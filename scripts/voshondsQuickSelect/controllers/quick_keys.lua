local async = require("openmw.async")
local core = require("openmw.core")
local I = require("openmw.interfaces")
local input = require("openmw.input")
local self = require("openmw.self")
local storage = require("openmw.storage")
local types = require("openmw.types")
local ui = require("openmw.ui")
local util = require("openmw.util")

local Catalog = require("scripts.voshondsquickselect.services.item_catalog")
local Debug = require("scripts.voshondsquickselect.debug")
local tooltipData = require("scripts.voshondsquickselect.presentation.tooltip_data")
local Button = require("scripts.voshondsquickselect.ui.button")
local Hotbar = require("scripts.voshondsquickselect.ui.hotbar")
local Icon = require("scripts.voshondsquickselect.ui.icon")
local Modal = require("scripts.voshondsquickselect.ui.modal")
local ScrollView = require("scripts.voshondsquickselect.ui.scroll_view")
local SearchBar = require("scripts.voshondsquickselect.ui.search_bar")
local Tooltip = require("scripts.voshondsquickselect.ui.tooltip")
local utility = require("scripts.voshondsquickselect.legacy.utility")

local settings = storage.playerSection("SettingsVoshondsQuickSelect")
local selectionSettings = storage.playerSection("SettingsVoshondsQuickSelectSelection")
local textSettings = storage.playerSection("SettingsVoshondsQuickSelectText")

local VIEW = {
    Hotbars = "hotbars",
    SlotActions = "slotActions",
    Inventory = "inventory",
    Magic = "magic",
}

local window
local scrollView
local currentView = VIEW.Hotbars
local slotToSave
local query = ""
local searchHasFocus = false
local menuIsOpen = false
local catalogEntries = {}
local tooltipTarget
local selectorListHost
local selectorSummary
local selectorSearchInput
local selectorMetrics

local drawQuickSelect
local drawSlotActions
local drawSelector

local function textStyles()
    local color = textSettings:get("slotTextColor") or util.color.rgba(0.792, 0.647, 0.376, 1)
    local shadowColor = textSettings:get("slotTextShadowColor") or util.color.rgba(0, 0, 0, 1)
    local textAlpha = (textSettings:get("slotTextAlpha") or 100) / 100
    local shadowAlpha = (textSettings:get("slotTextShadowAlpha") or 100) / 100
    local shadowEnabled = textSettings:get("enableTextShadow")
    if shadowEnabled == nil then
        shadowEnabled = true
    end

    return {
        color = util.color.rgba(color.r, color.g, color.b, textAlpha),
        shadowColor = util.color.rgba(shadowColor.r, shadowColor.g, shadowColor.b, shadowAlpha),
        shadowEnabled = shadowEnabled,
        itemCountSize = textSettings:get("itemCountTextSize") or 12,
    }
end

local function destroyWindow()
    Tooltip.hide()
    tooltipTarget = nil

    if window then
        window:destroy()
        window = nil
    end

    if scrollView then
        ScrollView.destroy(scrollView)
        scrollView = nil
    end

    selectorListHost = nil
    selectorSummary = nil
    selectorSearchInput = nil
    selectorMetrics = nil
end

local function resetState()
    currentView = VIEW.Hotbars
    slotToSave = nil
    query = ""
    searchHasFocus = false
    catalogEntries = {}
    menuIsOpen = false
end

local function clearTooltip()
    tooltipTarget = nil
    Tooltip.hide()
end

local function closeMenu()
    destroyWindow()
    resetState()
    I.UI.setMode()
end

local function createText(text, params)
    params = params or {}
    return {
        type = ui.TYPE.Text,
        template = params.template or I.MWUI.templates.textNormal,
        props = {
            text = text,
            textSize = params.textSize or 16,
            size = params.size,
            textColor = params.textColor,
            textAlignH = params.textAlignH,
            textAlignV = params.textAlignV,
        },
    }
end

local function resolveSlot(slot)
    local data = I.QuickSelect_Storage.getFavoriteItemData(slot) or {}
    local item
    local path

    if data.item then
        item = types.Actor.inventory(self):find(data.item)
    elseif data.itemId then
        item = types.Actor.inventory(self):find(data.itemId)
    end

    if data.spellType and string.lower(data.spellType) == "spell" and data.spell then
        path = Catalog.magicIcon(types.Actor.spells(self)[data.spell])
    elseif data.enchantId then
        path = Catalog.magicIcon(core.magic.enchantments.records[data.enchantId])
    end

    return data, item, path
