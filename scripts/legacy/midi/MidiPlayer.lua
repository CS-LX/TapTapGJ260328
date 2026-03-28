------------------------------------------------------------
-- MidiPlayer.lua
-- 基于采样音频的 MIDI 播放器
-- 依赖 MidiParser 解析后的数据，通过引擎 SoundSource 播放
------------------------------------------------------------
local MidiParser = require("midi.MidiParser")

local MidiPlayer = {}
MidiPlayer.__index = MidiPlayer

------------------------------------------------------------
-- 钢琴采样路径配置
-- 采样分 Hard (强力度) 和 Soft (弱力度) 两层
-- 命名: 小写音名 + #号 + 八度, 如 c#4.ogg, a3.ogg
-- 路径: audio/Hard/<note>.ogg, audio/Soft/<note>.ogg
------------------------------------------------------------

local NOTE_NAMES_LOWER = { "c", "c#", "d", "d#", "e", "f", "f#", "g", "g#", "a", "a#", "b" }

--- Velocity 分界线: >= 此值使用 Hard 采样, < 此值使用 Soft 采样
local VELOCITY_THRESHOLD = 80

--- 根据 MIDI note number 生成采样文件名 (不含目录)
---@param noteNum integer  0-127
---@return string  如 "c#4.ogg"
local function noteToFileName(noteNum)
    local octave = math.floor(noteNum / 12) - 1
    local name   = NOTE_NAMES_LOWER[(noteNum % 12) + 1]
    return string.format("%s%d.ogg", name, octave)
end

--- 生成路径表 (note 0~127)
---@param layer string  "Hard" 或 "Soft"
---@return table<integer, string>
local function buildNotePaths(layer)
    local paths = {}
    for i = 0, 127 do
        paths[i] = string.format("audio/%s/%s", layer, noteToFileName(i))
    end
    return paths
end

--- 默认打击乐路径 (GM Channel 10 映射)
---@return table<integer, string>
local function buildDefaultPercussionPaths()
    local paths = {}
    for i = 35, 81 do
        paths[i] = string.format("Sounds/Percussion/perc_%d.ogg", i)
    end
    return paths
end

------------------------------------------------------------
-- 播放状态枚举
------------------------------------------------------------
MidiPlayer.STATE_STOPPED  = "stopped"
MidiPlayer.STATE_PLAYING  = "playing"
MidiPlayer.STATE_PAUSED   = "paused"

------------------------------------------------------------
-- 构造
------------------------------------------------------------

--- 创建播放器实例
---@param scene      Scene     场景对象 (用于创建音频节点)
---@param options?   table     可选配置
---@return table
function MidiPlayer.new(scene, options)
    options = options or {}

    local self = setmetatable({}, MidiPlayer)

    self.scene           = scene
    self.state           = MidiPlayer.STATE_STOPPED
    self.midi            = nil        -- 解析后的 MIDI 数据
    self.tempos          = nil        -- tempo 列表
    self.allEvents       = nil        -- 按时间排序的合并事件列表
    self.eventIndex      = 1          -- 当前播放到的事件索引
    self.elapsedTime     = 0.0        -- 已播放时长 (秒)
    self.totalDuration   = 0.0        -- 总时长 (秒)
    self.speed           = options.speed or 1.0
    self.volume          = options.volume or 1.0
    self.loop            = options.loop or false
    self.maxPolyphony     = options.maxPolyphony or 32   -- 最大同时发声数

    -- 音频路径映射 (双层: Hard + Soft)
    self.notePathsHard   = options.notePathsHard or buildNotePaths("Hard")
    self.notePathsSoft   = options.notePathsSoft or buildNotePaths("Soft")
    self.percussionPaths = options.percussionPaths or buildDefaultPercussionPaths()
    self.velocityThreshold = options.velocityThreshold or VELOCITY_THRESHOLD

    -- 音源架构: 每个音符 = 独立 Node + SoundSource
    -- 绝不调 Stop()、绝不在活跃源上调 Play()，避免音频缓冲区不连续导致爆音
    self.activeSources     = {}   -- 活跃音源 { node, source, note, channel, targetGain }
    self.releasingSources  = {}   -- 正在淡出的音源 { node, source, startGain, fadeFrame }
    self.silentSources     = {}   -- gain=0 等待自然结束的音源 { node, source }
    self.fadeOutFrames     = options.fadeOutFrames or 15       -- 线性淡出帧数 (~250ms@60fps)
    self.fadeInFrames      = options.fadeInFrames or 3         -- 淡入帧数 (~50ms@60fps)
    self.fadingInSources   = {}   -- 正在淡入的音源 { source, currentGain, targetGain, step }
    self.nodeCounter       = 0    -- 节点计数器 (用于命名)

    -- 轨道过滤: nil = 播放全部, 否则为 { [trackIndex]=true } 集合
    self.enabledTracks   = nil

    -- 回调
    self.onNoteOn        = options.onNoteOn        -- function(note, velocity, channel)
    self.onNoteOff       = options.onNoteOff       -- function(note, velocity, channel)
    self.onTrackEnd      = options.onTrackEnd      -- function()
    self.onTempoChange   = options.onTempoChange   -- function(bpm)

    return self
