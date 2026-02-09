local addonName, ns = ...
local L = ns.L

local cache = {}
local W = ns.Widgets
local C = ns.COLORS

local ASSET_PATH       = "Interface\\AddOns\\NaowhQOL\\Assets\\"
local CAST_SEGMENTS    = 36
local TRAIL_MAX_POINTS = 20
local RING_TEXEL_HALF  = 0.5 / 256
local TRAIL_TEXEL_HALF = 0.5 / 128
local floor = math.floor
local GCD_SPELL_ID     = 61304

-- Size multipliers
local CAST_OVERLAY_INITIAL_SCALE = 0.01   -- Cast overlay starting scale
local TRAIL_BASE_SIZE            = 48     -- Fixed base size for trail (independent of ring)
local TRAIL_SIZE_MULTIPLIER      = 0.5    -- Trail glow size relative to base
local TRAIL_FADE_MULTIPLIER      = 0.4    -- Trail fade size multiplier
local TRAIL_MAX_ALPHA            = 0.8    -- Maximum trail point alpha

local ringShapes = {
    { text = L["MOUSE_SHAPE_CIRCLE"], value = "ring.tga" },
    { text = L["MOUSE_SHAPE_THIN"],   value = "thin_ring.tga" },
    { text = L["MOUSE_SHAPE_THICK"],  value = "thick_ring.tga" },
}

local function Clamp(val, min, max)
    if val < min then return min elseif val > max then return max end
    return val
end

local function Clamp01(v)
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function GetSpecKey()
    local specIndex = GetSpecialization()
    if not specIndex then return "NoSpec" end
    local _, specName = GetSpecializationInfo(specIndex)
    return specName or ("Spec" .. specIndex)
end

local function GetSpecSettings()
    NaowhQOL = NaowhQOL or {}
    NaowhQOL.CursorTracker = NaowhQOL.CursorTracker or {}
    local key = GetSpecKey()
    NaowhQOL.CursorTracker[key] = NaowhQOL.CursorTracker[key] or {}
    return NaowhQOL.CursorTracker[key]
end

local settings = {
    enabled = true,
    size = 48,
    shape = "ring.tga",
    color = nil,
    showOutOfCombat = true,
    opacityInCombat = 1.0,
    opacityOutOfCombat = 1.0,
    trailEnabled = false,
    trailDuration = 0.6,
    trailColor = { r = 1.0, g = 1.0, b = 1.0 },
    gcdEnabled = true,
    gcdColor = nil,
    gcdReadyColor = { r = 0.0, g = 0.8, b = 0.3 },
    gcdReadyMatchSwipe = false,
    gcdAlpha = 1.0,
    hideOnMouseClick = false,
    hideBackground = false,
    castSwipeEnabled = true,
    castSwipeColor = { r = 1.0, g = 0.66, b = 0.0 },
    -- Internal settings (not exposed in UI)
    castAnimation = "ring",
    castColor = { r = 1.0, g = 0.66, b = 0.0 },
}

local function LoadSettings()
    local db = GetSpecSettings()

    -- Use explicit nil checks to correctly handle boolean false values
    settings.enabled = db.enabled == nil and true or db.enabled
    settings.size = (db.size ~= nil) and db.size or 48
    settings.shape = db.shape or "ring.tga"
    settings.showOutOfCombat = db.showOutOfCombat == nil and true or db.showOutOfCombat

    settings.opacityInCombat = (db.opacityInCombat ~= nil) and db.opacityInCombat or 1.0
    settings.opacityOutOfCombat = (db.opacityOutOfCombat ~= nil) and db.opacityOutOfCombat or 1.0

    settings.color = db.color or { r = 1.0, g = 0.66, b = 0.0 }

    settings.trailEnabled = db.trailEnabled or false
    settings.trailDuration = (db.trailDuration ~= nil) and db.trailDuration or 0.6
    settings.trailColor = db.trailColor or { r = 1.0, g = 1.0, b = 1.0 }

    settings.gcdEnabled = db.gcdEnabled == nil and true or db.gcdEnabled
    settings.gcdColor = db.gcdColor or { r = 0.004, g = 0.56, b = 0.91 }
    settings.gcdReadyColor = db.gcdReadyColor or { r = 0.0, g = 0.8, b = 0.3 }
    settings.gcdReadyMatchSwipe = db.gcdReadyMatchSwipe or false
    settings.gcdAlpha = (db.gcdAlpha ~= nil) and db.gcdAlpha or 1.0

    settings.hideOnMouseClick = db.hideOnMouseClick or false
    settings.hideBackground = db.hideBackground or false

    settings.castSwipeEnabled = db.castSwipeEnabled == nil and true or db.castSwipeEnabled
    settings.castSwipeColor = db.castSwipeColor or { r = 1.0, g = 0.66, b = 0.0 }

    -- Only write keys that don't exist to avoid stale key accumulation
    for k, v in pairs(settings) do
        if db[k] == nil then
            db[k] = v
        end
    end
end

local function SaveSettings()
    local db = GetSpecSettings()
    for k, v in pairs(settings) do
        db[k] = v
    end
end

-- Debounced save for slider controls to avoid disk writes during drag
local saveTimer = nil
local function DebouncedSave()
    if saveTimer then saveTimer:Cancel() end
    saveTimer = C_Timer.NewTimer(0.3, function()
        SaveSettings()
        saveTimer = nil
    end)
end

-- Move cached variable declarations before their usage
local cachedCombat = false
local cachedInstance = false

local function RefreshCombatCache()
    cachedCombat = InCombatLockdown() or UnitAffectingCombat("player")
    local inInst, instType = IsInInstance()
    cachedInstance = inInst and (instType == "party" or instType == "raid"
        or instType == "pvp" or instType == "arena" or instType == "scenario")
end

local function ShouldShow()
    if cachedCombat or cachedInstance then return true end
    return settings.showOutOfCombat
end

local function GetCurrentOpacity()
    return (cachedCombat or cachedInstance) and settings.opacityInCombat or settings.opacityOutOfCombat
end

ns.Frames = ns.Frames or {}
local frames = ns.Frames
frames.mainRing = nil
frames.castOverlay = nil
frames.castSegments = nil
frames.gcdCooldown = nil
frames.gcdReadyRing = nil
frames.trailContainer = nil

local isCasting = false
local trailActive = false
local castTicker = nil
local gcdActive = false
local isRightMouseDown = false
local gcdDelayTimer = nil
local GCD_SHOW_DELAY = 0.07  -- 70ms delay to prevent flash when cast starts

-- Forward declarations for cast ticker functions
local StartCastTicker, StopCastTicker
local UpdateMouseWatcher

