-- ============================================================================
-- 障碍物视觉构建模块
-- 从 World.lua 的 SpawnObstacle 中提取，负责各 biome 障碍物的 3D 模型构建
-- ============================================================================

local Config = require "Game.Config"
local State  = require "Game.State"

local Obstacles = {}

-- ============================================================================
-- 共享工具
-- ============================================================================

local blockTexCache = {}  -- 贴图材质缓存

--- Billboard 贴图障碍（大蓝象 / 企鹅 / 熊大）
---@param parentNode Node
---@param vis table
---@param height number?
function Obstacles.CreateBillboardBlock(parentNode, vis, height)
    height = height or 2.5
    local aspect = vis.blockTextureAspect or 1.0
    local width  = height * aspect

    local bbSet = parentNode:CreateComponent("BillboardSet")
    bbSet.numBillboards = 1
    bbSet.sorted = true
    bbSet.faceCameraMode = FC_ROTATE_Y
    bbSet.castShadows = true

    local texPath = vis.blockTexture
    if not blockTexCache[texPath] then
        local mat = Material:new()
        mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/DiffAlpha.xml"))
        mat:SetTexture(0, cache:GetResource("Texture2D", texPath))
        mat:SetShaderParameter("MatDiffColor", Variant(Color(2.5, 2.5, 2.5, 1.0)))
        blockTexCache[texPath] = mat
    end
    bbSet:SetMaterial(blockTexCache[texPath])

    local bb = bbSet:GetBillboard(0)
    bb.position = Vector3(0, 0, 0)
    bb.size = Vector2(width * 0.5, height * 0.5)
    bb.enabled = true
    bbSet:Commit()
end

--- BLOCK 装饰（按 biome 分支）
---@param node Node
---@param biomeIdx number
---@param vis table
function Obstacles.DecorateBlock(node, biomeIdx, vis)
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

--- OVERHEAD 装饰（按 biome 分支）
---@param node Node
---@param biomeIdx number
---@param vis table
function Obstacles.DecorateOverhead(node, biomeIdx, vis)
    local psx, psy, psz = node.scale.x, node.scale.y, node.scale.z

    if biomeIdx == 1 then
        -- Savanna: 底部草帘
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

-- ============================================================================
-- Glacier (biome 2): 冰刺 + 冰山混合生成
-- ============================================================================

--- 生成冰山墙
---@param laneX number
---@param zPos number
---@param iceMat Material
---@param iceDarkMat Material
---@return table obs
function Obstacles.BuildIceberg(laneX, zPos, iceMat, iceDarkMat, sl)
    local iceNode = State.scene:CreateChild("Iceberg")
    iceNode.position = Vector3(laneX, 0, zPos)

    local wallH = 3.0 + math.random() * 1.0
    local wallW = 1.8
    local wallD = 0.8 + math.random() * 0.4
    local mainWall = iceNode:CreateChild("IceWall")
    mainWall.position = Vector3(0, wallH * 0.5, 0)
    mainWall.scale = Vector3(wallW, wallH, wallD)
    local wm = mainWall:CreateComponent("StaticModel")
    wm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    wm:SetMaterial(iceMat)
    wm.castShadows = true

    local peak = iceNode:CreateChild("Peak")
    peak.position = Vector3(
        (math.random() - 0.5) * 0.4, wallH + 0.4, (math.random() - 0.5) * 0.2)
    peak.scale = Vector3(wallW * 0.6, 1.2, wallD * 0.6)
    peak.rotation = Quaternion(math.random() * 15 - 7, Vector3.UP)
    local pm = peak:CreateComponent("StaticModel")
    pm:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
    pm:SetMaterial(iceMat)
    pm.castShadows = true

    for j = 1, math.random(2, 3) do
        local chunk = iceNode:CreateChild("IceChunk")
        local cSide = (j % 2 == 0) and 1 or -1
        chunk.position = Vector3(
            cSide * (wallW * 0.35 + math.random() * 0.3),
            math.random() * wallH * 0.6 + 0.3,
            (math.random() - 0.5) * wallD * 0.5)
        local cs = 0.3 + math.random() * 0.4
        chunk.scale = Vector3(cs, cs * 1.5, cs)
        chunk.rotation = Quaternion(math.random() * 30 - 15, Vector3.UP)
        local cm = chunk:CreateComponent("StaticModel")
        cm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        cm:SetMaterial(iceDarkMat)
        cm.castShadows = true
    end

    return {
        node = iceNode, z = zPos, obsType = Config.OBS_ICEBERG,
        lane = sl, biome = 2, damage = 1
    }
