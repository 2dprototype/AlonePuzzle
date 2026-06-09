local Vegetation = {}
Vegetation.list = {}
Vegetation.healRate = 0.15  -- Heal speed (0.15 per second = ~6.7 sec from full burn to green)

-- Initialize or clear vegetation data
function Vegetation.init()
    Vegetation.list = {}
end

-- Create an individual grass tuft attached to a specific Box2D body
function Vegetation.createGrass(body, localX, localY, w, h, localAngle)
    if not body or body:isDestroyed() then return nil end

    -- Generate a realistic organic blend for Healthy Grass (Deep Forest to Olive Green)
    local hR = 0.12 + math.random() * 0.10
    local hG = 0.28 + math.random() * 0.18
    local hB = 0.10 + math.random() * 0.08
    
    -- Generate a realistic organic blend for Dead/Burnt Grass (Dark Ochre/Mustard/Brown)
    local dR = 0.42 + math.random() * 0.15
    local dG = 0.35 + math.random() * 0.12
    local dB = 0.12 + math.random() * 0.06
    
    local grass = {
        type = "grass",
        body = body,
        localX = localX or 0,
        localY = localY or 0,
        localAngle = localAngle or 0,
        
        -- Absolute coordinates synchronized dynamically during updates
        x = 0, y = 0,
        
        -- Core structural dimensions
        w = w or (3.5 + math.random() * 2.5),
        h = h or (16 + math.random() * 18), -- High height variance for wilder look
        
        -- Dynamic bending variables
        angle = 0,                       
        angularVelocity = 0,
        stiffness = 0 + math.random(12),
        damping = 4.5 + math.random() * 1.5,
        maxBend = math.pi / 1.5,
        
        -- Complex layered wind properties (Base breeze + Gusts)
        windFreq = 1.2 + math.random() * 1.5,
        windGustFreq = 2.5 + math.random() * 2.0,
        windStrength = 0.02 + math.random() * 0.03,
        
        -- Color Shift: 0 = Healthy Green, 1 = Dead/Burnt Yellow
        -- Natural variance: Some grass naturally spawns a little dry/yellow (0.0 to 0.25)
        burnFactor = math.random() * 0.25,
        healthyColor = { hR, hG, hB },
        deadColor = { dR, dG, dB },
        
        -- Procedural Blades: Generate 2 to 5 distinct blades per tuft for organic clustering
        blades = {}
    }
    
    local numBlades = math.random(2, 5)
    for i = 1, numBlades do
        table.insert(grass.blades, {
            -- Random spread angle for this specific blade
            angleOffset = (math.random() - 0.5) * 0.9,
            -- Height multiplier (some blades in the tuft are short, some tall)
            heightMod = 0.5 + math.random() * 0.7,
            -- Width multiplier
            widthMod = 0.6 + math.random() * 0.6,
            -- Slight color variance per blade
            colorMod = 0.85 + math.random() * 0.3,
            -- Natural static curve (makes blades droop slightly naturally)
            curve = (math.random() - 0.5) * 0.4
        })
    end
    
    -- Initial absolute coordinate lock
    grass.x, grass.y = body:getWorldPoint(grass.localX, grass.localY)
    table.insert(Vegetation.list, grass)
    return grass
end

-- Helper to populate a specific body's surface with grass blades
-- @param densityMulti: Multiplier for grass thickness (e.g., 1.0 is normal, 2.0 is very dense)
function Vegetation.populateBody(body, width, height, densityMulti, localAngle)
    if not body or body:isDestroyed() then return end
    localAngle = localAngle or 0
    densityMulti = densityMulti or 1.0
    
    -- Tighter base stepping, modified by density
    local step = 9 / densityMulti
    local localTopY = -height / 2 
    
    -- Distribute with Jitter to prevent unnatural perfect straight lines
    for localX = -width / 2 + 4, width / 2 - 4, step do
        local jitterX = localX + (math.random() - 0.5) * (step * 0.8)
        local jitterY = localTopY + (math.random() - 0.5) * 2.5 -- Slight depth variation
        Vegetation.createGrass(body, jitterX, jitterY, nil, nil, localAngle)
    end
