local addonName, ns = ...
local L = ns.L

local cache = {}
local W = ns.Widgets
local C = ns.COLORS

local function PlaceSlider(slider, parent, x, y)
    local frame = slider:GetParent()
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    return slider
end

function ns:InitCombatAlerts()
    local p = ns.MainFrame.Content
    local db = NaowhQOL.combatAlert
    local display = ns.CombatAlertDisplay

    W:CachedPanel(cache, "caFrame", p, function(f)
        local sf, sc = W:CreateScrollFrame(f, 1200)

        W:CreatePageHeader(sc,
            {{"COMBAT", C.BLUE}, {"ALERT", C.ORANGE}},
            W.Colorize(L["COMBATALERT_SUBTITLE"], C.GRAY))

        local function refresh() if display then display:UpdateDisplay() end end

        -- on/off toggle
        local killArea = CreateFrame("Frame", nil, sc, "BackdropTemplate")
        killArea:SetSize(460, 62)
        killArea:SetPoint("TOPLEFT", 10, -75)
        killArea:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
        killArea:SetBackdropColor(0.01, 0.56, 0.91, 0.08)

        local masterCB = W:CreateCheckbox(killArea, {
            label = L["COMBATALERT_ENABLE"],
            db = db, key = "enabled",
            x = 15, y = -8,
            isMaster = true,
        })

        local unlockCB = W:CreateCheckbox(killArea, {
            label = L["COMMON_UNLOCK"],
            db = db, key = "unlock",
            x = 15, y = -38,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refresh
        })
        unlockCB:SetShown(db.enabled)

        -- Section container
        local sectionContainer = CreateFrame("Frame", nil, sc)
        sectionContainer:SetPoint("TOPLEFT", killArea, "BOTTOMLEFT", 0, -10)
        sectionContainer:SetPoint("RIGHT", sc, "RIGHT", -10, 0)
        sectionContainer:SetHeight(1000)

        local RelayoutSections

        -- APPEARANCE section
        local appWrap, appContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["COMMON_SECTION_APPEARANCE"],
            startOpen = true,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        W:CreateFontPicker(appContent, 10, -5, db.font, function(path)
            db.font = path
            refresh()
        end)

        appContent:SetHeight(50)
        appWrap:RecalcHeight()

        -- ENTER COMBAT section
        local enterWrap, enterContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["COMBATALERT_SECTION_ENTER"],
            startOpen = true,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        W:CreateTextInput(enterContent, {
            label = L["COMBATALERT_DISPLAY_TEXT"], db = db, key = "enterText",
            default = "++ Combat", x = 10, y = -8, width = 200,
            onChange = refresh
        })

        W:CreateColorPicker(enterContent, {
            label = L["COMMON_LABEL_TEXT_COLOR"], db = db,
            rKey = "enterR", gKey = "enterG", bKey = "enterB",
            x = 10, y = -44,
            onChange = refresh
        })

        W:CreateDropdown(enterContent, {
            label = L["COMBATALERT_AUDIO_MODE"],
            x = 10, y = -84,
            db = db, key = "enterAudioMode",
            options = {
                { text = L["COMBATALERT_AUDIO_NONE"], value = "none" },
                { text = L["COMBATALERT_AUDIO_SOUND"], value = "sound" },
                { text = L["COMBATALERT_AUDIO_TTS"], value = "tts" },
            },
            onChange = refresh
        })

        W:CreateSoundPicker(enterContent, 10, -139, db.enterSoundID, function(soundId)
            db.enterSoundID = soundId
        end)

        local enterTtsLbl = enterContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        enterTtsLbl:SetPoint("TOPLEFT", 10, -184)
        enterTtsLbl:SetText(L["COMMON_TTS_MESSAGE"])

        local enterTtsBox = CreateFrame("EditBox", nil, enterContent, "BackdropTemplate")
        enterTtsBox:SetSize(180, 24)
        enterTtsBox:SetPoint("LEFT", enterTtsLbl, "RIGHT", 8, 0)
        enterTtsBox:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]],
            edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
        enterTtsBox:SetBackdropColor(0, 0, 0, 1)
        enterTtsBox:SetBackdropBorderColor(0, 0, 0, 1)
        enterTtsBox:SetFontObject("GameFontHighlightSmall")
        enterTtsBox:SetAutoFocus(false)
        enterTtsBox:SetTextInsets(6, 6, 0, 0)
        enterTtsBox:SetMaxLetters(50)
        enterTtsBox:SetText(db.enterTtsMessage or "Combat")
        enterTtsBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        enterTtsBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        enterTtsBox:SetScript("OnEditFocusLost", function(self)
            local val = strtrim(self:GetText())
            if val == "" then val = "Combat"; self:SetText(val) end
            db.enterTtsMessage = val
        end)

        local enterTtsVoiceLbl = enterContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        enterTtsVoiceLbl:SetPoint("TOPLEFT", 10, -214)
        enterTtsVoiceLbl:SetText(L["COMMON_TTS_VOICE"])

        W:CreateTTSVoicePicker(enterContent, 80, -211, db.enterTtsVoiceID or 0, function(voiceID)
            db.enterTtsVoiceID = voiceID
        end)

        local enterTtsVolSlider = W:CreateAdvancedSlider(enterContent,
            W.Colorize(L["COMMON_TTS_VOLUME"], C.ORANGE), 0, 100, -249, 5, true,
            function(val) db.enterTtsVolume = val end,
            { db = db, key = "enterTtsVolume", moduleName = "combatAlert" })
        PlaceSlider(enterTtsVolSlider, enterContent, 0, -249)

        local enterTtsRateSlider = W:CreateAdvancedSlider(enterContent,
            W.Colorize(L["COMMON_TTS_SPEED"], C.ORANGE), -10, 10, -249, 1, false,
            function(val) db.enterTtsRate = val end,
            { db = db, key = "enterTtsRate", moduleName = "combatAlert" })
        PlaceSlider(enterTtsRateSlider, enterContent, 240, -249)

        enterContent:SetHeight(310)
        enterWrap:RecalcHeight()

        -- LEAVE COMBAT section
        local leaveWrap, leaveContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["COMBATALERT_SECTION_LEAVE"],
            startOpen = true,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        W:CreateTextInput(leaveContent, {
            label = L["COMBATALERT_DISPLAY_TEXT"], db = db, key = "leaveText",
            default = "-- Combat", x = 10, y = -8, width = 200,
            onChange = refresh
        })

        W:CreateColorPicker(leaveContent, {
            label = L["COMMON_LABEL_TEXT_COLOR"], db = db,
            rKey = "leaveR", gKey = "leaveG", bKey = "leaveB",
            x = 10, y = -44,
            onChange = refresh
        })

        W:CreateDropdown(leaveContent, {
            label = L["COMBATALERT_AUDIO_MODE"],
            x = 10, y = -84,
            db = db, key = "leaveAudioMode",
            options = {
                { text = L["COMBATALERT_AUDIO_NONE"], value = "none" },
                { text = L["COMBATALERT_AUDIO_SOUND"], value = "sound" },
                { text = L["COMBATALERT_AUDIO_TTS"], value = "tts" },
            },
            onChange = refresh
        })

        W:CreateSoundPicker(leaveContent, 10, -139, db.leaveSoundID, function(soundId)
            db.leaveSoundID = soundId
        end)

        local leaveTtsLbl = leaveContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        leaveTtsLbl:SetPoint("TOPLEFT", 10, -184)
        leaveTtsLbl:SetText(L["COMMON_TTS_MESSAGE"])

        local leaveTtsBox = CreateFrame("EditBox", nil, leaveContent, "BackdropTemplate")
        leaveTtsBox:SetSize(180, 24)
        leaveTtsBox:SetPoint("LEFT", leaveTtsLbl, "RIGHT", 8, 0)
        leaveTtsBox:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]],
            edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
        leaveTtsBox:SetBackdropColor(0, 0, 0, 1)
        leaveTtsBox:SetBackdropBorderColor(0, 0, 0, 1)
        leaveTtsBox:SetFontObject("GameFontHighlightSmall")
        leaveTtsBox:SetAutoFocus(false)
        leaveTtsBox:SetTextInsets(6, 6, 0, 0)
        leaveTtsBox:SetMaxLetters(50)
        leaveTtsBox:SetText(db.leaveTtsMessage or "Safe")
        leaveTtsBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        leaveTtsBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        leaveTtsBox:SetScript("OnEditFocusLost", function(self)
            local val = strtrim(self:GetText())
            if val == "" then val = "Safe"; self:SetText(val) end
            db.leaveTtsMessage = val
        end)

        local leaveTtsVoiceLbl = leaveContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        leaveTtsVoiceLbl:SetPoint("TOPLEFT", 10, -214)
        leaveTtsVoiceLbl:SetText(L["COMMON_TTS_VOICE"])

        W:CreateTTSVoicePicker(leaveContent, 80, -211, db.leaveTtsVoiceID or 0, function(voiceID)
            db.leaveTtsVoiceID = voiceID
        end)

        local leaveTtsVolSlider = W:CreateAdvancedSlider(leaveContent,
            W.Colorize(L["COMMON_TTS_VOLUME"], C.ORANGE), 0, 100, -249, 5, true,
            function(val) db.leaveTtsVolume = val end,
            { db = db, key = "leaveTtsVolume", moduleName = "combatAlert" })
        PlaceSlider(leaveTtsVolSlider, leaveContent, 0, -249)

        local leaveTtsRateSlider = W:CreateAdvancedSlider(leaveContent,
            W.Colorize(L["COMMON_TTS_SPEED"], C.ORANGE), -10, 10, -249, 1, false,
            function(val) db.leaveTtsRate = val end,
            { db = db, key = "leaveTtsRate", moduleName = "combatAlert" })
        PlaceSlider(leaveTtsRateSlider, leaveContent, 240, -249)

        leaveContent:SetHeight(310)
        leaveWrap:RecalcHeight()

        -- Relayout
        local allSections = { appWrap, enterWrap, leaveWrap }

        RelayoutSections = function()
            for i, section in ipairs(allSections) do
                section:ClearAllPoints()
                if i == 1 then
                    section:SetPoint("TOPLEFT", sectionContainer, "TOPLEFT", 0, 0)
                else
                    section:SetPoint("TOPLEFT", allSections[i - 1], "BOTTOMLEFT", 0, -12)
                end
                section:SetPoint("RIGHT", sectionContainer, "RIGHT", 0, 0)
            end

            local totalH = 75 + 62 + 10
            if db.enabled then
                for _, s in ipairs(allSections) do
                    totalH = totalH + s:GetHeight() + 12
                end
            end
            sc:SetHeight(math.max(totalH + 40, 600))
        end

        masterCB:SetScript("OnClick", function(self)
            db.enabled = self:GetChecked() and true or false
            refresh()
            unlockCB:SetShown(db.enabled)
            sectionContainer:SetShown(db.enabled)
            RelayoutSections()
        end)
        sectionContainer:SetShown(db.enabled)

        -- Restore defaults button
        local restoreBtn = W:CreateRestoreDefaultsButton({
            moduleName = "combatAlert",
            parent = sc,
            initFunc = function() ns:InitCombatAlerts() end,
            onRestore = function()
                if cache.caFrame then
                    cache.caFrame:Hide()
                    cache.caFrame:SetParent(nil)
                    cache.caFrame = nil
                end
                if display then display:UpdateDisplay() end
            end
        })
        restoreBtn:SetPoint("BOTTOMLEFT", sc, "BOTTOMLEFT", 10, 20)

        RelayoutSections()
    end)
end
