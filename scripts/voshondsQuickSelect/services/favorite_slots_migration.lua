local FavoriteSlotsMigration = {}

local SLOT_COUNT = 30

function FavoriteSlotsMigration.hasAssignments(slots)
    if type(slots) ~= "table" then
        return false
    end

    for slot = 1, SLOT_COUNT do
        local entry = slots[slot]
        if type(entry) == "table" and (entry.item or entry.spell or entry.enchantId or entry.itemId) then
            return true
        end
    end

    return false
end

function FavoriteSlotsMigration.copySlots(slots)
    local copied = {}

    for slot = 1, SLOT_COUNT do
        local source = type(slots) == "table" and slots[slot] or nil
        local entry = { num = slot, item = nil }

        if type(source) == "table" then
            for key, value in pairs(source) do
                entry[key] = value
            end
            entry.num = source.num or slot
        end

        copied[slot] = entry
    end

    return copied
end

return FavoriteSlotsMigration
