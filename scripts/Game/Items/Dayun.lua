-- ============================================================================
-- Game/Items/Dayun.lua — 大运大货车（分数触发变身系统）
-- ============================================================================

local ItemManager = require "Game.Items.ItemManager"
local Config      = require "Game.Config"
local State       = require "Game.State"
local SFX         = require "Game.SFX"
local Player      = require "Game.Player"

local Dayun = {}

-- 内部状态
Dayun.timer        = 0.0    -- 剩余时间
Dayun.notifyTimer  = 0.0    -- "大运来咯"通知动画计时
Dayun.smashCooldown = 0.0   -- 撞飞音效冷却
Dayun.truckNode    = nil    -- 货车根节点

-- ============================================================================
-- 外部查询
-- ============================================================================

function Dayun.IsActive()
    return State.isDayunActive
end

-- ============================================================================
-- 货车 3D 模型（Box/Cylinder 组合，挂在 playerNode 下）
-- ============================================================================

local function createPart(parent, name, pos, scale, color, metallic, roughness, modelName, emissive)
    local node = parent:CreateChild(name)
    node.position = pos
    node.scale = scale
    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", modelName or "Models/Box.mdl"))
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(color))
    mat:SetShaderParameter("Metallic", Variant(metallic or 0.0))
    mat:SetShaderParameter("Roughness", Variant(roughness or 0.5))
    if emissive then
        mat:SetShaderParameter("MatEmissiveColor", Variant(emissive))
    end
    model:SetMaterial(mat)
    model.castShadows = true
    return node
end

function Dayun.BuildTruck()
    if Dayun.truckNode then
        Dayun.truckNode:Remove()
    end

    local truck = State.playerNode:CreateChild("Truck")
    truck.position = Vector3(0, 0, 0)
    Dayun.truckNode = truck

    -- 车头（红色，宽覆盖3赛道 = 2.5*2 + 余量 = 6m）
    createPart(truck, "Cab", Vector3(0, 1.4, 0.3), Vector3(6.0, 2.8, 2.5),
        Color(0.85, 0.15, 0.10, 1.0), 0.3, 0.4, nil,
        Color(0.3, 0.05, 0.02))

    -- 车厢（蓝色，在车头后方）
    createPart(truck, "Cargo", Vector3(0, 1.6, -2.5), Vector3(5.6, 3.2, 3.5),
        Color(0.15, 0.30, 0.75, 1.0), 0.2, 0.5, nil,
        Color(0.03, 0.06, 0.20))

    -- 前保险杠（银色金属，发光）
    createPart(truck, "Bumper", Vector3(0, 0.5, 1.5), Vector3(6.2, 0.6, 0.4),
        Color(0.85, 0.85, 0.88, 1.0), 0.9, 0.15, nil,
        Color(0.4, 0.4, 0.5))

    -- 车顶灯条
    createPart(truck, "RoofLight", Vector3(0, 2.9, 0.3), Vector3(4.0, 0.3, 0.3),
        Color(1.0, 0.9, 0.2, 1.0), 0.0, 0.3, nil,
        Color(1.0, 0.8, 0.1))

    -- 4 个车轮（黑色 Cylinder，旋转90度让侧面朝外）
    local wheelColor = Color(0.12, 0.12, 0.12, 1.0)
    local wheelPositions = {
        Vector3(-2.5, 0.4, 0.8),   -- 左前
        Vector3(2.5, 0.4, 0.8),    -- 右前
        Vector3(-2.5, 0.4, -2.8),  -- 左后
        Vector3(2.5, 0.4, -2.8),   -- 右后
    }
    for i, wpos in ipairs(wheelPositions) do
        local wNode = createPart(truck, "Wheel" .. i, wpos,
            Vector3(0.5, 0.8, 0.8),
            wheelColor, 0.0, 0.9, "Models/Cylinder.mdl")
        wNode.rotation = Quaternion(0, 0, 90)
    end

    -- 挡风玻璃（深色半透明效果）
    createPart(truck, "Windshield", Vector3(0, 2.2, 1.2), Vector3(4.5, 1.2, 0.15),
        Color(0.1, 0.15, 0.25, 1.0), 0.5, 0.1, nil,
        Color(0.05, 0.08, 0.15))
end

-- ============================================================================
-- 激活 / 失效
-- ============================================================================

function Dayun.Activate()
    State.isDayunActive = true
    State.dayunTriggered = true
    Dayun.timer = Config.DAYUN_DURATION
    Dayun.notifyTimer = 2.5
    Dayun.smashCooldown = 0.0

    -- 创建货车模型 + 隐藏玩家
    Dayun.BuildTruck()
    Player.SetVisible(false)

    -- 强制中间赛道
    State.currentLane = 0
    State.targetLaneX = 0.0

    -- 取消跳跃/下蹲状态
    State.isSliding = false
    State.slideTimer = 0

    -- 清除无敌状态（大运本身就无敌）
    State.isInvincible = false
    State.invincibleTimer = 0

    SFX.Play("car_horn.ogg", 0.9)
    print("[Dayun] Activated! Duration: " .. Config.DAYUN_DURATION .. "s")
end

function Dayun.Deactivate()
    State.isDayunActive = false
    Dayun.timer = 0

    -- 删除货车模型 + 显示玩家
    if Dayun.truckNode then
        Dayun.truckNode:Remove()
        Dayun.truckNode = nil
    end
    Player.SetVisible(true)

    -- 强制中间赛道
    State.currentLane = 0
    State.targetLaneX = 0.0

    -- 给予无敌缓冲
    State.isInvincible = true
    State.invincibleTimer = Config.DAYUN_INVINCIBLE_AFTER

    SFX.Play("car_horn.ogg", 0.6)
    print("[Dayun] Deactivated! Invincible buffer: " .. Config.DAYUN_INVINCIBLE_AFTER .. "s")
