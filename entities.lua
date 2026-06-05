local Config = require("config")
local WorldManager = require("world_manager")
local RopeSystem = require("rope")
local EffectsSystem = require("effects")
local Water = require("water")

local debugModeEnabled = false

local Entities = {
    player = nil,
    list = {}
}

function Entities.clear()
    Entities.player = nil
    Entities.list = {}
end

function Entities.setDebugMode(enabled)
    debugModeEnabled = enabled
end

function Entities.createPlayer(x, y)
    local cfg = Config.player
    local body = love.physics.newBody(WorldManager.world, x, y, "dynamic")
    local shape = love.physics.newRectangleShape(cfg.width, cfg.height)
    local fixture = love.physics.newFixture(body, shape, cfg.mass)
    fixture:setFriction(cfg.friction)
    fixture:setRestitution(cfg.restitution)
    
    Entities.player = {
        type = "player", body = body, shape = shape, fixture = fixture,
        w = cfg.width, h = cfg.height, particles = {}, ropeIds = {},
        health = cfg.maxHealth, maxHealth = cfg.maxHealth, damageFlash = 0, thrusterCooldown = 0
    }
    table.insert(Entities.list, Entities.player)
    return Entities.player
end

function Entities.createBox(x, y, w, h, angle, density, friction, label, Hp)
    local body = love.physics.newBody(WorldManager.world, x, y, "dynamic")
    local shape = love.physics.newRectangleShape(w, h)
    local fixture = love.physics.newFixture(body, shape, density or 1.0)
    fixture:setFriction(friction or 0.5)
    fixture:setRestitution(0.2)
    body:setAngle(angle or 0)
    
    local maxHp = Hp or 100
    local box = {
        type = "box", body = body, shape = shape, fixture = fixture,
        w = w, h = h, label = label or "Box", health = maxHp, maxHealth = maxHp,
        damageFlash = 0, ropeIds = {}, sliceDepth = 0
    }
    table.insert(Entities.list, box)
    return box
end

function Entities.createBall(x, y, r, angVel, density, friction)
    local body = love.physics.newBody(WorldManager.world, x, y, "dynamic")
    local shape = love.physics.newCircleShape(r)
    local fixture = love.physics.newFixture(body, shape, density or 1.0)
    fixture:setFriction(friction or 0.5)
    fixture:setRestitution(0.3)
    if angVel then body:setAngularVelocity(angVel) end
    
    local maxHp = math.max(10, math.floor((math.pi * r * r * (density or 1.0)) / 4))
    local ball = {
        type = "ball", body = body, shape = shape, fixture = fixture,
        r = r, health = maxHp, maxHealth = maxHp, damageFlash = 0, ropeIds = {}
    }
    table.insert(Entities.list, ball)
    return ball
end

function Entities.createEnemy(x, y, w, h, angle)
    local cfg = Config.enemy
    local body = love.physics.newBody(WorldManager.world, x, y, "dynamic")
    local shape = love.physics.newRectangleShape(w, h)
    local fixture = love.physics.newFixture(body, shape, cfg.mass)
    fixture:setFriction(cfg.friction)
    fixture:setRestitution(cfg.restitution)
    
    local maxHp = math.max(10, math.floor((w * h) / 3))
    local enemy = {
        type = "enemy", body = body, shape = shape, fixture = fixture,
        w = w, h = h, particles = {}, ropeIds = {}, health = maxHp, maxHealth = maxHp,
        damageFlash = 0, thrusterCooldown = 0
    }
    table.insert(Entities.list, enemy)
    return enemy
end

