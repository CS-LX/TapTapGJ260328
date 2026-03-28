-- ============================================================================
-- Game/World.lua — 场景创建、地面、障碍物、金币生成与更新
-- ============================================================================

local Config = require "Game.Config"
local State  = require "Game.State"

local World = {}

-- ============================================================================
-- 场景创建
-- ============================================================================

function World.CreateScene()
    State.scene = Scene()
    State.scene:CreateComponent("Octree")
    State.scene:CreateComponent("DebugRenderer")

    -- 光照环境
    local lightGroupFile = cache:GetResource("XMLFile", "LightGroup/Daytime.xml")
    local lightGroup = State.scene:CreateChild("LightGroup")
    lightGroup:LoadXML(lightGroupFile:GetRoot())

    -- 相机
    State.cameraNode = State.scene:CreateChild("Camera")
    State.cameraNode.position = Vector3(0, 8, -12)
    local camera = State.cameraNode:CreateComponent("Camera")
    camera.nearClip = 0.1
    camera.farClip = 300.0
    camera.fov = 60.0

    local viewport = Viewport:new(State.scene, camera)
    renderer:SetViewport(0, viewport)
    renderer.hdrRendering = true

    -- 天空色调
    local zoneNode = State.scene:CreateChild("Zone")
    local zone = zoneNode:CreateComponent("Zone")
    zone.boundingBox = BoundingBox(Vector3(-1000, -1000, -1000), Vector3(1000, 1000, 1000))
    zone.fogColor = Color(0.6, 0.75, 0.95)
    zone.fogStart = 80.0
    zone.fogEnd = 200.0
end

-- ============================================================================
-- 地面
-- ============================================================================

function World.CreateGroundSegment(zPos)
    local node = State.scene:CreateChild("Ground")
    node.position = Vector3(0, -0.25, zPos)
    node.scale = Vector3(Config.TRACK_WIDTH, 0.5, Config.TRACK_LENGTH)
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
        local lineNode = State.scene:CreateChild("LaneLine")
        lineNode.position = Vector3(i * Config.LANE_WIDTH, 0.01, zPos)
        lineNode.scale = Vector3(0.08, 0.01, Config.TRACK_LENGTH)
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
        local wallNode = State.scene:CreateChild("Wall")
        wallNode.position = Vector3(side * (Config.TRACK_WIDTH / 2 + 0.25), 1.5, zPos)
        wallNode.scale = Vector3(0.5, 3.0, Config.TRACK_LENGTH)
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

    table.insert(State.groundSegments, { node = node, z = zPos })
    return node
end

function World.CreateInitialGround()
    for i = 0, 2 do
        World.CreateGroundSegment(i * Config.TRACK_LENGTH)
    end
end

-- ============================================================================
-- 障碍物生成
-- ============================================================================

