-- Slot component for voshondsHotbars
-- Container for hotbar icons with consistent sizing, spacing, and interaction

local ui = require('openmw.ui')
local util = require('openmw.util')
local constants = require('scripts.voshondshotbars.core.constants')
local iconComponent = require('scripts.voshondshotbars.ui.components.Icon')

local slot = {}

-- ============================================================================
-- SLOT CREATION
-- ============================================================================

--[[
    Create a hotbar slot container

    A slot is a container that:
    - Holds an icon (item/spell/empty)
    - Provides consistent sizing with padding
    - Handles hover states (future)
    - Provides click interaction (future)
]]

-- Create slot with icon
-- @param slotData table (from storage.getSlot())
-- @param options table
--   - size: number (icon size, default ICON_SIZE_DEFAULT)
--   - slotNumber: number (1-30, for display)
--   - isEquipped: boolean
--   - inventory: object
--   - actor: object
--   - padding: number (default ICON_SPACING)
--   - onClick: function (click handler, optional)
--   - onHover: function (hover handler, optional)
-- @return table UI element
function slot.create(slotData, options)
    options = options or {}

    local iconSize = options.size or constants.ICON_SIZE_DEFAULT
    local padding = options.padding or constants.ICON_SPACING
    local onClick = options.onClick
    local onHover = options.onHover

    -- Create the icon
    local iconElement = iconComponent.createFromSlotData(slotData, options)

    -- Calculate total slot size (icon + padding)
    local slotSize = iconSize * constants.ICON_PADDING_MULTIPLIER

    -- Build slot container
    local slotElement = {
        type = ui.TYPE.Container,
        props = {
            size = util.vector2(slotSize, slotSize),
        },
        content = ui.content({
            -- Center the icon within the slot
            {
                type = ui.TYPE.Container,
                props = {
                    size = util.vector2(iconSize, iconSize),
                    position = util.vector2((slotSize - iconSize) / 2, (slotSize - iconSize) / 2),
                },
                content = ui.content({ iconElement })
            }
        }),
    }

    -- Add interaction handlers if provided
    if onClick or onHover then
        -- TODO: Add event handlers when implementing interaction system
        -- For now, just return the base element
    end

    return slotElement
end

-- Create empty slot (convenience function)
-- @param slotNumber number (1-30)
-- @param options table (optional, size and padding)
-- @return table UI element
function slot.createEmpty(slotNumber, options)
    options = options or {}
    options.slotNumber = slotNumber

    local emptySlotData = {
        type = constants.SLOT_TYPE_EMPTY
    }

    return slot.create(emptySlotData, options)
end

-- ============================================================================
-- SLOT LAYOUT HELPERS
-- ============================================================================

--[[
    Helper functions for arranging slots in various layouts
]]

-- Calculate total width for a row of slots
-- @param numSlots number
-- @param iconSize number (optional, default ICON_SIZE_DEFAULT)
-- @param padding number (optional, default ICON_SPACING)
-- @return number totalWidth
function slot.calculateRowWidth(numSlots, iconSize, padding)
    iconSize = iconSize or constants.ICON_SIZE_DEFAULT
    padding = padding or constants.ICON_SPACING

    local slotSize = iconSize * constants.ICON_PADDING_MULTIPLIER

    return (slotSize * numSlots) + (padding * (numSlots - 1))
end

-- Calculate total height for a column of slots
-- @param numSlots number
-- @param iconSize number (optional)
-- @param padding number (optional)
-- @return number totalHeight
function slot.calculateColumnHeight(numSlots, iconSize, padding)
    -- Same calculation as row width
    return slot.calculateRowWidth(numSlots, iconSize, padding)
end

