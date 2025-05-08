local core = require("openmw.core")

local self = require("openmw.self")
local types = require('openmw.types')
local nearby = require('openmw.nearby')
local camera = require('openmw.camera')
local util = require('openmw.util')
local async = require('openmw.async')
local storage = require('openmw.storage')
local I = require('openmw.interfaces')

local settings = storage.playerSection("SettingsVoshondsQuickSelect")

local utility = require("scripts.voshondsquickselect.qs_utility")
local Debug = require("scripts.voshondsquickselect.qs_debug")
local storedItems

local function getFavoriteItems()
    if not storedItems then
        storedItems = {}
        for i = 1, 30, 1 do
            storedItems[i] = { num = i, item = nil }
        end
    end
    return storedItems
end
local function getFavoriteItemData(slot)
    getFavoriteItems()
    return storedItems[slot]
end
local function deleteStoredItemData(slot)
    getFavoriteItems()
    storedItems[slot].spell     = nil
    storedItems[slot].spellType = nil
    storedItems[slot].enchantId = nil
    storedItems[slot].itemId    = nil
    storedItems[slot].item      = nil
end
local function saveStoredItemData(id, slot)
    getFavoriteItems()
    Debug.storage("Saving item " .. tostring(id) .. " to slot " .. tostring(slot))
    deleteStoredItemData(slot)
    storedItems[slot].item = id
end
local function saveStoredSpellData(spellId, spellType, slot)
    getFavoriteItems()
    deleteStoredItemData(slot)
    storedItems[slot].spellType = spellType
    storedItems[slot].spell     = spellId
end
local function saveStoredEnchantData(enchantId, itemId, slot)
    getFavoriteItems()
    deleteStoredItemData(slot)
    storedItems[slot].spellType = "Enchant"
    storedItems[slot].enchantId = enchantId
    storedItems[slot].itemId    = itemId
    Debug.storage("Saving enchanted item " .. tostring(itemId) .. " to slot " .. tostring(slot))
end
local function findItem(id)
    for index, value in ipairs(types.Actor.inventory(self)) do

    end
end
local function isSlotEquipped(slot)
    local item = getFavoriteItemData(slot)
    if item then
        if item.spell and not item.enchantId then
            local spell = types.Actor.getSelectedSpell(self)
            if not spell then return false end

            -- Additional logging to debug the issue
            local isMatched = (spell.id == item.spell)
            return isMatched
        elseif item.enchantId then
            Debug.storage("Checking enchanted item in slot " .. slot)
            local equip = types.Actor.getSelectedEnchantedItem(self)
            if not equip then return false end
            local realItem = types.Actor.inventory(self):find(item.itemId)
            if not realItem then return false end

            return types.Actor.getSelectedEnchantedItem(self).recordId == realItem.recordId
        elseif item.item then
            local equip = types.Actor.equipment(self)
            local realItem = types.Actor.inventory(self):find(item.item)
            if not realItem then return false end

            -- Special handling for Lockpicks, Probes, and Lights
            if realItem.type == types.Lockpick or realItem.type == types.Probe or realItem.type == types.Light then
                -- Check if the item is equipped in any slot
                for _, equippedItem in pairs(equip) do
                    if equippedItem == realItem then
                        return true
                    end
                end
                return false
            else
                -- Normal handling for other item types
                local slot = utility.findSlot(realItem)
                if not slot then
                    return false
                end
                return equip[slot] == realItem
            end
        end
    end
    return false
end
local function getEquipped(item)
    local equip = types.Actor.equipment(self)
    for index, value in pairs(equip) do
        if value == item then
            return index
        end
    end
    return nil
end
local function equipSlot(slot)
    local item = getFavoriteItemData(slot)
    if item then
        if item.spell and not item.enchantId then
            types.Actor.clearSelectedCastable(self)
            types.Actor.setSelectedSpell(self, item.spell)
        elseif item.enchantId then
            local equip = types.Actor.equipment(self)
            local realItem = types.Actor.inventory(self):find(item.itemId)
            if not realItem then return end
            types.Actor.setSelectedEnchantedItem(self, realItem)
        elseif item.item then
            local realItem = types.Actor.inventory(self):find(item.item)
            if not realItem then return end
            local equipped = getEquipped(realItem)

            if not equipped then
                -- Equip the item
                core.sendGlobalEvent('UseItem', { object = realItem, actor = self })

                if realItem.type == types.Weapon or realItem.type == types.Lockpick or realItem.type == types.Probe then
                    async:newUnsavableSimulationTimer(0.1, function()
                        types.Actor.setStance(self, types.Actor.STANCE.Weapon)
                    end)
                end
            else
                -- Item is already equipped
                if realItem.type == types.Light then
                    -- For lights, always unequip when already equipped
                    local equip = types.Actor.equipment(self)
                    equip[equipped] = nil
                    types.Actor.setEquipment(self, equip)
                elseif realItem.type == types.Weapon or realItem.type == types.Lockpick or realItem.type == types.Probe then
                    -- Toggle weapon stance for weapons, lockpicks, and probes
                    if types.Actor.getStance(self) == types.Actor.STANCE.Weapon then
                        types.Actor.setStance(self, types.Actor.STANCE.Nothing)
                    else
                        types.Actor.setStance(self, types.Actor.STANCE.Weapon)
                    end

                    -- If unEquipOnHotkey is enabled and we're in Nothing stance, unequip
                    if settings:get("unEquipOnHotkey") and types.Actor.getStance(self) == types.Actor.STANCE.Nothing then
                        local equip = types.Actor.equipment(self)
                        equip[equipped] = nil
                        types.Actor.setEquipment(self, equip)
                    end
                end
            end
        end
    end

    async:newUnsavableSimulationTimer(0.1, function()
        if I.QuickSelect_Hotbar then
            I.QuickSelect_Hotbar.drawHotbar()
        else
            Debug.error("QuickSelect_Storage", "QuickSelect_Hotbar interface not available")
        end
    end)
end
return {

    interfaceName = "QuickSelect_Storage",
    interface = {
        saveStoredItemData    = saveStoredItemData,
        getFavoriteItemData   = getFavoriteItemData,
        getFavoriteItems      = getFavoriteItems,
        saveStoredSpellData   = saveStoredSpellData,
        equipSlot             = equipSlot,
        saveStoredEnchantData = saveStoredEnchantData,
        isSlotEquipped        = isSlotEquipped,
        deleteStoredItemData  = deleteStoredItemData,
    },
    engineHandlers = {
        onSave = function()
            return { storedItems = storedItems }
        end,
        onLoad = function(data)
            storedItems = data.storedItems
        end,
    }
}
