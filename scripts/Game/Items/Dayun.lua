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
Dayun.timer         = 0.0    -- 剩余时间
Dayun.notifyTimer   = 0.0    -- "大运来咯"通知动画计时
Dayun.smashCooldown = 0.0    -- 撞飞音效冷却
Dayun.truckNode     = nil    -- 货车根节点
Dayun.wheelNodes    = {}     -- 车轮节点（用于旋转动画）
Dayun.flyingDebris  = {}     -- 撞飞碎片列表

-- ============================================================================
-- 外部查询
-- ============================================================================

function Dayun.IsActive()
    return State.isDayunActive
end

-- ============================================================================
-- 辅助：创建零件
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

-- ============================================================================
-- 精细货车 3D 模型（挂在 playerNode 下）
-- ============================================================================

function Dayun.BuildTruck()
    if Dayun.truckNode then
        Dayun.truckNode:Remove()
    end
    Dayun.wheelNodes = {}

    local truck = State.playerNode:CreateChild("Truck")
    truck.position = Vector3(0, 0, 0)
    Dayun.truckNode = truck

    -- === 色彩定义 ===
    local RED        = Color(0.82, 0.12, 0.08, 1.0)
    local RED_DARK   = Color(0.60, 0.08, 0.05, 1.0)
    local BLUE       = Color(0.12, 0.25, 0.72, 1.0)
    local BLUE_DARK  = Color(0.08, 0.18, 0.55, 1.0)
    local CHROME     = Color(0.88, 0.88, 0.90, 1.0)
    local DARK_METAL = Color(0.25, 0.25, 0.28, 1.0)
    local BLACK      = Color(0.08, 0.08, 0.08, 1.0)
    local RUBBER     = Color(0.12, 0.12, 0.12, 1.0)
    local GLASS      = Color(0.08, 0.12, 0.22, 1.0)
    local YELLOW     = Color(1.0, 0.85, 0.1, 1.0)
    local ORANGE     = Color(1.0, 0.45, 0.05, 1.0)
    local WHITE      = Color(0.95, 0.95, 0.95, 1.0)
    local TAIL_RED   = Color(0.9, 0.05, 0.02, 1.0)

    -- ================================================================
    -- 底盘 / 车架（黑色金属横梁）
    -- ================================================================
    createPart(truck, "Chassis", Vector3(0, 0.25, -0.8), Vector3(5.4, 0.2, 6.0),
        DARK_METAL, 0.7, 0.4)
    -- 底盘加强横梁
    for _, bz in ipairs({0.5, -0.8, -2.2, -3.5}) do
        createPart(truck, "ChassisBeam", Vector3(0, 0.18, bz), Vector3(5.0, 0.12, 0.15),
            DARK_METAL, 0.6, 0.5)
    end

    -- ================================================================
    -- 驾驶室（红色主体 + 多层细节）
    -- ================================================================
    -- 主体
    createPart(truck, "CabMain", Vector3(0, 1.5, 0.3), Vector3(5.8, 2.4, 2.4),
        RED, 0.3, 0.35, nil, Color(0.15, 0.02, 0.01))
    -- 驾驶室顶部（略窄，造型感）
    createPart(truck, "CabRoof", Vector3(0, 2.75, 0.2), Vector3(5.4, 0.12, 2.2),
        RED_DARK, 0.35, 0.3)
    -- 驾驶室底裙（深红色）
    createPart(truck, "CabSkirt", Vector3(0, 0.35, 0.3), Vector3(5.9, 0.15, 2.5),
        RED_DARK, 0.2, 0.6)

    -- ================================================================
    -- 前脸细节
    -- ================================================================
    -- 前保险杠（厚实铬合金）
    createPart(truck, "BumperMain", Vector3(0, 0.42, 1.55), Vector3(6.2, 0.55, 0.35),
        CHROME, 0.92, 0.1, nil, Color(0.25, 0.25, 0.30))
    -- 保险杠下唇
    createPart(truck, "BumperLip", Vector3(0, 0.18, 1.58), Vector3(5.8, 0.12, 0.2),
        DARK_METAL, 0.7, 0.3)

    -- 前格栅（多条横向铬条）
    for gi = 1, 5 do
        local gy = 0.72 + (gi - 1) * 0.22
        createPart(truck, "Grille" .. gi, Vector3(0, gy, 1.52), Vector3(4.8, 0.08, 0.08),
            CHROME, 0.95, 0.08, nil, Color(0.2, 0.2, 0.22))
    end
    -- 格栅背板（黑色）
    createPart(truck, "GrilleBg", Vector3(0, 1.05, 1.48), Vector3(4.9, 1.0, 0.04),
        BLACK, 0.1, 0.9)

    -- 大灯（左右各一组：主灯 Sphere + 灯罩 Box）
    for _, side in ipairs({-1, 1}) do
        local hx = side * 2.4
        -- 主灯（明亮发光球）
        createPart(truck, "Headlight", Vector3(hx, 1.1, 1.56), Vector3(0.5, 0.5, 0.3),
            WHITE, 0.1, 0.2, "Models/Sphere.mdl", Color(2.0, 2.0, 1.8))
        -- 灯罩框
        createPart(truck, "HeadlightRim", Vector3(hx, 1.1, 1.54), Vector3(0.7, 0.65, 0.06),
            CHROME, 0.9, 0.1)
        -- 转向灯（橙色小灯）
        createPart(truck, "TurnSignal", Vector3(hx, 0.72, 1.56), Vector3(0.35, 0.2, 0.15),
            ORANGE, 0.0, 0.3, "Models/Sphere.mdl", Color(1.2, 0.5, 0.02))
    end

    -- ================================================================
    -- 挡风玻璃 + 侧窗
    -- ================================================================
    -- 主挡风玻璃（倾斜效果通过位置暗示）
    createPart(truck, "Windshield", Vector3(0, 2.15, 1.35), Vector3(4.6, 1.0, 0.08),
        GLASS, 0.6, 0.05, nil, Color(0.03, 0.05, 0.12))
    -- 挡风玻璃框
    createPart(truck, "WsFrame", Vector3(0, 2.15, 1.38), Vector3(4.9, 1.15, 0.04),
        BLACK, 0.3, 0.7)
    -- 侧窗（左右）
    for _, side in ipairs({-1, 1}) do
        createPart(truck, "SideWindow", Vector3(side * 2.82, 2.1, 0.3), Vector3(0.08, 0.85, 1.6),
            GLASS, 0.5, 0.08, nil, Color(0.02, 0.04, 0.10))
    end

    -- ================================================================
    -- 驾驶室顶部装饰
    -- ================================================================
    -- 顶灯条（橙色警示灯条）
    createPart(truck, "LightBar", Vector3(0, 2.88, 0.5), Vector3(4.2, 0.18, 0.25),
        DARK_METAL, 0.5, 0.4)
    -- 5盏顶灯
    for li = -2, 2 do
        createPart(truck, "TopLight" .. li, Vector3(li * 0.8, 2.98, 0.5), Vector3(0.22, 0.12, 0.18),
            YELLOW, 0.0, 0.2, "Models/Sphere.mdl", Color(1.5, 1.2, 0.1))
    end
    -- 遮阳板
    createPart(truck, "SunVisor", Vector3(0, 2.82, 1.42), Vector3(5.0, 0.08, 0.3),
        RED_DARK, 0.2, 0.5)
    -- 气喇叭（车顶两侧）
    for _, side in ipairs({-1, 1}) do
        createPart(truck, "AirHorn", Vector3(side * 1.8, 3.05, 0.0), Vector3(0.12, 0.35, 0.12),
            CHROME, 0.9, 0.1, "Models/Cylinder.mdl", Color(0.15, 0.15, 0.18))
    end

    -- ================================================================
    -- 排气管（两侧各一根竖管）
    -- ================================================================
    for _, side in ipairs({-1, 1}) do
        -- 排气管本体
        createPart(truck, "Exhaust", Vector3(side * 2.95, 1.8, -0.4), Vector3(0.22, 2.8, 0.22),
            CHROME, 0.85, 0.12, "Models/Cylinder.mdl", Color(0.1, 0.1, 0.12))
        -- 排气管顶帽
        createPart(truck, "ExhaustCap", Vector3(side * 2.95, 3.18, -0.4), Vector3(0.30, 0.1, 0.30),
            DARK_METAL, 0.7, 0.3, "Models/Cylinder.mdl")
    end

    -- ================================================================
    -- 后视镜（两侧）
    -- ================================================================
    for _, side in ipairs({-1, 1}) do
        -- 镜臂
        createPart(truck, "MirrorArm", Vector3(side * 3.15, 2.2, 0.9), Vector3(0.4, 0.06, 0.06),
            BLACK, 0.3, 0.6)
        -- 镜面
        createPart(truck, "Mirror", Vector3(side * 3.35, 2.15, 0.9), Vector3(0.06, 0.35, 0.25),
            CHROME, 0.95, 0.05, nil, Color(0.3, 0.3, 0.35))
    end

    -- ================================================================
    -- 油箱（驾驶室侧面下方）
    -- ================================================================
    for _, side in ipairs({-1, 1}) do
        createPart(truck, "FuelTank", Vector3(side * 2.65, 0.5, -0.2), Vector3(0.5, 0.6, 1.2),
            DARK_METAL, 0.6, 0.35, "Models/Cylinder.mdl")
    end

    -- ================================================================
    -- 货厢（蓝色集装箱 + 结构细节）
    -- ================================================================
    -- 主体
    createPart(truck, "CargoMain", Vector3(0, 1.7, -2.5), Vector3(5.5, 3.0, 3.4),
        BLUE, 0.15, 0.45, nil, Color(0.02, 0.04, 0.15))
    -- 货厢顶板
    createPart(truck, "CargoRoof", Vector3(0, 3.22, -2.5), Vector3(5.6, 0.06, 3.5),
        BLUE_DARK, 0.2, 0.5)
    -- 货厢底板
    createPart(truck, "CargoFloor", Vector3(0, 0.22, -2.5), Vector3(5.6, 0.06, 3.5),
        DARK_METAL, 0.5, 0.5)

    -- 货厢加强筋（竖向金属条纹，每侧4根）
    for _, side in ipairs({-1, 1}) do
        for ri = 0, 3 do
            local rz = -1.2 - ri * 0.8
            createPart(truck, "CargoRib", Vector3(side * 2.78, 1.7, rz), Vector3(0.06, 2.8, 0.08),
                BLUE_DARK, 0.3, 0.5)
        end
    end
    -- 货厢底部边框
    for _, side in ipairs({-1, 1}) do
        createPart(truck, "CargoEdge", Vector3(side * 2.72, 0.3, -2.5), Vector3(0.1, 0.12, 3.4),
            DARK_METAL, 0.6, 0.4)
    end

    -- ================================================================
    -- 货厢后门
    -- ================================================================
    createPart(truck, "RearDoor", Vector3(0, 1.7, -4.22), Vector3(5.3, 2.8, 0.1),
        BLUE_DARK, 0.2, 0.5)
    -- 后门铰链（4个）
    for _, hy in ipairs({0.8, 1.5, 2.1, 2.7}) do
        createPart(truck, "Hinge", Vector3(2.5, hy, -4.25), Vector3(0.15, 0.12, 0.08),
            DARK_METAL, 0.7, 0.3)
    end
    -- 后门把手
    createPart(truck, "DoorHandle", Vector3(-0.3, 1.3, -4.28), Vector3(0.5, 0.08, 0.06),
        CHROME, 0.9, 0.1)
    createPart(truck, "DoorHandle2", Vector3(-0.3, 1.0, -4.28), Vector3(0.5, 0.08, 0.06),
        CHROME, 0.9, 0.1)

    -- ================================================================
    -- 尾灯（后方左右，红色发光）
    -- ================================================================
    for _, side in ipairs({-1, 1}) do
        createPart(truck, "TailLight", Vector3(side * 2.4, 1.0, -4.26), Vector3(0.3, 0.5, 0.08),
            TAIL_RED, 0.0, 0.3, nil, Color(1.5, 0.05, 0.02))
        -- 黄色转向灯
        createPart(truck, "RearTurn", Vector3(side * 2.4, 0.55, -4.26), Vector3(0.25, 0.2, 0.08),
            ORANGE, 0.0, 0.3, nil, Color(1.0, 0.4, 0.0))
    end

    -- ================================================================
    -- 车轮系统（前2 + 后4 = 6轮，后轴双轮）
    -- ================================================================
    local wheelScale = Vector3(0.45, 0.75, 0.75)
    local hubScale   = Vector3(0.08, 0.4, 0.4)

    -- 前轮（左右各1）
    local frontWheelZ = 0.8
    for _, side in ipairs({-1, 1}) do
        local wx = side * 2.65
        local wNode = createPart(truck, "WheelF", Vector3(wx, 0.4, frontWheelZ),
            wheelScale, RUBBER, 0.0, 0.85, "Models/Cylinder.mdl")
        wNode.rotation = Quaternion(0, 0, 90)
        table.insert(Dayun.wheelNodes, wNode)
        -- 轮毂
        local hub = createPart(truck, "HubF", Vector3(wx + side * 0.25, 0.4, frontWheelZ),
            hubScale, CHROME, 0.9, 0.1, "Models/Cylinder.mdl")
        hub.rotation = Quaternion(0, 0, 90)
        -- 轮眉/挡泥板
        createPart(truck, "FenderF", Vector3(wx, 0.8, frontWheelZ), Vector3(0.55, 0.08, 0.9),
            RED_DARK, 0.2, 0.5)
    end

    -- 后轮（左右各2，双轮并排）
    local rearWheelZ = -3.0
    for _, side in ipairs({-1, 1}) do
        for _, offset in ipairs({-0.28, 0.28}) do
            local wx = side * (2.45 + offset)
            local wNode = createPart(truck, "WheelR", Vector3(wx, 0.4, rearWheelZ),
                wheelScale, RUBBER, 0.0, 0.85, "Models/Cylinder.mdl")
            wNode.rotation = Quaternion(0, 0, 90)
            table.insert(Dayun.wheelNodes, wNode)
        end
        -- 后轮毂（外侧）
        local hubX = side * 2.95
        local hub = createPart(truck, "HubR", Vector3(hubX, 0.4, rearWheelZ),
            hubScale, CHROME, 0.9, 0.1, "Models/Cylinder.mdl")
        hub.rotation = Quaternion(0, 0, 90)
        -- 后轮挡泥板
        createPart(truck, "FenderR", Vector3(side * 2.65, 0.82, rearWheelZ), Vector3(0.8, 0.08, 1.0),
            BLUE_DARK, 0.2, 0.5)
        -- 挡泥板（泥瓦）
        createPart(truck, "MudFlap", Vector3(side * 2.65, 0.15, rearWheelZ - 0.55), Vector3(0.6, 0.35, 0.04),
            BLACK, 0.0, 0.9)
    end

    -- ================================================================
    -- 踏板 / 登车梯（驾驶室两侧）
    -- ================================================================
    for _, side in ipairs({-1, 1}) do
        createPart(truck, "StepBar", Vector3(side * 2.95, 0.3, 0.3), Vector3(0.15, 0.06, 1.8),
            CHROME, 0.8, 0.15, nil, Color(0.1, 0.1, 0.12))
    end

    -- ================================================================
    -- "大运" 铭牌（前格栅中央，金色发光）
    -- ================================================================
    createPart(truck, "LogoPlate", Vector3(0, 1.6, 1.54), Vector3(1.2, 0.4, 0.06),
        Color(0.85, 0.7, 0.15, 1.0), 0.8, 0.15, nil, Color(0.8, 0.6, 0.05))
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

