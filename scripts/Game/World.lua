-- ============================================================================
-- Game/World.lua — 场景创建、地面、障碍物、金币生成与更新
-- ============================================================================

local Config    = require "Game.Config"
local State     = require "Game.State"
local SFX       = require "Game.SFX"
local Magnet    = require "Game.Items.Magnet"
local Canyon    = require "Game.World.Canyon"
local Holes     = require "Game.World.Holes"
local JumpPad   = require "Game.World.JumpPad"
local Scenery   = require "Game.World.Scenery"

local World = {}

-- 导出子模块 API（保持对外接口不变）
World.IsInCanyon    = Canyon.IsInCanyon
World.SkipCanyon    = Canyon.SkipCanyon
World.GetNextCanyon = Canyon.GetNextCanyon
World.IsOverHole    = Holes.IsOverHole
World.GetSolidLanes = Holes.GetSolidLanes

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

    -- 侧边地形条（两侧各 30m 宽）
    local SC = Config.SCENERY
    local sideW = SC.SIDE_TERRAIN_WIDTH
    local halfTrack = Config.TRACK_WIDTH / 2
    local biomeIdx = State.biomeIndex
    local biomeColors = biomeIdx == 1 and SC.SAVANNA or (biomeIdx == 2 and SC.GLACIER or SC.CLIFFS)
    local terrainColor = biomeColors.TERRAIN_COLOR

    for side = -1, 1, 2 do
        local sideX = side * (halfTrack + sideW / 2)
        local sideNode = State.scene:CreateChild("SideTerrain")
        sideNode.position = Vector3(sideX, -0.3, zPos)
        sideNode.scale = Vector3(sideW, 0.5, Config.TRACK_LENGTH)
        local sideModel = sideNode:CreateComponent("StaticModel")
        sideModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        sideModel:SetMaterial(Config.CreatePBRMaterial(terrainColor, 0.0, 0.95))

        -- biome 特有地貌
        local hillCount = SC.SIDE_TERRAIN_HILLS
        for h = 1, hillCount do
            local hz = zPos + (math.random() - 0.5) * Config.TRACK_LENGTH * 0.8
            local hx = side * (halfTrack + 2.0 + math.random() * (sideW - 4.0))

            if biomeIdx == 1 then
                -- Savanna: 圆润小丘（扁平 Sphere）
                local hillNode = State.scene:CreateChild("SideTerrain")
                local hillR = 3.0 + math.random() * 5.0
                local hillH = 0.5 + math.random() * 1.5
                hillNode.position = Vector3(hx, hillH * 0.3, hz)
                hillNode.scale = Vector3(hillR * 2, hillH, hillR * 1.5)
                local hm = hillNode:CreateComponent("StaticModel")
                hm:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
                hm:SetMaterial(Config.CreatePBRMaterial(
                    math.random() > 0.5 and biomeColors.HILL_COLOR or biomeColors.HILL_GRASS,
                    0.0, 0.92
                ))

            elseif biomeIdx == 2 then
                -- Glacier: 冰脊（薄长 Box 微倾斜）
                local ridgeNode = State.scene:CreateChild("SideTerrain")
                local rLen = 4.0 + math.random() * 8.0
                local rH = 0.3 + math.random() * 1.0
                ridgeNode.position = Vector3(hx, rH * 0.4, hz)
                ridgeNode.rotation = Quaternion(0, math.random() * 40 - 20, math.random() * 8 - 4)
                ridgeNode.scale = Vector3(1.0 + math.random() * 1.5, rH, rLen)
                local rm = ridgeNode:CreateComponent("StaticModel")
                rm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
                rm:SetMaterial(Config.CreatePBRMaterial(biomeColors.RIDGE_COLOR, 0.15, 0.2))

            else
                -- Cliffs: 起伏丘陵（大 Sphere + 岩石面 Box）
                local hillNode = State.scene:CreateChild("SideTerrain")
                local hillR = 3.0 + math.random() * 6.0
                local hillH = 1.0 + math.random() * 3.0
                hillNode.position = Vector3(hx, hillH * 0.25, hz)
                hillNode.scale = Vector3(hillR * 2, hillH, hillR * 1.8)
                local hm = hillNode:CreateComponent("StaticModel")
                hm:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
                hm:SetMaterial(Config.CreatePBRMaterial(biomeColors.HILL_COLOR, 0.0, 0.90))

                -- 丘陵上的岩石露头
                if math.random() > 0.4 then
                    local rockNode = State.scene:CreateChild("SideTerrain")
                    rockNode.position = Vector3(hx + (math.random() - 0.5) * 2, hillH * 0.6, hz + (math.random() - 0.5) * 3)
                    rockNode.rotation = Quaternion(math.random() * 20, math.random() * 360, math.random() * 15)
                    local rs = 0.8 + math.random() * 1.5
                    rockNode.scale = Vector3(rs, rs * 0.7, rs * 0.9)
                    local rrm = rockNode:CreateComponent("StaticModel")
                    rrm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
                    rrm:SetMaterial(Config.CreatePBRMaterial(biomeColors.HILL_ROCK, 0.0, 0.88))
                end
            end
        end
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

