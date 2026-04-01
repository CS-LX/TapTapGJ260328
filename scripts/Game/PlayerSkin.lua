-- ============================================================================
-- Game/PlayerSkin.lua — 玩家皮肤模块（从 JSON 加载配置，数据驱动外观 + 动画）
-- ============================================================================

local Config = require "Game.Config"
local State  = require "Game.State"

local PlayerSkin = {}

-- ============================================================================
-- 内部状态
-- ============================================================================

---@type table<string, table>  已加载的皮肤配置缓存 { skinName -> skinData }
local loadedSkins = {}
local currentSkin = "steve"

-- ============================================================================
-- JSON 加载
-- ============================================================================

--- 从资源文件加载皮肤 JSON
---@param skinName string 皮肤名称（对应 Skins/<skinName>.json）
---@return table|nil skinData 解析后的皮肤数据
local function LoadSkinJSON(skinName)
    if loadedSkins[skinName] then
        return loadedSkins[skinName]
    end

    local path = "Skins/" .. skinName .. ".json"
    local file = cache:GetFile(path)
    if not file then
        print("[PlayerSkin] Skin file not found: " .. path)
        return nil
    end

    local jsonStr = file:ReadString()
    file:Close()

    local ok, data = pcall(cjson.decode, jsonStr) ---@diagnostic disable-line: undefined-global
    if not ok then
        print("[PlayerSkin] JSON parse error for " .. path .. ": " .. tostring(data))
        return nil
    end

    loadedSkins[skinName] = data
    return data
end

-- ============================================================================
-- 工具函数：JSON 数组 → 引擎类型
-- ============================================================================

---@param arr number[] [x, y, z]
---@return Vector3
local function toVec3(arr)
    return Vector3(arr[1], arr[2], arr[3])
end

---@param arr number[] [r, g, b, a]
---@return Color
local function toColor(arr)
    return Color(arr[1], arr[2], arr[3], arr[4] or 1.0)
end

---@param arr number[] [pitch, yaw, roll]
---@return Quaternion
local function toRot(arr)
    if not arr then return Quaternion(0, 0, 0) end
    return Quaternion(arr[1], arr[2], arr[3])
end

-- ============================================================================
-- 公共接口
-- ============================================================================

--- 获取当前皮肤名称
function PlayerSkin.GetCurrentSkin()
    return currentSkin
end

--- 设置皮肤（下次 Apply 时生效）
function PlayerSkin.SetSkin(skinName)
    local data = LoadSkinJSON(skinName)
    if data then
        currentSkin = skinName
    else
        print("[PlayerSkin] Unknown skin: " .. tostring(skinName))
    end
end

--- 获取已加载的皮肤数据（供外部读取配置）
function PlayerSkin.GetSkinData(skinName)
    skinName = skinName or currentSkin
    return LoadSkinJSON(skinName)
end

--- 创建/重建角色外观
---@param playerNode Node
---@param skinName? string 可选，不传则使用当前皮肤
function PlayerSkin.Apply(playerNode, skinName)
    skinName = skinName or currentSkin
    local skin = LoadSkinJSON(skinName)
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
        node.position = toVec3(part.offset)
        node.scale = toVec3(part.scale)
        local model = node:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", part.model))
        local mat = Material:new()
        mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
        mat:SetShaderParameter("MatDiffColor", Variant(toColor(part.color)))
        mat:SetShaderParameter("Metallic", Variant(part.metallic or 0.0))
        mat:SetShaderParameter("Roughness", Variant(part.roughness or 0.5))
        model:SetMaterial(mat)
        model.castShadows = true
    end
end

--- 移除所有皮肤部件
function PlayerSkin.RemoveParts(playerNode)
    local skin = LoadSkinJSON(currentSkin)
    if not skin then return end
    for _, part in ipairs(skin.parts) do
        local child = playerNode:GetChild(part.name)
        if child then child:Remove() end
    end
end

