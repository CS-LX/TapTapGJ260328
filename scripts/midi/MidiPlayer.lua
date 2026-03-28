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

    -- 音源池 (预创建，避免频繁 CreateComponent/Remove)
    self.audioNode         = scene:CreateChild("MidiPlayerAudio")
    self.sourcePool        = {}   -- 空闲 SoundSource 池
    self.activeSources     = {}   -- 活跃音源 { source, note, channel, gain }
    self.releasingSources  = {}   -- 正在淡出的音源 { source, gain }
    self.fadeOutSpeed       = options.fadeOutSpeed or 25.0  -- gain 每秒衰减速度 (~50ms 淡出)

    -- 预创建音源池
    for i = 1, self.maxPolyphony do
        local src = self.audioNode:CreateComponent("SoundSource")
        self.sourcePool[i] = src
    end

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

    -- 清理已结束的音源 & 处理淡出
    self:cleanupSources()
    self:fadeReleasingSources(dt)

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

    -- 控制复音数：池空时回收最老音源
    if #self.sourcePool == 0 then
        self:removeOldestSource()
    end
    -- 仍然没有可用音源则跳过
    if #self.sourcePool == 0 then return end

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

    -- 从池中取出音源
    local source = table.remove(self.sourcePool)

    local gain = (evt.velocity / 127.0) * self.volume

    -- 确保音源干净后再播放
    source:Stop()
    source:Play(sound, sound.frequency, gain)

    self.activeSources[#self.activeSources + 1] = {
        source  = source,
        note    = evt.note,
        channel = evt.channel,
        gain    = gain,
    }
end

---@param evt table
function MidiPlayer:handleNoteOff(evt)
    if self.onNoteOff then
        self.onNoteOff(evt.note, evt.velocity, evt.channel, evt.noteName)
    end

    -- 将对应音源移入淡出列表（不立即 Stop，避免噗声）
    for i = #self.activeSources, 1, -1 do
        local info = self.activeSources[i]
        if info.note == evt.note and info.channel == evt.channel then
            if info.source then
                self.releasingSources[#self.releasingSources + 1] = {
                    source = info.source,
                    gain   = info.gain or self.volume,
                }
            end
            table.remove(self.activeSources, i)
            break
        end
    end
end

------------------------------------------------------------
-- 音源管理
------------------------------------------------------------

function MidiPlayer:cleanupSources()
    for i = #self.activeSources, 1, -1 do
        local info = self.activeSources[i]
        if not info.source or not info.source:IsPlaying() then
            -- 归还到池
            if info.source then
                self.sourcePool[#self.sourcePool + 1] = info.source
            end
            table.remove(self.activeSources, i)
        end
    end
end

function MidiPlayer:removeOldestSource()
    if #self.activeSources > 0 then
        local info = table.remove(self.activeSources, 1)
        if info.source then
            -- 移入淡出列表而非立即 Stop
            self.releasingSources[#self.releasingSources + 1] = {
                source = info.source,
                gain   = info.gain or self.volume,
            }
        end
    end
    -- 如果淡出列表也满了，强制回收最老的淡出音源
    if #self.sourcePool == 0 and #self.releasingSources > 0 then
        local old = table.remove(self.releasingSources, 1)
        old.source:Stop()
        self.sourcePool[#self.sourcePool + 1] = old.source
    end
end

function MidiPlayer:stopAllSources()
    for _, info in ipairs(self.activeSources) do
        if info.source then
            info.source:Stop()
            self.sourcePool[#self.sourcePool + 1] = info.source
        end
    end
    self.activeSources = {}
    -- 同时清理淡出列表
    for _, info in ipairs(self.releasingSources) do
        if info.source then
            info.source:Stop()
            self.sourcePool[#self.sourcePool + 1] = info.source
        end
    end
    self.releasingSources = {}
end

--- 处理淡出中的音源（每帧调用）
---@param dt number
function MidiPlayer:fadeReleasingSources(dt)
    for i = #self.releasingSources, 1, -1 do
        local info = self.releasingSources[i]
        info.gain = info.gain - self.fadeOutSpeed * dt
        if info.gain <= 0.005 then
            -- 淡出完毕，停止并归还到池
            info.source:Stop()
            self.sourcePool[#self.sourcePool + 1] = info.source
            table.remove(self.releasingSources, i)
        else
            info.source.gain = info.gain
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
    if self.audioNode then
        self.audioNode:Remove()
        self.audioNode = nil
    end
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
