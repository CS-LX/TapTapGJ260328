-- ============================================================================
-- 地铁跑酷 (Subway Surfers Style)
-- 3D 无尽跑酷游戏
-- 基于 UrhoX 3D Scene Scaffold
-- ============================================================================

require "LuaScripts/Utilities/Sample"

-- ============================================================================
-- 1. 全局变量
-- ============================================================================
---@type Scene
local scene_ = nil
---@type Node
local cameraNode_ = nil
---@type Node
local playerNode_ = nil

-- NanoVG 上下文
local nvgCtx_ = nil

-- 游戏状态
local STATE_MENU = 0
local STATE_PLAYING = 1
local STATE_GAMEOVER = 2
local gameState_ = STATE_MENU

-- 游戏配置
local CONFIG = {
    -- 跑道配置
    LANE_WIDTH = 2.5,          -- 跑道间距（米）
    LANE_COUNT = 3,            -- 跑道数量（左/中/右）
    TRACK_LENGTH = 200.0,      -- 每段地面长度
    TRACK_WIDTH = 10.0,        -- 地面宽度

    -- 玩家配置
    START_SPEED = 12.0,        -- 初始速度（米/秒）
    MAX_SPEED = 30.0,          -- 最大速度
    SPEED_INCREASE = 0.3,      -- 每秒加速
    LANE_SWITCH_SPEED = 12.0,  -- 切换跑道速度
    JUMP_VELOCITY = 10.0,      -- 跳跃初速度
    GRAVITY = -25.0,           -- 重力加速度
    SLIDE_DURATION = 0.6,      -- 下蹲持续时间
    PLAYER_HEIGHT = 1.8,       -- 玩家站立高度
    PLAYER_SLIDE_HEIGHT = 0.6, -- 下蹲高度

    -- 障碍物配置
    OBSTACLE_INTERVAL = 15.0,  -- 障碍物间隔（米）
    SPAWN_DISTANCE = 120.0,    -- 生成距离
    DESPAWN_DISTANCE = 20.0,   -- 回收距离

    -- 金币配置
    COIN_INTERVAL = 5.0,       -- 金币间隔
    COIN_HEIGHT = 1.2,         -- 金币高度
    COIN_RADIUS = 0.3,         -- 金币碰撞半径

    -- 相机配置
    CAM_OFFSET = Vector3(0, 6.0, -10.0), -- 相机偏移
    CAM_LOOK_AHEAD = 8.0,      -- 相机前瞻
}

-- 游戏运行时变量
local currentLane_ = 0         -- 当前跑道：-1(左), 0(中), 1(右)
local targetLaneX_ = 0.0       -- 目标X位置
local playerVelocityY_ = 0.0   -- 玩家Y轴速度
local isJumping_ = false       -- 是否在跳跃
local isSliding_ = false       -- 是否在下蹲
local slideTimer_ = 0.0        -- 下蹲计时器
local runSpeed_ = CONFIG.START_SPEED   -- 当前速度
local distanceTraveled_ = 0.0  -- 跑过的距离
local score_ = 0               -- 得分
local coins_ = 0               -- 金币数
local highScore_ = 0           -- 最高分

-- 障碍物和金币对象池
local obstacles_ = {}          -- 活跃障碍物列表
local coinNodes_ = {}          -- 活跃金币列表
local scorePopups_ = {}        -- 得分弹出动画
local nextObstacleZ_ = 30.0   -- 下一个障碍物Z位置
local nextCoinZ_ = 15.0       -- 下一个金币Z位置
local groundSegments_ = {}    -- 地面段

-- 动画相关
local playerRunAngle_ = 0.0   -- 跑步动画角度
local swipeStartX_ = 0        -- 滑动起始位置
local swipeStartY_ = 0
local isSwiping_ = false

-- NanoVG
local fontNormal_ = -1

-- ============================================================================
-- 2. 入口函数
-- ============================================================================

function Start()
    SampleStart()
    SampleInitMouseMode(MM_FREE)

    -- 创建 NanoVG 上下文
    nvgCtx_ = nvgCreate(1)
    if nvgCtx_ == nil then
        print("ERROR: Failed to create NanoVG context")
        return
    end

    -- 创建字体（只调用一次）
    fontNormal_ = nvgCreateFont(nvgCtx_, "sans", "Fonts/MiSans-Regular.ttf")
    if fontNormal_ == -1 then
        print("ERROR: Failed to load font")
    end

    CreateScene()
    CreatePlayer()
    CreateInitialGround()
    SubscribeToEvents()

    print("=== Subway Surfer Game Started ===")
end

function Stop()
    if nvgCtx_ ~= nil then
        nvgDelete(nvgCtx_)
        nvgCtx_ = nil
    end
