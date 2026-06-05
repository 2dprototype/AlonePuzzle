-- water.lua
local Water = {
    areas = {},
    debugMode = false
}

-- Reusable static buffers to completely prevent Garbage Collection (GC) allocation lag
local lineBuffer = {}
local sparkleBuffer = {}
local bubbleBuffer = {}
local causticBuffer = {}

-- Create a water area
function Water.createArea(x, y, width, height, density, viscousDrag, waterType)
    local area = {
        x = x, y = y, w = width, h = height,
        density = density or 0.5,      -- Buoyancy strength (0-1)
        viscousDrag = viscousDrag or 0.8, -- Water resistance
        surfaceY = y,                   -- Water surface Y coordinate
        type = "water",
        waterType = waterType or "basic", -- "basic" or "deep"
        mesh = nil,                     -- Dynamically allocated once on first draw (for deep water)
        verticesTable = nil,
        meshSegments = 0
    }
    table.insert(Water.areas, area)
    return area
end

-- Check if a point is inside water
function Water.isPointInWater(px, py)
    for _, area in ipairs(Water.areas) do
        if px >= area.x and px <= area.x + area.w and
           py >= area.y and py <= area.y + area.h then
            return area
        end
    end
    return nil
end

-- Get the approximate submerged percentage of a body
function Water.getSubmergedPercent(body, shape, area)
    local bx, by = body:getPosition()
    
    local shapeHeight = 0
    local shapeMinY = by
    local shapeMaxY = by
    
    if shape:getType() == "rectangle" then
        local _, _, w, h = shape:getDimensions()
        shapeHeight = h
        shapeMinY = by - h/2
        shapeMaxY = by + h/2
    elseif shape:getType() == "circle" then
        local r = shape:getRadius()
        shapeHeight = r * 2
        shapeMinY = by - r
        shapeMaxY = by + r
    elseif shape:getType() == "polygon" then
        local points = {shape:getPoints()}
        local minY = points[2]
        local maxY = points[2]
        for i = 2, #points, 2 do
            if points[i] < minY then minY = points[i] end
            if points[i] > maxY then maxY = points[i] end
        end
        shapeMinY = minY
        shapeMaxY = maxY
        shapeHeight = maxY - minY
    end
    
    local waterSurface = area.y
    
    if shapeMaxY <= waterSurface then
        return 1.0
    elseif shapeMinY < waterSurface and shapeMaxY > waterSurface then
        local submergedHeight = shapeMaxY - waterSurface
        local totalHeight = shapeMaxY - shapeMinY
        if totalHeight > 0 then
            return math.min(1.0, math.max(0, submergedHeight / totalHeight))
        end
    end
    
    return 0
end

-- Apply buoyancy force to a body
function Water.applyBuoyancy(body, shape, area)
    if not body or body:isDestroyed() or body:getType() ~= "dynamic" then
        return
    end
    
    local bx, by = body:getPosition()
    local vx, vy = body:getLinearVelocity()
    
    local submergedPercent = Water.getSubmergedPercent(body, shape, area)
    
    if submergedPercent > 0 then
        local mass = body:getMass()
        local gravity = 9.81 * 64
        local buoyancyForce = mass * gravity * area.density * submergedPercent
        
        body:applyForce(0, -buoyancyForce)
        
        local dragForce = area.viscousDrag * submergedPercent
        body:applyForce(-vx * dragForce * mass, -vy * dragForce * mass)
        
        local av = body:getAngularVelocity()
        body:applyTorque(-av * dragForce * mass * 10)
        
        return true
    end
    
    return false
end

-- Apply buoyancy to all entities
function Water.update(entities)
    for _, entity in ipairs(entities) do
        if entity.body and not entity.body:isDestroyed() and entity.shape then
            local px, py = entity.body:getPosition()
            local waterArea = Water.isPointInWater(px, py)
            
            if waterArea then
                Water.applyBuoyancy(entity.body, entity.shape, waterArea)
                
                local vx, vy = entity.body:getLinearVelocity()
                local speed = math.sqrt(vx^2 + vy^2)
                if speed > 100 and love.math.random() < 0.03 then
                    Water.createSplash(px, py, speed)
                elseif speed > 50 and love.math.random() < 0.01 then
                    Water.createSplash(px, py, speed)
                end
            end
        end
    end
end

-- Visual effects for water interaction
function Water.createSplash(x, y, intensity)
    local EffectsSystem = require("effects")
    local numDrops = math.min(15, math.floor(intensity / 15))
    
    for i = 1, numDrops do
        local angle = love.math.random() * math.pi * 2
        local speed = love.math.random(30, 70) * (intensity / 100)
        local vx = math.cos(angle) * speed * love.math.random(0.5, 1.5)
        local vy = math.sin(angle) * speed * love.math.random(0.5, 1.5) - love.math.random(20, 40)
        
        EffectsSystem.createParticle(x, y, vx, vy, 12, 250, 2, "water")
    end
