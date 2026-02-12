local addonName, ns = ...
local L = ns.L

local CLASS_LIST = {
    "ALL", "DEATHKNIGHT", "DEMONHUNTER", "DRUID", "EVOKER",
    "HUNTER", "MAGE", "MONK", "PALADIN", "PRIEST",
    "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR",
}

local cache = {}
local W = ns.Widgets
local C = ns.COLORS

local function PlaceSlider(slider, parent, x, y)
    local frame = slider:GetParent()
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    return slider
end

function ns:InitBuffMonitor()
    local p = ns.MainFrame.Content
    local db = NaowhQOL.buffMonitor

    local function refresh() if ns.RefreshBuffMonitor then ns:RefreshBuffMonitor() end end

    W:CachedPanel(cache, "bmFrame", p, function(f)
        local sf, sc = W:CreateScrollFrame(f, 1200)

        W:CreatePageHeader(sc,
            {{"BUFF ", C.BLUE}, {"MONITOR", C.ORANGE}},
            W.Colorize(L["BUFFMONITOR_SUBTITLE"], C.GRAY))

        -- Disclaimer at top of page
        local disc = sc:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        disc:SetPoint("TOPLEFT", 10, -62)
        disc:SetWidth(440)
        disc:SetJustifyH("LEFT")
        disc:SetText(W.Colorize(L["BUFFMONITOR_NOTE"], C.RED) .. " " .. L["BUFFMONITOR_DISCLAIMER"])

        local RelayoutAll

        -- ============================================================
        -- CUSTOM BUFF MONITOR
        -- ============================================================

        local killArea = CreateFrame("Frame", nil, sc, "BackdropTemplate")
        killArea:SetSize(460, 62)
        killArea:SetPoint("TOPLEFT", 10, -100)
        killArea:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
        killArea:SetBackdropColor(0.01, 0.56, 0.91, 0.08)

        local masterCB = W:CreateCheckbox(killArea, {
            label = L["BUFFMONITOR_ENABLE"],
            db = db, key = "enabled",
            x = 15, y = -8,
            isMaster = true,
        })

        local unlockCB = W:CreateCheckbox(killArea, {
            label = L["COMMON_UNLOCK"],
            db = db, key = "unlock",
            x = 15, y = -38,
            template = "ChatConfigCheckButtonTemplate",
            onChange = function(val) ns:SetBuffMonitorUnlock(val) end,
        })
        unlockCB:SetShown(db.enabled)

        -- Custom sections container
        local customSections = CreateFrame("Frame", nil, sc)
        customSections:SetPoint("TOPLEFT", killArea, "BOTTOMLEFT", 0, -10)
        customSections:SetPoint("RIGHT", sc, "RIGHT", -10, 0)
        customSections:SetHeight(600)

        ---------------------------------------------------------------
        -- CUSTOM TRACKER DISPLAY
        ---------------------------------------------------------------
        local customWrap, customContent = W:CreateCollapsibleSection(customSections, {
            text = L["BUFFMONITOR_SECTION_CUSTOM_DISPLAY"] or "Custom Tracker Display",
            startOpen = false,
            onCollapse = function() if RelayoutAll then RelayoutAll() end end,
        })

        local G2 = ns.Layout:New(2)  -- 2-column grid

        -- Row 1: Icon Size / Label Font Size
        local iconSlider = W:CreateAdvancedSlider(customContent,
            W.Colorize(L["BUFFMONITOR_CUSTOM_ICONSIZE"], C.ORANGE), 20, 80, G2:Row(1), 1, false,
            function(val) db.iconSize = val; refresh() end,
            { db = db, key = "iconSize", moduleName = "buffMonitor" })
        PlaceSlider(iconSlider, customContent, G2:Col(1), G2:Row(1))

        local customLabelSlider = W:CreateAdvancedSlider(customContent,
            W.Colorize(L["BUFFMONITOR_LABEL_FONTSIZE"], C.ORANGE), 6, 18, G2:Row(1), 1, false,
            function(val) db.customLabelFontSize = val; refresh() end,
            { db = db, key = "customLabelFontSize", moduleName = "buffMonitor" })
        PlaceSlider(customLabelSlider, customContent, G2:Col(2), G2:Row(1))

        -- Row 2: Label Color / Label Opacity
        W:CreateColorPicker(customContent, {
            label = L["BUFFMONITOR_LABEL_COLOR"], db = db,
            rKey = "customLabelColorR", gKey = "customLabelColorG", bKey = "customLabelColorB",
            x = G2:Col(1), y = G2:ColorY(2),
            onChange = refresh
        })

        local customLabelAlphaSlider = W:CreateAdvancedSlider(customContent,
            W.Colorize(L["BUFFMONITOR_LABEL_OPACITY"], C.ORANGE), 0, 100, G2:SliderY(2), 5, true,
            function(val) db.customLabelAlpha = val / 100; refresh() end,
            { value = (db.customLabelAlpha or 1.0) * 100 })
        PlaceSlider(customLabelAlphaSlider, customContent, G2:Col(2), G2:SliderY(2))

        -- Row 3: Timer Font Size / Timer Opacity
        local customTimerSlider = W:CreateAdvancedSlider(customContent,
            W.Colorize(L["BUFFMONITOR_TIMER_FONTSIZE"], C.ORANGE), 8, 20, G2:Row(3), 1, false,
            function(val) db.customTimerFontSize = val; refresh() end,
            { db = db, key = "customTimerFontSize", moduleName = "buffMonitor" })
        PlaceSlider(customTimerSlider, customContent, G2:Col(1), G2:SliderY(3))

        local customTimerAlphaSlider = W:CreateAdvancedSlider(customContent,
            W.Colorize(L["BUFFMONITOR_TIMER_OPACITY"], C.ORANGE), 0, 100, G2:SliderY(3), 5, true,
            function(val) db.customTimerAlpha = val / 100; refresh() end,
            { value = (db.customTimerAlpha or 1.0) * 100 })
        PlaceSlider(customTimerAlphaSlider, customContent, G2:Col(2), G2:SliderY(3))

        customContent:SetHeight(G2:Height(3))
        customWrap:RecalcHeight()

        ---------------------------------------------------------------
        -- CUSTOM BUFF TRACKERS
        ---------------------------------------------------------------
        local trkWrap, trkContent = W:CreateCollapsibleSection(customSections, {
            text = L["BUFFMONITOR_SECTION_CUSTOM"],
            startOpen = false,
            onCollapse = function() if RelayoutAll then RelayoutAll() end end,
        })

        local trackerDesc = trkContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        trackerDesc:SetPoint("TOPLEFT", 10, -5)
        trackerDesc:SetWidth(420)
        trackerDesc:SetJustifyH("LEFT")
        trackerDesc:SetText(W.Colorize(L["BUFFMONITOR_CUSTOM_DESC"], C.GRAY))

        local listContainer = CreateFrame("Frame", nil, trkContent)
        listContainer:SetPoint("TOPLEFT", 10, -25)
        listContainer:SetSize(430, 1)

        -- Editor popup (centered overlay, hidden by default)
        local editor = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        editor:SetSize(430, 400)
        editor:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14 })
        editor:SetBackdropColor(0.08, 0.08, 0.08, 0.98)
        editor:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        editor:SetFrameStrata("DIALOG")
        editor:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
        editor:EnableMouse(true)
        editor:Hide()

        local editIdx = nil
        local edTitle = editor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        edTitle:SetPoint("TOPLEFT", 12, -12)

        local nameBox = CreateFrame("EditBox", nil, editor, "InputBoxTemplate")
        nameBox:SetSize(200, 22)
        nameBox:SetPoint("TOPLEFT", 60, -34)
        nameBox:SetAutoFocus(false)
        local nl = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nl:SetPoint("TOPLEFT", 12, -38)
        nl:SetText(L["COMMON_LABEL_NAME"])

        local selectedClass = "ALL"
        local classDrop = CreateFrame("Frame", "NaowhBMClassDrop", editor, "UIDropDownMenuTemplate")
        classDrop:SetPoint("TOPLEFT", 42, -58)
        UIDropDownMenu_SetWidth(classDrop, 130)
        local cl = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        cl:SetPoint("TOPLEFT", 12, -66)
        cl:SetText(L["BUFFMONITOR_CLASS"])
        local function InitClassDrop()
            UIDropDownMenu_Initialize(classDrop, function()
                for _, c in ipairs(CLASS_LIST) do
                    UIDropDownMenu_AddButton({ text = c, checked = (c == selectedClass), func = function()
                        selectedClass = c; UIDropDownMenu_SetText(classDrop, c)
                    end })
                end
            end)
            UIDropDownMenu_SetText(classDrop, selectedClass)
        end

        local exclCB = W:CreateCheckbox(editor, {
            label = L["BUFFMONITOR_EXCLUSIVE"],
            x = 12, y = -90,
            checked = true,
            template = "chat",
        })

        local matchLabel = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        matchLabel:SetPoint("TOPLEFT", 12, -115)
        matchLabel:SetText(L["COMMON_MATCH_BY"])

        local trkSelectedMatchType = "spellId"
        local RefreshTrkPreview
        local matchSpellBtn = W:CreateButton(editor, { text = L["COMMON_LABEL_SPELLID"], width = 80 })
        matchSpellBtn:SetPoint("TOPLEFT", 70, -111)
        local matchNameBtn = W:CreateButton(editor, { text = L["COMMON_BUFF_NAME"], width = 80 })
        matchNameBtn:SetPoint("LEFT", matchSpellBtn, "RIGHT", 4, 0)

        local function UpdateTrkMatchButtons()
            if trkSelectedMatchType == "spellId" then
                matchSpellBtn:SetText(W.Colorize(L["COMMON_LABEL_SPELLID"], C.ORANGE))
                matchNameBtn:SetText(L["COMMON_BUFF_NAME"])
            else
                matchSpellBtn:SetText(L["COMMON_LABEL_SPELLID"])
                matchNameBtn:SetText(W.Colorize(L["COMMON_BUFF_NAME"], C.ORANGE))
            end
            if RefreshTrkPreview then RefreshTrkPreview() end
        end
        matchSpellBtn:SetScript("OnClick", function()
            trkSelectedMatchType = "spellId"; UpdateTrkMatchButtons()
        end)
        matchNameBtn:SetScript("OnClick", function()
            trkSelectedMatchType = "name"; UpdateTrkMatchButtons()
        end)
        UpdateTrkMatchButtons()

        local sl = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        sl:SetPoint("TOPLEFT", 12, -143)
        sl:SetText(L["COMMON_ENTRIES_COMMA"])
        local spellBox = CreateFrame("EditBox", nil, editor, "InputBoxTemplate")
        spellBox:SetSize(400, 22)
        spellBox:SetPoint("TOPLEFT", 12, -160)
        spellBox:SetAutoFocus(false)

        local trkPreview = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        trkPreview:SetPoint("TOPLEFT", 12, -185)
        trkPreview:SetWidth(410)
        trkPreview:SetJustifyH("LEFT")
        trkPreview:SetWordWrap(true)
        trkPreview:SetMaxLines(3)

        RefreshTrkPreview = function()
            local raw = strtrim(spellBox:GetText())
            if raw == "" then
                if trkSelectedMatchType == "name" then
                    trkPreview:SetText(W.Colorize(L["COMMON_HINT_PARTIAL_MATCH"], C.GRAY))
                else
                    trkPreview:SetText("")
                end
                return
            end
            if trkSelectedMatchType == "spellId" then
                local parts = {}
                for num in raw:gmatch("%d+") do
                    local id = tonumber(num)
                    local info = id and C_Spell and C_Spell.GetSpellInfo(id)
                    local name = info and info.name
                    parts[#parts + 1] = name
                        and (W.Colorize(tostring(id), C.GRAY) .. " = " .. W.Colorize(name, C.ORANGE))
                        or (W.Colorize(tostring(id), C.RED) .. " (unknown)")
                end
                trkPreview:SetText(table.concat(parts, ", "))
            elseif trkSelectedMatchType == "name" then
                trkPreview:SetText(W.Colorize(L["COMMON_HINT_PARTIAL_MATCH"], C.GRAY))
            end
        end
        spellBox:SetScript("OnTextChanged", RefreshTrkPreview)

        local threshLabel = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        threshLabel:SetPoint("TOPLEFT", 12, -218)
        threshLabel:SetText("Alert thresholds (minutes):")

        local function MakeMinBox(parent, label, x, y)
            local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            lbl:SetPoint("TOPLEFT", x, y)
            lbl:SetText(label .. ":")
            local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
            box:SetSize(45, 20)
            box:SetPoint("LEFT", lbl, "RIGHT", 4, 0)
            box:SetAutoFocus(false)
            box:SetNumeric(true)
            box:SetMaxLetters(3)
            return box
        end
        local dBox = MakeMinBox(editor, L["COMMON_THRESHOLD_DUNGEON"], 12, -235)
        local rBox = MakeMinBox(editor, L["COMMON_THRESHOLD_RAID"], 145, -235)
        local oBox = MakeMinBox(editor, L["COMMON_THRESHOLD_OTHER"], 260, -235)

        -- Per-tracker difficulty filters
        local diffEnabledCB = W:CreateCheckbox(editor, {
            label = L["BUFFMONITOR_FILTER_DIFFICULTY"],
            x = 12, y = -262,
            template = "chat",
        })

        local DIFF_DEFS = {
            { label = L["COMMON_DIFF_NORMAL_DUNGEON"],  key = "diffNormalDungeon", x = 12,  y = -287 },
            { label = L["COMMON_DIFF_HEROIC_DUNGEON"],  key = "diffHeroicDungeon", x = 12,  y = -312 },
            { label = L["COMMON_DIFF_MYTHIC_DUNGEON"],  key = "diffMythicDungeon", x = 12,  y = -337 },
            { label = L["COMMON_DIFF_MYTHIC_KEYSTONE"], key = "diffMythicPlus",    x = 12,  y = -362 },
            { label = L["COMMON_DIFF_LFR"],             key = "diffLFR",           x = 220, y = -287 },
            { label = L["COMMON_DIFF_NORMAL_RAID"],     key = "diffNormalRaid",    x = 220, y = -312 },
            { label = L["COMMON_DIFF_HEROIC_RAID"],     key = "diffHeroicRaid",    x = 220, y = -337 },
            { label = L["COMMON_DIFF_MYTHIC_RAID"],     key = "diffMythicRaid",    x = 220, y = -362 },
        }

        local diffCBs = {}
        for _, d in ipairs(DIFF_DEFS) do
            local cb = W:CreateCheckbox(editor, {
                label = d.label,
                x = d.x, y = d.y,
                template = "chat",
            })
            diffCBs[d.key] = cb
        end

        local function SetDiffCheckboxVisibility(show)
            for _, cb in pairs(diffCBs) do cb:SetShown(show) end
        end
        diffEnabledCB:SetScript("OnClick", function(self)
            SetDiffCheckboxVisibility(self:GetChecked())
        end)

        local saveBtn = W:CreateButton(editor, { text = L["COMMON_SAVE"], width = 70 })
        saveBtn:SetPoint("BOTTOMLEFT", 12, 12)
        local cancelBtn = W:CreateButton(editor, { text = L["COMMON_CANCEL"], width = 70 })
        cancelBtn:SetPoint("LEFT", saveBtn, "RIGHT", 8, 0)

        local BuildTrackerList

        local function OpenEditor(idx)
            editIdx = idx
            if idx then
                local t = db.trackers[idx]
                edTitle:SetText(L["BUFFMONITOR_POPUP_EDIT"])
                nameBox:SetText(t.name or "")
                selectedClass = t.class or "ALL"
                exclCB:SetChecked(t.exclusive ~= false)
                trkSelectedMatchType = t.matchType or "spellId"
                UpdateTrkMatchButtons()
                local parts = {}
                for _, e in ipairs(t.entries or {}) do parts[#parts + 1] = tostring(e) end
                spellBox:SetText(table.concat(parts, ", "))
                dBox:SetText(tostring(math.floor((t.thresholdDungeon or 2400) / 60)))
                rBox:SetText(tostring(math.floor((t.thresholdRaid or 900) / 60)))
                oBox:SetText(tostring(math.floor((t.thresholdOpen or 300) / 60)))
                diffEnabledCB:SetChecked(t.diffEnabled or false)
                for _, d in ipairs(DIFF_DEFS) do
                    diffCBs[d.key]:SetChecked(t[d.key] ~= false)
                end
                SetDiffCheckboxVisibility(t.diffEnabled or false)
            else
                edTitle:SetText(L["BUFFMONITOR_POPUP_NEW"])
                nameBox:SetText("")
                selectedClass = "ALL"
                exclCB:SetChecked(true)
                trkSelectedMatchType = "spellId"
                UpdateTrkMatchButtons()
                spellBox:SetText("")
                dBox:SetText("40")
                rBox:SetText("15")
                oBox:SetText("5")
                diffEnabledCB:SetChecked(false)
                for _, d in ipairs(DIFF_DEFS) do
                    diffCBs[d.key]:SetChecked(true)
                end
                SetDiffCheckboxVisibility(false)
            end
            InitClassDrop()
            editor:Show()
        end

        local function CloseEditor() editor:Hide(); editIdx = nil end
        cancelBtn:SetScript("OnClick", CloseEditor)

        saveBtn:SetScript("OnClick", function()
            local name = strtrim(nameBox:GetText())
            if name == "" then name = L["BUFFMONITOR_UNNAMED"] end

            local entries = {}
            local raw = strtrim(spellBox:GetText())
            if trkSelectedMatchType == "spellId" then
                for num in raw:gmatch("%d+") do entries[#entries + 1] = tonumber(num) end
            else
                for part in raw:gmatch("[^,]+") do
                    local trimmed = strtrim(part)
                    if trimmed ~= "" then entries[#entries + 1] = trimmed end
                end
            end
            if #entries == 0 then
                UIErrorsFrame:AddMessage(L["COMMON_ERR_ENTRY_REQUIRED"], 1, 0.3, 0.3, 1, 3)
                return
            end

            local entry = {
                name = name, class = selectedClass, exclusive = exclCB:GetChecked(),
                matchType = trkSelectedMatchType,
                entries = entries,
                thresholdDungeon = math.max(1, tonumber(dBox:GetText()) or 40) * 60,
                thresholdRaid    = math.max(1, tonumber(rBox:GetText()) or 15) * 60,
                thresholdOpen    = math.max(1, tonumber(oBox:GetText()) or 5) * 60,
                diffEnabled = diffEnabledCB:GetChecked() and true or false,
            }
            for _, d in ipairs(DIFF_DEFS) do
                entry[d.key] = diffCBs[d.key]:GetChecked() and true or false
            end
            if editIdx then
                entry.disabled = db.trackers[editIdx].disabled
                db.trackers[editIdx] = entry
            else
                db.trackers[#db.trackers + 1] = entry
            end
            CloseEditor()
            BuildTrackerList()
            refresh()
        end)

        local collapsed = {}

        -- Frame pools for reusable list elements
        local headerPool, rowPool = {}, {}
        local headerCount, rowCount = 0, 0

        local function GetHeader()
            headerCount = headerCount + 1
            local h = headerPool[headerCount]
            if not h then
                h = CreateFrame("Button", nil, listContainer, "BackdropTemplate")
                h:SetSize(420, 24)
                h:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
                h:SetBackdropColor(0.15, 0.15, 0.15, 0.8)
                h.arrow = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                h.arrow:SetPoint("LEFT", 6, 0)
                h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                h.text:SetPoint("LEFT", 22, 0)
                headerPool[headerCount] = h
            end
            return h
        end

        local ROW_BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }

        local function GetRow()
            rowCount = rowCount + 1
            local r = rowPool[rowCount]
            if not r then
                r = CreateFrame("Frame", nil, listContainer, "BackdropTemplate")
                r:SetSize(400, 26)
                r:SetBackdrop(ROW_BACKDROP)
                r:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
                r:SetBackdropBorderColor(0, 0, 0, 1)
                r.lbl = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                r.lbl:SetPoint("LEFT", 8, 0)
                r.lbl:SetWidth(180)
                r.lbl:SetJustifyH("LEFT")
                r.del = W:CreateButton(r, { text = "|cffff0000X|r", width = 22, height = 20 })
                r.del:SetPoint("RIGHT", -5, 0)
                r.tog = W:CreateButton(r, { width = 28, height = 20 })
                r.tog:SetPoint("RIGHT", r.del, "LEFT", -4, 0)
                r.edit = W:CreateButton(r, { text = L["COMMON_EDIT"], width = 40, height = 20 })
                r.edit:SetPoint("RIGHT", r.tog, "LEFT", -4, 0)
                rowPool[rowCount] = r
            end
            return r
        end

        -- Shared "Add Tracker" button and empty-state label
        local addBtn = W:CreateButton(listContainer, { text = L["BUFFMONITOR_ADD_TRACKER"], onClick = function() OpenEditor(nil) end })

        local emptyLabel = listContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        emptyLabel:SetText(W.Colorize(L["BUFFMONITOR_NO_TRACKERS"], C.GRAY))

        BuildTrackerList = function()
            -- Return all pooled frames to available state
            for idx = 1, headerCount do headerPool[idx]:Hide() end
            for idx = 1, rowCount do rowPool[idx]:Hide() end
            headerCount, rowCount = 0, 0
            emptyLabel:Hide()

            db.trackers = db.trackers or {}

            local classOrder, byClass = {}, {}
            for i, t in ipairs(db.trackers) do
                local cls = t.class or "ALL"
                if not byClass[cls] then
                    byClass[cls] = {}
                    classOrder[#classOrder + 1] = cls
                end
                byClass[cls][#byClass[cls] + 1] = { idx = i, tracker = t }
            end

            local yOff = 0
            for _, cls in ipairs(classOrder) do
                local isCollapsed = collapsed[cls]
                local entries = byClass[cls]

                local header = GetHeader()
                header:ClearAllPoints()
                header:SetPoint("TOPLEFT", 0, yOff)
                header.arrow:SetText(isCollapsed and W.Colorize("+", C.ORANGE) or W.Colorize("-", C.ORANGE))
                header.text:SetText(W.Colorize(cls, C.ORANGE) .. " " .. W.Colorize("(" .. #entries .. ")", C.GRAY))
                header:SetScript("OnClick", function()
                    collapsed[cls] = not collapsed[cls]
                    BuildTrackerList()
                end)
                header:Show()
                yOff = yOff - 28

                if not isCollapsed then
                    for _, e in ipairs(entries) do
                        local trackerIdx, t = e.idx, e.tracker
                        local row = GetRow()
                        row:ClearAllPoints()
                        row:SetPoint("TOPLEFT", 20, yOff)
                        local matchTag = (t.matchType == "name") and "names" or "IDs"
                        local tag = (t.exclusive and "Excl" or "All") .. ", " .. #(t.entries or {}) .. " " .. matchTag
                        local clr = t.disabled and "|cff666666" or ""
                        row.lbl:SetText(clr .. (t.name or "?") .. " " .. W.Colorize("[" .. tag .. "]", C.GRAY))
                        row.del:SetScript("OnClick", function()
                            table.remove(db.trackers, trackerIdx)
                            CloseEditor()
                            BuildTrackerList()
                            refresh()
                        end)
                        row.tog:SetText(t.disabled and W.Colorize("OFF", C.RED) or W.Colorize("ON", C.GREEN))
                        row.tog:SetScript("OnClick", function()
                            t.disabled = not t.disabled
                            BuildTrackerList()
                            refresh()
                        end)
                        row.edit:SetScript("OnClick", function()
                            OpenEditor(trackerIdx)
                        end)
                        row:Show()
                        yOff = yOff - 30
                    end
                end
            end

            if #db.trackers == 0 then
                emptyLabel:ClearAllPoints()
                emptyLabel:SetPoint("TOPLEFT", 0, 0)
                emptyLabel:Show()
                yOff = yOff - 20
            end

            addBtn:ClearAllPoints()
            addBtn:SetPoint("TOPLEFT", 0, yOff - 8)
            addBtn:Show()

            listContainer:SetHeight(math.abs(yOff) + 40)
            trkContent:SetHeight(25 + math.abs(yOff) + 40 + 10)
            trkWrap:RecalcHeight()
            if RelayoutAll then RelayoutAll() end
        end

        BuildTrackerList()
        cache.buildList = BuildTrackerList

        -- ============================================================
        -- RAID BUFFS
        -- ============================================================

        local raidKillArea = CreateFrame("Frame", nil, sc, "BackdropTemplate")
        raidKillArea:SetSize(460, 62)
        raidKillArea:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
        raidKillArea:SetBackdropColor(0.91, 0.56, 0.01, 0.08)

        local raidMasterCB = W:CreateCheckbox(raidKillArea, {
            label = L["BUFFMONITOR_ENABLE_RAIDBUFFS"],
            db = db, key = "raidBuffsEnabled",
            x = 15, y = -8,
            isMaster = true,
        })

        local raidUnlockCB = W:CreateCheckbox(raidKillArea, {
            label = L["BUFFMONITOR_UNLOCK_RAIDBUFFS"],
            db = db, key = "unlockRaid",
            x = 15, y = -38,
            template = "ChatConfigCheckButtonTemplate",
            onChange = function(val) ns:SetBuffMonitorRaidUnlock(val) end,
        })
        raidUnlockCB:SetShown(db.raidBuffsEnabled)

        local raidInstanceOnlyCB = W:CreateCheckbox(raidKillArea, {
            label = "Instance Only",
            db = db, key = "raidBuffsInstanceOnly",
            x = 200, y = -38,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refresh,
        })
        raidInstanceOnlyCB:SetShown(db.raidBuffsEnabled)

        -- Raid sections container
        local raidSections = CreateFrame("Frame", nil, sc)
        raidSections:SetPoint("RIGHT", sc, "RIGHT", -10, 0)
        raidSections:SetHeight(200)

        ---------------------------------------------------------------
        -- RAID BUFFS SETTINGS
        ---------------------------------------------------------------
        local raidWrap, raidContent = W:CreateCollapsibleSection(raidSections, {
            text = L["BUFFMONITOR_SECTION_RAIDBUFFS"],
            startOpen = false,
            onCollapse = function() if RelayoutAll then RelayoutAll() end end,
        })

        local raidDesc = raidContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        raidDesc:SetPoint("TOPLEFT", 10, -5)
        raidDesc:SetWidth(420)
        raidDesc:SetJustifyH("LEFT")
        raidDesc:SetText(W.Colorize(L["BUFFMONITOR_RAIDBUFF_DESC"], C.GRAY))

        local G = ns.Layout:New(2)  -- 2-column grid

        -- Row 1: Icon Size / Label Font Size
        local raidSlider = W:CreateAdvancedSlider(raidContent,
            W.Colorize(L["BUFFMONITOR_RAIDBUFF_ICONSIZE"], C.ORANGE), 20, 80, -25, 1, false,
            function(val) db.raidIconSize = val; refresh() end,
            { db = db, key = "raidIconSize", moduleName = "buffMonitor" })
        PlaceSlider(raidSlider, raidContent, G:Col(1), -25)

        local raidLabelSlider = W:CreateAdvancedSlider(raidContent,
            W.Colorize(L["BUFFMONITOR_LABEL_FONTSIZE"], C.ORANGE), 6, 18, -25, 1, false,
            function(val) db.raidLabelFontSize = val; refresh() end,
            { db = db, key = "raidLabelFontSize", moduleName = "buffMonitor" })
        PlaceSlider(raidLabelSlider, raidContent, G:Col(2), -25)

        -- Row 2: Label Color / Label Opacity
        W:CreateColorPicker(raidContent, {
            label = L["BUFFMONITOR_LABEL_COLOR"], db = db,
            rKey = "raidLabelColorR", gKey = "raidLabelColorG", bKey = "raidLabelColorB",
            x = G:Col(1), y = -75,
            onChange = refresh
        })

        local raidLabelAlphaSlider = W:CreateAdvancedSlider(raidContent,
            W.Colorize(L["BUFFMONITOR_LABEL_OPACITY"], C.ORANGE), 0, 100, -75, 5, true,
            function(val) db.raidLabelAlpha = val / 100; refresh() end,
            { value = (db.raidLabelAlpha or 1.0) * 100 })
        PlaceSlider(raidLabelAlphaSlider, raidContent, G:Col(2), -75)

        -- Row 3: Timer Font Size / Timer Opacity
        local raidTimerSlider = W:CreateAdvancedSlider(raidContent,
            W.Colorize(L["BUFFMONITOR_TIMER_FONTSIZE"], C.ORANGE), 8, 20, -125, 1, false,
            function(val) db.raidTimerFontSize = val; refresh() end,
            { db = db, key = "raidTimerFontSize", moduleName = "buffMonitor" })
        PlaceSlider(raidTimerSlider, raidContent, G:Col(1), -125)

        local raidTimerAlphaSlider = W:CreateAdvancedSlider(raidContent,
            W.Colorize(L["BUFFMONITOR_TIMER_OPACITY"], C.ORANGE), 0, 100, -125, 5, true,
            function(val) db.raidTimerAlpha = val / 100; refresh() end,
            { value = (db.raidTimerAlpha or 1.0) * 100 })
        PlaceSlider(raidTimerAlphaSlider, raidContent, G:Col(2), -125)

        raidContent:SetHeight(180)
        raidWrap:RecalcHeight()

        -- ============================================================
        -- Layout
        -- ============================================================

        local customSectionList = { customWrap, trkWrap }
        local raidSectionList = { raidWrap }

        RelayoutAll = function()
            -- Custom sections
            for i, section in ipairs(customSectionList) do
                section:ClearAllPoints()
                if i == 1 then
                    section:SetPoint("TOPLEFT", customSections, "TOPLEFT", 0, 0)
                else
                    section:SetPoint("TOPLEFT", customSectionList[i - 1], "BOTTOMLEFT", 0, -12)
                end
                section:SetPoint("RIGHT", customSections, "RIGHT", 0, 0)
            end

            local customH = 0
            if db.enabled then
                for _, s in ipairs(customSectionList) do
                    customH = customH + s:GetHeight() + 12
                end
            end
            customSections:SetHeight(math.max(customH, 1))

            -- Position raid kill area below custom sections
            raidKillArea:ClearAllPoints()
            raidKillArea:SetPoint("TOPLEFT", customSections, "BOTTOMLEFT", 0, -20)

            raidSections:ClearAllPoints()
            raidSections:SetPoint("TOPLEFT", raidKillArea, "BOTTOMLEFT", 0, -10)
            raidSections:SetPoint("RIGHT", sc, "RIGHT", -10, 0)

            -- Raid sections
            for i, section in ipairs(raidSectionList) do
                section:ClearAllPoints()
                if i == 1 then
                    section:SetPoint("TOPLEFT", raidSections, "TOPLEFT", 0, 0)
                else
                    section:SetPoint("TOPLEFT", raidSectionList[i - 1], "BOTTOMLEFT", 0, -12)
                end
                section:SetPoint("RIGHT", raidSections, "RIGHT", 0, 0)
            end

            local raidH = 0
            if db.raidBuffsEnabled then
                for _, s in ipairs(raidSectionList) do
                    raidH = raidH + s:GetHeight() + 12
                end
            end
            raidSections:SetHeight(math.max(raidH, 1))

            -- Total scroll height
            local totalH = 100 + 62 + 10 + customH + 20 + 62 + 10 + raidH + 40
            sc:SetHeight(math.max(totalH, 600))
        end

        masterCB:HookScript("OnClick", function(self)
            db.enabled = self:GetChecked() and true or false
            refresh()
            unlockCB:SetShown(db.enabled)
            customSections:SetShown(db.enabled)
            RelayoutAll()
        end)
        customSections:SetShown(db.enabled)

        raidMasterCB:HookScript("OnClick", function(self)
            db.raidBuffsEnabled = self:GetChecked() and true or false
            refresh()
            raidUnlockCB:SetShown(db.raidBuffsEnabled)
            raidInstanceOnlyCB:SetShown(db.raidBuffsEnabled)
            raidSections:SetShown(db.raidBuffsEnabled)
            RelayoutAll()
        end)
        raidSections:SetShown(db.raidBuffsEnabled)

        -- Restore defaults button
        local restoreBtn = W:CreateRestoreDefaultsButton({
            moduleName = "buffMonitor",
            parent = sc,
        })
        restoreBtn:SetPoint("BOTTOMLEFT", sc, "BOTTOMLEFT", 10, 20)

        -- Close popup editors when page is hidden (page switch / main frame close)
        cache.hideEditors = function()
            editor:Hide(); editIdx = nil
        end
        f:SetScript("OnHide", function() if cache.hideEditors then cache.hideEditors() end end)

        RelayoutAll()
    end)

    if cache.buildList then cache.buildList() end
end
