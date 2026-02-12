local addonName, ns = ...
local L = ns.L
local W = ns.Widgets

local RangeLib = LibStub("LibRangeCheck-3.0", true)

local inCombat = false

local FRAME_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

---------------------------------------------------------------------------
-- Target helpers
---------------------------------------------------------------------------
local function HasAttackableTarget()
    if not UnitExists("target") then return false end
    if not UnitCanAttack("player", "target") then return false end
    if UnitIsDeadOrGhost("target") then return false end
    return true
end

---------------------------------------------------------------------------
-- Color helpers
---------------------------------------------------------------------------
local function GetColorForRange(minRange)
    local db = NaowhQOL.rangeCheck
    if not db or not db.rangeColors then
        return db and db.rangeColorR or 0.01, db and db.rangeColorG or 0.56, db and db.rangeColorB or 0.91
    end
    local bracket = math.floor((minRange or 0) / 5) * 5
    local color = db.rangeColors[bracket] or db.rangeColors[0]
    if color then
        return color.r, color.g, color.b
    end
    return 0.01, 0.56, 0.91
end

---------------------------------------------------------------------------
-- Range to Target Frame
---------------------------------------------------------------------------
local rangeFrame = CreateFrame("Frame", "NaowhQOL_RangeToTarget", UIParent, "BackdropTemplate")
rangeFrame:SetSize(200, 40)
rangeFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -190)
rangeFrame:Hide()

local rangeLabel = rangeFrame:CreateFontString(nil, "OVERLAY")
rangeLabel:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", 24, "OUTLINE")
rangeLabel:SetPoint("CENTER")

local rangeResizeHandle

function rangeFrame:UpdateDisplay()
    local db = NaowhQOL.rangeCheck
    if not db then return end

    if not db.enabled or not db.rangeEnabled then
        rangeFrame:SetBackdrop(nil)
        if rangeResizeHandle then rangeResizeHandle:Hide() end
        rangeFrame:Hide()
        return
    end

    if db.rangeUnlock then
        rangeFrame:SetBackdrop(FRAME_BACKDROP)
        rangeFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        rangeFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        rangeFrame:EnableMouse(true)
        if rangeResizeHandle then rangeResizeHandle:Show() end
        rangeFrame:Show()
    else
        rangeFrame:SetBackdrop(nil)
        rangeFrame:EnableMouse(false)
        if rangeResizeHandle then rangeResizeHandle:Hide() end
    end

    if not rangeFrame.initialized then
        rangeFrame:ClearAllPoints()
        local point = db.rangePoint or "CENTER"
        local x = db.rangeX or 0
        local y = db.rangeY or -190
        rangeFrame:SetPoint(point, UIParent, point, x, y)
        rangeFrame:SetSize(db.rangeWidth or 200, db.rangeHeight or 40)
        rangeFrame.initialized = true
    end

    local fontPath = db.rangeFont or "Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf"
    local fontSize = math.max(10, math.min(72, math.floor(rangeFrame:GetHeight() * 0.55)))
    local ok = rangeLabel:SetFont(fontPath, fontSize, "OUTLINE")
    if not ok then
        rangeLabel:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", fontSize, "OUTLINE")
    end
end

---------------------------------------------------------------------------
-- Tick (updates range display at 0.1s intervals)
---------------------------------------------------------------------------
local TICK_RATE = 0.1
local tickAcc = 0

local function TickRangeCheck()
    local db = NaowhQOL.rangeCheck
    if not db or not db.enabled then
        rangeFrame:Hide()
        return
    end

    if not RangeLib then
        rangeFrame:Hide()
        return
    end

    local hasTarget = HasAttackableTarget()

    if db.rangeEnabled and hasTarget then
        if db.rangeCombatOnly and not inCombat and not db.rangeUnlock then
            rangeFrame:Hide()
        else
            local minRange, maxRange = RangeLib:GetRange("target")
            if minRange and maxRange then
                rangeLabel:SetText(minRange .. "-" .. maxRange .. " yd")
            elseif maxRange then
                rangeLabel:SetText("0-" .. maxRange .. " yd")
            elseif minRange then
                rangeLabel:SetText(minRange .. "+ yd")
            else
                rangeLabel:SetText("-- yd")
            end
            rangeLabel:SetTextColor(GetColorForRange(minRange))
            if not db.rangeUnlock then
                rangeFrame:Show()
            end
        end
    else
        if not db.rangeUnlock then
            rangeFrame:Hide()
        end
    end
end

local tickFrame = CreateFrame("Frame")
tickFrame:SetScript("OnUpdate", ns.PerfMonitor:Wrap("Range Check", function(self, elapsed)
    tickAcc = tickAcc + elapsed
    if tickAcc < TICK_RATE then return end
    tickAcc = 0
    TickRangeCheck()
end))

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_REGEN_DISABLED")
loader:RegisterEvent("PLAYER_REGEN_ENABLED")
loader:RegisterEvent("PLAYER_TARGET_CHANGED")

loader:SetScript("OnEvent", function(self, event)
    local db = NaowhQOL.rangeCheck
    if not db then return end

    if event == "PLAYER_LOGIN" then
        inCombat = UnitAffectingCombat("player")

        if not RangeLib then
            RangeLib = LibStub("LibRangeCheck-3.0", true)
        end

        db.rangeWidth = db.rangeWidth or 200
        db.rangeHeight = db.rangeHeight or 40
        db.rangePoint = db.rangePoint or "CENTER"
        db.rangeX = db.rangeX or 0
        db.rangeY = db.rangeY or -190

        W.MakeDraggable(rangeFrame, {
            db = db,
            unlockKey = "rangeUnlock",
            pointKey = "rangePoint", xKey = "rangeX", yKey = "rangeY",
        })
        rangeResizeHandle = W.CreateResizeHandle(rangeFrame, {
            db = db,
            unlockKey = "rangeUnlock",
            widthKey = "rangeWidth", heightKey = "rangeHeight",
            minW = 75, minH = 10,
            onResize = function() rangeFrame:UpdateDisplay() end,
        })

        rangeFrame.initialized = false
        rangeFrame:UpdateDisplay()
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
    end

    -- Immediate refresh on any relevant event
    tickAcc = TICK_RATE
end)

---------------------------------------------------------------------------
-- Namespace exports
---------------------------------------------------------------------------
ns.RangeCheckRangeFrame = rangeFrame
