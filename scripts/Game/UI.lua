-- ============================================================================
-- Game/UI.lua — NanoVG UI 渲染
-- ============================================================================

local Config      = require "Game.Config"
local State       = require "Game.State"
local ItemManager = require "Game.Items.ItemManager"
local BGM         = require "Game.BGM"

local GameUI = {}

-- ============================================================================
-- 初始化
-- ============================================================================

function GameUI.Init(nvgCtx)
    State.fontNormal = nvgCreateFont(nvgCtx, "sans", "Fonts/MiSans-Regular.ttf")
    if State.fontNormal == -1 then
        print("ERROR: Failed to load font")
    end
end

-- ============================================================================
-- 渲染入口
-- ============================================================================

-- 上一帧的游戏状态（用于检测状态切换）
local prevGameState = Config.STATE_MENU
local lastRenderTime = 0

function GameUI.Render(eventType, eventData)
    if State.nvgCtx == nil then return end

    local now = GetTime():GetElapsedTime()
    local renderDt = now - lastRenderTime
    if renderDt > 0.1 then renderDt = 0.016 end  -- 防止首帧/卡顿跳跃
    lastRenderTime = now

    local g = GetGraphics()
    local physW = g:GetWidth()
    local physH = g:GetHeight()

    -- 检测进入 GAMEOVER 状态，重置结算动画
    if State.gameState == Config.STATE_GAMEOVER and prevGameState ~= Config.STATE_GAMEOVER then
        gameOverAnimT = 0
        goParticles = {}
    end
    prevGameState = State.gameState

    nvgBeginFrame(State.nvgCtx, physW, physH, 1.0)

    if State.gameState == Config.STATE_MENU then
        GameUI.DrawMenu(physW, physH)
    elseif State.gameState == Config.STATE_PLAYING then
        GameUI.DrawHUD(physW, physH, renderDt)
    elseif State.gameState == Config.STATE_DYING then
        GameUI.DrawHUD(physW, physH, renderDt)
        GameUI.DrawDeathEffect(physW, physH)
    elseif State.gameState == Config.STATE_GAMEOVER then
        GameUI.DrawGameOver(physW, physH)
    end

    nvgEndFrame(State.nvgCtx)
end

-- ============================================================================
-- 菜单画面
-- ============================================================================

-- 菜单装饰粒子（Emoji 飘过）
local menuParticles = {}
local MENU_EMOJIS = {"🏃", "💨", "🚛", "🦅", "⚡", "🔥", "💥", "🪙", "🌟", "💎", "🎮", "🏆"}
local MENU_SLOGANS = {
    "🦅 飞跃大峡谷",
    "🚛 大运狂飙碾压一切",
    "⚡ 极速 180 停不下来",
    "💀 三条命闯天涯",
    "🪙 金币收割王",
}
-- 主菜单火花粒子
local menuSparks = {}
-- 扣血弹出效果
local hitPopups = {}           -- { text, timer, duration, x, y }
local heartShakeTimer = 0      -- 血条抖动计时

-- 结算画面状态
local gameOverAnimT = 0       -- 结算画面入场动画计时
local scoreCountUp = 0         -- 分数滚动计数
local goParticles = {}         -- 结算画面粒子
local goShakeTimer = 0         -- 结算画面震屏计时

