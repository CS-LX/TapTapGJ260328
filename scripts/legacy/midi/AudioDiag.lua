------------------------------------------------------------
-- AudioDiag.lua
-- 音频爆音诊断工具 — 逐级排查 pop/click 的根源
--
-- 按键说明 (Phase 1 — 单音源基础测试):
--   1 : 播放一个音符，自然结束（不 Stop）
--   2 : 播放一个音符，1 秒后硬 Stop()
--   3 : 播放一个音符，1 秒后 gain=0 → 等2帧 → Stop()
--   4 : 播放一个音符 gain=0 启动, 5帧淡入到0.5
--   5 : 播放一个音符, 完整流程: gain=0启动 → 淡入 → 淡出 → Stop
--
-- Phase 2 — 多音符过渡测试:
--   6 : 连续播放两个不同音符 (间隔100ms静默)
--   7 : 同一音源上切换音符 (Stop旧 → Play新, 无间隔)
--   8 : 同音符快速重触发 (每200ms)
--   9 : 两个音符交叉淡入淡出 (模拟MidiPlayer行为)
--
--   0 : 停止一切，重置
--   P : 开始完整 MIDI 播放测试
------------------------------------------------------------

local AudioDiag = {}
AudioDiag.__index = AudioDiag

------------------------------------------------------------
-- 测试用音符路径 (中央C附近, 容易听出问题)
------------------------------------------------------------
local TEST_NOTES = {
    "audio/Hard/c4.ogg",   -- C4 (中央C)
    "audio/Hard/e4.ogg",   -- E4
    "audio/Hard/g4.ogg",   -- G4
    "audio/Hard/c5.ogg",   -- C5
}

------------------------------------------------------------
-- 构造
------------------------------------------------------------
function AudioDiag.new(scene)
    local self = setmetatable({}, AudioDiag)

    self.scene = scene
    self.audioNode = scene:CreateChild("AudioDiag")

    -- 创建 4 个独立音源用于测试
    self.sources = {}
    for i = 1, 4 do
        self.sources[i] = self.audioNode:CreateComponent("SoundSource")
        self.sources[i].gain = 0
    end

    -- 预加载测试音频
    self.sounds = {}
    for i, path in ipairs(TEST_NOTES) do
        self.sounds[i] = cache:GetResource("Sound", path)
        if self.sounds[i] then
            print(string.format("[DIAG] Loaded test sound %d: %s", i, path))
        else
            print(string.format("[DIAG] FAILED to load: %s", path))
        end
    end

    -- 测试状态机
    self.activeTest = nil    -- 当前运行的测试名
    self.step = 0            -- 测试内部步骤
    self.timer = 0           -- 计时器(秒)
    self.frameCount = 0      -- 帧计数器
    self.testGain = 0.5      -- 测试增益

    -- Phase 2 用
    self.retriggering = false
    self.retriggerInterval = 0.2
    self.retriggerTimer = 0
    self.retriggerCount = 0

    print("[DIAG] ========================================")
    print("[DIAG] Audio Pop Diagnostic Tool Ready")
    print("[DIAG] ========================================")
    print("[DIAG] Phase 1 - Single source tests:")
    print("[DIAG]   1: Play note, natural end")
    print("[DIAG]   2: Play note, hard Stop() at 1s")
    print("[DIAG]   3: Play note, gain=0 → 2 frames → Stop()")
    print("[DIAG]   4: Play note gain=0 start, fade-in 5 frames")
    print("[DIAG]   5: Full cycle: fade-in → play → fade-out → stop")
    print("[DIAG] Phase 2 - Multi-note tests:")
    print("[DIAG]   6: Two notes sequential (100ms gap)")
    print("[DIAG]   7: Switch note on same source (no gap)")
    print("[DIAG]   8: Same note retrigger every 200ms")
    print("[DIAG]   9: Crossfade two notes (simulate MidiPlayer)")
    print("[DIAG] Phase 3 - Pinpoint tests:")
    print("[DIAG]   Q: Reuse source after natural end + 1s gap")
    print("[DIAG]   W: Two FRESH sources play simultaneously")
    print("[DIAG]   E: Reuse source with safe pattern")
    print("[DIAG]   R/T/Y: Variant tests")
    print("[DIAG] Phase 4 - Root cause verification:")
    print("[DIAG]   A: Separate nodes + simultaneous Play (vs W)")
    print("[DIAG]   S: Separate nodes + crossfade (vs T9)")
    print("[DIAG]   D: Same node but 10-frame gap between Stop/Play (vs R)")
    print("[DIAG]   F: Separate nodes + retrigger (vs T8)")
    print("[DIAG] Phase 5 - Solution: NEVER call Stop():")
    print("[DIAG]   G: Crossfade WITHOUT Stop (gain=0 silence, no Stop)")
    print("[DIAG]   H: Retrigger WITHOUT Stop (gain=0 + Play覆盖)")
    print("[DIAG]   J: MidiPlayer模拟 (连续多音符, 不调Stop)")
    print("[DIAG]   K: 对比测试 (同场景, 左=有Stop 右=无Stop)")
    print("[DIAG] Phase 6 - Refined: fresh Node + long fade + no reuse:")
    print("[DIAG]   L: 交叉淡化 15帧慢淡 + 全新Node (不Remove)")
    print("[DIAG]   M: 交叉淡化 15帧慢淡 + 全新Node (gain=0后Remove)")
    print("[DIAG]   N: 重触发 每次新Node新Source (旧的慢淡出)")
    print("[DIAG]   O: 完整MidiPlayer模拟 (最终方案)")
    print("[DIAG] Control:")
    print("[DIAG]   0: Stop all, reset")
    print("[DIAG] ========================================")

    return self
end

------------------------------------------------------------
-- 停止一切
------------------------------------------------------------
function AudioDiag:stopAll()
    for i = 1, #self.sources do
        self.sources[i].gain = 0
        self.sources[i]:Stop()
    end
    self.activeTest = nil
    self.step = 0
    self.timer = 0
    self.frameCount = 0
    self.retriggering = false
    print("[DIAG] === All stopped, reset ===")
end

------------------------------------------------------------
-- 每帧调用
------------------------------------------------------------
function AudioDiag:update(dt)
    -- 按键检测
    if input:GetKeyPress(KEY_0) then
        self:stopAll()
        return
    end

    if input:GetKeyPress(KEY_1) then self:startTest("T1_natural_end") end
    if input:GetKeyPress(KEY_2) then self:startTest("T2_hard_stop") end
    if input:GetKeyPress(KEY_3) then self:startTest("T3_gain0_stop") end
    if input:GetKeyPress(KEY_4) then self:startTest("T4_fadein") end
    if input:GetKeyPress(KEY_5) then self:startTest("T5_full_cycle") end
    if input:GetKeyPress(KEY_6) then self:startTest("T6_two_notes_gap") end
    if input:GetKeyPress(KEY_7) then self:startTest("T7_switch_same_source") end
    if input:GetKeyPress(KEY_8) then self:startTest("T8_retrigger") end
    if input:GetKeyPress(KEY_9) then self:startTest("T9_crossfade") end

    -- Phase 3 按键 (Q/W/E/R/T/Y)
    if input:GetKeyPress(KEY_Q) then self:startTest("TQ_reuse_long_gap") end
    if input:GetKeyPress(KEY_W) then self:startTest("TW_two_fresh_simultaneous") end
    if input:GetKeyPress(KEY_E) then self:startTest("TE_reuse_safe_pattern") end
    if input:GetKeyPress(KEY_R) then self:startTest("TR_different_source") end
    if input:GetKeyPress(KEY_T) then self:startTest("TT_different_source_safe") end
    if input:GetKeyPress(KEY_Y) then self:startTest("TY_stacked_sources") end

    -- Phase 4 按键 (A/S/D/F)
    if input:GetKeyPress(KEY_A) then self:startTest("TA_separate_nodes_simultaneous") end
    if input:GetKeyPress(KEY_S) then self:startTest("TS_separate_nodes_crossfade") end
    if input:GetKeyPress(KEY_D) then self:startTest("TD_frame_gap") end
    if input:GetKeyPress(KEY_F) then self:startTest("TF_separate_nodes_retrigger") end

    -- Phase 5 按键 (G/H/J/K)
    if input:GetKeyPress(KEY_G) then self:startTest("TG_crossfade_no_stop") end
    if input:GetKeyPress(KEY_H) then self:startTest("TH_retrigger_no_stop") end
    if input:GetKeyPress(KEY_J) then self:startTest("TJ_midi_sim_no_stop") end
    if input:GetKeyPress(KEY_K) then self:startTest("TK_ab_compare") end

    -- Phase 6 按键 (L/M/N/O)
    if input:GetKeyPress(KEY_L) then self:startTest("TL_long_fade_no_remove") end
    if input:GetKeyPress(KEY_M) then self:startTest("TM_long_fade_with_remove") end
    if input:GetKeyPress(KEY_N) then self:startTest("TN_retrigger_fresh_nodes") end
    if input:GetKeyPress(KEY_O) then self:startTest("TO_midi_sim_final") end

    -- 驱动当前测试
    if self.activeTest then
        self.timer = self.timer + dt
        self.frameCount = self.frameCount + 1
        self["run_" .. self.activeTest](self, dt)
    end
end

function AudioDiag:startTest(name)
    self:stopAll()
    self.activeTest = name
    self.step = 0
    self.timer = 0
    self.frameCount = 0
    print(string.format("[DIAG] --- Starting %s ---", name))
end