end

--- 生成巨型冰刺
---@param laneX number
---@param zPos number
---@param sl number
---@return table obs
function Obstacles.BuildIceSpike(laneX, zPos, sl)
    local spikeNode = State.scene:CreateChild("IceSpike")
    spikeNode.position = Vector3(laneX, 0, zPos)

    local spikeGlowMat = Config.CreatePBRMaterial(
        Color(0.5, 0.85, 1.0, 1.0), 0.45, 0.08)
    spikeGlowMat:SetShaderParameter("MatEmissiveColor",
        Variant(Color(0.15, 0.35, 0.55)))
    local spikeDarkGlowMat = Config.CreatePBRMaterial(
        Color(0.3, 0.6, 0.85, 1.0), 0.50, 0.10)
    spikeDarkGlowMat:SetShaderParameter("MatEmissiveColor",
        Variant(Color(0.08, 0.20, 0.40)))

    -- 中央主刺
    local mainSpike = spikeNode:CreateChild("MainSpike")
    local mainH = 1.6 + math.random() * 0.4
    mainSpike.position = Vector3(0, 0, 0)
    mainSpike.scale = Vector3(0.5, mainH, 0.5)
    local msm = mainSpike:CreateComponent("StaticModel")
    msm:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
    msm:SetMaterial(spikeGlowMat)
    msm.castShadows = true

    -- 周围 5~7 根副刺
    local spikeCount = math.random(5, 7)
    for j = 1, spikeCount do
        local spike = spikeNode:CreateChild("Spike")
        local sH = 0.8 + math.random() * 0.8
        local sR = 0.2 + math.random() * 0.15
        local angle = (j / spikeCount) * math.pi * 2 + math.random() * 0.5
        local dist = 0.35 + math.random() * 0.35
        spike.position = Vector3(
            math.cos(angle) * dist, 0, math.sin(angle) * dist * 0.6)
        spike.scale = Vector3(sR * 2, sH, sR * 2)
        local tiltX = math.cos(angle) * 12
        local tiltZ = math.sin(angle) * 12
        spike.rotation = Quaternion(tiltZ, 0, -tiltX)
        local sm = spike:CreateComponent("StaticModel")
        sm:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
        sm:SetMaterial((j % 2 == 0) and spikeDarkGlowMat or spikeGlowMat)
        sm.castShadows = true
    end

    return {
        node = spikeNode, z = zPos, obsType = Config.OBS_LOW_BAR,
        lane = sl, biome = 2, damage = 2
    }
end

-- ============================================================================
-- Savanna (biome 1): LOW_BAR — Lowpoly 土堆
-- ============================================================================