end

-- ============================================================================
-- 3. 场景创建
-- ============================================================================

function CreateScene()
    scene_ = Scene()
    scene_:CreateComponent("Octree")
    scene_:CreateComponent("DebugRenderer")

    -- 光照环境
    local lightGroupFile = cache:GetResource("XMLFile", "LightGroup/Daytime.xml")
    local lightGroup = scene_:CreateChild("LightGroup")
    lightGroup:LoadXML(lightGroupFile:GetRoot())

    -- 相机
    cameraNode_ = scene_:CreateChild("Camera")
    cameraNode_.position = Vector3(0, 8, -12)
    local camera = cameraNode_:CreateComponent("Camera")
    camera.nearClip = 0.1
    camera.farClip = 300.0
    camera.fov = 60.0

    local viewport = Viewport:new(scene_, camera)
    renderer:SetViewport(0, viewport)
    renderer.hdrRendering = true

    -- 天空色调
    local zoneNode = scene_:CreateChild("Zone")
    local zone = zoneNode:CreateComponent("Zone")
    zone.boundingBox = BoundingBox(Vector3(-1000, -1000, -1000), Vector3(1000, 1000, 1000))
    zone.fogColor = Color(0.6, 0.75, 0.95)
    zone.fogStart = 80.0
    zone.fogEnd = 200.0
end

-- ============================================================================
-- 4. 玩家创建
-- ============================================================================

function CreatePlayer()
    playerNode_ = scene_:CreateChild("Player")
    playerNode_.position = Vector3(0, 0, 0)

    -- 身体（用 Box 表示玩家）
    local bodyNode = playerNode_:CreateChild("Body")
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

    -- 头部（球体）
    local headNode = playerNode_:CreateChild("Head")
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

    -- 双腿（左右腿交替动画用）
    CreateLeg(playerNode_, "LeftLeg", Vector3(-0.15, 0, 0))
    CreateLeg(playerNode_, "RightLeg", Vector3(0.15, 0, 0))
end

function CreateLeg(parentNode, name, offset)
    local legNode = parentNode:CreateChild(name)
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
-- 5. 地面创建
-- ============================================================================

function CreateGroundSegment(zPos)
    local node = scene_:CreateChild("Ground")
    node.position = Vector3(0, -0.25, zPos)
    node.scale = Vector3(CONFIG.TRACK_WIDTH, 0.5, CONFIG.TRACK_LENGTH)
    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))

    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(Color(0.35, 0.35, 0.38, 1.0)))
    mat:SetShaderParameter("Metallic", Variant(0.0))
    mat:SetShaderParameter("Roughness", Variant(0.9))
    model:SetMaterial(mat)

    -- 跑道线
    for i = -1, 1 do
        local lineNode = scene_:CreateChild("LaneLine")
        lineNode.position = Vector3(i * CONFIG.LANE_WIDTH, 0.01, zPos)
        lineNode.scale = Vector3(0.08, 0.01, CONFIG.TRACK_LENGTH)
        local lineModel = lineNode:CreateComponent("StaticModel")
        lineModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        local lineMat = Material:new()
        lineMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
        lineMat:SetShaderParameter("MatDiffColor", Variant(Color(0.9, 0.9, 0.3, 1.0)))
        lineMat:SetShaderParameter("Metallic", Variant(0.0))
        lineMat:SetShaderParameter("Roughness", Variant(0.5))
        lineModel:SetMaterial(lineMat)
    end

    -- 左右围墙
    for side = -1, 1, 2 do
        local wallNode = scene_:CreateChild("Wall")
        wallNode.position = Vector3(side * (CONFIG.TRACK_WIDTH / 2 + 0.25), 1.5, zPos)
        wallNode.scale = Vector3(0.5, 3.0, CONFIG.TRACK_LENGTH)
        local wallModel = wallNode:CreateComponent("StaticModel")
        wallModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        local wallMat = Material:new()
        wallMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
        wallMat:SetShaderParameter("MatDiffColor", Variant(Color(0.55, 0.4, 0.35, 1.0)))
        wallMat:SetShaderParameter("Metallic", Variant(0.0))
        wallMat:SetShaderParameter("Roughness", Variant(0.85))
        wallModel:SetMaterial(wallMat)
        wallModel.castShadows = true
    end

    table.insert(groundSegments_, { node = node, z = zPos })
    return node
end

function CreateInitialGround()
    for i = 0, 2 do
        CreateGroundSegment(i * CONFIG.TRACK_LENGTH)
    end
end

-- ============================================================================
-- 6. 障碍物生成
-- ============================================================================

-- 障碍物类型
local OBS_BLOCK = 1       -- 路障：需要左右躲避
local OBS_LOW_BAR = 2     -- 低横杆：需要跳跃
local OBS_HIGH_BAR = 3    -- 高横杆：需要下蹲

