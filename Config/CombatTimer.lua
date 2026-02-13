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

function ns:InitCombatTimer()
    local p = ns.MainFrame.Content
    local db = NaowhQOL.combatTimer
    local display = ns.CombatTimerDisplay

    W:CachedPanel(cache, "ctFrame", p, function(f)
        local sf, sc = W:CreateScrollFrame(f, 600)

        W:CreatePageHeader(sc,
            {{"COMBAT", C.BLUE}, {"TIMER", C.ORANGE}},
            W.Colorize(L["COMBATTIMER_SUBTITLE"], C.GRAY))

        local function refresh() if display then display:UpdateDisplay() end end

        -- on/off toggle
        local killArea = CreateFrame("Frame", nil, sc, "BackdropTemplate")
        killArea:SetSize(460, 62)
        killArea:SetPoint("TOPLEFT", 10, -75)
        killArea:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
        killArea:SetBackdropColor(0.01, 0.56, 0.91, 0.08)

        local masterCB = W:CreateCheckbox(killArea, {
            label = L["COMBATTIMER_ENABLE"],
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

        -- Section container
        local sectionContainer = CreateFrame("Frame", nil, sc)
        sectionContainer:SetPoint("TOPLEFT", killArea, "BOTTOMLEFT", 0, -10)
        sectionContainer:SetPoint("RIGHT", sc, "RIGHT", -10, 0)
        sectionContainer:SetHeight(400)

        local RelayoutSections

        -- OPTIONS section
        local optWrap, optContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["COMBATTIMER_SECTION_OPTIONS"],
            startOpen = false,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        W:CreateCheckbox(optContent, {
            label = L["COMBATTIMER_INSTANCE_ONLY"],
            db = db, key = "instanceOnly",
            x = 10, y = -5,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refresh
        })

        W:CreateCheckbox(optContent, {
            label = L["COMBATTIMER_CHAT_REPORT"],
            db = db, key = "chatReport",
            x = 220, y = -5,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refresh
        })

        W:CreateCheckbox(optContent, {
            label = L["COMBATTIMER_STICKY"],
            db = db, key = "stickyTimer",
            x = 10, y = -35,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refresh
        })

        optContent:SetHeight(65)
        optWrap:RecalcHeight()

        -- APPEARANCE section
        local appWrap, appContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["COMMON_SECTION_APPEARANCE"],
            startOpen = false,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        W:CreateCheckbox(appContent, {
            label = L["COMBATTIMER_HIDE_PREFIX"],
            db = db, key = "hidePrefix",
            x = 10, y = -5,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refresh
        })

        W:CreateFontPicker(appContent, 10, -35, db.font, function(path)
            db.font = path
            refresh()
        end)

        W:CreateColorPicker(appContent, {
            label = L["COMBATTIMER_COLOR"], db = db,
            rKey = "colorR", gKey = "colorG", bKey = "colorB",
            classColorKey = "useClassColor",
            x = 10, y = -80,
            onChange = refresh
        })

        appContent:SetHeight(120)
        appWrap:RecalcHeight()

        -- Relayout
        local allSections = { optWrap, appWrap }

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

        masterCB:HookScript("OnClick", function(self)
            db.enabled = self:GetChecked() and true or false
            refresh()
            unlockCB:SetShown(db.enabled)
            sectionContainer:SetShown(db.enabled)
            RelayoutSections()
        end)
        sectionContainer:SetShown(db.enabled)

        -- Restore defaults button
        local restoreBtn = W:CreateRestoreDefaultsButton({
            moduleName = "combatTimer",
            parent = sc,
            initFunc = function() ns:InitCombatTimer() end,
            onRestore = function()
                if cache.ctFrame then
                    cache.ctFrame:Hide()
                    cache.ctFrame:SetParent(nil)
                    cache.ctFrame = nil
                end
                if display then display:UpdateDisplay() end
            end
        })
        restoreBtn:SetPoint("BOTTOMLEFT", sc, "BOTTOMLEFT", 10, 20)

        RelayoutSections()
    end)
end
