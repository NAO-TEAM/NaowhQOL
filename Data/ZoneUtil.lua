local addonName, ns = ...

-- Zone/instance state cache with change callbacks

ns.ZoneUtil = {}

local currentZone = {
    zoneName = "",
    instanceType = "none",
    instanceID = 0,
    difficulty = 0,
    difficultyName = "",
}

local callbacks = {}

local retryTicker = nil
local MAX_RETRIES = 20
local RETRY_DELAY = 0.25

function ns.ZoneUtil.GetCurrentZone()
    return {
        zoneName       = currentZone.zoneName,
        instanceType   = currentZone.instanceType,
        instanceID     = currentZone.instanceID,
        difficulty     = currentZone.difficulty,
        difficultyName = currentZone.difficultyName,
    }
end

function ns.ZoneUtil.IsInDungeon()
    return currentZone.instanceType == "party"
end

function ns.ZoneUtil.IsInRaid()
    return currentZone.instanceType == "raid"
end

function ns.ZoneUtil.IsInInstance()
    return currentZone.instanceType ~= "none"
end

-- Mythic Keystone = party + difficulty 8
function ns.ZoneUtil.IsInMythicPlus()
    return currentZone.instanceType == "party" and currentZone.difficulty == 8
end

-- Register a callback for zone changes
function ns.ZoneUtil.RegisterCallback(key, func)
    if type(key) == "string" and type(func) == "function" then
        callbacks[key] = func
    end
end

function ns.ZoneUtil.UnregisterCallback(key)
    callbacks[key] = nil
end

-- Cleanup function for addon disable
function ns.ZoneUtil.Cleanup()
    CancelRetry()
    wipe(callbacks)
    currentZone.zoneName = ""
    currentZone.instanceType = "none"
    currentZone.instanceID = 0
    currentZone.difficulty = 0
    currentZone.difficultyName = ""
end

local function NotifyCallbacks()
    local snapshot = ns.ZoneUtil.GetCurrentZone()
    for k, fn in pairs(callbacks) do
        local ok, err = pcall(fn, snapshot)
        if not ok then
            print("|cffff0000NaowhQOL ZoneUtil:|r callback '" .. k .. "' error: " .. tostring(err))
        end
    end
end

-- Polls GetInstanceInfo and updates cache.
-- Returns false if difficulty is still pending (async load).
local function PollZoneInfo()
    local zoneName, instanceType, difficultyID, difficultyName,
          _, _, _, instanceID = GetInstanceInfo()

    -- Difficulty can report 0 briefly when entering instanced content
    if difficultyID == 0 and (instanceType == "raid" or instanceType == "party") then
        return false
    end

    local changed = (currentZone.instanceType ~= instanceType)
        or (currentZone.instanceID ~= instanceID)
        or (currentZone.difficulty ~= difficultyID)

    currentZone.zoneName = zoneName or ""
    currentZone.instanceType = instanceType or "none"
    currentZone.instanceID = instanceID or 0
    currentZone.difficulty = difficultyID or 0
    currentZone.difficultyName = difficultyName or ""

    if changed then NotifyCallbacks() end
    return true
end

local function CancelRetry()
    if retryTicker then
        retryTicker:Cancel()
        retryTicker = nil
    end
end

local function BeginZoneCheck()
    CancelRetry()

    if PollZoneInfo() then return end

    -- Difficulty was 0 for a raid/party; poll until it resolves
    local attempts = 0
    retryTicker = C_Timer.NewTicker(RETRY_DELAY, function(ticker)
        attempts = attempts + 1
        local resolved = PollZoneInfo()
        if resolved or attempts >= MAX_RETRIES then
            ticker:Cancel()
            retryTicker = nil
            if not resolved then NotifyCallbacks() end
        end
    end)
end

local eventFrame = CreateFrame("Frame", "NaowhQOL_ZoneUtil")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    BeginZoneCheck()
end)
