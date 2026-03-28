-- ============================================================================
-- Game/Player.lua — 玩家创建、移动、输入、碰撞
-- ============================================================================

local Config      = require "Game.Config"
local State       = require "Game.State"
local ItemManager = require "Game.Items.ItemManager"
local BGM         = require "Game.BGM"
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

    if input:GetKeyPress(KEY_A) or input:GetKeyPress(KEY_LEFT) then
        Player.SwitchLane(-1)
    end
    if input:GetKeyPress(KEY_D) or input:GetKeyPress(KEY_RIGHT) then
        Player.SwitchLane(1)
    end
    if input:GetKeyPress(KEY_SPACE) or input:GetKeyPress(KEY_UP) or input:GetKeyPress(KEY_W) then
        Player.Jump()
    end
    if input:GetKeyPress(KEY_S) or input:GetKeyPress(KEY_DOWN) or input:GetKeyPress(KEY_LSHIFT) or input:GetKeyPress(KEY_RSHIFT) then
        Player.Slide()
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
            if dx > 0 then
                Player.SwitchLane(1)
            else
                Player.SwitchLane(-1)
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
    end
end

function Player.Jump()
    if not State.isJumping and not State.isSliding then
        State.isJumping = true
        State.playerVelocityY = Config.JUMP_VELOCITY
    end
end

function Player.Slide()
    if not State.isJumping and not State.isSliding then
        State.isSliding = true
        State.slideTimer = Config.SLIDE_DURATION
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
    State.playerRunAngle = 0.0
    State.health = Config.MAX_HEALTH
    State.isInvincible = false
    State.invincibleTimer = 0.0
    State.hitFlashAlpha = 0

    -- 清除旧障碍物和金币
    State.ClearAll()
    ItemManager.ClearAll()

    -- 重置位置、旋转和可见性
    State.playerNode.position = Vector3(0, 0, 0)
    State.playerNode.rotation = Quaternion(0, 0, 0)
    Player.SetVisible(true)
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
    if not State.isAutoJumping and not State.isJumping then
        local canyon = World.GetNextCanyon(playerZ)
        if canyon then
            local distToCanyon = canyon.startZ - playerZ
            if distToCanyon > 0 and distToCanyon < Config.CANYON_TRIGGER_OFFSET then
                -- 触发自动跳跃
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
                -- 清除障碍物
                for _, obs in ipairs(State.obstacles) do
                    if obs.node then obs.node:Remove() end
                    if obs.extraNode then obs.extraNode:Remove() end
                end
                State.obstacles = {}
                -- 清除侧边装饰
                Scenery.ClearAll()
                print("[Canyon] Scene switch: cleared obstacles and scenery")

                -- 飞跃沟壑时推进 BGM 阶段
                local newStage = 4 - math.min(State.biomeChangeCount, 3)
                BGM.SetStage(newStage)
                print("[Canyon] Auto jump triggered! BGM stage → " .. newStage)
            end
        end
    end

    -- 自动跳跃落地后清除标记，并给予短暂无敌
    if State.isAutoJumping and not State.isJumping then
        State.isAutoJumping = false
        State.isInvincible = true
        State.invincibleTimer = 1.5
    end

    local pos = State.playerNode.position

    -- 判断玩家是否在峡谷上方（无地面）
    local overCanyon = World.IsInCanyon(pos.z) and not State.isAutoJumping

    -- 判断玩家是否在窟窿上方（按当前所在车道）
    local nearestLane = math.floor((pos.x / Config.LANE_WIDTH) + 0.5)
    nearestLane = math.max(-1, math.min(1, nearestLane))
    local overHole = World.IsOverHole(pos.z, nearestLane) and not State.isAutoJumping

    -- 合并：无地面 = 峡谷 或 窟窿
    local overVoid = overCanyon or overHole

    -- 虚空坠落中：只做坠落物理和翻滚动画，不做其他逻辑
    if State.isVoidFalling then
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

    if State.isJumping then
        pos.y = pos.y + State.playerVelocityY * dt
        State.playerVelocityY = State.playerVelocityY + Config.GRAVITY * dt
        if pos.y <= 0 then
            if overVoid then
                -- 无地面（峡谷或窟窿），进入虚空坠落
                State.isVoidFalling = true
                State.voidFallTimer = 0
                State.isJumping = false
                State.isSliding = false
                State.slideTimer = 0
                -- 保持当前下落速度继续坠落
                print("[Void] Player fell into void!")
            else
                pos.y = 0
                State.isJumping = false
                State.playerVelocityY = 0
            end
        end
    elseif overVoid then
        -- 非跳跃状态走入无地面区域（峡谷或窟窿）→ 开始坠落
        State.isVoidFalling = true
        State.voidFallTimer = 0
        State.playerVelocityY = 0
        State.isSliding = false
        State.slideTimer = 0
        print("[Void] Player walked into void!")
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
-- 峡谷拖尾特效
-- ============================================================================

local trailSpawnTimer = 0
local trailMat = nil

function Player.SpawnTrail(playerPos)
    trailSpawnTimer = trailSpawnTimer + 1
    -- 每2帧生成一个拖尾球
    if trailSpawnTimer % 2 ~= 0 then return end

    -- 懒创建拖尾材质（半透明发光蓝色）
    if not trailMat then
        trailMat = Material:new()
        trailMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
        trailMat:SetShaderParameter("MatDiffColor", Variant(Color(0.3, 0.6, 1.0, 0.8)))
        trailMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.4, 0.6, 1.0)))
        trailMat:SetShaderParameter("Metallic", Variant(0.0))
        trailMat:SetShaderParameter("Roughness", Variant(0.2))
    end

    local trailNode = State.scene:CreateChild("Trail")
    -- 在角色身后略微随机位置生成
    local offsetX = (math.random() - 0.5) * 0.6
    local offsetY = (math.random() - 0.5) * 0.4
    trailNode.position = Vector3(
        playerPos.x + offsetX,
        playerPos.y + 0.9 + offsetY,
        playerPos.z - 0.8
    )
    local size = 0.25 + math.random() * 0.15
    trailNode.scale = Vector3(size, size, size)

    local model = trailNode:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    model:SetMaterial(trailMat)
    model.castShadows = false

    table.insert(State.trailNodes, {
        node = trailNode,
        life = 0,
        maxLife = 0.5 + math.random() * 0.3,
        startScale = size,
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
        -- 2轨道时，玩家在空轨道可躲避
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
    end

    return false
end

-- ============================================================================
-- 菜单动画
-- ============================================================================

function Player.UpdateMenuAnimation(dt)
    if State.playerNode then
        State.playerNode.rotation = Quaternion(0, 0, 0)
        State.playerNode.position = Vector3(0, 0, 0)
    end
    local t = GetTime():GetElapsedTime()
    State.cameraNode.position = Vector3(
        math.sin(t * 0.3) * 2,
        5.0 + math.sin(t * 0.5) * 0.5,
        -8.0
    )
    State.cameraNode.rotation = Quaternion(25, 0, 0)
end

return Player
