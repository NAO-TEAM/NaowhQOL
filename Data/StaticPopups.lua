local addonName, ns = ...
if not ns then return end

local L = ns.L
local W = ns.Widgets
local C = ns.COLORS

-- Factory function for reload popups
local function CreateReloadPopup(id, message, warning, opts)
    opts = opts or {}
    StaticPopupDialogs[id] = {
        text = W.Colorize("Naowh QOL", C.BLUE) .. "\n\n"
            .. W.Colorize(message, C.WHITE) .. "\n\n"
            .. W.Colorize(warning or L["POPUP_RELOAD_WARNING"], C.ORANGE),
        button1 = W.Colorize(L["COMMON_RELOAD_UI"], C.SUCCESS),
        button2 = opts.button2 or L["COMMON_LATER"],
        OnAccept = opts.OnAccept or function() ReloadUI() end,
        OnCancel = opts.OnCancel,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

-- Standard reload popups
CreateReloadPopup("NAOWH_QOL_RELOAD",
    L["POPUP_CHANGES_APPLIED"],
    L["POPUP_RELOAD_WARNING"])

CreateReloadPopup("NAOWH_QOL_RELOAD_IMPORT",
    L["POPUP_SETTINGS_IMPORTED"],
    L["POPUP_RELOAD_WARNING"])

CreateReloadPopup("NAOWH_PROFILER_ENABLE",
    L["POPUP_PROFILER_ENABLE"],
    L["POPUP_PROFILER_OVERHEAD"],
    {
        button2 = L["COMMON_CANCEL"],
        OnAccept = function()
            NaowhQOL.profilerPending = true
            ReloadUI()
        end,
        OnCancel = function()
            SetCVar("scriptProfile", "0")
        end,
    })

CreateReloadPopup("NAOWH_PROFILER_DISABLE",
    L["POPUP_PROFILER_DISABLE"],
    L["POPUP_PROFILER_RECOMMEND"])

-- Confirmation popup (not a reload)
StaticPopupDialogs["NAOWH_BUFFTRACKER_RESET"] = {
    text = W.Colorize("Naowh QOL", C.BLUE) .. "\n\n"
        .. L["POPUP_BUFFTRACKER_RESET"],
    button1 = L["COMMON_YES"],
    button2 = L["COMMON_NO"],
    OnAccept = function()
        NaowhQOL.buffTracker = nil
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}
