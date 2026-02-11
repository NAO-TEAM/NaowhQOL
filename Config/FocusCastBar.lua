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

function ns:InitFocusCastBar()
    local p = ns.MainFrame.Content
    local db = NaowhQOL.focusCastBar
    local display = ns.FocusCastBarDisplay

    -- Migrate old soundID format to new sound format
    if db.soundID and not db.sound then
        db.sound = { id = db.soundID }
    end

    W:CachedPanel(cache, "fcbFrame", p, function(f)
        local sf, sc = W:CreateScrollFrame(f, 1200)

        W:CreatePageHeader(sc,
            {{"FOCUS ", C.BLUE}, {"CAST BAR", C.ORANGE}},
            W.Colorize(L["FOCUS_SUBTITLE"], C.GRAY))

        local function onUpdate() if display then display:UpdateDisplay() end end

        -- Master enable area
        local killArea = CreateFrame("Frame", nil, sc, "BackdropTemplate")
        killArea:SetSize(460, 62)
        killArea:SetPoint("TOPLEFT", 10, -75)
        killArea:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
        killArea:SetBackdropColor(0.01, 0.56, 0.91, 0.08)

        local masterCB = W:CreateCheckbox(killArea, {
            label = L["FOCUS_ENABLE"],
            db = db, key = "enabled",
            x = 15, y = -8,
            isMaster = true,
        })

        local unlockCB = W:CreateCheckbox(killArea, {
            label = L["COMMON_UNLOCK"],
            db = db, key = "unlock",
            x = 15, y = -38,
            template = "ChatConfigCheckButtonTemplate",
            onChange = onUpdate
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
            startOpen = false,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local G = ns.Layout:New(2)

        local barColorLbl = appContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        barColorLbl:SetPoint("TOPLEFT", G:Col(1), G:Row(1) + 10)
        barColorLbl:SetText(L["FOCUS_BAR_COLOR"])

        W:CreateColorPicker(appContent, {
            label = L["FOCUS_BAR_READY"], db = db,
            rKey = "barColorR", gKey = "barColorG", bKey = "barColorB",
            x = G:Col(1), y = G:Row(1) - 15,
            onChange = onUpdate
        })

        W:CreateColorPicker(appContent, {
            label = L["FOCUS_BAR_CD"], db = db,
            rKey = "barColorCdR", gKey = "barColorCdG", bKey = "barColorCdB",
            x = G:Col(2), y = G:Row(1) - 15,
            onChange = onUpdate
        })

        W:CreateColorPicker(appContent, {
            label = L["FOCUS_NONINT_COLOR"], db = db,
            rKey = "nonIntColorR", gKey = "nonIntColorG", bKey = "nonIntColorB",
            x = G:Col(1), y = G:Row(2) + 5,
            onChange = onUpdate
        })

        W:CreateColorPicker(appContent, {
            label = L["FOCUS_BACKGROUND"], db = db,
            rKey = "bgColorR", gKey = "bgColorG", bKey = "bgColorB",
            x = G:Col(1), y = G:Row(3) + 5,
            onChange = onUpdate
        })

        -- bgAlpha stored as 0-1, slider shows 0-100
        local bgAlphaSlider = W:CreateAdvancedSlider(appContent,
            W.Colorize(L["FOCUS_BG_OPACITY"], C.ORANGE), 0, 100, -125, 5, true,
            function(val) db.bgAlpha = val / 100; onUpdate() end,
            { value = (db.bgAlpha ~= nil and db.bgAlpha or 0.8) * 100 })
        PlaceSlider(bgAlphaSlider, appContent, G:Col(2), G:Row(3))

        appContent:SetHeight(G:Height(3))
        appWrap:RecalcHeight()

        -- ICON section
        local iconWrap, iconContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["FOCUS_SECTION_ICON"],
            startOpen = false,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local GI = ns.Layout:New(2)

        W:CreateCheckbox(iconContent, {
            label = L["FOCUS_SHOW_ICON"],
            db = db, key = "showIcon",
            x = GI:Col(1), y = GI:Row(1) + 5,
            template = "ChatConfigCheckButtonTemplate",
            onChange = onUpdate
        })

        local iconSizeSlider = W:CreateAdvancedSlider(iconContent,
            W.Colorize(L["COMMON_LABEL_ICON_SIZE"], C.ORANGE), 16, 64, -35, 1, false,
            function(val) db.iconSize = val; onUpdate() end,
            { db = db, key = "iconSize", moduleName = "focusCastBar" })
        PlaceSlider(iconSizeSlider, iconContent, GI:Col(1), GI:Row(2))

        db.iconPosition = db.iconPosition or "LEFT"
        W:CreateDropdown(iconContent, {
            label = L["FOCUS_ICON_POS"],
            db = db, key = "iconPosition",
            options = {"LEFT", "RIGHT", "TOP", "BOTTOM"},
            x = GI:Col(2), y = GI:Row(2),
            width = 120,
            globalName = "NaowhFcbIconPosDrop",
            onChange = onUpdate
        })

        iconContent:SetHeight(GI:Height(2))
        iconWrap:RecalcHeight()

        -- TEXT section
        local textWrap, textContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["FOCUS_SECTION_TEXT"],
            startOpen = false,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local GT = ns.Layout:New(2)

        W:CreateCheckbox(textContent, {
            label = L["FOCUS_SHOW_NAME"],
            db = db, key = "showSpellName",
            x = GT:Col(1), y = GT:Row(1) + 5,
            template = "ChatConfigCheckButtonTemplate",
            onChange = onUpdate
        })

        W:CreateCheckbox(textContent, {
            label = L["FOCUS_SHOW_TIME"],
            db = db, key = "showTimeRemaining",
            x = GT:Col(2), y = GT:Row(1) + 5,
            template = "ChatConfigCheckButtonTemplate",
            onChange = onUpdate
        })

        W:CreateFontPicker(textContent, GT:Col(1), GT:Row(2) - 5, db.font, function(path)
            db.font = path
            onUpdate()
        end)

        local fontSizeSlider = W:CreateAdvancedSlider(textContent,
            W.Colorize(L["COMMON_LABEL_FONT_SIZE"], C.ORANGE), 8, 24, -100, 1, false,
            function(val) db.fontSize = val; onUpdate() end,
            { db = db, key = "fontSize", moduleName = "focusCastBar" })
        PlaceSlider(fontSizeSlider, textContent, GT:Col(2), GT:Row(2))

        W:CreateColorPicker(textContent, {
            label = L["COMMON_LABEL_TEXT_COLOR"], db = db,
            rKey = "textColorR", gKey = "textColorG", bKey = "textColorB",
            x = GT:Col(1), y = GT:Row(3) + 5,
            onChange = onUpdate
        })

        textContent:SetHeight(GT:Height(3))
        textWrap:RecalcHeight()

        -- BEHAVIOR section
        local behWrap, behContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["COMMON_SECTION_BEHAVIOR"],
            startOpen = false,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        W:CreateCheckbox(behContent, {
            label = L["FOCUS_SHOW_EMPOWER"],
            db = db, key = "showEmpowerStages",
            x = 10, y = -5,
            template = "ChatConfigCheckButtonTemplate",
            onChange = onUpdate
        })

        W:CreateCheckbox(behContent, {
            label = L["FOCUS_HIDE_FRIENDLY"],
            db = db, key = "hideFriendlyCasts",
            x = 10, y = -29,
            template = "ChatConfigCheckButtonTemplate",
            onChange = onUpdate
        })

        W:CreateCheckbox(behContent, {
            label = L["FOCUS_SHOW_SHIELD"],
            db = db, key = "showShieldIcon",
            x = 10, y = -53,
            template = "ChatConfigCheckButtonTemplate",
            onChange = onUpdate
        })

        W:CreateCheckbox(behContent, {
            label = L["FOCUS_CHANGE_COLOR"],
            db = db, key = "colorNonInterrupt",
            x = 10, y = -77,
            template = "ChatConfigCheckButtonTemplate",
            onChange = onUpdate
        })

        behContent:SetHeight(108)
        behWrap:RecalcHeight()

        -- AUDIO section
        local audioWrap, audioContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["COMMON_SECTION_AUDIO"],
            startOpen = false,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local GA = ns.Layout:New(2)

        local soundCB = W:CreateCheckbox(audioContent, {
            label = L["FOCUS_SOUND_START"],
            db = db, key = "soundEnabled",
            x = GA:Col(1), y = GA:Row(1) + 5,
            template = "ChatConfigCheckButtonTemplate",
            onChange = function()
                if db.soundEnabled then db.ttsEnabled = false end
                onUpdate()
            end
        })

        W:CreateSoundPicker(audioContent, GA:Col(1), GA:Row(2) + 15, db.sound, function(entry)
            db.sound = entry.id and { id = entry.id } or { path = entry.path }
        end)

        local ttsCB = W:CreateCheckbox(audioContent, {
            label = L["FOCUS_USE_TTS"],
            db = db, key = "ttsEnabled",
            x = GA:Col(1), y = GA:Row(3) + 20,
            template = "ChatConfigCheckButtonTemplate",
            onChange = function()
                if db.ttsEnabled then db.soundEnabled = false end
                onUpdate()
            end
        })

        local ttsLbl = audioContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        ttsLbl:SetPoint("TOPLEFT", GA:Col(1), GA:Row(4) + 10)
        ttsLbl:SetText(L["COMMON_TTS_MESSAGE"] .. ":")

        local ttsBox = CreateFrame("EditBox", nil, audioContent, "BackdropTemplate")
        ttsBox:SetSize(180, 24)
        ttsBox:SetPoint("LEFT", ttsLbl, "RIGHT", 8, 0)
        ttsBox:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]],
            edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
        ttsBox:SetBackdropColor(0, 0, 0, 1)
        ttsBox:SetBackdropBorderColor(0, 0, 0, 1)
        ttsBox:SetFontObject("GameFontHighlightSmall")
        ttsBox:SetAutoFocus(false)
        ttsBox:SetTextInsets(6, 6, 0, 0)
        ttsBox:SetMaxLetters(50)
        ttsBox:SetText(db.ttsMessage or L["FOCUS_TTS_DEFAULT"])
        ttsBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        ttsBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        ttsBox:SetScript("OnEditFocusLost", function(self)
            local val = strtrim(self:GetText())
            if val == "" then val = L["FOCUS_TTS_DEFAULT"]; self:SetText(val) end
            db.ttsMessage = val
        end)

        local ttsVoiceLbl = audioContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        ttsVoiceLbl:SetPoint("TOPLEFT", GA:Col(1), GA:Row(4) - 20)
        ttsVoiceLbl:SetText(L["COMMON_TTS_VOICE"] .. ":")

        W:CreateTTSVoicePicker(audioContent, 80, GA:Row(4) - 17, db.ttsVoiceID or 0, function(voiceID)
            db.ttsVoiceID = voiceID
        end)

        local ttsVolSlider = W:CreateAdvancedSlider(audioContent,
            W.Colorize(L["COMMON_TTS_VOLUME"], C.ORANGE), 0, 100, -175, 5, true,
            function(val) db.ttsVolume = val end,
            { db = db, key = "ttsVolume", moduleName = "focusCastBar" })
        PlaceSlider(ttsVolSlider, audioContent, GA:Col(1), GA:Row(5))

        local ttsRateSlider = W:CreateAdvancedSlider(audioContent,
            W.Colorize(L["COMMON_TTS_SPEED"], C.ORANGE), -10, 10, -175, 1, false,
            function(val) db.ttsRate = val end,
            { db = db, key = "ttsRate", moduleName = "focusCastBar" })
        PlaceSlider(ttsRateSlider, audioContent, GA:Col(2), GA:Row(5))

        audioContent:SetHeight(GA:Height(5))
        audioWrap:RecalcHeight()

        -- Relayout
        local allSections = { appWrap, iconWrap, textWrap, behWrap, audioWrap }

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

        masterCB:HookScript("OnClick", function(self)
            db.enabled = self:GetChecked() and true or false
            onUpdate()
            unlockCB:SetShown(db.enabled)
            sectionContainer:SetShown(db.enabled)
            RelayoutSections()
        end)
        sectionContainer:SetShown(db.enabled)

        -- Restore defaults button
        local restoreBtn = W:CreateRestoreDefaultsButton({
            moduleName = "focusCastBar",
            parent = sc,
            initFunc = function() ns:InitFocusCastBar() end,
            onRestore = function()
                -- Destroy cached frame so it gets rebuilt
                if cache.fcbFrame then
                    cache.fcbFrame:Hide()
                    cache.fcbFrame:SetParent(nil)
                    cache.fcbFrame = nil
                end
                if display then
                    display:Hide()
                    display:UpdateDisplay()
                end
            end
        })
        restoreBtn:SetPoint("BOTTOMLEFT", sc, "BOTTOMLEFT", 10, 20)

        RelayoutSections()
    end)

    if display then display:UpdateDisplay() end
end
