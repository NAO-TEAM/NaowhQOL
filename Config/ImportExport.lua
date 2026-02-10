local addonName, ns = ...

local cache = {}
local W = ns.Widgets
local C = ns.COLORS

-- Styled dropdown colors (match Widgets.lua)
local DARK_BG_R, DARK_BG_G, DARK_BG_B = 0.08, 0.08, 0.08
local BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B = 0.004, 0.557, 0.906
local BTN_ORANGE_R, BTN_ORANGE_G, BTN_ORANGE_B = 1.0, 0.663, 0.0

-- Dynamic dropdown for profile selection
local function CreateDynamicDropdown(parent, opts)
    opts = opts or {}
    local width = opts.width or 160
    local height = 22

    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, height)

    -- Dropdown button
    local btn = CreateFrame("Button", nil, f, "BackdropTemplate")
    btn:SetSize(width, height)
    btn:SetPoint("TOPLEFT", 0, 0)
    btn:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]],
        edgeSize = 1,
    })
    btn:SetBackdropColor(DARK_BG_R, DARK_BG_G, DARK_BG_B, 0.95)
    btn:SetBackdropBorderColor(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 0.7)
    f.button = btn

    -- Selected text
    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", 8, 0)
    text:SetPoint("RIGHT", -20, 0)
    text:SetJustifyH("LEFT")
    text:SetTextColor(1, 1, 1, 1)
    text:SetText(opts.placeholder or "Select...")
    btn.text = text
    f.text = text

    -- Arrow
    local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetText("▼")
    arrow:SetTextColor(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 1)

    -- Dropdown menu frame
    local menu = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
    menu:SetWidth(width)
    menu:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]],
        edgeSize = 1,
    })
    menu:SetBackdropColor(DARK_BG_R, DARK_BG_G, DARK_BG_B, 0.98)
    menu:SetBackdropBorderColor(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 0.7)
    menu:SetFrameStrata("DIALOG")
    menu:SetFrameLevel(100)
    menu:Hide()
    f.menu = menu

    f.menuOpen = false
    f.menuItems = {}
    f.selectedValue = nil

    function f:SetText(str)
        text:SetText(str)
    end

    function f:GetSelectedValue()
        return f.selectedValue
    end

    function f:SetSelectedValue(val)
        f.selectedValue = val
    end

    function f:Refresh(options)
        -- Clear old items
        for _, item in ipairs(f.menuItems) do
            item:Hide()
            item:SetParent(nil)
        end
        f.menuItems = {}

        local itemHeight = 20
        for i, opt in ipairs(options) do
            local item = CreateFrame("Button", nil, menu, "BackdropTemplate")
            item:SetSize(width - 2, itemHeight)
            item:SetPoint("TOPLEFT", 1, -1 - (i - 1) * itemHeight)
            item:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
            item:SetBackdropColor(0, 0, 0, 0)

            local itemText = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            itemText:SetPoint("LEFT", 8, 0)
            itemText:SetPoint("RIGHT", -8, 0)
            itemText:SetJustifyH("LEFT")
            itemText:SetText(opt.text)
            itemText:SetTextColor(1, 1, 1, 1)

            item:SetScript("OnEnter", function(self)
                self:SetBackdropColor(BTN_ORANGE_R, BTN_ORANGE_G, BTN_ORANGE_B, 0.3)
            end)
            item:SetScript("OnLeave", function(self)
                self:SetBackdropColor(0, 0, 0, 0)
            end)
            item:SetScript("OnClick", function()
                f.selectedValue = opt.value
                text:SetText(opt.text)
                menu:Hide()
                f.menuOpen = false
                btn:SetBackdropBorderColor(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 0.7)
                if opts.onSelect then opts.onSelect(opt.value, opt.text) end
            end)

            f.menuItems[i] = item
        end

        if #options == 0 then
            menu:SetHeight(itemHeight + 2)
            local empty = CreateFrame("Frame", nil, menu)
            empty:SetSize(width - 2, itemHeight)
            empty:SetPoint("TOPLEFT", 1, -1)
            local emptyText = empty:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            emptyText:SetPoint("LEFT", 8, 0)
            emptyText:SetText(opts.emptyText or "(None)")
            f.menuItems[1] = empty
        else
            menu:SetHeight(#options * itemHeight + 2)
        end
    end

    -- Toggle menu
    btn:SetScript("OnClick", function()
        if f.menuOpen then
            menu:Hide()
            f.menuOpen = false
            btn:SetBackdropBorderColor(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 0.7)
        else
            menu:Show()
            f.menuOpen = true
            btn:SetBackdropBorderColor(BTN_ORANGE_R, BTN_ORANGE_G, BTN_ORANGE_B, 0.9)
        end
    end)

    btn:SetScript("OnEnter", function(self)
        if not f.menuOpen then
            self:SetBackdropBorderColor(BTN_ORANGE_R, BTN_ORANGE_G, BTN_ORANGE_B, 0.9)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if not f.menuOpen then
            self:SetBackdropBorderColor(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 0.7)
        end
    end)

    -- Close on world click
    f:SetScript("OnUpdate", function()
        if f.menuOpen and not menu:IsMouseOver() and not btn:IsMouseOver() then
            if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then
                menu:Hide()
                f.menuOpen = false
                btn:SetBackdropBorderColor(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 0.7)
            end
        end
    end)

    return f
end

-- Static popup for profile name input
StaticPopupDialogs["NAOWHQOL_PROFILE_NAME"] = {
    text = "%s",
    button1 = "OK",
    button2 = "Cancel",
    hasEditBox = true,
    OnShow = function(self)
        local editBox = self.editBox or self.EditBox
        if editBox then
            editBox:SetText(self.data and self.data.default or "")
            editBox:HighlightText()
        end
    end,
    OnAccept = function(self)
        local editBox = self.editBox or self.EditBox
        local name = editBox and strtrim(editBox:GetText()) or ""
        if name ~= "" and self.data and self.data.callback then
            self.data.callback(name)
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local name = strtrim(self:GetText())
        if name ~= "" and parent.data and parent.data.callback then
            parent.data.callback(name)
        end
        parent:Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["NAOWHQOL_PROFILE_CONFIRM"] = {
    text = "%s",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function(self)
        if self.data and self.data.callback then
            self.data.callback()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function ns:InitImportExport()
    local p = ns.MainFrame.Content

    W:CachedPanel(cache, "frame", p, function(f)
        local _, sc = W:CreateScrollFrame(f, 1200)

        W:CreatePageHeader(sc,
            W.Colorize("PROFILES", C.ORANGE),
            W.Colorize("Share settings between characters or with other players", C.BLUE),
            { subtitleFont = "GameFontNormalSmall", separator = false })

        -- Profile Management Section
        W:CreateSectionHeader(sc, "Profile Management", -80)

        local profileStatus = sc:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        profileStatus:SetPoint("TOPLEFT", 35, -115)
        profileStatus:SetText("")

        local function UpdateProfileStatus()
            local active = ns.SettingsIO:GetActiveProfile()
            local count = #ns.SettingsIO:GetProfileList()
            profileStatus:SetText("|cff44ff44Active: " .. active .. "|r  (" .. count .. " saved)")
        end

        -- Profile dropdown
        local profileDropdown = CreateDynamicDropdown(sc, {
            width = 160,
            placeholder = "Select Profile",
            emptyText = "(No saved profiles)",
            onSelect = function(name)
                local ok, err = ns.SettingsIO:LoadProfile(name)
                if ok then
                    UpdateProfileStatus()
                    StaticPopup_Show("NAOWH_QOL_RELOAD_IMPORT")
                else
                    profileStatus:SetText("|cffff4444" .. (err or "Failed to load") .. "|r")
                end
            end
        })
        profileDropdown:SetPoint("TOPLEFT", 35, -135)

        local function RefreshProfileDropdown()
            local profiles = ns.SettingsIO:GetProfileList()
            local options = {}
            for _, name in ipairs(profiles) do
                options[#options + 1] = { text = name, value = name }
            end
            profileDropdown:Refresh(options)
            profileDropdown:SetText(ns.SettingsIO:GetActiveProfile())
            profileDropdown:SetSelectedValue(ns.SettingsIO:GetActiveProfile())
        end

        -- Save button
        local saveBtn = W:CreateButton(sc, { text = "Save", width = 60, height = 24 })
        saveBtn:SetPoint("LEFT", profileDropdown, "RIGHT", 8, 0)
        saveBtn:SetScript("OnClick", function()
            local dialog = StaticPopup_Show("NAOWHQOL_PROFILE_NAME", "Save current settings as profile:")
            if dialog then
                dialog.data = {
                    default = ns.SettingsIO:GetActiveProfile(),
                    callback = function(name)
                        ns.SettingsIO:SaveProfile(name)
                        RefreshProfileDropdown()
                        UpdateProfileStatus()
                        profileStatus:SetText("|cff44ff44Saved: " .. name .. "|r")
                    end
                }
            end
        end)

        -- Rename button
        local renameBtn = W:CreateButton(sc, { text = "Rename", width = 70, height = 24 })
        renameBtn:SetPoint("LEFT", saveBtn, "RIGHT", 4, 0)
        renameBtn:SetScript("OnClick", function()
            local current = ns.SettingsIO:GetActiveProfile()
            if not NaowhQOL.profiles or not NaowhQOL.profiles[current] then
                profileStatus:SetText("|cffff4444Save profile first|r")
                return
            end
            local dialog = StaticPopup_Show("NAOWHQOL_PROFILE_NAME", "Rename profile '" .. current .. "' to:")
            if dialog then
                dialog.data = {
                    default = current,
                    callback = function(newName)
                        if ns.SettingsIO:RenameProfile(current, newName) then
                            RefreshProfileDropdown()
                            UpdateProfileStatus()
                            profileStatus:SetText("|cff44ff44Renamed to: " .. newName .. "|r")
                        else
                            profileStatus:SetText("|cffff4444Name already exists|r")
                        end
                    end
                }
            end
        end)

        -- Delete button
        local deleteBtn = W:CreateButton(sc, { text = "Delete", width = 60, height = 24 })
        deleteBtn:SetPoint("LEFT", renameBtn, "RIGHT", 4, 0)
        deleteBtn:SetScript("OnClick", function()
            local current = ns.SettingsIO:GetActiveProfile()
            if not NaowhQOL.profiles or not NaowhQOL.profiles[current] then
                profileStatus:SetText("|cffff4444No profile to delete|r")
                return
            end
            local dialog = StaticPopup_Show("NAOWHQOL_PROFILE_CONFIRM", "Delete profile '" .. current .. "'?")
            if dialog then
                dialog.data = {
                    callback = function()
                        ns.SettingsIO:DeleteProfile(current)
                        RefreshProfileDropdown()
                        UpdateProfileStatus()
                        profileStatus:SetText("|cff44ff44Deleted|r")
                    end
                }
            end
        end)

        -- Copy from other character section
        W:CreateSectionHeader(sc, "Copy From Character", -180)

        local selectedChar = nil

        local charProfileDropdown = CreateDynamicDropdown(sc, {
            width = 160,
            placeholder = "Select Profile",
            emptyText = "(Select character first)",
        })

        local charDropdown = CreateDynamicDropdown(sc, {
            width = 160,
            placeholder = "Select Character",
            emptyText = "(No other characters)",
            onSelect = function(charKey)
                selectedChar = charKey
                -- Refresh the profile dropdown for selected character
                local profiles = ns.SettingsIO:GetCharacterProfiles(charKey)
                local options = {}
                for _, name in ipairs(profiles) do
                    options[#options + 1] = { text = name, value = name }
                end
                charProfileDropdown:Refresh(options)
                charProfileDropdown:SetText("Select Profile")
                charProfileDropdown:SetSelectedValue(nil)
            end
        })
        charDropdown:SetPoint("TOPLEFT", 35, -215)
        charProfileDropdown:SetPoint("LEFT", charDropdown, "RIGHT", 8, 0)

        local function RefreshCharProfileDropdown()
            if not selectedChar then
                charProfileDropdown:Refresh({})
                charProfileDropdown:SetText("Select Profile")
                return
            end
            local profiles = ns.SettingsIO:GetCharacterProfiles(selectedChar)
            local options = {}
            for _, name in ipairs(profiles) do
                options[#options + 1] = { text = name, value = name }
            end
            charProfileDropdown:Refresh(options)
        end

        local function RefreshCharDropdown()
            local chars = ns.SettingsIO:GetOtherCharacters()
            local options = {}
            for _, charKey in ipairs(chars) do
                options[#options + 1] = { text = charKey, value = charKey }
            end
            charDropdown:Refresh(options)
            charDropdown:SetText("Select Character")
        end

        local copyBtn = W:CreateButton(sc, { text = "Copy", width = 60, height = 24 })
        copyBtn:SetPoint("LEFT", charProfileDropdown, "RIGHT", 8, 0)
        copyBtn:SetScript("OnClick", function()
            local charKey = charDropdown:GetSelectedValue()
            local profileName = charProfileDropdown:GetSelectedValue()
            if not charKey or not profileName then
                profileStatus:SetText("|cffff4444Select character and profile|r")
                return
            end
            local ok, err = ns.SettingsIO:CopyFromCharacter(charKey, profileName)
            if ok then
                profileStatus:SetText("|cff44ff44Copied from " .. charKey .. "|r")
                StaticPopup_Show("NAOWH_QOL_RELOAD_IMPORT")
            else
                profileStatus:SetText("|cffff4444" .. (err or "Copy failed") .. "|r")
            end
        end)

        -- Initialize dropdowns
        C_Timer.After(0.1, function()
            ns.SettingsIO:InitProfiles()
            RefreshProfileDropdown()
            RefreshCharDropdown()
            UpdateProfileStatus()
        end)

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

        W:CreateSectionHeader(sc, "Export", -270)

        local exportBtn = W:CreateButton(sc, { text = "Export Settings", width = 130, height = 26 })
        exportBtn:SetPoint("TOPLEFT", 35, -305)

        local exportHint = sc:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        exportHint:SetPoint("LEFT", exportBtn, "RIGHT", 10, 0)
        exportHint:SetText("Ctrl+A, Ctrl+C to copy")

        local exportBox = MakeTextBox(sc, -338, 80, true)

        exportBtn:SetScript("OnClick", function()
            if not ns.SettingsIO then return end
            local str = ns.SettingsIO:Export()
            exportBox:SetText(str)
            exportBox:SetFocus(); exportBox:HighlightText()
        end)

        W:CreateSectionHeader(sc, "Import", -435)

        local importBox = MakeTextBox(sc, -470, 80, false)

        local loadBtn = W:CreateButton(sc, { text = "Load", width = 80, height = 26 })
        loadBtn:SetPoint("TOPLEFT", 35, -558)

        local statusText = sc:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        statusText:SetPoint("LEFT", loadBtn, "RIGHT", 10, 0)
        statusText:SetText("")

        local checkContainer = CreateFrame("Frame", nil, sc)
        checkContainer:SetPoint("TOPLEFT", 35, -590); checkContainer:SetSize(430, 1)

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
