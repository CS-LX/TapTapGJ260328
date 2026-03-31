-- ============================================================================
-- Game/Player.lua — 玩家创建、移动、输入、碰撞
-- ============================================================================

local Config      = require "Game.Config"
local State       = require "Game.State"
local ItemManager = require "Game.Items.ItemManager"
local BGM         = require "Game.BGM"
local SFX         = require "Game.SFX"
local Scenery     = require "Game.World.Scenery"

local Player = {}

-- ============================================================================
-- 创建玩家
-- ============================================================================

function Player.Create()
    State.playerNode = State.scene:CreateChild("Player")
    State.playerNode.position = Vector3(0, 0, 0)

    -- 身体
    local bodyNode = State.playerNode:CreateChild("Body")
    bodyNode.position = Vector3(0, 0.9, 0)
    bodyNode.scale = Vector3(0.6, 1.8, 0.5)
    local bodyModel = bodyNode:CreateComponent("StaticModel")
    bodyModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    local bodyMat = Material:new()
    bodyMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    bodyMat:SetShaderParameter("MatDiffColor", Variant(Color(0.2, 0.5, 0.9, 1.0)))
    bodyMat:SetShaderParameter("Metallic", Variant(0.1))
    bodyMat:SetShaderParameter("Roughness", Variant(0.6))
    bodyModel:SetMaterial(bodyMat)
    bodyModel.castShadows = true

    -- 头部
    local headNode = State.playerNode:CreateChild("Head")
    headNode.position = Vector3(0, 2.0, 0)
    headNode.scale = Vector3(0.5, 0.5, 0.5)
    local headModel = headNode:CreateComponent("StaticModel")
    headModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    local headMat = Material:new()
    headMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    headMat:SetShaderParameter("MatDiffColor", Variant(Color(0.9, 0.7, 0.5, 1.0)))
    headMat:SetShaderParameter("Metallic", Variant(0.0))
    headMat:SetShaderParameter("Roughness", Variant(0.7))
    headModel:SetMaterial(headMat)
    headModel.castShadows = true

    -- 双腿
    Player.CreateLeg("LeftLeg", Vector3(-0.15, 0, 0))
    Player.CreateLeg("RightLeg", Vector3(0.15, 0, 0))
end

function Player.CreateLeg(name, offset)
    local legNode = State.playerNode:CreateChild(name)
    legNode.position = offset
    legNode.scale = Vector3(0.25, 0.8, 0.25)
    local legModel = legNode:CreateComponent("StaticModel")
    legModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    local legMat = Material:new()
    legMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    legMat:SetShaderParameter("MatDiffColor", Variant(Color(0.15, 0.15, 0.4, 1.0)))
    legMat:SetShaderParameter("Metallic", Variant(0.0))
    legMat:SetShaderParameter("Roughness", Variant(0.8))
    legModel:SetMaterial(legMat)
    legModel.castShadows = true
end

-- ============================================================================
-- 输入处理
-- ============================================================================

function Player.HandleMenuInput(dt)
    if input:GetKeyPress(KEY_SPACE) or input:GetKeyPress(KEY_RETURN) then
        Player.StartGame()
    end
end

function Player.HandlePlayingInput(dt)
    -- 虚空坠落或自动跳跃期间锁定输入
    if State.isVoidFalling then return end
    if State.autoJumpInputLock > 0 then return end

    -- 大运期间锁定变道（占满3赛道，无需切换）
    if not State.isDayunActive then
        if input:GetKeyPress(KEY_A) or input:GetKeyPress(KEY_LEFT) then
            Player.SwitchLane(-1)
        end
        if input:GetKeyPress(KEY_D) or input:GetKeyPress(KEY_RIGHT) then
            Player.SwitchLane(1)
        end
    end
    if input:GetKeyPress(KEY_SPACE) or input:GetKeyPress(KEY_UP) or input:GetKeyPress(KEY_W) then
        Player.Jump()
    end
    if input:GetKeyPress(KEY_S) or input:GetKeyPress(KEY_DOWN) or input:GetKeyPress(KEY_LSHIFT) or input:GetKeyPress(KEY_RSHIFT) then
        Player.Slide()
    end

    -- 作弊模式：Tab 键直接拉满分数和速度
    if input:GetKeyPress(KEY_TAB) then
        State.score = 50000
        State.runSpeed = 41.67  -- 150 km/h
        print("[CHEAT] Score → 50000, Speed → 150 km/h (41.67 m/s)")
    end
end

