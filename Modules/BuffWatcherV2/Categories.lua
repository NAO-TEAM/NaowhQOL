local _, ns = ...

-- BuffWatcherV2 Categories Module
-- Buff category definitions and user override management

local Categories = {}
ns.BWV2Categories = Categories

local BWV2 = ns.BWV2

-- Default buff categories by type
-- Scan types: buff, weaponEnchant, buffIcon, inventory

Categories.RAID = {
    { spellID = {1459, 432778}, key = "intellect", name = "Arcane Intellect", class = "MAGE" },
    { spellID = 6673, key = "attackPower", name = "Battle Shout", class = "WARRIOR" },
    { spellID = {1126, 432661}, key = "versatility", name = "Mark of the Wild", class = "DRUID" },
    { spellID = 21562, key = "stamina", name = "Power Word: Fortitude", class = "PRIEST" },
    { spellID = 462854, key = "skyfury", name = "Skyfury", class = "SHAMAN" },
    { spellID = {381732, 381741, 381746, 381748, 381749, 381750, 381751, 381752, 381753, 381754, 381756, 381757, 381758},
      key = "bronze", name = "Blessing of the Bronze", class = "EVOKER" },
}

-- Class info with spec IDs for class-specific buff checks
Categories.CLASS_INFO = {
    WARRIOR     = { name = "Warrior",      specs = {{71, "Arms"}, {72, "Fury"}, {73, "Protection"}} },
    PALADIN     = { name = "Paladin",      specs = {{65, "Holy"}, {66, "Protection"}, {70, "Retribution"}} },
    HUNTER      = { name = "Hunter",       specs = {{253, "Beast Mastery"}, {254, "Marksmanship"}, {255, "Survival"}} },
    ROGUE       = { name = "Rogue",        specs = {{259, "Assassination"}, {260, "Outlaw"}, {261, "Subtlety"}} },
    PRIEST      = { name = "Priest",       specs = {{256, "Discipline"}, {257, "Holy"}, {258, "Shadow"}} },
    DEATHKNIGHT = { name = "Death Knight", specs = {{250, "Blood"}, {251, "Frost"}, {252, "Unholy"}} },
    SHAMAN      = { name = "Shaman",       specs = {{262, "Elemental"}, {263, "Enhancement"}, {264, "Restoration"}} },
    MAGE        = { name = "Mage",         specs = {{62, "Arcane"}, {63, "Fire"}, {64, "Frost"}} },
    WARLOCK     = { name = "Warlock",      specs = {{265, "Affliction"}, {266, "Demonology"}, {267, "Destruction"}} },
    MONK        = { name = "Monk",         specs = {{268, "Brewmaster"}, {269, "Windwalker"}, {270, "Mistweaver"}} },
    DRUID       = { name = "Druid",        specs = {{102, "Balance"}, {103, "Feral"}, {104, "Guardian"}, {105, "Restoration"}} },
    DEMONHUNTER = { name = "Demon Hunter", specs = {{577, "Havoc"}, {581, "Vengeance"}} },
    EVOKER      = { name = "Evoker",       specs = {{1467, "Devastation"}, {1468, "Preservation"}, {1473, "Augmentation"}} },
}

-- Ordered list for consistent UI display
Categories.CLASS_ORDER = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT",
    "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER"
}

-- Consumables organized by type - each group is exclusive (only one needed)
Categories.CONSUMABLE_GROUPS = {
    {
        key = "flask",
        name = "Flask",
        exclusive = true,
        spellIDs = {},
    },
    {
        key = "food",
        name = "Food",
        exclusive = true,
        checkType = "icon",
        buffIconID = 136000,
        spellIDs = {},
    },
    {
        key = "rune",
        name = "Augment Rune",
        exclusive = true,
        spellIDs = {},
    },
    {
        key = "weaponBuff",
        name = "Weapon Buff",
        exclusive = true,
        checkType = "weaponEnchant",
        spellIDs = {},
    },
}

-- Inventory items to check (player only)
-- requireClass: only check if this class is in the group (can provide the item)
Categories.INVENTORY_GROUPS = {
    {
        key = "dpsPotion",
        name = "DPS Potion",
        itemIDs = {},  -- User adds current expansion potions
    },
    {
        key = "healthPotion",
        name = "Health Potion",
        itemIDs = {},  -- User adds current expansion potions
    },
    {
        key = "healthstone",
        name = "Healthstone",
        itemIDs = {5512},  -- Classic healthstone ID is stable
        requireClass = "WARLOCK",
    },
    {
        key = "gatewayControl",
        name = "Gateway Control Shard",
        itemIDs = {188152},
    },
}


-- Exclusive groups - only ONE buff from group needed
Categories.EXCLUSIVE_GROUPS = {
    shamanImbues = true,
    shamanShields = true,
    beacons = true,
}

