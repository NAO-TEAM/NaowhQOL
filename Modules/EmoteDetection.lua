local addonName, ns = ...
local W = ns.Widgets

------------------------------------------------------------
-- Display frame
------------------------------------------------------------
local UNLOCK_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local alertFrame = CreateFrame("Frame", "NaowhQOL_EmoteDetection", UIParent, "BackdropTemplate")
alertFrame:SetSize(200, 60)
alertFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
alertFrame:Hide()

local iconTex = alertFrame:CreateTexture(nil, "ARTWORK")
iconTex:SetSize(48, 48)
iconTex:SetPoint("LEFT", alertFrame, "LEFT", 6, 0)

local alertLabel = alertFrame:CreateFontString(nil, "OVERLAY")
alertLabel:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", 16, "OUTLINE")
alertLabel:SetPoint("TOPLEFT", iconTex, "TOPRIGHT", 8, 0)
alertLabel:SetPoint("BOTTOMRIGHT", alertFrame, "BOTTOMRIGHT", -6, 0)
alertLabel:SetJustifyH("LEFT")
alertLabel:SetJustifyV("MIDDLE")
alertLabel:SetWordWrap(true)

local resizeHandle

------------------------------------------------------------
-- Fade logic
------------------------------------------------------------
local FADE_DISPLAY = 4
local FADE_OUT = 1
local fadeTimer = nil
local fadeStart = 0
local fading = false

local function StopFade()
    if fadeTimer then fadeTimer:Cancel(); fadeTimer = nil end
    fading = false
    fadeStart = 0
end

local function BeginFadeOut()
    fading = true
    fadeStart = GetTime()
    if fadeTimer then fadeTimer:Cancel() end
    fadeTimer = C_Timer.NewTicker(0.03, function()
        local elapsed = GetTime() - fadeStart
        local alpha = 1 - (elapsed / FADE_OUT)
        if alpha <= 0 then
            alertFrame:SetAlpha(0)
            alertFrame:Hide()
            StopFade()
        else
            alertFrame:SetAlpha(alpha)
        end
    end)
end

local displayTimer = nil

local function ShowAlert(text)
    local db = NaowhQOL.emoteDetection
    if not db then return end

    StopFade()
    if displayTimer then displayTimer:Cancel(); displayTimer = nil end

    iconTex:SetTexture("Interface\\Icons\\INV_Misc_Food_164_Fish_Feast")
    iconTex:Show()

    local fontPath = db.font or "Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf"
    local fontSize = db.fontSize or 16
    local success = alertLabel:SetFont(fontPath, fontSize, "OUTLINE")
    if not success then
        alertLabel:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", fontSize, "OUTLINE")
    end

    alertLabel:SetText(text)
    alertLabel:SetTextColor(db.textR or 1, db.textG or 1, db.textB or 1)

    local iconSize = math.floor(alertFrame:GetHeight() * 0.8)
    local padding = 6 + iconSize + 8 + 6
    local textWidth = alertLabel:GetStringWidth() + 10
    local minWidth = db.width or 200
    local minHeight = db.height or 60
    local maxWidth = math.floor(UIParent:GetWidth() * 0.8)
    alertFrame:SetWidth(math.min(maxWidth, math.max(minWidth, textWidth + padding)))

    local textHeight = alertLabel:GetStringHeight() + 12
    alertFrame:SetHeight(math.max(minHeight, textHeight))
    iconTex:SetSize(math.floor(alertFrame:GetHeight() * 0.8), math.floor(alertFrame:GetHeight() * 0.8))

    alertFrame:SetAlpha(1)
    alertFrame:Show()

    displayTimer = C_Timer.After(FADE_DISPLAY, function()
        displayTimer = nil
        BeginFadeOut()
    end)
end

------------------------------------------------------------
-- UpdateDisplay (for unlock mode)
------------------------------------------------------------
function alertFrame:UpdateDisplay()
    local db = NaowhQOL.emoteDetection
    if not db then return end

    -- Early exit if disabled
    if not db.enabled then
        alertFrame:SetBackdrop(nil)
        if resizeHandle then resizeHandle:Hide() end
        alertFrame:Hide()
        return
    end

    if db.unlock then
        alertFrame:SetBackdrop(UNLOCK_BACKDROP)
        alertFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        alertFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        if resizeHandle then resizeHandle:Show() end

        iconTex:SetTexture("Interface\\Icons\\INV_Misc_Food_164_Fish_Feast")
        iconTex:Show()
        alertLabel:SetText("Emote Detection Preview")
        alertLabel:SetTextColor(db.textR or 1, db.textG or 1, db.textB or 1)

        local fontPath = db.font or "Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf"
        local fontSize = db.fontSize or 16
        local success = alertLabel:SetFont(fontPath, fontSize, "OUTLINE")
        if not success then
            alertLabel:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", fontSize, "OUTLINE")
        end

        alertFrame:SetAlpha(1)
        alertFrame:Show()
    else
        alertFrame:SetBackdrop(nil)
        if resizeHandle then resizeHandle:Hide() end
        alertFrame:Hide()
    end

    if not alertFrame.initialized then
        alertFrame:ClearAllPoints()
        local point = db.point or "CENTER"
        local x = db.x or 0
        local y = db.y or 0
        alertFrame:SetPoint(point, UIParent, point, x, y)
        alertFrame:SetSize(db.width or 200, db.height or 60)
        alertFrame.initialized = true
    end

    local iconSize = math.floor(alertFrame:GetHeight() * 0.8)
    iconTex:SetSize(iconSize, iconSize)
