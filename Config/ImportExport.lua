local addonName, ns = ...

local cache = {}
local W = ns.Widgets
local C = ns.COLORS

function ns:InitImportExport()
    local p = ns.MainFrame.Content

    W:CachedPanel(cache, "frame", p, function(f)
        local _, sc = W:CreateScrollFrame(f, 900)

        W:CreatePageHeader(sc,
            W.Colorize("PROFILES", C.ORANGE),
            W.Colorize("Share settings between characters or with other players", C.BLUE),
            { subtitleFont = "GameFontNormalSmall", separator = false })

        -- Multi-line edit box helper
        local function MakeTextBox(parent, y, height, readOnly)
            local bg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
            bg:SetSize(430, height)
            bg:SetPoint("TOPLEFT", 35, y)
            bg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            bg:SetBackdropColor(0.04, 0.04, 0.04, 1)
            bg:SetBackdropBorderColor(0, 0, 0, 1)

            local sf = CreateFrame("ScrollFrame", nil, bg, "UIPanelScrollFrameTemplate")
            sf:SetPoint("TOPLEFT", 6, -6); sf:SetPoint("BOTTOMRIGHT", -20, 6)

            local box = CreateFrame("EditBox", nil, sf)
            box:SetWidth(sf:GetWidth() or 400)
            box:SetFontObject("GameFontHighlightSmall")
            box:SetAutoFocus(false); box:SetMultiLine(true)
            box:SetMaxLetters(0)
            sf:SetScrollChild(box)

            if readOnly then
                local storedText = ""
                box:SetScript("OnTextChanged", function(self, userInput)
                    if userInput then
                        self:SetText(storedText)
                        self:HighlightText()
                    else
                        storedText = self:GetText()
                    end
                end)
                box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
                box:SetScript("OnCursorChanged", function(self) self:HighlightText() end)
                box:SetScript("OnEditFocusLost", function(self) self:SetText(""); self:HighlightText(0, 0) end)
            end
            box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

            return box, bg
        end

        W:CreateSectionHeader(sc, "Export", -80)

        local exportBtn = W:CreateButton(sc, { text = "Export Settings", width = 130, height = 26 })
        exportBtn:SetPoint("TOPLEFT", 35, -115)

        local exportHint = sc:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        exportHint:SetPoint("LEFT", exportBtn, "RIGHT", 10, 0)
        exportHint:SetText("Ctrl+A, Ctrl+C to copy")

        local exportBox = MakeTextBox(sc, -148, 80, true)

        exportBtn:SetScript("OnClick", function()
            if not ns.SettingsIO then return end
            local str = ns.SettingsIO:Export()
            exportBox:SetText(str)
            exportBox:SetFocus(); exportBox:HighlightText()
        end)

        W:CreateSectionHeader(sc, "Import", -245)

        local importBox = MakeTextBox(sc, -280, 80, false)

        local loadBtn = W:CreateButton(sc, { text = "Load", width = 80, height = 26 })
        loadBtn:SetPoint("TOPLEFT", 35, -368)

        local statusText = sc:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        statusText:SetPoint("LEFT", loadBtn, "RIGHT", 10, 0)
        statusText:SetText("")

        local checkContainer = CreateFrame("Frame", nil, sc)
        checkContainer:SetPoint("TOPLEFT", 35, -400); checkContainer:SetSize(430, 1)

        local checkBoxes = {}
        local checkPool = {}
        local importBtn

        local function ClearChecks()
            for _, cb in pairs(checkBoxes) do cb:Hide() end
            checkBoxes = {}
            if importBtn then importBtn:Hide() end
            statusText:SetText("")
        end

        local function GetPooledCheckbox()
            for _, cb in ipairs(checkPool) do
                if not cb:IsShown() then return cb end
            end
            local cb = W:CreateCheckbox(checkContainer, {
                template = "interface",
            })
            checkPool[#checkPool + 1] = cb
            return cb
        end

        local function BuildChecks(foundKeys)
            ClearChecks()
            if not foundKeys then
                statusText:SetText("|cffff4444Invalid string.|r")
                return
            end

            local yOff = 0
            local count = 0
            for _, m in ipairs(ns.SettingsIO.modules) do
                if foundKeys[m.key] then
                    local cb = GetPooledCheckbox()
                    cb:ClearAllPoints()
                    cb:SetPoint("TOPLEFT", 0, yOff)
                    cb.Text:SetText(m.label)
                    cb:SetChecked(true)
                    cb:Show()
                    checkBoxes[m.key] = cb
                    yOff = yOff - 28
                    count = count + 1
                end
            end

            if count == 0 then
                statusText:SetText("|cffff4444No recognized modules in string.|r")
                return
            end

            statusText:SetText("|cff44ff44" .. count .. " modules found.|r")

            if not importBtn then
                importBtn = W:CreateButton(checkContainer, {
                    text = "Import Selected",
                    width = 130,
                    height = 26,
                    onClick = function()
                        local selected = {}
                        for key, cb in pairs(checkBoxes) do
                            if cb:GetChecked() then selected[key] = true end
                        end
                        local raw = strtrim(importBox:GetText())
                        local ok, err = ns.SettingsIO:Import(raw, selected)
                        if ok then
                            statusText:SetText("|cff44ff44Imported! Reload UI to apply.|r")
                            StaticPopup_Show("NAOWH_QOL_RELOAD_IMPORT")
                        else
                            statusText:SetText("|cffff4444" .. (err or "Import failed.") .. "|r")
                        end
                    end
                })
            end
            importBtn:ClearAllPoints()
            importBtn:SetPoint("TOPLEFT", 0, yOff - 8)
            importBtn:Show()

            checkContainer:SetHeight(math.abs(yOff) + 40)
        end

        loadBtn:SetScript("OnClick", function()
            local raw = strtrim(importBox:GetText())
            if raw == "" then ClearChecks(); statusText:SetText("|cffff4444Paste a string first.|r"); return end
            local found = ns.SettingsIO:Preview(raw)
            BuildChecks(found)
        end)

    end)
end
