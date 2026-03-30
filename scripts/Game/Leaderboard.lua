-- ============================================================================
-- Game/Leaderboard.lua — 排行榜模块（云变量 + NanoVG 绘制）
-- ============================================================================

local Config = require "Game.Config"
local State  = require "Game.State"

local Leaderboard = {}

-- 排行榜数据
local rankList = {}         -- { rank, userId, nickname, score, isMe }
local myRank = nil          -- 我的排名 (number or nil)
local myScore = nil         -- 我的分数
local isLoading = false     -- 是否正在加载
local loadError = false     -- 是否加载失败
local lastFetchTime = 0     -- 上次加载时间（防止频繁请求）
local FETCH_COOLDOWN = 10   -- 最短请求间隔（秒）

-- ============================================================================
-- 数据接口
-- ============================================================================

--- 启动时从云端加载历史最高分到 State.highScore
function Leaderboard.LoadHighScore()
    if not clientCloud then
        print("[Leaderboard] clientCloud not available, skip loading high score")
        return
    end
    clientCloud:Get("high_score", {
        ok = function(values, iscores)
            local cloudScore = iscores.high_score or 0
            if cloudScore > State.highScore then
                State.highScore = cloudScore
                print("[Leaderboard] Loaded cloud high score: " .. cloudScore)
            end
        end,
        error = function(code, reason)
            print("[Leaderboard] Load high score failed: " .. tostring(reason))
        end
    })
end

--- 上传分数（游戏结束时调用）
function Leaderboard.UploadScore(score)
    if not clientCloud then
        print("[Leaderboard] clientCloud not available")
        return
    end
    -- 只在新高分时更新
    clientCloud:Get("high_score", {
        ok = function(values, iscores)
            local current = iscores.high_score or 0
            if score > current then
                clientCloud:SetInt("high_score", score, {
                    ok = function()
                        print("[Leaderboard] High score updated: " .. score)
                    end,
                    error = function(code, reason)
                        print("[Leaderboard] Upload error: " .. tostring(reason))
                    end
                })
            end
        end,
        error = function(code, reason)
            -- 第一次玩，直接写入
            clientCloud:SetInt("high_score", score, {
                ok = function()
                    print("[Leaderboard] First score saved: " .. score)
                end
            })
        end
    })
end

