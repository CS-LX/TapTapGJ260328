-- ============================================================================
-- Game/World/Holes.lua — 地面窟窿系统
-- ============================================================================

local Config = require "Game.Config"
local State  = require "Game.State"

-- Canyon 模块用于 SkipCanyon
local Canyon = require "Game.World.Canyon"

local Holes = {}

--- 创建窟窿的视觉表现（按场景派发 3D 效果）
function Holes.CreateHoleVisual(hole)
    hole.nodes = {}
    local biomeIdx = hole.biomeIndex or 1
    for _, lane in ipairs(hole.lanes) do
        if biomeIdx == 2 then
            Holes.CreateIceCrackVisual(hole, lane)
        elseif biomeIdx == 3 then
            Holes.CreateCliffEdgeVisual(hole, lane)
        end
    end
end

-- ============================================================================
-- Glacier: 3D 冰裂缝（深蓝底部 + 冰壁 + 暗色开口 + 发光边缘 + 碎冰）
-- ============================================================================

function Holes.CreateIceCrackVisual(hole, lane)
    local vis = Config.HOLE_VISUALS[2]
    local holeLen = hole.zEnd - hole.zStart
    local cx = lane * Config.LANE_WIDTH
    local cz = (hole.zStart + hole.zEnd) / 2
    local lw = Config.LANE_WIDTH * 0.95

    -- 1) 深层底部（深蓝黑色，沉到地面以下）
    local bottom = State.scene:CreateChild("Hole")
    bottom.position = Vector3(cx, -1.5, cz)
    bottom.scale = Vector3(lw * 0.6, 0.3, holeLen * 0.9)
    local bm = bottom:CreateComponent("StaticModel")
    bm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    bm:SetMaterial(Config.CreatePBRMaterial(vis.bottomColor, 0.0, 1.0))
    bm.castShadows = false
    table.insert(hole.nodes, bottom)

    -- 2) 冰壁（左右两面，收窄形成 V 形裂缝）
    for side = -1, 1, 2 do
        local wall = State.scene:CreateChild("Hole")
        wall.position = Vector3(cx + side * lw * 0.35, -0.7, cz)
        wall.scale = Vector3(0.15, 1.5, holeLen * 0.95)
        local wm = wall:CreateComponent("StaticModel")
        wm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        local wallMat = Material:new()
        wallMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
        wallMat:SetShaderParameter("MatDiffColor", Variant(vis.wallColor))
        wallMat:SetShaderParameter("MatEmissiveColor", Variant(vis.wallEmissive))
        wallMat:SetShaderParameter("Metallic", Variant(0.2))
        wallMat:SetShaderParameter("Roughness", Variant(0.15))
        wm:SetMaterial(wallMat)
        wm.castShadows = false
        table.insert(hole.nodes, wall)
    end

    -- 3) 暗色开口面（盖住地面，营造深渊感）
    local opening = State.scene:CreateChild("Hole")
    opening.position = Vector3(cx, -0.04, cz)
    opening.scale = Vector3(lw, 0.15, holeLen)
    local om = opening:CreateComponent("StaticModel")
    om:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    om:SetMaterial(Config.CreatePBRMaterial(Color(0.03, 0.05, 0.12, 1.0), 0.0, 1.0))
    om.castShadows = false
    table.insert(hole.nodes, opening)

    -- 4) 发光边缘条（前后各一条，冰蓝色微光）
    local edgeMat = Material:new()
    edgeMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    edgeMat:SetShaderParameter("MatDiffColor", Variant(vis.edgeColor))
    edgeMat:SetShaderParameter("MatEmissiveColor", Variant(vis.edgeEmissive))
    edgeMat:SetShaderParameter("Metallic", Variant(0.1))
    edgeMat:SetShaderParameter("Roughness", Variant(0.2))
    for _, zOff in ipairs({ hole.zStart, hole.zEnd }) do
        local edge = State.scene:CreateChild("Hole")
        edge.position = Vector3(cx, 0.02, zOff)
        edge.scale = Vector3(lw, 0.06, 0.2)
        local em = edge:CreateComponent("StaticModel")
        em:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        em:SetMaterial(edgeMat)
        em.castShadows = false
        table.insert(hole.nodes, edge)
    end

    -- 5) 散落碎冰块（裂缝边缘 3-5 块小冰碴）
    local fragCount = math.random(3, 5)
    for j = 1, fragCount do
        local frag = State.scene:CreateChild("Hole")
        local fz = hole.zStart + math.random() * holeLen
        local fx = cx + (math.random() - 0.5) * lw * 1.1
        local fs = 0.08 + math.random() * 0.15
        frag.position = Vector3(fx, 0.02 + math.random() * 0.05, fz)
        frag.rotation = Quaternion(math.random() * 360, math.random() * 30, math.random() * 30)
        frag.scale = Vector3(fs, fs * 0.5, fs * 0.7)
        local fm = frag:CreateComponent("StaticModel")
        fm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        fm:SetMaterial(Config.CreatePBRMaterial(vis.fragmentColor, 0.2, 0.15))
        fm.castShadows = false
        table.insert(hole.nodes, frag)
    end
