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
        "E: Grab Enemy/Box",
        "SHIFT: Connect two objects & detach"
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
            -- Only release ropes if BOTH ropes are attached
            if PlayerX[1].rope1 and PlayerX[1].rope2 then 
                releaseRope(PlayerX[1]) 
            else 
                grabObject() 
            end
        end
    elseif key == "e" then
        if PlayerX[1] and not (PlayerX[1].rope1 and PlayerX[1].rope2) then 
            grabEnemy() 
        end
    elseif key == "lshift" or key == "rshift" then
        if PlayerX[1] then
            -- Only connect when BOTH ropes are attached
            if PlayerX[1].rope1 and PlayerX[1].rope2 then
                connectTwoObjectsAndDetach()
            end
        end
    end
end

function love.wheelmoved(x, y)
    local zoomFactor = 1.1
    if y > 0 then camera.scale = math.min(camera.scale * zoomFactor, camera.maxScale)
    elseif y < 0 then camera.scale = math.max(camera.scale / zoomFactor, camera.minScale)
    end
end

-- UI and Debug Functions
function drawUI()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("State: " .. game.state, 10, 10)
    
    if PlayerX[1] then
        local px, py = PlayerX[1].body:getPosition()
        love.graphics.print("Player Position: " .. math.floor(px) .. ", " .. math.floor(py), 10, 30)
        
        -- Display rope status
        if PlayerX[1].rope1 then
            love.graphics.setColor(0.3, 1, 0.3)
            love.graphics.print("Rope 1: Connected!", 10, 250)
        end
        if PlayerX[1].rope2 then
            love.graphics.setColor(0.3, 0.3, 1)
            love.graphics.print("Rope 2: Connected!", 10, 270)
        end
        if not PlayerX[1].rope1 and not PlayerX[1].rope2 then
            love.graphics.setColor(1, 1, 1)
            love.graphics.print("No ropes attached", 10, 250)
        end
        love.graphics.setColor(1, 1, 1)
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
    
    love.graphics.print("Game Controls:", love.graphics.getWidth() - 200, 210)
    love.graphics.print("Arrow Keys: Move Player", love.graphics.getWidth() - 200, 230)
    love.graphics.print("PageUp/Down: Rotate", love.graphics.getWidth() - 200, 250)
    love.graphics.print("P: Pause/Resume", love.graphics.getWidth() - 200, 270)
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
        if enemy and enemy.body and not enemy.body:isDestroyed() then
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
    if PlayerX[1] and PlayerX[1].body and not PlayerX[1].body:isDestroyed() then
        local px, py = PlayerX[1].body:getPosition()
        for i, enemy in ipairs(enemies) do
            if enemy.body and not enemy.body:isDestroyed() then
                local ex, ey = enemy.body:getPosition()
                local dx, dy = px - ex, py - ey
                if math.sqrt(dx*dx + dy*dy) < 30 then
                    applyDamage(enemy, 10)
                    createDamageEffect(ex, ey)
                end
            end
        end
        for _, box in ipairs(box_i) do
            if box.type == "box" and box.body and not box.body:isDestroyed() then
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
    
    -- For boxes, damage is reduced based on slice depth (makes them harder)
    if obj.type == "box" and obj.sliceDepth then
        local damageReduction = math.pow(0.85, obj.sliceDepth)  -- 15% less damage per depth
        damage = damage * damageReduction
    end
    
    obj.health = obj.health - damage
    obj.damageFlash = 0.2
    
    if obj.health <= 0 then 
        destroyObject(obj)
    end
end

function destroyObject(obj)
    if not obj or not obj.body or obj.body:isDestroyed() then return end
    
    local x, y = obj.body:getPosition()
    
    -- Create damage effects on destruction/slicing
    for i = 1, 20 do createDamageEffect(x, y) end
    
    -- Safely destroy independent merged ropes attached to this object
    if obj.rope then
        destroyRope(obj.rope)
    end
    
    -- Check if this object is roped by an enemy
    for _, enemy in ipairs(enemies) do
        if enemy.rope and enemy.rope.object == obj then
            destroyRope(enemy.rope)
        end
    end
    
    -- Check if player is holding this object
    if PlayerX[1] then
        if PlayerX[1].rope1 and PlayerX[1].rope1.object == obj then
            releaseSingleRope(PlayerX[1], 1)
        end
        if PlayerX[1].rope2 and PlayerX[1].rope2.object == obj then
            releaseSingleRope(PlayerX[1], 2)
        end
    end
    
    -- Handle different object types removal
    if obj.type == "enemy" then
        for i, enemy in ipairs(enemies) do
            if enemy == obj then table.remove(enemies, i); break end
        end
        if obj.body and not obj.body:isDestroyed() then obj.body:destroy() end
        
    elseif obj.type == "box" then
        sliceBox(obj)
        for i, box in ipairs(box_i) do
            if box == obj then table.remove(box_i, i); break end
        end
        if obj.body and not obj.body:isDestroyed() then obj.body:destroy() end
        
    elseif obj.type == "ball" then
        for i, ball in ipairs(balls) do
            if ball == obj then table.remove(balls, i); break end
        end
        for i, box in ipairs(box_i) do
            if box == obj then table.remove(box_i, i); break end
        end
        if obj.body and not obj.body:isDestroyed() then obj.body:destroy() end
    end
