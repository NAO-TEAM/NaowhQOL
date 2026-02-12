local addonName, ns = ...

local COLORS = {
    BLUE = "018ee7",
    ORANGE = "ffa900",
    SUCCESS = "00ff00",
    ERROR = "ff0000",
}

local function ColorizeText(text, color)
    return "|cff" .. color .. text .. "|r"
end

NaowhQOL = NaowhQOL or {}

-- Session-only suppression flag (resets on reload)
ns.notificationsSuppressed = false

ns.DB = ns.DB or {}
ns.DefaultConfig = {
    config = {
        posX = 0,
        posY = 0,
        autoRepair = false,
        autoSell = false,
        skinChar = true,
        optimized = false,
        combatNotify = true,
    }
}

-- Apply default values to a settings table
local function ApplyDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if target[k] == nil then target[k] = v end
    end
end

-- Module default settings tables
local NAOWH_FONT = "Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf"

local COMBAT_TIMER_DEFAULTS = {
    enabled = false, unlock = false, font = NAOWH_FONT,
    colorR = 1, colorG = 1, colorB = 1, point = "CENTER",
    x = 0, y = -200, width = 400, height = 100, hidePrefix = false,
    instanceOnly = false, chatReport = true, stickyTimer = false,
}

local COMBAT_ALERT_DEFAULTS = {
    enabled = true, unlock = false, font = NAOWH_FONT,
    enterR = 0, enterG = 1, enterB = 0, leaveR = 1, leaveG = 0, leaveB = 0,
    point = "CENTER", x = 0, y = 100, width = 200, height = 50,
    enterText = "++ Combat", leaveText = "-- Combat",
    -- Enter combat audio (audioMode: "none", "sound", "tts")
    enterAudioMode = "none", enterSoundID = 8959,
    enterTtsMessage = "Combat", enterTtsVolume = 50, enterTtsRate = 0, enterTtsVoiceID = 0,
    -- Leave combat audio
    leaveAudioMode = "none", leaveSoundID = 8959,
    leaveTtsMessage = "Safe", leaveTtsVolume = 50, leaveTtsRate = 0, leaveTtsVoiceID = 0,
}

local CROSSHAIR_DEFAULTS = {
    enabled = false, size = 20, thickness = 2, gap = 6,
    colorR = 0, colorG = 1, colorB = 0, useClassColor = false, opacity = 0.8,
    offsetX = 0, offsetY = 0, combatOnly = false,
    dotEnabled = false, dotSize = 2,
    outlineEnabled = true, outlineWeight = 1,
    outlineR = 0, outlineG = 0, outlineB = 0, rotation = 0,
    showTop = true, showRight = true, showBottom = true, showLeft = true,
    dualColor = false, color2R = 1, color2G = 0, color2B = 0,
    circleEnabled = false, circleSize = 30, circleR = 0, circleG = 1, circleB = 0,
    hideWhileMounted = false, meleeRecolor = false,
    meleeRecolorBorder = true, meleeRecolorArms = false,
    meleeRecolorDot = false, meleeRecolorCircle = false,
    meleeOutColorR = 1, meleeOutColorG = 0, meleeOutColorB = 0,
    meleeSoundEnabled = false, meleeSoundID = 8959, meleeSoundInterval = 3,
}

local COMBAT_LOGGER_DEFAULTS = {
    enabled = false,
}

local DRAGONRIDING_DEFAULTS = {
    enabled = true, barWidth = 36, speedHeight = 14, chargeHeight = 14,
    gap = 0, showSpeedText = true, swapPosition = false, hideWhenGroundedFull = false,
    showSecondWind = true, showWhirlingSurge = true, colorPreset = "Classic",
    unlocked = false, point = "BOTTOM", posX = 0, posY = 200,
    barStyle = [[Interface\Buttons\WHITE8X8]],
    speedColorR = 0.00, speedColorG = 0.49, speedColorB = 0.79,
    thrillColorR = 1.00, thrillColorG = 0.66, thrillColorB = 0.00,
    chargeColorR = 0.01, chargeColorG = 0.56, chargeColorB = 0.91,
    speedFont = NAOWH_FONT, speedFontSize = 12,
    surgeIconSize = 0, surgeAnchor = "RIGHT", surgeOffsetX = 6, surgeOffsetY = 0,
    anchorFrame = "UIParent", anchorTo = "BOTTOM", matchAnchorWidth = false,
    bgColorR = 0.12, bgColorG = 0.12, bgColorB = 0.12, bgAlpha = 0.8,
    borderColorR = 0, borderColorG = 0, borderColorB = 0, borderAlpha = 1.0, borderSize = 1,
    iconBorderColorR = 0, iconBorderColorG = 0, iconBorderColorB = 0, iconBorderAlpha = 1.0, iconBorderSize = 1,
    hideCdmWhileMounted = false,
}

local BUFF_TRACKER_DEFAULTS = {
    enabled = true, iconSize = 40, spacing = 4, textSize = 14,
    font = NAOWH_FONT, showMissingOnly = false, combatOnly = false,
    showCooldown = true, showStacks = true, unlocked = false,
    showAllRaidBuffs = false, showRaidBuffs = true, showPersonalAuras = true,
    showStances = true, growDirection = "RIGHT", maxIconsPerRow = 10,
    point = "TOP", posX = 0, posY = -100, width = 450, height = 60,
}

local BUFF_MONITOR_DEFAULTS = {
    enabled = true, unlock = false, soundID = 8959, soundEnabled = true,
    colorR = 1, colorG = 0.2, colorB = 0.8, iconPoint = "CENTER", iconX = 0, iconY = 100, iconSize = 40,
    raidBuffsEnabled = true, raidIconSize = 40, raidIconPoint = "TOP", raidIconX = 0, raidIconY = -100, unlockRaid = false,
    raidLabelFontSize = 9, raidTimerFontSize = 11, raidLabelColorR = 0.7, raidLabelColorG = 0.7, raidLabelColorB = 0.7, raidLabelAlpha = 1.0, raidTimerAlpha = 1.0,
    customLabelFontSize = 9, customTimerFontSize = 11,
    customLabelColorR = 0.7, customLabelColorG = 0.7, customLabelColorB = 0.7, customLabelAlpha = 1.0, customTimerAlpha = 1.0,
}

