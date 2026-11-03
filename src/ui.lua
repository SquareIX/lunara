-- src/ui.lua
-- All menus and the HUD. Everything is laid out in game units (see view.lua),
-- so it scales with the screen. Text goes through UI.text() to stay crisp.
--
-- Hit-testing helpers (UI.cardAt, UI.pauseButtonHit) take SCREEN PIXELS,
-- exactly what touch / mouse events give you.

local View = require("src.view")
local Config = require("src.config")
local Save = require("src.save")
local Assets = require("src.assets")
local Equipment = require("src.equipment")

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
  local w, h = View.size()
  local cfg = Config.pauseButton
  return { x = w - cfg.margin - cfg.size, y = 52, w = cfg.size, h = cfg.size }
end

function UI.pauseButtonHit(px, py)
  local x, y = toUnits(px, py)
  local r = pauseButtonRect()
  -- a little extra padding makes it easier to hit with a thumb
  return x >= r.x - 10 and x <= r.x + r.w + 10 and y >= r.y - 10 and y <= r.y + r.h + 10
end

local function inventoryButtonRect()
  local w, h = View.size()
  local cfg = Config.pauseButton
  return { x = w - cfg.margin - cfg.size * 2 - 12, y = 52, w = cfg.size, h = cfg.size }
end

function UI.inventoryButtonHit(px, py)
  local x, y = toUnits(px, py)
  local r = inventoryButtonRect()
  return x >= r.x - 10 and x <= r.x + r.w + 10 and y >= r.y - 10 and y <= r.y + r.h + 10
end

local function drawInventoryButton()
  local r = inventoryButtonRect()
  love.graphics.setColor(0, 0, 0, 0.45)
  love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 10, 10)
  love.graphics.setColor(1, 0.85, 0.4, 0.95)
  love.graphics.rectangle("line", r.x + r.w * 0.24, r.y + r.h * 0.34, r.w * 0.52, r.h * 0.44, 4, 4)
  love.graphics.rectangle("line", r.x + r.w * 0.36, r.y + r.h * 0.18, r.w * 0.28, r.h * 0.2, 4, 4)
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
-- Shared widgets
----------------------------------------------------------------------
local function drawPanel(rect, borderColor, fillColor)
  love.graphics.setColor(fillColor or { 0.10, 0.11, 0.20, 0.92 })
  love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 14, 14)
  love.graphics.setColor(borderColor or { 1, 0.65, 0.85 })
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 14, 14)
  love.graphics.setLineWidth(1)
end

local function drawButton(rect, label, accent)
  drawPanel(rect, accent or { 0.55, 0.9, 1 }, { 0.12, 0.16, 0.28, 0.95 })
  love.graphics.setColor(1, 1, 1)
  UI.text(label, rect.x, rect.y + rect.h / 2 - 15, 26, "center", rect.w)
end

function UI.backButtonHit(px, py)
  local x, y = toUnits(px, py)
  local _, h = View.size()
  return insideRect(x, y, { x = (View.size()) / 2 - 90, y = h - 84, w = 180, h = 46 })
end

local function drawBackButton()
  local w, h = View.size()
  drawButton({ x = w / 2 - 90, y = h - 84, w = 180, h = 46 }, "BACK")
end

