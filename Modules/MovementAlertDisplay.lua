local addonName, ns = ...
local L = ns.L
local W = ns.Widgets

local DEBUG_MODE = false  -- Set to true for troubleshooting
local inCombat = false

local UNLOCK_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

-- Movement abilities by class and spec
-- Each class maps spec ID to an ordered list of spell IDs (first known one is used)
local MOVEMENT_ABILITIES = {
    DEATHKNIGHT = {[250] = {48265}, [251] = {48265}, [252] = {48265}},
    DEMONHUNTER = {[577] = {195072}, [581] = {189110}, [1480] = {1234796}},
    DRUID = {[102] = {102401, 252216, 1850}, [103] = {102401, 252216, 1850}, [104] = {102401, 106898}, [105] = {102401, 252216, 1850}},
    EVOKER = {[1467] = {358267}, [1468] = {358267}, [1473] = {358267}},
    HUNTER = {[253] = {781}, [254] = {781}, [255] = {781}},
    MAGE = {[62] = {212653, 1953}, [63] = {212653, 1953}, [64] = {212653, 1953}},
    MONK = {[268] = {115008, 109132}, [269] = {109132}, [270] = {109132}},
    PALADIN = {[65] = {190784}, [66] = {190784}, [70] = {190784}},
    PRIEST = {[256] = {121536, 73325}, [257] = {121536, 73325}, [258] = {121536, 73325}},
    ROGUE = {[259] = {36554}, [260] = {195457}, [261] = {36554}},
    SHAMAN = {[262] = {79206, 90328, 192063}, [263] = {90328, 192063}, [264] = {79206, 90328, 192063}},
    WARLOCK = {[265] = {48020}, [266] = {48020}, [267] = {48020}},
    WARRIOR = {[71] = {6544}, [72] = {6544}, [73] = {6544}},
}

-- Abilities affected by Time Spiral (free cooldown reset)
-- NOTE: This table must be updated when Blizzard adds new movement abilities
-- that interact with the Time Spiral effect. Check patch notes for changes.
local TIME_SPIRAL_ABILITIES = {
    [48265] = true,   -- Death's Advance
    [195072] = true,  -- Fel Rush
    [189110] = true,  -- Infernal Strike
    [1234796] = true, -- Shift
    [1850] = true,    -- Dash
    [252216] = true,  -- Tiger Dash
    [358267] = true,  -- Hover
    [186257] = true,  -- Aspect of the Cheetah
    [212653] = true,  -- Shimmer
    [1953] = true,    -- Blink
    [119085] = true,  -- Chi Torpedo
    [361138] = true,  -- Roll
    [190784] = true,  -- Divine Steed
    [2983] = true,    -- Sprint
    [192063] = true,  -- Gust of Wind
    [58875] = true,   -- Spirit Walk
    [79206] = true,   -- Spiritwalker's Grace
    [48020] = true,   -- Demonic Circle: Teleport
    [6544] = true,    -- Heroic Leap
}

-- Talents that trigger false positive glow events on movement abilities
-- Structure: CLASS[talentSpellId][triggerSpellId] = discardDelay
-- Credit: Spell IDs sourced from TimeSpiralTracker addon
local TS_FALSE_POSITIVE_TALENTS = {
    DEMONHUNTER = {
        [427640] = { [198793] = 0.1, [370965] = 1.1 },  -- Inertia: Vengeful Retreat, The Hunt
        [427794] = { [195072] = 0.1 },                   -- Dash of Chaos: Fel Rush
    },
    WARLOCK = {
        [385899] = { [385899] = 0.1 },                   -- Soulburn
    },
}

local activeFalsePositives = {}
local tsMultiGlowBlock = false
local tsDiscardActive = false

-- ----------------------------------------------------------------
-- Movement Cooldown Frame
-- ----------------------------------------------------------------

local movementFrame = CreateFrame("Frame", "NaowhQOL_MovementAlert", UIParent, "BackdropTemplate")
movementFrame:SetSize(200, 40)
movementFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
movementFrame:Hide()

-- Text display (for text mode)
local movementText = movementFrame:CreateFontString(nil, "OVERLAY")
movementText:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", 24, "OUTLINE")
movementText:SetPoint("CENTER")

