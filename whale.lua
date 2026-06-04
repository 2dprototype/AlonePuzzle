-- whale.lua
local Whale = {
    whales = {},
    nextId = 1
}

-- Whale species with unique physical traits and behaviors
local whaleTypes = {
    gentle = {
        name = "Blue Whale",
        color = {0.15, 0.25, 0.45},
        bellyColor = {0.3, 0.4, 0.6},
        speed = 400,          -- Thrust force
        turnSpeed = 1.5,      -- How fast they can rotate
        mass = 1200,
        health = 500,
        damage = 0,
        friendly = true,
        w = 120, h = 40,
        tailSize = 25,
        dorsalSize = 5
    },
    aggressive = {
        name = "Orca",
        color = {0.05, 0.05, 0.08}, -- Black
        bellyColor = {0.9, 0.9, 0.95}, -- White
        speed = 800,
        turnSpeed = 4.0,
        mass = 450,
        health = 250,
        damage = 30,
        friendly = false,
        w = 70, h = 25,
        tailSize = 18,
        dorsalSize = 20
    },
    baby = {
        name = "Calf",
        color = {0.25, 0.35, 0.55},
        bellyColor = {0.4, 0.5, 0.7},
        speed = 300,
        turnSpeed = 2.5,
        mass = 150,
        health = 100,
        damage = 0,
        friendly = true,
        w = 40, h = 15,
        tailSize = 10,
        dorsalSize = 3
    }
}

-- Create a whale
function Whale.create(x, y, whaleType)
    local WorldManager = require("world_manager")
    local typeData = whaleTypes[whaleType] or whaleTypes.gentle
    
    -- Create physics body
    local body = love.physics.newBody(WorldManager.world, x, y, "dynamic")
    -- Use a pill/capsule shape for better aquatic collision
    local shape = love.physics.newRectangleShape(typeData.w * 0.8, typeData.h * 0.8)
    local fixture = love.physics.newFixture(body, shape, typeData.mass)
    
    -- Low friction, high damping so they glide smoothly
    fixture:setFriction(0.1)
    fixture:setRestitution(0.2)
    body:setLinearDamping(0.8)  -- Water drag
    body:setAngularDamping(2.0) -- Prevents spinning out of control
    
    local whale = {
        id = Whale.nextId,
        type = "whale",
        whaleType = whaleType,
        body = body,
        shape = shape,
        fixture = fixture,
        data = typeData,
        
        -- Vitals
        health = typeData.health,
        maxHealth = typeData.health,
        damageFlash = 0,
        
        -- Animation State
        animPhase = love.math.random() * math.pi * 2,
        tailAngle = 0,
        inWater = true,
        blowholeTimer = 0,
        
        -- AI State
        state = "swim",
        targetX = x,
        targetY = y,
        waypointTimer = 0,
        lastAttackTime = 0,
        attackCooldown = 1.5
    }
    
    table.insert(Whale.whales, whale)
    Whale.nextId = Whale.nextId + 1
    
    return whale
end

