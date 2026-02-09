local addonName, ns = ...

local COLORS = {
    BLUE    = "018ee7",
    ORANGE  = "ffa900",
}

-- Equipment slots to display
local EQUIPMENT_SLOTS = {
    { id = 13, name = "Trinket 1" },
    { id = 14, name = "Trinket 2" },
    { id = 16, name = "Main Hand" },
    { id = 17, name = "Off Hand" },
}

local equipmentFrame = nil
local itemButtons = {}
local autoHideTimer = nil

local function GetDB()
    return NaowhQOL.equipmentReminder
end

local function UpdateSlot(button, slotID)
    local texture = GetInventoryItemTexture("player", slotID)
    local quality = GetInventoryItemQuality("player", slotID)

    if texture then
        button.icon:SetTexture(texture)
        button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.icon:Show()

        if quality and quality >= 0 then
            local r, g, b = C_Item.GetItemQualityColor(quality)
            button.border:SetVertexColor(r, g, b, 1)
            button.border:Show()
        else
            button.border:Hide()
        end
    else
        button.icon:SetTexture(nil)
        button.icon:Hide()
        button.border:Hide()
    end
end

local function UpdateAllSlots()
    for _, button in ipairs(itemButtons) do
        UpdateSlot(button, button.slotID)
    end
end

local function CreateItemButton(parent, slotID, slotName)
    local db = GetDB()
    local size = db.iconSize or 40

    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size, size)
    button.slotID = slotID
    button.slotName = slotName

    -- Icon texture
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    button.icon = icon

    -- Quality border
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetPoint("TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", 2, -2)
    border:SetTexture([[Interface\Buttons\UI-ActionButton-Border]])
    border:SetBlendMode("ADD")
    button.border = border

    -- Tooltip handling
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        if GetInventoryItemID("player", self.slotID) then
            GameTooltip:SetInventoryItem("player", self.slotID)
        else
            GameTooltip:SetText(self.slotName .. " - Empty")
        end
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return button
end

local function CreateEquipmentFrame()
    if equipmentFrame then return equipmentFrame end

    local db = GetDB()

    local frame = CreateFrame("Frame", "NaowhQOL_EquipmentReminder", UIParent, "BackdropTemplate")
    frame:SetSize(220, 90)
    frame:SetPoint(db.point or "CENTER", UIParent, db.point or "CENTER", db.x or 0, db.y or 100)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]],
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.08, 0.08, 0.12, 0.95)
    frame:SetBackdropBorderColor(0.01, 0.56, 0.91, 0.8)

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", frame, "TOP", 0, -8)
    title:SetText("|cff" .. COLORS.BLUE .. "Equipment|r |cff" .. COLORS.ORANGE .. "Check|r")
    frame.title = title

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame)
    closeBtn:SetSize(16, 16)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    closeBtn:SetNormalTexture([[Interface\Buttons\UI-StopButton]])
    closeBtn:SetHighlightTexture([[Interface\Buttons\UI-StopButton]])
    closeBtn:GetHighlightTexture():SetVertexColor(1, 0.66, 0, 1)
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
        if autoHideTimer then
            autoHideTimer:Cancel()
            autoHideTimer = nil
        end
    end)

    -- Item buttons container
    local buttonContainer = CreateFrame("Frame", nil, frame)
    buttonContainer:SetPoint("TOP", title, "BOTTOM", 0, -8)
    buttonContainer:SetSize(200, 50)

    local iconSize = db.iconSize or 40
    local spacing = 6
    local totalWidth = (#EQUIPMENT_SLOTS * iconSize) + ((#EQUIPMENT_SLOTS - 1) * spacing)
    local startX = -totalWidth / 2 + iconSize / 2

    for i, slot in ipairs(EQUIPMENT_SLOTS) do
        local button = CreateItemButton(buttonContainer, slot.id, slot.name)
        button:SetPoint("CENTER", buttonContainer, "CENTER", startX + (i - 1) * (iconSize + spacing), 0)
        itemButtons[i] = button
    end

    -- Dragging
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        db.point = point
        db.x = x
        db.y = y
    end)

    frame:Hide()
    equipmentFrame = frame
    return frame
end

local function ShowFrame()
    local db = GetDB()
    if not db or not db.enabled then return end
    if InCombatLockdown() then return end

    local frame = CreateEquipmentFrame()
    UpdateAllSlots()
    frame:Show()

    -- Cancel existing timer
    if autoHideTimer then
        autoHideTimer:Cancel()
        autoHideTimer = nil
    end

    -- Start auto-hide timer if configured
    local delay = db.autoHideDelay or 10
    if delay > 0 then
        autoHideTimer = C_Timer.NewTimer(delay, function()
            if frame and frame:IsShown() then
                frame:Hide()
            end
            autoHideTimer = nil
        end)
    end
end

local function HideFrame()
    if equipmentFrame then
        equipmentFrame:Hide()
    end
    if autoHideTimer then
        autoHideTimer:Cancel()
        autoHideTimer = nil
    end
end

local function OnInstanceEnter()
    local db = GetDB()
    if not db or not db.enabled or not db.showOnInstance then return end

    local inInstance, instanceType = IsInInstance()
    if inInstance and (instanceType == "party" or instanceType == "raid" or instanceType == "scenario") then
        C_Timer.After(1, function()
            if not InCombatLockdown() then
                ShowFrame()
            end
        end)
    end
end

local function OnReadyCheck()
    local db = GetDB()
    if not db or not db.enabled or not db.showOnReadyCheck then return end

    C_Timer.After(0.2, function()
        if not InCombatLockdown() then
            ShowFrame()
        end
    end)
end

-- Event handling
local loader = CreateFrame("Frame", "NaowhQOL_EquipmentReminderLoader")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:RegisterEvent("READY_CHECK")
loader:RegisterEvent("UNIT_INVENTORY_CHANGED")

loader:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        if not NaowhQOL.equipmentReminder then
            NaowhQOL.equipmentReminder = {
                enabled = true,
                showOnInstance = true,
                showOnReadyCheck = true,
                autoHideDelay = 10,
                iconSize = 40,
                point = "CENTER",
                x = 0,
                y = 100,
            }
        end
        local db = NaowhQOL.equipmentReminder
        if db.enabled == nil then db.enabled = true end
        if db.showOnInstance == nil then db.showOnInstance = true end
        if db.showOnReadyCheck == nil then db.showOnReadyCheck = true end
        if db.autoHideDelay == nil then db.autoHideDelay = 10 end
        if db.iconSize == nil then db.iconSize = 40 end

    elseif event == "PLAYER_ENTERING_WORLD" then
        OnInstanceEnter()

    elseif event == "READY_CHECK" then
        OnReadyCheck()

    elseif event == "UNIT_INVENTORY_CHANGED" then
        local unit = ...
        if unit == "player" and equipmentFrame and equipmentFrame:IsShown() then
            UpdateAllSlots()
        end
    end
end)

ns.EquipmentReminder = loader
ns.EquipmentReminder.ShowFrame = ShowFrame
ns.EquipmentReminder.HideFrame = HideFrame
