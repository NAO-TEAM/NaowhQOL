local addonName, ns = ...
local W = ns.Widgets
local L = ns.LayoutUtil

local VIGOR_SPELL = 372608
local SECOND_WIND_SPELL = 425782
local WHIRLING_SURGE_SPELL = 361584

-- Speed scaling: converts raw gliding speed to 0-1 range (max speed ~85)
local SPEED_RECIPROCAL = 0.01176
-- Display multiplier: converts raw speed to percentage shown to users
local SPEED_DISPLAY_FACTOR = 14.285
-- Vigor regen threshold: cooldown <= this means "Thrill of the Skies" active
local THRILL_THRESHOLD = 6.003
-- Ground Skim vigor recovery duration (exact game value)
local GROUND_SKIM_DURATION = 8.28
-- Update frequency (~30 Hz)
local THROTTLE = 0.0333
local NUM_CHARGES = 6
local BAR_TEXTURE = [[Interface\Buttons\WHITE8x8]]

local COLOR_PRESETS = {
    Classic = {
        charge     = { r = 0.01, g = 0.56, b = 0.91 },
        thrill     = { r = 1.00, g = 0.66, b = 0.00 },
        groundSkim = { r = 1.00, g = 0.80, b = 0.20 },
        lowSpeed   = { r = 0.00, g = 0.49, b = 0.79 },
        secondWind = { r = 0.00, g = 0.49, b = 0.79 },
        background = { r = 0.12, g = 0.12, b = 0.12 },
        border     = { r = 0.00, g = 0.00, b = 0.00 },
    },
}

-- Default values for all config options
local DEFAULTS = {
    barWidth = 36, speedHeight = 14, chargeHeight = 14, gap = 0,
    showSpeedText = true, swapPosition = false, hideWhenGroundedFull = false,
    showSecondWind = true, showWhirlingSurge = true, colorPreset = "Classic",
    unlocked = false, point = "BOTTOM", posX = 0, posY = 200,
    barStyle = [[Interface\Buttons\WHITE8X8]],
    speedColorR = 0.00, speedColorG = 0.49, speedColorB = 0.79,
    thrillColorR = 1.00, thrillColorG = 0.66, thrillColorB = 0.00,
    chargeColorR = 0.01, chargeColorG = 0.56, chargeColorB = 0.91,
    speedFont = "Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf",
    speedFontSize = 12, surgeIconSize = 0, surgeAnchor = "RIGHT",
    surgeOffsetX = 6, surgeOffsetY = 0, anchorFrame = "UIParent", anchorTo = "BOTTOM",
    matchAnchorWidth = false,
    bgColorR = 0.12, bgColorG = 0.12, bgColorB = 0.12, bgAlpha = 0.8,
    borderColorR = 0, borderColorG = 0, borderColorB = 0, borderAlpha = 1, borderSize = 1,
    iconBorderColorR = 0, iconBorderColorG = 0, iconBorderColorB = 0, iconBorderAlpha = 1, iconBorderSize = 1,
    hideCdmWhileMounted = false,
}

-- Get config value with default fallback
local function Get(key)
    local db = NaowhQOL.dragonriding
    if db and db[key] ~= nil then return db[key] end
    return DEFAULTS[key]
end

local prevSpeed = 0
local elapsed = 0
local lastColorState = nil
local uiBuilt = false
local stashedPosition = nil

local mainFrame
local speedBar, speedText
local chargeBars = {}
local chargeDividers = {}
local secondWindBars = {}
local surgeFrame, surgeCooldown, surgeBorder
local eventFrame
local pendingCdmShow = false
local pendingCdmHide = false

local function IsEnabled()
    return NaowhQOL.dragonriding and NaowhQOL.dragonriding.enabled
end

local eventsRegistered = false
local DYNAMIC_EVENTS = {
    "ACTIONBAR_UPDATE_COOLDOWN",
    "ACTIONBAR_UPDATE_STATE",
    "UPDATE_BONUS_ACTIONBAR",
    "PLAYER_CAN_GLIDE_CHANGED",
    "PLAYER_IS_GLIDING_CHANGED",
}