function Player.HandleGameOverInput(dt)
    if input:GetKeyPress(KEY_SPACE) or input:GetKeyPress(KEY_RETURN) then
        Player.StartGame()
    end
end

function Player.HandleTouchBegin(eventType, eventData)
    if State.gameState == Config.STATE_MENU then
        -- 检测 BGM 按钮点击
        local tx = eventData["X"]:GetInt()
        local ty = eventData["Y"]:GetInt()
        local btn = State.bgmBtnRect
        if btn then
            print(string.format("[Touch] tx=%d ty=%d | btn x=%.0f y=%.0f w=%.0f h=%.0f | physW=%d physH=%d dpr=%.1f",
                tx, ty, btn.x, btn.y, btn.w, btn.h,
                GetGraphics():GetWidth(), GetGraphics():GetHeight(), GetGraphics():GetDPR()))
        end
        if btn and tx >= btn.x and tx <= btn.x + btn.w
             and ty >= btn.y and ty <= btn.y + btn.h then
            BGM.ToggleMute()
            return
        end
        Player.StartGame()
        return
    end
    if State.gameState == Config.STATE_GAMEOVER then
        Player.StartGame()
        return
    end

    State.swipeStartX = eventData["X"]:GetInt()
    State.swipeStartY = eventData["Y"]:GetInt()
    State.isSwiping = true
end

function Player.HandleTouchMove(eventType, eventData)
    if not State.isSwiping or State.gameState ~= Config.STATE_PLAYING then return end
    -- 虚空坠落或自动跳跃期间锁定触摸输入
    if State.isVoidFalling then return end
    if State.autoJumpInputLock > 0 then return end

    local x = eventData["X"]:GetInt()
    local y = eventData["Y"]:GetInt()
    local dx = x - State.swipeStartX
    local dy = y - State.swipeStartY
    local threshold = 50

    if math.abs(dx) > threshold or math.abs(dy) > threshold then
        if math.abs(dx) > math.abs(dy) then
            -- 大运期间锁定变道
            if not State.isDayunActive then
                if dx > 0 then
                    Player.SwitchLane(1)
                else
                    Player.SwitchLane(-1)
                end
            end
        else
            if dy < 0 then
                Player.Jump()
            else
                Player.Slide()
            end
        end
        State.isSwiping = false
    end
end

function Player.HandleTouchEnd(eventType, eventData)
    State.isSwiping = false
end

-- ============================================================================
-- 动作
-- ============================================================================

function Player.SwitchLane(direction)
    local newLane = State.currentLane + direction
    if newLane >= -1 and newLane <= 1 then
        State.currentLane = newLane
        State.targetLaneX = State.currentLane * Config.LANE_WIDTH
        SFX.Play("player_lane_switch.ogg", 0.5)
    end
end

function Player.Jump()
    if not State.isJumping and not State.isSliding then
        State.isJumping = true
        State.playerVelocityY = Config.JUMP_VELOCITY
        SFX.Play("throw.ogg", 0.5)
    end
end

function Player.Slide()
    if not State.isJumping and not State.isSliding then
        State.isSliding = true
        State.slideTimer = Config.SLIDE_DURATION
        SFX.Play("player_slide.ogg", 0.5)
    end
end

-- ============================================================================
-- 开始游戏
-- ============================================================================

function Player.StartGame()
    local World = require "Game.World"

    State.gameState = Config.STATE_PLAYING
    State.currentLane = 0
    State.targetLaneX = 0.0
    State.playerVelocityY = 0.0
    State.isJumping = false
    State.isSliding = false
    State.slideTimer = 0.0
    State.runSpeed = Config.START_SPEED
    State.distanceTraveled = 0.0
    State.score = 0
    State.coins = 0
    State.heartsCollected = 0
    State.magnetsCollected = 0
    State.dayunCount = 0
    State.playerRunAngle = 0.0
    State.health = Config.MAX_HEALTH
    State.isInvincible = false
    State.invincibleTimer = 0.0
    State.hitFlashAlpha = 0

    -- 失败后重来才播放时间倒流音效
    if State.hasDied then
        SFX.Play("time_rewind.ogg")
    end
    State.hasDied = false

    -- 清除旧障碍物和金币
    State.ClearAll()
    ItemManager.ClearAll()

    -- 销毁菜单场景角色
    Player.DestroyMenuScene()

    -- 重置位置、旋转和可见性
    State.playerNode.position = Vector3(0, 0, 0)
    State.playerNode.rotation = Quaternion(0, 0, 0)
    Player.SetVisible(true)

    -- 立即重置相机到游戏跟随位置（避免从菜单位置慢慢插值过来）
    State.cameraNode.position = Vector3(0, Config.CAM_OFFSET.y, Config.CAM_OFFSET.z)
    State.cameraNode:LookAt(Vector3(0, 1.5, Config.CAM_LOOK_AHEAD))
    State.nextObstacleZ = 30.0
    State.nextCoinZ = 15.0
    ItemManager.ResetAll()

    -- 重新生成地面
    World.CreateInitialGround()

    print("Game Started! Speed: " .. State.runSpeed)