function World.SpawnObstacle(zPos)
    local obsType = math.random(1, 3)
    local lane = math.random(-1, 1)

    local node = State.scene:CreateChild("Obstacle")
    local obs = { node = node, z = zPos, obsType = obsType, lane = lane }

    if obsType == Config.OBS_BLOCK then
        obs.damage = 1
        node.position = Vector3(lane * Config.LANE_WIDTH, 0.6, zPos)
        node.scale = Vector3(1.8, 1.2, 0.8)
        local model = node:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        model:SetMaterial(Config.CreatePBRMaterial(Color(0.85, 0.2, 0.15, 1.0), 0.3, 0.4))
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
            local node2 = State.scene:CreateChild("Obstacle2")
            node2.position = Vector3(lane2 * Config.LANE_WIDTH, 0.6, zPos)
            node2.scale = Vector3(1.8, 1.2, 0.8)
            local model2 = node2:CreateComponent("StaticModel")
            model2:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
            model2:SetMaterial(Config.CreatePBRMaterial(Color(0.85, 0.2, 0.15, 1.0), 0.3, 0.4))
            model2.castShadows = true
            obs.extraNode = node2
            obs.lane2 = lane2
        end

    elseif obsType == Config.OBS_LOW_BAR then
        obs.damage = 2
        node.position = Vector3(0, 0.4, zPos)
        node.scale = Vector3(Config.TRACK_WIDTH * 0.8, 0.8, 0.3)
        local model = node:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        model:SetMaterial(Config.CreatePBRMaterial(Color(0.9, 0.6, 0.1, 1.0), 0.5, 0.3))
        model.castShadows = true
        obs.lane = -99

    elseif obsType == Config.OBS_HIGH_BAR then
        obs.damage = 3
        node.position = Vector3(0, 1.3, zPos)
        node.scale = Vector3(Config.TRACK_WIDTH * 0.8, 0.5, 0.3)
        local model = node:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        model:SetMaterial(Config.CreatePBRMaterial(Color(0.2, 0.7, 0.3, 1.0), 0.2, 0.5))
        model.castShadows = true

        -- 支撑柱
        for side = -1, 1, 2 do
            local pillar = node:CreateChild("Pillar")
            local parentScaleX = Config.TRACK_WIDTH * 0.8
            local parentScaleY = 0.5
            pillar.position = Vector3(side * 0.45, -1.3 / parentScaleY, 0)
            pillar.scale = Vector3(0.1 / parentScaleX, 2.6 / parentScaleY, 0.1 / 0.3)
            local pillarModel = pillar:CreateComponent("StaticModel")
            pillarModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
            pillarModel:SetMaterial(Config.CreatePBRMaterial(Color(0.5, 0.5, 0.5, 1.0), 0.8, 0.3))
            pillarModel.castShadows = true
        end
        obs.lane = -99
    end

    table.insert(State.obstacles, obs)
end

-- ============================================================================
-- 金币生成
-- ============================================================================

function World.SpawnCoins(zPos)
    local lane = math.random(-1, 1)
    local coinCount = math.random(3, 6)

    for i = 1, coinCount do
        local coinNode = State.scene:CreateChild("Coin")
        coinNode.position = Vector3(
            lane * Config.LANE_WIDTH,
            Config.COIN_HEIGHT,
            zPos + (i - 1) * 2.0
        )
        coinNode.scale = Vector3(0.5, 0.5, 0.5)
        local coinModel = coinNode:CreateComponent("StaticModel")
        coinModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))

        local coinMat = Material:new()
        coinMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
        coinMat:SetShaderParameter("MatDiffColor", Variant(Color(1.0, 0.8, 0.15, 1.0)))
        coinMat:SetShaderParameter("Metallic", Variant(1.0))
        coinMat:SetShaderParameter("Roughness", Variant(0.08))
        coinMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.4, 0.3, 0.0)))
        coinModel:SetMaterial(coinMat)
        coinModel.castShadows = false

        table.insert(State.coinNodes, {
            node = coinNode,
            z = zPos + (i - 1) * 2.0,
            lane = lane,
            collected = false,
        })
    end
end

-- ============================================================================
-- 心心道具生成
-- ============================================================================

function World.SpawnHeart(zPos)
    local lane = math.random(-1, 1)

    local heartNode = State.scene:CreateChild("Heart")
    heartNode.position = Vector3(
        lane * Config.LANE_WIDTH,
        Config.HEART_HEIGHT,
        zPos
    )
    heartNode.scale = Vector3(0.45, 0.45, 0.45)

    local heartModel = heartNode:CreateComponent("StaticModel")
    heartModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))

    -- 红色发光材质
    local heartMat = Material:new()
    heartMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    heartMat:SetShaderParameter("MatDiffColor", Variant(Color(0.9, 0.1, 0.15, 1.0)))
    heartMat:SetShaderParameter("Metallic", Variant(0.3))
    heartMat:SetShaderParameter("Roughness", Variant(0.4))
    heartMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.6, 0.05, 0.08)))
    heartModel:SetMaterial(heartMat)
    heartModel.castShadows = false

    table.insert(State.heartNodes, {
        node = heartNode,
        z = zPos,
        lane = lane,
        collected = false,
    })
end

-- ============================================================================
-- 心心道具更新
-- ============================================================================

