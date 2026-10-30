local FloatingText = {}
FloatingText.__index = FloatingText

function FloatingText.new(x, y, text, color, critical)
    return setmetatable({x=x, y=y, text=tostring(text), color=color or {1,1,1}, life=0.75, critical=critical, dead=false}, FloatingText)
end

function FloatingText:update(dt)
    self.life = self.life - dt
    self.y = self.y - (self.critical and 34 or 24) * dt
    if self.life <= 0 then self.dead = true end
end

function FloatingText:draw()
    local alpha = math.min(1, self.life * 4)
    local font = love.graphics.newFont(self.critical and 22 or 17)
    love.graphics.setFont(font)
    local width = font:getWidth(self.text)
    love.graphics.setColor(0, 0, 0, alpha * 0.7)
    love.graphics.print(self.text, self.x - width / 2 + 2, self.y + 2)
    love.graphics.setColor(self.color[1], self.color[2], self.color[3], alpha)
    love.graphics.print(self.text, self.x - width / 2, self.y)
end

return FloatingText
