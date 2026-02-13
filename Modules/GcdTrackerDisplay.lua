local addonName, ns = ...
local L = ns.L
local W = ns.Widgets

-- Shows scrolling icons of the player's recently used abilities.

-- Ring buffer for history to avoid O(n) table.remove operations
local history = {}
local historyHead = 1  -- Points to oldest entry
local historyTail = 0  -- Points to newest entry
local historyCount = 0
local MAX_HISTORY = 200  -- Maximum entries before wrap

local iconPool = {}
local activeIcons = {}
local inCombat = false
local zoneAllowed = true
local suppressUntil = 0

-- Pre-allocated frame pool
local PREALLOC_ICONS = 20
local PREALLOC_SEGS = 10
local poolInitialized = false

local DIRECTION_VECTORS = {
    LEFT  = { x = -1, y =  0 },
    RIGHT = { x =  1, y =  0 },
    UP    = { x =  0, y =  1 },
    DOWN  = { x =  0, y = -1 },
}

local PERP_VECTORS = {
    LEFT  = { x =  0, y = -1 },
    RIGHT = { x =  0, y = -1 },
    UP    = { x =  1, y =  0 },
    DOWN  = { x =  1, y =  0 },
}

local CLUSTER_WINDOW  = 0.3
local castingLookup   = {}
local recentCasts     = {}
local DEDUP_WINDOW    = 0.15
local gcdSpellID      = nil
local recentSpells    = {}
local recentSpellIdx  = {}  -- spellId -> index for O(1) lookup
local MAX_RECENT      = 10
local recentNextIdx   = 1
local recentValidCount = 0

-- Ring buffer for activity segments
local activitySegments  = {}
local segHead = 1
local segTail = 0
local segCount = 0
local MAX_SEGMENTS = 100

local lastActivityState = false
local segPool           = {}
local activeSegFrames   = {}
local TIMELINE_GAP      = 3

local combatStartTime     = 0
local totalDowntime       = 0
local lastDowntimeStart   = 0
local lastDowntimeActive  = false
local downtimeTicker      = nil

local ZONE_DB_KEY = {
    party = "showInDungeon",
    raid  = "showInRaid",
    arena = "showInArena",
    pvp   = "showInBattleground",
}

local function Acquire(pool, createFn)
    return table.remove(pool) or createFn()
end

-- Forward declarations for ring buffer cleanup
local ReleaseIcon, ReleaseSeg

-- Ring buffer helpers for history
local function HistoryPush(entry)
    historyTail = historyTail + 1
    if historyTail > MAX_HISTORY then historyTail = 1 end

    -- If we're about to overwrite an existing entry, release its icon
    if history[historyTail] and activeIcons[history[historyTail]] then
        ReleaseIcon(activeIcons[history[historyTail]])
        activeIcons[history[historyTail]] = nil
    end

    history[historyTail] = entry
    if historyCount < MAX_HISTORY then
        historyCount = historyCount + 1
    else
        -- Wrapped around, move head forward
        historyHead = historyHead + 1
        if historyHead > MAX_HISTORY then historyHead = 1 end
    end
end

local function HistoryDequeue()
    if historyCount == 0 then return nil end
    local entry = history[historyHead]
    history[historyHead] = nil
    historyHead = historyHead + 1
    if historyHead > MAX_HISTORY then historyHead = 1 end
    historyCount = historyCount - 1
    return entry
end

local function HistoryPeekOldest()
    if historyCount == 0 then return nil end
    return history[historyHead]
end

local function HistoryIterate()
    local idx = 0
    local pos = historyHead - 1
    return function()
        idx = idx + 1
        if idx > historyCount then return nil end
        pos = pos + 1
        if pos > MAX_HISTORY then pos = 1 end
        return history[pos]
    end
end

-- Ring buffer helpers for segments
local function SegmentPush(entry)
    segTail = segTail + 1
    if segTail > MAX_SEGMENTS then segTail = 1 end

    if activitySegments[segTail] and activeSegFrames[activitySegments[segTail]] then
        ReleaseSeg(activeSegFrames[activitySegments[segTail]])
        activeSegFrames[activitySegments[segTail]] = nil
    end

    activitySegments[segTail] = entry
    if segCount < MAX_SEGMENTS then
        segCount = segCount + 1
    else
        segHead = segHead + 1
        if segHead > MAX_SEGMENTS then segHead = 1 end
    end
    return entry
