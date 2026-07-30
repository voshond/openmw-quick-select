local createCount = 0
local testCharge = 80
local testCount = 3
local favoriteData = {}

local function content(values)
    values = values or {}
    function values:add(value)
        table.insert(self, value)
    end
    return values
end

package.preload["openmw.async"] = function()
    return {
        callback = function(_, callback)
            return callback
        end,
    }
end

package.preload["openmw.util"] = function()
    return {
        vector2 = function(x, y)
            return { x = x, y = y }
        end,
        color = {
            rgba = function(r, g, b, a)
                return { r = r, g = g, b = b, a = a }
            end,
        },
    }
end

package.preload["openmw.ui"] = function()
    local module = {
        TYPE = {
            Container = "Container",
            Flex = "Flex",
            Image = "Image",
            Text = "Text",
            Widget = "Widget",
        },
        ALIGNMENT = {
            Start = "Start",
            Center = "Center",
            End = "End",
        },
        content = content,
        texture = function(options)
            return { path = options.path }
        end,
    }

    function module.create(layout)
        createCount = createCount + 1
        local element = {
            layout = layout,
            updates = 0,
            destroyed = false,
        }
        function element:update()
            self.updates = self.updates + 1
        end
        function element:destroy()
            self.destroyed = true
            self.layout = nil
        end
        return element
    end

    return module
end

package.preload["openmw_aux.ui"] = function()
    local function deepDestroy(element)
        if not element or not element.layout then
            return
        end

        local function destroyChildren(layout)
            for _, child in ipairs(layout.content or {}) do
                if child.layout then
                    deepDestroy(child)
                elseif child.content then
                    destroyChildren(child)
                end
            end
        end

        destroyChildren(element.layout)
        element:destroy()
    end

    return {
        deepDestroy = deepDestroy,
    }
end

local itemType = {
    records = {
        test_item = {
            icon = "icons/test_item.dds",
            enchant = "test_enchantment",
        },
    },
}

local item = {
    id = "instance_1",
    recordId = "test_item",
    type = itemType,
    count = testCount,
}

local inventory = {
    find = function(_, id)
        if id == "instance_1" or id == "test_item" then
            item.count = testCount
            return item
        end
        return nil
    end,
    findAll = function(_, recordId)
        return recordId == "test_item" and { item } or {}
    end,
    countOf = function(_, recordId)
        if recordId == "test_item" then
            return testCount
        end
        return 0
    end,
    getAll = function()
        return { item }
    end,
}

local actor = {}
local typesModule = {
    Actor = {
        inventory = function()
            return inventory
        end,
        spells = function()
            return {}
        end,
        getSelectedSpell = function()
            return nil
        end,
        getSelectedEnchantedItem = function()
            return nil
        end,
        getEquipment = function()
            return {}
        end,
        setStance = function() end,
        STANCE = { Spell = 1, Nothing = 2 },
    },
    Item = {
        itemData = function()
            return { condition = 50, enchantmentCharge = testCharge }
        end,
        getEnchantmentCharge = function()
            return testCharge
        end,
    },
    Lockpick = {},
    Probe = {},
    Light = {},
    Potion = itemType,
}

package.preload["openmw.types"] = function()
    return typesModule
end

package.preload["openmw.self"] = function()
    return actor
end

package.preload["openmw.core"] = function()
    return {
        isWorldPaused = function()
            return false
        end,
        magic = {
            spells = { records = {} },
        },
    }
end

package.preload["openmw.input"] = function()
    return {
        CONTROLLER_BUTTON = {},
    }
end

local sectionValues = {
    SettingsVoshondsQuickSelect = {
        iconSize = 32,
        visibleHotbars = 1,
        hotbarGutterSize = 0,
        hotbarVerticalSpacing = 0,
        enableFadingBars = false,
        disableIconShrinking = true,
    },
}
local subscriptions = {}

package.preload["openmw.storage"] = function()
    return {
        playerSection = function(name)
            local values = sectionValues[name] or {}
            sectionValues[name] = values
            return {
                get = function(_, key)
                    return values[key]
                end,
                set = function(_, key, value)
                    values[key] = value
                end,
                subscribe = function(_, callback)
                    subscriptions[name] = callback
                end,
            }
        end,
    }