end

local function showSlotTooltip(event, layout)
    local target = "slot:" .. tostring(layout.userData.slot)
    if tooltipTarget == target then
        return
    end
    tooltipTarget = target

    local data, item = resolveSlot(layout.userData.slot)
    local lines

    if item then
        lines = tooltipData.genToolTips(item)
    elseif data.spell then
        local spell = core.magic.spells.records[data.spell] or types.Actor.spells(self)[data.spell]
        if spell then
            lines = tooltipData.genToolTips({ spell = spell })
        end
    end

    if lines then
        Tooltip.show(lines, { position = event.position })
    else
        clearTooltip()
    end
end

local function onSlotClick(_, layout)
    clearTooltip()
    slotToSave = layout.userData.slot
    currentView = VIEW.SlotActions
    drawSlotActions()
end

local function createSlot(slot, iconSize)
    local data, item, path = resolveSlot(slot)
    local prefix = ""
    if slot > 20 then
        prefix = "c"
    elseif slot > 10 then
        prefix = "s"
    end

    local content
    if item then
        content = I.Controller_Icon_QS.getItemIcon(item, false, false, slot, prefix, data)
    elseif path then
        content = I.Controller_Icon_QS.getSpellIcon(path, false, false, slot, prefix)
    else
        content = I.Controller_Icon_QS.getEmptyIcon(false, slot, false, true, prefix)
    end

    local iconPadding = 2
    local boxSize = iconSize + iconPadding * 2
    local boxedIcon = utility.renderItemBoxed(
        content,
        util.vector2(boxSize, boxSize),
        nil,
        util.vector2(0.5, 0.5),
        { slot = slot }
    )

    local iconContent = ui.content({ boxedIcon })
    if I.QuickSelect_Storage.isSlotEquipped(slot) then
        iconContent:add({
            type = ui.TYPE.Image,
            props = {
                resource = Icon.texture("textures/voshondsQuickSelect/equipped_indicator.dds"),
                size = util.vector2(16, 16),
                position = util.vector2(0, boxSize - 16),
            },
        })
    end

    -- Keep the quick-key window slot visually identical to the HUD slot.  The
    -- bordered box is the slot frame; a second padding wrapper would make a
    -- zero configured gutter visibly non-zero.
    return {
        type = ui.TYPE.Widget,
        props = { autoSize = false, size = util.vector2(boxSize, boxSize) },
        userData = { slot = slot },
        events = {
            mouseMove = async:callback(showSlotTooltip),
            mouseLeave = async:callback(clearTooltip),
            focusLoss = async:callback(clearTooltip),
            mouseClick = async:callback(onSlotClick),
        },
        content = iconContent,
    }
end

local function hotbarRow(page, iconSize, gap)
    local slots = {}
    for index = 1, 10 do
        table.insert(slots, createSlot(page * 10 + index, iconSize))
    end

    return Hotbar.create({
        name = "hotbar" .. tostring(page + 1),
        slots = slots,
        slotSize = iconSize + 4,
        gap = gap,
        align = ui.ALIGNMENT.Start,
        arrange = ui.ALIGNMENT.Start,
    })
end

local function goToHotbars()
    resetState()
    drawQuickSelect()
end

drawQuickSelect = function()
    destroyWindow()

    currentView = VIEW.Hotbars
    menuIsOpen = true
    local iconSize = settings:get("iconSize") or 40
    local gap = settings:get("hotbarGutterSize") or 5
    local barSize = Hotbar.measure(10, iconSize + 4, iconSize + 4, gap)
    local width = barSize.x + 64
    local instructions = core.getGMST("sQuickMenuInstruc"):gsub(",%s*", ",\n")
    local content = {}
    local labels = {
        "Hotbar 1 (1-0)",
        "Hotbar 2 (Shift 1-0)",
        "Hotbar 3 (Ctrl 1-0)",
    }

    for page = 0, 2 do
        table.insert(content, createText(labels[page + 1], {
            textSize = 18,
            size = util.vector2(width, 28),
            textAlignH = ui.ALIGNMENT.Center,
            textAlignV = ui.ALIGNMENT.Center,
        }))
        table.insert(content, hotbarRow(page, iconSize, gap))
    end

    window = ui.create(Modal.create({
        width = width,
        title = core.getGMST("sQuickMenuTitle"),
        subtitle = instructions,
        subtitleHeight = 48,
        content = content,
    }))
