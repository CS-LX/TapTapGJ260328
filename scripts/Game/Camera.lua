-- ============================================================================
-- Game/Camera.lua — 相机跟随 + 死亡震动
-- ============================================================================

local Config = require "Game.Config"
local State  = require "Game.State"

local Camera = {}

function Camera.Update(dt)
    if not State.playerNode then return end
    local playerPos = State.playerNode.position

    -- ================================================================
    -- 相机后拉插值（峡谷飞跃 / 大运期间拉远镜头）
    -- ================================================================
    local pullTarget = 0
    if State.isAutoJumping then
        pullTarget = Config.CANYON_FX_CAM_PULLBACK   -- 飞跃时后拉 4m
    elseif State.isDayunActive then
        pullTarget = Config.DAYUN_FX_CAM_PULLBACK    -- 大运时后拉 2m
    end
    State.fxCamPullback = State.fxCamPullback + (pullTarget - State.fxCamPullback) * 3.0 * dt

    local targetPos = Vector3(
        playerPos.x * 0.3,
        playerPos.y + Config.CAM_OFFSET.y,
        playerPos.z + Config.CAM_OFFSET.z - State.fxCamPullback
    )

    local camPos = State.cameraNode.position
    State.cameraNode.position = Vector3(
        camPos.x + (targetPos.x - camPos.x) * 5.0 * dt,
        camPos.y + (targetPos.y - camPos.y) * 5.0 * dt,
        camPos.z + (targetPos.z - camPos.z) * 8.0 * dt
    )

    -- ================================================================
    -- 速度微震（飞跃 / 大运期间持续轻微抖动）
    -- ================================================================
    if State.isAutoJumping or State.isDayunActive then
        local intensity = State.isAutoJumping and 0.15 or 0.08
        local shakeX = (math.random() - 0.5) * 2 * intensity
        local shakeY = (math.random() - 0.5) * 2 * intensity
        local pos = State.cameraNode.position
        State.cameraNode.position = Vector3(pos.x + shakeX, pos.y + shakeY, pos.z)
    end

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

    -- ================================================================
    -- FOV 平滑插值（正常 45° → 飞跃 65° → 大运 55°）
    -- ================================================================
    State.fxFovCurrent = State.fxFovCurrent + (State.fxFovTarget - State.fxFovCurrent) * 4.0 * dt
    local cam = State.cameraNode:GetComponent("Camera")
    if cam then
        cam.fov = State.fxFovCurrent
    end
end

return Camera
