-- main.lua (FIXED - added camera position initialization and proper chunk loading)
local Config = require("config")
local Camera = require("camera")
local WorldManager = require("world_manager")
local RopeSystem = require("rope")
local EffectsSystem = require("effects")
local Entities = require("entities")

local game = { debugMode = false, state = "playing" }
local cameraInstructions = {
    "F1: Follow Player", "F2: Follow Enemy", "F3: Free Move",
    "Wheel or -/+: Zoom", "WASD: Free Move", "R: Reset Zoom",
    "F5: Toggle Debug Mode", "SPACE: Grab/Release Object",
    "E: Grab Enemy", "SHIFT: Connect two objects & detach"
}

function love.load()
    WorldManager.init()
    
    -- Instantiate Scene Objects
    Entities.createPlayer(-820, 0)
    
    -- Populating Physical Rigid Props
    Entities.createBox(-800, 570, 8, 80, 0, 2, 0.2)
    Entities.createBox(-840, 570, 8, 80, 0, 2, 0.2)
    Entities.createBox(-820, 300, 80, 30, 0, 0.6, 0.2)
    Entities.createBall(260, 430, 12.5, -700, 2, 0.5)
    Entities.createBall(-390, 150, 25, -15, 1, 0.1)
    
    -- Grid Matrix Generator Setup (more boxes)
    for r = 0, 2 do
        for c = 0, 2 do
            Entities.createBox(-1600 + (c * 60), 800 - (r * 60), 30, 30, 0, 0.1, 0.2, string.format("Grid%d%d", c, r))
        end
    end
    
    -- Add more boxes to make the map interesting
    Entities.createBox(-900, 400, 20, 20, 0, 1.5, 0.3, "box1")
    Entities.createBox(-750, 350, 15, 40, 0.5, 1.2, 0.2, "box2")
    Entities.createBox(-1000, 600, 25, 25, 0, 2.0, 0.1, "box3")
    Entities.createBox(-1100, 650, 12, 60, 0.3, 0.8, 0.4, "box4")
    
    -- Add more balls
    Entities.createBall(-1590, 1000, 28, 0, 0.1, 0.8)
    Entities.createBall(-1300, 1000, 30, 0, 0.05, 0.8)
    
    -- Enemies
    -- Entities.createEnemy(-8900, -520, 12.5, 25, 0)
    -- Entities.createEnemy(-8850, -550, 15, 20, 0)
    
    -- Populating Static Ground Structures
    WorldManager.createBoundary(320, 500, 600, 10, 0)
    WorldManager.createBoundary(-100, 350, 600, 10, 0.3)
    WorldManager.createBoundary(-485, 261, 200, 10, 0)
    WorldManager.createBoundary(-265, 589, 600, 10, -0.3)
    WorldManager.createBoundary(-700, 605, 300, 10, 0)
    WorldManager.createBoundary(-700, 678, 300, 10, 0)
    WorldManager.createBoundary(-1260, 820, 300, 10, 0)
    WorldManager.createBoundary(-1540, 825, 180, 10, 0)
    WorldManager.createBoundary(-1565, 1005, 250, 10, 0)
    WorldManager.createBoundary(-1300, 1005, 250, 10, 0)
    WorldManager.createBoundary(-1685, 905, 10, 200, 0)
    WorldManager.createBoundary(-980, 749, 300, 10, -0.5)
    WorldManager.createBoundary(-440, 620, 80, 5, 0.4)
    
    WorldManager.updateSpatialGrid(Entities.list)
    
    -- Set camera to player position
    local player = Entities.player
    if player and player.body then
        local px, py = player.body:getPosition()
        Camera.x = px
        Camera.y = py
    end
    
    WorldManager.optimizeActiveChunks(Camera.x, Camera.y)
end

function love.update(dt)
    if game.state ~= "playing" then return end
    
    WorldManager.world:update(dt)
    Entities.update(dt)
    Entities.checkCollisions()
    RopeSystem.updateVisuals()
    EffectsSystem.update(dt)
    Camera.update(dt, Entities.player, Entities.list)
    
    -- Throttled Spatial Grid Chunk Optimization Processing Block
    WorldManager.timer = WorldManager.timer + dt
    if WorldManager.timer >= Config.chunks.updateInterval then
        WorldManager.timer = 0
        WorldManager.updateSpatialGrid(Entities.list)
        WorldManager.optimizeActiveChunks(Camera.x, Camera.y)
    end
end

