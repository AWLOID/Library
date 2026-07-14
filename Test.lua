-- Lurk UI Library v2 — redesigned by AI
-- Logic preserved, full visual overhaul
-- Z-order: FloatingButtons (low) < MainWindow < OpenButton (top)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ─── Z-ORDER CONSTANTS ────────────────────────────────────────────────────────
local ZO_FLOATING    = 999975  -- floating draggable buttons (can be covered by menu)
local ZO_MAIN        = 999985  -- main window ScreenGui
local ZO_OPENBUTTON  = 999995  -- open/close button always on top of everything
-- ──────────────────────────────────────────────────────────────────────────────

-- ─── DESIGN TOKENS ────────────────────────────────────────────────────────────
local D = {
    -- backgrounds
    BG_BASE      = Color3.fromRGB(8,   8,   8),
    BG_SURFACE   = Color3.fromRGB(13,  13,  13),
    BG_ELEVATED  = Color3.fromRGB(18,  18,  18),
    BG_CONTROL   = Color3.fromRGB(22,  22,  22),
    BG_HOVER     = Color3.fromRGB(28,  28,  28),

    -- borders
    BORDER       = Color3.fromRGB(35,  35,  35),
    BORDER_SUB   = Color3.fromRGB(28,  28,  28),

    -- text
    TEXT_PRIMARY = Color3.fromRGB(230, 230, 230),
    TEXT_SECOND  = Color3.fromRGB(160, 160, 160),
    TEXT_MUTED   = Color3.fromRGB(90,  90,  90),

    -- misc
    CORNER_LG    = UDim.new(0, 10),
    CORNER_MD    = UDim.new(0, 7),
    CORNER_SM    = UDim.new(0, 5),
    CORNER_XS    = UDim.new(0, 4),
    CORNER_ROUND = UDim.new(1,  0),

    FONT_TITLE  = Enum.Font.GothamBold,
    FONT_MEDIUM = Enum.Font.GothamMedium,
    FONT_BODY   = Enum.Font.Gotham,

    TWEEN_FAST  = TweenInfo.new(0.12, Enum.EasingStyle.Quint),
    TWEEN_MED   = TweenInfo.new(0.22, Enum.EasingStyle.Quint),
    TWEEN_OPEN  = TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
    TWEEN_CLOSE = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
}
-- ──────────────────────────────────────────────────────────────────────────────

local GuiParent = PlayerGui
do
    local ok, hui = pcall(function()
        if typeof(gethui) == "function" then return gethui() end
        return nil
    end)
    if ok and hui then GuiParent = hui
    else
        local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
        if ok2 and cg then GuiParent = cg end
    end
end

local function ProtectGui(gui)
    pcall(function()
        if typeof(syn) == "table" and syn.protect_gui then syn.protect_gui(gui)
        elseif typeof(protectgui) == "function" then protectgui(gui) end
    end)
end

local function NewInstance(className, properties, children)
    local inst = Instance.new(className)
    for key, value in pairs(properties or {}) do inst[key] = value end
    for _, child in ipairs(children or {}) do child.Parent = inst end
    return inst
end

local function Clamp01(n) return math.clamp(n, 0, 1) end

local function RoundTo(value, step)
    if step <= 0 then return value end
    local v = math.floor(value / step + 0.5) * step
    return math.floor(v * 1e6 + 0.5) / 1e6
end

local function FormatKeycodeName(keycode)
    if not keycode then return "None" end
    return keycode.Name
end

local function PointInsideGui(guiObject, x, y)
    local pos  = guiObject.AbsolutePosition
    local size = guiObject.AbsoluteSize
    return x >= pos.X and x <= pos.X + size.X and y >= pos.Y and y <= pos.Y + size.Y
end

local function ClampOpenPosition(x, y, width, height)
    local viewport = workspace.CurrentCamera.ViewportSize
    local maxX = math.max(4, viewport.X - width  - 4)
    local maxY = math.max(4, viewport.Y - height - 4)
    return math.clamp(x, 4, maxX), math.clamp(y, 4, maxY)
end

local function MakeDraggable(handle, target, onDragStart)
    local activeInput    = nil
    local startInputPos  = nil
    local startTargetPos = nil

    local function BeginDrag(input)
        if activeInput ~= nil then return end
        activeInput = input
        startInputPos  = input.Position
        startTargetPos = target.Position
        if onDragStart then onDragStart() end

        local connChanged, connEnded
        connChanged = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                if connChanged then connChanged:Disconnect() end
                if connEnded   then connEnded:Disconnect() end
                if activeInput == input then activeInput = nil end
            end
        end)
        connEnded = UserInputService.InputEnded:Connect(function(endedInput)
            if endedInput == input then
                if connChanged then connChanged:Disconnect() end
                if connEnded   then connEnded:Disconnect() end
                if activeInput == input then activeInput = nil end
            end
        end)
    end

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            BeginDrag(input)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if activeInput == nil then return end
        local isMouseMove = input.UserInputType  == Enum.UserInputType.MouseMovement
                        and activeInput.UserInputType == Enum.UserInputType.MouseButton1
        if input ~= activeInput and not isMouseMove then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = input.Position - startInputPos
        target.Position = UDim2.new(
            startTargetPos.X.Scale, startTargetPos.X.Offset + delta.X,
            startTargetPos.Y.Scale, startTargetPos.Y.Offset + delta.Y
        )
    end)
end

local function MakeValueDragger(hitTargets, onInputDown, onInputMove)
    local activeInput = nil
    local function Bind(obj)
        obj.InputBegan:Connect(function(input)
            if activeInput ~= nil then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or
               input.UserInputType == Enum.UserInputType.Touch then
                activeInput = input
                onInputDown(input)
                local connChanged, connEnded
                local function FinishDrag()
                    if connChanged then connChanged:Disconnect() end
                    if connEnded   then connEnded:Disconnect() end
                    if activeInput == input then activeInput = nil end
                end
                connChanged = input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then FinishDrag() end
                end)
                connEnded = UserInputService.InputEnded:Connect(function(endedInput)
                    if endedInput == input then FinishDrag() end
                end)
            end
        end)
    end
    for _, obj in ipairs(hitTargets) do Bind(obj) end
    UserInputService.InputChanged:Connect(function(input)
        if activeInput == nil then return end
        local isMatch = (input == activeInput)
            or (input.UserInputType == Enum.UserInputType.MouseMovement
                and activeInput.UserInputType == Enum.UserInputType.MouseButton1)
        if not isMatch then return end
        onInputMove(input)
    end)
end

local ActiveKeybindCancel = nil
local OverlayRegistry = {}

local function RegisterOverlay(holder, trigger, isOpenGetter, closeFn)
    table.insert(OverlayRegistry, { Holder=holder, Trigger=trigger, IsOpen=isOpenGetter, Close=closeFn })
end

local function PruneOverlays()
    for i = #OverlayRegistry, 1, -1 do
        local e = OverlayRegistry[i]
        if not e.Holder or not e.Holder.Parent then table.remove(OverlayRegistry, i) end
    end
end

local function CloseAllOverlaysExcept(exceptHolder)
    PruneOverlays()
    for _, e in ipairs(OverlayRegistry) do
        if e.Holder ~= exceptHolder and e.IsOpen() then e.Close() end
    end
end

local function CloseAllOverlays() CloseAllOverlaysExcept(nil) end

UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
    and input.UserInputType ~= Enum.UserInputType.Touch then return end
    PruneOverlays()
    local pos = input.Position
    for _, e in ipairs(OverlayRegistry) do
        if e.IsOpen() then
            local insideHolder  = PointInsideGui(e.Holder, pos.X, pos.Y)
            local insideTrigger = e.Trigger and PointInsideGui(e.Trigger, pos.X, pos.Y)
            if not insideHolder and not insideTrigger then e.Close() end
        end
    end
end)

