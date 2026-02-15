local addonName, ns = ...
local L = ns.L
local W = ns.Widgets

local inCombat = false
local stealthed = false
local isResting = false

local UNLOCK_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

-- Specs where stealth matters
local function IsStealthSpec()
    local cls = ns.SpecUtil.GetClassName()
    if cls == "ROGUE" then return true end
    if cls == "DRUID" then
        local db = NaowhQOL.stealthReminder
        local specIdx = ns.SpecUtil.GetSpecIndex()
        if specIdx == 2 then return true end  -- Feral always enabled
        if specIdx == 1 and db and db.enableBalance then return true end
        if specIdx == 3 and db and db.enableGuardian then return true end
        if specIdx == 4 and db and db.enableResto then return true end
    end
    return false
end

-- ----------------------------------------------------------------
-- Stealth Reminder
-- ----------------------------------------------------------------

local stealthFrame = CreateFrame("Frame", "NaowhQOL_StealthReminder", UIParent, "BackdropTemplate")
stealthFrame:SetSize(200, 40)
stealthFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
stealthFrame:Hide()

local stealthLabel = stealthFrame:CreateFontString(nil, "OVERLAY")
stealthLabel:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", 24, "OUTLINE")
stealthLabel:SetPoint("CENTER")

local stealthResizeHandle

function stealthFrame:UpdateDisplay()
    local db = NaowhQOL.stealthReminder
    if not db then return end

    stealthFrame:EnableMouse(db.unlock)
    if db.unlock then
        stealthFrame:SetBackdrop(UNLOCK_BACKDROP)
        stealthFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        stealthFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        if stealthResizeHandle then stealthResizeHandle:Show() end
        stealthFrame:Show()
    else
        stealthFrame:SetBackdrop(nil)
        if stealthResizeHandle then stealthResizeHandle:Hide() end
    end

    if not stealthFrame.initialized then
        stealthFrame:ClearAllPoints()
        local point = db.point or "CENTER"
        local x = db.x or 0
        local y = db.y or 150
        stealthFrame:SetPoint(point, UIParent, point, x, y)
        stealthFrame:SetSize(db.width or 200, db.height or 40)
        stealthFrame.initialized = true
    end

    local fontPath = db.font or "Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf"
    local fontSize = math.max(10, math.min(72, math.floor(stealthFrame:GetHeight() * 0.55)))
    local success = stealthLabel:SetFont(fontPath, fontSize, "OUTLINE")
    if not success then
        stealthLabel:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", fontSize, "OUTLINE")
    end

    if not db.enabled then
        stealthFrame:Hide()
        return
    end

    if not IsStealthSpec() and not db.unlock then
        stealthFrame:Hide()
        return
    end

    if inCombat and not db.unlock then
        stealthFrame:Hide()
        return
    end

    if IsMounted() and not db.unlock then
        stealthFrame:Hide()
        return
    end

    if db.disableWhenRested and isResting and not db.unlock then
        stealthFrame:Hide()
        return
    end

    if stealthed then
        if db.showStealthed == false and not db.unlock then
            stealthFrame:Hide()
            return
        end
        stealthLabel:SetText(db.stealthText or L["STEALTH_DEFAULT"])
        local sR, sG, sB = W.GetEffectiveColor(db, "stealthR", "stealthG", "stealthB", "stealthUseClassColor")
        stealthLabel:SetTextColor(sR, sG, sB)
    else
        if db.showNotStealthed == false and not db.unlock then
            stealthFrame:Hide()
            return
        end
        stealthLabel:SetText(db.warningText or L["STEALTH_WARNING_DEFAULT"])
        local wR, wG, wB = W.GetEffectiveColor(db, "warningR", "warningG", "warningB", "warningUseClassColor")
        stealthLabel:SetTextColor(wR, wG, wB)
    end

    stealthFrame:Show()
end

-- ----------------------------------------------------------------
-- Stance Reminder
-- ----------------------------------------------------------------

