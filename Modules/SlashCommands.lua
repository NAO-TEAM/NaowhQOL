local addonName, ns = ...
local L = ns.L

ns.SlashCommands = {}

local registeredCommands = {}

-- Known frames for the frame toggle dropdown (tested and working)
ns.SlashCommands.KNOWN_FRAMES = {
    -- Character & Stats
    { name = "Spellbook / Talents", value = "PlayerSpellsFrame", category = "Character" },
    { name = "Dress Up", value = "DressUpFrame", category = "Character" },
    { name = "Pet Stable", value = "StableFrame", category = "Character" },

    -- Collections & Journal
    { name = "Collections", value = "CollectionsJournal", category = "Collections" },
    { name = "Achievements", value = "AchievementFrame", category = "Collections" },
    { name = "Adventure Guide", value = "EncounterJournal", category = "Collections" },
    { name = "Allied Races", value = "AlliedRacesFrame", category = "Collections" },

    -- Social
    { name = "Communities", value = "CommunitiesFrame", category = "Social" },
    { name = "Raid Manager", value = "CompactRaidFrameManager", category = "Social" },
    { name = "Communities Avatar", value = "CommunitiesAvatarPickerDialog", category = "Social" },
    { name = "Channels", value = "ChannelFrame", category = "Social" },
    { name = "Chat Config", value = "ChatConfigFrame", category = "Social" },

    -- Group Content
    { name = "Group Finder", value = "PVEFrame", category = "Group" },
    { name = "Mythic+ Challenges", value = "ChallengesKeystoneFrame", category = "Group" },

    -- World & Navigation
    { name = "World Map", value = "WorldMapFrame", category = "World" },

    -- Inventory & Storage
    { name = "Guild Bank", value = "GuildBankFrame", category = "Inventory" },
    { name = "Loot", value = "LootFrame", category = "Inventory" },
    { name = "Auction House", value = "AuctionHouseFrame", category = "Inventory" },
    { name = "Black Market", value = "BlackMarketFrame", category = "Inventory" },
    { name = "Loot History", value = "GroupLootHistoryFrame", category = "Inventory" },

    -- Progression & Rewards
    { name = "Weekly Rewards", value = "WeeklyRewardsFrame", category = "Progression" },
    { name = "Item Upgrade", value = "ItemUpgradeFrame", category = "Progression" },
    { name = "Item Socketing", value = "ItemSocketingFrame", category = "Progression" },
    { name = "Contribution", value = "ContributionCollectionFrame", category = "Progression" },
    { name = "Death Recap", value = "DeathRecapFrame", category = "Progression" },
    { name = "Player Choice", value = "PlayerChoiceFrame", category = "Progression" },
    { name = "Account Store", value = "AccountStoreFrame", category = "Progression" },

    -- Appearance & Customization
    { name = "Barber Shop", value = "BarberShopFrame", category = "Appearance" },
    { name = "Tabard", value = "TabardFrame", category = "Appearance" },

    -- Crafting & Items
    { name = "Scrapping Machine", value = "ScrappingMachineFrame", category = "Crafting" },
    { name = "Runeforge", value = "RuneforgeFrame", category = "Crafting" },
    { name = "Professions Orders", value = "ProfessionsCustomerOrdersFrame", category = "Crafting" },

    -- Garrison & Missions
    { name = "Garrison Building", value = "GarrisonBuildingFrame", category = "Missions" },
    { name = "Garrison Mission", value = "GarrisonMissionFrame", category = "Missions" },
    { name = "Garrison Shipyard", value = "GarrisonShipyardFrame", category = "Missions" },
    { name = "Garrison Recruiter", value = "GarrisonRecruiterFrame", category = "Missions" },
    { name = "Covenant Preview", value = "CovenantPreviewFrame", category = "Missions" },

    -- Artifact & Azerite
    { name = "Azerite Essence", value = "AzeriteEssenceUI", category = "Artifact" },

    -- Delves & TWW Content
    { name = "Delves Difficulty", value = "DelvesDifficultyPickerFrame", category = "Delves" },
    { name = "Torghast Picker", value = "TorghastLevelPickerFrame", category = "Delves" },

    -- System & Settings
    { name = "Game Menu", value = "GameMenuFrame", category = "System" },
    { name = "Settings", value = "SettingsPanel", category = "System" },
    { name = "Calendar", value = "CalendarFrame", category = "System" },
    { name = "Addon List", value = "AddonList", category = "System" },
    { name = "Help", value = "HelpFrame", category = "System" },
    { name = "Stopwatch", value = "StopwatchFrame", category = "System" },
    { name = "Time Manager", value = "TimeManagerFrame", category = "System" },
    { name = "Click Binding", value = "ClickBindingFrame", category = "System" },
    { name = "Edit Mode", value = "EditModeManagerFrame", category = "System" },
    { name = "Quick Keybind", value = "QuickKeybindFrame", category = "System" },
    { name = "Cooldown Viewer", value = "CooldownViewerSettings", category = "System" },
    { name = "Color Picker", value = "ColorPickerFrame", category = "System" },
    { name = "Report Frame", value = "ReportFrame", category = "System" },
    { name = "Movie Frame", value = "MovieFrame", category = "System" },
    { name = "Cinematic Frame", value = "CinematicFrame", category = "System" },
    { name = "Splash Screen", value = "SplashFrame", category = "System" },

    -- Misc UI
    { name = "Chromie Time", value = "ChromieTimeFrame", category = "Misc" },
    { name = "Islands Queue", value = "IslandsQueueFrame", category = "Misc" },
    { name = "Pet Battle", value = "PetBattleFrame", category = "Misc" },
    { name = "Subscription", value = "SubscriptionInterstitialFrame", category = "Misc" },
    { name = "Perks Program", value = "PerksProgramFrame", category = "Misc" },

    -- Addon Frames
    { name = "NaowhQOL Settings", value = "NaowhQOL_MainFrame", category = "Addon" },
}

