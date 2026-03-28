-- ============================================================================
-- 地铁跑酷 (Subway Surfers Style)
-- 3D 无尽跑酷游戏 — 模块化入口
-- ============================================================================

require "LuaScripts/Utilities/Sample"

local Config      = require "Game.Config"
local State       = require "Game.State"
local Player      = require "Game.Player"
local World       = require "Game.World"
local Camera      = require "Game.Camera"
local GameUI      = require "Game.UI"
local ItemManager = require "Game.Items.ItemManager"
local BGM         = require "Game.BGM"

-- 加载道具模块（触发自动注册）
require "Game.Items.Heart"
require "Game.Items.Magnet"

-- ============================================================================
-- 入口函数
-- ============================================================================

function Start()
    SampleStart()
    SampleInitMouseMode(MM_FREE)

    -- 创建 NanoVG 上下文
    State.nvgCtx = nvgCreate(1)
    if State.nvgCtx == nil then
        print("ERROR: Failed to create NanoVG context")
        return
    end

    -- 初始化字体
    GameUI.Init(State.nvgCtx)

    -- 创建场景和玩家
    World.CreateScene()
    Player.Create()
    World.CreateInitialGround()

    -- 初始化 BGM（4轨同时播放，默认阶段4，通过 BGM.SetStage 控制）
    BGM.Init(State.scene, { volume = 0.7 })
    BGM.SetStage(4)

    -- BGM 阶段推进移至 Player.lua 自动跳跃时触发（飞跃沟壑瞬间）

    -- 重新开始时重置为第4阶段
    State.onGameReset = function()
        BGM.SetStage(4)
    end

    -- 订阅事件
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent(State.nvgCtx, "NanoVGRender", "HandleNanoVGRender")
    SubscribeToEvent("TouchBegin", "HandleTouchBegin")
    SubscribeToEvent("TouchMove", "HandleTouchMove")
    SubscribeToEvent("TouchEnd", "HandleTouchEnd")

    print("=== Subway Surfer Game Started ===")
end

function Stop()
    BGM.Destroy()
    if State.nvgCtx ~= nil then
        nvgDelete(State.nvgCtx)
        State.nvgCtx = nil
    end
end

-- ============================================================================
-- 主更新循环
-- ============================================================================

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    BGM.Update(dt)

    if State.gameState == Config.STATE_MENU then
        Player.HandleMenuInput(dt)
        Player.UpdateMenuAnimation(dt)
    elseif State.gameState == Config.STATE_PLAYING then
        Player.HandlePlayingInput(dt)
        Player.Update(dt)
        World.UpdateObstacles(dt)
        World.UpdateCoins(dt)
        ItemManager.UpdateAll(dt)
        World.UpdateGround(dt)
        World.UpdateScenery(dt)
        World.UpdateJumpPads(dt)
        World.UpdateFogTransition(dt)
        World.UpdateScore(dt)
        World.UpdateScorePopups(dt)
        Camera.Update(dt)
    elseif State.gameState == Config.STATE_DYING then
        State.UpdateDeath(dt)
        Camera.Update(dt)
        World.UpdateScorePopups(dt)
    elseif State.gameState == Config.STATE_GAMEOVER then
        Player.HandleGameOverInput(dt)
    end
end

-- ============================================================================
-- NanoVG 渲染
-- ============================================================================

function HandleNanoVGRender(eventType, eventData)
    GameUI.Render(eventType, eventData)
end

-- ============================================================================
-- 触摸事件
-- ============================================================================

---@param eventType string
---@param eventData TouchBeginEventData
function HandleTouchBegin(eventType, eventData)
    Player.HandleTouchBegin(eventType, eventData)
end

---@param eventType string
---@param eventData TouchMoveEventData
function HandleTouchMove(eventType, eventData)
    Player.HandleTouchMove(eventType, eventData)
end

---@param eventType string
---@param eventData TouchEndEventData
function HandleTouchEnd(eventType, eventData)
    Player.HandleTouchEnd(eventType, eventData)
end
