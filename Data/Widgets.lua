local addonName, ns = ...
if not ns then return end

ns.Widgets = {}

ns.COLORS = {
    BLUE        = "018ee7",
    DARK_BLUE   = "007cca",
    ORANGE      = "ffa900",
    DARK_ORANGE = "f48e00",
    WHITE       = "ffffff",
    GRAY        = "aaaaaa",
    LIGHT_GRAY  = "cccccc",
    SUCCESS     = "00ff00",
    ERROR       = "ff0000",
    GREEN       = "00ff00",
    RED         = "ff0000",
}

function ns.Widgets.GetPlayerClassColor()
    local _, classFile = UnitClass("player")
    -- Use WoW's built-in RAID_CLASS_COLORS which handles all classes correctly
    local color = RAID_CLASS_COLORS[classFile]
    if color then
        return CreateColor(color.r, color.g, color.b, 1)
    end
    return CreateColor(1, 1, 1, 1)
end

-- Returns the effective color for display - class color if toggle is on, picker color otherwise
function ns.Widgets.GetEffectiveColor(db, rKey, gKey, bKey, classColorKey)
    if classColorKey and db[classColorKey] then
        local classColor = ns.Widgets.GetPlayerClassColor()
        return classColor.r, classColor.g, classColor.b
    end
    return db[rKey] or 1, db[gKey] or 1, db[bKey] or 1
end

-- Layout factory for consistent grid positioning
-- Usage:
--   local L = ns.Layout:New(2)  -- 2-column layout
--   local L = ns.Layout:New(1)  -- single column layout
--   L:Row(1), L:Col(1), L:Col(2)
--   L:Pos(row, col) returns x, y
ns.Layout = {
    ROW_HEIGHT = 50,    -- Default vertical spacing between rows
    ROW_START = -10,    -- Default first row Y offset
    WIDTH = 500,        -- Default content width
    -- Widget-specific Y offsets (relative to Row position)
    SLIDER_OFFSET = 0,      -- Sliders are the baseline
    COLOR_OFFSET = -10,     -- Color pickers align with slider track
    CHECKBOX_OFFSET = 5,    -- Checkboxes align slightly higher
    DROPDOWN_OFFSET = 0,    -- Dropdowns align with sliders
}

function ns.Layout:New(columns, opts)
    opts = opts or {}
    local layout = {
        columns = columns or 2,
        rowHeight = opts.rowHeight or self.ROW_HEIGHT,
        rowStart = opts.rowStart or self.ROW_START,
        width = opts.width or self.WIDTH,
        gap = opts.gap or 20,  -- gap between columns
    }

    -- Calculate column width and positions
    layout.colWidth = (layout.width - (layout.gap * (layout.columns - 1))) / layout.columns
    layout.colPositions = {}
    for i = 1, layout.columns do
        -- Add 20px offset to column 2+ to prevent overlap
        local offset = (i > 1) and 20 or 0
        layout.colPositions[i] = (i - 1) * (layout.colWidth + layout.gap) + offset
    end

    -- Get Y position for row (1-indexed)
    function layout:Row(n)
        return self.rowStart - ((n - 1) * self.rowHeight)
    end

    -- Get X position for column (1-indexed)
    function layout:Col(n)
        return self.colPositions[n] or 0
    end

    -- Get X, Y position for row and column
    function layout:Pos(row, col)
        return self:Col(col), self:Row(row)
    end

    -- Widget-specific Y positions that auto-align
    function layout:SliderY(row)
        return self:Row(row) + ns.Layout.SLIDER_OFFSET
    end

    function layout:ColorY(row)
        return self:Row(row) + ns.Layout.COLOR_OFFSET
    end

    function layout:CheckboxY(row)
        return self:Row(row) + ns.Layout.CHECKBOX_OFFSET
    end

    function layout:DropdownY(row)
        return self:Row(row) + ns.Layout.DROPDOWN_OFFSET
    end

    -- Calculate total height for n rows
    function layout:Height(rows)
        return (rows * self.rowHeight) + 10
    end

    return layout
end


function ns.Widgets.Colorize(text, hexColor)
    return "|cff" .. hexColor .. text .. "|r"
end

-- Legacy function for any remaining template-based checkboxes
function ns.Widgets.StyleCheckbox(cb)
    if not cb then return end
    local normal = cb:GetNormalTexture()
    if normal then
        normal:SetVertexColor(1.00, 0.66, 0.00, 1)
    end
    local highlight = cb:GetHighlightTexture()
    if highlight then
        highlight:SetVertexColor(1.00, 0.66, 0.00, 0.4)
    end
end

-- Shared color constants
local BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B = 0.01, 0.56, 0.91
local BTN_ORANGE_R, BTN_ORANGE_G, BTN_ORANGE_B = 1.00, 0.66, 0.00
local DARK_BG_R, DARK_BG_G, DARK_BG_B = 0.08, 0.08, 0.12

-- Central button creation function
-- opts: { text, width, height, parent, noStyle, onClick, font }
-- If width/height not provided, auto-fits to text with padding
function ns.Widgets:CreateButton(parent, opts)
    opts = opts or {}
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")

    -- Create label first to measure text
    local label = btn:CreateFontString(nil, "OVERLAY", opts.font or "GameFontNormalSmall")
    label:SetPoint("CENTER", 0, 0)
    label:SetText(opts.text or "")
    label:SetTextColor(1, 1, 1, 1)
    label:SetShadowOffset(1, -1)
    label:SetShadowColor(0, 0, 0, 0.8)
    btn.Text = label

    -- Auto-fit size to text if not specified
    local textWidth = label:GetStringWidth() or 50
    local textHeight = label:GetStringHeight() or 14
    local padding = 16
    local minWidth = 40
    local minHeight = 24

    local width = opts.width or math.max(textWidth + padding * 2, minWidth)
    local height = opts.height or math.max(textHeight + 10, minHeight)
    btn:SetSize(width, height)

    -- Apply styling unless explicitly disabled
    if not opts.noStyle then
        -- Main backdrop with inset for depth
        btn:SetBackdrop({
            bgFile = [[Interface\Buttons\WHITE8x8]],
            edgeFile = [[Interface\Buttons\WHITE8x8]],
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })

        -- Top highlight line for raised effect
        local topHighlight = btn:CreateTexture(nil, "BORDER")
        topHighlight:SetColorTexture(1, 1, 1, 0.15)
        topHighlight:SetPoint("TOPLEFT", 2, -2)
        topHighlight:SetPoint("TOPRIGHT", -2, -2)
        topHighlight:SetHeight(1)
        btn.topHighlight = topHighlight

        -- Bottom shadow for depth
        local bottomShadow = btn:CreateTexture(nil, "BORDER")
        bottomShadow:SetColorTexture(0, 0, 0, 0.3)
        bottomShadow:SetPoint("BOTTOMLEFT", 2, 2)
        bottomShadow:SetPoint("BOTTOMRIGHT", -2, 2)
        bottomShadow:SetHeight(1)
        btn.bottomShadow = bottomShadow

        -- Inner glow overlay
        local innerGlow = btn:CreateTexture(nil, "ARTWORK")
        innerGlow:SetColorTexture(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 0.1)
        innerGlow:SetPoint("TOPLEFT", 2, -2)
        innerGlow:SetPoint("BOTTOMRIGHT", -2, 2)
        btn.innerGlow = innerGlow

        local function SetNormalState(self)
            self:SetBackdropColor(0.08, 0.08, 0.12, 0.95)
            self:SetBackdropBorderColor(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 0.7)
            self.innerGlow:SetColorTexture(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 0.08)
            self.topHighlight:SetColorTexture(1, 1, 1, 0.12)
            self.Text:SetTextColor(1, 1, 1, 1)
        end

        local function SetHoverState(self)
            self:SetBackdropColor(0.12, 0.10, 0.08, 0.98)
            self:SetBackdropBorderColor(BTN_ORANGE_R, BTN_ORANGE_G, BTN_ORANGE_B, 0.9)
            self.innerGlow:SetColorTexture(BTN_ORANGE_R, BTN_ORANGE_G, BTN_ORANGE_B, 0.15)
            self.topHighlight:SetColorTexture(BTN_ORANGE_R, BTN_ORANGE_G, BTN_ORANGE_B, 0.25)
            self.Text:SetTextColor(1, 0.9, 0.8, 1)
        end

        local function SetPressedState(self)
            self:SetBackdropColor(0.06, 0.04, 0.02, 1)
            self:SetBackdropBorderColor(BTN_ORANGE_R, BTN_ORANGE_G, BTN_ORANGE_B, 1)
            self.innerGlow:SetColorTexture(BTN_ORANGE_R, BTN_ORANGE_G, BTN_ORANGE_B, 0.25)
            self.topHighlight:SetColorTexture(0, 0, 0, 0.2)
            self.Text:SetPoint("CENTER", 0, -1)
        end

        SetNormalState(btn)
        btn.isHovered = false

        btn:SetScript("OnEnter", function(self)
            self.isHovered = true
            SetHoverState(self)
        end)

        btn:SetScript("OnLeave", function(self)
            self.isHovered = false
            self.Text:SetPoint("CENTER", 0, 0)
            SetNormalState(self)
        end)

        btn:SetScript("OnMouseDown", function(self)
            SetPressedState(self)
        end)

        btn:SetScript("OnMouseUp", function(self)
            self.Text:SetPoint("CENTER", 0, 0)
            if self.isHovered then
                SetHoverState(self)
            else
                SetNormalState(self)
            end
        end)

        -- Disabled state support
        btn:HookScript("OnDisable", function(self)
            self:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
            self:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.5)
            self.innerGlow:SetColorTexture(0.2, 0.2, 0.2, 0.05)
            self.topHighlight:SetColorTexture(1, 1, 1, 0.03)
            self.Text:SetTextColor(0.5, 0.5, 0.5, 1)
        end)

        btn:HookScript("OnEnable", function(self)
            SetNormalState(self)
        end)
    end

    -- OnClick handler
    if opts.onClick then
        btn:SetScript("OnClick", opts.onClick)
    end

    -- SetText method that auto-resizes
    function btn:SetText(text)
        self.Text:SetText(text)
        if not opts.width then
            local tw = self.Text:GetStringWidth() or 50
            self:SetWidth(math.max(tw + padding * 2, minWidth))
        end
    end

    function btn:GetText()
        return self.Text:GetText()
    end

    return btn
