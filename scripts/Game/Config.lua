-- ============================================================================
-- Game/Config.lua — 游戏常量配置
-- ============================================================================

local Config = {}

-- 游戏状态枚举
Config.STATE_MENU     = 0
Config.STATE_PLAYING  = 1
Config.STATE_GAMEOVER = 2
Config.STATE_DYING    = 3

-- 障碍物类型
Config.OBS_BLOCK    = 1   -- 路障：需要左右躲避（1颗心）
Config.OBS_LOW_BAR  = 2   -- 低横杆：需要跳跃（2颗心）
Config.OBS_HIGH_BAR = 3   -- 高横杆：需要下蹲（3颗心）

-- 游戏配置
Config.LANE_WIDTH       = 2.5          -- 跑道间距（米）
Config.LANE_COUNT       = 3            -- 跑道数量（左/中/右）
Config.TRACK_LENGTH     = 200.0        -- 每段地面长度
Config.TRACK_WIDTH      = 10.0         -- 地面宽度

Config.START_SPEED      = 12.0         -- 初始速度（米/秒）
Config.MAX_SPEED        = 30.0         -- 最大速度
Config.SPEED_INCREASE   = 0.3          -- 每秒加速
Config.LANE_SWITCH_SPEED = 12.0        -- 切换跑道速度
Config.JUMP_VELOCITY    = 10.0         -- 跳跃初速度
Config.GRAVITY          = -25.0        -- 重力加速度
Config.SLIDE_DURATION   = 0.6          -- 下蹲持续时间
Config.PLAYER_HEIGHT    = 1.8          -- 玩家站立高度
Config.PLAYER_SLIDE_HEIGHT = 0.6       -- 下蹲高度

Config.OBSTACLE_INTERVAL = 15.0        -- 障碍物间隔（米）
Config.SPAWN_DISTANCE   = 120.0        -- 生成距离
Config.DESPAWN_DISTANCE = 20.0         -- 回收距离

Config.COIN_INTERVAL    = 5.0          -- 金币间隔
Config.COIN_HEIGHT      = 1.2          -- 金币高度
Config.COIN_RADIUS      = 0.3          -- 金币碰撞半径

Config.CAM_OFFSET       = Vector3(0, 6.0, -10.0)  -- 相机偏移
Config.CAM_LOOK_AHEAD   = 8.0          -- 相机前瞻

-- 血量配置
Config.MAX_HEALTH          = 3
Config.INVINCIBLE_DURATION = 1.5

-- 场景切换配置
Config.BIOME_SEGMENT_COUNT  = 3          -- 每场景地面段数（3 × 200m = 600m）
Config.CANYON_LENGTH         = 10.0       -- 峡谷间隙宽度（米）
Config.CANYON_JUMP_VELOCITY  = 14.0       -- 峡谷自动跳跃速度（加强版）
Config.CANYON_TRIGGER_OFFSET = 2.0        -- 峡谷前多远触发自动跳跃
Config.CANYON_INPUT_LOCK     = 0.3        -- 自动跳跃时锁定变道（秒）

Config.BIOMES = {
    {   -- 城市（默认灰色调）
        name   = "City",
        ground = Color(0.35, 0.35, 0.38, 1.0),
        lane   = Color(0.9,  0.9,  0.3,  1.0),
        wall   = Color(0.55, 0.4,  0.35, 1.0),
        fog    = Color(0.6,  0.75, 0.95),
    },
    {   -- 沙漠（暖沙色调）
        name   = "Desert",
        ground = Color(0.72, 0.55, 0.35, 1.0),
        lane   = Color(0.95, 0.95, 0.85, 1.0),
        wall   = Color(0.75, 0.35, 0.2,  1.0),
        fog    = Color(0.9,  0.8,  0.55),
    },
    {   -- 霓虹（暗紫色调）
        name   = "Neon",
        ground = Color(0.12, 0.12, 0.18, 1.0),
        lane   = Color(0.2,  0.9,  0.9,  1.0),
        wall   = Color(0.5,  0.2,  0.6,  1.0),
        fog    = Color(0.08, 0.06, 0.18),
    },
}

-- 死亡动画配置
Config.DEATH_DURATION = 1.5

-- 工具函数：创建 PBR 材质
function Config.CreatePBRMaterial(color, metallic, roughness)
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(color))
    mat:SetShaderParameter("Metallic", Variant(metallic or 0.0))
    mat:SetShaderParameter("Roughness", Variant(roughness or 0.5))
    return mat
end

return Config
