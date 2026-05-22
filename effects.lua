local EffectsSystem = {
    particles = {},
    damageEffects = {}
}

function EffectsSystem.createDamageEffect(x1, y1, x2, y2, isLessIntense)
    -- Insert the slice line with an intensity flag
    table.insert(EffectsSystem.damageEffects, {
        x1 = x1, y1 = y1,
        x2 = x2, y2 = y2,
        life = isLessIntense and 0.12 or 0.30, -- Damage ticks fade away much quicker
        isLessIntense = isLessIntense,
        type = "cutLine"
    })
    
    -- Drop particle counts significantly if it is just a less intense damage tick
    local numSparks = isLessIntense and 2 or 12
    for i = 1, numSparks do
        local t = love.math.random()
        local sparkX = x1 + (x2 - x1) * t
        local sparkY = y1 + (y2 - y1) * t
        
        local angle = love.math.random() * math.pi * 2
        local speed = isLessIntense and love.math.random(20, 50) or love.math.random(40, 90)
        local vx = math.cos(angle) * speed
        local vy = math.sin(angle) * speed
        
        EffectsSystem.createParticle(sparkX, sparkY, vx, vy, 12, 350, 1.5, "orangeSpark")
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
    for i = #EffectsSystem.damageEffects, 1, -1 do
        local fx = EffectsSystem.damageEffects[i]
        fx.life = fx.life - dt
        if fx.life <= 0 then table.remove(EffectsSystem.damageEffects, i) end
    end
    
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
    for _, fx in ipairs(EffectsSystem.damageEffects) do
        if fx.type == "cutLine" then
            local alpha = math.min(1, fx.life * 4)
            -- Scale overall transparency down if it's a minor damage preview cut
            if fx.isLessIntense then alpha = alpha * 0.35 end
            
            -- 1. Outer heavy glow
            love.graphics.setLineWidth(fx.isLessIntense and 3 or 6)
            love.graphics.setColor(1, 0.25, 0, alpha * 0.4)
            love.graphics.line(fx.x1, fx.y1, fx.x2, fx.y2)
            
            -- 2. Mid-tone neon line
            love.graphics.setLineWidth(fx.isLessIntense and 1.5 or 3)
            love.graphics.setColor(1, 0.50, 0, alpha * 0.7)
            love.graphics.line(fx.x1, fx.y1, fx.x2, fx.y2)
            
            -- 3. White-hot inner core (Skip entirely on low intensity for a duller iron look)
            if not fx.isLessIntense then
                love.graphics.setLineWidth(1.2)
                love.graphics.setColor(1, 0.85, 0.3, alpha)
                love.graphics.line(fx.x1, fx.y1, fx.x2, fx.y2)
            end
            
            love.graphics.setLineWidth(1)
        end
    end
    
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