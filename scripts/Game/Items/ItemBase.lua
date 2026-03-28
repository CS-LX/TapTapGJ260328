-- ============================================================================
-- Game/Items/ItemBase.lua — 道具公共工具（Billboard创建、浮动动效、收集动画）
-- ============================================================================

local ItemBase = {}

-- ============================================================================
-- 创建 Billboard 道具节点（贴图 + 点光源）
-- ============================================================================

---@param scene Scene
---@param pos Vector3
---@param config table { texture: string, lightColor: Color, size: number }
---@return Node
function ItemBase.CreateNode(scene, pos, config)
    local node = scene:CreateChild("Item")
    node.position = pos

    -- BillboardSet
    local bbSet = node:CreateComponent("BillboardSet")
    bbSet.numBillboards = 1
    bbSet.sorted = true
    bbSet.faceCameraMode = FC_ROTATE_XYZ

    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/DiffAlpha.xml"))
    mat:SetTexture(0, cache:GetResource("Texture2D", config.texture))
    mat:SetShaderParameter("MatDiffColor", Variant(Color(1.0, 1.0, 1.0, 1.0)))
    bbSet:SetMaterial(mat)

    local bb = bbSet:GetBillboard(0)
    bb.position = Vector3(0, 0, 0)
    bb.size = Vector2(config.size, config.size)
    bb.enabled = true
    bbSet:Commit()

    -- 点光源
    local lightNode = node:CreateChild("ItemLight")
    local light = lightNode:CreateComponent("Light")
    light.lightType = LIGHT_POINT
    light.range = 3.0
    light.color = config.lightColor
    light.brightness = 1.5
    light.castShadows = false

    return node
end

-- ============================================================================
-- 批量触发道具自主失效（dissolve 消失动画）
-- ============================================================================

--- 让列表中所有未收集、未失效的道具进入 dissolve 状态
function ItemBase.DissolveAll(items)
    for _, item in ipairs(items) do
        if item.node and not item.collected and not item.collecting and not item.dissolving then
            item.dissolving = true
            item.dissolveTimer = 0
            item.dissolveOriginY = item.node.position.y
        end
    end
end

-- ============================================================================
-- 更新道具列表（浮动、收集动画、失效动画、碰撞检测、回收）
-- ============================================================================

---@param items table[] 道具列表
---@param dt number 帧间隔
---@param playerX number 玩家X
---@param playerZ number 玩家Z
---@param config table { height: number, size: number, despawnDist: number }
---@param callbacks table { canCollect?: fun(item):boolean, onCollect: fun(item) }
function ItemBase.UpdateList(items, dt, playerX, playerZ, config, callbacks)
    local toRemove = {}

    for i, item in ipairs(items) do
        if item.node and not item.collected then
            if item.collecting then
                -- === 收集动画 ===
                item.collectTimer = item.collectTimer + dt
                local t = item.collectTimer / 0.5

                if t >= 1.0 then
                    item.collected = true
                    item.node:Remove()
                    item.node = nil
                else
                    local pos = item.node.position
                    pos.y = item.collectOriginY + t * 3.0
                    item.node.position = pos

                    -- 膨胀后消失
                    local s
                    if t < 0.3 then
                        s = config.size * (1.0 + t / 0.3 * 1.5)
                    else
                        s = config.size * 2.5 * (1.0 - (t - 0.3) / 0.7)
                    end
                    local bbSet = item.node:GetComponent("BillboardSet")
                    if bbSet then
                        local bb = bbSet:GetBillboard(0)
                        bb.size = Vector2(s, s)
                        bbSet:Commit()
                    end
                end
            elseif item.dissolving then
                -- === 失效消散动画 ===
                item.dissolveTimer = item.dissolveTimer + dt
                local duration = 0.6
                local t = item.dissolveTimer / duration  -- 0→1

                if t >= 1.0 then
                    item.collected = true
                    item.node:Remove()
                    item.node = nil
                else
                    -- 向上飘 + 缩小
                    local pos = item.node.position
                    pos.y = item.dissolveOriginY + t * 2.0
                    item.node.position = pos

                    local s = config.size * (1.0 - t * 0.8)
                    if s < 0.05 then s = 0.05 end
                    local bbSet = item.node:GetComponent("BillboardSet")
                    if bbSet then
                        local bb = bbSet:GetBillboard(0)
                        bb.size = Vector2(s, s)
                        bbSet:Commit()
                    end

                    -- 光源渐暗
                    local lightNode = item.node:GetChild("ItemLight")
                    if lightNode then
                        local light = lightNode:GetComponent("Light")
                        if light then
                            light.brightness = 1.5 * (1.0 - t)
                        end
                    end
                end
            else
                -- === 浮动动效 ===
                local elapsed = GetTime():GetElapsedTime()
                local phase = elapsed * 2.5 + item.z

                -- 上下浮动
                local pos = item.node.position
                pos.y = config.height + math.sin(phase) * 0.35
                item.node.position = pos

                -- 呼吸脉冲缩放
                local pulse = config.size + math.sin(elapsed * 4.0 + item.z) * 0.1
                local bbSet = item.node:GetComponent("BillboardSet")
                if bbSet then
                    local bb = bbSet:GetBillboard(0)
                    bb.size = Vector2(pulse, pulse)
                    bbSet:Commit()
                end

                -- 光源亮度脉冲
                local lightNode = item.node:GetChild("ItemLight")
                if lightNode then
                    local light = lightNode:GetComponent("Light")
                    if light then
                        light.brightness = 1.2 + math.sin(elapsed * 3.0 + item.z) * 0.6
                    end
                end

                -- === 碰撞检测 ===
                local itemPos = item.node.position
                local dz = math.abs(itemPos.z - playerZ)
                local dx = math.abs(itemPos.x - playerX)
                if dz < 1.0 and dx < 1.0 then
                    if not callbacks.canCollect or callbacks.canCollect(item) then
                        item.collecting = true
                        item.collectTimer = 0.0
                        item.collectOriginY = itemPos.y
                        callbacks.onCollect(item)
                    end
                end

                -- === 超出范围回收 ===
                if itemPos.z < playerZ - config.despawnDist then
                    table.insert(toRemove, i)
                end
            end
        elseif item.collected then
            table.insert(toRemove, i)
        end
    end

    -- 从后往前移除
    for i = #toRemove, 1, -1 do
        local idx = toRemove[i]
        local item = items[idx]
        if item.node then item.node:Remove() end
        table.remove(items, idx)
    end
end

-- ============================================================================
-- 清理道具节点列表
-- ============================================================================

function ItemBase.ClearItems(items)
    for _, item in ipairs(items) do
        if item.node then item.node:Remove() end
    end
end

return ItemBase