-- Maps class + spec index to the expected shapeshift form
local expectedForms = {
    DRUID = {
        [1] = 4,  -- Balance  → Moonkin
        [2] = 2,  -- Feral    → Cat
        [3] = 1,  -- Guardian → Bear
    },
    WARRIOR = {
        [1] = 2,  -- Arms       → Battle Stance
        [2] = 2,  -- Fury       → Battle Stance
        [3] = 1,  -- Protection → Defensive Stance
    },
    PRIEST = {
        [3] = {1, 2},  -- Shadow → Shadowform or Voidform
    },
    -- Paladin aura support contributed by Bazook
    PALADIN = {
        [1] = {2, 3},  -- Holy → Devotion/Concentration Aura
        [2] = {2, 3},  -- Protection → Devotion/Concentration Aura
        [3] = {2, 3},  -- Retribution → Devotion/Concentration Aura
    },
}

local stanceFrame = CreateFrame("Frame", "NaowhQOL_StanceReminder", UIParent, "BackdropTemplate")
stanceFrame:SetSize(200, 40)
stanceFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
stanceFrame:Hide()

local stanceLabel = stanceFrame:CreateFontString(nil, "OVERLAY")
stanceLabel:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", 24, "OUTLINE")
stanceLabel:SetPoint("CENTER")

local stanceResizeHandle
local currentFormIndex = 0
local stanceSoundTicker = nil
local lastStanceSoundTime = 0
local STANCE_SOUND_COOLDOWN = 0.9
local stanceSoundFired = false

local function StopStanceSound()
    if stanceSoundTicker then
        stanceSoundTicker:Cancel()
        stanceSoundTicker = nil
    end
end

local function PlayStanceSound(sound)
    local now = GetTime()
    if now - lastStanceSoundTime < STANCE_SOUND_COOLDOWN then return end
    lastStanceSoundTime = now
    ns.SoundList.Play(sound)
end

local function StartStanceSound(db)
    StopStanceSound()
    local interval = db.stanceSoundInterval or 3
    local sound = db.stanceSound or { id = 8959 }
    PlayStanceSound(sound)
    stanceSoundFired = true
    if interval > 0 then
        stanceSoundTicker = C_Timer.NewTicker(interval, function()
            PlayStanceSound(sound)
        end)
    end
end

local function GetExpectedForm()
    local classForms = expectedForms[ns.SpecUtil.GetClassName()]
    if not classForms then return nil end
    return classForms[ns.SpecUtil.GetSpecIndex()]
end

local function IsInExpectedForm(expected)
    if type(expected) == "table" then
        for _, formIdx in ipairs(expected) do
            if currentFormIndex == formIdx then return true end
        end
        return false
    end
    return currentFormIndex == expected
end

function stanceFrame:UpdateDisplay()
    local db = NaowhQOL.stealthReminder
    if not db then return end

    stanceFrame:EnableMouse(db.stanceUnlock)
    if db.stanceUnlock and db.stanceEnabled then
        stanceFrame:SetBackdrop(UNLOCK_BACKDROP)
        stanceFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        stanceFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        if stanceResizeHandle then stanceResizeHandle:Show() end
        stanceFrame:Show()
    else
        stanceFrame:SetBackdrop(nil)
        if stanceResizeHandle then stanceResizeHandle:Hide() end
    end

    if not stanceFrame.initialized then
        stanceFrame:ClearAllPoints()
        local point = db.stancePoint or "CENTER"
        local x = db.stanceX or 0
        local y = db.stanceY or 100
        stanceFrame:SetPoint(point, UIParent, point, x, y)
        stanceFrame:SetSize(db.stanceWidth or 200, db.stanceHeight or 40)
        stanceFrame.initialized = true
    end

    local fontPath = db.font or "Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf"
    local fontSize = math.max(10, math.min(72, math.floor(stanceFrame:GetHeight() * 0.55)))
    local success = stanceLabel:SetFont(fontPath, fontSize, "OUTLINE")
    if not success then
        stanceLabel:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", fontSize, "OUTLINE")
    end

    if not db.stanceEnabled then
        StopStanceSound()
        stanceFrame:Hide()
        return
    end

    if db.stanceCombatOnly and not inCombat and not db.stanceUnlock then
        StopStanceSound()
        stanceFrame:Hide()
        return
    end

    if IsMounted() and not db.stanceUnlock then
        StopStanceSound()
        stanceFrame:Hide()
        return
    end

    if db.stanceDisableWhenRested and isResting and not db.stanceUnlock then
        StopStanceSound()
        stanceFrame:Hide()
        return
    end

    local expected = GetExpectedForm()
    if not expected then
        StopStanceSound()
        if not db.stanceUnlock then stanceFrame:Hide() end
        return
    end

    if not IsInExpectedForm(expected) then
        stanceLabel:SetText(db.stanceWarnText or L["STEALTH_STANCE_DEFAULT"])
        local swR, swG, swB = W.GetEffectiveColor(db, "stanceWarnR", "stanceWarnG", "stanceWarnB", "stanceWarnUseClassColor")
        stanceLabel:SetTextColor(swR, swG, swB)
        stanceFrame:Show()
        if db.stanceSoundEnabled and not stanceSoundTicker and not stanceSoundFired then
            StartStanceSound(db)
        elseif not db.stanceSoundEnabled then
            StopStanceSound()
            stanceSoundFired = false
        end
    else
        stanceSoundFired = false
        StopStanceSound()
        stanceFrame:Hide()
    end
