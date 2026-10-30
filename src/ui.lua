-- src/ui.lua
-- All menus and the HUD. Everything is laid out in game units (see view.lua),
-- so it scales with the screen. Text goes through UI.text() to stay crisp.
--
-- Hit-testing helpers (UI.cardAt, UI.pauseButtonHit) take SCREEN PIXELS,
-- exactly what touch / mouse events give you.

local View = require("src.view")
local Config = require("src.config")
local Save = require("src.save")

local UI = {}

local fontCache = {}

local function getFont(pixelSize)
    pixelSize = math.max(8, math.floor(pixelSize))
    if not fontCache[pixelSize] then
        fontCache[pixelSize] = love.graphics.newFont(pixelSize)
    end
    return fontCache[pixelSize]
end

-- Draws text at game-unit position. `size` is also in game units.
function UI.text(str, x, y, size, align, width)
    local scale = View.scale()
    love.graphics.push()
    love.graphics.scale(1 / scale)
    love.graphics.setFont(getFont(size * scale))
    love.graphics.printf(str, x * scale, y * scale, (width or 1000) * scale, align or "left")
    love.graphics.pop()
end

function UI.formatTime(seconds)
    return string.format("%02d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
end

local function beginUI()
    love.graphics.push()
    love.graphics.scale(View.scale())
end

local function dimScreen(alpha)
    local w, h = View.size()
    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.rectangle("fill", 0, 0, w, h)
end

local function toUnits(px, py)
    local scale = View.scale()
    return px / scale, py / scale
end

local function insideRect(x, y, r)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

----------------------------------------------------------------------
-- Pause button
----------------------------------------------------------------------
local function pauseButtonRect()
    local w = View.size()
    local cfg = Config.pauseButton
    return { x = w - cfg.margin - cfg.size, y = 52, w = cfg.size, h = cfg.size }
end

function UI.pauseButtonHit(px, py)
    local x, y = toUnits(px, py)
    local r = pauseButtonRect()
    -- a little extra padding makes it easier to hit with a thumb
    return x >= r.x - 10 and x <= r.x + r.w + 10 and y >= r.y - 10 and y <= r.y + r.h + 10
end

local function drawPauseButton()
    local r = pauseButtonRect()
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 10, 10)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.rectangle("fill", r.x + r.w * 0.30, r.y + r.h * 0.24, r.w * 0.14, r.h * 0.52, 3, 3)
    love.graphics.rectangle("fill", r.x + r.w * 0.56, r.y + r.h * 0.24, r.w * 0.14, r.h * 0.52, 3, 3)
end

