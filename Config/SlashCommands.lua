local addonName, ns = ...
local L = ns.L

local W = ns.Widgets
local C = ns.COLORS

local panelCache = {}

-- Forward declarations for dialog functions
local CreateAddDialog, ShowAddDialog

-- Build the UI panel
local function BuildPanel(parent)
    local sf, sc = W:CreateScrollFrame(parent, 800)

    local title, subtitle, sep = W:CreatePageHeader(sc, {
        {"SLASH ", C.BLUE},
        {"COMMANDS", C.ORANGE}
    }, L["SLASH_SUBTITLE"])

    local yPos = -80

    -- Master enable toggle
    local enableCB = W:CreateCheckbox(sc, {
        label = L["SLASH_ENABLE"],
        db = NaowhQOL.slashCommands,
        key = "enabled",
        x = 30,
        y = yPos,
        onChange = function(val)
            ns.SlashCommands:RefreshAll()
        end
    })
    yPos = yPos - 50

    -- Command list container
    local listContainer = CreateFrame("Frame", nil, sc)
    listContainer:SetPoint("TOPLEFT", 30, yPos)
    listContainer:SetPoint("RIGHT", sc, "RIGHT", -30, 0)
    listContainer:SetHeight(500)

    local function RefreshList()
        -- Clear existing children
        for i = 1, listContainer:GetNumChildren() do
            local child = select(i, listContainer:GetChildren())
            if child then child:Hide() end
        end

        local db = NaowhQOL.slashCommands
        local rowY = 0
        local ROW_H = 36

        -- All command rows
        local hasCommands = db.commands and #db.commands > 0
        for i, cmd in ipairs(db.commands or {}) do
            rowY = rowY - ROW_H

            local row = CreateFrame("Frame", nil, listContainer, "BackdropTemplate")
            row:SetSize(430, ROW_H - 4)
            row:SetPoint("TOPLEFT", 0, rowY)
            row:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
            row:SetBackdropColor(0.08, 0.08, 0.08, 0.5)

            -- Enable toggle
            local toggle = W:CreateCheckbox(row, {
                checked = cmd.enabled,
                x = 4, y = 0,
                point = "LEFT",
                template = "chat",
            })
            toggle:SetSize(22, 22)
            toggle:SetScript("OnClick", function(self)
                cmd.enabled = self:GetChecked()
                ns.SlashCommands:RefreshAll()
            end)

            -- Command name
            local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            nameText:SetPoint("LEFT", toggle, "RIGHT", 8, 0)
            nameText:SetText("/" .. cmd.name)
            nameText:SetWidth(100)
            nameText:SetJustifyH("LEFT")

            -- Action description
            local actionText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            actionText:SetPoint("LEFT", nameText, "RIGHT", 8, 0)
            actionText:SetWidth(200)
            actionText:SetJustifyH("LEFT")

            local actionType = cmd.actionType or "frame"
            if actionType == "command" then
                actionText:SetText(L["SLASH_PREFIX_RUNS"] .. (cmd.command or ""))
            else
                -- Find friendly name for frame
                local frameName = cmd.frame or ""
                local friendlyName = frameName
                for _, known in ipairs(ns.SlashCommands.KNOWN_FRAMES) do
                    if known.value == frameName then
                        friendlyName = known.name
                        break
                    end
                end
                if friendlyName == "" then
                    friendlyName = cmd.description or "Unknown"
                end
                actionText:SetText(L["SLASH_PREFIX_OPENS"] .. friendlyName)
            end

            -- Delete button
            local deleteBtn = W:CreateButton(row, { text = L["SLASH_DEL"], width = 40, onClick = function()
                table.remove(db.commands, i)
                ns.SlashCommands:RefreshAll()
                RefreshList()
            end })
            deleteBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        end

        if not hasCommands then
            rowY = rowY - 24
            local noCommands = listContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            noCommands:SetPoint("TOPLEFT", 10, rowY)
            noCommands:SetText(L["SLASH_NO_COMMANDS"])
        end

        rowY = rowY - 45

        -- Add Command button
        local addBtn = W:CreateButton(listContainer, { text = L["SLASH_ADD"], onClick = function()
            -- Show add dialog
            if not NaowhQOL_AddCommandDialog then
                CreateAddDialog()
            end
            ShowAddDialog(RefreshList)
        end })
        addBtn:SetPoint("TOPLEFT", 0, rowY)

        -- Restore Defaults button
        local restoreBtn = W:CreateButton(listContainer, { text = L["SLASH_RESTORE"], onClick = function()
            local defaults = {
                { name = "cdm", frame = "CooldownViewerSettings", enabled = true, default = true },
                { name = "em", frame = "EditModeManagerFrame", enabled = true, default = true },
                { name = "kb", frame = "QuickKeybindFrame", enabled = true, default = true },
            }
            -- Add missing defaults
            for _, def in ipairs(defaults) do
                local exists = false
                for _, cmd in ipairs(db.commands or {}) do
                    if cmd.name == def.name then
                        exists = true
                        break
                    end
                end
                if not exists then
                    table.insert(db.commands, def)
                end
            end
            ns.SlashCommands:RefreshAll()
            RefreshList()
        end })
        restoreBtn:SetPoint("LEFT", addBtn, "RIGHT", 10, 0)

        -- Update container height
        listContainer:SetHeight(math.abs(rowY) + 50)
        sc:SetHeight(math.abs(yPos) + math.abs(rowY) + 100)
    end

    RefreshList()

    return sf
