local auxUi = require("openmw_aux.ui")
local ui = require("openmw.ui")
local util = require("openmw.util")

local ScrollBar = require("scripts.voshondsquickselect.ui.scroll_bar")

local ScrollView = {}
local DEFAULT_SCROLLBAR_WIDTH = 14

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function applyFraction(state, fraction)
    state.fraction = clamp(fraction or 0, 0, 1)
    local overflow = math.max(0, state.contentHeight - state.height)
    state.content.layout.props.position = util.vector2(0, -overflow * state.fraction)
    state.content:update()
end

local function build(params)
    params = params or {}
    assert(params.content, "ScrollView.create requires a content layout or element")
    assert(params.width and params.height, "ScrollView.create requires width and height")

    local contentElement = params.content.layout and params.content or ui.create(params.content)
    local contentSize = contentElement.layout.props.size
    assert(contentSize, "ScrollView content requires a fixed props.size")

    local needsScrollbar = params.forceScrollbar or contentSize.y > params.height
    local scrollbarWidth = needsScrollbar and (params.scrollbarWidth or DEFAULT_SCROLLBAR_WIDTH) or 0
    local viewportWidth = params.width - scrollbarWidth
    local state = {
        width = params.width,
        height = params.height,
        contentWidth = contentSize.x,
        contentHeight = contentSize.y,
        itemHeight = params.itemHeight or 1,
        content = contentElement,
        fraction = 0,
    }

    local viewport = {
        type = ui.TYPE.Widget,
        props = {
            autoSize = false,
            size = util.vector2(viewportWidth, params.height),
        },
        content = ui.content({ contentElement }),
    }

    local children = { viewport }
    if needsScrollbar then
        local ratio = params.height / math.max(params.height, contentSize.y)
        local scrollbar = ScrollBar.create({
            width = scrollbarWidth,
            height = params.height,
            handleHeight = math.max(scrollbarWidth, (params.height - scrollbarWidth * 2) * ratio),
            stepFraction = state.itemHeight / math.max(state.itemHeight, contentSize.y - params.height),
            onChanged = function(fraction)
                applyFraction(state, fraction)
            end,
        })
        state.scrollbar = scrollbar
        table.insert(children, scrollbar)
    end

    local layout = {
        type = ui.TYPE.Flex,
        props = {
            autoSize = false,
            horizontal = true,
            size = util.vector2(params.width, params.height),
            align = ui.ALIGNMENT.Start,
        },
        userData = state,
        content = ui.content(children),
    }

    return layout, state
end

function ScrollView.create(params)
    local layout, state = build(params)
    local element = ui.create(layout)
    state.element = element
    applyFraction(state, params.initialFraction or 0)
    return element
end

-- Reusing the outer Element lets a search refresh replace a list and its
-- scrollbar without rebuilding the parent modal (and therefore without
-- disturbing a focused TextEdit elsewhere in that modal).
function ScrollView.replace(element, params)
    assert(element and element.layout, "ScrollView.replace requires an existing ScrollView element")

    local previousState = element.layout.userData
    if previousState and previousState.content then
        auxUi.deepDestroy(previousState.content)
    end

    local layout, state = build(params)
    element.layout = layout
    state.element = element
    applyFraction(state, params.initialFraction or 0)
    element:update()
    return element
end

function ScrollView.scroll(element, itemCount)
    local state = element and element.layout and element.layout.userData
    if not state or not state.scrollbar then
        return
    end

    local overflow = math.max(0, state.contentHeight - state.height)
    if overflow <= 0 then
        return
    end

    local delta = (state.itemHeight * (itemCount or 0)) / overflow
    ScrollBar.setFraction(state.scrollbar, state.fraction + delta)
end

function ScrollView.reset(element)
    local state = element and element.layout and element.layout.userData
    if not state then
        return
    end

    if state.scrollbar then
        ScrollBar.setFraction(state.scrollbar, 0)
    else
        applyFraction(state, 0)
    end
end

function ScrollView.destroy(element)
    if element then
        auxUi.deepDestroy(element)
    end
end

return ScrollView