function GameUI.DrawMenu(w, h)
    local vg = State.nvgCtx
    local t = GetTime():GetElapsedTime()
    local dt = GetTime():GetTimeStep()

    -- ================================================================
    -- 动感背景：多层渐变 + 呼吸色变
    -- ================================================================
    -- 底色脉冲（暗紫 ↔ 暗蓝交替）
    local bgPulse = math.sin(t * 0.8) * 0.5 + 0.5
    local bgR = math.floor(5 + bgPulse * 15)
    local bgG = math.floor(5 + (1 - bgPulse) * 10)
    local bgB = math.floor(20 + bgPulse * 25)
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, w, h)
    local bgGrad = nvgLinearGradient(vg, 0, 0, 0, h,
        nvgRGBA(0, 0, 0, 180), nvgRGBA(bgR, bgG, bgB, 100))
    nvgFillPaint(vg, bgGrad)
    nvgFill(vg)

    -- ================================================================
    -- 背景速度线（更密集、更亮）
    -- ================================================================
    GameUI.DrawMenuSpeedLines(vg, w, h, t)

    -- ================================================================
    -- 底部扫光（从左到右扫过的光带）
    -- ================================================================
    local sweepX = ((t * 0.3) % 1.4 - 0.2) * w
    local sweepW = w * 0.25
    nvgBeginPath(vg)
    nvgRect(vg, sweepX, 0, sweepW, h)
    local sweepGrad = nvgLinearGradient(vg, sweepX, 0, sweepX + sweepW, 0,
        nvgRGBA(255, 200, 80, 0), nvgRGBA(255, 200, 80, 18))
    nvgFillPaint(vg, sweepGrad)
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgRect(vg, sweepX + sweepW * 0.3, 0, sweepW * 0.4, h)
    local sweepGrad2 = nvgLinearGradient(vg, sweepX + sweepW * 0.3, 0, sweepX + sweepW * 0.7, 0,
        nvgRGBA(255, 220, 100, 20), nvgRGBA(255, 220, 100, 0))
    nvgFillPaint(vg, sweepGrad2)
    nvgFill(vg)

    -- ================================================================
    -- 飘过的 Emoji 装饰粒子
    -- ================================================================
    GameUI.UpdateAndDrawMenuParticles(vg, w, h, t)

    -- ================================================================
    -- 火花粒子（从标题位置迸发）
    -- ================================================================
    GameUI.UpdateAndDrawMenuSparks(vg, w, h, t, dt)

    -- ================================================================
    -- 主标题：「似腿快跑！！」—— 更炸裂的效果
    -- ================================================================
    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    local titleY = h * 0.26
    -- 更夸张的弹跳 + 左右晃动
    local bounce = math.sin(t * 3.0) * 10 + math.sin(t * 7.0) * 3
    local tilt = math.sin(t * 2.2) * 4

    -- 超大模糊光晕（彩色脉冲）
    local glowPhase = t * 5.0
    local glowR = math.floor(200 + math.sin(glowPhase) * 55)
    local glowG = math.floor(120 + math.sin(glowPhase + 2.1) * 80)
    local glowB = math.floor(30 + math.sin(glowPhase + 4.2) * 30)
    local glowPulse = 0.5 + math.sin(t * 4) * 0.5
    nvgFontSize(vg, 80)
    nvgFillColor(vg, nvgRGBA(glowR, glowG, glowB, math.floor(glowPulse * 50)))
    nvgText(vg, w/2 + tilt, titleY + bounce, "似腿快跑！！")
    -- 第二层光晕（更大更淡）
    nvgFontSize(vg, 88)
    nvgFillColor(vg, nvgRGBA(glowR, glowG, glowB, math.floor(glowPulse * 25)))
    nvgText(vg, w/2 + tilt, titleY + bounce, "似腿快跑！！")

    -- 厚实黑色描边
    nvgFontSize(vg, 64)
    local outlineOffsets = {
        {-3,-3},{3,-3},{-3,3},{3,3},{0,-4},{0,4},{-4,0},{4,0},
        {-2,-4},{2,-4},{-2,4},{2,4},{-4,-2},{4,-2},{-4,2},{4,2},
    }
    for _, off in ipairs(outlineOffsets) do
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 220))
        nvgText(vg, w/2 + off[1] + tilt, titleY + off[2] + bounce, "似腿快跑！！")
    end

    -- 主标题：彩虹色循环！
    local hueShift = (t * 60) % 360
    local titleR, titleG, titleB = GameUI.HSVtoRGB(hueShift, 0.5, 1.0)
    nvgFillColor(vg, nvgRGBA(titleR, titleG, titleB, 255))
    nvgText(vg, w/2 + tilt, titleY + bounce, "似腿快跑！！")

    -- 高光叠加层（白色，随脉冲闪烁）
    local highlightA = math.floor(math.max(0, math.sin(t * 6) * 80))
    nvgFillColor(vg, nvgRGBA(255, 255, 255, highlightA))
    nvgText(vg, w/2 + tilt, titleY + bounce - 1, "似腿快跑！！")

    -- ================================================================
    -- 副标题（游戏类型标签）
    -- ================================================================
    local subY = titleY + 52 + bounce * 0.3
    nvgFontSize(vg, 16)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 120))
    nvgText(vg, w/2 + 1, subY + 1, "🎮 3D 极速跑酷  ·  无尽冒险")
    nvgFillColor(vg, nvgRGBA(180, 200, 255, 180))
    nvgText(vg, w/2, subY, "🎮 3D 极速跑酷  ·  无尽冒险")

    -- ================================================================
    -- 特色标语轮播（更大更醒目 + 滑入动画）
    -- ================================================================
    local sloganCycle = 2.0
    local sloganIdx = math.floor(t / sloganCycle) % #MENU_SLOGANS + 1
    local sloganT = (t % sloganCycle) / sloganCycle
    local sloganAlpha = 255
    local sloganSlide = 0
    if sloganT < 0.15 then
        sloganAlpha = math.floor(sloganT / 0.15 * 255)
        sloganSlide = math.floor((1.0 - sloganT / 0.15) * 30)
    elseif sloganT > 0.85 then
        sloganAlpha = math.floor((1.0 - sloganT) / 0.15 * 255)
        sloganSlide = math.floor(-((sloganT - 0.85) / 0.15) * 30)
    end

    local sloganY = titleY + 80
    nvgFontSize(vg, 26)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(sloganAlpha * 0.6)))
    nvgText(vg, w/2 + 2 + sloganSlide, sloganY + 2, MENU_SLOGANS[sloganIdx])
    -- 标语彩色（根据内容换色）
    local sColors = {
        {100, 220, 255}, {255, 160, 50}, {50, 255, 120}, {255, 80, 80}, {255, 220, 50}
    }
    local sc = sColors[sloganIdx] or {180, 230, 255}
    nvgFillColor(vg, nvgRGBA(sc[1], sc[2], sc[3], sloganAlpha))
    nvgText(vg, w/2 + sloganSlide, sloganY, MENU_SLOGANS[sloganIdx])

    -- ================================================================
    -- 开始提示文字（闪烁呼吸）
    -- ================================================================
    local promptY = h * 0.60
    local promptAlpha = math.floor(140 + math.sin(t * 3.5) * 115)
    nvgFontSize(vg, 26)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(promptAlpha * 0.5)))
    nvgText(vg, w/2 + 1, promptY + 1, "按下空格，来一局")
    nvgFillColor(vg, nvgRGBA(255, 255, 255, promptAlpha))
    nvgText(vg, w/2, promptY, "按下空格，来一局")

    -- ================================================================
    -- 操作教程（醒目卡片）
    -- ================================================================
    GameUI.DrawMenuTutorial(vg, w, h, t)

    -- ================================================================
    -- 最高分（金色奖杯 + 闪烁星星）
    -- ================================================================
    if State.highScore > 0 then
        local hsY = h * 0.90
        local starBlink = math.sin(t * 5) > 0.3 and "⭐" or "✨"
        local hsText = starBlink .. " 最高分: " .. State.highScore .. " " .. starBlink
        nvgFontSize(vg, 22)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 140))
        nvgText(vg, w/2 + 1, hsY + 1, hsText)
        nvgFillColor(vg, nvgRGBA(255, 210, 80, 240))
        nvgText(vg, w/2, hsY, hsText)
    end

    -- ================================================================
    -- BGM 开关按钮（右上角）
    -- ================================================================
    GameUI.DrawBGMButton(vg, w, h)
end

-- ============================================================================
-- 菜单操作教程（醒目卡片式）
-- ============================================================================