function CreatePBRMaterial(color, metallic, roughness)
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(color))
    mat:SetShaderParameter("Metallic", Variant(metallic or 0.0))
    mat:SetShaderParameter("Roughness", Variant(roughness or 0.5))
    return mat
end

function SpawnObstacle(zPos)
    local obsType = math.random(1, 3)
    local lane = math.random(-1, 1)

    local node = scene_:CreateChild("Obstacle")
    local obs = { node = node, z = zPos, obsType = obsType, lane = lane }

    if obsType == OBS_BLOCK then
        -- 路障：在某条跑道上放置障碍
        node.position = Vector3(lane * CONFIG.LANE_WIDTH, 0.6, zPos)
        node.scale = Vector3(1.8, 1.2, 0.8)
        local model = node:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        model:SetMaterial(CreatePBRMaterial(Color(0.85, 0.2, 0.15, 1.0), 0.3, 0.4))
        model.castShadows = true

        -- 有时候占两条道
        if math.random() > 0.6 then
            local lane2 = lane
            if lane == 0 then
                lane2 = math.random(0, 1) == 0 and -1 or 1
            elseif lane == -1 then
                lane2 = 0
            else
                lane2 = 0
            end
            local node2 = scene_:CreateChild("Obstacle2")
            node2.position = Vector3(lane2 * CONFIG.LANE_WIDTH, 0.6, zPos)
            node2.scale = Vector3(1.8, 1.2, 0.8)
            local model2 = node2:CreateComponent("StaticModel")
            model2:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
            model2:SetMaterial(CreatePBRMaterial(Color(0.85, 0.2, 0.15, 1.0), 0.3, 0.4))
            model2.castShadows = true
            obs.extraNode = node2
            obs.lane2 = lane2
        end

    elseif obsType == OBS_LOW_BAR then
        -- 低横杆：跨越整个跑道
        node.position = Vector3(0, 0.4, zPos)
        node.scale = Vector3(CONFIG.TRACK_WIDTH * 0.8, 0.8, 0.3)
        local model = node:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        model:SetMaterial(CreatePBRMaterial(Color(0.9, 0.6, 0.1, 1.0), 0.5, 0.3))
        model.castShadows = true
        obs.lane = -99  -- 特殊标记：整行

    elseif obsType == OBS_HIGH_BAR then
        -- 高横杆：需要下蹲通过
        node.position = Vector3(0, 1.3, zPos)
        node.scale = Vector3(CONFIG.TRACK_WIDTH * 0.8, 0.5, 0.3)
        local model = node:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        model:SetMaterial(CreatePBRMaterial(Color(0.2, 0.7, 0.3, 1.0), 0.2, 0.5))
        model.castShadows = true

        -- 添加支撑柱
        for side = -1, 1, 2 do
            local pillar = node:CreateChild("Pillar")
            local parentScaleX = CONFIG.TRACK_WIDTH * 0.8
            local parentScaleY = 0.5
            pillar.position = Vector3(side * 0.45, -1.3 / parentScaleY, 0)
            pillar.scale = Vector3(0.1 / parentScaleX, 2.6 / parentScaleY, 0.1 / 0.3)
            local pillarModel = pillar:CreateComponent("StaticModel")
            pillarModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
            pillarModel:SetMaterial(CreatePBRMaterial(Color(0.5, 0.5, 0.5, 1.0), 0.8, 0.3))
            pillarModel.castShadows = true
        end
        obs.lane = -99  -- 整行
    end

    table.insert(obstacles_, obs)
end

-- ============================================================================
-- 7. 金币生成
-- ============================================================================

function SpawnCoins(zPos)
    local lane = math.random(-1, 1)
    local coinCount = math.random(3, 6)

    for i = 1, coinCount do
        local coinNode = scene_:CreateChild("Coin")
        coinNode.position = Vector3(
            lane * CONFIG.LANE_WIDTH,
            CONFIG.COIN_HEIGHT,
            zPos + (i - 1) * 2.0
        )
        coinNode.scale = Vector3(0.5, 0.5, 0.5)
        local coinModel = coinNode:CreateComponent("StaticModel")
        coinModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))

        -- 金色反光材质：高金属度 + 低粗糙度 = 镜面反射
        local coinMat = Material:new()
        coinMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
        coinMat:SetShaderParameter("MatDiffColor", Variant(Color(1.0, 0.8, 0.15, 1.0)))
        coinMat:SetShaderParameter("Metallic", Variant(1.0))
        coinMat:SetShaderParameter("Roughness", Variant(0.08))
        coinMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.4, 0.3, 0.0)))
        coinModel:SetMaterial(coinMat)
        coinModel.castShadows = false

        table.insert(coinNodes_, {
            node = coinNode,
            z = zPos + (i - 1) * 2.0,
            lane = lane,
            collected = false,
        })
    end
