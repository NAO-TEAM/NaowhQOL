local addonName, ns = ...
local L = ns.L

local COLORS = {
    NAOWH_ORANGE = { r = 1.00, g = 0.66, b = 0.00 },  
    NAOWH_BLUE = { r = 0.01, g = 0.56, b = 0.91 },    
    DARK_BLUE = { r = 0.00, g = 0.49, b = 0.79 },    
    BG_DARK = { r = 0.02, g = 0.02, b = 0.02 },      
    WHITE = { r = 1.00, g = 1.00, b = 1.00 },
    GRAY = { r = 0.67, g = 0.67, b = 0.67 }
}

local SidebarContainer = CreateFrame("Frame", "NaowhQOL_Sidebar", ns.MainFrame, "BackdropTemplate")
SidebarContainer:SetWidth(200)
SidebarContainer:SetPoint("TOPLEFT", ns.MainFrame, "TOPLEFT", 1, -1)
SidebarContainer:SetPoint("BOTTOMLEFT", ns.MainFrame, "BOTTOMLEFT", 1, 1)
SidebarContainer:SetBackdrop({
    bgFile = [[Interface\Buttons\WHITE8x8]]
})
SidebarContainer:SetBackdropColor(COLORS.BG_DARK.r, COLORS.BG_DARK.g, COLORS.BG_DARK.b, 1)

local SidebarDivider = SidebarContainer:CreateTexture(nil, "OVERLAY")
SidebarDivider:SetWidth(1)
SidebarDivider:SetPoint("TOPRIGHT", SidebarContainer, "TOPRIGHT", 0, -70)
SidebarDivider:SetPoint("BOTTOMRIGHT", SidebarContainer, "BOTTOMRIGHT", 0, 0)
SidebarDivider:SetColorTexture(COLORS.DARK_BLUE.r, COLORS.DARK_BLUE.g, COLORS.DARK_BLUE.b, 0.4)

local HeaderContainer = CreateFrame("Frame", nil, SidebarContainer, "BackdropTemplate")
HeaderContainer:SetSize(200, 70)
HeaderContainer:SetPoint("TOP", SidebarContainer, "TOP", 0, 0)
HeaderContainer:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
HeaderContainer:SetBackdropColor(0.01, 0.01, 0.01, 0.9)

local HeaderAccent = HeaderContainer:CreateTexture(nil, "OVERLAY")
HeaderAccent:SetHeight(3)
HeaderAccent:SetPoint("TOPLEFT", HeaderContainer, "TOPLEFT", 0, 0)
HeaderAccent:SetPoint("TOPRIGHT", HeaderContainer, "TOPRIGHT", 0, 0)
HeaderAccent:SetColorTexture(COLORS.NAOWH_ORANGE.r, COLORS.NAOWH_ORANGE.g, COLORS.NAOWH_ORANGE.b, 1)

local AddonTitle = HeaderContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
AddonTitle:SetPoint("TOP", HeaderContainer, "TOP", 0, -20)
AddonTitle:SetText("|cff018ee7NAOWH|r |cffffa900QOL|r")

local VersionText = HeaderContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
VersionText:SetPoint("TOP", AddonTitle, "BOTTOM", 0, -5)

local stage = _G.NaowhQOL_VersionStage or "ALPHA"
local number = _G.NaowhQOL_VersionNumber or "0.0.1"
VersionText:SetText(string.format("|cffffa900%s|r |cffaaaaaa%s|r", stage, number))

local HeaderSeparator = HeaderContainer:CreateTexture(nil, "OVERLAY")
HeaderSeparator:SetHeight(2)
HeaderSeparator:SetPoint("BOTTOMLEFT", HeaderContainer, "BOTTOMLEFT", 0, 0)
HeaderSeparator:SetPoint("BOTTOMRIGHT", HeaderContainer, "BOTTOMRIGHT", 0, 0)
HeaderSeparator:SetColorTexture(COLORS.NAOWH_BLUE.r, COLORS.NAOWH_BLUE.g, COLORS.NAOWH_BLUE.b, 0.5)

