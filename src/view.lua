-- src/view.lua
-- Makes the game look the same on every screen size (desktop window, phone...).
-- The shorter screen side always shows `Config.window.baseShortSide` game units,
-- so it works in portrait and landscape.
--
-- All drawing code works in "game units"; UI and world apply View.scale().

local Config = require("src.config")

local View = {}

-- How many screen pixels one game unit takes up.
function View.scale()
    local shortSide = math.min(love.graphics.getWidth(), love.graphics.getHeight())
    return math.max(0.2, shortSide / Config.window.baseShortSide)
end

-- Visible area in game units: width, height.
function View.size()
    local s = View.scale()
    return love.graphics.getWidth() / s, love.graphics.getHeight() / s
end

function View.isPortrait()
    return love.graphics.getHeight() > love.graphics.getWidth()
end

return View