end

-- ============================================================================
-- 更新
-- ============================================================================

function Player.Update(dt)
    local World = require "Game.World"

    -- 自动跳跃输入锁定倒计时
    if State.autoJumpInputLock > 0 then
        State.autoJumpInputLock = State.autoJumpInputLock - dt
    end

    -- 峡谷自动跳跃检测
    local playerZ = State.playerNode.position.z
    if not State.isAutoJumping then
        local canyon = World.GetNextCanyon(playerZ)
        if canyon then
            local distToCanyon = canyon.startZ - playerZ
            if distToCanyon > 0 and distToCanyon < Config.CANYON_TRIGGER_OFFSET then
                -- 触发自动跳跃（即使玩家在半空中也执行飞跃）
                State.isJumping = true
                State.isAutoJumping = true
                State.playerVelocityY = Config.CANYON_JUMP_VELOCITY
                State.autoJumpInputLock = Config.CANYON_INPUT_LOCK
                -- 取消下蹲
                State.isSliding = false
                State.slideTimer = 0
                -- 强制回中间跑道
                State.currentLane = 0
                State.targetLaneX = 0
                -- ======== 场景切换时刻：清除旧场景装饰物 ========
                -- 清除障碍物（避免飞跃中碰撞）
                for _, obs in ipairs(State.obstacles) do
                    if obs.node then obs.node:Remove() end
                    if obs.extraNode then obs.extraNode:Remove() end
                end
                State.obstacles = {}
                -- 注意：不清除侧边装饰，让旧装饰自然滚动消失，保持视觉连续性
                print("[Canyon] Scene switch: cleared obstacles")

                -- ======== 峡谷飞跃视觉特效触发 ========
                State.fxFovTarget      = Config.CANYON_FX_FOV_FLIGHT  -- FOV 拉宽到 65°
                State.fxFlashTimer     = Config.CANYON_FX_FLASH_DURATION  -- 青白闪光
                State.fxFlashColor     = {180, 230, 255}
                State.fxSpeedLines     = true
                State.fxSpeedLineTargetIntensity = 1.0     -- 峡谷满强度
                State.fxSpeedLineColor = {100, 200, 255}   -- 青色速度线
                State.fxVignetteTarget = 0.4

                -- 飞跃沟壑时推进 BGM 阶段
                local newStage = 4 - math.min(State.biomeChangeCount, 3)
                BGM.SetStage(newStage)
                SFX.Play("eagle_screech.ogg", 1.5)
                print("[Canyon] Auto jump triggered! BGM stage → " .. newStage)
            end
        end
    end

    -- 自动跳跃落地后清除标记，并给予短暂无敌
    if State.isAutoJumping and not State.isJumping then
        State.isAutoJumping = false
        State.isInvincible = true
        State.invincibleTimer = 1.5

        -- ======== 峡谷飞跃特效恢复 ========
        -- 如果大运仍激活，切换为大运特效；否则恢复正常
        if State.isDayunActive then
            State.fxFovTarget      = Config.DAYUN_FX_FOV
            State.fxSpeedLineColor = {255, 120, 30}
            State.fxVignetteTarget = 0.3
        else
            State.fxFovTarget      = Config.CANYON_FX_FOV_NORMAL
            State.fxSpeedLines     = false
            State.fxVignetteTarget = 0.0
        end
    end

    local pos = State.playerNode.position

    -- 判断玩家是否在峡谷上方（无地面）
    local immune = State.isAutoJumping or State.isDayunActive
    local overCanyon = World.IsInCanyon(pos.z) and not immune

    -- 判断玩家是否在窟窿上方（按当前所在车道）
    local nearestLane = math.floor((pos.x / Config.LANE_WIDTH) + 0.5)
    nearestLane = math.max(-1, math.min(1, nearestLane))
    local overHole = World.IsOverHole(pos.z, nearestLane) and not immune

    -- 合并：无地面 = 峡谷 或 窟窿
    local overVoid = overCanyon or overHole

    -- 虚空坠落中：只做坠落物理和翻滚动画，不做其他逻辑
    if State.isVoidFalling then
        -- 坠落瞬间播放威廉尖叫
        if State.voidFallTimer == 0 then
            SFX.Play("wilhelm_scream.ogg")
        end
        State.voidFallTimer = State.voidFallTimer + dt
        -- 前进逐渐减速
        local forwardSpeed = State.runSpeed * math.max(0, 1.0 - State.voidFallTimer * 0.8)
        pos.z = pos.z + forwardSpeed * dt
        State.distanceTraveled = pos.z
        -- 重力坠落
        State.playerVelocityY = State.playerVelocityY + Config.GRAVITY * dt
        pos.y = pos.y + State.playerVelocityY * dt
        -- 翻滚动画
        State.playerNode.rotation = Quaternion(
            State.voidFallTimer * 200,
            0,
            State.voidFallTimer * 120
        )
        State.playerNode.position = pos
        Player.UpdateTrail(dt)
        -- 坠落足够深 → 死亡
        if pos.y < -20 then
            State.isVoidFalling = false
            State.voidFallTimer = 0
            State.GameOver()
        end
        return
    end

    -- 峡谷飞行时速度加成
    local speedMultiplier = State.isAutoJumping and Config.CANYON_SPEED_BOOST or 1.0
    pos.z = pos.z + State.runSpeed * speedMultiplier * dt
    State.distanceTraveled = pos.z

    local dx = State.targetLaneX - pos.x
    if math.abs(dx) > 0.05 then
        pos.x = pos.x + dx * Config.LANE_SWITCH_SPEED * dt
    else
        pos.x = State.targetLaneX
    end

    -- 虚空宽限期：停留超过 0.15 秒才坠落
    local VOID_GRACE = 0.15

    if State.isJumping then
        pos.y = pos.y + State.playerVelocityY * dt
        State.playerVelocityY = State.playerVelocityY + Config.GRAVITY * dt
        if pos.y <= 0 then
            if overVoid then
                -- 落地到虚空区域，开始/累加宽限计时
                pos.y = 0
                State.isJumping = false
                State.playerVelocityY = 0
                State.voidGraceTimer = State.voidGraceTimer + dt
                if State.voidGraceTimer >= VOID_GRACE then
                    State.isVoidFalling = true
                    State.voidFallTimer = 0
                    State.voidGraceTimer = 0
                    State.isSliding = false
                    State.slideTimer = 0
                    print("[Void] Player fell into void!")
                end
            else
                pos.y = 0
                State.isJumping = false
                State.playerVelocityY = 0
            end
        end
    elseif overVoid then
        -- 非跳跃状态走在无地面区域，累加宽限计时
        State.voidGraceTimer = State.voidGraceTimer + dt
        if State.voidGraceTimer >= VOID_GRACE then
            State.isVoidFalling = true
            State.voidFallTimer = 0
            State.voidGraceTimer = 0
            State.playerVelocityY = 0
            State.isSliding = false
            State.slideTimer = 0
            print("[Void] Player walked into void!")
        end
    end

    -- 脚下有地面时重置宽限计时
    if not overVoid then
        State.voidGraceTimer = 0
    end

    if State.isSliding then
        State.slideTimer = State.slideTimer - dt
        if State.slideTimer <= 0 then
            State.isSliding = false
        end
    end

    State.playerNode.position = pos

    -- 峡谷飞行拖尾特效
    if State.isAutoJumping then
        Player.SpawnTrail(pos)
    end
    Player.UpdateTrail(dt)

    -- 无敌状态更新
    if State.isInvincible then
        State.invincibleTimer = State.invincibleTimer - dt
        State.hitFlashAlpha = math.max(0, State.hitFlashAlpha - 200 * dt)
        if State.invincibleTimer <= 0 then
            State.isInvincible = false
            State.invincibleTimer = 0
            Player.SetVisible(true)
        else
            local visible = math.floor(State.invincibleTimer * 10) % 2 == 0
            Player.SetVisible(visible)
        end
    end

    Player.UpdateVisual(dt)