end

-- Basic water rendering (from water_basic.lua)
function Water.draw_basic(area)
    local time = love.timer.getTime()
    local steps = math.max(15, math.floor(area.w / 20))
    local stepSize = area.w / steps
    
    -- Draw the dynamic water body as vertical trapezoids
    love.graphics.setColor(0.2, 0.4, 0.8, 0.55)
    
    for i = 0, steps - 1 do
        local x1 = area.x + i * stepSize
        local x2 = area.x + (i + 1) * stepSize
        
        -- Combine two sine waves for natural wave effect
        local waveY1 = area.y + math.sin(time * 3 + i * 0.4) * 3 + math.sin(time * 1.5 + i * 0.2) * 2
        local waveY2 = area.y + math.sin(time * 3 + (i + 1) * 0.4) * 3 + math.sin(time * 1.5 + (i + 1) * 0.2) * 2
        
        -- Draw trapezoid for this segment
        love.graphics.polygon("fill", 
            x1, waveY1,
            x2, waveY2,
            x2, area.y + area.h,
            x1, area.y + area.h
        )
    end
    
    -- Draw surface highlight line
    love.graphics.setColor(0.4, 0.7, 1.0, 0.7)
    love.graphics.setLineWidth(2)
    
    for i = 0, steps - 1 do
        local x1 = area.x + i * stepSize
        local x2 = area.x + (i + 1) * stepSize
        
        local waveY1 = area.y + math.sin(time * 3 + i * 0.4) * 3 + math.sin(time * 1.5 + i * 0.2) * 2
        local waveY2 = area.y + math.sin(time * 3 + (i + 1) * 0.4) * 3 + math.sin(time * 1.5 + (i + 1) * 0.2) * 2
        
        love.graphics.line(x1, waveY1, x2, waveY2)
    end
    
    -- Add bubbles/caustics
    love.graphics.setColor(0.6, 0.8, 1.0, 0.15)
    for i = 1, 20 do
        local fx = area.x + ((time * 20 + i * 37) % area.w)
        local fy = area.y + 10 + math.sin(time * 5 + i) * 8
        
        if fy < area.y + area.h - 5 then
            love.graphics.circle("fill", fx, fy, 3)
        end
    end
end

-- Deep water rendering (enhanced with mesh, god rays, caustics, etc.)
function Water.draw_deep(area)
    local time = love.timer.getTime()
    local steps = math.max(15, math.floor(area.w / 12))
    local stepSize = area.w / steps
    
    -- Clear buffers
    for i = 1, #lineBuffer do lineBuffer[i] = nil end
    for i = 1, #sparkleBuffer do sparkleBuffer[i] = nil end
    for i = 1, #bubbleBuffer do bubbleBuffer[i] = nil end
    
    -- Initialize or update dynamic Mesh
    if not area.mesh or area.meshSegments ~= steps then
        area.meshSegments = steps
        area.verticesTable = {}
        for i = 0, steps do
            table.insert(area.verticesTable, {0, 0, 0, 0, 1, 1, 1, 1})
            table.insert(area.verticesTable, {0, 0, 0, 0, 1, 1, 1, 1})
        end
        area.mesh = love.graphics.newMesh(area.verticesTable, "strip", "dynamic")
    end
    
    -- Update mesh vertices
    local idx = 1
    local lineIdx = 1
    
    for i = 0, steps do
        local x = area.x + i * stepSize
        local waveY = area.y + math.sin(time * 2.8 + i * 0.28) * 4.5 + math.cos(time * 1.4 + i * 0.12) * 2.0
        
        -- Store surface points for line drawing
        lineBuffer[lineIdx] = x
        lineBuffer[lineIdx + 1] = waveY
        lineIdx = lineIdx + 2
        
        -- Sparkle positions
        if i > 0 and i < steps and math.sin(time * 5 + i * 2) > 0.82 then
            table.insert(sparkleBuffer, x)
            table.insert(sparkleBuffer, waveY + 1)
        end
        
        -- Top vertex
        area.verticesTable[idx][1] = x
        area.verticesTable[idx][2] = waveY
        area.verticesTable[idx][5] = 0.15
        area.verticesTable[idx][6] = 0.42
        area.verticesTable[idx][7] = 0.78
        area.verticesTable[idx][8] = 0.65
        idx = idx + 1
        
        -- Bottom vertex
        area.verticesTable[idx][1] = x
        area.verticesTable[idx][2] = area.y + area.h
        area.verticesTable[idx][5] = 0.04
        area.verticesTable[idx][6] = 0.12
        area.verticesTable[idx][8] = 0.92
        idx = idx + 1
    end
    
    -- Draw mesh
    area.mesh:setVertices(area.verticesTable)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(area.mesh)
    
    -- Draw bubbles
    -- local maxBubbles = 25
    -- for i = 1, maxBubbles do
        -- local bx = area.x + ((i * 143.7 + time * 14) % area.w)
        -- local by = area.y + area.h - ((i * 87.3 + time * (18 + (i % 4) * 6)) % area.h)
        -- bx = bx + math.sin(time * 2.5 + i) * 5
        
        -- if by > area.y + 12 and by < area.y + area.h then
            -- table.insert(bubbleBuffer, bx)
            -- table.insert(bubbleBuffer, by)
        -- end
    -- end
    
    if #bubbleBuffer > 0 then
        love.graphics.setPointSize(2)
        love.graphics.setColor(0.85, 0.95, 1.0, 0.3)
        love.graphics.points(bubbleBuffer)
    end
    
    -- Draw surface highlights
    -- if #lineBuffer >= 4 then
        -- love.graphics.setColor(0.48, 0.78, 1.0, 0.75)
        -- love.graphics.setLineWidth(3)
        -- love.graphics.line(lineBuffer)
        
        -- love.graphics.setColor(0.2, 1.0, 0.95, 0.85)
        -- love.graphics.setLineWidth(1)
        -- love.graphics.line(lineBuffer)
    -- end
