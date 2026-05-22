-- ============================================================================
-- INDEPENDENT ROPE SYSTEM
-- Ropes are now managed in a global rope collection and rendered independently
-- ============================================================================

function love.load()
    -- Game state
    game = {
        debugMode = false,
        state = "playing" -- playing, paused, gameover
    }
    
    -- Physics world setup
    love.physics.setMeter(64)
    world = love.physics.newWorld(0, 9.81 * 64, true)
    
    -- Game object collections
    boundaries = {}
    PlayerX = {}
    boxes = {}      -- Separate box collection
    particles = {}
    enemies = {}
    balls = {}
    damageEffects = {}
    
    -- NEW: Independent rope collection
    ropes = {}       -- Each rope: {id, segments, joint1, joint2, obj1, obj2, anchor1, anchor2}
    nextRopeId = 1
    
    createBoundaries()
    createPlayer()
    createEnemies()
    createBoxes()
    createBalls()
    
    -- Camera setup
    camera = {
        x = 0, y = 0, scale = 1,
        mode = "follow_player",
        target = nil,
        freeMoveSpeed = 300,
        minScale = 0.1,
        maxScale = 3.0
    }
    
    -- UI instructions
    cameraInstructions = {
        "F1: Follow Player", "F2: Follow Enemy", "F3: Free Move",
        "Wheel or -/+: Zoom", "WASD: Free Move", "R: Reset Zoom",
        "F5: Toggle Debug Mode", "SPACE: Grab/Release Object",
        "E: Grab Enemy/Box", "SHIFT: Connect two objects & detach"
    }
    
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
    
    -- NEW: Update rope visual segments (positions for rendering)
    updateRopeVisuals()
end

function love.draw()
    love.graphics.clear(0.15, 0.15, 0.15)
    love.graphics.push()
    
    love.graphics.translate(love.graphics.getWidth()/2, love.graphics.getHeight()/2)
    love.graphics.scale(camera.scale)
    love.graphics.translate(-camera.x, -camera.y)
    
    love.graphics.circle("fill", 0, 0, 12.5)
    
    local oldFont = love.graphics.getFont()
    local smallFont = love.graphics.newFont(8)
    love.graphics.setFont(smallFont)
    
    drawBoundaries()
    drawBoxes()
    drawEnemies()
    drawBalls()
    drawPlayer(PlayerX[1])
    
    -- NEW: Draw ropes independently
    drawAllRopes()
    
    drawParticles()
    drawDamageEffects()
    
    love.graphics.setFont(oldFont)
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
            if PlayerX[1].ropeIds and #PlayerX[1].ropeIds == 2 then 
                releaseBothRopes(PlayerX[1]) 
            else 
                grabObject() 
            end
        end
    elseif key == "e" then
        if PlayerX[1] and #(PlayerX[1].ropeIds or {}) < 2 then 
            grabEnemy() 
        end
    elseif key == "lshift" or key == "rshift" then
        if PlayerX[1] and PlayerX[1].ropeIds and #PlayerX[1].ropeIds == 2 then
            connectTwoObjectsAndDetach()
        end
    end
end

function love.wheelmoved(x, y)
    local zoomFactor = 1.1
    if y > 0 then camera.scale = math.min(camera.scale * zoomFactor, 3.0)
    elseif y < 0 then camera.scale = math.max(camera.scale / zoomFactor, 0.1)
    end
end

-- ============================================================================
-- INDEPENDENT ROPE CORE FUNCTIONS

