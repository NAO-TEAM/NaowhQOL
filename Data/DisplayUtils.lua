local addonName, ns = ...
if not ns then return end
local L = ns.L

ns.DisplayUtils = {}

---------------------------------------------------------------------------
-- Texture caching with simple hash-based eviction
-- Uses a simpler approach: just overwrite on collision, no LRU tracking
-- This avoids O(n) operations while still providing effective caching
---------------------------------------------------------------------------
local MAX_CACHE_SIZE = 100
local textureCache = {}
local cacheCount = 0

function ns.DisplayUtils.GetCachedTexture(spellId)
    if not spellId then return nil end
    local tex = textureCache[spellId]
    if tex then
        return tex
    end

    tex = C_Spell.GetSpellTexture(spellId)
    if tex then
        -- Simple eviction: if cache is full, clear half of it
        -- This is O(n) but only happens rarely, not on every access
        if cacheCount >= MAX_CACHE_SIZE then
            local cleared = 0
            for k in pairs(textureCache) do
                textureCache[k] = nil
                cleared = cleared + 1
                if cleared >= MAX_CACHE_SIZE / 2 then break end
            end
            cacheCount = cacheCount - cleared
        end
        textureCache[spellId] = tex
        cacheCount = cacheCount + 1
    end
    return tex
end

function ns.DisplayUtils.ClearTextureCache()
    wipe(textureCache)
    cacheCount = 0
end

---------------------------------------------------------------------------
-- Aura caching with event-driven updates
-- Instead of scanning on every query, we cache on UNIT_AURA events
---------------------------------------------------------------------------
local auraIdMap = {}
local auraNameMap = {}
local auraCacheDirty = true
local auraCacheVersion = 0
local auraCacheFrame = CreateFrame("Frame")

-- Rebuild cache when auras change
local function RebuildAuraCache()
    wipe(auraIdMap)
    wipe(auraNameMap)

    local ok = pcall(function()
        for i = 1, 40 do
            local a = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
            if not a then break end
            local id = a.spellId
            if id then
                auraIdMap[id] = { icon = a.icon, expiry = a.expirationTime }
            end
            if a.name then
                auraNameMap[a.name] = { icon = a.icon, expiry = a.expirationTime }
            end
        end
    end)
    auraCacheDirty = false
    auraCacheVersion = auraCacheVersion + 1
    return ok
end

-- Register for aura events to invalidate cache
auraCacheFrame:RegisterUnitEvent("UNIT_AURA", "player")
auraCacheFrame:SetScript("OnEvent", function()
    auraCacheDirty = true
end)

function ns.DisplayUtils.ScanAuras()
    -- Only rebuild if cache is dirty
    if auraCacheDirty then
        if not RebuildAuraCache() then
            return nil, nil
        end
    end
    return auraIdMap, auraNameMap
end

-- Force cache invalidation (for external use if needed)
function ns.DisplayUtils.InvalidateAuraCache()
    auraCacheDirty = true
end

---------------------------------------------------------------------------
-- Aura lookup helpers
---------------------------------------------------------------------------
local strfind, strlower = string.find, string.lower

-- Cache for lowercase aura names to avoid repeated strlower calls
local lowerNameCache = {}
local lowerNameCacheVersion = 0

function ns.DisplayUtils.FindAuraByName(nameMap, partial)
    if not nameMap then return nil, nil end

    -- Invalidate lowercase cache if aura cache was rebuilt
    if lowerNameCacheVersion ~= auraCacheVersion then
        wipe(lowerNameCache)
        lowerNameCacheVersion = auraCacheVersion
    end

    local lp = strlower(partial)
    for fullName, data in pairs(nameMap) do
        -- Cache the lowercase version
        local lowerName = lowerNameCache[fullName]
        if not lowerName then
            lowerName = strlower(fullName)
            lowerNameCache[fullName] = lowerName
        end
        if strfind(lowerName, lp, 1, true) then
            return data, fullName
        end
    end
    return nil, nil
end

function ns.DisplayUtils.IsExpiring(aura, threshold, now)
    if not aura then return true end
    if aura.expiry == 0 then return false end  -- Permanent buff
    return (aura.expiry - (now or GetTime())) < threshold
end

function ns.DisplayUtils.CanReadAuras()
    local aura = C_UnitAuras.GetAuraDataByIndex("player", 1, "HELPFUL")
    if not aura then return true end
    local ok = pcall(function() local _ = aura.spellId end)
    return ok
end

---------------------------------------------------------------------------
-- Shared frame backdrop
---------------------------------------------------------------------------
ns.DisplayUtils.FRAME_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

---------------------------------------------------------------------------
-- Slot frame creation
---------------------------------------------------------------------------
function ns.DisplayUtils.MakeSlot(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(40, 40)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints()
    f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.timer = f:CreateFontString(nil, "OVERLAY")
    f.timer:SetPoint("BOTTOM", 0, -14)
    f.timer:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", 11, "OUTLINE")
    f.lbl = f:CreateFontString(nil, "OVERLAY")
    f.lbl:SetPoint("TOP", 0, 12)
    f.lbl:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", 9, "OUTLINE")
    f.lbl:SetTextColor(0.7, 0.7, 0.7)
    return f
end

function ns.DisplayUtils.SetSlot(slot, label, data, fallbackIcon)
    slot.lbl:SetText(label)
    if not data then
        slot.tex:SetTexture(fallbackIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
        slot.tex:SetDesaturated(fallbackIcon ~= nil)
        slot.timer:SetText("NONE")
        slot.timer:SetTextColor(1, 0.3, 0.3)
    elseif data.expiry == 0 then
        slot.tex:SetTexture(data.icon)
        slot.tex:SetDesaturated(false)
        slot.timer:SetText("")
        slot.timer:SetTextColor(1, 1, 1)
    else
        slot.tex:SetTexture(data.icon)
        slot.tex:SetDesaturated(false)
        local rem = data.expiry - GetTime()
        if rem > 0 then
            slot.timer:SetText(format("%d:%02d", rem / 60, rem % 60))
            slot.timer:SetTextColor(1, 1, 1)
        else
            slot.timer:SetText(L["COMMON_EXPIRED"])
            slot.timer:SetTextColor(1, 0.3, 0.3)
        end
    end
end

---------------------------------------------------------------------------
-- Unlock mode visuals
---------------------------------------------------------------------------
function ns.DisplayUtils.SetFrameUnlocked(frame, unlocked, label)
    if unlocked then
        frame:SetBackdrop(ns.DisplayUtils.FRAME_BACKDROP)
        frame:SetBackdropColor(0, 0, 0, 0.5)
        frame:SetBackdropBorderColor(1, 0.66, 0, 0.8)
        if label and not frame.unlockLabel then
            frame.unlockLabel = frame:CreateFontString(nil, "OVERLAY")
            frame.unlockLabel:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", 10, "OUTLINE")
            frame.unlockLabel:SetPoint("CENTER")
            frame.unlockLabel:SetTextColor(1, 0.66, 0)
        end
        if frame.unlockLabel then
            frame.unlockLabel:SetText(label or L["COMMON_DRAG_TO_MOVE"])
            frame.unlockLabel:Show()
        end
    else
        frame:SetBackdrop(nil)
        if frame.unlockLabel then
            frame.unlockLabel:Hide()
        end
    end
end
