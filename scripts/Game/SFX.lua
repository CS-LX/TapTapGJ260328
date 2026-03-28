-- ============================================================================
-- Game/SFX.lua — Meme 音效管理器
-- ============================================================================

local State = require "Game.State"

local SFX = {}

---@type table<string, Sound>
local soundCache = {}

---@type Node
local sfxNode = nil

--- 初始化（场景创建后调用一次）
---@param scene Scene
function SFX.Init(scene)
    sfxNode = scene:CreateChild("SFX")
end

--- 预加载音效资源
---@param name string 文件名（不含路径前缀）
---@return Sound|nil
local function getSound(name)
    if soundCache[name] then return soundCache[name] end
    local path = "audio/SFX/" .. name
    local sound = cache:GetResource("Sound", path)
    if sound then
        soundCache[name] = sound
    else
        print("[SFX] WARNING: not found: " .. path)
    end
    return sound
end

--- 播放一次性音效
---@param name string 文件名（如 "eagle_screech.ogg"）
---@param gain? number 音量 0~1，默认 1.0
function SFX.Play(name, gain)
    if not sfxNode then return end
    local sound = getSound(name)
    if not sound then return end
    sound.looped = false
    local source = sfxNode:CreateComponent("SoundSource")
    source.soundType = SOUND_EFFECT
    source.gain = gain or 1.0
    source.autoRemoveMode = REMOVE_COMPONENT
    source:Play(sound)
end

--- 从列表中随机播放一个
---@param names string[] 文件名列表
---@param gain? number 音量
function SFX.PlayRandom(names, gain)
    if #names == 0 then return end
    local idx = math.random(1, #names)
    SFX.Play(names[idx], gain)
end

--- 销毁
function SFX.Destroy()
    soundCache = {}
    if sfxNode then
        sfxNode:Remove()
        sfxNode = nil
    end
end

return SFX