function World.UpdateHearts(dt)
    local playerZ = State.playerNode.position.z
    local playerX = State.playerNode.position.x

    -- 生成新心心（仅在血量未满时才生成）
    while State.nextHeartZ < playerZ + Config.SPAWN_DISTANCE do
        if State.health < Config.MAX_HEALTH then
            World.SpawnHeart(State.nextHeartZ)
        end
        State.nextHeartZ = State.nextHeartZ + Config.HEART_INTERVAL + math.random() * 20
    end

    local toRemove = {}
    for i, heart in ipairs(State.heartNodes) do
        if heart.node and not heart.collected then
            if heart.collecting then
                -- 收集动画
                heart.collectTimer = heart.collectTimer + dt
                local t = heart.collectTimer / 0.5

                if t >= 1.0 then
                    heart.collected = true
                    heart.node:Remove()
                    heart.node = nil
                else
                    local pos = heart.node.position
                    pos.y = heart.collectOriginY + t * 3.0
                    heart.node.position = pos

                    -- 膨胀后消失
                    local s
                    if t < 0.3 then
                        s = 0.45 * (1.0 + t / 0.3 * 1.0)
                    else
                        s = 0.9 * (1.0 - (t - 0.3) / 0.7)
                    end
                    heart.node.scale = Vector3(s, s, s)

                    heart.node:Rotate(Quaternion(0, 540 * dt, 0))
                end
            else
                -- 上下浮动 + 旋转
                local baseY = Config.HEART_HEIGHT
                local floatOffset = math.sin(GetTime():GetElapsedTime() * 3.0 + heart.z) * 0.2
                local pos = heart.node.position
                pos.y = baseY + floatOffset
                heart.node.position = pos
                heart.node:Rotate(Quaternion(0, 90 * dt, 0))

                -- 碰撞检测
                local heartPos = heart.node.position
                local dz = math.abs(heartPos.z - playerZ)
                local dx = math.abs(heartPos.x - playerX)
                if dz < 1.0 and dx < 1.0 then
                    -- 只在血量未满时才收集
                    if State.health < Config.MAX_HEALTH then
                        heart.collecting = true
                        heart.collectTimer = 0.0
                        heart.collectOriginY = heartPos.y
                        State.health = math.min(State.health + 1, Config.MAX_HEALTH)

                        -- 回血弹出文字
                        table.insert(State.scorePopups, {
                            worldPos = Vector3(heartPos.x, heartPos.y, heartPos.z),
                            baseY = heartPos.y + 0.5,
                            timer = 0,
                            duration = 0.8,
                            text = "+❤️",
                        })
                    end
                end

                if heartPos.z < playerZ - Config.DESPAWN_DISTANCE then
                    table.insert(toRemove, i)
                end
            end
        elseif heart.collected then
            table.insert(toRemove, i)
        end
    end

    for i = #toRemove, 1, -1 do
        local idx = toRemove[i]
        local heart = State.heartNodes[idx]
        if heart.node then heart.node:Remove() end
        table.remove(State.heartNodes, idx)
    end
end

-- ============================================================================
-- 障碍物更新
-- ============================================================================

function World.UpdateObstacles(dt)
    local Player = require "Game.Player"
    local playerZ = State.playerNode.position.z

    while State.nextObstacleZ < playerZ + Config.SPAWN_DISTANCE do
        World.SpawnObstacle(State.nextObstacleZ)
        State.nextObstacleZ = State.nextObstacleZ + Config.OBSTACLE_INTERVAL + math.random() * 8
    end

    local toRemove = {}
    for i, obs in ipairs(State.obstacles) do
        local obsZ = obs.z

        if obsZ < playerZ - Config.DESPAWN_DISTANCE then
            table.insert(toRemove, i)
        else
            if not obs.hit and not State.isInvincible and math.abs(obsZ - playerZ) < 0.8 then
                if Player.CheckCollision(obs) then
                    obs.hit = true
                    local damage = obs.damage or 1
                    State.health = State.health - damage
                    if State.health <= 0 then
                        State.health = 0
                        State.GameOver()
                        return
                    else
                        State.isInvincible = true
                        State.invincibleTimer = Config.INVINCIBLE_DURATION
                        State.hitFlashAlpha = 180
                    end
                end
            end
        end
    end

    for i = #toRemove, 1, -1 do
        local idx = toRemove[i]
        local obs = State.obstacles[idx]
        if obs.node then obs.node:Remove() end
        if obs.extraNode then obs.extraNode:Remove() end
        table.remove(State.obstacles, idx)
    end
end

