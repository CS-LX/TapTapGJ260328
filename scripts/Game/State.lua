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

-- 障碍物和金币对象池
State.obstacles = {}           -- 活跃障碍物列表
State.coinNodes = {}           -- 活跃金币列表
State.scorePopups = {}         -- 得分弹出动画
State.nextObstacleZ = 30.0    -- 下一个障碍物Z位置
State.nextCoinZ = 15.0        -- 下一个金币Z位置
State.groundSegments = {}     -- 地面段

-- 道具系统
State.heartNodes = {}              -- 心心道具列表
State.nextHeartZ = 50.0            -- 下一个心心Z位置
State.magnetNodes = {}             -- 磁铁道具列表
State.nextMagnetZ = 40.0           -- 下一个磁铁Z位置
State.magnetActive = false         -- 磁铁是否激活
State.magnetTimer = 0.0            -- 磁铁剩余时间

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

-- 动画相关
State.playerRunAngle = 0.0
State.swipeStartX = 0
State.swipeStartY = 0
State.isSwiping = false

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

    for _, heart in ipairs(State.heartNodes) do
        if heart.node then heart.node:Remove() end
    end
    State.heartNodes = {}

    for _, magnet in ipairs(State.magnetNodes) do
        if magnet.node then magnet.node:Remove() end
    end
    State.magnetNodes = {}
    State.magnetActive = false
    State.magnetTimer = 0.0

    for _, seg in ipairs(State.groundSegments) do
        if seg.node then seg.node:Remove() end
    end
    local children = State.scene:GetChildren()
    for _, child in ipairs(children) do
        local name = child.name
        if name == "LaneLine" or name == "Wall" or name == "Ground" then
            child:Remove()
        end
    end
    State.groundSegments = {}
end

function State.GameOver()
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