end

-- Style existing UIPanelButtonTemplate buttons (for legacy code)
function ns.Widgets.StyleButton(btn)
    if not btn then return end

    btn:SetNormalTexture(nil)
    btn:SetPushedTexture(nil)
    btn:SetHighlightTexture(nil)
    btn:SetDisabledTexture(nil)

    if not btn.styledBackdrop then
        btn:SetBackdrop({
            bgFile = [[Interface\Buttons\WHITE8x8]],
            edgeFile = [[Interface\Buttons\WHITE8x8]],
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })

        -- Top highlight
        local topHighlight = btn:CreateTexture(nil, "BORDER")
        topHighlight:SetColorTexture(1, 1, 1, 0.12)
        topHighlight:SetPoint("TOPLEFT", 2, -2)
        topHighlight:SetPoint("TOPRIGHT", -2, -2)
        topHighlight:SetHeight(1)
        btn.topHighlight = topHighlight

        -- Bottom shadow
        local bottomShadow = btn:CreateTexture(nil, "BORDER")
        bottomShadow:SetColorTexture(0, 0, 0, 0.3)
        bottomShadow:SetPoint("BOTTOMLEFT", 2, 2)
        bottomShadow:SetPoint("BOTTOMRIGHT", -2, 2)
        bottomShadow:SetHeight(1)
        btn.bottomShadow = bottomShadow

        -- Inner glow
        local innerGlow = btn:CreateTexture(nil, "ARTWORK")
        innerGlow:SetColorTexture(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 0.08)
        innerGlow:SetPoint("TOPLEFT", 2, -2)
        innerGlow:SetPoint("BOTTOMRIGHT", -2, 2)
        btn.innerGlow = innerGlow

        btn.styledBackdrop = true
    end

    local text = btn:GetFontString()
    if text then
        text:SetTextColor(1, 1, 1, 1)
        text:SetShadowOffset(1, -1)
        text:SetShadowColor(0, 0, 0, 0.8)
    end

    local function SetNormalState(self)
        self:SetBackdropColor(0.08, 0.08, 0.12, 0.95)
        self:SetBackdropBorderColor(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 0.7)
        if self.innerGlow then self.innerGlow:SetColorTexture(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 0.08) end
        if self.topHighlight then self.topHighlight:SetColorTexture(1, 1, 1, 0.12) end
        local t = self:GetFontString()
        if t then t:SetTextColor(1, 1, 1, 1) end
    end

    local function SetHoverState(self)
        self:SetBackdropColor(0.12, 0.10, 0.08, 0.98)
        self:SetBackdropBorderColor(BTN_ORANGE_R, BTN_ORANGE_G, BTN_ORANGE_B, 0.9)
        if self.innerGlow then self.innerGlow:SetColorTexture(BTN_ORANGE_R, BTN_ORANGE_G, BTN_ORANGE_B, 0.15) end
        if self.topHighlight then self.topHighlight:SetColorTexture(BTN_ORANGE_R, BTN_ORANGE_G, BTN_ORANGE_B, 0.25) end
        local t = self:GetFontString()
        if t then t:SetTextColor(1, 0.9, 0.8, 1) end
    end

    SetNormalState(btn)
    btn.isHovered = false

    btn:HookScript("OnEnter", function(self)
        self.isHovered = true
        SetHoverState(self)
    end)

    btn:HookScript("OnLeave", function(self)
        self.isHovered = false
        SetNormalState(self)
    end)

    btn:HookScript("OnMouseDown", function(self)
        self:SetBackdropColor(0.06, 0.04, 0.02, 1)
        self:SetBackdropBorderColor(BTN_ORANGE_R, BTN_ORANGE_G, BTN_ORANGE_B, 1)
        if self.innerGlow then self.innerGlow:SetColorTexture(BTN_ORANGE_R, BTN_ORANGE_G, BTN_ORANGE_B, 0.25) end
        if self.topHighlight then self.topHighlight:SetColorTexture(0, 0, 0, 0.2) end
    end)

    btn:HookScript("OnMouseUp", function(self)
        if self.isHovered then
            SetHoverState(self)
        else
            SetNormalState(self)
        end
    end)
end

function ns.Widgets.ClearFrame(frame)
    local children = {frame:GetChildren()}
    for i = 1, #children do
        local child = children[i]
        if child then child:Hide() end
    end
    local regions = {frame:GetRegions()}
    for i = 1, #regions do
        local region = regions[i]
        if region then region:Hide() end
    end
end

--- Standard page header: title + subtitle + optional blue separator.
-- @param titleParts  string (pre-formatted) OR {{text, color}, ...}
-- @param subtitle    string (displayed as-is)
-- @param opts        { subtitleFont = "GameFontNormal", separator = true }
function ns.Widgets:CreatePageHeader(parent, titleParts, subtitle, opts)
    opts = opts or {}

    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOP", 0, -20)

    if type(titleParts) == "table" then
        local str = ""
        for _, p in ipairs(titleParts) do
            str = str .. ns.Widgets.Colorize(p[1], p[2])
        end
        title:SetText(str)
    else
        title:SetText(titleParts)
    end

    local sub = parent:CreateFontString(nil, "OVERLAY", opts.subtitleFont or "GameFontNormal")
    sub:SetPoint("TOP", title, "BOTTOM", 0, -5)
    sub:SetText(subtitle)

    local sep
    if opts.separator ~= false then
        sep = parent:CreateTexture(nil, "ARTWORK")
        sep:SetColorTexture(0.00, 0.56, 0.91, 0.6)
        sep:SetSize(400, 2)
        sep:SetPoint("TOP", sub, "BOTTOM", 0, -8)
    end

    return title, sub, sep
end

function ns.Widgets:CreateSectionHeader(parent, text, yOffset, opts)
    opts = opts or {}
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", opts.x or 30, yOffset)
    header:SetText(ns.Widgets.Colorize(text, ns.COLORS.ORANGE))

    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(1.00, 0.66, 0.00, 0.3)
    sep:SetSize(opts.width or 430, 1)
    sep:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)

    return header, sep
end

--- Collapsible section with header bar, optional enable toggle, and hideable content.
-- @param parent  the parent frame to attach to
-- @param opts    table with:
--   text       = "SECTION NAME"
--   db         = settings table (optional, required if enableKey set)
--   enableKey  = key in db for the enable toggle (nil = no toggle)
--   startOpen  = bool, default true
--   onToggle   = function(enabled) called when enable checkbox changes
--   onCollapse = function() called after collapse state changes
--   width      = wrapper width (default 460)
-- @return wrapper (Frame), contentFrame (Frame), enableCB (CheckButton|nil)
function ns.Widgets:CreateCollapsibleSection(parent, opts)
    opts = opts or {}
    local W = ns.Widgets
    local C = ns.COLORS
    local HEADER_H = 28
    local SEP_H = 1
    local PAD = 8

    local wrapper = CreateFrame("Frame", nil, parent)
    wrapper:SetWidth(opts.width or 460)

    -- Header bar background
    local headerBar = CreateFrame("Button", nil, wrapper, "BackdropTemplate")
    headerBar:SetHeight(HEADER_H)
    headerBar:SetPoint("TOPLEFT", 0, 0)
    headerBar:SetPoint("TOPRIGHT", 0, 0)
    headerBar:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
    headerBar:SetBackdropColor(0.10, 0.10, 0.10, 0.7)

    -- Collapse arrow
    local arrow = headerBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arrow:SetPoint("LEFT", 10, 0)

    -- Section title
    local headerText = headerBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    headerText:SetPoint("LEFT", arrow, "RIGHT", 6, 0)
    headerText:SetText(W.Colorize(opts.text or "SECTION", C.ORANGE))

    -- Orange separator
    local sep = wrapper:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(1.00, 0.66, 0.00, 0.3)
    sep:SetHeight(SEP_H)
    sep:SetPoint("TOPLEFT", headerBar, "BOTTOMLEFT", 0, 0)
    sep:SetPoint("TOPRIGHT", headerBar, "BOTTOMRIGHT", 0, 0)

    -- Enable toggle in header (optional)
    local enableCB
    if opts.enableKey and opts.db then
        enableCB = CreateFrame("CheckButton", nil, headerBar, "UICheckButtonTemplate")
        enableCB:SetSize(22, 22)
        enableCB:SetPoint("RIGHT", headerBar, "RIGHT", -8, 0)
        enableCB:SetChecked(opts.db[opts.enableKey])
        ns.Widgets.StyleCheckbox(enableCB)
        enableCB:SetScript("OnClick", function(self)
            local val = self:GetChecked() and true or false
            opts.db[opts.enableKey] = val
            if opts.onToggle then opts.onToggle(val) end
        end)
    end

    -- Content container
    local content = CreateFrame("Frame", nil, wrapper)
    content:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 0, -PAD)
    content:SetPoint("RIGHT", wrapper, "RIGHT", 0, 0)
    content:SetHeight(100) -- default, caller should override

    local isCollapsed = not (opts.startOpen ~= false)

    local function UpdateState()
        arrow:SetText(W.Colorize(isCollapsed and "+" or "-", C.ORANGE))
        if isCollapsed then
            content:Hide()
            wrapper:SetHeight(HEADER_H + SEP_H)
        else
            content:Show()
            wrapper:SetHeight(HEADER_H + SEP_H + PAD + content:GetHeight())
        end
        if opts.onCollapse then opts.onCollapse() end
    end

    headerBar:SetScript("OnClick", function()
        isCollapsed = not isCollapsed
        UpdateState()
    end)

    wrapper.RecalcHeight = function(self)
        if isCollapsed then
            wrapper:SetHeight(HEADER_H + SEP_H)
        else
            wrapper:SetHeight(HEADER_H + SEP_H + PAD + content:GetHeight())
        end
    end

    wrapper.SetCollapsed = function(self, collapsed)
        isCollapsed = collapsed
        UpdateState()
    end

    wrapper.IsCollapsed = function(self)
        return isCollapsed
    end

    UpdateState()
    return wrapper, content, enableCB
