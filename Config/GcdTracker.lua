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

local function GetSpellName(spellId)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellId)
        return info and info.name
    else
        local name = GetSpellInfo(spellId)
        return name
    end
end

function ns:InitGcdTracker()
    local p = ns.MainFrame.Content
    local db = NaowhQOL.gcdTracker
    local display = ns.GcdTrackerDisplay

    W:CachedPanel(cache, "gtFrame", p, function(f)
        local sf, sc = W:CreateScrollFrame(f, 1000)

        W:CreatePageHeader(sc,
            {{"GCD ", C.BLUE}, {"TRACKER", C.ORANGE}},
            W.Colorize(L["GCD_SUBTITLE"], C.GRAY))

        local function onUpdate() if display then display:UpdateDisplay() end end
        local function visRefresh()
            if ns.GcdTrackerRefreshVisibility then ns.GcdTrackerRefreshVisibility() end
            onUpdate()
        end

        -- on/off toggle
        local killArea = CreateFrame("Frame", nil, sc, "BackdropTemplate")
        killArea:SetSize(460, 86)
        killArea:SetPoint("TOPLEFT", 10, -75)
        killArea:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
        killArea:SetBackdropColor(0.01, 0.56, 0.91, 0.08)

        local masterCB = W:CreateCheckbox(killArea, {
            label = L["GCD_ENABLE"],
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

        local combatCB = W:CreateCheckbox(killArea, {
            label = L["GCD_COMBAT_ONLY"],
            db = db, key = "combatOnly",
            x = 15, y = -62,
            template = "ChatConfigCheckButtonTemplate",
            onChange = visRefresh
        })
        combatCB:SetShown(db.enabled)

        -- Section container
        local sectionContainer = CreateFrame("Frame", nil, sc)
        sectionContainer:SetPoint("TOPLEFT", killArea, "BOTTOMLEFT", 0, -10)
        sectionContainer:SetPoint("RIGHT", sc, "RIGHT", -10, 0)
        sectionContainer:SetHeight(800)

        local RelayoutSections

        -- DISPLAY section
        local dspWrap, dspContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["COMMON_SECTION_DISPLAY"],
            startOpen = true,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local G = ns.Layout:New(2)

        local durationSlider = W:CreateAdvancedSlider(dspContent,
            W.Colorize(L["GCD_DURATION"], C.ORANGE), 1, 15, -5, 0.5, false,
            function(val) db.duration = val end,
            { db = db, key = "duration", moduleName = "gcdTracker" })
        PlaceSlider(durationSlider, dspContent, G:Col(1), G:Row(1))

        local iconSizeSlider = W:CreateAdvancedSlider(dspContent,
            W.Colorize(L["COMMON_LABEL_ICON_SIZE"], C.ORANGE), 16, 64, -5, 1, false,
            function(val) db.iconSize = val; onUpdate() end,
            { db = db, key = "iconSize", moduleName = "gcdTracker" })
        PlaceSlider(iconSizeSlider, dspContent, G:Col(2), G:Row(1))

        local spacingSlider = W:CreateAdvancedSlider(dspContent,
            W.Colorize(L["GCD_SPACING"], C.ORANGE), 0, 20, -65, 1, false,
            function(val) db.spacing = val end,
            { db = db, key = "spacing", moduleName = "gcdTracker" })
        PlaceSlider(spacingSlider, dspContent, G:Col(1), G:Row(2))

        -- fadeStart stored as 0-1, slider shows 0-100
        local fadeSlider = W:CreateAdvancedSlider(dspContent,
            W.Colorize(L["GCD_FADE_START"], C.ORANGE), 0, 100, -65, 5, true,
            function(val) db.fadeStart = val / 100 end,
            { value = (db.fadeStart ~= nil and db.fadeStart or 0.5) * 100 })
        PlaceSlider(fadeSlider, dspContent, G:Col(2), G:Row(2))

        db.direction = db.direction or "RIGHT"
        W:CreateDropdown(dspContent, {
            label = L["GCD_SCROLL_DIR"],
            db = db, key = "direction",
            options = {"LEFT", "RIGHT", "UP", "DOWN"},
            x = G:Col(1), y = G:Row(3),
            width = 160,
            globalName = "NaowhGcdDirDrop"
        })

        W:CreateCheckbox(dspContent, {
            label = L["GCD_STACK_OVERLAPPING"],
            db = db, key = "stackOverlapping",
            x = G:Col(2), y = G:Row(3),
            template = "ChatConfigCheckButtonTemplate",
            onChange = onUpdate
        })

        dspContent:SetHeight(G:Height(3) + 30)
        dspWrap:RecalcHeight()

        -- TIMELINE section
        local tlWrap, tlContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["GCD_SECTION_TIMELINE"],
            startOpen = true,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local GT = ns.Layout:New(2)

        local tlSlider = W:CreateAdvancedSlider(tlContent,
            W.Colorize(L["GCD_THICKNESS"], C.ORANGE), 1, 16, -5, 1, false,
            function(val) db.timelineHeight = val; onUpdate() end,
            { db = db, key = "timelineHeight", moduleName = "gcdTracker" })
        PlaceSlider(tlSlider, tlContent, GT:Col(1), GT:Row(1))

        W:CreateColorPicker(tlContent, {
            label = L["GCD_TIMELINE_COLOR"], db = db,
            rKey = "timelineColorR", gKey = "timelineColorG", bKey = "timelineColorB",
            x = GT:Col(1), y = GT:Row(2) + 5,
            onChange = onUpdate
        })

        W:CreateCheckbox(tlContent, {
            label = L["GCD_SHOW_DOWNTIME"],
            db = db, key = "showDowntimeSummary",
            x = GT:Col(2), y = GT:Row(2) + 5,
            template = "ChatConfigCheckButtonTemplate",
        })

        tlContent:SetHeight(GT:Height(2))
        tlWrap:RecalcHeight()

        -- ZONE VISIBILITY section
        local zoneWrap, zoneContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["GCD_SECTION_ZONE"],
            startOpen = true,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local zoneChecks = {
            { label = L["GCD_SHOW_DUNGEONS"],      key = "showInDungeon" },
            { label = L["GCD_SHOW_RAIDS"],         key = "showInRaid" },
            { label = L["GCD_SHOW_ARENAS"],        key = "showInArena" },
            { label = L["GCD_SHOW_BGS"], key = "showInBattleground" },
            { label = L["GCD_SHOW_WORLD"],         key = "showInWorld" },
        }

        for i, def in ipairs(zoneChecks) do
            W:CreateCheckbox(zoneContent, {
                label = def.label,
                db = db, key = def.key,
                x = 10, y = -5 - (i - 1) * 25,
                template = "ChatConfigCheckButtonTemplate",
                onChange = visRefresh
            })
        end

        zoneContent:SetHeight(5 + #zoneChecks * 25 + 5)
        zoneWrap:RecalcHeight()

        -- SPELL BLOCKLIST section
        local blkWrap, blkContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["GCD_SECTION_BLOCKLIST"],
            startOpen = true,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local blkDesc = blkContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        blkDesc:SetPoint("TOPLEFT", 10, -5)
        blkDesc:SetText(W.Colorize(L["GCD_BLOCKLIST_DESC"], C.GRAY))

        local inputBox = CreateFrame("EditBox", nil, blkContent, "BackdropTemplate")
        inputBox:SetSize(140, 24)
        inputBox:SetPoint("TOPLEFT", 10, -25)
        inputBox:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]],
            edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
        inputBox:SetBackdropColor(0, 0, 0, 1)
        inputBox:SetBackdropBorderColor(0, 0, 0, 1)
        inputBox:SetFontObject("GameFontHighlightSmall")
        inputBox:SetAutoFocus(false)
        inputBox:SetTextInsets(6, 6, 0, 0)
        inputBox:SetNumeric(true)

        local placeholder = inputBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        placeholder:SetPoint("LEFT", 6, 0)
        placeholder:SetText(L["GCD_SPELLID_PLACEHOLDER"])
        inputBox:SetScript("OnEditFocusGained", function() placeholder:Hide() end)
        inputBox:SetScript("OnEditFocusLost", function()
            if inputBox:GetText() == "" then placeholder:Show() end
        end)

        local addBtn = W:CreateButton(blkContent, { text = L["COMMON_ADD"], width = 70, height = 24 })
        addBtn:SetPoint("LEFT", inputBox, "RIGHT", 8, 0)

        -- Recent spells picker
        local recentLabel = blkContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        recentLabel:SetPoint("TOPLEFT", 10, -55)
        recentLabel:SetText(W.Colorize(L["GCD_RECENT_SPELLS"], C.GRAY))

        local recentContainer = CreateFrame("Frame", nil, blkContent)
        recentContainer:SetSize(430, 28)
        recentContainer:SetPoint("TOPLEFT", 10, -70)

        local recentButtons = {}

        local function GetSpellIcon(spellId)
            if C_Spell and C_Spell.GetSpellInfo then
                local info = C_Spell.GetSpellInfo(spellId)
                return info and info.iconID
            else
                local _, _, icon = GetSpellInfo(spellId)
                return icon
            end
        end

        local function RefreshRecentSpells(RefreshBlocklist)
            for _, btn in ipairs(recentButtons) do btn:Hide() end
            wipe(recentButtons)

            local spells = ns.GcdTrackerRecentSpells or {}
            local shown = 0
            for i = #spells, 1, -1 do
                local entry = spells[i]
                if not (db.blocklist and db.blocklist[entry.spellId]) then
                    local btn = CreateFrame("Button", nil, recentContainer, "BackdropTemplate")
                    btn:SetSize(26, 26)
                    btn:SetPoint("LEFT", shown * 30, 0)

                    btn:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]],
                        edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
                    btn:SetBackdropColor(0.08, 0.08, 0.08, 1)
                    btn:SetBackdropBorderColor(0, 0, 0, 1)

                    local tex = btn:CreateTexture(nil, "ARTWORK")
                    tex:SetPoint("TOPLEFT", 2, -2)
                    tex:SetPoint("BOTTOMRIGHT", -2, 2)
                    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    tex:SetTexture(entry.icon or GetSpellIcon(entry.spellId))

                    local sid = entry.spellId
                    btn:SetScript("OnEnter", function(self)
                        self:SetBackdropBorderColor(0.01, 0.56, 0.91, 1)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        local name = GetSpellName(sid) or "Unknown"
                        GameTooltip:AddLine(name, 1, 1, 1)
                        GameTooltip:AddLine("ID: " .. sid, 0.6, 0.6, 0.6)
                        GameTooltip:AddLine("Click to block", 0.01, 0.56, 0.91)
                        GameTooltip:Show()
                    end)
                    btn:SetScript("OnLeave", function(self)
                        self:SetBackdropBorderColor(0, 0, 0, 1)
                        GameTooltip:Hide()
                    end)
                    btn:SetScript("OnClick", function()
                        if not db.blocklist then db.blocklist = {} end
                        db.blocklist[sid] = true
                        RefreshBlocklist()
                    end)

                    recentButtons[#recentButtons + 1] = btn
                    shown = shown + 1
                    if shown >= 10 then break end
                end
            end

            if shown == 0 then
                recentLabel:SetText(W.Colorize(L["GCD_RECENT_SPELLS"] .. " ", C.GRAY)
                    .. W.Colorize(L["GCD_CAST_TO_POPULATE"], C.GRAY))
                recentContainer:SetHeight(1)
            else
                recentLabel:SetText(W.Colorize(L["GCD_RECENT_SPELLS"], C.GRAY))
                recentContainer:SetHeight(28)
            end
        end

        local listContainer = CreateFrame("Frame", nil, blkContent)
        listContainer:SetSize(430, 200)
        listContainer:SetPoint("TOPLEFT", 10, -100)

        local blocklistRows = {}

        local function RefreshBlocklist()
            for _, row in ipairs(blocklistRows) do row:Hide() end
            wipe(blocklistRows)

            local sorted = {}
            if db.blocklist then
                for spellId in pairs(db.blocklist) do sorted[#sorted + 1] = spellId end
            end
            table.sort(sorted)

            for i, spellId in ipairs(sorted) do
                local row = CreateFrame("Frame", nil, listContainer, "BackdropTemplate")
                row:SetSize(400, 24)
                row:SetPoint("TOPLEFT", 0, -(i - 1) * 28)
                row:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]],
                    edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
                row:SetBackdropColor(0.08, 0.08, 0.08, 0.8)
                row:SetBackdropBorderColor(0, 0, 0, 1)

                local icon = row:CreateTexture(nil, "ARTWORK")
                icon:SetSize(18, 18)
                icon:SetPoint("LEFT", 6, 0)
                icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                icon:SetTexture(GetSpellIcon(spellId))

                local spellName = GetSpellName(spellId) or "Unknown"
                local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
                label:SetText(W.Colorize(spellName, C.WHITE) .. "  "
                    .. W.Colorize("(ID: " .. spellId .. ")", C.GRAY))

                local removeBtn = CreateFrame("Button", nil, row)
                removeBtn:SetSize(20, 20)
                removeBtn:SetPoint("RIGHT", -4, 0)
                local removeTex = removeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                removeTex:SetPoint("CENTER")
                removeTex:SetText(W.Colorize("X", "ff4444"))
                removeBtn:SetScript("OnClick", function()
                    db.blocklist[spellId] = nil
                    RefreshBlocklist()
                end)
                removeBtn:SetScript("OnEnter", function() removeTex:SetText(W.Colorize("X", "ff0000")) end)
                removeBtn:SetScript("OnLeave", function() removeTex:SetText(W.Colorize("X", "ff4444")) end)

                blocklistRows[#blocklistRows + 1] = row
            end

            RefreshRecentSpells(RefreshBlocklist)

            local listH = math.max(10, #sorted * 28)
            blkContent:SetHeight(100 + listH + 10)
            blkWrap:RecalcHeight()
            if RelayoutSections then RelayoutSections() end
        end

        addBtn:SetScript("OnClick", function()
            local spellId = tonumber(inputBox:GetText())
            if spellId and spellId > 0 then
                if not db.blocklist then db.blocklist = {} end
                db.blocklist[spellId] = true
                inputBox:SetText("")
                inputBox:ClearFocus()
                placeholder:Show()
                RefreshBlocklist()
            end
        end)

        inputBox:SetScript("OnEnterPressed", function() addBtn:Click() end)

        -- Live-update the recent spells picker while the panel is visible
        local lastNewest = nil
        local tickAcc = 0
        recentContainer:SetScript("OnUpdate", function(_, elapsed)
            tickAcc = tickAcc + elapsed
            if tickAcc < 1.0 then return end
            tickAcc = 0
            local spells = ns.GcdTrackerRecentSpells or {}
            local newest = #spells > 0 and spells[#spells].spellId or nil
            if newest ~= lastNewest then
                lastNewest = newest
                RefreshRecentSpells(RefreshBlocklist)
            end
        end)

        blkContent:SetHeight(110)
        blkWrap:RecalcHeight()

        -- Relayout
        local allSections = { dspWrap, tlWrap, zoneWrap, blkWrap }

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

            local totalH = 75 + 86 + 10
            if db.enabled then
                for _, s in ipairs(allSections) do
                    totalH = totalH + s:GetHeight() + 12
                end
            end
            sc:SetHeight(math.max(totalH + 40, 600))
        end

        masterCB:SetScript("OnClick", function(self)
            db.enabled = self:GetChecked() and true or false
            visRefresh()
            unlockCB:SetShown(db.enabled)
            combatCB:SetShown(db.enabled)
            sectionContainer:SetShown(db.enabled)
            RelayoutSections()
        end)
        sectionContainer:SetShown(db.enabled)

        -- Restore defaults button
        local restoreBtn = W:CreateRestoreDefaultsButton({
            moduleName = "gcdTracker",
            parent = sc,
            initFunc = function() ns:InitGcdTracker() end,
            onRestore = function()
                if cache.gtFrame then
                    cache.gtFrame:Hide()
                    cache.gtFrame:SetParent(nil)
                    cache.gtFrame = nil
                end
                if display then display:UpdateDisplay() end
            end
        })
        restoreBtn:SetPoint("BOTTOMLEFT", sc, "BOTTOMLEFT", 10, 20)

        RefreshBlocklist()
        RelayoutSections()
    end)

    if display then display:UpdateDisplay() end
end