-- Generate unique slash command ID
local function GetSlashID(name)
    return "NAOWHQOL_" .. strupper(name)
end

-- Check if a slash command already exists (not registered by us)
local function CommandExistsExternally(name)
    local slashKey = "SLASH_" .. strupper(name) .. "1"
    local existing = _G[slashKey]
    if existing then
        local ourKey = "SLASH_" .. GetSlashID(name) .. "1"
        return _G[ourKey] ~= existing
    end
    return false
end

-- Register a single command
function ns.SlashCommands:Register(cmdData)
    if not cmdData or not cmdData.name then return false end

    local name = strlower(cmdData.name)
    local slashID = GetSlashID(name)

    -- Check for external conflicts
    if CommandExistsExternally(name) then
        print("|cffffa900NaowhQOL:|r /" .. name .. " " .. L["SLASH_WARN_CONFLICT"])
        return false
    end

    -- Register primary command
    _G["SLASH_" .. slashID .. "1"] = "/" .. name

    -- Create handler
    SlashCmdList[slashID] = function(msg)
        ns.SlashCommands:Execute(cmdData, msg)
    end

    registeredCommands[name] = slashID
    return true
end

-- Unregister a command
function ns.SlashCommands:Unregister(name)
    name = strlower(name)
    local slashID = registeredCommands[name]
    if not slashID then return end

    local idx = 1
    while _G["SLASH_" .. slashID .. idx] do
        _G["SLASH_" .. slashID .. idx] = nil
        idx = idx + 1
    end

    SlashCmdList[slashID] = nil
    registeredCommands[name] = nil
end

-- Execute command action
function ns.SlashCommands:Execute(cmdData, msg)
    local actionType = cmdData.actionType or "frame"

    if actionType == "command" then
        -- Execute another slash command
        self:RunSlashCommand(cmdData.command, msg)
    else
        -- Default: toggle frame (combat lockdown check)
        if InCombatLockdown() then
            print("|cffffa900NaowhQOL:|r " .. L["SLASH_ERR_COMBAT"])
            return
        end
        self:ToggleFrame(cmdData.frame)
    end
end

-- Execute a slash command string
function ns.SlashCommands:RunSlashCommand(command, args)
    if not command or command == "" then return end

    -- Ensure command starts with /
    if not command:match("^/") then
        command = "/" .. command
    end

    -- Append any arguments passed to our alias
    if args and args ~= "" then
        command = command .. " " .. args
    end

    -- Execute via chat edit box
    local editBox = ChatFrame1EditBox or (DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox)
    if editBox then
        local original = editBox:GetText()
        editBox:SetText(command)
        ChatEdit_SendText(editBox)
        editBox:SetText(original)
    end
