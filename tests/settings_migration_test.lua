local sections = {}
local playerSectionRequests = {}
local registeredRenderer

local function section(values)
    values = values or {}
    return {
        values = values,
        get = function(self, key)
            return self.values[key]
        end,
        getCopy = function(self, key)
            return self.values[key]
        end,
        set = function(self, key, value)
            self.values[key] = value
        end,
    }
end

package.preload["openmw.storage"] = function()
    return {
        allPlayerSections = function()
            return sections
        end,
        playerSection = function(name)
            table.insert(playerSectionRequests, name)
            if not sections[name] then
                sections[name] = section()
            end
            return sections[name]
        end,
    }
end

package.preload["openmw.async"] = function()
    return {
        callback = function(_, callback)
            return callback
        end,
    }
end

package.preload["openmw.ui"] = function()
    return {
        TYPE = { Container = "Container", Text = "Text" },
        ALIGNMENT = { Center = "Center" },
        content = function(content)
            return content
        end,
    }
end

package.preload["openmw.interfaces"] = function()
    return {
        MWUI = {
            templates = {
                borders = {},
                padding = {},
                textNormal = {},
            },
        },
        Settings = {
            registerRenderer = function(name, renderer)
                registeredRenderer = renderer
            end,
        },
    }
end

local searchers = package.searchers or package.loaders
table.insert(searchers, 1, function(name)
    local prefix = "scripts.voshondsquickselect."
    if string.sub(name, 1, #prefix) ~= prefix then
        return nil
    end

    local suffix = string.sub(name, #prefix + 1)
    local path = "scripts/voshondsQuickSelect/" .. string.gsub(suffix, "%.", "/") .. ".lua"
    local loader, err = loadfile(path)
    if not loader then
        return "\n\t" .. err
    end
    return loader
end)

local Migration = require("scripts.voshondsquickselect.services.settings_migration")

sections = {
    SettingsQuickSelect = section({
        visibleHotbars = 3,
        unEquipOnHotkey = true,
        hotBarOnTop = true,
        hotbarGutterSize = 11,
        hotbarVerticalSpacing = 24,
        iconSize = 64,
        persistMode = false,
    }),
    SettingsVoshondsQuickSelect = section({
        visibleHotbars = 1,
        toggleEquipment = false,
        hotBarOnTop = false,
        hotbarGutterSize = 0,
        hotbarVerticalSpacing = 0,
        iconSize = 32,
        enableFadingBars = true,
    }),
}

local result = Migration.importPre1023()
local current = sections.SettingsVoshondsQuickSelect

assert(result.status == "imported", "legacy settings are available for import")
assert(result.migrated == 6, "all compatible legacy values are imported")
assert(current:get("visibleHotbars") == 3, "the import overwrites current bar count")
assert(current:get("toggleEquipment") == true, "the old equipment key is mapped")
assert(current:get("hotBarOnTop") == true, "the import overwrites boolean settings")
assert(current:get("hotbarGutterSize") == 11, "the import overwrites spacing")
assert(current:get("hotbarVerticalSpacing") == 24, "the import overwrites vertical spacing")
assert(current:get("iconSize") == 64, "the import overwrites icon size")
assert(current:get("enableFadingBars") == true, "settings absent from legacy storage are retained")
assert(sections.SettingsQuickSelect:get("iconSize") == 64, "legacy storage is retained")

sections = {}
playerSectionRequests = {}

local notFound = Migration.importPre1023()
assert(notFound.status == "not_found", "missing legacy storage reports a clear outcome")
assert(#playerSectionRequests == 0, "a missing import source does not create either section")

sections = {
    SettingsQuickSelect = section({ visibleHotbars = 2 }),
    SettingsVoshondsQuickSelect = section({ visibleHotbars = 1 }),
}

require("scripts.voshondsquickselect.settings_menu")
assert(registeredRenderer, "settings menu registers the import button renderer")

local actionValue
local button = registeredRenderer(0, function(value)
    actionValue = value
end)
button.events.mouseClick()

assert(sections.SettingsVoshondsQuickSelect:get("visibleHotbars") == 2,
    "clicking the import button overwrites current settings")
assert(actionValue == 1, "the button reports how many settings were imported")

print("settings_migration_test: ok")
