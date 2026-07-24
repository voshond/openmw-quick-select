local I = require("openmw.interfaces")
local ui = require("openmw.ui")
local util = require("openmw.util")

local Modal = {}

function Modal.create(params)
    params = params or {}

    local width = params.width or 600
    local content = {}

    if params.title then
        table.insert(content, {
            type = ui.TYPE.Text,
            template = I.MWUI.templates.textHeader,
            props = {
                text = params.title,
                textSize = params.titleSize or 24,
                size = util.vector2(width, params.headerHeight or 36),
                textAlignH = ui.ALIGNMENT.Center,
                textAlignV = ui.ALIGNMENT.Center,
            },
        })
    end

    if params.subtitle then
        table.insert(content, {
            type = ui.TYPE.Text,
            template = I.MWUI.templates.textNormal,
            props = {
                text = params.subtitle,
                textSize = params.subtitleSize or 16,
                size = util.vector2(width, params.subtitleHeight or 28),
                textAlignH = ui.ALIGNMENT.Center,
                textAlignV = ui.ALIGNMENT.Center,
            },
        })
    end

    for _, child in ipairs(params.content or {}) do
        table.insert(content, child)
    end

    return {
        type = ui.TYPE.Container,
        layer = params.layer or "Windows",
        template = params.template or I.MWUI.templates.boxTransparentThick,
        props = {
            anchor = params.anchor or util.vector2(0.5, 0.5),
            relativePosition = params.relativePosition or util.vector2(0.5, 0.5),
            autoSize = true,
            arrange = ui.ALIGNMENT.Center,
            align = ui.ALIGNMENT.Center,
        },
        userData = params.userData,
        events = params.events,
        content = ui.content({
            {
                type = ui.TYPE.Flex,
                props = {
                    autoSize = true,
                    horizontal = false,
                    align = ui.ALIGNMENT.Center,
                    arrange = ui.ALIGNMENT.Center,
                },
                content = ui.content(content),
            },
        }),
    }
end

return Modal
