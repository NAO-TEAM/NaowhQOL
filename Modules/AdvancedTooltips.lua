local addonName, ns = ...

local function IsEnabled()
    return NaowhQOL.misc and NaowhQOL.misc.advancedTooltips
end

local function AddDataFields(tooltip, data)
    if not data then return end
    tooltip:AddLine(" ")
    for key, value in pairs(data) do
        if type(value) ~= "table" and key ~= "dataInstanceID" then
            if type(value) == "boolean" then
                tooltip:AddDoubleLine(key, value and "true" or "false")
            else
                tooltip:AddDoubleLine(key, value)
            end
        end
    end
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
    if IsEnabled() then AddDataFields(tooltip, data) end
end)

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tooltip, data)
    if IsEnabled() then AddDataFields(tooltip, data) end
end)

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
    if IsEnabled() then AddDataFields(tooltip, data) end
end)

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.UnitAura, function(tooltip, data)
    if IsEnabled() then AddDataFields(tooltip, data) end
end)

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Currency, function(tooltip, data)
    if IsEnabled() then AddDataFields(tooltip, data) end
end)

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Achievement, function(tooltip, data)
    if IsEnabled() then AddDataFields(tooltip, data) end
end)

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Mount, function(tooltip, data)
    if IsEnabled() then AddDataFields(tooltip, data) end
end)

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Toy, function(tooltip, data)
    if IsEnabled() then AddDataFields(tooltip, data) end
end)