local trailBuf = {}
local trailHead = 0
local trailCount = 0
local trailUpdateTimer = 0
local lastTrailX, lastTrailY = 0, 0
local lastRingX, lastRingY = 0, 0
local TRAIL_UPDATE_INTERVAL = 0.025  -- 40Hz throttle
local TRAIL_MOVE_THRESHOLD_SQ = 4    -- 2 pixels squared
for idx = 1, TRAIL_MAX_POINTS do
    trailBuf[idx] = { x = 0, y = 0, time = 0, tex = nil, active = false, lastSize = 0 }
end

local function FetchCooldownData(spellID)
    if C_Spell and C_Spell.GetSpellCooldown then
        local result = C_Spell.GetSpellCooldown(spellID)
        if type(result) == "table" then
            return result.startTime or result.start, result.duration, result.modRate
        else
            -- Fallback for older WoW versions (dead code in TWW)
            local s, d, e, m = C_Spell.GetSpellCooldown(spellID)
            return s, d, m
        end
    end
    if GetSpellCooldown then
        local s, d = GetSpellCooldown(spellID)
        return s, d, nil
    end
end

local function CheckCooldownState(start, dur)
    -- WoW can return "secret" values in protected contexts, use pcall to safely compare
    local ok, result = pcall(function()
        return (dur or 0) > 0 and (start or 0) > 0
    end)
    return ok and result
end

local function CalculateSwipeOpacity()
    return Clamp01(settings.gcdAlpha * GetCurrentOpacity())
end

local function ApplySwipeColor(forCast)
    if not frames.gcdCooldown then return end
    local c
    if forCast then
        c = settings.castSwipeColor or { r = 1.0, g = 0.66, b = 0.0 }
    else
        c = settings.gcdColor or { r = 0.0, g = 0.56, b = 0.91 }
    end
    local opacity = CalculateSwipeOpacity()
    frames.gcdCooldown:SetSwipeColor(c.r, c.g, c.b, opacity)
end

-- Stop cast ticker and clean up visuals
StopCastTicker = function()
    if castTicker then
        castTicker:Cancel()
        castTicker = nil
    end
    isCasting = false
    ApplySwipeColor(false)
    if frames.castOverlay then
        frames.castOverlay:SetAlpha(0)
        frames.castOverlay:SetSize(settings.size * CAST_OVERLAY_INITIAL_SCALE, settings.size * CAST_OVERLAY_INITIAL_SCALE)
    end
    if frames.castSegments then
        for i = 1, CAST_SEGMENTS do
            if frames.castSegments[i] then
                frames.castSegments[i]:SetVertexColor(settings.castColor.r, settings.castColor.g, settings.castColor.b, 0)
            end
        end
    end
    -- Show GCD ready ring if GCD is already done and ring should be visible
    if not gcdActive and settings.enabled and settings.gcdEnabled and ShouldShow() and frames.gcdReadyRing then
        frames.gcdReadyRing:Show()
    end
end

-- Start cast/channel progress ticker (only runs while casting)
StartCastTicker = function()
    if castTicker then return end
    castTicker = C_Timer.NewTicker(0.033, function()
        if not settings.enabled then return end
        if settings.hideOnMouseClick and isRightMouseDown then return end

        local now = GetTime()
        local progress = 0
        local casting, _, _, castStart, castEnd = UnitCastingInfo("player")
        local channeling, _, _, chanStart, chanEnd = UnitChannelInfo("player")

        if casting then
            progress = (now - (castStart / 1000)) / ((castEnd - castStart) / 1000)
        elseif channeling then
            progress = 1 - ((now - (chanStart / 1000)) / ((chanEnd - chanStart) / 1000))
        else
            -- Cast/channel ended, stop ticker
            StopCastTicker()
            return
        end

        progress = Clamp(progress, 0, 1)
        local visible = ShouldShow()

        if settings.castAnimation == "fill" and frames.castOverlay then
            frames.castOverlay:SetAlpha(visible and progress > 0 and 1 or 0)
            local sz = settings.size * math.max(progress, 0.01)
            frames.castOverlay:SetSize(sz, sz)
        end

        if (settings.castAnimation == "ring" or settings.castAnimation == "wedge") and frames.castSegments then
            local lit = math.floor(progress * CAST_SEGMENTS + 0.5)
            for i = 1, CAST_SEGMENTS do
                if frames.castSegments[i] then
                    frames.castSegments[i]:SetVertexColor(
                        settings.castColor.r, settings.castColor.g, settings.castColor.b,
                        visible and (i <= lit) and 1 or 0)
                end
            end
        end
    end)
end

local function RefreshGCDAppearance()
    if not frames.gcdCooldown then return end

    if not settings.gcdEnabled then
        frames.gcdCooldown:Hide()
        if frames.gcdReadyRing then frames.gcdReadyRing:Hide() end
        gcdActive = false
        if frames.mainRing and not settings.hideBackground then frames.mainRing:Show() end
        return
    end

    local texturePath = ASSET_PATH .. settings.shape
    frames.gcdCooldown:SetSwipeTexture(texturePath)

    local opacity = CalculateSwipeOpacity()
    local r, g, b = settings.gcdColor.r, settings.gcdColor.g, settings.gcdColor.b

    frames.gcdCooldown:SetDrawEdge(false)
    frames.gcdCooldown:SetSwipeColor(r, g, b, opacity)

    -- Update GCD ready ring color and shape
    if frames.gcdReadyRing then
        frames.gcdReadyRing:SetTexture(ASSET_PATH .. settings.shape, "CLAMP", "CLAMP", "TRILINEAR")
        local rc
        if settings.gcdReadyMatchSwipe then
            rc = settings.gcdColor or { r = 0.004, g = 0.56, b = 0.91 }
        else
            rc = settings.gcdReadyColor or { r = 0.0, g = 0.8, b = 0.3 }
        end
        frames.gcdReadyRing:SetVertexColor(rc.r, rc.g, rc.b, opacity)
    end
end