end

-- Add dialog with searchable frame list
local addDialog = nil
local frameListButtons = {}

local function RefreshFrameList(popup, filter)
    local listContent = popup.listContent
    filter = strlower(filter or "")

    -- Hide all existing buttons
    for _, btn in ipairs(frameListButtons) do
        btn:Hide()
    end

    local y = 0
    local btnIndex = 0

    -- Add "Custom" option at the top if user is typing something not in the list
    local hasExactMatch = false
    for _, frame in ipairs(ns.SlashCommands.KNOWN_FRAMES) do
        if strlower(frame.name) == filter or strlower(frame.value) == filter then
            hasExactMatch = true
            break
        end
    end

    -- Show custom option if filter has text and no exact match
    if filter ~= "" and not hasExactMatch then
        btnIndex = btnIndex + 1
        local btn = frameListButtons[btnIndex]

        if not btn then
            btn = CreateFrame("Button", nil, listContent, "BackdropTemplate")
            btn:SetSize(295, 22)
            btn:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            btn.text:SetPoint("LEFT", 6, 0)
            btn.text:SetJustifyH("LEFT")
            frameListButtons[btnIndex] = btn
        end

        btn:SetPoint("TOPLEFT", 0, y)
        btn:SetBackdropColor(0, 0, 0, 0)
        btn.text:SetText(W.Colorize("Custom: ", C.ORANGE) .. popup.searchBox:GetText() .. W.Colorize(" (use exact frame name)", C.GRAY))
        btn.frameValue = popup.searchBox:GetText()
        btn.frameName = popup.searchBox:GetText()
        btn.isCustom = true

        btn:SetScript("OnClick", function(self)
            popup.selectedFrame = self.frameValue
            popup.selectedFrameName = self.frameName
            -- Highlight selected
            for _, b in ipairs(frameListButtons) do
                if b:IsShown() then
                    b:SetBackdropColor(0, 0, 0, 0)
                end
            end
            self:SetBackdropColor(1, 0.66, 0, 0.3)
        end)

        btn:SetScript("OnEnter", function(self)
            if popup.selectedFrame ~= self.frameValue then
                self:SetBackdropColor(0.01, 0.56, 0.91, 0.2)
            end
        end)

        btn:SetScript("OnLeave", function(self)
            if popup.selectedFrame ~= self.frameValue then
                self:SetBackdropColor(0, 0, 0, 0)
            end
        end)

        btn:Show()
        y = y - 24
    end

    -- Show matching frames from KNOWN_FRAMES
    for _, frame in ipairs(ns.SlashCommands.KNOWN_FRAMES) do
        local matchName = strlower(frame.name)
        local matchValue = strlower(frame.value)
        local matchCat = strlower(frame.category or "")

        if filter == "" or
           matchName:find(filter, 1, true) or
           matchValue:find(filter, 1, true) or
           matchCat:find(filter, 1, true) then

            btnIndex = btnIndex + 1
            local btn = frameListButtons[btnIndex]

            if not btn then
                btn = CreateFrame("Button", nil, listContent, "BackdropTemplate")
                btn:SetSize(295, 22)
                btn:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
                btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                btn.text:SetPoint("LEFT", 6, 0)
                btn.text:SetJustifyH("LEFT")
                frameListButtons[btnIndex] = btn
            end

            btn:SetPoint("TOPLEFT", 0, y)
            btn:SetBackdropColor(0, 0, 0, 0)
            btn.text:SetText(frame.name .. W.Colorize(" (" .. frame.category .. ")", C.GRAY))
            btn.frameValue = frame.value
            btn.frameName = frame.name
            btn.isCustom = false

            btn:SetScript("OnClick", function(self)
                popup.selectedFrame = self.frameValue
                popup.selectedFrameName = self.frameName
                popup.searchBox:SetText(self.frameName)
                popup.searchBox:ClearFocus()
                -- Highlight selected
                for _, b in ipairs(frameListButtons) do
                    if b:IsShown() then
                        b:SetBackdropColor(0, 0, 0, 0)
                    end
                end
                self:SetBackdropColor(1, 0.66, 0, 0.3)
            end)

            btn:SetScript("OnEnter", function(self)
                if popup.selectedFrame ~= self.frameValue then
                    self:SetBackdropColor(0.01, 0.56, 0.91, 0.2)
                end
            end)

            btn:SetScript("OnLeave", function(self)
                if popup.selectedFrame ~= self.frameValue then
                    self:SetBackdropColor(0, 0, 0, 0)
                end
            end)

            -- Highlight if currently selected
            if popup.selectedFrame == frame.value then
                btn:SetBackdropColor(1, 0.66, 0, 0.3)
            end

            btn:Show()
            y = y - 24
        end
    end

    listContent:SetHeight(math.max(math.abs(y), 10))
