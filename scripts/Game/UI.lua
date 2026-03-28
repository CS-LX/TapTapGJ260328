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

function GameUI.DrawMenu(w, h)
    local vg = State.nvgCtx

    -- 半透明背景
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, w, h)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 120))
    nvgFill(vg)

    -- 标题
    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 标题阴影
    nvgFontSize(vg, 56)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 150))
    nvgText(vg, w/2 + 2, h/2 - 78, "地铁跑酷")

    -- 标题
    nvgFillColor(vg, nvgRGBA(255, 220, 50, 255))
    nvgText(vg, w/2, h/2 - 80, "地铁跑酷")

    -- 副标题
    nvgFontSize(vg, 18)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 200))
    nvgText(vg, w/2, h/2 - 30, "SUBWAY SURFERS")

    -- 开始提示（闪烁）
    local t = GetTime():GetElapsedTime()
    local alpha = math.floor(math.abs(math.sin(t * 3)) * 255)
    nvgFontSize(vg, 24)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, alpha))
    nvgText(vg, w/2, h/2 + 40, "点击屏幕或按空格开始")

    -- 操作说明
    nvgFontSize(vg, 14)
    nvgFillColor(vg, nvgRGBA(200, 200, 200, 180))
    nvgText(vg, w/2, h/2 + 90, "← → 切换跑道  |  ↑/空格 跳跃  |  ↓ 下蹲")
    nvgText(vg, w/2, h/2 + 115, "触屏: 左右滑动切道 | 上滑跳跃 | 下滑下蹲")

    -- 最高分
    if State.highScore > 0 then
        nvgFontSize(vg, 18)
        nvgFillColor(vg, nvgRGBA(255, 200, 100, 220))
        nvgText(vg, w/2, h/2 + 150, "最高分: " .. State.highScore)
    end

    -- BGM 开关按钮（右上角）
    local btnW, btnH = 44, 44
    local btnX = w - btnW - 16
    local btnY = 16
    State.bgmBtnRect = { x = btnX, y = btnY, w = btnW, h = btnH }

    -- 按钮背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, btnX, btnY, btnW, btnH, 8)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 30))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 80))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)

    -- 图标
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    if BGM.IsMuted() then
        nvgFillColor(vg, nvgRGBA(255, 100, 100, 200))
        nvgText(vg, btnX + btnW / 2, btnY + btnH / 2, "🔇")
    else
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 220))
        nvgText(vg, btnX + btnW / 2, btnY + btnH / 2, "🔊")
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
