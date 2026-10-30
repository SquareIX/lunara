-- src/entities/projectile.lua
-- A bolt flying in a straight line. Dies on its first hit or when its lifetime ends.

local Config = require("src.config")
local Assets = require("src.assets")
local Util = require("src.util")

local Projectile = {}
Projectile.__index = Projectile

function Projectile.new(x, y, angle, damage, sx, sy)
    local cfg = Config.weapons.bolt
    return setmetatable({
        x = x, y = y, 
        sx = sx, sy = sy,
        vx = math.cos(angle) * cfg.speed,
        vy = math.sin(angle) * cfg.speed,
        angle = angle,
        damage = damage,
        radius = cfg.radius,
        life = cfg.lifetime,
        dead = false,
    }, Projectile)
end

function Projectile:update(dt, world)
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
    self.life = self.life - dt
    if self.life <= 0 then self.dead = true return end
  

    for _, enemy in ipairs(world.enemies) do
        if not enemy.dead and Util.circlesOverlap(self.x, self.y, self.radius, enemy.x, enemy.y, enemy.radius) then
            local critical = love.math.random() < world.player.stats.critChance
            local damage = self.damage * (critical and world.player.stats.critMult or 1)
            enemy:takeDamage(damage, world)
            world:addFloatingText(enemy.x, enemy.y - enemy.radius - 8, math.floor(damage + 0.5), critical and {1, 0.85, 0.25} or {1, 1, 1}, critical)
            self.dead = true
            return
        end
    end
end

function Projectile:draw()
    love.graphics.setColor(1, 1, 1)
    
    Assets.draw("bolt", self.x, self.y, self.angle)
    if Config.debug then
        love.graphics.setColor(1, 1, 0, 0.8)
        love.graphics.circle("line", self.x, self.y, self.radius)
    end
end

return Projectile
