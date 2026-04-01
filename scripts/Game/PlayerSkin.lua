-- ============================================================================
-- Game/PlayerSkin.lua — 玩家皮肤模块（外观创建 + 动画）
-- ============================================================================

local Config = require "Game.Config"
local State  = require "Game.State"

local PlayerSkin = {}

-- ============================================================================
-- 皮肤定义（数据驱动，方便扩展）
-- ============================================================================

local SKINS = {
    steve = {
        parts = {
            -- 头部（方块）
            {
                name     = "Head",
                model    = "Models/Box.mdl",
                scale    = Vector3(0.5, 0.5, 0.5),
                offset   = Vector3(0, 1.85, 0),
                color    = Color(0.76, 0.60, 0.42, 1.0),
                metallic = 0.0,
                roughness = 0.75,
            },
            -- 躯干
            {
                name     = "Body",
                model    = "Models/Box.mdl",
                scale    = Vector3(0.5, 0.75, 0.25),
                offset   = Vector3(0, 1.225, 0),
                color    = Color(0.0, 0.67, 0.67, 1.0),
                metallic = 0.0,
                roughness = 0.7,
            },
            -- 左臂
            {
                name     = "LeftArm",
                model    = "Models/Box.mdl",
                scale    = Vector3(0.25, 0.75, 0.25),
                offset   = Vector3(-0.375, 1.225, 0),
                color    = Color(0.76, 0.60, 0.42, 1.0),
                metallic = 0.0,
                roughness = 0.75,
            },
            -- 右臂
            {
                name     = "RightArm",
                model    = "Models/Box.mdl",
                scale    = Vector3(0.25, 0.75, 0.25),
                offset   = Vector3(0.375, 1.225, 0),
                color    = Color(0.76, 0.60, 0.42, 1.0),
                metallic = 0.0,
                roughness = 0.75,
            },
            -- 左腿
            {
                name     = "LeftLeg",
                model    = "Models/Box.mdl",
                scale    = Vector3(0.25, 0.75, 0.25),
                offset   = Vector3(-0.125, 0.375, 0),
                color    = Color(0.0, 0.0, 0.82, 1.0),
                metallic = 0.0,
                roughness = 0.8,
            },
            -- 右腿
            {
                name     = "RightLeg",
                model    = "Models/Box.mdl",
                scale    = Vector3(0.25, 0.75, 0.25),
                offset   = Vector3(0.125, 0.375, 0),
                color    = Color(0.0, 0.0, 0.82, 1.0),
                metallic = 0.0,
                roughness = 0.8,
            },
        },
    },
}

-- 当前使用的皮肤名称
local currentSkin = "steve"

-- ============================================================================
-- 公共接口
-- ============================================================================

--- 获取当前皮肤名称
function PlayerSkin.GetCurrentSkin()
    return currentSkin
end

--- 设置皮肤（下次 Apply 时生效）
function PlayerSkin.SetSkin(skinName)
    if SKINS[skinName] then
        currentSkin = skinName
    else
        print("[PlayerSkin] Unknown skin: " .. tostring(skinName))
    end
end

--- 创建/重建角色外观
---@param playerNode Node
---@param skinName? string 可选，不传则使用当前皮肤
function PlayerSkin.Apply(playerNode, skinName)
    skinName = skinName or currentSkin
    local skin = SKINS[skinName]
    if not skin then
        print("[PlayerSkin] Skin not found: " .. tostring(skinName))
        return
    end
    currentSkin = skinName

    -- 移除旧部件
    PlayerSkin.RemoveParts(playerNode)

    -- 创建新部件
    for _, part in ipairs(skin.parts) do
        local node = playerNode:CreateChild(part.name)
        node.position = part.offset
        node.scale = part.scale
        local model = node:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", part.model))
        local mat = Material:new()
        mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
        mat:SetShaderParameter("MatDiffColor", Variant(part.color))
        mat:SetShaderParameter("Metallic", Variant(part.metallic or 0.0))
        mat:SetShaderParameter("Roughness", Variant(part.roughness or 0.5))
        model:SetMaterial(mat)
        model.castShadows = true
    end
end

--- 移除所有皮肤部件
function PlayerSkin.RemoveParts(playerNode)
    local skin = SKINS[currentSkin]
    if not skin then return end
    for _, part in ipairs(skin.parts) do
        local child = playerNode:GetChild(part.name)
        if child then child:Remove() end
    end
end

--- 获取当前皮肤的所有部件节点名
function PlayerSkin.GetPartNames()
    local skin = SKINS[currentSkin]
    if not skin then return {} end
    local names = {}
    for _, part in ipairs(skin.parts) do
        table.insert(names, part.name)
    end
    return names