-- Rogue poison enchant IDs for custom check
Categories.ROGUE_UTILITY_POISONS = {8679, 381637}  -- Wound, Atrophic
Categories.ROGUE_DAMAGE_POISONS = {2823, 315584}   -- Deadly, Instant

-- Apply talent modifications to base requirements
function Categories:ApplyTalentMods(categoryKey, baseRequirements)
    local db = BWV2:GetDB()
    local mods = db.talentMods and db.talentMods[categoryKey]
    if not mods then return baseRequirements end

    local requirements = {}
    for k, v in pairs(baseRequirements) do
        requirements[k] = v
    end

    for _, rule in ipairs(mods) do
        local hasTalent = BWV2:PlayerHasTalent(rule.talentID)

        if hasTalent then
            if rule.type == "requireCount" then
                requirements.count = rule.count
            elseif rule.type == "requireSpellID" then
                requirements.spellID = rule.spellID
            elseif rule.type == "skipIfTalent" then
                requirements.skip = true
            end
        end
    end

    return requirements
end

-- Check rogue poisons (talent-aware)
function Categories:CheckRoguePoisons()
    local hasMain, _, _, mainEnchantId, hasOff, _, _, offEnchantId = GetWeaponEnchantInfo()

    -- Apply talent modifications (e.g., Dragon-Tempered Blades)
    local reqs = self:ApplyTalentMods("roguePoisons", { count = 2 })
    if reqs.skip then return nil end

    local enchantCount = 0
    if hasMain and mainEnchantId then enchantCount = enchantCount + 1 end
    if hasOff and offEnchantId then enchantCount = enchantCount + 1 end

    if enchantCount < reqs.count then
        return { missing = true, have = enchantCount, need = reqs.count }
    end
    return nil
end

-- Run custom check for specific category
function Categories:RunCustomCheck(key)
    if key == "roguePoisons" then
        return self:CheckRoguePoisons()
    end
    return nil
end

