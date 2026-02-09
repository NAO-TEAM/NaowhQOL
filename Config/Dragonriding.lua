local addonName, ns = ...
local L = ns.L

local cache = {}
local W = ns.Widgets
local C = ns.COLORS
local Layout = ns.LayoutUtil

local function PlaceSlider(slider, parent, x, y)
    local frame = slider:GetParent()
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    return slider
end

function ns:InitDragonriding()
    local p = ns.MainFrame.Content
    local db = NaowhQOL.dragonriding

    W:CachedPanel(cache, "drFrame", p, function(f)
        local sf, sc = W:CreateScrollFrame(f, 1200)

        W:CreatePageHeader(sc,
            {{"DRAGON", C.BLUE}, {"RIDING", C.ORANGE}},
            W.Colorize(L["DRAGON_SUBTITLE"], C.GRAY))

        local function drRefresh()
            if ns.RefreshDragonridingLayout then ns:RefreshDragonridingLayout() end
        end

        -- on/off toggle
        local killArea = CreateFrame("Frame", nil, sc, "BackdropTemplate")
        killArea:SetSize(460, 62)
        killArea:SetPoint("TOPLEFT", 10, -75)
        killArea:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
        killArea:SetBackdropColor(0.01, 0.56, 0.91, 0.08)

        local masterCB = W:CreateCheckbox(killArea, {
            label = L["DRAGON_ENABLE"],
            db = db, key = "enabled",
            x = 15, y = -8,
            isMaster = true,
        })

        local unlockCB = W:CreateCheckbox(killArea, {
            label = L["COMMON_UNLOCK"],
            db = db, key = "unlocked",
            x = 15, y = -38,
            template = "ChatConfigCheckButtonTemplate",
        })
        unlockCB:SetShown(db.enabled)

        -- Section container
        local sectionContainer = CreateFrame("Frame", nil, sc)
        sectionContainer:SetPoint("TOPLEFT", killArea, "BOTTOMLEFT", 0, -10)
        sectionContainer:SetPoint("RIGHT", sc, "RIGHT", -10, 0)
        sectionContainer:SetHeight(600)

        local RelayoutSections

        -- LAYOUT section
        local layWrap, layContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["DRAGON_SECTION_LAYOUT"],
            startOpen = true,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local widthSlider = W:CreateAdvancedSlider(layContent,
            W.Colorize(L["DRAGON_BAR_WIDTH"], C.ORANGE), 10, 100, -5, 1, false,
            function(val) db.barWidth = val; drRefresh() end,
            { db = db, key = "barWidth", moduleName = "dragonriding" })
        PlaceSlider(widthSlider, layContent, 0, -5)

        local speedHSlider = W:CreateAdvancedSlider(layContent,
            W.Colorize(L["DRAGON_SPEED_HEIGHT"], C.ORANGE), 6, 50, -5, 1, false,
            function(val) db.speedHeight = val; drRefresh() end,
            { db = db, key = "speedHeight", moduleName = "dragonriding" })
        PlaceSlider(speedHSlider, layContent, 240, -5)

        local chargeHSlider = W:CreateAdvancedSlider(layContent,
            W.Colorize(L["DRAGON_CHARGE_HEIGHT"], C.ORANGE), 6, 50, -65, 1, false,
            function(val) db.chargeHeight = val; drRefresh() end,
            { db = db, key = "chargeHeight", moduleName = "dragonriding" })
        PlaceSlider(chargeHSlider, layContent, 0, -65)

        local gapSlider = W:CreateAdvancedSlider(layContent,
            W.Colorize(L["DRAGON_GAP"], C.ORANGE), 0, 40, -65, 1, false,
            function(val) db.gap = val; drRefresh() end,
            { db = db, key = "gap", moduleName = "dragonriding" })
        PlaceSlider(gapSlider, layContent, 240, -65)

        layContent:SetHeight(125)
        layWrap:RecalcHeight()

        -- ANCHOR section
        local anchorWrap, anchorContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["DRAGON_SECTION_ANCHOR"],
            startOpen = true,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        W:CreateDropdown(anchorContent, {
            label = L["DRAGON_ANCHOR_FRAME"],
            db = db, key = "anchorFrame",
            options = Layout.GetAnchorFrameList(),
            x = 10, y = -5,
            width = 180,
            onChange = drRefresh,
        })

        W:CreateDropdown(anchorContent, {
            label = L["DRAGON_ANCHOR_SELF"],
            db = db, key = "point",
            options = Layout.ANCHOR_POINTS,
            x = 10, y = -65,
            width = 130,
            onChange = drRefresh,
        })

        W:CreateDropdown(anchorContent, {
            label = L["DRAGON_ANCHOR_TARGET"],
            db = db, key = "anchorTo",
            options = Layout.ANCHOR_POINTS,
            x = 240, y = -65,
            width = 130,
            onChange = drRefresh,
        })

        W:CreateCheckbox(anchorContent, {
            label = L["DRAGON_MATCH_WIDTH"],
            db = db, key = "matchAnchorWidth",
            x = 10, y = -120,
            template = "ChatConfigCheckButtonTemplate",
            description = L["DRAGON_MATCH_WIDTH_DESC"],
            onChange = drRefresh
        })

        local offsetXSlider = W:CreateAdvancedSlider(anchorContent,
            W.Colorize(L["DRAGON_OFFSET_X"], C.ORANGE), -500, 500, -145, 1, false,
            function(val) db.posX = val; drRefresh() end,
            { db = db, key = "posX", moduleName = "dragonriding" })
        PlaceSlider(offsetXSlider, anchorContent, 0, -145)

        local offsetYSlider = W:CreateAdvancedSlider(anchorContent,
            W.Colorize(L["DRAGON_OFFSET_Y"], C.ORANGE), -500, 500, -145, 1, false,
            function(val) db.posY = val; drRefresh() end,
            { db = db, key = "posY", moduleName = "dragonriding" })
        PlaceSlider(offsetYSlider, anchorContent, 240, -145)

        anchorContent:SetHeight(210)
        anchorWrap:RecalcHeight()

        -- APPEARANCE section
        local appWrap, appContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["COMMON_SECTION_APPEARANCE"],
            startOpen = true,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local styleLabel = appContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        styleLabel:SetPoint("TOPLEFT", appContent, "TOPLEFT", 10, -5)
        styleLabel:SetText(W.Colorize(L["DRAGON_BAR_STYLE"], C.BLUE))

        W:CreateBarStylePicker(appContent, 10, -20,
            db.barStyle or [[Interface\Buttons\WHITE8X8]],
            function(path)
                db.barStyle = path
                drRefresh()
            end)

        W:CreateColorPicker(appContent, {
            label = L["DRAGON_SPEED_COLOR"],
            db = db, rKey = "speedColorR", gKey = "speedColorG", bKey = "speedColorB",
            x = 10, y = -60,
            onChange = drRefresh,
        })

        W:CreateColorPicker(appContent, {
            label = L["DRAGON_THRILL_COLOR"],
            db = db, rKey = "thrillColorR", gKey = "thrillColorG", bKey = "thrillColorB",
            x = 240, y = -60,
            onChange = drRefresh,
        })

        W:CreateColorPicker(appContent, {
            label = L["DRAGON_CHARGE_COLOR"],
            db = db, rKey = "chargeColorR", gKey = "chargeColorG", bKey = "chargeColorB",
            x = 10, y = -95,
            onChange = drRefresh,
        })

        W:CreateColorPicker(appContent, {
            label = L["DRAGON_BG_COLOR"],
            db = db, rKey = "bgColorR", gKey = "bgColorG", bKey = "bgColorB",
            x = 240, y = -95,
            onChange = drRefresh,
        })

        local bgAlphaSlider = W:CreateAdvancedSlider(appContent,
            W.Colorize(L["DRAGON_BG_OPACITY"], C.ORANGE), 0, 100, -130, 1, true,
            function(val) db.bgAlpha = val / 100; drRefresh() end)
        PlaceSlider(bgAlphaSlider, appContent, 0, -130)
        -- bgAlpha stored as 0-1, slider shows 0-100
        bgAlphaSlider:SetValue((db.bgAlpha ~= nil and db.bgAlpha or 0.8) * 100)

        local fontLabel = appContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fontLabel:SetPoint("TOPLEFT", appContent, "TOPLEFT", 10, -190)
        fontLabel:SetText(W.Colorize(L["DRAGON_SPEED_FONT"], C.BLUE))

        W:CreateFontPicker(appContent, 10, -205,
            db.speedFont or "Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf",
            function(path)
                db.speedFont = path
                drRefresh()
            end)

        local fontSizeSlider = W:CreateAdvancedSlider(appContent,
            W.Colorize("Font Size", C.ORANGE), 6, 32, -205, 1, false,
            function(val) db.speedFontSize = val; drRefresh() end,
            { db = db, key = "speedFontSize", moduleName = "dragonriding" })
        PlaceSlider(fontSizeSlider, appContent, 240, -205)

        appContent:SetHeight(265)
        appWrap:RecalcHeight()

        -- BEHAVIOR section
        local behWrap, behContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["COMMON_SECTION_BEHAVIOR"],
            startOpen = true,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        W:CreateCheckbox(behContent, {
            label = L["DRAGON_SHOW_SPEED"],
            db = db, key = "showSpeedText",
            x = 10, y = -5,
            template = "ChatConfigCheckButtonTemplate",
            description = L["DRAGON_SHOW_SPEED_DESC"],
            onChange = drRefresh
        })

        W:CreateCheckbox(behContent, {
            label = L["DRAGON_SWAP_BARS"],
            db = db, key = "swapPosition",
            x = 10, y = -30,
            template = "ChatConfigCheckButtonTemplate",
            description = L["DRAGON_SWAP_BARS_DESC"],
            onChange = drRefresh
        })

        W:CreateCheckbox(behContent, {
            label = L["DRAGON_HIDE_GROUNDED"],
            db = db, key = "hideWhenGroundedFull",
            x = 10, y = -55,
            template = "ChatConfigCheckButtonTemplate",
            description = L["DRAGON_HIDE_GROUNDED_DESC"],
            onChange = drRefresh
        })

        W:CreateCheckbox(behContent, {
            label = L["DRAGON_HIDE_COOLDOWN"],
            db = db, key = "hideCdmWhileMounted",
            x = 10, y = -80,
            template = "ChatConfigCheckButtonTemplate",
            description = L["DRAGON_HIDE_COOLDOWN_DESC"],
            onChange = drRefresh
        })

        behContent:SetHeight(110)
        behWrap:RecalcHeight()

        -- FEATURES section
        local featWrap, featContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["DRAGON_SECTION_FEATURES"],
            startOpen = true,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        W:CreateCheckbox(featContent, {
            label = L["DRAGON_SECOND_WIND"],
            db = db, key = "showSecondWind",
            x = 10, y = -5,
            template = "ChatConfigCheckButtonTemplate",
            description = L["DRAGON_SECOND_WIND_DESC"],
            onChange = drRefresh
        })

        W:CreateCheckbox(featContent, {
            label = L["DRAGON_WHIRLING_SURGE"],
            db = db, key = "showWhirlingSurge",
            x = 10, y = -30,
            template = "ChatConfigCheckButtonTemplate",
            description = L["DRAGON_WHIRLING_SURGE_DESC"],
            onChange = drRefresh
        })

        featContent:SetHeight(60)
        featWrap:RecalcHeight()

        -- ICON section (Whirling Surge)
        local iconWrap, iconContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["DRAGON_SECTION_ICON"],
            startOpen = true,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local iconSizeSlider = W:CreateAdvancedSlider(iconContent,
            W.Colorize(L["DRAGON_ICON_SIZE"], C.ORANGE), 0, 64, -5, 1, false,
            function(val) db.surgeIconSize = val; drRefresh() end,
            { db = db, key = "surgeIconSize", moduleName = "dragonriding" })
        PlaceSlider(iconSizeSlider, iconContent, 0, -5)

        W:CreateDropdown(iconContent, {
            label = L["DRAGON_ICON_ANCHOR"],
            db = db, key = "surgeAnchor",
            options = {
                { text = L["DRAGON_ICON_RIGHT"],  value = "RIGHT" },
                { text = L["DRAGON_ICON_LEFT"],   value = "LEFT" },
                { text = L["DRAGON_ICON_TOP"],    value = "TOP" },
                { text = L["DRAGON_ICON_BOTTOM"], value = "BOTTOM" },
            },
            x = 240, y = -5,
            width = 100,
            onChange = drRefresh,
        })

        local offsetXSlider = W:CreateAdvancedSlider(iconContent,
            W.Colorize(L["DRAGON_OFFSET_X"], C.ORANGE), -50, 50, -65, 1, false,
            function(val) db.surgeOffsetX = val; drRefresh() end,
            { db = db, key = "surgeOffsetX", moduleName = "dragonriding" })
        PlaceSlider(offsetXSlider, iconContent, 0, -65)

        local offsetYSlider = W:CreateAdvancedSlider(iconContent,
            W.Colorize(L["DRAGON_OFFSET_Y"], C.ORANGE), -50, 50, -65, 1, false,
            function(val) db.surgeOffsetY = val; drRefresh() end,
            { db = db, key = "surgeOffsetY", moduleName = "dragonriding" })
        PlaceSlider(offsetYSlider, iconContent, 240, -65)

        iconContent:SetHeight(125)
        iconWrap:RecalcHeight()

        -- Relayout
        local allSections = { layWrap, anchorWrap, appWrap, behWrap, featWrap, iconWrap }

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
            drRefresh()
            unlockCB:SetShown(db.enabled)
            sectionContainer:SetShown(db.enabled)
            RelayoutSections()
        end)
        sectionContainer:SetShown(db.enabled)

        -- Restore defaults button
        local restoreBtn = W:CreateRestoreDefaultsButton({
            moduleName = "dragonriding",
            parent = sc,
        })
        restoreBtn:SetPoint("BOTTOMLEFT", sc, "BOTTOMLEFT", 10, 20)

        RelayoutSections()
    end)

    if ns.RefreshDragonridingLayout then
        ns:RefreshDragonridingLayout()
    end
end
