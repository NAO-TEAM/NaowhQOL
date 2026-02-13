local addonName, ns = ...
local L = ns.L
local W = ns.Widgets

-- State tracking
local isMounted = false
local isInVehicle = false
local isDead = false
local dismountTimer = nil
local DISMOUNT_DELAY = 5

-- Warning states
local WARNING_NONE = 0
local WARNING_MISSING = 1
local WARNING_PASSIVE = 2
local WARNING_WRONG_PET = 3

local UNLOCK_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

-- Spell IDs for class detection
local HUNTER_NO_PET_TALENTS = { 466846, 1232995, 1223323 }  -- Lone Wolf, Pack Leader, etc.
local GRIMOIRE_OF_SACRIFICE = 108503
local GRIMOIRE_SACRIFICE_BUFF = 196099
local FELGUARD_SPELL = 30146
local WATER_ELEMENTAL_SPELL = 31687
local DEMONOLOGY_SPEC = 2  -- Spec index
local UNHOLY_SPEC = 3      -- Spec index
local FROST_MAGE_SPEC = 3  -- Spec index

-- Check if player is a pet class that should track pets
local function IsPetClass()
    local cls = ns.SpecUtil.GetClassName()
    return cls == "HUNTER" or cls == "WARLOCK" or cls == "DEATHKNIGHT" or cls == "MAGE"
end

-- Check if current spec should have a pet
local function ShouldHavePet()
    local cls = ns.SpecUtil.GetClassName()
    local specIdx = ns.SpecUtil.GetSpecIndex()

    if cls == "HUNTER" then
        -- Check for no-pet talents (Lone Wolf, etc.)
        for _, spellID in ipairs(HUNTER_NO_PET_TALENTS) do
            if IsPlayerSpell(spellID) then
                return false
            end
        end
        return true

    elseif cls == "WARLOCK" then
        -- Check for Grimoire of Sacrifice
        if IsPlayerSpell(GRIMOIRE_OF_SACRIFICE) then
            local auraData = C_UnitAuras.GetPlayerAuraBySpellID(GRIMOIRE_SACRIFICE_BUFF)
            if auraData then
                return false  -- Pet is sacrificed, no pet needed
            end
        end
        return true

    elseif cls == "DEATHKNIGHT" then
        -- Only Unholy needs a pet
        return specIdx == UNHOLY_SPEC

    elseif cls == "MAGE" then
        -- Only Frost with Water Elemental talent
        if specIdx == FROST_MAGE_SPEC then
            return IsPlayerSpell(WATER_ELEMENTAL_SPELL)
        end
        return false
    end

    return false
end

-- Check if pet is on passive stance
local function IsPetPassive()
    if not PetHasActionBar() then return false end

    for i = 1, NUM_PET_ACTION_SLOTS or 10 do
        local name, _, isToken, isActive = GetPetActionInfo(i)
        if isToken and name == "PET_MODE_PASSIVE" and isActive then
            return true
        end
    end
    return false
end

-- Check for wrong pet (Demo Warlock without Felguard)
local function IsWrongPet()
    local cls = ns.SpecUtil.GetClassName()
    local specIdx = ns.SpecUtil.GetSpecIndex()

    if cls == "WARLOCK" and specIdx == DEMONOLOGY_SPEC then
        -- Check if player has Felguard talent
        if IsPlayerSpell(FELGUARD_SPELL) then
            local petFamily = UnitCreatureFamily("pet")
            if petFamily then
                -- Check if pet is NOT a Felguard using user-configurable family name
                local db = NaowhQOL.petTracker
                local felguardNames = db and db.felguardFamily or "felguard,teufelswache"
                local lowerFamily = petFamily:lower()

                for name in felguardNames:gmatch("[^,]+") do
                    local trimmed = name:match("^%s*(.-)%s*$"):lower()
                    if trimmed ~= "" and lowerFamily:find(trimmed, 1, true) then
                        return false  -- Pet is a Felguard variant
                    end
                end
                return true  -- Pet family didn't match any configured names
            end
        end
    end
    return false
end

-- Evaluate current warning state
local function EvaluateWarning()
    local db = NaowhQOL.petTracker
    if not db or not db.enabled then return WARNING_NONE end

    -- Skip if not a pet class
    if not IsPetClass() then return WARNING_NONE end

    -- Skip in suppressed states
    if isDead or isMounted or isInVehicle then return WARNING_NONE end

    -- Instance-only check
    if db.onlyInInstance then
        local inInstance = IsInInstance()
        if not inInstance then return WARNING_NONE end
    end

    -- Check if spec should have a pet
    if not ShouldHavePet() then return WARNING_NONE end

    -- Check pet states in priority order
    if not UnitExists("pet") then
        return WARNING_MISSING
    end

    -- Check for wrong pet (Demo Warlock)
    if IsWrongPet() then
        return WARNING_WRONG_PET
    end

    -- Check passive stance
    if IsPetPassive() then
        return WARNING_PASSIVE
    end

    return WARNING_NONE
end

-- Create the display frame
local petFrame = CreateFrame("Frame", "NaowhQOL_PetTracker", UIParent, "BackdropTemplate")
petFrame:SetSize(200, 50)
petFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
petFrame:Hide()

-- Icon texture
local iconTexture = petFrame:CreateTexture(nil, "ARTWORK")
iconTexture:SetSize(32, 32)
iconTexture:SetPoint("LEFT", petFrame, "LEFT", 10, 0)
iconTexture:SetTexture(132161)  -- Beast Call / summon pet icon

