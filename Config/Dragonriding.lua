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
            startOpen = false,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local G = ns.Layout:New(2)

        local widthSlider = W:CreateAdvancedSlider(layContent,
            W.Colorize(L["DRAGON_BAR_WIDTH"], C.ORANGE), 10, 100, -5, 1, false,
            function(val) db.barWidth = val; drRefresh() end,
            { db = db, key = "barWidth", moduleName = "dragonriding" })
        PlaceSlider(widthSlider, layContent, G:Col(1), G:Row(1))

        local speedHSlider = W:CreateAdvancedSlider(layContent,
            W.Colorize(L["DRAGON_SPEED_HEIGHT"], C.ORANGE), 6, 50, -5, 1, false,
            function(val) db.speedHeight = val; drRefresh() end,
            { db = db, key = "speedHeight", moduleName = "dragonriding" })
        PlaceSlider(speedHSlider, layContent, G:Col(2), G:Row(1))

        local chargeHSlider = W:CreateAdvancedSlider(layContent,
            W.Colorize(L["DRAGON_CHARGE_HEIGHT"], C.ORANGE), 6, 50, -65, 1, false,
            function(val) db.chargeHeight = val; drRefresh() end,
            { db = db, key = "chargeHeight", moduleName = "dragonriding" })
        PlaceSlider(chargeHSlider, layContent, G:Col(1), G:Row(2))

        local gapSlider = W:CreateAdvancedSlider(layContent,
            W.Colorize(L["DRAGON_GAP"], C.ORANGE), 0, 40, -65, 1, false,
            function(val) db.gap = val; drRefresh() end,
            { db = db, key = "gap", moduleName = "dragonriding" })
        PlaceSlider(gapSlider, layContent, G:Col(2), G:Row(2))

        layContent:SetHeight(G:Height(2))
        layWrap:RecalcHeight()

        -- ANCHOR section
        local anchorWrap, anchorContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["DRAGON_SECTION_ANCHOR"],
            startOpen = false,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local GA = ns.Layout:New(2)

        W:CreateDropdown(anchorContent, {
            label = L["DRAGON_ANCHOR_FRAME"],
            db = db, key = "anchorFrame",
            options = Layout.GetAnchorFrameList(),
            x = GA:Col(1), y = GA:Row(1),
            width = 180,
            onChange = drRefresh,
        })

        W:CreateDropdown(anchorContent, {
            label = L["DRAGON_ANCHOR_SELF"],
            db = db, key = "point",
            options = Layout.ANCHOR_POINTS,
            x = GA:Col(1), y = GA:Row(2),
            width = 130,
            onChange = drRefresh,
        })

        W:CreateDropdown(anchorContent, {
            label = L["DRAGON_ANCHOR_TARGET"],
            db = db, key = "anchorTo",
            options = Layout.ANCHOR_POINTS,
            x = GA:Col(2), y = GA:Row(2),
            width = 130,
            onChange = drRefresh,
        })

        W:CreateCheckbox(anchorContent, {
            label = L["DRAGON_MATCH_WIDTH"],
            db = db, key = "matchAnchorWidth",
            x = GA:Col(1), y = GA:Row(3),
            template = "ChatConfigCheckButtonTemplate",
            description = L["DRAGON_MATCH_WIDTH_DESC"],
            onChange = drRefresh
        })

        local offsetXSlider = W:CreateAdvancedSlider(anchorContent,
            W.Colorize(L["DRAGON_OFFSET_X"], C.ORANGE), -500, 500, -145, 1, false,
            function(val) db.posX = val; drRefresh() end,
            { db = db, key = "posX", moduleName = "dragonriding" })
        PlaceSlider(offsetXSlider, anchorContent, GA:Col(1), GA:Row(4))

        local offsetYSlider = W:CreateAdvancedSlider(anchorContent,
            W.Colorize(L["DRAGON_OFFSET_Y"], C.ORANGE), -500, 500, -145, 1, false,
            function(val) db.posY = val; drRefresh() end,
            { db = db, key = "posY", moduleName = "dragonriding" })
        PlaceSlider(offsetYSlider, anchorContent, GA:Col(2), GA:Row(4))

        anchorContent:SetHeight(GA:Height(4))
        anchorWrap:RecalcHeight()

        -- APPEARANCE section
        local appWrap, appContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["COMMON_SECTION_APPEARANCE"],
            startOpen = false,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local GAP = ns.Layout:New(2)

        local styleLabel = appContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        styleLabel:SetPoint("TOPLEFT", appContent, "TOPLEFT", GAP:Col(1), GAP:Row(1) + 5)
        styleLabel:SetText(W.Colorize(L["DRAGON_BAR_STYLE"], C.BLUE))

        W:CreateBarStylePicker(appContent, GAP:Col(1), GAP:Row(1) - 15,
            db.barStyle or [[Interface\Buttons\WHITE8X8]],
            function(path)
                db.barStyle = path
                drRefresh()
            end)

        W:CreateColorPicker(appContent, {
            label = L["DRAGON_SPEED_COLOR"],
            db = db, rKey = "speedColorR", gKey = "speedColorG", bKey = "speedColorB",
            x = GAP:Col(1), y = GAP:Row(2) + 5,
            onChange = drRefresh,
        })

        W:CreateColorPicker(appContent, {
            label = L["DRAGON_THRILL_COLOR"],
            db = db, rKey = "thrillColorR", gKey = "thrillColorG", bKey = "thrillColorB",
            x = GAP:Col(2), y = GAP:Row(2) + 5,
            onChange = drRefresh,
        })

        W:CreateColorPicker(appContent, {
            label = L["DRAGON_CHARGE_COLOR"],
            db = db, rKey = "chargeColorR", gKey = "chargeColorG", bKey = "chargeColorB",
            x = GAP:Col(1), y = GAP:Row(3),
            onChange = drRefresh,
        })

        W:CreateColorPicker(appContent, {
            label = L["DRAGON_BG_COLOR"],
            db = db, rKey = "bgColorR", gKey = "bgColorG", bKey = "bgColorB",
            x = GAP:Col(2), y = GAP:Row(3),
            onChange = drRefresh,
        })

        local bgAlphaSlider = W:CreateAdvancedSlider(appContent,
            W.Colorize(L["DRAGON_BG_OPACITY"], C.ORANGE), 0, 100, -130, 1, true,
            function(val) db.bgAlpha = val / 100; drRefresh() end)
        PlaceSlider(bgAlphaSlider, appContent, GAP:Col(1), GAP:Row(4))
        -- bgAlpha stored as 0-1, slider shows 0-100
        bgAlphaSlider:SetValue((db.bgAlpha ~= nil and db.bgAlpha or 0.8) * 100)

        W:CreateColorPicker(appContent, {
            label = L["DRAGON_BORDER_COLOR"],
            db = db, rKey = "borderColorR", gKey = "borderColorG", bKey = "borderColorB",
            x = GAP:Col(1), y = GAP:Row(5) + 5,
            onChange = drRefresh,
        })

        local borderAlphaSlider = W:CreateAdvancedSlider(appContent,
            W.Colorize(L["DRAGON_BORDER_OPACITY"], C.ORANGE), 0, 100, -190, 1, true,
            function(val) db.borderAlpha = val / 100; drRefresh() end)
        PlaceSlider(borderAlphaSlider, appContent, GAP:Col(2), GAP:Row(5))
        borderAlphaSlider:SetValue((db.borderAlpha ~= nil and db.borderAlpha or 1.0) * 100)

        local borderSizeSlider = W:CreateAdvancedSlider(appContent,
            W.Colorize(L["DRAGON_BORDER_SIZE"], C.ORANGE), 1, 5, -250, 1, false,
            function(val) db.borderSize = val; drRefresh() end,
            { db = db, key = "borderSize", moduleName = "dragonriding" })
        PlaceSlider(borderSizeSlider, appContent, GAP:Col(1), GAP:Row(6))

        local fontLabel = appContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fontLabel:SetPoint("TOPLEFT", appContent, "TOPLEFT", GAP:Col(1), GAP:Row(7) + 5)
        fontLabel:SetText(W.Colorize(L["DRAGON_SPEED_FONT"], C.BLUE))

        W:CreateFontPicker(appContent, GAP:Col(1), GAP:Row(7) - 15,
            db.speedFont or "Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf",
            function(path)
                db.speedFont = path
                drRefresh()
            end)

        local fontSizeSlider = W:CreateAdvancedSlider(appContent,
            W.Colorize("Font Size", C.ORANGE), 6, 32, -325, 1, false,
            function(val) db.speedFontSize = val; drRefresh() end,
            { db = db, key = "speedFontSize", moduleName = "dragonriding" })
        PlaceSlider(fontSizeSlider, appContent, GAP:Col(2), GAP:Row(7))

        appContent:SetHeight(GAP:Height(7))
        appWrap:RecalcHeight()

        -- BEHAVIOR section
        local behWrap, behContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["COMMON_SECTION_BEHAVIOR"],
            startOpen = false,
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
            startOpen = false,
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
            startOpen = false,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local GI = ns.Layout:New(2)

        local iconSizeSlider = W:CreateAdvancedSlider(iconContent,
            W.Colorize(L["DRAGON_ICON_SIZE"], C.ORANGE), 0, 64, -5, 1, false,
            function(val) db.surgeIconSize = val; drRefresh() end,
            { db = db, key = "surgeIconSize", moduleName = "dragonriding" })
        PlaceSlider(iconSizeSlider, iconContent, GI:Col(1), GI:Row(1))

        W:CreateDropdown(iconContent, {
            label = L["DRAGON_ICON_ANCHOR"],
            db = db, key = "surgeAnchor",
            options = {
                { text = L["DRAGON_ICON_RIGHT"],  value = "RIGHT" },
                { text = L["DRAGON_ICON_LEFT"],   value = "LEFT" },
                { text = L["DRAGON_ICON_TOP"],    value = "TOP" },
                { text = L["DRAGON_ICON_BOTTOM"], value = "BOTTOM" },
            },
            x = GI:Col(2), y = GI:Row(1),
            width = 100,
            onChange = drRefresh,
        })

        local surgeOffsetXSlider = W:CreateAdvancedSlider(iconContent,
            W.Colorize(L["DRAGON_OFFSET_X"], C.ORANGE), -50, 50, -65, 1, false,
            function(val) db.surgeOffsetX = val; drRefresh() end,
            { db = db, key = "surgeOffsetX", moduleName = "dragonriding" })
        PlaceSlider(surgeOffsetXSlider, iconContent, GI:Col(1), GI:Row(2))

        local surgeOffsetYSlider = W:CreateAdvancedSlider(iconContent,
            W.Colorize(L["DRAGON_OFFSET_Y"], C.ORANGE), -50, 50, -65, 1, false,
            function(val) db.surgeOffsetY = val; drRefresh() end,
            { db = db, key = "surgeOffsetY", moduleName = "dragonriding" })
        PlaceSlider(surgeOffsetYSlider, iconContent, GI:Col(2), GI:Row(2))

        W:CreateColorPicker(iconContent, {
            label = L["DRAGON_ICON_BORDER_COLOR"],
            db = db, rKey = "iconBorderColorR", gKey = "iconBorderColorG", bKey = "iconBorderColorB",
            x = GI:Col(1), y = GI:Row(3) + 5,
            onChange = drRefresh,
        })

        local iconBorderAlphaSlider = W:CreateAdvancedSlider(iconContent,
            W.Colorize(L["DRAGON_ICON_BORDER_OPACITY"], C.ORANGE), 0, 100, -130, 1, true,
            function(val) db.iconBorderAlpha = val / 100; drRefresh() end)
        PlaceSlider(iconBorderAlphaSlider, iconContent, GI:Col(2), GI:Row(3))
        iconBorderAlphaSlider:SetValue((db.iconBorderAlpha ~= nil and db.iconBorderAlpha or 1.0) * 100)

        local iconBorderSizeSlider = W:CreateAdvancedSlider(iconContent,
            W.Colorize(L["DRAGON_ICON_BORDER_SIZE"], C.ORANGE), 1, 5, -190, 1, false,
            function(val) db.iconBorderSize = val; drRefresh() end,
            { db = db, key = "iconBorderSize", moduleName = "dragonriding" })
        PlaceSlider(iconBorderSizeSlider, iconContent, GI:Col(1), GI:Row(4))

        iconContent:SetHeight(GI:Height(4))
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

        masterCB:HookScript("OnClick", function(self)
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
