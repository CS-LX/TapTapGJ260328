-- ============================================================================
-- Game/World/Buildings.lua — 城市建筑系统（右侧商铺与住宅）
-- ============================================================================

local Config = require "Game.Config"
local State  = require "Game.State"
local Canyon = require "Game.World.Canyon"

local Buildings = {}

local CS = Config.CITY_SIDEWALK

-- ============================================================================
-- 创建单栋建筑（3种原型随机）
-- ============================================================================

---@param z number
---@return table
function Buildings.CreateBuilding(z)
    local archetype = math.random(1, 3)
    local buildingW, buildingH, buildingD, hasAwning

    if archetype == 1 then      -- 高公寓
        buildingW = 2.5 + math.random() * 1.0
        buildingH = 6.0 + math.random() * 4.0
        buildingD = 3.5 + math.random() * 1.5
        hasAwning = false
    elseif archetype == 2 then  -- 矮商铺（带遮阳篷）
        buildingW = 4.0 + math.random() * 2.0
        buildingH = 3.0 + math.random() * 1.5
        buildingD = 3.5 + math.random() * 2.0
        hasAwning = true
    else                        -- 中等住宅
        buildingW = 3.0 + math.random() * 1.5
        buildingH = 4.0 + math.random() * 2.0
        buildingD = 3.5 + math.random() * 1.5
        hasAwning = math.random() > 0.5
    end

    local buildingColor = CS.BUILDING_COLORS[math.random(1, #CS.BUILDING_COLORS)]

    local parentNode = State.scene:CreateChild("Building")
    -- 左边缘紧贴 BUILDING_X_BASE，中心偏移半宽
    local xPos = CS.BUILDING_X_BASE + buildingW / 2
    parentNode.position = Vector3(xPos, buildingH / 2, z)

    -- 主体
    local body = parentNode:CreateChild("Body")
    body.scale = Vector3(buildingW, buildingH, buildingD)
    local bm = body:CreateComponent("StaticModel")
    bm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    bm:SetMaterial(Config.CreatePBRMaterial(buildingColor, 0.0, 0.85))
    bm.castShadows = true

    -- 窗户行（深蓝色薄 Box，最多4行）
    local windowRows = math.floor(buildingH / 2.5)
    if windowRows > 0 then
        local windowColor = Color(0.20, 0.25, 0.35, 1.0)
        local windowMat = Config.CreatePBRMaterial(windowColor, 0.8, 0.15)
        for row = 1, math.min(windowRows, 4) do
            local wy = -buildingH / 2 + row * (buildingH / (windowRows + 1))
            local windowNode = parentNode:CreateChild("Window")
            windowNode.position = Vector3(0, wy, -buildingD / 2 + 0.01)
            windowNode.scale = Vector3(buildingW * 0.7, 0.6, 0.05)
            local wm = windowNode:CreateComponent("StaticModel")
            wm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
            wm:SetMaterial(windowMat)
            wm.castShadows = false
        end
    end

    -- 遮阳篷（倾斜彩色 Box）
    if hasAwning then
        local awningColor = CS.AWNING_COLORS[math.random(1, #CS.AWNING_COLORS)]
        local awning = parentNode:CreateChild("Awning")
        awning.position = Vector3(-buildingW / 2 - 0.4, -buildingH / 2 + 1.8, 0)
        awning.rotation = Quaternion(0, 0, -15)
        awning.scale = Vector3(1.2, 0.08, buildingD * 0.8)
        local am = awning:CreateComponent("StaticModel")
        am:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        am:SetMaterial(Config.CreatePBRMaterial(awningColor, 0.0, 0.7))
        am.castShadows = true
    end

    return {
        node  = parentNode,
        z     = z,
        depth = buildingD,
    }
end

-- ============================================================================
-- 前方生成（仅 City 场景）
-- ============================================================================

function Buildings.SpawnAhead(playerZ)
    if State.biomeIndex ~= 1 then return end
    if #State.buildings >= CS.MAX_ACTIVE_BUILDINGS then return end

    while State.nextBuildingZ < playerZ + CS.BUILDING_SPAWN_AHEAD do
        State.nextBuildingZ = Canyon.SkipCanyon(State.nextBuildingZ, 10)

        local building = Buildings.CreateBuilding(State.nextBuildingZ)
        table.insert(State.buildings, building)

        State.nextBuildingZ = State.nextBuildingZ + building.depth + CS.BUILDING_GAP

        if #State.buildings >= CS.MAX_ACTIVE_BUILDINGS then break end
    end
end

-- ============================================================================
-- 更新：生成 + 回收（建筑静止不动）
-- ============================================================================

function Buildings.Update(dt)
    if State.biomeIndex ~= 1 and #State.buildings == 0 then return end

    local playerZ = State.playerNode.position.z

    Buildings.SpawnAhead(playerZ)

    local toRemove = {}
    for i, b in ipairs(State.buildings) do
        if b.z + b.depth < playerZ - CS.BUILDING_DESPAWN_BEHIND then
            table.insert(toRemove, i)
        end
    end
    for i = #toRemove, 1, -1 do
        local idx = toRemove[i]
        State.buildings[idx].node:Remove()
        table.remove(State.buildings, idx)
    end
end

-- ============================================================================
-- 全部清理
-- ============================================================================

function Buildings.ClearAll()
    for _, b in ipairs(State.buildings) do
        if b.node then b.node:Remove() end
    end
    State.buildings = {}
    State.nextBuildingZ = 5.0
end

return Buildings