local function RegisterDynamicEvents()
    if eventsRegistered or not eventFrame then return end
    for _, event in ipairs(DYNAMIC_EVENTS) do
        eventFrame:RegisterEvent(event)
    end
    eventsRegistered = true
end

local function UnregisterDynamicEvents()
    if not eventsRegistered or not eventFrame then return end
    for _, event in ipairs(DYNAMIC_EVENTS) do
        eventFrame:UnregisterEvent(event)
    end
    eventsRegistered = false
end

local CDM_FRAMES = {
    BuffIconCooldownViewer = true,
    EssentialCooldownViewer = true,
    UtilityCooldownViewer = true,
}

local function IsAnchoredToCDM()
    return CDM_FRAMES[Get("anchorFrame")] == true
end

local function StashPositionAndReanchor()
    if not mainFrame or stashedPosition then return end
    if not IsAnchoredToCDM() then return end

    local x, y = mainFrame:GetCenter()
    if not x or not y then return end
    stashedPosition = { x = x, y = y }

    local uiWidth, uiHeight = UIParent:GetSize()
    local offsetX = x - (uiWidth / 2)
    local offsetY = y - (uiHeight / 2)

    mainFrame:ClearAllPoints()
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", offsetX, offsetY)
end

local function RestoreOriginalAnchor()
    if not mainFrame or not stashedPosition then return end
    stashedPosition = nil

    mainFrame:ClearAllPoints()
    local anchorParent = L.GetAnchorFrame(Get("anchorFrame")) or UIParent
    mainFrame:SetPoint(Get("point"), anchorParent, Get("anchorTo"), Get("posX"), Get("posY"))
end

local function IsSkyriding()
    if GetBonusBarIndex() == 11 and GetBonusBarOffset() == 5 then
        return true
    end
    if UnitPowerBarID("player") == 650 then return false end
    local _, canGlide = C_PlayerInfo.GetGlidingInfo()
    return canGlide and UnitPowerBarID("player") ~= 0
end

local function IsGliding()
    local gliding = C_PlayerInfo.GetGlidingInfo()
    return gliding
end

local function GetForwardSpeed()
    local _, _, spd = C_PlayerInfo.GetGlidingInfo()
    return spd or 0
end

local function GetVigorInfo()
    local data = C_Spell.GetSpellCharges(VIGOR_SPELL)
    if not data then return 0, 6, 0, 0, false, false end
    local isThrill = data.cooldownDuration > 0 and data.cooldownDuration <= THRILL_THRESHOLD
    local isGroundSkim = math.abs(data.cooldownDuration - GROUND_SKIM_DURATION) < 0.05 and not isThrill
    return data.currentCharges, data.maxCharges,
           data.cooldownStartTime, data.cooldownDuration,
           isThrill, isGroundSkim
end

local function GetSecondWindCharges()
    local data = C_Spell.GetSpellCharges(SECOND_WIND_SPELL)
    if not data then return 0 end
    return data.currentCharges
end

local function GetWhirlingSurgeCooldown()
    local data = C_Spell.GetSpellCooldown(WHIRLING_SURGE_SPELL)
    if not data then return 0, 0 end
    return data.startTime, data.duration
end

local function GetPreset()
    return COLOR_PRESETS[Get("colorPreset")] or COLOR_PRESETS.Classic
end

local function ApplyColors(isThrill, isGroundSkim)
    local state = isThrill and "thrill" or (isGroundSkim and "groundSkim" or "lowSpeed")
    if state == lastColorState then return end
    lastColorState = state

    local db = NaowhQOL.dragonriding or {}
    if isThrill then
        local r, g, b = W.GetEffectiveColor(db, "thrillColorR", "thrillColorG", "thrillColorB", "thrillColorUseClassColor")
        speedBar:SetStatusBarColor(r, g, b)
    else
        local r, g, b = W.GetEffectiveColor(db, "speedColorR", "speedColorG", "speedColorB", "speedColorUseClassColor")
        speedBar:SetStatusBarColor(r, g, b)
    end

    local cr, cg, cb = W.GetEffectiveColor(db, "chargeColorR", "chargeColorG", "chargeColorB", "chargeColorUseClassColor")
    for i = 1, NUM_CHARGES do
        chargeBars[i]:SetStatusBarColor(cr, cg, cb)
    end