--- 给障碍物节点添加场景风格化装饰（子节点，自动随父节点删除）
local function DecorateBlock(node, biomeIdx, vis)
    local psx, psy, psz = node.scale.x, node.scale.y, node.scale.z

    if biomeIdx == 1 then
        -- Savanna: 木板顶盖 + 侧面条纹
        local plank = node:CreateChild("Decor")
        plank.position = Vector3(0, 0.5, 0)
        plank.scale = Vector3(1.05, 0.06 / psy, 1.05)
        local pm = plank:CreateComponent("StaticModel")
        pm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        pm:SetMaterial(Config.CreateObsMaterial(vis.blockAcc))
        pm.castShadows = true
        -- 侧面横条纹
        for i = -1, 1, 2 do
            local stripe = node:CreateChild("Decor")
            stripe.position = Vector3(0, i * 0.15, 0.5)
            stripe.scale = Vector3(1.02, 0.08 / psy, 0.02 / psz)
            local sm = stripe:CreateComponent("StaticModel")
            sm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
            sm:SetMaterial(Config.CreateObsMaterial(vis.blockAcc))
            sm.castShadows = false
        end

    elseif biomeIdx == 2 then
        -- Glacier: 冰锥尖角 + 顶部碎冰
        local shard = node:CreateChild("Decor")
        shard.position = Vector3(0.15, 0.5, 0.05)
        shard.rotation = Quaternion(0, 25, 12)
        shard.scale = Vector3(0.25 / psx, 0.5 / psy, 0.25 / psz)
        local shm = shard:CreateComponent("StaticModel")
        shm:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
        shm:SetMaterial(Config.CreateObsMaterial(vis.blockAcc))
        shm.castShadows = true
        -- 另一侧小冰锥
        local shard2 = node:CreateChild("Decor")
        shard2.position = Vector3(-0.2, 0.5, -0.1)
        shard2.rotation = Quaternion(0, -40, -8)
        shard2.scale = Vector3(0.18 / psx, 0.35 / psy, 0.18 / psz)
        local shm2 = shard2:CreateComponent("StaticModel")
        shm2:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
        shm2:SetMaterial(Config.CreateObsMaterial(vis.blockAcc))
        shm2.castShadows = true

    elseif biomeIdx == 3 then
        -- Cliffs: 苔藓覆盖顶面 + 小石块
        local moss = node:CreateChild("Decor")
        moss.position = Vector3(0, 0.5, 0)
        moss.scale = Vector3(1.02, 0.05 / psy, 1.02)
        local mm = moss:CreateComponent("StaticModel")
        mm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        mm:SetMaterial(Config.CreateObsMaterial(vis.blockAcc))
        mm.castShadows = false
        -- 小碎石
        local pebble = node:CreateChild("Decor")
        pebble.position = Vector3(0.3, 0.5, 0.2)
        pebble.rotation = Quaternion(15, 40, 0)
        pebble.scale = Vector3(0.15 / psx, 0.10 / psy, 0.12 / psz)
        local pbm = pebble:CreateComponent("StaticModel")
        pbm:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        pbm:SetMaterial(Config.CreatePBRMaterial(Color(0.48, 0.42, 0.35, 1.0), 0.0, 0.9))
        pbm.castShadows = false
    end
