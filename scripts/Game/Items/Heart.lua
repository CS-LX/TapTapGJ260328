-- ============================================================================
-- Game/Items/Heart.lua — 心心道具（回血）
-- ============================================================================

local ItemBase    = require "Game.Items.ItemBase"
local ItemManager = require "Game.Items.ItemManager"
local State       = require "Game.State"
local Config      = require "Game.Config"
local SFX         = require "Game.SFX"
local GameUI      = require "Game.UI"

local Heart = {}

-- 配置
Heart.INTERVAL    = 80.0   -- 出现间隔（米）
Heart.HEIGHT      = 1.2    -- 浮空高度
Heart.SIZE        = 0.7    -- Billboard 尺寸
Heart.TEXTURE     = "image/heart_lowpoly_20260328171850.png"
Heart.LIGHT_COLOR = Color(1.0, 0.3, 0.35)

-- 状态
Heart.nodes  = {}
Heart.nextZ  = 50.0

-- ============================================================================
-- 生成
-- ============================================================================

function Heart.Spawn(zPos)
    local lane = math.random(-1, 1)
    local pos = Vector3(lane * Config.LANE_WIDTH, Heart.HEIGHT, zPos)

    local node = ItemBase.CreateNode(State.scene, pos, {
        texture    = Heart.TEXTURE,
        lightColor = Heart.LIGHT_COLOR,
        size       = Heart.SIZE,
    })

    table.insert(Heart.nodes, {
        node = node, z = zPos, lane = lane, collected = false,
    })
end

-- ============================================================================
-- 更新
-- ============================================================================

function Heart.Update(dt)
    local playerZ = State.playerNode.position.z
    local playerX = State.playerNode.position.x

    -- 生成新心心（仅在血量未满时）
    local World = require "Game.World"
    while Heart.nextZ < playerZ + Config.SPAWN_DISTANCE do
        Heart.nextZ = World.SkipCanyon(Heart.nextZ)
        if State.health < Config.MAX_HEALTH then
            Heart.Spawn(Heart.nextZ)
        end
        Heart.nextZ = Heart.nextZ + Heart.INTERVAL + math.random() * 20
    end

    -- 更新列表
    ItemBase.UpdateList(Heart.nodes, dt, playerX, playerZ, {
        height     = Heart.HEIGHT,
        size       = Heart.SIZE,
        despawnDist = Config.DESPAWN_DISTANCE,
    }, {
        canCollect = function(item)
            return State.health < Config.MAX_HEALTH
        end,
        onCollect = function(item)
            SFX.Play("wow_sparkle.ogg", 0.8)
            local p = item.node.position
            -- 飞心动画：从捡到位置飞向左上角血条
            GameUI.TriggerHealFlyHeart(Vector3(p.x, p.y + 1.0, p.z), State.health + 1)
            State.health = math.min(State.health + 1, Config.MAX_HEALTH)
            table.insert(State.scorePopups, {
                worldPos = Vector3(p.x, p.y, p.z),
                baseY    = p.y + 0.5,
                timer    = 0,
                duration = 0.8,
                text     = "+❤️",
                color    = { 255, 80, 80 },
            })
            -- 满血后让场上剩余心心消散
            if State.health >= Config.MAX_HEALTH then
                ItemBase.DissolveAll(Heart.nodes)
            end
        end,
    })
end

-- ============================================================================
-- 重置 / 清理
-- ============================================================================

function Heart.Reset()
    Heart.nextZ = 50.0
end

function Heart.ClearAll()
    ItemBase.ClearItems(Heart.nodes)
    Heart.nodes = {}
end

-- 自动注册
ItemManager.Register(Heart)

return Heart
