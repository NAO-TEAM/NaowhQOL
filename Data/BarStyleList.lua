local addonName, ns = ...

-- Blizzard statusbar textures that ship with the game (always available)
local builtIn = {
    { name = "Blizzard",                       path = [[Interface\TargetingFrame\UI-StatusBar]] },
    { name = "Blizzard Character Skills Bar",  path = [[Interface\PaperDollInfoFrame\UI-Character-Skills-Bar]] },
    { name = "Blizzard Raid Bar",              path = [[Interface\RaidFrame\Raid-Bar-Hp-Fill]] },
    { name = "Solid",                          path = [[Interface\Buttons\WHITE8X8]] },
}

ns.BarStyleList = {}

local dirty = true

-- Rebuild the merged list: built-in + LSM statusbar textures, sorted
function ns.BarStyleList.Rebuild()
    if not dirty then return end
    dirty = false

    local merged = {}
    local seen = {}

    -- Always include built-in Blizzard styles
    for _, t in ipairs(builtIn) do
        merged[#merged + 1] = { name = t.name, path = t.path }
        seen[t.path] = true
    end

    -- Pull in LSM statusbar textures if available
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local barTable = LSM:HashTable("statusbar")
        if barTable then
            for name, path in pairs(barTable) do
                if not seen[path] then
                    merged[#merged + 1] = { name = name, path = path }
                    seen[path] = true
                end
            end
        end
    end

    -- Sort alphabetically by name
    table.sort(merged, function(a, b) return a.name < b.name end)

    -- Replace the array portion of ns.BarStyleList
    for i = 1, #ns.BarStyleList do ns.BarStyleList[i] = nil end
    for i, t in ipairs(merged) do ns.BarStyleList[i] = t end

    -- Rebuild reverse lookup
    ns.BarStyleList._nameByPath = {}
    for _, t in ipairs(ns.BarStyleList) do
        ns.BarStyleList._nameByPath[t.path] = t.name
    end
end

-- Mark dirty so next Rebuild() actually runs
function ns.BarStyleList.MarkDirty()
    dirty = true
end

function ns.BarStyleList.GetName(path)
    if not ns.BarStyleList._nameByPath then ns.BarStyleList.Rebuild() end
    return ns.BarStyleList._nameByPath[path] or ("Unknown (" .. tostring(path) .. ")")
end

-- Hook LSM callback to mark dirty when new statusbar textures are registered
local function HookLSM()
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        LSM.RegisterCallback(ns.BarStyleList, "LibSharedMedia_Registered", function(_, mediatype)
            if mediatype == "statusbar" then dirty = true end
        end)
    end
end

-- Initial build
ns.BarStyleList.Rebuild()
HookLSM()
