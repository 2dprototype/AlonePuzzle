function love.load()
    -- Game state
    game = {
        debugMode = false,
        state = "playing" -- playing, paused, gameover
    }
    
    -- Physics world setup
    love.physics.setMeter(64) -- 1 meter = 64 pixels
    world = love.physics.newWorld(0, 9.81 * 64, true)
    
    -- Game objects
    boundaries = {}
    PlayerX = {}
    box_i = {}
    particles = {}
    enemies = {}
    balls = {}
    damageEffects = {}
    
    createBoundaries()
    createPlayer()
    createEnemies()
    createBoxes()
    createBalls()
    
    -- Enhanced Camera setup
    camera = {
        x = 0, 
        y = 0, 
        scale = 1,
        mode = "follow_player",
        target = nil,
        freeMoveSpeed = 300,
        minScale = 0.1,
        maxScale = 3.0
    }
    
    -- Camera mode instructions
    cameraInstructions = {
        "F1: Follow Player",
        "F2: Follow Enemy", 
        "F3: Free Move",
        "Wheel or -/+: Zoom",
        "WASD: Free Move",
        "R: Reset Zoom",
        "F5: Toggle Debug Mode",
        "SPACE: Grab/Release Object",
        "E: Grab Enemy/Box"
    }
    
    -- Debug info
    debugInfo = {
        showPlayerVectors = true,
        showThrusterDirection = true,
        showPhysicsInfo = true,
        showObjectCounts = true
    }
    
    damageEffects = {}
    objectHealth = {}
end

function love.update(dt)
    if game.state ~= "playing" then return end
    
    world:update(dt)
    updatePlayer(dt)
    updateEnemies(dt)
    updateParticles(dt)
    updateDamageEffects(dt)
    updateCamera(dt)
    checkCollisions()
end

function love.draw()
    love.graphics.clear(0.15, 0.15, 0.15)
    love.graphics.push()
    
    -- Apply camera transform
    love.graphics.translate(love.graphics.getWidth()/2, love.graphics.getHeight()/2)
    love.graphics.scale(camera.scale)
    love.graphics.translate(-camera.x, -camera.y)
    
    -- Draw sun
    love.graphics.circle("fill", 0, 0, 12.5)
    
    local oldFont = love.graphics.getFont()
    local smallFont = love.graphics.newFont(8)
    love.graphics.setFont(smallFont)

    -- Draw all objects
    drawBoundaries()
    drawBoxes()
    drawEnemies()
    drawBalls()
    drawPlayer(PlayerX[1])
    drawParticles()
    drawDamageEffects()
    
    love.graphics.setFont(oldFont)
    
    -- Debug drawings
    if game.debugMode then drawDebugInfo() end
    
    love.graphics.pop()
    drawUI()
end

function love.keypressed(key)
    if key == "escape" then love.event.quit()
    elseif key == "f1" then camera.mode = "follow_player"; camera.target = nil
    elseif key == "f2" then camera.mode = "follow_enemy"; camera.target = nil
    elseif key == "f3" then camera.mode = "free_move"; camera.target = nil
    elseif key == "=" or key == "+" then camera.scale = math.min(camera.scale + 0.1, 5)
    elseif key == "-" or key == "_" then camera.scale = math.max(camera.scale - 0.1, 0.1)
    elseif key == "r" then camera.scale = 1.0 
    elseif key == "f5" then game.debugMode = not game.debugMode
    elseif key == "p" then game.state = (game.state == "playing") and "paused" or "playing"
    elseif key == "space" then
        if PlayerX[1] then
            if PlayerX[1].rope then releaseRope(PlayerX[1]) else grabObject() end
        end
    elseif key == "e" then
        if PlayerX[1] and not PlayerX[1].rope then grabEnemy() end
    end
end

function love.wheelmoved(x, y)
    local zoomFactor = 1.1
    if y > 0 then camera.scale = math.min(camera.scale * zoomFactor, camera.maxScale)
    elseif y < 0 then camera.scale = math.max(camera.scale / zoomFactor, camera.minScale)
    end
end

