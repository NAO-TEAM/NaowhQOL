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

        W:CreateColorPicker(appContent, {
            label = L["COMMON_LABEL_TEXT_COLOR"], db = db,
            rKey = "rangeColorR", gKey = "rangeColorG", bKey = "rangeColorB",
            x = 10, y = -50,
            onChange = refreshRange
        })

        appContent:SetHeight(90)
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