end

------------------------------------------------------------
-- 加载
------------------------------------------------------------

--- 从文件加载 MIDI
---@param filePath string  资源路径
---@return boolean success
---@return string|nil err
function MidiPlayer:load(filePath)
    local midi, err = MidiParser.parseFile(filePath)
    if not midi then
        return false, err
    end
    return self:loadFromData(midi)
end

--- 从已解析的 MIDI 数据加载
---@param midi table  MidiParser.parse() 返回的结果
---@return boolean success
---@return string|nil err
function MidiPlayer:loadFromData(midi)
    self:stop()

    self.midi   = midi
    self.tempos = MidiParser.extractTempos(midi)

    if not midi.ticksPerBeat then
        return false, "SMPTE timing not supported yet"
    end

    -- 合并所有轨道事件并按 tick 排序
    local allEvents = {}
    for ti, track in ipairs(midi.tracks) do
        for _, evt in ipairs(track.events) do
            allEvents[#allEvents + 1] = {
                tick       = evt.tick,
                trackIndex = ti,
                event      = evt,
            }
        end
    end
    table.sort(allEvents, function(a, b)
        if a.tick == b.tick then return a.trackIndex < b.trackIndex end
        return a.tick < b.tick
    end)

    self.allEvents = allEvents
    self.eventIndex = 1

    -- 计算总时长
    if #allEvents > 0 then
        local lastTick = allEvents[#allEvents].tick
        self.totalDuration = MidiParser.tickToSeconds(
            lastTick, midi.ticksPerBeat, self.tempos
        )
    else
        self.totalDuration = 0
    end

    return true
end

------------------------------------------------------------
-- 播放控制
------------------------------------------------------------

function MidiPlayer:play()
    if not self.midi then return end
    if self.state == MidiPlayer.STATE_PAUSED then
        self.state = MidiPlayer.STATE_PLAYING
        return
    end
    -- 从头播放
    self.eventIndex  = 1
    self.elapsedTime = 0.0
    self.state       = MidiPlayer.STATE_PLAYING
end

function MidiPlayer:pause()
    if self.state == MidiPlayer.STATE_PLAYING then
        self.state = MidiPlayer.STATE_PAUSED
    end
end

function MidiPlayer:resume()
    if self.state == MidiPlayer.STATE_PAUSED then
        self.state = MidiPlayer.STATE_PLAYING
    end
end

function MidiPlayer:stop()
    self.state       = MidiPlayer.STATE_STOPPED
    self.eventIndex  = 1
    self.elapsedTime = 0.0
    -- 停止所有活跃音源
    self:stopAllSources()
end

--- 跳转到指定时间 (秒)
---@param timeInSeconds number
function MidiPlayer:seek(timeInSeconds)
    if not self.midi then return end

    self.elapsedTime = math.max(0, math.min(timeInSeconds, self.totalDuration))
    self:stopAllSources()

    -- 重新定位 eventIndex
    self.eventIndex = 1
    for i, item in ipairs(self.allEvents) do
        local evtTime = MidiParser.tickToSeconds(
            item.tick, self.midi.ticksPerBeat, self.tempos
        )
        if evtTime > self.elapsedTime then
            self.eventIndex = i
            return
        end
    end
    self.eventIndex = #self.allEvents + 1
end

------------------------------------------------------------
-- 帧更新 (在 HandleUpdate 中调用)
------------------------------------------------------------

--- 每帧调用，驱动 MIDI 事件播放
---@param dt number  帧间隔时间 (秒)
function MidiPlayer:update(dt)
    if self.state ~= MidiPlayer.STATE_PLAYING then return end
    if not self.midi or not self.allEvents then return end

    self.elapsedTime = self.elapsedTime + dt * self.speed

    -- 处理淡入淡出 & 清理已结束的音源
    self:fadeFadeInSources()
    self:fadeReleasingSources()
    self:cleanupSilentSources()

    -- 触发当前时间之前的所有事件
    local ticksPerBeat = self.midi.ticksPerBeat
    local filter = self.enabledTracks  -- nil = 不过滤
    while self.eventIndex <= #self.allEvents do
        local item = self.allEvents[self.eventIndex]
        local evtTime = MidiParser.tickToSeconds(item.tick, ticksPerBeat, self.tempos)

        if evtTime > self.elapsedTime then
            break  -- 还没到这个事件的时间
        end

        -- 轨道过滤: meta 事件(tempo等)始终处理, 音符事件按 enabledTracks 过滤
        if not filter or filter[item.trackIndex] or item.event.type == "meta" then
            self:processEvent(item.event)
        end
        self.eventIndex = self.eventIndex + 1
    end

    -- 检查是否播放完毕
    if self.eventIndex > #self.allEvents then
        if self.loop then
            self:play()  -- 循环
        else
            self.state = MidiPlayer.STATE_STOPPED
            if self.onTrackEnd then
                self.onTrackEnd()
            end
        end
    end
end

------------------------------------------------------------
-- 事件处理
------------------------------------------------------------

---@param evt table
function MidiPlayer:processEvent(evt)
    if evt.type == "note_on" then
        self:handleNoteOn(evt)
    elseif evt.type == "note_off" then
        self:handleNoteOff(evt)
    elseif evt.type == "meta" and evt.metaName == "set_tempo" then
        if self.onTempoChange then
            self.onTempoChange(evt.bpm)
        end
    end
end

---@param evt table  { note, velocity, channel, noteName }
function MidiPlayer:handleNoteOn(evt)
    -- 回调
    if self.onNoteOn then
        self.onNoteOn(evt.note, evt.velocity, evt.channel, evt.noteName)
    end

    -- 同音符重触发：将同 note+channel 的旧音源移入淡出列表
    for i = #self.activeSources, 1, -1 do
        local info = self.activeSources[i]
        if info.note == evt.note and info.channel == evt.channel then
            self.releasingSources[#self.releasingSources + 1] = {
                node      = info.node,
                source    = info.source,
                startGain = info.source.gain,
                fadeFrame = 0,
            }
            table.remove(self.activeSources, i)
        end
    end

    -- 控制复音数：超限时回收最老音源
    local totalActive = #self.activeSources + #self.releasingSources
    if totalActive >= self.maxPolyphony then
        self:removeOldestSource()
    end

    -- 获取音频路径 (根据 velocity 选择 Hard/Soft 采样层)
    local soundPath
    if evt.channel == 10 then
        soundPath = self.percussionPaths[evt.note]
    else
        if evt.velocity >= self.velocityThreshold then
            soundPath = self.notePathsHard[evt.note]
        else
            soundPath = self.notePathsSoft[evt.note]
        end
    end

    if not soundPath then return end

    -- 尝试加载音频资源
    local sound = cache:GetResource("Sound", soundPath)
    if not sound then return end

    -- 创建全新 Node + SoundSource (绝不复用正在播放的音源)
    self.nodeCounter = self.nodeCounter + 1
    local node = self.scene:CreateChild("MPN" .. self.nodeCounter)
    local source = node:CreateComponent("SoundSource")

    local targetGain = (evt.velocity / 127.0) * self.volume

    -- 以 gain=0 启动播放，再淡入
    source.gain = 0
    source:Play(sound)

    -- 注册淡入：在 fadeInFrames 帧内线性爬升到 targetGain
    local step = targetGain / math.max(self.fadeInFrames, 1)
    self.fadingInSources[#self.fadingInSources + 1] = {
        source      = source,
        currentGain = 0,
        targetGain  = targetGain,
        step        = step,
    }

    self.activeSources[#self.activeSources + 1] = {
        node    = node,
        source  = source,
        note    = evt.note,
        channel = evt.channel,
        targetGain = targetGain,
    }
end

---@param evt table
function MidiPlayer:handleNoteOff(evt)
    if self.onNoteOff then
        self.onNoteOff(evt.note, evt.velocity, evt.channel, evt.noteName)
    end

    -- 将对应音源移入淡出列表（线性淡出，绝不调 Stop）
    for i = #self.activeSources, 1, -1 do
        local info = self.activeSources[i]
        if info.note == evt.note and info.channel == evt.channel then
            self.releasingSources[#self.releasingSources + 1] = {
                node      = info.node,
                source    = info.source,
                startGain = info.source.gain,
                fadeFrame = 0,
            }
            table.remove(self.activeSources, i)
            break
        end
    end
end

------------------------------------------------------------
-- 音源管理
------------------------------------------------------------

--- 清理已静音且自然结束的音源节点（每帧调用）
--- gain=0 的源等待 IsPlaying()==false 后安全 Remove 节点
function MidiPlayer:cleanupSilentSources()
    for i = #self.silentSources, 1, -1 do
        local info = self.silentSources[i]
        if not info.source:IsPlaying() then
            info.node:Remove()
            table.remove(self.silentSources, i)
        end
    end
    -- 同时清理 activeSources 中已自然结束的（音频比音符短的情况）
    for i = #self.activeSources, 1, -1 do
        local info = self.activeSources[i]
        if not info.source:IsPlaying() then
            info.node:Remove()
            table.remove(self.activeSources, i)
        end
    end
end

--- 回收最老的活跃音源（复音数超限时调用）
--- 将最老的活跃源移入淡出列表，绝不调 Stop
function MidiPlayer:removeOldestSource()
    -- 优先从 releasingSources 中回收增益最低的
    if #self.releasingSources > 0 then
        local minIdx = 1
        local minGain = self.releasingSources[1].source.gain
        for i = 2, #self.releasingSources do
            local g = self.releasingSources[i].source.gain
            if g < minGain then
                minIdx = i
                minGain = g
            end
        end
        local old = table.remove(self.releasingSources, minIdx)
        old.source.gain = 0
        -- 移入静音列表，等待自然结束后 Remove
        self.silentSources[#self.silentSources + 1] = {
            node   = old.node,
            source = old.source,
        }
        return
    end
    -- 否则从 activeSources 移除最老的（第一个）
    if #self.activeSources > 0 then
        local info = table.remove(self.activeSources, 1)
        self.releasingSources[#self.releasingSources + 1] = {
            node      = info.node,
            source    = info.source,
            startGain = info.source.gain,
            fadeFrame = 0,
        }
    end
end

--- 优雅停止所有音源（gain 置零 + 等待自然结束，绝不调 Stop）
function MidiPlayer:stopAllSources()
    -- 活跃音源 → 静音列表
    for _, info in ipairs(self.activeSources) do
        info.source.gain = 0
        self.silentSources[#self.silentSources + 1] = {
            node   = info.node,
            source = info.source,
        }
    end
    self.activeSources = {}
    -- 淡出中的音源 → 静音列表
    for _, info in ipairs(self.releasingSources) do
        info.source.gain = 0
        self.silentSources[#self.silentSources + 1] = {
            node   = info.node,
            source = info.source,
        }
    end
    self.releasingSources = {}
    -- 清理淡入列表
    self.fadingInSources = {}
end

--- 处理淡入中的音源（每帧调用，按预计算 step 步进）
function MidiPlayer:fadeFadeInSources()
    for i = #self.fadingInSources, 1, -1 do
        local info = self.fadingInSources[i]
        info.currentGain = info.currentGain + info.step
        if info.currentGain >= info.targetGain then
            info.source.gain = info.targetGain
            table.remove(self.fadingInSources, i)
        else
            info.source.gain = info.currentGain
        end
    end
end

--- 处理淡出中的音源（每帧调用，线性衰减）
--- 在 fadeOutFrames 帧内从 startGain 线性降至 0，然后移入 silentSources
function MidiPlayer:fadeReleasingSources()
    local totalFrames = math.max(self.fadeOutFrames, 1)
    for i = #self.releasingSources, 1, -1 do
        local info = self.releasingSources[i]
        info.fadeFrame = info.fadeFrame + 1
        local progress = info.fadeFrame / totalFrames  -- 0→1
        if progress >= 1.0 then
            -- 淡出完毕，移入静音列表等待自然结束
            info.source.gain = 0
            self.silentSources[#self.silentSources + 1] = {
                node   = info.node,
                source = info.source,
            }
            table.remove(self.releasingSources, i)
        else
            info.source.gain = info.startGain * (1.0 - progress)
        end
    end
end

------------------------------------------------------------
-- 查询接口
------------------------------------------------------------

--- 获取播放进度 (0.0 ~ 1.0)
---@return number
function MidiPlayer:getProgress()
    if self.totalDuration <= 0 then return 0 end
    return math.min(self.elapsedTime / self.totalDuration, 1.0)
end

--- 获取当前播放时间 (秒)
---@return number
function MidiPlayer:getCurrentTime()
    return self.elapsedTime
end

--- 获取总时长 (秒)
---@return number
function MidiPlayer:getDuration()
    return self.totalDuration
end

--- 获取当前状态
---@return string  "stopped" | "playing" | "paused"
function MidiPlayer:getState()
    return self.state
end

--- 设置播放速度
---@param speed number  1.0 = 正常, 2.0 = 双倍速
function MidiPlayer:setSpeed(speed)
    self.speed = math.max(0.1, math.min(speed, 10.0))
end

--- 设置音量
---@param volume number  0.0 ~ 1.0
function MidiPlayer:setVolume(volume)
    self.volume = math.max(0, math.min(volume, 1.0))
end

--- 设置循环
---@param enabled boolean
function MidiPlayer:setLoop(enabled)
    self.loop = enabled
end

--- 设置单个音符的音频路径
---@param noteNumber integer  0-127
---@param path string  音频资源路径
---@param layer? string  "hard"/"soft"/"both"(默认)
function MidiPlayer:setNotePath(noteNumber, path, layer)
    layer = layer or "both"
    if layer == "hard" or layer == "both" then
        self.notePathsHard[noteNumber] = path
    end
    if layer == "soft" or layer == "both" then
        self.notePathsSoft[noteNumber] = path
    end
end

--- 批量设置音符音频路径
---@param paths table<integer, string>
---@param layer? string  "hard"/"soft"/"both"(默认)
function MidiPlayer:setNotePaths(paths, layer)
    for note, path in pairs(paths) do
        self:setNotePath(note, path, layer)
    end
end

--- 设置打击乐音频路径
---@param noteNumber integer
---@param path string
function MidiPlayer:setPercussionPath(noteNumber, path)
    self.percussionPaths[noteNumber] = path
end

--- 销毁播放器，释放资源
function MidiPlayer:destroy()
    self:stop()
    -- 清理静音列表中等待自然结束的节点
    for _, info in ipairs(self.silentSources) do
        info.source.gain = 0
        info.node:Remove()
    end
    self.silentSources = {}
end

------------------------------------------------------------
-- 轨道选择
------------------------------------------------------------

--- 设置只播放指定轨道 (其余静音)
--- 可传入单个轨道索引或索引数组，索引从 1 开始
---@param tracks integer|integer[]  轨道索引，如 1 或 {1, 3}
function MidiPlayer:setTracks(tracks)
    if type(tracks) == "number" then
        self.enabledTracks = { [tracks] = true }
    elseif type(tracks) == "table" then
        local set = {}
        for _, idx in ipairs(tracks) do
            set[idx] = true
        end
        self.enabledTracks = set
    end
end

--- 启用单条轨道 (不影响其他已启用的轨道)
---@param trackIndex integer  轨道索引 (1-based)
function MidiPlayer:enableTrack(trackIndex)
    if not self.enabledTracks then
        -- 当前是"全部播放"，切换到显式模式：先填入所有轨道再操作
        self.enabledTracks = self:_buildAllTracksSet()
    end
    self.enabledTracks[trackIndex] = true
end

--- 禁用单条轨道
---@param trackIndex integer  轨道索引 (1-based)
function MidiPlayer:disableTrack(trackIndex)
    if not self.enabledTracks then
        self.enabledTracks = self:_buildAllTracksSet()
    end
    self.enabledTracks[trackIndex] = nil
end

--- 切换单条轨道的启用/禁用状态
---@param trackIndex integer
---@return boolean enabled  切换后是否启用
function MidiPlayer:toggleTrack(trackIndex)
    if not self.enabledTracks then
        self.enabledTracks = self:_buildAllTracksSet()
    end
    if self.enabledTracks[trackIndex] then
        self.enabledTracks[trackIndex] = nil
        return false
    else
        self.enabledTracks[trackIndex] = true
        return true
    end
end

--- 播放所有轨道 (清除过滤)
function MidiPlayer:setAllTracks()
    self.enabledTracks = nil
end

--- 独奏某条轨道 (只播放该轨道，其余全部静音)
---@param trackIndex integer
function MidiPlayer:soloTrack(trackIndex)
    self.enabledTracks = { [trackIndex] = true }
end

--- 静音某条轨道 (禁用该轨道，其余保持不变)
--- 与 disableTrack 相同，语义更清晰
---@param trackIndex integer
function MidiPlayer:muteTrack(trackIndex)
    self:disableTrack(trackIndex)
end

--- 取消静音
---@param trackIndex integer
function MidiPlayer:unmuteTrack(trackIndex)
    self:enableTrack(trackIndex)
end

--- 查询某条轨道是否启用
---@param trackIndex integer
---@return boolean
function MidiPlayer:isTrackEnabled(trackIndex)
    if not self.enabledTracks then return true end
    return self.enabledTracks[trackIndex] == true
end

--- 获取当前已启用的轨道索引列表
---@return integer[]
function MidiPlayer:getEnabledTracks()
    if not self.enabledTracks then
        -- 全部启用
        local result = {}
        if self.midi then
            for i = 1, self.midi.numTracks do
                result[i] = i
            end
        end
        return result
    end
    local result = {}
    for idx in pairs(self.enabledTracks) do
        result[#result + 1] = idx
    end
    table.sort(result)
    return result
end

--- 获取所有轨道信息 (索引、名称、事件数)
---@return table[]|nil  { index, name, eventCount, enabled }
function MidiPlayer:getTrackList()
    if not self.midi then return nil end
    local list = {}
    for i, track in ipairs(self.midi.tracks) do
        list[i] = {
            index      = i,
            name       = track.name or string.format("Track %d", i),
            eventCount = #track.events,
            enabled    = self:isTrackEnabled(i),
        }
    end
    return list
end

--- 内部: 构建包含所有轨道的 set
---@return table<integer, boolean>
function MidiPlayer:_buildAllTracksSet()
    local set = {}
    if self.midi then
        for i = 1, self.midi.numTracks do
            set[i] = true
        end
    end
    return set
end

return MidiPlayer
