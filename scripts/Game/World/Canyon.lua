-- ============================================================================
-- Game/World/Canyon.lua — 峡谷工具函数
-- ============================================================================

local Config = require "Game.Config"
local State  = require "Game.State"

local Canyon = {}

--- 检查某个 Z 坐标是否在峡谷内
function Canyon.IsInCanyon(z)
    for _, canyon in ipairs(State.canyons) do
        if z >= canyon.startZ and z <= canyon.endZ then
            return true
        end
    end
    return false
end

--- 如果 z 落在峡谷（含缓冲区）内，跳过到峡谷后方；否则原样返回
--- @param z number
--- @param buffer number|nil 缓冲距离（默认5米，障碍物建议传30）
function Canyon.SkipCanyon(z, buffer)
    buffer = buffer or 5
    for _, canyon in ipairs(State.canyons) do
        if z >= canyon.startZ - buffer and z <= canyon.endZ + buffer then
            return canyon.endZ + buffer + 5
        end
    end
    return z
end

--- 获取最近的前方峡谷信息（用于自动跳跃检测）
function Canyon.GetNextCanyon(playerZ)
    local nearest = nil
    for _, canyon in ipairs(State.canyons) do
        if canyon.startZ > playerZ - 5 then
            if nearest == nil or canyon.startZ < nearest.startZ then
                nearest = canyon
            end
        end
    end
    return nearest
end

return Canyon
