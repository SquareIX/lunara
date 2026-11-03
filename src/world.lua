-- src/world.lua
-- Owns everything that exists during one run: the player, enemies, bolts, gems.
-- Also handles enemy spawning and the camera.
--
-- main.lua creates a new World for every run and calls update()/draw().

local Config = require("src.config")
local Assets = require("src.assets")
local View = require("src.view")
local Util = require("src.util")
local Player = require("src.entities.player")
local Enemy = require("src.entities.enemy")
local Gem = require("src.entities.gem")
local Weapons = require("src.weapons")
local FloatingText = require("src.entities.floating_text")
local Particles = require("src.particles")
local Audio = require("src.audio")

local World = {}
World.__index = World

function World.new()
    local self = setmetatable({}, World)
    self.player = Player.new()
    self.enemies = {}
    self.projectiles = {}
    self.gems = {}
    self.floatingTexts = {}
    self.particles = {}
    self.damageBuckets = {}
    self.shake = 0          -- screen shake magnitude in world units (decays)
    self.hitstop = 0        -- brief freeze frames on big hits, seconds
    self.lastLevel = 1      -- for level-up celebration effects
    self.time = 0            -- seconds survived
    self.kills = 0
    self.spawnTimer = 0.5
    self.nextBossTime = Config.spawn.bossInterval
    self.bossWarning = 0
    self.camera = { x = 0, y = 0 }
    Weapons.reset()
    return self
end

----------------------------------------------------------------------
-- Adding things (used by weapons and enemies)
----------------------------------------------------------------------
-- Screen shake: bigger events ask for more, capped so it stays readable.
function World:addShake(amount)
    self.shake = math.min(16, self.shake + amount)
end

