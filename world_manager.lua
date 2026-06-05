-- world_manager.lua (FIXED)
local Config = require("config")
local WorldManager = {
    world = nil,
    boundaries = {},
    spatialGrid = {}, -- Format: grid[cx][cy] = { entities }
    timer = 0,
    activeRadius = Config.chunks.activeRadius  -- Add this
}

function WorldManager.init()
    love.physics.setMeter(Config.physics.meter)
    WorldManager.world = love.physics.newWorld(0, Config.physics.gravityY, true)
    WorldManager.spatialGrid = {}
    WorldManager.activeRadius = Config.chunks.activeRadius
end

function WorldManager.getChunkCoords(x, y)
    local size = Config.chunks.size
    return math.floor(x / size), math.floor(y / size)
end

function WorldManager.registerEntity(entity)
    if not entity.body or entity.body:isDestroyed() then return end
    local x, y = entity.body:getPosition()
    local cx, cy = WorldManager.getChunkCoords(x, y)
    
    WorldManager.spatialGrid[cx] = WorldManager.spatialGrid[cx] or {}
    WorldManager.spatialGrid[cx][cy] = WorldManager.spatialGrid[cx][cy] or {}
    
    table.insert(WorldManager.spatialGrid[cx][cy], entity)
    entity.currentChunkX = cx
    entity.currentChunkY = cy
end

function WorldManager.updateSpatialGrid(entities)
    -- Re-index dynamic game objects across grid chunks
    WorldManager.spatialGrid = {}
    for _, entity in ipairs(entities) do
        if entity.body and not entity.body:isDestroyed() then
            WorldManager.registerEntity(entity)
        end
    end
end

function WorldManager.optimizeActiveChunks(cameraX, cameraY)
    local ccx, ccy = WorldManager.getChunkCoords(cameraX, cameraY)
    local radius = WorldManager.activeRadius

    -- First, activate ALL dynamic bodies (disable the chunk culling to show full map)
    -- If you want to keep optimization but show more, increase the radius
    
    -- For now, let's just keep everything active to ensure the map loads
    for cx, col in pairs(WorldManager.spatialGrid) do
        for cy, entities in pairs(col) do
            for _, entity in ipairs(entities) do
                if entity.body and not entity.body:isDestroyed() and entity.body:getType() == "dynamic" then
                    -- Keep all entities active for full map visibility
                    entity.body:setActive(true)
                end
            end
        end
    end
    
    -- Optional: If you want optimization back later, uncomment this:
    --[[
    for cx, col in pairs(WorldManager.spatialGrid) do
        for cy, entities in pairs(col) do
            local isWithinRange = (math.abs(cx - ccx) <= radius) and (math.abs(cy - ccy) <= radius)
            for _, entity in ipairs(entities) do
                if entity.body and not entity.body:isDestroyed() and entity.body:getType() == "dynamic" then
                    entity.body:setActive(isWithinRange)
                end
            end
        end
    end
    --]]
end

function WorldManager.createBoundary(x, y, w, h, angle)
    local body = love.physics.newBody(WorldManager.world, x, y, "static")
    local shape = love.physics.newRectangleShape(w, h)
    local fixture = love.physics.newFixture(body, shape)
    fixture:setFriction(0.5)
    fixture:setRestitution(0.2)
    body:setAngle(angle)
    
    local boundary = { body = body, shape = shape, fixture = fixture, w = w, h = h, type = "boundary" }
    table.insert(WorldManager.boundaries, boundary)
    return boundary
end

function WorldManager.drawBoundaries()
    love.graphics.setColor(0, 0, 0)
    for _, b in ipairs(WorldManager.boundaries) do
        if b.body and not b.body:isDestroyed() then
            love.graphics.polygon("fill", b.body:getWorldPoints(b.shape:getPoints()))
        end
    end
end

-- ========== BOUNDARY SLICING FEATURE (CONTACT-BASED) ==========

function WorldManager.getCollidingBoundary(player)
    if not player or not player.body or player.body:isDestroyed() then return nil, nil end
    local contacts = WorldManager.world:getContacts()
    for _, contact in ipairs(contacts) do
        if contact:isEnabled() then
            local fa, fb = contact:getFixtures()
            if not fa or not fb then goto continue end
            local bodyA = fa:getBody()
            local bodyB = fb:getBody()
            local isPlayerA = (bodyA == player.body)
            local isPlayerB = (bodyB == player.body)
            if isPlayerA or isPlayerB then
                local boundaryBody = isPlayerA and bodyB or bodyA
                for _, b in ipairs(WorldManager.boundaries) do
                    if b.body == boundaryBody then
                        -- Return boundary AND the contact itself for later point extraction
                        return b, contact
                    end
                end
            end
        end
        ::continue::
    end
    return nil, nil
end

