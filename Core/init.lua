local addonName, ns = ...

-- Global table so other scripts or macros can access our stuff
local Sentinel = {}
_G["Sentinel"] = Sentinel

-- Set up namespaces to keep things organized: UI for frames, Data for logic
ns.UI = {}
ns.Data = {}
Sentinel.UI = ns.UI
Sentinel.Data = ns.Data

-- Basic event frame to handle the addon startup
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, arg1)
    -- Make sure we only run this for our addon
    if arg1 ~= addonName then return end
    
    -- Load saved variables or set defaults if it's a fresh install
    SentinelDB = SentinelDB or {
        auras = {},
        config = { 
            posX = 0, 
            posY = -150, 
            iconSize = 45, 
            spacing = 4,
            unlocked = true
        }
    }
    
    -- Link the DB to our namespace so we don't have to type SentinelDB every time
    ns.DB = SentinelDB
    
    -- Quick log to know the core is up and running
    print("|cff00fbffSentinel UI:|r Core loaded. Everything looks good.")
    
    -- Done with this event, unregister to save some cycles
    self:UnregisterEvent("ADDON_LOADED")
end)