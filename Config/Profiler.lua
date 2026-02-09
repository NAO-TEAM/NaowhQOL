local addonName, ns = ...
ns.Profiler = {}

local W = ns.Widgets

local COLORS = {
    BLUE = "018ee7",
    ORANGE = "ffa900",
    SUCCESS = "00ff00",
    GREEN = "00ff00",
    RED = "ff0000",
    GRAY = "aaaaaa",
}

local function ColorizeText(text, color)
    return "|cff" .. color .. text .. "|r"
end

local isPaused = false

local p = CreateFrame("Frame", "NaowhQOLProfilerFrame", UIParent, "BackdropTemplate")
p:SetSize(500, 260)
p:SetPoint("CENTER")
p:SetFrameStrata("DIALOG")
p:SetClampedToScreen(true)
p:SetMovable(true)
p:SetResizable(true)

if p.SetResizeBounds then p:SetResizeBounds(450, 200, 750, 800) else p:SetMinResize(450, 200) end


p:EnableMouse(true)
p:RegisterForDrag("LeftButton")
p:SetScript("OnDragStart", p.StartMoving)
p:SetScript("OnDragStop", p.StopMovingOrSizing)

p:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
p:SetBackdropColor(0, 0, 0, 0.95)
p:Hide()


local titleText = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titleText:SetPoint("TOPLEFT", 12, -10)
titleText:SetText(ColorizeText("ADDON ", COLORS.BLUE) .. ColorizeText("PROFILER", COLORS.ORANGE))

local nameHeader = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
nameHeader:SetPoint("TOPLEFT", 12, -44)
nameHeader:SetText(ColorizeText("ADDON NAME", COLORS.BLUE))

-- Primera fila de encabezados (labels principales)
local avgHeader1 = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
avgHeader1:SetPoint("TOPRIGHT", p, "TOPRIGHT", -185, -30)
avgHeader1:SetText(ColorizeText("CPU AVG", COLORS.ORANGE))

local peakHeader1 = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
peakHeader1:SetPoint("TOPRIGHT", p, "TOPRIGHT", -95, -30)
peakHeader1:SetText(ColorizeText("CPU MAX", COLORS.ORANGE))

local ramHeader1 = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ramHeader1:SetPoint("TOPRIGHT", p, "TOPRIGHT", -15, -30) 
ramHeader1:SetText(ColorizeText("RAM", COLORS.GRAY))

-- Segunda fila de encabezados (unidades)
local avgHeader2 = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
avgHeader2:SetPoint("TOPRIGHT", p, "TOPRIGHT", -185, -44)
avgHeader2:SetText(ColorizeText("(ms)", COLORS.ORANGE))

local peakHeader2 = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
peakHeader2:SetPoint("TOPRIGHT", p, "TOPRIGHT", -95, -44)
peakHeader2:SetText(ColorizeText("(ms)", COLORS.ORANGE))

local ramHeader2 = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ramHeader2:SetPoint("TOPRIGHT", p, "TOPRIGHT", -15, -44) 
ramHeader2:SetText(ColorizeText("(MB)", COLORS.GRAY))

local sep = p:CreateTexture(nil, "ARTWORK")
sep:SetColorTexture(0.00, 0.56, 0.91, 0.4)
sep:SetSize(476, 1)
sep:SetPoint("TOPLEFT", 12, -60)


local scrollFrame = CreateFrame("ScrollFrame", "NaowhQOLScrollFrame", p, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 10, -66)
scrollFrame:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -30, 45)

local scrollChild = CreateFrame("Frame", nil, scrollFrame)
scrollChild:SetSize(450, 1)
scrollFrame:SetScrollChild(scrollChild)


