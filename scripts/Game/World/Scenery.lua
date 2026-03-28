-- ============================================================================
-- Game/World/Scenery.lua — 统一侧边装饰系统（增强版：精细模型 + 双层生成）
-- ============================================================================

local Config = require "Game.Config"
local State  = require "Game.State"
local Canyon = require "Game.World.Canyon"

local Scenery = {}

local SC = Config.SCENERY

-- ============================================================================
-- 工具函数
-- ============================================================================

local function AddModel(parent, name, pos, scale, rot, modelPath, material)
    local node = parent:CreateChild(name)
    node.position = pos
    node.scale = scale
    if rot then node.rotation = rot end
    local m = node:CreateComponent("StaticModel")
    m:SetModel(cache:GetResource("Model", modelPath))
    m:SetMaterial(material)
    m.castShadows = true
    return node
end

local function RandColor(colors)
    return colors[math.random(1, #colors)]
end

-- ============================================================================
-- Savanna 装饰：金合欢树 / 棱角岩石 / 茂密高草
-- ============================================================================

local function CreateSavannaAcacia(parentNode, colors)
    -- 多层金合欢树：粗树干 + 2 层错开扁平树冠 + 1-2 根分叉枝
    local trunkH = 2.5 + math.random() * 2.5
    local trunkR = 0.15 + math.random() * 0.15

    -- 主树干（底部略粗 → 用 Cone 倒置模拟锥形）
    AddModel(parentNode, "Trunk", Vector3(0, trunkH / 2, 0),
        Vector3(trunkR * 2, trunkH, trunkR * 2), nil,
        "Models/Cylinder.mdl",
        Config.CreatePBRMaterial(colors.TRUNK_COLOR, 0.0, 0.9))

    -- 底部树根加粗
    AddModel(parentNode, "TrunkBase", Vector3(0, 0.3, 0),
        Vector3(trunkR * 3.5, 0.6, trunkR * 3.5), nil,
        "Models/Cone.mdl",
        Config.CreatePBRMaterial(colors.TRUNK_DARK, 0.0, 0.92))

    -- 主树冠（大扁平 Sphere）
    local canopyR = 1.8 + math.random() * 1.5
    AddModel(parentNode, "Canopy1", Vector3(0, trunkH + 0.2, 0),
        Vector3(canopyR * 2, 0.7, canopyR * 2), nil,
        "Models/Sphere.mdl",
        Config.CreatePBRMaterial(colors.CANOPY_COLOR, 0.0, 0.85))

    -- 副树冠（偏移错开，稍小）
    local offX = (math.random() - 0.5) * canopyR * 0.6
    local offZ = (math.random() - 0.5) * canopyR * 0.6
    AddModel(parentNode, "Canopy2",
        Vector3(offX, trunkH + 0.5, offZ),
        Vector3(canopyR * 1.4, 0.5, canopyR * 1.4), nil,
        "Models/Sphere.mdl",
        Config.CreatePBRMaterial(colors.CANOPY_LIGHT, 0.0, 0.82))

    -- 分叉枝条（1-2 根倾斜的 Cylinder）
    local branches = math.random(1, 2)
    for b = 1, branches do
        local angle = math.random() * 360
        local tilt = 30 + math.random() * 25
        local branchH = 1.0 + math.random() * 0.8
        AddModel(parentNode, "Branch",
            Vector3(0, trunkH * 0.6, 0),
            Vector3(0.08, branchH, 0.08),
            Quaternion(tilt, angle, 0),
            "Models/Cylinder.mdl",
            Config.CreatePBRMaterial(colors.TRUNK_COLOR, 0.0, 0.9))
    end
end

local function CreateSavannaRocks(parentNode, colors)
    -- 棱角岩石群：4-6 个旋转 Box 堆叠
    local count = math.random(4, 6)
    for j = 1, count do
        local sx = 0.4 + math.random() * 0.9
        local sy = 0.3 + math.random() * 0.7
        local sz = 0.4 + math.random() * 0.7
        AddModel(parentNode, "Rock",
            Vector3(
                (math.random() - 0.5) * 2.0,
                sy * 0.35,
                (math.random() - 0.5) * 2.0
            ),
            Vector3(sx, sy, sz),
            Quaternion(math.random() * 25, math.random() * 360, math.random() * 20),
            "Models/Box.mdl",
            Config.CreatePBRMaterial(RandColor(colors.ROCK_COLORS), 0.0, 0.93))
    end
end

local function CreateSavannaGrass(parentNode, colors)
    -- 茂密高草丛：6-10 根不同高度和倾斜
    local count = math.random(6, 10)
    for j = 1, count do
        local h = 0.5 + math.random() * 1.8
        local grassColor = RandColor(colors.GRASS_COLORS)
        AddModel(parentNode, "Grass",
            Vector3(
                (math.random() - 0.5) * 1.8,
                h / 2,
                (math.random() - 0.5) * 1.8
            ),
            Vector3(0.05, h, 0.05),
            Quaternion(0, math.random() * 360, (math.random() - 0.5) * 20),
            "Models/Box.mdl",
            Config.CreatePBRMaterial(grassColor, 0.0, 0.88))
    end
end

local function CreateSavannaDecor(z, sideX)
    local colors = SC.SAVANNA
    local parentNode = State.scene:CreateChild("Scenery")
    parentNode.position = Vector3(sideX, 0, z)

    local roll = math.random()
    if roll < 0.45 then
        CreateSavannaAcacia(parentNode, colors)
    elseif roll < 0.72 then
        CreateSavannaRocks(parentNode, colors)
    else
        CreateSavannaGrass(parentNode, colors)
    end

    return parentNode
end

-- ============================================================================
-- Glacier 装饰：复合冰山 / 多层雪堆 / 冰锥群
-- ============================================================================

local function CreateGlacierIceberg(parentNode, colors)
    -- 复合冰山：大底座 Box + 中间旋转 Box + 顶部 Cone，带 emissive
    local baseW = 1.0 + math.random() * 1.5
    local baseH = 1.5 + math.random() * 2.5
    local baseD = 0.8 + math.random() * 1.2

    -- 底座
    local baseMat = Config.CreatePBRMaterial(RandColor(colors.ICE_COLORS), 0.2, 0.12)
    baseMat:SetShaderParameter("MatEmissiveColor", Variant(colors.ICE_EMISSIVE))
    AddModel(parentNode, "IceBase",
        Vector3(0, baseH / 2, 0),
        Vector3(baseW, baseH, baseD), nil,
        "Models/Box.mdl", baseMat)

    -- 中间层（旋转 45° 的 Box）
    local midH = 0.8 + math.random() * 1.5
    local midW = baseW * 0.7
    AddModel(parentNode, "IceMid",
        Vector3(0, baseH + midH * 0.3, 0),
        Vector3(midW, midH, midW * 0.8),
        Quaternion(0, 45, 0),
        "Models/Box.mdl",
        Config.CreatePBRMaterial(RandColor(colors.ICE_COLORS), 0.25, 0.1))

    -- 顶部尖 Cone
    local topH = 1.0 + math.random() * 1.5
    AddModel(parentNode, "IceTop",
        Vector3(0, baseH + midH * 0.5 + topH * 0.3, 0),
        Vector3(midW * 0.6, topH, midW * 0.6),
        Quaternion(0, math.random() * 360, (math.random() - 0.5) * 10),
        "Models/Cone.mdl",
        Config.CreatePBRMaterial(colors.SNOW_COLOR, 0.0, 0.15))

    -- 整体微倾斜
    parentNode.rotation = Quaternion(0, math.random() * 360, (math.random() - 0.5) * 12)
end

local function CreateGlacierSnowPile(parentNode, colors)
    -- 多层雪堆：2-3 个重叠扁平 Sphere
    local layers = math.random(2, 3)
    local baseR = 1.2 + math.random() * 1.5
    for k = 1, layers do
        local r = baseR * (1.0 - (k - 1) * 0.3)
        local h = r * 0.4
        local yOffset = (k - 1) * h * 0.5
        AddModel(parentNode, "SnowLayer",
            Vector3((math.random() - 0.5) * 0.5, yOffset + h * 0.25, (math.random() - 0.5) * 0.5),
            Vector3(r * 2, h, r * 1.8), nil,
            "Models/Sphere.mdl",
            Config.CreatePBRMaterial(
                k == 1 and colors.SNOW_SHADOW or colors.SNOW_COLOR,
                0.0, 0.8))
    end
end

local function CreateGlacierIceShards(parentNode, colors)
    -- 冰锥群：4-6 个 Cone + 底座小 Box 碎片
    local count = math.random(4, 6)
    for j = 1, count do
        local h = 0.5 + math.random() * 2.5
        local r = 0.15 + math.random() * 0.25
        local iceColor = RandColor(colors.ICE_COLORS)
        local mat = Config.CreatePBRMaterial(iceColor, 0.3, 0.08)
        mat:SetShaderParameter("MatEmissiveColor", Variant(colors.ICE_EMISSIVE))

        AddModel(parentNode, "IceShard",
            Vector3(
                (math.random() - 0.5) * 2.0,
                h / 2,
                (math.random() - 0.5) * 1.5
            ),
            Vector3(r * 2, h, r * 2),
            Quaternion(0, math.random() * 360, (math.random() - 0.5) * 15),
            "Models/Cone.mdl", mat)
    end
    -- 底座碎片（2-3 个小 Box）
    for j = 1, math.random(2, 3) do
        local s = 0.15 + math.random() * 0.3
        AddModel(parentNode, "IceChip",
            Vector3(
                (math.random() - 0.5) * 2.5,
                s * 0.3,
                (math.random() - 0.5) * 2.0
            ),
            Vector3(s, s * 0.5, s * 0.8),
            Quaternion(math.random() * 30, math.random() * 360, math.random() * 30),
            "Models/Box.mdl",
            Config.CreatePBRMaterial(RandColor(colors.ICE_COLORS), 0.2, 0.15))
    end
end

local function CreateGlacierDecor(z, sideX)
    local colors = SC.GLACIER
    local parentNode = State.scene:CreateChild("Scenery")
    parentNode.position = Vector3(sideX, 0, z)

    local roll = math.random()
    if roll < 0.4 then
        CreateGlacierIceberg(parentNode, colors)
    elseif roll < 0.7 then
        CreateGlacierSnowPile(parentNode, colors)
    else
        CreateGlacierIceShards(parentNode, colors)
    end

    return parentNode
end

-- ============================================================================
-- Cliffs 装饰：精细松树 / 密集树丛 / 堆叠岩石 / 灌木群
-- ============================================================================

local function CreateSinglePineTree(parent, pos, colors, scaleFactor)
    scaleFactor = scaleFactor or 1.0
    local treeNode = parent:CreateChild("PineTree")
    treeNode.position = pos

    -- 粗树干
    local trunkH = (1.5 + math.random() * 1.2) * scaleFactor
    AddModel(treeNode, "Trunk",
        Vector3(0, trunkH / 2, 0),
        Vector3(0.2 * scaleFactor, trunkH, 0.2 * scaleFactor), nil,
        "Models/Cylinder.mdl",
        Config.CreatePBRMaterial(colors.PINE_TRUNK_COLOR, 0.0, 0.9))

    -- 3-4 层 Cone 针叶（从大到小）
    local layers = math.random(3, 4)
    for k = 1, layers do
        local coneR = (1.3 - k * 0.22) * scaleFactor
        local coneH = (1.0 + math.random() * 0.4) * scaleFactor
        local needleColor = k <= 2 and colors.PINE_DARK_COLOR or colors.PINE_NEEDLE_COLOR
        AddModel(treeNode, "PineLayer",
            Vector3(0, trunkH + (k - 1) * coneH * 0.55, 0),
            Vector3(coneR * 2, coneH, coneR * 2), nil,
            "Models/Cone.mdl",
            Config.CreatePBRMaterial(needleColor, 0.0, 0.85))
    end

    return treeNode
end

local function CreateCliffsTreeCluster(parentNode, colors)
    -- 密集树丛：3-5 棵松树紧密排列
    local count = math.random(3, 5)
    for i = 1, count do
        local scale = 0.7 + math.random() * 0.6
        CreateSinglePineTree(parentNode,
            Vector3(
                (math.random() - 0.5) * 3.0,
                0,
                (math.random() - 0.5) * 3.0
            ),
            colors, scale)
    end
end

local function CreateCliffsRockPile(parentNode, colors)
    -- 堆叠岩石：4-7 个旋转 Box（棱角感）
    local count = math.random(4, 7)
    local baseY = 0
    for j = 1, count do
        local sx = 0.5 + math.random() * 1.2
        local sy = 0.4 + math.random() * 0.9
        local sz = 0.5 + math.random() * 0.9

        -- 底层岩石大，上层小
        if j > 2 then
            sx = sx * 0.7
            sy = sy * 0.6
            sz = sz * 0.7
        end

        local yPos = baseY + sy * 0.35
        AddModel(parentNode, "Rock",
            Vector3(
                (math.random() - 0.5) * 2.5,
                yPos,
                (math.random() - 0.5) * 2.0
            ),
            Vector3(sx, sy, sz),
            Quaternion(math.random() * 30, math.random() * 360, math.random() * 25),
            "Models/Box.mdl",
            Config.CreatePBRMaterial(RandColor(colors.ROCK_COLORS), 0.0, 0.90))

        if j <= 2 then baseY = baseY + sy * 0.3 end
    end
end

local function CreateCliffsBushCluster(parentNode, colors)
    -- 灌木群：3-5 个紧密球体
    local count = math.random(3, 5)
    for j = 1, count do
        local s = 0.5 + math.random() * 0.7
        local bushColor = RandColor(colors.BUSH_COLORS)
        AddModel(parentNode, "Bush",
            Vector3(
                (math.random() - 0.5) * 2.0,
                s * 0.35,
                (math.random() - 0.5) * 1.5
            ),
            Vector3(s, s * 0.7, s * 0.9), nil,
            "Models/Sphere.mdl",
            Config.CreatePBRMaterial(bushColor, 0.0, 0.86))
    end
end

local function CreateCliffsDecor(z, sideX)
    local colors = SC.CLIFFS
    local parentNode = State.scene:CreateChild("Scenery")
    parentNode.position = Vector3(sideX, 0, z)

    local roll = math.random()
    if roll < 0.35 then
        -- 单棵精细松树
        CreateSinglePineTree(parentNode, Vector3(0, 0, 0), colors)
    elseif roll < 0.55 then
        -- 密集树丛
        CreateCliffsTreeCluster(parentNode, colors)
    elseif roll < 0.78 then
        -- 堆叠岩石
        CreateCliffsRockPile(parentNode, colors)
    else
        -- 灌木群
        CreateCliffsBushCluster(parentNode, colors)
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
-- 前方生成（双层：近层 + 远层）
-- ============================================================================

function Scenery.SpawnAhead(playerZ)
    if #State.sceneryItems >= SC.MAX_ACTIVE then return end

    local halfTrack = Config.TRACK_WIDTH / 2

    while State.nextSceneryZ < playerZ + SC.SPAWN_AHEAD do
        State.nextSceneryZ = Canyon.SkipCanyon(State.nextSceneryZ, 10)

        -- 近层（紧贴轨道边，6-10m）
        for side = -1, 1, 2 do
            local nearX = side * (halfTrack + 1.5 + math.random() * 3.5)
            local nodeNear = Scenery.CreateDecoration(
                State.nextSceneryZ + (math.random() - 0.5) * 3,
                nearX)
            if nodeNear then
                table.insert(State.sceneryItems, { node = nodeNear, z = State.nextSceneryZ })
            end
        end

        -- 远层（12-22m，更大更稀疏）
        if math.random() > 0.3 then
            for side = -1, 1, 2 do
                local farX = side * (halfTrack + 8.0 + math.random() * 12.0)
                local nodeFar = Scenery.CreateDecoration(
                    State.nextSceneryZ + (math.random() - 0.5) * 6,
                    farX)
                if nodeFar then
                    -- 远层装饰放大 1.2-1.8 倍
                    local scaleMul = 1.2 + math.random() * 0.6
                    local curScale = nodeFar.scale
                    nodeFar.scale = Vector3(curScale.x * scaleMul, curScale.y * scaleMul, curScale.z * scaleMul)
                    table.insert(State.sceneryItems, { node = nodeFar, z = State.nextSceneryZ })
                end
            end
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