---@param node Node
---@param barWidthRatio number
function Obstacles.BuildSavannaMound(node, barOffsetX, zPos, barWidthRatio)
    local moundW = Config.TRACK_WIDTH * barWidthRatio
    local moundBase = moundW * 0.9
    local moundH = 0.8 + moundW * 0.12
    local moundD = math.max(1.5, moundW * 0.5)
    node.position = Vector3(barOffsetX, 0.0, zPos)

    local mainMound = node:CreateChild("MainMound")
    mainMound.position = Vector3(0, 0, 0)
    mainMound.scale = Vector3(moundBase, moundH, moundD)
    local mm = mainMound:CreateComponent("StaticModel")
    mm:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
    mm:SetMaterial(Config.CreatePBRMaterial(
        Color(0.62, 0.42, 0.22, 1.0), 0.0, 0.92))
    mm.castShadows = true

    local bumpCount = barWidthRatio > 0.5 and 4 or 2
    for j = 1, bumpCount do
        local bump = node:CreateChild("Bump")
        local bAngle = (j / bumpCount) * math.pi * 2 + math.random() * 0.8
        local bDist = moundBase * 0.35 + math.random() * moundBase * 0.15
        bump.position = Vector3(
            math.cos(bAngle) * bDist, 0, math.sin(bAngle) * bDist * 0.6)
        local bScale = moundBase * (0.3 + math.random() * 0.2)
        bump.scale = Vector3(bScale, moundH * (0.5 + math.random() * 0.3), bScale * 0.7)
        bump.rotation = Quaternion(math.random() * 40 - 20, Vector3.UP)
        local bm = bump:CreateComponent("StaticModel")
        bm:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
        bm:SetMaterial(Config.CreatePBRMaterial(
            Color(0.58 + math.random() * 0.08, 0.38 + math.random() * 0.06, 0.18, 1.0), 0.0, 0.90))
        bm.castShadows = true
    end

    local rockCount = barWidthRatio > 0.5 and 5 or 3
    for j = 1, rockCount do
        local rock = node:CreateChild("Rock")
        local angle = (j / rockCount) * math.pi * 2 + math.random() * 0.5
        local dist = moundBase * 0.15 + math.random() * moundBase * 0.25
        rock.position = Vector3(
            math.cos(angle) * dist,
            moundH * 0.25 + math.random() * moundH * 0.4,
            math.sin(angle) * dist * 0.5)
        local rs = 0.15 + math.random() * 0.15
        rock.scale = Vector3(rs, rs * 0.8, rs)
        rock.rotation = Quaternion(math.random() * 360, Vector3.UP)
        local rm = rock:CreateComponent("StaticModel")
        rm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        rm:SetMaterial(Config.CreatePBRMaterial(
            Color(0.50, 0.42, 0.34, 1.0), 0.1, 0.85))
        rm.castShadows = true
    end
end

-- ============================================================================
-- Cliffs (biome 3): LOW_BAR — 木栅栏 / 石头堆
-- ============================================================================