end

-- Update loop simulating ambient environment physics, healing, and real-time synchronization
function Vegetation.update(dt, entitiesList)
    local time = love.timer.getTime()
    
    for i = #Vegetation.list, 1, -1 do
        local item = Vegetation.list[i]
        
        if not item.body or item.body:isDestroyed() then
            table.remove(Vegetation.list, i)
        else
            item.x, item.y = item.body:getWorldPoint(item.localX, item.localY)
            
            -- 2. Layered Ambient Wind Processing (Base wave + chaotic gusts)
            local baseWind = math.sin(time * item.windFreq + item.x * 0.015)
            local gustWind = math.sin(time * item.windGustFreq + item.x * 0.04) * 0.4
            local wind = (baseWind + gustWind) * item.windStrength
            
            -- 3. Damped Spring Physics
            local angleDiff = wind - item.angle
            local springForce = angleDiff * item.stiffness
            
            item.angularVelocity = item.angularVelocity + springForce * dt
            item.angularVelocity = item.angularVelocity * math.max(0, 1 - item.damping * dt)
            item.angle = item.angle + item.angularVelocity * dt
            item.angle = math.max(-item.maxBend, math.min(item.maxBend, item.angle))
            
            -- 4. Entity brush interaction mechanics
            if entitiesList then
                for _, e in ipairs(entitiesList) do
                    if e.body and not e.body:isDestroyed() and e.body ~= item.body then
                        local ex, ey = e.body:getPosition()
                        local dx = ex - item.x
                        local dy = ey - item.y
                        local dist = math.sqrt(dx * dx + dy * dy)
                        
                        local entityRadius = e.r or math.max(e.w or 20, e.h or 20) / 2
                        local triggerDistance = entityRadius + 14
                        
                        if dist < triggerDistance then
                            local vx, vy = e.body:getLinearVelocity()
                            local speed = math.sqrt(vx * vx + vy * vy)
                            
                            local pushDir = vx > 0 and 1 or (vx < 0 and -1 or 0)
                            if pushDir == 0 then pushDir = dx > 0 and -1 or 1 end
                            
                            local interactionStrength = 1 - (dist / triggerDistance)
                            local impulse = pushDir * interactionStrength * (speed * 0.08 + 4.5)
                            item.angularVelocity = item.angularVelocity + impulse * dt * 60
                        end
                    end
                end
            end
            
            -- 5. Healing: slowly turn burnt grass back to green over time
            if item.burnFactor > 0 then
                item.burnFactor = math.max(0, item.burnFactor - Vegetation.healRate * dt)
            end
        end
    end
end

-- Process high-impact explosions and trigger color mutations
function Vegetation.applyExplosion(cx, cy, radius, force)
    local EffectsSystem = package.loaded["effects"]
    
    for _, item in ipairs(Vegetation.list) do
        local dx = item.x - cx
        local dy = (item.y - item.h / 2) - cy
        local dist = math.sqrt(dx * dx + dy * dy)
        
        if dist < radius then
            local pushDir = dx >= 0 and 1 or -1
            local falloff = 1 - (dist / radius)
            local explosionForce = pushDir * falloff * (force * 0.09)
            
            -- Flatten instantly from shockwave energy
            item.angle = item.angle + pushDir * falloff * 2.0
            item.angularVelocity = item.angularVelocity + explosionForce * 5.0
            
            -- Shift color towards burnt yellow/brown depending on proximity
            item.burnFactor = math.min(1, item.burnFactor + falloff * 0.85)
            
            if EffectsSystem and EffectsSystem.createParticle then
                -- Add dirt/debris kicking up from the roots
                local particleCount = math.floor(falloff * 3) + 1
                for i = 1, particleCount do
                    local px = item.x + (math.random() - 0.5) * 10
                    local py = item.y - math.random() * (item.h * 0.5)
                    local vx = (math.random() - 0.5) * 50 + (pushDir * falloff * 90)
                    local vy = -(math.random() * 50 + 20)
                    EffectsSystem.createParticle(px, py, vx, vy, 35, 120, 1.5 + math.random(2), "debris")
                end
            end
        end
    end