end

local function SegmentDequeue()
    if segCount == 0 then return nil end
    local entry = activitySegments[segHead]
    activitySegments[segHead] = nil
    segHead = segHead + 1
    if segHead > MAX_SEGMENTS then segHead = 1 end
    segCount = segCount - 1
    return entry
end

local function SegmentPeekOldest()
    if segCount == 0 then return nil end
    return activitySegments[segHead]
end

local function SegmentGetNewest()
    if segCount == 0 then return nil end
    return activitySegments[segTail]
end

local function SegmentIterate()
    local idx = 0
    local pos = segHead - 1
    return function()
        idx = idx + 1
        if idx > segCount then return nil end
        pos = pos + 1
        if pos > MAX_SEGMENTS then pos = 1 end
        return activitySegments[pos]
    end
end

local function CalcFade(fraction, fadeStart)
    if fraction <= fadeStart then return 1.0 end
    return math.max(0, 1.0 - (fraction - fadeStart) / (1.0 - fadeStart))
end

local function GetDB()
    local db = NaowhQOL.gcdTracker
    return (db and db.enabled) and db or nil
end

-- Same approach as Action Halo in MouseCursor.lua
local function GetClassGCDSpell()
    local _, class = UnitClass("player")
    local classSpells = {
        WARRIOR     = 100,
        PALADIN     = 35395,
        HUNTER      = 883,
        ROGUE       = 1752,
        PRIEST      = 585,
        DEATHKNIGHT = 49998,
        SHAMAN      = 188196,
        MAGE        = 133,
        WARLOCK     = 686,
        MONK        = 100780,
        DRUID       = 5176,
        DEMONHUNTER = 162243,
        EVOKER      = 361469,
    }
    return classSpells[class] or 61304
end

local function IsGCDActive()
    if not gcdSpellID then gcdSpellID = GetClassGCDSpell() end
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, info = pcall(C_Spell.GetSpellCooldown, gcdSpellID)
        if ok and info and info.isOnGCD then return true end
    end
    return false
end

local function IsCasting()
    local name = UnitCastingInfo("player")
    if name then return true end
    name = UnitChannelInfo("player")
    return name ~= nil
end

local function TrackDowntime()
    local now = GetTime()
    local activityActive = IsGCDActive() or IsCasting()

    if not activityActive and lastDowntimeActive then
        -- Activity just ended, start tracking downtime
        lastDowntimeStart = now
    elseif activityActive and not lastDowntimeActive and lastDowntimeStart > 0 then
        -- Activity resumed, accumulate downtime
        totalDowntime = totalDowntime + (now - lastDowntimeStart)
        lastDowntimeStart = 0
    end
    lastDowntimeActive = activityActive
end

local function GetSpellIcon(spellId)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellId)
        return info and info.iconID
    else
        local _, _, icon = GetSpellInfo(spellId)
        return icon
    end
end

local container = CreateFrame("Frame", "NaowhQOL_GcdTrackerDisplay", UIParent, "BackdropTemplate")
container:SetSize(200, 40)
container:SetPoint("CENTER", UIParent, "CENTER", 0, -100)
container:Hide()
container:EnableMouse(false)

local function CreateIconFrame()
    local f = CreateFrame("Frame", nil, container)
    f:SetSize(32, 32)

    f.glow = f:CreateTexture(nil, "BACKGROUND")
    f.glow:SetPoint("TOPLEFT", -1, 1)
    f.glow:SetPoint("BOTTOMRIGHT", 1, -1)
    f.glow:SetColorTexture(0.01, 0.56, 0.91, 0.7)
    f.glow:Hide()

    f.border = f:CreateTexture(nil, "BORDER")
    f.border:SetPoint("TOPLEFT", -1, 1)
    f.border:SetPoint("BOTTOMRIGHT", 1, -1)
    f.border:SetColorTexture(0, 0, 0, 0.8)

    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints()
    f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    f:Hide()
    return f
