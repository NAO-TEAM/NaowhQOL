local addonName, ns = ...
local L = ns.L
local W = ns.Widgets

-- Interrupt spell IDs by class and spec
local INTERRUPT_SPELLS = {
    DEATHKNIGHT = {[250] = 47528, [251] = 47528, [252] = 47528},
    DEMONHUNTER = {[577] = 183752, [581] = 183752, [1480] = 183752},
    DRUID = {[102] = 78675, [103] = 106839, [104] = 106839, [105] = nil},
    EVOKER = {[1467] = 351338, [1468] = 351338, [1473] = 351338},
    HUNTER = {[253] = 147362, [254] = 147362, [255] = 187707},
    MAGE = {[62] = 2139, [63] = 2139, [64] = 2139},
    MONK = {[268] = 116705, [269] = 116705, [270] = nil},
    PALADIN = {[65] = nil, [66] = 96231, [70] = 96231},
    PRIEST = {[256] = nil, [257] = nil, [258] = 15487},
    ROGUE = {[259] = 1766, [260] = 1766, [261] = 1766},
    SHAMAN = {[262] = 57994, [263] = 57994, [264] = 57994},
    WARLOCK = {[265] = 19647, [266] = 119914, [267] = 19647},
    WARRIOR = {[71] = 6552, [72] = 6552, [73] = 6552},
}

-- Main frame
local castBarFrame = CreateFrame("Frame", "NaowhQOL_FocusCastBar", UIParent, "BackdropTemplate")
castBarFrame:SetSize(250, 24)
castBarFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
castBarFrame:Hide()

-- 1px black border
local borderFrame = CreateFrame("Frame", nil, castBarFrame, "BackdropTemplate")
borderFrame:SetPoint("TOPLEFT", -1, 1)
borderFrame:SetPoint("BOTTOMRIGHT", 1, -1)
borderFrame:SetBackdrop({
    edgeFile = [[Interface\Buttons\WHITE8X8]],
    edgeSize = 1,
})
borderFrame:SetBackdropBorderColor(0, 0, 0, 1)

-- Background
local bgTexture = castBarFrame:CreateTexture(nil, "BACKGROUND")
bgTexture:SetAllPoints()
bgTexture:SetTexture([[Interface\Buttons\WHITE8X8]])

-- Progress bar
local progressBar = CreateFrame("StatusBar", nil, castBarFrame)
progressBar:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
progressBar:SetMinMaxValues(0, 1)
progressBar:SetValue(0)

-- Non-interruptible color overlay (shown via alpha when cast is non-interruptible)
local nonIntOverlay = progressBar:CreateTexture(nil, "OVERLAY")
nonIntOverlay:SetAllPoints(progressBar:GetStatusBarTexture())
nonIntOverlay:SetTexture([[Interface\Buttons\WHITE8X8]])
nonIntOverlay:SetAlpha(0)

-- Icon frame (left side by default)
local iconFrame = CreateFrame("Frame", nil, castBarFrame)
iconFrame:SetSize(24, 24)
iconFrame:SetPoint("LEFT", castBarFrame, "LEFT", 0, 0)

local iconBg = iconFrame:CreateTexture(nil, "BACKGROUND")
iconBg:SetAllPoints()
iconBg:SetTexture([[Interface\Buttons\WHITE8X8]])
iconBg:SetVertexColor(0, 0, 0, 0.8)

local iconTexture = iconFrame:CreateTexture(nil, "ARTWORK")
iconTexture:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1, -1)
iconTexture:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)
iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

-- Shield icon for non-interruptible casts (using Blizzard atlas)
local shieldIcon = castBarFrame:CreateTexture(nil, "OVERLAY")
shieldIcon:SetAtlas("ui-castingbar-shield")
shieldIcon:SetSize(29, 33)
shieldIcon:SetPoint("TOP", castBarFrame, "BOTTOM", 0, 4)
shieldIcon:Hide()

