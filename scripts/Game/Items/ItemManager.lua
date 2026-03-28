-- ============================================================================
-- Game/Items/ItemManager.lua — 道具注册中心
-- 新增道具只需创建模块文件并调用 Register，无需修改其他文件
-- ============================================================================

local ItemManager = {}

---@type table[]
local registry = {}

--- 注册一个道具模块（模块需提供 Update/Reset/ClearAll 方法）
function ItemManager.Register(item)
    table.insert(registry, item)
end

--- 更新所有道具
function ItemManager.UpdateAll(dt)
    for _, item in ipairs(registry) do
        item.Update(dt)
    end
end

--- 重置所有道具（开始新游戏时）
function ItemManager.ResetAll()
    for _, item in ipairs(registry) do
        item.Reset()
    end
end

--- 清理所有道具节点（重开游戏时）
function ItemManager.ClearAll()
    for _, item in ipairs(registry) do
        item.ClearAll()
    end
end

--- 绘制所有道具的 HUD（磁铁倒计时等）
function ItemManager.DrawHUD(vg, w, h)
    for _, item in ipairs(registry) do
        if item.DrawHUD then
            item.DrawHUD(vg, w, h)
        end
    end
end

return ItemManager
