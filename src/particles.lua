-- src/particles.lua
-- Tiny particle system for juice: death bursts, sparks, embers, pickups.
-- Particles live in a plain list owned by the world (world.particles).
-- A particle is a table: x, y, vx, vy, life, maxLife, size, color, gravity, drag.

local Particles = {}

local function rand(min, max) return min + love.math.random() * (max - min) end

-- Spawn `count` particles at (x, y).
-- opts: colors (list of {r,g,b}), speed {min,max}, life {min,max}, size {min,max},
--       angle (direction, optional), spread (radians, default full circle),
--       gravity (default 0), drag (default 2.5)
function Particles.spawn(list, x, y, opts)
    if #list > 700 then return end  -- hard cap: juice must never tank the frame rate
    opts = opts or {}
    local colors = opts.colors or { { 1, 1, 1 } }
    local speed = opts.speed or { 40, 160 }
    local life = opts.life or { 0.3, 0.7 }
    local size = opts.size or { 2, 4 }
    local baseAngle = opts.angle or 0
    local spread = opts.spread or math.pi * 2
    for _ = 1, opts.count or 10 do
        local a = baseAngle + rand(-spread / 2, spread / 2)
        local s = rand(speed[1], speed[2])
        local l = rand(life[1], life[2])
        list[#list + 1] = {
            x = x, y = y,
            vx = math.cos(a) * s, vy = math.sin(a) * s,
            life = l, maxLife = l,
            size = rand(size[1], size[2]),
            color = colors[love.math.random(#colors)],
            gravity = opts.gravity or 0,
            drag = opts.drag or 2.5,
        }
    end
end

-- Convenience: radial burst in one or two colours.
function Particles.burst(list, x, y, color, count)
    Particles.spawn(list, x, y, { count = count or 12, colors = { color, { 1, 1, 1 } } })
end

function Particles.update(list, dt)
    local kept = 0
    for i = 1, #list do
        local p = list[i]
        p.life = p.life - dt
        if p.life > 0 then
            local dragF = math.max(0, 1 - p.drag * dt)
            p.vx = p.vx * dragF
            p.vy = p.vy * dragF + p.gravity * dt
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            kept = kept + 1
            list[kept] = p
        end
    end
    for i = #list, kept + 1, -1 do list[i] = nil end
end

function Particles.draw(list)
    for _, p in ipairs(list) do
        local t = p.life / p.maxLife
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], t)
        love.graphics.circle("fill", p.x, p.y, p.size * (0.4 + 0.6 * t))
    end
    love.graphics.setColor(1, 1, 1)
end

return Particles