end

CreateAddDialog = function()
    local popup = CreateFrame("Frame", "NaowhQOL_AddCommandDialog", UIParent, "BackdropTemplate")
    popup:SetSize(350, 380)
    popup:SetPoint("CENTER")
    popup:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]],
        edgeSize = 2,
    })
    popup:SetBackdropColor(0.05, 0.05, 0.05, 0.98)
    popup:SetBackdropBorderColor(0, 0.49, 0.79, 0.8)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(200)
    popup:EnableMouse(true)
    popup:SetMovable(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
    popup:Hide()

    -- Title
    local titleText = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOP", 0, -12)
    titleText:SetText(L["SLASH_POPUP_ADD"])

    -- Command Name
    local nameLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", 16, -45)
    nameLabel:SetText(L["SLASH_CMD_NAME"])

    local nameBox = CreateFrame("EditBox", nil, popup, "BackdropTemplate")
    nameBox:SetSize(180, 26)
    nameBox:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -4)
    nameBox:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]],
        edgeSize = 1
    })
    nameBox:SetBackdropColor(0.08, 0.08, 0.08, 1)
    nameBox:SetBackdropBorderColor(0, 0.49, 0.79, 0.4)
    nameBox:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    nameBox:SetTextColor(1, 1, 1, 0.9)
    nameBox:SetTextInsets(8, 8, 0, 0)
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(20)
    popup.nameBox = nameBox

    local nameHint = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameHint:SetPoint("LEFT", nameBox, "RIGHT", 8, 0)
    nameHint:SetText(L["SLASH_CMD_HINT"])

    -- Action Type selector
    local typeLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    typeLabel:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -12)
    typeLabel:SetText(L["SLASH_ACTION_TYPE"])

    popup.actionType = "frame" -- default

    local function StyleTypeBtn(btn, selected)
        if selected then
            btn:SetBackdropColor(1, 0.66, 0, 0.4)
            btn:SetBackdropBorderColor(1, 0.66, 0, 0.8)
        else
            btn:SetBackdropColor(0.08, 0.08, 0.08, 1)
            btn:SetBackdropBorderColor(0, 0.49, 0.79, 0.4)
        end
    end

    local frameTypeBtn = CreateFrame("Button", nil, popup, "BackdropTemplate")
    frameTypeBtn:SetSize(100, 26)
    frameTypeBtn:SetPoint("TOPLEFT", typeLabel, "BOTTOMLEFT", 0, -4)
    frameTypeBtn:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]],
        edgeSize = 1
    })
    local frameTypeTxt = frameTypeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frameTypeTxt:SetPoint("CENTER")
    frameTypeTxt:SetText(L["SLASH_FRAME_TOGGLE"])
    popup.frameTypeBtn = frameTypeBtn

    local cmdTypeBtn = CreateFrame("Button", nil, popup, "BackdropTemplate")
    cmdTypeBtn:SetSize(100, 26)
    cmdTypeBtn:SetPoint("LEFT", frameTypeBtn, "RIGHT", 8, 0)
    cmdTypeBtn:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]],
        edgeSize = 1
    })
    local cmdTypeTxt = cmdTypeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cmdTypeTxt:SetPoint("CENTER")
    cmdTypeTxt:SetText(L["SLASH_COMMAND"])
    popup.cmdTypeBtn = cmdTypeBtn

    -- Frame selection container (for frame toggle)
    local frameContainer = CreateFrame("Frame", nil, popup)
    frameContainer:SetPoint("TOPLEFT", frameTypeBtn, "BOTTOMLEFT", 0, -12)
    frameContainer:SetSize(320, 180)
    popup.frameContainer = frameContainer

    local frameLabel2 = frameContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frameLabel2:SetPoint("TOPLEFT", 0, 0)
    frameLabel2:SetText(L["SLASH_SEARCH_FRAMES"])

    local searchBox = CreateFrame("EditBox", nil, frameContainer, "BackdropTemplate")
    searchBox:SetSize(300, 26)
    searchBox:SetPoint("TOPLEFT", frameLabel2, "BOTTOMLEFT", 0, -4)
    searchBox:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]],
        edgeSize = 1
    })
    searchBox:SetBackdropColor(0.08, 0.08, 0.08, 1)
    searchBox:SetBackdropBorderColor(0, 0.49, 0.79, 0.4)
    searchBox:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    searchBox:SetTextColor(1, 1, 1, 0.9)
    searchBox:SetTextInsets(8, 8, 0, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function(self)
        RefreshFrameList(popup, self:GetText())
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    popup.searchBox = searchBox

    local listContainer = CreateFrame("Frame", nil, frameContainer, "BackdropTemplate")
    listContainer:SetSize(316, 120)
    listContainer:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -4)
    listContainer:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]],
        edgeSize = 1
    })
    listContainer:SetBackdropColor(0.04, 0.04, 0.04, 1)
    listContainer:SetBackdropBorderColor(0, 0.49, 0.79, 0.3)

    local listScroll = CreateFrame("ScrollFrame", nil, listContainer, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", 4, -4)
    listScroll:SetPoint("BOTTOMRIGHT", -24, 4)

    local listContent = CreateFrame("Frame", nil, listScroll)
    listContent:SetSize(280, 1)
    listScroll:SetScrollChild(listContent)
    popup.listContent = listContent

    -- Command input container (for slash command)
    local cmdContainer = CreateFrame("Frame", nil, popup)
    cmdContainer:SetPoint("TOPLEFT", frameTypeBtn, "BOTTOMLEFT", 0, -12)
    cmdContainer:SetSize(320, 180)
    cmdContainer:Hide()
    popup.cmdContainer = cmdContainer

    local cmdLabel = cmdContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cmdLabel:SetPoint("TOPLEFT", 0, 0)
    cmdLabel:SetText(L["SLASH_CMD_RUN"])

    local cmdBox = CreateFrame("EditBox", nil, cmdContainer, "BackdropTemplate")
    cmdBox:SetSize(300, 26)
    cmdBox:SetPoint("TOPLEFT", cmdLabel, "BOTTOMLEFT", 0, -4)
    cmdBox:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]],
        edgeSize = 1
    })
    cmdBox:SetBackdropColor(0.08, 0.08, 0.08, 1)
    cmdBox:SetBackdropBorderColor(0, 0.49, 0.79, 0.4)
    cmdBox:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    cmdBox:SetTextColor(1, 1, 1, 0.9)
    cmdBox:SetTextInsets(8, 8, 0, 0)
    cmdBox:SetAutoFocus(false)
    cmdBox:SetMaxLetters(100)
    cmdBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    popup.cmdBox = cmdBox

    local cmdHint = cmdContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cmdHint:SetPoint("TOPLEFT", cmdBox, "BOTTOMLEFT", 0, -6)
    cmdHint:SetText(L["SLASH_CMD_RUN_HINT"])

    local cmdNote = cmdContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cmdNote:SetPoint("TOPLEFT", cmdHint, "BOTTOMLEFT", 0, -8)
    cmdNote:SetWidth(300)
    cmdNote:SetJustifyH("LEFT")
    cmdNote:SetText(L["SLASH_ARGS_NOTE"])

    -- Type button click handlers
    local function UpdateTypeSelection()
        StyleTypeBtn(frameTypeBtn, popup.actionType == "frame")
        StyleTypeBtn(cmdTypeBtn, popup.actionType == "command")
        if popup.actionType == "frame" then
            frameContainer:Show()
            cmdContainer:Hide()
        else
            frameContainer:Hide()
            cmdContainer:Show()
        end
    end

    frameTypeBtn:SetScript("OnClick", function()
        popup.actionType = "frame"
        UpdateTypeSelection()
    end)

    cmdTypeBtn:SetScript("OnClick", function()
        popup.actionType = "command"
        UpdateTypeSelection()
    end)

    -- Disclaimer
    local disclaimer = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    disclaimer:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", 16, 44)
    disclaimer:SetWidth(316)
    disclaimer:SetJustifyH("LEFT")
    disclaimer:SetText(L["SLASH_FRAME_WARN"])
    popup.disclaimer = disclaimer

    -- Buttons
    local saveBtn = W:CreateButton(popup, { text = L["COMMON_SAVE"], width = 80 })
    saveBtn:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -16, 12)
    popup.saveBtn = saveBtn

    local cancelBtn = W:CreateButton(popup, { text = L["COMMON_CANCEL"], width = 80, onClick = function() popup:Hide() end })
    cancelBtn:SetPoint("RIGHT", saveBtn, "LEFT", -8, 0)

    addDialog = popup