local CONSUMABLE_CHECKER_DEFAULTS = {
    enabled = true, unlock = false, iconSize = 40, iconPoint = "TOP", iconX = 0, iconY = -140,
    normalDungeon = true, heroicDungeon = true, mythicDungeon = true, mythicPlus = false,
    lfr = true, normalRaid = true, heroicRaid = true, mythicRaid = true,
    soundEnabled = true, soundID = 8959, colorR = 1, colorG = 0.2, colorB = 0.8,
    labelFontSize = 9, labelColorR = 0.7, labelColorG = 0.7, labelColorB = 0.7, labelAlpha = 1.0,
    timerFontSize = 11, timerAlpha = 1.0,
    stackFontSize = 11, stackColorR = 1, stackColorG = 1, stackColorB = 1, stackAlpha = 1.0,
}

local GCD_TRACKER_DEFAULTS = {
    enabled = false, unlock = false, duration = 5, iconSize = 32,
    direction = "RIGHT", spacing = 4, fadeStart = 0.5, stackOverlapping = true,
    point = "CENTER", x = 0, y = -100, combatOnly = false,
    showInDungeon = true, showInRaid = true, showInArena = true,
    showInBattleground = true, showInWorld = true,
    timelineColorR = 0.01, timelineColorG = 0.56, timelineColorB = 0.91, timelineHeight = 4,
    showDowntimeSummary = true,
}

local STEALTH_REMINDER_DEFAULTS = {
    enabled = false, unlock = false, font = NAOWH_FONT,
    stealthR = 0, stealthG = 1, stealthB = 0, warningR = 1, warningG = 0, warningB = 0,
    showStealthed = true, showNotStealthed = true, disableWhenRested = false,
    stealthText = "STEALTH", warningText = "RESTEALTH",
    point = "CENTER", x = 0, y = 150, width = 200, height = 40,
    stanceEnabled = false, stanceUnlock = false, stanceWarnR = 1, stanceWarnG = 0.4, stanceWarnB = 0,
    stancePoint = "CENTER", stanceX = 0, stanceY = 100, stanceWidth = 200, stanceHeight = 40,
    stanceCombatOnly = false, stanceDisableWhenRested = false,
    stanceSoundEnabled = false, stanceSoundID = 8959, stanceSoundInterval = 3, stanceWarnText = "CHECK STANCE",
}

local MOVEMENT_ALERT_DEFAULTS = {
    -- Movement Cooldown sub-feature
    enabled = false, unlock = false, font = NAOWH_FONT,
    displayMode = "text",  -- "text", "icon", "bar"
    textFormat = "No %a - %ts",  -- %a = ability name, %t = time
    barShowIcon = true,
    textColorR = 1, textColorG = 1, textColorB = 1,
    precision = 1,
    pollRate = 100,  -- ms between countdown updates
    point = "CENTER", x = 0, y = 50, width = 200, height = 40,
    combatOnly = false,
    -- Time Spiral sub-feature
    tsEnabled = false, tsUnlock = false,
    tsText = "FREE MOVEMENT", tsColorR = 0.53, tsColorG = 1, tsColorB = 0,
    tsPoint = "CENTER", tsX = 0, tsY = 100, tsWidth = 200, tsHeight = 40,
    tsSoundEnabled = false, tsSoundID = 8959,
    tsTtsEnabled = false, tsTtsMessage = "Free movement", tsTtsVolume = 50, tsTtsRate = 0,
}

local RANGE_CHECK_DEFAULTS = {
    enabled = false, rangeEnabled = true, rangeUnlock = false, rangeFont = NAOWH_FONT,
    rangeColorR = 0.01, rangeColorG = 0.56, rangeColorB = 0.91,
    rangePoint = "CENTER", rangeX = 0, rangeY = -190, rangeWidth = 200, rangeHeight = 40, rangeCombatOnly = false,
}

local EMOTE_DETECTION_DEFAULTS = {
    enabled = true, unlock = false, font = NAOWH_FONT,
    point = "TOP", x = 0, y = -50, width = 200, height = 60, fontSize = 16,
    textR = 1, textG = 1, textB = 1, emotePattern = "prepares,places", soundOn = true, soundID = 8959,
    autoEmoteEnabled = true, autoEmoteCooldown = 2,
}

local FOCUS_CAST_BAR_DEFAULTS = {
    enabled = false, unlock = false, point = "CENTER", x = 0, y = 100, width = 250, height = 24,
    barColorR = 0.01, barColorG = 0.56, barColorB = 0.91,
    barColorCdR = 0.5, barColorCdG = 0.5, barColorCdB = 0.5,
    bgColorR = 0.12, bgColorG = 0.12, bgColorB = 0.12, bgAlpha = 0.8,
    showIcon = true, iconSize = 24, iconPosition = "LEFT",
    showSpellName = true, showTimeRemaining = true, font = NAOWH_FONT, fontSize = 12,
    textColorR = 1, textColorG = 1, textColorB = 1, hideFriendlyCasts = false,
    showEmpowerStages = true, showShieldIcon = true, colorNonInterrupt = true,
    nonIntColorR = 0.8, nonIntColorG = 0.2, nonIntColorB = 0.2,
    soundEnabled = false, soundID = 8959, ttsEnabled = false, ttsMessage = "Interrupt", ttsVolume = 50, ttsRate = 0,
}

local TALENT_REMINDER_DEFAULTS = {
    enabled = false,
}

local RAID_ALERTS_DEFAULTS = {
    enabled = true,
}

local POISON_REMINDER_DEFAULTS = {
    enabled = false,
}

local EQUIPMENT_REMINDER_DEFAULTS = {
    enabled = false,
    showOnInstance = true,
    showOnReadyCheck = true,
    autoHideDelay = 10,
    iconSize = 40,
    point = "CENTER",
    x = 0,
    y = 100,
}

local CURSOR_TRACKER_DEFAULTS = {
    enabled = false,
    size = 48,
    shape = "ring.tga",
    color = { r = 1.0, g = 0.66, b = 0.0 },
    showOutOfCombat = true,
    opacityInCombat = 1.0,
    opacityOutOfCombat = 1.0,
    trailEnabled = false,
    trailDuration = 0.6,
    gcdEnabled = true,
    gcdColor = { r = 0.004, g = 0.56, b = 0.91 },
    gcdReadyColor = { r = 0.0, g = 0.8, b = 0.3 },
    gcdReadyMatchSwipe = false,
    gcdAlpha = 1.0,
    hideOnMouseClick = false,
    hideBackground = false,
    castSwipeEnabled = true,
    castSwipeColor = { r = 1.0, g = 0.66, b = 0.0 },
}

