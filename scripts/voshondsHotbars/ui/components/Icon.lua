-- Icon component for voshondsHotbars
-- Unified icon creation for items, spells, and empty slots
-- Eliminates ~270 lines of duplicated icon creation logic

local ui = require('openmw.ui')
local util = require('openmw.util')
local constants = require('scripts.voshondshotbars.core.constants')
local textStyles = require('scripts.voshondshotbars.utils.text_styles')
local iconsUtil = require('scripts.voshondshotbars.utils.icons')
local itemsUtil = require('scripts.voshondshotbars.utils.items')
local spellsUtil = require('scripts.voshondshotbars.utils.spells')

local icon = {}

-- ============================================================================
-- ICON CREATION
-- ============================================================================

--[[
    Create a hotbar icon with all features:
    - Icon image (item/spell/empty)
    - Slot number display
    - Item count display
    - Charge display (for enchanted items)
    - Equipped indicator
    - Customizable size
]]

-- Create icon for an item
-- @param item object (OpenMW item object)
-- @param options table
--   - size: number (icon size, default ICON_SIZE_DEFAULT)
--   - slotNumber: number (1-30, for display)
--   - isEquipped: boolean (show equipped indicator)
--   - inventory: object (for total count calculation)
--   - actor: object (for enchantment charge lookup)
-- @return table UI element
function icon.createItemIcon(item, options)
    options = options or {}

    local size = options.size or constants.ICON_SIZE_DEFAULT
    local slotNumber = options.slotNumber
    local isEquipped = options.isEquipped or false

    -- Get item properties
    local iconPath = iconsUtil.getItemIcon(item)
    local itemCount = itemsUtil.getDisplayCount(item, options.inventory)
    local currentCharge, maxCharge = itemsUtil.getCharges(item)

    -- Build icon elements
    local elements = {}

    -- Base icon image
    if iconPath then
        table.insert(elements, {
            type = ui.TYPE.Image,
            props = {
                resource = iconsUtil.getCachedTexture({ path = iconPath }),
                size = util.vector2(size, size),
            }
        })
    end

    -- Slot number (if applicable)
    if slotNumber and textStyles.showSlotNumbers() then
        table.insert(elements, icon.createSlotNumberText(slotNumber, size))
    end

    -- Item count (if applicable)
    if itemCount and textStyles.showItemCounts() then
        table.insert(elements, icon.createCountText(itemCount, size))
    end

    -- Charge display (if enchanted)
    if currentCharge and maxCharge then
        table.insert(elements, icon.createChargeDisplay(currentCharge, maxCharge, size))
    end

    -- Equipped indicator
    if isEquipped then
        table.insert(elements, icon.createEquippedIndicator(size))
    end

    return {
        type = ui.TYPE.Container,
        props = {
            size = util.vector2(size, size),
        },
        content = ui.content(elements)
    }
end

-- Create icon for a spell
-- @param spell object (OpenMW spell object)
-- @param options table
--   - size: number (icon size)
--   - slotNumber: number (1-30)
--   - isEquipped: boolean
--   - useBigIcon: boolean (use big spell effect icon, default true)
-- @return table UI element
function icon.createSpellIcon(spell, options)
    options = options or {}

    local size = options.size or constants.ICON_SIZE_DEFAULT
    local slotNumber = options.slotNumber
    local isEquipped = options.isEquipped or false
    local useBigIcon = options.useBigIcon
    if useBigIcon == nil then useBigIcon = true end

    -- Get spell icon path
    local iconPath = spellsUtil.getSpellIconPath(spell, useBigIcon)

    -- Build icon elements
    local elements = {}

    -- Base spell icon
    if iconPath then
        table.insert(elements, {
            type = ui.TYPE.Image,
            props = {
                resource = iconsUtil.getCachedTexture({ path = iconPath }),
                size = util.vector2(size, size),
            }
        })
    end

    -- Slot number
    if slotNumber and textStyles.showSlotNumbers() then
        table.insert(elements, icon.createSlotNumberText(slotNumber, size))
    end

    -- Equipped indicator
    if isEquipped then
        table.insert(elements, icon.createEquippedIndicator(size))
    end

    return {
        type = ui.TYPE.Container,
        props = {
            size = util.vector2(size, size),
        },
        content = ui.content(elements)
    }
