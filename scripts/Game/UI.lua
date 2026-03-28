-- ============================================================================
-- Game/UI.lua — NanoVG UI 渲染
-- ============================================================================

local Config = require "Game.Config"
local State  = require "Game.State"

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

    -- 磁铁激活状态指示
    if State.magnetActive then
        local magnetAlpha = 255
        -- 最后2秒闪烁提示即将结束
        if State.magnetTimer < 2.0 then
            magnetAlpha = math.floor(math.abs(math.sin(GetTime():GetElapsedTime() * 6)) * 255)
        end
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFontSize(vg, 20)
        nvgFillColor(vg, nvgRGBA(80, 160, 255, magnetAlpha))
        local remainText = string.format("🧲 %.1fs", State.magnetTimer)
        nvgText(vg, w / 2 + 50, 35, remainText)
    end

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
            -- 文字颜色：心心红色、磁铁蓝色、金币金色
            if popup.text == "+❤️" then
                nvgFillColor(vg, nvgRGBA(255, 80, 80, alpha))
            elseif popup.text and popup.text:find("磁铁") then
                nvgFillColor(vg, nvgRGBA(80, 160, 255, alpha))
            else
                nvgFillColor(vg, nvgRGBA(255, 230, 50, alpha))
            end
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

return GameUI
