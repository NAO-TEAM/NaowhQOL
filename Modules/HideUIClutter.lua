local addonName, ns = ...

-- Suppresses alert popups, talking head, event toasts, and zone text.

local function GetConfig(key)
    return NaowhQOL.misc and NaowhQOL.misc[key]
end

local function SetupAlertSuppression()
    if not GetConfig("hideAlerts") then return end
    if not AlertFrame then return end

    -- Intercept the queue layer so alerts never appear, but events
    -- still fire for other addons that depend on them
    if AlertFrame.AddAlertFrame then
        hooksecurefunc(AlertFrame, "AddAlertFrame", function(self, frame)
            if frame and frame.Hide then
                frame:Hide()
            end
        end)
    end

    if AlertFrame.SetAlertFrameSubSystem then
        local original = AlertFrame.SetAlertFrameSubSystem
        hooksecurefunc(AlertFrame, "SetAlertFrameSubSystem", function(self, subsystem)
            if subsystem and subsystem.alertFramePool then
                subsystem.alertFramePool:ReleaseAll()
            end
        end)
    end
end

local talkingHeadWaitFrame

local function SetupTalkingHeadSuppression()
    if not GetConfig("hideTalkingHead") then return end

    -- TalkingHeadFrame is loaded on demand by Blizzard_TalkingHeadUI
    local function ApplyTalkingHeadHook()
        if not TalkingHeadFrame then return false end
        hooksecurefunc(TalkingHeadFrame, "Show", function(self)
            self:Hide()
        end)
        return true
    end

    if not ApplyTalkingHeadHook() then
        talkingHeadWaitFrame = CreateFrame("Frame")
        talkingHeadWaitFrame:RegisterEvent("ADDON_LOADED")
        talkingHeadWaitFrame:SetScript("OnEvent", function(self, event, name)
            if name == "Blizzard_TalkingHeadUI" then
                ApplyTalkingHeadHook()
                self:UnregisterAllEvents()
                self:SetScript("OnEvent", nil)
                talkingHeadWaitFrame = nil
            end
        end)
    end
end

local function SetupEventToastSuppression()
    if not GetConfig("hideEventToasts") then return end
    if not EventToastManagerFrame then return end

    -- Dismiss toasts as they appear, but leave ones with a close button alone
    if EventToastManagerFrame.DisplayToast then
        hooksecurefunc(EventToastManagerFrame, "DisplayToast", function(self)
            C_Timer.After(0.05, function()
                if self:IsShown() then
                    local hideBtn = self.HideButton
                    if not hideBtn or not hideBtn:IsShown() then
                        self:CloseActiveToasts()
                    end
                end
            end)
        end)
    end
end

local function SetupZoneTextSuppression()
    if not GetConfig("hideZoneText") then return end

    local framesToSuppress = { ZoneTextFrame, SubZoneTextFrame }
    for _, frame in ipairs(framesToSuppress) do
        if frame then
            frame:UnregisterAllEvents()
            frame:Hide()
            frame:SetScript("OnShow", frame.Hide)
        end
    end
end

local clutterFrame = CreateFrame("Frame", "NaowhQOL_HideUIClutter")
clutterFrame:RegisterEvent("PLAYER_LOGIN")

clutterFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        SetupAlertSuppression()
        SetupTalkingHeadSuppression()
        SetupEventToastSuppression()
        SetupZoneTextSuppression()
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

ns.HideUIClutter = clutterFrame