local function ProcessGCDUpdate()
    -- Cancel any pending delayed show
    if gcdDelayTimer then
        gcdDelayTimer:Cancel()
        gcdDelayTimer = nil
    end

    if not frames.gcdCooldown or not settings.gcdEnabled or not settings.enabled then
        if frames.gcdCooldown then
            frames.gcdCooldown:Hide()
            gcdActive = false
            if frames.mainRing and settings.enabled and not settings.hideBackground and ShouldShow() then
                frames.mainRing:Show()
            end
        end
        return
    end

    -- Don't show GCD elements when ring shouldn't be visible
    if not ShouldShow() then
        frames.gcdCooldown:Hide()
        gcdActive = false
        if frames.gcdReadyRing then frames.gcdReadyRing:Hide() end
        return
    end

    -- Don't override cast swipe with GCD (check API directly)
    if settings.castSwipeEnabled and (UnitCastingInfo("player") or UnitChannelInfo("player")) then return end

    local start, duration, modRate = FetchCooldownData(GCD_SPELL_ID)
    if CheckCooldownState(start, duration) then
        -- Delay showing GCD to let cast events register first
        gcdDelayTimer = C_Timer.NewTimer(GCD_SHOW_DELAY, function()
            gcdDelayTimer = nil
            -- Re-check if we're now casting (cast event may have fired during delay)
            if settings.castSwipeEnabled and (UnitCastingInfo("player") or UnitChannelInfo("player")) then
                return
            end
            if not frames.gcdCooldown then return end
            -- Re-check visibility in case it changed during delay
            if not ShouldShow() then return end

            -- Hide ready ring when new GCD starts
            if frames.gcdReadyRing then
                frames.gcdReadyRing:Hide()
            end
            frames.gcdCooldown:Show()
            gcdActive = true
            if frames.mainRing and not settings.hideBackground then
                frames.mainRing:Show()
            end
            if modRate then
                frames.gcdCooldown:SetCooldown(start, duration, modRate)
            else
                frames.gcdCooldown:SetCooldown(start, duration)
            end
        end)
    else
        frames.gcdCooldown:Hide()
        gcdActive = false
        if frames.mainRing and settings.enabled and not settings.hideBackground and ShouldShow() then
            frames.mainRing:Show()
        end
    end
end

local function UpdateVisibility()
    if not frames.mainRing then return end

    if not settings.enabled then
        frames.mainRing:Hide()
        if frames.gcdCooldown then frames.gcdCooldown:Hide() end
        if frames.gcdReadyRing then frames.gcdReadyRing:Hide() end
        if frames.castOverlay then frames.castOverlay:Hide() end
        if frames.castSegments then
            for i = 1, CAST_SEGMENTS do
                if frames.castSegments[i] then
                    frames.castSegments[i]:Hide()
                end
            end
        end
        gcdActive = false
        isCasting = false
        if castTicker then
            castTicker:Cancel()
            castTicker = nil
        end
        return
    end

    if settings.hideOnMouseClick and isRightMouseDown then
        frames.mainRing:Hide()
        if frames.gcdCooldown then frames.gcdCooldown:Hide() end
        if frames.gcdReadyRing then frames.gcdReadyRing:Hide() end
        if frames.castOverlay then
            frames.castOverlay:SetAlpha(0)
        end
        if frames.castSegments then
            for i = 1, CAST_SEGMENTS do
                if frames.castSegments[i] then
                    frames.castSegments[i]:SetVertexColor(settings.castColor.r, settings.castColor.g, settings.castColor.b, 0)
                end
            end
        end
        return
    end

    local show = ShouldShow()

    -- Hide GCD ready ring when not visible
    if frames.gcdReadyRing then
        if not show then
            frames.gcdReadyRing:Hide()
        end
    end

    if settings.hideBackground then
        frames.mainRing:Hide()
    else
        frames.mainRing:SetShown(show and not gcdActive)
        if show then frames.mainRing:SetAlpha(GetCurrentOpacity()) end
    end
end

-- Forward declaration for trail frame creation
local CreateTrailFrame

local function UpdateTrailVisibility()
    if not settings.enabled then
        trailActive = false
        for i = 1, TRAIL_MAX_POINTS do
            local pt = trailBuf[i]
            if pt.active then
                pt.active = false
                if pt.tex then pt.tex:Hide() end
            end
        end
        return
    end

    if settings.hideOnMouseClick and isRightMouseDown then
        for i = 1, TRAIL_MAX_POINTS do
            local pt = trailBuf[i]
            if pt.active and pt.tex then
                pt.tex:Hide()
            end
        end
        return
    end

    -- Create trail frame on-demand when enabling
    if settings.trailEnabled and not frames.trailContainer then
        CreateTrailFrame()
        -- Reset trail position to current cursor
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        lastTrailX, lastTrailY = x / scale, y / scale
    end

    trailActive = settings.trailEnabled and ShouldShow()
    local a = GetCurrentOpacity()
    for i = 1, TRAIL_MAX_POINTS do
        local pt = trailBuf[i]
        if pt.active and pt.tex then
            pt.tex:SetAlpha(trailActive and a or 0)
        end
    end
end

-- Forward declarations to avoid nil references
local CreateCursorFrame
local UpdateCastAnimation

local function UpdateSize(size)
    settings.size = size
    SaveSettings()

    if frames.mainRing and frames.mainRing:GetParent() then
        local parent = frames.mainRing:GetParent()

        local script = parent:GetScript("OnUpdate")
        if not script then
            parent:Hide()

            if castTicker then
                castTicker:Cancel()
                castTicker = nil
            end

            frames.mainRing = nil
            frames.castOverlay = nil
            frames.castSegments = nil
            frames.gcdCooldown = nil
            gcdActive = false
            isCasting = false

            CreateCursorFrame()
            UpdateCastAnimation(settings.castAnimation)
            UpdateVisibility()
            RefreshGCDAppearance()
            return
        end

        local sz = size
        if sz % 2 == 1 then sz = sz + 1 end
        parent:SetSize(sz, sz)

        if frames.castOverlay then
            frames.castOverlay:SetSize(sz * CAST_OVERLAY_INITIAL_SCALE, sz * CAST_OVERLAY_INITIAL_SCALE)
        end
    end
end

local function UpdateColor(r, g, b)
    settings.color = { r = r, g = g, b = b }
    SaveSettings()
    if frames.mainRing then frames.mainRing:SetVertexColor(r, g, b, 1) end
end

