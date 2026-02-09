local addonName, ns = ...

-- Speeds up looting by immediately collecting all items when the
-- loot window opens, bypassing the default animation.

local lastLootTime = 0

local function IsEnabled()
    return NaowhQOL.misc and NaowhQOL.misc.fasterLoot
end

local function ShouldAutoLoot()
    local autoLootOn = GetCVarBool("autoLootDefault")
    local modifierHeld = IsModifiedClick("AUTOLOOTTOGGLE")
    -- Toggle behavior: auto-loot when setting XOR modifier
    if autoLootOn then
        return not modifierHeld
    else
        return modifierHeld
    end
end

local function CollectLoot()
    if not IsEnabled() then return end
    if not ShouldAutoLoot() then return end

    local throttle = 0.2
    local now = GetTime()
    if now - lastLootTime < throttle then return end
    lastLootTime = now

    -- Skip if cursor already holds something (TSM destroy, etc)
    if GetCursorInfo() then return end

    local slotCount = GetNumLootItems()
    for i = 1, slotCount do
        LootSlot(i)
    end
end

local lootFrame = CreateFrame("Frame", "NaowhQOL_FasterLoot")
lootFrame:RegisterEvent("PLAYER_LOGIN")

lootFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        if IsEnabled() then
            self:RegisterEvent("LOOT_READY")
        end
        self:UnregisterEvent("PLAYER_LOGIN")
        return
    end

    if event == "LOOT_READY" then
        CollectLoot()
    end
end)

ns.FasterLoot = lootFrame