end

-- ============================================================================
-- 8. 事件订阅
-- ============================================================================

function SubscribeToEvents()
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent(nvgCtx_, "NanoVGRender", "HandleNanoVGRender")
    SubscribeToEvent("TouchBegin", "HandleTouchBegin")
    SubscribeToEvent("TouchMove", "HandleTouchMove")
    SubscribeToEvent("TouchEnd", "HandleTouchEnd")
end

-- ============================================================================
-- 9. 主更新循环
-- ============================================================================

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    if gameState_ == STATE_MENU then
        HandleMenuInput(dt)
        UpdateMenuAnimation(dt)
    elseif gameState_ == STATE_PLAYING then
        HandlePlayingInput(dt)
        UpdatePlayer(dt)
        UpdateObstacles(dt)
        UpdateCoins(dt)
        UpdateGround(dt)
        UpdateCamera(dt)
        UpdateScore(dt)
        UpdateScorePopups(dt)
    elseif gameState_ == STATE_GAMEOVER then
        HandleGameOverInput(dt)
    end
end

-- ============================================================================
-- 10. 菜单状态
-- ============================================================================

function HandleMenuInput(dt)
    if input:GetKeyPress(KEY_SPACE) or input:GetKeyPress(KEY_RETURN) then
        StartGame()
    end
end

function UpdateMenuAnimation(dt)
    if playerNode_ then
        playerNode_.rotation = Quaternion(0, 0, 0)
        playerNode_.position = Vector3(0, 0, 0)
    end
    local t = GetTime():GetElapsedTime()
    cameraNode_.position = Vector3(
        math.sin(t * 0.3) * 2,
        5.0 + math.sin(t * 0.5) * 0.5,
        -8.0
    )
    cameraNode_.rotation = Quaternion(25, 0, 0)
end

function StartGame()
    gameState_ = STATE_PLAYING
    currentLane_ = 0
    targetLaneX_ = 0.0
    playerVelocityY_ = 0.0
    isJumping_ = false
    isSliding_ = false
    slideTimer_ = 0.0
    runSpeed_ = CONFIG.START_SPEED
    distanceTraveled_ = 0.0
    score_ = 0
    coins_ = 0
    playerRunAngle_ = 0.0

    -- 清除旧障碍物和金币
    ClearAll()

    -- 重置位置
    playerNode_.position = Vector3(0, 0, 0)
    nextObstacleZ_ = 30.0
    nextCoinZ_ = 15.0

    -- 重新生成地面
    CreateInitialGround()

    print("Game Started! Speed: " .. runSpeed_)
end

function ClearAll()
    for _, obs in ipairs(obstacles_) do
        if obs.node then obs.node:Remove() end
        if obs.extraNode then obs.extraNode:Remove() end
    end
    obstacles_ = {}

    for _, coin in ipairs(coinNodes_) do
        if coin.node then coin.node:Remove() end
    end
    coinNodes_ = {}
    scorePopups_ = {}

    for _, seg in ipairs(groundSegments_) do
        if seg.node then seg.node:Remove() end
    end
    local children = scene_:GetChildren()
    for _, child in ipairs(children) do
        local name = child.name
        if name == "LaneLine" or name == "Wall" or name == "Ground" then
            child:Remove()
        end
    end
    groundSegments_ = {}
end

-- ============================================================================
-- 11. 游戏进行中
-- ============================================================================

function HandlePlayingInput(dt)
    if input:GetKeyPress(KEY_A) or input:GetKeyPress(KEY_LEFT) then
        SwitchLane(-1)
    end
    if input:GetKeyPress(KEY_D) or input:GetKeyPress(KEY_RIGHT) then
        SwitchLane(1)
    end
    if input:GetKeyPress(KEY_SPACE) or input:GetKeyPress(KEY_UP) or input:GetKeyPress(KEY_W) then
        Jump()
    end
    if input:GetKeyPress(KEY_S) or input:GetKeyPress(KEY_DOWN) then
        Slide()
    end
end

---@param eventType string
---@param eventData TouchBeginEventData
function HandleTouchBegin(eventType, eventData)
    if gameState_ == STATE_MENU then
        StartGame()
        return
    end
    if gameState_ == STATE_GAMEOVER then
        StartGame()
        return
    end

    swipeStartX_ = eventData["X"]:GetInt()
    swipeStartY_ = eventData["Y"]:GetInt()
    isSwiping_ = true
end

