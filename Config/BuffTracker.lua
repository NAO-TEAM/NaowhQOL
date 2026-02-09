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

function ns:InitBuffTracker()
    if not ns.MainFrame or not ns.MainFrame.Content then return end
    local p = ns.MainFrame.Content

    if not NaowhQOL then NaowhQOL = {} end
    if not NaowhQOL.buffTracker then
        NaowhQOL.buffTracker = {
            enabled = true, iconSize = 40, spacing = 4, textSize = 14,
            font = "Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", showMissingOnly = false,
            combatOnly = false, showCooldown = true, showStacks = true,
            unlocked = false, showAllRaidBuffs = false, showRaidBuffs = true,
            showPersonalAuras = true, showStances = true,
            growDirection = "RIGHT", maxIconsPerRow = 10,
            point = "TOP", posX = 0, posY = -100, width = 450, height = 60,
        }
    end

    local db = NaowhQOL.buffTracker
    local defaults = {
        enabled = true, iconSize = 40, spacing = 4, textSize = 14,
        font = "Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", showMissingOnly = false,
        combatOnly = false, showCooldown = true, showStacks = true,
        unlocked = false, showAllRaidBuffs = false, showRaidBuffs = true,
        showPersonalAuras = true, showStances = true,
        growDirection = "RIGHT", maxIconsPerRow = 10,
        point = "TOP", posX = 0, posY = -100, width = 450, height = 60,
    }
    for k, v in pairs(defaults) do if db[k] == nil then db[k] = v end end

    local function refresh() if ns.RefreshBuffTracker then ns:RefreshBuffTracker() end end

    W:CachedPanel(cache, "btFrame", p, function(f)
        local sf, sc = W:CreateScrollFrame(f, 800)

        W:CreatePageHeader(sc,
            {{"BUFF ", C.BLUE}, {"TRACKER", C.ORANGE}},
            W.Colorize(L["BUFFTRACKER_SUBTITLE"], C.GRAY))

        -- Master Killswitch
        local killArea = CreateFrame("Frame", nil, sc, "BackdropTemplate")
        killArea:SetSize(460, 62)
        killArea:SetPoint("TOPLEFT", 10, -75)
        killArea:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
        killArea:SetBackdropColor(0.01, 0.56, 0.91, 0.08)

        local masterCB = W:CreateCheckbox(killArea, {
            label = L["BUFFTRACKER_ENABLE"],
            db = db, key = "enabled",
            x = 15, y = -8,
            isMaster = true,
        })

        local unlockCB = W:CreateCheckbox(killArea, {
            label = L["COMMON_UNLOCK"],
            db = db, key = "unlocked",
            x = 15, y = -38,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refresh
        })
        unlockCB:SetShown(db.enabled)

        -- Section container
        local sectionContainer = CreateFrame("Frame", nil, sc)
        sectionContainer:SetPoint("TOPLEFT", killArea, "BOTTOMLEFT", 0, -10)
        sectionContainer:SetPoint("RIGHT", sc, "RIGHT", -10, 0)
        sectionContainer:SetHeight(600)

        local RelayoutSections

        -- TRACKING section
        local trkWrap, trkContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["BUFFTRACKER_SECTION_TRACKING"],
            startOpen = true,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        W:CreateCheckbox(trkContent, {
            label = L["BUFFTRACKER_RAID_MODE"],
            db = db, key = "showAllRaidBuffs",
            x = 10, y = -5,
            template = "ChatConfigCheckButtonTemplate",
            description = L["BUFFTRACKER_RAID_MODE_DESC"],
            onChange = refresh
        })

        W:CreateCheckbox(trkContent, {
            label = L["BUFFTRACKER_RAID_BUFFS"],
            db = db, key = "showRaidBuffs",
            x = 10, y = -30,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refresh
        })

        W:CreateCheckbox(trkContent, {
            label = L["BUFFTRACKER_PERSONAL_AURAS"],
            db = db, key = "showPersonalAuras",
            x = 10, y = -55,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refresh
        })

        W:CreateCheckbox(trkContent, {
            label = L["BUFFTRACKER_STANCES"],
            db = db, key = "showStances",
            x = 10, y = -80,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refresh
        })

        trkContent:SetHeight(110)
        trkWrap:RecalcHeight()

        -- DISPLAY section
        local dspWrap, dspContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["COMMON_SECTION_DISPLAY"],
            startOpen = true,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        W:CreateCheckbox(dspContent, {
            label = L["BUFFTRACKER_SHOW_MISSING"],
            db = db, key = "showMissingOnly",
            x = 10, y = -5,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refresh
        })

        W:CreateCheckbox(dspContent, {
            label = L["BUFFTRACKER_COMBAT_ONLY"],
            db = db, key = "combatOnly",
            x = 10, y = -30,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refresh
        })

        W:CreateCheckbox(dspContent, {
            label = L["BUFFTRACKER_SHOW_COOLDOWN"],
            db = db, key = "showCooldown",
            x = 10, y = -55,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refresh
        })

        W:CreateCheckbox(dspContent, {
            label = L["BUFFTRACKER_SHOW_STACKS"],
            db = db, key = "showStacks",
            x = 10, y = -80,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refresh
        })

        W:CreateFontDropdown(dspContent, {
            db = db, x = 10, y = -110,
            globalName = "NaowhBuffTrackerFontDrop",
            onChange = refresh
        })

        W:CreateDropdown(dspContent, {
            label = L["BUFFTRACKER_GROW_DIR"],
            db = db, key = "growDirection",
            options = {"RIGHT", "LEFT", "DOWN", "UP"},
            x = 240, y = -110,
            width = 120,
            onChange = refresh
        })

        local iconSlider = W:CreateAdvancedSlider(dspContent,
            W.Colorize(L["COMMON_LABEL_ICON_SIZE"], C.ORANGE), 24, 64, -175, 1, false,
            function(val) db.iconSize = val; refresh() end,
            { value = db.iconSize })
        PlaceSlider(iconSlider, dspContent, 0, -175)

        local spacingSlider = W:CreateAdvancedSlider(dspContent,
            W.Colorize(L["BUFFTRACKER_SPACING"], C.ORANGE), 0, 20, -175, 1, false,
            function(val) db.spacing = val; refresh() end,
            { value = db.spacing })
        PlaceSlider(spacingSlider, dspContent, 240, -175)

        local textSlider = W:CreateAdvancedSlider(dspContent,
            W.Colorize(L["COMMON_LABEL_TEXT_SIZE"], C.ORANGE), 8, 24, -235, 1, false,
            function(val) db.textSize = val; refresh() end,
            { value = db.textSize })
        PlaceSlider(textSlider, dspContent, 0, -235)

        local rowSlider = W:CreateAdvancedSlider(dspContent,
            W.Colorize(L["BUFFTRACKER_ICONS_PER_ROW"], C.ORANGE), 1, 20, -235, 1, false,
            function(val) db.maxIconsPerRow = val; refresh() end,
            { value = db.maxIconsPerRow })
        PlaceSlider(rowSlider, dspContent, 240, -235)

        local reset = W:CreateButton(dspContent, { text = "Reset to Defaults", onClick = function() StaticPopup_Show("NAOWH_BUFFTRACKER_RESET") end })
        reset:SetPoint("TOPLEFT", 10, -300)

        dspContent:SetHeight(335)
        dspWrap:RecalcHeight()

        -- Relayout
        local allSections = { trkWrap, dspWrap }

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
            refresh()
            unlockCB:SetShown(db.enabled)
            sectionContainer:SetShown(db.enabled)
            RelayoutSections()
        end)
        sectionContainer:SetShown(db.enabled)

        RelayoutSections()
    end)

end
