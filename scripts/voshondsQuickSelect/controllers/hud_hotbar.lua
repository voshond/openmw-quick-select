local core = require("openmw.core")
local self = require("openmw.self")
local types = require("openmw.types")
local storage = require("openmw.storage")
local async = require("openmw.async")
local input = require("openmw.input")
local util = require("openmw.util")
local ui = require("openmw.ui")
local I = require("openmw.interfaces")

local Debug = require("scripts.voshondsquickselect.debug")
local utility = require("scripts.voshondsquickselect.legacy.utility")
local Snapshot = require("scripts.voshondsquickselect.presentation.hotbar_snapshot")
local tooltipData = require("scripts.voshondsquickselect.presentation.tooltip_data")
local HotbarView = require("scripts.voshondsquickselect.ui.hotbar_view")
local Icon = require("scripts.voshondsquickselect.ui.icon")
local Tooltip = require("scripts.voshondsquickselect.ui.tooltip")

local settings = storage.playerSection("SettingsVoshondsQuickSelect")
local textSettings = storage.playerSection("SettingsVoshondsQuickSelectText")
local chargeSettings = storage.playerSection("SettingsVoshondsQuickSelectMagicCharges")
local thresholdSettings = storage.playerSection("SettingsVoshondsQuickSelectItemCountThresholds")

local ITEMS_PER_ROW = 10
local ICON_PADDING = 2
local DYNAMIC_POLL_INTERVAL = 0.5
local FADE_DELAY = 2.0
local FADE_HIDE_DELAY = 0.3

local view
local activeLayoutConfig
local snapshots = {}
local visibleSlots = {}
local dirtySlots = {}
local pendingAll = true
local layoutDirty = true
local pendingResetFade = true
local styleVersion = 0
local selectedNum = 1
local pickSlotMode = false
local controllerPickMode = false
local pendingSlotData
local pollElapsed = 0
local fadeElapsed = 0
local fadedHidden = false
local wasHudVisible = true
local frameTime = 0
local retryAfter = 0
local lastHudError

local HUD_ERROR_RETRY_SECONDS = 1.0

local metrics = {
    fullBuilds = 0,
    slotUpdates = 0,
    skippedSlotUpdates = 0,
    invalidationBatches = 0,
    dynamicPolls = 0,
}

local STRUCTURAL_SETTINGS = {
    visibleHotbars = true,
    hotBarOnTop = true,
    hotbarGutterSize = true,
    hotbarVerticalSpacing = true,
    iconSize = true,
}

local function hudIsVisible()
    if I.UI and I.UI.isHudVisible then
        return I.UI.isHudVisible() ~= false
    end
    return true
end

local function shouldShowView()
    return hudIsVisible() and not fadedHidden
end

local function slotPrefix(slot)
    if slot >= 21 then
        return "c"
    elseif slot >= 11 then
        return "s"
    end
    return ""
end

local function selectedSlot()
    return selectedNum + (I.QuickSelect.getSelectedPage() * ITEMS_PER_ROW)
end

local function markSlotDirty(slot)
    if type(slot) == "number" and slot >= 1 and slot <= 30 then
        dirtySlots[slot] = true
    end
end

local function requestAll(resetFadeTimer)
    pendingAll = true
    if resetFadeTimer ~= false then
        pendingResetFade = true
    end
end

local function requestSlot(slot, resetFadeTimer)
    markSlotDirty(slot)
    if resetFadeTimer then
        pendingResetFade = true
    end
end

local function requestLayout(resetFadeTimer)
    layoutDirty = true
    requestAll(resetFadeTimer)
end

local function resetFadeState()
    fadeElapsed = 0
    fadedHidden = false
    if view then
        HotbarView.setVisible(view, hudIsVisible())
    end
end

local function resetFade()
    resetFadeState()
    requestAll(false)
end

