-- src/weapons.lua
-- The player's automatic weapons. Each weapon has:
--     update(world, dt)   -- fire / hit things
--     draw(world)         -- optional extra drawing
-- Numbers come from Config.weapons and the player's upgraded stats.
--
-- To add a weapon: write a table like `bolt` below, add it to `Weapons.list`,
-- add its numbers to config.lua and an upgrade to upgrades.lua.

local Config = require("src.config")
local Assets = require("src.assets")
local Util = require("src.util")
local Projectile = require("src.entities.projectile")
local Rocket = require("src.entities.rocket")
local Audio = require("src.audio")

local Weapons = {}

----------------------------------------------------------------------
-- ROCKET: auto-aimed explosive projectile
local rocket = { timer = 0 }
function rocket.reset() rocket.timer = 0 end
function rocket.update(world, dt)
    local cfg, player = Config.weapons.rocket, world.player
    if player.stats.rocketCount <= 0 then return end
    rocket.timer = rocket.timer - dt
    if rocket.timer > 0 then return end
    local target, bestDist = nil, cfg.targetRange
    for _, enemy in ipairs(world.enemies) do
        local distance = Util.distance(player.x, player.y, enemy.x, enemy.y)
        if not enemy.dead and distance < bestDist then target, bestDist = enemy, distance end
    end
    if not target then return end
    rocket.timer = cfg.cooldown * player.stats.cooldownMult
    Audio.play("rocket")
    local angle = math.atan2(target.y - player.y, target.x - player.x)
    world:addProjectile(Rocket.new(player.x, player.y, angle, cfg.damage * player.stats.damageMult))
end

-- BOLT: shoots at the nearest enemy
----------------------------------------------------------------------
local bolt = { timer = 0 }

local function findNearestEnemy(world, range)
    local player = world.player
    local best, bestDist = nil, range
    for _, enemy in ipairs(world.enemies) do
        local d = Util.distance(player.x, player.y, enemy.x, enemy.y)
        if not enemy.dead and d < bestDist then
            best, bestDist = enemy, d
        end
    end
    return best
end

function bolt.reset()
    bolt.timer = 0
end

function bolt.update(world, dt)
    local cfg, player = Config.weapons.bolt, world.player
    bolt.timer = bolt.timer - dt
    if bolt.timer > 0 then return end

    local target = findNearestEnemy(world, cfg.targetRange)
    if not target then return end

    bolt.timer = cfg.cooldown * player.stats.cooldownMult
    Audio.play("bolt")
    local baseAngle = math.atan2(target.y - player.y, target.x - player.x)
    local count = player.stats.boltCount
    local damage = cfg.damage * player.stats.damageMult

    for i = 1, count do
        -- Fan the bolts out evenly around the aim direction.
        local offset = (i - (count + 1) / 2) * cfg.spread
        world:addProjectile(Projectile.new(player.x, player.y, baseAngle + offset, damage, 0, 0))
    end
end

----------------------------------------------------------------------
-- ORBIT: orbs circle the player and damage whatever they touch
----------------------------------------------------------------------
local orbit = { angle = 0 }

function orbit.reset()
    orbit.angle = 0
end

local function orbPosition(player, index, count)
    local cfg = Config.weapons.orbit
    local a = orbit.angle + (index - 1) * (math.pi * 2 / count)
    return player.x + math.cos(a) * cfg.radius, player.y + math.sin(a) * cfg.radius
end

function orbit.update(world, dt)
    local player = world.player
    local count = player.stats.orbCount
    if count <= 0 then return end

    local cfg = Config.weapons.orbit
    orbit.angle = orbit.angle + cfg.rotateSpeed * dt
    local damage = cfg.damage * player.stats.damageMult

    for i = 1, count do
        local ox, oy = orbPosition(player, i, count)
        for _, enemy in ipairs(world.enemies) do
            if not enemy.dead
               and world.time - enemy.lastOrbHit >= cfg.hitCooldown
               and Util.circlesOverlap(ox, oy, cfg.orbRadius, enemy.x, enemy.y, enemy.radius) then
                enemy.lastOrbHit = world.time
                local critical = love.math.random() < player.stats.critChance
                local hitDamage = damage * (critical and player.stats.critMult or 1)
                enemy:takeDamage(hitDamage, world)
                Audio.play("orbit")
                world:addDamageNumber(enemy, hitDamage, critical and {1, 0.85, 0.25} or {1, 1, 1}, critical)
            end
        end
    end