-- Icon display (for icon mode)
local movementIcon = CreateFrame("Frame", nil, movementFrame)
movementIcon:SetSize(40, 40)
movementIcon:SetPoint("CENTER")
movementIcon.border = movementIcon:CreateTexture(nil, "BACKGROUND")
movementIcon.border:SetAllPoints()
movementIcon.border:SetColorTexture(0, 0, 0, 1)
movementIcon.tex = movementIcon:CreateTexture(nil, "ARTWORK")
movementIcon.tex:SetPoint("TOPLEFT", 2, -2)
movementIcon.tex:SetPoint("BOTTOMRIGHT", -2, 2)
movementIcon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
movementIcon.cooldown = CreateFrame("Cooldown", nil, movementIcon, "CooldownFrameTemplate")
movementIcon.cooldown:SetAllPoints(movementIcon.tex)
movementIcon.cooldown:SetDrawEdge(false)
movementIcon:Hide()

-- Bar display (for bar mode)
local movementBar = CreateFrame("StatusBar", nil, movementFrame)
movementBar:SetSize(150, 20)
movementBar:SetPoint("CENTER")
movementBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
movementBar:SetMinMaxValues(0, 1)
movementBar:SetValue(0)
movementBar.bg = movementBar:CreateTexture(nil, "BACKGROUND")
movementBar.bg:SetAllPoints()
movementBar.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
movementBar.text = movementBar:CreateFontString(nil, "OVERLAY")
movementBar.text:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", 12, "OUTLINE")
movementBar.text:SetPoint("CENTER")
movementBar.icon = movementBar:CreateTexture(nil, "OVERLAY")
movementBar.icon:SetSize(20, 20)
movementBar.icon:SetPoint("RIGHT", movementBar, "LEFT", -4, 0)
movementBar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
movementBar:Hide()

local movementResizeHandle
local cachedMovementSpellId = nil
local cachedMovementSpellName = nil
local cachedMovementSpellIcon = nil

-- Timer handles for countdown updates
local movementCountdownTimer = nil
local timeSpiralCountdownTimer = nil

-- Forward declarations for self-referencing functions
local CheckMovementCooldown
local UpdateEventRegistration

-- ----------------------------------------------------------------
-- Time Spiral Frame
-- ----------------------------------------------------------------

local timeSpiralFrame = CreateFrame("Frame", "NaowhQOL_TimeSpiral", UIParent, "BackdropTemplate")
timeSpiralFrame:SetSize(200, 40)
timeSpiralFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
timeSpiralFrame:Hide()

local timeSpiralText = timeSpiralFrame:CreateFontString(nil, "OVERLAY")
timeSpiralText:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", 24, "OUTLINE")
timeSpiralText:SetPoint("CENTER")

local timeSpiralResizeHandle
local timeSpiralActiveTime = nil

-- ----------------------------------------------------------------
-- Helper Functions
-- ----------------------------------------------------------------

local function GetPlayerMovementSpell()
    local class = select(2, UnitClass("player"))
    local spec = GetSpecialization()
    if not spec then return nil end
    local specId = select(1, GetSpecializationInfo(spec))

    local classAbilities = MOVEMENT_ABILITIES[class]
    if not classAbilities then return nil end

    local specAbilities = classAbilities[specId]
    if not specAbilities then return nil end

    for _, spellId in ipairs(specAbilities) do
        if IsPlayerSpell(spellId) then
            return spellId
        end
    end
    return nil
end

local function CacheMovementSpell()
    local class = select(2, UnitClass("player"))
    local spec = GetSpecialization()
    local specId = spec and select(1, GetSpecializationInfo(spec)) or nil

    if DEBUG_MODE then
        print("[MovementAlert] CacheMovementSpell - Class:", class, "SpecID:", specId)
    end

    cachedMovementSpellId = GetPlayerMovementSpell()
    if cachedMovementSpellId then
        local spellInfo = C_Spell.GetSpellInfo(cachedMovementSpellId)
        if spellInfo then
            cachedMovementSpellName = spellInfo.name
            cachedMovementSpellIcon = spellInfo.iconID
        end
        if DEBUG_MODE then
            print("[MovementAlert] Cached spell:", cachedMovementSpellId, cachedMovementSpellName)
            print("[MovementAlert] IsPlayerSpell:", IsPlayerSpell(cachedMovementSpellId))
        end
    else
        cachedMovementSpellName = nil
        cachedMovementSpellIcon = nil
        if DEBUG_MODE then
            print("[MovementAlert] No movement spell found for this spec")
        end
    end
end

