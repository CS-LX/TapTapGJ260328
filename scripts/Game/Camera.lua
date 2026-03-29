-- ============================================================================
-- Game/Camera.lua — 相机跟随 + 死亡震动
-- ============================================================================

local Config = require "Game.Config"
local State  = require "Game.State"

local Camera = {}

-- ================================================================
-- 渐进式速度动感：根据当前速度渐增 FOV/暗角/后拉/速度线/微震
-- 仅在正常跑步时生效，大运/峡谷激活时自动让位
-- ================================================================
function Camera.UpdateProgressiveFX(dt)
    if State.isAutoJumping or State.isDayunActive then return end
    if State.gameState ~= Config.STATE_PLAYING then return end

    local PFX = Config.PROGRESSIVE_FX
    local speedRatio = (State.runSpeed - Config.START_SPEED)
                     / (Config.MAX_SPEED - Config.START_SPEED)
    speedRatio = math.max(0, math.min(1, speedRatio))

    local function effectRatio(threshold)
        if speedRatio <= threshold then return 0.0 end
        return (speedRatio - threshold) / (1.0 - threshold)
    end

    -- 1. FOV: 45 → 50
    local fovER = effectRatio(PFX.FOV_THRESHOLD)
    State.fxFovTarget = Config.CANYON_FX_FOV_NORMAL + (fovER ^ PFX.FOV_CURVE_EXP) * PFX.FOV_MAX_ADDITION

    -- 2. 暗角: 0 → 0.12
    local vigER = effectRatio(PFX.VIGNETTE_THRESHOLD)
    State.fxVignetteTarget = vigER * PFX.VIGNETTE_MAX

    -- 3. 后拉: 0 → 0.8m
    local pullER = effectRatio(PFX.PULLBACK_THRESHOLD)
    State.fxProgressivePullback = pullER * PFX.PULLBACK_MAX

    -- 4. 速度线: 0 → 0.25 强度
    local lineER = effectRatio(PFX.SPEED_LINE_THRESHOLD)
    local lineIntensity = lineER * PFX.SPEED_LINE_MAX_INTENSITY
    if lineIntensity > 0.01 then
        State.fxSpeedLines = true
        State.fxSpeedLineTargetIntensity = lineIntensity
        State.fxSpeedLineColor = PFX.SPEED_LINE_COLOR
    else
        State.fxSpeedLines = false
        State.fxSpeedLineTargetIntensity = 0.0
    end

    -- 5. 微震: 0 → 0.04
    local shakeER = effectRatio(PFX.SHAKE_THRESHOLD)
    State.fxCamShakeIntensity = (shakeER ^ PFX.SHAKE_CURVE_EXP) * PFX.SHAKE_MAX
end

function Camera.Update(dt)
    if not State.playerNode then return end
    local playerPos = State.playerNode.position

    -- 渐进式速度动感（正常跑步时）
    Camera.UpdateProgressiveFX(dt)

    -- ================================================================
    -- 相机后拉插值（峡谷飞跃 / 大运 / 渐进速度感）
    -- ================================================================
    local pullTarget = State.fxProgressivePullback or 0  -- 渐进基准
    if State.isAutoJumping then
        pullTarget = Config.CANYON_FX_CAM_PULLBACK   -- 飞跃时后拉 4m（覆盖）
    elseif State.isDayunActive then
        pullTarget = Config.DAYUN_FX_CAM_PULLBACK    -- 大运时后拉 2m（覆盖）
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
    elseif State.fxCamShakeIntensity > 0.001 then
        -- 渐进微震（正常高速跑步时）
        local shakeX = (math.random() - 0.5) * 2 * State.fxCamShakeIntensity
        local shakeY = (math.random() - 0.5) * 2 * State.fxCamShakeIntensity
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
