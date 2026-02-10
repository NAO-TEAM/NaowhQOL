local addonName, ns = ...

local cache = {}
local W = ns.Widgets
local C = ns.COLORS

local OptEngine = {
    isOptimized = false,
    lastFPSCheck = 0,
    performanceData = {},
}

-- Optimal FPS Settings based on client specifications
local OPTIMAL_FPS_CVARS = {
    -- Render & Display
    {
        cvar = "renderScale",
        optimal = "1",
        name = "Render Scale",
        desc = "100% native resolution",
        category = "render",
    },
    {
        cvar = "gxVSync",
        optimal = "0",
        name = "VSync",
        desc = "Disabled for maximum FPS",
        category = "render",
    },
    {
        cvar = "LowLatencyMode",
        optimal = "3",
        name = "Low Latency Mode",
        desc = "Reflex + Boost enabled",
        category = "render",
    },
    {
        cvar = "ffxAntiAliasingMode",
        optimal = "4",
        name = "Anti-Aliasing",
        desc = "CMAA2",
        category = "render",
    },
    {
        cvar = "MSAAQuality",
        optimal = "0",
        name = "MSAA Quality",
        desc = "Disabled",
        category = "render",
    },
    
    -- Graphics Quality
    {
        cvar = "graphicsShadowQuality",
        optimal = "1",
        name = "Shadow Quality",
        desc = "Fair (1)",
        category = "graphics",
    },
    {
        cvar = "graphicsLiquidDetail",
        optimal = "2",
        name = "Liquid Detail",
        desc = "Fair (2)",
        category = "graphics",
    },
    {
        cvar = "graphicsParticleDensity",
        optimal = "3",
        name = "Particle Density",
        desc = "Good (3)",
        category = "graphics",
    },
    {
        cvar = "graphicsSSAO",
        optimal = "0",
        name = "SSAO",
        desc = "Disabled",
        category = "graphics",
    },
    {
        cvar = "graphicsDepthEffects",
        optimal = "0",
        name = "Depth Effects",
        desc = "Disabled",
        category = "graphics",
    },
    {
        cvar = "graphicsComputeEffects",
        optimal = "0",
        name = "Compute Effects",
        desc = "Disabled",
        category = "graphics",
    },
    {
        cvar = "graphicsOutlineMode",
        optimal = "2",
        name = "Outline Mode",
        desc = "High (2)",
        category = "graphics",
    },
    {
        cvar = "graphicsTextureResolution",
        optimal = "2",
        name = "Texture Resolution",
        desc = "High (2)",
        category = "graphics",
    },
    {
        cvar = "graphicsSpellDensity",
        optimal = "0",
        name = "Spell Density",
        desc = "Essential",
        category = "graphics",
    },
    {
        cvar = "graphicsProjectedTextures",
        optimal = "1",
        name = "Projected Textures",
        desc = "Enabled",
        category = "graphics",
    },
    
    -- View Distance & Detail
    {
        cvar = "graphicsViewDistance",
        optimal = "4",
        name = "View Distance",
        desc = "Level 4",
        category = "detail",
    },
    {
        cvar = "graphicsEnvironmentDetail",
        optimal = "4",
        name = "Environment Detail",
        desc = "Level 4",
        category = "detail",
    },
    {
        cvar = "graphicsGroundClutter",
        optimal = "1",
        name = "Ground Clutter",
        desc = "Level 1",
        category = "detail",
    },
    
    -- Advanced Settings
    {
        cvar = "gxMaximize",
        optimal = "0",
        name = "Triple Buffering",
        desc = "Disabled",
        category = "advanced",
    },
    {
        cvar = "textureFilteringMode",
        optimal = "5",
        name = "Texture Filtering",
        desc = "16x Anisotropic",
        category = "advanced",
    },
    {
        cvar = "rtShadowQuality",
        optimal = "0",
        name = "Ray Traced Shadows",
        desc = "Disabled",
        category = "advanced",
    },
    {
        cvar = "ffxVRS",
        optimal = "0",
        name = "VRS Mode",
        desc = "Disabled",
        category = "advanced",
    },
    {
        cvar = "GxApi",
        optimal = "D3D12",
        name = "Graphics API",
        desc = "DirectX 12",
        category = "advanced",
    },
    {
        cvar = "physicsLevel",
        optimal = "1",
        name = "Physics Integration",
        desc = "Player Only",
        category = "advanced",
    },
    
    -- FPS Settings
    {
        cvar = "maxFPSBk",
        optimal = "30",
        name = "Max Background FPS",
        desc = "30 FPS",
        category = "fps",
    },
    {
        cvar = "useTargetFPS",
        optimal = "0",
        name = "Target FPS",
        desc = "Disabled",
        category = "fps",
    },
    
    -- Post Processing
    {
        cvar = "ResampleSharpness",
        optimal = "0",
        name = "Resample Sharpness",
        desc = "0 (neutral)",
        category = "post",
    },
    {
        cvar = "cameraShake",
        optimal = "0",
        name = "Camera Shake",
        desc = "Disabled",
        category = "post",
    },
}

-- Category display names and order
local CATEGORY_INFO = {
    render = { name = "Render & Display", order = 1 },
    graphics = { name = "Graphics Quality", order = 2 },
    detail = { name = "View Distance & Detail", order = 3 },
    advanced = { name = "Advanced Settings", order = 4 },
    fps = { name = "FPS Limits", order = 5 },
    post = { name = "Post Processing", order = 6 },
}

local SetCVar = SetCVar
local GetCVar = GetCVar
local ConsoleExec = ConsoleExec
local GetFramerate = GetFramerate
local GetNetStats = GetNetStats
local collectgarbage = collectgarbage
local print = print
local C_Timer = C_Timer
local C_AddOnProfiler = C_AddOnProfiler
local math_floor = math.floor
local string_format = string.format
local tonumber = tonumber

