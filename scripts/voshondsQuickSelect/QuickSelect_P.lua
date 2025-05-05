local core = require("openmw.core")

local self = require("openmw.self")
local types = require('openmw.types')
local nearby = require('openmw.nearby')
local camera = require('openmw.camera')
local util = require('openmw.util')
local ui = require('openmw.ui')
local input = require('openmw.input')
local I = require('openmw.interfaces')
local storage = require('openmw.storage')
local async = require('openmw.async')
local settings = require("scripts.voshondsQuickSelect.qs_settings")
local function getIconSize()
    local settingsStorage = storage.playerSection("SettingsVoshondsQuickSelect")
    return settingsStorage:get("iconSize") or 40
end
local selectedPage = 0
local function getIconSizeGrow()
    local ret = 20
    return getIconSize() + ret * 0.25
end
local function createHotbarItem(item, spell)
    local icon = I.Controller_Icon_QS.getItemIcon(item, false, false, nil, "")
    local boxedIcon = { --box around the titem
        type = ui.TYPE.Container,
        props = {
            size = util.vector2(getIconSize(), getIconSize()),
        },
        events = {
        },
        content = {
            {
                template = I.MWUI.templates.boxSolid,
                alignment = ui.ALIGNMENT.Center,
                content = icon
            }
        }
    }
    return boxedIcon
end
local function getHotbarItems()
    local items = {}
    for index, value in ipairs(types.Actor.inventory(self):getAll()) do
        if index < 10 then
            table.insert(items, createHotbarItem(value))
        end
    end
    return items
end
local function drawHotbar()
    I.QuickSelect_Win1.drawQuickSelect()
    if true then
        return
    end
    local items = getHotbarItems()
    local itemFlex = {
        type = ui.TYPE.Flex,
        layer = "HUD",
        content = items,
        props = {
            size = util.vector2(450, 300),
            horizontal = false,
            vertical = false,
            arrange = ui.ALIGNMENT.Start,
            align = ui.ALIGNMENT.Center,
            autoSize = true
        },
    }
    local pos = 0
    for index, value in ipairs(items) do
        pos = pos + 0.1
    end
    ui.create {
        layer = "HUD",
        template = I.MWUI.templates.boxSolid,
        events = {
        },
        props = {
            anchor = util.vector2(0.5, 0.5),
            relativePosition = util.vector2(pos, .1),
            arrange = ui.ALIGNMENT.Center,
            align = ui.ALIGNMENT.Center,
            autoSize = false,
            vertical = true,
            size = util.vector2(450, 300),
        },
        content = itemFlex
    }
end