-- Changed from 'local function' to assignment to respect forward declaration
-- Using texture pool to prevent texture leak
UpdateCastAnimation = function(animation)
    settings.castAnimation = animation
    SaveSettings()

    if not frames.mainRing or not frames.mainRing:GetParent() then return end
    local parent = frames.mainRing:GetParent()

    -- Instead of destroying and recreating, simply hide/reconfigure existing segments
    if frames.castSegments then
        for i = 1, CAST_SEGMENTS do
            if frames.castSegments[i] then
                frames.castSegments[i]:Hide()
            end
        end
    end
    
    -- If segments don't exist, create them once
    if not frames.castSegments or #frames.castSegments == 0 then
        frames.castSegments = {}
        for i = 1, CAST_SEGMENTS do
            local seg = parent:CreateTexture(nil, "BACKGROUND")
            seg:SetAllPoints()
            seg:SetRotation(math.rad((i - 1) * (360 / CAST_SEGMENTS)))
            seg:SetVertexColor(1, 1, 1, 0)
            seg:SetTexCoord(RING_TEXEL_HALF, 1 - RING_TEXEL_HALF, RING_TEXEL_HALF, 1 - RING_TEXEL_HALF)
            if seg.SetSnapToPixelGrid then
                seg:SetSnapToPixelGrid(false)
                seg:SetTexelSnappingBias(0)
            end
            frames.castSegments[i] = seg
        end
    end

    -- Update texture based on animation type
    local texture
    if animation == "fill" then
        texture = ASSET_PATH .. settings.shape
    elseif animation == "wedge" then
        texture = ASSET_PATH .. "cast_wedge.tga"
    else
        texture = ASSET_PATH .. "cast_segment.tga"
    end

    -- Reuse existing textures, only change their texture and properties
    for i = 1, CAST_SEGMENTS do
        if frames.castSegments[i] then
            frames.castSegments[i]:SetTexture(texture, "CLAMP", "CLAMP", "TRILINEAR")
            frames.castSegments[i]:SetTexCoord(RING_TEXEL_HALF, 1 - RING_TEXEL_HALF, RING_TEXEL_HALF, 1 - RING_TEXEL_HALF)
        end
    end

    if animation == "fill" and frames.castOverlay then
        frames.castOverlay:Show()
        frames.castOverlay:SetVertexColor(settings.castColor.r, settings.castColor.g, settings.castColor.b, 1)
    end
end

local function UpdateShape(shapeFile)
    settings.shape = shapeFile
    if frames.mainRing then
        frames.mainRing:SetTexture(ASSET_PATH .. shapeFile, "CLAMP", "CLAMP", "TRILINEAR")
        frames.mainRing:SetTexCoord(RING_TEXEL_HALF, 1 - RING_TEXEL_HALF, RING_TEXEL_HALF, 1 - RING_TEXEL_HALF)
    end
    if frames.castOverlay then
        frames.castOverlay:SetTexture(ASSET_PATH .. shapeFile, "CLAMP", "CLAMP", "TRILINEAR")
        frames.castOverlay:SetTexCoord(RING_TEXEL_HALF, 1 - RING_TEXEL_HALF, RING_TEXEL_HALF, 1 - RING_TEXEL_HALF)
    end
    SaveSettings()
    if settings.castAnimation == "fill" then
        UpdateCastAnimation(settings.castAnimation)
    end
    RefreshGCDAppearance()
end

local function OpenColorPicker(currentRGB, callback)
    local info = {
        swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            callback(r, g, b)
        end,
        cancelFunc = function(previousValues)
            callback(previousValues.r, previousValues.g, previousValues.b)
        end,
        r = currentRGB.r, g = currentRGB.g, b = currentRGB.b,
        hasOpacity = false,
        previousValues = { r = currentRGB.r, g = currentRGB.g, b = currentRGB.b }
    }
    ColorPickerFrame:SetupColorPickerAndShow(info)
end

local function CreateColorButton(parent, label, configKey, x, yOffset, callback)
    local btn = W:CreateButton(parent, { text = L["COMMON_LABEL_COLOR"], width = 70, height = 20 })
    btn:SetPoint("TOPLEFT", x or 230, yOffset)

    local swatch = parent:CreateTexture(nil, "OVERLAY")
    swatch:SetSize(16, 16)
    swatch:SetPoint("LEFT", btn, "RIGHT", 8, 0)
    swatch:SetColorTexture(settings[configKey].r, settings[configKey].g, settings[configKey].b, 1)

    local border = parent:CreateTexture(nil, "BACKGROUND")
    border:SetPoint("TOPLEFT", swatch, -1, 1)
    border:SetPoint("BOTTOMRIGHT", swatch, 1, -1)
    border:SetColorTexture(0.5, 0.5, 0.5, 1)

    btn:SetScript("OnClick", function()
        OpenColorPicker(settings[configKey], function(r, g, b)
            settings[configKey] = { r = r, g = g, b = b }
            swatch:SetColorTexture(r, g, b, 1)
            SaveSettings()
            if callback then callback(r, g, b) end
        end)
    end)

    return btn, swatch, border
end

-- Helper: Create ring texture with proper settings
local function CreateRingTexture(container)
    local tex = container:CreateTexture(nil, "BORDER")
    tex:SetTexture(ASSET_PATH .. settings.shape, "CLAMP", "CLAMP", "TRILINEAR")
    tex:SetAllPoints()
    tex:SetVertexColor(settings.color.r, settings.color.g, settings.color.b, 1)
    tex:SetTexCoord(RING_TEXEL_HALF, 1 - RING_TEXEL_HALF, RING_TEXEL_HALF, 1 - RING_TEXEL_HALF)
    if tex.SetSnapToPixelGrid then
        tex:SetSnapToPixelGrid(false)
        tex:SetTexelSnappingBias(0)
    end
    return tex
end

-- Helper: Create GCD ready ring (shows when GCD complete)
local function CreateGCDReadyRing(container)
    local tex = container:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(ASSET_PATH .. settings.shape, "CLAMP", "CLAMP", "TRILINEAR")
    tex:SetAllPoints()
    local c
    if settings.gcdReadyMatchSwipe then
        c = settings.gcdColor or { r = 0.004, g = 0.56, b = 0.91 }
    else
        c = settings.gcdReadyColor or { r = 0.0, g = 0.8, b = 0.3 }
    end
    tex:SetVertexColor(c.r, c.g, c.b, 1)
    tex:SetTexCoord(RING_TEXEL_HALF, 1 - RING_TEXEL_HALF, RING_TEXEL_HALF, 1 - RING_TEXEL_HALF)
    if tex.SetSnapToPixelGrid then
        tex:SetSnapToPixelGrid(false)
        tex:SetTexelSnappingBias(0)
    end
    tex:Hide()
    return tex
end

-- Helper: Create GCD cooldown frame
local function CreateGCDCooldown(container)
    local cd = CreateFrame("Cooldown", nil, container, "CooldownFrameTemplate")
    cd:SetAllPoints()
    cd:EnableMouse(false)
    cd:SetDrawSwipe(true)
    cd:SetDrawEdge(false)
    cd:SetHideCountdownNumbers(true)
    cd:SetReverse(true)
    if cd.SetDrawBling then
        cd:SetDrawBling(false)
    end
    if cd.SetUseCircularEdge then
        cd:SetUseCircularEdge(true)
    end

    -- Disable pixel snapping for smoother rendering
    if cd.SetSnapToPixelGrid then
        cd:SetSnapToPixelGrid(false)
        cd:SetTexelSnappingBias(0)
    end

    cd:SetFrameStrata("TOOLTIP")
    cd:SetFrameLevel(container:GetFrameLevel() + 5)
    cd:Hide()

    cd:SetScript("OnCooldownDone", function()
        gcdActive = false
        if not settings.enabled or isCasting or not ShouldShow() then return end

        -- Prefer GCD ready ring when GCD is enabled
        if frames.gcdReadyRing and settings.gcdEnabled then
            frames.gcdReadyRing:Show()
        elseif frames.mainRing and not settings.hideBackground then
            frames.mainRing:Show()
        end
    end)
    return cd
