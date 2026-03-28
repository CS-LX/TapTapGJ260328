-- ============================================================================
-- Game/World/Holes.lua — 地面窟窿系统（真实开洞 + 背面渲染内壁洞窟）
-- ============================================================================

local Config = require "Game.Config"
local State  = require "Game.State"

-- Canyon 模块用于 SkipCanyon
local Canyon = require "Game.World.Canyon"

local Holes = {}

--- 创建只显示内壁的 PBR 材质（剔除正面，只渲染背面）
local function CreateInnerWallMaterial(color, metallic, roughness, emissiveColor)
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(color))
    mat:SetShaderParameter("Metallic", Variant(metallic or 0.0))
    mat:SetShaderParameter("Roughness", Variant(roughness or 0.5))
    if emissiveColor then
        mat:SetShaderParameter("MatEmissiveColor", Variant(emissiveColor))
    end
    mat:SetCullMode(CULL_CW)  -- 剔除正面(顺时针)，只显示背面(内壁)
    return mat
end

-- ============================================================================
-- PunchGround: 拆分地面 Box，在洞的车道留出真实缺口
-- ============================================================================

--- 拆分地面：删除原地面 Box，按车道条带重建，有洞的车道留缺口
local function PunchGround(segStartZ, segEndZ, biomeIdx)
    local segZ = (segStartZ + segEndZ) / 2

    -- 收集本段内的所有洞
    local holeRanges = {}
    for _, hole in ipairs(State.holes) do
        if hole.zEnd > segStartZ and hole.zStart < segEndZ then
            holeRanges[#holeRanges + 1] = hole
        end
    end
    if #holeRanges == 0 then return end

    -- 找到原地面段并删除
    local segData = nil
    for _, seg in ipairs(State.groundSegments) do
        if math.abs(seg.z - segZ) < 1.0 then
            segData = seg
            break
        end
    end
    if not segData or not segData.node then return end
    segData.node:Remove()
    segData.node = nil  -- 标记为已拆分，由名称清理回收新节点

    -- 同时删除原跑道线（稍后重建不穿越洞口的版本）
    local children = State.scene:GetChildren()
    for i = #children, 1, -1 do
        local child = children[i]
        if child.name == "LaneLine" and math.abs(child.position.z - segZ) < 1.0 then
            child:Remove()
        end
    end

    -- 重建地面
    local biome = Config.BIOMES[biomeIdx]
    local LW = Config.LANE_WIDTH
    local halfTrack = Config.TRACK_WIDTH / 2
    local groundMat = Config.CreatePBRMaterial(biome.ground, 0.0, 0.9)
    local laneMat = Config.CreatePBRMaterial(biome.lane, 0.0, 0.5)

    -- 五条纵向条带: 左边缘 | 左车道 | 中车道 | 右车道 | 右边缘
    local strips = {
        { x1 = -halfTrack, x2 = -LW * 1.5, lane = nil },
        { x1 = -LW * 1.5, x2 = -LW * 0.5, lane = -1 },
        { x1 = -LW * 0.5, x2 =  LW * 0.5, lane =  0 },
        { x1 =  LW * 0.5, x2 =  LW * 1.5, lane =  1 },
        { x1 =  LW * 1.5, x2 =  halfTrack, lane = nil },
    }

    for _, strip in ipairs(strips) do
        local w = strip.x2 - strip.x1
        local cx = (strip.x1 + strip.x2) / 2

        -- 收集此车道在本段内的洞
        local laneHoles = {}
        if strip.lane then
            for _, hole in ipairs(holeRanges) do
                for _, hl in ipairs(hole.lanes) do
                    if hl == strip.lane then
                        laneHoles[#laneHoles + 1] = {
                            zStart = math.max(hole.zStart, segStartZ),
                            zEnd   = math.min(hole.zEnd, segEndZ),
                        }
                        break
                    end
                end
            end
            table.sort(laneHoles, function(a, b) return a.zStart < b.zStart end)
        end

        if #laneHoles == 0 then
            -- 无洞：整段铺满
            local node = State.scene:CreateChild("Ground")
            node.position = Vector3(cx, -0.25, segZ)
            node.scale = Vector3(w, 0.5, Config.TRACK_LENGTH)
            local m = node:CreateComponent("StaticModel")
            m:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
            m:SetMaterial(groundMat)
        else
            -- 有洞：在洞之间铺地面碎片
            local curZ = segStartZ
            for _, lh in ipairs(laneHoles) do
                if lh.zStart > curZ + 0.2 then
                    local pLen = lh.zStart - curZ
                    local pZ = (curZ + lh.zStart) / 2
                    local node = State.scene:CreateChild("Ground")
                    node.position = Vector3(cx, -0.25, pZ)
                    node.scale = Vector3(w, 0.5, pLen)
                    local m = node:CreateComponent("StaticModel")
                    m:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
                    m:SetMaterial(groundMat)
                end
                curZ = lh.zEnd
            end
            -- 最后一段
            if curZ < segEndZ - 0.2 then
                local pLen = segEndZ - curZ
                local pZ = (curZ + segEndZ) / 2
                local node = State.scene:CreateChild("Ground")
                node.position = Vector3(cx, -0.25, pZ)
                node.scale = Vector3(w, 0.5, pLen)
                local m = node:CreateComponent("StaticModel")
                m:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
                m:SetMaterial(groundMat)
            end
        end
    end

    -- 重建跑道线（同样按洞切割）
    for i = -1, 1 do
        local lineX = i * LW
        -- 收集所有影响此线位置的洞（线在两个车道的边界，任一侧有洞就切断）
        local lineHoles = {}
        for _, hole in ipairs(holeRanges) do
            for _, hl in ipairs(hole.lanes) do
                -- 线在 lane 和 lane+1 的边界，检查两侧
                -- i=-1 的线在 lane -1 和 0 之间（x=-2.5），i=0 在 0 和 1（x=0），i=1 在 1 和右边（x=2.5）
                -- 简化：如果洞的车道与此线相邻就切断
                if hl == i or hl == i - 1 then
                    local zs = math.max(hole.zStart, segStartZ)
                    local ze = math.min(hole.zEnd, segEndZ)
                    lineHoles[#lineHoles + 1] = { zStart = zs, zEnd = ze }
                end
            end
        end
        -- 合并重叠区间
        table.sort(lineHoles, function(a, b) return a.zStart < b.zStart end)
        local merged = {}
        for _, lh in ipairs(lineHoles) do
            if #merged > 0 and lh.zStart <= merged[#merged].zEnd then
                merged[#merged].zEnd = math.max(merged[#merged].zEnd, lh.zEnd)
            else
                merged[#merged + 1] = { zStart = lh.zStart, zEnd = lh.zEnd }
            end
        end

        if #merged == 0 then
            -- 无洞影响，整段跑道线
            local ln = State.scene:CreateChild("LaneLine")
            ln.position = Vector3(lineX, 0.01, segZ)
            ln.scale = Vector3(0.08, 0.01, Config.TRACK_LENGTH)
            local lm = ln:CreateComponent("StaticModel")
            lm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
            lm:SetMaterial(laneMat)
        else
            local curZ = segStartZ
            for _, lh in ipairs(merged) do
                if lh.zStart > curZ + 0.2 then
                    local pLen = lh.zStart - curZ
                    local pZ = (curZ + lh.zStart) / 2
                    local ln = State.scene:CreateChild("LaneLine")
                    ln.position = Vector3(lineX, 0.01, pZ)
                    ln.scale = Vector3(0.08, 0.01, pLen)
                    local lm = ln:CreateComponent("StaticModel")
                    lm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
                    lm:SetMaterial(laneMat)
                end
                curZ = lh.zEnd
            end
            if curZ < segEndZ - 0.2 then
                local pLen = segEndZ - curZ
                local pZ = (curZ + segEndZ) / 2
                local ln = State.scene:CreateChild("LaneLine")
                ln.position = Vector3(lineX, 0.01, pZ)
                ln.scale = Vector3(0.08, 0.01, pLen)
                local lm = ln:CreateComponent("StaticModel")
                lm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
                lm:SetMaterial(laneMat)
            end
        end
    end
end

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
-- Glacier: 冰裂缝洞窟（背面渲染内壁 + 发光边缘 + 碎冰）
-- ============================================================================

function Holes.CreateIceCrackVisual(hole, lane)
    local vis = Config.HOLE_VISUALS[2]
    local holeLen = hole.zEnd - hole.zStart
    local cx = lane * Config.LANE_WIDTH
    local cz = (hole.zStart + hole.zEnd) / 2
    local lw = Config.LANE_WIDTH * 0.95

    -- 1) 洞窟主体（背面渲染的长方体，沉入地面以下）
    local caveDepth = 2.5
    local caveNode = State.scene:CreateChild("Hole")
    caveNode.position = Vector3(cx, -caveDepth / 2, cz)
    caveNode.scale = Vector3(lw, caveDepth, holeLen * 0.98)
    local cm = caveNode:CreateComponent("StaticModel")
    cm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    cm:SetMaterial(CreateInnerWallMaterial(vis.wallColor, 0.15, 0.2, vis.wallEmissive))
    cm.castShadows = false
    table.insert(hole.nodes, caveNode)

    -- 2) 深层底部（暗色底板，正常渲染）
    local bottom = State.scene:CreateChild("Hole")
    bottom.position = Vector3(cx, -caveDepth, cz)
    bottom.scale = Vector3(lw * 0.95, 0.1, holeLen * 0.95)
    local bm = bottom:CreateComponent("StaticModel")
    bm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    bm:SetMaterial(Config.CreatePBRMaterial(vis.bottomColor, 0.0, 1.0))
    bm.castShadows = false
    table.insert(hole.nodes, bottom)

    -- 3) 发光边缘条（洞口四周冰蓝色微光边框）
    local edgeMat = Material:new()
    edgeMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    edgeMat:SetShaderParameter("MatDiffColor", Variant(vis.edgeColor))
    edgeMat:SetShaderParameter("MatEmissiveColor", Variant(vis.edgeEmissive))
    edgeMat:SetShaderParameter("Metallic", Variant(0.1))
    edgeMat:SetShaderParameter("Roughness", Variant(0.2))

    -- 前后边缘
    for _, zOff in ipairs({ hole.zStart, hole.zEnd }) do
        local edge = State.scene:CreateChild("Hole")
        edge.position = Vector3(cx, 0.02, zOff)
        edge.scale = Vector3(lw * 1.02, 0.05, 0.15)
        local em = edge:CreateComponent("StaticModel")
        em:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        em:SetMaterial(edgeMat)
        em.castShadows = false
        table.insert(hole.nodes, edge)
    end
    -- 左右边缘
    for side = -1, 1, 2 do
        local sideEdge = State.scene:CreateChild("Hole")
        sideEdge.position = Vector3(cx + side * lw * 0.5, 0.02, cz)
        sideEdge.scale = Vector3(0.12, 0.05, holeLen)
        local sem = sideEdge:CreateComponent("StaticModel")
        sem:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        sem:SetMaterial(edgeMat)
        sem.castShadows = false
        table.insert(hole.nodes, sideEdge)
    end

    -- 4) 散落碎冰块
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
-- Cliffs: 悬崖边缘洞窟（背面渲染岩壁 + 草皮边缘 + 碎石）
-- ============================================================================

