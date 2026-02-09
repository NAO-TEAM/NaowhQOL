local addonName, ns = ...
local L = ns.L
local W = ns.Widgets

local alertFrame = CreateFrame("Frame", "NaowhQOL_CombatAlertDisplay", UIParent, "BackdropTemplate")
alertFrame:SetSize(300, 80)
alertFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
alertFrame:Hide()

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
        local soundID = db[prefix .. "SoundID"]
        if soundID then
            PlaySound(soundID, "Master")
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
        txtColor.r, txtColor.g, txtColor.b = db.enterR or 0, db.enterG or 1, db.enterB or 0
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

-- Fade: fadingIn (0.4s) -> waiting (1.7s) -> fadingOut (0.4s) = 2.5s total
local fadeFrame = CreateFrame("Frame")
fadeFrame:Hide()

local fadeElapsed = 0
local fadeState = "idle"
local FADE_IN  = 0.4
local VISIBLE  = 1.7
local FADE_OUT = 0.4

local function ShowAlert(text, r, g, b)
    local db = NaowhQOL.combatAlert
    if not db or not db.enabled then return end
    if db.unlock then return end

    alertFrame:ClearAllPoints()
    local point = db.point or "CENTER"
    alertFrame:SetPoint(point, UIParent, point, db.x or 0, db.y or 200)
    alertFrame:SetSize(db.width or 300, db.height or 80)

    -- Set text/color before scaling
    alertText:SetText(text)
    txtColor.r, txtColor.g, txtColor.b = r, g, b
    ApplyColor()

    alertFrame:SetAlpha(0)
    alertFrame:Show()
    alertFrame:UpdateTextSize()

    fadeElapsed = 0
    fadeState = "fadingIn"

    fadeFrame:SetScript("OnUpdate", ns.PerfMonitor:Wrap("Combat Alert", function(self, dt)
        fadeElapsed = fadeElapsed + dt

        if fadeState == "fadingIn" then
            local a = fadeElapsed / FADE_IN
            if a >= 1 then
                a = 1
                fadeState = "waiting"
                fadeElapsed = 0
            end
            alertFrame:SetAlpha(a)

        elseif fadeState == "waiting" then
            if fadeElapsed >= VISIBLE then
                fadeState = "fadingOut"
                fadeElapsed = 0
            end

        elseif fadeState == "fadingOut" then
            local a = 1 - (fadeElapsed / FADE_OUT)
            if a <= 0 then
                alertFrame:Hide()
                fadeState = "idle"
                self:SetScript("OnUpdate", nil)
            else
                alertFrame:SetAlpha(a)
            end
        end
    end))
    fadeFrame:Show()
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
            ShowAlert(db.enterText or "++ Combat", db.enterR or 0, db.enterG or 1, db.enterB or 0)
            PlayCombatAudio("enter")
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        if db.enabled then
            ShowAlert(db.leaveText or "-- Combat", db.leaveR or 1, db.leaveG or 0, db.leaveB or 0)
            PlayCombatAudio("leave")
        end
    end
end)

ns.CombatAlertDisplay = alertFrame
