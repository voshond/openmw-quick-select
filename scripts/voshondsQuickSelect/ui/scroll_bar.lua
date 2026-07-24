local async = require("openmw.async")
local I = require("openmw.interfaces")
local ui = require("openmw.ui")
local util = require("openmw.util")

local ScrollBar = {}

local UP_TEXTURE = ui.texture({ path = "textures/omw_menu_scroll_up.dds" })
local DOWN_TEXTURE = ui.texture({ path = "textures/omw_menu_scroll_down.dds" })
local HANDLE_TEXTURE = ui.texture({ path = "textures/omw_menu_scroll_center_v.dds" })

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function maxHandlePosition(state)
    return math.max(0, state.trackHeight - state.handleHeight)
end

local function notify(state)
    if state.onChanged then
        local maximum = maxHandlePosition(state)
        local fraction = maximum > 0 and state.handleY / maximum or 0
        state.onChanged(fraction)
    end
end

local function update(state)
    state.handle.props.position = util.vector2(0, state.handleY)
    state.handle.props.size = util.vector2(state.width, state.handleHeight)
    if state.element then
        state.element:update()
    end
end

local function setFraction(state, fraction, shouldNotify)
    state.handleY = clamp(fraction or 0, 0, 1) * maxHandlePosition(state)
    update(state)
    if shouldNotify ~= false then
        notify(state)
    end
end

local function step(state, direction)
    local maximum = maxHandlePosition(state)
    if maximum <= 0 then
        return
    end

    local fraction = state.handleY / maximum
    setFraction(state, fraction + direction * state.stepFraction)
end

local function onUpClick(_, layout)
    step(layout.userData.state, -1)
end

local function onDownClick(_, layout)
    step(layout.userData.state, 1)
end

local function onTrackPress(event, layout)
    local state = layout.userData.state
    local targetY = event.offset.y - state.handleHeight / 2
    state.handleY = clamp(targetY, 0, maxHandlePosition(state))
    update(state)
    notify(state)
end

local function onHandlePress(event, layout)
    local state = layout.userData.state
    state.dragging = true
    state.dragStartMouseY = event.position.y
    state.dragStartHandleY = state.handleY
end

local function onHandleMove(event, layout)
    local state = layout.userData.state
    if not state.dragging then
        return
    end

    local delta = event.position.y - state.dragStartMouseY
    state.handleY = clamp(state.dragStartHandleY + delta, 0, maxHandlePosition(state))
    update(state)
    notify(state)
end

local function onHandleRelease(_, layout)
    layout.userData.state.dragging = false
end

local function arrow(resource, size, handler, state)
    return {
        type = ui.TYPE.Container,
        template = I.MWUI.templates.borders,
        props = {
            autoSize = false,
            size = util.vector2(size, size),
            propagateEvents = false,
        },
        userData = { state = state },
        events = { mouseClick = async:callback(handler) },
        content = ui.content({
            {
                type = ui.TYPE.Image,
                props = {
                    resource = resource,
                    size = util.vector2(size, size),
                },
            },
        }),
    }
end

function ScrollBar.create(params)
    params = params or {}

    local width = params.width or 14
    local height = params.height or 200
    local trackHeight = math.max(width, height - width * 2)
    local state = {
        width = width,
        height = height,
        trackHeight = trackHeight,
        handleHeight = clamp(params.handleHeight or trackHeight, width, trackHeight),
        handleY = 0,
        dragging = false,
        stepFraction = params.stepFraction or 0.1,
        onChanged = params.onChanged,
    }

    local handle = {
        type = ui.TYPE.Image,
        props = {
            resource = HANDLE_TEXTURE,
            size = util.vector2(width, state.handleHeight),
            position = util.vector2(0, 0),
            tileV = true,
            propagateEvents = false,
        },
        userData = { state = state },
        events = {
            mousePress = async:callback(onHandlePress),
            mouseMove = async:callback(onHandleMove),
            mouseRelease = async:callback(onHandleRelease),
        },
    }
    state.handle = handle

    local track = {
        type = ui.TYPE.Widget,
        props = {
            autoSize = false,
            size = util.vector2(width, trackHeight),
            propagateEvents = false,
        },
        userData = { state = state },
        events = { mousePress = async:callback(onTrackPress) },
        content = ui.content({ handle }),
    }

    local layout = {
        type = ui.TYPE.Flex,
        props = {
            autoSize = false,
            horizontal = false,
            size = util.vector2(width, height),
            align = ui.ALIGNMENT.Center,
        },
        userData = state,
        content = ui.content({
            arrow(UP_TEXTURE, width, onUpClick, state),
            {
                type = ui.TYPE.Container,
                template = I.MWUI.templates.boxSolid,
                props = {
                    autoSize = false,
                    size = util.vector2(width, trackHeight),
                },
                content = ui.content({ track }),
            },
            arrow(DOWN_TEXTURE, width, onDownClick, state),
        }),
    }

    local element = ui.create(layout)
    state.element = element
    return element
end

function ScrollBar.getFraction(element)
    local state = element and element.layout and element.layout.userData
    if not state then
        return 0
    end

    local maximum = maxHandlePosition(state)
    return maximum > 0 and state.handleY / maximum or 0
end

function ScrollBar.setFraction(element, fraction, shouldNotify)
    local state = element and element.layout and element.layout.userData
    if state then
        setFraction(state, fraction, shouldNotify)
    end
end

function ScrollBar.setHandleRatio(element, ratio)
    local state = element and element.layout and element.layout.userData
    if not state then
        return
    end

    local fraction = ScrollBar.getFraction(element)
    state.handleHeight = clamp(state.trackHeight * clamp(ratio or 1, 0, 1), state.width, state.trackHeight)
    setFraction(state, fraction, false)
end

return ScrollBar
