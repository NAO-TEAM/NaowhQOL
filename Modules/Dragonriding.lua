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

local cfg = {}
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
local surgeFrame, surgeCooldown
local eventFrame

local function IsEnabled()
    return NaowhQOL.dragonriding and NaowhQOL.dragonriding.enabled
end

local function GetConfig()
    local db = NaowhQOL.dragonriding or {}
    cfg.barWidth = db.barWidth or 36
    cfg.speedHeight = db.speedHeight or 14
    cfg.chargeHeight = db.chargeHeight or 14
    cfg.gap = db.gap or 0
    cfg.showSpeedText = db.showSpeedText ~= false
    cfg.swapPosition = db.swapPosition or false
    cfg.hideWhenGroundedFull = db.hideWhenGroundedFull or false
    cfg.showSecondWind = db.showSecondWind ~= false
    cfg.showWhirlingSurge = db.showWhirlingSurge ~= false
    cfg.colorPreset = db.colorPreset or "Classic"
    cfg.unlocked = db.unlocked or false
    cfg.point = db.point or "BOTTOM"
    cfg.posX = db.posX or 0
    cfg.posY = db.posY or 200
    cfg.barStyle = db.barStyle or [[Interface\Buttons\WHITE8X8]]
    cfg.speedColorR = db.speedColorR or 0.00
    cfg.speedColorG = db.speedColorG or 0.49
    cfg.speedColorB = db.speedColorB or 0.79
    cfg.thrillColorR = db.thrillColorR or 1.00
    cfg.thrillColorG = db.thrillColorG or 0.66
    cfg.thrillColorB = db.thrillColorB or 0.00
    cfg.chargeColorR = db.chargeColorR or 0.01
    cfg.chargeColorG = db.chargeColorG or 0.56
    cfg.chargeColorB = db.chargeColorB or 0.91
    cfg.speedFont = db.speedFont or "Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf"
    cfg.speedFontSize = db.speedFontSize or 12
    cfg.surgeIconSize = db.surgeIconSize or 0
    cfg.surgeAnchor = db.surgeAnchor or "RIGHT"
    cfg.surgeOffsetX = db.surgeOffsetX or 6
    cfg.surgeOffsetY = db.surgeOffsetY or 0
    cfg.anchorFrame = db.anchorFrame or "UIParent"
    cfg.anchorTo = db.anchorTo or "BOTTOM"
    cfg.matchAnchorWidth = db.matchAnchorWidth or false
    cfg.bgColorR = db.bgColorR or 0.12
    cfg.bgColorG = db.bgColorG or 0.12
    cfg.bgColorB = db.bgColorB or 0.12
    cfg.bgAlpha = db.bgAlpha or 0.8
    cfg.hideCdmWhileMounted = db.hideCdmWhileMounted or false
end

local CDM_FRAMES = {
    BuffIconCooldownViewer = true,
    EssentialCooldownViewer = true,
    UtilityCooldownViewer = true,
}

local function IsAnchoredToCDM()
    return CDM_FRAMES[cfg.anchorFrame] == true
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
    local anchorParent = L.GetAnchorFrame(cfg.anchorFrame) or UIParent
    mainFrame:SetPoint(cfg.point, anchorParent, cfg.anchorTo, cfg.posX, cfg.posY)
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
    return COLOR_PRESETS[cfg.colorPreset] or COLOR_PRESETS.Classic
end

local function ApplyColors(isThrill, isGroundSkim)
    local state = isThrill and "thrill" or (isGroundSkim and "groundSkim" or "lowSpeed")
    if state == lastColorState then return end
    lastColorState = state

    if isThrill then
        speedBar:SetStatusBarColor(cfg.thrillColorR, cfg.thrillColorG, cfg.thrillColorB)
    else
        speedBar:SetStatusBarColor(cfg.speedColorR, cfg.speedColorG, cfg.speedColorB)
    end

    for i = 1, NUM_CHARGES do
        chargeBars[i]:SetStatusBarColor(cfg.chargeColorR, cfg.chargeColorG, cfg.chargeColorB)
    end
end

