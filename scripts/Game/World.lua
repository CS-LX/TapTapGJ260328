-- ============================================================================
-- Game/World.lua — 场景创建、地面、障碍物、金币生成与更新
-- ============================================================================

local Config = require "Game.Config"
local State  = require "Game.State"
local Magnet = require "Game.Items.Magnet"

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
    local firstBiome = Config.BIOMES[1]
    zone.fogColor = Color(firstBiome.fog.r, firstBiome.fog.g, firstBiome.fog.b)
    zone.fogStart = 80.0
    zone.fogEnd = 200.0
    State.zoneComponent = zone
end

-- ============================================================================
-- 地面
-- ============================================================================

function World.CreateGroundSegment(zPos, biome)
    biome = biome or Config.BIOMES[1]

    local node = State.scene:CreateChild("Ground")
    node.position = Vector3(0, -0.25, zPos)
    node.scale = Vector3(Config.TRACK_WIDTH, 0.5, Config.TRACK_LENGTH)
    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))

    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(biome.ground))
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
        lineMat:SetShaderParameter("MatDiffColor", Variant(biome.lane))
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
        wallMat:SetShaderParameter("MatDiffColor", Variant(biome.wall))
        wallMat:SetShaderParameter("Metallic", Variant(0.0))
        wallMat:SetShaderParameter("Roughness", Variant(0.85))
        wallModel:SetMaterial(wallMat)
        wallModel.castShadows = true
    end

    table.insert(State.groundSegments, { node = node, z = zPos })
    return node
end

function World.CreateInitialGround()
    local biome = Config.BIOMES[State.biomeIndex]
    for i = 0, 2 do
        World.CreateGroundSegment(i * Config.TRACK_LENGTH, biome)
        State.segmentsInBiome = State.segmentsInBiome + 1
    end
end

-- ============================================================================
-- 障碍物生成
-- ============================================================================

function World.SpawnObstacle(zPos)
    local obsType = math.random(1, 4)
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

    elseif obsType == Config.OBS_LOW_BAR
        or obsType == Config.OBS_HIGH_BAR
        or obsType == Config.OBS_OVERHEAD then

        -- 栏板类障碍：50% 概率只占2轨道，留1轨道可变道躲避
        local barOffsetX = 0
        local barWidthRatio = 0.8  -- 满3轨道宽度比
        if math.random() > 0.25 then
            -- 2轨道：随机空出左或右
            local openLane = math.random(0, 1) == 0 and -1 or 1
            obs.openLane = openLane
            barOffsetX = -openLane * Config.LANE_WIDTH * 0.5
            barWidthRatio = 0.55  -- 缩窄到覆盖2轨道
        end
        obs.lane = -99

        if obsType == Config.OBS_LOW_BAR then
            obs.damage = 2
            node.position = Vector3(barOffsetX, 0.4, zPos)
            node.scale = Vector3(Config.TRACK_WIDTH * barWidthRatio, 0.8, 0.3)
            local model = node:CreateComponent("StaticModel")
            model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
            model:SetMaterial(Config.CreatePBRMaterial(Color(0.9, 0.6, 0.1, 1.0), 0.5, 0.3))
            model.castShadows = true

        elseif obsType == Config.OBS_HIGH_BAR then
            obs.damage = 3
            local barW = Config.TRACK_WIDTH * barWidthRatio
            node.position = Vector3(barOffsetX, 1.3, zPos)
            node.scale = Vector3(barW, 0.5, 0.3)
            local model = node:CreateComponent("StaticModel")
            model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
            model:SetMaterial(Config.CreatePBRMaterial(Color(0.2, 0.7, 0.3, 1.0), 0.2, 0.5))
            model.castShadows = true

            -- 支撑柱
            for side = -1, 1, 2 do
                local pillar = node:CreateChild("Pillar")
                local parentScaleY = 0.5
                pillar.position = Vector3(side * 0.45, -1.3 / parentScaleY, 0)
                pillar.scale = Vector3(0.1 / barW, 2.6 / parentScaleY, 0.1 / 0.3)
                local pillarModel = pillar:CreateComponent("StaticModel")
                pillarModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
                pillarModel:SetMaterial(Config.CreatePBRMaterial(Color(0.5, 0.5, 0.5, 1.0), 0.8, 0.3))
                pillarModel.castShadows = true
            end

        elseif obsType == Config.OBS_OVERHEAD then
            obs.damage = 2
            local barW = Config.TRACK_WIDTH * (barWidthRatio + 0.05)
            node.position = Vector3(barOffsetX, 1.6, zPos)
            node.scale = Vector3(barW, 1.4, 1.2)
            local model = node:CreateComponent("StaticModel")
            model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
            model:SetMaterial(Config.CreatePBRMaterial(Color(0.7, 0.35, 0.8, 1.0), 0.4, 0.5))
            model.castShadows = true

            -- 两侧支撑柱
            for side = -1, 1, 2 do
                local pillar = node:CreateChild("Pillar")
                local parentScaleY = 1.4
                pillar.position = Vector3(side * 0.45, -0.8 / parentScaleY, 0)
                pillar.scale = Vector3(0.15 / barW, 1.6 / parentScaleY, 0.15 / 1.2)
                local pillarModel = pillar:CreateComponent("StaticModel")
                pillarModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
                pillarModel:SetMaterial(Config.CreatePBRMaterial(Color(0.5, 0.25, 0.6, 1.0), 0.6, 0.4))
                pillarModel.castShadows = true
            end
        end
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
-- 障碍物更新
-- ============================================================================