end

-- ============================================================================
-- Cliffs: 3D 悬崖边缘（深渊 + 岩壁 + 暗影 + 草皮边缘 + 碎石）
-- ============================================================================

function Holes.CreateCliffEdgeVisual(hole, lane)
    local vis = Config.HOLE_VISUALS[3]
    local holeLen = hole.zEnd - hole.zStart
    local cx = lane * Config.LANE_WIDTH
    local cz = (hole.zStart + hole.zEnd) / 2
    local lw = Config.LANE_WIDTH * 0.95

    -- 1) 深渊底部（几乎纯黑）
    local abyss = State.scene:CreateChild("Hole")
    abyss.position = Vector3(cx, -2.0, cz)
    abyss.scale = Vector3(lw * 0.7, 0.3, holeLen * 0.85)
    local am = abyss:CreateComponent("StaticModel")
    am:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    am:SetMaterial(Config.CreatePBRMaterial(vis.bottomColor, 0.0, 1.0))
    am.castShadows = false
    table.insert(hole.nodes, abyss)

    -- 2) 岩壁（左右两面，棕色岩石质感）
    for side = -1, 1, 2 do
        local wall = State.scene:CreateChild("Hole")
        wall.position = Vector3(cx + side * lw * 0.38, -0.9, cz)
        wall.scale = Vector3(0.2, 2.0, holeLen * 0.95)
        local wm = wall:CreateComponent("StaticModel")
        wm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        wm:SetMaterial(Config.CreatePBRMaterial(vis.wallColor, 0.0, 0.92))
        wm.castShadows = false
        table.insert(hole.nodes, wall)
    end

    -- 3) 暗影开口
    local shadow = State.scene:CreateChild("Hole")
    shadow.position = Vector3(cx, -0.04, cz)
    shadow.scale = Vector3(lw, 0.15, holeLen)
    local sm = shadow:CreateComponent("StaticModel")
    sm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    sm:SetMaterial(Config.CreatePBRMaterial(Color(0.04, 0.04, 0.03, 1.0), 0.0, 1.0))
    sm.castShadows = false
    table.insert(hole.nodes, shadow)

    -- 4) 草皮边缘（前后各一条绿色草坪条带）
    local grassMat = Config.CreatePBRMaterial(vis.grassColor, 0.0, 0.85)
    for _, zOff in ipairs({ hole.zStart, hole.zEnd }) do
        local lip = State.scene:CreateChild("Hole")
        lip.position = Vector3(cx, 0.02, zOff)
        lip.scale = Vector3(lw * 1.05, 0.06, 0.3)
        local lm = lip:CreateComponent("StaticModel")
        lm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        lm:SetMaterial(grassMat)
        lm.castShadows = false
        table.insert(hole.nodes, lip)
    end

    -- 5) 崖壁边缘色条（棕色岩石边条，前后）
    local edgeMat = Config.CreatePBRMaterial(vis.edgeColor, 0.0, 0.88)
    for _, zOff in ipairs({ hole.zStart - 0.1, hole.zEnd + 0.1 }) do
        local edge = State.scene:CreateChild("Hole")
        edge.position = Vector3(cx, -0.1, zOff)
        edge.scale = Vector3(lw, 0.2, 0.15)
        local em = edge:CreateComponent("StaticModel")
        em:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        em:SetMaterial(edgeMat)
        em.castShadows = false
        table.insert(hole.nodes, edge)
    end

    -- 6) 散落碎石（悬崖边缘 3-6 块碎石）
    local rubbleCount = math.random(3, 6)
    for j = 1, rubbleCount do
        local rubble = State.scene:CreateChild("Hole")
        local rz = hole.zStart + math.random() * holeLen
        local rx = cx + (math.random() - 0.5) * lw * 1.15
        local rs = 0.1 + math.random() * 0.2
        rubble.position = Vector3(rx, 0.01 + math.random() * 0.04, rz)
        rubble.rotation = Quaternion(math.random() * 360, math.random() * 20, math.random() * 20)
        rubble.scale = Vector3(rs, rs * 0.5, rs * 0.6)
        local rm = rubble:CreateComponent("StaticModel")
        rm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        rm:SetMaterial(Config.CreatePBRMaterial(vis.fragmentColor, 0.0, 0.9))
        rm.castShadows = false
        table.insert(hole.nodes, rubble)
    end
