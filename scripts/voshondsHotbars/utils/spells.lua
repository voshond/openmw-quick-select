-- Spell and enchantment utility functions for voshondsHotbars
-- Handles spell/enchantment lookups, equipped state, icon resolution, etc.

local types = require('openmw.types')
local core = require('openmw.core')
local icons = require('scripts.voshondshotbars.utils.icons')

local spells = {}

-- ============================================================================
-- SPELL LOOKUP
-- ============================================================================

-- Get spell by ID from actor's spell list
-- @param spellId string
-- @param actor object (OpenMW actor object)
-- @return object? spell (nil if not found)
function spells.getSpell(spellId, actor)
    if not spellId or not actor then
        return nil
    end

    local actorSpells = types.Actor.spells(actor)
    if not actorSpells then
        return nil
    end

    return actorSpells[spellId]
end

-- Check if actor has spell
-- @param spellId string
-- @param actor object (OpenMW actor object)
-- @return boolean
function spells.hasSpell(spellId, actor)
    return spells.getSpell(spellId, actor) ~= nil
end

-- ============================================================================
-- ENCHANTMENT LOOKUP
-- ============================================================================

-- Get enchantment record by ID
-- @param enchantId string
-- @return object? enchantment (nil if not found)
function spells.getEnchantment(enchantId)
    if not enchantId or enchantId == "" then
        return nil
    end

    return core.magic.enchantments.records[enchantId]
end

-- Check if enchantment exists
-- @param enchantId string
-- @return boolean
function spells.hasEnchantment(enchantId)
    return spells.getEnchantment(enchantId) ~= nil
end

-- Get enchantment from item
-- @param item object (OpenMW item object)
-- @return object? enchantment (nil if item not enchanted)
function spells.getItemEnchantment(item)
    if not item or not item.type or not item.type.records then
        return nil
    end

    local record = item.type.records[item.recordId]
    if not record or not record.enchant or record.enchant == "" then
        return nil
    end

    return spells.getEnchantment(record.enchant)
end

-- ============================================================================
-- EQUIPPED STATE
-- ============================================================================

-- Check if spell is currently selected/equipped
-- @param spellId string
-- @param actor object (OpenMW actor object)
-- @return boolean
function spells.isSpellEquipped(spellId, actor)
    if not spellId or not actor then
        return false
    end

    local selectedSpells = types.Actor.activeSpells(actor)
    if not selectedSpells then
        return false
    end

    -- Check if this spell is in the active spells list
    for _, activeSpell in ipairs(selectedSpells) do
        if activeSpell.id == spellId then
            return true
        end
    end

    return false
end

-- Get currently equipped spell
-- @param actor object (OpenMW actor object)
-- @return object? spell (nil if no spell equipped)
function spells.getEquippedSpell(actor)
    if not actor then
        return nil
    end

    local selectedSpells = types.Actor.activeSpells(actor)
    if not selectedSpells or #selectedSpells == 0 then
        return nil
    end

    -- Return first active spell (player can only have one selected at a time)
    return selectedSpells[1]
end

-- ============================================================================
-- SPELL ICONS
-- ============================================================================

-- Get icon path for spell
-- @param spell object (OpenMW spell object)
-- @param useBigIcon boolean (optional, default true)
-- @return string? iconPath
function spells.getSpellIconPath(spell, useBigIcon)
    return icons.getSpellIcon(spell, useBigIcon)
end

-- Get icon path from spell ID
-- @param spellId string
-- @param actor object (OpenMW actor object)
-- @param useBigIcon boolean (optional, default true)
-- @return string? iconPath
function spells.getSpellIconPathById(spellId, actor, useBigIcon)
    local spell = spells.getSpell(spellId, actor)
    if not spell then
        return nil
    end

    return spells.getSpellIconPath(spell, useBigIcon)
end

-- Get icon path for enchantment
-- @param enchantment object (OpenMW enchantment object)
-- @param useBigIcon boolean (optional, default true)
-- @return string? iconPath
function spells.getEnchantmentIconPath(enchantment, useBigIcon)
    return icons.getEnchantmentIcon(enchantment, useBigIcon)
end

-- Get icon path from enchantment ID
-- @param enchantId string
-- @param useBigIcon boolean (optional, default true)
-- @return string? iconPath
function spells.getEnchantmentIconPathById(enchantId, useBigIcon)
    local enchantment = spells.getEnchantment(enchantId)
    if not enchantment then
        return nil
    end

    return spells.getEnchantmentIconPath(enchantment, useBigIcon)
end

-- ============================================================================
-- SPELL PROPERTIES
-- ============================================================================

-- Get spell name
-- @param spell object (OpenMW spell object)
-- @return string? name
function spells.getSpellName(spell)
    if not spell then
        return nil
    end

    return spell.name
end