end

local function UpdateLayout()
    if not mainFrame then return end
    local db = NaowhQOL.dragonriding or {}
    local speedHeight = Get("speedHeight")
    local chargeHeight = Get("chargeHeight")
    local gap = Get("gap")
    local totalHeight = speedHeight + gap + chargeHeight

    -- Update anchor position
    mainFrame:ClearAllPoints()
    local anchorParent = L.GetAnchorFrame(Get("anchorFrame")) or UIParent
    mainFrame:SetPoint(Get("point"), anchorParent, Get("anchorTo"), Get("posX"), Get("posY"))

    -- Calculate widths (match anchor width if enabled)
    local barWidthCfg = Get("barWidth")
    local totalWidth = NUM_CHARGES * barWidthCfg + (NUM_CHARGES - 1) * gap
    local barWidth = barWidthCfg
    local borderSize = Get("borderSize")

    if Get("matchAnchorWidth") and anchorParent ~= UIParent then
        local anchorWidth = anchorParent:GetWidth()
        if anchorWidth and anchorWidth > 0 then
            -- Subtract border so total frame width matches anchor exactly
            totalWidth = anchorWidth - (borderSize * 2)
            barWidth = (totalWidth - (NUM_CHARGES - 1) * gap) / NUM_CHARGES
        end
    end
    -- Enlarge frame to include border outside content area
    mainFrame:SetSize(totalWidth + borderSize * 2, totalHeight + borderSize * 2)
    mainFrame:SetBackdrop({
        bgFile = BAR_TEXTURE,
        edgeFile = BAR_TEXTURE,
        edgeSize = borderSize,
        insets = { left = borderSize, right = borderSize, top = borderSize, bottom = borderSize }
    })
    local bgR, bgG, bgB = W.GetEffectiveColor(db, "bgColorR", "bgColorG", "bgColorB", "bgColorUseClassColor")
    local brR, brG, brB = W.GetEffectiveColor(db, "borderColorR", "borderColorG", "borderColorB", "borderColorUseClassColor")
    mainFrame:SetBackdropColor(bgR, bgG, bgB, Get("bgAlpha"))
    mainFrame:SetBackdropBorderColor(brR, brG, brB, Get("borderAlpha"))

    local swapPosition = Get("swapPosition")
    local speedY = swapPosition and -borderSize or -(chargeHeight + gap + borderSize)
    local chargeY = swapPosition and -(speedHeight + gap + borderSize) or -borderSize

    speedBar:ClearAllPoints()
    speedBar:SetSize(totalWidth, speedHeight)
    speedBar:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", borderSize, speedY)

    speedText:SetShown(Get("showSpeedText"))
    speedText:SetFont(Get("speedFont"), Get("speedFontSize"), "OUTLINE")

    for i = 1, NUM_CHARGES do
        local xOff = borderSize + (i - 1) * (barWidth + gap)

        secondWindBars[i]:ClearAllPoints()
        secondWindBars[i]:SetSize(barWidth, chargeHeight)
        secondWindBars[i]:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", xOff, chargeY)

        chargeBars[i]:ClearAllPoints()
        chargeBars[i]:SetSize(barWidth, chargeHeight)
        chargeBars[i]:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", xOff, chargeY)

        -- Position divider at the right edge of each bar (except last)
        if chargeDividers[i] then
            chargeDividers[i]:ClearAllPoints()
            chargeDividers[i]:SetSize(1, chargeHeight)
            chargeDividers[i]:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", xOff + barWidth, chargeY)
        end
    end

    if surgeFrame then
        surgeFrame:ClearAllPoints()
        local surgeIconSize = Get("surgeIconSize")
        local iconSize = surgeIconSize > 0 and surgeIconSize or (chargeHeight + speedHeight + gap)
        surgeFrame:SetSize(iconSize, iconSize)

        local anchor = Get("surgeAnchor")
        local ox, oy = Get("surgeOffsetX"), Get("surgeOffsetY")
        if anchor == "LEFT" then
            surgeFrame:SetPoint("RIGHT", mainFrame, "LEFT", -ox, oy)
        elseif anchor == "TOP" then
            surgeFrame:SetPoint("BOTTOM", mainFrame, "TOP", ox, oy)
        elseif anchor == "BOTTOM" then
            surgeFrame:SetPoint("TOP", mainFrame, "BOTTOM", ox, -oy)
        else
            surgeFrame:SetPoint("LEFT", mainFrame, "RIGHT", ox, oy)
        end
        surgeFrame:SetShown(Get("showWhirlingSurge"))

        if surgeBorder then
            local iconBorderSize = Get("iconBorderSize")
            surgeBorder:ClearAllPoints()
            surgeBorder:SetPoint("TOPLEFT", surgeFrame, "TOPLEFT", -iconBorderSize, iconBorderSize)
            surgeBorder:SetPoint("BOTTOMRIGHT", surgeFrame, "BOTTOMRIGHT", iconBorderSize, -iconBorderSize)
            surgeBorder:SetBackdrop({
                edgeFile = BAR_TEXTURE,
                edgeSize = iconBorderSize,
            })
            local ibR, ibG, ibB = W.GetEffectiveColor(db, "iconBorderColorR", "iconBorderColorG", "iconBorderColorB", "iconBorderColorUseClassColor")
            surgeBorder:SetBackdropBorderColor(ibR, ibG, ibB, Get("iconBorderAlpha"))
        end
    end

    -- Apply bar style to all status bars
    local barTex = Get("barStyle") or BAR_TEXTURE
    speedBar:SetStatusBarTexture(barTex)
    for i = 1, NUM_CHARGES do
        secondWindBars[i]:SetStatusBarTexture(barTex)
        chargeBars[i]:SetStatusBarTexture(barTex)
    end

    -- Apply charge colors
    lastColorState = nil