------------------------------------------------------------
-- TEST 1: 播放一个音符, 自然结束
-- 目的: 检测采样本身是否有 pop
------------------------------------------------------------
function AudioDiag:run_T1_natural_end(dt)
    if self.step == 0 then
        local src = self.sources[1]
        src.gain = self.testGain
        src:Play(self.sounds[1])
        print(string.format("[DIAG] T1: Playing C4 at gain=%.2f, will end naturally", self.testGain))
        print("[DIAG] T1: >> Listen for pop at START and when note fades to silence <<")
        self.step = 1
    elseif self.step == 1 then
        -- 等待自然结束
        if not self.sources[1]:IsPlaying() then
            print(string.format("[DIAG] T1: Note ended naturally at %.2fs", self.timer))
            print("[DIAG] T1: >> Did you hear any pop? At start? At end? <<")
            self.activeTest = nil
        end
    end
end

------------------------------------------------------------
-- TEST 2: 播放一个音符, 1秒后硬 Stop()
-- 目的: 检测 Stop() 是否产生 pop
------------------------------------------------------------
function AudioDiag:run_T2_hard_stop(dt)
    if self.step == 0 then
        local src = self.sources[1]
        src.gain = self.testGain
        src:Play(self.sounds[1])
        print("[DIAG] T2: Playing C4, will hard Stop() at 1.0s")
        self.step = 1
    elseif self.step == 1 and self.timer >= 1.0 then
        print("[DIAG] T2: >>> Hard Stop() NOW <<<")
        self.sources[1]:Stop()
        print("[DIAG] T2: >> Did you hear a pop when it stopped? <<")
        self.activeTest = nil
    end
end

------------------------------------------------------------
-- TEST 3: 播放, 1秒后 gain=0, 等2帧, 再 Stop()
-- 目的: 检测 gain=0 是否能防止 Stop() 的 pop
------------------------------------------------------------
function AudioDiag:run_T3_gain0_stop(dt)
    if self.step == 0 then
        local src = self.sources[1]
        src.gain = self.testGain
        src:Play(self.sounds[1])
        print("[DIAG] T3: Playing C4, will set gain=0 at 1.0s, then Stop() 2 frames later")
        self.step = 1
    elseif self.step == 1 and self.timer >= 1.0 then
        self.sources[1].gain = 0
        print(string.format("[DIAG] T3: gain=0 set at frame %d, waiting 2 frames...", self.frameCount))
        self.step = 2
        self.frameCount = 0  -- 重新计帧
    elseif self.step == 2 and self.frameCount >= 2 then
        self.sources[1]:Stop()
        print("[DIAG] T3: Stop() called after 2 frames of gain=0")
        print("[DIAG] T3: >> Did you hear a pop? Compare with T2 <<")
        self.activeTest = nil
    end
end

------------------------------------------------------------
-- TEST 4: gain=0 启动, 5帧淡入到 0.5
-- 目的: 检测 Play() 时 gain=0 + 淡入 是否有 pop
------------------------------------------------------------
function AudioDiag:run_T4_fadein(dt)
    local FADE_FRAMES = 5
    if self.step == 0 then
        local src = self.sources[1]
        src.gain = 0
        src:Play(self.sounds[1])
        print("[DIAG] T4: Playing C4 with gain=0, fading in over 5 frames")
        self.step = 1
        self.frameCount = 0
    elseif self.step == 1 then
        local progress = math.min(self.frameCount / FADE_FRAMES, 1.0)
        self.sources[1].gain = progress * self.testGain
        if self.frameCount <= FADE_FRAMES then
            print(string.format("[DIAG] T4: frame %d gain=%.3f", self.frameCount, self.sources[1].gain))
        end
        if progress >= 1.0 then
            print("[DIAG] T4: Fade-in complete, note playing at full gain")
            print("[DIAG] T4: >> Did you hear a pop at the very start? <<")
            self.step = 2
        end
    elseif self.step == 2 then
        -- 让它继续播放, 用户按0停止
        if not self.sources[1]:IsPlaying() then
            self.activeTest = nil
        end
    end
end

------------------------------------------------------------
-- TEST 5: 完整生命周期: gain=0启动 → 淡入 → 播放 → 淡出 → Stop
-- 目的: 验证完整的 anti-pop 流程
------------------------------------------------------------
function AudioDiag:run_T5_full_cycle(dt)
    local FADE_IN_FRAMES = 5
    local PLAY_TIME = 1.0
    local FADE_OUT_FRAMES = 15

    if self.step == 0 then
        -- 启动: gain=0
        self.sources[1].gain = 0
        self.sources[1]:Play(self.sounds[1])
        print("[DIAG] T5: Start gain=0, fade-in 5f, play 1s, fade-out 15f, Stop")
        self.step = 1
        self.frameCount = 0
    elseif self.step == 1 then
        -- 淡入
        local progress = math.min(self.frameCount / FADE_IN_FRAMES, 1.0)
        self.sources[1].gain = progress * self.testGain
        if progress >= 1.0 then
            print(string.format("[DIAG] T5: Fade-in done at frame %d", self.frameCount))
            self.step = 2
            self.timer = 0  -- 重新计时
        end
    elseif self.step == 2 then
        -- 正常播放
        if self.timer >= PLAY_TIME then
            print("[DIAG] T5: Starting fade-out...")
            self.step = 3
            self.frameCount = 0
        end
    elseif self.step == 3 then
        -- 淡出
        local progress = math.min(self.frameCount / FADE_OUT_FRAMES, 1.0)
        self.sources[1].gain = self.testGain * (1.0 - progress)
        if progress >= 1.0 then
            self.sources[1].gain = 0
            print(string.format("[DIAG] T5: Fade-out done, gain=0, calling Stop()"))
            self.step = 4
            self.frameCount = 0
        end
    elseif self.step == 4 then
        -- 等2帧后Stop
        if self.frameCount >= 2 then
            self.sources[1]:Stop()
            print("[DIAG] T5: Stopped. Full cycle complete.")
            print("[DIAG] T5: >> Any pop at start, during fade, or at end? <<")
            self.activeTest = nil
        end
    end
end

------------------------------------------------------------
-- TEST 6: 两个不同音符, 间隔100ms静默
-- 目的: 检测音符切换时是否有 pop
------------------------------------------------------------
function AudioDiag:run_T6_two_notes_gap(dt)
    if self.step == 0 then
        self.sources[1].gain = self.testGain
        self.sources[1]:Play(self.sounds[1])  -- C4
        print("[DIAG] T6: Playing C4, will stop at 0.5s, 100ms silence, then E4")
        self.step = 1
    elseif self.step == 1 and self.timer >= 0.5 then
        self.sources[1].gain = 0
        print("[DIAG] T6: gain=0 on C4")
        self.step = 2
        self.frameCount = 0
    elseif self.step == 2 and self.frameCount >= 2 then
        self.sources[1]:Stop()
        print("[DIAG] T6: C4 stopped, waiting 100ms silence...")
        self.step = 3
        self.timer = 0
    elseif self.step == 3 and self.timer >= 0.1 then
        self.sources[1].gain = self.testGain
        self.sources[1]:Play(self.sounds[2])  -- E4
        print("[DIAG] T6: Playing E4")
        print("[DIAG] T6: >> Pop during the transition? <<")
        self.step = 4
    elseif self.step == 4 and self.timer >= 1.5 then
        self.sources[1].gain = 0
        self.sources[1]:Stop()
        self.activeTest = nil
    end
end

------------------------------------------------------------
-- TEST 7: 同一音源切换音符 (Stop旧 → 立即Play新)
-- 目的: 检测无缝切换是否 pop
------------------------------------------------------------
function AudioDiag:run_T7_switch_same_source(dt)
    if self.step == 0 then
        self.sources[1].gain = self.testGain
        self.sources[1]:Play(self.sounds[1])  -- C4
        print("[DIAG] T7: Playing C4, will switch to E4 at 0.5s on SAME source")
        self.step = 1
    elseif self.step == 1 and self.timer >= 0.5 then
        -- 直接切换: Stop → Play
        print("[DIAG] T7: >>> Switching NOW: Stop(C4) → Play(E4) <<<")
        self.sources[1]:Stop()
        self.sources[1].gain = self.testGain
        self.sources[1]:Play(self.sounds[2])
        self.step = 2
    elseif self.step == 2 and self.timer >= 1.5 then
        self.sources[1].gain = 0
        self.sources[1]:Stop()
        print("[DIAG] T7: >> Pop at the switch point? <<")
        self.activeTest = nil
    end
end

------------------------------------------------------------
-- TEST 8: 同音符快速重触发 (每200ms)
-- 目的: 检测 retrigger 是否 pop
------------------------------------------------------------
function AudioDiag:run_T8_retrigger(dt)
    if self.step == 0 then
        self.sources[1].gain = self.testGain
        self.sources[1]:Play(self.sounds[1])
        print("[DIAG] T8: Retriggering C4 every 200ms, 10 times. Listen for pops.")
        self.step = 1
        self.retriggerTimer = 0
        self.retriggerCount = 0
    elseif self.step == 1 then
        self.retriggerTimer = self.retriggerTimer + dt
        if self.retriggerTimer >= 0.2 then
            self.retriggerTimer = 0
            self.retriggerCount = self.retriggerCount + 1
            -- 硬重触发
            self.sources[1]:Stop()
            self.sources[1].gain = self.testGain
            self.sources[1]:Play(self.sounds[1])
            print(string.format("[DIAG] T8: Retrigger #%d", self.retriggerCount))
            if self.retriggerCount >= 10 then
                print("[DIAG] T8: Done. >> Pops on retrigger? <<")
                self.step = 2
            end
        end
    elseif self.step == 2 and self.timer >= 5.0 then
        self.sources[1].gain = 0
        self.sources[1]:Stop()
        self.activeTest = nil
    end