end

-- Create icon for an enchanted item (shows enchantment effect icon)
-- @param item object (OpenMW item object)
-- @param enchantment object (OpenMW enchantment object)
-- @param options table (same as createItemIcon plus useBigIcon)
-- @return table UI element
function icon.createEnchantedItemIcon(item, enchantment, options)
    options = options or {}

    local size = options.size or constants.ICON_SIZE_DEFAULT
    local slotNumber = options.slotNumber
    local isEquipped = options.isEquipped or false
    local useBigIcon = options.useBigIcon
    if useBigIcon == nil then useBigIcon = true end

    -- Get enchantment icon (effect icon, not item icon)
    local iconPath = spellsUtil.getEnchantmentIconPath(enchantment, useBigIcon)

    -- Get charge information
    local currentCharge, maxCharge = itemsUtil.getCharges(item)

    -- Build icon elements
    local elements = {}

    -- Base enchantment effect icon
    if iconPath then
        table.insert(elements, {
            type = ui.TYPE.Image,
            props = {
                resource = iconsUtil.getCachedTexture({ path = iconPath }),
                size = util.vector2(size, size),
            }
        })
    end

    -- Slot number
    if slotNumber and textStyles.showSlotNumbers() then
        table.insert(elements, icon.createSlotNumberText(slotNumber, size))
    end

    -- Charge display
    if currentCharge and maxCharge then
        table.insert(elements, icon.createChargeDisplay(currentCharge, maxCharge, size))
    end

    -- Equipped indicator
    if isEquipped then
        table.insert(elements, icon.createEquippedIndicator(size))
    end

    return {
        type = ui.TYPE.Container,
        props = {
            size = util.vector2(size, size),
        },
        content = ui.content(elements)
    }
end

-- Create empty slot icon
-- @param options table
--   - size: number (icon size)
--   - slotNumber: number (1-30)
-- @return table UI element
function icon.createEmptyIcon(options)
    options = options or {}

    local size = options.size or constants.ICON_SIZE_DEFAULT
    local slotNumber = options.slotNumber

    -- Build icon elements
    local elements = {}

    -- Empty background (semi-transparent black)
    table.insert(elements, {
        type = ui.TYPE.Widget,
        props = {
            size = util.vector2(size, size),
        },
    })

    -- Slot number (always show for empty slots)
    if slotNumber then
        table.insert(elements, icon.createSlotNumberText(slotNumber, size))
    end

    return {
        type = ui.TYPE.Container,
        props = {
            size = util.vector2(size, size),
        },
        content = ui.content(elements)
    }
end

-- ============================================================================
-- ICON SUB-ELEMENTS
-- ============================================================================

-- Create slot number text overlay
-- @param slotNumber number (1-30)
-- @param iconSize number
-- @return table UI element
function icon.createSlotNumberText(slotNumber, iconSize)
    local displayText = constants.formatSlotNumber(slotNumber, true)
    local template = textStyles.createSlotNumberTemplate()

    return {
        type = ui.TYPE.Text,
        props = {
            text = displayText,
            textSize = template.textSize,
            textColor = template.textColor,
            textShadow = template.textShadow,
            textShadowColor = template.textShadowColor,
            position = util.vector2(2, 2),  -- Top-left corner with small offset
            anchor = util.vector2(0, 0),
        }
    }
end

-- Create item count text overlay
-- @param count number
-- @param iconSize number
-- @return table UI element
function icon.createCountText(count, iconSize)
    local displayText = itemsUtil.formatNumber(count)
    local template = textStyles.createItemCountTemplate()

    return {
        type = ui.TYPE.Text,
        props = {
            text = displayText,
            textSize = template.textSize,
            textColor = template.textColor,
            textShadow = template.textShadow,
            textShadowColor = template.textShadowColor,
            position = util.vector2(iconSize - 2, iconSize - 2),  -- Bottom-right corner
            anchor = util.vector2(1, 1),  -- Anchor to bottom-right
        }
    }
end