---@param node Node
---@param barOffsetX number
---@param zPos number
---@param barWidthRatio number
function Obstacles.BuildCliffsFence(node, barOffsetX, zPos, barWidthRatio)
    local barW = Config.TRACK_WIDTH * barWidthRatio
    node.position = Vector3(barOffsetX, 0, zPos)

    if barWidthRatio > 0.4 then
        -- === Lowpoly 木栅栏 ===
        local fenceH = 0.9
        local postCount = math.max(3, math.floor(barW / 0.8) + 1)
        local woodMat = Config.CreatePBRMaterial(
            Color(0.50, 0.35, 0.18, 1.0), 0.0, 0.85)
        local darkWoodMat = Config.CreatePBRMaterial(
            Color(0.38, 0.25, 0.12, 1.0), 0.0, 0.88)

        for j = 1, postCount do
            local px = (j - 1) / (postCount - 1) * barW - barW * 0.5
            local post = node:CreateChild("FencePost")
            local postH = fenceH + math.random() * 0.15
            post.position = Vector3(px, postH * 0.5, 0)
            post.scale = Vector3(0.12, postH, 0.12)
            post.rotation = Quaternion(0, math.random() * 8 - 4, math.random() * 3 - 1.5)
            local pm = post:CreateComponent("StaticModel")
            pm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
            pm:SetMaterial(woodMat)
            pm.castShadows = true

            local tip = post:CreateChild("Tip")
            tip.position = Vector3(0, 0.52, 0)
            tip.scale = Vector3(1.2, 0.2 / postH, 1.2)
            local tm = tip:CreateComponent("StaticModel")
            tm:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
            tm:SetMaterial(darkWoodMat)
            tm.castShadows = false
        end

        for _, beamY in ipairs({ fenceH * 0.3, fenceH * 0.7 }) do
            local beam = node:CreateChild("FenceBeam")
            beam.position = Vector3(0, beamY, 0)
            beam.scale = Vector3(barW + 0.1, 0.08, 0.06)
            beam.rotation = Quaternion(0, 0, math.random() * 2 - 1)
            local bm = beam:CreateComponent("StaticModel")
            bm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
            bm:SetMaterial(darkWoodMat)
            bm.castShadows = true
        end

        for j = 1, math.random(2, 3) do
            local grass = node:CreateChild("Grass")
            grass.position = Vector3(
                (math.random() - 0.5) * barW * 0.7, 0.08, (math.random() - 0.5) * 0.3)
            grass.scale = Vector3(0.2, 0.18, 0.08)
            grass.rotation = Quaternion(math.random() * 360, Vector3.UP)
            local gm = grass:CreateComponent("StaticModel")
            gm:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
            gm:SetMaterial(Config.CreatePBRMaterial(
                Color(0.28, 0.45, 0.15, 1.0), 0.0, 0.92))
            gm.castShadows = false
        end
    else
        -- === 石头堆 ===
        local rockMat = Config.CreatePBRMaterial(
            Color(0.52, 0.48, 0.42, 1.0), 0.05, 0.88)
        local mossMat = Config.CreatePBRMaterial(
            Color(0.35, 0.45, 0.28, 1.0), 0.0, 0.90)

        for j = 1, math.random(2, 3) do
            local rock = node:CreateChild("BigRock")
            local rs = 0.35 + math.random() * 0.25
            rock.position = Vector3(
                (math.random() - 0.5) * 0.8, rs * 0.4, (math.random() - 0.5) * 0.4)
            rock.scale = Vector3(rs * 1.3, rs * 0.9, rs)
            rock.rotation = Quaternion(
                math.random() * 30 - 15, math.random() * 360, math.random() * 15 - 7)
            local rm = rock:CreateComponent("StaticModel")
            rm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
            rm:SetMaterial(rockMat)
            rm.castShadows = true
        end

        for j = 1, 2 do
            local peak = node:CreateChild("PeakRock")
            local pH = 0.4 + math.random() * 0.3
            peak.position = Vector3(
                (math.random() - 0.5) * 0.5, 0.3 + math.random() * 0.15, (math.random() - 0.5) * 0.3)
            peak.scale = Vector3(0.25, pH, 0.25)
            peak.rotation = Quaternion(
                math.random() * 20 - 10, 0, math.random() * 20 - 10)
            local pm = peak:CreateComponent("StaticModel")
            pm:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
            pm:SetMaterial((j == 1) and rockMat or mossMat)
            pm.castShadows = true
        end

        for j = 1, math.random(2, 3) do
            local moss = node:CreateChild("Moss")
            moss.position = Vector3(
                (math.random() - 0.5) * 0.6, 0.15 + math.random() * 0.2, (math.random() - 0.5) * 0.3)
            moss.scale = Vector3(0.12, 0.1, 0.12)
            local mm = moss:CreateComponent("StaticModel")
            mm:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
            mm:SetMaterial(mossMat)
            mm.castShadows = false
        end
    end
end

-- ============================================================================
-- HIGH_BAR: 滚木（Savanna / Cliffs 共用结构，颜色不同）
-- ============================================================================

