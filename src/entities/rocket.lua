local Config = require("src.config")
local Assets = require("src.assets")
local Util = require("src.util")

local Rocket = {}
Rocket.__index = Rocket

function Rocket.new(x, y, angle, damage)
    local cfg = Config.weapons.rocket
    return setmetatable({
        x=x, y=y, angle=angle, damage=damage,
        vx=math.cos(angle) * cfg.speed, vy=math.sin(angle) * cfg.speed,
        radius=cfg.radius, life=cfg.lifetime, dead=false,
    }, Rocket)
end

function Rocket:update(dt, world)
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
    self.life = self.life - dt
    if self.life <= 0 then self.dead = true return end
    for _, enemy in ipairs(world.enemies) do
        if not enemy.dead and Util.circlesOverlap(self.x, self.y, self.radius, enemy.x, enemy.y, enemy.radius) then
            local radius = Config.weapons.rocket.explosionRadius
            for _, victim in ipairs(world.enemies) do
                if not victim.dead and Util.distance(self.x, self.y, victim.x, victim.y) <= radius then
                    local critical = love.math.random() < world.player.stats.critChance
                    local damage = self.damage * (critical and world.player.stats.critMult or 1)
                    victim:takeDamage(damage, world)
                    world:addFloatingText(victim.x, victim.y - victim.radius - 8, math.floor(damage + 0.5), critical and {1, 0.85, 0.25} or {1, 0.55, 0.25}, critical)
                end
            end
            self.dead = true
            return
        end
    end
end

function Rocket:draw()
    love.graphics.setColor(1, 1, 1)
    Assets.draw("rocket", self.x, self.y, self.angle)
end

return Rocket
