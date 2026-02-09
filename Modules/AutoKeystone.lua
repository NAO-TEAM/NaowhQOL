local addonName, ns = ...

---------------------------------------------------------------------------
-- Find and place the keystone from bags onto the cursor, then slot it
---------------------------------------------------------------------------
local function TrySlotKeystone()
    local reagentType = Enum.ItemClass.Reagent
    local keystoneType = Enum.ItemReagentSubclass.Keystone

    for bag = 0, (NUM_BAG_FRAMES or 4) do
        local slots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, slots do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if itemID then
                local _, _, _, _, _, _, _, _, _, _, _, itemClass, itemSub = C_Item.GetItemInfo(itemID)
                if itemClass == reagentType and itemSub == keystoneType then
                    C_Container.PickupContainerItem(bag, slot)
                    if C_Cursor.GetCursorItem() then
                        C_ChallengeMode.SlotKeystone()
                        return
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Wait for the Blizzard M+ UI to load, then hook the keystone frame
---------------------------------------------------------------------------
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")

watcher:SetScript("OnEvent", function(self, event, loaded)
    if loaded ~= "Blizzard_ChallengesUI" then return end
    self:UnregisterEvent("ADDON_LOADED")

    local keystoneUI = ChallengesKeystoneFrame
    if not keystoneUI then return end

    keystoneUI:HookScript("OnShow", function()
        local db = NaowhQOL.misc
        if not db or not db.autoSlotKeystone then return end
        if C_ChallengeMode.HasSlottedKeystone() then return end
        TrySlotKeystone()
    end)
end)
