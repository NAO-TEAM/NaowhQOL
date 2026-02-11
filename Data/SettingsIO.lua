local addonName, ns = ...
if not ns then return end

-- To add a new module to export/import:
--
--   Simple (NaowhQOL subtable):
--     ns.SettingsIO:RegisterSimple("key", "Display Name")
--
--   Custom getter/setter:
--     ns.SettingsIO:Register("key", "Display Name", getterFn, setterFn)
--
-- The UI, serializer, and base64 layer handle everything else automatically.

ns.SettingsIO = { modules = {} }

-- Type schemas for import validation
-- Only defines expected types; missing fields are OK (will get defaults)
local TYPE_SCHEMAS = {
    combatTimer = {
        enabled = "boolean", unlock = "boolean", font = "string",
        colorR = "number", colorG = "number", colorB = "number",
        point = "string", x = "number", y = "number",
        width = "number", height = "number", hidePrefix = "boolean",
        instanceOnly = "boolean", chatReport = "boolean", stickyTimer = "boolean",
    },
    combatAlert = {
        enabled = "boolean", unlock = "boolean", font = "string",
        enterR = "number", enterG = "number", enterB = "number",
        leaveR = "number", leaveG = "number", leaveB = "number",
        point = "string", x = "number", y = "number",
        width = "number", height = "number",
        enterText = "string", leaveText = "string",
    },
    crosshair = {
        enabled = "boolean", size = "number", thickness = "number",
        gap = "number", colorR = "number", colorG = "number", colorB = "number", useClassColor = "boolean",
        opacity = "number", offsetX = "number", offsetY = "number",
        combatOnly = "boolean", dotEnabled = "boolean", dotSize = "number",
        outlineEnabled = "boolean", outlineWeight = "number",
        outlineR = "number", outlineG = "number", outlineB = "number",
        rotation = "number", showTop = "boolean", showRight = "boolean",
        showBottom = "boolean", showLeft = "boolean",
        hideWhileMounted = "boolean",
        dualColor = "boolean", color2R = "number", color2G = "number", color2B = "number",
        circleEnabled = "boolean", circleSize = "number",
        circleR = "number", circleG = "number", circleB = "number",
        meleeRecolor = "boolean", meleeRecolorBorder = "boolean",
        meleeRecolorArms = "boolean", meleeRecolorDot = "boolean", meleeRecolorCircle = "boolean",
        meleeOutColorR = "number", meleeOutColorG = "number", meleeOutColorB = "number",
        meleeSoundEnabled = "boolean", meleeSoundID = "number", meleeSoundInterval = "number",
    },
    combatLogger = {
        enabled = "boolean", instances = "table",
    },
    mouseRing = "table", -- Mouse ring settings
    dragonriding = {
        enabled = "boolean", barWidth = "number", speedHeight = "number",
        chargeHeight = "number", gap = "number", showSpeedText = "boolean",
        point = "string", posX = "number", posY = "number",
        swapPosition = "boolean", hideWhenGroundedFull = "boolean",
        hideCdmWhileMounted = "boolean", showSecondWind = "boolean",
        showWhirlingSurge = "boolean", colorPreset = "string", unlocked = "boolean",
        barStyle = "string", speedFont = "string", speedFontSize = "number",
        speedColorR = "number", speedColorG = "number", speedColorB = "number",
        thrillColorR = "number", thrillColorG = "number", thrillColorB = "number",
        chargeColorR = "number", chargeColorG = "number", chargeColorB = "number",
        bgColorR = "number", bgColorG = "number", bgColorB = "number", bgAlpha = "number",
        surgeIconSize = "number", surgeAnchor = "string",
        surgeOffsetX = "number", surgeOffsetY = "number",
        anchorFrame = "string", anchorTo = "string", matchAnchorWidth = "boolean",
    },
    misc = {
        autoFillDelete = "boolean", fasterLoot = "boolean",
        suppressLootWarnings = "boolean", hideAlerts = "boolean",
        hideTalkingHead = "boolean", hideEventToasts = "boolean",
        hideZoneText = "boolean", autoRepair = "boolean", guildRepair = "boolean",
        durabilityWarning = "boolean", durabilityThreshold = "number",
        autoSlotKeystone = "boolean", skipQueueConfirm = "boolean",
    },
    buffMonitor = {
        enabled = "boolean", unlock = "boolean", soundID = "number",
        soundEnabled = "boolean", colorR = "number", colorG = "number", colorB = "number",
        iconPoint = "string", iconX = "number", iconY = "number", iconSize = "number",
        trackers = "table", raidBuffsEnabled = "boolean", raidIconSize = "number",
        raidIconPoint = "string", raidIconX = "number", raidIconY = "number",
        unlockRaid = "boolean",
        raidLabelFontSize = "number", raidLabelColorR = "number",
        raidLabelColorG = "number", raidLabelColorB = "number",
        customLabelFontSize = "number", customTimerFontSize = "number",
        customLabelColorR = "number", customLabelColorG = "number", customLabelColorB = "number",
    },
    consumableChecker = {
        enabled = "boolean", unlock = "boolean", iconSize = "number",
        iconPoint = "string", iconX = "number", iconY = "number",
        soundEnabled = "boolean", soundID = "number",
        colorR = "number", colorG = "number", colorB = "number",
        categories = "table",
        labelFontSize = "number", timerFontSize = "number",
        labelColorR = "number", labelColorG = "number", labelColorB = "number",
        normalDungeon = "boolean", heroicDungeon = "boolean",
        mythicDungeon = "boolean", mythicPlus = "boolean",
        lfr = "boolean", normalRaid = "boolean",
        heroicRaid = "boolean", mythicRaid = "boolean",
    },
    gcdTracker = {
        enabled = "boolean", unlock = "boolean", duration = "number",
        iconSize = "number", direction = "string", spacing = "number",
        fadeStart = "number", point = "string", x = "number", y = "number",
        combatOnly = "boolean", blocklist = "table", stackOverlapping = "boolean",
        showInDungeon = "boolean", showInRaid = "boolean", showInArena = "boolean",
        showInBattleground = "boolean", showInWorld = "boolean",
        timelineColorR = "number", timelineColorG = "number", timelineColorB = "number",
        timelineHeight = "number",
    },
    stealthReminder = {
        enabled = "boolean", unlock = "boolean", font = "string",
        stealthR = "number", stealthG = "number", stealthB = "number",
        warningR = "number", warningG = "number", warningB = "number",
        stealthText = "string", warningText = "string",
        point = "string", x = "number", y = "number",
        width = "number", height = "number",
        showStealthed = "boolean", showNotStealthed = "boolean",
        stanceEnabled = "boolean", stanceUnlock = "boolean",
        stanceWarnR = "number", stanceWarnG = "number", stanceWarnB = "number",
        stancePoint = "string", stanceX = "number", stanceY = "number",
        stanceWidth = "number", stanceHeight = "number",
        stanceCombatOnly = "boolean", stanceSoundEnabled = "boolean",
        stanceSoundID = "number", stanceSoundInterval = "number",
        stanceWarnText = "string",
    },
    emoteDetection = {
        enabled = "boolean", unlock = "boolean", point = "string",
        x = "number", y = "number", width = "number", height = "number",
        autoEmoteEnabled = "boolean", autoEmotes = "table", autoEmoteCooldown = "number",
        font = "string", fontSize = "number",
        textR = "number", textG = "number", textB = "number",
        emotePattern = "string", soundOn = "boolean", soundID = "number",
    },
    rangeCheck = {
        enabled = "boolean",
        rangeEnabled = "boolean", rangeUnlock = "boolean",
        rangeFont = "string",
        rangeColorR = "number", rangeColorG = "number", rangeColorB = "number",
        rangePoint = "string", rangeX = "number", rangeY = "number",
        rangeWidth = "number", rangeHeight = "number",
        rangeCombatOnly = "boolean",
    },
    focusCastBar = {
        enabled = "boolean", unlock = "boolean",
        point = "string", x = "number", y = "number",
        width = "number", height = "number",
        barColorR = "number", barColorG = "number", barColorB = "number",
        barColorCdR = "number", barColorCdG = "number", barColorCdB = "number",
        bgColorR = "number", bgColorG = "number", bgColorB = "number",
        bgAlpha = "number",
        showIcon = "boolean", iconSize = "number", iconPosition = "string",
        showSpellName = "boolean", showTimeRemaining = "boolean",
        font = "string", fontSize = "number",
        textColorR = "number", textColorG = "number", textColorB = "number",
        hideFriendlyCasts = "boolean", showEmpowerStages = "boolean",
        showShieldIcon = "boolean", colorNonInterrupt = "boolean",
        nonIntColorR = "number", nonIntColorG = "number", nonIntColorB = "number",
        soundEnabled = "boolean", soundID = "number",
        ttsEnabled = "boolean", ttsMessage = "string", ttsVolume = "number",
    },
    slashCommands = {
        enabled = "boolean",
        commands = "table",
    },
    cRez = {
        enabled = "boolean", unlock = "boolean",
        point = "string", x = "number", y = "number", iconSize = "number",
        timerFontSize = "number", timerColorR = "number", timerColorG = "number", timerColorB = "number", timerAlpha = "number",
        countFontSize = "number", countColorR = "number", countColorG = "number", countColorB = "number", countAlpha = "number",
        deathWarning = "boolean",
    },
    petTracker = {
        enabled = "boolean", unlock = "boolean",
        showIcon = "boolean", onlyInInstance = "boolean",
        point = "string", x = "number", y = "number",
        width = "number", height = "number",
        textSize = "number", iconSize = "number",
        missingText = "string", passiveText = "string", wrongPetText = "string",
        colorR = "number", colorG = "number", colorB = "number",
    },
}

