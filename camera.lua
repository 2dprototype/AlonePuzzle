local Config = require("config")
local Camera = {
    x = 0, y = 0, scale = 1,
    mode = "follow_player",
    target = nil
}

function Camera.update(dt, player, enemies)
    local cfg = Config.camera
    if Camera.mode == "follow_player" and player and player.body and not player.body:isDestroyed() then
        local targetX, targetY = player.body:getPosition()
        Camera.x = Camera.x + (targetX - Camera.x) * cfg.lerpSpeed
        Camera.y = Camera.y + (targetY - Camera.y) * cfg.lerpSpeed
    elseif Camera.mode == "follow_enemy" then
        local enemy = enemies[1]
        if enemy and enemy.body and not enemy.body:isDestroyed() then
            local targetX, targetY = enemy.body:getPosition()
            Camera.x = Camera.x + (targetX - Camera.x) * cfg.lerpSpeed
            Camera.y = Camera.y + (targetY - Camera.y) * cfg.lerpSpeed
        end
    elseif Camera.mode == "free_move" then
        local speed = cfg.freeSpeed * dt / Camera.scale
        if love.keyboard.isDown("w") then Camera.y = Camera.y - speed end
        if love.keyboard.isDown("s") then Camera.y = Camera.y + speed end
        if love.keyboard.isDown("a") then Camera.x = Camera.x - speed end
        if love.keyboard.isDown("d") then Camera.x = Camera.x + speed end
    end
end

function Camera.apply()
    love.graphics.translate(love.graphics.getWidth() / 2, love.graphics.getHeight() / 2)
    love.graphics.scale(Camera.scale)
    love.graphics.translate(-Camera.x, -Camera.y)
end

function Camera:screenToWorld(screenX, screenY)
    local worldX = (screenX - love.graphics.getWidth() / 2) / self.scale + self.x
    local worldY = (screenY - love.graphics.getHeight() / 2) / self.scale + self.y
    return worldX, worldY
end

return Camera