local addonName, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Equipped slot range (head through main-hand/off-hand/ranged)
---------------------------------------------------------------------------
local FIRST_SLOT = 1
local LAST_SLOT  = 19

-- Warning text color (pink)
local WARN_R, WARN_G, WARN_B = 1.0, 0.41, 0.71

---------------------------------------------------------------------------
-- On-screen warning frame
---------------------------------------------------------------------------
local warnFrame = CreateFrame("Frame", "NaowhQOL_DurabilityWarning", UIParent)
warnFrame:SetSize(400, 40)
warnFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 250)
warnFrame:Hide()

local warnText = warnFrame:CreateFontString(nil, "OVERLAY")
warnText:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", 22, "OUTLINE")
warnText:SetPoint("CENTER")
warnText:SetTextColor(WARN_R, WARN_G, WARN_B)

---------------------------------------------------------------------------
-- Show / hide helpers
---------------------------------------------------------------------------
local function ShowWarning(pct)
    warnText:SetText(string.format(L["DURABILITY_WARNING"], pct))
    warnFrame:SetAlpha(1)
    warnFrame:Show()
end

local function HideWarning()
    warnFrame:Hide()
end

---------------------------------------------------------------------------
-- Scan equipped gear for the lowest durability percentage
---------------------------------------------------------------------------
local function GetLowestDurability()
    local lowest = nil

    for slot = FIRST_SLOT, LAST_SLOT do
        local current, maximum = GetInventoryItemDurability(slot)
        if current and maximum and maximum > 0 then
            local pct = (current / maximum) * 100
            if not lowest or pct < lowest then
                lowest = pct
            end
        end
    end

    return lowest
end

---------------------------------------------------------------------------
-- Periodic out-of-combat ticker (updates or clears the warning)
---------------------------------------------------------------------------
local POLL_INTERVAL = 3
local pollTimer = nil

local function StopPolling()
    if pollTimer then
        pollTimer:Cancel()
        pollTimer = nil
    end
end

local function StartPolling()
    StopPolling()
    pollTimer = C_Timer.NewTicker(POLL_INTERVAL, function()
        local db = NaowhQOL.misc
        if not db or not db.durabilityWarning then
            HideWarning()
            return
        end
        local lowest = GetLowestDurability()
        if not lowest or lowest >= (db.durabilityThreshold or 50) then
            HideWarning()
        else
            ShowWarning(math.floor(lowest))
        end
    end)
end

---------------------------------------------------------------------------
-- Auto-repair at merchant
---------------------------------------------------------------------------
local function HandleMerchantRepair()
    local db = NaowhQOL.misc
    if not db or not db.autoRepair then return end
    if IsShiftKeyDown() then return end
    if not CanMerchantRepair() then return end

    local cost = GetRepairAllCost()
    if not cost or cost <= 0 then return end

    if db.guildRepair and IsInGuild() then
        local hasPermission = CanGuildBankRepair and CanGuildBankRepair()
        if hasPermission then
            RepairAllItems(true)
            -- Cover any remainder personal gold couldn't handle via guild
            C_Timer.After(0.5, function() RepairAllItems(false) end)
            return
        end
    end

    RepairAllItems(false)
end

---------------------------------------------------------------------------
-- Event handler
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")

events:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("MERCHANT_SHOW")
        self:UnregisterEvent("PLAYER_LOGIN")

        -- Initial durability check on login + start polling
        local db = NaowhQOL.misc
        if db and db.durabilityWarning then
            local lowest = GetLowestDurability()
            if lowest and lowest < (db.durabilityThreshold or 50) then
                ShowWarning(math.floor(lowest))
            end
        end
        StartPolling()
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        HideWarning()
        StopPolling()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        local db = NaowhQOL.misc
        if db and db.durabilityWarning then
            local lowest = GetLowestDurability()
            if lowest and lowest < (db.durabilityThreshold or 50) then
                ShowWarning(math.floor(lowest))
            end
        end
        StartPolling()
        return
    end

    if event == "MERCHANT_SHOW" then
        HandleMerchantRepair()
        return
    end
end)

ns.DurabilityDisplay = warnFrame