-- Validate imported data against schema
local function ValidateImportData(key, data)
    if type(data) ~= "table" then
        return false, "expected table"
    end

    local schema = TYPE_SCHEMAS[key]
    if not schema then
        return true -- No schema defined, allow import
    end

    -- Simple table schema (just validate it's a table)
    if schema == "table" then
        return true
    end

    -- Detailed field validation
    for field, expectedType in pairs(schema) do
        local value = data[field]
        if value ~= nil then
            local actualType = type(value)
            if actualType ~= expectedType then
                return false, field .. " should be " .. expectedType .. ", got " .. actualType
            end
        end
    end

    return true
end

function ns.SettingsIO:Register(key, label, getter, setter)
    self.modules[#self.modules + 1] = { key = key, label = label, get = getter, set = setter }
end

function ns.SettingsIO:RegisterSimple(key, label)
    self:Register(key, label,
        function() return NaowhQOL[key] end,
        function(d) NaowhQOL[key] = d end)
end

local function SerializeValue(v)
    local t = type(v)
    if t == "string" then
        return string.format("%q", v)
    elseif t == "number" then
        return tostring(v)
    elseif t == "boolean" then
        return v and "true" or "false"
    elseif t == "table" then
        local parts = {}
        local n = #v
        for i = 1, n do
            parts[#parts + 1] = SerializeValue(v[i])
        end
        for k, val in pairs(v) do
            if type(k) == "number" and k >= 1 and k <= n and k == math.floor(k) then
                -- already handled in array part
            else
                local kStr
                if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                    kStr = k
                else
                    kStr = "[" .. SerializeValue(k) .. "]"
                end
                parts[#parts + 1] = kStr .. "=" .. SerializeValue(val)
            end
        end
        return "{" .. table.concat(parts, ",") .. "}"
    else
        return "nil"
    end
end

local function Serialize(tbl)
    return SerializeValue(tbl)
end

-- recursive parser (avoids loadstring for security)
local function Deserialize(str)
    if type(str) ~= "string" or str == "" then return nil end
    local pos = 1
    local len = #str
    local MAX_DEPTH = 20

    local parseValue  -- forward declaration

    local function skipWS()
        while pos <= len do
            local b = str:byte(pos)
            if b == 32 or b == 9 or b == 10 or b == 13 then pos = pos + 1
            else break end
        end
    end

    local function peek()
        skipWS()
        return pos <= len and str:byte(pos) or 0
    end

    local function parseString()
        pos = pos + 1  -- skip opening "
        local parts = {}
        while pos <= len do
            local b = str:byte(pos)
            if b == 34 then  -- closing "
                pos = pos + 1
                return table.concat(parts), true
            elseif b == 92 then  -- backslash
                pos = pos + 1
                if pos > len then return nil, false end
                local esc = str:byte(pos)
                if     esc == 110 then parts[#parts + 1] = "\n"
                elseif esc == 116 then parts[#parts + 1] = "\t"
                elseif esc == 114 then parts[#parts + 1] = "\r"
                elseif esc == 92  then parts[#parts + 1] = "\\"
                elseif esc == 34  then parts[#parts + 1] = "\""
                elseif esc == 10  then parts[#parts + 1] = "\n"
                elseif esc >= 48 and esc <= 57 then
                    local numStr = string.char(esc)
                    for _ = 1, 2 do
                        local nb = pos + 1 <= len and str:byte(pos + 1)
                        if nb and nb >= 48 and nb <= 57 then
                            numStr = numStr .. string.char(nb)
                            pos = pos + 1
                        else break end
                    end
                    local code = tonumber(numStr)
                    if not code or code > 255 then return nil, false end
                    parts[#parts + 1] = string.char(code)
                else
                    parts[#parts + 1] = string.char(esc)
                end
                pos = pos + 1
            else
                parts[#parts + 1] = string.char(b)
                pos = pos + 1
            end
        end
        return nil, false  -- unterminated string
    end

    local function parseNumber()
        local start = pos
        if str:byte(pos) == 45 then pos = pos + 1 end  -- minus
        if pos > len or str:byte(pos) < 48 or str:byte(pos) > 57 then
            pos = start; return nil, false
        end
        while pos <= len and str:byte(pos) >= 48 and str:byte(pos) <= 57 do pos = pos + 1 end
        if pos <= len and str:byte(pos) == 46 then  -- decimal
            pos = pos + 1
            while pos <= len and str:byte(pos) >= 48 and str:byte(pos) <= 57 do pos = pos + 1 end
        end
        if pos <= len and (str:byte(pos) == 101 or str:byte(pos) == 69) then  -- exponent
            pos = pos + 1
            if pos <= len and (str:byte(pos) == 43 or str:byte(pos) == 45) then pos = pos + 1 end
            while pos <= len and str:byte(pos) >= 48 and str:byte(pos) <= 57 do pos = pos + 1 end
        end
        local n = tonumber(str:sub(start, pos - 1))
        if not n then pos = start; return nil, false end
        return n, true
    end

    local function isWordChar(b)
        return (b >= 65 and b <= 90) or (b >= 97 and b <= 122)
            or (b >= 48 and b <= 57) or b == 95
    end

    local function parseTable(depth)
        if depth > MAX_DEPTH then return nil, false end
        pos = pos + 1  -- skip {
        local tbl = {}
        local arrayIdx = 1

        while true do
            local b = peek()
            if b == 125 then  -- }
                pos = pos + 1
                return tbl, true
            elseif b == 0 then
                return nil, false
            end

            if b == 91 then  -- [key]=value
                pos = pos + 1
                local key, ok = parseValue(depth + 1)
                if not ok then return nil, false end
                if peek() ~= 93 then return nil, false end  -- ]
                pos = pos + 1
                if peek() ~= 61 then return nil, false end  -- =
                pos = pos + 1
                local val, vok = parseValue(depth + 1)
                if not vok then return nil, false end
                tbl[key] = val
            elseif (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or b == 95 then
                -- identifier or keyword (true/false)
                local idStart = pos
                while pos <= len and isWordChar(str:byte(pos)) do pos = pos + 1 end
                local ident = str:sub(idStart, pos - 1)
                if peek() == 61 then  -- key=value
                    pos = pos + 1
                    local val, vok = parseValue(depth + 1)
                    if not vok then return nil, false end
                    tbl[ident] = val
                else
                    -- bare keyword value
                    local val
                    if ident == "true" then val = true
                    elseif ident == "false" then val = false
                    else return nil, false end
                    tbl[arrayIdx] = val
                    arrayIdx = arrayIdx + 1
                end
            else
                -- plain value (number, string, nested table)
                local val, ok = parseValue(depth + 1)
                if not ok then return nil, false end
                tbl[arrayIdx] = val
                arrayIdx = arrayIdx + 1
            end

            local nb = peek()
            if nb == 44 then  -- comma
                pos = pos + 1
            elseif nb ~= 125 then  -- must be } or ,
                return nil, false
            end
        end
    end

    parseValue = function(depth)
        local b = peek()
        if b == 123 then return parseTable(depth or 0) end     -- {
        if b == 34  then return parseString() end               -- "
        if b == 45 or (b >= 48 and b <= 57) then                -- number
            return parseNumber()
        end
        -- keywords
        if str:sub(pos, pos + 3) == "true" and not isWordChar(str:byte(pos + 4) or 0) then
            pos = pos + 4; return true, true
        end
        if str:sub(pos, pos + 4) == "false" and not isWordChar(str:byte(pos + 5) or 0) then
            pos = pos + 5; return false, true
        end
        return nil, false
    end

    local ok, result = pcall(function()
        local val, success = parseValue(0)
        if not success then return nil end
        skipWS()
        if pos <= len then return nil end  -- trailing chars
        if type(val) ~= "table" then return nil end
        return val
    end)
    if not ok then return nil end
    return result
end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function Base64Encode(data)
    local out = {}
    local len = #data
    for i = 1, len, 3 do
        local a, b, c = data:byte(i, i + 2)
        b = b or 0; c = c or 0
        local n = a * 65536 + b * 256 + c
        out[#out + 1] = B64:sub(math.floor(n / 262144) % 64 + 1, math.floor(n / 262144) % 64 + 1)
        out[#out + 1] = B64:sub(math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1)
        out[#out + 1] = (i + 1 <= len) and B64:sub(math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1) or "="
        out[#out + 1] = (i + 2 <= len) and B64:sub(n % 64 + 1, n % 64 + 1) or "="
    end
    return table.concat(out)
end

local B64_REV = {}
for i = 1, 64 do B64_REV[B64:byte(i)] = i - 1 end

local function Base64Decode(data)
    if type(data) ~= "string" then return nil end
    data = data:gsub("[^A-Za-z0-9+/=]", "")
    local out = {}
    for i = 1, #data, 4 do
        local a, b, c, d = data:byte(i, i + 3)
        a, b = B64_REV[a] or 0, B64_REV[b] or 0
        c = c and (B64_REV[c] or 0) or 0
        d = d and (B64_REV[d] or 0) or 0
        local n = a * 262144 + b * 4096 + c * 64 + d
        out[#out + 1] = string.char(math.floor(n / 65536) % 256)
        if data:sub(i + 2, i + 2) ~= "=" then
            out[#out + 1] = string.char(math.floor(n / 256) % 256)
        end
        if data:sub(i + 3, i + 3) ~= "=" then
            out[#out + 1] = string.char(n % 256)
        end
    end
    return table.concat(out)
end

function ns.SettingsIO:Export()
    local data = {}
    for _, m in ipairs(self.modules) do
        local val = m.get()
        if val then data[m.key] = val end
    end
    return Base64Encode(Serialize(data))
end

function ns.SettingsIO:Preview(encoded)
    local raw = Base64Decode(encoded)
    local data = Deserialize(raw)
    if not data then return nil end
    local found = {}
    for k in pairs(data) do found[k] = true end
    return found
end

function ns.SettingsIO:Import(encoded, selectedKeys)
    local raw = Base64Decode(encoded)
    local data = Deserialize(raw)
    if not data then return false, "Invalid import string." end

    -- Validate all selected modules before applying any changes
    for _, m in ipairs(self.modules) do
        if selectedKeys[m.key] and data[m.key] then
            local valid, err = ValidateImportData(m.key, data[m.key])
            if not valid then
                return false, "Invalid data for " .. m.label .. ": " .. (err or "unknown error")
            end
        end
    end

    -- Apply validated data
    for _, m in ipairs(self.modules) do
        if selectedKeys[m.key] and data[m.key] then
            m.set(data[m.key])
        end
    end
    return true
end

-- Profile Management (profiles are stored as export strings)
-- NaowhQOL.profiles = { ["ProfileName"] = "base64string", ... }
-- NaowhQOL.activeProfile = "Default"
-- NaowhQOL_Profiles = { ["Realm-Character"] = { ["ProfileName"] = "base64string" }, ... }

function ns.SettingsIO:InitProfiles()
    NaowhQOL.profiles = NaowhQOL.profiles or {}
    NaowhQOL.activeProfile = NaowhQOL.activeProfile or "Default"
    NaowhQOL_Profiles = NaowhQOL_Profiles or {}
end

local cachedCharKey = nil

function ns.SettingsIO:GetCharacterKey()
    if cachedCharKey then return cachedCharKey end

    local name = UnitName("player")
    local realm = GetRealmName()

    -- Return nil if not ready yet
    if not name or name == "Unknown" or not realm then
        return nil
    end

    cachedCharKey = realm .. "-" .. name
    return cachedCharKey
end

function ns.SettingsIO:GetProfileList()
    self:InitProfiles()
    local list = {}
    for name in pairs(NaowhQOL.profiles) do
        list[#list + 1] = name
    end
    table.sort(list)
    return list
end

function ns.SettingsIO:GetActiveProfile()
    self:InitProfiles()
    local active = NaowhQOL.activeProfile

    -- Validate that active profile exists
    if active and NaowhQOL.profiles[active] then
        return active
    end

    -- Fall back to first available profile
    local list = self:GetProfileList()
    if #list > 0 then
        NaowhQOL.activeProfile = list[1]
        return list[1]
    end

    return "Unsaved"
end

function ns.SettingsIO:SaveProfile(name)
    self:InitProfiles()
    local exportStr = self:Export()
    NaowhQOL.profiles[name] = exportStr
    NaowhQOL.activeProfile = name

    -- Sync to account-wide registry for cross-character copy
    local charKey = self:GetCharacterKey()
    if charKey then
        NaowhQOL_Profiles[charKey] = NaowhQOL_Profiles[charKey] or {}
        NaowhQOL_Profiles[charKey][name] = exportStr
    end

    return true
end

function ns.SettingsIO:LoadProfile(name)
    self:InitProfiles()
    local exportStr = NaowhQOL.profiles[name]
    if not exportStr then return false, "Profile not found" end

    -- Import all modules from the stored string
    local allKeys = {}
    for _, m in ipairs(self.modules) do
        allKeys[m.key] = true
    end

    local ok, err = self:Import(exportStr, allKeys)
    if ok then
        NaowhQOL.activeProfile = name
    end
    return ok, err
end

function ns.SettingsIO:DeleteProfile(name)
    self:InitProfiles()
    if not NaowhQOL.profiles[name] then return false end

    NaowhQOL.profiles[name] = nil

    -- Remove from account registry
    local charKey = self:GetCharacterKey()
    if charKey and NaowhQOL_Profiles[charKey] then
        NaowhQOL_Profiles[charKey][name] = nil
    end

    -- Switch to another profile if we deleted the active one
    if NaowhQOL.activeProfile == name then
        local remaining = self:GetProfileList()
        NaowhQOL.activeProfile = remaining[1] or "Unsaved"
    end

    return true
end

function ns.SettingsIO:RenameProfile(oldName, newName)
    self:InitProfiles()
    if not NaowhQOL.profiles[oldName] then return false, "not_found" end
    if NaowhQOL.profiles[newName] then return false, "exists" end

    NaowhQOL.profiles[newName] = NaowhQOL.profiles[oldName]
    NaowhQOL.profiles[oldName] = nil

    -- Update account registry
    local charKey = self:GetCharacterKey()
    if charKey and NaowhQOL_Profiles[charKey] and NaowhQOL_Profiles[charKey][oldName] then
        NaowhQOL_Profiles[charKey][newName] = NaowhQOL_Profiles[charKey][oldName]
        NaowhQOL_Profiles[charKey][oldName] = nil
    end

    if NaowhQOL.activeProfile == oldName then
        NaowhQOL.activeProfile = newName
    end

    return true
end

function ns.SettingsIO:GetOtherCharacters()
    self:InitProfiles()
    local charKey = self:GetCharacterKey()
    local chars = {}
    for key in pairs(NaowhQOL_Profiles) do
        if not charKey or key ~= charKey then
            chars[#chars + 1] = key
        end
    end
    table.sort(chars)
    return chars
end

function ns.SettingsIO:GetCharacterProfiles(charKey)
    self:InitProfiles()
    local profiles = NaowhQOL_Profiles[charKey]
    if not profiles then return {} end

    local list = {}
    for name in pairs(profiles) do
        list[#list + 1] = name
    end
    table.sort(list)
    return list
end

function ns.SettingsIO:CopyFromCharacter(charKey, profileName, saveAsName)
    self:InitProfiles()
    local charProfiles = NaowhQOL_Profiles[charKey]
    if not charProfiles then return false, "Character not found" end

    local exportStr = charProfiles[profileName]
    if not exportStr then return false, "Profile not found" end

    -- Import all modules
    local allKeys = {}
    for _, m in ipairs(self.modules) do
        allKeys[m.key] = true
    end

    local ok, err = self:Import(exportStr, allKeys)
    if ok then
        -- Save as new profile
        local newName = saveAsName or profileName
        NaowhQOL.profiles[newName] = exportStr
        NaowhQOL.activeProfile = newName

        -- Sync to account registry
        local myCharKey = self:GetCharacterKey()
        if myCharKey then
            NaowhQOL_Profiles[myCharKey] = NaowhQOL_Profiles[myCharKey] or {}
            NaowhQOL_Profiles[myCharKey][newName] = exportStr
        end
    end
    return ok, err
end

ns.SettingsIO:RegisterSimple("combatTimer",   "Combat Timer")
ns.SettingsIO:RegisterSimple("combatAlert",   "Combat Alert")
ns.SettingsIO:RegisterSimple("crosshair",     "Crosshair")
ns.SettingsIO:RegisterSimple("combatLogger",  "Combat Logger")
ns.SettingsIO:RegisterSimple("mouseRing",     "Mouse Ring")
ns.SettingsIO:RegisterSimple("dragonriding",  "Dragonriding")
ns.SettingsIO:RegisterSimple("misc",          "Misc Toggles")
ns.SettingsIO:RegisterSimple("buffMonitor",   "Buff Monitor")
ns.SettingsIO:RegisterSimple("consumableChecker", "Consumable Checker")
ns.SettingsIO:RegisterSimple("gcdTracker",       "GCD Tracker")
ns.SettingsIO:RegisterSimple("stealthReminder",  "Stealth Reminder")
ns.SettingsIO:RegisterSimple("emoteDetection",   "Emote Detection")
ns.SettingsIO:RegisterSimple("rangeCheck",       "Range Check")
ns.SettingsIO:RegisterSimple("focusCastBar",     "Focus Cast Bar")
ns.SettingsIO:RegisterSimple("slashCommands",    "Slash Commands")
ns.SettingsIO:RegisterSimple("cRez",             "Combat Rez")
ns.SettingsIO:RegisterSimple("petTracker",       "Pet Tracker")
