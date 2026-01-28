local addonName, ns = ...

local defaultSettings = {
    enabled = true,
    showIcons = true,
    showText = true,
    barWidth = 150,
    barHeight = 20,
    maxBars = 8,
}

-- creates a settings panel for a cooldown group, returns the settings table
function ns:CreateCooldownSettingsPanel(groupName)
    ns.DB.cooldownGroups = ns.DB.cooldownGroups or {}
    ns.DB.cooldownGroups[groupName] = ns.DB.cooldownGroups[groupName] or CopyTable(defaultSettings)

    local settings = ns.DB.cooldownGroups[groupName]
    local p = ns.MainFrame.Content

    for _, region in ipairs({p:GetRegions()}) do region:Hide() end
    for _, child in ipairs({p:GetChildren()}) do child:Hide() end

    local y = -20

    local function Header(text)
        local h = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h:SetPoint("TOPLEFT", 15, y)
        h:SetText(text:upper())
        h:SetTextColor(0.12, 0.62, 0.78)
        y = y - 35
    end

    local function Checkbox(label, key)
        local cb = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 20, y)
        cb:SetChecked(settings[key])
        cb:SetScript("OnClick", function(self) settings[key] = self:GetChecked() end)

        local txt = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("LEFT", cb, "RIGHT", 5, 0)
        txt:SetText(label)
        y = y - 30
    end

    -- title showing which group we're editing
    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 15, y)
    title:SetText(groupName)
    y = y - 40

    Header("General")
    Checkbox("Enable Cooldown Bars", "enabled")
    Checkbox("Show Spell Icons", "showIcons")
    Checkbox("Show Timer Text", "showText")

    y = y - 15
    Header("Bar Size")

    local widthSlider = ns.Widgets:CreateAdvancedSlider(p, "Bar Width", 50, 300, y)
    widthSlider:SetValue(settings.barWidth)
    widthSlider:SetScript("OnValueChanged", function(_, val) settings.barWidth = val end)

    y = y - 60
    local heightSlider = ns.Widgets:CreateAdvancedSlider(p, "Bar Height", 10, 50, y)
    heightSlider:SetValue(settings.barHeight)
    heightSlider:SetScript("OnValueChanged", function(_, val) settings.barHeight = val end)

    y = y - 75
    Header("Display")

    local maxSlider = ns.Widgets:CreateAdvancedSlider(p, "Max Bars Shown", 1, 20, y)
    maxSlider:SetValue(settings.maxBars)
    maxSlider:SetScript("OnValueChanged", function(_, val) settings.maxBars = val end)

    return settings
end

-- shows all cooldown groups in one panel
function ns:InitCooldownSettings()
    ns.DB.cooldownGroups = ns.DB.cooldownGroups or {}

    local groups = { "Essential CDs", "Utility CDs" }
    for _, name in ipairs(groups) do
        ns.DB.cooldownGroups[name] = ns.DB.cooldownGroups[name] or CopyTable(defaultSettings)
    end

    local p = ns.MainFrame.Content

    for _, region in ipairs({p:GetRegions()}) do region:Hide() end
    for _, child in ipairs({p:GetChildren()}) do child:Hide() end

    local y = -20

    local function GroupSection(groupName)
        local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 15, y)
        title:SetText(groupName)
        y = y - 30

        local btn = CreateFrame("Button", nil, p, "BackdropTemplate")
        btn:SetSize(120, 22)
        btn:SetPoint("TOPLEFT", 20, y)
        btn:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]], edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
        btn:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
        btn:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

        local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("CENTER")
        txt:SetText("Configure")

        btn:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(0.12, 0.62, 0.78, 1)
            txt:SetTextColor(0.12, 0.62, 0.78)
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
            txt:SetTextColor(1, 1, 1)
        end)
        btn:SetScript("OnClick", function()
            ns:CreateCooldownSettingsPanel(groupName)
        end)

        y = y - 50
    end

    for _, name in ipairs(groups) do
        GroupSection(name)
    end
end