end

-- Monkey-patch helper hooks to securely intercept explosion triggers from standard entities
local Entities = package.loaded["entities"] or require("entities")
if Entities and type(Entities.explode) == "function" then
    local originalExplode = Entities.explode
    Entities.explode = function(e)
        local cx, cy, radius, force
        if e and e.body and not e.body:isDestroyed() then
            cx, cy = e.body:getPosition()
            radius = e.explosionRadius or 100
            force = e.explosionForce or 1000
        end
        originalExplode(e)
        if cx and cy then
            Vegetation.applyExplosion(cx, cy, radius, force)
        end
    end
end

-- Render highly realistic procedural segmented grass
function Vegetation.draw()
    local segments = 4 -- Keeps performance solid while allowing smooth curving
    
    for _, item in ipairs(Vegetation.list) do
        -- CRITICAL FIX: Skip any grass attached to a destroyed body
        if not item.body or item.body:isDestroyed() then
            goto continue
        end
        
        love.graphics.push()
        love.graphics.translate(item.x, item.y)
        
        -- Orient matrix based on the parent body angle structure
        local bodyAngle = item.body:getAngle()
        love.graphics.rotate(bodyAngle + item.localAngle)
        
        -- Interpolate base color state (Healthy Green -> Burnt Yellow)
        local bR = item.healthyColor[1] * (1 - item.burnFactor) + item.deadColor[1] * item.burnFactor
        local bG = item.healthyColor[2] * (1 - item.burnFactor) + item.deadColor[2] * item.burnFactor
        local bB = item.healthyColor[3] * (1 - item.burnFactor) + item.deadColor[3] * item.burnFactor
        
        -- Draw each procedural blade in the tuft
        for _, blade in ipairs(item.blades) do
            love.graphics.push()
            
            -- Apply blade-specific angle spread
            love.graphics.rotate(blade.angleOffset)
            
            local bladeHeight = item.h * blade.heightMod
            local bladeWidth = item.w * blade.widthMod
            local segH = bladeHeight / segments
            
            for s = 1, segments do
                -- Root-to-Tip Gradient: 
                -- Roots (s=1) are heavily shadowed (40% brightness).
                -- Tips (s=segments) are bright and slightly more yellow.
                local heightRatio = s / segments
                local depthShadow = 0.4 + (0.6 * heightRatio)
                
                -- Add a slight yellow tint to the very tips of the grass for realism
                local tipYellow = (heightRatio > 0.7) and (0.1 * heightRatio) or 0
                
                local fR = math.min(1, bR * depthShadow * blade.colorMod + tipYellow)
                local fG = math.min(1, bG * depthShadow * blade.colorMod + tipYellow)
                local fB = math.min(1, bB * depthShadow * blade.colorMod)
                
                love.graphics.setColor(fR, fG, fB)
                
                -- Calculate tapering width
                local currentW = bladeWidth * ((segments - s + 1) / segments)
                local nextW = bladeWidth * ((segments - s) / segments)
                
                -- Distribute physical bending + natural static curve along segments
                love.graphics.rotate((item.angle / segments) + (blade.curve / segments))
                
                -- Draw the segment polygon
                love.graphics.polygon("fill", 
                    -currentW / 2, 0, 
                    currentW / 2, 0, 
                    nextW / 2, -segH, 
                    -nextW / 2, -segH
                )
                
                -- Translate up to the end of this segment for the next loop iteration
                love.graphics.translate(0, -segH)
            end
            
            love.graphics.pop()
        end
        
        love.graphics.pop()
        ::continue::
    end
    -- Reset color to prevent tinting other game assets
    love.graphics.setColor(1, 1, 1, 1)
end

return Vegetation