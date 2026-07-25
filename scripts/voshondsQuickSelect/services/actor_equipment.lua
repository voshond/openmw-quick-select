local types = require("openmw.types")

-- OpenMW 0.51 documents Actor.getEquipment.  Keep the old name only as a
-- compatibility fallback for older runtimes, and keep that decision in one
-- place rather than letting every controller pick an API independently.
local ActorEquipment = {}

function ActorEquipment.get(actor)
    if types.Actor.getEquipment then
        return types.Actor.getEquipment(actor) or {}
    end

    if types.Actor.equipment then
        return types.Actor.equipment(actor) or {}
    end

    return {}
end

function ActorEquipment.findSlot(actor, item)
    if not item then
        return nil
    end

    for slot, equippedItem in pairs(ActorEquipment.get(actor)) do
        if equippedItem == item then
            return slot
        end
    end

    return nil
end

function ActorEquipment.has(actor, item)
    if not item then
        return false
    end

    if types.Actor.hasEquipped then
        return types.Actor.hasEquipped(actor, item)
    end

    return ActorEquipment.findSlot(actor, item) ~= nil
end

return ActorEquipment
