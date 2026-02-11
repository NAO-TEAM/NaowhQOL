local addonName, ns = ...
local L = ns.L
local W = ns.Widgets
local MakeSlot = ns.DisplayUtils.MakeSlot

local NAOWH_FONT = "Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf"
local REBIRTH_SPELL_ID = 20484

-- State tracking (event-driven, not polled)
local inMythicPlus = false
local encounterActive = false

-- ----------------------------------------------------------------
-- Combat Rez Timer
-- ----------------------------------------------------------------

local rezFrame = CreateFrame("Frame", "NaowhQOL_CRezTimer", UIParent, "BackdropTemplate")
rezFrame:SetSize(40, 40)
rezFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
rezFrame:Hide()

local rezSlot = MakeSlot(rezFrame)
rezSlot:SetAllPoints()
rezSlot.lbl:Hide()  -- No label per spec

-- Stack count in bottom-right corner
rezSlot.count = rezSlot:CreateFontString(nil, "OVERLAY")
rezSlot.count:SetPoint("BOTTOMRIGHT", -2, 2)
rezSlot.count:SetFont(NAOWH_FONT, 11, "OUTLINE")

local rezUpdateElapsed = 0
local REZ_UPDATE_INTERVAL = 0.1

local function ShouldShowRezTimer()
    local db = NaowhQOL.cRez
    if not db or not db.enabled then return false end
    if db.unlock then return true end
    return inMythicPlus or encounterActive
end

local function UpdateRezDisplay()
    local db = NaowhQOL.cRez
    if not db then return end

    -- Apply font settings
    rezSlot.timer:SetFont(NAOWH_FONT, db.timerFontSize or 11, "OUTLINE")
    rezSlot.timer:SetTextColor(db.timerColorR or 1, db.timerColorG or 1, db.timerColorB or 1, db.timerAlpha or 1)
    rezSlot.count:SetFont(NAOWH_FONT, db.countFontSize or 11, "OUTLINE")
    rezSlot.count:SetTextColor(db.countColorR or 1, db.countColorG or 1, db.countColorB or 1, db.countAlpha or 1)

    local charges = C_Spell.GetSpellCharges(REBIRTH_SPELL_ID)
    if not charges then
        rezSlot.tex:SetTexture("Interface\\Icons\\Spell_Nature_Reincarnation")
        rezSlot.timer:SetText("--:--")
        rezSlot.count:SetText("0")
        return
    end

    local icon = C_Spell.GetSpellTexture(REBIRTH_SPELL_ID)
    rezSlot.tex:SetTexture(icon or "Interface\\Icons\\Spell_Nature_Reincarnation")
    rezSlot.count:SetText(tostring(charges.currentCharges))

    if charges.currentCharges >= charges.maxCharges then
        rezSlot.timer:SetText("")
        rezSlot.tex:SetDesaturated(false)
    else
        local remaining = charges.cooldownDuration - (GetTime() - charges.cooldownStartTime)
        if remaining > 0 then
            rezSlot.timer:SetText(format("%d:%02d", remaining / 60, remaining % 60))
        else
            rezSlot.timer:SetText("")
        end
        rezSlot.tex:SetDesaturated(charges.currentCharges == 0)
    end
end

rezFrame:SetScript("OnUpdate", function(self, elapsed)
    rezUpdateElapsed = rezUpdateElapsed + elapsed
    if rezUpdateElapsed < REZ_UPDATE_INTERVAL then return end
    rezUpdateElapsed = 0
    UpdateRezDisplay()
end)

function rezFrame:Refresh()
    local db = NaowhQOL.cRez
    if not db then self:Hide() return end

    self:EnableMouse(db.unlock)
    ns.DisplayUtils.SetFrameUnlocked(self, db.unlock, L["CREZ_UNLOCK_LABEL"] or "Rez Timer")

    local sz = db.iconSize or 40
    self:SetSize(sz, sz)

    if not self.posInitialized then
        self:ClearAllPoints()
        self:SetPoint(db.point or "CENTER", UIParent, db.point or "CENTER", db.x or 0, db.y or 150)
        self.posInitialized = true
    end

    if ShouldShowRezTimer() then
        self:Show()
        UpdateRezDisplay()
    else
        self:Hide()
    end
end

-- ----------------------------------------------------------------
-- Death Notice
-- ----------------------------------------------------------------


-- ----------------------------------------------------------------
-- Death Detection via UNIT_DIED
-- ----------------------------------------------------------------

local function OnUnitDied(unitGUID)
    local db = NaowhQOL.cRez
    if not db or not db.enabled or not db.deathWarning then return end

    -- Handle restricted/secret values
    if issecretvalue and issecretvalue(unitGUID) then return end
    if not unitGUID then return end

    local unit = UnitTokenFromGUID(unitGUID)
    if not unit then return end

    -- Check if in group or is player (for testing)
    local inGroup = IsGUIDInGroup and IsGUIDInGroup(unitGUID)
    local isPlayer = UnitIsUnit(unit, "player")
    if not inGroup and not isPlayer then return end

    -- Play warning sound
    PlaySound(SOUNDKIT.RAID_WARNING or 8959, "Master")

    -- Show warning text via RaidWarningFrame
    local name = UnitNameUnmodified(unit) or UnitName(unit) or "Unknown"
    local msg = name .. " " .. (L["CREZ_DIED"] or "died")
    RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo["RAID_WARNING"])
end

-- ----------------------------------------------------------------
-- Events
-- ----------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("ENCOUNTER_START")
eventFrame:RegisterEvent("ENCOUNTER_END")
eventFrame:RegisterEvent("CHALLENGE_MODE_START")
eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
eventFrame:RegisterEvent("UNIT_DIED")

eventFrame:SetScript("OnEvent", ns.PerfMonitor:Wrap("CRez", function(self, event, arg1)
    if event == "PLAYER_LOGIN" then
        local db = NaowhQOL.cRez
        if not db then return end

        -- Check initial M+ state
        inMythicPlus = ns.ZoneUtil.IsInMythicPlus()
        encounterActive = C_InstanceEncounter and C_InstanceEncounter.IsEncounterInProgress() or false

        -- Setup draggable for rez timer
        W.MakeDraggable(rezFrame, { db = db })

        -- Register for zone changes
        ns.ZoneUtil.RegisterCallback("CRez", function()
            inMythicPlus = ns.ZoneUtil.IsInMythicPlus()
            rezFrame:Refresh()
        end)

        rezFrame:Refresh()
        return
    end

    if event == "ENCOUNTER_START" then
        encounterActive = true
        rezFrame:Refresh()
        return
    end

    if event == "ENCOUNTER_END" then
        encounterActive = false
        rezFrame:Refresh()
        return
    end

    if event == "CHALLENGE_MODE_START" then
        inMythicPlus = true
        rezFrame:Refresh()
        return
    end

    if event == "CHALLENGE_MODE_COMPLETED" then
        inMythicPlus = false
        rezFrame:Refresh()
        return
    end

    if event == "UNIT_DIED" then
        OnUnitDied(arg1)
        return
    end
end))

-- Expose for config refresh
ns.CRezTimerDisplay = rezFrame