end

-- ----------------------------------------------------------------
-- Events
-- ----------------------------------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("UPDATE_STEALTH")
loader:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
loader:RegisterEvent("PLAYER_REGEN_DISABLED")
loader:RegisterEvent("PLAYER_REGEN_ENABLED")
loader:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
loader:RegisterEvent("PLAYER_UPDATE_RESTING")
loader:RegisterEvent("PLAYER_LOGOUT")

loader:SetScript("OnEvent", ns.PerfMonitor:Wrap("Stealth/Stance", function(self, event)
    local db = NaowhQOL.stealthReminder
    if not db then return end

    if event == "PLAYER_LOGIN" then
        stealthed = IsStealthed()
        inCombat = UnitAffectingCombat("player")
        currentFormIndex = GetShapeshiftForm()
        isResting = IsResting()

        db.width = db.width or 200
        db.height = db.height or 40
        db.point = db.point or "CENTER"
        db.x = db.x or 0
        db.y = db.y or 150

        W.MakeDraggable(stealthFrame, { db = db })
        stealthResizeHandle = W.CreateResizeHandle(stealthFrame, {
            db = db,
            onResize = function() stealthFrame:UpdateDisplay() end,
        })

        db.stanceWidth = db.stanceWidth or 200
        db.stanceHeight = db.stanceHeight or 40
        db.stancePoint = db.stancePoint or "CENTER"
        db.stanceX = db.stanceX or 0
        db.stanceY = db.stanceY or 100

        W.MakeDraggable(stanceFrame, {
            db = db,
            unlockKey = "stanceUnlock",
            pointKey = "stancePoint", xKey = "stanceX", yKey = "stanceY",
        })
        stanceResizeHandle = W.CreateResizeHandle(stanceFrame, {
            db = db,
            unlockKey = "stanceUnlock",
            widthKey = "stanceWidth", heightKey = "stanceHeight",
            onResize = function() stanceFrame:UpdateDisplay() end,
        })

        stealthFrame.initialized = false
        stanceFrame.initialized = false
        stealthFrame:UpdateDisplay()
        stanceFrame:UpdateDisplay()

        -- Re-evaluate both frames when spec changes
        ns.SpecUtil.RegisterCallback("StealthStanceReminder", function()
            StopStanceSound()
            stealthFrame:UpdateDisplay()
            stanceFrame:UpdateDisplay()
        end)
        return
    end

    if event == "PLAYER_LOGOUT" then
        StopStanceSound()
        return
    end

    if event == "UPDATE_STEALTH" then
        stealthed = IsStealthed()
    elseif event == "UPDATE_SHAPESHIFT_FORM" then
        currentFormIndex = GetShapeshiftForm()
    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
    elseif event == "PLAYER_UPDATE_RESTING" then
        isResting = IsResting()
    end

    stealthFrame:UpdateDisplay()
    stanceFrame:UpdateDisplay()
end))

ns.StealthReminderDisplay = stealthFrame
ns.StanceReminderDisplay = stanceFrame
