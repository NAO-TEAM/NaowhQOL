local addonName, ns = ...
local L = ns.L

local cache = {}
local W = ns.Widgets
local C = ns.COLORS

local function PlaceSlider(slider, parent, x, y)
    local frame = slider:GetParent()
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    return slider
end

local function ApplyPreset(db, preset, display, refreshUI)
    if preset == "cross" then
        db.showTop, db.showRight, db.showBottom, db.showLeft = true, true, true, true
        db.rotation = 0; db.dotEnabled = false; db.circleEnabled = false
    elseif preset == "dot" then
        db.showTop, db.showRight, db.showBottom, db.showLeft = false, false, false, false
        db.rotation = 0; db.dotEnabled = true; db.circleEnabled = false
    elseif preset == "circle" then
        db.showTop, db.showRight, db.showBottom, db.showLeft = true, true, true, true
        db.rotation = 0; db.dotEnabled = true; db.circleEnabled = true
    end
    if display then display:UpdateDisplay() end
    if refreshUI then refreshUI() end
end

function ns:InitCrosshair()
    local p = ns.MainFrame.Content
    local db = NaowhQOL.crosshair
    local display = ns.CrosshairDisplay

    W:CachedPanel(cache, "chFrame", p, function(f)
        local sf, sc = W:CreateScrollFrame(f, 1200)

        W:CreatePageHeader(sc,
            {{"CROSS", C.BLUE}, {"HAIR", C.ORANGE}},
            W.Colorize(L["CROSSHAIR_SUBTITLE"], C.GRAY))

        local function refresh()
            if display then display:UpdateDisplay() end
        end

        -- on/off toggle
        local killArea = CreateFrame("Frame", nil, sc, "BackdropTemplate")
        killArea:SetSize(460, 62)
        killArea:SetPoint("TOPLEFT", 10, -75)
        killArea:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
        killArea:SetBackdropColor(0.01, 0.56, 0.91, 0.08)

        local masterCB = W:CreateCheckbox(killArea, {
            label = L["CROSSHAIR_ENABLE"],
            db = db, key = "enabled",
            x = 15, y = -8,
            isMaster = true,
        })

        local combatCB = W:CreateCheckbox(killArea, {
            label = L["CROSSHAIR_COMBAT_ONLY"],
            db = db, key = "combatOnly",
            x = 15, y = -38,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refresh
        })
        combatCB:SetShown(db.enabled)

        local mountCB = W:CreateCheckbox(killArea, {
            label = L["CROSSHAIR_HIDE_MOUNTED"],
            db = db, key = "hideWhileMounted",
            x = 200, y = -38,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refresh
        })
        mountCB:SetShown(db.enabled)

        -- Section container
        local sectionContainer = CreateFrame("Frame", nil, sc)
        sectionContainer:SetPoint("TOPLEFT", killArea, "BOTTOMLEFT", 0, -10)
        sectionContainer:SetPoint("RIGHT", sc, "RIGHT", -10, 0)
        sectionContainer:SetHeight(900)

        local RelayoutSections
        local refreshControls

        -- SHAPE PRESETS section
        local shpWrap, shpContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["CROSSHAIR_SECTION_SHAPE"],
            startOpen = true,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local presetBtnWidth = 120
        local presetNames = {
            { label = L["CROSSHAIR_PRESET_CROSS"],  id = "cross" },
            { label = L["CROSSHAIR_PRESET_DOT"],    id = "dot" },
            { label = L["CROSSHAIR_PRESET_CIRCLE"], id = "circle" },
        }

        for idx, preset in ipairs(presetNames) do
            local btn = W:CreateButton(shpContent, {
                text = preset.label,
                width = presetBtnWidth,
                height = 24,
                onClick = function()
                    ApplyPreset(db, preset.id, display, refreshControls)
                end
            })
            btn:SetPoint("TOPLEFT", 10 + (idx - 1) * (presetBtnWidth + 8), -5)
        end

        local armKeys = {
            { label = L["CROSSHAIR_ARM_TOP"],    key = "showTop"    },
            { label = L["CROSSHAIR_ARM_RIGHT"],  key = "showRight"  },
            { label = L["CROSSHAIR_ARM_BOTTOM"], key = "showBottom" },
            { label = L["CROSSHAIR_ARM_LEFT"],   key = "showLeft"   },
        }
        local armToggles = {}
        for idx, def in ipairs(armKeys) do
            local cb = W:CreateCheckbox(shpContent, {
                label = def.label,
                db = db, key = def.key,
                x = 10 + (idx - 1) * 110, y = -35,
                template = "interface",
                font = "GameFontNormal",
                onChange = refresh,
            })
            cb:SetSize(26, 26)
            cb.Text:SetTextColor(1, 1, 1)
            armToggles[def.key] = cb
        end

        shpContent:SetHeight(65)
        shpWrap:RecalcHeight()

        -- DIMENSIONS section
        local dimWrap, dimContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["CROSSHAIR_SECTION_DIMENSIONS"],
            startOpen = true,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local rotSlider = W:CreateAdvancedSlider(dimContent,
            W.Colorize(L["CROSSHAIR_ROTATION"], C.ORANGE), 0, 359, -5, 1, false,
            function(val) db.rotation = val; refresh() end,
            { db = db, key = "rotation", moduleName = "crosshair" })
        PlaceSlider(rotSlider, dimContent, 0, -5)

        local sizeSlider = W:CreateAdvancedSlider(dimContent,
            W.Colorize(L["CROSSHAIR_ARM_LENGTH"], C.ORANGE), 2, 80, -65, 1, false,
            function(val) db.size = val; refresh() end,
            { db = db, key = "size", moduleName = "crosshair" })
        PlaceSlider(sizeSlider, dimContent, 0, -65)

        local thickSlider = W:CreateAdvancedSlider(dimContent,
            W.Colorize(L["CROSSHAIR_THICKNESS"], C.ORANGE), 1, 20, -65, 1, false,
            function(val) db.thickness = val; refresh() end,
            { db = db, key = "thickness", moduleName = "crosshair" })
        PlaceSlider(thickSlider, dimContent, 240, -65)

        local gapSlider = W:CreateAdvancedSlider(dimContent,
            W.Colorize(L["CROSSHAIR_CENTER_GAP"], C.ORANGE), 0, 40, -125, 1, false,
            function(val) db.gap = val; refresh() end,
            { db = db, key = "gap", moduleName = "crosshair" })
        PlaceSlider(gapSlider, dimContent, 0, -125)

        local dotSizeSlider = W:CreateAdvancedSlider(dimContent,
            W.Colorize(L["CROSSHAIR_DOT_SIZE"], C.ORANGE), 1, 16, -125, 1, false,
            function(val) db.dotSize = val; refresh() end,
            { db = db, key = "dotSize", moduleName = "crosshair" })
        PlaceSlider(dotSizeSlider, dimContent, 240, -125)

        local dotToggle = W:CreateCheckbox(dimContent, {
            label = L["CROSSHAIR_CENTER_DOT"],
            db = db, key = "dotEnabled",
            x = 10, y = -185,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refresh
        })

        dimContent:SetHeight(215)
        dimWrap:RecalcHeight()

        -- APPEARANCE section
        local appWrap, appContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["CROSSHAIR_SECTION_APPEARANCE"],
            startOpen = true,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        W:CreateColorPicker(appContent, {
            label = L["CROSSHAIR_COLOR_PRIMARY"], db = db,
            rKey = "colorR", gKey = "colorG", bKey = "colorB",
            x = 10, y = -5,
            onChange = refresh
        })

        -- Opacity stored as 0-1, slider shows 0-100
        local opacSlider = W:CreateAdvancedSlider(appContent,
            W.Colorize(L["CROSSHAIR_OPACITY"], C.ORANGE), 0, 100, -40, 5, true,
            function(val) db.opacity = val / 100; refresh() end,
            { value = (db.opacity ~= nil and db.opacity or 0.8) * 100 })
        PlaceSlider(opacSlider, appContent, 0, -40)

        local color2Btn, color2Preview

        W:CreateCheckbox(appContent, {
            label = L["CROSSHAIR_DUAL_COLOR"],
            db = db, key = "dualColor",
            x = 10, y = -100,
            template = "ChatConfigCheckButtonTemplate",
            description = L["CROSSHAIR_DUAL_COLOR_DESC"],
            onChange = function(enabled)
                if color2Btn then
                    if enabled then color2Btn:Show(); color2Preview:Show()
                    else color2Btn:Hide(); color2Preview:Hide() end
                end
                refresh()
            end
        })

        color2Btn, color2Preview = W:CreateColorPicker(appContent, {
            label = L["CROSSHAIR_COLOR_SECONDARY"], db = db,
            rKey = "color2R", gKey = "color2G", bKey = "color2B",
            x = 10, y = -130,
            onChange = refresh
        })

        if not db.dualColor then
            color2Btn:Hide(); color2Preview:Hide()
        end

        W:CreateCheckbox(appContent, {
            label = L["CROSSHAIR_BORDER_ALWAYS"],
            db = db, key = "outlineEnabled",
            x = 10, y = -165,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refresh
        })

        local outSlider = W:CreateAdvancedSlider(appContent,
            W.Colorize(L["CROSSHAIR_BORDER_THICKNESS"], C.ORANGE), 1, 6, -195, 1, false,
            function(val) db.outlineWeight = val; refresh() end,
            { db = db, key = "outlineWeight", moduleName = "crosshair" })
        PlaceSlider(outSlider, appContent, 0, -195)

        W:CreateColorPicker(appContent, {
            label = L["CROSSHAIR_COLOR_BORDER"], db = db,
            rKey = "outlineR", gKey = "outlineG", bKey = "outlineB",
            x = 240, y = -190,
            onChange = refresh
        })

        appContent:SetHeight(235)
        appWrap:RecalcHeight()

        -- CIRCLE section
        local circWrap, circContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["CROSSHAIR_SECTION_CIRCLE"],
            startOpen = true,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local circToggle = W:CreateCheckbox(circContent, {
            label = L["CROSSHAIR_CIRCLE_ENABLE"],
            db = db, key = "circleEnabled",
            x = 10, y = -5,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refresh
        })

        W:CreateColorPicker(circContent, {
            label = L["CROSSHAIR_COLOR_CIRCLE"], db = db,
            rKey = "circleR", gKey = "circleG", bKey = "circleB",
            x = 10, y = -35,
            onChange = refresh
        })

        local circSlider = W:CreateAdvancedSlider(circContent,
            W.Colorize(L["CROSSHAIR_CIRCLE_SIZE"], C.ORANGE), 10, 120, -70, 1, false,
            function(val) db.circleSize = val; refresh() end,
            { db = db, key = "circleSize", moduleName = "crosshair" })
        PlaceSlider(circSlider, circContent, 0, -70)

        circContent:SetHeight(120)
        circWrap:RecalcHeight()

        -- POSITION section
        local posWrap, posContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["CROSSHAIR_SECTION_POSITION"],
            startOpen = true,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local xSlider = W:CreateAdvancedSlider(posContent,
            W.Colorize(L["CROSSHAIR_OFFSET_X"], C.ORANGE), -200, 200, -5, 1, false,
            function(val) db.offsetX = val; refresh() end,
            { db = db, key = "offsetX", moduleName = "crosshair" })
        PlaceSlider(xSlider, posContent, 0, -5)

        local ySlider = W:CreateAdvancedSlider(posContent,
            W.Colorize(L["CROSSHAIR_OFFSET_Y"], C.ORANGE), -200, 200, -5, 1, false,
            function(val) db.offsetY = val; refresh() end,
            { db = db, key = "offsetY", moduleName = "crosshair" })
        PlaceSlider(ySlider, posContent, 240, -5)

        local resetBtn = W:CreateButton(posContent, {
            text = L["CROSSHAIR_RESET_POSITION"],
            width = 140,
            height = 26,
            onClick = function()
                db.offsetX = 0; db.offsetY = 0
                xSlider:SetValue(0); ySlider:SetValue(0)
                refresh()
            end
        })
        resetBtn:SetPoint("TOPLEFT", 10, -70)

        posContent:SetHeight(100)
        posWrap:RecalcHeight()

        -- DETECTION section (melee range)
        local mlWrap, mlContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["CROSSHAIR_SECTION_DETECTION"],
            startOpen = true,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local meleeSubElements = {}

        local function updateMeleeSubVisibility()
            local show = db.meleeRecolor
            for _, el in ipairs(meleeSubElements) do
                el:SetShown(show)
            end
            -- Adjust section height
            mlContent:SetHeight(show and 370 or 35)
            mlWrap:RecalcHeight()
            if RelayoutSections then RelayoutSections() end
        end

        W:CreateCheckbox(mlContent, {
            label = L["CROSSHAIR_MELEE_ENABLE"],
            db = db, key = "meleeRecolor",
            x = 10, y = -5,
            template = "ChatConfigCheckButtonTemplate",
            onChange = function()
                refresh()
                updateMeleeSubVisibility()
            end
        })

        -- Recolor options
        meleeSubElements[#meleeSubElements + 1] = W:CreateCheckbox(mlContent, {
            label = L["CROSSHAIR_RECOLOR_BORDER"],
            db = db, key = "meleeRecolorBorder",
            x = 10, y = -35,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refresh
        })

        meleeSubElements[#meleeSubElements + 1] = W:CreateCheckbox(mlContent, {
            label = L["CROSSHAIR_RECOLOR_ARMS"],
            db = db, key = "meleeRecolorArms",
            x = 150, y = -35,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refresh
        })

        meleeSubElements[#meleeSubElements + 1] = W:CreateCheckbox(mlContent, {
            label = L["CROSSHAIR_RECOLOR_DOT"],
            db = db, key = "meleeRecolorDot",
            x = 280, y = -35,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refresh
        })

        meleeSubElements[#meleeSubElements + 1] = W:CreateCheckbox(mlContent, {
            label = L["CROSSHAIR_RECOLOR_CIRCLE"],
            db = db, key = "meleeRecolorCircle",
            x = 400, y = -35,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refresh
        })

        local oorColorBtn, oorColorPreview = W:CreateColorPicker(mlContent, {
            label = L["CROSSHAIR_COLOR_OUT_OF_RANGE"], db = db,
            rKey = "meleeOutColorR", gKey = "meleeOutColorG", bKey = "meleeOutColorB",
            x = 10, y = -65,
            onChange = refresh
        })
        meleeSubElements[#meleeSubElements + 1] = oorColorBtn
        meleeSubElements[#meleeSubElements + 1] = oorColorPreview

        -- Sound options
        local soundCB = W:CreateCheckbox(mlContent, {
            label = L["CROSSHAIR_SOUND_ENABLE"],
            db = db, key = "meleeSoundEnabled",
            x = 10, y = -105,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refresh
        })
        meleeSubElements[#meleeSubElements + 1] = soundCB

        local soundPicker = W:CreateSoundPicker(mlContent, 10, -135, db.meleeSoundID or 8959,
            function(id) db.meleeSoundID = id end)
        meleeSubElements[#meleeSubElements + 1] = soundPicker

        local intervalSlider = W:CreateAdvancedSlider(mlContent,
            W.Colorize(L["CROSSHAIR_SOUND_INTERVAL"], C.ORANGE), 0, 15, -175, 1, false,
            function(val) db.meleeSoundInterval = val end,
            { db = db, key = "meleeSoundInterval", moduleName = "crosshair" })
        PlaceSlider(intervalSlider, mlContent, 0, -175)
        meleeSubElements[#meleeSubElements + 1] = intervalSlider:GetParent()

        -- Spell ID customization
        local spellLabel = mlContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        spellLabel:SetPoint("TOPLEFT", 10, -240)
        spellLabel:SetText(W.Colorize(L["CROSSHAIR_SPELL_ID"], C.WHITE))
        meleeSubElements[#meleeSubElements + 1] = spellLabel

        local spellStatusText = mlContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        spellStatusText:SetPoint("TOPLEFT", 10, -257)
        spellStatusText:SetTextColor(0.6, 0.6, 0.6)
        meleeSubElements[#meleeSubElements + 1] = spellStatusText

        local spellInputContainer = CreateFrame("Frame", nil, mlContent)
        spellInputContainer:SetSize(250, 25)
        spellInputContainer:SetPoint("TOPLEFT", 10, -275)
        meleeSubElements[#meleeSubElements + 1] = spellInputContainer

        local spellInput = CreateFrame("EditBox", nil, spellInputContainer, "InputBoxTemplate")
        spellInput:SetSize(100, 20)
        spellInput:SetPoint("LEFT", 0, 0)
        spellInput:SetAutoFocus(false)
        spellInput:SetNumeric(true)
        spellInput:SetMaxLetters(6)

        local function UpdateSpellDisplay()
            local info = ns.MeleeRangeInfo
            if not info then return end

            local current = info.GetCurrentSpell()
            local default = info.GetDefaultSpell()

            if current then
                spellInput:SetText(tostring(current))
                local spellInfo = C_Spell.GetSpellInfo(current)
                local spellName = spellInfo and spellInfo.name or "Unknown"
                spellStatusText:SetText(string.format(L["CROSSHAIR_SPELL_CURRENT"], spellName))
                spellStatusText:SetTextColor(0.5, 1, 0.5)
            elseif default == nil then
                spellInput:SetText("")
                spellStatusText:SetText(L["CROSSHAIR_SPELL_UNSUPPORTED"])
                spellStatusText:SetTextColor(1, 0.5, 0.5)
            else
                spellInput:SetText("")
                spellStatusText:SetText(L["CROSSHAIR_SPELL_NONE"])
                spellStatusText:SetTextColor(1, 0.5, 0.5)
            end
        end

        spellInput:SetScript("OnEnterPressed", function(self)
            local info = ns.MeleeRangeInfo
            if not info then return end

            local key = info.GetSpellKey()
            if not key then return end

            local val = tonumber(self:GetText())
            if val and val > 0 then
                db.meleeSpellOverrides = db.meleeSpellOverrides or {}
                db.meleeSpellOverrides[key] = val
                info.RefreshCache()
                refresh()
            end
            UpdateSpellDisplay()
            self:ClearFocus()
        end)

        spellInput:SetScript("OnEscapePressed", function(self)
            UpdateSpellDisplay()
            self:ClearFocus()
        end)

        local resetSpellBtn = W:CreateButton(spellInputContainer, {
            text = L["CROSSHAIR_RESET_SPELL"],
            width = 120,
            height = 22,
            onClick = function()
                local info = ns.MeleeRangeInfo
                if not info then return end

                local key = info.GetSpellKey()
                if key and db.meleeSpellOverrides then
                    db.meleeSpellOverrides[key] = nil
                end
                info.RefreshCache()
                UpdateSpellDisplay()
                refresh()
            end
        })
        resetSpellBtn:SetPoint("LEFT", spellInput, "RIGHT", 10, 0)

        UpdateSpellDisplay()

        -- Register for spec changes to update display
        ns.SpecUtil.RegisterCallback("CrosshairConfig", function()
            UpdateSpellDisplay()
        end)

        updateMeleeSubVisibility()

        mlContent:SetHeight(db.meleeRecolor and 370 or 35)
        mlWrap:RecalcHeight()

        -- Preset refresh callback
        refreshControls = function()
            rotSlider:SetValue(db.rotation or 0)
            armToggles.showTop:SetChecked(db.showTop ~= false)
            armToggles.showRight:SetChecked(db.showRight ~= false)
            armToggles.showBottom:SetChecked(db.showBottom ~= false)
            armToggles.showLeft:SetChecked(db.showLeft ~= false)
            dotToggle:SetChecked(db.dotEnabled and true or false)
            circToggle:SetChecked(db.circleEnabled and true or false)
        end

        -- Relayout
        local allSections = { shpWrap, dimWrap, appWrap, circWrap, posWrap, mlWrap }

        RelayoutSections = function()
            for i, section in ipairs(allSections) do
                section:ClearAllPoints()
                if i == 1 then
                    section:SetPoint("TOPLEFT", sectionContainer, "TOPLEFT", 0, 0)
                else
                    section:SetPoint("TOPLEFT", allSections[i - 1], "BOTTOMLEFT", 0, -12)
                end
                section:SetPoint("RIGHT", sectionContainer, "RIGHT", 0, 0)
            end

            local totalH = 75 + 62 + 10
            if db.enabled then
                for _, s in ipairs(allSections) do
                    totalH = totalH + s:GetHeight() + 12
                end
            end
            sc:SetHeight(math.max(totalH + 40, 600))
        end

        masterCB:SetScript("OnClick", function(self)
            db.enabled = self:GetChecked() and true or false
            refresh()
            combatCB:SetShown(db.enabled)
            mountCB:SetShown(db.enabled)
            sectionContainer:SetShown(db.enabled)
            RelayoutSections()
        end)
        sectionContainer:SetShown(db.enabled)

        -- Restore defaults button
        local restoreBtn = W:CreateRestoreDefaultsButton({
            moduleName = "crosshair",
            parent = sc,
            initFunc = function() ns:InitCrosshair() end,
            onRestore = function()
                if cache.chFrame then
                    cache.chFrame:Hide()
                    cache.chFrame:SetParent(nil)
                    cache.chFrame = nil
                end
                if display then display:UpdateDisplay() end
            end
        })
        restoreBtn:SetPoint("BOTTOMLEFT", sc, "BOTTOMLEFT", 10, 20)

        RelayoutSections()
    end)

    if display then display:UpdateDisplay() end
end