-- scrollable region below header for the nav buttons
local menuScroll = CreateFrame("ScrollFrame", nil, SidebarContainer)
menuScroll:SetPoint("TOPLEFT", HeaderContainer, "BOTTOMLEFT", 0, 0)
menuScroll:SetPoint("BOTTOMRIGHT", SidebarContainer, "BOTTOMRIGHT", 0, 0)

local scrollContent = CreateFrame("Frame", nil, menuScroll)
scrollContent:SetWidth(200)
scrollContent:SetHeight(1) -- gets updated after buttons are built
menuScroll:SetScrollChild(scrollContent)

menuScroll:EnableMouseWheel(true)
menuScroll:SetScript("OnMouseWheel", function(self, delta)
    local pos = self:GetVerticalScroll()
    local max = scrollContent:GetHeight() - self:GetHeight()
    if max < 0 then max = 0 end
    local newPos = math.max(0, math.min(pos - (delta * 47), max))
    self:SetVerticalScroll(newPos)
end)

local ActiveTabIndicator = scrollContent:CreateTexture(nil, "OVERLAY")
ActiveTabIndicator:SetWidth(4)
ActiveTabIndicator:SetColorTexture(COLORS.NAOWH_ORANGE.r, COLORS.NAOWH_ORANGE.g, COLORS.NAOWH_ORANGE.b, 1)
ActiveTabIndicator:Hide()

local selectedButton = nil
local tabRegistry = {}  -- Maps tab keys to {button, groupName, initFunc}

local function SwitchTab(button, initFunction, tabKey)
    if not ns.MainFrame or not ns.MainFrame.Content then return end

    if ns.MainFrame.ResetContent then
        ns.MainFrame:ResetContent()
    end

    local ContentArea = ns.MainFrame.Content
    ContentArea:Show()
    ContentArea:SetAlpha(1)

    selectedButton = button
    ActiveTabIndicator:ClearAllPoints()
    ActiveTabIndicator:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    ActiveTabIndicator:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)

    -- Only show if button is visible
    if button:IsShown() then
        ActiveTabIndicator:Show()
    else
        ActiveTabIndicator:Hide()
    end

    if initFunction then
        initFunction()
    end

    -- Save last tab for session restore
    if tabKey and NaowhQOL and NaowhQOL.config then
        NaowhQOL.config.lastTab = tabKey
    end
end

-- Collapse state storage
local groupStates = {}

-- Track all groups and items for layout
local allGroups = {}
local firstChildBtn = nil

local function RecalculateLayout()
    local yOffset = 0
    for _, group in ipairs(allGroups) do
        group.header:ClearAllPoints()
        group.header:SetPoint("TOP", scrollContent, "TOP", 0, yOffset)
        yOffset = yOffset - 38

        if groupStates[group.name] then
            for _, child in ipairs(group.children) do
                child:ClearAllPoints()
                child:SetPoint("TOP", scrollContent, "TOP", 0, yOffset)
                child:Show()
                yOffset = yOffset - 36
            end
        else
            for _, child in ipairs(group.children) do
                child:Hide()
            end
        end
    end
    scrollContent:SetHeight(math.abs(yOffset) + 20)

    -- Update indicator visibility based on selected button
    if selectedButton then
        if selectedButton:IsShown() then
            ActiveTabIndicator:Show()
        else
            ActiveTabIndicator:Hide()
        end
    end
end