end

local interfaces = {
    MWUI = {
        templates = {
            padding = {},
            borders = {},
        },
    },
    UI = {
        setMode = function() end,
        isHudVisible = function()
            return true
        end,
    },
    QuickSelect = {
        getSelectedPage = function()
            return 0
        end,
        setSelectedPage = function() end,
    },
    QuickSelect_Storage = {
        getFavoriteItemData = function(slot)
            return favoriteData[slot] or {}
        end,
        saveStoredItemData = function() end,
        saveStoredSpellData = function() end,
        saveStoredEnchantData = function() end,
        equipSlot = function() end,
    },
    Controller_Icon_QS = {
        getItemIcon = function()
            return content({})
        end,
        getSpellIcon = function()
            return content({})
        end,
        getEmptyIcon = function()
            return content({})
        end,
        refreshTextStyles = function() end,
    },
}

package.preload["openmw.interfaces"] = function()
    return interfaces
end

package.preload["scripts.voshondsquickselect.debug"] = function()
    return {
        isEnabled = function() return false end,
        hotbar = function() end,
        error = function(_, message) error(message) end,
    }
end

package.preload["scripts.voshondsquickselect.legacy.utility"] = function()
    return {
        getIconSize = function()
            return sectionValues.SettingsVoshondsQuickSelect.iconSize
        end,
        findSlot = function()
            return nil
        end,
        getSpellEffectBigIconPath = function(path)
            return path
        end,
        getEnchantment = function()
            return { charge = 100 }
        end,
        renderItemBoxed = function(iconContent, size)
            return {
                type = "Container",
                props = { size = size },
                content = iconContent,
            }
        end,
        itemWindowLocs = {
            BottomCenter = { anchor = { x = 0.5, y = 1 }, wx = 0.5, wy = 1 },
            TopCenter = { anchor = { x = 0.5, y = 0 }, wx = 0.5, wy = 0 },
        },
    }
end

package.preload["scripts.voshondsquickselect.presentation.tooltip_data"] = function()
    return {
        genToolTips = function()
            return nil
        end,
    }
end

package.preload["scripts.voshondsquickselect.ui.tooltip"] = function()
    return {
        ensureLayer = function() end,
        show = function() end,
        hide = function() end,
    }
end

