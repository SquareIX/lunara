-- src/entities/slash_wave.lua
-- The ranged part of the sword: a crescent wave launched by every swing.
-- Flies straight, pierces through enemies, and dies after travelling
-- Config.weapons.sword.waveRange units. Each enemy is hit at most once.

local Config = require("src.config")
local Assets = require("src.assets")
local Util = require("src.util")
local Particles = require("src.particles")

local SlashWave = {}
SlashWave.__index = SlashWave

function SlashWave.new(x, y, angle, damage)
    local cfg = Config.weapons.sword
    return setmetatable({
        x = x, y = y, angle = angle, damage = damage,
        vx = math.cos(angle) * cfg.waveSpeed,
        vy = math.sin(angle) * cfg.waveSpeed,
        radius = cfg.waveRadius,
        travelled = 0,
        age = 0,
        hit = {},          -- enemies already struck by this wave
        dead = false,
    }, SlashWave)
end

function SlashWave:update(dt, world)
    local cfg = Config.weapons.sword
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
    self.age = self.age + dt
    self.travelled = self.travelled + cfg.waveSpeed * dt
    if self.travelled >= cfg.waveRange then self.dead = true return end

    for _, enemy in ipairs(world.enemies) do
        if not enemy.dead and not self.hit[enemy]
           and Util.circlesOverlap(self.x, self.y, self.radius, enemy.x, enemy.y, enemy.radius) then
            self.hit[enemy] = true
            local critical = love.math.random() < world.player.stats.critChance
            local damage = self.damage * (critical and world.player.stats.critMult or 1)
            enemy:takeDamage(damage, world)
            enemy:knockback(self.x - self.vx * 0.05, self.y - self.vy * 0.05, enemy.isBoss and 25 or 150)
            world:addDamageNumber(enemy, damage, critical and { 1, 0.85, 0.25 } or { 0.65, 0.95, 1 }, critical)
            Particles.spawn(world.particles, enemy.x, enemy.y, {
                count = 4, colors = { { 0.65, 0.95, 1 } },
                speed = { 30, 110 }, life = { 0.2, 0.45 }, size = { 1.5, 3 },
            })
        end
    end
end

function SlashWave:draw()
    love.graphics.setColor(1, 1, 1)
    if Assets.animations.slash then
        -- Cycle the slash frames while the wave flies.
        local def = Assets.animations.slash.def
        local frame = math.floor(self.age * def.fps) % def.frames + 1
        Assets.drawAnimated("slash", self.x, self.y, frame, self.angle, false, 0)
    else
        -- Fallback until slash_sheet.png is added: a spinning sword.
        Assets.draw("sword", self.x, self.y, self.angle + self.age * 12)
    end
end

return SlashWave
