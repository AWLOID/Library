local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local GuiParent = PlayerGui
do
    local ok, hui = pcall(function()
        if typeof(gethui) == "function" then return gethui() end
        return nil
    end)
    if ok and hui then
        GuiParent = hui
    else
        local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
        if ok2 and cg then GuiParent = cg end
    end
end

local function ProtectGui(gui)
    pcall(function()
        if typeof(syn) == "table" and syn.protect_gui then
            syn.protect_gui(gui)
        elseif typeof(protectgui) == "function" then
            protectgui(gui)
        end
    end)
end

local function NewInstance(className, properties, children)
    local inst = Instance.new(className)
    for key, value in pairs(properties or {}) do
        inst[key] = value
    end
    for _, child in ipairs(children or {}) do
        child.Parent = inst
    end
    return inst
end

local function Clamp01(n)
    return math.clamp(n, 0, 1)
end

local function RoundTo(value, step)
    if step <= 0 then
        return value
    end
    local v = math.floor(value / step + 0.5) * step
    return math.floor(v * 1e6 + 0.5) / 1e6
end

local function FormatKeycodeName(keycode)
    if not keycode then
        return "None"
    end
    return keycode.Name
end

local function PointInsideGui(guiObject, x, y)
    local pos = guiObject.AbsolutePosition
    local size = guiObject.AbsoluteSize
    return x >= pos.X and x <= pos.X + size.X and y >= pos.Y and y <= pos.Y + size.Y
end

local function ClampOpenPosition(x, y, width, height)
    local viewport = workspace.CurrentCamera.ViewportSize
    local maxX = math.max(4, viewport.X - width - 4)
    local maxY = math.max(4, viewport.Y - height - 4)
    return math.clamp(x, 4, maxX), math.clamp(y, 4, maxY)
end

local function MakeDraggable(handle, target, onDragStart)
    local activeInput = nil
    local startInputPos = nil
    local startTargetPos = nil

    local function BeginDrag(input)
        if activeInput ~= nil then
            return
        end
        activeInput = input
        startInputPos = input.Position
        startTargetPos = target.Position
        if onDragStart then
            onDragStart()
        end

        local connChanged
        local connEnded

        connChanged = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                if connChanged then connChanged:Disconnect() end
                if connEnded then connEnded:Disconnect() end
                if activeInput == input then
                    activeInput = nil
                end
            end
        end)

        connEnded = UserInputService.InputEnded:Connect(function(endedInput)
            if endedInput == input then
                if connChanged then connChanged:Disconnect() end
                if connEnded then connEnded:Disconnect() end
                if activeInput == input then
                    activeInput = nil
                end
            end
        end)
    end

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            BeginDrag(input)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if activeInput == nil then
            return
        end
        local isMouseMove = input.UserInputType == Enum.UserInputType.MouseMovement
            and activeInput.UserInputType == Enum.UserInputType.MouseButton1
        if input ~= activeInput and not isMouseMove then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local delta = input.Position - startInputPos
        target.Position = UDim2.new(
            startTargetPos.X.Scale,
            startTargetPos.X.Offset + delta.X,
            startTargetPos.Y.Scale,
            startTargetPos.Y.Offset + delta.Y
        )
    end)
end

local function MakeValueDragger(hitTargets, onInputDown, onInputMove)
    local activeInput = nil

    local function Bind(obj)
        obj.InputBegan:Connect(function(input)
            if activeInput ~= nil then
                return
            end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                activeInput = input
                onInputDown(input)

                local connChanged
                local connEnded
                local function FinishDrag()
                    if connChanged then connChanged:Disconnect() end
                    if connEnded then connEnded:Disconnect() end
                    if activeInput == input then
                        activeInput = nil
                    end
                end
                connChanged = input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        FinishDrag()
                    end
                end)
                connEnded = UserInputService.InputEnded:Connect(function(endedInput)
                    if endedInput == input then
                        FinishDrag()
                    end
                end)
            end
        end)
    end

    for _, obj in ipairs(hitTargets) do
        Bind(obj)
    end

    UserInputService.InputChanged:Connect(function(input)
        if activeInput == nil then
            return
        end
        local isMatch = (input == activeInput)
            or (input.UserInputType == Enum.UserInputType.MouseMovement and activeInput.UserInputType == Enum.UserInputType.MouseButton1)
        if not isMatch then
            return
        end
        onInputMove(input)
    end)
end

local ActiveKeybindCancel = nil

local OverlayRegistry = {}

local function RegisterOverlay(holder, trigger, isOpenGetter, closeFn)
    table.insert(OverlayRegistry, {
        Holder = holder,
        Trigger = trigger,
        IsOpen = isOpenGetter,
        Close = closeFn,
    })
end

local function PruneOverlays()
    for i = #OverlayRegistry, 1, -1 do
        local entry = OverlayRegistry[i]
        if not entry.Holder or not entry.Holder.Parent then
            table.remove(OverlayRegistry, i)
        end
    end
end

local function CloseAllOverlaysExcept(exceptHolder)
    PruneOverlays()
    for _, entry in ipairs(OverlayRegistry) do
        if entry.Holder ~= exceptHolder and entry.IsOpen() then
            entry.Close()
        end
    end
end

local function CloseAllOverlays()
    CloseAllOverlaysExcept(nil)
end

UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    PruneOverlays()
    local pos = input.Position
    for _, entry in ipairs(OverlayRegistry) do
        if entry.IsOpen() then
            local insideHolder = PointInsideGui(entry.Holder, pos.X, pos.Y)
            local insideTrigger = entry.Trigger and PointInsideGui(entry.Trigger, pos.X, pos.Y)
            if not insideHolder and not insideTrigger then
                entry.Close()
            end
        end
    end
end)

