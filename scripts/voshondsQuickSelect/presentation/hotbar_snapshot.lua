local self = require("openmw.self")
local types = require("openmw.types")

local utility = require("scripts.voshondsquickselect.legacy.utility")
local ActorEquipment = require("scripts.voshondsquickselect.services.actor_equipment")
local FavoriteItem = require("scripts.voshondsquickselect.services.favorite_item")

local Snapshot = {}

local COMPARISON_FIELDS = {
    "kind",
    "assignmentId",
    "instanceId",
    "recordId",
    "iconPath",
    "available",
    "equipped",
    "selected",
    "count",
    "totalCount",
    "condition",
    "charge",
    "styleVersion",
}

local function valueId(value)
    if value == nil then
        return nil
    end
    return tostring(value)
end

local function actorSpell(spells, id)
    if not spells or not id then
        return nil
    end

    local spell = spells[id]
    if spell then
        return spell
    end

    for _, candidate in ipairs(spells) do
        if candidate.id == id then
            return candidate
        end
    end
    return nil
end

local function itemData(item)
    if not item or not types.Item or not types.Item.itemData then
        return nil
    end
    return types.Item.itemData(item)
end

local function itemCharge(item)
    if not item or not types.Item then
        return nil
    end

    -- itemData is the current API. A nil enchantmentCharge means a full,
    -- never-used enchantment, so derive the display value from the record
    -- instead of treating it as an unknown charge.
    local data = itemData(item)
    local charge = data and data.enchantmentCharge
    if charge == nil and types.Item.getEnchantmentCharge then
        charge = types.Item.getEnchantmentCharge(item)
    end

    if charge ~= nil then
        return math.floor(charge)
    end

    local record = item.type and item.type.records[item.recordId]
    local enchantment = record and utility.getEnchantment(record.enchant)
    if enchantment and enchantment.charge ~= nil then
        return math.floor(enchantment.charge)
    end

    return nil
end

local function inventoryCount(context, recordId)
    if not recordId then
        return 0
    end

    local cached = context.counts[recordId]
    if cached ~= nil then
        return cached
    end

    local count
    if context.inventory.countOf then
        count = context.inventory:countOf(recordId)
    else
        count = 0
        for _, item in ipairs(context.inventory:getAll()) do
            if item.recordId == recordId then
                count = count + (item.count or 1)
            end
        end
    end

    context.counts[recordId] = count
    return count
end

local function isEquipped(context, data, item)
    if data.spell and not data.enchantId then
        return context.selectedSpell ~= nil and context.selectedSpell.id == data.spell
    end

    if data.enchantId then
        return context.selectedEnchantedItem ~= nil
            and item ~= nil
            and FavoriteItem.isSameInstance(context.selectedEnchantedItem, item)
    end

    if not item then
        return false
    end

    if item.type == types.Lockpick or item.type == types.Probe or item.type == types.Light then
        for _, equippedItem in pairs(context.equipment) do
            if equippedItem == item then
                return true
            end
        end
        return false
    end

    local equipmentSlot = utility.findSlot(item)
    if equipmentSlot == nil then
        return false
    end
    return context.equipment[equipmentSlot] == item
end

local function effectIcon(record)
    if not record or not record.effects or not record.effects[1] then
        return nil
    end

    local effect = record.effects[1]
    local path = effect.effect and effect.effect.icon
    return utility.getSpellEffectBigIconPath(path)
end

local function isInterchangeablePotion(item)
    return item ~= nil and item.type == types.Potion
end

function Snapshot.begin(options)
    options = options or {}
    local actor = options.actor or self
    local inventory = options.inventory or types.Actor.inventory(actor)

    return {
        actor = actor,
        inventory = inventory,
        equipment = options.equipment or ActorEquipment.get(actor),
        spells = options.spells or types.Actor.spells(actor),
        selectedSpell = options.selectedSpell
            or (types.Actor.getSelectedSpell and types.Actor.getSelectedSpell(actor)),
        selectedEnchantedItem = options.selectedEnchantedItem
            or (types.Actor.getSelectedEnchantedItem and types.Actor.getSelectedEnchantedItem(actor)),
        selectedSlot = options.selectedSlot,
        styleVersion = options.styleVersion or 0,
        counts = {},
    }
