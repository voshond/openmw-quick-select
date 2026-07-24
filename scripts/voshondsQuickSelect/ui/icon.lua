local I = require("openmw.interfaces")
local ui = require("openmw.ui")
local util = require("openmw.util")

local Icon = {}
local textureCache = {}

local function texture(path)
    if not path then
        return nil
    end

    if not textureCache[path] then
        textureCache[path] = ui.texture({ path = path })
    end

    return textureCache[path]
end

local function imageLayer(layer, defaultSize)
    if not layer then
        return nil
    end

    local resource = layer.resource or texture(layer.path)
    if not resource then
        return nil
    end

    return {
        type = ui.TYPE.Image,
        props = {
            resource = resource,
            size = layer.size or defaultSize,
            position = layer.position,
            relativePosition = layer.relativePosition,
            anchor = layer.anchor,
            alpha = layer.alpha or 1,
            arrange = layer.arrange or ui.ALIGNMENT.Center,
            align = layer.align or ui.ALIGNMENT.Center,
        },
    }
end

local function textLayer(layer)
    if not layer or layer.text == nil or layer.text == "" then
        return nil
    end

    return {
        type = ui.TYPE.Text,
        template = layer.template or I.MWUI.templates.textNormal,
        props = {
            text = tostring(layer.text),
            textSize = layer.textSize,
            textColor = layer.textColor,
            textShadow = layer.textShadow,
            textShadowColor = layer.textShadowColor,
            position = layer.position,
            relativePosition = layer.relativePosition,
            anchor = layer.anchor,
            arrange = layer.arrange,
            align = layer.align,
            textAlignH = layer.textAlignH,
            textAlignV = layer.textAlignV,
        },
    }
end

local function append(target, value)
    if value then
        table.insert(target, value)
    end
end

function Icon.content(spec)
    spec = spec or {}

    if spec.content then
        return spec.content
    end

    local width = spec.width or spec.size or 40
    local height = spec.height or spec.size or 40
    if spec.half then
        height = height / 2
    end

    local imageSize = util.vector2(width, height)
    local content = {}

    for _, layer in ipairs(spec.backgrounds or {}) do
        append(content, imageLayer(layer, imageSize))
    end

    append(content, imageLayer({
        path = spec.path,
        resource = spec.resource,
        alpha = spec.alpha,
        size = spec.imageSize,
    }, imageSize))

    for _, layer in ipairs(spec.images or {}) do
        append(content, imageLayer(layer, imageSize))
    end

    for _, layer in ipairs(spec.texts or {}) do
        append(content, textLayer(layer))
    end

    for _, layout in ipairs(spec.overlays or {}) do
        append(content, layout)
    end

    return ui.content(content)
end

function Icon.create(spec)
    spec = spec or {}

    local width = spec.width or spec.size or 40
    local height = spec.height or spec.size or 40
    if spec.half then
        height = height / 2
    end

    return {
        type = ui.TYPE.Container,
        name = spec.name,
        template = spec.template or I.MWUI.templates.borders,
        props = {
            size = util.vector2(width, height),
            autoSize = false,
            propagateEvents = spec.propagateEvents,
            alpha = spec.containerAlpha,
        },
        userData = spec.userData,
        events = spec.events,
        content = Icon.content(spec),
    }
end

function Icon.texture(path)
    return texture(path)
end

function Icon.clearTextureCache()
    textureCache = {}
end

return Icon
