local addonName, ns = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("AUCTION_HOUSE_SHOW")

frame:SetScript("OnEvent", function(self, event)
    local db = NaowhQOL and NaowhQOL.misc
    if not db or not db.ahCurrentExpansion then return end

    C_Timer.After(0, function()
        if AuctionHouseFrame and AuctionHouseFrame.SearchBar then
            local filterBtn = AuctionHouseFrame.SearchBar.FilterButton
            if filterBtn and filterBtn.filters then
                filterBtn.filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
                AuctionHouseFrame.SearchBar:UpdateClearFiltersButton()
            end
        end
    end)
end)
