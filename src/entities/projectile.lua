-- src/entities/projectile.lua
-- A bolt flying in a straight line. Dies on its first hit or when its lifetime ends.

local Config = require("src.config")
local Assets = require("src.assets")
local Util = require("src.util")
local Particles = require("src.particles")
local Audio = require("src.audio")

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
            local stats = world.player.stats
            local critical = love.math.random() < stats.critChance
            local damage = self.damage * (critical and stats.critMult or 1)
            enemy:takeDamage(damage, world)
            if enemy.knockback then enemy:knockback(self.x, self.y, enemy.isBoss and 10 or 55) end
            world:addDamageNumber(enemy, damage, critical and {1, 0.85, 0.25} or {1, 1, 1}, critical)
            if stats.boltBurn > 0 then
                enemy:applyBurn(stats.boltBurn, Config.weapons.bolt.burnDuration)
            end
            -- Ricochet passive: bounce to the nearest other enemies, one by one.
            if stats.boltChain > 0 then
                local alreadyHit = { [enemy] = true }
                local fromX, fromY = enemy.x, enemy.y
                local bounced = false
                for _ = 1, stats.boltChain do
                    local target, bestDist = nil, Config.weapons.bolt.chainRange
                    for _, other in ipairs(world.enemies) do
                        if not other.dead and not alreadyHit[other] then
                            local d = Util.distance(fromX, fromY, other.x, other.y)
                            if d < bestDist then target, bestDist = other, d end
                        end
                    end
                    if not target then break end
                    bounced = true
                    alreadyHit[target] = true
                    local cCrit = love.math.random() < stats.critChance
                    local cDamage = self.damage * (cCrit and stats.critMult or 1)
                    target:takeDamage(cDamage, world)
                    world:addDamageNumber(target, cDamage, cCrit and {1, 0.85, 0.25} or {0.85, 0.65, 1}, cCrit)
                    if stats.boltBurn > 0 then
                        target:applyBurn(stats.boltBurn, Config.weapons.bolt.burnDuration)
                    end
                    Particles.spawn(world.particles, target.x, target.y, {
                        count = 3, colors = { { 0.85, 0.65, 1 } },
                        speed = { 30, 100 }, life = { 0.2, 0.4 }, size = { 1.5, 3 },
                    })
                    fromX, fromY = target.x, target.y
                end
                if bounced then Audio.play("lightning") end
            end
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