-- Text overlay (higher frame level)
local textFrame = CreateFrame("Frame", nil, castBarFrame)
textFrame:SetAllPoints(progressBar)
textFrame:SetFrameLevel(castBarFrame:GetFrameLevel() + 5)

local spellNameText = textFrame:CreateFontString(nil, "OVERLAY")
spellNameText:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", 12, "OUTLINE")
spellNameText:SetPoint("LEFT", textFrame, "LEFT", 4, 0)
spellNameText:SetJustifyH("LEFT")

local castTimeText = textFrame:CreateFontString(nil, "OVERLAY")
castTimeText:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", 12, "OUTLINE")
castTimeText:SetPoint("RIGHT", textFrame, "RIGHT", -4, 0)
castTimeText:SetJustifyH("RIGHT")

-- Empower stage markers container
local empowerMarkers = {}

-- State variables
local resizeHandle
local isCasting = false
local isChanneling = false
local cachedInterruptSpellId = nil

-- Get player's interrupt spell ID for current spec
local function GetInterruptSpellId()
    if cachedInterruptSpellId then
        return cachedInterruptSpellId
    end

    local _, class = UnitClass("player")
    local classSpells = INTERRUPT_SPELLS[class]
    if not classSpells then return nil end

    local spec = GetSpecialization()
    if not spec then return nil end

    local specId = GetSpecializationInfo(spec)
    if not specId then return nil end

    cachedInterruptSpellId = classSpells[specId]
    return cachedInterruptSpellId
end

-- Update bar color based on interrupt availability
local function UpdateBarColor()
    local db = NaowhQOL.focusCastBar
    if not db then return end

    local spellId = GetInterruptSpellId()
    if not spellId then
        progressBar:SetStatusBarColor(db.barColorCdR, db.barColorCdG, db.barColorCdB)
        return
    end

    local cooldownDuration = C_Spell.GetSpellCooldownDuration(spellId)
    if not cooldownDuration then
        progressBar:SetStatusBarColor(db.barColorCdR, db.barColorCdG, db.barColorCdB)
        return
    end

    -- Use IsZero() which returns a boolean we can use for color
    local isReady = cooldownDuration:IsZero()
    local barTexture = progressBar:GetStatusBarTexture()

    local bcR, bcG, bcB = W.GetEffectiveColor(db, "barColorR", "barColorG", "barColorB", "barColorUseClassColor")
    local readyColor = CreateColor(bcR, bcG, bcB, 1)
    local cdcR, cdcG, cdcB = W.GetEffectiveColor(db, "barColorCdR", "barColorCdG", "barColorCdB", "barColorCdUseClassColor")
    local cdColor = CreateColor(cdcR, cdcG, cdcB, 1)

    barTexture:SetVertexColorFromBoolean(isReady, readyColor, cdColor)

    -- Hide bar when interrupt is on cooldown
    if db.hideOnCooldown then
        castBarFrame:SetAlphaFromBoolean(isReady)
    end
end

-- Update visual indicators for interruptible state
-- Must get fresh notInterruptible value and pass directly to FromBoolean methods
local function UpdateInterruptibleDisplay()
    local db = NaowhQOL.focusCastBar
    if not db then return end

    -- Get fresh notInterruptible value directly from API
    local notInterruptible
    if isCasting then
        local _, _, _, _, _, _, _, notInt = UnitCastingInfo("focus")
        notInterruptible = notInt
    elseif isChanneling then
        local _, _, _, _, _, _, notInt = UnitChannelInfo("focus")
        notInterruptible = notInt
    else
        shieldIcon:Hide()
        nonIntOverlay:SetAlpha(0)
        return
    end

    if notInterruptible == nil then
        shieldIcon:Hide()
        nonIntOverlay:SetAlpha(0)
        return
    end

    -- Shield icon: use SetAlphaFromBoolean
    if db.showShieldIcon then
        shieldIcon:Show()
        shieldIcon:SetAlphaFromBoolean(notInterruptible, 1, 0)
    else
        shieldIcon:Hide()
    end

    -- Color overlay: use SetAlphaFromBoolean to show overlay when non-interruptible
    if db.colorNonInterrupt then
        local niR, niG, niB = W.GetEffectiveColor(db, "nonIntColorR", "nonIntColorG", "nonIntColorB", "nonIntColorUseClassColor")
        nonIntOverlay:SetVertexColor(niR, niG, niB, 1)
        nonIntOverlay:SetAlphaFromBoolean(notInterruptible, 1, 0)
    else
        nonIntOverlay:SetAlpha(0)
    end
