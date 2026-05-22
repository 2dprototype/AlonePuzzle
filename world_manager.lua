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

return WorldManager