end

local function UpdateSpeedBar(rawSpeed)
    local scaled = math.min(rawSpeed * SPEED_RECIPROCAL, 1.0)
    prevSpeed = prevSpeed + (scaled - prevSpeed) * 0.15
    speedBar:SetValue(prevSpeed)

    if Get("showSpeedText") then
        local display = math.floor(rawSpeed * SPEED_DISPLAY_FACTOR)
        speedText:SetText(display > 0 and tostring(display) or "")
    end
end

local function UpdateCharges(charges, maxCharges, startTime, duration)
    local now = GetTime()
    for i = 1, NUM_CHARGES do
        if i > maxCharges then
            chargeBars[i]:SetValue(0)
        elseif i <= charges then
            chargeBars[i]:SetValue(1)
        elseif i == charges + 1 and duration > 0 and startTime > 0 then
            local progress = (now - startTime) / duration
            chargeBars[i]:SetValue(math.min(progress, 1))
        else
            chargeBars[i]:SetValue(0)
        end
    end
end

local function UpdateSecondWind(charges, totalFilled)
    if not Get("showSecondWind") then
        for i = 1, NUM_CHARGES do
            secondWindBars[i]:SetValue(0)
        end
        return
    end
    for i = 1, NUM_CHARGES do
        secondWindBars[i]:SetValue(i <= totalFilled and 1 or 0)
    end
end

local function UpdateWhirlingSurge(startTime, duration)
    if not Get("showWhirlingSurge") or not surgeFrame then
        if surgeFrame then surgeFrame:Hide() end
        return
    end
    surgeFrame:Show()
    if startTime > 0 and duration > 0 then
        surgeCooldown:SetCooldown(startTime, duration)
    end
end

local cdmHidden = false
local function HideCooldownManager()
    if cdmHidden then return end
    local success = pcall(function()
        StashPositionAndReanchor()
        cdmHidden = true
        if BuffIconCooldownViewer then BuffIconCooldownViewer:Hide() end
        if EssentialCooldownViewer then EssentialCooldownViewer:Hide() end
        if UtilityCooldownViewer then UtilityCooldownViewer:Hide() end
    end)
    if not success and InCombatLockdown() then
        cdmHidden = false
        pendingCdmHide = true
        pendingCdmShow = false
    end
