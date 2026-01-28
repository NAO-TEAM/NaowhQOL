local addonName, ns = ...

-- current build version
ns.Version = "Alpha 0.0.1"

-- side panel anchored to the main frame
local side = CreateFrame("Frame", "Sentinel_Sidebar", ns.MainFrame, "BackdropTemplate")
side:SetWidth(200)
side:SetPoint("TOPLEFT")
side:SetPoint("BOTTOMLEFT")
side:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
side:SetBackdropColor(0.04, 0.04, 0.04, 1)

-- version text up top, keeps things looking official
local ver = side:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ver:SetPoint("TOP", side, "TOP", 0, -20)
ver:SetText("SENTINEL UI |cff777777" .. ns.Version .. "|r")

-- main button for the cooldown manager module
local cdmBtn = CreateFrame("Button", nil, side, "BackdropTemplate")
cdmBtn:SetSize(185, 40)
cdmBtn:SetPoint("TOP", side, "TOP", 0, -60)
cdmBtn:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
cdmBtn:SetBackdropColor(0.12, 0.62, 0.78, 0.2)

-- button label
local cdmTxt = cdmBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
cdmTxt:SetPoint("LEFT", 15, 0)
cdmTxt:SetText("COOLDOWN MANAGER")

-- that little blue bar on the left of the button
local indicator = cdmBtn:CreateTexture(nil, "OVERLAY")
indicator:SetWidth(3)
indicator:SetPoint("TOPLEFT")
indicator:SetPoint("BOTTOMLEFT")
indicator:SetColorTexture(0.12, 0.62, 0.78, 1)

-- simple hover effects so it doesnt feel static
cdmBtn:SetScript("OnEnter", function(self)
    self:SetBackdropColor(0.12, 0.62, 0.78, 0.4)
end)

cdmBtn:SetScript("OnLeave", function(self)
    self:SetBackdropColor(0.12, 0.62, 0.78, 0.2)
end)

-- this makes the button actually do something
cdmBtn:SetScript("OnClick", function()
    if ns.InitCDMOptions then
        ns:InitCDMOptions()
    else
        print("Sentinel Error: CDM module not loaded yet.")
    end
end)