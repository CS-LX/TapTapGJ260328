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
Config.OBS_ICEBERG  = 5   -- 冰山墙：只能换轨道（1颗心）

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
    {   -- 非洲大草原（金色草地）
        name   = "Savanna",
        ground = Color(0.78, 0.68, 0.38, 1.0),   -- 干燥金色草地
        lane   = Color(0.60, 0.50, 0.30, 1.0),   -- 磨损泥土小径
        wall   = Color(0.65, 0.50, 0.30, 1.0),   -- 土质路堤
        fog    = Color(0.85, 0.75, 0.50),          -- 暖黄地平线
    },
    {   -- 南极冰川（冰蓝白色）
        name   = "Glacier",
        ground = Color(0.82, 0.90, 0.95, 1.0),   -- 压实冰雪面
        lane   = Color(0.60, 0.75, 0.88, 1.0),   -- 冰沟纹路
        wall   = Color(0.55, 0.72, 0.85, 1.0),   -- 冰川壁
        fog    = Color(0.78, 0.85, 0.95),          -- 冷白蓝雾
    },
    {   -- 丘陵悬崖（绿棕色地貌）
        name   = "Cliffs",
        ground = Color(0.45, 0.55, 0.30, 1.0),   -- 草地泥土
        lane   = Color(0.60, 0.55, 0.40, 1.0),   -- 石径
        wall   = Color(0.50, 0.42, 0.32, 1.0),   -- 岩石崖壁
        fog    = Color(0.60, 0.70, 0.55),          -- 山谷绿雾
    },
}

-- 地面窟窿配置（按场景索引）
Config.HOLE_CONFIGS = {
    -- Savanna: 无窟窿（开阔草原）
    { enabled = false },
    -- Glacier: 冰裂缝（单车道）
    { enabled = true, minLen = 6, maxLen = 12, maxLanes = 1, intervalMin = 30, intervalMax = 50 },
    -- Cliffs: 悬崖边缘（可双车道）
    { enabled = true, minLen = 8, maxLen = 16, maxLanes = 2, intervalMin = 25, intervalMax = 45 },
}

-- 大运大货车配置
Config.DAYUN_SCORE_THRESHOLD  = 50000   -- 激活分数阈值
Config.DAYUN_DURATION         = 10.0    -- 持续时间（秒）
Config.DAYUN_INVINCIBLE_AFTER = 2.0     -- 失效后无敌缓冲（秒）

-- 死亡动画配置
Config.DEATH_DURATION = 1.5

-- ============================================================================
-- 侧边装饰配置（通用）
-- ============================================================================
Config.SCENERY = {
    SPAWN_AHEAD    = 120.0,
    DESPAWN_BEHIND = 30.0,
    MAX_ACTIVE     = 80,
    INTERVAL_MIN   = 4.0,
    INTERVAL_MAX   = 8.0,

    -- 侧边地形尺寸
    SIDE_TERRAIN_WIDTH = 30.0,    -- 每侧地形宽度（米）
    SIDE_TERRAIN_HILLS = 3,       -- 每段地形随机丘陵数量

    SAVANNA = {
        TERRAIN_COLOR = Color(0.75, 0.65, 0.35, 1.0),  -- 侧边草地（比跑道略深）
        HILL_COLOR    = Color(0.72, 0.62, 0.32, 1.0),  -- 丘陵色
        HILL_GRASS    = Color(0.55, 0.58, 0.25, 1.0),  -- 丘陵上的绿草
        TRUNK_COLOR   = Color(0.45, 0.30, 0.15, 1.0),  -- 树干
        TRUNK_DARK    = Color(0.35, 0.22, 0.10, 1.0),  -- 深色树干
        CANOPY_COLOR  = Color(0.35, 0.50, 0.20, 1.0),  -- 树冠
        CANOPY_LIGHT  = Color(0.45, 0.58, 0.25, 1.0),  -- 浅色树冠
        ROCK_COLORS   = {
            Color(0.60, 0.50, 0.35, 1.0),
            Color(0.55, 0.45, 0.30, 1.0),
            Color(0.50, 0.42, 0.32, 1.0),
            Color(0.58, 0.48, 0.33, 1.0),
        },
        GRASS_COLORS  = {
            Color(0.70, 0.65, 0.30, 1.0),
            Color(0.65, 0.60, 0.28, 1.0),
            Color(0.60, 0.55, 0.25, 1.0),
        },
    },
    GLACIER = {
        TERRAIN_COLOR = Color(0.85, 0.92, 0.97, 1.0),  -- 冰雪平原
        RIDGE_COLOR   = Color(0.70, 0.82, 0.92, 1.0),  -- 冰脊
        ICE_COLORS = {
            Color(0.70, 0.85, 0.95, 1.0),
            Color(0.55, 0.75, 0.90, 1.0),
            Color(0.80, 0.90, 0.97, 1.0),
            Color(0.60, 0.78, 0.92, 1.0),
        },
        ICE_EMISSIVE  = Color(0.08, 0.15, 0.30),       -- 冰体自发光
        SNOW_COLOR    = Color(0.92, 0.94, 0.96, 1.0),
        SNOW_SHADOW   = Color(0.78, 0.85, 0.92, 1.0),  -- 雪丘阴影面
    },
    CLIFFS = {
        TERRAIN_COLOR     = Color(0.42, 0.52, 0.28, 1.0),  -- 森林泥土
        HILL_COLOR        = Color(0.38, 0.45, 0.25, 1.0),  -- 丘陵
        HILL_ROCK         = Color(0.48, 0.42, 0.35, 1.0),  -- 丘陵岩石面
        PINE_TRUNK_COLOR  = Color(0.35, 0.22, 0.12, 1.0),
        PINE_NEEDLE_COLOR = Color(0.15, 0.40, 0.15, 1.0),
        PINE_DARK_COLOR   = Color(0.10, 0.30, 0.10, 1.0),  -- 深色针叶
        ROCK_COLORS = {
            Color(0.45, 0.40, 0.35, 1.0),
            Color(0.50, 0.45, 0.38, 1.0),
            Color(0.40, 0.38, 0.32, 1.0),
            Color(0.55, 0.48, 0.40, 1.0),
        },
        BUSH_COLORS = {
            Color(0.25, 0.50, 0.20, 1.0),
            Color(0.20, 0.45, 0.18, 1.0),
            Color(0.30, 0.55, 0.22, 1.0),
        },
    },
}

