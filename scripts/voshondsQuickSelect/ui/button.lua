local ambient = require("openmw.ambient")
local async = require("openmw.async")
local I = require("openmw.interfaces")
local ui = require("openmw.ui")
local util = require("openmw.util")

local Button = {}

local function onClick(_, layout)
    if layout.userData and layout.userData.onClick then
        ambient.playSound("Menu Click")
        layout.userData.onClick(layout.userData.value, layout)
    end
end

function Button.create(params)
    params = params or {}

    local layout = {
        type = ui.TYPE.Container,
        template = params.template or I.MWUI.templates.borders,
        props = {
            size = params.size,
            autoSize = params.size == nil,
            propagateEvents = false,
        },
        userData = {
            onClick = params.onClick,
            value = params.value,
        },
        events = {
            mouseClick = async:callback(onClick),
        },
        content = ui.content({
            {
                type = ui.TYPE.Container,
                template = I.MWUI.templates.padding,
                content = ui.content({
                    {
                        type = ui.TYPE.Text,
                        template = params.textTemplate or I.MWUI.templates.textNormal,
                        props = {
                            text = params.text or "",
                            textSize = params.textSize or 18,
                            textColor = params.textColor,
                            arrange = ui.ALIGNMENT.Center,
                            align = ui.ALIGNMENT.Center,
                            textAlignH = ui.ALIGNMENT.Center,
                            textAlignV = ui.ALIGNMENT.Center,
                        },
                    },
                }),
            },
        }),
    }

    return layout
end

return Button
