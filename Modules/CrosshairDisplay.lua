local addonName, ns = ...
local L = ns.L

-- Crosshair overlay w/ dot, circle

local BAR_TEXTURE = [[Interface\Buttons\WHITE8x8]]
local CIRCLE_TEXTURE = [[Interface\AddOns\NaowhQOL\Assets\ring]]
local TEXEL_HALF = 0.5 / 512  -- ring.tga is 512x512
local PI = math.pi
local sin, cos = math.sin, math.cos

-- Default spell IDs for melee range checking per class/spec index
local DEFAULT_MELEE_SPELLS = {
    DEATHKNIGHT = { 49998, 49998, 49998 },
    DEMONHUNTER = { 162794, 344859 },
    DRUID = { nil, 5221, 33917, nil },
    HUNTER = { nil, nil, 186270 },
    MONK = { 205523, 205523, 205523 },
    PALADIN = { nil, 96231, 96231 },
    ROGUE = { 1752, 1752, 1752 },
    SHAMAN = { nil, 73899, nil },
    WARRIOR = { 1464, 1464, 1464 },
}

local cachedMeleeSpellId = nil
local meleeCheckSupported = false
local hpalEnabled = false  -- Holy Paladin item-based fallback

local function GetMeleeSpellKey()
    local classFile = ns.SpecUtil.GetClassName()
    local specIndex = ns.SpecUtil.GetSpecIndex()
    if not classFile or specIndex == 0 then return nil end
    return classFile .. "_" .. specIndex
end

local function GetDefaultMeleeSpell()
    local classFile = ns.SpecUtil.GetClassName()
    local specIndex = ns.SpecUtil.GetSpecIndex()
    local classSpells = DEFAULT_MELEE_SPELLS[classFile]
    return classSpells and classSpells[specIndex]
end

local function GetCurrentMeleeSpell()
    local db = NaowhQOL and NaowhQOL.crosshair
    local key = GetMeleeSpellKey()
    if not key then return nil end

    -- Check for user override first
    if db and db.meleeSpellOverrides and db.meleeSpellOverrides[key] then
        return db.meleeSpellOverrides[key]
    end

    return GetDefaultMeleeSpell()
end

local function CacheMeleeSpell()
    if hpalEnabled then return end

    cachedMeleeSpellId = GetCurrentMeleeSpell()
    meleeCheckSupported = (cachedMeleeSpellId ~= nil)

    if not meleeCheckSupported then
        local db = NaowhQOL and NaowhQOL.crosshair
        if db and db.meleeRecolor then
            print("|cff00ff00NaowhQOL|r: " .. L["CROSSHAIR_MELEE_UNSUPPORTED"])
        end
    end
end

-- Expose for settings UI
ns.MeleeRangeInfo = {
    GetCurrentSpell = GetCurrentMeleeSpell,
    GetDefaultSpell = GetDefaultMeleeSpell,
    GetSpellKey = GetMeleeSpellKey,
    RefreshCache = CacheMeleeSpell,
}

local function HasAttackableTarget()
    if not UnitExists("target") then return false end
    if not UnitCanAttack("player", "target") then return false end
    if UnitIsDeadOrGhost("target") then return false end
    return true
end

-- Base angles measured clockwise from 12-o'clock
local ARM_DEFS = {
    { key = "showTop",    base = 0        },
    { key = "showRight",  base = PI / 2   },
    { key = "showBottom", base = PI       },
    { key = "showLeft",   base = 3*PI / 2 },
}

local crosshairFrame = CreateFrame("Frame", "NaowhQOL_Crosshair", UIParent)
crosshairFrame:SetFrameStrata("HIGH")
crosshairFrame:SetFrameLevel(50)
crosshairFrame:EnableMouse(false)
crosshairFrame:Hide()

local arms = {}
local shadows = {}

for i, def in ipairs(ARM_DEFS) do
    local s = crosshairFrame:CreateTexture(nil, "ARTWORK", nil, 0)
    s:SetTexture(BAR_TEXTURE)
    s:SetVertexColor(0, 0, 0, 1)
    shadows[i] = s

    local t = crosshairFrame:CreateTexture(nil, "ARTWORK", nil, 1)
    t:SetTexture(BAR_TEXTURE)
    arms[i] = t
end

local dotShadow = crosshairFrame:CreateTexture(nil, "ARTWORK", nil, 0)
dotShadow:SetTexture(BAR_TEXTURE)
dotShadow:SetVertexColor(0, 0, 0, 1)

local dot = crosshairFrame:CreateTexture(nil, "ARTWORK", nil, 1)
dot:SetTexture(BAR_TEXTURE)