---@param node Node
---@param barOffsetX number
---@param zPos number
---@param barW number
---@param biomeIdx number
---@return number logBaseY
function Obstacles.BuildRollingLog(node, barOffsetX, zPos, barW, biomeIdx)
    local logRadius = 0.45
    local logLen = barW
    node.position = Vector3(barOffsetX, logRadius + 0.1, zPos)

    local logBody = node:CreateChild("LogBody")
    logBody.rotation = Quaternion(0, 0, 90)

    -- 颜色配置
    local trunkColor, barkColor, capColor, stumpColor
    if biomeIdx == 3 then
        -- Cliffs: 苔藓色调
        trunkColor = Color(0.35, 0.30, 0.15, 1.0)
        barkColor  = Color(0.25, 0.35, 0.12, 1.0)
        capColor   = Color(0.60, 0.48, 0.28, 1.0)
        stumpColor = Color(0.40, 0.32, 0.16, 1.0)
    else
        -- Savanna: 原木色
        trunkColor = Color(0.45, 0.28, 0.12, 1.0)
        barkColor  = Color(0.38, 0.22, 0.08, 1.0)
        capColor   = Color(0.72, 0.55, 0.32, 1.0)
        stumpColor = Color(0.52, 0.32, 0.14, 1.0)
    end

    -- 主干
    local trunk = logBody:CreateChild("Trunk")
    trunk.scale = Vector3(logRadius * 2, logLen, logRadius * 2)
    local tm = trunk:CreateComponent("StaticModel")
    tm:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
    tm:SetMaterial(Config.CreatePBRMaterial(trunkColor, 0.0, 0.88))
    tm.castShadows = true

    -- 树皮条纹
    for j = 1, 5 do
        local angle = (j / 5) * math.pi * 2
        local bark = logBody:CreateChild("Bark")
        bark.position = Vector3(
            math.cos(angle) * logRadius * 0.85, 0,
            math.sin(angle) * logRadius * 0.85)
        bark.scale = Vector3(0.12, logLen * 0.9, 0.08)
        local bm = bark:CreateComponent("StaticModel")
        bm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        bm:SetMaterial(Config.CreatePBRMaterial(barkColor, 0.0, 0.90))
        bm.castShadows = false
    end

    -- 两端截面
    for side = -1, 1, 2 do
        local cap = logBody:CreateChild("Cap")
        cap.position = Vector3(0, side * logLen * 0.5, 0)
        cap.scale = Vector3(logRadius * 1.8, 0.05, logRadius * 1.8)
        local cm = cap:CreateComponent("StaticModel")
        cm:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
        cm:SetMaterial(Config.CreatePBRMaterial(capColor, 0.0, 0.85))
        cm.castShadows = false
    end

    -- 树枝窦子
    local stumpData = (biomeIdx == 3)
        and {
            { angle = 0.6,  yOff = -0.25 },
            { angle = 2.0,  yOff =  0.15 },
            { angle = 3.8,  yOff = -0.15 },
            { angle = 5.1,  yOff =  0.30 },
            { angle = 1.5,  yOff = -0.35 },
        }
        or {
            { angle = 0.4,  yOff = -0.3 },
            { angle = 1.8,  yOff =  0.2 },
            { angle = 3.5,  yOff = -0.1 },
            { angle = 4.9,  yOff =  0.35 },
            { angle = 2.2,  yOff = -0.4 },
        }
    for _, sd in ipairs(stumpData) do
        local stump = logBody:CreateChild("Stump")
        stump.position = Vector3(
            math.cos(sd.angle) * logRadius * 0.9,
            sd.yOff * logLen,
            math.sin(sd.angle) * logRadius * 0.9)
        stump.rotation = Quaternion(0, 0, -math.deg(sd.angle) + 90)
        stump.scale = Vector3(0.12, 0.25, 0.12)
        local sm = stump:CreateComponent("StaticModel")
        sm:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
        sm:SetMaterial(Config.CreatePBRMaterial(stumpColor, 0.0, 0.88))
        sm.castShadows = false
    end

    return logRadius + 0.1  -- logBaseY
end

-- ============================================================================
-- OVERHEAD: Savanna — 西部广告牌
-- ============================================================================

