local async = require("openmw.async")
local I = require("openmw.interfaces")
local ui = require("openmw.ui")
local SettingsMigration = require("scripts.voshondsquickselect.services.settings_migration")

local RENDERER = "VoshondsQuickSelect/importPre1023Settings"

local function buttonLabel(result)
    if result == -1 then
        return "No pre-1.0.23 settings found"
    elseif result and result > 0 then
        return string.format("Imported %d setting%s — import again", result, result == 1 and "" or "s")
    end

    return "Import pre-1.0.23 settings"
end

I.Settings.registerRenderer(RENDERER, function(value, set)
    return {
        type = ui.TYPE.Container,
        template = I.MWUI.templates.borders,
        props = {
            autoSize = true,
            propagateEvents = false,
        },
        events = {
            mouseClick = async:callback(function()
                local result = SettingsMigration.importPre1023()
                set(result.migrated > 0 and result.migrated or -1)
            end),
        },
        content = ui.content({
            {
                type = ui.TYPE.Container,
                template = I.MWUI.templates.padding,
                content = ui.content({
                    {
                        type = ui.TYPE.Text,
                        template = I.MWUI.templates.textNormal,
                        props = {
                            text = buttonLabel(value),
                            textAlignH = ui.ALIGNMENT.Center,
                        },
                    },
                }),
            },
        }),
    }
end)