-- ─── ELEMENT FACTORY ──────────────────────────────────────────────────────────
local function CreateElementFactory(context)
    local ScreenGui = context.ScreenGui
    local Accent    = context.Accent
    local Factory   = {}

    -- helper: make a standard dark container frame
    local function MakeControlFrame(parent, name, h)
        local f = NewInstance("Frame", {
            Name = name,
            BackgroundColor3 = D.BG_CONTROL,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, h or 28),
            Parent = parent,
        })
        NewInstance("UICorner", { CornerRadius = D.CORNER_SM, Parent = f })
        NewInstance("UIStroke", { Color = D.BORDER, Thickness = 1, Parent = f })
        return f
    end

    -- ── Label ──────────────────────────────────────────────────────────────────
    function Factory.Label(parent, text)
        return NewInstance("TextLabel", {
            Name = "Label_" .. text,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 18),
            Font = D.FONT_BODY,
            TextSize = 13,
            TextColor3 = D.TEXT_MUTED,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = text,
            Parent = parent,
        })
    end

    -- ── Paragraph ─────────────────────────────────────────────────────────────
    function Factory.Paragraph(parent, config)
        config = config or {}
        local title = config.Title
        local text  = config.Text or ""
        local row   = NewInstance("Frame", {
            Name = "Paragraph",
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(1, 0, 0, 0),
            Parent = parent,
        })
        NewInstance("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
        if title then
            NewInstance("TextLabel", {
                Name = "Title",
                BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.Y,
                Size = UDim2.new(1, 0, 0, 0),
                Font = D.FONT_TITLE,
                TextSize = 13,
                TextColor3 = D.TEXT_PRIMARY,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
                Text = title,
                Parent = row,
            })
        end
        local body = NewInstance("TextLabel", {
            Name = "Body",
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(1, 0, 0, 0),
            Font = D.FONT_BODY,
            TextSize = 12,
            TextColor3 = D.TEXT_SECOND,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            Text = text,
            Parent = row,
        })
        local api = {}
        function api.SetText(t) body.Text = t end
        return api
    end

    -- ── Section ───────────────────────────────────────────────────────────────
    function Factory.Section(parent, text)
        local row = NewInstance("Frame", {
            Name = "Section_" .. tostring(text),
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 22),
            Parent = parent,
        })
        local lbl = NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            Font = D.FONT_TITLE,
            TextSize = 10,
            TextColor3 = Accent.Value,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = string.upper(text or ""),
            Parent = row,
        })
        Accent.Changed:Connect(function(c) lbl.TextColor3 = c end)
        NewInstance("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.new(1, -80, 0, 1),
            BackgroundColor3 = D.BORDER,
            BorderSizePixel = 0,
            Parent = row,
        })
        return row
    end

    -- ── Toggle ────────────────────────────────────────────────────────────────
    function Factory.Toggle(parent, config)
        config = config or {}
        local name     = config.Name     or "Toggle"
        local default  = config.Default  or false
        local callback = config.Callback

        local container = NewInstance("Frame", {
            Name = "ToggleContainer_" .. name,
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(1, 0, 0, 0),
            Parent = parent,
        })
        NewInstance("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = container })

        local row = NewInstance("Frame", {
            Name = "Toggle_" .. name,
            BackgroundTransparency = 1,
            LayoutOrder = 1,
            Size = UDim2.new(1, 0, 0, 28),
            Parent = container,
        })

        local subHolder = nil
        local function EnsureSub()
            if not subHolder then
                subHolder = NewInstance("Frame", {
                    Name = "SubContent",
                    BackgroundTransparency = 1,
                    LayoutOrder = 2,
                    AutomaticSize = Enum.AutomaticSize.Y,
                    Size = UDim2.new(1, 0, 0, 0),
                    Parent = container,
                })
                NewInstance("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = subHolder })
            end
            return subHolder
        end

        NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -52, 1, 0),
            Font = D.FONT_BODY,
            TextSize = 13,
            TextColor3 = D.TEXT_PRIMARY,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            Parent = row,
        })

        -- switch-style track
        local track = NewInstance("Frame", {
            Name = "Track",
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(38, 20),
            BackgroundColor3 = default and Accent.Value or D.BG_HOVER,
            BorderSizePixel = 0,
            Parent = row,
        })
        NewInstance("UICorner", { CornerRadius = D.CORNER_ROUND, Parent = track })

        local knob = NewInstance("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = default and UDim2.new(1, -11, 0.5, 0) or UDim2.new(0, 11, 0.5, 0),
            Size = UDim2.fromOffset(14, 14),
            BackgroundColor3 = default and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(110, 110, 110),
            BorderSizePixel = 0,
            Parent = track,
        })
        NewInstance("UICorner", { CornerRadius = D.CORNER_ROUND, Parent = knob })

        local state = default

        local function ApplyVisual(animated)
            local kGoal = { Position = state and UDim2.new(1, -11, 0.5, 0) or UDim2.new(0, 11, 0.5, 0) }
            local kColor = { BackgroundColor3 = state and Color3.fromRGB(255,255,255) or Color3.fromRGB(110,110,110) }
            local tGoal  = { BackgroundColor3 = state and Accent.Value or D.BG_HOVER }
            if animated then
                TweenService:Create(knob,  D.TWEEN_FAST, kGoal):Play()
                TweenService:Create(knob,  D.TWEEN_FAST, kColor):Play()
                TweenService:Create(track, D.TWEEN_FAST, tGoal):Play()
            else
                knob.Position         = kGoal.Position
                knob.BackgroundColor3 = kColor.BackgroundColor3
                track.BackgroundColor3 = tGoal.BackgroundColor3
            end
        end

        Accent.Changed:Connect(function(c) if state then track.BackgroundColor3 = c end end)

        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                state = not state
                ApplyVisual(true)
                if callback then callback(state) end
            end
        end)

        local api = {}
        function api.Set(v) state = v; ApplyVisual(false) end
        function api.Get() return state end
        api.Row = row; api.Container = container
        function api:GetContainer() return EnsureSub() end
        function api:AddSlider(sc)  return Factory.Slider(EnsureSub(), sc)  end
        function api:AddToggle(sc)  return Factory.Toggle(EnsureSub(), sc)  end
        function api:AddButton(sc)  return Factory.Button(EnsureSub(), sc)  end
        function api:AddLabel(t)    return Factory.Label(EnsureSub(), t)     end
        function api:ClearSub()
            if subHolder then subHolder:Destroy(); subHolder = nil end
        end
        return api
    end

    -- ── Slider ────────────────────────────────────────────────────────────────
    function Factory.Slider(parent, config)
        config = config or {}
        local name     = config.Name    or "Slider"
        local min      = config.Min     or 0
        local max      = config.Max     or 100
        if max < min then min, max = max, min end
        local default  = math.clamp(config.Default or min, min, max)
        local step     = config.Step    or ((max - min <= 1) and 0.01 or 1)
        local callback = config.Callback

        local row = NewInstance("Frame", {
            Name = "Slider_" .. name,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 40),
            Parent = parent,
        })
        local label = NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -56, 0, 18),
            Font = D.FONT_BODY,
            TextSize = 13,
            TextColor3 = D.TEXT_PRIMARY,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            Parent = row,
        })
        -- value badge
        local badge = NewInstance("TextLabel", {
            BackgroundColor3 = D.BG_ELEVATED,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, 0),
            Size = UDim2.fromOffset(50, 18),
            BorderSizePixel = 0,
            Font = D.FONT_MEDIUM,
            TextSize = 12,
            TextColor3 = Accent.Value,
            Text = tostring(default),
            Parent = row,
        })
        NewInstance("UICorner", { CornerRadius = D.CORNER_XS, Parent = badge })
        Accent.Changed:Connect(function(c) badge.TextColor3 = c end)

        local track = NewInstance("Frame", {
            Position = UDim2.fromOffset(0, 25),
            Size = UDim2.new(1, 0, 0, 5),
            BackgroundColor3 = D.BG_ELEVATED,
            BorderSizePixel = 0,
            Parent = row,
        })
        NewInstance("UICorner", { CornerRadius = D.CORNER_ROUND, Parent = track })

        local fillRatio = (max > min) and Clamp01((default - min)/(max - min)) or 0
        local fill = NewInstance("Frame", {
            Size = UDim2.new(fillRatio, 0, 1, 0),
            BackgroundColor3 = Accent.Value,
            BorderSizePixel = 0,
            Parent = track,
        })
        NewInstance("UICorner", { CornerRadius = D.CORNER_ROUND, Parent = fill })
        Accent.Changed:Connect(function(c) fill.BackgroundColor3 = c end)

        local knob = NewInstance("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(fillRatio, 0, 0.5, 0),
            Size = UDim2.fromOffset(14, 14),
            BackgroundColor3 = Color3.fromRGB(240, 240, 240),
            BorderSizePixel = 0,
            ZIndex = track.ZIndex + 1,
            Parent = track,
        })
        NewInstance("UICorner", { CornerRadius = D.CORNER_ROUND, Parent = knob })

        local currentValue = default
        local function ApplyValue(value, fromUser)
            value = math.clamp(RoundTo(math.clamp(value, min, max), step), min, max)
            currentValue = value
            local ratio = (max > min) and Clamp01((value - min)/(max - min)) or 0
            fill.Size  = UDim2.new(ratio, 0, 1, 0)
            knob.Position = UDim2.new(ratio, 0, 0.5, 0)
            badge.Text = tostring(value)
            if fromUser and callback then callback(value) end
        end
        local function UpdateFromX(xPos)
            local tp = track.AbsolutePosition.X
            local ts = track.AbsoluteSize.X
            if ts <= 0 then return end
            ApplyValue(min + (max - min) * Clamp01((xPos - tp) / ts), true)
        end
        MakeValueDragger({knob, track},
            function(i) UpdateFromX(i.Position.X) end,
            function(i) UpdateFromX(i.Position.X) end)

        local api = {}
        function api.Set(v) ApplyValue(v, false) end
        function api.Get() return currentValue end
        api.Instance = row
        function api.SetVisible(v) row.Visible = v ~= false end
        function api.Destroy()  row:Destroy() end
        return api
    end

    -- ── Button ────────────────────────────────────────────────────────────────
    function Factory.Button(parent, config)
        config = config or {}
        local name     = config.Name     or "Button"
        local callback = config.Callback

        local btn = NewInstance("TextButton", {
            Name = "Button_" .. name,
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundColor3 = D.BG_CONTROL,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = D.FONT_MEDIUM,
            TextSize = 13,
            TextColor3 = D.TEXT_PRIMARY,
            Text = name,
            Parent = parent,
        })
        NewInstance("UICorner", { CornerRadius = D.CORNER_SM, Parent = btn })
        NewInstance("UIStroke", { Color = D.BORDER, Thickness = 1, Parent = btn })

        btn.MouseButton1Click:Connect(function()
            TweenService:Create(btn, D.TWEEN_FAST, { BackgroundColor3 = Accent.Value }):Play()
            task.delay(0.14, function()
                TweenService:Create(btn, D.TWEEN_MED, { BackgroundColor3 = D.BG_CONTROL }):Play()
            end)
            if callback then callback() end
        end)

        local api = {}
        function api.SetText(t) btn.Text = t end
        return api
    end

    -- ── ProgressBar ───────────────────────────────────────────────────────────
    function Factory.ProgressBar(parent, config)
        config = config or {}
        local name    = config.Name    or "Progress"
        local min     = config.Min     or 0
        local max     = config.Max     or 100
        if max < min then min, max = max, min end
        local default = math.clamp(config.Default or min, min, max)

        local row = NewInstance("Frame", {
            Name = "ProgressBar_" .. name,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 36),
            Parent = parent,
        })
        NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 16),
            Font = D.FONT_BODY,
            TextSize = 13,
            TextColor3 = D.TEXT_SECOND,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            Parent = row,
        })
        local track = NewInstance("Frame", {
            Position = UDim2.fromOffset(0, 20),
            Size = UDim2.new(1, 0, 0, 6),
            BackgroundColor3 = D.BG_ELEVATED,
            BorderSizePixel = 0,
            Parent = row,
        })
        NewInstance("UICorner", { CornerRadius = D.CORNER_ROUND, Parent = track })
        local ratio = (max > min) and Clamp01((default - min)/(max - min)) or 0
        local fill = NewInstance("Frame", {
            Size = UDim2.new(ratio, 0, 1, 0),
            BackgroundColor3 = Accent.Value,
            BorderSizePixel = 0,
            Parent = track,
        })
        NewInstance("UICorner", { CornerRadius = D.CORNER_ROUND, Parent = fill })
        Accent.Changed:Connect(function(c) fill.BackgroundColor3 = c end)

        local currentValue = default
        local api = {}
        function api.Set(value)
            currentValue = math.clamp(value, min, max)
            local r = (max > min) and Clamp01((currentValue - min)/(max - min)) or 0
            TweenService:Create(fill, D.TWEEN_MED, { Size = UDim2.new(r, 0, 1, 0) }):Play()
        end
        function api.Get() return currentValue end
        return api
    end

    -- ── Image ─────────────────────────────────────────────────────────────────
    function Factory.Image(parent, config)
        config = config or {}
        local id     = config.Id     or ""
        local height = config.Height or 120
        local holder = NewInstance("Frame", {
            Name = "Image",
            BackgroundColor3 = D.BG_ELEVATED,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, height),
            Parent = parent,
        })
        NewInstance("UICorner", { CornerRadius = D.CORNER_SM, Parent = holder })
        NewInstance("UIStroke", { Color = D.BORDER, Thickness = 1, Parent = holder })
        local image = NewInstance("ImageLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Image = id,
            ScaleType = Enum.ScaleType.Crop,
            Parent = holder,
        })
        NewInstance("UICorner", { CornerRadius = D.CORNER_SM, Parent = image })
        local api = {}
        function api.Set(newId) image.Image = newId end
        return api
    end

    -- ── Dropdown ──────────────────────────────────────────────────────────────
    function Factory.Dropdown(parent, config)
        config = config or {}
        local name       = config.Name       or "Dropdown"
        local options    = config.Options    or {}
        local default    = config.Default    or options[1]
        local callback   = config.Callback
        local maxVisible = config.MaxVisible or 6

        local row = NewInstance("Frame", {
            Name = "Dropdown_" .. name,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 50),
            Parent = parent,
        })
        NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 16),
            Font = D.FONT_BODY,
            TextSize = 12,
            TextColor3 = D.TEXT_MUTED,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = string.upper(name),
            Parent = row,
        })
        local box = NewInstance("TextButton", {
            Name = "Box",
            Position = UDim2.fromOffset(0, 20),
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundColor3 = D.BG_CONTROL,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = D.FONT_BODY,
            TextSize = 13,
            TextColor3 = D.TEXT_PRIMARY,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "  " .. tostring(default or ""),
            Parent = row,
        })
        NewInstance("UICorner", { CornerRadius = D.CORNER_SM, Parent = box })
        local boxStroke = NewInstance("UIStroke", { Color = D.BORDER, Thickness = 1, Parent = box })
        local arrow = NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -10, 0.5, 0),
            Size = UDim2.fromOffset(16, 16),
            Font = D.FONT_TITLE,
            TextSize = 10,
            TextColor3 = Accent.Value,
            Text = "\u{25BE}",
            Parent = box,
        })
        local isOpen = false
        Accent.Changed:Connect(function(c) arrow.TextColor3 = c; if isOpen then boxStroke.Color = c end end)

        local optionsHolder = NewInstance("Frame", {
            Name = "DropdownHolder_" .. name,
            BackgroundColor3 = D.BG_SURFACE,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(0, 28),
            Visible = false,
            ClipsDescendants = true,
            ZIndex = 200,
            Parent = ScreenGui,
        })
        NewInstance("UICorner", { CornerRadius = D.CORNER_MD, Parent = optionsHolder })
        NewInstance("UIStroke", { Color = D.BORDER, Thickness = 1, Parent = optionsHolder })

        local scroll = NewInstance("ScrollingFrame", {
            Name = "Scroll",
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Accent.Value,
            ScrollBarImageTransparency = 0.5,
            ZIndex = optionsHolder.ZIndex + 1,
            Parent = optionsHolder,
        })
        NewInstance("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })

        local currentValue = default
        local optionButtons = {}

        local function HighlightSelected()
            for opt, btn in pairs(optionButtons) do
                if opt == currentValue then
                    btn.BackgroundColor3 = D.BG_ELEVATED
                    btn.TextColor3 = Accent.Value
                else
                    btn.BackgroundColor3 = D.BG_SURFACE
                    btn.TextColor3 = D.TEXT_SECOND
                end
            end
        end

        local function Close()
            isOpen = false
            optionsHolder.Visible = false
            boxStroke.Color = D.BORDER
            arrow.Text = "\u{25BE}"
        end

        local function RebuildOptions()
            for _, child in ipairs(scroll:GetChildren()) do
                if child:IsA("TextButton") then child:Destroy() end
            end
            optionButtons = {}
            for index, opt in ipairs(options) do
                local optBtn = NewInstance("TextButton", {
                    Name = "Option_" .. tostring(opt),
                    BackgroundColor3 = D.BG_SURFACE,
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                    Size = UDim2.new(1, 0, 0, 28),
                    Font = D.FONT_BODY,
                    TextSize = 13,
                    TextColor3 = D.TEXT_SECOND,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Text = "   " .. tostring(opt),
                    LayoutOrder = index,
                    ZIndex = scroll.ZIndex + 1,
                    Parent = scroll,
                })
                optionButtons[opt] = optBtn
                optBtn.MouseEnter:Connect(function()
                    if opt ~= currentValue then
                        TweenService:Create(optBtn, D.TWEEN_FAST, { BackgroundColor3 = D.BG_HOVER }):Play()
                    end
                end)
                optBtn.MouseLeave:Connect(function()
                    if opt ~= currentValue then
                        TweenService:Create(optBtn, D.TWEEN_FAST, { BackgroundColor3 = D.BG_SURFACE }):Play()
                    end
                end)
                optBtn.MouseButton1Click:Connect(function()
                    currentValue = opt
                    box.Text = "  " .. tostring(opt)
                    HighlightSelected()
                    Close()
                    if callback then callback(opt) end
                end)
            end
            HighlightSelected()
        end
        RebuildOptions()

        local function Open()
            CloseAllOverlaysExcept(optionsHolder)
            local boxPos  = box.AbsolutePosition
            local boxSize = box.AbsoluteSize
            local visible = math.min(#options, maxVisible)
            local panelH  = math.max(visible, 1) * 28
            optionsHolder.Size = UDim2.fromOffset(boxSize.X, panelH)
            local x, y = ClampOpenPosition(boxPos.X, boxPos.Y + boxSize.Y + 2, boxSize.X, panelH)
            optionsHolder.Position = UDim2.fromOffset(x, y)
            optionsHolder.Visible = true
            isOpen = true
            boxStroke.Color = Accent.Value
            arrow.Text = "\u{25B4}"
            HighlightSelected()
        end

        box.MouseButton1Click:Connect(function()
            if isOpen then Close() else Open() end
        end)
        RegisterOverlay(optionsHolder, box, function() return isOpen end, Close)
        row.Destroying:Connect(function() optionsHolder:Destroy() end)

        local api = {}
        function api.Set(value) currentValue = value; box.Text = "  " .. tostring(value); HighlightSelected() end
        function api.Get() return currentValue end
        function api.SetOptions(newOpts) options = newOpts; RebuildOptions() end
        return api
    end

    -- ── MultiDropdown ─────────────────────────────────────────────────────────
    function Factory.MultiDropdown(parent, config)
        config = config or {}
        local name     = config.Name     or "Dropdown"
        local options  = config.Options  or {}
        local default  = config.Default  or {}
        local callback = config.Callback

        local selected = {}
        for _, opt in ipairs(default) do selected[opt] = true end

        local row = NewInstance("Frame", {
            Name = "MultiDropdown_" .. name,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 46),
            Parent = parent,
        })
        NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 16),
            Font = D.FONT_BODY,
            TextSize = 12,
            TextColor3 = D.TEXT_MUTED,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = string.upper(name),
            Parent = row,
        })
        local box = NewInstance("TextButton", {
            Name = "Box",
            Position = UDim2.fromOffset(0, 20),
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundColor3 = D.BG_CONTROL,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = D.FONT_BODY,
            TextSize = 13,
            TextColor3 = D.TEXT_PRIMARY,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "",
            Parent = row,
        })
        NewInstance("UICorner", { CornerRadius = D.CORNER_SM, Parent = box })
        NewInstance("UIStroke", { Color = D.BORDER, Thickness = 1, Parent = box })
        NewInstance("UIPadding", { PaddingLeft = UDim.new(0, 6), Parent = box })
        local arrow = NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -8, 0.5, 0),
            Size = UDim2.fromOffset(16, 16),
            Font = D.FONT_TITLE,
            TextSize = 10,
            TextColor3 = Accent.Value,
            Text = "\u{25BE}",
            Parent = box,
        })
        Accent.Changed:Connect(function(c) arrow.TextColor3 = c end)

        local optionsHolder = NewInstance("Frame", {
            Name = "MultiDropdownHolder_" .. name,
            BackgroundColor3 = D.BG_SURFACE,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(0, math.min(#options, 8) * 24),
            Visible = false,
            ClipsDescendants = true,
            ZIndex = 200,
            Parent = ScreenGui,
        })
        NewInstance("UICorner", { CornerRadius = D.CORNER_MD, Parent = optionsHolder })
        NewInstance("UIStroke", { Color = D.BORDER, Thickness = 1, Parent = optionsHolder })

        local optScroll = NewInstance("ScrollingFrame", {
            Name = "Scroll",
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Accent.Value,
            ScrollBarImageTransparency = 0.5,
            ZIndex = optionsHolder.ZIndex + 1,
            Parent = optionsHolder,
        })
        NewInstance("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = optScroll })

        local isOpen = false
        local checkMarks = {}

        local function RefreshBoxText()
            local count, first = 0, nil
            for opt, sel in pairs(selected) do
                if sel then count = count + 1; first = first or opt end
            end
            box.Text = count == 0 and "None" or (count == 1 and tostring(first) or tostring(first) .. " +" .. (count-1))
        end

        local function Close() isOpen = false; optionsHolder.Visible = false end

        local function RebuildOptions()
            for _, child in ipairs(optScroll:GetChildren()) do
                if child:IsA("Frame") then child:Destroy() end
            end
            checkMarks = {}
            for _, opt in ipairs(options) do
                local optRow = NewInstance("Frame", {
                    Name = "Option_" .. tostring(opt),
                    BackgroundColor3 = D.BG_SURFACE,
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, 0, 0, 26),
                    ZIndex = optScroll.ZIndex + 1,
                    Parent = optScroll,
                })
                local optBtn = NewInstance("TextButton", {
                    BackgroundTransparency = 1,
                    Size = UDim2.fromScale(1, 1),
                    Font = D.FONT_BODY,
                    TextSize = 13,
                    TextColor3 = D.TEXT_SECOND,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Text = "  " .. tostring(opt),
                    ZIndex = optRow.ZIndex + 1,
                    Parent = optRow,
                })
                local dot = NewInstance("Frame", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -8, 0.5, 0),
                    Size = UDim2.fromOffset(8, 8),
                    BackgroundColor3 = Accent.Value,
                    BorderSizePixel = 0,
                    Visible = selected[opt] == true,
                    ZIndex = optRow.ZIndex + 1,
                    Parent = optRow,
                })
                NewInstance("UICorner", { CornerRadius = D.CORNER_ROUND, Parent = dot })
                checkMarks[opt] = dot
                optBtn.MouseButton1Click:Connect(function()
                    selected[opt] = not selected[opt]
                    dot.Visible = selected[opt] == true
                    RefreshBoxText()
                    if callback then callback(selected) end
                end)
            end
        end
        RebuildOptions()
        RefreshBoxText()
        Accent.Changed:Connect(function(c)
            for _, dot in pairs(checkMarks) do dot.BackgroundColor3 = c end
        end)

        local function Open()
            CloseAllOverlaysExcept(optionsHolder)
            local boxPos  = box.AbsolutePosition
            local boxSize = box.AbsoluteSize
            local panelH  = math.max(math.min(#options, 8), 1) * 26
            optionsHolder.Size = UDim2.fromOffset(boxSize.X, panelH)
            local x, y = ClampOpenPosition(boxPos.X, boxPos.Y + boxSize.Y + 2, boxSize.X, panelH)
            optionsHolder.Position = UDim2.fromOffset(x, y)
            optionsHolder.Visible = true
            isOpen = true
        end
        box.MouseButton1Click:Connect(function() if isOpen then Close() else Open() end end)
        RegisterOverlay(optionsHolder, box, function() return isOpen end, Close)
        row.Destroying:Connect(function() optionsHolder:Destroy() end)

        local api = {}
        function api.Get()
            local r = {}
            for opt, sel in pairs(selected) do if sel then table.insert(r, opt) end end
            return r
        end
        function api.Set(newSel)
            selected = {}
            for _, opt in ipairs(newSel) do selected[opt] = true end
            for opt, dot in pairs(checkMarks) do dot.Visible = selected[opt] == true end
            RefreshBoxText()
        end
        return api
    end

    -- ── ColorPicker ───────────────────────────────────────────────────────────
    function Factory.ColorPicker(parent, config)
        config = config or {}
        local name     = config.Name    or "Color"
        local default  = config.Default or Color3.fromRGB(255, 255, 255)
        local callback = config.Callback

        local row = NewInstance("Frame", {
            Name = "ColorPicker_" .. name,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 28),
            Parent = parent,
        })
        NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -52, 1, 0),
            Font = D.FONT_BODY,
            TextSize = 13,
            TextColor3 = D.TEXT_PRIMARY,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            Parent = row,
        })
        local swatch = NewInstance("TextButton", {
            Name = "Swatch",
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(40, 22),
            BackgroundColor3 = default,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            Parent = row,
        })
        NewInstance("UICorner", { CornerRadius = D.CORNER_SM, Parent = swatch })
        NewInstance("UIStroke", { Color = D.BORDER, Thickness = 1, Parent = swatch })

        local h, s, v = Color3.toHSV(default)
        local currentColor = default

        local panel = NewInstance("Frame", {
            Name = "ColorPickerPanel_" .. name,
            BackgroundColor3 = D.BG_SURFACE,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(188, 210),
            Visible = false,
            ZIndex = 200,
            Parent = ScreenGui,
        })
        NewInstance("UICorner", { CornerRadius = D.CORNER_LG, Parent = panel })
        NewInstance("UIStroke", { Color = D.BORDER, Thickness = 1, Parent = panel })

        local panelHandle = NewInstance("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 24),
            ZIndex = panel.ZIndex + 1,
            Parent = panel,
        })
        NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(10, 0),
            Size = UDim2.new(1, -34, 1, 0),
            Font = D.FONT_MEDIUM,
            TextSize = 11,
            TextColor3 = D.TEXT_SECOND,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            ZIndex = panelHandle.ZIndex + 1,
            Parent = panelHandle,
        })
        local closeBtn = NewInstance("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -4, 0.5, 0),
            Size = UDim2.fromOffset(20, 20),
            BackgroundColor3 = D.BG_ELEVATED,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = D.FONT_TITLE,
            TextSize = 12,
            TextColor3 = D.TEXT_MUTED,
            Text = "\u{2715}",
            ZIndex = panelHandle.ZIndex + 1,
            Parent = panelHandle,
        })
        NewInstance("UICorner", { CornerRadius = D.CORNER_ROUND, Parent = closeBtn })

        local svMap = NewInstance("ImageButton", {
            Name = "SVMap",
            Position = UDim2.fromOffset(10, 32),
            Size = UDim2.fromOffset(168, 112),
            BackgroundColor3 = Color3.fromHSV(h, 1, 1),
            BorderSizePixel = 0,
            AutoButtonColor = false,
            ZIndex = panel.ZIndex + 1,
            Parent = panel,
        })
        NewInstance("UICorner", { CornerRadius = D.CORNER_SM, Parent = svMap })
        local svWhite = NewInstance("Frame", { Size = UDim2.fromScale(1,1), BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel=0, ZIndex=svMap.ZIndex+1, Parent=svMap })
        NewInstance("UIGradient", { Transparency = NumberSequence.new(0,1), Parent = svWhite })
        NewInstance("UICorner", { CornerRadius = D.CORNER_SM, Parent = svWhite })
        local svBlack = NewInstance("Frame", { Size=UDim2.fromScale(1,1), BackgroundColor3=Color3.new(0,0,0), BorderSizePixel=0, ZIndex=svWhite.ZIndex+1, Parent=svMap })
        NewInstance("UIGradient", { Rotation=90, Transparency=NumberSequence.new(1,0), Parent=svBlack })
        NewInstance("UICorner", { CornerRadius = D.CORNER_SM, Parent = svBlack })

        local svCursor = NewInstance("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(10, 10),
            BackgroundColor3 = Color3.new(1,1,1),
            BorderSizePixel = 0,
            ZIndex = svBlack.ZIndex + 1,
            Position = UDim2.new(s, 0, 1-v, 0),
            Parent = svMap,
        })
        NewInstance("UICorner", { CornerRadius = D.CORNER_ROUND, Parent = svCursor })
        NewInstance("UIStroke", { Color = Color3.new(0,0,0), Thickness = 1.5, Parent = svCursor })

        local hueTrack = NewInstance("Frame", {
            Position = UDim2.fromOffset(10, 158),
            Size = UDim2.fromOffset(168, 10),
            BorderSizePixel = 0,
            ZIndex = panel.ZIndex + 1,
            Parent = panel,
        })
        NewInstance("UICorner", { CornerRadius = D.CORNER_ROUND, Parent = hueTrack })
        local hSeq = {}
        for i = 0, 10 do table.insert(hSeq, ColorSequenceKeypoint.new(i/10, Color3.fromHSV(i/10, 1, 1))) end
        NewInstance("UIGradient", { Color = ColorSequence.new(hSeq), Parent = hueTrack })

        local hueCursor = NewInstance("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(h, 0, 0.5, 0),
            Size = UDim2.fromOffset(4, 16),
            BackgroundColor3 = Color3.new(1,1,1),
            BorderSizePixel = 0,
            ZIndex = hueTrack.ZIndex + 1,
            Parent = hueTrack,
        })
        NewInstance("UICorner", { CornerRadius = D.CORNER_SM, Parent = hueCursor })
        NewInstance("UIStroke", { Color = Color3.new(0,0,0), Thickness = 1, Parent = hueCursor })

        local hexBox = NewInstance("TextBox", {
            Position = UDim2.fromOffset(10, 182),
            Size = UDim2.fromOffset(168, 20),
            BackgroundColor3 = D.BG_CONTROL,
            BorderSizePixel = 0,
            Font = Enum.Font.Code,
            TextSize = 12,
            TextColor3 = D.TEXT_PRIMARY,
            ClearTextOnFocus = false,
            Text = "#" .. default:ToHex(),
            ZIndex = panel.ZIndex + 1,
            Parent = panel,
        })
        NewInstance("UICorner", { CornerRadius = D.CORNER_SM, Parent = hexBox })
        NewInstance("UIStroke", { Color = D.BORDER, Thickness = 1, Parent = hexBox })

        local isOpen = false
        local function ApplyColor(fromUser)
            currentColor = Color3.fromHSV(h, s, v)
            swatch.BackgroundColor3 = currentColor
            svMap.BackgroundColor3  = Color3.fromHSV(h, 1, 1)
            hexBox.Text = "#" .. currentColor:ToHex()
            if fromUser and callback then callback(currentColor) end
        end
        local function SetSV(x, y)
            local pos = svMap.AbsolutePosition; local size = svMap.AbsoluteSize
            s = Clamp01((x - pos.X)/size.X); v = 1 - Clamp01((y - pos.Y)/size.Y)
            svCursor.Position = UDim2.new(s, 0, 1-v, 0); ApplyColor(true)
        end
        local function SetHue(x)
            local pos = hueTrack.AbsolutePosition; local size = hueTrack.AbsoluteSize
            h = Clamp01((x - pos.X)/size.X); hueCursor.Position = UDim2.new(h, 0, 0.5, 0); ApplyColor(true)
        end
        MakeValueDragger({svMap},    function(i) SetSV(i.Position.X, i.Position.Y) end, function(i) SetSV(i.Position.X, i.Position.Y) end)
        MakeValueDragger({hueTrack}, function(i) SetHue(i.Position.X) end, function(i) SetHue(i.Position.X) end)
        hexBox.FocusLost:Connect(function()
            local hex = hexBox.Text:gsub("#", "")
            local ok, color = pcall(Color3.fromHex, hex)
            if ok then h, s, v = Color3.toHSV(color); svCursor.Position = UDim2.new(s,0,1-v,0); hueCursor.Position = UDim2.new(h,0,0.5,0); ApplyColor(true)
            else hexBox.Text = "#" .. currentColor:ToHex() end
        end)

        local function Close() isOpen = false; panel.Visible = false end
        local function Open()
            CloseAllOverlaysExcept(panel)
            local sp = swatch.AbsolutePosition; local ss = swatch.AbsoluteSize; local ps = panel.AbsoluteSize
            local x = sp.X - ps.X + ss.X; local y = sp.Y + ss.Y + 4
            x, y = ClampOpenPosition(x, y, ps.X, ps.Y)
            panel.Position = UDim2.fromOffset(x, y); panel.Visible = true; isOpen = true
        end
        swatch.MouseButton1Click:Connect(function() if isOpen then Close() else Open() end end)
        closeBtn.MouseButton1Click:Connect(Close)
        MakeDraggable(panelHandle, panel)
        RegisterOverlay(panel, swatch, function() return isOpen end, Close)
        row.Destroying:Connect(function() panel:Destroy() end)

        local api = {}
        function api.Set(color3)
            h, s, v = Color3.toHSV(color3)
            svCursor.Position = UDim2.new(s,0,1-v,0); hueCursor.Position = UDim2.new(h,0,0.5,0); ApplyColor(false)
        end
        function api.Get() return currentColor end
        return api
    end

    -- ── Textbox ───────────────────────────────────────────────────────────────
    function Factory.Textbox(parent, config)
        config = config or {}
        local name        = config.Name        or "Textbox"
        local default     = config.Default     or ""
        local placeholder = config.Placeholder or ""
        local callback    = config.Callback

        local row = NewInstance("Frame", {
            Name = "Textbox_" .. name,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 42),
            Parent = parent,
        })
        NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 16),
            Font = D.FONT_BODY,
            TextSize = 12,
            TextColor3 = D.TEXT_MUTED,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = string.upper(name),
            Parent = row,
        })
        local box = NewInstance("TextBox", {
            Position = UDim2.fromOffset(0, 20),
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundColor3 = D.BG_CONTROL,
            BorderSizePixel = 0,
            Font = D.FONT_BODY,
            TextSize = 13,
            TextColor3 = D.TEXT_PRIMARY,
            PlaceholderText = placeholder,
            PlaceholderColor3 = D.TEXT_MUTED,
            ClearTextOnFocus = false,
            Text = default,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row,
        })
        NewInstance("UICorner", { CornerRadius = D.CORNER_SM, Parent = box })
        local stroke = NewInstance("UIStroke", { Color = D.BORDER, Thickness = 1, Parent = box })
        NewInstance("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = box })
        box.Focused:Connect(function() TweenService:Create(stroke, D.TWEEN_FAST, { Color = Accent.Value }):Play() end)
        box.FocusLost:Connect(function(ep)
            TweenService:Create(stroke, D.TWEEN_FAST, { Color = D.BORDER }):Play()
            if callback then callback(box.Text, ep) end
        end)
        Accent.Changed:Connect(function(c) if box:IsFocused() then stroke.Color = c end end)
        local api = {}
        function api.Set(t) box.Text = t end
        function api.Get() return box.Text end
        return api
    end

    -- ── Keybind ───────────────────────────────────────────────────────────────
    function Factory.Keybind(parent, config)
        config = config or {}
        local name     = config.Name     or "Keybind"
        local default  = config.Default
        local callback = config.Callback

        local row = NewInstance("Frame", {
            Name = "Keybind_" .. name,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 28),
            Parent = parent,
        })
        NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -96, 1, 0),
            Font = D.FONT_BODY,
            TextSize = 13,
            TextColor3 = D.TEXT_PRIMARY,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            Parent = row,
        })
        local box = NewInstance("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(88, 22),
            BackgroundColor3 = D.BG_CONTROL,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = D.FONT_MEDIUM,
            TextSize = 11,
            TextColor3 = D.TEXT_PRIMARY,
            Text = FormatKeycodeName(default),
            Parent = row,
        })
        NewInstance("UICorner", { CornerRadius = D.CORNER_SM, Parent = box })
        local stroke = NewInstance("UIStroke", { Color = D.BORDER, Thickness = 1, Parent = box })

        local currentKey = default
        local listening  = false

        box.MouseButton1Click:Connect(function()
            if listening then
                listening = false; ActiveKeybindCancel = nil; box.Text = FormatKeycodeName(currentKey)
                TweenService:Create(stroke, D.TWEEN_FAST, { Color = D.BORDER }):Play()
                return
            end
            if ActiveKeybindCancel then ActiveKeybindCancel() end
            listening = true
            ActiveKeybindCancel = function()
                listening = false; box.Text = FormatKeycodeName(currentKey)
                TweenService:Create(stroke, D.TWEEN_FAST, { Color = D.BORDER }):Play()
            end
            box.Text = "\u{25CF}"
            TweenService:Create(stroke, D.TWEEN_FAST, { Color = Accent.Value }):Play()
        end)
        UserInputService.InputBegan:Connect(function(input, gp)
            if not listening or gp then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode == Enum.KeyCode.Escape then
                    listening = false; ActiveKeybindCancel = nil; box.Text = FormatKeycodeName(currentKey)
                    TweenService:Create(stroke, D.TWEEN_FAST, { Color = D.BORDER }):Play()
                    return
                end
                currentKey = input.KeyCode; box.Text = FormatKeycodeName(currentKey)
                listening = false; ActiveKeybindCancel = nil
                TweenService:Create(stroke, D.TWEEN_FAST, { Color = D.BORDER }):Play()
                if callback then callback(currentKey) end
            end
        end)
        local api = {}
        function api.Set(kc) currentKey = kc; box.Text = FormatKeycodeName(kc) end
        function api.Get() return currentKey end
        return api
    end

    -- ── Divider ───────────────────────────────────────────────────────────────
    function Factory.Divider(parent)
        local row = NewInstance("Frame", { Name="Divider", BackgroundTransparency=1, Size=UDim2.new(1,0,0,10), Parent=parent })
        NewInstance("Frame", {
            Name = "Line",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = D.BORDER_SUB,
            BorderSizePixel = 0,
            Parent = row,
        })
        return row
    end

    -- ── Spacer ────────────────────────────────────────────────────────────────
    function Factory.Spacer(parent, height)
        return NewInstance("Frame", { Name="Spacer", BackgroundTransparency=1, Size=UDim2.new(1,0,0,height or 8), Parent=parent })
    end

    -- ── Checkbox ──────────────────────────────────────────────────────────────
    function Factory.Checkbox(parent, config)
        config = config or {}
        local name     = config.Name     or "Checkbox"
        local default  = config.Default  or false
        local callback = config.Callback
        local row = NewInstance("Frame", { Name="Checkbox_"..name, BackgroundTransparency=1, Size=UDim2.new(1,0,0,28), Parent=parent })
        NewInstance("TextLabel", {
            BackgroundTransparency=1, Size=UDim2.new(1,-34,1,0),
            Font=D.FONT_BODY, TextSize=13, TextColor3=D.TEXT_PRIMARY,
            TextXAlignment=Enum.TextXAlignment.Left, Text=name, Parent=row,
        })
        local box = NewInstance("TextButton", {
            AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,0,0.5,0),
            Size=UDim2.fromOffset(20,20),
            BackgroundColor3=default and Accent.Value or D.BG_CONTROL,
            BorderSizePixel=0, AutoButtonColor=false, Text="", Parent=row,
        })
        NewInstance("UICorner", { CornerRadius=D.CORNER_XS, Parent=box })
        local stroke = NewInstance("UIStroke", { Color=default and Accent.Value or D.BORDER, Thickness=1, Parent=box })
        local check = NewInstance("TextLabel", {
            BackgroundTransparency=1, Size=UDim2.fromScale(1,1),
            Font=D.FONT_TITLE, TextSize=13,
            TextColor3=D.BG_BASE, Text="\u{2713}", Visible=default, Parent=box,
        })
        local state = default
        local function ApplyVisual(animated)
            check.Visible = state
            local goal = { BackgroundColor3 = state and Accent.Value or D.BG_CONTROL }
            stroke.Color = state and Accent.Value or D.BORDER
            if animated then TweenService:Create(box, D.TWEEN_FAST, goal):Play()
            else box.BackgroundColor3 = goal.BackgroundColor3 end
        end
        Accent.Changed:Connect(function(c) if state then box.BackgroundColor3=c; stroke.Color=c end end)
        box.MouseButton1Click:Connect(function() state=not state; ApplyVisual(true); if callback then callback(state) end end)
        local api = {}
        function api.Set(v) state=v; ApplyVisual(false) end
        function api.Get() return state end
        return api
    end

    -- ── Switch ────────────────────────────────────────────────────────────────
    function Factory.Switch(parent, config)
        -- Alias to Toggle for consistency
        return Factory.Toggle(parent, config)
    end

    -- ── Segmented ─────────────────────────────────────────────────────────────
    function Factory.Segmented(parent, config)
        config = config or {}
        local name     = config.Name
        local options  = config.Options or {}
        local default  = config.Default or options[1]
        local callback = config.Callback
        local hasLabel = name ~= nil
        local row = NewInstance("Frame", {
            Name="Segmented_"..tostring(name),
            BackgroundTransparency=1,
            Size=UDim2.new(1,0,0,hasLabel and 48 or 28),
            Parent=parent,
        })
        if hasLabel then
            NewInstance("TextLabel", {
                BackgroundTransparency=1, Size=UDim2.new(1,0,0,16),
                Font=D.FONT_BODY, TextSize=12, TextColor3=D.TEXT_MUTED,
                TextXAlignment=Enum.TextXAlignment.Left, Text=string.upper(name), Parent=row,
            })
        end
        local bar = NewInstance("Frame", {
            Position=UDim2.fromOffset(0,hasLabel and 20 or 0),
            Size=UDim2.new(1,0,0,26),
            BackgroundColor3=D.BG_CONTROL, BorderSizePixel=0, Parent=row,
        })
        NewInstance("UICorner", { CornerRadius=D.CORNER_SM, Parent=bar })
        NewInstance("UIStroke", { Color=D.BORDER, Thickness=1, Parent=bar })
        NewInstance("UIListLayout", { FillDirection=Enum.FillDirection.Horizontal, SortOrder=Enum.SortOrder.LayoutOrder, Parent=bar })
        local currentValue = default
        local segButtons = {}
        local function Highlight()
            for opt, btn in pairs(segButtons) do
                if opt == currentValue then
                    btn.BackgroundColor3 = Accent.Value; btn.BackgroundTransparency=0.1
                    btn.TextColor3 = Color3.fromRGB(255,255,255)
                else
                    btn.BackgroundTransparency=1; btn.TextColor3=D.TEXT_SECOND
                end
            end
        end
        local count = #options
        for idx, opt in ipairs(options) do
            local sb = NewInstance("TextButton", {
                Name="Seg_"..tostring(opt),
                BackgroundColor3=Accent.Value, BackgroundTransparency=1, BorderSizePixel=0,
                AutoButtonColor=false, Size=UDim2.new(1/count,0,1,0),
                Font=D.FONT_MEDIUM, TextSize=12, TextColor3=D.TEXT_SECOND,
                Text=tostring(opt), LayoutOrder=idx, Parent=bar,
            })
            segButtons[opt] = sb
            sb.MouseButton1Click:Connect(function()
                currentValue=opt; Highlight(); if callback then callback(opt) end
            end)
        end
        Accent.Changed:Connect(Highlight); Highlight()
        local api = {}
        function api.Set(v) currentValue=v; Highlight() end
        function api.Get() return currentValue end
        return api
    end

    -- ── RadioGroup ────────────────────────────────────────────────────────────
    function Factory.RadioGroup(parent, config)
        config = config or {}
        local name     = config.Name
        local options  = config.Options or {}
        local default  = config.Default or options[1]
        local callback = config.Callback
        local row = NewInstance("Frame", { Name="RadioGroup_"..tostring(name), BackgroundTransparency=1, AutomaticSize=Enum.AutomaticSize.Y, Size=UDim2.new(1,0,0,0), Parent=parent })
        NewInstance("UIListLayout", { Padding=UDim.new(0,6), SortOrder=Enum.SortOrder.LayoutOrder, Parent=row })
        if name then
            NewInstance("TextLabel", { BackgroundTransparency=1, Size=UDim2.new(1,0,0,16), Font=D.FONT_BODY, TextSize=12, TextColor3=D.TEXT_MUTED, TextXAlignment=Enum.TextXAlignment.Left, Text=string.upper(name), Parent=row })
        end
        local currentValue = default
        local dots = {}
        local function SelectOption(opt) currentValue=opt; for k,d in pairs(dots) do d.Visible=(k==opt) end end
        for _, opt in ipairs(options) do
            local optRow = NewInstance("Frame", { BackgroundTransparency=1, Size=UDim2.new(1,0,0,22), Parent=row })
            local optBtn = NewInstance("TextButton", { BackgroundTransparency=1, Size=UDim2.fromScale(1,1), Text="", AutoButtonColor=false, Parent=optRow })
            NewInstance("TextLabel", { BackgroundTransparency=1, Size=UDim2.new(1,-28,1,0), Font=D.FONT_BODY, TextSize=13, TextColor3=D.TEXT_SECOND, TextXAlignment=Enum.TextXAlignment.Left, Text=tostring(opt), Parent=optRow })
            local ring = NewInstance("Frame", { AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,0,0.5,0), Size=UDim2.fromOffset(16,16), BackgroundColor3=D.BG_CONTROL, BorderSizePixel=0, Parent=optRow })
            NewInstance("UICorner", { CornerRadius=D.CORNER_ROUND, Parent=ring })
            NewInstance("UIStroke", { Color=D.BORDER, Thickness=1, Parent=ring })
            local dot = NewInstance("Frame", { AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5), Size=UDim2.fromOffset(8,8), BackgroundColor3=Accent.Value, BorderSizePixel=0, Visible=(opt==default), Parent=ring })
            NewInstance("UICorner", { CornerRadius=D.CORNER_ROUND, Parent=dot })
            dots[opt] = dot
            optBtn.MouseButton1Click:Connect(function() SelectOption(opt); if callback then callback(opt) end end)
        end
        Accent.Changed:Connect(function(c) for _,dot in pairs(dots) do dot.BackgroundColor3=c end end)
        local api = {}
        function api.Set(v) SelectOption(v) end
        function api.Get() return currentValue end
        return api
    end

    -- ── Stepper ───────────────────────────────────────────────────────────────
    function Factory.Stepper(parent, config)
        config = config or {}
        local name     = config.Name    or "Stepper"
        local min      = config.Min     or 0
        local max      = config.Max     or 100
        local step     = config.Step    or 1
        if max < min then min, max = max, min end
        local default  = math.clamp(config.Default or min, min, max)
        local callback = config.Callback
        local row = NewInstance("Frame", { Name="Stepper_"..name, BackgroundTransparency=1, Size=UDim2.new(1,0,0,28), Parent=parent })
        NewInstance("TextLabel", { BackgroundTransparency=1, Size=UDim2.new(1,-110,1,0), Font=D.FONT_BODY, TextSize=13, TextColor3=D.TEXT_PRIMARY, TextXAlignment=Enum.TextXAlignment.Left, Text=name, Parent=row })
        local ctrl = MakeControlFrame(row, "StepCtrl", 24)
        ctrl.AnchorPoint = Vector2.new(1,0.5); ctrl.Position = UDim2.new(1,0,0.5,0)
        ctrl.Size = UDim2.fromOffset(100, 24)
        NewInstance("UIListLayout", { FillDirection=Enum.FillDirection.Horizontal, SortOrder=Enum.SortOrder.LayoutOrder, Parent=ctrl })
        local minusBtn = NewInstance("TextButton", { Size=UDim2.new(0,28,1,0), BackgroundTransparency=1, AutoButtonColor=false, Font=D.FONT_TITLE, TextSize=16, TextColor3=D.TEXT_SECOND, Text="−", Parent=ctrl })
        local valueLabel = NewInstance("TextLabel", { Size=UDim2.new(1,-56,1,0), BackgroundTransparency=1, Font=D.FONT_MEDIUM, TextSize=12, TextColor3=D.TEXT_PRIMARY, Text=tostring(default), Parent=ctrl })
        local plusBtn  = NewInstance("TextButton", { Size=UDim2.new(0,28,1,0), BackgroundTransparency=1, AutoButtonColor=false, Font=D.FONT_TITLE, TextSize=16, TextColor3=D.TEXT_SECOND, Text="+", Parent=ctrl })
        local currentValue = default
        local function SetValue(value, fromUser)
            currentValue = math.clamp(value, min, max); valueLabel.Text = tostring(currentValue)
            if fromUser and callback then callback(currentValue) end
        end
        local function Flash(btn) TweenService:Create(btn, D.TWEEN_FAST, { TextColor3=Accent.Value }):Play(); task.delay(0.14, function() TweenService:Create(btn, D.TWEEN_MED, { TextColor3=D.TEXT_SECOND }):Play() end) end
        minusBtn.MouseButton1Click:Connect(function() SetValue(currentValue-step,true); Flash(minusBtn) end)
        plusBtn.MouseButton1Click:Connect(function()  SetValue(currentValue+step,true); Flash(plusBtn)  end)
        local api = {}
        function api.Set(v) SetValue(v,false) end
        function api.Get() return currentValue end
        return api
    end

    -- ── RangeSlider ───────────────────────────────────────────────────────────
    function Factory.RangeSlider(parent, config)
        config = config or {}
        local name        = config.Name        or "Range"
        local min         = config.Min         or 0
        local max         = config.Max         or 100
        if max < min then min, max = max, min end
        local defaultLow  = math.clamp(config.DefaultLow  or min, min, max)
        local defaultHigh = math.clamp(config.DefaultHigh or max, min, max)
        local step        = config.Step        or 1
        local callback    = config.Callback
        local row = NewInstance("Frame", { Name="RangeSlider_"..name, BackgroundTransparency=1, Size=UDim2.new(1,0,0,40), Parent=parent })
        local badge = NewInstance("TextLabel", {
            BackgroundColor3=D.BG_ELEVATED, AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,0,0,0),
            Size=UDim2.fromOffset(90,18), BorderSizePixel=0, Font=D.FONT_MEDIUM, TextSize=11,
            TextColor3=Accent.Value, Text=tostring(defaultLow).." – "..tostring(defaultHigh), Parent=row,
        })
        NewInstance("UICorner", { CornerRadius=D.CORNER_XS, Parent=badge })
        Accent.Changed:Connect(function(c) badge.TextColor3=c end)
        NewInstance("TextLabel", { BackgroundTransparency=1, Size=UDim2.new(1,-98,0,18), Font=D.FONT_BODY, TextSize=13, TextColor3=D.TEXT_PRIMARY, TextXAlignment=Enum.TextXAlignment.Left, Text=name, Parent=row })
        local track = NewInstance("Frame", { Position=UDim2.fromOffset(0,25), Size=UDim2.new(1,0,0,5), BackgroundColor3=D.BG_ELEVATED, BorderSizePixel=0, Parent=row })
        NewInstance("UICorner", { CornerRadius=D.CORNER_ROUND, Parent=track })
        local lr = (max>min) and Clamp01((defaultLow-min)/(max-min)) or 0
        local hr = (max>min) and Clamp01((defaultHigh-min)/(max-min)) or 0
        local fill = NewInstance("Frame", { Position=UDim2.new(lr,0,0,0), Size=UDim2.new(hr-lr,0,1,0), BackgroundColor3=Accent.Value, BorderSizePixel=0, Parent=track })
        NewInstance("UICorner", { CornerRadius=D.CORNER_ROUND, Parent=fill })
        Accent.Changed:Connect(function(c) fill.BackgroundColor3=c end)
        local function MakeKnob(ratio)
            local k = NewInstance("Frame", { AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new(ratio,0,0.5,0), Size=UDim2.fromOffset(14,14), BackgroundColor3=Color3.fromRGB(240,240,240), BorderSizePixel=0, ZIndex=track.ZIndex+1, Parent=track })
            NewInstance("UICorner", { CornerRadius=D.CORNER_ROUND, Parent=k })
            return k
        end
        local lowKnob  = MakeKnob(lr)
        local highKnob = MakeKnob(hr)
        local currentLow = defaultLow; local currentHigh = defaultHigh
        local function ApplyRange(fromUser)
            local lrr = (max>min) and Clamp01((currentLow-min)/(max-min)) or 0
            local hrr = (max>min) and Clamp01((currentHigh-min)/(max-min)) or 0
            fill.Position=UDim2.new(lrr,0,0,0); fill.Size=UDim2.new(hrr-lrr,0,1,0)
            lowKnob.Position=UDim2.new(lrr,0,0.5,0); highKnob.Position=UDim2.new(hrr,0,0.5,0)
            badge.Text = tostring(currentLow).." – "..tostring(currentHigh)
            if fromUser and callback then callback(currentLow, currentHigh) end
        end
        local function UpdateLow(xPos)
            local tp=track.AbsolutePosition.X; local ts=track.AbsoluteSize.X; if ts<=0 then return end
            currentLow = math.min(math.clamp(RoundTo(min+(max-min)*Clamp01((xPos-tp)/ts),step),min,max), currentHigh); ApplyRange(true)
        end
        local function UpdateHigh(xPos)
            local tp=track.AbsolutePosition.X; local ts=track.AbsoluteSize.X; if ts<=0 then return end
            currentHigh = math.max(math.clamp(RoundTo(min+(max-min)*Clamp01((xPos-tp)/ts),step),min,max), currentLow); ApplyRange(true)
        end
        MakeValueDragger({lowKnob},  function(i) lowKnob.ZIndex=track.ZIndex+2;  highKnob.ZIndex=track.ZIndex+1; UpdateLow(i.Position.X)  end, function(i) UpdateLow(i.Position.X)  end)
        MakeValueDragger({highKnob}, function(i) highKnob.ZIndex=track.ZIndex+2; lowKnob.ZIndex=track.ZIndex+1;  UpdateHigh(i.Position.X) end, function(i) UpdateHigh(i.Position.X) end)
        local api = {}
        function api.Set(low, high)
            currentLow=math.clamp(low,min,max); currentHigh=math.clamp(high,min,max)
            if currentLow>currentHigh then currentLow,currentHigh=currentHigh,currentLow end; ApplyRange(false)
        end
        function api.Get() return currentLow, currentHigh end
        return api
    end

    -- ── KeyValue ──────────────────────────────────────────────────────────────
    function Factory.KeyValue(parent, config)
        config = config or {}
        local key   = config.Key   or ""
        local value = config.Value or ""
        local row = NewInstance("Frame", { Name="KeyValue_"..key, BackgroundTransparency=1, Size=UDim2.new(1,0,0,20), Parent=parent })
        NewInstance("TextLabel", { BackgroundTransparency=1, Size=UDim2.new(0.5,0,1,0), Font=D.FONT_BODY, TextSize=12, TextColor3=D.TEXT_MUTED, TextXAlignment=Enum.TextXAlignment.Left, Text=key, Parent=row })
        local vl = NewInstance("TextLabel", { AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,0,0,0), Size=UDim2.new(0.5,0,1,0), BackgroundTransparency=1, Font=D.FONT_MEDIUM, TextSize=12, TextColor3=D.TEXT_PRIMARY, TextXAlignment=Enum.TextXAlignment.Right, Text=tostring(value), Parent=row })
        local api = {}; function api.Set(v) vl.Text=tostring(v) end; return api
    end

    -- ── Badge ─────────────────────────────────────────────────────────────────
    function Factory.Badge(parent, config)
        config = config or {}
        local name  = config.Name  or "Status"
        local text  = config.Text  or "Active"
        local color = config.Color or Accent.Value
        local row = NewInstance("Frame", { Name="Badge_"..name, BackgroundTransparency=1, Size=UDim2.new(1,0,0,24), Parent=parent })
        NewInstance("TextLabel", { BackgroundTransparency=1, Size=UDim2.new(1,-96,1,0), Font=D.FONT_BODY, TextSize=13, TextColor3=D.TEXT_PRIMARY, TextXAlignment=Enum.TextXAlignment.Left, Text=name, Parent=row })
        local pill = NewInstance("Frame", { AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,0,0.5,0), Size=UDim2.fromOffset(0,18), AutomaticSize=Enum.AutomaticSize.X, BackgroundColor3=color, BackgroundTransparency=0.85, BorderSizePixel=0, Parent=row })
        NewInstance("UICorner", { CornerRadius=D.CORNER_ROUND, Parent=pill })
        local pillStroke = NewInstance("UIStroke", { Color=color, Thickness=1, Parent=pill })
        local lbl = NewInstance("TextLabel", { BackgroundTransparency=1, Size=UDim2.fromOffset(0,18), AutomaticSize=Enum.AutomaticSize.X, Font=D.FONT_MEDIUM, TextSize=11, TextColor3=color, Text=text, Parent=pill })
        NewInstance("UIPadding", { PaddingLeft=UDim.new(0,8), PaddingRight=UDim.new(0,8), Parent=pill })
        local api = {}
        function api.Set(newText, newColor) lbl.Text=newText; if newColor then pill.BackgroundColor3=newColor; lbl.TextColor3=newColor; pillStroke.Color=newColor end end
        return api
    end

    -- ── ToggleSlider ──────────────────────────────────────────────────────────
    function Factory.ToggleSlider(parent, config)
        config = config or {}
        local name           = config.Name            or "ToggleSlider"
        local toggleDefault  = config.ToggleDefault   or false
        local min            = config.Min             or 0
        local max            = config.Max             or 100
        if max < min then min, max = max, min end
        local sliderDefault  = math.clamp(config.SliderDefault or min, min, max)
        local step           = config.Step            or 1
        local toggleCallback = config.ToggleCallback
        local sliderCallback = config.SliderCallback

        local row = NewInstance("Frame", { Name="ToggleSlider_"..name, BackgroundTransparency=1, Size=UDim2.new(1,0,0,40), Parent=parent })
        local badge = NewInstance("TextLabel", {
            BackgroundColor3=D.BG_ELEVATED, AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,0,0,0),
            Size=UDim2.fromOffset(50,18), BorderSizePixel=0, Font=D.FONT_MEDIUM, TextSize=11,
            TextColor3=Accent.Value, Text=tostring(sliderDefault), Parent=row,
        })
        NewInstance("UICorner", { CornerRadius=D.CORNER_XS, Parent=badge })
        Accent.Changed:Connect(function(c) badge.TextColor3=c end)
        NewInstance("TextLabel", { BackgroundTransparency=1, Size=UDim2.new(1,-100,0,18), Font=D.FONT_BODY, TextSize=13, TextColor3=D.TEXT_PRIMARY, TextXAlignment=Enum.TextXAlignment.Left, Text=name, Parent=row })
        -- toggle
        local track = NewInstance("Frame", { Name="Track", AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,0,0,0), Size=UDim2.fromOffset(38,18), BackgroundColor3=toggleDefault and Accent.Value or D.BG_HOVER, BorderSizePixel=0, Parent=row })
        NewInstance("UICorner", { CornerRadius=D.CORNER_ROUND, Parent=track })
        local knobT = NewInstance("Frame", { AnchorPoint=Vector2.new(0.5,0.5), Position=toggleDefault and UDim2.new(1,-10,0.5,0) or UDim2.new(0,10,0.5,0), Size=UDim2.fromOffset(12,12), BackgroundColor3=toggleDefault and Color3.fromRGB(255,255,255) or Color3.fromRGB(110,110,110), BorderSizePixel=0, Parent=track })
        NewInstance("UICorner", { CornerRadius=D.CORNER_ROUND, Parent=knobT })
        -- slider
        local sliderTrack = NewInstance("Frame", { Position=UDim2.fromOffset(0,25), Size=UDim2.new(1,0,0,5), BackgroundColor3=D.BG_ELEVATED, BorderSizePixel=0, Parent=row })
        NewInstance("UICorner", { CornerRadius=D.CORNER_ROUND, Parent=sliderTrack })
        local fr = (max>min) and Clamp01((sliderDefault-min)/(max-min)) or 0
        local sliderFill = NewInstance("Frame", { Size=UDim2.new(fr,0,1,0), BackgroundColor3=Accent.Value, BorderSizePixel=0, Parent=sliderTrack })
        NewInstance("UICorner", { CornerRadius=D.CORNER_ROUND, Parent=sliderFill })
        Accent.Changed:Connect(function(c) sliderFill.BackgroundColor3=c end)
        local knobS = NewInstance("Frame", { AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new(fr,0,0.5,0), Size=UDim2.fromOffset(14,14), BackgroundColor3=Color3.fromRGB(240,240,240), BorderSizePixel=0, ZIndex=sliderTrack.ZIndex+1, Parent=sliderTrack })
        NewInstance("UICorner", { CornerRadius=D.CORNER_ROUND, Parent=knobS })

        local toggleState = toggleDefault; local sliderValue = sliderDefault
        Accent.Changed:Connect(function(c) if toggleState then track.BackgroundColor3=c end end)
        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                toggleState = not toggleState
                TweenService:Create(knobT, D.TWEEN_FAST, { Position=toggleState and UDim2.new(1,-10,0.5,0) or UDim2.new(0,10,0.5,0) }):Play()
                TweenService:Create(track, D.TWEEN_FAST, { BackgroundColor3=toggleState and Accent.Value or D.BG_HOVER }):Play()
                if toggleCallback then toggleCallback(toggleState) end
            end
        end)
        local function UpdateFromX(xPos)
            local tp=sliderTrack.AbsolutePosition.X; local ts=sliderTrack.AbsoluteSize.X; if ts<=0 then return end
            local ratio=Clamp01((xPos-tp)/ts)
            sliderValue=math.clamp(RoundTo(min+(max-min)*ratio,step),min,max)
            local sr=(max>min) and Clamp01((sliderValue-min)/(max-min)) or 0
            sliderFill.Size=UDim2.new(sr,0,1,0); knobS.Position=UDim2.new(sr,0,0.5,0); badge.Text=tostring(sliderValue)
            if sliderCallback then sliderCallback(sliderValue) end
        end
        MakeValueDragger({knobS,sliderTrack}, function(i) UpdateFromX(i.Position.X) end, function(i) UpdateFromX(i.Position.X) end)
        local api = {}
        function api.GetToggle() return toggleState end
        function api.GetSlider() return sliderValue end
        return api
    end

    -- ── SearchableDropdown ────────────────────────────────────────────────────
    function Factory.SearchableDropdown(parent, config)
        config = config or {}
        local name     = config.Name     or "Dropdown"
        local options  = config.Options  or {}
        local default  = config.Default  or options[1]
        local callback = config.Callback
        local row = NewInstance("Frame", { Name="SearchableDropdown_"..name, BackgroundTransparency=1, Size=UDim2.new(1,0,0,50), Parent=parent })
        NewInstance("TextLabel", { BackgroundTransparency=1, Size=UDim2.new(1,0,0,16), Font=D.FONT_BODY, TextSize=12, TextColor3=D.TEXT_MUTED, TextXAlignment=Enum.TextXAlignment.Left, Text=string.upper(name), Parent=row })
        local box = NewInstance("TextButton", { Position=UDim2.fromOffset(0,20), Size=UDim2.new(1,0,0,28), BackgroundColor3=D.BG_CONTROL, BorderSizePixel=0, AutoButtonColor=false, Font=D.FONT_BODY, TextSize=13, TextColor3=D.TEXT_PRIMARY, TextXAlignment=Enum.TextXAlignment.Left, Text="  "..tostring(default or ""), Parent=row })
        NewInstance("UICorner", { CornerRadius=D.CORNER_SM, Parent=box })
        NewInstance("UIStroke", { Color=D.BORDER, Thickness=1, Parent=box })
        local arrow = NewInstance("TextLabel", { BackgroundTransparency=1, AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,-8,0.5,0), Size=UDim2.fromOffset(16,16), Font=D.FONT_TITLE, TextSize=10, TextColor3=Accent.Value, Text="\u{25BE}", Parent=box })
        Accent.Changed:Connect(function(c) arrow.TextColor3=c end)
        local panelH = math.min(#options, 5)*26 + 28
        local holder = NewInstance("Frame", { Name="SearchDropHolder_"..name, BackgroundColor3=D.BG_SURFACE, BorderSizePixel=0, Size=UDim2.fromOffset(0,panelH), Visible=false, ZIndex=200, Parent=ScreenGui })
        NewInstance("UICorner", { CornerRadius=D.CORNER_MD, Parent=holder })
        NewInstance("UIStroke", { Color=D.BORDER, Thickness=1, Parent=holder })
        local searchBox = NewInstance("TextBox", { Position=UDim2.fromOffset(4,4), Size=UDim2.new(1,-8,0,22), BackgroundColor3=D.BG_CONTROL, BorderSizePixel=0, Font=D.FONT_BODY, TextSize=12, TextColor3=D.TEXT_PRIMARY, PlaceholderText="Search…", PlaceholderColor3=D.TEXT_MUTED, ClearTextOnFocus=false, Text="", ZIndex=holder.ZIndex+1, Parent=holder })
        NewInstance("UICorner", { CornerRadius=D.CORNER_SM, Parent=searchBox })
        NewInstance("UIStroke", { Color=D.BORDER, Thickness=1, Parent=searchBox })
        NewInstance("UIPadding", { PaddingLeft=UDim.new(0,6), Parent=searchBox })
        local listHolder = NewInstance("ScrollingFrame", { Position=UDim2.fromOffset(0,30), Size=UDim2.new(1,0,1,-30), BackgroundTransparency=1, BorderSizePixel=0, CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollBarThickness=0, ZIndex=holder.ZIndex+1, Parent=holder })
        NewInstance("UIListLayout", { SortOrder=Enum.SortOrder.LayoutOrder, Parent=listHolder })
        local currentValue = default; local isOpen = false
        local function Close() isOpen=false; holder.Visible=false end
        local function RebuildOptions(filterText)
            for _, child in ipairs(listHolder:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
            filterText = (filterText or ""):lower()
            for _, opt in ipairs(options) do
                if filterText=="" or tostring(opt):lower():find(filterText,1,true) then
                    local ob = NewInstance("TextButton", { BackgroundColor3=D.BG_SURFACE, BorderSizePixel=0, AutoButtonColor=false, Size=UDim2.new(1,0,0,26), Font=D.FONT_BODY, TextSize=13, TextColor3=D.TEXT_SECOND, TextXAlignment=Enum.TextXAlignment.Left, Text="  "..tostring(opt), ZIndex=listHolder.ZIndex+1, Parent=listHolder })
                    ob.MouseButton1Click:Connect(function() currentValue=opt; box.Text="  "..tostring(opt); Close(); if callback then callback(opt) end end)
                end
            end
        end
        RebuildOptions("")
        searchBox:GetPropertyChangedSignal("Text"):Connect(function() RebuildOptions(searchBox.Text) end)
        local function Open()
            CloseAllOverlaysExcept(holder)
            local bp=box.AbsolutePosition; local bs=box.AbsoluteSize
            holder.Size=UDim2.fromOffset(bs.X,panelH)
            local x,y=ClampOpenPosition(bp.X, bp.Y+bs.Y+2, bs.X, panelH)
            holder.Position=UDim2.fromOffset(x,y); holder.Visible=true; isOpen=true; searchBox.Text=""
        end
        box.MouseButton1Click:Connect(function() if isOpen then Close() else Open() end end)
        RegisterOverlay(holder, box, function() return isOpen end, Close)
        row.Destroying:Connect(function() holder:Destroy() end)
        local api = {}
        function api.Set(v) currentValue=v; box.Text="  "..tostring(v) end
        function api.Get() return currentValue end
        return api
    end

    -- ── Input ─────────────────────────────────────────────────────────────────
    function Factory.Input(parent, config)
        config = config or {}
        local name        = config.Name        or "Input"
        local default     = config.Default     or ""
        local placeholder = config.Placeholder or ""
        local numeric     = config.Numeric     or false
        local min         = config.Min
        local max         = config.Max
        local callback    = config.Callback
        local row = NewInstance("Frame", { Name="Input_"..name, BackgroundTransparency=1, Size=UDim2.new(1,0,0,42), Parent=parent })
        NewInstance("TextLabel", { BackgroundTransparency=1, Size=UDim2.new(1,0,0,16), Font=D.FONT_BODY, TextSize=12, TextColor3=D.TEXT_MUTED, TextXAlignment=Enum.TextXAlignment.Left, Text=string.upper(name), Parent=row })
        local box = NewInstance("TextBox", { Position=UDim2.fromOffset(0,20), Size=UDim2.new(1,0,0,22), BackgroundColor3=D.BG_CONTROL, BorderSizePixel=0, Font=D.FONT_BODY, TextSize=13, TextColor3=D.TEXT_PRIMARY, PlaceholderText=placeholder, PlaceholderColor3=D.TEXT_MUTED, ClearTextOnFocus=false, Text=tostring(default), TextXAlignment=Enum.TextXAlignment.Left, Parent=row })
        NewInstance("UICorner", { CornerRadius=D.CORNER_SM, Parent=box })
        local stroke = NewInstance("UIStroke", { Color=D.BORDER, Thickness=1, Parent=box })
        NewInstance("UIPadding", { PaddingLeft=UDim.new(0,8), PaddingRight=UDim.new(0,8), Parent=box })
        box.Focused:Connect(function() TweenService:Create(stroke, D.TWEEN_FAST, { Color=Accent.Value }):Play() end)
        box.FocusLost:Connect(function(ep)
            TweenService:Create(stroke, D.TWEEN_FAST, { Color=D.BORDER }):Play()
            if numeric then
                local n = tonumber(box.Text)
                if n == nil then n = tonumber(default) or 0 end
                if min then n = math.max(n, min) end
                if max then n = math.min(n, max) end
                box.Text = tostring(n)
                if callback then callback(n, ep) end
            else
                if callback then callback(box.Text, ep) end
            end
        end)
        Accent.Changed:Connect(function(c) if box:IsFocused() then stroke.Color=c end end)
        local api = {}
        function api.Set(v) box.Text=tostring(v) end
        function api.Get() return numeric and tonumber(box.Text) or box.Text end
        return api
    end

    -- ── Group ─────────────────────────────────────────────────────────────────
    function Factory.Group(parent, config)
        config = config or {}
        local name      = config.Name or "Group"
        local startOpen = config.Open
        if startOpen == nil then startOpen = true end

        local container = NewInstance("Frame", {
            Name = "Group_" .. name,
            BackgroundColor3 = D.BG_SURFACE,
            BorderSizePixel = 0,
            AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(1, 0, 0, 0),
            Parent = parent,
        })
        NewInstance("UICorner", { CornerRadius = D.CORNER_MD, Parent = container })
        NewInstance("UIStroke", { Color = D.BORDER_SUB, Thickness = 1, Parent = container })
        NewInstance("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = container })

        local header = NewInstance("TextButton", {
            Name = "Header",
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Size = UDim2.new(1, 0, 0, 30),
            Text = "",
            Parent = container,
        })
        NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(1, -36, 1, 0),
            Font = D.FONT_MEDIUM,
            TextSize = 13,
            TextColor3 = D.TEXT_PRIMARY,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            Parent = header,
        })
        local chevron = NewInstance("TextLabel", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -10, 0.5, 0),
            Size = UDim2.fromOffset(16, 16),
            BackgroundTransparency = 1,
            Font = D.FONT_TITLE,
            TextSize = 10,
            TextColor3 = D.TEXT_MUTED,
            Text = startOpen and "\u{25BE}" or "\u{25B8}",
            Parent = header,
        })
        local body = NewInstance("Frame", {
            Name = "Body",
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(1, 0, 0, 0),
            Visible = startOpen,
            Parent = container,
        })
        NewInstance("UIPadding", { PaddingLeft=UDim.new(0,10), PaddingRight=UDim.new(0,10), PaddingBottom=UDim.new(0,12), Parent=body })
        NewInstance("UIListLayout", { Padding=UDim.new(0,10), SortOrder=Enum.SortOrder.LayoutOrder, Parent=body })
        local isOpen = startOpen
        header.MouseButton1Click:Connect(function()
            isOpen = not isOpen
            body.Visible = isOpen
            chevron.Text = isOpen and "\u{25BE}" or "\u{25B8}"
        end)
        local Group = {}
        Group.Instance = container
        local function Add(fn, ...) return fn(body, ...) end
        function Group:AddLabel(t)              return Factory.Label(body, t) end
        function Group:AddParagraph(c)          return Factory.Paragraph(body, c) end
        function Group:AddSection(t)            return Factory.Section(body, t) end
        function Group:AddToggle(c)             return Factory.Toggle(body, c) end
        function Group:AddCheckbox(c)           return Factory.Checkbox(body, c) end
        function Group:AddSlider(c)             return Factory.Slider(body, c) end
        function Group:AddRangeSlider(c)        return Factory.RangeSlider(body, c) end
        function Group:AddStepper(c)            return Factory.Stepper(body, c) end
        function Group:AddButton(c)             return Factory.Button(body, c) end
        function Group:AddToggleSlider(c)       return Factory.ToggleSlider(body, c) end
        function Group:AddDropdown(c)           return Factory.Dropdown(body, c) end
        function Group:AddMultiDropdown(c)      return Factory.MultiDropdown(body, c) end
        function Group:AddSearchableDropdown(c) return Factory.SearchableDropdown(body, c) end
        function Group:AddRadioGroup(c)         return Factory.RadioGroup(body, c) end
        function Group:AddSwitch(c)             return Factory.Switch(body, c) end
        function Group:AddSegmented(c)          return Factory.Segmented(body, c) end
        function Group:AddColorPicker(c)        return Factory.ColorPicker(body, c) end
        function Group:AddTextbox(c)            return Factory.Textbox(body, c) end
        function Group:AddInput(c)              return Factory.Input(body, c) end
        function Group:AddKeybind(c)            return Factory.Keybind(body, c) end
        function Group:AddProgressBar(c)        return Factory.ProgressBar(body, c) end
        function Group:AddImage(c)              return Factory.Image(body, c) end
        function Group:AddKeyValue(c)           return Factory.KeyValue(body, c) end
        function Group:AddBadge(c)              return Factory.Badge(body, c) end
        function Group:AddDivider()             return Factory.Divider(body) end
        function Group:AddSpacer(h)             return Factory.Spacer(body, h) end
        function Group:AddGroup(c)              return Factory.Group(body, c) end
        function Group:SetOpen(open) isOpen=open; body.Visible=isOpen; chevron.Text=isOpen and "\u{25BE}" or "\u{25B8}" end
        return Group
    end

    return Factory