local function CreateElementFactory(context)
    local ScreenGui = context.ScreenGui
    local Accent = context.Accent

    local Factory = {}

    function Factory.Label(parent, text)
        return NewInstance("TextLabel", {
            Name = "Label_" .. text,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 20),
            Font = Enum.Font.GothamMedium,
            TextSize = 14,
            TextColor3 = Color3.fromRGB(165, 172, 196),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = text,
            Parent = parent,
        })
    end

    function Factory.Paragraph(parent, config)
        config = config or {}
        local title = config.Title
        local text = config.Text or ""

        local row = NewInstance("Frame", {
            Name = "Paragraph",
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(1, 0, 0, 0),
            Parent = parent,
        })

        local layout = NewInstance("UIListLayout", {
            Padding = UDim.new(0, 2),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = row,
        })

        if title then
            NewInstance("TextLabel", {
                Name = "Title",
                BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.Y,
                Size = UDim2.new(1, 0, 0, 0),
                Font = Enum.Font.GothamBold,
                TextSize = 14,
                TextColor3 = Color3.fromRGB(220, 226, 242),
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
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextColor3 = Color3.fromRGB(150, 156, 178),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            Text = text,
            Parent = row,
        })

        local api = {}
        function api.SetText(newText)
            body.Text = newText
        end
        return api
    end

    function Factory.Section(parent, text)
        local row = NewInstance("Frame", {
            Name = "Section_" .. tostring(text),
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 18),
            Parent = parent,
        })

        local titleLabel = NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = Accent.Value,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = string.upper(text or ""),
            Parent = row,
        })

        Accent.Changed:Connect(function(color)
            titleLabel.TextColor3 = color
        end)

        local line = NewInstance("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.new(1, -68, 0, 1),
            BackgroundColor3 = Color3.fromRGB(72, 78, 100),
            BorderSizePixel = 0,
            Parent = row,
        })

        return row
    end

    function Factory.Toggle(parent, config)
        config = config or {}
        local name = config.Name or "Toggle"
        local default = config.Default or false
        local callback = config.Callback

        local container = NewInstance("Frame", {
            Name = "ToggleContainer_" .. name,
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(1, 0, 0, 0),
            Parent = parent,
        })

        NewInstance("UIListLayout", {
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = container,
        })

        local row = NewInstance("Frame", {
            Name = "Toggle_" .. name,
            BackgroundTransparency = 1,
            LayoutOrder = 1,
            Size = UDim2.new(1, 0, 0, 26),
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
                NewInstance("UIListLayout", {
                    Padding = UDim.new(0, 6),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Parent = subHolder,
                })
            end
            return subHolder
        end

        NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -48, 1, 0),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Color3.fromRGB(212, 218, 235),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            Parent = row,
        })

        local box = NewInstance("TextButton", {
            Name = "Box",
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(20, 20),
            BackgroundColor3 = Color3.fromRGB(23, 25, 35),
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            Parent = row,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 4), Parent = box })

        local boxStroke = NewInstance("UIStroke", {
            Color = Accent.Value,
            Transparency = default and 0.3 or 1,
            Thickness = 1,
            Parent = box,
        })

        local fill = NewInstance("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Accent.Value,
            BorderSizePixel = 0,
            BackgroundTransparency = default and 0 or 1,
            Parent = box,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 4), Parent = fill })

        local state = default

        local function ApplyVisual(animated)
            local goal = { BackgroundTransparency = state and 0 or 1 }
            local strokeGoal = { Transparency = state and 0.3 or 1 }
            if animated then
                TweenService:Create(fill, TweenInfo.new(0.15), goal):Play()
                TweenService:Create(boxStroke, TweenInfo.new(0.15), strokeGoal):Play()
            else
                fill.BackgroundTransparency = goal.BackgroundTransparency
                boxStroke.Transparency = strokeGoal.Transparency
            end
        end

        Accent.Changed:Connect(function(color)
            fill.BackgroundColor3 = color
            boxStroke.Color = color
        end)

        box.MouseButton1Click:Connect(function()
            state = not state
            ApplyVisual(true)
            if callback then
                callback(state)
            end
        end)

        local api = {}
        function api.Set(value)
            state = value
            ApplyVisual(false)
        end
        function api.Get()
            return state
        end
        api.Row = row
        api.Container = container
        function api:GetContainer()
            return EnsureSub()
        end
        function api:AddSlider(sc)
            return Factory.Slider(EnsureSub(), sc)
        end
        function api:AddToggle(sc)
            return Factory.Toggle(EnsureSub(), sc)
        end
        function api:AddButton(sc)
            return Factory.Button(EnsureSub(), sc)
        end
        function api:AddLabel(t)
            return Factory.Label(EnsureSub(), t)
        end
        function api:ClearSub()
            if subHolder then
                subHolder:Destroy()
                subHolder = nil
            end
        end
        return api
    end

    function Factory.Slider(parent, config)
        config = config or {}
        local name = config.Name or "Slider"
        local min = config.Min or 0
        local max = config.Max or 100
        if max < min then min, max = max, min end
        local default = math.clamp(config.Default or min, min, max)
        local step = config.Step or ((max - min <= 1) and 0.01 or 1)
        local callback = config.Callback

        local row = NewInstance("Frame", {
            Name = "Slider_" .. name,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 38),
            Parent = parent,
        })

        local label = NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 18),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Color3.fromRGB(212, 218, 235),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name .. ": " .. tostring(default),
            Parent = row,
        })

        local track = NewInstance("Frame", {
            Position = UDim2.fromOffset(0, 23),
            Size = UDim2.new(1, 0, 0, 8),
            BackgroundColor3 = Color3.fromRGB(23, 25, 35),
            BorderSizePixel = 0,
            Parent = row,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })

        local fillRatio = (max > min) and Clamp01((default - min) / (max - min)) or 0

        local fill = NewInstance("Frame", {
            Size = UDim2.new(fillRatio, 0, 1, 0),
            BackgroundColor3 = Accent.Value,
            BorderSizePixel = 0,
            Parent = track,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })

        local knob = NewInstance("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(fillRatio, 0, 0.5, 0),
            Size = UDim2.fromOffset(13, 18),
            BackgroundColor3 = Color3.fromRGB(245, 247, 255),
            BorderSizePixel = 0,
            ZIndex = track.ZIndex + 1,
            Parent = track,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })

        Accent.Changed:Connect(function(color)
            fill.BackgroundColor3 = color
        end)

        local currentValue = default

        local function ApplyValue(value, fromUser)
            value = math.clamp(RoundTo(math.clamp(value, min, max), step), min, max)
            currentValue = value
            local ratio = (max > min) and Clamp01((value - min) / (max - min)) or 0
            fill.Size = UDim2.new(ratio, 0, 1, 0)
            knob.Position = UDim2.new(ratio, 0, 0.5, 0)
            label.Text = name .. ": " .. tostring(value)
            if fromUser and callback then
                callback(value)
            end
        end

        local function UpdateFromX(xPos)
            local trackPos = track.AbsolutePosition.X
            local trackSize = track.AbsoluteSize.X
            if trackSize <= 0 then
                return
            end
            local ratio = Clamp01((xPos - trackPos) / trackSize)
            ApplyValue(min + (max - min) * ratio, true)
        end

        MakeValueDragger({ knob, track }, function(input)
            UpdateFromX(input.Position.X)
        end, function(input)
            UpdateFromX(input.Position.X)
        end)

        local api = {}
        function api.Set(value)
            ApplyValue(value, false)
        end
        function api.Get()
            return currentValue
        end
        api.Instance = row
        function api.SetVisible(v)
            row.Visible = v ~= false
        end
        function api.Destroy()
            row:Destroy()
        end
        return api
    end

    function Factory.Button(parent, config)
        config = config or {}
        local name = config.Name or "Button"
        local callback = config.Callback

        local btn = NewInstance("TextButton", {
            Name = "Button_" .. name,
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundColor3 = Color3.fromRGB(23, 25, 35),
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = Enum.Font.GothamMedium,
            TextSize = 14,
            TextColor3 = Color3.fromRGB(235, 240, 252),
            Text = name,
            Parent = parent,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 4), Parent = btn })

        NewInstance("UIStroke", {
            Color = Color3.fromRGB(62, 66, 86),
            Thickness = 1,
            Parent = btn,
        })

        btn.MouseButton1Click:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.08), { BackgroundColor3 = Accent.Value }):Play()
            task.delay(0.12, function()
                TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(23, 25, 35) }):Play()
            end)
            if callback then
                callback()
            end
        end)

        local api = {}
        function api.SetText(text)
            btn.Text = text
        end
        return api
    end

    function Factory.ProgressBar(parent, config)
        config = config or {}
        local name = config.Name or "Progress"
        local min = config.Min or 0
        local max = config.Max or 100
        if max < min then min, max = max, min end
        local default = math.clamp(config.Default or min, min, max)

        local row = NewInstance("Frame", {
            Name = "ProgressBar_" .. name,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 36),
            Parent = parent,
        })

        local label = NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 16),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Color3.fromRGB(212, 218, 235),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            Parent = row,
        })

        local track = NewInstance("Frame", {
            Position = UDim2.fromOffset(0, 20),
            Size = UDim2.new(1, 0, 0, 8),
            BackgroundColor3 = Color3.fromRGB(23, 25, 35),
            BorderSizePixel = 0,
            Parent = row,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })

        local ratio = (max > min) and Clamp01((default - min) / (max - min)) or 0

        local fill = NewInstance("Frame", {
            Size = UDim2.new(ratio, 0, 1, 0),
            BackgroundColor3 = Accent.Value,
            BorderSizePixel = 0,
            Parent = track,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })

        Accent.Changed:Connect(function(color)
            fill.BackgroundColor3 = color
        end)

        local currentValue = default

        local api = {}
        function api.Set(value)
            currentValue = math.clamp(value, min, max)
            local newRatio = (max > min) and Clamp01((currentValue - min) / (max - min)) or 0
            TweenService:Create(fill, TweenInfo.new(0.2), { Size = UDim2.new(newRatio, 0, 1, 0) }):Play()
        end
        function api.Get()
            return currentValue
        end
        return api
    end

    function Factory.Image(parent, config)
        config = config or {}
        local id = config.Id or ""
        local height = config.Height or 120

        local holder = NewInstance("Frame", {
            Name = "Image",
            BackgroundColor3 = Color3.fromRGB(23, 25, 35),
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, height),
            Parent = parent,
        })

        NewInstance("UIStroke", {
            Color = Color3.fromRGB(62, 66, 86),
            Thickness = 1,
            Parent = holder,
        })

        local image = NewInstance("ImageLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Image = id,
            ScaleType = Enum.ScaleType.Crop,
            Parent = holder,
        })

        local api = {}
        function api.Set(newId)
            image.Image = newId
        end
        return api
    end

    function Factory.Dropdown(parent, config)
        config = config or {}
        local name = config.Name or "Dropdown"
        local options = config.Options or {}
        local default = config.Default or options[1]
        local callback = config.Callback
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
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Color3.fromRGB(212, 218, 235),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            Parent = row,
        })

        local box = NewInstance("TextButton", {
            Name = "Box",
            Position = UDim2.fromOffset(0, 20),
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundColor3 = Color3.fromRGB(23, 25, 35),
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextColor3 = Color3.fromRGB(235, 240, 252),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "  " .. tostring(default or ""),
            Parent = row,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 4), Parent = box })

        local boxStroke = NewInstance("UIStroke", {
            Color = Color3.fromRGB(62, 66, 86),
            Thickness = 1,
            Parent = box,
        })

        local arrow = NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -10, 0.5, 0),
            Size = UDim2.fromOffset(16, 16),
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = Accent.Value,
            Text = "\u{25BC}",
            Parent = box,
        })

        local isOpen = false

        Accent.Changed:Connect(function(color)
            arrow.TextColor3 = color
            if isOpen then
                boxStroke.Color = color
            end
        end)

        local optionsHolder = NewInstance("Frame", {
            Name = "DropdownOptionsHolder_" .. name,
            BackgroundColor3 = Color3.fromRGB(18, 20, 28),
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(0, 28),
            Visible = false,
            ClipsDescendants = true,
            ZIndex = 200,
            Parent = ScreenGui,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 6), Parent = optionsHolder })

        NewInstance("UIStroke", {
            Color = Color3.fromRGB(62, 66, 86),
            Thickness = 1,
            Parent = optionsHolder,
        })

        local scroll = NewInstance("ScrollingFrame", {
            Name = "Scroll",
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Color3.fromRGB(152, 160, 196),
            ScrollBarImageTransparency = 0.4,
            ZIndex = optionsHolder.ZIndex + 1,
            Parent = optionsHolder,
        })

        NewInstance("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = scroll,
        })

        local currentValue = default
        local optionButtons = {}

        local function HighlightSelected()
            for opt, btn in pairs(optionButtons) do
                if opt == currentValue then
                    btn.BackgroundColor3 = Color3.fromRGB(34, 36, 48)
                    btn.TextColor3 = Accent.Value
                else
                    btn.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
                    btn.TextColor3 = Color3.fromRGB(212, 218, 235)
                end
            end
        end

        local function Close()
            isOpen = false
            optionsHolder.Visible = false
            boxStroke.Color = Color3.fromRGB(62, 66, 86)
            arrow.Text = "\u{25BC}"
        end

        local function RebuildOptions()
            for _, child in ipairs(scroll:GetChildren()) do
                if child:IsA("TextButton") then
                    child:Destroy()
                end
            end
            optionButtons = {}
            for index, opt in ipairs(options) do
                local optBtn = NewInstance("TextButton", {
                    Name = "Option_" .. tostring(opt),
                    BackgroundColor3 = Color3.fromRGB(18, 20, 28),
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                    Size = UDim2.new(1, 0, 0, 28),
                    Font = Enum.Font.Gotham,
                    TextSize = 13,
                    TextColor3 = Color3.fromRGB(212, 218, 235),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Text = "   " .. tostring(opt),
                    LayoutOrder = index,
                    ZIndex = scroll.ZIndex + 1,
                    Parent = scroll,
                })

                optionButtons[opt] = optBtn

                optBtn.MouseEnter:Connect(function()
                    if opt ~= currentValue then
                        optBtn.BackgroundColor3 = Color3.fromRGB(28, 30, 42)
                    end
                end)
                optBtn.MouseLeave:Connect(function()
                    if opt ~= currentValue then
                        optBtn.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
                    end
                end)
                optBtn.MouseButton1Click:Connect(function()
                    currentValue = opt
                    box.Text = "  " .. tostring(opt)
                    HighlightSelected()
                    Close()
                    if callback then
                        callback(opt)
                    end
                end)
            end
            HighlightSelected()
        end

        RebuildOptions()

        local function Open()
            CloseAllOverlaysExcept(optionsHolder)
            local boxPos = box.AbsolutePosition
            local boxSize = box.AbsoluteSize
            local visible = math.min(#options, maxVisible)
            local panelHeight = math.max(visible, 1) * 28
            optionsHolder.Size = UDim2.fromOffset(boxSize.X, panelHeight)
            local x, y = ClampOpenPosition(boxPos.X, boxPos.Y + boxSize.Y + 2, boxSize.X, panelHeight)
            optionsHolder.Position = UDim2.fromOffset(x, y)
            optionsHolder.Visible = true
            isOpen = true
            boxStroke.Color = Accent.Value
            arrow.Text = "\u{25B2}"
            HighlightSelected()
        end

        box.MouseButton1Click:Connect(function()
            if isOpen then
                Close()
            else
                Open()
            end
        end)

        RegisterOverlay(optionsHolder, box, function() return isOpen end, Close)

        row.Destroying:Connect(function()
            optionsHolder:Destroy()
        end)

        local api = {}
        function api.Set(value)
            currentValue = value
            box.Text = "  " .. tostring(value)
            HighlightSelected()
        end
        function api.Get()
            return currentValue
        end
        function api.SetOptions(newOptions)
            options = newOptions
            RebuildOptions()
        end
        return api
    end

    function Factory.MultiDropdown(parent, config)
        config = config or {}
        local name = config.Name or "Dropdown"
        local options = config.Options or {}
        local default = config.Default or {}
        local callback = config.Callback

        local selected = {}
        for _, opt in ipairs(default) do
            selected[opt] = true
        end

        local row = NewInstance("Frame", {
            Name = "MultiDropdown_" .. name,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 46),
            Parent = parent,
        })

        NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 16),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Color3.fromRGB(212, 218, 235),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            Parent = row,
        })

        local box = NewInstance("TextButton", {
            Name = "Box",
            Position = UDim2.fromOffset(0, 20),
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundColor3 = Color3.fromRGB(23, 25, 35),
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextColor3 = Color3.fromRGB(235, 240, 252),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "",
            Parent = row,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 4), Parent = box })

        NewInstance("UIStroke", {
            Color = Color3.fromRGB(62, 66, 86),
            Thickness = 1,
            Parent = box,
        })

        NewInstance("UIPadding", {
            PaddingLeft = UDim.new(0, 6),
            Parent = box,
        })

        local arrow = NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -8, 0.5, 0),
            Size = UDim2.fromOffset(16, 16),
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = Accent.Value,
            Text = "v",
            Parent = box,
        })

        Accent.Changed:Connect(function(color)
            arrow.TextColor3 = color
        end)

        local optionsHolder = NewInstance("Frame", {
            Name = "MultiDropdownOptionsHolder_" .. name,
            BackgroundColor3 = Color3.fromRGB(18, 20, 28),
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(0, math.min(#options, 8) * 24),
            Visible = false,
            ClipsDescendants = true,
            ZIndex = 200,
            Parent = ScreenGui,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 6), Parent = optionsHolder })

        NewInstance("UIStroke", {
            Color = Color3.fromRGB(62, 66, 86),
            Thickness = 1,
            Parent = optionsHolder,
        })

        local optionsScroll = NewInstance("ScrollingFrame", {
            Name = "Scroll",
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Color3.fromRGB(152, 160, 196),
            ScrollBarImageTransparency = 0.4,
            ZIndex = optionsHolder.ZIndex + 1,
            Parent = optionsHolder,
        })

        NewInstance("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = optionsScroll,
        })

        local isOpen = false

        local function RefreshBoxText()
            local count = 0
            local first = nil
            for opt, isSelected in pairs(selected) do
                if isSelected then
                    count = count + 1
                    first = first or opt
                end
            end
            if count == 0 then
                box.Text = "None"
            elseif count == 1 then
                box.Text = tostring(first)
            else
                box.Text = tostring(first) .. " +" .. tostring(count - 1)
            end
        end

        local checkMarks = {}

        local function Close()
            isOpen = false
            optionsHolder.Visible = false
        end

        local function RebuildOptions()
            for _, child in ipairs(optionsScroll:GetChildren()) do
                if child:IsA("Frame") then
                    child:Destroy()
                end
            end
            checkMarks = {}
            for _, opt in ipairs(options) do
                local optRow = NewInstance("Frame", {
                    Name = "Option_" .. tostring(opt),
                    BackgroundColor3 = Color3.fromRGB(18, 20, 28),
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, 0, 0, 24),
                    ZIndex = optionsScroll.ZIndex + 1,
                    Parent = optionsScroll,
                })

                local optBtn = NewInstance("TextButton", {
                    BackgroundTransparency = 1,
                    Size = UDim2.fromScale(1, 1),
                    Font = Enum.Font.Gotham,
                    TextSize = 13,
                    TextColor3 = Color3.fromRGB(212, 218, 235),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Text = "  " .. tostring(opt),
                    ZIndex = optRow.ZIndex + 1,
                    Parent = optRow,
                })

                local check = NewInstance("Frame", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -6, 0.5, 0),
                    Size = UDim2.fromOffset(12, 12),
                    BackgroundColor3 = Accent.Value,
                    BorderSizePixel = 0,
                    Visible = selected[opt] == true,
                    ZIndex = optRow.ZIndex + 1,
                    Parent = optRow,
                })

                checkMarks[opt] = check

                optBtn.MouseButton1Click:Connect(function()
                    selected[opt] = not selected[opt]
                    check.Visible = selected[opt] == true
                    RefreshBoxText()
                    if callback then
                        callback(selected)
                    end
                end)
            end
        end

        RebuildOptions()
        RefreshBoxText()

        Accent.Changed:Connect(function(color)
            for _, check in pairs(checkMarks) do
                check.BackgroundColor3 = color
            end
        end)

        local function Open()
            CloseAllOverlaysExcept(optionsHolder)
            local boxPos = box.AbsolutePosition
            local boxSize = box.AbsoluteSize
            local panelHeight = math.max(math.min(#options, 8), 1) * 24
            optionsHolder.Size = UDim2.fromOffset(boxSize.X, panelHeight)
            local x, y = ClampOpenPosition(boxPos.X, boxPos.Y + boxSize.Y + 2, boxSize.X, panelHeight)
            optionsHolder.Position = UDim2.fromOffset(x, y)
            optionsHolder.Visible = true
            isOpen = true
        end

        box.MouseButton1Click:Connect(function()
            if isOpen then
                Close()
            else
                Open()
            end
        end)

        RegisterOverlay(optionsHolder, box, function() return isOpen end, Close)

        row.Destroying:Connect(function()
            optionsHolder:Destroy()
        end)

        local api = {}
        function api.Get()
            local result = {}
            for opt, isSelected in pairs(selected) do
                if isSelected then
                    table.insert(result, opt)
                end
            end
            return result
        end
        function api.Set(newSelected)
            selected = {}
            for _, opt in ipairs(newSelected) do
                selected[opt] = true
            end
            for opt, check in pairs(checkMarks) do
                check.Visible = selected[opt] == true
            end
            RefreshBoxText()
        end
        return api
    end

    function Factory.ColorPicker(parent, config)
        config = config or {}
        local name = config.Name or "Color"
        local default = config.Default or Color3.fromRGB(255, 255, 255)
        local callback = config.Callback

        local row = NewInstance("Frame", {
            Name = "ColorPicker_" .. name,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 26),
            Parent = parent,
        })

        NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -48, 1, 0),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Color3.fromRGB(212, 218, 235),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            Parent = row,
        })

        local swatch = NewInstance("TextButton", {
            Name = "Swatch",
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(26, 20),
            BackgroundColor3 = default,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            Parent = row,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 4), Parent = swatch })

        NewInstance("UIStroke", {
            Color = Color3.fromRGB(120, 128, 160),
            Thickness = 1,
            Parent = swatch,
        })

        local h, s, v = Color3.toHSV(default)
        local currentColor = default

        local panel = NewInstance("Frame", {
            Name = "ColorPickerPanel_" .. name,
            BackgroundColor3 = Color3.fromRGB(18, 20, 28),
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(180, 204),
            Visible = false,
            ZIndex = 200,
            Parent = ScreenGui,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 6), Parent = panel })

        NewInstance("UIStroke", {
            Color = Color3.fromRGB(62, 66, 86),
            Thickness = 1,
            Parent = panel,
        })

        local panelHandle = NewInstance("Frame", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 22),
            ZIndex = panel.ZIndex + 1,
            Parent = panel,
        })

        NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(8, 0),
            Size = UDim2.new(1, -32, 1, 0),
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            TextColor3 = Color3.fromRGB(188, 194, 216),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            ZIndex = panelHandle.ZIndex + 1,
            Parent = panelHandle,
        })

        local closeBtn = NewInstance("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -4, 0.5, 0),
            Size = UDim2.fromOffset(18, 18),
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            TextColor3 = Color3.fromRGB(188, 194, 216),
            Text = "x",
            ZIndex = panelHandle.ZIndex + 1,
            Parent = panelHandle,
        })

        local svMap = NewInstance("ImageButton", {
            Name = "SVMap",
            Position = UDim2.fromOffset(10, 32),
            Size = UDim2.fromOffset(160, 110),
            BackgroundColor3 = Color3.fromHSV(h, 1, 1),
            BorderSizePixel = 0,
            AutoButtonColor = false,
            ZIndex = panel.ZIndex + 1,
            Parent = panel,
        })

        local svWhiteOverlay = NewInstance("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            ZIndex = svMap.ZIndex + 1,
            Parent = svMap,
        })

        NewInstance("UIGradient", {
            Transparency = NumberSequence.new(0, 1),
            Parent = svWhiteOverlay,
        })

        local svBlackOverlay = NewInstance("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.new(0, 0, 0),
            BorderSizePixel = 0,
            ZIndex = svWhiteOverlay.ZIndex + 1,
            Parent = svMap,
        })

        NewInstance("UIGradient", {
            Rotation = 90,
            Transparency = NumberSequence.new(1, 0),
            Parent = svBlackOverlay,
        })

        local svCursor = NewInstance("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(8, 8),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            ZIndex = svBlackOverlay.ZIndex + 1,
            Position = UDim2.new(s, 0, 1 - v, 0),
            Parent = svMap,
        })

        NewInstance("UIStroke", {
            Color = Color3.new(0, 0, 0),
            Thickness = 1.5,
            Parent = svCursor,
        })

        local hueTrack = NewInstance("Frame", {
            Position = UDim2.fromOffset(10, 154),
            Size = UDim2.fromOffset(160, 14),
            BorderSizePixel = 0,
            ZIndex = panel.ZIndex + 1,
            Parent = panel,
        })

        local hueSequence = {}
        for i = 0, 10 do
            table.insert(hueSequence, ColorSequenceKeypoint.new(i / 10, Color3.fromHSV(i / 10, 1, 1)))
        end

        NewInstance("UIGradient", {
            Color = ColorSequence.new(hueSequence),
            Parent = hueTrack,
        })

        local hueCursor = NewInstance("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(h, 0, 0.5, 0),
            Size = UDim2.fromOffset(4, 18),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            ZIndex = hueTrack.ZIndex + 1,
            Parent = hueTrack,
        })

        NewInstance("UIStroke", {
            Color = Color3.new(0, 0, 0),
            Thickness = 1,
            Parent = hueCursor,
        })

        local hexBox = NewInstance("TextBox", {
            Position = UDim2.fromOffset(10, 178),
            Size = UDim2.fromOffset(160, 16),
            BackgroundColor3 = Color3.fromRGB(28, 30, 42),
            BorderSizePixel = 0,
            Font = Enum.Font.Code,
            TextSize = 12,
            TextColor3 = Color3.fromRGB(235, 240, 252),
            ClearTextOnFocus = false,
            Text = "#" .. default:ToHex(),
            ZIndex = panel.ZIndex + 1,
            Parent = panel,
        })

        local isOpen = false

        local function ApplyColor(fromUser)
            currentColor = Color3.fromHSV(h, s, v)
            swatch.BackgroundColor3 = currentColor
            svMap.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
            hexBox.Text = "#" .. currentColor:ToHex()
            if fromUser and callback then
                callback(currentColor)
            end
        end

        local function SetSV(x, y)
            local pos = svMap.AbsolutePosition
            local size = svMap.AbsoluteSize
            s = Clamp01((x - pos.X) / size.X)
            v = 1 - Clamp01((y - pos.Y) / size.Y)
            svCursor.Position = UDim2.new(s, 0, 1 - v, 0)
            ApplyColor(true)
        end

        local function SetHue(x)
            local pos = hueTrack.AbsolutePosition
            local size = hueTrack.AbsoluteSize
            h = Clamp01((x - pos.X) / size.X)
            hueCursor.Position = UDim2.new(h, 0, 0.5, 0)
            ApplyColor(true)
        end

        MakeValueDragger({ svMap }, function(input)
            SetSV(input.Position.X, input.Position.Y)
        end, function(input)
            SetSV(input.Position.X, input.Position.Y)
        end)

        MakeValueDragger({ hueTrack }, function(input)
            SetHue(input.Position.X)
        end, function(input)
            SetHue(input.Position.X)
        end)

        hexBox.FocusLost:Connect(function()
            local hex = hexBox.Text:gsub("#", "")
            local ok, color = pcall(Color3.fromHex, hex)
            if ok then
                h, s, v = Color3.toHSV(color)
                svCursor.Position = UDim2.new(s, 0, 1 - v, 0)
                hueCursor.Position = UDim2.new(h, 0, 0.5, 0)
                ApplyColor(true)
            else
                hexBox.Text = "#" .. currentColor:ToHex()
            end
        end)

        local function Close()
            isOpen = false
            panel.Visible = false
        end

        local function Open()
            CloseAllOverlaysExcept(panel)
            local swatchPos = swatch.AbsolutePosition
            local swatchSize = swatch.AbsoluteSize
            local panelSize = panel.AbsoluteSize
            local x = swatchPos.X - panelSize.X + swatchSize.X
            local y = swatchPos.Y + swatchSize.Y + 4
            x, y = ClampOpenPosition(x, y, panelSize.X, panelSize.Y)
            panel.Position = UDim2.fromOffset(x, y)
            panel.Visible = true
            isOpen = true
        end

        swatch.MouseButton1Click:Connect(function()
            if isOpen then
                Close()
            else
                Open()
            end
        end)

        closeBtn.MouseButton1Click:Connect(Close)

        MakeDraggable(panelHandle, panel)

        RegisterOverlay(panel, swatch, function() return isOpen end, Close)

        row.Destroying:Connect(function()
            panel:Destroy()
        end)

        local api = {}
        function api.Set(color3)
            h, s, v = Color3.toHSV(color3)
            svCursor.Position = UDim2.new(s, 0, 1 - v, 0)
            hueCursor.Position = UDim2.new(h, 0, 0.5, 0)
            ApplyColor(false)
        end
        function api.Get()
            return currentColor
        end
        return api
    end

    function Factory.Textbox(parent, config)
        config = config or {}
        local name = config.Name or "Textbox"
        local default = config.Default or ""
        local placeholder = config.Placeholder or ""
        local callback = config.Callback

        local row = NewInstance("Frame", {
            Name = "Textbox_" .. name,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 40),
            Parent = parent,
        })

        NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 16),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Color3.fromRGB(212, 218, 235),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            Parent = row,
        })

        local box = NewInstance("TextBox", {
            Position = UDim2.fromOffset(0, 20),
            Size = UDim2.new(1, 0, 0, 20),
            BackgroundColor3 = Color3.fromRGB(23, 25, 35),
            BorderSizePixel = 0,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextColor3 = Color3.fromRGB(235, 240, 252),
            PlaceholderText = placeholder,
            PlaceholderColor3 = Color3.fromRGB(134, 142, 176),
            ClearTextOnFocus = false,
            Text = default,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 4), Parent = box })

        NewInstance("UIStroke", {
            Color = Color3.fromRGB(62, 66, 86),
            Thickness = 1,
            Parent = box,
        })

        NewInstance("UIPadding", {
            PaddingLeft = UDim.new(0, 6),
            PaddingRight = UDim.new(0, 6),
            Parent = box,
        })

        box.FocusLost:Connect(function(enterPressed)
            if callback then
                callback(box.Text, enterPressed)
            end
        end)

        local api = {}
        function api.Set(text)
            box.Text = text
        end
        function api.Get()
            return box.Text
        end
        return api
    end

    function Factory.Keybind(parent, config)
        config = config or {}
        local name = config.Name or "Keybind"
        local default = config.Default
        local callback = config.Callback

        local row = NewInstance("Frame", {
            Name = "Keybind_" .. name,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 26),
            Parent = parent,
        })

        NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -90, 1, 0),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Color3.fromRGB(212, 218, 235),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            Parent = row,
        })

        local box = NewInstance("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(84, 20),
            BackgroundColor3 = Color3.fromRGB(23, 25, 35),
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextColor3 = Color3.fromRGB(235, 240, 252),
            Text = FormatKeycodeName(default),
            Parent = row,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 4), Parent = box })

        NewInstance("UIStroke", {
            Color = Color3.fromRGB(62, 66, 86),
            Thickness = 1,
            Parent = box,
        })

        local currentKey = default
        local listening = false

        box.MouseButton1Click:Connect(function()
            if listening then
                listening = false
                ActiveKeybindCancel = nil
                box.Text = FormatKeycodeName(currentKey)
                return
            end
            if ActiveKeybindCancel then
                ActiveKeybindCancel()
            end
            listening = true
            ActiveKeybindCancel = function()
                listening = false
                box.Text = FormatKeycodeName(currentKey)
            end
            box.Text = "..."
        end)

        UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if not listening then
                return
            end
            if gameProcessed then
                return
            end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode == Enum.KeyCode.Escape then
                    listening = false
                    ActiveKeybindCancel = nil
                    box.Text = FormatKeycodeName(currentKey)
                    return
                end
                currentKey = input.KeyCode
                box.Text = FormatKeycodeName(currentKey)
                listening = false
                ActiveKeybindCancel = nil
                if callback then
                    callback(currentKey)
                end
            end
        end)

        local api = {}
        function api.Set(keycode)
            currentKey = keycode
            box.Text = FormatKeycodeName(keycode)
        end
        function api.Get()
            return currentKey
        end
        return api
    end

    function Factory.Divider(parent)
        local row = NewInstance("Frame", {
            Name = "Divider",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 9),
            Parent = parent,
        })
        NewInstance("Frame", {
            Name = "Line",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = Color3.fromRGB(82, 88, 112),
            BorderSizePixel = 0,
            Parent = row,
        })
        return row
    end

    function Factory.Spacer(parent, height)
        return NewInstance("Frame", {
            Name = "Spacer",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, height or 8),
            Parent = parent,
        })
    end

    function Factory.Checkbox(parent, config)
        config = config or {}
        local name = config.Name or "Checkbox"
        local default = config.Default or false
        local callback = config.Callback

        local row = NewInstance("Frame", {
            Name = "Checkbox_" .. name,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 26),
            Parent = parent,
        })

        NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -32, 1, 0),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Color3.fromRGB(212, 218, 235),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            Parent = row,
        })

        local box = NewInstance("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(18, 18),
            BackgroundColor3 = default and Accent.Value or Color3.fromRGB(18, 20, 28),
            BackgroundTransparency = default and 0 or 1,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            Parent = row,
        })

        NewInstance("UICorner", {
            CornerRadius = UDim.new(0, 4),
            Parent = box,
        })

        local boxStroke = NewInstance("UIStroke", {
            Color = default and Accent.Value or Color3.fromRGB(104, 111, 140),
            Thickness = 1,
            Parent = box,
        })

        local check = NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextColor3 = Color3.fromRGB(18, 20, 28),
            Text = "\u{2713}",
            Visible = default,
            Parent = box,
        })

        local state = default

        local function ApplyVisual(animated)
            check.Visible = state
            local bgGoal = { BackgroundTransparency = state and 0 or 1 }
            boxStroke.Color = state and Accent.Value or Color3.fromRGB(104, 111, 140)
            box.BackgroundColor3 = Accent.Value
            if animated then
                TweenService:Create(box, TweenInfo.new(0.12), bgGoal):Play()
            else
                box.BackgroundTransparency = bgGoal.BackgroundTransparency
            end
        end

        Accent.Changed:Connect(function(color)
            box.BackgroundColor3 = color
            boxStroke.Color = state and color or Color3.fromRGB(104, 111, 140)
        end)

        box.MouseButton1Click:Connect(function()
            state = not state
            ApplyVisual(true)
            if callback then
                callback(state)
            end
        end)

        local api = {}
        function api.Set(value)
            state = value
            ApplyVisual(false)
        end
        function api.Get()
            return state
        end
        return api
    end

    function Factory.Switch(parent, config)
        config = config or {}
        local name = config.Name or "Switch"
        local default = config.Default or false
        local callback = config.Callback

        local row = NewInstance("Frame", {
            Name = "Switch_" .. name,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 26),
            Parent = parent,
        })

        NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -52, 1, 0),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Color3.fromRGB(212, 218, 235),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            Parent = row,
        })

        local track = NewInstance("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(40, 20),
            BackgroundColor3 = default and Accent.Value or Color3.fromRGB(72, 78, 100),
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            Parent = row,
        })

        NewInstance("UICorner", {
            CornerRadius = UDim.new(1, 0),
            Parent = track,
        })

        local knob = NewInstance("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = default and UDim2.new(1, -11, 0.5, 0) or UDim2.new(0, 11, 0.5, 0),
            Size = UDim2.fromOffset(14, 14),
            BackgroundColor3 = Color3.fromRGB(250, 251, 255),
            BorderSizePixel = 0,
            Parent = track,
        })

        NewInstance("UICorner", {
            CornerRadius = UDim.new(1, 0),
            Parent = knob,
        })

        local state = default

        local function ApplyVisual(animated)
            local knobGoal = { Position = state and UDim2.new(1, -11, 0.5, 0) or UDim2.new(0, 11, 0.5, 0) }
            local trackGoal = { BackgroundColor3 = state and Accent.Value or Color3.fromRGB(72, 78, 100) }
            if animated then
                TweenService:Create(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad), knobGoal):Play()
                TweenService:Create(track, TweenInfo.new(0.15), trackGoal):Play()
            else
                knob.Position = knobGoal.Position
                track.BackgroundColor3 = trackGoal.BackgroundColor3
            end
        end

        Accent.Changed:Connect(function()
            if state then
                track.BackgroundColor3 = Accent.Value
            end
        end)

        track.MouseButton1Click:Connect(function()
            state = not state
            ApplyVisual(true)
            if callback then
                callback(state)
            end
        end)

        local api = {}
        function api.Set(value)
            state = value
            ApplyVisual(false)
        end
        function api.Get()
            return state
        end
        return api
    end

    function Factory.Segmented(parent, config)
        config = config or {}
        local name = config.Name
        local options = config.Options or {}
        local default = config.Default or options[1]
        local callback = config.Callback

        local hasLabel = name ~= nil
        local row = NewInstance("Frame", {
            Name = "Segmented_" .. tostring(name),
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, hasLabel and 46 or 26),
            Parent = parent,
        })

        if hasLabel then
            NewInstance("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 16),
                Font = Enum.Font.Gotham,
                TextSize = 14,
                TextColor3 = Color3.fromRGB(212, 218, 235),
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = name,
                Parent = row,
            })
        end

        local bar = NewInstance("Frame", {
            Position = UDim2.fromOffset(0, hasLabel and 20 or 0),
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundColor3 = Color3.fromRGB(23, 25, 35),
            BorderSizePixel = 0,
            Parent = row,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 4), Parent = bar })

        NewInstance("UIStroke", {
            Color = Color3.fromRGB(62, 66, 86),
            Thickness = 1,
            Parent = bar,
        })

        NewInstance("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
            Parent = bar,
        })

        local currentValue = default
        local segButtons = {}

        local function Highlight()
            for opt, btn in pairs(segButtons) do
                if opt == currentValue then
                    btn.BackgroundColor3 = Accent.Value
                    btn.BackgroundTransparency = 0.15
                    btn.TextColor3 = Color3.fromRGB(250, 251, 255)
                else
                    btn.BackgroundTransparency = 1
                    btn.TextColor3 = Color3.fromRGB(196, 202, 224)
                end
            end
        end

        local count = #options
        for index, opt in ipairs(options) do
            local segBtn = NewInstance("TextButton", {
                Name = "Seg_" .. tostring(opt),
                BackgroundColor3 = Accent.Value,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Size = UDim2.new(1 / count, 0, 1, 0),
                Font = Enum.Font.GothamMedium,
                TextSize = 12,
                TextColor3 = Color3.fromRGB(196, 202, 224),
                Text = tostring(opt),
                LayoutOrder = index,
                Parent = bar,
            })
            segButtons[opt] = segBtn
            segBtn.MouseButton1Click:Connect(function()
                currentValue = opt
                Highlight()
                if callback then
                    callback(opt)
                end
            end)
        end

        Accent.Changed:Connect(Highlight)
        Highlight()

        local api = {}
        function api.Set(value)
            currentValue = value
            Highlight()
        end
        function api.Get()
            return currentValue
        end
        return api
    end

    function Factory.RadioGroup(parent, config)
        config = config or {}
        local name = config.Name
        local options = config.Options or {}
        local default = config.Default or options[1]
        local callback = config.Callback

        local row = NewInstance("Frame", {
            Name = "RadioGroup_" .. tostring(name),
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(1, 0, 0, 0),
            Parent = parent,
        })

        local layout = NewInstance("UIListLayout", {
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = row,
        })

        if name then
            NewInstance("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 16),
                Font = Enum.Font.Gotham,
                TextSize = 14,
                TextColor3 = Color3.fromRGB(212, 218, 235),
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = name,
                Parent = row,
            })
        end

        local currentValue = default
        local dots = {}

        local function SelectOption(opt)
            currentValue = opt
            for optName, dot in pairs(dots) do
                dot.Visible = (optName == opt)
            end
        end

        for _, opt in ipairs(options) do
            local optRow = NewInstance("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 20),
                Parent = row,
            })

            local optBtn = NewInstance("TextButton", {
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                Text = "",
                AutoButtonColor = false,
                Parent = optRow,
            })

            NewInstance("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -24, 1, 0),
                Font = Enum.Font.Gotham,
                TextSize = 13,
                TextColor3 = Color3.fromRGB(196, 202, 224),
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = tostring(opt),
                Parent = optRow,
            })

            local ring = NewInstance("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, 0, 0.5, 0),
                Size = UDim2.fromOffset(16, 16),
                BackgroundColor3 = Color3.fromRGB(23, 25, 35),
                BorderSizePixel = 0,
                Parent = optRow,
            })

            NewInstance("UICorner", {
                CornerRadius = UDim.new(1, 0),
                Parent = ring,
            })

            NewInstance("UIStroke", {
                Color = Color3.fromRGB(104, 111, 140),
                Thickness = 1,
                Parent = ring,
            })

            local dot = NewInstance("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromOffset(8, 8),
                BackgroundColor3 = Accent.Value,
                BorderSizePixel = 0,
                Visible = (opt == default),
                Parent = ring,
            })

            NewInstance("UICorner", {
                CornerRadius = UDim.new(1, 0),
                Parent = dot,
            })

            dots[opt] = dot

            optBtn.MouseButton1Click:Connect(function()
                SelectOption(opt)
                if callback then
                    callback(opt)
                end
            end)
        end

        Accent.Changed:Connect(function(color)
            for _, dot in pairs(dots) do
                dot.BackgroundColor3 = color
            end
        end)

        local api = {}
        function api.Set(value)
            SelectOption(value)
        end
        function api.Get()
            return currentValue
        end
        return api
    end

    function Factory.Stepper(parent, config)
        config = config or {}
        local name = config.Name or "Stepper"
        local min = config.Min or 0
        local max = config.Max or 100
        local step = config.Step or 1
        if max < min then min, max = max, min end
        local default = math.clamp(config.Default or min, min, max)
        local callback = config.Callback

        local row = NewInstance("Frame", {
            Name = "Stepper_" .. name,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 26),
            Parent = parent,
        })

        NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -110, 1, 0),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Color3.fromRGB(212, 218, 235),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            Parent = row,
        })

        local controls = NewInstance("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(100, 22),
            BackgroundColor3 = Color3.fromRGB(23, 25, 35),
            BorderSizePixel = 0,
            Parent = row,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 4), Parent = controls })

        NewInstance("UIStroke", {
            Color = Color3.fromRGB(62, 66, 86),
            Thickness = 1,
            Parent = controls,
        })

        local minusBtn = NewInstance("TextButton", {
            Size = UDim2.new(0, 26, 1, 0),
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            TextColor3 = Color3.fromRGB(212, 218, 235),
            Text = "-",
            Parent = controls,
        })

        local valueLabel = NewInstance("TextLabel", {
            Position = UDim2.new(0, 26, 0, 0),
            Size = UDim2.new(1, -52, 1, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextColor3 = Color3.fromRGB(235, 240, 252),
            Text = tostring(default),
            Parent = controls,
        })

        local plusBtn = NewInstance("TextButton", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, 0),
            Size = UDim2.new(0, 26, 1, 0),
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            TextColor3 = Color3.fromRGB(212, 218, 235),
            Text = "+",
            Parent = controls,
        })

        local currentValue = default

        local function SetValue(value, fromUser)
            currentValue = math.clamp(value, min, max)
            valueLabel.Text = tostring(currentValue)
            if fromUser and callback then
                callback(currentValue)
            end
        end

        local function FlashButton(btn)
            TweenService:Create(btn, TweenInfo.new(0.08), { TextColor3 = Accent.Value }):Play()
            task.delay(0.12, function()
                TweenService:Create(btn, TweenInfo.new(0.15), { TextColor3 = Color3.fromRGB(212, 218, 235) }):Play()
            end)
        end

        minusBtn.MouseButton1Click:Connect(function()
            SetValue(currentValue - step, true)
            FlashButton(minusBtn)
        end)

        plusBtn.MouseButton1Click:Connect(function()
            SetValue(currentValue + step, true)
            FlashButton(plusBtn)
        end)

        local api = {}
        function api.Set(value)
            SetValue(value, false)
        end
        function api.Get()
            return currentValue
        end
        return api
    end

    function Factory.RangeSlider(parent, config)
        config = config or {}
        local name = config.Name or "Range"
        local min = config.Min or 0
        local max = config.Max or 100
        if max < min then min, max = max, min end
        local defaultLow = math.clamp(config.DefaultLow or min, min, max)
        local defaultHigh = math.clamp(config.DefaultHigh or max, min, max)
        local step = config.Step or 1
        local callback = config.Callback

        local row = NewInstance("Frame", {
            Name = "RangeSlider_" .. name,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 38),
            Parent = parent,
        })

        local label = NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 18),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Color3.fromRGB(212, 218, 235),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name .. ": " .. tostring(defaultLow) .. " - " .. tostring(defaultHigh),
            Parent = row,
        })

        local track = NewInstance("Frame", {
            Position = UDim2.fromOffset(0, 23),
            Size = UDim2.new(1, 0, 0, 8),
            BackgroundColor3 = Color3.fromRGB(23, 25, 35),
            BorderSizePixel = 0,
            Parent = row,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })

        local lowRatio = (max > min) and Clamp01((defaultLow - min) / (max - min)) or 0
        local highRatio = (max > min) and Clamp01((defaultHigh - min) / (max - min)) or 0

        local fill = NewInstance("Frame", {
            Position = UDim2.new(lowRatio, 0, 0, 0),
            Size = UDim2.new(highRatio - lowRatio, 0, 1, 0),
            BackgroundColor3 = Accent.Value,
            BorderSizePixel = 0,
            Parent = track,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })

        local lowKnob = NewInstance("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(lowRatio, 0, 0.5, 0),
            Size = UDim2.fromOffset(13, 18),
            BackgroundColor3 = Color3.fromRGB(245, 247, 255),
            BorderSizePixel = 0,
            ZIndex = track.ZIndex + 1,
            Parent = track,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(1, 0), Parent = lowKnob })

        local highKnob = NewInstance("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(highRatio, 0, 0.5, 0),
            Size = UDim2.fromOffset(13, 18),
            BackgroundColor3 = Color3.fromRGB(245, 247, 255),
            BorderSizePixel = 0,
            ZIndex = track.ZIndex + 1,
            Parent = track,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(1, 0), Parent = highKnob })

        Accent.Changed:Connect(function(color)
            fill.BackgroundColor3 = color
        end)

        local currentLow = defaultLow
        local currentHigh = defaultHigh

        local function ApplyRange(fromUser)
            local lr = (max > min) and Clamp01((currentLow - min) / (max - min)) or 0
            local hr = (max > min) and Clamp01((currentHigh - min) / (max - min)) or 0
            fill.Position = UDim2.new(lr, 0, 0, 0)
            fill.Size = UDim2.new(hr - lr, 0, 1, 0)
            lowKnob.Position = UDim2.new(lr, 0, 0.5, 0)
            highKnob.Position = UDim2.new(hr, 0, 0.5, 0)
            label.Text = name .. ": " .. tostring(currentLow) .. " - " .. tostring(currentHigh)
            if fromUser and callback then
                callback(currentLow, currentHigh)
            end
        end

        local function UpdateLow(xPos)
            local trackPos = track.AbsolutePosition.X
            local trackSize = track.AbsoluteSize.X
            if trackSize <= 0 then
                return
            end
            local ratio = Clamp01((xPos - trackPos) / trackSize)
            local value = math.clamp(RoundTo(min + (max - min) * ratio, step), min, max)
            currentLow = math.min(value, currentHigh)
            ApplyRange(true)
        end

        local function UpdateHigh(xPos)
            local trackPos = track.AbsolutePosition.X
            local trackSize = track.AbsoluteSize.X
            if trackSize <= 0 then
                return
            end
            local ratio = Clamp01((xPos - trackPos) / trackSize)
            local value = math.clamp(RoundTo(min + (max - min) * ratio, step), min, max)
            currentHigh = math.max(value, currentLow)
            ApplyRange(true)
        end

        MakeValueDragger({ lowKnob }, function(input)
            lowKnob.ZIndex = track.ZIndex + 2
            highKnob.ZIndex = track.ZIndex + 1
            UpdateLow(input.Position.X)
        end, function(input)
            UpdateLow(input.Position.X)
        end)

        MakeValueDragger({ highKnob }, function(input)
            highKnob.ZIndex = track.ZIndex + 2
            lowKnob.ZIndex = track.ZIndex + 1
            UpdateHigh(input.Position.X)
        end, function(input)
            UpdateHigh(input.Position.X)
        end)

        local api = {}
        function api.Set(low, high)
            currentLow = math.clamp(low, min, max)
            currentHigh = math.clamp(high, min, max)
            if currentLow > currentHigh then currentLow, currentHigh = currentHigh, currentLow end
            ApplyRange(false)
        end
        function api.Get()
            return currentLow, currentHigh
        end
        return api
    end

    function Factory.KeyValue(parent, config)
        config = config or {}
        local key = config.Key or ""
        local value = config.Value or ""

        local row = NewInstance("Frame", {
            Name = "KeyValue_" .. key,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 20),
            Parent = parent,
        })

        NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0.5, 0, 1, 0),
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextColor3 = Color3.fromRGB(150, 156, 178),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = key,
            Parent = row,
        })

        local valueLabel = NewInstance("TextLabel", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, 0),
            Size = UDim2.new(0.5, 0, 1, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium,
            TextSize = 13,
            TextColor3 = Color3.fromRGB(235, 240, 252),
            TextXAlignment = Enum.TextXAlignment.Right,
            Text = tostring(value),
            Parent = row,
        })

        local api = {}
        function api.Set(newValue)
            valueLabel.Text = tostring(newValue)
        end
        return api
    end

    function Factory.Badge(parent, config)
        config = config or {}
        local name = config.Name or "Status"
        local text = config.Text or "Active"
        local color = config.Color or Accent.Value

        local row = NewInstance("Frame", {
            Name = "Badge_" .. name,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 24),
            Parent = parent,
        })

        NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -90, 1, 0),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Color3.fromRGB(212, 218, 235),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            Parent = row,
        })

        local pill = NewInstance("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(0, 18),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = color,
            BackgroundTransparency = 0.8,
            BorderSizePixel = 0,
            Parent = row,
        })

        NewInstance("UICorner", {
            CornerRadius = UDim.new(1, 0),
            Parent = pill,
        })

        local pillStroke = NewInstance("UIStroke", {
            Color = color,
            Thickness = 1,
            Parent = pill,
        })

        local label = NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(0, 18),
            AutomaticSize = Enum.AutomaticSize.X,
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            TextColor3 = color,
            Text = text,
            Parent = pill,
        })

        NewInstance("UIPadding", {
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            Parent = pill,
        })

        local api = {}
        function api.Set(newText, newColor)
            label.Text = newText
            if newColor then
                pill.BackgroundColor3 = newColor
                label.TextColor3 = newColor
                pillStroke.Color = newColor
            end
        end
        return api
    end

    function Factory.ToggleSlider(parent, config)
        config = config or {}
        local name = config.Name or "ToggleSlider"
        local toggleDefault = config.ToggleDefault or false
        local min = config.Min or 0
        local max = config.Max or 100
        if max < min then min, max = max, min end
        local sliderDefault = math.clamp(config.SliderDefault or min, min, max)
        local step = config.Step or 1
        local toggleCallback = config.ToggleCallback
        local sliderCallback = config.SliderCallback

        local row = NewInstance("Frame", {
            Name = "ToggleSlider_" .. name,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 38),
            Parent = parent,
        })

        local label = NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -48, 0, 18),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Color3.fromRGB(212, 218, 235),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name .. ": " .. tostring(sliderDefault),
            Parent = row,
        })

        local box = NewInstance("TextButton", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, 0),
            Size = UDim2.fromOffset(20, 18),
            BackgroundColor3 = Color3.fromRGB(23, 25, 35),
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            Parent = row,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 4), Parent = box })

        local toggleFill = NewInstance("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Accent.Value,
            BorderSizePixel = 0,
            BackgroundTransparency = toggleDefault and 0 or 1,
            Parent = box,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 4), Parent = toggleFill })

        local track = NewInstance("Frame", {
            Position = UDim2.fromOffset(0, 23),
            Size = UDim2.new(1, 0, 0, 8),
            BackgroundColor3 = Color3.fromRGB(23, 25, 35),
            BorderSizePixel = 0,
            Parent = row,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })

        local fillRatio = (max > min) and Clamp01((sliderDefault - min) / (max - min)) or 0

        local sliderFill = NewInstance("Frame", {
            Size = UDim2.new(fillRatio, 0, 1, 0),
            BackgroundColor3 = Accent.Value,
            BorderSizePixel = 0,
            Parent = track,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(1, 0), Parent = sliderFill })

        local knob = NewInstance("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(fillRatio, 0, 0.5, 0),
            Size = UDim2.fromOffset(13, 18),
            BackgroundColor3 = Color3.fromRGB(245, 247, 255),
            BorderSizePixel = 0,
            ZIndex = track.ZIndex + 1,
            Parent = track,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })

        Accent.Changed:Connect(function(color)
            toggleFill.BackgroundColor3 = color
            sliderFill.BackgroundColor3 = color
        end)

        local toggleState = toggleDefault
        local sliderValue = sliderDefault

        box.MouseButton1Click:Connect(function()
            toggleState = not toggleState
            TweenService:Create(toggleFill, TweenInfo.new(0.15), { BackgroundTransparency = toggleState and 0 or 1 }):Play()
            if toggleCallback then
                toggleCallback(toggleState)
            end
        end)

        local function UpdateFromX(xPos)
            local trackPos = track.AbsolutePosition.X
            local trackSize = track.AbsoluteSize.X
            if trackSize <= 0 then
                return
            end
            local ratio = Clamp01((xPos - trackPos) / trackSize)
            sliderValue = math.clamp(RoundTo(min + (max - min) * ratio, step), min, max)
            local snappedRatio = (max > min) and Clamp01((sliderValue - min) / (max - min)) or 0
            sliderFill.Size = UDim2.new(snappedRatio, 0, 1, 0)
            knob.Position = UDim2.new(snappedRatio, 0, 0.5, 0)
            label.Text = name .. ": " .. tostring(sliderValue)
            if sliderCallback then
                sliderCallback(sliderValue)
            end
        end

        MakeValueDragger({ knob, track }, function(input)
            UpdateFromX(input.Position.X)
        end, function(input)
            UpdateFromX(input.Position.X)
        end)

        local api = {}
        function api.GetToggle()
            return toggleState
        end
        function api.GetSlider()
            return sliderValue
        end
        return api
    end

    function Factory.SearchableDropdown(parent, config)
        config = config or {}
        local name = config.Name or "Dropdown"
        local options = config.Options or {}
        local default = config.Default or options[1]
        local callback = config.Callback

        local row = NewInstance("Frame", {
            Name = "SearchableDropdown_" .. name,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 46),
            Parent = parent,
        })

        NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 16),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Color3.fromRGB(212, 218, 235),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            Parent = row,
        })

        local box = NewInstance("TextButton", {
            Position = UDim2.fromOffset(0, 20),
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundColor3 = Color3.fromRGB(23, 25, 35),
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextColor3 = Color3.fromRGB(235, 240, 252),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "  " .. tostring(default or ""),
            Parent = row,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 4), Parent = box })

        NewInstance("UIStroke", {
            Color = Color3.fromRGB(62, 66, 86),
            Thickness = 1,
            Parent = box,
        })

        local arrow = NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -8, 0.5, 0),
            Size = UDim2.fromOffset(16, 16),
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = Accent.Value,
            Text = "v",
            Parent = box,
        })

        Accent.Changed:Connect(function(color)
            arrow.TextColor3 = color
        end)

        local panelHeight = math.min(#options, 5) * 24 + 28

        local optionsHolder = NewInstance("Frame", {
            Name = "SearchableDropdownHolder_" .. name,
            BackgroundColor3 = Color3.fromRGB(18, 20, 28),
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(0, panelHeight),
            Visible = false,
            ZIndex = 200,
            Parent = ScreenGui,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 6), Parent = optionsHolder })

        NewInstance("UIStroke", {
            Color = Color3.fromRGB(62, 66, 86),
            Thickness = 1,
            Parent = optionsHolder,
        })

        local searchBox = NewInstance("TextBox", {
            Position = UDim2.fromOffset(4, 4),
            Size = UDim2.new(1, -8, 0, 20),
            BackgroundColor3 = Color3.fromRGB(28, 30, 42),
            BorderSizePixel = 0,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextColor3 = Color3.fromRGB(235, 240, 252),
            PlaceholderText = "Search...",
            PlaceholderColor3 = Color3.fromRGB(134, 142, 176),
            ClearTextOnFocus = false,
            Text = "",
            ZIndex = optionsHolder.ZIndex + 1,
            Parent = optionsHolder,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 4), Parent = searchBox })

        NewInstance("UIPadding", {
            PaddingLeft = UDim.new(0, 6),
            Parent = searchBox,
        })

        local listHolder = NewInstance("ScrollingFrame", {
            Position = UDim2.fromOffset(0, 28),
            Size = UDim2.new(1, 0, 1, -28),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 0,
            ZIndex = optionsHolder.ZIndex + 1,
            Parent = optionsHolder,
        })

        NewInstance("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = listHolder,
        })

        local currentValue = default
        local isOpen = false

        local function Close()
            isOpen = false
            optionsHolder.Visible = false
        end

        local function RebuildOptions(filterText)
            for _, child in ipairs(listHolder:GetChildren()) do
                if child:IsA("TextButton") then
                    child:Destroy()
                end
            end
            filterText = (filterText or ""):lower()
            for _, opt in ipairs(options) do
                if filterText == "" or tostring(opt):lower():find(filterText, 1, true) then
                    local optBtn = NewInstance("TextButton", {
                        BackgroundColor3 = Color3.fromRGB(18, 20, 28),
                        BorderSizePixel = 0,
                        AutoButtonColor = false,
                        Size = UDim2.new(1, 0, 0, 24),
                        Font = Enum.Font.Gotham,
                        TextSize = 13,
                        TextColor3 = Color3.fromRGB(212, 218, 235),
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Text = "  " .. tostring(opt),
                        ZIndex = listHolder.ZIndex + 1,
                        Parent = listHolder,
                    })
                    optBtn.MouseButton1Click:Connect(function()
                        currentValue = opt
                        box.Text = "  " .. tostring(opt)
                        Close()
                        if callback then
                            callback(opt)
                        end
                    end)
                end
            end
        end

        RebuildOptions("")

        searchBox:GetPropertyChangedSignal("Text"):Connect(function()
            RebuildOptions(searchBox.Text)
        end)

        local function Open()
            CloseAllOverlaysExcept(optionsHolder)
            local boxPos = box.AbsolutePosition
            local boxSize = box.AbsoluteSize
            optionsHolder.Size = UDim2.fromOffset(boxSize.X, panelHeight)
            local x, y = ClampOpenPosition(boxPos.X, boxPos.Y + boxSize.Y + 2, boxSize.X, panelHeight)
            optionsHolder.Position = UDim2.fromOffset(x, y)
            optionsHolder.Visible = true
            isOpen = true
            searchBox.Text = ""
        end

        box.MouseButton1Click:Connect(function()
            if isOpen then
                Close()
            else
                Open()
            end
        end)

        RegisterOverlay(optionsHolder, box, function() return isOpen end, Close)

        row.Destroying:Connect(function()
            optionsHolder:Destroy()
        end)

        local api = {}
        function api.Set(value)
            currentValue = value
            box.Text = "  " .. tostring(value)
        end
        function api.Get()
            return currentValue
        end
        return api
    end

    function Factory.Input(parent, config)
        config = config or {}
        local name = config.Name or "Input"
        local default = config.Default or ""
        local placeholder = config.Placeholder or ""
        local numeric = config.Numeric or false
        local min = config.Min
        local max = config.Max
        local callback = config.Callback

        local row = NewInstance("Frame", {
            Name = "Input_" .. name,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 40),
            Parent = parent,
        })

        NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 16),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Color3.fromRGB(212, 218, 235),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            Parent = row,
        })

        local box = NewInstance("TextBox", {
            Position = UDim2.fromOffset(0, 20),
            Size = UDim2.new(1, 0, 0, 20),
            BackgroundColor3 = Color3.fromRGB(23, 25, 35),
            BorderSizePixel = 0,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextColor3 = Color3.fromRGB(235, 240, 252),
            PlaceholderText = placeholder,
            PlaceholderColor3 = Color3.fromRGB(134, 142, 176),
            ClearTextOnFocus = false,
            Text = tostring(default),
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 4), Parent = box })

        if numeric then
            box.TextWrapped = false
        end

        local boxStroke = NewInstance("UIStroke", {
            Color = Color3.fromRGB(62, 66, 86),
            Thickness = 1,
            Parent = box,
        })

        NewInstance("UIPadding", {
            PaddingLeft = UDim.new(0, 6),
            PaddingRight = UDim.new(0, 6),
            Parent = box,
        })

        box.Focused:Connect(function()
            boxStroke.Color = Accent.Value
        end)

        box.FocusLost:Connect(function(enterPressed)
            boxStroke.Color = Color3.fromRGB(62, 66, 86)

            if numeric then
                local n = tonumber(box.Text)
                if n == nil then
                    n = tonumber(default) or 0
                end
                if min then n = math.max(n, min) end
                if max then n = math.min(n, max) end
                box.Text = tostring(n)
                if callback then
                    callback(n, enterPressed)
                end
            else
                if callback then
                    callback(box.Text, enterPressed)
                end
            end
        end)

        Accent.Changed:Connect(function(color)
            if box:IsFocused() then
                boxStroke.Color = color
            end
        end)

        local api = {}
        function api.Set(value)
            box.Text = tostring(value)
        end
        function api.Get()
            if numeric then
                return tonumber(box.Text)
            end
            return box.Text
        end
        return api
    end

    function Factory.Group(parent, config)
        config = config or {}
        local name = config.Name or "Group"
        local startOpen = config.Open
        if startOpen == nil then
            startOpen = true
        end

        local container = NewInstance("Frame", {
            Name = "Group_" .. name,
            BackgroundColor3 = Color3.fromRGB(20, 22, 31),
            BorderSizePixel = 0,
            AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(1, 0, 0, 0),
            Parent = parent,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 6), Parent = container })

        NewInstance("UIStroke", {
            Color = Color3.fromRGB(56, 60, 78),
            Thickness = 1,
            Parent = container,
        })

        local outerLayout = NewInstance("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = container,
        })

        local header = NewInstance("TextButton", {
            Name = "Header",
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Size = UDim2.new(1, 0, 0, 28),
            Text = "",
            Parent = container,
        })

        NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(8, 0),
            Size = UDim2.new(1, -32, 1, 0),
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextColor3 = Color3.fromRGB(220, 226, 242),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            Parent = header,
        })

        local chevron = NewInstance("TextLabel", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -8, 0.5, 0),
            Size = UDim2.fromOffset(16, 16),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = Accent.Value,
            Text = startOpen and "v" or ">",
            Parent = header,
        })

        Accent.Changed:Connect(function(color)
            chevron.TextColor3 = color
        end)

        local body = NewInstance("Frame", {
            Name = "Body",
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(1, 0, 0, 0),
            Visible = startOpen,
            Parent = container,
        })

        NewInstance("UIPadding", {
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            PaddingBottom = UDim.new(0, 10),
            Parent = body,
        })

        local bodyLayout = NewInstance("UIListLayout", {
            Padding = UDim.new(0, 10),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = body,
        })

        local isOpen = startOpen

        header.MouseButton1Click:Connect(function()
            isOpen = not isOpen
            body.Visible = isOpen
            chevron.Text = isOpen and "v" or ">"
        end)

        local Group = {}
        Group.Instance = container

        function Group:AddLabel(text)
            return Factory.Label(body, text)
        end
        function Group:AddParagraph(cfg)
            return Factory.Paragraph(body, cfg)
        end
        function Group:AddSection(text)
            return Factory.Section(body, text)
        end
        function Group:AddToggle(cfg)
            return Factory.Toggle(body, cfg)
        end
        function Group:AddCheckbox(cfg)
            return Factory.Checkbox(body, cfg)
        end
        function Group:AddSlider(cfg)
            return Factory.Slider(body, cfg)
        end
        function Group:AddRangeSlider(cfg)
            return Factory.RangeSlider(body, cfg)
        end
        function Group:AddStepper(cfg)
            return Factory.Stepper(body, cfg)
        end
        function Group:AddButton(cfg)
            return Factory.Button(body, cfg)
        end
        function Group:AddToggleSlider(cfg)
            return Factory.ToggleSlider(body, cfg)
        end
        function Group:AddDropdown(cfg)
            return Factory.Dropdown(body, cfg)
        end
        function Group:AddMultiDropdown(cfg)
            return Factory.MultiDropdown(body, cfg)
        end
        function Group:AddSearchableDropdown(cfg)
            return Factory.SearchableDropdown(body, cfg)
        end
        function Group:AddRadioGroup(cfg)
            return Factory.RadioGroup(body, cfg)
        end

        function Group:AddSwitch(cfg)
            return Factory.Switch(body, cfg)
        end

        function Group:AddSegmented(cfg)
            return Factory.Segmented(body, cfg)
        end
        function Group:AddColorPicker(cfg)
            return Factory.ColorPicker(body, cfg)
        end
        function Group:AddTextbox(cfg)
            return Factory.Textbox(body, cfg)
        end
        function Group:AddInput(cfg)
            return Factory.Input(body, cfg)
        end
        function Group:AddKeybind(cfg)
            return Factory.Keybind(body, cfg)
        end
        function Group:AddProgressBar(cfg)
            return Factory.ProgressBar(body, cfg)
        end
        function Group:AddImage(cfg)
            return Factory.Image(body, cfg)
        end
        function Group:AddKeyValue(cfg)
            return Factory.KeyValue(body, cfg)
        end
        function Group:AddBadge(cfg)
            return Factory.Badge(body, cfg)
        end
        function Group:AddDivider()
            return Factory.Divider(body)
        end
        function Group:AddSpacer(height)
            return Factory.Spacer(body, height)
        end
        function Group:AddGroup(cfg)
            return Factory.Group(body, cfg)
        end
        function Group:SetOpen(open)
            isOpen = open
            body.Visible = isOpen
            chevron.Text = isOpen and "v" or ">"
        end

        return Group
    end

    return Factory