-- Create horizontal row of slots
-- @param slotDataList table (array of slot data)
-- @param options table
--   - size: number (icon size)
--   - startSlot: number (starting slot number for display, default 1)
--   - spacing: number (space between slots, default ICON_SPACING)
--   - inventory: object
--   - actor: object
--   - equippedSlots: table (set of equipped slot numbers, e.g., {1=true, 5=true})
-- @return table UI element (Flex container with horizontal layout)
function slot.createRow(slotDataList, options)
    options = options or {}

    local iconSize = options.size or constants.ICON_SIZE_DEFAULT
    local spacing = options.spacing or constants.ICON_SPACING
    local startSlot = options.startSlot or 1
    local equippedSlots = options.equippedSlots or {}

    local slots = {}

    for i, slotData in ipairs(slotDataList) do
        local slotNumber = startSlot + i - 1

        -- Check if this slot is equipped
        local isEquipped = equippedSlots[slotNumber] or false

        -- Create slot with all context
        local slotOptions = {
            size = iconSize,
            slotNumber = slotNumber,
            isEquipped = isEquipped,
            inventory = options.inventory,
            actor = options.actor,
            padding = spacing,
        }

        table.insert(slots, slot.create(slotData, slotOptions))

        -- Add spacing between slots (except after last)
        if i < #slotDataList and spacing > 0 then
            table.insert(slots, {
                type = ui.TYPE.Widget,
                props = {
                    size = util.vector2(spacing, iconSize),
                }
            })
        end
    end

    return {
        type = ui.TYPE.Flex,
        props = {
            horizontal = true,
            autoSize = true,
        },
        content = ui.content(slots)
    }
end

-- Create vertical column of slots
-- @param slotDataList table (array of slot data)
-- @param options table (same as createRow)
-- @return table UI element
function slot.createColumn(slotDataList, options)
    options = options or {}

    local iconSize = options.size or constants.ICON_SIZE_DEFAULT
    local spacing = options.spacing or constants.ICON_SPACING
    local startSlot = options.startSlot or 1
    local equippedSlots = options.equippedSlots or {}

    local slots = {}

    for i, slotData in ipairs(slotDataList) do
        local slotNumber = startSlot + i - 1
        local isEquipped = equippedSlots[slotNumber] or false

        local slotOptions = {
            size = iconSize,
            slotNumber = slotNumber,
            isEquipped = isEquipped,
            inventory = options.inventory,
            actor = options.actor,
            padding = spacing,
        }

        table.insert(slots, slot.create(slotData, slotOptions))

        -- Add spacing between slots (except after last)
        if i < #slotDataList and spacing > 0 then
            table.insert(slots, {
                type = ui.TYPE.Widget,
                props = {
                    size = util.vector2(iconSize, spacing),
                }
            })
        end
    end

    return {
        type = ui.TYPE.Flex,
        props = {
            horizontal = false,
            autoSize = true,
        },
        content = ui.content(slots)
    }
end

-- Create grid of slots
-- @param slotDataList table (array of slot data)
-- @param options table
--   - size: number (icon size)
--   - columns: number (slots per row)
--   - startSlot: number
--   - spacing: number
--   - inventory: object
--   - actor: object
--   - equippedSlots: table
-- @return table UI element
function slot.createGrid(slotDataList, options)
    options = options or {}

    local columns = options.columns or constants.SLOTS_PER_HOTBAR
    local rows = {}

    -- Split slots into rows
    for i = 1, #slotDataList, columns do
        local rowData = {}
        local rowStartSlot = (options.startSlot or 1) + i - 1

        for j = 0, columns - 1 do
            local index = i + j
            if index <= #slotDataList then
                table.insert(rowData, slotDataList[index])
            end
        end

        if #rowData > 0 then
            local rowOptions = {
                size = options.size,
                startSlot = rowStartSlot,
                spacing = options.spacing,
                inventory = options.inventory,
                actor = options.actor,
                equippedSlots = options.equippedSlots,
            }

            table.insert(rows, slot.createRow(rowData, rowOptions))
        end
    end

    -- Stack rows vertically
    return {
        type = ui.TYPE.Flex,
        props = {
            horizontal = false,
            autoSize = true,
        },
        content = ui.content(rows)
    }
end

return slot
