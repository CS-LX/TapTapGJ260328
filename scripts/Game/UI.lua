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

function GameUI.Render(eventType, eventData)
    if State.nvgCtx == nil then return end

    local g = GetGraphics()
    local physW = g:GetWidth()
    local physH = g:GetHeight()

    nvgBeginFrame(State.nvgCtx, physW, physH, 1.0)

    if State.gameState == Config.STATE_MENU then
        GameUI.DrawMenu(physW, physH)
    elseif State.gameState == Config.STATE_PLAYING then
        GameUI.DrawHUD(physW, physH)
    elseif State.gameState == Config.STATE_DYING then
        GameUI.DrawHUD(physW, physH)
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
local MENU_EMOJIS = {"🏃", "💨", "🚛", "🦅", "⚡", "🔥", "💥", "🪙"}
local MENU_SLOGANS = {
    "🦅 飞跃大峡谷",
    "🚛 大运狂飙碾压一切",
    "⚡ 极速 180 停不下来",
}

function GameUI.DrawMenu(w, h)
    local vg = State.nvgCtx
    local t = GetTime():GetElapsedTime()

    -- ================================================================
    -- 背景渐变遮罩（上深下浅，不是死板全黑）
    -- ================================================================
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, w, h)
    local bgGrad = nvgLinearGradient(vg, 0, 0, 0, h,
        nvgRGBA(0, 0, 0, 160), nvgRGBA(10, 15, 40, 80))
    nvgFillPaint(vg, bgGrad)
    nvgFill(vg)

    -- ================================================================
    -- 背景速度线（淡淡几条营造速度氛围）
    -- ================================================================
    GameUI.DrawMenuSpeedLines(vg, w, h, t)

    -- ================================================================
    -- 飘过的 Emoji 装饰粒子
    -- ================================================================
    GameUI.UpdateAndDrawMenuParticles(vg, w, h, t)

    -- ================================================================
    -- 主标题：「似腿快跑！！」
    -- ================================================================
    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 标题布局基准
    local titleY = h * 0.28
    local bounce = math.sin(t * 2.5) * 6  -- 弹跳
    local tilt = math.sin(t * 1.8) * 1.5  -- 轻微摇摆角度（用位移模拟）

    -- 发光光晕（底层大字模糊效果）
    local glowPulse = 0.6 + math.sin(t * 4) * 0.4
    local glowAlpha = math.floor(glowPulse * 60)
    nvgFontSize(vg, 72)
    nvgFillColor(vg, nvgRGBA(255, 160, 30, glowAlpha))
    nvgText(vg, w/2 + tilt, titleY + bounce, "似腿快跑！！")

    -- 黑色描边（多层阴影模拟粗描边）
    nvgFontSize(vg, 64)
    for _, off in ipairs({{-3,-3},{3,-3},{-3,3},{3,3},{0,-4},{0,4},{-4,0},{4,0}}) do
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 200))
        nvgText(vg, w/2 + off[1] + tilt, titleY + off[2] + bounce, "似腿快跑！！")
    end

    -- 主标题金色渐变（用两层颜色模拟渐变效果）
    -- 上半金黄
    nvgFillColor(vg, nvgRGBA(255, 230, 50, 255))
    nvgText(vg, w/2 + tilt, titleY + bounce, "似腿快跑！！")
    -- 叠加橙色层（下方偏移一像素）
    nvgFillColor(vg, nvgRGBA(255, 150, 20, 100))
    nvgText(vg, w/2 + tilt, titleY + bounce + 2, "似腿快跑！！")

    -- ================================================================
    -- 特色标语轮播
    -- ================================================================
    local sloganIdx = math.floor(t / 2.5) % #MENU_SLOGANS + 1
    local sloganT = (t % 2.5) / 2.5  -- 0→1 within each cycle
    -- 淡入淡出：前0.2淡入，后0.2淡出，中间全亮
    local sloganAlpha = 255
    if sloganT < 0.15 then
        sloganAlpha = math.floor(sloganT / 0.15 * 255)
    elseif sloganT > 0.85 then
        sloganAlpha = math.floor((1.0 - sloganT) / 0.15 * 255)
    end

    local sloganY = titleY + 55
    nvgFontSize(vg, 22)
    -- 标语阴影
    nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(sloganAlpha * 0.5)))
    nvgText(vg, w/2 + 1, sloganY + 1, MENU_SLOGANS[sloganIdx])
    -- 标语本体（青白色）
    nvgFillColor(vg, nvgRGBA(180, 230, 255, sloganAlpha))
    nvgText(vg, w/2, sloganY, MENU_SLOGANS[sloganIdx])

    -- ================================================================
    -- 开始按钮（脉冲发光 + 呼吸缩放）
    -- ================================================================
    local btnCenterY = h * 0.58
    local breathe = 1.0 + math.sin(t * 3.5) * 0.06  -- 呼吸缩放
    local btnFontSize = 28 * breathe
    local pulseAlpha = math.floor((0.4 + math.sin(t * 3.5) * 0.3) * 255)

    -- 按钮光环
    local ringW = 220 * breathe
    local ringH = 52 * breathe
    nvgBeginPath(vg)
    nvgRoundedRect(vg, w/2 - ringW/2, btnCenterY - ringH/2, ringW, ringH, ringH/2)
    -- 外发光
    nvgStrokeColor(vg, nvgRGBA(255, 200, 50, pulseAlpha))
    nvgStrokeWidth(vg, 2.5)
    nvgStroke(vg)
    -- 内填充
    local btnGrad = nvgLinearGradient(vg, w/2, btnCenterY - ringH/2, w/2, btnCenterY + ringH/2,
        nvgRGBA(255, 200, 50, 50), nvgRGBA(255, 120, 20, 30))
    nvgFillPaint(vg, btnGrad)
    nvgFill(vg)

    -- 按钮文字
    nvgFontSize(vg, btnFontSize)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 180))
    nvgText(vg, w/2 + 1, btnCenterY + 1, "▶  点击开始  ▶")
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, w/2, btnCenterY, "▶  点击开始  ▶")

    -- ================================================================
    -- 最高分（金色奖杯样式）
    -- ================================================================
    if State.highScore > 0 then
        local hsY = h * 0.72
        nvgFontSize(vg, 20)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 120))
        nvgText(vg, w/2 + 1, hsY + 1, "🏆 最高分: " .. State.highScore)
        nvgFillColor(vg, nvgRGBA(255, 210, 80, 230))
        nvgText(vg, w/2, hsY, "🏆 最高分: " .. State.highScore)
    end

    -- ================================================================
    -- 操作指南（底部精简一行）
    -- ================================================================
    nvgFontSize(vg, 13)
    nvgFillColor(vg, nvgRGBA(180, 180, 180, 140))
    nvgText(vg, w/2, h - 40, "↔ 切道  |  ↑/空格 跳跃  |  ↓ 下蹲  |  触屏滑动操作")

    -- ================================================================
    -- BGM 开关按钮（右上角）
    -- ================================================================
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
-- 菜单背景速度线（淡淡的水平速度氛围）
-- ============================================================================