-- UI and Debug Functions (Unchanged visually, kept modular)
function drawUI()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("State: " .. game.state, 10, 10)
    
    if PlayerX[1] then
        local px, py = PlayerX[1].body:getPosition()
        love.graphics.print("Player Position: " .. math.floor(px) .. ", " .. math.floor(py), 10, 30)
        if PlayerX[1].rope then
            love.graphics.setColor(0.3, 1, 0.3)
            love.graphics.print("Carrying Object!", 10, 250)
            love.graphics.setColor(1, 1, 1)
        end
    end
    
    love.graphics.print("Camera Mode: " .. camera.mode, 10, 50)
    love.graphics.print("Zoom: " .. string.format("%.2f", camera.scale), 10, 70)
    
    if game.debugMode then
        love.graphics.setColor(1, 0, 0)
        love.graphics.print("DEBUG MODE ACTIVE", 10, 90)
        love.graphics.setColor(1, 1, 1)
    end
    
    love.graphics.print("Controls:", love.graphics.getWidth() - 200, 10)
    for i, instruction in ipairs(cameraInstructions) do
        love.graphics.print(instruction, love.graphics.getWidth() - 200, 10 + i * 20)
    end
    
    love.graphics.print("Game Controls:", love.graphics.getWidth() - 200, 190)
    love.graphics.print("Arrow Keys: Move Player", love.graphics.getWidth() - 200, 210)
    love.graphics.print("PageUp/Down: Rotate", love.graphics.getWidth() - 200, 230)
    love.graphics.print("P: Pause/Resume", love.graphics.getWidth() - 200, 250)
end

function drawDebugInfo()
    if PlayerX[1] then drawPlayerDebugInfo(PlayerX[1]) end
    for _, enemy in ipairs(enemies) do drawEnemyDebugInfo(enemy) end
    if debugInfo.showPhysicsInfo then drawPhysicsDebug() end
end

function drawPlayerDebugInfo(player)
    local body = player.body
    local x, y = body:getPosition()
    local angle = body:getAngle()
    
    if debugInfo.showPlayerVectors then
        local length = 50
        love.graphics.setColor(1, 0, 0, 0.8)
        love.graphics.line(x, y, x + math.cos(angle) * length, y + math.sin(angle) * length)
        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.line(x, y, x + math.cos(angle + math.pi/2) * length, y + math.sin(angle + math.pi/2) * length)
    end
    
    local vx, vy = body:getLinearVelocity()
    love.graphics.setColor(0, 0.5, 1, 0.8)
    love.graphics.line(x, y, x + vx, y + vy)
end

function drawEnemyDebugInfo(enemy)
    local body = enemy.body
    local x, y = body:getPosition()
    if PlayerX[1] then
        local px, py = PlayerX[1].body:getPosition()
        love.graphics.setColor(1, 0, 0, 0.5)
        love.graphics.line(x, y, px, py)
    end
    local vx, vy = body:getLinearVelocity()
    love.graphics.setColor(1, 0.5, 0.5, 0.8)
    love.graphics.line(x, y, x + vx, y + vy)
end

function drawPhysicsDebug()
    love.graphics.setColor(0, 0.5, 0, 0.3)
    for _, boundary in ipairs(boundaries) do
        love.graphics.polygon("line", boundary.body:getWorldPoints(boundary.shape:getPoints()))
    end
    love.graphics.setColor(0.5, 0.5, 0, 0.3)
    for _, box in ipairs(box_i) do
        if box.type == "box" then
            love.graphics.polygon("line", box.body:getWorldPoints(box.shape:getPoints()))
        end
    end
end

function updateCamera(dt)
    if camera.mode == "follow_player" and PlayerX[1] then
        local targetX, targetY = PlayerX[1].body:getPosition()
        camera.x = camera.x + (targetX - camera.x) * 0.99
        camera.y = camera.y + (targetY - camera.y) * 0.99
    elseif camera.mode == "follow_enemy" then
        local enemy = enemies[1]
        if enemy then
            camera.target = enemy
            local targetX, targetY = enemy.body:getPosition()
            camera.x = camera.x + (targetX - camera.x) * 0.99
            camera.y = camera.y + (targetY - camera.y) * 0.99
        end
    elseif camera.mode == "free_move" then
        local speed = camera.freeMoveSpeed * dt / camera.scale
        if love.keyboard.isDown("w") or love.keyboard.isDown("up") then camera.y = camera.y - speed end
        if love.keyboard.isDown("s") or love.keyboard.isDown("down") then camera.y = camera.y + speed end
        if love.keyboard.isDown("a") or love.keyboard.isDown("left") then camera.x = camera.x - speed end
        if love.keyboard.isDown("d") or love.keyboard.isDown("right") then camera.x = camera.x + speed end
    end
end

