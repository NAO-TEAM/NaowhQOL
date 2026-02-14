local _, ns = ...

-- BuffWatcherV2 Scanner Module
-- Batched unit scanning and buff comparison

local Scanner = {}
ns.BWV2Scanner = Scanner

local BWV2 = ns.BWV2
local Categories = ns.BWV2Categories
local Watchers = ns.BWV2Watchers

-- Texture cache for spell and item icons
local textureCache = {}

local function GetCachedSpellTexture(spellID)
    if not spellID then return nil end
    local key = "spell_" .. spellID
    if not textureCache[key] then
        textureCache[key] = C_Spell.GetSpellTexture(spellID)
    end
    return textureCache[key]
end

local function GetCachedItemIcon(itemID)
    if not itemID then return nil end
    local key = "item_" .. itemID
    if not textureCache[key] then
        local _, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
        textureCache[key] = icon
    end
    return textureCache[key]
end

-- Find first available item from comma-separated ID string
local function FindFirstAvailableItem(itemIDString)
    if not itemIDString then return nil end
    for id in tostring(itemIDString):gmatch("%d+") do
        local itemID = tonumber(id)
        if itemID and GetItemCount(itemID) > 0 then
            return itemID
        end
    end
    return nil
end

-- Scan configuration
local BATCH_SIZE = 5
local BATCH_DELAY = 0.2  -- seconds