end
-- ──────────────────────────────────────────────────────────────────────────────

-- ─── TAB ──────────────────────────────────────────────────────────────────────
local function CreateTab(context, tabName, isFirst)
    local Factory     = context.Factory
    local ScrollHolder = context.ScrollHolder

    local scroll = NewInstance("ScrollingFrame", {
        Name = tabName .. "_Scroll",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromScale(0, 0),
        CanvasSize = UDim2.new(0,0,0,0),
        AutomaticCanvasSize = Enum.AutomaticSize.None,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Color3.fromRGB(50,50,50),
        ScrollBarImageTransparency = 0,
        ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
        ClipsDescendants = true,
        Visible = isFirst,
        ZIndex = ScrollHolder.ZIndex + 1,
        Parent = ScrollHolder,
    })
    local layout = NewInstance("UIListLayout", { Padding=UDim.new(0,10), SortOrder=Enum.SortOrder.LayoutOrder, Parent=scroll })
    NewInstance("UIPadding", { PaddingTop=UDim.new(0,6), PaddingBottom=UDim.new(0,16), PaddingLeft=UDim.new(0,2), PaddingRight=UDim.new(0,6), Parent=scroll })

    local function RefreshCanvas()
        scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 28)
    end
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(RefreshCanvas)

    local Tab = {}; Tab.Name = tabName; Tab.Instance = scroll
    function Tab:AddLabel(t)              return Factory.Label(scroll, t) end
    function Tab:AddParagraph(c)          return Factory.Paragraph(scroll, c) end
    function Tab:AddSection(t)            return Factory.Section(scroll, t) end
    function Tab:AddToggle(c)             return Factory.Toggle(scroll, c) end
    function Tab:AddSlider(c)             return Factory.Slider(scroll, c) end
    function Tab:AddButton(c)             return Factory.Button(scroll, c) end
    function Tab:AddProgressBar(c)        return Factory.ProgressBar(scroll, c) end
    function Tab:AddImage(c)              return Factory.Image(scroll, c) end
    function Tab:AddDropdown(c)           return Factory.Dropdown(scroll, c) end
    function Tab:AddMultiDropdown(c)      return Factory.MultiDropdown(scroll, c) end
    function Tab:AddColorPicker(c)        return Factory.ColorPicker(scroll, c) end
    function Tab:AddTextbox(c)            return Factory.Textbox(scroll, c) end
    function Tab:AddKeybind(c)            return Factory.Keybind(scroll, c) end
    function Tab:AddDivider()             return Factory.Divider(scroll) end
    function Tab:AddSpacer(h)             return Factory.Spacer(scroll, h) end
    function Tab:AddCheckbox(c)           return Factory.Checkbox(scroll, c) end
    function Tab:AddRadioGroup(c)         return Factory.RadioGroup(scroll, c) end
    function Tab:AddSwitch(c)             return Factory.Switch(scroll, c) end
    function Tab:AddSegmented(c)          return Factory.Segmented(scroll, c) end
    function Tab:AddStepper(c)            return Factory.Stepper(scroll, c) end
    function Tab:AddRangeSlider(c)        return Factory.RangeSlider(scroll, c) end
    function Tab:AddKeyValue(c)           return Factory.KeyValue(scroll, c) end
    function Tab:AddBadge(c)              return Factory.Badge(scroll, c) end
    function Tab:AddToggleSlider(c)       return Factory.ToggleSlider(scroll, c) end
    function Tab:AddSearchableDropdown(c) return Factory.SearchableDropdown(scroll, c) end
    function Tab:AddInput(c)              return Factory.Input(scroll, c) end
    function Tab:AddGroup(c)              return Factory.Group(scroll, c) end
    function Tab:Refresh()                RefreshCanvas() end
    task.defer(RefreshCanvas)
    return Tab