local function getToolTipPos()
    if settings:get("hotBarOnTop") then
        return utility.itemWindowLocs.BottomCenter
    end
    return utility.itemWindowLocs.TopCenter
end

local function drawToolTip()
    local data = I.QuickSelect_Storage.getFavoriteItemData(selectedSlot())
    if not data then
        Tooltip.hide()
        return
    end

    local item
    local magicRecord
    if I.QuickSelect_Storage.getFavoriteItem then
        item = I.QuickSelect_Storage.getFavoriteItem(selectedSlot())
    elseif data.item then
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

    if not lines then
        Tooltip.hide()
        return
    end

    local position = getToolTipPos()
    Tooltip.show(lines, {
        anchor = position.anchor,
        relativePosition = util.vector2(position.wx, position.wy),
    })
end

local function createSlotLayout(snapshot)
    local slotSize = activeLayoutConfig and activeLayoutConfig.slotSize
        or utility.getIconSize() + ICON_PADDING * 2
    local size = util.vector2(slotSize, slotSize)
    local prefix = slotPrefix(snapshot.slot)
    local selected = snapshot.selected

    if settings:get("disableIconShrinking") ~= false and selected then
        selected = false
    end

    local content
    if snapshot.kind == "item" and snapshot.item then
        content = I.Controller_Icon_QS.getItemIcon(
            snapshot.item,
            false,
            selected,
            snapshot.slot,
            prefix,
            snapshot.data,
            snapshot.renderState
        )
    elseif (snapshot.kind == "spell" or snapshot.kind == "enchant") and snapshot.iconPath then
        content = I.Controller_Icon_QS.getSpellIcon(
            snapshot.iconPath,
            false,
            selected,
            snapshot.slot,
            prefix
        )
    else
        content = I.Controller_Icon_QS.getEmptyIcon(
            false,
            snapshot.slot,
            selected,
            true,
            prefix
        )
    end

    local boxedIcon = utility.renderItemBoxed(
        content,
        size,
        nil,
        util.vector2(0.5, 0.5),
        { item = snapshot.item, num = snapshot.slot, data = snapshot.data }
    )

    local layers = { boxedIcon }
    if snapshot.equipped then
        layers[#layers + 1] = {
            type = ui.TYPE.Image,
            props = {
                resource = Icon.texture("textures/voshondsQuickSelect/equipped_indicator.dds"),
                size = util.vector2(16, 16),
                position = util.vector2(0, size.y - 16),
                arrange = ui.ALIGNMENT.Start,
                align = ui.ALIGNMENT.Start,
                alpha = 1,
            },
        }
    end

    return {
        type = ui.TYPE.Widget,
        props = {
            autoSize = false,
            size = size,
        },
        content = ui.content(layers),
    }
end

local function readLayoutConfig()
    local iconSize = utility.getIconSize()
    local slotSize = iconSize + ICON_PADDING * 2
    local visibleBars = math.max(0, math.min(3, settings:get("visibleHotbars") or 1))
    local gap = math.max(0, settings:get("hotbarGutterSize") or 5)
    local verticalGap = visibleBars > 1
        and math.max(0, settings:get("hotbarVerticalSpacing") or 12)
        or 0

    local anchor = util.vector2(0.5, 1)
    local relativePosition = util.vector2(0.5, 1)
    if settings:get("hotBarOnTop") then
        anchor = util.vector2(0.5, 0)
        relativePosition = util.vector2(0.5, 0)
    end

    return {
        slotSize = slotSize,
        visibleBars = visibleBars,
        gap = gap,
        verticalGap = verticalGap,
        anchor = anchor,
        relativePosition = relativePosition,
    }
end

