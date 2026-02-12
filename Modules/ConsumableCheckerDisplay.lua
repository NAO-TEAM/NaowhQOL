local addonName, ns = ...
local L = ns.L

-- Use shared utilities from DisplayUtils
local DU = ns.DisplayUtils
local GetCachedTexture = DU.GetCachedTexture
local ScanAuras = DU.ScanAuras
local FindAuraByName = DU.FindAuraByName

-- Module-level ticker reference for proper cleanup
local consumableTicker

---------------------------------------------------------------------------
-- Difficulty filters for instance-based visibility
---------------------------------------------------------------------------
local DIFFICULTY_FILTERS = {
    { inst = "party", diff = 1,  key = "normalDungeon" },
    { inst = "party", diff = 2,  key = "heroicDungeon" },
    { inst = "party", diff = 23, key = "mythicDungeon" },
    { inst = "raid",  diff = 17, key = "lfr" },
    { inst = "raid",  diff = 14, key = "normalRaid" },
    { inst = "raid",  diff = 15, key = "heroicRaid" },
    { inst = "raid",  diff = 16, key = "mythicRaid" },
}

-- Get expiry threshold based on zone type and category settings
local function GetExpiryThreshold(cat)
    local zone = ns.ZoneUtil and ns.ZoneUtil.GetCurrentZone()
    if not zone then return cat.thresholdOpen or 300 end

    if zone.instanceType == "party" then
        return cat.thresholdDungeon or 600
    elseif zone.instanceType == "raid" then
        return cat.thresholdRaid or 600
    else
        return cat.thresholdOpen or 300
    end
end

local inCombat = false
local pendingHide = false  -- Deferred hide when combat blocked the action

---------------------------------------------------------------------------
-- Bag scanning for consumable items
---------------------------------------------------------------------------
local function ScanBagsForCategory(customItems, manualItemId)
    -- Manual override takes priority
    if manualItemId and manualItemId > 0 then
        local count = GetItemCount(manualItemId, false, true)
        if count > 0 then
            local name = C_Item.GetItemInfo(manualItemId)
            local itemInfo = GetItemInfoInstant(manualItemId)
            local tex = itemInfo and select(5, GetItemInfoInstant(manualItemId)) or nil
            -- Return even if name is nil (item may not be cached yet)
            return manualItemId, name or "", tex, count
        end
        return manualItemId, nil, nil, 0
    end
    -- Check items from category's customItems list
    if customItems then
        for _, itemId in ipairs(customItems) do
            local count = GetItemCount(itemId, false, true)
            if count > 0 then
                local name = C_Item.GetItemInfo(itemId)
                local itemInfo = GetItemInfoInstant(itemId)
                local tex = itemInfo and select(5, GetItemInfoInstant(itemId)) or nil
                return itemId, name or "", tex, count
            end
        end
    end
    return nil, nil, nil, 0
end

---------------------------------------------------------------------------
-- Zone / difficulty check
---------------------------------------------------------------------------
local function ShouldShow(db)
    if ns.notificationsSuppressed then return false end
    if not db.enabled then return false end
    local zone = ns.ZoneUtil and ns.ZoneUtil.GetCurrentZone()
    if not zone or zone.instanceType == "none" then
        -- "Other" catch-all for non-instance locations
        return db.other == true
    end
    for _, f in ipairs(DIFFICULTY_FILTERS) do
        if zone.instanceType == f.inst and zone.difficulty == f.diff then
            return db[f.key] ~= false
        end
    end
    -- "Other" catch-all for unmatched instance types/difficulties
    return db.other == true
end

---------------------------------------------------------------------------
-- Icon strip frame
---------------------------------------------------------------------------
local ccIcons = CreateFrame("Frame", "NaowhQOL_ConsumableCheckerIcons", UIParent, "BackdropTemplate")
ccIcons:SetSize(90, 56); ccIcons:SetPoint("CENTER", 0, 150)
ccIcons:SetMovable(true); ccIcons:EnableMouse(true)
ccIcons:RegisterForDrag("LeftButton"); ccIcons:SetClampedToScreen(true); ccIcons:Hide()

