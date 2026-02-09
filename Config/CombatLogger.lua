local addonName, ns = ...

local cache = {}
local W = ns.Widgets
local C = ns.COLORS

local statusRef, zoneRef, rebuildInstances

function ns:InitCombatLogger()
    local p = ns.MainFrame.Content
    local db = NaowhQOL.combatLogger

    W:CachedPanel(cache, "clFrame", p, function(f)
        local sf, sc = W:CreateScrollFrame(f, 700)

        W:CreatePageHeader(sc,
            {{"COMBAT ", C.BLUE}, {"LOGGER", C.ORANGE}},
            W.Colorize("Automatic combat log management for raids & M+", C.GRAY))

        -- on/off toggle
        local killArea = CreateFrame("Frame", nil, sc, "BackdropTemplate")
        killArea:SetSize(460, 38)
        killArea:SetPoint("TOPLEFT", 10, -75)
        killArea:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
        killArea:SetBackdropColor(0.01, 0.56, 0.91, 0.08)

        local masterCB = W:CreateCheckbox(killArea, {
            label = "Enable Combat Logger",
            db = db, key = "enabled",
            x = 15, y = -8,
            isMaster = true,
        })

        -- Section container
        local sectionContainer = CreateFrame("Frame", nil, sc)
        sectionContainer:SetPoint("TOPLEFT", killArea, "BOTTOMLEFT", 0, -10)
        sectionContainer:SetPoint("RIGHT", sc, "RIGHT", -10, 0)
        sectionContainer:SetHeight(500)

        local RelayoutSections

        -- STATUS section
        local statWrap, statContent = W:CreateCollapsibleSection(sectionContainer, {
            text = "STATUS",
            startOpen = true,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        statusRef = statContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        statusRef:SetPoint("TOPLEFT", 10, -5)

        zoneRef = statContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        zoneRef:SetPoint("TOPLEFT", 10, -25)

        statContent:SetHeight(50)
        statWrap:RecalcHeight()

        -- SAVED INSTANCES section
        local instWrap, instContent = W:CreateCollapsibleSection(sectionContainer, {
            text = "SAVED INSTANCES",
            startOpen = true,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local instScroll = CreateFrame("ScrollFrame", "NaowhQOL_CombatLoggerScroll", instContent, "UIPanelScrollFrameTemplate")
        instScroll:SetPoint("TOPLEFT", 0, -5)
        instScroll:SetSize(420, 220)

        local instChild = CreateFrame("Frame", nil, instScroll)
        instScroll:SetScrollChild(instChild)
        instChild:SetWidth(400)

        rebuildInstances = function()
            local children = { instChild:GetChildren() }
            for _, child in ipairs(children) do child:Hide() end
            for i = 1, instChild:GetNumRegions() do
                local region = select(i, instChild:GetRegions())
                if region then region:Hide() end
            end

            db.instances = db.instances or {}
            local yOff = 0
            local count = 0

            local keys = {}
            for key in pairs(db.instances) do keys[#keys + 1] = key end
            table.sort(keys)

            for _, key in ipairs(keys) do
                local entry = db.instances[key]
                if entry then
                    count = count + 1

                    local row = CreateFrame("Frame", nil, instChild, "BackdropTemplate")
                    row:SetSize(390, 28)
                    row:SetPoint("TOPLEFT", 0, yOff)
                    row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
                        edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
                    row:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
                    row:SetBackdropBorderColor(0, 0, 0, 1)
                    row:Show()

                    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    label:SetPoint("LEFT", 8, 0)
                    label:SetWidth(230)
                    label:SetJustifyH("LEFT")

                    local displayName = entry.name or ""
                    local displayDiff = entry.diffName or ""
                    if displayName == "" then
                        local instID, diff = key:match("^(%d+):(%d+)$")
                        displayName = "Instance " .. (instID or "?")
                        displayDiff = "Difficulty " .. (diff or "?")
                    end
                    label:SetText(displayName .. " " .. W.Colorize("(" .. displayDiff .. ")", C.GRAY))

                    local status = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    status:SetPoint("RIGHT", -85, 0)
                    status:SetText(entry.enabled and W.Colorize("ON", C.SUCCESS) or W.Colorize("OFF", C.ERROR))

                    local deleteBtn = W:CreateButton(row, {
                        text = "|cffff0000X|r",
                        width = 22,
                        height = 20,
                        onClick = function()
                            db.instances[key] = nil
                            rebuildInstances()
                        end
                    })
                    deleteBtn:SetPoint("RIGHT", -5, 0)

                    local toggleBtn = W:CreateButton(row, {
                        text = "Toggle",
                        width = 50,
                        height = 20,
                        onClick = function()
                            entry.enabled = not entry.enabled
                            rebuildInstances()
                        end
                    })
                    toggleBtn:SetPoint("RIGHT", deleteBtn, "LEFT", -4, 0)

                    yOff = yOff - 32
                end
            end

            if count == 0 then
                local emptyText = instChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                emptyText:SetPoint("TOPLEFT", 0, 0)
                emptyText:SetText(W.Colorize("No saved instances yet. Enter a raid or M+ dungeon.", C.GRAY))
            end

            instChild:SetHeight(math.max(1, math.abs(yOff)))
        end

        local resetBtn = W:CreateButton(instContent, {
            text = "Reset All Instances",
            width = 160,
            height = 26,
            onClick = function()
                StaticPopup_Show("NAOWHQOL_COMBATLOG_RESET")
            end
        })
        resetBtn:SetPoint("TOPLEFT", 0, -235)

        instContent:SetHeight(270)
        instWrap:RecalcHeight()

        -- Relayout
        local allSections = { statWrap, instWrap }

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
            if not db.enabled and LoggingCombat() then LoggingCombat(false) end
            sectionContainer:SetShown(db.enabled)
            RelayoutSections()
        end)
        sectionContainer:SetShown(db.enabled)

        -- Restore defaults button
        local restoreBtn = W:CreateRestoreDefaultsButton({
            moduleName = "combatLogger",
            parent = sc,
        })
        restoreBtn:SetPoint("BOTTOMLEFT", sc, "BOTTOMLEFT", 10, 20)

        RelayoutSections()
    end)

    -- Refresh dynamic content each time tab is shown
    if statusRef then
        if LoggingCombat() then
            statusRef:SetText("Status: " .. W.Colorize("LOGGING ACTIVE", C.SUCCESS))
        else
            statusRef:SetText("Status: " .. W.Colorize("NOT LOGGING", C.GRAY))
        end
    end

    if zoneRef and ns.ZoneUtil then
        local zone = ns.ZoneUtil.GetCurrentZone()
        if ns.ZoneUtil.IsInRaid() or ns.ZoneUtil.IsInMythicPlus() then
            zoneRef:SetText("Current: " .. W.Colorize(zone.zoneName, C.ORANGE)
                .. " (" .. zone.difficultyName .. ")")
        else
            zoneRef:SetText("Current: " .. W.Colorize("Not in trackable content", C.GRAY))
        end
    end

    if rebuildInstances then
        rebuildInstances()
    end

    if not StaticPopupDialogs["NAOWHQOL_COMBATLOG_RESET"] then
        StaticPopupDialogs["NAOWHQOL_COMBATLOG_RESET"] = {
            text = W.Colorize("Naowh QOL", C.BLUE) .. "\n\n"
                .. "Clear all saved instance logging preferences?\n"
                .. "You will be prompted again next time you enter each instance.",
            button1 = "Clear All",
            button2 = "Cancel",
            OnAccept = function()
                NaowhQOL.combatLogger.instances = {}
                if cache["clFrame"] then cache["clFrame"]:Hide(); cache["clFrame"] = nil end
                if ns.MainFrame and ns.MainFrame.ResetContent then
                    ns.MainFrame:ResetContent()
                    ns:InitCombatLogger()
                end
            end,
            timeout = 0, whileDead = true, hideOnEscape = true,
        }
    end
end