local circleShadow = crosshairFrame:CreateTexture(nil, "ARTWORK", nil, 0)
circleShadow:SetTexture(CIRCLE_TEXTURE, "CLAMP", "CLAMP", "TRILINEAR")
circleShadow:SetVertexColor(0, 0, 0, 1)
circleShadow:SetTexCoord(TEXEL_HALF, 1 - TEXEL_HALF, TEXEL_HALF, 1 - TEXEL_HALF)
if circleShadow.SetSnapToPixelGrid then
    circleShadow:SetSnapToPixelGrid(false)
    circleShadow:SetTexelSnappingBias(0)
end

local circleRing = crosshairFrame:CreateTexture(nil, "ARTWORK", nil, 1)
circleRing:SetTexture(CIRCLE_TEXTURE, "CLAMP", "CLAMP", "TRILINEAR")
circleRing:SetTexCoord(TEXEL_HALF, 1 - TEXEL_HALF, TEXEL_HALF, 1 - TEXEL_HALF)
if circleRing.SetSnapToPixelGrid then
    circleRing:SetSnapToPixelGrid(false)
    circleRing:SetTexelSnappingBias(0)
end

local inCombat = false
local isMounted = false
local isOutOfMelee = false

local function ApplyLayout()
    local db = NaowhQOL and NaowhQOL.crosshair
    if not db then return end

    local size      = db.size or 20
    local thick     = db.thickness or 2
    local gap       = db.gap or 6
    local r1, g1, b1 = ns.Widgets.GetEffectiveColor(db, "colorR", "colorG", "colorB", "useClassColor")
    local alpha     = db.opacity or 0.8
    local ox        = db.offsetX or 0
    local oy        = db.offsetY or 0
    local outline   = db.outlineEnabled
    local ow        = db.outlineWeight or 1
    local olR, olG, olB = db.outlineR or 0, db.outlineG or 0, db.outlineB or 0

    -- Melee out-of-range color for recoloring elements
    local meleeOut = db.meleeRecolor and isOutOfMelee
    local moR, moG, moB = db.meleeOutColorR or 1, db.meleeOutColorG or 0, db.meleeOutColorB or 0

    -- When out of melee range, force outline on and override its color (if border recolor enabled)
    if meleeOut and db.meleeRecolorBorder ~= false then
        outline = true
        olR, olG, olB = moR, moG, moB
    end

    local span = (gap + size) + (outline and ow or 0) + 2
    crosshairFrame:SetSize(span * 2, span * 2)
    crosshairFrame:ClearAllPoints()
    local uiScale = UIParent:GetEffectiveScale()
    local snappedOx = math.floor(ox * uiScale + 0.5) / uiScale
    local snappedOy = math.floor(oy * uiScale + 0.5) / uiScale
    crosshairFrame:SetPoint("CENTER", UIParent, "CENTER", snappedOx, snappedOy)

    local cx, cy = span, span

    for i, def in ipairs(ARM_DEFS) do
        local arm = arms[i]
        local shd = shadows[i]
        local visible = db[def.key] ~= false
        local angle = def.base

        if visible then
            local cr, cg, cb = r1, g1, b1
            if meleeOut and db.meleeRecolorArms then
                cr, cg, cb = moR, moG, moB
            end

            local dist = gap + size / 2
            local ax = cx + dist * sin(angle)
            local ay = cy + dist * cos(angle)

            arm:SetSize(thick, size)
            arm:ClearAllPoints()
            arm:SetPoint("CENTER", crosshairFrame, "BOTTOMLEFT", ax, ay)
            arm:SetRotation(-angle)
            arm:SetVertexColor(cr, cg, cb, alpha)
            arm:Show()

            if outline then
                shd:SetSize(thick + ow * 2, size + ow * 2)
                shd:ClearAllPoints()
                shd:SetPoint("CENTER", crosshairFrame, "BOTTOMLEFT", ax, ay)
                shd:SetRotation(-angle)
                shd:SetVertexColor(olR, olG, olB, alpha)
                shd:Show()
            else
                shd:Hide()
            end
        else
            arm:Hide()
            shd:Hide()
        end
    end

    if db.dotEnabled then
        local ds = db.dotSize or 2
        dot:SetSize(ds, ds)
        dot:ClearAllPoints()
        dot:SetPoint("CENTER", crosshairFrame, "BOTTOMLEFT", cx, cy)
        local dotR, dotG, dotB = r1, g1, b1
        if meleeOut and db.meleeRecolorDot then
            dotR, dotG, dotB = moR, moG, moB
        end
        dot:SetVertexColor(dotR, dotG, dotB, alpha)
        dot:Show()

        if outline then
            dotShadow:SetSize(ds + ow * 2, ds + ow * 2)
            dotShadow:ClearAllPoints()
            dotShadow:SetPoint("CENTER", dot, "CENTER", 0, 0)
            dotShadow:SetVertexColor(olR, olG, olB, alpha)
            dotShadow:Show()
        else
            dotShadow:Hide()
        end
    else
        dot:Hide()
        dotShadow:Hide()
    end

    if db.circleEnabled then
        local cs = db.circleSize or 30
        circleRing:SetSize(cs, cs)
        circleRing:ClearAllPoints()
        circleRing:SetPoint("CENTER", crosshairFrame, "BOTTOMLEFT", cx, cy)
        local cR, cG, cB
        if db.circleR ~= nil or db.circleUseClassColor then
            cR, cG, cB = ns.Widgets.GetEffectiveColor(db, "circleR", "circleG", "circleB", "circleUseClassColor")
        else
            cR, cG, cB = r1, g1, b1
        end
        if meleeOut and db.meleeRecolorCircle then
            cR, cG, cB = moR, moG, moB
        end
        circleRing:SetVertexColor(cR, cG, cB, alpha)
        circleRing:Show()

        if outline then
            circleShadow:SetSize(cs + ow * 2, cs + ow * 2)
            circleShadow:ClearAllPoints()
            circleShadow:SetPoint("CENTER", circleRing, "CENTER", 0, 0)
            circleShadow:SetVertexColor(olR, olG, olB, alpha)
            circleShadow:Show()
        else
            circleShadow:Hide()
        end
    else
        circleRing:Hide()
        circleShadow:Hide()
    end