end

local function CreateTab(context, tabName, isFirst)
    local Factory = context.Factory
    local ScrollHolder = context.ScrollHolder

    local scroll = NewInstance("ScrollingFrame", {
        Name = tabName .. "_Scroll",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromScale(0, 0),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.None,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 0,
        ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
        ClipsDescendants = true,
        Visible = isFirst,
        ZIndex = ScrollHolder.ZIndex + 1,
        Parent = ScrollHolder,
    })

    local layout = NewInstance("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = scroll,
    })

    NewInstance("UIPadding", {
        PaddingTop = UDim.new(0, 6),
        PaddingBottom = UDim.new(0, 14),
        PaddingLeft = UDim.new(0, 4),
        PaddingRight = UDim.new(0, 4),
        Parent = scroll,
    })

    local function RefreshCanvas()
        scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 28)
    end

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(RefreshCanvas)

    local Tab = {}
    Tab.Name = tabName
    Tab.Instance = scroll

    function Tab:AddLabel(text)
        return Factory.Label(scroll, text)
    end

    function Tab:AddParagraph(config)
        return Factory.Paragraph(scroll, config)
    end

    function Tab:AddSection(text)
        return Factory.Section(scroll, text)
    end

    function Tab:AddToggle(config)
        return Factory.Toggle(scroll, config)
    end

    function Tab:AddSlider(config)
        return Factory.Slider(scroll, config)
    end

    function Tab:AddButton(config)
        return Factory.Button(scroll, config)
    end

    function Tab:AddProgressBar(config)
        return Factory.ProgressBar(scroll, config)
    end

    function Tab:AddImage(config)
        return Factory.Image(scroll, config)
    end

    function Tab:AddDropdown(config)
        return Factory.Dropdown(scroll, config)
    end

    function Tab:AddMultiDropdown(config)
        return Factory.MultiDropdown(scroll, config)
    end

    function Tab:AddColorPicker(config)
        return Factory.ColorPicker(scroll, config)
    end

    function Tab:AddTextbox(config)
        return Factory.Textbox(scroll, config)
    end

    function Tab:AddKeybind(config)
        return Factory.Keybind(scroll, config)
    end

    function Tab:AddDivider()
        return Factory.Divider(scroll)
    end

    function Tab:AddSpacer(height)
        return Factory.Spacer(scroll, height)
    end

    function Tab:AddCheckbox(config)
        return Factory.Checkbox(scroll, config)
    end

    function Tab:AddRadioGroup(config)
        return Factory.RadioGroup(scroll, config)
    end

    function Tab:AddSwitch(config)
        return Factory.Switch(scroll, config)
    end

    function Tab:AddSegmented(config)
        return Factory.Segmented(scroll, config)
    end

    function Tab:AddStepper(config)
        return Factory.Stepper(scroll, config)
    end

    function Tab:AddRangeSlider(config)
        return Factory.RangeSlider(scroll, config)
    end

    function Tab:AddKeyValue(config)
        return Factory.KeyValue(scroll, config)
    end

    function Tab:AddBadge(config)
        return Factory.Badge(scroll, config)
    end

    function Tab:AddToggleSlider(config)
        return Factory.ToggleSlider(scroll, config)
    end

    function Tab:AddSearchableDropdown(config)
        return Factory.SearchableDropdown(scroll, config)
    end

    function Tab:AddInput(config)
        return Factory.Input(scroll, config)
    end

    function Tab:AddGroup(config)
        return Factory.Group(scroll, config)
    end

    function Tab:Refresh()
        RefreshCanvas()
    end

    task.defer(RefreshCanvas)

    return Tab
