local addonName, ns = ...
local L = ns.L
local W = ns.Widgets

-- Mouse ring cursor overlay with GCD tracking and trail effects

local ASSET_PATH = "Interface\\AddOns\\NaowhQOL\\Assets\\"
local RING_TEXEL = 0.5 / 256
local TRAIL_TEXEL = 0.5 / 128
local TRAIL_MAX = 20
local GCD_SPELL = 61304
local SWIPE_DELAY = 0.08  -- 80ms delay before showing swipes to avoid flicker
local floor, max = math.floor, math.max

local function GetDB()
    NaowhQOL = NaowhQOL or {}
    NaowhQOL.mouseRing = NaowhQOL.mouseRing or {}
    return NaowhQOL.mouseRing
end

--------------------------------------------------------------------------------
-- STATE (Event Manager sets these flags)
--------------------------------------------------------------------------------
local state = {
    inCombat = false,
    inInstance = false,
    isRightMouseDown = false,
    -- Cast/Channel state
    isCasting = false,
    isChanneling = false,
    castStart = 0,
    castEnd = 0,
    channelStart = 0,
    channelEnd = 0,
    -- GCD state
    gcdReady = true,
    gcdInfo = nil,  -- stores C_Spell.GetSpellCooldown result
    gcdSwipeAllowed = true,  -- false during delay period after GCD starts
    gcdDelayTimer = nil,  -- timer handle for swipe delay
    -- Cast/channel swipe delay
    castSwipeAllowed = false,  -- false during delay period after cast starts
    castDelayTimer = nil,  -- timer handle for cast swipe delay
}

--------------------------------------------------------------------------------
-- FRAMES
--------------------------------------------------------------------------------
local container, ring, gcdCooldown, readyRing
local trailContainer, trailPoints = nil, {}

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------
local UpdateMouseWatcher  -- forward declaration

local function ShouldBeVisible()
    local db = GetDB()
    if not db.enabled then return false end
    if db.hideOnMouseClick and state.isRightMouseDown then return false end
    if state.inCombat or state.inInstance then return true end
    return db.showOutOfCombat ~= false
end

local function GetOpacity()
    local db = GetDB()
    if state.inCombat or state.inInstance then
        return db.opacityInCombat or 1.0
    end
    return db.opacityOutOfCombat or 1.0
end

local function GetRingColor()
    local db = GetDB()
    return W.GetEffectiveColor(db, "colorR", "colorG", "colorB", "useClassColor")
end

local function SetupTexture(tex, shape)
    tex:SetTexture(ASSET_PATH .. shape, "CLAMP", "CLAMP", "TRILINEAR")
    tex:SetTexCoord(RING_TEXEL, 1 - RING_TEXEL, RING_TEXEL, 1 - RING_TEXEL)
    if tex.SetSnapToPixelGrid then
        tex:SetSnapToPixelGrid(false)
        tex:SetTexelSnappingBias(0)
    end
end

--------------------------------------------------------------------------------
-- RENDER MANAGER - Single source of truth for all visibility
--------------------------------------------------------------------------------
local function UpdateRender()
    if not container then return end
    local db = GetDB()
    local alpha = GetOpacity()

    -- Update mouse watcher state (must run regardless of visibility)
    UpdateMouseWatcher()

    -- Hide everything if not visible
    if not ShouldBeVisible() then
        container:Hide()
        if trailContainer then trailContainer:Hide() end
        return
    end

    container:Show()

    -- Layer 1: Background ring (always visible unless hideBackground)
    if ring then
        if db.hideBackground then
            ring:Hide()
        else
            ring:SetAlpha(alpha)
            ring:Show()
        end
    end

    -- Layer 2: Swipe (priority: cast > channel > gcd)
    if gcdCooldown then
        local swipeAlpha = alpha * (db.gcdAlpha or 1)

        if db.castSwipeEnabled and state.isCasting and state.castStart > 0 and state.castSwipeAllowed then
            -- Cast swipe (only after delay period to avoid flicker from failed casts)
            local r, g, b = db.castSwipeR or 1, db.castSwipeG or 0.66, db.castSwipeB or 0
            gcdCooldown:SetSwipeColor(r, g, b, swipeAlpha)
            gcdCooldown:SetCooldown(state.castStart, state.castEnd - state.castStart)
            gcdCooldown:Show()

        elseif db.castSwipeEnabled and state.isChanneling and state.channelStart > 0 and state.castSwipeAllowed then
            -- Channel swipe (only after delay period to avoid flicker)
            local r, g, b = db.castSwipeR or 1, db.castSwipeG or 0.66, db.castSwipeB or 0
            gcdCooldown:SetSwipeColor(r, g, b, swipeAlpha)
            gcdCooldown:SetCooldown(state.channelStart, state.channelEnd - state.channelStart)
            gcdCooldown:Show()

        elseif db.gcdEnabled and not state.gcdReady and state.gcdInfo and state.gcdSwipeAllowed then
            -- GCD swipe (only after delay period to avoid flicker with cast swipe)
            local r, g, b = db.gcdR or 0.004, db.gcdG or 0.56, db.gcdB or 0.91
            gcdCooldown:SetSwipeColor(r, g, b, swipeAlpha)
            gcdCooldown:SetCooldown(state.gcdInfo.startTime, state.gcdInfo.duration, state.gcdInfo.modRate)
            gcdCooldown:Show()

        else
            -- No swipe needed
            gcdCooldown:Hide()
        end
    end

    -- Layer 3: Ready ring (only when gcdReady + not casting/channeling)
    if readyRing then
        local showReady = db.gcdEnabled and state.gcdReady
                          and not state.isCasting and not state.isChanneling

        if showReady then
            -- Set ready ring color
            local readyR, readyG, readyB
            if db.gcdReadyMatchSwipe then
                readyR, readyG, readyB = db.gcdR or 0.004, db.gcdG or 0.56, db.gcdB or 0.91
            else
                readyR, readyG, readyB = db.gcdReadyR or 0, db.gcdReadyG or 0.8, db.gcdReadyB or 0.3
            end
            readyRing:SetVertexColor(readyR, readyG, readyB, 1)
            readyRing:SetAlpha(alpha)
            readyRing:Show()
        else
            readyRing:Hide()
        end
    end

    -- Trail visibility
    if trailContainer then
        if db.trailEnabled then
            trailContainer:Show()
        else
            trailContainer:Hide()
        end
    end
