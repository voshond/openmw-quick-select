local core = require("openmw.core")

local self = require("openmw.self")
local types = require('openmw.types')
local nearby = require('openmw.nearby')
local storage = require('openmw.storage')
local async = require('openmw.async')
local input = require('openmw.input')
local util = require('openmw.util')
local ui = require('openmw.ui')
local I = require('openmw.interfaces')

local settings = storage.playerSection("SettingsVoshondsQuickSelect")
local tooltipData = require("scripts.voshondsquickselect.ci_tooltipgen")
local utility = require("scripts.voshondsquickselect.qs_utility")
local Debug = require("scripts.voshondsquickselect.qs_debug")
local Hotbar = require("scripts.voshondsquickselect.ui.hotbar")
local Tooltip = require("scripts.voshondsquickselect.ui.tooltip")

-- Debug logging function (using the Debug module)
local function log(message)
    Debug.hotbar(message)
end

local hotBarElement
local num = 1
local enableHotbar = true        -- Always enabled
local pickSlotMode = false       --True if we are picking a slot for saving
local controllerPickMode = false --True if we are picking a slot for equipping OR saving
local selectedNum = 1
local HOTBAR_ITEMS_PER_ROW = 10

-- Fade-related variables
local fadeTimer = 0
local isFading = false
local fadeDuration = 2.0 -- 2 seconds fade duration before hiding

-- Add these variables at the top of the file with the other state variables
local lastUpdateTime = 0
local UPDATE_THROTTLE = 2.0 -- Only update the hotbar every 2 seconds at most
local needsRedraw = false
local wasHudVisible = true  -- Track the previous state of HUD visibility

-- Forward declare the drawHotbar function to use it in resetFade
local drawHotbar

-- Remove the early initialization code
-- Let's initialize in onLoad instead

local function startPickingMode()
    controllerPickMode = true
    I.QuickSelect_Hotbar.drawHotbar()
end
local function endPickingMode()
    pickSlotMode = false
    controllerPickMode = false
    I.UI.setMode()
    I.QuickSelect_Hotbar.drawHotbar()
end

local function getToolTipPos()
    local setting = settings:get("hotBarOnTop")
    if setting then
        return utility.itemWindowLocs.BottomCenter
    else
        return utility.itemWindowLocs.TopCenter
    end
end
local function drawToolTip()
    local offset = I.QuickSelect.getSelectedPage() * 10
    local data = I.QuickSelect_Storage.getFavoriteItemData(selectedNum + offset)

    local item
    local magicRecord
    if data.item then
        item = types.Actor.inventory(self):find(data.item)
    elseif data.itemId then
        item = types.Actor.inventory(self):find(data.itemId)
    elseif data.spell or data.enchantId then
        if data.spellType and data.spellType:lower() == "spell" then
            local selectedSpell = types.Actor.spells(self)[data.spell]
            if selectedSpell then
                magicRecord = core.magic.spells.records[selectedSpell.id]
            end
        elseif data.spellType and data.spellType:lower() == "enchant" then
            magicRecord = utility.getEnchantment(data.enchantId)
        end
    end

    local lines
    if item then
        lines = tooltipData.genToolTips(item)
    elseif magicRecord then
        lines = tooltipData.genToolTips({ spell = magicRecord })
    end

    if lines then
        local position = getToolTipPos()
        Tooltip.show(lines, {
            anchor = position.anchor,
            relativePosition = util.vector2(position.wx, position.wy),
        })
    else
        Tooltip.hide()
    end