end

-- Helper: Create cast segment textures
local function CreateCastSegments(container)
    local segments = {}
    for i = 1, CAST_SEGMENTS do
        local seg = container:CreateTexture(nil, "ARTWORK")
        seg:SetTexture(ASSET_PATH .. "cast_segment.tga", "CLAMP", "CLAMP", "TRILINEAR")
        seg:SetAllPoints()
        seg:SetRotation(math.rad((i - 1) * (360 / CAST_SEGMENTS)))
        seg:SetVertexColor(1, 1, 1, 0)
        seg:SetTexCoord(RING_TEXEL_HALF, 1 - RING_TEXEL_HALF, RING_TEXEL_HALF, 1 - RING_TEXEL_HALF)
        if seg.SetSnapToPixelGrid then
            seg:SetSnapToPixelGrid(false)
            seg:SetTexelSnappingBias(0)
        end
        segments[i] = seg
    end
    return segments
end

-- Helper: Create cast overlay texture
local function CreateCastOverlay(container)
    local overlay = container:CreateTexture(nil, "OVERLAY")
    overlay:SetTexture(ASSET_PATH .. settings.shape, "CLAMP", "CLAMP", "TRILINEAR")
    overlay:SetVertexColor(settings.castColor.r, settings.castColor.g, settings.castColor.b, 1)
    overlay:SetAlpha(0)
    overlay:SetSize(settings.size * CAST_OVERLAY_INITIAL_SCALE, settings.size * CAST_OVERLAY_INITIAL_SCALE)
    overlay:SetPoint("CENTER", container, "CENTER")
    overlay:SetTexCoord(RING_TEXEL_HALF, 1 - RING_TEXEL_HALF, RING_TEXEL_HALF, 1 - RING_TEXEL_HALF)
    if overlay.SetSnapToPixelGrid then
        overlay:SetSnapToPixelGrid(false)
        overlay:SetTexelSnappingBias(0)
    end
    return overlay
end

-- Helper: Create trail glow texture
local function CreateTrailGlow(parent)
    local tex = parent:CreateTexture(nil, "BACKGROUND")
    tex:SetTexture(ASSET_PATH .. "trail_glow.tga", "CLAMP", "CLAMP", "TRILINEAR")
    tex:SetBlendMode("ADD")
    tex:SetAlpha(0)
    tex:SetSize(TRAIL_BASE_SIZE * TRAIL_SIZE_MULTIPLIER, TRAIL_BASE_SIZE * TRAIL_SIZE_MULTIPLIER)
    tex:SetTexCoord(TRAIL_TEXEL_HALF, 1 - TRAIL_TEXEL_HALF, TRAIL_TEXEL_HALF, 1 - TRAIL_TEXEL_HALF)
    return tex
end

-- Create independent trail frame (separate from ring)
CreateTrailFrame = function()
    if frames.trailContainer then return end

    local container = CreateFrame("Frame", nil, UIParent)
    container:SetSize(1, 1)
    container:SetFrameStrata("TOOLTIP")
    container:SetFrameLevel(1)
    container:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)

    frames.trailContainer = container

    -- Create trail textures
    for i = 1, TRAIL_MAX_POINTS do
        trailBuf[i].tex = CreateTrailGlow(container)
        trailBuf[i].tex:Hide()
    end

    -- Trail has its own OnUpdate
    container:SetScript("OnUpdate", function(self, elapsed)
        if not settings.trailEnabled then return end
        if not trailActive then return end
        if settings.hideOnMouseClick and isRightMouseDown then return end

        trailUpdateTimer = trailUpdateTimer + elapsed
        if trailUpdateTimer < TRAIL_UPDATE_INTERVAL then return end
        trailUpdateTimer = 0

        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        x, y = floor(x / scale + 0.5), floor(y / scale + 0.5)

        local now = GetTime()
        local opacity = GetCurrentOpacity()

        -- Check if cursor moved enough to add new point
        local dx, dy = x - lastTrailX, y - lastTrailY
        if dx * dx + dy * dy >= TRAIL_MOVE_THRESHOLD_SQ then
            lastTrailX, lastTrailY = x, y
            trailHead = (trailHead % TRAIL_MAX_POINTS) + 1
            local slot = trailBuf[trailHead]
            slot.x, slot.y, slot.time, slot.active, slot.lastSize = x, y, now, true, 0
            if trailCount < TRAIL_MAX_POINTS then trailCount = trailCount + 1 end
        end

        -- Update existing trail points
        if trailCount > 0 then
            local duration = settings.trailDuration > 0 and settings.trailDuration or 0.1
            local invDuration = 1 / duration

            for i = 1, TRAIL_MAX_POINTS do
                local pt = trailBuf[i]
                if pt.active and pt.tex then
                    local fade = 1 - ((now - pt.time) * invDuration)
                    if fade <= 0 then
                        pt.active = false
                        trailCount = trailCount - 1
                        pt.tex:Hide()
                    else
                        pt.tex:ClearAllPoints()
                        pt.tex:SetPoint("CENTER", UIParent, "BOTTOMLEFT", pt.x, pt.y)
                        local tc = settings.trailColor
                        pt.tex:SetVertexColor(tc.r, tc.g, tc.b, fade * opacity * TRAIL_MAX_ALPHA)
                        local newSize = TRAIL_BASE_SIZE * TRAIL_FADE_MULTIPLIER * fade
                        if math.abs(newSize - pt.lastSize) > 1 then
                            pt.lastSize = newSize
                            pt.tex:SetSize(newSize, newSize)
                        end
                        pt.tex:Show()
                    end
                end
            end
        end
    end)

    container:Show()
end

