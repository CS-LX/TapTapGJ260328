-- ============================================================================
-- Game/Camera.lua — 相机跟随 + 死亡震动
-- ============================================================================

local Config = require "Game.Config"
local State  = require "Game.State"

local Camera = {}

function Camera.Update(dt)
    if not State.playerNode then return end
    local playerPos = State.playerNode.position

    local targetPos = Vector3(
        playerPos.x * 0.3,
        playerPos.y + Config.CAM_OFFSET.y,
        playerPos.z + Config.CAM_OFFSET.z
    )

    local camPos = State.cameraNode.position
    State.cameraNode.position = Vector3(
        camPos.x + (targetPos.x - camPos.x) * 5.0 * dt,
        camPos.y + (targetPos.y - camPos.y) * 5.0 * dt,
        camPos.z + (targetPos.z - camPos.z) * 8.0 * dt
    )

    -- 死亡时相机震动
    if State.gameState == Config.STATE_DYING and State.deathTimer < 0.6 then
        local intensity = (1.0 - State.deathTimer / 0.6) * 0.5
        local shakeX = (math.random() - 0.5) * 2 * intensity
        local shakeY = (math.random() - 0.5) * 2 * intensity
        local pos = State.cameraNode.position
        State.cameraNode.position = Vector3(pos.x + shakeX, pos.y + shakeY, pos.z)
    end

    local lookTarget = Vector3(
        playerPos.x * 0.2,
        playerPos.y + 1.5,
        playerPos.z + Config.CAM_LOOK_AHEAD
    )
    State.cameraNode:LookAt(lookTarget)
end

return Camera