local rows = {}
for i = 1, 40 do
    local row = CreateFrame("Frame", nil, scrollChild)
    row:SetHeight(18)
    row:SetPoint("LEFT", scrollChild, "LEFT", 0, 0)
    row:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)
    row:SetPoint("TOP", scrollChild, "TOP", 0, -(i-1) * 18)
    
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", 5, 0)
    row.name:SetWidth(210)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    
    row.avg = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.avg:SetPoint("RIGHT", row, "RIGHT", -165, 0)
    row.avg:SetJustifyH("RIGHT")
    row.avg:SetWidth(60)
    
    row.peak = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.peak:SetPoint("RIGHT", row, "RIGHT", -80, 0)
    row.peak:SetJustifyH("RIGHT")
    row.peak:SetWidth(60)
    
    row.mem = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.mem:SetPoint("RIGHT", row, "RIGHT", -5, 0)
    row.mem:SetJustifyH("RIGHT")
    row.mem:SetWidth(55)
    
    rows[i] = row
end


p:SetScript("OnSizeChanged", function(self, width, height)
    scrollChild:SetWidth(scrollFrame:GetWidth()) 
end)


local resetBtn = W:CreateButton(p, {
    text = ColorizeText("Reset", COLORS.ORANGE),
    width = 80,
    height = 22,
    onClick = function()
        ResetCPUUsage()
        UpdateAddOnCPUUsage()
        UpdateAddOnMemoryUsage()
        print(ColorizeText("Addon Profiler:", COLORS.BLUE) .. " " .. ColorizeText("Statistics reset", COLORS.ORANGE))
    end
})
resetBtn:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 12, 12)

local purgeBtn = W:CreateButton(p, {
    text = ColorizeText("Purge ", COLORS.ORANGE) .. ColorizeText("RAM", COLORS.BLUE),
    width = 100,
    height = 22,
    onClick = function()
        UpdateAddOnMemoryUsage()
        local memBefore = collectgarbage("count")

        collectgarbage("collect")
        collectgarbage("collect")

        UpdateAddOnMemoryUsage()
        local memAfter = collectgarbage("count")
        local freed = (memBefore - memAfter) / 1024

        p.timer = 2

        DEFAULT_CHAT_FRAME:AddMessage(ColorizeText("Naowh QOL:", COLORS.BLUE) .. " Global RAM purge complete. Freed: " ..
            ColorizeText(string.format("%.2f MB", freed), COLORS.SUCCESS))
    end
})
purgeBtn:SetPoint("LEFT", resetBtn, "RIGHT", 5, 0)

local pauseBtn = W:CreateButton(p, {
    text = ColorizeText("Pause", COLORS.GREEN),
    width = 80,
    height = 22,
    onClick = function(self)
        isPaused = not isPaused
        if isPaused then
            self:SetText(ColorizeText("Resume", COLORS.ORANGE))
            print(ColorizeText("Addon Profiler:", COLORS.BLUE) .. " " .. ColorizeText("Paused", COLORS.ORANGE))
        else
            self:SetText(ColorizeText("Pause", COLORS.GREEN))
            p.timer = 2
            print(ColorizeText("Addon Profiler:", COLORS.BLUE) .. " " .. ColorizeText("Resumed", COLORS.GREEN))
        end
    end
})
pauseBtn:SetPoint("LEFT", purgeBtn, "RIGHT", 5, 0)

local stopBtn = W:CreateButton(p, {
    text = ColorizeText("Stop", COLORS.RED) .. " Profiling",
    width = 100,
    height = 22,
    onClick = function()
        SetCVar("scriptProfile", "0")
        p.manualStop = true
        p:Hide()
        StaticPopup_Show("NAOWH_PROFILER_DISABLE")
    end
})
stopBtn:SetPoint("LEFT", pauseBtn, "RIGHT", 5, 0)

local function EnsureProfilingEnabled()
    if not GetCVarBool("scriptProfile") then
        SetCVar("scriptProfile", "1")
        ReloadUI()
    end
end

p:SetScript("OnShow", function()
    EnsureProfilingEnabled()
end)

p:SetScript("OnHide", function(self)
    if self.manualStop then
        self.manualStop = nil
        return
    end
    if GetCVarBool("scriptProfile") then
        SetCVar("scriptProfile", "0")
        StaticPopup_Show("NAOWH_PROFILER_DISABLE")
    end
end)