end

function Player.SetVisible(visible)
    local body = State.playerNode:GetChild("Body")
    local head = State.playerNode:GetChild("Head")
    local leftLeg = State.playerNode:GetChild("LeftLeg")
    local rightLeg = State.playerNode:GetChild("RightLeg")
    if body then body:SetEnabled(visible) end
    if head then head:SetEnabled(visible) end
    if leftLeg then leftLeg:SetEnabled(visible) end
    if rightLeg then rightLeg:SetEnabled(visible) end
end

function Player.UpdateVisual(dt)
    local bodyNode = State.playerNode:GetChild("Body")
    local headNode = State.playerNode:GetChild("Head")
    local leftLeg = State.playerNode:GetChild("LeftLeg")
    local rightLeg = State.playerNode:GetChild("RightLeg")

    if State.isSliding then
        if bodyNode then
            bodyNode.position = Vector3(0, 0.3, 0)
            bodyNode.scale = Vector3(0.6, 0.6, 0.8)
        end
        if headNode then
            headNode.position = Vector3(0, 0.8, 0.2)
            headNode.scale = Vector3(0.45, 0.45, 0.45)
        end
        if leftLeg then
            leftLeg.position = Vector3(-0.15, 0.15, 0.3)
            leftLeg.scale = Vector3(0.25, 0.3, 0.6)
        end
        if rightLeg then
            rightLeg.position = Vector3(0.15, 0.15, 0.3)
            rightLeg.scale = Vector3(0.25, 0.3, 0.6)
        end
    else
        if bodyNode then
            bodyNode.position = Vector3(0, 0.9, 0)
            bodyNode.scale = Vector3(0.6, 1.8, 0.5)
        end
        if headNode then
            headNode.position = Vector3(0, 2.0, 0)
            headNode.scale = Vector3(0.5, 0.5, 0.5)
        end

        State.playerRunAngle = State.playerRunAngle + dt * State.runSpeed * 0.8
        local legSwing = math.sin(State.playerRunAngle) * 0.3
        if leftLeg then
            leftLeg.position = Vector3(-0.15, 0.4, legSwing)
            leftLeg.scale = Vector3(0.25, 0.8, 0.25)
            leftLeg.rotation = Quaternion(-legSwing * 40, Vector3.RIGHT)
        end
        if rightLeg then
            rightLeg.position = Vector3(0.15, 0.4, -legSwing)
            rightLeg.scale = Vector3(0.25, 0.8, 0.25)
            rightLeg.rotation = Quaternion(legSwing * 40, Vector3.RIGHT)
        end
    end
