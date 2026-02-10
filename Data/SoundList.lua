local addonName, ns = ...

-- Color palette for sources (auto-cycled)
local SOURCE_COLORS = {
    { 1.0, 1.0, 1.0, 1 },    -- White (Base Game - always first)
    { 0.4, 0.8, 1.0, 1 },    -- Light Blue
    { 0.8, 0.5, 1.0, 1 },    -- Purple
    { 1.0, 0.8, 0.4, 1 },    -- Gold
    { 0.5, 1.0, 0.5, 1 },    -- Light Green
    { 1.0, 0.5, 0.5, 1 },    -- Light Red
    { 0.5, 1.0, 1.0, 1 },    -- Cyan
}

local BASE_GAME = "Base Game"

-- Built-in WoW game sounds (always available)
local builtIn = {
    { name = "Achievement Unlocked",    id = 13833 },
    { name = "Alarm Clock Warning 1",   id = 18871 },
    { name = "Alarm Clock Warning 2",   id = 12867 },
    { name = "Alarm Clock Warning 3",   id = 12889 },
    { name = "Battleground Countdown",  id = 25477 },
    { name = "Battleground Start",      id = 25478 },
    { name = "BNet Toast",              id = 18019 },
    { name = "Bonus Roll End",          id = 31581 },
    { name = "Bonus Roll Start",        id = 31579 },
    { name = "Challenge Complete",      id = 74526 },
    { name = "Challenge Keystone Up",   id = 74437 },
    { name = "Challenge New Record",    id = 33338 },
    { name = "Epic Loot Toast",         id = 31578 },
    { name = "Fishing Reel In",         id = 3407 },
    { name = "Flag Captured",           id = 8174 },
    { name = "GM Chat Warning",         id = 15273 },
    { name = "Group Finder App",        id = 47615 },
    { name = "Honor Rank Up",           id = 77003 },
    { name = "Item Repair",             id = 7994 },
    { name = "Legendary Loot Toast",    id = 63971 },
    { name = "Level Up",                id = 888  },
    { name = "LFG Denied",              id = 17341 },
    { name = "LFG Rewards",             id = 17316 },
    { name = "LFG Role Check",          id = 17317 },
    { name = "Loot Coin",               id = 120  },
    { name = "Loss of Control",         id = 34468 },
    { name = "Map Ping",                id = 3175 },
    { name = "Mission Complete",        id = 44294 },
    { name = "Mission Success Cheers",  id = 74702 },
    { name = "Personal Loot Banner",    id = 50893 },
    { name = "Pet Battle Start",        id = 31584 },
    { name = "Power Aura",              id = 23287 },
    { name = "PVP Enter Queue",         id = 8458 },
    { name = "PVP Through Queue",       id = 8459 },
    { name = "Quest Auto Complete",     id = 23404 },
    { name = "Quest Complete",          id = 878  },
    { name = "Quest List Open",         id = 875  },
    { name = "Raid Boss Defeated",      id = 50111 },
    { name = "Raid Boss Emote Warning", id = 12197 },
    { name = "Raid Boss Whisper",       id = 37666 },
    { name = "Raid Warning",            id = 8959 },
    { name = "Ready Check",             id = 8960 },
    { name = "Recipe Learned Toast",    id = 73919 },
    { name = "Scenario Ending",         id = 31754 },
    { name = "Scenario Stage End",      id = 31757 },
    { name = "Store Unwrap",            id = 64329 },
    { name = "Talent Ready Check",      id = 73281 },
    { name = "Talent Ready Toast",      id = 73280 },
    { name = "Talent Select",           id = 73279 },
    { name = "Tell Message",            id = 3081 },
    { name = "Tutorial Popup",          id = 7355 },
    { name = "Warforged Loot Toast",    id = 51561 },
    { name = "Warmode Activate",        id = 118563 },
    { name = "World Quest Complete",    id = 73277 },
    { name = "World Quest Start",       id = 73275 },
}

ns.SoundList = {}

local dirty = true
local sourceColors = {}     -- source name -> color table
local sourceList = {}       -- ordered list: {"All", "Base Game", ...}
local colorIndex = 2        -- start at 2 since Base Game always gets index 1

-- Extract addon name from a SharedMedia path (or handle numeric sound IDs)
local function GetSourceFromPath(path)
    -- Some LSM sounds use numeric IDs instead of paths
    if type(path) == "number" then
        return "SharedMedia"
    end
    -- Paths like: Interface\AddOns\AddonName\Sounds\file.ogg
    local addon = path:match("Interface\\AddOns\\([^\\]+)")
    if addon then
        return addon
    end
    -- Fallback for paths without standard addon structure
    return "SharedMedia"
end

