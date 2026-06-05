-- config.lua (FIXED - increased active radius)
local Config = {
    -- Physics Setup
    physics = {
        meter = 64,
        gravityY = 9.81 * 64,
        -- gravityY = 0,
        linearDamping = 8.0,
        angularDamping = 8.0
    },

    -- Optimization & Chunk Loading Settings
    chunks = {
        size = 1000,         -- Size of each square chunk in world units
        activeRadius = 10,   -- INCREASED: Number of chunks to keep awake (was 2)
        updateInterval = 0.5 -- How often (seconds) to recalculate active chunks
    },

    -- Player Tuning
    player = {
        width = 12.5,
        height = 25,
        mass = 1.0,
        friction = 0.1,
        restitution = 0.2,
        maxHealth = 10000000,
        moveForceX = 30,
        moveForceYUp = -90,
        moveForceYDown = 20,
        torqueForce = 45,
        stabilizationTorque = -30,
        stabilizationDamping = -2.5,
        thrusterCooldown = 0.03
    },

    -- Enemy Balancing
    enemy = {
        width = 12.5,
        height = 25,
        mass = 1.2,
        friction = 0.1,
        restitution = 0.2,
        maxForce = 130,
        trackingScale = 0.001,
        stabilizationTorque = -100,
        stabilizationDamping = -2.5,
        thrusterCooldown = 0.08,
        grabRadius = 200
    },

    -- Rope Mechanics
    rope = {
        minSegments = 3,
        maxSegments = 23,
        segmentDensity = 0.3,
        thickness = 2,
        extraLengthLimit = 2
    },

    -- Camera System
    camera = {
        freeSpeed = 300,
        minScale = 0.1,
        maxScale = 3.0,
        zoomFactor = 1.1,
        lerpSpeed = 0.99
    }
}

return Config