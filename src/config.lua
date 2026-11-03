-- src/config.lua
-- Every tweakable number and every sprite definition lives here.
-- Want the game easier/harder? Edit this file, not the logic files.

local Config = {}

Config.debug = false -- F1 toggles: shows hitboxes, FPS and entity counts

-- The SHORTER side of the screen always shows `baseShortSide` game units.
-- So a portrait phone shows 540 units across, a landscape one 540 units tall,
-- and everything else follows the screen's aspect ratio (see src/view.lua).
Config.window = { baseShortSide = 540 }

----------------------------------------------------------------------
-- SPRITES
-- To replace a placeholder: put a PNG with the same file name into
-- assets/sprites/ (or change `file` below). `size` is the on-screen size
-- (longest side, in game units), so your image can be any resolution.
-- `shadow` draws a small ground shadow under the sprite (0 = none,
-- otherwise the shadow width as a fraction of `size`).
-- If a file is missing the game draws a coloured shape using `color`.
----------------------------------------------------------------------
Config.spriteFilter = "linear" -- use "nearest" if your new art is pixel art

Config.sprites = {
  player     = { file = "player.png", size = 56, shadow = 0.7, color = { 1.00, 0.60, 0.80 } },
  slime      = { file = "slime.png", size = 44, shadow = 0.8, color = { 0.45, 0.90, 0.65 } },
  bat        = { file = "bat.png", size = 44, shadow = 0.5, color = { 0.65, 0.45, 0.90 } },
  golem      = { file = "golem.png", size = 78, shadow = 0.8, color = { 0.65, 0.65, 0.72 } },
  wraith     = { file = "wraith.png", size = 52, shadow = 0.4, color = { 0.35, 0.85, 1.00 } },
  charger    = { file = "charger.png", size = 60, shadow = 0.7, color = { 1.00, 0.45, 0.25 } },
  boss       = { file = "boss.png", size = 150, shadow = 0.9, color = { 0.95, 0.20, 0.35 } },
  bolt       = { file = "bolt.png", size = 34, color = { 0.30, 0.80, 1.00 } },
  rocket     = { file = "rocket.png", size = 42, color = { 1.00, 0.45, 0.18 } },
  sword      = { file = "sword.png", size = 54, color = { 0.85, 0.88, 0.95 } },
  orb        = { file = "orb.png", size = 40, color = { 1.00, 0.55, 0.75 } },
  gem        = { file = "gem.png", size = 22, color = { 0.25, 0.90, 0.60 } },
  background = { file = "background.png", size = 128, color = { 0.18, 0.30, 0.23 }, shape = "rect" },
}

-- Optional sprite-sheet animations. If a sheet is missing, the normal sprite
-- above is used automatically.
Config.animations = {
  player = { file = "player_sheet.png", frames = 4, fps = 8, size = 56 },
  player_attack = { file = "player_attack_sheet.png", frames = 4, fps = 12, size = 56 },
  slash = { file = "slash_sheet.png", frames = 4, fps = 18, size = 200 },
  slime = { file = "slime_sheet.png", frames = 4, fps = 8, size = 44 },
  bat = { file = "bat_sheet.png", frames = 4, fps = 12, size = 44 },
  wraith = { file = "wraith_sheet.png", frames = 4, fps = 6, size = 52 },
  boss = { file = "boss_sheet.png", frames = 4, fps = 6, size = 150 },
}

----------------------------------------------------------------------
-- PLAYER
----------------------------------------------------------------------
Config.player = {
  maxHp       = 10,
  moveSpeed   = 200, -- units per second
  pickupRange = 800, -- gems inside this range fly towards the player
  radius      = 10,  -- hitbox
  invulnTime  = 0.5, -- seconds of invincibility after being hit
  regen       = 0,
  armor       = 0,
}



-- XP needed for the next level: first * growth^(level - 1)
Config.xp = { first = 2, growth = 1.05 }
Config.objectiveSeconds = 10 * 60

Config.upgradeChoiceCount = 5