-- ============================================================================
-- COLLISION AND DAMAGE SYSTEM
-- ============================================================================

function checkCollisions()
    if PlayerX[1] then
        local px, py = PlayerX[1].body:getPosition()
        for i, enemy in ipairs(enemies) do
            local ex, ey = enemy.body:getPosition()
            local dx, dy = px - ex, py - ey
            if math.sqrt(dx*dx + dy*dy) < 30 then
                applyDamage(enemy, 10)
                createDamageEffect(ex, ey)
            end
        end
        for _, box in ipairs(box_i) do
            if box.type == "box" then
                local bx, by = box.body:getPosition()
                local dx, dy = px - bx, py - by
                if math.sqrt(dx*dx + dy*dy) < 40 then
                    applyDamage(box, 5)
                    createDamageEffect(bx, by)
                end
            end
        end
    end
end

function applyDamage(obj, damage)
    if not obj or not obj.health then return end
    obj.health = obj.health - damage
    obj.damageFlash = 0.2
    if obj.health <= 0 then destroyObject(obj) end
end

function destroyObject(obj)
    local x, y = obj.body:getPosition()
    for i = 1, 20 do createDamageEffect(x, y) end
    
    if obj.type == "enemy" then
        for i, enemy in ipairs(enemies) do
            if enemy == obj then table.remove(enemies, i); break end
        end
    elseif obj.type == "box" or obj.type == "ball" then
        for i, box in ipairs(box_i) do
            if box == obj then table.remove(box_i, i); break end
        end
        if obj.type == "ball" then
            for i, ball in ipairs(balls) do
                if ball == obj then table.remove(balls, i); break end
            end
        end
    end
    
    if obj.body and not obj.body:isDestroyed() then obj.body:destroy() end
end

function createDamageEffect(x, y)
    table.insert(damageEffects, {
        x = x, y = y, life = 0.5,
        vx = love.math.random(-50, 50), vy = love.math.random(-50, 50)
    })
end

function updateDamageEffects(dt)
    for i = #damageEffects, 1, -1 do
        local effect = damageEffects[i]
        effect.life = effect.life - dt
        effect.x = effect.x + effect.vx * dt
        effect.y = effect.y + effect.vy * dt
        if effect.life <= 0 then table.remove(damageEffects, i) end
    end
end

function drawDamageEffects()
    for _, effect in ipairs(damageEffects) do
        local alpha = effect.life * 2
        love.graphics.setColor(1, 0.5, 0, alpha)
        love.graphics.circle("fill", effect.x, effect.y, 5 * effect.life)
        love.graphics.setColor(1, 0, 0, alpha)
        love.graphics.circle("fill", effect.x, effect.y, 3 * effect.life)
    end
end

-- ============================================================================
-- UNIVERSAL ROPE SYSTEM
-- ============================================================================

function createRope(obj1, obj2)
    if not obj1 or not obj2 then return nil end
    local x1, y1 = obj1.body:getPosition()
    local x2, y2 = obj2.body:getPosition()
    local rope = { bodies = {}, joints = {}, obj1 = obj1, obj2 = obj2 }
    local numSegments = 13
    local prevBody = obj1.body
    local dx, dy = x2 - x1, y2 - y1
    local distance = math.sqrt(dx*dx + dy*dy)
    
    for i = 1, numSegments do
        local t = i / (numSegments + 1)
        local segBody = love.physics.newBody(world, x1 + dx * t, y1 + dy * t, "dynamic")
        local segFixture = love.physics.newFixture(segBody, love.physics.newCircleShape(1.5), 0.001)
        segFixture:setSensor(true)
        segBody:setLinearDamping(3.0)
        segBody:setAngularDamping(3.0)
        table.insert(rope.bodies, segBody)
        table.insert(rope.joints, love.physics.newRevoluteJoint(prevBody, segBody, x1 + dx * t, y1 + dy * t, false))
        prevBody = segBody
    end
    
    table.insert(rope.joints, love.physics.newRevoluteJoint(prevBody, obj2.body, x2, y2, false))
    rope.limitRope = love.physics.newRopeJoint(obj1.body, obj2.body, x1, y1, x2, y2, distance + 10, false)
    return rope
end

