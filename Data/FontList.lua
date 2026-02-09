local addonName, ns = ...

local ADDON_FONT_DIR = "Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\"

-- Custom fonts shipped with the addon (drop font files in Assets/Fonts and add a line here)
local custom = {
    { name = "Naowh", file = "Naowh.ttf" },
    { name = "Metropolis ExtraBold", file = "Metropolis-ExtraBold.otf" },
}

-- Built-in WoW game fonts (always available)
local builtIn = {
    { name = "2002",                           path = "Fonts\\2002.TTF" },
    { name = "2002 Bold",                      path = "Fonts\\2002B.TTF" },
    { name = "AR CrystalzcuheiGBK Demibold",   path = "Fonts\\ARHei.TTF" },
    { name = "AR Heiti2 Medium B5",            path = "Fonts\\bHEI00M.ttf" },
    { name = "AR Heiti2 Bold B5",              path = "Fonts\\bHEI01B.ttf" },
    { name = "AR Kaiti Medium B5",             path = "Fonts\\bKAI00M.ttf" },
    { name = "AR Leisu Demi B5",               path = "Fonts\\bLEI00D.ttf" },
    { name = "AR ZhongkaiGBK Medium",          path = "Fonts\\ARKai_T.TTF" },
    { name = "AR ZhongkaiGBK Medium (Combat)", path = "Fonts\\ARKai_C.TTF" },
    { name = "Arial Narrow",                   path = "Fonts\\ARIALN.TTF" },
    { name = "Friends",                        path = "Fonts\\FRIENDS.TTF" },
    { name = "Friz Quadrata TT",               path = "Fonts\\FRIZQT__.TTF" },
    { name = "Friz Quadrata TT CYR",           path = "Fonts\\FRIZQT___CYR.TTF" },
    { name = "MoK",                            path = "Fonts\\K_Pagetext.TTF" },
    { name = "Morpheus",                       path = "Fonts\\MORPHEUS.TTF" },
    { name = "Morpheus CYR",                   path = "Fonts\\MORPHEUS_CYR.TTF" },
    { name = "Nimrod MT",                      path = "Fonts\\NIM_____.ttf" },
    { name = "Skurri",                         path = "Fonts\\skurri.ttf" },
    { name = "Skurri CYR",                     path = "Fonts\\SKURRI_CYR.TTF" },
    { name = "YDIWingsM",                      path = "Fonts\\K_Damage.TTF" },
}

ns.FontList = {}

local dirty = true

-- Rebuild the merged list: built-in + custom + LSM fonts, sorted
function ns.FontList.Rebuild()
    if not dirty then return end
    dirty = false

    local merged = {}
    local seenPath = {}
    local seenName = {}

    -- Always include built-in fonts (highest priority)
    for _, f in ipairs(builtIn) do
        merged[#merged + 1] = { name = f.name, path = f.path }
        seenPath[f.path] = true
        seenName[f.name] = true
    end

    -- Custom fonts from Assets/Fonts (skip duplicates by path or name)
    for _, f in ipairs(custom) do
        local fullPath = ADDON_FONT_DIR .. f.file
        if not seenPath[fullPath] and not seenName[f.name] then
            merged[#merged + 1] = { name = f.name, path = fullPath }
            seenPath[fullPath] = true
            seenName[f.name] = true
        end
    end

    -- Pull in LSM fonts if available (skip duplicates by path or name)
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local fontTable = LSM:HashTable("font")
        if fontTable then
            for name, path in pairs(fontTable) do
                if not seenPath[path] and not seenName[name] then
                    merged[#merged + 1] = { name = name, path = path }
                    seenPath[path] = true
                    seenName[name] = true
                end
            end
        end
    end

    -- Sort alphabetically by name
    table.sort(merged, function(a, b) return a.name < b.name end)

    -- Replace the array portion of ns.FontList
    for i = 1, #ns.FontList do ns.FontList[i] = nil end
    for i, f in ipairs(merged) do ns.FontList[i] = f end

    -- Rebuild reverse lookup
    ns.FontList._nameByPath = {}
    for _, f in ipairs(ns.FontList) do
        ns.FontList._nameByPath[f.path] = f.name
    end
end

-- Mark dirty so next Rebuild() actually runs
function ns.FontList.MarkDirty()
    dirty = true
end

function ns.FontList.GetName(path)
    if not ns.FontList._nameByPath then ns.FontList.Rebuild() end
    return ns.FontList._nameByPath[path] or ("Unknown (" .. tostring(path) .. ")")
end

-- Hook LSM callback to mark dirty when new fonts are registered
local function HookLSM()
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        LSM.RegisterCallback(ns.FontList, "LibSharedMedia_Registered", function(_, mediatype)
            if mediatype == "font" then dirty = true end
        end)
    end
end

-- Initial build
ns.FontList.Rebuild()
HookLSM()