----------------------------------------------------------------------
-- ENEMIES
-- `unlockTime`: seconds into the run before this enemy can spawn.
-- `weight`: relative spawn chance among unlocked enemies.
-- `sprite`: key from Config.sprites.
----------------------------------------------------------------------
Config.enemies = {
  slime   = {
    sprite = "slime",
    hp = 20,
    speed = 70,
    damage = 8,
    radius = 15,
    xp = 1,
    unlockTime = 0,
    weight = 10
  },
  bat     = {
    sprite = "bat",
    hp = 10,
    speed = 125,
    damage = 6,
    radius = 12,
    xp = 1,
    unlockTime = 90,
    weight = 6
  },
  golem   = { sprite = "golem", hp = 200, speed = 45, damage = 20, radius = 26, xp = 6, unlockTime = 120, weight = 2 },
  wraith  = { sprite = "wraith", hp = 42, speed = 95, damage = 13, radius = 17, xp = 3, unlockTime = 90, weight = 4 },
  charger = { sprite = "charger", hp = 75, speed = 175, damage = 24, radius = 20, xp = 5, unlockTime = 120, weight = 3 },
  boss    = { sprite = "boss", hp = 2000, speed = 38, damage = 35, radius = 52, xp = 40, unlockTime = 0, weight = 0, boss = true },
}

Config.spawn = {
  startInterval           = 7.0,   -- seconds between spawn waves at the start
  minInterval             = 0.08,  -- fastest spawn rate
  intervalShrinkPerSecond = 0.009, -- how fast the interval shrinks over time
  batchGrowthSeconds      = 45,    -- every N seconds each wave gets +1 enemy
  maxEnemies              = 300,
  margin                  = 80,    -- spawn this far outside the visible screen
  hpScalePerMinute        = 5,     -- enemies get +65% HP per minute survived
  bossInterval            = 90,
  bossHpScalePerMinute    = 0.35,
}

----------------------------------------------------------------------
-- WEAPO7S
-- Per-run changes (upgrades) are stored in player.stats, see upgrades.lua.
----------------------------------------------------------------------
Config.weapons = {
  bolt = {           -- auto-aimed projectile
    damage      = 30,
    cooldown    = 2, -- seconds between shots
    speed       = 500,
    lifetime    = 5,
    radius      = 8,
    targetRange = 550,  -- only fires at enemies this close
    spread      = 0.07, -- radians between bolts when firing several
    chainRange  = 170,  -- ricochet passive: how far a bolt bounce can reach
    burnDuration = 3,   -- ember passive: seconds a burn lasts
    burnTick    = 0.5,   -- ember passive: damage tick interval
  },
  rocket = {            -- auto-aimed explosive projectile
    damage          = 20,
    cooldown        = 5.0,
    speed           = 700,
    lifetime        = 10,
    radius          = 10,
    targetRange     = 700,
    explosionRadius = 76,
  },
  orbit = {            -- orbs circling the player
    damage      = 7000,
    radius      = 200, -- distance from the player
    rotateSpeed = 7.5, -- radians per second
    orbRadius   = 14,  -- hitbox of each orb
    hitCooldown = 0.1, -- seconds before the same enemy can be hit again
  },
  pulse = { cooldown = 5.5, damage = 22, radius = 170 },
  lightning = { cooldown = 7.0, damage = 55, targetRange = 620, chainRange = 150, chains = 3 },
  sword = {
    damage = 45, cooldown = 1.1, range = 95, arc = 2.0, swingTime = 0.18,
    waveDamageMult = 0.6,  -- the ranged slash wave hits for 60% of a swing
    waveSpeed = 520, waveRange = 340, waveRadius = 26,
  },
}

----------------------------------------------------------------------
-- TOUCH CONTROLS (virtual joystick appears where you touch the screen)
----------------------------------------------------------------------
Config.touch = {
  joystickRadius = 60, -- in game units
  deadzone       = 0.15,
}

-- Pause button in the top-right corner (needed on phones: no Esc key).
Config.pauseButton = { size = 48, margin = 12 }

-- After dying, taps are ignored for this long so you don't restart by accident.
Config.gameOverLockSeconds = 1.0

return Config