end

--- 为一段地面生成窟窿
--- @param segStartZ number 地面段起点 Z
--- @param segEndZ number 地面段终点 Z
--- @param biomeIdx number 当前场景索引
function Holes.GenerateForSegment(segStartZ, segEndZ, biomeIdx)
    local cfg = Config.HOLE_CONFIGS[biomeIdx]
    if not cfg or not cfg.enabled then return end

    while State.nextHoleZ < segEndZ do
        if State.nextHoleZ < segStartZ then
            State.nextHoleZ = segStartZ + 10
        end

        State.nextHoleZ = Canyon.SkipCanyon(State.nextHoleZ, 15)
        if State.nextHoleZ >= segEndZ then break end

        local holeLen = cfg.minLen + math.random() * (cfg.maxLen - cfg.minLen)
        if State.nextHoleZ + holeLen > segEndZ - 5 then break end

        local lanes = {}
        if cfg.maxLanes == 1 then
            lanes = { math.random(0, 1) == 0 and -1 or 1 }
        elseif cfg.maxLanes == 2 then
            if math.random() < 0.35 then
                lanes = { math.random(0, 1) == 0 and -1 or 1 }
            else
                lanes = { -1, 1 }
            end
        end

        local hole = {
            zStart     = State.nextHoleZ,
            zEnd       = State.nextHoleZ + holeLen,
            lanes      = lanes,
            biomeIndex = biomeIdx,
        }
        Holes.CreateHoleVisual(hole)
        table.insert(State.holes, hole)

        local interval = cfg.intervalMin + math.random() * (cfg.intervalMax - cfg.intervalMin)
        State.nextHoleZ = State.nextHoleZ + holeLen + interval
    end
end

--- 检查 (z, lane) 是否在窟窿上
function Holes.IsOverHole(z, lane)
    for _, hole in ipairs(State.holes) do
        if z >= hole.zStart and z <= hole.zEnd then
            for _, hl in ipairs(hole.lanes) do
                if hl == lane then return true end
            end
        end
    end
    return false
end

--- 获取 z 位置的实心车道列表
function Holes.GetSolidLanes(z)
    local solid = { [-1] = true, [0] = true, [1] = true }
    for _, hole in ipairs(State.holes) do
        if z >= hole.zStart and z <= hole.zEnd then
            for _, hl in ipairs(hole.lanes) do
                solid[hl] = nil
            end
        end
    end
    local result = {}
    for lane = -1, 1 do
        if solid[lane] then
            result[#result + 1] = lane
        end
    end
    return result
end

--- 清理过远的窟窿
function Holes.Cleanup(playerZ)
    for i = #State.holes, 1, -1 do
        local hole = State.holes[i]
        if hole.zEnd < playerZ - 50 then
            if hole.nodes then
                for _, n in ipairs(hole.nodes) do
                    if n then n:Remove() end
                end
            end
            table.remove(State.holes, i)
        end
    end
end

return Holes
