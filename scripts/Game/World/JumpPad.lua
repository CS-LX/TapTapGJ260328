-- ============================================================================
-- Game/World/JumpPad.lua — 峡谷跳跃板视觉与动效
-- ============================================================================

local Config = require "Game.Config"
local State  = require "Game.State"

local JumpPad = {}

--- 在峡谷触发点创建跳跃板视觉标识
function JumpPad.Create(canyon)
    local triggerZ = canyon.startZ - Config.CANYON_TRIGGER_OFFSET
    canyon.padNodes = {}
    canyon.padTriggerZ = triggerZ

    -- 共用材质：发光青色
    local glowMat = Material:new()
    glowMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    glowMat:SetShaderParameter("MatDiffColor", Variant(Color(0.0, 0.9, 1.0, 0.5)))
    glowMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.0, 1.0, 1.5)))
    glowMat:SetShaderParameter("Metallic", Variant(0.9))
    glowMat:SetShaderParameter("Roughness", Variant(0.1))

    -- 共用材质：箭头绿色
    local arrowMat = Material:new()
    arrowMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    arrowMat:SetShaderParameter("MatDiffColor", Variant(Color(0.1, 1.0, 0.4, 0.75)))
    arrowMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.0, 1.2, 0.4)))
    arrowMat:SetShaderParameter("Metallic", Variant(0.5))
    arrowMat:SetShaderParameter("Roughness", Variant(0.2))

    -- === 1. 发光主地板 ===
    local pad = State.scene:CreateChild("JumpPadFloor")
    pad.position = Vector3(0, 0.06, triggerZ)
    pad.scale = Vector3(Config.TRACK_WIDTH * 0.85, 0.08, 3.0)
    local padModel = pad:CreateComponent("StaticModel")
    padModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    padModel:SetMaterial(glowMat)
    padModel.castShadows = false
    table.insert(canyon.padNodes, { node = pad, kind = "floor" })

    -- === 2. 两条边缘光带 ===
    for side = -1, 1, 2 do
        local edge = State.scene:CreateChild("JumpPadEdge")
        edge.position = Vector3(side * Config.TRACK_WIDTH * 0.38, 0.08, triggerZ)
        edge.scale = Vector3(0.15, 0.1, 3.5)
        local em = edge:CreateComponent("StaticModel")
        em:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        em:SetMaterial(arrowMat)
        em.castShadows = false
        table.insert(canyon.padNodes, { node = edge, kind = "edge" })
    end

    -- === 3. 两侧光柱 ===
    for side = -1, 1, 2 do
        local pillar = State.scene:CreateChild("JumpPadPillar")
        pillar.position = Vector3(side * Config.TRACK_WIDTH * 0.42, 2.0, triggerZ)
        pillar.scale = Vector3(0.15, 4.0, 0.15)
        local pm = pillar:CreateComponent("StaticModel")
        pm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        pm:SetMaterial(glowMat)
        pm.castShadows = false
        table.insert(canyon.padNodes, { node = pillar, kind = "pillar", side = side })
    end

    -- === 4. 中央点光源 ===
    local lightNode = State.scene:CreateChild("JumpPadLight")
    lightNode.position = Vector3(0, 3.0, triggerZ)
    local light = lightNode:CreateComponent("Light")
    light.lightType = LIGHT_POINT
    light.range = 12.0
    light.color = Color(0.0, 0.9, 1.0)
    light.brightness = 3.0
    light.castShadows = false
    table.insert(canyon.padNodes, { node = lightNode, kind = "light" })

    -- === 5. 向上箭头（4 个人字形 chevron） ===
    for i = 1, 4 do
        local arrowNode = State.scene:CreateChild("JumpPadArrow")
        arrowNode.position = Vector3(0, 0.6 + (i - 1) * 1.1, triggerZ)

        local left = arrowNode:CreateChild("L")
        left.position = Vector3(-0.4, 0, 0)
        left.rotation = Quaternion(0, 0, -35)
        left.scale = Vector3(0.12, 0.9, 0.12)
        local lm = left:CreateComponent("StaticModel")
        lm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        lm:SetMaterial(arrowMat)
        lm.castShadows = false

        local right = arrowNode:CreateChild("R")
        right.position = Vector3(0.4, 0, 0)
        right.rotation = Quaternion(0, 0, 35)
        right.scale = Vector3(0.12, 0.9, 0.12)
        local rm = right:CreateComponent("StaticModel")
        rm:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        rm:SetMaterial(arrowMat)
        rm.castShadows = false

        table.insert(canyon.padNodes, { node = arrowNode, kind = "arrow", idx = i })
    end

    -- === 6. 上升粒子 ===
    for i = 1, 10 do
        local particle = State.scene:CreateChild("JumpPadParticle")
        local px = (math.random() - 0.5) * Config.TRACK_WIDTH * 0.7
        local py = math.random() * 4.0
        particle.position = Vector3(px, py, triggerZ + (math.random() - 0.5) * 2.0)
        local s = 0.06 + math.random() * 0.07
        particle.scale = Vector3(s, s, s)
        local pModel = particle:CreateComponent("StaticModel")
        pModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        pModel:SetMaterial(glowMat)
        pModel.castShadows = false
        table.insert(canyon.padNodes, {
            node = particle, kind = "particle",
            baseX = px,
            speed = 1.5 + math.random() * 2.5,
            phase = math.random() * 6.28,
            startScale = s,
        })
    end