end

function Water.draw_algae(area)
    local t = love.timer.getTime()
    
    -- 1. Base deep murky green body
    love.graphics.setColor(0.05, 0.25, 0.15, 0.85)
    love.graphics.rectangle("fill", area.x, area.y + 5, area.w, area.h - 5)
    
    -- 2. Bright, wavy algae "scum" on the surface
    love.graphics.setColor(0.25, 0.65, 0.2, 0.9)
    local segments = math.floor(area.w / 15)
    local surfacePoly = {area.x, area.y + area.h, area.x + area.w, area.y + area.h}
    
    for i = segments, 0, -1 do
        local px = area.x + (i / segments) * area.w
        -- Organic overlapping sine waves for a swampy look
        local wave = math.sin(t * 1.5 + px * 0.04) * 4 + math.cos(t * 1.2 + px * 0.02) * 2
        table.insert(surfacePoly, px)
        table.insert(surfacePoly, area.y + wave)
    end
    
    if #surfacePoly >= 6 then
        love.graphics.polygon("fill", surfacePoly)
    end
    
    -- 3. Top highlight (bright green edge)
    love.graphics.setColor(0.4, 0.8, 0.3, 1)
    love.graphics.setLineWidth(2)
    for i = 5, #surfacePoly - 2, 2 do
        love.graphics.line(surfacePoly[i], surfacePoly[i+1], surfacePoly[i-2], surfacePoly[i-1])
    end
    
    -- 4. Suspended drifting algae clumps
    love.graphics.setColor(0.3, 0.6, 0.25, 0.6)
    -- Calculate how many clumps based on area size
    local numParticles = math.floor((area.w * area.h) / 2500) 
    
    for i = 1, numParticles do
        -- Use pseudo-random math based on area position so they don't flicker
        local pseudoX = (area.x * 13 + i * 117) % area.w
        local pseudoY = (area.y * 7 + i * 233) % (area.h - 15) + 15
        
        -- Make them gently drift in circles using time
        local driftX = math.sin(t * 0.5 + pseudoY * 0.1) * 8
        local driftY = math.cos(t * 0.3 + pseudoX * 0.1) * 5
        
        local px = area.x + pseudoX + driftX
        local py = area.y + pseudoY + driftY
        
        -- Keep them visually constrained to the water boundaries horizontally
        if px > area.x and px < area.x + area.w then
            local radius = (i % 3) + 1.5 -- Varying clump sizes
            love.graphics.circle("fill", px, py, radius)
        end
    end
end

-- Main draw function - routes to appropriate renderer based on waterType
function Water.draw()
    for _, area in ipairs(Water.areas) do
        if area.waterType == "basic" then
            Water.draw_basic(area)
        elseif area.waterType == "algae" then
            Water.draw_algae(area) -- NEW: Route to algae rendering
        else -- "deep" or default
            Water.draw_deep(area)
        end
        
        -- Debug overlay (applies to all types)
        if Water.debugMode then
            love.graphics.setColor(0, 0.5, 1, 1)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", area.x, area.y, area.w, area.h)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(string.format("Type: %s, Density: %.1f, Drag: %.1f", 
                area.waterType, area.density, area.viscousDrag), area.x + 5, area.y - 15)
        end
    end
    
    -- Reset graphics state
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
    love.graphics.setPointSize(1)
end

-- Check if a body is in any water (for swimming mechanics)
function Water.isBodyInWater(body)
    if not body or body:isDestroyed() then return false end
    local x, y = body:getPosition()
    return Water.isPointInWater(x, y) ~= nil
end

-- Get water area at position
function Water.getWaterArea(x, y)
    return Water.isPointInWater(x, y)
end

-- Toggle debug visualization
function Water.setDebug(enabled)
    Water.debugMode = enabled
end

return Water