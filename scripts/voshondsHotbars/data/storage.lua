-- Persistent storage management for voshondsHotbars
-- Handles saving/loading hotbar slot data with validation

local storage = require('openmw.storage')
local constants = require('scripts.voshondshotbars.core.constants')
local schemas = require('scripts.voshondshotbars.data.schemas')

local storageModule = {}

-- ============================================================================
-- PRIVATE STATE
-- ============================================================================

-- Cache for slot data (lazy loaded)
local slotDataCache = nil

-- Player storage section for persistence
local playerStorage = storage.playerSection(constants.SETTING_PREFIX)

-- ============================================================================
-- PRIVATE FUNCTIONS
-- ============================================================================

-- Initialize slot data cache
-- Loads from persistent storage or creates default empty slots
local function initializeCache()
    if slotDataCache then
        return
    end

    slotDataCache = {}

    -- Try to load from persistent storage
    local savedData = playerStorage:get("hotbarSlots")

    if savedData and type(savedData) == "table" then
        -- Load saved slots and validate/migrate if needed
        for slot = 1, constants.TOTAL_SLOTS do
            local slotData = savedData[slot]

            if slotData then
                -- Migrate old format if needed
                slotData = schemas.migrateOldFormat(slotData)

                -- Validate
                local isValid, error = schemas.validateSlotData(slotData)
                if isValid then
                    slotDataCache[slot] = slotData
                else
                    -- Invalid data, use empty slot
                    print(string.format("Invalid data in slot %d: %s", slot, error or "unknown"))
                    slotDataCache[slot] = schemas.createEmptySlot()
                end
            else
                -- No data for this slot, create empty
                slotDataCache[slot] = schemas.createEmptySlot()
            end
        end
    else
        -- No saved data, initialize all empty slots
        for slot = 1, constants.TOTAL_SLOTS do
            slotDataCache[slot] = schemas.createEmptySlot()
        end
    end
end

-- Save cache to persistent storage
local function saveToStorage()
    initializeCache()
    playerStorage:set("hotbarSlots", slotDataCache)
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

-- Get data for a specific slot
-- @param slot number (1-30)
-- @return table slotData (never nil, returns empty slot if invalid)
function storageModule.getSlot(slot)
    initializeCache()

    -- Validate slot number
    local isValid, error = schemas.validateSlotNumber(slot)
    if not isValid then
        print("storage.getSlot: " .. error)
        return schemas.createEmptySlot()
    end

    return slotDataCache[slot] or schemas.createEmptySlot()
end

-- Set data for a specific slot
-- @param slot number (1-30)
-- @param data table (slot data conforming to schema)
-- @return boolean success
function storageModule.setSlot(slot, data)
    initializeCache()

    -- Validate slot number
    local slotValid, slotError = schemas.validateSlotNumber(slot)
    if not slotValid then
        print("storage.setSlot: " .. slotError)
        return false
    end

    -- Validate slot data
    local dataValid, dataError = schemas.validateSlotData(data)
    if not dataValid then
        print("storage.setSlot: " .. dataError)
        return false
    end

    -- Update cache
    slotDataCache[slot] = data

    -- Persist to storage
    saveToStorage()

    return true
end

-- Clear a specific slot (set to empty)
-- @param slot number (1-30)
-- @return boolean success
function storageModule.clearSlot(slot)
    return storageModule.setSlot(slot, schemas.createEmptySlot())
end

-- Save an item to a slot
-- @param slot number (1-30)
-- @param recordId string
-- @return boolean success
function storageModule.saveItem(slot, recordId)
    if type(recordId) ~= "string" or recordId == "" then
        print("storage.saveItem: recordId must be non-empty string")
        return false
    end

    local slotData = schemas.createItemSlot(recordId)
    return storageModule.setSlot(slot, slotData)
end

-- Save a spell to a slot
-- @param slot number (1-30)
-- @param spellId string
-- @return boolean success
function storageModule.saveSpell(slot, spellId)
    if type(spellId) ~= "string" or spellId == "" then
        print("storage.saveSpell: spellId must be non-empty string")
        return false
    end

    local slotData = schemas.createSpellSlot(spellId)
    return storageModule.setSlot(slot, slotData)
end

-- Save an enchanted item to a slot
-- @param slot number (1-30)
-- @param itemId string
-- @param enchantId string
-- @return boolean success
function storageModule.saveEnchant(slot, itemId, enchantId)
    if type(itemId) ~= "string" or itemId == "" then
        print("storage.saveEnchant: itemId must be non-empty string")
        return false
    end

    if type(enchantId) ~= "string" or enchantId == "" then
        print("storage.saveEnchant: enchantId must be non-empty string")
        return false
    end

    local slotData = schemas.createEnchantSlot(itemId, enchantId)
    return storageModule.setSlot(slot, slotData)
end

-- Get all slot data
-- @return table allSlots (indexed 1-30)
function storageModule.getAllSlots()
    initializeCache()

    -- Return a copy to prevent external modification
    local copy = {}
    for i = 1, constants.TOTAL_SLOTS do
        copy[i] = slotDataCache[i]
    end

    return copy
end

-- Check if a slot is empty
-- @param slot number (1-30)
-- @return boolean
function storageModule.isSlotEmpty(slot)
    local slotData = storageModule.getSlot(slot)
    return schemas.isEmpty(slotData)
end

-- Get slot type
-- @param slot number (1-30)
-- @return string type ("empty", "item", "spell", "enchant")
function storageModule.getSlotType(slot)
    local slotData = storageModule.getSlot(slot)
    return slotData.type or constants.SLOT_TYPE_EMPTY
end

-- Clear all slots
-- @return boolean success
function storageModule.clearAll()
    initializeCache()

    for slot = 1, constants.TOTAL_SLOTS do
        slotDataCache[slot] = schemas.createEmptySlot()
    end

    saveToStorage()
    return true
end

-- Force reload from storage (useful for testing/debugging)
function storageModule.reload()
    slotDataCache = nil
    initializeCache()
end

-- Export data for backup/debugging
-- @return table serialized slot data
function storageModule.exportData()
    initializeCache()
    return slotDataCache
end

-- Import data (for restoration/migration)
-- @param data table
-- @return boolean success
function storageModule.importData(data)
    if type(data) ~= "table" then
        print("storage.importData: data must be a table")
        return false
    end

    -- Validate all slots before importing
    for slot = 1, constants.TOTAL_SLOTS do
        local slotData = data[slot]
        if slotData then
            -- Migrate if needed
            slotData = schemas.migrateOldFormat(slotData)

            -- Validate
            local isValid, error = schemas.validateSlotData(slotData)
            if not isValid then
                print(string.format("storage.importData: Invalid data for slot %d: %s", slot, error))
                return false
            end
        end
    end

    -- All valid, import
    initializeCache()

    for slot = 1, constants.TOTAL_SLOTS do
        local slotData = data[slot]
        if slotData then
            slotData = schemas.migrateOldFormat(slotData)
            slotDataCache[slot] = slotData
        else
            slotDataCache[slot] = schemas.createEmptySlot()
        end
    end

    saveToStorage()
    return true
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

-- Initialize on module load
initializeCache()

return storageModule