end


local function SafeSetProperty(instance, propertyName, value)
    pcall(function()
        instance[propertyName] = value
    end)
end

local function Color3ToHex(color)
    local r = math.clamp(math.floor(color.R * 255 + 0.5), 0, 255)
    local g = math.clamp(math.floor(color.G * 255 + 0.5), 0, 255)
    local b = math.clamp(math.floor(color.B * 255 + 0.5), 0, 255)
    return string.format("%02X%02X%02X", r, g, b)
end

local IconPacks = {
    lucide = {
        provider = "lucide",
        iconifySet = "lucide",
        defaultVariant = "default",
        rawPattern = "https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/%s.svg",
    },
    solar = {
        provider = "solar",
        iconifySet = "solar",
        defaultVariant = "linear",
    },
}

local Icons = {}
Icons.Packs = IconPacks

function Icons.Resolve(provider, name, variant)
    local pack = IconPacks[string.lower(provider or "lucide")]
    if not pack then
        return nil
    end

    local cleanName = tostring(name or ""):lower():gsub("_", "-")
    local cleanVariant = tostring(variant or pack.defaultVariant or "default"):lower():gsub("_", "-")
    local iconifyName = cleanName

    if pack.provider == "solar" then
        local suffixes = {
            ["linear"] = true,
            ["outline"] = true,
            ["bold"] = true,
            ["broken"] = true,
            ["line-duotone"] = true,
            ["bold-duotone"] = true,
        }
        local hasKnownSuffix = false
        for suffix in pairs(suffixes) do
            if iconifyName:sub(-#suffix) == suffix then
                hasKnownSuffix = true
                break
            end
        end
        if not hasKnownSuffix then
            iconifyName = iconifyName .. "-" .. cleanVariant
        end
    end

    local info = {
        provider = pack.provider,
        name = cleanName,
        variant = cleanVariant,
        iconifySet = pack.iconifySet,
        iconifyName = iconifyName,
        iconifyKey = pack.iconifySet .. ":" .. iconifyName,
    }

    info.iconifyUrl = "https://api.iconify.design/" .. info.iconifyKey .. ".svg"
    if pack.rawPattern then
        info.rawUrl = string.format(pack.rawPattern, cleanName)
    end

    return info
end

function Icons.GetUrl(provider, name, variant, color, size)
    local info = Icons.Resolve(provider, name, variant)
    if not info then
        return nil
    end

    local query = {}
    if color ~= nil then
        local hex = color
        if typeof(color) == "Color3" then
            hex = Color3ToHex(color)
        else
            hex = tostring(color):gsub("#", "")
        end
        table.insert(query, "color=%23" .. hex)
    end
    if size ~= nil then
        table.insert(query, "width=" .. tostring(size))
        table.insert(query, "height=" .. tostring(size))
    end

    if #query > 0 then
        return info.iconifyUrl .. "?" .. table.concat(query, "&")
    end
    return info.iconifyUrl
end

local function TryHttpGet(url)
    local requestFns = {
        function()
            if typeof(request) == "function" then
                return request({ Url = url, Method = "GET" })
            end
        end,
        function()
            if typeof(http_request) == "function" then
                return http_request({ Url = url, Method = "GET" })
            end
        end,
        function()
            if typeof(syn) == "table" and typeof(syn.request) == "function" then
                return syn.request({ Url = url, Method = "GET" })
            end
        end,
        function()
            if typeof(game.HttpGet) == "function" then
                return {
                    Success = true,
                    StatusCode = 200,
                    Body = game:HttpGet(url),
                }
            end
        end,
    }

    for _, run in ipairs(requestFns) do
        local ok, response = pcall(run)
        if ok and response then
            if type(response) == "table" then
                local success = response.Success
                if success == nil then
                    success = tonumber(response.StatusCode or 0) == 200
                end
                if success and response.Body then
                    return true, response.Body
                end
            elseif type(response) == "string" and response ~= "" then
                return true, response
            end
        end
    end

    return false, nil
end

function Icons.FetchSvg(provider, name, variant)
    local info = Icons.Resolve(provider, name, variant)
    if not info then
        return nil
    end

    if info.rawUrl then
        local ok, body = TryHttpGet(info.rawUrl)
        if ok then
            return body, info
        end
    end

    local ok, body = TryHttpGet(info.iconifyUrl)
    if ok then
        return body, info
    end

    return nil, info
end

local function CreateWindow(config)
    config = config or {}

    local windowName = config.Name or "Lurk"
    local windowSize = config.Size or UDim2.fromOffset(500, 360)
    local sidebarWidth = config.SidebarWidth or 138
    local openButtonText = config.OpenButtonText or string.sub(windowName, 1, 1)
    local startColor = config.AccentColor or Color3.fromRGB(108, 92, 255)

    local MAIN_DISPLAY_ORDER = config.DisplayOrder or 2147482000
    local FLOATING_DISPLAY_ORDER = config.FloatingDisplayOrder or (MAIN_DISPLAY_ORDER - 80)
    local OPEN_BUTTON_DISPLAY_ORDER = config.OpenButtonDisplayOrder or (MAIN_DISPLAY_ORDER + 80)

    local theme = {
        canvas = Color3.fromRGB(10, 12, 18),
        surface = Color3.fromRGB(16, 18, 27),
        surfaceAlt = Color3.fromRGB(20, 23, 34),
        surfaceRaised = Color3.fromRGB(25, 29, 43),
        sidebar = Color3.fromRGB(14, 16, 24),
        border = Color3.fromRGB(54, 59, 79),
        borderSoft = Color3.fromRGB(37, 41, 56),
        text = Color3.fromRGB(240, 244, 255),
        textMuted = Color3.fromRGB(151, 158, 184),
        textSoft = Color3.fromRGB(120, 128, 154),
        shadow = Color3.fromRGB(5, 6, 10),
        overlay = Color3.fromRGB(6, 7, 10),
    }

    local existing = GuiParent:FindFirstChild("LurkGui_" .. windowName)
    if existing then
        existing:Destroy()
    end

    local existingOpenGui = GuiParent:FindFirstChild("LurkOpenButton_" .. windowName)
    if existingOpenGui then
        existingOpenGui:Destroy()
    end

    local ScreenGui = NewInstance("ScreenGui", {
        Name = "LurkGui_" .. windowName,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = MAIN_DISPLAY_ORDER,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    SafeSetProperty(ScreenGui, "OnTopOfCoreBlur", true)
    ProtectGui(ScreenGui)
    ScreenGui.Parent = GuiParent

    local OpenButtonGui = NewInstance("ScreenGui", {
        Name = "LurkOpenButton_" .. windowName,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = OPEN_BUTTON_DISPLAY_ORDER,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    SafeSetProperty(OpenButtonGui, "OnTopOfCoreBlur", true)
    ProtectGui(OpenButtonGui)
    OpenButtonGui.Parent = GuiParent

    local Accent = {}
    Accent.Value = startColor
    Accent._bindable = Instance.new("BindableEvent")
    Accent.Changed = Accent._bindable.Event
    function Accent.Set(color)
        Accent.Value = color
        Accent._bindable:Fire(color)
    end

    local backdrop = NewInstance("TextButton", {
        Name = "Backdrop",
        BackgroundColor3 = theme.overlay,
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Visible = false,
        Text = "",
        ZIndex = 1,
        Parent = ScreenGui,
    })

    local shadow = NewInstance("Frame", {
        Name = "WindowShadow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(windowSize.X.Scale, windowSize.X.Offset + 28, windowSize.Y.Scale, windowSize.Y.Offset + 28),
        BackgroundColor3 = theme.shadow,
        BackgroundTransparency = 0.58,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 2,
        Parent = ScreenGui,
    })
    NewInstance("UICorner", { CornerRadius = UDim.new(0, 24), Parent = shadow })

    local mainWindow = NewInstance("Frame", {
        Name = "MainWindow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = windowSize,
        BackgroundColor3 = theme.surface,
        BorderSizePixel = 0,
        ClipsDescendants = false,
        Visible = false,
        ZIndex = 3,
        Parent = ScreenGui,
    })
    NewInstance("UICorner", { CornerRadius = UDim.new(0, 20), Parent = mainWindow })
    local mainStroke = NewInstance("UIStroke", {
        Color = theme.border,
        Thickness = 1,
        Transparency = 0.08,
        Parent = mainWindow,
    })

    local windowGradient = NewInstance("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 23, 34)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(11, 13, 20)),
        }),
        Parent = mainWindow,
    })

    local ambientGlow = NewInstance("Frame", {
        Name = "AmbientGlow",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.62, 0, 0, -70),
        Size = UDim2.fromOffset(280, 180),
        BackgroundColor3 = Accent.Value,
        BackgroundTransparency = 0.86,
        BorderSizePixel = 0,
        ZIndex = mainWindow.ZIndex,
        Parent = mainWindow,
    })
    NewInstance("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ambientGlow })

    Accent.Changed:Connect(function(color)
        ambientGlow.BackgroundColor3 = color
    end)

    local inner = NewInstance("Frame", {
        Name = "Inner",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = mainWindow.ZIndex + 1,
        Parent = mainWindow,
    })

    local titleBar = NewInstance("Frame", {
        Name = "TitleBar",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 12),
        Size = UDim2.new(1, -28, 0, 42),
        ZIndex = inner.ZIndex + 1,
        Parent = inner,
    })

    local dragHandle = NewInstance("Frame", {
        Name = "DragHandle",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -116, 1, 0),
        Parent = titleBar,
    })

    local titleMeta = NewInstance("Frame", {
        Name = "TitleMeta",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -116, 1, 0),
        ZIndex = titleBar.ZIndex + 1,
        Parent = titleBar,
    })

    local brandDot = NewInstance("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 2, 0.5, 0),
        Size = UDim2.fromOffset(10, 10),
        BackgroundColor3 = Accent.Value,
        BorderSizePixel = 0,
        ZIndex = titleMeta.ZIndex + 1,
        Parent = titleMeta,
    })
    NewInstance("UICorner", { CornerRadius = UDim.new(1, 0), Parent = brandDot })

    local titleText = NewInstance("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(20, 2),
        Size = UDim2.new(1, -20, 0, 18),
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextColor3 = theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = windowName,
        ZIndex = titleMeta.ZIndex + 1,
        Parent = titleMeta,
    })

    local subtitleText = NewInstance("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(20, 19),
        Size = UDim2.new(1, -20, 0, 16),
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = theme.textMuted,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "minimal dark interface",
        ZIndex = titleMeta.ZIndex + 1,
        Parent = titleMeta,
    })

    local windowBadge = NewInstance("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(104, 28),
        BackgroundColor3 = theme.surfaceAlt,
        BorderSizePixel = 0,
        ZIndex = titleBar.ZIndex + 1,
        Parent = titleBar,
    })
    NewInstance("UICorner", { CornerRadius = UDim.new(0, 10), Parent = windowBadge })
    local windowBadgeStroke = NewInstance("UIStroke", {
        Color = theme.borderSoft,
        Thickness = 1,
        Transparency = 0.15,
        Parent = windowBadge,
    })

    local badgeAccent = NewInstance("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromOffset(10, 14),
        Size = UDim2.fromOffset(7, 7),
        BackgroundColor3 = Accent.Value,
        BorderSizePixel = 0,
        ZIndex = windowBadge.ZIndex + 1,
        Parent = windowBadge,
    })
    NewInstance("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badgeAccent })

    local badgeText = NewInstance("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(24, 0),
        Size = UDim2.new(1, -24, 1, 0),
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = theme.textMuted,
        Text = "overlay locked",
        ZIndex = windowBadge.ZIndex + 1,
        Parent = windowBadge,
    })

    Accent.Changed:Connect(function(color)
        badgeAccent.BackgroundColor3 = color
    end)

    local sidebar = NewInstance("Frame", {
        Name = "Sidebar",
        BackgroundColor3 = theme.sidebar,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(14, 62),
        Size = UDim2.new(0, sidebarWidth, 1, -76),
        ZIndex = inner.ZIndex + 1,
        Parent = inner,
    })
    NewInstance("UICorner", { CornerRadius = UDim.new(0, 18), Parent = sidebar })
    NewInstance("UIStroke", {
        Color = theme.borderSoft,
        Thickness = 1,
        Transparency = 0.12,
        Parent = sidebar,
    })

    local sidebarGlow = NewInstance("Frame", {
        BackgroundColor3 = Accent.Value,
        BackgroundTransparency = 0.92,
        Position = UDim2.fromOffset(12, 12),
        Size = UDim2.new(1, -24, 0, 56),
        BorderSizePixel = 0,
        ZIndex = sidebar.ZIndex + 1,
        Parent = sidebar,
    })
    NewInstance("UICorner", { CornerRadius = UDim.new(0, 14), Parent = sidebarGlow })

    local logoChip = NewInstance("Frame", {
        BackgroundColor3 = theme.surfaceRaised,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(12, 12),
        Size = UDim2.new(1, -24, 0, 56),
        ZIndex = sidebar.ZIndex + 2,
        Parent = sidebar,
    })
    NewInstance("UICorner", { CornerRadius = UDim.new(0, 14), Parent = logoChip })
    NewInstance("UIStroke", {
        Color = theme.border,
        Thickness = 1,
        Transparency = 0.15,
        Parent = logoChip,
    })

    local logoBadge = NewInstance("Frame", {
        Position = UDim2.fromOffset(10, 10),
        Size = UDim2.fromOffset(36, 36),
        BackgroundColor3 = Accent.Value,
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        ZIndex = logoChip.ZIndex + 1,
        Parent = logoChip,
    })
    NewInstance("UICorner", { CornerRadius = UDim.new(0, 12), Parent = logoBadge })

    local logoLabel = NewInstance("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Font = Enum.Font.GothamBlack,
        Text = openButtonText,
        TextSize = 20,
        TextColor3 = theme.text,
        ZIndex = logoBadge.ZIndex + 1,
        Parent = logoBadge,
    })

    local logoTitle = NewInstance("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(56, 11),
        Size = UDim2.new(1, -62, 0, 16),
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = windowName,
        ZIndex = logoChip.ZIndex + 1,
        Parent = logoChip,
    })

    local logoSubtitle = NewInstance("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(56, 27),
        Size = UDim2.new(1, -62, 0, 14),
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = theme.textMuted,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "lucide + solar ready",
        ZIndex = logoChip.ZIndex + 1,
        Parent = logoChip,
    })

    Accent.Changed:Connect(function(color)
        sidebarGlow.BackgroundColor3 = color
        logoBadge.BackgroundColor3 = color
    end)

    local sidebarLabel = NewInstance("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 76),
        Size = UDim2.new(1, -28, 0, 16),
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        TextColor3 = theme.textSoft,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "SECTIONS",
        ZIndex = sidebar.ZIndex + 1,
        Parent = sidebar,
    })

    local contentArea = NewInstance("Frame", {
        Name = "ContentArea",
        BackgroundColor3 = theme.surfaceAlt,
        BorderSizePixel = 0,
        Position = UDim2.new(0, sidebarWidth + 22, 0, 62),
        Size = UDim2.new(1, -(sidebarWidth + 36), 1, -76),
        ZIndex = inner.ZIndex + 1,
        Parent = inner,
    })
    NewInstance("UICorner", { CornerRadius = UDim.new(0, 18), Parent = contentArea })
    NewInstance("UIStroke", {
        Color = theme.borderSoft,
        Thickness = 1,
        Transparency = 0.1,
        Parent = contentArea,
    })

    local contentInner = NewInstance("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = contentArea.ZIndex + 1,
        Parent = contentArea,
    })

    local tabHeader = NewInstance("Frame", {
        Name = "TabHeader",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(16, 14),
        Size = UDim2.new(1, -32, 0, 48),
        ZIndex = contentInner.ZIndex + 1,
        Parent = contentInner,
    })

    local tabTitle = NewInstance("TextLabel", {
        Name = "TabTitle",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -140, 0, 22),
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextColor3 = theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "",
        ZIndex = tabHeader.ZIndex + 1,
        Parent = tabHeader,
    })

    local tabSubtitle = NewInstance("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 24),
        Size = UDim2.new(1, -140, 0, 16),
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = theme.textMuted,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "clean layout, preserved logic",
        ZIndex = tabHeader.ZIndex + 1,
        Parent = tabHeader,
    })

    local liveBadge = NewInstance("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(116, 28),
        BackgroundColor3 = theme.surfaceRaised,
        BorderSizePixel = 0,
        ZIndex = tabHeader.ZIndex + 1,
        Parent = tabHeader,
    })
    NewInstance("UICorner", { CornerRadius = UDim.new(0, 10), Parent = liveBadge })
    NewInstance("UIStroke", {
        Color = theme.borderSoft,
        Thickness = 1,
        Transparency = 0.12,
        Parent = liveBadge,
    })

    local liveDot = NewInstance("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromOffset(10, 14),
        Size = UDim2.fromOffset(7, 7),
        BackgroundColor3 = Accent.Value,
        BorderSizePixel = 0,
        ZIndex = liveBadge.ZIndex + 1,
        Parent = liveBadge,
    })
    NewInstance("UICorner", { CornerRadius = UDim.new(1, 0), Parent = liveDot })

    local liveText = NewInstance("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(24, 0),
        Size = UDim2.new(1, -24, 1, 0),
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = theme.textMuted,
        Text = "active panel",
        ZIndex = liveBadge.ZIndex + 1,
        Parent = liveBadge,
    })

    Accent.Changed:Connect(function(color)
        liveDot.BackgroundColor3 = color
    end)

    local scrollHolder = NewInstance("Frame", {
        Name = "ScrollHolder",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 72),
        Size = UDim2.new(1, -28, 1, -86),
        ZIndex = contentInner.ZIndex + 1,
        Parent = contentInner,
    })

    local tabsSidebarHolder = NewInstance("ScrollingFrame", {
        Name = "TabsHolder",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(10, 100),
        Size = UDim2.new(1, -20, 1, -112),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 0,
        ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
        ClipsDescendants = true,
        ZIndex = sidebar.ZIndex + 1,
        Parent = sidebar,
    })

    local tabsListLayout = NewInstance("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = tabsSidebarHolder,
    })

    tabsListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        tabsSidebarHolder.CanvasSize = UDim2.new(0, 0, 0, tabsListLayout.AbsoluteContentSize.Y + 8)
    end)

    local Factory = CreateElementFactory({
        ScreenGui = ScreenGui,
        Accent = Accent,
    })

    local Window = {}
    Window.Name = windowName
    Window.Instance = mainWindow
    Window.ScreenGui = ScreenGui
    Window.OpenButtonGui = OpenButtonGui
    Window.Accent = Accent
    Window.Icons = Icons

    local tabs = {}
    local tabButtons = {}
    local selectedTab = nil

    local function ApplyTabButtonVisual(name, active)
        local entry = tabButtons[name]
        if not entry then
            return
        end

        entry.Fill.BackgroundTransparency = active and 0.08 or 1
        entry.Fill.BackgroundColor3 = active and Accent.Value or theme.surfaceRaised
        entry.Stroke.Color = active and Accent.Value or theme.borderSoft
        entry.Stroke.Transparency = active and 0.02 or 0.18
        entry.Label.TextColor3 = active and theme.text or theme.textMuted
        entry.Meta.TextColor3 = active and Color3.fromRGB(206, 214, 240) or theme.textSoft
        entry.Indicator.BackgroundTransparency = active and 0 or 1
    end

    local function SelectTab(tabName)
        if not tabs[tabName] then
            return
        end
        selectedTab = tabName
        tabTitle.Text = tabName
        for name, tab in pairs(tabs) do
            tab.Instance.Visible = (name == tabName)
        end
        for name in pairs(tabButtons) do
            ApplyTabButtonVisual(name, name == tabName)
        end
        CloseAllOverlays()
    end

    Accent.Changed:Connect(function(color)
        mainStroke.Color = Color3.fromRGB(
            math.clamp(color.R * 255 * 0.45 + theme.border.R * 255 * 0.55, 0, 255),
            math.clamp(color.G * 255 * 0.45 + theme.border.G * 255 * 0.55, 0, 255),
            math.clamp(color.B * 255 * 0.45 + theme.border.B * 255 * 0.55, 0, 255)
        )
        brandDot.BackgroundColor3 = color
        for name in pairs(tabButtons) do
            ApplyTabButtonVisual(name, name == selectedTab)
        end
    end)

    function Window:AddTab(tabName)
        if tabs[tabName] then
            return tabs[tabName]
        end

        local isFirst = (next(tabs) == nil)
        local tab = CreateTab({
            Factory = Factory,
            ScrollHolder = scrollHolder,
        }, tabName, isFirst)
        tabs[tabName] = tab

        local index = 0
        for _ in pairs(tabButtons) do
            index = index + 1
        end

        local holder = NewInstance("Frame", {
            Name = "TabButton_" .. tabName,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 42),
            LayoutOrder = index,
            ZIndex = tabsSidebarHolder.ZIndex + 1,
            Parent = tabsSidebarHolder,
        })

        local fill = NewInstance("Frame", {
            BackgroundColor3 = theme.surfaceRaised,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            ZIndex = holder.ZIndex + 1,
            Parent = holder,
        })
        NewInstance("UICorner", { CornerRadius = UDim.new(0, 12), Parent = fill })

        local stroke = NewInstance("UIStroke", {
            Color = theme.borderSoft,
            Thickness = 1,
            Transparency = 0.18,
            Parent = fill,
        })

        local indicator = NewInstance("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.fromOffset(10, 21),
            Size = UDim2.fromOffset(4, 18),
            BackgroundColor3 = Accent.Value,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = fill.ZIndex + 1,
            Parent = fill,
        })
        NewInstance("UICorner", { CornerRadius = UDim.new(1, 0), Parent = indicator })

        local label = NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(24, 6),
            Size = UDim2.new(1, -30, 0, 16),
            Font = Enum.Font.GothamMedium,
            TextSize = 13,
            TextColor3 = theme.textMuted,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = tabName,
            ZIndex = fill.ZIndex + 1,
            Parent = fill,
        })

        local meta = NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(24, 21),
            Size = UDim2.new(1, -30, 0, 12),
            Font = Enum.Font.Gotham,
            TextSize = 10,
            TextColor3 = theme.textSoft,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = isFirst and "default view" or "panel",
            ZIndex = fill.ZIndex + 1,
            Parent = fill,
        })

        local btn = NewInstance("TextButton", {
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Text = "",
            Size = UDim2.fromScale(1, 1),
            ZIndex = fill.ZIndex + 2,
            Parent = holder,
        })

        btn.MouseButton1Click:Connect(function()
            SelectTab(tabName)
        end)

        tabButtons[tabName] = {
            Holder = holder,
            Fill = fill,
            Stroke = stroke,
            Indicator = indicator,
            Label = label,
            Meta = meta,
            Button = btn,
        }

        if isFirst then
            SelectTab(tabName)
        else
            ApplyTabButtonVisual(tabName, false)
        end

        return tab
    end

    function Window:SelectTab(tabName)
        SelectTab(tabName)
    end

    function Window:SetAccentColor(color3)
        Accent.Set(color3)
    end

    local menuOpen = false
    local animating = false

    local function ApplyOpenState(open)
        if not open then
            CloseAllOverlays()
        end

        local collapsedSize = UDim2.new(
            windowSize.X.Scale * 0.92,
            math.floor(windowSize.X.Offset * 0.92),
            windowSize.Y.Scale * 0.92,
            math.floor(windowSize.Y.Offset * 0.92)
        )

        if open then
            backdrop.Visible = true
            shadow.Visible = true
            mainWindow.Visible = true
            mainWindow.Size = collapsedSize
            shadow.Size = UDim2.new(collapsedSize.X.Scale, collapsedSize.X.Offset + 28, collapsedSize.Y.Scale, collapsedSize.Y.Offset + 28)
            mainWindow.BackgroundTransparency = 0.02
            backdrop.BackgroundTransparency = 1
            TweenService:Create(backdrop, TweenInfo.new(0.18), { BackgroundTransparency = 0.36 }):Play()
            TweenService:Create(mainWindow, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = windowSize }):Play()
            local shadowTween = TweenService:Create(shadow, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                Size = UDim2.new(windowSize.X.Scale, windowSize.X.Offset + 28, windowSize.Y.Scale, windowSize.Y.Offset + 28),
                BackgroundTransparency = 0.58,
            })
            shadowTween:Play()
            shadowTween.Completed:Connect(function()
                animating = false
            end)
        else
            local tween = TweenService:Create(mainWindow, TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
                Size = collapsedSize,
                BackgroundTransparency = 0.08,
            })
            local shadowTween = TweenService:Create(shadow, TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
                Size = UDim2.new(collapsedSize.X.Scale, collapsedSize.X.Offset + 28, collapsedSize.Y.Scale, collapsedSize.Y.Offset + 28),
                BackgroundTransparency = 0.82,
            })
            TweenService:Create(backdrop, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
            tween:Play()
            shadowTween:Play()
            tween.Completed:Connect(function()
                mainWindow.Visible = false
                shadow.Visible = false
                backdrop.Visible = false
                animating = false
            end)
        end
    end

    function Window:Toggle(open)
        if animating then
            return
        end
        if open == nil then
            open = not menuOpen
        end
        menuOpen = open
        animating = true
        ApplyOpenState(open)
    end

    backdrop.MouseButton1Click:Connect(function()
        if menuOpen and not animating then
            Window:Toggle(false)
        end
    end)

    local openButton = NewInstance("TextButton", {
        Name = "OpenMenuButton",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -22, 0.5, 0),
        Size = UDim2.fromOffset(76, 76),
        BackgroundColor3 = theme.surfaceAlt,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = Enum.Font.GothamBlack,
        TextSize = 24,
        Text = openButtonText,
        TextColor3 = theme.text,
        ZIndex = 500,
        Parent = OpenButtonGui,
    })
    NewInstance("UICorner", { CornerRadius = UDim.new(1, 0), Parent = openButton })

    local openButtonGlow = NewInstance("Frame", {
        Size = UDim2.new(1, 16, 1, 16),
        Position = UDim2.fromOffset(-8, -8),
        BackgroundColor3 = Accent.Value,
        BackgroundTransparency = 0.82,
        BorderSizePixel = 0,
        ZIndex = openButton.ZIndex - 1,
        Parent = openButton,
    })
    NewInstance("UICorner", { CornerRadius = UDim.new(1, 0), Parent = openButtonGlow })

    local openButtonStroke = NewInstance("UIStroke", {
        Color = Accent.Value,
        Thickness = 1.6,
        Transparency = 0.08,
        Parent = openButton,
    })

    local openButtonInner = NewInstance("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, -14, 1, -14),
        BackgroundColor3 = theme.surfaceRaised,
        BorderSizePixel = 0,
        ZIndex = openButton.ZIndex + 1,
        Parent = openButton,
    })
    NewInstance("UICorner", { CornerRadius = UDim.new(1, 0), Parent = openButtonInner })

    local openButtonLabel = NewInstance("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Font = Enum.Font.GothamBlack,
        TextSize = 24,
        Text = openButtonText,
        TextColor3 = theme.text,
        ZIndex = openButtonInner.ZIndex + 1,
        Parent = openButtonInner,
    })

    local openButtonMiniDot = NewInstance("Frame", {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -10, 1, -10),
        Size = UDim2.fromOffset(10, 10),
        BackgroundColor3 = Accent.Value,
        BorderSizePixel = 0,
        ZIndex = openButtonInner.ZIndex + 1,
        Parent = openButtonInner,
    })
    NewInstance("UICorner", { CornerRadius = UDim.new(1, 0), Parent = openButtonMiniDot })

    Accent.Changed:Connect(function(color)
        openButtonGlow.BackgroundColor3 = color
        openButtonStroke.Color = color
        openButtonMiniDot.BackgroundColor3 = color
    end)

    openButton.MouseButton1Click:Connect(function()
        if not openButton:GetAttribute("WasDragged") then
            Window:Toggle()
        end
    end)

    do
        local DRAG_THRESHOLD = 6
        local activeInput = nil
        local startInputPos = nil
        local startTargetPos = nil
        local moved = false

        openButton.InputBegan:Connect(function(input)
            if activeInput ~= nil then
                return
            end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                activeInput = input
                startInputPos = input.Position
                startTargetPos = openButton.Position
                moved = false
                openButton:SetAttribute("WasDragged", false)

                local connChanged
                local connEnded
                local function FinishDrag()
                    if connChanged then connChanged:Disconnect() end
                    if connEnded then connEnded:Disconnect() end
                    if activeInput == input then
                        activeInput = nil
                    end
                end
                connChanged = input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        FinishDrag()
                    end
                end)
                connEnded = UserInputService.InputEnded:Connect(function(endedInput)
                    if endedInput == input then
                        FinishDrag()
                    end
                end)
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if activeInput == nil then
                return
            end
            local isMouseMove = input.UserInputType == Enum.UserInputType.MouseMovement
                and activeInput.UserInputType == Enum.UserInputType.MouseButton1
            if input ~= activeInput and not isMouseMove then
                return
            end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            local delta = input.Position - startInputPos
            if not moved and delta.Magnitude > DRAG_THRESHOLD then
                moved = true
                openButton:SetAttribute("WasDragged", true)
            end
            if moved then
                openButton.Position = UDim2.new(
                    startTargetPos.X.Scale,
                    startTargetPos.X.Offset + delta.X,
                    startTargetPos.Y.Scale,
                    startTargetPos.Y.Offset + delta.Y
                )
                local cam = workspace.CurrentCamera
                if cam then
                    local vp = cam.ViewportSize
                    local absPos = openButton.AbsolutePosition
                    local absSize = openButton.AbsoluteSize
                    local cx = math.clamp(absPos.X, 0, math.max(0, vp.X - absSize.X))
                    local cy = math.clamp(absPos.Y, 0, math.max(0, vp.Y - absSize.Y))
                    if cx ~= absPos.X or cy ~= absPos.Y then
                        local p = openButton.Position
                        openButton.Position = UDim2.new(p.X.Scale, p.X.Offset + (cx - absPos.X), p.Y.Scale, p.Y.Offset + (cy - absPos.Y))
                    end
                end
            end
        end)
    end

    MakeDraggable(dragHandle, mainWindow, function()
        shadow.Position = mainWindow.Position
    end)

    mainWindow:GetPropertyChangedSignal("Position"):Connect(function()
        shadow.Position = mainWindow.Position
    end)

    local notifyHolder = NewInstance("Frame", {
        Name = "NotifyHolder",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -18, 1, -18),
        Size = UDim2.fromOffset(300, 520),
        ZIndex = 320,
        Parent = ScreenGui,
    })

    NewInstance("UIListLayout", {
        Padding = UDim.new(0, 10),
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = notifyHolder,
    })

    local floatingGuis = {}

    local function CreateFloatingButton(cfg, forceToggle)
        cfg = cfg or {}
        local isToggle = forceToggle == true or cfg.Toggle == true
        local minSize = cfg.MinSize or 40
        local maxSize = cfg.MaxSize or 200
        local size = math.clamp(cfg.Size or 92, minSize, maxSize)
        local radius = cfg.Radius or 18
        local threshold = cfg.DragThreshold or 10

        local state = cfg.Default == true

        local floatingGui = NewInstance("ScreenGui", {
            Name = "LurkFloating",
            ResetOnSpawn = false,
            IgnoreGuiInset = false,
            DisplayOrder = FLOATING_DISPLAY_ORDER,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        })
        SafeSetProperty(floatingGui, "OnTopOfCoreBlur", true)
        ProtectGui(floatingGui)
        floatingGui.Parent = GuiParent
        table.insert(floatingGuis, floatingGui)

        local btn = NewInstance("TextButton", {
            Name = "FloatingButton",
            Size = UDim2.fromOffset(size, size),
            Position = cfg.Position or UDim2.new(0.5, -size / 2, 0.6, 0),
            BackgroundColor3 = theme.surfaceAlt,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = cfg.Text or "",
            TextColor3 = theme.text,
            TextScaled = true,
            TextWrapped = true,
            Font = Enum.Font.GothamBold,
            Active = true,
            Selectable = true,
            ZIndex = 250,
            Parent = floatingGui,
        })
        NewInstance("UICorner", { CornerRadius = UDim.new(0, radius), Parent = btn })

        local inner = NewInstance("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(1, -12, 1, -12),
            BackgroundColor3 = theme.surfaceRaised,
            BorderSizePixel = 0,
            ZIndex = btn.ZIndex + 1,
            Parent = btn,
        })
        NewInstance("UICorner", { CornerRadius = UDim.new(0, math.max(8, radius - 6)), Parent = inner })

        local label = NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Font = Enum.Font.GothamBold,
            TextScaled = true,
            TextWrapped = true,
            Text = cfg.Text or "",
            TextColor3 = theme.text,
            ZIndex = inner.ZIndex + 1,
            Parent = inner,
        })
        NewInstance("UITextSizeConstraint", { MaxTextSize = 20, MinTextSize = 8, Parent = label })

        local stroke = NewInstance("UIStroke", {
            Thickness = 1.5,
            Color = Accent.Value,
            Transparency = 0.25,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Parent = btn,
        })

        local accentDot = NewInstance("Frame", {
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -8, 1, -8),
            Size = UDim2.fromOffset(9, 9),
            BackgroundColor3 = Accent.Value,
            BorderSizePixel = 0,
            ZIndex = inner.ZIndex + 1,
            Parent = inner,
        })
        NewInstance("UICorner", { CornerRadius = UDim.new(1, 0), Parent = accentDot })

        local handle = {}
        handle.Gui = floatingGui
        handle.Button = btn
        handle.Stroke = stroke

        local function ClampButton()
            local cam = workspace.CurrentCamera
            if not cam then return end
            local vp = cam.ViewportSize
            local absSize = btn.AbsoluteSize
            local sizeX = absSize.X > 0 and absSize.X or btn.Size.X.Offset
            local sizeY = absSize.Y > 0 and absSize.Y or btn.Size.Y.Offset
            local p = btn.Position
            local absX = p.X.Scale * vp.X + p.X.Offset
            local absY = p.Y.Scale * vp.Y + p.Y.Offset
            local maxX = math.max(0, vp.X - sizeX)
            local maxY = math.max(0, vp.Y - sizeY)
            local cx = math.clamp(absX, 0, maxX)
            local cy = math.clamp(absY, 0, maxY)
            if cx ~= absX or cy ~= absY then
                btn.Position = UDim2.new(p.X.Scale, p.X.Offset + (cx - absX), p.Y.Scale, p.Y.Offset + (cy - absY))
            end
        end
        handle.Clamp = ClampButton
        task.defer(ClampButton)
        if workspace.CurrentCamera then
            workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
                task.defer(ClampButton)
            end)
        end
        floatingGui:GetPropertyChangedSignal("Enabled"):Connect(function()
            if floatingGui.Enabled then
                task.defer(ClampButton)
                task.delay(0.05, ClampButton)
            end
        end)
        btn:GetPropertyChangedSignal("AbsolutePosition"):Connect(ClampButton)
        btn:GetPropertyChangedSignal("AbsoluteSize"):Connect(ClampButton)

        local baseText = cfg.Text or ""
        local function applyVisual()
            accentDot.BackgroundColor3 = Accent.Value
            if isToggle and state then
                btn.BackgroundColor3 = Accent.Value
                inner.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                label.TextColor3 = Color3.fromRGB(26, 28, 36)
                stroke.Color = Accent.Value
                stroke.Transparency = 0
                accentDot.BackgroundColor3 = Color3.fromRGB(26, 28, 36)
                label.Text = cfg.OnText or baseText
            else
                btn.BackgroundColor3 = theme.surfaceAlt
                inner.BackgroundColor3 = theme.surfaceRaised
                label.TextColor3 = theme.text
                stroke.Color = Accent.Value
                stroke.Transparency = 0.25
                if isToggle then label.Text = cfg.OffText or baseText end
            end
        end

        applyVisual()
        Accent.Changed:Connect(applyVisual)

        local activeInput = nil
        local moved = false
        local finished = false
        local startInputPos, startBtnPos

        local function DoActivate()
            if isToggle then
                state = not state
                applyVisual()
                if cfg.Callback then
                    local s = state
                    task.spawn(function() cfg.Callback(s) end)
                end
            else
                if cfg.Callback then task.spawn(cfg.Callback) end
            end
        end

        local function UpdateDrag(pos)
            if activeInput == nil then return end
            local delta = pos - startInputPos
            if not moved and delta.Magnitude > threshold then moved = true end
            if moved then
                btn.Position = UDim2.new(
                    startBtnPos.X.Scale,
                    startBtnPos.X.Offset + delta.X,
                    startBtnPos.Y.Scale,
                    startBtnPos.Y.Offset + delta.Y
                )
                ClampButton()
            end
        end

        local function EndGesture()
            if activeInput == nil or finished then return end
            finished = true
            local didMove = moved
            activeInput = nil
            if not didMove then
                DoActivate()
            end
        end

        local function IsSameInput(input)
            if input == activeInput then return true end
            if activeInput ~= nil
                and activeInput.UserInputType == Enum.UserInputType.MouseButton1
                and input.UserInputType == Enum.UserInputType.MouseMovement then
                return true
            end
            return false
        end

        btn.InputBegan:Connect(function(input)
            if activeInput ~= nil then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                activeInput = input
                moved = false
                finished = false
                startInputPos = input.Position
                startBtnPos = btn.Position

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
            if IsSameInput(input) then
                UpdateDrag(input.Position)
            end
        end)

        btn.InputEnded:Connect(function(input)
            if activeInput == nil then return end
            if input == activeInput
                or (activeInput.UserInputType == Enum.UserInputType.MouseButton1
                    and input.UserInputType == Enum.UserInputType.MouseButton1) then
                EndGesture()
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if activeInput == nil then return end
            if input == activeInput
                or (activeInput.UserInputType == Enum.UserInputType.MouseButton1
                    and input.UserInputType == Enum.UserInputType.MouseButton1)
                or (activeInput.UserInputType == Enum.UserInputType.Touch
                    and input.UserInputType == Enum.UserInputType.Touch
                    and input == activeInput) then
                EndGesture()
            end
        end)

        function handle:SetSize(px)
            size = math.clamp(px, minSize, maxSize)
            btn.Size = UDim2.fromOffset(size, size)
            task.defer(ClampButton)
            return size
        end

        function handle:GetSize()
            return size
        end

        function handle:SetText(text)
            label.Text = text or ""
            if not isToggle then
                baseText = text or ""
            end
        end

        function handle:SetActive(value, silent)
            if not isToggle then return end
            local newState = value == true
            local changed = newState ~= state
            state = newState
            applyVisual()
            if changed and not silent and cfg.Callback then
                local s = state
                task.spawn(function() cfg.Callback(s) end)
            end
        end

        function handle:Toggle()
            if not isToggle then return end
            self:SetActive(not state)
        end

        function handle:GetState()
            return state
        end

        function handle:SetVisible(value)
            floatingGui.Enabled = value ~= false
        end

        function handle:SetPosition(udim2)
            btn.Position = udim2
        end

        function handle:Destroy()
            floatingGui:Destroy()
        end

        function handle:AddSizeSlider(tab, sc)
            sc = sc or {}
            return tab:AddSlider({
                Name = sc.Name or "Button Size",
                Min = sc.Min or minSize,
                Max = sc.Max or maxSize,
                Default = sc.Default or size,
                Step = sc.Step or 5,
                Callback = function(v)
                    handle:SetSize(v)
                    if sc.Callback then sc.Callback(v) end
                end,
            })
        end

        return handle
    end

    function Window:AddFloatingButton(cfg)
        return CreateFloatingButton(cfg, false)
    end

    function Window:AddFloatingToggle(cfg)
        return CreateFloatingButton(cfg, true)
    end

    function Window:Notify(cfg)
        cfg = cfg or {}
        local title = cfg.Title or "Notification"
        local content = cfg.Content or ""
        local duration = cfg.Duration or 4

        local card = NewInstance("Frame", {
            BackgroundColor3 = theme.surfaceAlt,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            ZIndex = notifyHolder.ZIndex + 1,
            Parent = notifyHolder,
        })
        NewInstance("UICorner", { CornerRadius = UDim.new(0, 14), Parent = card })

        local cardStroke = NewInstance("UIStroke", {
            Color = theme.border,
            Thickness = 1,
            Transparency = 1,
            Parent = card,
        })

        NewInstance("UIPadding", {
            PaddingTop = UDim.new(0, 10),
            PaddingBottom = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 12),
            PaddingRight = UDim.new(0, 12),
            Parent = card,
        })

        NewInstance("UIListLayout", {
            Padding = UDim.new(0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = card,
        })

        local titleRow = NewInstance("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 16),
            Parent = card,
        })

        local accentBar = NewInstance("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.fromOffset(0, 8),
            Size = UDim2.fromOffset(4, 14),
            BackgroundColor3 = Accent.Value,
            BorderSizePixel = 0,
            ZIndex = card.ZIndex + 1,
            Parent = titleRow,
        })
        NewInstance("UICorner", { CornerRadius = UDim.new(1, 0), Parent = accentBar })

        local titleLabel = NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(12, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(1, -12, 0, 0),
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            TextColor3 = theme.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            Text = title,
            TextTransparency = 1,
            ZIndex = card.ZIndex + 1,
            Parent = titleRow,
        })

        local bodyLabel = NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(1, 0, 0, 0),
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextColor3 = theme.textMuted,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            Text = content,
            TextTransparency = 1,
            ZIndex = card.ZIndex + 1,
            Parent = card,
        })

        Accent.Changed:Connect(function(color)
            accentBar.BackgroundColor3 = color
        end)

        TweenService:Create(card, TweenInfo.new(0.2), { BackgroundTransparency = 0 }):Play()
        TweenService:Create(cardStroke, TweenInfo.new(0.2), { Transparency = 0.2 }):Play()
        TweenService:Create(titleLabel, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
        TweenService:Create(bodyLabel, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()

        task.delay(duration, function()
            TweenService:Create(card, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
            TweenService:Create(cardStroke, TweenInfo.new(0.25), { Transparency = 1 }):Play()
            TweenService:Create(titleLabel, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
            local fade = TweenService:Create(bodyLabel, TweenInfo.new(0.25), { TextTransparency = 1 })
            fade:Play()
            fade.Completed:Connect(function()
                card:Destroy()
            end)
        end)

        return card
    end

    function Window:Destroy()
        for _, gui in ipairs(floatingGuis) do
            pcall(function()
                gui:Destroy()
            end)
        end
        table.clear(floatingGuis)
        pcall(function()
            Accent._bindable:Destroy()
        end)
        OpenButtonGui:Destroy()
        ScreenGui:Destroy()
    end

    return Window
end

local Lurk = {}
Lurk.Icons = Icons

function Lurk:CreateWindow(config)
    return CreateWindow(config)
end

return Lurk
