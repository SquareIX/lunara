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
    id = "bolt_count",
    name = "Bullet Multiplier",
    desc = "x1.2 bolt per shot, you need 5 of this to get 2 bullet, not good im early",
    max = 20,
    apply = function(p) p.stats.boltCount = p.stats.boltCount * 1.2 end,
  },
  {
    id = "fire_rate",
    name = "Quick Cast",
    desc = "Weapons fire x0.8 faster, decent picked",
    max = 10,
    apply = function(p) p.stats.cooldownMult = p.stats.cooldownMult * 0.8 end,
  },
  {
    id = "damage",
    name = "Power Up",
    desc = "x1.1 more damage",
    apply = function(p) p.stats.damageMult = p.stats.damageMult * 1.1 end,
  },
  {
    id = "rocket",
    name = "Auto Rocket",
    desc = "+1 ICBM 🗿 straight to enemies faces",
    max = 5,
    apply = function(p) p.stats.rocketCount = p.stats.rocketCount + 1 end,
  },
  {
    id = "orbit",
    name = "Orbiting Orbs",
    desc = "+1 orb guarding you like a president",
    max = 12,
    apply = function(p) p.stats.orbCount = p.stats.orbCount + 1 end,
  },
  {
    id = "speed",
    name = "Swift Feet",
    desc = "+10% move speed, not good i swear!",
    max = 5,
    apply = function(p) p.stats.moveSpeed = p.stats.moveSpeed * 1.10 end,
  },
  {
    id = "max_hp",
    name = "Vitality",
    desc = "+25 max HP and heal 25",
    apply = function(p)
      p.stats.maxHp = p.stats.maxHp + 25
      p:heal(25)
    end,
  },
  {
    id = "magnet",
    name = "Magnet",
    desc = "+40% pickup range, not necessary but hey, your choice",
    max = 5,
    apply = function(p) p.stats.pickupRange = p.stats.pickupRange * 1.4 end,
  },
  {
    id = "heal",
    name = "Recovery",
    desc = "Heal 40 HP, pick this if you dying",
    apply = function(p) p:heal(40) end,
  },
  {
    id = "crit",
    name = "Crit Rate",
    desc = "+8% chance to crot eh I meant crit",
    max = 8,
    apply = function(
        p)
      p.stats.critChance = math.min(0.64, p.stats.critChance + 0.08)
    end
  },
  {
    id = "armor",
    name = "Iron Man 🗿",
    desc = "Take 2 less damage from hits",
    max = 8,
    apply = function(
        p)
      p.stats.armor = p.stats.armor + 2
    end
  },
  {
    id = "regen",
    name = "Regeneration",
    desc = "Recover 0.6 HP every second",
    max = 5,
    apply = function(
        p)
      p.stats.regen = p.stats.regen + 0.6
    end
  },
  {
    id = "pulse",
    name = "Shockwave",
    desc = "Now you have aura circling you, you can now aura farming 😎",
    max = 1,
    apply = function(
        p)
      p.stats.pulseCount = p.stats.pulseCount + 1
    end
  },
  {
    id = "lightning",
    name = "Chain Lightning",
    desc = "Hit 'em with your tesla coil 🗿⚡",
    max = 1,
    apply = function(
        p)
      p.stats.lightningCount = p.stats.lightningCount + 1
    end
  },
  {
    id = "sword",
    name = "Moonlight Sword",
    desc = "Unlock the sword: auto-slashes the nearest enemy in an arc 🗡️",
    max = 1,
    apply = function(p) p.stats.swordCount = p.stats.swordCount + 1 end,
  },
  {
    id = "bolt_chain",
    name = "Ricochet Bolts",
    desc = "Your main bolts bounce to up to 3 close enemies ⚡",
    max = 1,
    apply = function(p) p.stats.boltChain = 3 end,
  },
  {
    id = "bolt_burn",
    name = "Ember Bolts",
    desc = "Your bolts set enemies on fire: +12 burn damage/s 🔥",
    max = 3,
    apply = function(p) p.stats.boltBurn = p.stats.boltBurn + 12 end,
  },
  {
    id = "sword_damage",
    name = "Sharpened Edge",
    desc = "+35% sword damage, waves included 🗡️",
    max = 4,
    apply = function(p) p.stats.swordDamageMult = p.stats.swordDamageMult * 1.35 end,
  },
  {
    id = "overcharge",
    name = "Overcharge",
    desc = "+35% damage, but skills fire 8% slower. it's your choices",
    max = 4,
    apply = function(
        p)
      p.stats.damageMult = p.stats.damageMult * 1.35; p.stats.cooldownMult = p.stats.cooldownMult * 1.08
    end
  },
  {
    id = "haste",
    name = "Haste",
    desc = "All skills fire 18% faster, OP imo",
    max = 6,
    apply = function(
        p)
      p.stats.cooldownMult = p.stats.cooldownMult * 0.82
    end
  },
  {
    id = "fortress",
    name = "Fortress",
    desc = "+20 max HP and +3 armor, tank build for sure",
    max = 6,
    apply = function(
        p)
      p.stats.maxHp = p.stats.maxHp + 20; p.stats.armor = p.stats.armor + 3; p:heal(20)
    end
  },
  {
    id = "executioner",
    name = "Executioner",
    desc = "+25% damage to enemies below half HP, it's kinda op imo",
    max = 1,
    apply = function(
        p)
      p.stats.executioner = true
    end
  },
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