function GameUI.DrawMenuTutorial(vg, w, h, t)
    nvgSave(vg)

    local tutorialItems = {
        { icon = "⬅️ ➡️",  key = "A / D",     touch = "左右滑动", desc = "切换跑道" },
        { icon = "⬆️",     key = "空格",       touch = "上滑",     desc = "跳跃" },
        { icon = "⬇️",     key = "S",          touch = "下滑",     desc = "下蹲" },
        { icon = "💰",     key = "",           touch = "",         desc = "收集金币加分" },
        { icon = "❤️",     key = "",           touch = "",         desc = "吃爱心回血" },
    }

    local itemCount = #tutorialItems
    local cardW = math.min(w * 0.7, 400)
    local itemH = 36
    local padding = 12
    local cardH = itemCount * itemH + padding * 2 + 28  -- 28 for title
    local cardX = (w - cardW) / 2
    local cardY = h * 0.64

    -- 卡片背景（半透明圆角矩形 + 发光边框）
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cardX, cardY, cardW, cardH, 12)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 160))
    nvgFill(vg)

    -- 发光边框（脉冲呼吸）
    local borderAlpha = math.floor(60 + math.sin(t * 2.5) * 40)
    nvgStrokeWidth(vg, 1.5)
    nvgStrokeColor(vg, nvgRGBA(100, 180, 255, borderAlpha))
    nvgStroke(vg)

    -- 标题
    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 18)
    nvgFillColor(vg, nvgRGBA(100, 200, 255, 220))
    nvgText(vg, w / 2, cardY + padding + 8, "-- 操作指南 --")

    -- 教程内容
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    local startY = cardY + padding + 28 + itemH / 2
    local colIcon = cardX + padding + 4
    local colDesc = cardX + padding + 46
    local colKey  = cardX + cardW - padding - 8

    for i, item in ipairs(tutorialItems) do
        local iy = startY + (i - 1) * itemH

        -- 交替行背景色
        if i % 2 == 0 then
            nvgBeginPath(vg)
            nvgRoundedRect(vg, cardX + 6, iy - itemH / 2 + 2, cardW - 12, itemH - 4, 6)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 12))
            nvgFill(vg)
        end

        -- 图标
        nvgFontSize(vg, 20)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 230))
        nvgText(vg, colIcon, iy, item.icon)

        -- 描述
        nvgFontSize(vg, 16)
        nvgFillColor(vg, nvgRGBA(220, 230, 255, 220))
        nvgText(vg, colDesc, iy, item.desc)

        -- 按键/触控提示（右对齐）
        if item.key ~= "" then
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 13)

            -- 键盘按键标签（圆角背景）
            local keyText = item.key
            local kw = (nvgTextBounds(vg, 0, 0, keyText) or 0) + 12
            local kh = 20
            local kx = colKey - kw + 2
            local ky = iy - kh / 2

            nvgBeginPath(vg)
            nvgRoundedRect(vg, kx, ky, kw, kh, 4)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 30))
            nvgFill(vg)
            nvgStrokeWidth(vg, 1)
            nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 50))
            nvgStroke(vg)

            nvgFillColor(vg, nvgRGBA(200, 220, 255, 200))
            nvgText(vg, colKey - 4, iy, keyText)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        end

        -- 触控提示（小字灰色）
        if item.touch ~= "" then
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 11)
            nvgFillColor(vg, nvgRGBA(160, 170, 200, 140))
            local touchY = iy + 0
            -- 放在按键标签的左边
            local keyWidth = (item.key ~= "") and ((nvgTextBounds(vg, 0, 0, item.key) or 0) + 20) or 0
            nvgText(vg, colKey - keyWidth - 4, touchY, item.touch)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        end
    end

    nvgRestore(vg)
end

-- ============================================================================
-- 菜单背景速度线（淡淡的水平速度氛围）
-- ============================================================================

function GameUI.DrawMenuSpeedLines(vg, w, h, t)
    nvgSave(vg)
    local lineCount = 20
    for i = 1, lineCount do
        local seed = i * 137.5
        local y = (math.sin(seed) * 0.5 + 0.5) * h
        local speed = 100 + (math.sin(seed * 0.7) * 0.5 + 0.5) * 180
        local x = w - ((t * speed + seed * 3) % (w + 300)) + 150
        local lineLen = 50 + (math.sin(seed * 1.3) * 0.5 + 0.5) * 120
        local alpha = math.floor(20 + math.sin(t * 3 + i) * 15)
        -- 偶尔出现亮色线
        local lr, lg, lb = 200, 220, 255
        if i % 5 == 0 then
            lr, lg, lb = 255, 200, 80
            alpha = alpha + 10
        end

        nvgBeginPath(vg)
        nvgMoveTo(vg, x, y)
        nvgLineTo(vg, x + lineLen, y)
        nvgStrokeColor(vg, nvgRGBA(lr, lg, lb, alpha))
        nvgStrokeWidth(vg, 1.0 + math.sin(seed) * 0.8)
        nvgStroke(vg)
    end
    nvgRestore(vg)
end

-- ============================================================================
-- 菜单 Emoji 装饰粒子系统
-- ============================================================================

function GameUI.UpdateAndDrawMenuParticles(vg, w, h, t)
    -- 定期生成新粒子
    if #menuParticles < 8 and math.floor(t * 2) ~= math.floor((t - GetTime():GetTimeStep()) * 2) then
        local emoji = MENU_EMOJIS[math.random(1, #MENU_EMOJIS)]
        table.insert(menuParticles, {
            emoji = emoji,
            x = w + 30,
            y = 30 + math.random() * (h - 60),
            speed = 30 + math.random() * 50,
            size = 18 + math.random() * 16,
            alpha = 120 + math.random(80),
            wobble = math.random() * 6.28,  -- 初始相位
        })
    end

    local dt = GetTime():GetTimeStep()
    local toRemove = {}

    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    for i, p in ipairs(menuParticles) do
        p.x = p.x - p.speed * dt
        local wobbleY = math.sin(t * 1.5 + p.wobble) * 8

        if p.x < -40 then
            table.insert(toRemove, i)
        else
            nvgFontSize(vg, p.size)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, p.alpha))
            nvgText(vg, p.x, p.y + wobbleY, p.emoji)
        end
    end

    for i = #toRemove, 1, -1 do
        table.remove(menuParticles, toRemove[i])
    end
end

-- ============================================================================
-- 菜单火花粒子系统（从标题方向迸射的小光点）
-- ============================================================================

