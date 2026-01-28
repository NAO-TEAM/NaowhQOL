local addonName, ns = ...

function ns:InitCDMOptions()
    local p = ns.MainFrame.Content

    for _, region in ipairs({p:GetRegions()}) do region:Hide() end
    for _, child in ipairs({p:GetChildren()}) do child:Hide() end

    local y = -20

    local function Header(text)
        local h = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h:SetPoint("TOPLEFT", 15, y)
        h:SetText("|cff00fbff>|r  " .. text:upper())
        y = y - 35
    end

    Header("Display Text")

    local eb = CreateFrame("EditBox", nil, p, "BackdropTemplate")
    eb:SetSize(400, 30)
    eb:SetPoint("TOPLEFT", 20, y)
    eb:SetAutoFocus(false)
    eb:SetFontObject("ChatFontNormal")
    eb:SetText("Charge: %p")
    eb:SetTextInsets(10, 10, 0, 0)
    eb:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]], edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
    eb:SetBackdropColor(0, 0, 0, 0.5)
    eb:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    y = y - 80
    Header("Position Settings")

    local xSlider = ns.Widgets:CreateAdvancedSlider(p, "Horizontal Offset", -500, 500, y)
    xSlider:SetValue(ns.DB.config.posX)
    xSlider:SetScript("OnValueChanged", function(_, val) ns.DB.config.posX = val end)

    y = y - 60
    local ySlider = ns.Widgets:CreateAdvancedSlider(p, "Vertical Offset", -500, 500, y)
    ySlider:SetValue(ns.DB.config.posY)
    ySlider:SetScript("OnValueChanged", function(_, val) ns.DB.config.posY = val end)
end