local function PlayTimeSpiralAlert(db)
    if db.tsSoundEnabled and db.tsSoundID then
        local sound = db.tsSoundID
        if type(sound) == "table" then
            ns.SoundList.Play(sound)
        else
            PlaySound(sound)
        end
    elseif db.tsTtsEnabled and db.tsTtsMessage then
        C_VoiceChat.SpeakText(0, db.tsTtsMessage, 1, db.tsTtsVolume or 50, true)
    end
end

local function RebuildFalsePositiveList()
    activeFalsePositives = {}
    local class = select(2, UnitClass("player"))
    local classTalents = TS_FALSE_POSITIVE_TALENTS[class]
    if not classTalents then return end

    for talentId, spells in pairs(classTalents) do
        if C_SpellBook.IsSpellKnown(talentId) then
            for spellId, delay in pairs(spells) do
                activeFalsePositives[spellId] = delay
            end
        end
    end
end

local function CancelMovementCountdown()
    if movementCountdownTimer then
        movementCountdownTimer:Cancel()
        movementCountdownTimer = nil
    end
end

local function CancelTimeSpiralCountdown()
    if timeSpiralCountdownTimer then
        timeSpiralCountdownTimer:Cancel()
        timeSpiralCountdownTimer = nil
    end
end

-- ----------------------------------------------------------------
-- Movement Frame Display
-- ----------------------------------------------------------------

function movementFrame:UpdateDisplay()
    local db = NaowhQOL.movementAlert
    if not db then return end

    movementFrame:EnableMouse(db.unlock)
    if db.unlock then
        movementFrame:SetBackdrop(UNLOCK_BACKDROP)
        movementFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        movementFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        if movementResizeHandle then movementResizeHandle:Show() end
        movementFrame:Show()
    else
        movementFrame:SetBackdrop(nil)
        if movementResizeHandle then movementResizeHandle:Hide() end
    end

    if not movementFrame.initialized then
        movementFrame:ClearAllPoints()
        local point = db.point or "CENTER"
        local x = db.x or 0
        local y = db.y or 50
        movementFrame:SetPoint(point, UIParent, point, x, y)
        movementFrame:SetSize(db.width or 200, db.height or 40)
        movementFrame.initialized = true
    end

    local fontPath = db.font or "Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf"
    local frameW = movementFrame:GetWidth()
    local frameH = movementFrame:GetHeight()

    -- Text mode font sizing
    local fontSize = math.max(10, math.min(72, math.floor(frameH * 0.55)))
    local success = movementText:SetFont(fontPath, fontSize, "OUTLINE")
    if not success then
        movementText:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", fontSize, "OUTLINE")
    end
    movementText:SetTextColor(db.textColorR or 1, db.textColorG or 1, db.textColorB or 1)

    -- Bar mode sizing - scale with frame
    local barH = math.max(12, math.floor(frameH * 0.5))
    local barIconSize = barH
    local barW = frameW - (db.barShowIcon ~= false and (barIconSize + 8) or 0) - 10
    movementBar:SetSize(math.max(50, barW), barH)
    movementBar.icon:SetSize(barIconSize, barIconSize)
    local barFontSize = math.max(8, math.min(24, math.floor(barH * 0.6)))
    movementBar.text:SetFont(fontPath, barFontSize, "OUTLINE")

    -- Icon mode sizing - scale with frame (use smaller dimension to stay square)
    local iconSize = math.max(20, math.min(frameW, frameH) - 4)
    movementIcon:SetSize(iconSize, iconSize)
    movementIcon.tex:SetPoint("TOPLEFT", 2, -2)
    movementIcon.tex:SetPoint("BOTTOMRIGHT", -2, 2)

    -- Update event registration when display is refreshed (enables/disables events)
    UpdateEventRegistration()
    if db.enabled and not db.unlock then
        CheckMovementCooldown()
    end
end

-- ----------------------------------------------------------------
-- Time Spiral Frame Display
-- ----------------------------------------------------------------

