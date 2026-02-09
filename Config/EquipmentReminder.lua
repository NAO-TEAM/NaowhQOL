local addonName, ns = ...

local cache = {}
local W = ns.Widgets
local C = ns.COLORS

function ns:InitEquipmentReminder()
    local p = ns.MainFrame.Content
    local db = NaowhQOL.equipmentReminder

    W:CachedPanel(cache, "eqFrame", p, function(f)
        local sf, sc = W:CreateScrollFrame(f, 700)

        W:CreatePageHeader(sc,
            {{"EQUIPMENT ", C.BLUE}, {"REMINDER", C.ORANGE}},
            W.Colorize("Display equipped trinkets and weapons when entering instances or during ready checks", C.GRAY))

        -- Master toggle
        local toggleArea = CreateFrame("Frame", nil, sc, "BackdropTemplate")
        toggleArea:SetSize(460, 38)
        toggleArea:SetPoint("TOPLEFT", 10, -75)
        toggleArea:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
        toggleArea:SetBackdropColor(0.01, 0.56, 0.91, 0.08)

        local masterCB = W:CreateCheckbox(toggleArea, {
            label = "Enable Equipment Reminder",
            db = db, key = "enabled",
            x = 15, y = -8,
            isMaster = true,
        })

        -- Section container
        local sectionContainer = CreateFrame("Frame", nil, sc)
        sectionContainer:SetPoint("TOPLEFT", toggleArea, "BOTTOMLEFT", 0, -10)
        sectionContainer:SetPoint("RIGHT", sc, "RIGHT", -10, 0)
        sectionContainer:SetHeight(400)

        local RelayoutSections

        -- TRIGGERS section
        local triggerWrap, triggerContent = W:CreateCollapsibleSection(sectionContainer, {
            text = "TRIGGERS",
            startOpen = true,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local triggerDesc = triggerContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        triggerDesc:SetPoint("TOPLEFT", 0, -5)
        triggerDesc:SetText(W.Colorize("Choose when to show the equipment reminder", C.GRAY))

        W:CreateCheckbox(triggerContent, {
            label = "Show on instance entry",
            tooltip = "Display equipment when entering dungeons, raids, or scenarios",
            db = db, key = "showOnInstance",
            x = 0, y = -30,
        })

        W:CreateCheckbox(triggerContent, {
            label = "Show on ready check",
            tooltip = "Display equipment when a ready check is initiated",
            db = db, key = "showOnReadyCheck",
            x = 0, y = -55,
        })

        triggerContent:SetHeight(90)
        triggerWrap:RecalcHeight()

        -- DISPLAY section
        local displayWrap, displayContent = W:CreateCollapsibleSection(sectionContainer, {
            text = "DISPLAY",
            startOpen = true,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        W:CreateSlider(displayContent, {
            label = "Auto-Hide Delay",
            min = 0, max = 30, step = 1,
            db = db, key = "autoHideDelay",
            x = 0, y = -10,
            width = 200,
            tooltip = "Seconds before auto-hiding (0 = manual close only)",
            onChange = function(val) db.autoHideDelay = val end,
        })

        W:CreateSlider(displayContent, {
            label = "Icon Size",
            min = 32, max = 64, step = 2,
            db = db, key = "iconSize",
            x = 0, y = -70,
            width = 200,
            tooltip = "Size of equipment icons",
            onChange = function(val)
                db.iconSize = val
                -- Force recreation of frame on next show
                if _G["NaowhQOL_EquipmentReminder"] then
                    _G["NaowhQOL_EquipmentReminder"]:Hide()
                    _G["NaowhQOL_EquipmentReminder"] = nil
                end
            end,
        })

        displayContent:SetHeight(130)
        displayWrap:RecalcHeight()

        -- PREVIEW section
        local previewWrap, previewContent = W:CreateCollapsibleSection(sectionContainer, {
            text = "PREVIEW",
            startOpen = true,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local previewBtn = W:CreateButton(previewContent, {
            text = "Show Equipment Frame",
            onClick = function()
                if ns.EquipmentReminder and ns.EquipmentReminder.ShowFrame then
                    ns.EquipmentReminder.ShowFrame()
                end
            end,
        })
        previewBtn:SetPoint("TOPLEFT", 0, -10)

        local hideBtn = W:CreateButton(previewContent, {
            text = "Hide Equipment Frame",
            onClick = function()
                if ns.EquipmentReminder and ns.EquipmentReminder.HideFrame then
                    ns.EquipmentReminder.HideFrame()
                end
            end,
        })
        hideBtn:SetPoint("LEFT", previewBtn, "RIGHT", 10, 0)

        previewContent:SetHeight(50)
        previewWrap:RecalcHeight()

        -- Relayout sections
        local allSections = { triggerWrap, displayWrap, previewWrap }

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

            local totalH = 75 + 38 + 10
            if db.enabled then
                for _, s in ipairs(allSections) do
                    totalH = totalH + s:GetHeight() + 12
                end
            end
            sc:SetHeight(math.max(totalH + 40, 600))
        end

        masterCB:SetScript("OnClick", function(self)
            db.enabled = self:GetChecked() and true or false
            sectionContainer:SetShown(db.enabled)
            RelayoutSections()
        end)
        sectionContainer:SetShown(db.enabled)

        -- Restore defaults button
        local restoreBtn = W:CreateRestoreDefaultsButton({
            moduleName = "equipmentReminder",
            parent = sc,
        })
        restoreBtn:SetPoint("BOTTOMLEFT", sc, "BOTTOMLEFT", 10, 20)

        RelayoutSections()
    end)
end