local function SaveCurrentSettings()
    if not NaowhQOL then NaowhQOL = {} end
    if not NaowhQOL.savedSettings then
        NaowhQOL.savedSettings = {}
        
        for _, setting in ipairs(OPTIMAL_FPS_CVARS) do
            local success, current = pcall(GetCVar, setting.cvar)
            if success and current then
                NaowhQOL.savedSettings[setting.cvar] = current
            end
        end
        
        -- Also save maxFPSToggle
        local toggleSuccess, toggleValue = pcall(GetCVar, "maxFPSToggle")
        if toggleSuccess and toggleValue then
            NaowhQOL.savedSettings["maxFPSToggle"] = toggleValue
        end
        
        print(W.Colorize("Naowh QOL:", C.BLUE) .. " "
            .. W.Colorize("Current settings saved! You can restore them anytime.", C.SUCCESS))
    end
end

function ns:ApplyFPSOptimization()
    SaveCurrentSettings()
    
    local successCount = 0
    local failCount = 0
    
    for _, setting in ipairs(OPTIMAL_FPS_CVARS) do
        -- Special handling for maxFPS
        if setting.cvar == "maxFPS" then
            if setting.optimal == "0" then
                -- Unlimited: turn OFF the toggle
                pcall(SetCVar, "maxFPSToggle", "0")
                pcall(SetCVar, "maxFPS", "0")
            else
                -- Limited: turn ON the toggle and set value
                pcall(SetCVar, "maxFPSToggle", "1")
                pcall(SetCVar, "maxFPS", setting.optimal)
            end
            successCount = successCount + 1
        else
            local success = pcall(SetCVar, setting.cvar, setting.optimal)
            if success then
                successCount = successCount + 1
            else
                failCount = failCount + 1
            end
        end
    end

    if not NaowhQOL then NaowhQOL = {} end
    NaowhQOL.fpsOptimizationApplied = true

    print(W.Colorize("OPTIMAL FPS SETTINGS:", C.ORANGE) .. " "
        .. W.Colorize(string_format("Applied %d settings! Reloading UI...", successCount), C.SUCCESS))
    
    if failCount > 0 then
        print(W.Colorize("Warning:", C.ORANGE) .. " "
            .. W.Colorize(string_format("%d settings could not be applied.", failCount), C.GRAY))
    end
    
    C_Timer.After(0.5, function()
        StaticPopup_Show("NAOWH_QOL_FPS_RELOAD")
    end)

    OptEngine.isOptimized = true
end

function ns:ApplySingleCVar(cvar, value)
    -- Initialize individual backups if needed
    if not NaowhQOL then NaowhQOL = {} end
    if not NaowhQOL.individualBackups then
        NaowhQOL.individualBackups = {}
    end
    
    -- Save current value BEFORE changing
    local success, current = pcall(GetCVar, cvar)
    if success and current then
        NaowhQOL.individualBackups[cvar] = tostring(current)
    end
    
    -- SPECIAL HANDLING for maxFPS - need to control the toggle too
    if cvar == "maxFPS" then
        -- Save the toggle state too
        local toggleSuccess, toggleCurrent = pcall(GetCVar, "maxFPSToggle")
        if toggleSuccess and toggleCurrent then
            NaowhQOL.individualBackups["maxFPSToggle"] = tostring(toggleCurrent)
        end
        
        if value == "0" then
            -- Unlimited: turn OFF the toggle (disable the cap)
            pcall(SetCVar, "maxFPSToggle", "0")
            pcall(SetCVar, "maxFPS", "0")
        else
            -- Limited: turn ON the toggle and set the value
            pcall(SetCVar, "maxFPSToggle", "1")
            pcall(SetCVar, "maxFPS", tostring(value))
        end
        
        print(W.Colorize("Naowh QOL:", C.BLUE) .. " "
            .. W.Colorize("maxFPS set to " .. (value == "0" and "Unlimited" or (value .. " FPS")), C.SUCCESS))
        return true
    end
    
    -- Apply the new value for other CVars
    local applySuccess = pcall(SetCVar, cvar, tostring(value))
    if applySuccess then
        print(W.Colorize("Naowh QOL:", C.BLUE) .. " "
            .. W.Colorize(cvar .. " set to " .. tostring(value), C.SUCCESS))
        return true
    else
        print(W.Colorize("Naowh QOL:", C.BLUE) .. " "
            .. W.Colorize("Failed to set " .. cvar, C.ERROR))
        return false
    end
end

function ns:RevertSingleCVar(cvar)
    if not NaowhQOL or not NaowhQOL.individualBackups or not NaowhQOL.individualBackups[cvar] then
        print(W.Colorize("Naowh QOL:", C.BLUE) .. " "
            .. W.Colorize("No backup found for " .. cvar, C.ERROR))
        return false
    end
    
    local savedValue = NaowhQOL.individualBackups[cvar]
    
    -- SPECIAL HANDLING for maxFPS - restore the toggle too
    if cvar == "maxFPS" then
        local savedToggle = NaowhQOL.individualBackups["maxFPSToggle"]
        if savedToggle then
            pcall(SetCVar, "maxFPSToggle", tostring(savedToggle))
        end
        pcall(SetCVar, "maxFPS", tostring(savedValue))
        
        print(W.Colorize("Naowh QOL:", C.BLUE) .. " "
            .. W.Colorize("maxFPS reverted to " .. tostring(savedValue), C.SUCCESS))
        
        -- Clear both backups
        NaowhQOL.individualBackups[cvar] = nil
        NaowhQOL.individualBackups["maxFPSToggle"] = nil
        return true
    end
    
    local success = pcall(SetCVar, cvar, tostring(savedValue))
    
    if success then
        print(W.Colorize("Naowh QOL:", C.BLUE) .. " "
            .. W.Colorize(cvar .. " reverted to " .. tostring(savedValue), C.SUCCESS))
        -- Clear the backup after reverting
        NaowhQOL.individualBackups[cvar] = nil
        return true
    else
        print(W.Colorize("Naowh QOL:", C.BLUE) .. " "
            .. W.Colorize("Failed to revert " .. cvar, C.ERROR))
        return false
    end
end

function ns:HasBackupForCVar(cvar)
    return NaowhQOL and NaowhQOL.individualBackups and NaowhQOL.individualBackups[cvar] ~= nil
end