-- Changed from 'local function' to assignment to respect forward declaration
CreateCursorFrame = function()
    if frames.mainRing then return end

    local container = CreateFrame("Frame", nil, UIParent)
    local sz = settings.size
    if sz % 2 == 1 then sz = sz + 1 end
    container:SetSize(sz, sz)
    container:SetFrameStrata("TOOLTIP")
    container:SetIgnoreParentScale(false)
    container:EnableMouse(false)
    container:SetClampedToScreen(false)

    -- Create main components using helper functions
    frames.mainRing = CreateRingTexture(container)
    frames.gcdReadyRing = CreateGCDReadyRing(container)
    frames.gcdCooldown = CreateGCDCooldown(container)
    RefreshGCDAppearance()

    frames.castSegments = CreateCastSegments(container)
    frames.castOverlay = CreateCastOverlay(container)
    UpdateCastAnimation(settings.castAnimation)

    local alphaTimer = 0
    local cachedOpacity = nil
    container:SetScript("OnUpdate", ns.PerfMonitor:Wrap("Mouse Ring", function(self, elapsed)
        if not settings.enabled then return end
        
        if settings.hideOnMouseClick and isRightMouseDown then return end
        
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        x, y = x / scale, y / scale

        x = floor(x + 0.5)
        y = floor(y + 0.5)

        if x ~= lastRingX or y ~= lastRingY then
            lastRingX, lastRingY = x, y
            self:ClearAllPoints()
            self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
        end

        alphaTimer = alphaTimer + elapsed
        if alphaTimer >= 0.5 then
            alphaTimer = 0
            if frames.mainRing and settings.enabled and ShouldShow() and not (settings.hideOnMouseClick and isRightMouseDown) then
                local alpha = GetCurrentOpacity()

                -- Skip updates if opacity hasn't changed
                if alpha ~= cachedOpacity then
                    cachedOpacity = alpha

                    if not gcdActive and not settings.hideBackground then
                        frames.mainRing:SetAlpha(alpha)
                    end

                    if frames.castOverlay and frames.castOverlay:GetAlpha() > 0 then
                        frames.castOverlay:SetAlpha(alpha)
                    end

                    if frames.castSegments then
                        for i = 1, CAST_SEGMENTS do
                            local seg = frames.castSegments[i]
                            if seg then
                                local r, g, b, a = seg:GetVertexColor()
                                if a > 0 then seg:SetVertexColor(r, g, b, alpha) end
                            end
                        end
                    end
                end
            end
        end
    end))

    if castTicker then castTicker:Cancel(); castTicker = nil end

    UpdateVisibility()
    
    -- Force initial ring position to cursor IMMEDIATELY when creating the frame
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    x, y = x / scale, y / scale
    x = floor(x + 0.5)
    y = floor(y + 0.5)
    container:ClearAllPoints()
    container:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    container:Show()
end