end
local function createHotbarItem(item, xicon, num, data, half)
    -- Add debug logging to track item creation
    log("Creating hotbar item for slot " .. num)

    local icon
    -- Forcefully check if the slot is equipped every time we create the hotbar item
    -- This ensures the equipped status is always up-to-date
    local isEquipped = false

    -- Use pcall to safely check equipped status
    local success, result = pcall(function()
        return I.QuickSelect_Storage.isSlotEquipped(num)
    end)

    if success then
        isEquipped = result
        log("Slot " .. num .. " equipped status: " .. tostring(isEquipped))
    else
        log("Error checking if slot " .. num .. " is equipped: " .. tostring(result))
    end

    local sizeX = utility.getIconSize()
    local sizeY = utility.getIconSize()
    local drawNumber = true -- Always draw the number regardless of settings
    local offset = I.QuickSelect.getSelectedPage() * 10
    local selected = (num) == (selectedNum + offset)

    -- When disableIconShrinking is true, don't pass the selected state to the icon functions
    local useSelectedState = selected
    -- Add a nil check to avoid errors if the setting isn't initialized yet
    local disableShrinking = settings:get("disableIconShrinking")
    if disableShrinking ~= false and selected then
        -- Default to true (disable shrinking) unless explicitly set to false
        useSelectedState = false -- Don't use selected state for icon generation
    end

    if half then
        sizeY = sizeY / 2
    end

    -- Calculate the slot's bar for determining the prefix
    -- This is based on the actual slot number range:
    -- Bar 1 (slots 1-10): no prefix
    -- Bar 2 (slots 11-20): "s" prefix
    -- Bar 3 (slots 21-30): "c" prefix
    local slotPrefix = ""

    if num >= 21 and num <= 30 then
        slotPrefix = "c"
    elseif num >= 11 and num <= 20 then
        slotPrefix = "s"
    end

    -- Instead of using metatables, we'll pass the slot number directly with appropriate prefix
    if item and not xicon then
        icon = I.Controller_Icon_QS.getItemIcon(item, half, useSelectedState, num, slotPrefix, data)
    elseif xicon then
        icon = I.Controller_Icon_QS.getSpellIcon(xicon, half, useSelectedState, num, slotPrefix)
    elseif num then
        icon = I.Controller_Icon_QS.getEmptyIcon(half, num, useSelectedState, drawNumber, slotPrefix)
    end

    -- Add a small margin around the icon to prevent clipping
    local iconPadding = 2 -- 2px padding on each side

    -- Create a box size that's slightly larger than the icon
    local boxSize = util.vector2(sizeX + iconPadding * 2, sizeY + iconPadding * 2)

    -- Create the icon with proper padding to prevent clipping
    local boxedIcon = utility.renderItemBoxed(icon, boxSize, nil,
        util.vector2(0.5, 0.5),
        { item = item, num = num, data = data })

    -- Create an equipped indicator if needed
    local iconContent
    if isEquipped then
        -- Use the equipped indicator icon from the textures folder
        local equippedIconTexture = ui.texture({ path = "textures/voshondsQuickSelect/equipped_indicator.dds" })

        -- Overlay the equipped icon in the bottom-left corner of the hotbar icon
        iconContent = ui.content {
            boxedIcon,
            {
                type = ui.TYPE.Image,
                props = {
                    resource = equippedIconTexture,
                    size = util.vector2(16, 16),                              -- Adjust size as needed
                    position = util.vector2(0, sizeY + iconPadding * 2 - 16), -- Bottom-left corner
                    arrange = ui.ALIGNMENT.Start,
                    align = ui.ALIGNMENT.Start,
                    alpha = 1,
                }
            }
        }

        -- Add extra log for equipped items
        log("Created equipped item marker for slot " .. num)
    else
        iconContent = ui.content { boxedIcon }
    end

    -- The bordered icon above is already the visual slot frame.  Do not add
    -- the legacy padding-template wrapper here: it expands the drawn slot
    -- beyond its declared size, making both width measurement and a zero
    -- gutter inaccurate.
    local outerSize = util.vector2(sizeX + iconPadding * 2, sizeY + iconPadding * 2)
    return {
        type = ui.TYPE.Widget,
        props = {
            autoSize = false,
            size = outerSize,
        },
        content = iconContent,
    }
end

