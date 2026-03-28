-- ============================================================================
-- Game/World/Scenery.lua — 统一侧边装饰系统（替代 Traffic + Buildings）
-- ============================================================================

local Config = require "Game.Config"
local State  = require "Game.State"
local Canyon = require "Game.World.Canyon"

local Scenery = {}

local SC = Config.SCENERY

-- ============================================================================
-- Savanna 装饰：金合欢树 / 岩石群 / 高草
-- ============================================================================

local function CreateSavannaDecor(z, sideX)
    local colors = SC.SAVANNA
    local parentNode = State.scene:CreateChild("Scenery")
    parentNode.position = Vector3(sideX, 0, z)

    local roll = math.random()

    if roll < 0.4 then
        -- 金合欢树：圆柱树干 + 扁平球冠
        local trunk = parentNode:CreateChild("Trunk")
        local trunkH = 2.5 + math.random() * 2.0
        trunk.position = Vector3(0, trunkH / 2, 0)
        trunk.scale = Vector3(0.3, trunkH, 0.3)
        local tm = trunk:CreateComponent("StaticModel")
        tm:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
        tm:SetMaterial(Config.CreatePBRMaterial(colors.TRUNK_COLOR, 0.0, 0.9))
        tm.castShadows = true

        local canopy = parentNode:CreateChild("Canopy")
        local canopyR = 1.5 + math.random() * 1.5
        canopy.position = Vector3(0, trunkH + 0.3, 0)
        canopy.scale = Vector3(canopyR * 2, 0.8, canopyR * 2)
        local cm = canopy:CreateComponent("StaticModel")
        cm:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        cm:SetMaterial(Config.CreatePBRMaterial(colors.CANOPY_COLOR, 0.0, 0.85))
        cm.castShadows = true

    elseif roll < 0.7 then
        -- 岩石群：2-3 个不同大小的球
        local count = math.random(2, 3)
        for j = 1, count do
            local rock = parentNode:CreateChild("Rock")
            local s = 0.4 + math.random() * 0.8
            rock.position = Vector3(
                (math.random() - 0.5) * 1.5,
                s * 0.4,
                (math.random() - 0.5) * 1.5
            )
            rock.scale = Vector3(s, s * 0.7, s)
            local rm = rock:CreateComponent("StaticModel")
            rm:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
            local rockColor = colors.ROCK_COLORS[math.random(1, #colors.ROCK_COLORS)]
            rm:SetMaterial(Config.CreatePBRMaterial(rockColor, 0.0, 0.95))
            rm.castShadows = true
        end

    else
        -- 高草丛：3-5 根细长 Box
        local count = math.random(3, 5)
        for j = 1, count do
            local grass = parentNode:CreateChild("Grass")
            local h = 0.8 + math.random() * 1.0
            grass.position = Vector3(
                (math.random() - 0.5) * 1.2,
                h / 2,
                (math.random() - 0.5) * 1.2
            )
            grass.rotation = Quaternion(0, math.random() * 360, (math.random() - 0.5) * 15)
            grass.scale = Vector3(0.06, h, 0.06)
            local gm = grass:CreateComponent("StaticModel")
            gm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
            gm:SetMaterial(Config.CreatePBRMaterial(colors.GRASS_COLOR, 0.0, 0.9))
            gm.castShadows = false
        end
    end

    return parentNode
end

-- ============================================================================
-- Glacier 装饰：冰柱 / 雪丘 / 冰锥
-- ============================================================================

local function CreateGlacierDecor(z, sideX)
    local colors = SC.GLACIER
    local parentNode = State.scene:CreateChild("Scenery")
    parentNode.position = Vector3(sideX, 0, z)

    local roll = math.random()

    if roll < 0.4 then
        -- 冰柱：高 Box
        local pillar = parentNode:CreateChild("IcePillar")
        local h = 2.0 + math.random() * 3.0
        local w = 0.4 + math.random() * 0.5
        pillar.position = Vector3(0, h / 2, 0)
        pillar.scale = Vector3(w, h, w * 0.8)
        local pm = pillar:CreateComponent("StaticModel")
        pm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        local iceColor = colors.ICE_COLORS[math.random(1, #colors.ICE_COLORS)]
        pm:SetMaterial(Config.CreatePBRMaterial(iceColor, 0.2, 0.15))
        pm.castShadows = true

    elseif roll < 0.7 then
        -- 雪丘：扁平球
        local mound = parentNode:CreateChild("SnowMound")
        local r = 1.0 + math.random() * 1.5
        mound.position = Vector3(0, r * 0.25, 0)
        mound.scale = Vector3(r * 2, r * 0.5, r * 1.5)
        local mm = mound:CreateComponent("StaticModel")
        mm:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        mm:SetMaterial(Config.CreatePBRMaterial(colors.SNOW_COLOR, 0.0, 0.8))
        mm.castShadows = true

    else
        -- 冰锥群：2-3 个 Cone
        local count = math.random(2, 3)
        for j = 1, count do
            local shard = parentNode:CreateChild("IceShard")
            local h = 1.0 + math.random() * 1.5
            shard.position = Vector3(
                (math.random() - 0.5) * 1.5,
                h / 2,
                (math.random() - 0.5) * 1.0
            )
            shard.rotation = Quaternion(0, math.random() * 360, (math.random() - 0.5) * 20)
            shard.scale = Vector3(0.3, h, 0.3)
            local sm = shard:CreateComponent("StaticModel")
            sm:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
            local iceColor = colors.ICE_COLORS[math.random(1, #colors.ICE_COLORS)]
            sm:SetMaterial(Config.CreatePBRMaterial(iceColor, 0.3, 0.1))
            sm.castShadows = true
        end
    end

    return parentNode
end

-- ============================================================================
-- Cliffs 装饰：松树 / 岩石 / 灌木
-- ============================================================================

local function CreateCliffsDecor(z, sideX)
    local colors = SC.CLIFFS
    local parentNode = State.scene:CreateChild("Scenery")
    parentNode.position = Vector3(sideX, 0, z)

    local roll = math.random()

    if roll < 0.4 then
        -- 松树：圆柱树干 + 2-3 层叠 Cone 针叶
        local trunk = parentNode:CreateChild("Trunk")
        local trunkH = 1.5 + math.random() * 1.0
        trunk.position = Vector3(0, trunkH / 2, 0)
        trunk.scale = Vector3(0.2, trunkH, 0.2)
        local tm = trunk:CreateComponent("StaticModel")
        tm:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
        tm:SetMaterial(Config.CreatePBRMaterial(colors.PINE_TRUNK_COLOR, 0.0, 0.9))
        tm.castShadows = true

        local layers = math.random(2, 3)
        for k = 1, layers do
            local cone = parentNode:CreateChild("PineLayer")
            local coneR = (1.2 - k * 0.25)
            local coneH = 1.2 + math.random() * 0.5
            cone.position = Vector3(0, trunkH + (k - 1) * coneH * 0.6, 0)
            cone.scale = Vector3(coneR * 2, coneH, coneR * 2)
            local cm = cone:CreateComponent("StaticModel")
            cm:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
            cm:SetMaterial(Config.CreatePBRMaterial(colors.PINE_NEEDLE_COLOR, 0.0, 0.85))
            cm.castShadows = true
        end

    elseif roll < 0.7 then
        -- 岩石群
        local count = math.random(2, 4)
        for j = 1, count do
            local rock = parentNode:CreateChild("Rock")
            local sx = 0.5 + math.random() * 1.0
            local sy = 0.4 + math.random() * 0.8
            local sz = 0.5 + math.random() * 0.8
            rock.position = Vector3(
                (math.random() - 0.5) * 2.0,
                sy / 2,
                (math.random() - 0.5) * 1.5
            )
            rock.rotation = Quaternion(0, math.random() * 360, 0)
            rock.scale = Vector3(sx, sy, sz)
            local rm = rock:CreateComponent("StaticModel")
            rm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
            local rockColor = colors.ROCK_COLORS[math.random(1, #colors.ROCK_COLORS)]
            rm:SetMaterial(Config.CreatePBRMaterial(rockColor, 0.0, 0.92))
            rm.castShadows = true
        end

    else
        -- 灌木丛：2-3 个球
        local count = math.random(2, 3)
        for j = 1, count do
            local bush = parentNode:CreateChild("Bush")
            local s = 0.5 + math.random() * 0.6
            bush.position = Vector3(
                (math.random() - 0.5) * 1.5,
                s * 0.4,
                (math.random() - 0.5) * 1.0
            )
            bush.scale = Vector3(s, s * 0.7, s * 0.9)
            local bm = bush:CreateComponent("StaticModel")
            bm:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
            bm:SetMaterial(Config.CreatePBRMaterial(colors.BUSH_COLOR, 0.0, 0.88))
            bm.castShadows = true
        end
    end

    return parentNode
end

-- ============================================================================
-- 按场景派发创建
-- ============================================================================

local creators = {
    CreateSavannaDecor,
    CreateGlacierDecor,
    CreateCliffsDecor,
}

function Scenery.CreateDecoration(z, sideX)
    local fn = creators[State.biomeIndex]
    if fn then
        return fn(z, sideX)
    end
end

-- ============================================================================
-- 前方生成（双侧）
-- ============================================================================

function Scenery.SpawnAhead(playerZ)
    if #State.sceneryItems >= SC.MAX_ACTIVE then return end

    local halfTrack = Config.TRACK_WIDTH / 2

    while State.nextSceneryZ < playerZ + SC.SPAWN_AHEAD do
        State.nextSceneryZ = Canyon.SkipCanyon(State.nextSceneryZ, 10)

        -- 左侧
        local leftX = -(halfTrack + 1.5 + math.random() * 2.0)
        local nodeL = Scenery.CreateDecoration(State.nextSceneryZ, leftX)
        if nodeL then
            table.insert(State.sceneryItems, { node = nodeL, z = State.nextSceneryZ })
        end

        -- 右侧
        local rightX = halfTrack + 1.5 + math.random() * 2.0
        local nodeR = Scenery.CreateDecoration(State.nextSceneryZ + (math.random() - 0.5) * 4, rightX)
        if nodeR then
            table.insert(State.sceneryItems, { node = nodeR, z = State.nextSceneryZ })
        end

        State.nextSceneryZ = State.nextSceneryZ
            + SC.INTERVAL_MIN
            + math.random() * (SC.INTERVAL_MAX - SC.INTERVAL_MIN)

        if #State.sceneryItems >= SC.MAX_ACTIVE then break end
    end
end

-- ============================================================================
-- 更新：生成 + 回收
-- ============================================================================

function Scenery.Update(dt)
    local playerZ = State.playerNode.position.z

    Scenery.SpawnAhead(playerZ)

    local toRemove = {}
    for i, item in ipairs(State.sceneryItems) do
        if item.z < playerZ - SC.DESPAWN_BEHIND then
            table.insert(toRemove, i)
        end
    end
    for i = #toRemove, 1, -1 do
        local idx = toRemove[i]
        State.sceneryItems[idx].node:Remove()
        table.remove(State.sceneryItems, idx)
    end
end

-- ============================================================================
-- 全部清理
-- ============================================================================

function Scenery.ClearAll()
    for _, item in ipairs(State.sceneryItems) do
        if item.node then item.node:Remove() end
    end
    State.sceneryItems = {}
    State.nextSceneryZ = 10.0
end

return Scenery