function GameUI.UpdateAndDrawMenuSparks(vg, w, h, t, dt)
    -- 定期生成火花
    if #menuSparks < 16 and math.random() < 0.3 then
        local angle = math.random() * math.pi * 2
        local speed = 60 + math.random() * 120
        table.insert(menuSparks, {
            x = w/2 + (math.random() - 0.5) * 120,
            y = h * 0.26,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed - 40,  -- 偏上迸射
            life = 0,
            maxLife = 0.4 + math.random() * 0.5,
            size = 2 + math.random() * 3,
            hue = math.random() * 360,
        })
    end

    local toRemove = {}
    for i, s in ipairs(menuSparks) do
        s.life = s.life + dt
        if s.life >= s.maxLife then
            table.insert(toRemove, i)
        else
            s.x = s.x + s.vx * dt
            s.vy = s.vy + 80 * dt  -- 轻微重力
            s.y = s.y + s.vy * dt
            local fade = 1.0 - (s.life / s.maxLife)
            local alpha = math.floor(fade * 220)
            local sz = s.size * fade
            local r, g, b = GameUI.HSVtoRGB(s.hue, 0.7, 1.0)
            nvgBeginPath(vg)
            nvgCircle(vg, s.x, s.y, sz)
            nvgFillColor(vg, nvgRGBA(r, g, b, alpha))
            nvgFill(vg)
        end
    end
    for i = #toRemove, 1, -1 do
        table.remove(menuSparks, toRemove[i])
    end
end

-- ============================================================================
-- HSV → RGB 工具函数
-- ============================================================================

function GameUI.HSVtoRGB(h, s, v)
    local c = v * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = v - c
    local r, g, b = 0, 0, 0
    if h < 60 then     r, g, b = c, x, 0
    elseif h < 120 then r, g, b = x, c, 0
    elseif h < 180 then r, g, b = 0, c, x
    elseif h < 240 then r, g, b = 0, x, c
    elseif h < 300 then r, g, b = x, 0, c
    else                r, g, b = c, 0, x
    end
    return math.floor((r + m) * 255), math.floor((g + m) * 255), math.floor((b + m) * 255)
end

-- ============================================================================
-- BGM 按钮（共用）
-- ============================================================================

function GameUI.DrawBGMButton(vg, w, h)
    local btnW2, btnH2 = 44, 44
    local btnX = w - btnW2 - 16
    local btnY2 = 16
    State.bgmBtnRect = { x = btnX, y = btnY2, w = btnW2, h = btnH2 }

    nvgBeginPath(vg)
    nvgRoundedRect(vg, btnX, btnY2, btnW2, btnH2, 8)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 30))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 80))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    if BGM.IsMuted() then
        nvgFillColor(vg, nvgRGBA(255, 100, 100, 200))
        nvgText(vg, btnX + btnW2 / 2, btnY2 + btnH2 / 2, "🔇")
    else
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 220))
        nvgText(vg, btnX + btnW2 / 2, btnY2 + btnH2 / 2, "🔊")
    end
end

-- ============================================================================
-- 扣血弹出效果（玩家头顶弹出 + 心飞向左上角血条）
-- ============================================================================

-- 飞行中的心列表 { startX, startY, targetX, targetY, timer, duration }
local flyingHearts = {}

--- 外部调用：触发扣血弹出（在玩家位置）
function GameUI.TriggerHitPopup(damage)
    heartShakeTimer = 0.5
    -- 获取玩家世界坐标，投影到屏幕
    local playerPos = State.playerNode.position
    local worldPos = Vector3(playerPos.x, playerPos.y + 2.5, playerPos.z)
    table.insert(hitPopups, {
        text = "-" .. damage .. " ❤️",
        damage = damage,
        timer = 0,
        duration = 1.5,
        worldPos = worldPos,           -- 3D 世界位置
        heartsSent = false,            -- 飞心是否已发出
    })
end

--- 外部调用：捡到爱心时触发飞心动画（从 3D 位置飞向左上角血条）
function GameUI.TriggerHealFlyHeart(worldPos, slotIndex)
    table.insert(flyingHearts, {
        worldPos = worldPos,           -- 3D 起点
        slotIndex = slotIndex,         -- 飞向第几颗心槽位
        timer = 0,
        duration = 0.6,
        heal = true,                   -- 标记为回血飞心
        screenStartResolved = false,   -- 屏幕起点尚未计算
        startX = 0, startY = 0,
        targetX = 0, targetY = 0,
    })
end