function grabObject()
    local player = PlayerX[1]
    if not player then return end
    local px, py = player.body:getWorldPoint(0, player.h / 2)
    local closestObj, closestDist = nil, 200
    
    for _, obj in ipairs(box_i) do
        if obj.type == "box" or obj.type == "ball" then
            local ox, oy = obj.body:getPosition()
            local dist = math.sqrt((px-ox)^2 + (py-oy)^2)
            if dist < closestDist then
                closestDist = dist
                closestObj = obj
            end
        end
    end
    if closestObj then
        player.rope = createRope(player, closestObj)
        if player.rope then player.rope.object = closestObj end
    end
end

function grabEnemy()
    local player = PlayerX[1]
    if not player or player.rope then return end
    local px, py = player.body:getWorldPoint(0, player.h / 2)
    local closestEnemy, closestDist = nil, 200
    
    for _, enemy in ipairs(enemies) do
        local ex, ey = enemy.body:getPosition()
        local dist = math.sqrt((px-ex)^2 + (py-ey)^2)
        if dist < closestDist then
            closestDist = dist
            closestEnemy = enemy
        end
    end
    if closestEnemy then
        player.rope = createRope(player, closestEnemy)
        if player.rope then player.rope.object = closestEnemy end
    end
end

function releaseRope(entity)
    if entity and entity.rope then
        if entity.rope.limitRope and not entity.rope.limitRope:isDestroyed() then
            entity.rope.limitRope:destroy()
        end
        for _, joint in ipairs(entity.rope.joints) do
            if not joint:isDestroyed() then joint:destroy() end
        end
        for _, body in ipairs(entity.rope.bodies) do
            if not body:isDestroyed() then body:destroy() end
        end
        if entity.rope.object then entity.rope.object.roped = false end
        entity.rope = nil
    end
end

-- ============================================================================
-- ENHANCED ENEMY AI (SUPER SMART)
-- ============================================================================

function createEnemies()
    table.insert(enemies, createEnemyObj(-8900, -520, 12.5, 25, 0, true))
    table.insert(enemies, createEnemyObj(-8800, -500, 12.5, 25, 0, true))
    -- Added a slightly thicker heavy enemy
    table.insert(enemies, createEnemyObj(-8700, -500, 18, 30, 0, true))
end

function createEnemyObj(x, y, w, h, angle, isSmart)
    local body = love.physics.newBody(world, x, y, "dynamic")
    local shape = love.physics.newRectangleShape(w, h)
    local fixture = love.physics.newFixture(body, shape, 1.2)
    fixture:setFriction(0.1)
    fixture:setRestitution(0.2)
    
    -- Smart Scale Health based on physical size
    local calcMaxHealth = math.floor((w * h) / 3) 
    
    local enemy = {
        type = "enemy", body = body, shape = shape, fixture = fixture,
        w = w, h = h, particles = {},
        smart = isSmart or false,
        rope = nil,
        health = calcMaxHealth,
        maxHealth = calcMaxHealth,
        damageFlash = 0
    }
    table.insert(box_i, enemy)
    return enemy
end

function updateEnemies(dt)
    if not PlayerX[1] then return end
    local playerX, playerY = PlayerX[1].body:getPosition()
    
    for _, enemy in ipairs(enemies) do
        if enemy.smart then
            updateSuperSmartEnemy(enemy, playerX, playerY, dt)
        else
            updateSingleEnemy(enemy, playerX, playerY, dt)
        end
        if enemy.damageFlash then enemy.damageFlash = math.max(0, enemy.damageFlash - dt) end
    end
end