end

--------------------------------------------------------------------------------
-- FRAME CREATION
--------------------------------------------------------------------------------
local function CreateRing()
    if container then return end
    local db = GetDB()
    local size = db.size or 48
    if size % 2 == 1 then size = size + 1 end

    -- Container follows cursor
    container = CreateFrame("Frame", nil, UIParent)
    container:SetSize(size, size)
    container:SetFrameStrata("TOOLTIP")
    container:EnableMouse(false)

    -- Main ring texture (background)
    local shape = db.shape or "ring.tga"
    ring = container:CreateTexture(nil, "BORDER")
    ring:SetAllPoints()
    SetupTexture(ring, shape)
    local r, g, b = GetRingColor()
    ring:SetVertexColor(r, g, b, 1)

    -- GCD ready ring
    readyRing = container:CreateTexture(nil, "ARTWORK")
    readyRing:SetAllPoints()
    SetupTexture(readyRing, shape)
    readyRing:Hide()

    -- Cooldown swipe (used for GCD, cast, and channel)
    gcdCooldown = CreateFrame("Cooldown", nil, container, "CooldownFrameTemplate")
    gcdCooldown:SetAllPoints()
    gcdCooldown:SetDrawSwipe(true)
    gcdCooldown:SetDrawEdge(false)
    gcdCooldown:SetHideCountdownNumbers(true)
    gcdCooldown:SetReverse(true)
    gcdCooldown:SetSwipeTexture(ASSET_PATH .. shape)
    if gcdCooldown.SetDrawBling then gcdCooldown:SetDrawBling(false) end
    if gcdCooldown.SetUseCircularEdge then gcdCooldown:SetUseCircularEdge(true) end
    gcdCooldown:SetFrameLevel(container:GetFrameLevel() + 5)
    gcdCooldown:Hide()

    -- When cooldown animation finishes, GCD is ready
    gcdCooldown:SetScript("OnCooldownDone", function()
        state.gcdReady = true
        state.gcdInfo = nil
        UpdateRender()
    end)

    -- Cursor following
    local lastX, lastY = 0, 0
    container:SetScript("OnUpdate", function(self, elapsed)
        if not ShouldBeVisible() then return end

        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        x, y = floor(x / scale + 0.5), floor(y / scale + 0.5)

        if x ~= lastX or y ~= lastY then
            lastX, lastY = x, y
            self:ClearAllPoints()
            self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
        end
    end)

    UpdateRender()
end