end

-- Blizzard addon requirements for certain frames
-- Expose for Config access
ns.SlashCommands.FRAME_ADDON_REQUIREMENTS = {
    -- System & Settings
    EditModeManagerFrame = "Blizzard_EditMode",
    QuickKeybindFrame = "Blizzard_QuickKeybind",
    CooldownViewerSettings = "Blizzard_CooldownViewer",
    MacroFrame = "Blizzard_MacroUI",
    CalendarFrame = "Blizzard_Calendar",
    ClickBindingFrame = "Blizzard_ClickBindingUI",
    TimeManagerFrame = "Blizzard_TimeManager",
    HelpFrame = "Blizzard_HelpFrame",
    ReportFrame = "Blizzard_ReportFrame",

    -- Character & Talents
    ClassTalentFrame = "Blizzard_ClassTalentUI",
    PlayerSpellsFrame = "Blizzard_PlayerSpells",
    InspectFrame = "Blizzard_InspectUI",
    StableFrame = "Blizzard_StableUI",

    -- Professions
    ProfessionsFrame = "Blizzard_Professions",
    ProfessionsBookFrame = "Blizzard_ProfessionsBook",
    ProfessionsCustomerOrdersFrame = "Blizzard_ProfessionsCustomerOrders",
    ClassTrainerFrame = "Blizzard_TrainerUI",

    -- Collections & Journal
    CollectionsJournal = "Blizzard_Collections",
    WardrobeFrame = "Blizzard_Collections",
    AchievementFrame = "Blizzard_AchievementUI",
    EncounterJournal = "Blizzard_EncounterJournal",
    AlliedRacesFrame = "Blizzard_AlliedRacesUI",

    -- Social & Communities
    CommunitiesFrame = "Blizzard_Communities",
    CommunitiesGuildLogFrame = "Blizzard_Communities",
    CommunitiesGuildTextEditFrame = "Blizzard_Communities",
    CommunitiesGuildNewsFiltersFrame = "Blizzard_Communities",
    CommunitiesSettingsDialog = "Blizzard_Communities",
    CommunitiesAvatarPickerDialog = "Blizzard_Communities",
    ChannelFrame = "Blizzard_Channels",

    -- Group Content
    PVPUIFrame = "Blizzard_PVPUI",
    ChallengesKeystoneFrame = "Blizzard_ChallengesUI",
    CompactRaidFrameManager = "Blizzard_CompactRaidFrames",
    RaidParentFrame = "Blizzard_RaidFrame",
    BattlefieldMapFrame = "Blizzard_BattlefieldMap",

    -- Inventory & Trading
    AuctionHouseFrame = "Blizzard_AuctionHouseUI",
    BlackMarketFrame = "Blizzard_BlackMarketUI",
    GuildBankFrame = "Blizzard_GuildBankUI",
    GroupLootHistoryFrame = "Blizzard_GroupLootHistoryFrame",

    -- Progression & Rewards
    WeeklyRewardsFrame = "Blizzard_WeeklyRewards",
    ItemUpgradeFrame = "Blizzard_ItemUpgradeUI",
    ItemSocketingFrame = "Blizzard_ItemSocketingUI",
    ContributionCollectionFrame = "Blizzard_Contribution",
    DeathRecapFrame = "Blizzard_DeathRecap",
    PlayerChoiceFrame = "Blizzard_PlayerChoice",
    AccountStoreFrame = "Blizzard_AccountStore",

    -- Crafting & Items
    ScrappingMachineFrame = "Blizzard_ScrappingMachineUI",
    RuneforgeFrame = "Blizzard_RuneforgeUI",
    ObliterumForgeFrame = "Blizzard_ObliterumUI",
    ItemInteractionFrame = "Blizzard_ItemInteractionUI",

    -- Garrison & Missions
    GarrisonBuildingFrame = "Blizzard_GarrisonUI",
    GarrisonMissionFrame = "Blizzard_GarrisonUI",
    GarrisonShipyardFrame = "Blizzard_GarrisonUI",
    GarrisonRecruiterFrame = "Blizzard_GarrisonUI",
    GarrisonMonumentFrame = "Blizzard_GarrisonUI",
    OrderHallMissionFrame = "Blizzard_OrderHallUI",
    OrderHallTalentFrame = "Blizzard_OrderHallUI",
    BFAMissionFrame = "Blizzard_GarrisonUI",
    CovenantMissionFrame = "Blizzard_GarrisonUI",
    CovenantSanctumFrame = "Blizzard_CovenantSanctum",
    CovenantRenownFrame = "Blizzard_CovenantRenown",
    CovenantPreviewFrame = "Blizzard_CovenantPreviewUI",
    AnimaDiversionFrame = "Blizzard_AnimaDiversionUI",

    -- Artifact & Azerite
    ArtifactFrame = "Blizzard_ArtifactUI",
    AzeriteEssenceUI = "Blizzard_AzeriteEssenceUI",
    AzeriteRespecFrame = "Blizzard_AzeriteRespecUI",
    GenericTraitFrame = "Blizzard_GenericTraitUI",

    -- Delves & TWW
    DelvesCompanionConfigurationFrame = "Blizzard_DelvesCompanionConfiguration",
    DelvesDifficultyPickerFrame = "Blizzard_DelvesDifficultyPicker",
    TorghastLevelPickerFrame = "Blizzard_TorghastLevelPicker",

    -- Misc
    ArchaeologyFrame = "Blizzard_ArchaeologyUI",
    ChromieTimeFrame = "Blizzard_ChromieTimeUI",
    IslandsQueueFrame = "Blizzard_IslandsQueueUI",
    SpectateFrame = "Blizzard_SpectateFrame",
    PetBattleFrame = "Blizzard_PetBattleUI",
    WowTokenFrame = "Blizzard_WowTokenUI",
    CurrencyTransferMenu = "Blizzard_TokenUI",
    RecruitAFriendFrame = "Blizzard_RecruitAFriend",
    SubscriptionInterstitialFrame = "Blizzard_SubscriptionInterstitialUI",
    PerksProgramFrame = "Blizzard_PerksProgram",
    FlightMapFrame = "Blizzard_FlightMap",
    WorldMapFrame = "Blizzard_WorldMap",

    -- Housing
    HousingDashboardFrame = "Blizzard_HousingDashboard",
    HousingControlsFrame = "Blizzard_HousingControls",
    HousingBulletinBoardFrame = "Blizzard_HousingBulletinBoard",
    HousingHouseSettingsFrame = "Blizzard_HousingHouseSettings",
    HouseListFrame = "Blizzard_HouseList",
    HouseFinderFrame = "Blizzard_HousingHouseFinder",
}

