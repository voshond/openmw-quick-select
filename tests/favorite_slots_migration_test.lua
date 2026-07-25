local FavoriteSlotsMigration = dofile("scripts/voshondsQuickSelect/services/favorite_slots_migration.lua")

local legacySlots = {
    [1] = { num = 1, spell = "fireball", spellType = "Spell" },
    [8] = { num = 8, enchantId = "ench_ring", itemId = "ring_01", spellType = "Enchant" },
    [10] = { num = 10, item = "iron_sword", recordId = "iron_sword" },
}

assert(FavoriteSlotsMigration.hasAssignments(legacySlots), "legacy assignments are detected")
assert(not FavoriteSlotsMigration.hasAssignments({ [1] = { num = 1, item = nil } }), "empty slots are not assignments")
assert(not FavoriteSlotsMigration.hasAssignments(nil), "missing slots are not assignments")

local copied = FavoriteSlotsMigration.copySlots(legacySlots)
assert(copied[1].spell == "fireball", "spell assignments are copied")
assert(copied[8].enchantId == "ench_ring", "enchanted-item assignments are copied")
assert(copied[10].item == "iron_sword", "inventory-item assignments are copied")
assert(copied[2].num == 2 and copied[2].item == nil, "missing legacy slots are normalised")

copied[1].spell = "changed"
assert(legacySlots[1].spell == "fireball", "the migration copies slot tables")

local importedSlots
package.preload["openmw.interfaces"] = function()
    return {
        QuickSelect_Storage = {
            importLegacyFavorites = function(slots)
                importedSlots = slots
                return true
            end,
        },
    }
end

local bridge = dofile("scripts/voshondsQuickSelect/ci_favorite_storage.lua")
bridge.engineHandlers.onLoad({ storedItems = legacySlots })
assert(importedSlots == legacySlots, "the legacy script path forwards its saved payload")

print("favorite slots migration tests passed")
