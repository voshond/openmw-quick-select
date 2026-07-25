local FavoriteItem = dofile("scripts/voshondsQuickSelect/services/favorite_item.lua")

local itemA = { id = "instance_a", recordId = "iron_sword" }
local itemB = { id = "instance_b", recordId = "iron_sword" }
local inventory = {
    find = function(_, recordId)
        return recordId == "iron_sword" and itemA or nil
    end,
    findAll = function(_, recordId)
        return recordId == "iron_sword" and { itemA, itemB } or {}
    end,
}

assert(FavoriteItem.resolve(inventory, { item = "iron_sword" }) == itemA,
    "legacy record-only assignments retain their existing behaviour")
assert(FavoriteItem.resolve(inventory, { item = "iron_sword", itemInstanceId = "instance_b" }) == itemB,
    "new item assignments retain the selected inventory instance")
assert(FavoriteItem.resolve(inventory, { item = "iron_sword", itemInstanceId = "missing" }) == nil,
    "missing assigned instances do not silently resolve to a different item")
assert(FavoriteItem.resolve(inventory, { itemId = "iron_sword", itemInstanceId = "instance_a" }) == itemA,
    "enchantment assignments use the same instance resolution")
assert(FavoriteItem.isSameInstance(itemA, { id = "instance_a", recordId = "iron_sword" }),
    "instance identity compares OpenMW object IDs instead of record IDs")
assert(not FavoriteItem.isSameInstance(itemA, itemB),
    "same-record objects remain distinct instances")

print("favorite_item_test: ok")
