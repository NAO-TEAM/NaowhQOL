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

-- Check if TalentLoadoutsEx addon is loaded and available
local function IsTLXAvailable()
    local success, result = pcall(function()
        return C_AddOns.IsAddOnLoaded("TalentLoadoutsEx")
            and _G.TLX ~= nil
            and _G.TalentLoadoutEx ~= nil
    end)
    return success and result
end

-- Get all TLX loadouts for the current spec
local function GetTLXLoadouts()
    if not IsTLXAvailable() then return nil end

    local success, result = pcall(function()
        local _, englishClass = UnitClass("player")
        local specIndex = GetSpecialization()
        if not englishClass or not specIndex then return nil end

        local tlxData = _G.TalentLoadoutEx
        if not tlxData or not tlxData[englishClass] then return nil end
        local specTable = tlxData[englishClass][specIndex]
        if not specTable then return nil end

        local loadouts = {}
        for _, entry in ipairs(specTable) do
            if entry.text and not entry.isLegacy then
                table.insert(loadouts, entry)
            end
        end
        return #loadouts > 0 and loadouts or nil
    end)

    return success and result or nil
end

-- Find a TLX loadout by name
local function GetTLXLoadoutByName(name)
    local loadouts = GetTLXLoadouts()
    if not loadouts then return nil end
    for _, loadout in ipairs(loadouts) do
        if loadout.name == name then return loadout end
    end
    return nil
end

-- Get the currently active TLX loadout (if any matches current talents)
local function GetCurrentTLXLoadout()
    if not IsTLXAvailable() then return nil, nil end

    local success, result = pcall(function()
        local tlx = _G.TLX
        if not tlx or not tlx.GetLoadedData then return nil end
        local loaded = { tlx.GetLoadedData() }
        if loaded[1] then
            return { name = loaded[1].name, text = loaded[1].text }
        end
        return nil
    end)

    if success and result then
        return result.name, result.text
    end
    return nil, nil
end

-- Swap to a TLX loadout using its slash command
local function SwapToTLXLoadout(loadoutName)
    if InCombatLockdown() then
        ChatMsg("|cff" .. COLORS.ERROR .. L["TALENT_COMBAT_ERROR"] .. "|r")
        return false
    end
    local loadout = GetTLXLoadoutByName(loadoutName)
    if not loadout then
        ChatMsg("|cff" .. COLORS.ERROR .. L["TALENT_NOT_FOUND"] .. "|r")
        return false
    end
    -- Defer execution to break taint chain
    C_Timer.After(0, function()
        if InCombatLockdown() then return end
        local success = pcall(function()
            local slashHandler = SlashCmdList["TalentLoadoutsEx_Load"]
            if slashHandler then
                slashHandler(loadoutName)
            end
        end)
        if not success then
            -- Fallback: try chat input method
            local editBox = ChatFrame1 and ChatFrame1.editBox
            if editBox and ChatEdit_SendText then
                ChatEdit_ActivateChat(editBox)
                editBox:SetText("/tlx " .. loadoutName)
                ChatEdit_SendText(editBox)
            end
        end
    end)
    ChatMsg(string.format(L["TALENT_SWAPPED"], "|cff" .. COLORS.ORANGE .. loadoutName .. "|r"))
    return true
end

local function GetCurrentTalentInfo()
    -- Check TLX first if available
    if IsTLXAvailable() then
        local tlxName, tlxExport = GetCurrentTLXLoadout()
        if tlxName then
            return tlxName, tlxExport, tlxName
        else
            -- TLX active but no matching loadout = unsaved
            local activeConfigID = C_ClassTalents.GetActiveConfigID()
            local exportString = activeConfigID and C_Traits.GenerateImportString(activeConfigID)
            return nil, exportString, "Unsaved Build"
        end
    end

    -- Fallback to Blizzard API
    local specID = GetSpecID()
    local activeConfigID = C_ClassTalents.GetActiveConfigID()
    if not activeConfigID then return nil, nil, nil end

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

    -- Use TLX if this was saved as a TLX loadout
    if saved.tlxMode and saved.tlxName then
        return SwapToTLXLoadout(saved.tlxName)
    end

    -- Fallback to Blizzard API
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

        -- Use TLX storage if available
        if IsTLXAvailable() then
            local tlxName, tlxExport = GetCurrentTLXLoadout()
            if tlxName then
                db.loadouts[data.key] = {
                    tlxMode = true,
                    tlxName = tlxName,
                    exportString = tlxExport,
                    name = data.name,
                    diffName = data.diffName,
                }
                ChatMsg(string.format(
                    L["TALENT_SAVED"],
                    "|cff" .. COLORS.ORANGE .. data.name .. "|r"
                ))
                return
            else
                ChatMsg("|cff" .. COLORS.ERROR .. "No TLX loadout active. Select a loadout first.|r")
                return
            end
        end

        -- Fallback to Blizzard storage
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

        -- Use TLX storage if available
        if IsTLXAvailable() then
            local tlxName, tlxExport = GetCurrentTLXLoadout()
            if tlxName then
                db.loadouts[data.key] = {
                    tlxMode = true,
                    tlxName = tlxName,
                    exportString = tlxExport,
                    name = data.name,
                    diffName = data.diffName,
                }
                ChatMsg(string.format(
                    L["TALENT_OVERWRITTEN"],
                    "|cff" .. COLORS.ORANGE .. data.name .. "|r"
                ))
                return
            else
                ChatMsg("|cff" .. COLORS.ERROR .. "No TLX loadout active. Select a loadout first.|r")
                return
            end
        end

        -- Fallback to Blizzard storage
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

