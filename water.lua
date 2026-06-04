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
function Water.createArea(x, y, width, height, density, viscousDrag)
    local area = {
        x = x, y = y, w = width, h = height,
        density = density or 0.5,      -- Buoyancy strength (0-1)
        viscousDrag = viscousDrag or 0.8, -- Water resistance
        surfaceY = y,                   -- Water surface Y coordinate
        type = "water",
        mesh = nil,                     -- Dynamically allocated once on first draw
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

-- Draw water areas
function Water.draw()
    local time = love.timer.getTime()
    
    -- Fast clear reuse arrays without triggering Garbage Collection allocations
    for i = 1, #lineBuffer do lineBuffer[i] = nil end
    for i = 1, #sparkleBuffer do sparkleBuffer[i] = nil end
    for i = 1, #bubbleBuffer do bubbleBuffer[i] = nil end
    for i = 1, #causticBuffer do causticBuffer[i] = nil end
    
    for _, area in ipairs(Water.areas) do
        local steps = math.max(15, math.floor(area.w / 12)) -- Higher fidelity steps
        local stepSize = area.w / steps
        
        -- Initialize or update dynamic Mesh layout if sizes changed
        if not area.mesh or area.meshSegments ~= steps then
            area.meshSegments = steps
            area.verticesTable = {}
            for i = 0, steps do
                table.insert(area.verticesTable, {0, 0, 0, 0, 1, 1, 1, 1}) -- Top Vertex structural anchor
                table.insert(area.verticesTable, {0, 0, 0, 0, 1, 1, 1, 1}) -- Bottom Vertex structural anchor
            end
            area.mesh = love.graphics.newMesh(area.verticesTable, "strip", "dynamic")
        end
        
        -- 1. LAYER ONE: UNDERWATER GOD RAYS (Rendered underneath water colors)
        -- love.graphics.setBlendMode("add")
        -- for r = 1, 3 do
            -- local angleOffset = math.sin(time * 0.4 + r) * 35
            -- local startX = area.x + (area.w * 0.23) * r
            -- love.graphics.setColor(0.5, 0.75, 1.0, 0.04) -- Subtle light glow
            -- love.graphics.polygon("fill", 
                -- startX, area.y,
                -- startX + 50, area.y,
                -- startX + 50 + angleOffset + 60, area.y + area.h,
                -- startX + angleOffset, area.y + area.h
            -- )
        -- end
        -- love.graphics.setBlendMode("alpha")
        
        -- 2. LAYER TWO: GRADIENT WATER BODY POLYGON (Dynamic Mesh processing)
        local idx = 1
        local lineIdx = 1
        
        for i = 0, steps do
            local x = area.x + i * stepSize
            -- Compound math wave formulation for smooth natural movement
            local waveY = area.y + math.sin(time * 2.8 + i * 0.28) * 4.5 + math.cos(time * 1.4 + i * 0.12) * 2.0
            
            -- Keep record of surface track points for line draw pipelines
            lineBuffer[lineIdx] = x
            lineBuffer[lineIdx + 1] = waveY
            lineIdx = lineIdx + 2
            
            -- Handle Sparkle gathering positions (Only near high points dynamically blinking)
            if i > 0 and i < steps and math.sin(time * 5 + i * 2) > 0.82 then
                table.insert(sparkleBuffer, x)
                table.insert(sparkleBuffer, waveY + 1)
            end
            
            -- Vertex Group Array Modifications
            -- Top Node Position: Mid-water gradient accent
            area.verticesTable[idx][1] = x
            area.verticesTable[idx][2] = waveY
            area.verticesTable[idx][5] = 0.15  -- R
            area.verticesTable[idx][6] = 0.42  -- G
            area.verticesTable[idx][7] = 0.78  -- B
            area.verticesTable[idx][8] = 0.65  -- Alpha mid-depth transparency
            idx = idx + 1
            
            -- Bottom Node Position: Deep water structural base
            area.verticesTable[idx][1] = x
            area.verticesTable[idx][2] = area.y + area.h
            area.verticesTable[idx][5] = 0.04  -- R
            area.verticesTable[idx][6] = 0.12  -- G
            area.verticesTable[idx][8] = 0.92  -- Deep ocean opacity shift
            idx = idx + 1
        end
        
        -- Direct single hardware push instructions
        area.mesh:setVertices(area.verticesTable)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(area.mesh)
        
        -- 3. LAYER THREE: LIGHT CAUSTICS NETWORK
        -- love.graphics.setBlendMode("add")
        -- love.graphics.setColor(1, 1, 1, 0.03)
        -- for c = 1, 2 do
            -- local baseCausticY = area.y + 25 + (c * 40)
            -- if baseCausticY < area.y + area.h - 10 then
                -- local cLineIdx = 1
                -- for i = 0, steps do
                    -- local cx = area.x + i * stepSize
                    -- local cy = baseCausticY + math.sin(time * 3.5 + i * 0.5 + c) * 3
                    -- causticBuffer[cLineIdx] = cx
                    -- causticBuffer[cLineIdx + 1] = cy
                    -- cLineIdx = cLineIdx + 2
                -- end
                -- love.graphics.setLineWidth(2)
                -- love.graphics.line(causticBuffer)
                -- -- Clear immediate sub-buffer array index tracking safely
                -- for k = 1, #causticBuffer do causticBuffer[k] = nil end
            -- end
        -- end
        -- love.graphics.setBlendMode("alpha")
        
        -- 4. LAYER FOUR: RISING BUBBLES BATCH PROCESSING
        -- local maxBubbles = 25
        -- for i = 1, maxBubbles do
            -- -- Pseudo-random deterministic placement calculations using continuous math sequences
            -- local bx = area.x + ((i * 143.7 + time * 14) % area.w)
            -- local by = area.y + area.h - ((i * 87.3 + time * (18 + (i % 4) * 6)) % area.h)
            -- bx = bx + math.sin(time * 2.5 + i) * 5 -- Sub-surface drift oscillation
            
            -- if by > area.y + 12 and by < area.y + area.h then
                -- table.insert(bubbleBuffer, bx)
                -- table.insert(bubbleBuffer, by)
            -- end
        -- end
        -- if #bubbleBuffer > 0 then
            -- love.graphics.setPointSize(2)
            -- love.graphics.setColor(0.85, 0.95, 1.0, 0.3)
            -- love.graphics.points(bubbleBuffer)
        -- end
        
        -- 5. LAYER FIVE: SURFACE HIGHLIGHTS & CYAN CREST LINES
        -- if #lineBuffer >= 4 then
            -- -- Surface Base Highlight (Thick Light Blue Line)
            -- love.graphics.setColor(0.48, 0.78, 1.0, 0.75)
            -- love.graphics.setLineWidth(3)
            -- love.graphics.line(lineBuffer)
            
            -- -- High Contrast Wave Crest Accent (Thin Cyan Line Overlay)
            -- love.graphics.setColor(0.2, 1.0, 0.95, 0.85)
            -- love.graphics.setLineWidth(1)
            -- love.graphics.line(lineBuffer)
        -- end
        
        
        -- 6. LAYER EIGHT: SYSTEM DEBUG DATA
        if Water.debugMode then
            love.graphics.setColor(0, 0.5, 1, 1)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", area.x, area.y, area.w, area.h)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(string.format("Density: %.1f, Drag: %.1f, Vertices: %d", 
                area.density, area.viscousDrag, steps * 2), area.x + 5, area.y - 15)
        end
    end
    
    -- Global Environment State Normalization Reset
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