-- Get spell IDs for a category (merged with user additions)
function Categories:GetSpellIDs(categoryKey)
    local db = BWV2:GetDB()
    local userEntries = db.userEntries and db.userEntries[categoryKey]
    local userSpellIDs = userEntries and userEntries.spellIDs or {}

    -- Find the category definition
    local allCategories = {self.RAID, self.PRESENCE, self.TARGETED, self.SELF, self.CONSUMABLE_GROUPS}
    for _, catList in ipairs(allCategories) do
        if catList then
            for _, buff in ipairs(catList) do
                if buff.key == categoryKey then
                    local baseIDs = buff.spellIDs or (type(buff.spellID) == "table" and buff.spellID or {buff.spellID})
                    local merged = {}
                    for _, id in ipairs(baseIDs or {}) do
                        merged[#merged + 1] = id
                    end
                    for _, id in ipairs(userSpellIDs) do
                        merged[#merged + 1] = id
                    end
                    return merged
                end
            end
        end
    end

    return userSpellIDs
end

-- Add user spell ID to a category
function Categories:AddUserSpellID(categoryKey, spellID)
    local db = BWV2:GetDB()
    if not db.userEntries[categoryKey] then
        db.userEntries[categoryKey] = { spellIDs = {} }
    end
    table.insert(db.userEntries[categoryKey].spellIDs, spellID)
end

-- Remove user spell ID from a category
function Categories:RemoveUserSpellID(categoryKey, spellID)
    local db = BWV2:GetDB()
    local entries = db.userEntries[categoryKey]
    if not entries or not entries.spellIDs then return end

    for i, id in ipairs(entries.spellIDs) do
        if id == spellID then
            table.remove(entries.spellIDs, i)
            return
        end
    end
end

-- Check if a category is enabled
function Categories:IsCategoryEnabled(categoryKey)
    local db = BWV2:GetDB()
    if db.categoryEnabled[categoryKey] == nil then
        return true  -- Default enabled
    end
    return db.categoryEnabled[categoryKey]
end

-- Check if a consumable group is enabled (flask, food, rune, etc.)
function Categories:IsConsumableGroupEnabled(groupKey)
    local db = BWV2:GetDB()
    if not db.consumableGroupEnabled then return true end
    if db.consumableGroupEnabled[groupKey] == nil then
        return true  -- Default enabled
    end
    return db.consumableGroupEnabled[groupKey]
end

-- Check if a default spell ID is disabled by user
function Categories:IsDefaultDisabled(categoryKey, spellID)
    local db = BWV2:GetDB()
    if not db.disabledDefaults then return false end
    if not db.disabledDefaults[categoryKey] then return false end
    return db.disabledDefaults[categoryKey][spellID] == true
end

-- Get active buffs for a category (filtering out disabled defaults)
function Categories:GetActiveBuffs(categoryType, categoryKey)
    local sourceList = self[categoryType]
    if not sourceList then return {} end

    local active = {}
    for _, buff in ipairs(sourceList) do
        -- Get the primary spell ID for checking disabled status
        local primaryID = type(buff.spellID) == "table" and buff.spellID[1] or buff.spellID

        -- Skip if this default is disabled (use categoryKey from the buff or the provided one)
        local checkKey = categoryKey or buff.key
        if not primaryID or not self:IsDefaultDisabled(checkKey, primaryID) then
            active[#active + 1] = buff
        end
    end

    return active
end

-- Check if unit has a buff from a spell ID list
function Categories:UnitHasBuffFromList(unit, spellIDs, threshold)
    if type(spellIDs) ~= "table" then
        spellIDs = {spellIDs}
    end

    local now = GetTime()
    threshold = threshold or 0

    for _, spellID in ipairs(spellIDs) do
        local auraData = C_UnitAuras.GetAuraDataBySpellName(unit, spellID, "HELPFUL")
        if not auraData then
            auraData = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
        end

        if auraData then
            local remaining = (auraData.expirationTime or 0) - now
            -- No expiry (permanent) or above threshold
            if auraData.expirationTime == 0 or remaining > threshold then
                return true, remaining, auraData.sourceUnit
            end
        end
    end

    return false, 0, nil
end

-- Check if unit has a buff by icon ID (for food)
function Categories:UnitHasBuffByIcon(unit, iconID, threshold)
    local now = GetTime()
    threshold = threshold or 0

    local i = 1
    local auraData = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
    while auraData do
        if auraData.icon == iconID then
            local remaining = (auraData.expirationTime or 0) - now
            if auraData.expirationTime == 0 or remaining > threshold then
                return true, remaining
            end
        end
        i = i + 1
        auraData = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
    end

    return false, 0
end

-- Check weapon enchant by enchant ID
function Categories:HasWeaponEnchant(enchantID)
    local hasMain, _, _, mainID, hasOff, _, _, offID = GetWeaponEnchantInfo()
    if hasMain and mainID == enchantID then
        return true
    end
    if hasOff and offID == enchantID then
        return true
    end
    return false
end

-- Check if offhand slot contains an enchantable weapon (not shield/off-hand frill)
function Categories:IsOffhandEnchantable()
    local offhandID = GetInventoryItemID("player", 17)  -- INVSLOT_OFFHAND = 17
    if not offhandID then
        return false  -- No item in offhand
    end

    local _, _, _, _, _, itemType = C_Item.GetItemInfo(offhandID)
    -- itemType for weapons is "Weapon"
    return itemType == "Weapon"
end

-- Check weapon buff status with detailed error codes
-- Returns: success (bool), errorCode (string or nil)
-- Error codes: "NO_WEAPON", "MISSING_MAIN", "MISSING_OFF"
function Categories:CheckWeaponBuffStatus()
    local mainhandID = GetInventoryItemID("player", 16)  -- INVSLOT_MAINHAND

    -- Check if mainhand weapon is equipped
    if not mainhandID then
        return false, "NO_WEAPON"
    end

    local hasMain, _, _, _, hasOff, _, _, _ = GetWeaponEnchantInfo()

    -- Check mainhand enchant
    if not hasMain then
        return false, "MISSING_MAIN"
    end

    -- Check offhand if it's an enchantable weapon
    if self:IsOffhandEnchantable() and not hasOff then
        return false, "MISSING_OFF"
    end

    return true, nil
end

-- Check if player has weapon enchants on all enchantable weapons
function Categories:HasAnyWeaponEnchant()
    local success, _ = self:CheckWeaponBuffStatus()
    return success
end

-- Check inventory for item
function Categories:HasInventoryItem(itemIDs)
    if type(itemIDs) ~= "table" then
        itemIDs = {itemIDs}
    end

    for _, itemID in ipairs(itemIDs) do
        if C_Item.GetItemCount(itemID, false, true) > 0 then
            return true
        end
    end
    return false
end

-- Get total count of items from a list
function Categories:GetInventoryItemCount(itemIDs)
    if type(itemIDs) ~= "table" then
        itemIDs = {itemIDs}
    end

    local total = 0
    for _, itemID in ipairs(itemIDs) do
        total = total + C_Item.GetItemCount(itemID, false, true)
    end
    return total
end

-- Check if an inventory group is enabled (healthPotion, healthstone, etc.)
function Categories:IsInventoryGroupEnabled(groupKey)
    local db = BWV2:GetDB()
    if not db.inventoryGroupEnabled then return true end
    if db.inventoryGroupEnabled[groupKey] == nil then
        return true  -- Default enabled
    end
    return db.inventoryGroupEnabled[groupKey]
end
