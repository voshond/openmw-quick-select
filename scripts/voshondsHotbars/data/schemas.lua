-- Data schemas and validation for voshondsHotbars
-- Defines data structures and provides type-safe validation

local constants = require('scripts.voshondshotbars.core.constants')

local schemas = {}

-- ============================================================================
-- SLOT DATA SCHEMAS
-- ============================================================================

--[[
    Slot data can be one of four types:

    1. Empty slot:
       { type = "empty" }

    2. Item slot:
       {
           type = "item",
           recordId = "iron sword"  -- item record ID
       }

    3. Spell slot:
       {
           type = "spell",
           spellId = "fireball"  -- spell ID
       }

    4. Enchanted item slot:
       {
           type = "enchant",
           itemId = "iron sword",      -- item record ID
           enchantId = "enchant_id"    -- enchantment ID
       }
]]

-- ============================================================================
-- VALIDATION FUNCTIONS
-- ============================================================================

-- Validate slot number
-- @param slot any
-- @return boolean isValid
-- @return string? errorMessage
function schemas.validateSlotNumber(slot)
    if type(slot) ~= "number" then
        return false, "Slot must be a number"
    end

    if not constants.isValidSlot(slot) then
        return false, string.format("Slot must be between 1 and %d", constants.TOTAL_SLOTS)
    end

    return true
end

-- Validate empty slot data
-- @param data table
-- @return boolean isValid
-- @return string? errorMessage
function schemas.validateEmptySlot(data)
    if type(data) ~= "table" then
        return false, "Slot data must be a table"
    end

    if data.type ~= constants.SLOT_TYPE_EMPTY then
        return false, "Empty slot must have type 'empty'"
    end

    return true
end

-- Validate item slot data
-- @param data table
-- @return boolean isValid
-- @return string? errorMessage
function schemas.validateItemSlot(data)
    if type(data) ~= "table" then
        return false, "Slot data must be a table"
    end

    if data.type ~= constants.SLOT_TYPE_ITEM then
        return false, "Item slot must have type 'item'"
    end

    if type(data.recordId) ~= "string" or data.recordId == "" then
        return false, "Item slot must have valid recordId string"
    end

    return true
end

-- Validate spell slot data
-- @param data table
-- @return boolean isValid
-- @return string? errorMessage
function schemas.validateSpellSlot(data)
    if type(data) ~= "table" then
        return false, "Slot data must be a table"
    end

    if data.type ~= constants.SLOT_TYPE_SPELL then
        return false, "Spell slot must have type 'spell'"
    end

    if type(data.spellId) ~= "string" or data.spellId == "" then
        return false, "Spell slot must have valid spellId string"
    end

    return true
end

-- Validate enchanted item slot data
-- @param data table
-- @return boolean isValid
-- @return string? errorMessage
function schemas.validateEnchantSlot(data)
    if type(data) ~= "table" then
        return false, "Slot data must be a table"
    end

    if data.type ~= constants.SLOT_TYPE_ENCHANT then
        return false, "Enchant slot must have type 'enchant'"
    end

    if type(data.itemId) ~= "string" or data.itemId == "" then
        return false, "Enchant slot must have valid itemId string"
    end

    if type(data.enchantId) ~= "string" or data.enchantId == "" then
        return false, "Enchant slot must have valid enchantId string"
    end

    return true
end

-- Validate any slot data
-- @param data table
-- @return boolean isValid
-- @return string? errorMessage
function schemas.validateSlotData(data)
    if type(data) ~= "table" then
        return false, "Slot data must be a table"
    end

    local slotType = data.type

    if slotType == constants.SLOT_TYPE_EMPTY then
        return schemas.validateEmptySlot(data)
    elseif slotType == constants.SLOT_TYPE_ITEM then
        return schemas.validateItemSlot(data)
    elseif slotType == constants.SLOT_TYPE_SPELL then
        return schemas.validateSpellSlot(data)
    elseif slotType == constants.SLOT_TYPE_ENCHANT then
        return schemas.validateEnchantSlot(data)
    else
        return false, string.format("Unknown slot type: %s", tostring(slotType))
    end
end

-- ============================================================================
-- FACTORY FUNCTIONS
-- ============================================================================

-- Create empty slot data
-- @return table
function schemas.createEmptySlot()
    return {
        type = constants.SLOT_TYPE_EMPTY
    }
end

-- Create item slot data
-- @param recordId string
-- @return table
function schemas.createItemSlot(recordId)
    assert(type(recordId) == "string" and recordId ~= "", "recordId must be non-empty string")

    return {
        type = constants.SLOT_TYPE_ITEM,
        recordId = recordId
    }
end

-- Create spell slot data
-- @param spellId string
-- @return table
function schemas.createSpellSlot(spellId)
    assert(type(spellId) == "string" and spellId ~= "", "spellId must be non-empty string")

    return {
        type = constants.SLOT_TYPE_SPELL,
        spellId = spellId
    }
end

-- Create enchanted item slot data
-- @param itemId string
-- @param enchantId string
-- @return table
function schemas.createEnchantSlot(itemId, enchantId)
    assert(type(itemId) == "string" and itemId ~= "", "itemId must be non-empty string")
    assert(type(enchantId) == "string" and enchantId ~= "", "enchantId must be non-empty string")

    return {
        type = constants.SLOT_TYPE_ENCHANT,
        itemId = itemId,
        enchantId = enchantId
    }
end

-- ============================================================================
-- TYPE CHECKING FUNCTIONS
-- ============================================================================

-- Check if slot data is empty
-- @param data table
-- @return boolean
function schemas.isEmpty(data)
    return type(data) == "table" and data.type == constants.SLOT_TYPE_EMPTY
end

-- Check if slot data is an item
-- @param data table
-- @return boolean
function schemas.isItem(data)
    return type(data) == "table" and data.type == constants.SLOT_TYPE_ITEM
end

-- Check if slot data is a spell
-- @param data table
-- @return boolean
function schemas.isSpell(data)
    return type(data) == "table" and data.type == constants.SLOT_TYPE_SPELL
end

-- Check if slot data is an enchanted item
-- @param data table
-- @return boolean
function schemas.isEnchant(data)
    return type(data) == "table" and data.type == constants.SLOT_TYPE_ENCHANT
end

-- ============================================================================
-- MIGRATION HELPERS
-- ============================================================================

--[[
    Convert old storage format to new schema

    Old format:
    - {item = "recordId"}
    - {spell = "spellId", spellType = "Spell"}
    - {itemId = "recordId", enchantId = "enchId", spellType = "Enchant"}

    New format:
    - {type = "item", recordId = "recordId"}
    - {type = "spell", spellId = "spellId"}
    - {type = "enchant", itemId = "recordId", enchantId = "enchId"}
]]

-- Convert old format slot data to new schema
-- @param oldData table
-- @return table newData
function schemas.migrateOldFormat(oldData)
    if type(oldData) ~= "table" then
        return schemas.createEmptySlot()
    end

    -- Check if already new format
    if oldData.type then
        return oldData
    end

    -- Convert old item format
    if oldData.item then
        return schemas.createItemSlot(oldData.item)
    end

    -- Convert old spell format
    if oldData.spell and oldData.spellType == "Spell" then
        return schemas.createSpellSlot(oldData.spell)
    end

    -- Convert old enchant format
    if oldData.itemId and oldData.enchantId and oldData.spellType == "Enchant" then
        return schemas.createEnchantSlot(oldData.itemId, oldData.enchantId)
    end

    -- Unknown format, return empty
    return schemas.createEmptySlot()
end

return schemas