function timeSpiralFrame:UpdateDisplay()
    local db = NaowhQOL.movementAlert
    if not db then return end

    timeSpiralFrame:EnableMouse(db.tsUnlock)
    if db.tsUnlock and db.tsEnabled then
        timeSpiralFrame:SetBackdrop(UNLOCK_BACKDROP)
        timeSpiralFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        timeSpiralFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        if timeSpiralResizeHandle then timeSpiralResizeHandle:Show() end
        timeSpiralFrame:Show()
    else
        timeSpiralFrame:SetBackdrop(nil)
        if timeSpiralResizeHandle then timeSpiralResizeHandle:Hide() end
    end

    if not timeSpiralFrame.initialized then
        timeSpiralFrame:ClearAllPoints()
        local point = db.tsPoint or "CENTER"
        local x = db.tsX or 0
        local y = db.tsY or 100
        timeSpiralFrame:SetPoint(point, UIParent, point, x, y)
        timeSpiralFrame:SetSize(db.tsWidth or 200, db.tsHeight or 40)
        timeSpiralFrame.initialized = true
    end

    local fontPath = db.font or "Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf"
    local fontSize = math.max(10, math.min(72, math.floor(timeSpiralFrame:GetHeight() * 0.55)))
    local success = timeSpiralText:SetFont(fontPath, fontSize, "OUTLINE")
    if not success then
        timeSpiralText:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", fontSize, "OUTLINE")
    end
    timeSpiralText:SetTextColor(db.tsColorR or 0.53, db.tsColorG or 1, db.tsColorB or 0)

    -- Update event registration when display is refreshed
    UpdateEventRegistration()
end

-- ----------------------------------------------------------------
-- Movement Cooldown Display (Event-Driven + Timer)
-- ----------------------------------------------------------------

local function HideMovementDisplay()
    local db = NaowhQOL.movementAlert
    if db and not db.unlock then
        movementFrame:Hide()
    end
    movementText:Hide()
    movementIcon:Hide()
    movementIcon.cooldown:Clear()
    movementBar:Hide()
    CancelMovementCountdown()
end

-- Show movement cooldown display (no arithmetic on secret values)
-- Secret values can be passed to string.format and SetText, just not used in arithmetic
local function ShowMovementDisplay(cdInfo)
    local db = NaowhQOL.movementAlert
    if not db then return end

    local displayMode = db.displayMode or "text"
    local precision = db.precision or 1
    local spellName = cachedMovementSpellName or L["MOVEMENT_ALERT_FALLBACK"] or "Movement"

    -- Hide all elements first
    movementText:Hide()
    movementIcon:Hide()
    movementBar:Hide()

    if displayMode == "text" then
        -- Text mode: convert format to use %s placeholder, then pass secret value to SetFormattedText
        -- Cannot use gsub with secret string as replacement - must pass directly to API
        local textFormat = db.textFormat or "No %a - %ts"
        local fmtStr = textFormat:gsub("%%a", spellName):gsub("%%t", "%%s")
        movementText:SetFormattedText(fmtStr, string.format("%." .. precision .. "f", cdInfo.timeUntilEndOfStartRecovery))
        movementText:Show()
    elseif displayMode == "icon" then
        -- Icon mode: use cooldown frame with SetCooldown (AllowedWhenTainted)
        if cachedMovementSpellIcon then
            movementIcon.tex:SetTexture(cachedMovementSpellIcon)
            movementIcon.cooldown:SetCooldown(cdInfo.startTime, cdInfo.duration, cdInfo.modRate or 1)
            movementIcon.cooldown:SetHideCountdownNumbers(false)
            movementIcon:Show()
        else
            -- Fallback to text if no icon
            local textFormat = db.textFormat or "No %a - %ts"
            local fmtStr = textFormat:gsub("%%a", spellName):gsub("%%t", "%%s")
            movementText:SetFormattedText(fmtStr, string.format("%." .. precision .. "f", cdInfo.timeUntilEndOfStartRecovery))
            movementText:Show()
        end
    elseif displayMode == "bar" then
        -- Bar mode: pass secret values directly to StatusBar (AllowedWhenTainted)
        -- SetMinMaxValues and SetValue don't require arithmetic
        movementBar:SetMinMaxValues(0, cdInfo.duration)
        movementBar:SetValue(cdInfo.timeUntilEndOfStartRecovery)
        movementBar:SetStatusBarColor(db.textColorR or 1, db.textColorG or 1, db.textColorB or 1)

        -- Timer text - use secret value in string.format (allowed)
        local timeStr = string.format("%." .. precision .. "f", cdInfo.timeUntilEndOfStartRecovery)
        movementBar.text:SetText(timeStr)

        -- Optional icon
        if db.barShowIcon ~= false and cachedMovementSpellIcon then
            movementBar.icon:SetTexture(cachedMovementSpellIcon)
            movementBar.icon:Show()
        else
            movementBar.icon:Hide()
        end

        movementBar:Show()
    end

    movementFrame:Show()
end