end

ShowAddDialog = function(refreshCallback)
    if not addDialog then CreateAddDialog() end

    -- Reset all fields
    addDialog.nameBox:SetText("")
    addDialog.selectedFrame = nil
    addDialog.selectedFrameName = nil
    addDialog.searchBox:SetText("")
    addDialog.cmdBox:SetText("")
    addDialog.actionType = "frame"

    -- Reset type selection UI
    local function StyleTypeBtn(btn, selected)
        if selected then
            btn:SetBackdropColor(1, 0.66, 0, 0.4)
            btn:SetBackdropBorderColor(1, 0.66, 0, 0.8)
        else
            btn:SetBackdropColor(0.08, 0.08, 0.08, 1)
            btn:SetBackdropBorderColor(0, 0.49, 0.79, 0.4)
        end
    end
    StyleTypeBtn(addDialog.frameTypeBtn, true)
    StyleTypeBtn(addDialog.cmdTypeBtn, false)
    addDialog.frameContainer:Show()
    addDialog.cmdContainer:Hide()

    -- Populate frame list
    RefreshFrameList(addDialog, "")

    addDialog.saveBtn:SetScript("OnClick", function()
        local name = strtrim(addDialog.nameBox:GetText())
        name = name:gsub("^/", ""):lower()

        if name == "" then
            ns:LogError(L["SLASH_ERR_NAME"])
            return
        end

        if name:match("[^%w_]") then
            ns:LogError(L["SLASH_ERR_INVALID"])
            return
        end

        -- Validate based on action type
        if addDialog.actionType == "frame" then
            if not addDialog.selectedFrame then
                ns:LogError(L["SLASH_ERR_FRAME"])
                return
            end
        else
            local cmdText = strtrim(addDialog.cmdBox:GetText())
            if cmdText == "" then
                ns:LogError(L["SLASH_ERR_CMD"])
                return
            end
        end

        -- Check for duplicate
        local db = NaowhQOL.slashCommands
        for _, cmd in ipairs(db.commands or {}) do
            if cmd.name == name then
                ns:LogError(L["SLASH_ERR_EXISTS"])
                return
            end
        end

        -- Add command based on type
        if addDialog.actionType == "frame" then
            db.commands[#db.commands + 1] = {
                name = name,
                actionType = "frame",
                frame = addDialog.selectedFrame,
                enabled = true,
            }
        else
            db.commands[#db.commands + 1] = {
                name = name,
                actionType = "command",
                command = strtrim(addDialog.cmdBox:GetText()),
                enabled = true,
            }
        end

        ns.SlashCommands:RefreshAll()
        addDialog:Hide()
        if refreshCallback then refreshCallback() end
    end)

    addDialog:Show()