-- Get the exact overlap interval (min/max projection) from contact points
function WorldManager.getContactOverlapOnBoundary(boundary, playerBody, contact)
    if not contact then
        -- If no specific contact, find any contact between player and boundary
        local contacts = WorldManager.world:getContactList()
        for _, c in ipairs(contacts) do
            if c:isEnabled() then
                local fa, fb = c:getFixtures()
                if fa and fb then
                    local bodyA = fa:getBody()
                    local bodyB = fb:getBody()
                    if (bodyA == playerBody and bodyB == boundary.body) or
                       (bodyB == playerBody and bodyA == boundary.body) then
                        contact = c
                        break
                    end
                end
            end
        end
    end
    if not contact then return nil, nil end

    -- Get contact points
    local x1, y1, x2, y2, nx, ny = contact:getPositions()
    local points = {}
    if x1 and y1 then
        table.insert(points, {x = x1, y = y1})
    end
    if x2 and y2 then
        table.insert(points, {x = x2, y = y2})
    end
    -- Also add the player's position? Not needed, contacts are enough.
    if #points == 0 then return nil, nil end

    -- Determine boundary's length axis (same as before)
    local worldPoints = {boundary.body:getWorldPoints(boundary.shape:getPoints())}
    local p1 = {x=worldPoints[1], y=worldPoints[2]}
    local p2 = {x=worldPoints[3], y=worldPoints[4]}
    local p3 = {x=worldPoints[5], y=worldPoints[6]}
    local dx12 = p2.x - p1.x
    local dy12 = p2.y - p1.y
    local len12 = math.sqrt(dx12*dx12 + dy12*dy12)
    local dx23 = p3.x - p2.x
    local dy23 = p3.y - p2.y
    local len23 = math.sqrt(dx23*dx23 + dy23*dy23)

    local axis
    if len12 > len23 then
        axis = {x = dx12/len12, y = dy12/len12}
    else
        axis = {x = dx23/len23, y = dy23/len23}
    end

    -- Project all contact points onto axis
    local minProj, maxProj = math.huge, -math.huge
    for _, pt in ipairs(points) do
        local proj = pt.x * axis.x + pt.y * axis.y
        if proj < minProj then minProj = proj end
        if proj > maxProj then maxProj = proj end
    end

    -- Add a small buffer to ensure the cut fully covers the contact area
    local buffer = 3
    return minProj - buffer, maxProj + buffer
end

function WorldManager.computeSliceInfo(boundary, playerBody, playerShape, contact)
    -- Get boundary corners in world space
    local points = {boundary.body:getWorldPoints(boundary.shape:getPoints())}
    local p1 = {x=points[1], y=points[2]}
    local p2 = {x=points[3], y=points[4]}
    local p3 = {x=points[5], y=points[6]}
    local p4 = {x=points[7], y=points[8]}
    
    -- Determine length axis (longer side)
    local dx12 = p2.x - p1.x
    local dy12 = p2.y - p1.y
    local len12 = math.sqrt(dx12*dx12 + dy12*dy12)
    local dx23 = p3.x - p2.x
    local dy23 = p3.y - p2.y
    local len23 = math.sqrt(dx23*dx23 + dy23*dy23)
    
    local lengthAxis, length, width
    if len12 > len23 then
        lengthAxis = {x = dx12/len12, y = dy12/len12}
        length = len12
        width = len23
    else
        lengthAxis = {x = dx23/len23, y = dy23/len23}
        length = len23
        width = len12
    end
    
    -- Boundary projection onto length axis
    local boundaryMin, boundaryMax = math.huge, -math.huge
    for i = 1, #points, 2 do
        local proj = points[i]*lengthAxis.x + points[i+1]*lengthAxis.y
        if proj < boundaryMin then boundaryMin = proj end
        if proj > boundaryMax then boundaryMax = proj end
    end
    
    -- Get exact overlap interval from contact points
    local overlapStart, overlapEnd = WorldManager.getContactOverlapOnBoundary(boundary, playerBody, contact)
    if not overlapStart or overlapEnd <= overlapStart + 5 then
        return nil  -- Not enough overlap
    end
    
    -- Ensure overlap stays within boundary bounds
    overlapStart = math.max(boundaryMin, overlapStart)
    overlapEnd = math.min(boundaryMax, overlapEnd)
    if overlapEnd <= overlapStart + 5 then return nil end
    
    local MIN_SLICE = 5
    local leftLen = overlapStart - boundaryMin
    local middleLen = overlapEnd - overlapStart
    local rightLen = boundaryMax - overlapEnd
    
    local pieces = {}
    if leftLen >= MIN_SLICE then
        table.insert(pieces, {type="static", start=boundaryMin, finish=overlapStart, length=leftLen})
    end
    if middleLen >= MIN_SLICE then
        table.insert(pieces, {type="dynamic", start=overlapStart, finish=overlapEnd, length=middleLen})
    end
    if rightLen >= MIN_SLICE then
        table.insert(pieces, {type="static", start=overlapEnd, finish=boundaryMax, length=rightLen})
    end
    
    if #pieces == 0 then return nil end
    
    -- ==== THE FIX IS HERE ====
    -- Only check if the chosen length axis corresponds to the boundary's width
    local isLengthAxisW = math.abs(length - boundary.w) < 0.1
    
    local centerX, centerY = boundary.body:getPosition()
    local boundaryCenterProj = (boundaryMin + boundaryMax) / 2
    local cat, mask, group = boundary.fixture:getFilterData()
    
    return {
        pieces = pieces,
        lengthAxis = lengthAxis,
        width = width,
        angle = boundary.body:getAngle(),
        isLengthAxisW = isLengthAxisW,
        originalW = boundary.w,
        originalH = boundary.h,
        friction = boundary.fixture:getFriction(),
        restitution = boundary.fixture:getRestitution(),
        categories = cat,
        mask = mask,
        group = group,
        centerX = centerX,
        centerY = centerY,
        boundaryMin = boundaryMin,
        boundaryMax = boundaryMax,
        boundaryCenterProj = boundaryCenterProj
    }
