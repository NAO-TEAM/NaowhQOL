local addonName, ns = ...


local NaowhOrange = { r = 255/255, g = 169/255, b = 0/255 } 
local NaowhDarkBlue = { r = 0.00, g = 0.49, b = 0.79 }

local MainWindow = CreateFrame("Frame", "NaowhQOL_MainFrame", UIParent, "BackdropTemplate")
MainWindow:SetSize(950, 650)
MainWindow:SetPoint("CENTER")
MainWindow:SetFrameStrata("HIGH")
MainWindow:SetMovable(true)
MainWindow:EnableMouse(true)
MainWindow:RegisterForDrag("LeftButton")
MainWindow:SetScript("OnDragStart", MainWindow.StartMoving)
MainWindow:SetScript("OnDragStop", MainWindow.StopMovingOrSizing)
MainWindow:Hide()


MainWindow:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 }
})
MainWindow:SetBackdropColor(0.02, 0.02, 0.02, 0.95)
MainWindow:SetBackdropBorderColor(NaowhDarkBlue.r, NaowhDarkBlue.g, NaowhDarkBlue.b, 0.7)


tinsert(UISpecialFrames, MainWindow:GetName())


local TopAccent = MainWindow:CreateTexture(nil, "OVERLAY")
TopAccent:SetHeight(3)
TopAccent:SetPoint("TOPLEFT", 1, -1)
TopAccent:SetPoint("TOPRIGHT", -1, -1)
TopAccent:SetColorTexture(NaowhOrange.r, NaowhOrange.g, NaowhOrange.b, 1)


local BottomAccent = MainWindow:CreateTexture(nil, "OVERLAY")
BottomAccent:SetHeight(2)
BottomAccent:SetPoint("BOTTOMLEFT", 1, 1)
BottomAccent:SetPoint("BOTTOMRIGHT", -1, 1)
BottomAccent:SetColorTexture(NaowhDarkBlue.r, NaowhDarkBlue.g, NaowhDarkBlue.b, 0.7)

local CloseButton = CreateFrame("Button", nil, MainWindow, "UIPanelCloseButton")
CloseButton:SetPoint("TOPRIGHT", -3, -3)
CloseButton:SetSize(32, 32)


local ContentArea = CreateFrame("Frame", nil, MainWindow, "BackdropTemplate")
ContentArea:SetPoint("TOPLEFT", 202, -5)
ContentArea:SetPoint("BOTTOMRIGHT", -2, 2)
ContentArea:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
})
ContentArea:SetBackdropColor(0, 0, 0, 0.3)
ContentArea:SetBackdropBorderColor(NaowhDarkBlue.r, NaowhDarkBlue.g, NaowhDarkBlue.b, 0.35)
ContentArea:SetClipsChildren(false)

MainWindow.Content = ContentArea


function MainWindow:ResetContent()
    if ContentArea then
        local children = {ContentArea:GetChildren()}
        for _, child in ipairs(children) do
            if child then
                child:Hide()
            end
        end
        
        local regions = {ContentArea:GetRegions()}
        for _, region in ipairs(regions) do
            if region and region.Hide then
                region:Hide()
            end
        end
    end
end

ns.MainFrame = MainWindow


SLASH_NAOWHQOL1 = "/nao"
SLASH_NAOWHQOL2 = "/nqol"

SlashCmdList["NAOWHQOL"] = function()
    if MainWindow:IsShown() then
        MainWindow:Hide()
    else
        MainWindow:Show()
        if MainWindow.ResetContent then
            MainWindow:ResetContent()
        end
        if ns.InitHomePage then
            ns:InitHomePage()
        end

        if ns.ResetSidebarToHome then
            ns:ResetSidebarToHome()
        end
    end
end

-- Addon Compartment click handler
function NaowhQOL_OnAddonCompartmentClick(addonName, buttonName)
    SlashCmdList["NAOWHQOL"]()
end


local WelcomeFrame = CreateFrame("Frame")
WelcomeFrame:RegisterEvent("PLAYER_LOGIN")
WelcomeFrame:SetScript("OnEvent", function()
    ns:Log("Loaded. Type |cff00ff00/nao|r to open settings.")
end)

-- Home/Welcome page shown on addon open
function ns:InitHomePage()
    local p = ns.MainFrame.Content
    local L = ns.L

    -- Container for masked icon
    local iconFrame = CreateFrame("Frame", nil, p)
    iconFrame:SetSize(200, 200)
    iconFrame:SetPoint("CENTER", 0, 40)

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\AddOns\\NaowhQOL\\Assets\\welcomeicon.tga")
    icon:SetAlpha(0.4)

    -- Apply circular mask to hide square edges
    local mask = iconFrame:CreateMaskTexture()
    mask:SetAllPoints()
    mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    icon:AddMaskTexture(mask)

    local subtitle = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    subtitle:SetPoint("TOP", iconFrame, "BOTTOM", 0, -15)
    subtitle:SetText(L["HOME_SUBTITLE"])
    subtitle:SetTextColor(0.6, 0.6, 0.6, 1)
end