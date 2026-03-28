------------------------------------------------------------
-- MidiParser.lua
-- 纯 Lua 5.4 MIDI 二进制文件解析器
-- 支持 Format 0/1/2，解析所有标准 MIDI 事件
------------------------------------------------------------
local MidiParser = {}

------------------------------------------------------------
-- 内部工具
------------------------------------------------------------

--- 从二进制字符串中读取大端无符号整数
---@param data string
---@param pos  integer  -- 1-based
---@param len  integer  -- 字节数 (1/2/3/4)
---@return integer value, integer nextPos
local function readUInt(data, pos, len)
    local fmt = ">I" .. len
    local value = string.unpack(fmt, data, pos)
    return value, pos + len
end

--- 读取 Variable-Length Quantity (VLQ)
---@param data string
---@param pos  integer
---@return integer value, integer nextPos
local function readVLQ(data, pos)
    local value = 0
    local byte
    repeat
        byte = string.byte(data, pos)
        value = (value << 7) | (byte & 0x7F)
        pos = pos + 1
    until (byte & 0x80) == 0
    return value, pos
end

--- 读取定长字节串
---@param data string
---@param pos  integer
---@param len  integer
---@return string bytes, integer nextPos
local function readBytes(data, pos, len)
    return string.sub(data, pos, pos + len - 1), pos + len
end

------------------------------------------------------------
-- Meta Event 解析
------------------------------------------------------------

--- 已知 Meta Event 类型名称
local META_NAMES = {
    [0x00] = "sequence_number",
    [0x01] = "text",
    [0x02] = "copyright",
    [0x03] = "track_name",
    [0x04] = "instrument_name",
    [0x05] = "lyric",
    [0x06] = "marker",
    [0x07] = "cue_point",
    [0x20] = "channel_prefix",
    [0x21] = "port_prefix",
    [0x2F] = "end_of_track",
    [0x51] = "set_tempo",
    [0x54] = "smpte_offset",
    [0x58] = "time_signature",
    [0x59] = "key_signature",
    [0x7F] = "sequencer_specific",
}

---@param metaType integer
---@param raw string  -- meta data bytes
---@return table
local function parseMetaEvent(metaType, raw)
    local evt = {
        type      = "meta",
        metaType  = metaType,
        metaName  = META_NAMES[metaType] or string.format("unknown_0x%02X", metaType),
        raw       = raw,
    }

    if metaType == 0x03 or metaType == 0x01 or metaType == 0x02
       or metaType == 0x04 or metaType == 0x05 or metaType == 0x06
       or metaType == 0x07 then
        evt.text = raw
    elseif metaType == 0x51 and #raw == 3 then
        -- Tempo: 3 bytes → microseconds per quarter note
        local b1, b2, b3 = string.byte(raw, 1, 3)
        evt.tempo = (b1 << 16) | (b2 << 8) | b3    -- μs/beat
        evt.bpm   = 60000000 / evt.tempo
    elseif metaType == 0x58 and #raw >= 4 then
        -- Time Signature
        local nn, dd, cc, bb = string.byte(raw, 1, 4)
        evt.numerator   = nn
        evt.denominator = 1 << dd
        evt.clocksPerClick    = cc
        evt.notated32ndPerBeat = bb
    elseif metaType == 0x59 and #raw >= 2 then
        -- Key Signature
        local sf, mi = string.byte(raw, 1, 2)
        if sf > 127 then sf = sf - 256 end  -- signed
        evt.sharpsFlats = sf   -- 负=降号数, 正=升号数
        evt.minor       = (mi == 1)
    end

    return evt
end

------------------------------------------------------------
-- Channel Event 名称
------------------------------------------------------------
local CHANNEL_EVENT_NAMES = {
    [0x80] = "note_off",
    [0x90] = "note_on",
    [0xA0] = "aftertouch",
    [0xB0] = "control_change",
    [0xC0] = "program_change",
    [0xD0] = "channel_pressure",
    [0xE0] = "pitch_bend",
}

--- Channel 事件的数据字节数 (status high nibble → byte count)
local CHANNEL_DATA_LEN = {
    [0x80] = 2,  -- note_off:        note, velocity
    [0x90] = 2,  -- note_on:         note, velocity
    [0xA0] = 2,  -- aftertouch:      note, pressure
    [0xB0] = 2,  -- control_change:  controller, value
    [0xC0] = 1,  -- program_change:  program
    [0xD0] = 1,  -- channel_pressure: pressure
    [0xE0] = 2,  -- pitch_bend:      lsb, msb
}

------------------------------------------------------------
-- 音符名称
------------------------------------------------------------
local NOTE_NAMES = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }

--- 将 MIDI note number 转为可读名称 (如 "C4", "A#5")
---@param noteNum integer  0-127
---@return string
local function noteName(noteNum)
    local octave = math.floor(noteNum / 12) - 1
    local name   = NOTE_NAMES[(noteNum % 12) + 1]
    return name .. octave
