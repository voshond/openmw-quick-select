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
local settings = require("scripts.voshondsquickselect.qs_settings")
local Debug = require("scripts.voshondsquickselect.qs_debug")

local selectedPage = 0
local interfacesReady = false
local interfaceCheckAttempts = 0
local MAX_INTERFACE_CHECK_ATTEMPTS = 20 -- 10 seconds total (20 * 0.5s)

local function getIconSize()
    local settingsStorage = storage.playerSection("SettingsVoshondsQuickSelect")
    return settingsStorage:get("iconSize") or 40
end
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

-- Function to check if all required interfaces are available
local function checkInterfaces()
    local requiredInterfaces = {
        "QuickSelect_Storage",
        "QuickSelect_Hotbar",
        "QuickSelect_Win1",
        "Controller_Icon_QS"
    }

    -- Check for basic interface availability
    for _, interfaceName in ipairs(requiredInterfaces) do
        if not I[interfaceName] then
            Debug.warning("QuickSelect_p", "Interface not available: " .. interfaceName)
            return false
        end
    end

    -- Check for required functions in QuickSelect_Storage
    local requiredStorageFunctions = {
        "getFavoriteItemData",
        "saveStoredItemData",
        "saveStoredSpellData",
        "saveStoredEnchantData",
        "isSlotEquipped",
        "equipSlot",
        "deleteStoredItemData"
    }

    for _, funcName in ipairs(requiredStorageFunctions) do
        if not I.QuickSelect_Storage[funcName] then
            Debug.warning("QuickSelect_p", "QuickSelect_Storage function not available: " .. funcName)
            return false
        end
    end

    -- Check for required functions in QuickSelect_Hotbar
    local requiredHotbarFunctions = {
        "drawHotbar",
        "resetFade"
    }

    for _, funcName in ipairs(requiredHotbarFunctions) do
        if not I.QuickSelect_Hotbar[funcName] then
            Debug.warning("QuickSelect_p", "QuickSelect_Hotbar function not available: " .. funcName)
            return false
        end
    end

    return true
end

local function onInputAction(action)
    -- Only process input if interfaces are ready
    if not interfacesReady then
        Debug.warning("QuickSelect_p", "Interfaces not ready, ignoring input")
        return
    end

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

        -- If we're on a different page than the target, switch to it
        if selectedPage ~= targetPage then
            selectedPage = targetPage
            I.QuickSelect_Hotbar.drawHotbar()
        end

        -- Calculate the actual slot number based on the page
        local actualSlot = slot + (targetPage * 10)

        -- Get the stored item/spell data
        local itemData = I.QuickSelect_Storage.getFavoriteItemData(actualSlot)

        -- Reset fade state and show hotbar
        if I.QuickSelect_Hotbar then
            I.QuickSelect_Hotbar.resetFade()
            I.QuickSelect_Hotbar.drawHotbar()
        end

        -- Handle spells
        if itemData and itemData.spell and not itemData.enchantId then
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
                if I.QuickSelect_Hotbar then
                    I.QuickSelect_Hotbar.drawHotbar()
                else
                    Debug.error("QuickSelect_p", "QuickSelect_Hotbar interface not available")
                end
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
                    if I.QuickSelect_Hotbar then
                        I.QuickSelect_Hotbar.drawHotbar()
                    else
                        Debug.error("QuickSelect_p", "QuickSelect_Hotbar interface not available")
                    end
                end)

                return
            end
        end

        -- Let equipSlot handle all other interactions
        if itemData then
            I.QuickSelect_Storage.equipSlot(actualSlot)
        end
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
            -- Initialize the QuickSelect system
            Debug.quickSelect("Initializing QuickSelect system")

            -- Initialize with page 0 selected
            selectedPage = 0
            interfacesReady = false
            interfaceCheckAttempts = 0

            -- Use a timer to check when other interfaces become available
            local function checkAndInitialize()
                interfaceCheckAttempts = interfaceCheckAttempts + 1

                if checkInterfaces() then
                    interfacesReady = true
                    Debug.quickSelect("All required interfaces are available")

                    -- Try to draw the hotbar once all interfaces are available
                    if I.QuickSelect_Hotbar then
                        I.QuickSelect_Hotbar.drawHotbar()
                    end
                else
                    if interfaceCheckAttempts >= MAX_INTERFACE_CHECK_ATTEMPTS then
                        Debug.error("QuickSelect_p",
                            "Failed to initialize interfaces after " .. MAX_INTERFACE_CHECK_ATTEMPTS .. " attempts")
                        return
                    end

                    -- Check again in 0.5 seconds
                    async:newUnsavableSimulationTimer(0.5, checkAndInitialize)
                end
            end

            -- Start checking for interfaces
            checkAndInitialize()
        end
    }
}
