-- v1.3.0 - Clean wireframe debug draw with thin lines and circle angle indicators

local function drawFixture(fixture, bodyAngle)
    local shape = fixture:getShape()
    local shapeType = shape:getType()
    
    if (shapeType == "circle") then
        local x, y = shape:getPoint()
        local radius = shape:getRadius()
        love.graphics.circle("line", x, y, radius, 32)
        
        -- Draw angle indicator line from center to edge
        local angle = bodyAngle
        local endX = x + math.cos(angle) * radius
        local endY = y + math.sin(angle) * radius
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 0, 0.8)  -- Yellow for angle indicator
        love.graphics.line(x, y, endX, endY)
    elseif (shapeType == "polygon") then
        local points = {shape:getPoints()}
        love.graphics.polygon("line", points)
    elseif (shapeType == "edge") then
        love.graphics.line(shape:getPoints())
    elseif (shapeType == "chain") then
        love.graphics.line(shape:getPoints())
    end
end

local function drawBody(body)
    local bx, by = body:getPosition()
    local bodyAngle = body:getAngle()

    love.graphics.push()
    love.graphics.translate(bx, by)
    love.graphics.rotate(bodyAngle)

    local fixtures = body.getFixtures and body:getFixtures() or body:getFixtureList()
    for i = 1, #fixtures do
        if (body:getType() == 'dynamic') then
            if (body:isAwake()) then 
                love.graphics.setColor(1, 0.6, 0.6)  -- Light red for awake dynamic
            else 
                love.graphics.setColor(0.5, 0.5, 0.5)  -- Grey for sleeping dynamic
            end
        elseif (body:getType() == 'static') then 
            love.graphics.setColor(0.4, 0.8, 0.4)  -- Green for static
        elseif (body:getType() == 'kinematic') then 
            love.graphics.setColor(0.4, 0.6, 1.0)  -- Blue for kinematic
        end
        drawFixture(fixtures[i], bodyAngle)
    end
    
    love.graphics.pop()
end

local drawnBodies = {}
local function b2debugDraw_scissor_callback(fixture)
    drawnBodies[fixture:getBody()] = true
    return true
end

local function b2debugDraw(world, topLeft_x, topLeft_y, width, height)
    if not world then return end
    
    love.graphics.push("all")
    drawnBodies = {}
    
    -- Query bodies in view
    world:queryBoundingBox(topLeft_x, topLeft_y, topLeft_x + width, topLeft_y + height, b2debugDraw_scissor_callback)

    -- Draw bodies with thin wireframe
    love.graphics.setLineWidth(0.5)
    for body in pairs(drawnBodies) do
        drawnBodies[body] = nil
        drawBody(body)
    end

    -- Draw joints
    love.graphics.setLineWidth(0.8)
    love.graphics.setColor(0.6, 0.8, 1.0)  -- Light blue for joints
    
    local joints = world.getJoints and world:getJoints() or world:getJointList()
    for i = 1, #joints do
        local joint = joints[i]
        local t = joint:getType()
        
        local x1, y1, x2, y2 = joint:getAnchors()
        if x1 and x2 then
            if t == 'revolute' or t == 'prismatic' or t == 'rope' or t == 'friction' or t == 'weld' or t == 'wheel' or t == 'gear' then
                local bodyA, bodyB = joint:getBodies()
                if bodyA and bodyB then
                    local xA, yA = bodyA:getPosition()
                    local xB, yB = bodyB:getPosition()
                    love.graphics.line(xA, yA, x1, y1)
                    love.graphics.line(x1, y1, x2, y2)
                    love.graphics.line(x2, y2, xB, yB)
                end
            elseif t == 'distance' then
                love.graphics.line(x1, y1, x2, y2)
            elseif t == 'pulley' then
                local a1x, a1y, a2x, a2y = joint:getGroundAnchors()
                if a1x and a2x then
                    love.graphics.line(x1, y1, a1x, a1y)
                    love.graphics.line(a1x, a1y, a2x, a2y)
                    love.graphics.line(a2x, a2y, x2, y2)
                end
            elseif t == 'motor' or t == 'mouse' then
                love.graphics.line(x1, y1, x2, y2)
            end
        end
    end
    
    love.graphics.pop()
end

return b2debugDraw