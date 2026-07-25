local self = require("openmw.self")
local types = require('openmw.types')
local core = require("openmw.core")
local async = require('openmw.async')
local storage = require('openmw.storage')
local I = require('openmw.interfaces')

local settings = storage.playerSection("SettingsVoshondsQuickSelect")

local utility = require("scripts.voshondsquickselect.legacy.utility")
local Debug = require("scripts.voshondsquickselect.debug")
local ActorEquipment = require("scripts.voshondsquickselect.services.actor_equipment")
local FavoriteItem = require("scripts.voshondsquickselect.services.favorite_item")
local FavoriteSlotsMigration = require("scripts.voshondsquickselect.services.favorite_slots_migration")

local SLOT_COUNT = 30
local STORAGE_VERSION = 2
local storedItems

local function emptySlot(slot)
    return { num = slot, item = nil }
end

local function normalizeStoredItems(slots)
    local normalized = {}

    for slot = 1, SLOT_COUNT do
        local source = type(slots) == "table" and slots[slot] or nil
        local entry = emptySlot(slot)

        if type(source) == "table" then
            if type(source.enchantId) == "string" and type(source.itemId) == "string" then
                entry.spellType = "Enchant"
                entry.enchantId = source.enchantId
                entry.itemId = source.itemId
                if type(source.itemInstanceId) == "string" then
                    entry.itemInstanceId = source.itemInstanceId
                end
            elseif type(source.spell) == "string" then
                entry.spellType = "Spell"
                entry.spell = source.spell
            elseif type(source.item) == "string" then
                entry.item = source.item
                if type(source.itemInstanceId) == "string" then
                    entry.itemInstanceId = source.itemInstanceId
                end
            end
        end

        normalized[slot] = entry
    end

    return normalized
end

local function validSlot(slot)
    return type(slot) == "number" and slot >= 1 and slot <= SLOT_COUNT and slot % 1 == 0
end

local function getFavoriteItems()
    if not storedItems then
        storedItems = normalizeStoredItems()
    end
    return storedItems
end

local function getFavoriteItemData(slot)
    if not validSlot(slot) then
        return nil
    end
    getFavoriteItems()
    return storedItems[slot]
end

local function getFavoriteItem(slot)
    return FavoriteItem.resolve(types.Actor.inventory(self), getFavoriteItemData(slot))
end

local function importLegacyFavorites(legacySlots)
    -- The compatibility bridge can be loaded alongside a save that already
    -- contains data written by this module. Never replace current assignments.
    if FavoriteSlotsMigration.hasAssignments(storedItems) then
        return false
    end

    if not FavoriteSlotsMigration.hasAssignments(legacySlots) then
        return false
    end

    storedItems = normalizeStoredItems(FavoriteSlotsMigration.copySlots(legacySlots))
    Debug.storage("Imported quick-key assignments from the legacy storage script")
    return true
end

local requestHotbarUpdate

local function deleteStoredItemData(slot, suppressUpdate)
    if not validSlot(slot) then
        return false
    end

    getFavoriteItems()
    -- Replacing the complete entry clears metadata from the previous item as
    -- well. In particular, an old enchantment charge must never leak into a
    -- newly assigned item.
    storedItems[slot] = emptySlot(slot)
    if not suppressUpdate and requestHotbarUpdate then
        requestHotbarUpdate(slot, false)
    end
    return true
end
requestHotbarUpdate = function(slot, settleAfterEngineAction)
    local function invalidate()
        if not I.QuickSelect_Hotbar then
            return
        end

        if I.QuickSelect_Hotbar.invalidateSlot then
            I.QuickSelect_Hotbar.invalidateSlot(slot, "favorite slot changed", true)
        else
            I.QuickSelect_Hotbar.drawHotbar()
        end
    end

    invalidate()

    -- UseItem is handled by the engine after this script action. One deferred
    -- reconciliation is enough; the HUD coalesces it with any other request.
    if settleAfterEngineAction then
        async:newUnsavableSimulationTimer(0.1, invalidate)
    end
end

local function resolveItemReference(reference)
    if type(reference) == "table" and reference.recordId then
        return reference
    end

    if type(reference) == "string" then
        return types.Actor.inventory(self):find(reference)
    end

    return nil