local MOUSE_RING_DEFAULTS = {
    enabled = true,
    size = 48,
    shape = "ring.tga",
    colorR = 1.0, colorG = 0.66, colorB = 0.0,
    useClassColor = false,
    showOutOfCombat = true,
    opacityInCombat = 1.0,
    opacityOutOfCombat = 1.0,
    trailEnabled = false,
    trailDuration = 0.6,
    trailR = 1.0, trailG = 1.0, trailB = 1.0,
    gcdEnabled = true,
    gcdR = 0.004, gcdG = 0.56, gcdB = 0.91,
    gcdReadyR = 0.0, gcdReadyG = 0.8, gcdReadyB = 0.3,
    gcdReadyMatchSwipe = false,
    gcdAlpha = 1.0,
    hideOnMouseClick = false,
    hideBackground = false,
    castSwipeEnabled = true,
    castSwipeR = 1.0, castSwipeG = 0.66, castSwipeB = 0.0,
}

local CREZ_DEFAULTS = {
    -- Combat Rez Timer
    enabled = false, unlock = false,
    point = "CENTER", x = 0, y = 150, iconSize = 40,
    timerFontSize = 11, timerColorR = 1, timerColorG = 1, timerColorB = 1, timerAlpha = 1.0,
    countFontSize = 11, countColorR = 1, countColorG = 1, countColorB = 1, countAlpha = 1.0,
    -- Death Warning
    deathWarning = false,
}

local PET_TRACKER_DEFAULTS = {
    enabled = false, unlock = false,
    showIcon = true, onlyInInstance = false,
    point = "CENTER", x = 0, y = 200,
    width = 200, height = 50,
    textSize = 20, iconSize = 32,
    missingText = "Pet Missing",
    passiveText = "Pet Passive",
    wrongPetText = "Wrong Pet",
    colorR = 1, colorG = 0, colorB = 0,
}

-- Expose module defaults for restore functionality
ns.ModuleDefaults = {
    combatTimer = COMBAT_TIMER_DEFAULTS,
    combatAlert = COMBAT_ALERT_DEFAULTS,
    crosshair = CROSSHAIR_DEFAULTS,
    combatLogger = COMBAT_LOGGER_DEFAULTS,
    dragonriding = DRAGONRIDING_DEFAULTS,
    buffTracker = BUFF_TRACKER_DEFAULTS,
    buffMonitor = BUFF_MONITOR_DEFAULTS,
    consumableChecker = CONSUMABLE_CHECKER_DEFAULTS,
    gcdTracker = GCD_TRACKER_DEFAULTS,
    stealthReminder = STEALTH_REMINDER_DEFAULTS,
    movementAlert = MOVEMENT_ALERT_DEFAULTS,
    rangeCheck = RANGE_CHECK_DEFAULTS,
    emoteDetection = EMOTE_DETECTION_DEFAULTS,
    focusCastBar = FOCUS_CAST_BAR_DEFAULTS,
    talentReminder = TALENT_REMINDER_DEFAULTS,
    raidAlerts = RAID_ALERTS_DEFAULTS,
    poisonReminder = POISON_REMINDER_DEFAULTS,
    equipmentReminder = EQUIPMENT_REMINDER_DEFAULTS,
    mouseRing = MOUSE_RING_DEFAULTS,
    cRez = CREZ_DEFAULTS,
    petTracker = PET_TRACKER_DEFAULTS,
}

-- Restore a module to default settings
function ns:RestoreModuleDefaults(moduleName, skipKeys)
    local defaults = ns.ModuleDefaults[moduleName]
    if not defaults then return false end

    -- CursorTracker stores settings per-spec
    local db
    if moduleName == "CursorTracker" then
        local specIndex = GetSpecialization()
        local specName = specIndex and select(2, GetSpecializationInfo(specIndex)) or "NoSpec"
        NaowhQOL.CursorTracker = NaowhQOL.CursorTracker or {}
        NaowhQOL.CursorTracker[specName] = NaowhQOL.CursorTracker[specName] or {}
        db = NaowhQOL.CursorTracker[specName]
    else
        db = NaowhQOL[moduleName]
    end

    if not db then return false end

    skipKeys = skipKeys or {}
    local skipSet = {}
    for _, k in ipairs(skipKeys) do skipSet[k] = true end

    for k, v in pairs(defaults) do
        if not skipSet[k] then
            -- Deep copy tables
            if type(v) == "table" then
                db[k] = {}
                for tk, tv in pairs(v) do
                    db[k][tk] = tv
                end
            else
                db[k] = v
            end
        end
    end
    return true
end