local function buildRows(visibleBars)
    local rows = {}
    local slotSet = {}

    for page = visibleBars - 1, 0, -1 do
        local row = {}
        for index = 1, ITEMS_PER_ROW do
            local slot = page * ITEMS_PER_ROW + index
            row[#row + 1] = slot
            slotSet[slot] = true
        end
        rows[#rows + 1] = row
    end

    return rows, slotSet
end

local function captureContext()
    return Snapshot.begin({
        selectedSlot = selectedSlot(),
        styleVersion = styleVersion,
    })
end

local function captureSlot(slot, context)
    return Snapshot.capture(
        slot,
        I.QuickSelect_Storage.getFavoriteItemData(slot),
        context
    )
end

local function rebuildView()
    if view then
        HotbarView.destroy(view)
        view = nil
    end

    local config = readLayoutConfig()
    activeLayoutConfig = config
    snapshots = {}

    if config.visibleBars == 0 then
        visibleSlots = {}
        layoutDirty = false
        pendingAll = false
        dirtySlots = {}
        return
    end

    local rows
    rows, visibleSlots = buildRows(config.visibleBars)

    local context = captureContext()
    for slot in pairs(visibleSlots) do
        snapshots[slot] = captureSlot(slot, context)
    end

    view = HotbarView.create({
        rows = rows,
        itemsPerRow = ITEMS_PER_ROW,
        slotSize = config.slotSize,
        gap = config.gap,
        verticalGap = config.verticalGap,
        anchor = config.anchor,
        relativePosition = config.relativePosition,
        visible = shouldShowView(),
        renderSlot = function(slot)
            return createSlotLayout(snapshots[slot])
        end,
    })

    metrics.fullBuilds = metrics.fullBuilds + 1
    layoutDirty = false
    pendingAll = false
    dirtySlots = {}
end

local function updateDirtySlots()
    local work = {}
    if pendingAll then
        for slot in pairs(visibleSlots) do
            work[slot] = true
        end
    else
        for slot in pairs(dirtySlots) do
            if visibleSlots[slot] then
                work[slot] = true
            end
        end
    end

    local context = captureContext()
    for slot in pairs(work) do
        local nextSnapshot = captureSlot(slot, context)
        if Snapshot.equals(snapshots[slot], nextSnapshot) then
            metrics.skippedSlotUpdates = metrics.skippedSlotUpdates + 1
        else
            snapshots[slot] = nextSnapshot
            if HotbarView.updateSlot(view, slot, createSlotLayout(nextSnapshot)) then
                metrics.slotUpdates = metrics.slotUpdates + 1
            end
        end
    end

    pendingAll = false
    dirtySlots = {}
end

local function flushInvalidations()
    if pendingResetFade then
        pendingResetFade = false
        resetFadeState()
    end

    if not hudIsVisible() then
        if view then
            HotbarView.setVisible(view, false)
        end
        return
    end

    if layoutDirty or (not view and activeLayoutConfig and activeLayoutConfig.visibleBars > 0) then
        rebuildView()
        metrics.invalidationBatches = metrics.invalidationBatches + 1
    elseif view and (pendingAll or next(dirtySlots) ~= nil) then
        updateDirtySlots()
        metrics.invalidationBatches = metrics.invalidationBatches + 1
    end

    if view then
        HotbarView.setVisible(view, shouldShowView())
    end

    if controllerPickMode then
        drawToolTip()
    end
end

local function invalidateDynamic()
    if not view then
        pendingAll = true
        return
    end

    for slot, snapshot in pairs(snapshots) do
        if snapshot.dynamic then
            dirtySlots[slot] = true
        end
    end
end

local function updateFade(dt)
    if not settings:get("enableFadingBars") then
        if fadedHidden then
            fadedHidden = false
            if view then
                HotbarView.setVisible(view, hudIsVisible())
            end
        end
        return
    end

    if controllerPickMode or fadedHidden or not hudIsVisible() or not view then
        return
    end

    fadeElapsed = fadeElapsed + dt
    if fadeElapsed >= FADE_DELAY + FADE_HIDE_DELAY then
        fadedHidden = true
        HotbarView.setVisible(view, false)
    end
end

local function onUpdate(dt)
    local hudVisible = hudIsVisible()
    if hudVisible ~= wasHudVisible then
        wasHudVisible = hudVisible
        if view then
            HotbarView.setVisible(view, hudVisible and not fadedHidden)
        end
        if hudVisible then
            invalidateDynamic()
        end
    end

    if not hudVisible or fadedHidden or (activeLayoutConfig and activeLayoutConfig.visibleBars == 0) then
        return
    end

    pollElapsed = pollElapsed + dt
    if pollElapsed >= DYNAMIC_POLL_INTERVAL then
        pollElapsed = pollElapsed % DYNAMIC_POLL_INTERVAL
        metrics.dynamicPolls = metrics.dynamicPolls + 1
        invalidateDynamic()
    end
end

local function startPickingMode()
    controllerPickMode = true
    resetFade()
end

local function endPickingMode()
    pickSlotMode = false
    controllerPickMode = false
    pendingSlotData = nil
    Tooltip.hide()
    I.UI.setMode()
    requestAll(true)
end

local function selectSlot(item, spell, enchant)
    pickSlotMode = true
    controllerPickMode = true
    pendingSlotData = { item = item, spell = spell, enchant = enchant }
    requestAll(true)
end

local function saveSlot()
    if not pickSlotMode or not pendingSlotData then
        return
    end

    local slot = selectedSlot()
    if pendingSlotData.item and not pendingSlotData.enchant then
        I.QuickSelect_Storage.saveStoredItemData(pendingSlotData.item, slot)
    elseif pendingSlotData.spell then
        I.QuickSelect_Storage.saveStoredSpellData(pendingSlotData.spell, "Spell", slot)
    elseif pendingSlotData.enchant then
        I.QuickSelect_Storage.saveStoredEnchantData(pendingSlotData.enchant, pendingSlotData.item, slot)
    end

    pickSlotMode = false
    pendingSlotData = nil
    requestSlot(slot, true)
end

local function uiModeChanged(data)
    if data.newMode and controllerPickMode then
        controllerPickMode = false
        pickSlotMode = false
        pendingSlotData = nil
        Tooltip.hide()
        requestAll(false)
    elseif not data.newMode and not pickSlotMode then
        Tooltip.hide()
    end
end

local function selectNextOrPrevHotBar(direction)
    local page = I.QuickSelect.getSelectedPage()
    if direction == "next" then
        page = page + 1
        if page > 2 then page = 0 end
    else
        page = page - 1
        if page < 0 then page = 2 end
    end

    I.QuickSelect.setSelectedPage(page)
    requestAll(true)
end

local function selectNextOrPrevHotKey(direction)
    if not controllerPickMode then
        startPickingMode()
        return
    end

    local oldSlot = selectedSlot()
    if direction == "next" then
        selectedNum = selectedNum == ITEMS_PER_ROW and 1 or selectedNum + 1
    else
        selectedNum = selectedNum == 1 and ITEMS_PER_ROW or selectedNum - 1
    end

    requestSlot(oldSlot, true)
    requestSlot(selectedSlot(), false)
end

local function isQuickKeysMenuOpen()
    return I.QuickSelect_Win1
        and I.QuickSelect_Win1.isMenuOpen
        and I.QuickSelect_Win1.isMenuOpen()
end

local function onMainSettingsChanged(_, key)
    if key == nil or STRUCTURAL_SETTINGS[key] then
        requestLayout(false)
    else
        requestAll(false)
    end
end

local function onVisualSettingsChanged()
    styleVersion = styleVersion + 1
    if I.Controller_Icon_QS and I.Controller_Icon_QS.refreshTextStyles then
        I.Controller_Icon_QS.refreshTextStyles()
    end
    requestAll(false)
end

settings:subscribe(async:callback(onMainSettingsChanged))
textSettings:subscribe(async:callback(onVisualSettingsChanged))
chargeSettings:subscribe(async:callback(onVisualSettingsChanged))
thresholdSettings:subscribe(async:callback(onVisualSettingsChanged))

return {
    interfaceName = "QuickSelect_Hotbar",
    interface = {
        drawHotbar = function(resetFadeTimer)
            requestAll(resetFadeTimer)
        end,
        invalidateSlot = function(slot, _, resetFadeTimer)
            requestSlot(slot, resetFadeTimer)
        end,
        invalidateState = function(_, resetFadeTimer)
            requestAll(resetFadeTimer)
        end,
        invalidateDynamic = function()
            invalidateDynamic()
        end,
        invalidateLayout = function(_, resetFadeTimer)
            requestLayout(resetFadeTimer)
        end,
        startPickingMode = startPickingMode,
        endPickingMode = endPickingMode,
        selectSlot = selectSlot,
        saveSlot = saveSlot,
        resetFade = resetFade,
        isHotbarVisible = function()
            return view ~= nil and view.visible
        end,
        getPerformanceMetrics = function()
            return {
                fullBuilds = metrics.fullBuilds,
                slotUpdates = metrics.slotUpdates,
                skippedSlotUpdates = metrics.skippedSlotUpdates,
                invalidationBatches = metrics.invalidationBatches,
                dynamicPolls = metrics.dynamicPolls,
            }
        end,
    },
    eventHandlers = {
        UiModeChanged = uiModeChanged,
    },
    engineHandlers = {
        onLoad = function()
            Tooltip.ensureLayer()

            if settings:get("disableIconShrinking") == nil then
                settings:set("disableIconShrinking", true)
            end

            pickSlotMode = false
            controllerPickMode = false
            selectedNum = 1
            pollElapsed = 0
            fadeElapsed = 0
            fadedHidden = false
            wasHudVisible = hudIsVisible()
            frameTime = 0
            retryAfter = 0
            lastHudError = nil
            requestLayout(true)
        end,
        onUpdate = onUpdate,
        onFrame = function(dt)
            frameTime = frameTime + (dt or 0)
            if frameTime < retryAfter then
                return
            end

            local success, err = pcall(function()
                updateFade(dt)
                flushInvalidations()
            end)
            if not success then
                local message = tostring(err)
                if message ~= lastHudError then
                    Debug.error("QuickSelect_Hotbar", "HUD update failed: " .. message)
                    lastHudError = message
                end
                retryAfter = frameTime + HUD_ERROR_RETRY_SECONDS
            else
                lastHudError = nil
                retryAfter = 0
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
            if char == "=" then
                selectNextOrPrevHotBar("next")
            elseif char == "-" then
                selectNextOrPrevHotBar("prev")
            end
        end,
        onControllerButtonPress = function(button)
            if isQuickKeysMenuOpen() then
                return
            end
            if core.isWorldPaused() and not controllerPickMode then
                return
            end

            if button == input.CONTROLLER_BUTTON.LeftShoulder
                or button == input.CONTROLLER_BUTTON.DPadLeft then
                selectNextOrPrevHotKey("prev")
            elseif button == input.CONTROLLER_BUTTON.RightShoulder
                or button == input.CONTROLLER_BUTTON.DPadRight then
                selectNextOrPrevHotKey("next")
            elseif button == input.CONTROLLER_BUTTON.DPadDown and controllerPickMode then
                selectNextOrPrevHotBar("next")
            elseif button == input.CONTROLLER_BUTTON.DPadUp and controllerPickMode then
                selectNextOrPrevHotBar("prev")
            elseif button == input.CONTROLLER_BUTTON.A and controllerPickMode then
                if pickSlotMode then
                    saveSlot()
                    return
                end
                I.QuickSelect_Storage.equipSlot(selectedSlot())
                endPickingMode()
            elseif button == input.CONTROLLER_BUTTON.B and controllerPickMode then
                endPickingMode()
            end
        end,
    },
}
