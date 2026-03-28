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
Config.OBS_HIGH_BAR = 3   -- 高横杆：需要下蹲或跳跃（3颗心）
Config.OBS_OVERHEAD = 4   -- 低天花板：只能下蹲（2颗心）

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
Config.CANYON_LENGTH         = 40.0       -- 峡谷间隙宽度（米）
Config.CANYON_JUMP_VELOCITY  = 18.0       -- 峡谷自动跳跃速度（加强版）
Config.CANYON_TRIGGER_OFFSET = 2.0        -- 峡谷前多远触发自动跳跃
Config.CANYON_INPUT_LOCK     = 0.3        -- 自动跳跃时锁定变道（秒）
Config.CANYON_SPEED_BOOST    = 2.5        -- 峡谷飞行速度倍率

Config.BIOMES = {
    {   -- 城市人行道（淡黄橙色调）
        name   = "City",
        ground = Color(0.88, 0.78, 0.55, 1.0),   -- 淡黄橙色人行道
        lane   = Color(0.65, 0.61, 0.56, 1.0),   -- 低调的砖缝色
        wall   = Color(0.55, 0.4,  0.35, 1.0),
        fog    = Color(0.70, 0.75, 0.85),          -- 城市灰蓝雾
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

-- 地面窟窿配置（按场景索引）
Config.HOLE_CONFIGS = {
    -- City: 无窟窿
    { enabled = false },
    -- Desert: 小的单轨窟窿
    { enabled = true, minLen = 5, maxLen = 10, maxLanes = 1, intervalMin = 35, intervalMax = 55 },
    -- Neon: 长窟窿，可达2轨（只剩中间一条）
    { enabled = true, minLen = 10, maxLen = 18, maxLanes = 2, intervalMin = 25, intervalMax = 45 },
}

-- 死亡动画配置
Config.DEATH_DURATION = 1.5

-- ============================================================================
-- 城市人行道专属装饰配置
-- ============================================================================
Config.CITY_SIDEWALK = {
    -- 车流（左侧马路）
    CAR_LANES         = { -6.5, -8.5 },     -- 两条车道 X 坐标
    ROAD_WIDTH        = 5.0,                 -- 马路宽度
    CAR_SPEED_MIN     = 0.6,                 -- 车速 = 玩家速度 × 倍率
    CAR_SPEED_MAX     = 0.9,
    CAR_INTERVAL_MIN  = 8.0,                 -- 车间距（米）
    CAR_INTERVAL_MAX  = 16.0,
    CAR_SPAWN_AHEAD   = 120.0,              -- 前方生成距离
    CAR_DESPAWN_BEHIND = 30.0,              -- 后方回收距离
    MAX_ACTIVE_CARS   = 20,

    -- 建筑（右侧房屋/商铺）
    BUILDING_X_BASE    = 5.5,               -- 建筑左边缘紧贴右路缘
    BUILDING_GAP       = 0.8,               -- 建筑间距（米）
    BUILDING_SPAWN_AHEAD  = 120.0,
    BUILDING_DESPAWN_BEHIND = 30.0,
    MAX_ACTIVE_BUILDINGS = 30,

    -- 颜色库
    CAR_COLORS = {
        Color(0.85, 0.15, 0.15, 1.0),  -- 红
        Color(0.15, 0.45, 0.85, 1.0),  -- 蓝
        Color(0.95, 0.95, 0.90, 1.0),  -- 白
        Color(0.20, 0.20, 0.22, 1.0),  -- 黑
        Color(0.75, 0.75, 0.70, 1.0),  -- 银
        Color(0.90, 0.75, 0.20, 1.0),  -- 黄
    },
    BUILDING_COLORS = {
        Color(0.85, 0.82, 0.75, 1.0),  -- 米白
        Color(0.78, 0.72, 0.62, 1.0),  -- 暖灰
        Color(0.70, 0.60, 0.50, 1.0),  -- 棕灰
        Color(0.90, 0.85, 0.78, 1.0),  -- 奶白
        Color(0.65, 0.62, 0.58, 1.0),  -- 水泥灰
        Color(0.82, 0.70, 0.55, 1.0),  -- 土黄
    },
    AWNING_COLORS = {
        Color(0.85, 0.25, 0.20, 1.0),  -- 红
        Color(0.20, 0.55, 0.30, 1.0),  -- 绿
        Color(0.20, 0.35, 0.75, 1.0),  -- 蓝
        Color(0.90, 0.60, 0.15, 1.0),  -- 橙
    },

    -- 马路/路缘颜色
    ROAD_COLOR = Color(0.25, 0.25, 0.28, 1.0),  -- 柏油路
    CURB_COLOR = Color(0.70, 0.68, 0.65, 1.0),  -- 路缘石
}

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
