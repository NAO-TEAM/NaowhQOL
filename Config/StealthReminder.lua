local addonName, ns = ...
local L = ns.L

local cache = {}
local W = ns.Widgets
local C = ns.COLORS

function ns:InitStealthReminder()
    local p = ns.MainFrame.Content
    local db = NaowhQOL.stealthReminder
    local stealthDisplay = ns.StealthReminderDisplay
    local stanceDisplay = ns.StanceReminderDisplay

    -- Migrate old soundID format to new sound format
    if db.stanceSoundID and not db.stanceSound then
        db.stanceSound = { id = db.stanceSoundID }
    end

    W:CachedPanel(cache, "srFrame", p, function(f)
        local sf, sc = W:CreateScrollFrame(f, 800)

        W:CreatePageHeader(sc,
            {{"STEALTH", C.BLUE}, {"/ STANCE", C.ORANGE}},
            L["STEALTH_SUBTITLE"])

        local function refreshStealth() if stealthDisplay then stealthDisplay:UpdateDisplay() end end
        local function refreshStance() if stanceDisplay then stanceDisplay:UpdateDisplay() end end
        local function refreshAll() refreshStealth(); refreshStance() end

        -- ============================================================
        -- STEALTH REMINDER
        -- ============================================================

        local killArea = CreateFrame("Frame", nil, sc, "BackdropTemplate")
        killArea:SetSize(460, 62)
        killArea:SetPoint("TOPLEFT", 10, -75)
        killArea:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
        killArea:SetBackdropColor(0.01, 0.56, 0.91, 0.08)

        local masterCB = W:CreateCheckbox(killArea, {
            label = L["STEALTH_ENABLE"],
            db = db, key = "enabled",
            x = 15, y = -8,
            isMaster = true,
        })

        local unlockCB = W:CreateCheckbox(killArea, {
            label = L["COMMON_UNLOCK"],
            db = db, key = "unlock",
            x = 15, y = -38,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refreshStealth
        })
        unlockCB:SetShown(db.enabled)

        -- Stealth sections container
        local stealthSections = CreateFrame("Frame", nil, sc)
        stealthSections:SetPoint("TOPLEFT", killArea, "BOTTOMLEFT", 0, -10)
        stealthSections:SetPoint("RIGHT", sc, "RIGHT", -10, 0)
        stealthSections:SetHeight(300)

        local RelayoutAll

        -- APPEARANCE
        local appWrap, appContent = W:CreateCollapsibleSection(stealthSections, {
            text = L["COMMON_SECTION_APPEARANCE"],
            startOpen = false,
            onCollapse = function() if RelayoutAll then RelayoutAll() end end,
        })

        W:CreateFontPicker(appContent, 10, -5, db.font, function(path)
            db.font = path
            refreshAll()
        end)

        appContent:SetHeight(50)
        appWrap:RecalcHeight()

        -- SETTINGS
        local colWrap, colContent = W:CreateCollapsibleSection(stealthSections, {
            text = L["STEALTH_SECTION_STEALTH"],
            startOpen = false,
            onCollapse = function() if RelayoutAll then RelayoutAll() end end,
        })

        W:CreateCheckbox(colContent, {
            label = L["STEALTH_SHOW_STEALTHED"],
            db = db, key = "showStealthed",
            x = 10, y = -5,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refreshStealth
        })

        W:CreateCheckbox(colContent, {
            label = L["STEALTH_SHOW_NOT"],
            db = db, key = "showNotStealthed",
            x = 10, y = -29,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refreshStealth
        })

        W:CreateCheckbox(colContent, {
            label = L["STEALTH_DISABLE_RESTED"],
            db = db, key = "disableWhenRested",
            x = 10, y = -53,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refreshStealth
        })

        local G = ns.Layout:New(2)

        W:CreateColorPicker(colContent, {
            label = L["STEALTH_COLOR_STEALTHED"], db = db,
            rKey = "stealthR", gKey = "stealthG", bKey = "stealthB",
            x = G:Col(1), y = -79,
            onChange = refreshStealth
        })

        W:CreateColorPicker(colContent, {
            label = L["STEALTH_COLOR_NOT"], db = db,
            rKey = "warningR", gKey = "warningG", bKey = "warningB",
            x = G:Col(2), y = -79,
            onChange = refreshStealth
        })

        -- Stealth Text input
        local stealthTextLbl = colContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        stealthTextLbl:SetPoint("TOPLEFT", G:Col(1), -119)
        stealthTextLbl:SetText(L["STEALTH_TEXT"])

        local stealthTextBox = CreateFrame("EditBox", nil, colContent, "BackdropTemplate")
        stealthTextBox:SetSize(180, 24)
        stealthTextBox:SetPoint("LEFT", stealthTextLbl, "RIGHT", 8, 0)
        stealthTextBox:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]],
            edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
        stealthTextBox:SetBackdropColor(0, 0, 0, 1)
        stealthTextBox:SetBackdropBorderColor(0, 0, 0, 1)
        stealthTextBox:SetFontObject("GameFontHighlightSmall")
        stealthTextBox:SetAutoFocus(false)
        stealthTextBox:SetTextInsets(6, 6, 0, 0)
        stealthTextBox:SetMaxLetters(30)
        stealthTextBox:SetText(db.stealthText or L["STEALTH_DEFAULT"])
        stealthTextBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        stealthTextBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        stealthTextBox:SetScript("OnEditFocusLost", function(self)
            local val = strtrim(self:GetText())
            if val == "" then val = L["STEALTH_DEFAULT"]; self:SetText(val) end
            db.stealthText = val
            refreshStealth()
        end)

        -- Warning Text input
        local warningTextLbl = colContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        warningTextLbl:SetPoint("TOPLEFT", G:Col(1), -149)
        warningTextLbl:SetText(L["STEALTH_WARNING_TEXT"])

        local warningTextBox = CreateFrame("EditBox", nil, colContent, "BackdropTemplate")
        warningTextBox:SetSize(180, 24)
        warningTextBox:SetPoint("LEFT", warningTextLbl, "RIGHT", 8, 0)
        warningTextBox:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]],
            edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
        warningTextBox:SetBackdropColor(0, 0, 0, 1)
        warningTextBox:SetBackdropBorderColor(0, 0, 0, 1)
        warningTextBox:SetFontObject("GameFontHighlightSmall")
        warningTextBox:SetAutoFocus(false)
        warningTextBox:SetTextInsets(6, 6, 0, 0)
        warningTextBox:SetMaxLetters(30)
        warningTextBox:SetText(db.warningText or L["STEALTH_WARNING_DEFAULT"])
        warningTextBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        warningTextBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        warningTextBox:SetScript("OnEditFocusLost", function(self)
            local val = strtrim(self:GetText())
            if val == "" then val = L["STEALTH_WARNING_DEFAULT"]; self:SetText(val) end
            db.warningText = val
            refreshStealth()
        end)

        -- Druid options (child of stealth settings)
        local druidNote = colContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        druidNote:SetPoint("TOPLEFT", G:Col(1), -179)
        druidNote:SetText(L["STEALTH_DRUID_NOTE"])

        W:CreateCheckbox(colContent, {
            label = L["STEALTH_BALANCE"],
            db = db, key = "enableBalance",
            x = G:Col(1), y = -199,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refreshStealth
        })

        W:CreateCheckbox(colContent, {
            label = L["STEALTH_GUARDIAN"],
            db = db, key = "enableGuardian",
            x = G:Col(1), y = -223,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refreshStealth
        })

        W:CreateCheckbox(colContent, {
            label = L["STEALTH_RESTORATION"],
            db = db, key = "enableResto",
            x = G:Col(1), y = -247,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refreshStealth
        })

        colContent:SetHeight(279)
        colWrap:RecalcHeight()

        -- ============================================================
        -- STANCE CHECK
        -- ============================================================

        local stanceKillArea = CreateFrame("Frame", nil, sc, "BackdropTemplate")
        stanceKillArea:SetSize(460, 88)
        stanceKillArea:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
        stanceKillArea:SetBackdropColor(0.91, 0.56, 0.01, 0.08)

        local stanceMasterCB = W:CreateCheckbox(stanceKillArea, {
            label = L["STEALTH_ENABLE_STANCE"],
            db = db, key = "stanceEnabled",
            x = 15, y = -8,
            isMaster = true,
        })

        local stanceUnlockCB = W:CreateCheckbox(stanceKillArea, {
            label = L["COMMON_UNLOCK"],
            db = db, key = "stanceUnlock",
            x = 15, y = -38,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refreshStance
        })
        stanceUnlockCB:SetShown(db.stanceEnabled)

        local combatOnlyCB = W:CreateCheckbox(stanceKillArea, {
            label = L["COMMON_SECTION_BEHAVIOR"],
            db = db, key = "stanceCombatOnly",
            x = 15, y = -62,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refreshStance
        })
        combatOnlyCB:SetShown(db.stanceEnabled)

        local stanceRestedCB = W:CreateCheckbox(stanceKillArea, {
            label = L["STEALTH_DISABLE_RESTED"],
            db = db, key = "stanceDisableWhenRested",
            x = 200, y = -62,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refreshStance
        })
        stanceRestedCB:SetShown(db.stanceEnabled)

        -- Stance sections container
        local stanceSections = CreateFrame("Frame", nil, sc)
        stanceSections:SetPoint("RIGHT", sc, "RIGHT", -10, 0)
        stanceSections:SetHeight(200)

        -- STANCE ALERTS
        local stColWrap, stColContent = W:CreateCollapsibleSection(stanceSections, {
            text = L["STEALTH_SECTION_STANCE"],
            startOpen = false,
            onCollapse = function() if RelayoutAll then RelayoutAll() end end,
        })

        W:CreateColorPicker(stColContent, {
            label = L["STEALTH_WRONG_COLOR"], db = db,
            rKey = "stanceWarnR", gKey = "stanceWarnG", bKey = "stanceWarnB",
            x = 10, y = -5,
            onChange = refreshStance
        })

        -- Wrong Stance Text input
        local stanceTextLbl = stColContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        stanceTextLbl:SetPoint("TOPLEFT", 10, -45)
        stanceTextLbl:SetText(L["STEALTH_WARNING_TEXT"])

        local stanceTextBox = CreateFrame("EditBox", nil, stColContent, "BackdropTemplate")
        stanceTextBox:SetSize(180, 24)
        stanceTextBox:SetPoint("LEFT", stanceTextLbl, "RIGHT", 8, 0)
        stanceTextBox:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]],
            edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
        stanceTextBox:SetBackdropColor(0, 0, 0, 1)
        stanceTextBox:SetBackdropBorderColor(0, 0, 0, 1)
        stanceTextBox:SetFontObject("GameFontHighlightSmall")
        stanceTextBox:SetAutoFocus(false)
        stanceTextBox:SetTextInsets(6, 6, 0, 0)
        stanceTextBox:SetMaxLetters(30)
        stanceTextBox:SetText(db.stanceWarnText or L["STEALTH_STANCE_DEFAULT"])
        stanceTextBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        stanceTextBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        stanceTextBox:SetScript("OnEditFocusLost", function(self)
            local val = strtrim(self:GetText())
            if val == "" then val = L["STEALTH_STANCE_DEFAULT"]; self:SetText(val) end
            db.stanceWarnText = val
            refreshStance()
        end)

        W:CreateCheckbox(stColContent, {
            label = L["STEALTH_ENABLE_SOUND"],
            db = db, key = "stanceSoundEnabled",
            x = 10, y = -80,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refreshStance
        })

        W:CreateSoundPicker(stColContent, 10, -110, db.stanceSound or { id = 8959 },
            function(entry) db.stanceSound = entry.id and { id = entry.id } or { path = entry.path } end)

        local intervalSlider = W:CreateAdvancedSlider(stColContent, L["STEALTH_REPEAT"], 0, 15, -155, 1, false,
            function(val) db.stanceSoundInterval = val end,
            { db = db, key = "stanceSoundInterval", moduleName = "stealthReminder" })

        stColContent:SetHeight(200)
        stColWrap:RecalcHeight()

        -- ============================================================
        -- Layout
        -- ============================================================

        local stealthSectionList = { appWrap, colWrap }
        local stanceSectionList = { stColWrap }

        RelayoutAll = function()
            -- Stealth sections
            for i, section in ipairs(stealthSectionList) do
                section:ClearAllPoints()
                if i == 1 then
                    section:SetPoint("TOPLEFT", stealthSections, "TOPLEFT", 0, 0)
                else
                    section:SetPoint("TOPLEFT", stealthSectionList[i - 1], "BOTTOMLEFT", 0, -12)
                end
                section:SetPoint("RIGHT", stealthSections, "RIGHT", 0, 0)
            end

            local stealthH = 0
            if db.enabled then
                for _, s in ipairs(stealthSectionList) do
                    stealthH = stealthH + s:GetHeight() + 12
                end
            end
            stealthSections:SetHeight(math.max(stealthH, 1))

            -- Position stance kill area below stealth sections
            stanceKillArea:ClearAllPoints()
            stanceKillArea:SetPoint("TOPLEFT", stealthSections, "BOTTOMLEFT", 0, -20)

            stanceSections:ClearAllPoints()
            stanceSections:SetPoint("TOPLEFT", stanceKillArea, "BOTTOMLEFT", 0, -10)
            stanceSections:SetPoint("RIGHT", sc, "RIGHT", -10, 0)

            -- Stance sections
            for i, section in ipairs(stanceSectionList) do
                section:ClearAllPoints()
                if i == 1 then
                    section:SetPoint("TOPLEFT", stanceSections, "TOPLEFT", 0, 0)
                else
                    section:SetPoint("TOPLEFT", stanceSectionList[i - 1], "BOTTOMLEFT", 0, -12)
                end
                section:SetPoint("RIGHT", stanceSections, "RIGHT", 0, 0)
            end

            local stanceH = 0
            if db.stanceEnabled then
                for _, s in ipairs(stanceSectionList) do
                    stanceH = stanceH + s:GetHeight() + 12
                end
            end
            stanceSections:SetHeight(math.max(stanceH, 1))

            -- Total scroll height
            local totalH = 75 + 62 + 10 + stealthH + 20 + 88 + 10 + stanceH + 40
            sc:SetHeight(math.max(totalH, 800))
        end

        masterCB:SetScript("OnClick", function(self)
            db.enabled = self:GetChecked() and true or false
            refreshStealth()
            unlockCB:SetShown(db.enabled)
            stealthSections:SetShown(db.enabled)
            RelayoutAll()
        end)
        stealthSections:SetShown(db.enabled)

        stanceMasterCB:SetScript("OnClick", function(self)
            db.stanceEnabled = self:GetChecked() and true or false
            refreshStance()
            stanceUnlockCB:SetShown(db.stanceEnabled)
            combatOnlyCB:SetShown(db.stanceEnabled)
            stanceRestedCB:SetShown(db.stanceEnabled)
            stanceSections:SetShown(db.stanceEnabled)
            RelayoutAll()
        end)
        stanceSections:SetShown(db.stanceEnabled)

        -- Restore defaults button
        local restoreBtn = W:CreateRestoreDefaultsButton({
            moduleName = "stealthReminder",
            parent = sc,
            initFunc = function() ns:InitStealthReminder() end,
            onRestore = function()
                if cache.srFrame then
                    cache.srFrame:Hide()
                    cache.srFrame:SetParent(nil)
                    cache.srFrame = nil
                end
                if stealthDisplay then stealthDisplay:UpdateDisplay() end
                if stanceDisplay then stanceDisplay:UpdateDisplay() end
            end
        })
        restoreBtn:SetPoint("BOTTOMLEFT", sc, "BOTTOMLEFT", 10, 20)

        RelayoutAll()
    end)
end