end

local function saveStoredItemData(reference, slot)
    if not validSlot(slot) then
        return false
    end

    local realItem = resolveItemReference(reference)
    if not realItem then
        Debug.warning("QuickSelect_Storage", "Cannot save an item that is no longer in inventory")
        return false
    end

    getFavoriteItems()
    Debug.storage("Saving item " .. tostring(realItem.recordId) .. " to slot " .. tostring(slot))
    deleteStoredItemData(slot, true)
    storedItems[slot].item = realItem.recordId
    storedItems[slot].itemInstanceId = tostring(realItem.id)

    requestHotbarUpdate(slot, false)
    return true
end

local function saveStoredSpellData(spellId, spellType, slot)
    if not validSlot(slot) or type(spellId) ~= "string" then
        return false
    end

    getFavoriteItems()
    deleteStoredItemData(slot, true)
    storedItems[slot].spellType = "Spell"
    storedItems[slot].spell     = spellId

    requestHotbarUpdate(slot, false)
    return true
end

local function saveStoredEnchantData(enchantId, reference, slot)
    if not validSlot(slot) or type(enchantId) ~= "string" then
        return false
    end

    local realItem = resolveItemReference(reference)
    if not realItem then
        Debug.warning("QuickSelect_Storage", "Cannot save an enchanted item that is no longer in inventory")
        return false
    end

    getFavoriteItems()
    deleteStoredItemData(slot, true)
    storedItems[slot].spellType = "Enchant"
    storedItems[slot].enchantId = enchantId
    storedItems[slot].itemId = realItem.recordId
    storedItems[slot].itemInstanceId = tostring(realItem.id)
    Debug.storage("Saving enchanted item " .. tostring(realItem.recordId) .. " to slot " .. tostring(slot))

    requestHotbarUpdate(slot, false)
    return true
end

local function isSlotEquipped(slot)
    local item = getFavoriteItemData(slot)
    if not item then return false end

    -- Log slot being checked for equipped status
    Debug.storage("Checking if slot " .. slot .. " is equipped")

    -- First, handle spells
    if item.spell and not item.enchantId then
        local spell = types.Actor.getSelectedSpell(self)
        if not spell then return false end

        -- Log the comparison
        local isMatched = (spell.id == item.spell)
        Debug.storage("Spell comparison: " ..
            tostring(spell.id) .. " == " .. tostring(item.spell) .. " is " .. tostring(isMatched))
        return isMatched

        -- Then handle enchanted items
    elseif item.enchantId then
        Debug.storage("Checking enchanted item in slot " .. slot)
        local enchantedItem = types.Actor.getSelectedEnchantedItem(self)
        if not enchantedItem then return false end

        local realItem = getFavoriteItem(slot)
        if not realItem then return false end

        local isMatched = FavoriteItem.isSameInstance(enchantedItem, realItem)
        Debug.storage("Enchanted item comparison: " ..
            tostring(enchantedItem.id) .. " == " .. tostring(realItem.id) .. " is " .. tostring(isMatched))
        return isMatched

        -- Finally handle regular items
    elseif item.item then
        local equip = ActorEquipment.get(self)
        local realItem = getFavoriteItem(slot)
        if not realItem then
            Debug.storage("Item not found in inventory: " .. tostring(item.item))
            return false
        end

        -- Special handling for Lockpicks, Probes, and Lights
        if realItem.type == types.Lockpick or realItem.type == types.Probe or realItem.type == types.Light then
            -- Check if the item is equipped in any slot
            for slotName, equippedItem in pairs(equip) do
                if equippedItem == realItem then
                    Debug.storage("Item " .. tostring(item.item) .. " is equipped in slot " .. tostring(slotName))
                    return true
                end
            end
            Debug.storage("Item " .. tostring(item.item) .. " is not equipped in any slot")
            return false
        else
            -- Normal handling for other item types
            local itemSlot = utility.findSlot(realItem)
            if not itemSlot then
                Debug.storage("No equipment slot found for item: " .. tostring(item.item))
                return false
            end

            local isEquipped = (equip[itemSlot] == realItem)
            Debug.storage("Item " ..
                tostring(item.item) .. " equipped in slot " .. tostring(itemSlot) .. ": " .. tostring(isEquipped))
            return isEquipped
        end
    end

    return false
