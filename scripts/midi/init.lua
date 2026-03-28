------------------------------------------------------------
-- midi/init.lua
-- MIDI 模块对外公共接口
--
-- 用法:
--   local Midi = require("midi")
--
--   -- 1) 解析 MIDI 文件
--   local data, err = Midi.parseFile("Music/song.mid")
--
--   -- 2) 创建播放器并播放
--   local player = Midi.createPlayer(scene, { volume = 0.8 })
--   player:load("Music/song.mid")
--   player:play()
--
--   -- 3) 在 Update 中驱动
--   function HandleUpdate(_, eventData)
--       player:update(eventData["TimeStep"]:GetFloat())
--   end
------------------------------------------------------------
local MidiParser = require("midi.MidiParser")
local MidiPlayer = require("midi.MidiPlayer")

local Midi = {}

------------------------------------------------------------
-- 解析接口
------------------------------------------------------------

--- 从资源路径解析 MIDI 文件
---@param filePath string  资源路径 (如 "Music/song.mid")
---@return table|nil data  解析后的 MIDI 数据结构
---@return string|nil err  错误信息
function Midi.parseFile(filePath)
    return MidiParser.parseFile(filePath)
end

--- 从二进制字符串解析 MIDI 数据
---@param binaryData string  完整 MIDI 文件的二进制内容
---@return table|nil data
---@return string|nil err
function Midi.parse(binaryData)
    return MidiParser.parse(binaryData)
end

--- 提取所有 note_on 事件 (便捷方法)
---@param midiData table  Midi.parse/parseFile 返回的结果
---@return table[] notes  按 tick 排序的音符列表
function Midi.extractNotes(midiData)
    return MidiParser.extractNotes(midiData)
end

--- 提取 Tempo 变化列表
---@param midiData table
---@return table[] tempos  { tick, tempo, bpm }
function Midi.extractTempos(midiData)
    return MidiParser.extractTempos(midiData)
end

--- 将 tick 转为秒
---@param tick integer
---@param ticksPerBeat integer
---@param tempos table[]
---@return number seconds
function Midi.tickToSeconds(tick, ticksPerBeat, tempos)
    return MidiParser.tickToSeconds(tick, ticksPerBeat, tempos)
end

------------------------------------------------------------
-- 播放器接口
------------------------------------------------------------

--- 创建 MIDI 播放器
---@param scene Scene       场景对象
---@param options? table    配置选项:
---   speed          number    播放速度 (默认 1.0)
---   volume         number    音量 0~1 (默认 1.0)
---   loop           boolean   是否循环 (默认 false)
---   maxPolyphony   integer   最大复音数 (默认 32)
---   notePaths      table     音符音频路径映射 { [0~127] = "path" }
---   percussionPaths table    打击乐路径映射
---   onNoteOn       function  音符触发回调 (note, velocity, channel, noteName)
---   onNoteOff      function  音符释放回调 (note, velocity, channel, noteName)
---   onTrackEnd     function  播放结束回调 ()
---   onTempoChange  function  速度变化回调 (bpm)
---@return table
function Midi.createPlayer(scene, options)
    return MidiPlayer.new(scene, options)
end

------------------------------------------------------------
-- 常量 / 工具
------------------------------------------------------------

--- 播放状态常量
Midi.STATE_STOPPED = MidiPlayer.STATE_STOPPED
Midi.STATE_PLAYING = MidiPlayer.STATE_PLAYING
Midi.STATE_PAUSED  = MidiPlayer.STATE_PAUSED

--- GM 乐器名称 (Program 0~127 → 名称)
Midi.GM_INSTRUMENTS = {
    -- Piano
    [0] = "Acoustic Grand Piano", [1] = "Bright Acoustic Piano",
    [2] = "Electric Grand Piano", [3] = "Honky-tonk Piano",
    [4] = "Electric Piano 1",     [5] = "Electric Piano 2",
    [6] = "Harpsichord",          [7] = "Clavinet",
    -- Chromatic Percussion
    [8] = "Celesta",    [9] = "Glockenspiel", [10] = "Music Box",
    [11] = "Vibraphone", [12] = "Marimba",     [13] = "Xylophone",
    [14] = "Tubular Bells", [15] = "Dulcimer",
    -- Organ
    [16] = "Drawbar Organ",  [17] = "Percussive Organ",
    [18] = "Rock Organ",     [19] = "Church Organ",
    [20] = "Reed Organ",     [21] = "Accordion",
    [22] = "Harmonica",      [23] = "Tango Accordion",
    -- Guitar
    [24] = "Nylon Guitar",  [25] = "Steel Guitar",
    [26] = "Jazz Guitar",   [27] = "Clean Guitar",
    [28] = "Muted Guitar",  [29] = "Overdriven Guitar",
    [30] = "Distortion Guitar", [31] = "Guitar Harmonics",
    -- Bass
    [32] = "Acoustic Bass", [33] = "Finger Bass",
    [34] = "Pick Bass",     [35] = "Fretless Bass",
    [36] = "Slap Bass 1",   [37] = "Slap Bass 2",
    [38] = "Synth Bass 1",  [39] = "Synth Bass 2",
    -- Strings
    [40] = "Violin",   [41] = "Viola",    [42] = "Cello",
    [43] = "Contrabass", [44] = "Tremolo Strings",
    [45] = "Pizzicato Strings", [46] = "Orchestral Harp",
    [47] = "Timpani",
}

--- MIDI 音符编号 → 可读名称
---@param noteNum integer  0-127
---@return string  如 "C4", "A#5"
function Midi.noteName(noteNum)
    local names = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }
    local octave = math.floor(noteNum / 12) - 1
    return names[(noteNum % 12) + 1] .. octave
end

--- 频率 → MIDI 音符编号 (A4=440Hz 标准)
---@param freq number  频率 (Hz)
---@return integer noteNum
function Midi.freqToNote(freq)
    return math.floor(12 * math.log(freq / 440, 2) + 69 + 0.5)
end

--- MIDI 音符编号 → 频率 (Hz)
---@param noteNum integer
---@return number freq
function Midi.noteToFreq(noteNum)
    return 440.0 * (2 ^ ((noteNum - 69) / 12))
end

return Midi
