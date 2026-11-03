-- main.lua
-- Entry point. Only does three things:
--   1. keeps track of the current game STATE (title / playing / levelup / paused / gameover)
--   2. forwards LÖVE callbacks (update, draw, input) to the right module
--   3. creates a fresh World for every run
-- Game rules live in src/world.lua; tweakable numbers in src/config.lua.

local Config = require("src.config")
local Assets = require("src.assets")
local Input = require("src.input")
local UI = require("src.ui")
local World = require("src.world")
local Upgrades = require("src.upgrades")
local Save = require("src.save")
local Audio = require("src.audio")

local state = "title"     -- "title" | "characters" | "howto" | "playing" | "levelup" | "paused" | "inventory" | "gameover" | "victory"
local inventoryReturn = "playing"  -- state to go back to when inventory closes
local stateTime = 0       -- seconds spent in the current state
local world = nil
local upgradeChoices = {} -- cards shown in the "levelup" state
local newRecord = false   -- did the last run beat the best time?

----------------------------------------------------------------------
-- State changes
----------------------------------------------------------------------
local function setState(name)
  state = name
  stateTime = 0
  Input.reset()   -- never carry a held joystick into another screen
end

local function startRun()
  world = World.new(Save.character)
  newRecord = false
  setState("playing")
  Audio.setMusic("normal")
end

local function openLevelUp()
  upgradeChoices = Upgrades.roll(world.player)
  setState("levelup")
end

local function chooseUpgrade(index)
  local upgrade = upgradeChoices[index]
  if not upgrade then return end
  Upgrades.apply(upgrade, world.player)
  world.player.pendingLevelUps = world.player.pendingLevelUps - 1

  if world.player.pendingLevelUps > 0 then
    openLevelUp()     -- gained several levels at once
  else
    setState("playing")
  end
end

local function rerollUpgrades()
  if state ~= "levelup" or world.player.stats.rerolls <= 0 then return end
  world.player.stats.rerolls = world.player.stats.rerolls - 1
  upgradeChoices = Upgrades.roll(world.player)
end

local function togglePause()
  if state == "playing" then
    setState("paused")
  elseif state == "paused" then
    setState("playing")
  end
end

local function endRun()
  newRecord = Save.submitTime(world.time)
  setState("gameover")
end

local function winRun()
  newRecord = Save.submitTime(Config.objectiveSeconds)
  setState("victory")
end

-- Game-over screen ignores input for a moment so you can't restart by accident.
local function canRestart()
  return stateTime >= Config.gameOverLockSeconds
end

----------------------------------------------------------------------
-- LÖVE callbacks
----------------------------------------------------------------------
function love.load()
  love.graphics.setDefaultFilter(Config.spriteFilter, Config.spriteFilter)
  love.math.setRandomSeed(os.time())
  Assets.load()
  Audio.load()
  Save.load()
end

function love.update(dt)
  dt = math.min(dt, 1 / 20)   -- avoid huge jumps after a lag spike
  stateTime = stateTime + dt
  if state ~= "playing" then return end

  Audio.update(world)
  world:update(dt)

  if world.player:isDead() then
    endRun()
  elseif world.time >= Config.objectiveSeconds then
    winRun()
  elseif world.player.pendingLevelUps > 0 then
    openLevelUp()
  end
end

local function openInventory(fromState)
  inventoryReturn = fromState
  setState("inventory")
end

function love.draw()
  if state == "title" then
    UI.drawTitle()
    return
  end
  if state == "characters" then
    UI.drawCharacters(Save.character)
    return
  end
  if state == "howto" then
    UI.drawHowTo()
    return
  end

  world:draw()
  UI.drawHud(world, state == "playing")

  if state == "playing" then Input.draw() end
  if state == "levelup" then UI.drawLevelUp(upgradeChoices, world.player) end
  if state == "inventory" then UI.drawInventory(world.player) end
  if state == "paused" then UI.drawPaused() end
  if state == "gameover" then UI.drawGameOver(world, newRecord, canRestart()) end
  if state == "victory" then UI.drawVictory(world, newRecord, canRestart()) end
end

----------------------------------------------------------------------
-- Input: keyboard
----------------------------------------------------------------------
function love.keypressed(key)
  if key == "f1" then Config.debug = not Config.debug end
  if key == "f5" then Assets.load() end   -- hot-reload sprites after editing PNGs


  if state == "title" then
    if key == "return" or key == "space" then startRun() end
    if key == "c" then setState("characters") end
  elseif state == "characters" then
    local index = tonumber(key)
    if index and Config.characters[index] then Save.setCharacter(Config.characters[index].id) end
    if key == "escape" or key == "return" then setState("title") end
  elseif state == "howto" then
    if key == "escape" or key == "return" or key == "space" then setState("title") end
  elseif state == "inventory" then
    if key == "escape" or key == "i" or key == "tab" then setState(inventoryReturn) end
    return  -- never fall through to the pause toggle below
  elseif state == "playing" then
    if key == "i" or key == "tab" then openInventory("playing") end
  elseif state == "paused" then
    if key == "i" then openInventory("paused") end
  elseif state == "gameover" or state == "victory" then
    if (key == "return" or key == "space") and canRestart() then startRun() end
  elseif state == "levelup" then
    local index = tonumber(key)
    if index then chooseUpgrade(index) end
    if key == "r" then rerollUpgrades() end
  end

  if key == "escape" then togglePause() end
end

----------------------------------------------------------------------
-- Input: pointer (touch and mouse share one code path)
----------------------------------------------------------------------
local function pointerPressed(id, x, y)
  if state == "title" then
    local button = UI.menuButtonAt(x, y)
    if button == "start" then startRun()
    elseif button == "characters" then setState("characters")
    elseif button == "howto" then setState("howto") end
  elseif state == "characters" then
    local index = UI.characterCardAt(x, y)
    if index then
      Save.setCharacter(Config.characters[index].id)
    elseif UI.backButtonHit(x, y) then
      setState("title")
    end
  elseif state == "howto" then
    setState("title")
  elseif state == "inventory" then
    if UI.backButtonHit(x, y) then setState(inventoryReturn) end
  elseif state == "gameover" or state == "victory" then
    if canRestart() then startRun() end
  elseif state == "paused" then
    togglePause()
  elseif state == "levelup" then
    local index = UI.cardAt(#upgradeChoices, x, y)
    if index then
      chooseUpgrade(index)
    elseif UI.rerollButtonHit(x, y) then
      rerollUpgrades()
    end
  elseif state == "playing" then
    if UI.pauseButtonHit(x, y) then
      togglePause()
    elseif UI.inventoryButtonHit(x, y) then
      openInventory("playing")
    else
      Input.pressed(id, x, y)
    end
  end
end

function love.touchpressed(id, x, y) pointerPressed(id, x, y) end

function love.touchmoved(id, x, y) Input.moved(id, x, y) end

function love.touchreleased(id) Input.released(id) end

-- On phones LÖVE also emits fake mouse events for touches; `istouch` filters them out.
function love.mousepressed(x, y, button, istouch)
  if not istouch and button == 1 then pointerPressed("mouse", x, y) end
end

function love.mousemoved(x, y, _, _, istouch)
  if not istouch then Input.moved("mouse", x, y) end
end

function love.mousereleased(_, _, button, istouch)
  if not istouch and button == 1 then Input.released("mouse") end
end

-- Pause automatically when the app goes to the background (important on phones).
function love.focus(hasFocus)
  if not hasFocus and state == "playing" then togglePause() end
end
