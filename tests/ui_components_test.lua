local textureCalls = 0
local testInventoryItems = {}
local testSpells = {}

package.preload["openmw.async"] = function()
    return {
        callback = function(_, fn)
            return fn
        end,
    }
end

package.preload["openmw.ambient"] = function()
    return { playSound = function() end }
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

local function content(values)
    values = values or {}
    function values:add(value)
        table.insert(self, value)
    end
    return values
end

package.preload["openmw.ui"] = function()
    local module = {
        TYPE = {
            Container = "Container",
            Flex = "Flex",
            Image = "Image",
            Text = "Text",
            TextEdit = "TextEdit",
            Widget = "Widget",
        },
        ALIGNMENT = {
            Start = "Start",
            Center = "Center",
            End = "End",
        },
        content = content,
        texture = function(options)
            textureCalls = textureCalls + 1
            return { path = options.path }
        end,
        screenSize = function()
            return { x = 1920, y = 1080 }
        end,
    }

    function module.create(layout)
        local element = {
            layout = layout,
            updates = 0,
        }
        function element:update()
            self.updates = self.updates + 1
        end
        function element:destroy()
            self.destroyed = true
        end
        return element
    end

    return module
end

package.preload["openmw.interfaces"] = function()
    local templates = {
        borders = {},
        boxSolid = {},
        boxTransparent = {},
        boxTransparentThick = {},
        padding = {},
        textEditLine = {},
        textHeader = {},
        textNormal = {},
    }
    local controllerContent = function()
        return content({})
    end
    return {
        MWUI = { templates = templates },
        UI = {
            WINDOW = { QuickKeys = "QuickKeys" },
            registerWindow = function() end,
            setMode = function() end,
        },
        Controller_Icon_QS = {
            getItemIcon = controllerContent,
            getSpellIcon = controllerContent,
            getEmptyIcon = controllerContent,
        },
        QuickSelect_Storage = {
            getFavoriteItemData = function()
                return {}
            end,
            isSlotEquipped = function()
                return false
            end,
        },
    }
end

package.preload["openmw_aux.ui"] = function()
    return {
        deepDestroy = function(element)
            element:destroy()
        end,
    }
end

package.preload["openmw.core"] = function()
    return {
        getGMST = function(key)
            return key
        end,
        magic = {
            SPELL_TYPE = { Power = 1, Spell = 2 },
            ENCHANTMENT_TYPE = { CastOnUse = 1, CastOnce = 2 },
        },
    }
end

package.preload["openmw.input"] = function()
    return {
        KEY = {},
        CONTROLLER_BUTTON = {},
    }
end

package.preload["openmw.self"] = function()
    return {}
end

package.preload["openmw.storage"] = function()
    local section = {
        get = function() return nil end,
        subscribe = function() end,
    }
    return {
        playerSection = function()
            return section
        end,
    }
end

