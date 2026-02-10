local addonName, ns = ...
local L = ns.L

-- Use shared utilities from DisplayUtils
local DU = ns.DisplayUtils
local GetCachedTexture = DU.GetCachedTexture
local ScanAuras = DU.ScanAuras
local FindAuraByName = DU.FindAuraByName
local IsExpiring = DU.IsExpiring
local CanReadAuras = DU.CanReadAuras
local MakeSlot = DU.MakeSlot

local RAID_BUFFS = {
    { spellId = 1459,   class = "MAGE",    name = "Arcane Intellect" },
    { spellId = 1126,   class = "DRUID",   name = "Mark of the Wild" },
    { spellId = 21562,  class = "PRIEST",  name = "Power Word: Fortitude" },
    { spellId = 6673,   class = "WARRIOR", name = "Battle Shout" },
    { spellId = 462854, class = "SHAMAN",  name = "Skyfury" },
    { spellId = 381748, class = "EVOKER",  name = "Blessing of the Bronze" },
}

local playerClass, inCombat = nil, false
local activeTrackers = {}  -- { tracker, idSet }

local TRK_DIFFICULTY_FILTERS = {
    { inst = "party", diff = 1,  key = "diffNormalDungeon" },
    { inst = "party", diff = 2,  key = "diffHeroicDungeon" },
    { inst = "party", diff = 23, key = "diffMythicDungeon" },
    { inst = "party", diff = 8,  key = "diffMythicPlus" },
    { inst = "raid",  diff = 17, key = "diffLFR" },
    { inst = "raid",  diff = 14, key = "diffNormalRaid" },
    { inst = "raid",  diff = 15, key = "diffHeroicRaid" },
    { inst = "raid",  diff = 16, key = "diffMythicRaid" },
}

local SetSlot = DU.SetSlot

---------------------------------------------------------------------------
-- Custom tracker strip
---------------------------------------------------------------------------
local icons = CreateFrame("Frame", "NaowhQOL_BuffMonitorIcons", UIParent, "BackdropTemplate")
icons:SetSize(90, 56); icons:SetPoint("CENTER", 0, 100)
icons:SetMovable(true); icons:EnableMouse(true)
icons:RegisterForDrag("LeftButton"); icons:SetClampedToScreen(true); icons:Hide()

local iconSlots = {}
local function EnsureSlots(n)
    while #iconSlots < n do iconSlots[#iconSlots + 1] = MakeSlot(icons) end
end

local iconsDragging = false

local function PositionIcons(db, count)
    local sz = db.iconSize or 40
    if not iconsDragging then
        icons:ClearAllPoints()
        icons:SetPoint(db.iconPoint or "CENTER", UIParent, db.iconPoint or "CENTER",
                       db.iconX or 0, db.iconY or 100)
    end
    for i = 1, count do
        iconSlots[i]:SetSize(sz, sz); iconSlots[i]:ClearAllPoints()
        iconSlots[i]:SetPoint("TOPLEFT", (i - 1) * (sz + 10), 0); iconSlots[i]:Show()
    end
    for i = count + 1, #iconSlots do iconSlots[i]:Hide() end
    icons:SetSize(math.max(1, count * sz + (count - 1) * 10), sz + 16)
end

icons:SetScript("OnDragStart", function(self)
    local db = NaowhQOL.buffMonitor
    if db and db.enabled and db.unlock then
        iconsDragging = true; self:StartMoving()
    end
end)
icons:SetScript("OnDragStop", function(self)
    iconsDragging = false; self:StopMovingOrSizing()
    local db = NaowhQOL.buffMonitor
    if db then
        local p, _, _, x, y = self:GetPoint()
        if p and x and y then
            db.iconPoint, db.iconX, db.iconY = p, math.floor(x), math.floor(y)
        end
    end
end)

---------------------------------------------------------------------------
-- Raid buff strip
---------------------------------------------------------------------------
local raidIcons = CreateFrame("Frame", "NaowhQOL_BuffMonitorRaidIcons", UIParent, "BackdropTemplate")
raidIcons:SetSize(90, 56); raidIcons:SetPoint("TOP", 0, -100)
raidIcons:SetMovable(true); raidIcons:EnableMouse(true)
raidIcons:RegisterForDrag("LeftButton"); raidIcons:SetClampedToScreen(true); raidIcons:Hide()

local raidSlots = {}
local function EnsureRaidSlots(n)
    while #raidSlots < n do raidSlots[#raidSlots + 1] = MakeSlot(raidIcons) end
end

local raidDragging = false