end

-- Assign to forward declaration
ReleaseIcon = function(f)
    f:Hide()
    f:ClearAllPoints()
    iconPool[#iconPool + 1] = f
end

local function CreateSegFrame()
    local db = NaowhQOL.gcdTracker
    local f = CreateFrame("Frame", nil, container)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints()
    local tlR, tlG, tlB = W.GetEffectiveColor(db, "timelineColorR", "timelineColorG", "timelineColorB", "timelineColorUseClassColor")
    f.tex:SetColorTexture(tlR, tlG, tlB, 0.6)
    f:Hide()
    return f
end

-- Assign to forward declaration
ReleaseSeg = function(f)
    f:Hide()
    f:ClearAllPoints()
    segPool[#segPool + 1] = f
end

-- Pre-allocate frame pools at initialization
local function InitializeFramePools()
    if poolInitialized then return end
    for i = 1, PREALLOC_ICONS do
        local f = CreateIconFrame()
        f:Hide()
        iconPool[#iconPool + 1] = f
    end
    for i = 1, PREALLOC_SEGS do
        local f = CreateSegFrame()
        f:Hide()
        segPool[#segPool + 1] = f
    end
    poolInitialized = true
end

local function ShouldBeVisible()
    local db = NaowhQOL.gcdTracker
    if not db or not db.enabled then return false end
    if db.unlock then return true end
    if db.combatOnly and not inCombat then return false end
    return zoneAllowed
end

local function RefreshVisibility()
    container:SetShown(ShouldBeVisible())
end

local ICON_STATES = {
    casting = { glow = true,  desat = false, vr = 1, vg = 1,   vb = 1,   br = 0.01, bg = 0.56, bb = 0.91, ba = 0.8 },
    failed  = { glow = false, desat = true,  vr = 1, vg = 0.3, vb = 0.3, br = 0.8,  bg = 0.1,  bb = 0.1,  ba = 0.9 },
    normal  = { glow = false, desat = false, vr = 1, vg = 1,   vb = 1,   br = 0,    bg = 0,    bb = 0,    ba = 0.8 },
}

local function ApplyIconState(f, state)
    local s = ICON_STATES[state]
    if s.glow then f.glow:Show() else f.glow:Hide() end
    f.tex:SetDesaturated(s.desat)
    f.tex:SetVertexColor(s.vr, s.vg, s.vb)
    f.border:SetColorTexture(s.br, s.bg, s.bb, s.ba)
end

local function LayoutIcons()
    local db = NaowhQOL.gcdTracker
    if not db then return end

    local now = GetTime()
    local duration = db.duration or 5
    local iconSize = db.iconSize or 32
    local spacing = db.spacing or 4
    local fadeStart = db.fadeStart or 0.5
    local dirKey = db.direction or "RIGHT"
    local dir = DIRECTION_VECTORS[dirKey] or DIRECTION_VECTORS.RIGHT
    local perp = PERP_VECTORS[dirKey] or PERP_VECTORS.RIGHT
    local scrollSpeed = (iconSize + spacing) * 1.5
    local gcdActive = IsGCDActive()

    -- Remove expired entries using ring buffer (O(1) dequeue)
    local oldest = HistoryPeekOldest()
    while oldest and (now - oldest.timestamp) > duration do
        local entry = HistoryDequeue()
        if entry and activeIcons[entry] then
            ReleaseIcon(activeIcons[entry])
            activeIcons[entry] = nil
        end
        oldest = HistoryPeekOldest()
    end

    -- Create icons for entries that don't have them
    for entry in HistoryIterate() do
        if not activeIcons[entry] then
            local f = Acquire(iconPool, CreateIconFrame)
            f.tex:SetTexture(entry.icon)
            f:SetSize(iconSize, iconSize)
            activeIcons[entry] = f
        end
    end

    local maxPrimaryOffset = 0
    local maxLane = 0
    for entry in HistoryIterate() do
        local f = activeIcons[entry]
        if f then
            local age = now - entry.timestamp
            local primaryOffset = age * scrollSpeed
            local lane = entry.lane or 0
            local perpOffset = lane * (iconSize + spacing)

            f:ClearAllPoints()
            f:SetPoint("CENTER", container, "CENTER",
                dir.x * primaryOffset + perp.x * perpOffset,
                dir.y * primaryOffset + perp.y * perpOffset)

            local isOnGCD = not entry.casting and not entry.failed and gcdActive and age < 2.0
            local state = (entry.casting or isOnGCD) and "casting" or entry.failed and "failed" or "normal"
            ApplyIconState(f, state)

            f:SetAlpha(CalcFade(age / duration, fadeStart))
            f:SetSize(iconSize, iconSize)
            f:Show()

            if primaryOffset > maxPrimaryOffset then maxPrimaryOffset = primaryOffset end
            if lane > maxLane then maxLane = lane end
        end
    end

    -- Activity timeline (GCD or casting) - split into 1s segments for natural fading
    local activityActive = gcdActive or IsCasting()
    if activityActive then
        local lastSeg = SegmentGetNewest()
        local needNewSeg = not lastSeg
            or lastSeg.endTime
            or (now - lastSeg.startTime) >= 1.0
        if needNewSeg then
            if lastSeg and not lastSeg.endTime then
                lastSeg.endTime = now
            end
            SegmentPush({ startTime = now })
        end
    elseif lastActivityState then
        local lastSeg = SegmentGetNewest()
        if lastSeg and not lastSeg.endTime then
            lastSeg.endTime = now
        end
    end

    lastActivityState = activityActive

    -- Remove expired segments using ring buffer (O(1) dequeue)
    local oldestSeg = SegmentPeekOldest()
    while oldestSeg and (now - oldestSeg.startTime) > duration do
        local seg = SegmentDequeue()
        if seg and activeSegFrames[seg] then
            ReleaseSeg(activeSegFrames[seg])
            activeSegFrames[seg] = nil
        end
        oldestSeg = SegmentPeekOldest()
    end

    local tlHeight = db.timelineHeight or 4
    local tlR, tlG, tlB = W.GetEffectiveColor(db, "timelineColorR", "timelineColorG", "timelineColorB", "timelineColorUseClassColor")
    local barPerpOff = iconSize / 2 + TIMELINE_GAP + tlHeight / 2

    for seg in SegmentIterate() do
        local segStartAge = math.min(now - seg.startTime, duration)
        local segEndAge = seg.endTime and (now - seg.endTime) or 0

        local startOff = segStartAge * scrollSpeed
        local endOff   = segEndAge * scrollSpeed
        local segLength = math.max(1, startOff - endOff)
        local midOff = (startOff + endOff) / 2

        if not activeSegFrames[seg] then
            activeSegFrames[seg] = Acquire(segPool, CreateSegFrame)
        end
        local sf = activeSegFrames[seg]
        sf:ClearAllPoints()
        sf.tex:SetColorTexture(tlR, tlG, tlB, 0.6)

        if dir.x ~= 0 then
            sf:SetSize(segLength, tlHeight)
            sf:SetPoint("CENTER", container, "CENTER", dir.x * midOff, -barPerpOff)
        else
            sf:SetSize(tlHeight, segLength)
            sf:SetPoint("CENTER", container, "CENTER", barPerpOff, dir.y * midOff)
        end

        sf:SetAlpha(CalcFade(segStartAge / duration, fadeStart))
        sf:Show()
    end

    local primarySpan = math.max(iconSize, maxPrimaryOffset + iconSize)
    local perpSpan = (maxLane + 1) * (iconSize + spacing) + TIMELINE_GAP + tlHeight
    if dir.x ~= 0 then
        container:SetSize(primarySpan, perpSpan)
    else
        container:SetSize(perpSpan, primarySpan)
    end
end

-- 40 fps cap
local UPDATE_INTERVAL = 0.025
local elapsedAcc = 0

container:SetScript("OnUpdate", ns.PerfMonitor:Wrap("GCD Tracker", function(self, elapsed)
    local db = NaowhQOL.gcdTracker
    if not db or not db.enabled then return end
    elapsedAcc = elapsedAcc + elapsed
    if elapsedAcc >= UPDATE_INTERVAL then
        elapsedAcc = 0
        LayoutIcons()
    end
end))

-- Helper to get the newest history entry for lane assignment
local function GetNewestHistoryEntry()
    if historyCount == 0 then return nil end
    return history[historyTail]
end

local function AssignLane()
    if not NaowhQOL.gcdTracker.stackOverlapping then
        return 0
    end
    local now = GetTime()
    local prev = GetNewestHistoryEntry()
    if prev and (now - prev.timestamp) <= CLUSTER_WINDOW then
        return prev.lane + 1
    end
    return 0
end

-- Compact recentSpells array, keeping only newest MAX_RECENT entries
local function CompactRecentSpells()
    local newSpells = {}
    local newIdx = 1
    local toKeep = math.min(recentValidCount, MAX_RECENT)
    local kept = 0

    -- Collect entries to keep (iterate backwards for newest first)
    local keepIndices = {}
    for i = recentNextIdx - 1, 1, -1 do
        if recentSpells[i] and kept < toKeep then
            keepIndices[#keepIndices + 1] = i
            kept = kept + 1
        end
    end

    -- Rebuild in chronological order (reverse the kept indices)
    wipe(recentSpellIdx)
    for i = #keepIndices, 1, -1 do
        local entry = recentSpells[keepIndices[i]]
        newSpells[newIdx] = entry
        recentSpellIdx[entry.spellId] = newIdx
        newIdx = newIdx + 1
    end

    wipe(recentSpells)
    for i = 1, newIdx - 1 do
        recentSpells[i] = newSpells[i]
    end

    recentNextIdx = newIdx
    recentValidCount = kept
end

local function TrackRecentSpell(spellId, icon)
    -- O(1) removal via index lookup instead of O(n) search
    local existingIdx = recentSpellIdx[spellId]
    if existingIdx then
        recentSpells[existingIdx] = nil
        recentValidCount = recentValidCount - 1
    end

    -- Add at end (O(1))
    recentSpells[recentNextIdx] = { spellId = spellId, icon = icon }
    recentSpellIdx[spellId] = recentNextIdx
    recentNextIdx = recentNextIdx + 1
    recentValidCount = recentValidCount + 1

    -- Compact when array gets sparse or exceeds capacity
    if recentValidCount > MAX_RECENT or recentNextIdx > MAX_RECENT * 3 then
        CompactRecentSpells()
    end
end

local function AddHistoryEntry(spellId, icon, casting, castGUID)
    local entry = {
        spellId = spellId, icon = icon,
        timestamp = GetTime(), lane = AssignLane(),
        casting = casting, failed = false, castGUID = castGUID,
    }
    HistoryPush(entry)
    if castGUID then castingLookup[castGUID] = entry end
    TrackRecentSpell(spellId, icon)
    return entry
end

local function OnCastStart(castGUID, spellId)
    local db = GetDB()
    if not db then return end
    if db.blocklist and db.blocklist[spellId] then return end
    local icon = GetSpellIcon(spellId)
    if icon then AddHistoryEntry(spellId, icon, true, castGUID) end
end

local function OnCastSucceeded(castGUID, spellId)
    local db = GetDB()
    if not db then return end

    local tracked = castGUID and castingLookup[castGUID]
    if tracked then
        tracked.casting = false
        castingLookup[castGUID] = nil
        recentCasts[spellId] = GetTime()
        return
    end

    if db.blocklist and db.blocklist[spellId] then return end

    local now = GetTime()
    local lastSeen = recentCasts[spellId]
    if lastSeen and (now - lastSeen) < DEDUP_WINDOW then return end
    recentCasts[spellId] = now

    local icon = GetSpellIcon(spellId)
    if icon then AddHistoryEntry(spellId, icon, false, nil) end
end

local function OnCastFailed(castGUID)
    if not GetDB() then return end
    local tracked = castGUID and castingLookup[castGUID]
    if tracked then
        tracked.casting = false
        tracked.failed = true
        castingLookup[castGUID] = nil
    end
end

-- Called from config panel changes
function container:UpdateDisplay()
    local db = NaowhQOL.gcdTracker
    if not db then return end

    if db.unlock then
        container:EnableMouse(true)
        container:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        container:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        container:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    else
        container:EnableMouse(false)
        container:SetBackdrop(nil)
    end

    if not container.posInitialized then
        container:ClearAllPoints()
        container:SetPoint(db.point or "CENTER", UIParent, db.point or "CENTER", db.x or 0, db.y or -100)
        container.posInitialized = true
    end

    local iconSize = db.iconSize or 32
    for _, f in pairs(activeIcons) do
        f:SetSize(iconSize, iconSize)
    end

    RefreshVisibility()
end

local function OnZoneChanged(zoneData)
    local db = NaowhQOL.gcdTracker
    if not db then return end
    local key = ZONE_DB_KEY[zoneData.instanceType] or "showInWorld"
    zoneAllowed = db[key] ~= false
    RefreshVisibility()
end

local eventFrame = CreateFrame("Frame", "NaowhQOL_GcdTrackerEvents")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        suppressUntil = GetTime() + 5
        -- Pre-allocate frame pools for better performance
        InitializeFramePools()
        local db = NaowhQOL.gcdTracker
        if db then
            W.MakeDraggable(container, {
                db = db, enableMouse = false, userPlaced = false,
            })
        end
        container.posInitialized = false
        container:UpdateDisplay()
        if ns.ZoneUtil and ns.ZoneUtil.RegisterCallback then
            ns.ZoneUtil.RegisterCallback("GcdTracker", OnZoneChanged)
            C_Timer.After(0.5, function()
                OnZoneChanged(ns.ZoneUtil.GetCurrentZone())
            end)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        suppressUntil = GetTime() + 5
    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        local db = NaowhQOL.gcdTracker
        -- Start ticker only if downtime summary is enabled
        if db and db.downtimeSummaryEnabled then
            combatStartTime = GetTime()
            totalDowntime = 0
            lastDowntimeStart = 0
            lastDowntimeActive = IsGCDActive() or IsCasting()
            if downtimeTicker then downtimeTicker:Cancel() end
            downtimeTicker = C_Timer.NewTicker(0.1, TrackDowntime)
        end
        RefreshVisibility()
    elseif event == "PLAYER_REGEN_ENABLED" then
        local db = NaowhQOL.gcdTracker

        -- Stop downtime ticker and print summary if enabled
        if downtimeTicker then
            downtimeTicker:Cancel()
            downtimeTicker = nil

            -- Finalize any pending downtime
            if lastDowntimeStart > 0 then
                totalDowntime = totalDowntime + (GetTime() - lastDowntimeStart)
            end

            local combatDuration = GetTime() - combatStartTime
            if db and db.downtimeSummaryEnabled and combatDuration > 15 then
                local downtimePct = (totalDowntime / combatDuration) * 100
                local msg = string.format("|cFFFFFF00[NaowhQOL]|r " .. L["GCD_DOWNTIME_MSG"], totalDowntime, downtimePct)
                print(msg)
            end
        end

        inCombat = false
        wipe(recentCasts)
        -- Close current segment but let existing ones fade naturally
        local lastSeg = SegmentGetNewest()
        if lastSeg and not lastSeg.endTime then
            lastSeg.endTime = GetTime()
        end
        lastActivityState = false
        RefreshVisibility()
    else
        local unit, castGUID, spellId = ...
        if unit ~= "player" then return end
        if GetTime() < suppressUntil then return end
        if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
            OnCastStart(castGUID, spellId)
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
            OnCastSucceeded(castGUID, spellId)
        elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
            OnCastFailed(castGUID)
        end
    end
end)

ns.GcdTrackerDisplay = container
ns.GcdTrackerRefreshVisibility = RefreshVisibility
-- Return compacted array for external consumers (sparse array safe)
ns.GetGcdTrackerRecentSpells = function()
    local result = {}
    for i = 1, recentNextIdx - 1 do
        if recentSpells[i] then
            result[#result + 1] = recentSpells[i]
        end
    end
    return result
end
ns.GcdTrackerRecentSpells = recentSpells  -- Keep for backwards compat
