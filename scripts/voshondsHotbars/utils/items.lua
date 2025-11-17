-- Item utility functions for voshondsHotbars
-- Handles item-related logic: count display, charges, equipment slots, etc.

local types = require('openmw.types')
local core = require('openmw.core')
local constants = require('scripts.voshondshotbars.core.constants')

local items = {}

-- ============================================================================
-- ITEM COUNT DISPLAY
-- ============================================================================

--[[
    Determine if an item should always show its count

    Some items (consumables, ammo) should always display count even if count is 1
    Other items only show count when > 1
]]

-- Check if item type always shows count
-- @param item object (OpenMW item object)
-- @return boolean
function items.shouldShowCount(item)
    if not item or not item.type then
        return false
    end

    -- Check for item types that always show count
    if item.type == types.Lockpick or
       item.type == types.Probe or
       item.type == types.Repair or
       item.type == types.Potion then
        return true
    end

    -- Check for ammunition (arrows, bolts)
    if item.type == types.Weapon then
        local record = item.type.records[item.recordId]
        if record and record.type then
            local weaponType = record.type
            if weaponType == types.Weapon.TYPE.Arrow or
               weaponType == types.Weapon.TYPE.Bolt then
                return true
            end
        end
    end

    -- Other items: show count only if > 1
    return false
end