end

--- 给 overhead/高栏添加场景装饰
local function DecorateOverhead(node, biomeIdx, vis)
    local psx, psy, psz = node.scale.x, node.scale.y, node.scale.z

    if biomeIdx == 1 then
        -- Savanna: 底部草帘（前后各一排细条）
        for zSide = -1, 1, 2 do
            for j = 1, 3 do
                local straw = node:CreateChild("Decor")
                local xOff = (j - 2) * 0.25
                straw.position = Vector3(xOff, -0.5, zSide * 0.5)
                straw.scale = Vector3(0.06 / psx, 0.15 / psy, 0.02 / psz)
                local sm = straw:CreateComponent("StaticModel")
                sm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
                sm:SetMaterial(Config.CreateObsMaterial(vis.blockAcc or vis.overhead))
                sm.castShadows = false
            end
        end

    elseif biomeIdx == 2 then
        -- Glacier: 底部悬挂冰锥
        for j = 1, 4 do
            local icicle = node:CreateChild("Decor")
            local xOff = (j - 2.5) * 0.22
            icicle.position = Vector3(xOff, -0.5, (math.random() - 0.5) * 0.6)
            icicle.rotation = Quaternion(180, 0, math.random() * 10 - 5)
            local iciH = 0.15 + math.random() * 0.20
            icicle.scale = Vector3(0.05 / psx, iciH / psy, 0.05 / psz)
            local im = icicle:CreateComponent("StaticModel")
            im:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
            im:SetMaterial(Config.CreateObsMaterial(vis.blockAcc or {
                color = Color(0.65, 0.82, 0.95, 1.0), m = 0.35, r = 0.10,
                emissive = Color(0.06, 0.15, 0.30)
            }))
            im.castShadows = false
        end

    elseif biomeIdx == 3 then
        -- Cliffs: 顶部草皮 + 侧面藤蔓
        local grass = node:CreateChild("Decor")
        grass.position = Vector3(0, 0.5, 0)
        grass.scale = Vector3(1.02, 0.04 / psy, 1.02)
        local gm = grass:CreateComponent("StaticModel")
        gm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        gm:SetMaterial(Config.CreatePBRMaterial(Color(0.30, 0.52, 0.22, 1.0), 0.0, 0.85))
        gm.castShadows = false
        -- 侧面垂挂藤蔓
        for side = -1, 1, 2 do
            local vine = node:CreateChild("Decor")
            vine.position = Vector3(side * 0.48, -0.1, 0)
            vine.scale = Vector3(0.03 / psx, 0.4 / psy, 0.15 / psz)
            local vm = vine:CreateComponent("StaticModel")
            vm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
            vm:SetMaterial(Config.CreatePBRMaterial(Color(0.20, 0.42, 0.15, 1.0), 0.0, 0.88))
            vm.castShadows = false
        end
    end
end