function ns.InitMouseOptions()
    local p = ns.MainFrame.Content

    W:CachedPanel(cache, "cursorPanel", p, function(f)
        local sf, sc = W:CreateScrollFrame(f, 900)

        W:CreatePageHeader(sc,
            {{"MOUSE", C.BLUE}, {"RING", C.ORANGE}},
            W.Colorize(L["MOUSE_SUBTITLE"], C.GRAY))

        local killArea = CreateFrame("Frame", nil, sc, "BackdropTemplate")
        killArea:SetSize(460, 87)
        killArea:SetPoint("TOPLEFT", 10, -75)
        killArea:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
        killArea:SetBackdropColor(0.01, 0.56, 0.91, 0.08)

        local masterCB = W:CreateCheckbox(killArea, {
            label = L["MOUSE_ENABLE"],
            db = settings, key = "enabled",
            x = 15, y = -8,
            isMaster = true,
        })

        local oocCB = W:CreateCheckbox(killArea, {
            label = L["MOUSE_VISIBLE_OOC"],
            db = settings, key = "showOutOfCombat",
            x = 15, y = -38,
            template = "ChatConfigCheckButtonTemplate",
            onChange = function()
                SaveSettings()
                RefreshCombatCache()
                
                if settings.enabled and ShouldShow() and frames.mainRing and frames.mainRing:GetParent() then
                    frames.mainRing:GetParent():Show()
                end
                
                UpdateVisibility()
                UpdateTrailVisibility()
                ProcessGCDUpdate()
            end
        })
        oocCB:SetShown(settings.enabled)

        local hideOnClickCB = W:CreateCheckbox(killArea, {
            label = L["MOUSE_HIDE_ON_CLICK"],
            db = settings, key = "hideOnMouseClick",
            x = 15, y = -63,
            template = "ChatConfigCheckButtonTemplate",
            onChange = function()
                SaveSettings()
                UpdateMouseWatcher()
                RefreshCombatCache()

                if settings.enabled and ShouldShow() and frames.mainRing and frames.mainRing:GetParent() then
                    frames.mainRing:GetParent():Show()
                end

                UpdateVisibility()
                UpdateTrailVisibility()
                ProcessGCDUpdate()
            end
        })
        hideOnClickCB:SetShown(settings.enabled)

        local sectionContainer = CreateFrame("Frame", nil, sc)
        sectionContainer:SetPoint("TOPLEFT", killArea, "BOTTOMLEFT", 0, -10)
        sectionContainer:SetPoint("RIGHT", sc, "RIGHT", -10, 0)
        sectionContainer:SetHeight(600)

        local RelayoutSections

        local appWrap, appContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["MOUSE_SECTION_APPEARANCE"],
            startOpen = true,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        W:CreateDropdown(appContent, {
            label = L["MOUSE_SHAPE"],
            db = settings, key = "shape",
            options = ringShapes,
            x = 10, y = -5,
            width = 120,
            onChange = function(val) UpdateShape(val) end
        })

        local bgColorLabel = appContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        bgColorLabel:SetPoint("TOPLEFT", 250, -5)
        bgColorLabel:SetText(W.Colorize(L["MOUSE_COLOR_BACKGROUND"], C.ORANGE))

        CreateColorButton(appContent, "Background", "color", 250, -25, function(r, g, b)
            UpdateColor(r, g, b)
        end)

        W:CreateSlider(appContent, {
            label = L["MOUSE_SIZE"],
            min = 32, max = 256, step = 1,
            x = 0, y = -55,
            value = settings.size or 48,
            onChange = function(val) UpdateSize(val) end
        })

        W:CreateSlider(appContent, {
            label = L["MOUSE_OPACITY_COMBAT"],
            min = 0, max = 100, step = 10,
            x = 240, y = -55,
            isPercent = true,
            value = (settings.opacityInCombat or 1.0) * 100,
            onChange = function(val)
                settings.opacityInCombat = val / 100
                DebouncedSave()
            end
        })

        W:CreateSlider(appContent, {
            label = L["MOUSE_OPACITY_OOC"],
            min = 0, max = 100, step = 10,
            x = 0, y = -115,
            isPercent = true,
            value = (settings.opacityOutOfCombat or 1.0) * 100,
            onChange = function(val)
                settings.opacityOutOfCombat = val / 100
                DebouncedSave()
            end
        })

        appContent:SetHeight(175)
        appWrap:RecalcHeight()

        local gcdWrap, gcdContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["MOUSE_SECTION_GCD"],
            startOpen = true,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        W:CreateCheckbox(gcdContent, {
            label = L["MOUSE_GCD_ENABLE"],
            db = settings, key = "gcdEnabled",
            x = 10, y = -5,
            template = "ChatConfigCheckButtonTemplate",
            onChange = function()
                SaveSettings()
                RefreshGCDAppearance()
                ProcessGCDUpdate()
            end
        })

        W:CreateCheckbox(gcdContent, {
            label = L["MOUSE_HIDE_BACKGROUND"],
            db = settings, key = "hideBackground",
            x = 10, y = -30,
            template = "ChatConfigCheckButtonTemplate",
            onChange = function()
                SaveSettings()
                UpdateVisibility()
            end
        })

        local swipeLabel = gcdContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        swipeLabel:SetPoint("TOPLEFT", 10, -55)
        swipeLabel:SetText(W.Colorize(L["MOUSE_COLOR_SWIPE"], C.ORANGE))

        CreateColorButton(gcdContent, "Swipe", "gcdColor", 10, -75, function()
            RefreshGCDAppearance()
        end)

        local readyLabel = gcdContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        readyLabel:SetPoint("TOPLEFT", 230, -55)
        readyLabel:SetText(W.Colorize(L["MOUSE_COLOR_READY"], C.ORANGE))

        local readyColorBtn, readyColorSwatch, readyColorBorder = CreateColorButton(gcdContent, "Ready", "gcdReadyColor", 230, -75, function()
            RefreshGCDAppearance()
        end)

        local matchSwipeCB = W:CreateCheckbox(gcdContent, {
            label = L["MOUSE_GCD_READY_MATCH"],
            db = settings, key = "gcdReadyMatchSwipe",
            x = 230, y = -100,
            template = "ChatConfigCheckButtonTemplate",
            onChange = function(enabled)
                SaveSettings()
                readyLabel:SetShown(not enabled)
                readyColorBtn:SetShown(not enabled)
                readyColorSwatch:SetShown(not enabled)
                readyColorBorder:SetShown(not enabled)
                RefreshGCDAppearance()
            end
        })

        readyLabel:SetShown(not settings.gcdReadyMatchSwipe)
        readyColorBtn:SetShown(not settings.gcdReadyMatchSwipe)
        readyColorSwatch:SetShown(not settings.gcdReadyMatchSwipe)
        readyColorBorder:SetShown(not settings.gcdReadyMatchSwipe)

        W:CreateSlider(gcdContent, {
            label = L["MOUSE_OPACITY_SWIPE"],
            min = 0, max = 100, step = 10,
            x = 0, y = -130,
            isPercent = true,
            value = (settings.gcdAlpha or 1.0) * 100,
            onChange = function(val)
                settings.gcdAlpha = val / 100
                DebouncedSave()
                RefreshGCDAppearance()
            end
        })

        W:CreateCheckbox(gcdContent, {
            label = L["MOUSE_CAST_SWIPE_ENABLE"],
            db = settings, key = "castSwipeEnabled",
            x = 10, y = -190,
            template = "ChatConfigCheckButtonTemplate",
            onChange = function()
                SaveSettings()
            end
        })

        CreateColorButton(gcdContent, "Cast Swipe Color", "castSwipeColor", 10, -220, function()
            if isCasting then
                ApplySwipeColor(true)
            end
        end)

        gcdContent:SetHeight(265)
        gcdWrap:RecalcHeight()

        local trailWrap, trailContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["MOUSE_SECTION_TRAIL"],
            startOpen = true,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        W:CreateCheckbox(trailContent, {
            label = L["MOUSE_TRAIL_ENABLE"],
            db = settings, key = "trailEnabled",
            x = 10, y = -5,
            template = "ChatConfigCheckButtonTemplate",
            onChange = function()
                SaveSettings()
                UpdateTrailVisibility()
            end
        })

        W:CreateSlider(trailContent, {
            label = L["MOUSE_TRAIL_DURATION"],
            min = 10, max = 100, step = 5,
            x = 0, y = -30,
            value = ((settings.trailDuration - 0.1) / 0.4) * 100,
            onChange = function(val)
                settings.trailDuration = 0.1 + (val / 100) * 0.4
                DebouncedSave()
            end
        })

        local trailColorLabel = trailContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        trailColorLabel:SetPoint("TOPLEFT", 250, -5)
        trailColorLabel:SetText(W.Colorize(L["MOUSE_TRAIL_COLOR"], C.ORANGE))

        CreateColorButton(trailContent, "Trail", "trailColor", 250, -25, function()
            SaveSettings()
        end)

        trailContent:SetHeight(90)
        trailWrap:RecalcHeight()

        local allSections = { appWrap, gcdWrap, trailWrap }

        RelayoutSections = function()
            for i, section in ipairs(allSections) do
                section:ClearAllPoints()
                if i == 1 then
                    section:SetPoint("TOPLEFT", sectionContainer, "TOPLEFT", 0, 0)
                else
                    section:SetPoint("TOPLEFT", allSections[i - 1], "BOTTOMLEFT", 0, -12)
                end
                section:SetPoint("RIGHT", sectionContainer, "RIGHT", 0, 0)
            end

            local totalH = 100 + 95 + 10
            if settings.enabled then
                for _, s in ipairs(allSections) do
                    totalH = totalH + s:GetHeight() + 12
                end
            end
            sc:SetHeight(math.max(totalH + 40, 600))
        end

        masterCB:SetScript("OnClick", function(self)
            settings.enabled = self:GetChecked() and true or false
            SaveSettings()

            if settings.enabled then
                -- Create cursor frame if it doesn't exist
                if not frames.mainRing then
                    CreateCursorFrame()
                    UpdateCastAnimation(settings.castAnimation)
                    RefreshGCDAppearance()
                    UpdateMouseWatcher()
                end
                -- Show the parent container
                if frames.mainRing and frames.mainRing:GetParent() then
                    frames.mainRing:GetParent():Show()
                end
            else
                -- Hide the parent container completely when disabled
                if frames.mainRing and frames.mainRing:GetParent() then
                    frames.mainRing:GetParent():Hide()
                end
                if frames.gcdCooldown then
                    frames.gcdCooldown:Hide()
                end
                gcdActive = false
            end

            UpdateVisibility()
            UpdateTrailVisibility()

            oocCB:SetShown(settings.enabled)
            hideOnClickCB:SetShown(settings.enabled)
            sectionContainer:SetShown(settings.enabled)
            if settings.enabled then
                killArea:SetBackdropColor(0.01, 0.56, 0.91, 0.08)
            end
            RelayoutSections()
        end)
        sectionContainer:SetShown(settings.enabled)

        -- Restore defaults button
        local restoreBtn = W:CreateRestoreDefaultsButton({
            moduleName = "CursorTracker",
            parent = sc,
        })
        restoreBtn:SetPoint("BOTTOMLEFT", sc, "BOTTOMLEFT", 10, 20)

        RelayoutSections()
    end)
