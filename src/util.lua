-- src/util.lua
-- Small helper functions shared by many modules.

local Util = {}

function Util.clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

function Util.distance(ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    return math.sqrt(dx * dx + dy * dy)
end

-- Returns a unit-length version of (x, y), or (0, 0) if the vector is empty.
function Util.normalize(x, y)
    local length = math.sqrt(x * x + y * y)
    if length == 0 then return 0, 0 end
    return x / length, y / length
end

function Util.circlesOverlap(ax, ay, ar, bx, by, br)
    local dx, dy = bx - ax, by - ay
    local r = ar + br
    return dx * dx + dy * dy <= r * r
end

-- Removes every entry with `dead == true` from a list, keeping order.
function Util.removeDead(list)
    local kept = 0
    for i = 1, #list do
        local item = list[i]
        if not item.dead then
            kept = kept + 1
            list[kept] = item
        end
    end
    for i = #list, kept + 1, -1 do
        list[i] = nil
    end
end

-- In-place Fisher-Yates shuffle.
function Util.shuffle(list)
    for i = #list, 2, -1 do
        local j = love.math.random(i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end

return Util