---@param node Node
---@param barOffsetX number
---@param zPos number
---@param barWidthRatio number
function Obstacles.BuildSavannaBillboard(node, barOffsetX, zPos, barWidthRatio)
    local barW = Config.TRACK_WIDTH * (barWidthRatio + 0.05)
    node.position = Vector3(barOffsetX, 2.2, zPos)

    -- 两根木柱
    for side = -1, 1, 2 do
        local post = node:CreateChild("Post")
        post.position = Vector3(side * barW * 0.42, -0.8, 0)
        post.scale = Vector3(0.2, 3.8, 0.2)
        local pm = post:CreateComponent("StaticModel")
        pm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        pm:SetMaterial(Config.CreatePBRMaterial(
            Color(0.45, 0.28, 0.12, 1.0), 0.0, 0.88))
        pm.castShadows = true
    end

    -- 广告牌底板
    local signW = barW * 0.8
    local signH = signW * (768 / 1376)
    local boardNode = node:CreateChild("Board")
    boardNode.position = Vector3(0, 0.4, 0)
    boardNode.scale = Vector3(signW, signH, 0.08)
    local boardModel = boardNode:CreateComponent("StaticModel")
    boardModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    boardModel:SetMaterial(Config.CreatePBRMaterial(
        Color(0.55, 0.35, 0.15, 1.0), 0.0, 0.85))
    boardModel.castShadows = true

    -- 木板边框
    local frameThick = 0.06
    local frameDepth = 0.12
    local frameOffsets = {
        { Vector3(0, signH * 0.5, 0),  Vector3(signW + frameThick * 2, frameThick, frameDepth) },
        { Vector3(0, -signH * 0.5, 0), Vector3(signW + frameThick * 2, frameThick, frameDepth) },
        { Vector3(-signW * 0.5, 0, 0), Vector3(frameThick, signH, frameDepth) },
        { Vector3(signW * 0.5, 0, 0),  Vector3(frameThick, signH, frameDepth) },
    }
    for _, fo in ipairs(frameOffsets) do
        local frame = node:CreateChild("Frame")
        frame.position = Vector3(fo[1].x, 0.4 + fo[1].y, fo[1].z)
        frame.scale = fo[2]
        local fm = frame:CreateComponent("StaticModel")
        fm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        fm:SetMaterial(Config.CreatePBRMaterial(
            Color(0.35, 0.20, 0.08, 1.0), 0.0, 0.90))
        fm.castShadows = true
    end

    -- 海报贴图
    local posterNode = node:CreateChild("Poster")
    posterNode.position = Vector3(0, 0.4, -0.05)

    local bbSet = posterNode:CreateComponent("BillboardSet")
    bbSet.numBillboards = 1
    bbSet.sorted = true
    bbSet.faceCameraMode = FC_NONE
    bbSet.castShadows = false

    if not blockTexCache["billboard_poster"] then
        local mat = Material:new()
        mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/DiffAlpha.xml"))
        mat:SetTexture(0, cache:GetResource("Texture2D", "image/billboard_poster.png"))
        mat:SetShaderParameter("MatDiffColor", Variant(Color(2.5, 2.5, 2.5, 1.0)))
        blockTexCache["billboard_poster"] = mat
    end
    bbSet:SetMaterial(blockTexCache["billboard_poster"])

    local bb = bbSet:GetBillboard(0)
    bb.position = Vector3(0, 0, 0)
    bb.size = Vector2(signW * 0.48, signH * 0.48)
    bb.enabled = true
    bbSet:Commit()
end

-- ============================================================================
-- OVERHEAD: Cliffs — 吊脚楼
-- ============================================================================

