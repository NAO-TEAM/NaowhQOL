local addonName, ns = ...

-- Removes the "type DELETE" requirement for superior quality items
-- and shows item links in destroy confirmation popups.

local function IsEnabled()
    return NaowhQOL.misc and NaowhQOL.misc.autoFillDelete
end

local function ResolveItemLinkFromCursor()
    local infoType, id, link = GetCursorInfo()
    if not infoType then return nil end

    if infoType == "battlepet" then
        local speciesID = id
        local name = C_PetJournal and C_PetJournal.GetPetInfoBySpeciesID(speciesID)
        if name and name ~= "" then
            return "|cff0070dd[" .. name .. "]|r"
        end
        return nil
    end

    if infoType == "item" and link then
        return link
    end

    return nil
end

local function StripDeleteInstruction(originalText)
    if not originalText then return originalText end

    local deleteGoodStr = DELETE_GOOD_ITEM
    if not deleteGoodStr then return originalText end

    local boundary = string.find(deleteGoodStr, "\n")
    if not boundary then return originalText end

    local instructionBlock = string.sub(deleteGoodStr, boundary)
    local cleanedBlock = string.gsub(instructionBlock, "%%s", "")
    cleanedBlock = strtrim(cleanedBlock)

    if cleanedBlock == "" then return originalText end

    local matchStart = string.find(originalText, cleanedBlock, 1, true)
    if matchStart then
        return strtrim(string.sub(originalText, 1, matchStart - 1))
    end

    return originalText
end

local function OnDeleteHyperlinkEnter(self, linkData, text)
    if not linkData then return end
    local linkType = string.match(linkData, "^(%a+)")
    if linkType == "item" then
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetHyperlink(linkData)
        GameTooltip:Show()
    elseif linkType == "battlepet" and BattlePetToolTip_ShowLink then
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        BattlePetToolTip_ShowLink(linkData)
    end
end

local function OnDeleteHyperlinkLeave(self)
    GameTooltip:Hide()
    if BattlePetTooltip then BattlePetTooltip:Hide() end
end

local DESTROY_DIALOG_NAMES = {
    "DELETE_ITEM",
    "DELETE_QUEST_ITEM",
    "DELETE_GOOD_QUEST_ITEM",
}

local function PatchDeleteDialogs()
    for _, name in ipairs(DESTROY_DIALOG_NAMES) do
        local dlg = StaticPopupDialogs[name]
        if dlg then
            dlg.OnHyperlinkEnter = OnDeleteHyperlinkEnter
            dlg.OnHyperlinkLeave = OnDeleteHyperlinkLeave
        end
    end
end

local function HandleDeleteConfirm()
    if not IsEnabled() then return end

    local popupCount = STATICPOPUP_NUMDIALOGS or 4
    local activePopup, activeEditBox, activeButton

    for i = 1, popupCount do
        local popup = _G["StaticPopup" .. i]
        if popup and popup:IsShown() then
            local editBox = _G["StaticPopup" .. i .. "EditBox"]
            local btn = _G["StaticPopup" .. i .. "Button1"]
            if editBox and btn then
                activePopup = popup
                activeEditBox = editBox
                activeButton = btn
                break
            end
        end
    end

    if not activePopup then return end

    local itemLink = ResolveItemLinkFromCursor()
    local requiresTyping = activeEditBox and activeEditBox:IsShown()

    if activeEditBox then activeEditBox:Hide() end
    if activeButton then activeButton:Enable() end

    -- Safely get the text region with nil checks
    local popupName = activePopup:GetName()
    local textRegion = popupName and _G[popupName .. "Text"]
    if textRegion and itemLink then
        local currentText = textRegion:GetText() or ""
        local cleanText = StripDeleteInstruction(currentText)

        if not requiresTyping then
            local extraHeight = itemLink and 32 or 0
            activePopup:SetHeight(activePopup:GetHeight() + extraHeight)
        end

        textRegion:SetText(cleanText .. "\n\n" .. itemLink)
    end
end

local destroyFrame = CreateFrame("Frame", "NaowhQOL_EasyItemDestroy")
destroyFrame:RegisterEvent("DELETE_ITEM_CONFIRM")
destroyFrame:RegisterEvent("ADDON_LOADED")

destroyFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if IsEnabled() then PatchDeleteDialogs() end
        self:UnregisterEvent("ADDON_LOADED")
        return
    end

    if event == "DELETE_ITEM_CONFIRM" then
        HandleDeleteConfirm()
    end
end)

ns.EasyItemDestroy = destroyFrame