-- 窟窿视觉配置（按场景索引）
Config.HOLE_VISUALS = {
    { },  -- Savanna: 无窟窿
    {   -- Glacier: 冰裂缝
        bottomColor   = Color(0.03, 0.06, 0.15, 1.0),
        wallColor     = Color(0.40, 0.65, 0.85, 1.0),
        wallEmissive  = Color(0.10, 0.20, 0.40),
        edgeColor     = Color(0.70, 0.85, 0.95, 1.0),
        edgeEmissive  = Color(0.15, 0.30, 0.50),
        fragmentColor = Color(0.75, 0.88, 0.95, 1.0),
    },
    {   -- Cliffs: 悬崖边缘
        bottomColor   = Color(0.05, 0.05, 0.03, 1.0),
        wallColor     = Color(0.45, 0.38, 0.28, 1.0),
        edgeColor     = Color(0.55, 0.45, 0.30, 1.0),
        fragmentColor = Color(0.50, 0.42, 0.30, 1.0),
        grassColor    = Color(0.40, 0.55, 0.25, 1.0),
    },
}

-- ============================================================================
-- 障碍物视觉配置（按场景索引）
-- ============================================================================
Config.OBSTACLE_VISUALS = {
    { -- 1. Savanna: 大蓝象贴图障碍
        block    = { color = Color(0.72, 0.45, 0.22, 1.0), m = 0.0, r = 0.80 },
        blockAcc = { color = Color(0.55, 0.38, 0.15, 1.0), m = 0.0, r = 0.85 },
        blockTexture = "image/elephant.png",   -- Billboard 贴图
        blockTextureAspect = 798 / 1112,       -- 宽高比
        lowBar   = { color = Color(0.58, 0.38, 0.18, 1.0), m = 0.0, r = 0.82 },
        highBar  = { color = Color(0.52, 0.42, 0.18, 1.0), m = 0.0, r = 0.78 },
        overhead = { color = Color(0.62, 0.45, 0.25, 1.0), m = 0.0, r = 0.88 },
        pillar   = { color = Color(0.48, 0.35, 0.20, 1.0), m = 0.0, r = 0.85 },
        oPillar  = { color = Color(0.55, 0.40, 0.22, 1.0), m = 0.0, r = 0.85 },
    },
    { -- 2. Glacier: 企鹅贴图障碍
        block    = { color = Color(0.50, 0.72, 0.90, 1.0), m = 0.30, r = 0.15,
                     emissive = Color(0.05, 0.12, 0.25) },
        blockAcc = { color = Color(0.65, 0.82, 0.95, 1.0), m = 0.40, r = 0.10,
                     emissive = Color(0.08, 0.18, 0.35) },
        blockTexture = "image/gugugaga.png",   -- Billboard 贴图
        blockTextureAspect = 366 / 671,        -- 宽高比
        lowBar   = { color = Color(0.48, 0.68, 0.88, 1.0), m = 0.25, r = 0.20,
                     emissive = Color(0.03, 0.08, 0.18) },
        highBar  = { color = Color(0.55, 0.75, 0.92, 1.0), m = 0.20, r = 0.18 },
        overhead = { color = Color(0.42, 0.62, 0.82, 1.0), m = 0.30, r = 0.20,
                     emissive = Color(0.04, 0.10, 0.22) },
        pillar   = { color = Color(0.65, 0.82, 0.95, 1.0), m = 0.35, r = 0.12 },
        oPillar  = { color = Color(0.55, 0.72, 0.88, 1.0), m = 0.30, r = 0.15 },
    },
    { -- 3. Cliffs: 熊大贴图障碍
        block    = { color = Color(0.52, 0.48, 0.40, 1.0), m = 0.0, r = 0.90 },
        blockAcc = { color = Color(0.28, 0.48, 0.20, 1.0), m = 0.0, r = 0.85 },
        blockTexture = "image/bear.png",       -- Billboard 贴图
        blockTextureAspect = 538 / 972,        -- 宽高比
        lowBar   = { color = Color(0.42, 0.30, 0.18, 1.0), m = 0.0, r = 0.86 },
        highBar  = { color = Color(0.50, 0.45, 0.38, 1.0), m = 0.0, r = 0.88 },
        overhead = { color = Color(0.45, 0.40, 0.35, 1.0), m = 0.0, r = 0.92 },
        pillar   = { color = Color(0.55, 0.50, 0.42, 1.0), m = 0.0, r = 0.88 },
        oPillar  = { color = Color(0.50, 0.45, 0.38, 1.0), m = 0.0, r = 0.88 },
    },
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

--- 从 OBSTACLE_VISUALS 的条目创建 PBR 材质（支持 emissive）
function Config.CreateObsMaterial(vis)
    local mat = Config.CreatePBRMaterial(vis.color, vis.m, vis.r)
    if vis.emissive then
        mat:SetShaderParameter("MatEmissiveColor", Variant(vis.emissive))
    end
    return mat
end

return Config