local searchers = package.searchers or package.loaders
table.insert(searchers, 1, function(name)
    if package.preload[name] then
        return nil
    end

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

local Snapshot = require("scripts.voshondsquickselect.presentation.hotbar_snapshot")
favoriteData[1] = { item = "instance_1" }

local context = Snapshot.begin({ actor = actor, selectedSlot = 1 })
local first = Snapshot.capture(1, favoriteData[1], context)
local unchanged = Snapshot.capture(1, favoriteData[1], Snapshot.begin({ actor = actor, selectedSlot = 1 }))
assert(Snapshot.equals(first, unchanged), "identical captured state is not dirty")
assert(first.totalCount == 3, "snapshot captures the inventory count")
assert(first.charge == 80, "snapshot captures enchantment charge")

local replacementPotion = Snapshot.capture(
    2,
    { item = "test_item", itemInstanceId = "consumed_stack" },
    Snapshot.begin({ actor = actor, selectedSlot = 1 })
)
assert(replacementPotion.item == item and replacementPotion.totalCount == 3,
    "snapshot keeps tracking a potion count after OpenMW replaces its stack object")

testCharge = 79
local changedCharge = Snapshot.capture(1, favoriteData[1], Snapshot.begin({ actor = actor, selectedSlot = 1 }))
assert(not Snapshot.equals(first, changedCharge), "charge changes dirty the slot snapshot")

testCharge = nil
local fullCharge = Snapshot.capture(1, favoriteData[1], Snapshot.begin({ actor = actor, selectedSlot = 1 }))
assert(fullCharge.charge == 100, "an unused enchantment displays its full record charge")

local HotbarView = require("scripts.voshondsquickselect.ui.hotbar_view")
local standaloneView = HotbarView.create({
    rows = { { 1, 2 } },
    itemsPerRow = 2,
    slotSize = 32,
    gap = 0,
    verticalGap = 0,
    anchor = { x = 0.5, y = 1 },
    relativePosition = { x = 0.5, y = 1 },
    renderSlot = function(slot)
        return { type = "Widget", props = { slot = slot } }
    end,
})
assert(standaloneView.root.updates == 0, "creating a view does not perform a redundant root update")
HotbarView.updateSlot(standaloneView, 1, { type = "Widget", props = { slot = 1 } })
assert(standaloneView.slots[1].updates == 1, "slot updates target the independent child element")
assert(standaloneView.root.updates == 0, "slot updates do not update the hotbar root")
HotbarView.setVisible(standaloneView, false)
assert(standaloneView.root.updates == 1, "visibility changes update only the root")
HotbarView.destroy(standaloneView)

testCharge = 80
local controller = require("scripts.voshondsquickselect.controllers.hud_hotbar")
interfaces.QuickSelect_Hotbar = controller.interface
controller.engineHandlers.onLoad()
controller.engineHandlers.onFrame(0)

local initialMetrics = controller.interface.getPerformanceMetrics()
assert(initialMetrics.fullBuilds == 1, "the HUD creates one initial persistent view")

controller.interface.drawHotbar(false)
controller.interface.drawHotbar(false)
controller.engineHandlers.onFrame(0)
local coalescedMetrics = controller.interface.getPerformanceMetrics()
assert(coalescedMetrics.fullBuilds == 1, "repeated redraw requests do not rebuild the root")
assert(coalescedMetrics.slotUpdates == 0, "unchanged snapshots do not update slot elements")

testCount = 4
controller.interface.invalidateSlot(1, "test")
controller.engineHandlers.onFrame(0)
local countMetrics = controller.interface.getPerformanceMetrics()
assert(countMetrics.slotUpdates == 1, "one changed item count updates one slot")
assert(countMetrics.fullBuilds == 1, "a slot change preserves the root element")

controller.engineHandlers.onUpdate(0.5)
controller.engineHandlers.onFrame(0)
local unchangedPollMetrics = controller.interface.getPerformanceMetrics()
assert(unchangedPollMetrics.slotUpdates == 1, "an unchanged dynamic poll performs no UI update")

testCharge = 70
controller.engineHandlers.onUpdate(0.5)
controller.engineHandlers.onFrame(0)
local chargeMetrics = controller.interface.getPerformanceMetrics()
assert(chargeMetrics.slotUpdates == 2, "a charge poll updates only its changed slot")
assert(chargeMetrics.fullBuilds == 1, "charge changes never rebuild the root")

controller.interface.invalidateLayout("test")
controller.engineHandlers.onFrame(0)
local layoutMetrics = controller.interface.getPerformanceMetrics()
assert(layoutMetrics.fullBuilds == 2, "layout invalidation performs an explicit full rebuild")

sectionValues.SettingsVoshondsQuickSelect.visibleHotbars = 0
subscriptions.SettingsVoshondsQuickSelect(nil, "visibleHotbars")
controller.engineHandlers.onFrame(0)
assert(not controller.interface.isHotbarVisible(), "zero visible hotbars hides the HUD view")

local hiddenMetrics = controller.interface.getPerformanceMetrics()
controller.interface.drawHotbar(false)
controller.engineHandlers.onFrame(0)
assert(controller.interface.getPerformanceMetrics().fullBuilds == hiddenMetrics.fullBuilds,
    "zero visible hotbars does not rebuild an empty HUD view")

sectionValues.SettingsVoshondsQuickSelect.visibleHotbars = 1
subscriptions.SettingsVoshondsQuickSelect(nil, "visibleHotbars")
controller.engineHandlers.onFrame(0)
assert(controller.interface.isHotbarVisible(), "raising visible hotbars recreates the HUD view")

print("hotbar_performance_test: ok")
