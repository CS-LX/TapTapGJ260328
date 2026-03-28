-- ============================================================================
-- Game/World/Traffic.lua — 城市车流系统（左侧马路）
-- ============================================================================

local Config = require "Game.Config"
local State  = require "Game.State"
local Canyon = require "Game.World.Canyon"

local Traffic = {}

local CS = Config.CITY_SIDEWALK

-- ============================================================================
-- 创建单辆车（父节点 + 车身 + 车顶 + 4轮）
-- ============================================================================

---@param z number
---@param laneX number
---@return table
function Traffic.CreateCar(z, laneX)
    local color = CS.CAR_COLORS[math.random(1, #CS.CAR_COLORS)]

    local carNode = State.scene:CreateChild("TrafficCar")
    carNode.position = Vector3(laneX, 0.35, z)

    -- 车身（扁平 Box）
    local body = carNode:CreateChild("CarBody")
    body.scale = Vector3(1.8, 0.7, 4.0)
    local bodyModel = body:CreateComponent("StaticModel")
    bodyModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    bodyModel:SetMaterial(Config.CreatePBRMaterial(color, 0.6, 0.35))
    bodyModel.castShadows = true

    -- 车顶/车窗（深色 Box）
    local cabin = carNode:CreateChild("CarCabin")
    cabin.position = Vector3(0, 0.55, -0.3)
    cabin.scale = Vector3(1.5, 0.55, 2.0)
    local cabinModel = cabin:CreateComponent("StaticModel")
    cabinModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    local cabinColor = Color(color.r * 0.4, color.g * 0.4, color.b * 0.4, 1.0)
    cabinModel:SetMaterial(Config.CreatePBRMaterial(cabinColor, 0.7, 0.2))
    cabinModel.castShadows = true

    -- 4个车轮（黑色 Cylinder）
    local wheelMat = Config.CreatePBRMaterial(Color(0.1, 0.1, 0.1, 1.0), 0.1, 0.9)
    local wheelPositions = {
        Vector3(-0.85, -0.25, 1.2),
        Vector3( 0.85, -0.25, 1.2),
        Vector3(-0.85, -0.25, -1.2),
        Vector3( 0.85, -0.25, -1.2),
    }
    for _, wp in ipairs(wheelPositions) do
        local wheel = carNode:CreateChild("Wheel")
        wheel.position = wp
        wheel.rotation = Quaternion(0, 0, 90)
        wheel.scale = Vector3(0.3, 0.2, 0.3)
        local wm = wheel:CreateComponent("StaticModel")
        wm:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
        wm:SetMaterial(wheelMat)
        wm.castShadows = false
    end

    local speedMul = CS.CAR_SPEED_MIN + math.random() * (CS.CAR_SPEED_MAX - CS.CAR_SPEED_MIN)

    return {
        node     = carNode,
        z        = z,
        laneX    = laneX,
        speedMul = speedMul,
    }
end

-- ============================================================================
-- 前方生成（仅 City 场景）
-- ============================================================================

function Traffic.SpawnAhead(playerZ)
    if State.biomeIndex ~= 1 then return end
    if #State.trafficCars >= CS.MAX_ACTIVE_CARS then return end

    while State.nextCarZ < playerZ + CS.CAR_SPAWN_AHEAD do
        State.nextCarZ = Canyon.SkipCanyon(State.nextCarZ, 10)

        local laneX = CS.CAR_LANES[math.random(1, #CS.CAR_LANES)]
        local car = Traffic.CreateCar(State.nextCarZ, laneX)
        table.insert(State.trafficCars, car)

        State.nextCarZ = State.nextCarZ
            + CS.CAR_INTERVAL_MIN
            + math.random() * (CS.CAR_INTERVAL_MAX - CS.CAR_INTERVAL_MIN)

        if #State.trafficCars >= CS.MAX_ACTIVE_CARS then break end
    end
end

-- ============================================================================
-- 更新：移动车辆 + 回收
-- ============================================================================

function Traffic.Update(dt)
    if State.biomeIndex ~= 1 and #State.trafficCars == 0 then return end

    local playerZ = State.playerNode.position.z

    Traffic.SpawnAhead(playerZ)

    local toRemove = {}
    for i, car in ipairs(State.trafficCars) do
        local carSpeed = State.runSpeed * car.speedMul
        local pos = car.node.position
        pos.z = pos.z + carSpeed * dt
        car.node.position = pos
        car.z = pos.z

        if pos.z < playerZ - CS.CAR_DESPAWN_BEHIND then
            table.insert(toRemove, i)
        end
    end

    for i = #toRemove, 1, -1 do
        local idx = toRemove[i]
        State.trafficCars[idx].node:Remove()
        table.remove(State.trafficCars, idx)
    end
end

-- ============================================================================
-- 全部清理
-- ============================================================================

function Traffic.ClearAll()
    for _, car in ipairs(State.trafficCars) do
        if car.node then car.node:Remove() end
    end
    State.trafficCars = {}
    State.nextCarZ = 30.0
end

return Traffic
