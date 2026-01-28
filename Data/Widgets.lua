local addonName, ns = ...
ns.Widgets = {}

function ns.Widgets:CreateAdvancedSlider(parent, label, min, max, yOffset)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(600, 50)
    f:SetPoint("TOPLEFT", 20, yOffset)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText(label:upper())
    title:SetTextColor(0.12, 0.62, 0.78)

    local s = CreateFrame("Slider", nil, f, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", 0, -20)
    s:SetWidth(220)
    s:SetMinMaxValues(min, max)
    s:SetValueStep(1)
    s:SetObeyStepOnDrag(true)
    s.Low:SetText("")
    s.High:SetText("")

    local eb = CreateFrame("EditBox", nil, f, "BackdropTemplate")
    eb:SetSize(45, 20)
    eb:SetPoint("LEFT", s, "RIGHT", 15, 0)
    eb:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]], edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
    eb:SetBackdropColor(0, 0, 0, 0.8)
    eb:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    eb:SetFontObject("GameFontHighlightSmall")
    eb:SetJustifyH("CENTER")
    eb:SetAutoFocus(false)

    s:SetScript("OnValueChanged", function(_, val) eb:SetText(math.floor(val)) end)
    eb:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val then s:SetValue(val) end
        self:ClearFocus()
    end)

    return s
end
