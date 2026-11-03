-- src/entities/gem.lua
-- XP gem dropped by enemies. Flies towards the player once inside pickup range.

local Assets = require("src.assets")
local Util = require("src.util")
local Particles = require("src.particles")
local Audio = require("src.audio")

local Gem = {}
Gem.__index = Gem

local FLY_SPEED = 380
local COLLECT_DISTANCE = 12

function Gem.new(x, y, value)
    return setmetatable({ x = x, y = y, value = value, attracted = false, dead = false }, Gem)
end

function Gem:update(dt, world)
    local player = world.player
    local dist = Util.distance(self.x, self.y, player.x, player.y)

    if dist <= player.stats.pickupRange then self.attracted = true end

    if self.attracted then
        local dx, dy = Util.normalize(player.x - self.x, player.y - self.y)
        self.x = self.x + dx * FLY_SPEED * dt
        self.y = self.y + dy * FLY_SPEED * dt
    end

    if dist <= COLLECT_DISTANCE then
        player:addXp(self.value)
        Particles.spawn(world.particles, self.x, self.y, {
            count = 4, colors = { { 0.35, 1, 0.65 } },
            speed = { 25, 80 }, life = { 0.2, 0.4 }, size = { 1.5, 2.5 },
        })
        Audio.play("pickup")
        self.dead = true
    end
end

function Gem:draw()
    love.graphics.setColor(1, 1, 1)
    Assets.draw("gem", self.x, self.y)
end

return Gem
