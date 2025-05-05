local ui = require("openmw.ui")
local I = require("openmw.interfaces")

local v2 = require("openmw.util").vector2
local util = require("openmw.util")
local cam = require("openmw.interfaces").Camera
local core = require("openmw.core")
local self = require("openmw.self")
local nearby = require("openmw.nearby")
local types = require("openmw.types")
local Camera = require("openmw.camera")
local camera = require("openmw.camera")
local input = require("openmw.input")
local async = require("openmw.async")
local storage = require("openmw.storage")
local function getIconSize()
    local settings = storage.playerSection("SettingsQuickSelect")
    return settings:get("iconSize") or 40
end

local savedTextures = {}
local function textContent(text)
    return {
        type = ui.TYPE.Text,
        template = I.MWUI.templates.textHeader,
        props = {
            text = tostring(text),
            textSize = 10 * 1,
            arrange = ui.ALIGNMENT.Start,
            align = ui.ALIGNMENT.Start
        }
    }
end
local function imageContent(resource, half, customOpacity)
    local size = getIconSize()
    local opacity = customOpacity or 1
    if half and customOpacity == nil then
        opacity = 0.5
    end

    -- Create a consistent size for all images
    local sizeX = size
    local sizeY = size

    if half then
        sizeY = sizeY / 2
    end

    if not resource then
        return {}
    end

    return {
        type = ui.TYPE.Image,
        props = {
            resource = resource,
            size = util.vector2(sizeX, sizeY),
            alpha = opacity,
            arrange = ui.ALIGNMENT.Center,
            align = ui.ALIGNMENT.Center
        }
    }
end
local function getTexture(path)
    if not savedTextures[path] and path then
        savedTextures[path] = ui.texture({ path = path })
    end
    return savedTextures[path]
end
local function formatNumber(num)
    local threshold = 1000
    local millionThreshold = 1000000

    if num >= millionThreshold then
        local formattedNum = math.floor(num / millionThreshold)
        return string.format("%dm", formattedNum)
    elseif num >= threshold then
        local formattedNum = math.floor(num / threshold)
        return string.format("%dk", formattedNum)
    else
        return tostring(num)
    end
end
local function FindEnchant(item)
    if not item or not item.id then
        return nil
    end
    if item.enchant then
        return item.enchant
    end
    if (item == nil or item.type == nil or item.type.records[item.recordId] == nil or item.type.records[item.recordId].enchant == nil or item.type.records[item.recordId].enchant == "") then
        return nil
    end
    return item.type.records[item.recordId].enchant
end

local function getItemIcon(item, half, selected, slotNumber, slotPrefix)
    local itemIcon = nil

    local selectionResource
    local drawFavoriteStar = true
    selectionResource = getTexture("icons\\voshondsQuickSelect\\selected.tga")

    -- Get magic icon with reduced opacity (0.7)
    local magicIconOpacity = 0.3
    local magicIcon = FindEnchant(item) and FindEnchant(item) ~= "" and getTexture("textures\\menu_icon_magic_mini.dds")
    local text = ""
    if item and item.type then
        local record = item.type.records[item.recordId]
        if not record then
            --print("No record for " .. item.recordId)
        else
            --print(record.icon)
        end
        if item.count > 1 then
            text = formatNumber(item.count)
        end

        itemIcon = getTexture(record.icon)
    end

    local selectedContent = {}
    if selected then
        selectedContent = imageContent(selectionResource)
    end

    -- Save item count text for the upper left
    local itemCountText = textContent(tostring(text))

    -- Format the slot number with the prefix if available
    local slotText = slotNumber
    if slotPrefix and slotPrefix ~= "" then
        -- Calculate the slot's position within its bar (1-10)
        local slotPosition = ((slotNumber - 1) % 10) + 1
        -- Display slot number with prefix
        slotText = slotPrefix .. slotPosition
    else
        -- For the first bar, just show the slot position (1-10)
        local slotPosition = ((slotNumber - 1) % 10) + 1
        slotText = slotPosition
    end

    local context = ui.content {
        selectedContent,
        imageContent(magicIcon, half, magicIconOpacity),
        imageContent(itemIcon, half),
        itemCountText,
        -- Add slot number to bottom right if we have it
        slotNumber and {
            type = ui.TYPE.Text,
            template = I.MWUI.templates.textNormal,
            props = {
                text = tostring(slotText),
                textSize = 14,                             -- Smaller size for the slot number
                relativePosition = util.vector2(0.9, 0.9), -- Bottom right position
                anchor = util.vector2(0.9, 0.9),
                arrange = ui.ALIGNMENT.End,
                align = ui.ALIGNMENT.End,
            }
        }
    }

    return context