end

-- ============================================================================
-- 撞飞障碍效果（由 World.lua 调用）
-- ============================================================================

function Dayun.SmashObstacle(obs)
    -- 音效（带冷却防叠音）
    if Dayun.smashCooldown <= 0 then
        SFX.Play("rock_eyebrow_raise.ogg", 0.8)
        Dayun.smashCooldown = 0.4
    end

    -- 移除障碍节点
    if obs.node then obs.node:Remove(); obs.node = nil end
    if obs.extraNode then obs.extraNode:Remove(); obs.extraNode = nil end

    -- 加分 + 弹出文字
    State.score = State.score + 200
    local playerPos = State.playerNode.position
    table.insert(State.scorePopups, {
        worldPos = Vector3(playerPos.x, playerPos.y + 2.0, playerPos.z + 2.0),
        baseY    = playerPos.y + 2.5,
        timer    = 0,
        duration = 0.8,
        text     = "SMASH! +200",
        color    = { 255, 80, 30 },
    })
end

-- ============================================================================
-- Update（ItemManager 生命周期）
-- ============================================================================

function Dayun.Update(dt)
    -- 音效冷却
    if Dayun.smashCooldown > 0 then
        Dayun.smashCooldown = Dayun.smashCooldown - dt
    end

    -- 通知动画倒计时
    if Dayun.notifyTimer > 0 then
        Dayun.notifyTimer = Dayun.notifyTimer - dt
    end

    if State.isDayunActive then
        -- 倒计时
        Dayun.timer = Dayun.timer - dt

        -- 最后 3 秒货车闪烁
        if Dayun.timer < 3.0 and Dayun.truckNode then
            local visible = math.floor(Dayun.timer * 6) % 2 == 0
            Dayun.truckNode:SetEnabled(visible)
        elseif Dayun.truckNode then
            Dayun.truckNode:SetEnabled(true)
        end

        -- 时间到 → 失效
        if Dayun.timer <= 0 then
            Dayun.Deactivate()
        end
    else
        -- 检测激活条件
        if not State.dayunTriggered
            and State.gameState == Config.STATE_PLAYING
            and State.score >= Config.DAYUN_SCORE_THRESHOLD then
            Dayun.Activate()
        end
    end
end

-- ============================================================================
-- HUD 渲染（ItemManager 生命周期）
-- ============================================================================

function Dayun.DrawHUD(vg, w, h)
    -- "大运来咯！！！" 通知动画
    if Dayun.notifyTimer > 0 then
        Dayun.DrawNotification(vg, w, h)
    end

    -- 倒计时显示
    if State.isDayunActive then
        Dayun.DrawCountdown(vg, w, h)
    end
end

function Dayun.DrawNotification(vg, w, h)
    local t = 2.5 - Dayun.notifyTimer  -- 0 → 2.5
    local alpha = 255
    local scale = 1.0

    if t < 0.3 then
        -- 飞入放大
        scale = 0.3 + (t / 0.3) * 0.7
        alpha = math.floor((t / 0.3) * 255)
    elseif t < 2.0 then
        -- 金色闪烁 + 轻微抖动
        scale = 1.0 + math.sin(t * 12) * 0.05
        alpha = 255
    else
        -- 淡出
        local fadeT = (t - 2.0) / 0.5
        alpha = math.floor((1.0 - fadeT) * 255)
        scale = 1.0 + fadeT * 0.3
    end

    if alpha <= 0 then return end

    local fontSize = 52 * scale
    local cx, cy = w / 2, h / 2 - 40

    -- 抖动偏移
    local shakeX = 0
    local shakeY = 0
    if t >= 0.3 and t < 2.0 then
        shakeX = math.sin(t * 25) * 3
        shakeY = math.cos(t * 30) * 2
    end

    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, fontSize)

    -- 黑色阴影
    nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(alpha * 0.6)))
    nvgText(vg, cx + shakeX + 3, cy + shakeY + 3, "大运来咯！！！")

    -- 金色主文字
    local pulse = math.abs(math.sin(t * 8))
    local r = math.floor(255)
    local g = math.floor(180 + pulse * 75)
    local b = math.floor(30 + pulse * 40)
    nvgFillColor(vg, nvgRGBA(r, g, b, alpha))
    nvgText(vg, cx + shakeX, cy + shakeY, "大运来咯！！！")
end

function Dayun.DrawCountdown(vg, w, h)
    local remaining = math.max(0, Dayun.timer)
    local countdownAlpha = 255

    -- 最后 3 秒闪烁
    if remaining < 3.0 then
        countdownAlpha = math.floor(math.abs(math.sin(GetTime():GetElapsedTime() * 6)) * 255)
    end

    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 22)
    nvgFillColor(vg, nvgRGBA(255, 100, 30, countdownAlpha))
    nvgText(vg, w / 2 + 50, 55, string.format("🚛 %.1fs", remaining))
end

-- ============================================================================
-- Reset / ClearAll（ItemManager 生命周期）
-- ============================================================================

function Dayun.Reset()
    Dayun.timer        = 0.0
    Dayun.notifyTimer  = 0.0
    Dayun.smashCooldown = 0.0
end

function Dayun.ClearAll()
    if Dayun.truckNode then
        Dayun.truckNode:Remove()
        Dayun.truckNode = nil
    end
    Dayun.timer        = 0.0
    Dayun.notifyTimer  = 0.0
    Dayun.smashCooldown = 0.0
end

-- 自动注册到 ItemManager
ItemManager.Register(Dayun)

return Dayun
