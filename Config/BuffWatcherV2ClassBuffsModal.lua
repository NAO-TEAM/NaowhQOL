local addonName, ns = ...

local W = ns.Widgets
local L = ns.L
local Categories = ns.BWV2Categories

-- Helper: Get all talents from player's current spec tree
local function GetPlayerTalents()
    local talents = {}
    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then return talents end

    local specIndex = GetSpecialization()
    if not specIndex then return talents end
    local specID = GetSpecializationInfo(specIndex)
    if not specID then return talents end

    local treeID = C_ClassTalents.GetTraitTreeForSpec(specID)
    if not treeID then return talents end

    local nodeIDs = C_Traits.GetTreeNodes(treeID)
    if not nodeIDs then return talents end

    local seen = {}
    for _, nodeID in ipairs(nodeIDs) do
        local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
        if nodeInfo and nodeInfo.entryIDs then
            for _, entryID in ipairs(nodeInfo.entryIDs) do
                local entryInfo = C_Traits.GetEntryInfo(configID, entryID)
                if entryInfo and entryInfo.definitionID then
                    local defInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
                    if defInfo and defInfo.spellID and not seen[defInfo.spellID] then
                        seen[defInfo.spellID] = true
                        local spellInfo = C_Spell.GetSpellInfo(defInfo.spellID)
                        if spellInfo then
                            table.insert(talents, {
                                spellID = defInfo.spellID,
                                name = defInfo.overrideName or spellInfo.name,
                                icon = defInfo.overrideIcon or spellInfo.iconID,
                            })
                        end
                    end
                end
            end
        end
    end

    table.sort(talents, function(a, b) return a.name < b.name end)
    return talents
end

-- Modal frame (reused across calls)
local classBuffModal = nil

