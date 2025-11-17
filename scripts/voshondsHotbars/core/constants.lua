-- Core constants for voshondsHotbars mod
-- Centralizes all magic numbers and configuration values

local constants = {}

-- ============================================================================
-- HOTBAR CONFIGURATION
-- ============================================================================

constants.SLOTS_PER_HOTBAR = 10
constants.TOTAL_HOTBARS = 3
constants.TOTAL_SLOTS = constants.SLOTS_PER_HOTBAR * constants.TOTAL_HOTBARS

-- Hotbar slot ranges
constants.HOTBAR_1_START = 1
constants.HOTBAR_1_END = 10
constants.HOTBAR_2_START = 11
constants.HOTBAR_2_END = 20
constants.HOTBAR_3_START = 21
constants.HOTBAR_3_END = 30

-- Slot prefixes for display
constants.SLOT_PREFIX = {
    [1] = "",   -- Hotbar 1: no prefix (1-10)
    [2] = "s",  -- Hotbar 2: shift prefix (s1-s10)
    [3] = "c",  -- Hotbar 3: ctrl prefix (c1-c10)
}

-- ============================================================================
-- UI SIZING
-- ============================================================================

constants.ICON_SIZE_SMALL = 32
constants.ICON_SIZE_MEDIUM = 40
constants.ICON_SIZE_LARGE = 48
constants.ICON_SIZE_DEFAULT = constants.ICON_SIZE_MEDIUM

constants.ICON_PADDING_MULTIPLIER = 1.2
constants.ICON_SPACING = 2

constants.EQUIPPED_INDICATOR_SIZE = 8
constants.EQUIPPED_INDICATOR_OFFSET = 2

constants.CHARGE_BAR_HEIGHT = 4
constants.CHARGE_BAR_Y_OFFSET = -2

-- ============================================================================
-- UPDATE INTERVALS & PERFORMANCE
-- ============================================================================

constants.UPDATE_THROTTLE_DEFAULT = 0.1  -- Minimum time between full redraws (seconds)
constants.HOTBAR_UPDATE_INTERVAL = 5.0   -- Periodic update check interval (seconds)
constants.ENCHANT_REFRESH_DEFAULT = 0.5  -- Default enchantment charge refresh interval (seconds)
constants.FADE_DURATION = 2.0            -- Hotbar fade out duration (seconds)
constants.FADE_CHECK_INTERVAL = 0.1      -- How often to check fade timer (seconds)

-- ============================================================================
-- COLOR DEFAULTS
-- ============================================================================

-- Text colors (RGBA format for util.color.rgba)
constants.DEFAULT_TEXT_COLOR = {0.792, 0.647, 0.376, 1.0}  -- Morrowind gold
constants.DEFAULT_SHADOW_COLOR = {0, 0, 0, 1.0}            -- Black shadow

-- Alpha defaults (0-100 for settings)
constants.DEFAULT_TEXT_ALPHA = 100
constants.DEFAULT_SHADOW_ALPHA = 100

-- Equipped indicator color
constants.EQUIPPED_COLOR = {0.0, 1.0, 0.0, 1.0}  -- Green

-- Charge bar colors
constants.CHARGE_COLOR_FULL = {0.0, 1.0, 0.0, 1.0}     -- Green
constants.CHARGE_COLOR_MEDIUM = {1.0, 1.0, 0.0, 1.0}   -- Yellow
constants.CHARGE_COLOR_LOW = {1.0, 0.0, 0.0, 1.0}      -- Red
constants.CHARGE_BACKGROUND = {0.0, 0.0, 0.0, 0.5}     -- Semi-transparent black

-- Charge thresholds (percentage)
constants.CHARGE_THRESHOLD_MEDIUM = 0.5  -- Below 50% shows yellow
constants.CHARGE_THRESHOLD_LOW = 0.25    -- Below 25% shows red

-- ============================================================================
-- INPUT MAPPING
-- ============================================================================

-- Key numbers (1-10, where 10 is the '0' key)
constants.KEY_NUMBERS = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}

-- Modifier keys for hotbar selection
constants.MODIFIER_NONE = "none"
constants.MODIFIER_SHIFT = "shift"
constants.MODIFIER_CTRL = "ctrl"
constants.MODIFIER_MOUSE4 = "mouse4"
constants.MODIFIER_MOUSE5 = "mouse5"