-- Get all valid raid/party units
function Scanner:GetRaidUnits()
    local units = {}
    local inRaid = IsInRaid()
    local groupSize = GetNumGroupMembers()

    if groupSize == 0 then
        -- Solo player
        units[1] = "player"
        return units
    end

    for i = 1, groupSize do
        local unit
        if inRaid then
            unit = "raid" .. i
        else
            unit = (i == 1) and "player" or ("party" .. (i - 1))
        end

        if UnitExists(unit) and not UnitIsDeadOrGhost(unit)
           and UnitIsConnected(unit) and UnitIsVisible(unit) then
            units[#units + 1] = unit
        end
    end

    return units
end

-- Scan all buffs on a single unit
function Scanner:ScanUnitBuffs(unit)
    local buffs = {}
    local i = 1
    local auraData = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")

    while auraData do
        buffs[auraData.spellId] = {
            expiry = auraData.expirationTime,
            icon = auraData.icon,
            name = auraData.name,
            sourceUnit = auraData.sourceUnit,
        }
        i = i + 1
        auraData = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
    end

    return buffs
end

-- Scan raid buffs category
function Scanner:ScanRaidBuffs()
    local missing = {}
    local threshold = BWV2:GetThreshold()

    -- Clear and rebuild scanResults.raidBuffs
    wipe(BWV2.scanResults.raidBuffs)

    for _, buff in ipairs(Categories.RAID) do
        -- Get primary spell ID to check if disabled
        local primaryID = type(buff.spellID) == "table" and buff.spellID[1] or buff.spellID

        if not Categories:IsCategoryEnabled(buff.key) then
            -- Skip disabled categories
        elseif primaryID and Categories:IsDefaultDisabled("raidBuffs", primaryID) then
            -- Skip user-disabled defaults
        elseif not BWV2:HasClassInGroup(buff.class) then
            -- No caster for this buff, skip
        else
            local covered = 0
            local total = 0

            for unit, data in pairs(BWV2.raidResults) do
                total = total + 1
                local spellIDs = type(buff.spellID) == "table" and buff.spellID or {buff.spellID}

                for _, spellID in ipairs(spellIDs) do
                    if data.buffs[spellID] then
                        local remaining = (data.buffs[spellID].expiry or 0) - GetTime()
                        if data.buffs[spellID].expiry == 0 or remaining > threshold then
                            covered = covered + 1
                            break
                        end
                    end
                end
            end

            -- Get icon for report card (cached)
            local icon = GetCachedSpellTexture(primaryID)
            local pass = (covered >= total)

            -- Add to scanResults for report card
            BWV2.scanResults.raidBuffs[#BWV2.scanResults.raidBuffs + 1] = {
                key = buff.key,
                name = buff.name,
                spellID = primaryID,
                icon = icon,
                pass = pass,
                covered = covered,
                total = total,
                class = buff.class,
            }

            if not pass then
                missing[buff.key] = {
                    name = buff.name,
                    missing = total - covered,
                    total = total,
                    class = buff.class,
                }
            end
        end
    end

    return missing
end

-- Scan presence buffs category (anyone has it)
function Scanner:ScanPresenceBuffs()
    local missing = {}

    for _, buff in ipairs(Categories.PRESENCE) do
        -- Get primary spell ID to check if disabled
        local primaryID = type(buff.spellID) == "table" and buff.spellID[1] or buff.spellID

        if not Categories:IsCategoryEnabled(buff.key) then
            -- Skip disabled
        elseif primaryID and Categories:IsDefaultDisabled("presenceBuffs", primaryID) then
            -- Skip user-disabled defaults
        elseif not BWV2:HasClassInGroup(buff.class) then
            -- No caster
        else
            local found = false
            local spellIDs = type(buff.spellID) == "table" and buff.spellID or {buff.spellID}

            for unit, data in pairs(BWV2.raidResults) do
                for _, spellID in ipairs(spellIDs) do
                    if data.buffs[spellID] then
                        found = true
                        break
                    end
                end
                if found then break end
            end

            if not found then
                missing[buff.key] = {
                    name = buff.name,
                    class = buff.class,
                }
            end
        end
    end

    return missing
end

-- Helper: Check if player has any of the given spell IDs as a self buff
function Scanner:CheckSelfBuffSpells(spellIDs, minRequired)
    local playerBuffs = BWV2.raidResults["player"] and BWV2.raidResults["player"].buffs or {}

    local count = 0
    for _, spellID in ipairs(spellIDs) do
        if playerBuffs[spellID] then
            count = count + 1
        end
    end

    -- minRequired: 0 = all spells required, 1+ = at least N spells must be active
    local needed = (minRequired == 0) and #spellIDs or minRequired
    return count >= needed
end

-- Helper: Check if player has cast any of the given spell IDs on someone in the raid
function Scanner:CheckTargetedBuffSpells(spellIDs)
    for unit, data in pairs(BWV2.raidResults) do
        for _, spellID in ipairs(spellIDs) do
            local buffData = data.buffs[spellID]
            if buffData and buffData.sourceUnit and UnitIsUnit(buffData.sourceUnit, "player") then
                return true
            end
        end
    end
    return false
end

-- Helper: Check if player has any of the given weapon enchant IDs
function Scanner:CheckWeaponEnchantIDs(enchantIDs, minRequired)
    local hasMain, _, _, mainID, hasOff, _, _, offID = GetWeaponEnchantInfo()

    local count = 0
    for _, enchantID in ipairs(enchantIDs) do
        if (hasMain and mainID == enchantID) or (hasOff and offID == enchantID) then
            count = count + 1
        end
    end

    -- minRequired: 0 = all enchants required, 1+ = at least N enchants must be active
    local needed = (minRequired == 0) and #enchantIDs or minRequired
    return count >= needed
end

-- Scan class-specific buff groups (user-defined)
function Scanner:ScanClassBuffs()
    local missing = {}
    local _, playerClass = UnitClass("player")
    local playerSpecID = BWV2:GetPlayerSpecID()
    local db = BWV2:GetDB()

    -- Clear and rebuild scanResults.classBuffs
    wipe(BWV2.scanResults.classBuffs)

    local classData = db.classBuffs and db.classBuffs[playerClass]
    if not classData or not classData.enabled then
        return missing
    end

    local playerBuffs = BWV2.raidResults["player"] and BWV2.raidResults["player"].buffs or {}

    for _, group in ipairs(classData.groups or {}) do
        local shouldCheck = true

        -- Check spec filter (empty = all specs)
        if group.specFilter and #group.specFilter > 0 then
            local specMatch = false
            for _, specID in ipairs(group.specFilter) do
                if specID == playerSpecID then
                    specMatch = true
                    break
                end
            end
            if not specMatch then
                shouldCheck = false
            end
        end

        -- Check talent condition
        if shouldCheck and group.talentCondition then
            local hasTalent = BWV2:PlayerHasTalent(group.talentCondition.talentID)
            if group.talentCondition.mode == "activate" then
                -- Only check if player has the talent
                if not hasTalent then
                    shouldCheck = false
                end
            elseif group.talentCondition.mode == "skip" then
                -- Skip this check if player has the talent
                if hasTalent then
                    shouldCheck = false
                end
            end
        end

        if shouldCheck then
            local hasBuff = false
            local foundSpellID = nil
            local foundIcon = nil

            if group.checkType == "self" then
                local spellIDs = group.spellIDs or {}
                if #spellIDs > 0 then
                    hasBuff = self:CheckSelfBuffSpells(spellIDs, group.minRequired or 1)
                    -- Find which spell is active for icon
                    for _, spellID in ipairs(spellIDs) do
                        if playerBuffs[spellID] then
                            foundSpellID = spellID
                            foundIcon = playerBuffs[spellID].icon or GetCachedSpellTexture(spellID)
                            break
                        end
                    end
                    -- Default to first spell icon if none found
                    if not foundIcon and spellIDs[1] then
                        foundSpellID = spellIDs[1]
                        foundIcon = GetCachedSpellTexture(spellIDs[1])
                    end
                end
            elseif group.checkType == "targeted" then
                local spellIDs = group.spellIDs or {}
                if #spellIDs > 0 then
                    hasBuff = self:CheckTargetedBuffSpells(spellIDs)
                    -- Find which spell is active
                    for unit, data in pairs(BWV2.raidResults) do
                        for _, spellID in ipairs(spellIDs) do
                            local buffData = data.buffs[spellID]
                            if buffData and buffData.sourceUnit and UnitIsUnit(buffData.sourceUnit, "player") then
                                foundSpellID = spellID
                                foundIcon = buffData.icon or GetCachedSpellTexture(spellID)
                                break
                            end
                        end
                        if foundIcon then break end
                    end
                    -- Default to first spell icon
                    if not foundIcon and spellIDs[1] then
                        foundSpellID = spellIDs[1]
                        foundIcon = GetCachedSpellTexture(spellIDs[1])
                    end
                end
            elseif group.checkType == "weaponEnchant" then
                local enchantIDs = group.enchantIDs or {}
                if #enchantIDs > 0 then
                    hasBuff = self:CheckWeaponEnchantIDs(enchantIDs, group.minRequired or 1)
                    -- Use a generic weapon enchant icon
                    foundIcon = 136241
                end
            end

            -- Add to scanResults for report card
            BWV2.scanResults.classBuffs[#BWV2.scanResults.classBuffs + 1] = {
                key = group.key,
                name = group.name,
                spellID = foundSpellID,
                icon = foundIcon,
                pass = hasBuff,
                checkType = group.checkType,
            }

            if not hasBuff then
                missing[group.key] = {
                    name = group.name,
                    checkType = group.checkType,
                    className = playerClass,
                }
            end
        end
    end

    return missing
end

-- Scan consumables (player only)
function Scanner:ScanConsumables()
    local missing = {}
    local threshold = BWV2:GetThreshold()
    local playerBuffs = BWV2.raidResults["player"] and BWV2.raidResults["player"].buffs or {}
    local db = BWV2:GetDB()

    -- Clear and rebuild scanResults.consumables
    wipe(BWV2.scanResults.consumables)

    for _, buff in ipairs(Categories.CONSUMABLE) do
        -- Get primary spell ID to check if disabled
        local primaryID = type(buff.spellID) == "table" and buff.spellID[1] or buff.spellID

        -- Check if this consumable group is enabled
        if not Categories:IsConsumableGroupEnabled(buff.key) then
            -- Group disabled by user (e.g., augment runes disabled)
        elseif not Categories:IsCategoryEnabled(buff.key) then
            -- Category disabled
        elseif primaryID and Categories:IsDefaultDisabled("consumable_" .. buff.key, primaryID) then
            -- Skip user-disabled defaults (note: uses consumable_ prefix for groupKey)
        else
            -- Check exclusion spells (e.g., skip weapon oils for shamans)
            local skip = false
            if buff.excludeIfSpellKnown then
                for _, spellID in ipairs(buff.excludeIfSpellKnown) do
                    if IsPlayerSpell(spellID) then
                        skip = true
                        break
                    end
                end
            end

            if not skip then
                local hasBuff = false
                local foundSpellID = nil
                local foundIcon = nil
                local remaining = 0

                -- Icon-based check (food)
                if buff.buffIconID then
                    for spellID, data in pairs(playerBuffs) do
                        if data.icon == buff.buffIconID then
                            remaining = (data.expiry or 0) - GetTime()
                            if data.expiry == 0 or remaining > threshold then
                                hasBuff = true
                                foundSpellID = spellID
                                foundIcon = data.icon
                                break
                            elseif data.expiry ~= 0 then
                                -- Below threshold but has buff - store for duration display
                                foundSpellID = spellID
                                foundIcon = data.icon
                            end
                        end
                    end
                -- Weapon enchant check (with detailed status)
                elseif buff.checkWeaponEnchant then
                    local success, errorCode = Categories:CheckWeaponBuffStatus()
                    if not success then
                        local errorNames = {
                            NO_WEAPON = "No Weapon Equipped",
                            MISSING_MAIN = "Mainhand Missing Enchant",
                            MISSING_OFF = "Offhand Missing Enchant",
                        }
                        missing[buff.key] = {
                            name = errorNames[errorCode] or buff.name,
                            readyCheckOnly = buff.readyCheckOnly,
                            errorCode = errorCode,
                        }
                    end
                    hasBuff = success
                    -- Use a generic weapon icon
                    foundIcon = 136241  -- Weapon enchant icon
                -- Inventory check (healthstone)
                elseif buff.itemID then
                    local itemIDs = type(buff.itemID) == "table" and buff.itemID or {buff.itemID}
                    hasBuff = Categories:HasInventoryItem(itemIDs)
                    foundIcon = GetCachedItemIcon(itemIDs[1])
                -- Normal spell check
                elseif buff.spellID then
                    local spellIDs = type(buff.spellID) == "table" and buff.spellID or {buff.spellID}
                    for _, spellID in ipairs(spellIDs) do
                        if playerBuffs[spellID] then
                            remaining = (playerBuffs[spellID].expiry or 0) - GetTime()
                            if playerBuffs[spellID].expiry == 0 or remaining > threshold then
                                hasBuff = true
                                foundSpellID = spellID
                                foundIcon = playerBuffs[spellID].icon or GetCachedSpellTexture(spellID)
                                break
                            elseif playerBuffs[spellID].expiry ~= 0 then
                                -- Below threshold but has buff
                                foundSpellID = spellID
                                foundIcon = playerBuffs[spellID].icon or GetCachedSpellTexture(spellID)
                            end
                        end
                    end
                    -- If no buff found, use first spell's icon
                    if not foundIcon and spellIDs[1] then
                        foundIcon = GetCachedSpellTexture(spellIDs[1])
                    end
                end

                -- Add to scanResults for report card
                -- Find first available item from comma-separated list (for click-to-use)
                local autoUseItemID = FindFirstAvailableItem(db.consumableAutoUse and db.consumableAutoUse[buff.key])
                BWV2.scanResults.consumables[#BWV2.scanResults.consumables + 1] = {
                    key = buff.key,
                    name = buff.name,
                    spellID = foundSpellID or primaryID,
                    itemID = autoUseItemID,
                    icon = foundIcon or GetCachedSpellTexture(primaryID),
                    pass = hasBuff,
                    remaining = (not hasBuff and remaining > 0) and remaining or nil,
                }

                -- Only add to missing if not already added (weapon check adds directly)
                if not hasBuff and not missing[buff.key] then
                    missing[buff.key] = {
                        name = buff.name,
                        readyCheckOnly = buff.readyCheckOnly,
                    }
                end
            end
        end
    end

    return missing
end

-- Scan inventory items (player only)
-- Returns: missing table, inventory table (with counts for passes)
function Scanner:ScanInventory()
    local missing = {}
    local inventory = {}
    local db = BWV2:GetDB()

    -- Clear and rebuild scanResults.inventory
    wipe(BWV2.scanResults.inventory)

    for _, group in ipairs(Categories.INVENTORY_GROUPS) do
        local groupKey = "inventory_" .. group.key

        -- Check if this inventory group is enabled
        if not Categories:IsInventoryGroupEnabled(group.key) then
            -- Group disabled by user
        elseif group.requireClass and not BWV2:HasClassInGroup(group.requireClass) then
            -- Required class not in group (e.g., no warlock for healthstone)
        else
            -- Build list of item IDs (defaults + user added, minus disabled)
            local itemIDs = {}
            local disabledDefaults = db.disabledDefaults and db.disabledDefaults[groupKey] or {}

            -- Add default items (skip disabled)
            for _, itemID in ipairs(group.itemIDs or {}) do
                if not disabledDefaults[itemID] then
                    itemIDs[#itemIDs + 1] = itemID
                end
            end

            -- Add user items
            local userEntries = db.userEntries and db.userEntries[groupKey]
            if userEntries and userEntries.itemIDs then
                for _, itemID in ipairs(userEntries.itemIDs) do
                    itemIDs[#itemIDs + 1] = itemID
                end
            end

            local count = Categories:GetInventoryItemCount(itemIDs)
            local pass = count > 0

            -- Get icon from first item (cached)
            local icon = GetCachedItemIcon(itemIDs[1])

            -- Add to scanResults for report card
            BWV2.scanResults.inventory[#BWV2.scanResults.inventory + 1] = {
                key = group.key,
                name = group.name,
                itemID = itemIDs[1],
                icon = icon,
                pass = pass,
                count = count,
                requireClass = group.requireClass,
            }

            if pass then
                inventory[group.key] = {
                    name = group.name,
                    count = count,
                    pass = true,
                }
            else
                missing[group.key] = {
                    name = group.name,
                    requireClass = group.requireClass,
                }
            end
        end
    end

    return missing, inventory
end

-- Scan a single unit and compare against requirements
function Scanner:ScanAndCompareUnit(unit)
    local buffs = self:ScanUnitBuffs(unit)
    BWV2.raidResults[unit] = { buffs = buffs }
end

-- Process a batch of units
local function ScanBatch(batch, onComplete)
    for _, unit in ipairs(batch) do
        Scanner:ScanAndCompareUnit(unit)
    end

    if onComplete then
        onComplete()
    end
end

-- Start batched scan of all raid members
function Scanner:StartBatchedScan(onAllComplete)
    local units = self:GetRaidUnits()

    -- Reset state and watchers
    Watchers:RemoveAllWatchers()
    BWV2:ResetState()

    local totalBatches = math.ceil(#units / BATCH_SIZE)
    local completedBatches = 0

    if #units == 0 then
        if onAllComplete then onAllComplete() end
        return
    end

    for batchStart = 1, #units, BATCH_SIZE do
        local batch = {}
        for i = batchStart, math.min(batchStart + BATCH_SIZE - 1, #units) do
            batch[#batch + 1] = units[i]
        end

        local delay = ((batchStart - 1) / BATCH_SIZE) * BATCH_DELAY

        C_Timer.After(delay, function()
            ScanBatch(batch, function()
                completedBatches = completedBatches + 1
                if completedBatches >= totalBatches then
                    -- All batches done, run category scans
                    self:RunCategoryScans()
                    if onAllComplete then
                        onAllComplete()
                    end
                end
            end)
        end)
    end
end

-- Run all category scans after unit data collected
function Scanner:RunCategoryScans()
    local allMissing = {}

    -- Raid buffs (coverage check)
    local raidMissing = self:ScanRaidBuffs()
    for key, data in pairs(raidMissing) do
        allMissing[key] = data
    end

    -- Class-specific buffs (user-defined groups)
    local classBuffMissing = self:ScanClassBuffs()
    for key, data in pairs(classBuffMissing) do
        allMissing[key] = data
    end

    -- Consumables
    local consumableMissing = self:ScanConsumables()
    for key, data in pairs(consumableMissing) do
        allMissing[key] = data
    end

    -- Inventory items (player only)
    local inventoryMissing, inventoryStatus = self:ScanInventory()
    for key, data in pairs(inventoryMissing) do
        allMissing[key] = data
    end

    -- Store results
    BWV2.missingByCategory = allMissing
    BWV2.inventoryStatus = inventoryStatus

    -- Set up watchers for player if they have missing buffs
    if next(classBuffMissing) or next(consumableMissing) then
        Watchers:SetupWatcher("player")
    end
end

-- Re-scan a single unit (called from watcher callback)
function Scanner:RescanUnit(unit)
    self:ScanAndCompareUnit(unit)
    self:RunCategoryScans()
end