----------------------------------------------------------------------
-- HUD (in-run)
----------------------------------------------------------------------
function UI.drawHud(world, showPauseButton)
    local player = world.player
    local w = View.size()
    beginUI()

    -- XP bar across the top
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, w, 14)
    love.graphics.setColor(0.3, 0.8, 1)
    love.graphics.rectangle("fill", 0, 0, w * player.xp / player.xpToNext, 14)

    -- HP bar
    local barW = 190
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 12, 24, barW, 16, 4, 4)
    love.graphics.setColor(1.0, 0.35, 0.5)
    love.graphics.rectangle("fill", 12, 24, barW * math.max(0, player.hp) / player.stats.maxHp, 16, 4, 4)
    love.graphics.setColor(1, 1, 1, 0.95)
    UI.text(string.format("HP %d / %d", math.max(0, math.ceil(player.hp)), player.stats.maxHp), 18, 24, 14)

    love.graphics.setColor(1, 1, 1)
    UI.text("LV " .. player.level, 12, 44, 20)
    UI.text(UI.formatTime(world.time), 0, 20, 28, "center", w)
    UI.text("Kills " .. world.kills, w - 162, 22, 20, "right", 150)

    if showPauseButton then drawPauseButton() end

    if Config.debug then
        UI.text(string.format("FPS %d  enemies %d  bolts %d  gems %d",
            love.timer.getFPS(), #world.enemies, #world.projectiles, #world.gems), 12, 72, 16)
    end

    love.graphics.pop()
end

----------------------------------------------------------------------
-- Menus
----------------------------------------------------------------------
function UI.drawTitle()
    local w, h = View.size()
    beginUI()
    love.graphics.setColor(0.10, 0.12, 0.18)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(1, 0.65, 0.85)
    UI.text("SURVIVOR", 0, h * 0.25, 64, "center", w)
    love.graphics.setColor(1, 1, 1)
    UI.text("Tap / press Enter to start", 0, h * 0.50, 28, "center", w)
    UI.text("Drag on screen (or WASD) to move.\nAttacks are automatic.", 20, h * 0.60, 20, "center", w - 40)
    if Save.bestTime > 0 then
        love.graphics.setColor(1, 0.9, 0.4)
        UI.text("Best: " .. UI.formatTime(Save.bestTime), 0, h * 0.75, 26, "center", w)
    end
    love.graphics.pop()
end

function UI.drawPaused()
    local w, h = View.size()
    beginUI()
    dimScreen(0.6)
    love.graphics.setColor(1, 1, 1)
    UI.text("PAUSED", 0, h * 0.4, 56, "center", w)
    UI.text("Tap / press Esc to resume", 0, h * 0.52, 24, "center", w)
    love.graphics.pop()
end

function UI.drawGameOver(world, newRecord, canRestart)
    local w, h = View.size()
    beginUI()
    dimScreen(0.7)
    love.graphics.setColor(1, 0.4, 0.5)
    UI.text("YOU FELL...", 0, h * 0.25, 54, "center", w)
    love.graphics.setColor(1, 1, 1)
    UI.text("Survived " .. UI.formatTime(world.time), 0, h * 0.40, 30, "center", w)
    UI.text("Level " .. world.player.level .. "   Kills " .. world.kills, 0, h * 0.47, 28, "center", w)
    if newRecord then
        love.graphics.setColor(1, 0.9, 0.4)
        UI.text("New best time!", 0, h * 0.54, 28, "center", w)
    end
    love.graphics.setColor(1, 1, 1, canRestart and 1 or 0.25)
    UI.text("Tap / press Enter to retry", 0, h * 0.68, 26, "center", w)
    love.graphics.pop()
end

----------------------------------------------------------------------
-- Level-up cards
----------------------------------------------------------------------
-- Card rectangles in game units. Used for both drawing and touch hit-testing.
-- Portrait screens stack the cards vertically, landscape puts them side by side.
function UI.cardRects(count)
    local w, h = View.size()
    local gap = 16
    local rects = {}

    if View.isPortrait() then
        local cardW, cardH = math.min(w - 40, 460), 130
        local totalH = count * cardH + (count - 1) * gap
        local startY = (h - totalH) / 2 + 30
        for i = 1, count do
            rects[i] = { x = (w - cardW) / 2, y = startY + (i - 1) * (cardH + gap), w = cardW, h = cardH }
        end
    else
        local cardW, cardH = math.min(240, (w - 40 - (count - 1) * gap) / count), 220
        local startX = (w - (count * cardW + (count - 1) * gap)) / 2
        for i = 1, count do
            rects[i] = { x = startX + (i - 1) * (cardW + gap), y = (h - cardH) / 2 + 20, w = cardW, h = cardH }
        end
    end
    return rects
end

-- Returns the index of the card under screen-pixel (px, py), or nil.
function UI.cardAt(count, px, py)
    local x, y = toUnits(px, py)
    for i, rect in ipairs(UI.cardRects(count)) do
        if insideRect(x, y, rect) then return i end
    end
end

function UI.drawLevelUp(choices, player)
    local w, h = View.size()
    beginUI()
    dimScreen(0.7)
    love.graphics.setColor(1, 0.9, 0.3)
    local rects = UI.cardRects(#choices)
    UI.text("LEVEL UP!  (Lv " .. player.level .. ")", 0, math.max(30, rects[1].y - 80), 40, "center", w)

    for i, rect in ipairs(rects) do
        local upgrade = choices[i]
        love.graphics.setColor(0.17, 0.18, 0.30, 0.95)
        love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 12, 12)
        love.graphics.setColor(1, 0.65, 0.85)
        love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 12, 12)

        love.graphics.setColor(1, 1, 1)
        UI.text(upgrade.name, rect.x + 10, rect.y + rect.h * 0.18, 28, "center", rect.w - 20)
        love.graphics.setColor(0.8, 0.85, 0.95)
        UI.text(upgrade.desc, rect.x + 14, rect.y + rect.h * 0.52, 20, "center", rect.w - 28)
        love.graphics.setColor(0.6, 0.6, 0.75)
        UI.text("[" .. i .. "]", rect.x + rect.w - 40, rect.y + 6, 16, "right", 30)
    end
    love.graphics.pop()
end

return UI