end
local function getSpellIcon(iconPath, half, selected, slotNumber, slotPrefix)
    local itemIcon = nil

    local selectionResource
    local drawFavoriteStar = true
    selectionResource = getTexture("icons\\voshondsQuickSelect\\selected.tga")
    local pendingText = getTexture("icons\\buying.tga")

    local selectedContent = {}
    if selected then
        selectedContent = imageContent(selectionResource)
    end
    itemIcon = getTexture(iconPath)

    -- Format the slot number with the prefix if available
    local slotText = slotNumber
    if slotPrefix and slotPrefix ~= "" then
        -- Calculate the slot's position within its bar (1-10)
        local slotPosition = ((slotNumber - 1) % 10) + 1
        -- Display slot number with prefix
        slotText = slotPrefix .. slotPosition
    else
        -- For the first bar, just show the slot position (1-10)
        local slotPosition = ((slotNumber - 1) % 10) + 1
        slotText = slotPosition
    end

    local context = ui.content {
        imageContent(itemIcon, half),
        selectedContent,
        -- Add slot number to bottom right if we have it
        slotNumber and {
            type = ui.TYPE.Text,
            template = I.MWUI.templates.textNormal,
            props = {
                text = tostring(slotText),
                textSize = 14,                             -- Smaller size for the slot number
                relativePosition = util.vector2(0.9, 0.9), -- Bottom right position
                anchor = util.vector2(0.9, 0.9),
                arrange = ui.ALIGNMENT.End,
                align = ui.ALIGNMENT.End,
            }
        }
    }

    return context
end
local function getEmptyIcon(half, num, selected, useNumber, slotPrefix)
    local size = getIconSize()
    local selectionResource
    local drawFavoriteStar = true
    selectionResource = getTexture("icons\\voshondsQuickSelect\\selected.tga")

    local selectedContent = {}
    if selected then
        selectedContent = imageContent(selectionResource)
    end

    -- Format the slot number with the prefix if available
    local text = num
    if slotPrefix and slotPrefix ~= "" then
        -- Calculate the slot's position within its bar (1-10)
        local slotPosition = ((num - 1) % 10) + 1
        -- Display slot number with prefix
        text = slotPrefix .. slotPosition
    else
        -- For the first bar, just show the slot position (1-10)
        local slotPosition = ((num - 1) % 10) + 1
        text = slotPosition
    end

    -- Calculate proper size for the text, matching the icon size
    local textSize = 14 -- Smaller size for slot numbers
    if half then
        textSize = textSize / 1.5
    end

    return ui.content {
        selectedContent,
        {
            type = ui.TYPE.Text,
            template = I.MWUI.templates.textNormal,
            props = {
                text = tostring(text),
                textSize = textSize,
                relativePosition = util.vector2(0.9, 0.9), -- Bottom right position
                anchor = util.vector2(0.9, 0.9),
                arrange = ui.ALIGNMENT.End,
                align = ui.ALIGNMENT.End,
            },
            num = num,
            events = {
                --          mouseMove = async:callback(mouseMove),
            },
        }
    }
end

return {
    interfaceName = "Controller_Icon_QS",
    interface = {
        version = 1,
        getItemIcon = getItemIcon,
        getSpellIcon = getSpellIcon,
        getEmptyIcon = getEmptyIcon,
    },
    eventHandlers = {
    },
    engineHandlers = {
    }
}