end

-- Update layout based on settings
local function UpdateLayout()
    local db = NaowhQOL.focusCastBar
    if not db then return end

    local iconSize = db.iconSize or 24
    local showIcon = db.showIcon
    local iconPos = db.iconPosition or "LEFT"

    iconFrame:SetSize(iconSize, iconSize)

    if showIcon then
        iconFrame:Show()
        iconFrame:ClearAllPoints()
        progressBar:ClearAllPoints()

        if iconPos == "LEFT" then
            iconFrame:SetPoint("LEFT", castBarFrame, "LEFT", 0, 0)
            progressBar:SetPoint("LEFT", iconFrame, "RIGHT", 1, 0)
            progressBar:SetPoint("RIGHT", castBarFrame, "RIGHT", 0, 0)
            progressBar:SetPoint("TOP", castBarFrame, "TOP", 0, 0)
            progressBar:SetPoint("BOTTOM", castBarFrame, "BOTTOM", 0, 0)
        elseif iconPos == "RIGHT" then
            iconFrame:SetPoint("RIGHT", castBarFrame, "RIGHT", 0, 0)
            progressBar:SetPoint("LEFT", castBarFrame, "LEFT", 0, 0)
            progressBar:SetPoint("RIGHT", iconFrame, "LEFT", -1, 0)
            progressBar:SetPoint("TOP", castBarFrame, "TOP", 0, 0)
            progressBar:SetPoint("BOTTOM", castBarFrame, "BOTTOM", 0, 0)
        elseif iconPos == "TOP" then
            iconFrame:SetPoint("BOTTOM", castBarFrame, "TOP", 0, 1)
            progressBar:SetAllPoints(castBarFrame)
        elseif iconPos == "BOTTOM" then
            iconFrame:SetPoint("TOP", castBarFrame, "BOTTOM", 0, -1)
            progressBar:SetAllPoints(castBarFrame)
        else
            -- Default to LEFT
            iconFrame:SetPoint("LEFT", castBarFrame, "LEFT", 0, 0)
            progressBar:SetPoint("LEFT", iconFrame, "RIGHT", 1, 0)
            progressBar:SetPoint("RIGHT", castBarFrame, "RIGHT", 0, 0)
            progressBar:SetPoint("TOP", castBarFrame, "TOP", 0, 0)
            progressBar:SetPoint("BOTTOM", castBarFrame, "BOTTOM", 0, 0)
        end
    else
        iconFrame:Hide()
        progressBar:ClearAllPoints()
        progressBar:SetAllPoints(castBarFrame)
    end

    -- Update background color
    local bgR, bgG, bgB = W.GetEffectiveColor(db, "bgColorR", "bgColorG", "bgColorB", "bgColorUseClassColor")
    bgTexture:SetVertexColor(bgR, bgG, bgB, db.bgAlpha)

    -- Re-anchor text frame to follow progressBar
    textFrame:ClearAllPoints()
    textFrame:SetAllPoints(progressBar)

    -- Update text settings
    local fontPath = db.font or "Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf"
    local fontSize = db.fontSize or 12
    spellNameText:SetFont(fontPath, fontSize, "OUTLINE")
    castTimeText:SetFont(fontPath, fontSize, "OUTLINE")
    local tcR, tcG, tcB = W.GetEffectiveColor(db, "textColorR", "textColorG", "textColorB", "textColorUseClassColor")
    spellNameText:SetTextColor(tcR, tcG, tcB)
    castTimeText:SetTextColor(tcR, tcG, tcB)

    -- Show/hide text elements
    if db.showSpellName then
        spellNameText:Show()
    else
        spellNameText:Hide()
    end

    if db.showTimeRemaining then
        castTimeText:Show()
    else
        castTimeText:Hide()
    end