end

------------------------------------------------------------
-- TEST 9: 交叉淡入淡出 (模拟 MidiPlayer 的行为)
-- 音符A淡出的同时, 音符B在另一个source上淡入
------------------------------------------------------------
function AudioDiag:run_T9_crossfade(dt)
    local FADE_FRAMES = 5

    if self.step == 0 then
        -- 播放音符A
        self.sources[1].gain = 0
        self.sources[1]:Play(self.sounds[1])  -- C4 on source 1
        print("[DIAG] T9: Playing C4 (fade-in)...")
        self.step = 1
        self.frameCount = 0
    elseif self.step == 1 then
        -- 淡入A
        local p = math.min(self.frameCount / FADE_FRAMES, 1.0)
        self.sources[1].gain = p * self.testGain
        if p >= 1.0 then
            self.step = 2
            self.timer = 0
        end
    elseif self.step == 2 and self.timer >= 0.5 then
        -- 开始交叉淡化: A淡出, B淡入
        self.sources[2].gain = 0
        self.sources[2]:Play(self.sounds[2])  -- E4 on source 2
        print("[DIAG] T9: >>> Crossfading C4→E4 over 5 frames <<<")
        self.step = 3
        self.frameCount = 0
    elseif self.step == 3 then
        local p = math.min(self.frameCount / FADE_FRAMES, 1.0)
        -- A 淡出
        self.sources[1].gain = self.testGain * (1.0 - p)
        -- B 淡入
        self.sources[2].gain = self.testGain * p
        if p >= 1.0 then
            self.sources[1].gain = 0
            self.sources[1]:Stop()
            print("[DIAG] T9: Crossfade done, C4 stopped, E4 playing")
            print("[DIAG] T9: >> Pop during crossfade? <<")
            self.step = 4
            self.timer = 0
        end
    elseif self.step == 4 and self.timer >= 1.0 then
        -- 再做一次: E4→G4
        self.sources[3].gain = 0
        self.sources[3]:Play(self.sounds[3])  -- G4 on source 3
        print("[DIAG] T9: >>> Crossfading E4→G4 <<<")
        self.step = 5
        self.frameCount = 0
    elseif self.step == 5 then
        local p = math.min(self.frameCount / FADE_FRAMES, 1.0)
        self.sources[2].gain = self.testGain * (1.0 - p)
        self.sources[3].gain = self.testGain * p
        if p >= 1.0 then
            self.sources[2].gain = 0
            self.sources[2]:Stop()
            print("[DIAG] T9: Crossfade E4→G4 done")
            print("[DIAG] T9: >> Pop during second crossfade? <<")
            self.step = 6
            self.timer = 0
        end
    elseif self.step == 6 and self.timer >= 1.0 then
        self.sources[3].gain = 0
        self.sources[3]:Stop()
        print("[DIAG] T9: All done.")
        self.activeTest = nil
    end
end

------------------------------------------------------------
-- Phase 3: 精确定位 (Q/W/E/R/T/Y)
------------------------------------------------------------

-- TEST Q: 音源复用 + 长间隔
-- 播放C4 → 自然结束 → 等1秒 → 在同一音源再播放C4
-- 目的: 复用本身是否爆音 (排除时序因素)
function AudioDiag:run_TQ_reuse_long_gap(dt)
    if self.step == 0 then
        self.sources[1].gain = self.testGain
        self.sources[1]:Play(self.sounds[1])
        print("[DIAG] TQ: Playing C4 on source 1, waiting for natural end + 1s...")
        self.step = 1
    elseif self.step == 1 then
        if not self.sources[1]:IsPlaying() then
            print("[DIAG] TQ: C4 ended, waiting 1 second...")
            self.step = 2
            self.timer = 0
        end
    elseif self.step == 2 and self.timer >= 1.0 then
        print("[DIAG] TQ: >>> Playing C4 AGAIN on SAME source <<<")
        self.sources[1].gain = self.testGain
        self.sources[1]:Play(self.sounds[1])
        self.step = 3
    elseif self.step == 3 then
        if not self.sources[1]:IsPlaying() then
            print("[DIAG] TQ: Done. >> Pop when second note started? <<")
            self.activeTest = nil
        end
    end
end

-- TEST W: 两个全新音源同时播放 (非复用, 纯并发)
-- 同时在 source1 播C4 + source2 播E4
-- 目的: 并发本身是否爆音
function AudioDiag:run_TW_two_fresh_simultaneous(dt)
    if self.step == 0 then
        self.sources[1].gain = self.testGain
        self.sources[2].gain = self.testGain
        self.sources[1]:Play(self.sounds[1])  -- C4
        self.sources[2]:Play(self.sounds[2])  -- E4
        print("[DIAG] TW: Playing C4+E4 simultaneously on two FRESH sources")
        print("[DIAG] TW: >> Pop at start? <<")
        self.step = 1
    elseif self.step == 1 then
        if not self.sources[1]:IsPlaying() and not self.sources[2]:IsPlaying() then
            print("[DIAG] TW: Both ended naturally")
            self.activeTest = nil
        end
    end
end

-- TEST E: 复用但安全模式 (gain=0启动 + 淡入)
-- 播C4 → fade-out+Stop → 等500ms → gain=0+Play E4 → fade-in
-- 目的: 安全模式能否解决复用爆音
function AudioDiag:run_TE_reuse_safe_pattern(dt)
    local FADE_FRAMES = 5
    if self.step == 0 then
        self.sources[1].gain = self.testGain
        self.sources[1]:Play(self.sounds[1])
        print("[DIAG] TE: Playing C4, will fade-out → stop → 500ms → safe-start E4")
        self.step = 1
    elseif self.step == 1 and self.timer >= 0.5 then
        print("[DIAG] TE: Starting fade-out...")
        self.step = 2
        self.frameCount = 0
    elseif self.step == 2 then
        local p = math.min(self.frameCount / FADE_FRAMES, 1.0)
        self.sources[1].gain = self.testGain * (1.0 - p)
        if p >= 1.0 then
            self.sources[1].gain = 0
            self.step = 3
            self.frameCount = 0
        end
    elseif self.step == 3 and self.frameCount >= 2 then
        self.sources[1]:Stop()
        print("[DIAG] TE: Stopped. Waiting 500ms...")
        self.step = 4
        self.timer = 0
    elseif self.step == 4 and self.timer >= 0.5 then
        -- 安全模式启动E4
        self.sources[1].gain = 0
        self.sources[1]:Play(self.sounds[2])
        print("[DIAG] TE: >>> Safe-starting E4 (gain=0, fading in) <<<")
        self.step = 5
        self.frameCount = 0
    elseif self.step == 5 then
        local p = math.min(self.frameCount / FADE_FRAMES, 1.0)
        self.sources[1].gain = p * self.testGain
        if p >= 1.0 then
            print("[DIAG] TE: Fade-in done. >> Pop at E4 start? <<")
            self.step = 6
        end
    elseif self.step == 6 then
        if not self.sources[1]:IsPlaying() then
            self.activeTest = nil
        end
    end
end

-- TEST R: 用不同音源播放第二个音符 (避免复用)
-- source1 播C4 → fade-out+Stop → source2 播E4 (直接gain=0.5)
-- 目的: 不复用音源时, 连续播放是否爆音
function AudioDiag:run_TR_different_source(dt)
    local FADE_FRAMES = 5
    if self.step == 0 then
        self.sources[1].gain = self.testGain
        self.sources[1]:Play(self.sounds[1])
        print("[DIAG] TR: C4 on source1, will switch to E4 on source2 (no reuse)")
        self.step = 1
    elseif self.step == 1 and self.timer >= 0.5 then
        -- 淡出 source 1
        self.step = 2
        self.frameCount = 0
    elseif self.step == 2 then
        local p = math.min(self.frameCount / FADE_FRAMES, 1.0)
        self.sources[1].gain = self.testGain * (1.0 - p)
        if p >= 1.0 then
            self.sources[1].gain = 0
            self.step = 3
            self.frameCount = 0
        end
    elseif self.step == 3 and self.frameCount >= 2 then
        self.sources[1]:Stop()
        -- 立即在 source2 上播放E4
        self.sources[2].gain = self.testGain
        self.sources[2]:Play(self.sounds[2])
        print("[DIAG] TR: >>> E4 on source2 (fresh, gain=0.5 direct) <<<")
        print("[DIAG] TR: >> Pop at switch? <<")
        self.step = 4
    elseif self.step == 4 then
        if not self.sources[2]:IsPlaying() then
            self.activeTest = nil
        end
    end
end