function Entities.update(dt)
    if not Entities.player or not Entities.player.body or Entities.player.body:isDestroyed() then return end
    
    local p = Entities.player
    if p.damageFlash then p.damageFlash = math.max(0, p.damageFlash - dt) end
    p.thrusterCooldown = math.max(0, (p.thrusterCooldown or 0) - dt)
    
    local bx, by = p.body:getWorldPoint(0, p.h / 2)
    local thrusting = false
    local pCfg = Config.player
    
    if love.keyboard.isDown("right") then 
        p.body:applyForce(pCfg.moveForceX, 0)
        if p.thrusterCooldown <= 0 then
            EffectsSystem.createParticle(bx - 5, by, -30, love.math.random(-10, 10), 30, 200, 0.8, "thruster")
            p.thrusterCooldown = pCfg.thrusterCooldown
        end
        thrusting = true
    end
    if love.keyboard.isDown("left") then 
        p.body:applyForce(-pCfg.moveForceX, 0)
        if p.thrusterCooldown <= 0 then
            EffectsSystem.createParticle(bx + 5, by, 30, love.math.random(-10, 10), 30, 200, 0.8, "thruster")
            p.thrusterCooldown = pCfg.thrusterCooldown
        end
        thrusting = true
    end
    if love.keyboard.isDown("up") then 
        p.body:applyForce(0, pCfg.moveForceYUp)
        if p.thrusterCooldown <= 0 then
            for i = 1, 3 do
                EffectsSystem.createParticle(bx, by + 10, love.math.random(-15, 15), -40 - love.math.random(0, 20), 30, 200, 0.5 + love.math.random(), "thruster")
            end
            p.thrusterCooldown = 0.02
        end
        thrusting = true
    end    
    
    if love.keyboard.isDown("l") then 
        p.body:applyForce(0, pCfg.moveForceYUp*5)
        if p.thrusterCooldown <= 0 then
            for i = 1, 3 do
                EffectsSystem.createParticle(bx, by + 10, love.math.random(-30, 30), -40 - love.math.random(0, 30), 30, 200, 0.5 + love.math.random(), "thruster")
            end
            p.thrusterCooldown = 0.05
        end
        thrusting = true
    end
    
    if love.keyboard.isDown("down") then 
        p.body:applyForce(0, pCfg.moveForceYDown)
        if p.thrusterCooldown <= 0 then
            EffectsSystem.createParticle(bx, by - 10, love.math.random(-15, 15), 30 + love.math.random(0, 20), 30, 200, 0.8, "thruster")
            p.thrusterCooldown = pCfg.thrusterCooldown
        end
        thrusting = true
    end
    if not thrusting and love.math.random() < 0.02 then
        EffectsSystem.createParticle(bx, by, love.math.random(-5, 5), love.math.random(-2, 2), 20, 150, 1, "smoke")
    end
    
    p.body:applyTorque(-p.body:getAngle() * pCfg.torqueForce - p.body:getAngularVelocity() * 2.5)
    if love.keyboard.isDown("pageup") then p.body:applyTorque(-pCfg.torqueForce) end
    if love.keyboard.isDown("pagedown") then p.body:applyTorque(pCfg.torqueForce) end
    

    local px, py = p.body:getPosition()
    local waterArea = Water.isPointInWater(px, py)
    if waterArea then
        -- Apply water drag correctly
        local vx, vy = p.body:getLinearVelocity()
        local resistance = waterArea.viscousDrag * 0.5
        p.body:applyForce(-vx * resistance, -vy * resistance)
    end

    local pX, pY = p.body:getPosition()
    local eCfg = Config.enemy
    
    for i = #Entities.list, 1, -1 do
        local e = Entities.list[i]
        if e.body and e.body:isDestroyed() then
            table.remove(Entities.list, i)
        elseif e.body and e.body:isActive() then
            if e.damageFlash then e.damageFlash = math.max(0, e.damageFlash - dt) end
            
            if e.type == "enemy" then
                local ex, ey = e.body:getPosition()
                local dx, dy = pX - ex, pY - ey
                e.thrusterCooldown = math.max(0, (e.thrusterCooldown or 0) - dt)
                
                local fMag = math.sqrt(dx^2 + dy^2)
                if fMag > 0 then
                    local scale = math.min(eCfg.maxForce / fMag, eCfg.trackingScale)
                    e.body:applyForce(dx * scale * fMag, dy * scale * fMag)
                end
                
                local vx, vy = e.body:getLinearVelocity()
                local speed = math.sqrt(vx^2 + vy^2)
                if speed > 20 and e.thrusterCooldown <= 0 then
                    local ang = math.atan2(vy, vx)
                    local backX = ex - math.cos(ang) * (e.w / 2)
                    local backY = ey - math.sin(ang) * (e.h / 2)
                    EffectsSystem.createParticle(backX, backY, -vx * 0.3 + love.math.random(-10, 10), -vy * 0.3 + love.math.random(-10, 10), 20, 250, 1.5, "enemy_thruster")
                    e.thrusterCooldown = eCfg.thrusterCooldown
                end
                e.body:applyTorque(-e.body:getAngle() * 30 - e.body:getAngularVelocity() * 2.5)
            end
        end
    end
end