-- Get or assign a color for a source
local function GetColorForSource(source)
    if sourceColors[source] then
        return sourceColors[source]
    end
    -- Assign next color in palette (wrap around if needed)
    local color = SOURCE_COLORS[colorIndex] or SOURCE_COLORS[#SOURCE_COLORS]
    sourceColors[source] = color
    colorIndex = colorIndex + 1
    if colorIndex > #SOURCE_COLORS then
        colorIndex = 2  -- wrap back, skip white (reserved for Base Game)
    end
    return color
end

-- Rebuild the merged list: built-in + LSM sounds, sorted
function ns.SoundList.Rebuild()
    if not dirty then return end
    dirty = false

    local merged = {}
    local seenName = {}
    local seenID = {}
    local seenPath = {}
    local sourcesFound = {}

    -- Reset color assignments (except Base Game)
    sourceColors = { [BASE_GAME] = SOURCE_COLORS[1] }
    colorIndex = 2

    -- Add built-in sounds first (highest priority)
    local baseGameColor = SOURCE_COLORS[1]
    for _, s in ipairs(builtIn) do
        merged[#merged + 1] = {
            name = s.name,
            id = s.id,
            path = nil,
            source = BASE_GAME,
            color = baseGameColor,
        }
        seenName[s.name] = true
        seenID[s.id] = true
        sourcesFound[BASE_GAME] = true
    end

    -- Pull in LSM sounds if available
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local soundTable = LSM:HashTable("sound")
        if soundTable then
            for name, pathOrID in pairs(soundTable) do
                -- LSM can return numeric IDs or string paths
                local isNumeric = type(pathOrID) == "number"
                local skipKey = isNumeric and pathOrID or pathOrID

                -- Skip duplicates
                if not seenName[name] and not (isNumeric and seenID[pathOrID]) and not (not isNumeric and seenPath[pathOrID]) then
                    local source = GetSourceFromPath(pathOrID)
                    local color = GetColorForSource(source)
                    merged[#merged + 1] = {
                        name = name,
                        id = isNumeric and pathOrID or nil,
                        path = isNumeric and nil or pathOrID,
                        source = source,
                        color = color,
                    }
                    seenName[name] = true
                    if isNumeric then
                        seenID[pathOrID] = true
                    else
                        seenPath[pathOrID] = true
                    end
                    sourcesFound[source] = true
                end
            end
        end
    end

    -- Sort alphabetically by name
    table.sort(merged, function(a, b) return a.name < b.name end)

    -- Replace the array portion of ns.SoundList
    for i = 1, #ns.SoundList do ns.SoundList[i] = nil end
    for i, s in ipairs(merged) do ns.SoundList[i] = s end

    -- Rebuild reverse lookups
    ns.SoundList._nameByID = {}
    ns.SoundList._nameByPath = {}
    ns.SoundList._entryByID = {}
    ns.SoundList._entryByPath = {}
    for _, s in ipairs(ns.SoundList) do
        if s.id then
            ns.SoundList._nameByID[s.id] = s.name
            ns.SoundList._entryByID[s.id] = s
        end
        if s.path then
            ns.SoundList._nameByPath[s.path] = s.name
            ns.SoundList._entryByPath[s.path] = s
        end
    end

    -- Build ordered source list for filter dropdown
    sourceList = { "All" }
    -- Add Base Game first if present
    if sourcesFound[BASE_GAME] then
        sourceList[#sourceList + 1] = BASE_GAME
    end
    -- Add other sources alphabetically
    local otherSources = {}
    for src in pairs(sourcesFound) do
        if src ~= BASE_GAME then
            otherSources[#otherSources + 1] = src
        end
    end
    table.sort(otherSources)
    for _, src in ipairs(otherSources) do
        sourceList[#sourceList + 1] = src
    end
end

-- Mark dirty so next Rebuild() actually runs
function ns.SoundList.MarkDirty()
    dirty = true
end

-- Get name by ID (legacy) or by path
function ns.SoundList.GetName(idOrPath)
    if not ns.SoundList._nameByID then ns.SoundList.Rebuild() end
    if type(idOrPath) == "number" then
        return ns.SoundList._nameByID[idOrPath] or ("Unknown (" .. tostring(idOrPath) .. ")")
    else
        return ns.SoundList._nameByPath[idOrPath] or ("Unknown")
    end
end

-- Get entry by sound data table {id=...} or {path=...}
function ns.SoundList.GetEntry(soundData)
    if not soundData then return nil end
    if not ns.SoundList._entryByID then ns.SoundList.Rebuild() end
    if soundData.id then
        return ns.SoundList._entryByID[soundData.id]
    elseif soundData.path then
        return ns.SoundList._entryByPath[soundData.path]
    end
    return nil
end

-- Get ordered list of sources for filter dropdown
function ns.SoundList.GetSources()
    if #sourceList == 0 then ns.SoundList.Rebuild() end
    return sourceList
end

-- Default fallback sound (Raid Warning)
local FALLBACK_SOUND_ID = 8959

-- Unified playback - handles both ID and path based sounds
-- Returns true if sound played successfully, false if fallback was used
function ns.SoundList.Play(soundData)
    if not soundData then return false end

    if soundData.id then
        PlaySound(soundData.id, "Master")
        return true
    elseif soundData.path then
        -- PlaySoundFile returns willPlay, handle (or just willPlay in some versions)
        local willPlay = PlaySoundFile(soundData.path, "Master")
        if not willPlay then
            -- File missing or invalid - play fallback sound
            PlaySound(FALLBACK_SOUND_ID, "Master")
            return false
        end
        return true
    end
    return false
end

-- Hook LSM callback to mark dirty when new sounds are registered
local function HookLSM()
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        LSM.RegisterCallback(ns.SoundList, "LibSharedMedia_Registered", function(_, mediatype)
            if mediatype == "sound" then dirty = true end
        end)
    end
end

-- Initial build
ns.SoundList.Rebuild()
HookLSM()