function createIndependentRope(obj1, obj2)
    if not obj1 or not obj2 or not obj1.body or not obj2.body then return nil end
    if obj1.body:isDestroyed() or obj2.body:isDestroyed() then return nil end
    
    -- Get edge attachment points
    local cx2, cy2 = obj2.body:getPosition()
    local anchor1X, anchor1Y = getEdgePoint(obj1, cx2, cy2)
    
    local cx1, cy1 = obj1.body:getPosition()
    local anchor2X, anchor2Y = getEdgePoint(obj2, cx1, cy1)
    
    -- Calculate rope parameters
    local dx, dy = anchor2X - anchor1X, anchor2Y - anchor1Y
    local distance = math.sqrt(dx*dx + dy*dy)
    local numSegments = math.max(3, math.min(15, math.floor(distance / 10)))
    local angle = math.atan2(dy, dx)
    local segLength = distance / numSegments
    local segThickness = 3
    local ux, uy = dx / distance, dy / distance
    
    local segments = {}
    local joints = {}
    local prevBody = obj1.body
    local prevX, prevY = anchor1X, anchor1Y
    
    -- Create physics bodies for each rope segment
    for i = 1, numSegments do
        local cx = anchor1X + ux * (segLength * (i - 0.5))
        local cy = anchor1Y + uy * (segLength * (i - 0.5))
        
        local segBody = love.physics.newBody(world, cx, cy, "dynamic")
        segBody:setAngle(angle)
        
        local segShape = love.physics.newRectangleShape(segLength, segThickness)
        local segFixture = love.physics.newFixture(segBody, segShape, 0.5)
        segFixture:setSensor(true)
        segFixture:setFriction(0.2)
        
        segBody:setLinearDamping(8.0)
        segBody:setAngularDamping(8.0)
        
        table.insert(segments, segBody)
        
        -- Joint to previous body
        table.insert(joints, love.physics.newRevoluteJoint(prevBody, segBody, prevX, prevY, false))
        
        prevBody = segBody
        prevX = anchor1X + ux * (segLength * i)
        prevY = anchor1Y + uy * (segLength * i)
    end
    
    -- Final joint to second object
    table.insert(joints, love.physics.newRevoluteJoint(prevBody, obj2.body, anchor2X, anchor2Y, false))
    
    -- Limit rope joint
    local limitRope = love.physics.newRopeJoint(obj1.body, obj2.body, anchor1X, anchor1Y, anchor2X, anchor2Y, distance + 2, false)
    
    -- Create rope record
    local ropeId = nextRopeId
    nextRopeId = nextRopeId + 1
    
    local rope = {
        id = ropeId,
        segments = segments,
        joints = joints,
        limitRope = limitRope,
        obj1 = obj1,
        obj2 = obj2,
        anchor1 = {x = anchor1X, y = anchor1Y},
        anchor2 = {x = anchor2X, y = anchor2Y},
        numSegments = numSegments,
        isDestroyed = false
    }
    
    -- Store rope in global collection
    ropes[ropeId] = rope
    
    -- Register rope with objects
    obj1.ropeIds = obj1.ropeIds or {}
    obj2.ropeIds = obj2.ropeIds or {}
    table.insert(obj1.ropeIds, ropeId)
    table.insert(obj2.ropeIds, ropeId)
    
    return ropeId
end
-- ============================================================================

function updateRopeVisuals()
    for id, rope in pairs(ropes) do
        if rope.isDestroyed then
            ropes[id] = nil
        else
            -- Check if objects still exist
            if not rope.obj1 or not rope.obj2 or not rope.obj1.body or not rope.obj2.body or 
               rope.obj1.body:isDestroyed() or rope.obj2.body:isDestroyed() then
                destroyRopeById(id)
            else
                -- Update anchor positions to maintain edge attachment
                local cx2, cy2 = rope.obj2.body:getPosition()
                local ax, ay = getEdgePoint(rope.obj1, cx2, cy2)
                rope.anchor1 = {x = ax, y = ay}
                
                local cx1, cy1 = rope.obj1.body:getPosition()
                local ax2, ay2 = getEdgePoint(rope.obj2, cx1, cy1)
                rope.anchor2 = {x = ax2, y = ay2}
            end
        end
    end
end

function drawAllRopes()
    for id, rope in pairs(ropes) do
        if not rope.isDestroyed then
            drawRope(rope)
        end
    end
end

function drawRope(rope)
    if not rope or rope.isDestroyed then return end
    if not rope.segments or #rope.segments == 0 then return end
    
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(1)
    
    -- Draw from anchor1 through each segment to anchor2
    local prevX, prevY = rope.anchor1.x, rope.anchor1.y
    
    -- Draw lines through each segment body
    for i, segBody in ipairs(rope.segments) do
        if segBody and not segBody:isDestroyed() then
            local currX, currY = segBody:getPosition()
            if prevX and prevY and currX and currY then
                love.graphics.line(prevX, prevY, currX, currY)
            end
            prevX, prevY = currX, currY
        end
    end
    
    -- Draw final line to anchor2
    if prevX and prevY and rope.anchor2.x and rope.anchor2.y then
        love.graphics.line(prevX, prevY, rope.anchor2.x, rope.anchor2.y)
    end
    
    love.graphics.setLineWidth(1)
    
    -- Optional: Draw segment bodies for debug
    if game.debugMode then
        love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
        for _, segBody in ipairs(rope.segments) do
            if segBody and not segBody:isDestroyed() then
                local fixtures = segBody:getFixtures()
                if fixtures[1] then
                    local shape = fixtures[1]:getShape()
                    if shape:getType() == "polygon" then
                        love.graphics.polygon("line", segBody:getWorldPoints(shape:getPoints()))
                    end
                end
            end
        end
    end
