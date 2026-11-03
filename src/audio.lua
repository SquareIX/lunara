-- Temporary procedural audio. Replace this module's generated sounds with
-- your own sources later without changing gameplay code.
local Audio = { sounds = {}, music = {}, mode = nil }
local RATE = 22050

local function tone(frequency, seconds, volume, wobble)
    local data = love.sound.newSoundData(math.floor(RATE * seconds), RATE, 16, 1)
    for i = 0, data:getSampleCount() - 1 do
        local t = i / RATE
        local envelope = math.min(1, t * 45) * math.min(1, (seconds - t) * 12)
        local wave = math.sin(math.pi * 2 * frequency * t + math.sin(t * 8) * (wobble or 0))
        data:setSample(i, wave * volume * envelope)
    end
    return love.audio.newSource(data, "static")
end

local function theme(notes, seconds)
    local data = love.sound.newSoundData(math.floor(RATE * seconds), RATE, 16, 1)
    for i = 0, data:getSampleCount() - 1 do
        local t = i / RATE
        local note = notes[(math.floor(t * 2) % #notes) + 1]
        data:setSample(i, math.sin(math.pi * 2 * note * t) * 0.16 + math.sin(math.pi * 4 * note * t) * 0.05)
    end
    local source = love.audio.newSource(data, "static")
    source:setLooping(true)
    source:setVolume(0.28)
    return source
end

function Audio.load()
    Audio.sounds = {
        bolt = tone(720, 0.07, 0.18, 0.2), rocket = tone(120, 0.22, 0.25, 1.5),
        orbit = tone(980, 0.045, 0.12, 0.4), pulse = tone(180, 0.24, 0.28, 2.0),
        lightning = tone(1500, 0.16, 0.22, 3.0),
        sword = tone(340, 0.12, 0.2, 2.5),
        hit = tone(160, 0.05, 0.14, 0.5), die = tone(95, 0.18, 0.2, 1.2),
        pickup = tone(1250, 0.05, 0.09, 0.3), levelup = tone(880, 0.28, 0.16, 1.0),
        boom = tone(70, 0.3, 0.3, 1.5), loot = tone(1560, 0.14, 0.14, 0.8),
    }
    Audio.music = { normal = theme({220, 277, 330, 277}, 8), boss = theme({110, 123, 146, 98}, 8) }
end

function Audio.play(name)
    local source = Audio.sounds[name]
    if source then source:stop(); source:play() end
end

function Audio.setMusic(name)
    if Audio.mode == name then return end
    for _, source in pairs(Audio.music) do source:stop() end
    if Audio.music[name] then Audio.music[name]:play() end
    Audio.mode = name
end

function Audio.update(world)
    local boss = false
    for _, enemy in ipairs(world.enemies) do
        if not enemy.dead and enemy.isBoss then boss = true; break end
    end
    Audio.setMusic(boss and "boss" or "normal")
end

return Audio
