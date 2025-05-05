local storage = require('openmw.storage')
local settings = storage.playerSection("SettingsVoshondsQuickSelect")

-- Debug module to centralize all logging functionality
local Debug = {}

-- Main logging function that checks if debug is enabled before printing
function Debug.log(module, message)
    if settings:get("enableDebugLogging") then
        print("[" .. module .. "] " .. tostring(message))
    end
end

-- Shorthand for specific module logs
function Debug.hotbar(message)
    Debug.log("HOTBAR DEBUG", message)
end

function Debug.quickSelect(message)
    Debug.log("QuickSelect", message)
end

function Debug.storage(message)
    Debug.log("QuickSelect_Storage", message)
end

function Debug.items(message)
    Debug.log("select_items_win1", message)
end

-- Function to report errors that will always print regardless of debug setting
function Debug.error(module, message)
    print("[ERROR:" .. module .. "] " .. tostring(message))
end

-- Function to report warnings that will always print regardless of debug setting
function Debug.warning(module, message)
    print("[WARNING:" .. module .. "] " .. tostring(message))
end

-- Utility function to create a conditional print function
-- This can be used to replace direct print() calls
function Debug.createPrinter(module)
    return function(message)
        Debug.log(module, message)
    end
end

-- Function to check if debug logging is enabled
function Debug.isEnabled()
    return settings:get("enableDebugLogging")
end

return Debug
