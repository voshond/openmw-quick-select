local async = require("openmw.async")
local I = require("openmw.interfaces")
local ui = require("openmw.ui")
local util = require("openmw.util")

local SearchBar = {}

local function onTextChanged(text, layout)
    text = text or ""
    -- TextEdit maintains an internal buffer.  Persist the value back to the
    -- layout before refreshing the result list, otherwise Element:update()
    -- can restore the stale value that was used when the field was created.
    layout.props.text = text

    if layout.userData and layout.userData.onChanged then
        layout.userData.onChanged(text)
    end
end

local function onFocusGain(_, layout)
    if layout.userData and layout.userData.onFocusChanged then
        layout.userData.onFocusChanged(true)
    end
end

local function onFocusLoss(_, layout)
    if layout.userData and layout.userData.onFocusChanged then
        layout.userData.onFocusChanged(false)
    end
end

function SearchBar.create(params)
    params = params or {}

    local width = params.width or 420
    local height = params.height or 26

    local inputWidth = width - (params.labelWidth or 72)
    local input = {
        name = params.name or "searchInput",
        type = ui.TYPE.TextEdit,
        props = {
            position = util.vector2(2, 2),
            text = params.text or "",
            textSize = params.textSize or 16,
            -- TextEdit defaults to black text. Keep the compact, single
            -- border below, but use the standard MWUI sand text colour.
            textColor = I.MWUI.templates.textNormal.props and I.MWUI.templates.textNormal.props.textColor or nil,
            size = util.vector2(math.max(1, inputWidth - 4), math.max(1, height - 4)),
            multiline = false,
            wordWrap = false,
            autoSize = false,
        },
        userData = {
            onChanged = params.onChanged,
            onFocusChanged = params.onFocusChanged,
        },
        events = {
            textChanged = async:callback(onTextChanged),
            focusGain = async:callback(onFocusGain),
            focusLoss = async:callback(onFocusLoss),
        },
    }

    -- Use one deliberate frame. textEditLine adds a second, thick frame that
    -- makes the field look oversized at high UI scales.
    local inputBox = {
        type = ui.TYPE.Container,
        template = I.MWUI.templates.borders,
        props = {
            autoSize = false,
            size = util.vector2(inputWidth, height),
        },
        content = ui.content({ input }),
    }

    local layout = {
        type = ui.TYPE.Flex,
        props = {
            autoSize = false,
            horizontal = true,
            size = util.vector2(width, height),
            align = ui.ALIGNMENT.Center,
        },
        content = ui.content({
            {
                type = ui.TYPE.Text,
                template = I.MWUI.templates.textNormal,
                props = {
                    text = params.label or "Search:",
                    textSize = params.textSize or 16,
                    size = util.vector2(params.labelWidth or 72, height),
                    textAlignV = ui.ALIGNMENT.Center,
                },
            },
            {
                type = ui.TYPE.Widget,
                props = { autoSize = false, size = util.vector2(inputWidth, height) },
                content = ui.content({ inputBox }),
            },
        }),
    }

    -- This is intentionally exposed to the selector so it can change only
    -- the results list as text is entered, preserving TextEdit focus.
    layout.userData = { input = input }
    return layout
end

function SearchBar.getInput(layout)
    return layout and layout.userData and layout.userData.input
end

function SearchBar.setText(input, value)
    if input and input.props then
        input.props.text = value or ""
    end
end

return SearchBar