-- Toggle frame visibility (wrapped in pcall for safety)
function ns.SlashCommands:ToggleFrame(frameName)
    if not frameName or frameName == "" then return end

    local success, err = pcall(function()
        -- Load required Blizzard addon if needed
        local requiredAddon = ns.SlashCommands.FRAME_ADDON_REQUIREMENTS[frameName]
        if requiredAddon and not C_AddOns.IsAddOnLoaded(requiredAddon) then
            C_AddOns.LoadAddOn(requiredAddon)
        end

        local frame = _G[frameName]
        if frame and frame.IsShown then
            if frame:IsShown() then
                frame:Hide()
            else
                frame:Show()
            end
        end
    end)

    -- Fail silently - don't spam errors for frames that don't work
end

-- Initialize all enabled commands
function ns.SlashCommands:InitializeAll()
    local db = NaowhQOL.slashCommands
    if not db or not db.enabled then return end

    for _, cmd in ipairs(db.commands or {}) do
        if cmd.enabled then
            self:Register(cmd)
        end
    end
end

-- Refresh commands (unregister all, then re-register enabled ones)
function ns.SlashCommands:RefreshAll()
    for name, _ in pairs(registeredCommands) do
        self:Unregister(name)
    end
    self:InitializeAll()
end

-- Get display string for a command
function ns.SlashCommands:GetDisplayName(cmdData)
    return "/" .. cmdData.name
end

-- Initialize on login
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        -- Unregister after first use - this is a one-time initialization
        self:UnregisterEvent("PLAYER_LOGIN")
        C_Timer.After(0.5, function()
            ns.SlashCommands:InitializeAll()
        end)
    end
end)

-- Cleanup function for addon disable
function ns.SlashCommands:Cleanup()
    -- Clear registered commands table
    wipe(registeredCommands)
end
