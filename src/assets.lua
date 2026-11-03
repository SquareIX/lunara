-- src/assets.lua
-- Loads sprites listed in Config.sprites. If a PNG is missing, a coloured
-- placeholder shape is generated, so the game always runs.
--
-- Draw a sprite with:  Assets.draw("slime", x, y, rotation, flipX, squash)
--   * it is centred on (x, y) and scaled to the `size` set in config.lua
--   * `squash` (optional, about -0.1..0.1) stretches it for a bouncy feel

local Config = require("src.config")

local Assets = { images = {}, animations = {} }

local SPRITE_FOLDER = "assets/sprites/"

local function makeFallback(def)
    local size = 32
    local canvas = love.graphics.newCanvas(size, size)
    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(def.color)
    if def.shape == "rect" then
        love.graphics.rectangle("fill", 0, 0, size, size)
    else
        love.graphics.circle("fill", size / 2, size / 2, size / 2 - 1)
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.circle("line", size / 2, size / 2, size / 2 - 1)
    end
    love.graphics.pop()
    return canvas
end

-- Safe to call again at runtime (F5 in main.lua) to hot-reload your art.
function Assets.load()
    Assets.animations = {}
    for name, def in pairs(Config.sprites) do
        local path = SPRITE_FOLDER .. def.file
        if love.filesystem.getInfo(path) then
            local image = love.graphics.newImage(path)
            image:setFilter(Config.spriteFilter, Config.spriteFilter)
            Assets.images[name] = image
        else
            print("[assets] missing " .. path .. " -> using fallback shape")
            Assets.images[name] = makeFallback(def)
        end
    end
    for name, def in pairs(Config.animations or {}) do
        local path = SPRITE_FOLDER .. def.file
        if love.filesystem.getInfo(path) then
            local image = love.graphics.newImage(path)
            image:setFilter(Config.spriteFilter, Config.spriteFilter)
            local frameWidth = def.frameWidth or (image:getWidth() / def.frames)
            local frameHeight = def.frameHeight or image:getHeight()
            local quads = {}
            for i = 0, def.frames - 1 do
                quads[i + 1] = love.graphics.newQuad(i * frameWidth, 0, frameWidth, frameHeight, image:getDimensions())
            end
            Assets.animations[name] = { image = image, quads = quads, def = def, frameWidth = frameWidth, frameHeight = frameHeight }
        else
            print("[assets] missing animation " .. path .. " -> using static sprite")
        end
    end
end

local function drawScaled(name, x, y, rotation, flipX, squash, sizeOverride)
    local image = Assets.images[name]
    local def = Config.sprites[name]
    local w, h = image:getDimensions()
    local scale = (sizeOverride or def.size) / math.max(w, h)
    squash = squash or 0
    local sx = scale * (1 + squash) * (flipX and -1 or 1)
    local sy = scale * (1 - squash)
    love.graphics.draw(image, x, y, rotation or 0, sx, sy, w / 2, h / 2)
end

function Assets.draw(name, x, y, rotation, flipX, squash)
    drawScaled(name, x, y, rotation, flipX, squash)
end

function Assets.drawAnimated(name, x, y, frame, rotation, flipX, squash)
    local animation = Assets.animations[name]
    if not animation then
        Assets.draw(name, x, y, rotation, flipX, squash)
        return
    end
    local def, image = animation.def, animation.image
    local frameWidth, frameHeight = animation.frameWidth, animation.frameHeight
    local quad = animation.quads[((math.floor(frame or 1) - 1) % def.frames) + 1]
    local scale = def.size / math.max(frameWidth, frameHeight)
    squash = squash or 0
    local sx = scale * (1 + squash) * (flipX and -1 or 1)
    local sy = scale * (1 - squash)
    love.graphics.draw(image, quad, x, y, rotation or 0, sx, sy, frameWidth / 2, frameHeight / 2)
end

-- Background tiles are drawn 2 units larger so no thin seams show between them.
function Assets.drawTile(name, x, y)
    drawScaled(name, x, y, 0, false, 0, Config.sprites[name].size + 2)
end

-- Soft oval under a character (uses `shadow` from config.lua).
function Assets.drawShadow(name, x, y)
    local def = Config.sprites[name]
    if not def.shadow or def.shadow <= 0 then return end
    love.graphics.setColor(0, 0, 0, 0.28)
    love.graphics.ellipse("fill", x, y + def.size * 0.40, def.size * def.shadow * 0.5, def.size * 0.12)
end

return Assets
