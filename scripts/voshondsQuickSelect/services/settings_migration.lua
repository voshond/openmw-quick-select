local storage = require("openmw.storage")

local SettingsMigration = {}

local CURRENT_SECTION = "SettingsVoshondsQuickSelect"
local LEGACY_SECTION = "SettingsQuickSelect"

-- These are the pre-1.0.23 main settings that still have a compatible meaning.
-- The import is intentionally destructive for these keys: it is a user-triggered
-- recovery action, not an automatic migration.
local settings = {
    { current = "visibleHotbars" },
    { current = "toggleEquipment", legacy = { "toggleEquipment", "unEquipOnHotkey" } },
    { current = "autoUnequipSheathedWeapons" },
    { current = "hotBarOnTop" },
    { current = "hotbarGutterSize" },
    { current = "hotbarVerticalSpacing" },
    { current = "iconSize" },
    { current = "enableDebugLogging" },
    { current = "enableFrameLogging" },
    { current = "enableFadingBars" },
}

local function readValue(section, key)
    if section.getCopy then
        return section:getCopy(key)
    end
    return section:get(key)
end

function SettingsMigration.importPre1023()
    if not storage.allPlayerSections then
        return { status = "unavailable", migrated = 0 }
    end

    -- Looking up the section in allPlayerSections avoids creating an empty
    -- legacy section when this installation has never used pre-1.0.23 builds.
    local ok, sections = pcall(storage.allPlayerSections)
    if not ok then
        return { status = "unavailable", migrated = 0 }
    end
    local legacy = sections[LEGACY_SECTION]
    if not legacy then
        return { status = "not_found", migrated = 0 }
    end

    local current = sections[CURRENT_SECTION] or storage.playerSection(CURRENT_SECTION)
    local migrated = 0

    for _, setting in ipairs(settings) do
        local legacyKeys = setting.legacy or { setting.current }
        for _, legacyKey in ipairs(legacyKeys) do
            local value = readValue(legacy, legacyKey)
            if value ~= nil then
                current:set(setting.current, value)
                migrated = migrated + 1
                break
            end
        end
    end

    return { status = "imported", migrated = migrated }
end

return SettingsMigration