function Entities.grab(isEnemyOnly)
    local p = Entities.player
    if not p or #(p.ropeIds or {}) >= 2 then return end
    
    local px, py = p.body:getWorldPoint(0, p.h / 2)
    local closest, minDist = nil, Config.enemy.grabRadius
    
    for _, e in ipairs(Entities.list) do
        if e.body and not e.body:isDestroyed() and e ~= p then
            local valid = not isEnemyOnly or (isEnemyOnly and e.type == "enemy")
            if valid and not RopeSystem.connects(p, e) then
                local ox, oy = e.body:getPosition()
                local dist = math.sqrt((px-ox)^2 + (py-oy)^2)
                if dist < minDist then
                    minDist = dist
                    closest = e
                end
            end
        end
    end
    if closest then RopeSystem.create(p, closest) end
end

function Entities.applyDamage(e, dmg)
    if not e or not e.health or e.body:isDestroyed() then return end
    if e.type == "box" and e.sliceDepth then
        dmg = dmg * math.pow(0.85, e.sliceDepth)
    end
    
    e.health = e.health - dmg
    e.damageFlash = 0.2
    
    if e.health <= 0 then 
        Entities.destroy(e) 
    end
end

function Entities.destroy(e)
    if not e or not e.body or e.body:isDestroyed() then return end
    
    RopeSystem.destroyAllForObject(e)
    if e.type == "box" then 
        Entities.sliceBox(e) 
    else
        -- Non-box entities (like enemies or balls) just disintegrate
        local ex, ey = e.body:getPosition()
        EffectsSystem.createDamageEffect(ex - 15, ey, ex + 15, ey)
    end
    e.body:destroy()
end

function Entities.mergeBoxesTouchingPlayer(player)
    if not player or not player.body then return end

    -- Find all boxes in contact with the player
    local contacts = WorldManager.world:getContacts()
    local boxesToMerge = {}
    local seen = {}

    for _, contact in ipairs(contacts) do
        if contact:isEnabled() then
            local fa, fb = contact:getFixtures()
            if fa and fb then
                local bodyA = fa:getBody()
                local bodyB = fb:getBody()
                local isPlayerA = (bodyA == player.body)
                local isPlayerB = (bodyB == player.body)
                if isPlayerA or isPlayerB then
                    local otherBody = isPlayerA and bodyB or bodyA
                    -- Find the entity from the body
                    for _, ent in ipairs(Entities.list) do
                        if ent.body == otherBody and ent.type == "box" and not seen[ent] then
                            table.insert(boxesToMerge, ent)
                            seen[ent] = true
                        end
                    end
                end
            end
        end
    end

    if #boxesToMerge == 0 then return end

    -- Compute total area, total health, area‑weighted centroid, sum of widths & heights
    local totalArea = 0
    local totalHealth = 0
    local weightedX, weightedY = 0, 0
    local sumWidth = 0
    local sumHeight = 0
    local count = 0

    for _, box in ipairs(boxesToMerge) do
        local area = box.w * box.h
        totalArea = totalArea + area
        totalHealth = totalHealth + box.health
        local x, y = box.body:getPosition()
        weightedX = weightedX + x * area
        weightedY = weightedY + y * area
        sumWidth = sumWidth + box.w
        sumHeight = sumHeight + box.h
        count = count + 1
    end

    if count == 0 then return end

    local centroidX = weightedX / totalArea
    local centroidY = weightedY / totalArea

    -- Determine new dimensions preserving average aspect ratio
    local avgAspect = (sumWidth / count) / (sumHeight / count)
    local newWidth = math.sqrt(totalArea * avgAspect)
    local newHeight = math.sqrt(totalArea / avgAspect)

    -- Ensure minimum size
    newWidth = math.max(5, newWidth)
    newHeight = math.max(5, newHeight)

    -- Destroy the old boxes and their ropes
    for _, box in ipairs(boxesToMerge) do
        RopeSystem.destroyAllForObject(box)
        box.body:destroy()
        -- Remove from Entities.list
        for i, e in ipairs(Entities.list) do
            if e == box then
                table.remove(Entities.list, i)
                break
            end
        end
    end

    -- Create the merged box (dynamic, default density 1.0, friction 0.5)
    local newBox = Entities.createBox(centroidX, centroidY, newWidth, newHeight, 0, 1.0, 0.5, "Merged")
    newBox.health = totalHealth
    newBox.maxHealth = totalHealth
    newBox.damageFlash = 0

    -- Optional: add a flash effect at the new box location
    local EffectsSystem = require("effects")
    EffectsSystem.createDamageEffect(centroidX - newWidth/2, centroidY - newHeight/2,
                                     centroidX + newWidth/2, centroidY + newHeight/2, true)

    return newBox