--- 将障碍节点变成飞行碎片（保留节点，赋予抛物线速度 + 旋转）
local function reparentAsDebris(obsNode)
    if not obsNode then return end

    local worldPos = obsNode.worldPosition
    local worldScale = obsNode.worldScale

    -- 随机飞行方向
    local sideDir = (math.random() > 0.5) and 1 or -1
    local velX = sideDir * (8 + math.random() * 12)
    local velY = 10 + math.random() * 8
    local velZ = -2 + math.random() * 4

    table.insert(Dayun.flyingDebris, {
        node    = obsNode,
        velX    = velX,
        velY    = velY,
        velZ    = velZ,
        rotX    = (math.random() - 0.5) * 600,
        rotY    = (math.random() - 0.5) * 400,
        rotZ    = (math.random() - 0.5) * 500,
        life    = 0,
        maxLife = 2.5,
        originY = worldPos.y,
    })
end

function Dayun.SmashObstacle(obs)
    -- 音效（带冷却防叠音）
    if Dayun.smashCooldown <= 0 then
        SFX.Play("rock_eyebrow_raise.ogg", 0.8)
        Dayun.smashCooldown = 0.4
    end

    -- 把障碍节点变成飞行碎片（不直接删除！）
    if obs.node then
        reparentAsDebris(obs.node)
        obs.node = nil  -- 解除 obs 对节点的引用，不再参与碰撞
    end
    if obs.extraNode then
        reparentAsDebris(obs.extraNode)
        obs.extraNode = nil
    end

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
-- 飞行碎片更新（抛物线 + 旋转 + 缩小消失）
-- ============================================================================