local slots = {}
local slotIndex = 0

local function MakeSlot(parent)
    slotIndex = slotIndex + 1
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(40, 40)

    -- Secure click overlay for using consumable items
    local click = CreateFrame("Button",
        "NaowhQOL_CCSlotBtn" .. slotIndex,
        f,
        "SecureActionButtonTemplate")
    click:SetAllPoints()
    pcall(function()
        click:SetAttribute("type", "macro")
        click:SetAttribute("macrotext1", "")
    end)
    click:RegisterForClicks("AnyUp", "AnyDown")
    f.click = click

    -- Black border (2px)
    f.border = f:CreateTexture(nil, "BACKGROUND")
    f.border:SetAllPoints()
    f.border:SetColorTexture(0, 0, 0, 1)

    -- Icon texture (inset by 2px for border)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetPoint("TOPLEFT", 2, -2)
    f.tex:SetPoint("BOTTOMRIGHT", -2, 2)
    f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    f.timer = f:CreateFontString(nil, "OVERLAY")
    f.timer:SetPoint("BOTTOM", 0, -14)
    f.timer:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", 11, "OUTLINE")

    f.lbl = f:CreateFontString(nil, "OVERLAY")
    f.lbl:SetPoint("TOP", 0, 12)
    f.lbl:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", 9, "OUTLINE")
    f.lbl:SetTextColor(0.7, 0.7, 0.7)

    f.count = f:CreateFontString(nil, "OVERLAY")
    f.count:SetPoint("BOTTOMRIGHT", -2, 2)
    f.count:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", 11, "OUTLINE")
    f.count:SetTextColor(1, 1, 1)

    return f
end

local function EnsureSlots(n)
    while #slots < n do slots[#slots + 1] = MakeSlot(ccIcons) end
end

---------------------------------------------------------------------------
-- Combat state: each secure button hides itself in combat
---------------------------------------------------------------------------
local function RegisterSlotCombatDriver(slot)
    -- SecureActionButton inherits SecureHandlerBase, so state drivers work
    pcall(function()
        RegisterStateDriver(slot.click, "combat", "[combat] hide; [nocombat] show")
    end)
end

---------------------------------------------------------------------------
-- Positioning and dragging
---------------------------------------------------------------------------
local dragging = false

local function PositionSlots(db, count)
    local sz = db.iconSize or 40
    if not dragging then
        ccIcons:ClearAllPoints()
        ccIcons:SetPoint(db.iconPoint or "CENTER", UIParent,
            db.iconPoint or "CENTER", db.iconX or 0, db.iconY or 150)
    end
    for i = 1, count do
        slots[i]:SetSize(sz, sz); slots[i]:ClearAllPoints()
        slots[i]:SetPoint("TOPLEFT", (i - 1) * (sz + 10), 0); slots[i]:Show()
    end
    for i = count + 1, #slots do slots[i]:Hide() end
    ccIcons:SetSize(math.max(1, count * sz + (count - 1) * 10), sz + 16)
end

ccIcons:SetScript("OnDragStart", function(self)
    local db = NaowhQOL.consumableChecker
    if db and db.enabled and db.unlock then
        dragging = true; self:StartMoving()
    end
end)
ccIcons:SetScript("OnDragStop", function(self)
    dragging = false; self:StopMovingOrSizing()
    local db = NaowhQOL.consumableChecker
    if db then
        local p, _, _, x, y = self:GetPoint()
        if p and x and y then
            db.iconPoint, db.iconX, db.iconY = p, math.floor(x), math.floor(y)
        end
    end
end)

---------------------------------------------------------------------------
-- Unlock backdrop
---------------------------------------------------------------------------
local FRAME_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local function SetFrameUnlocked(frame, unlocked)
    if InCombatLockdown() then return end  -- Can't modify secure frames in combat
    if unlocked then
        frame:SetBackdrop(FRAME_BACKDROP)
        frame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        if not frame:IsShown() then
            frame:SetSize(120, 40)
            frame:Show()
        end
        if not frame.unlockLabel then
            frame.unlockLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            frame.unlockLabel:SetPoint("CENTER")
        end
        frame.unlockLabel:SetText(L["COMMON_DRAG_TO_MOVE"])
        frame.unlockLabel:Show()
    else
        frame:StopMovingOrSizing()
        frame:SetBackdrop(nil)
        if frame.unlockLabel then frame.unlockLabel:Hide() end
    end