-- TLX Loadout Unavailable Dialog
StaticPopupDialogs["NAOWHQOL_TALENT_TLX_UNAVAILABLE"] = {
    text = "%s",
    button1 = L["TALENT_OVERWRITE_BTN"],
    button2 = L["TALENT_IGNORE_BTN"],
    OnAccept = function(self)
        local data = self.data
        if not data then return end

        local db = NaowhQOL.talentReminder
        if not db then return end
        db.loadouts = db.loadouts or {}

        -- Save current loadout (TLX or Blizzard mode)
        if IsTLXAvailable() then
            local tlxName, tlxExport = GetCurrentTLXLoadout()
            if tlxName then
                db.loadouts[data.key] = {
                    tlxMode = true,
                    tlxName = tlxName,
                    exportString = tlxExport,
                    name = data.name,
                    diffName = data.diffName,
                }
                ChatMsg(string.format(
                    L["TALENT_OVERWRITTEN"],
                    "|cff" .. COLORS.ORANGE .. data.name .. "|r"
                ))
                return
            end
        end

        -- Fallback to Blizzard storage
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
    OnCancel = function() end,
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
        -- First visit - check if TLX is active but no loadout selected
        if IsTLXAvailable() then
            local tlxName = GetCurrentTLXLoadout()
            if not tlxName then
                ChatMsg(string.format("No TLX loadout active for %s. Select a loadout first.",
                    "|cff" .. COLORS.ORANGE .. displayName .. "|r"))
                return
            end
        end

        -- Prompt to save
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
    else
        -- Check for mismatch
        local isMismatch = false
        local savedDisplayName = saved.configName or saved.tlxName or "Saved Build"

        if saved.tlxMode then
            -- TLX mode: check if TLX is available and loadout still exists
            local tlxUnavailableReason = nil

            if not IsTLXAvailable() then
                tlxUnavailableReason = "TalentLoadoutsEx not loaded"
            else
                local tlxLoadout = GetTLXLoadoutByName(saved.tlxName)
                if not tlxLoadout then
                    tlxUnavailableReason = "Loadout '" .. saved.tlxName .. "' not found"
                end
            end

            if tlxUnavailableReason then
                -- Show unavailable dialog with overwrite/ignore options
                local promptText = "|cff" .. COLORS.BLUE .. "Naowh QOL|r\n\n"
                    .. "|cff" .. COLORS.ERROR .. tlxUnavailableReason .. "|r\n\n"
                    .. "Saved TLX loadout for:\n"
                    .. "|cff" .. COLORS.ORANGE .. displayName .. "|r\n\n"
                    .. "Current: |cff" .. COLORS.SUCCESS .. configName .. "|r"

                local dialog = StaticPopup_Show("NAOWHQOL_TALENT_TLX_UNAVAILABLE", promptText)
                if dialog then
                    dialog.data = {
                        key = key,
                        name = displayName,
                        diffName = diffName,
                    }
                end
                return
            end

            local currentTLX = GetCurrentTLXLoadout()
            isMismatch = (currentTLX ~= saved.tlxName)
            savedDisplayName = saved.tlxName
        else
            -- Blizzard mode: compare by configID
            isMismatch = (saved.configID ~= configID)
        end

        if isMismatch then
            local promptText = "|cff" .. COLORS.BLUE .. "Naowh QOL|r\n\n"
                .. string.format(
                    L["TALENT_MISMATCH_POPUP"],
                    "|cff" .. COLORS.ORANGE .. displayName .. "|r",
                    "|cff" .. COLORS.ERROR .. configName .. "|r",
                    "|cff" .. COLORS.SUCCESS .. savedDisplayName .. "|r"
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

-- Public function to trigger a zone check (called when module is enabled)
function loader:TriggerZoneCheck()
    -- Reset last checked to allow re-prompting
    lastCheckedZone = nil
    lastCheckedBoss = nil

    C_Timer.After(0.5, function()
        if InCombatLockdown() then return end
        if ns.ZoneUtil then
            OnZoneChanged(ns.ZoneUtil.GetCurrentZone())
        end
        OnTargetChanged()
    end)
end

ns.TalentReminder = loader
