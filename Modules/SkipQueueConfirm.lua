local addonName, ns = ...

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")

loader:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")

    local dialog = LFGListApplicationDialog
    if not dialog then return end

    dialog:HookScript("OnShow", function(dlg)
        local db = NaowhQOL.misc
        if not db or not db.skipQueueConfirm then return end

        -- Hold Ctrl to keep the dialog visible
        if IsControlKeyDown() then return end

        local confirmBtn = dlg.SignUpButton
        if confirmBtn and confirmBtn:IsEnabled() then
            confirmBtn:Click()
        end
    end)
end)