function World:addProjectile(projectile)
    self.projectiles[#self.projectiles + 1] = projectile
end

function World:spawnGem(x, y, value)
    self.gems[#self.gems + 1] = Gem.new(x, y, value)
end

function World:addFloatingText(x, y, text, color, critical)
    self.floatingTexts[#self.floatingTexts + 1] = FloatingText.new(x, y, text, color, critical)
end

-- Hits landing close together on one enemy are shown as one combined number.
function World:addDamageNumber(enemy, amount, color, critical)
    local bucket = self.damageBuckets[enemy]
    if not bucket then
        bucket = { amount = 0, timer = 0.09, color = color, critical = false }
        self.damageBuckets[enemy] = bucket
    end
    bucket.amount = bucket.amount + amount
    bucket.color = color or bucket.color
    bucket.critical = bucket.critical or critical
    bucket.timer = 0.09
end

function World:updateDamageNumbers(dt)
    for enemy, bucket in pairs(self.damageBuckets) do
        bucket.timer = bucket.timer - dt
        if bucket.timer <= 0 then
            self:addFloatingText(enemy.x, enemy.y - enemy.radius - 8, math.floor(bucket.amount + 0.5), bucket.color, bucket.critical)
            self.damageBuckets[enemy] = nil
        end
    end
end

----------------------------------------------------------------------
-- Spawning
----------------------------------------------------------------------
-- Picks an enemy type among those unlocked, using the `weight` in config.
local function pickEnemyType(time)
    local total = 0
    for _, def in pairs(Config.enemies) do
        if not def.boss and time >= def.unlockTime then total = total + def.weight end
    end
    local roll = love.math.random() * total
    for name, def in pairs(Config.enemies) do
        if not def.boss and time >= def.unlockTime then
            roll = roll - def.weight
            if roll <= 0 then return name end
        end
    end
    return "slime"   -- safety net (floating point), slime is always unlocked
end

-- A random point just outside the visible screen.
function World:randomSpawnPoint()
    local viewW, viewH = View.size()
    local margin = Config.spawn.margin
    local halfW, halfH = viewW / 2 + margin, viewH / 2 + margin
    local angle = love.math.random() * math.pi * 2
    -- Project the direction onto the rectangle border.
    local dx, dy = math.cos(angle), math.sin(angle)
    local t = math.min(halfW / math.max(math.abs(dx), 1e-6), halfH / math.max(math.abs(dy), 1e-6))
    return self.player.x + dx * t, self.player.y + dy * t
end

function World:updateSpawning(dt)
    local cfg = Config.spawn
    if self.time >= self.nextBossTime then
        local hpScale = 1 + (self.time / 60) * cfg.bossHpScalePerMinute
        local x, y = self:randomSpawnPoint()
        self.enemies[#self.enemies + 1] = Enemy.new("boss", x, y, hpScale)
        self.nextBossTime = self.nextBossTime + cfg.bossInterval
        self.bossWarning = 3
    end
    self.bossWarning = math.max(0, self.bossWarning - dt)
    self.spawnTimer = self.spawnTimer - dt
    if self.spawnTimer > 0 then return end

    local interval = math.max(cfg.minInterval, cfg.startInterval - self.time * cfg.intervalShrinkPerSecond)
    self.spawnTimer = interval

    local batch = 1 + math.floor(self.time / cfg.batchGrowthSeconds)
    local hpScale = 1 + (self.time / 60) * cfg.hpScalePerMinute

    for _ = 1, batch do
        if #self.enemies >= cfg.maxEnemies then break end
        local x, y = self:randomSpawnPoint()
        self.enemies[#self.enemies + 1] = Enemy.new(pickEnemyType(self.time), x, y, hpScale)
    end
end

----------------------------------------------------------------------
-- Update / draw
----------------------------------------------------------------------
local function updateAll(list, dt, world)
    for _, item in ipairs(list) do
        if not item.dead then item:update(dt, world) end
    end
    Util.removeDead(list)
end

function World:update(dt)
    -- Hitstop: freeze the world for a few frames on big hits.
    if self.hitstop > 0 then
        self.hitstop = self.hitstop - dt
        return
    end
    self.time = self.time + dt
    self.shake = math.max(0, self.shake - dt * 30)

    self.player:update(dt, self)
    Weapons.update(self, dt)
    self:updateSpawning(dt)

    updateAll(self.enemies, dt, self)
    updateAll(self.projectiles, dt, self)
    updateAll(self.gems, dt, self)
    self:updateDamageNumbers(dt)
    updateAll(self.floatingTexts, dt, self)
    Particles.update(self.particles, dt)

    -- Level-up celebration: sound, gold burst and a floating banner.
    if self.player.level > self.lastLevel then
        self.lastLevel = self.player.level
        Audio.play("levelup")
        Particles.spawn(self.particles, self.player.x, self.player.y, {
            count = 26, colors = { { 1, 0.85, 0.25 }, { 1, 1, 1 } },
            speed = { 80, 220 }, life = { 0.4, 0.8 }, size = { 2, 4 },
        })
        self:addFloatingText(self.player.x, self.player.y - 46, "LEVEL UP!", { 1, 0.85, 0.25 }, true)
    end

    self.camera.x, self.camera.y = self.player.x, self.player.y
end

local function drawBackground(camera)
    local tile = Config.sprites.background.size
    local viewW, viewH = View.size()
    local firstX = math.floor((camera.x - viewW / 2) / tile)
    local lastX  = math.floor((camera.x + viewW / 2) / tile)
    local firstY = math.floor((camera.y - viewH / 2) / tile)
    local lastY  = math.floor((camera.y + viewH / 2) / tile)

    love.graphics.setColor(1, 1, 1)
    for ty = firstY, lastY do
        for tx = firstX, lastX do
            Assets.drawTile("background", tx * tile + tile / 2, ty * tile + tile / 2)
        end
    end
end

-- Draws the game world (camera applied). UI is drawn separately by ui.lua.
function World:draw()
    local viewW, viewH = View.size()
    local scale = View.scale()

    love.graphics.push()
    love.graphics.scale(scale)
    -- Rounding to whole screen pixels stops sprites from shimmering while moving.
    local camX = math.floor(self.camera.x * scale) / scale
    local camY = math.floor(self.camera.y * scale) / scale
    love.graphics.translate(viewW / 2 - camX, viewH / 2 - camY)
    if self.shake > 0.2 then
        love.graphics.translate((love.math.random() * 2 - 1) * self.shake,
                                (love.math.random() * 2 - 1) * self.shake)
    end

    drawBackground(self.camera)

    -- Layers, back to front: shadows, gems, enemies, player, weapons.
    for _, enemy in ipairs(self.enemies) do
        love.graphics.setColor(1, 1, 1)
        Assets.drawShadow(enemy.sprite, enemy.x, enemy.y)
    end
    Assets.drawShadow("player", self.player.x, self.player.y)

    for _, gem in ipairs(self.gems) do gem:draw() end
    for _, enemy in ipairs(self.enemies) do enemy:draw() end
    self.player:draw()
    Weapons.draw(self)
    for _, projectile in ipairs(self.projectiles) do projectile:draw() end
    Particles.draw(self.particles)
    for _, text in ipairs(self.floatingTexts) do text:draw() end

    love.graphics.pop()
end

return World
