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
    local spellName = info and info.name or L["BWV2_UNKNOWN"]

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
        defaultTag:SetText(W.Colorize(L["BWV2_DEFAULT_TAG"], C.GRAY))
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
        inputLabel:SetText(L["BWV2_ADD_SPELL_ID"])

        local inputBox = CreateFrame("EditBox", nil, inputRow, "InputBoxTemplate")
        inputBox:SetSize(100, 20)
        inputBox:SetPoint("LEFT", inputLabel, "RIGHT", 8, 0)
        inputBox:SetNumeric(true)
        inputBox:SetAutoFocus(false)

        local addBtn = W:CreateButton(inputRow, {
            text = L["COMMON_ADD"],
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
                text = L["BWV2_RESTORE_DEFAULTS"],
                width = 110,
                onClick = function()
                    wipe(db.disabledDefaults[categoryKey])
                    RebuildContent()
                end,
            })
            restoreBtn:SetPoint("LEFT", 0, 0)

            local restoreHint = restoreRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            restoreHint:SetPoint("LEFT", restoreBtn, "RIGHT", 8, 0)
            restoreHint:SetText(W.Colorize(L["BWV2_DEFAULTS_HIDDEN"], C.GRAY))

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

    local displayName = L["BWV2_UNKNOWN"]
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
        defaultTag:SetText(W.Colorize(L["BWV2_DEFAULT_TAG"], C.GRAY))
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
                headerText:SetText(W.Colorize(group.name .. " " .. L["BWV2_DISABLED"], C.GRAY))
            end

            local exclusiveTag = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            exclusiveTag:SetPoint("LEFT", headerText, "RIGHT", 8, 0)
            if isGroupEnabled then
                exclusiveTag:SetText(W.Colorize(L["BWV2_EXCLUSIVE_ONE"], C.GRAY))
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
                iconNote:SetText(W.Colorize(L["BWV2_FOOD_BUFF_DETECT"], C.GRAY))
                allElements[#allElements + 1] = iconNote
                yOffset = yOffset - 18
                totalHeight = totalHeight + 18
            elseif group.checkType == "weaponEnchant" then
                local enchantNote = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                enchantNote:SetPoint("TOPLEFT", 25, yOffset)
                enchantNote:SetText(W.Colorize(L["BWV2_WEAPON_ENCHANT_DETECT"], C.GRAY))
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

            -- Add input row (skip for icon/weaponEnchant check types - those don't use spell IDs)
            if group.checkType ~= "icon" and group.checkType ~= "weaponEnchant" then
                local inputRow = CreateFrame("Frame", nil, contentFrame)
                inputRow:SetSize(400, 24)
                inputRow:SetPoint("TOPLEFT", 20, yOffset - 2)
                allElements[#allElements + 1] = inputRow

                local inputLabel = inputRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                inputLabel:SetPoint("LEFT", 0, 0)
                inputLabel:SetText(idType == "item" and L["BWV2_ADD_ITEM_ID"] or L["BWV2_ADD_SPELL_ID"])

                local inputBox = CreateFrame("EditBox", nil, inputRow, "InputBoxTemplate")
                inputBox:SetSize(80, 18)
                inputBox:SetPoint("LEFT", inputLabel, "RIGHT", 6, 0)
                inputBox:SetNumeric(true)
                inputBox:SetAutoFocus(false)

                local capturedGroupKey = groupKey
                local capturedIdType = idType
                local addBtn = W:CreateButton(inputRow, {
                    text = L["COMMON_ADD"],
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
                        text = L["BWV2_RESTORE"],
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
            end

            -- Auto-use item row (for click-to-use: flasks, food, runes, weapon oils/stones)
                -- Ensure consumableAutoUse exists
                if not db.consumableAutoUse then
                    db.consumableAutoUse = {}
                end

                local autoUseRow = CreateFrame("Frame", nil, contentFrame)
                autoUseRow:SetSize(400, 26)
                autoUseRow:SetPoint("TOPLEFT", 20, yOffset - 2)
                allElements[#allElements + 1] = autoUseRow

                local autoLabel = autoUseRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                autoLabel:SetPoint("LEFT", 0, 0)
                autoLabel:SetText(L["BWV2_AUTO_USE_ITEM"])

                local currentItemID = db.consumableAutoUse[group.key]
                local capturedKey = group.key

                if currentItemID then
                    -- Parse all IDs for display
                    local itemIDs = {}
                    for id in tostring(currentItemID):gmatch("%d+") do
                        itemIDs[#itemIDs + 1] = tonumber(id)
                    end

                    -- Show first item's icon
                    local firstID = itemIDs[1]
                    local itemIcon = autoUseRow:CreateTexture(nil, "ARTWORK")
                    itemIcon:SetSize(18, 18)
                    itemIcon:SetPoint("LEFT", autoLabel, "RIGHT", 6, 0)
                    itemIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

                    local itemName, _, _, _, _, _, _, _, _, itemTex = C_Item.GetItemInfo(firstID)
                    if itemTex then
                        itemIcon:SetTexture(itemTex)
                    else
                        itemIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                    end

                    -- Show name with count indicator if multiple
                    local countText = #itemIDs > 1 and (" +" .. (#itemIDs - 1)) or ""
                    local itemText = autoUseRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    itemText:SetPoint("LEFT", itemIcon, "RIGHT", 4, 0)
                    itemText:SetText(W.Colorize((itemName or tostring(firstID)) .. countText, C.GREEN))

                    local clearBtn = W:CreateButton(autoUseRow, {
                        text = "X",
                        width = 22,
                        onClick = function()
                            db.consumableAutoUse[capturedKey] = nil
                            RebuildContent()
                        end,
                    })
                    clearBtn:SetPoint("LEFT", itemText, "RIGHT", 6, 0)
                else
                    -- Show input for setting item IDs (comma-separated)
                    local autoInput = CreateFrame("EditBox", nil, autoUseRow, "InputBoxTemplate")
                    autoInput:SetSize(140, 18)
                    autoInput:SetPoint("LEFT", autoLabel, "RIGHT", 6, 0)
                    autoInput:SetAutoFocus(false)

                    local setBtn = W:CreateButton(autoUseRow, {
                        text = L["COMMON_SET"],
                        width = 40,
                        onClick = function()
                            local text = autoInput:GetText():gsub("%s+", "")
                            if text ~= "" then
                                -- Validate: must be comma-separated numbers
                                local valid = true
                                for part in text:gmatch("[^,]+") do
                                    if not tonumber(part) then
                                        valid = false
                                        break
                                    end
                                end
                                if valid then
                                    db.consumableAutoUse[capturedKey] = text
                                    autoInput:SetText("")
                                    RebuildContent()
                                end
                            end
                        end,
                    })
                    setBtn:SetPoint("LEFT", autoInput, "RIGHT", 4, 0)
                end

                yOffset = yOffset - 28
                totalHeight = totalHeight + 28

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
        desc:SetText(W.Colorize(L["BWV2_INVENTORY_DESC"], C.GRAY))
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
                headerText:SetText(W.Colorize(group.name .. " " .. L["BWV2_DISABLED"], C.GRAY))
            end

            -- Show exclusive tag and requireClass if applicable
            if isGroupEnabled then
                local tagText = L["BWV2_EXCLUSIVE_ONE"]
                if group.requireClass then
                    tagText = string.format(L["BWV2_EXCLUSIVE_REQUIRES"], group.requireClass)
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
                inputLabel:SetText(L["BWV2_ADD_ITEM_ID"])

                local inputBox = CreateFrame("EditBox", nil, inputRow, "InputBoxTemplate")
                inputBox:SetSize(80, 18)
                inputBox:SetPoint("LEFT", inputLabel, "RIGHT", 6, 0)
                inputBox:SetNumeric(true)
                inputBox:SetAutoFocus(false)

                local capturedGroupKey = groupKey
                local addBtn = W:CreateButton(inputRow, {
                    text = L["COMMON_ADD"],
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
                        text = L["BWV2_RESTORE"],
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
                headerText:SetText(W.Colorize(classInfo.name .. " " .. L["BWV2_YOU"], C.ORANGE))
            end

            -- Group count
            local groupCount = #(classData.groups or {})
            local countText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            countText:SetPoint("LEFT", headerText, "RIGHT", 8, 0)
            countText:SetText(W.Colorize(string.format(L["BWV2_GROUPS_COUNT"], groupCount), C.GRAY))

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
                    if group.checkType == "targeted" then typeTag = " " .. L["BWV2_TAG_TARGETED"]
                    elseif group.checkType == "weaponEnchant" then typeTag = " " .. L["BWV2_TAG_WEAPON"]
                    end

                    local exclusiveTag = group.exclusive and " " .. L["BWV2_EXCLUSIVE"] or ""
                    groupName:SetText(group.name .. W.Colorize(typeTag .. exclusiveTag, C.GRAY))

                    -- Edit button
                    local editBtn = CreateFrame("Button", nil, groupRow, "UIPanelButtonTemplate")
                    editBtn:SetSize(40, 18)
                    editBtn:SetPoint("RIGHT", -30, 0)
                    editBtn:SetText(L["COMMON_EDIT"])
                    editBtn:SetScript("OnClick", function()
                        ns.ShowClassBuffModal(className, group, function(selectedClass, newGroup)
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
                    text = L["BWV2_ADD_GROUP"],
                    width = 100,
                    onClick = function()
                        ns.ShowClassBuffModal(className, nil, function(selectedClass, newGroup)
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
            W.Colorize(L["BWV2_SUBTITLE"], C.GRAY))

        -- Master enable area (killswitch)
        local killArea = CreateFrame("Frame", nil, sc, "BackdropTemplate")
        killArea:SetSize(460, 62)
        killArea:SetPoint("TOPLEFT", 10, -75)
        killArea:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
        killArea:SetBackdropColor(0.01, 0.56, 0.91, 0.08)

        local masterCB = W:CreateCheckbox(killArea, {
            label = L["BWV2_ENABLE"],
            db = db, key = "enabled",
            x = 15, y = -8,
            isMaster = true,
        })

        -- Scan button (secondary control, like unlock checkbox)
        local scanBtn = W:CreateButton(killArea, {
            text = L["BWV2_SCAN_NOW"],
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
        scanHint:SetText(W.Colorize(L["BWV2_SCAN_HINT"], C.GRAY))

        -- Sections container
        local sectionContainer = CreateFrame("Frame", nil, sc)
        sectionContainer:SetPoint("TOPLEFT", killArea, "BOTTOMLEFT", 0, -10)
        sectionContainer:SetPoint("RIGHT", sc, "RIGHT", -10, 0)
        sectionContainer:SetHeight(1500)

        -- Reference table so we can update RelayoutAll after definition
        local layoutRef = { func = nil }
        local RelayoutAll

        -- Section memory: restore last expanded section
        local lastSection = db.lastSection or "classBuffs"

        ---------------------------------------------------------------
        -- THRESHOLDS SECTION
        ---------------------------------------------------------------
        local threshWrap, threshContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["BWV2_SECTION_THRESHOLDS"],
            startOpen = (lastSection == "thresholds"),
            onCollapse = function(isOpen)
                if isOpen then db.lastSection = "thresholds" end
                if RelayoutAll then RelayoutAll() end
            end,
        })

        local threshDesc = threshContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        threshDesc:SetPoint("TOPLEFT", 10, -5)
        threshDesc:SetWidth(420)
        threshDesc:SetJustifyH("LEFT")
        threshDesc:SetText(W.Colorize(L["BWV2_THRESHOLD_DESC"], C.GRAY))

        -- Threshold inputs (display in minutes, store in seconds)
        local threshY = -30

        local dungeonLabel = threshContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        dungeonLabel:SetPoint("TOPLEFT", 10, threshY)
        dungeonLabel:SetText(L["BWV2_DUNGEON"])

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
        dungeonMin:SetText(L["BWV2_MIN"])

        local raidLabel = threshContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        raidLabel:SetPoint("LEFT", dungeonMin, "RIGHT", 15, 0)
        raidLabel:SetText(L["BWV2_RAID"])

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
        raidMin:SetText(L["BWV2_MIN"])

        local otherLabel = threshContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        otherLabel:SetPoint("LEFT", raidMin, "RIGHT", 15, 0)
        otherLabel:SetText(L["BWV2_OTHER"])

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
        otherMin:SetText(L["BWV2_MIN"])

        threshContent:SetHeight(70)
        threshWrap:RecalcHeight()

        ---------------------------------------------------------------
        -- RAID BUFFS SECTION
        ---------------------------------------------------------------
        local raidWrap, raidContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["BWV2_SECTION_RAID"],
            startOpen = (lastSection == "raidBuffs"),
            onCollapse = function(isOpen)
                if isOpen then db.lastSection = "raidBuffs" end
                if RelayoutAll then RelayoutAll() end
            end,
        })

        CreateSpellListContent(raidContent, Categories.RAID, "raidBuffs", db, raidWrap, layoutRef)

        ---------------------------------------------------------------
        -- CONSUMABLES SECTION (with subgroups)
        ---------------------------------------------------------------
        local consWrap, consContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["BWV2_SECTION_CONSUMABLES"],
            startOpen = (lastSection == "consumables"),
            onCollapse = function(isOpen)
                if isOpen then db.lastSection = "consumables" end
                if RelayoutAll then RelayoutAll() end
            end,
        })

        CreateConsumableGroupsContent(consContent, db, consWrap, layoutRef)

        ---------------------------------------------------------------
        -- INVENTORY CHECK SECTION
        ---------------------------------------------------------------
        local invWrap, invContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["BWV2_SECTION_INVENTORY"],
            startOpen = (lastSection == "inventory"),
            onCollapse = function(isOpen)
                if isOpen then db.lastSection = "inventory" end
                if RelayoutAll then RelayoutAll() end
            end,
        })

        CreateInventoryGroupsContent(invContent, db, invWrap, layoutRef)

        ---------------------------------------------------------------
        -- CLASS BUFFS SECTION
        ---------------------------------------------------------------
        local classBuffsWrap, classBuffsContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["BWV2_SECTION_CLASS"],
            startOpen = (lastSection == "classBuffs"),
            onCollapse = function(isOpen)
                if isOpen then db.lastSection = "classBuffs" end
                if RelayoutAll then RelayoutAll() end
            end,
        })

        CreateClassBuffsContent(classBuffsContent, db, classBuffsWrap, layoutRef)

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

            sectionContainer:SetHeight(math.abs(yOffset) + 20)
            sc:SetHeight(math.abs(yOffset) + 180)
        end

        -- Set the reference so CreateSpellListContent callbacks can use it
        layoutRef.func = RelayoutAll

        RelayoutAll()
    end)
end
