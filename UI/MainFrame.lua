local addonName, ns = ...

local f = CreateFrame("Frame", "Sentinel_MainFrame", UIParent, "BackdropTemplate")
f:SetSize(950, 650)
f:SetPoint("CENTER")
f:SetFrameStrata("HIGH")
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)
f:Hide()

f:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
})
f:SetBackdropColor(0.01, 0.01, 0.01, 0.98)
f:SetBackdropBorderColor(0, 0, 0, 1)

tinsert(UISpecialFrames, f:GetName())

local logo = f:CreateFontString(nil, "OVERLAY")
logo:SetFont([[Fonts\FRIZQT__.TTF]], 15, "OUTLINE")
logo:SetPoint("TOPLEFT", 25, -20)
logo:SetText("SENTINEL |cff777777v1.0|r")

local topActions = CreateFrame("Frame", nil, f)
topActions:SetHeight(40)
topActions:SetPoint("TOPRIGHT", -55, -12)
topActions:SetWidth(500)

local function QuickButton(text, anchor, x, onClick)
    local b = CreateFrame("Button", nil, topActions, "BackdropTemplate")
    b:SetSize(110, 22)
    b:SetPoint("RIGHT", anchor, x, 0)
    b:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    b:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
    b:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    local txt = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    txt:SetPoint("CENTER")
    txt:SetText(text)

    b:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.12, 0.62, 0.78, 1)
        txt:SetTextColor(0.12, 0.62, 0.78)
    end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
        txt:SetTextColor(1, 1, 1)
    end)
    if onClick then b:SetScript("OnClick", onClick) end

    return b
end

local btnClose = QuickButton("Close View", topActions, 0, function() f:Hide() end)

local btnLock = QuickButton("Toggle Lock", btnClose, -115, function()
    print("|cff00fbffSentinel:|r TODO lock frames not implemented")
end)

local btnSetup = QuickButton("Quick Setup", btnLock, -115, function()
    print("|cff00fbffSentinel:|r TODO Quick Setup wizard not implemented")
end)

local btnLayout = QuickButton("Layout Mode", btnSetup, -115, function()
    ns.LayoutMode = not ns.LayoutMode
    print("|cff00fbffSentinel:|r Layout mode " .. (ns.LayoutMode and "enabled" or "disabled"))
end)

local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -5, -5)
close:SetSize(30, 30)

local content = CreateFrame("Frame", nil, f, "BackdropTemplate")
content:SetPoint("TOPLEFT", 210, -60)
content:SetPoint("BOTTOMRIGHT", -15, 15)
content:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
})
content:SetBackdropColor(0, 0, 0, 0.4)
content:SetBackdropBorderColor(1, 1, 1, 0.03)
f.Content = content

ns.MainFrame = f

SLASH_SENTINEL1 = "/sentinel"
SLASH_SENTINEL2 = "/sen"
SlashCmdList["SENTINEL"] = function()
    if f:IsShown() then f:Hide() else f:Show() end
end
