local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- Alice/Everness "Solid" palette from themes/themes.cpp. Text is precomposed
-- against the 12,12,12 background; only the large surfaces keep a very light
-- transparency so the interface still feels integrated with the game.
local Theme = {
    Accent = Color3.fromRGB(120, 255, 100),
    Window = Color3.fromRGB(12, 12, 12),
    Settings = Color3.fromRGB(8, 8, 8),
    Element = Color3.fromRGB(14, 14, 14),
    ElementHover = Color3.fromRGB(16, 16, 16),
    ElementActive = Color3.fromRGB(18, 18, 18),
    Popup = Color3.fromRGB(14, 14, 14),
    Outline = Color3.fromRGB(20, 20, 20),
    Border = Color3.fromRGB(25, 25, 25),
    Text = Color3.fromRGB(203, 203, 203),
    TextBright = Color3.fromRGB(255, 255, 255),
    TextDim = Color3.fromRGB(155, 155, 155),
    TextUnsafe = Color3.fromRGB(255, 199, 56),
    Slider = Color3.fromRGB(0, 0, 0),
    WindowRounding = 12,
    PopupRounding = 16,
    ElementRounding = 12,
    WindowTransparency = 15 / 255,
    PopupTransparency = 10 / 255,
}

local DEFAULT_ICON_URL = "https://raw.githubusercontent.com/AWLOID/Obscura/refs/heads/main/icons.lua"
local IconAtlasCache = {}
local IconDescriptorCache = setmetatable({}, { __mode = "k" })

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

    if className == "UIStroke" and (not properties or properties.ApplyStrokeMode == nil) then
        inst.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    end

    -- Give every standalone control row the same solid surface used by
    -- Alice/Everness elements. Containers and popup holders stay transparent.
    if className == "Frame" or className == "CanvasGroup" then
        local name = tostring(inst.Name)
        local isElementRow = string.match(name, "^Dropdown_")
            or string.match(name, "^MultiDropdown_")
            or string.match(name, "^ColorPicker_")
            or string.match(name, "^Textbox_")
            or string.match(name, "^Keybind_")
            or string.match(name, "^Checkbox_")
            or string.match(name, "^Switch_")
            or string.match(name, "^Stepper_")
            or string.match(name, "^RangeSlider_")
            or string.match(name, "^ToggleSlider_")
            or string.match(name, "^SearchableDropdown_")
            or string.match(name, "^Input_")
        if isElementRow and properties and properties.BackgroundTransparency == 1 then
            inst.BackgroundColor3 = Theme.Element
            inst.BackgroundTransparency = 0
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, Theme.ElementRounding)
            corner.Parent = inst
        end

        local isPopupHolder = string.match(name, "^DropdownOptionsHolder_")
            or string.match(name, "^MultiDropdownOptionsHolder_")
            or string.match(name, "^SearchableDropdownHolder_")
        if isPopupHolder then
            inst.BackgroundTransparency = Theme.PopupTransparency
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, Theme.PopupRounding)
            corner.Parent = inst
        end
    end
    return inst
end

local function NormalizeIconName(name)
    if type(name) ~= "string" then return nil end
    name = string.lower(string.match(name, "^%s*(.-)%s*$") or name)
    name = string.gsub(name, "[_%s]+", "-")
    return string.gsub(name, "%-+", "-")
end

local function LoadIconAtlas(source)
    if type(source) == "table" then return source end
    local url = type(source) == "string" and source or DEFAULT_ICON_URL
    if IconAtlasCache[url] then return IconAtlasCache[url] end
    local ok, atlas = pcall(function()
        local sourceCode = game:HttpGet(url)
        assert(type(sourceCode) == "string" and #sourceCode > 0 and #sourceCode <= 2097152, "invalid icon atlas")
        local compiler = loadstring
        assert(type(compiler) == "function", "loadstring is unavailable")
        local chunk = assert(compiler(sourceCode), "icon atlas compilation failed")
        return chunk()
    end)
    if not ok or type(atlas) ~= "table"
        or type(atlas["48px"]) ~= "table" and type(atlas["256px"]) ~= "table" then
        return nil
    end
    IconAtlasCache[url] = atlas
    return atlas
end

local function ResolveIcon(atlas, name, sheetName)
    name = NormalizeIconName(name)
    if not atlas or not name then return nil end
    local sheetKey = (sheetName == 256 or sheetName == "256px") and "256px" or "48px"
    local atlasCache = IconDescriptorCache[atlas]
    if not atlasCache then atlasCache = {}; IconDescriptorCache[atlas] = atlasCache end
    local cacheKey = sheetKey .. "\0" .. name
    if atlasCache[cacheKey] ~= nil then return atlasCache[cacheKey] or nil end
    local sheet = atlas[sheetKey]
    local data = sheet and sheet[name]
    if type(data) ~= "table" or type(data[1]) ~= "number"
        or type(data[2]) ~= "table" or type(data[3]) ~= "table" then
        atlasCache[cacheKey] = false
        return nil
    end
    local descriptor = {
        Name = name,
        Sheet = sheetKey,
        Image = "rbxassetid://" .. tostring(data[1]),
        Size = Vector2.new(data[2][1], data[2][2]),
        Offset = Vector2.new(data[3][1], data[3][2]),
    }
    atlasCache[cacheKey] = descriptor
    return descriptor
end

local function CreateAtlasIcon(atlas, parent, name, config)
    config = config or {}
    local descriptor = ResolveIcon(atlas, name, config.Sheet)
    if not descriptor then return nil end
    local pixels = tonumber(config.Pixels) or 16
    local parentZIndex = 1
    if typeof(parent) == "Instance" and parent:IsA("GuiObject") then
        parentZIndex = parent.ZIndex
    end
    local icon = NewInstance(config.Button and "ImageButton" or "ImageLabel", {
        Name = config.Name or ("Icon_" .. descriptor.Name),
        AnchorPoint = config.AnchorPoint or Vector2.new(0, 0.5),
        Position = config.Position or UDim2.new(0, 0, 0.5, 0),
        Size = config.Size or UDim2.fromOffset(pixels, pixels),
        BackgroundTransparency = 1,
        Image = descriptor.Image,
        ImageRectSize = descriptor.Size,
        ImageRectOffset = descriptor.Offset,
        ImageColor3 = config.Color or Theme.Text,
        ImageTransparency = config.Transparency or 0,
        ScaleType = Enum.ScaleType.Fit,
        Rotation = config.Rotation or 0,
        ZIndex = config.ZIndex or (parentZIndex + 1),
        Parent = parent,
    })
    if config.Button then icon.AutoButtonColor = false end
    icon:SetAttribute("LucideIcon", descriptor.Name)
    icon:SetAttribute("LucideSheet", descriptor.Sheet)
    return icon
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

local ActivePointerDrags = {}

local function RegisterPointerDrag(token, hitTargets, cancel)
    ActivePointerDrags[token] = {
        HitTargets = hitTargets,
        Cancel = cancel,
    }
end

local function UnregisterPointerDrag(token)
    ActivePointerDrags[token] = nil
end

local function CancelPointerDragsInside(root)
    local pending = {}
    for _, drag in pairs(ActivePointerDrags) do
        for _, hitTarget in ipairs(drag.HitTargets) do
            if hitTarget == root or hitTarget.Parent and hitTarget:IsDescendantOf(root) then
                table.insert(pending, drag.Cancel)
                break
            end
        end
    end
    for _, cancel in ipairs(pending) do
        pcall(cancel)
    end
end

local function MakeDraggable(handle, target, onDragStart)
    local activeInput = nil
    local startInputPos = nil
    local startTargetPos = nil
    local persistentConnections = {}
    local transientChanged = nil
    local transientEnded = nil
    local disconnected = false
    local dragToken = {}

    local function FinishDrag()
        if transientChanged then transientChanged:Disconnect(); transientChanged = nil end
        if transientEnded then transientEnded:Disconnect(); transientEnded = nil end
        activeInput = nil
        UnregisterPointerDrag(dragToken)
    end

    local function BeginDrag(input)
        if disconnected or activeInput ~= nil then
            return
        end
        activeInput = input
        startInputPos = input.Position
        startTargetPos = target.Position
        RegisterPointerDrag(dragToken, { handle, target }, FinishDrag)
        if onDragStart then
            onDragStart()
        end
        if activeInput ~= input then return end

        transientChanged = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                if activeInput == input then FinishDrag() end
            end
        end)

        transientEnded = UserInputService.InputEnded:Connect(function(endedInput)
            if endedInput == input then
                FinishDrag()
            end
        end)
    end

    table.insert(persistentConnections, handle.InputBegan:Connect(function(input)
        if not handle.Interactable then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            BeginDrag(input)
        end
    end))

    table.insert(persistentConnections, UserInputService.InputChanged:Connect(function(input)
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
    end))

    local cleanup = {}
    function cleanup:Disconnect()
        if disconnected then return end
        disconnected = true
        FinishDrag()
        for _, connection in ipairs(persistentConnections) do connection:Disconnect() end
        table.clear(persistentConnections)
    end
    return cleanup
end

local function MakeValueDragger(hitTargets, onInputDown, onInputMove)
    local activeInput = nil
    local persistentConnections = {}
    local transientChanged = nil
    local transientEnded = nil
    local disconnected = false
    local dragToken = {}

    local function FinishDrag()
        if transientChanged then transientChanged:Disconnect(); transientChanged = nil end
        if transientEnded then transientEnded:Disconnect(); transientEnded = nil end
        activeInput = nil
        UnregisterPointerDrag(dragToken)
    end

    local function Bind(obj)
        table.insert(persistentConnections, obj.InputBegan:Connect(function(input)
            if not obj.Interactable then return end
            if disconnected or activeInput ~= nil then
                return
            end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                activeInput = input
                RegisterPointerDrag(dragToken, hitTargets, FinishDrag)
                onInputDown(input)
                if activeInput ~= input then return end

                transientChanged = input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        if activeInput == input then FinishDrag() end
                    end
                end)
                transientEnded = UserInputService.InputEnded:Connect(function(endedInput)
                    if endedInput == input then
                        FinishDrag()
                    end
                end)
            end
        end))
    end

    for _, obj in ipairs(hitTargets) do
        Bind(obj)
    end

    table.insert(persistentConnections, UserInputService.InputChanged:Connect(function(input)
        if activeInput == nil then
            return
        end
        local isMatch = (input == activeInput)
            or (input.UserInputType == Enum.UserInputType.MouseMovement and activeInput.UserInputType == Enum.UserInputType.MouseButton1)
        if not isMatch then
            return
        end
        onInputMove(input)
    end))

    local cleanup = {}
    function cleanup:Disconnect()
        if disconnected then return end
        disconnected = true
        FinishDrag()
        for _, connection in ipairs(persistentConnections) do connection:Disconnect() end
        table.clear(persistentConnections)
    end
    for _, obj in ipairs(hitTargets) do
        table.insert(persistentConnections, obj.Destroying:Connect(function()
            cleanup:Disconnect()
        end))
    end
    return cleanup
end

local ActiveKeybindCancel = nil
local ActiveKeybindTarget = nil

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

-- GuiObject.Interactable is not inherited by every descendant. Keep a
-- reference-counted lock per subtree so no button, field, slider hit-area or
-- drag handle stays live during a fade, even when several locks overlap.
local InteractionLocks = setmetatable({}, { __mode = "k" })
local InteractionStates = setmetatable({}, { __mode = "k" })