-- TEST T: 第二音源也用安全模式
-- source1播C4 → fade-out → source2 gain=0+Play E4 → fade-in
-- 目的: 新音源 + 安全模式 = 完美方案?
function AudioDiag:run_TT_different_source_safe(dt)
    local FADE_FRAMES = 5
    if self.step == 0 then
        self.sources[1].gain = 0
        self.sources[1]:Play(self.sounds[1])
        print("[DIAG] TT: C4 fade-in on src1, then crossfade to E4 on src2 (both safe)")
        self.step = 1
        self.frameCount = 0
    elseif self.step == 1 then
        local p = math.min(self.frameCount / FADE_FRAMES, 1.0)
        self.sources[1].gain = p * self.testGain
        if p >= 1.0 then
            self.step = 2
            self.timer = 0
        end
    elseif self.step == 2 and self.timer >= 0.5 then
        -- 开始交叉: source1 淡出, source2 淡入
        self.sources[2].gain = 0
        self.sources[2]:Play(self.sounds[2])
        print("[DIAG] TT: >>> Crossfading src1→src2, both with fade <<<")
        self.step = 3
        self.frameCount = 0
    elseif self.step == 3 then
        local p = math.min(self.frameCount / FADE_FRAMES, 1.0)
        self.sources[1].gain = self.testGain * (1.0 - p)
        self.sources[2].gain = self.testGain * p
        if p >= 1.0 then
            self.sources[1].gain = 0
            self.step = 4
            self.frameCount = 0
        end
    elseif self.step == 4 and self.frameCount >= 2 then
        self.sources[1]:Stop()
        print("[DIAG] TT: Crossfade done. E4 playing on src2.")
        print("[DIAG] TT: >> Pop during crossfade? <<")
        self.step = 5
    elseif self.step == 5 then
        if not self.sources[2]:IsPlaying() then
            self.activeTest = nil
        end
    end
end

-- TEST Y: 纯并发渐进 — 先1个音源, 再加1个, 再加1个
-- 每隔0.5s在一个新音源上直接Play不同音符
-- 目的: 音源数量递增时哪个点开始爆音
function AudioDiag:run_TY_stacked_sources(dt)
    if self.step == 0 then
        self.sources[1].gain = self.testGain
        self.sources[1]:Play(self.sounds[1])
        print("[DIAG] TY: Playing C4 on src1")
        self.step = 1
        self.timer = 0
    elseif self.step == 1 and self.timer >= 0.5 then
        self.sources[2].gain = self.testGain
        self.sources[2]:Play(self.sounds[2])
        print("[DIAG] TY: +E4 on src2 (now 2 sources)")
        print("[DIAG] TY: >> Pop when src2 started? <<")
        self.step = 2
        self.timer = 0
    elseif self.step == 2 and self.timer >= 0.5 then
        self.sources[3].gain = self.testGain
        self.sources[3]:Play(self.sounds[3])
        print("[DIAG] TY: +G4 on src3 (now 3 sources)")
        print("[DIAG] TY: >> Pop when src3 started? <<")
        self.step = 3
        self.timer = 0
    elseif self.step == 3 and self.timer >= 0.5 then
        self.sources[4].gain = self.testGain
        self.sources[4]:Play(self.sounds[4])
        print("[DIAG] TY: +C5 on src4 (now 4 sources)")
        print("[DIAG] TY: >> Pop when src4 started? <<")
        self.step = 4
        self.timer = 0
    elseif self.step == 4 and self.timer >= 2.0 then
        for i = 1, 4 do
            self.sources[i].gain = 0
            self.sources[i]:Stop()
        end
        print("[DIAG] TY: All stopped")
        self.activeTest = nil
    end
end

------------------------------------------------------------
-- Phase 4: 根因验证 (A/S/D/F)
------------------------------------------------------------

-- TEST A: 每个音源在独立 Node 上, 同帧 Play
-- 对比W: W用同一Node, A用不同Node
-- 目的: 验证是否是同 Node 多 SoundSource 干扰
function AudioDiag:run_TA_separate_nodes_simultaneous(dt)
    if self.step == 0 then
        -- 创建独立节点+音源
        self._testNodes = {}
        self._testSrcs = {}
        for i = 1, 2 do
            local node = self.scene:CreateChild("DiagNode" .. i)
            local src = node:CreateComponent("SoundSource")
            self._testNodes[i] = node
            self._testSrcs[i] = src
        end
        self._testSrcs[1].gain = self.testGain
        self._testSrcs[2].gain = self.testGain
        self._testSrcs[1]:Play(self.sounds[1])  -- C4
        self._testSrcs[2]:Play(self.sounds[2])  -- E4
        print("[DIAG] TA: C4+E4 同帧Play, 每个音源在独立Node上")
        print("[DIAG] TA: >> 是否能听到和弦(同时)? 有爆音吗? <<")
        self.step = 1
    elseif self.step == 1 then
        if not self._testSrcs[1]:IsPlaying() and not self._testSrcs[2]:IsPlaying() then
            for i = 1, 2 do self._testNodes[i]:Remove() end
            self._testNodes = nil
            self._testSrcs = nil
            print("[DIAG] TA: Done")
            self.activeTest = nil
        end
    end
end

-- TEST S: 独立Node + 交叉淡入淡出 (对比T9)
-- 目的: 独立Node能否解决T9的交叉淡化爆音
function AudioDiag:run_TS_separate_nodes_crossfade(dt)
    local FADE_FRAMES = 5
    if self.step == 0 then
        self._testNodes = {}
        self._testSrcs = {}
        for i = 1, 3 do
            local node = self.scene:CreateChild("DiagXNode" .. i)
            local src = node:CreateComponent("SoundSource")
            src.gain = 0
            self._testNodes[i] = node
            self._testSrcs[i] = src
        end
        -- 播放C4, 淡入
        self._testSrcs[1]:Play(self.sounds[1])
        print("[DIAG] TS: 独立Node交叉淡化测试: C4→E4→G4")
        self.step = 1
        self.frameCount = 0
    elseif self.step == 1 then
        -- 淡入 C4
        local p = math.min(self.frameCount / FADE_FRAMES, 1.0)
        self._testSrcs[1].gain = p * self.testGain
        if p >= 1.0 then
            self.step = 2
            self.timer = 0
        end
    elseif self.step == 2 and self.timer >= 0.5 then
        -- 交叉: C4淡出, E4淡入
        self._testSrcs[2]:Play(self.sounds[2])
        print("[DIAG] TS: >>> Crossfade C4→E4 <<<")
        self.step = 3
        self.frameCount = 0
    elseif self.step == 3 then
        local p = math.min(self.frameCount / FADE_FRAMES, 1.0)
        self._testSrcs[1].gain = self.testGain * (1.0 - p)
        self._testSrcs[2].gain = self.testGain * p
        if p >= 1.0 then
            self._testSrcs[1].gain = 0
            self.step = 4
            self.frameCount = 0
        end
    elseif self.step == 4 and self.frameCount >= 2 then
        self._testSrcs[1]:Stop()
        print("[DIAG] TS: C4 stopped. >> Pop during crossfade? <<")
        self.step = 5
        self.timer = 0
    elseif self.step == 5 and self.timer >= 0.5 then
        -- 交叉: E4淡出, G4淡入
        self._testSrcs[3]:Play(self.sounds[3])
        print("[DIAG] TS: >>> Crossfade E4→G4 <<<")
        self.step = 6
        self.frameCount = 0
    elseif self.step == 6 then
        local p = math.min(self.frameCount / FADE_FRAMES, 1.0)
        self._testSrcs[2].gain = self.testGain * (1.0 - p)
        self._testSrcs[3].gain = self.testGain * p
        if p >= 1.0 then
            self._testSrcs[2].gain = 0
            self.step = 7
            self.frameCount = 0
        end
    elseif self.step == 7 and self.frameCount >= 2 then
        self._testSrcs[2]:Stop()
        print("[DIAG] TS: E4 stopped. >> Pop during 2nd crossfade? <<")
        self.step = 8
        self.timer = 0
    elseif self.step == 8 and self.timer >= 1.5 then
        self._testSrcs[3].gain = 0
        self._testSrcs[3]:Stop()
        for i = 1, 3 do self._testNodes[i]:Remove() end
        self._testNodes = nil
        self._testSrcs = nil
        print("[DIAG] TS: Done")
        self.activeTest = nil
    end
end

-- TEST D: Stop 和 Play 隔 10 帧 (同一Node, 不同音源)
-- 对比R: R是同帧Stop+Play, D隔10帧
-- 目的: 帧间隔能否解决爆音
function AudioDiag:run_TD_frame_gap(dt)
    local FADE_FRAMES = 5
    if self.step == 0 then
        self.sources[1].gain = self.testGain
        self.sources[1]:Play(self.sounds[1])
        print("[DIAG] TD: C4 on src1, fade-out→Stop, wait 10 frames, E4 on src2")
        self.step = 1
    elseif self.step == 1 and self.timer >= 0.5 then
        self.step = 2
        self.frameCount = 0
    elseif self.step == 2 then
        local p = math.min(self.frameCount / FADE_FRAMES, 1.0)
        self.sources[1].gain = self.testGain * (1.0 - p)
        if p >= 1.0 then
            self.sources[1].gain = 0
            self.step = 3
            self.frameCount = 0
        end
    elseif self.step == 3 and self.frameCount >= 2 then
        self.sources[1]:Stop()
        print("[DIAG] TD: Src1 stopped, waiting 10 frames...")
        self.step = 4
        self.frameCount = 0
    elseif self.step == 4 and self.frameCount >= 10 then
        -- 10帧后在 src2 上播
        self.sources[2].gain = self.testGain
        self.sources[2]:Play(self.sounds[2])
        print("[DIAG] TD: >>> E4 on src2 after 10 frame gap <<<")
        print("[DIAG] TD: >> Pop? Compare with R <<")
        self.step = 5
    elseif self.step == 5 then
        if not self.sources[2]:IsPlaying() then
            self.activeTest = nil
        end
    end
end