function GameUI.DrawMenuSpeedLines(vg, w, h, t)
    nvgSave(vg)
    local lineCount = 12
    for i = 1, lineCount do
        -- 每条线在不同 Y 位置，从右往左
        local seed = i * 137.5
        local y = (math.sin(seed) * 0.5 + 0.5) * h
        local speed = 80 + (math.sin(seed * 0.7) * 0.5 + 0.5) * 120
        local x = w - ((t * speed + seed * 3) % (w + 200)) + 100
        local lineLen = 40 + (math.sin(seed * 1.3) * 0.5 + 0.5) * 80
        local alpha = math.floor(15 + math.sin(t * 2 + i) * 10)

        nvgBeginPath(vg)
        nvgMoveTo(vg, x, y)
        nvgLineTo(vg, x + lineLen, y)
        nvgStrokeColor(vg, nvgRGBA(200, 220, 255, alpha))
        nvgStrokeWidth(vg, 1.0 + math.sin(seed) * 0.5)
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
-- 游戏 HUD
-- ============================================================================

function GameUI.DrawHUD(w, h)
    local vg = State.nvgCtx

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

    -- 爱心血条
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 28)
    local heartStr = ""
    for i = 1, Config.MAX_HEALTH do
        if i <= State.health then
            heartStr = heartStr .. "❤️"
        else
            heartStr = heartStr .. "🖤"
        end
    end
    nvgText(vg, 20, 25, heartStr)

    -- 得分
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

    -- 半透明背景
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, w, h)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 160))
    nvgFill(vg)

    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- Game Over 标题
    nvgFontSize(vg, 48)
    nvgFillColor(vg, nvgRGBA(255, 80, 80, 255))
    nvgText(vg, w/2, h/2 - 80, "游戏结束")

    -- 得分
    nvgFontSize(vg, 28)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 230))
    nvgText(vg, w/2, h/2 - 20, "得分: " .. State.score)

    -- 金币
    nvgFontSize(vg, 22)
    nvgFillColor(vg, nvgRGBA(255, 220, 50, 255))
    nvgText(vg, w/2, h/2 + 20, "金币: " .. State.coins)

    -- 距离
    nvgFontSize(vg, 20)
    nvgFillColor(vg, nvgRGBA(200, 200, 200, 200))
    nvgText(vg, w/2, h/2 + 55, string.format("距离: %.0f 米", State.distanceTraveled))

    -- 最高分
    nvgFontSize(vg, 22)
    if State.score >= State.highScore then
        nvgFillColor(vg, nvgRGBA(255, 200, 50, 255))
        nvgText(vg, w/2, h/2 + 90, "★ 新纪录! ★")
    else
        nvgFillColor(vg, nvgRGBA(180, 180, 180, 200))
        nvgText(vg, w/2, h/2 + 90, "最高分: " .. State.highScore)
    end

    -- 重新开始提示（闪烁）
    local t = GetTime():GetElapsedTime()
    local alpha = math.floor(math.abs(math.sin(t * 3)) * 255)
    nvgFontSize(vg, 22)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, alpha))
    nvgText(vg, w/2, h/2 + 140, "点击或按空格重新开始")
end

-- ============================================================================
-- 速度视觉特效系统（速度线 + 起飞闪光 + 边缘暗角）
-- ============================================================================

--- 统一入口：更新 + 绘制所有速度特效
function GameUI.UpdateAndDrawSpeedFX(vg, w, h)
    local dt = GetTime():GetTimeStep()

    -- 速度线 intensity 平滑过渡
    if State.fxSpeedLines then
        State.fxSpeedLineIntensity = math.min(1.0, State.fxSpeedLineIntensity + dt * 3.0)
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
