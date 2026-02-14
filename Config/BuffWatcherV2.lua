local addonName, ns = ...
local L = ns.L

local cache = {}
local W = ns.Widgets
local C = ns.COLORS

local BWV2 = ns.BWV2
local Categories = ns.BWV2Categories
local Core = ns.BWV2Core

-- Row height for spell entries
local ROW_HEIGHT = 28
local ICON_SIZE = 22

-- Create a single spell row with icon, name, and delete button
local function CreateSpellRow(parent, spellID, isDefault, onDelete, yOffset)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetSize(420, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 10, yOffset)
    row:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
    row:SetBackdropColor(0.08, 0.08, 0.08, 0.6)

    -- Icon
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("LEFT", 4, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local spellIcon = C_Spell.GetSpellTexture(spellID)
    if spellIcon then
        icon:SetTexture(spellIcon)
    else
        icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    -- Spell name and ID
    local info = C_Spell.GetSpellInfo(spellID)
    local spellName = info and info.name or "Unknown"

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    nameText:SetText(spellName)

    local idText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    idText:SetPoint("LEFT", nameText, "RIGHT", 8, 0)
    idText:SetText(W.Colorize("(" .. spellID .. ")", C.GRAY))

    -- Default tag (if applicable)
    if isDefault then
        local defaultTag = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        defaultTag:SetPoint("RIGHT", -30, 0)
        defaultTag:SetText(W.Colorize("[Default]", C.GRAY))
    end

    -- Delete button (for both defaults and user entries)
    local deleteBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    deleteBtn:SetSize(20, 18)
    deleteBtn:SetPoint("RIGHT", -4, 0)
    deleteBtn:SetText("X")
    deleteBtn:SetScript("OnClick", function()
        if onDelete then onDelete() end
    end)

    return row
end

-- Create spell list content for a collapsible section
-- layoutRef is a table with { func = RelayoutAll } so we can update it after definition
local function CreateSpellListContent(contentFrame, defaultSpells, categoryKey, db, wrapperFrame, layoutRef)
    local allRows = {}

    -- Ensure disabledDefaults table exists for this category
    if not db.disabledDefaults then
        db.disabledDefaults = {}
    end
    if not db.disabledDefaults[categoryKey] then
        db.disabledDefaults[categoryKey] = {}
    end

    local function RebuildContent()
        -- Clear existing rows
        for _, row in ipairs(allRows) do
            row:Hide()
            row:SetParent(nil)
        end
        wipe(allRows)

        local yOffset = -5
        local rowCount = 0
        local hasDisabledDefaults = false

        -- Add default spells first (skip disabled ones)
        if defaultSpells then
            for _, buff in ipairs(defaultSpells) do
                local spellIDs = type(buff.spellID) == "table" and buff.spellID or {buff.spellID}
                local displayID = spellIDs[1]

                if displayID then
                    -- Check if this default is disabled
                    if db.disabledDefaults[categoryKey][displayID] then
                        hasDisabledDefaults = true
                    else
                        local capturedID = displayID
                        local row = CreateSpellRow(contentFrame, displayID, true, function()
                            -- Mark this default as disabled
                            db.disabledDefaults[categoryKey][capturedID] = true
                            RebuildContent()
                        end, yOffset)
                        allRows[#allRows + 1] = row
                        yOffset = yOffset - ROW_HEIGHT
                        rowCount = rowCount + 1
                    end
                end
            end
        end

        -- Add user-added spells (capture index properly for deletion)
        local userEntries = db.userEntries[categoryKey] and db.userEntries[categoryKey].spellIDs or {}
        for idx = 1, #userEntries do
            local spellID = userEntries[idx]
            local deleteIndex = idx  -- Capture current index
            local row = CreateSpellRow(contentFrame, spellID, false, function()
                table.remove(db.userEntries[categoryKey].spellIDs, deleteIndex)
                RebuildContent()
            end, yOffset)
            allRows[#allRows + 1] = row
            yOffset = yOffset - ROW_HEIGHT
            rowCount = rowCount + 1
        end

        -- Add input row for new spell IDs
        local inputRow = CreateFrame("Frame", nil, contentFrame)
        inputRow:SetSize(420, 30)
        inputRow:SetPoint("TOPLEFT", 10, yOffset - 5)
        allRows[#allRows + 1] = inputRow

        local inputLabel = inputRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        inputLabel:SetPoint("LEFT", 0, 0)
        inputLabel:SetText("Add Spell ID:")

        local inputBox = CreateFrame("EditBox", nil, inputRow, "InputBoxTemplate")
        inputBox:SetSize(100, 20)
        inputBox:SetPoint("LEFT", inputLabel, "RIGHT", 8, 0)
        inputBox:SetNumeric(true)
        inputBox:SetAutoFocus(false)

        local addBtn = W:CreateButton(inputRow, {
            text = "Add",
            width = 50,
            onClick = function()
                local id = tonumber(inputBox:GetText())
                if id and id > 0 then
                    if not db.userEntries[categoryKey] then
                        db.userEntries[categoryKey] = { spellIDs = {} }
                    end
                    table.insert(db.userEntries[categoryKey].spellIDs, id)
                    inputBox:SetText("")
                    RebuildContent()
                end
            end,
        })
        addBtn:SetPoint("LEFT", inputBox, "RIGHT", 5, 0)

        -- Add restore defaults button if any defaults are disabled
        local extraHeight = 35
        if hasDisabledDefaults then
            local restoreRow = CreateFrame("Frame", nil, contentFrame)
            restoreRow:SetSize(420, 26)
            restoreRow:SetPoint("TOPLEFT", 10, yOffset - 35)
            allRows[#allRows + 1] = restoreRow

            local restoreBtn = W:CreateButton(restoreRow, {
                text = "Restore Defaults",
                width = 110,
                onClick = function()
                    wipe(db.disabledDefaults[categoryKey])
                    RebuildContent()
                end,
            })
            restoreBtn:SetPoint("LEFT", 0, 0)

            local restoreHint = restoreRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            restoreHint:SetPoint("LEFT", restoreBtn, "RIGHT", 8, 0)
            restoreHint:SetText(W.Colorize("(Some defaults hidden)", C.GRAY))

            extraHeight = extraHeight + 30
        end

        -- Update content height
        local totalHeight = (rowCount * ROW_HEIGHT) + extraHeight
        contentFrame:SetHeight(totalHeight)

        -- Recalc wrapper height
        if wrapperFrame and wrapperFrame.RecalcHeight then
            wrapperFrame:RecalcHeight()
        end

        -- Call relayout function via reference table
        if layoutRef and layoutRef.func then
            layoutRef.func()
        end
    end

    RebuildContent()
    return RebuildContent
end

-- Create a single ID row (spell or item) with icon, name, and delete button
local function CreateIDRow(parent, id, idType, isDefault, onDelete, yOffset)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetSize(400, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 20, yOffset)
    row:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
    row:SetBackdropColor(0.06, 0.06, 0.06, 0.5)

    -- Icon
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("LEFT", 4, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local displayName = "Unknown"
    local displayIcon = "Interface\\Icons\\INV_Misc_QuestionMark"

    if idType == "spell" then
        local spellIcon = C_Spell.GetSpellTexture(id)
        if spellIcon then displayIcon = spellIcon end
        local info = C_Spell.GetSpellInfo(id)
        if info and info.name then displayName = info.name end
    elseif idType == "item" then
        local itemName, _, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(id)
        if itemIcon then displayIcon = itemIcon end
        if itemName then displayName = itemName end
    end

    icon:SetTexture(displayIcon)

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    nameText:SetText(displayName)

    local idText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    idText:SetPoint("LEFT", nameText, "RIGHT", 6, 0)
    idText:SetText(W.Colorize("(" .. id .. ")", C.GRAY))

    if isDefault then
        local defaultTag = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        defaultTag:SetPoint("RIGHT", -28, 0)
        defaultTag:SetText(W.Colorize("[D]", C.GRAY))
    end

    local deleteBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    deleteBtn:SetSize(18, 16)
    deleteBtn:SetPoint("RIGHT", -4, 0)
    deleteBtn:SetText("X")
    deleteBtn:SetScript("OnClick", function()
        if onDelete then onDelete() end
    end)

    return row
end

-- Create consumable subgroups content
local function CreateConsumableGroupsContent(contentFrame, db, wrapperFrame, layoutRef)
    local allElements = {}

    -- Ensure tables exist
    if not db.disabledDefaults then db.disabledDefaults = {} end
    if not db.userEntries then db.userEntries = {} end

    local function RebuildContent()
        -- Clear existing elements
        for _, elem in ipairs(allElements) do
            elem:Hide()
            elem:SetParent(nil)
        end
        wipe(allElements)

        -- Ensure consumableGroupEnabled exists
        if not db.consumableGroupEnabled then
            db.consumableGroupEnabled = {}
        end

        local yOffset = -5
        local totalHeight = 10

        -- Iterate through each consumable group
        for _, group in ipairs(Categories.CONSUMABLE_GROUPS) do
            local groupKey = "consumable_" .. group.key

            -- Default to enabled if not set
            if db.consumableGroupEnabled[group.key] == nil then
                db.consumableGroupEnabled[group.key] = true
            end

            local isGroupEnabled = db.consumableGroupEnabled[group.key]

            -- Ensure tables for this group
            if not db.disabledDefaults[groupKey] then
                db.disabledDefaults[groupKey] = {}
            end
            if not db.userEntries[groupKey] then
                db.userEntries[groupKey] = { spellIDs = {}, itemIDs = {} }
            end

            -- Group header with enable checkbox
            local header = CreateFrame("Frame", nil, contentFrame, "BackdropTemplate")
            header:SetSize(420, 24)
            header:SetPoint("TOPLEFT", 10, yOffset)
            header:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
            header:SetBackdropColor(0.15, 0.15, 0.15, 0.8)
            allElements[#allElements + 1] = header

            -- Enable checkbox
            local enableCB = CreateFrame("CheckButton", nil, header, "ChatConfigCheckButtonTemplate")
            enableCB:SetPoint("LEFT", 4, 0)
            enableCB:SetSize(20, 20)
            enableCB:SetChecked(isGroupEnabled)
            enableCB:SetScript("OnClick", function(self)
                db.consumableGroupEnabled[group.key] = self:GetChecked()
                RebuildContent()
            end)

            local headerText = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            headerText:SetPoint("LEFT", enableCB, "RIGHT", 2, 0)
            if isGroupEnabled then
                headerText:SetText(W.Colorize(group.name, C.ORANGE))
            else
                headerText:SetText(W.Colorize(group.name .. " (disabled)", C.GRAY))
            end

            local exclusiveTag = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            exclusiveTag:SetPoint("LEFT", headerText, "RIGHT", 8, 0)
            if isGroupEnabled then
                exclusiveTag:SetText(W.Colorize("(exclusive - one required)", C.GRAY))
            end

            yOffset = yOffset - 26
            totalHeight = totalHeight + 26

            -- Skip content if group is disabled
            if not isGroupEnabled then
                yOffset = yOffset - 4
                totalHeight = totalHeight + 4
            else
                local hasDisabledDefaults = false
                local idType = (group.checkType == "inventory") and "item" or "spell"
                local defaultIDs = (idType == "item") and (group.itemIDs or {}) or (group.spellIDs or {})

            -- Show default IDs
            for _, id in ipairs(defaultIDs) do
                if db.disabledDefaults[groupKey][id] then
                    hasDisabledDefaults = true
                else
                    local capturedID = id
                    local row = CreateIDRow(contentFrame, id, idType, true, function()
                        db.disabledDefaults[groupKey][capturedID] = true
                        RebuildContent()
                    end, yOffset)
                    allElements[#allElements + 1] = row
                    yOffset = yOffset - ROW_HEIGHT
                    totalHeight = totalHeight + ROW_HEIGHT
                end
            end

            -- Show special check type indicator
            if group.checkType == "icon" then
                local iconNote = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                iconNote:SetPoint("TOPLEFT", 25, yOffset)
                iconNote:SetText(W.Colorize("Detected by buff icon (all food buffs)", C.GRAY))
                allElements[#allElements + 1] = iconNote
                yOffset = yOffset - 18
                totalHeight = totalHeight + 18
            elseif group.checkType == "weaponEnchant" then
                local enchantNote = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                enchantNote:SetPoint("TOPLEFT", 25, yOffset)
                enchantNote:SetText(W.Colorize("Detected via weapon enchant check", C.GRAY))
                allElements[#allElements + 1] = enchantNote
                yOffset = yOffset - 18
                totalHeight = totalHeight + 18
            end

            -- Show user-added IDs
            local userIDs = (idType == "item") and db.userEntries[groupKey].itemIDs or db.userEntries[groupKey].spellIDs
            for idx = 1, #userIDs do
                local id = userIDs[idx]
                local deleteIdx = idx
                local row = CreateIDRow(contentFrame, id, idType, false, function()
                    if idType == "item" then
                        table.remove(db.userEntries[groupKey].itemIDs, deleteIdx)
                    else
                        table.remove(db.userEntries[groupKey].spellIDs, deleteIdx)
                    end
                    RebuildContent()
                end, yOffset)
                allElements[#allElements + 1] = row
                yOffset = yOffset - ROW_HEIGHT
                totalHeight = totalHeight + ROW_HEIGHT
            end

            -- Add input row
            local inputRow = CreateFrame("Frame", nil, contentFrame)
            inputRow:SetSize(400, 24)
            inputRow:SetPoint("TOPLEFT", 20, yOffset - 2)
            allElements[#allElements + 1] = inputRow

            local inputLabel = inputRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            inputLabel:SetPoint("LEFT", 0, 0)
            inputLabel:SetText("Add " .. (idType == "item" and "Item" or "Spell") .. " ID:")

            local inputBox = CreateFrame("EditBox", nil, inputRow, "InputBoxTemplate")
            inputBox:SetSize(80, 18)
            inputBox:SetPoint("LEFT", inputLabel, "RIGHT", 6, 0)
            inputBox:SetNumeric(true)
            inputBox:SetAutoFocus(false)

            local capturedGroupKey = groupKey
            local capturedIdType = idType
            local addBtn = W:CreateButton(inputRow, {
                text = "Add",
                width = 45,
                onClick = function()
                    local id = tonumber(inputBox:GetText())
                    if id and id > 0 then
                        if capturedIdType == "item" then
                            table.insert(db.userEntries[capturedGroupKey].itemIDs, id)
                        else
                            table.insert(db.userEntries[capturedGroupKey].spellIDs, id)
                        end
                        inputBox:SetText("")
                        RebuildContent()
                    end
                end,
            })
            addBtn:SetPoint("LEFT", inputBox, "RIGHT", 4, 0)

            -- Restore defaults button if needed
            if hasDisabledDefaults then
                local restoreBtn = W:CreateButton(inputRow, {
                    text = "Restore",
                    width = 60,
                    onClick = function()
                        wipe(db.disabledDefaults[capturedGroupKey])
                        RebuildContent()
                    end,
                })
                restoreBtn:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
            end

                yOffset = yOffset - 30
                totalHeight = totalHeight + 32

                -- Spacer between groups
                yOffset = yOffset - 8
                totalHeight = totalHeight + 8
            end  -- end isGroupEnabled
        end  -- end for group

        contentFrame:SetHeight(totalHeight)

        if wrapperFrame and wrapperFrame.RecalcHeight then
            wrapperFrame:RecalcHeight()
        end

        if layoutRef and layoutRef.func then
            layoutRef.func()
        end
    end

    RebuildContent()
    return RebuildContent
end

-- Create inventory check groups content
local function CreateInventoryGroupsContent(contentFrame, db, wrapperFrame, layoutRef)
    local allElements = {}

    -- Ensure tables exist
    if not db.inventoryGroupEnabled then db.inventoryGroupEnabled = {} end
    if not db.disabledDefaults then db.disabledDefaults = {} end
    if not db.userEntries then db.userEntries = {} end

    local function RebuildContent()
        -- Clear existing elements
        for _, elem in ipairs(allElements) do
            elem:Hide()
            elem:SetParent(nil)
        end
        wipe(allElements)

        local yOffset = -5
        local totalHeight = 10

        -- Description
        local desc = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        desc:SetPoint("TOPLEFT", 10, yOffset)
        desc:SetWidth(420)
        desc:SetJustifyH("LEFT")
        desc:SetText(W.Colorize("Checks if you have these items in your bags. Some items only checked when required class is in group.", C.GRAY))
        allElements[#allElements + 1] = desc
        yOffset = yOffset - 32
        totalHeight = totalHeight + 32

        -- Iterate through each inventory group
        for _, group in ipairs(Categories.INVENTORY_GROUPS) do
            local groupKey = "inventory_" .. group.key

            -- Default to enabled if not set
            if db.inventoryGroupEnabled[group.key] == nil then
                db.inventoryGroupEnabled[group.key] = true
            end

            local isGroupEnabled = db.inventoryGroupEnabled[group.key]

            -- Ensure tables for this group
            if not db.disabledDefaults[groupKey] then
                db.disabledDefaults[groupKey] = {}
            end
            if not db.userEntries[groupKey] then
                db.userEntries[groupKey] = { itemIDs = {} }
            end

            -- Group header with enable checkbox
            local header = CreateFrame("Frame", nil, contentFrame, "BackdropTemplate")
            header:SetSize(420, 24)
            header:SetPoint("TOPLEFT", 10, yOffset)
            header:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
            header:SetBackdropColor(0.15, 0.15, 0.15, 0.8)
            allElements[#allElements + 1] = header

            -- Enable checkbox
            local enableCB = CreateFrame("CheckButton", nil, header, "ChatConfigCheckButtonTemplate")
            enableCB:SetPoint("LEFT", 4, 0)
            enableCB:SetSize(20, 20)
            enableCB:SetChecked(isGroupEnabled)
            enableCB:SetScript("OnClick", function(self)
                db.inventoryGroupEnabled[group.key] = self:GetChecked()
                RebuildContent()
            end)

            local headerText = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            headerText:SetPoint("LEFT", enableCB, "RIGHT", 2, 0)
            if isGroupEnabled then
                headerText:SetText(W.Colorize(group.name, C.ORANGE))
            else
                headerText:SetText(W.Colorize(group.name .. " (disabled)", C.GRAY))
            end

            -- Show exclusive tag and requireClass if applicable
            if isGroupEnabled then
                local tagText = "(exclusive - one required)"
                if group.requireClass then
                    tagText = "(exclusive, requires " .. group.requireClass .. ")"
                end
                local exclusiveTag = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                exclusiveTag:SetPoint("LEFT", headerText, "RIGHT", 8, 0)
                exclusiveTag:SetText(W.Colorize(tagText, C.GRAY))
            end

            yOffset = yOffset - 26
            totalHeight = totalHeight + 26

            -- Skip content if group is disabled
            if not isGroupEnabled then
                yOffset = yOffset - 4
                totalHeight = totalHeight + 4
            else
                local hasDisabledDefaults = false

                -- Show default item IDs
                for _, itemID in ipairs(group.itemIDs or {}) do
                    if db.disabledDefaults[groupKey][itemID] then
                        hasDisabledDefaults = true
                    else
                        local capturedID = itemID
                        local row = CreateIDRow(contentFrame, itemID, "item", true, function()
                            db.disabledDefaults[groupKey][capturedID] = true
                            RebuildContent()
                        end, yOffset)
                        allElements[#allElements + 1] = row
                        yOffset = yOffset - ROW_HEIGHT
                        totalHeight = totalHeight + ROW_HEIGHT
                    end
                end

                -- Show user-added item IDs
                local userIDs = db.userEntries[groupKey].itemIDs or {}
                for idx = 1, #userIDs do
                    local itemID = userIDs[idx]
                    local deleteIdx = idx
                    local row = CreateIDRow(contentFrame, itemID, "item", false, function()
                        table.remove(db.userEntries[groupKey].itemIDs, deleteIdx)
                        RebuildContent()
                    end, yOffset)
                    allElements[#allElements + 1] = row
                    yOffset = yOffset - ROW_HEIGHT
                    totalHeight = totalHeight + ROW_HEIGHT
                end

                -- Add input row
                local inputRow = CreateFrame("Frame", nil, contentFrame)
                inputRow:SetSize(400, 24)
                inputRow:SetPoint("TOPLEFT", 20, yOffset - 2)
                allElements[#allElements + 1] = inputRow

                local inputLabel = inputRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                inputLabel:SetPoint("LEFT", 0, 0)
                inputLabel:SetText("Add Item ID:")

                local inputBox = CreateFrame("EditBox", nil, inputRow, "InputBoxTemplate")
                inputBox:SetSize(80, 18)
                inputBox:SetPoint("LEFT", inputLabel, "RIGHT", 6, 0)
                inputBox:SetNumeric(true)
                inputBox:SetAutoFocus(false)

                local capturedGroupKey = groupKey
                local addBtn = W:CreateButton(inputRow, {
                    text = "Add",
                    width = 45,
                    onClick = function()
                        local id = tonumber(inputBox:GetText())
                        if id and id > 0 then
                            table.insert(db.userEntries[capturedGroupKey].itemIDs, id)
                            inputBox:SetText("")
                            RebuildContent()
                        end
                    end,
                })
                addBtn:SetPoint("LEFT", inputBox, "RIGHT", 4, 0)

                -- Restore defaults button if needed
                if hasDisabledDefaults then
                    local restoreBtn = W:CreateButton(inputRow, {
                        text = "Restore",
                        width = 60,
                        onClick = function()
                            wipe(db.disabledDefaults[capturedGroupKey])
                            RebuildContent()
                        end,
                    })
                    restoreBtn:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
                end

                yOffset = yOffset - 30
                totalHeight = totalHeight + 32

                -- Spacer between groups
                yOffset = yOffset - 8
                totalHeight = totalHeight + 8
            end
        end

        contentFrame:SetHeight(totalHeight)

        if wrapperFrame and wrapperFrame.RecalcHeight then
            wrapperFrame:RecalcHeight()
        end

        if layoutRef and layoutRef.func then
            layoutRef.func()
        end
    end

    RebuildContent()
    return RebuildContent
end

-- Modal for adding/editing class buff groups
local classBuffModal = nil

local function ShowClassBuffModal(initialClassName, groupData, onSave, onDelete, db)
    -- Create modal if not exists
    if not classBuffModal then
        classBuffModal = CreateFrame("Frame", "NaowhQOL_ClassBuffModal", UIParent, "BackdropTemplate")
        classBuffModal:SetSize(520, 355)
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
    end

    local modal = classBuffModal
    local isEdit = groupData ~= nil
    modal.title:SetText(isEdit and "Edit Buff Group" or "Add Buff Group")

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

    -- Left side - settings
    local leftContent = CreateFrame("Frame", nil, modal)
    leftContent:SetPoint("TOPLEFT", 15, -40)
    leftContent:SetSize(250, 265)
    modal.leftContent = leftContent

    -- Right side - spell IDs
    local rightContent = CreateFrame("Frame", nil, modal)
    rightContent:SetPoint("TOPRIGHT", -15, -40)
    rightContent:SetSize(230, 265)
    modal.rightContent = rightContent

    -- Editing state
    local editState = {
        className = initialClassName,
        name = groupData and groupData.name or "",
        checkType = groupData and groupData.checkType or "self",
        exclusive = groupData and groupData.exclusive ~= false,
        specFilter = groupData and groupData.specFilter and {unpack(groupData.specFilter)} or {},
        spellIDs = groupData and groupData.spellIDs and {unpack(groupData.spellIDs)} or {},
        enchantIDs = groupData and groupData.enchantIDs and {unpack(groupData.enchantIDs)} or {},
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
        allLabel:SetText("All specs")
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
    classLabel:SetText("Class:")

    local classDropdown = CreateFrame("Frame", nil, leftContent, "UIDropDownMenuTemplate")
    classDropdown:SetPoint("LEFT", classLabel, "RIGHT", -5, -2)
    UIDropDownMenu_SetWidth(classDropdown, 130)

    local function UpdateClassDropdownText()
        local classInfo = Categories.CLASS_INFO[editState.className]
        UIDropDownMenu_SetText(classDropdown, classInfo and classInfo.name or "Select Class")
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
    nameLabel:SetText("Group Name:")

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
    typeLabel:SetText("Check Type:")

    yOffset = yOffset - 18

    local checkTypes = {
        { key = "self", label = "Self Buff" },
        { key = "targeted", label = "Targeted (on others)" },
        { key = "weaponEnchant", label = "Weapon Enchant" },
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

    -- Exclusive checkbox
    local exclusiveCB = CreateFrame("CheckButton", nil, leftContent, "ChatConfigCheckButtonTemplate")
    exclusiveCB:SetPoint("TOPLEFT", 0, yOffset)
    exclusiveCB:SetChecked(editState.exclusive)
    exclusiveCB:SetScript("OnClick", function(self)
        editState.exclusive = self:GetChecked()
    end)

    local exclusiveLabel = leftContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    exclusiveLabel:SetPoint("LEFT", exclusiveCB, "RIGHT", 2, 0)
    exclusiveLabel:SetText("Exclusive (any one = pass)")

    yOffset = yOffset - 25

    -- Spec Filter label
    local specLabel = leftContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    specLabel:SetPoint("TOPLEFT", 0, yOffset)
    specLabel:SetText("Specs:")

    -- Create spec container anchored below the label
    specContainer = CreateFrame("Frame", nil, leftContent)
    specContainer:SetPoint("TOPLEFT", specLabel, "BOTTOMLEFT", 0, -2)
    specContainer:SetSize(240, 100)

    -- Build initial spec checkboxes
    RebuildSpecCheckboxes()

    -- === RIGHT SIDE ===
    local idLabel = rightContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    idLabel:SetPoint("TOPLEFT", 0, 0)
    idLabel:SetText("Spell/Enchant IDs:")

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
            local name = info and info.name or "Unknown"
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
        text = "Save",
        width = 80,
        onClick = function()
            if not editState.className then
                print("|cffff0000[BuffWatcher]|r Please select a class")
                return
            end

            if editState.name == "" then
                print("|cffff0000[BuffWatcher]|r Group name is required")
                return
            end

            local ids = editState.checkType == "weaponEnchant" and editState.enchantIDs or editState.spellIDs
            if #ids == 0 then
                print("|cffff0000[BuffWatcher]|r At least one spell/enchant ID is required")
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
                exclusive = editState.exclusive,
                specFilter = editState.specFilter,
                spellIDs = editState.checkType ~= "weaponEnchant" and editState.spellIDs or nil,
                enchantIDs = editState.checkType == "weaponEnchant" and editState.enchantIDs or nil,
            }

            if onSave then onSave(editState.className, newGroup) end
            modal:Hide()
        end,
    })
    modal.saveBtn:SetPoint("BOTTOMLEFT", 15, 15)

    modal.cancelBtn = W:CreateButton(modal, {
        text = "Cancel",
        width = 80,
        onClick = function()
            modal:Hide()
        end,
    })
    modal.cancelBtn:SetPoint("LEFT", modal.saveBtn, "RIGHT", 10, 0)

    if isEdit and onDelete then
        modal.deleteBtn = W:CreateButton(modal, {
            text = "Delete",
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

-- Create class buffs section content
local function CreateClassBuffsContent(contentFrame, db, wrapperFrame, layoutRef)
    local allElements = {}
    local classWrappers = {}
    local expandedState = {}  -- Persists across rebuilds

    local function RebuildContent()
        -- Clear existing elements
        for _, elem in ipairs(allElements) do
            if elem.Hide then elem:Hide() end
        end
        wipe(allElements)
        wipe(classWrappers)

        local _, playerClass = UnitClass("player")
        local yOffset = -5
        local totalHeight = 10

        -- Create a section for each class
        for _, className in ipairs(Categories.CLASS_ORDER) do
            local classInfo = Categories.CLASS_INFO[className]
            local classData = db.classBuffs[className]

            if not classData then
                db.classBuffs[className] = { enabled = true, groups = {} }
                classData = db.classBuffs[className]
            end

            -- Class header row
            local header = CreateFrame("Frame", nil, contentFrame, "BackdropTemplate")
            header:SetSize(420, 26)
            header:SetPoint("TOPLEFT", 10, yOffset)
            header:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })

            local isPlayerClass = className == playerClass
            if isPlayerClass then
                header:SetBackdropColor(0.2, 0.3, 0.2, 0.9)
            else
                header:SetBackdropColor(0.12, 0.12, 0.12, 0.8)
            end
            allElements[#allElements + 1] = header

            -- Enable checkbox
            local enableCB = CreateFrame("CheckButton", nil, header, "ChatConfigCheckButtonTemplate")
            enableCB:SetPoint("LEFT", 4, 0)
            enableCB:SetSize(20, 20)
            enableCB:SetChecked(classData.enabled)
            enableCB:SetScript("OnClick", function(self)
                classData.enabled = self:GetChecked()
            end)

            -- Class name
            local headerText = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            headerText:SetPoint("LEFT", enableCB, "RIGHT", 2, 0)
            headerText:SetText(classInfo.name)
            if isPlayerClass then
                headerText:SetText(W.Colorize(classInfo.name .. " (You)", C.ORANGE))
            end

            -- Group count
            local groupCount = #(classData.groups or {})
            local countText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            countText:SetPoint("LEFT", headerText, "RIGHT", 8, 0)
            countText:SetText(W.Colorize("(" .. groupCount .. " groups)", C.GRAY))

            -- Expand/collapse button
            local expandBtn = CreateFrame("Button", nil, header)
            expandBtn:SetSize(20, 20)
            expandBtn:SetPoint("RIGHT", -4, 0)
            expandBtn:SetNormalFontObject("GameFontNormal")

            local classContent = CreateFrame("Frame", nil, contentFrame)
            classContent:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 10, -2)
            classContent:SetSize(400, 1)
            allElements[#allElements + 1] = classContent

            -- Use saved state, or default to expanded for player's class
            if expandedState[className] == nil then
                expandedState[className] = isPlayerClass
            end
            local isExpanded = expandedState[className]
            classWrappers[className] = { header = header, content = classContent, expanded = isExpanded }

            local function UpdateExpand()
                if isExpanded then
                    expandBtn:SetText("-")
                    classContent:Show()
                else
                    expandBtn:SetText("+")
                    classContent:Hide()
                end
            end

            expandBtn:SetScript("OnClick", function()
                expandedState[className] = not expandedState[className]
                RebuildContent()
            end)

            UpdateExpand()

            yOffset = yOffset - 28
            totalHeight = totalHeight + 28

            -- Class content (groups + add button)
            if isExpanded then
                local contentY = -2
                local contentHeight = 4

                -- Show existing groups
                for i, group in ipairs(classData.groups or {}) do
                    local groupRow = CreateFrame("Frame", nil, classContent, "BackdropTemplate")
                    groupRow:SetSize(390, 24)
                    groupRow:SetPoint("TOPLEFT", 0, contentY)
                    groupRow:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
                    groupRow:SetBackdropColor(0.08, 0.08, 0.08, 0.6)

                    local groupName = groupRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    groupName:SetPoint("LEFT", 8, 0)

                    local typeTag = ""
                    if group.checkType == "targeted" then typeTag = " [targeted]"
                    elseif group.checkType == "weaponEnchant" then typeTag = " [weapon]"
                    end

                    local exclusiveTag = group.exclusive and " (exclusive)" or ""
                    groupName:SetText(group.name .. W.Colorize(typeTag .. exclusiveTag, C.GRAY))

                    -- Edit button
                    local editBtn = CreateFrame("Button", nil, groupRow, "UIPanelButtonTemplate")
                    editBtn:SetSize(40, 18)
                    editBtn:SetPoint("RIGHT", -30, 0)
                    editBtn:SetText("Edit")
                    editBtn:SetScript("OnClick", function()
                        ShowClassBuffModal(className, group, function(selectedClass, newGroup)
                            -- Update group (class cannot change during edit)
                            for k, v in pairs(newGroup) do
                                group[k] = v
                            end
                            RebuildContent()
                        end, function()
                            -- Delete group
                            table.remove(classData.groups, i)
                            RebuildContent()
                        end, db)
                    end)

                    -- Delete button
                    local delBtn = CreateFrame("Button", nil, groupRow, "UIPanelButtonTemplate")
                    delBtn:SetSize(20, 18)
                    delBtn:SetPoint("RIGHT", -4, 0)
                    delBtn:SetText("X")
                    delBtn:SetScript("OnClick", function()
                        table.remove(classData.groups, i)
                        RebuildContent()
                    end)

                    contentY = contentY - 26
                    contentHeight = contentHeight + 26
                end

                -- Add Group button
                local addBtn = W:CreateButton(classContent, {
                    text = "+ Add Group",
                    width = 100,
                    onClick = function()
                        ShowClassBuffModal(className, nil, function(selectedClass, newGroup)
                            -- Add to the selected class (user can change class in modal)
                            local targetClassData = db.classBuffs[selectedClass]
                            if not targetClassData then
                                db.classBuffs[selectedClass] = { enabled = true, groups = {} }
                                targetClassData = db.classBuffs[selectedClass]
                            end
                            if not targetClassData.groups then targetClassData.groups = {} end
                            table.insert(targetClassData.groups, newGroup)
                            RebuildContent()
                        end, nil, db)
                    end,
                })
                addBtn:SetPoint("TOPLEFT", 0, contentY - 2)

                contentHeight = contentHeight + 28
                classContent:SetHeight(contentHeight)

                yOffset = yOffset - contentHeight
                totalHeight = totalHeight + contentHeight
            end

            yOffset = yOffset - 4
            totalHeight = totalHeight + 4
        end

        contentFrame:SetHeight(totalHeight)

        if wrapperFrame and wrapperFrame.RecalcHeight then
            wrapperFrame:RecalcHeight()
        end

        if layoutRef and layoutRef.func then
            layoutRef.func()
        end
    end

    RebuildContent()
    return RebuildContent
end

function ns:InitBuffWatcherV2()
    local p = ns.MainFrame.Content
    local db = BWV2:GetDB()

    W:CachedPanel(cache, "bwv2Frame", p, function(f)
        local sf, sc = W:CreateScrollFrame(f, 2000)

        W:CreatePageHeader(sc,
            {{"BUFF ", C.BLUE}, {"WATCHER", C.ORANGE}},
            W.Colorize("Raid buff scanner triggered on ready check", C.GRAY))

        -- Master enable area (killswitch)
        local killArea = CreateFrame("Frame", nil, sc, "BackdropTemplate")
        killArea:SetSize(460, 62)
        killArea:SetPoint("TOPLEFT", 10, -75)
        killArea:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
        killArea:SetBackdropColor(0.01, 0.56, 0.91, 0.08)

        local masterCB = W:CreateCheckbox(killArea, {
            label = "Enable Buff Watcher",
            db = db, key = "enabled",
            x = 15, y = -8,
            isMaster = true,
        })

        -- Scan button (secondary control, like unlock checkbox)
        local scanBtn = W:CreateButton(killArea, {
            text = "Scan Now",
            width = 100,
            onClick = function()
                if Core then
                    Core:TriggerScan()
                end
            end,
        })
        scanBtn:SetPoint("TOPLEFT", 15, -35)

        local scanHint = killArea:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        scanHint:SetPoint("LEFT", scanBtn, "RIGHT", 8, 0)
        scanHint:SetText(W.Colorize("or use /nscan", C.GRAY))

        -- Sections container
        local sectionContainer = CreateFrame("Frame", nil, sc)
        sectionContainer:SetPoint("TOPLEFT", killArea, "BOTTOMLEFT", 0, -10)
        sectionContainer:SetPoint("RIGHT", sc, "RIGHT", -10, 0)
        sectionContainer:SetHeight(1500)

        -- Reference table so we can update RelayoutAll after definition
        local layoutRef = { func = nil }
        local RelayoutAll

        ---------------------------------------------------------------
        -- THRESHOLDS SECTION
        ---------------------------------------------------------------
        local threshWrap, threshContent = W:CreateCollapsibleSection(sectionContainer, {
            text = "DURATION THRESHOLDS",
            startOpen = false,
            onCollapse = function() if RelayoutAll then RelayoutAll() end end,
        })

        local threshDesc = threshContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        threshDesc:SetPoint("TOPLEFT", 10, -5)
        threshDesc:SetWidth(420)
        threshDesc:SetJustifyH("LEFT")
        threshDesc:SetText(W.Colorize("Minimum remaining duration (minutes) for buffs to be considered active.", C.GRAY))

        -- Threshold inputs (display in minutes, store in seconds)
        local threshY = -30

        local dungeonLabel = threshContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        dungeonLabel:SetPoint("TOPLEFT", 10, threshY)
        dungeonLabel:SetText("Dungeon:")

        local dungeonInput = CreateFrame("EditBox", nil, threshContent, "InputBoxTemplate")
        dungeonInput:SetSize(40, 20)
        dungeonInput:SetPoint("LEFT", dungeonLabel, "RIGHT", 8, 0)
        dungeonInput:SetNumeric(true)
        dungeonInput:SetAutoFocus(false)
        dungeonInput:SetText(tostring(math.floor(db.thresholds.dungeon / 60)))
        dungeonInput:SetScript("OnTextChanged", function(self)
            local val = tonumber(self:GetText())
            if val then db.thresholds.dungeon = val * 60 end
        end)

        local dungeonMin = threshContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        dungeonMin:SetPoint("LEFT", dungeonInput, "RIGHT", 4, 0)
        dungeonMin:SetText("min")

        local raidLabel = threshContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        raidLabel:SetPoint("LEFT", dungeonMin, "RIGHT", 15, 0)
        raidLabel:SetText("Raid:")

        local raidInput = CreateFrame("EditBox", nil, threshContent, "InputBoxTemplate")
        raidInput:SetSize(40, 20)
        raidInput:SetPoint("LEFT", raidLabel, "RIGHT", 8, 0)
        raidInput:SetNumeric(true)
        raidInput:SetAutoFocus(false)
        raidInput:SetText(tostring(math.floor(db.thresholds.raid / 60)))
        raidInput:SetScript("OnTextChanged", function(self)
            local val = tonumber(self:GetText())
            if val then db.thresholds.raid = val * 60 end
        end)

        local raidMin = threshContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        raidMin:SetPoint("LEFT", raidInput, "RIGHT", 4, 0)
        raidMin:SetText("min")

        local otherLabel = threshContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        otherLabel:SetPoint("LEFT", raidMin, "RIGHT", 15, 0)
        otherLabel:SetText("Other:")

        local otherInput = CreateFrame("EditBox", nil, threshContent, "InputBoxTemplate")
        otherInput:SetSize(40, 20)
        otherInput:SetPoint("LEFT", otherLabel, "RIGHT", 8, 0)
        otherInput:SetNumeric(true)
        otherInput:SetAutoFocus(false)
        otherInput:SetText(tostring(math.floor(db.thresholds.other / 60)))
        otherInput:SetScript("OnTextChanged", function(self)
            local val = tonumber(self:GetText())
            if val then db.thresholds.other = val * 60 end
        end)

        local otherMin = threshContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        otherMin:SetPoint("LEFT", otherInput, "RIGHT", 4, 0)
        otherMin:SetText("min")

        threshContent:SetHeight(70)
        threshWrap:RecalcHeight()

        ---------------------------------------------------------------
        -- RAID BUFFS SECTION
        ---------------------------------------------------------------
        local raidWrap, raidContent = W:CreateCollapsibleSection(sectionContainer, {
            text = "RAID BUFFS",
            startOpen = true,
            onCollapse = function() if RelayoutAll then RelayoutAll() end end,
        })

        CreateSpellListContent(raidContent, Categories.RAID, "raidBuffs", db, raidWrap, layoutRef)

        ---------------------------------------------------------------
        -- CONSUMABLES SECTION (with subgroups)
        ---------------------------------------------------------------
        local consWrap, consContent = W:CreateCollapsibleSection(sectionContainer, {
            text = "CONSUMABLES",
            startOpen = false,
            onCollapse = function() if RelayoutAll then RelayoutAll() end end,
        })

        CreateConsumableGroupsContent(consContent, db, consWrap, layoutRef)

        ---------------------------------------------------------------
        -- INVENTORY CHECK SECTION
        ---------------------------------------------------------------
        local invWrap, invContent = W:CreateCollapsibleSection(sectionContainer, {
            text = "INVENTORY CHECK",
            startOpen = false,
            onCollapse = function() if RelayoutAll then RelayoutAll() end end,
        })

        CreateInventoryGroupsContent(invContent, db, invWrap, layoutRef)

        ---------------------------------------------------------------
        -- CLASS BUFFS SECTION
        ---------------------------------------------------------------
        local classBuffsWrap, classBuffsContent = W:CreateCollapsibleSection(sectionContainer, {
            text = "CLASS BUFFS",
            startOpen = true,
            onCollapse = function() if RelayoutAll then RelayoutAll() end end,
        })

        CreateClassBuffsContent(classBuffsContent, db, classBuffsWrap, layoutRef)

        ---------------------------------------------------------------
        -- TALENT MODIFICATIONS SECTION
        ---------------------------------------------------------------
        local talentWrap, talentContent = W:CreateCollapsibleSection(sectionContainer, {
            text = "TALENT MODIFICATIONS",
            startOpen = false,
            onCollapse = function() if RelayoutAll then RelayoutAll() end end,
        })

        local talentDesc = talentContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        talentDesc:SetPoint("TOPLEFT", 10, -5)
        talentDesc:SetWidth(420)
        talentDesc:SetJustifyH("LEFT")
        talentDesc:SetText(W.Colorize("Define rules that modify requirements when talents are active.\nTypes: requireCount, requireSpellID, skipIfTalent", C.GRAY))

        -- Show existing talent mods
        local talentY = -45
        local talentMods = db.talentMods or {}

        for catKey, rules in pairs(talentMods) do
            if type(rules) == "table" and #rules > 0 then
                local catLabel = talentContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                catLabel:SetPoint("TOPLEFT", 10, talentY)
                catLabel:SetText(W.Colorize(catKey .. ":", C.ORANGE))
                talentY = talentY - 20

                for _, rule in ipairs(rules) do
                    local info = C_Spell.GetSpellInfo(rule.talentID)
                    local talentName = info and info.name or "Unknown"
                    local ruleText = string.format("  %s (%d) - %s", talentName, rule.talentID, rule.type)
                    if rule.count then ruleText = ruleText .. " = " .. rule.count end

                    local ruleLabel = talentContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    ruleLabel:SetPoint("TOPLEFT", 20, talentY)
                    ruleLabel:SetText(ruleText)
                    talentY = talentY - 18
                end
            end
        end

        talentContent:SetHeight(math.abs(talentY) + 10)
        talentWrap:RecalcHeight()

        ---------------------------------------------------------------
        -- LAYOUT FUNCTION
        ---------------------------------------------------------------
        RelayoutAll = function()
            local yOffset = 0

            threshWrap:ClearAllPoints()
            threshWrap:SetPoint("TOPLEFT", sectionContainer, "TOPLEFT", 0, yOffset)
            yOffset = yOffset - threshWrap:GetHeight() - 5

            raidWrap:ClearAllPoints()
            raidWrap:SetPoint("TOPLEFT", sectionContainer, "TOPLEFT", 0, yOffset)
            yOffset = yOffset - raidWrap:GetHeight() - 5

            consWrap:ClearAllPoints()
            consWrap:SetPoint("TOPLEFT", sectionContainer, "TOPLEFT", 0, yOffset)
            yOffset = yOffset - consWrap:GetHeight() - 5

            invWrap:ClearAllPoints()
            invWrap:SetPoint("TOPLEFT", sectionContainer, "TOPLEFT", 0, yOffset)
            yOffset = yOffset - invWrap:GetHeight() - 5

            classBuffsWrap:ClearAllPoints()
            classBuffsWrap:SetPoint("TOPLEFT", sectionContainer, "TOPLEFT", 0, yOffset)
            yOffset = yOffset - classBuffsWrap:GetHeight() - 5

            talentWrap:ClearAllPoints()
            talentWrap:SetPoint("TOPLEFT", sectionContainer, "TOPLEFT", 0, yOffset)
            yOffset = yOffset - talentWrap:GetHeight() - 5

            sectionContainer:SetHeight(math.abs(yOffset) + 20)
            sc:SetHeight(math.abs(yOffset) + 180)
        end

        -- Set the reference so CreateSpellListContent callbacks can use it
        layoutRef.func = RelayoutAll

        RelayoutAll()
    end)
end