end

--- 更新所有跳跃板的动效
function JumpPad.UpdateAll(dt)
    local elapsed = GetTime():GetElapsedTime()

    for _, canyon in ipairs(State.canyons) do
        if not canyon.padNodes then goto continue end
        local tz = canyon.padTriggerZ

        for _, pad in ipairs(canyon.padNodes) do
            if not pad.node then goto next end

            if pad.kind == "arrow" then
                local baseY = 0.6 + (pad.idx - 1) * 1.1
                local floatY = math.sin(elapsed * 3.0 + pad.idx * 0.9) * 0.35
                pad.node.position = Vector3(0, baseY + floatY, tz)

            elseif pad.kind == "light" then
                local light = pad.node:GetComponent("Light")
                if light then
                    light.brightness = 2.5 + math.sin(elapsed * 4.0) * 1.5
                end

            elseif pad.kind == "pillar" then
                local breathe = 1.0 + math.sin(elapsed * 2.5 + pad.side) * 0.15
                pad.node.scale = Vector3(0.15, 4.0 * breathe, 0.15)

            elseif pad.kind == "particle" then
                local pos = pad.node.position
                local y = pos.y + pad.speed * dt
                if y > 5.0 then y = 0.1 end
                local xOff = math.sin(elapsed * 2.0 + pad.phase) * 0.3
                pad.node.position = Vector3(pad.baseX + xOff, y, tz + math.sin(elapsed + pad.phase) * 0.4)
                local alpha = 1.0
                if y < 0.5 then alpha = y / 0.5
                elseif y > 4.0 then alpha = (5.0 - y) end
                local s = pad.startScale * (0.5 + alpha * 0.5)
                pad.node.scale = Vector3(s, s, s)

            elseif pad.kind == "floor" then
                local pulse = 1.0 + math.sin(elapsed * 3.5) * 0.06
                pad.node.scale = Vector3(Config.TRACK_WIDTH * 0.85 * pulse, 0.08, 3.0)
            end

            ::next::
        end
        ::continue::
    end
end

--- 清理跳跃板节点
function JumpPad.Remove(canyon)
    if not canyon.padNodes then return end
    for _, pad in ipairs(canyon.padNodes) do
        if pad.node then pad.node:Remove() end
    end
    canyon.padNodes = nil
end

return JumpPad
