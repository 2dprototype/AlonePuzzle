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
        mode = "follow_player", -- Modes: "follow_player", "follow_enemy", "free_move"
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
        "SPACE: Grab/Release Box"
    }
    
    -- Debug info
    debugInfo = {
        showPlayerVectors = true,
        showThrusterDirection = true,
        showPhysicsInfo = true,
        showObjectCounts = true
    }
end

function love.update(dt)
    if game.state ~= "playing" then return end
    
    world:update(dt)
    updatePlayer(dt)
    updateEnemies(dt)
    updateParticles(dt)
    updateCamera(dt)
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
    
    love.graphics.setFont(oldFont)
    
    -- Debug drawings (on top of everything)
    if game.debugMode then
        drawDebugInfo()
    end
    
    love.graphics.pop()
    
    -- Draw UI (not affected by camera)
    drawUI()
end


function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "f1" then
        camera.mode = "follow_player"
        camera.target = nil
    elseif key == "f2" then
        camera.mode = "follow_enemy"
        camera.target = nil
    elseif key == "f3" then
        camera.mode = "free_move"
        camera.target = nil
    elseif key == "=" or key == "+" then
        camera.scale = math.min(camera.scale + 0.1, 5)
    elseif key == "-" or key == "_" then
        camera.scale = math.max(camera.scale - 0.1, 0.1)
    elseif key == "r" then
        camera.scale = 1.0  -- Reset zoom
    elseif key == "f5" then
        game.debugMode = not game.debugMode
    elseif key == "p" then
        if game.state == "playing" then
            game.state = "paused"
        else
            game.state = "playing"
        end
    elseif key == "space" then
        if PlayerX[1] then
            if PlayerX[1].rope then
                releaseBox()
            else
                grabBox()
            end
        end
    end
end

function love.wheelmoved(x, y)
    -- Zoom in/out with mouse wheel
    local zoomFactor = 1.1
    if y > 0 then
        -- Zoom in
        camera.scale = math.min(camera.scale * zoomFactor, camera.maxScale)
    elseif y < 0 then
        -- Zoom out
        camera.scale = math.max(camera.scale / zoomFactor, camera.minScale)
    end
end


