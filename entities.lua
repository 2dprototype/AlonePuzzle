local Config = require("config")
local WorldManager = require("world_manager")
local RopeSystem = require("rope")
local EffectsSystem = require("effects")
local Water = require("water")
local Whale = require("whale")

local debugModeEnabled = false

local Entities = {
    player = nil,
    list = {}
}

-- Explosive presets
local EXPLOSIVE_PRESETS = {
    grenade = {
        radius = 150, damage = 10, force = 25,
        width = 12, height = 12, mass = 0.8, friction = 0.3, restitution = 0.4,
        label = "GRE"
    },
    tnt = {
        radius = 300, damage = 700, force = 80,
        width = 25, height = 25, mass = 1.5, friction = 0.4, restitution = 0.2,
        label = "TNT"
    },
    nuke = {
        radius = 800, damage = 2000, force = 5000,
        width = 40, height = 120, mass = 5.0, friction = 0.5, restitution = 0.1,
        label = "NUKE"
    }
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
        health = cfg.maxHealth, maxHealth = cfg.maxHealth, damageFlash = 0, thrusterCooldown = 0,
        dead = false -- Added tracking property
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

function Entities.createGrenade(x, y)
    local p = EXPLOSIVE_PRESETS.grenade
    local body = love.physics.newBody(WorldManager.world, x, y, "dynamic")
    local shape = love.physics.newRectangleShape(p.width, p.height)
    local fixture = love.physics.newFixture(body, shape, p.mass)
    fixture:setFriction(p.friction)
    fixture:setRestitution(p.restitution)
    
    local grenade = {
        type = "grenade",
        body = body, shape = shape, fixture = fixture,
        w = p.width, h = p.height,
        timer = nil,                -- seconds until explosion
        explosionRadius = p.radius,
        explosionDamage = p.damage,
        explosionForce = p.force,
        ropeIds = {},
        damageFlash = 0
    }
    table.insert(Entities.list, grenade)
    return grenade
end

function Entities.createTNTBox(x, y, w, h)
    w = w or 30
    h = h or 30
    local p = EXPLOSIVE_PRESETS.tnt
    local body = love.physics.newBody(WorldManager.world, x, y, "dynamic")
    local shape = love.physics.newRectangleShape(w, h)
    local fixture = love.physics.newFixture(body, shape, p.mass)
    fixture:setFriction(p.friction)
    fixture:setRestitution(p.restitution)
    
    local tnt = {
        type = "tnt",
        body = body, shape = shape, fixture = fixture,
        w = w, h = h,
        timer = nil,
        explosionRadius = p.radius,
        explosionDamage = p.damage,
        explosionForce = p.force,
        ropeIds = {},
        damageFlash = 0
    }
    table.insert(Entities.list, tnt)
    return tnt
end

function Entities.createNuke(x, y)
    local p = EXPLOSIVE_PRESETS.nuke
    local body = love.physics.newBody(WorldManager.world, x, y, "dynamic")
    local shape = love.physics.newRectangleShape(p.width, p.height)
    local fixture = love.physics.newFixture(body, shape, p.mass)
    fixture:setFriction(p.friction)
    fixture:setRestitution(p.restitution)
    
    local nuke = {
        type = "nuke",
        body = body, shape = shape, fixture = fixture,
        w = p.width, h = p.height,
        timer = nil,
        explosionRadius = p.radius,
        explosionDamage = p.damage,
        explosionForce = p.force,
        ropeIds = {},
        damageFlash = 0
    }
    table.insert(Entities.list, nuke)
    return nuke
end

function Entities.update(dt)
    -- Guard condition changed: Allow logic to run even if player is dead, as long as body exists
    if not Entities.player or not Entities.player.body or Entities.player.body:isDestroyed() then return end
    
    local p = Entities.player
    if p.damageFlash then p.damageFlash = math.max(0, p.damageFlash - dt) end
    p.thrusterCooldown = math.max(0, (p.thrusterCooldown or 0) - dt)
    
    local bx, by = p.body:getWorldPoint(0, p.h / 2)
    local thrusting = false
    local pCfg = Config.player
    
    -- ONLY PROCESS CONTROLS IF ALIVE
    if not p.dead then
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
    else
        -- If dead, apply heavy damping to bring the body to a gradual rest
        local vx, vy = p.body:getLinearVelocity()
        p.body:setLinearVelocity(vx * 0.95, vy * 0.95)
    end
    

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
            
            if (e.type == "grenade" or e.type == "tnt" or e.type == "nuke") and e.timer and e.timer > 0 then
                e.timer = e.timer - dt
                if e.timer <= 0 then
                    Entities.explode(e)
                end
            end
            
            -- Only track/hunt the player if they are still alive
            if e.type == "enemy" and not p.dead then
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
    if not e or not e.health or e.body:isDestroyed() or e.dead then return end
    if e.type == "box" and e.sliceDepth then
        dmg = dmg * math.pow(0.85, e.sliceDepth)
    end
    
    e.health = e.health - dmg
    e.damageFlash = 0.2
    
    if e.health <= 0 then 
        e.health = 0
        if e.type == "player" then
            e.dead = true
            e.body:setLinearVelocity(0, 0)
            e.body:setAngularVelocity(0)
            -- if e.fixture and not e.fixture:isDestroyed() then
                -- e.fixture:setSensor(true) -- Turns off collisions so things pass through gracefully
            -- end
            RopeSystem.destroyAllForObject(e) -- Snaps ropes attached to the dead player
        else
            Entities.destroy(e) 
        end
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

function Entities.explode(e)
    if not e or not e.body or e.body:isDestroyed() then return end
    local cx, cy = e.body:getPosition()
    local radius = e.explosionRadius
    local maxDamage = e.explosionDamage
    local maxForce = e.explosionForce

    local isNuke = (e.type == "nuke")
    local intensity = (maxDamage / 300) * 0.6 + (maxForce / 1000) * 0.4
    intensity = math.min(1, intensity)
    -- if isNuke then intensity = 1.0 end

    -- 1. Bright flash (big damage effect line)
    EffectsSystem.createFlash(cx, cy, radius, intensity)

    -- 2. Shockwave ring
    if isNuke then
        for i = 1, 3 do
            EffectsSystem.createShockwave(cx, cy, radius * (0.8 + i * 0.1), intensity)
        end
    else
        EffectsSystem.createShockwave(cx, cy, radius, intensity)
    end

    -- 3. Fireball core (large orange particles)
    local coreCount = 10 + math.floor(20 * intensity)
    if isNuke then coreCount = 80 end
    for i = 1, coreCount do
        local angle = love.math.random() * math.pi * 2
        local dist = love.math.random(0, radius * 0.6)
        local px = cx + math.cos(angle) * dist
        local py = cy + math.sin(angle) * dist
        local vx = math.cos(angle) * love.math.random(30, 120 * intensity)
        local vy = math.sin(angle) * love.math.random(30, 120 * intensity)
        local size = 2 + love.math.random() * 4 * intensity
        EffectsSystem.createParticle(px, py, vx, vy, 20 + 30 * intensity, 250, size, "orangeSpark")
    end

    -- 4. Sparks and embers (more = more damage)
    local sparkCount = 30 + math.floor(70 * intensity)
    if isNuke then sparkCount = 200 end
    
    for i = 1, sparkCount do
        local angle = love.math.random() * math.pi * 2
        local dist = love.math.random(5, radius)
        local px = cx + math.cos(angle) * dist
        local py = cy + math.sin(angle) * dist
        local speed = 50 + love.math.random() * 200 * intensity
        local vx = math.cos(angle) * speed + love.math.random(-30, 30)
        local vy = math.sin(angle) * speed + love.math.random(-30, 30)
        local ptype = love.math.random() < 0.7 and "orangeSpark" or "ember"
        EffectsSystem.createParticle(px, py, vx, vy, 15 + 20 * intensity, 300, 1.5 + intensity, ptype)
    end

    -- 5. Debris chunks (small dark pieces)
    local debrisCount = 5 + math.floor(15 * intensity)
    if isNuke then debrisCount = 50 end
    
    for i = 1, debrisCount do
        local angle = love.math.random() * math.pi * 2
        local dist = love.math.random(0, radius * 0.8)
        local px = cx + math.cos(angle) * dist
        local py = cy + math.sin(angle) * dist
        local speed = 80 + love.math.random() * 150 * intensity
        local vx = math.cos(angle) * speed + love.math.random(-40, 40)
        local vy = math.sin(angle) * speed + love.math.random(-40, 40)
        EffectsSystem.createParticle(px, py, vx, vy, 25, 200, 2 + intensity, "debris")
    end

    -- 6. Thick smoke cloud
    local smokeCount = 20 + math.floor(40 * intensity)
    if isNuke then smokeCount = 150 end
    
    for i = 1, smokeCount do
        local angle = love.math.random() * math.pi * 2
        local dist = love.math.random(0, radius * 0.9)
        local px = cx + math.cos(angle) * dist
        local py = cy + math.sin(angle) * dist
        local vx = math.cos(angle) * love.math.random(10, 50) + love.math.random(-20, 20)
        local vy = math.sin(angle) * love.math.random(10, 50) + love.math.random(-20, 20) - 20
        local size = 3 + love.math.random() * 5 * intensity
        EffectsSystem.createParticle(px, py, vx, vy, 40 + 60 * intensity, 120, size, "smoke")
    end

    -- 7. Collect affected entities from Entities.list
    local affected = {}
    for _, other in ipairs(Entities.list) do
        if other ~= e and other.body and not other.body:isDestroyed() then
            local ox, oy = other.body:getPosition()
            local dx = ox - cx
            local dy = oy - cy
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist < radius then
                table.insert(affected, {other=other, dist=dist, ox=ox, oy=oy, dx=dx, dy=dy})
            end
        end
    end

    -- Also collect whales from Whale module
    local whales = Whale.getAll()
    for _, w in ipairs(whales) do
        if w.body and not w.body:isDestroyed() and not w.dead then
            local ox, oy = w.body:getPosition()
            local dx = ox - cx
            local dy = oy - cy
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist < radius then
                table.insert(affected, {other=w, dist=dist, ox=ox, oy=oy, dx=dx, dy=dy})
            end
        end
    end

    -- Apply impulses (push)
    for _, a in ipairs(affected) do
        local falloff = 1 - (a.dist / radius)
        local forceMag = maxForce * falloff * (0.5 + intensity)   -- extra kick
        local angle = math.atan2(a.dy, a.dx)
        local fx = math.cos(angle) * forceMag
        local fy = math.sin(angle) * forceMag
        if a.other.body and not a.other.body:isDestroyed() then
            a.other.body:applyLinearImpulse(fx, fy, a.ox, a.oy)
        end
    end

    -- Apply damage
    for _, a in ipairs(affected) do
        local falloff = 1 - (a.dist / radius)
        local damage = math.floor(maxDamage * falloff)
        if a.other.type == "player" then
            Entities.applyDamage(a.other, damage)
        elseif a.other.type == "enemy" then
            Entities.applyDamage(a.other, damage)
        elseif a.other.type == "box" then
            Entities.applyDamage(a.other, damage)
        elseif a.other.type == "ball" then
            Entities.applyDamage(a.other, damage)
        elseif a.other.type == "whale" then
            Entities.applyDamage(a.other, damage)
        end
    end

    -- Destroy the explosive
    RopeSystem.destroyAllForObject(e)
    e.body:destroy()
    for i, ent in ipairs(Entities.list) do
        if ent == e then
            table.remove(Entities.list, i)
            break
        end
    end
end


-- Merge explosives of the same type that are near the player
function Entities.mergeExplosivesNearPlayer(player)
    if not player or not player.body then return end
    local px, py = player.body:getPosition()
    local radius = 120  -- detection radius for explosives

    -- Collect explosives by type
    local explosivesByType = {
        grenade = {},
        tnt = {},
        nuke = {}
    }

    for _, e in ipairs(Entities.list) do
        if e.body and not e.body:isDestroyed() then
            local ex, ey = e.body:getPosition()
            local dist = math.sqrt((px-ex)^2 + (py-ey)^2)
            if dist < radius then
                if e.type == "grenade" then
                    table.insert(explosivesByType.grenade, e)
                elseif e.type == "tnt" then
                    table.insert(explosivesByType.tnt, e)
                elseif e.type == "nuke" then
                    table.insert(explosivesByType.nuke, e)
                end
            end
        end
    end

    -- Process each type separately
    for typ, list in pairs(explosivesByType) do
        if #list >= 2 then
            -- Compute weighted center (by damage or simply average)
            local sumX, sumY = 0, 0
            local totalDamage = 0
            local totalForce = 0
            local totalRadius = 0
            local minTimer = nil
            local mergeCount = #list

            for _, e in ipairs(list) do
                local ex, ey = e.body:getPosition()
                sumX = sumX + ex
                sumY = sumY + ey
                totalDamage = totalDamage + e.explosionDamage
                totalForce = totalForce + e.explosionForce
                totalRadius = totalRadius + e.explosionRadius
                if e.timer and e.timer > 0 then
                    if minTimer == nil or e.timer < minTimer then
                        minTimer = e.timer
                    end
                end
            end

            local centerX = sumX / #list
            local centerY = sumY / #list

            -- Optionally boost stats for merging 
            local boost = 1 + (mergeCount - 1)
            totalDamage = totalDamage * boost
            totalForce = totalForce * boost
            totalRadius = totalRadius * 0.8 + (totalRadius / #list) * 0.5  -- blend radius

            -- Create the merged explosive (preserve original type)
            local newExplosive
            if typ == "grenade" then
                newExplosive = Entities.createGrenade(centerX, centerY)
                newExplosive.explosionDamage = totalDamage
                newExplosive.explosionForce = totalForce
                newExplosive.explosionRadius = math.min(300, totalRadius)  -- cap
                newExplosive.mergeCount = mergeCount   -- store for visual effect
                newExplosive.mergePower = mergeCount   -- for drawing
            elseif typ == "tnt" then
                newExplosive = Entities.createTNTBox(centerX, centerY, 30, 30)
                newExplosive.explosionDamage = totalDamage
                newExplosive.explosionForce = totalForce
                newExplosive.explosionRadius = math.min(500, totalRadius)
                newExplosive.mergeCount = mergeCount
                newExplosive.mergePower = mergeCount
            elseif typ == "nuke" then
                newExplosive = Entities.createNuke(centerX, centerY)
                newExplosive.explosionDamage = totalDamage
                newExplosive.explosionForce = totalForce
                newExplosive.explosionRadius = math.min(1200, totalRadius)
                newExplosive.mergeCount = mergeCount
                newExplosive.mergePower = mergeCount
            end

            if newExplosive then
                -- Set timer to the smallest remaining timer from merged explosives
                if minTimer then
                    newExplosive.timer = math.max(0.1, minTimer)
                end

                -- Destroy all original explosives (ropes already handled in destroy)
                for _, e in ipairs(list) do
                    if e.body and not e.body:isDestroyed() then
                        RopeSystem.destroyAllForObject(e)
                        e.body:destroy()
                        -- Remove from Entities.list
                        for i, ent in ipairs(Entities.list) do
                            if ent == e then
                                table.remove(Entities.list, i)
                                break
                            end
                        end
                    end
                end

                -- Optional: Add a flash effect at merge location
                EffectsSystem.createFlash(centerX, centerY, 50, 0.5)
            end
        end
    end
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
                elseif e.type == "grenade" then
                    love.graphics.setColor(0.25, 0.35, 0.2)  
                    -- Darken based on merge count
                    if e.mergePower and e.mergePower > 1 then
                        local factor = 1 - math.min(0.6, (e.mergePower-1) * 0.15)
                        love.graphics.setColor(0.25 * factor, 0.35 * factor, 0.2 * factor)
                    end
                    love.graphics.circle("fill", x, y, e.w/2)
                -- love.graphics.setColor(0,0,0)
                -- love.graphics.circle("line", x, y, e.w/2)
                if e.timer and e.timer > 0 then
                    love.graphics.setColor(1,1,0)
                    love.graphics.print(string.format("%.1f", e.timer), x-4, y-12)
                end
            elseif e.type == "tnt" then
                local r, g, b = 0.7, 0.1, 0.05
                if e.mergePower and e.mergePower > 1 then
                    local factor = 1 - math.min(0.5, (e.mergePower-1) * 0.12)
                    r, g, b = r * factor, g * factor, b * factor
                end
                love.graphics.setColor(r, g, b)
                love.graphics.polygon("fill", e.body:getWorldPoints(e.shape:getPoints()))
                love.graphics.setColor(0,0,0)
                -- love.graphics.polygon("line", e.body:getWorldPoints(e.shape:getPoints()))
                love.graphics.print("TNT", x-8, y-5)
                love.graphics.print("" .. e.explosionForce, x-8, y-14)
                love.graphics.print("" .. e.explosionDamage, x-8, y+4)
                if e.timer and e.timer > 0 then
                    love.graphics.setColor(1,1,0)
                    love.graphics.print(string.format("%.1f", e.timer), x-6, y-20)
                end
            elseif e.type == "nuke" then
                love.graphics.push()
                love.graphics.translate(x, y)
                -- Rotate drawing to match the physics body
                love.graphics.rotate(e.body:getAngle())
                
                local w = e.w
                local h = e.h
                local hw = w / 2
                local hh = h / 2
                
                -- Calculate darkening factor based on merge count
                local darkFactor = 1
                if e.mergePower and e.mergePower > 1 then
                    darkFactor = 1 - math.min(0.6, (e.mergePower - 1) * 0.12)
                end
                
                -- 1. Base Casing (Military Olive Green) - darkened by merge count
                love.graphics.setColor(0.28 * darkFactor, 0.32 * darkFactor, 0.24 * darkFactor)
                love.graphics.rectangle("fill", -hw, -hh + 30, w, h - 50)
                
                -- 2. Nose Cone (Dark olive, slightly metallic) - darkened by merge count
                love.graphics.setColor(0.22 * darkFactor, 0.26 * darkFactor, 0.18 * darkFactor)
                love.graphics.polygon("fill", -hw, -hh + 30, hw, -hh + 30, 0, -hh - 10)
                
                -- 3. Tail Section (Dark military) - darkened by merge count
                love.graphics.setColor(0.2 * darkFactor, 0.24 * darkFactor, 0.17 * darkFactor)
                love.graphics.polygon("fill", -hw, hh - 20, hw, hh - 20, hw - 10, hh, -hw + 10, hh)
                
                -- 4. Tail Fins (Dark metal/olive) - darkened by merge count
                love.graphics.setColor(0.18 * darkFactor, 0.21 * darkFactor, 0.15 * darkFactor)
                love.graphics.polygon("fill", -hw, hh - 40, -hw - 18, hh, -hw, hh - 10) -- Left fin
                love.graphics.polygon("fill", hw, hh - 40, hw + 18, hh, hw, hh - 10)  -- Right fin
                
                -- 5. Yellow Warning Stripes (become more orange/red as darker)
                if e.mergePower and e.mergePower > 2 then
                    -- Very merged nukes have danger red stripes instead of yellow
                    love.graphics.setColor(0.85, 0.2, 0.1)  -- Danger red
                elseif e.mergePower and e.mergePower > 1 then
                    -- Slightly merged: orange warning
                    love.graphics.setColor(0.85, 0.55, 0.1)  -- Orange
                else
                    love.graphics.setColor(0.75, 0.65, 0.1)  -- Standard military caution yellow
                end
                love.graphics.rectangle("fill", -hw, -hh + 40, w, 12)
                
                -- Black hazard stripes (clipped to body width) - always black
                love.graphics.setColor(0.15, 0.15, 0.12)
                local stripe_width = 8
                local start_x = -hw
                for i = 0, math.ceil(w / stripe_width) do
                    local x_pos = start_x + (i * stripe_width)
                    if x_pos + stripe_width/2 <= hw then
                        love.graphics.polygon("fill", 
                            x_pos, -hh + 40, 
                            x_pos + stripe_width/2, -hh + 40,
                            x_pos + stripe_width, -hh + 52,
                            x_pos + stripe_width/2, -hh + 52)
                    end
                end
                
                love.graphics.pop()
                
                -- 7. Detonation Timer (Drawn outside rotation so it stays upright)
                if e.timer and e.timer > 0 then
                    -- Military-style warning display
                    local alpha = 1
                    if e.timer < 3 then
                        alpha = 0.5 + math.sin(love.timer.getTime() * 10) * 0.5  -- Blinking effect
                    end
                    love.graphics.setColor(0.9, 0.7, 0.1, alpha)
                    love.graphics.print(string.format("FUSE: %.1f", e.timer), x - 35, y - hh - 30)
                    
                    -- Critical warning
                    if e.timer < 2 then
                        love.graphics.setColor(0.9, 0.2, 0.1, 0.8 + math.sin(love.timer.getTime() * 15) * 0.5)
                        love.graphics.print("! ARMING FAST !", x - 45, y - hh - 48)
                    end
                end
        
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