end
local function getEquipped(item)
    return ActorEquipment.findSlot(self, item)
end

local function equipSlot(slot)
    local item = getFavoriteItemData(slot)
    if item then
        if item.spell and not item.enchantId then
            types.Actor.clearSelectedCastable(self)
            types.Actor.setSelectedSpell(self, item.spell)
            -- Always set stance to Spell when selecting a spell
            types.Actor.setStance(self, types.Actor.STANCE.Spell)
            Debug.storage("Set selected spell to " .. tostring(item.spell))
        elseif item.enchantId then
            -- This is now handled in controllers/player.lua's onInputAction function.
            -- This code is kept for compatibility with other parts of the code that may call equipSlot directly
            local realItem = getFavoriteItem(slot)
            if not realItem then return end
            types.Actor.setSelectedEnchantedItem(self, realItem)
            -- Always set stance to Spell when selecting an enchanted item
            types.Actor.setStance(self, types.Actor.STANCE.Spell)
            Debug.storage("Set selected enchanted item to " .. tostring(item.itemId))
        elseif item.item then
            local realItem = getFavoriteItem(slot)
            if not realItem then return end
            local equipped = getEquipped(realItem)

            if not equipped then
                -- Equip the item
                Debug.storage("Equipping item " .. tostring(item.item))
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
                    Debug.storage("Unequipping light " .. tostring(item.item))
                    local equip = ActorEquipment.get(self)
                    equip[equipped] = nil
                    types.Actor.setEquipment(self, equip)
                elseif realItem.type == types.Weapon or realItem.type == types.Lockpick or realItem.type == types.Probe then
                    -- Toggle weapon stance for weapons, lockpicks, and probes
                    if types.Actor.getStance(self) == types.Actor.STANCE.Weapon then
                        Debug.storage("Setting stance to Nothing")
                        types.Actor.setStance(self, types.Actor.STANCE.Nothing)
                    else
                        Debug.storage("Setting stance to Weapon")
                        types.Actor.setStance(self, types.Actor.STANCE.Weapon)
                    end

                    -- If autoUnequipSheathedWeapons is enabled and we're in Nothing stance, unequip
                    if settings:get("autoUnequipSheathedWeapons") and types.Actor.getStance(self) == types.Actor.STANCE.Nothing then
                        Debug.storage("Unequipping weapon due to autoUnequipSheathedWeapons setting")
                        local equip = ActorEquipment.get(self)
                        equip[equipped] = nil
                        types.Actor.setEquipment(self, equip)
                    end
                elseif realItem.type == types.Armor or realItem.type == types.Clothing then
                    -- For armor and clothing, check toggleEquipment setting
                    if settings:get("toggleEquipment") then
                        Debug.storage("Unequipping equipment " .. tostring(item.item) .. " due to toggleEquipment setting")
                        local equip = ActorEquipment.get(self)
                        equip[equipped] = nil
                        types.Actor.setEquipment(self, equip)
                    else
                        Debug.storage("Equipment already equipped and toggleEquipment is disabled, doing nothing")
                    end
                end
            end
        end
    end

    requestHotbarUpdate(slot, true)
end
return {

    interfaceName = "QuickSelect_Storage",
    interface = {
        saveStoredItemData    = saveStoredItemData,
        getFavoriteItemData   = getFavoriteItemData,
        getFavoriteItem       = getFavoriteItem,
        getFavoriteItems      = getFavoriteItems,
        saveStoredSpellData   = saveStoredSpellData,
        equipSlot             = equipSlot,
        saveStoredEnchantData = saveStoredEnchantData,
        isSlotEquipped        = isSlotEquipped,
        deleteStoredItemData  = deleteStoredItemData,
        importLegacyFavorites = importLegacyFavorites,
    },
    engineHandlers = {
        onSave = function()
            return {
                version = STORAGE_VERSION,
                storedItems = getFavoriteItems(),
            }
        end,
        onLoad = function(data)
            storedItems = normalizeStoredItems(data and data.storedItems)
        end,
    }
}
