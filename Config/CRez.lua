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

function ns:InitCRez()
    local p = ns.MainFrame.Content
    local db = NaowhQOL.cRez
    local rezDisplay = ns.CRezTimerDisplay

    local function refreshRez() if rezDisplay then rezDisplay:Refresh() end end
    local function refreshAll() refreshRez() end

    W:CachedPanel(cache, "crezFrame", p, function(f)
        local sf, sc = W:CreateScrollFrame(f, 800)

        W:CreatePageHeader(sc,
            {{"COMBAT", C.BLUE}, {" REZ", C.ORANGE}},
            W.Colorize(L["CREZ_SUBTITLE"] or "Combat resurrection timer and death alerts", C.GRAY))

        local RelayoutAll

        -- ============================================================
        -- REZ TIMER
        -- ============================================================

        local rezKillArea = CreateFrame("Frame", nil, sc, "BackdropTemplate")
        rezKillArea:SetSize(460, 62)
        rezKillArea:SetPoint("TOPLEFT", 10, -75)
        rezKillArea:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
        rezKillArea:SetBackdropColor(0.01, 0.56, 0.91, 0.08)

        local rezMasterCB = W:CreateCheckbox(rezKillArea, {
            label = L["CREZ_ENABLE_TIMER"] or "Enable Combat Rez Timer",
            db = db, key = "enabled",
            x = 15, y = -8,
            isMaster = true,
        })

        local rezUnlockCB = W:CreateCheckbox(rezKillArea, {
            label = L["COMMON_UNLOCK"],
            db = db, key = "unlock",
            x = 15, y = -38,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refreshRez
        })
        rezUnlockCB:SetShown(db.enabled)

        local deathWarnCB = W:CreateCheckbox(rezKillArea, {
            label = L["CREZ_DEATH_WARNING"] or "Death as Warning",
            db = db, key = "deathWarning",
            x = 200, y = -38,
            template = "ChatConfigCheckButtonTemplate",
        })
        deathWarnCB:SetShown(db.enabled)

        -- Rez sections container
        local rezSections = CreateFrame("Frame", nil, sc)
        rezSections:SetPoint("TOPLEFT", rezKillArea, "BOTTOMLEFT", 0, -10)
        rezSections:SetPoint("RIGHT", sc, "RIGHT", -10, 0)
        rezSections:SetHeight(300)

        -- APPEARANCE
        local rezAppWrap, rezAppContent = W:CreateCollapsibleSection(rezSections, {
            text = L["COMMON_SECTION_APPEARANCE"] or "Appearance",
            startOpen = false,
            onCollapse = function() if RelayoutAll then RelayoutAll() end end,
        })

        local G = ns.Layout:New(2)

        -- Row 1: Icon Size
        local iconSlider = W:CreateAdvancedSlider(rezAppContent,
            W.Colorize(L["CREZ_ICON_SIZE"] or "Icon Size", C.ORANGE), 24, 80, G:Row(1), 1, false,
            function(val) db.iconSize = val; refreshRez() end,
            { db = db, key = "iconSize", moduleName = "cRez" })
        PlaceSlider(iconSlider, rezAppContent, G:Col(1), G:SliderY(1))

        -- Row 2: Timer Font Size / Timer Color
        local timerLbl = rezAppContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        timerLbl:SetPoint("TOPLEFT", 10, G:Row(2) + 15)
        timerLbl:SetText(W.Colorize(L["CREZ_TIMER_LABEL"] or "Timer Text", C.BLUE))

        local timerSizeSlider = W:CreateAdvancedSlider(rezAppContent,
            W.Colorize(L["COMMON_FONT_SIZE"] or "Font Size", C.ORANGE), 8, 24, G:Row(2), 1, false,
            function(val) db.timerFontSize = val; refreshRez() end,
            { db = db, key = "timerFontSize", moduleName = "cRez" })
        PlaceSlider(timerSizeSlider, rezAppContent, G:Col(1), G:SliderY(2))

        W:CreateColorPicker(rezAppContent, {
            label = L["COMMON_COLOR"] or "Color", db = db,
            rKey = "timerColorR", gKey = "timerColorG", bKey = "timerColorB",
            x = G:Col(2), y = G:ColorY(2),
            onChange = refreshRez
        })

        -- Row 3: Timer Alpha
        local timerAlphaSlider = W:CreateAdvancedSlider(rezAppContent,
            W.Colorize(L["COMMON_ALPHA"] or "Alpha", C.ORANGE), 0, 100, G:Row(3), 5, true,
            function(val) db.timerAlpha = val / 100; refreshRez() end,
            { value = (db.timerAlpha or 1.0) * 100 })
        PlaceSlider(timerAlphaSlider, rezAppContent, G:Col(1), G:SliderY(3))

        -- Row 4: Stack Count Font Size / Stack Color
        local countLbl = rezAppContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        countLbl:SetPoint("TOPLEFT", 10, G:Row(4) + 15)
        countLbl:SetText(W.Colorize(L["CREZ_COUNT_LABEL"] or "Stack Count", C.BLUE))

        local countSizeSlider = W:CreateAdvancedSlider(rezAppContent,
            W.Colorize(L["COMMON_FONT_SIZE"] or "Font Size", C.ORANGE), 8, 24, G:Row(4), 1, false,
            function(val) db.countFontSize = val; refreshRez() end,
            { db = db, key = "countFontSize", moduleName = "cRez" })
        PlaceSlider(countSizeSlider, rezAppContent, G:Col(1), G:SliderY(4))

        W:CreateColorPicker(rezAppContent, {
            label = L["COMMON_COLOR"] or "Color", db = db,
            rKey = "countColorR", gKey = "countColorG", bKey = "countColorB",
            x = G:Col(2), y = G:ColorY(4),
            onChange = refreshRez
        })

        -- Row 5: Stack Alpha
        local countAlphaSlider = W:CreateAdvancedSlider(rezAppContent,
            W.Colorize(L["COMMON_ALPHA"] or "Alpha", C.ORANGE), 0, 100, G:Row(5), 5, true,
            function(val) db.countAlpha = val / 100; refreshRez() end,
            { value = (db.countAlpha or 1.0) * 100 })
        PlaceSlider(countAlphaSlider, rezAppContent, G:Col(1), G:SliderY(5))

        rezAppContent:SetHeight(G:Height(5))
        rezAppWrap:RecalcHeight()

        -- ============================================================
        -- Layout
        -- ============================================================

        local rezSectionList = { rezAppWrap }

        RelayoutAll = function()
            -- Rez sections
            for i, section in ipairs(rezSectionList) do
                section:ClearAllPoints()
                if i == 1 then
                    section:SetPoint("TOPLEFT", rezSections, "TOPLEFT", 0, 0)
                else
                    section:SetPoint("TOPLEFT", rezSectionList[i - 1], "BOTTOMLEFT", 0, -12)
                end
                section:SetPoint("RIGHT", rezSections, "RIGHT", 0, 0)
            end

            local rezH = 0
            if db.enabled then
                for _, s in ipairs(rezSectionList) do
                    rezH = rezH + s:GetHeight() + 12
                end
            end
            rezSections:SetHeight(math.max(rezH, 1))

            -- Total scroll height
            local totalH = 75 + 62 + 10 + rezH + 40
            sc:SetHeight(math.max(totalH, 800))
        end

        rezMasterCB:HookScript("OnClick", function(self)
            db.enabled = self:GetChecked() and true or false
            refreshRez()
            rezUnlockCB:SetShown(db.enabled)
            deathWarnCB:SetShown(db.enabled)
            rezSections:SetShown(db.enabled)
            RelayoutAll()
        end)
        rezSections:SetShown(db.enabled)

        -- Restore defaults button
        local restoreBtn = W:CreateRestoreDefaultsButton({
            moduleName = "cRez",
            parent = sc,
            initFunc = function() ns:InitCRez() end,
            onRestore = function()
                if cache.crezFrame then
                    cache.crezFrame:Hide()
                    cache.crezFrame:SetParent(nil)
                    cache.crezFrame = nil
                end
                refreshAll()
            end
        })
        restoreBtn:SetPoint("BOTTOMLEFT", sc, "BOTTOMLEFT", 10, 20)

        RelayoutAll()
    end)
end
