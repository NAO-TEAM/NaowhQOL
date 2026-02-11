local addonName, ns = ...
local L = ns.L

local cache = {}
local W = ns.Widgets
local C = ns.COLORS

local ringShapes = {
    { text = L["MOUSE_SHAPE_CIRCLE"], value = "ring.tga" },
    { text = L["MOUSE_SHAPE_THIN"],   value = "thin_ring.tga" },
    { text = L["MOUSE_SHAPE_THICK"],  value = "thick_ring.tga" },
}

local function GetDB()
    NaowhQOL = NaowhQOL or {}
    NaowhQOL.mouseRing = NaowhQOL.mouseRing or {}
    return NaowhQOL.mouseRing
end

-- Debounced save for slider controls
local saveTimer = nil
local function DebouncedSave()
    if saveTimer then saveTimer:Cancel() end
    saveTimer = C_Timer.NewTimer(0.3, function()
        saveTimer = nil
    end)
end

function ns.InitMouseOptions()
    local p = ns.MainFrame.Content
    local display = ns.MouseRingDisplay

    W:CachedPanel(cache, "cursorPanel", p, function(f)
        local db = GetDB()
        local sf, sc = W:CreateScrollFrame(f, 900)

        W:CreatePageHeader(sc,
            {{"MOUSE", C.BLUE}, {"RING", C.ORANGE}},
            W.Colorize(L["MOUSE_SUBTITLE"], C.GRAY))

        local function refresh()
            if display then display:UpdateDisplay() end
        end

        local killArea = CreateFrame("Frame", nil, sc, "BackdropTemplate")
        killArea:SetSize(460, 87)
        killArea:SetPoint("TOPLEFT", 10, -75)
        killArea:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
        killArea:SetBackdropColor(0.01, 0.56, 0.91, 0.08)

        local masterCB = W:CreateCheckbox(killArea, {
            label = L["MOUSE_ENABLE"],
            db = db, key = "enabled",
            x = 15, y = -8,
            isMaster = true,
        })

        local oocCB = W:CreateCheckbox(killArea, {
            label = L["MOUSE_VISIBLE_OOC"],
            db = db, key = "showOutOfCombat",
            x = 15, y = -38,
            template = "ChatConfigCheckButtonTemplate",
            onChange = function()
                if display then display:RefreshVisibility() end
            end
        })
        oocCB:SetShown(db.enabled)

        local hideOnClickCB = W:CreateCheckbox(killArea, {
            label = L["MOUSE_HIDE_ON_CLICK"],
            db = db, key = "hideOnMouseClick",
            x = 15, y = -63,
            template = "ChatConfigCheckButtonTemplate",
            onChange = function()
                if display then display:RefreshVisibility() end
            end
        })
        hideOnClickCB:SetShown(db.enabled)

        local sectionContainer = CreateFrame("Frame", nil, sc)
        sectionContainer:SetPoint("TOPLEFT", killArea, "BOTTOMLEFT", 0, -10)
        sectionContainer:SetPoint("RIGHT", sc, "RIGHT", -10, 0)
        sectionContainer:SetHeight(600)

        local RelayoutSections

        -- APPEARANCE section
        local appWrap, appContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["MOUSE_SECTION_APPEARANCE"],
            startOpen = false,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local G = ns.Layout:New(2)

        W:CreateDropdown(appContent, {
            label = L["MOUSE_SHAPE"],
            db = db, key = "shape",
            options = ringShapes,
            x = G:Col(1), y = G:Row(1),
            width = 120,
            onChange = function(val)
                if display then display:UpdateShape(val) end
            end
        })

        W:CreateColorPicker(appContent, {
            label = L["MOUSE_COLOR_BACKGROUND"], db = db,
            rKey = "colorR", gKey = "colorG", bKey = "colorB",
            classColorKey = "useClassColor",
            x = G:Col(2), y = G:Row(1) - 10,
            onChange = function(r, g, b)
                if display then display:UpdateColor(r, g, b) end
            end
        })

        W:CreateSlider(appContent, {
            label = L["MOUSE_SIZE"],
            min = 16, max = 256, step = 1,
            x = G:Col(1), y = G:Row(2),
            value = db.size or 48,
            onChange = function(val)
                if display then display:UpdateSize(val) end
            end
        })

        W:CreateSlider(appContent, {
            label = L["MOUSE_OPACITY_COMBAT"],
            min = 0, max = 100, step = 10,
            x = G:Col(2), y = G:Row(2),
            isPercent = true,
            value = (db.opacityInCombat or 1.0) * 100,
            onChange = function(val)
                db.opacityInCombat = val / 100
                DebouncedSave()
            end
        })

        W:CreateSlider(appContent, {
            label = L["MOUSE_OPACITY_OOC"],
            min = 0, max = 100, step = 10,
            x = G:Col(1), y = G:Row(3),
            isPercent = true,
            value = (db.opacityOutOfCombat or 1.0) * 100,
            onChange = function(val)
                db.opacityOutOfCombat = val / 100
                DebouncedSave()
            end
        })

        appContent:SetHeight(G:Height(3))
        appWrap:RecalcHeight()

        -- GCD section
        local gcdWrap, gcdContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["MOUSE_SECTION_GCD"],
            startOpen = false,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local GG = ns.Layout:New(2)

        W:CreateCheckbox(gcdContent, {
            label = L["MOUSE_GCD_ENABLE"],
            db = db, key = "gcdEnabled",
            x = GG:Col(1), y = GG:Row(1) + 5,
            template = "ChatConfigCheckButtonTemplate",
            onChange = function()
                if display then display:RefreshGCD() end
            end
        })

        W:CreateCheckbox(gcdContent, {
            label = L["MOUSE_HIDE_BACKGROUND"],
            db = db, key = "hideBackground",
            x = GG:Col(2), y = GG:Row(1) + 5,
            template = "ChatConfigCheckButtonTemplate",
            onChange = function()
                if display then display:RefreshVisibility() end
            end
        })

        local swipeBtn, swipePreview = W:CreateColorPicker(gcdContent, {
            label = L["MOUSE_COLOR_SWIPE"], db = db,
            rKey = "gcdR", gKey = "gcdG", bKey = "gcdB",
            x = GG:Col(1), y = GG:Row(2) - 10,
            onChange = function()
                if display then display:RefreshGCD() end
            end
        })

        local readyBtn, readyPreview, readyToggle = W:CreateColorPicker(gcdContent, {
            label = L["MOUSE_COLOR_READY"], db = db,
            rKey = "gcdReadyR", gKey = "gcdReadyG", bKey = "gcdReadyB",
            x = GG:Col(2), y = GG:Row(2) - 10,
            onChange = function()
                if display then display:RefreshGCD() end
            end
        })

        local matchSwipeCB = W:CreateCheckbox(gcdContent, {
            label = L["MOUSE_GCD_READY_MATCH"],
            db = db, key = "gcdReadyMatchSwipe",
            x = GG:Col(2), y = GG:Row(3) + 5,
            template = "ChatConfigCheckButtonTemplate",
            onChange = function(enabled)
                readyBtn:SetShown(not enabled)
                readyPreview:SetShown(not enabled)
                readyToggle:SetShown(not enabled)
                if display then display:RefreshGCD() end
            end
        })

        readyBtn:SetShown(not db.gcdReadyMatchSwipe)
        readyPreview:SetShown(not db.gcdReadyMatchSwipe)
        readyToggle:SetShown(not db.gcdReadyMatchSwipe)

        W:CreateSlider(gcdContent, {
            label = L["MOUSE_OPACITY_SWIPE"],
            min = 0, max = 100, step = 10,
            x = GG:Col(1), y = GG:Row(3),
            isPercent = true,
            value = (db.gcdAlpha or 1.0) * 100,
            onChange = function(val)
                db.gcdAlpha = val / 100
                DebouncedSave()
                if display then display:RefreshGCD() end
            end
        })

        W:CreateCheckbox(gcdContent, {
            label = L["MOUSE_CAST_SWIPE_ENABLE"],
            db = db, key = "castSwipeEnabled",
            x = GG:Col(1), y = GG:Row(4) + 5,
            template = "ChatConfigCheckButtonTemplate",
            onChange = function() end
        })

        W:CreateColorPicker(gcdContent, {
            label = L["MOUSE_COLOR_CAST_SWIPE"] or "Cast Swipe", db = db,
            rKey = "castSwipeR", gKey = "castSwipeG", bKey = "castSwipeB",
            x = GG:Col(1), y = GG:Row(5) - 10,
            onChange = function() end
        })

        gcdContent:SetHeight(GG:Height(5))
        gcdWrap:RecalcHeight()

        -- TRAIL section
        local trailWrap, trailContent = W:CreateCollapsibleSection(sectionContainer, {
            text = L["MOUSE_SECTION_TRAIL"],
            startOpen = false,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local GT = ns.Layout:New(2)

        W:CreateCheckbox(trailContent, {
            label = L["MOUSE_TRAIL_ENABLE"],
            db = db, key = "trailEnabled",
            x = GT:Col(1), y = GT:Row(1) + 5,
            template = "ChatConfigCheckButtonTemplate",
            onChange = function()
                if display then display:RefreshVisibility() end
            end
        })

        W:CreateColorPicker(trailContent, {
            label = L["MOUSE_TRAIL_COLOR"], db = db,
            rKey = "trailR", gKey = "trailG", bKey = "trailB",
            x = GT:Col(2), y = GT:Row(1) - 10,
            onChange = function() end
        })

        W:CreateSlider(trailContent, {
            label = L["MOUSE_TRAIL_DURATION"],
            min = 10, max = 100, step = 5,
            x = GT:Col(1), y = GT:Row(2),
            value = ((db.trailDuration or 0.6) - 0.1) / 0.4 * 100,
            onChange = function(val)
                db.trailDuration = 0.1 + (val / 100) * 0.4
                DebouncedSave()
            end
        })

        trailContent:SetHeight(GT:Height(2))
        trailWrap:RecalcHeight()

        local allSections = { appWrap, gcdWrap, trailWrap }

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

            local totalH = 100 + 95 + 10
            if db.enabled then
                for _, s in ipairs(allSections) do
                    totalH = totalH + s:GetHeight() + 12
                end
            end
            sc:SetHeight(math.max(totalH + 40, 600))
        end

        masterCB:HookScript("OnClick", function(self)
            db.enabled = self:GetChecked() and true or false

            if display then
                display:UpdateDisplay()
            end

            oocCB:SetShown(db.enabled)
            hideOnClickCB:SetShown(db.enabled)
            sectionContainer:SetShown(db.enabled)
            if db.enabled then
                killArea:SetBackdropColor(0.01, 0.56, 0.91, 0.08)
            end
            RelayoutSections()
        end)
        sectionContainer:SetShown(db.enabled)

        -- Restore defaults button
        local restoreBtn = W:CreateRestoreDefaultsButton({
            moduleName = "mouseRing",
            parent = sc,
        })
        restoreBtn:SetPoint("BOTTOMLEFT", sc, "BOTTOMLEFT", 10, 20)

        RelayoutSections()
    end)
end

-- Initialize display when module loads
function ns.UpdateMouseCircle()
    if ns.MouseRingDisplay then
        ns.MouseRingDisplay:UpdateDisplay()
    end
end