--- 更新并绘制扣血弹出
local function UpdateAndDrawHitPopups(vg, w, h, dt)
    -- 更新抖动计时
    if heartShakeTimer > 0 then
        heartShakeTimer = heartShakeTimer - dt
        if heartShakeTimer < 0 then heartShakeTimer = 0 end
    end

    local camera = State.cameraNode:GetComponent("Camera")

    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    for i = #hitPopups, 1, -1 do
        local p = hitPopups[i]
        p.timer = p.timer + dt
        if p.timer >= p.duration then
            table.remove(hitPopups, i)
        else
            local t = p.timer / p.duration
            -- 将玩家世界坐标投影到屏幕
            local upOffset = p.timer * 2.0
            local worldP = Vector3(p.worldPos.x, p.worldPos.y + upOffset, p.worldPos.z)
            local sp = camera:WorldToScreenPoint(worldP)
            local sx = sp.x * w
            local sy = sp.y * h

            -- 阶段1 (0~0.4)：文字弹出放大
            -- 阶段2 (0.4~1.0)：淡出，同时飞心
            local alpha
            if t < 0.1 then
                alpha = math.floor(t / 0.1 * 255)
            elseif t < 0.5 then
                alpha = 255
            else
                alpha = math.floor(255 * (1.0 - (t - 0.5) / 0.5))
            end

            local scale
            if t < 0.08 then
                scale = t / 0.08 * 1.8
            elseif t < 0.2 then
                scale = 1.8 - (t - 0.08) / 0.12 * 0.6
            else
                scale = 1.2
            end

            nvgFontSize(vg, 40 * scale)
            -- 黑色描边
            nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(alpha * 0.7)))
            nvgText(vg, sx + 2, sy + 2, p.text)
            -- 红色主体
            nvgFillColor(vg, nvgRGBA(255, 40, 40, alpha))
            nvgText(vg, sx, sy, p.text)

            -- 在 0.3s 时发射飞行心
            if not p.heartsSent and p.timer > 0.3 then
                p.heartsSent = true
                local damage = p.damage or 1
                -- 当前血量已扣过，飞心对应扣掉的槽位
                for hi = 1, damage do
                    -- 目标：左上角第 (health + hi) 颗心的位置
                    local slotIndex = State.health + hi
                    local targetX = 20 + (slotIndex - 1) * 28 + 14
                    local targetY = 25
                    table.insert(flyingHearts, {
                        startX = sx,
                        startY = sy,
                        targetX = targetX,
                        targetY = targetY,
                        timer = 0,
                        duration = 0.5,
                    })
                end
            end
        end
    end

    -- 绘制飞行中的心（扣血：从玩家飞向血条 / 回血：从拾取位置飞向血条）
    local heartSize = 32
    local heartGap = 4
    local heartBaseX = 10
    local heartBaseY = 5

    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    for i = #flyingHearts, 1, -1 do
        local fh = flyingHearts[i]
        fh.timer = fh.timer + dt

        -- 回血飞心：首帧从 3D 坐标投影屏幕坐标
        if fh.heal and not fh.screenStartResolved then
            fh.screenStartResolved = true
            local sp = camera:WorldToScreenPoint(fh.worldPos)
            fh.startX = sp.x * w
            fh.startY = sp.y * h
            local si = fh.slotIndex or 1
            fh.targetX = heartBaseX + 12 + (si - 1) * (heartSize + heartGap) + heartSize / 2
            fh.targetY = heartBaseY + 20
        end

        if fh.timer >= fh.duration then
            table.remove(flyingHearts, i)
        else
            local t = fh.timer / fh.duration
            -- 缓出曲线
            local ease = 1.0 - (1.0 - t) * (1.0 - t)
            local cx = fh.startX + (fh.targetX - fh.startX) * ease
            local cy = fh.startY + (fh.targetY - fh.startY) * ease
            -- 弧形偏移（抛物线感）
            local arc = math.sin(t * 3.14159) * -40
            cy = cy + arc

            local fAlpha = t < 0.8 and 255 or math.floor(255 * (1.0 - (t - 0.8) / 0.2))
            local fScale = fh.heal and (1.0 + (1.0 - ease) * 0.8) or (1.5 - ease * 0.8)

            nvgFontSize(vg, 32 * fScale)
            nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(fAlpha * 0.5)))
            nvgText(vg, cx + 1, cy + 1, "❤️")
            nvgFillColor(vg, nvgRGBA(255, 255, 255, fAlpha))
            nvgText(vg, cx, cy, "❤️")
        end
    end
end

-- ============================================================================
-- 游戏 HUD
-- ============================================================================

function GameUI.DrawHUD(w, h, dt)
    local vg = State.nvgCtx
    dt = dt or 0.016

    nvgFontFace(vg, "sans")

    -- 受击红色闪屏
    if State.hitFlashAlpha > 0 then
        nvgBeginPath(vg)
        nvgRect(vg, 0, 0, w, h)
        nvgFillColor(vg, nvgRGBA(200, 30, 20, math.floor(State.hitFlashAlpha)))
        nvgFill(vg)
    end

    -- 顶部状态栏背景
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, w, 70)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 100))
    nvgFill(vg)

    -- 爱心血条（大号醒目 + 底板 + 受击抖动 + 低血量脉冲）
    nvgSave(vg)
    if heartShakeTimer > 0 then
        local shakeX = math.sin(heartShakeTimer * 40) * heartShakeTimer * 15
        local shakeY = math.cos(heartShakeTimer * 35) * heartShakeTimer * 8
        nvgTranslate(vg, shakeX, shakeY)
    end

    local heartSize = 32
    local heartGap = 4
    local heartW = Config.MAX_HEALTH * (heartSize + heartGap) + 16
    local heartH = 40
    local heartX = 10
    local heartY = 5

    -- 底板背景（圆角半透明）
    nvgBeginPath(vg)
    nvgRoundedRect(vg, heartX, heartY, heartW, heartH, 8)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 140))
    nvgFill(vg)

    -- 低血量时底板边框脉冲红光
    if State.health <= 2 and State.health > 0 then
        local t = GetTime():GetElapsedTime()
        local pulse = math.floor(80 + math.sin(t * 5) * 80)
        nvgStrokeWidth(vg, 2)
        nvgStrokeColor(vg, nvgRGBA(255, 50, 30, pulse))
        nvgStroke(vg)
    end

    -- 逐颗绘制心（大号 emoji）
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, heartSize)
    for i = 1, Config.MAX_HEALTH do
        local cx = heartX + 12 + (i - 1) * (heartSize + heartGap) + heartSize / 2
        local cy = heartY + heartH / 2
        if i <= State.health then
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
            nvgText(vg, cx, cy, "❤️")
        else
            nvgFillColor(vg, nvgRGBA(150, 150, 150, 120))
            nvgText(vg, cx, cy, "🖤")
        end
    end
    nvgRestore(vg)

    -- 得分
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 24)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 230))
    nvgText(vg, 20, 55, "得分: " .. State.score)

    -- 金币
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 22)
    nvgFillColor(vg, nvgRGBA(255, 220, 50, 255))
    nvgText(vg, w/2, 35, "🪙 " .. State.coins)

    -- 速度
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 18)
    nvgFillColor(vg, nvgRGBA(200, 200, 200, 200))
    nvgText(vg, w - 20, 25, string.format("%.0f km/h", State.runSpeed * 3.6))

    -- 距离
    nvgFontSize(vg, 14)
    nvgFillColor(vg, nvgRGBA(180, 180, 180, 180))
    nvgText(vg, w - 20, 50, string.format("%.0f m", State.distanceTraveled))

    -- 道具 HUD（磁铁倒计时等，由各道具模块自行绘制）
    ItemManager.DrawHUD(vg, w, h)

    -- ================================================================
    -- 速度视觉特效（速度线 + 闪光 + 暗角）
    -- ================================================================
    GameUI.UpdateAndDrawSpeedFX(vg, w, h)

    -- 浮动得分弹出文字
    local camera = State.cameraNode:GetComponent("Camera")
    for _, popup in ipairs(State.scorePopups) do
        local t = popup.timer / popup.duration
        local worldY = popup.baseY + popup.timer * 3.0
        local worldP = Vector3(popup.worldPos.x, worldY, popup.worldPos.z)
        local sp = camera:WorldToScreenPoint(worldP)
        if sp.x >= 0 and sp.x <= 1 and sp.y >= 0 and sp.y <= 1 then
            local sx = sp.x * w
            local sy = sp.y * h

            local alpha = math.floor((1.0 - t * t) * 255)
            local fontSize = 26 * (1.0 - t * 0.3)

            nvgFontSize(vg, fontSize)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

            local popupText = popup.text or "+50"

            -- 阴影
            nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(alpha * 0.5)))
            nvgText(vg, sx + 1, sy + 1, popupText)
            -- 文字颜色：使用 popup.color 字段，默认金色
            local pc = popup.color or { 255, 230, 50 }
            nvgFillColor(vg, nvgRGBA(pc[1], pc[2], pc[3], alpha))
            nvgText(vg, sx, sy, popupText)
        end
    end

    -- 扣血弹出
    UpdateAndDrawHitPopups(vg, w, h, dt)