local function CreateGroupHeader(label, groupName)
    local btn = CreateFrame("Button", nil, scrollContent, "BackdropTemplate")
    btn:SetSize(196, 34)
    btn:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]],
        edgeSize = 1
    })
    btn:SetBackdropColor(COLORS.NAOWH_BLUE.r, COLORS.NAOWH_BLUE.g, COLORS.NAOWH_BLUE.b, 0.25)
    btn:SetBackdropBorderColor(COLORS.NAOWH_BLUE.r, COLORS.NAOWH_BLUE.g, COLORS.NAOWH_BLUE.b, 0.5)

    local iconTxt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    iconTxt:SetPoint("LEFT", btn, "LEFT", 10, 0)
    iconTxt:SetText("+")
    iconTxt:SetTextColor(COLORS.NAOWH_ORANGE.r, COLORS.NAOWH_ORANGE.g, COLORS.NAOWH_ORANGE.b, 1)
    btn.iconTxt = iconTxt

    local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    txt:SetPoint("LEFT", iconTxt, "RIGHT", 6, 0)
    txt:SetText(label)
    txt:SetTextColor(COLORS.NAOWH_ORANGE.r, COLORS.NAOWH_ORANGE.g, COLORS.NAOWH_ORANGE.b, 1)

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(COLORS.NAOWH_ORANGE.r, COLORS.NAOWH_ORANGE.g, COLORS.NAOWH_ORANGE.b, 0.3)
        self:SetBackdropBorderColor(COLORS.NAOWH_ORANGE.r, COLORS.NAOWH_ORANGE.g, COLORS.NAOWH_ORANGE.b, 0.8)
    end)

    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(COLORS.NAOWH_BLUE.r, COLORS.NAOWH_BLUE.g, COLORS.NAOWH_BLUE.b, 0.25)
        self:SetBackdropBorderColor(COLORS.NAOWH_BLUE.r, COLORS.NAOWH_BLUE.g, COLORS.NAOWH_BLUE.b, 0.5)
    end)

    btn:SetScript("OnClick", function(self)
        groupStates[groupName] = not groupStates[groupName]
        self.iconTxt:SetText(groupStates[groupName] and "-" or "+")
        RecalculateLayout()
    end)

    btn.groupName = groupName
    return btn
end

local function CreateChildButton(label, onClickFunc, tabKey)
    local btn = CreateFrame("Button", nil, scrollContent, "BackdropTemplate")
    btn:SetSize(186, 32)
    btn:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]],
        edgeSize = 1
    })
    btn:SetBackdropColor(COLORS.DARK_BLUE.r, COLORS.DARK_BLUE.g, COLORS.DARK_BLUE.b, 0.15)
    btn:SetBackdropBorderColor(COLORS.DARK_BLUE.r, COLORS.DARK_BLUE.g, COLORS.DARK_BLUE.b, 0.25)

    local iconTxt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    iconTxt:SetPoint("LEFT", btn, "LEFT", 18, 0)
    iconTxt:SetText("»")
    iconTxt:SetTextColor(COLORS.NAOWH_ORANGE.r, COLORS.NAOWH_ORANGE.g, COLORS.NAOWH_ORANGE.b, 1)

    local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    txt:SetPoint("LEFT", iconTxt, "RIGHT", 6, 0)
    txt:SetText(label)
    txt:SetTextColor(COLORS.WHITE.r, COLORS.WHITE.g, COLORS.WHITE.b, 0.9)

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(COLORS.NAOWH_ORANGE.r, COLORS.NAOWH_ORANGE.g, COLORS.NAOWH_ORANGE.b, 0.3)
        self:SetBackdropBorderColor(COLORS.NAOWH_ORANGE.r, COLORS.NAOWH_ORANGE.g, COLORS.NAOWH_ORANGE.b, 0.8)
        txt:SetTextColor(COLORS.NAOWH_ORANGE.r, COLORS.NAOWH_ORANGE.g, COLORS.NAOWH_ORANGE.b, 1)
        iconTxt:SetTextColor(COLORS.WHITE.r, COLORS.WHITE.g, COLORS.WHITE.b, 1)
    end)

    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(COLORS.DARK_BLUE.r, COLORS.DARK_BLUE.g, COLORS.DARK_BLUE.b, 0.15)
        self:SetBackdropBorderColor(COLORS.DARK_BLUE.r, COLORS.DARK_BLUE.g, COLORS.DARK_BLUE.b, 0.25)
        txt:SetTextColor(COLORS.WHITE.r, COLORS.WHITE.g, COLORS.WHITE.b, 0.9)
        iconTxt:SetTextColor(COLORS.NAOWH_ORANGE.r, COLORS.NAOWH_ORANGE.g, COLORS.NAOWH_ORANGE.b, 1)
    end)

    btn:SetScript("OnClick", function(self)
        SwitchTab(self, onClickFunc, tabKey)
    end)

    btn.tabKey = tabKey
    return btn