-- Map modifiers to hotbar pages
constants.MODIFIER_TO_PAGE = {
    [constants.MODIFIER_NONE] = 1,
    [constants.MODIFIER_SHIFT] = 2,
    [constants.MODIFIER_MOUSE4] = 2,
    [constants.MODIFIER_CTRL] = 3,
    [constants.MODIFIER_MOUSE5] = 3,
}

-- ============================================================================
-- DATA TYPES
-- ============================================================================

constants.SLOT_TYPE_EMPTY = "empty"
constants.SLOT_TYPE_ITEM = "item"
constants.SLOT_TYPE_SPELL = "spell"
constants.SLOT_TYPE_ENCHANT = "enchant"

-- ============================================================================
-- UI LAYERS
-- ============================================================================

constants.LAYER_WINDOWS = "Windows"
constants.LAYER_TOOLTIP = "TooltipLayer"
constants.LAYER_HUD = "HUD"

-- ============================================================================
-- ITEM CATEGORIES
-- ============================================================================

-- Item types that always show count
constants.COUNTED_ITEM_TYPES = {
    Lockpick = true,
    Probe = true,
    Repair = true,
    Potion = true,
}

-- Weapon types that show count (ammunition)
constants.AMMO_WEAPON_TYPES = {
    Arrow = true,
    Bolt = true,
}

-- ============================================================================
-- SETTINGS KEYS
-- ============================================================================

constants.SETTING_PREFIX = "VoshondsHotbars"

-- Settings groups
constants.SETTINGS_GROUP_GENERAL = "SettingsVoshondsHotbarsGeneral"
constants.SETTINGS_GROUP_APPEARANCE = "SettingsVoshondsHotbarsAppearance"
constants.SETTINGS_GROUP_TEXT = "SettingsVoshondsHotbarsText"
constants.SETTINGS_GROUP_PERFORMANCE = "SettingsVoshondsHotbarsPerformance"
constants.SETTINGS_GROUP_DEBUG = "SettingsVoshondsHotbarsDebug"

-- ============================================================================
-- DEBUG MODULES
-- ============================================================================

constants.DEBUG_MODULES = {
    "main",
    "hotbar",
    "storage",
    "input",
    "equip",
    "update",
    "ui",
    "icons",
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Get slot number from page and position
-- @param page number (1-3)
-- @param position number (1-10)
-- @return number slot (1-30)
function constants.getSlotNumber(page, position)
    return ((page - 1) * constants.SLOTS_PER_HOTBAR) + position
end

-- Get page and position from slot number
-- @param slot number (1-30)
-- @return page number (1-3), position number (1-10)
function constants.getPageAndPosition(slot)
    local page = math.ceil(slot / constants.SLOTS_PER_HOTBAR)
    local position = ((slot - 1) % constants.SLOTS_PER_HOTBAR) + 1
    return page, position
end

-- Get display slot number (1-10) from absolute slot (1-30)
-- @param slot number (1-30)
-- @return number (1-10)
function constants.getDisplaySlot(slot)
    return ((slot - 1) % constants.SLOTS_PER_HOTBAR) + 1
end

-- Get slot prefix for display
-- @param slot number (1-30)
-- @return string ("", "s", or "c")
function constants.getSlotPrefix(slot)
    local page = math.ceil(slot / constants.SLOTS_PER_HOTBAR)
    return constants.SLOT_PREFIX[page] or ""
end

-- Format slot number for display
-- @param slot number (1-30)
-- @param withPrefix boolean (optional, default true)
-- @return string (e.g., "c3", "s7", "5")
function constants.formatSlotNumber(slot, withPrefix)
    if withPrefix == nil then withPrefix = true end

    local displayNum = constants.getDisplaySlot(slot)

    if withPrefix then
        local prefix = constants.getSlotPrefix(slot)
        return prefix .. displayNum
    else
        return tostring(displayNum)
    end
end

-- Validate slot number
-- @param slot number
-- @return boolean
function constants.isValidSlot(slot)
    return slot >= 1 and slot <= constants.TOTAL_SLOTS
end

-- Validate page number
-- @param page number
-- @return boolean
function constants.isValidPage(page)
    return page >= 1 and page <= constants.TOTAL_HOTBARS
end

return constants