end

local function ShowCooldownManager()
    if not cdmHidden then return end
    local success = pcall(function()
        cdmHidden = false
        if BuffIconCooldownViewer then BuffIconCooldownViewer:Show() end
        if EssentialCooldownViewer then EssentialCooldownViewer:Show() end
        if UtilityCooldownViewer then UtilityCooldownViewer:Show() end
        RestoreOriginalAnchor()
    end)
    if not success and InCombatLockdown() then
        cdmHidden = true
        pendingCdmShow = true
        pendingCdmHide = false
    end
end

local OnUpdate = ns.PerfMonitor:Wrap("Dragonriding", function(self, dt)
    elapsed = elapsed + dt
    if elapsed < THROTTLE then return end
    elapsed = 0

    if not mainFrame or not speedBar then return end

    if not IsEnabled() or not IsSkyriding() then
        mainFrame:SetAlpha(0)
        mainFrame:Hide()
        eventFrame:SetScript("OnUpdate", nil)
        prevSpeed = 0
        lastColorState = nil
        if Get("hideCdmWhileMounted") then
            ShowCooldownManager()
        end
        return
    end

    local charges, maxCharges, startTime, duration, isThrill, isGroundSkim = GetVigorInfo()

    if Get("hideWhenGroundedFull") and not IsGliding() and charges >= maxCharges then
        mainFrame:SetAlpha(0)
        mainFrame:Hide()
        eventFrame:SetScript("OnUpdate", nil)
        if Get("hideCdmWhileMounted") then
            ShowCooldownManager()
        end
        return
    end

    mainFrame:Show()
    mainFrame:SetAlpha(1)

    if Get("hideCdmWhileMounted") then
        HideCooldownManager()
    end

    UpdateSpeedBar(GetForwardSpeed())
    UpdateCharges(charges, maxCharges, startTime, duration)
    ApplyColors(isThrill, isGroundSkim)

    if Get("showSecondWind") then
        local swCharges = GetSecondWindCharges()
        UpdateSecondWind(charges, charges + swCharges)
    else
        UpdateSecondWind(0, 0)
    end

    if Get("showWhirlingSurge") then
        local sStart, sDur = GetWhirlingSurgeCooldown()
        UpdateWhirlingSurge(sStart, sDur)
    else
        UpdateWhirlingSurge(0, 0)
    end
end)

local function ActivateUpdater()
    if not mainFrame then return end
    if not IsEnabled() then return end
    eventFrame:SetScript("OnUpdate", OnUpdate)
end

