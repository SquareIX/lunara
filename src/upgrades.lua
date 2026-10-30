-- src/upgrades.lua
-- The choices offered on level-up. Each entry:
--     id, name, desc   -- shown on the card
--     max              -- (optional) how many times it can be taken
--     apply(player)    -- what it does
-- To add an upgrade, just add another entry to the `list` below.

local Util = require("src.util")
local Config = require("src.config")

local Upgrades = {}

Upgrades.list = {
    {
        id = "bolt_count", name = "Multi Bolt", desc = "+1 bolt per shot", max = 20,
        apply = function(p) p.stats.boltCount = p.stats.boltCount + 1 end,
    },
    {
        id = "fire_rate", name = "Quick Cast", desc = "Weapons fire 15% faster", max = 10,
        apply = function(p) p.stats.cooldownMult = p.stats.cooldownMult * 0.8 end,
    },
    {
        id = "damage", name = "Power Up", desc = "x1.5% weapon damage",
        apply = function(p) p.stats.damageMult = p.stats.damageMult * 1.5 end,
    },
    {
        id = "rocket", name = "Auto Rocket", desc = "+1 homing rocket with area damage", max = 5,
        apply = function(p) p.stats.rocketCount = p.stats.rocketCount + 1 end,
    },
    {
        id = "orbit", name = "Orbiting Orbs", desc = "+1 orb circles you", max = 12,
        apply = function(p) p.stats.orbCount = p.stats.orbCount + 1 end,
    },
    {
        id = "speed", name = "Swift Feet", desc = "+10% move speed", max = 5,
        apply = function(p) p.stats.moveSpeed = p.stats.moveSpeed * 1.10 end,
    },
    {
        id = "max_hp", name = "Vitality", desc = "+25 max HP and heal 25",
        apply = function(p)
            p.stats.maxHp = p.stats.maxHp + 25
            p:heal(25)
        end,
    },
    {
        id = "magnet", name = "Magnet", desc = "+40% pickup range", max = 5,
        apply = function(p) p.stats.pickupRange = p.stats.pickupRange * 1.4 end,
    },
    {
        id = "heal", name = "Recovery", desc = "Heal 40 HP",
        apply = function(p) p:heal(40) end,
    },
    { id = "crit", name = "Lucky Strike", desc = "+8% chance to deal double damage", max = 8, apply = function(p) p.stats.critChance = math.min(0.64, p.stats.critChance + 0.08) end },
    { id = "armor", name = "Iron Skin", desc = "Take 2 less damage from hits", max = 8, apply = function(p) p.stats.armor = p.stats.armor + 2 end },
    { id = "regen", name = "Regeneration", desc = "Recover 0.6 HP every second", max = 5, apply = function(p) p.stats.regen = p.stats.regen + 0.6 end },
}

local function isAvailable(upgrade, player)
    local taken = player.upgradeCounts[upgrade.id] or 0
    return upgrade.max == nil or taken < upgrade.max
end

-- Returns up to `count` random upgrades the player can still take.
function Upgrades.roll(player, count)
    local pool = {}
    for _, upgrade in ipairs(Upgrades.list) do
        if isAvailable(upgrade, player) then pool[#pool + 1] = upgrade end
    end
    Util.shuffle(pool)
    local choices = {}
    for i = 1, math.min(count or Config.upgradeChoiceCount, #pool) do
        choices[i] = pool[i]
    end
    return choices
end

function Upgrades.apply(upgrade, player)
    upgrade.apply(player)
    player.upgradeCounts[upgrade.id] = (player.upgradeCounts[upgrade.id] or 0) + 1
end

return Upgrades