function Dayun.UpdateDebris(dt)
    local GRAVITY = -22.0
    local toRemove = {}

    for i, d in ipairs(Dayun.flyingDebris) do
        d.life = d.life + dt

        if d.life >= d.maxLife or not d.node then
            table.insert(toRemove, i)
        else
            -- 物理运动
            d.velY = d.velY + GRAVITY * dt
            local pos = d.node.position
            pos.x = pos.x + d.velX * dt
            pos.y = pos.y + d.velY * dt
            pos.z = pos.z + d.velZ * dt
            d.node.position = pos

            -- 旋转翻滚
            d.node:Rotate(Quaternion(d.rotX * dt, d.rotY * dt, d.rotZ * dt))

            -- 后半段缩小淡出
            local lifeRatio = d.life / d.maxLife
            if lifeRatio > 0.5 then
                local shrink = 1.0 - (lifeRatio - 0.5) * 2.0  -- 1.0 → 0.0
                shrink = math.max(0.05, shrink)
                local s = d.node.scale
                local avgS = (s.x + s.y + s.z) / 3.0
                if avgS > 0.1 then
                    d.node.scale = s * (1.0 - dt * 2.0)
                end
            end

            -- 掉到地面以下也移除
            if pos.y < -10.0 then
                table.insert(toRemove, i)
            end
        end
    end

    -- 倒序移除
    for i = #toRemove, 1, -1 do
        local idx = toRemove[i]
        local d = Dayun.flyingDebris[idx]
        if d.node then d.node:Remove() end
        table.remove(Dayun.flyingDebris, idx)
    end
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

    -- 飞行碎片更新（无论大运是否激活都要更新，碎片可能在失效后仍在飞）
    Dayun.UpdateDebris(dt)

    if State.isDayunActive then
        -- 倒计时
        Dayun.timer = Dayun.timer - dt

        -- 车轮旋转动画（根据车速转动）
        local wheelRPM = State.runSpeed * 120  -- 越快转越快
        for _, wNode in ipairs(Dayun.wheelNodes) do
            if wNode then
                wNode:Rotate(Quaternion(wheelRPM * dt, 0, 0))
            end
        end

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
    Dayun.wheelNodes = {}
    -- 清理所有飞行碎片
    for _, d in ipairs(Dayun.flyingDebris) do
        if d.node then d.node:Remove() end
    end
    Dayun.flyingDebris  = {}
    Dayun.timer         = 0.0
    Dayun.notifyTimer   = 0.0
    Dayun.smashCooldown = 0.0
end

-- 自动注册到 ItemManager
ItemManager.Register(Dayun)

return Dayun