end

function destroyRopeById(ropeId)
    local rope = ropes[ropeId]
    if not rope or rope.isDestroyed then return end
    
    -- Destroy physics components
    if rope.limitRope and not rope.limitRope:isDestroyed() then
        rope.limitRope:destroy()
    end
    if rope.joints then
        for _, joint in ipairs(rope.joints) do
            if joint and not joint:isDestroyed() then joint:destroy() end
        end
    end
    if rope.segments then
        for _, body in ipairs(rope.segments) do
            if body and not body:isDestroyed() then body:destroy() end
        end
    end
    
    -- Remove rope from objects' rope lists
    if rope.obj1 and rope.obj1.ropeIds then
        for i, rid in ipairs(rope.obj1.ropeIds) do
            if rid == ropeId then table.remove(rope.obj1.ropeIds, i); break end
        end
    end
    if rope.obj2 and rope.obj2.ropeIds then
        for i, rid in ipairs(rope.obj2.ropeIds) do
            if rid == ropeId then table.remove(rope.obj2.ropeIds, i); break end
        end
    end
    
    rope.isDestroyed = true
    ropes[ropeId] = nil
end

function destroyAllRopesForObject(obj)
    if not obj or not obj.ropeIds then return end
    local ropeIdsCopy = {}
    for _, id in ipairs(obj.ropeIds) do table.insert(ropeIdsCopy, id) end
    for _, id in ipairs(ropeIdsCopy) do
        destroyRopeById(id)
    end
    obj.ropeIds = {}
end

function getPlayerRopeIds(player)
    if not player then return {} end
    return player.ropeIds or {}
end

function ropeConnectsTo(obj1, obj2)
    if not obj1.ropeIds then return false end
    for _, ropeId in ipairs(obj1.ropeIds) do
        local rope = ropes[ropeId]
        if rope and ((rope.obj1 == obj2) or (rope.obj2 == obj2)) then
            return true
        end
    end
    return false
end

function releaseBothRopes(player)
    if not player then return end
    destroyAllRopesForObject(player)
end


-- ============================================================================
-- OBJECT GRABBING AND CONNECTION
-- ============================================================================

function grabObject()
    local player = PlayerX[1]
    if not player or #(player.ropeIds or {}) >= 2 then return end
    
    local px, py = player.body:getWorldPoint(0, player.h / 2)
    local closestObj, closestDist = nil, 200
    
    -- Check boxes
    for _, obj in ipairs(boxes) do
        if obj.body and not obj.body:isDestroyed() then
            if ropeConnectsTo(player, obj) then goto continue end
            local ox, oy = obj.body:getPosition()
            local dist = math.sqrt((px-ox)^2 + (py-oy)^2)
            if dist < closestDist then
                closestDist = dist
                closestObj = obj
            end
        end
        ::continue::
    end
    
    -- Check balls
    for _, obj in ipairs(balls) do
        if obj.body and not obj.body:isDestroyed() then
            if ropeConnectsTo(player, obj) then goto continue2 end
            local ox, oy = obj.body:getPosition()
            local dist = math.sqrt((px-ox)^2 + (py-oy)^2)
            if dist < closestDist then
                closestDist = dist
                closestObj = obj
            end
        end
        ::continue2::
    end
    
    if closestObj then
        createIndependentRope(player, closestObj)
    end
end

function grabEnemy()
    local player = PlayerX[1]
    if not player or #(player.ropeIds or {}) >= 2 then return end
    
    local px, py = player.body:getWorldPoint(0, player.h / 2)
    local closestEnemy, closestDist = nil, 200
    
    for _, enemy in ipairs(enemies) do
        if enemy.body and not enemy.body:isDestroyed() then
            if ropeConnectsTo(player, enemy) then goto continue end
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
        createIndependentRope(player, closestEnemy)
    end