-- TEST F: 独立Node + 同音符快速重触发 (对比T8)
-- 每次用新Node新Source, 旧的淡出
-- 目的: 独立Node能否解决重触发爆音
function AudioDiag:run_TF_separate_nodes_retrigger(dt)
    if self.step == 0 then
        self._retrigNodes = {}
        self._retrigSrcs = {}
        -- 首次播放
        local node = self.scene:CreateChild("RetrigNode1")
        local src = node:CreateComponent("SoundSource")
        src.gain = self.testGain
        src:Play(self.sounds[1])
        self._retrigNodes[1] = node
        self._retrigSrcs[1] = src
        self._retrigIdx = 1
        self.retriggerTimer = 0
        self.retriggerCount = 0
        print("[DIAG] TF: 独立Node重触发, 每200ms新Node播C4, 旧的淡出")
        self.step = 1
    elseif self.step == 1 then
        -- 淡出旧的
        for i = 1, self._retrigIdx - 1 do
            if self._retrigSrcs[i] and self._retrigSrcs[i]:IsPlaying() then
                local g = self._retrigSrcs[i].gain * 0.85
                if g < 0.001 then
                    self._retrigSrcs[i].gain = 0
                    self._retrigSrcs[i]:Stop()
                else
                    self._retrigSrcs[i].gain = g
                end
            end
        end
        self.retriggerTimer = self.retriggerTimer + dt
        if self.retriggerTimer >= 0.2 then
            self.retriggerTimer = 0
            self.retriggerCount = self.retriggerCount + 1
            -- 新Node新Source
            self._retrigIdx = self._retrigIdx + 1
            local node = self.scene:CreateChild("RetrigNode" .. self._retrigIdx)
            local src = node:CreateComponent("SoundSource")
            src.gain = self.testGain
            src:Play(self.sounds[1])
            self._retrigNodes[self._retrigIdx] = node
            self._retrigSrcs[self._retrigIdx] = src
            print(string.format("[DIAG] TF: Retrigger #%d (new node)", self.retriggerCount))
            if self.retriggerCount >= 10 then
                print("[DIAG] TF: Done. >> Pops? Compare with T8 <<")
                self.step = 2
                self.timer = 0
            end
        end
    elseif self.step == 2 and self.timer >= 1.0 then
        -- 清理
        for i = 1, self._retrigIdx do
            if self._retrigSrcs[i] then
                self._retrigSrcs[i].gain = 0
                self._retrigSrcs[i]:Stop()
            end
            if self._retrigNodes[i] then
                self._retrigNodes[i]:Remove()
            end
        end
        self._retrigNodes = nil
        self._retrigSrcs = nil
        print("[DIAG] TF: Cleaned up")
        self.activeTest = nil
    end
end

------------------------------------------------------------
-- Phase 5: 解决方案验证 — 完全不调 Stop() (G/H/J/K)
------------------------------------------------------------

-- TEST G: 交叉淡化但不调 Stop — 旧音源 gain=0 保持"静默播放"
-- 对比S: S用独立Node+交叉淡化+Stop, 有爆音
-- 目的: 不调Stop能否消除交叉淡化的爆音
function AudioDiag:run_TG_crossfade_no_stop(dt)
    local FADE_FRAMES = 5
    if self.step == 0 then
        -- 为每个音符创建独立Node+Source
        self._p5Nodes = {}
        self._p5Srcs = {}
        for i = 1, 3 do
            local node = self.scene:CreateChild("P5Node" .. i)
            local src = node:CreateComponent("SoundSource")
            src.gain = 0
            self._p5Nodes[i] = node
            self._p5Srcs[i] = src
        end
        -- 播放C4, 淡入
        self._p5Srcs[1]:Play(self.sounds[1])
        print("[DIAG] TG: 交叉淡化 WITHOUT Stop() — C4→E4→G4")
        print("[DIAG] TG: 旧音源只设gain=0, 绝不调Stop()")
        self.step = 1
        self.frameCount = 0
    elseif self.step == 1 then
        -- 淡入 C4
        local p = math.min(self.frameCount / FADE_FRAMES, 1.0)
        self._p5Srcs[1].gain = p * self.testGain
        if p >= 1.0 then
            self.step = 2
            self.timer = 0
        end
    elseif self.step == 2 and self.timer >= 0.5 then
        -- 交叉: C4淡出, E4淡入 — 不Stop C4!
        self._p5Srcs[2]:Play(self.sounds[2])
        print("[DIAG] TG: >>> Crossfade C4→E4 (NO Stop on C4) <<<")
        self.step = 3
        self.frameCount = 0
    elseif self.step == 3 then
        local p = math.min(self.frameCount / FADE_FRAMES, 1.0)
        self._p5Srcs[1].gain = self.testGain * (1.0 - p)
        self._p5Srcs[2].gain = self.testGain * p
        if p >= 1.0 then
            self._p5Srcs[1].gain = 0  -- 静默, 但不Stop!
            print("[DIAG] TG: C4 gain=0 (still playing silently). >> Pop? <<")
            self.step = 4
            self.timer = 0
        end
    elseif self.step == 4 and self.timer >= 0.5 then
        -- 交叉: E4淡出, G4淡入 — 不Stop E4!
        self._p5Srcs[3]:Play(self.sounds[3])
        print("[DIAG] TG: >>> Crossfade E4→G4 (NO Stop on E4) <<<")
        self.step = 5
        self.frameCount = 0
    elseif self.step == 5 then
        local p = math.min(self.frameCount / FADE_FRAMES, 1.0)
        self._p5Srcs[2].gain = self.testGain * (1.0 - p)
        self._p5Srcs[3].gain = self.testGain * p
        if p >= 1.0 then
            self._p5Srcs[2].gain = 0  -- 静默, 不Stop!
            print("[DIAG] TG: E4 gain=0 (silent). >> Pop? <<")
            self.step = 6
            self.timer = 0
        end
    elseif self.step == 6 and self.timer >= 1.5 then
        -- 清理: 全部设gain=0, 不调Stop, 删除Node(Node删除会自动清理)
        for i = 1, 3 do
            self._p5Srcs[i].gain = 0
            self._p5Nodes[i]:Remove()
        end
        self._p5Nodes = nil
        self._p5Srcs = nil
        print("[DIAG] TG: Done. >> Compare with S: any difference? <<")
        self.activeTest = nil
    end
end

-- TEST H: 快速重触发但不调 Stop — gain=0 后直接 Play覆盖
-- 对比F: F用独立Node+Stop淡出, 前几次有爆音
-- 对比T8: T8用同源Stop+Play, 每次都爆
-- 目的: 在同一音源上 gain=0 + 直接Play(newSound) 不调Stop
function AudioDiag:run_TH_retrigger_no_stop(dt)
    if self.step == 0 then
        -- 创建独立Node (只1个, 复用)
        self._p5hNode = self.scene:CreateChild("P5HNode")
        self._p5hSrc = self._p5hNode:CreateComponent("SoundSource")
        self._p5hSrc.gain = self.testGain
        self._p5hSrc:Play(self.sounds[1])  -- C4
        self.retriggerTimer = 0
        self.retriggerCount = 0
        print("[DIAG] TH: 重触发C4 每200ms, 不调Stop, gain=0后直接Play覆盖")
        self.step = 1
    elseif self.step == 1 then
        self.retriggerTimer = self.retriggerTimer + dt
        if self.retriggerTimer >= 0.2 then
            self.retriggerTimer = 0
            self.retriggerCount = self.retriggerCount + 1
            -- 关键: 不调Stop! 先gain=0, 再直接Play新音
            self._p5hSrc.gain = 0
            self._p5hSrc.gain = self.testGain
            self._p5hSrc:Play(self.sounds[1])  -- 直接覆盖播放
            print(string.format("[DIAG] TH: Retrigger #%d (no Stop, direct Play)", self.retriggerCount))
            if self.retriggerCount >= 10 then
                print("[DIAG] TH: Done. >> Pops? Compare with T8 (Stop版) <<")
                self.step = 2
                self.timer = 0
            end
        end
    elseif self.step == 2 and self.timer >= 1.0 then
        self._p5hSrc.gain = 0
        self._p5hNode:Remove()
        self._p5hNode = nil
        self._p5hSrc = nil
        self.activeTest = nil
    end
end