-- Get spell name by ID
-- @param spellId string
-- @param actor object (OpenMW actor object)
-- @return string? name
function spells.getSpellNameById(spellId, actor)
    local spell = spells.getSpell(spellId, actor)
    return spells.getSpellName(spell)
end

-- Get enchantment name
-- @param enchantment object (OpenMW enchantment object)
-- @return string? name
function spells.getEnchantmentName(enchantment)
    if not enchantment then
        return nil
    end

    -- Enchantments might not have names, return ID as fallback
    return enchantment.name or enchantment.id
end

-- Get primary effect from spell
-- @param spell object (OpenMW spell object)
-- @return object? effect (first effect of spell)
function spells.getPrimaryEffect(spell)
    if not spell or not spell.effects or #spell.effects == 0 then
        return nil
    end

    return spell.effects[1]
end

-- Get primary effect from enchantment
-- @param enchantment object (OpenMW enchantment object)
-- @return object? effect (first effect of enchantment)
function spells.getPrimaryEnchantmentEffect(enchantment)
    if not enchantment or not enchantment.effects or #enchantment.effects == 0 then
        return nil
    end

    return enchantment.effects[1]
end

-- ============================================================================
-- SPELL COST & CASTING
-- ============================================================================

-- Get spell magicka cost
-- @param spell object (OpenMW spell object)
-- @return number cost
function spells.getSpellCost(spell)
    if not spell then
        return 0
    end

    return spell.cost or 0
end

-- Check if actor can cast spell (has enough magicka)
-- @param spell object (OpenMW spell object)
-- @param actor object (OpenMW actor object)
-- @return boolean
function spells.canCastSpell(spell, actor)
    if not spell or not actor then
        return false
    end

    local cost = spells.getSpellCost(spell)
    local actorStats = types.Actor.stats

.dynamic(actor)

    if not actorStats or not actorStats.magicka then
        return false
    end

    local currentMagicka = actorStats.magicka.current

    return currentMagicka >= cost
end

-- Get spell success chance
-- @param spell object (OpenMW spell object)
-- @param actor object (OpenMW actor object)
-- @return number percentage (0-100)
function spells.getSpellSuccessChance(spell, actor)
    if not spell or not actor then
        return 0
    end

    -- OpenMW calculates success chance based on skill, willpower, luck, etc.
    -- This is a simplified version - actual calculation is complex
    -- For now, return a placeholder
    -- TODO: Implement proper success chance calculation if needed
    return 100
end

-- ============================================================================
-- ENCHANTMENT CHARGES
-- ============================================================================

-- Get enchantment max charge
-- @param enchantment object (OpenMW enchantment object)
-- @return number maxCharge
function spells.getEnchantmentMaxCharge(enchantment)
    if not enchantment then
        return 0
    end

    return enchantment.charge or 0
end

-- Get enchantment type
-- @param enchantment object (OpenMW enchantment object)
-- @return number? enchantmentType
function spells.getEnchantmentType(enchantment)
    if not enchantment then
        return nil
    end

    return enchantment.type
end

-- Check if enchantment is cast on use
-- @param enchantment object (OpenMW enchantment object)
-- @return boolean
function spells.isCastOnUse(enchantment)
    local enchantType = spells.getEnchantmentType(enchantment)
    return enchantType == core.magic.ENCHANTMENT_TYPE.WhenUsed
end

-- Check if enchantment is cast once
-- @param enchantment object (OpenMW enchantment object)
-- @return boolean
function spells.isCastOnce(enchantment)
    local enchantType = spells.getEnchantmentType(enchantment)
    return enchantType == core.magic.ENCHANTMENT_TYPE.CastOnce
end

-- Check if enchantment is constant effect
-- @param enchantment object (OpenMW enchantment object)
-- @return boolean
function spells.isConstantEffect(enchantment)
    local enchantType = spells.getEnchantmentType(enchantment)
    return enchantType == core.magic.ENCHANTMENT_TYPE.ConstantEffect
end

-- Check if enchantment shows charges
-- (only cast on use and cast once show charges)
-- @param enchantment object (OpenMW enchantment object)
-- @return boolean
function spells.showsCharges(enchantment)
    return spells.isCastOnUse(enchantment) or spells.isCastOnce(enchantment)
end

-- ============================================================================
-- SPELL SCHOOLS
-- ============================================================================

-- Get spell school
-- @param spell object (OpenMW spell object)
-- @return number? schoolId
function spells.getSpellSchool(spell)
    local effect = spells.getPrimaryEffect(spell)
    if not effect or not effect.effect then
        return nil
    end

    return effect.effect.school
end

-- Get spell school name
-- @param spell object (OpenMW spell object)
-- @return string? schoolName
function spells.getSpellSchoolName(spell)
    local schoolId = spells.getSpellSchool(spell)
    if not schoolId then
        return nil
    end

    local schoolRecord = core.stats.Skill.records[schoolId]
    if not schoolRecord then
        return nil
    end

    return schoolRecord.name
end

return spells