end

--- 显示/隐藏所有部件
---@param playerNode Node
---@param visible boolean
function PlayerSkin.SetVisible(playerNode, visible)
    local skin = SKINS[currentSkin]
    if not skin then return end
    for _, part in ipairs(skin.parts) do
        local child = playerNode:GetChild(part.name)
        if child then child:SetEnabled(visible) end
    end
end

--- 每帧更新动画
---@param playerNode Node
---@param dt number
function PlayerSkin.UpdateVisual(playerNode, dt)
    local skin = SKINS[currentSkin]
    if not skin then return end

    local head     = playerNode:GetChild("Head")
    local body     = playerNode:GetChild("Body")
    local leftArm  = playerNode:GetChild("LeftArm")
    local rightArm = playerNode:GetChild("RightArm")
    local leftLeg  = playerNode:GetChild("LeftLeg")
    local rightLeg = playerNode:GetChild("RightLeg")

    if State.isSliding then
        -- ====== 滑铲姿态 ======
        -- 身体压低并前倾
        if body then
            body.position = Vector3(0, 0.3, 0.1)
            body.scale = Vector3(0.5, 0.5, 0.35)
            body.rotation = Quaternion(20, Vector3.RIGHT)  -- 前倾
        end
        -- 头部压低前伸
        if head then
            head.position = Vector3(0, 0.65, 0.3)
            head.scale = Vector3(0.45, 0.45, 0.45)
        end
        -- 手臂收拢到身体两侧
        if leftArm then
            leftArm.position = Vector3(-0.3, 0.3, 0.15)
            leftArm.scale = Vector3(0.2, 0.5, 0.2)
            leftArm.rotation = Quaternion(30, Vector3.RIGHT)
        end
        if rightArm then
            rightArm.position = Vector3(0.3, 0.3, 0.15)
            rightArm.scale = Vector3(0.2, 0.5, 0.2)
            rightArm.rotation = Quaternion(30, Vector3.RIGHT)
        end
        -- 腿部前伸
        if leftLeg then
            leftLeg.position = Vector3(-0.125, 0.15, 0.35)
            leftLeg.scale = Vector3(0.25, 0.3, 0.55)
            leftLeg.rotation = Quaternion(0, 0, 0)
        end
        if rightLeg then
            rightLeg.position = Vector3(0.125, 0.15, 0.35)
            rightLeg.scale = Vector3(0.25, 0.3, 0.55)
            rightLeg.rotation = Quaternion(0, 0, 0)
        end
    else
        -- ====== 正常站立/跑步 ======
        -- 躯干复位
        if body then
            body.position = Vector3(0, 1.225, 0)
            body.scale = Vector3(0.5, 0.75, 0.25)
            body.rotation = Quaternion(0, 0, 0)
        end
        -- 头部复位
        if head then
            head.position = Vector3(0, 1.85, 0)
            head.scale = Vector3(0.5, 0.5, 0.5)
        end

        -- 摆动动画（手臂和腿交叉摆动）
        State.playerRunAngle = State.playerRunAngle + dt * State.runSpeed * 0.8
        local swing = math.sin(State.playerRunAngle)
        local armSwing = swing * 0.35   -- 摆臂幅度
        local legSwing = swing * 0.30   -- 摆腿幅度

        -- 左臂：与右腿同相
        if leftArm then
            leftArm.position = Vector3(-0.375, 1.225, -armSwing * 0.5)
            leftArm.scale = Vector3(0.25, 0.75, 0.25)
            leftArm.rotation = Quaternion(armSwing * 45, Vector3.RIGHT)
        end
        -- 右臂：与左腿同相
        if rightArm then
            rightArm.position = Vector3(0.375, 1.225, armSwing * 0.5)
            rightArm.scale = Vector3(0.25, 0.75, 0.25)
            rightArm.rotation = Quaternion(-armSwing * 45, Vector3.RIGHT)
        end

        -- 左腿
        if leftLeg then
            leftLeg.position = Vector3(-0.125, 0.375, legSwing * 0.4)
            leftLeg.scale = Vector3(0.25, 0.75, 0.25)
            leftLeg.rotation = Quaternion(-legSwing * 40, Vector3.RIGHT)
        end
        -- 右腿
        if rightLeg then
            rightLeg.position = Vector3(0.125, 0.375, -legSwing * 0.4)
            rightLeg.scale = Vector3(0.25, 0.75, 0.25)
            rightLeg.rotation = Quaternion(legSwing * 40, Vector3.RIGHT)
        end
    end
end

return PlayerSkin
