-- Centralized text styling for voshondsHotbars
-- Single source of truth for all text appearance settings

local util = require('openmw.util')
local storage = require('openmw.storage')
local constants = require('scripts.voshondshotbars.core.constants')

local textStyles = {}

-- ============================================================================
-- PRIVATE STATE
-- ============================================================================

local playerStorage = storage.playerSection(constants.SETTING_PREFIX)

-- Cached styles (refreshed when settings change)
local cachedStyles = nil

-- ============================================================================
-- SETTINGS HELPERS
-- ============================================================================

-- Get setting with default value
-- @param key string
-- @param default any
-- @return any
local function getSetting(key, default)
    local value = playerStorage:get(key)
    return value ~= nil and value or default
end

-- ============================================================================
-- STYLE GENERATION
-- ============================================================================

-- Generate text styles from settings
-- @return table styles
local function generateStyles()
    -- Get color settings or use defaults
    local textColorSetting = getSetting("slotTextColor", nil)
    local shadowColorSetting = getSetting("slotTextShadowColor", nil)

    -- Create default colors if not set
    local textColor = textColorSetting or util.color.rgba(
        constants.DEFAULT_TEXT_COLOR[1],
        constants.DEFAULT_TEXT_COLOR[2],
        constants.DEFAULT_TEXT_COLOR[3],
        constants.DEFAULT_TEXT_COLOR[4]
    )

    local shadowColor = shadowColorSetting or util.color.rgba(
        constants.DEFAULT_SHADOW_COLOR[1],
        constants.DEFAULT_SHADOW_COLOR[2],
        constants.DEFAULT_SHADOW_COLOR[3],
        constants.DEFAULT_SHADOW_COLOR[4]
    )

    -- Get alpha settings (0-100) and convert to 0-1 range
    local textAlpha = getSetting("slotTextAlpha", constants.DEFAULT_TEXT_ALPHA) / 100
    local shadowAlpha = getSetting("slotTextShadowAlpha", constants.DEFAULT_SHADOW_ALPHA) / 100

    -- Apply alpha values to colors
    local finalTextColor = util.color.rgba(
        textColor.r,
        textColor.g,
        textColor.b,
        textAlpha
    )

    local finalShadowColor = util.color.rgba(
        shadowColor.r,
        shadowColor.g,
        shadowColor.b,
        shadowAlpha
    )

    -- Get display settings
    local shadowEnabled = getSetting("enableTextShadow", true)
    local showSlotNumbers = getSetting("showSlotNumbers", true)
    local showItemCounts = getSetting("showItemCounts", true)

    -- Get text sizes
    local slotNumberTextSize = getSetting("slotNumberTextSize", 14)
    local itemCountTextSize = getSetting("itemCountTextSize", 12)

    return {
        textColor = finalTextColor,
        shadowColor = finalShadowColor,
        shadowEnabled = shadowEnabled,
        showSlotNumbers = showSlotNumbers,
        showItemCounts = showItemCounts,
        slotNumberTextSize = slotNumberTextSize,
        itemCountTextSize = itemCountTextSize,
    }
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

-- Get current text styles
-- Uses cached value if available, otherwise generates fresh
-- @return table styles
function textStyles.get()
    if not cachedStyles then
        cachedStyles = generateStyles()
    end

    return cachedStyles
end

-- Refresh cached styles (call when settings change)
function textStyles.refresh()
    cachedStyles = generateStyles()
end

-- Clear cache (force refresh on next get)
function textStyles.clearCache()
    cachedStyles = nil
end

-- Get specific style property
-- @param property string
-- @return any
function textStyles.getProperty(property)
    local styles = textStyles.get()
    return styles[property]
end

-- ============================================================================
-- CONVENIENCE FUNCTIONS
-- ============================================================================

-- Check if shadow is enabled
-- @return boolean
function textStyles.isShadowEnabled()
    return textStyles.getProperty("shadowEnabled")
end

-- Check if slot numbers should be shown
-- @return boolean
function textStyles.showSlotNumbers()
    return textStyles.getProperty("showSlotNumbers")
end

-- Check if item counts should be shown
-- @return boolean
function textStyles.showItemCounts()
    return textStyles.getProperty("showItemCounts")
end

-- Get text color
-- @return color
function textStyles.getTextColor()
    return textStyles.getProperty("textColor")
end

-- Get shadow color
-- @return color
function textStyles.getShadowColor()
    return textStyles.getProperty("shadowColor")
end

-- Get slot number text size
-- @return number
function textStyles.getSlotNumberSize()
    return textStyles.getProperty("slotNumberTextSize")
end

-- Get item count text size
-- @return number
function textStyles.getItemCountSize()
    return textStyles.getProperty("itemCountTextSize")
end

-- ============================================================================
-- TEMPLATE CREATION
-- ============================================================================

-- Create text template for slot numbers
-- Uses OpenMW text template format with configured styles
-- @return table template props
function textStyles.createSlotNumberTemplate()
    local styles = textStyles.get()

    local props = {
        textSize = styles.slotNumberTextSize,
        textColor = styles.textColor,
    }

    if styles.shadowEnabled then
        props.textShadow = true
        props.textShadowColor = styles.shadowColor
    end

    return props
end

-- Create text template for item counts
-- Uses OpenMW text template format with configured styles
-- @return table template props
function textStyles.createItemCountTemplate()
    local styles = textStyles.get()

    local props = {
        textSize = styles.itemCountTextSize,
        textColor = styles.textColor,
    }

    if styles.shadowEnabled then
        props.textShadow = true
        props.textShadowColor = styles.shadowColor
    end

    return props
end

-- Create generic text template with custom size
-- @param textSize number (optional, defaults to slot number size)
-- @return table template props
function textStyles.createTextTemplate(textSize)
    local styles = textStyles.get()

    local props = {
        textSize = textSize or styles.slotNumberTextSize,
        textColor = styles.textColor,
    }

    if styles.shadowEnabled then
        props.textShadow = true
        props.textShadowColor = styles.shadowColor
    end

    return props
end

return textStyles
