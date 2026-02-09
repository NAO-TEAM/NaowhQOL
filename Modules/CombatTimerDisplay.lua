local addonName, ns = ...
local L = ns.L
local W = ns.Widgets

local timerFrame = CreateFrame("Frame", "NaowhQOL_CombatTimerDisplay", UIParent, "BackdropTemplate")
timerFrame:SetSize(400, 100)
timerFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
timerFrame:Hide()

local timerText = timerFrame:CreateFontString(nil, "OVERLAY")
timerText:SetPoint("CENTER", timerFrame, "CENTER", 0, 0)
timerText:SetJustifyH("CENTER")
timerText:SetJustifyV("MIDDLE")
timerText:SetWordWrap(false)
timerText:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", 32, "OUTLINE")
timerText:SetText("COMBAT: 0:00")

local resizeHandle
local combatStartTime = 0
local inCombat = false
local lastCombatDuration = 0

-- Cached db reference to avoid repeated lookups in OnUpdate
local cachedDb = nil
local function GetCachedDb()
    if not cachedDb then
        cachedDb = NaowhQOL and NaowhQOL.combatTimer
    end
    return cachedDb
end

local function InvalidateDbCache()
    cachedDb = nil
end


function timerFrame:UpdateTextSize()
    local db = NaowhQOL.combatTimer
    if not db then return end

    local frameWidth = timerFrame:GetWidth()
    local frameHeight = timerFrame:GetHeight()

    local currentText = timerText:GetText() or "COMBAT: 0:00"
    local textLength = string.len(currentText)

    local fontSizeFromHeight = math.floor(frameHeight * 0.35)

    local usableWidth = frameWidth * 0.85
    local estimatedCharWidth = 0.55
    local maxFontSizeFromWidth = math.floor(usableWidth / (textLength * estimatedCharWidth))

    local scaledFontSize = math.min(fontSizeFromHeight, maxFontSizeFromWidth)

    scaledFontSize = math.max(10, math.min(72, scaledFontSize))

    local fontPath = db.font or "Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf"

    local success = timerText:SetFont(fontPath, scaledFontSize, "OUTLINE")

    if not success then
        timerText:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", scaledFontSize, "OUTLINE")
    end
end


function timerFrame:UpdateDisplay()
    local db = NaowhQOL.combatTimer
    if not db then return end

    if not db.enabled then
        timerFrame:SetBackdrop(nil)
        if resizeHandle then resizeHandle:Hide() end
        timerFrame:Hide()
        return
    end

    timerFrame:EnableMouse(db.unlock)
    if db.unlock then
        timerFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        timerFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        timerFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        if resizeHandle then resizeHandle:Show() end

        timerFrame:Show()
    else
        timerFrame:SetBackdrop(nil)
        if resizeHandle then resizeHandle:Hide() end

        if not inCombat and not db.stickyTimer then
            timerFrame:Hide()
        end
    end

    if not timerFrame.initialized then
        timerFrame:ClearAllPoints()
        local point = db.point or "CENTER"
        local x = db.x or 0
        local y = db.y or -200
        timerFrame:SetPoint(point, UIParent, point, x, y)

        local width = db.width or 400
        local height = db.height or 100
        timerFrame:SetSize(width, height)

        timerFrame.initialized = true
    end

    timerText:SetTextColor(db.colorR or 1, db.colorG or 0.66, db.colorB or 0)

    local elapsed
    if inCombat then
        elapsed = GetTime() - combatStartTime
    elseif db.stickyTimer and lastCombatDuration > 0 then
        elapsed = lastCombatDuration
    else
        elapsed = 0
    end
    local minutes = math.floor(elapsed / 60)
    local seconds = math.floor(elapsed % 60)

    -- Optimized string formatting: avoid gsub chains
    local text
    local timeStr = string.format("%d:%02d", minutes, seconds)
    if db.hidePrefix then
        text = timeStr
    elseif db.combatText then
        -- Only use gsub if custom format is set
        text = db.combatText:gsub("{m}", minutes):gsub("{s}", string.format("%02d", seconds))
    else
        text = "COMBAT: " .. timeStr
    end

    timerText:SetText(text)

    self:UpdateTextSize()

    timerText:Show()
end

local acc = 0
timerFrame:SetScript("OnUpdate", ns.PerfMonitor:Wrap("Combat Timer", function(self, elapsed)
    acc = acc + elapsed
    if acc >= 1 then
        acc = 0
        local db = GetCachedDb()
        if inCombat or (db and db.unlock) or (db and db.stickyTimer and lastCombatDuration > 0) then
            self:UpdateDisplay()
        end
    end
end))


local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_REGEN_DISABLED")
loader:RegisterEvent("PLAYER_REGEN_ENABLED")

loader:SetScript("OnEvent", function(self, event)
    local db = NaowhQOL.combatTimer
    if not db then return end

    if event == "PLAYER_LOGIN" then
        -- Initialize db cache
        InvalidateDbCache()

        db.width = db.width or 400
        db.height = db.height or 100
        db.point = db.point or "CENTER"
        db.x = db.x or 0
        db.y = db.y or -200

        W.MakeDraggable(timerFrame, { db = db })
        resizeHandle = W.CreateResizeHandle(timerFrame, {
            db = db,
            onResize = function() timerFrame:UpdateTextSize() end,
        })

        timerFrame.initialized = false
        timerFrame:UpdateDisplay()

        if db.enabled and db.unlock then
            timerFrame:Show()
        end

    elseif event == "PLAYER_REGEN_DISABLED" and db.enabled then
        -- Check instance restriction
        if db.instanceOnly then
            local inInstance, instanceType = IsInInstance()
            if not inInstance or instanceType == "none" then
                return
            end
        end
        inCombat = true
        combatStartTime = GetTime()
        timerFrame:Show()
        timerFrame:UpdateDisplay()

    elseif event == "PLAYER_REGEN_ENABLED" then
        if inCombat then
            local duration = GetTime() - combatStartTime
            lastCombatDuration = duration

            if db.chatReport ~= false then
                local h = math.floor(duration / 3600)
                local m = math.floor((duration % 3600) / 60)
                local s = math.floor(duration % 60)

                local timeText
                if h > 0 then
                    timeText = string.format("%d:%02d:%02d hours", h, m, s)
                elseif m > 0 then
                    timeText = string.format("%d:%02d minutes", m, s)
                else
                    timeText = string.format("%d seconds", duration)
                end

                print("|cff018ee7Naowh QOL:|r " .. L["COMBATTIMER_CHAT_MSG"] .. " |cffffa900" .. timeText .. "|r")
            end
        end

        inCombat = false
        if not db.unlock and not db.stickyTimer then
            timerFrame:Hide()
        elseif db.stickyTimer and lastCombatDuration > 0 then
            timerFrame:UpdateDisplay()
        end
    end
end)


ns.CombatTimerDisplay = timerFrame

-- Export function to invalidate db cache when settings change
function timerFrame:RefreshSettings()
    InvalidateDbCache()
    self:UpdateDisplay()
end