CheckMovementCooldown = function()
    local db = NaowhQOL.movementAlert
    if not db then return end

    -- Skip if module disabled
    if not db.enabled then
        if DEBUG_MODE then print("[MovementAlert] Module disabled") end
        HideMovementDisplay()
        return
    end

    -- Skip if combat-only and not in combat
    if db.combatOnly and not inCombat and not db.unlock then
        if DEBUG_MODE then print("[MovementAlert] Combat-only mode, not in combat") end
        HideMovementDisplay()
        return
    end

    -- Skip if no cached movement spell
    if not cachedMovementSpellId then
        if DEBUG_MODE then print("[MovementAlert] No cached spell") end
        HideMovementDisplay()
        return
    end

    -- Get cooldown info
    local cdInfo = C_Spell.GetSpellCooldown(cachedMovementSpellId)

    if DEBUG_MODE then
        print("[MovementAlert] cdInfo:", cdInfo and "exists" or "nil",
              "isOnGCD:", cdInfo and cdInfo.isOnGCD)
    end

    -- Check if on actual cooldown (not GCD)
    -- isOnGCD: nil for double jumps, true for GCD, false for actual cooldown
    if cdInfo and cdInfo.isOnGCD == false then
        -- Spell is on cooldown - show and schedule next poll
        ShowMovementDisplay(cdInfo)

        -- Schedule next poll for smooth countdown updates
        CancelMovementCountdown()
        local pollMs = math.max(50, db.pollRate or 100)
        movementCountdownTimer = C_Timer.NewTimer(pollMs / 1000, CheckMovementCooldown)
    else
        -- Spell is ready or just GCD - hide display
        HideMovementDisplay()
    end
end

-- ----------------------------------------------------------------
-- Time Spiral Countdown (Timer-Based)
-- ----------------------------------------------------------------

local function UpdateTimeSpiralCountdown()
    local db = NaowhQOL.movementAlert
    if not db or not db.tsEnabled or not timeSpiralActiveTime then
        if not (db and db.tsUnlock) then
            timeSpiralFrame:Hide()
        end
        CancelTimeSpiralCountdown()
        return
    end

    local remaining = 10 - (GetTime() - timeSpiralActiveTime)
    if remaining > 0 then
        local tsText = db.tsText or L["TIME_SPIRAL_TEXT_DEFAULT"] or "FREE MOVEMENT"
        timeSpiralText:SetText(string.format("%s\n%.1f", tsText, remaining))
        timeSpiralFrame:Show()

        -- Schedule next update
        timeSpiralCountdownTimer = C_Timer.NewTimer(0.1, UpdateTimeSpiralCountdown)
    else
        timeSpiralActiveTime = nil
        if not db.tsUnlock then
            timeSpiralFrame:Hide()
        end
        CancelTimeSpiralCountdown()
    end
end

local function StartTimeSpiralCountdown()
    CancelTimeSpiralCountdown()
    UpdateTimeSpiralCountdown()
end

-- ----------------------------------------------------------------
-- Event Handler
-- ----------------------------------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
loader:RegisterEvent("PLAYER_TALENT_UPDATE")
loader:RegisterEvent("TRAIT_CONFIG_UPDATED")
loader:RegisterEvent("PLAYER_REGEN_DISABLED")
loader:RegisterEvent("PLAYER_REGEN_ENABLED")
loader:RegisterEvent("PLAYER_LOGOUT")

-- Track which optional events are registered
local movementEventsRegistered = false
local timeSpiralEventsRegistered = false

-- Register/unregister events based on feature enabled state
UpdateEventRegistration = function()
    local db = NaowhQOL.movementAlert
    if not db then return end

    -- Movement CD events (only when enabled)
    if db.enabled and not movementEventsRegistered then
        loader:RegisterEvent("SPELL_UPDATE_USABLE")
        loader:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        loader:RegisterEvent("SPELL_UPDATE_CHARGES")
        movementEventsRegistered = true
    elseif not db.enabled and movementEventsRegistered then
        loader:UnregisterEvent("SPELL_UPDATE_USABLE")
        loader:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
        loader:UnregisterEvent("SPELL_UPDATE_CHARGES")
        movementEventsRegistered = false
        CancelMovementCountdown()
    end

    -- Time Spiral events (only when enabled)
    if db.tsEnabled and not timeSpiralEventsRegistered then
        loader:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
        loader:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
        loader:RegisterEvent("UNIT_SPELLCAST_SENT")
        loader:RegisterEvent("LOADING_SCREEN_DISABLED")
        timeSpiralEventsRegistered = true
        RebuildFalsePositiveList()
    elseif not db.tsEnabled and timeSpiralEventsRegistered then
        loader:UnregisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
        loader:UnregisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
        loader:UnregisterEvent("UNIT_SPELLCAST_SENT")
        loader:UnregisterEvent("LOADING_SCREEN_DISABLED")
        timeSpiralEventsRegistered = false
        CancelTimeSpiralCountdown()
    end
