local addonName, ns = ...

-- Locale storage
local locales = {}
local currentLocale = "enUS"
local fallbackLocale = "enUS"
local missingKeys = {}

-- Create L table with metatable for key lookup
local L = setmetatable({}, {
    __index = function(self, key)
        local localeTable = locales[currentLocale]
        if localeTable and localeTable[key] then
            return localeTable[key]
        end
        -- Fallback to English
        local fallback = locales[fallbackLocale]
        if fallback and fallback[key] then
            return fallback[key]
        end
        -- Log missing key (once per key)
        if not missingKeys[key] then
            missingKeys[key] = true
            if ns.Debug then
                -- Use hardcoded string here since L is not fully initialized during metatable __index
                print("|cffff6600[NaowhQOL]|r Missing localization key: " .. tostring(key))
            end
        end
        return key
    end,
    __newindex = function() end -- Prevent direct writes
})

-- Register strings for a locale
function ns:RegisterLocale(locale, strings)
    locales[locale] = locales[locale] or {}
    for k, v in pairs(strings) do
        locales[locale][k] = v
    end
end

-- Get/set current locale
function ns:GetLocale()
    return currentLocale
end

function ns:SetLocale(locale)
    if locales[locale] then
        currentLocale = locale
        NaowhQOL.locale = locale
        return true
    end
    return false
end

-- Get available locales
function ns:GetAvailableLocales()
    local list = {}
    for locale in pairs(locales) do
        table.insert(list, locale)
    end
    return list
end

-- Debug: get missing keys
function ns:GetMissingKeys()
    return missingKeys
end

-- Export L to namespace
ns.L = L
