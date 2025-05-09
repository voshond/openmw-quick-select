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
local settings = storage.playerSection("SettingsVoshondsQuickSelect")
local textSettings = storage.playerSection("SettingsVoshondsQuickSelectText")
local Debug = require("scripts.voshondsquickselect.qs_debug")

-- Function to get text appearance settings
local function getTextStyles()
    -- Get color settings or use defaults
    local textColor = textSettings:get("slotTextColor") or util.color.rgba(0.792, 0.647, 0.376, 1.0)
    local shadowColor = textSettings:get("slotTextShadowColor") or util.color.rgba(0, 0, 0, 1.0)

    -- Get alpha settings (0-100) and convert to 0-1 range
    local textAlpha = (textSettings:get("slotTextAlpha") or 100) / 100
    local shadowAlpha = (textSettings:get("slotTextShadowAlpha") or 100) / 100

    -- Apply alpha values to colors
    local finalTextColor = util.color.rgba(textColor.r, textColor.g, textColor.b, textAlpha)
    local finalShadowColor = util.color.rgba(shadowColor.r, shadowColor.g, shadowColor.b, shadowAlpha)

    -- Check if shadow is enabled
    local shadowEnabled = textSettings:get("enableTextShadow")
    if shadowEnabled == nil then shadowEnabled = true end -- Default to true if not set

    -- Check if slot numbers and item counts should be shown
    local showSlotNumbers = textSettings:get("showSlotNumbers")
    if showSlotNumbers == nil then showSlotNumbers = true end -- Default to true if not set

    local showItemCounts = textSettings:get("showItemCounts")
    if showItemCounts == nil then showItemCounts = true end -- Default to true if not set

    -- Get text sizes
    local slotNumberTextSize = textSettings:get("slotNumberTextSize") or 14
    local itemCountTextSize = textSettings:get("itemCountTextSize") or 12

    return {
        textColor = finalTextColor,
        shadowColor = finalShadowColor,
        shadowEnabled = shadowEnabled,
        showSlotNumbers = showSlotNumbers,
        showItemCounts = showItemCounts,
        slotNumberTextSize = slotNumberTextSize,
        itemCountTextSize = itemCountTextSize
    }
end

-- Define reusable text style variables
local TEXT_COLORS = {
    itemCount = nil, -- Will be set dynamically
    slotNumber = nil -- Will be set dynamically
}

local TEXT_SHADOWS = {
    enabled = true, -- Will be set dynamically
    color = nil     -- Will be set dynamically
}

-- Function to refresh text style settings
local function refreshTextStyles()
    local styles = getTextStyles()

    TEXT_COLORS.itemCount = styles.textColor
    TEXT_COLORS.slotNumber = styles.textColor

    TEXT_SHADOWS.enabled = styles.shadowEnabled
    TEXT_SHADOWS.color = styles.shadowColor
end

-- Initialize text styles
refreshTextStyles()

local function getIconSize()
    return settings:get("iconSize") or 40
end

local savedTextures = {}
local function getThresholdItemCountColor(count)
    local enable = textSettings:get("enableQuantityThresholdColor")
    if not enable then
        return getTextStyles().textColor
    end
    local critical = textSettings:get("quantityCriticalThreshold") or 1
    local warning = textSettings:get("quantityWarningThreshold") or 5
    local baseColor = textSettings:get("slotTextColor") or util.color.rgba(0.792, 0.647, 0.376, 1.0)
    local textAlpha = (textSettings:get("slotTextAlpha") or 100) / 100
    -- Red and orange for thresholds
    local warningColor = util.color.rgba(0.95, 0.15, 0.0, textAlpha) -- even deeper orange
    local criticalColor = util.color.rgba(1.0, 0.1, 0.1, textAlpha)  -- red
    if count <= critical then
        return criticalColor
    elseif count <= warning then
        -- Fade between orange and base color
        local t = (count - critical) / math.max(1, (warning - critical))
        return util.color.rgba(
            warningColor.r * (1 - t) + baseColor.r * t,
            warningColor.g * (1 - t) + baseColor.g * t,
            warningColor.b * (1 - t) + baseColor.b * t,
            textAlpha
        )
    else
        return baseColor
    end
end