function World.UpdateObstacles(dt)
    local Player = require "Game.Player"
    local playerZ = State.playerNode.position.z

    while State.nextObstacleZ < playerZ + Config.SPAWN_DISTANCE do
        State.nextObstacleZ = World.SkipCanyon(State.nextObstacleZ, 30)
        World.SpawnObstacle(State.nextObstacleZ)
        -- 障碍间距随速度增大：速度越快间距越大，保证反应时间
        local speedRatio = State.runSpeed / Config.START_SPEED
        State.nextObstacleZ = State.nextObstacleZ + (Config.OBSTACLE_INTERVAL + math.random() * 8) * speedRatio
    end

    local toRemove = {}
    for i, obs in ipairs(State.obstacles) do
        local obsZ = obs.z

        if obsZ < playerZ - Config.DESPAWN_DISTANCE then
            table.insert(toRemove, i)
        else
            if not obs.hit and not State.isInvincible and not State.isAutoJumping and math.abs(obsZ - playerZ) < 0.8 then
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
        State.nextCoinZ = World.SkipCanyon(State.nextCoinZ)
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

                -- 磁铁吸引效果
                if Magnet.IsActive() then
                    local coinPos = coin.node.position
                    local toPlayerX = playerX - coinPos.x
                    local toPlayerZ = playerZ - coinPos.z
                    local toPlayerY = 0.8 - coinPos.y  -- 吸向玩家身体中心
                    local dist = math.sqrt(toPlayerX * toPlayerX + toPlayerZ * toPlayerZ)
                    if dist < Magnet.RANGE and dist > 0.1 then
                        local speed = Magnet.PULL_SPEED * (1.0 - dist / Magnet.RANGE) + 5.0
                        local nx, nz = toPlayerX / dist, toPlayerZ / dist
                        coinPos.x = coinPos.x + nx * speed * dt
                        coinPos.z = coinPos.z + nz * speed * dt
                        coinPos.y = coinPos.y + toPlayerY * 3.0 * dt
                        coin.node.position = coinPos
                    end
                end

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

    -- 找到最远的地面段尾端
    local lastSegEnd = 0
    for _, seg in ipairs(State.groundSegments) do
        local segEnd = seg.z + Config.TRACK_LENGTH / 2
        if segEnd > lastSegEnd then lastSegEnd = segEnd end
    end

    -- 需要生成新段时
    while playerZ + Config.TRACK_LENGTH > lastSegEnd do
        -- 检查是否需要峡谷（当前场景段数已满）
        if State.segmentsInBiome >= Config.BIOME_SEGMENT_COUNT then
            -- 插入峡谷
            local canyonStartZ = lastSegEnd
            local canyonEndZ   = canyonStartZ + Config.CANYON_LENGTH
            local canyonData = { startZ = canyonStartZ, endZ = canyonEndZ }
            table.insert(State.canyons, canyonData)

            -- 创建跳跃板视觉标识
            World.CreateJumpPad(canyonData)

            -- 切换到下一个场景
            State.biomeIndex = (State.biomeIndex % #Config.BIOMES) + 1
            State.segmentsInBiome = 0

            -- 设置雾色渐变目标
            local nextBiome = Config.BIOMES[State.biomeIndex]
            State.fogTargetColor = Color(nextBiome.fog.r, nextBiome.fog.g, nextBiome.fog.b)

            -- 新段从峡谷后面开始
            lastSegEnd = canyonEndZ
            print("[Biome] Canyon at Z=" .. canyonStartZ .. ", switching to " .. nextBiome.name)
        end

        -- 生成新地面段
        local biome = Config.BIOMES[State.biomeIndex]
        local newSegZ = lastSegEnd + Config.TRACK_LENGTH / 2
        World.CreateGroundSegment(newSegZ, biome)
        State.segmentsInBiome = State.segmentsInBiome + 1
        lastSegEnd = newSegZ + Config.TRACK_LENGTH / 2
    end

    -- 清理过远的地面段
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

    -- 清理过远的跑道线和围墙
    local children = State.scene:GetChildren()
    for _, child in ipairs(children) do
        local name = child.name
        if (name == "LaneLine" or name == "Wall" or name == "CanyonMarker")
            and child.position.z < playerZ - 50 - Config.TRACK_LENGTH then
            child:Remove()
        end
    end

    -- 清理过远的峡谷记录（含跳跃板节点）
    for i = #State.canyons, 1, -1 do
        if State.canyons[i].endZ < playerZ - 100 then
            World.RemoveJumpPad(State.canyons[i])
            table.remove(State.canyons, i)
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

-- ============================================================================
-- 峡谷工具函数
-- ============================================================================

--- 检查某个 Z 坐标是否在峡谷内
function World.IsInCanyon(z)
    for _, canyon in ipairs(State.canyons) do
        if z >= canyon.startZ and z <= canyon.endZ then
            return true
        end
    end
    return false
end

--- 如果 z 落在峡谷（含缓冲区）内，跳过到峡谷后方；否则原样返回
--- @param z number
--- @param buffer number|nil 缓冲距离（默认5米，障碍物建议传30）
function World.SkipCanyon(z, buffer)
    buffer = buffer or 5
    for _, canyon in ipairs(State.canyons) do
        if z >= canyon.startZ - buffer and z <= canyon.endZ + buffer then
            return canyon.endZ + buffer + 5
        end
    end
    return z
end

--- 获取最近的前方峡谷信息（用于自动跳跃检测）
function World.GetNextCanyon(playerZ)
    local nearest = nil
    for _, canyon in ipairs(State.canyons) do
        if canyon.startZ > playerZ - 5 then
            if nearest == nil or canyon.startZ < nearest.startZ then
                nearest = canyon
            end
        end
    end
    return nearest
end

-- ============================================================================
-- 雾色渐变更新
-- ============================================================================

function World.UpdateFogTransition(dt)
    if State.zoneComponent == nil then return end

    local speed = 1.5  -- 渐变速度
    local cur = State.fogCurrentColor
    local tgt = State.fogTargetColor

    local dr = tgt.r - cur.r
    local dg = tgt.g - cur.g
    local db = tgt.b - cur.b

    if math.abs(dr) > 0.001 or math.abs(dg) > 0.001 or math.abs(db) > 0.001 then
        local t = math.min(speed * dt, 1.0)
        State.fogCurrentColor = Color(
            cur.r + dr * t,
            cur.g + dg * t,
            cur.b + db * t
        )
        State.zoneComponent.fogColor = State.fogCurrentColor
    end
end

-- ============================================================================
-- 峡谷跳跃板 — 发光地板 + 向上箭头 + 粒子特效
-- ============================================================================

--- 在峡谷触发点创建跳跃板视觉标识
function World.CreateJumpPad(canyon)
    local triggerZ = canyon.startZ - Config.CANYON_TRIGGER_OFFSET
    canyon.padNodes = {}
    canyon.padTriggerZ = triggerZ

    -- 共用材质：发光青色
    local glowMat = Material:new()
    glowMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    glowMat:SetShaderParameter("MatDiffColor", Variant(Color(0.0, 0.9, 1.0, 0.5)))
    glowMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.0, 1.0, 1.5)))
    glowMat:SetShaderParameter("Metallic", Variant(0.9))
    glowMat:SetShaderParameter("Roughness", Variant(0.1))

    -- 共用材质：箭头绿色
    local arrowMat = Material:new()
    arrowMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    arrowMat:SetShaderParameter("MatDiffColor", Variant(Color(0.1, 1.0, 0.4, 0.75)))
    arrowMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.0, 1.2, 0.4)))
    arrowMat:SetShaderParameter("Metallic", Variant(0.5))
    arrowMat:SetShaderParameter("Roughness", Variant(0.2))

    -- === 1. 发光主地板 ===
    local pad = State.scene:CreateChild("JumpPadFloor")
    pad.position = Vector3(0, 0.06, triggerZ)
    pad.scale = Vector3(Config.TRACK_WIDTH * 0.85, 0.08, 3.0)
    local padModel = pad:CreateComponent("StaticModel")
    padModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    padModel:SetMaterial(glowMat)
    padModel.castShadows = false
    table.insert(canyon.padNodes, { node = pad, kind = "floor" })

    -- === 2. 两条边缘光带 ===
    for side = -1, 1, 2 do
        local edge = State.scene:CreateChild("JumpPadEdge")
        edge.position = Vector3(side * Config.TRACK_WIDTH * 0.38, 0.08, triggerZ)
        edge.scale = Vector3(0.15, 0.1, 3.5)
        local em = edge:CreateComponent("StaticModel")
        em:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        em:SetMaterial(arrowMat)
        em.castShadows = false
        table.insert(canyon.padNodes, { node = edge, kind = "edge" })
    end

    -- === 3. 两侧光柱 ===
    for side = -1, 1, 2 do
        local pillar = State.scene:CreateChild("JumpPadPillar")
        pillar.position = Vector3(side * Config.TRACK_WIDTH * 0.42, 2.0, triggerZ)
        pillar.scale = Vector3(0.15, 4.0, 0.15)
        local pm = pillar:CreateComponent("StaticModel")
        pm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        pm:SetMaterial(glowMat)
        pm.castShadows = false
        table.insert(canyon.padNodes, { node = pillar, kind = "pillar", side = side })
    end

    -- === 4. 中央点光源 ===
    local lightNode = State.scene:CreateChild("JumpPadLight")
    lightNode.position = Vector3(0, 3.0, triggerZ)
    local light = lightNode:CreateComponent("Light")
    light.lightType = LIGHT_POINT
    light.range = 12.0
    light.color = Color(0.0, 0.9, 1.0)
    light.brightness = 3.0
    light.castShadows = false
    table.insert(canyon.padNodes, { node = lightNode, kind = "light" })

    -- === 5. 向上箭头（4 个人字形 chevron，分层堆叠） ===
    for i = 1, 4 do
        local arrowNode = State.scene:CreateChild("JumpPadArrow")
        arrowNode.position = Vector3(0, 0.6 + (i - 1) * 1.1, triggerZ)

        -- 左臂 "/"
        local left = arrowNode:CreateChild("L")
        left.position = Vector3(-0.4, 0, 0)
        left.rotation = Quaternion(0, 0, -35)
        left.scale = Vector3(0.12, 0.9, 0.12)
        local lm = left:CreateComponent("StaticModel")
        lm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        lm:SetMaterial(arrowMat)
        lm.castShadows = false

        -- 右臂 "\"
        local right = arrowNode:CreateChild("R")
        right.position = Vector3(0.4, 0, 0)
        right.rotation = Quaternion(0, 0, 35)
        right.scale = Vector3(0.12, 0.9, 0.12)
        local rm = right:CreateComponent("StaticModel")
        rm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        rm:SetMaterial(arrowMat)
        rm.castShadows = false

        table.insert(canyon.padNodes, { node = arrowNode, kind = "arrow", idx = i })
    end

    -- === 6. 上升粒子（小方块不断上浮） ===
    for i = 1, 10 do
        local particle = State.scene:CreateChild("JumpPadParticle")
        local px = (math.random() - 0.5) * Config.TRACK_WIDTH * 0.7
        local py = math.random() * 4.0
        particle.position = Vector3(px, py, triggerZ + (math.random() - 0.5) * 2.0)
        local s = 0.06 + math.random() * 0.07
        particle.scale = Vector3(s, s, s)
        local pModel = particle:CreateComponent("StaticModel")
        pModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        pModel:SetMaterial(glowMat)
        pModel.castShadows = false
        table.insert(canyon.padNodes, {
            node = particle, kind = "particle",
            baseX = px,
            speed = 1.5 + math.random() * 2.5,
            phase = math.random() * 6.28,
            startScale = s,
        })
    end