local function onInputAction(action)
    if action >= input.ACTION.QuickKey1 and action <= input.ACTION.QuickKey10 then
        local slot = action - input.ACTION.QuickKey1 + 1

        -- Alt cycles through hotbars
        if input.isAltPressed() then
            selectedPage = (selectedPage + 1) % 3
            I.QuickSelect_Hotbar.drawHotbar()
            return
        end

        -- Direct hotbar selection:
        -- Default: Keys 1-0 select slots from the first hotbar (page 0)
        -- Shift: Shift+1-0 select slots from the second hotbar (page 1)
        -- Ctrl: Ctrl+1-0 select slots from the third hotbar (page 2)
        local targetPage = 0

        if input.isShiftPressed() then
            targetPage = 1
        elseif input.isCtrlPressed() then
            targetPage = 2
        end

        -- Check if the item in this slot is already equipped
        local slotNumber = slot + (targetPage * 10)
        local itemData = I.QuickSelect_Storage.getFavoriteItemData(slotNumber)

        if itemData then
            -- Handle spells
            if itemData.spell and not itemData.enchantId then
                local selectedSpell = types.Actor.getSelectedSpell(self)
                if selectedSpell and selectedSpell.id == itemData.spell then
                    -- If the same spell is already selected, toggle spell stance
                    local currentStance = types.Actor.getStance(self)
                    if currentStance == types.Actor.STANCE.Spell then
                        types.Actor.setStance(self, types.Actor.STANCE.Nothing)
                    else
                        types.Actor.setStance(self, types.Actor.STANCE.Spell)
                    end

                    -- Update the hotbar UI to reflect the spell change
                    I.QuickSelect_Hotbar.drawHotbar()
                    return
                else
                    -- If a different spell is selected, maintain spell stance if a spell stance was active
                    local currentStance = types.Actor.getStance(self)
                    local wasSpellStance = (currentStance == types.Actor.STANCE.Spell)
                    local hadSpellSelected = (selectedSpell ~= nil)

                    -- Change to the new spell
                    types.Actor.setSelectedSpell(self, itemData.spell)

                    -- If we were already in spell stance, maintain it with the new spell
                    if wasSpellStance then
                        types.Actor.setStance(self, types.Actor.STANCE.Spell)
                        -- If we had any spell selected but were in the nothing stance, switch to spell stance
                    elseif hadSpellSelected then
                        types.Actor.setStance(self, types.Actor.STANCE.Spell)
                    end

                    -- Allow a small delay for the game state to update before redrawing the UI
                    async:newUnsavableSimulationTimer(0.05, function()
                        I.QuickSelect_Hotbar.drawHotbar()
                    end)

                    return
                end
                -- Handle enchanted items
            elseif itemData.enchantId then
                local enchantedItem = types.Actor.getSelectedEnchantedItem(self)
                local realItem = types.Actor.inventory(self):find(itemData.itemId)
                if enchantedItem and realItem and enchantedItem.recordId == realItem.recordId then
                    -- If the same enchanted item is already selected, toggle spell stance
                    local currentStance = types.Actor.getStance(self)
                    if currentStance == types.Actor.STANCE.Spell then
                        types.Actor.setStance(self, types.Actor.STANCE.Nothing)
                    else
                        types.Actor.setStance(self, types.Actor.STANCE.Spell)
                    end
                    return
                end
                -- Handle regular items
            elseif itemData.item then
                local realItem = types.Actor.inventory(self):find(itemData.item)
                if realItem then
                    local isEquipped = I.QuickSelect_Storage.isSlotEquipped(slotNumber)
                    if isEquipped then
                        -- Special handling for light sources
                        if realItem.type == types.Light then
                            local currentStance = types.Actor.getStance(self)
                            if currentStance == types.Actor.STANCE.Spell then
                                -- If a spell is ready, toggle to nothing
                                types.Actor.setStance(self, types.Actor.STANCE.Nothing)
                            elseif currentStance == types.Actor.STANCE.Weapon then
                                -- If a weapon is ready, unequip the light
                                local equip = types.Actor.equipment(self)
                                for slotKey, item in pairs(equip) do
                                    if item == realItem then
                                        equip[slotKey] = nil
                                        types.Actor.setEquipment(self, equip)
                                        break
                                    end
                                end
                            else
                                -- If nothing is ready, unequip the light
                                local equip = types.Actor.equipment(self)
                                for slotKey, item in pairs(equip) do
                                    if item == realItem then
                                        equip[slotKey] = nil
                                        types.Actor.setEquipment(self, equip)
                                        break
                                    end
                                end
                            end
                            return
                            -- Regular handling for weapons and lockpicks
                        elseif realItem.type == types.Weapon or realItem.type == types.Lockpick or realItem.type == types.Probe then
                            -- Toggle weapon stance for weapon, lockpick, and probe
                            local currentStance = types.Actor.getStance(self)
                            if currentStance == types.Actor.STANCE.Weapon then
                                types.Actor.setStance(self, types.Actor.STANCE.Nothing)
                            else
                                types.Actor.setStance(self, types.Actor.STANCE.Weapon)
                            end
                            return
                        end
                    end
                end
            end
        end

        -- Use the determined page instead of the selected page
        I.QuickSelect_Storage.equipSlot(slotNumber)
        I.QuickSelect_Hotbar.drawHotbar()
    end
end
return {

    interfaceName = "QuickSelect",
    interface = {
        drawHotbar = drawHotbar,
        getSelectedPage = function()
            return selectedPage
        end,
        setSelectedPage = function(num)
            selectedPage = num
        end,
    },
    engineHandlers = {
        onInputAction = onInputAction,
        onLoad = function()
            -- I.QuickSelect_Hotbar.drawHotbar()
        end
    }
}
