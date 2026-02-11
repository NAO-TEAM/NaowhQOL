local addonName, ns = ...
local L = ns.L

local cache = {}
local W = ns.Widgets
local C = ns.COLORS

function ns:InitPetTracker()
    local p = ns.MainFrame.Content
    local db = NaowhQOL.petTracker
    local petDisplay = ns.PetTrackerDisplay

    local function refresh()
        if petDisplay then petDisplay:UpdateDisplay() end
    end

    W:CachedPanel(cache, "petTrackerFrame", p, function(f)
        local sf, sc = W:CreateScrollFrame(f, 800)

        W:CreatePageHeader(sc,
            {{"PET ", C.BLUE}, {"TRACKER", C.ORANGE}},
            L["PETTRACKER_SUBTITLE"])

        -- Class note
        local classNote = sc:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        classNote:SetPoint("TOPLEFT", 12, -60)
        classNote:SetText(L["PETTRACKER_CLASS_NOTE"])

        -- Master toggle area
        local killArea = CreateFrame("Frame", nil, sc, "BackdropTemplate")
        killArea:SetSize(460, 62)
        killArea:SetPoint("TOPLEFT", 10, -85)
        killArea:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
        killArea:SetBackdropColor(0.01, 0.56, 0.91, 0.08)

        local masterCB = W:CreateCheckbox(killArea, {
            label = L["PETTRACKER_ENABLE"],
            db = db, key = "enabled",
            x = 15, y = -8,
            isMaster = true,
        })

        local unlockCB = W:CreateCheckbox(killArea, {
            label = L["COMMON_UNLOCK"],
            db = db, key = "unlock",
            x = 15, y = -38,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refresh
        })
        unlockCB:SetShown(db.enabled)

        -- Sections container
        local sectionContainer = CreateFrame("Frame", nil, sc)
        sectionContainer:SetPoint("TOPLEFT", killArea, "BOTTOMLEFT", 0, -10)
        sectionContainer:SetPoint("RIGHT", sc, "RIGHT", -10, 0)
        sectionContainer:SetHeight(500)

        local RelayoutAll

        -- BEHAVIOR section
        local behaviorWrap, behaviorContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["COMMON_SECTION_BEHAVIOR"],
            startOpen = false,
            onCollapse = function() if RelayoutAll then RelayoutAll() end end,
        })

        W:CreateCheckbox(behaviorContent, {
            label = L["PETTRACKER_SHOW_ICON"],
            db = db, key = "showIcon",
            x = 10, y = -5,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refresh
        })

        W:CreateCheckbox(behaviorContent, {
            label = L["PETTRACKER_INSTANCE_ONLY"],
            db = db, key = "onlyInInstance",
            x = 10, y = -30,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refresh
        })

        behaviorContent:SetHeight(65)
        behaviorWrap:RecalcHeight()

        -- APPEARANCE section
        local appWrap, appContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["COMMON_SECTION_APPEARANCE"],
            startOpen = false,
            onCollapse = function() if RelayoutAll then RelayoutAll() end end,
        })

        local G = ns.Layout:New(2)

        local function PlaceSlider(slider, x, y)
            local frame = slider:GetParent()
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", appContent, "TOPLEFT", x, y)
        end

        -- Row 1: Text Size / Icon Size
        local textSlider = W:CreateAdvancedSlider(appContent, L["COMMON_LABEL_TEXT_SIZE"], 12, 48, G:SliderY(1), 1, false,
            function(val) db.textSize = val; refresh() end,
            { db = db, key = "textSize", moduleName = "petTracker" })
        PlaceSlider(textSlider, G:Col(1), G:SliderY(1))

        local iconSlider = W:CreateAdvancedSlider(appContent, L["COMMON_LABEL_ICON_SIZE"], 16, 64, G:SliderY(1), 2, false,
            function(val) db.iconSize = val; refresh() end,
            { db = db, key = "iconSize", moduleName = "petTracker" })
        PlaceSlider(iconSlider, G:Col(2), G:SliderY(1))

        -- Row 2: Text Color
        W:CreateColorPicker(appContent, {
            label = L["COMMON_LABEL_TEXT_COLOR"], db = db,
            rKey = "colorR", gKey = "colorG", bKey = "colorB",
            x = G:Col(1), y = G:ColorY(2),
            onChange = refresh
        })

        appContent:SetHeight(G:Height(2))
        appWrap:RecalcHeight()

        -- WARNING TEXT section
        local textWrap, textContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["PETTRACKER_SECTION_WARNINGS"],
            startOpen = false,
            onCollapse = function() if RelayoutAll then RelayoutAll() end end,
        })

        -- Missing Pet Text
        local missingLbl = textContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        missingLbl:SetPoint("TOPLEFT", 10, -10)
        missingLbl:SetText(L["PETTRACKER_MISSING_LABEL"])

        local missingBox = CreateFrame("EditBox", nil, textContent, "BackdropTemplate")
        missingBox:SetSize(180, 24)
        missingBox:SetPoint("LEFT", missingLbl, "RIGHT", 8, 0)
        missingBox:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]],
            edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
        missingBox:SetBackdropColor(0, 0, 0, 1)
        missingBox:SetBackdropBorderColor(0, 0, 0, 1)
        missingBox:SetFontObject("GameFontHighlightSmall")
        missingBox:SetAutoFocus(false)
        missingBox:SetTextInsets(6, 6, 0, 0)
        missingBox:SetMaxLetters(30)
        missingBox:SetText(db.missingText or L["PETTRACKER_MISSING_DEFAULT"])
        missingBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        missingBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        missingBox:SetScript("OnEditFocusLost", function(self)
            local val = strtrim(self:GetText())
            if val == "" then val = L["PETTRACKER_MISSING_DEFAULT"]; self:SetText(val) end
            db.missingText = val
            refresh()
        end)

        -- Passive Pet Text
        local passiveLbl = textContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        passiveLbl:SetPoint("TOPLEFT", 10, -45)
        passiveLbl:SetText(L["PETTRACKER_PASSIVE_LABEL"])

        local passiveBox = CreateFrame("EditBox", nil, textContent, "BackdropTemplate")
        passiveBox:SetSize(180, 24)
        passiveBox:SetPoint("LEFT", passiveLbl, "RIGHT", 8, 0)
        passiveBox:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]],
            edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
        passiveBox:SetBackdropColor(0, 0, 0, 1)
        passiveBox:SetBackdropBorderColor(0, 0, 0, 1)
        passiveBox:SetFontObject("GameFontHighlightSmall")
        passiveBox:SetAutoFocus(false)
        passiveBox:SetTextInsets(6, 6, 0, 0)
        passiveBox:SetMaxLetters(30)
        passiveBox:SetText(db.passiveText or L["PETTRACKER_PASSIVE_DEFAULT"])
        passiveBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        passiveBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        passiveBox:SetScript("OnEditFocusLost", function(self)
            local val = strtrim(self:GetText())
            if val == "" then val = L["PETTRACKER_PASSIVE_DEFAULT"]; self:SetText(val) end
            db.passiveText = val
            refresh()
        end)

        -- Wrong Pet Text (Demo Warlock)
        local wrongLbl = textContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        wrongLbl:SetPoint("TOPLEFT", 10, -80)
        wrongLbl:SetText(L["PETTRACKER_WRONGPET_LABEL"])

        local wrongBox = CreateFrame("EditBox", nil, textContent, "BackdropTemplate")
        wrongBox:SetSize(180, 24)
        wrongBox:SetPoint("LEFT", wrongLbl, "RIGHT", 8, 0)
        wrongBox:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]],
            edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
        wrongBox:SetBackdropColor(0, 0, 0, 1)
        wrongBox:SetBackdropBorderColor(0, 0, 0, 1)
        wrongBox:SetFontObject("GameFontHighlightSmall")
        wrongBox:SetAutoFocus(false)
        wrongBox:SetTextInsets(6, 6, 0, 0)
        wrongBox:SetMaxLetters(30)
        wrongBox:SetText(db.wrongPetText or L["PETTRACKER_WRONGPET_DEFAULT"])
        wrongBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        wrongBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        wrongBox:SetScript("OnEditFocusLost", function(self)
            local val = strtrim(self:GetText())
            if val == "" then val = L["PETTRACKER_WRONGPET_DEFAULT"]; self:SetText(val) end
            db.wrongPetText = val
            refresh()
        end)

        textContent:SetHeight(115)
        textWrap:RecalcHeight()

        -- Layout management
        local allSections = { behaviorWrap, appWrap, textWrap }

        RelayoutAll = function()
            for i, section in ipairs(allSections) do
                section:ClearAllPoints()
                if i == 1 then
                    section:SetPoint("TOPLEFT", sectionContainer, "TOPLEFT", 0, 0)
                else
                    section:SetPoint("TOPLEFT", allSections[i - 1], "BOTTOMLEFT", 0, -12)
                end
                section:SetPoint("RIGHT", sectionContainer, "RIGHT", 0, 0)
            end

            local totalH = 85 + 62 + 10
            if db.enabled then
                for _, s in ipairs(allSections) do
                    totalH = totalH + s:GetHeight() + 12
                end
            end
            sc:SetHeight(math.max(totalH + 60, 700))
        end

        masterCB:HookScript("OnClick", function(self)
            db.enabled = self:GetChecked() and true or false
            refresh()
            unlockCB:SetShown(db.enabled)
            sectionContainer:SetShown(db.enabled)
            RelayoutAll()
        end)
        sectionContainer:SetShown(db.enabled)

        -- Restore defaults button
        local restoreBtn = W:CreateRestoreDefaultsButton({
            moduleName = "petTracker",
            parent = sc,
            initFunc = function() ns:InitPetTracker() end,
            onRestore = function()
                if cache.petTrackerFrame then
                    cache.petTrackerFrame:Hide()
                    cache.petTrackerFrame:SetParent(nil)
                    cache.petTrackerFrame = nil
                end
                if petDisplay then petDisplay:UpdateDisplay() end
            end
        })
        restoreBtn:SetPoint("BOTTOMLEFT", sc, "BOTTOMLEFT", 10, 20)

        RelayoutAll()
    end)
end