end
-- ──────────────────────────────────────────────────────────────────────────────

-- ─── ICON MAP for common tab names ────────────────────────────────────────────
-- Unicode symbols that render in Roblox's Gotham font
local ICON_MAP = {
    ["main"]     = "\u{2302}",  -- ⌂ home
    ["home"]     = "\u{2302}",
    ["settings"] = "\u{2699}",  -- ⚙
    ["setting"]  = "\u{2699}",
    ["config"]   = "\u{2699}",
    ["visuals"]  = "\u{25A1}",  -- □ display
    ["visual"]   = "\u{25A1}",
    ["aim"]      = "\u{25CE}",  -- ◎ bullseye
    ["aimbot"]   = "\u{25CE}",
    ["combat"]   = "\u{2694}",  -- ⚔ crossed swords
    ["misc"]     = "\u{2605}",  -- ★ star
    ["player"]   = "\u{25CF}",  -- ● filled circle
    ["players"]  = "\u{25CF}",
    ["world"]    = "\u{25CB}",  -- ○ globe
    ["esp"]      = "\u{25A1}",
    ["speed"]    = "\u{25B6}",  -- ▶
    ["fly"]      = "\u{25B2}",  -- ▲
    ["teleport"] = "\u{21E5}",  -- ⇥
    ["credits"]  = "\u{2665}",  -- ♥
    ["about"]    = "\u{2139}",  -- ℹ
    ["info"]     = "\u{2139}",
    ["debug"]    = "\u{25CA}",  -- ◊
}
local function GetTabIcon(tabName)
    local key = tabName:lower()
    return ICON_MAP[key] or "\u{25AA}"  -- ▪ small square as fallback
