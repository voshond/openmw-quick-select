local core = require("openmw.core")

local self = require("openmw.self")
local types = require('openmw.types')
local nearby = require('openmw.nearby')
local storage = require('openmw.storage')
local async = require('openmw.async')
local util = require('openmw.util')
local ui = require('openmw.ui')
local I = require('openmw.interfaces')

local settings = storage.playerSection("SettingsVoshondsQuickSelect")

I.Settings.registerPage {
    key = "SettingsVoshondsQuickSelect",
    l10n = "SettingsVoshondsQuickSelect",
    name = "voshond's QuickSelect",
    description = "These settings allow you to modify the behavior of the Quickselect bar."
}
I.Settings.registerGroup {
    key = "SettingsVoshondsQuickSelect",
    page = "SettingsVoshondsQuickSelect",
    l10n = "SettingsVoshondsQuickSelect",
    name = "Main Settings",
    permanentStorage = true,
    description = [[
    These settings allow you to modify the behavior of the Quickselect bar.

    It allows for up to 3 separate hotbars, and you can select an item with 1-10, or use the arrow keys(when enabled), or the DPad on a controller to pick a slot.

    You should unbind the normal quick items before enabling this mod.
    ]],
    settings = {
        {
            key = "visibleHotbars",
            renderer = "number",
            name = "Number of Visible Hotbars",
            description = "Set how many hotbars should be visible at once (1-3). Value of 1 shows only the current hotbar, 2 shows current and one additional, 3 shows all hotbars.",
            default = 1,
            argument = {
                min = 1,
                max = 3,
            },
        },
        {
            key = "unEquipOnHotkey",
            renderer = "checkbox",
            name = "Unequip when selecting equipped items",
            description =
            "If enabled, selecting an item that is already equipped will unequip it. If disabled, selecting an item that is already equipped will do nothing.",
            default = true
        },
        {
            key = "hotBarOnTop",
            renderer = "checkbox",
            name = "Set Hotbar on Top",
            description =
            "If enabled, the hotbar will be displayed at the top.",
            default = false
        },
        {
            key = "hotbarGutterSize",
            renderer = "number",
            name = "Hotbar Item Spacing",
            description = "Controls the spacing between items in the hotbar. Higher values create more space between items.",
            default = 5,
            argument = {
                min = 0,
                max = 20,
            },
        },
        {
            key = "hotbarVerticalSpacing",
            renderer = "number",
            name = "Hotbar Vertical Spacing",
            description = "Controls the vertical spacing between stacked hotbars when multiple bars are shown. Lower values create tighter spacing.",
            default = 60,
            argument = {
                min = 0,
                max = 100,
            },
        },
        {
            key = "iconSize",
            renderer = "number",
            name = "Icon Size",
            description = "Controls the size of icons in the hotbar. Higher values create larger icons.",
            default = 40,
            argument = {
                min = 20,
                max = 100,
            },
        },
        {
            key = "enableDebugLogging",
            renderer = "checkbox",
            name = "Enable Debug Logging",
            description = "If enabled, debug print statements will be shown in the console. Useful for troubleshooting but may impact performance.",
            default = false
        },
        {
            key = "enableFadingBars",
            renderer = "checkbox",
            name = "Enable Fading Bars",
            description = "If enabled, the hotbar will automatically hide after 2 seconds of inactivity. It will reappear when you interact with items.",
            default = false
        },
    },

}
settings:get("unEquipOnHotkey")
return settings