function love.draw()
    love.graphics.clear(0.15, 0.15, 0.15)
    love.graphics.push()
    
    Camera.apply()
    
    local oldFont = love.graphics.getFont()
    local smallFont = love.graphics.newFont(8)
    love.graphics.setFont(smallFont)
    
    WorldManager.drawBoundaries()
    Entities.draw()
    RopeSystem.drawAll(game.debugMode)
    EffectsSystem.draw()
    
    love.graphics.setFont(oldFont)
    if game.debugMode then drawDebugData() end
    
    love.graphics.pop()
    drawUI()
end

function love.keypressed(key)
    if key == "escape" then love.event.quit()
    elseif key == "f1" then Camera.mode = "follow_player"
    elseif key == "f2" then Camera.mode = "follow_enemy"
    elseif key == "f3" then Camera.mode = "free_move"
    elseif key == "=" or key == "+" then Camera.scale = math.min(Camera.scale + 0.1, Config.camera.maxScale)
    elseif key == "-" or key == "_" then Camera.scale = math.max(Camera.scale - 0.1, Config.camera.minScale)
    elseif key == "r" then Camera.scale = 1.0 
    elseif key == "f5" then
        game.debugMode = not game.debugMode
        Entities.setDebugMode(game.debugMode)
    elseif key == "tab" then
        -- Entities.sliceTouchingObject()
        print("tab")
    elseif key == "p" then game.state = (game.state == "playing") and "paused" or "playing"
    elseif key == "space" then
        local p = Entities.player
        if p then
            if p.ropeIds and #p.ropeIds == 2 then 
                RopeSystem.destroyAllForObject(p) 
            else 
                Entities.grab(false) 
            end
        end
    elseif key == "e" then
        Entities.grab(true)
    elseif key == "lshift" or key == "rshift" then
        local p = Entities.player
        if p and p.ropeIds and #p.ropeIds == 2 then
            local ids = {}
            for _, id in ipairs(p.ropeIds) do table.insert(ids, id) end
            if #ids >= 2 then
                local r1, r2 = RopeSystem.collection[ids[1]], RopeSystem.collection[ids[2]]
                if r1 and r2 then
                    local o1 = (r1.obj1 == p) and r1.obj2 or r1.obj1
                    local o2 = (r2.obj1 == p) and r2.obj2 or r2.obj1
                    if o1 and o2 then
                        RopeSystem.destroy(ids[1])
                        RopeSystem.destroy(ids[2])
                        RopeSystem.create(o1, o2)
                        -- local jx, jy = p.body:getWorldPoint(0, p.h / 2)
                        -- for i = 1, 20 do EffectsSystem.createDamageEffect(jx, jy) end
                    end
                end
            end
        end
    end
end

function love.wheelmoved(x, y)
    local factor = Config.camera.zoomFactor
    if y > 0 then Camera.scale = math.min(Camera.scale * factor, Config.camera.maxScale)
    elseif y < 0 then Camera.scale = math.max(Camera.scale / factor, Config.camera.minScale)
    end
end

function drawUI()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("State: " .. game.state, 10, 10)
    love.graphics.print("Camera Mode: " .. Camera.mode, 10, 30)
    love.graphics.print("Zoom: " .. string.format("%.2f", Camera.scale), 10, 50)
    
    local p = Entities.player
    if p and p.body and not p.body:isDestroyed() then
        local px, py = p.body:getPosition()
        love.graphics.print("Player: " .. math.floor(px) .. ", " .. math.floor(py), 10, 80)
        love.graphics.print("Ropes Attached: " .. #(p.ropeIds or {}) .. "/2", 10, 100)
    end
    
    if game.debugMode then
        love.graphics.setColor(1, 0, 0)
        love.graphics.print("DEBUG MODE ACTIVE", 10, 130)
        love.graphics.setColor(1, 1, 1)
        local count = 0 for _ in pairs(RopeSystem.collection) do count = count + 1 end
        love.graphics.print("Active Ropes: " .. count, 10, 150)
        love.graphics.print("Total Entities: " .. #Entities.list, 10, 170)
    end
    
    love.graphics.print("Controls:", love.graphics.getWidth() - 220, 10)
    for i, inst in ipairs(cameraInstructions) do
        love.graphics.print(inst, love.graphics.getWidth() - 220, 10 + i * 18)
    end
end

function drawDebugData()
    love.graphics.setColor(0, 0.5, 0, 0.3)
    for _, b in ipairs(WorldManager.boundaries) do
        if b.body and not b.body:isDestroyed() then
            love.graphics.polygon("line", b.body:getWorldPoints(b.shape:getPoints()))
        end
    end
    
    local p = Entities.player
    if p and p.body and not p.body:isDestroyed() then
        local x, y = p.body:getPosition()
        local vx, vy = p.body:getLinearVelocity()
        love.graphics.setColor(0, 0.5, 1, 0.8)
        love.graphics.line(x, y, x + vx, y + vy)
    end
end