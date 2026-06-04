-- water.lua
local Water = {
    areas = {},
    debugMode = false
}

-- Create a water area
function Water.createArea(x, y, width, height, density, viscousDrag)
    local area = {
        x = x, y = y, w = width, h = height,
        density = density or 0.5,      -- Buoyancy strength (0-1)
        viscousDrag = viscousDrag or 0.8, -- Water resistance
        surfaceY = y,                   -- Water surface Y coordinate
        type = "water"
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
    
    -- Get shape dimensions based on shape type
    local shapeHeight = 0
    local shapeMinY = by
    local shapeMaxY = by
    
    -- Handle different shape types
    if shape:getType() == "rectangle" then
        -- For rectangle shapes, get the height
        local _, _, w, h = shape:getDimensions()
        shapeHeight = h
        shapeMinY = by - h/2
        shapeMaxY = by + h/2
    elseif shape:getType() == "circle" then
        -- For circle shapes
        local r = shape:getRadius()
        shapeHeight = r * 2
        shapeMinY = by - r
        shapeMaxY = by + r
    elseif shape:getType() == "polygon" then
        -- For polygon shapes, get approximate bounds
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
    
    -- Calculate submerged percentage
    if shapeMaxY <= waterSurface then
        -- Fully submerged
        return 1.0
    elseif shapeMinY < waterSurface and shapeMaxY > waterSurface then
        -- Partially submerged
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
    
    -- Calculate submerged percentage
    local submergedPercent = Water.getSubmergedPercent(body, shape, area)
    
    if submergedPercent > 0 then
        -- Buoyancy force (Archimedes principle)
        local mass = body:getMass()
        local gravity = 9.81 * 64 -- Match your physics meter
        local buoyancyForce = mass * gravity * area.density * submergedPercent
        
        -- Apply upward force at center of mass
        body:applyForce(0, -buoyancyForce)
        
        -- Apply water drag (viscous damping)
        local dragForce = area.viscousDrag * submergedPercent
        body:applyForce(-vx * dragForce * mass, -vy * dragForce * mass)
        
        -- Add angular damping
        local av = body:getAngularVelocity()
        body:applyTorque(-av * dragForce * mass * 10)
        
        return true
    end
    
    return false
end

-- Apply buoyancy to all entities
function Water.update(entities)
    local EffectsSystem = require("effects")
    
    for _, entity in ipairs(entities) do
        if entity.body and not entity.body:isDestroyed() and entity.shape then
            local px, py = entity.body:getPosition()
            local waterArea = Water.isPointInWater(px, py)
            
            if waterArea then
                Water.applyBuoyancy(entity.body, entity.shape, waterArea)
                
                -- Add water splashes and effects for fast-moving objects
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
    
    for _, area in ipairs(Water.areas) do
        -- Calculate resolution of the wave geometry
        local steps = math.max(15, math.floor(area.w / 20)) -- More steps = smoother wave geometry
        local stepSize = area.w / steps
        
        -- 1. Draw the dynamic water body as vertical trapezoids
        love.graphics.setColor(0.2, 0.4, 0.8, 0.55)
        
        for i = 0, steps - 1 do
            local x1 = area.x + i * stepSize
            local x2 = area.x + (i + 1) * stepSize
            
            -- Combine two sine waves for a more natural, overlapping wave effect
            local waveY1 = area.y + math.sin(time * 3 + i * 0.4) * 3 + math.sin(time * 1.5 + i * 0.2) * 2
            local waveY2 = area.y + math.sin(time * 3 + (i + 1) * 0.4) * 3 + math.sin(time * 1.5 + (i + 1) * 0.2) * 2
            
            -- Draw a trapezoid for this segment of water
            love.graphics.polygon("fill", 
                x1, waveY1,          -- Top-left corner
                x2, waveY2,          -- Top-right corner
                x2, area.y + area.h, -- Bottom-right corner
                x1, area.y + area.h  -- Bottom-left corner
            )
        end
        
        -- 2. Draw the crisp surface highlight line to match the polygon top
        love.graphics.setColor(0.4, 0.7, 1.0, 0.7)
        love.graphics.setLineWidth(2)
        
        for i = 0, steps - 1 do
            local x1 = area.x + i * stepSize
            local x2 = area.x + (i + 1) * stepSize
            
            local waveY1 = area.y + math.sin(time * 3 + i * 0.4) * 3 + math.sin(time * 1.5 + i * 0.2) * 2
            local waveY2 = area.y + math.sin(time * 3 + (i + 1) * 0.4) * 3 + math.sin(time * 1.5 + (i + 1) * 0.2) * 2
            
            love.graphics.line(x1, waveY1, x2, waveY2)
        end
        
        -- 3. Add internal water caustics/bubbles
        love.graphics.setColor(0.6, 0.8, 1.0, 0.15)
        for i = 1, 20 do
            local fx = area.x + ((time * 20 + i * 37) % area.w)
            local fy = area.y + 10 + math.sin(time * 5 + i) * 8
            
            -- Make sure bubbles don't draw outside the bottom of the water area
            if fy < area.y + area.h - 5 then
                love.graphics.circle("fill", fx, fy, 3)
            end
        end
        
        -- 4. Debug outline
        if Water.debugMode then
            love.graphics.setColor(0, 0.5, 1, 1)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", area.x, area.y, area.w, area.h)
            
            -- Show water properties
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(string.format("Density: %.1f, Drag: %.1f", 
                area.density, area.viscousDrag), area.x + 5, area.y - 15)
        end
    end
    
    -- Reset graphics state
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
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