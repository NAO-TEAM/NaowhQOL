local addonName, ns = ...

-- handles the cdm settings page on the right side
function ns:InitCDMOptions()
    local p = ns.MainFrame.Content
    
    -- wipe the panel so we dont stack frames if we click the button twice
    local children = {p:GetChildren()}
    for _, child in ipairs(children) do child:Hide() end

    -- helper for section titles
    local function AddHeader(text, y)
        local h = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h:SetPoint("TOPLEFT", 15, y)
        h:SetText("|cff00fbff>|r  " .. text:upper())
        return -35
    end

    local y = -20

    -- section 1: how the text looks on the bars
    y = y + AddHeader("Display Text", y)
    
    local eb = CreateFrame("EditBox", nil, p, "BackdropTemplate")
    eb:SetSize(400, 30)
    eb:SetPoint("TOPLEFT", 20, y)
    eb:SetAutoFocus(false)
    eb:SetFontObject("ChatFontNormal")
    eb:SetText("Charge: %p") -- format placeholder
    eb:SetTextInsets(10, 10, 0, 0)
    eb:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]],
        edgeSize = 1,
    })
    eb:SetBackdropColor(0, 0, 0, 0.5)
    eb:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    -- section 2: moving the bars around
    y = y - 80
    y = y + AddHeader("Position Settings", y)

    -- calling our custom widget from the other file
    -- we use the db values so the slider matches the saved config
    local xSlider = ns.Widgets:CreateAdvancedSlider(p, "Horizontal Offset", -500, 500, y)
    xSlider:SetValue(ns.DB.config.posX)
    xSlider:SetScript("OnValueChanged", function(_, val)
        ns.DB.config.posX = val
        -- todo: trigger bar update here
    end)

    y = y - 60
    local ySlider = ns.Widgets:CreateAdvancedSlider(p, "Vertical Offset", -500, 500, y)
    ySlider:SetValue(ns.DB.config.posY)
    ySlider:SetScript("OnValueChanged", function(_, val)
        ns.DB.config.posY = val
        -- todo: trigger bar update here
    end)
end