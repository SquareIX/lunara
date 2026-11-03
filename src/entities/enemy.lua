-- src/entities/enemy.lua
-- One enemy instance. Its type (slime, bat, golem...) comes from Config.enemies.
-- To add a new enemy: add a sprite + an entry in config.lua. No code changes needed.

local Config = require("src.config")
local Assets = require("src.assets")
local Util = require("src.util")
local Particles = require("src.particles")
local Audio = require("src.audio")

local Enemy = {}
Enemy.__index = Enemy

function Enemy.new(typeName, x, y, hpScale)
    local def = Config.enemies[typeName]
    local self = setmetatable({}, Enemy)

    self.typeName = typeName
    self.sprite = def.sprite
    self.x, self.y = x, y
    self.radius = def.radius
    self.damage = def.damage
    self.xp = def.xp
    self.maxHp = def.hp * hpScale
    self.hp = self.maxHp
    self.speed = def.speed * (0.9 + love.math.random() * 0.2)  -- slight variety
    self.age = love.math.random() * 10   -- random start so enemies don't bounce in sync
    self.flashTimer = 0          -- > 0 while showing the "I got hit" tint
    self.lastOrbHit = -999       -- used by the orbit weapon's per-enemy cooldown
    self.burnTimer = 0           -- ember passive: seconds of burn remaining
    self.burnDps = 0             -- ember passive: burn damage per second
    self.burnTickAcc = 0
    self.facingLeft = false
    self.dead = false
    self.isBoss = def.boss == true

    return self
end

function Enemy:update(dt, world)
    local player = world.player
    local dx, dy = Util.normalize(player.x - self.x, player.y - self.y)
    self.x = self.x + dx * self.speed * dt
    self.y = self.y + dy * self.speed * dt
    if dx ~= 0 then self.facingLeft = dx < 0 end

    self.age = self.age + dt
    self.flashTimer = math.max(0, self.flashTimer - dt)

    -- Ember passive: burn damage over time.
    if self.burnTimer > 0 and not self.dead then
        self.burnTimer = self.burnTimer - dt
        self.burnTickAcc = self.burnTickAcc + dt
        local tick = Config.weapons.bolt.burnTick
        while self.burnTickAcc >= tick and not self.dead do
            self.burnTickAcc = self.burnTickAcc - tick
            local dmg = self.burnDps * tick
            self:takeDamage(dmg, world)
            if not self.dead then
                world:addDamageNumber(self, dmg, { 1, 0.5, 0.15 }, false)
                Particles.spawn(world.particles, self.x, self.y - self.radius, {
                    count = 1, colors = { { 1, 0.5, 0.15 }, { 1, 0.75, 0.2 } },
                    speed = { 12, 40 }, life = { 0.3, 0.55 }, size = { 1.5, 3 }, gravity = -60,
                })
            end
        end
    end

    -- Touching the player hurts (player has brief invulnerability, see player.lua).
    if Util.circlesOverlap(self.x, self.y, self.radius, player.x, player.y, player.radius) then
        -- Contact damage ramps with the run, so standing still becomes lethal.
        local enrage = 1 + math.min(1.25, world.time / 360)
        if player:takeDamage(self.damage * enrage) then
            -- A landed hit shakes the screen and knocks sparks off the player.
            world:addShake(5)
            world.hitstop = math.max(world.hitstop, 0.03)
            Particles.spawn(world.particles, player.x, player.y, {
                count = 8, colors = { { 1, 0.35, 0.35 } },
                speed = { 50, 150 }, life = { 0.25, 0.5 }, size = { 2, 3.5 },
            })
        end
    end
end

-- Ember passive: (re)apply a burn. Stronger burns win, duration refreshes.
function Enemy:applyBurn(dps, duration)
    if dps >= self.burnDps then self.burnDps = dps end
    self.burnTimer = math.max(self.burnTimer, duration)
end

function Enemy:takeDamage(amount, world)
    if self.dead then return end
    if world.player.stats.executioner and self.hp <= self.maxHp * 0.5 then
        amount = amount * 1.25
    end
    self.hp = self.hp - amount
    self.flashTimer = 0.08
    
    if self.hp <= 0 then
        self.dead = true
        world.kills = world.kills + 1
        world:spawnGem(self.x, self.y, self.xp)
        -- Death juice: a burst in the enemy's own colours + a sound.
        local color = (Config.sprites[self.sprite] or {}).color or { 1, 1, 1 }
        Particles.burst(world.particles, self.x, self.y, color, self.isBoss and 42 or 14)
        Audio.play("die")
        if self.isBoss then
            world:addShake(12)
            world.hitstop = math.max(world.hitstop, 0.09)
        end
    end
end

function Enemy:draw()
    if self.flashTimer > 0 then
        love.graphics.setColor(1, 0.6, 0.6)
    elseif self.burnTimer > 0 then
        love.graphics.setColor(1, 0.72, 0.45)   -- burning tint
    else
        love.graphics.setColor(1, 1, 1)
    end
    local squash = math.sin(self.age * (self.isBoss and 4 or 9)) * (self.isBoss and 0.03 or 0.07)
    if Assets.animations[self.sprite] then
        -- Animated sheet (walk / flap / float cycle), if one was added.
        local def = Assets.animations[self.sprite].def
        local frame = math.floor(self.age * def.fps) % def.frames + 1
        Assets.drawAnimated(self.sprite, self.x, self.y, frame, 0, self.facingLeft, squash)
    else
        Assets.draw(self.sprite, self.x, self.y, 0, self.facingLeft, squash)
    end

    if self.isBoss then
        love.graphics.setColor(1, 0.2, 0.35, 0.95)
        love.graphics.rectangle("fill", self.x - 90, self.y - self.radius - 24, 180, 9, 3, 3)
        love.graphics.setColor(1, 0.85, 0.2)
        love.graphics.rectangle("fill", self.x - 90, self.y - self.radius - 24, 180 * math.max(0, self.hp / self.maxHp), 9, 3, 3)
        love.graphics.setColor(1, 0.8, 0.25)
        love.graphics.printf("BOSS", self.x - 90, self.y - self.radius - 46, 180, "center")
    elseif self.hp < self.maxHp then
        local width, height = math.max(28, self.radius * 2.4), 5
        love.graphics.setColor(0, 0, 0, 0.75)
        love.graphics.rectangle("fill", self.x - width / 2, self.y - self.radius - 12, width, height, 2, 2)
        love.graphics.setColor(0.35, 0.95, 0.45)
        love.graphics.rectangle("fill", self.x - width / 2, self.y - self.radius - 12, width * math.max(0, self.hp / self.maxHp), height, 2, 2)
    end

    if Config.debug then
        love.graphics.setColor(1, 0, 0, 0.8)
        love.graphics.circle("line", self.x, self.y, self.radius)
    end
end

return Enemy