end

local function RefreshVisibility()
    local db = NaowhQOL and NaowhQOL.crosshair
    if not db or not db.enabled then
        crosshairFrame:Hide()
        return
    end

    if db.combatOnly and not inCombat then
        crosshairFrame:Hide()
        return
    end

    if db.hideWhileMounted and isMounted then
        crosshairFrame:Hide()
        return
    end

    crosshairFrame:Show()
end

-- Forward declarations (defined later in file)
local EvaluateMeleeTick
local EvaluateHpalMode

function crosshairFrame:UpdateDisplay()
    ApplyLayout()
    RefreshVisibility()
    if EvaluateHpalMode then EvaluateHpalMode() end
    if EvaluateMeleeTick then EvaluateMeleeTick() end
end

---------------------------------------------------------------------------
-- Sound system for melee out-of-range alerts
---------------------------------------------------------------------------
local meleeSoundTicker = nil
local lastMeleeSoundTime = 0
local MELEE_SOUND_COOLDOWN = 0.9

local function StopMeleeSound()
    if meleeSoundTicker then
        meleeSoundTicker:Cancel()
        meleeSoundTicker = nil
    end
end

local function PlayMeleeSoundOnce(soundID)
    local now = GetTime()
    if now - lastMeleeSoundTime < MELEE_SOUND_COOLDOWN then return end
    lastMeleeSoundTime = now
    PlaySound(soundID, "Master")
end

local function StartMeleeSound(db)
    StopMeleeSound()
    local interval = db.meleeSoundInterval or 3
    local soundID = db.meleeSoundID or 8959
    PlayMeleeSoundOnce(soundID)
    if interval > 0 then
        meleeSoundTicker = C_Timer.NewTicker(interval, function()
            PlayMeleeSoundOnce(soundID)
        end)
    end
end

---------------------------------------------------------------------------
-- Melee range polling tick (0.1s)
---------------------------------------------------------------------------
local TICK_RATE = 0.1
local tickAcc = 0
local lastInRange = nil
local tickFrame = CreateFrame("Frame")

local function ShouldTickRun()
    if hpalEnabled then return false end  -- Holy Paladin has its own tick
    local db = NaowhQOL and NaowhQOL.crosshair
    if not db or not db.enabled then return false end
    if not db.meleeRecolor then return false end
    if not meleeCheckSupported then return false end
    if not HasAttackableTarget() then return false end
    return true
end

local function TickMeleeRangeCheck()
    local db = NaowhQOL and NaowhQOL.crosshair
    if not db or not db.meleeRecolor or not meleeCheckSupported then
        if isOutOfMelee then
            isOutOfMelee = false
            ApplyLayout()
        end
        StopMeleeSound()
        lastInRange = nil
        return
    end

    local wasOut = isOutOfMelee

    if not HasAttackableTarget() then
        isOutOfMelee = false
        StopMeleeSound()
        lastInRange = nil
    else
        local inMelee = C_Spell.IsSpellInRange(cachedMeleeSpellId, "target")
        isOutOfMelee = not inMelee

        if isOutOfMelee then
            -- Sound on transition from in-range to out-of-range
            if db.meleeSoundEnabled and lastInRange == true then
                StartMeleeSound(db)
            end
        else
            StopMeleeSound()
        end
        lastInRange = inMelee
    end

    if isOutOfMelee ~= wasOut then
        ApplyLayout()
    end