end

function sliceBox(box)
    if not box or box.type ~= "box" then return end
    
    local x, y = box.body:getPosition()
    local angle = box.body:getAngle()
    local w = box.w
    local h = box.h
    
    -- Determine which side is larger to slice along that axis
    local sliceVertical = (w >= h)  -- Slice along vertical axis if width >= height
    
    local newWidth1, newWidth2, newHeight1, newHeight2
    local sliceOffset
    
    if sliceVertical then
        sliceOffset = w * (0.3 + love.math.random() * 0.4)
        newWidth1 = sliceOffset
        newWidth2 = w - sliceOffset
        newHeight1 = h
        newHeight2 = h
    else
        sliceOffset = h * (0.3 + love.math.random() * 0.4)
        newWidth1 = w
        newWidth2 = w
        newHeight1 = sliceOffset
        newHeight2 = h - sliceOffset
    end
    
    -- Ensure minimum size for boxes
    local minSize = 5
    if newWidth1 < minSize or newWidth2 < minSize or newHeight1 < minSize or newHeight2 < minSize then
        return
    end
    
    -- Calculate positions for the two new boxes
    local x1, y1, x2, y2
    
    local localSlicePoint
    if sliceVertical then
        localSlicePoint = {x = -w/2 + sliceOffset, y = 0}
    else
        localSlicePoint = {x = 0, y = -h/2 + sliceOffset}
    end
    
    local cosA, sinA = math.cos(angle), math.sin(angle)
    local worldSliceX = x + (localSlicePoint.x * cosA - localSlicePoint.y * sinA)
    local worldSliceY = y + (localSlicePoint.x * sinA + localSlicePoint.y * cosA)
    
    if sliceVertical then
        local offset1X = (-w/2 + sliceOffset/2) * cosA
        local offset1Y = (-w/2 + sliceOffset/2) * sinA
        local offset2X = (w/2 - sliceOffset/2) * cosA
        local offset2Y = (w/2 - sliceOffset/2) * sinA
        
        x1 = x + offset1X
        y1 = y + offset1Y
        x2 = worldSliceX + offset2X
        y2 = worldSliceY + offset2Y
    else
        local offset1Y = (-h/2 + sliceOffset/2) * cosA
        local offset1X = (-h/2 + sliceOffset/2) * -sinA
        local offset2Y = (h/2 - sliceOffset/2) * cosA
        local offset2X = (h/2 - sliceOffset/2) * -sinA
        
        x1 = x + offset1X
        y1 = y + offset1Y
        x2 = worldSliceX + offset2X
        y2 = worldSliceY + offset2Y
    end
    
    local healthMultiplier = 1.5
    local newArea1 = newWidth1 * newHeight1
    local newArea2 = newWidth2 * newHeight2
    
    local currentDepth = box.sliceDepth or 0
    local newDepth = currentDepth + 1
    
    local baseHealthPerArea = 2.5
    local newHealth1 = math.max(10, math.floor(newArea1 * baseHealthPerArea * math.pow(healthMultiplier, newDepth)))
    local newHealth2 = math.max(10, math.floor(newArea2 * baseHealthPerArea * math.pow(healthMultiplier, newDepth)))
    
    local density = box.fixture:getDensity()
    local friction = box.fixture:getFriction()
    
    local newBox1 = createBoxObj(x1, y1, newWidth1, newHeight1, angle, density, friction, 
        string.format("%s_A%d", box.label or "Box", newDepth))
    newBox1.sliceDepth = newDepth
    newBox1.maxHealth = newHealth1
    newBox1.health = newHealth1
    newBox1.damageFlash = 0.3
    
    local newBox2 = createBoxObj(x2, y2, newWidth2, newHeight2, angle, density, friction,
        string.format("%s_B%d", box.label or "Box", newDepth))
    newBox2.sliceDepth = newDepth
    newBox2.maxHealth = newHealth2
    newBox2.health = newHealth2
    newBox2.damageFlash = 0.3
    
    local originalVx, originalVy = box.body:getLinearVelocity()
    local originalAngularVel = box.body:getAngularVelocity()
    
    newBox1.body:setLinearVelocity(originalVx + love.math.random(-20, 20), originalVy + love.math.random(-20, 20))
    newBox2.body:setLinearVelocity(originalVx + love.math.random(-20, 20), originalVy + love.math.random(-20, 20))
    newBox1.body:setAngularVelocity(originalAngularVel + love.math.random(-0.5, 0.5))
    newBox2.body:setAngularVelocity(originalAngularVel + love.math.random(-0.5, 0.5))
    
    table.insert(box_i, newBox1)
    table.insert(box_i, newBox2)
    
    for i = 1, 15 do
        createDamageEffect(x, y)
        createDamageEffect(x1, y1)
        createDamageEffect(x2, y2)
    end
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
-- DUAL ROPE SYSTEM
-- ============================================================================

