local addonName, ns = ...

ns.LayoutUtil = {}

-- Calculate container size for a row/column of elements
-- @param count number - Number of elements
-- @param size number - Size of each element (width or height depending on direction)
-- @param spacing number - Space between elements
-- @param direction string - "RIGHT", "LEFT", "UP", or "DOWN"
-- @return width, height
function ns.LayoutUtil.CalculateContainerSize(count, size, spacing, direction)
    if count == 0 then return 1, 1 end

    local totalSize = (count * size) + ((count - 1) * spacing)

    if direction == "RIGHT" or direction == "LEFT" then
        return totalSize, size
    else -- UP or DOWN
        return size, totalSize
    end
end

-- Apply calculated size to a container frame based on child elements
-- @param container Frame - The container frame to resize
-- @param elements table - Array of child frames
-- @param size number - Size of each element
-- @param spacing number - Space between elements
-- @param direction string - Growth direction
function ns.LayoutUtil.AutoSizeContainer(container, elements, size, spacing, direction)
    local w, h = ns.LayoutUtil.CalculateContainerSize(#elements, size, spacing, direction)
    container:SetSize(w, h)
end

-- Position elements within a container with optional centering
-- @param container Frame - Parent container
-- @param elements table - Array of frames to position
-- @param size number - Size of each element
-- @param spacing number - Space between elements
-- @param direction string - "RIGHT", "LEFT", "UP", or "DOWN"
-- @param centered boolean - Whether to center elements within the container
function ns.LayoutUtil.LayoutElements(container, elements, size, spacing, direction, centered)
    if #elements == 0 then return end

    local totalSize = (#elements * size) + ((#elements - 1) * spacing)
    local startOffset = centered and (-(totalSize / 2) + (size / 2)) or 0

    for i, element in ipairs(elements) do
        element:ClearAllPoints()
        element:SetSize(size, size)

        local offset = startOffset + ((i - 1) * (size + spacing))

        if direction == "RIGHT" then
            element:SetPoint(centered and "CENTER" or "LEFT", container, centered and "CENTER" or "LEFT", offset, 0)
        elseif direction == "LEFT" then
            element:SetPoint(centered and "CENTER" or "RIGHT", container, centered and "CENTER" or "RIGHT", -offset, 0)
        elseif direction == "DOWN" then
            element:SetPoint(centered and "CENTER" or "TOP", container, centered and "CENTER" or "TOP", 0, -offset)
        elseif direction == "UP" then
            element:SetPoint(centered and "CENTER" or "BOTTOM", container, centered and "CENTER" or "BOTTOM", 0, offset)
        end
    end
end

-- Combined function to auto-size container and layout elements in one call
-- @param container Frame - Parent container
-- @param elements table - Array of frames to position
-- @param size number - Size of each element
-- @param spacing number - Space between elements
-- @param direction string - "RIGHT", "LEFT", "UP", or "DOWN"
-- @param centered boolean - Whether to center elements
function ns.LayoutUtil.AutoLayout(container, elements, size, spacing, direction, centered)
    ns.LayoutUtil.AutoSizeContainer(container, elements, size, spacing, direction)
    ns.LayoutUtil.LayoutElements(container, elements, size, spacing, direction, centered)
end

-- Match frame width to anchor frame with optional delay
-- @param frame Frame - Frame to resize
-- @param anchorFrame Frame - Frame to match width from
-- @param delay number - Delay before applying (default 0.1)
function ns.LayoutUtil.MatchAnchorWidth(frame, anchorFrame, delay)
    delay = delay or 0.1
    C_Timer.After(delay, function()
        if anchorFrame and anchorFrame:GetWidth() > 0 then
            frame:SetWidth(anchorFrame:GetWidth())
        end
    end)
end

-- Match frame height to anchor frame with optional delay
-- @param frame Frame - Frame to resize
-- @param anchorFrame Frame - Frame to match height from
-- @param delay number - Delay before applying (default 0.1)
function ns.LayoutUtil.MatchAnchorHeight(frame, anchorFrame, delay)
    delay = delay or 0.1
    C_Timer.After(delay, function()
        if anchorFrame and anchorFrame:GetHeight() > 0 then
            frame:SetHeight(anchorFrame:GetHeight())
        end
    end)
end

-- Create a throttled update function for performance
-- @param callback function - Function to call when throttle allows
-- @param interval number - Minimum time between calls (default 0.05)
-- @return function - Throttled version of the callback
function ns.LayoutUtil.CreateThrottledUpdater(callback, interval)
    interval = interval or 0.05
    local nextUpdate = 0

    return function(...)
        local now = GetTime()
        if now < nextUpdate then return end
        nextUpdate = now + interval
        callback(...)
    end
end

-- Frame scanning and anchor utilities

-- Curated list of anchor frames
local ANCHOR_FRAMES = {
    { text = "Screen (UIParent)", value = "UIParent" },
    -- Blizzard Unit Frames
    { text = "Player Frame", value = "PlayerFrame" },
    { text = "Target Frame", value = "TargetFrame" },
    { text = "Focus Frame", value = "FocusFrame" },
    { text = "Pet Frame", value = "PetFrame" },
    { text = "Minimap", value = "Minimap" },
    -- Blizzard Cooldown Viewers
    { text = "Buff Cooldown Viewer", value = "BuffIconCooldownViewer" },
    { text = "Essential Cooldown Viewer", value = "EssentialCooldownViewer" },
    { text = "Utility Cooldown Viewer", value = "UtilityCooldownViewer" },
}

-- Get the list of available anchor frames (only includes frames that exist)
-- @return table - Array of { text = "Display Name", value = "FrameName" }
function ns.LayoutUtil.GetAnchorFrameList()
    local frames = {}

    for _, entry in ipairs(ANCHOR_FRAMES) do
        -- UIParent always exists, others check if they exist
        if entry.value == "UIParent" or _G[entry.value] then
            frames[#frames + 1] = { text = entry.text, value = entry.value }
        end
    end

    return frames
end

-- Get a frame by name, with fallback to UIParent
-- @param frameName string - Name of the frame
-- @return Frame - The frame object or UIParent if not found
function ns.LayoutUtil.GetAnchorFrame(frameName)
    if not frameName or frameName == "UIParent" then
        return UIParent
    end

    local frame = _G[frameName]
    if frame and type(frame) == "table" and frame.GetObjectType then
        return frame
    end

    return UIParent
end

-- Standard anchor point options for dropdowns
ns.LayoutUtil.ANCHOR_POINTS = {
    { text = "Top Left",     value = "TOPLEFT" },
    { text = "Top",          value = "TOP" },
    { text = "Top Right",    value = "TOPRIGHT" },
    { text = "Left",         value = "LEFT" },
    { text = "Center",       value = "CENTER" },
    { text = "Right",        value = "RIGHT" },
    { text = "Bottom Left",  value = "BOTTOMLEFT" },
    { text = "Bottom",       value = "BOTTOM" },
    { text = "Bottom Right", value = "BOTTOMRIGHT" },
}