--- 加载排行榜数据
function Leaderboard.Fetch()
    if not clientCloud then
        print("[Leaderboard] clientCloud not available")
        loadError = true
        return
    end

    local now = GetTime():GetElapsedTime()
    if isLoading or (now - lastFetchTime < FETCH_COOLDOWN and #rankList > 0) then
        return  -- 冷却中或正在加载，跳过
    end

    isLoading = true
    loadError = false
    lastFetchTime = now

    clientCloud:GetRankList("high_score", 0, 10, {
        ok = function(list)
            local tempList = {}
            local userIds = {}
            for i, item in ipairs(list) do
                table.insert(tempList, {
                    rank = i,
                    userId = item.userId,
                    nickname = nil,
                    score = item.iscore.high_score or 0,
                    isMe = item.userId == clientCloud.userId,
                })
                table.insert(userIds, item.userId)
            end

            -- 获取我的排名
            clientCloud:GetUserRank(clientCloud.userId, "high_score", {
                ok = function(rank, scoreValue)
                    myRank = rank
                    myScore = scoreValue
                end,
            })

            if #userIds == 0 then
                rankList = tempList
                isLoading = false
                return
            end

            -- 查询昵称
            GetUserNickname({
                userIds = userIds,
                onSuccess = function(nicknames)
                    local map = {}
                    for _, info in ipairs(nicknames) do
                        map[info.userId] = info.nickname or ""
                    end
                    for _, entry in ipairs(tempList) do
                        entry.nickname = map[entry.userId] or "玩家"
                    end
                    rankList = tempList
                    isLoading = false
                end,
                onError = function(errorCode)
                    -- 昵称失败，仍显示排行榜
                    for _, entry in ipairs(tempList) do
                        entry.nickname = "玩家"
                    end
                    rankList = tempList
                    isLoading = false
                end
            })
        end,
        error = function(code, reason)
            print("[Leaderboard] Fetch error: " .. tostring(reason))
            isLoading = false
            loadError = true
        end
    })
end

-- ============================================================================
-- NanoVG 绘制（右侧半透明排行榜面板）
-- ============================================================================

--- 绘制排行榜面板
--- @param vg userdata NanoVG context
--- @param w number 屏幕宽度
--- @param h number 屏幕高度
--- @param panelAlpha number 面板整体透明度 0~255（用于入场淡入）
function Leaderboard.Draw(vg, w, h, panelAlpha)
    panelAlpha = panelAlpha or 255
    if panelAlpha <= 0 then return end

    local t = GetTime():GetElapsedTime()

    -- 面板尺寸和位置（右侧）
    local panelW = math.min(380, w * 0.38)
    local panelH = math.min(520, h * 0.88)
    local panelX = w - panelW - 20
    local panelY = (h - panelH) / 2

    nvgSave(vg)

    -- ================================================================
    -- 面板背景（圆角半透明 + 模糊边框）
    -- ================================================================
    nvgBeginPath(vg)
    nvgRoundedRect(vg, panelX, panelY, panelW, panelH, 14)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(160 * panelAlpha / 255)))
    nvgFill(vg)

    -- 边框（金色渐变脉冲）
    local borderPulse = math.sin(t * 2) * 0.3 + 0.7
    nvgStrokeWidth(vg, 1.5)
    nvgStrokeColor(vg, nvgRGBA(255, 200, 80,
        math.floor(100 * borderPulse * panelAlpha / 255)))
    nvgStroke(vg)

    -- ================================================================
    -- 标题
    -- ================================================================
    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 28)

    local titleY = panelY + 32
    -- 金色奖杯标题
    nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(180 * panelAlpha / 255)))
    nvgText(vg, panelX + panelW / 2 + 1, titleY + 1, "🏆 排行榜")
    nvgFillColor(vg, nvgRGBA(255, 210, 60, panelAlpha))
    nvgText(vg, panelX + panelW / 2, titleY, "🏆 排行榜")

    -- 分割线
    nvgBeginPath(vg)
    local lineY = titleY + 24
    nvgMoveTo(vg, panelX + 16, lineY)
    nvgLineTo(vg, panelX + panelW - 16, lineY)
    nvgStrokeColor(vg, nvgRGBA(255, 200, 80, math.floor(60 * panelAlpha / 255)))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    -- ================================================================
    -- 排行榜内容
    -- ================================================================
    local contentY = lineY + 16
    local rowH = 40

    if isLoading and #rankList == 0 then
        -- 加载中
        nvgFontSize(vg, 20)
        nvgFillColor(vg, nvgRGBA(180, 180, 180, panelAlpha))
        nvgText(vg, panelX + panelW / 2, panelY + panelH / 2, "加载中...")
    elseif loadError and #rankList == 0 then
        -- 加载失败
        nvgFontSize(vg, 20)
        nvgFillColor(vg, nvgRGBA(255, 100, 100, panelAlpha))
        nvgText(vg, panelX + panelW / 2, panelY + panelH / 2, "加载失败")
    elseif #rankList == 0 then
        -- 暂无数据
        nvgFontSize(vg, 20)
        nvgFillColor(vg, nvgRGBA(160, 160, 160, panelAlpha))
        nvgText(vg, panelX + panelW / 2, panelY + panelH / 2, "暂无排行数据")
    else
        -- 绘制每行
        for i, entry in ipairs(rankList) do
            local rowY = contentY + (i - 1) * rowH + rowH / 2

            if rowY > panelY + panelH - 40 then break end  -- 超出面板

            -- 高亮自己的行
            if entry.isMe then
                nvgBeginPath(vg)
                nvgRoundedRect(vg, panelX + 8, rowY - rowH / 2 + 2,
                    panelW - 16, rowH - 4, 6)
                nvgFillColor(vg, nvgRGBA(255, 200, 50, math.floor(30 * panelAlpha / 255)))
                nvgFill(vg)
            elseif i % 2 == 0 then
                -- 交替行背景
                nvgBeginPath(vg)
                nvgRoundedRect(vg, panelX + 8, rowY - rowH / 2 + 2,
                    panelW - 16, rowH - 4, 4)
                nvgFillColor(vg, nvgRGBA(255, 255, 255, math.floor(8 * panelAlpha / 255)))
                nvgFill(vg)
            end

            -- 排名（左侧）
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 22)
            local rankIcon
            if i == 1 then rankIcon = "🥇"
            elseif i == 2 then rankIcon = "🥈"
            elseif i == 3 then rankIcon = "🥉"
            else rankIcon = string.format(" %d", i) end

            nvgFillColor(vg, nvgRGBA(255, 255, 255, panelAlpha))
            nvgText(vg, panelX + 16, rowY, rankIcon)

            -- 昵称（中间，截断）
            nvgFontSize(vg, 18)
            local nameColor = entry.isMe
                and nvgRGBA(255, 220, 80, panelAlpha)
                or  nvgRGBA(220, 230, 255, panelAlpha)
            nvgFillColor(vg, nameColor)

            local displayName = entry.nickname or "玩家"
            -- 截断过长昵称（大约8个汉字宽度）
            nvgText(vg, panelX + 56, rowY, displayName)

            -- 分数（右侧）
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 18)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, panelAlpha))
            nvgText(vg, panelX + panelW - 14, rowY, tostring(entry.score))
        end

        -- ================================================================
        -- 我的排名（底部）
        -- ================================================================
        local footerY = panelY + panelH - 30
        nvgBeginPath(vg)
        nvgMoveTo(vg, panelX + 16, footerY - 12)
        nvgLineTo(vg, panelX + panelW - 16, footerY - 12)
        nvgStrokeColor(vg, nvgRGBA(255, 200, 80, math.floor(40 * panelAlpha / 255)))
        nvgStrokeWidth(vg, 1)
        nvgStroke(vg)

        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(vg, 18)
        if myRank then
            nvgFillColor(vg, nvgRGBA(255, 220, 80, panelAlpha))
            nvgText(vg, panelX + panelW / 2, footerY,
                string.format("我的排名: #%d  分数: %d", myRank, myScore or 0))
        else
            nvgFillColor(vg, nvgRGBA(160, 160, 160, panelAlpha))
            nvgText(vg, panelX + panelW / 2, footerY, "尚未上榜")
        end
    end

    nvgRestore(vg)
end

return Leaderboard
