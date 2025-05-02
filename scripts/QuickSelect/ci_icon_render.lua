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
local function imageContent(resource, half)
    local size = getIconSize()
    local opacity = 1
    if half then
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

local function getItemIcon(item, half, selected, slotNumber)
    local itemIcon = nil

    local selectionResource
    local drawFavoriteStar = true
    selectionResource = getTexture("icons\\quickselect\\selected.tga")
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

    -- Format the slot number based on which bar it's on
    local formattedSlotNumber = ""
    if slotNumber then
        local slotNum = slotNumber % 10
        if slotNum == 0 then slotNum = 10 end

        if slotNumber <= 10 then
            -- Main bar (1-10)
            formattedSlotNumber = tostring(slotNum)
        elseif slotNumber <= 20 then
            -- Second bar (s1-s10)
            formattedSlotNumber = "s" .. tostring(slotNum)
        else
            -- Third bar (c1-c10)
            formattedSlotNumber = "c" .. tostring(slotNum)
        end
    end

    local context = ui.content {
        -- selectedContent,
        imageContent(magicIcon, half),
        imageContent(itemIcon, half),
        itemCountText,
        -- Add slot number to bottom right if we have it
        slotNumber and {
            type = ui.TYPE.Text,
            template = I.MWUI.templates.textNormal,
            props = {
                text = formattedSlotNumber,
                textSize = 14,                              -- Smaller size for the slot number
                relativePosition = util.vector2(0.85, 0.9), -- Bottom right position with margin
                anchor = util.vector2(0.85, 0.9),
                arrange = ui.ALIGNMENT.End,
                align = ui.ALIGNMENT.End,
                padding = util.vector4(0, 0, 5, 0), -- Add right padding/margin (left, top, right, bottom)
            }
        }
    }

    return context
end
local function getSpellIcon(iconPath, half, selected, slotNumber)
    local itemIcon = nil

    local selectionResource
    local drawFavoriteStar = true
    selectionResource = getTexture("icons\\quickselect\\selected.tga")
    local pendingText = getTexture("icons\\buying.tga")

    local selectedContent = {}
    if selected then
        selectedContent = imageContent(selectionResource)
    end
    itemIcon = getTexture(iconPath)

    -- Format the slot number based on which bar it's on
    local formattedSlotNumber = ""
    if slotNumber then
        local slotNum = slotNumber % 10
        if slotNum == 0 then slotNum = 10 end

        if slotNumber <= 10 then
            -- Main bar (1-10)
            formattedSlotNumber = tostring(slotNum)
        elseif slotNumber <= 20 then
            -- Second bar (s1-s10)
            formattedSlotNumber = "s" .. tostring(slotNum)
        else
            -- Third bar (c1-c10)
            formattedSlotNumber = "c" .. tostring(slotNum)
        end
    end

    local context = ui.content {
        imageContent(itemIcon, half),
        -- selectedContent,
        -- Add slot number to bottom right if we have it
        slotNumber and {
            type = ui.TYPE.Text,
            template = I.MWUI.templates.textNormal,
            props = {
                text = formattedSlotNumber,
                textSize = 14,                              -- Smaller size for the slot number
                relativePosition = util.vector2(0.85, 0.9), -- Bottom right position with margin
                anchor = util.vector2(0.85, 0.9),
                arrange = ui.ALIGNMENT.End,
                align = ui.ALIGNMENT.End,
                padding = util.vector4(0, 0, 5, 0), -- Add right padding/margin (left, top, right, bottom)
            }
        }
    }

    return context
end
local function getEmptyIcon(half, num, selected, useNumber)
    local size = getIconSize()
    local selectionResource
    local drawFavoriteStar = true
    selectionResource = getTexture("icons\\quickselect\\selected.tga")

    local selectedContent = {}
    if selected then
        selectedContent = imageContent(selectionResource)
    end

    -- Format the slot number based on which bar it's on
    local formattedSlotNumber = ""
    if num then
        local slotNum = num % 10
        if slotNum == 0 then slotNum = 10 end

        if num <= 10 then
            -- Main bar (1-10)
            formattedSlotNumber = tostring(slotNum)
        elseif num <= 20 then
            -- Second bar (s1-s10)
            formattedSlotNumber = "s" .. tostring(slotNum)
        else
            -- Third bar (c1-c10)
            formattedSlotNumber = "c" .. tostring(slotNum)
        end
    end

    -- Calculate proper size for the text, matching the icon size
    local textSize = 14 -- Smaller size for slot numbers
    if half then
        textSize = textSize / 1.5
    end

    return ui.content {
        -- selectedContent,
        {
            type = ui.TYPE.Text,
            template = I.MWUI.templates.textNormal,
            props = {
                text = formattedSlotNumber,
                textSize = textSize,
                relativePosition = util.vector2(0.85, 0.9), -- Bottom right position with margin
                anchor = util.vector2(0.85, 0.9),
                arrange = ui.ALIGNMENT.End,
                align = ui.ALIGNMENT.End,
                padding = util.vector4(0, 0, 5, 0), -- Add right padding/margin (left, top, right, bottom)
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
