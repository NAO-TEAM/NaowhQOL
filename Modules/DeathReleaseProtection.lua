local addonName, ns = ...
local L = ns.L

local REQUIRED_HOLD = 1.0

local blocker = nil
local timerLabel = nil
local pressStart = 0
local isReady = false

local function BuildBlocker(releaseBtn)
    if blocker then return blocker end

    blocker = CreateFrame("Button", nil, releaseBtn)
    blocker:SetAllPoints()
    blocker:SetFrameStrata("DIALOG")
    blocker:EnableMouse(true)
    blocker:RegisterForClicks("AnyUp", "AnyDown")

    local bg = blocker:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.85)

    timerLabel = blocker:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    timerLabel:SetPoint("CENTER", 0, 0)
    timerLabel:SetTextColor(1, 0.65, 0)
    local fontFile, fontSize, fontFlags = timerLabel:GetFont()
    timerLabel:SetFont(fontFile, fontSize * 0.7, fontFlags)

    blocker:SetScript("OnClick", function() end)

    return blocker
end

local function TickTimer(self, dt)
    if isReady then
        blocker:Hide()
        return
    end

    local altDown = IsAltKeyDown()

    if altDown then
        if pressStart == 0 then
            pressStart = GetTime()
        end

        local elapsed = GetTime() - pressStart
        local left = REQUIRED_HOLD - elapsed

        if left <= 0 then
            isReady = true
            blocker:Hide()
        else
            timerLabel:SetText(format(L["MODULES_DONT_RELEASE_TIMER"], left))
        end
    else
        pressStart = 0
        timerLabel:SetText(format(L["MODULES_DONT_RELEASE_TIMER"], REQUIRED_HOLD))
    end
end

local function ClearState()
    pressStart = 0
    isReady = false
    if blocker then
        blocker:SetScript("OnUpdate", nil)
        blocker:Hide()
    end
end

local function ActivateProtection()
    local db = NaowhQOL and NaowhQOL.misc
    if not db or not db.deathReleaseProtection then return end

    local visible, popup = StaticPopup_Visible("DEATH")
    if not visible or not popup then return end

    local btn = popup.GetButton and popup:GetButton(1)
    if not btn then return end

    BuildBlocker(btn)
    ClearState()
    timerLabel:SetText(format(L["MODULES_DONT_RELEASE_TIMER"], REQUIRED_HOLD))
    blocker:Show()
    blocker:SetScript("OnUpdate", TickTimer)
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_DEAD")
watcher:RegisterEvent("PLAYER_ALIVE")
watcher:RegisterEvent("PLAYER_UNGHOST")

watcher:SetScript("OnEvent", function(self, ev)
    if ev == "PLAYER_DEAD" then
        C_Timer.After(0.05, ActivateProtection)
    else
        ClearState()
    end
end)