function Whale.update(dt, player, entities)
    local Water = require("water")
    local EffectsSystem = require("effects")
    
    for i = #Whale.whales, 1, -1 do
        local w = Whale.whales[i]
        
        if not w.body or w.body:isDestroyed() then
            table.remove(Whale.whales, i)
            goto continue
        end
        
        if w.damageFlash > 0 then
            w.damageFlash = math.max(0, w.damageFlash - dt)
        end
        
        local wx, wy = w.body:getPosition()
        local vx, vy = w.body:getLinearVelocity()
        local currentSpeed = math.sqrt(vx^2 + vy^2)
        local waterArea = Water.isPointInWater(wx, wy)
        
        -- Surface breathing / Blowhole mechanic
        local wasInWater = w.inWater
        w.inWater = (waterArea ~= nil)
        
        if not wasInWater and w.inWater then
            -- Create a big splash when falling back into water
            Water.createSplash(wx, wy, currentSpeed)
        elseif wasInWater and not w.inWater and w.blowholeTimer <= 0 then
            -- Blow spout when breaching the surface
            w.blowholeTimer = 5.0 -- Cooldown for blowing water
            for b = 1, 15 do
                EffectsSystem.createParticle(
                    wx, wy - w.data.h/2, 
                    love.math.random(-20, 20), love.math.random(-150, -50), 
                    10, 255, 1.5, "water"
                )
            end
        end
        
        if w.blowholeTimer > 0 then
            w.blowholeTimer = w.blowholeTimer - dt
        end
        
        -- Procedural Animation update
        -- Tail wags faster when moving faster
        local wagSpeed = math.max(2, currentSpeed * 0.02)
        w.animPhase = w.animPhase + (dt * wagSpeed)
        w.tailAngle = math.sin(w.animPhase) * 0.4 -- 0.4 radians max wag
        
        -- AI Update
        if w.inWater then
            Whale.updateAI(w, dt, player, waterArea)
        else
            -- Gravity takes over in the air, minimal steering
            w.body:applyTorque(w.body:getAngularVelocity() * -0.5 * w.body:getMass())
        end
        
        -- Combat / Player Collision
        if player and player.body and not player.body:isDestroyed() and not w.data.friendly then
            local px, py = player.body:getPosition()
            local dist = math.sqrt((wx-px)^2 + (wy-py)^2)
            
            if dist < (w.data.w/2 + 20) then
                local currentTime = love.timer.getTime()
                if currentTime - w.lastAttackTime >= w.attackCooldown then
                    local Entities = require("entities")
                    Entities.applyDamage(player, w.data.damage)
                    w.lastAttackTime = currentTime
                    EffectsSystem.createDamageEffect(px, py, px, py, true)
                    
                    -- Recoil
                    w.body:applyLinearImpulse(-vx * 0.5, -vy * 0.5)
                end
            end
        end
        
        ::continue::
    end
end

-- Realistic steering AI
function Whale.updateAI(whale, dt, player, waterArea)
    local wx, wy = whale.body:getPosition()
    local px, py = player and player.body and player.body:getPosition() or wx, wy
    local distToPlayer = math.sqrt((wx-px)^2 + (wy-py)^2)
    
    -- State transitions
    if not whale.data.friendly and distToPlayer < 400 then
        whale.state = "hunt"
        whale.targetX, whale.targetY = px, py
    else
        whale.state = "wander"
        whale.waypointTimer = whale.waypointTimer - dt
        if whale.waypointTimer <= 0 then
            -- Pick a new waypoint inside the water
            whale.waypointTimer = love.math.random(3, 8)
            local wanderRadius = 300
            whale.targetX = wx + love.math.random(-wanderRadius, wanderRadius)
            -- Tendency to stay submerged, but occasionally breach
            if love.math.random() < 0.2 then
                whale.targetY = waterArea.y - 50 -- Target above water to breach!
            else
                whale.targetY = math.min(wy + love.math.random(-wanderRadius, wanderRadius), waterArea.y + waterArea.h - 50)
            end
        end
    end
    
    -- 1. Calculate desired angle
    local dx = whale.targetX - wx
    local dy = whale.targetY - wy
    local desiredAngle = math.atan2(dy, dx)
    local currentAngle = whale.body:getAngle()
    
    -- Normalize angle difference to -PI to PI
    local angleDiff = (desiredAngle - currentAngle + math.pi) % (2 * math.pi) - math.pi
    
    -- 2. Apply Torque to rotate smoothly towards target (Fish steering)
    local turnSpeed = whale.data.turnSpeed * whale.body:getMass()
    whale.body:applyTorque(angleDiff * turnSpeed)
    
    -- 3. Apply forward Thrust in the direction it is currently facing
    local facingX = math.cos(currentAngle)
    local facingY = math.sin(currentAngle)
    local thrust = whale.data.speed * whale.body:getMass()
    
    -- If hunting, move faster. If facing away from target, move slower.
    local alignment = math.max(0, math.cos(angleDiff))
    local multiplier = (whale.state == "hunt") and 1.5 or 0.8
    
    whale.body:applyForce(facingX * thrust * alignment * multiplier, facingY * thrust * alignment * multiplier)
