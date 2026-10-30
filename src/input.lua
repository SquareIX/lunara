-- src/input.lua
-- One place that turns keyboard + touch/mouse into a movement direction.
--
-- Touch: a floating virtual joystick appears wherever you press and drag.
-- Keyboard: WASD or arrow keys.
-- main.lua forwards press / move / release events here while playing.

local Config = require("src.config")
local Util = require("src.util")
local View = require("src.view")

local Input = {}

local stick = {
    active = false,
    id = nil,        -- touch id (or "mouse")
    originX = 0, originY = 0,   -- where the finger first touched (screen pixels)
    currentX = 0, currentY = 0, -- where the finger is now
}

local function stickRadiusPixels()
    return Config.touch.joystickRadius * View.scale()
end

function Input.pressed(id, x, y)
    if stick.active then return end
    stick.active = true
    stick.id = id
    stick.originX, stick.originY = x, y
    stick.currentX, stick.currentY = x, y
end

function Input.moved(id, x, y)
    if stick.active and stick.id == id then
        stick.currentX, stick.currentY = x, y
    end
end

function Input.released(id)
    if stick.active and stick.id == id then
        stick.active = false
    end
end

function Input.reset()
    stick.active = false
end

-- Returns a direction vector (dx, dy) with length 0..1.
function Input.getMoveVector()
    local dx, dy = 0, 0
    if love.keyboard.isDown("a", "left")  then dx = dx - 1 end
    if love.keyboard.isDown("d", "right") then dx = dx + 1 end
    if love.keyboard.isDown("w", "up")    then dy = dy - 1 end
    if love.keyboard.isDown("s", "down")  then dy = dy + 1 end
    if dx ~= 0 or dy ~= 0 then
        return Util.normalize(dx, dy)
    end

    if stick.active then
        local radius = stickRadiusPixels()
        local sx = (stick.currentX - stick.originX) / radius
        local sy = (stick.currentY - stick.originY) / radius
        local length = math.sqrt(sx * sx + sy * sy)
        if length > Config.touch.deadzone then
            if length > 1 then sx, sy = sx / length, sy / length end
            return sx, sy
        end
    end
    return 0, 0
end

-- Draws the joystick in screen space (call after everything else).
function Input.draw()
    if not stick.active then return end
    local radius = stickRadiusPixels()
    local dx, dy = stick.currentX - stick.originX, stick.currentY - stick.originY
    local length = math.sqrt(dx * dx + dy * dy)
    if length > radius then dx, dy = dx / length * radius, dy / length * radius end

    love.graphics.setColor(1, 1, 1, 0.15)
    love.graphics.circle("fill", stick.originX, stick.originY, radius)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.circle("line", stick.originX, stick.originY, radius)
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.circle("fill", stick.originX + dx, stick.originY + dy, radius * 0.35)
end

return Input