local function BuildUI()
    if uiBuilt then return end
    uiBuilt = true

    local db = NaowhQOL.dragonriding or {}
    local preset = GetPreset()

    mainFrame = CreateFrame("Frame", "NaowhQOL_Dragonriding", UIParent, "BackdropTemplate")
    mainFrame:SetFrameStrata("MEDIUM")
    mainFrame:SetFrameLevel(100)
    mainFrame:SetClampedToScreen(true)
    local borderSize = Get("borderSize")
    mainFrame:SetBackdrop({
        bgFile = BAR_TEXTURE,
        edgeFile = BAR_TEXTURE,
        edgeSize = borderSize,
        insets = { left = borderSize, right = borderSize, top = borderSize, bottom = borderSize }
    })
    local bgR, bgG, bgB = W.GetEffectiveColor(db, "bgColorR", "bgColorG", "bgColorB", "bgColorUseClassColor")
    local brR, brG, brB = W.GetEffectiveColor(db, "borderColorR", "borderColorG", "borderColorB", "borderColorUseClassColor")
    mainFrame:SetBackdropColor(bgR, bgG, bgB, Get("bgAlpha"))
    mainFrame:SetBackdropBorderColor(brR, brG, brB, Get("borderAlpha"))

    W.MakeDraggable(mainFrame, {
        db = NaowhQOL.dragonriding,
        unlockKey = "unlocked",
        pointKey = "point",
        anchorToKey = "anchorTo",
        xKey = "posX",
        yKey = "posY",
        userPlaced = false,
    })

    speedBar = CreateFrame("StatusBar", nil, mainFrame)
    speedBar:SetStatusBarTexture(BAR_TEXTURE)
    speedBar:SetMinMaxValues(0, 1)
    speedBar:SetValue(0)
    local sR, sG, sB = W.GetEffectiveColor(db, "speedColorR", "speedColorG", "speedColorB", "speedColorUseClassColor")
    speedBar:SetStatusBarColor(sR, sG, sB)

    local speedTextFrame = CreateFrame("Frame", nil, mainFrame)
    speedTextFrame:SetAllPoints()
    speedTextFrame:SetFrameLevel(mainFrame:GetFrameLevel() + 10)

    speedText = speedTextFrame:CreateFontString(nil, "OVERLAY")
    speedText:SetFont(Get("speedFont"), Get("speedFontSize"), "OUTLINE")
    speedText:SetJustifyH("RIGHT")
    speedText:SetJustifyV("MIDDLE")
    speedText:SetPoint("RIGHT", mainFrame, "RIGHT", -2, 0)
    speedText:SetText("")

    for i = 1, NUM_CHARGES do
        local sw = CreateFrame("StatusBar", nil, mainFrame)
        sw:SetStatusBarTexture(BAR_TEXTURE)
        sw:SetMinMaxValues(0, 1)
        sw:SetValue(0)
        sw:SetStatusBarColor(preset.secondWind.r, preset.secondWind.g, preset.secondWind.b, 0.5)
        secondWindBars[i] = sw

        local cb = CreateFrame("StatusBar", nil, mainFrame)
        cb:SetStatusBarTexture(BAR_TEXTURE)
        cb:SetMinMaxValues(0, 1)
        cb:SetValue(0)
        cb:SetFrameLevel(sw:GetFrameLevel() + 1)
        cb:SetStatusBarColor(preset.charge.r, preset.charge.g, preset.charge.b)
        chargeBars[i] = cb

    end

    -- Create divider container at higher frame level
    local dividerFrame = CreateFrame("Frame", nil, mainFrame)
    dividerFrame:SetAllPoints()
    dividerFrame:SetFrameLevel(mainFrame:GetFrameLevel() + 5)

    for i = 1, NUM_CHARGES - 1 do
        local divider = dividerFrame:CreateTexture(nil, "OVERLAY")
        divider:SetColorTexture(0, 0, 0, 1)
        chargeDividers[i] = divider
    end

    surgeFrame = CreateFrame("Frame", nil, mainFrame)
    surgeFrame:SetFrameLevel(mainFrame:GetFrameLevel() + 2)

    local icon = C_Spell.GetSpellTexture(WHIRLING_SURGE_SPELL) or 134400
    local surgeIcon = surgeFrame:CreateTexture(nil, "ARTWORK")
    surgeIcon:SetAllPoints()
    surgeIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    surgeIcon:SetTexture(icon)

    surgeCooldown = CreateFrame("Cooldown", nil, surgeFrame, "CooldownFrameTemplate")
    surgeCooldown:SetPoint("TOPLEFT", surgeFrame, "TOPLEFT", 0, 1)
    surgeCooldown:SetPoint("BOTTOMRIGHT", surgeFrame, "BOTTOMRIGHT", 0, 0)
    surgeCooldown:SetDrawEdge(false)
    surgeCooldown:SetDrawBling(false)
    surgeCooldown:SetSwipeColor(0, 0, 0, 0.8)
    surgeCooldown:SetHideCountdownNumbers(false)

    surgeBorder = CreateFrame("Frame", nil, surgeFrame, "BackdropTemplate")
    surgeBorder:SetFrameLevel(surgeFrame:GetFrameLevel() + 3)
    -- Border positioning handled by UpdateLayout()

    mainFrame:ClearAllPoints()
    local anchorParent = L.GetAnchorFrame(Get("anchorFrame")) or UIParent
    mainFrame:SetPoint(Get("point"), anchorParent, Get("anchorTo"), Get("posX"), Get("posY"))

    UpdateLayout()

    -- Schedule a delayed layout refresh when matching anchor width
    -- Anchor frames may not have their final size immediately on reload
    if Get("matchAnchorWidth") and anchorParent ~= UIParent then
        C_Timer.After(0.1, function()
            if mainFrame then
                UpdateLayout()
            end
        end)
    end
    mainFrame:Hide()