p:SetScript("OnUpdate", function(self, elapsed)
    if isPaused then return end
    
    self.timer = (self.timer or 0) + elapsed
    if self.timer > 1.5 then
        UpdateAddOnMemoryUsage()
        UpdateAddOnCPUUsage()
        
        -- Get profiler's own stats BEFORE resetting to diagnose if WE are the leak
        local profilerIndex = nil
        for i = 1, C_AddOns.GetNumAddOns() do
            local name = C_AddOns.GetAddOnInfo(i)
            if name == addonName then
                profilerIndex = i
                break
            end
        end
        
        local profilerCPU = 0
        local profilerMem = 0
        if profilerIndex then
            profilerCPU = GetAddOnCPUUsage(profilerIndex) or 0
            profilerMem = GetAddOnMemoryUsage(profilerIndex) / 1024
        end
        
        -- Reuse the data table instead of creating a new one each time
        local data = self.cachedData or {}
        wipe(data) -- Clear the table instead of creating new one
        
        for i = 1, C_AddOns.GetNumAddOns() do
            local name = C_AddOns.GetAddOnInfo(i)
            local mem = GetAddOnMemoryUsage(i)
            local cpu = GetAddOnCPUUsage(i) or 0
            
            if mem > 0 then 
                table.insert(data, {
                    n = name, 
                    m = mem/1024,
                    c = cpu,
                }) 
            end
        end
        
        -- Reset CPU usage after reading to show current period usage
        ResetCPUUsage()
        
        table.sort(data, function(a, b) return a.m > b.m end)
        
        self.cachedData = data -- Store for reuse
        
        scrollChild:SetWidth(scrollFrame:GetWidth())
        
        -- Update title to show profiler's own usage - this lets you see if WE are leaking
        titleText:SetText(ColorizeText("ADDON ", COLORS.BLUE) .. ColorizeText("PROFILER", COLORS.ORANGE) .. 
            ColorizeText(string.format(" [Self: %.2fms / %.1fMB]", profilerCPU, profilerMem), COLORS.GRAY))
        
        for i = 1, 40 do
            if data[i] then
                rows[i].name:SetText(data[i].n)
                
                -- Simplified color logic without creating extra strings
                local avgColor = COLORS.GREEN
                if data[i].c >= 2.0 then avgColor = COLORS.RED
                elseif data[i].c >= 0.5 then avgColor = COLORS.ORANGE end
                rows[i].avg:SetText(ColorizeText(string.format("%.3f", data[i].c), avgColor))
                
                local peakColor = COLORS.GREEN
                if data[i].c >= 5.0 then peakColor = COLORS.RED
                elseif data[i].c >= 1.0 then peakColor = COLORS.ORANGE end
                rows[i].peak:SetText(ColorizeText(string.format("%.2f", data[i].c), peakColor))
                
                local memColor = COLORS.GREEN
                if data[i].m >= 50 then memColor = COLORS.RED
                elseif data[i].m >= 20 then memColor = COLORS.ORANGE end
                rows[i].mem:SetText(ColorizeText(string.format("%.1f", data[i].m), memColor))
                
                rows[i]:Show()
            else
                rows[i]:Hide()
            end
        end
        scrollChild:SetHeight(#data * 18)
        self.timer = 0
        
        -- Force garbage collection every 10 updates to prevent buildup
        self.gcCounter = (self.gcCounter or 0) + 1
        if self.gcCounter >= 10 then
            collectgarbage("step", 100)
            self.gcCounter = 0
        end
    end
end)


local closeBtn = CreateFrame("Button", nil, p, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)

local grip = CreateFrame("Button", nil, p)
grip:SetSize(16, 16)
grip:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -5, 5)
grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
grip:SetScript("OnMouseDown", function() p:StartSizing("BOTTOMRIGHT") end)
grip:SetScript("OnMouseUp", function() p:StopMovingOrSizing() end)

function ns.Profiler:Toggle()
    if p:IsShown() then p:Hide() else p:Show() end
end

-- Auto-open profiler after reload if it was pending
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
    if NaowhQOL and NaowhQOL.profilerPending then
        NaowhQOL.profilerPending = nil
        C_Timer.After(0.5, function() p:Show() end)
    end
    self:UnregisterAllEvents()
end)