end

function orbit.draw(world)
    local player = world.player
    local count = player.stats.orbCount
    for i = 1, count do
        local ox, oy = orbPosition(player, i, count)
        love.graphics.setColor(1, 1, 1)
        Assets.draw("orb", ox, oy)
        if Config.debug then
            love.graphics.setColor(1, 1, 0, 0.8)
            love.graphics.circle("line", ox, oy, Config.weapons.orbit.orbRadius)
        end
    end
end

-- PULSE: a periodic ring that hits every enemy around the player.
local pulse = { timer = 0, flash = 0 }
function pulse.reset() pulse.timer, pulse.flash = 0, 0 end
function pulse.update(world, dt)
    local player = world.player
    if player.stats.pulseCount <= 0 then return end
    local cfg = Config.weapons.pulse
    pulse.timer = pulse.timer - dt
    pulse.flash = math.max(0, pulse.flash - dt)
    if pulse.timer > 0 then return end
    pulse.timer = cfg.cooldown * player.stats.cooldownMult
    pulse.flash = 0.22
    Audio.play("pulse")
    for _, enemy in ipairs(world.enemies) do
        if not enemy.dead and Util.distance(player.x, player.y, enemy.x, enemy.y) <= cfg.radius then
            local damage = cfg.damage * player.stats.damageMult
            enemy:takeDamage(damage, world)
            world:addDamageNumber(enemy, damage, {0.45, 0.9, 1}, false)
        end
    end
end
function pulse.draw(world)
    if pulse.flash <= 0 then return end
    local cfg = Config.weapons.pulse
    love.graphics.setColor(0.35, 0.85, 1, pulse.flash / 0.22 * 0.45)
    love.graphics.circle("line", world.player.x, world.player.y, cfg.radius * (1 - pulse.flash * 0.7))
end

-- LIGHTNING: chains through a few nearby targets whenever it fires.
local lightning = { timer = 0, strikes = {} }
function lightning.reset() lightning.timer, lightning.strikes = 0, {} end
function lightning.update(world, dt)
    local player = world.player
    if player.stats.lightningCount <= 0 then return end
    local cfg = Config.weapons.lightning
    lightning.timer = lightning.timer - dt
    if lightning.timer > 0 then return end
    lightning.timer = cfg.cooldown * player.stats.cooldownMult
    lightning.strikes = {}
    Audio.play("lightning")
    local fromX, fromY = player.x, player.y
    local used = {}
    for _ = 1, cfg.chains do
        local target, best = nil, cfg.chainRange
        for _, enemy in ipairs(world.enemies) do
            local d = Util.distance(fromX, fromY, enemy.x, enemy.y)
            if not enemy.dead and not used[enemy] and d < best then target, best = enemy, d end
        end
        if not target then break end
        used[target] = true
        lightning.strikes[#lightning.strikes + 1] = {fromX, fromY, target.x, target.y}
        local damage = cfg.damage * player.stats.damageMult
        target:takeDamage(damage, world)
        world:addDamageNumber(target, damage, {0.85, 0.65, 1}, false)
        fromX, fromY = target.x, target.y
    end
end
function lightning.draw(world)
    if #lightning.strikes == 0 then return end
    love.graphics.setColor(0.85, 0.65, 1, 0.8)
    love.graphics.setLineWidth(4)
    for _, s in ipairs(lightning.strikes) do love.graphics.line(s[1], s[2], s[3], s[4]) end
    love.graphics.setLineWidth(1)
end

----------------------------------------------------------------------
-- Public API used by world.lua
----------------------------------------------------------------------
Weapons.list = { bolt, rocket, orbit, pulse, lightning }

function Weapons.reset()
    for _, weapon in ipairs(Weapons.list) do
        if weapon.reset then weapon.reset() end
    end
end

function Weapons.update(world, dt)
    for _, weapon in ipairs(Weapons.list) do weapon.update(world, dt) end
end

function Weapons.draw(world)
    for _, weapon in ipairs(Weapons.list) do
        if weapon.draw then weapon.draw(world) end
    end
end

return Weapons
