-- ============================================================================
-- Game/State.lua — 运行时状态 + 状态管理函数
-- ============================================================================

local Config = require "Game.Config"

local State = {}

-- 核心节点引用
---@type Scene
State.scene = nil
---@type Node
State.cameraNode = nil
---@type Node
State.playerNode = nil

-- NanoVG 上下文
State.nvgCtx = nil
State.fontNormal = -1

-- 游戏状态
State.gameState = Config.STATE_MENU

-- 游戏运行时变量
State.currentLane = 0          -- 当前跑道：-1(左), 0(中), 1(右)
State.targetLaneX = 0.0        -- 目标X位置
State.playerVelocityY = 0.0    -- 玩家Y轴速度
State.isJumping = false        -- 是否在跳跃
State.isSliding = false        -- 是否在下蹲
State.slideTimer = 0.0         -- 下蹲计时器
State.runSpeed = Config.START_SPEED    -- 当前速度
State.distanceTraveled = 0.0   -- 跑过的距离
State.score = 0                -- 得分
State.coins = 0                -- 金币数
State.highScore = 0            -- 最高分

-- 本局道具计数
State.heartsCollected = 0      -- 本局吃到心心
State.magnetsCollected = 0     -- 本局吃到磁铁
State.dayunCount = 0           -- 本局大运次数

-- 云端累计统计（启动时从云端加载）
State.totalDistance = 0        -- 总距离
State.totalScore = 0           -- 总得分
State.totalCoins = 0           -- 总金币
State.totalHearts = 0          -- 总心心
State.totalMagnets = 0         -- 总磁铁
State.totalDayun = 0           -- 总大运次数

-- 障碍物和金币对象池
State.obstacles = {}           -- 活跃障碍物列表
State.coinNodes = {}           -- 活跃金币列表
State.scorePopups = {}         -- 得分弹出动画
State.nextObstacleZ = 30.0    -- 下一个障碍物Z位置
State.nextCoinZ = 15.0        -- 下一个金币Z位置
State.groundSegments = {}     -- 地面段

-- 血量系统
State.health = Config.MAX_HEALTH
State.isInvincible = false
State.invincibleTimer = 0.0
State.hitFlashAlpha = 0

-- 死亡动画相关
State.deathTimer = 0.0
State.deathVelY = 0.0
State.deathVelZ = 0.0
State.deathRotX = 0.0
State.deathRotZ = 0.0
State.deathFlashAlpha = 0

-- 场景/峡谷相关
State.biomeIndex = 1                    -- 当前场景索引 (1=Savanna, 2=Glacier, 3=Cliffs)
State.biomeChangeCount = 0             -- 场景切换累计次数
State.onBiomeChange = nil              -- 场景切换回调 function(count)
State.onGameReset = nil                -- 游戏重置回调 function()
State.segmentsInBiome = 0              -- 当前场景已生成的地面段数
State.canyons = {}                      -- 活跃峡谷列表 { startZ, endZ }
State.isAutoJumping = false             -- 是否在自动跳跃中
State.autoJumpInputLock = 0.0           -- 自动跳跃输入锁定计时器
---@type Zone
State.zoneComponent = nil               -- Zone 组件引用（用于雾色渐变）
State.fogCurrentColor = Color(0.6, 0.75, 0.95)  -- 当前雾色
State.fogTargetColor  = Color(0.6, 0.75, 0.95)  -- 目标雾色

-- 峡谷拖尾特效
State.trailNodes = {}           -- 拖尾节点列表 { node, life, maxLife }

-- 地面窟窿
State.holes = {}                -- 活跃窟窿列表 { zStart, zEnd, lanes={}, nodes={} }
State.nextHoleZ = 60.0          -- 下一个窟窿生成位置

-- 虚空坠落死亡
State.isVoidFalling = false     -- 是否正在坠入峡谷
State.voidFallTimer = 0.0       -- 坠落计时器
State.voidGraceTimer = 0.0      -- 虚空宽限计时（停留超过阈值才坠落）

-- 大运大货车
State.isDayunActive = false     -- 大运是否激活
State.dayunNextThreshold = Config.DAYUN_SCORE_THRESHOLD  -- 下次触发分数阈值

-- 视觉特效状态（峡谷飞跃 + 大运速度感）
State.fxFovCurrent         = 45.0              -- 当前 FOV（平滑插值）
State.fxFovTarget          = 45.0              -- 目标 FOV
State.fxCamPullback        = 0.0               -- 当前相机后拉量
State.fxFlashTimer         = 0.0               -- 起飞闪光计时
State.fxFlashColor         = {180, 230, 255}   -- 闪光颜色（青白）
State.fxSpeedLines         = false             -- 是否显示速度线
State.fxSpeedLineIntensity = 0.0               -- 速度线强度 0~1
State.fxSpeedLineColor     = {100, 200, 255}   -- 速度线颜色
State.fxVignetteAlpha      = 0.0               -- 边缘暗角强度
State.fxVignetteTarget     = 0.0               -- 边缘暗角目标值
State.fxWindParticles      = {}                -- 风粒子列表（3D 白点）
State.fxSpeedLineTargetIntensity = 1.0         -- 速度线目标强度（渐进模式用）
State.fxCamShakeIntensity  = 0.0               -- 渐进微震强度
State.fxProgressivePullback = 0.0              -- 渐进相机后拉量

