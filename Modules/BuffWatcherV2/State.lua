local _, ns = ...

-- BuffWatcherV2 State Module
-- Central state tables and utility functions

local BWV2 = {}
ns.BWV2 = BWV2

-- State tables
BWV2.raidResults = {}       -- unit -> { buffs = {spellID = auraData}, spec = id }
BWV2.missingByPlayer = {}   -- unit -> { categoryKey = true, ... }
BWV2.activeWatchers = {}    -- unit -> frame (one per unit with missing buffs)
BWV2.inventoryStatus = {}   -- key -> { name, count, pass = true }
BWV2.scanInProgress = false
BWV2.lastScanTime = 0

-- Report card results (full pass/fail data with icons)
BWV2.scanResults = {
    raidBuffs = {},     -- { key, name, spellID, icon, pass, covered, total }
    consumables = {},   -- { key, name, spellID, icon, pass, remaining }
    inventory = {},     -- { key, name, itemID, icon, pass, count }
    classBuffs = {},    -- { key, name, spellID, icon, pass }
}

-- Reset all state tables
function BWV2:ResetState()
    wipe(self.raidResults)
    wipe(self.missingByPlayer)
    wipe(self.inventoryStatus)
    -- Reset scan results for report card
    wipe(self.scanResults.raidBuffs)
    wipe(self.scanResults.consumables)
    wipe(self.scanResults.inventory)
    wipe(self.scanResults.classBuffs)
    -- Note: watchers should be cleaned up via Watchers.RemoveAllWatchers() before reset
    self.scanInProgress = false
end

-- Detect current content type for threshold selection
function BWV2:GetCurrentContentType()
    local inInstance, instanceType = IsInInstance()
    if not inInstance then
        return "other"
    elseif instanceType == "raid" then
        return "raid"
    else
        return "dungeon"
    end
end

-- Check if a class is present in the current group
function BWV2:HasClassInGroup(className)
    local inRaid = IsInRaid()
    local groupSize = GetNumGroupMembers()

    if groupSize == 0 then
        -- Solo player
        local _, playerClass = UnitClass("player")
        return playerClass == className
    end

    for i = 1, groupSize do
        local unit
        if inRaid then
            unit = "raid" .. i
        else
            unit = (i == 1) and "player" or ("party" .. (i - 1))
        end

        if UnitExists(unit) then
            local _, unitClass = UnitClass(unit)
            if unitClass == className then
                return true
            end
        end
    end

    return false
end

-- Get player's current specialization ID
function BWV2:GetPlayerSpecID()
    local specIndex = GetSpecialization()
    if specIndex then
        return GetSpecializationInfo(specIndex)
    end
    return nil
end

-- Check if player has a specific talent/spell known
function BWV2:PlayerHasTalent(spellID)
    return IsPlayerSpell(spellID)
end

-- Initialize default saved variables if needed
function BWV2:InitSavedVars()
    if not NaowhQOL then NaowhQOL = {} end
    if not NaowhQOL.buffWatcherV2 then
        NaowhQOL.buffWatcherV2 = {
            enabled = true,
            userEntries = {
                raidBuffs = { spellIDs = {} },
                consumables = { spellIDs = {} },
                shamanImbues = { enchantIDs = {} },
                roguePoisons = { enchantIDs = {} },
                shamanShields = { spellIDs = {} },
            },
            categoryEnabled = {
                raidBuffs = true,
                consumables = true,
                shamanImbues = true,
                roguePoisons = true,
                shamanShields = true,
            },
            thresholds = {
                dungeon = 2400,  -- 40 min in seconds
                raid = 900,      -- 15 min
                other = 300,     -- 5 min
            },
            talentMods = {
                -- Default example: Dragon-Tempered Blades for rogue poisons
                roguePoisons = {
                    { type = "requireCount", talentID = 381802, count = 4 },
                },
            },
            -- Track which default spells user has disabled per category
            disabledDefaults = {},
            -- Per-consumable group enable/disable
            consumableGroupEnabled = {
                flask = true,
                food = true,
                rune = true,
                weaponBuff = true,
            },
            -- Per-inventory group enable/disable
            inventoryGroupEnabled = {
                dpsPotion = true,
                healthPotion = true,
                healthstone = true,
                gatewayControl = true,
            },
            -- Class-specific buff groups (user-defined)
            classBuffs = {
                WARRIOR     = { enabled = true, groups = {} },
                PALADIN     = { enabled = true, groups = {} },
                HUNTER      = { enabled = true, groups = {} },
                ROGUE       = { enabled = true, groups = {} },
                PRIEST      = { enabled = true, groups = {} },
                DEATHKNIGHT = { enabled = true, groups = {} },
                SHAMAN      = { enabled = true, groups = {} },
                MAGE        = { enabled = true, groups = {} },
                WARLOCK     = { enabled = true, groups = {} },
                MONK        = { enabled = true, groups = {} },
                DRUID       = { enabled = true, groups = {} },
                DEMONHUNTER = { enabled = true, groups = {} },
                EVOKER      = { enabled = true, groups = {} },
            },
            -- Report card frame position
            reportCardPosition = nil,  -- { point, x, y }
            -- Last expanded config section (for tab memory)
            lastSection = "classBuffs",
        }
    end

    -- Migration: ensure tables exist for existing users
    if not NaowhQOL.buffWatcherV2.disabledDefaults then
        NaowhQOL.buffWatcherV2.disabledDefaults = {}
    end
    if not NaowhQOL.buffWatcherV2.consumableGroupEnabled then
        NaowhQOL.buffWatcherV2.consumableGroupEnabled = {
            flask = true,
            food = true,
            rune = true,
            weaponBuff = true,
        }
    end
    if not NaowhQOL.buffWatcherV2.inventoryGroupEnabled then
        NaowhQOL.buffWatcherV2.inventoryGroupEnabled = {
            healthPotion = true,
            healthstone = true,
            gatewayControl = true,
        }
    end
    if not NaowhQOL.buffWatcherV2.classBuffs then
        NaowhQOL.buffWatcherV2.classBuffs = {
            WARRIOR     = { enabled = true, groups = {} },
            PALADIN     = { enabled = true, groups = {} },
            HUNTER      = { enabled = true, groups = {} },
            ROGUE       = { enabled = true, groups = {} },
            PRIEST      = { enabled = true, groups = {} },
            DEATHKNIGHT = { enabled = true, groups = {} },
            SHAMAN      = { enabled = true, groups = {} },
            MAGE        = { enabled = true, groups = {} },
            WARLOCK     = { enabled = true, groups = {} },
            MONK        = { enabled = true, groups = {} },
            DRUID       = { enabled = true, groups = {} },
            DEMONHUNTER = { enabled = true, groups = {} },
            EVOKER      = { enabled = true, groups = {} },
        }
    end
end

-- Get saved variables table
function BWV2:GetDB()
    self:InitSavedVars()
    return NaowhQOL.buffWatcherV2
end

-- Check if module is enabled
function BWV2:IsEnabled()
    local db = self:GetDB()
    return db.enabled
end

-- Get threshold for current content type
function BWV2:GetThreshold()
    local db = self:GetDB()
    local contentType = self:GetCurrentContentType()
    return db.thresholds[contentType] or 300
end
