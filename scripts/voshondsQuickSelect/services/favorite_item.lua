-- Resolves a saved Quick Select assignment to an inventory object.
--
-- Older saves contain only a record ID.  New assignments can also contain the
-- unique GameObject ID so two items with the same record but different charge
-- or condition do not silently resolve to whichever matching item happens to
-- be first in the inventory. Callers may explicitly allow a record-level
-- fallback for interchangeable stackable items whose GameObject can be
-- replaced by the engine as the stack is consumed.
local FavoriteItem = {}

function FavoriteItem.recordId(data)
    if type(data) ~= "table" then
        return nil
    end

    return data.item or data.itemId
end

function FavoriteItem.isSameInstance(left, right)
    if not left or not right then
        return false
    end

    if left.id ~= nil and right.id ~= nil then
        return tostring(left.id) == tostring(right.id)
    end

    return left == right
end

function FavoriteItem.resolve(inventory, data, canUseRecordFallback)
    local recordId = FavoriteItem.recordId(data)
    if not inventory or not recordId then
        return nil
    end

    local instanceId = data and data.itemInstanceId
    if instanceId then
        local candidates
        if inventory.findAll then
            candidates = inventory:findAll(recordId)
        elseif inventory.getAll then
            candidates = inventory:getAll()
        end

        for _, candidate in ipairs(candidates or {}) do
            if candidate.recordId == recordId and tostring(candidate.id) == tostring(instanceId) then
                return candidate
            end
        end

        local replacement = inventory.find and inventory:find(recordId)
        if replacement
            and canUseRecordFallback
            and canUseRecordFallback(replacement, data)
        then
            return replacement
        end

        -- Mutable items are intentionally unavailable when their exact
        -- instance is gone. Falling back for those would reintroduce the
        -- wrong-charge/wrong-condition behaviour instance IDs prevent.
        return nil
    end

    -- Preserve the old record-level behaviour for existing saves.
    return inventory:find(recordId)
end

return FavoriteItem