end

function Snapshot.capture(slot, data, context)
    data = data or {}
    local snapshot = {
        slot = slot,
        data = data,
        kind = "empty",
        available = false,
        equipped = false,
        selected = context.selectedSlot == slot,
        styleVersion = context.styleVersion,
        dynamic = false,
    }

    if data.item then
        local item = FavoriteItem.resolve(context.inventory, data, isInterchangeablePotion)
        snapshot.kind = "item"
        snapshot.assignmentId = tostring(valueId(data.item) or "") .. ":" .. tostring(valueId(data.itemInstanceId) or "")
        snapshot.item = item
        snapshot.available = item ~= nil
        snapshot.dynamic = true

        if item then
            local record = item.type and item.type.records[item.recordId]
            local state = itemData(item)
            snapshot.instanceId = valueId(item.id or item)
            snapshot.recordId = item.recordId
            snapshot.iconPath = record and record.icon
            snapshot.count = item.count or 1
            snapshot.totalCount = inventoryCount(context, item.recordId)
            snapshot.condition = state and state.condition
            snapshot.charge = itemCharge(item)
        end
    elseif data.spell and data.spellType and data.spellType:lower() == "spell" then
        local spell = actorSpell(context.spells, data.spell)
        snapshot.kind = "spell"
        snapshot.assignmentId = valueId(data.spell)
        snapshot.magicRecord = spell
        snapshot.available = spell ~= nil
        snapshot.dynamic = true
        snapshot.iconPath = effectIcon(spell)
    elseif data.enchantId then
        local enchantment = utility.getEnchantment(data.enchantId)
        local item = FavoriteItem.resolve(context.inventory, data)
        snapshot.kind = "enchant"
        snapshot.assignmentId = tostring(valueId(data.enchantId) or "") .. ":" .. tostring(valueId(data.itemId) or "") .. ":" .. tostring(valueId(data.itemInstanceId) or "")
        snapshot.item = item
        snapshot.magicRecord = enchantment
        snapshot.available = enchantment ~= nil and item ~= nil
        snapshot.dynamic = true
        snapshot.recordId = item and item.recordId
        snapshot.instanceId = item and valueId(item.id or item)
        snapshot.iconPath = effectIcon(enchantment)
    elseif data.spell then
        -- Keep malformed or legacy spell assignments visible when possible.
        local spell = actorSpell(context.spells, data.spell)
        snapshot.kind = "spell"
        snapshot.assignmentId = valueId(data.spell)
        snapshot.magicRecord = spell
        snapshot.available = spell ~= nil
        snapshot.dynamic = true
        snapshot.iconPath = effectIcon(spell)
    end

    snapshot.equipped = isEquipped(context, data, snapshot.item)
    snapshot.renderState = {
        totalCount = snapshot.totalCount,
        charge = snapshot.charge,
        condition = snapshot.condition,
        equipped = snapshot.equipped,
    }
    return snapshot
end

function Snapshot.equals(left, right)
    if left == right then
        return true
    end
    if left == nil or right == nil then
        return false
    end

    for _, field in ipairs(COMPARISON_FIELDS) do
        if left[field] ~= right[field] then
            return false
        end
    end
    return true
end

function Snapshot.diff(previous, current)
    local changed = {}
    local seen = {}

    for slot, snapshot in pairs(current or {}) do
        seen[slot] = true
        if not Snapshot.equals(previous and previous[slot], snapshot) then
            changed[#changed + 1] = slot
        end
    end

    for slot in pairs(previous or {}) do
        if not seen[slot] then
            changed[#changed + 1] = slot
        end
    end

    table.sort(changed)
    return changed
end

return Snapshot
