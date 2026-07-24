local I = require("openmw.interfaces")
local ui = require("openmw.ui")
local util = require("openmw.util")

local Icon = require("scripts.voshondsquickselect.ui.icon")

local Tooltip = {}
local LAYER = "VoshondsQuickSelectTooltips"
local element

local function ensureLayer()
    if ui.layers.indexOf(LAYER) then
        return LAYER
    end

    local success, err = pcall(function()
        local lastLayer = ui.layers[#ui.layers]
        if lastLayer then
            ui.layers.insertAfter(lastLayer.name, LAYER, { interactive = false })
        else
            ui.layers.insertAfter("HUD", LAYER, { interactive = false })
        end
    end)

    if not success then
        print("[VoshondsQuickSelect][Tooltip] Could not create tooltip layer: " .. tostring(err))
        return "Windows"
    end

    return LAYER
end

local ROW_HEIGHT = 18

local function lineLayout(line, width, height)
    if type(line) == "table" then
        local children = {}
        if line.icon then
            table.insert(children, {
                type = ui.TYPE.Image,
                props = {
                    resource = Icon.texture(line.icon),
                    size = util.vector2(height, height),
                    align = ui.ALIGNMENT.Start,
                },
            })
        end
        table.insert(children, {
            type = ui.TYPE.Text,
            template = line.header and I.MWUI.templates.textHeader or I.MWUI.templates.textNormal,
            props = {
                text = tostring(line.text or ""),
                textSize = line.textSize or 15,
                size = util.vector2(width - (line.icon and height + 4 or 0), height),
                textColor = line.color,
                textAlignH = ui.ALIGNMENT.Start,
                textAlignV = ui.ALIGNMENT.Center,
            },
        })
        return {
            type = ui.TYPE.Flex,
            props = {
                horizontal = true,
                autoSize = false,
                size = util.vector2(width, height),
                align = ui.ALIGNMENT.Start,
                arrange = ui.ALIGNMENT.Start,
            },
            content = ui.content(children),
        }
    end

    return {
        type = ui.TYPE.Text,
        template = I.MWUI.templates.textNormal,
        props = {
            text = tostring(line),
            textSize = 15,
            size = util.vector2(width, height),
            textAlignH = ui.ALIGNMENT.Start,
            textAlignV = ui.ALIGNMENT.Center,
        },
    }
end

local function estimateWidth(lines)
    local widest = 0
    for _, line in ipairs(lines) do
        local text = type(line) == "table" and line.text or line
        local iconAllowance = type(line) == "table" and line.icon and 28 or 0
        widest = math.max(widest, #(tostring(text or "")) * 7 + iconAllowance + 12)
    end

    -- MW's font is variable-width, so this has a little breathing room.  It
    -- avoids the old fixed 360px tooltip for short one-line effect lists.
    return math.max(120, math.min(460, widest))
end

local function destroy()
    if element then
        element:destroy()
        element = nil
    end
end

function Tooltip.show(lines, params)
    destroy()

    if not lines or #lines == 0 then
        return
    end

    params = params or {}
    local width = params.width or estimateWidth(lines)
    local rowHeight = params.rowHeight or ROW_HEIGHT
    local height = #lines * rowHeight
    local screen = ui.screenSize()
    local position = params.position

    if position then
        position = util.vector2(
            math.max(0, math.min(position.x + 16, screen.x - width)),
            math.max(0, math.min(position.y + 16, screen.y - height))
        )
    end

    local content = {}
    for _, line in ipairs(lines) do
        table.insert(content, lineLayout(line, width, rowHeight))
    end

    element = ui.create({
        type = ui.TYPE.Container,
        layer = ensureLayer(),
        template = I.MWUI.templates.boxSolid,
        props = {
            position = position,
            anchor = params.anchor,
            relativePosition = params.relativePosition,
            autoSize = true,
            propagateEvents = false,
        },
        content = ui.content({
            {
                type = ui.TYPE.Flex,
                props = {
                    horizontal = false,
                    autoSize = false,
                    size = util.vector2(width, height),
                    align = ui.ALIGNMENT.Start,
                    arrange = ui.ALIGNMENT.Start,
                },
                content = ui.content(content),
            },
        }),
    })

    return element
end

function Tooltip.hide()
    destroy()
end

function Tooltip.ensureLayer()
    return ensureLayer()
end

return Tooltip