end

------------------------------------------------------------
-- State tracking
------------------------------------------------------------
local inCombat = false
local inInstance = false

------------------------------------------------------------
-- Auto Emote state and logic
------------------------------------------------------------
local lastEmoteTime = 0
local autoEmoteLookup = {}

local function RebuildAutoEmoteLookup()
    wipe(autoEmoteLookup)
    local db = NaowhQOL.emoteDetection
    if not db or not db.autoEmotes then return end
    for _, entry in ipairs(db.autoEmotes) do
        if entry.enabled ~= false and entry.spellId and entry.emoteText then
            autoEmoteLookup[entry.spellId] = entry.emoteText
        end
    end
end

local function OnPlayerCastStart(spellId)
    local db = NaowhQOL.emoteDetection
    if not db or not db.autoEmoteEnabled then return end
    if not inInstance then return end

    local now = GetTime()
    local cooldown = db.autoEmoteCooldown or 2
    if now - lastEmoteTime < cooldown then return end

    if ns.ZoneUtil and ns.ZoneUtil.IsInMythicPlus() then return end

    local emoteText = autoEmoteLookup[spellId]
    if emoteText then
        pcall(function()
            SendChatMessage(emoteText, "EMOTE")
        end)
        lastEmoteTime = now
    end
end

------------------------------------------------------------
-- Events
------------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
loader:RegisterEvent("CHAT_MSG_EMOTE")
loader:RegisterEvent("CHAT_MSG_MONSTER_EMOTE")
loader:RegisterEvent("CHAT_MSG_SYSTEM")
loader:RegisterEvent("PLAYER_REGEN_DISABLED")
loader:RegisterEvent("PLAYER_REGEN_ENABLED")
loader:RegisterEvent("UNIT_SPELLCAST_START")
loader:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")

loader:SetScript("OnEvent", ns.PerfMonitor:Wrap("Emote Detection", function(self, event, ...)
    local db = NaowhQOL.emoteDetection
    if not db then return end

    if event == "PLAYER_LOGIN" then
        inCombat = UnitAffectingCombat("player")
        inInstance = ns.ZoneUtil and ns.ZoneUtil.IsInInstance() or false

        db.width  = db.width  or 200
        db.height = db.height or 60
        db.point  = db.point  or "CENTER"
        db.x      = db.x      or 0
        db.y      = db.y      or 0

        W.MakeDraggable(alertFrame, { db = db })
        resizeHandle = W.CreateResizeHandle(alertFrame, {
            db = db,
            onResize = function() alertFrame:UpdateDisplay() end,
        })

        alertFrame.initialized = false
        alertFrame:UpdateDisplay()

        ns.ZoneUtil.RegisterCallback("EmoteDetection", function(snapshot)
            inInstance = snapshot.instanceType ~= "none"
        end)

        RebuildAutoEmoteLookup()
        return
    end

    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        local unit, castGUID, spellId = ...
        if unit == "player" then OnPlayerCastStart(spellId) end
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        return
    end

    if event == "CHAT_MSG_TEXT_EMOTE"
    or event == "CHAT_MSG_EMOTE"
    or event == "CHAT_MSG_MONSTER_EMOTE"
    or event == "CHAT_MSG_SYSTEM" then
        if not db.enabled then return end
        if inCombat then return end
        if not inInstance then return end
        if ns.ZoneUtil and ns.ZoneUtil.IsInMythicPlus() then return end

        local text = ...
        if not text then return end

        pcall(function()
            local raw = db.emotePattern or "prepares"
            local matched = false
            for token in raw:gmatch("[^,]+") do
                local trimmed = token:match("^%s*(.-)%s*$")
                if trimmed ~= "" and text:find(trimmed, 1, true) then
                    matched = true
                    break
                end
            end
            if not matched then return end

            ShowAlert(text)

            if db.soundOn then
                local soundID = db.soundID or 8959
                PlaySound(soundID, "Master")
            end
        end)
    end
end))

ns.EmoteDetectionDisplay = alertFrame
ns.RebuildAutoEmoteLookup = RebuildAutoEmoteLookup
