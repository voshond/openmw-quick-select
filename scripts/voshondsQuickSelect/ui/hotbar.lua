local ui = require("openmw.ui")
local util = require("openmw.util")

local Hotbar = {}

local function spacer(width, height)
    return {
        type = ui.TYPE.Widget,
        props = {
            autoSize = false,
            size = util.vector2(width, height),
        },
    }
end

function Hotbar.measure(slotCount, slotWidth, slotHeight, gap)
    local count = math.max(0, slotCount or 0)
    local width = count * slotWidth + math.max(0, count - 1) * gap
    return util.vector2(width, slotHeight)
end

function Hotbar.create(params)
    params = params or {}

    local slots = params.slots or {}
    local slotWidth = params.slotWidth or params.slotSize or 40
    local slotHeight = params.slotHeight or params.slotSize or 40
    local gap = params.gap or 0
    local content = {}

    for index, slot in ipairs(slots) do
        table.insert(content, slot)
        if index < #slots and gap > 0 then
            table.insert(content, spacer(gap, slotHeight))
        end
    end

    local measured = Hotbar.measure(#slots, slotWidth, slotHeight, gap)

    return {
        type = ui.TYPE.Flex,
        name = params.name,
        template = params.template,
        props = {
            autoSize = false,
            horizontal = params.horizontal ~= false,
            size = params.size or measured,
            align = params.align or ui.ALIGNMENT.Center,
            arrange = params.arrange or ui.ALIGNMENT.Center,
            alpha = params.alpha,
        },
        userData = params.userData,
        events = params.events,
        content = ui.content(content),
    }
end

return Hotbar