---@param eventType string
---@param eventData TouchMoveEventData
function HandleTouchMove(eventType, eventData)
    if not isSwiping_ or gameState_ ~= STATE_PLAYING then return end

    local x = eventData["X"]:GetInt()
    local y = eventData["Y"]:GetInt()
    local dx = x - swipeStartX_
    local dy = y - swipeStartY_
    local threshold = 50

    if math.abs(dx) > threshold or math.abs(dy) > threshold then
        if math.abs(dx) > math.abs(dy) then
            if dx > 0 then
                SwitchLane(1)
            else
                SwitchLane(-1)
            end
        else
            if dy < 0 then
                Jump()
            else
                Slide()
            end
        end
        isSwiping_ = false
    end
end

---@param eventType string
---@param eventData TouchEndEventData
function HandleTouchEnd(eventType, eventData)
    isSwiping_ = false
end

function SwitchLane(direction)
    local newLane = currentLane_ + direction
    if newLane >= -1 and newLane <= 1 then
        currentLane_ = newLane
        targetLaneX_ = currentLane_ * CONFIG.LANE_WIDTH
    end
end

function Jump()
    if not isJumping_ and not isSliding_ then
        isJumping_ = true
        playerVelocityY_ = CONFIG.JUMP_VELOCITY
    end
end

function Slide()
    if not isJumping_ and not isSliding_ then
        isSliding_ = true
        slideTimer_ = CONFIG.SLIDE_DURATION
    end
end

-- ============================================================================
-- 12. 玩家更新
-- ============================================================================

function UpdatePlayer(dt)
    local pos = playerNode_.position

    pos.z = pos.z + runSpeed_ * dt
    distanceTraveled_ = pos.z

    local dx = targetLaneX_ - pos.x
    if math.abs(dx) > 0.05 then
        pos.x = pos.x + dx * CONFIG.LANE_SWITCH_SPEED * dt
    else
        pos.x = targetLaneX_
    end

    if isJumping_ then
        pos.y = pos.y + playerVelocityY_ * dt
        playerVelocityY_ = playerVelocityY_ + CONFIG.GRAVITY * dt
        if pos.y <= 0 then
            pos.y = 0
            isJumping_ = false
            playerVelocityY_ = 0
        end
    end

    if isSliding_ then
        slideTimer_ = slideTimer_ - dt
        if slideTimer_ <= 0 then
            isSliding_ = false
        end
    end

    playerNode_.position = pos

    UpdatePlayerVisual(dt)
end

function UpdatePlayerVisual(dt)
    local bodyNode = playerNode_:GetChild("Body")
    local headNode = playerNode_:GetChild("Head")
    local leftLeg = playerNode_:GetChild("LeftLeg")
    local rightLeg = playerNode_:GetChild("RightLeg")

    if isSliding_ then
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

        playerRunAngle_ = playerRunAngle_ + dt * runSpeed_ * 0.8
        local legSwing = math.sin(playerRunAngle_) * 0.3
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
-- 13. 障碍物/金币更新
-- ============================================================================

function UpdateObstacles(dt)
    local playerZ = playerNode_.position.z

    while nextObstacleZ_ < playerZ + CONFIG.SPAWN_DISTANCE do
        SpawnObstacle(nextObstacleZ_)
        nextObstacleZ_ = nextObstacleZ_ + CONFIG.OBSTACLE_INTERVAL + math.random() * 8
    end

    local toRemove = {}
    for i, obs in ipairs(obstacles_) do
        local obsZ = obs.z

        if obsZ < playerZ - CONFIG.DESPAWN_DISTANCE then
            table.insert(toRemove, i)
        else
            if not obs.hit and math.abs(obsZ - playerZ) < 0.8 then
                if CheckObstacleCollision(obs) then
                    obs.hit = true
                    GameOver()
                    return
                end
            end
        end
    end

    for i = #toRemove, 1, -1 do
        local idx = toRemove[i]
        local obs = obstacles_[idx]
        if obs.node then obs.node:Remove() end
        if obs.extraNode then obs.extraNode:Remove() end
        table.remove(obstacles_, idx)
    end
end

function CheckObstacleCollision(obs)
    local playerX = playerNode_.position.x
    local playerY = playerNode_.position.y

    if obs.obsType == OBS_BLOCK then
        local inLane1 = math.abs(playerX - obs.lane * CONFIG.LANE_WIDTH) < 1.0
        local inLane2 = obs.lane2 and math.abs(playerX - obs.lane2 * CONFIG.LANE_WIDTH) < 1.0
        if (inLane1 or inLane2) and playerY < 1.2 then
            return true
        end
    elseif obs.obsType == OBS_LOW_BAR then
        if playerY < 0.8 then
            return true
        end
    elseif obs.obsType == OBS_HIGH_BAR then
        if not isSliding_ and playerY < 0.3 then
            return true
        end
    end

    return false