--- 获取当前皮肤的所有部件节点名
function PlayerSkin.GetPartNames()
    local skin = LoadSkinJSON(currentSkin)
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
    local skin = LoadSkinJSON(currentSkin)
    if not skin then return end
    for _, part in ipairs(skin.parts) do
        local child = playerNode:GetChild(part.name)
        if child then child:SetEnabled(visible) end
    end
end

--- 每帧更新动画（从 JSON 配置读取姿态和动画参数）
---@param playerNode Node
---@param dt number
function PlayerSkin.UpdateVisual(playerNode, dt)
    local skin = LoadSkinJSON(currentSkin)
    if not skin then return end

    local poses = skin.poses
    local runAnim = skin.runAnim

    if State.isSliding then
        -- ====== 滑铲姿态：从 poses.slide 读取 ======
        local slidePose = poses and poses.slide
        if slidePose then
            for partName, pose in pairs(slidePose) do
                local child = playerNode:GetChild(partName)
                if child then
                    child.position = toVec3(pose.pos)
                    child.scale = toVec3(pose.scale)
                    child.rotation = toRot(pose.rot)
                end
            end
        end
    else
        -- ====== 正常站立/跑步：从 poses.idle + runAnim 读取 ======
        local idlePose = poses and poses.idle

        -- 先复位到 idle 姿态
        if idlePose then
            for partName, pose in pairs(idlePose) do
                local child = playerNode:GetChild(partName)
                if child then
                    child.position = toVec3(pose.pos)
                    child.scale = toVec3(pose.scale)
                    child.rotation = toRot(pose.rot)
                end
            end
        end

        -- 跑步摆动动画
        if runAnim then
            local speedFactor = runAnim.speedFactor or 0.8
            State.playerRunAngle = State.playerRunAngle + dt * State.runSpeed * speedFactor
            local swing = math.sin(State.playerRunAngle)
            local armAmp = runAnim.swingAmplitudeArm or 0.35
            local legAmp = runAnim.swingAmplitudeLeg or 0.30
            local armDeg = runAnim.armSwingDeg or 45
            local legDeg = runAnim.legSwingDeg or 40
            local armOff = runAnim.armSwingOffset or 0.5
            local legOff = runAnim.legSwingOffset or 0.4

            local armSwing = swing * armAmp
            local legSwing = swing * legAmp

            -- 左臂（与右腿同相）
            local leftArm = playerNode:GetChild("LeftArm")
            if leftArm and idlePose and idlePose.LeftArm then
                local base = idlePose.LeftArm.pos
                leftArm.position = Vector3(base[1], base[2], base[3] - armSwing * armOff)
                leftArm.rotation = Quaternion(armSwing * armDeg, Vector3.RIGHT)
            end

            -- 右臂（与左腿同相）
            local rightArm = playerNode:GetChild("RightArm")
            if rightArm and idlePose and idlePose.RightArm then
                local base = idlePose.RightArm.pos
                rightArm.position = Vector3(base[1], base[2], base[3] + armSwing * armOff)
                rightArm.rotation = Quaternion(-armSwing * armDeg, Vector3.RIGHT)
            end

            -- 左腿
            local leftLeg = playerNode:GetChild("LeftLeg")
            if leftLeg and idlePose and idlePose.LeftLeg then
                local base = idlePose.LeftLeg.pos
                leftLeg.position = Vector3(base[1], base[2], base[3] + legSwing * legOff)
                leftLeg.rotation = Quaternion(-legSwing * legDeg, Vector3.RIGHT)
            end

            -- 右腿
            local rightLeg = playerNode:GetChild("RightLeg")
            if rightLeg and idlePose and idlePose.RightLeg then
                local base = idlePose.RightLeg.pos
                rightLeg.position = Vector3(base[1], base[2], base[3] - legSwing * legOff)
                rightLeg.rotation = Quaternion(legSwing * legDeg, Vector3.RIGHT)
            end
        end
    end
end

return PlayerSkin