---@param node Node
---@param barOffsetX number
---@param zPos number
---@param barWidthRatio number
function Obstacles.BuildStiltHouse(node, barOffsetX, zPos, barWidthRatio)
    local barW = Config.TRACK_WIDTH * (barWidthRatio + 0.05)
    node.position = Vector3(barOffsetX, 0, zPos)

    local logMat = Config.CreatePBRMaterial(
        Color(0.48, 0.32, 0.15, 1.0), 0.0, 0.82)
    local darkLogMat = Config.CreatePBRMaterial(
        Color(0.35, 0.22, 0.10, 1.0), 0.0, 0.88)
    local plankMat = Config.CreatePBRMaterial(
        Color(0.55, 0.40, 0.22, 1.0), 0.0, 0.80)
    local roofMat = Config.CreatePBRMaterial(
        Color(0.30, 0.25, 0.18, 1.0), 0.0, 0.90)

    local floorY = 1.5
    local houseH = 1.6
    local houseD = 1.4
    local roofH = 0.8

    -- 4根圆柱吊脚
    local legW = 0.15
    for _, lx in ipairs({ -barW * 0.4, barW * 0.4 }) do
        for _, lz in ipairs({ -houseD * 0.4, houseD * 0.4 }) do
            local leg = node:CreateChild("Leg")
            leg.position = Vector3(lx, floorY * 0.5, lz)
            leg.scale = Vector3(legW, floorY, legW)
            local lm = leg:CreateComponent("StaticModel")
            lm:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
            lm:SetMaterial(logMat)
            lm.castShadows = true
        end
    end

    -- 楼板
    local floor = node:CreateChild("Floor")
    floor.position = Vector3(0, floorY, 0)
    floor.scale = Vector3(barW * 0.9, 0.1, houseD)
    local fm = floor:CreateComponent("StaticModel")
    fm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    fm:SetMaterial(plankMat)
    fm.castShadows = true

    -- 后墙
    local backWall = node:CreateChild("BackWall")
    backWall.position = Vector3(0, floorY + houseH * 0.5, houseD * 0.45)
    backWall.scale = Vector3(barW * 0.88, houseH, 0.06)
    local bwm = backWall:CreateComponent("StaticModel")
    bwm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    bwm:SetMaterial(plankMat)
    bwm.castShadows = true

    -- 左右侧板
    for side = -1, 1, 2 do
        local sideWall = node:CreateChild("SideWall")
        sideWall.position = Vector3(side * barW * 0.44, floorY + houseH * 0.5, 0)
        sideWall.scale = Vector3(0.06, houseH, houseD * 0.88)
        local swm = sideWall:CreateComponent("StaticModel")
        swm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        swm:SetMaterial(plankMat)
        swm.castShadows = true
    end

    -- 前面横梁（门洞效果）
    local frontBeam = node:CreateChild("FrontBeam")
    frontBeam.position = Vector3(0, floorY + houseH * 0.85, -houseD * 0.45)
    frontBeam.scale = Vector3(barW * 0.88, houseH * 0.3, 0.06)
    local fbm = frontBeam:CreateComponent("StaticModel")
    fbm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    fbm:SetMaterial(darkLogMat)
    fbm.castShadows = true

    -- 窗户
    for side = -1, 1, 2 do
        local window = node:CreateChild("Window")
        window.position = Vector3(
            side * barW * 0.2, floorY + houseH * 0.5, -houseD * 0.46)
        window.scale = Vector3(barW * 0.12, houseH * 0.25, 0.04)
        local wm = window:CreateComponent("StaticModel")
        wm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        wm:SetMaterial(Config.CreatePBRMaterial(
            Color(0.12, 0.10, 0.08, 1.0), 0.0, 0.95))
        wm.castShadows = false
    end

    -- 三角屋顶
    local roofW = barW * 0.55
    local roofLen = houseD * 1.1
    for side = -1, 1, 2 do
        local roofPanel = node:CreateChild("Roof")
        local roofAngle = side * -28
        roofPanel.position = Vector3(
            side * roofW * 0.4, floorY + houseH + roofH * 0.35, 0)
        roofPanel.rotation = Quaternion(0, 0, roofAngle)
        roofPanel.scale = Vector3(roofW, 0.06, roofLen)
        local rm = roofPanel:CreateComponent("StaticModel")
        rm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        rm:SetMaterial(roofMat)
        rm.castShadows = true
    end

    -- 屋顶脊梁
    local ridge = node:CreateChild("Ridge")
    ridge.position = Vector3(0, floorY + houseH + roofH * 0.62, 0)
    ridge.scale = Vector3(0.08, 0.08, roofLen * 1.05)
    local rdm = ridge:CreateComponent("StaticModel")
    rdm:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
    rdm:SetMaterial(darkLogMat)
    rdm.castShadows = true

    -- 屋檐挂饰
    for j = 1, math.random(2, 3) do
        local hang = node:CreateChild("Hang")
        hang.position = Vector3(
            (math.random() - 0.5) * barW * 0.5,
            floorY - 0.05,
            -houseD * 0.3 + math.random() * houseD * 0.2)
        hang.scale = Vector3(0.03, 0.25 + math.random() * 0.15, 0.03)
        local hm = hang:CreateComponent("StaticModel")
        hm:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
        hm:SetMaterial(darkLogMat)
        hm.castShadows = false
    end
end

return Obstacles