----------------------------------------------------------------------
-- HUD (in-run)
----------------------------------------------------------------------
function UI.drawHud(world, showPauseButton)
  local player = world.player
  local w, h = View.size()
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
  love.graphics.setColor(0.75, 0.85, 1, 0.85)
  UI.text("GOAL " .. UI.formatTime(Config.objectiveSeconds), w - 190, 48, 15, "right", 178)

  if world.bossWarning > 0 then
    love.graphics.setColor(1, 0.22, 0.3, 0.95)
    UI.text("!! ATMINT DATANG 😈 !!", 0, 78, 24, "center", w)
  end

  love.graphics.setColor(0.75, 0.85, 1, 0.85)
  local skills = ""
  if player.stats.swordCount > 0 then skills = skills .. "  SWORD" end
  if player.stats.boltChain > 0 then skills = skills .. "  RICOCHET" end
  if player.stats.boltBurn > 0 then skills = skills .. "  EMBER" end
  if player.stats.pulseCount > 0 then skills = skills .. "  SHOCKWAVE" end
  if player.stats.lightningCount > 0 then skills = skills .. "  LIGHTNING" end
  if skills ~= "" then UI.text(skills, 12, h - 30, 16) end

  if showPauseButton then drawPauseButton() drawInventoryButton() end

  -- Low-HP danger vignette.
  if player.hp / player.stats.maxHp < 0.35 and not player:isDead() then
    local a = 0.16 + 0.12 * math.sin(world.time * 6)
    love.graphics.setColor(1, 0.15, 0.2, a)
    love.graphics.rectangle("fill", 0, 0, w, 10)
    love.graphics.rectangle("fill", 0, h - 10, w, 10)
    love.graphics.rectangle("fill", 0, 0, 10, h)
    love.graphics.rectangle("fill", w - 10, 0, 10, h)
  end

  if Config.debug then
    UI.text(string.format("FPS %d  enemies %d  bolts %d  gems %d",
      love.timer.getFPS(), #world.enemies, #world.projectiles, #world.gems), 12, 72, 16)
  end

  love.graphics.pop()
end

----------------------------------------------------------------------
-- Menus
----------------------------------------------------------------------
-- Main menu buttons: { id, label, rect }
function UI.menuButtons()
  local w, h = View.size()
  local bw, bh, gap = math.min(w - 60, 340), 58, 16
  local startY = h * 0.52
  local defs = {
    { id = "start", label = "▶  START RUN" },
    { id = "characters", label = "CHARACTERS" },
    { id = "howto", label = "HOW TO PLAY" },
  }
  local buttons = {}
  for i, def in ipairs(defs) do
    buttons[i] = { id = def.id, label = def.label,
      rect = { x = (w - bw) / 2, y = startY + (i - 1) * (bh + gap), w = bw, h = bh } }
  end
  return buttons
end

function UI.menuButtonAt(px, py)
  local x, y = toUnits(px, py)
  for _, button in ipairs(UI.menuButtons()) do
    if insideRect(x, y, button.rect) then return button.id end
  end
end

function UI.drawTitle()
  local w, h = View.size()
  beginUI()
  -- Menu artwork (falls back to a flat colour until menu_bg.png is added).
  local bg = Assets.images.menu_bg
  if bg then
    local iw, ih = bg:getDimensions()
    local scale = View.scale()
    local sx = (w * scale) / iw
    local sy = (h * scale) / ih
    local s = math.max(sx, sy)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(bg, (w - iw * s / scale) / 2, (h - ih * s / scale) / 2, 0, s / scale, s / scale)
    love.graphics.setColor(0.02, 0.03, 0.08, 0.45)
    love.graphics.rectangle("fill", 0, 0, w, h)
  else
    love.graphics.setColor(0.10, 0.12, 0.18)
    love.graphics.rectangle("fill", 0, 0, w, h)
  end

  -- Title with a soft shadow layer.
  love.graphics.setColor(0.45, 0.2, 0.5, 0.8)
  UI.text("LUNARA", 0, h * 0.16 + 4, 84, "center", w)
  love.graphics.setColor(1, 0.75, 0.9)
  UI.text("LUNARA", 0, h * 0.16, 84, "center", w)
  love.graphics.setColor(0.85, 0.92, 1)
  UI.text("— S U R V I V O R —", 0, h * 0.16 + 96, 24, "center", w)

  local char = Config.characterById(Save.character)
  love.graphics.setColor(1, 1, 1, 0.9)
  UI.text("Playing as: " .. char.name .. " · " .. char.title, 0, h * 0.40, 20, "center", w)

  for _, button in ipairs(UI.menuButtons()) do
    drawButton(button.rect, button.label, button.id == "start" and { 1, 0.65, 0.85 } or { 0.55, 0.9, 1 })
  end

  if Save.bestTime > 0 then
    love.graphics.setColor(1, 0.9, 0.4)
    UI.text("Best: " .. UI.formatTime(Save.bestTime), 0, h - 44, 22, "center", w)
  end
  love.graphics.pop()
end

----------------------------------------------------------------------
-- Character select
----------------------------------------------------------------------
function UI.characterRects()
  local w, h = View.size()
  local gap = 14
  local rects = {}
  if View.isPortrait() then
    local cardW, cardH = math.min(w - 40, 440), 168
    local totalH = #Config.characters * cardH + (#Config.characters - 1) * gap
    local startY = (h - totalH) / 2 - 10
    for i = 1, #Config.characters do
      rects[i] = { x = (w - cardW) / 2, y = startY + (i - 1) * (cardH + gap), w = cardW, h = cardH }
    end
  else
    local cardW = math.min(250, (w - 40 - (#Config.characters - 1) * gap) / #Config.characters)
    local cardH = 300
    local startX = (w - (#Config.characters * cardW + (#Config.characters - 1) * gap)) / 2
    for i = 1, #Config.characters do
      rects[i] = { x = startX + (i - 1) * (cardW + gap), y = (h - cardH) / 2 - 10, w = cardW, h = cardH }
    end
  end
  return rects
end

function UI.characterCardAt(px, py)
  local x, y = toUnits(px, py)
  for i, rect in ipairs(UI.characterRects()) do
    if insideRect(x, y, rect) then return i end
  end
end

function UI.drawCharacters(selectedId)
  local w, h = View.size()
  beginUI()
  love.graphics.setColor(0.07, 0.09, 0.15)
  love.graphics.rectangle("fill", 0, 0, w, h)
  love.graphics.setColor(1, 0.75, 0.9)
  UI.text("CHOOSE YOUR SURVIVOR", 0, 36, 34, "center", w)

  local rects = UI.characterRects()
  for i, rect in ipairs(rects) do
    local char = Config.characters[i]
    local selected = char.id == selectedId
    drawPanel(rect, selected and { 1, 0.85, 0.3 } or { 0.5, 0.55, 0.75 },
      selected and { 0.16, 0.14, 0.26, 0.97 } or { 0.10, 0.11, 0.20, 0.95 })
    -- Sprite preview (animated walk frame when the sheet exists).
    local cx = View.isPortrait() and rect.x + 62 or rect.x + rect.w / 2
    local cy = View.isPortrait() and rect.y + rect.h / 2 or rect.y + 84
    love.graphics.setColor(1, 1, 1)
    if Assets.animations[char.walkAnim] then
      local def = Assets.animations[char.walkAnim].def
      local frame = math.floor(love.timer.getTime() * def.fps) % def.frames + 1
      Assets.drawAnimated(char.walkAnim, cx, cy, frame, 0, false, 0)
    else
      Assets.draw(char.sprite, cx, cy)
    end
    local tx = View.isPortrait() and rect.x + 118 or rect.x + 10
    local tw = View.isPortrait() and rect.w - 128 or rect.w - 20
    local ty = View.isPortrait() and rect.y + 14 or rect.y + 138
    love.graphics.setColor(1, 1, 1)
    UI.text(char.name, tx, ty, 26, View.isPortrait() and "left" or "center", tw)
    love.graphics.setColor(0.65, 0.85, 1)
    UI.text(char.title, tx, ty + 30, 17, View.isPortrait() and "left" or "center", tw)
    love.graphics.setColor(0.85, 0.88, 0.95)
    UI.text(char.desc, tx, ty + 56, 16, View.isPortrait() and "left" or "center", tw)
    love.graphics.setColor(1, 0.9, 0.5)
    UI.text(string.format("HP x%.1f   SPD x%.2f   DMG x%.1f", char.hpMult, char.speedMult, char.damageMult),
      tx, ty + (View.isPortrait() and 118 or 118), 15, View.isPortrait() and "left" or "center", tw)
    if selected then
      love.graphics.setColor(1, 0.85, 0.3)
      UI.text("★ SELECTED", rect.x, rect.y + 6, 16, "right", rect.w - 12)
    end
  end
  drawBackButton()
  love.graphics.pop()
end

----------------------------------------------------------------------
-- How to play
----------------------------------------------------------------------
function UI.drawHowTo()
  local w, h = View.size()
  beginUI()
  love.graphics.setColor(0.07, 0.09, 0.15)
  love.graphics.rectangle("fill", 0, 0, w, h)
  love.graphics.setColor(1, 0.75, 0.9)
  UI.text("HOW TO PLAY", 0, 40, 34, "center", w)
  local panel = { x = math.max(16, w / 2 - 300), y = 110, w = math.min(w - 32, 600), h = h - 230 }
  drawPanel(panel, { 0.55, 0.9, 1 })
  love.graphics.setColor(0.9, 0.92, 1)
  UI.text("Drag on screen (or WASD / arrows) to move.\n"
    .. "All attacks are automatic - just dodge and position.\n\n"
    .. "Collect green gems to level up and pick upgrades.\n"
    .. "Enemies sometimes drop EQUIPMENT (helmets, armour, boots,\n"
    .. "amulets). Better gear equips itself; weaker loot becomes XP.\n"
    .. "Press I or tap the bag to see your gear.\n\n"
    .. "Watch out for golden ELITES and the boss every 90 seconds.\n"
    .. "Survive 10 minutes to win the night!",
    panel.x + 22, panel.y + 20, 19, "left", panel.w - 44)
  drawBackButton()
  love.graphics.pop()
end

----------------------------------------------------------------------
-- Inventory
----------------------------------------------------------------------
function UI.drawInventory(player)
  local w, h = View.size()
  beginUI()
  dimScreen(0.72)
  love.graphics.setColor(1, 0.85, 0.4)
  UI.text("INVENTORY", 0, 30, 36, "center", w)
  local panelW = math.min(w - 32, 520)
  local rowH = 86
  local panel = { x = (w - panelW) / 2, y = 92, w = panelW, h = #Equipment.slots * rowH + 58 }
  drawPanel(panel, { 1, 0.85, 0.4 })
  for i, slot in ipairs(Equipment.slots) do
    local ry = panel.y + 12 + (i - 1) * rowH
    love.graphics.setColor(1, 1, 1)
    Assets.draw(slot, panel.x + 46, ry + rowH / 2 - 6)
    love.graphics.setColor(0.65, 0.7, 0.85)
    UI.text(slot:upper(), panel.x + 92, ry + 2, 14)
    local item = player.equipment[slot]
    if item then
      love.graphics.setColor(item.color)
      UI.text(item.name .. "  (" .. item.rarityName .. ")", panel.x + 92, ry + 20, 21)
      love.graphics.setColor(0.88, 0.9, 0.97)
      UI.text(item.desc, panel.x + 92, ry + 48, 16)
    else
      love.graphics.setColor(0.55, 0.58, 0.7)
      UI.text("— nothing equipped —", panel.x + 92, ry + 24, 19)
    end
  end
  love.graphics.setColor(0.75, 0.8, 0.9)
  UI.text("Gear drops from enemies. Stronger gear auto-equips;\nweaker loot is scrapped into XP.  (I / Esc to close)",
    panel.x + 16, panel.y + panel.h - 46, 15, "center", panel.w - 32)
  drawBackButton()
  love.graphics.pop()
end

function UI.drawPaused()
  local w, h = View.size()
  beginUI()
  dimScreen(0.6)
  love.graphics.setColor(1, 1, 1)
  UI.text("PAUSED", 0, h * 0.4, 56, "center", w)
  UI.text("Tap / press Esc to resume", 0, h * 0.52, 24, "center", w)
  love.graphics.setColor(0.75, 0.8, 0.9)
  UI.text("Press I for inventory", 0, h * 0.60, 19, "center", w)
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

function UI.drawVictory(world, newRecord, canRestart)
  local w, h = View.size()
  beginUI()
  dimScreen(0.65)
  love.graphics.setColor(0.35, 1, 0.65)
  UI.text("10 MINUTES SURVIVED!", 0, h * 0.25, 48, "center", w)
  love.graphics.setColor(1, 1, 1)
  UI.text("You cleared the night.", 0, h * 0.39, 28, "center", w)
  UI.text("Level " .. world.player.level .. "   Kills " .. world.kills, 0, h * 0.47, 26, "center", w)
  if newRecord then
    love.graphics.setColor(1, 0.9, 0.4)
    UI.text("New best time!", 0, h * 0.54, 28, "center", w)
  end
  love.graphics.setColor(1, 1, 1, canRestart and 1 or 0.25)
  UI.text("Tap / press Enter to play again", 0, h * 0.68, 26, "center", w)
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

function UI.rerollButtonRect()
  local w, h = View.size()
  return { x = w / 2 - 105, y = h - 58, w = 210, h = 40 }
end

function UI.rerollButtonHit(px, py)
  local x, y = toUnits(px, py)
  return insideRect(x, y, UI.rerollButtonRect())
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
  local reroll = UI.rerollButtonRect()
  love.graphics.setColor(0.12, 0.35, 0.46, 0.96)
  love.graphics.rectangle("fill", reroll.x, reroll.y, reroll.w, reroll.h, 10, 10)
  love.graphics.setColor(0.55, 0.9, 1)
  love.graphics.rectangle("line", reroll.x, reroll.y, reroll.w, reroll.h, 10, 10)
  love.graphics.setColor(1, 1, 1)
  UI.text("R  REROLL (" .. player.stats.rerolls .. ")", reroll.x, reroll.y + 9, 18, "center", reroll.w)
  love.graphics.pop()
end

return UI
