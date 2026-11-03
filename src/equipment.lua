-- src/equipment.lua
-- Loot: enemies sometimes drop equipment for one of four slots.
-- Items have a rarity (common / rare / epic) and a list of stat mods:
--     { stat = "armor", kind = "add", value = 2 }
--     { stat = "damageMult", kind = "mult", value = 1.07 }
-- player.lua applies / un-applies the mods when an item is equipped.
-- A weaker drop for an occupied slot is scrapped into XP automatically.

local Equipment = {}

Equipment.slots = { "helmet", "chest", "boots", "amulet" }

Equipment.rarities = {
    { id = "common", name = "Common", scale = 1.0, color = { 0.75, 0.8, 0.9 } },
    { id = "rare",   name = "Rare",   scale = 1.9, color = { 0.4, 0.7, 1.0 } },
    { id = "epic",   name = "Epic",   scale = 3.2, color = { 0.85, 0.55, 1.0 } },
}

-- Base mod templates per slot (scaled by rarity).
local TEMPLATES = {
    helmet = { name = "Helm", mods = {
        { stat = "armor", kind = "add", value = 1, fmt = "+%d Armor" },
        { stat = "critChance", kind = "add", value = 0.03, fmt = "+%d%% Crit", pct = true },
    } },
    chest = { name = "Chestplate", mods = {
        { stat = "maxHp", kind = "add", value = 20, fmt = "+%d Max HP" },
        { stat = "armor", kind = "add", value = 1, fmt = "+%d Armor" },
    } },
    boots = { name = "Boots", mods = {
        { stat = "moveSpeed", kind = "mult", value = 1.06, fmt = "+%d%% Move speed", pct = true },
        { stat = "pickupRange", kind = "mult", value = 1.15, fmt = "+%d%% Pickup range", pct = true },
    } },
    amulet = { name = "Amulet", mods = {
        { stat = "damageMult", kind = "mult", value = 1.07, fmt = "+%d%% Damage", pct = true },
        { stat = "cooldownMult", kind = "mult", value = 0.96, fmt = "%d%% Cooldowns", pct = true, invert = true },
    } },
}

local function scaleMod(template, scale)
    local value
    if template.kind == "add" then
        if template.pct then
            value = template.value * scale
        else
            value = math.max(1, math.floor(template.value * scale + 0.5))
        end
    elseif template.value >= 1 then
        value = 1 + (template.value - 1) * scale
    else
        value = 1 - (1 - template.value) * scale
    end
    local text
    if template.pct then
        local pct = template.kind == "add" and math.floor(value * 100 + 0.5)
            or math.floor(math.abs(value - 1) * 100 + 0.5)
        text = string.format(template.fmt, template.invert and -pct or pct)
    else
        text = string.format(template.fmt, value)
    end
    return { stat = template.stat, kind = template.kind, value = value, text = text }
end

local PREFIX = {
    common = { "Worn", "Sturdy", "Plain" },
    rare = { "Moonsteel", "Runed", "Gleaming" },
    epic = { "Lunara's", "Starforged", "Eclipse" },
}

-- quality: nil = normal drop table, "boss" = only rare/epic.
function Equipment.rollDrop(quality)
    local slot = Equipment.slots[love.math.random(#Equipment.slots)]
    local roll = love.math.random()
    local rarity
    if quality == "boss" then
        rarity = roll < 0.45 and Equipment.rarities[3] or Equipment.rarities[2]
    elseif roll < 0.10 then
        rarity = Equipment.rarities[3]
    elseif roll < 0.38 then
        rarity = Equipment.rarities[2]
    else
        rarity = Equipment.rarities[1]
    end
    local template = TEMPLATES[slot]
    local mods, power = {}, 0
    for i, t in ipairs(template.mods) do
        mods[i] = scaleMod(t, rarity.scale)
        power = power + rarity.scale * i  -- rough strength score for comparisons
    end
    local prefix = PREFIX[rarity.id][love.math.random(#PREFIX[rarity.id])]
    local texts = {}
    for i, m in ipairs(mods) do texts[i] = m.text end
    return {
        slot = slot, rarity = rarity.id, rarityName = rarity.name,
        color = rarity.color, name = prefix .. " " .. template.name,
        mods = mods, power = power, desc = table.concat(texts, ", "),
    }
end

return Equipment