end

-- Hide empower stage markers
local function HideEmpowerStages()
    for i, marker in ipairs(empowerMarkers) do
        marker:Hide()
    end
end

-- Show empower stage markers
local function UpdateEmpowerStages(numStages)
    local db = NaowhQOL.focusCastBar
    if not db or not db.showEmpowerStages then
        HideEmpowerStages()
        return
    end

    local barWidth = progressBar:GetWidth()

    for i = 1, numStages - 1 do
        local marker = empowerMarkers[i]
        if not marker then
            marker = progressBar:CreateTexture(nil, "OVERLAY")
            marker:SetTexture([[Interface\Buttons\WHITE8X8]])
            marker:SetVertexColor(1, 1, 1, 0.8)
            marker:SetWidth(2)
            empowerMarkers[i] = marker
        end

        local xOffset = (barWidth / numStages) * i
        marker:ClearAllPoints()
        marker:SetPoint("TOP", progressBar, "TOPLEFT", xOffset, 0)
        marker:SetPoint("BOTTOM", progressBar, "BOTTOMLEFT", xOffset, 0)
        marker:Show()
    end

    -- Hide extra markers
    for i = numStages, #empowerMarkers do
        if empowerMarkers[i] then
            empowerMarkers[i]:Hide()
        end
    end
end

-- Play audio alert
local function PlayAudioAlert()
    local db = NaowhQOL.focusCastBar
    if not db then return end

    if db.soundEnabled and db.sound then
        ns.SoundList.Play(db.sound)
    elseif db.ttsEnabled and db.ttsMessage and db.ttsMessage ~= "" then
        local voiceID = db.ttsVoiceID or 0
        local rate = db.ttsRate or 0
        local volume = db.ttsVolume or 50
        C_VoiceChat.SpeakText(voiceID, db.ttsMessage, rate, volume, true)
    end
end

-- Track current notInterruptible state (secret value) and a flag for whether we have one
local currentNotInterruptible = nil
local hasSecretInterruptible = false

-- Check if focus target is friendly
local function IsFocusFriendly()
    return UnitExists("focus") and UnitIsFriend("player", "focus")
end

-- Start tracking a regular cast
local function StartCast(notInterruptible, texture, text, startTime, endTime)
    local db = NaowhQOL.focusCastBar
    if not db or not db.enabled then return end

    -- Filter out friendly unit casts if enabled
    if db.hideFriendlyCasts and IsFocusFriendly() then return end

    isCasting = true
    isChanneling = false
    currentNotInterruptible = notInterruptible
    hasSecretInterruptible = true

    -- Update icon (SetTexture accepts restricted values)
    if db.showIcon then
        iconTexture:SetTexture(texture)
    end

    -- Update spell name (SetText accepts restricted values)
    if db.showSpellName and text then
        spellNameText:SetText(text)
    end

    HideEmpowerStages()

    -- Only use interrupt cooldown coloring if not using non-interruptible color mode
    if not db.colorNonInterrupt then
        UpdateBarColor()
    end

    local duration = UnitCastingDuration("focus")
    if duration then
        progressBar:SetMinMaxValues(0, 1)
        progressBar:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, Enum.StatusBarTimerDirection.ElapsedTime)
        if db.showTimeRemaining then
            local remain = duration:GetRemainingDuration()
            castTimeText:SetFormattedText('%.1f', remain)
        end
    end

    castBarFrame:Show()
    UpdateInterruptibleDisplay()

    PlayAudioAlert()
