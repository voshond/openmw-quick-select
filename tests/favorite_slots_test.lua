local inventoryItem = {
    id = "instance_1",
    recordId = "iron_sword",
    type = { records = { iron_sword = {} } },
}
local inventory = {
    find = function(_, recordId)
        return recordId == "iron_sword" and inventoryItem or nil
    end,
    findAll = function(_, recordId)
        return recordId == "iron_sword" and { inventoryItem } or {}
    end,
}

package.preload["openmw.self"] = function()
    return {}
end

package.preload["openmw.types"] = function()
    return {
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
assert(storage.interface.saveStoredItemData(inventoryItem, 5), "saving accepts the selected inventory object")
assert(slots[5].item == "iron_sword" and slots[5].itemInstanceId == "instance_1",
    "saving records both record and instance IDs")
storage.interface.deleteStoredItemData(5)
assert(slots[5].num == 5 and slots[5].item == nil and slots[5].itemInstanceId == nil,
    "deleting replaces the full slot and clears item metadata")

local saved = storage.engineHandlers.onSave()
assert(saved.version == 2 and #saved.storedItems == 30, "save data is versioned and normalized")

print("favorite_slots_test: ok")
