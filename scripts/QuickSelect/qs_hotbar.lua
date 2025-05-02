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

local settings = storage.playerSection("SettingsQuickSelect")
local tooltipData = require("scripts.QuickSelect.ci_tooltipgen")
local utility = require("scripts.QuickSelect.qs_utility")
local hotBarElement
local tooltipElement
local num = 1
local enableHotbar = false       --True if we are showing the hotbar

local pickSlotMode = false       --True if we are picking a slot for saving

local controllerPickMode = false --True if we are picking a slot for equipping OR saving

local selectedNum = 1
local HOTBAR_ITEMS_PER_ROW = 10

local function log(message)
    print("[HOTBAR DEBUG] " .. tostring(message))
end

local function startPickingMode()
    enableHotbar = true
    controllerPickMode = true
    I.QuickSelect_Hotbar.drawHotbar()
    if settings:get("pauseWhenSelecting") then
        I.UI.setMode("LevelUp", { windows = {} })
    end
end
local function endPickingMode()
    enableHotbar = false
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
    if true then
        --   return
    end
    local inv = types.Actor.inventory(self):getAll()
    local offset = I.QuickSelect.getSelectedPage() * 10
    local data = I.QuickSelect_Storage.getFavoriteItemData(selectedNum + offset)

    local item
    local effect
    local icon
    local spell
    if data.item then
        item = types.Actor.inventory(self):find(data.item)
    elseif data.itemId then
        item = types.Actor.inventory(self):find(data.itemId)
    elseif data.spell then
        if data.spellType:lower() == "spell" then
            spell = types.Actor.spells(self)[data.spell]
            if spell then
                spell = spell.id
            end
        elseif data.spellType:lower() == "enchant" then
            local enchant = utility.getEnchantment(data.enchantId)
            if enchant then
                spell = enchant
            end
        end
    end

    if item then
        tooltipElement = utility.drawListMenu(tooltipData.genToolTips(item),
            getToolTipPos(), nil, "HUD")
        -- ui.showMessage("Mouse moving over icon" .. data.item.recordId)
    elseif spell then
        local spellRecord = core.magic.spells.records[spell]

        tooltipElement = utility.drawListMenu(tooltipData.genToolTips({ spell = spellRecord }),
            getToolTipPos(), nil, "HUD")
    end
end
local function createHotbarItem(item, xicon, num, data, half)
    local icon
    local isEquipped = I.QuickSelect_Storage.isSlotEquipped(num)
    local sizeX = utility.iconSize
    local sizeY = utility.iconSize
    local drawNumber = settings:get("showNumbersForEmptySlots")
    local offset = I.QuickSelect.getSelectedPage() * 10
    local selected = (num) == (selectedNum + offset)
    if half then
        sizeY = sizeY / 2
    end
    if item and not xicon then
        icon = I.Controller_Icon_QS.getItemIcon(item, half, selected)
    elseif xicon then
        icon = I.Controller_Icon_QS.getSpellIcon(xicon, half, selected)
    elseif num then
        icon = I.Controller_Icon_QS.getEmptyIcon(half, num, selected, drawNumber)
    end

    -- Add a small margin around the icon to prevent clipping
    local iconPadding = 2 -- 2px padding on each side

    -- Create a box size that's slightly larger than the icon
    local boxSize = util.vector2(sizeX + iconPadding * 2, sizeY + iconPadding * 2)

    -- Create the icon with proper padding to prevent clipping
    local boxedIcon = utility.renderItemBoxed(icon, boxSize, nil,
        util.vector2(0.5, 0.5),
        { item = item, num = num, data = data })

    local paddingTemplate = I.MWUI.templates.padding
    if isEquipped then
        paddingTemplate = I.MWUI.templates.borders
    end

    -- Create the outer padding with a fixed size
    local outerSize = util.vector2(sizeX + iconPadding * 2, sizeY + iconPadding * 2)
    local padding = utility.renderItemBoxed(ui.content { boxedIcon },
        outerSize,
        paddingTemplate, util.vector2(0.5, 0.5))
    return padding
end

-- Create a spacer element with the specified width
local function createSpacerElement(width, half)
    log("Creating spacer: width=" .. width .. ", half=" .. tostring(half))
    local iconPadding = 2 -- Same padding as in createHotbarItem
    local height = half and (utility.iconSize / 2) or utility.iconSize

    -- Add padding to height to match the padded icons
    height = height + (iconPadding * 2)

    -- Create a transparent texture for the spacer
    local transparentTexture = ui.texture({ path = "icons\\quickselect\\selected.tga" })

    return {
        type = ui.TYPE.Container,
        template = I.MWUI.templates.padding, -- Add padding template to make it more visible to layout
        props = {
            size = util.vector2(width, height),
            minSize = util.vector2(width, height),   -- Enforce minimum size
            fixedSize = util.vector2(width, height), -- Try to enforce exact size
            arrange = ui.ALIGNMENT.Center,
            align = ui.ALIGNMENT.Center,
        },
        content = ui.content {
            {
                type = ui.TYPE.Image,
                props = {
                    resource = transparentTexture,
                    size = util.vector2(width, height),
                    alpha = 0.01, -- Very slightly visible for testing
                }
            }
        }
    }