end

-- Interactive frame test
local testDialog = nil
local testResults = { works = {}, useless = {}, lua = {}, silent = {} }
local testIndex = 0

-- Forward declarations for mutual recursion
local CreateTestDialog, TestNextFrame, RecordTestResult, PrintTestResults

local function StartFrameTest()
    testResults = { works = {}, useless = {}, lua = {}, silent = {} }
    testIndex = 0

    if not testDialog then
        CreateTestDialog()
    end

    testDialog:Show()
    TestNextFrame()
end

CreateTestDialog = function()
    local popup = CreateFrame("Frame", "NaowhQOL_FrameTestDialog", UIParent, "BackdropTemplate")
    popup:SetSize(400, 160)
    popup:SetPoint("TOP", 0, -100)
    popup:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]],
        edgeSize = 2,
    })
    popup:SetBackdropColor(0.05, 0.05, 0.05, 0.98)
    popup:SetBackdropBorderColor(1, 0.66, 0, 0.8)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(300)
    popup:EnableMouse(true)
    popup:SetMovable(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
    popup:Hide()

    -- Title
    local titleText = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOP", 0, -12)
    titleText:SetText(L["SLASH_POPUP_TEST"])
    popup.titleText = titleText

    -- Progress
    local progressText = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    progressText:SetPoint("TOP", titleText, "BOTTOM", 0, -8)
    popup.progressText = progressText

    -- Frame name
    local frameText = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frameText:SetPoint("TOP", progressText, "BOTTOM", 0, -8)
    popup.frameText = frameText

    -- Frame value (technical name)
    local valueText = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valueText:SetPoint("TOP", frameText, "BOTTOM", 0, -4)
    popup.valueText = valueText

    -- Buttons row
    local btnY = -110

    local worksBtn = W:CreateButton(popup, { text = L["SLASH_TEST_WORKS"], width = 70, onClick = function()
        RecordTestResult("works")
    end })
    worksBtn:SetPoint("TOPLEFT", 20, btnY)

    local uselessBtn = W:CreateButton(popup, { text = L["SLASH_TEST_USELESS"], width = 70, onClick = function()
        RecordTestResult("useless")
    end })
    uselessBtn:SetPoint("LEFT", worksBtn, "RIGHT", 8, 0)

    local luaBtn = W:CreateButton(popup, { text = L["SLASH_TEST_ERROR"], width = 70, onClick = function()
        RecordTestResult("lua")
    end })
    luaBtn:SetPoint("LEFT", uselessBtn, "RIGHT", 8, 0)

    local silentBtn = W:CreateButton(popup, { text = L["SLASH_TEST_SILENT"], width = 70, onClick = function()
        RecordTestResult("silent")
    end })
    silentBtn:SetPoint("LEFT", luaBtn, "RIGHT", 8, 0)

    local skipBtn = W:CreateButton(popup, { text = L["SLASH_TEST_SKIP"], width = 50, onClick = function()
        TestNextFrame()
    end })
    skipBtn:SetPoint("LEFT", silentBtn, "RIGHT", 8, 0)

    -- Cancel/Done row
    local cancelBtn = W:CreateButton(popup, { text = L["SLASH_TEST_STOP"], width = 80, onClick = function()
        popup:Hide()
        PrintTestResults()
    end })
    cancelBtn:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -16, 10)

    testDialog = popup