local function PositionRaidIcons(db, count)
    local sz = db.raidIconSize or 40
    if not raidDragging then
        raidIcons:ClearAllPoints()
        raidIcons:SetPoint(db.raidIconPoint or "TOP", UIParent, db.raidIconPoint or "TOP",
                           db.raidIconX or 0, db.raidIconY or -100)
    end
    for i = 1, count do
        raidSlots[i]:SetSize(sz, sz); raidSlots[i]:ClearAllPoints()
        raidSlots[i]:SetPoint("TOPLEFT", (i - 1) * (sz + 10), 0); raidSlots[i]:Show()
    end
    for i = count + 1, #raidSlots do raidSlots[i]:Hide() end
    raidIcons:SetSize(math.max(1, count * sz + (count - 1) * 10), sz + 16)
end

raidIcons:SetScript("OnDragStart", function(self)
    local db = NaowhQOL.buffMonitor
    if db and db.enabled and db.unlockRaid then
        raidDragging = true; self:StartMoving()
    end
end)
raidIcons:SetScript("OnDragStop", function(self)
    raidDragging = false; self:StopMovingOrSizing()
    local db = NaowhQOL.buffMonitor
    if db then
        local p, _, _, x, y = self:GetPoint()
        if p and x and y then
            db.raidIconPoint, db.raidIconX, db.raidIconY = p, math.floor(x), math.floor(y)
        end
    end
end)

---------------------------------------------------------------------------
-- Unlock backdrop visibility
---------------------------------------------------------------------------
local FRAME_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local function SetFrameUnlocked(frame, unlocked, label)
    if unlocked then
        frame:SetBackdrop(FRAME_BACKDROP)
        frame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        if not frame:IsShown() then
            frame:SetSize(120, 40)
            frame:Show()
        end
        if not frame.unlockLabel then
            frame.unlockLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            frame.unlockLabel:SetPoint("CENTER")
        end
        frame.unlockLabel:SetText(label or L["COMMON_DRAG_TO_MOVE"])
        frame.unlockLabel:Show()
    else
        frame:StopMovingOrSizing()
        frame:SetBackdrop(FRAME_BACKDROP)
        frame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0)
        if frame.unlockLabel then frame.unlockLabel:Hide() end
    end
end

function ns:SetBuffMonitorUnlock(unlocked)
    local db = NaowhQOL.buffMonitor
    if not db or not db.enabled then unlocked = false end
    icons:EnableMouse(unlocked)
    SetFrameUnlocked(icons, unlocked, "Custom Tracker")
    if not unlocked then iconsDragging = false; ns:RefreshBuffMonitor() end
end

function ns:SetBuffMonitorRaidUnlock(unlocked)
    local db = NaowhQOL.buffMonitor
    if not db or not db.enabled then unlocked = false end
    raidIcons:EnableMouse(unlocked)
    SetFrameUnlocked(raidIcons, unlocked, "Raid Buffs")
    if not unlocked then raidDragging = false; ns:RefreshBuffMonitor() end
end

---------------------------------------------------------------------------
-- Guarded hide — keeps frame visible while user is positioning it
---------------------------------------------------------------------------
local function SafeHide(frame, unlockKey)
    local db = NaowhQOL.buffMonitor
    if not db or not db.enabled or not db[unlockKey] then frame:Hide() end
end

local function ShouldShowTracker(t, zone)
    if not t.diffEnabled then return true end
    if not zone or zone.instanceType == "none" then return true end
    for _, f in ipairs(TRK_DIFFICULTY_FILTERS) do
        if zone.instanceType == f.inst and zone.difficulty == f.diff then
            return t[f.key] ~= false
        end
    end
    return true
end

local function GetThreshold(tracker)
    if ns.ZoneUtil and ns.ZoneUtil.IsInRaid() then return tracker.thresholdRaid or 900
    elseif ns.ZoneUtil and ns.ZoneUtil.IsInDungeon() then return tracker.thresholdDungeon or 2400
    else return tracker.thresholdOpen or 300 end
end

---------------------------------------------------------------------------
-- Custom tracker filtering
---------------------------------------------------------------------------
local function FilterTrackers()
    activeTrackers = {}
    local db = NaowhQOL.buffMonitor
    if not db or not db.trackers then return end
    local zone = ns.ZoneUtil and ns.ZoneUtil.GetCurrentZone()
    for _, t in ipairs(db.trackers) do
        if not t.disabled and (t.class == "ALL" or t.class == playerClass)
           and t.entries and #t.entries > 0 and ShouldShowTracker(t, zone) then
            local entrySet = {}
            for _, e in ipairs(t.entries) do entrySet[e] = true end
            activeTrackers[#activeTrackers + 1] = {
                tracker = t, entrySet = entrySet, entries = t.entries,
                matchType = t.matchType or "spellId"
            }
        end
    end