-- 动画相关
State.playerRunAngle = 0.0
State.swipeStartX = 0
State.swipeStartY = 0
State.isSwiping = false

-- BGM 按钮区域（用于菜单触摸检测）
State.bgmBtnRect = nil  -- { x, y, w, h }

-- 侧边装饰（自然风景）
State.sceneryItems = {}        -- 活跃装饰物列表
State.nextSceneryZ = 10.0      -- 下一个装饰物生成 Z

-- ============================================================================
-- 状态管理函数
-- ============================================================================

function State.ClearAll()
    for _, obs in ipairs(State.obstacles) do
        if obs.node then obs.node:Remove() end
        if obs.extraNode then obs.extraNode:Remove() end
    end
    State.obstacles = {}

    for _, coin in ipairs(State.coinNodes) do
        if coin.node then coin.node:Remove() end
    end
    State.coinNodes = {}
    State.scorePopups = {}

    for _, seg in ipairs(State.groundSegments) do
        if seg.node then seg.node:Remove() end
    end
    -- 清理侧边装饰
    for _, item in ipairs(State.sceneryItems) do
        if item.node then item.node:Remove() end
    end
    State.sceneryItems = {}
    State.nextSceneryZ = 10.0

    local children = State.scene:GetChildren()
    for _, child in ipairs(children) do
        local name = child.name
        if name == "LaneLine" or name == "Ground" or name == "Hole"
            or name == "Scenery" or name == "SideTerrain" then
            child:Remove()
        end
    end
    State.groundSegments = {}

    -- 清理窟窿
    for _, hole in ipairs(State.holes) do
        if hole.nodes then
            for _, n in ipairs(hole.nodes) do
                if n then n:Remove() end
            end
        end
    end
    State.holes = {}
    State.nextHoleZ = 60.0

    -- 重置场景/峡谷状态
    State.biomeIndex = 1
    State.biomeChangeCount = 0
    State.segmentsInBiome = 0
    State.canyons = {}
    State.isAutoJumping = false
    State.autoJumpInputLock = 0.0
    State.isVoidFalling = false
    State.voidFallTimer = 0.0
    State.voidGraceTimer = 0.0
    -- 大运重置
    State.isDayunActive = false
    State.dayunNextThreshold = Config.DAYUN_SCORE_THRESHOLD
    -- 视觉特效重置
    State.fxFovCurrent         = 45.0
    State.fxFovTarget          = 45.0
    State.fxCamPullback        = 0.0
    State.fxFlashTimer         = 0.0
    State.fxSpeedLines         = false
    State.fxSpeedLineIntensity = 0.0
    State.fxVignetteAlpha      = 0.0
    State.fxVignetteTarget     = 0.0
    State.fxSpeedLineTargetIntensity = 1.0
    State.fxCamShakeIntensity  = 0.0
    State.fxProgressivePullback = 0.0
    -- 清理风粒子
    for _, wp in ipairs(State.fxWindParticles) do
        if wp.node then wp.node:Remove() end
    end
    State.fxWindParticles = {}
    -- 清理拖尾节点
    for _, trail in ipairs(State.trailNodes) do
        if trail.node then trail.node:Remove() end
    end
    State.trailNodes = {}
    local firstBiome = require("Game.Config").BIOMES[1]
    State.fogCurrentColor = Color(firstBiome.fog.r, firstBiome.fog.g, firstBiome.fog.b)
    State.fogTargetColor  = Color(firstBiome.fog.r, firstBiome.fog.g, firstBiome.fog.b)

    if State.onGameReset then
        State.onGameReset()
    end
end

function State.GameOver()
    State.hasDied = true
    State.gameState = Config.STATE_DYING
    State.deathTimer = 0.0
    State.deathVelY = 8.0
    State.deathVelZ = -4.0
    State.deathRotX = 0.0
    State.deathRotZ = 0.0
    State.deathFlashAlpha = 255

    if State.score > State.highScore then
        State.highScore = State.score
    end
    print("Game Over! Score: " .. State.score .. " | High Score: " .. State.highScore)
end

function State.UpdateDeath(dt)
    State.deathTimer = State.deathTimer + dt

    -- 玩家弹飞物理
    local pos = State.playerNode.position
    State.deathVelY = State.deathVelY + Config.GRAVITY * 0.6 * dt
    pos.y = pos.y + State.deathVelY * dt
    pos.z = pos.z + State.deathVelZ * dt
    if pos.y < -2.0 then pos.y = -2.0 end
    State.playerNode.position = pos

    -- 翻滚旋转
    State.deathRotX = State.deathRotX + 360 * dt
    State.deathRotZ = State.deathRotZ + 120 * dt
    State.playerNode.rotation = Quaternion(State.deathRotX, State.deathRotZ, 0)

    -- 红色闪屏衰减
    State.deathFlashAlpha = math.max(0, State.deathFlashAlpha - 400 * dt)

    -- 动画结束，进入 GameOver 画面
    if State.deathTimer >= Config.DEATH_DURATION then
        State.gameState = Config.STATE_GAMEOVER
    end
end

return State