end

-- ============================================================================
-- 峡谷拖尾特效（增强版：多色火焰 + 风粒子）
-- ============================================================================

local trailSpawnTimer = 0
local windSpawnTimer  = 0

-- 火焰材质缓存（避免每帧创建）
local trailMats = {}
local TRAIL_COLORS = {
    { diffuse = Color(1.0, 1.0, 1.0, 0.9),  emissive = Color(3.0, 3.0, 3.0) },    -- 白热核心
    { diffuse = Color(0.2, 0.85, 1.0, 0.8), emissive = Color(0.3, 1.5, 2.0) },    -- 青色
    { diffuse = Color(0.3, 0.4, 1.0, 0.75), emissive = Color(0.4, 0.5, 2.0) },    -- 蓝色
    { diffuse = Color(0.6, 0.2, 1.0, 0.65), emissive = Color(0.8, 0.3, 2.0) },    -- 紫色
    { diffuse = Color(0.1, 0.6, 0.9, 0.7),  emissive = Color(0.2, 1.0, 1.5) },    -- 天蓝
}

local windMat = nil  -- 风粒子材质

local function getTrailMat(idx)
    if trailMats[idx] then return trailMats[idx] end
    local c = TRAIL_COLORS[idx]
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(c.diffuse))
    mat:SetShaderParameter("MatEmissiveColor", Variant(c.emissive))
    mat:SetShaderParameter("Metallic", Variant(0.0))
    mat:SetShaderParameter("Roughness", Variant(0.15))
    trailMats[idx] = mat
    return mat
end

local function getWindMat()
    if windMat then return windMat end
    windMat = Material:new()
    windMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    windMat:SetShaderParameter("MatDiffColor", Variant(Color(1.0, 1.0, 1.0, 0.7)))
    windMat:SetShaderParameter("MatEmissiveColor", Variant(Color(2.0, 2.0, 2.0)))
    windMat:SetShaderParameter("Metallic", Variant(0.0))
    windMat:SetShaderParameter("Roughness", Variant(0.1))
    return windMat
end

