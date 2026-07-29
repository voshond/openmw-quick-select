local weaponType = { records = { iron_sword = {} } }
local potionType = { records = { health_potion = {} } }
local inventoryItem = {
    id = "instance_1",
    recordId = "iron_sword",
    type = weaponType,
}
local potionStack = {
    id = "replacement_stack",
    recordId = "health_potion",
    type = potionType,
    count = 2,
}
local inventory = {
    find = function(_, recordId)
        if recordId == "iron_sword" then
            return inventoryItem
        elseif recordId == "health_potion" then
            return potionStack
        end
        return nil
    end,
    findAll = function(_, recordId)
        if recordId == "iron_sword" then
            return { inventoryItem }
        elseif recordId == "health_potion" then
            return { potionStack }
        end
        return {}
    end,
}

package.preload["openmw.self"] = function()
    return {}
end

package.preload["openmw.types"] = function()
    return {
        Potion = potionType,
        Actor = {
            inventory = function()
                return inventory
            end,
        },
    }
end

package.preload["openmw.core"] = function()
    return { sendGlobalEvent = function() end }
end

package.preload["openmw.async"] = function()
    return { newUnsavableSimulationTimer = function() end }
end

package.preload["openmw.storage"] = function()
    return {
        playerSection = function()
            return { get = function() return false end }
        end,
    }
end

package.preload["openmw.interfaces"] = function()
    return {}
end

package.preload["scripts.voshondsquickselect.legacy.utility"] = function()
    return { findSlot = function() return nil end }
end

package.preload["scripts.voshondsquickselect.debug"] = function()
    return {
        storage = function() end,
        warning = function() end,
    }
end

package.preload["scripts.voshondsquickselect.services.actor_equipment"] = function()
    return {
        get = function() return {} end,
        findSlot = function() return nil end,
    }
end

package.preload["scripts.voshondsquickselect.services.favorite_item"] = function()
    return dofile("scripts/voshondsQuickSelect/services/favorite_item.lua")
end

package.preload["scripts.voshondsquickselect.services.favorite_slots_migration"] = function()
    return dofile("scripts/voshondsQuickSelect/services/favorite_slots_migration.lua")
end

local storage = dofile("scripts/voshondsQuickSelect/services/favorite_slots.lua")

storage.engineHandlers.onLoad({
    storedItems = {
        [1] = { item = "iron_sword", itemInstanceId = "instance_1", lastKnownCharge = 7 },
        [2] = { enchantId = "ench_sword", itemId = "iron_sword", itemInstanceId = "instance_1" },
        [3] = { spell = "fireball", spellType = "anything" },
        [4] = { item = 42 },
        [6] = { item = "health_potion", itemInstanceId = "consumed_stack" },
        [8] = { item = "iron_sword", itemInstanceId = "missing" },
    },
})

local slots = storage.interface.getFavoriteItems()
assert(#slots == 30 and slots[30].num == 30, "loading normalizes the complete slot range")
assert(slots[1].item == "iron_sword" and slots[1].itemInstanceId == "instance_1",
    "loading preserves a valid instance assignment")
assert(slots[1].lastKnownCharge == nil, "obsolete charge metadata is discarded")
assert(slots[2].enchantId == "ench_sword" and slots[2].itemInstanceId == "instance_1",
    "loading preserves valid enchantment assignments")
assert(slots[3].spell == "fireball" and slots[3].spellType == "Spell",
    "loading normalizes legacy spell data")
assert(slots[4].item == nil, "loading rejects malformed slot entries")

assert(storage.interface.getFavoriteItem(1) == inventoryItem, "saved instance IDs resolve the intended object")
assert(storage.interface.getFavoriteItem(6) == potionStack,
    "saved potion slots follow the current stack after the assigned stack is consumed")
assert(storage.interface.getFavoriteItem(8) == nil,
    "saved mutable items remain unavailable when their assigned instance is gone")
assert(storage.interface.saveStoredItemData(inventoryItem, 5), "saving accepts the selected inventory object")
assert(slots[5].item == "iron_sword" and slots[5].itemInstanceId == "instance_1",
    "saving records both record and instance IDs")
storage.interface.deleteStoredItemData(5)
assert(slots[5].num == 5 and slots[5].item == nil and slots[5].itemInstanceId == nil,
    "deleting replaces the full slot and clears item metadata")
assert(storage.interface.saveStoredItemData(potionStack, 7), "saving accepts a potion stack")
assert(slots[7].item == "health_potion" and slots[7].itemInstanceId == nil,
    "saving keeps interchangeable potion stacks record-based")

-- OpenMW exposes GameObjects as userdata. A table-only type check accepts the
-- test doubles above but silently rejects real inventory-picker selections.
local selectedGameObject = io.tmpfile()
debug.setmetatable(selectedGameObject, {
    __index = {
        id = "userdata_instance",
        recordId = "ebony_sword",
        type = weaponType,
    },
})
assert(type(selectedGameObject) == "userdata", "the picker regression uses a userdata-shaped GameObject")
assert(storage.interface.saveStoredItemData(selectedGameObject, 9),
    "saving accepts an OpenMW userdata GameObject")
assert(slots[9].item == "ebony_sword" and slots[9].itemInstanceId == "userdata_instance",
    "userdata GameObjects preserve record and instance identity")

local saved = storage.engineHandlers.onSave()
assert(saved.version == 2 and #saved.storedItems == 30, "save data is versioned and normalized")

print("favorite_slots_test: ok")