local function IsInteractiveControl(gui)
    return gui:IsA("GuiObject")
end

local function SetTreeInteractable(root, enabled)
    if not root then return end

    local lock = InteractionLocks[root]
    if not enabled then
        CancelPointerDragsInside(root)
        if ActiveKeybindCancel and ActiveKeybindTarget
            and (ActiveKeybindTarget == root or ActiveKeybindTarget:IsDescendantOf(root)) then
            ActiveKeybindCancel()
        end
        if lock then
            if not IsInteractiveControl(root) then root.Interactable = false end
            return
        end

        lock = {
            Objects = setmetatable({}, { __mode = "k" }),
            Connection = nil,
        }
        InteractionLocks[root] = lock

        local function LockControl(gui)
            if not IsInteractiveControl(gui) or lock.Objects[gui] then return end
            local state = InteractionStates[gui]
            if not state then
                state = { Count = 0, Original = gui.Interactable }
                InteractionStates[gui] = state
            end
            state.Count = state.Count + 1
            lock.Objects[gui] = true
            if gui:IsA("TextBox") and gui:IsFocused() then
                gui:ReleaseFocus(false)
            end
            gui.Interactable = false
        end

        LockControl(root)
        for _, descendant in ipairs(root:GetDescendants()) do
            LockControl(descendant)
        end
        lock.Connection = root.DescendantAdded:Connect(LockControl)

        if not IsInteractiveControl(root) then root.Interactable = false end
        return
    end

    if lock then
        if lock.Connection then lock.Connection:Disconnect() end
        for gui in pairs(lock.Objects) do
            local state = InteractionStates[gui]
            if state then
                state.Count = state.Count - 1
                if state.Count <= 0 then
                    if gui.Parent then gui.Interactable = state.Original end
                    InteractionStates[gui] = nil
                elseif gui.Parent then
                    gui.Interactable = false
                end
            end
        end
        InteractionLocks[root] = nil
    end

    if IsInteractiveControl(root) then
        local state = InteractionStates[root]
        if state then
            -- The subtree was explicitly reopened while an ancestor is still
            -- locked. Remember the desired state without defeating that lock.
            state.Original = true
            if root.Parent then root.Interactable = false end
        elseif root.Parent then
            root.Interactable = true
        end
    elseif root.Parent then
        root.Interactable = true
    end
end

local PopupAnimationState = setmetatable({}, { __mode = "k" })