local function ShowClassBuffModal(initialClassName, groupData, onSave, onDelete, db)
    -- Create modal if not exists
    if not classBuffModal then
        classBuffModal = CreateFrame("Frame", "NaowhQOL_ClassBuffModal", UIParent, "BackdropTemplate")
        classBuffModal:SetSize(520, 435)
        classBuffModal:SetPoint("CENTER")
        classBuffModal:SetFrameStrata("DIALOG")
        classBuffModal:SetBackdrop({
            bgFile = [[Interface\Buttons\WHITE8x8]],
            edgeFile = [[Interface\Buttons\WHITE8x8]],
            edgeSize = 2,
        })
        classBuffModal:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
        classBuffModal:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        classBuffModal:EnableMouse(true)
        classBuffModal:SetMovable(true)
        classBuffModal:RegisterForDrag("LeftButton")
        classBuffModal:SetScript("OnDragStart", classBuffModal.StartMoving)
        classBuffModal:SetScript("OnDragStop", classBuffModal.StopMovingOrSizing)
        classBuffModal:Hide()

        -- Title
        classBuffModal.title = classBuffModal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        classBuffModal.title:SetPoint("TOP", 0, -10)

        -- Close button
        local closeBtn = CreateFrame("Button", nil, classBuffModal, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -2, -2)
        closeBtn:SetScript("OnClick", function() classBuffModal:Hide() end)

        -- Clean up dropdown panel when modal hides
        classBuffModal:SetScript("OnHide", function(self)
            if self.talentDropdownPanel then
                self.talentDropdownPanel:Hide()
            end
        end)
    end

    local modal = classBuffModal
    local isEdit = groupData ~= nil
    modal.title:SetText(isEdit and L["BWV2_MODAL_EDIT_TITLE"] or L["BWV2_MODAL_ADD_TITLE"])

    -- Clear old content completely (orphan frames to prevent stale closures)
    if modal.leftContent then
        modal.leftContent:Hide()
        modal.leftContent:SetParent(nil)
    end
    if modal.rightContent then
        modal.rightContent:Hide()
        modal.rightContent:SetParent(nil)
    end
    if modal.saveBtn then
        modal.saveBtn:Hide()
        modal.saveBtn:SetParent(nil)
    end
    if modal.cancelBtn then
        modal.cancelBtn:Hide()
        modal.cancelBtn:SetParent(nil)
    end
    if modal.deleteBtn then
        modal.deleteBtn:Hide()
        modal.deleteBtn:SetParent(nil)
        modal.deleteBtn = nil
    end
    if modal.talentDropdownPanel then
        modal.talentDropdownPanel:Hide()
        modal.talentDropdownPanel:SetParent(nil)
        modal.talentDropdownPanel = nil
    end

    -- Left side - settings
    local leftContent = CreateFrame("Frame", nil, modal)
    leftContent:SetPoint("TOPLEFT", 15, -40)
    leftContent:SetSize(250, 345)
    modal.leftContent = leftContent

    -- Right side - spell IDs
    local rightContent = CreateFrame("Frame", nil, modal)
    rightContent:SetPoint("TOPRIGHT", -15, -40)
    rightContent:SetSize(230, 345)
    modal.rightContent = rightContent

    -- Editing state
    local editState = {
        className = initialClassName,
        name = groupData and groupData.name or "",
        checkType = groupData and groupData.checkType or "self",
        minRequired = groupData and groupData.minRequired or 1,
        specFilter = groupData and groupData.specFilter and {unpack(groupData.specFilter)} or {},
        spellIDs = groupData and groupData.spellIDs and {unpack(groupData.spellIDs)} or {},
        enchantIDs = groupData and groupData.enchantIDs and {unpack(groupData.enchantIDs)} or {},
        talentCondition = groupData and groupData.talentCondition and {
            talentID = groupData.talentCondition.talentID,
            mode = groupData.talentCondition.mode,
        } or nil,
    }

    -- Store spec UI elements for proper cleanup (container created later after specLabel)
    local specElements = {}
    local specContainer = nil

    local function RebuildSpecCheckboxes()
        -- Clear old elements (both frames and font strings)
        for _, elem in ipairs(specElements) do
            elem:Hide()
            elem:SetParent(nil)
        end
        wipe(specElements)

        if not specContainer then return end

        local classInfo = Categories.CLASS_INFO[editState.className]
        if not classInfo or not classInfo.specs then return end

        local yOffset = 0

        local allSpecsCB = CreateFrame("CheckButton", nil, specContainer, "ChatConfigCheckButtonTemplate")
        allSpecsCB:SetPoint("TOPLEFT", 10, yOffset)
        allSpecsCB:SetChecked(#editState.specFilter == 0)
        specElements[#specElements + 1] = allSpecsCB

        local allLabel = specContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        allLabel:SetPoint("LEFT", allSpecsCB, "RIGHT", 2, 0)
        allLabel:SetText(L["BWV2_ALL_SPECS"])
        specElements[#specElements + 1] = allLabel

        yOffset = yOffset - 18

        local specCBs = {}
        for _, specData in ipairs(classInfo.specs) do
            local specID, specName = specData[1], specData[2]
            local specCB = CreateFrame("CheckButton", nil, specContainer, "ChatConfigCheckButtonTemplate")
            specCB:SetPoint("TOPLEFT", 10, yOffset)
            specElements[#specElements + 1] = specCB

            local hasSpec = false
            for _, id in ipairs(editState.specFilter) do
                if id == specID then hasSpec = true break end
            end
            specCB:SetChecked(hasSpec)

            local specLbl = specContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            specLbl:SetPoint("LEFT", specCB, "RIGHT", 2, 0)
            specLbl:SetText(specName)
            specElements[#specElements + 1] = specLbl

            specCB:SetScript("OnClick", function(self)
                if self:GetChecked() then
                    table.insert(editState.specFilter, specID)
                    allSpecsCB:SetChecked(false)
                else
                    for i, id in ipairs(editState.specFilter) do
                        if id == specID then
                            table.remove(editState.specFilter, i)
                            break
                        end
                    end
                    if #editState.specFilter == 0 then
                        allSpecsCB:SetChecked(true)
                    end
                end
            end)

            specCBs[specID] = specCB
            yOffset = yOffset - 18
        end

        allSpecsCB:SetScript("OnClick", function(self)
            if self:GetChecked() then
                wipe(editState.specFilter)
                for _, cb in pairs(specCBs) do
                    cb:SetChecked(false)
                end
            else
                self:SetChecked(true)
            end
        end)
    end

    -- === LEFT SIDE ===
    local yOffset = 0

    -- Class Selection (disabled during edit)
    local classLabel = leftContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    classLabel:SetPoint("TOPLEFT", 0, yOffset)
    classLabel:SetText(L["BWV2_CLASS"])

    local classDropdown = CreateFrame("Frame", nil, leftContent, "UIDropDownMenuTemplate")
    classDropdown:SetPoint("LEFT", classLabel, "RIGHT", -5, -2)
    UIDropDownMenu_SetWidth(classDropdown, 130)

    local function UpdateClassDropdownText()
        local classInfo = Categories.CLASS_INFO[editState.className]
        UIDropDownMenu_SetText(classDropdown, classInfo and classInfo.name or L["BWV2_SELECT_CLASS"])
    end

    UIDropDownMenu_Initialize(classDropdown, function(self, level)
        for _, className in ipairs(Categories.CLASS_ORDER) do
            local classInfo = Categories.CLASS_INFO[className]
            local info = UIDropDownMenu_CreateInfo()
            info.text = classInfo.name
            info.func = function()
                editState.className = className
                wipe(editState.specFilter)  -- Reset spec filter on class change
                UpdateClassDropdownText()
                RebuildSpecCheckboxes()
            end
            info.checked = (editState.className == className)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    UpdateClassDropdownText()

    if isEdit then
        UIDropDownMenu_DisableDropDown(classDropdown)
    end

    yOffset = yOffset - 30

    -- Group Name
    local nameLabel = leftContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", 0, yOffset)
    nameLabel:SetText(L["BWV2_GROUP_NAME"])

    local nameInput = CreateFrame("EditBox", nil, leftContent, "InputBoxTemplate")
    nameInput:SetSize(120, 20)
    nameInput:SetPoint("LEFT", nameLabel, "RIGHT", 8, 0)
    nameInput:SetAutoFocus(false)
    nameInput:SetText(editState.name)
    nameInput:SetScript("OnTextChanged", function(self)
        editState.name = self:GetText()
    end)

    yOffset = yOffset - 28

    -- Check Type
    local typeLabel = leftContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    typeLabel:SetPoint("TOPLEFT", 0, yOffset)
    typeLabel:SetText(L["BWV2_CHECK_TYPE"])

    yOffset = yOffset - 18

    local checkTypes = {
        { key = "self", label = L["BWV2_TYPE_SELF"] },
        { key = "targeted", label = L["BWV2_TYPE_TARGETED"] },
        { key = "weaponEnchant", label = L["BWV2_TYPE_WEAPON"] },
    }

    for _, ct in ipairs(checkTypes) do
        local radio = CreateFrame("CheckButton", nil, leftContent, "UIRadioButtonTemplate")
        radio:SetPoint("TOPLEFT", 10, yOffset)
        radio:SetChecked(editState.checkType == ct.key)

        local radioLabel = leftContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        radioLabel:SetPoint("LEFT", radio, "RIGHT", 2, 0)
        radioLabel:SetText(ct.label)

        radio:SetScript("OnClick", function()
            editState.checkType = ct.key
            for _, child in ipairs({leftContent:GetChildren()}) do
                if child:GetObjectType() == "CheckButton" and child.isRadio then
                    child:SetChecked(child.radioKey == ct.key)
                end
            end
        end)
        radio.isRadio = true
        radio.radioKey = ct.key

        yOffset = yOffset - 18
    end

    yOffset = yOffset - 6

    -- Min Required input
    local minReqLabel = leftContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    minReqLabel:SetPoint("TOPLEFT", 0, yOffset)
    minReqLabel:SetText(L["BWV2_MIN_REQUIRED"])

    local minReqInput = CreateFrame("EditBox", nil, leftContent, "InputBoxTemplate")
    minReqInput:SetSize(40, 20)
    minReqInput:SetPoint("LEFT", minReqLabel, "RIGHT", 8, 0)
    minReqInput:SetNumeric(true)
    minReqInput:SetAutoFocus(false)
    minReqInput:SetText(tostring(editState.minRequired))
    minReqInput:SetScript("OnTextChanged", function(self)
        local val = tonumber(self:GetText())
        if val then
            val = math.max(0, math.floor(val))
        else
            val = 1
        end
        editState.minRequired = val
    end)

    local minReqHint = leftContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    minReqHint:SetPoint("LEFT", minReqInput, "RIGHT", 5, 0)
    minReqHint:SetText(L["BWV2_MIN_HINT"])
    minReqHint:SetTextColor(0.6, 0.6, 0.6)

    yOffset = yOffset - 28

    -- Talent Condition section
    local talentLabel = leftContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    talentLabel:SetPoint("TOPLEFT", 0, yOffset)
    talentLabel:SetText(L["BWV2_TALENT_CONDITION"])

    yOffset = yOffset - 22

    -- Cache talents for this modal session
    local cachedTalents = GetPlayerTalents()

    -- Dropdown button (shows current selection)
    local dropdownBtn = CreateFrame("Button", nil, leftContent, "BackdropTemplate")
    dropdownBtn:SetSize(190, 22)
    dropdownBtn:SetPoint("TOPLEFT", 10, yOffset)
    dropdownBtn:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]],
        edgeSize = 1,
    })
    dropdownBtn:SetBackdropColor(0.1, 0.1, 0.1, 1)
    dropdownBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local dropdownIcon = dropdownBtn:CreateTexture(nil, "ARTWORK")
    dropdownIcon:SetSize(16, 16)
    dropdownIcon:SetPoint("LEFT", 4, 0)
    dropdownIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    dropdownIcon:Hide()

    local dropdownText = dropdownBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dropdownText:SetPoint("LEFT", 24, 0)
    dropdownText:SetPoint("RIGHT", -18, 0)
    dropdownText:SetJustifyH("LEFT")
    dropdownText:SetText(L["BWV2_SELECT_TALENT"])
    dropdownText:SetTextColor(0.5, 0.5, 0.5)

    local dropdownArrow = dropdownBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dropdownArrow:SetPoint("RIGHT", -4, 0)
    dropdownArrow:SetText("v")

    -- Clear button
    local clearBtn = CreateFrame("Button", nil, leftContent, "UIPanelButtonTemplate")
    clearBtn:SetSize(22, 22)
    clearBtn:SetPoint("LEFT", dropdownBtn, "RIGHT", 2, 0)
    clearBtn:SetText("X")

    -- Dropdown panel (appears below button)
    local dropdownPanel = CreateFrame("Frame", nil, modal, "BackdropTemplate")
    modal.talentDropdownPanel = dropdownPanel
    dropdownPanel:SetSize(190, 150)
    dropdownPanel:SetPoint("TOPLEFT", dropdownBtn, "BOTTOMLEFT", 0, -2)
    dropdownPanel:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]],
        edgeSize = 1,
    })
    dropdownPanel:SetBackdropColor(0.1, 0.1, 0.1, 0.98)
    dropdownPanel:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    dropdownPanel:SetFrameStrata("TOOLTIP")
    dropdownPanel:Hide()

    -- Search box inside dropdown
    local searchBox = CreateFrame("EditBox", nil, dropdownPanel, "InputBoxTemplate")
    searchBox:SetSize(170, 18)
    searchBox:SetPoint("TOP", 0, -8)
    searchBox:SetAutoFocus(false)
    searchBox:SetText("")

    local searchPlaceholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    searchPlaceholder:SetPoint("LEFT", 5, 0)
    searchPlaceholder:SetText(L["BWV2_FILTER_TALENTS"])
    searchPlaceholder:SetTextColor(0.4, 0.4, 0.4)

    -- Results scroll area
    local resultsScroll = CreateFrame("ScrollFrame", nil, dropdownPanel, "UIPanelScrollFrameTemplate")
    resultsScroll:SetPoint("TOPLEFT", 4, -30)
    resultsScroll:SetPoint("BOTTOMRIGHT", -22, 4)

    local resultsContent = CreateFrame("Frame", nil, resultsScroll)
    resultsContent:SetSize(160, 1)
    resultsScroll:SetScrollChild(resultsContent)

    local resultRows = {}
    local MAX_VISIBLE = 6

    local function UpdateDropdownDisplay()
        if editState.talentCondition and editState.talentCondition.talentID then
            local info = C_Spell.GetSpellInfo(editState.talentCondition.talentID)
            if info then
                dropdownIcon:SetTexture(info.iconID)
                dropdownIcon:Show()
                dropdownText:SetText(info.name)
                dropdownText:SetTextColor(0.4, 0.8, 0.4)
                return
            end
        end
        dropdownIcon:Hide()
        dropdownText:SetText(L["BWV2_SELECT_TALENT"])
        dropdownText:SetTextColor(0.5, 0.5, 0.5)
    end

    local function FilterTalents(searchText)
        if not searchText or searchText == "" then
            return cachedTalents
        end
        local lower = searchText:lower()
        local results = {}
        for _, t in ipairs(cachedTalents) do
            if t.name:lower():find(lower, 1, true) then
                table.insert(results, t)
            end
        end
        return results
    end

    local function RebuildResultsList(filtered)
        -- Hide all existing rows first
        for _, row in ipairs(resultRows) do
            row:Hide()
        end

        -- Limit max rows to prevent unbounded growth
        local MAX_ROWS = 50
        local displayCount = math.min(#filtered, MAX_ROWS)
        resultsContent:SetHeight(math.max(1, displayCount * 20))

        for i = 1, displayCount do
            local talent = filtered[i]
            local row = resultRows[i]
            if not row then
                row = CreateFrame("Button", nil, resultsContent)
                row:SetSize(160, 20)
                row:SetPoint("TOPLEFT", 0, -(i - 1) * 20)

                row.bg = row:CreateTexture(nil, "BACKGROUND")
                row.bg:SetAllPoints()
                row.bg:SetColorTexture(0.3, 0.3, 0.3, 0)

                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(16, 16)
                row.icon:SetPoint("LEFT", 2, 0)
                row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                row.text:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
                row.text:SetPoint("RIGHT", -2, 0)
                row.text:SetJustifyH("LEFT")

                row:SetScript("OnEnter", function(self)
                    self.bg:SetColorTexture(0.3, 0.3, 0.3, 0.8)
                end)
                row:SetScript("OnLeave", function(self)
                    self.bg:SetColorTexture(0.3, 0.3, 0.3, 0)
                end)

                resultRows[i] = row
            end

            row:SetPoint("TOPLEFT", 0, -(i - 1) * 20)
            row.icon:SetTexture(talent.icon)
            row.text:SetText(talent.name)

            row:SetScript("OnClick", function()
                editState.talentCondition = editState.talentCondition or { mode = "activate" }
                editState.talentCondition.talentID = talent.spellID
                UpdateDropdownDisplay()
                dropdownPanel:Hide()
                searchBox:SetText("")
            end)

            row:Show()
        end
    end

    searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        searchPlaceholder:SetShown(text == "")
        local filtered = FilterTalents(text)
        RebuildResultsList(filtered)
    end)

    dropdownBtn:SetScript("OnClick", function()
        if dropdownPanel:IsShown() then
            dropdownPanel:Hide()
        else
            RebuildResultsList(cachedTalents)
            dropdownPanel:Show()
            searchBox:SetFocus()
        end
    end)

    clearBtn:SetScript("OnClick", function()
        editState.talentCondition = nil
        UpdateDropdownDisplay()
        dropdownPanel:Hide()
        searchBox:SetText("")
    end)

    -- Close dropdown when clicking elsewhere
    dropdownPanel:SetScript("OnShow", function()
        dropdownPanel:SetPropagateKeyboardInput(true)
    end)

    -- Initialize display
    UpdateDropdownDisplay()
    RebuildResultsList(cachedTalents)

    yOffset = yOffset - 24

    -- Talent mode radio buttons
    local talentModes = {
        { key = "activate", label = L["BWV2_MODE_ACTIVATE"] },
        { key = "skip", label = L["BWV2_MODE_SKIP"] },
    }

    local talentModeRadios = {}
    for _, tm in ipairs(talentModes) do
        local radio = CreateFrame("CheckButton", nil, leftContent, "UIRadioButtonTemplate")
        radio:SetPoint("TOPLEFT", 10, yOffset)
        local isChecked = editState.talentCondition and editState.talentCondition.mode == tm.key
        radio:SetChecked(isChecked or (tm.key == "activate" and not editState.talentCondition))

        local radioLabel = leftContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        radioLabel:SetPoint("LEFT", radio, "RIGHT", 2, 0)
        radioLabel:SetText(tm.label)

        radio:SetScript("OnClick", function()
            for _, r in ipairs(talentModeRadios) do
                r:SetChecked(r.modeKey == tm.key)
            end
            if editState.talentCondition then
                editState.talentCondition.mode = tm.key
            else
                editState.talentCondition = { mode = tm.key }
            end
        end)
        radio.modeKey = tm.key
        table.insert(talentModeRadios, radio)

        yOffset = yOffset - 18
    end

    yOffset = yOffset - 6

    -- Spec Filter label
    local specLabel = leftContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    specLabel:SetPoint("TOPLEFT", 0, yOffset)
    specLabel:SetText(L["BWV2_SPECS"])

    -- Create spec container anchored below the label
    specContainer = CreateFrame("Frame", nil, leftContent)
    specContainer:SetPoint("TOPLEFT", specLabel, "BOTTOMLEFT", 0, -2)
    specContainer:SetSize(240, 100)

    -- Build initial spec checkboxes
    RebuildSpecCheckboxes()

    -- === RIGHT SIDE ===
    local idLabel = rightContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    idLabel:SetPoint("TOPLEFT", 0, 0)
    idLabel:SetText(L["BWV2_SPELL_ENCHANT_IDS"])

    -- ID list display
    local idListFrame = CreateFrame("Frame", nil, rightContent, "BackdropTemplate")
    idListFrame:SetPoint("TOPLEFT", 0, -20)
    idListFrame:SetSize(230, 180)
    idListFrame:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
    idListFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.8)

    local function RefreshIDList()
        for _, child in ipairs({idListFrame:GetChildren()}) do
            child:Hide()
        end

        local ids = editState.checkType == "weaponEnchant" and editState.enchantIDs or editState.spellIDs
        local listY = -3
        for i, id in ipairs(ids) do
            local row = CreateFrame("Frame", nil, idListFrame)
            row:SetSize(220, 18)
            row:SetPoint("TOPLEFT", 5, listY)

            local idText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            idText:SetPoint("LEFT", 0, 0)

            local info = C_Spell.GetSpellInfo(id)
            local name = info and info.name or L["BWV2_UNKNOWN"]
            idText:SetText(id .. " - " .. name)

            local delBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            delBtn:SetSize(18, 16)
            delBtn:SetPoint("RIGHT", -2, 0)
            delBtn:SetText("X")
            delBtn:SetScript("OnClick", function()
                table.remove(ids, i)
                RefreshIDList()
            end)

            listY = listY - 18
        end
    end

    RefreshIDList()

    -- Add ID input
    local addIDInput = CreateFrame("EditBox", nil, rightContent, "InputBoxTemplate")
    addIDInput:SetSize(150, 20)
    addIDInput:SetPoint("TOPLEFT", 0, -205)
    addIDInput:SetNumeric(true)
    addIDInput:SetAutoFocus(false)

    local addIDBtn = W:CreateButton(rightContent, {
        text = "+",
        width = 30,
        onClick = function()
            local id = tonumber(addIDInput:GetText())
            if id and id > 0 then
                local ids = editState.checkType == "weaponEnchant" and editState.enchantIDs or editState.spellIDs
                table.insert(ids, id)
                addIDInput:SetText("")
                RefreshIDList()
            end
        end,
    })
    addIDBtn:SetPoint("LEFT", addIDInput, "RIGHT", 5, 0)

    -- Bottom buttons (stored on modal for cleanup on next open)
    modal.saveBtn = W:CreateButton(modal, {
        text = L["COMMON_SAVE"],
        width = 80,
        onClick = function()
            if not editState.className then
                print("|cffff0000[BuffWatcher]|r " .. L["BWV2_ERR_SELECT_CLASS"])
                return
            end

            if editState.name == "" then
                print("|cffff0000[BuffWatcher]|r " .. L["BWV2_ERR_NAME_REQUIRED"])
                return
            end

            local ids = editState.checkType == "weaponEnchant" and editState.enchantIDs or editState.spellIDs
            if #ids == 0 then
                print("|cffff0000[BuffWatcher]|r " .. L["BWV2_ERR_ID_REQUIRED"])
                return
            end

            local key = editState.name:lower():gsub("%s+", "_"):gsub("[^%w_]", "")
            if groupData and groupData.key then
                key = groupData.key
            end

            local newGroup = {
                key = key,
                name = editState.name,
                checkType = editState.checkType,
                minRequired = editState.minRequired,
                specFilter = editState.specFilter,
                spellIDs = editState.checkType ~= "weaponEnchant" and editState.spellIDs or nil,
                enchantIDs = editState.checkType == "weaponEnchant" and editState.enchantIDs or nil,
                talentCondition = editState.talentCondition,
            }

            if onSave then onSave(editState.className, newGroup) end
            modal:Hide()
        end,
    })
    modal.saveBtn:SetPoint("BOTTOMLEFT", 15, 15)

    modal.cancelBtn = W:CreateButton(modal, {
        text = L["COMMON_CANCEL"],
        width = 80,
        onClick = function()
            modal:Hide()
        end,
    })
    modal.cancelBtn:SetPoint("LEFT", modal.saveBtn, "RIGHT", 10, 0)

    if isEdit and onDelete then
        modal.deleteBtn = W:CreateButton(modal, {
            text = L["BWV2_DELETE"],
            width = 80,
            onClick = function()
                onDelete()
                modal:Hide()
            end,
        })
        modal.deleteBtn:SetPoint("BOTTOMRIGHT", -15, 15)
    end

    modal:Show()
end

-- Export to namespace
ns.ShowClassBuffModal = ShowClassBuffModal