end

-- ============================================================================
-- 死亡特效
-- ============================================================================

function GameUI.DrawDeathEffect(w, h)
    local vg = State.nvgCtx

    -- 红色闪屏
    if State.deathFlashAlpha > 0 then
        nvgBeginPath(vg)
        nvgRect(vg, 0, 0, w, h)
        nvgFillColor(vg, nvgRGBA(200, 30, 20, math.floor(State.deathFlashAlpha)))
        nvgFill(vg)
    end

    -- 渐入暗角
    local t = State.deathTimer / Config.DEATH_DURATION
    local vignetteAlpha = math.floor(t * 120)
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, w, h)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, vignetteAlpha))
    nvgFill(vg)
end

-- ============================================================================
-- 游戏结束画面
-- ============================================================================

function GameUI.DrawGameOver(w, h)
    local vg = State.nvgCtx
    local t = GetTime():GetElapsedTime()
    local dt = GetTime():GetTimeStep()

    -- 入场动画计时
    gameOverAnimT = gameOverAnimT + dt
    local animT = gameOverAnimT
    local isNewRecord = State.score >= State.highScore and State.score > 0

    -- ================================================================
    -- 震屏偏移（刚进入时屏幕震动）
    -- ================================================================
    local shakeX, shakeY = 0, 0
    if animT < 0.5 then
        local intensity = (1.0 - animT / 0.5) * 8
        shakeX = math.sin(animT * 50) * intensity
        shakeY = math.cos(animT * 37) * intensity
    end
    nvgSave(vg)
    nvgTranslate(vg, shakeX, shakeY)

    -- ================================================================
    -- 背景：动态渐变（暗红 → 暗紫，脉冲呼吸）
    -- ================================================================
    local bgPulse = math.sin(t * 1.2) * 0.5 + 0.5
    nvgBeginPath(vg)
    nvgRect(vg, -10, -10, w + 20, h + 20)
    local bgGrad = nvgLinearGradient(vg, 0, 0, 0, h,
        nvgRGBA(math.floor(30 + bgPulse * 20), 0, 0, 200),
        nvgRGBA(math.floor(15 + bgPulse * 10), 0, math.floor(20 + bgPulse * 15), 180))
    nvgFillPaint(vg, bgGrad)
    nvgFill(vg)

    -- ================================================================
    -- 结算粒子特效
    -- ================================================================
    GameUI.UpdateAndDrawGOParticles(vg, w, h, t, dt, isNewRecord)

    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- ================================================================
    -- 标题砸入动画：从上方弹入
    -- ================================================================
    local titleTargetY = h * 0.20
    local titleY = titleTargetY
    if animT < 0.6 then
        -- 弹簧入场
        local p = animT / 0.6
        local bounce = math.sin(p * math.pi * 2.5) * (1 - p) * 60
        titleY = -60 + (titleTargetY + 60) * math.min(1, p * 1.2) + bounce
    end

    -- 标题"游戏结束"（红色大字 + 黑色描边 + 闪光）
    nvgFontSize(vg, 56)
    -- 描边
    for _, off in ipairs({{-3,-3},{3,-3},{-3,3},{3,3},{0,-4},{0,4},{-4,0},{4,0}}) do
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 220))
        nvgText(vg, w/2 + off[1], titleY + off[2], "游戏结束")
    end
    -- 红色主体 + 脉冲高光
    local titlePulse = math.sin(t * 4) * 0.3 + 0.7
    nvgFillColor(vg, nvgRGBA(255, math.floor(50 + titlePulse * 40), math.floor(30 + titlePulse * 30), 255))
    nvgText(vg, w/2, titleY, "游戏结束")

    -- ================================================================
    -- 统计数据：分数滚动 + 逐行弹入
    -- ================================================================
    local statsStartY = h * 0.38
    local lineH = 42

    -- 分数（滚动计数动画）
    local scoreDisplay = State.score
    if animT < 1.5 then
        local countProgress = math.min(1.0, (animT - 0.3) / 1.0)
        if countProgress < 0 then countProgress = 0 end
        -- 缓出
        countProgress = 1.0 - (1.0 - countProgress) * (1.0 - countProgress)
        scoreDisplay = math.floor(State.score * countProgress)
    end

    -- 第1行：得分
    local row1Alpha = math.floor(math.min(1, math.max(0, (animT - 0.2) * 4)) * 255)
    local row1Slide = math.floor(math.max(0, 1.0 - (animT - 0.2) * 4) * 40)
    nvgFontSize(vg, 32)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(row1Alpha * 0.5)))
    nvgText(vg, w/2 + 2 - row1Slide, statsStartY + 2, "🏅 得分: " .. scoreDisplay)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, row1Alpha))
    nvgText(vg, w/2 - row1Slide, statsStartY, "🏅 得分: " .. scoreDisplay)

    -- 第2行：金币
    local row2Alpha = math.floor(math.min(1, math.max(0, (animT - 0.5) * 4)) * 255)
    local row2Slide = math.floor(math.max(0, 1.0 - (animT - 0.5) * 4) * 40)
    nvgFontSize(vg, 24)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(row2Alpha * 0.4)))
    nvgText(vg, w/2 + 1 + row2Slide, statsStartY + lineH + 1, "🪙 金币: " .. State.coins)
    nvgFillColor(vg, nvgRGBA(255, 220, 50, row2Alpha))
    nvgText(vg, w/2 + row2Slide, statsStartY + lineH, "🪙 金币: " .. State.coins)

    -- 第3行：距离
    local row3Alpha = math.floor(math.min(1, math.max(0, (animT - 0.8) * 4)) * 255)
    local row3Slide = math.floor(math.max(0, 1.0 - (animT - 0.8) * 4) * 40)
    nvgFontSize(vg, 22)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(row3Alpha * 0.4)))
    nvgText(vg, w/2 + 1 - row3Slide, statsStartY + lineH * 2 + 1, string.format("📏 距离: %.0f 米", State.distanceTraveled))
    nvgFillColor(vg, nvgRGBA(180, 220, 255, row3Alpha))
    nvgText(vg, w/2 - row3Slide, statsStartY + lineH * 2, string.format("📏 距离: %.0f 米", State.distanceTraveled))

    -- 第4行：速度记录
    local row4Alpha = math.floor(math.min(1, math.max(0, (animT - 1.0) * 4)) * 255)
    nvgFontSize(vg, 18)
    nvgFillColor(vg, nvgRGBA(160, 180, 200, row4Alpha))
    nvgText(vg, w/2, statsStartY + lineH * 3, string.format("⚡ 最高速度: %.0f km/h", State.runSpeed * 3.6))

    -- ================================================================
    -- 新纪录 / 最高分
    -- ================================================================
    local recordY = statsStartY + lineH * 4 + 10
    local row5Alpha = math.floor(math.min(1, math.max(0, (animT - 1.3) * 3)) * 255)

    if isNewRecord then
        -- 新纪录！！ 超级闪烁彩虹
        local hue = (t * 120) % 360
        local nr, ng, nb = GameUI.HSVtoRGB(hue, 0.8, 1.0)
        local recBounce = math.sin(t * 5) * 4
        local recScale = 1.0 + math.sin(t * 6) * 0.08

        nvgFontSize(vg, 30 * recScale)
        -- 光晕
        nvgFillColor(vg, nvgRGBA(nr, ng, nb, math.floor(row5Alpha * 0.3)))
        nvgText(vg, w/2, recordY + recBounce, "🎉🎉 新纪录!!! 🎉🎉")
        -- 描边
        for _, off in ipairs({{-2,-2},{2,-2},{-2,2},{2,2}}) do
            nvgFillColor(vg, nvgRGBA(0, 0, 0, row5Alpha))
            nvgText(vg, w/2 + off[1], recordY + off[2] + recBounce, "🎉🎉 新纪录!!! 🎉🎉")
        end
        -- 彩虹主体
        nvgFillColor(vg, nvgRGBA(nr, ng, nb, row5Alpha))
        nvgText(vg, w/2, recordY + recBounce, "🎉🎉 新纪录!!! 🎉🎉")
    else
        nvgFontSize(vg, 22)
        nvgFillColor(vg, nvgRGBA(180, 180, 180, row5Alpha))
        nvgText(vg, w/2, recordY, "🏆 最高分: " .. State.highScore)
    end

    -- ================================================================
    -- 重新开始提示文字（1.5秒后出现，闪烁呼吸）
    -- ================================================================
    if animT > 1.5 then
        local btnAlpha = math.floor(math.min(1, (animT - 1.5) * 3) * 255)
        local promptY = h * 0.82
        local promptFlicker = math.floor(140 + math.sin(t * 3.5) * 115)
        local finalAlpha = math.floor(btnAlpha * promptFlicker / 255)

        nvgFontSize(vg, 24)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(finalAlpha * 0.5)))
        nvgText(vg, w/2 + 1, promptY + 1, "按下空格，再来一局！")
        nvgFillColor(vg, nvgRGBA(255, 255, 255, finalAlpha))
        nvgText(vg, w/2, promptY, "按下空格，再来一局！")
    end

    nvgRestore(vg)
