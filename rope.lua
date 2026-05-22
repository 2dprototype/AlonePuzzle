local Config = require("config")
local WorldManager = require("world_manager")

local RopeSystem = {
    collection = {},
    nextId = 1
}

function RopeSystem.getEdgePoint(obj, targetX, targetY)
    if not obj or not obj.body or obj.body:isDestroyed() then return targetX, targetY end
    
    local cx, cy = obj.body:getPosition()
    local dx, dy = targetX - cx, targetY - cy
    local dist = math.sqrt(dx*dx + dy*dy)
    if dist == 0 then return cx, cy end
    dx, dy = dx/dist, dy/dist

    if obj.type == "ball" then
        return cx + dx * obj.r, cy + dy * obj.r
    elseif obj.type == "box" or obj.type == "enemy" or obj.type == "player" then
        local angle = obj.body:getAngle()
        local cosA, sinA = math.cos(-angle), math.sin(-angle)
        local ldx = dx * cosA - dy * sinA
        local ldy = dx * sinA + dy * cosA
        
        local hw = (obj.w or 20) / 2
        local hh = (obj.h or 20) / 2
        
        local tx = (ldx ~= 0) and math.abs(hw / ldx) or math.huge
        local ty = (ldy ~= 0) and math.abs(hh / ldy) or math.huge
        local t = math.min(tx, ty)
        
        local lx, ly = ldx * t, ldy * t
        cosA, sinA = math.cos(angle), math.sin(angle)
        return cx + (lx * cosA - ly * sinA), cy + (lx * sinA + ly * cosA)
    end
    return cx, cy
end

function RopeSystem.create(obj1, obj2)
    if not obj1 or not obj2 or not obj1.body or not obj2.body then return nil end
    if obj1.body:isDestroyed() or obj2.body:isDestroyed() then return nil end
    
    local cx2, cy2 = obj2.body:getPosition()
    local anchor1X, anchor1Y = RopeSystem.getEdgePoint(obj1, cx2, cy2)
    
    local cx1, cy1 = obj1.body:getPosition()
    local anchor2X, anchor2Y = RopeSystem.getEdgePoint(obj2, cx1, cy1)
    
    local dx, dy = anchor2X - anchor1X, anchor2Y - anchor1Y
    local distance = math.sqrt(dx*dx + dy*dy)
    local numSegments = math.max(Config.rope.minSegments, math.min(Config.rope.maxSegments, math.floor(distance / 10)))
    local angle = math.atan2(dy, dx)
    local segLength = distance / numSegments
    local ux, uy = dx / distance, dy / distance
    
    local segments, joints = {}, {}
    local prevBody = obj1.body
    local prevX, prevY = anchor1X, anchor1Y
    
    local wWorld = WorldManager.world
    for i = 1, numSegments do
        local cx = anchor1X + ux * (segLength * (i - 0.5))
        local cy = anchor1Y + uy * (segLength * (i - 0.5))
        
        local segBody = love.physics.newBody(wWorld, cx, cy, "dynamic")
        segBody:setAngle(angle)
        
        local segShape = love.physics.newRectangleShape(segLength, Config.rope.thickness)
        local segFixture = love.physics.newFixture(segBody, segShape, Config.rope.segmentDensity)
        segFixture:setSensor(true)
        segFixture:setFriction(0.2)
        
        segBody:setLinearDamping(Config.physics.linearDamping)
        segBody:setAngularDamping(Config.physics.angularDamping)
        
        table.insert(segments, segBody)
        table.insert(joints, love.physics.newRevoluteJoint(prevBody, segBody, prevX, prevY, false))
        
        prevBody = segBody
        prevX = anchor1X + ux * (segLength * i)
        prevY = anchor1Y + uy * (segLength * i)
    end
    
    table.insert(joints, love.physics.newRevoluteJoint(prevBody, obj2.body, anchor2X, anchor2Y, false))
    local limitRope = love.physics.newRopeJoint(obj1.body, obj2.body, anchor1X, anchor1Y, anchor2X, anchor2Y, distance + Config.rope.extraLengthLimit, false)
    
    local ropeId = RopeSystem.nextId
    RopeSystem.nextId = RopeSystem.nextId + 1
    
    local rope = {
        id = ropeId, segments = segments, joints = joints, limitRope = limitRope,
        obj1 = obj1, obj2 = obj2, anchor1 = {x = anchor1X, y = anchor1Y}, anchor2 = {x = anchor2X, y = anchor2Y},
        isDestroyed = false
    }
    
    RopeSystem.collection[ropeId] = rope
    obj1.ropeIds = obj1.ropeIds or {}
    obj2.ropeIds = obj2.ropeIds or {}
    table.insert(obj1.ropeIds, ropeId)
    table.insert(obj2.ropeIds, ropeId)
    
    return ropeId