end

function WorldManager.performSlice(boundary, sliceInfo)
    local EffectsSystem = require("effects")
    local Entities = require("entities") -- Require here to avoid circular dependency
    
    -- Draw slice visual effect along the cut
    local points = {boundary.body:getWorldPoints(boundary.shape:getPoints())}
    EffectsSystem.createDamageEffect(points[1], points[2], points[5], points[6])
    
    local newBoundaries = {}
    local axis = sliceInfo.lengthAxis
    
    for _, piece in ipairs(sliceInfo.pieces) do
        local pieceCenterProj = (piece.start + piece.finish) / 2
        local offset = pieceCenterProj - sliceInfo.boundaryCenterProj
        local newCenterX = sliceInfo.centerX + axis.x * offset
        local newCenterY = sliceInfo.centerY + axis.y * offset
        
        local newW, newH
        if sliceInfo.isLengthAxisW then
            newW = piece.length
            newH = sliceInfo.originalH
        else
            newW = sliceInfo.originalW
            newH = piece.length
        end
        
        if piece.type == "dynamic" then
            -- ==== CONVERT TO ENTITY BOX ====
            -- Based on your main.lua: Entities.createBox(x, y, w, h, angle, density, friction)
            local density = 1.0
            local newBox = Entities.createBox(newCenterX, newCenterY, newW, newH, sliceInfo.angle, density, sliceInfo.friction)
            
            -- Carry over the restitution and collision filters
            if newBox and newBox.fixture then
                newBox.fixture:setRestitution(sliceInfo.restitution)
                if sliceInfo.categories then
                    newBox.fixture:setFilterData(sliceInfo.categories, sliceInfo.mask, sliceInfo.group)
                end
            end
        else
            -- ==== KEEP AS STATIC BOUNDARY ====
            local newBody = love.physics.newBody(WorldManager.world, newCenterX, newCenterY, "static")
            local newShape = love.physics.newRectangleShape(newW, newH)
            local newFixture = love.physics.newFixture(newBody, newShape, 0)
            
            newFixture:setFriction(sliceInfo.friction)
            newFixture:setRestitution(sliceInfo.restitution)
            
            -- Carry over collision filters to static pieces too
            if sliceInfo.categories then
                newFixture:setFilterData(sliceInfo.categories, sliceInfo.mask, sliceInfo.group)
            end
            
            newBody:setAngle(sliceInfo.angle)
            
            local newBoundary = {
                body = newBody, shape = newShape, fixture = newFixture,
                w = newW, h = newH, type = "boundary"
            }
            table.insert(WorldManager.boundaries, newBoundary)
            table.insert(newBoundaries, newBoundary)
        end
    end
    
    -- Sparks at the cut line
    for i = 1, 20 do
        local t = love.math.random()
        local sparkX = points[1] + (points[5] - points[1]) * t
        local sparkY = points[2] + (points[6] - points[2]) * t
        local angle = love.math.random() * math.pi * 2
        local speed = love.math.random(50, 150)
        local vx = math.cos(angle) * speed
        local vy = math.sin(angle) * speed - 30
        EffectsSystem.createParticle(sparkX, sparkY, vx, vy, 18, 350, 2.5, "orangeSpark")
    end
    
    return newBoundaries
end

function WorldManager.removeBoundary(boundary)
    if not boundary or not boundary.body then return end
    for i, b in ipairs(WorldManager.boundaries) do
        if b == boundary then
            table.remove(WorldManager.boundaries, i)
            break
        end
    end
    if boundary.body and not boundary.body:isDestroyed() then
        boundary.body:destroy()
    end
end

function WorldManager.sliceBoundaryAtPlayer(player)
    if not player or not player.body then return end
    local boundary, contact = WorldManager.getCollidingBoundary(player)
    if not boundary then return end
    
    local sliceInfo = WorldManager.computeSliceInfo(boundary, player.body, player.shape, contact)
    if not sliceInfo then return end
    
    WorldManager.performSlice(boundary, sliceInfo)
    WorldManager.removeBoundary(boundary)
end

return WorldManager