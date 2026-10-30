-- src/save.lua
-- Stores the best survival time between sessions (a tiny text file in LÖVE's
-- save folder). Add more fields here later if you want more persistent data.

local Save = { bestTime = 0 }

local FILE = "best.txt"

function Save.load()
    if love.filesystem.getInfo(FILE) then
        Save.bestTime = tonumber(love.filesystem.read(FILE)) or 0
    end
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
