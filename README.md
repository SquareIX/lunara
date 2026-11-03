# Survivor (LÖVE 11.x)

A small "survivor" game (think Vampire Survivors): move around, weapons fire
automatically, collect gems, level up, pick upgrades, survive as long as you can.
Built for **phones first** (touch joystick, portrait or landscape) and playable
on desktop with a keyboard. Art is anime-styled **placeholder** sprites you can replace.

## Run it

```
love .            # from this folder (install LÖVE 11.4+ from love2d.org)
```

| Input | Action |
|---|---|
| Drag on screen (touch / mouse) | floating virtual joystick |
| WASD / arrows | move |
| Esc or pause button | pause |
| I / Tab or bag button | inventory (equipment) |
| C (on title) | character select |
| 1 / 2 / 3 or tap a card | choose upgrade |
| F1 | debug overlay (hitboxes, FPS, counts) |
| F5 | reload sprites from disk without restarting |

## Project layout

```
main.lua            game states + forwards LÖVE callbacks (start here)
conf.lua            window / module settings
src/
  config.lua        ALL numbers: sprites, enemies, weapons, spawn rates, controls
  world.lua         one run: spawning, update order, camera, draw order
  weapons.lua       bolt (auto-aim) and orbit (orbs around you)
  upgrades.lua      level-up choices
  input.lua         keyboard + touch joystick -> movement vector
  ui.lua            HUD, menus, level-up cards, pause button
  assets.lua        loads sprites, falls back to coloured shapes if a PNG is missing
  view.lua          screen scaling (same look on every phone)
  save.lua          best time (saved between sessions)
  util.lua          small math helpers
  entities/         player, enemy, projectile, gem
assets/sprites/     the PNG placeholders
tools/generate_placeholder_sprites.py   regenerates the placeholders
```

Rule of thumb: **numbers go in `config.lua`, rules go in the other files.**

## Replacing the placeholder art

1. Make your PNG (any resolution, transparent background, character facing **right**).
2. Save it over the file in `assets/sprites/` with the same name (e.g. `slime.png`).
3. Press **F5** in the game. Done.

Each sprite is scaled to the `size` set in `Config.sprites` (src/config.lua),
so you never need to match the old resolution. Change `size` if your art should
appear bigger or smaller. For pixel art set `Config.spriteFilter = "nearest"`.
If a PNG is missing the game draws a coloured circle instead, so nothing crashes.

Sprites used: `player, aiko, momo, slime, bat, golem, wraith, charger, boss, bolt, rocket, orb, gem, sword, helmet, chest, boots, amulet, menu_bg, background`
(`background` is a tile that repeats forever; make it tileable).
Animation sheets: `player_sheet` (walk cycle), `player_attack_sheet` (sword swing)
and `slash_sheet` (the sword's slash effect), plus walk/flap/float cycles for
the enemies: `slime_sheet`, `bat_sheet`, `wraith_sheet`, `boss_sheet`, and walk
+ attack sheets for the other characters: `aiko_sheet`, `aiko_attack_sheet`,
`momo_sheet`, `momo_attack_sheet`. Any character or enemy without a sheet
simply uses its static sprite as before.

## Menus, characters and equipment

The title screen is a main menu (Start / Characters / How to Play) over
`menu_bg` art. Three survivors are playable (Lunara, Aiko the Blade Dancer,
Momo the Bulwark), picked on the character screen; the choice is remembered.
Enemies drop equipment for four slots (helmet, chest, boots, amulet) in three
rarities; drops auto-equip when stronger and scrap into XP when weaker.
Golden elite enemies (3% of spawns) are much tougher and drop loot often.

To regenerate the placeholders: `pip install pillow && python3 tools/generate_placeholder_sprites.py`

## Common changes

- **Easier / harder:** edit `Config.player`, `Config.enemies`, `Config.spawn`.
- **New enemy:** add a PNG + one line in `Config.sprites` and one in `Config.enemies`. No code needed.
- **New upgrade:** add an entry to `Upgrades.list` in `src/upgrades.lua`.
- **New weapon:** copy the `bolt` or `orbit` table in `src/weapons.lua`, add it to
  `Weapons.list`, put its numbers in `Config.weapons`, add a stat to `player.stats`
  and an upgrade that raises it.
- **New game state** (e.g. shop): add a state name in `main.lua`, a `UI.draw...` function,
  and handle it in `love.update/draw/pointerPressed`.

## Getting it on a phone

- **Fastest test (Android):** install "LÖVE for Android" from Google Play, then open `survivor.love`.
  Create it with: `zip -9 -r survivor.love . -x "tools/*" "*.md" ".git/*"`
- **A real APK:** use [love-android](https://github.com/love2d/love-android); put this folder's
  contents in `app/src/embed/assets/` (rename to `game`). Set `android:screenOrientation`
  in `AndroidManifest.xml` to `portrait` or `landscape` if you want to lock rotation.
- **iOS:** build with the LÖVE iOS project in Xcode and add the folder as a resource.
- Touch input, scaling and auto-pause when the app loses focus are already handled.

## Performance notes

Enemy count is capped by `Config.spawn.maxEnemies` (300). If an old phone stutters,
lower it to ~150. Collision uses simple circle checks, which is fine at this scale; if you
raise the cap a lot, add a spatial grid in `world.lua`.