local function UpdateLayout()
    if not mainFrame then return end
    local preset = GetPreset()
    local totalHeight = cfg.speedHeight + cfg.gap + cfg.chargeHeight

    -- Update anchor position
    mainFrame:ClearAllPoints()
    local anchorParent = L.GetAnchorFrame(cfg.anchorFrame) or UIParent
    mainFrame:SetPoint(cfg.point, anchorParent, cfg.anchorTo, cfg.posX, cfg.posY)

    -- Calculate widths (match anchor width if enabled)
    local totalWidth = NUM_CHARGES * cfg.barWidth + (NUM_CHARGES - 1) * cfg.gap
    local barWidth = cfg.barWidth

    if cfg.matchAnchorWidth and anchorParent ~= UIParent then
        local anchorWidth = anchorParent:GetWidth()
        if anchorWidth and anchorWidth > 0 then
            totalWidth = anchorWidth
            -- Recalculate individual bar width to fit
            barWidth = (totalWidth - (NUM_CHARGES - 1) * cfg.gap) / NUM_CHARGES
        end
    end

    mainFrame:SetSize(totalWidth, totalHeight)
    mainFrame:SetBackdropColor(cfg.bgColorR, cfg.bgColorG, cfg.bgColorB, cfg.bgAlpha)
    mainFrame:SetBackdropBorderColor(preset.border.r, preset.border.g, preset.border.b, 1)

    local speedY = cfg.swapPosition and 0 or -(cfg.chargeHeight + cfg.gap)
    local chargeY = cfg.swapPosition and -(cfg.speedHeight + cfg.gap) or 0

    speedBar:ClearAllPoints()
    speedBar:SetSize(totalWidth, cfg.speedHeight)
    speedBar:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 0, speedY)

    speedText:SetShown(cfg.showSpeedText)
    speedText:SetFont(cfg.speedFont, cfg.speedFontSize, "OUTLINE")

    for i = 1, NUM_CHARGES do
        local xOff = (i - 1) * (barWidth + cfg.gap)

        secondWindBars[i]:ClearAllPoints()
        secondWindBars[i]:SetSize(barWidth, cfg.chargeHeight)
        secondWindBars[i]:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", xOff, chargeY)

        chargeBars[i]:ClearAllPoints()
        chargeBars[i]:SetSize(barWidth, cfg.chargeHeight)
        chargeBars[i]:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", xOff, chargeY)

        -- Position divider at the right edge of each bar (except last)
        if chargeDividers[i] then
            chargeDividers[i]:ClearAllPoints()
            chargeDividers[i]:SetSize(1, cfg.chargeHeight)
            chargeDividers[i]:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", xOff + barWidth, chargeY)
        end
    end

    if surgeFrame then
        surgeFrame:ClearAllPoints()
        local iconSize = cfg.surgeIconSize > 0 and cfg.surgeIconSize
            or (cfg.chargeHeight + cfg.speedHeight + cfg.gap)
        surgeFrame:SetSize(iconSize, iconSize)

        local anchor = cfg.surgeAnchor
        local ox, oy = cfg.surgeOffsetX, cfg.surgeOffsetY
        if anchor == "LEFT" then
            surgeFrame:SetPoint("RIGHT", mainFrame, "LEFT", -ox, oy)
        elseif anchor == "TOP" then
            surgeFrame:SetPoint("BOTTOM", mainFrame, "TOP", ox, oy)
        elseif anchor == "BOTTOM" then
            surgeFrame:SetPoint("TOP", mainFrame, "BOTTOM", ox, -oy)
        else
            surgeFrame:SetPoint("LEFT", mainFrame, "RIGHT", ox, oy)
        end
        surgeFrame:SetShown(cfg.showWhirlingSurge)
    end

    -- Apply bar style to all status bars
    local barTex = cfg.barStyle or BAR_TEXTURE
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

    if cfg.showSpeedText then
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
    if not cfg.showSecondWind then
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
    if not cfg.showWhirlingSurge or not surgeFrame then
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
    -- Always enforce BCDM bar hiding (they may re-show themselves)
    if BCDM_PowerBar and BCDM_PowerBar:IsShown() then BCDM_PowerBar:Hide() end
    if BCDM_SecondaryPowerBar and BCDM_SecondaryPowerBar:IsShown() then BCDM_SecondaryPowerBar:Hide() end

    if cdmHidden then return end
    StashPositionAndReanchor()
    cdmHidden = true
    if BuffIconCooldownViewer then BuffIconCooldownViewer:Hide() end
    if EssentialCooldownViewer then EssentialCooldownViewer:Hide() end
    if UtilityCooldownViewer then UtilityCooldownViewer:Hide() end
end