-- TEST J: 模拟 MidiPlayer 工作流 — 连续4个音符, 无Stop
-- 模拟: noteOn→淡入→播放→noteOff→淡出到gain=0→不Stop→下个noteOn复用
-- 这是最终解决方案的完整模拟
function AudioDiag:run_TJ_midi_sim_no_stop(dt)
    local FADE_IN_FRAMES = 3
    local FADE_OUT_FACTOR = 0.85
    if self.step == 0 then
        -- 创建4个独立Node+Source (模拟音源池)
        self._p5jNodes = {}
        self._p5jSrcs = {}
        self._p5jPool = {}  -- 可用池
        for i = 1, 4 do
            local node = self.scene:CreateChild("P5JNode" .. i)
            local src = node:CreateComponent("SoundSource")
            src.gain = 0
            self._p5jNodes[i] = node
            self._p5jSrcs[i] = src
            self._p5jPool[i] = src
        end
        self._p5jActive = {}     -- { src=, targetGain=, fadeIn=, note= }
        self._p5jReleasing = {}  -- { src=, gain= }
        self._p5jNoteSeq = {1, 2, 3, 4, 3, 2, 1, 2, 3, 4}  -- 音符序列
        self._p5jSeqIdx = 0
        self._p5jNoteInterval = 0.25  -- 每250ms一个音符
        print("[DIAG] TJ: 模拟MidiPlayer工作流 — 10个连续音符, 完全不调Stop()")
        print("[DIAG] TJ: 序列: C4 E4 G4 C5 G4 E4 C4 E4 G4 C5")
        self.step = 1
        self.timer = 0
    elseif self.step == 1 then
        -- 处理淡出中的音源 (gain *= factor, 但不Stop)
        for i = #self._p5jReleasing, 1, -1 do
            local info = self._p5jReleasing[i]
            info.gain = info.gain * FADE_OUT_FACTOR
            if info.gain <= 0.001 then
                info.src.gain = 0
                -- 不Stop! 放回池
                self._p5jPool[#self._p5jPool + 1] = info.src
                table.remove(self._p5jReleasing, i)
            else
                info.src.gain = info.gain
            end
        end
        -- 处理淡入中的音源
        for i = #self._p5jActive, 1, -1 do
            local info = self._p5jActive[i]
            if info.fadeIn then
                info.fadeIn = info.fadeIn - 1
                if info.fadeIn <= 0 then
                    info.src.gain = info.targetGain
                    info.fadeIn = nil
                else
                    local progress = 1.0 - (info.fadeIn / FADE_IN_FRAMES)
                    info.src.gain = info.targetGain * progress
                end
            end
        end
        -- 定时触发下一个音符
        if self.timer >= self._p5jNoteInterval then
            self.timer = 0
            self._p5jSeqIdx = self._p5jSeqIdx + 1
            if self._p5jSeqIdx > #self._p5jNoteSeq then
                print("[DIAG] TJ: 序列播完, 等待淡出完成...")
                self.step = 2
                self.timer = 0
                return
            end
            local noteIdx = self._p5jNoteSeq[self._p5jSeqIdx]
            -- 先把活跃的同音符移入释放列表
            for j = #self._p5jActive, 1, -1 do
                local info = self._p5jActive[j]
                if info.note == noteIdx then
                    self._p5jReleasing[#self._p5jReleasing + 1] = {
                        src = info.src,
                        gain = info.src.gain,
                    }
                    table.remove(self._p5jActive, j)
                end
            end
            -- 从池取音源
            if #self._p5jPool > 0 then
                local src = table.remove(self._p5jPool)
                local targetGain = self.testGain
                -- 关键: gain=0 → Play → 淡入, 不调Stop!
                src.gain = 0
                src:Play(self.sounds[noteIdx])
                self._p5jActive[#self._p5jActive + 1] = {
                    src = src,
                    targetGain = targetGain,
                    fadeIn = FADE_IN_FRAMES,
                    note = noteIdx,
                }
                local noteNames = {"C4", "E4", "G4", "C5"}
                print(string.format("[DIAG] TJ: Note %d/%d: %s (pool:%d active:%d releasing:%d)",
                    self._p5jSeqIdx, #self._p5jNoteSeq,
                    noteNames[noteIdx],
                    #self._p5jPool, #self._p5jActive, #self._p5jReleasing))
            else
                print("[DIAG] TJ: Pool empty! (releasing still fading)")
            end
        end
    elseif self.step == 2 then
        -- 等待所有释放完成
        for i = #self._p5jReleasing, 1, -1 do
            local info = self._p5jReleasing[i]
            info.gain = info.gain * FADE_OUT_FACTOR
            if info.gain <= 0.001 then
                info.src.gain = 0
                table.remove(self._p5jReleasing, i)
            else
                info.src.gain = info.gain
            end
        end
        if #self._p5jReleasing == 0 and self.timer >= 0.5 then
            -- 全部完成, 清理
            for i = 1, #self._p5jNodes do
                self._p5jSrcs[i].gain = 0
                self._p5jNodes[i]:Remove()
            end
            self._p5jNodes = nil
            self._p5jSrcs = nil
            self._p5jPool = nil
            self._p5jActive = nil
            self._p5jReleasing = nil
            print("[DIAG] TJ: Done! >> 整个过程有爆音吗? 对比之前Phase2/3/4的结果 <<")
            self.activeTest = nil
        end
    end
end

-- TEST K: A/B 对比 — 相同操作, 一边调Stop一边不调
-- 播放两轮相同的交叉淡化:
--   第1轮: 有Stop (和S一样)
--   间隔2秒
--   第2轮: 无Stop (和G一样)
-- 目的: 直接对比听感
function AudioDiag:run_TK_ab_compare(dt)
    local FADE_FRAMES = 5
    if self.step == 0 then
        self._p5kNodes = {}
        self._p5kSrcs = {}
        for i = 1, 4 do
            local node = self.scene:CreateChild("P5KNode" .. i)
            local src = node:CreateComponent("SoundSource")
            src.gain = 0
            self._p5kNodes[i] = node
            self._p5kSrcs[i] = src
        end
        print("[DIAG] TK: ====== A/B 对比测试 ======")
        print("[DIAG] TK: 第1轮: C4→E4 交叉淡化 [有Stop]")
        -- 第1轮: 有Stop — 使用 src1, src2
        self._p5kSrcs[1]:Play(self.sounds[1])  -- C4
        self.step = 1
        self.frameCount = 0
    elseif self.step == 1 then
        -- 淡入C4
        local p = math.min(self.frameCount / FADE_FRAMES, 1.0)
        self._p5kSrcs[1].gain = p * self.testGain
        if p >= 1.0 then
            self.step = 2
            self.timer = 0
        end
    elseif self.step == 2 and self.timer >= 0.5 then
        -- 交叉淡化 C4→E4 (有Stop)
        self._p5kSrcs[2]:Play(self.sounds[2])
        print("[DIAG] TK: [有Stop] Crossfade C4→E4")
        self.step = 3
        self.frameCount = 0
    elseif self.step == 3 then
        local p = math.min(self.frameCount / FADE_FRAMES, 1.0)
        self._p5kSrcs[1].gain = self.testGain * (1.0 - p)
        self._p5kSrcs[2].gain = self.testGain * p
        if p >= 1.0 then
            self._p5kSrcs[1].gain = 0
            self.step = 4
            self.frameCount = 0
        end
    elseif self.step == 4 and self.frameCount >= 2 then
        -- 有Stop版: 调Stop!
        self._p5kSrcs[1]:Stop()
        print("[DIAG] TK: [有Stop] C4 stopped! >> 听到爆音了吗? <<")
        self.step = 5
        self.timer = 0
    elseif self.step == 5 and self.timer >= 0.5 then
        -- 停掉E4
        self._p5kSrcs[2].gain = 0
        self.step = 6
        self.frameCount = 0
    elseif self.step == 6 and self.frameCount >= 2 then
        self._p5kSrcs[2]:Stop()
        print("[DIAG] TK: --- 间隔2秒 ---")
        self.step = 7
        self.timer = 0
    elseif self.step == 7 and self.timer >= 2.0 then
        -- 第2轮: 无Stop — 使用 src3, src4
        print("[DIAG] TK: 第2轮: C4→E4 交叉淡化 [无Stop]")
        self._p5kSrcs[3]:Play(self.sounds[1])  -- C4
        self.step = 8
        self.frameCount = 0
    elseif self.step == 8 then
        -- 淡入C4
        local p = math.min(self.frameCount / FADE_FRAMES, 1.0)
        self._p5kSrcs[3].gain = p * self.testGain
        if p >= 1.0 then
            self.step = 9
            self.timer = 0
        end
    elseif self.step == 9 and self.timer >= 0.5 then
        -- 交叉淡化 C4→E4 (无Stop)
        self._p5kSrcs[4]:Play(self.sounds[2])
        print("[DIAG] TK: [无Stop] Crossfade C4→E4")
        self.step = 10
        self.frameCount = 0
    elseif self.step == 10 then
        local p = math.min(self.frameCount / FADE_FRAMES, 1.0)
        self._p5kSrcs[3].gain = self.testGain * (1.0 - p)
        self._p5kSrcs[4].gain = self.testGain * p
        if p >= 1.0 then
            self._p5kSrcs[3].gain = 0  -- 不Stop! 静默播放
            print("[DIAG] TK: [无Stop] C4 gain=0, 不Stop! >> 有爆音吗? <<")
            self.step = 11
            self.timer = 0
        end
    elseif self.step == 11 and self.timer >= 1.5 then
        -- 清理
        for i = 1, 4 do
            self._p5kSrcs[i].gain = 0
            self._p5kNodes[i]:Remove()
        end
        self._p5kNodes = nil
        self._p5kSrcs = nil
        print("[DIAG] TK: ====== A/B 对比结束 ======")
        print("[DIAG] TK: >> 第1轮(有Stop) vs 第2轮(无Stop) 哪个有爆音? <<")
        self.activeTest = nil
    end
end

------------------------------------------------------------
-- Phase 6: 改进方案 — 全新Node + 长淡出 + 绝不复用活跃源 (L/M/N/O)
--
-- Phase 5 发现:
--   1. Play() 在已播放音源上 = 爆音 (缓冲区重置)
--   2. 5帧淡出太快, 增益步长太大
-- Phase 6 原则:
--   1. 每个音符 = 全新 Node + 全新 SoundSource
--   2. 淡出 15 帧 (~250ms@60fps), 步长更小
--   3. 绝不在正在播放的音源上调 Play() 或 Stop()
--   4. 淡出到 gain=0 后, 要么不管(L) 要么 Remove Node(M)
------------------------------------------------------------

-- TEST L: 交叉淡化 + 15帧慢淡 + 全新Node + 不Remove
-- 淡出后的Node保持存在(gain=0静默播放直到自然结束)
-- 目的: 排除 Node 删除造成的爆音
function AudioDiag:run_TL_long_fade_no_remove(dt)
    local FADE_FRAMES = 15
    if self.step == 0 then
        self._p6Nodes = {}
        self._p6Srcs = {}
        for i = 1, 3 do
            local node = self.scene:CreateChild("P6LNode" .. i)
            local src = node:CreateComponent("SoundSource")
            src.gain = 0
            self._p6Nodes[i] = node
            self._p6Srcs[i] = src
        end
        self._p6Srcs[1]:Play(self.sounds[1])  -- C4
        print("[DIAG] TL: 交叉淡化 15帧慢淡, 全新Node, 不Remove")
        print("[DIAG] TL: C4→E4→G4, 每个音符独立Node, 旧的gain=0后保持不动")
        self.step = 1
        self.frameCount = 0
    elseif self.step == 1 then
        -- 淡入 C4 (15帧)
        local p = math.min(self.frameCount / FADE_FRAMES, 1.0)
        self._p6Srcs[1].gain = p * self.testGain
        if p >= 1.0 then
            self.step = 2
            self.timer = 0
        end
    elseif self.step == 2 and self.timer >= 0.6 then
        -- 交叉: C4淡出15帧, E4淡入15帧
        self._p6Srcs[2]:Play(self.sounds[2])
        print("[DIAG] TL: >>> Crossfade C4→E4 (15 frames, ~250ms) <<<")
        self.step = 3
        self.frameCount = 0
    elseif self.step == 3 then
        local p = math.min(self.frameCount / FADE_FRAMES, 1.0)
        self._p6Srcs[1].gain = self.testGain * (1.0 - p)
        self._p6Srcs[2].gain = self.testGain * p
        if p >= 1.0 then
            self._p6Srcs[1].gain = 0  -- 静默, 不Stop, 不Remove
            print("[DIAG] TL: C4→gain=0 (alive, silent). >> Pop? <<")
            self.step = 4
            self.timer = 0
        end
    elseif self.step == 4 and self.timer >= 0.6 then
        -- 交叉: E4淡出, G4淡入
        self._p6Srcs[3]:Play(self.sounds[3])
        print("[DIAG] TL: >>> Crossfade E4→G4 (15 frames) <<<")
        self.step = 5
        self.frameCount = 0
    elseif self.step == 5 then
        local p = math.min(self.frameCount / FADE_FRAMES, 1.0)
        self._p6Srcs[2].gain = self.testGain * (1.0 - p)
        self._p6Srcs[3].gain = self.testGain * p
        if p >= 1.0 then
            self._p6Srcs[2].gain = 0
            print("[DIAG] TL: E4→gain=0 (alive, silent). >> Pop? <<")
            self.step = 6
            self.timer = 0
        end
    elseif self.step == 6 and self.timer >= 2.0 then
        -- 等G4自然结束后清理
        print("[DIAG] TL: 等待所有音源自然结束...")
        self.step = 7
    elseif self.step == 7 then
        local allDone = true
        for i = 1, 3 do
            if self._p6Srcs[i]:IsPlaying() then allDone = false end
        end
        if allDone then
            for i = 1, 3 do self._p6Nodes[i]:Remove() end
            self._p6Nodes = nil
            self._p6Srcs = nil
            print("[DIAG] TL: 全部自然结束, 已清理. >> 对比G(5帧)有改善吗? <<")
            self.activeTest = nil
        end
    end
end

-- TEST M: 交叉淡化 + 15帧慢淡 + 全新Node + gain=0后Remove
-- 和L完全一样但淡出完成后立即Remove Node
-- 目的: 对比L, 看Remove本身是否造成爆音
function AudioDiag:run_TM_long_fade_with_remove(dt)
    local FADE_FRAMES = 15
    if self.step == 0 then
        self._p6mNodes = {}
        self._p6mSrcs = {}
        for i = 1, 3 do
            local node = self.scene:CreateChild("P6MNode" .. i)
            local src = node:CreateComponent("SoundSource")
            src.gain = 0
            self._p6mNodes[i] = node
            self._p6mSrcs[i] = src
        end
        self._p6mSrcs[1]:Play(self.sounds[1])
        print("[DIAG] TM: 同L但gain=0后立即Remove Node")
        self.step = 1
        self.frameCount = 0
    elseif self.step == 1 then
        local p = math.min(self.frameCount / FADE_FRAMES, 1.0)
        self._p6mSrcs[1].gain = p * self.testGain
        if p >= 1.0 then
            self.step = 2
            self.timer = 0
        end
    elseif self.step == 2 and self.timer >= 0.6 then
        self._p6mSrcs[2]:Play(self.sounds[2])
        print("[DIAG] TM: >>> Crossfade C4→E4 (15 frames) <<<")
        self.step = 3
        self.frameCount = 0
    elseif self.step == 3 then
        local p = math.min(self.frameCount / FADE_FRAMES, 1.0)
        self._p6mSrcs[1].gain = self.testGain * (1.0 - p)
        self._p6mSrcs[2].gain = self.testGain * p
        if p >= 1.0 then
            self._p6mSrcs[1].gain = 0
            -- 关键区别: 立即Remove!
            self._p6mNodes[1]:Remove()
            self._p6mNodes[1] = nil
            self._p6mSrcs[1] = nil
            print("[DIAG] TM: C4 Node removed! >> Pop at remove? Compare with L <<")
            self.step = 4
            self.timer = 0
        end
    elseif self.step == 4 and self.timer >= 0.6 then
        self._p6mSrcs[3]:Play(self.sounds[3])
        print("[DIAG] TM: >>> Crossfade E4→G4 (15 frames) <<<")
        self.step = 5
        self.frameCount = 0
    elseif self.step == 5 then
        local p = math.min(self.frameCount / FADE_FRAMES, 1.0)
        self._p6mSrcs[2].gain = self.testGain * (1.0 - p)
        self._p6mSrcs[3].gain = self.testGain * p
        if p >= 1.0 then
            self._p6mSrcs[2].gain = 0
            self._p6mNodes[2]:Remove()
            self._p6mNodes[2] = nil
            self._p6mSrcs[2] = nil
            print("[DIAG] TM: E4 Node removed! >> Pop? <<")
            self.step = 6
            self.timer = 0
        end
    elseif self.step == 6 and self.timer >= 2.0 then
        -- 清理最后一个
        if self._p6mNodes[3] then
            self._p6mSrcs[3].gain = 0
            self._p6mNodes[3]:Remove()
        end
        self._p6mNodes = nil
        self._p6mSrcs = nil
        print("[DIAG] TM: Done. >> L vs M: Remove是否导致额外爆音? <<")
        self.activeTest = nil
    end
end

-- TEST N: 重触发 — 每次全新Node+Source, 旧的15帧淡出后自然结束
-- 和T8对比: T8同源Stop+Play每次爆, H同源Play覆盖也爆
-- 目的: 全新Node + 慢淡出能否彻底消除重触发爆音
function AudioDiag:run_TN_retrigger_fresh_nodes(dt)
    local FADE_FRAMES = 15
    if self.step == 0 then
        self._p6nNodes = {}  -- 所有创建的节点 (用于最终清理)
        self._p6nFading = {} -- 正在淡出的: { node, src, gain, frame }
        -- 第一个音符
        local node = self.scene:CreateChild("P6NNode1")
        local src = node:CreateComponent("SoundSource")
        src.gain = self.testGain
        src:Play(self.sounds[1])
        self._p6nNodes[1] = node
        self._p6nCurrentNode = node
        self._p6nCurrentSrc = src
        self._p6nIdx = 1
        self.retriggerTimer = 0
        self.retriggerCount = 0
        print("[DIAG] TN: 重触发C4 每300ms, 每次全新Node, 旧的15帧慢淡出")
        self.step = 1
    elseif self.step == 1 then
        -- 处理淡出中的旧音源
        for i = #self._p6nFading, 1, -1 do
            local info = self._p6nFading[i]
            info.frame = info.frame + 1
            local p = math.min(info.frame / FADE_FRAMES, 1.0)
            info.src.gain = info.startGain * (1.0 - p)
            if p >= 1.0 then
                info.src.gain = 0
                -- 不Stop, 不Remove, 让它自然结束
                table.remove(self._p6nFading, i)
            end
        end

        self.retriggerTimer = self.retriggerTimer + dt
        if self.retriggerTimer >= 0.3 then
            self.retriggerTimer = 0
            self.retriggerCount = self.retriggerCount + 1

            -- 当前音源放入淡出列表
            self._p6nFading[#self._p6nFading + 1] = {
                node = self._p6nCurrentNode,
                src = self._p6nCurrentSrc,
                startGain = self._p6nCurrentSrc.gain,
                frame = 0,
            }

            -- 全新 Node + Source
            self._p6nIdx = self._p6nIdx + 1
            local node = self.scene:CreateChild("P6NNode" .. self._p6nIdx)
            local src = node:CreateComponent("SoundSource")
            src.gain = self.testGain
            src:Play(self.sounds[1])  -- C4
            self._p6nNodes[self._p6nIdx] = node
            self._p6nCurrentNode = node
            self._p6nCurrentSrc = src

            print(string.format("[DIAG] TN: Retrigger #%d (fresh node, fading:%d)",
                self.retriggerCount, #self._p6nFading))

            if self.retriggerCount >= 8 then
                print("[DIAG] TN: Done triggering. Waiting for fade-outs...")
                self.step = 2
                self.timer = 0
            end
        end
    elseif self.step == 2 then
        -- 继续处理淡出
        for i = #self._p6nFading, 1, -1 do
            local info = self._p6nFading[i]
            info.frame = info.frame + 1
            local p = math.min(info.frame / FADE_FRAMES, 1.0)
            info.src.gain = info.startGain * (1.0 - p)
            if p >= 1.0 then
                info.src.gain = 0
                table.remove(self._p6nFading, i)
            end
        end
        if self.timer >= 3.0 then
            -- 全部清理 (等足够久让采样自然结束)
            for _, node in ipairs(self._p6nNodes) do
                node:Remove()
            end
            self._p6nNodes = nil
            self._p6nFading = nil
            self._p6nCurrentNode = nil
            self._p6nCurrentSrc = nil
            print("[DIAG] TN: Cleaned up. >> Pops? Compare T8(Stop) and H(Play覆盖) <<")
            self.activeTest = nil
        end
    end
end

-- TEST O: 完整 MidiPlayer 模拟 (最终方案)
-- 规则:
--   1. 每个 noteOn = 全新 Node + Source (gain=0→Play→15帧淡入)
--   2. noteOff / 同音重触发 = 旧源 15帧淡出→gain=0→保持不动
--   3. gain=0 的源等自然播放结束后, Remove Node 回收
--   4. 绝不调 Stop(), 绝不在活跃源上调 Play()
function AudioDiag:run_TO_midi_sim_final(dt)
    local FADE_IN_FRAMES = 3
    local FADE_OUT_FRAMES = 15
    if self.step == 0 then
        self._p6oActive = {}     -- { node, src, targetGain, fadeInFrame, note }
        self._p6oReleasing = {}  -- { node, src, startGain, fadeFrame }
        self._p6oSilent = {}     -- { node, src } gain=0, 等自然结束后Remove
        self._p6oNoteSeq = {1, 2, 3, 4, 3, 2, 1, 2, 3, 4, 1, 3, 2, 4, 1, 2}  -- 16个音符
        self._p6oSeqIdx = 0
        self._p6oInterval = 0.2  -- 每200ms一个音符 (模拟快速MIDI)
        self._p6oNodeCount = 0
        print("[DIAG] TO: === 最终方案完整模拟 ===")
        print("[DIAG] TO: 16个音符, 200ms间隔, 全新Node, 15帧淡出, 无Stop")
        print("[DIAG] TO: C4 E4 G4 C5 G4 E4 C4 E4 G4 C5 C4 G4 E4 C5 C4 E4")
        self.step = 1
        self.timer = 0
    elseif self.step == 1 then
        -- 处理淡入中的音源
        for i = #self._p6oActive, 1, -1 do
            local info = self._p6oActive[i]
            if info.fadeInFrame then
                info.fadeInFrame = info.fadeInFrame + 1
                local p = math.min(info.fadeInFrame / FADE_IN_FRAMES, 1.0)
                info.src.gain = info.targetGain * p
                if p >= 1.0 then
                    info.fadeInFrame = nil  -- 淡入完成
                end
            end
        end
        -- 处理淡出中的音源
        for i = #self._p6oReleasing, 1, -1 do
            local info = self._p6oReleasing[i]
            info.fadeFrame = info.fadeFrame + 1
            local p = math.min(info.fadeFrame / FADE_OUT_FRAMES, 1.0)
            info.src.gain = info.startGain * (1.0 - p)
            if p >= 1.0 then
                info.src.gain = 0
                -- 移入静默列表, 等自然结束
                self._p6oSilent[#self._p6oSilent + 1] = {
                    node = info.node,
                    src = info.src,
                }
                table.remove(self._p6oReleasing, i)
            end
        end
        -- 清理已自然结束的静默音源
        for i = #self._p6oSilent, 1, -1 do
            local info = self._p6oSilent[i]
            if not info.src:IsPlaying() then
                info.node:Remove()
                table.remove(self._p6oSilent, i)
            end
        end

        -- 定时触发下一个音符
        if self.timer >= self._p6oInterval then
            self.timer = 0
            self._p6oSeqIdx = self._p6oSeqIdx + 1
            if self._p6oSeqIdx > #self._p6oNoteSeq then
                print(string.format("[DIAG] TO: 序列播完! 总创建节点:%d, 等待清理...",
                    self._p6oNodeCount))
                self.step = 2
                self.timer = 0
                return
            end
            local noteIdx = self._p6oNoteSeq[self._p6oSeqIdx]
            -- 同音符的活跃源移入释放列表
            for j = #self._p6oActive, 1, -1 do
                local info = self._p6oActive[j]
                if info.note == noteIdx then
                    self._p6oReleasing[#self._p6oReleasing + 1] = {
                        node = info.node,
                        src = info.src,
                        startGain = info.src.gain,
                        fadeFrame = 0,
                    }
                    table.remove(self._p6oActive, j)
                end
            end
            -- 全新 Node + Source
            self._p6oNodeCount = self._p6oNodeCount + 1
            local node = self.scene:CreateChild("P6ONode" .. self._p6oNodeCount)
            local src = node:CreateComponent("SoundSource")
            local targetGain = self.testGain
            src.gain = 0
            src:Play(self.sounds[noteIdx])
            self._p6oActive[#self._p6oActive + 1] = {
                node = node,
                src = src,
                targetGain = targetGain,
                fadeInFrame = 0,
                note = noteIdx,
            }
            local noteNames = {"C4", "E4", "G4", "C5"}
            print(string.format("[DIAG] TO: %d/%d %s (active:%d releasing:%d silent:%d nodes:%d)",
                self._p6oSeqIdx, #self._p6oNoteSeq,
                noteNames[noteIdx],
                #self._p6oActive, #self._p6oReleasing,
                #self._p6oSilent, self._p6oNodeCount))
        end
    elseif self.step == 2 then
        -- 等待所有音源结束
        -- 继续处理淡出
        for i = #self._p6oReleasing, 1, -1 do
            local info = self._p6oReleasing[i]
            info.fadeFrame = info.fadeFrame + 1
            local p = math.min(info.fadeFrame / FADE_OUT_FRAMES, 1.0)
            info.src.gain = info.startGain * (1.0 - p)
            if p >= 1.0 then
                info.src.gain = 0
                self._p6oSilent[#self._p6oSilent + 1] = {
                    node = info.node, src = info.src,
                }
                table.remove(self._p6oReleasing, i)
            end
        end
        -- 活跃的也移入静默
        for i = #self._p6oActive, 1, -1 do
            local info = self._p6oActive[i]
            info.src.gain = info.src.gain * 0.9
            if info.src.gain < 0.001 then
                info.src.gain = 0
                self._p6oSilent[#self._p6oSilent + 1] = {
                    node = info.node, src = info.src,
                }
                table.remove(self._p6oActive, i)
            end
        end
        -- 清理自然结束的
        for i = #self._p6oSilent, 1, -1 do
            local info = self._p6oSilent[i]
            if not info.src:IsPlaying() then
                info.node:Remove()
                table.remove(self._p6oSilent, i)
            end
        end
        -- 超时强制清理 (采样最长也就几秒)
        if self.timer >= 8.0 then
            for _, info in ipairs(self._p6oSilent) do
                info.src.gain = 0
                info.node:Remove()
            end
            for _, info in ipairs(self._p6oActive) do
                info.src.gain = 0
                info.node:Remove()
            end
            for _, info in ipairs(self._p6oReleasing) do
                info.src.gain = 0
                info.node:Remove()
            end
            self._p6oActive = nil
            self._p6oReleasing = nil
            self._p6oSilent = nil
            print("[DIAG] TO: === 测试完成 ===")
            print("[DIAG] TO: >> 整个过程有爆音吗? 这是最终方案! <<")
            self.activeTest = nil
        elseif #self._p6oSilent == 0 and #self._p6oActive == 0 and #self._p6oReleasing == 0 then
            self._p6oActive = nil
            self._p6oReleasing = nil
            self._p6oSilent = nil
            print("[DIAG] TO: === 全部自然结束, 测试完成 ===")
            print("[DIAG] TO: >> 整个过程有爆音吗? 这是最终方案! <<")
            self.activeTest = nil
        end
    end
end

------------------------------------------------------------
-- 销毁
------------------------------------------------------------
function AudioDiag:destroy()
    self:stopAll()
    if self.audioNode then
        self.audioNode:Remove()
        self.audioNode = nil
    end
    -- 清理Phase4临时节点
    if self._testNodes then
        for _, n in ipairs(self._testNodes) do n:Remove() end
    end
    if self._retrigNodes then
        for _, n in ipairs(self._retrigNodes) do n:Remove() end
    end
    -- 清理Phase5临时节点
    if self._p5Nodes then
        for _, n in ipairs(self._p5Nodes) do n:Remove() end
    end
    if self._p5hNode then self._p5hNode:Remove() end
    if self._p5jNodes then
        for _, n in ipairs(self._p5jNodes) do n:Remove() end
    end
    if self._p5kNodes then
        for _, n in ipairs(self._p5kNodes) do n:Remove() end
    end
    -- 清理Phase6临时节点
    if self._p6Nodes then
        for _, n in ipairs(self._p6Nodes) do if n then n:Remove() end end
    end
    if self._p6mNodes then
        for _, n in ipairs(self._p6mNodes) do if n then n:Remove() end end
    end
    if self._p6nNodes then
        for _, n in ipairs(self._p6nNodes) do n:Remove() end
    end
    local function cleanList(list)
        if not list then return end
        for _, info in ipairs(list) do
            if info.node then info.node:Remove() end
        end
    end
    cleanList(self._p6oActive)
    cleanList(self._p6oReleasing)
    cleanList(self._p6oSilent)
end

return AudioDiag