function createRope(obj1, obj2)
    if not obj1 or not obj2 or not obj1.body or not obj2.body then return nil end
    if obj1.body:isDestroyed() or obj2.body:isDestroyed() then return nil end
    
    -- Target the nearest edge instead of the centers
    local cx2, cy2 = obj2.body:getPosition()
    local x1, y1 = getEdgePoint(obj1, cx2, cy2)
    
    local cx1, cy1 = obj1.body:getPosition()
    local x2, y2 = getEdgePoint(obj2, cx1, cy1)
    
    local rope = { bodies = {}, joints = {}, obj1 = obj1, obj2 = obj2 }
    local dx, dy = x2 - x1, y2 - y1
    local distance = math.sqrt(dx*dx + dy*dy)
    
    local numSegments = 15
    local angle = math.atan2(dy, dx)
    
    local segLength = distance / numSegments
    local segThickness = 3 -- Visual thickness
    
    -- Unit direction vectors for moving along the rope line
    local ux = dx / distance
    local uy = dy / distance
    
    local prevBody = obj1.body
    local prevX, prevY = x1, y1
    
    for i = 1, numSegments do
        -- Position center point of the current rectangle link
        local cx = x1 + ux * (segLength * (i - 0.5))
        local cy = y1 + uy * (segLength * (i - 0.5))
        
        local segBody = love.physics.newBody(world, cx, cy, "dynamic")
        segBody:setAngle(angle)
        
        local segShape = love.physics.newRectangleShape(segLength, segThickness)
        local segFixture = love.physics.newFixture(segBody, segShape, 0.5)
        segFixture:setSensor(true) -- Prevent clipping explosions
        segFixture:setFriction(0.2)
        
        -- High damping eliminates sudden physics oscillations
        segBody:setLinearDamping(6.0)
        segBody:setAngularDamping(6.0)
        
        table.insert(rope.bodies, segBody)
        
        -- Revolute joint links the END of the previous body to the START of this link
        table.insert(rope.joints, love.physics.newRevoluteJoint(prevBody, segBody, prevX, prevY, false))
        
        -- Advance the structural connection point to the END of this current rectangle link
        prevBody = segBody
        prevX = x1 + ux * (segLength * i)
        prevY = y1 + uy * (segLength * i)
    end
    
    -- Link the end edge of the last segment directly to the second target object boundary
    table.insert(rope.joints, love.physics.newRevoluteJoint(prevBody, obj2.body, x2, y2, false))
    
    -- Backing limit rope constraint holds the sequence together tightly
    rope.limitRope = love.physics.newRopeJoint(obj1.body, obj2.body, x1, y1, x2, y2, distance + 2, false)
    
    return rope
end

