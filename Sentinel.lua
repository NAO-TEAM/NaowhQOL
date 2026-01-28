local addonName, ns = ...

-- this handles the final init when the player actually enters the world
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    -- check if our main frame exists before trying to link it
    if ns.MainFrame then
        -- just a welcome msg so we know the addon is alive
        print("|cff00fbffSentinel UI:|r Loaded - Type /sentinel or /sen to open config")
    else
        -- something went wrong if we get here lol
        print("|cff00fbffSentinel UI:|r Error - MainFrame not found.")
    end
end)

-- setting up the slash commands for easy access
SLASH_SENTINEL1 = "/sentinel"
SLASH_SENTINEL2 = "/sen"
SlashCmdList["SENTINEL"] = function()
    if ns.MainFrame then
        -- basic toggle logic
        if ns.MainFrame:IsShown() then 
            ns.MainFrame:Hide() 
        else 
            ns.MainFrame:Show() 
        end
    end
end