end

local function CreateGroup(name, label, childDefs)
    local header = CreateGroupHeader(label, name)
    local children = {}
    for _, def in ipairs(childDefs) do
        local child = CreateChildButton(def.label, def.onClick, def.key)
        children[#children + 1] = child
        if not firstChildBtn then firstChildBtn = child end
        -- Register tab for restore functionality
        if def.key then
            tabRegistry[def.key] = { button = child, groupName = name, initFunc = def.onClick }
        end
    end
    groupStates[name] = false -- default collapsed
    allGroups[#allGroups + 1] = { name = name, header = header, children = children }
    return header, children
end

-- COMBAT group
CreateGroup("combat", L["SIDEBAR_GROUP_COMBAT"], {
    { key = "combat_timer", label = L["SIDEBAR_TAB_COMBAT_TIMER"], onClick = function() if ns.InitCombatTimer then ns:InitCombatTimer() end end },
    { key = "combat_alert", label = L["SIDEBAR_TAB_COMBAT_ALERT"], onClick = function() if ns.InitCombatAlerts then ns:InitCombatAlerts() end end },
    { key = "combat_logger", label = L["SIDEBAR_TAB_COMBAT_LOGGER"], onClick = function() if ns.InitCombatLogger then ns:InitCombatLogger() end end },
    { key = "gcd_tracker", label = L["SIDEBAR_TAB_GCD_TRACKER"], onClick = function() if ns.InitGcdTracker then ns:InitGcdTracker() end end },
})

-- HUD group
CreateGroup("hud", L["SIDEBAR_GROUP_HUD"], {
    { key = "mouse_ring", label = L["SIDEBAR_TAB_MOUSE_RING"], onClick = function() if ns.InitMouseOptions then ns:InitMouseOptions() end end },
    { key = "crosshair", label = L["SIDEBAR_TAB_CROSSHAIR"], onClick = function() if ns.InitCrosshair then ns:InitCrosshair() end end },
    { key = "focus_castbar", label = L["SIDEBAR_TAB_FOCUS_CASTBAR"], onClick = function() if ns.InitFocusCastBar then ns:InitFocusCastBar() end end },
    { key = "dragonriding", label = L["SIDEBAR_TAB_DRAGONRIDING"], onClick = function() if ns.InitDragonriding then ns:InitDragonriding() end end },
    { key = "movement_alert", label = L["SIDEBAR_TAB_MOVEMENT_ALERT"], onClick = function() if ns.InitMovementAlert then ns:InitMovementAlert() end end },
})

-- TRACKING group
CreateGroup("tracking", L["SIDEBAR_GROUP_TRACKING"], {
    { key = "buff_monitor", label = L["SIDEBAR_TAB_BUFF_MONITOR"], onClick = function() if ns.InitBuffMonitor then ns:InitBuffMonitor() end end },
    { key = "consumables", label = L["SIDEBAR_TAB_CONSUMABLES"], onClick = function() if ns.InitConsumableChecker then ns:InitConsumableChecker() end end },
    { key = "stealth", label = L["SIDEBAR_TAB_STEALTH"], onClick = function() if ns.InitStealthReminder then ns:InitStealthReminder() end end },
    { key = "range_check", label = L["SIDEBAR_TAB_RANGE_CHECK"], onClick = function() if ns.InitRangeCheck then ns:InitRangeCheck() end end },
    { key = "pet_tracker", label = L["SIDEBAR_TAB_PET_TRACKER"], onClick = function() if ns.InitPetTracker then ns:InitPetTracker() end end },
})

-- REMINDERS/MISC group
CreateGroup("reminders", L["SIDEBAR_GROUP_REMINDERS"], {
    { key = "talent_reminder", label = L["SIDEBAR_TAB_TALENT_REMINDER"], onClick = function() if ns.InitTalentReminder then ns:InitTalentReminder() end end },
    { key = "emote_detection", label = L["SIDEBAR_TAB_EMOTE_DETECTION"], onClick = function() if ns.InitEmoteDetection then ns:InitEmoteDetection() end end },
    { key = "equipment_reminder", label = L["SIDEBAR_TAB_EQUIPMENT_REMINDER"], onClick = function() if ns.InitEquipmentReminder then ns:InitEquipmentReminder() end end },
    { key = "crez", label = L["SIDEBAR_TAB_CREZ"], onClick = function() if ns.InitCRez then ns:InitCRez() end end },
    { key = "misc", label = L["SIDEBAR_TAB_MISC"], onClick = function() if ns.InitModuleOptions then ns:InitModuleOptions() end end },
})

-- SYSTEM group
CreateGroup("system", L["SIDEBAR_GROUP_SYSTEM"], {
    { key = "optimizations", label = L["SIDEBAR_TAB_OPTIMIZATIONS"], onClick = function() if ns.InitOptOptions then ns:InitOptOptions() end end },
    { key = "profiles", label = L["SIDEBAR_TAB_PROFILES"], onClick = function() if ns.InitImportExport then ns:InitImportExport() end end },
    { key = "slash_commands", label = L["SIDEBAR_TAB_SLASH_COMMANDS"], onClick = function() if ns.InitSlashCommands then ns:InitSlashCommands() end end },
})

function ns:ResetSidebarToOptimizations()
    -- Find Optimizations button (first child of SYSTEM group)
    local systemGroup = allGroups[5]
    if systemGroup and systemGroup.children[1] and ActiveTabIndicator then
        ActiveTabIndicator:ClearAllPoints()
        ActiveTabIndicator:SetPoint("TOPLEFT", systemGroup.children[1], "TOPLEFT", 0, 0)
        ActiveTabIndicator:SetPoint("BOTTOMLEFT", systemGroup.children[1], "BOTTOMLEFT", 0, 0)
        ActiveTabIndicator:Show()
    end
end

function ns:ResetSidebarToHome()
    -- Hide tab indicator (no sidebar item selected for home page)
    if ActiveTabIndicator then
        ActiveTabIndicator:Hide()
    end
    selectedButton = nil
end

function ns:OpenTab(tabKey)
    local tabInfo = tabRegistry[tabKey]
    if not tabInfo then
        -- Fallback to optimizations
        if ns.InitOptOptions then ns:InitOptOptions() end
        ns:ResetSidebarToOptimizations()
        return
    end

    -- Expand the parent group
    for _, group in ipairs(allGroups) do
        if group.name == tabInfo.groupName then
            groupStates[group.name] = true
            group.header.iconTxt:SetText("-")
        else
            groupStates[group.name] = false
            group.header.iconTxt:SetText("+")
        end
    end
    RecalculateLayout()

    -- Switch to the tab
    SwitchTab(tabInfo.button, tabInfo.initFunc, tabKey)
end

-- Reset all groups to collapsed and expand only the one with selected item
local function ResetSidebarGroups()
    -- Collapse all groups
    for _, group in ipairs(allGroups) do
        groupStates[group.name] = false
        group.header.iconTxt:SetText("+")
    end

    -- Expand the group containing the selected button
    if selectedButton then
        for _, group in ipairs(allGroups) do
            for _, child in ipairs(group.children) do
                if child == selectedButton then
                    groupStates[group.name] = true
                    group.header.iconTxt:SetText("-")
                    break
                end
            end
        end
    end

    RecalculateLayout()
end

-- Hook into MainFrame OnShow to reset sidebar
SidebarContainer:SetScript("OnShow", function()
    ResetSidebarGroups()
end)

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    RecalculateLayout()

    C_Timer.After(0.1, function()
        -- Show home page by default (no sidebar item selected)
        if ns.MainFrame and ns.MainFrame.Content and ns.InitHomePage then
            ns.MainFrame:ResetContent()
            ns:InitHomePage()
        end
        ActiveTabIndicator:Hide()
    end)
end)