local core = require("openmw.core")
local self = require("openmw.self")
local types = require("openmw.types")

local utility = require("scripts.voshondsquickselect.legacy.utility")

local Catalog = {}

local function normalized(value)
    return string.lower(tostring(value or ""))
end

local function recordFor(item)
    if not item or not item.type or not item.recordId then
        return nil
    end
    return item.type.records[item.recordId]
end

local function entrySort(a, b)
    local aName = normalized(a.name)
    local bName = normalized(b.name)
    if aName == bName then
        return normalized(a.id) < normalized(b.id)
    end
    return aName < bName
end

function Catalog.inventory()
    local result = {}

    for _, item in ipairs(types.Actor.inventory(self):getAll()) do
        local record = recordFor(item)
        if record then
            table.insert(result, {
                kind = "item",
                id = item.recordId,
                name = record.name or item.recordId,
                icon = record.icon,
                count = item.count or 1,
                enchanted = record.enchant ~= nil and record.enchant ~= "",
                item = item,
                searchText = normalized((record.name or "") .. " " .. item.recordId),
            })
        end
    end

    table.sort(result, entrySort)
    return result
end

local function spellIcon(spell)
    local effect = spell and spell.effects and spell.effects[1]
    local icon = effect and effect.effect and effect.effect.icon
    return utility.getSpellEffectBigIconPath(icon)
end

local function effectSearchTerms(effects)
    local terms = {}
    for _, effect in ipairs(effects or {}) do
        local effectRecord = effect.effect or effect
        table.insert(terms, effectRecord.name or "")
        table.insert(terms, effectRecord.id or "")
        table.insert(terms, effectRecord.school or "")
    end
    return table.concat(terms, " ")
end

function Catalog.magic()
    local result = {}

    for _, spell in ipairs(types.Actor.spells(self)) do
        if spell.type == core.magic.SPELL_TYPE.Power or spell.type == core.magic.SPELL_TYPE.Spell then
            table.insert(result, {
                kind = "spell",
                category = "Spells",
                id = spell.id,
                name = spell.name or spell.id,
                icon = spellIcon(spell),
                spell = spell,
                searchText = normalized((spell.name or "") .. " " .. spell.id .. " spell " .. effectSearchTerms(spell.effects)),
            })
        end
    end

    for _, item in ipairs(types.Actor.inventory(self):getAll()) do
        local record = recordFor(item)
        local enchantment = utility.FindEnchantment(item)
        if record and enchantment and (
                enchantment.type == core.magic.ENCHANTMENT_TYPE.CastOnUse or
                enchantment.type == core.magic.ENCHANTMENT_TYPE.CastOnce
            ) then
            table.insert(result, {
                kind = "enchantment",
                category = "Enchantments",
                id = item.recordId,
                name = record.name or item.recordId,
                icon = spellIcon(enchantment),
                enchantmentId = record.enchant,
                item = item,
                searchText = normalized((record.name or "") .. " " .. item.recordId .. " enchantment " .. effectSearchTerms(enchantment.effects)),
            })
        end
    end

    local categoryOrder = {
        Spells = 1,
        Enchantments = 2,
    }
    table.sort(result, function(a, b)
        if a.category ~= b.category then
            return categoryOrder[a.category] < categoryOrder[b.category]
        end
        return entrySort(a, b)
    end)

    return result
end

function Catalog.filter(entries, query)
    local needle = normalized(query)
    if needle == "" then
        return entries
    end

    local result = {}
    for _, entry in ipairs(entries or {}) do
        if string.find(entry.searchText or normalized(entry.name), needle, 1, true) then
            table.insert(result, entry)
        end
    end
    return result
end

function Catalog.normalized(value)
    return normalized(value)
end

function Catalog.magicIcon(record)
    return spellIcon(record)
end

return Catalog