end

local function ShowPreview()
    if not mainFrame then return end
    eventFrame:SetScript("OnUpdate", nil)
    mainFrame:Show()
    mainFrame:SetAlpha(1)

    local db = NaowhQOL.dragonriding or {}
    speedBar:SetValue(0.65)
    local tR, tG, tB = W.GetEffectiveColor(db, "thrillColorR", "thrillColorG", "thrillColorB", "thrillColorUseClassColor")
    speedBar:SetStatusBarColor(tR, tG, tB)
    if Get("showSpeedText") then
        speedText:SetText("456")
    end

    local cR, cG, cB = W.GetEffectiveColor(db, "chargeColorR", "chargeColorG", "chargeColorB", "chargeColorUseClassColor")
    for i = 1, NUM_CHARGES do
        if i <= 4 then
            chargeBars[i]:SetValue(1)
        elseif i == 5 then
            chargeBars[i]:SetValue(0.6)
        else
            chargeBars[i]:SetValue(0)
        end
        chargeBars[i]:SetStatusBarColor(cR, cG, cB)
        secondWindBars[i]:SetValue(i <= 5 and 1 or 0)
    end

    lastColorState = nil
end

function ns:HideDragonridingPreview()
    if not mainFrame or not uiBuilt then return end
    prevSpeed = 0
    lastColorState = nil
    if IsEnabled() then
        RegisterDynamicEvents()
        ActivateUpdater()
    else
        mainFrame:Hide()
        mainFrame:SetAlpha(0)
        eventFrame:SetScript("OnUpdate", nil)
        UnregisterDynamicEvents()
    end
end

function ns:RefreshDragonridingLayout()
    if not uiBuilt then
        if not C_PlayerInfo or not C_PlayerInfo.GetGlidingInfo then return end
        BuildUI()
    end
    UpdateLayout()
    -- Only show preview if module is enabled
    if IsEnabled() then
        -- Re-enable mouse if unlocked
        if mainFrame then
            mainFrame:EnableMouse(Get("unlocked"))
        end
        ShowPreview()
    else
        -- Force hide and disable interaction when disabled
        if mainFrame then
            mainFrame:Hide()
            mainFrame:SetAlpha(0)
            mainFrame:EnableMouse(false)
        end
        eventFrame:SetScript("OnUpdate", nil)
        UnregisterDynamicEvents()
    end
end

local previewHooked = false
local function HookPreviewCleanup()
    if previewHooked then return end
    if not ns.MainFrame then return end
    previewHooked = true

    if ns.MainFrame.ResetContent then
        hooksecurefunc(ns.MainFrame, "ResetContent", function()
            ns:HideDragonridingPreview()
        end)
    end

    ns.MainFrame:HookScript("OnHide", function()
        ns:HideDragonridingPreview()
    end)
end

eventFrame = CreateFrame("Frame", "NaowhQOL_DragonridingEvents")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        HookPreviewCleanup()
        if not C_PlayerInfo or not C_PlayerInfo.GetGlidingInfo then return end
        BuildUI()
        if IsEnabled() then
            RegisterDynamicEvents()
            ActivateUpdater()
        end
        return
    end

    if event == "PLAYER_LOGOUT" then
        ShowCooldownManager()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if pendingCdmShow then
            pendingCdmShow = false
            ShowCooldownManager()
        elseif pendingCdmHide then
            pendingCdmHide = false
            HideCooldownManager()
        end
        return
    end

    if not uiBuilt or not IsEnabled() then return end
    ActivateUpdater()
end)

ns.Dragonriding = eventFrame