function ns:GetCVarStatus(cvar, optimal)
    local success, current = pcall(GetCVar, cvar)
    
    -- If GetCVar fails or returns nil, treat it as "0" or "Off"
    if not success or not current or current == "" then
        current = "0"
    end
    
    -- Convert to numbers for proper comparison when possible
    local currentNum = tonumber(current)
    local optimalNum = tonumber(optimal)
    
    -- Format special cases for display
    local displayValue = tostring(current)
    local displayOptimal = tostring(optimal)
    
    -- SPECIAL CASE: maxFPS needs to check the toggle
    if cvar == "maxFPS" then
        local toggleSuccess, toggleValue = pcall(GetCVar, "maxFPSToggle")
        
        -- Determine the REAL current state
        local realCurrentValue
        if toggleSuccess and toggleValue == "0" then
            -- Toggle is OFF = effectively unlimited (treat as "0")
            realCurrentValue = "0"
            displayValue = "Unlimited"
        else
            -- Toggle is ON = use the actual maxFPS value
            realCurrentValue = current
            displayValue = (current == "0") and "Unlimited" or (current .. " FPS")
        end
        
        displayOptimal = (optimal == "0") and "Unlimited" or (optimal .. " FPS")
        
        -- Now compare the REAL current value with optimal
        local realCurrentNum = tonumber(realCurrentValue)
        if realCurrentNum and optimalNum then
            isOptimal = (realCurrentNum == optimalNum)
        else
            isOptimal = (tostring(realCurrentValue) == tostring(optimal))
        end
        
        return displayValue, isOptimal, displayOptimal
    end
    
    if cvar == "maxFPSBk" or cvar == "targetFPS" then
        displayValue = current .. " FPS"
        displayOptimal = optimal .. " FPS"
    elseif cvar == "useTargetFPS" or cvar == "gxVSync" or cvar == "gxMaximize" or 
           cvar == "rtShadowQuality" or cvar == "ffxVRS" or
           cvar == "graphicsSSAO" or cvar == "graphicsDepthEffects" or 
           cvar == "graphicsComputeEffects" or cvar == "graphicsProjectedTextures" then
        displayValue = (current == "1" or current == "true") and "Enabled" or "Disabled"
        displayOptimal = (optimal == "1" or optimal == "true") and "Enabled" or "Disabled"
    elseif cvar == "LowLatencyMode" then
        if current == "0" then displayValue = "Off"
        elseif current == "1" then displayValue = "On"
        elseif current == "2" then displayValue = "Reflex"
        elseif current == "3" then displayValue = "Reflex+Boost"
        else displayValue = "Off" end
        if optimal == "3" then displayOptimal = "Reflex+Boost" end
    elseif cvar == "ffxAntiAliasingMode" then
        if current == "0" then displayValue = "None"
        elseif current == "1" then displayValue = "FXAA"
        elseif current == "2" then displayValue = "CMAA2"
        elseif current == "4" then displayValue = "CMAA2"
        else displayValue = "None" end
        if optimal == "2" or optimal == "4" then displayOptimal = "CMAA2" end
    elseif cvar == "MSAAQuality" then
        if current == "0" then displayValue = "Off"
        elseif current == "1" then displayValue = "2x MSAA"
        elseif current == "2" then displayValue = "4x MSAA"
        elseif current == "3" then displayValue = "8x MSAA"
        else displayValue = "Off" end
        if optimal == "0" then displayOptimal = "Off" end
    elseif cvar == "textureFilteringMode" then
        if current == "0" then displayValue = "Bilinear"
        elseif current == "1" then displayValue = "Trilinear"
        elseif current == "2" then displayValue = "2x"
        elseif current == "3" then displayValue = "4x"
        elseif current == "4" then displayValue = "8x"
        elseif current == "5" then displayValue = "16x"
        else displayValue = "Bilinear" end
        if optimal == "5" then displayOptimal = "16x Aniso" end
    elseif cvar == "physicsLevel" then
        if current == "0" then displayValue = "None"
        elseif current == "1" then displayValue = "Player Only"
        elseif current == "2" then displayValue = "Full"
        else displayValue = "None" end
        if optimal == "1" then displayOptimal = "Player Only" end
    elseif cvar == "cameraShake" then
        displayValue = (current == "0") and "Off" or "On"
        displayOptimal = (optimal == "0") and "Off" or "On"
    elseif cvar == "renderScale" then
        local scalePercent = math.floor((tonumber(current) or 1) * 100)
        displayValue = scalePercent .. "%"
        displayOptimal = "100%"
    end
    
    -- IMPROVED COMPARISON (not used for maxFPS since we handled it above)
    local isOptimal
    if currentNum and optimalNum then
        -- Numeric comparison (handles "3" vs 3, "4.0" vs "4", etc.)
        isOptimal = (currentNum == optimalNum)
    else
        -- String comparison for non-numeric values (like "D3D12")
        isOptimal = (tostring(current) == tostring(optimal))
    end
    
    return displayValue, isOptimal, displayOptimal
end

function ns:OptimizeNetwork()
    SetCVar("advancedCombatLogging", "0")
    SetCVar("chatBubbles", "0")
    SetCVar("chatBubblesParty", "0")

    if not NaowhQOL then NaowhQOL = {} end
    NaowhQOL.networkOptimizationApplied = true

    print(W.Colorize("NETWORK OPTIMIZATION:", C.BLUE) .. " "
        .. W.Colorize("Network settings optimized!", C.SUCCESS))
end

function ns:OptimizeNameplates()
    SetCVar("nameplateShowAll", "1")
    SetCVar("nameplateShowEnemies", "1")
    SetCVar("nameplateShowFriends", "0")
    SetCVar("nameplateMaxDistance", "45")
    SetCVar("nameplateMinAlpha", "0.5")
    SetCVar("nameplateMaxAlpha", "1")
    SetCVar("nameplateMinScale", "0.8")
    SetCVar("nameplateMaxScale", "1")
    SetCVar("nameplateSelectedScale", "1.2")

    if not NaowhQOL then NaowhQOL = {} end
    NaowhQOL.nameplateOptimizationApplied = true

    print(W.Colorize("NAMEPLATE OPTIMIZATION:", C.ORANGE) .. " "
        .. W.Colorize("Nameplates optimized for performance!", C.SUCCESS))
end