end

function RopeSystem.updateVisuals()
    for id, rope in pairs(RopeSystem.collection) do
        if rope.isDestroyed then
            RopeSystem.collection[id] = nil
        else
            if not rope.obj1 or not rope.obj2 or not rope.obj1.body or not rope.obj2.body or 
               rope.obj1.body:isDestroyed() or rope.obj2.body:isDestroyed() then
                RopeSystem.destroy(id)
            else
                local cx2, cy2 = rope.obj2.body:getPosition()
                local ax, ay = RopeSystem.getEdgePoint(rope.obj1, cx2, cy2)
                rope.anchor1 = {x = ax, y = ay}
                
                local cx1, cy1 = rope.obj1.body:getPosition()
                local ax2, ay2 = RopeSystem.getEdgePoint(rope.obj2, cx1, cy1)
                rope.anchor2 = {x = ax2, y = ay2}
            end
        end
    end
end

function RopeSystem.destroy(ropeId)
    local rope = RopeSystem.collection[ropeId]
    if not rope or rope.isDestroyed then return end
    
    if rope.limitRope and not rope.limitRope:isDestroyed() then rope.limitRope:destroy() end
    for _, joint in ipairs(rope.joints) do
        if joint and not joint:isDestroyed() then joint:destroy() end
    end
    for _, body in ipairs(rope.segments) do
        if body and not body:isDestroyed() then body:destroy() end
    end
    
    if rope.obj1 and rope.obj1.ropeIds then
        for i, rid in ipairs(rope.obj1.ropeIds) do
            if rid == ropeId then table.remove(rope.obj1.ropeIds, i); break end
        end
    end
    if rope.obj2 and rope.obj2.ropeIds then
        for i, rid in ipairs(rope.obj2.ropeIds) do
            if rid == ropeId then table.remove(rope.obj2.ropeIds, i); break end
        end
    end
    
    rope.isDestroyed = true
    RopeSystem.collection[ropeId] = nil
end

function RopeSystem.destroyAllForObject(obj)
    if not obj or not obj.ropeIds then return end
    local copy = {}
    for _, id in ipairs(obj.ropeIds) do table.insert(copy, id) end
    for _, id in ipairs(copy) do RopeSystem.destroy(id) end
    obj.ropeIds = {}
end

function RopeSystem.connects(obj1, obj2)
    if not obj1.ropeIds then return false end
    for _, id in ipairs(obj1.ropeIds) do
        local r = RopeSystem.collection[id]
        if r and ((r.obj1 == obj2) or (r.obj2 == obj2)) then return true end
    end
    return false
end

function RopeSystem.drawAll(debugMode)
    for _, rope in pairs(RopeSystem.collection) do
        if not rope.isDestroyed and #rope.segments > 0 then
            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.setLineWidth(1)
            
            local prevX, prevY = rope.anchor1.x, rope.anchor1.y
            for _, segBody in ipairs(rope.segments) do
                if segBody and not segBody:isDestroyed() then
                    local currX, currY = segBody:getPosition()
                    love.graphics.line(prevX, prevY, currX, currY)
                    prevX, prevY = currX, currY
                end
            end
            love.graphics.line(prevX, prevY, rope.anchor2.x, rope.anchor2.y)
            
            if debugMode then
                love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
                for _, segBody in ipairs(rope.segments) do
                    if segBody and not segBody:isDestroyed() then
                        local fixtures = segBody:getFixtures()
                        if fixtures[1] then
                            local shape = fixtures[1]:getShape()
                            if shape:getType() == "polygon" then
                                love.graphics.polygon("line", segBody:getWorldPoints(shape:getPoints()))
                            end
                        end
                    end
                end
            end
        end
    end
end

return RopeSystem