end

function ropeConnectsTo(obj1, obj2)
    if not obj1.ropeIds then return false end
    for _, ropeId in ipairs(obj1.ropeIds) do
        local rope = ropes[ropeId]
        if rope and ((rope.obj1 == obj2) or (rope.obj2 == obj2)) then
            return true
        end
    end
    return false
end

function connectTwoObjectsAndDetach()
    local player = PlayerX[1]
    if not player or not player.ropeIds or #player.ropeIds ~= 2 then return end
    
    local ropeIds = {}
    for _, id in ipairs(player.ropeIds) do
        table.insert(ropeIds, id)
    end
    
    if #ropeIds < 2 then return end
    
    local rope1 = ropes[ropeIds[1]]
    local rope2 = ropes[ropeIds[2]]
    
    if not rope1 or not rope2 then return end
    
    local obj1 = (rope1.obj1 == player) and rope1.obj2 or rope1.obj1
    local obj2 = (rope2.obj1 == player) and rope2.obj2 or rope2.obj1
    
    if not obj1 or not obj2 or not obj1.body or not obj2.body then return end
    if obj1.body:isDestroyed() or obj2.body:isDestroyed() then return end
    
    -- Destroy both player ropes
    destroyRopeById(ropeIds[1])
    destroyRopeById(ropeIds[2])
    
    -- Create new rope directly between the two objects
    createIndependentRope(obj1, obj2)
    
    -- Create visual effect at connection point
    local jx, jy = player.body:getWorldPoint(0, player.h / 2)
    for i = 1, 20 do createDamageEffect(jx, jy) end
end

function removeRopeConnecting(ropeId)
    destroyRopeById(ropeId)
end


-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

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
        
        local ldx = dx * cosA - dy * sinA
        local ldy = dx * sinA + dy * cosA
        
        local hw = (obj.w or 20) / 2
        local hh = (obj.h or 20) / 2
        
        local tx = (ldx ~= 0) and math.abs(hw / ldx) or math.huge
        local ty = (ldy ~= 0) and math.abs(hh / ldy) or math.huge
        local t = math.min(tx, ty)
        
        local lx = ldx * t
        local ly = ldy * t
        
        cosA, sinA = math.cos(angle), math.sin(angle)
        return cx + (lx * cosA - ly * sinA), cy + (lx * sinA + ly * cosA)
    end
    
    return cx, cy
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
        for _, box in ipairs(boxes) do
            if box.body and not box.body:isDestroyed() then
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
    
    if obj.type == "box" and obj.sliceDepth then
        local damageReduction = math.pow(0.85, obj.sliceDepth)
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
    
    for i = 1, 20 do createDamageEffect(x, y) end
    
    -- Destroy all ropes connected to this object
    destroyAllRopesForObject(obj)
    
    if obj.type == "enemy" then
        for i, enemy in ipairs(enemies) do
            if enemy == obj then table.remove(enemies, i); break end
        end
        if obj.body and not obj.body:isDestroyed() then obj.body:destroy() end
        
    elseif obj.type == "box" then
        sliceBox(obj)
        for i, box in ipairs(boxes) do
            if box == obj then table.remove(boxes, i); break end
        end
        if obj.body and not obj.body:isDestroyed() then obj.body:destroy() end
        
    elseif obj.type == "ball" then
        for i, ball in ipairs(balls) do
            if ball == obj then table.remove(balls, i); break end
        end
        for i, box in ipairs(boxes) do
            if box == obj then table.remove(boxes, i); break end
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
    
    local sliceVertical = (w >= h)
    
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
    
    local minSize = 5
    if newWidth1 < minSize or newWidth2 < minSize or newHeight1 < minSize or newHeight2 < minSize then
        return
    end
    
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
    
    table.insert(boxes, newBox1)
    table.insert(boxes, newBox2)
    
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
-- SIMPLE ENEMY AI
-- ============================================================================