end

--- 更新所有跳跃板的动效
function World.UpdateJumpPads(dt)
    local elapsed = GetTime():GetElapsedTime()

    for _, canyon in ipairs(State.canyons) do
        if not canyon.padNodes then goto continue end
        local tz = canyon.padTriggerZ

        for _, pad in ipairs(canyon.padNodes) do
            if not pad.node then goto next end

            if pad.kind == "arrow" then
                -- 箭头上下浮动（相位错开）
                local baseY = 0.6 + (pad.idx - 1) * 1.1
                local floatY = math.sin(elapsed * 3.0 + pad.idx * 0.9) * 0.35
                pad.node.position = Vector3(0, baseY + floatY, tz)

            elseif pad.kind == "light" then
                -- 光源脉冲
                local light = pad.node:GetComponent("Light")
                if light then
                    light.brightness = 2.5 + math.sin(elapsed * 4.0) * 1.5
                end

            elseif pad.kind == "pillar" then
                -- 光柱高度呼吸
                local breathe = 1.0 + math.sin(elapsed * 2.5 + pad.side) * 0.15
                pad.node.scale = Vector3(0.15, 4.0 * breathe, 0.15)

            elseif pad.kind == "particle" then
                -- 粒子上浮，到顶重置
                local pos = pad.node.position
                local y = pos.y + pad.speed * dt
                if y > 5.0 then y = 0.1 end
                -- 轻微水平摇摆
                local xOff = math.sin(elapsed * 2.0 + pad.phase) * 0.3
                pad.node.position = Vector3(pad.baseX + xOff, y, tz + math.sin(elapsed + pad.phase) * 0.4)
                -- 上升中渐大，到顶渐小
                local alpha = 1.0
                if y < 0.5 then alpha = y / 0.5
                elseif y > 4.0 then alpha = (5.0 - y) end
                local s = pad.startScale * (0.5 + alpha * 0.5)
                pad.node.scale = Vector3(s, s, s)

            elseif pad.kind == "floor" then
                -- 地板脉冲呼吸（缩放微变）
                local pulse = 1.0 + math.sin(elapsed * 3.5) * 0.06
                pad.node.scale = Vector3(Config.TRACK_WIDTH * 0.85 * pulse, 0.08, 3.0)
            end

            ::next::
        end
        ::continue::
    end
end

--- 清理峡谷跳跃板节点
function World.RemoveJumpPad(canyon)
    if not canyon.padNodes then return end
    for _, pad in ipairs(canyon.padNodes) do
        if pad.node then pad.node:Remove() end
    end
    canyon.padNodes = nil
end

return World