end

-- Start tracking a channeled cast
local function StartChannel(notInterruptible, numEmpowerStages, texture, text, startTime, endTime)
    local db = NaowhQOL.focusCastBar
    if not db or not db.enabled then return end

    -- Filter out friendly unit casts if enabled
    if db.hideFriendlyCasts and IsFocusFriendly() then return end

    isCasting = false
    isChanneling = true
    currentNotInterruptible = notInterruptible
    hasSecretInterruptible = true

    -- Update icon (SetTexture accepts restricted values)
    if db.showIcon then
        iconTexture:SetTexture(texture)
    end

    -- Update spell name (SetText accepts restricted values)
    if db.showSpellName and text then
        spellNameText:SetText(text)
    end

    -- Handle empowered channels (numEmpowerStages may be nil for non-empowered)
    HideEmpowerStages()
    if numEmpowerStages then
        pcall(function()
            if numEmpowerStages > 0 then
                UpdateEmpowerStages(numEmpowerStages)
            end
        end)
    end

    -- Only use interrupt cooldown coloring if not using non-interruptible color mode
    if not db.colorNonInterrupt then
        UpdateBarColor()
    end

    local duration = UnitChannelDuration("focus")
    if duration then
        progressBar:SetMinMaxValues(0, 1)
        progressBar:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, Enum.StatusBarTimerDirection.RemainingTime)
        if db.showTimeRemaining then
            local remain = duration:GetRemainingDuration()
            castTimeText:SetFormattedText('%.1f', remain)
        end
    end

    castBarFrame:Show()
    UpdateInterruptibleDisplay()

    PlayAudioAlert()
end

-- Stop tracking cast
local function StopCast()
    isCasting = false
    isChanneling = false
    currentNotInterruptible = nil
    hasSecretInterruptible = false
    HideEmpowerStages()
    shieldIcon:SetAlpha(0)
    nonIntOverlay:SetAlpha(0)
    local db = NaowhQOL.focusCastBar
    if not db or not db.unlock then
        castBarFrame:Hide()
    end
end

-- Check if focus currently has an active cast
local function CheckFocusCast()
    if not UnitExists("focus") then
        StopCast()
        return
    end

    -- Check for regular cast using duration (non-secret)
    local castDuration = UnitCastingDuration("focus")
    if castDuration then
        local name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible = UnitCastingInfo("focus")
        StartCast(notInterruptible, texture, text, startTime, endTime)
        return
    end

    -- Check for channel using duration (non-secret)
    local channelDuration = UnitChannelDuration("focus")
    if channelDuration then
        local name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID, _, numStages = UnitChannelInfo("focus")
        StartChannel(notInterruptible, numStages, texture, text, startTime, endTime)
        return
    end

    StopCast()
end

-- Update display state
function castBarFrame:UpdateDisplay()
    local db = NaowhQOL.focusCastBar
    if not db then return end

    if not db.enabled then
        castBarFrame:SetBackdrop(nil)
        if resizeHandle then resizeHandle:Hide() end
        castBarFrame:Hide()
        return
    end

    castBarFrame:EnableMouse(db.unlock)
    if db.unlock then
        castBarFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        })
        castBarFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        if resizeHandle then resizeHandle:Show() end

        -- Show preview when unlocked
        spellNameText:SetText(L["FOCUS_PREVIEW_CAST"])
        castTimeText:SetText(L["FOCUS_PREVIEW_TIME"])
        progressBar:SetValue(0.5)
        iconTexture:SetTexture(136243)  -- Generic spell icon
        castBarFrame:Show()
    else
        castBarFrame:SetBackdrop(nil)
        if resizeHandle then resizeHandle:Hide() end

        if not isCasting and not isChanneling then
            castBarFrame:Hide()
        end
    end

    -- Always apply saved size
    local width = db.width or 250
    local height = db.height or 24
    castBarFrame:SetSize(width, height)

    if not castBarFrame.initialized then
        castBarFrame:ClearAllPoints()
        local point = db.point or "CENTER"
        local x = db.x or 0
        local y = db.y or 100
        castBarFrame:SetPoint(point, UIParent, point, x, y)

        castBarFrame.initialized = true
    end

    UpdateLayout()
    UpdateBarColor()