local function getHotbarItems(half)
    log("---- BEGIN getHotbarItems ----")
    log("half=" .. tostring(half) .. ", num=" .. num)

    local items = {}
    local count = num + 10

    log("count=" .. count)

    local startNum = num
    while num < count do
        local data = I.QuickSelect_Storage.getFavoriteItemData(num)
        log("Processing item " .. num)

        local item
        local effect
        local icon
        if data.item then
            item = types.Actor.inventory(self):find(data.item)
            log("Item found: " .. tostring(data.item))
        elseif data.spell or data.enchantId then
            log("Spell or enchant item")
            if data.spellType and data.spellType:lower() == "spell" then
                local spell = types.Actor.spells(self)[data.spell]
                if spell then
                    Debug.log("Spell: " .. tostring(spell))
                    effect = spell.effects[1]
                    -- Use big effect icon for better quality (adds "b_" prefix)
                    local smallIconPath = effect.effect.icon
                    icon = utility.getSpellEffectBigIconPath(smallIconPath)
                    -- Alternative: Use school icon (shows Destruction, Restoration, etc.)
                    -- local schoolId = effect.effect.school
                    -- local schoolSkill = core.stats.Skill.records[schoolId]
                    -- icon = schoolSkill.icon
                    Debug.log("Spell icon found: " .. tostring(icon))
                end
            elseif data.spellType and data.spellType:lower() == "enchant" then
                local enchant = utility.getEnchantment(data.enchantId)
                if enchant then
                    effect = enchant.effects[1]
                    local smallIconPath = effect.effect.icon
                    icon = utility.getSpellEffectBigIconPath(smallIconPath)
                    Debug.log("Enchant icon found")
                end
            end
        else
            log("Empty slot")
        end

        -- Add the hotbar item
        log("Adding hotbar item " .. num)
        table.insert(items, createHotbarItem(item, icon, num, data, half))

        num = num + 1
    end

    log("Created " .. #items .. " slot elements")
    log("Initial num=" .. startNum .. ", final num=" .. num)
    log("---- END getHotbarItems ----")

    return items
end

-- Now define the real drawHotbar function
drawHotbar = function(resetFadeTimer)
    if resetFadeTimer == nil then resetFadeTimer = true end
    -- Modified condition: Only skip if no redraw is explicitly needed AND UI already exists
    if hotBarElement and not needsRedraw and not pickSlotMode and not controllerPickMode then
        log("Skipping redraw - UI exists and no changes detected")
        return
    end

    log("==== BEGIN drawHotbar ====")

    -- If an existing hotbar exists, destroy it before creating a new one
    if hotBarElement then
        log("Destroying existing hotbar")
        local success, err = pcall(function()
            hotBarElement:destroy()
        end)
        if not success then
            log("Error destroying hotbar: " .. tostring(err))
        end
        hotBarElement = nil
    end

    Tooltip.hide()

    -- Only reset fade state if requested (user interaction)
    if resetFadeTimer then
        fadeTimer = 0
        isFading = false
    end

    -- Force retrieve the latest item data from storage to ensure we have the most recent changes
    -- This is especially important when items are just saved to slots
    log("Retrieving latest hotbar data")

    -- Configuration for the hotbar
    local iconSize = utility.getIconSize()
    local iconPadding = 2                                               -- Same padding as in createHotbarItem
    local paddedIconSize = iconSize + (iconPadding * 2)                 -- Account for padding
    local boxSize = paddedIconSize                                      -- Use padded icon size
    local gutterSize = settings:get("hotbarGutterSize") or 5            -- Get the gutter size from settings
    local verticalSpacing = settings:get("hotbarVerticalSpacing") or 12 -- Direct UI-pixel gap
    local itemsPerRow = HOTBAR_ITEMS_PER_ROW

    log("Config - iconSize: " ..
        iconSize ..
        ", paddedIconSize: " .. paddedIconSize .. ", gutterSize: " .. gutterSize ..
        ", verticalSpacing: " .. verticalSpacing ..
        ", itemsPerRow: " .. itemsPerRow)

    -- A row owns exactly the size it draws.  The old renderer added arbitrary
    -- width/height padding and then scaled child rows into that box, which is
    -- what caused clipped slots at different icon and gutter settings.
    local rowSize = Hotbar.measure(itemsPerRow, boxSize, boxSize, gutterSize)
    local visibleHotbars = math.max(1, math.min(3, settings:get("visibleHotbars") or 1))
    -- Settings are logical UI pixels.  Do not apply the old /10 conversion:
    -- zero must mean zero, and 40 should look materially larger than 4.
    local verticalGap = visibleHotbars > 1 and math.max(0, verticalSpacing) or 0
    local rows = {}

    log("Row size: " .. tostring(rowSize.x) .. "x" .. tostring(rowSize.y) .. ", visible: " .. tostring(visibleHotbars))

    local function addBar(page)
        num = 1 + (itemsPerRow * page)
        local items = getHotbarItems()
        table.insert(rows, Hotbar.create({
            slots = items,
            slotSize = boxSize,
            gap = gutterSize,
            size = rowSize,
            -- The row itself is centred by the HUD root.  Its slots must
            -- start at x=0 so an exact zero gap stays exact.
            align = ui.ALIGNMENT.Start,
            arrange = ui.ALIGNMENT.Start,
        }))
    end

    -- Page three is visually above page two, which is above the default page.
    for page = visibleHotbars - 1, 0, -1 do
        addBar(page)
        if page > 0 then
            table.insert(rows, {
                type = ui.TYPE.Widget,
                props = { autoSize = false, size = util.vector2(rowSize.x, verticalGap) },
            })
        end
    end

    local totalHeight = boxSize * visibleHotbars + verticalGap * (visibleHotbars - 1)
    local content = ui.content(rows)

    local anchor = util.vector2(0.5, 1)
    local relativePosition = util.vector2(0.5, 1)
    if settings:get("hotBarOnTop") then
        anchor = util.vector2(0.5, 0)
        relativePosition = util.vector2(0.5, 0)
    end
    if controllerPickMode then
        log("Drawing tooltip")
        drawToolTip()
    end

    log("Creating hotbar UI")

    hotBarElement = ui.create {
        layer = "HUD",
        template = I.MWUI.templates.padding,
        props = {
            anchor = anchor,
            relativePosition = relativePosition,
            arrange = ui.ALIGNMENT.Center,
            align = ui.ALIGNMENT.Center
        },
        content = ui.content {
            {
                type = ui.TYPE.Flex,
                content = content,
                props = {
                    horizontal = false,
                    align = ui.ALIGNMENT.Center,
                    arrange = ui.ALIGNMENT.Center,
                    autoSize = false,
                    size = util.vector2(rowSize.x, totalHeight),
                }
            }
        }
    }

    -- At the end of drawHotbar, mark that we've just redrawn
    needsRedraw = false
    lastUpdateTime = os.time()

    -- Log the end of drawing
    log("==== END drawHotbar ====")
end

-- Simplify the updateFade function to avoid setAlpha calls
local function updateFade(dt)
    -- Skip if fading is disabled
    if not settings:get("enableFadingBars") then
        return
    end

    -- Skip if hotbar is disabled or doesn't exist
    if not enableHotbar or not hotBarElement then
        return
    end

    -- If we're not fading yet, increment the timer
    if not isFading then
        fadeTimer = fadeTimer + dt
        if fadeTimer >= fadeDuration then
            -- Once timer exceeds duration, set fading state
            isFading = true
            fadeTimer = 0
            log("Starting hotbar hide process")
        end
    else
        -- When we're in fading state, just wait a short time and then hide
        fadeTimer = fadeTimer + dt

        -- Once the short delay passes, hide the hotbar
        if fadeTimer >= 0.3 then -- Short delay before hiding
            log("Hiding hotbar")
            -- Simply destroy the element instead of trying to fade it
            if hotBarElement then
                local success, err = pcall(function()
                    hotBarElement:destroy()
                    hotBarElement = nil
                end)
                if not success then
                    log("Error destroying hotbar: " .. tostring(err))
                end
            end
            isFading = false
        end
    end
end

-- Update the resetFade function to avoid setAlpha calls
local function resetFade()
    log("Fade state reset")
    isFading = false
    fadeTimer = 0
    needsRedraw = true

    -- Force immediate redraw only if necessary
    if not hotBarElement then
        -- Check if drawHotbar is available first
        if type(drawHotbar) == "function" then
            drawHotbar()
        else
            log("Error: drawHotbar not available yet")
            needsRedraw = true
        end
    end
end

local data
local function selectSlot(item, spell, enchant)
    pickSlotMode = true
    controllerPickMode = true
    data = { item = item, spell = spell, enchant = enchant }
    drawHotbar()
end
local function saveSlot()
    if pickSlotMode then
        local selectedSlot = selectedNum + (I.QuickSelect.getSelectedPage() * 10)
        if data.item and not data.enchant then
            I.QuickSelect_Storage.saveStoredItemData(data.item, selectedSlot)
        elseif data.spell then
            I.QuickSelect_Storage.saveStoredSpellData(data.spell, "Spell", selectedSlot)
        elseif data.enchant then
            I.QuickSelect_Storage.saveStoredEnchantData(data.enchant, data.item, selectedSlot)
        end

        log("Saved item data to slot " .. selectedSlot)
        pickSlotMode = false
        data = nil

        -- Force redraw to show the newly saved slot
        needsRedraw = true

        -- Use direct call with error handling to redraw immediately
        local success, err = pcall(function()
            drawHotbar()
        end)
        if not success then
            log("Error redrawing hotbar after save: " .. tostring(err))
        end
    end
end
local function UiModeChanged(data)
    if data.newMode then
        if controllerPickMode then
            controllerPickMode = false
            pickSlotMode = false
            drawHotbar()
        end
    else -- no mode (mode ended)
        -- Clean up UI if we're not in our menu mode
        if pickSlotMode then
            -- Keep the hotbar open
        else
            Tooltip.hide()
        end
    end
end
local function selectNextOrPrevHotBar(dir)
    if dir == "next" then
        local num = I.QuickSelect.getSelectedPage() + 1
        if num > 2 then
            num = 0
        end
        I.QuickSelect.setSelectedPage(num)
        I.QuickSelect_Hotbar.drawHotbar()
    elseif dir == "prev" then
        local num = I.QuickSelect.getSelectedPage() - 1
        if num < 0 then
            num = 2
        end
        I.QuickSelect.setSelectedPage(num)
        I.QuickSelect_Hotbar.drawHotbar()
    end
end
local function selectNextOrPrevHotKey(dir)
    if dir == "next" then
        if not controllerPickMode then
            startPickingMode()
            return
        end
        selectedNum = selectedNum + 1
        if selectedNum > 10 then
            selectedNum = 1
        end
        I.QuickSelect_Hotbar.drawHotbar()
    elseif dir == "prev" then
        if not controllerPickMode then
            startPickingMode()
            return
        end
        selectedNum = selectedNum - 1
        if selectedNum < 1 then
            selectedNum = 10
        end
        I.QuickSelect_Hotbar.drawHotbar()
    end
end
local function getNextKey()
    return "="
end

local function getPrevKey()
    return "-"
end

local function isQuickKeysMenuOpen()
    return I.QuickSelect_Win1
        and I.QuickSelect_Win1.isMenuOpen
        and I.QuickSelect_Win1.isMenuOpen()
end

-- Create a settings update callback function
local function onSettingsChanged()
    I.QuickSelect_Hotbar.drawHotbar()
end

-- Subscribe to settings changes
settings:subscribe(async:callback(onSettingsChanged))

-- Add variable to track current UI mode
local currentUiMode = nil

-- Update or add onUpdate function
local function onUpdate(dt)
    -- Handle fade effect if enabled (but don't use alpha)
    if isFading and fadeTimer < fadeDuration then
        fadeTimer = fadeTimer + dt
        -- No alpha changes here
    elseif isFading and fadeTimer >= fadeDuration then
        -- When fade timer is complete, destroy the hotbar
        if hotBarElement then
            local success, err = pcall(function()
                hotBarElement:destroy()
                hotBarElement = nil
            end)
            if not success then
                log("Error destroying hotbar: " .. tostring(err))
            end
        end
        isFading = false
    end

    -- Check HUD visibility and update hotbar accordingly
    local hudVisible = I.UI and I.UI.isHudVisible and I.UI.isHudVisible()

    -- Handle HUD visibility changes
    if hudVisible ~= wasHudVisible then
        -- State changed
        if hudVisible == false then
            -- HUD was just hidden
            if hotBarElement then
                local success, err = pcall(function()
                    hotBarElement:destroy()
                    hotBarElement = nil
                end)
                if not success then
                    log("Error destroying hotbar when HUD is hidden: " .. tostring(err))
                end
            end
        else
            -- HUD was just shown - trigger a redraw
            log("HUD became visible - triggering hotbar redraw")
            needsRedraw = true
        end

        -- Update tracking variable
        wasHudVisible = hudVisible
    elseif hudVisible == false and hotBarElement then
        -- Safety check - if somehow HUD is hidden but hotbar still exists, destroy it
        local success, err = pcall(function()
            hotBarElement:destroy()
            hotBarElement = nil
        end)
        if not success then
            log("Error destroying hotbar when HUD is hidden: " .. tostring(err))
        end
    end

    -- Only update the hotbar when absolutely necessary
    local currentTime = os.time()
    if needsRedraw and hudVisible and (currentTime - lastUpdateTime) > UPDATE_THROTTLE then
        lastUpdateTime = currentTime
        needsRedraw = false
        drawHotbar()
    end
end

return {
    interfaceName = "QuickSelect_Hotbar",
    interface = {
        drawHotbar = function(resetFadeTimer)
            needsRedraw = true
            local success, err = pcall(function()
                drawHotbar(resetFadeTimer)
            end)
            if not success then
                log("Error calling drawHotbar: " .. tostring(err))
            end
        end,
        startPickingMode = startPickingMode,
        endPickingMode = endPickingMode,
        selectSlot = selectSlot,
        saveSlot = saveSlot,
        resetFade = function()
            -- Add a safety wrapper for resetFade too
            local success, err = pcall(function()
                resetFade()
            end)
            if not success then
                log("Error calling resetFade: " .. tostring(err))
            end
        end,
        isHotbarVisible = function()
            return hotBarElement ~= nil
        end,
    },
    eventHandlers = {
        UiModeChanged = UiModeChanged,
    },
    engineHandlers = {
        onLoad = function()
            log("==== Initializing QuickSelect_Hotbar ====")
            Tooltip.ensureLayer()

            -- Initialize settings if they don't exist
            if settings:get("disableIconShrinking") == nil then
                settings:set("disableIconShrinking", true)
            end

            -- Set initial state
            pickSlotMode = false
            controllerPickMode = false
            selectedNum = 1
            currentUiMode = I.UI and I.UI.getMode and I.UI.getMode()

            -- Initial draw with a small delay to ensure all interfaces are registered
            async:newUnsavableSimulationTimer(0.05, function()
                local success, err = pcall(function()
                    drawHotbar()
                end)
                if not success then
                    log("Error in initial draw: " .. tostring(err))
                end
            end)
        end,
        onUpdate = onUpdate,
        onFrame = function(dt)
            local success, err = pcall(function()
                updateFade(dt)
            end)
            if not success then
                log("Error in updateFade: " .. tostring(err))
            end
        end,
        onKeyPress = function(key)
            if isQuickKeysMenuOpen() then
                return
            end
            if core.isWorldPaused() and not controllerPickMode then
                return
            end
            local char = key.symbol
            if not char then
                return
            end
            local nextKey = getNextKey()
            local prevKey = getPrevKey()
            if nextKey and char == nextKey then
                selectNextOrPrevHotBar("next")
            elseif prevKey and char == prevKey then
                selectNextOrPrevHotBar("prev")
            end
        end,
        onControllerButtonPress = function(btn)
            if isQuickKeysMenuOpen() then
                return
            end
            if core.isWorldPaused() and not controllerPickMode then
                return
            end
            if btn == input.CONTROLLER_BUTTON.LeftShoulder or btn == input.CONTROLLER_BUTTON.DPadLeft then
                selectNextOrPrevHotKey("prev")
            elseif btn == input.CONTROLLER_BUTTON.RightShoulder or btn == input.CONTROLLER_BUTTON.DPadRight then
                selectNextOrPrevHotKey("next")
            elseif btn == input.CONTROLLER_BUTTON.DPadDown and controllerPickMode then
                selectNextOrPrevHotBar("next")
            elseif btn == input.CONTROLLER_BUTTON.DPadUp and controllerPickMode then
                if not enableHotbar then
                    return
                end
                selectNextOrPrevHotBar("prev")
            elseif btn == input.CONTROLLER_BUTTON.A and controllerPickMode then
                if not enableHotbar then
                    return
                end
                if pickSlotMode then
                    saveSlot()
                    -- Don't redraw here, saveSlot() already does it
                    return
                end
                I.QuickSelect_Storage.equipSlot(selectedNum + (I.QuickSelect.getSelectedPage() * 10))
                endPickingMode()
            elseif btn == input.CONTROLLER_BUTTON.B then
                if enableHotbar then
                    endPickingMode()
                end
            end
        end
    }
}
