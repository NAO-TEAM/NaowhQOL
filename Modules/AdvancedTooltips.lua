local addonName, ns = ...

local function IsEnabled()
    return NaowhQOL.misc and NaowhQOL.misc.advancedTooltips
end

-- Format a value for display
local function FormatValue(val)
    if val == nil then return "nil" end
    if type(val) == "boolean" then return val and "true" or "false" end
    if type(val) == "table" then return "{table}" end
    return tostring(val)
end

-- Add all data fields to tooltip
local function AddDataFields(tooltip, data, prefix)
    if not data then return end

    tooltip:AddLine(" ", 1, 1, 1)

    for key, value in pairs(data) do
        -- Skip verbose/internal keys
        if key ~= "lines" and key ~= "healthGUID" and key ~= "dataInstanceID" and key ~= "type" and key ~= "Type"
           and key ~= "isAzeriteItem" and key ~= "isAzeriteEmpoweredItem" and key ~= "isCorruptedItem"
           and type(key) == "string" then
            local displayVal = FormatValue(value)
            tooltip:AddDoubleLine(key .. ":", displayVal, 0.5, 0.8, 1, 1, 1, 1)
        end
    end

    -- For units, parse NPC ID from GUID
    if data.guid then
        local guidType, _, serverID, instanceID, zoneUID, npcID, spawnUID = strsplit("-", data.guid)
        if guidType == "Creature" or guidType == "Vehicle" then
            tooltip:AddDoubleLine("NPC ID:", npcID or "?", 0.5, 0.8, 1, 1, 1, 1)
        end
    end
end

-- Hook item tooltips
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
    if not IsEnabled() or not data then return end
    AddDataFields(tooltip, data, "Item")
end)

-- Hook spell tooltips
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tooltip, data)
    if not IsEnabled() or not data then return end
    AddDataFields(tooltip, data, "Spell")
end)

-- Hook unit tooltips
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
    if not IsEnabled() or not data then return end
    AddDataFields(tooltip, data, "Unit")
end)

-- Hook aura tooltips
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.UnitAura, function(tooltip, data)
    if not IsEnabled() or not data then return end
    AddDataFields(tooltip, data, "Aura")
end)

-- Hook currency tooltips
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Currency, function(tooltip, data)
    if not IsEnabled() or not data then return end
    AddDataFields(tooltip, data, "Currency")
end)

-- Hook achievement tooltips
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Achievement, function(tooltip, data)
    if not IsEnabled() or not data then return end
    AddDataFields(tooltip, data, "Achievement")
end)

-- Hook mount tooltips
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Mount, function(tooltip, data)
    if not IsEnabled() or not data then return end
    AddDataFields(tooltip, data, "Mount")
end)

-- Hook toy tooltips
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Toy, function(tooltip, data)
    if not IsEnabled() or not data then return end
    AddDataFields(tooltip, data, "Toy")
end)