local function InitializeDB()
    -- Initialize locale
    NaowhQOL.locale = NaowhQOL.locale or "enUS"
    ns:SetLocale(NaowhQOL.locale)

    ns.DB.config = ns.DB.config or {}
    ApplyDefaults(ns.DB.config, ns.DefaultConfig.config)

    NaowhQOL.combatTimer = NaowhQOL.combatTimer or {}
    ApplyDefaults(NaowhQOL.combatTimer, COMBAT_TIMER_DEFAULTS)

    NaowhQOL.combatAlert = NaowhQOL.combatAlert or {}
    ApplyDefaults(NaowhQOL.combatAlert, COMBAT_ALERT_DEFAULTS)

    -- Action Halo (per-spec settings managed by MouseCursor.lua)
    NaowhQOL.CursorTracker = NaowhQOL.CursorTracker or {}

    NaowhQOL.mouseRing = NaowhQOL.mouseRing or {}
    ApplyDefaults(NaowhQOL.mouseRing, MOUSE_RING_DEFAULTS)

    NaowhQOL.crosshair = NaowhQOL.crosshair or {}
    ApplyDefaults(NaowhQOL.crosshair, CROSSHAIR_DEFAULTS)

    NaowhQOL.combatLogger = NaowhQOL.combatLogger or {}
    ApplyDefaults(NaowhQOL.combatLogger, COMBAT_LOGGER_DEFAULTS)
    NaowhQOL.combatLogger.instances = NaowhQOL.combatLogger.instances or {}

    -- Dragonriding
    NaowhQOL.dragonriding = NaowhQOL.dragonriding or {}
    local dr = NaowhQOL.dragonriding
    if dr.enabled == nil then dr.enabled = true end
    if dr.barWidth == nil then dr.barWidth = 36 end
    if dr.speedHeight == nil then dr.speedHeight = 14 end
    if dr.chargeHeight == nil then dr.chargeHeight = 14 end
    if dr.gap == nil then dr.gap = 0 end
    if dr.showSpeedText == nil then dr.showSpeedText = true end
    if dr.swapPosition == nil then dr.swapPosition = false end
    if dr.hideWhenGroundedFull == nil then dr.hideWhenGroundedFull = false end
    if dr.showSecondWind == nil then dr.showSecondWind = true end
    if dr.showWhirlingSurge == nil then dr.showWhirlingSurge = true end
    if dr.colorPreset == nil then dr.colorPreset = "Classic" end
    if dr.unlocked == nil then dr.unlocked = false end
    if dr.point == nil then dr.point = "BOTTOM" end
    if dr.posX == nil then dr.posX = 0 end
    if dr.posY == nil then dr.posY = 200 end
    if dr.barStyle == nil then dr.barStyle = [[Interface\Buttons\WHITE8X8]] end
    if dr.speedColorR == nil then dr.speedColorR = 0.00 end
    if dr.speedColorG == nil then dr.speedColorG = 0.49 end
    if dr.speedColorB == nil then dr.speedColorB = 0.79 end
    if dr.thrillColorR == nil then dr.thrillColorR = 1.00 end
    if dr.thrillColorG == nil then dr.thrillColorG = 0.66 end
    if dr.thrillColorB == nil then dr.thrillColorB = 0.00 end
    if dr.chargeColorR == nil then dr.chargeColorR = 0.01 end
    if dr.chargeColorG == nil then dr.chargeColorG = 0.56 end
    if dr.chargeColorB == nil then dr.chargeColorB = 0.91 end
    if dr.speedFont == nil then dr.speedFont = NAOWH_FONT end
    if dr.speedFontSize == nil then dr.speedFontSize = 12 end
    if dr.surgeIconSize == nil then dr.surgeIconSize = 0 end
    if dr.surgeAnchor == nil then dr.surgeAnchor = "RIGHT" end
    if dr.surgeOffsetX == nil then dr.surgeOffsetX = 6 end
    if dr.surgeOffsetY == nil then dr.surgeOffsetY = 0 end
    if dr.anchorFrame == nil then dr.anchorFrame = "UIParent" end
    if dr.anchorTo == nil then dr.anchorTo = "BOTTOM" end
    if dr.matchAnchorWidth == nil then dr.matchAnchorWidth = false end
    if dr.bgColorR == nil then dr.bgColorR = 0.12 end
    if dr.bgColorG == nil then dr.bgColorG = 0.12 end
    if dr.bgColorB == nil then dr.bgColorB = 0.12 end
    if dr.bgAlpha == nil then dr.bgAlpha = 0.8 end
    if dr.borderColorR == nil then dr.borderColorR = 0 end
    if dr.borderColorG == nil then dr.borderColorG = 0 end
    if dr.borderColorB == nil then dr.borderColorB = 0 end
    if dr.borderAlpha == nil then dr.borderAlpha = 1.0 end
    if dr.borderSize == nil then dr.borderSize = 1 end
    if dr.iconBorderColorR == nil then dr.iconBorderColorR = 0 end
    if dr.iconBorderColorG == nil then dr.iconBorderColorG = 0 end
    if dr.iconBorderColorB == nil then dr.iconBorderColorB = 0 end
    if dr.iconBorderAlpha == nil then dr.iconBorderAlpha = 1.0 end
    if dr.iconBorderSize == nil then dr.iconBorderSize = 1 end
    if dr.hideCdmWhileMounted == nil then dr.hideCdmWhileMounted = false end

    NaowhQOL.misc = NaowhQOL.misc or {}
    local misc = NaowhQOL.misc
    if misc.autoFillDelete == nil then misc.autoFillDelete = true end
    if misc.fasterLoot == nil then misc.fasterLoot = true end
    if misc.suppressLootWarnings == nil then misc.suppressLootWarnings = true end
    if misc.hideAlerts == nil then misc.hideAlerts = false end
    if misc.hideTalkingHead == nil then misc.hideTalkingHead = false end
    if misc.hideEventToasts == nil then misc.hideEventToasts = false end
    if misc.hideZoneText == nil then misc.hideZoneText = false end
    if misc.autoRepair == nil then misc.autoRepair = false end
    if misc.guildRepair == nil then misc.guildRepair = false end
    if misc.durabilityWarning == nil then misc.durabilityWarning = true end
    if misc.durabilityThreshold == nil then misc.durabilityThreshold = 30 end
    if misc.autoSlotKeystone == nil then misc.autoSlotKeystone = true end
    if misc.skipQueueConfirm == nil then misc.skipQueueConfirm = false end
    if misc.deathReleaseProtection == nil then misc.deathReleaseProtection = false end
    if misc.ahCurrentExpansion == nil then misc.ahCurrentExpansion = false end

    -- Buff Monitor
    NaowhQOL.buffMonitor = NaowhQOL.buffMonitor or {}
    local bm = NaowhQOL.buffMonitor
    if bm.enabled      == nil then bm.enabled      = true     end
    if bm.unlock       == nil then bm.unlock       = false    end
    if bm.soundID      == nil then bm.soundID      = 8959     end
    if bm.soundEnabled == nil then bm.soundEnabled = true     end
    if bm.colorR       == nil then bm.colorR       = 1        end
    if bm.colorG       == nil then bm.colorG       = 0.2      end
    if bm.colorB       == nil then bm.colorB       = 0.8      end
    if bm.iconPoint    == nil then bm.iconPoint    = "CENTER" end
    if bm.iconX        == nil then bm.iconX        = 0        end
    if bm.iconY        == nil then bm.iconY        = 100      end
    if bm.iconSize     == nil then bm.iconSize     = 40       end
    if bm.trackers     == nil then bm.trackers     = {}       end

    -- Migrate old buffTracker position BEFORE setting raid strip defaults
    local old = NaowhQOL.buffTracker
    if old and bm.raidIconPoint == nil and old.point then
        bm.raidIconPoint = old.point
        bm.raidIconX = old.posX or 0
        bm.raidIconY = old.posY or -100
    end

    if bm.raidBuffsEnabled == nil then bm.raidBuffsEnabled = true  end
    if bm.raidIconSize == nil then bm.raidIconSize = 40       end
    if bm.raidIconPoint == nil then bm.raidIconPoint = "TOP"  end
    if bm.raidIconX    == nil then bm.raidIconX    = 0        end
    if bm.raidIconY    == nil then bm.raidIconY    = -100     end
    if bm.unlockRaid   == nil then bm.unlockRaid   = false    end
    -- Raid buff font settings
    if bm.raidLabelFontSize == nil then bm.raidLabelFontSize = 9     end
    if bm.raidTimerFontSize == nil then bm.raidTimerFontSize = 11    end
    if bm.raidLabelColorR   == nil then bm.raidLabelColorR   = 0.7   end
    if bm.raidLabelColorG   == nil then bm.raidLabelColorG   = 0.7   end
    if bm.raidLabelColorB   == nil then bm.raidLabelColorB   = 0.7   end
    if bm.raidLabelAlpha    == nil then bm.raidLabelAlpha    = 1.0   end
    if bm.raidTimerAlpha    == nil then bm.raidTimerAlpha    = 1.0   end
    -- Custom tracker font settings
    if bm.customLabelFontSize == nil then bm.customLabelFontSize = 9   end
    if bm.customTimerFontSize == nil then bm.customTimerFontSize = 11  end
    if bm.customLabelColorR   == nil then bm.customLabelColorR   = 0.7 end
    if bm.customLabelColorG   == nil then bm.customLabelColorG   = 0.7 end
    if bm.customLabelColorB   == nil then bm.customLabelColorB   = 0.7 end
    if bm.customLabelAlpha    == nil then bm.customLabelAlpha    = 1.0 end
    if bm.customTimerAlpha    == nil then bm.customTimerAlpha    = 1.0 end

    -- Migrate consumable data from buffMonitor to standalone consumableChecker
    if bm.ccEnabled ~= nil and NaowhQOL.consumableChecker == nil then
        local migrated = {}
        local keyMap = {
            ccEnabled = "enabled", ccUnlock = "unlock", ccIconSize = "iconSize",
            ccIconPoint = "iconPoint", ccIconX = "iconX", ccIconY = "iconY",
            ccNormalDungeon = "normalDungeon", ccHeroicDungeon = "heroicDungeon",
            ccMythicDungeon = "mythicDungeon", ccMythicPlus = "mythicPlus",
            ccLFR = "lfr", ccNormalRaid = "normalRaid",
            ccHeroicRaid = "heroicRaid", ccMythicRaid = "mythicRaid",
            ccSoundEnabled = "soundEnabled", ccSoundID = "soundID",
            ccColorR = "colorR", ccColorG = "colorG", ccColorB = "colorB",
        }
        for oldKey, newKey in pairs(keyMap) do
            if bm[oldKey] ~= nil then
                migrated[newKey] = bm[oldKey]
                bm[oldKey] = nil
            end
        end
        if bm.ccCategories then
            migrated.categories = bm.ccCategories
            bm.ccCategories = nil
        end
        NaowhQOL.consumableChecker = migrated
    end

    -- Consumable Checker (standalone module)
    NaowhQOL.consumableChecker = NaowhQOL.consumableChecker or {}
    local cc = NaowhQOL.consumableChecker
    if cc.enabled          == nil then cc.enabled          = true     end
    if cc.unlock           == nil then cc.unlock           = false    end
    if cc.iconSize         == nil then cc.iconSize         = 40       end
    if cc.iconPoint        == nil then cc.iconPoint        = "TOP"    end
    if cc.iconX            == nil then cc.iconX            = 0        end
    if cc.iconY            == nil then cc.iconY            = -140     end
    if cc.normalDungeon    == nil then cc.normalDungeon    = true     end
    if cc.heroicDungeon    == nil then cc.heroicDungeon    = true     end
    if cc.mythicDungeon    == nil then cc.mythicDungeon    = true     end
    if cc.mythicPlus       == nil then cc.mythicPlus       = false    end
    if cc.lfr              == nil then cc.lfr              = true     end
    if cc.normalRaid       == nil then cc.normalRaid       = true     end
    if cc.heroicRaid       == nil then cc.heroicRaid       = true     end
    if cc.mythicRaid       == nil then cc.mythicRaid       = true     end
    if cc.soundEnabled     == nil then cc.soundEnabled     = true     end
    if cc.soundID          == nil then cc.soundID          = 8959     end
    if cc.colorR           == nil then cc.colorR           = 1        end
    if cc.colorG           == nil then cc.colorG           = 0.2      end
    if cc.colorB           == nil then cc.colorB           = 0.8      end
    if cc.labelFontSize    == nil then cc.labelFontSize    = 9        end
    if cc.labelColorR      == nil then cc.labelColorR      = 0.7      end
    if cc.labelColorG      == nil then cc.labelColorG      = 0.7      end
    if cc.labelColorB      == nil then cc.labelColorB      = 0.7      end
    if cc.labelAlpha       == nil then cc.labelAlpha       = 1.0      end
    if cc.timerFontSize    == nil then cc.timerFontSize    = 11       end
    if cc.timerAlpha       == nil then cc.timerAlpha       = 1.0      end
    if cc.stackFontSize    == nil then cc.stackFontSize    = 11       end
    if cc.stackColorR      == nil then cc.stackColorR      = 1        end
    if cc.stackColorG      == nil then cc.stackColorG      = 1        end
    if cc.stackColorB      == nil then cc.stackColorB      = 1        end
    if cc.stackAlpha       == nil then cc.stackAlpha       = 1.0      end
    if cc.categories == nil then
        cc.categories = {
            { name = "Flask", matchType = "spellId",
              entries = {432021, 432473, 431971, 431972, 431974, 431973, 432430, 432403, 432452},
              customItems = {212283, 212282, 212281, 212301, 212300, 212299, 212271, 212270, 212269,
                             212274, 212273, 212272, 212280, 212279, 212278, 212277, 212276, 212275},
              enabled = true, icon = 967532 },
            { name = "Food", matchType = "name",
              entries = {"Well Fed", "Hearty Well Fed"},
              customItems = {222732, 222733, 222734, 222735, 222709, 222710, 222711, 222712,
                             222717, 222718, 222719, 222720, 222725, 222726, 222727, 222728},
              enabled = true, icon = 134062 },
            { name = "Augment Rune", matchType = "spellId",
              entries = {},
              customItems = {224572, 243191},
              enabled = false, icon = 1392955 },
            { name = "Weapon Oil (MH)", matchType = "weaponEnchant",
              weaponSlot = 16,
              customItems = {224107, 224108, 224109, 224110, 224105, 224106, 224111, 224112, 224113,
                             222504, 222503, 222502, 222507, 222506, 222505},
              enabled = true, icon = 134722 },
            { name = "Weapon Oil (OH)", matchType = "weaponEnchant",
              weaponSlot = 17,
              customItems = {224107, 224108, 224109, 224110, 224105, 224106, 224111, 224112, 224113,
                             222504, 222503, 222502, 222507, 222506, 222505},
              enabled = true, icon = 134722 },
        }
    end
    -- Migrate old single "Weapon Oil" category into MH + OH
    for i, cat in ipairs(cc.categories) do
        if cat.name == "Weapon Oil" and cat.matchType == "weaponEnchant" then
            cc.categories[i] = { name = "Weapon Oil (MH)", matchType = "weaponEnchant",
                weaponSlot = 16, enabled = cat.enabled, icon = cat.icon or 134722,
                itemId = cat.itemId }
            table.insert(cc.categories, i + 1, { name = "Weapon Oil (OH)",
                matchType = "weaponEnchant", weaponSlot = 17,
                enabled = cat.enabled, icon = cat.icon or 134722,
                itemId = cat.itemId })
            break
        end
        -- Also catch the old name-based "Oil" detection
        if cat.name == "Weapon Oil" and cat.matchType == "name" then
            cc.categories[i] = { name = "Weapon Oil (MH)", matchType = "weaponEnchant",
                weaponSlot = 16, enabled = cat.enabled, icon = 134722 }
            table.insert(cc.categories, i + 1, { name = "Weapon Oil (OH)",
                matchType = "weaponEnchant", weaponSlot = 17,
                enabled = cat.enabled, icon = 134722 })
            break
        end
    end

    -- Migrate: Add customItems to existing categories that don't have them
    local defaultItems = {
        Flask = {212283, 212282, 212281, 212301, 212300, 212299, 212271, 212270, 212269,
                 212274, 212273, 212272, 212280, 212279, 212278, 212277, 212276, 212275},
        Food = {222732, 222733, 222734, 222735, 222709, 222710, 222711, 222712,
                222717, 222718, 222719, 222720, 222725, 222726, 222727, 222728},
        ["Augment Rune"] = {224572, 243191},
        ["Weapon Oil (MH)"] = {224107, 224108, 224109, 224110, 224105, 224106, 224111, 224112, 224113,
                              222504, 222503, 222502, 222507, 222506, 222505},
        ["Weapon Oil (OH)"] = {224107, 224108, 224109, 224110, 224105, 224106, 224111, 224112, 224113,
                              222504, 222503, 222502, 222507, 222506, 222505},
    }
    for _, cat in ipairs(cc.categories) do
        if cat.customItems == nil then
            cat.customItems = defaultItems[cat.name] or {}
        end
    end

    -- GCD Tracker uses a defaults table since it has a lot of keys
    NaowhQOL.gcdTracker = NaowhQOL.gcdTracker or {}
    local gtDefaults = {
        enabled = false, unlock = false, duration = 5, iconSize = 32,
        direction = "RIGHT", spacing = 4, fadeStart = 0.5,
        stackOverlapping = true,
        point = "CENTER", x = 0, y = -100, combatOnly = false,
        showInDungeon = true, showInRaid = true, showInArena = true,
        showInBattleground = true, showInWorld = true,
        blocklist = { [6603] = true },
        timelineColorR = 0.01, timelineColorG = 0.56, timelineColorB = 0.91,
        timelineHeight = 4,
        downtimeSummaryEnabled = false,
    }
    for k, v in pairs(gtDefaults) do
        if NaowhQOL.gcdTracker[k] == nil then NaowhQOL.gcdTracker[k] = v end
    end

    -- Stealth Reminder
    NaowhQOL.stealthReminder = NaowhQOL.stealthReminder or {}
    local sr = NaowhQOL.stealthReminder
    if sr.enabled  == nil then sr.enabled  = false              end
    if sr.unlock   == nil then sr.unlock   = false              end
    if sr.font     == nil then sr.font     = NAOWH_FONT end
    if sr.stealthR == nil then sr.stealthR = 0                  end
    if sr.stealthG == nil then sr.stealthG = 1                  end
    if sr.stealthB == nil then sr.stealthB = 0                  end
    if sr.warningR == nil then sr.warningR = 1                  end
    if sr.warningG == nil then sr.warningG = 0                  end
    if sr.warningB == nil then sr.warningB = 0                  end
    if sr.showStealthed    == nil then sr.showStealthed    = true  end
    if sr.showNotStealthed == nil then sr.showNotStealthed = true  end
    if sr.disableWhenRested == nil then sr.disableWhenRested = false end
    if sr.stealthText  == nil then sr.stealthText  = "STEALTH"  end
    if sr.warningText  == nil then sr.warningText  = "RESTEALTH" end
    if sr.point    == nil then sr.point    = "CENTER"           end
    if sr.x        == nil then sr.x        = 0                  end
    if sr.y        == nil then sr.y        = 150                end
    if sr.width    == nil then sr.width    = 200                end
    if sr.height   == nil then sr.height   = 40                 end
    -- Stance check (lives in same saved table)
    if sr.stanceEnabled == nil then sr.stanceEnabled = false     end
    if sr.stanceUnlock  == nil then sr.stanceUnlock  = false     end
    if sr.stanceWarnR   == nil then sr.stanceWarnR   = 1         end
    if sr.stanceWarnG   == nil then sr.stanceWarnG   = 0.4       end
    if sr.stanceWarnB   == nil then sr.stanceWarnB   = 0         end
    if sr.stancePoint   == nil then sr.stancePoint   = "CENTER"  end
    if sr.stanceX       == nil then sr.stanceX       = 0         end
    if sr.stanceY       == nil then sr.stanceY       = 100       end
    if sr.stanceWidth          == nil then sr.stanceWidth          = 200   end
    if sr.stanceHeight         == nil then sr.stanceHeight         = 40    end
    if sr.stanceCombatOnly     == nil then sr.stanceCombatOnly     = false end
    if sr.stanceDisableWhenRested == nil then sr.stanceDisableWhenRested = false end
    if sr.stanceSoundEnabled   == nil then sr.stanceSoundEnabled   = false end
    if sr.stanceSoundID        == nil then sr.stanceSoundID        = 8959  end
    if sr.stanceSoundInterval  == nil then sr.stanceSoundInterval  = 3     end
    if sr.stanceWarnText       == nil then sr.stanceWarnText       = "CHECK STANCE" end

    -- Movement Alert
    NaowhQOL.movementAlert = NaowhQOL.movementAlert or {}
    local ma = NaowhQOL.movementAlert
    -- Movement Cooldown
    if ma.enabled     == nil then ma.enabled     = false              end
    if ma.unlock      == nil then ma.unlock      = false              end
    if ma.font        == nil then ma.font        = NAOWH_FONT         end
    if ma.displayMode == nil then ma.displayMode = "text"             end
    if ma.textColorR  == nil then ma.textColorR  = 1                  end
    if ma.textColorG  == nil then ma.textColorG  = 1                  end
    if ma.textColorB  == nil then ma.textColorB  = 1                  end
    if ma.precision   == nil then ma.precision   = 1                  end
    if ma.point       == nil then ma.point       = "CENTER"           end
    if ma.x           == nil then ma.x           = 0                  end
    if ma.y           == nil then ma.y           = 50                 end
    if ma.width       == nil then ma.width       = 200                end
    if ma.height      == nil then ma.height      = 40                 end
    if ma.combatOnly  == nil then ma.combatOnly  = false              end
    -- Time Spiral
    if ma.tsEnabled      == nil then ma.tsEnabled      = false           end
    if ma.tsUnlock       == nil then ma.tsUnlock       = false           end
    if ma.tsText         == nil then ma.tsText         = "FREE MOVEMENT" end
    if ma.tsColorR       == nil then ma.tsColorR       = 0.53            end
    if ma.tsColorG       == nil then ma.tsColorG       = 1               end
    if ma.tsColorB       == nil then ma.tsColorB       = 0               end
    if ma.tsPoint        == nil then ma.tsPoint        = "CENTER"        end
    if ma.tsX            == nil then ma.tsX            = 0               end
    if ma.tsY            == nil then ma.tsY            = 100             end
    if ma.tsWidth        == nil then ma.tsWidth        = 200             end
    if ma.tsHeight       == nil then ma.tsHeight       = 40              end
    if ma.tsSoundEnabled == nil then ma.tsSoundEnabled = false           end
    if ma.tsSoundID      == nil then ma.tsSoundID      = 8959            end
    if ma.tsTtsEnabled   == nil then ma.tsTtsEnabled   = false           end
    if ma.tsTtsMessage   == nil then ma.tsTtsMessage   = "Free movement" end
    if ma.tsTtsVolume    == nil then ma.tsTtsVolume    = 50              end
    if ma.tsTtsRate      == nil then ma.tsTtsRate      = 0               end

    -- Range Check
    NaowhQOL.rangeCheck = NaowhQOL.rangeCheck or {}
    local rc = NaowhQOL.rangeCheck
    if rc.enabled           == nil then rc.enabled           = false              end
    -- Range to Target
    if rc.rangeEnabled      == nil then rc.rangeEnabled      = true               end
    if rc.rangeUnlock       == nil then rc.rangeUnlock       = false              end
    if rc.rangeFont         == nil then rc.rangeFont         = NAOWH_FONT end
    if rc.rangeColorR       == nil then rc.rangeColorR       = 0.01               end
    if rc.rangeColorG       == nil then rc.rangeColorG       = 0.56               end
    if rc.rangeColorB       == nil then rc.rangeColorB       = 0.91               end
    if rc.rangePoint        == nil then rc.rangePoint        = "CENTER"           end
    if rc.rangeX            == nil then rc.rangeX            = 0                  end
    if rc.rangeY            == nil then rc.rangeY            = -190               end
    if rc.rangeWidth        == nil then rc.rangeWidth        = 200                end
    if rc.rangeHeight       == nil then rc.rangeHeight       = 40                 end
    if rc.rangeCombatOnly   == nil then rc.rangeCombatOnly   = false              end

    -- Emote Detection
    NaowhQOL.emoteDetection = NaowhQOL.emoteDetection or {}
    local ra = NaowhQOL.emoteDetection
    if ra.enabled          == nil then ra.enabled          = true               end
    if ra.unlock           == nil then ra.unlock           = false              end
    if ra.font             == nil then ra.font             = NAOWH_FONT end
    if ra.point            == nil then ra.point            = "TOP"              end
    if ra.x                == nil then ra.x                = 0                  end
    if ra.y                == nil then ra.y                = -50                end
    if ra.width            == nil then ra.width            = 200                end
    if ra.height           == nil then ra.height           = 60                 end
    if ra.fontSize         == nil then ra.fontSize         = 16                 end
    if ra.textR            == nil then ra.textR            = 1                  end
    if ra.textG            == nil then ra.textG            = 1                  end
    if ra.textB            == nil then ra.textB            = 1                  end
    if ra.emotePattern     == nil then ra.emotePattern     = "prepares,places"  end
    if ra.soundOn          == nil then ra.soundOn          = true               end
    if ra.soundID          == nil then ra.soundID          = 8959               end
    -- Auto Emote sub-feature
    if ra.autoEmoteEnabled == nil then ra.autoEmoteEnabled = true               end
    if ra.autoEmoteCooldown == nil then ra.autoEmoteCooldown = 2                end
    if ra.autoEmotes       == nil then
        ra.autoEmotes = {
            { spellId = 29893, emoteText = "prepares soulwell", enabled = true },
            { spellId = 698, emoteText = "prepares ritual of summoning", enabled = true },
        }
    end

    -- Focus Cast Bar
    NaowhQOL.focusCastBar = NaowhQOL.focusCastBar or {}
    local fcb = NaowhQOL.focusCastBar
    if fcb.enabled           == nil then fcb.enabled           = false              end
    if fcb.unlock            == nil then fcb.unlock            = false              end
    if fcb.point             == nil then fcb.point             = "CENTER"           end
    if fcb.x                 == nil then fcb.x                 = 0                  end
    if fcb.y                 == nil then fcb.y                 = 100                end
    if fcb.width             == nil then fcb.width             = 250                end
    if fcb.height            == nil then fcb.height            = 24                 end
    if fcb.barColorR         == nil then fcb.barColorR         = 0.01               end
    if fcb.barColorG         == nil then fcb.barColorG         = 0.56               end
    if fcb.barColorB         == nil then fcb.barColorB         = 0.91               end
    if fcb.barColorCdR       == nil then fcb.barColorCdR       = 0.5                end
    if fcb.barColorCdG       == nil then fcb.barColorCdG       = 0.5                end
    if fcb.barColorCdB       == nil then fcb.barColorCdB       = 0.5                end
    if fcb.bgColorR          == nil then fcb.bgColorR          = 0.12               end
    if fcb.bgColorG          == nil then fcb.bgColorG          = 0.12               end
    if fcb.bgColorB          == nil then fcb.bgColorB          = 0.12               end
    if fcb.bgAlpha           == nil then fcb.bgAlpha           = 0.8                end
    if fcb.showIcon          == nil then fcb.showIcon          = true               end
    if fcb.iconSize          == nil then fcb.iconSize          = 24                 end
    if fcb.iconPosition      == nil then fcb.iconPosition      = "LEFT"             end
    if fcb.showSpellName     == nil then fcb.showSpellName     = true               end
    if fcb.showTimeRemaining == nil then fcb.showTimeRemaining = true               end
    if fcb.font              == nil then fcb.font              = NAOWH_FONT end
    if fcb.fontSize          == nil then fcb.fontSize          = 12                 end
    if fcb.textColorR        == nil then fcb.textColorR        = 1                  end
    if fcb.textColorG        == nil then fcb.textColorG        = 1                  end
    if fcb.textColorB        == nil then fcb.textColorB        = 1                  end
    if fcb.hideFriendlyCasts == nil then fcb.hideFriendlyCasts = false              end
    if fcb.showEmpowerStages == nil then fcb.showEmpowerStages = true               end
    if fcb.showShieldIcon    == nil then fcb.showShieldIcon    = true               end
    if fcb.colorNonInterrupt == nil then fcb.colorNonInterrupt = true               end
    if fcb.nonIntColorR      == nil then fcb.nonIntColorR      = 0.8                end
    if fcb.nonIntColorG      == nil then fcb.nonIntColorG      = 0.2                end
    if fcb.nonIntColorB      == nil then fcb.nonIntColorB      = 0.2                end
    if fcb.soundEnabled      == nil then fcb.soundEnabled      = false              end
    if fcb.soundID           == nil then fcb.soundID           = 8959               end
    if fcb.ttsEnabled        == nil then fcb.ttsEnabled        = false              end
    if fcb.ttsMessage        == nil then fcb.ttsMessage        = "Interrupt"        end
    if fcb.ttsVolume         == nil then fcb.ttsVolume         = 50                 end

    -- Talent Reminder
    NaowhQOL.talentReminder = NaowhQOL.talentReminder or {}
    local tr = NaowhQOL.talentReminder
    if tr.enabled == nil then tr.enabled = false end
    tr.loadouts = tr.loadouts or {}

    -- Combat Rez
    NaowhQOL.cRez = NaowhQOL.cRez or {}
    local cr = NaowhQOL.cRez
    -- Rez Timer
    if cr.enabled           == nil then cr.enabled           = false     end
    if cr.unlock            == nil then cr.unlock            = false     end
    if cr.point             == nil then cr.point             = "CENTER"  end
    if cr.x                 == nil then cr.x                 = 0         end
    if cr.y                 == nil then cr.y                 = 150       end
    if cr.iconSize          == nil then cr.iconSize          = 40        end
    if cr.timerFontSize     == nil then cr.timerFontSize     = 11        end
    if cr.timerColorR       == nil then cr.timerColorR       = 1         end
    if cr.timerColorG       == nil then cr.timerColorG       = 1         end
    if cr.timerColorB       == nil then cr.timerColorB       = 1         end
    if cr.timerAlpha        == nil then cr.timerAlpha        = 1.0       end
    if cr.countFontSize     == nil then cr.countFontSize     = 11        end
    if cr.countColorR       == nil then cr.countColorR       = 1         end
    if cr.countColorG       == nil then cr.countColorG       = 1         end
    if cr.countColorB       == nil then cr.countColorB       = 1         end
    if cr.countAlpha        == nil then cr.countAlpha        = 1.0       end
    -- Death Warning
    if cr.deathWarning      == nil then cr.deathWarning      = false     end

    -- Pet Tracker
    NaowhQOL.petTracker = NaowhQOL.petTracker or {}
    ApplyDefaults(NaowhQOL.petTracker, PET_TRACKER_DEFAULTS)

    -- Slash Commands
    NaowhQOL.slashCommands = NaowhQOL.slashCommands or {}
    local sc = NaowhQOL.slashCommands
    if sc.enabled == nil then sc.enabled = true end
    if sc.commands == nil then
        sc.commands = {
            { name = "cdm", frame = "CooldownViewerSettings", enabled = true, default = true },
            { name = "em", frame = "EditModeManagerFrame", enabled = true, default = true },
            { name = "kb", frame = "QuickKeybindFrame", enabled = true, default = true },
        }
    end
    -- Migrate: Convert old frameToggle format to new format, keep all valid commands
    if sc.commands then
        local cleaned = {}
        for _, cmd in ipairs(sc.commands) do
            if cmd.actionType == "command" and cmd.command then
                -- Keep slash command aliases as-is
                table.insert(cleaned, cmd)
            elseif cmd.frame then
                -- Keep frame toggle commands as-is
                table.insert(cleaned, cmd)
            elseif cmd.actionType == "frameToggle" and cmd.action then
                -- Convert old frameToggle format to new format
                table.insert(cleaned, {
                    name = cmd.name,
                    actionType = "frame",
                    frame = cmd.action,
                    enabled = cmd.enabled,
                })
            end
        end
        sc.commands = cleaned
    end
