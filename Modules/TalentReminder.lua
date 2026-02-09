local addonName, ns = ...
local L = ns.L

local COLORS = {
    BLUE    = "018ee7",
    ORANGE  = "ffa900",
    SUCCESS = "00ff00",
    ERROR   = "ff0000",
}

local lastCheckedBoss = nil
local lastCheckedZone = nil

local function ChatMsg(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cff" .. COLORS.BLUE .. "Naowh QOL:|r " .. text)
end

local function GetSpecID()
    return PlayerUtil and PlayerUtil.GetCurrentSpecID() or 0
end

local function GetSpecName()
    local specIndex = GetSpecialization()
    if specIndex then
        local _, name = GetSpecializationInfo(specIndex)
        return name or "Unknown"
    end
    return "Unknown"
end

local function GetCurrentTalentInfo()
    local specID = GetSpecID()
    local activeConfigID = C_ClassTalents.GetActiveConfigID()
    if not activeConfigID then return nil, nil, nil end

    -- Get the saved loadout ID (this has the user-defined name)
    local savedConfigID = C_ClassTalents.GetLastSelectedSavedConfigID(specID)
    local configName = "Unsaved Build"

    if savedConfigID then
        local configInfo = C_Traits.GetConfigInfo(savedConfigID)
        if configInfo and configInfo.name then
            configName = configInfo.name
        end
    end

    local exportString = C_Traits.GenerateImportString(activeConfigID)
    return savedConfigID or activeConfigID, exportString, configName
end

local function GetConfigName(configID)
    local info = C_Traits.GetConfigInfo(configID)
    return info and info.name or "Unknown"
end

local function BuildDungeonKey(specID, instanceID, difficulty)
    return specID .. ":" .. instanceID .. ":" .. difficulty
end

local function BuildBossKey(specID, bossID, difficulty)
    return specID .. ":" .. bossID .. ":" .. difficulty
end

local function IsTargetRaidBoss()
    if not UnitExists("target") then return nil, nil end

    -- Check if it's a boss-level mob (skull level, boss frame)
    local isBoss = UnitLevel("target") == -1 or
                   UnitClassification("target") == "worldboss" or
                   UnitClassification("target") == "raidboss"

    if not isBoss then return nil, nil end

    local guid = UnitGUID("target")
    if not guid then return nil, nil end

    local unitType, _, _, _, _, npcID = strsplit("-", guid)
    if unitType == "Creature" then
        return tonumber(npcID), UnitName("target")
    end

    return nil, nil
end

local function SwapToSaved(saved)
    if InCombatLockdown() then
        ChatMsg("|cff" .. COLORS.ERROR .. L["TALENT_COMBAT_ERROR"] .. "|r")
        return false
    end

    local specID = GetSpecID()
    local configs = C_ClassTalents.GetConfigIDsBySpecID(specID) or {}
    for index, id in ipairs(configs) do
        if id == saved.configID then
            if ClassTalentHelper and ClassTalentHelper.SwitchToLoadoutByIndex then
                ClassTalentHelper.SwitchToLoadoutByIndex(index)
                ChatMsg(string.format(
                    L["TALENT_SWAPPED"],
                    "|cff" .. COLORS.ORANGE .. (saved.configName or "saved build") .. "|r"
                ))
                return true
            end
        end
    end
    ChatMsg("|cff" .. COLORS.ERROR .. L["TALENT_NOT_FOUND"] .. "|r")
    return false
end

-- Save Prompt Dialog
StaticPopupDialogs["NAOWHQOL_TALENT_SAVE"] = {
    text = "%s",
    button1 = L["TALENT_SAVE_BTN"],
    button2 = L["COMBATLOGGER_SKIP_BTN"],
    OnAccept = function(self)
        local data = self.data
        if not data then return end

        local db = NaowhQOL.talentReminder
        if not db then return end
        db.loadouts = db.loadouts or {}

        local configID, exportString, configName = GetCurrentTalentInfo()
        db.loadouts[data.key] = {
            configID = configID,
            exportString = exportString,
            configName = configName,
            name = data.name,
            diffName = data.diffName,
        }

        ChatMsg(string.format(
            L["TALENT_SAVED"],
            "|cff" .. COLORS.ORANGE .. data.name .. "|r"
        ))
    end,
    timeout = 0,
    whileDead = false,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Mismatch Prompt Dialog
StaticPopupDialogs["NAOWHQOL_TALENT_MISMATCH"] = {
    text = "%s",
    button1 = L["TALENT_SWAP_BTN"],
    button2 = L["TALENT_OVERWRITE_BTN"],
    button3 = L["TALENT_IGNORE_BTN"],
    OnAccept = function(self)
        local data = self.data
        if not data or not data.saved then return end
        SwapToSaved(data.saved)
    end,
    OnCancel = function(self)
        local data = self.data
        if not data then return end

        local db = NaowhQOL.talentReminder
        if not db then return end
        db.loadouts = db.loadouts or {}

        local configID, exportString, configName = GetCurrentTalentInfo()
        db.loadouts[data.key] = {
            configID = configID,
            exportString = exportString,
            configName = configName,
            name = data.name,
            diffName = data.diffName,
        }

        ChatMsg(string.format(
            L["TALENT_OVERWRITTEN"],
            "|cff" .. COLORS.ORANGE .. data.name .. "|r"
        ))
    end,
    OnAlt = function() end,
    timeout = 0,
    whileDead = false,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function CheckTalents(key, displayName, diffName)
    if InCombatLockdown() then return end

    local db = NaowhQOL.talentReminder
    if not db or not db.enabled then return end
    db.loadouts = db.loadouts or {}

    local saved = db.loadouts[key]
    local configID, exportString, configName = GetCurrentTalentInfo()

    if not saved then
        -- First visit, prompt to save
        local promptText = "|cff" .. COLORS.BLUE .. "Naowh QOL|r\n\n"
            .. string.format(
                L["TALENT_SAVE_POPUP"],
                "|cff" .. COLORS.ORANGE .. displayName .. "|r",
                diffName and ("(" .. diffName .. ")") or "",
                "(" .. GetSpecName() .. ")",
                "|cff" .. COLORS.SUCCESS .. configName .. "|r"
            )

        local dialog = StaticPopup_Show("NAOWHQOL_TALENT_SAVE", promptText)
        if dialog then
            dialog.data = {
                key = key,
                name = displayName,
                diffName = diffName,
            }
        end
    elseif saved.configID ~= configID then
        -- Mismatch detected
        local savedName = saved.configName or "Saved Build"
        local promptText = "|cff" .. COLORS.BLUE .. "Naowh QOL|r\n\n"
            .. string.format(
                L["TALENT_MISMATCH_POPUP"],
                "|cff" .. COLORS.ORANGE .. displayName .. "|r",
                "|cff" .. COLORS.ERROR .. configName .. "|r",
                "|cff" .. COLORS.SUCCESS .. savedName .. "|r"
            )

        local dialog = StaticPopup_Show("NAOWHQOL_TALENT_MISMATCH", promptText)
        if dialog then
            dialog.data = {
                key = key,
                name = displayName,
                diffName = diffName,
                saved = saved,
            }
        end
    end
end

local function OnZoneChanged(zoneData)
    if InCombatLockdown() then return end

    local db = NaowhQOL.talentReminder
    if not db or not db.enabled then return end

    -- Only track mythic dungeons (difficulty 23), not M+ (8) since talents lock once key starts
    if zoneData.instanceType ~= "party" or zoneData.difficulty ~= 23 then
        lastCheckedZone = nil
        return
    end

    local specID = GetSpecID()
    if specID == 0 then return end

    local key = BuildDungeonKey(specID, zoneData.instanceID, zoneData.difficulty)

    -- Avoid repeated prompts for same zone
    if lastCheckedZone == key then return end
    lastCheckedZone = key

    C_Timer.After(1, function()
        if InCombatLockdown() then return end
        CheckTalents(key, zoneData.zoneName, zoneData.difficultyName)
    end)
end

local function OnTargetChanged()
    if InCombatLockdown() then return end

    local db = NaowhQOL.talentReminder
    if not db or not db.enabled then return end

    -- Only in raids
    local zoneData = ns.ZoneUtil and ns.ZoneUtil.GetCurrentZone()
    if not zoneData or zoneData.instanceType ~= "raid" then return end

    local bossID, bossName = IsTargetRaidBoss()
    if not bossID then return end

    local specID = GetSpecID()
    if specID == 0 then return end

    local difficulty = zoneData.difficulty
    local diffName = zoneData.difficultyName

    local key = BuildBossKey(specID, bossID, difficulty)

    -- Avoid repeated prompts for same boss at same difficulty
    if lastCheckedBoss == key then return end
    lastCheckedBoss = key

    C_Timer.After(0.5, function()
        if InCombatLockdown() then return end
        CheckTalents(key, bossName, diffName)
    end)
end

local loader = CreateFrame("Frame", "NaowhQOL_TalentReminder")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_TARGET_CHANGED")
loader:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
loader:RegisterEvent("TRAIT_CONFIG_UPDATED")

loader:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        if not NaowhQOL.talentReminder then
            NaowhQOL.talentReminder = { enabled = true, loadouts = {} }
        end
        local db = NaowhQOL.talentReminder
        if db.enabled == nil then db.enabled = true end
        db.loadouts = db.loadouts or {}

        if ns.ZoneUtil and ns.ZoneUtil.RegisterCallback then
            ns.ZoneUtil.RegisterCallback("TalentReminder", OnZoneChanged)
            C_Timer.After(1, function()
                if not InCombatLockdown() then
                    OnZoneChanged(ns.ZoneUtil.GetCurrentZone())
                end
            end)
        end

        self:UnregisterEvent("PLAYER_LOGIN")

    elseif event == "PLAYER_TARGET_CHANGED" then
        OnTargetChanged()

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        -- Reset checks when spec changes
        lastCheckedBoss = nil
        lastCheckedZone = nil

    elseif event == "TRAIT_CONFIG_UPDATED" then
        -- Re-check when talents change
        lastCheckedBoss = nil
        lastCheckedZone = nil
        C_Timer.After(0.5, function()
            if InCombatLockdown() then return end
            -- Re-trigger zone check if in dungeon
            if ns.ZoneUtil then
                OnZoneChanged(ns.ZoneUtil.GetCurrentZone())
            end
            -- Re-trigger boss check if targeting one
            OnTargetChanged()
        end)
    end
end)

ns.TalentReminder = loader
