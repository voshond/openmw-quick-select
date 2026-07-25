local equipment = { [1] = { id = "iron_sword" } }
local types = {
    Actor = {
        getEquipment = function()
            return equipment
        end,
        hasEquipped = function(_, item)
            return item == equipment[1]
        end,
    },
}

package.preload["openmw.types"] = function()
    return types
end

local ActorEquipment = dofile("scripts/voshondsQuickSelect/services/actor_equipment.lua")

assert(ActorEquipment.get({}) == equipment, "uses the documented Actor.getEquipment API")
assert(ActorEquipment.findSlot({}, equipment[1]) == 1, "finds an equipped item's slot")
assert(ActorEquipment.has({}, equipment[1]), "uses Actor.hasEquipped when available")

types.Actor.getEquipment = nil
types.Actor.equipment = function()
    return equipment
end
types.Actor.hasEquipped = nil

assert(ActorEquipment.get({}) == equipment, "keeps the legacy equipment API as a fallback")
assert(ActorEquipment.has({}, equipment[1]), "falls back to a slot lookup on old runtimes")

print("actor_equipment_test: ok")