function Holes.CreateCliffEdgeVisual(hole, lane)
    local vis = Config.HOLE_VISUALS[3]
    local holeLen = hole.zEnd - hole.zStart
    local cx = lane * Config.LANE_WIDTH
    local cz = (hole.zStart + hole.zEnd) / 2
    local lw = Config.LANE_WIDTH * 0.95

    -- 1) 洞窟主体（背面渲染 — 岩石内壁）
    local caveDepth = 3.0
    local caveNode = State.scene:CreateChild("Hole")
    caveNode.position = Vector3(cx, -caveDepth / 2, cz)
    caveNode.scale = Vector3(lw, caveDepth, holeLen * 0.98)
    local cm = caveNode:CreateComponent("StaticModel")
    cm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    cm:SetMaterial(CreateInnerWallMaterial(vis.wallColor, 0.0, 0.88))
    cm.castShadows = false
    table.insert(hole.nodes, caveNode)

    -- 2) 深渊底部
    local abyss = State.scene:CreateChild("Hole")
    abyss.position = Vector3(cx, -caveDepth, cz)
    abyss.scale = Vector3(lw * 0.95, 0.1, holeLen * 0.95)
    local am = abyss:CreateComponent("StaticModel")
    am:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    am:SetMaterial(Config.CreatePBRMaterial(vis.bottomColor, 0.0, 1.0))
    am.castShadows = false
    table.insert(hole.nodes, abyss)

    -- 3) 草皮边缘
    local grassMat = Config.CreatePBRMaterial(vis.grassColor, 0.0, 0.85)
    for _, zOff in ipairs({ hole.zStart, hole.zEnd }) do
        local lip = State.scene:CreateChild("Hole")
        lip.position = Vector3(cx, 0.02, zOff)
        lip.scale = Vector3(lw * 1.05, 0.05, 0.25)
        local lm = lip:CreateComponent("StaticModel")
        lm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        lm:SetMaterial(grassMat)
        lm.castShadows = false
        table.insert(hole.nodes, lip)
    end

    -- 4) 崖壁边缘色条
    local edgeMat = Config.CreatePBRMaterial(vis.edgeColor, 0.0, 0.88)
    for side = -1, 1, 2 do
        local edge = State.scene:CreateChild("Hole")
        edge.position = Vector3(cx + side * lw * 0.5, 0.01, cz)
        edge.scale = Vector3(0.12, 0.06, holeLen)
        local em = edge:CreateComponent("StaticModel")
        em:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        em:SetMaterial(edgeMat)
        em.castShadows = false
        table.insert(hole.nodes, edge)
    end

    -- 5) 散落碎石
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

    local createdAny = false

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
        createdAny = true

        local interval = cfg.intervalMin + math.random() * (cfg.intervalMax - cfg.intervalMin)
        State.nextHoleZ = State.nextHoleZ + holeLen + interval
    end

    -- 如果本段有洞，拆分地面留出缺口
    if createdAny then
        PunchGround(segStartZ, segEndZ, biomeIdx)
    end
end

--- 检查 (z, lane) 是否在窟窿上
--- 判定范围比视觉缩小 HOLE_HITBOX_SHRINK（前后各收缩），降低掉坑难度
local HOLE_HITBOX_SHRINK = 1.2  -- 前后各缩 1.2 米

function Holes.IsOverHole(z, lane)
    for _, hole in ipairs(State.holes) do
        if z >= hole.zStart + HOLE_HITBOX_SHRINK and z <= hole.zEnd - HOLE_HITBOX_SHRINK then
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
