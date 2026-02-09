local addonName, ns = ...

-- Auto-confirms loot roll popups, BoP warnings, and refund-window
-- confirmations for vendoring or mailing items.

local function IsEnabled()
    return NaowhQOL.misc and NaowhQOL.misc.suppressLootWarnings
end

local CONFIRMATIONS = {
    CONFIRM_LOOT_ROLL = {
        confirm = "ConfirmLootRoll",
        popup   = "CONFIRM_LOOT_ROLL",
        forwardArgs = true,
    },
    CONFIRM_DISENCHANT_ROLL = {
        confirm = "ConfirmLootRoll",
        popup   = "CONFIRM_LOOT_ROLL",
        forwardArgs = true,
    },
    LOOT_BIND_CONFIRM = {
        confirm     = "ConfirmLootSlot",
        popup       = "LOOT_BIND",
        forwardArgs = true,
        spreadExtra = true,
    },
    MERCHANT_CONFIRM_TRADE_TIMER_REMOVAL = {
        confirm = "SellCursorItem",
    },
    MAIL_LOCK_SEND_ITEMS = {
        confirm     = "RespondMailLockSendItem",
        forwardArgs = true,
        appendTrue  = true,
    },
}

local function HandleConfirmation(event, arg1, arg2, ...)
    local entry = CONFIRMATIONS[event]
    if not entry then return end

    local fn = _G[entry.confirm]
    if not fn then return end

    if entry.appendTrue then
        fn(arg1, true)
    elseif entry.forwardArgs then
        fn(arg1, arg2)
    else
        fn()
    end

    if entry.popup then
        if entry.spreadExtra then
            StaticPopup_Hide(entry.popup, ...)
        else
            StaticPopup_Hide(entry.popup)
        end
    end
end

local warningFrame = CreateFrame("Frame", "NaowhQOL_LootWarnings")
warningFrame:RegisterEvent("PLAYER_LOGIN")

warningFrame:SetScript("OnEvent", function(self, event, arg1, arg2, ...)
    if event == "PLAYER_LOGIN" then
        if IsEnabled() then
            for evtName in pairs(CONFIRMATIONS) do
                self:RegisterEvent(evtName)
            end
        end
        self:UnregisterEvent("PLAYER_LOGIN")
        return
    end

    HandleConfirmation(event, arg1, arg2, ...)
end)

ns.DisableLootWarnings = warningFrame
