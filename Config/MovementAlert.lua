local addonName, ns = ...
local L = ns.L

local cache = {}
local W = ns.Widgets
local C = ns.COLORS

function ns:InitMovementAlert()
    local p = ns.MainFrame.Content
    local db = NaowhQOL.movementAlert
    local movementDisplay = ns.MovementAlertDisplay
    local timeSpiralDisplay = ns.TimeSpiralDisplay

    W:CachedPanel(cache, "maFrame", p, function(f)
        local sf, sc = W:CreateScrollFrame(f, 800)

        W:CreatePageHeader(sc,
            {{"MOVEMENT", C.BLUE}, {" ALERT", C.ORANGE}},
            L["MOVEMENT_ALERT_SUBTITLE"])

        local function refreshMovement() if movementDisplay then movementDisplay:UpdateDisplay() end end
        local function refreshTimeSpiral() if timeSpiralDisplay then timeSpiralDisplay:UpdateDisplay() end end
        local function refreshAll() refreshMovement(); refreshTimeSpiral() end

        -- ============================================================
        -- MOVEMENT COOLDOWN
        -- ============================================================

        local killArea = CreateFrame("Frame", nil, sc, "BackdropTemplate")
        killArea:SetSize(460, 90)
        killArea:SetPoint("TOPLEFT", 10, -75)
        killArea:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
        killArea:SetBackdropColor(0.01, 0.56, 0.91, 0.08)

        local masterCB = W:CreateCheckbox(killArea, {
            label = L["MOVEMENT_ALERT_ENABLE"],
            db = db, key = "enabled",
            x = 15, y = -8,
            isMaster = true,
        })

        local unlockCB = W:CreateCheckbox(killArea, {
            label = L["COMMON_UNLOCK"],
            db = db, key = "unlock",
            x = 15, y = -38,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refreshMovement
        })
        unlockCB:SetShown(db.enabled)

        local combatOnlyCB = W:CreateCheckbox(killArea, {
            label = L["GCD_COMBAT_ONLY"],
            db = db, key = "combatOnly",
            x = 15, y = -63,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refreshMovement
        })
        combatOnlyCB:SetShown(db.enabled)

        -- Movement sections container
        local movementSections = CreateFrame("Frame", nil, sc)
        movementSections:SetPoint("TOPLEFT", killArea, "BOTTOMLEFT", 0, -10)
        movementSections:SetPoint("RIGHT", sc, "RIGHT", -10, 0)
        movementSections:SetHeight(300)

        local RelayoutAll

        -- APPEARANCE (contains all display settings)
        local appWrap, appContent = W:CreateCollapsibleSection(movementSections, {
            text = L["COMMON_SECTION_APPEARANCE"],
            startOpen = false,
            onCollapse = function() if RelayoutAll then RelayoutAll() end end,
        })

        local LA = ns.Layout:New(2)

        -- Forward declare conditional rows
        local textFormatRow, barIconRow

        local function updateConditionalRows()
            if textFormatRow then textFormatRow:SetShown(db.displayMode == "text") end
            if barIconRow then barIconRow:SetShown(db.displayMode == "bar") end
        end

        -- Row 1: Font | Text Color
        W:CreateFontPicker(appContent, LA:Col(1), LA:Row(1) + 12, db.font, function(path)
            db.font = path
            refreshAll()
        end)

        W:CreateColorPicker(appContent, {
            label = L["COMMON_LABEL_TEXT_COLOR"], db = db,
            rKey = "textColorR", gKey = "textColorG", bKey = "textColorB",
            x = LA:Col(2), y = LA:Row(1) + 6,
            onChange = refreshMovement
        })

        -- Row 2: Display Mode | Timer Decimals
        W:CreateDropdown(appContent, {
            label = L["MOVEMENT_ALERT_DISPLAY_MODE"],
            x = LA:Col(1), y = LA:Row(2),
            db = db, key = "displayMode",
            options = {
                { text = L["MOVEMENT_ALERT_MODE_TEXT"], value = "text" },
                { text = L["MOVEMENT_ALERT_MODE_ICON"], value = "icon" },
                { text = L["MOVEMENT_ALERT_MODE_BAR"], value = "bar" },
            },
            onChange = function()
                refreshMovement()
                updateConditionalRows()
            end
        })

        W:CreateSlider(appContent, {
            label = L["MOVEMENT_ALERT_POLL_RATE"],
            min = 50, max = 500, step = 50,
            x = LA:Col(2), y = LA:Row(2),
            db = db, key = "pollRate",
            onChange = function(val) db.pollRate = val end
        })

        -- Row 3: Text Format (only for text mode)
        textFormatRow = CreateFrame("Frame", nil, appContent)
        textFormatRow:SetPoint("TOPLEFT", LA:Col(1), LA:Row(3) - 15)
        textFormatRow:SetSize(400, 60)

        W:CreateTextInput(textFormatRow, {
            label = L["MOVEMENT_ALERT_TEXT_FORMAT"], db = db, key = "textFormat",
            default = "No %a - %ts", x = 0, y = 0, width = 200,
            onChange = refreshMovement
        })

        local textFormatHelp = textFormatRow:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        textFormatHelp:SetPoint("TOPLEFT", 0, -48)
        textFormatHelp:SetText(L["MOVEMENT_ALERT_TEXT_FORMAT_HELP"])

        -- Row 3 (alternate): Show Icon on Progress Bar (only for bar mode)
        barIconRow = CreateFrame("Frame", nil, appContent)
        barIconRow:SetPoint("TOPLEFT", LA:Col(1), LA:Row(3) - 15)
        barIconRow:SetSize(400, 50)

        W:CreateCheckbox(barIconRow, {
            label = L["MOVEMENT_ALERT_BAR_SHOW_ICON"],
            db = db, key = "barShowIcon",
            x = 0, y = 5,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refreshMovement
        })

        -- Set initial visibility
        updateConditionalRows()

        appContent:SetHeight(LA:Height(3))
        appWrap:RecalcHeight()

        -- ============================================================
        -- TIME SPIRAL
        -- ============================================================

        local tsKillArea = CreateFrame("Frame", nil, sc, "BackdropTemplate")
        tsKillArea:SetSize(460, 62)
        tsKillArea:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
        tsKillArea:SetBackdropColor(0.53, 1, 0, 0.08)

        local tsMasterCB = W:CreateCheckbox(tsKillArea, {
            label = L["TIME_SPIRAL_ENABLE"],
            db = db, key = "tsEnabled",
            x = 15, y = -8,
            isMaster = true,
        })

        local tsUnlockCB = W:CreateCheckbox(tsKillArea, {
            label = L["COMMON_UNLOCK"],
            db = db, key = "tsUnlock",
            x = 15, y = -38,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refreshTimeSpiral
        })
        tsUnlockCB:SetShown(db.tsEnabled)

        -- Time Spiral sections container
        local tsSections = CreateFrame("Frame", nil, sc)
        tsSections:SetPoint("RIGHT", sc, "RIGHT", -10, 0)
        tsSections:SetHeight(200)

        -- TIME SPIRAL SETTINGS
        local tsColWrap, tsColContent = W:CreateCollapsibleSection(tsSections, {
            text = L["TIME_SPIRAL_SETTINGS"],
            startOpen = false,
            onCollapse = function() if RelayoutAll then RelayoutAll() end end,
        })

        local LT = ns.Layout:New(2)

        W:CreateTextInput(tsColContent, {
            label = L["TIME_SPIRAL_TEXT"], db = db, key = "tsText",
            default = "FREE MOVEMENT", x = LT:Col(1), y = LT:Row(1) + 12, width = 180,
            onChange = refreshTimeSpiral
        })

        W:CreateColorPicker(tsColContent, {
            label = L["TIME_SPIRAL_COLOR"], db = db,
            rKey = "tsColorR", gKey = "tsColorG", bKey = "tsColorB",
            x = LT:Col(2), y = LT:Row(1) + 6,
            onChange = refreshTimeSpiral
        })

        W:CreateCheckbox(tsColContent, {
            label = L["TIME_SPIRAL_SOUND_ON"],
            db = db, key = "tsSoundEnabled",
            x = LT:Col(1), y = LT:Row(2) + 5,
            template = "ChatConfigCheckButtonTemplate",
            onChange = function()
                if db.tsSoundEnabled then db.tsTtsEnabled = false end
                refreshTimeSpiral()
            end
        })

        W:CreateSoundPicker(tsColContent, LT:Col(2), LT:Row(2) + 11, db.tsSoundID and { id = db.tsSoundID } or { id = 8959 },
            function(entry)
                db.tsSoundID = entry.id or entry.path
            end)

        W:CreateCheckbox(tsColContent, {
            label = L["TIME_SPIRAL_TTS_ON"],
            db = db, key = "tsTtsEnabled",
            x = LT:Col(1), y = LT:Row(3) + 5,
            template = "ChatConfigCheckButtonTemplate",
            onChange = function()
                if db.tsTtsEnabled then db.tsSoundEnabled = false end
                refreshTimeSpiral()
            end
        })

        W:CreateTextInput(tsColContent, {
            label = L["TIME_SPIRAL_TTS_MESSAGE"], db = db, key = "tsTtsMessage",
            default = "Free movement", x = LT:Col(1), y = LT:Row(4) + 12, width = 180,
        })

        W:CreateSlider(tsColContent, {
            label = L["TIME_SPIRAL_TTS_VOLUME"],
            min = 0, max = 100, step = 1,
            x = LT:Col(2), y = LT:Row(4),
            db = db, key = "tsTtsVolume",
            onChange = function(val) db.tsTtsVolume = val end
        })

        tsColContent:SetHeight(LT:Height(5))
        tsColWrap:RecalcHeight()

        -- ============================================================
        -- GATEWAY SHARD
        -- ============================================================

        local gatewayDisplay = ns.GatewayShardDisplay
        local function refreshGateway() if gatewayDisplay then gatewayDisplay:UpdateDisplay() end end

        local gwKillArea = CreateFrame("Frame", nil, sc, "BackdropTemplate")
        gwKillArea:SetSize(460, 90)
        gwKillArea:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
        gwKillArea:SetBackdropColor(0.5, 0, 0.8, 0.08)

        local gwMasterCB = W:CreateCheckbox(gwKillArea, {
            label = L["GATEWAY_SHARD_ENABLE"],
            db = db, key = "gwEnabled",
            x = 15, y = -8,
            isMaster = true,
        })

        local gwUnlockCB = W:CreateCheckbox(gwKillArea, {
            label = L["COMMON_UNLOCK"],
            db = db, key = "gwUnlock",
            x = 15, y = -38,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refreshGateway
        })
        gwUnlockCB:SetShown(db.gwEnabled)

        local gwCombatOnlyCB = W:CreateCheckbox(gwKillArea, {
            label = L["GCD_COMBAT_ONLY"],
            db = db, key = "gwCombatOnly",
            x = 15, y = -63,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refreshGateway
        })
        gwCombatOnlyCB:SetShown(db.gwEnabled)

        -- Gateway sections container
        local gwSections = CreateFrame("Frame", nil, sc)
        gwSections:SetPoint("RIGHT", sc, "RIGHT", -10, 0)
        gwSections:SetHeight(200)

        -- GATEWAY SHARD SETTINGS
        local gwColWrap, gwColContent = W:CreateCollapsibleSection(gwSections, {
            text = L["GATEWAY_SHARD_SETTINGS"],
            startOpen = false,
            onCollapse = function() if RelayoutAll then RelayoutAll() end end,
        })

        local LG = ns.Layout:New(2)

        W:CreateTextInput(gwColContent, {
            label = L["GATEWAY_SHARD_TEXT"], db = db, key = "gwText",
            default = "GATEWAY READY", x = LG:Col(1), y = LG:Row(1) + 12, width = 180,
            onChange = refreshGateway
        })

        W:CreateColorPicker(gwColContent, {
            label = L["GATEWAY_SHARD_COLOR"], db = db,
            rKey = "gwColorR", gKey = "gwColorG", bKey = "gwColorB",
            x = LG:Col(2), y = LG:Row(1) + 6,
            onChange = refreshGateway
        })

        W:CreateCheckbox(gwColContent, {
            label = L["GATEWAY_SHARD_SOUND_ON"],
            db = db, key = "gwSoundEnabled",
            x = LG:Col(1), y = LG:Row(2) + 5,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refreshGateway
        })

        W:CreateSoundPicker(gwColContent, LG:Col(2), LG:Row(2) + 11, db.gwSoundID and { id = db.gwSoundID } or { id = 8959 },
            function(entry)
                db.gwSoundID = entry.id or entry.path
            end)

        W:CreateCheckbox(gwColContent, {
            label = L["GATEWAY_SHARD_TTS_ON"],
            db = db, key = "gwTtsEnabled",
            x = LG:Col(1), y = LG:Row(3) + 5,
            template = "ChatConfigCheckButtonTemplate",
            onChange = refreshGateway
        })

        W:CreateTextInput(gwColContent, {
            label = L["GATEWAY_SHARD_TTS_MESSAGE"], db = db, key = "gwTtsMessage",
            default = "Gateway ready", x = LG:Col(1), y = LG:Row(4) + 12, width = 180,
        })

        W:CreateSlider(gwColContent, {
            label = L["GATEWAY_SHARD_TTS_VOLUME"],
            min = 0, max = 100, step = 1,
            x = LG:Col(2), y = LG:Row(4),
            db = db, key = "gwTtsVolume",
            onChange = function(val) db.gwTtsVolume = val end
        })

        gwColContent:SetHeight(LG:Height(5))
        gwColWrap:RecalcHeight()

        -- ============================================================
        -- Layout
        -- ============================================================

        local movementSectionList = { appWrap }
        local tsSectionList = { tsColWrap }
        local gwSectionList = { gwColWrap }

        RelayoutAll = function()
            -- Movement sections
            for i, section in ipairs(movementSectionList) do
                section:ClearAllPoints()
                if i == 1 then
                    section:SetPoint("TOPLEFT", movementSections, "TOPLEFT", 0, 0)
                else
                    section:SetPoint("TOPLEFT", movementSectionList[i - 1], "BOTTOMLEFT", 0, -12)
                end
                section:SetPoint("RIGHT", movementSections, "RIGHT", 0, 0)
            end

            local movementH = 0
            if db.enabled then
                for _, s in ipairs(movementSectionList) do
                    movementH = movementH + s:GetHeight() + 12
                end
            end
            movementSections:SetHeight(math.max(movementH, 1))

            -- Position Time Spiral kill area below movement sections
            tsKillArea:ClearAllPoints()
            tsKillArea:SetPoint("TOPLEFT", movementSections, "BOTTOMLEFT", 0, -20)

            tsSections:ClearAllPoints()
            tsSections:SetPoint("TOPLEFT", tsKillArea, "BOTTOMLEFT", 0, -10)
            tsSections:SetPoint("RIGHT", sc, "RIGHT", -10, 0)

            -- Time Spiral sections
            for i, section in ipairs(tsSectionList) do
                section:ClearAllPoints()
                if i == 1 then
                    section:SetPoint("TOPLEFT", tsSections, "TOPLEFT", 0, 0)
                else
                    section:SetPoint("TOPLEFT", tsSectionList[i - 1], "BOTTOMLEFT", 0, -12)
                end
                section:SetPoint("RIGHT", tsSections, "RIGHT", 0, 0)
            end

            local tsH = 0
            if db.tsEnabled then
                for _, s in ipairs(tsSectionList) do
                    tsH = tsH + s:GetHeight() + 12
                end
            end
            tsSections:SetHeight(math.max(tsH, 1))

            -- Position Gateway Shard kill area below Time Spiral sections
            gwKillArea:ClearAllPoints()
            gwKillArea:SetPoint("TOPLEFT", tsSections, "BOTTOMLEFT", 0, -20)

            gwSections:ClearAllPoints()
            gwSections:SetPoint("TOPLEFT", gwKillArea, "BOTTOMLEFT", 0, -10)
            gwSections:SetPoint("RIGHT", sc, "RIGHT", -10, 0)

            -- Gateway Shard sections
            for i, section in ipairs(gwSectionList) do
                section:ClearAllPoints()
                if i == 1 then
                    section:SetPoint("TOPLEFT", gwSections, "TOPLEFT", 0, 0)
                else
                    section:SetPoint("TOPLEFT", gwSectionList[i - 1], "BOTTOMLEFT", 0, -12)
                end
                section:SetPoint("RIGHT", gwSections, "RIGHT", 0, 0)
            end

            local gwH = 0
            if db.gwEnabled then
                for _, s in ipairs(gwSectionList) do
                    gwH = gwH + s:GetHeight() + 12
                end
            end
            gwSections:SetHeight(math.max(gwH, 1))

            -- Total scroll height
            local totalH = 75 + 90 + 10 + movementH + 20 + 62 + 10 + tsH + 20 + 90 + 10 + gwH + 40
            sc:SetHeight(math.max(totalH, 800))
        end

        masterCB:HookScript("OnClick", function(self)
            db.enabled = self:GetChecked() and true or false
            refreshMovement()
            unlockCB:SetShown(db.enabled)
            combatOnlyCB:SetShown(db.enabled)
            movementSections:SetShown(db.enabled)
            RelayoutAll()
        end)
        movementSections:SetShown(db.enabled)

        tsMasterCB:HookScript("OnClick", function(self)
            db.tsEnabled = self:GetChecked() and true or false
            refreshTimeSpiral()
            tsUnlockCB:SetShown(db.tsEnabled)
            tsSections:SetShown(db.tsEnabled)
            RelayoutAll()
        end)
        tsSections:SetShown(db.tsEnabled)

        gwMasterCB:HookScript("OnClick", function(self)
            db.gwEnabled = self:GetChecked() and true or false
            refreshGateway()
            gwUnlockCB:SetShown(db.gwEnabled)
            gwCombatOnlyCB:SetShown(db.gwEnabled)
            gwSections:SetShown(db.gwEnabled)
            RelayoutAll()
        end)
        gwSections:SetShown(db.gwEnabled)

        -- Restore defaults button
        local restoreBtn = W:CreateRestoreDefaultsButton({
            moduleName = "movementAlert",
            parent = sc,
            initFunc = function() ns:InitMovementAlert() end,
            onRestore = function()
                if cache.maFrame then
                    cache.maFrame:Hide()
                    cache.maFrame:SetParent(nil)
                    cache.maFrame = nil
                end
                if movementDisplay then movementDisplay:UpdateDisplay() end
                if timeSpiralDisplay then timeSpiralDisplay:UpdateDisplay() end
                if gatewayDisplay then gatewayDisplay:UpdateDisplay() end
            end
        })
        restoreBtn:SetPoint("BOTTOMLEFT", sc, "BOTTOMLEFT", 10, 20)

        RelayoutAll()
    end)
end