end

function Entities.sliceBox(box)
    if not box or box.type ~= "box" then return end
    
    local currentDepth = box.sliceDepth or 0
    if currentDepth >= 10 then return end
    
    local x, y = box.body:getPosition()
    local angle = box.body:getAngle()
    local w, h = box.w, box.h
    local sliceVert = (w >= h)
    
    local w1, w2, h1, h2, offset
    if sliceVert then
        offset = w * (0.3 + love.math.random() * 0.4)
        w1, w2, h1, h2 = offset, w - offset, h, h
    else
        offset = h * (0.3 + love.math.random() * 0.4)
        w1, w2, h1, h2 = w, w, offset, h - offset
    end
    
    if w1 < 5 or w2 < 5 or h1 < 5 or h2 < 5 then return end
    
    local localSlice = sliceVert and {x = -w/2 + offset, y = 0} or {x = 0, y = -h/2 + offset}
    local cosA, sinA = math.cos(angle), math.sin(angle)
    local wx = x + (localSlice.x * cosA - localSlice.y * sinA)
    local wy = y + (localSlice.x * sinA + localSlice.y * cosA)
    
    local sliceStartX, sliceStartY, sliceEndX, sliceEndY
    if sliceVert then
        local halfH = h / 2
        sliceStartX = wx - halfH * -sinA
        sliceStartY = wy - halfH * cosA
        sliceEndX = wx + halfH * -sinA
        sliceEndY = wy + halfH * cosA
    else
        local halfW = w / 2
        sliceStartX = wx - halfW * cosA
        sliceStartY = wy - halfW * sinA
        sliceEndX = wx + halfW * cosA
        sliceEndY = wy + halfW * sinA
    end
    
    -- TRIGGER CUT LINE VISUAL EXACTLY ON THE SLICE PLANE
    EffectsSystem.createDamageEffect(sliceStartX, sliceStartY, sliceEndX, sliceEndY)
    
    local numSparks = 16
    for i = 1, numSparks do
        local t = love.math.random()
        local sparkX = sliceStartX + (sliceEndX - sliceStartX) * t
        local sparkY = sliceStartY + (sliceEndY - sliceStartY) * t
        
        local angleRad = math.atan2(sliceEndY - sliceStartY, sliceEndX - sliceStartX)
        local perpAngle = angleRad + math.pi/2 + (love.math.random() - 0.5) * 1.2
        local speed = love.math.random(40, 100)
        local vx = math.cos(perpAngle) * speed + love.math.random(-10, 10)
        local vy = math.sin(perpAngle) * speed + love.math.random(-10, 10)
        
        EffectsSystem.createParticle(sparkX, sparkY, vx, vy, 20, 350, 2.5, "orangeSpark")
    end
    
    for i = 1, 12 do
        local t = love.math.random()
        local sparkX = sliceStartX + (sliceEndX - sliceStartX) * t
        local sparkY = sliceStartY + (sliceEndY - sliceStartY) * t
        
        local angleRad = math.atan2(sliceEndY - sliceStartY, sliceEndX - sliceStartX)
        local perpAngle = angleRad + math.pi/2 + (love.math.random() - 0.5) * 1.5
        local speed = love.math.random(20, 60)
        local vx = math.cos(perpAngle) * speed
        local vy = math.sin(perpAngle) * speed
        
        EffectsSystem.createParticle(sparkX, sparkY, vx, vy, 15, 300, 3, "ember")
    end
    
    for i = 1, 8 do
        local t = love.math.random()
        local sparkX = sliceStartX + (sliceEndX - sliceStartX) * t
        local sparkY = sliceStartY + (sliceEndY - sliceStartY) * t
        
        local vx = love.math.random(-20, 20)
        local vy = love.math.random(-30, 0)
        
        EffectsSystem.createParticle(sparkX, sparkY, vx, vy, 25, 150, 4, "smoke")
    end
    
    local x1, y1, x2, y2
    if sliceVert then
        x1, y1 = x + (-w/2 + w1/2) * cosA, y + (-w/2 + w1/2) * sinA
        x2, y2 = wx + (w/2 - w2/2) * cosA, wy + (w/2 - w2/2) * sinA
    else
        x1, y1 = x + (-h/2 + h1/2) * -sinA, y + (-h/2 + h1/2) * cosA
        x2, y2 = wx + (h/2 - h2/2) * -sinA, wy + (h/2 - h2/2) * cosA
    end
    
    local depth = currentDepth + 1
    local d, f = box.fixture:getDensity(), box.fixture:getFriction()
    local lbl = box.label or "Box"
    
    local healthMultiplier = 1.05
    local newArea1 = w1 * h1
    local newArea2 = w2 * h2
    local baseHealthPerArea = 2.5
    
    local newHealth1 = math.max(10, math.floor(newArea1 * baseHealthPerArea * math.pow(healthMultiplier, depth)))
    local newHealth2 = math.max(10, math.floor(newArea2 * baseHealthPerArea * math.pow(healthMultiplier, depth)))
    
    local b1 = Entities.createBox(x1, y1, w1, h1, angle, d, f, string.format("%s_A%d", lbl, depth))
    local b2 = Entities.createBox(x2, y2, w2, h2, angle, d, f, string.format("%s_B%d", lbl, depth))
    b1.sliceDepth = depth
    b2.sliceDepth = depth
    b1.maxHealth = newHealth1
    b1.health = newHealth1
    b2.maxHealth = newHealth2
    b2.health = newHealth2
    
    local vx, vy = box.body:getLinearVelocity()
    local av = box.body:getAngularVelocity()
    b1.body:setLinearVelocity(vx + love.math.random(-20,20), vy + love.math.random(-20,20))
    b2.body:setLinearVelocity(vx + love.math.random(-20,20), vy + love.math.random(-20,20))
    b1.body:setAngularVelocity(av + love.math.random(-0.5,0.5))
    b2.body:setAngularVelocity(av + love.math.random(-0.5,0.5))