end

function UpdateCoins(dt)
    local playerZ = playerNode_.position.z
    local playerX = playerNode_.position.x

    while nextCoinZ_ < playerZ + CONFIG.SPAWN_DISTANCE do
        SpawnCoins(nextCoinZ_)
        nextCoinZ_ = nextCoinZ_ + CONFIG.COIN_INTERVAL + math.random() * 5
    end

    local toRemove = {}
    for i, coin in ipairs(coinNodes_) do
        if coin.node and not coin.collected then
            if coin.collecting then
                -- 收集动画播放中
                coin.collectTimer = coin.collectTimer + dt
                local t = coin.collectTimer / 0.4  -- 0.4秒完成

                if t >= 1.0 then
                    -- 动画结束，移除
                    coin.collected = true
                    coin.node:Remove()
                    coin.node = nil
                else
                    -- 上升
                    local pos = coin.node.position
                    pos.y = coin.collectOriginY + t * 2.5
                    coin.node.position = pos

                    -- 缩放：先膨胀再缩小消失
                    local s
                    if t < 0.25 then
                        s = 0.5 * (1.0 + t / 0.25 * 0.8)   -- 0.5 → 0.9
                    else
                        s = 0.9 * (1.0 - (t - 0.25) / 0.75) -- 0.9 → 0
                    end
                    coin.node.scale = Vector3(s, s, s)

                    -- 快速旋转
                    coin.node:Rotate(Quaternion(0, 720 * dt, 0))
                end
            else
                -- 正常状态：慢速旋转 + 碰撞检测
                coin.node:Rotate(Quaternion(0, 120 * dt, 0))

                local coinPos = coin.node.position
                local dz = math.abs(coinPos.z - playerZ)
                local dx = math.abs(coinPos.x - playerX)
                if dz < 1.0 and dx < 1.0 then
                    -- 开始收集动画
                    coin.collecting = true
                    coin.collectTimer = 0.0
                    coin.collectOriginY = coinPos.y
                    coins_ = coins_ + 1
                    score_ = score_ + 50

                    -- 添加浮动得分文字
                    table.insert(scorePopups_, {
                        worldPos = Vector3(coinPos.x, coinPos.y, coinPos.z),
                        baseY = coinPos.y + 0.5,
                        timer = 0,
                        duration = 0.8,
                    })
                end

                if coinPos.z < playerZ - CONFIG.DESPAWN_DISTANCE then
                    table.insert(toRemove, i)
                end
            end
        elseif coin.collected then
            table.insert(toRemove, i)
        end
    end

    for i = #toRemove, 1, -1 do
        local idx = toRemove[i]
        local coin = coinNodes_[idx]
        if coin.node then coin.node:Remove() end
        table.remove(coinNodes_, idx)
    end
end

function UpdateGround(dt)
    local playerZ = playerNode_.position.z

    local lastSegZ = 0
    for _, seg in ipairs(groundSegments_) do
        if seg.z > lastSegZ then lastSegZ = seg.z end
    end
    if playerZ + CONFIG.TRACK_LENGTH > lastSegZ then
        CreateGroundSegment(lastSegZ + CONFIG.TRACK_LENGTH)
    end

    local toRemove = {}
    for i, seg in ipairs(groundSegments_) do
        if seg.z + CONFIG.TRACK_LENGTH < playerZ - 50 then
            table.insert(toRemove, i)
        end
    end
    for i = #toRemove, 1, -1 do
        local idx = toRemove[i]
        local seg = groundSegments_[idx]
        if seg.node then seg.node:Remove() end
        table.remove(groundSegments_, idx)
    end
    local children = scene_:GetChildren()
    for _, child in ipairs(children) do
        local name = child.name
        if (name == "LaneLine" or name == "Wall") and child.position.z < playerZ - 50 - CONFIG.TRACK_LENGTH then
            child:Remove()
        end
    end
end

function UpdateScore(dt)
    if runSpeed_ < CONFIG.MAX_SPEED then
        runSpeed_ = runSpeed_ + CONFIG.SPEED_INCREASE * dt
    end

    score_ = math.floor(distanceTraveled_) + coins_ * 50
end

function UpdateScorePopups(dt)
    for i = #scorePopups_, 1, -1 do
        local popup = scorePopups_[i]
        popup.timer = popup.timer + dt
        if popup.timer >= popup.duration then
            table.remove(scorePopups_, i)
        end
    end
end

-- ============================================================================
-- 14. 相机更新
-- ============================================================================