-- Warning label
local warningLabel = petFrame:CreateFontString(nil, "OVERLAY")
warningLabel:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", 20, "OUTLINE")
warningLabel:SetPoint("CENTER")

local resizeHandle

function petFrame:UpdateDisplay()
    local db = NaowhQOL.petTracker
    if not db then return end

    -- Unlock mode handling
    petFrame:EnableMouse(db.unlock)
    if db.unlock then
        petFrame:SetBackdrop(UNLOCK_BACKDROP)
        petFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        petFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        if resizeHandle then resizeHandle:Show() end
        petFrame:Show()
    else
        petFrame:SetBackdrop(nil)
        if resizeHandle then resizeHandle:Hide() end
    end

    -- Position initialization
    if not petFrame.initialized then
        petFrame:ClearAllPoints()
        local point = db.point or "CENTER"
        local x = db.x or 0
        local y = db.y or 200
        petFrame:SetPoint(point, UIParent, point, x, y)
        petFrame:SetSize(db.width or 200, db.height or 50)
        petFrame.initialized = true
    end

    -- Font sizing
    local fontSize = math.max(12, math.min(48, db.textSize or 20))
    warningLabel:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", fontSize, "OUTLINE")

    -- Icon visibility and positioning
    if db.showIcon then
        iconTexture:Show()
        iconTexture:SetSize(db.iconSize or 32, db.iconSize or 32)
        warningLabel:ClearAllPoints()
        warningLabel:SetPoint("LEFT", iconTexture, "RIGHT", 8, 0)
    else
        iconTexture:Hide()
        warningLabel:ClearAllPoints()
        warningLabel:SetPoint("CENTER")
    end

    -- Evaluate warning state
    local warning = EvaluateWarning()

    if warning == WARNING_NONE then
        if not db.unlock then
            petFrame:Hide()
        else
            warningLabel:SetText(db.missingText or L["PETTRACKER_MISSING_DEFAULT"])
            warningLabel:SetTextColor(0.5, 0.5, 0.5)  -- Gray when unlocked but no warning
        end
        return
    end

    -- Set warning text and color based on state
    local r, g, b = W.GetEffectiveColor(db, "colorR", "colorG", "colorB", "colorUseClassColor")

    if warning == WARNING_MISSING then
        warningLabel:SetText(db.missingText or L["PETTRACKER_MISSING_DEFAULT"])
        warningLabel:SetTextColor(r, g, b)
    elseif warning == WARNING_PASSIVE then
        warningLabel:SetText(db.passiveText or L["PETTRACKER_PASSIVE_DEFAULT"])
        warningLabel:SetTextColor(1, 0.5, 0)  -- Orange for passive
    elseif warning == WARNING_WRONG_PET then
        warningLabel:SetText(db.wrongPetText or L["PETTRACKER_WRONGPET_DEFAULT"])
        warningLabel:SetTextColor(1, 0.3, 0.3)  -- Light red for wrong pet
    end

    petFrame:Show()
end

-- Cancel any pending dismount timer
local function CancelDismountTimer()
    if dismountTimer then
        dismountTimer:Cancel()
        dismountTimer = nil
    end
end

-- Event handling
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("UNIT_PET")
loader:RegisterEvent("PET_BAR_UPDATE")
loader:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
loader:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
loader:RegisterEvent("UNIT_ENTERED_VEHICLE")
loader:RegisterEvent("UNIT_EXITED_VEHICLE")
loader:RegisterEvent("PLAYER_DEAD")
loader:RegisterEvent("PLAYER_ALIVE")
loader:RegisterEvent("PLAYER_UNGHOST")
loader:RegisterEvent("SPELLS_CHANGED")

loader:SetScript("OnEvent", ns.PerfMonitor:Wrap("PetTracker", function(self, event, unit)
    local db = NaowhQOL.petTracker
    if not db then return end

    if event == "PLAYER_LOGIN" then
        -- Initialize state
        isMounted = IsMounted()
        isInVehicle = UnitInVehicle("player")
        isDead = UnitIsDeadOrGhost("player")

        -- Setup draggable frame
        db.width = db.width or 200
        db.height = db.height or 50
        db.point = db.point or "CENTER"
        db.x = db.x or 0
        db.y = db.y or 200

        W.MakeDraggable(petFrame, { db = db })
        resizeHandle = W.CreateResizeHandle(petFrame, {
            db = db,
            onResize = function() petFrame:UpdateDisplay() end,
        })

        petFrame.initialized = false
        petFrame:UpdateDisplay()

        -- Register spec change callback
        ns.SpecUtil.RegisterCallback("PetTracker", function()
            petFrame:UpdateDisplay()
        end)

        return
    end

    -- State updates
    if event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        local wasMounted = isMounted
        isMounted = IsMounted()

        if wasMounted and not isMounted then
            -- Just dismounted - delay update to allow pet to appear
            CancelDismountTimer()
            dismountTimer = C_Timer.NewTimer(DISMOUNT_DELAY, function()
                dismountTimer = nil
                petFrame:UpdateDisplay()
            end)
            return
        elseif isMounted then
            CancelDismountTimer()
        end
    elseif event == "UNIT_ENTERED_VEHICLE" and unit == "player" then
        isInVehicle = true
    elseif event == "UNIT_EXITED_VEHICLE" and unit == "player" then
        isInVehicle = false
    elseif event == "PLAYER_DEAD" then
        isDead = true
    elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        isDead = false
    elseif event == "UNIT_PET" then
        -- Pet changed - cancel dismount timer if active
        CancelDismountTimer()
    end

    petFrame:UpdateDisplay()
end))

-- Export frame reference for config panel
ns.PetTrackerDisplay = petFrame