function Player.SpawnTrail(playerPos)
    trailSpawnTimer = trailSpawnTimer + 1

    -- 每帧生成 2~3 个火焰粒子（比原来更密集）
    local particlesPerFrame = 2
    if trailSpawnTimer % 3 == 0 then particlesPerFrame = 3 end

    for _ = 1, particlesPerFrame do
        local colorIdx = math.random(1, #TRAIL_COLORS)
        local mat = getTrailMat(colorIdx)

        local trailNode = State.scene:CreateChild("Trail")
        local offsetX = (math.random() - 0.5) * 1.0
        local offsetY = (math.random() - 0.5) * 0.8
        trailNode.position = Vector3(
            playerPos.x + offsetX,
            playerPos.y + 0.9 + offsetY,
            playerPos.z - 0.5 - math.random() * 0.8
        )
        -- 核心粒子更大，外围粒子较小
        local size = (colorIdx == 1) and (0.35 + math.random() * 0.2) or (0.2 + math.random() * 0.2)
        trailNode.scale = Vector3(size, size, size)

        local model = trailNode:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        model:SetMaterial(mat)
        model.castShadows = false

        table.insert(State.trailNodes, {
            node = trailNode,
            life = 0,
            maxLife = 0.4 + math.random() * 0.4,
            startScale = size,
        })
    end

    -- 风粒子：每 3 帧生成 1~2 个白色小点飞过
    windSpawnTimer = windSpawnTimer + 1
    if windSpawnTimer % 3 == 0 then
        Player.SpawnWindParticle(playerPos)
        if math.random() > 0.5 then
            Player.SpawnWindParticle(playerPos)
        end
    end
end

--- 生成风粒子（白色小球从前方高速飞过）
function Player.SpawnWindParticle(playerPos)
    local node = State.scene:CreateChild("Wind")
    local s = 0.05 + math.random() * 0.06
    node.scale = Vector3(s, s, s)
    -- 在玩家前方 15~25 米随机位置生成
    node.position = Vector3(
        playerPos.x + (math.random() - 0.5) * 10.0,
        playerPos.y + (math.random() - 0.5) * 6.0 + 2.0,
        playerPos.z + 15 + math.random() * 10
    )
    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    model:SetMaterial(getWindMat())
    model.castShadows = false

    table.insert(State.fxWindParticles, {
        node = node,
        life = 0,
        maxLife = 0.3 + math.random() * 0.25,
        startScale = s,
    })
end

function Player.UpdateTrail(dt)
    local toRemove = {}
    for i, trail in ipairs(State.trailNodes) do
        trail.life = trail.life + dt
        if trail.life >= trail.maxLife then
            table.insert(toRemove, i)
        else
            -- 逐渐缩小并变透明
            local t = trail.life / trail.maxLife  -- 0→1
            local s = trail.startScale * (1.0 - t)
            if s < 0.01 then s = 0.01 end
            trail.node.scale = Vector3(s, s, s)
        end
    end
    -- 清理过期拖尾
    for i = #toRemove, 1, -1 do
        local idx = toRemove[i]
        local trail = State.trailNodes[idx]
        if trail.node then trail.node:Remove() end
        table.remove(State.trailNodes, idx)
    end

    -- 更新风粒子（白色小球从前方飞过，快速消失）
    local windRemove = {}
    for i, wp in ipairs(State.fxWindParticles) do
        wp.life = wp.life + dt
        if wp.life >= wp.maxLife or not wp.node then
            table.insert(windRemove, i)
        else
            local t = wp.life / wp.maxLife
            local s = wp.startScale * (1.0 - t * t)  -- 加速缩小
            if s < 0.005 then s = 0.005 end
            wp.node.scale = Vector3(s, s, s)
        end
    end
    for i = #windRemove, 1, -1 do
        local idx = windRemove[i]
        local wp = State.fxWindParticles[idx]
        if wp.node then wp.node:Remove() end
        table.remove(State.fxWindParticles, idx)
    end
end

-- ============================================================================
-- 碰撞检测
-- ============================================================================

function Player.CheckCollision(obs)
    local playerX = State.playerNode.position.x
    local playerY = State.playerNode.position.y

    if obs.obsType == Config.OBS_BLOCK then
        local inLane1 = math.abs(playerX - obs.lane * Config.LANE_WIDTH) < 1.0
        local inLane2 = obs.lane2 and math.abs(playerX - obs.lane2 * Config.LANE_WIDTH) < 1.0
        if (inLane1 or inLane2) and playerY < 1.2 then
            return true
        end
    elseif obs.obsType == Config.OBS_LOW_BAR then
        -- 单轨道冰刺（biome 2）：先检查是否在同一轨道
        if obs.biome == 2 then
            if math.abs(playerX - obs.lane * Config.LANE_WIDTH) < 1.0 and playerY < 0.8 then
                return true
            end
            return false
        end
        -- 跨轨道横杆：在空轨道可躲避
        if obs.openLane and math.abs(playerX - obs.openLane * Config.LANE_WIDTH) < Config.LANE_WIDTH * 0.6 then
            return false
        end
        if playerY < 0.8 then
            return true
        end
    elseif obs.obsType == Config.OBS_HIGH_BAR then
        if obs.openLane and math.abs(playerX - obs.openLane * Config.LANE_WIDTH) < Config.LANE_WIDTH * 0.6 then
            return false
        end
        if not State.isSliding and playerY < 0.3 then
            return true
        end
    elseif obs.obsType == Config.OBS_OVERHEAD then
        if obs.openLane and math.abs(playerX - obs.openLane * Config.LANE_WIDTH) < Config.LANE_WIDTH * 0.6 then
            return false
        end
        if not State.isSliding then
            return true
        end
    elseif obs.obsType == Config.OBS_ICEBERG then
        -- 冰山墙：单轨道阻挡，无法跳跃或滑铲通过，只能换轨道
        if math.abs(playerX - obs.lane * Config.LANE_WIDTH) < 1.0 then
            return true
        end
    end

    return false
end

-- ============================================================================
-- 菜单动画：企鹅趴地 + 大蓝象踩背
-- ============================================================================

local menuPenguinNode = nil
local menuElephantNode = nil
local menuBearNodes = {}
local menuSceneCreated = false

local function CreateMenuBillboard(name, texPath, aspect, height)
    local node = State.scene:CreateChild(name)
    local width = height * aspect

    local bbSet = node:CreateComponent("BillboardSet")
    bbSet.numBillboards = 1
    bbSet.sorted = true
    bbSet.faceCameraMode = FC_ROTATE_Y
    bbSet.castShadows = true

    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/DiffAlpha.xml"))
    mat:SetTexture(0, cache:GetResource("Texture2D", texPath))
    mat:SetShaderParameter("MatDiffColor", Variant(Color(2.5, 2.5, 2.5, 1.0)))
    bbSet:SetMaterial(mat)

    local bb = bbSet:GetBillboard(0)
    bb.position = Vector3(0, 0, 0)
    bb.size = Vector2(width * 0.5, height * 0.5)
    bb.enabled = true
    bbSet:Commit()

    return node
end

function Player.CreateMenuScene()
    if menuSceneCreated then return end
    menuSceneCreated = true

    -- 企鹅：趴在地上（缩小，低位置模拟趴姿）
    menuPenguinNode = CreateMenuBillboard(
        "MenuPenguin", "image/gugugaga.png", 366 / 671, 1.8)
    menuPenguinNode.position = Vector3(0.3, 0.9, 2.0)
    -- 企鹅缩矮模拟趴下（Y 方向压缩）
    menuPenguinNode.scale = Vector3(1.0, 0.55, 1.0)

    -- 大蓝象：在企鹅上方
    menuElephantNode = CreateMenuBillboard(
        "MenuElephant", "image/elephant.png", 798 / 1112, 2.8)
    menuElephantNode.position = Vector3(0.3, 3.0, 2.0)

    -- 一堆熊大围观（半圆形排列，面朝中心看热闹）
    menuBearNodes = {}
    local bearCount = 7
    local centerX, centerZ = 0.3, 2.0  -- 企鹅/大象的中心位置
    local radius = 4.5                 -- 围观半径
    local startAngle = math.rad(-100)  -- 从左后方
    local endAngle   = math.rad(100)   -- 到右后方

    for i = 1, bearCount do
        local frac = (i - 1) / (bearCount - 1)  -- 0 ~ 1
        local angle = startAngle + frac * (endAngle - startAngle)

        -- 随机化：大小、距离、高度略有不同，更自然
        local rndRadius = radius + (math.random() - 0.5) * 1.5
        local rndHeight = 1.6 + math.random() * 0.6  -- 高度 1.6 ~ 2.2
        local rndScale  = 0.7 + math.random() * 0.5  -- 大小 0.7 ~ 1.2

        local bx = centerX + math.sin(angle) * rndRadius
        local bz = centerZ + math.cos(angle) * rndRadius

        local bearNode = CreateMenuBillboard(
            "MenuBear" .. i, "image/bear.png", 538 / 972, rndHeight)
        bearNode.position = Vector3(bx, rndHeight * 0.5, bz)
        bearNode.scale = Vector3(rndScale, rndScale, rndScale)

        table.insert(menuBearNodes, {
            node = bearNode,
            baseX = bx,
            baseY = rndHeight * 0.5,
            baseZ = bz,
            baseScale = rndScale,
            phase = math.random() * math.pi * 2,  -- 随机动画相位
            speed = 1.5 + math.random() * 1.5,    -- 随机动画速度
        })
    end
end

function Player.DestroyMenuScene()
    if menuPenguinNode then menuPenguinNode:Remove() menuPenguinNode = nil end
    if menuElephantNode then menuElephantNode:Remove() menuElephantNode = nil end
    for _, bear in ipairs(menuBearNodes) do
        if bear.node then bear.node:Remove() end
    end
    menuBearNodes = {}
    menuSceneCreated = false
end

function Player.UpdateMenuAnimation(dt)
    -- 如果 HandleMenuInput 已经切换了状态（按空格开始游戏），跳过菜单动画
    if State.gameState ~= Config.STATE_MENU then return end

    local t = GetTime():GetElapsedTime()

    -- 隐藏跑步小人
    if State.playerNode then
        Player.SetVisible(false)
        State.playerNode.position = Vector3(0, -100, 0)
    end

    -- 创建菜单场景角色（只创建一次）
    Player.CreateMenuScene()

    if menuPenguinNode and menuElephantNode then
        -- 企鹅：趴在地上，轻微呼吸起伏
        local breathe = math.sin(t * 2.0) * 0.02
        menuPenguinNode.position = Vector3(0.3, 0.9 + breathe, 2.0)

        -- 大蓝象：一跳一跳踩在企鹅背上
        -- 弹跳曲线：用 abs(sin) 做弹跳，到底部时快速回弹
        local jumpFreq = 3.0  -- 跳跃频率
        local jumpPhase = t * jumpFreq
        local rawBounce = math.abs(math.sin(jumpPhase))
        -- 用幂次让底部停留时间短、顶部停留时间更长，更有趣
        local bounce = rawBounce * rawBounce
        local jumpHeight = 1.2  -- 最大弹跳高度
        local elephantBaseY = 1.8  -- 基础 Y（企鹅背上方）
        local elephantY = elephantBaseY + bounce * jumpHeight

        menuElephantNode.position = Vector3(0.3, elephantY, 2.0)

        -- 大象着地时企鹅被狠狠压扁
        local landingForce = (1.0 - rawBounce)  -- 0=空中, 1=着地
        local squishY = 0.55 * (1.0 - landingForce * 0.45)  -- 着地时压到原高的55%
        local squishX = 1.0 + landingForce * 2.5  -- 横向膨胀250%
        menuPenguinNode.scale = Vector3(squishX, squishY, 1.0 + landingForce * 0.3)

        -- 大象着地时自身也有挤压拉伸
        local elephantSquish = 1.0 + landingForce * 0.15
        local elephantStretch = 1.0 - landingForce * 0.10
        menuElephantNode.scale = Vector3(elephantSquish, elephantStretch, 1.0)

        -- 熊大围观动画：随机跳跃、摇晃，大象落地时一起震
        for _, bear in ipairs(menuBearNodes) do
            if bear.node then
                local bs = bear.baseScale
                -- 每只熊有自己的节奏：随机呼吸 + 小跳
                local bearBounce = math.abs(math.sin(t * bear.speed + bear.phase)) * 0.15
                -- 大象落地时所有熊一起被震一下
                local shockY = landingForce * 0.12
                bear.node.position = Vector3(
                    bear.baseX,
                    bear.baseY + bearBounce + shockY,
                    bear.baseZ)

                -- 左右摇晃 + 落地时挤压
                local sway = 1.0 + math.sin(t * bear.speed + bear.phase) * 0.06
                bear.node.scale = Vector3(
                    bs * sway,
                    bs * (1.0 + landingForce * 0.08),
                    bs)
            end
        end
    end

    -- 相机：环绕运动，对准大蓝象
    local orbitAngle = t * 0.25
    local orbitRadius = 7.0 + math.sin(t * 0.4) * 0.8
    local camHeight = 3.0 + math.sin(t * 0.35) * 0.4
    local camX = math.sin(orbitAngle) * orbitRadius * 0.25
    local camZ = -orbitRadius + math.cos(orbitAngle) * 0.5

    State.cameraNode.position = Vector3(camX, camHeight, camZ)
    local lookTarget = Vector3(0.3, 2.6, 2.0)
    local dir = lookTarget - State.cameraNode.position
    local pitch = math.deg(math.atan(dir.y, math.sqrt(dir.x * dir.x + dir.z * dir.z)))
    local yaw = math.deg(math.atan(dir.x, dir.z))
    State.cameraNode.rotation = Quaternion(pitch, yaw, 0)
end

return Player