function UpdateCamera(dt)
    if not playerNode_ then return end
    local playerPos = playerNode_.position

    local targetPos = Vector3(
        playerPos.x * 0.3,
        playerPos.y + CONFIG.CAM_OFFSET.y,
        playerPos.z + CONFIG.CAM_OFFSET.z
    )

    local camPos = cameraNode_.position
    cameraNode_.position = Vector3(
        camPos.x + (targetPos.x - camPos.x) * 5.0 * dt,
        camPos.y + (targetPos.y - camPos.y) * 5.0 * dt,
        camPos.z + (targetPos.z - camPos.z) * 8.0 * dt
    )

    local lookTarget = Vector3(
        playerPos.x * 0.2,
        playerPos.y + 1.5,
        playerPos.z + CONFIG.CAM_LOOK_AHEAD
    )
    cameraNode_:LookAt(lookTarget)
end

-- ============================================================================
-- 15. 游戏结束
-- ============================================================================

function GameOver()
    gameState_ = STATE_GAMEOVER
    if score_ > highScore_ then
        highScore_ = score_
    end
    print("Game Over! Score: " .. score_ .. " | High Score: " .. highScore_)
end

function HandleGameOverInput(dt)
    if input:GetKeyPress(KEY_SPACE) or input:GetKeyPress(KEY_RETURN) then
        StartGame()
    end
end

-- ============================================================================
-- 16. NanoVG UI 渲染
-- ============================================================================

function HandleNanoVGRender(eventType, eventData)
    if nvgCtx_ == nil then return end

    local g = GetGraphics()
    local physW = g:GetWidth()
    local physH = g:GetHeight()

    nvgBeginFrame(nvgCtx_, physW, physH, 1.0)

    if gameState_ == STATE_MENU then
        DrawMenu(physW, physH)
    elseif gameState_ == STATE_PLAYING then
        DrawHUD(physW, physH)
    elseif gameState_ == STATE_GAMEOVER then
        DrawGameOver(physW, physH)
    end

    nvgEndFrame(nvgCtx_)
end