end

-- ============================================================================
-- 结算画面粒子系统
-- ============================================================================

function GameUI.UpdateAndDrawGOParticles(vg, w, h, t, dt, isNewRecord)
    -- 新纪录时疯狂生成庆祝粒子
    local spawnRate = isNewRecord and 0.6 or 0.15
    if #goParticles < 30 and math.random() < spawnRate then
        local emoji = isNewRecord
            and ({"🎉", "🌟", "✨", "🔥", "💥", "🏆", "⭐", "💎"})[math.random(1, 8)]
            or  ({"💀", "💔", "😵", "🔥"})[math.random(1, 4)]
        table.insert(goParticles, {
            emoji = emoji,
            x = math.random() * w,
            y = isNewRecord and (h + 20) or (-20),
            vx = (math.random() - 0.5) * 60,
            vy = isNewRecord and (-80 - math.random() * 120) or (40 + math.random() * 60),
            life = 0,
            maxLife = 1.5 + math.random() * 1.5,
            size = 20 + math.random() * 18,
            rot = math.random() * 360,
            rotSpeed = (math.random() - 0.5) * 200,
        })
    end

    local toRemove = {}
    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    for i, p in ipairs(goParticles) do
        p.life = p.life + dt
        if p.life >= p.maxLife then
            table.insert(toRemove, i)
        else
            p.x = p.x + p.vx * dt
            p.vy = p.vy + 30 * dt  -- 轻微重力
            p.y = p.y + p.vy * dt
            p.rot = p.rot + p.rotSpeed * dt

            local fade = 1.0 - (p.life / p.maxLife)
            local alpha = math.floor(fade * fade * 200)
            nvgFontSize(vg, p.size * (0.7 + fade * 0.3))
            nvgFillColor(vg, nvgRGBA(255, 255, 255, alpha))
            nvgText(vg, p.x, p.y, p.emoji)
        end
    end
    for i = #toRemove, 1, -1 do
        table.remove(goParticles, toRemove[i])
    end