-- Get display count for an item
-- @param item object (OpenMW item object)
-- @param inventory object (OpenMW inventory object, optional)
-- @return number? count (nil if shouldn't display count)
function items.getDisplayCount(item, inventory)
    if not item then
        return nil
    end

    local alwaysShow = items.shouldShowCount(item)

    if alwaysShow then
        -- For stackable items, show total count in inventory
        if inventory then
            return items.getTotalCount(item, inventory)
        else
            return item.count or 1
        end
    elseif item.count and item.count > 1 then
        -- Show count only if > 1
        return item.count
    end

    return nil
end

-- Get total count of an item across entire inventory
-- @param item object (OpenMW item object)
-- @param inventory object (OpenMW inventory object)
-- @return number totalCount
function items.getTotalCount(item, inventory)
    if not item or not inventory then
        return 0
    end

    local total = 0
    local recordId = item.recordId

    -- Sum up all instances of this item in inventory
    for _, invItem in ipairs(inventory:getAll(item.type)) do
        if invItem.recordId == recordId then
            total = total + (invItem.count or 1)
        end
    end

    return total
end

-- ============================================================================
-- ITEM CHARGES
-- ============================================================================

-- Get item charge information
-- @param item object (OpenMW item object)
-- @return number? current, number? max (nil if item has no charges)
function items.getCharges(item)
    if not item then
        return nil, nil
    end

    -- Get item record
    local record = item.type and item.type.records and item.type.records[item.recordId]
    if not record then
        return nil, nil
    end

    -- Check if item has enchantment
    local enchantId = record.enchant
    if not enchantId or enchantId == "" then
        return nil, nil
    end

    -- Get enchantment record
    local enchantment = core.magic.enchantments.records[enchantId]
    if not enchantment then
        return nil, nil
    end

    -- Only show charges for items with "cast once" or "cast when used" enchantments
    local enchantType = enchantment.type
    if enchantType ~= core.magic.ENCHANTMENT_TYPE.CastOnce and
       enchantType ~= core.magic.ENCHANTMENT_TYPE.WhenUsed then
        return nil, nil
    end

    -- Get current and max charges
    local currentCharge = item.enchantmentCharge or 0
    local maxCharge = enchantment.charge or 0

    return currentCharge, maxCharge
end

-- Calculate charge percentage
-- @param item object (OpenMW item object)
-- @return number? percentage (0.0 to 1.0, nil if no charges)
function items.getChargePercent(item)
    local current, max = items.getCharges(item)

    if not current or not max or max == 0 then
        return nil
    end

    return math.max(0.0, math.min(1.0, current / max))
end

-- Check if item has charges
-- @param item object (OpenMW item object)
-- @return boolean
function items.hasCharges(item)
    local current, max = items.getCharges(item)
    return current ~= nil and max ~= nil
end

-- ============================================================================
-- EQUIPMENT SLOTS
-- ============================================================================

--[[
    Find the appropriate equipment slot for an item
    Based on original utility.findSlot() logic
]]

-- Get equipment slot for an item
-- @param item object (OpenMW item object)
-- @return number? slot (equipment slot ID, nil if not equippable)
function items.getEquipmentSlot(item)
    if not item or not item.type then
        return nil
    end

    local itemType = item.type

    -- Weapons go in weapon slot
    if itemType == types.Weapon then
        return types.Actor.EQUIPMENT_SLOT.CarriedRight
    end

    -- Armor pieces
    if itemType == types.Armor then
        local record = itemType.records[item.recordId]
        if not record then
            return nil
        end

        local armorType = record.type

        -- Map armor type to equipment slot
        local armorSlots = {
            [types.Armor.TYPE.Helmet] = types.Actor.EQUIPMENT_SLOT.Helmet,
            [types.Armor.TYPE.Cuirass] = types.Actor.EQUIPMENT_SLOT.Cuirass,
            [types.Armor.TYPE.LPauldron] = types.Actor.EQUIPMENT_SLOT.LeftPauldron,
            [types.Armor.TYPE.RPauldron] = types.Actor.EQUIPMENT_SLOT.RightPauldron,
            [types.Armor.TYPE.Greaves] = types.Actor.EQUIPMENT_SLOT.Greaves,
            [types.Armor.TYPE.Boots] = types.Actor.EQUIPMENT_SLOT.Boots,
            [types.Armor.TYPE.LGauntlet] = types.Actor.EQUIPMENT_SLOT.LeftGauntlet,
            [types.Armor.TYPE.RGauntlet] = types.Actor.EQUIPMENT_SLOT.RightGauntlet,
            [types.Armor.TYPE.Shield] = types.Actor.EQUIPMENT_SLOT.CarriedLeft,
            [types.Armor.TYPE.LBracer] = types.Actor.EQUIPMENT_SLOT.LeftGauntlet,
            [types.Armor.TYPE.RBracer] = types.Actor.EQUIPMENT_SLOT.RightGauntlet,
        }

        return armorSlots[armorType]
    end

    -- Clothing
    if itemType == types.Clothing then
        local record = itemType.records[item.recordId]
        if not record then
            return nil
        end

        local clothingType = record.type

        -- Map clothing type to equipment slot
        local clothingSlots = {
            [types.Clothing.TYPE.Amulet] = types.Actor.EQUIPMENT_SLOT.Amulet,
            [types.Clothing.TYPE.Belt] = types.Actor.EQUIPMENT_SLOT.Belt,
            [types.Clothing.TYPE.LGlove] = types.Actor.EQUIPMENT_SLOT.LeftGauntlet,
            [types.Clothing.TYPE.RGlove] = types.Actor.EQUIPMENT_SLOT.RightGauntlet,
            [types.Clothing.TYPE.Pants] = types.Actor.EQUIPMENT_SLOT.Greaves,
            [types.Clothing.TYPE.Ring] = types.Actor.EQUIPMENT_SLOT.Ring,
            [types.Clothing.TYPE.Robe] = types.Actor.EQUIPMENT_SLOT.Robe,
            [types.Clothing.TYPE.Shirt] = types.Actor.EQUIPMENT_SLOT.Shirt,
            [types.Clothing.TYPE.Shoes] = types.Actor.EQUIPMENT_SLOT.Boots,
            [types.Clothing.TYPE.Skirt] = types.Actor.EQUIPMENT_SLOT.Skirt,
        }

        return clothingSlots[clothingType]
    end

    -- Not an equippable item
    return nil
end

-- Check if item is equippable
-- @param item object (OpenMW item object)
-- @return boolean
function items.isEquippable(item)
    return items.getEquipmentSlot(item) ~= nil
end

-- ============================================================================
-- ITEM SEARCH & LOOKUP
-- ============================================================================

-- Find item in inventory by record ID
-- @param recordId string
-- @param inventory object (OpenMW inventory object)
-- @return object? item (nil if not found)
function items.findByRecordId(recordId, inventory)
    if not recordId or not inventory then
        return nil
    end

    -- Search through all item types
    for _, item in ipairs(inventory:getAll()) do
        if item.recordId == recordId then
            return item
        end
    end

    return nil
end

-- Check if actor has item
-- @param recordId string
-- @param inventory object (OpenMW inventory object)
-- @return boolean
function items.hasItem(recordId, inventory)
    return items.findByRecordId(recordId, inventory) ~= nil
end

-- ============================================================================
-- ITEM PROPERTIES
-- ============================================================================

-- Get item record
-- @param item object (OpenMW item object)
-- @return object? record
function items.getRecord(item)
    if not item or not item.type or not item.type.records then
        return nil
    end

    return item.type.records[item.recordId]
end

-- Get item enchantment ID
-- @param item object (OpenMW item object)
-- @return string? enchantId
function items.getEnchantmentId(item)
    local record = items.getRecord(item)
    if not record then
        return nil
    end

    local enchantId = record.enchant
    if enchantId and enchantId ~= "" then
        return enchantId
    end

    return nil
end

-- Check if item is enchanted
-- @param item object (OpenMW item object)
-- @return boolean
function items.isEnchanted(item)
    return items.getEnchantmentId(item) ~= nil
end

-- Get item icon path
-- @param item object (OpenMW item object)
-- @return string? iconPath
function items.getIcon(item)
    local record = items.getRecord(item)
    if not record then
        return nil
    end

    return record.icon
end

-- Get item name
-- @param item object (OpenMW item object)
-- @return string? name
function items.getName(item)
    local record = items.getRecord(item)
    if not record then
        return nil
    end

    return record.name
end

-- ============================================================================
-- NUMBER FORMATTING
-- ============================================================================

-- Format number for display (adds k/m suffixes for large numbers)
-- @param num number
-- @return string
function items.formatNumber(num)
    if not num then
        return "0"
    end

    if num >= 1000000 then
        return string.format("%.1fm", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fk", num / 1000)
    else
        return tostring(math.floor(num))
    end
end

return items
