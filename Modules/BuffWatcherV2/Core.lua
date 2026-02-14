local _, ns = ...

-- BuffWatcherV2 Core Module
-- Event handling, lifecycle, and slash commands

local Core = {}
ns.BWV2Core = Core

local BWV2 = ns.BWV2
local Categories = ns.BWV2Categories
local Watchers = ns.BWV2Watchers
local Scanner = ns.BWV2Scanner
local ReportCard = ns.BWV2ReportCard

-- Watcher callback throttle (100ms)
local WATCHER_THROTTLE = 0.1
local lastWatcherUpdate = 0

-- Event frame
local eventFrame = CreateFrame("Frame")

-- Trigger a scan
local function TriggerScan()
    if not BWV2:IsEnabled() then
        return
    end

    if BWV2.scanInProgress then
        return
    end

    if InCombatLockdown() then
        print("|cffff6600[BuffWatcher]|r Cannot scan during combat.")
        return
    end

    if ns.ZoneUtil.IsInMythicPlus() then
        print("|cffff6600[BuffWatcher]|r Disabled in M+.")
        return
    end

    BWV2.scanInProgress = true
    print("|cff00ff00[BuffWatcher]|r Scanning raid buffs...")

    Scanner:StartBatchedScan(function()
        BWV2.scanInProgress = false
        BWV2.lastScanTime = GetTime()
        Core:PrintSummary()
        ReportCard:Show()
    end)
end

-- Handle unit aura changes (watcher callback)
local function OnUnitAuraChanged(unit, updateInfo)
    if not BWV2:IsEnabled() then return end
    if InCombatLockdown() then return end

    -- Throttle rapid callbacks (100ms)
    local now = GetTime()
    if now - lastWatcherUpdate < WATCHER_THROTTLE then
        return
    end
    lastWatcherUpdate = now

    -- Re-scan this unit (also runs category scans internally)
    Scanner:RescanUnit(unit)

    -- Check stored results for missing buffs (avoid redundant scans)
    local stillMissing = BWV2.missingByCategory and next(BWV2.missingByCategory)

    if not stillMissing then
        Watchers:RemoveWatcher(unit)
    end

    -- Update report card if visible
    if ReportCard:IsShown() then
        ReportCard:Update()
    end
end

-- Set up the watcher callback
Watchers:SetCallback(OnUnitAuraChanged)

-- Print summary of missing buffs
function Core:PrintSummary()
    local missing = BWV2.missingByCategory
    local inventoryStatus = BWV2.inventoryStatus or {}

    if not missing or not next(missing) then
        print("|cff00ff00[BuffWatcher]|r All players have required buffs!")
        -- Still show inventory status if we have any
        if next(inventoryStatus) then
            print("  |cffffcc00Inventory:|r")
            for key, data in pairs(inventoryStatus) do
                print("    |cff00ff00✓|r " .. (data.name or key) .. ": " .. data.count)
            end
        end
        return
    end

    print("|cffff6600[BuffWatcher]|r Missing buffs:")

    -- Group by category type for cleaner output
    local raidMissing = {}
    local classBuffMissing = {}
    local consumableMissing = {}
    local inventoryMissing = {}

    for key, data in pairs(missing) do
        local found = false

        -- Check raid buffs
        for _, buff in ipairs(Categories.RAID) do
            if buff.key == key then
                raidMissing[key] = data
                found = true
                break
            end
        end

        -- Check consumables
        if not found then
            for _, buff in ipairs(Categories.CONSUMABLE_GROUPS) do
                if buff.key == key then
                    consumableMissing[key] = data
                    found = true
                    break
                end
            end
        end

        -- Check inventory
        if not found then
            for _, group in ipairs(Categories.INVENTORY_GROUPS) do
                if group.key == key then
                    inventoryMissing[key] = data
                    found = true
                    break
                end
            end
        end

        -- Remaining are class buffs (user-defined)
        if not found then
            classBuffMissing[key] = data
        end
    end

    -- Print raid buffs
    if next(raidMissing) then
        print("  |cffffcc00Raid Buffs:|r")
        for key, data in pairs(raidMissing) do
            local coverage = data.missing and string.format(" (%d/%d covered)", data.total - data.missing, data.total) or ""
            print("    - " .. (data.name or key) .. coverage)
        end
    end

    -- Print class buffs (grouped by check type)
    if next(classBuffMissing) then
        print("  |cffffcc00Class Buffs:|r")
        for key, data in pairs(classBuffMissing) do
            local typeTag = ""
            if data.checkType == "targeted" then
                typeTag = " (targeted)"
            elseif data.checkType == "weaponEnchant" then
                typeTag = " (weapon)"
            end
            print("    - " .. (data.name or key) .. typeTag)
        end
    end

    -- Print consumables
    if next(consumableMissing) then
        print("  |cffffcc00Consumables:|r")
        for key, data in pairs(consumableMissing) do
            print("    - " .. (data.name or key))
        end
    end

    -- Print inventory (both missing and passes with counts)
    local inventoryStatus = BWV2.inventoryStatus or {}
    if next(inventoryMissing) or next(inventoryStatus) then
        print("  |cffffcc00Inventory:|r")
        -- Print passes first (with count)
        for key, data in pairs(inventoryStatus) do
            print("    |cff00ff00✓|r " .. (data.name or key) .. ": " .. data.count)
        end
        -- Print missing
        for key, data in pairs(inventoryMissing) do
            print("    |cffff0000✗|r " .. (data.name or key) .. ": Missing")
        end
    end
end

-- Event handler
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "READY_CHECK" then
        TriggerScan()

    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Combat started - kill all watchers
        Watchers:RemoveAllWatchers()

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Combat ended - could optionally rescan
        -- For now, do nothing

    elseif event == "PLAYER_LOGIN" then
        -- Initialize saved variables
        BWV2:InitSavedVars()
    end
end)

-- Register events
eventFrame:RegisterEvent("READY_CHECK")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

-- Slash command for manual scan
SLASH_NSCAN1 = "/nscan"
SlashCmdList["NSCAN"] = function(msg)
    TriggerScan()
end

-- Public API
function Core:TriggerScan()
    TriggerScan()
end

function Core:GetLastScanTime()
    return BWV2.lastScanTime
end

function Core:GetMissingBuffs()
    return BWV2.missingByCategory
end