end

function Entities.checkCollisions()
    local p = Entities.player
    if not p or not p.body or p.body:isDestroyed() then return end
    local px, py = p.body:getPosition()
    
    for _, e in ipairs(Entities.list) do
        if e.body and not e.body:isDestroyed() and e ~= p and e.body:isActive() then
            local ex, ey = e.body:getPosition()
            local dist = math.sqrt((px-ex)^2 + (py-ey)^2)
            
            if e.type == "enemy" and dist < 30 then
                Entities.applyDamage(e, 10)
            elseif e.type == "box" and dist < 40 then
                Entities.applyDamage(e, 5)
            end
        end
    end
end

function Entities.draw()
    for _, e in ipairs(Entities.list) do
        if e.body and not e.body:isDestroyed() and e.body:isActive() then
            if e.damageFlash and e.damageFlash > 0 then
                local intensity = math.sin(e.damageFlash * 30) * 0.5 + 0.5
                if e.type == "box" or e.type == "ball" then
                    love.graphics.setColor(0, 0, 0, intensity)
                else
                    love.graphics.setColor(1, intensity, intensity)
                end
            else
                love.graphics.setColor(0, 0, 0)
            end
            
            local x, y = e.body:getPosition()
            if e.type == "ball" then
                love.graphics.setLineWidth(3)
                love.graphics.circle("line", x, y, e.r)
                local cosA, sinA = math.cos(e.body:getAngle()), math.sin(e.body:getAngle())
                love.graphics.line(x - e.r * cosA, y - e.r * sinA, x + e.r * cosA, y + e.r * sinA)
                love.graphics.line(x - e.r * sinA, y + e.r * cosA, x + e.r * sinA, y - e.r * cosA)
                love.graphics.setLineWidth(1)
            else
                love.graphics.polygon("fill", e.body:getWorldPoints(e.shape:getPoints()))
            end
            
            if debugModeEnabled and e.health and e.health < e.maxHealth then
                local pct = e.health / e.maxHealth
                local offsetY = (e.h or e.r*2) + 5
                love.graphics.setColor(1, 0, 0)
                love.graphics.rectangle("fill", x - 15, y - offsetY, 30, 4)
                love.graphics.setColor(0, 1, 0)
                love.graphics.rectangle("fill", x - 15, y - offsetY, 30 * pct, 4)
            end
            
            if e.type == "player" then
                love.graphics.setColor(0, 1, 0, 0.5)
                love.graphics.print("$", x - 4, y - 4)
            elseif e.type == "enemy" then
                love.graphics.setColor(1, 0, 0, 0.5)
                love.graphics.print("E", x - 4, y - 4)
            end
        end
    end
end

return Entities