function ns:SupremeMemoryPurge()
    local memBefore = collectgarbage("count")

    collectgarbage("stop")
    for i = 1, 3 do
        collectgarbage("collect")
    end

    if CombatLogClearEntries then
        CombatLogClearEntries()
    end

    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame"..i]
        if frame then
            frame:Clear()
        end
    end

    collectgarbage("restart")
    collectgarbage("collect")

    local memAfter = collectgarbage("count")
    local freed = memBefore - memAfter

    print(W.Colorize("MEMORY PURGE:", C.ORANGE) .. " "
        .. W.Colorize(string_format("%.2f MB freed successfully", freed / 1024), C.SUCCESS))
end

function ns:CombatOptimization()
    SetCVar("graphicsSpellDensity", "0")
    SetCVar("projectedTextures", "0")
    SetCVar("graphicsParticleDensity", "0")
    SetCVar("nameplateMaxDistance", "45")

    if not NaowhQOL then NaowhQOL = {} end
    NaowhQOL.combatOptimizationApplied = true

    print(W.Colorize("COMBAT OPTIMIZATION:", C.ORANGE) .. " "
        .. W.Colorize("Combat performance maximized!", C.SUCCESS))
end

function ns:AllPerformanceOptimizations()
    SaveCurrentSettings()
    ns:CombatOptimization()
    ns:OptimizeNetwork()
    ns:OptimizeNameplates()
    ns:SupremeMemoryPurge()

    if not NaowhQOL then NaowhQOL = {} end
    NaowhQOL.allPerformanceApplied = true

    print(W.Colorize("ALL PERFORMANCE OPTIMIZATIONS:", C.ORANGE) .. " "
        .. W.Colorize("All performance settings maximized!", C.SUCCESS))
end

function ns:LowEndOptimization()
    SaveCurrentSettings()
    
    -- Base Graphics Quality (1 = Low)
    SetCVar("graphicsQuality", "1")
    SetCVar("graphicsTextureQuality", "1")
    SetCVar("graphicsProjectedTextures", "0")
    
    -- Shadow Quality (0 = Low)
    SetCVar("graphicsShadowQuality", "0")
    
    -- Liquid Detail (0 = Low)
    SetCVar("graphicsLiquidDetail", "0")
    
    -- Particle Density (0 = Low)
    SetCVar("graphicsParticleDensity", "0")
    
    -- SSAO (0 = Disabled)
    SetCVar("graphicsSSAO", "0")
    
    -- Depth Effects (0 = Low)
    SetCVar("graphicsDepthEffects", "0")
    
    -- Compute Effects (0 = Disabled)
    SetCVar("graphicsComputeEffects", "0")
    
    -- Outline Mode (0 = Disabled)
    SetCVar("graphicsOutlineMode", "0")
    
    -- Texture Resolution (0 = Low)
    SetCVar("graphicsTextureResolution", "0")
    
    -- Spell Density (0 = Essential)
    SetCVar("graphicsSpellDensity", "0")
    
    -- Projected Textures (0 = Disabled)
    SetCVar("projectedTextures", "0")
    
    -- View Distance (3 = Low)
    SetCVar("graphicsViewDistance", "3")
    
    -- Environment Detail (3 = Low)
    SetCVar("graphicsEnvironmentDetail", "3")
    
    -- Ground Clutter (3 = Low)
    SetCVar("graphicsGroundClutter", "3")
    
    -- Texture Filtering (0 = Bilinear - Lowest)
    SetCVar("graphicsTextureFiltering", "0")
    
    -- Anti-Aliasing (0 = None)
    SetCVar("MSAAQuality", "0")
    SetCVar("ffxAntiAliasingMode", "0")
    
    -- Resample Quality (0 = Bilinear)
    SetCVar("ResampleQuality", "0")
    
    -- Graphics API
    SetCVar("gxApi", "D3D11")
    
    -- Weather Density (0 = Disabled)
    SetCVar("weatherDensity", "0")
    
    -- Reflections (0 = Disabled)
    SetCVar("reflectionMode", "0")
    
    -- Sunshafts (0 = Disabled)
    SetCVar("sunshafts", "0")
    
    -- Refraction (0 = Disabled)
    SetCVar("refraction", "0")
    
    -- Lighting Quality (0 = Low)
    SetCVar("lightingQuality", "0")
    
    -- Render Scale (0.75 = 75%)
    SetCVar("renderScale", "0.75")
    
    -- FPS Cap
    SetCVar("maxFPSToggle", "1")
    SetCVar("maxFPS", "60")
    SetCVar("maxFPSLoading", "30")
    
    -- VSync
    SetCVar("gxVSync", "0")
    
    -- Triple Buffering
    SetCVar("gxTripleBuffer", "0")
    
    if not NaowhQOL then NaowhQOL = {} end
    NaowhQOL.lowEndApplied = true

    print(W.Colorize("LOW-END MODE:", C.ORANGE) .. " "
        .. W.Colorize("Optimized for low-end PCs! Reloading UI...", C.SUCCESS))
    
    C_Timer.After(0.5, function()
        StaticPopup_Show("NAOWH_QOL_FPS_RELOAD")
    end)
end

function ns:RestorePreviousSettings()
    if not NaowhQOL or not NaowhQOL.savedSettings then
        print(W.Colorize("Naowh QOL:", C.BLUE) .. " "
            .. W.Colorize("No saved settings found!", C.ERROR))
        return
    end
    
    local successCount = 0
    local saved = NaowhQOL.savedSettings
    
    for cvar, value in pairs(saved) do
        local success = pcall(SetCVar, cvar, value)
        if success then
            successCount = successCount + 1
        end
    end
    
    -- Clear saved settings after reverting
    NaowhQOL.savedSettings = nil
    
    print(W.Colorize("Naowh QOL:", C.BLUE) .. " "
        .. W.Colorize(string_format("Restored %d settings! Reloading UI...", successCount), C.SUCCESS))
    
    C_Timer.After(0.5, function()
        StaticPopup_Show("NAOWH_QOL_FPS_RELOAD")
    end)
end