function drawUI()
    love.graphics.setColor(1, 1, 1)
    
    -- Game state
    love.graphics.print("State: " .. game.state, 10, 10)
    
    -- Player position
    if PlayerX[1] then
        local px, py = PlayerX[1].body:getPosition()
        love.graphics.print("Player Position: " .. math.floor(px) .. ", " .. math.floor(py), 10, 30)
        if PlayerX[1].rope then
            love.graphics.setColor(0.3, 1, 0.3)
            love.graphics.print("Carrying Box!", 10, 250)
            love.graphics.setColor(1, 1, 1)
        end
    end
    
    -- Camera info
    love.graphics.print("Camera Mode: " .. camera.mode, 10, 50)
    love.graphics.print("Zoom: " .. string.format("%.2f", camera.scale), 10, 70)
    
    -- Debug mode indicator
    if game.debugMode then
        love.graphics.setColor(1, 0, 0)
        love.graphics.print("DEBUG MODE ACTIVE", 10, 90)
        love.graphics.setColor(1, 1, 1)
    end
    
    -- Instructions
    love.graphics.print("Controls:", love.graphics.getWidth() - 200, 10)
    for i, instruction in ipairs(cameraInstructions) do
        love.graphics.print(instruction, love.graphics.getWidth() - 200, 10 + i * 20)
    end
    
    -- Game controls
    love.graphics.print("Game Controls:", love.graphics.getWidth() - 200, 190)
    love.graphics.print("Arrow Keys: Move Player", love.graphics.getWidth() - 200, 210)
    love.graphics.print("PageUp/Down: Rotate", love.graphics.getWidth() - 200, 230)
    love.graphics.print("P: Pause/Resume", love.graphics.getWidth() - 200, 250)
    
    -- Target info if following enemy
    if camera.mode == "follow_enemy" and camera.target then
        local tx, ty = camera.target.body:getPosition()
        love.graphics.print("Tracking Enemy", 10, 110)
        love.graphics.print("Enemy Position: " .. math.floor(tx) .. ", " .. math.floor(ty), 10, 130)
    end
    
    -- Object counts in debug mode
    if game.debugMode then
        love.graphics.print("Objects - Boundaries: " .. #boundaries .. 
                           " Boxes: " .. countObjects("box") .. 
                           " Enemies: " .. #enemies .. 
                           " Balls: " .. #balls, 10, 150)
    end
end



function drawDebugInfo()
    if PlayerX[1] then
        drawPlayerDebugInfo(PlayerX[1])
    end
    
    for _, enemy in ipairs(enemies) do
        drawEnemyDebugInfo(enemy)
    end
    
    -- Draw physics body outlines
    if debugInfo.showPhysicsInfo then
        drawPhysicsDebug()
    end
end

function drawPlayerDebugInfo(player)
    local body = player.body
    local x, y = body:getPosition()
    local angle = body:getAngle()
    
    -- Coordinate axes
    if debugInfo.showPlayerVectors then
        local length = 50
        -- X-axis (red)
        love.graphics.setColor(1, 0, 0, 0.8)
        love.graphics.line(x, y, x + math.cos(angle) * length, y + math.sin(angle) * length)
        -- Y-axis (green)
        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.line(x, y, x + math.cos(angle + math.pi/2) * length, y + math.sin(angle + math.pi/2) * length)
    end
    
    -- Velocity vector
    local vx, vy = body:getLinearVelocity()
    love.graphics.setColor(0, 0.5, 1, 0.8)
    love.graphics.line(x, y, x + vx, y + vy)
    love.graphics.print("Velocity: " .. string.format("%.1f", math.sqrt(vx*vx + vy*vy)), x + 20, y - 40)
    
    -- Thruster direction
    if debugInfo.showThrusterDirection then
        local thrusterLength = 50
        local bx, by = body:getWorldPoint(0, player.h / 2) -- Bottom point
        
        -- Up thruster (cyan)
        if love.keyboard.isDown("up") then
            love.graphics.setColor(0, 1, 1, 0.8)
            love.graphics.line(bx, by, bx, by - thrusterLength)
        end
        
        -- Down thruster (yellow)
        if love.keyboard.isDown("down") then
            love.graphics.setColor(1, 1, 0, 0.8)
            love.graphics.line(bx, by, bx, by + thrusterLength)
        end
    end
    
    -- Angular velocity
    local av = body:getAngularVelocity()
    love.graphics.setColor(1, 0.5, 0, 0.8)
    love.graphics.print("Angular Vel: " .. string.format("%.2f", av), x + 20, y - 20)
    
    -- Force indicators
    love.graphics.setColor(1, 0, 1, 0.6)
    if love.keyboard.isDown("right") then
        love.graphics.line(x, y, x + 20, y)
    end
    if love.keyboard.isDown("left") then
        love.graphics.line(x, y, x - 20, y)
    end
end

function drawEnemyDebugInfo(enemy)
    local body = enemy.body
    local x, y = body:getPosition()
    
    -- Draw line to player if exists
    if PlayerX[1] then
        local px, py = PlayerX[1].body:getPosition()
        love.graphics.setColor(1, 0, 0, 0.5)
        love.graphics.line(x, y, px, py)
        
        -- Distance to player
        local dx, dy = px - x, py - y
        local distance = math.sqrt(dx*dx + dy*dy)
        love.graphics.print("Dist: " .. string.format("%.1f", distance), x + 15, y - 20)
    end
    
    -- Velocity vector
    local vx, vy = body:getLinearVelocity()
    love.graphics.setColor(1, 0.5, 0.5, 0.8)
    love.graphics.line(x, y, x + vx, y + vy)
end

function drawPhysicsDebug()
    -- Draw boundaries
    love.graphics.setColor(0, 0.5, 0, 0.3)
    for _, boundary in ipairs(boundaries) do
        love.graphics.polygon("line", boundary.body:getWorldPoints(boundary.shape:getPoints()))
    end
    
    -- Draw boxes
    love.graphics.setColor(0.5, 0.5, 0, 0.3)
    for _, box in ipairs(box_i) do
        if box.type == "box" then
            love.graphics.polygon("line", box.body:getWorldPoints(box.shape:getPoints()))
        end
    end
end

function countObjects(objectType)
    local count = 0
    for _, obj in ipairs(box_i) do
        if obj.type == objectType then
            count = count + 1
        end
    end
    return count
end



function updateCamera(dt)
    if camera.mode == "follow_player" and PlayerX[1] then
        -- Smooth follow player
        local targetX, targetY = PlayerX[1].body:getPosition()
        camera.x = camera.x + (targetX - camera.x) * 0.99
        camera.y = camera.y + (targetY - camera.y) * 0.99
        
    elseif camera.mode == "follow_enemy" then
        -- Follow first enemy
        local enemy = findFirstEnemy()
        if enemy then
            camera.target = enemy
            local targetX, targetY = enemy.body:getPosition()
            camera.x = camera.x + (targetX - camera.x) * 0.99
            camera.y = camera.y + (targetY - camera.y) * 0.99
        elseif PlayerX[1] then
            -- Fallback to player if no enemy
            local targetX, targetY = PlayerX[1].body:getPosition()
            camera.x = camera.x + (targetX - camera.x) * 0.99
            camera.y = camera.y + (targetY - camera.y) * 0.99
        end
        
    elseif camera.mode == "free_move" then
        -- Free movement with WASD
        local speed = camera.freeMoveSpeed * dt / camera.scale
        
        if love.keyboard.isDown("w") or love.keyboard.isDown("up") then
            camera.y = camera.y - speed
        end
        if love.keyboard.isDown("s") or love.keyboard.isDown("down") then
            camera.y = camera.y + speed
        end
        if love.keyboard.isDown("a") or love.keyboard.isDown("left") then
            camera.x = camera.x - speed
        end
        if love.keyboard.isDown("d") or love.keyboard.isDown("right") then
            camera.x = camera.x + speed
        end
    end
end

function findFirstEnemy()
    for _, enemy in ipairs(enemies) do
        return enemy
    end
    return nil
end



function createBoundaries()
    -- Floor
    table.insert(boundaries, createBoundary(320, 500, 600, 10, 0))
    table.insert(boundaries, createBoundary(-100, 350, 600, 10, 0.3))
    table.insert(boundaries, createBoundary(-485, 261, 200, 10, 0))
    table.insert(boundaries, createBoundary(-265, 589, 600, 10, -0.3))
    
    -- Additional platforms
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
    
    return {
        body = body,
        shape = shape,
        fixture = fixture,
        w = w,
        h = h
    }
end

function drawBoundaries()
    love.graphics.setColor(0, 0, 0)
    for _, boundary in ipairs(boundaries) do
        love.graphics.polygon("fill", boundary.body:getWorldPoints(boundary.shape:getPoints()))
    end
end


function createPlayer()
    local body = love.physics.newBody(world, -820, 0, "dynamic")
    local shape = love.physics.newRectangleShape(12.5, 25)
    local fixture = love.physics.newFixture(body, shape, 1.0)
    fixture:setFriction(0.1)
    fixture:setRestitution(0.2)
    
    PlayerX[1] = {
        body = body,
        shape = shape,
        fixture = fixture,
        w = 12.5,
        h = 25,
        particles = {},
        rope = nil
    }
end

function updatePlayer(dt)
    if not PlayerX[1] then return end
    
    local player = PlayerX[1]
    local body = player.body
    local vx, vy = body:getLinearVelocity()

    -- Get bottom world coordinates (even if rotated)
    local bx, by = body:getWorldPoint(0, player.h / 2)
    
    -- Apply forces based on key presses
    if love.keyboard.isDown("right") then
        body:applyForce(30, 0)
    end
    
    if love.keyboard.isDown("left") then
        body:applyForce(-30, 0)
    end
    
    if love.keyboard.isDown("up") then
        body:applyForce(0, -60)
        createPlayerParticle(bx, by)
    end 
    
    if love.keyboard.isDown("down") then
        body:applyForce(0, 20)
        createPlayerParticle(bx, by)
    end

    -- Upright Stabilization (auto balance)
    local angle = body:getAngle()
    local angularVelocity = body:getAngularVelocity()

    local k = 30         -- proportional correction (spring strength)
    local damping = 2.5  -- damping to stop oscillation

    local torque = -angle * k - angularVelocity * damping
    body:applyTorque(torque)
    
    -- Manual rotation
    local rotationForce = 45
    if love.keyboard.isDown("pageup") then
        body:applyTorque(-rotationForce)
    end
    if love.keyboard.isDown("pagedown") then
        body:applyTorque(rotationForce)
    end

    -- Update particles
    updatePlayerParticles(player, dt)
end

function updatePlayerParticles(player, dt)
    for i = #player.particles, 1, -1 do
        local p = player.particles[i]
        p.life = p.life - 8 * dt
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + 0.05
        if p.life <= 0 then
            table.remove(player.particles, i)
        end
    end
end

function drawPlayer(player)
    love.graphics.setColor(0, 0, 0)
    local x, y = player.body:getPosition()
    
    -- Apply shadow effect
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", x + x/50, y + y/50, player.w, player.h)
    
    -- Draw player
    love.graphics.setColor(0, 0, 0)
    love.graphics.polygon("fill", player.body:getWorldPoints(player.shape:getPoints()))
    
    -- Draw dynamic rope links if carrying a box
    if player.rope then
        love.graphics.setColor(0, 0, 0)
        love.graphics.setLineWidth(1)
        local prevX, prevY = player.body:getWorldPoint(0, player.h / 2)
        
        for _, linkBody in ipairs(player.rope.bodies) do
            local lx, ly = linkBody:getPosition()
            love.graphics.line(prevX, prevY, lx, ly)
            prevX, prevY = lx, ly
        end
        
        -- Pull the connection all the way to the box joint target anchor point
        if player.rope.joints[#player.rope.joints] then
            local finalJoint = player.rope.joints[#player.rope.joints]
            if not finalJoint:isDestroyed() then
                local ax, ay = finalJoint:getAnchors()
                love.graphics.line(prevX, prevY, ax, ay)
            end
        end
        love.graphics.setLineWidth(1)
    end
    
    -- Draw particles
    drawPlayerParticles(player)
    
    -- Draw player indicator
    love.graphics.setColor(0, 1, 0, 0.5)
    love.graphics.print("$", x - 4, y - 4)
end

function drawPlayerParticles(player)
    love.graphics.setColor(0.5, 0.5, 0.5)
    for _, p in ipairs(player.particles) do
        love.graphics.setColor(1, 1, 1, p.life/255)
        love.graphics.circle("fill", p.x, p.y, 1)
    end
end

function createPlayerParticle(x, y)
    table.insert(PlayerX[1].particles, {
        x = x,
        y = y,
        vx = love.math.random(-0.6, 0.62),
        vy = love.math.random(-1, 0),
        life = 255
    })
end


-- ============================================================================
-- ROPE / BOX CARRY MECHANICS
-- ============================================================================

function grabBox()
    local player = PlayerX[1]
    if not player then return end

    local p_bottom_x, p_bottom_y = player.body:getWorldPoint(0, player.h / 2)
    local grabRadius = 160 -- Maximum radius to tether boxes (in pixels)
    
    local closestBox = nil
    local closestDist = grabRadius
    local targetEdgeX, targetEdgeY = 0, 0

    for _, obj in ipairs(box_i) do
        if obj.type == "box" then
            -- Check centers of all 4 outer edges of the box
            local edges = {
                {obj.body:getWorldPoint(0, -obj.h / 2)}, -- Top Center
                {obj.body:getWorldPoint(0, obj.h / 2)},  -- Bottom Center
                {obj.body:getWorldPoint(-obj.w / 2, 0)}, -- Left Center
                {obj.body:getWorldPoint(obj.w / 2, 0)}   -- Right Center
            }

            for _, edge in ipairs(edges) do
                local ex, ey = edge[1], edge[2]
                local dx = p_bottom_x - ex
                local dy = p_bottom_y - ey
                local dist = math.sqrt(dx * dx + dy * dy)

                if dist < closestDist then
                    closestDist = dist
                    closestBox = obj
                    targetEdgeX, targetEdgeY = ex, ey
                end
            end
        end
    end

    -- Construct the chain tether if a valid box is nearby
    if closestBox then
        player.rope = { bodies = {}, joints = {}, box = closestBox, limitRope = nil }
        
        -- Optimized settings for a much tighter chain
        local numSegments = 10
        local prevBody = player.body
        local vx = targetEdgeX - p_bottom_x
        local vy = targetEdgeY - p_bottom_y
        local initialDistance = math.sqrt(vx * vx + vy * vy)

        for i = 1, numSegments do
            local t = i / (numSegments + 1)
            local segX = p_bottom_x + vx * t
            local segY = p_bottom_y + vy * t

            local segBody = love.physics.newBody(world, segX, segY, "dynamic")
            local segShape = love.physics.newCircleShape(1.5)
            
            -- High density + strong structural damping prevents the chain links from glitching or snapping wildly
            local segFixture = love.physics.newFixture(segBody, segShape, 0.001) 
            segFixture:setSensor(true) 
            segBody:setLinearDamping(3.0)
            segBody:setAngularDamping(3.0)

            table.insert(player.rope.bodies, segBody)
            
            -- Bind rope links sequentially
            local joint = love.physics.newRevoluteJoint(prevBody, segBody, segX, segY, false)
            table.insert(player.rope.joints, joint)

            prevBody = segBody
        end

        -- Secure final link directly to the target center point on the box edge
        local finalJoint = love.physics.newRevoluteJoint(prevBody, closestBox.body, targetEdgeX, targetEdgeY, false)
        table.insert(player.rope.joints, finalJoint)

        -- STRENGTHENING STEP: Create an overarching structural RopeJoint constraint
        -- This serves as an absolute maximum limit that keeps the physical bodies from rubber-banding.
        player.rope.limitRope = love.physics.newRopeJoint(
            player.body, 
            closestBox.body, 
            p_bottom_x, p_bottom_y, 
            targetEdgeX, targetEdgeY, 
            initialDistance + 5, -- Give it a tiny bit of slack so the chain segment loops don't look completely frozen
            false
        )
    end
end

function releaseBox()
    local player = PlayerX[1]
    if player and player.rope then
        -- Safely clean up structural limit joint
        if player.rope.limitRope and not player.rope.limitRope:isDestroyed() then
            player.rope.limitRope:destroy()
        end
        -- Safe breakdown of Box2D components
        for _, joint in ipairs(player.rope.joints) do
            if not joint:isDestroyed() then joint:destroy() end
        end
        for _, body in ipairs(player.rope.bodies) do
            if not body:isDestroyed() then body:destroy() end
        end
        player.rope = nil
    end
end

-- ============================================================================


function createEnemies()
    table.insert(enemies, createEnemyObj(-8900, -520, 12.5, 25, 0))
end

function createEnemyObj(x, y, w, h, angle)
    local body = love.physics.newBody(world, x, y, "dynamic")
    local shape = love.physics.newRectangleShape(w, h)
    local fixture = love.physics.newFixture(body, shape, 1.2)
    fixture:setFriction(0.1)
    fixture:setRestitution(0.2)
    
    local enemy = {
        type = "enemy",
        body = body,
        shape = shape,
        fixture = fixture,
        w = w,
        h = h,
        particles = {}
    }
    
    table.insert(box_i, enemy) -- Keep for backward compatibility
    return enemy
end

function updateEnemies(dt)
    if not PlayerX[1] then return end
    
    local playerX, playerY = PlayerX[1].body:getPosition()
    
    for _, enemy in ipairs(enemies) do
        updateSingleEnemy(enemy, playerX, playerY, dt)
    end
end

function updateSingleEnemy(enemy, playerX, playerY, dt)
    local body = enemy.body
    local ex, ey = body:getPosition()
    local dx = playerX - ex
    local dy = playerY - ey

    -- Calculate distance to player
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- MAX FORCE LIMIT 
    local maxForce = 130 
    local forceMultiplier = 0.05
    
    -- Calculate desired force
    local desiredForceX = dx * forceMultiplier
    local desiredForceY = dy * forceMultiplier
    local forceMagnitude = math.sqrt(desiredForceX * desiredForceX + desiredForceY * desiredForceY)
    
    -- Apply force limit
    if forceMagnitude > maxForce then
        local scale = maxForce / forceMagnitude
        desiredForceX = desiredForceX * scale
        desiredForceY = desiredForceY * scale
    end
    
    -- Move toward player with limited force
    body:applyForce(desiredForceX, desiredForceY)

    -- Stabilization
    local currentAngle = body:getAngle()
    local angularVelocity = body:getAngularVelocity()

    local k = 30     
    local damping = 2.5 

    local torque = -currentAngle * k - angularVelocity * damping
    body:applyTorque(torque)

    -- Emit particle at bottom (follows rotation)
    local bx, by = body:getWorldPoint(0, enemy.h / 2)
    createEnemyParticle(enemy, bx, by)

    -- Update particles
    updateEnemyParticles(enemy, dt)
end

function updateEnemyParticles(enemy, dt)
    for i = #enemy.particles, 1, -1 do
        local p = enemy.particles[i]
        p.life = p.life - 8 * dt
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + 0.05
        
        if p.life <= 0 then
            table.remove(enemy.particles, i)
        end
    end
end

function createEnemyParticle(enemy, x, y)
    table.insert(enemy.particles, {
        x = x,
        y = y,
        vx = love.math.random(-0.3, 0.3),
        vy = love.math.random(-0.8, 0),
        life = 255
    })
end

function drawEnemies()
    for _, enemy in ipairs(enemies) do
        drawSingleEnemy(enemy)
    end
end

function drawSingleEnemy(enemy)
    love.graphics.setColor(0, 0, 0)
    local x, y = enemy.body:getPosition()
    love.graphics.polygon("fill", enemy.body:getWorldPoints(enemy.shape:getPoints()))
    
    -- Draw enemy indicator
    love.graphics.setColor(1, 0, 0, 0.5)
    love.graphics.print("E", x - 4, y - 4)
    
    -- Draw particles
    drawEnemyParticles(enemy)
end

function drawEnemyParticles(enemy)
    for _, p in ipairs(enemy.particles) do
        love.graphics.setColor(1, 1, 1, p.life/255)
        love.graphics.circle("fill", p.x, p.y, 1)
    end
end


function createBoxes()
    -- Existing boxes
    table.insert(box_i, createBoxObj(-800, 570, 8, 80, 0, 2, 0.2))
    table.insert(box_i, createBoxObj(-840, 570, 8, 80, 0, 2, 0.2))
    table.insert(box_i, createBoxObj(-820, 300, 80, 30, 0, 0.6, 0.2))
    
    -- Create grid of boxes with custom parameters
    createBoxGrid(-1600, 800, 3, 3, 30, 30, 3, 0.1, 0.2)
end

function createBoxGrid(startX, startY, cols, rows, boxWidth, boxHeight, spacing, density, friction)
    for row = 0, rows - 1 do
        for col = 0, cols - 1 do
            local x = startX + (col * (boxWidth + spacing))
            local y = startY - (row * (boxHeight + spacing))
            table.insert(box_i, createBoxObj(x, y, boxWidth, boxHeight, 0, density, friction))
        end
    end
end

function createBoxObj(x, y, w, h, angle, density, friction)
    local body = love.physics.newBody(world, x, y, "dynamic")
    local shape = love.physics.newRectangleShape(w, h)
    local fixture = love.physics.newFixture(body, shape, density or 1.0)
    fixture:setFriction(friction or 0.5)
    fixture:setRestitution(0.2)
    body:setAngle(angle or 0)
    
    return {
        type = "box",
        body = body,
        shape = shape,
        fixture = fixture,
        w = w,
        h = h
    }
end

function drawBoxes()
    for i, box in ipairs(box_i) do
        if box.type == "box" then
            drawSingleBox(box, "b" .. i)
        end
    end
end

function drawSingleBox(box, label)
    local x, y = box.body:getPosition()
    local angle = box.body:getAngle()

    love.graphics.setColor(0, 0, 0)
    love.graphics.polygon("fill", box.body:getWorldPoints(box.shape:getPoints()))

    love.graphics.push()
        love.graphics.translate(x, y)
        love.graphics.rotate(angle)
        love.graphics.setColor(1, 1, 1, 0.2) 
        love.graphics.print(label, (-box.w / 2) + 2, -box.h / 2 + 2)
    love.graphics.pop()
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
    
    if angularVelocity then
        body:setAngularVelocity(angularVelocity)
    end
    
    local ball = {
        type = "ball",
        body = body,
        shape = shape,
        fixture = fixture,
        r = r
    }
    
    table.insert(box_i, ball) -- Keep for backward compatibility
    return ball
end

function drawBalls()
    for _, ball in ipairs(balls) do
        drawSingleBall(ball)
    end
end

function drawSingleBall(ball)
    local x, y = ball.body:getPosition()
    local angle = ball.body:getAngle()

    -- Outline
    love.graphics.setColor(0, 0, 0)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", x, y, ball.r)

    -- Rotating cross
    local cosA, sinA = math.cos(angle), math.sin(angle)
    local r = ball.r

    love.graphics.line(
        x - r * cosA, y - r * sinA,
        x + r * cosA, y + r * sinA
    )
    love.graphics.line(
        x - r * sinA, y + r * cosA,
        x + r * sinA, y - r * cosA
    )
	love.graphics.setLineWidth(1)
end


function updateParticles(dt)
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.life = p.life - 8 * dt
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + 0.05
        
        if p.life <= 0 then
            table.remove(particles, i)
        end
    end
end

function drawParticles()
    for _, p in ipairs(particles) do
        love.graphics.setColor(1, 1, 1, p.life/255)
        love.graphics.circle("fill", p.x, p.y, 1)
    end
end