end

function ns.Widgets:CreateScrollFrame(parent, contentHeight)
    local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 0, 0)
    sf:SetPoint("BOTTOMRIGHT", -26, 0)

    local sc = CreateFrame("Frame", nil, sf)
    sc:SetWidth(sf:GetWidth() or 700)
    sc:SetHeight(contentHeight or 900)
    sf:SetScrollChild(sc)

    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local pos = self:GetVerticalScroll()
        local max = sc:GetHeight() - self:GetHeight()
        if max < 0 then max = 0 end
        local newPos = math.max(0, math.min(pos - (delta * 23), max))
        self:SetVerticalScroll(newPos)
    end)

    return sf, sc
end

-- buildFn is called once on first show
function ns.Widgets:CachedPanel(cache, key, parent, buildFn)
    if cache[key] then
        cache[key]:Hide()
    end
    if not cache[key] then
        cache[key] = CreateFrame("Frame", nil, parent)
        cache[key]:SetAllPoints()
        buildFn(cache[key])
    end
    cache[key]:Show()
    return cache[key]
end

-- Custom styled checkbox matching addon theme
-- opts: label, db, key, x, y, size, description, descWidth, onChange, isMaster, font, checked, point, tooltip
function ns.Widgets:CreateCheckbox(parent, opts)
    opts = opts or {}

    -- Sizes
    local boxSize = opts.size or (opts.isMaster and 22 or 18)
    local font = opts.font or (opts.isMaster and "GameFontNormal" or "GameFontNormalSmall")

    -- Create the checkbox frame (no template - fully custom)
    local cb = CreateFrame("CheckButton", nil, parent, "BackdropTemplate")
    cb:SetSize(boxSize, boxSize)

    -- Positioning
    local point = opts.point or "TOPLEFT"
    if opts.x or opts.y then
        cb:SetPoint(point, opts.x or 0, opts.y or 0)
    end

    -- Box backdrop
    cb:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]],
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })

    -- Inner glow texture
    local innerGlow = cb:CreateTexture(nil, "ARTWORK")
    innerGlow:SetColorTexture(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 0.08)
    innerGlow:SetPoint("TOPLEFT", 2, -2)
    innerGlow:SetPoint("BOTTOMRIGHT", -2, 2)
    cb.innerGlow = innerGlow

    -- Checkmark texture using WoW's built-in checkmark
    local check = cb:CreateTexture(nil, "OVERLAY")
    check:SetSize(boxSize * 1.4, boxSize * 1.4)
    check:SetPoint("CENTER", 1, 0)
    check:SetTexture([[Interface\Buttons\UI-CheckBox-Check]])
    check:SetVertexColor(1, 0.75, 0.1, 1)  -- Bright golden-orange
    check:Hide()
    cb.check = check

    -- Label text
    local label = cb:CreateFontString(nil, "OVERLAY", font)
    label:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    label:SetText(opts.label or "")
    label:SetTextColor(1, 1, 1, 1)
    label:SetShadowOffset(1, -1)
    label:SetShadowColor(0, 0, 0, 0.8)
    cb.Text = label

    -- State functions
    local function SetUncheckedState(self)
        self:SetBackdropColor(DARK_BG_R, DARK_BG_G, DARK_BG_B, 0.95)
        self:SetBackdropBorderColor(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 0.7)
        self.innerGlow:SetColorTexture(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 0.08)
        self.check:Hide()
    end

    local function SetCheckedState(self)
        self:SetBackdropColor(DARK_BG_R, DARK_BG_G, DARK_BG_B, 0.95)
        self:SetBackdropBorderColor(BTN_ORANGE_R, BTN_ORANGE_G, BTN_ORANGE_B, 0.9)
        self.innerGlow:SetColorTexture(BTN_ORANGE_R, BTN_ORANGE_G, BTN_ORANGE_B, 0.15)
        self.check:Show()
    end

    local function SetHoverState(self)
        if self:GetChecked() then
            self:SetBackdropBorderColor(BTN_ORANGE_R, BTN_ORANGE_G, BTN_ORANGE_B, 1)
            self.innerGlow:SetColorTexture(BTN_ORANGE_R, BTN_ORANGE_G, BTN_ORANGE_B, 0.25)
        else
            self:SetBackdropBorderColor(BTN_ORANGE_R, BTN_ORANGE_G, BTN_ORANGE_B, 0.7)
            self.innerGlow:SetColorTexture(BTN_ORANGE_R, BTN_ORANGE_G, BTN_ORANGE_B, 0.12)
        end
        self.Text:SetTextColor(1, 0.9, 0.8, 1)
    end

    local function UpdateVisualState(self)
        if self:GetChecked() then
            SetCheckedState(self)
        else
            SetUncheckedState(self)
        end
    end

    -- Initialize state
    cb.isHovered = false
    UpdateVisualState(cb)

    -- Mouse events
    cb:SetScript("OnEnter", function(self)
        self.isHovered = true
        SetHoverState(self)
        if opts.tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(opts.label, 1, 1, 1)
            GameTooltip:AddLine(opts.tooltip, nil, nil, nil, true)
            GameTooltip:Show()
        end
    end)

    cb:SetScript("OnLeave", function(self)
        self.isHovered = false
        UpdateVisualState(self)
        self.Text:SetTextColor(1, 1, 1, 1)
        if opts.tooltip then
            GameTooltip:Hide()
        end
    end)

    -- Click handling
    cb:SetScript("OnClick", function(self)
        local checked = self:GetChecked() and true or false
        UpdateVisualState(self)
        if self.isHovered then
            SetHoverState(self)
        end
        if opts.db and opts.key then
            opts.db[opts.key] = checked
        end
        if opts.onChange then
            opts.onChange(checked)
        end
        PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    end)

    -- Database binding - initial state
    if opts.db and opts.key then
        cb:SetChecked(opts.db[opts.key])
        UpdateVisualState(cb)
    elseif opts.checked ~= nil then
        cb:SetChecked(opts.checked)
        UpdateVisualState(cb)
    end

    -- Description text (inline hint)
    if opts.description then
        local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        desc:SetPoint("LEFT", label, "RIGHT", 8, 0)
        desc:SetText(ns.Widgets.Colorize(opts.description, ns.COLORS.GRAY))
        desc:SetWidth(opts.descWidth or 300)
        desc:SetJustifyH("LEFT")
        cb.desc = desc
    end

    -- Disabled state support
    cb:HookScript("OnDisable", function(self)
        self:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
        self:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.5)
        self.innerGlow:SetColorTexture(0.2, 0.2, 0.2, 0.05)
        self.Text:SetTextColor(0.5, 0.5, 0.5, 1)
        self.check:SetVertexColor(0.5, 0.5, 0.5, 1)
    end)

    cb:HookScript("OnEnable", function(self)
        UpdateVisualState(self)
        self.Text:SetTextColor(1, 1, 1, 1)
        self.check:SetVertexColor(1, 0.75, 0.1, 1)
    end)

    return cb
end

function ns.Widgets:CreateColorPicker(parent, opts)
    local btn = self:CreateButton(parent, {
        text = opts.label or "Choose Color",
        width = opts.width or 140,
        height = opts.height or 26
    })
    btn:SetPoint("TOPLEFT", opts.x or 40, opts.y)

    -- Auto-generate classColorKey if not provided (unless explicitly disabled)
    local classColorKey = opts.classColorKey
    if not classColorKey and not opts.noClassColor and opts.rKey then
        -- Derive from rKey: strip trailing "R" and append "UseClassColor"
        local base = opts.rKey:match("^(.-)R$") or opts.rKey
        classColorKey = base .. "UseClassColor"
    end

    local preview = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    preview:SetSize(26, 26)
    preview:SetPoint("LEFT", btn, "RIGHT", 10, 0)
    preview:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    preview:SetBackdropBorderColor(0, 0, 0, 1)

    -- Helper to update preview based on class toggle state
    local function UpdatePreview()
        local r, g, b = ns.Widgets.GetEffectiveColor(opts.db, opts.rKey, opts.gKey, opts.bKey, classColorKey)
        preview:SetBackdropColor(r, g, b, 1)
    end

    UpdatePreview()

    local thirdElement

    if classColorKey then
        -- Class color toggle using consistent styled checkbox
        local cb = self:CreateCheckbox(parent, {
            label = "Class",
            db = opts.db,
            key = classColorKey,
            size = 18,
            tooltip = "Use your class color instead of the picker color",
            onChange = function()
                UpdatePreview()
                if opts.onChange then
                    local r, g, b = ns.Widgets.GetEffectiveColor(opts.db, opts.rKey, opts.gKey, opts.bKey, classColorKey)
                    opts.onChange(r, g, b)
                end
            end
        })
        cb:ClearAllPoints()
        cb:SetPoint("LEFT", preview, "RIGHT", 6, 0)
        thirdElement = cb
    end

    btn:SetScript("OnClick", function()
        local _, classFile = UnitClass("player")
        ColorPickerFrame:SetupColorPickerAndShow({
            r = opts.db[opts.rKey] or 1,
            g = opts.db[opts.gKey] or 1,
            b = opts.db[opts.bKey] or 1,
            extraInfo = classFile,
            swatchFunc = function()
                local cr, cg, cb = ColorPickerFrame:GetColorRGB()
                opts.db[opts.rKey], opts.db[opts.gKey], opts.db[opts.bKey] = cr, cg, cb
                -- Only update preview directly if class toggle is off
                if not classColorKey or not opts.db[classColorKey] then
                    preview:SetBackdropColor(cr, cg, cb, 1)
                end
                if opts.onChange then opts.onChange(cr, cg, cb) end
            end,
            cancelFunc = function(prev)
                opts.db[opts.rKey], opts.db[opts.gKey], opts.db[opts.bKey] = prev.r, prev.g, prev.b
                if not classColorKey or not opts.db[classColorKey] then
                    preview:SetBackdropColor(prev.r, prev.g, prev.b, 1)
                end
                if opts.onChange then opts.onChange(prev.r, prev.g, prev.b) end
            end,
        })
    end)

    return btn, preview, thirdElement