end

function Whale.damage(whale, amount, source)
    if not whale or not whale.body or whale.body:isDestroyed() then return end
    
    whale.health = whale.health - amount
    whale.damageFlash = 0.3
    
    local wx, wy = whale.body:getPosition()
    local EffectsSystem = require("effects")
    
    for i = 1, 8 do
        EffectsSystem.createParticle(wx, wy, 
            love.math.random(-50, 50), love.math.random(-30, 30), 
            20, 200, 3, "orangeSpark")
    end
    
    if whale.health <= 0 then
        Whale.destroy(whale)
    end
end

function Whale.destroy(whale)
    if not whale or not whale.body then return end
    
    local RopeSystem = require("rope")
    RopeSystem.destroyAllForObject(whale)
    
    local wx, wy = whale.body:getPosition()
    local EffectsSystem = require("effects")
    local Water = require("water")
    
    for i = 1, 30 do
        EffectsSystem.createParticle(wx, wy, 
            love.math.random(-80, 80), love.math.random(-80, 80), 
            30, 250, 4, "orangeSpark")
        EffectsSystem.createParticle(wx, wy, 
            love.math.random(-40, 40), love.math.random(-60, 20), 
            40, 200, 5, "smoke")
    end
    
    Water.createSplash(wx, wy, 250)
    whale.body:destroy()
    
    for i, w in ipairs(Whale.whales) do
        if w == whale then
            table.remove(Whale.whales, i)
            break
        end
    end
end