end

function ns.UpdateMouseCircle()
    LoadSettings()
    CreateCursorFrame()
    UpdateCastAnimation(settings.castAnimation)
    UpdateVisibility()
    UpdateTrailVisibility()
    RefreshGCDAppearance()
    UpdateMouseWatcher()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_LEAVING_WORLD")
events:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
events:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_FAILED_QUIET", "player")

-- Better parameter naming (unit, castGUID, spellID)
events:SetScript("OnEvent", function(self, event, unit, castGUID, spellID)
    if settings.hideOnMouseClick and isRightMouseDown then return end
    
    if event == "PLAYER_LOGIN" then
        NaowhQOL = NaowhQOL or {}
        NaowhQOL.CursorTracker = NaowhQOL.CursorTracker or {}

    elseif event == "PLAYER_LEAVING_WORLD" then
        if frames.mainRing and frames.mainRing:GetParent() then
            local parent = frames.mainRing:GetParent()
            parent:Hide()
            parent:SetScript("OnUpdate", nil)
        end

        if castTicker then
            castTicker:Cancel()
            castTicker = nil
        end

        -- Clean up trail
        if frames.trailContainer then
            frames.trailContainer:Hide()
            frames.trailContainer:SetScript("OnUpdate", nil)
        end
        for i = 1, TRAIL_MAX_POINTS do
            local pt = trailBuf[i]
            if pt.tex then
                pt.tex:Hide()
                pt.tex = nil
            end
            pt.active = false
        end
        frames.trailContainer = nil
        trailHead = 0
        trailCount = 0
        trailActive = false

        gcdActive = false
        isCasting = false

        if frames.gcdReadyRing then
            frames.gcdReadyRing:Hide()
        end

    elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        NaowhQOL = NaowhQOL or {}
        NaowhQOL.CursorTracker = NaowhQOL.CursorTracker or {}

        cache["cursorPanel"] = nil

        if frames.mainRing and frames.mainRing:GetParent() then
            local parent = frames.mainRing:GetParent()
            parent:Hide()
            parent:SetScript("OnUpdate", nil)
        end

        if castTicker then castTicker:Cancel(); castTicker = nil end

        frames.mainRing = nil
        frames.castOverlay = nil
        frames.castSegments = nil
        frames.gcdCooldown = nil
        frames.gcdReadyRing = nil
        gcdActive = false

        RefreshCombatCache()
        LoadSettings()
        CreateCursorFrame()
        UpdateCastAnimation(settings.castAnimation)
        UpdateVisibility()
        UpdateTrailVisibility()
        RefreshGCDAppearance()
        UpdateMouseWatcher()

        -- Force position update after entering world
        if frames.mainRing and frames.mainRing:GetParent() and settings.enabled then
            local parent = frames.mainRing:GetParent()
            parent:Show()

            -- Single position snap using timer instead of orphaned frame
            C_Timer.After(0, function()
                if parent and parent:IsShown() then
                    local x, y = GetCursorPosition()
                    local scale = UIParent:GetEffectiveScale()
                    x, y = floor(x / scale + 0.5), floor(y / scale + 0.5)
                    parent:ClearAllPoints()
                    parent:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
                end
            end)
        end

    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        if unit == "player" and settings.enabled then
            local isChannel = (event == "UNIT_SPELLCAST_CHANNEL_START")
            local startTime, endTime
            if isChannel then
                _, _, _, startTime, endTime = UnitChannelInfo("player")
            else
                _, _, _, startTime, endTime = UnitCastingInfo("player")
            end
            if startTime and endTime then
                -- Cancel any pending GCD timer to prevent flash
                if gcdDelayTimer then
                    gcdDelayTimer:Cancel()
                    gcdDelayTimer = nil
                end
                -- Hide GCD ready ring when casting
                if frames.gcdReadyRing then
                    frames.gcdReadyRing:Hide()
                end
                isCasting = true
                gcdActive = false
                if settings.castSwipeEnabled and frames.gcdCooldown then
                    ApplySwipeColor(true)
                    local duration = (endTime - startTime) / 1000
                    local start = startTime / 1000
                    frames.gcdCooldown:Show()
                    frames.gcdCooldown:SetCooldown(start, duration)
                end
                StartCastTicker()
            end
        end

    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP"
        or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_FAILED_QUIET" then
        if unit == "player" then
            -- Don't stop if a cast or channel is still active
            -- (failed spam attempts fire FAILED events while channeling)
            if UnitCastingInfo("player") or UnitChannelInfo("player") then
                return
            end
            StopCastTicker()
        end

    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        RefreshCombatCache()
        UpdateVisibility()
        UpdateTrailVisibility()

    elseif event == "SPELL_UPDATE_COOLDOWN" or event == "ACTIONBAR_UPDATE_COOLDOWN" then
        ProcessGCDUpdate()

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and spellID then
        if not settings.gcdEnabled or not settings.enabled then return end
        -- Skip GCD if cast or channel is active (check API directly)
        if settings.castSwipeEnabled and (UnitCastingInfo("player") or UnitChannelInfo("player")) then return end

        local start, duration, modRate = FetchCooldownData(spellID)
        if CheckCooldownState(start, duration) and frames.gcdCooldown then
            frames.gcdCooldown:Show()
            gcdActive = true

            if frames.mainRing and not settings.hideBackground then
                frames.mainRing:Show()
            end

            if modRate then
                frames.gcdCooldown:SetCooldown(start, duration, modRate)
            else
                frames.gcdCooldown:SetCooldown(start, duration)
            end
        else
            ProcessGCDUpdate()
        end
    end
end)

local mouseWatcher = CreateFrame("Frame")
local mouseWatcherOnUpdate = function()
    if not settings.enabled then return end
    if not frames.mainRing then return end

    local wasRightDown = isRightMouseDown
    isRightMouseDown = IsMouseButtonDown("RightButton")

    if wasRightDown and not isRightMouseDown then
        if ShouldShow() then
            if frames.mainRing and frames.mainRing:GetParent() then
                frames.mainRing:GetParent():Show()
            end
            UpdateVisibility()
            UpdateTrailVisibility()
            ProcessGCDUpdate()
        end
    elseif not wasRightDown and isRightMouseDown then
        if frames.mainRing and frames.mainRing:GetParent() then
            frames.mainRing:GetParent():Hide()
        end
        if frames.gcdCooldown then
            frames.gcdCooldown:Hide()
        end
    end
end

UpdateMouseWatcher = function()
    if settings.hideOnMouseClick then
        mouseWatcher:SetScript("OnUpdate", mouseWatcherOnUpdate)
    else
        mouseWatcher:SetScript("OnUpdate", nil)
        isRightMouseDown = false
    end
end