end

function ns:SetConsumableCheckerUnlock(unlocked)
    local db = NaowhQOL.consumableChecker
    if not db or not db.enabled then unlocked = false end
    SetFrameUnlocked(ccIcons, unlocked)
    if not unlocked then dragging = false; ns:RefreshConsumableChecker() end
end

---------------------------------------------------------------------------
-- Safe hide (respects unlock mode)
---------------------------------------------------------------------------
local function SafeHide(frame, unlockKey)
    local db = NaowhQOL.consumableChecker
    local shouldHide = not db or not db.enabled or not db[unlockKey]
    if not shouldHide then return end
    if InCombatLockdown() then
        pendingHide = true  -- Defer until combat ends
        return
    end
    frame:Hide()
end

---------------------------------------------------------------------------
-- Core consumable check
---------------------------------------------------------------------------
local function CheckConsumables()
    local db = NaowhQOL.consumableChecker
    if not db or not ShouldShow(db) then
        SafeHide(ccIcons, "unlock"); return
    end
    if inCombat or (ns.ZoneUtil and ns.ZoneUtil.IsInMythicPlus()) then
        SafeHide(ccIcons, "unlock"); return
    end

    local auraById, auraByName = ScanAuras()
    if not auraById then SafeHide(ccIcons, "unlock"); return end
    auraByName = auraByName or {}

    local missing = {}
    local now = GetTime()

    for _, cat in ipairs(db.categories or {}) do
        local hasEntries = cat.entries and #cat.entries > 0
        local isWeaponEnchant = cat.matchType == "weaponEnchant" and cat.weaponSlot
        if cat.enabled and (hasEntries or isWeaponEnchant) then
            local found, expiring = false, false
            local auraData = nil
            local expiryThreshold = GetExpiryThreshold(cat)

            if cat.matchType == "spellId" then
                for _, id in ipairs(cat.entries) do
                    if auraById[id] then
                        found = true
                        auraData = auraById[id]
                        if auraData.expiry ~= 0
                           and (auraData.expiry - now) < expiryThreshold then
                            expiring = true
                        end
                        break
                    end
                end
            elseif cat.matchType == "name" then
                for _, buffName in ipairs(cat.entries) do
                    local data = FindAuraByName(auraByName, buffName)
                    if data then
                        found = true
                        auraData = data
                        if data.expiry ~= 0
                           and (data.expiry - now) < expiryThreshold then
                            expiring = true
                        end
                        break
                    end
                end
            elseif cat.matchType == "weaponEnchant" then
                -- Each category checks ONE weapon slot (like MRT)
                local hasMain, mainExp, _, _, hasOff, offExp = GetWeaponEnchantInfo()
                local wSlot = cat.weaponSlot or 16

                if wSlot == 17 then
                    -- Off-hand: only relevant if off-hand is a weapon
                    local ohItemId = GetInventoryItemID("player", 17)
                    if ohItemId then
                        local _, _, _, _, _, classId = GetItemInfoInstant(ohItemId)
                        if classId ~= 2 then
                            found = true  -- not a weapon, skip entirely
                        end
                    else
                        found = true  -- nothing equipped, skip
                    end

                    if not found then
                        if hasOff then
                            found = true
                            local rem = offExp / 1000
                            if rem > 0 and rem < expiryThreshold then
                                expiring = true
                            end
                            auraData = { expiry = now + rem }
                        end
                    end
                else
                    -- Main hand (slot 16)
                    if hasMain then
                        found = true
                        local rem = mainExp / 1000
                        if rem > 0 and rem < expiryThreshold then
                            expiring = true
                        end
                        auraData = { expiry = now + rem }
                    end
                end
            end

            -- All categories use the same missing check
            if not found or expiring then
                local itemId, itemName, itemTex, itemCount =
                    ScanBagsForCategory(cat.customItems, cat.itemId)

                missing[#missing + 1] = {
                    label      = cat.name,
                    icon       = cat.icon,
                    aura       = auraData,
                    expiring   = expiring,
                    itemId     = itemId,
                    itemName   = itemName,
                    itemTex    = itemTex,
                    itemCount  = itemCount,
                    targetSlot = cat.weaponSlot,  -- nil for non-enchant
                }
            end
        end
    end

    if #missing > 0 then
        EnsureSlots(#missing)
        PositionSlots(db, #missing)

        for i, m in ipairs(missing) do
            local slot = slots[i]
            slot.lbl:SetText(m.label)

            -- Apply font settings
            local labelSize = db.labelFontSize or 9
            local timerSize = db.timerFontSize or 11
            local stackSize = db.stackFontSize or 11
            local labelAlpha = db.labelAlpha or 1.0
            local timerAlpha = db.timerAlpha or 1.0
            slot.lbl:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", labelSize, "OUTLINE")
            slot.lbl:SetTextColor(db.labelColorR or 0.7, db.labelColorG or 0.7, db.labelColorB or 0.7, labelAlpha)
            slot.timer:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", timerSize, "OUTLINE")
            slot.count:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", stackSize, "OUTLINE")
            slot.count:SetTextColor(db.stackColorR or 1, db.stackColorG or 1, db.stackColorB or 1, db.stackAlpha or 1)

            -- Prefer the item texture (what clicking will use) over generic icons
            local displayTex = m.itemTex
                or m.icon
                or "Interface\\Icons\\INV_Misc_QuestionMark"

            if m.expiring and m.aura then
                slot.tex:SetTexture(displayTex)
                slot.tex:SetDesaturated(false)
                local rem = m.aura.expiry - now
                if rem > 0 then
                    slot.timer:SetText(format("%d:%02d", rem / 60, rem % 60))
                    slot.timer:SetTextColor(1, 0.6, 0, timerAlpha)
                else
                    slot.timer:SetText(L["COMMON_EXPIRED"])
                    slot.timer:SetTextColor(1, 0.3, 0.3, timerAlpha)
                end
            else
                slot.tex:SetTexture(displayTex)
                slot.tex:SetDesaturated(not m.itemTex)
                slot.timer:SetText(L["COMMON_MISSING"])
                slot.timer:SetTextColor(1, 0.3, 0.3, timerAlpha)
            end

            -- Update secure button attributes only outside combat
            if not inCombat and slot.click then
                pcall(function()
                    if m.itemName and m.itemCount > 0 then
                        if m.targetSlot then
                            -- Weapon enchant: item targets a weapon slot (like MRT)
                            -- Set target-slot BEFORE type, and clear conflicting attrs first
                            slot.click:SetAttribute("macrotext1", nil)
                            slot.click:SetAttribute("target-slot", tostring(m.targetSlot))
                            slot.click:SetAttribute("item", m.itemName)
                            slot.click:SetAttribute("type", "item")
                        else
                            -- Regular consumable: macro-based self-use
                            slot.click:SetAttribute("item", nil)
                            slot.click:SetAttribute("target-slot", nil)
                            slot.click:SetAttribute("macrotext1",
                                format("/stopmacro [combat]\n/use %s", m.itemName))
                            slot.click:SetAttribute("type", "macro")
                        end
                        slot.count:SetText(tostring(m.itemCount))
                        slot.count:Show()
                    else
                        slot.click:SetAttribute("item", nil)
                        slot.click:SetAttribute("target-slot", nil)
                        slot.click:SetAttribute("macrotext1", "")
                        slot.click:SetAttribute("type", "macro")
                        slot.count:SetText("")
                        slot.count:Hide()
                    end
                end)
            end

            -- Register combat state driver if not already done
            if not slot.registered then
                RegisterSlotCombatDriver(slot)
                slot.registered = true
            end
        end

        -- Hide extra slots
        for i = #missing + 1, #slots do
            slots[i]:Hide()
        end

        if not InCombatLockdown() then ccIcons:Show() end
    else
        SafeHide(ccIcons, "unlock")
    end
end

---------------------------------------------------------------------------
-- Public refresh
---------------------------------------------------------------------------
function ns:RefreshConsumableChecker()
    CheckConsumables()
end

---------------------------------------------------------------------------
-- Event handling
---------------------------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_REGEN_DISABLED")
loader:RegisterEvent("PLAYER_REGEN_ENABLED")

local auraDirty = false
local function FlushAura()
    if auraDirty then auraDirty = false; pcall(CheckConsumables) end
end

local bagDirty = false
local function FlushBag()
    if bagDirty then bagDirty = false; pcall(CheckConsumables) end
end

loader:SetScript("OnEvent", function(self, ev, a1)
    if ev == "ADDON_LOADED" and a1 == addonName then
        self:UnregisterEvent("ADDON_LOADED")
    elseif ev == "PLAYER_LOGIN" then
        -- Restore unlock visual if it was left on
        local db = NaowhQOL.consumableChecker
        if db and db.unlock then
            SetFrameUnlocked(ccIcons, true)
        end

        -- Periodic check every second (store reference for potential cancellation)
        if consumableTicker then consumableTicker:Cancel() end
        consumableTicker = C_Timer.NewTicker(1, function()
            local d = NaowhQOL.consumableChecker
            if d and d.enabled then pcall(CheckConsumables) end
        end)
        C_Timer.After(1, function() pcall(CheckConsumables) end)

        -- Register aura, bag, and equipment events
        self:RegisterEvent("UNIT_AURA")
        self:RegisterEvent("BAG_UPDATE")
        self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

        -- Zone change callback
        if ns.ZoneUtil then
            ns.ZoneUtil.RegisterCallback("ConsumableChecker", function()
                C_Timer.After(0.5, function() pcall(CheckConsumables) end)
            end)
        end
    elseif ev == "UNIT_AURA" and a1 == "player" then
        if not auraDirty then
            auraDirty = true
            C_Timer.After(0.15, FlushAura)
        end
    elseif ev == "BAG_UPDATE" then
        if not bagDirty then
            bagDirty = true
            C_Timer.After(0.3, FlushBag)
        end
    elseif ev == "PLAYER_EQUIPMENT_CHANGED" then
        local slot = a1
        if slot == 16 or slot == 17 then
            if not bagDirty then
                bagDirty = true
                C_Timer.After(0.3, FlushBag)
            end
        end
    elseif ev == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        SafeHide(ccIcons, "unlock")
    elseif ev == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        -- Process deferred hide if combat blocked it
        if pendingHide then
            pendingHide = false
            ccIcons:Hide()
        end
        -- Re-apply macro attributes now that combat ended
        C_Timer.After(0.5, function() pcall(CheckConsumables) end)
    end
end)

ns.ConsumableCheckerIcon = ccIcons

---------------------------------------------------------------------------
-- Module cleanup for disable
---------------------------------------------------------------------------
function ns:DisableConsumableChecker()
    if InCombatLockdown() then
        pendingHide = true
    else
        ccIcons:Hide()
    end
    -- Unregister all dynamic events (not ADDON_LOADED/PLAYER_LOGIN which are one-time)
    loader:UnregisterEvent("UNIT_AURA")
    loader:UnregisterEvent("BAG_UPDATE")
    loader:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")
    loader:UnregisterEvent("PLAYER_REGEN_DISABLED")
    loader:UnregisterEvent("PLAYER_REGEN_ENABLED")
    inCombat = false
end

-- Re-enable events when module is turned back on
function ns:EnableConsumableChecker()
    loader:RegisterEvent("UNIT_AURA")
    loader:RegisterEvent("BAG_UPDATE")
    loader:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    loader:RegisterEvent("PLAYER_REGEN_DISABLED")
    loader:RegisterEvent("PLAYER_REGEN_ENABLED")
    pcall(CheckConsumables)
end
