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

function ns:InitConsumableChecker()
    local p = ns.MainFrame.Content
    local db = NaowhQOL.consumableChecker

    local function refresh()
        if ns.RefreshConsumableChecker then ns:RefreshConsumableChecker() end
    end

    W:CachedPanel(cache, "ccFrame", p, function(f)
        local sf, sc = W:CreateScrollFrame(f, 1400)

        W:CreatePageHeader(sc,
            {{"CONSUMABLE ", C.BLUE}, {"CHECKER", C.ORANGE}},
            W.Colorize(L["CONSUMABLE_SUBTITLE"], C.GRAY))

        -- Disclaimer
        local disc = sc:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        disc:SetPoint("TOPLEFT", 10, -62)
        disc:SetWidth(440)
        disc:SetJustifyH("LEFT")
        disc:SetText(W.Colorize(L["CONSUMABLE_NOTE"], C.RED) .. " " .. L["CONSUMABLE_DISCLAIMER"]
            .. " " .. L["CONSUMABLE_CLICK_BLOCK"])

        -- Master toggle area
        local killArea = CreateFrame("Frame", nil, sc, "BackdropTemplate")
        killArea:SetSize(460, 62)
        killArea:SetPoint("TOPLEFT", 10, -100)
        killArea:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
        killArea:SetBackdropColor(0.01, 0.56, 0.91, 0.08)

        local masterCB = W:CreateCheckbox(killArea, {
            label = L["CONSUMABLE_ENABLE"],
            db = db, key = "enabled",
            x = 15, y = -8,
            isMaster = true,
        })

        local unlockCB = W:CreateCheckbox(killArea, {
            label = L["COMMON_UNLOCK"],
            db = db, key = "unlock",
            x = 15, y = -38,
            template = "ChatConfigCheckButtonTemplate",
            onChange = function(val) ns:SetConsumableCheckerUnlock(val) end,
        })
        unlockCB:SetShown(db.enabled)

        -- Section container
        local sectionContainer = CreateFrame("Frame", nil, sc)
        sectionContainer:SetPoint("TOPLEFT", killArea, "BOTTOMLEFT", 0, -10)
        sectionContainer:SetPoint("RIGHT", sc, "RIGHT", -10, 0)
        sectionContainer:SetHeight(900)

        local RelayoutSections

        ---------------------------------------------------------------
        -- SETTINGS
        ---------------------------------------------------------------
        local settingsWrap, settingsContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["COMMON_SECTION_SETTINGS"],
            startOpen = false,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local G = ns.Layout:New(2)  -- 2-column grid

        -- Row 1: Icon Size / Label Font Size
        local iconSlider = W:CreateAdvancedSlider(settingsContent,
            W.Colorize(L["COMMON_LABEL_ICON_SIZE"], C.ORANGE), 20, 80, G:Row(1), 1, false,
            function(val) db.iconSize = val; refresh() end,
            { db = db, key = "iconSize", moduleName = "consumableChecker" })
        PlaceSlider(iconSlider, settingsContent, G:Col(1), G:Row(1))

        local labelSlider = W:CreateAdvancedSlider(settingsContent,
            W.Colorize(L["COMMON_LABEL_FONT_SIZE"], C.ORANGE), 6, 18, G:Row(1), 1, false,
            function(val) db.labelFontSize = val; refresh() end,
            { db = db, key = "labelFontSize", moduleName = "consumableChecker" })
        PlaceSlider(labelSlider, settingsContent, G:Col(2), G:Row(1))

        -- Row 2: Timer Font Size / Label Color
        local timerSlider = W:CreateAdvancedSlider(settingsContent,
            W.Colorize(L["CONSUMABLE_TIMER_FONTSIZE"], C.ORANGE), 8, 20, G:Row(2), 1, false,
            function(val) db.timerFontSize = val; refresh() end,
            { db = db, key = "timerFontSize", moduleName = "consumableChecker" })
        PlaceSlider(timerSlider, settingsContent, G:Col(1), G:Row(2))

        W:CreateColorPicker(settingsContent, {
            label = L["BUFFMONITOR_LABEL_COLOR"], db = db,
            rKey = "labelColorR", gKey = "labelColorG", bKey = "labelColorB",
            x = G:Col(2), y = G:ColorY(2),
            onChange = refresh
        })

        -- Row 3: Stack Font Size / Stack Color
        local stackSlider = W:CreateAdvancedSlider(settingsContent,
            W.Colorize(L["CONSUMABLE_STACK_FONTSIZE"], C.ORANGE), 8, 20, G:Row(3), 1, false,
            function(val) db.stackFontSize = val; refresh() end,
            { db = db, key = "stackFontSize", moduleName = "consumableChecker" })
        PlaceSlider(stackSlider, settingsContent, G:Col(1), G:Row(3))

        W:CreateColorPicker(settingsContent, {
            label = L["CONSUMABLE_STACK_COLOR"], db = db,
            rKey = "stackColorR", gKey = "stackColorG", bKey = "stackColorB",
            x = G:Col(2), y = G:ColorY(3),
            onChange = refresh
        })

        -- Row 4: Stack Alpha
        local stackAlphaSlider = W:CreateAdvancedSlider(settingsContent,
            W.Colorize(L["CONSUMABLE_STACK_ALPHA"], C.ORANGE), 0, 1, G:Row(4), 0.1, false,
            function(val) db.stackAlpha = val; refresh() end,
            { db = db, key = "stackAlpha", moduleName = "consumableChecker" })
        PlaceSlider(stackAlphaSlider, settingsContent, G:Col(1), G:Row(4))

        settingsContent:SetHeight(G:Height(4))
        settingsWrap:RecalcHeight()

        ---------------------------------------------------------------
        -- DIFFICULTY FILTERS
        ---------------------------------------------------------------
        local diffWrap, diffContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["CONSUMABLE_SECTION_DIFFICULTY"],
            startOpen = false,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local diffDesc = diffContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        diffDesc:SetPoint("TOPLEFT", 10, -5)
        diffDesc:SetWidth(420)
        diffDesc:SetJustifyH("LEFT")
        diffDesc:SetText(W.Colorize(L["CONSUMABLE_DIFF_DESC"], C.GRAY))

        local diffChecks = {
            { label = L["COMMON_DIFF_NORMAL_DUNGEON"],  key = "normalDungeon", x = 10,  y = -25 },
            { label = L["COMMON_DIFF_HEROIC_DUNGEON"],  key = "heroicDungeon", x = 10,  y = -50 },
            { label = L["COMMON_DIFF_MYTHIC_DUNGEON"],  key = "mythicDungeon", x = 10,  y = -75 },
            { label = L["COMMON_DIFF_OTHER"],           key = "other",         x = 10,  y = -100 },
            { label = L["COMMON_DIFF_LFR"],             key = "lfr",           x = 230, y = -25 },
            { label = L["COMMON_DIFF_NORMAL_RAID"],     key = "normalRaid",    x = 230, y = -50 },
            { label = L["COMMON_DIFF_HEROIC_RAID"],     key = "heroicRaid",    x = 230, y = -75 },
            { label = L["COMMON_DIFF_MYTHIC_RAID"],     key = "mythicRaid",    x = 230, y = -100 },
        }
        for _, d in ipairs(diffChecks) do
            W:CreateCheckbox(diffContent, {
                label = d.label, db = db, key = d.key,
                x = d.x, y = d.y,
                template = "ChatConfigCheckButtonTemplate",
                onChange = refresh,
            })
        end

        diffContent:SetHeight(130)
        diffWrap:RecalcHeight()

        ---------------------------------------------------------------
        -- CONSUMABLE CATEGORIES
        ---------------------------------------------------------------
        local catWrap, catContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["CONSUMABLE_SECTION_CATEGORIES"],
            startOpen = false,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local catDesc = catContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        catDesc:SetPoint("TOPLEFT", 10, -5)
        catDesc:SetWidth(420)
        catDesc:SetJustifyH("LEFT")
        catDesc:SetText(W.Colorize(L["CONSUMABLE_CAT_DESC"], C.GRAY))
        catDesc:SetWidth(420)
        catDesc:SetJustifyH("LEFT")
        catDesc:SetText(W.Colorize(L["CONSUMABLE_CAT_DESC"], C.GRAY))

        local catListContainer = CreateFrame("Frame", nil, catContent)
        catListContainer:SetPoint("TOPLEFT", 10, -25)
        catListContainer:SetSize(430, 1)

        -- Category editor popup
        local catEditor = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        catEditor:SetSize(430, 580)
        catEditor:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14 })
        catEditor:SetBackdropColor(0.08, 0.08, 0.08, 0.98)
        catEditor:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        catEditor:SetFrameStrata("DIALOG")
        catEditor:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
        catEditor:EnableMouse(true)
        catEditor:Hide()

        local catEditIdx = nil
        local catEdTitle = catEditor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        catEdTitle:SetPoint("TOPLEFT", 12, -12)

        local catNl = catEditor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        catNl:SetPoint("TOPLEFT", 12, -38)
        catNl:SetText(L["COMMON_LABEL_NAME"])
        local catNameBox = CreateFrame("EditBox", nil, catEditor, "InputBoxTemplate")
        catNameBox:SetSize(200, 22)
        catNameBox:SetPoint("TOPLEFT", 60, -34)
        catNameBox:SetAutoFocus(false)

        -- Match type toggle
        local catEntriesLabel, catEntriesBox
        local RefreshCatPreview
        local catMatchLabel = catEditor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        catMatchLabel:SetPoint("TOPLEFT", 12, -62)
        catMatchLabel:SetText(L["COMMON_MATCH_BY"])

        local catSelectedMatchType = "spellId"
        local catMatchSpellBtn = W:CreateButton(catEditor, { text = L["COMMON_LABEL_SPELLID"]:gsub(":", ""), width = 80 })
        catMatchSpellBtn:SetPoint("TOPLEFT", 80, -58)
        local catMatchNameBtn = W:CreateButton(catEditor, { text = L["COMMON_BUFF_NAME"], width = 80 })
        catMatchNameBtn:SetPoint("LEFT", catMatchSpellBtn, "RIGHT", 4, 0)
        local catMatchEnchantBtn = W:CreateButton(catEditor, { text = L["CONSUMABLE_WEAPON_ENCH"], width = 90 })
        catMatchEnchantBtn:SetPoint("LEFT", catMatchNameBtn, "RIGHT", 4, 0)

        -- Weapon slot selector (shown only for weaponEnchant)
        local catSelectedWeaponSlot = 16
        local catSlotLabel = catEditor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        catSlotLabel:SetPoint("TOPLEFT", 12, -86)
        catSlotLabel:SetText(L["CONSUMABLE_WEAPON_SLOT"])
        local catSlotMHBtn = W:CreateButton(catEditor, { text = L["CONSUMABLE_MAIN_HAND"], width = 90 })
        catSlotMHBtn:SetPoint("TOPLEFT", 90, -82)
        local catSlotOHBtn = W:CreateButton(catEditor, { text = L["CONSUMABLE_OFF_HAND"], width = 90 })
        catSlotOHBtn:SetPoint("LEFT", catSlotMHBtn, "RIGHT", 4, 0)

        local function UpdateSlotButtons()
            catSlotMHBtn:SetText(catSelectedWeaponSlot == 16
                and W.Colorize(L["CONSUMABLE_MAIN_HAND"], C.ORANGE) or L["CONSUMABLE_MAIN_HAND"])
            catSlotOHBtn:SetText(catSelectedWeaponSlot == 17
                and W.Colorize(L["CONSUMABLE_OFF_HAND"], C.ORANGE) or L["CONSUMABLE_OFF_HAND"])
            if RefreshCatPreview then RefreshCatPreview() end
        end
        catSlotMHBtn:SetScript("OnClick", function()
            catSelectedWeaponSlot = 16; UpdateSlotButtons()
        end)
        catSlotOHBtn:SetScript("OnClick", function()
            catSelectedWeaponSlot = 17; UpdateSlotButtons()
        end)

        local function UpdateCatMatchButtons()
            local spellIdLabel = L["COMMON_LABEL_SPELLID"]:gsub(":", "")
            catMatchSpellBtn:SetText(catSelectedMatchType == "spellId"
                and W.Colorize(spellIdLabel, C.ORANGE) or spellIdLabel)
            catMatchNameBtn:SetText(catSelectedMatchType == "name"
                and W.Colorize(L["COMMON_BUFF_NAME"], C.ORANGE) or L["COMMON_BUFF_NAME"])
            catMatchEnchantBtn:SetText(catSelectedMatchType == "weaponEnchant"
                and W.Colorize(L["CONSUMABLE_WEAPON_ENCH"], C.ORANGE) or L["CONSUMABLE_WEAPON_ENCH"])

            local isEnchant = catSelectedMatchType == "weaponEnchant"
            -- Show/hide weapon slot selector vs entries field
            catSlotLabel:SetShown(isEnchant)
            catSlotMHBtn:SetShown(isEnchant)
            catSlotOHBtn:SetShown(isEnchant)
            catEntriesLabel:SetShown(not isEnchant)
            catEntriesBox:SetShown(not isEnchant)

            if not isEnchant then
                catEntriesLabel:SetText(L["COMMON_ENTRIES_COMMA"])
            end
            UpdateSlotButtons()
            if RefreshCatPreview then RefreshCatPreview() end
        end
        catMatchSpellBtn:SetScript("OnClick", function()
            catSelectedMatchType = "spellId"; UpdateCatMatchButtons()
        end)
        catMatchNameBtn:SetScript("OnClick", function()
            catSelectedMatchType = "name"; UpdateCatMatchButtons()
        end)
        catMatchEnchantBtn:SetScript("OnClick", function()
            catSelectedMatchType = "weaponEnchant"; UpdateCatMatchButtons()
        end)

        catEntriesLabel = catEditor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        catEntriesLabel:SetPoint("TOPLEFT", 12, -86)
        catEntriesLabel:SetText(L["COMMON_ENTRIES_COMMA"])
        catEntriesBox = CreateFrame("EditBox", nil, catEditor, "InputBoxTemplate")
        catEntriesBox:SetSize(400, 22)
        catEntriesBox:SetPoint("TOPLEFT", 12, -103)
        catEntriesBox:SetAutoFocus(false)
        UpdateCatMatchButtons()

        local catPreview = catEditor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        catPreview:SetPoint("TOPLEFT", 12, -128)
        catPreview:SetWidth(410)
        catPreview:SetJustifyH("LEFT")
        catPreview:SetWordWrap(true)
        catPreview:SetMaxLines(3)

        RefreshCatPreview = function()
            if catSelectedMatchType == "weaponEnchant" then
                local slotName = catSelectedWeaponSlot == 17 and L["CONSUMABLE_OFF_HAND"] or L["CONSUMABLE_MAIN_HAND"]
                catPreview:SetText(W.Colorize(L["CONSUMABLE_WEAPON_HINT"], C.GRAY))
                return
            end
            local raw = strtrim(catEntriesBox:GetText())
            if raw == "" then
                if catSelectedMatchType == "name" then
                    catPreview:SetText(W.Colorize(L["COMMON_HINT_PARTIAL_MATCH"], C.GRAY))
                else
                    catPreview:SetText("")
                end
                return
            end
            if catSelectedMatchType == "spellId" then
                local parts = {}
                for num in raw:gmatch("%d+") do
                    local id = tonumber(num)
                    local info = id and C_Spell and C_Spell.GetSpellInfo(id)
                    local name = info and info.name
                    parts[#parts + 1] = name
                        and (W.Colorize(tostring(id), C.GRAY) .. " = " .. W.Colorize(name, C.ORANGE))
                        or (W.Colorize(tostring(id), C.RED) .. " (unknown)")
                end
                catPreview:SetText(table.concat(parts, ", "))
            elseif catSelectedMatchType == "name" then
                catPreview:SetText(W.Colorize(L["COMMON_HINT_PARTIAL_MATCH"], C.GRAY))
            end
        end
        catEntriesBox:SetScript("OnTextChanged", RefreshCatPreview)

        -- Icon ID field
        local catIconLabel = catEditor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        catIconLabel:SetPoint("TOPLEFT", 12, -168)
        catIconLabel:SetText(L["CONSUMABLE_ICON_ID"])
        local catIconBox = CreateFrame("EditBox", nil, catEditor, "InputBoxTemplate")
        catIconBox:SetSize(120, 22)
        catIconBox:SetPoint("TOPLEFT", 70, -164)
        catIconBox:SetAutoFocus(false)
        catIconBox:SetNumeric(true)

        -- Item ID override for click-to-use
        local itemLabel = catEditor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        itemLabel:SetPoint("TOPLEFT", 12, -194)
        itemLabel:SetText(L["CONSUMABLE_ITEM_ID"])
        local itemBox = CreateFrame("EditBox", nil, catEditor, "InputBoxTemplate")
        itemBox:SetSize(120, 22)
        itemBox:SetPoint("TOPLEFT", 12, -211)
        itemBox:SetAutoFocus(false)
        itemBox:SetNumeric(true)

        local itemHint = catEditor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        itemHint:SetPoint("TOPLEFT", 140, -215)
        itemHint:SetWidth(270)
        itemHint:SetJustifyH("LEFT")
        itemHint:SetText(W.Colorize(L["CONSUMABLE_ITEM_HINT"], C.GRAY))

        -- Tracked Items section
        local trackedLabel = catEditor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        trackedLabel:SetPoint("TOPLEFT", 12, -240)
        trackedLabel:SetText(L["CONSUMABLE_TRACKED_ITEMS"])

        local trackedListFrame = CreateFrame("Frame", nil, catEditor, "BackdropTemplate")
        trackedListFrame:SetPoint("TOPLEFT", 12, -257)
        trackedListFrame:SetSize(406, 180)
        trackedListFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        trackedListFrame:SetBackdropColor(0, 0, 0, 0.3)

        local trackedScroll = CreateFrame("ScrollFrame", nil, trackedListFrame, "UIPanelScrollFrameTemplate")
        trackedScroll:SetPoint("TOPLEFT", 4, -4)
        trackedScroll:SetPoint("BOTTOMRIGHT", -24, 4)
        local trackedContent = CreateFrame("Frame", nil, trackedScroll)
        trackedContent:SetSize(375, 1)
        trackedScroll:SetScrollChild(trackedContent)

        local catCustomItems = {}
        local trackedRows = {}

        local function RefreshTrackedItemsList()
            for _, row in ipairs(trackedRows) do row:Hide() end
            local yOff = 0
            for i, itemId in ipairs(catCustomItems) do
                local row = trackedRows[i]
                if not row then
                    row = CreateFrame("Frame", nil, trackedContent)
                    row:SetSize(370, 20)
                    row.icon = row:CreateTexture(nil, "ARTWORK")
                    row.icon:SetSize(18, 18)
                    row.icon:SetPoint("LEFT", 2, 0)
                    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    row.text:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
                    row.text:SetWidth(290)
                    row.text:SetJustifyH("LEFT")
                    row.del = W:CreateButton(row, { text = "X", width = 20, height = 18 })
                    row.del:SetPoint("RIGHT", -2, 0)
                    trackedRows[i] = row
                end
                local itemInfo = GetItemInfoInstant(itemId)
                local tex = itemInfo and select(5, GetItemInfoInstant(itemId)) or nil
                local name = C_Item.GetItemInfo(itemId)
                row.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
                row.text:SetText(name or ("Item " .. itemId))
                -- Store the index locally to avoid closure issues
                local removeIdx = i
                row.del:SetScript("OnClick", function()
                    -- Validate index before removal
                    if removeIdx >= 1 and removeIdx <= #catCustomItems then
                        table.remove(catCustomItems, removeIdx)
                        RefreshTrackedItemsList()
                    end
                end)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, yOff)
                row:Show()
                yOff = yOff - 22
            end
            trackedContent:SetHeight(math.max(1, math.abs(yOff)))
        end

        -- Scan Bags button (created first so popup can reference it)
        local scanBagsBtn = W:CreateButton(catEditor, { text = L["CONSUMABLE_SCAN_BAGS"], width = 80 })
        scanBagsBtn:SetPoint("TOPLEFT", 12, -442)

        -- Scan results popup
        local scanPopup = CreateFrame("Frame", nil, catEditor, "BackdropTemplate")
        scanPopup:SetSize(250, 300)
        scanPopup:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
        scanPopup:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
        scanPopup:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        scanPopup:SetFrameStrata("TOOLTIP")
        scanPopup:Hide()

        local scanPopupTitle = scanPopup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        scanPopupTitle:SetPoint("TOP", 0, -8)
        scanPopupTitle:SetText(L["CONSUMABLE_SELECT_ITEM"])

        local scanPopupClose = CreateFrame("Button", nil, scanPopup, "UIPanelCloseButton")
        scanPopupClose:SetPoint("TOPRIGHT", -2, -2)
        scanPopupClose:SetScript("OnClick", function() scanPopup:Hide() end)

        local scanPopupScroll = CreateFrame("ScrollFrame", nil, scanPopup, "UIPanelScrollFrameTemplate")
        scanPopupScroll:SetPoint("TOPLEFT", 8, -28)
        scanPopupScroll:SetPoint("BOTTOMRIGHT", -28, 8)
        local scanPopupContent = CreateFrame("Frame", nil, scanPopupScroll)
        scanPopupContent:SetSize(210, 1)
        scanPopupScroll:SetScrollChild(scanPopupContent)

        local scanRows = {}

        local function ShowScanResults(items)
            for _, row in ipairs(scanRows) do row:Hide() end
            local yOff = 0
            for i, itemId in ipairs(items) do
                local row = scanRows[i]
                if not row then
                    row = CreateFrame("Button", nil, scanPopupContent)
                    row:SetSize(205, 22)
                    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
                    row.icon = row:CreateTexture(nil, "ARTWORK")
                    row.icon:SetSize(18, 18)
                    row.icon:SetPoint("LEFT", 2, 0)
                    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    row.text:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
                    row.text:SetWidth(175)
                    row.text:SetJustifyH("LEFT")
                    scanRows[i] = row
                end
                local itemInfo = GetItemInfoInstant(itemId)
                local tex = itemInfo and select(5, GetItemInfoInstant(itemId)) or nil
                local name = C_Item.GetItemInfo(itemId) or ("Item " .. itemId)
                row.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
                row.text:SetText(name)
                row:SetScript("OnClick", function()
                    catCustomItems[#catCustomItems + 1] = itemId
                    RefreshTrackedItemsList()
                    scanPopup:Hide()
                end)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, yOff)
                row:Show()
                yOff = yOff - 24
            end
            scanPopupContent:SetHeight(math.max(1, math.abs(yOff)))
            scanPopup:ClearAllPoints()
            scanPopup:SetPoint("TOPLEFT", scanBagsBtn, "BOTTOMLEFT", 0, -4)
            scanPopup:Show()
        end

        -- Scan Bags button click handler
        scanBagsBtn:SetScript("OnClick", function()
            local found = {}
            local seen = {}
            for _, id in ipairs(catCustomItems) do seen[id] = true end
            for bag = 0, 4 do
                local slots = C_Container.GetContainerNumSlots(bag)
                for slot = 1, slots do
                    local info = C_Container.GetContainerItemInfo(bag, slot)
                    if info and info.itemID and not seen[info.itemID] then
                        local _, _, _, _, _, classId = GetItemInfoInstant(info.itemID)
                        if classId == 0 then
                            found[#found + 1] = info.itemID
                            seen[info.itemID] = true
                        end
                    end
                end
            end
            if #found == 0 then
                UIErrorsFrame:AddMessage(L["CONSUMABLE_NO_BAGS"], 1, 0.8, 0, 1, 3)
                return
            end
            ShowScanResults(found)
        end)

        -- Manual add item
        local addItemLabel = catEditor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        addItemLabel:SetPoint("LEFT", scanBagsBtn, "RIGHT", 12, 0)
        addItemLabel:SetText(L["EMOTE_ID"])
        local addItemBox = CreateFrame("EditBox", nil, catEditor, "InputBoxTemplate")
        addItemBox:SetSize(70, 22)
        addItemBox:SetPoint("LEFT", addItemLabel, "RIGHT", 4, 0)
        addItemBox:SetAutoFocus(false)
        addItemBox:SetNumeric(true)
        local addItemBtn = W:CreateButton(catEditor, { text = L["COMMON_ADD"], width = 45, onClick = function()
            local id = tonumber(addItemBox:GetText())
            if id and id > 0 then
                for _, existing in ipairs(catCustomItems) do
                    if existing == id then
                        UIErrorsFrame:AddMessage(L["CONSUMABLE_ALREADY_ADDED"], 1, 0.8, 0, 1, 3)
                        return
                    end
                end
                catCustomItems[#catCustomItems + 1] = id
                addItemBox:SetText("")
                RefreshTrackedItemsList()
            end
        end })
        addItemBtn:SetPoint("LEFT", addItemBox, "RIGHT", 4, 0)

        -- Expiry warning thresholds (minutes)
        local threshLabel = catEditor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        threshLabel:SetPoint("TOPLEFT", 12, -470)
        threshLabel:SetText(L["CONSUMABLE_EXPIRY_THRESHOLDS"])

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
        local dBox = MakeMinBox(catEditor, L["COMMON_THRESHOLD_DUNGEON"], 12, -487)
        local rBox = MakeMinBox(catEditor, L["COMMON_THRESHOLD_RAID"], 145, -487)
        local oBox = MakeMinBox(catEditor, L["COMMON_THRESHOLD_OTHER"], 260, -487)

        -- Save / Cancel buttons
        local catSaveBtn = W:CreateButton(catEditor, { text = L["COMMON_SAVE"], width = 70 })
        catSaveBtn:SetPoint("BOTTOMLEFT", 12, 12)
        local catCancelBtn = W:CreateButton(catEditor, { text = L["COMMON_CANCEL"], width = 70 })
        catCancelBtn:SetPoint("LEFT", catSaveBtn, "RIGHT", 8, 0)

        local BuildCategoryList

        local function OpenCatEditor(idx)
            catEditIdx = idx
            -- Clear and rebuild customItems list
            for i = #catCustomItems, 1, -1 do catCustomItems[i] = nil end
            addItemBox:SetText("")

            if idx then
                local cat = db.categories[idx]
                catEdTitle:SetText(L["CONSUMABLE_POPUP_EDIT"])
                catNameBox:SetText(cat.name or "")
                catSelectedMatchType = cat.matchType or "spellId"
                catSelectedWeaponSlot = cat.weaponSlot or 16
                UpdateCatMatchButtons()
                local parts = {}
                for _, e in ipairs(cat.entries or {}) do parts[#parts + 1] = tostring(e) end
                catEntriesBox:SetText(table.concat(parts, ", "))
                catIconBox:SetText(tostring(cat.icon or ""))
                itemBox:SetText(cat.itemId and tostring(cat.itemId) or "")
                dBox:SetText(tostring(math.floor((cat.thresholdDungeon or 600) / 60)))
                rBox:SetText(tostring(math.floor((cat.thresholdRaid or 600) / 60)))
                oBox:SetText(tostring(math.floor((cat.thresholdOpen or 300) / 60)))
                -- Load existing customItems
                for _, id in ipairs(cat.customItems or {}) do
                    catCustomItems[#catCustomItems + 1] = id
                end
            else
                catEdTitle:SetText(L["CONSUMABLE_POPUP_NEW"])
                catNameBox:SetText("")
                catSelectedMatchType = "spellId"
                catSelectedWeaponSlot = 16
                UpdateCatMatchButtons()
                catEntriesBox:SetText("")
                catIconBox:SetText("")
                itemBox:SetText("")
                dBox:SetText("10")
                rBox:SetText("10")
                oBox:SetText("5")
            end
            RefreshTrackedItemsList()
            catEditor:Show()
            if BuildCategoryList then BuildCategoryList() end
        end

        local function CloseCatEditor()
            scanPopup:Hide()
            catEditor:Hide(); catEditIdx = nil
            if BuildCategoryList then BuildCategoryList() end
        end
        catCancelBtn:SetScript("OnClick", CloseCatEditor)

        catSaveBtn:SetScript("OnClick", function()
            local name = strtrim(catNameBox:GetText())
            if name == "" then name = L["CONSUMABLE_UNNAMED"] end

            local entries = {}
            local weaponSlot = nil

            if catSelectedMatchType == "weaponEnchant" then
                -- Weapon enchant uses weaponSlot, not entries
                weaponSlot = catSelectedWeaponSlot
            elseif catSelectedMatchType == "spellId" then
                local raw = strtrim(catEntriesBox:GetText())
                for num in raw:gmatch("%d+") do
                    entries[#entries + 1] = tonumber(num)
                end
                if #entries == 0 then
                    UIErrorsFrame:AddMessage(L["COMMON_ERR_SPELLID_REQUIRED"], 1, 0.3, 0.3, 1, 3)
                    return
                end
            else
                local raw = strtrim(catEntriesBox:GetText())
                for part in raw:gmatch("[^,]+") do
                    local trimmed = strtrim(part)
                    if trimmed ~= "" then
                        entries[#entries + 1] = trimmed
                    end
                end
                if #entries == 0 then
                    UIErrorsFrame:AddMessage(L["COMMON_ERR_ENTRY_REQUIRED"], 1, 0.3, 0.3, 1, 3)
                    return
                end
            end

            local iconId = tonumber(catIconBox:GetText()) or 0
            local overrideItemId = tonumber(itemBox:GetText())
            if overrideItemId and overrideItemId <= 0 then overrideItemId = nil end

            -- Copy customItems to saved entry
            local savedCustomItems = {}
            for _, id in ipairs(catCustomItems) do
                savedCustomItems[#savedCustomItems + 1] = id
            end

            local entry = {
                name = name,
                matchType = catSelectedMatchType,
                entries = entries,
                weaponSlot = weaponSlot,
                enabled = true,
                icon = iconId > 0 and iconId or nil,
                itemId = overrideItemId,
                customItems = savedCustomItems,
                thresholdDungeon = (tonumber(dBox:GetText()) or 10) * 60,
                thresholdRaid    = (tonumber(rBox:GetText()) or 10) * 60,
                thresholdOpen    = (tonumber(oBox:GetText()) or 5) * 60,
            }

            db.categories = db.categories or {}
            if catEditIdx then
                entry.enabled = db.categories[catEditIdx].enabled
                db.categories[catEditIdx] = entry
            else
                db.categories[#db.categories + 1] = entry
            end

            CloseCatEditor()
            refresh()
        end)

        -- Category row pool
        local CAT_ROW_BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }
        local catRowPool = {}
        local catRowCount = 0

        local function GetCatRow()
            catRowCount = catRowCount + 1
            local r = catRowPool[catRowCount]
            if not r then
                r = CreateFrame("Frame", nil, catListContainer, "BackdropTemplate")
                r:SetSize(410, 26)
                r:SetBackdrop(CAT_ROW_BACKDROP)
                r:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
                r:SetBackdropBorderColor(0, 0, 0, 1)
                r.lbl = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                r.lbl:SetPoint("LEFT", 8, 0)
                r.lbl:SetWidth(220)
                r.lbl:SetJustifyH("LEFT")
                r.del = W:CreateButton(r, { text = "|cffff0000X|r", width = 22, height = 20 })
                r.del:SetPoint("RIGHT", -5, 0)
                r.tog = W:CreateButton(r, { width = 28, height = 20 })
                r.tog:SetPoint("RIGHT", r.del, "LEFT", -4, 0)
                r.edit = W:CreateButton(r, { text = L["COMMON_EDIT"], width = 40, height = 20 })
                r.edit:SetPoint("RIGHT", r.tog, "LEFT", -4, 0)
                catRowPool[catRowCount] = r
            end
            return r
        end

        local catAddBtn = W:CreateButton(catListContainer, { text = L["CONSUMABLE_ADD_CATEGORY"], onClick = function() OpenCatEditor(nil) end })

        local catEmptyLabel = catListContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        catEmptyLabel:SetText(W.Colorize(L["CONSUMABLE_NO_CATEGORIES"], C.GRAY))

        BuildCategoryList = function()
            for idx = 1, catRowCount do catRowPool[idx]:Hide() end
            catRowCount = 0
            catEmptyLabel:Hide()

            db.categories = db.categories or {}
            local yOff = 0

            for i, cat in ipairs(db.categories) do
                local row = GetCatRow()
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, yOff)
                local mt = cat.matchType or "spellId"
                local tag
                if mt == "weaponEnchant" then
                    tag = cat.weaponSlot == 17 and "off-hand enchant" or "main-hand enchant"
                else
                    tag = mt .. ", " .. #(cat.entries or {}) .. " entries"
                end
                local itemCount = cat.customItems and #cat.customItems or 0
                if itemCount > 0 then tag = tag .. ", " .. itemCount .. " items" end
                if cat.itemId then tag = tag .. ", item:" .. cat.itemId end
                local clr = (not cat.enabled) and "|cff666666" or ""
                row.lbl:SetText(clr .. (cat.name or "?") .. " "
                    .. W.Colorize("[" .. tag .. "]", C.GRAY))
                row.del:SetScript("OnClick", function()
                    for idx = #db.categories, 1, -1 do
                        if db.categories[idx] == cat then
                            table.remove(db.categories, idx)
                            break
                        end
                    end
                    CloseCatEditor()
                    BuildCategoryList()
                    refresh()
                end)
                row.tog:SetText(cat.enabled and W.Colorize("ON", C.GREEN) or W.Colorize("OFF", C.RED))
                row.tog:SetScript("OnClick", function()
                    cat.enabled = not cat.enabled
                    BuildCategoryList()
                    refresh()
                end)
                row.edit:SetScript("OnClick", function()
                    for idx = 1, #db.categories do
                        if db.categories[idx] == cat then
                            OpenCatEditor(idx)
                            return
                        end
                    end
                end)
                row:Show()
                yOff = yOff - 30
            end

            if #db.categories == 0 then
                catEmptyLabel:ClearAllPoints()
                catEmptyLabel:SetPoint("TOPLEFT", 0, 0)
                catEmptyLabel:Show()
                yOff = yOff - 20
            end

            catAddBtn:ClearAllPoints()
            catAddBtn:SetPoint("TOPLEFT", 0, yOff - 8)
            catAddBtn:Show()

            catListContainer:SetHeight(math.abs(yOff) + 40)
            catContent:SetHeight(25 + math.abs(yOff) + 40 + 10)
            catWrap:RecalcHeight()
            if RelayoutSections then RelayoutSections() end
        end

        BuildCategoryList()
        cache.buildCatList = BuildCategoryList

        ---------------------------------------------------------------
        -- Relayout
        ---------------------------------------------------------------
        local allSections = { settingsWrap, diffWrap, catWrap }

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

            local totalH = 100 + 62 + 10
            if db.enabled then
                for _, s in ipairs(allSections) do
                    totalH = totalH + s:GetHeight() + 12
                end
            end
            sc:SetHeight(math.max(totalH + 40, 600))
        end

        masterCB:HookScript("OnClick", function(self)
            db.enabled = self:GetChecked() and true or false
            refresh()
            unlockCB:SetShown(db.enabled)
            sectionContainer:SetShown(db.enabled)
            RelayoutSections()
        end)
        sectionContainer:SetShown(db.enabled)

        -- Restore defaults button
        local restoreBtn = W:CreateRestoreDefaultsButton({
            moduleName = "consumableChecker",
            parent = sc,
        })
        restoreBtn:SetPoint("BOTTOMLEFT", sc, "BOTTOMLEFT", 10, 20)

        -- Close popup editor when page is hidden
        cache.hideEditors = function()
            catEditor:Hide(); catEditIdx = nil
        end
        f:SetScript("OnHide", function() if cache.hideEditors then cache.hideEditors() end end)

        RelayoutSections()
    end)

    if cache.buildCatList then cache.buildCatList() end
end
