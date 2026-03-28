------------------------------------------------------------
-- BGM.lua
-- 多轨 BGM 管理器：4条旋律同时播放，通过阶段控制各轨音量
------------------------------------------------------------
local BGM = {}

---@type Node[]
local nodes = {}
---@type SoundSource[]
local sources = {}

local volume = 1.0       -- 全局音量
local muted = false      -- 是否静音
local stage = 0          -- 当前阶段 (0=全静音)
local targetGains = { 0, 0, 0, 0 }  -- 各轨目标增益
local currentGains = { 0, 0, 0, 0 }  -- 各轨当前增益（用于平滑过渡）
local fadeSpeed = 2.0    -- 淡入淡出速度 (gain/秒)

---@type Sound[]
local sounds = {}           -- 缓存 Sound 资源

local TRACKS = {
    "audio/BGM/bgm_melody_1.ogg",
    "audio/BGM/bgm_melody_2.ogg",
    "audio/BGM/bgm_melody_3.ogg",
    "audio/BGM/bgm_melody_4.ogg",
}

-- 各阶段对应的增益配置 [stage] = { track1, track2, track3, track4 }
local STAGE_GAINS = {
    [0] = { 0.1,  0.1,  0.1,  0.1  },  -- 全待机
    [4] = { 0.1,  0.1,  0.1,  1.0  },  -- 第四旋律启用
    [3] = { 0.1,  0.1,  1.0,  1.0  },  -- +第三旋律
    [2] = { 0.1,  0.5,  1.0,  1.0  },  -- +第二旋律(50%)
    [1] = { 1.0,  0.5,  1.0,  1.0  },  -- +第一旋律（全开）
}

--- 初始化 BGM（在场景创建后调用一次）
---@param scene Scene
---@param opts? { volume?: number, fadeSpeed?: number }
function BGM.Init(scene, opts)
    opts = opts or {}
    volume = opts.volume or 1.0
    fadeSpeed = opts.fadeSpeed or 2.0

    for i = 1, 4 do
        local sound = cache:GetResource("Sound", TRACKS[i])
        if sound then
            sound.looped = true   -- 引擎原生循环，保证不断播
            local node = scene:CreateChild("BGM_Track" .. i)
            local source = node:CreateComponent("SoundSource")
            source.soundType = SOUND_MUSIC
            source.gain = 0
            source:Play(sound)
            nodes[i] = node
            sources[i] = source
            sounds[i] = sound
            currentGains[i] = 0
        end
    end

    stage = 0
    targetGains = { 0, 0, 0, 0 }
end

--- 设置阶段（1~4，0=全静音）
---@param s integer  0|1|2|3|4
function BGM.SetStage(s)
    local gains = STAGE_GAINS[s]
    if not gains then return end
    stage = s
    for i = 1, 4 do
        targetGains[i] = gains[i]
    end
end

--- 获取当前阶段
---@return integer
function BGM.GetStage()
    return stage
end

--- 设置全局音量
---@param v number  0.0~1.0
function BGM.SetVolume(v)
    volume = math.max(0, math.min(v, 1.0))
end

--- 切换静音状态
function BGM.ToggleMute()
    muted = not muted
end

--- 获取是否静音
---@return boolean
function BGM.IsMuted()
    return muted
end

--- 每帧更新（平滑过渡增益）
---@param dt number
function BGM.Update(dt)
    -- 平滑过渡增益
    local step = fadeSpeed * dt
    for i = 1, 4 do
        if sources[i] then
            local target = targetGains[i]
            local cur = currentGains[i]
            if cur < target then
                cur = math.min(cur + step, target)
            elseif cur > target then
                cur = math.max(cur - step, target)
            end
            currentGains[i] = cur
            sources[i].gain = cur * volume * (muted and 0 or 1)
        end
    end
end

--- 销毁所有 BGM 节点
function BGM.Destroy()
    for i = 1, 4 do
        if nodes[i] then
            nodes[i]:Remove()
            nodes[i] = nil
            sources[i] = nil
        end
    end
    currentGains = { 0, 0, 0, 0 }
    targetGains = { 0, 0, 0, 0 }
    sounds = {}
    stage = 0
end

return BGM