function createEnemies()
    -- Add enemies here as needed
    -- table.insert(enemies, createEnemyObj(-8900, -520, 12.5, 25, 0))
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
        ropeIds = {},
        health = calcMaxHealth, maxHealth = calcMaxHealth,
        damageFlash = 0, thrusterCooldown = 0
    }
    table.insert(boxes, enemy)
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
    table.insert(boxes, createBoxObj(-800, 570, 8, 80, 0, 2, 0.2, ""))
    table.insert(boxes, createBoxObj(-840, 570, 8, 80, 0, 2, 0.2, ""))
    table.insert(boxes, createBoxObj(-820, 300, 80, 30, 0, 0.6, 0.2, ""))
    createBoxGrid(-1600, 800, 3, 3, 30, 30, 3, 0.1, 0.2)
    table.insert(boxes, createBoxObj(-900, 400, 20, 20, 0, 1.5, 0.3, ""))
    table.insert(boxes, createBoxObj(-750, 350, 15, 40, 0.5, 1.2, 0.2, ""))
    table.insert(boxes, createBoxObj(-1000, 600, 25, 25, 0, 2.0, 0.1, ""))
    table.insert(boxes, createBoxObj(-1100, 650, 12, 60, 0.3, 0.8, 0.4, ""))
end

function createBoxGrid(startX, startY, cols, rows, boxWidth, boxHeight, spacing, density, friction)
    for row = 0, rows - 1 do
        for col = 0, cols - 1 do
            local x = startX + (col * (boxWidth + spacing))
            local y = startY - (row * (boxHeight + spacing))
            table.insert(boxes, createBoxObj(x, y, boxWidth, boxHeight, 0, density, friction, string.format("x%d%d", col, row)))
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
        damageFlash = 0, ropeIds = {}, sliceDepth = 0
    }
end

function drawBoxes()
    for _, box in ipairs(boxes) do
        if box.type == "box" and box.body and not box.body:isDestroyed() then
            if box.damageFlash and box.damageFlash > 0 then
                love.graphics.setColor(0, 0, 0, math.sin(box.damageFlash * 30) * 0.5 + 0.5)
            else 
                love.graphics.setColor(0, 0, 0) 
            end
            
            local x, y = box.body:getPosition()
            love.graphics.polygon("fill", box.body:getWorldPoints(box.shape:getPoints()))
            -- REMOVED: rope drawing here
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
        damageFlash = 0, ropeIds = {}
    }
    table.insert(boxes, ball)
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
            -- REMOVED: rope drawing here
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
        ropeIds = {},
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
    love.graphics.setColor(0, 1, 0, 0.5)
    love.graphics.print("$", x - 4, y - 4)
    
    for _, p in ipairs(player.particles) do
        love.graphics.setColor(1, 1, 1, p.life/255)
        love.graphics.circle("fill", p.x, p.y, 1.5)
    end
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
            love.graphics.setColor(1, 0.5 + (p.life / 100) * 0.5, 0, alpha * 0.8)
        elseif p.type == "enemy_thruster" then
            love.graphics.setColor(1, 0.2 + (p.life / 100) * 0.3, 0, alpha * 0.7)
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

-- ============================================================================
-- UI AND DEBUG FUNCTIONS
-- ============================================================================

function drawUI()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("State: " .. game.state, 10, 10)
    
    if PlayerX[1] then
        local px, py = PlayerX[1].body:getPosition()
        love.graphics.print("Player Position: " .. math.floor(px) .. ", " .. math.floor(py), 10, 30)
        
        local ropeCount = #(PlayerX[1].ropeIds or {})
        love.graphics.print("Ropes attached: " .. ropeCount .. "/2", 10, 250)
        if ropeCount == 0 then
            love.graphics.print("No ropes attached", 10, 270)
        elseif ropeCount == 1 then
            love.graphics.setColor(0.3, 1, 0.3)
            love.graphics.print("1 rope attached (Press E or SPACE for second)", 10, 270)
        else
            love.graphics.setColor(0.3, 1, 0.3)
            love.graphics.print("Both ropes attached! Press SHIFT to connect them", 10, 270)
        end
        love.graphics.setColor(1, 1, 1)
    end
    
    love.graphics.print("Camera Mode: " .. camera.mode, 10, 50)
    love.graphics.print("Zoom: " .. string.format("%.2f", camera.scale), 10, 70)
    
    if game.debugMode then
        love.graphics.setColor(1, 0, 0)
        love.graphics.print("DEBUG MODE ACTIVE", 10, 90)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Total ropes: " .. #ropes, 10, 110)
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
    for _, box in ipairs(boxes) do
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