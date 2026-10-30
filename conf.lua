-- conf.lua
-- Runs before the game starts. Only window / module settings live here.
-- Gameplay numbers belong in src/config.lua.

function love.conf(t)
    t.identity = "survivor"            -- save-folder name
    t.version = "11.5"
    t.window.title = "Survivor"
    t.window.width = 450               -- desktop window = a portrait phone preview.
    t.window.height = 800              -- (on phones LÖVE uses the real screen size)
    t.window.resizable = true
    t.window.vsync = 1
    t.window.highdpi = true

    t.modules.joystick = false         -- not needed, saves startup time
    t.modules.physics = false
    t.modules.video = false
    t.modules.thread = false
end