-- Create charge display (text or bar)
-- @param currentCharge number
-- @param maxCharge number
-- @param iconSize number
-- @return table UI element
function icon.createChargeDisplay(currentCharge, maxCharge, iconSize)
    -- Display as text in top-right corner
    local chargePercent = currentCharge / maxCharge
    local displayText = string.format("%d/%d", math.floor(currentCharge), math.floor(maxCharge))

    -- Color based on charge level
    local color
    if chargePercent >= constants.CHARGE_THRESHOLD_MEDIUM then
        color = util.color.rgba(
            constants.CHARGE_COLOR_FULL[1],
            constants.CHARGE_COLOR_FULL[2],
            constants.CHARGE_COLOR_FULL[3],
            constants.CHARGE_COLOR_FULL[4]
        )
    elseif chargePercent >= constants.CHARGE_THRESHOLD_LOW then
        color = util.color.rgba(
            constants.CHARGE_COLOR_MEDIUM[1],
            constants.CHARGE_COLOR_MEDIUM[2],
            constants.CHARGE_COLOR_MEDIUM[3],
            constants.CHARGE_COLOR_MEDIUM[4]
        )
    else
        color = util.color.rgba(
            constants.CHARGE_COLOR_LOW[1],
            constants.CHARGE_COLOR_LOW[2],
            constants.CHARGE_COLOR_LOW[3],
            constants.CHARGE_COLOR_LOW[4]
        )
    end

    local template = textStyles.createItemCountTemplate()

    return {
        type = ui.TYPE.Text,
        props = {
            text = displayText,
            textSize = template.textSize,
            textColor = color,
            textShadow = template.textShadow,
            textShadowColor = template.textShadowColor,
            position = util.vector2(iconSize - 2, 2),  -- Top-right corner
            anchor = util.vector2(1, 0),  -- Anchor to top-right
        }
    }
end

-- Create equipped indicator overlay
-- @param iconSize number
-- @return table UI element
function icon.createEquippedIndicator(iconSize)
    local indicatorSize = constants.EQUIPPED_INDICATOR_SIZE
    local offset = constants.EQUIPPED_INDICATOR_OFFSET

    return {
        type = ui.TYPE.Widget,
        props = {
            size = util.vector2(indicatorSize, indicatorSize),
            position = util.vector2(offset, iconSize - indicatorSize - offset),
            color = util.color.rgba(
                constants.EQUIPPED_COLOR[1],
                constants.EQUIPPED_COLOR[2],
                constants.EQUIPPED_COLOR[3],
                constants.EQUIPPED_COLOR[4]
            ),
        }
    }
end

-- ============================================================================
-- HIGH-LEVEL FACTORY
-- ============================================================================

--[[
    Create icon from slot data

    This is the main entry point - determines what kind of icon to create
    based on the slot data type.
]]

-- Create icon from slot data
-- @param slotData table (from storage.getSlot())
-- @param options table
--   - size: number
--   - slotNumber: number
--   - isEquipped: boolean
--   - inventory: object (for item lookup)
--   - actor: object (for spell lookup)
-- @return table UI element
function icon.createFromSlotData(slotData, options)
    options = options or {}

    local slotType = slotData.type

    if slotType == constants.SLOT_TYPE_ITEM then
        -- Find item in inventory
        local item = options.inventory and
            itemsUtil.findByRecordId(slotData.recordId, options.inventory)

        if item then
            return icon.createItemIcon(item, options)
        else
            -- Item not in inventory, show empty
            return icon.createEmptyIcon(options)
        end

    elseif slotType == constants.SLOT_TYPE_SPELL then
        -- Find spell in actor's spell list
        local spell = options.actor and
            spellsUtil.getSpell(slotData.spellId, options.actor)

        if spell then
            return icon.createSpellIcon(spell, options)
        else
            -- Spell not available, show empty
            return icon.createEmptyIcon(options)
        end

    elseif slotType == constants.SLOT_TYPE_ENCHANT then
        -- Find item and enchantment
        local item = options.inventory and
            itemsUtil.findByRecordId(slotData.itemId, options.inventory)

        local enchantment = spellsUtil.getEnchantment(slotData.enchantId)

        if item and enchantment then
            return icon.createEnchantedItemIcon(item, enchantment, options)
        else
            -- Item or enchantment not available, show empty
            return icon.createEmptyIcon(options)
        end

    else
        -- Empty or unknown type
        return icon.createEmptyIcon(options)
    end
end

return icon