local function CreateTrail()
    if trailContainer then return end

    trailContainer = CreateFrame("Frame", nil, UIParent)
    trailContainer:SetFrameStrata("TOOLTIP")
    trailContainer:SetFrameLevel(1)
    trailContainer:SetPoint("BOTTOMLEFT")
    trailContainer:SetSize(1, 1)

    for i = 1, TRAIL_MAX do
        local tex = trailContainer:CreateTexture(nil, "BACKGROUND")
        tex:SetTexture(ASSET_PATH .. "trail_glow.tga", "CLAMP", "CLAMP", "TRILINEAR")
        tex:SetTexCoord(TRAIL_TEXEL, 1 - TRAIL_TEXEL, TRAIL_TEXEL, 1 - TRAIL_TEXEL)
        tex:SetBlendMode("ADD")
        tex:SetSize(24, 24)
        tex:Hide()
        trailPoints[i] = { tex = tex, x = 0, y = 0, time = 0, active = false }
    end

    local head, lastX, lastY = 0, 0, 0
    local updateTimer = 0
    local activeCount = 0
    local trailUpdateFunc

    trailUpdateFunc = function(self, elapsed)
        local db = GetDB()
        local shouldTrack = db.trailEnabled and ShouldBeVisible()

        updateTimer = updateTimer + elapsed
        if updateTimer < 0.025 then return end
        updateTimer = 0

        local now = GetTime()

        -- Only track new points when enabled and visible
        if shouldTrack then
            local x, y = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            x, y = floor(x / scale + 0.5), floor(y / scale + 0.5)

            local dx, dy = x - lastX, y - lastY

            -- Add new point if moved enough
            if dx * dx + dy * dy >= 4 then
                lastX, lastY = x, y
                head = (head % TRAIL_MAX) + 1
                local pt = trailPoints[head]
                if not pt.active then
                    activeCount = activeCount + 1
                end
                pt.x, pt.y, pt.time, pt.active = x, y, now, true
            end
        end

        -- Update existing points (always, to let them fade out)
        if activeCount > 0 then
            local duration = max(db.trailDuration or 0.6, 0.1)
            local tr, tg, tb = db.trailR or 1, db.trailG or 1, db.trailB or 1
            local opacity = GetOpacity()

            for i = 1, TRAIL_MAX do
                local pt = trailPoints[i]
                if pt.active then
                    local fade = 1 - (now - pt.time) / duration
                    if fade <= 0 then
                        pt.active = false
                        pt.tex:Hide()
                        activeCount = activeCount - 1
                    else
                        pt.tex:ClearAllPoints()
                        pt.tex:SetPoint("CENTER", UIParent, "BOTTOMLEFT", pt.x, pt.y)
                        pt.tex:SetVertexColor(tr, tg, tb, fade * opacity * 0.8)
                        pt.tex:SetSize(24 * fade, 24 * fade)
                        pt.tex:Show()
                    end
                end
            end
        end

        -- Stop updates when disabled and all points faded
        if not shouldTrack and activeCount == 0 then
            self:SetScript("OnUpdate", nil)
        end
    end

    -- Start/stop trail updates based on visibility
    trailContainer:SetScript("OnShow", function(self)
        self:SetScript("OnUpdate", trailUpdateFunc)
    end)
    trailContainer:SetScript("OnHide", function(self)
        -- Let fade complete, OnUpdate will self-stop when activeCount reaches 0
        if activeCount == 0 then
            self:SetScript("OnUpdate", nil)
        end
    end)
end

--------------------------------------------------------------------------------
-- EVENT MANAGER - Only updates state flags, then calls UpdateRender()
--------------------------------------------------------------------------------
local function RefreshCombatState()
    state.inCombat = InCombatLockdown() or UnitAffectingCombat("player")
    local inInst, instType = IsInInstance()
    state.inInstance = inInst and (instType == "party" or instType == "raid" or instType == "pvp" or instType == "arena")
end

-- Right mouse button watcher (conditional - only runs when enabled and hideOnMouseClick is on)
local mouseWatcher = CreateFrame("Frame")
local mouseWatcherActive = false

local function MouseWatcherOnUpdate()
    local wasDown = state.isRightMouseDown
    state.isRightMouseDown = IsMouseButtonDown("RightButton")

    if wasDown ~= state.isRightMouseDown then
        UpdateRender()
    end
end

UpdateMouseWatcher = function()
    local db = GetDB()
    local shouldRun = db.enabled and db.hideOnMouseClick

    if shouldRun and not mouseWatcherActive then
        mouseWatcher:SetScript("OnUpdate", MouseWatcherOnUpdate)
        mouseWatcherActive = true
    elseif not shouldRun and mouseWatcherActive then
        mouseWatcher:SetScript("OnUpdate", nil)
        state.isRightMouseDown = false
        mouseWatcherActive = false
    end
end

-- Main event handler
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
events:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")

events:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        RefreshCombatState()
        CreateRing()
        CreateTrail()
        UpdateRender()

    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        RefreshCombatState()
        UpdateRender()

    elseif event == "UNIT_SPELLCAST_START" then
        local _, _, _, startTime, endTime = UnitCastingInfo("player")
        if startTime and endTime then
            state.isCasting = true
            state.castStart = startTime / 1000
            state.castEnd = endTime / 1000
            -- Delay showing cast swipe to avoid flicker from failed casts
            state.castSwipeAllowed = false
            if state.castDelayTimer then
                state.castDelayTimer:Cancel()
            end
            state.castDelayTimer = C_Timer.NewTimer(SWIPE_DELAY, function()
                state.castSwipeAllowed = true
                state.castDelayTimer = nil
                UpdateRender()
            end)
        end
        UpdateRender()

    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        local _, _, _, startTime, endTime = UnitChannelInfo("player")
        if startTime and endTime then
            state.isChanneling = true
            state.channelStart = startTime / 1000
            state.channelEnd = endTime / 1000
            -- Delay showing channel swipe to avoid flicker
            state.castSwipeAllowed = false
            if state.castDelayTimer then
                state.castDelayTimer:Cancel()
            end
            state.castDelayTimer = C_Timer.NewTimer(SWIPE_DELAY, function()
                state.castSwipeAllowed = true
                state.castDelayTimer = nil
                UpdateRender()
            end)
        end
        UpdateRender()

    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        -- Only clear cast state if we were actually casting
        if state.isCasting then
            state.isCasting = false
            state.castStart = 0
            state.castEnd = 0
            -- Cancel delay timer and reset
            if state.castDelayTimer then
                state.castDelayTimer:Cancel()
                state.castDelayTimer = nil
            end
            state.castSwipeAllowed = false
        end
        -- Check if channel is still active
        local _, _, _, startTime, endTime = UnitChannelInfo("player")
        if startTime and endTime then
            state.isChanneling = true
            state.channelStart = startTime / 1000
            state.channelEnd = endTime / 1000
        end
        UpdateRender()

    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        state.isChanneling = false
        state.channelStart = 0
        state.channelEnd = 0
        -- Cancel delay timer and reset
        if state.castDelayTimer then
            state.castDelayTimer:Cancel()
            state.castDelayTimer = nil
        end
        state.castSwipeAllowed = false
        UpdateRender()

    elseif event == "SPELL_UPDATE_COOLDOWN" then
        local db = GetDB()
        if not db.gcdEnabled then return end

        local info = C_Spell.GetSpellCooldown(GCD_SPELL)
        if info and info.duration and info.duration > 0 then
            -- GCD is active
            local wasReady = state.gcdReady
            state.gcdInfo = info
            state.gcdReady = false

            -- If GCD just started, delay showing swipe to avoid flicker with cast swipe
            if wasReady then
                state.gcdSwipeAllowed = false
                if state.gcdDelayTimer then
                    state.gcdDelayTimer:Cancel()
                end
                state.gcdDelayTimer = C_Timer.NewTimer(SWIPE_DELAY, function()
                    state.gcdSwipeAllowed = true
                    state.gcdDelayTimer = nil
                    UpdateRender()
                end)
            end
        else
            -- GCD is not active (duration is 0 or nil)
            state.gcdReady = true
            state.gcdInfo = nil
            state.gcdSwipeAllowed = true
            if state.gcdDelayTimer then
                state.gcdDelayTimer:Cancel()
                state.gcdDelayTimer = nil
            end
        end
        UpdateRender()
    end
end)

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------
local MouseRingDisplay = {}

function MouseRingDisplay:UpdateDisplay()
    CreateRing()
    CreateTrail()

    local db = GetDB()
    local shape = db.shape or "ring.tga"
    local size = db.size or 48
    if size % 2 == 1 then size = size + 1 end

    if container then container:SetSize(size, size) end
    if ring then
        SetupTexture(ring, shape)
        local r, g, b = GetRingColor()
        ring:SetVertexColor(r, g, b, 1)
    end
    if readyRing then SetupTexture(readyRing, shape) end
    if gcdCooldown then gcdCooldown:SetSwipeTexture(ASSET_PATH .. shape) end

    UpdateRender()
end

function MouseRingDisplay:UpdateSize(size)
    GetDB().size = size
    if size % 2 == 1 then size = size + 1 end
    if container then container:SetSize(size, size) end
end

function MouseRingDisplay:UpdateColor(r, g, b)
    local db = GetDB()
    db.colorR, db.colorG, db.colorB = r, g, b
    if ring then ring:SetVertexColor(r, g, b, 1) end
end

function MouseRingDisplay:UpdateShape(shape)
    GetDB().shape = shape
    if ring then SetupTexture(ring, shape) end
    if readyRing then SetupTexture(readyRing, shape) end
    if gcdCooldown then gcdCooldown:SetSwipeTexture(ASSET_PATH .. shape) end
end

function MouseRingDisplay:RefreshGCD()
    UpdateRender()
end

function MouseRingDisplay:RefreshVisibility()
    RefreshCombatState()
    UpdateRender()
end

ns.MouseRingDisplay = MouseRingDisplay