end

local function beginSelector(view)
    currentView = view
    query = ""
    searchHasFocus = false
    catalogEntries = view == VIEW.Inventory and Catalog.inventory() or Catalog.magic()
    Debug.items("Built " .. view .. " catalog with " .. tostring(#catalogEntries) .. " entries")
    drawSelector()
end

local function deleteSlot()
    I.QuickSelect_Storage.deleteStoredItemData(slotToSave)
    closeMenu()
end

drawSlotActions = function()
    destroyWindow()

    currentView = VIEW.SlotActions
    local width = 380
    local buttonSize = util.vector2(width - 48, 38)
    local content = {
        Button.create({
            text = core.getGMST("sQuickMenu2"),
            size = buttonSize,
            onClick = function()
                beginSelector(VIEW.Inventory)
            end,
        }),
        Button.create({
            text = core.getGMST("sQuickMenu3"),
            size = buttonSize,
            onClick = function()
                beginSelector(VIEW.Magic)
            end,
        }),
        Button.create({
            text = core.getGMST("sQuickMenu4"),
            size = buttonSize,
            onClick = deleteSlot,
        }),
        Button.create({
            text = core.getGMST("sCancel"),
            size = buttonSize,
            onClick = goToHotbars,
        }),
    }

    window = ui.create(Modal.create({
        width = width,
        title = "Quick Key " .. tostring(slotToSave),
        subtitle = core.getGMST("sQuickMenu1"),
        content = content,
    }))
end

local function entryTooltip(event, layout)
    local entry = layout.userData.entry
    if tooltipTarget == entry then
        return
    end
    tooltipTarget = entry

    local lines

    if entry.item then
        lines = tooltipData.genToolTips(entry.item)
    elseif entry.spell then
        local record = core.magic.spells.records[entry.id] or entry.spell
        if record then
            lines = tooltipData.genToolTips({ spell = record })
        end
    end

    if lines then
        Tooltip.show(lines, { position = event.position })
    else
        clearTooltip()
    end
end

local function selectEntry(_, layout)
    local entry = layout.userData.entry
    clearTooltip()

    if entry.kind == "item" then
        I.QuickSelect_Storage.saveStoredItemData(entry.item.recordId, slotToSave)
    elseif entry.kind == "spell" then
        I.QuickSelect_Storage.saveStoredSpellData(entry.id, "Spell", slotToSave)
    elseif entry.kind == "enchantment" then
        I.QuickSelect_Storage.saveStoredEnchantData(entry.enchantmentId, entry.item.recordId, slotToSave)
    end

    closeMenu()
end

local function countText(entry)
    if not entry.count or entry.count <= 1 then
        return nil
    end

    local styles = textStyles()
    return {
        text = entry.count,
        textSize = styles.itemCountSize,
        textColor = styles.color,
        textShadow = styles.shadowEnabled,
        textShadowColor = styles.shadowColor,
        relativePosition = util.vector2(0.08, 0.05),
        anchor = util.vector2(0.08, 0.05),
        arrange = ui.ALIGNMENT.Start,
        align = ui.ALIGNMENT.Start,
    }
end

local function createInventoryIcon(entry, iconSize)
    local backgrounds = {}
    if entry.enchanted then
        table.insert(backgrounds, {
            path = "textures/menu_icon_magic_mini.dds",
            alpha = 0.3,
        })
    end

    local texts = {}
    local count = countText(entry)
    if count then
        table.insert(texts, count)
    end

    return Icon.create({
        size = iconSize,
        path = entry.icon,
        backgrounds = backgrounds,
        texts = texts,
        userData = { entry = entry },
        events = {
            mouseMove = async:callback(entryTooltip),
            mouseLeave = async:callback(clearTooltip),
            focusLoss = async:callback(clearTooltip),
            mouseClick = async:callback(selectEntry),
        },
    })
end

local function createInventoryContent(entries, iconSize, columns, gap, panelWidth)
    local rows = {}
    local rowHeight = iconSize + gap
    local rowCount = math.max(1, math.ceil(#entries / columns))

    if #entries == 0 then
        table.insert(rows, createText("No matching items", {
            size = util.vector2(panelWidth, rowHeight),
            textAlignH = ui.ALIGNMENT.Center,
            textAlignV = ui.ALIGNMENT.Center,
        }))
    else
        for row = 1, rowCount do
            local slots = {}
            local first = (row - 1) * columns + 1
            local last = math.min(#entries, first + columns - 1)
            for index = first, last do
                table.insert(slots, createInventoryIcon(entries[index], iconSize))
            end
            table.insert(rows, Hotbar.create({
                slots = slots,
                slotSize = iconSize,
                gap = gap,
                size = util.vector2(panelWidth, rowHeight),
                align = ui.ALIGNMENT.Start,
                arrange = ui.ALIGNMENT.Start,
            }))
        end
    end

    return {
        type = ui.TYPE.Flex,
        props = {
            autoSize = false,
            horizontal = false,
            size = util.vector2(panelWidth, rowCount * rowHeight),
            align = ui.ALIGNMENT.Start,
        },
        content = ui.content(rows),
    }, rowHeight
end

local function magicCategory(name, width, height)
    return createText(name, {
        template = I.MWUI.templates.textHeader,
        textSize = 17,
        size = util.vector2(width, height),
        textAlignH = ui.ALIGNMENT.Start,
        textAlignV = ui.ALIGNMENT.Center,
    })
end

local function createMagicEntry(entry, width, height)
    return {
        type = ui.TYPE.Container,
        template = I.MWUI.templates.borders,
        props = {
            autoSize = false,
            size = util.vector2(width, height),
            propagateEvents = false,
        },
        userData = { entry = entry },
        events = {
            mouseMove = async:callback(entryTooltip),
            mouseLeave = async:callback(clearTooltip),
            focusLoss = async:callback(clearTooltip),
            mouseClick = async:callback(selectEntry),
        },
        content = ui.content({
            {
                type = ui.TYPE.Flex,
                props = {
                    autoSize = false,
                    horizontal = true,
                    size = util.vector2(width, height),
                    align = ui.ALIGNMENT.Start,
                    arrange = ui.ALIGNMENT.Start,
                },
                content = ui.content({
                    Icon.create({
                        size = height - 6,
                        path = entry.icon,
                        template = I.MWUI.templates.padding,
                    }),
                    createText(entry.name, {
                        textSize = 17,
                        size = util.vector2(width - height, height),
                        textAlignH = ui.ALIGNMENT.Start,
                        textAlignV = ui.ALIGNMENT.Center,
                    }),
                }),
            },
        }),
    }
end

local function createMagicContent(entries, panelWidth)
    local rowHeight = selectionSettings:get("selectionMagicRowHeight") or 38
    local rows = {}
    local currentCategory

    if #entries == 0 then
        table.insert(rows, createText("No matching spells or enchantments", {
            size = util.vector2(panelWidth, rowHeight),
            textAlignH = ui.ALIGNMENT.Center,
            textAlignV = ui.ALIGNMENT.Center,
        }))
    else
        for _, entry in ipairs(entries) do
            if entry.category ~= currentCategory then
                currentCategory = entry.category
                table.insert(rows, magicCategory(currentCategory, panelWidth, rowHeight))
            end
            table.insert(rows, createMagicEntry(entry, panelWidth, rowHeight))
        end
    end

    return {
        type = ui.TYPE.Flex,
        props = {
            autoSize = false,
            horizontal = false,
            size = util.vector2(panelWidth, math.max(1, #rows) * rowHeight),
            align = ui.ALIGNMENT.Start,
        },
        content = ui.content(rows),
    }, rowHeight
end

local function selectorScrollParams(entries)
    local content
    local itemHeight
    if currentView == VIEW.Inventory then
        content, itemHeight = createInventoryContent(
            entries,
            selectorMetrics.iconSize,
            selectorMetrics.columns,
            selectorMetrics.gap,
            selectorMetrics.contentWidth
        )
    else
        content, itemHeight = createMagicContent(entries, selectorMetrics.contentWidth)
    end

    return {
        width = selectorMetrics.panelWidth,
        height = selectorMetrics.panelHeight,
        content = content,
        itemHeight = itemHeight,
    }
end

local function buildSelectorScroll(entries)
    return ScrollView.create(selectorScrollParams(entries))
end

local function refreshSelectorResults()
    if not window or not selectorMetrics then
        drawSelector()
        return
    end

    local entries = Catalog.filter(catalogEntries, query)
    Debug.items("Rendering " .. currentView .. " selector with " .. tostring(#entries) ..
        " results for query '" .. query .. "'")
    -- The scroll view retains its outer Element while its content and
    -- scrollbar are replaced.  This avoids recreating the modal and its
    -- focused search field.
    scrollView = ScrollView.replace(scrollView, selectorScrollParams(entries))
    selectorSummary.props.text = tostring(#entries) .. " result" .. (#entries == 1 and "" or "s")
    window:update()
end

local function updateSearch(value)
    value = value or ""
    if value == query then
        return
    end
    query = value
    -- Keep the TextEdit instance alive while results change.  Recreating it
    -- here used to drop keyboard focus after every character.
    refreshSelectorResults()
end

local function clearSearch()
    if query == "" then
        return
    end
    query = ""
    SearchBar.setText(selectorSearchInput, query)
    refreshSelectorResults()
end

drawSelector = function()
    destroyWindow()

    local iconSize = settings:get("iconSize") or 40
    local columns = selectionSettings:get("selectionColumns") or 10
    local visibleRows = selectionSettings:get("selectionVisibleRows") or 6
    local magicRows = selectionSettings:get("selectionMagicVisibleRows") or 12
    local gap = selectionSettings:get("selectionItemSpacing") or 4
    local scrollbarWidth = 14
    local screen = ui.screenSize()
    local maximumContentWidth = math.max(360, screen.x - 120 - scrollbarWidth)
    local maximumColumns = math.max(1, math.floor((maximumContentWidth + gap) / (iconSize + gap)))
    columns = math.min(columns, maximumColumns)
    local contentWidth = math.max(360, columns * iconSize + math.max(0, columns - 1) * gap)
    local panelWidth = contentWidth + scrollbarWidth
    local rowHeight = currentView == VIEW.Inventory
        and iconSize + gap
        or (selectionSettings:get("selectionMagicRowHeight") or 38)
    local panelHeight
    if currentView == VIEW.Inventory then
        visibleRows = math.max(1, math.min(visibleRows, math.floor((screen.y - 220) / rowHeight)))
        panelHeight = visibleRows * rowHeight
    else
        magicRows = math.max(1, math.min(magicRows, math.floor((screen.y - 220) / rowHeight)))
        panelHeight = magicRows * rowHeight
    end

    selectorMetrics = {
        iconSize = iconSize,
        columns = columns,
        gap = gap,
        contentWidth = contentWidth,
        panelWidth = panelWidth,
        panelHeight = panelHeight,
    }

    local entries = Catalog.filter(catalogEntries, query)
    Debug.items("Rendering " .. currentView .. " selector with " .. tostring(#entries) ..
        " results for query '" .. query .. "'")
    scrollView = buildSelectorScroll(entries)

    local title = currentView == VIEW.Inventory and core.getGMST("sQuickMenu6") or core.getGMST("sMagicSelectTitle")
    selectorSummary = createText(tostring(#entries) .. " result" .. (#entries == 1 and "" or "s"), {
        size = util.vector2(panelWidth, 24),
        textAlignH = ui.ALIGNMENT.Center,
        textAlignV = ui.ALIGNMENT.Center,
    })
    local searchBar = SearchBar.create({
        width = panelWidth,
        text = query,
        onChanged = updateSearch,
        onFocusChanged = function(focused)
            searchHasFocus = focused
        end,
    })
    selectorSearchInput = SearchBar.getInput(searchBar)
    selectorListHost = {
        type = ui.TYPE.Container,
        template = I.MWUI.templates.boxSolid,
        props = {
            autoSize = false,
            size = util.vector2(panelWidth, panelHeight),
        },
        content = ui.content({ scrollView }),
    }
    local footer = {
        type = ui.TYPE.Flex,
        props = {
            autoSize = false,
            horizontal = true,
            size = util.vector2(panelWidth, 42),
            align = ui.ALIGNMENT.Center,
            arrange = ui.ALIGNMENT.End,
        },
        content = ui.content({
            Button.create({
                text = "Clear",
                size = util.vector2(100, 34),
                onClick = clearSearch,
            }),
            Button.create({
                text = core.getGMST("sCancel"),
                size = util.vector2(120, 34),
                onClick = drawSlotActions,
            }),
        }),
    }

    window = ui.create(Modal.create({
        width = panelWidth,
        title = title,
        content = {
            selectorSummary,
            searchBar,
            selectorListHost,
            footer,
        },
    }))
end

local function handleSearchKey(key)
    if currentView ~= VIEW.Inventory and currentView ~= VIEW.Magic then
        return false
    end

    if key.code == input.KEY.Backspace then
        -- Let a focused TextEdit process Backspace itself.  It emits
        -- textChanged, which updates the results list without recreating the
        -- field.  The fallback below is for keyboard/controller search before
        -- the TextEdit has focus.
        if searchHasFocus then
            return false
        end
        if #query > 0 then
            query = string.sub(query, 1, #query - 1)
            SearchBar.setText(selectorSearchInput, query)
            refreshSelectorResults()
        end
        return true
    end

    if searchHasFocus or key.withCtrl or key.withAlt or key.withSuper then
        return false
    end

    if key.symbol and key.symbol ~= "" then
        query = query .. key.symbol
        SearchBar.setText(selectorSearchInput, query)
        refreshSelectorResults()
        return true
    end

    return false
end

local function onKeyPress(key)
    if not window then
        return
    end

    if key.code == input.KEY.Escape then
        if currentView == VIEW.Inventory or currentView == VIEW.Magic then
            if query ~= "" then
                clearSearch()
            else
                drawSlotActions()
            end
        elseif currentView == VIEW.SlotActions then
            goToHotbars()
        end
        return
    end

    return handleSearchKey(key)
end

local function onControllerButtonPress(button)
    if not window then
        return
    end

    if button == input.CONTROLLER_BUTTON.B then
        if currentView == VIEW.Inventory or currentView == VIEW.Magic then
            drawSlotActions()
        elseif currentView == VIEW.SlotActions then
            goToHotbars()
        else
            closeMenu()
        end
    end
end

local function onMouseWheel(vertical)
    if not scrollView or vertical == 0 then
        return
    end

    local direction = vertical / math.abs(vertical)
    ScrollView.scroll(scrollView, -direction * 3)
end

local function uiModeChanged(data)
    if data.newMode then
        return
    end

    destroyWindow()
    resetState()
    if I.QuickSelect_Hotbar then
        I.QuickSelect_Hotbar.drawHotbar()
    end
end

local function buttonClicked(data)
    if not slotToSave then
        return
    end

    if data.text == core.getGMST("sQuickMenu2") then
        beginSelector(VIEW.Inventory)
    elseif data.text == core.getGMST("sQuickMenu3") then
        beginSelector(VIEW.Magic)
    elseif data.text == core.getGMST("sQuickMenu4") then
        deleteSlot()
    elseif data.text == core.getGMST("sCancel") then
        goToHotbars()
    end
end

I.UI.registerWindow(I.UI.WINDOW.QuickKeys, drawQuickSelect, function()
    destroyWindow()
    resetState()
end)

local function onSettingsChanged()
    if not window then
        return
    end

    if currentView == VIEW.Hotbars then
        drawQuickSelect()
    elseif currentView == VIEW.SlotActions then
        drawSlotActions()
    else
        drawSelector()
    end
end

settings:subscribe(async:callback(onSettingsChanged))
selectionSettings:subscribe(async:callback(onSettingsChanged))
textSettings:subscribe(async:callback(onSettingsChanged))

return {
    interfaceName = "QuickSelect_Win1",
    interface = {
        drawQuickSelect = drawQuickSelect,
        openQuickSelect = drawQuickSelect,
        getQuickSelectWindow = function()
            return window
        end,
        isMenuOpen = function()
            return menuIsOpen
        end,
    },
    eventHandlers = {
        UiModeChanged = uiModeChanged,
        drawQuickSelect = drawQuickSelect,
        openQuickSelect = drawQuickSelect,
        ButtonClicked = buttonClicked,
    },
    engineHandlers = {
        onLoad = function()
            Tooltip.ensureLayer()
            Debug.items("QuickSelect UI components initialized")
        end,
        onKeyPress = onKeyPress,
        onControllerButtonPress = onControllerButtonPress,
        onMouseWheel = onMouseWheel,
    },
}
