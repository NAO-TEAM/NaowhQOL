local addonName, ns = ...
local L = ns.L

local cache = {}
local W = ns.Widgets
local C = ns.COLORS

function ns:InitRangeCheck()
    local p = ns.MainFrame.Content
    local db = NaowhQOL.rangeCheck
    local rangeDisplay = ns.RangeCheckRangeFrame

    W:CachedPanel(cache, "rcFrame", p, function(f)
        local sf, sc = W:CreateScrollFrame(f, 600)

        W:CreatePageHeader(sc,
            {{"RANGE ", C.BLUE}, {"CHECK", C.ORANGE}},
            W.Colorize(L["RANGE_SUBTITLE"], C.GRAY))

        local function refreshRange() if rangeDisplay then rangeDisplay:UpdateDisplay() end end

        -- Master enable area
        local killArea = CreateFrame("Frame", nil, sc, "BackdropTemplate")
        killArea:SetSize(460, 62)
        killArea:SetPoint("TOPLEFT", 10, -75)
        killArea:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
        killArea:SetBackdropColor(0.01, 0.56, 0.91, 0.08)

        local masterCB = W:CreateCheckbox(killArea, {
            label = L["RANGE_ENABLE"],
            db = db, key = "enabled",
            x = 15, y = -8,
            isMaster = true,
        })

        local unlockCB = W:CreateCheckbox(killArea, {
            label = L["COMMON_UNLOCK"],
            db = db, key = "rangeUnlock",
            x = 15, y = -38,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refreshRange
        })
        unlockCB:SetShown(db.enabled)

        -- Section container
        local sectionContainer = CreateFrame("Frame", nil, sc)
        sectionContainer:SetPoint("TOPLEFT", killArea, "BOTTOMLEFT", 0, -10)
        sectionContainer:SetPoint("RIGHT", sc, "RIGHT", -10, 0)
        sectionContainer:SetHeight(400)

        local RelayoutSections

        -- BEHAVIOR section
        local behWrap, behContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["COMMON_SECTION_BEHAVIOR"],
            startOpen = false,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        W:CreateCheckbox(behContent, {
            label = L["RANGE_COMBAT_ONLY"],
            db = db, key = "rangeCombatOnly",
            x = 10, y = -5,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refreshRange
        })

        behContent:SetHeight(35)
        behWrap:RecalcHeight()

        -- APPEARANCE section
        local appWrap, appContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["COMMON_SECTION_APPEARANCE"],
            startOpen = false,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        W:CreateFontPicker(appContent, 10, -5, db.rangeFont, function(path)
            db.rangeFont = path
            refreshRange()
        end)

        -- Initialize rangeColors table if needed
        if not db.rangeColors then
            db.rangeColors = {
                [0]  = {r = 0.01, g = 0.91, b = 0.15},
                [5]  = {r = 0.01, g = 0.91, b = 0.15},
                [10] = {r = 0.91, g = 0.91, b = 0.01},
                [15] = {r = 0.91, g = 0.56, b = 0.01},
                [20] = {r = 0.91, g = 0.56, b = 0.01},
                [25] = {r = 0.91, g = 0.20, b = 0.01},
                [30] = {r = 0.91, g = 0.01, b = 0.01},
                [35] = {r = 0.91, g = 0.01, b = 0.01},
                [40] = {r = 0.91, g = 0.01, b = 0.01},
            }
        end

        -- Range bracket color pickers
        local brackets = {0, 5, 10, 15, 20, 25, 30, 35, 40}
        local yOffset = -50
        for i, bracket in ipairs(brackets) do
            local nextBracket = brackets[i + 1] or (bracket + 5)
            local label = bracket .. "-" .. (nextBracket - 1) .. " yd"
            if not db.rangeColors[bracket] then
                db.rangeColors[bracket] = {r = 0.01, g = 0.56, b = 0.91}
            end
            local colorBtn = CreateFrame("Button", nil, appContent)
            colorBtn:SetSize(20, 20)
            colorBtn:SetPoint("TOPLEFT", 10, yOffset)

            local border = colorBtn:CreateTexture(nil, "BACKGROUND")
            border:SetPoint("TOPLEFT", -1, 1)
            border:SetPoint("BOTTOMRIGHT", 1, -1)
            border:SetColorTexture(0.3, 0.3, 0.3)

            local tex = colorBtn:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints()
            tex:SetColorTexture(db.rangeColors[bracket].r, db.rangeColors[bracket].g, db.rangeColors[bracket].b)
            colorBtn.tex = tex

            local lbl = appContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lbl:SetPoint("LEFT", colorBtn, "RIGHT", 8, 0)
            lbl:SetText(label)

            colorBtn:SetScript("OnClick", function()
                local c = db.rangeColors[bracket]
                ColorPickerFrame:SetupColorPickerAndShow({
                    r = c.r, g = c.g, b = c.b,
                    hasOpacity = false,
                    swatchFunc = function()
                        local r, g, b = ColorPickerFrame:GetColorRGB()
                        db.rangeColors[bracket] = {r = r, g = g, b = b}
                        tex:SetColorTexture(r, g, b)
                        refreshRange()
                    end,
                    cancelFunc = function(prev)
                        db.rangeColors[bracket] = {r = prev.r, g = prev.g, b = prev.b}
                        tex:SetColorTexture(prev.r, prev.g, prev.b)
                        refreshRange()
                    end,
                })
            end)
            yOffset = yOffset - 28
        end

        appContent:SetHeight(50 + (#brackets * 28) + 10)
        appWrap:RecalcHeight()

        -- Layout
        local allSections = { behWrap, appWrap }

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

        -- Master enable click
        masterCB:HookScript("OnClick", function(self)
            db.enabled = self:GetChecked() and true or false
            db.rangeEnabled = db.enabled  -- Keep in sync for compatibility
            refreshRange()
            unlockCB:SetShown(db.enabled)
            sectionContainer:SetShown(db.enabled)
            RelayoutSections()
        end)

        -- Restore defaults button
        local restoreBtn = W:CreateRestoreDefaultsButton({
            moduleName = "rangeCheck",
            parent = sc,
        })
        restoreBtn:SetPoint("BOTTOMLEFT", sc, "BOTTOMLEFT", 10, 20)

        -- Initial visibility
        sectionContainer:SetShown(db.enabled)
        RelayoutSections()
    end)
end