end
-- ──────────────────────────────────────────────────────────────────────────────

-- ─── WINDOW ───────────────────────────────────────────────────────────────────
local function CreateWindow(config)
    config = config or {}
    local windowName    = config.Name         or "Lurk"
    local windowSize    = config.Size         or UDim2.fromOffset(460, 340)
    local sidebarWidth  = config.SidebarWidth or 112
    local startColor    = config.AccentColor  or Color3.fromRGB(99, 149, 255)

    -- The first letter of the window name is used as the open button label
    local openButtonText = config.OpenButtonText or string.sub(windowName, 1, 1)

    -- Remove any old instance
    for _, gui in ipairs(GuiParent:GetChildren()) do
        if gui.Name == "LurkGui_" .. windowName or gui.Name == "LurkOpenBtn_" .. windowName then
            gui:Destroy()
        end
    end

    -- ── Accent observable ─────────────────────────────────────────────────────
    local Accent = {}
    Accent.Value = startColor
    Accent._bindable = Instance.new("BindableEvent")
    Accent.Changed = Accent._bindable.Event
    function Accent.Set(color)
        Accent.Value = color
        Accent._bindable:Fire(color)
    end

    -- ── Main window ScreenGui (ZO_MAIN) ──────────────────────────────────────
    local ScreenGui = NewInstance("ScreenGui", {
        Name = "LurkGui_" .. windowName,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = ZO_MAIN,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    ProtectGui(ScreenGui)
    ScreenGui.Parent = GuiParent

    -- ── Open button ScreenGui (ZO_OPENBUTTON — above everything) ─────────────
    local OpenBtnGui = NewInstance("ScreenGui", {
        Name = "LurkOpenBtn_" .. windowName,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = ZO_OPENBUTTON,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    ProtectGui(OpenBtnGui)
    OpenBtnGui.Parent = GuiParent

    -- ── Main window frame ─────────────────────────────────────────────────────
    local mainWindow = NewInstance("Frame", {
        Name = "MainWindow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = windowSize,
        BackgroundColor3 = D.BG_BASE,
        BorderSizePixel = 0,
        ClipsDescendants = false,
        Visible = false,
        ZIndex = 2,
        Parent = ScreenGui,
    })
    NewInstance("UICorner", { CornerRadius = D.CORNER_LG, Parent = mainWindow })
    NewInstance("UIStroke", {
        Color = D.BORDER,
        Thickness = 1,
        Transparency = 0,
        Parent = mainWindow,
    })

    -- subtle inner glow layer
    local innerGlow = NewInstance("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, 2, 1, 2),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = mainWindow.ZIndex - 1,
        Parent = ScreenGui,
    })
    NewInstance("UICorner", { CornerRadius = D.CORNER_LG, Parent = innerGlow })
    local glowStroke = NewInstance("UIStroke", {
        Color = Accent.Value,
        Thickness = 1,
        Transparency = 0.82,
        Parent = innerGlow,
    })
    Accent.Changed:Connect(function(c) glowStroke.Color = c end)

    local bg2 = NewInstance("Frame", { BackgroundTransparency=1, Size=UDim2.fromScale(1,1), ZIndex=mainWindow.ZIndex+1, Parent=mainWindow })

    -- ── Title bar ─────────────────────────────────────────────────────────────
    local titleBar = NewInstance("Frame", {
        Name = "TitleBar",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, 0, 0, 38),
        ZIndex = bg2.ZIndex + 1,
        Parent = bg2,
    })
    -- thin accent line at top
    local accentLine = NewInstance("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 0),
        Size = UDim2.new(0.35, 0, 0, 2),
        BackgroundColor3 = Accent.Value,
        BorderSizePixel = 0,
        ZIndex = titleBar.ZIndex + 1,
        Parent = titleBar,
    })
    NewInstance("UICorner", { CornerRadius = D.CORNER_ROUND, Parent = accentLine })
    Accent.Changed:Connect(function(c) accentLine.BackgroundColor3 = c end)

    local titleText = NewInstance("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(sidebarWidth + 14, 0),
        Size = UDim2.new(1, -sidebarWidth - 54, 1, 0),
        Font = D.FONT_TITLE,
        TextSize = 14,
        TextColor3 = D.TEXT_SECOND,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = windowName,
        ZIndex = titleBar.ZIndex + 1,
        Parent = titleBar,
    })
    local tabTitleLabel = NewInstance("TextLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 0),
        Size = UDim2.fromOffset(200, 38),
        Font = D.FONT_TITLE,
        TextSize = 16,
        TextColor3 = D.TEXT_PRIMARY,
        TextXAlignment = Enum.TextXAlignment.Right,
        Text = "",
        ZIndex = titleBar.ZIndex + 1,
        Parent = titleBar,
    })

    -- ── Sidebar ────────────────────────────────────────────────────────────────
    local sidebar = NewInstance("Frame", {
        Name = "Sidebar",
        BackgroundColor3 = D.BG_SURFACE,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(1, 38),
        Size = UDim2.new(0, sidebarWidth - 2, 1, -42),
        ZIndex = bg2.ZIndex + 1,
        Parent = bg2,
    })
    NewInstance("UICorner", { CornerRadius = D.CORNER_MD, Parent = sidebar })
    NewInstance("UIStroke", { Color = D.BORDER_SUB, Thickness = 1, Parent = sidebar })

    local sidebarInner = NewInstance("Frame", { BackgroundTransparency=1, Size=UDim2.fromScale(1,1), ZIndex=sidebar.ZIndex+1, Parent=sidebar })

    -- sidebar brand mark
    local brandLabel = NewInstance("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 44),
        Position = UDim2.fromOffset(0, 6),
        Font = D.FONT_TITLE,
        Text = windowName,
        TextSize = 15,
        TextColor3 = Accent.Value,
        ZIndex = sidebarInner.ZIndex + 1,
        Parent = sidebarInner,
    })
    Accent.Changed:Connect(function(c) brandLabel.TextColor3 = c end)

    -- divider under brand
    local brandDiv = NewInstance("Frame", {
        Position = UDim2.fromOffset(8, 52),
        Size = UDim2.new(1, -16, 0, 1),
        BackgroundColor3 = D.BORDER_SUB,
        BorderSizePixel = 0,
        ZIndex = sidebarInner.ZIndex + 1,
        Parent = sidebarInner,
    })

    -- scrollable tab list
    local tabListHolder = NewInstance("ScrollingFrame", {
        Name = "TabList",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 58),
        Size = UDim2.new(1, 0, 1, -62),
        CanvasSize = UDim2.new(0,0,0,0),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 0,
        ClipsDescendants = true,
        ZIndex = sidebarInner.ZIndex + 1,
        Parent = sidebarInner,
    })
    local tabListLayout = NewInstance("UIListLayout", {
        Padding = UDim.new(0, 3),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = tabListHolder,
    })
    NewInstance("UIPadding", { PaddingLeft=UDim.new(0,6), PaddingRight=UDim.new(0,6), PaddingTop=UDim.new(0,4), Parent=tabListHolder })
    tabListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        tabListHolder.CanvasSize = UDim2.new(0,0,0, tabListLayout.AbsoluteContentSize.Y + 6)
    end)

    -- ── Content area ──────────────────────────────────────────────────────────
    local contentArea = NewInstance("Frame", {
        Name = "ContentArea",
        BackgroundColor3 = D.BG_ELEVATED,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(sidebarWidth + 4, 38),
        Size = UDim2.new(1, -(sidebarWidth + 7), 1, -42),
        ZIndex = bg2.ZIndex + 1,
        Parent = bg2,
    })
    NewInstance("UICorner", { CornerRadius = D.CORNER_MD, Parent = contentArea })
    NewInstance("UIStroke", { Color = D.BORDER_SUB, Thickness = 1, Parent = contentArea })

    local contentInner = NewInstance("Frame", { BackgroundTransparency=1, Size=UDim2.fromScale(1,1), ZIndex=contentArea.ZIndex+1, Parent=contentArea })

    local scrollHolder = NewInstance("Frame", {
        Name = "ScrollHolder",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 4),
        Size = UDim2.new(1, 0, 1, -4),
        ZIndex = contentInner.ZIndex + 1,
        Parent = contentInner,
    })

    -- ── Notification area ─────────────────────────────────────────────────────
    local notifyHolder = NewInstance("Frame", {
        Name = "NotifyHolder",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -10, 1, -10),
        Size = UDim2.fromOffset(270, 500),
        ZIndex = 300,
        Parent = ScreenGui,
    })
    NewInstance("UIListLayout", { Padding=UDim.new(0,6), VerticalAlignment=Enum.VerticalAlignment.Bottom, HorizontalAlignment=Enum.HorizontalAlignment.Right, SortOrder=Enum.SortOrder.LayoutOrder, Parent=notifyHolder })

    -- ── Factory ───────────────────────────────────────────────────────────────
    local Factory = CreateElementFactory({ ScreenGui = ScreenGui, Accent = Accent })

    -- ── Window state ──────────────────────────────────────────────────────────
    local Window = {}
    Window.Name       = windowName
    Window.Instance   = mainWindow
    Window.ScreenGui  = ScreenGui
    Window.Accent     = Accent

    local tabs       = {}
    local tabButtons = {}
    local selectedTab = nil

    local function SelectTab(tabName)
        if not tabs[tabName] then return end
        selectedTab = tabName
        tabTitleLabel.Text = tabName
        for name, tab in pairs(tabs) do tab.Instance.Visible = (name == tabName) end
        for name, btn in pairs(tabButtons) do
            local isSel = (name == tabName)
            TweenService:Create(btn.bg,   D.TWEEN_FAST, { BackgroundColor3 = isSel and Accent.Value or D.BG_BASE,  BackgroundTransparency = isSel and 0.1 or 1 }):Play()
            TweenService:Create(btn.icon, D.TWEEN_FAST, { TextColor3 = isSel and Accent.Value or D.TEXT_MUTED }):Play()
            TweenService:Create(btn.lbl,  D.TWEEN_FAST, { TextColor3 = isSel and D.TEXT_PRIMARY or D.TEXT_MUTED }):Play()
        end
        CloseAllOverlays()
    end

    Accent.Changed:Connect(function(c)
        if selectedTab and tabButtons[selectedTab] then
            tabButtons[selectedTab].bg.BackgroundColor3 = c
        end
    end)

    function Window:AddTab(tabName)
        if tabs[tabName] then return tabs[tabName] end
        local isFirst = (next(tabs) == nil)
        local tab = CreateTab({ Factory = Factory, ScrollHolder = scrollHolder }, tabName, isFirst)
        tabs[tabName] = tab

        local idx = 0; for _ in pairs(tabButtons) do idx = idx + 1 end

        -- tab button container
        local btnFrame = NewInstance("Frame", {
            Name = "TabBtn_" .. tabName,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 32),
            LayoutOrder = idx,
            Parent = tabListHolder,
        })
        local btnBg = NewInstance("TextButton", {
            Name = "BG",
            BackgroundColor3 = isFirst and Accent.Value or D.BG_BASE,
            BackgroundTransparency = isFirst and 0.1 or 1,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            AutoButtonColor = false,
            Text = "",
            Parent = btnFrame,
        })
        NewInstance("UICorner", { CornerRadius = D.CORNER_SM, Parent = btnBg })

        -- icon
        local icon = NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(8, 0),
            Size = UDim2.new(0, 22, 1, 0),
            Font = D.FONT_TITLE,
            TextSize = 13,
            TextColor3 = isFirst and Accent.Value or D.TEXT_MUTED,
            Text = GetTabIcon(tabName),
            Parent = btnBg,
        })
        -- label
        local lbl = NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(32, 0),
            Size = UDim2.new(1, -34, 1, 0),
            Font = D.FONT_MEDIUM,
            TextSize = 12,
            TextColor3 = isFirst and D.TEXT_PRIMARY or D.TEXT_MUTED,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = tabName,
            Parent = btnBg,
        })

        tabButtons[tabName] = { bg = btnBg, icon = icon, lbl = lbl }

        btnBg.MouseButton1Click:Connect(function() SelectTab(tabName) end)

        -- hover effect
        btnBg.MouseEnter:Connect(function()
            if tabName ~= selectedTab then
                TweenService:Create(btnBg, D.TWEEN_FAST, { BackgroundTransparency = 0.92 }):Play()
            end
        end)
        btnBg.MouseLeave:Connect(function()
            if tabName ~= selectedTab then
                TweenService:Create(btnBg, D.TWEEN_FAST, { BackgroundTransparency = 1 }):Play()
            end
        end)

        if isFirst then SelectTab(tabName) end
        return tab
    end

    function Window:SelectTab(tabName) SelectTab(tabName) end
    function Window:SetAccentColor(c) Accent.Set(c) end

    -- ── Open / Close animation ────────────────────────────────────────────────
    local menuOpen  = false
    local animating = false

    local function ApplyOpenState(open)
        if not open then CloseAllOverlays() end
        local collapsed = UDim2.new(
            windowSize.X.Scale * 0.92, windowSize.X.Offset * 0.92,
            windowSize.Y.Scale * 0.92, windowSize.Y.Offset * 0.92
        )
        if open then
            mainWindow.Visible = true
            mainWindow.Size = collapsed
            local tw = TweenService:Create(mainWindow, D.TWEEN_OPEN, { Size = windowSize })
            tw:Play()
            tw.Completed:Connect(function() animating = false end)
        else
            local tw = TweenService:Create(mainWindow, D.TWEEN_CLOSE, { Size = collapsed })
            tw:Play()
            tw.Completed:Connect(function() mainWindow.Visible = false; animating = false end)
        end
    end

    function Window:Toggle(open)
        if animating then return end
        if open == nil then open = not menuOpen end
        menuOpen = open
        animating = true
        ApplyOpenState(open)
    end

    -- ── Open button (in its OWN ScreenGui at ZO_OPENBUTTON) ──────────────    -- Open button
    local openButton = NewInstance("TextButton", {
        Name = "OpenMenuButton",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(52, 52),
        BackgroundColor3 = D.BG_SURFACE,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = D.FONT_TITLE,
        TextSize = 20,
        Text = openButtonText,
        TextColor3 = Accent.Value,
        ZIndex = 100,
        Parent = OpenBtnGui,
    })
    NewInstance("UICorner", { CornerRadius = D.CORNER_ROUND, Parent = openButton })
    local openBtnStroke = NewInstance("UIStroke", {
        Color = Accent.Value,
        Thickness = 1.5,
        Transparency = 0.5,
        Parent = openButton,
    })
    Accent.Changed:Connect(function(c)
        openButton.TextColor3 = c
        openBtnStroke.Color   = c
    end)

    -- pulse ring on open button
    local pulseRing = NewInstance("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(52, 52),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = openButton.ZIndex - 1,
        Parent = openButton,
    })
    NewInstance("UICorner", { CornerRadius = D.CORNER_ROUND, Parent = pulseRing })
    local pulseStroke = NewInstance("UIStroke", { Color = Accent.Value, Thickness = 1.5, Transparency = 1, Parent = pulseRing })
    Accent.Changed:Connect(function(c) pulseStroke.Color = c end)

    local function PulseOpenBtn()
        pulseRing.Size = UDim2.fromOffset(52, 52)
        pulseStroke.Transparency = 0.4
        TweenService:Create(pulseRing, TweenInfo.new(0.4, Enum.EasingStyle.Quint), { Size = UDim2.fromOffset(72, 72) }):Play()
        TweenService:Create(pulseStroke, TweenInfo.new(0.4, Enum.EasingStyle.Quint), { Transparency = 1 }):Play()
    end

    openButton.MouseButton1Click:Connect(function()
        if not openButton:GetAttribute("WasDragged") then
            PulseOpenBtn()
            Window:Toggle()
        end
    end)

    -- Draggable open button
    do
        local DRAG_THRESHOLD = 6
        local activeInput = nil
        local startInputPos = nil
        local startTargetPos = nil
        local moved = false

        openButton.InputBegan:Connect(function(input)
            if activeInput ~= nil then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or
               input.UserInputType == Enum.UserInputType.Touch then
                activeInput = input
                startInputPos  = input.Position
                startTargetPos = openButton.Position
                moved = false
                openButton:SetAttribute("WasDragged", false)
                local cC, cE
                local function FinishDrag()
                    if cC then cC:Disconnect() end
                    if cE then cE:Disconnect() end
                    if activeInput == input then activeInput = nil end
                end
                cC = input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then FinishDrag() end
                end)
                cE = UserInputService.InputEnded:Connect(function(ei)
                    if ei == input then FinishDrag() end
                end)
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if activeInput == nil then return end
            local isMouseMove = input.UserInputType  == Enum.UserInputType.MouseMovement
                            and activeInput.UserInputType == Enum.UserInputType.MouseButton1
            if input ~= activeInput and not isMouseMove then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
            local delta = input.Position - startInputPos
            if not moved and delta.Magnitude > DRAG_THRESHOLD then
                moved = true
                openButton:SetAttribute("WasDragged", true)
            end
            if moved then
                openButton.Position = UDim2.new(
                    startTargetPos.X.Scale, startTargetPos.X.Offset + delta.X,
                    startTargetPos.Y.Scale, startTargetPos.Y.Offset + delta.Y
                )
                local cam = workspace.CurrentCamera
                if cam then
                    local vp = cam.ViewportSize
                    local ap = openButton.AbsolutePosition
                    local as = openButton.AbsoluteSize
                    local cx = math.clamp(ap.X, 0, math.max(0, vp.X - as.X))
                    local cy = math.clamp(ap.Y, 0, math.max(0, vp.Y - as.Y))
                    if cx ~= ap.X or cy ~= ap.Y then
                        local p = openButton.Position
                        openButton.Position = UDim2.new(p.X.Scale, p.X.Offset + (cx-ap.X), p.Y.Scale, p.Y.Offset + (cy-ap.Y))
                    end
                end
            end
        end)
    end

    MakeDraggable(titleBar, mainWindow)

    -- ── Floating GUIs registry ───────────────────────────────────────────────
    local floatingGuis = {}

    local function CreateFloatingButton(cfg, forceToggle)
        cfg = cfg or {}
        local isToggle = forceToggle == true or cfg.Toggle == true
        local minSize  = cfg.MinSize or 40
        local maxSize  = cfg.MaxSize or 200
        local size     = math.clamp(cfg.Size or 80, minSize, maxSize)
        local radius   = cfg.Radius or 10
        local threshold = cfg.DragThreshold or 10
        local state    = cfg.Default == true

        -- Floating buttons live at ZO_FLOATING (lower than main window)
        local floatingGui = NewInstance("ScreenGui", {
            Name = "LurkFloating",
            ResetOnSpawn = false,
            IgnoreGuiInset = false,
            DisplayOrder = ZO_FLOATING,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        })
        ProtectGui(floatingGui)
        floatingGui.Parent = GuiParent
        table.insert(floatingGuis, floatingGui)

        local btn = NewInstance("TextButton", {
            Name = "FloatingButton",
            Size = UDim2.fromOffset(size, size),
            Position = cfg.Position or UDim2.new(0.5, -size/2, 0.6, 0),
            BackgroundColor3 = D.BG_SURFACE,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = cfg.Text or "",
            TextColor3 = D.TEXT_PRIMARY,
            TextScaled = true,
            TextWrapped = true,
            Font = D.FONT_MEDIUM,
            Active = true,
            Selectable = true,
            ZIndex = 250,
            Parent = floatingGui,
        })
        NewInstance("UICorner", { CornerRadius = UDim.new(0, radius), Parent = btn })
        NewInstance("UIPadding", { PaddingLeft=UDim.new(0,6), PaddingRight=UDim.new(0,6), PaddingTop=UDim.new(0,6), PaddingBottom=UDim.new(0,6), Parent=btn })
        NewInstance("UITextSizeConstraint", { MaxTextSize=20, MinTextSize=8, Parent=btn })
        local stroke = NewInstance("UIStroke", { Thickness=1.5, Color=Accent.Value, Transparency=0.5, ApplyStrokeMode=Enum.ApplyStrokeMode.Border, Parent=btn })

        local handle = {}
        handle.Gui    = floatingGui
        handle.Button = btn
        handle.Stroke = stroke

        local function ClampButton()
            local cam = workspace.CurrentCamera
            if not cam then return end
            local vp = cam.ViewportSize
            local as = btn.AbsoluteSize
            local sX = as.X > 0 and as.X or btn.Size.X.Offset
            local sY = as.Y > 0 and as.Y or btn.Size.Y.Offset
            local p  = btn.Position
            local aX = p.X.Scale * vp.X + p.X.Offset
            local aY = p.Y.Scale * vp.Y + p.Y.Offset
            local cX = math.clamp(aX, 0, math.max(0, vp.X - sX))
            local cY = math.clamp(aY, 0, math.max(0, vp.Y - sY))
            if cX ~= aX or cY ~= aY then
                btn.Position = UDim2.new(p.X.Scale, p.X.Offset+(cX-aX), p.Y.Scale, p.Y.Offset+(cY-aY))
            end
        end
        handle.Clamp = ClampButton
        task.defer(ClampButton)
        if workspace.CurrentCamera then
            workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function() task.defer(ClampButton) end)
        end
        floatingGui:GetPropertyChangedSignal("Enabled"):Connect(function()
            if floatingGui.Enabled then task.defer(ClampButton); task.delay(0.05, ClampButton) end
        end)
        btn:GetPropertyChangedSignal("AbsolutePosition"):Connect(ClampButton)
        btn:GetPropertyChangedSignal("AbsoluteSize"):Connect(ClampButton)

        local baseText = cfg.Text or ""
        local function ApplyVisual()
            if isToggle and state then
                TweenService:Create(btn,    D.TWEEN_FAST, { BackgroundColor3 = Accent.Value }):Play()
                TweenService:Create(btn,    D.TWEEN_FAST, { TextColor3 = Color3.fromRGB(255,255,255) }):Play()
                TweenService:Create(stroke, D.TWEEN_FAST, { Transparency = 0, Color = Accent.Value }):Play()
                if isToggle then btn.Text = cfg.OnText or baseText end
            else
                TweenService:Create(btn,    D.TWEEN_FAST, { BackgroundColor3 = D.BG_SURFACE }):Play()
                TweenService:Create(btn,    D.TWEEN_FAST, { TextColor3 = D.TEXT_PRIMARY }):Play()
                TweenService:Create(stroke, D.TWEEN_FAST, { Transparency = 0.5, Color = Accent.Value }):Play()
                if isToggle then btn.Text = cfg.OffText or baseText end
            end
        end
        ApplyVisual()
        Accent.Changed:Connect(function(c) stroke.Color = c; if state then btn.BackgroundColor3 = c end end)

        local activeInput = nil; local moved = false; local finished = false
        local startInputPos, startBtnPos

        local function DoActivate()
            if isToggle then
                state = not state
                ApplyVisual()
                if cfg.Callback then local s=state; task.spawn(function() cfg.Callback(s) end) end
            else
                if cfg.Callback then task.spawn(cfg.Callback) end
            end
        end

        local function UpdateDrag(pos)
            if activeInput == nil then return end
            local delta = pos - startInputPos
            if not moved and delta.Magnitude > threshold then moved = true end
            if moved then
                btn.Position = UDim2.new(startBtnPos.X.Scale, startBtnPos.X.Offset+delta.X, startBtnPos.Y.Scale, startBtnPos.Y.Offset+delta.Y)
                ClampButton()
            end
        end

        local function EndGesture()
            if activeInput == nil or finished then return end
            finished = true
            local didMove = moved
            activeInput = nil
            if not didMove then DoActivate() end
        end

        local function IsSameInput(input)
            if input == activeInput then return true end
            if activeInput ~= nil and activeInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement then return true end
            return false
        end

        btn.InputBegan:Connect(function(input)
            if activeInput ~= nil then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                activeInput = input; moved = false; finished = false
                startInputPos = input.Position; startBtnPos = btn.Position
                if input.UserInputType == Enum.UserInputType.Touch then
                    local conn
                    conn = input.Changed:Connect(function(prop)
                        if input.UserInputType == Enum.UserInputType.Touch and prop == "Position" then
                            if input == activeInput then UpdateDrag(input.Position) end
                        end
                        if input.UserInputState == Enum.UserInputState.End then
                            if conn then conn:Disconnect() end
                            if input == activeInput then EndGesture() end
                        end
                    end)
                end
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if activeInput == nil then return end
            if IsSameInput(input) then UpdateDrag(input.Position) end
        end)
        btn.InputEnded:Connect(function(input)
            if activeInput == nil then return end
            if input == activeInput or (activeInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1) then
                EndGesture()
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if activeInput == nil then return end
            if input == activeInput
            or (activeInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1)
            or (activeInput.UserInputType == Enum.UserInputType.Touch and input.UserInputType == Enum.UserInputType.Touch and input == activeInput) then
                EndGesture()
            end
        end)

        function handle:SetSize(px)
            size = math.clamp(px, minSize, maxSize)
            btn.Size = UDim2.fromOffset(size, size)
            task.defer(ClampButton)
            return size
        end
        function handle:GetSize()    return size end
        function handle:SetText(t)   btn.Text = t or "" end
        function handle:SetActive(value, silent)
            if not isToggle then return end
            local newState = value == true
            local changed = newState ~= state
            state = newState; ApplyVisual()
            if changed and not silent and cfg.Callback then
                local s=state; task.spawn(function() cfg.Callback(s) end)
            end
        end
        function handle:Toggle()        if isToggle then self:SetActive(not state) end end
        function handle:GetState()      return state end
        function handle:SetVisible(v)   floatingGui.Enabled = v ~= false end
        function handle:SetPosition(u)  btn.Position = u end
        function handle:Destroy()       floatingGui:Destroy() end
        function handle:AddSizeSlider(tab, sc)
            sc = sc or {}
            return tab:AddSlider({
                Name = sc.Name or "Button Size",
                Min = sc.Min or minSize, Max = sc.Max or maxSize,
                Default = sc.Default or size, Step = sc.Step or 5,
                Callback = function(v) handle:SetSize(v); if sc.Callback then sc.Callback(v) end end,
            })
        end
        return handle
    end

    function Window:AddFloatingButton(cfg)  return CreateFloatingButton(cfg, false) end
    function Window:AddFloatingToggle(cfg)  return CreateFloatingButton(cfg, true)  end

    -- ── Notify ─────────────────────────────────────────────────────────────────
    function Window:Notify(cfg)
        cfg = cfg or {}
        local title    = cfg.Title    or "Notification"
        local content  = cfg.Content  or ""
        local duration = cfg.Duration or 4

        local card = NewInstance("Frame", {
            BackgroundColor3 = D.BG_SURFACE,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            ZIndex = notifyHolder.ZIndex + 1,
            Parent = notifyHolder,
        })
        NewInstance("UICorner", { CornerRadius = D.CORNER_MD, Parent = card })
        local cardStroke = NewInstance("UIStroke", { Color=Accent.Value, Thickness=1, Transparency=1, Parent=card })

        -- left accent bar
        local accentBar = NewInstance("Frame", {
            Size = UDim2.new(0, 3, 1, 0),
            BackgroundColor3 = Accent.Value,
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            ZIndex = card.ZIndex + 1,
            Parent = card,
        })
        NewInstance("UICorner", { CornerRadius = D.CORNER_ROUND, Parent = accentBar })

        NewInstance("UIPadding", { PaddingTop=UDim.new(0,8), PaddingBottom=UDim.new(0,8), PaddingLeft=UDim.new(0,14), PaddingRight=UDim.new(0,10), Parent=card })
        NewInstance("UIListLayout", { Padding=UDim.new(0,2), SortOrder=Enum.SortOrder.LayoutOrder, Parent=card })

        local titleLbl = NewInstance("TextLabel", {
            BackgroundTransparency=1, AutomaticSize=Enum.AutomaticSize.Y,
            Size=UDim2.new(1,0,0,0), Font=D.FONT_TITLE, TextSize=13,
            TextColor3=Accent.Value, TextXAlignment=Enum.TextXAlignment.Left,
            TextWrapped=true, Text=title, TextTransparency=1,
            ZIndex=card.ZIndex+1, Parent=card,
        })
        local bodyLbl = NewInstance("TextLabel", {
            BackgroundTransparency=1, AutomaticSize=Enum.AutomaticSize.Y,
            Size=UDim2.new(1,0,0,0), Font=D.FONT_BODY, TextSize=12,
            TextColor3=D.TEXT_SECOND, TextXAlignment=Enum.TextXAlignment.Left,
            TextWrapped=true, Text=content, TextTransparency=1,
            ZIndex=card.ZIndex+1, Parent=card,
        })

        TweenService:Create(card,       D.TWEEN_MED, { BackgroundTransparency=0 }):Play()
        TweenService:Create(cardStroke, D.TWEEN_MED, { Transparency=0.3 }):Play()
        TweenService:Create(accentBar,  D.TWEEN_MED, { BackgroundTransparency=0 }):Play()
        TweenService:Create(titleLbl,   D.TWEEN_MED, { TextTransparency=0 }):Play()
        TweenService:Create(bodyLbl,    D.TWEEN_MED, { TextTransparency=0 }):Play()

        task.delay(duration, function()
            TweenService:Create(card,       D.TWEEN_MED, { BackgroundTransparency=1 }):Play()
            TweenService:Create(cardStroke, D.TWEEN_MED, { Transparency=1 }):Play()
            TweenService:Create(accentBar,  D.TWEEN_MED, { BackgroundTransparency=1 }):Play()
            TweenService:Create(titleLbl,   D.TWEEN_MED, { TextTransparency=1 }):Play()
            local fade = TweenService:Create(bodyLbl, D.TWEEN_MED, { TextTransparency=1 })
            fade:Play()
            fade.Completed:Connect(function() card:Destroy() end)
        end)
        return card
    end

    -- ── Destroy ────────────────────────────────────────────────────────────────
    function Window:Destroy()
        for _, gui in ipairs(floatingGuis) do pcall(function() gui:Destroy() end) end
        table.clear(floatingGuis)
        pcall(function() Accent._bindable:Destroy() end)
        pcall(function() OpenBtnGui:Destroy() end)
        ScreenGui:Destroy()
    end

    return Window
end
-- ──────────────────────────────────────────────────────────────────────────────

local Lurk = {}
function Lurk:CreateWindow(config)
    return CreateWindow(config)
end
return Lurk
