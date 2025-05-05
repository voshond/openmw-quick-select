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
local tooltipData = require("scripts.voshondsQuickSelect.ci_tooltipgen")
local utility = require("scripts.voshondsQuickSelect.qs_utility")

-- Create a dedicated tooltip layer on top of everything else
local function initTooltipLayer()
    -- Check if the layer already exists to avoid errors
    local tooltipLayerExists = false
    for i, layer in ipairs(ui.layers) do
        if layer.name == "TooltipLayer" then
            tooltipLayerExists = true
            break
        end
    end

    if not tooltipLayerExists then
        -- Wrap layer creation in pcall to catch errors
        local success, err = pcall(function()
            local layerCount = #ui.layers
            if layerCount > 0 then
                -- Add it after the topmost existing layer
                local topLayerName = ui.layers[layerCount].name
                ui.layers.insertAfter(topLayerName, "TooltipLayer", { interactive = false })
            else
                -- If no layers exist yet (unlikely), create a Windows layer and insert after it
                if not ui.layers.indexOf("Windows") then
                    -- Create a Windows layer first if it doesn't exist
                    ui.layers.insertAfter("HUD", "Windows", { interactive = true })
                end
                ui.layers.insertAfter("Windows", "TooltipLayer", { interactive = false })
            end
        end)

        -- If creation failed, log a message but continue without error
        if not success then
            log("TooltipLayer creation failed: " .. tostring(err))
        end
    else
        log("TooltipLayer already exists, skipping creation")
    end
end

-- Don't initialize immediately, will be initialized in onLoad instead
-- initTooltipLayer()

local hotBarElement
local tooltipElement
local num = 1
local enableHotbar = false       --True if we are showing the hotbar

local pickSlotMode = false       --True if we are picking a slot for saving

local controllerPickMode = false --True if we are picking a slot for equipping OR saving

local selectedNum = 1
local HOTBAR_ITEMS_PER_ROW = 10

-- Remove the early initialization code
-- Let's initialize in onLoad instead

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

    -- Choose the layer to use - check if TooltipLayer exists, otherwise fall back to HUD
    local layerToUse = "HUD"
    local tooltipLayerExists = false
    for i, layer in ipairs(ui.layers) do
        if layer.name == "TooltipLayer" then
            layerToUse = "TooltipLayer"
            tooltipLayerExists = true
            break
        end
    end

    if not tooltipLayerExists then
        log("TooltipLayer not found, using HUD layer instead")
    end

    if item then
        tooltipElement = utility.drawListMenu(tooltipData.genToolTips(item),
            getToolTipPos(), nil, layerToUse)
        -- ui.showMessage("Mouse moving over icon" .. data.item.recordId)
    elseif spell then
        local spellRecord = core.magic.spells.records[spell]

        tooltipElement = utility.drawListMenu(tooltipData.genToolTips({ spell = spellRecord }),
            getToolTipPos(), nil, layerToUse)
    end
end
local function createHotbarItem(item, xicon, num, data, half)
    local icon
    local isEquipped = I.QuickSelect_Storage.isSlotEquipped(num)
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
        icon = I.Controller_Icon_QS.getItemIcon(item, half, useSelectedState, num, slotPrefix)
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

    -- Always use padding template to maintain consistent layout
    local paddingTemplate = I.MWUI.templates.padding

    -- Create an equipped indicator if needed
    local iconContent
    if isEquipped then
        -- Create a border overlay that doesn't affect layout
        local borderTexture = ui.texture({ path = "icons\\voshondsQuickSelect\\selected.tga" })

        -- Wrap the boxedIcon with a container that includes both the icon and an overlay border
        iconContent = ui.content {
            boxedIcon,
            {
                type = ui.TYPE.Container,
                props = {
                    size = boxSize,
                    position = util.vector2(0, 0),
                    arrange = ui.ALIGNMENT.Center,
                    align = ui.ALIGNMENT.Center,
                },
                content = ui.content {
                    {
                        type = ui.TYPE.Image,
                        props = {
                            resource = borderTexture,
                            size = util.vector2(sizeX + iconPadding * 2, 2),
                            position = util.vector2(0, (sizeY - 2) + iconPadding * 2),
                            arrange = ui.ALIGNMENT.End,
                            align = ui.ALIGNMENT.End,
                            border = 1,
                            alpha = 1,
                            color = util.color.rgb(0, 1, 0), -- Green highlight for equipped items
                        }
                    }
                }
            }
        }
    else
        iconContent = ui.content { boxedIcon }
    end

    -- Create the outer padding with a fixed size - always use padding template
    local outerSize = util.vector2(sizeX + iconPadding * 2, sizeY + iconPadding * 2)
    local padding = utility.renderItemBoxed(iconContent,
        outerSize,
        paddingTemplate, util.vector2(0.5, 0.5))
    return padding