end



function ns:ApplyFPSOptimization()

    SetCVar("gxVSync", 0)
    SetCVar("MSAAAlphaTest", 0)
    SetCVar("tripleBuffering", 0)


    SetCVar("shadowMode", 1)
    SetCVar("SSAO", 0)


    SetCVar("liquidDetail", 2)
    SetCVar("depthEffects", 0)
    SetCVar("computeEffects", 0)
    SetCVar("fringeEffect", 0)


    SetCVar("textureFilteringMode", 5)
    SetCVar("ResampleAlwaysSharpen", 0)


    SetCVar("gxMaxBackgroundFPS", 30)
    SetCVar("targetFPS", 0)


    SetCVar("processPriority", 3)
    SetCVar("WorldTextScale", 1)
    SetCVar("nameplateMaxDistance", 41)

    ns.DB.config.optimized = true

    ns:LogSuccess("FPS optimization applied.")
    StaticPopup_Show("NAOWH_QOL_RELOAD")
end


function ns:OptimizeNetwork()
    SetCVar("SpellQueueWindow", 150)
    SetCVar("reducedLagTolerance", 1)
    SetCVar("MaxSpellQueueWindow", 150)

    ns:LogSuccess("Network optimized (150ms Spell Queue).")
end


function ns:DeepGraphicsPurge()
    SetCVar("physicsLevel", 0)
    SetCVar("groundEffectDist", 40)
    SetCVar("groundEffectDensity", 16)
    SetCVar("worldBaseTickRate", 150)
    SetCVar("clutterFarDist", 20)

    ns:LogSuccess("Physics and clutter purged.")
end


local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, name)
    if name == addonName then
        InitializeDB()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- Suppress notifications slash command (session only, resets on reload)
SLASH_NAOWHQOLSUP1 = "/nsup"
SlashCmdList["NAOWHQOLSUP"] = function()
    ns.notificationsSuppressed = not ns.notificationsSuppressed
    if ns.notificationsSuppressed then
        print("|cff00ff00NaowhQOL:|r Notifications suppressed until reload")
        if ns.DisableConsumableChecker then ns:DisableConsumableChecker() end
        if ns.DisableBuffMonitor then ns:DisableBuffMonitor() end
    else
        print("|cff00ff00NaowhQOL:|r Notifications re-enabled")
        if ns.EnableConsumableChecker then ns:EnableConsumableChecker() end
        if ns.RefreshBuffMonitor then ns:RefreshBuffMonitor() end
    end
end