function World.SpawnObstacle(zPos)
    local obsType = math.random(1, 4)

    local solidLanes = Holes.GetSolidLanes(zPos)
    if #solidLanes == 0 then return end

    local lane = solidLanes[math.random(1, #solidLanes)]

    local node = State.scene:CreateChild("Obstacle")
    local obs = { node = node, z = zPos, obsType = obsType, lane = lane }

    -- 获取当前场景障碍物视觉配置
    local vis = Config.OBSTACLE_VISUALS[State.biomeIndex]

    if obsType == Config.OBS_BLOCK then
        obs.damage = 1
        node.position = Vector3(lane * Config.LANE_WIDTH, 0.6, zPos)
        node.scale = Vector3(1.8, 1.2, 0.8)
        local model = node:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        model:SetMaterial(Config.CreateObsMaterial(vis.block))
        model.castShadows = true
        DecorateBlock(node, State.biomeIndex, vis)

        if math.random() > 0.6 and #solidLanes >= 2 then
            local lane2 = lane
            for _, sl in ipairs(solidLanes) do
                if sl ~= lane then
                    lane2 = sl
                    break
                end
            end
            if lane2 ~= lane then
                local node2 = State.scene:CreateChild("Obstacle2")
                node2.position = Vector3(lane2 * Config.LANE_WIDTH, 0.6, zPos)
                node2.scale = Vector3(1.8, 1.2, 0.8)
                local model2 = node2:CreateComponent("StaticModel")
                model2:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
                model2:SetMaterial(Config.CreateObsMaterial(vis.block))
                model2.castShadows = true
                DecorateBlock(node2, State.biomeIndex, vis)
                obs.extraNode = node2
                obs.lane2 = lane2
            end
        end

    elseif obsType == Config.OBS_LOW_BAR
        or obsType == Config.OBS_HIGH_BAR
        or obsType == Config.OBS_OVERHEAD then

        local solidCount = #solidLanes
        local barOffsetX = 0
        local barWidthRatio = 0.8

        if solidCount == 1 then
            barOffsetX = solidLanes[1] * Config.LANE_WIDTH
            barWidthRatio = 0.25
        elseif solidCount == 2 then
            local sumX = 0
            for _, sl in ipairs(solidLanes) do sumX = sumX + sl end
            barOffsetX = (sumX / 2) * Config.LANE_WIDTH
            barWidthRatio = 0.55
            if math.random() < 0.25 then
                local pickLane = solidLanes[math.random(1, 2)]
                barOffsetX = pickLane * Config.LANE_WIDTH
                barWidthRatio = 0.25
                for _, sl in ipairs(solidLanes) do
                    if sl ~= pickLane then obs.openLane = sl break end
                end
            end
        else
            if math.random() > 0.25 then
                local openLane = math.random(0, 1) == 0 and -1 or 1
                obs.openLane = openLane
                barOffsetX = -openLane * Config.LANE_WIDTH * 0.5
                barWidthRatio = 0.55
            end
        end
        obs.lane = -99

        if obsType == Config.OBS_LOW_BAR then
            obs.damage = 2
            node.position = Vector3(barOffsetX, 0.4, zPos)
            node.scale = Vector3(Config.TRACK_WIDTH * barWidthRatio, 0.8, 0.3)
            local model = node:CreateComponent("StaticModel")
            model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
            model:SetMaterial(Config.CreateObsMaterial(vis.lowBar))
            model.castShadows = true

        elseif obsType == Config.OBS_HIGH_BAR then
            obs.damage = 3
            local barW = Config.TRACK_WIDTH * barWidthRatio
            node.position = Vector3(barOffsetX, 1.3, zPos)
            node.scale = Vector3(barW, 0.5, 0.3)
            local model = node:CreateComponent("StaticModel")
            model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
            model:SetMaterial(Config.CreateObsMaterial(vis.highBar))
            model.castShadows = true

            for side = -1, 1, 2 do
                local pillar = node:CreateChild("Pillar")
                local parentScaleY = 0.5
                pillar.position = Vector3(side * 0.45, -1.3 / parentScaleY, 0)
                pillar.scale = Vector3(0.1 / barW, 2.6 / parentScaleY, 0.1 / 0.3)
                local pillarModel = pillar:CreateComponent("StaticModel")
                pillarModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
                pillarModel:SetMaterial(Config.CreateObsMaterial(vis.pillar))
                pillarModel.castShadows = true
            end

        elseif obsType == Config.OBS_OVERHEAD then
            obs.damage = 2
            local barW = Config.TRACK_WIDTH * (barWidthRatio + 0.05)
            node.position = Vector3(barOffsetX, 1.6, zPos)
            node.scale = Vector3(barW, 1.4, 1.2)
            local model = node:CreateComponent("StaticModel")
            model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
            model:SetMaterial(Config.CreateObsMaterial(vis.overhead))
            model.castShadows = true
            DecorateOverhead(node, State.biomeIndex, vis)

            for side = -1, 1, 2 do
                local pillar = node:CreateChild("Pillar")
                local parentScaleY = 1.4
                pillar.position = Vector3(side * 0.45, -0.8 / parentScaleY, 0)
                pillar.scale = Vector3(0.15 / barW, 1.6 / parentScaleY, 0.15 / 1.2)
                local pillarModel = pillar:CreateComponent("StaticModel")
                pillarModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
                pillarModel:SetMaterial(Config.CreateObsMaterial(vis.oPillar))
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
    local solidLanes = Holes.GetSolidLanes(zPos)
    if #solidLanes == 0 then return end
    local lane = solidLanes[math.random(1, #solidLanes)]
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
        State.nextObstacleZ = Canyon.SkipCanyon(State.nextObstacleZ, 30)
        World.SpawnObstacle(State.nextObstacleZ)
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
                        SFX.PlayRandom({
                            "laugh_private_1.ogg",
                            "laugh_private_2.ogg",
                            "laugh_private_3.ogg",
                        }, 0.9)
                        State.GameOver()
                        return
                    else
                        SFX.Play("thud.ogg", 0.7)
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
        State.nextCoinZ = Canyon.SkipCanyon(State.nextCoinZ)
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
                    local toPlayerY = 0.8 - coinPos.y
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

    local lastSegEnd = 0
    for _, seg in ipairs(State.groundSegments) do
        local segEnd = seg.z + Config.TRACK_LENGTH / 2
        if segEnd > lastSegEnd then lastSegEnd = segEnd end
    end

    while playerZ + Config.TRACK_LENGTH > lastSegEnd do
        if State.segmentsInBiome >= Config.BIOME_SEGMENT_COUNT then
            local canyonStartZ = lastSegEnd
            local canyonEndZ   = canyonStartZ + Config.CANYON_LENGTH
            local canyonData = { startZ = canyonStartZ, endZ = canyonEndZ }
            table.insert(State.canyons, canyonData)

            JumpPad.Create(canyonData)

            State.biomeIndex = (State.biomeIndex % #Config.BIOMES) + 1
            State.biomeChangeCount = State.biomeChangeCount + 1
            State.segmentsInBiome = 0

            if State.onBiomeChange then
                State.onBiomeChange(State.biomeChangeCount)
            end

            local nextBiome = Config.BIOMES[State.biomeIndex]
            State.fogTargetColor = Color(nextBiome.fog.r, nextBiome.fog.g, nextBiome.fog.b)

            lastSegEnd = canyonEndZ
            print("[Biome] Canyon at Z=" .. canyonStartZ .. ", switching to " .. nextBiome.name)
        end

        local biome = Config.BIOMES[State.biomeIndex]
        local newSegZ = lastSegEnd + Config.TRACK_LENGTH / 2
        World.CreateGroundSegment(newSegZ, biome)
        State.segmentsInBiome = State.segmentsInBiome + 1
        lastSegEnd = newSegZ + Config.TRACK_LENGTH / 2

        local segStartZ = newSegZ - Config.TRACK_LENGTH / 2
        local segEndZ   = newSegZ + Config.TRACK_LENGTH / 2
        Holes.GenerateForSegment(segStartZ, segEndZ, State.biomeIndex)
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

    -- 清理过远的跑道线、围墙、路面、路缘
    local children = State.scene:GetChildren()
    for _, child in ipairs(children) do
        local name = child.name
        if (name == "Ground" or name == "LaneLine" or name == "CanyonMarker"
            or name == "Scenery" or name == "SideTerrain")
            and child.position.z < playerZ - 50 - Config.TRACK_LENGTH then
            child:Remove()
        end
    end

    -- 清理过远的峡谷（含跳跃板）
    for i = #State.canyons, 1, -1 do
        if State.canyons[i].endZ < playerZ - 100 then
            JumpPad.Remove(State.canyons[i])
            table.remove(State.canyons, i)
        end
    end

    -- 清理过远的窟窿
    Holes.Cleanup(playerZ)
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
-- 雾色渐变更新
-- ============================================================================

function World.UpdateFogTransition(dt)
    if State.zoneComponent == nil then return end

    local speed = 1.5
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
-- 跳跃板动效更新（委托给子模块）
-- ============================================================================

World.UpdateJumpPads = JumpPad.UpdateAll

-- 导出子模块更新（供 main.lua 调用）
World.UpdateScenery = Scenery.Update

return World
