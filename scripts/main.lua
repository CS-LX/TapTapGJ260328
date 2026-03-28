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
local MidiPlayer  = require "midi.MidiPlayer"

-- 加载道具模块（触发自动注册）
require "Game.Items.Heart"
require "Game.Items.Magnet"

-- BGM 播放器实例
local bgmPlayer = nil

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

    -- 初始化 BGM 播放器
    bgmPlayer = MidiPlayer.new(State.scene, {
        volume = 0.7,
        loop = true,
        maxPolyphony = 32,
    })
    local ok, err = bgmPlayer:load("audio/BGM.midi.txt")
    if ok then
        bgmPlayer:setTracks({1, 4})  -- 只播放第1、4轨道
        bgmPlayer:play()
        print("BGM: MIDI loaded, duration=" .. string.format("%.1f", bgmPlayer:getDuration()) .. "s")
    else
        print("BGM: Failed to load MIDI - " .. tostring(err))
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
    if bgmPlayer then
        bgmPlayer:destroy()
        bgmPlayer = nil
    end
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

    -- BGM 每帧驱动
    if bgmPlayer then
        bgmPlayer:update(dt)
        -- DEBUG: 按 1~4 切换对应音轨
        for i = 1, 4 do
            if input:GetKeyPress(KEY_1 + i - 1) then
                local on = bgmPlayer:toggleTrack(i)
                print(string.format("Track %d: %s", i, on and "ON" or "OFF"))
            end
        end
    end

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