end

-- Custom styled dropdown matching addon theme
-- opts: label, db, key, options, x, y, width, globalName, onChange
function ns.Widgets:CreateDropdown(parent, opts)
    opts = opts or {}
    local width = opts.width or 160
    local height = 22

    -- Container frame
    local f = CreateFrame("Frame", opts.globalName, parent)
    f:SetSize(width, opts.label and 40 or height)

    -- Positioning
    if opts.x or opts.y then
        f:SetPoint("TOPLEFT", opts.x or 0, opts.y or 0)
    end

    -- Label
    if opts.label then
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        title:SetPoint("TOPLEFT", 0, 0)
        title:SetText(opts.label:upper())
        title:SetTextColor(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 1)
        f.title = title
    end

    -- Normalize options to {text, value} format
    local normalized = {}
    for _, opt in ipairs(opts.options or {}) do
        if type(opt) == "table" then
            normalized[#normalized + 1] = opt
        else
            normalized[#normalized + 1] = { text = tostring(opt), value = opt }
        end
    end

    -- Dropdown button
    local btn = CreateFrame("Button", nil, f, "BackdropTemplate")
    btn:SetSize(width, height)
    btn:SetPoint("TOPLEFT", 0, opts.label and -18 or 0)
    btn:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]],
        edgeSize = 1,
    })
    btn:SetBackdropColor(DARK_BG_R, DARK_BG_G, DARK_BG_B, 0.95)
    btn:SetBackdropBorderColor(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 0.7)
    f.button = btn

    -- Selected text
    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", 8, 0)
    text:SetPoint("RIGHT", -20, 0)
    text:SetJustifyH("LEFT")
    text:SetTextColor(1, 1, 1, 1)
    btn.text = text

    -- Dropdown menu frame
    local menu = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
    menu:SetWidth(width)
    menu:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]],
        edgeSize = 1,
    })
    menu:SetBackdropColor(DARK_BG_R, DARK_BG_G, DARK_BG_B, 0.98)
    menu:SetBackdropBorderColor(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 0.7)
    menu:SetFrameStrata("DIALOG")
    menu:SetFrameLevel(100)
    menu:Hide()
    f.menu = menu

    -- Track menu state
    f.menuOpen = false

    -- Create menu items
    local menuItems = {}
    local itemHeight = 20
    for i, opt in ipairs(normalized) do
        local item = CreateFrame("Button", nil, menu, "BackdropTemplate")
        item:SetSize(width - 2, itemHeight)
        item:SetPoint("TOPLEFT", 1, -1 - (i - 1) * itemHeight)
        item:SetBackdrop({
            bgFile = [[Interface\Buttons\WHITE8x8]],
        })
        item:SetBackdropColor(0, 0, 0, 0)

        local itemText = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        itemText:SetPoint("LEFT", 8, 0)
        itemText:SetPoint("RIGHT", -8, 0)
        itemText:SetJustifyH("LEFT")
        itemText:SetText(opt.text)
        itemText:SetTextColor(1, 1, 1, 1)
        item.text = itemText

        item:SetScript("OnEnter", function(self)
            self:SetBackdropColor(BTN_ORANGE_R, BTN_ORANGE_G, BTN_ORANGE_B, 0.3)
        end)

        item:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0, 0, 0, 0)
        end)

        item:SetScript("OnClick", function()
            opts.db[opts.key] = opt.value
            text:SetText(opt.text)
            menu:Hide()
            f.menuOpen = false
            btn:SetBackdropBorderColor(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 0.7)
            if opts.onChange then opts.onChange(opt.value) end
        end)

        menuItems[i] = item
    end

    menu:SetHeight(#normalized * itemHeight + 2)

    -- Set initial value
    local currentVal = opts.db and opts.db[opts.key]
    for i, opt in ipairs(normalized) do
        if opt.value == currentVal then
            text:SetText(opt.text)
            break
        end
    end

    -- Toggle menu on click
    btn:SetScript("OnClick", function()
        if f.menuOpen then
            menu:Hide()
            f.menuOpen = false
            btn:SetBackdropBorderColor(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 0.7)
        else
            menu:Show()
            f.menuOpen = true
            btn:SetBackdropBorderColor(BTN_ORANGE_R, BTN_ORANGE_G, BTN_ORANGE_B, 0.9)
        end
    end)

    -- Hover states
    btn:SetScript("OnEnter", function(self)
        if not f.menuOpen then
            self:SetBackdropBorderColor(BTN_ORANGE_R, BTN_ORANGE_G, BTN_ORANGE_B, 0.9)
        end
    end)

    btn:SetScript("OnLeave", function(self)
        if not f.menuOpen then
            self:SetBackdropBorderColor(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 0.7)
        end
    end)

    -- Close menu when clicking elsewhere
    menu:SetScript("OnShow", function()
        menu:SetPropagateKeyboardInput(true)
    end)

    -- Global click handler to close menu
    btn:RegisterForClicks("AnyUp")
    menu:SetScript("OnHide", function()
        f.menuOpen = false
        btn:SetBackdropBorderColor(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 0.7)
    end)

    -- Close on world click
    f:SetScript("OnUpdate", function()
        if f.menuOpen and not menu:IsMouseOver() and not btn:IsMouseOver() then
            if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then
                menu:Hide()
            end
        end
    end)

    return f
end


-- Custom styled slider matching addon theme
-- opts: label, min, max, step, x, y, width, isPercent, db, key, showEditBox, showValueText, onChange, uppercase
function ns.Widgets:CreateSlider(parent, opts)
    opts = opts or {}
    local step = opts.step or 1
    local min = opts.min or 0
    local max = opts.max or 100
    local width = opts.width or 180
    local height = 12

    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width + 60, 50)

    -- Positioning
    if opts.x or opts.y then
        f:SetPoint("TOPLEFT", opts.x or 0, opts.y or 0)
    end

    -- Title label
    local title
    if opts.label then
        title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        title:SetPoint("TOPLEFT", 0, 0)
        local labelText = opts.uppercase ~= false and opts.label:upper() or opts.label
        title:SetText(labelText)
        title:SetTextColor(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 1)
        f.title = title
    end

    -- Create custom slider (no template)
    local s = CreateFrame("Slider", nil, f, "BackdropTemplate")
    s:SetPoint("TOPLEFT", 0, opts.label and -18 or 0)
    s:SetSize(width, height)
    s:SetOrientation("HORIZONTAL")
    s:SetMinMaxValues(min, max)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:EnableMouseWheel(true)

    -- Track background
    s:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]],
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    s:SetBackdropColor(DARK_BG_R, DARK_BG_G, DARK_BG_B, 0.95)
    s:SetBackdropBorderColor(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 0.7)

    -- Fill bar (shows progress)
    local fill = s:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 2, -2)
    fill:SetHeight(height - 4)
    fill:SetColorTexture(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 0.4)
    s.fill = fill

    -- Thumb texture (use the slider's actual thumb for proper mouse interaction)
    s:SetThumbTexture([[Interface\Buttons\WHITE8x8]])
    local thumbTex = s:GetThumbTexture()
    thumbTex:SetSize(14, height + 6)
    thumbTex:SetVertexColor(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 0.9)
    s.thumbTex = thumbTex

    -- Thumb border overlay (visual only, doesn't block mouse)
    local thumbBorder = s:CreateTexture(nil, "OVERLAY")
    thumbBorder:SetSize(14, height + 6)
    thumbBorder:SetColorTexture(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 0.9)
    s.thumbBorder = thumbBorder

    -- Update fill width and thumb border position
    local function UpdateThumbPosition()
        local val = s:GetValue()
        local pct = (max > min) and ((val - min) / (max - min)) or 0
        local trackWidth = width - 4
        local fillWidth = math.max(1, pct * trackWidth)
        fill:SetWidth(fillWidth)
        -- Position border to match thumb
        thumbBorder:ClearAllPoints()
        thumbBorder:SetPoint("CENTER", thumbTex, "CENTER", 0, 0)
    end

    -- Hover and drag states
    s.isHovered = false
    s.isDragging = false

    local function SetActiveColor(self)
        self:SetBackdropBorderColor(BTN_ORANGE_R, BTN_ORANGE_G, BTN_ORANGE_B, 0.9)
        self.fill:SetColorTexture(BTN_ORANGE_R, BTN_ORANGE_G, BTN_ORANGE_B, 0.5)
        self.thumbTex:SetVertexColor(BTN_ORANGE_R, BTN_ORANGE_G, BTN_ORANGE_B, 1)
        self.thumbBorder:SetColorTexture(BTN_ORANGE_R, BTN_ORANGE_G, BTN_ORANGE_B, 1)
    end

    local function SetInactiveColor(self)
        self:SetBackdropBorderColor(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 0.7)
        self.fill:SetColorTexture(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 0.4)
        self.thumbTex:SetVertexColor(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 0.9)
        self.thumbBorder:SetColorTexture(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 0.9)
    end

    s:SetScript("OnEnter", function(self)
        self.isHovered = true
        SetActiveColor(self)
    end)

    s:SetScript("OnLeave", function(self)
        self.isHovered = false
        if not self.isDragging then
            SetInactiveColor(self)
        end
    end)

    s:HookScript("OnMouseDown", function(self)
        self.isDragging = true
        SetActiveColor(self)
    end)

    s:HookScript("OnMouseUp", function(self)
        self.isDragging = false
        if not self.isHovered then
            SetInactiveColor(self)
        end
    end)

    -- Mouse wheel support
    s:SetScript("OnMouseWheel", function(self, delta)
        local val = self:GetValue() + (delta * step)
        val = math.max(min, math.min(max, val))
        self:SetValue(val)
    end)

    -- Value display (editbox or text)
    local valueDisplay
    if opts.showEditBox ~= false then
        local eb = CreateFrame("EditBox", nil, f, "BackdropTemplate")
        eb:SetSize(45, 20)
        eb:SetPoint("LEFT", s, "RIGHT", 10, 0)
        eb:SetBackdrop({
            bgFile = [[Interface\Buttons\WHITE8x8]],
            edgeFile = [[Interface\Buttons\WHITE8x8]],
            edgeSize = 1
        })
        eb:SetBackdropColor(DARK_BG_R, DARK_BG_G, DARK_BG_B, 0.95)
        eb:SetBackdropBorderColor(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 0.5)
        eb:SetFontObject("GameFontHighlightSmall")
        eb:SetJustifyH("CENTER")
        eb:SetAutoFocus(false)
        eb:SetTextColor(1, 1, 1, 1)

        eb:SetScript("OnEnterPressed", function(self)
            local txt = self:GetText():gsub("%%", "")
            local val = tonumber(txt)
            if val then
                val = math.max(min, math.min(max, val))
                s:SetValue(val)
            end
            self:ClearFocus()
        end)

        eb:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)

        eb:SetScript("OnEditFocusGained", function(self)
            self:SetBackdropBorderColor(BTN_ORANGE_R, BTN_ORANGE_G, BTN_ORANGE_B, 0.8)
        end)

        eb:SetScript("OnEditFocusLost", function(self)
            self:SetBackdropBorderColor(BTN_BLUE_R, BTN_BLUE_G, BTN_BLUE_B, 0.5)
        end)

        valueDisplay = eb
        f.editBox = eb
    elseif opts.showValueText then
        local vt = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        vt:SetPoint("LEFT", s, "RIGHT", 10, 0)
        valueDisplay = vt
        f.valueText = vt
    end

    -- Format value for display
    local function FormatValue(val)
        if opts.isPercent then
            return string.format("%.0f%%", val)
        elseif step < 1 then
            return string.format("%.2f", val)
        else
            return string.format("%.0f", val)
        end
    end

    -- Value changed handler
    s:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val / step + 0.5) * step
        UpdateThumbPosition()
        if valueDisplay and valueDisplay.SetText then
            valueDisplay:SetText(FormatValue(val))
        end
        if opts.db and opts.key then
            opts.db[opts.key] = val
        end
        if opts.onChange then opts.onChange(val) end
    end)

    -- Initialize from db → module defaults → warn if missing
    local initVal
    if opts.db and opts.key then
        if opts.db[opts.key] ~= nil then
            -- Value exists in db
            initVal = opts.db[opts.key]
        elseif opts.moduleName and ns.ModuleDefaults[opts.moduleName] then
            -- Fall back to module defaults
            local defaults = ns.ModuleDefaults[opts.moduleName]
            if defaults[opts.key] ~= nil then
                initVal = defaults[opts.key]
                opts.db[opts.key] = initVal  -- Populate db with default
            else
                -- Missing default - warn and use slider min
                print("|cffff6600NaowhQOL:|r Missing default for " .. (opts.moduleName or "?") .. "." .. opts.key)
                initVal = min
            end
        else
            -- No module defaults available, use slider min
            initVal = min
        end
    elseif opts.value ~= nil then
        initVal = opts.value
    else
        initVal = min
    end
    s:SetValue(initVal)
    UpdateThumbPosition()

    -- Ensure initial display is set (OnValueChanged may not fire if value equals default)
    if valueDisplay and valueDisplay.SetText then
        valueDisplay:SetText(FormatValue(initVal))
    end

    f.slider = s
    f.GetValue = function() return s:GetValue() end
    f.SetValue = function(_, val) s:SetValue(val) end

    return f