local function AnimatePopup(holder, open)
    if not holder or not holder.Parent then return end
    if not holder:IsA("CanvasGroup") then
        SetTreeInteractable(holder, open)
        holder.Visible = open
        return
    end

    local state = PopupAnimationState[holder]
    if not state then
        state = { Token = 0, Tween = nil, Open = false }
        PopupAnimationState[holder] = state
    end
    state.Token = state.Token + 1
    state.Open = open
    local token = state.Token
    if state.Tween then state.Tween:Cancel() end

    if open then
        if not holder.Visible then holder.GroupTransparency = 1 end
        holder.Visible = true
        SetTreeInteractable(holder, true)
    elseif not holder.Visible then
        holder.GroupTransparency = 1
        SetTreeInteractable(holder, false)
        return
    else
        SetTreeInteractable(holder, false)
    end

    state.Tween = TweenService:Create(
        holder,
        TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { GroupTransparency = open and 0 or 1 }
    )
    state.Tween:Play()
    if not open then
        state.Tween.Completed:Connect(function()
            if holder.Parent and state.Token == token and not state.Open then
                holder.Visible = false
            end
        end)
    end
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
    local CreateIcon = context.CreateIcon

    local Factory = {}

    function Factory.Label(parent, text)
        return NewInstance("TextLabel", {
            Name = "Label_" .. text,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 20),
            Font = Enum.Font.GothamMedium,
            TextSize = 14,
            TextColor3 = Theme.TextDim,
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
                TextColor3 = Theme.Text,
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
            TextColor3 = Theme.TextDim,
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
            TextColor3 = Theme.TextDim,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = string.upper(text or ""),
            Parent = row,
        })

        local line = NewInstance("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.new(1, -68, 0, 1),
            BackgroundColor3 = Theme.Outline,
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
            BackgroundColor3 = Theme.Element,
            BorderSizePixel = 0,
            LayoutOrder = 1,
            Size = UDim2.new(1, 0, 0, 34),
            Parent = container,
        })

        NewInstance("UICorner", {
            CornerRadius = UDim.new(0, Theme.ElementRounding),
            Parent = row,
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
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(1, -64, 1, 0),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            Parent = row,
        })

        local box = NewInstance("TextButton", {
            Name = "Box",
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.fromOffset(28, 16),
            BackgroundColor3 = Theme.ElementHover,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            Parent = row,
        })

        NewInstance("UICorner", {
            CornerRadius = UDim.new(1, 0),
            Parent = box,
        })

        local boxStroke = NewInstance("UIStroke", {
            Color = Theme.Outline,
            Transparency = 0,
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

        NewInstance("UICorner", {
            CornerRadius = UDim.new(1, 0),
            Parent = fill,
        })

        local knob = NewInstance("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = default and UDim2.new(1, -8, 0.5, 0) or UDim2.fromOffset(8, 8),
            Size = UDim2.fromOffset(8, 8),
            BackgroundColor3 = Theme.TextBright,
            BorderSizePixel = 0,
            ZIndex = fill.ZIndex + 1,
            Parent = box,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })

        local state = default

        local function ApplyVisual(animated)
            local goal = { BackgroundTransparency = state and 0 or 1 }
            local knobGoal = { Position = state and UDim2.new(1, -8, 0.5, 0) or UDim2.fromOffset(8, 8) }
            if animated then
                TweenService:Create(fill, TweenInfo.new(0.15), goal):Play()
                TweenService:Create(knob, TweenInfo.new(0.15), knobGoal):Play()
            else
                fill.BackgroundTransparency = goal.BackgroundTransparency
                knob.Position = knobGoal.Position
            end
        end

        Accent.Changed:Connect(function(color)
            fill.BackgroundColor3 = color
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
            BackgroundColor3 = Theme.Element,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 42),
            Parent = parent,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, Theme.ElementRounding), Parent = row })

        local label = NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(12, 2),
            Size = UDim2.new(1, -24, 0, 18),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name .. ": " .. tostring(default),
            Parent = row,
        })

        local track = NewInstance("Frame", {
            Position = UDim2.fromOffset(12, 27),
            Size = UDim2.new(1, -24, 0, 6),
            BackgroundColor3 = Theme.Slider,
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
            Size = UDim2.fromOffset(10, 10),
            BackgroundColor3 = Theme.TextBright,
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
            BackgroundColor3 = Theme.Element,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = Enum.Font.GothamMedium,
            TextSize = 14,
            TextColor3 = Theme.Text,
            Text = name,
            TextXAlignment = config.Icon and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center,
            Parent = parent,
        })

        NewInstance("UIStroke", {
            Color = Theme.Outline,
            Thickness = 1,
            Parent = btn,
        })

        NewInstance("UICorner", {
            CornerRadius = UDim.new(0, Theme.ElementRounding),
            Parent = btn,
        })

        local buttonIcon = nil
        if config.Icon and CreateIcon then
            buttonIcon = CreateIcon(btn, config.Icon, {
                Pixels = 14,
                Position = UDim2.new(0, -23, 0.5, 0),
                Color = Theme.Text,
                ZIndex = btn.ZIndex + 1,
            })
            if not buttonIcon then
                btn.TextXAlignment = Enum.TextXAlignment.Center
            end
        end

        local buttonPadding = NewInstance("UIPadding", {
            PaddingLeft = UDim.new(0, buttonIcon and 34 or 12),
            PaddingRight = UDim.new(0, 12),
            Parent = btn,
        })

        btn.MouseButton1Click:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.08), { BackgroundColor3 = Accent.Value }):Play()
            task.delay(0.12, function()
                TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Theme.Element }):Play()
            end)
            if callback then
                callback()
            end
        end)

        local api = {}
        function api.SetText(text)
            btn.Text = text
        end
        function api.SetIcon(iconName)
            if buttonIcon then buttonIcon:Destroy(); buttonIcon = nil end
            if iconName and CreateIcon then
                buttonIcon = CreateIcon(btn, iconName, {
                    Pixels = 14,
                    Position = UDim2.new(0, -23, 0.5, 0),
                    Color = Theme.Text,
                    ZIndex = btn.ZIndex + 1,
                })
            end
            btn.TextXAlignment = buttonIcon and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
            buttonPadding.PaddingLeft = UDim.new(0, buttonIcon and 34 or 12)
            api.Icon = buttonIcon
            return buttonIcon
        end
        api.Icon = buttonIcon
        api.Instance = btn
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
            BackgroundColor3 = Theme.Element,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 36),
            Parent = parent,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, Theme.ElementRounding), Parent = row })

        local label = NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(1, -24, 0, 16),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            Parent = row,
        })

        local track = NewInstance("Frame", {
            Position = UDim2.fromOffset(12, 20),
            Size = UDim2.new(1, -24, 0, 8),
            BackgroundColor3 = Theme.Element,
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
            BackgroundColor3 = Theme.Element,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            Size = UDim2.new(1, 0, 0, height),
            Parent = parent,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, Theme.ElementRounding), Parent = holder })

        NewInstance("UIStroke", {
            Color = Theme.Outline,
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
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(1, -24, 0, 16),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            Parent = row,
        })

        local box = NewInstance("TextButton", {
            Name = "Box",
            Position = UDim2.fromOffset(12, 20),
            Size = UDim2.new(1, -24, 0, 28),
            BackgroundColor3 = Theme.Element,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "  " .. tostring(default or ""),
            Parent = row,
        })

        local boxStroke = NewInstance("UIStroke", {
            Color = Theme.Outline,
            Thickness = 1,
            Parent = box,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 8), Parent = box })

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

        local arrowIcon = nil
        if CreateIcon then
            arrowIcon = CreateIcon(box, "chevron-down", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(1, -18, 0.5, 0),
                Pixels = 15,
                Color = Accent.Value,
                ZIndex = box.ZIndex + 1,
            })
            if arrowIcon then arrow.Text = "" end
        end

        local isOpen = false

        Accent.Changed:Connect(function(color)
            arrow.TextColor3 = color
            if arrowIcon then arrowIcon.ImageColor3 = color end
            if isOpen then
                boxStroke.Color = color
            end
        end)

        local optionsHolder = NewInstance("CanvasGroup", {
            Name = "DropdownOptionsHolder_" .. name,
            BackgroundColor3 = Theme.Popup,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(0, 28),
            Visible = false,
            GroupTransparency = 1,
            ClipsDescendants = true,
            ZIndex = 200,
            Parent = ScreenGui,
        })

        NewInstance("UIStroke", {
            Color = Theme.Outline,
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
            ScrollBarImageColor3 = Theme.TextDim,
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
                    btn.BackgroundColor3 = Theme.ElementHover
                    btn.TextColor3 = Accent.Value
                else
                    btn.BackgroundColor3 = Theme.Popup
                    btn.TextColor3 = Theme.Text
                end
            end
        end

        local function Close()
            isOpen = false
            AnimatePopup(optionsHolder, false)
            boxStroke.Color = Theme.Outline
            if arrowIcon then
                TweenService:Create(arrowIcon, TweenInfo.new(0.12), { Rotation = 0 }):Play()
            else
                arrow.Text = "\u{25BC}"
            end
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
                    BackgroundColor3 = Theme.Popup,
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                    Size = UDim2.new(1, 0, 0, 28),
                    Font = Enum.Font.Gotham,
                    TextSize = 13,
                    TextColor3 = Theme.Text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Text = "   " .. tostring(opt),
                    LayoutOrder = index,
                    ZIndex = scroll.ZIndex + 1,
                    Parent = scroll,
                })

                optionButtons[opt] = optBtn

                optBtn.MouseEnter:Connect(function()
                    if opt ~= currentValue then
                        TweenService:Create(optBtn, TweenInfo.new(0.1), { BackgroundColor3 = Theme.ElementActive }):Play()
                    end
                end)
                optBtn.MouseLeave:Connect(function()
                    if opt ~= currentValue then
                        TweenService:Create(optBtn, TweenInfo.new(0.1), { BackgroundColor3 = Theme.Popup }):Play()
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
            isOpen = true
            AnimatePopup(optionsHolder, true)
            boxStroke.Color = Accent.Value
            if arrowIcon then
                TweenService:Create(arrowIcon, TweenInfo.new(0.12), { Rotation = 180 }):Play()
            else
                arrow.Text = "\u{25B2}"
            end
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
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(1, -24, 0, 16),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            Parent = row,
        })

        local box = NewInstance("TextButton", {
            Name = "Box",
            Position = UDim2.fromOffset(12, 20),
            Size = UDim2.new(1, -24, 0, 24),
            BackgroundColor3 = Theme.Element,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "",
            Parent = row,
        })

        NewInstance("UIStroke", {
            Color = Theme.Outline,
            Thickness = 1,
            Parent = box,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 8), Parent = box })

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

        local arrowIcon = nil
        if CreateIcon then
            arrowIcon = CreateIcon(box, "chevron-down", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(1, -16, 0.5, 0),
                Pixels = 15,
                Color = Accent.Value,
                ZIndex = box.ZIndex + 1,
            })
            if arrowIcon then arrow.Text = "" end
        end

        Accent.Changed:Connect(function(color)
            arrow.TextColor3 = color
            if arrowIcon then arrowIcon.ImageColor3 = color end
        end)

        local optionsHolder = NewInstance("CanvasGroup", {
            Name = "MultiDropdownOptionsHolder_" .. name,
            BackgroundColor3 = Theme.Popup,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(0, math.min(#options, 8) * 24),
            Visible = false,
            GroupTransparency = 1,
            ClipsDescendants = true,
            ZIndex = 200,
            Parent = ScreenGui,
        })

        NewInstance("UIStroke", {
            Color = Theme.Outline,
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
            ScrollBarImageColor3 = Theme.TextDim,
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
            AnimatePopup(optionsHolder, false)
            if arrowIcon then TweenService:Create(arrowIcon, TweenInfo.new(0.12), { Rotation = 0 }):Play() end
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
                    BackgroundColor3 = Theme.Popup,
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
                    TextColor3 = Theme.Text,
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
                    BackgroundTransparency = selected[opt] == true and 0 or 1,
                    BorderSizePixel = 0,
                    Visible = true,
                    ZIndex = optRow.ZIndex + 1,
                    Parent = optRow,
                })

                NewInstance("UICorner", { CornerRadius = UDim.new(0, 4), Parent = check })

                checkMarks[opt] = check

                optBtn.MouseButton1Click:Connect(function()
                    selected[opt] = not selected[opt]
                    TweenService:Create(
                        check,
                        TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                        { BackgroundTransparency = selected[opt] == true and 0 or 1 }
                    ):Play()
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
            isOpen = true
            AnimatePopup(optionsHolder, true)
            if arrowIcon then TweenService:Create(arrowIcon, TweenInfo.new(0.12), { Rotation = 180 }):Play() end
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
                check.BackgroundTransparency = selected[opt] == true and 0 or 1
            end
            RefreshBoxText()
        end
        return api
    end

    function Factory.ColorPicker(parent, config)
        config = config or {}
        local name = config.Name or "Color"
        local default = config.Default or Theme.TextBright
        local callback = config.Callback

        local row = NewInstance("Frame", {
            Name = "ColorPicker_" .. name,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 26),
            Parent = parent,
        })

        NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(1, -56, 1, 0),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            Parent = row,
        })

        local swatch = NewInstance("TextButton", {
            Name = "Swatch",
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.fromOffset(16, 16),
            BackgroundColor3 = default,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            Parent = row,
        })

        NewInstance("UIStroke", {
            Color = Theme.Outline,
            Thickness = 1,
            Parent = swatch,
        })

        NewInstance("UICorner", {
            CornerRadius = UDim.new(0, 5),
            Parent = swatch,
        })

        local h, s, v = Color3.toHSV(default)
        local currentColor = default

        local panel = NewInstance("CanvasGroup", {
            Name = "ColorPickerPanel_" .. name,
            BackgroundColor3 = Theme.Popup,
            BackgroundTransparency = Theme.PopupTransparency,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(180, 204),
            Visible = false,
            GroupTransparency = 1,
            Interactable = false,
            ZIndex = 200,
            Parent = ScreenGui,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, Theme.PopupRounding), Parent = panel })

        NewInstance("UIStroke", {
            Color = Theme.Outline,
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
            TextColor3 = Theme.TextDim,
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
            TextColor3 = Theme.TextDim,
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
            ClipsDescendants = false,
            ZIndex = panel.ZIndex + 1,
            Parent = panel,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 7), Parent = svMap })

        local svWhiteOverlay = NewInstance("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            ZIndex = svMap.ZIndex + 1,
            Parent = svMap,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 7), Parent = svWhiteOverlay })

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

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 7), Parent = svBlackOverlay })

        NewInstance("UIGradient", {
            Rotation = 90,
            Transparency = NumberSequence.new(1, 0),
            Parent = svBlackOverlay,
        })

        local svCursor = NewInstance("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(10, 10),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = svBlackOverlay.ZIndex + 1,
            Position = UDim2.new(s, 0, 1 - v, 0),
            Parent = svMap,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(1, 0), Parent = svCursor })

        NewInstance("UIStroke", {
            Color = Color3.new(1, 1, 1),
            Thickness = 2,
            Parent = svCursor,
        })

        local hueTrack = NewInstance("Frame", {
            Position = UDim2.fromOffset(10, 154),
            Size = UDim2.fromOffset(160, 8),
            BorderSizePixel = 0,
            ZIndex = panel.ZIndex + 1,
            Parent = panel,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(1, 0), Parent = hueTrack })

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
            Size = UDim2.fromOffset(12, 12),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = hueTrack.ZIndex + 1,
            Parent = hueTrack,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(1, 0), Parent = hueCursor })

        NewInstance("UIStroke", {
            Color = Color3.new(1, 1, 1),
            Thickness = 2,
            Parent = hueCursor,
        })

        local hueCursorTween = nil

        local hexBox = NewInstance("TextBox", {
            Position = UDim2.fromOffset(10, 178),
            Size = UDim2.fromOffset(160, 16),
            BackgroundColor3 = Theme.ElementActive,
            BorderSizePixel = 0,
            Font = Enum.Font.Code,
            TextSize = 12,
            TextColor3 = Theme.Text,
            ClearTextOnFocus = false,
            Text = "#" .. default:ToHex(),
            ZIndex = panel.ZIndex + 1,
            Parent = panel,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 5), Parent = hexBox })
        NewInstance("UIStroke", { Color = Theme.Outline, Thickness = 1, Parent = hexBox })

        local isOpen = false
        local panelTransition = 0
        local panelTween = nil

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
            if hueCursorTween then hueCursorTween:Cancel() end
            hueCursorTween = TweenService:Create(
                hueCursor,
                TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { Position = UDim2.new(h, 0, 0.5, 0) }
            )
            hueCursorTween:Play()
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
                if hueCursorTween then hueCursorTween:Cancel() end
                hueCursor.Position = UDim2.new(h, 0, 0.5, 0)
                ApplyColor(true)
            else
                hexBox.Text = "#" .. currentColor:ToHex()
            end
        end)

        local function Close()
            if not isOpen and not panel.Visible then return end
            isOpen = false
            SetTreeInteractable(panel, false)
            panelTransition = panelTransition + 1
            local token = panelTransition
            if panelTween then panelTween:Cancel() end
            panelTween = TweenService:Create(
                panel,
                TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { GroupTransparency = 1 }
            )
            panelTween:Play()
            panelTween.Completed:Connect(function()
                if panel.Parent and token == panelTransition and not isOpen then
                    panel.Visible = false
                end
            end)
        end

        local function Open()
            CloseAllOverlaysExcept(panel)
            local swatchPos = swatch.AbsolutePosition
            local swatchSize = swatch.AbsoluteSize
            local panelSize = panel.AbsoluteSize
            local x = swatchPos.X + swatchSize.X + 5
            local y = swatchPos.Y - 100
            x, y = ClampOpenPosition(x, y, panelSize.X, panelSize.Y)
            panel.Position = UDim2.fromOffset(x, y)
            isOpen = true
            panelTransition = panelTransition + 1
            if panelTween then panelTween:Cancel() end
            if not panel.Visible then panel.GroupTransparency = 1 end
            panel.Visible = true
            SetTreeInteractable(panel, true)
            panelTween = TweenService:Create(
                panel,
                TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { GroupTransparency = 0 }
            )
            panelTween:Play()
        end

        swatch.MouseButton1Click:Connect(function()
            if isOpen then
                Close()
            else
                Open()
            end
        end)

        closeBtn.MouseButton1Click:Connect(Close)

        local pickerDragCleanup = MakeDraggable(panelHandle, panel)

        RegisterOverlay(panel, swatch, function() return isOpen end, Close)

        row.Destroying:Connect(function()
            panelTransition = panelTransition + 1
            if panelTween then panelTween:Cancel() end
            if hueCursorTween then hueCursorTween:Cancel() end
            pickerDragCleanup:Disconnect()
            panel:Destroy()
        end)

        local api = {}
        function api.Set(color3)
            h, s, v = Color3.toHSV(color3)
            svCursor.Position = UDim2.new(s, 0, 1 - v, 0)
            if hueCursorTween then hueCursorTween:Cancel() end
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
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(1, -24, 0, 16),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            Parent = row,
        })

        local box = NewInstance("TextBox", {
            Position = UDim2.fromOffset(12, 20),
            Size = UDim2.new(1, -24, 0, 18),
            BackgroundColor3 = Theme.Element,
            BorderSizePixel = 0,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextColor3 = Theme.Text,
            PlaceholderText = placeholder,
            PlaceholderColor3 = Theme.TextDim,
            ClearTextOnFocus = false,
            Text = default,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row,
        })

        NewInstance("UIStroke", {
            Color = Theme.Outline,
            Thickness = 1,
            Parent = box,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 8), Parent = box })

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
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(1, -120, 1, 0),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            Parent = row,
        })

        local box = NewInstance("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.fromOffset(84, 20),
            BackgroundColor3 = Theme.Element,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextColor3 = Theme.Text,
            Text = FormatKeycodeName(default),
            Parent = row,
        })

        NewInstance("UIStroke", {
            Color = Theme.Outline,
            Thickness = 1,
            Parent = box,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 8), Parent = box })

        local currentKey = default
        local listening = false

        local function StopListening()
            listening = false
            if box.Parent then box.Text = FormatKeycodeName(currentKey) end
            if ActiveKeybindTarget == box then
                ActiveKeybindTarget = nil
                ActiveKeybindCancel = nil
            end
        end

        box.MouseButton1Click:Connect(function()
            if listening then
                StopListening()
                return
            end
            if ActiveKeybindCancel then
                ActiveKeybindCancel()
            end
            listening = true
            ActiveKeybindTarget = box
            ActiveKeybindCancel = StopListening
            box.Text = "..."
        end)

        local keyInputConnection
        keyInputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if not listening then
                return
            end
            if gameProcessed then
                return
            end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode == Enum.KeyCode.Escape then
                    StopListening()
                    return
                end
                currentKey = input.KeyCode
                StopListening()
                if callback then
                    callback(currentKey)
                end
            end
        end)

        row.Destroying:Connect(function()
            StopListening()
            if keyInputConnection then keyInputConnection:Disconnect() end
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
            BackgroundColor3 = Theme.Outline,
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
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(1, -56, 1, 0),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            Parent = row,
        })

        local box = NewInstance("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.fromOffset(18, 18),
            BackgroundColor3 = default and Accent.Value or Theme.Element,
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
            Color = default and Accent.Value or Theme.Outline,
            Thickness = 1,
            Parent = box,
        })

        local check = NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextColor3 = Theme.Element,
            Text = "\u{2713}",
            Visible = true,
            TextTransparency = default and 0 or 1,
            Parent = box,
        })

        local state = default

        local function ApplyVisual(animated)
            local bgGoal = { BackgroundTransparency = state and 0 or 1 }
            local checkGoal = { TextTransparency = state and 0 or 1 }
            boxStroke.Color = state and Accent.Value or Theme.Outline
            box.BackgroundColor3 = Accent.Value
            if animated then
                TweenService:Create(box, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), bgGoal):Play()
                TweenService:Create(check, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), checkGoal):Play()
            else
                box.BackgroundTransparency = bgGoal.BackgroundTransparency
                check.TextTransparency = checkGoal.TextTransparency
            end
        end

        Accent.Changed:Connect(function(color)
            box.BackgroundColor3 = color
            boxStroke.Color = state and color or Theme.Outline
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
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(1, -76, 1, 0),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            Parent = row,
        })

        local track = NewInstance("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.fromOffset(40, 20),
            BackgroundColor3 = default and Accent.Value or Theme.ElementHover,
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
            BackgroundColor3 = Theme.TextBright,
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
            local trackGoal = { BackgroundColor3 = state and Accent.Value or Theme.ElementHover }
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
                TextColor3 = Theme.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = name,
                Parent = row,
            })
        end

        local bar = NewInstance("Frame", {
            Position = UDim2.fromOffset(0, hasLabel and 20 or 0),
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundColor3 = Theme.Element,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            Parent = row,
        })

        NewInstance("UIStroke", {
            Color = Theme.Outline,
            Thickness = 1,
            Parent = bar,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 8), Parent = bar })

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
                local active = opt == currentValue
                btn.BackgroundColor3 = Accent.Value
                TweenService:Create(
                    btn,
                    TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    {
                        BackgroundTransparency = active and 0.15 or 1,
                        TextColor3 = active and Theme.TextBright or Theme.Text,
                    }
                ):Play()
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
                TextColor3 = Theme.Text,
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
                TextColor3 = Theme.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = name,
                Parent = row,
            })
        end

        local currentValue = default
        local dots = {}

        local function SelectOption(opt, animated)
            currentValue = opt
            for optName, dot in pairs(dots) do
                local active = optName == opt
                local goal = {
                    BackgroundTransparency = active and 0 or 1,
                    Size = active and UDim2.fromOffset(8, 8) or UDim2.fromOffset(5, 5),
                }
                if animated then
                    TweenService:Create(
                        dot,
                        TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                        goal
                    ):Play()
                else
                    dot.BackgroundTransparency = goal.BackgroundTransparency
                    dot.Size = goal.Size
                end
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
                TextColor3 = Theme.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = tostring(opt),
                Parent = optRow,
            })

            local ring = NewInstance("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, 0, 0.5, 0),
                Size = UDim2.fromOffset(16, 16),
                BackgroundColor3 = Theme.Element,
                BorderSizePixel = 0,
                Parent = optRow,
            })

            NewInstance("UICorner", {
                CornerRadius = UDim.new(1, 0),
                Parent = ring,
            })

            NewInstance("UIStroke", {
                Color = Theme.Outline,
                Thickness = 1,
                Parent = ring,
            })

            local dot = NewInstance("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromOffset(8, 8),
                BackgroundColor3 = Accent.Value,
                BackgroundTransparency = opt == default and 0 or 1,
                BorderSizePixel = 0,
                Visible = true,
                Parent = ring,
            })

            NewInstance("UICorner", {
                CornerRadius = UDim.new(1, 0),
                Parent = dot,
            })

            dots[opt] = dot

            optBtn.MouseButton1Click:Connect(function()
                SelectOption(opt, true)
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
            SelectOption(value, false)
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
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(1, -134, 1, 0),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            Parent = row,
        })

        local controls = NewInstance("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.fromOffset(100, 22),
            BackgroundColor3 = Theme.Element,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            Parent = row,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 8), Parent = controls })

        NewInstance("UIStroke", {
            Color = Theme.Outline,
            Thickness = 1,
            Parent = controls,
        })

        local minusBtn = NewInstance("TextButton", {
            Size = UDim2.new(0, 26, 1, 0),
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            TextColor3 = Theme.Text,
            Text = "-",
            Parent = controls,
        })

        local valueLabel = NewInstance("TextLabel", {
            Position = UDim2.new(0, 26, 0, 0),
            Size = UDim2.new(1, -52, 1, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextColor3 = Theme.Text,
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
            TextColor3 = Theme.Text,
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
                TweenService:Create(btn, TweenInfo.new(0.15), { TextColor3 = Theme.Text }):Play()
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
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(1, -24, 0, 18),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name .. ": " .. tostring(defaultLow) .. " - " .. tostring(defaultHigh),
            Parent = row,
        })

        local track = NewInstance("Frame", {
            Position = UDim2.fromOffset(12, 23),
            Size = UDim2.new(1, -24, 0, 8),
            BackgroundColor3 = Theme.Element,
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
            BackgroundColor3 = Theme.TextBright,
            BorderSizePixel = 0,
            ZIndex = track.ZIndex + 1,
            Parent = track,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(1, 0), Parent = lowKnob })

        local highKnob = NewInstance("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(highRatio, 0, 0.5, 0),
            Size = UDim2.fromOffset(13, 18),
            BackgroundColor3 = Theme.TextBright,
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
            TextColor3 = Theme.TextDim,
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
            TextColor3 = Theme.Text,
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
            TextColor3 = Theme.Text,
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
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(1, -72, 0, 18),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name .. ": " .. tostring(sliderDefault),
            Parent = row,
        })

        local box = NewInstance("TextButton", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -12, 0, 0),
            Size = UDim2.fromOffset(20, 18),
            BackgroundColor3 = Theme.Element,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            Parent = row,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 5), Parent = box })

        local toggleFill = NewInstance("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Accent.Value,
            BorderSizePixel = 0,
            BackgroundTransparency = toggleDefault and 0 or 1,
            Parent = box,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 5), Parent = toggleFill })

        local track = NewInstance("Frame", {
            Position = UDim2.fromOffset(12, 23),
            Size = UDim2.new(1, -24, 0, 8),
            BackgroundColor3 = Theme.Element,
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
            BackgroundColor3 = Theme.TextBright,
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
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(1, -24, 0, 16),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            Parent = row,
        })

        local box = NewInstance("TextButton", {
            Position = UDim2.fromOffset(12, 20),
            Size = UDim2.new(1, -24, 0, 24),
            BackgroundColor3 = Theme.Element,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "  " .. tostring(default or ""),
            Parent = row,
        })

        NewInstance("UIStroke", {
            Color = Theme.Outline,
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

        local arrowIcon = nil
        if CreateIcon then
            arrowIcon = CreateIcon(box, "chevron-down", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(1, -16, 0.5, 0),
                Pixels = 15,
                Color = Accent.Value,
                ZIndex = box.ZIndex + 1,
            })
            if arrowIcon then arrow.Text = "" end
        end

        Accent.Changed:Connect(function(color)
            arrow.TextColor3 = color
            if arrowIcon then arrowIcon.ImageColor3 = color end
        end)

        local panelHeight = math.min(#options, 5) * 24 + 28

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 8), Parent = box })

        local optionsHolder = NewInstance("CanvasGroup", {
            Name = "SearchableDropdownHolder_" .. name,
            BackgroundColor3 = Theme.Popup,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(0, panelHeight),
            Visible = false,
            GroupTransparency = 1,
            ClipsDescendants = true,
            ZIndex = 200,
            Parent = ScreenGui,
        })

        NewInstance("UIStroke", {
            Color = Theme.Outline,
            Thickness = 1,
            Parent = optionsHolder,
        })

        local searchBox = NewInstance("TextBox", {
            Position = UDim2.fromOffset(4, 4),
            Size = UDim2.new(1, -8, 0, 20),
            BackgroundColor3 = Theme.ElementActive,
            BorderSizePixel = 0,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextColor3 = Theme.Text,
            PlaceholderText = "Search...",
            PlaceholderColor3 = Theme.TextDim,
            ClearTextOnFocus = false,
            Text = "",
            ZIndex = optionsHolder.ZIndex + 1,
            Parent = optionsHolder,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 8), Parent = searchBox })

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
            AnimatePopup(optionsHolder, false)
            if arrowIcon then TweenService:Create(arrowIcon, TweenInfo.new(0.12), { Rotation = 0 }):Play() end
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
                        BackgroundColor3 = Theme.Popup,
                        BorderSizePixel = 0,
                        AutoButtonColor = false,
                        Size = UDim2.new(1, 0, 0, 24),
                        Font = Enum.Font.Gotham,
                        TextSize = 13,
                        TextColor3 = Theme.Text,
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
            isOpen = true
            AnimatePopup(optionsHolder, true)
            if arrowIcon then TweenService:Create(arrowIcon, TweenInfo.new(0.12), { Rotation = 180 }):Play() end
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
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(1, -24, 0, 16),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = name,
            Parent = row,
        })

        local box = NewInstance("TextBox", {
            Position = UDim2.fromOffset(12, 20),
            Size = UDim2.new(1, -24, 0, 18),
            BackgroundColor3 = Theme.Element,
            BorderSizePixel = 0,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextColor3 = Theme.Text,
            PlaceholderText = placeholder,
            PlaceholderColor3 = Theme.TextDim,
            ClearTextOnFocus = false,
            Text = tostring(default),
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row,
        })

        if numeric then
            box.TextWrapped = false
        end

        local boxStroke = NewInstance("UIStroke", {
            Color = Theme.Outline,
            Thickness = 1,
            Parent = box,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, 8), Parent = box })

        NewInstance("UIPadding", {
            PaddingLeft = UDim.new(0, 6),
            PaddingRight = UDim.new(0, 6),
            Parent = box,
        })

        box.Focused:Connect(function()
            boxStroke.Color = Accent.Value
        end)

        box.FocusLost:Connect(function(enterPressed)
            boxStroke.Color = Theme.Outline

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
            BackgroundColor3 = Theme.ElementActive,
            BorderSizePixel = 0,
            AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(1, 0, 0, 0),
            Parent = parent,
        })

        NewInstance("UIStroke", {
            Color = Theme.Outline,
            Thickness = 1,
            Parent = container,
        })

        NewInstance("UICorner", {
            CornerRadius = UDim.new(0, Theme.ElementRounding),
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

        local groupIcon = nil
        if config.Icon and CreateIcon then
            groupIcon = CreateIcon(header, config.Icon, {
                Pixels = 15,
                Position = UDim2.new(0, 10, 0.5, 0),
                Color = Theme.Text,
                ZIndex = header.ZIndex + 1,
            })
        end

        NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(groupIcon and 34 or 10, 0),
            Size = UDim2.new(1, groupIcon and -68 or -44, 1, 0),
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextColor3 = Theme.Text,
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

        local chevronIcon = nil
        if CreateIcon then
            chevronIcon = CreateIcon(header, "chevron-down", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(1, -16, 0.5, 0),
                Pixels = 15,
                Color = Accent.Value,
                Rotation = startOpen and 0 or -90,
                ZIndex = header.ZIndex + 1,
            })
            if chevronIcon then chevron.Text = "" end
        end

        Accent.Changed:Connect(function(color)
            chevron.TextColor3 = color
            if chevronIcon then chevronIcon.ImageColor3 = color end
        end)

        local bodyClip = NewInstance("Frame", {
            Name = "BodyClip",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            ClipsDescendants = true,
            Visible = startOpen,
            Parent = container,
        })

        local body = NewInstance("CanvasGroup", {
            Name = "Body",
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(1, 0, 0, 0),
            Visible = true,
            GroupTransparency = startOpen and 0 or 1,
            Interactable = startOpen,
            Parent = bodyClip,
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
        local groupTransition = 0
        local bodyTween = nil
        local bodySizeTween = nil
        local chevronTween = nil

        local function GetBodyHeight()
            return math.max(body.AbsoluteSize.Y, bodyLayout.AbsoluteContentSize.Y + 10)
        end

        local function SetGroupOpen(open, animated)
            open = open == true
            isOpen = open
            groupTransition = groupTransition + 1
            local token = groupTransition
            if bodyTween then bodyTween:Cancel() end
            if bodySizeTween then bodySizeTween:Cancel() end
            if chevronTween then chevronTween:Cancel() end

            if chevronIcon then
                if animated then
                    chevronTween = TweenService:Create(
                        chevronIcon,
                        TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                        { Rotation = open and 0 or -90 }
                    )
                    chevronTween:Play()
                else
                    chevronIcon.Rotation = open and 0 or -90
                end
            else
                chevron.Text = open and "v" or ">"
            end

            if not animated then
                body.GroupTransparency = open and 0 or 1
                SetTreeInteractable(body, open)
                bodyClip.Size = UDim2.new(1, 0, 0, open and GetBodyHeight() or 0)
                bodyClip.Visible = open
                return
            end

            if open then
                if not bodyClip.Visible then
                    body.GroupTransparency = 1
                    bodyClip.Size = UDim2.new(1, 0, 0, 0)
                end
                bodyClip.Visible = true
                SetTreeInteractable(body, true)
            else
                SetTreeInteractable(body, false)
            end
            bodyTween = TweenService:Create(
                body,
                TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { GroupTransparency = open and 0 or 1 }
            )
            bodyTween:Play()
            bodySizeTween = TweenService:Create(
                bodyClip,
                TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { Size = UDim2.new(1, 0, 0, open and GetBodyHeight() or 0) }
            )
            bodySizeTween:Play()
            if not open then
                bodySizeTween.Completed:Connect(function()
                    if token == groupTransition and not isOpen then bodyClip.Visible = false end
                end)
            end
        end

        bodyLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            if not isOpen then return end
            task.defer(function()
                if isOpen and bodyClip.Parent then
                    if bodySizeTween then bodySizeTween:Cancel() end
                    bodySizeTween = TweenService:Create(
                        bodyClip,
                        TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                        { Size = UDim2.new(1, 0, 0, GetBodyHeight()) }
                    )
                    bodySizeTween:Play()
                end
            end)
        end)

        task.defer(function()
            if bodyClip.Parent then
                bodyClip.Size = UDim2.new(1, 0, 0, startOpen and GetBodyHeight() or 0)
            end
        end)

        header.MouseButton1Click:Connect(function()
            SetGroupOpen(not isOpen, true)
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
            SetGroupOpen(open, true)
        end

        return Group
    end

    return Factory
end

local function CreateTab(context, tabName, isFirst)
    local Factory = context.Factory
    local ScrollHolder = context.ScrollHolder

    local tabContainer = NewInstance("CanvasGroup", {
        Name = tabName .. "_Container",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Visible = isFirst,
        GroupTransparency = isFirst and 0 or 1,
        Interactable = isFirst,
        ZIndex = ScrollHolder.ZIndex + 1,
        Parent = ScrollHolder,
    })

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
        ZIndex = tabContainer.ZIndex + 1,
        Parent = tabContainer,
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
    Tab.Container = tabContainer

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

local function CreateWindow(config)
    config = config or {}

    local iconSheet = config.IconSheet or "48px"
    local iconAtlas = nil
    if config.LoadIcons == false then
        iconAtlas = type(config.Icons) == "table" and config.Icons or nil
    else
        iconAtlas = LoadIconAtlas(config.Icons or config.IconURL or DEFAULT_ICON_URL)
    end
    local function CreateWindowIcon(parent, name, iconConfig)
        iconConfig = iconConfig or {}
        local resolvedConfig = {}
        for key, value in pairs(iconConfig) do resolvedConfig[key] = value end
        if resolvedConfig.Sheet == nil then resolvedConfig.Sheet = iconSheet end
        return CreateAtlasIcon(iconAtlas, parent, name, resolvedConfig)
    end

    local function GetViewportSize()
        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize
        if viewport and viewport.X > 0 and viewport.Y > 0 then return viewport end
        return Vector2.new(1920, 1080)
    end

    local function IsFinitePositive(value)
        return type(value) == "number" and value == value and value > 0 and value < 10000000
    end

    local function SanitizePixelSize(value, fallback)
        if typeof(value) ~= "Vector2" then return fallback end
        local x = IsFinitePositive(value.X) and value.X or fallback.X
        local y = IsFinitePositive(value.Y) and value.Y or fallback.Y
        return Vector2.new(x, y)
    end

    local function ResolveSizeValue(value, viewport, fallback)
        if typeof(value) == "Vector2" then return SanitizePixelSize(value, fallback) end
        if typeof(value) == "UDim2" then
            return SanitizePixelSize(Vector2.new(
                value.X.Scale * viewport.X + value.X.Offset,
                value.Y.Scale * viewport.Y + value.Y.Offset
            ), fallback)
        end
        return fallback
    end

    local windowName = config.Name or "Lurk"
    local initialViewport = GetViewportSize()
    local availableSize = Vector2.new(math.max(1, initialViewport.X - 16), math.max(1, initialViewport.Y - 16))
    local defaultPixelSize = Vector2.new(math.min(680, availableSize.X), math.min(460, availableSize.Y))
    local requestedPixelSize = ResolveSizeValue(config.Size, initialViewport, defaultPixelSize)
    local provisionalWidth = math.min(requestedPixelSize.X, availableSize.X)
    local sidebarMinimum = provisionalWidth < 260 and 72 or 96
    local contentMinimum = provisionalWidth < 260 and 80 or 140
    local defaultSidebar = provisionalWidth < 560 and math.clamp(math.floor(provisionalWidth * 0.34), sidebarMinimum, 150) or 180
    local requestedSidebar = tonumber(config.SidebarWidth) or defaultSidebar
    local sidebarWidth = math.clamp(requestedSidebar, sidebarMinimum, math.max(sidebarMinimum, provisionalWidth - contentMinimum))

    local defaultMinimumSize = Vector2.new(math.max(240, sidebarWidth + 140), 200)
    local minimumWindowSize = ResolveSizeValue(config.MinSize, initialViewport, defaultMinimumSize)
    local maximumWindowSize = ResolveSizeValue(config.MaxSize, initialViewport, Vector2.new(1400, 1000))
    maximumWindowSize = Vector2.new(
        math.max(maximumWindowSize.X, minimumWindowSize.X),
        math.max(maximumWindowSize.Y, minimumWindowSize.Y)
    )
    local effectiveMinimum = Vector2.new(
        math.min(minimumWindowSize.X, availableSize.X),
        math.min(minimumWindowSize.Y, availableSize.Y)
    )
    local effectiveMaximum = Vector2.new(
        math.max(effectiveMinimum.X, math.min(maximumWindowSize.X, availableSize.X)),
        math.max(effectiveMinimum.Y, math.min(maximumWindowSize.Y, availableSize.Y))
    )
    local initialPixelSize = Vector2.new(
        math.clamp(requestedPixelSize.X, effectiveMinimum.X, effectiveMaximum.X),
        math.clamp(requestedPixelSize.Y, effectiveMinimum.Y, effectiveMaximum.Y)
    )
    sidebarWidth = math.clamp(
        sidebarWidth,
        initialPixelSize.X < 260 and 72 or 96,
        math.max(initialPixelSize.X < 260 and 72 or 96, initialPixelSize.X - (initialPixelSize.X < 260 and 80 or 140))
    )
    local windowSize = UDim2.fromOffset(math.floor(initialPixelSize.X + 0.5), math.floor(initialPixelSize.Y + 0.5))
    local openButtonText = config.OpenButtonText or string.sub(windowName, 1, 1)
    local startColor = config.AccentColor or Theme.Accent

    local existing = GuiParent:FindFirstChild("LurkGui_" .. windowName)
    if existing then
        existing:Destroy()
    end

    local ScreenGui = NewInstance("ScreenGui", {
        Name = "LurkGui_" .. windowName,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 999999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    ProtectGui(ScreenGui)
    ScreenGui.Parent = GuiParent

    local Accent = {}
    Accent.Value = startColor
    Accent._bindable = Instance.new("BindableEvent")
    Accent.Changed = Accent._bindable.Event
    function Accent.Set(color)
        Accent.Value = color
        Accent._bindable:Fire(color)
    end

    local mainWindow = NewInstance("Frame", {
        Name = "MainWindow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = windowSize,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = false,
        Interactable = false,
        ZIndex = 2,
        Parent = ScreenGui,
    })

    NewInstance("UICorner", {
        CornerRadius = UDim.new(0, Theme.WindowRounding),
        Parent = mainWindow,
    })

    local windowSurface = NewInstance("CanvasGroup", {
        Name = "WindowSurface",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Window,
        BackgroundTransparency = Theme.WindowTransparency,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        GroupTransparency = 1,
        Interactable = false,
        ZIndex = mainWindow.ZIndex,
        Parent = mainWindow,
    })

    NewInstance("UICorner", {
        CornerRadius = UDim.new(0, Theme.WindowRounding),
        Parent = windowSurface,
    })

    NewInstance("UIStroke", {
        Color = Theme.Border,
        Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = windowSurface,
    })

    -- The old Lurk skin used four nested bevel layers. Everness uses one
    -- clean surface and a single outline.
    local bg2 = windowSurface

    local rightOutline = NewInstance("Frame", {
        Name = "SidebarDivider",
        Position = UDim2.fromOffset(sidebarWidth, 0),
        Size = UDim2.new(0, 1, 1, 0),
        BackgroundColor3 = Theme.Border,
        BorderSizePixel = 0,
        Active = false,
        ZIndex = bg2.ZIndex + 1,
        Parent = bg2,
    })

    local titleBar = NewInstance("Frame", {
        Name = "TitleBar",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(sidebarWidth + 1, 1),
        Size = UDim2.new(1, -sidebarWidth - 2, 0, 48),
        ZIndex = bg2.ZIndex + 1,
        Parent = bg2,
    })

    local titleText = NewInstance("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        TextColor3 = Theme.Text,
        Text = windowName,
        ZIndex = titleBar.ZIndex + 1,
        Parent = titleBar,
    })

    local sidebar = NewInstance("Frame", {
        Name = "Sidebar",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(0, sidebarWidth, 1, 0),
        ZIndex = bg2.ZIndex + 1,
        Parent = bg2,
    })

    local sidebarInner = sidebar

    local logoIconName = config.LogoIcon or config.Icon
    local logoLabel = NewInstance("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 80),
        Position = UDim2.fromOffset(0, 0),
        Font = Enum.Font.GothamBlack,
        Text = logoIconName and "" or openButtonText,
        TextSize = 32,
        TextColor3 = Theme.Text,
        ZIndex = sidebarInner.ZIndex + 1,
        Parent = sidebarInner,
    })

    local logoIcon = nil
    if logoIconName then
        logoIcon = CreateWindowIcon(sidebarInner, logoIconName, {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0, 50),
            Pixels = tonumber(config.LogoIconSize) or 48,
            Color = config.LogoColor or Theme.TextBright,
            ZIndex = logoLabel.ZIndex + 1,
        })
        if not logoIcon then logoLabel.Text = openButtonText end
    end

    local contentArea = NewInstance("Frame", {
        Name = "ContentArea",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(sidebarWidth + 1, 51),
        Size = UDim2.new(1, -sidebarWidth - 2, 1, -52),
        ZIndex = bg2.ZIndex + 1,
        Parent = bg2,
    })
    local contentInner = contentArea

    local topSeparator = NewInstance("Frame", {
        Name = "TopSeparator",
        Position = UDim2.fromOffset(sidebarWidth, 50),
        Size = UDim2.new(1, -sidebarWidth, 0, 1),
        BackgroundColor3 = Theme.Border,
        BorderSizePixel = 0,
        ZIndex = bg2.ZIndex + 2,
        Parent = bg2,
    })

    local tabTitle = NewInstance("TextLabel", {
        Name = "TabTitle",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 4),
        Size = UDim2.new(1, -20, 0, 24),
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "",
        ZIndex = contentInner.ZIndex + 1,
        Parent = contentInner,
    })

    local scrollHolder = NewInstance("Frame", {
        Name = "ScrollHolder",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 34),
        Size = UDim2.new(1, -20, 1, -44),
        ZIndex = contentInner.ZIndex + 1,
        Parent = contentInner,
    })

    local tabsSidebarHolder = NewInstance("ScrollingFrame", {
        Name = "TabsHolder",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(10, 80),
        Size = UDim2.new(1, -20, 1, -90),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 0,
        ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
        ClipsDescendants = true,
        ZIndex = sidebarInner.ZIndex + 1,
        Parent = sidebarInner,
    })

    local tabsListLayout = NewInstance("UIListLayout", {
        Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = tabsSidebarHolder,
    })

    NewInstance("UIPadding", {
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
        Parent = tabsSidebarHolder,
    })

    tabsListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        tabsSidebarHolder.CanvasSize = UDim2.new(0, 0, 0, tabsListLayout.AbsoluteContentSize.Y + 4)
    end)

    local Factory = CreateElementFactory({
        ScreenGui = ScreenGui,
        Accent = Accent,
        CreateIcon = CreateWindowIcon,
    })

    local Window = {}
    local windowConnections = {}
    Window.Name = windowName
    Window.Instance = mainWindow
    Window.Surface = windowSurface
    Window.ScreenGui = ScreenGui
    Window.Accent = Accent
    Window.Icons = iconAtlas
    Window.LogoIcon = logoIcon

    function Window:GetIcon(name, sheetName)
        local descriptor = ResolveIcon(iconAtlas, name, sheetName or iconSheet)
        if not descriptor then return nil, nil, nil end
        return descriptor.Image, descriptor.Offset, descriptor.Size
    end

    function Window:GetIconDescriptor(name, sheetName)
        return ResolveIcon(iconAtlas, name, sheetName or iconSheet)
    end

    function Window:CreateIcon(parent, name, iconConfig)
        return CreateWindowIcon(parent, name, iconConfig)
    end

    function Window:SetIconAtlas(source, sheetName)
        local resolved = LoadIconAtlas(source)
        if not resolved then return false end
        iconAtlas = resolved
        Window.Icons = resolved
        if sheetName then iconSheet = sheetName end
        return true
    end

    function Window:SetIcon(name)
        if logoIcon then
            logoIcon:Destroy()
            logoIcon = nil
        end
        logoLabel.Text = name and "" or openButtonText
        if name then
            logoIcon = CreateWindowIcon(sidebarInner, name, {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0, 50),
                Pixels = tonumber(config.LogoIconSize) or 48,
                Color = config.LogoColor or Theme.TextBright,
                ZIndex = logoLabel.ZIndex + 1,
            })
            if not logoIcon then logoLabel.Text = openButtonText end
        end
        Window.LogoIcon = logoIcon
        return logoIcon
    end

    local tabs = {}
    local tabButtons = {}
    local tabIcons = {}
    local selectedTab = nil
    local tabTransition = 0
    local tabContentTweens = {}

    local function SelectTab(tabName)
        if not tabs[tabName] then
            return
        end
        if selectedTab == tabName then return end
        tabTransition = tabTransition + 1
        local token = tabTransition
        for _, tween in ipairs(tabContentTweens) do tween:Cancel() end
        table.clear(tabContentTweens)

        selectedTab = tabName
        tabTitle.Text = tabName
        local targetTab = tabs[tabName]
        local targetContainer = targetTab.Container or targetTab.Instance
        local fadingOldContent = false

        for name, tab in pairs(tabs) do
            local container = tab.Container or tab.Instance
            if name ~= tabName and container.Visible then
                fadingOldContent = true
                SetTreeInteractable(container, false)
                local tween = TweenService:Create(
                    container,
                    TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { GroupTransparency = 1 }
                )
                table.insert(tabContentTweens, tween)
                tween:Play()
            end
        end

        local function RevealTarget()
            if token ~= tabTransition or not targetContainer.Parent then return end
            for name, tab in pairs(tabs) do
                local container = tab.Container or tab.Instance
                if name ~= tabName then
                    container.Visible = false
                    SetTreeInteractable(container, false)
                    container.GroupTransparency = 1
                    tab.Instance.Visible = false
                end
            end
            if not targetContainer.Visible then targetContainer.GroupTransparency = 1 end
            targetContainer.Visible = true
            SetTreeInteractable(targetContainer, true)
            targetTab.Instance.Visible = true
            targetTab.Instance.Position = UDim2.fromOffset(0, 4)
            local fadeIn = TweenService:Create(
                targetContainer,
                TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { GroupTransparency = 0 }
            )
            local slideIn = TweenService:Create(
                targetTab.Instance,
                TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { Position = UDim2.fromOffset(0, 0) }
            )
            table.insert(tabContentTweens, fadeIn)
            table.insert(tabContentTweens, slideIn)
            fadeIn:Play()
            slideIn:Play()
        end

        if fadingOldContent then
            task.delay(0.08, RevealTarget)
        else
            RevealTarget()
        end

        for name, btn in pairs(tabButtons) do
            local active = name == tabName
            TweenService:Create(
                btn,
                TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {
                    TextColor3 = active and Theme.TextBright or Theme.TextDim,
                    BackgroundTransparency = active and (1 - 8 / 255) or 1,
                }
            ):Play()
            local icon = tabIcons[name]
            if icon then
                TweenService:Create(
                    icon,
                    TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { ImageColor3 = active and Accent.Value or Theme.TextDim }
                ):Play()
            end
        end
        CloseAllOverlays()
    end

    function Window:AddTab(tabConfig)
        local tabName = type(tabConfig) == "table" and tostring(tabConfig.Name or tabConfig.Title or "Tab") or tostring(tabConfig)
        local tabIconName = type(tabConfig) == "table" and tabConfig.Icon or nil
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

        local btn = NewInstance("TextButton", {
            BackgroundColor3 = Theme.TextBright,
            BackgroundTransparency = isFirst and (1 - 8 / 255) or 1,
            Size = UDim2.new(1, 0, 0, 32),
            LayoutOrder = index,
            Font = Enum.Font.GothamMedium,
            TextSize = 15,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = tabName,
            TextColor3 = isFirst and Theme.TextBright or Theme.TextDim,
            AutoButtonColor = false,
            ZIndex = tabsSidebarHolder.ZIndex + 1,
            Parent = tabsSidebarHolder,
        })

        NewInstance("UICorner", {
            CornerRadius = UDim.new(0, Theme.ElementRounding),
            Parent = btn,
        })

        local tabIcon = nil
        if tabIconName then
            tabIcon = CreateWindowIcon(btn, tabIconName, {
                Pixels = 16,
                Position = UDim2.new(0, -26, 0.5, 0),
                Color = isFirst and Accent.Value or Theme.TextDim,
                ZIndex = btn.ZIndex + 1,
            })
        end
        NewInstance("UIPadding", {
            PaddingLeft = UDim.new(0, tabIcon and 38 or 12),
            PaddingRight = UDim.new(0, 12),
            Parent = btn,
        })

        btn.MouseEnter:Connect(function()
            if selectedTab ~= tabName then
                TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundTransparency = 1 - 4 / 255, TextColor3 = Theme.Text }):Play()
                if tabIcon then
                    TweenService:Create(tabIcon, TweenInfo.new(0.1), { ImageColor3 = Theme.Text }):Play()
                end
            end
        end)

        btn.MouseLeave:Connect(function()
            if selectedTab ~= tabName then
                TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundTransparency = 1, TextColor3 = Theme.TextDim }):Play()
                if tabIcon then
                    TweenService:Create(tabIcon, TweenInfo.new(0.1), { ImageColor3 = Theme.TextDim }):Play()
                end
            end
        end)

        btn.MouseButton1Click:Connect(function()
            SelectTab(tabName)
        end)

        tabButtons[tabName] = btn
        tabIcons[tabName] = tabIcon

        if isFirst then
            SelectTab(tabName)
        end

        return tab
    end

    Accent.Changed:Connect(function(color)
        if selectedTab and tabIcons[selectedTab] then
            tabIcons[selectedTab].ImageColor3 = color
        end
    end)

    function Window:SelectTab(tabName)
        SelectTab(tabName)
    end

    function Window:SetAccentColor(color3)
        Accent.Set(color3)
    end

    local menuOpen = false
    local animating = false
    local resizing = false
    local menuTransition = 0
    local menuFadeTween = nil
    local menuScaleTween = nil
    local menuScale = NewInstance("UIScale", {
        Scale = 0.985,
        Parent = mainWindow,
    })

    local function ApplyOpenState(open)
        menuTransition = menuTransition + 1
        local token = menuTransition
        if menuFadeTween then menuFadeTween:Cancel() end
        if menuScaleTween then menuScaleTween:Cancel() end

        if not open then
            CloseAllOverlays()
        end

        if open then
            if not mainWindow.Visible then
                windowSurface.GroupTransparency = 1
                menuScale.Scale = 0.985
            end
            mainWindow.Visible = true
            SetTreeInteractable(mainWindow, true)
            SetTreeInteractable(windowSurface, true)
            menuFadeTween = TweenService:Create(
                windowSurface,
                TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                { GroupTransparency = 0 }
            )
            menuScaleTween = TweenService:Create(
                menuScale,
                TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                { Scale = 1 }
            )
            menuFadeTween:Play()
            menuScaleTween:Play()
            menuScaleTween.Completed:Connect(function()
                if token == menuTransition then animating = false end
            end)
        else
            SetTreeInteractable(mainWindow, false)
            SetTreeInteractable(windowSurface, false)
            if not mainWindow.Visible then
                animating = false
                return
            end
            menuFadeTween = TweenService:Create(
                windowSurface,
                TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { GroupTransparency = 1 }
            )
            menuScaleTween = TweenService:Create(
                menuScale,
                TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { Scale = 0.985 }
            )
            menuFadeTween:Play()
            menuScaleTween:Play()
            menuFadeTween.Completed:Connect(function()
                if token == menuTransition and not menuOpen then
                    mainWindow.Visible = false
                    animating = false
                end
            end)
        end
    end

    function Window:Toggle(open)
        if resizing then return end
        if open == nil then
            open = not menuOpen
        end
        open = open == true
        if open == menuOpen then return end
        menuOpen = open
        animating = true
        ApplyOpenState(open)
    end

    local openButton = NewInstance("TextButton", {
        Name = "OpenMenuButton",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(46, 46),
        BackgroundColor3 = Theme.Popup,
        BackgroundTransparency = Theme.PopupTransparency,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        Text = config.OpenButtonIcon and "" or openButtonText,
        TextColor3 = Theme.Text,
        ZIndex = 100,
        Parent = ScreenGui,
    })

    local openButtonIcon = nil
    if config.OpenButtonIcon then
        openButtonIcon = CreateWindowIcon(openButton, config.OpenButtonIcon, {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Pixels = 20,
            Color = Theme.Text,
            ZIndex = openButton.ZIndex + 1,
        })
        if not openButtonIcon then openButton.Text = openButtonText end
    end
    Window.OpenButton = openButton
    Window.OpenButtonIcon = openButtonIcon

    NewInstance("UICorner", {
        CornerRadius = UDim.new(0, 14),
        Parent = openButton,
    })

    local openButtonStroke = NewInstance("UIStroke", {
        Color = Theme.Border,
        Thickness = 1,
        Transparency = 0,
        Parent = openButton,
    })

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

        table.insert(windowConnections, UserInputService.InputChanged:Connect(function(input)
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
        end))
    end

    table.insert(windowConnections, MakeDraggable(titleBar, mainWindow))

    -- Resize is intentionally built in and always enabled. The top-left point
    -- stays fixed even though MainWindow uses a centered AnchorPoint.
    local function ResolvePixelSize(value, fallback)
        return ResolveSizeValue(value, GetViewportSize(), fallback)
    end

    local function GetLogicalSize()
        return ResolveSizeValue(mainWindow.Size, GetViewportSize(), initialPixelSize)
    end

    local function GetLogicalTopLeft(size)
        size = size or GetLogicalSize()
        local viewport = GetViewportSize()
        local position = mainWindow.Position
        local anchorPixel = Vector2.new(
            position.X.Scale * viewport.X + position.X.Offset,
            position.Y.Scale * viewport.Y + position.Y.Offset
        )
        return Vector2.new(
            anchorPixel.X - mainWindow.AnchorPoint.X * size.X,
            anchorPixel.Y - mainWindow.AnchorPoint.Y * size.Y
        )
    end

    local function GetEffectiveBounds(topLeft)
        local viewport = GetViewportSize()
        local fullWidth = math.max(1, viewport.X - 16)
        local fullHeight = math.max(1, viewport.Y - 16)
        local availableWidth = math.min(fullWidth, math.max(1, viewport.X - topLeft.X - 8))
        local availableHeight = math.min(fullHeight, math.max(1, viewport.Y - topLeft.Y - 8))
        local minWidth = math.min(minimumWindowSize.X, availableWidth)
        local minHeight = math.min(minimumWindowSize.Y, availableHeight)
        local maxWidth = math.max(minWidth, math.min(maximumWindowSize.X, availableWidth))
        local maxHeight = math.max(minHeight, math.min(maximumWindowSize.Y, availableHeight))
        return Vector2.new(minWidth, minHeight), Vector2.new(maxWidth, maxHeight)
    end

    local resizeInput = nil
    local resizeMouse = false
    local resizeStartInput = Vector3.zero
    local resizeStartSize = Vector2.zero
    local resizeStartPosition = mainWindow.Position
    local resizeStartTopLeft = Vector2.zero

    local resizeHandle = NewInstance("TextButton", {
        Name = "ResizeHandle",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -4, 1, -4),
        Size = UDim2.fromOffset(44, 44),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = utf8.char(0x25E2),
        TextColor3 = Theme.TextDim,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        Active = true,
        ZIndex = 90,
        Parent = windowSurface,
    })

    local resizeIcon = nil
    local resizeIconCandidates = {}
    if config.ResizeIcon then table.insert(resizeIconCandidates, config.ResizeIcon) end
    table.insert(resizeIconCandidates, "scaling")
    table.insert(resizeIconCandidates, "move-diagonal-2")
    table.insert(resizeIconCandidates, "grip")
    for _, iconName in ipairs(resizeIconCandidates) do
        if not resizeIcon then
            resizeIcon = CreateWindowIcon(resizeHandle, iconName, {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Pixels = 14,
                Color = Theme.TextDim,
                Rotation = iconName == "grip" and -45 or 0,
                ZIndex = resizeHandle.ZIndex + 1,
            })
        end
    end
    if resizeIcon then resizeHandle.Text = "" end

    local ApplyResponsiveSidebar = nil

    local function ApplyPixelSize(requested, preserveTopLeft)
        local oldSize = GetLogicalSize()
        requested = SanitizePixelSize(requested, oldSize)
        local currentTopLeft = GetLogicalTopLeft(oldSize)
        local topLeft = preserveTopLeft or currentTopLeft
        local effectiveMin, effectiveMax = GetEffectiveBounds(topLeft)
        local width = math.clamp(requested.X, effectiveMin.X, effectiveMax.X)
        local height = math.clamp(requested.Y, effectiveMin.Y, effectiveMax.Y)
        local delta = Vector2.new(width - oldSize.X, height - oldSize.Y)
        local topLeftDelta = topLeft - currentTopLeft
        local oldPosition = mainWindow.Position
        mainWindow.Size = UDim2.fromOffset(width, height)
        mainWindow.Position = UDim2.new(
            oldPosition.X.Scale, oldPosition.X.Offset + topLeftDelta.X + mainWindow.AnchorPoint.X * delta.X,
            oldPosition.Y.Scale, oldPosition.Y.Offset + topLeftDelta.Y + mainWindow.AnchorPoint.Y * delta.Y
        )
        windowSize = mainWindow.Size
        if ApplyResponsiveSidebar then ApplyResponsiveSidebar(width) end
        return Vector2.new(width, height)
    end

    table.insert(windowConnections, resizeHandle.InputBegan:Connect(function(input)
        if not resizeHandle.Interactable then return end
        local kind = input.UserInputType
        if resizing or animating or kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then return end
        resizing = true
        resizeInput = input
        resizeMouse = kind == Enum.UserInputType.MouseButton1
        resizeStartInput = input.Position
        resizeStartSize = GetLogicalSize()
        resizeStartPosition = mainWindow.Position
        resizeStartTopLeft = GetLogicalTopLeft(resizeStartSize)
        CloseAllOverlays()
    end))

    table.insert(windowConnections, UserInputService.InputChanged:Connect(function(input)
        if not resizing or not resizeInput then return end
        local matches = resizeMouse and input.UserInputType == Enum.UserInputType.MouseMovement or input == resizeInput
        if not matches then return end
        local delta = input.Position - resizeStartInput
        local effectiveMin, effectiveMax = GetEffectiveBounds(resizeStartTopLeft)
        local width = math.clamp(resizeStartSize.X + delta.X, effectiveMin.X, effectiveMax.X)
        local height = math.clamp(resizeStartSize.Y + delta.Y, effectiveMin.Y, effectiveMax.Y)
        local actualDelta = Vector2.new(width - resizeStartSize.X, height - resizeStartSize.Y)
        mainWindow.Size = UDim2.fromOffset(width, height)
        mainWindow.Position = UDim2.new(
            resizeStartPosition.X.Scale, resizeStartPosition.X.Offset + mainWindow.AnchorPoint.X * actualDelta.X,
            resizeStartPosition.Y.Scale, resizeStartPosition.Y.Offset + mainWindow.AnchorPoint.Y * actualDelta.Y
        )
        windowSize = mainWindow.Size
        if ApplyResponsiveSidebar then ApplyResponsiveSidebar(width) end
    end))

    table.insert(windowConnections, UserInputService.InputEnded:Connect(function(input)
        if input == resizeInput or resizeMouse and input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizing = false
            resizeInput = nil
            resizeMouse = false
        end
    end))

    resizeHandle.MouseEnter:Connect(function()
        if resizeIcon then
            TweenService:Create(resizeIcon, TweenInfo.new(0.12), { ImageColor3 = Accent.Value }):Play()
        else
            TweenService:Create(resizeHandle, TweenInfo.new(0.12), { TextColor3 = Accent.Value }):Play()
        end
    end)
    resizeHandle.MouseLeave:Connect(function()
        if resizeIcon then
            TweenService:Create(resizeIcon, TweenInfo.new(0.12), { ImageColor3 = Theme.TextDim }):Play()
        else
            TweenService:Create(resizeHandle, TweenInfo.new(0.12), { TextColor3 = Theme.TextDim }):Play()
        end
    end)

    Window.ResizeHandle = resizeHandle
    Window.ResizeIcon = resizeIcon
    function Window:SetSize(value)
        local requested = ResolvePixelSize(value, GetLogicalSize())
        return ApplyPixelSize(requested)
    end
    function Window:GetSize()
        return GetLogicalSize()
    end
    function Window:SetMinimumSize(value)
        minimumWindowSize = ResolvePixelSize(value, minimumWindowSize)
        maximumWindowSize = Vector2.new(
            math.max(maximumWindowSize.X, minimumWindowSize.X),
            math.max(maximumWindowSize.Y, minimumWindowSize.Y)
        )
        return ApplyPixelSize(GetLogicalSize())
    end
    function Window:SetMaximumSize(value)
        local requestedMaximum = ResolvePixelSize(value, maximumWindowSize)
        maximumWindowSize = Vector2.new(
            math.max(requestedMaximum.X, minimumWindowSize.X),
            math.max(requestedMaximum.Y, minimumWindowSize.Y)
        )
        return ApplyPixelSize(GetLogicalSize())
    end

    ApplyResponsiveSidebar = function(width)
        if config.SidebarWidth ~= nil then return end
        local minimum = width < 260 and 72 or 96
        local content = width < 260 and 80 or 140
        local desired = width < 560 and math.clamp(math.floor(width * 0.34), minimum, 150) or 180
        desired = math.clamp(desired, minimum, math.max(minimum, width - content))
        if math.abs(desired - sidebarWidth) < 0.5 then return end
        sidebarWidth = desired
        rightOutline.Position = UDim2.fromOffset(sidebarWidth, 0)
        titleBar.Position = UDim2.fromOffset(sidebarWidth + 1, 1)
        titleBar.Size = UDim2.new(1, -sidebarWidth - 2, 0, 48)
        sidebar.Size = UDim2.new(0, sidebarWidth, 1, 0)
        contentArea.Position = UDim2.fromOffset(sidebarWidth + 1, 51)
        contentArea.Size = UDim2.new(1, -sidebarWidth - 2, 1, -52)
        topSeparator.Position = UDim2.fromOffset(sidebarWidth, 50)
        topSeparator.Size = UDim2.new(1, -sidebarWidth, 0, 1)
    end

    local function FitWindowToViewport()
        if not mainWindow.Parent then return end
        local viewport = GetViewportSize()
        local logicalSize = GetLogicalSize()
        local available = Vector2.new(math.max(1, viewport.X - 16), math.max(1, viewport.Y - 16))
        local requestedSize = Vector2.new(
            math.min(logicalSize.X, available.X),
            math.min(logicalSize.Y, available.Y)
        )
        local currentTopLeft = GetLogicalTopLeft(logicalSize)
        local requestedTopLeft = Vector2.new(
            math.clamp(currentTopLeft.X, 8, math.max(8, viewport.X - requestedSize.X - 8)),
            math.clamp(currentTopLeft.Y, 8, math.max(8, viewport.Y - requestedSize.Y - 8))
        )
        logicalSize = ApplyPixelSize(requestedSize, requestedTopLeft)
        local topLeft = GetLogicalTopLeft(logicalSize)
        local maxX = math.max(8, viewport.X - logicalSize.X - 8)
        local maxY = math.max(8, viewport.Y - logicalSize.Y - 8)
        local desiredTopLeft = Vector2.new(
            math.clamp(topLeft.X, 8, maxX),
            math.clamp(topLeft.Y, 8, maxY)
        )
        local delta = desiredTopLeft - topLeft
        if delta.X ~= 0 or delta.Y ~= 0 then
            local position = mainWindow.Position
            mainWindow.Position = UDim2.new(
                position.X.Scale, position.X.Offset + delta.X,
                position.Y.Scale, position.Y.Offset + delta.Y
            )
        end
    end

    if config.Responsive ~= false then
        local viewportConnection = nil
        local function BindViewport()
            if viewportConnection then viewportConnection:Disconnect() end
            local camera = workspace.CurrentCamera
            if camera then
                viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
                    task.defer(FitWindowToViewport)
                end)
                table.insert(windowConnections, viewportConnection)
            end
            task.defer(FitWindowToViewport)
        end
        table.insert(windowConnections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(BindViewport))
        BindViewport()
    end

    local notifyHolder = NewInstance("Frame", {
        Name = "NotifyHolder",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(260, 500),
        ZIndex = 300,
        Parent = ScreenGui,
    })

    NewInstance("UIListLayout", {
        Padding = UDim.new(0, 8),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = notifyHolder,
    })

    local floatingGuis = {}

    local function CreateFloatingButton(cfg, forceToggle)
        cfg = cfg or {}
        local isToggle = forceToggle == true or cfg.Toggle == true
        local minSize = cfg.MinSize or 40
        local maxSize = cfg.MaxSize or 200
        local size = math.clamp(cfg.Size or 90, minSize, maxSize)
        local radius = cfg.Radius or 6
        local threshold = cfg.DragThreshold or 10

        local state = cfg.Default == true

        local floatingGui = NewInstance("ScreenGui", {
            Name = "LurkFloating",
            ResetOnSpawn = false,
            IgnoreGuiInset = false,
            DisplayOrder = 1000000,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        })
        ProtectGui(floatingGui)
        floatingGui.Parent = GuiParent
        table.insert(floatingGuis, floatingGui)

        local btn = NewInstance("TextButton", {
            Name = "FloatingButton",
            Size = UDim2.fromOffset(size, size),
            Position = cfg.Position or UDim2.new(0.5, -size / 2, 0.6, 0),
            BackgroundColor3 = Theme.Popup,
            BackgroundTransparency = Theme.PopupTransparency,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = cfg.Icon and "" or (cfg.Text or ""),
            TextColor3 = Theme.TextBright,
            TextScaled = true,
            TextWrapped = true,
            Font = Enum.Font.GothamBold,
            Active = true,
            Selectable = true,
            ZIndex = 250,
            Parent = floatingGui,
        })

        NewInstance("UICorner", { CornerRadius = UDim.new(0, radius), Parent = btn })

        local floatingIcon = nil
        if cfg.Icon then
            floatingIcon = CreateWindowIcon(btn, cfg.Icon, {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Pixels = math.max(16, math.min(size - 12, tonumber(cfg.IconSize) or size * 0.42)),
                Color = Theme.TextBright,
                ZIndex = btn.ZIndex + 1,
            })
            if not floatingIcon then btn.Text = cfg.Text or "" end
        end

        NewInstance("UIPadding", {
            PaddingLeft = UDim.new(0, 6),
            PaddingRight = UDim.new(0, 6),
            PaddingTop = UDim.new(0, 6),
            PaddingBottom = UDim.new(0, 6),
            Parent = btn,
        })

        NewInstance("UITextSizeConstraint", { MaxTextSize = 22, MinTextSize = 8, Parent = btn })

        local stroke = NewInstance("UIStroke", {
            Thickness = 1.5,
            Color = Theme.Border,
            Transparency = 0,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Parent = btn,
        })

        local handle = {}
        handle.Gui = floatingGui
        handle.Button = btn
        handle.Stroke = stroke
        handle.Icon = floatingIcon

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
            if isToggle and state then
                btn.BackgroundColor3 = Accent.Value
                btn.TextColor3 = Theme.TextBright
                stroke.Color = Accent.Value
                stroke.Transparency = 0
                if floatingIcon then floatingIcon.ImageColor3 = Theme.TextBright end
                if isToggle and not floatingIcon then btn.Text = cfg.OnText or baseText end
            else
                btn.BackgroundColor3 = Theme.Popup
                btn.TextColor3 = Theme.TextBright
                stroke.Color = Theme.Border
                stroke.Transparency = 0
                if floatingIcon then floatingIcon.ImageColor3 = Theme.Text end
                if isToggle and not floatingIcon then btn.Text = cfg.OffText or baseText end
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
            baseText = text or ""
            if not floatingIcon then btn.Text = baseText end
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
        local duration = math.max(0.25, tonumber(cfg.Duration) or 4)

        local card = NewInstance("Frame", {
            BackgroundColor3 = Theme.Window,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            ZIndex = notifyHolder.ZIndex + 1,
            Parent = notifyHolder,
        })

        NewInstance("UICorner", {
            CornerRadius = UDim.new(0, Theme.PopupRounding),
            Parent = card,
        })

        local cardStroke = NewInstance("UIStroke", {
            Color = Theme.Border,
            Thickness = 1,
            Transparency = 1,
            Parent = card,
        })

        NewInstance("UIPadding", {
            PaddingTop = UDim.new(0, 15),
            PaddingBottom = UDim.new(0, 15),
            PaddingLeft = UDim.new(0, 15),
            PaddingRight = UDim.new(0, 15),
            Parent = card,
        })

        NewInstance("UIListLayout", {
            Padding = UDim.new(0, 2),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = card,
        })

        local titleLabel = NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(1, 0, 0, 0),
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            TextColor3 = Theme.TextBright,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            Text = title,
            TextTransparency = 1,
            ZIndex = card.ZIndex + 1,
            Parent = card,
        })

        local notificationIcon = nil
        if cfg.Icon then
            notificationIcon = CreateWindowIcon(titleLabel, cfg.Icon, {
                Pixels = 16,
                Position = UDim2.new(0, -24, 0.5, 0),
                Color = cfg.IconColor or Accent.Value,
                Transparency = 1,
                ZIndex = titleLabel.ZIndex + 1,
            })
            if notificationIcon then
                NewInstance("UIPadding", {
                    PaddingLeft = UDim.new(0, 24),
                    Parent = titleLabel,
                })
            end
        end

        local bodyLabel = NewInstance("TextLabel", {
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(1, 0, 0, 0),
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            Text = content,
            TextTransparency = 1,
            ZIndex = card.ZIndex + 1,
            Parent = card,
        })

        TweenService:Create(card, TweenInfo.new(0.2), { BackgroundTransparency = Theme.WindowTransparency }):Play()
        TweenService:Create(cardStroke, TweenInfo.new(0.2), { Transparency = 0 }):Play()
        TweenService:Create(titleLabel, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
        TweenService:Create(bodyLabel, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
        if notificationIcon then
            TweenService:Create(notificationIcon, TweenInfo.new(0.2), { ImageTransparency = 0 }):Play()
        end

        task.delay(duration, function()
            if not card.Parent then return end
            TweenService:Create(card, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
            TweenService:Create(cardStroke, TweenInfo.new(0.25), { Transparency = 1 }):Play()
            TweenService:Create(titleLabel, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
            if notificationIcon then
                TweenService:Create(notificationIcon, TweenInfo.new(0.25), { ImageTransparency = 1 }):Play()
            end
            local fade = TweenService:Create(bodyLabel, TweenInfo.new(0.25), { TextTransparency = 1 })
            fade:Play()
            fade.Completed:Connect(function()
                card:Destroy()
            end)
        end)

        return card
    end

    function Window:Destroy()
        menuTransition = menuTransition + 1
        tabTransition = tabTransition + 1
        resizing = false
        if menuFadeTween then menuFadeTween:Cancel() end
        if menuScaleTween then menuScaleTween:Cancel() end
        for _, tween in ipairs(tabContentTweens) do tween:Cancel() end
        table.clear(tabContentTweens)
        for _, connection in ipairs(windowConnections) do
            pcall(function() connection:Disconnect() end)
        end
        table.clear(windowConnections)
        for _, gui in ipairs(floatingGuis) do
            pcall(function()
                gui:Destroy()
            end)
        end
        table.clear(floatingGuis)
        pcall(function()
            Accent._bindable:Destroy()
        end)
        ScreenGui:Destroy()
    end

    return Window
end

local Lurk = {}

function Lurk:LoadIcons(source)
    return LoadIconAtlas(source or DEFAULT_ICON_URL)
end

function Lurk:GetIcon(name, source, sheetName)
    if source == "48px" or source == "256px" or source == 256 then
        sheetName, source = source, nil
    end
    local atlas = LoadIconAtlas(source or DEFAULT_ICON_URL)
    local descriptor = ResolveIcon(atlas, name, sheetName or "48px")
    if not descriptor then return nil, nil, nil end
    return descriptor.Image, descriptor.Offset, descriptor.Size
end

function Lurk:CreateIcon(parent, name, config)
    config = config or {}
    local atlas = LoadIconAtlas(config.Icons or config.IconURL or DEFAULT_ICON_URL)
    return CreateAtlasIcon(atlas, parent, name, config)
end

function Lurk:CreateWindow(config)
    return CreateWindow(config)
end

return Lurk
