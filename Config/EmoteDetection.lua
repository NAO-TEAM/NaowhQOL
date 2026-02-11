local addonName, ns = ...
local L = ns.L

local cache = {}
local W = ns.Widgets
local C = ns.COLORS

------------------------------------------------------------
-- Config Init
------------------------------------------------------------
function ns:InitEmoteDetection()
    local p = ns.MainFrame.Content
    local db = NaowhQOL.emoteDetection
    local display = ns.EmoteDetectionDisplay

    W:CachedPanel(cache, "edFrame", p, function(f)
        local sf, sc = W:CreateScrollFrame(f, 800)

        W:CreatePageHeader(sc,
            {{"EMOTE ", C.BLUE}, {"DETECTION", C.ORANGE}},
            W.Colorize(L["EMOTE_SUBTITLE"], C.GRAY))

        local function refreshDisplay() if display then display:UpdateDisplay() end end

        -- ============================================================
        -- MASTER TOGGLE
        -- ============================================================

        local killArea = CreateFrame("Frame", nil, sc, "BackdropTemplate")
        killArea:SetSize(460, 62)
        killArea:SetPoint("TOPLEFT", 10, -75)
        killArea:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
        killArea:SetBackdropColor(0.01, 0.56, 0.91, 0.08)

        local masterCB = W:CreateCheckbox(killArea, {
            label = L["EMOTE_ENABLE"],
            db = db, key = "enabled",
            x = 15, y = -8,
            isMaster = true,
        })

        local unlockCB = W:CreateCheckbox(killArea, {
            label = L["COMMON_UNLOCK"],
            db = db, key = "unlock",
            x = 15, y = -38,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refreshDisplay
        })
        unlockCB:SetShown(db.enabled)

        -- ============================================================
        -- Settings container
        -- ============================================================

        local sections = CreateFrame("Frame", nil, sc)
        sections:SetPoint("TOPLEFT", killArea, "BOTTOMLEFT", 0, -10)
        sections:SetPoint("RIGHT", sc, "RIGHT", -10, 0)
        sections:SetHeight(400)

        local RelayoutAll

        -- APPEARANCE
        local appWrap, appContent = W:CreateCollapsibleSection(sections, {
            text = L["COMMON_SECTION_APPEARANCE"],
            startOpen = false,
            onCollapse = function() if RelayoutAll then RelayoutAll() end end,
        })

        W:CreateFontPicker(appContent, 10, -5, db.font, function(path)
            db.font = path
            refreshDisplay()
        end)

        local sizeSlider = W:CreateAdvancedSlider(appContent,
            W.Colorize(L["COMMON_LABEL_TEXT_SIZE"], C.ORANGE), 8, 36, -45, 1, false,
            function(val) db.fontSize = val; refreshDisplay() end,
            { db = db, key = "fontSize", moduleName = "emoteDetection" })

        W:CreateColorPicker(appContent, {
            label = L["COMMON_LABEL_TEXT_COLOR"], db = db,
            rKey = "textR", gKey = "textG", bKey = "textB",
            x = 10, y = -105,
            onChange = refreshDisplay
        })

        appContent:SetHeight(150)
        appWrap:RecalcHeight()

        -- EMOTE FILTER
        local filterWrap, filterContent = W:CreateCollapsibleSection(sections, {
            text = L["EMOTE_SECTION_FILTER"],
            startOpen = false,
            onCollapse = function() if RelayoutAll then RelayoutAll() end end,
        })

        local patternLabel = filterContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        patternLabel:SetPoint("TOPLEFT", 10, -10)
        patternLabel:SetText(L["EMOTE_MATCH_PATTERN"])

        local patternBox = CreateFrame("EditBox", nil, filterContent, "BackdropTemplate")
        patternBox:SetSize(260, 22)
        patternBox:SetPoint("LEFT", patternLabel, "RIGHT", 8, 0)
        patternBox:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]],
            edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
        patternBox:SetBackdropColor(0, 0, 0, 1)
        patternBox:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        patternBox:SetFontObject("GameFontHighlightSmall")
        patternBox:SetAutoFocus(false)
        patternBox:SetTextInsets(6, 6, 0, 0)
        patternBox:SetText(db.emotePattern or "prepares")
        patternBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        patternBox:SetScript("OnEnterPressed", function(self)
            db.emotePattern = self:GetText()
            self:ClearFocus()
        end)
        patternBox:SetScript("OnEditFocusLost", function(self)
            db.emotePattern = self:GetText()
        end)

        local patternHint = filterContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        patternHint:SetPoint("TOPLEFT", 10, -38)
        patternHint:SetTextColor(0.5, 0.5, 0.5)
        patternHint:SetText(L["EMOTE_PATTERN_HINT"])

        filterContent:SetHeight(60)
        filterWrap:RecalcHeight()

        -- SOUND
        local soundWrap, soundContent = W:CreateCollapsibleSection(sections, {
            text = L["COMMON_SECTION_SOUND"],
            startOpen = false,
            onCollapse = function() if RelayoutAll then RelayoutAll() end end,
        })

        W:CreateCheckbox(soundContent, {
            label = L["COMMON_LABEL_PLAY_SOUND"],
            db = db, key = "soundOn",
            x = 10, y = -5,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refreshDisplay,
        })

        W:CreateSoundPicker(soundContent, 10, -35, db.soundID or 8959,
            function(id) db.soundID = id end)

        soundContent:SetHeight(80)
        soundWrap:RecalcHeight()

        -- ============================================================
        -- AUTO EMOTE
        -- ============================================================
        local autoWrap, autoContent = W:CreateCollapsibleSection(sections, {
            text = L["EMOTE_SECTION_AUTO"],
            startOpen = false,
            onCollapse = function() if RelayoutAll then RelayoutAll() end end,
        })

        local autoDesc = autoContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        autoDesc:SetPoint("TOPLEFT", 10, -5)
        autoDesc:SetWidth(420)
        autoDesc:SetJustifyH("LEFT")
        autoDesc:SetText(W.Colorize(L["EMOTE_AUTO_DESC"], C.GRAY))

        W:CreateCheckbox(autoContent, {
            label = L["EMOTE_ENABLE_AUTO"],
            db = db, key = "autoEmoteEnabled",
            x = 10, y = -30,
            template = "ChatConfigCheckButtonTemplate",
            onChange = function() if ns.RebuildAutoEmoteLookup then ns.RebuildAutoEmoteLookup() end end,
        })

        local cdSlider = W:CreateAdvancedSlider(autoContent,
            W.Colorize(L["EMOTE_COOLDOWN"], C.ORANGE), 0, 10, -65, 0.5, false,
            function(val) db.autoEmoteCooldown = val end,
            { db = db, key = "autoEmoteCooldown", moduleName = "emoteDetection" })

        -- List container for auto emote entries
        local autoListContainer = CreateFrame("Frame", nil, autoContent)
        autoListContainer:SetPoint("TOPLEFT", 10, -110)
        autoListContainer:SetSize(420, 1)

        -- Modal editor
        local autoEditor = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        autoEditor:SetSize(380, 200)
        autoEditor:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14 })
        autoEditor:SetBackdropColor(0.08, 0.08, 0.08, 0.98)
        autoEditor:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        autoEditor:SetFrameStrata("DIALOG")
        autoEditor:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
        autoEditor:EnableMouse(true)
        autoEditor:Hide()

        local autoEditIdx = nil
        local autoEdTitle = autoEditor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        autoEdTitle:SetPoint("TOPLEFT", 12, -12)

        local spellIdLabel = autoEditor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        spellIdLabel:SetPoint("TOPLEFT", 12, -38)
        spellIdLabel:SetText(L["COMMON_LABEL_SPELLID"])

        local spellIdBox = CreateFrame("EditBox", nil, autoEditor, "InputBoxTemplate")
        spellIdBox:SetSize(120, 22)
        spellIdBox:SetPoint("LEFT", spellIdLabel, "RIGHT", 8, 0)
        spellIdBox:SetAutoFocus(false)
        spellIdBox:SetNumeric(true)

        local spellPreview = autoEditor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        spellPreview:SetPoint("LEFT", spellIdBox, "RIGHT", 8, 0)
        spellPreview:SetWidth(180)
        spellPreview:SetJustifyH("LEFT")

        local function UpdateSpellPreview()
            local id = tonumber(spellIdBox:GetText())
            if id and id > 0 then
                local info = C_Spell and C_Spell.GetSpellInfo(id)
                if info and info.name then
                    spellPreview:SetText(W.Colorize(info.name, C.ORANGE))
                else
                    spellPreview:SetText(W.Colorize("(unknown spell)", C.RED))
                end
            else
                spellPreview:SetText("")
            end
        end
        spellIdBox:SetScript("OnTextChanged", UpdateSpellPreview)

        local emoteLabel = autoEditor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        emoteLabel:SetPoint("TOPLEFT", 12, -68)
        emoteLabel:SetText(L["EMOTE_TEXT"])

        local emoteBox = CreateFrame("EditBox", nil, autoEditor, "InputBoxTemplate")
        emoteBox:SetSize(280, 22)
        emoteBox:SetPoint("LEFT", emoteLabel, "RIGHT", 8, 0)
        emoteBox:SetAutoFocus(false)
        emoteBox:SetMaxLetters(255)

        local emoteHint = autoEditor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        emoteHint:SetPoint("TOPLEFT", 12, -95)
        emoteHint:SetTextColor(0.5, 0.5, 0.5)
        emoteHint:SetText(L["EMOTE_TEXT_HINT"])

        local autoSaveBtn = W:CreateButton(autoEditor, { text = L["COMMON_SAVE"], width = 70, height = 24 })
        autoSaveBtn:SetPoint("BOTTOMLEFT", 12, 12)

        local autoCancelBtn = W:CreateButton(autoEditor, { text = L["COMMON_CANCEL"], width = 70, height = 24 })
        autoCancelBtn:SetPoint("LEFT", autoSaveBtn, "RIGHT", 8, 0)

        local BuildAutoEmoteList

        local function OpenAutoEditor(idx)
            autoEditIdx = idx
            if idx then
                local entry = db.autoEmotes[idx]
                autoEdTitle:SetText(L["EMOTE_POPUP_EDIT"])
                spellIdBox:SetText(tostring(entry.spellId or ""))
                emoteBox:SetText(entry.emoteText or "")
            else
                autoEdTitle:SetText(L["EMOTE_POPUP_NEW"])
                spellIdBox:SetText("")
                emoteBox:SetText("")
            end
            UpdateSpellPreview()
            autoEditor:Show()
        end

        local function CloseAutoEditor() autoEditor:Hide(); autoEditIdx = nil end
        autoCancelBtn:SetScript("OnClick", CloseAutoEditor)

        autoSaveBtn:SetScript("OnClick", function()
            local spellId = tonumber(spellIdBox:GetText())
            local emoteText = strtrim(emoteBox:GetText())

            if not spellId or spellId <= 0 then
                UIErrorsFrame:AddMessage("Spell ID required.", 1, 0.3, 0.3, 1, 3)
                return
            end
            if emoteText == "" then
                UIErrorsFrame:AddMessage("Emote text required.", 1, 0.3, 0.3, 1, 3)
                return
            end

            local entry = { spellId = spellId, emoteText = emoteText, enabled = true }

            if autoEditIdx then
                entry.enabled = db.autoEmotes[autoEditIdx].enabled
                db.autoEmotes[autoEditIdx] = entry
            else
                db.autoEmotes[#db.autoEmotes + 1] = entry
            end

            CloseAutoEditor()
            BuildAutoEmoteList()
            if ns.RebuildAutoEmoteLookup then ns.RebuildAutoEmoteLookup() end
        end)

        -- Pooled row frames
        local autoRowPool = {}
        local autoRowCount = 0
        local AUTO_ROW_BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }

        local function GetAutoRow()
            autoRowCount = autoRowCount + 1
            local r = autoRowPool[autoRowCount]
            if not r then
                r = CreateFrame("Frame", nil, autoListContainer, "BackdropTemplate")
                r:SetSize(400, 26)
                r:SetBackdrop(AUTO_ROW_BACKDROP)
                r:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
                r:SetBackdropBorderColor(0, 0, 0, 1)

                r.lbl = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                r.lbl:SetPoint("LEFT", 8, 0)
                r.lbl:SetWidth(220)
                r.lbl:SetJustifyH("LEFT")

                r.del = W:CreateButton(r, { text = "|cffff0000X|r", width = 22, height = 20 })
                r.del:SetPoint("RIGHT", -5, 0)

                r.tog = W:CreateButton(r, { text = "", width = 28, height = 20 })
                r.tog:SetPoint("RIGHT", r.del, "LEFT", -4, 0)

                r.edit = W:CreateButton(r, { text = L["COMMON_EDIT"], width = 40, height = 20 })
                r.edit:SetPoint("RIGHT", r.tog, "LEFT", -4, 0)

                autoRowPool[autoRowCount] = r
            end
            return r
        end

        local addAutoBtn = W:CreateButton(autoListContainer, { text = L["EMOTE_ADD"], width = 120, height = 24, onClick = function() OpenAutoEditor(nil) end })

        local emptyAutoLabel = autoListContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        emptyAutoLabel:SetText(W.Colorize(L["EMOTE_NO_AUTO"], C.GRAY))

        BuildAutoEmoteList = function()
            for idx = 1, autoRowCount do autoRowPool[idx]:Hide() end
            autoRowCount = 0
            emptyAutoLabel:Hide()

            db.autoEmotes = db.autoEmotes or {}

            local yOff = 0

            if #db.autoEmotes == 0 then
                emptyAutoLabel:ClearAllPoints()
                emptyAutoLabel:SetPoint("TOPLEFT", 0, 0)
                emptyAutoLabel:Show()
                yOff = yOff - 20
            else
                for i, entry in ipairs(db.autoEmotes) do
                    local row = GetAutoRow()
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", 0, yOff)

                    local spellName = ""
                    local info = C_Spell and C_Spell.GetSpellInfo(entry.spellId)
                    if info and info.name then spellName = info.name end

                    local clr = (entry.enabled == false) and "|cff666666" or ""
                    row.lbl:SetText(clr .. spellName .. " " .. W.Colorize("[" .. entry.spellId .. "]", C.GRAY))

                    row.del:SetScript("OnClick", function()
                        table.remove(db.autoEmotes, i)
                        CloseAutoEditor()
                        BuildAutoEmoteList()
                        if ns.RebuildAutoEmoteLookup then ns.RebuildAutoEmoteLookup() end
                    end)

                    row.tog:SetText(entry.enabled ~= false and W.Colorize("ON", C.GREEN) or W.Colorize("OFF", C.RED))
                    row.tog:SetScript("OnClick", function()
                        entry.enabled = not (entry.enabled ~= false)
                        BuildAutoEmoteList()
                        if ns.RebuildAutoEmoteLookup then ns.RebuildAutoEmoteLookup() end
                    end)

                    row.edit:SetScript("OnClick", function()
                        OpenAutoEditor(i)
                    end)

                    row:Show()
                    yOff = yOff - 30
                end
            end

            addAutoBtn:ClearAllPoints()
            addAutoBtn:SetPoint("TOPLEFT", 0, yOff - 8)
            addAutoBtn:Show()

            autoListContainer:SetHeight(math.abs(yOff) + 40)
            autoContent:SetHeight(110 + math.abs(yOff) + 40 + 10)
            autoWrap:RecalcHeight()
            if RelayoutAll then RelayoutAll() end
        end

        BuildAutoEmoteList()

        autoContent:SetHeight(200)
        autoWrap:RecalcHeight()

        -- ============================================================
        -- Layout
        -- ============================================================

        local sectionList = { appWrap, filterWrap, soundWrap, autoWrap }

        RelayoutAll = function()
            for i, section in ipairs(sectionList) do
                section:ClearAllPoints()
                if i == 1 then
                    section:SetPoint("TOPLEFT", sections, "TOPLEFT", 0, 0)
                else
                    section:SetPoint("TOPLEFT", sectionList[i - 1], "BOTTOMLEFT", 0, -12)
                end
                section:SetPoint("RIGHT", sections, "RIGHT", 0, 0)
            end

            local totalH = 0
            if db.enabled then
                for _, s in ipairs(sectionList) do
                    totalH = totalH + s:GetHeight() + 12
                end
            end
            sections:SetHeight(math.max(totalH, 1))

            local scrollH = 75 + 62 + 10 + totalH + 40
            sc:SetHeight(math.max(scrollH, 800))
        end

        masterCB:HookScript("OnClick", function(self)
            db.enabled = self:GetChecked() and true or false
            refreshDisplay()
            unlockCB:SetShown(db.enabled)
            sections:SetShown(db.enabled)
            RelayoutAll()
        end)
        sections:SetShown(db.enabled)

        -- Restore defaults button
        local restoreBtn = W:CreateRestoreDefaultsButton({
            moduleName = "emoteDetection",
            parent = sc,
            initFunc = function() ns:InitEmoteDetection() end,
            onRestore = function()
                if cache.edFrame then
                    cache.edFrame:Hide()
                    cache.edFrame:SetParent(nil)
                    cache.edFrame = nil
                end
                if display then display:UpdateDisplay() end
            end
        })
        restoreBtn:SetPoint("BOTTOMLEFT", sc, "BOTTOMLEFT", 10, 20)

        RelayoutAll()
    end)
end
