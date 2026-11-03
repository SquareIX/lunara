-- src/entities/player.lua
-- The player: movement, health, XP / levels and the stats that upgrades change.

local Config = require("src.config")
local Assets = require("src.assets")
local Input = require("src.input")

local Player = {}
Player.__index = Player

function Player.new(characterId)
    local cfg = Config.player
    local char = Config.characterById(characterId)
    local self = setmetatable({}, Player)

    self.charId = char.id
    self.spriteKey = char.sprite       -- static sprite + shadow
    self.walkAnim = char.walkAnim      -- animation keys (Sheets may be absent)
    self.attackAnim = char.attackAnim
    self.x, self.y = 0, 0
    self.radius = cfg.radius
    self.facingLeft = false
    self.invulnTimer = 0
    self.attackTimer = 0      -- > 0 while a sword swing animation plays
    self.attackDuration = 0
    self.age = 0
    self.moving = false

    self.level = 1
    self.xp = 0
    self.xpToNext = Config.xp.first
    self.pendingLevelUps = 0      -- main.lua opens the upgrade screen while > 0

    -- Everything upgrades are allowed to modify lives in `stats`.
    -- Weapons read these every frame (see src/weapons.lua).
    self.stats = {
        maxHp        = cfg.maxHp,
        moveSpeed    = cfg.moveSpeed,
        pickupRange  = cfg.pickupRange,
        damageMult   = 1.0,   -- multiplies all weapon damage
        cooldownMult = 1.0,   -- multiplies weapon cooldowns (lower = faster)
        boltCount    = 1,     -- projectiles per shot
        orbCount     = 0,     -- orbiting orbs (0 = weapon not unlocked yet)
        rocketCount  = 0,
        pulseCount   = 0,
        lightningCount = 0,
        swordCount   = 0,     -- sword swings (0 = weapon not unlocked yet)
        swordDamageMult = 1.0, -- sword-only damage multiplier (Sharpened Edge)
        boltChain    = 0,     -- ricochet passive: extra enemies a bolt bounces to
        boltBurn     = 0,     -- ember passive: burn damage per second from bolts
        critChance   = 0,
        critMult     = 2.0,
        regen        = cfg.regen,
        armor        = cfg.armor,
        rerolls      = 3,
        executioner  = false,
    }
    self.upgradeCounts = {}   -- upgrade id -> times taken
    self.equipment = {}       -- slot -> item (see src/equipment.lua)

    -- Character identity: stat multipliers, bonus armour, starting weapons.
    self.stats.maxHp = math.max(1, math.floor(self.stats.maxHp * char.hpMult))
    self.stats.moveSpeed = self.stats.moveSpeed * char.speedMult
    self.stats.damageMult = self.stats.damageMult * char.damageMult
    self.stats.armor = self.stats.armor + char.armorBonus
    for key, value in pairs(char.startStats) do self.stats[key] = value end
    self.hp = self.stats.maxHp

    return self
end

----------------------------------------------------------------------
-- Equipment (items found during the run, see src/equipment.lua)
----------------------------------------------------------------------
local function applyMods(player, item, direction)
    for _, mod in ipairs(item.mods) do
        if mod.kind == "add" then
            player.stats[mod.stat] = player.stats[mod.stat] + mod.value * direction
        elseif direction > 0 then
            player.stats[mod.stat] = player.stats[mod.stat] * mod.value
        else
            player.stats[mod.stat] = player.stats[mod.stat] / mod.value
        end
    end
    if player.stats.maxHp < 1 then player.stats.maxHp = 1 end
    if player.hp > player.stats.maxHp then player.hp = player.stats.maxHp end
end

-- Equip an item. Returns "equipped" or "scrapped" (a weaker item for an
-- occupied slot turns into XP instead).
function Player:equip(item)
    local current = self.equipment[item.slot]
    if current and current.power >= item.power then
        self:addXp(Config.drops.scrapXp)
        return "scrapped"
    end
    if current then applyMods(self, current, -1) end
    applyMods(self, item, 1)
    if item.slot == "chest" then self:heal(20) end  -- a little top-up with new armour
    self.equipment[item.slot] = item
    return "equipped"
end

function Player:update(dt, world)
    local dx, dy = Input.getMoveVector()
    self.x = self.x + dx * self.stats.moveSpeed * dt
    self.y = self.y + dy * self.stats.moveSpeed * dt
    if dx ~= 0 then self.facingLeft = dx < 0 end
    self.moving = dx ~= 0 or dy ~= 0

    self.age = self.age + dt
    self.invulnTimer = math.max(0, self.invulnTimer - dt)
    self.attackTimer = math.max(0, self.attackTimer - dt)
    if self.stats.regen > 0 and self.hp > 0 then
        self.hp = math.min(self.stats.maxHp, self.hp + self.stats.regen * dt)
    end
end

-- Returns true when the hit actually landed (false while invulnerable),
-- so callers can trigger shake / particles / hitstop only on real hits.
function Player:takeDamage(amount)
    if self.invulnTimer > 0 then return false end
    self.hp = self.hp - math.max(1, amount - self.stats.armor)
    self.invulnTimer = Config.player.invulnTime
    return true
end

function Player:heal(amount)
    self.hp = math.min(self.stats.maxHp, self.hp + amount)
end

function Player:isDead()
    return self.hp <= 0
end

function Player:addXp(amount)
    self.xp = self.xp + amount
    while self.xp >= self.xpToNext do
        self.xp = self.xp - self.xpToNext
        self.level = self.level + 1
        self.pendingLevelUps = self.pendingLevelUps + 1
        self.xpToNext = math.ceil(Config.xp.first * Config.xp.growth ^ (self.level - 1))
    end
end

function Player:draw()
    -- Blink while invulnerable.
    local blink = self.invulnTimer > 0 and math.floor(self.invulnTimer * 20) % 2 == 0
    love.graphics.setColor(1, 1, 1, blink and 0.4 or 1)

    -- Quick bounce while running, slow breathing while standing still.
    local squash = self.moving and math.sin(self.age * 16) * 0.06 or math.sin(self.age * 3) * 0.02
    if self.attackTimer > 0 and Assets.animations[self.attackAnim] then
        -- Sword swing in progress: play the attack sheet instead of walking.
        local progress = 1 - self.attackTimer / math.max(self.attackDuration, 0.01)
        local attackFrame = math.min(4, math.floor(progress * 4) + 1)
        Assets.drawAnimated(self.attackAnim, self.x, self.y, attackFrame, 0, self.facingLeft, squash)
    elseif Assets.animations[self.walkAnim] then
        local frame = self.moving and (math.floor(self.age * 8) % 4) + 1 or (math.floor(self.age * 2) % 2) + 1
        Assets.drawAnimated(self.walkAnim, self.x, self.y, frame, 0, self.facingLeft, squash)
    else
        Assets.draw(self.spriteKey, self.x, self.y, 0, self.facingLeft, squash)
    end

    if Config.debug then
        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.circle("line", self.x, self.y, self.radius)
        love.graphics.setColor(0, 1, 0, 0.3)
        love.graphics.circle("line", self.x, self.y, self.stats.pickupRange)
    end
end

return Player