-- Procedural Rendering
function Whale.draw(debugMode)
    for _, w in ipairs(Whale.whales) do
        if w.body and not w.body:isDestroyed() then
            local x, y = w.body:getPosition()
            local angle = w.body:getAngle()
            local data = w.data
            
            -- Damage Flash
            if w.damageFlash > 0 then
                love.graphics.setColor(1, 0.3, 0.3, 1)
            else
                love.graphics.setColor(data.color)
            end
            
            love.graphics.push()
            love.graphics.translate(x, y)
            love.graphics.rotate(angle)
            
            local hw, hh = data.w/2, data.h/2
            
            -- 1. Draw Tail (Fluke)
            love.graphics.push()
            love.graphics.translate(-hw + 5, 0) -- Hinge at the back
            love.graphics.rotate(w.tailAngle)
            
            -- Tail connecting peduncle
            love.graphics.polygon("fill", 
                0, -hh * 0.4, 
                -data.tailSize * 0.8, -hh * 0.15, 
                -data.tailSize * 0.8, hh * 0.15, 
                0, hh * 0.4)
                
            -- Tail fins
            love.graphics.polygon("fill", 
                -data.tailSize * 0.6, 0,
                -data.tailSize * 1.5, -hh * 1.2,
                -data.tailSize * 1.2, 0,
                -data.tailSize * 1.5, hh * 1.2)
            love.graphics.pop()
            
            -- 2. Draw Pectoral Fin (Background)
            love.graphics.setColor(data.color[1]*0.7, data.color[2]*0.7, data.color[3]*0.7)
            love.graphics.polygon("fill", 
                hw * 0.3, 0,
                0, hh * 1.5,
                hw * 0.1, 0)
                
            -- Reset color for main body
            if w.damageFlash > 0 then
                love.graphics.setColor(1, 0.3, 0.3, 1)
            else
                love.graphics.setColor(data.color)
            end

            -- 3. Draw Main Body (Sleek aerodynamic profile)
            -- We build a dynamic polygon to make a streamlined whale shape
            local segments = 12
            local bodyPoly = {}
            for i = 0, segments do
                local t = i / segments
                local px = hw - (t * data.w)
                -- Curve formula for top of the whale
                local py = -hh * math.sin(t * math.pi) * (1.0 - t * 0.3)
                table.insert(bodyPoly, px)
                table.insert(bodyPoly, py)
            end
            for i = segments, 0, -1 do
                local t = i / segments
                local px = hw - (t * data.w)
                -- Curve formula for the bottom (belly is slightly flatter or rounder depending on type)
                local py = hh * math.sin(t * math.pi) * (1.0 - t * 0.5)
                table.insert(bodyPoly, px)
                table.insert(bodyPoly, py)
            end
            love.graphics.polygon("fill", bodyPoly)
            
            -- 4. Draw Belly Color (Underbelly)
            if not (w.damageFlash > 0) then
                love.graphics.setColor(data.bellyColor)
                local bellyPoly = {}
                for i = 0, segments do
                    local t = i / segments
                    local px = hw - (t * data.w)
                    local py = hh * math.sin(t * math.pi) * (1.0 - t * 0.5)
                    table.insert(bellyPoly, px)
                    table.insert(bellyPoly, py)
                end
                -- Close the belly polygon
                for i = segments, 0, -1 do
                    local t = i / segments
                    local px = hw - (t * data.w)
                    local py = hh * 0.2 * math.sin(t * math.pi) -- Line across the middle
                    table.insert(bellyPoly, px)
                    table.insert(bellyPoly, py)
                end
                love.graphics.polygon("fill", bellyPoly)
            end
            
            -- 5. Species Specific Markings (Orca eye patch)
            if w.whaleType == "aggressive" and not (w.damageFlash > 0) then
                love.graphics.setColor(1, 1, 1, 1) -- White patch
                love.graphics.ellipse("fill", hw * 0.5, -hh * 0.3, hw * 0.15, hh * 0.2)
            end

            -- 6. Draw Dorsal Fin
            if not (w.damageFlash > 0) then love.graphics.setColor(data.color) end
            love.graphics.polygon("fill", 
                -hw * 0.1, -hh * 0.9,
                -hw * 0.3 - data.dorsalSize, -hh - data.dorsalSize,
                -hw * 0.4, -hh * 0.8)

            -- 7. Draw Pectoral Fin (Foreground)
            love.graphics.polygon("fill", 
                hw * 0.4, 0,
                hw * 0.1, hh * 1.8,
                hw * 0.2, 0)
                
            -- 8. Draw Eye
            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.circle("fill", hw * 0.75, -hh * 0.2, 2)
            if w.whaleType == "aggressive" then
                -- Angry red pupil for killer whales
                love.graphics.setColor(1, 0, 0, 1)
                love.graphics.circle("fill", hw * 0.75 + 0.5, -hh * 0.2, 1)
            end
            
            love.graphics.pop()
            
            -- Debug UI
            if debugMode then
                love.graphics.setColor(0, 1, 0)
                love.graphics.circle("line", w.targetX, w.targetY, 5)
                love.graphics.line(x, y, w.targetX, w.targetY)
                
                love.graphics.setColor(1, 1, 1)
                love.graphics.print(w.state, x - 20, y - hh - 20)
                
                -- Health bar
                local pct = w.health / w.maxHealth
                love.graphics.setColor(1, 0, 0)
                love.graphics.rectangle("fill", x - 25, y - hh - 10, 50, 4)
                love.graphics.setColor(0, 1, 0)
                love.graphics.rectangle("fill", x - 25, y - hh - 10, 50 * pct, 4)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Whale.getAll()
    return Whale.whales
end

function Whale.clear()
    for _, w in ipairs(Whale.whales) do
        if w.body and not w.body:isDestroyed() then
            w.body:destroy()
        end
    end
    Whale.whales = {}
    Whale.nextId = 1
end

return Whale