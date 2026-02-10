local addonName, ns = ...
local L = ns.L

local cache = {}
local W = ns.Widgets
local C = ns.COLORS

function ns:InitModuleOptions()
    local p = ns.MainFrame.Content

    W:CachedPanel(cache, "moduleFrame", p, function(f)
        local db = NaowhQOL.misc
        local sf, sc = W:CreateScrollFrame(f, 900)

        W:CreatePageHeader(sc,
            {{L["MODULES_TITLE"]:match("^(%S+)") .. " ", C.BLUE}, {L["MODULES_TITLE"]:match("%s(%S+)$") or "", C.ORANGE}},
            W.Colorize(L["MODULES_SUBTITLE"], C.GRAY))

        local sections = CreateFrame("Frame", nil, sc)
        sections:SetPoint("TOPLEFT", 10, -75)
        sections:SetPoint("RIGHT", sc, "RIGHT", -10, 0)
        sections:SetHeight(600)

        local RelayoutSections

        -- ============================================================
        -- ITEMS / LOOT
        -- ============================================================
        local itemsWrap, itemsContent = W:CreateCollapsibleSection(sections, {
            text = L["MODULES_SECTION_LOOT"],
            startOpen = false,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        W:CreateCheckbox(itemsContent, {
            label = L["MODULES_FASTER_LOOT"], db = db, key = "fasterLoot",
            x = 10, y = -5, template = "ChatConfigCheckButtonTemplate",
            description = L["MODULES_FASTER_LOOT_DESC"],
            descWidth = 350,
        })
        W:CreateCheckbox(itemsContent, {
            label = L["MODULES_SUPPRESS_WARNINGS"], db = db, key = "suppressLootWarnings",
            x = 10, y = -35, template = "ChatConfigCheckButtonTemplate",
            description = L["MODULES_SUPPRESS_WARNINGS_DESC"],
            descWidth = 350,
        })
        W:CreateCheckbox(itemsContent, {
            label = L["MODULES_EASY_DESTROY"], db = db, key = "autoFillDelete",
            x = 10, y = -65, template = "ChatConfigCheckButtonTemplate",
            description = L["MODULES_EASY_DESTROY_DESC"],
            descWidth = 350,
        })
        W:CreateCheckbox(itemsContent, {
            label = L["MODULES_AUTO_KEYSTONE"], db = db, key = "autoSlotKeystone",
            x = 10, y = -95, template = "ChatConfigCheckButtonTemplate",
            description = L["MODULES_AUTO_KEYSTONE_DESC"],
            descWidth = 350,
        })
        W:CreateCheckbox(itemsContent, {
            label = L["MODULES_AH_EXPANSION"], db = db, key = "ahCurrentExpansion",
            x = 10, y = -125, template = "ChatConfigCheckButtonTemplate",
            description = L["MODULES_AH_EXPANSION_DESC"],
            descWidth = 350,
        })

        itemsContent:SetHeight(155)
        itemsWrap:RecalcHeight()

        -- ============================================================
        -- UI CLUTTER
        -- ============================================================
        local clutterWrap, clutterContent = W:CreateCollapsibleSection(sections, {
            text = L["MODULES_SECTION_UI"],
            startOpen = false,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        W:CreateCheckbox(clutterContent, {
            label = L["MODULES_HIDE_ALERTS"], db = db, key = "hideAlerts",
            x = 10, y = -5, template = "ChatConfigCheckButtonTemplate",
            description = L["MODULES_HIDE_ALERTS_DESC"],
            descWidth = 350,
        })
        W:CreateCheckbox(clutterContent, {
            label = L["MODULES_HIDE_TALKING"], db = db, key = "hideTalkingHead",
            x = 10, y = -35, template = "ChatConfigCheckButtonTemplate",
            description = L["MODULES_HIDE_TALKING_DESC"],
            descWidth = 350,
        })
        W:CreateCheckbox(clutterContent, {
            label = L["MODULES_HIDE_TOASTS"], db = db, key = "hideEventToasts",
            x = 10, y = -65, template = "ChatConfigCheckButtonTemplate",
            description = L["MODULES_HIDE_TOASTS_DESC"],
            descWidth = 350,
        })
        W:CreateCheckbox(clutterContent, {
            label = L["MODULES_HIDE_ZONE"], db = db, key = "hideZoneText",
            x = 10, y = -95, template = "ChatConfigCheckButtonTemplate",
            description = L["MODULES_HIDE_ZONE_DESC"],
            descWidth = 350,
        })
        W:CreateCheckbox(clutterContent, {
            label = L["MODULES_SKIP_QUEUE"], db = db, key = "skipQueueConfirm",
            x = 10, y = -125, template = "ChatConfigCheckButtonTemplate",
            description = L["MODULES_SKIP_QUEUE_DESC"],
            descWidth = 350,
        })

        clutterContent:SetHeight(155)
        clutterWrap:RecalcHeight()

        -- ============================================================
        -- DEATH / DURABILITY / REPAIR
        -- ============================================================
        local durWrap, durContent = W:CreateCollapsibleSection(sections, {
            text = L["MODULES_SECTION_DEATH"],
            startOpen = false,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        W:CreateCheckbox(durContent, {
            label = L["MODULES_DONT_RELEASE"], db = db, key = "deathReleaseProtection",
            x = 10, y = -5, template = "ChatConfigCheckButtonTemplate",
            description = L["MODULES_DONT_RELEASE_DESC"],
            descWidth = 350,
        })

        local guildCB

        W:CreateCheckbox(durContent, {
            label = L["MODULES_AUTO_REPAIR"], db = db, key = "autoRepair",
            x = 10, y = -35, template = "ChatConfigCheckButtonTemplate",
            description = L["MODULES_AUTO_REPAIR_DESC"],
            descWidth = 350,
            onChange = function(enabled)
                if guildCB then guildCB:SetShown(enabled) end
            end,
        })

        guildCB = W:CreateCheckbox(durContent, {
            label = L["MODULES_GUILD_FUNDS"], db = db, key = "guildRepair",
            x = 30, y = -65, template = "ChatConfigCheckButtonTemplate",
            description = L["MODULES_GUILD_FUNDS_DESC"],
            descWidth = 330,
        })
        guildCB:SetShown(db.autoRepair)

        W:CreateCheckbox(durContent, {
            label = L["MODULES_DURABILITY"], db = db, key = "durabilityWarning",
            x = 10, y = -95, template = "ChatConfigCheckButtonTemplate",
            description = L["MODULES_DURABILITY_DESC"],
            descWidth = 350,
        })

        local threshSlider = W:CreateAdvancedSlider(durContent,
            L["MODULES_DURABILITY_THRESHOLD"], 30, 80, -140, 5, true,
            function(val) db.durabilityThreshold = val end,
            { value = db.durabilityThreshold or 50 })

        durContent:SetHeight(180)
        durWrap:RecalcHeight()

        -- ============================================================
        -- Layout
        -- ============================================================
        local sectionList = { itemsWrap, clutterWrap, durWrap }

        RelayoutSections = function()
            for i, section in ipairs(sectionList) do
                section:ClearAllPoints()
                if i == 1 then
                    section:SetPoint("TOPLEFT", sections, "TOPLEFT", 0, 0)
                else
                    section:SetPoint("TOPLEFT", sectionList[i - 1], "BOTTOMLEFT", 0, -12)
                end
                section:SetPoint("RIGHT", sections, "RIGHT", 0, 0)
            end

            local totalH = 0
            for _, s in ipairs(sectionList) do
                totalH = totalH + s:GetHeight() + 12
            end
            sections:SetHeight(math.max(totalH, 1))
            sc:SetHeight(math.max(75 + totalH + 40, 600))
        end

        RelayoutSections()
    end)
end