local function ShowCooldownManager()
    if not cdmHidden then return end
    cdmHidden = false
    if BuffIconCooldownViewer then BuffIconCooldownViewer:Show() end
    if EssentialCooldownViewer then EssentialCooldownViewer:Show() end
    if UtilityCooldownViewer then UtilityCooldownViewer:Show() end
    if BCDM_PowerBar then BCDM_PowerBar:Show() end
    if BCDM_SecondaryPowerBar then BCDM_SecondaryPowerBar:Show() end
    RestoreOriginalAnchor()
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
        if cfg.hideCdmWhileMounted then
            ShowCooldownManager()
        end
        return
    end

    local charges, maxCharges, startTime, duration, isThrill, isGroundSkim = GetVigorInfo()

    if cfg.hideWhenGroundedFull and not IsGliding() and charges >= maxCharges then
        mainFrame:SetAlpha(0)
        mainFrame:Hide()
        eventFrame:SetScript("OnUpdate", nil)
        if cfg.hideCdmWhileMounted then
            ShowCooldownManager()
        end
        return
    end

    mainFrame:Show()
    mainFrame:SetAlpha(1)

    if cfg.hideCdmWhileMounted then
        HideCooldownManager()
    end

    UpdateSpeedBar(GetForwardSpeed())
    UpdateCharges(charges, maxCharges, startTime, duration)
    ApplyColors(isThrill, isGroundSkim)

    if cfg.showSecondWind then
        local swCharges = GetSecondWindCharges()
        UpdateSecondWind(charges, charges + swCharges)
    else
        UpdateSecondWind(0, 0)
    end

    if cfg.showWhirlingSurge then
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

    local preset = GetPreset()

    mainFrame = CreateFrame("Frame", "NaowhQOL_Dragonriding", UIParent, "BackdropTemplate")
    mainFrame:SetFrameStrata("MEDIUM")
    mainFrame:SetFrameLevel(100)
    mainFrame:SetClampedToScreen(true)
    mainFrame:SetBackdrop({
        bgFile = BAR_TEXTURE,
        edgeFile = BAR_TEXTURE,
        edgeSize = 1,
    })
    mainFrame:SetBackdropColor(cfg.bgColorR, cfg.bgColorG, cfg.bgColorB, cfg.bgAlpha)
    mainFrame:SetBackdropBorderColor(preset.border.r, preset.border.g, preset.border.b, 1)

    W.MakeDraggable(mainFrame, {
        db = NaowhQOL.dragonriding,
        unlockKey = "unlocked", xKey = "posX", yKey = "posY",
        userPlaced = false,
    })

    speedBar = CreateFrame("StatusBar", nil, mainFrame)
    speedBar:SetStatusBarTexture(BAR_TEXTURE)
    speedBar:SetMinMaxValues(0, 1)
    speedBar:SetValue(0)
    speedBar:SetStatusBarColor(cfg.speedColorR, cfg.speedColorG, cfg.speedColorB)


    local speedTextFrame = CreateFrame("Frame", nil, mainFrame)
    speedTextFrame:SetAllPoints()
    speedTextFrame:SetFrameLevel(mainFrame:GetFrameLevel() + 10)

    speedText = speedTextFrame:CreateFontString(nil, "OVERLAY")
    speedText:SetFont(cfg.speedFont, cfg.speedFontSize, "OUTLINE")
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
    surgeCooldown:SetAllPoints()
    surgeCooldown:SetHideCountdownNumbers(false)

    mainFrame:ClearAllPoints()
    local anchorParent = L.GetAnchorFrame(cfg.anchorFrame) or UIParent
    mainFrame:SetPoint(cfg.point, anchorParent, cfg.anchorTo, cfg.posX, cfg.posY)

    UpdateLayout()

    -- Schedule a delayed layout refresh when matching anchor width
    -- Anchor frames may not have their final size immediately on reload
    if cfg.matchAnchorWidth and anchorParent ~= UIParent then
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

    speedBar:SetValue(0.65)
    speedBar:SetStatusBarColor(cfg.thrillColorR, cfg.thrillColorG, cfg.thrillColorB)
    if cfg.showSpeedText then
        speedText:SetText("456")
    end

    for i = 1, NUM_CHARGES do
        if i <= 4 then
            chargeBars[i]:SetValue(1)
        elseif i == 5 then
            chargeBars[i]:SetValue(0.6)
        else
            chargeBars[i]:SetValue(0)
        end
        chargeBars[i]:SetStatusBarColor(cfg.chargeColorR, cfg.chargeColorG, cfg.chargeColorB)
        secondWindBars[i]:SetValue(i <= 5 and 1 or 0)
    end

    lastColorState = nil
end

function ns:HideDragonridingPreview()
    if not mainFrame or not uiBuilt then return end
    prevSpeed = 0
    lastColorState = nil
    if IsEnabled() then
        ActivateUpdater()
    else
        mainFrame:Hide()
        mainFrame:SetAlpha(0)
        eventFrame:SetScript("OnUpdate", nil)
    end
end

function ns:RefreshDragonridingLayout()
    GetConfig()
    if not uiBuilt then
        if not C_PlayerInfo or not C_PlayerInfo.GetGlidingInfo then return end
        BuildUI()
    end
    UpdateLayout()
    ShowPreview()
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
eventFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
eventFrame:RegisterEvent("ACTIONBAR_UPDATE_STATE")
eventFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
eventFrame:RegisterEvent("PLAYER_CAN_GLIDE_CHANGED")
eventFrame:RegisterEvent("PLAYER_IS_GLIDING_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        HookPreviewCleanup()
        if not C_PlayerInfo or not C_PlayerInfo.GetGlidingInfo then return end
        GetConfig()
        BuildUI()
        ActivateUpdater()
        return
    end

    if event == "PLAYER_LOGOUT" then
        ShowCooldownManager()
        return
    end

    if not uiBuilt then return end
    ActivateUpdater()
end)

ns.Dragonriding = eventFrame
