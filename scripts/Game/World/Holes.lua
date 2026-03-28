-- ============================================================================
-- Game/World/Holes.lua — 地面窟窿系统
-- ============================================================================

local Config = require "Game.Config"
local State  = require "Game.State"

-- Canyon 模块用于 SkipCanyon
local Canyon = require "Game.World.Canyon"

local Holes = {}

--- 创建窟窿的视觉表现（暗色坑洞覆盖地面）
function Holes.CreateHoleVisual(hole)
    hole.nodes = {}
    for _, lane in ipairs(hole.lanes) do
        local holeLen = hole.zEnd - hole.zStart
        local cx = lane * Config.LANE_WIDTH
        local cz = (hole.zStart + hole.zEnd) / 2

        -- 主体：深色凹陷
        local node = State.scene:CreateChild("Hole")
        node.position = Vector3(cx, -0.05, cz)
        node.scale = Vector3(Config.LANE_WIDTH * 0.95, 0.2, holeLen)
        local model = node:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        local mat = Material:new()
        mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
        mat:SetShaderParameter("MatDiffColor", Variant(Color(0.02, 0.02, 0.05, 1.0)))
        mat:SetShaderParameter("Metallic", Variant(0.0))
        mat:SetShaderParameter("Roughness", Variant(1.0))
        model:SetMaterial(mat)
        model.castShadows = false
        table.insert(hole.nodes, node)

        -- 边缘发光条（前后两条）
        local edgeMat = Material:new()
        edgeMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
        edgeMat:SetShaderParameter("MatDiffColor", Variant(Color(1.0, 0.3, 0.1, 1.0)))
        edgeMat:SetShaderParameter("MatEmissiveColor", Variant(Color(1.0, 0.2, 0.0)))
        edgeMat:SetShaderParameter("Metallic", Variant(0.0))
        edgeMat:SetShaderParameter("Roughness", Variant(0.5))
        for _, zOff in ipairs({ hole.zStart, hole.zEnd }) do
            local edge = State.scene:CreateChild("Hole")
            edge.position = Vector3(cx, 0.02, zOff)
            edge.scale = Vector3(Config.LANE_WIDTH * 0.95, 0.05, 0.15)
            local em = edge:CreateComponent("StaticModel")
            em:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
            em:SetMaterial(edgeMat)
            em.castShadows = false
            table.insert(hole.nodes, edge)
        end
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
            zStart = State.nextHoleZ,
            zEnd   = State.nextHoleZ + holeLen,
            lanes  = lanes,
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
