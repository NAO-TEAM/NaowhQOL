local addonName, ns = ...

-- Quest automation for faster questing

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")

local function GetDB()
    NaowhQOL = NaowhQOL or {}
    NaowhQOL.misc = NaowhQOL.misc or {}
    return NaowhQOL.misc
end

local function ApplyInteractRange()
    local db = GetDB()
    if db.enhancedInteractRange then
        SetCVar("SoftTargetInteractArc", 2)
        SetCVar("SoftTargetInteractRange", 30)
    end
end

frame:SetScript("OnEvent", function(self, event, ...)
    local db = GetDB()

    if event == "PLAYER_LOGIN" then
        -- Apply enhanced interact range on login if enabled
        ApplyInteractRange()

        -- Register quest events
        self:RegisterEvent("QUEST_DETAIL")
        self:RegisterEvent("QUEST_PROGRESS")
        self:RegisterEvent("QUEST_COMPLETE")
        self:RegisterEvent("QUEST_ACCEPT_CONFIRM")
        self:RegisterEvent("QUEST_GREETING")
        self:RegisterEvent("GOSSIP_SHOW")
        return
    end

    -- Hold alt to bypass automation
    if IsAltKeyDown() then return end

    ----------------------------------------------------------------------
    -- Auto Accept Quests
    ----------------------------------------------------------------------
    if event == "QUEST_DETAIL" then
        if not db.autoQuestAccept then return end

        if QuestGetAutoAccept() then
            CloseQuest()
        else
            AcceptQuest()
        end
        return
    end

    -- Confirm escort/shared quests
    if event == "QUEST_ACCEPT_CONFIRM" then
        if not db.autoQuestAccept then return end
        ConfirmAcceptQuest()
        StaticPopup_Hide("QUEST_ACCEPT")
        return
    end

    ----------------------------------------------------------------------
    -- Auto Turn-in Quests
    ----------------------------------------------------------------------
    if event == "QUEST_PROGRESS" then
        if not db.autoQuestTurnIn then return end
        if not IsQuestCompletable() then return end
        CompleteQuest()
        return
    end

    if event == "QUEST_COMPLETE" then
        if not db.autoQuestTurnIn then return end

        -- Only auto-complete if there's 0 or 1 reward choice
        if GetNumQuestChoices() <= 1 then
            GetQuestReward(GetNumQuestChoices())
        end
        return
    end

    ----------------------------------------------------------------------
    -- Auto Select from Gossip/Greeting
    ----------------------------------------------------------------------
    if event == "GOSSIP_SHOW" or event == "QUEST_GREETING" then
        if not db.autoGossipSelect then return end

        if event == "QUEST_GREETING" then
            -- Select completed quests first (turn-in)
            if db.autoQuestTurnIn then
                for i = 1, GetNumActiveQuests() do
                    local title, isComplete = GetActiveTitle(i)
                    if title and isComplete then
                        return SelectActiveQuest(i)
                    end
                end
            end

            -- Select available quests (accept)
            if db.autoQuestAccept then
                for i = 1, GetNumAvailableQuests() do
                    return SelectAvailableQuest(i)
                end
            end
        else
            -- GOSSIP_SHOW - use C_GossipInfo API
            -- Select completed quests first (turn-in)
            if db.autoQuestTurnIn then
                local activeQuests = C_GossipInfo.GetActiveQuests()
                for _, questInfo in ipairs(activeQuests) do
                    if questInfo.title and questInfo.isComplete and questInfo.questID then
                        return C_GossipInfo.SelectActiveQuest(questInfo.questID)
                    end
                end
            end

            -- Select available quests (accept)
            if db.autoQuestAccept then
                local availableQuests = C_GossipInfo.GetAvailableQuests()
                for _, questInfo in ipairs(availableQuests) do
                    if questInfo.questID then
                        return C_GossipInfo.SelectAvailableQuest(questInfo.questID)
                    end
                end
            end
        end
        return
    end
end)

-- Export for config to call when toggle changes
ns.QuestAutomation = {
    ApplyInteractRange = ApplyInteractRange,
}