end

-- OnUpdate loop for interrupt CD color and time display updates
local THROTTLE = 0.033  -- ~30 FPS
local updateElapsed = 0

castBarFrame:SetScript("OnUpdate", ns.PerfMonitor:Wrap("Focus Cast Bar", function(self, dt)
    updateElapsed = updateElapsed + dt
    if updateElapsed < THROTTLE then return end

    local db = NaowhQOL.focusCastBar
    if not db or not db.enabled then return end

    UpdateBarColor()

    -- Update time display
    if db.showTimeRemaining then
        local duration
        if isCasting then
            duration = UnitCastingDuration("focus")
        elseif isChanneling then
            duration = UnitChannelDuration("focus")
        end
        if duration then
            local remain = duration:GetRemainingDuration()
            castTimeText:SetFormattedText('%.1f', remain)
        end
    end

    updateElapsed = 0
end))

-- Event handler
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
loader:RegisterEvent("PLAYER_FOCUS_CHANGED")
loader:RegisterUnitEvent("UNIT_SPELLCAST_START", "focus")
loader:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "focus")
loader:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "focus")
loader:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "focus")
loader:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "focus")
loader:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "focus")
loader:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", "focus")
loader:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "focus")
loader:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", "focus")
loader:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "focus")

loader:SetScript("OnEvent", function(self, event, unit, ...)
    local db = NaowhQOL.focusCastBar

    if event == "PLAYER_LOGIN" then
        if not db then return end

        db.width = db.width or 250
        db.height = db.height or 24
        db.point = db.point or "CENTER"
        db.x = db.x or 0
        db.y = db.y or 100

        W.MakeDraggable(castBarFrame, { db = db })
        resizeHandle = W.CreateResizeHandle(castBarFrame, {
            db = db,
            onResize = function()
                UpdateLayout()
                UpdateEmpowerStages(#empowerMarkers + 1)
            end,
        })

        castBarFrame.initialized = false
        castBarFrame:UpdateDisplay()

        -- Cache interrupt spell ID
        GetInterruptSpellId()
        return
    end

    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        -- Clear cached interrupt spell on spec change
        cachedInterruptSpellId = nil
        GetInterruptSpellId()
        return
    end

    if not db or not db.enabled then return end

    -- When unlocked, keep showing the preview - don't process cast events
    if db.unlock then return end

    if event == "PLAYER_FOCUS_CHANGED" then
        CheckFocusCast()
        return
    end

    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_DELAYED" then
        local name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible = UnitCastingInfo("focus")
        StartCast(notInterruptible, texture, text, startTime, endTime)

    elseif event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        local name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID, _, numStages = UnitChannelInfo("focus")
        StartChannel(notInterruptible, numStages, texture, text, startTime, endTime)

    elseif event == "UNIT_SPELLCAST_STOP"
        or event == "UNIT_SPELLCAST_CHANNEL_STOP"
        or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_INTERRUPTED" then
        StopCast()

    elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
        -- Cast became interruptible mid-cast
        currentNotInterruptible = false
        hasSecretInterruptible = true
        if isCasting or isChanneling then
            UpdateInterruptibleDisplay()
        end

    elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
        -- Cast became uninterruptible (shield applied)
        currentNotInterruptible = true
        hasSecretInterruptible = true
        if isCasting or isChanneling then
            UpdateInterruptibleDisplay()
        end
    end
end)

-- Export to namespace
ns.FocusCastBarDisplay = castBarFrame
