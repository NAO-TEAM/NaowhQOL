local addonName, ns = ...
local L = ns.L
local W = ns.Widgets

local alertFrame = CreateFrame("Frame", "NaowhQOL_CombatAlertDisplay", UIParent, "BackdropTemplate")
alertFrame:SetSize(300, 80)
alertFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
alertFrame:Hide()

-- Animation groups for fade in -> hold -> fade out
local fadeInAnim = alertFrame:CreateAnimationGroup()
local fadeIn = fadeInAnim:CreateAnimation("Alpha")
fadeIn:SetFromAlpha(0)
fadeIn:SetToAlpha(1)
fadeIn:SetDuration(0.4)

local holdAnim = alertFrame:CreateAnimationGroup()
local hold = holdAnim:CreateAnimation("Alpha")
hold:SetFromAlpha(1)
hold:SetToAlpha(1)
hold:SetDuration(1.7)

local fadeOutAnim = alertFrame:CreateAnimationGroup()
local fadeOut = fadeOutAnim:CreateAnimation("Alpha")
fadeOut:SetFromAlpha(1)
fadeOut:SetToAlpha(0)
fadeOut:SetDuration(0.4)

fadeInAnim:SetScript("OnFinished", function() holdAnim:Play() end)
holdAnim:SetScript("OnFinished", function() fadeOutAnim:Play() end)
fadeOutAnim:SetScript("OnFinished", function() alertFrame:Hide() end)

local alertText = alertFrame:CreateFontString(nil, "OVERLAY")
alertText:SetPoint("CENTER", alertFrame, "CENTER", 0, 0)
alertText:SetJustifyH("CENTER")
alertText:SetJustifyV("MIDDLE")
alertText:SetWordWrap(false)
alertText:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", 32, "OUTLINE")

-- shared text color
local txtColor = { r = 0, g = 1, b = 0 }

local function ApplyColor()
    alertText:SetTextColor(txtColor.r, txtColor.g, txtColor.b, 1)
end

local function PlayCombatAudio(prefix)
    local db = NaowhQOL.combatAlert
    if not db then return end

    local audioMode = db[prefix .. "AudioMode"] or "none"
    if audioMode == "none" then return end

    if audioMode == "sound" then
        local sound = db[prefix .. "Sound"]
        if sound then
            ns.SoundList.Play(sound)
        end
    elseif audioMode == "tts" then
        local ttsMessage = db[prefix .. "TtsMessage"]
        local ttsVolume = db[prefix .. "TtsVolume"] or 50
        local ttsRate = db[prefix .. "TtsRate"] or 0
        local ttsVoiceID = db[prefix .. "TtsVoiceID"] or 0
        if ttsMessage and ttsMessage ~= "" then
            C_VoiceChat.SpeakText(ttsVoiceID, ttsMessage, ttsRate, ttsVolume, true)
        end
    end
end

local resizeHandle

function alertFrame:UpdateTextSize()
    local db = NaowhQOL.combatAlert
    if not db then return end

    local frameWidth = alertFrame:GetWidth()
    local frameHeight = alertFrame:GetHeight()

    local db2 = NaowhQOL.combatAlert
    local currentText = alertText:GetText() or (db2 and db2.enterText or "++ Combat")
    local textLength = string.len(currentText)

    local fontSizeFromHeight = math.floor(frameHeight * 0.35)
    local usableWidth = frameWidth * 0.85
    local estimatedCharWidth = 0.55
    local maxFontSizeFromWidth = math.floor(usableWidth / (textLength * estimatedCharWidth))

    local scaledFontSize = math.min(fontSizeFromHeight, maxFontSizeFromWidth)
    scaledFontSize = math.max(10, math.min(72, scaledFontSize))

    local fontPath = db.font or "Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf"
    local success = alertText:SetFont(fontPath, scaledFontSize, "OUTLINE")
    if not success then
        alertText:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", scaledFontSize, "OUTLINE")
    end

    -- SetFont resets color to white
    ApplyColor()
end

function alertFrame:UpdateDisplay()
    local db = NaowhQOL.combatAlert
    if not db then return end

    if not db.enabled then
        alertFrame:SetBackdrop(nil)
        if resizeHandle then resizeHandle:Hide() end
        alertFrame:Hide()
        return
    end

    alertFrame:EnableMouse(db.unlock)
    if db.unlock then
        alertFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        alertFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        alertFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        if resizeHandle then resizeHandle:Show() end
        alertFrame:SetAlpha(1)

        -- Preview text for unlock mode
        alertText:SetText(db.enterText or "++ Combat")
        txtColor.r, txtColor.g, txtColor.b = W.GetEffectiveColor(db, "enterR", "enterG", "enterB", "enterUseClassColor")
        ApplyColor()
        alertFrame:Show()
    else
        alertFrame:SetBackdrop(nil)
        if resizeHandle then resizeHandle:Hide() end
        alertFrame:Hide()
    end

    if not alertFrame.initialized then
        alertFrame:ClearAllPoints()
        local point = db.point or "CENTER"
        local x = db.x or 0
        local y = db.y or 200
        alertFrame:SetPoint(point, UIParent, point, x, y)
        alertFrame:SetSize(db.width or 300, db.height or 80)
        alertFrame.initialized = true
    end

    self:UpdateTextSize()
end

local function ShowAlert(text, r, g, b)
    local db = NaowhQOL.combatAlert
    if not db or not db.enabled or db.unlock then return end

    alertFrame:ClearAllPoints()
    local point = db.point or "CENTER"
    alertFrame:SetPoint(point, UIParent, point, db.x or 0, db.y or 200)
    alertFrame:SetSize(db.width or 300, db.height or 80)

    alertText:SetText(text)
    txtColor.r, txtColor.g, txtColor.b = r, g, b
    ApplyColor()

    fadeInAnim:Stop()
    holdAnim:Stop()
    fadeOutAnim:Stop()

    alertFrame:SetAlpha(0)
    alertFrame:Show()
    alertFrame:UpdateTextSize()

    fadeInAnim:Play()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_REGEN_DISABLED")
loader:RegisterEvent("PLAYER_REGEN_ENABLED")

loader:SetScript("OnEvent", function(self, event)
    local db = NaowhQOL.combatAlert
    if not db then return end

    if event == "PLAYER_LOGIN" then
        db.width  = db.width  or 300
        db.height = db.height or 80
        db.point  = db.point  or "CENTER"
        db.x      = db.x      or 0
        db.y      = db.y      or 200

        W.MakeDraggable(alertFrame, { db = db })
        resizeHandle = W.CreateResizeHandle(alertFrame, {
            db = db,
            onResize = function() alertFrame:UpdateTextSize() end,
        })

        alertFrame.initialized = false
        alertFrame:UpdateDisplay()

        if db.enabled and db.unlock then
            alertFrame:Show()
        end

    elseif event == "PLAYER_REGEN_DISABLED" then
        if db.enabled then
            local eR, eG, eB = W.GetEffectiveColor(db, "enterR", "enterG", "enterB", "enterUseClassColor")
            ShowAlert(db.enterText or "++ Combat", eR, eG, eB)
            PlayCombatAudio("enter")
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        if db.enabled then
            local lR, lG, lB = W.GetEffectiveColor(db, "leaveR", "leaveG", "leaveB", "leaveUseClassColor")
            ShowAlert(db.leaveText or "-- Combat", lR, lG, lB)
            PlayCombatAudio("leave")
        end
    end
end)

ns.CombatAlertDisplay = alertFrame
