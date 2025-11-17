-- Debug logging system for voshondsHotbars
-- Provides module-based logging with configurable verbosity

local storage = require('openmw.storage')
local constants = require('scripts.voshondshotbars.core.constants')

local debug = {}

-- ============================================================================
-- PRIVATE STATE
-- ============================================================================

local playerStorage = storage.playerSection(constants.SETTING_PREFIX)

-- ============================================================================
-- LOG LEVELS
-- ============================================================================

local LOG_LEVEL = {
    ERROR = 1,    -- Always shown
    WARNING = 2,  -- Always shown
    INFO = 3,     -- Shown when debug enabled
    FRAME = 4,    -- Shown when frame logging enabled
}

-- ============================================================================
-- SETTINGS HELPERS
-- ============================================================================

-- Check if debug logging is enabled
local function isDebugEnabled()
    return playerStorage:get("enableDebugLogging") or false
end

-- Check if frame logging is enabled
local function isFrameLoggingEnabled()
    return playerStorage:get("enableFrameLogging") or false
end

-- Check if specific module logging is enabled
local function isModuleEnabled(module)
    -- If general debug is off, only errors/warnings
    if not isDebugEnabled() then
        return false
    end

    -- Check per-module setting (if exists)
    local moduleSetting = "debug" .. module:sub(1,1):upper() .. module:sub(2)
    local moduleEnabled = playerStorage:get(moduleSetting)

    -- If no per-module setting, default to enabled when debug is on
    if moduleEnabled == nil then
        return true
    end

    return moduleEnabled
end

-- ============================================================================
-- CORE LOGGING FUNCTIONS
-- ============================================================================

-- Internal log function
-- @param level number (LOG_LEVEL)
-- @param module string
-- @param message string
local function logMessage(level, module, message)
    local prefix = ""

    if level == LOG_LEVEL.ERROR then
        prefix = "ERROR:"
    elseif level == LOG_LEVEL.WARNING then
        prefix = "WARNING:"
    elseif level == LOG_LEVEL.FRAME then
        prefix = "FRAME:"
    end

    local formattedMessage = string.format("[%s%s] %s", prefix, module, tostring(message))
    print(formattedMessage)
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

-- Log an error (always shown)
-- @param module string
-- @param message string
function debug.error(module, message)
    logMessage(LOG_LEVEL.ERROR, module, message)
end

-- Log a warning (always shown)
-- @param module string
-- @param message string
function debug.warning(module, message)
    logMessage(LOG_LEVEL.WARNING, module, message)
end

-- Log an info message (shown when debug enabled for module)
-- @param module string
-- @param message string
function debug.log(module, message)
    if isDebugEnabled() and isModuleEnabled(module) then
        logMessage(LOG_LEVEL.INFO, module, message)
    end
end

-- Log a frame message (high-frequency logging for animations/updates)
-- @param module string
-- @param message string
function debug.frame(module, message)
    if isFrameLoggingEnabled() and isModuleEnabled(module) then
        logMessage(LOG_LEVEL.FRAME, module, message)
    end
end

-- ============================================================================
-- MODULE-SPECIFIC LOGGERS
-- ============================================================================

-- Create module-specific logger functions for convenience
for _, moduleName in ipairs(constants.DEBUG_MODULES) do
    debug[moduleName] = function(message)
        debug.log(moduleName, message)
    end

    debug[moduleName .. "Frame"] = function(message)
        debug.frame(moduleName, message)
    end

    debug[moduleName .. "Error"] = function(message)
        debug.error(moduleName, message)
    end

    debug[moduleName .. "Warning"] = function(message)
        debug.warning(moduleName, message)
    end
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Check if debug logging is enabled
-- @return boolean
function debug.isEnabled()
    return isDebugEnabled()
end

-- Check if frame logging is enabled
-- @return boolean
function debug.isFrameEnabled()
    return isFrameLoggingEnabled()
end

-- Check if specific module logging is enabled
-- @param module string
-- @return boolean
function debug.isModuleEnabled(module)
    return isModuleEnabled(module)
end

-- Create a logger function for a custom module
-- @param moduleName string
-- @return function logger
function debug.createLogger(moduleName)
    return function(message)
        debug.log(moduleName, message)
    end
end

-- Create a frame logger function for a custom module
-- @param moduleName string
-- @return function frameLogger
function debug.createFrameLogger(moduleName)
    return function(message)
        debug.frame(moduleName, message)
    end
end

-- Format table for debugging
-- @param tbl table
-- @param indent number (optional)
-- @return string
function debug.formatTable(tbl, indent)
    if type(tbl) ~= "table" then
        return tostring(tbl)
    end

    indent = indent or 0
    local padding = string.rep("  ", indent)
    local result = "{\n"

    for key, value in pairs(tbl) do
        result = result .. padding .. "  " .. tostring(key) .. " = "

        if type(value) == "table" then
            result = result .. debug.formatTable(value, indent + 1)
        else
            result = result .. tostring(value)
        end

        result = result .. ",\n"
    end

    result = result .. padding .. "}"
    return result
end

-- Log table contents (for debugging)
-- @param module string
-- @param label string
-- @param tbl table
function debug.logTable(module, label, tbl)
    if isDebugEnabled() and isModuleEnabled(module) then
        local formatted = debug.formatTable(tbl)
        debug.log(module, label .. ": " .. formatted)
    end
end

return debug