function DrawMenu(w, h)
    -- 半透明背景
    nvgBeginPath(nvgCtx_)
    nvgRect(nvgCtx_, 0, 0, w, h)
    nvgFillColor(nvgCtx_, nvgRGBA(0, 0, 0, 120))
    nvgFill(nvgCtx_)

    -- 标题
    nvgFontFace(nvgCtx_, "sans")
    nvgTextAlign(nvgCtx_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 标题阴影
    nvgFontSize(nvgCtx_, 56)
    nvgFillColor(nvgCtx_, nvgRGBA(0, 0, 0, 150))
    nvgText(nvgCtx_, w/2 + 2, h/2 - 78, "地铁跑酷")

    -- 标题
    nvgFillColor(nvgCtx_, nvgRGBA(255, 220, 50, 255))
    nvgText(nvgCtx_, w/2, h/2 - 80, "地铁跑酷")

    -- 副标题
    nvgFontSize(nvgCtx_, 18)
    nvgFillColor(nvgCtx_, nvgRGBA(255, 255, 255, 200))
    nvgText(nvgCtx_, w/2, h/2 - 30, "SUBWAY SURFERS")

    -- 开始提示（闪烁）
    local t = GetTime():GetElapsedTime()
    local alpha = math.floor(math.abs(math.sin(t * 3)) * 255)
    nvgFontSize(nvgCtx_, 24)
    nvgFillColor(nvgCtx_, nvgRGBA(255, 255, 255, alpha))
    nvgText(nvgCtx_, w/2, h/2 + 40, "点击屏幕或按空格开始")

    -- 操作说明
    nvgFontSize(nvgCtx_, 14)
    nvgFillColor(nvgCtx_, nvgRGBA(200, 200, 200, 180))
    nvgText(nvgCtx_, w/2, h/2 + 90, "← → 切换跑道  |  ↑/空格 跳跃  |  ↓ 下蹲")
    nvgText(nvgCtx_, w/2, h/2 + 115, "触屏: 左右滑动切道 | 上滑跳跃 | 下滑下蹲")

    -- 最高分
    if highScore_ > 0 then
        nvgFontSize(nvgCtx_, 18)
        nvgFillColor(nvgCtx_, nvgRGBA(255, 200, 100, 220))
        nvgText(nvgCtx_, w/2, h/2 + 150, "最高分: " .. highScore_)
    end
end

function DrawHUD(w, h)
    nvgFontFace(nvgCtx_, "sans")

    -- 顶部状态栏背景
    nvgBeginPath(nvgCtx_)
    nvgRect(nvgCtx_, 0, 0, w, 50)
    nvgFillColor(nvgCtx_, nvgRGBA(0, 0, 0, 100))
    nvgFill(nvgCtx_)

    -- 得分
    nvgTextAlign(nvgCtx_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(nvgCtx_, 24)
    nvgFillColor(nvgCtx_, nvgRGBA(255, 255, 255, 230))
    nvgText(nvgCtx_, 20, 25, "得分: " .. score_)

    -- 金币
    nvgTextAlign(nvgCtx_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(nvgCtx_, 22)
    nvgFillColor(nvgCtx_, nvgRGBA(255, 220, 50, 255))
    nvgText(nvgCtx_, w/2, 25, "🪙 " .. coins_)

    -- 速度
    nvgTextAlign(nvgCtx_, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFontSize(nvgCtx_, 18)
    nvgFillColor(nvgCtx_, nvgRGBA(200, 200, 200, 200))
    nvgText(nvgCtx_, w - 20, 25, string.format("%.0f km/h", runSpeed_ * 3.6))

    -- 距离
    nvgFontSize(nvgCtx_, 14)
    nvgFillColor(nvgCtx_, nvgRGBA(180, 180, 180, 180))
    nvgText(nvgCtx_, w - 20, 45, string.format("%.0f m", distanceTraveled_))

    -- 浮动得分弹出文字
    local camera = cameraNode_:GetComponent("Camera")
    for _, popup in ipairs(scorePopups_) do
        local t = popup.timer / popup.duration
        local worldY = popup.baseY + popup.timer * 3.0
        local worldP = Vector3(popup.worldPos.x, worldY, popup.worldPos.z)
        local sp = camera:WorldToScreenPoint(worldP)
        if sp.x >= 0 and sp.x <= 1 and sp.y >= 0 and sp.y <= 1 then
            local sx = sp.x * w
            local sy = sp.y * h

            -- 缓出透明度
            local alpha = math.floor((1.0 - t * t) * 255)
            -- 字号从大到小
            local fontSize = 26 * (1.0 - t * 0.3)

            nvgFontSize(nvgCtx_, fontSize)
            nvgTextAlign(nvgCtx_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            -- 阴影
            nvgFillColor(nvgCtx_, nvgRGBA(0, 0, 0, math.floor(alpha * 0.5)))
            nvgText(nvgCtx_, sx + 1, sy + 1, "+50")
            -- 金色文字
            nvgFillColor(nvgCtx_, nvgRGBA(255, 230, 50, alpha))
            nvgText(nvgCtx_, sx, sy, "+50")
        end
    end
end

function DrawGameOver(w, h)
    -- 半透明背景
    nvgBeginPath(nvgCtx_)
    nvgRect(nvgCtx_, 0, 0, w, h)
    nvgFillColor(nvgCtx_, nvgRGBA(0, 0, 0, 160))
    nvgFill(nvgCtx_)

    nvgFontFace(nvgCtx_, "sans")
    nvgTextAlign(nvgCtx_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- Game Over 标题
    nvgFontSize(nvgCtx_, 48)
    nvgFillColor(nvgCtx_, nvgRGBA(255, 80, 80, 255))
    nvgText(nvgCtx_, w/2, h/2 - 80, "游戏结束")

    -- 得分
    nvgFontSize(nvgCtx_, 28)
    nvgFillColor(nvgCtx_, nvgRGBA(255, 255, 255, 230))
    nvgText(nvgCtx_, w/2, h/2 - 20, "得分: " .. score_)

    -- 金币
    nvgFontSize(nvgCtx_, 22)
    nvgFillColor(nvgCtx_, nvgRGBA(255, 220, 50, 255))
    nvgText(nvgCtx_, w/2, h/2 + 20, "金币: " .. coins_)

    -- 距离
    nvgFontSize(nvgCtx_, 20)
    nvgFillColor(nvgCtx_, nvgRGBA(200, 200, 200, 200))
    nvgText(nvgCtx_, w/2, h/2 + 55, string.format("距离: %.0f 米", distanceTraveled_))

    -- 最高分
    nvgFontSize(nvgCtx_, 22)
    if score_ >= highScore_ then
        nvgFillColor(nvgCtx_, nvgRGBA(255, 200, 50, 255))
        nvgText(nvgCtx_, w/2, h/2 + 90, "★ 新纪录! ★")
    else
        nvgFillColor(nvgCtx_, nvgRGBA(180, 180, 180, 200))
        nvgText(nvgCtx_, w/2, h/2 + 90, "最高分: " .. highScore_)
    end

    -- 重新开始提示（闪烁）
    local t = GetTime():GetElapsedTime()
    local alpha = math.floor(math.abs(math.sin(t * 3)) * 255)
    nvgFontSize(nvgCtx_, 22)
    nvgFillColor(nvgCtx_, nvgRGBA(255, 255, 255, alpha))
    nvgText(nvgCtx_, w/2, h/2 + 140, "点击或按空格重新开始")
end