end

-- Create a spacer element with the specified width
local function createSpacerElement(width, half)
    log("Creating spacer: width=" .. width .. ", half=" .. tostring(half))
    local iconPadding = 2 -- Same padding as in createHotbarItem
    local height = half and (utility.getIconSize() / 2) or utility.getIconSize()

    -- Add padding to height to match the padded icons
    height = height + (iconPadding * 2)

    -- Create a transparent texture for the spacer
    local transparentTexture = ui.texture({ path = "icons\\voshondsQuickSelect\\selected.tga" })

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
    local iconSize = utility.getIconSize()
    local iconPadding = 2                                               -- Same padding as in createHotbarItem
    local paddedIconSize = iconSize + (iconPadding * 2)                 -- Account for padding
    local boxSize = paddedIconSize                                      -- Use padded icon size
    local gutterSize = settings:get("hotbarGutterSize") or 5            -- Get the gutter size from settings
    local verticalSpacing = settings:get("hotbarVerticalSpacing") or 60 -- Get vertical spacing from settings
    local itemsPerRow = HOTBAR_ITEMS_PER_ROW

    log("Config - iconSize: " ..
        iconSize ..
        ", paddedIconSize: " .. paddedIconSize .. ", gutterSize: " .. gutterSize ..
        ", verticalSpacing: " .. verticalSpacing ..
        ", itemsPerRow: " .. itemsPerRow)

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
    log("Starting page: " .. I.QuickSelect.getSelectedPage())

    local visibleHotbars = settings:get("visibleHotbars")
    log("Visible hotbars: " .. tostring(visibleHotbars))

    if visibleHotbars > 1 then
        -- Render multiple bars stacked in reverse order based on visibleHotbars setting
        -- Scale bar height based on vertical spacing setting
        local heightScale = math.max(0.1, verticalSpacing / 100) -- Convert to percentage, min 10%

        -- Calculate margin height based on vertical spacing (lower = less margin)
        local marginHeight = math.max(1, math.floor(verticalSpacing / 10))

        -- Bar 3 (top) - Only shown when visibleHotbars is 3
        if visibleHotbars == 3 then
            num = 1 + (itemsPerRow * 2) -- Page 2 (third bar)
            log("Adding bar 3 (top)")
            local bar3Items = getHotbarItems()
            log("Bar 3 items count: " .. #bar3Items)

            table.insert(content,
                utility.renderItemBoxed(
                    utility.flexedItems(bar3Items, true, util.vector2(0.5, 0.5)),
                    util.vector2(hotbarWidth, hotbarHeight * heightScale),
                    I.MWUI.templates.padding,
                    util.vector2(0.5, 0.5)))

            -- Add a margin element between bar 3 and bar 2
            if marginHeight > 1 then
                table.insert(content, {
                    type = ui.TYPE.Container,
                    props = {
                        size = util.vector2(hotbarWidth, marginHeight),
                        minSize = util.vector2(hotbarWidth, marginHeight),
                        fixedSize = util.vector2(hotbarWidth, marginHeight)
                    }
                })
            end
        end

        -- Bar 2 (middle) - Shown when visibleHotbars is 2 or 3
        num = 1 + (itemsPerRow * 1) -- Page 1 (second bar)
        log("Adding bar 2 (middle)")
        local bar2Items = getHotbarItems()
        log("Bar 2 items count: " .. #bar2Items)

        table.insert(content,
            utility.renderItemBoxed(
                utility.flexedItems(bar2Items, true, util.vector2(0.5, 0.5)),
                util.vector2(hotbarWidth, hotbarHeight * heightScale),
                I.MWUI.templates.padding,
                util.vector2(0.5, 0.5)))

        -- Add a margin element between bar 2 and bar 1
        if marginHeight > 1 then
            table.insert(content, {
                type = ui.TYPE.Container,
                props = {
                    size = util.vector2(hotbarWidth, marginHeight),
                    minSize = util.vector2(hotbarWidth, marginHeight),
                    fixedSize = util.vector2(hotbarWidth, marginHeight)
                }
            })
        end
    end

    -- Bar 1 (bottom) - Always show current bar
    num = 1 + (itemsPerRow * 0) -- Page 0 (first bar)
    log("Adding bar 1 (bottom)")
    local bar1Items = getHotbarItems()
    log("Bar 1 items count: " .. #bar1Items)

    -- Apply the same height scaling to the main bar when vertical spacing is low
    local mainBarHeight = hotbarHeight
    if visibleHotbars > 1 and verticalSpacing < 70 then
        local heightScale = math.max(0.1, verticalSpacing / 100) -- Use the same scale as other bars
        mainBarHeight = hotbarHeight * heightScale
    end

    table.insert(content,
        utility.renderItemBoxed(
            utility.flexedItems(bar1Items, true, util.vector2(0.5, 0.5)),
            util.vector2(hotbarWidth, mainBarHeight),
            I.MWUI.templates.padding,
            util.vector2(0.5, 0.5)))

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

    -- Calculate total height based on how many bars are showing
    local totalHeight = hotbarHeight
    if visibleHotbars > 1 then
        -- Calculate height based on vertical spacing setting
        local heightScale = math.max(0.1, verticalSpacing / 100) -- Convert to percentage, min 10%

        -- Calculate margin height based on vertical spacing
        local marginHeight = math.max(1, math.floor(verticalSpacing / 10))

        -- Use scaled height for all bars when vertical spacing is low
        if verticalSpacing < 70 then
            -- Calculate based on number of visible hotbars
            totalHeight = (hotbarHeight * heightScale * visibleHotbars) + (marginHeight * (visibleHotbars - 1))
        else
            -- For bar 1 use full height, for additional bars use scaled height
            totalHeight = hotbarHeight + (hotbarHeight * heightScale * (visibleHotbars - 1)) +
                (marginHeight * (visibleHotbars - 1))
        end

        -- Create a smaller container when vertical spacing is very low
        if verticalSpacing < 30 then
            totalHeight = totalHeight * 0.9
        end
    end

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
                    size = util.vector2(hotbarWidth, totalHeight),
                    minSize = util.vector2(hotbarWidth, totalHeight),   -- Enforce minimum size
                    fixedSize = util.vector2(hotbarWidth, totalHeight), -- Try to enforce fixed size
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

-- Create a settings update callback function
local function onSettingsChanged()
    -- Only redraw the hotbar if it's visible
    if enableHotbar then
        I.QuickSelect_Hotbar.drawHotbar()
    end
end

-- Subscribe to settings changes
settings:subscribe(async:callback(onSettingsChanged))

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
            -- Initialize settings if they don't exist
            if settings:get("disableIconShrinking") == nil then
                settings:set("disableIconShrinking", true)
            end

            -- Initialize tooltip layer only once at startup
            initTooltipLayer()

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
        end,
    }
}