end

-- Legacy signature for backwards compatibility - wraps new CreateSlider
-- Can pass opts table as 9th param with db, key, moduleName for proper default handling
function ns.Widgets:CreateAdvancedSlider(parent, label, min, max, yOffset, step, isPercent, callback, opts)
    opts = opts or {}
    local wrapper = self:CreateSlider(parent, {
        label = label,
        min = min,
        max = max,
        step = step or 1,
        isPercent = isPercent,
        onChange = callback,
        db = opts.db,
        key = opts.key,
        moduleName = opts.moduleName,
        value = opts.value,
    })
    wrapper:ClearAllPoints()
    wrapper:SetPoint("TOP", parent, "TOP", 0, yOffset)
    return wrapper.slider
end

function ns.Widgets:CreateSoundPicker(parent, x, y, currentSound, onSelect)
    -- currentSound can be: number (legacy ID), {id=N}, or {path="..."}
    local VISIBLE_ROWS = 12
    local ROW_H = 20
    local FILTER_H = 20
    local WIDTH = 260

    -- Normalize legacy format
    if type(currentSound) == "number" then
        currentSound = { id = currentSound }
    end
    currentSound = currentSound or { id = 8959 }

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(WIDTH, 28)
    frame:SetPoint("TOPLEFT", x, y)

    local selBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    selBtn:SetSize(WIDTH, 26)
    selBtn:SetPoint("TOPLEFT")
    selBtn:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
    selBtn:SetBackdropColor(0.08, 0.08, 0.08, 1)
    selBtn:SetBackdropBorderColor(0, 0, 0, 1)

    local selText = selBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    selText:SetPoint("LEFT", 8, 0); selText:SetPoint("RIGHT", -24, 0)
    selText:SetJustifyH("LEFT")

    local arrow = selBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arrow:SetPoint("RIGHT", -6, 0); arrow:SetText("|cffffa900v|r")

    local panel = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    panel:SetSize(WIDTH, FILTER_H + ROW_H + VISIBLE_ROWS * ROW_H + 10)
    panel:SetPoint("TOPLEFT", selBtn, "BOTTOMLEFT", 0, -2)
    panel:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
    panel:SetBackdropColor(0.06, 0.06, 0.06, 0.98)
    panel:SetBackdropBorderColor(0, 0, 0, 1)
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
    panel:SetFrameLevel(100)
    panel:Hide()

    -- Click-outside overlay to dismiss the dropdown
    local overlay = CreateFrame("Button", nil, UIParent)
    overlay:SetAllPoints(UIParent)
    overlay:SetFrameStrata("FULLSCREEN_DIALOG")
    overlay:SetFrameLevel(99)
    overlay:Hide()
    overlay:SetScript("OnClick", function() panel:Hide() end)
    panel:SetScript("OnShow", function() overlay:Show() end)
    panel:SetScript("OnHide", function() overlay:Hide() end)

    -- Source filter dropdown
    local currentFilter = "All"
    local filterBtn = CreateFrame("Button", nil, panel, "BackdropTemplate")
    filterBtn:SetSize(WIDTH - 8, FILTER_H)
    filterBtn:SetPoint("TOPLEFT", 4, -4)
    filterBtn:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
    filterBtn:SetBackdropColor(0.12, 0.12, 0.12, 1)
    filterBtn:SetBackdropBorderColor(0, 0, 0, 1)

    local filterText = filterBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    filterText:SetPoint("LEFT", 6, 0); filterText:SetPoint("RIGHT", -20, 0)
    filterText:SetJustifyH("LEFT"); filterText:SetText("All")

    local filterArrow = filterBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    filterArrow:SetPoint("RIGHT", -4, 0); filterArrow:SetText("|cffffa900v|r")

    -- Filter dropdown menu (floats above panel)
    local filterMenu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    filterMenu:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
    filterMenu:SetBackdropColor(0.1, 0.1, 0.1, 1)
    filterMenu:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    filterMenu:SetFrameStrata("TOOLTIP")
    filterMenu:SetFrameLevel(200)
    filterMenu:Hide()

    local filterRows = {}
    local Filter  -- Forward declaration
    local function BuildFilterMenu()
        local sources = ns.SoundList.GetSources()
        filterMenu:SetSize(WIDTH - 8, #sources * 18 + 4)
        filterMenu:SetPoint("TOPLEFT", filterBtn, "BOTTOMLEFT", 0, -1)

        for i, src in ipairs(sources) do
            if not filterRows[i] then
                local row = CreateFrame("Button", nil, filterMenu, "BackdropTemplate")
                row:SetSize(WIDTH - 12, 18)
                row:SetPoint("TOPLEFT", 2, -(i - 1) * 18 - 2)
                row:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
                row:SetBackdropColor(0, 0, 0, 0)
                row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.label:SetPoint("LEFT", 4, 0)
                row:SetScript("OnEnter", function(self) self:SetBackdropColor(0.2, 0.5, 0.8, 0.3) end)
                row:SetScript("OnLeave", function(self) self:SetBackdropColor(0, 0, 0, 0) end)
                filterRows[i] = row
            end
            filterRows[i].label:SetText(src)
            filterRows[i]:SetScript("OnClick", function()
                currentFilter = src
                filterText:SetText(src)
                filterMenu:Hide()
                Filter()
            end)
            filterRows[i]:Show()
        end
        for i = #sources + 1, #filterRows do
            filterRows[i]:Hide()
        end
    end

    filterBtn:SetScript("OnClick", function()
        if filterMenu:IsShown() then
            filterMenu:Hide()
        else
            BuildFilterMenu()
            filterMenu:Show()
        end
    end)

    local search = CreateFrame("EditBox", nil, panel, "BackdropTemplate")
    search:SetSize(WIDTH - 8, 18)
    search:SetPoint("TOPLEFT", 4, -(FILTER_H + 6))
    search:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
    search:SetBackdropColor(0, 0, 0, 1)
    search:SetBackdropBorderColor(0, 0, 0, 1)
    search:SetFontObject("GameFontHighlightSmall")
    search:SetAutoFocus(false)
    search:SetTextInsets(4, 4, 0, 0)

    local placeholder = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", 6, 0); placeholder:SetText("Search sounds...")
    search:SetScript("OnEditFocusGained", function() placeholder:Hide(); filterMenu:Hide() end)
    search:SetScript("OnEditFocusLost", function()
        if search:GetText() == "" then placeholder:Show() end
    end)

    local listArea = CreateFrame("Frame", nil, panel)
    listArea:SetPoint("TOPLEFT", 4, -(FILTER_H + ROW_H + 8))
    listArea:SetSize(WIDTH - 8, VISIBLE_ROWS * ROW_H)
    listArea:EnableMouseWheel(true)

    local rows = {}
    local filtered = {}
    local scrollOff = 0

    local function BuildRows()
        for i = 1, VISIBLE_ROWS do
            if rows[i] then break end
            local row = CreateFrame("Button", nil, listArea, "BackdropTemplate")
            row:SetSize(WIDTH - 8, ROW_H)
            row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
            row:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
            row:SetBackdropColor(0, 0, 0, 0)

            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.label:SetPoint("LEFT", 6, 0); row.label:SetPoint("RIGHT", -30, 0)
            row.label:SetJustifyH("LEFT")

            row.play = CreateFrame("Button", nil, row)
            row.play:SetSize(20, ROW_H)
            row.play:SetPoint("RIGHT")
            row.play.tex = row.play:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.play.tex:SetPoint("CENTER"); row.play.tex:SetText("|cff66ccff>|r")

            row:SetScript("OnEnter", function(self) self:SetBackdropColor(0.2, 0.5, 0.8, 0.3) end)
            row:SetScript("OnLeave", function(self) self:SetBackdropColor(0, 0, 0, 0) end)

            rows[i] = row
        end
    end

    local function Refresh()
        BuildRows()
        for i = 1, VISIBLE_ROWS do
            local idx = filtered[scrollOff + i]
            local row = rows[i]
            if idx then
                local entry = ns.SoundList[idx]
                row.label:SetText(entry.name)
                row.label:SetTextColor(unpack(entry.color))
                row:SetScript("OnClick", function()
                    currentSound = entry.id and { id = entry.id } or { path = entry.path }
                    selText:SetText(entry.name)
                    panel:Hide()
                    if onSelect then onSelect(entry) end
                end)
                row.play:SetScript("OnClick", function()
                    ns.SoundList.Play(entry)
                end)
                row:Show()
            else
                row:Hide()
            end
        end
    end

    Filter = function()
        filtered = {}
        local q = strlower(strtrim(search:GetText()))
        for i, entry in ipairs(ns.SoundList) do
            local matchesSearch = q == "" or strlower(entry.name):find(q, 1, true)
            local matchesSource = currentFilter == "All" or entry.source == currentFilter
            if matchesSearch and matchesSource then
                filtered[#filtered + 1] = i
            end
        end
        scrollOff = 0
        Refresh()
    end

    search:SetScript("OnTextChanged", function() Filter() end)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus(); panel:Hide() end)

    listArea:SetScript("OnMouseWheel", function(_, delta)
        scrollOff = math.max(0, math.min(scrollOff - delta, math.max(0, #filtered - VISIBLE_ROWS)))
        Refresh()
    end)

    selBtn:SetScript("OnClick", function()
        if panel:IsShown() then
            panel:Hide()
        else
            currentFilter = "All"
            filterText:SetText("All")
            search:SetText(""); placeholder:Show(); Filter()
            panel:Show(); search:SetFocus()
        end
    end)

    -- Legacy support: SetSoundID accepts number or {id=...}/{path=...}
    local function SetSound(_, sound)
        if type(sound) == "number" then
            currentSound = { id = sound }
        else
            currentSound = sound
        end
        local entry = ns.SoundList.GetEntry(currentSound)
        selText:SetText(entry and entry.name or "Unknown")
    end

    frame.SetSound = SetSound
    frame.SetSoundID = SetSound  -- Legacy alias
    frame.GetSound = function() return currentSound end
    frame.GetSoundID = function() return currentSound.id end  -- Legacy alias

    -- Initialize display text
    local initEntry = ns.SoundList.GetEntry(currentSound)
    selText:SetText(initEntry and initEntry.name or "Unknown")

    return frame
end

function ns.Widgets:CreateFontPicker(parent, x, y, currentPath, onSelect)
    local VISIBLE_ROWS = 12
    local ROW_H = 22
    local WIDTH = 260
    local PREVIEW_SIZE = 12

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(WIDTH, 28)
    frame:SetPoint("TOPLEFT", x, y)

    -- Selection button (shows current font name)
    local selBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    selBtn:SetSize(WIDTH, 26)
    selBtn:SetPoint("TOPLEFT")
    selBtn:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
    selBtn:SetBackdropColor(0.08, 0.08, 0.08, 1)
    selBtn:SetBackdropBorderColor(0, 0, 0, 1)

    local selText = selBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    selText:SetPoint("LEFT", 8, 0); selText:SetPoint("RIGHT", -24, 0)
    selText:SetJustifyH("LEFT")

    local arrow = selBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arrow:SetPoint("RIGHT", -6, 0); arrow:SetText("|cffffa900v|r")

    -- Dropdown panel (hidden by default)
    local panel = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    panel:SetSize(WIDTH, ROW_H + VISIBLE_ROWS * ROW_H + 6)
    panel:SetPoint("TOPLEFT", selBtn, "BOTTOMLEFT", 0, -2)
    panel:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
    panel:SetBackdropColor(0.06, 0.06, 0.06, 0.98)
    panel:SetBackdropBorderColor(0, 0, 0, 1)
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
    panel:SetFrameLevel(100)
    panel:Hide()

    -- Click-outside overlay to dismiss the dropdown
    local overlay = CreateFrame("Button", nil, UIParent)
    overlay:SetAllPoints(UIParent)
    overlay:SetFrameStrata("FULLSCREEN_DIALOG")
    overlay:SetFrameLevel(99)
    overlay:Hide()
    overlay:SetScript("OnClick", function() panel:Hide() end)
    panel:SetScript("OnShow", function() overlay:Show() end)
    panel:SetScript("OnHide", function() overlay:Hide() end)

    -- Search box
    local search = CreateFrame("EditBox", nil, panel, "BackdropTemplate")
    search:SetSize(WIDTH - 8, 18)
    search:SetPoint("TOPLEFT", 4, -4)
    search:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
    search:SetBackdropColor(0, 0, 0, 1)
    search:SetBackdropBorderColor(0, 0, 0, 1)
    search:SetFontObject("GameFontHighlightSmall")
    search:SetAutoFocus(false)
    search:SetTextInsets(4, 4, 0, 0)

    local placeholder = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", 6, 0); placeholder:SetText("Search fonts...")
    search:SetScript("OnEditFocusGained", function() placeholder:Hide() end)
    search:SetScript("OnEditFocusLost", function()
        if search:GetText() == "" then placeholder:Show() end
    end)

    -- List display area
    local listArea = CreateFrame("Frame", nil, panel)
    listArea:SetPoint("TOPLEFT", 4, -(ROW_H + 4))
    listArea:SetSize(WIDTH - 8, VISIBLE_ROWS * ROW_H)
    listArea:EnableMouseWheel(true)

    local rows = {}
    local filtered = {}
    local scrollOff = 0

    local function ApplyFont(fontString, fontPath)
        local ok = pcall(fontString.SetFont, fontString, fontPath, PREVIEW_SIZE, "")
        if not ok then
            fontString:SetFontObject("GameFontHighlightSmall")
        end
    end

    -- Build row buttons (created once, reused)
    local function BuildRows()
        for i = 1, VISIBLE_ROWS do
            if rows[i] then break end
            local row = CreateFrame("Button", nil, listArea, "BackdropTemplate")
            row:SetSize(WIDTH - 8, ROW_H)
            row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
            row:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
            row:SetBackdropColor(0, 0, 0, 0)

            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.label:SetPoint("LEFT", 6, 0); row.label:SetPoint("RIGHT", -36, 0)
            row.label:SetJustifyH("LEFT")

            -- "Aa" preview rendered in the row's font
            row.preview = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.preview:SetPoint("RIGHT", -6, 0)
            row.preview:SetText("|cff66ccffAa|r")

            row:SetScript("OnEnter", function(self) self:SetBackdropColor(0.2, 0.5, 0.8, 0.3) end)
            row:SetScript("OnLeave", function(self) self:SetBackdropColor(0, 0, 0, 0) end)

            rows[i] = row
        end
    end

    -- Refresh display with current filtered results
    local function Refresh()
        BuildRows()
        for i = 1, VISIBLE_ROWS do
            local idx = filtered[scrollOff + i]
            local row = rows[i]
            if idx then
                local entry = ns.FontList[idx]
                ApplyFont(row.label, entry.path)
                row.label:SetText(entry.name)
                ApplyFont(row.preview, entry.path)
                row:SetScript("OnClick", function()
                    currentPath = entry.path
                    selText:SetText(entry.name)
                    panel:Hide()
                    if onSelect then onSelect(entry.path, entry.name) end
                end)
                row:Show()
            else
                row:Hide()
            end
        end
    end

    -- Filter list by search query
    local function Filter()
        filtered = {}
        local q = strlower(strtrim(search:GetText()))
        for i, entry in ipairs(ns.FontList) do
            if q == "" or strlower(entry.name):find(q, 1, true) then
                filtered[#filtered + 1] = i
            end
        end
        scrollOff = 0
        Refresh()
    end

    search:SetScript("OnTextChanged", function() Filter() end)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus(); panel:Hide() end)

    -- Mouse wheel scrolling
    listArea:SetScript("OnMouseWheel", function(_, delta)
        scrollOff = math.max(0, math.min(scrollOff - delta, math.max(0, #filtered - VISIBLE_ROWS)))
        Refresh()
    end)

    -- Toggle dropdown
    selBtn:SetScript("OnClick", function()
        if panel:IsShown() then
            panel:Hide()
        else
            ns.FontList.Rebuild()
            search:SetText(""); placeholder:Show(); Filter()
            panel:Show(); search:SetFocus()
        end
    end)

    -- Public API
    local function SetFontPath(_, path)
        currentPath = path
        selText:SetText(ns.FontList.GetName(path))
    end

    frame.SetFontPath = SetFontPath
    frame.GetFontPath = function() return currentPath end

    selText:SetText(ns.FontList.GetName(currentPath or "Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf"))

    return frame
end

function ns.Widgets:CreateBarStylePicker(parent, x, y, currentPath, onSelect)
    local VISIBLE_ROWS = 6
    local ROW_H = 24
    local WIDTH = 260
    local SWATCH_H = 12

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(WIDTH, 28)
    frame:SetPoint("TOPLEFT", x, y)

    -- Selection button (shows current bar style name)
    local selBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    selBtn:SetSize(WIDTH, 26)
    selBtn:SetPoint("TOPLEFT")
    selBtn:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
    selBtn:SetBackdropColor(0.08, 0.08, 0.08, 1)
    selBtn:SetBackdropBorderColor(0, 0, 0, 1)

    local selText = selBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    selText:SetPoint("LEFT", 8, 0); selText:SetPoint("RIGHT", -24, 0)
    selText:SetJustifyH("LEFT")

    local arrow = selBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arrow:SetPoint("RIGHT", -6, 0); arrow:SetText("|cffffa900v|r")

    -- Dropdown panel (hidden by default)
    local panel = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    panel:SetSize(WIDTH, ROW_H + VISIBLE_ROWS * ROW_H + 6)
    panel:SetPoint("TOPLEFT", selBtn, "BOTTOMLEFT", 0, -2)
    panel:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
    panel:SetBackdropColor(0.06, 0.06, 0.06, 0.98)
    panel:SetBackdropBorderColor(0, 0, 0, 1)
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
    panel:SetFrameLevel(100)
    panel:Hide()

    -- Click-outside overlay to dismiss the dropdown
    local overlay = CreateFrame("Button", nil, UIParent)
    overlay:SetAllPoints(UIParent)
    overlay:SetFrameStrata("FULLSCREEN_DIALOG")
    overlay:SetFrameLevel(99)
    overlay:Hide()
    overlay:SetScript("OnClick", function() panel:Hide() end)
    panel:SetScript("OnShow", function() overlay:Show() end)
    panel:SetScript("OnHide", function() overlay:Hide() end)

    -- Search box
    local search = CreateFrame("EditBox", nil, panel, "BackdropTemplate")
    search:SetSize(WIDTH - 8, 18)
    search:SetPoint("TOPLEFT", 4, -4)
    search:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
    search:SetBackdropColor(0, 0, 0, 1)
    search:SetBackdropBorderColor(0, 0, 0, 1)
    search:SetFontObject("GameFontHighlightSmall")
    search:SetAutoFocus(false)
    search:SetTextInsets(4, 4, 0, 0)

    local placeholder = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", 6, 0); placeholder:SetText("Search bar styles...")
    search:SetScript("OnEditFocusGained", function() placeholder:Hide() end)
    search:SetScript("OnEditFocusLost", function()
        if search:GetText() == "" then placeholder:Show() end
    end)

    -- List display area
    local listArea = CreateFrame("Frame", nil, panel)
    listArea:SetPoint("TOPLEFT", 4, -(ROW_H + 4))
    listArea:SetSize(WIDTH - 8, VISIBLE_ROWS * ROW_H)
    listArea:EnableMouseWheel(true)

    local rows = {}
    local filtered = {}
    local scrollOff = 0

    -- Build row buttons (created once, reused)
    local function BuildRows()
        for i = 1, VISIBLE_ROWS do
            if rows[i] then break end
            local row = CreateFrame("Button", nil, listArea, "BackdropTemplate")
            row:SetSize(WIDTH - 8, ROW_H)
            row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
            row:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
            row:SetBackdropColor(0, 0, 0, 0)

            -- Bar style name label (left side)
            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.label:SetPoint("LEFT", 6, 0)
            row.label:SetPoint("RIGHT", row, "CENTER", -2, 0)
            row.label:SetJustifyH("LEFT")

            -- Texture preview swatch (right half of the row)
            row.swatch = row:CreateTexture(nil, "ARTWORK")
            row.swatch:SetPoint("LEFT", row, "CENTER", 4, 0)
            row.swatch:SetPoint("RIGHT", row, "RIGHT", -6, 0)
            row.swatch:SetHeight(SWATCH_H)
            row.swatch:SetVertexColor(0.01, 0.56, 0.91, 1)

            row:SetScript("OnEnter", function(self) self:SetBackdropColor(0.2, 0.5, 0.8, 0.3) end)
            row:SetScript("OnLeave", function(self) self:SetBackdropColor(0, 0, 0, 0) end)

            rows[i] = row
        end
    end

    -- Refresh display with current filtered results
    local function Refresh()
        BuildRows()
        for i = 1, VISIBLE_ROWS do
            local idx = filtered[scrollOff + i]
            local row = rows[i]
            if idx then
                local entry = ns.BarStyleList[idx]
                row.label:SetText(entry.name)
                row.swatch:SetTexture(entry.path)
                row:SetScript("OnClick", function()
                    currentPath = entry.path
                    selText:SetText(entry.name)
                    panel:Hide()
                    if onSelect then onSelect(entry.path, entry.name) end
                end)
                row:Show()
            else
                row:Hide()
            end
        end
    end

    -- Filter list by search query
    local function Filter()
        filtered = {}
        local q = strlower(strtrim(search:GetText()))
        for i, entry in ipairs(ns.BarStyleList) do
            if q == "" or strlower(entry.name):find(q, 1, true) then
                filtered[#filtered + 1] = i
            end
        end
        scrollOff = 0
        Refresh()
    end

    search:SetScript("OnTextChanged", function() Filter() end)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus(); panel:Hide() end)

    -- Mouse wheel scrolling
    listArea:SetScript("OnMouseWheel", function(_, delta)
        scrollOff = math.max(0, math.min(scrollOff - delta, math.max(0, #filtered - VISIBLE_ROWS)))
        Refresh()
    end)

    -- Toggle dropdown
    selBtn:SetScript("OnClick", function()
        if panel:IsShown() then
            panel:Hide()
        else
            ns.BarStyleList.Rebuild()
            search:SetText(""); placeholder:Show(); Filter()
            panel:Show(); search:SetFocus()
        end
    end)

    -- Public API
    local function SetBarStyle(_, path)
        currentPath = path
        selText:SetText(ns.BarStyleList.GetName(path))
    end

    frame.SetBarStyle = SetBarStyle
    frame.GetBarStyle = function() return currentPath end

    selText:SetText(ns.BarStyleList.GetName(currentPath or [[Interface\Buttons\WHITE8X8]]))

    return frame
end

--- Make a frame draggable with position saved to db.
function ns.Widgets.MakeDraggable(frame, opts)
    local db = opts.db
    local unlockKey = opts.unlockKey or "unlock"
    local pointKey = opts.pointKey or "point"
    local xKey = opts.xKey or "x"
    local yKey = opts.yKey or "y"

    frame:SetMovable(true)
    if opts.enableMouse ~= false then frame:EnableMouse(true) end
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    if opts.userPlaced ~= false then frame:SetUserPlaced(true) end

    frame:SetScript("OnDragStart", function(self)
        if db[unlockKey] then
            self:StartMoving()
        end
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        if point and x and y then
            db[pointKey] = point
            db[xKey] = math.floor(x)
            db[yKey] = math.floor(y)
        end
    end)
end

-- Text input field, saves string to db[key]
function ns.Widgets:CreateTextInput(parent, opts)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", opts.x or 10, opts.y or 0)
    label:SetText(ns.Widgets.Colorize(opts.label or "", ns.COLORS.WHITE))

    local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    box:SetSize(opts.width or 200, 28)
    box:SetPoint("LEFT", label, "RIGHT", 10, 0)
    box:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]],
        edgeSize = 1
    })
    box:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    box:SetBackdropBorderColor(0, 0.49, 0.79, 0.4)
    box:SetFont("Interface\\AddOns\\NaowhQOL\\Assets\\Fonts\\Naowh.ttf", 12, "")
    box:SetTextColor(1, 1, 1, 0.9)
    box:SetTextInsets(8, 8, 0, 0)
    box:SetAutoFocus(false)
    box:SetMaxLetters(opts.maxLetters or 50)

    if opts.db and opts.key then
        box:SetText(opts.db[opts.key] or opts.default or "")
        box:SetScript("OnEnterPressed", function(self)
            opts.db[opts.key] = self:GetText()
            self:ClearFocus()
            if opts.onChange then opts.onChange(opts.db[opts.key]) end
        end)
        box:SetScript("OnEscapePressed", function(self)
            self:SetText(opts.db[opts.key] or opts.default or "")
            self:ClearFocus()
        end)
    end

    box:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(1, 0.66, 0, 0.8)
    end)
    box:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(0, 0.49, 0.79, 0.4)
    end)

    return box
end

-- Resize handle, saves dimensions to db
function ns.Widgets.CreateResizeHandle(parent, opts)
    local db = opts.db
    local unlockKey = opts.unlockKey or "unlock"
    local widthKey = opts.widthKey or "width"
    local heightKey = opts.heightKey or "height"

    parent:SetResizable(true)
    parent:SetResizeBounds(
        opts.minW or 150, opts.minH or 20,
        opts.maxW or 600, opts.maxH or 200
    )

    local handle = CreateFrame("Button", nil, parent)
    handle:SetSize(16, 16)
    handle:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -2, 2)
    handle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    handle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    handle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")

    handle:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and db[unlockKey] then
            parent:StartSizing("BOTTOMRIGHT")
            parent.isResizing = true
        end
    end)

    handle:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            parent:StopMovingOrSizing()
            parent.isResizing = false
            local w, h = parent:GetSize()
            db[widthKey] = math.floor(w)
            db[heightKey] = math.floor(h)
            if opts.onResize then opts.onResize() end
        end
    end)

    handle:SetScript("OnUpdate", function(self)
        if parent.isResizing and opts.onResize then
            opts.onResize()
        end
    end)

    return handle
end

-- TTS Voice Picker - uses system TTS voices from C_VoiceChat.GetTtsVoices()
function ns.Widgets:CreateTTSVoicePicker(parent, x, y, currentVoiceID, onSelect)
    local VISIBLE_ROWS = 6
    local ROW_H = 22
    local WIDTH = 280

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(WIDTH, 28)
    frame:SetPoint("TOPLEFT", x, y)

    -- Selection button (shows current voice name)
    local selBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    selBtn:SetSize(WIDTH - 34, 26)
    selBtn:SetPoint("TOPLEFT")
    selBtn:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
    selBtn:SetBackdropColor(0.08, 0.08, 0.08, 1)
    selBtn:SetBackdropBorderColor(0, 0, 0, 1)

    local selText = selBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    selText:SetPoint("LEFT", 8, 0); selText:SetPoint("RIGHT", -24, 0)
    selText:SetJustifyH("LEFT")

    local arrow = selBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arrow:SetPoint("RIGHT", -6, 0); arrow:SetText("|cffffa900v|r")

    -- Play sample button
    local playBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    playBtn:SetSize(28, 26)
    playBtn:SetPoint("LEFT", selBtn, "RIGHT", 4, 0)
    playBtn:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
    playBtn:SetBackdropColor(0.08, 0.08, 0.08, 1)
    playBtn:SetBackdropBorderColor(0, 0, 0, 1)

    local playIcon = playBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    playIcon:SetPoint("CENTER"); playIcon:SetText("|cff66ccff>|r")

    playBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.2, 0.5, 0.8, 0.3)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Play Sample")
        GameTooltip:Show()
    end)
    playBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.08, 0.08, 0.08, 1)
        GameTooltip:Hide()
    end)

    -- Dropdown panel (hidden by default)
    local panel = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    panel:SetSize(WIDTH, ROW_H + VISIBLE_ROWS * ROW_H + 6)
    panel:SetPoint("TOPLEFT", selBtn, "BOTTOMLEFT", 0, -2)
    panel:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
    panel:SetBackdropColor(0.06, 0.06, 0.06, 0.98)
    panel:SetBackdropBorderColor(0, 0, 0, 1)
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
    panel:SetFrameLevel(100)
    panel:Hide()

    -- Click-outside overlay to dismiss the dropdown
    local overlay = CreateFrame("Button", nil, UIParent)
    overlay:SetAllPoints(UIParent)
    overlay:SetFrameStrata("FULLSCREEN_DIALOG")
    overlay:SetFrameLevel(99)
    overlay:Hide()
    overlay:SetScript("OnClick", function() panel:Hide() end)
    panel:SetScript("OnShow", function() overlay:Show() end)
    panel:SetScript("OnHide", function() overlay:Hide() end)

    -- Search box
    local search = CreateFrame("EditBox", nil, panel, "BackdropTemplate")
    search:SetSize(WIDTH - 8, 18)
    search:SetPoint("TOPLEFT", 4, -4)
    search:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = 1 })
    search:SetBackdropColor(0, 0, 0, 1)
    search:SetBackdropBorderColor(0, 0, 0, 1)
    search:SetFontObject("GameFontHighlightSmall")
    search:SetAutoFocus(false)
    search:SetTextInsets(4, 4, 0, 0)

    local placeholder = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", 6, 0); placeholder:SetText("Search voices...")
    search:SetScript("OnEditFocusGained", function() placeholder:Hide() end)
    search:SetScript("OnEditFocusLost", function()
        if search:GetText() == "" then placeholder:Show() end
    end)

    -- List display area
    local listArea = CreateFrame("Frame", nil, panel)
    listArea:SetPoint("TOPLEFT", 4, -(ROW_H + 4))
    listArea:SetSize(WIDTH - 8, VISIBLE_ROWS * ROW_H)
    listArea:EnableMouseWheel(true)

    local rows = {}
    local filtered = {}
    local scrollOff = 0
    local voiceCache = {}

    -- Get available TTS voices from system
    local function GetVoices()
        voiceCache = {}
        local voices = C_VoiceChat and C_VoiceChat.GetTtsVoices and C_VoiceChat.GetTtsVoices() or {}
        for _, voice in ipairs(voices) do
            voiceCache[#voiceCache + 1] = { id = voice.voiceID, name = voice.name }
        end
        -- Add fallback if no voices found
        if #voiceCache == 0 then
            voiceCache[1] = { id = 0, name = "Default System Voice" }
        end
        return voiceCache
    end

    -- Get voice name by ID
    local function GetVoiceName(voiceID)
        local voices = GetVoices()
        for _, v in ipairs(voices) do
            if v.id == voiceID then return v.name end
        end
        return voices[1] and voices[1].name or "Unknown"
    end

    -- Build row buttons (created once, reused)
    local function BuildRows()
        for i = 1, VISIBLE_ROWS do
            if rows[i] then break end
            local row = CreateFrame("Button", nil, listArea, "BackdropTemplate")
            row:SetSize(WIDTH - 8, ROW_H)
            row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
            row:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8x8]] })
            row:SetBackdropColor(0, 0, 0, 0)

            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.label:SetPoint("LEFT", 6, 0); row.label:SetPoint("RIGHT", -30, 0)
            row.label:SetJustifyH("LEFT")

            -- Preview play button in row
            row.play = CreateFrame("Button", nil, row)
            row.play:SetSize(20, ROW_H)
            row.play:SetPoint("RIGHT")
            row.play.tex = row.play:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.play.tex:SetPoint("CENTER"); row.play.tex:SetText("|cff66ccff>|r")

            row:SetScript("OnEnter", function(self) self:SetBackdropColor(0.2, 0.5, 0.8, 0.3) end)
            row:SetScript("OnLeave", function(self) self:SetBackdropColor(0, 0, 0, 0) end)

            rows[i] = row
        end
    end

    -- Play TTS sample with given voice ID
    local function PlaySample(voiceID)
        if C_VoiceChat and C_VoiceChat.SpeakText then
            local rate = C_TTSSettings and C_TTSSettings.GetSpeechRate and C_TTSSettings.GetSpeechRate() or 0
            local volume = C_TTSSettings and C_TTSSettings.GetSpeechVolume and C_TTSSettings.GetSpeechVolume() or 100
            C_VoiceChat.SpeakText(voiceID, "This is a sample of the selected voice.", rate, volume, false)
        end
    end

    -- Refresh display with current filtered results
    local function Refresh()
        BuildRows()
        for i = 1, VISIBLE_ROWS do
            local idx = filtered[scrollOff + i]
            local row = rows[i]
            if idx then
                local entry = voiceCache[idx]
                row.label:SetText(entry.name)
                row:SetScript("OnClick", function()
                    currentVoiceID = entry.id
                    selText:SetText(entry.name)
                    panel:Hide()
                    if onSelect then onSelect(entry.id, entry.name) end
                end)
                row.play:SetScript("OnClick", function()
                    PlaySample(entry.id)
                end)
                row:Show()
            else
                row:Hide()
            end
        end
    end

    -- Filter list by search query
    local function Filter()
        filtered = {}
        local q = strlower(strtrim(search:GetText()))
        for i, entry in ipairs(voiceCache) do
            if q == "" or strlower(entry.name):find(q, 1, true) then
                filtered[#filtered + 1] = i
            end
        end
        scrollOff = 0
        Refresh()
    end

    search:SetScript("OnTextChanged", function() Filter() end)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus(); panel:Hide() end)

    -- Mouse wheel scrolling
    listArea:SetScript("OnMouseWheel", function(_, delta)
        scrollOff = math.max(0, math.min(scrollOff - delta, math.max(0, #filtered - VISIBLE_ROWS)))
        Refresh()
    end)

    -- Toggle dropdown
    selBtn:SetScript("OnClick", function()
        if panel:IsShown() then
            panel:Hide()
        else
            GetVoices()
            search:SetText(""); placeholder:Show(); Filter()
            panel:Show(); search:SetFocus()
        end
    end)

    -- Play button plays current selection
    playBtn:SetScript("OnClick", function()
        if currentVoiceID then
            PlaySample(currentVoiceID)
        end
    end)

    -- Public API
    local function SetVoiceID(_, id)
        currentVoiceID = id
        GetVoices()
        selText:SetText(GetVoiceName(id))
    end

    frame.SetVoiceID = SetVoiceID
    frame.GetVoiceID = function() return currentVoiceID end
    frame.RefreshVoices = function() GetVoices() end

    -- Initialize with current voice
    GetVoices()
    selText:SetText(GetVoiceName(currentVoiceID or 0))

    return frame
end

-- Restore to Defaults button for module config pages
-- opts: moduleName, parent, scrollContent, onRestore
function ns.Widgets:CreateRestoreDefaultsButton(opts)
    local parent = opts.parent
    local moduleName = opts.moduleName
    local onRestore = opts.onRestore

    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(160, 28)
    btn:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]],
        edgeSize = 1,
    })
    btn:SetBackdropColor(0.15, 0.08, 0.08, 0.9)
    btn:SetBackdropBorderColor(0.6, 0.2, 0.2, 0.8)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER", 0, 0)
    label:SetText("RESTORE DEFAULTS")
    label:SetTextColor(0.9, 0.3, 0.3, 1)

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(BTN_ORANGE_R, BTN_ORANGE_G, BTN_ORANGE_B, 0.9)
        label:SetTextColor(1, 0.5, 0.5, 1)
    end)

    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.6, 0.2, 0.2, 0.8)
        label:SetTextColor(0.9, 0.3, 0.3, 1)
    end)

    local initFunc = opts.initFunc

    btn:SetScript("OnClick", function()
        StaticPopupDialogs["NAOWHQOL_RESTORE_DEFAULTS"] = {
            text = "Restore " .. moduleName:upper() .. " to default settings?\n\nThis will close the settings panel.",
            button1 = "Restore",
            button2 = "Cancel",
            OnAccept = function()
                if ns:RestoreModuleDefaults(moduleName) then
                    print("|cff018ee7NaowhQOL|r: " .. moduleName .. " restored to defaults.")
                    -- Clear cache and update display
                    if onRestore then onRestore() end
                    -- Close and reopen the main frame to rebuild UI with new values
                    if ns.MainFrame then
                        ns.MainFrame:Hide()
                        C_Timer.After(0.1, function()
                            ns.MainFrame:Show()
                            -- Re-select the same panel
                            if initFunc then initFunc() end
                        end)
                    end
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("NAOWHQOL_RESTORE_DEFAULTS")
    end)

    return btn
end