function ns:UltraQualityOptimization()
    SaveCurrentSettings()
    
    local successCount = 0
    local failCount = 0
    
    -- Ultra Graphics CVars - Everything maxed out
    local ultraSettings = {
        -- Base Quality
        ["graphicsQuality"] = "10",
        ["graphicsTextureQuality"] = "2",
        
        -- Render Scale
        ["renderScale"] = "1",
        
        -- VSync & Display
        ["gxVSync"] = "0",
        ["gxMaximize"] = "0",
        
        -- Low Latency
        ["LowLatencyMode"] = "3",
        
        -- Anti-Aliasing
        ["ffxAntiAliasingMode"] = "2",
        ["MSAAQuality"] = "8",
        ["MSAAAlphaCoverage"] = "1",
        
        -- Shadow Quality
        ["graphicsShadowQuality"] = "6",
        ["shadowTextureSize"] = "2048",
        ["shadowMode"] = "4",
        
        -- Liquid Detail
        ["graphicsLiquidDetail"] = "3",
        ["waterDetail"] = "3",
        ["reflectionMode"] = "3",
        ["refraction"] = "1",
        ["rippleDetail"] = "2",
        
        -- Particle Density
        ["graphicsParticleDensity"] = "10",
        ["particleDensity"] = "100",
        ["weatherDensity"] = "3",
        
        -- SSAO
        ["graphicsSSAO"] = "4",
        ["ssao"] = "3",
        
        -- Depth Effects
        ["graphicsDepthEffects"] = "3",
        ["depthEffects"] = "2",
        
        -- Compute Effects
        ["graphicsComputeEffects"] = "3",
        
        -- Outline Mode
        ["graphicsOutlineMode"] = "3",
        ["OutlineEngineMode"] = "2",
        
        -- Texture Resolution
        ["graphicsTextureResolution"] = "2",
        
        -- Spell Density
        ["graphicsSpellDensity"] = "10",
        ["spellClutter"] = "200",
        
        -- Projected Textures
        ["graphicsProjectedTextures"] = "2",
        ["projectedTextures"] = "2",
        
        -- View Distance
        ["graphicsViewDistance"] = "10",
        ["farclip"] = "2600",
        ["horizonStart"] = "3000",
        ["horizonClip"] = "6000",
        
        -- Environment Detail
        ["graphicsEnvironmentDetail"] = "10",
        ["environmentDetail"] = "2",
        
        -- Ground Clutter
        ["graphicsGroundClutter"] = "10",
        ["groundEffectDensity"] = "256",
        ["groundEffectDist"] = "260",
        
        -- Texture Filtering
        ["textureFilteringMode"] = "5",
        ["graphicsTextureFiltering"] = "5",
        
        -- Ray Traced Shadows
        ["rtShadowQuality"] = "3",
        
        -- VRS Mode
        ["ffxVRS"] = "0",
        
        -- Graphics API
        ["GxApi"] = "D3D12",
        ["gxApi"] = "D3D12",
        
        -- Physics
        ["physicsLevel"] = "2",
        
        -- FPS Settings - Unlimited
        ["maxFPSToggle"] = "0",
        ["maxFPS"] = "0",
        ["maxFPSBk"] = "30",
        ["useTargetFPS"] = "0",
        
        -- Post Processing
        ["ResampleSharpness"] = "0.5",
        ["ResampleQuality"] = "3",
        ["ffxSuperResolution"] = "0",
        ["Contrast"] = "50",
        ["Brightness"] = "50",
        ["Gamma"] = "1",
        
        -- Effects
        ["ffxGlow"] = "1",
        ["ffxDeath"] = "1",
        ["ffxNether"] = "1",
        ["sunShafts"] = "2",
        
        -- Camera
        ["cameraShake"] = "1",
        ["cameraDistanceMaxZoomFactor"] = "2.6",
        
        -- LOD
        ["terrainLodDist"] = "400",
        ["terrainMipLevel"] = "0",
        ["lodObjectCullSize"] = "5",
        ["lodObjectFadeScale"] = "100",
        ["entityLodDist"] = "100",
        
        -- Other
        ["particulatesEnabled"] = "1",
        ["clusteredShading"] = "1",
        ["volumeFogLevel"] = "3",
    }
    
    for cvar, value in pairs(ultraSettings) do
        local success = pcall(SetCVar, cvar, value)
        if success then
            successCount = successCount + 1
        else
            failCount = failCount + 1
        end
    end

    if not NaowhQOL then NaowhQOL = {} end
    NaowhQOL.ultraQualityApplied = true

    print(W.Colorize("ULTRA SETTINGS:", C.BLUE) .. " "
        .. W.Colorize(string_format("Applied %d ultra settings! Reloading UI...", successCount), C.SUCCESS))
    
    if failCount > 0 then
        print(W.Colorize("Note:", C.ORANGE) .. " "
            .. W.Colorize(string_format("%d settings may require game restart.", failCount), C.GRAY))
    end
    
    C_Timer.After(0.5, function()
        StaticPopup_Show("NAOWH_QOL_FPS_RELOAD")
    end)
end

-- Slash command for sharpening toggle
SLASH_NAOWHSHARP1 = "/naowhsharp"
SlashCmdList["NAOWHSHARP"] = function()
    local current = GetCVarBool("ResampleAlwaysSharpen")
    SetCVar("ResampleAlwaysSharpen", not current and "1" or "0")
    print(W.Colorize("Naowh QOL:", C.BLUE) .. " Sharpening is now " 
        .. W.Colorize(current and "OFF" or "ON", current and C.ERROR or C.SUCCESS))
end

local function AddTooltip(button, title, description, features)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(W.Colorize(title, C.ORANGE), 1, 1, 1, 1, true)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine(description, 0.7, 0.7, 0.7)
        if features then
            for i = 1, #features do
                GameTooltip:AddLine(features[i], 0.5, 1, 0.5)
            end
        end
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
end

local function CreateSectionButton(parent, col, row, text)
    local btnW, btnH = 190, 32
    local x = (col == 2) and 120 or -120
    local y = -5 - ((row - 1) * 42)
    local btn = W:CreateButton(parent, { text = text, width = btnW, height = btnH })
    btn:SetPoint("TOP", parent, "TOP", x, y)
    return btn, y
end

local function PlaceSlider(slider, parent, x, y)
    local frame = slider:GetParent()
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    return slider
end

