local I = require("openmw.interfaces")
local ui = require("openmw.ui")
local util = require("openmw.util")
local auxUi = require("openmw_aux.ui")

local Hotbar = require("scripts.voshondsquickselect.ui.hotbar")

local HotbarView = {}

local function verticalSpacer(width, height)
    return {
        type = ui.TYPE.Widget,
        props = {
            autoSize = false,
            size = util.vector2(width, height),
        },
    }
end

function HotbarView.create(params)
    params = params or {}

    local slotSize = params.slotSize or 40
    local gap = params.gap or 0
    local verticalGap = params.verticalGap or 0
    local rows = params.rows or {}
    local rowSize = Hotbar.measure(params.itemsPerRow or 10, slotSize, slotSize, gap)
    local rowLayouts = {}
    local slotElements = {}

    for rowIndex, slotIds in ipairs(rows) do
        local elements = {}
        for _, slot in ipairs(slotIds) do
            local element = ui.create(params.renderSlot(slot))
            slotElements[slot] = element
            elements[#elements + 1] = element
        end

        rowLayouts[#rowLayouts + 1] = Hotbar.create({
            slots = elements,
            slotSize = slotSize,
            gap = gap,
            size = rowSize,
            align = ui.ALIGNMENT.Start,
            arrange = ui.ALIGNMENT.Start,
        })

        if rowIndex < #rows then
            rowLayouts[#rowLayouts + 1] = verticalSpacer(rowSize.x, verticalGap)
        end
    end

    local totalHeight = slotSize * #rows + verticalGap * math.max(0, #rows - 1)
    local root = ui.create {
        layer = params.layer or "HUD",
        template = params.template or I.MWUI.templates.padding,
        props = {
            anchor = params.anchor,
            relativePosition = params.relativePosition,
            arrange = ui.ALIGNMENT.Center,
            align = ui.ALIGNMENT.Center,
            visible = params.visible ~= false,
        },
        content = ui.content {
            {
                type = ui.TYPE.Flex,
                content = ui.content(rowLayouts),
                props = {
                    horizontal = false,
                    align = ui.ALIGNMENT.Center,
                    arrange = ui.ALIGNMENT.Center,
                    autoSize = false,
                    size = util.vector2(rowSize.x, totalHeight),
                },
            },
        },
    }

    return {
        root = root,
        slots = slotElements,
        visible = params.visible ~= false,
        rowSize = rowSize,
        totalHeight = totalHeight,
        slotUpdates = 0,
        rootUpdates = 0,
    }
end

function HotbarView.updateSlot(view, slot, layout)
    local element = view and view.slots[slot]
    if not element then
        return false
    end

    element.layout = layout
    element:update()
    view.slotUpdates = view.slotUpdates + 1
    return true
end

function HotbarView.setVisible(view, visible)
    if not view or not view.root or view.visible == visible then
        return false
    end

    view.visible = visible
    view.root.layout.props.visible = visible
    view.root:update()
    view.rootUpdates = view.rootUpdates + 1
    return true
end

function HotbarView.destroy(view)
    if not view then
        return
    end

    if view.root and view.root.layout then
        auxUi.deepDestroy(view.root)
    end
    view.root = nil
    view.slots = {}
end

return HotbarView
