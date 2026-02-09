local addonName, ns = ...

-- Spec + class cache with change callbacks

ns.SpecUtil = {}

local currentSpec = {
    index     = 0,
    name      = "",
    role      = "",
    class     = "",
    classFile = "",
}

local callbacks = {}

function ns.SpecUtil.GetCurrentSpec()
    return {
        index     = currentSpec.index,
        name      = currentSpec.name,
        role      = currentSpec.role,
        class     = currentSpec.class,
        classFile = currentSpec.classFile,
    }
end

function ns.SpecUtil.GetSpecIndex()
    return currentSpec.index
end

function ns.SpecUtil.GetSpecName()
    return currentSpec.name
end

function ns.SpecUtil.GetClassName()
    return currentSpec.classFile
end

function ns.SpecUtil.RegisterCallback(key, func)
    if type(key) == "string" and type(func) == "function" then
        callbacks[key] = func
    end
end

function ns.SpecUtil.UnregisterCallback(key)
    callbacks[key] = nil
end

local function NotifyCallbacks()
    local snapshot = ns.SpecUtil.GetCurrentSpec()
    for k, fn in pairs(callbacks) do
        local ok, err = pcall(fn, snapshot)
        if not ok then
            print("|cffff0000NaowhQOL SpecUtil:|r callback '" .. k .. "' error: " .. tostring(err))
        end
    end
end

local function PollSpecInfo()
    local specIndex = GetSpecialization()
    local localClass, classFile = UnitClass("player")

    local changed = (currentSpec.index ~= (specIndex or 0))
        or (currentSpec.classFile ~= (classFile or ""))

    currentSpec.classFile = classFile or ""
    currentSpec.class = localClass or ""

    if specIndex then
        local _, specName, _, _, role = GetSpecializationInfo(specIndex)
        currentSpec.index = specIndex
        currentSpec.name = specName or ""
        currentSpec.role = role or ""
    else
        currentSpec.index = 0
        currentSpec.name = ""
        currentSpec.role = ""
    end

    if changed then NotifyCallbacks() end
end

local eventFrame = CreateFrame("Frame", "NaowhQOL_SpecUtil")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    PollSpecInfo()
end)
