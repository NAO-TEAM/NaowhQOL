local addonName, ns = ...
local L = ns.L

-- Auto combat logging for raids/M+

local COLORS = {
    BLUE    = "018ee7",
    ORANGE  = "ffa900",
    SUCCESS = "00ff00",
    ERROR   = "ff0000",
}

local isLogging = false

local function ChatMsg(text)
    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff" .. COLORS.BLUE .. "Naowh QOL:|r " .. text
    )
end

StaticPopupDialogs["NAOWHQOL_COMBATLOG_PROMPT"] = {
    text = "%s",
    button1 = L["COMBATLOGGER_ENABLE_BTN"],
    button2 = L["COMBATLOGGER_SKIP_BTN"],
    OnAccept = function(self)
        local data = self.data
        if not data then return end

        local db = NaowhQOL.combatLogger
        if not db then return end
        db.instances = db.instances or {}

        local key = data.instanceID .. ":" .. data.difficulty
        db.instances[key] = {
            enabled  = true,
            name     = data.zoneName or "",
            diffName = data.difficultyName or "",
        }

        LoggingCombat(true)
        isLogging = true
        ChatMsg(string.format(
            "|cff" .. COLORS.SUCCESS .. L["COMBATLOGGER_ENABLED"] .. "|r",
            data.zoneName or "this instance",
            data.difficultyName or ""
        ))
    end,
    OnCancel = function(self)
        local data = self.data
        if not data then return end

        local db = NaowhQOL.combatLogger
        if not db then return end
        db.instances = db.instances or {}

        local key = data.instanceID .. ":" .. data.difficulty
        db.instances[key] = {
            enabled  = false,
            name     = data.zoneName or "",
            diffName = data.difficultyName or "",
        }

        ChatMsg(string.format(
            "|cff" .. COLORS.ERROR .. L["COMBATLOGGER_DISABLED"] .. "|r",
            data.zoneName or "this instance",
            data.difficultyName or ""
        ))
    end,
    timeout = 0,
    whileDead = false,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function OnZoneChanged(zoneData)
    local db = NaowhQOL.combatLogger
    if not db or not db.enabled then
        if isLogging then
            LoggingCombat(false)
            isLogging = false
        end
        return
    end

    local shouldTrack = false
    if zoneData.instanceType == "raid" then
        shouldTrack = true
    elseif zoneData.instanceType == "party" and zoneData.difficulty == 8 then
        shouldTrack = true
    end

    if not shouldTrack then
        if isLogging then
            LoggingCombat(false)
            isLogging = false
            ChatMsg("|cff" .. COLORS.ERROR .. L["COMBATLOGGER_STOPPED"] .. "|r")
        end
        return
    end

    db.instances = db.instances or {}
    local key = zoneData.instanceID .. ":" .. zoneData.difficulty
    local saved = db.instances[key]

    if saved and saved.enabled == true then
        if not isLogging then
            LoggingCombat(true)
            isLogging = true
            ChatMsg(string.format(
                "|cff" .. COLORS.SUCCESS .. L["COMBATLOGGER_ENABLED"] .. "|r",
                zoneData.zoneName,
                zoneData.difficultyName
            ))
        end
    elseif saved and saved.enabled == false then
        if isLogging then
            LoggingCombat(false)
            isLogging = false
        end
    else
        -- First time in this instance+difficulty, ask the user
        local promptText = "|cff" .. COLORS.BLUE .. "Naowh QOL|r\n\n"
            .. string.format(
                L["COMBATLOGGER_POPUP"],
                "|cff" .. COLORS.ORANGE .. zoneData.zoneName .. "|r",
                zoneData.difficultyName
            )

        local dialog = StaticPopup_Show("NAOWHQOL_COMBATLOG_PROMPT", promptText)
        if dialog then
            dialog.data = {
                instanceID     = zoneData.instanceID,
                difficulty     = zoneData.difficulty,
                zoneName       = zoneData.zoneName,
                difficultyName = zoneData.difficultyName,
            }
        end
    end
end

local loader = CreateFrame("Frame", "NaowhQOL_CombatLogger")
loader:RegisterEvent("PLAYER_LOGIN")

loader:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        if not NaowhQOL.combatLogger then
            NaowhQOL.combatLogger = { enabled = true, instances = {} }
        end
        local db = NaowhQOL.combatLogger
        if db.enabled == nil then db.enabled = true end
        db.instances = db.instances or {}

        -- Sync with WoW's logging state (handles /reload)
        isLogging = LoggingCombat()

        if ns.ZoneUtil and ns.ZoneUtil.RegisterCallback then
            ns.ZoneUtil.RegisterCallback("CombatLogger", OnZoneChanged)
            -- ZoneUtil already has cached data from PLAYER_ENTERING_WORLD
            C_Timer.After(0.5, function()
                OnZoneChanged(ns.ZoneUtil.GetCurrentZone())
            end)
        end

        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

ns.CombatLogger = loader
