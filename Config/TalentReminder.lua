local addonName, ns = ...

local cache = {}
local W = ns.Widgets
local C = ns.COLORS

local rebuildLoadouts

function ns:InitTalentReminder()
    local p = ns.MainFrame.Content
    local db = NaowhQOL.talentReminder

    W:CachedPanel(cache, "trFrame", p, function(f)
        local sf, sc = W:CreateScrollFrame(f, 700)

        W:CreatePageHeader(sc,
            {{"TALENT ", C.BLUE}, {"REMINDER", C.ORANGE}},
            W.Colorize("Save and restore talent loadouts per dungeon and raid boss", C.GRAY))

        -- Master toggle
        local toggleArea = CreateFrame("Frame", nil, sc, "BackdropTemplate")
        toggleArea:SetSize(460, 38)
        toggleArea:SetPoint("TOPLEFT", 10, -75)
        toggleArea:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
        toggleArea:SetBackdropColor(0.01, 0.56, 0.91, 0.08)

        local masterCB = W:CreateCheckbox(toggleArea, {
            label = "Enable Talent Reminder",
            db = db, key = "enabled",
            x = 15, y = -8,
            isMaster = true,
        })

        -- Section container
        local sectionContainer = CreateFrame("Frame", nil, sc)
        sectionContainer:SetPoint("TOPLEFT", toggleArea, "BOTTOMLEFT", 0, -10)
        sectionContainer:SetPoint("RIGHT", sc, "RIGHT", -10, 0)
        sectionContainer:SetHeight(500)

        local RelayoutSections

        -- SAVED LOADOUTS section
        local loadWrap, loadContent = W:CreateCollapsibleSection(sectionContainer, {
            text = "SAVED LOADOUTS",
            startOpen = true,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local loadScroll = CreateFrame("ScrollFrame", "NaowhQOL_TalentReminderScroll", loadContent, "UIPanelScrollFrameTemplate")
        loadScroll:SetPoint("TOPLEFT", 0, -5)
        loadScroll:SetSize(420, 280)

        local loadChild = CreateFrame("Frame", nil, loadScroll)
        loadScroll:SetScrollChild(loadChild)
        loadChild:SetWidth(400)

        local specSections = {}  -- Track collapsible spec sections
        local expandedSpecs = {}  -- Remember which specs are expanded

        rebuildLoadouts = function()
            -- Clear existing children
            local children = { loadChild:GetChildren() }
            for _, child in ipairs(children) do child:Hide() end
            for i = 1, loadChild:GetNumRegions() do
                local region = select(i, loadChild:GetRegions())
                if region then region:Hide() end
            end
            specSections = {}

            db.loadouts = db.loadouts or {}

            -- Group loadouts by specID
            local specGroups = {}
            for key, entry in pairs(db.loadouts) do
                local specID = key:match("^(%d+):")
                specID = tonumber(specID) or 0
                if not specGroups[specID] then
                    specGroups[specID] = {}
                end
                specGroups[specID][key] = entry
            end

            -- Get sorted spec IDs
            local specIDs = {}
            for specID in pairs(specGroups) do
                specIDs[#specIDs + 1] = specID
            end
            table.sort(specIDs)

            if #specIDs == 0 then
                local emptyText = loadChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                emptyText:SetPoint("TOPLEFT", 0, 0)
                emptyText:SetText(W.Colorize("No saved loadouts yet.\nEnter a Mythic dungeon or target a raid boss.", C.GRAY))
                loadChild:SetHeight(40)
                return
            end

            local yOff = 0

            for _, specID in ipairs(specIDs) do
                local entries = specGroups[specID]

                -- Get spec name
                local specName = "Unknown Spec"
                local _, name, _, icon = GetSpecializationInfoByID(specID)
                if name then specName = name end

                -- Create collapsible header for this spec
                local specHeader = CreateFrame("Button", nil, loadChild, "BackdropTemplate")
                specHeader:SetSize(390, 26)
                specHeader:SetPoint("TOPLEFT", 0, yOff)
                specHeader:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
                specHeader:SetBackdropColor(0.01, 0.56, 0.91, 0.2)
                -- Default to expanded, remember state
                if expandedSpecs[specID] == nil then
                    expandedSpecs[specID] = true
                end
                specHeader.expanded = expandedSpecs[specID]
                specHeader:Show()

                local arrow = specHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                arrow:SetPoint("LEFT", 8, 0)
                arrow:SetText(specHeader.expanded and "v" or ">")
                arrow:SetTextColor(1, 0.66, 0)

                local specLabel = specHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                specLabel:SetPoint("LEFT", arrow, "RIGHT", 6, 0)
                specLabel:SetText(W.Colorize(specName, C.ORANGE))

                -- Container for this spec's entries
                local specContainer = CreateFrame("Frame", nil, loadChild)
                specContainer:SetPoint("TOPLEFT", 0, yOff - 28)
                specContainer:SetWidth(390)
                specContainer:SetShown(specHeader.expanded)

                specSections[specID] = { header = specHeader, container = specContainer, arrow = arrow }

                -- Build entries for this spec
                local keys = {}
                for key in pairs(entries) do keys[#keys + 1] = key end
                table.sort(keys)

                local entryYOff = 0
                for _, key in ipairs(keys) do
                    local entry = entries[key]

                    local row = CreateFrame("Frame", nil, specContainer, "BackdropTemplate")
                    row:SetSize(380, 28)
                    row:SetPoint("TOPLEFT", 10, entryYOff)
                    row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
                        edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
                    row:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
                    row:SetBackdropBorderColor(0, 0, 0, 1)
                    row:Show()

                    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    label:SetPoint("LEFT", 8, 0)
                    label:SetWidth(240)
                    label:SetJustifyH("LEFT")

                    local displayName = entry.name or "Unknown"
                    local diffText = entry.diffName and (" (" .. entry.diffName .. ")") or ""
                    local configText = entry.configName and (" - " .. W.Colorize(entry.configName, C.SUCCESS)) or ""
                    label:SetText(displayName .. W.Colorize(diffText, C.GRAY) .. configText)

                    local deleteBtn = W:CreateButton(row, { text = "|cffff0000X|r", width = 22, height = 18, onClick = function()
                        db.loadouts[key] = nil
                        rebuildLoadouts()
                    end })
                    deleteBtn:SetPoint("RIGHT", -5, 0)

                    entryYOff = entryYOff - 30
                end

                local containerHeight = math.abs(entryYOff)
                specContainer:SetHeight(math.max(1, containerHeight))

                -- Toggle collapse
                specHeader:SetScript("OnClick", function(self)
                    self.expanded = not self.expanded
                    expandedSpecs[specID] = self.expanded
                    rebuildLoadouts()
                end)

                yOff = yOff - 28 - (specHeader.expanded and containerHeight or 0) - 6
            end

            loadChild:SetHeight(math.max(1, math.abs(yOff)))
        end

        local resetBtn = W:CreateButton(loadContent, { text = "Clear All Loadouts", onClick = function()
            StaticPopup_Show("NAOWHQOL_TALENT_RESET")
        end })
        resetBtn:SetPoint("TOPLEFT", 0, -295)

        loadContent:SetHeight(330)
        loadWrap:RecalcHeight()

        -- Relayout
        local allSections = { loadWrap }

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
            moduleName = "talentReminder",
            parent = sc,
        })
        restoreBtn:SetPoint("BOTTOMLEFT", sc, "BOTTOMLEFT", 10, 20)

        RelayoutSections()
    end)

    if rebuildLoadouts then
        rebuildLoadouts()
    end

    if not StaticPopupDialogs["NAOWHQOL_TALENT_RESET"] then
        StaticPopupDialogs["NAOWHQOL_TALENT_RESET"] = {
            text = W.Colorize("Naowh QOL", C.BLUE) .. "\n\n"
                .. "Clear all saved talent loadouts?\n"
                .. "You will be prompted again for each dungeon/boss.",
            button1 = "Clear All",
            button2 = "Cancel",
            OnAccept = function()
                NaowhQOL.talentReminder.loadouts = {}
                if cache["trFrame"] then cache["trFrame"]:Hide(); cache["trFrame"] = nil end
                if ns.MainFrame and ns.MainFrame.ResetContent then
                    ns.MainFrame:ResetContent()
                    ns:InitTalentReminder()
                end
            end,
            timeout = 0, whileDead = true, hideOnEscape = true,
        }
    end
end
