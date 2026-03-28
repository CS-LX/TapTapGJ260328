-- ============================================================================
-- Game/Items/Magnet.lua — 磁铁道具（吸引金币）
-- ============================================================================

local ItemBase    = require "Game.Items.ItemBase"
local ItemManager = require "Game.Items.ItemManager"
local State       = require "Game.State"
local Config      = require "Game.Config"
local SFX         = require "Game.SFX"

local Magnet = {}

-- 配置
Magnet.INTERVAL   = 100.0  -- 出现间隔（米），稀有
Magnet.HEIGHT     = 1.2    -- 浮空高度
Magnet.SIZE       = 0.7    -- Billboard 尺寸
Magnet.DURATION   = 8.0    -- 持续时间（秒）
Magnet.RANGE      = 8.0    -- 吸引范围（米）
Magnet.PULL_SPEED = 18.0   -- 吸引速度（米/秒）
Magnet.TEXTURE     = "image/magnet_lowpoly_20260328171836.png"
Magnet.LIGHT_COLOR = Color(0.2, 0.4, 1.0)

-- 状态
Magnet.nodes  = {}
Magnet.nextZ  = 40.0
Magnet.active   = false
Magnet.timer    = 0.0
Magnet.cooldown = 0.0       -- 效果结束后的生成冷却（秒）

-- ============================================================================
-- 外部查询接口
-- ============================================================================

function Magnet.IsActive()
    return Magnet.active
end

function Magnet.GetTimer()
    return Magnet.timer
end

-- ============================================================================
-- 生成
-- ============================================================================

function Magnet.Spawn(zPos)
    local lane = math.random(-1, 1)
    local pos = Vector3(lane * Config.LANE_WIDTH, Magnet.HEIGHT, zPos)

    local node = ItemBase.CreateNode(State.scene, pos, {
        texture    = Magnet.TEXTURE,
        lightColor = Magnet.LIGHT_COLOR,
        size       = Magnet.SIZE,
    })

    table.insert(Magnet.nodes, {
        node = node, z = zPos, lane = lane, collected = false,
    })
end

-- ============================================================================
-- 更新
-- ============================================================================

function Magnet.Update(dt)
    local playerZ = State.playerNode.position.z
    local playerX = State.playerNode.position.x

    -- 磁铁激活倒计时
    if Magnet.active then
        Magnet.timer = Magnet.timer - dt
        if Magnet.timer <= 0 then
            Magnet.active = false
            Magnet.timer = 0
            -- 效果结束，启动随机冷却 5~20 秒
            Magnet.cooldown = 5.0 + math.random() * 15.0
        end
    end

    -- 冷却倒计时
    if Magnet.cooldown > 0 then
        Magnet.cooldown = Magnet.cooldown - dt
    end

    -- 生成新磁铁（激活期间和冷却期间都不生成）
    local World = require "Game.World"
    if not Magnet.active and Magnet.cooldown <= 0 then
        while Magnet.nextZ < playerZ + Config.SPAWN_DISTANCE do
            Magnet.nextZ = World.SkipCanyon(Magnet.nextZ)
            Magnet.Spawn(Magnet.nextZ)
            Magnet.nextZ = Magnet.nextZ + Magnet.INTERVAL + math.random() * 20
        end
    end

    -- 更新列表
    ItemBase.UpdateList(Magnet.nodes, dt, playerX, playerZ, {
        height      = Magnet.HEIGHT,
        size        = Magnet.SIZE,
        despawnDist = Config.DESPAWN_DISTANCE,
    }, {
        onCollect = function(item)
            SFX.Play("bell.ogg", 0.8)
            Magnet.active = true
            Magnet.timer = Magnet.DURATION
            local p = item.node.position
            table.insert(State.scorePopups, {
                worldPos = Vector3(p.x, p.y, p.z),
                baseY    = p.y + 0.5,
                timer    = 0,
                duration = 0.8,
                text     = "🧲磁铁!",
                color    = { 80, 160, 255 },
            })
            -- 激活后让场上剩余磁铁消散
            ItemBase.DissolveAll(Magnet.nodes)
        end,
    })
end

-- ============================================================================
-- HUD：磁铁倒计时显示
-- ============================================================================

function Magnet.DrawHUD(vg, w, h)
    if not Magnet.active then return end

    local magnetAlpha = 255
    -- 最后2秒闪烁提示
    if Magnet.timer < 2.0 then
        magnetAlpha = math.floor(math.abs(math.sin(GetTime():GetElapsedTime() * 6)) * 255)
    end
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 20)
    nvgFillColor(vg, nvgRGBA(80, 160, 255, magnetAlpha))
    nvgText(vg, w / 2 + 50, 35, string.format("🧲 %.1fs", Magnet.timer))
end

-- ============================================================================
-- 重置 / 清理
-- ============================================================================

function Magnet.Reset()
    Magnet.nextZ    = 40.0
    Magnet.active   = false
    Magnet.timer    = 0.0
    Magnet.cooldown = 0.0
end

function Magnet.ClearAll()
    ItemBase.ClearItems(Magnet.nodes)
    Magnet.nodes    = {}
    Magnet.active   = false
    Magnet.timer    = 0.0
    Magnet.cooldown = 0.0
end

-- 自动注册
ItemManager.Register(Magnet)

return Magnet