function connectTwoObjectsAndDetach()
    local player = PlayerX[1]
    if not player then return end
    
    if not player.rope1 or not player.rope2 then return end
    
    local rope1 = player.rope1
    local rope2 = player.rope2
    
    local obj1 = rope1.object
    local obj2 = rope2.object
    
    if not obj1 or not obj2 or not obj1.body or not obj2.body then return end
    if obj1.body:isDestroyed() or obj2.body:isDestroyed() then return end
    
    -- Ensure tracking arrays are ready
    obj1.ropes = obj1.ropes or {}
    obj2.ropes = obj2.ropes or {}
    
    local jx, jy = player.body:getWorldPoint(0, player.h / 2)
    
    -- 1. Unbind the player anchors instantly
    if rope1.joints[1] and not rope1.joints[1]:isDestroyed() then rope1.joints[1]:destroy() end
    if rope2.joints[1] and not rope2.joints[1]:isDestroyed() then rope2.joints[1]:destroy() end
    
    -- 2. Fuse the two loose ends smoothly right where they met at the center
    local linkJoint = love.physics.newRevoluteJoint(rope1.bodies[1], rope2.bodies[1], jx, jy, false)
    
    -- 3. Transition the overall structural limits safely
    local len1 = (rope1.limitRope and not rope1.limitRope:isDestroyed()) and rope1.limitRope:getMaxLength() or 200
    local len2 = (rope2.limitRope and not rope2.limitRope:isDestroyed()) and rope2.limitRope:getMaxLength() or 200
    
    if rope1.limitRope and not rope1.limitRope:isDestroyed() then rope1.limitRope:destroy() end
    if rope2.limitRope and not rope2.limitRope:isDestroyed() then rope2.limitRope:destroy() end
    
    local x1, y1 = obj1.body:getPosition()
    local x2, y2 = obj2.body:getPosition()
    local limitRope = love.physics.newRopeJoint(obj1.body, obj2.body, x1, y1, x2, y2, len1 + len2, false)
    
    -- 4. Construct a perfect linear array map for drawing loops
    local mergedRope = {
        bodies = {},
        joints = {},
        obj1 = obj1,
        obj2 = obj2,
        limitRope = limitRope,
        object = obj2
    }
    
    -- TRICK: rope1 flowed from Player (1) out to Obj1 (#bodies). 
    -- We load it sequentially from index 1 up to #bodies, making Obj1 the starting root point.
    for i = 1, #rope1.bodies do
        local b = rope1.bodies[i]
        b:setLinearDamping(8.0) -- Stabilize independent cable physics weight
        b:setAngularDamping(8.0)
        table.insert(mergedRope.bodies, b)
    end
    
    -- TRICK: rope2 flowed from Player (1) out to Obj2 (#bodies). 
    -- We append rope2 by starting at its outer tip (#bodies) and tracing backwards down to (1).
    -- This forms a perfect straight pipeline link: Obj1 -> Center Fusion -> Obj2.
    for i = #rope2.bodies, 1, -1 do
        local b = rope2.bodies[i]
        b:setLinearDamping(8.0)
        b:setAngularDamping(8.0)
        table.insert(mergedRope.bodies, b)
    end
    
    -- Keep inner joint elements bound together so removals/cleans behave safely
    table.insert(mergedRope.joints, linkJoint)
    for i = 2, #rope1.joints do table.insert(mergedRope.joints, rope1.joints[i]) end
    for i = 2, #rope2.joints do table.insert(mergedRope.joints, rope2.joints[i]) end
    
    -- Store rope structures into object indexes so drawing functions draw it properly
    obj1.rope = mergedRope
    obj2.rope = mergedRope
    table.insert(obj1.ropes, mergedRope)
    table.insert(obj2.ropes, mergedRope)
    
    obj1.roped = true
    obj2.roped = true
    
    -- Fully wipe references from player space
    player.rope1 = nil
    player.rope2 = nil
    
    for i = 1, 20 do createDamageEffect(jx, jy) end
end

function destroyRope(rope)
    if not rope then return end
    if rope.limitRope and not rope.limitRope:isDestroyed() then
        rope.limitRope:destroy()
    end
    if rope.joints then
        for _, joint in ipairs(rope.joints) do
            if joint and not joint:isDestroyed() then joint:destroy() end
        end
    end
    if rope.bodies then
        for _, body in ipairs(rope.bodies) do
            if body and not body:isDestroyed() then body:destroy() end
        end
    end
    if rope.obj1 then rope.obj1.rope = nil; rope.obj1.roped = false end
    if rope.obj2 then rope.obj2.rope = nil; rope.obj2.roped = false end
end

-- ============================================================================
-- NEW HELPER FUNCTIONS
-- ============================================================================

-- Calculates the nearest edge intersection on a body towards a target point
function getEdgePoint(obj, targetX, targetY)
    if not obj or not obj.body then return targetX, targetY end
    if obj.body:isDestroyed() then return targetX, targetY end
    
    local cx, cy = obj.body:getPosition()
    local dx, dy = targetX - cx, targetY - cy
    local dist = math.sqrt(dx*dx + dy*dy)
    if dist == 0 then return cx, cy end
    dx, dy = dx/dist, dy/dist

    if obj.type == "ball" then
        return cx + dx * obj.r, cy + dy * obj.r
    elseif obj.type == "box" or obj.type == "enemy" or obj.type == "player" then
        local angle = obj.body:getAngle()
        local cosA, sinA = math.cos(-angle), math.sin(-angle)
        
        -- Convert direction to local object space
        local ldx = dx * cosA - dy * sinA
        local ldy = dx * sinA + dy * cosA
        
        local hw = (obj.w or 20) / 2
        local hh = (obj.h or 20) / 2
        
        -- Ray intersection with bounding box
        local tx = (ldx ~= 0) and math.abs(hw / ldx) or math.huge
        local ty = (ldy ~= 0) and math.abs(hh / ldy) or math.huge
        local t = math.min(tx, ty)
        
        local lx = ldx * t
        local ly = ldy * t
        
        -- Convert back to world space
        cosA, sinA = math.cos(angle), math.sin(angle)
        return cx + (lx * cosA - ly * sinA), cy + (lx * sinA + ly * cosA)
    end
    
    return cx, cy
end

-- Safely removes a rope from the physics world and unbinds it from both objects
function removeSpecificRope(rope)
    if not rope then return end
    if rope.limitRope and not rope.limitRope:isDestroyed() then rope.limitRope:destroy() end
    for _, joint in ipairs(rope.joints) do
        if joint and not joint:isDestroyed() then joint:destroy() end
    end
    for _, body in ipairs(rope.bodies) do
        if body and not body:isDestroyed() then body:destroy() end
    end
    
    -- Unbind from objects
    if rope.obj1 and rope.obj1.ropes then
        for i = #rope.obj1.ropes, 1, -1 do
            if rope.obj1.ropes[i] == rope then table.remove(rope.obj1.ropes, i) end
        end
    end
    if rope.obj2 and rope.obj2.ropes then
        for i = #rope.obj2.ropes, 1, -1 do
            if rope.obj2.ropes[i] == rope then table.remove(rope.obj2.ropes, i) end
        end
    end
end

-- Unified drawing function for object ropes
function drawRope(rope)
    if not rope or not rope.bodies then return end
    
    love.graphics.setColor(0, 0, 0, 1) -- Matches the clean black line aesthetic of your objects
    
    for _, linkBody in ipairs(rope.bodies) do
        if linkBody and not linkBody:isDestroyed() then
            local fixtures = linkBody:getFixtures()
            if fixtures[1] then
                local shape = fixtures[1]:getShape()
                if shape:getType() == "polygon" then
                    love.graphics.polygon("fill", linkBody:getWorldPoints(shape:getPoints()))
                end
            end
        end
    end
end

function grabObject()
    local player = PlayerX[1]
    if not player or (player.rope1 and player.rope2) then return end
    
    local px, py = player.body:getWorldPoint(0, player.h / 2)
    local closestObj, closestDist = nil, 200

    for _, obj in ipairs(box_i) do
        if (obj.type == "box" or obj.type == "ball") and obj.body and not obj.body:isDestroyed() then
            if (player.rope1 and player.rope1.object == obj) or (player.rope2 and player.rope2.object == obj) then
                goto continue
            end
            local ox, oy = obj.body:getPosition()
            local dist = math.sqrt((px-ox)^2 + (py-oy)^2)
            if dist < closestDist then
                closestDist = dist
                closestObj = obj
            end
        end
        ::continue::
    end

    if closestObj then
        local newRope = createRope(player, closestObj)
        if newRope then
            newRope.object = closestObj
            if not player.rope1 then
                player.rope1 = newRope
            elseif not player.rope2 then
                player.rope2 = newRope
            end
        end
    end
end

function grabEnemy()
    local player = PlayerX[1]
    if not player or (player.rope1 and player.rope2) then return end
    
    local px, py = player.body:getWorldPoint(0, player.h / 2)
    local closestEnemy, closestDist = nil, 200
    
    for _, enemy in ipairs(enemies) do
        if enemy.body and not enemy.body:isDestroyed() then
            if (player.rope1 and player.rope1.object == enemy) or (player.rope2 and player.rope2.object == enemy) then
                goto continue
            end
            local ex, ey = enemy.body:getPosition()
            local dist = math.sqrt((px-ex)^2 + (py-ey)^2)
            if dist < closestDist then
                closestDist = dist
                closestEnemy = enemy
            end
        end
        ::continue::
    end
    
    if closestEnemy then
        local newRope = createRope(player, closestEnemy)
        if newRope then
            newRope.object = closestEnemy
            if not player.rope1 then
                player.rope1 = newRope
            elseif not player.rope2 then
                player.rope2 = newRope
            end
        end
    end
end

function releaseSingleRope(entity, ropeNumber)
    if not entity then return end
    local rope = nil
    if ropeNumber == 1 then
        rope = entity.rope1
        entity.rope1 = nil
    elseif ropeNumber == 2 then
        rope = entity.rope2
        entity.rope2 = nil
    end
    removeSpecificRope(rope)
end


function releaseRope(entity)
    if entity then
        releaseSingleRope(entity, 1)
        releaseSingleRope(entity, 2)
    end
end

-- ============================================================================
-- SIMPLE ENEMY AI
-- ============================================================================

function createEnemies()
    -- table.insert(enemies, createEnemyObj(-8900, -520, 12.5, 25, 0))
    -- table.insert(enemies, createEnemyObj(-8850, -550, 15, 20, 0))
end

function createEnemyObj(x, y, w, h, angle)
    local body = love.physics.newBody(world, x, y, "dynamic")
    local shape = love.physics.newRectangleShape(w, h)
    local fixture = love.physics.newFixture(body, shape, 1.2)
    fixture:setFriction(0.1)
    fixture:setRestitution(0.2)
    
    local calcMaxHealth = math.floor((w * h) / 3) 
    
    local enemy = {
        type = "enemy", body = body, shape = shape, fixture = fixture,
        w = w, h = h, particles = {},
        ropes = {},
        health = calcMaxHealth, maxHealth = calcMaxHealth,
        damageFlash = 0, thrusterCooldown = 0
    }
    table.insert(box_i, enemy)
    return enemy
end


function updateEnemies(dt)
    if not PlayerX[1] or not PlayerX[1].body or PlayerX[1].body:isDestroyed() then return end
    local playerX, playerY = PlayerX[1].body:getPosition()
    
    for _, enemy in ipairs(enemies) do
        if enemy.body and not enemy.body:isDestroyed() then
            updateSingleEnemy(enemy, playerX, playerY, dt)
            if enemy.damageFlash then 
                enemy.damageFlash = math.max(0, enemy.damageFlash - dt) 
            end
            
            -- Update enemy particles with faster fade
            for i = #enemy.particles, 1, -1 do
                local p = enemy.particles[i]
                p.life = p.life - dt * 250
                p.x = p.x + p.vx * dt
                p.y = p.y + p.vy * dt
                if p.life <= 0 then 
                    table.remove(enemy.particles, i) 
                end
            end
        end
    end
end

function updateSingleEnemy(enemy, playerX, playerY, dt)
    local body = enemy.body
    local ex, ey = body:getPosition()
    local dx, dy = playerX - ex, playerY - ey
    
    -- Update thruster cooldown
    if enemy.thrusterCooldown then
        enemy.thrusterCooldown = math.max(0, enemy.thrusterCooldown - dt)
    else
        enemy.thrusterCooldown = 0
    end
    
    local maxForce = 130
    local forceMag = math.sqrt(dx^2 + dy^2)
    if forceMag > 0 then
        local scale = math.min(maxForce / forceMag, 0.05)
        body:applyForce(dx * scale * forceMag, dy * scale * forceMag)
    end
    
    -- Create thruster particles for basic enemies
    local vx, vy = body:getLinearVelocity()
    local speed = math.sqrt(vx^2 + vy^2)
    if speed > 20 and enemy.thrusterCooldown <= 0 then
        local angle = math.atan2(vy, vx)
        local backX = ex - math.cos(angle) * (enemy.w / 2)
        local backY = ey - math.sin(angle) * (enemy.h / 2)
        createEnemyThrusterParticle(backX, backY, 
            -vx * 0.3 + love.math.random(-10, 10), 
            -vy * 0.3 + love.math.random(-10, 10), 
            1)
        enemy.thrusterCooldown = 0.08
    end
    
    body:applyTorque(-body:getAngle() * 30 - body:getAngularVelocity() * 2.5)
    
    local bx, by = body:getWorldPoint(0, enemy.h / 2)
    createEnemyParticle(enemy, bx, by)
end

function createEnemyThrusterParticle(x, y, vx, vy, size)
    table.insert(particles, {
        x = x, y = y,
        vx = vx, vy = vy,
        life = 20,
        fadeSpeed = 250,
        size = size or 1.5,
        type = "enemy_thruster",
        scale = 1
    })
end

function createEnemyParticle(enemy, x, y)
    table.insert(enemy.particles, {
        x = x, y = y,
        vx = love.math.random(-0.5, 0.5), 
        vy = love.math.random(-1.2, 0),
        life = 20
    })
end

function drawEnemies()
    for _, enemy in ipairs(enemies) do
        if not enemy.body or enemy.body:isDestroyed() then goto continue end
        
        if enemy.damageFlash and enemy.damageFlash > 0 then
            local flashIntensity = math.sin(enemy.damageFlash * 30) * 0.5 + 0.5
            love.graphics.setColor(1, flashIntensity, flashIntensity)
        else 
            love.graphics.setColor(0, 0, 0) 
        end
        
        local x, y = enemy.body:getPosition()
        love.graphics.polygon("fill", enemy.body:getWorldPoints(enemy.shape:getPoints()))
        
        if enemy.health and enemy.health < enemy.maxHealth then
            local hpPercent = enemy.health / enemy.maxHealth
            love.graphics.setColor(1, 0, 0)
            love.graphics.rectangle("fill", x - 15, y - 20, 30, 4)
            love.graphics.setColor(0, 1, 0)
            love.graphics.rectangle("fill", x - 15, y - 20, 30 * hpPercent, 4)
        end
        
        love.graphics.setColor(1, 0, 0, 0.5)
        love.graphics.print("E", x - 4, y - 4)
        
        if enemy.ropes then
            for _, rope in ipairs(enemy.ropes) do
                if rope.obj1 == enemy then drawRope(rope) end
            end
        end
        
        for _, p in ipairs(enemy.particles) do
            local alpha = math.min(1, p.life / 30)
            love.graphics.setColor(1, 0.3, 0.3, alpha)
            love.graphics.circle("fill", p.x, p.y, 2)
        end
        
        ::continue::
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
    
    local calcMaxHealth = math.max(10, math.floor((w * h * (density or 1.0)) / 4))
    
    return {
        type = "box", body = body, shape = shape, fixture = fixture,
        w = w, h = h, label = label or "Box",
        health = calcMaxHealth, maxHealth = calcMaxHealth,
        damageFlash = 0, ropes = {}, sliceDepth = 0
    }
end

function drawBoxes()
    for _, box in ipairs(box_i) do
        if box.type == "box" and box.body and not box.body:isDestroyed() then
            if box.damageFlash and box.damageFlash > 0 then
                love.graphics.setColor(0, 0, 0, math.sin(box.damageFlash * 30) * 0.5 + 0.5)
            else 
                love.graphics.setColor(0, 0, 0) 
            end
            
            local x, y = box.body:getPosition()
            love.graphics.polygon("fill", box.body:getWorldPoints(box.shape:getPoints()))
            
            if box.ropes then
                for _, rope in ipairs(box.ropes) do
                    -- Only draw from obj1's pass to prevent doubling up on visuals
                    if rope.obj1 == box then drawRope(rope) end
                end
            end
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
    
    local calcMaxHealth = math.max(10, math.floor((math.pi * r * r * (density or 1.0)) / 4))
    
    local ball = {
        type = "ball", body = body, shape = shape, fixture = fixture,
        r = r, health = calcMaxHealth, maxHealth = calcMaxHealth, 
        damageFlash = 0, ropes = {}
    }
    table.insert(box_i, ball)
    return ball
end

function drawBalls()
    for _, ball in ipairs(balls) do
        if ball.body and not ball.body:isDestroyed() then
            if ball.damageFlash and ball.damageFlash > 0 then
                love.graphics.setColor(math.sin(ball.damageFlash * 30) * 0.5 + 0.5, 0.5, 0.5)
            else 
                love.graphics.setColor(0, 0, 0) 
            end
            
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
            
            if ball.ropes then
                for _, rope in ipairs(ball.ropes) do
                    if rope.obj1 == ball then drawRope(rope) end
                end
            end
        end
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
        w = 12.5, h = 25, particles = {}, 
        rope1 = nil, rope2 = nil, -- Dual ropes
        health = 200, maxHealth = 200, damageFlash = 0,
        thrusterCooldown = 0
    }
end

function updatePlayer(dt)
    if not PlayerX[1] or not PlayerX[1].body or PlayerX[1].body:isDestroyed() then return end
    local player = PlayerX[1]
    local body = player.body
    
    if player.damageFlash then player.damageFlash = math.max(0, player.damageFlash - dt) end
    
    if player.thrusterCooldown then
        player.thrusterCooldown = math.max(0, player.thrusterCooldown - dt)
    else
        player.thrusterCooldown = 0
    end
    
    local bx, by = body:getWorldPoint(0, player.h / 2)
    local thrusting = false
    
    if love.keyboard.isDown("right") then 
        body:applyForce(30, 0)
        if player.thrusterCooldown <= 0 then
            createEnhancedThrusterParticle(bx - 5, by, -30, love.math.random(-10, 10), 0.8)
            player.thrusterCooldown = 0.03
        end
        thrusting = true
    end
    if love.keyboard.isDown("left") then 
        body:applyForce(-30, 0)
        if player.thrusterCooldown <= 0 then
            createEnhancedThrusterParticle(bx + 5, by, 30, love.math.random(-10, 10), 0.8)
            player.thrusterCooldown = 0.03
        end
        thrusting = true
    end
    if love.keyboard.isDown("up") then 
        body:applyForce(0, -60)
        if player.thrusterCooldown <= 0 then
            for i = 1, 3 do
                createEnhancedThrusterParticle(bx, by + 10, love.math.random(-15, 15), -40 - love.math.random(0, 20), 0.5 + love.math.random())
            end
            player.thrusterCooldown = 0.02
        end
        thrusting = true
    end
    if love.keyboard.isDown("down") then 
        body:applyForce(0, 20)
        if player.thrusterCooldown <= 0 then
            createEnhancedThrusterParticle(bx, by - 10, love.math.random(-15, 15), 30 + love.math.random(0, 20), 0.8)
            player.thrusterCooldown = 0.03
        end
        thrusting = true
    end
    
    if not thrusting and love.math.random() < 0.02 then
        createSmallSmokeParticle(bx, by, love.math.random(-5, 5), love.math.random(-2, 2), 0.5)
    end
    
    body:applyTorque(-body:getAngle() * 30 - body:getAngularVelocity() * 2.5)
    
    if love.keyboard.isDown("pageup") then body:applyTorque(-45) end
    if love.keyboard.isDown("pagedown") then body:applyTorque(45) end
    
    for i = #player.particles, 1, -1 do
        local p = player.particles[i]
        p.life = p.life - dt * 300
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + 0.05
        if p.life <= 0 then 
            table.remove(player.particles, i) 
        end
    end
end

function createEnhancedThrusterParticle(x, y, vx, vy, size)
    table.insert(particles, {
        x = x, y = y,
        vx = vx, vy = vy,
        life = 30,
        fadeSpeed = 200,
        size = size or 2,
        type = "thruster",
        scale = 1
    })
end

function createSmallSmokeParticle(x, y, vx, vy, size)
    table.insert(particles, {
        x = x, y = y,
        vx = vx, vy = vy,
        life = 20,
        fadeSpeed = 150,
        size = size or 1,
        type = "smoke",
        scale = 1
    })
end

function drawPlayer(player)
    if not player or not player.body or player.body:isDestroyed() then return end
    
    if player.damageFlash and player.damageFlash > 0 then
        love.graphics.setColor(math.sin(player.damageFlash * 30) * 0.5 + 0.5, 0.5, 0.5)
    else 
        love.graphics.setColor(0, 0, 0) 
    end
    
    local x, y = player.body:getPosition()
    if player.health and player.health < player.maxHealth then
        love.graphics.setColor(1, 0, 0)
        love.graphics.rectangle("fill", x - 15, y - 30, 30, 4)
        love.graphics.setColor(0, 1, 0)
        love.graphics.rectangle("fill", x - 15, y - 30, 30 * (player.health / player.maxHealth), 4)
    end
    
    love.graphics.setColor(0, 0, 0)
    love.graphics.polygon("fill", player.body:getWorldPoints(player.shape:getPoints()))
    
    -- Draw rope 1
    if player.rope1 then
        love.graphics.setLineWidth(2)
        if game.debugMode then
            love.graphics.setColor(0.3, 1, 0.3, 0.8)
        else
            love.graphics.setColor(0, 0, 0, 1)
        end
        local prevX, prevY = player.body:getWorldPoint(0, player.h / 2)
        for _, linkBody in ipairs(player.rope1.bodies) do
            if linkBody and not linkBody:isDestroyed() then
                local lx, ly = linkBody:getPosition()
                love.graphics.line(prevX, prevY, lx, ly)
                prevX, prevY = lx, ly
            end
        end
        if player.rope1.joints and #player.rope1.joints > 0 then
            local lastJoint = player.rope1.joints[#player.rope1.joints]
            if lastJoint and not lastJoint:isDestroyed() then
                local ax, ay = lastJoint:getAnchors()
                love.graphics.line(prevX, prevY, ax, ay)
            end
        end
    end
    
    -- Draw rope 2
    if player.rope2 then
        love.graphics.setLineWidth(2)
        if game.debugMode then
            love.graphics.setColor(0.3, 0.3, 1, 0.8)
        else
            love.graphics.setColor(0, 0, 0, 1)
        end
        local prevX, prevY = player.body:getWorldPoint(0, player.h / 2)
        for _, linkBody in ipairs(player.rope2.bodies) do
            if linkBody and not linkBody:isDestroyed() then
                local lx, ly = linkBody:getPosition()
                love.graphics.line(prevX, prevY, lx, ly)
                prevX, prevY = lx, ly
            end
        end
        if player.rope2.joints and #player.rope2.joints > 0 then
            local lastJoint = player.rope2.joints[#player.rope2.joints]
            if lastJoint and not lastJoint:isDestroyed() then
                local ax, ay = lastJoint:getAnchors()
                love.graphics.line(prevX, prevY, ax, ay)
            end
        end
    end
    
    love.graphics.setLineWidth(1)
    
    for _, p in ipairs(player.particles) do
        love.graphics.setColor(1, 1, 1, p.life/255)
        love.graphics.circle("fill", p.x, p.y, 1.5)
    end
    love.graphics.setColor(0, 1, 0, 0.5)
    love.graphics.print("$", x - 4, y - 4)
end

function createPlayerParticle(x, y)
    if PlayerX[1] then
        table.insert(PlayerX[1].particles, { 
            x = x, y = y, 
            vx = love.math.random(-1, 1), 
            vy = love.math.random(-1.5, 0), 
            life = 30
        })
    end
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
    for _, b in ipairs(boundaries) do 
        if b.body and not b.body:isDestroyed() then
            love.graphics.polygon("fill", b.body:getWorldPoints(b.shape:getPoints()))
        end
    end
end

-- ============================================================================
-- PARTICLE FUNCTIONS
-- ============================================================================

function updateParticles(dt)
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.life = p.life - dt * (p.fadeSpeed or 200)
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + 0.05
        
        if p.scale then
            p.scale = p.scale - dt * 2
        end
        
        if p.life <= 0 then 
            table.remove(particles, i) 
        end
    end
end

function drawParticles()
    for _, p in ipairs(particles) do
        local alpha = math.min(1, p.life / 50)
        
        if p.type == "thruster" then
            local r = 1
            local g = 0.5 + (p.life / 100) * 0.5
            local b = 0
            love.graphics.setColor(r, g, b, alpha * 0.8)
        elseif p.type == "enemy_thruster" then
            local r = 1
            local g = 0.2 + (p.life / 100) * 0.3
            local b = 0
            love.graphics.setColor(r, g, b, alpha * 0.7)
        else
            love.graphics.setColor(1, 1, 1, alpha)
        end
        
        local size = p.size or 2
        if p.scale then
            size = size * p.scale
        end
        love.graphics.circle("fill", p.x, p.y, math.max(0.5, size))
    end
end