-- Icon utilities for voshondsHotbars
-- Handles icon path resolution and texture caching

local ui = require('openmw.ui')

local icons = {}

-- ============================================================================
-- TEXTURE CACHE
-- ============================================================================

-- Cache for UI textures to avoid recreating identical textures
-- Key format: concatenation of all texture properties
local textureCache = {}

-- ============================================================================
-- CACHE FUNCTIONS
-- ============================================================================

-- Build cache key from texture properties
-- @param props table (texture properties)
-- @return string cacheKey
local function buildCacheKey(props)
    local key = ""

    -- Sort keys for consistent cache keys
    local sortedKeys = {}
    for k in pairs(props) do
        table.insert(sortedKeys, k)
    end
    table.sort(sortedKeys)

    -- Build key from sorted properties
    for _, k in ipairs(sortedKeys) do
        local v = props[k]
        key = key .. tostring(k) .. ":" .. tostring(v) .. ";"
    end

    return key
end

-- Get or create cached texture
-- Based on Zerkish pattern - significantly improves performance
-- @param props table (texture properties for ui.texture())
-- @return texture
function icons.getCachedTexture(props)
    local key = buildCacheKey(props)

    if textureCache[key] then
        return textureCache[key]
    end

    -- Create new texture and cache it
    local texture = ui.texture(props)
    textureCache[key] = texture

    return texture
end

-- Clear texture cache (useful for testing or after major changes)
function icons.clearCache()
    textureCache = {}
end

-- Get cache size (for debugging/monitoring)
-- @return number cacheSize
function icons.getCacheSize()
    local count = 0
    for _ in pairs(textureCache) do
        count = count + 1
    end
    return count
end

-- ============================================================================
-- ICON PATH UTILITIES
-- ============================================================================

--[[
    Convert small spell effect icon path to big icon path

    OpenMW stores spell effects with small icons, but the game also has
    larger "b_" prefixed versions for better display.

    Example transformation:
    "textures/icons/magic/fireball.dds" -> "textures/icons/magic/b_fireball.dds"
]]

-- Get big icon path from small icon path
-- @param smallIconPath string
-- @return string? bigIconPath (nil if conversion failed)
function icons.getSpellEffectBigIconPath(smallIconPath)
    if not smallIconPath or type(smallIconPath) ~= "string" then
        return nil
    end

    -- Pattern to match filename.dds
    local pattern = "[%w_]+%.dds"

    local startPos, endPos = string.find(smallIconPath, pattern)

    if startPos and endPos then
        local directory = string.sub(smallIconPath, 1, startPos - 1)
        local filename = string.sub(smallIconPath, startPos, endPos)

        -- Add "b_" prefix to filename
        return string.format("%sb_%s", directory, filename)
    end

    -- Couldn't parse path, return original
    return smallIconPath
end

-- Check if an icon path is valid (exists and has correct format)
-- @param iconPath string
-- @return boolean
function icons.isValidPath(iconPath)
    if not iconPath or type(iconPath) ~= "string" then
        return false
    end

    -- Basic validation: should end with .dds and contain a path
    return iconPath:match("%.dds$") ~= nil and iconPath:find("/") ~= nil
end

-- Normalize icon path (ensure consistent format)
-- @param iconPath string
-- @return string normalizedPath
function icons.normalizePath(iconPath)
    if not iconPath then
        return ""
    end

    -- Convert backslashes to forward slashes
    iconPath = iconPath:gsub("\\", "/")

    -- Remove duplicate slashes
    iconPath = iconPath:gsub("//+", "/")

    -- Ensure lowercase extension
    iconPath = iconPath:gsub("%.DDS$", ".dds")

    return iconPath
end

-- ============================================================================
-- ICON DEFAULTS
-- ============================================================================

-- Default/fallback icon paths
local DEFAULT_ICONS = {
    item = "textures/menu_icon_magic.dds",  -- Generic item icon
    spell = "textures/menu_icon_magic.dds", -- Generic spell icon
    empty = "textures/menu_icon_blank.dds", -- Empty slot icon (if needed)
}

-- Get default icon for a given type
-- @param iconType string ("item", "spell", "empty")
-- @return string iconPath
function icons.getDefaultIcon(iconType)
    return DEFAULT_ICONS[iconType] or DEFAULT_ICONS.item
end

-- ============================================================================
-- ICON EXTRACTION HELPERS
-- ============================================================================

-- Get icon path from item
-- @param item object (OpenMW item object)
-- @return string? iconPath
function icons.getItemIcon(item)
    if not item then
        return nil
    end

    -- Get item record
    local record = item.type and item.type.records and item.type.records[item.recordId]

    if not record then
        return nil
    end

    -- Return icon from record
    return record.icon
end

-- Get icon path from spell
-- @param spell object (OpenMW spell object)
-- @param useBigIcon boolean (optional, default true)
-- @return string? iconPath
function icons.getSpellIcon(spell, useBigIcon)
    if useBigIcon == nil then
        useBigIcon = true
    end

    if not spell or not spell.effects or #spell.effects == 0 then
        return nil
    end

    -- Get first effect's icon
    local effect = spell.effects[1]
    if not effect or not effect.effect then
        return nil
    end

    local smallIconPath = effect.effect.icon

    if not smallIconPath then
        return nil
    end

    -- Convert to big icon if requested
    if useBigIcon then
        return icons.getSpellEffectBigIconPath(smallIconPath)
    else
        return smallIconPath
    end
end

-- Get icon path from enchantment
-- @param enchantment object (OpenMW enchantment object)
-- @param useBigIcon boolean (optional, default true)
-- @return string? iconPath
function icons.getEnchantmentIcon(enchantment, useBigIcon)
    if useBigIcon == nil then
        useBigIcon = true
    end

    if not enchantment or not enchantment.effects or #enchantment.effects == 0 then
        return nil
    end

    -- Get first effect's icon
    local effect = enchantment.effects[1]
    if not effect or not effect.effect then
        return nil
    end

    local smallIconPath = effect.effect.icon

    if not smallIconPath then
        return nil
    end

    -- Convert to big icon if requested
    if useBigIcon then
        return icons.getSpellEffectBigIconPath(smallIconPath)
    else
        return smallIconPath
    end
end

return icons
