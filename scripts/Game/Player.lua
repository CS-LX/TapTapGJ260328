-- ============================================================================
-- Game/Player.lua — 玩家创建、移动、输入、碰撞
-- ============================================================================

local Config = require "Game.Config"
local State  = require "Game.State"

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

    -- 重置位置、旋转和可见性
    State.playerNode.position = Vector3(0, 0, 0)
    State.playerNode.rotation = Quaternion(0, 0, 0)
    Player.SetVisible(true)
    State.nextObstacleZ = 30.0
    State.nextCoinZ = 15.0

    -- 重新生成地面
    World.CreateInitialGround()

    print("Game Started! Speed: " .. State.runSpeed)
end

-- ============================================================================
-- 更新
-- ============================================================================

function Player.Update(dt)
    local pos = State.playerNode.position

    pos.z = pos.z + State.runSpeed * dt
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
            pos.y = 0
            State.isJumping = false
            State.playerVelocityY = 0
        end
    end

    if State.isSliding then
        State.slideTimer = State.slideTimer - dt
        if State.slideTimer <= 0 then
            State.isSliding = false
        end
    end

    State.playerNode.position = pos

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
        if playerY < 0.8 then
            return true
        end
    elseif obs.obsType == Config.OBS_HIGH_BAR then
        if not State.isSliding and playerY < 0.3 then
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