end

-- ============================================================================
-- 速度视觉特效系统（速度线 + 起飞闪光 + 边缘暗角）
-- ============================================================================

--- 统一入口：更新 + 绘制所有速度特效
function GameUI.UpdateAndDrawSpeedFX(vg, w, h)
    local dt = GetTime():GetTimeStep()

    -- 速度线 intensity 平滑过渡（向目标强度插值）
    if State.fxSpeedLines then
        local target = State.fxSpeedLineTargetIntensity or 1.0
        State.fxSpeedLineIntensity = State.fxSpeedLineIntensity
            + (target - State.fxSpeedLineIntensity) * 3.0 * dt
    else
        State.fxSpeedLineIntensity = math.max(0.0, State.fxSpeedLineIntensity - dt * 3.0)
    end

    -- 暗角平滑过渡
    State.fxVignetteAlpha = State.fxVignetteAlpha + (State.fxVignetteTarget - State.fxVignetteAlpha) * 4.0 * dt

    -- 闪光计时
    if State.fxFlashTimer > 0 then
        State.fxFlashTimer = State.fxFlashTimer - dt
    end

    -- 绘制各层
    if State.fxSpeedLineIntensity > 0.01 then
        GameUI.DrawSpeedLines(vg, w, h)
    end
    if State.fxFlashTimer > 0 then
        GameUI.DrawLaunchFlash(vg, w, h)
    end
    if State.fxVignetteAlpha > 0.01 then
        GameUI.DrawSpeedVignette(vg, w, h)
    end
end

--- 速度线：从屏幕中心向四周放射的半透明线条
function GameUI.DrawSpeedLines(vg, w, h)
    local cx, cy = w * 0.5, h * 0.5
    local intensity = State.fxSpeedLineIntensity
    local color = State.fxSpeedLineColor
    local elapsed = GetTime():GetElapsedTime()
    local maxR = math.sqrt(cx * cx + cy * cy)
    local count = math.floor(20 + intensity * 15)

    nvgSave(vg)
    for i = 1, count do
        -- 每根线的角度（均匀分布 + 时间旋转 + 随机抖动）
        local baseAngle = (i / count) * math.pi * 2
        local angle = baseAngle + elapsed * 1.5 + math.sin(elapsed * 3.0 + i * 0.7) * 0.1

        -- 线条从中间偏外开始，延伸到边缘（模拟速度隧道）
        local innerFactor = 0.3 + (math.sin(elapsed * 2.0 + i) * 0.5 + 0.5) * 0.15
        local outerFactor = 0.7 + (math.sin(elapsed * 1.5 + i * 1.3) * 0.5 + 0.5) * 0.3
        local innerR = maxR * innerFactor
        local outerR = maxR * outerFactor

        local x1 = cx + math.cos(angle) * innerR
        local y1 = cy + math.sin(angle) * innerR
        local x2 = cx + math.cos(angle) * outerR
        local y2 = cy + math.sin(angle) * outerR

        -- alpha 随 intensity 和每根线的随机性变化
        local lineAlpha = intensity * (0.3 + math.random() * 0.4)
        local a = math.floor(lineAlpha * 255)

        nvgBeginPath(vg)
        nvgMoveTo(vg, x1, y1)
        nvgLineTo(vg, x2, y2)
        nvgStrokeColor(vg, nvgRGBA(color[1], color[2], color[3], a))
        nvgStrokeWidth(vg, 1.0 + math.random() * 2.0)
        nvgStroke(vg)
    end
    nvgRestore(vg)
end

--- 起飞闪光：触发峡谷跳跃瞬间的全屏青白色闪光
function GameUI.DrawLaunchFlash(vg, w, h)
    local t = State.fxFlashTimer / Config.CANYON_FX_FLASH_DURATION  -- 1→0
    local alpha = math.floor(t * t * 200)  -- 二次衰减，前段很亮
    if alpha <= 0 then return end

    local c = State.fxFlashColor
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, w, h)
    nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], alpha))
    nvgFill(vg)
end

--- 边缘暗角：飞行/大运时屏幕四周变暗，营造隧道视觉聚焦
function GameUI.DrawSpeedVignette(vg, w, h)
    local alpha = State.fxVignetteAlpha
    local edgeAlpha = math.floor(alpha * 180)
    if edgeAlpha <= 0 then return end

    local bandW = w * 0.18  -- 暗角带宽度
    local bandH = h * 0.15

    -- 左边缘
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, bandW, h)
    local paintL = nvgLinearGradient(vg, 0, 0, bandW, 0,
        nvgRGBA(0, 0, 0, edgeAlpha), nvgRGBA(0, 0, 0, 0))
    nvgFillPaint(vg, paintL)
    nvgFill(vg)

    -- 右边缘
    nvgBeginPath(vg)
    nvgRect(vg, w - bandW, 0, bandW, h)
    local paintR = nvgLinearGradient(vg, w, 0, w - bandW, 0,
        nvgRGBA(0, 0, 0, edgeAlpha), nvgRGBA(0, 0, 0, 0))
    nvgFillPaint(vg, paintR)
    nvgFill(vg)

    -- 上边缘
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, w, bandH)
    local paintT = nvgLinearGradient(vg, 0, 0, 0, bandH,
        nvgRGBA(0, 0, 0, edgeAlpha), nvgRGBA(0, 0, 0, 0))
    nvgFillPaint(vg, paintT)
    nvgFill(vg)

    -- 下边缘
    nvgBeginPath(vg)
    nvgRect(vg, 0, h - bandH, w, bandH)
    local paintB = nvgLinearGradient(vg, 0, h, 0, h - bandH,
        nvgRGBA(0, 0, 0, edgeAlpha), nvgRGBA(0, 0, 0, 0))
    nvgFillPaint(vg, paintB)
    nvgFill(vg)
end

return GameUI
