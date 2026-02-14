local _, ns = ...

-- BuffWatcherV2 Watchers Module
-- Per-unit UNIT_AURA watcher management

local Watchers = {}
ns.BWV2Watchers = Watchers

local BWV2 = ns.BWV2

-- Callback function set by Core.lua
local onUnitAuraChangedCallback = nil

-- Set the callback for when unit auras change
function Watchers:SetCallback(callback)
    onUnitAuraChangedCallback = callback
end

-- Set up a watcher for a specific unit
function Watchers:SetupWatcher(unit)
    if BWV2.activeWatchers[unit] then
        return  -- Already watching this unit
    end

    local frame = CreateFrame("Frame")
    frame.unit = unit

    frame:RegisterUnitEvent("UNIT_AURA", unit)
    frame:SetScript("OnEvent", function(self, event, changedUnit, updateInfo)
        if changedUnit == unit and onUnitAuraChangedCallback then
            onUnitAuraChangedCallback(unit, updateInfo)
        end
    end)

    BWV2.activeWatchers[unit] = frame
end

-- Remove a watcher for a specific unit
function Watchers:RemoveWatcher(unit)
    local frame = BWV2.activeWatchers[unit]
    if frame then
        frame:UnregisterAllEvents()
        frame:SetScript("OnEvent", nil)
        BWV2.activeWatchers[unit] = nil
    end
end

-- Remove all active watchers
function Watchers:RemoveAllWatchers()
    for unit, frame in pairs(BWV2.activeWatchers) do
        frame:UnregisterAllEvents()
        frame:SetScript("OnEvent", nil)
    end
    wipe(BWV2.activeWatchers)
end

-- Get count of active watchers
function Watchers:GetWatcherCount()
    local count = 0
    for _ in pairs(BWV2.activeWatchers) do
        count = count + 1
    end
    return count
end

-- Check if we're watching a specific unit
function Watchers:IsWatching(unit)
    return BWV2.activeWatchers[unit] ~= nil
end