function updateSuperSmartEnemy(enemy, playerX, playerY, dt)
    local body = enemy.body
    local ex, ey = body:getPosition()
    local vx, vy = body:getLinearVelocity()
    local playerVx, playerVy = PlayerX[1].body:getLinearVelocity()
    
    local dx = playerX - ex
    local dy = playerY - ey
    local distance = math.sqrt(dx * dx + dy * dy)
    
    local maxForce = 220 
    local forceMultiplier = 0.1
    
    -- 1. STUCK DETECTION & OBSTACLE AVOIDANCE
    -- If trying to move fast but velocity is practically zero, jump/thrust upward
    local isMovingSlow = math.abs(vx) < 15 and math.abs(vy) < 15
    if distance > 100 and isMovingSlow and love.math.random() < 0.05 then
        body:applyLinearImpulse(0, -150 * enemy.h) -- Hop over obstacle
    end

    -- 2. DYNAMIC WEAPON MANAGEMENT (Grab/Release logic)
    local shouldHaveWeapon = (distance > 50 and distance < 450)
    
    if enemy.rope then
        local weaponAlive = enemy.rope.object and not enemy.rope.object.body:isDestroyed()
        if not weaponAlive or not shouldHaveWeapon then
            -- Release weapon to sprint faster (if player far) or tackle (if player close)
            releaseRope(enemy)
        else
            -- Swing the weapon offensively at the player
            local obj = enemy.rope.object
            local ox, oy = obj.body:getPosition()
            local swingForceX = (playerX - ox) * 3
            local swingForceY = (playerY - oy) * 3
            obj.body:applyForce(swingForceX, swingForceY)
        end
    elseif shouldHaveWeapon then
        -- Scan for a suitable box to grab
        local nearestBox, nearestDist = nil, 200
        for _, obj in ipairs(box_i) do
            if obj.type == "box" and not obj.roped then
                local bx, by = obj.body:getPosition()
                local bDist = math.sqrt((ex-bx)^2 + (ey-by)^2)
                if bDist < nearestDist then nearestDist = bDist; nearestBox = obj end
            end
        end
        if nearestBox then
            enemy.rope = createRope(enemy, nearestBox)
            if enemy.rope then nearestBox.roped = true end
        end
    end

    -- 3. PREDICTIVE CHASING
    -- Lead the target slightly based on player velocity
    local predictionTime = math.min(distance / 200, 1.0)
    local targetX = playerX + (playerVx * predictionTime)
    local targetY = playerY + (playerVy * predictionTime)
    
    local desiredForceX = (targetX - ex) * forceMultiplier
    local desiredForceY = (targetY - ey) * forceMultiplier
    local forceMag = math.sqrt(desiredForceX^2 + desiredForceY^2)
    
    if forceMag > maxForce then
        local scale = maxForce / forceMag
        desiredForceX = desiredForceX * scale
        desiredForceY = desiredForceY * scale
    end
    
    body:applyForce(desiredForceX, desiredForceY)
    
    -- 4. AGGRESSIVE STABILIZATION
    local currentAngle = body:getAngle()
    local angularVelocity = body:getAngularVelocity()
    body:applyTorque(-currentAngle * 40 - angularVelocity * 3.5)
    
    -- Particles
    local bx, by = body:getWorldPoint(0, enemy.h / 2)
    createEnemyParticle(enemy, bx, by)
    createEnemyParticle(enemy, bx, by)
    updateEnemyParticles(enemy, dt)
end

function updateSingleEnemy(enemy, playerX, playerY, dt)
    local body = enemy.body
    local ex, ey = body:getPosition()
    local dx, dy = playerX - ex, playerY - ey
    
    local maxForce = 130
    local forceMag = math.sqrt(dx^2 + dy^2)
    local scale = math.min(maxForce / forceMag, 0.05)
    
    body:applyForce(dx * scale * forceMag, dy * scale * forceMag)
    body:applyTorque(-body:getAngle() * 30 - body:getAngularVelocity() * 2.5)
    
    local bx, by = body:getWorldPoint(0, enemy.h / 2)
    createEnemyParticle(enemy, bx, by)
    updateEnemyParticles(enemy, dt)
end

function updateEnemyParticles(enemy, dt)
    for i = #enemy.particles, 1, -1 do
        local p = enemy.particles[i]
        p.life = p.life - 20 * dt
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        if p.life <= 0 then table.remove(enemy.particles, i) end
    end
end

function createEnemyParticle(enemy, x, y)
    table.insert(enemy.particles, {
        x = x, y = y,
        vx = love.math.random(-0.5, 0.5), vy = love.math.random(-1.2, 0),
        life = 255
    })
end