end

loader:SetScript("OnEvent", ns.PerfMonitor:Wrap("Movement Alert", function(self, event, ...)
    local db = NaowhQOL.movementAlert
    if not db then return end

    if event == "PLAYER_LOGIN" then
        if DEBUG_MODE then print("[MovementAlert] PLAYER_LOGIN - initializing") end
        CacheMovementSpell()
        inCombat = UnitAffectingCombat("player")

        db.width = db.width or 200
        db.height = db.height or 40
        db.point = db.point or "CENTER"
        db.x = db.x or 0
        db.y = db.y or 50

        W.MakeDraggable(movementFrame, { db = db })
        movementResizeHandle = W.CreateResizeHandle(movementFrame, {
            db = db,
            onResize = function() movementFrame:UpdateDisplay() end,
        })

        db.tsWidth = db.tsWidth or 200
        db.tsHeight = db.tsHeight or 40
        db.tsPoint = db.tsPoint or "CENTER"
        db.tsX = db.tsX or 0
        db.tsY = db.tsY or 100

        W.MakeDraggable(timeSpiralFrame, {
            db = db,
            unlockKey = "tsUnlock",
            pointKey = "tsPoint", xKey = "tsX", yKey = "tsY",
        })
        timeSpiralResizeHandle = W.CreateResizeHandle(timeSpiralFrame, {
            db = db,
            unlockKey = "tsUnlock",
            widthKey = "tsWidth", heightKey = "tsHeight",
            onResize = function() timeSpiralFrame:UpdateDisplay() end,
        })

        movementFrame.initialized = false
        timeSpiralFrame.initialized = false
        movementFrame:UpdateDisplay()
        timeSpiralFrame:UpdateDisplay()
        UpdateEventRegistration()

        -- Re-evaluate on spec change
        ns.SpecUtil.RegisterCallback("MovementAlert", function()
            CacheMovementSpell()
            movementFrame:UpdateDisplay()
            timeSpiralFrame:UpdateDisplay()
            CheckMovementCooldown()
        end)

        -- Initial cooldown check
        CheckMovementCooldown()
        return
    end

    if event == "PLAYER_LOGOUT" then
        timeSpiralActiveTime = nil
        CancelMovementCountdown()
        CancelTimeSpiralCountdown()
        return
    end

    if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" then
        if not InCombatLockdown() then
            CacheMovementSpell()
            CheckMovementCooldown()
            RebuildFalsePositiveList()
        end
    elseif event == "LOADING_SCREEN_DISABLED" then
        RebuildFalsePositiveList()
    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        CheckMovementCooldown()
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        CacheMovementSpell()
        CheckMovementCooldown()
    elseif event == "SPELL_UPDATE_USABLE" or event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES" then
        if DEBUG_MODE then print("[MovementAlert] Event:", event) end
        CheckMovementCooldown()
    elseif event == "UNIT_SPELLCAST_SENT" then
        local _, _, _, spellId = ...
        local delay = activeFalsePositives[spellId]
        if delay then
            tsDiscardActive = true
            C_Timer.After(delay, function() tsDiscardActive = false end)
        end
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
        local spellId = ...
        if db.tsEnabled and TIME_SPIRAL_ABILITIES[spellId]
           and not tsDiscardActive and not tsMultiGlowBlock then
            tsMultiGlowBlock = true
            C_Timer.After(0.1, function() tsMultiGlowBlock = false end)
            timeSpiralActiveTime = GetTime()
            PlayTimeSpiralAlert(db)
            StartTimeSpiralCountdown()
        end
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        local spellId = ...
        if TIME_SPIRAL_ABILITIES[spellId] then
            timeSpiralActiveTime = nil
            CancelTimeSpiralCountdown()
            if not db.tsUnlock then
                timeSpiralFrame:Hide()
            end
        end
    end

    movementFrame:UpdateDisplay()
    timeSpiralFrame:UpdateDisplay()
    UpdateEventRegistration()
end))

ns.MovementAlertDisplay = movementFrame
ns.TimeSpiralDisplay = timeSpiralFrame