local function textContent(text, isCharge)
    if not text or text == "" then
        return {}
    end
    refreshTextStyles()

    Debug.log("QuickSelect", "!!!!!!!!!!!!!isCharge " .. tostring(text) .. ", isCharge: " .. tostring(isCharge))

    -- Always show charge values for enchanted items, only check showItemCounts for regular item counts
    local styles = getTextStyles()
    if not isCharge and not styles.showItemCounts then
        return {}
    end
    local count = tonumber(text)
    local color = styles.textColor
    local position = util.vector2(0.1, 0.1) -- Default position (upper left)
    -- Special handling for charge values
    if isCharge then
        Debug.log("QuickSelect", "!!!!!!!!!!!!!isCharge " .. tostring(text) .. ", isCharge: " .. tostring(isCharge))
        color = util.color.rgba(0.2, 0.6, 1, 1) -- blue
    elseif count then
        color = getThresholdItemCountColor(count)
    end
    Debug.log("QuickSelect", "!!!!!!!!!!!!!isCharge " .. tostring(text) .. ", isCharge: " .. tostring(isCharge))
    return {
        type = ui.TYPE.Text,
        template = I.MWUI.templates.textNormal,
        props = {
            text = text,
            textSize = styles.itemCountTextSize,
            relativePosition = position,
            anchor = position,
            arrange = ui.ALIGNMENT.Start,
            align = ui.ALIGNMENT.Start,
            textShadow = TEXT_SHADOWS.enabled,
            textShadowColor = TEXT_SHADOWS.color,
            textColor = color
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

-- Helper to check if a table is empty
local function isEmptyTable(t)
    return type(t) == 'table' and next(t) == nil
end

local function getItemIcon(item, half, selected, slotNumber, slotPrefix, slotData)
    Debug.log("QuickSelect",
        "getItemIcon called for item: " ..
        tostring(item) ..
        ", type: " .. tostring(item and item.type) .. ", recordId: " .. tostring(item and item.recordId))
    if item and item.type and item.recordId then
        local record = item.type.records[item.recordId]
        Debug.log("QuickSelect",
            "Item record: " .. tostring(record and record.id) .. ", enchant: " .. tostring(record and record.enchant))
    end
    local itemIcon = nil

    local selectionResource
    local drawFavoriteStar = true
    selectionResource = getTexture("icons\\voshondsQuickSelect\\selected.tga")

    -- Get magic icon with reduced opacity (0.7)
    local magicIconOpacity = 0.3
    local magicIcon = FindEnchant(item) and FindEnchant(item) ~= "" and getTexture("textures\\menu_icon_magic_mini.dds")
    local text = ""
    local chargeText = {}    -- Ensure chargeText is always defined
    local itemCountText = {} -- Ensure itemCountText is always defined
    if item and item.type then
        local record = item.type.records[item.recordId]
        local enchantmentId = record and record.enchant
        if not record then
            Debug.error("ci_icon_render", "No record for " .. item.recordId)
        else
            Debug.log("ci_icon_render", "Icon: " .. tostring(record.icon))
        end
        if item.count > 1 then
            text = formatNumber(item.count)
        end
        itemIcon = getTexture(record.icon)

        -- Add enchanted item charge display (upper left, replaces item count if enchanted)
        if enchantmentId and enchantmentId ~= "" then
            Debug.log("QuickSelect",
                "Found enchantmentId: " .. tostring(enchantmentId) .. " for item: " .. tostring(item.recordId))
            local enchantment = core.magic.enchantments.records[enchantmentId]

            -- First try to get charge from item data
            local charge = nil
            local itemData = types.Item.itemData and types.Item.itemData(item)

            -- Use the proper API method: getEnchantmentCharge
            if types.Item.getEnchantmentCharge then
                charge = types.Item.getEnchantmentCharge(item)
                Debug.log("QuickSelect", "Got charge from types.Item.getEnchantmentCharge: " .. tostring(charge))
                -- Fallback to older methods
            elseif itemData and itemData.charge ~= nil then
                charge = itemData.charge
                Debug.log("QuickSelect", "Got charge from itemData.charge: " .. tostring(charge))
            elseif types.Item.charge then
                charge = types.Item.charge(item)
                Debug.log("QuickSelect", "Got charge from types.Item.charge: " .. tostring(charge))
                -- Use stored charge from slot data if available
            elseif slotData and slotData.lastKnownCharge then
                charge = slotData.lastKnownCharge
                Debug.log("QuickSelect", "Using stored charge from slot data: " .. tostring(charge))
            end

            Debug.log("QuickSelect", "Final charge value: " .. tostring(charge))

            if enchantment then
                Debug.log("QuickSelect", "Enchantment type: " .. tostring(enchantment.type))

                -- Only show charge for enchantments that use charges
                local usesCharge = (
                    enchantment.type == core.magic.ENCHANTMENT_TYPE.CastOnUse or
                    enchantment.type == core.magic.ENCHANTMENT_TYPE.CastOnStrike or
                    enchantment.type == core.magic.ENCHANTMENT_TYPE.CastOnce
                )

                Debug.log("QuickSelect", "usesCharge: " .. tostring(usesCharge) .. ", charge: " .. tostring(charge))

                if usesCharge and charge ~= nil then
                    charge = math.floor(charge)
                    local maxCharge = enchantment and enchantment.charge and math.floor(enchantment.charge) or "?"
                    Debug.log("QuickSelect",
                        "Displaying charge: " ..
                        tostring(charge) .. "/" .. tostring(maxCharge) .. " for item: " .. tostring(item.recordId))
                    chargeText = textContent(tostring(charge) .. "/" .. tostring(maxCharge), true)
                    Debug.log("QuickSelect",
                        "chargeText from textContent: " .. tostring(chargeText.props and chargeText.props.text))
                elseif usesCharge and charge == nil then
                    Debug.log("QuickSelect",
                        "Enchanted item has no charge property (even after fallback): " .. tostring(item.recordId))
                end
            end
        end
    end

    local selectedContent = {}
    if selected then
        selectedContent = imageContent(selectionResource)
    end

    -- Save item count text for the upper left
    itemCountText = textContent(tostring(text), false)

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

    -- Refresh text styles to ensure we have the latest settings
    refreshTextStyles()

    -- Create slot number content only if enabled
    local slotNumberContent = {}
    local styles = getTextStyles()

    if styles.showSlotNumbers and slotNumber then
        slotNumberContent = {
            type = ui.TYPE.Text,
            template = I.MWUI.templates.textNormal,
            props = {
                text = tostring(slotText),
                textSize = styles.slotNumberTextSize,
                relativePosition = util.vector2(0.85, 0.9),
                anchor = util.vector2(0.85, 0.9),
                arrange = ui.ALIGNMENT.End,
                align = ui.ALIGNMENT.End,
                textShadow = TEXT_SHADOWS.enabled,
                textShadowColor = TEXT_SHADOWS.color,
                textColor = TEXT_COLORS.slotNumber
            }
        }
    end

    -- Compose UI content
    local uiContent = { selectedContent, imageContent(magicIcon, half, magicIconOpacity), imageContent(itemIcon, half) }
    -- Insert chargeText if present, otherwise itemCountText
    if not isEmptyTable(chargeText) then
        Debug.log("QuickSelect",
            "Inserting chargeText into UI content array: " .. tostring(chargeText.props and chargeText.props.text))
        table.insert(uiContent, chargeText)
    elseif not isEmptyTable(itemCountText) then
        table.insert(uiContent, itemCountText)
    end
    -- Render the slot number as before
    --[[ if slotNumberContent and not isEmptyTable(slotNumberContent) then
        table.insert(uiContent, slotNumberContent)
    end ]] --
    Debug.log("QuickSelect",
        "Final UI content: " .. tostring(#uiContent) .. " elements, content: " .. tostring(uiContent))
    return ui.content(uiContent)
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

    -- Refresh text styles to ensure we have the latest settings
    refreshTextStyles()

    -- Create slot number content only if enabled
    local slotNumberContent = {}
    local styles = getTextStyles()

    if styles.showSlotNumbers and slotNumber then
        slotNumberContent = {
            type = ui.TYPE.Text,
            template = I.MWUI.templates.textNormal,
            props = {
                text = tostring(slotText),
                textSize = styles.slotNumberTextSize,
                relativePosition = util.vector2(0.85, 0.9),
                anchor = util.vector2(0.85, 0.9),
                arrange = ui.ALIGNMENT.End,
                align = ui.ALIGNMENT.End,
                textShadow = TEXT_SHADOWS.enabled,
                textShadowColor = TEXT_SHADOWS.color,
                textColor = TEXT_COLORS.slotNumber
            }
        }
    end

    local context = ui.content {
        imageContent(itemIcon, half),
        selectedContent,
        -- Add slot number to bottom right if we have it and it's enabled
        slotNumberContent
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

    -- Refresh text styles to ensure we have the latest settings
    refreshTextStyles()

    -- Only show number if slot numbers are enabled
    local styles = getTextStyles()
    if not styles.showSlotNumbers then
        return ui.content { selectedContent }
    end

    return ui.content {
        selectedContent,
        {
            type = ui.TYPE.Text,
            template = I.MWUI.templates.textNormal,
            props = {
                text = tostring(text),
                textSize = styles.slotNumberTextSize,
                relativePosition = util.vector2(0.85, 0.9),
                anchor = util.vector2(0.85, 0.9),
                arrange = ui.ALIGNMENT.End,
                align = ui.ALIGNMENT.End,
                textShadow = TEXT_SHADOWS.enabled,
                textShadowColor = TEXT_SHADOWS.color,
                textColor = TEXT_COLORS.slotNumber
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
        refreshTextStyles = refreshTextStyles -- Export this so it can be called when settings change
    },
    eventHandlers = {
    },
    engineHandlers = {
        onFrame = function()
            -- Check for settings changes periodically
            -- This is a lightweight operation since we're just fetching stored values
            refreshTextStyles()
        end
    }
}
