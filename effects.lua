local EffectsSystem = {
    particles = {},
    damageEffects = {}
}

function EffectsSystem.createDamageEffect(x, y)
    -- Create a damage flash effect similar to slice lines
    table.insert(EffectsSystem.damageEffects, {
        x = x, y = y, life = 0.25,
        vx = love.math.random(-30, 30), vy = love.math.random(-30, 30),
        type = "damageFlash"
    })
    
    -- Add orange sparks (like the slicing sparks)
    local numSparks = 8
    for i = 1, numSparks do
        local angle = love.math.random() * math.pi * 2
        local speed = love.math.random(40, 100)
        local vx = math.cos(angle) * speed + love.math.random(-10, 10)
        local vy = math.sin(angle) * speed + love.math.random(-10, 10)
        
        EffectsSystem.createParticle(x, y, vx, vy, 15, 300, 2.5, "orangeSpark")
    end
    
    -- Add glowing embers
    for i = 1, 6 do
        local angle = love.math.random() * math.pi * 2
        local speed = love.math.random(20, 60)
        local vx = math.cos(angle) * speed
        local vy = math.sin(angle) * speed
        
        EffectsSystem.createParticle(x, y, vx, vy, 12, 250, 3, "ember")
    end
    
    -- Add smoke
    for i = 1, 4 do
        local vx = love.math.random(-20, 20)
        local vy = love.math.random(-30, 0)
        
        EffectsSystem.createParticle(x, y, vx, vy, 20, 120, 4, "smoke")
    end
end

function EffectsSystem.createParticle(x, y, vx, vy, life, fadeSpeed, size, pType)
    table.insert(EffectsSystem.particles, {
        x = x, y = y, vx = vx, vy = vy,
        life = life, fadeSpeed = fadeSpeed,
        size = size or 2, type = pType, scale = 1
    })
end

function EffectsSystem.update(dt)
    -- Update damage effects
    for i = #EffectsSystem.damageEffects, 1, -1 do
        local fx = EffectsSystem.damageEffects[i]
        fx.life = fx.life - dt
        fx.x = fx.x + fx.vx * dt
        fx.y = fx.y + fx.vy * dt
        if fx.life <= 0 then table.remove(EffectsSystem.damageEffects, i) end
    end
    
    -- Update slice effects (the cutting lines)
    if _G.sliceEffects then
        for i = #_G.sliceEffects, 1, -1 do
            local se = _G.sliceEffects[i]
            se.life = se.life - dt
            if se.life <= 0 then
                table.remove(_G.sliceEffects, i)
            end
        end
    end
    
    -- Update particles
    for i = #EffectsSystem.particles, 1, -1 do
        local p = EffectsSystem.particles[i]
        p.life = p.life - dt * (p.fadeSpeed or 200)
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + 0.05
        if p.scale then p.scale = p.scale - dt * 2 end
        if p.life <= 0 then table.remove(EffectsSystem.particles, i) end
    end
end

function EffectsSystem.draw()
    -- Draw damage effects (like slice lines but radial)
    for _, fx in ipairs(EffectsSystem.damageEffects) do
        if fx.type == "damageFlash" then
            local alpha = math.min(1, fx.life * 4)  -- Fades out quickly
            
            -- Outer glow (bright orange)
            love.graphics.setLineWidth(6)
            love.graphics.setColor(1, 0.3, 0, alpha * 0.5)
            love.graphics.circle("line", fx.x, fx.y, 12 * fx.life)
            
            -- Middle glow (orange)
            love.graphics.setLineWidth(3)
            love.graphics.setColor(1, 0.5, 0, alpha * 0.7)
            love.graphics.circle("line", fx.x, fx.y, 8 * fx.life)
            
            -- Inner core (yellow/white hot)
            love.graphics.setLineWidth(1.5)
            love.graphics.setColor(1, 0.8, 0.2, alpha)
            love.graphics.circle("line", fx.x, fx.y, 4 * fx.life)
            
            -- Reset line width
            love.graphics.setLineWidth(1)
        end
    end
    
    -- Draw slice lines (orange hot cutter effect)
    if _G.sliceEffects then
        for _, se in ipairs(_G.sliceEffects) do
            if se.type == "sliceLine" then
                local alpha = math.min(1, se.life * 4)
                -- Outer glow (bright orange)
                love.graphics.setLineWidth(8)
                love.graphics.setColor(1, 0.3, 0, alpha * 0.4)
                love.graphics.line(se.x1, se.y1, se.x2, se.y2)
                -- Middle glow (orange)
                love.graphics.setLineWidth(4)
                love.graphics.setColor(1, 0.5, 0, alpha * 0.7)
                love.graphics.line(se.x1, se.y1, se.x2, se.y2)
                -- Inner core (yellow/white hot)
                love.graphics.setLineWidth(2)
                love.graphics.setColor(1, 0.8, 0.2, alpha)
                love.graphics.line(se.x1, se.y1, se.x2, se.y2)
                -- Reset line width
                love.graphics.setLineWidth(1)
            end
        end
    end
    
    -- Draw particles (rest of the code remains the same)
    for _, p in ipairs(EffectsSystem.particles) do
        local alpha = math.min(1, p.life / 50)
        
        if p.type == "thruster" then
            love.graphics.setColor(1, 0.5 + (p.life / 100) * 0.5, 0, alpha * 0.8)
        elseif p.type == "enemy_thruster" then
            love.graphics.setColor(1, 0.2 + (p.life / 100) * 0.3, 0, alpha * 0.7)
        elseif p.type == "orangeSpark" then
            local intensity = 0.8 + math.random() * 0.4
            love.graphics.setColor(1, 0.5 * intensity, 0.1, alpha)
        elseif p.type == "ember" then
            love.graphics.setColor(1, 0.4, 0.05, alpha * 0.9)
        elseif p.type == "smoke" then
            love.graphics.setColor(0.3, 0.3, 0.3, alpha * 0.5)
        else
            love.graphics.setColor(1, 1, 1, alpha)
        end
        
        local sz = (p.size or 2) * (p.scale or 1)
        love.graphics.circle("fill", p.x, p.y, math.max(0.5, sz))
    end
end

return EffectsSystem