end

---------------------------------------------------------------------------
-- Raid buff check
---------------------------------------------------------------------------
local function CheckRaidBuffs(auras)
    local db = NaowhQOL.buffMonitor
    if not db or not db.enabled or not db.raidBuffsEnabled then
        SafeHide(raidIcons, "unlockRaid"); return
    end
    if inCombat or (ns.ZoneUtil and ns.ZoneUtil.IsInMythicPlus()) then
        SafeHide(raidIcons, "unlockRaid"); return
    end
    if not auras then SafeHide(raidIcons, "unlockRaid"); return end

    pcall(function()
        local groupClasses = ns.GroupUtil and ns.GroupUtil.GetGroupClasses() or {}
        local now = GetTime()
        local slots = {}

        for _, buff in ipairs(RAID_BUFFS) do
            if groupClasses[buff.class] then
                local a = auras[buff.spellId]
                local missing = not a
                local expired = a and a.expiry ~= 0 and (a.expiry - now) <= 0
                if missing or expired then
                    local icon = GetCachedTexture(buff.spellId)
                    slots[#slots + 1] = { label = buff.name, data = a, fallbackIcon = icon }
                end
            end
        end

        if #slots > 0 then
            EnsureRaidSlots(#slots); PositionRaidIcons(db, #slots)
            for i, s in ipairs(slots) do
                SetSlot(raidSlots[i], s.label, s.data, s.fallbackIcon)
                -- Apply raid buff font settings
                local labelSize = db.raidLabelFontSize or 9
                local labelOffset = 10 + labelSize  -- Scale offset with font size
                raidSlots[i].lbl:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", labelSize, "OUTLINE")
                raidSlots[i].lbl:ClearAllPoints()
                raidSlots[i].lbl:SetPoint("TOP", 0, labelOffset)
                raidSlots[i].lbl:SetTextColor(db.raidLabelColorR or 0.7, db.raidLabelColorG or 0.7, db.raidLabelColorB or 0.7)
            end
            raidIcons:Show()
        else
            SafeHide(raidIcons, "unlockRaid")
        end
    end)
end

---------------------------------------------------------------------------
-- Custom tracker check
---------------------------------------------------------------------------
local loader

local function CheckTrackers()
    local db = NaowhQOL.buffMonitor
    if not db or not db.enabled then
        SafeHide(icons, "unlock"); SafeHide(raidIcons, "unlockRaid")
        return
    end
    if inCombat or (ns.ZoneUtil and ns.ZoneUtil.IsInMythicPlus()) then
        SafeHide(icons, "unlock"); SafeHide(raidIcons, "unlockRaid")
        return
    end

    pcall(function()
        local auras, auraNames = ScanAuras()
        if not auras then
            SafeHide(icons, "unlock")
            SafeHide(raidIcons, "unlockRaid")
            return
        end

        -- Raid buffs
        CheckRaidBuffs(auras)

        -- Custom trackers
        if #activeTrackers == 0 then
            SafeHide(icons, "unlock")
            return
        end

        local now = GetTime()
        local slots = {}
        auraNames = auraNames or {}

        for ai, entry in ipairs(activeTrackers) do
            local t = entry.tracker
            local threshold = GetThreshold(t)
            local matchType = entry.matchType

            if t.exclusive then
                local best = nil
                for e in pairs(entry.entrySet) do
                    local a
                    if matchType == "name" then a = FindAuraByName(auraNames, e)
                    else a = auras[e] end
                    if a and not IsExpiring(a, threshold, now) then
                        best = a; break
                    elseif a and (not best or a.expiry > best.expiry) then
                        best = a
                    end
                end
                local ok = best and not IsExpiring(best, threshold, now)
                if not ok then
                    local icon
                    if matchType == "spellId" then
                        local firstId = entry.entries[1]
                        icon = firstId and GetCachedTexture(firstId)
                    else
                        icon = best and best.icon
                    end
                    slots[#slots + 1] = { label = t.name, data = best, fallbackIcon = icon }
                end
            else
                for _, e in ipairs(entry.entries) do
                    local a, matched
                    if matchType == "name" then a, matched = FindAuraByName(auraNames, e)
                    else a = auras[e] end
                    if IsExpiring(a, threshold, now) then
                        local displayName, icon
                        if matchType == "name" then
                            displayName = matched or e
                            icon = a and a.icon
                        else
                            local info = C_Spell.GetSpellInfo(e)
                            displayName = (info and info.name) or tostring(e)
                            icon = GetCachedTexture(e)
                        end
                        slots[#slots + 1] = { label = displayName, data = a, fallbackIcon = icon }
                    end
                end
            end
        end

        if #slots > 0 then
            EnsureSlots(#slots); PositionIcons(db, #slots)
            for i, s in ipairs(slots) do
                SetSlot(iconSlots[i], s.label, s.data, s.fallbackIcon)
                -- Apply custom tracker font settings
                local labelSize = db.customLabelFontSize or 9
                local timerSize = db.customTimerFontSize or 11
                local labelOffset = 10 + labelSize  -- Scale offset with font size
                local timerOffset = -(10 + timerSize)  -- Scale offset with font size
                iconSlots[i].lbl:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", labelSize, "OUTLINE")
                iconSlots[i].lbl:ClearAllPoints()
                iconSlots[i].lbl:SetPoint("TOP", 0, labelOffset)
                iconSlots[i].lbl:SetTextColor(db.customLabelColorR or 0.7, db.customLabelColorG or 0.7, db.customLabelColorB or 0.7)
                iconSlots[i].timer:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", timerSize, "OUTLINE")
                iconSlots[i].timer:ClearAllPoints()
                iconSlots[i].timer:SetPoint("BOTTOM", 0, timerOffset)
            end
            icons:Show()
        else
            SafeHide(icons, "unlock")
        end
    end)
end

---------------------------------------------------------------------------
-- Guard tick and refresh
---------------------------------------------------------------------------
local function GuardTick()
    local db = NaowhQOL.buffMonitor
    local hasWork = #activeTrackers > 0 or (db and db.raidBuffsEnabled)
    if not hasWork then return end
    if inCombat or (ns.ZoneUtil and ns.ZoneUtil.IsInMythicPlus()) then
        loader:UnregisterEvent("UNIT_AURA")
        SafeHide(icons, "unlock"); SafeHide(raidIcons, "unlockRaid")
        return
    end
    if CanReadAuras() then loader:RegisterEvent("UNIT_AURA"); pcall(CheckTrackers)
    else
        loader:UnregisterEvent("UNIT_AURA")
        SafeHide(icons, "unlock"); SafeHide(raidIcons, "unlockRaid")
    end
end

function ns:RefreshBuffMonitor()
    pcall(FilterTrackers)
    pcall(GuardTick)
end

---------------------------------------------------------------------------
-- Event handling
---------------------------------------------------------------------------
loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_REGEN_DISABLED")
loader:RegisterEvent("PLAYER_REGEN_ENABLED")

-- Coalesce rapid UNIT_AURA bursts into a single scan
local auraDirty = false
local function FlushAura()
    if auraDirty then auraDirty = false; pcall(CheckTrackers) end
end

loader:SetScript("OnEvent", function(self, ev, a1)
    if ev == "ADDON_LOADED" and a1 == addonName then
        self:UnregisterEvent("ADDON_LOADED")
    elseif ev == "PLAYER_LOGIN" then
        playerClass = select(2, UnitClass("player"))
        for _, buff in ipairs(RAID_BUFFS) do GetCachedTexture(buff.spellId) end
        -- Restore unlock visuals if they were left on
        local bdb = NaowhQOL.buffMonitor
        icons:EnableMouse(bdb and bdb.unlock or false)
        raidIcons:EnableMouse(bdb and bdb.unlockRaid or false)
        if bdb and bdb.unlock then SetFrameUnlocked(icons, true, "Custom Tracker") end
        if bdb and bdb.unlockRaid then SetFrameUnlocked(raidIcons, true, "Raid Buffs") end
        FilterTrackers()
        C_Timer.NewTicker(1, function() pcall(GuardTick) end); C_Timer.After(1, function() pcall(GuardTick) end)
        -- Re-check when group composition changes
        if ns.GroupUtil then
            ns.GroupUtil.RegisterCallback("BuffMonitor", function()
                if not inCombat then pcall(CheckTrackers) end
            end)
        end
    elseif ev == "UNIT_AURA" and a1 == "player" then
        if not auraDirty then auraDirty = true; C_Timer.After(0.15, FlushAura) end
    elseif ev == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        SafeHide(icons, "unlock"); SafeHide(raidIcons, "unlockRaid")
    elseif ev == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        C_Timer.After(0.5, function() pcall(CheckTrackers) end)
    end
end)

ns.BuffMonitorIcon = icons
ns.BuffMonitorRaidIcon = raidIcons

---------------------------------------------------------------------------
-- Module cleanup for disable
---------------------------------------------------------------------------
function ns:DisableBuffMonitor()
    icons:Hide()
    raidIcons:Hide()
    loader:UnregisterEvent("UNIT_AURA")
    wipe(activeTrackers)
    DU.ClearTextureCache()
end