end

------------------------------------------------------------
-- Track 解析
------------------------------------------------------------

---@param data string    -- 完整 MIDI 文件数据
---@param trackStart integer  -- MTrk 数据区起始位置 (1-based，跳过 chunk header)
---@param trackLen integer    -- 数据区字节数
---@return table[] events
local function parseTrack(data, trackStart, trackLen)
    local events = {}
    local pos = trackStart
    local endPos = trackStart + trackLen
    local runningStatus = 0
    local absoluteTick = 0

    while pos < endPos do
        -- 1) Delta time
        local delta
        delta, pos = readVLQ(data, pos)
        absoluteTick = absoluteTick + delta

        -- 2) Status byte (with running status support)
        local statusByte = string.byte(data, pos)
        if statusByte >= 0x80 then
            runningStatus = statusByte
            pos = pos + 1
        else
            -- running status: reuse previous status
            statusByte = runningStatus
        end

        -- 3) 分类处理
        if statusByte == 0xFF then
            ---- Meta Event ----
            local metaType = string.byte(data, pos)
            pos = pos + 1
            local metaLen
            metaLen, pos = readVLQ(data, pos)
            local metaData
            metaData, pos = readBytes(data, pos, metaLen)

            local evt = parseMetaEvent(metaType, metaData)
            evt.delta = delta
            evt.tick  = absoluteTick
            events[#events + 1] = evt

        elseif statusByte == 0xF0 or statusByte == 0xF7 then
            ---- SysEx Event ----
            local sysLen
            sysLen, pos = readVLQ(data, pos)
            local sysData
            sysData, pos = readBytes(data, pos, sysLen)
            events[#events + 1] = {
                type  = "sysex",
                delta = delta,
                tick  = absoluteTick,
                data  = sysData,
            }
        else
            ---- Channel Event ----
            local highNibble = statusByte & 0xF0
            local channel    = (statusByte & 0x0F) + 1   -- 1-based
            local dataLen    = CHANNEL_DATA_LEN[highNibble] or 0
            local eventName  = CHANNEL_EVENT_NAMES[highNibble] or "unknown"

            local evt = {
                type    = eventName,
                delta   = delta,
                tick    = absoluteTick,
                channel = channel,
            }

            if highNibble == 0x80 or highNibble == 0x90 then
                -- Note On / Off
                evt.note     = string.byte(data, pos)
                evt.velocity = string.byte(data, pos + 1)
                evt.noteName = noteName(evt.note)
                -- note_on with velocity 0 = note_off
                if highNibble == 0x90 and evt.velocity == 0 then
                    evt.type = "note_off"
                end
                pos = pos + 2

            elseif highNibble == 0xA0 then
                evt.note     = string.byte(data, pos)
                evt.pressure = string.byte(data, pos + 1)
                pos = pos + 2

            elseif highNibble == 0xB0 then
                evt.controller = string.byte(data, pos)
                evt.value      = string.byte(data, pos + 1)
                pos = pos + 2

            elseif highNibble == 0xC0 then
                evt.program = string.byte(data, pos)
                pos = pos + 1

            elseif highNibble == 0xD0 then
                evt.pressure = string.byte(data, pos)
                pos = pos + 1

            elseif highNibble == 0xE0 then
                local lsb = string.byte(data, pos)
                local msb = string.byte(data, pos + 1)
                evt.value = (msb << 7) | lsb  -- 0-16383, center=8192
                pos = pos + 2
            else
                -- 未知事件，跳过 dataLen 字节
                pos = pos + dataLen
            end

            events[#events + 1] = evt
        end
    end

    return events
end

------------------------------------------------------------
-- 公共接口
------------------------------------------------------------

--- 解析 MIDI 二进制数据
---@param data string  完整的 MIDI 文件二进制内容
---@return table|nil midi  解析结果, 失败返回 nil
---@return string|nil err  错误信息
function MidiParser.parse(data)
    if not data or #data < 14 then
        return nil, "Data too short to be a valid MIDI file"
    end

    -- ========== Header Chunk ==========
    local headerTag = string.sub(data, 1, 4)
    if headerTag ~= "MThd" then
        return nil, "Invalid MIDI header (expected 'MThd', got '" .. headerTag .. "')"
    end

    local headerLen, pos = readUInt(data, 5, 4)   -- should be 6
    local format,   _    = readUInt(data, 9, 2)    -- 0, 1, or 2
    local numTracks      = readUInt(data, 11, 2)
    local division       = readUInt(data, 13, 2)

    -- Division: 正数 = ticks per quarter note; 负数 = SMPTE
    local ticksPerBeat = nil
    local smpte = nil
    if division & 0x8000 == 0 then
        ticksPerBeat = division
    else
        -- SMPTE: high byte = negative frames/sec, low byte = ticks/frame
        local framesPerSec = -(((division >> 8) & 0xFF) - 256)
        local ticksPerFrame = division & 0xFF
        smpte = { fps = framesPerSec, ticksPerFrame = ticksPerFrame }
    end

    pos = 9 + headerLen  -- skip header data (usually byte 15)

    -- ========== Track Chunks ==========
    local tracks = {}
    for i = 1, numTracks do
        if pos + 8 > #data then
            return nil, string.format("Unexpected end of data at track %d", i)
        end

        local chunkTag = string.sub(data, pos, pos + 3)
        if chunkTag ~= "MTrk" then
            return nil, string.format("Expected 'MTrk' at track %d, got '%s'", i, chunkTag)
        end

        local trackLen = readUInt(data, pos + 4, 4)
        local trackDataStart = pos + 8

        local trackEvents = parseTrack(data, trackDataStart, trackLen)

        -- 提取轨道名称
        local trackName = nil
        for _, evt in ipairs(trackEvents) do
            if evt.type == "meta" and evt.metaName == "track_name" then
                trackName = evt.text
                break
            end
        end

        tracks[i] = {
            index  = i,
            name   = trackName,
            events = trackEvents,
        }

        pos = trackDataStart + trackLen
    end

    -- ========== 构建结果 ==========
    return {
        format       = format,
        numTracks    = numTracks,
        ticksPerBeat = ticksPerBeat,
        smpte        = smpte,
        tracks       = tracks,
    }
end

--- 从引擎资源系统加载并解析 MIDI 文件
---@param filePath string  资源路径 (如 "Music/song.mid")
---@return table|nil midi
---@return string|nil err
function MidiParser.parseFile(filePath)
    local file = File(filePath, FILE_READ)
    if not file or not file:IsOpen() then
        return nil, "Cannot open file: " .. tostring(filePath)
    end

    local size = file:GetSize()
    if size == 0 then
        file:Close()
        return nil, "File is empty: " .. tostring(filePath)
    end

    -- 逐字节读取构建二进制字符串
    local bytes = {}
    for i = 1, size do
        bytes[i] = string.char(file:ReadUByte())
    end
    file:Close()

    local data = table.concat(bytes)
    return MidiParser.parse(data)
end

--- 获取所有 note_on 事件（便捷方法）
---@param midi table  MidiParser.parse() 的返回结果
---@return table[] notes  { tick, channel, note, noteName, velocity, trackIndex }
function MidiParser.extractNotes(midi)
    local notes = {}
    for ti, track in ipairs(midi.tracks) do
        for _, evt in ipairs(track.events) do
            if evt.type == "note_on" then
                notes[#notes + 1] = {
                    tick       = evt.tick,
                    channel    = evt.channel,
                    note       = evt.note,
                    noteName   = evt.noteName,
                    velocity   = evt.velocity,
                    trackIndex = ti,
                }
            end
        end
    end
    -- 按 tick 排序
    table.sort(notes, function(a, b) return a.tick < b.tick end)
    return notes
end

--- 获取 Tempo 变化列表
---@param midi table
---@return table[] tempos  { tick, tempo(μs/beat), bpm }
function MidiParser.extractTempos(midi)
    local tempos = {}
    for _, track in ipairs(midi.tracks) do
        for _, evt in ipairs(track.events) do
            if evt.type == "meta" and evt.metaName == "set_tempo" then
                tempos[#tempos + 1] = {
                    tick  = evt.tick,
                    tempo = evt.tempo,
                    bpm   = evt.bpm,
                }
            end
        end
    end
    table.sort(tempos, function(a, b) return a.tick < b.tick end)
    -- 默认 tempo (120 BPM) 如果没有 tempo 事件
    if #tempos == 0 then
        tempos[1] = { tick = 0, tempo = 500000, bpm = 120 }
    end
    return tempos
end

--- 将 tick 转换为秒 (需要 ticksPerBeat 和 tempo 列表)
---@param tick integer
---@param ticksPerBeat integer
---@param tempos table[]  -- MidiParser.extractTempos() 的返回值
---@return number seconds
function MidiParser.tickToSeconds(tick, ticksPerBeat, tempos)
    local seconds = 0.0
    local lastTick = 0
    local currentTempo = 500000  -- 默认 120 BPM

    for _, t in ipairs(tempos) do
        if t.tick >= tick then
            break
        end
        -- 累加从 lastTick 到 t.tick 的时间
        seconds = seconds + (t.tick - lastTick) * (currentTempo / 1000000.0) / ticksPerBeat
        lastTick = t.tick
        currentTempo = t.tempo
    end

    -- 累加剩余部分
    seconds = seconds + (tick - lastTick) * (currentTempo / 1000000.0) / ticksPerBeat
    return seconds
end

return MidiParser