end

TestNextFrame = function()
    testIndex = testIndex + 1
    local frames = ns.SlashCommands.KNOWN_FRAMES

    if testIndex > #frames then
        testDialog:Hide()
        PrintTestResults()
        return
    end

    local frame = frames[testIndex]
    testDialog.progressText:SetText(testIndex .. " / " .. #frames)
    testDialog.frameText:SetText(frame.name)
    testDialog.valueText:SetText(W.Colorize(frame.value .. " (" .. frame.category .. ")", C.GRAY))

    -- Try to show the frame
    pcall(function()
        local addonReq = ns.SlashCommands.FRAME_ADDON_REQUIREMENTS[frame.value]
        if addonReq and not C_AddOns.IsAddOnLoaded(addonReq) then
            C_AddOns.LoadAddOn(addonReq)
        end

        local f = _G[frame.value]
        if f and f.Show then
            f:Show()
        end
    end)
end

RecordTestResult = function(result)
    local frame = ns.SlashCommands.KNOWN_FRAMES[testIndex]
    if frame then
        table.insert(testResults[result], frame.name)

        -- Hide the frame we just tested
        pcall(function()
            local f = _G[frame.value]
            if f and f.Hide then
                f:Hide()
            end
        end)
    end
    TestNextFrame()
end

PrintTestResults = function()
    if not ns.Debug then return end
    ns:LogSuccess("Frame Test Complete!")
    ns:Log("Works: " .. #testResults.works, ns.COLORS.SUCCESS)
    ns:Log("Useless: " .. #testResults.useless, ns.COLORS.GRAY)
    ns:Log("Lua Error: " .. #testResults.lua, ns.COLORS.ERROR)
    ns:Log("Silent Fail: " .. #testResults.silent, ns.COLORS.ORANGE)
end

function ns:InitSlashCommands()
    local content = ns.MainFrame and ns.MainFrame.Content
    if not content then return end

    W:CachedPanel(panelCache, "slashCommands", content, BuildPanel)
end