local function CreateCVarRow(parent, setting, yOffset)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(440, 28)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    
    -- Setting name
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("LEFT", row, "LEFT", 5, 0)
    nameText:SetWidth(140)
    nameText:SetJustifyH("LEFT")
    nameText:SetText(W.Colorize(setting.name, C.BLUE))
    
    -- Current value
    local currentText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    currentText:SetPoint("LEFT", nameText, "RIGHT", 5, 0)
    currentText:SetWidth(80)
    currentText:SetJustifyH("LEFT")
    
    -- Arrow
    local arrowText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    arrowText:SetPoint("LEFT", currentText, "RIGHT", 2, 0)
    arrowText:SetText(W.Colorize(">", C.GRAY))
    
    -- Optimal value
    local optimalText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    optimalText:SetPoint("LEFT", arrowText, "RIGHT", 2, 0)
    optimalText:SetWidth(80)
    optimalText:SetJustifyH("LEFT")
    
    -- Revert button (declare first so Apply can reference it)
    local revertBtn = W:CreateButton(row, { text = "Revert", width = 60, height = 22 })
    
    local function UpdateRevertButton()
        if ns:HasBackupForCVar(setting.cvar) then
            revertBtn:Enable()
            revertBtn:SetAlpha(1.0)
        else
            revertBtn:Disable()
            revertBtn:SetAlpha(0.5)
        end
    end
    
    local function UpdateCurrentText()
        local displayCurrent, isOptimal, displayOptimal = ns:GetCVarStatus(setting.cvar, setting.optimal)
        local color = isOptimal and C.SUCCESS or C.ORANGE
        currentText:SetText(W.Colorize(tostring(displayCurrent), color))
        optimalText:SetText(W.Colorize(tostring(displayOptimal), C.SUCCESS))
        UpdateRevertButton()
    end
    UpdateCurrentText()
    
    -- Apply button
    local applyBtn = W:CreateButton(row, {
        text = "Apply",
        width = 60,
        height = 22,
        onClick = function()
            if ns:ApplySingleCVar(setting.cvar, setting.optimal) then
                C_Timer.After(0.1, function()
                    UpdateCurrentText()
                end)
            end
        end
    })
    applyBtn:SetPoint("LEFT", optimalText, "RIGHT", 5, 0)
    
    -- Position revert button
    revertBtn:SetPoint("LEFT", applyBtn, "RIGHT", 5, 0)
    revertBtn:SetScript("OnClick", function()
        if ns:RevertSingleCVar(setting.cvar) then
            C_Timer.After(0.1, function()
                UpdateCurrentText()
            end)
        end
    end)
    
    -- Initialize button state
    UpdateRevertButton()
    
    -- Auto-refresh every 2 seconds to detect external changes
    local refreshFrame = CreateFrame("Frame", nil, row)
    refreshFrame.elapsed = 0
    refreshFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed >= 2 then
            UpdateCurrentText()
            self.elapsed = 0
        end
    end)
    
    -- Tooltip
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(W.Colorize(setting.name, C.ORANGE), 1, 1, 1, 1, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(setting.desc, 0.7, 0.7, 0.7)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("CVar: " .. setting.cvar, 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    
    row:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    return row
end

function ns:InitOptOptions()
    local p = ns.MainFrame.Content

    W:CachedPanel(cache, "optFrame", p, function(f)
        local sf, sc = W:CreateScrollFrame(f, 2400)

        W:CreatePageHeader(sc,
            {{"SYSTEM ", C.BLUE}, {"OPTIMIZATIONS", C.ORANGE}},
            W.Colorize("Performance Enhancement", C.GRAY))

        StaticPopupDialogs["NAOWH_QOL_FPS_RELOAD"] = {
            text = W.Colorize("Naowh QOL", C.BLUE) .. "\n\n"
                .. W.Colorize("Aggressive FPS optimizations applied successfully.", C.WHITE) .. "\n\n"
                .. W.Colorize("A UI Reload is required to apply all changes.", C.ORANGE),
            button1 = W.Colorize("Reload UI", C.SUCCESS),
            button2 = W.Colorize("Cancel", C.ERROR),
            OnAccept = function() ReloadUI() end,
            timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        }

        StaticPopupDialogs["NAOWH_QOL_RELOAD"] = {
            text = W.Colorize("Naowh QOL", C.BLUE) .. "\n\n"
                .. W.Colorize("Graphics engine restarted successfully.", C.WHITE) .. "\n\n"
                .. W.Colorize("A UI Reload is required to prevent conflicts.", C.ORANGE),
            button1 = W.Colorize("Reload UI", C.SUCCESS),
            button2 = W.Colorize("Cancel", C.ERROR),
            OnAccept = function() ReloadUI() end,
            timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        }

        -- Section container
        local sectionContainer = CreateFrame("Frame", nil, sc)
        sectionContainer:SetPoint("TOPLEFT", 10, -75)
        sectionContainer:SetPoint("RIGHT", sc, "RIGHT", -10, 0)
        sectionContainer:SetHeight(1)  -- Will be updated by RelayoutSections

        local RelayoutSections
        local allSections = {}

        -----------------------------------------------------------------------
        -- PRESETS (3 buttons: Optimal FPS, Ultra Settings, Revert Settings)
        -----------------------------------------------------------------------
        local presetsWrap, presetsContent = W:CreateCollapsibleSection(sectionContainer, {
            text = "PRESETS",
            startOpen = false,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        -- Create Revert button first (will be referenced by other buttons)
        local revertBtn = CreateSectionButton(presetsContent, 1, 2,
            W.Colorize("Revert ", C.GRAY) .. "Settings")
        
        -- Check if settings were previously saved to enable/disable button
        local hasSavedSettings = NaowhQOL and NaowhQOL.savedSettings ~= nil
        
        if not hasSavedSettings then
            revertBtn:Disable()
            revertBtn:SetAlpha(0.5)
        end
        
        revertBtn:SetScript("OnClick", function() 
            ns:RestorePreviousSettings()
            -- Disable button after reverting
            revertBtn:Disable()
            revertBtn:SetAlpha(0.5)
            revertBtn:SetText(W.Colorize("Revert ", C.GRAY) .. "Settings")
            -- Clear saved settings
            if NaowhQOL then
                NaowhQOL.savedSettings = nil
            end
        end)
        AddTooltip(revertBtn, "Revert Settings",
            "Restore your previous settings:", {
            "Reverts to saved configuration",
            "Before any optimization was applied",
            " ",
            hasSavedSettings and "Click to restore" or "Apply optimization first"
        })

        local fpsBtn = CreateSectionButton(presetsContent, 1, 1,
            W.Colorize("Optimal FPS ", C.ORANGE) .. "Settings")
        fpsBtn:SetScript("OnClick", function() 
            ns:ApplyFPSOptimization()
            -- Enable revert button after applying optimization
            revertBtn:Enable()
            revertBtn:SetAlpha(1)
            revertBtn:SetText(W.Colorize("Revert ", C.ORANGE) .. "Settings")
        end)
        AddTooltip(fpsBtn, "Optimal FPS Settings",
            "Maximum performance for competitive gameplay:", {
            "DirectX 12 enabled", "All effects optimized",
            "Shadows balanced", "Particles optimized",
            "Perfect for raids & M+",
            " ", "Requires UI Reload"
        })

        local qualityBtn = CreateSectionButton(presetsContent, 2, 1,
            W.Colorize("Ultra ", C.BLUE) .. "Settings")
        qualityBtn:SetScript("OnClick", function() 
            ns:UltraQualityOptimization()
            -- Enable revert button after applying optimization
            revertBtn:Enable()
            revertBtn:SetAlpha(1)
            revertBtn:SetText(W.Colorize("Revert ", C.ORANGE) .. "Settings")
        end)
        AddTooltip(qualityBtn, "Ultra Settings", "Maximum graphics quality:", {
            "All settings maxed out", "DirectX 12 optimized",
            "SSAO at maximum", "Full effects enabled",
            "For high-end PCs & content creation"
        })

        presetsContent:SetHeight(87)
        presetsWrap:RecalcHeight()
        table.insert(allSections, presetsWrap)

        -----------------------------------------------------------------------
        -- OPTIMAL FPS SETTINGS (Individual CVars by Category)
        -----------------------------------------------------------------------
        
        -- Group settings by category
        local settingsByCategory = {}
        for _, setting in ipairs(OPTIMAL_FPS_CVARS) do
            if not settingsByCategory[setting.category] then
                settingsByCategory[setting.category] = {}
            end
            table.insert(settingsByCategory[setting.category], setting)
        end
        
        -- Create sections for each category in order
        local categoryOrder = {}
        for cat, info in pairs(CATEGORY_INFO) do
            table.insert(categoryOrder, {cat = cat, order = info.order})
        end
        table.sort(categoryOrder, function(a, b) return a.order < b.order end)
        
        for _, catData in ipairs(categoryOrder) do
            local category = catData.cat
            local settings = settingsByCategory[category]
            
            if settings and #settings > 0 then
                local catWrap, catContent = W:CreateCollapsibleSection(sectionContainer, {
                    text = CATEGORY_INFO[category].name,
                    startOpen = false,
                    onCollapse = function() if RelayoutSections then RelayoutSections() end end,
                })
                
                local yOffset = -5
                for _, setting in ipairs(settings) do
                    CreateCVarRow(catContent, setting, yOffset)
                    yOffset = yOffset - 32
                end
                
                catContent:SetHeight(math.abs(yOffset) + 10)
                catWrap:RecalcHeight()
                table.insert(allSections, catWrap)
            end
        end

        -----------------------------------------------------------------------
        -- SPELL QUEUE WINDOW
        -----------------------------------------------------------------------
        local advWrap, advContent = W:CreateCollapsibleSection(sectionContainer, {
            text = "SPELL QUEUE WINDOW",
            startOpen = false,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local queueInitVal = tonumber(GetCVar("SpellQueueWindow")) or 130
        local queueSlider = W:CreateAdvancedSlider(advContent,
            W.Colorize("Spell Queue Window (ms)", C.BLUE), 50, 500, -5, 1, false,
            function(val)
                SetCVar("SpellQueueWindow", val)
                if not NaowhQOL then NaowhQOL = {} end
                NaowhQOL.spellQueueWindow = val
            end,
            { value = queueInitVal })
        PlaceSlider(queueSlider, advContent, 110, -5)

        local recommendText = advContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        recommendText:SetPoint("TOP", queueSlider:GetParent(), "BOTTOM", 0, 5)
        recommendText:SetText(W.Colorize("Recommended Settings: ", C.GRAY) 
            .. W.Colorize("Melee: Ping + 100, ", C.WHITE)
            .. W.Colorize("Ranged: Ping + 150", C.WHITE))

        advContent:SetHeight(75)
        advWrap:RecalcHeight()
        table.insert(allSections, advWrap)

        -----------------------------------------------------------------------
        -- DIAGNOSTICS
        -----------------------------------------------------------------------
        local diagWrap, diagContent = W:CreateCollapsibleSection(sectionContainer, {
            text = "DIAGNOSTICS",
            startOpen = false,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local profBtn = CreateSectionButton(diagContent, 1, 1,
            W.Colorize("Addon ", C.BLUE) .. "Profiler")
        profBtn:SetPoint("TOP", diagContent, "TOP", 0, -5)
        profBtn:SetScript("OnClick", function()
            if GetCVar("scriptProfile") ~= "1" then
                SetCVar("scriptProfile", "1")
                print(W.Colorize("Naowh QOL:", C.BLUE) .. " "
                    .. W.Colorize("Script profiling enabled.", C.SUCCESS))
                StaticPopup_Show("NAOWH_QOL_RELOAD")
            else
                if ns.Profiler and ns.Profiler.Toggle then
                    ns.Profiler:Toggle()
                else
                    print(W.Colorize("Naowh QOL:", C.BLUE) .. " "
                        .. W.Colorize("Profiler module not available.", C.ERROR))
                end
            end
        end)
        AddTooltip(profBtn, "Addon Profiler", "Profile all addon performance:", {
            "Track all addon CPU & memory", "Find performance issues",
            "Optimize addon load", "Requires UI reload first time"
        })

        diagContent:SetHeight(45)
        diagWrap:RecalcHeight()
        table.insert(allSections, diagWrap)

        -----------------------------------------------------------------------
        -- REAL-TIME MONITOR
        -----------------------------------------------------------------------
        local monWrap, monContent = W:CreateCollapsibleSection(sectionContainer, {
            text = "REAL-TIME MONITOR",
            startOpen = false,
            onCollapse = function() if RelayoutSections then RelayoutSections() end end,
        })

        local monitorBg = monContent:CreateTexture(nil, "BACKGROUND")
        monitorBg:SetColorTexture(0, 0, 0, 0.6)
        monitorBg:SetSize(380, 105)
        monitorBg:SetPoint("TOP", monContent, "TOP", 0, -5)

        local recentAvgText = monContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        recentAvgText:SetPoint("TOP", monitorBg, "TOP", -90, -10)

        local lastTickText = monContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lastTickText:SetPoint("TOP", recentAvgText, "BOTTOM", 0, -6)

        local peakText = monContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        peakText:SetPoint("TOP", lastTickText, "BOTTOM", 0, -6)

        local encounterText = monContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        encounterText:SetPoint("TOP", peakText, "BOTTOM", 0, -6)

        local profilerAvailable = C_AddOnProfiler and C_AddOnProfiler.GetAddOnMetric
        local startupTime = GetTime()
        local WARMUP_DELAY = 3
        local trackedPeak = 0

        local monitorFrame = CreateFrame("Frame", nil, monContent)
        monitorFrame.timer = 0
        monitorFrame:SetScript("OnUpdate", function(self, elapsed)
            self.timer = self.timer + elapsed
            if self.timer > 0.5 then
                if (GetTime() - startupTime) < WARMUP_DELAY then
                    recentAvgText:SetText(W.Colorize("Warming up...", C.GRAY))
                    lastTickText:SetText("")
                    peakText:SetText("")
                    encounterText:SetText("")
                    self.timer = 0
                    return
                end

                if not profilerAvailable then
                    recentAvgText:SetText(W.Colorize("Profiler unavailable", C.GRAY))
                    lastTickText:SetText("")
                    peakText:SetText("")
                    encounterText:SetText("")
                    self.timer = 0
                    return
                end

                local recentAvg = C_AddOnProfiler.GetAddOnMetric(addonName, 1)
                local lastTime  = C_AddOnProfiler.GetAddOnMetric(addonName, 3)
                local encAvg    = C_AddOnProfiler.GetAddOnMetric(addonName, 2)

                if lastTime > trackedPeak then
                    trackedPeak = lastTime
                end

                -- Recent average: green <0.5ms, orange 0.5-2ms, red >=2ms
                local avgColor = C.SUCCESS
                if recentAvg >= 2 then avgColor = C.ERROR
                elseif recentAvg >= 0.5 then avgColor = C.ORANGE end
                recentAvgText:SetText(W.Colorize("Avg (60 tick): ", C.BLUE)
                    .. W.Colorize(string_format("%.2f ms", recentAvg), avgColor))

                -- Last tick: green <1ms, orange 1-5ms, red >=5ms
                local lastColor = C.SUCCESS
                if lastTime >= 5 then lastColor = C.ERROR
                elseif lastTime >= 1 then lastColor = C.ORANGE end
                lastTickText:SetText(W.Colorize("Last Tick: ", C.BLUE)
                    .. W.Colorize(string_format("%.2f ms", lastTime), lastColor))

                -- Peak: green <1ms, orange 1-5ms, red >=5ms
                local peakColor = C.SUCCESS
                if trackedPeak >= 5 then peakColor = C.ERROR
                elseif trackedPeak >= 1 then peakColor = C.ORANGE end
                peakText:SetText(W.Colorize("Peak: ", C.BLUE)
                    .. W.Colorize(string_format("%.2f ms", trackedPeak), peakColor))

                -- Encounter average (only meaningful during/after a boss fight)
                if encAvg and encAvg > 0 then
                    local encColor = C.SUCCESS
                    if encAvg >= 2 then encColor = C.ERROR
                    elseif encAvg >= 0.5 then encColor = C.ORANGE end
                    encounterText:SetText(W.Colorize("Encounter Avg: ", C.BLUE)
                        .. W.Colorize(string_format("%.2f ms", encAvg), encColor))
                else
                    encounterText:SetText(W.Colorize("Encounter Avg: ", C.BLUE)
                        .. W.Colorize("--", C.GRAY))
                end

                self.timer = 0
            end
        end)

        monContent:SetHeight(115)
        monWrap:RecalcHeight()
        table.insert(allSections, monWrap)

        -----------------------------------------------------------------------
        -- Footer (only Reload UI button)
        -----------------------------------------------------------------------
        local footerContainer = CreateFrame("Frame", nil, sc)
        footerContainer:SetSize(460, 50)

        local relBtn = W:CreateButton(footerContainer, {
            text = W.Colorize("RELOAD ", C.ORANGE) .. W.Colorize("UI", C.BLUE),
            width = 160,
            height = 32,
            onClick = function() ReloadUI() end
        })
        relBtn:SetPoint("TOP", footerContainer, "TOP", 0, 0)

        -----------------------------------------------------------------------
        -- Relayout
        -----------------------------------------------------------------------
        RelayoutSections = function()
            for i, section in ipairs(allSections) do
                section:ClearAllPoints()
                if i == 1 then
                    section:SetPoint("TOPLEFT", sectionContainer, "TOPLEFT", 0, 0)
                else
                    section:SetPoint("TOPLEFT", allSections[i - 1], "BOTTOMLEFT", 0, -12)
                end
                section:SetPoint("RIGHT", sectionContainer, "RIGHT", 0, 0)
            end

            -- Position footer below last section
            footerContainer:ClearAllPoints()
            footerContainer:SetPoint("TOPLEFT", allSections[#allSections], "BOTTOMLEFT", 0, -20)
            footerContainer:SetPoint("RIGHT", sectionContainer, "RIGHT", 0, 0)

            -- Recalculate total scroll height
            local totalH = 75
            for _, s in ipairs(allSections) do
                totalH = totalH + s:GetHeight() + 12
            end
            totalH = totalH + footerContainer:GetHeight() + 40
            sc:SetHeight(math.max(totalH, 600))
            sectionContainer:SetHeight(totalH - 35)
        end

        RelayoutSections()
    end)
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

initFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if event == "ADDON_LOADED" and loadedAddon == addonName then
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)