package.preload["openmw.types"] = function()
    local inventory = {
        getAll = function()
            return testInventoryItems
        end,
        find = function()
            return nil
        end,
    }
    return {
        Actor = {
            inventory = function()
                return inventory
            end,
            spells = function()
                return testSpells
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

local Hotbar = require("scripts.voshondsquickselect.ui.hotbar")
local Icon = require("scripts.voshondsquickselect.ui.icon")
local Modal = require("scripts.voshondsquickselect.ui.modal")
local ScrollView = require("scripts.voshondsquickselect.ui.scroll_view")
local SearchBar = require("scripts.voshondsquickselect.ui.search_bar")

local measured = Hotbar.measure(3, 40, 32, 5)
assert(measured.x == 130, "hotbar width includes slots and gaps")
assert(measured.y == 32, "hotbar height matches slot height")

local hotbar = Hotbar.create({
    slots = { {}, {}, {} },
    slotWidth = 40,
    slotHeight = 32,
    gap = 5,
})
assert(#hotbar.content == 5, "hotbar inserts one spacer between adjacent slots")

local compactHotbar = Hotbar.create({
    slots = { {}, {}, {} },
    slotSize = 40,
    gap = 0,
})
assert(#compactHotbar.content == 3, "zero hotbar gap inserts no hidden spacer layouts")

local beforeTexture = textureCalls
local textureA = Icon.texture("icons/test.dds")
local textureB = Icon.texture("icons/test.dds")
assert(textureA == textureB, "icon textures are cached")
assert(textureCalls == beforeTexture + 1, "cached texture is registered once")

local iconContent = Icon.content({
    size = 40,
    backgrounds = { { path = "icons/background.dds" } },
    path = "icons/base.dds",
    texts = { { text = "3" } },
})
assert(#iconContent == 3, "icon content composes background, base, and text")

local changedValue
local search = SearchBar.create({
    text = "",
    onChanged = function(value)
        changedValue = value
    end,
})
local inputLayout = SearchBar.getInput(search)
inputLayout.events.textChanged("amulet", inputLayout)
assert(changedValue == "amulet", "search field forwards text changes")
SearchBar.setText(inputLayout, "ring")
assert(inputLayout.props.text == "ring", "search field text can update without rebuilding its layout")

local scrolledContent = {
    type = "Flex",
    props = {
        size = { x = 200, y = 300 },
        position = { x = 0, y = 0 },
    },
}
local scroll = ScrollView.create({
    width = 214,
    height = 100,
    content = scrolledContent,
    itemHeight = 20,
})
ScrollView.scroll(scroll, 1)
local scrollState = scroll.layout.userData
assert(math.abs(scrollState.content.layout.props.position.y + 20) < 0.001, "scroll view moves by one item")
ScrollView.reset(scroll)
assert(scrollState.content.layout.props.position.y == 0, "scroll reset returns to the top")

local replacementContent = {
    type = "Flex",
    props = {
        size = { x = 200, y = 80 },
        position = { x = 0, y = 0 },
    },
}
ScrollView.replace(scroll, {
    width = 214,
    height = 100,
    content = replacementContent,
    itemHeight = 20,
})
assert(scrollState.content.destroyed, "scroll replacement disposes the previous content element")
assert(scroll.layout.userData.contentHeight == 80, "scroll replacement updates its content metrics")

local modal = Modal.create({
    title = "Quick Keys",
    content = { {} },
})
assert(modal.layer == "Windows", "modal uses the window layer by default")
assert(#modal.content[1].content == 2, "modal prepends its title to body content")

local selector = require("scripts.voshondsquickselect.select_items_win1")
assert(selector.interfaceName == "QuickSelect_Win1", "selector controller loads with its component dependencies")
selector.interface.drawQuickSelect()
assert(selector.interface.getQuickSelectWindow() ~= nil, "selector renders the shared three-hotbar view")
local hotbarWindow = selector.interface.getQuickSelectWindow()
local hotbarLayout = hotbarWindow.layout.content[1].content[4]
local firstSlot = hotbarLayout.content[1]
firstSlot.events.mouseClick(nil, firstSlot)

local actionWindow = selector.interface.getQuickSelectWindow()
local inventoryButton = actionWindow.layout.content[1].content[3]
inventoryButton.events.mouseClick(nil, inventoryButton)
assert(selector.interface.getQuickSelectWindow() ~= nil, "inventory selector renders from the slot action view")
local selectorWindow = selector.interface.getQuickSelectWindow()
local selectorSearch = selectorWindow.layout.content[1].content[3]
local selectorInput = SearchBar.getInput(selectorSearch)
selectorInput.events.textChanged("amulet", selectorInput)
assert(selector.interface.getQuickSelectWindow() == selectorWindow, "search refresh keeps the selector modal alive")
assert(SearchBar.getInput(selectorSearch) == selectorInput, "search refresh preserves the focused TextEdit layout")
local testInput = require("openmw.input")
testInput.KEY.Backspace = "Backspace"
selectorInput.events.focusGain(nil, selectorInput)
assert(selector.engineHandlers.onKeyPress({ code = testInput.KEY.Backspace }) == false,
    "focused search lets TextEdit receive Backspace")
selectorInput.events.focusLoss(nil, selectorInput)
assert(selector.engineHandlers.onKeyPress({ code = testInput.KEY.Backspace }) == true,
    "unfocused search retains the Backspace fallback")
assert(selectorInput.props.text == "amule", "unfocused Backspace updates the visible search text")

local Catalog = require("scripts.voshondsquickselect.qs_item_catalog")
testSpells = {
    {
        id = "example_non_fire_name",
        name = "Cinder Ward",
        type = 2,
        effects = {
            {
                effect = {
                    id = "fire_damage",
                    name = "Fire Damage",
                    school = "destruction",
                    icon = "icons/fire.dds",
                },
            },
        },
    },
}
local magicEntries = Catalog.magic()
assert(#Catalog.filter(magicEntries, "fire") == 1, "magic search includes effect names, not only spell names")
testSpells = {}

print("ui_components_test: ok")