-- ============================================================================
-- 金币更新
-- ============================================================================

function World.UpdateCoins(dt)
    local playerZ = State.playerNode.position.z
    local playerX = State.playerNode.position.x

    while State.nextCoinZ < playerZ + Config.SPAWN_DISTANCE do
        World.SpawnCoins(State.nextCoinZ)
        State.nextCoinZ = State.nextCoinZ + Config.COIN_INTERVAL + math.random() * 5
    end

    local toRemove = {}
    for i, coin in ipairs(State.coinNodes) do
        if coin.node and not coin.collected then
            if coin.collecting then
                coin.collectTimer = coin.collectTimer + dt
                local t = coin.collectTimer / 0.4

                if t >= 1.0 then
                    coin.collected = true
                    coin.node:Remove()
                    coin.node = nil
                else
                    local pos = coin.node.position
                    pos.y = coin.collectOriginY + t * 2.5
                    coin.node.position = pos

                    local s
                    if t < 0.25 then
                        s = 0.5 * (1.0 + t / 0.25 * 0.8)
                    else
                        s = 0.9 * (1.0 - (t - 0.25) / 0.75)
                    end
                    coin.node.scale = Vector3(s, s, s)

                    coin.node:Rotate(Quaternion(0, 720 * dt, 0))
                end
            else
                coin.node:Rotate(Quaternion(0, 120 * dt, 0))

                local coinPos = coin.node.position
                local dz = math.abs(coinPos.z - playerZ)
                local dx = math.abs(coinPos.x - playerX)
                if dz < 1.0 and dx < 1.0 then
                    coin.collecting = true
                    coin.collectTimer = 0.0
                    coin.collectOriginY = coinPos.y
                    State.coins = State.coins + 1
                    State.score = State.score + 50

                    table.insert(State.scorePopups, {
                        worldPos = Vector3(coinPos.x, coinPos.y, coinPos.z),
                        baseY = coinPos.y + 0.5,
                        timer = 0,
                        duration = 0.8,
                    })
                end

                if coinPos.z < playerZ - Config.DESPAWN_DISTANCE then
                    table.insert(toRemove, i)
                end
            end
        elseif coin.collected then
            table.insert(toRemove, i)
        end
    end

    for i = #toRemove, 1, -1 do
        local idx = toRemove[i]
        local coin = State.coinNodes[idx]
        if coin.node then coin.node:Remove() end
        table.remove(State.coinNodes, idx)
    end
end

-- ============================================================================
-- 地面更新
-- ============================================================================

function World.UpdateGround(dt)
    local playerZ = State.playerNode.position.z

    local lastSegZ = 0
    for _, seg in ipairs(State.groundSegments) do
        if seg.z > lastSegZ then lastSegZ = seg.z end
    end
    if playerZ + Config.TRACK_LENGTH > lastSegZ then
        World.CreateGroundSegment(lastSegZ + Config.TRACK_LENGTH)
    end

    local toRemove = {}
    for i, seg in ipairs(State.groundSegments) do
        if seg.z + Config.TRACK_LENGTH < playerZ - 50 then
            table.insert(toRemove, i)
        end
    end
    for i = #toRemove, 1, -1 do
        local idx = toRemove[i]
        local seg = State.groundSegments[idx]
        if seg.node then seg.node:Remove() end
        table.remove(State.groundSegments, idx)
    end
    local children = State.scene:GetChildren()
    for _, child in ipairs(children) do
        local name = child.name
        if (name == "LaneLine" or name == "Wall") and child.position.z < playerZ - 50 - Config.TRACK_LENGTH then
            child:Remove()
        end
    end
end

-- ============================================================================
-- 得分更新
-- ============================================================================

function World.UpdateScore(dt)
    if State.runSpeed < Config.MAX_SPEED then
        State.runSpeed = State.runSpeed + Config.SPEED_INCREASE * dt
    end
    State.score = math.floor(State.distanceTraveled) + State.coins * 50
end

function World.UpdateScorePopups(dt)
    for i = #State.scorePopups, 1, -1 do
        local popup = State.scorePopups[i]
        popup.timer = popup.timer + dt
        if popup.timer >= popup.duration then
            table.remove(State.scorePopups, i)
        end
    end
end

return World