function drawEnemies()
    for _, enemy in ipairs(enemies) do
        if enemy.damageFlash and enemy.damageFlash > 0 then
            local flashIntensity = math.sin(enemy.damageFlash * 30) * 0.5 + 0.5
            love.graphics.setColor(1, flashIntensity, flashIntensity)
        else love.graphics.setColor(0, 0, 0) end
        
        local x, y = enemy.body:getPosition()
        love.graphics.polygon("fill", enemy.body:getWorldPoints(enemy.shape:getPoints()))
        
        if enemy.health and enemy.health < enemy.maxHealth then
            local hpPercent = enemy.health / enemy.maxHealth
            love.graphics.setColor(1, 0, 0)
            love.graphics.rectangle("fill", x - 15, y - 20, 30, 4)
            love.graphics.setColor(0, 1, 0)
            love.graphics.rectangle("fill", x - 15, y - 20, 30 * hpPercent, 4)
        end
        
        love.graphics.setColor(enemy.smart and {1, 0.5, 0, 0.5} or {1, 0, 0, 0.5})
        love.graphics.print(enemy.smart and "S" or "E", x - 4, y - 4)
        
        if enemy.rope then
            love.graphics.setColor(0.5, 0.5, 0.5)
            local prevX, prevY = enemy.body:getPosition()
            for _, linkBody in ipairs(enemy.rope.bodies) do
                local lx, ly = linkBody:getPosition()
                love.graphics.line(prevX, prevY, lx, ly)
                prevX, prevY = lx, ly
            end
            if enemy.rope.joints[#enemy.rope.joints] then
                local ax, ay = enemy.rope.joints[#enemy.rope.joints]:getAnchors()
                love.graphics.line(prevX, prevY, ax, ay)
            end
        end
        
        for _, p in ipairs(enemy.particles) do
            love.graphics.setColor(1, 0.3, 0.3, p.life/255)
            love.graphics.circle("fill", p.x, p.y, 2)
        end
    end
end

-- ============================================================================
-- SCALED BOXES & BALLS
-- ============================================================================

function createBoxes()
    table.insert(box_i, createBoxObj(-800, 570, 8, 80, 0, 2, 0.2, ""))
    table.insert(box_i, createBoxObj(-840, 570, 8, 80, 0, 2, 0.2, ""))
    table.insert(box_i, createBoxObj(-820, 300, 80, 30, 0, 0.6, 0.2, ""))
    createBoxGrid(-1600, 800, 3, 3, 30, 30, 3, 0.1, 0.2)
    table.insert(box_i, createBoxObj(-900, 400, 20, 20, 0, 1.5, 0.3, ""))
    table.insert(box_i, createBoxObj(-750, 350, 15, 40, 0.5, 1.2, 0.2, ""))
    table.insert(box_i, createBoxObj(-1000, 600, 25, 25, 0, 2.0, 0.1, ""))
    table.insert(box_i, createBoxObj(-1100, 650, 12, 60, 0.3, 0.8, 0.4, ""))
end

function createBoxGrid(startX, startY, cols, rows, boxWidth, boxHeight, spacing, density, friction)
    for row = 0, rows - 1 do
        for col = 0, cols - 1 do
            local x = startX + (col * (boxWidth + spacing))
            local y = startY - (row * (boxHeight + spacing))
            table.insert(box_i, createBoxObj(x, y, boxWidth, boxHeight, 0, density, friction, string.format("x%d%d", col, row)))
        end
    end
end

function createBoxObj(x, y, w, h, angle, density, friction, label)
    local body = love.physics.newBody(world, x, y, "dynamic")
    local shape = love.physics.newRectangleShape(w, h)
    local fixture = love.physics.newFixture(body, shape, density or 1.0)
    fixture:setFriction(friction or 0.5)
    fixture:setRestitution(0.2)
    body:setAngle(angle or 0)
    
    -- Dynamically scale health based on Volume/Density
    local calcMaxHealth = math.max(10, math.floor((w * h * (density or 1.0)) / 4))
    
    return {
        type = "box", body = body, shape = shape, fixture = fixture,
        w = w, h = h, label = label or "Box",
        health = calcMaxHealth,
        maxHealth = calcMaxHealth,
        damageFlash = 0, roped = false
    }
end

function drawBoxes()
    for _, box in ipairs(box_i) do
        if box.type == "box" then
            if box.damageFlash and box.damageFlash > 0 then
                love.graphics.setColor(0, 0, 0, math.sin(box.damageFlash * 30) * 0.5 + 0.5)
            else love.graphics.setColor(0, 0, 0) end
            
            local x, y = box.body:getPosition()
            love.graphics.polygon("fill", box.body:getWorldPoints(box.shape:getPoints()))
            
            if box.health and box.health < box.maxHealth then
                local hpPercent = box.health / box.maxHealth
                love.graphics.setColor(1, 0, 0, 0.5)
                love.graphics.rectangle("fill", x - 15, y - 15, 30, 3)
                love.graphics.setColor(0, 1, 0, 0.5)
                love.graphics.rectangle("fill", x - 15, y - 15, 30 * hpPercent, 3)
            end
            
            love.graphics.push()
            love.graphics.translate(x, y)
            love.graphics.rotate(box.body:getAngle())
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.print(box.label or "", (-box.w / 2) + 2, -box.h / 2 + 2)
            love.graphics.pop()
        end
    end
end

function createBalls()
    table.insert(balls, createBallObj(260, 430, 12.5, -700, 2, 0.5))
    table.insert(balls, createBallObj(-390, 150, 25, -15, 1, 0.1))
    table.insert(balls, createBallObj(-1590, 1000, 28, 0, 0.1, 0.8))
    table.insert(balls, createBallObj(-1300, 1000, 30, 0, 0.05, 0.8))
end

function createBallObj(x, y, r, angularVelocity, density, friction)
    local body = love.physics.newBody(world, x, y, "dynamic")
    local shape = love.physics.newCircleShape(r)
    local fixture = love.physics.newFixture(body, shape, density or 1.0)
    fixture:setFriction(friction or 0.5)
    fixture:setRestitution(0.3)
    if angularVelocity then body:setAngularVelocity(angularVelocity) end
    
    -- Dynamically scale health based on Area/Density
    local calcMaxHealth = math.max(10, math.floor((math.pi * r * r * (density or 1.0)) / 4))
    
    local ball = {
        type = "ball", body = body, shape = shape, fixture = fixture,
        r = r, health = calcMaxHealth, maxHealth = calcMaxHealth, damageFlash = 0
    }
    table.insert(box_i, ball)
    return ball
end

function drawBalls()
    for _, ball in ipairs(balls) do
        if ball.damageFlash and ball.damageFlash > 0 then
            love.graphics.setColor(math.sin(ball.damageFlash * 30) * 0.5 + 0.5, 0.5, 0.5)
        else love.graphics.setColor(0, 0, 0) end
        
        local x, y = ball.body:getPosition()
        if ball.health and ball.health < ball.maxHealth then
            love.graphics.setColor(1, 0, 0)
            love.graphics.rectangle("fill", x - 15, y - ball.r - 5, 30, 3)
            love.graphics.setColor(0, 1, 0)
            love.graphics.rectangle("fill", x - 15, y - ball.r - 5, 30 * (ball.health / ball.maxHealth), 3)
        end
        
        love.graphics.setColor(0, 0, 0)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", x, y, ball.r)
        
        local cosA, sinA = math.cos(ball.body:getAngle()), math.sin(ball.body:getAngle())
        love.graphics.line(x - ball.r * cosA, y - ball.r * sinA, x + ball.r * cosA, y + ball.r * sinA)
        love.graphics.line(x - ball.r * sinA, y + ball.r * cosA, x + ball.r * sinA, y - ball.r * cosA)
        love.graphics.setLineWidth(1)
    end
end

-- ============================================================================
-- PLAYER FUNCTIONS
-- ============================================================================

function createPlayer()
    local body = love.physics.newBody(world, -820, 0, "dynamic")
    local shape = love.physics.newRectangleShape(12.5, 25)
    local fixture = love.physics.newFixture(body, shape, 1.0)
    fixture:setFriction(0.1)
    fixture:setRestitution(0.2)
    
    PlayerX[1] = {
        body = body, shape = shape, fixture = fixture,
        w = 12.5, h = 25, particles = {}, rope = nil,
        health = 200, maxHealth = 200, damageFlash = 0
    }
end

function updatePlayer(dt)
    if not PlayerX[1] then return end
    local player = PlayerX[1]
    local body = player.body
    
    if player.damageFlash then player.damageFlash = math.max(0, player.damageFlash - dt) end
    
    local bx, by = body:getWorldPoint(0, player.h / 2)
    if love.keyboard.isDown("right") then body:applyForce(30, 0) end
    if love.keyboard.isDown("left") then body:applyForce(-30, 0) end
    if love.keyboard.isDown("up") then body:applyForce(0, -60); createPlayerParticle(bx, by) end 
    if love.keyboard.isDown("down") then body:applyForce(0, 20); createPlayerParticle(bx, by) end
    
    body:applyTorque(-body:getAngle() * 30 - body:getAngularVelocity() * 2.5)
    
    if love.keyboard.isDown("pageup") then body:applyTorque(-45) end
    if love.keyboard.isDown("pagedown") then body:applyTorque(45) end
    
    for i = #player.particles, 1, -1 do
        local p = player.particles[i]
        p.life, p.x, p.y, p.vy = p.life - 20 * dt, p.x + p.vx * dt, p.y + p.vy * dt, p.vy + 0.05
        if p.life <= 0 then table.remove(player.particles, i) end
    end
end

function drawPlayer(player)
    if player.damageFlash and player.damageFlash > 0 then
        love.graphics.setColor(math.sin(player.damageFlash * 30) * 0.5 + 0.5, 0.5, 0.5)
    else love.graphics.setColor(0, 0, 0) end
    
    local x, y = player.body:getPosition()
    if player.health and player.health < player.maxHealth then
        love.graphics.setColor(1, 0, 0)
        love.graphics.rectangle("fill", x - 15, y - 30, 30, 4)
        love.graphics.setColor(0, 1, 0)
        love.graphics.rectangle("fill", x - 15, y - 30, 30 * (player.health / player.maxHealth), 4)
    end
    
    love.graphics.setColor(0, 0, 0)
    love.graphics.polygon("fill", player.body:getWorldPoints(player.shape:getPoints()))
    
    if player.rope then
        love.graphics.setLineWidth(1)
        local prevX, prevY = player.body:getWorldPoint(0, player.h / 2)
        for _, linkBody in ipairs(player.rope.bodies) do
            local lx, ly = linkBody:getPosition()
            love.graphics.line(prevX, prevY, lx, ly)
            prevX, prevY = lx, ly
        end
        if player.rope.joints[#player.rope.joints] then
            local ax, ay = player.rope.joints[#player.rope.joints]:getAnchors()
            love.graphics.line(prevX, prevY, ax, ay)
        end
    end
    
    for _, p in ipairs(player.particles) do
        love.graphics.setColor(1, 1, 1, p.life/255)
        love.graphics.circle("fill", p.x, p.y, 1.5)
    end
    love.graphics.setColor(0, 1, 0, 0.5)
    love.graphics.print("$", x - 4, y - 4)
end

function createPlayerParticle(x, y)
    table.insert(PlayerX[1].particles, { x = x, y = y, vx = love.math.random(-1, 1), vy = love.math.random(-1.5, 0), life = 255 })
end

-- ============================================================================
-- BOUNDARY FUNCTIONS
-- ============================================================================

function createBoundaries()
    table.insert(boundaries, createBoundary(320, 500, 600, 10, 0))
    table.insert(boundaries, createBoundary(-100, 350, 600, 10, 0.3))
    table.insert(boundaries, createBoundary(-485, 261, 200, 10, 0))
    table.insert(boundaries, createBoundary(-265, 589, 600, 10, -0.3))
    table.insert(boundaries, createBoundary(-700, 605, 300, 10, 0))
    table.insert(boundaries, createBoundary(-700, 678, 300, 10, 0))
    table.insert(boundaries, createBoundary(-1260, 820, 300, 10, 0))
    table.insert(boundaries, createBoundary(-1540, 825, 180, 10, 0))
    table.insert(boundaries, createBoundary(-1565, 1005, 250, 10, 0))
    table.insert(boundaries, createBoundary(-1300, 1005, 250, 10, 0))
    table.insert(boundaries, createBoundary(-1685, 905, 10, 200, 0))
    table.insert(boundaries, createBoundary(-980, 749, 300, 10, -0.5))
    table.insert(boundaries, createBoundary(-440, 620, 80, 5, 0.4))
end

function createBoundary(x, y, w, h, angle)
    local body = love.physics.newBody(world, x, y, "static")
    local shape = love.physics.newRectangleShape(w, h)
    local fixture = love.physics.newFixture(body, shape)
    fixture:setFriction(0.5)
    fixture:setRestitution(0.2)
    body:setAngle(angle)
    return { body = body, shape = shape, fixture = fixture, w = w, h = h }
end

function drawBoundaries()
    love.graphics.setColor(0, 0, 0)
    for _, b in ipairs(boundaries) do love.graphics.polygon("fill", b.body:getWorldPoints(b.shape:getPoints())) end
end

-- ============================================================================
-- PARTICLE FUNCTIONS
-- ============================================================================

function updateParticles(dt)
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.life, p.x, p.y, p.vy = p.life - 20 * dt, p.x + p.vx * dt, p.y + p.vy * dt, p.vy + 0.05
        if p.life <= 0 then table.remove(particles, i) end
    end
end

function drawParticles()
    for _, p in ipairs(particles) do
        love.graphics.setColor(1, 1, 1, p.life/255)
        love.graphics.circle("fill", p.x, p.y, 1)
    end
end