end

local tickOnUpdate = ns.PerfMonitor:Wrap("Crosshair Range", function(self, elapsed)
    tickAcc = tickAcc + elapsed
    if tickAcc < TICK_RATE then return end
    tickAcc = 0
    TickMeleeRangeCheck()
end)

local function StartMeleeTick()
    if not tickFrame:GetScript("OnUpdate") then
        tickFrame:SetScript("OnUpdate", tickOnUpdate)
    end
end

local function StopMeleeTick()
    tickFrame:SetScript("OnUpdate", nil)
    tickAcc = 0
    -- Clean up melee state when stopping
    if isOutOfMelee then
        isOutOfMelee = false
        ApplyLayout()
    end
    StopMeleeSound()
    lastInRange = nil
end

EvaluateMeleeTick = function()
    if ShouldTickRun() then
        StartMeleeTick()
    else
        StopMeleeTick()
    end
end

---------------------------------------------------------------------------
-- Holy Paladin Melee Range (item-based fallback)
---------------------------------------------------------------------------
local HPAL_ITEM_ID = 129055  -- Shoe Shine Kit (4 yards)

local function HpalCheckMeleeRange()
    local db = NaowhQOL and NaowhQOL.crosshair
    if not db or not db.enabled or not db.meleeRecolor then return end

    local wasOut = isOutOfMelee

    if not HasAttackableTarget() then
        isOutOfMelee = false
        StopMeleeSound()
        lastInRange = nil
    else
        local inMelee = C_Item.IsItemInRange(HPAL_ITEM_ID, "target")
        isOutOfMelee = not inMelee

        if isOutOfMelee then
            if db.meleeSoundEnabled and lastInRange == true then
                StartMeleeSound(db)
            end
        else
            StopMeleeSound()
        end
        lastInRange = inMelee
    end

    if isOutOfMelee ~= wasOut then
        ApplyLayout()
    end
end

local hpalTickAcc = 0
local hpalTickFrame = CreateFrame("Frame")

local hpalTickOnUpdate = ns.PerfMonitor:Wrap("Crosshair HPal", function(self, elapsed)
    hpalTickAcc = hpalTickAcc + elapsed
    if hpalTickAcc < TICK_RATE then return end
    hpalTickAcc = 0
    HpalCheckMeleeRange()
end)

local function StartHpalTick()
    if not hpalTickFrame:GetScript("OnUpdate") then
        hpalTickFrame:SetScript("OnUpdate", hpalTickOnUpdate)
    end
end

local function StopHpalTick()
    hpalTickFrame:SetScript("OnUpdate", nil)
    hpalTickAcc = 0
end

EvaluateHpalMode = function()
    local db = NaowhQOL and NaowhQOL.crosshair
    local classFile = ns.SpecUtil.GetClassName()
    local specIndex = ns.SpecUtil.GetSpecIndex()

    -- Holy Paladin auto-enables item-based detection (no melee spell available)
    local shouldEnable = classFile == "PALADIN"
        and specIndex == 1
        and db and db.enabled and db.meleeRecolor

    if shouldEnable then
        hpalEnabled = true
        meleeCheckSupported = true
        StartHpalTick()
    else
        hpalEnabled = false
        StopHpalTick()
    end
end

ns.EvaluateHpalMode = EvaluateHpalMode

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_REGEN_DISABLED")
loader:RegisterEvent("PLAYER_REGEN_ENABLED")
loader:RegisterEvent("DISPLAY_SIZE_CHANGED")
loader:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
loader:RegisterEvent("PLAYER_TARGET_CHANGED")
loader:RegisterEvent("PLAYER_LEAVING_WORLD")

loader:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" or event == "DISPLAY_SIZE_CHANGED" then
        isMounted = IsMounted()
        EvaluateHpalMode()
        CacheMeleeSpell()
        crosshairFrame:UpdateDisplay()
    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        RefreshVisibility()
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        RefreshVisibility()
    elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        isMounted = IsMounted()
        RefreshVisibility()
    elseif event == "PLAYER_TARGET_CHANGED" then
        isOutOfMelee = false
        lastInRange = nil
        StopMeleeSound()
        ApplyLayout()
        EvaluateMeleeTick()
    elseif event == "PLAYER_LEAVING_WORLD" then
        StopMeleeTick()
        StopHpalTick()
    end
end)

ns.SpecUtil.RegisterCallback("CrosshairDisplay", function()
    EvaluateHpalMode()
    CacheMeleeSpell()
    EvaluateMeleeTick()
end)

ns.CrosshairDisplay = crosshairFrame
ns.CrosshairDisplay.StopMeleeSound = StopMeleeSound