end

local function getHotbarItems(half)
    log("---- BEGIN getHotbarItems ----")
    log("half=" .. tostring(half) .. ", num=" .. num)

    local items = {}
    local inv = types.Actor.inventory(self):getAll()
    local count = num + 10
    local gutterSize = settings:get("hotbarGutterSize") or 5

    log("gutterSize=" .. gutterSize .. ", count=" .. count)

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
                    effect = spell.effects[1]
                    icon = effect.effect.icon
                    log("Spell icon found")
                end
            elseif data.spellType and data.spellType:lower() == "enchant" then
                local enchant = utility.getEnchantment(data.enchantId)
                if enchant then
                    effect = enchant.effects[1]
                    icon = effect.effect.icon
                    log("Enchant icon found")
                end
            end
        else
            log("Empty slot")
        end

        -- Add the hotbar item
        log("Adding hotbar item " .. num)
        table.insert(items, createHotbarItem(item, icon, num, data, half))

        -- Add spacer element if this isn't the last item
        if num < count - 1 and gutterSize > 0 then
            log("Adding spacer after item " .. num)
            table.insert(items, createSpacerElement(gutterSize, half))
        end

        num = num + 1
    end

    log("Created " .. #items .. " elements (items + spacers)")
    log("Initial num=" .. startNum .. ", final num=" .. num)
    log("---- END getHotbarItems ----")

    return items
end

local function drawHotbar()
    log("==== BEGIN drawHotbar ====")

    if hotBarElement then
        log("Destroying existing hotbar")
        hotBarElement:destroy()
    end
    if tooltipElement then
        log("Destroying existing tooltip")
        tooltipElement:destroy()
        tooltipElement = nil
    end
    if not enableHotbar then
        log("Hotbar disabled, exiting")
        log("==== END drawHotbar ====")
        return
    end

    -- Configuration for the hotbar
    local iconSize = utility.iconSize
    local iconPadding = 2                                    -- Same padding as in createHotbarItem
    local paddedIconSize = iconSize + (iconPadding * 2)      -- Account for padding
    local boxSize = paddedIconSize                           -- Use padded icon size
    local gutterSize = settings:get("hotbarGutterSize") or 5 -- Get the gutter size from settings
    local itemsPerRow = HOTBAR_ITEMS_PER_ROW

    log("Config - iconSize: " ..
        iconSize ..
        ", paddedIconSize: " .. paddedIconSize .. ", gutterSize: " .. gutterSize .. ", itemsPerRow: " .. itemsPerRow)

    -- Calculate the width - account for items and spacers
    local itemWidth = boxSize
    local spacerWidth = gutterSize
    local totalItemsWidth = itemWidth * itemsPerRow
    local totalSpacersWidth = spacerWidth * (itemsPerRow - 1)
    local totalWidth = totalItemsWidth + totalSpacersWidth
    -- Use base padding plus gutter-based scaling
    local basePadding = 80               -- Significantly increase base padding to prevent cutoff
    local gutterPadding = gutterSize * 6 -- Additional padding based on gutter size
    local paddingAmount = basePadding + gutterPadding
    local hotbarWidth = totalWidth + paddingAmount
    local hotbarHeight = boxSize + 20

    log("Size - boxSize: " .. boxSize .. ", totalWidth: " .. totalWidth .. ", hotbarWidth: " .. hotbarWidth
        .. ", padding: " .. paddingAmount .. " (base: " .. basePadding .. ", gutter-based: " .. gutterPadding .. ")")

    local xContent = {}
    local content = {}
    num = 1 + (itemsPerRow * I.QuickSelect.getSelectedPage())
    log("Starting num: " .. num .. ", page: " .. I.QuickSelect.getSelectedPage())

    local showExtraHotbars = settings:get("previewOtherHotbars")
    log("Show extra hotbars: " .. tostring(showExtraHotbars))

    if showExtraHotbars then
        if I.QuickSelect.getSelectedPage() > 0 then
            log("Adding previous hotbar")
            num = 1 + (itemsPerRow * (I.QuickSelect.getSelectedPage() - 1))
            -- Previous hotbar (half height if it's not the current one)
            local prevItems = getHotbarItems(true)
            log("Previous hotbar items count: " .. #prevItems)

            table.insert(content,
                utility.renderItemBoxed(
                    utility.flexedItems(prevItems, true, util.vector2(0.5, 0.5)),
                    util.vector2(hotbarWidth, hotbarHeight * 0.8),
                    I.MWUI.templates.padding,
                    util.vector2(0.5, 0.5)))
        end
    end

    -- Current hotbar (full height)
    log("Adding current hotbar")
    local currentItems = getHotbarItems()
    log("Current hotbar items count: " .. #currentItems)

    table.insert(content,
        utility.renderItemBoxed(utility.flexedItems(currentItems, true, util.vector2(0.5, 0.5)),
            util.vector2(hotbarWidth, hotbarHeight),
            I.MWUI.templates.padding,
            util.vector2(0.5, 0.5)))

    if showExtraHotbars then
        if I.QuickSelect.getSelectedPage() < 2 then
            log("Adding next hotbar")
            -- Next hotbar (half height if it's not the current one)
            local nextItems = getHotbarItems(true)
            log("Next hotbar items count: " .. #nextItems)

            table.insert(content,
                utility.renderItemBoxed(
                    utility.flexedItems(nextItems, true, util.vector2(0.5, 0.5)),
                    util.vector2(hotbarWidth, hotbarHeight * 0.8),
                    I.MWUI.templates.padding,
                    util.vector2(0.5, 0.5)))
        end
    end

    content = ui.content(content)
    log("Content elements count: " .. #content)

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
            align = ui.ALIGNMENT.Center,
        },
        content = ui.content {
            {
                type = ui.TYPE.Flex,
                content = content,
                props = {
                    horizontal = false,
                    align = ui.ALIGNMENT.Center,
                    arrange = ui.ALIGNMENT.Center,
                    size = util.vector2(hotbarWidth, hotbarHeight),
                    minSize = util.vector2(hotbarWidth, hotbarHeight),   -- Enforce minimum size
                    fixedSize = util.vector2(hotbarWidth, hotbarHeight), -- Try to enforce fixed size
                }
            }
        }
    }

    log("==== END drawHotbar ====")
end
local data
local function selectSlot(item, spell, enchant)
    enableHotbar = true
    pickSlotMode = true
    controllerPickMode = true
    -- print(item,spell,enchant)
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
        enableHotbar = false
        pickSlotMode = false
        data = nil
    end
end
local function UiModeChanged(data)
    if data.newMode then
        if controllerPickMode and not settings:get("persistMode") then
            if settings:get("pauseWhenSelecting") and data.newMode == "LevelUp" then
                return
            end
            controllerPickMode = false
            pickSlotMode = false
            enableHotbar = false
            drawHotbar()
        elseif settings:get("persistMode") then
            enableHotbar = true
            drawHotbar()
        end
    end
end
local function selectNextOrPrevHotBar(dir)
    if dir == "next" then
        if not enableHotbar then
            return
        end
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
        if not enableHotbar or not controllerPickMode then
            startPickingMode()
            return
        end
        selectedNum = selectedNum + 1
        if selectedNum > 10 then
            selectedNum = 1
        end
        I.QuickSelect_Hotbar.drawHotbar()
    elseif dir == "prev" then
        if not enableHotbar or not controllerPickMode then
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
    local status = settings:get("barSelectionMode")
    if status == "-/= Keys" then
        return "="
    elseif status == "[/] Keys" then
        return "["
    end
end
local function getPrevKey()
    local status = settings:get("barSelectionMode")
    if status == "-/= Keys" then
        return "-"
    elseif status == "[/] Keys" then
        return "]"
    end
end
return {
    --I.QuickSelect_Hotbar.drawHotbar()
    interfaceName = "QuickSelect_Hotbar",
    interface = {
        drawHotbar = drawHotbar,
        selectSlot = selectSlot,
    },
    eventHandlers = {
        UiModeChanged = UiModeChanged,
    },
    engineHandlers = {
        onLoad = function()
            if settings:get("persistMode") then
                enableHotbar = true
                drawHotbar()
            end
        end,
        onKeyPress = function(key)
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
            if settings:get("useArrowKeys") then
                if key.code == input.KEY.RightArrow then
                    selectNextOrPrevHotKey("next")
                elseif key.code == input.KEY.LeftArrow then
                    selectNextOrPrevHotKey("prev")
                elseif key.code == input.KEY.UpArrow then
                    if not enableHotbar then
                        return
                    end
                    selectNextOrPrevHotBar("prev")
                elseif key.code == input.KEY.DownArrow then
                    if not enableHotbar then
                        return
                    end
                    selectNextOrPrevHotBar("next")
                elseif key.code == input.KEY.Enter then
                    if not enableHotbar then
                        return
                    end
                    if pickSlotMode then
                        saveSlot()
                        I.QuickSelect_Hotbar.drawHotbar()
                        return
                    end
                    --  print("EQUP ME"  )
                    I.QuickSelect_Storage.equipSlot(selectedNum + (I.QuickSelect.getSelectedPage() * 10))
                    endPickingMode()
                end
            end
        end,
        onControllerButtonPress = function(btn)
            if core.isWorldPaused() and not controllerPickMode then
                return
            end
            if btn == input.CONTROLLER_BUTTON.LeftShoulder or btn == input.CONTROLLER_BUTTON.DPadLeft then
                selectNextOrPrevHotKey("prev")
            elseif btn == input.CONTROLLER_BUTTON.RightShoulder or btn == input.CONTROLLER_BUTTON.DPadRight then
                selectNextOrPrevHotKey("next")
            elseif btn == input.CONTROLLER_BUTTON.DPadDown and controllerPickMode then
                selectNextOrPrevHotBar("next")
                --  print("down")
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
                    I.QuickSelect_Hotbar.drawHotbar()
                    return
                end
                --  print("EQUP ME"  )
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
