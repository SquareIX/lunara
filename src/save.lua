-- src/save.lua
-- Stores the best survival time between sessions (a tiny text file in LÖVE's
-- save folder). Add more fields here later if you want more persistent data.

local Save = { bestTime = 0, character = "lunara" }

local FILE = "best.txt"
local CHAR_FILE = "character.txt"

function Save.load()
    if love.filesystem.getInfo(FILE) then
        Save.bestTime = tonumber(love.filesystem.read(FILE)) or 0
    end
    if love.filesystem.getInfo(CHAR_FILE) then
        local id = love.filesystem.read(CHAR_FILE)
        if id then Save.character = id:gsub("%s+", "") end
    end
end

-- Remember the character picked on the select screen.
function Save.setCharacter(id)
    Save.character = id
    love.filesystem.write(CHAR_FILE, id)
end

-- Call at the end of a run. Returns true if it is a new record.
function Save.submitTime(seconds)
    if seconds > Save.bestTime then
        Save.bestTime = seconds
        love.filesystem.write(FILE, tostring(seconds))
        return true
    end
    return false
end

return Save
