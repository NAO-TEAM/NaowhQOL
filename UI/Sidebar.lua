local addonName, ns = ...
ns.Version = "Alpha 0.0.1"

local side = CreateFrame("Frame", "Sentinel_Sidebar", ns.MainFrame, "BackdropTemplate")
side:SetWidth(200)
side:SetPoint("TOPLEFT")
side:SetPoint("BOTTOMLEFT")
side:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
side:SetBackdropColor(0.04, 0.04, 0.04, 1)

local ver = side:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ver:SetPoint("TOP", 0, -20)
ver:SetText("SENTINEL UI |cff777777" .. ns.Version .. "|r")

local function SidebarButton(label, yOffset, onClick, indent)
    local btn = CreateFrame("Button", nil, side, "BackdropTemplate")
    btn:SetSize(indent and 170 or 185, indent and 30 or 40)
    btn:SetPoint("TOP", indent and 15 or 0, yOffset)
    btn:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
    btn:SetBackdropColor(0.12, 0.62, 0.78, indent and 0.1 or 0.2)

    local txt = btn:CreateFontString(nil, "OVERLAY", indent and "GameFontHighlightSmall" or "GameFontHighlight")
    txt:SetPoint("LEFT", 15, 0)
    txt:SetText(label)

    local ind = btn:CreateTexture(nil, "OVERLAY")
    ind:SetWidth(3)
    ind:SetPoint("TOPLEFT")
    ind:SetPoint("BOTTOMLEFT")
    ind:SetColorTexture(0.12, 0.62, 0.78, indent and 0.5 or 1)

    btn:SetScript("OnEnter", function(self) self:SetBackdropColor(0.12, 0.62, 0.78, 0.4) end)
    btn:SetScript("OnLeave", function(self) self:SetBackdropColor(0.12, 0.62, 0.78, indent and 0.1 or 0.2) end)
    btn:SetScript("OnClick", onClick)

    return btn
end

SidebarButton("COOLDOWN MANAGER", -60, function()
    if ns.InitCDMOptions then ns:InitCDMOptions() end
end)

SidebarButton("COOLDOWN SETTINGS", -105, function()
    if ns.InitCooldownSettings then ns:InitCooldownSettings() end
end)
