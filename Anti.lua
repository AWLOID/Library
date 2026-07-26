local Players            = game:GetService("Players")
local TweenService       = game:GetService("TweenService")
local UserInputService    = game:GetService("UserInputService")
local RunService         = game:GetService("RunService")
local HttpService        = game:GetService("HttpService")
local GuiService         = game:GetService("GuiService")

local Lighting, StatsService
pcall(function() Lighting = game:GetService("Lighting") end)
pcall(function() StatsService = game:GetService("Stats") end)

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    Players.PlayerAdded:Wait()
    LocalPlayer = Players.LocalPlayer
end

local GuiParent
do
    local ok, hui = pcall(function()
        if typeof(gethui) == "function" then return gethui() end
        return nil
    end)
    if ok and hui then
        GuiParent = hui
    else
        local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
        if ok2 and cg then

            local ok3 = pcall(function()
                local probe = Instance.new("Folder")
                probe.Parent = cg
                probe:Destroy()
            end)
            GuiParent = ok3 and cg or nil
        end
    end
    if not GuiParent then
        GuiParent = LocalPlayer:WaitForChild("PlayerGui")
    end
end

local function ProtectGui(gui)
    pcall(function()
        if typeof(syn) == "table" and syn.protect_gui then
            syn.protect_gui(gui)
        elseif typeof(protect_gui) == "function" then
            protect_gui(gui)
        elseif typeof(protectgui) == "function" then
            protectgui(gui)
        end
    end)
end

local FS = { Enabled = false }
do
    local ok = pcall(function()
        return typeof(writefile) == "function"
            and typeof(readfile) == "function"
            and typeof(isfile) == "function"
    end)
    if ok and typeof(writefile) == "function" and typeof(readfile) == "function" then
        FS.Enabled = true
        FS.Write   = writefile
        FS.Read    = readfile
        FS.IsFile  = (typeof(isfile) == "function") and isfile or function() return true end
        FS.IsDir   = (typeof(isfolder) == "function") and isfolder or function() return true end
        FS.MakeDir = (typeof(makefolder) == "function") and makefolder or function() end
        FS.ListDir = (typeof(listfiles) == "function") and listfiles or function() return {} end
        FS.Delete  = (typeof(delfile) == "function") and delfile or function() end
    end
end

local Util = {}

local function New(className, props, children)
    local inst = Instance.new(className)
    local parent
    if props then
        parent = props.Parent
        props.Parent = nil

        local ok = pcall(function()
            for key, value in pairs(props) do
                inst[key] = value
            end
        end)
        if not ok then
            for key, value in pairs(props) do
                pcall(function() inst[key] = value end)
            end
        end
    end
    if children then
        for _, child in ipairs(children) do
            child.Parent = inst
        end
    end
    if parent then
        inst.Parent = parent
    end
    return inst
end
Util.New = New

local function Clamp01(n) return math.clamp(n, 0, 1) end
local function Lerp(a, b, t) return a + (b - a) * t end

local function RoundTo(value, step)
    if not step or step <= 0 then return value end
    local v = math.floor(value / step + 0.5) * step
    return math.floor(v * 1e6 + 0.5) / 1e6
end

local function Trim(s)
    return (tostring(s):gsub("^%s*(.-)%s*$", "%1"))
end

local function FormatNumber(n, decimals)
    if decimals and decimals > 0 then
        return string.format("%." .. decimals .. "f", n)
    end
    if math.abs(n - math.floor(n + 0.5)) < 1e-6 then
        return tostring(math.floor(n + 0.5))
    end
    return string.format("%.2f", n)
end

local function SafeCall(fn, ...)
    if typeof(fn) ~= "function" then return end
    local args = table.pack(...)
    task.spawn(function()
        local ok, err = pcall(function()
            fn(table.unpack(args, 1, args.n))
        end)
        if not ok then
            warn("[Lurk] Callback error: " .. tostring(err))
        end
    end)
end

local function KeyName(keycode)
    if not keycode then return "None" end
    if typeof(keycode) == "EnumItem" then
        local n = keycode.Name
        local map = {
            LeftControl = "LCtrl", RightControl = "RCtrl",
            LeftShift = "LShift", RightShift = "RShift",
            LeftAlt = "LAlt", RightAlt = "RAlt",
            MouseButton1 = "MB1", MouseButton2 = "MB2", MouseButton3 = "MB3",
        }
        return map[n] or n
    end
    return tostring(keycode)
end

local function PointInside(guiObject, x, y)
    if not guiObject or not guiObject.Parent then return false end
    local pos = guiObject.AbsolutePosition
    local size = guiObject.AbsoluteSize
    return x >= pos.X and x <= pos.X + size.X and y >= pos.Y and y <= pos.Y + size.Y
end

local function ViewportSize()
    local cam = workspace.CurrentCamera
    if cam then return cam.ViewportSize end
    return Vector2.new(1280, 720)
end

local SHARP = true

local function Corner(inst, radius)
    radius = radius or 6
    if SHARP then
        if radius >= 100 then
            radius = 999
        elseif radius > 4 then
            radius = 0
        end
    end
    return New("UICorner", { CornerRadius = UDim.new(0, radius), Parent = inst })
end

local function Padding(inst, top, bottom, left, right)
    return New("UIPadding", {
        PaddingTop = UDim.new(0, top or 0),
        PaddingBottom = UDim.new(0, bottom or top or 0),
        PaddingLeft = UDim.new(0, left or top or 0),
        PaddingRight = UDim.new(0, right or left or top or 0),
        Parent = inst,
    })
end

local function ListLayout(inst, padding, dir)
    return New("UIListLayout", {
        Padding = UDim.new(0, padding or 6),
        FillDirection = dir or Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = inst,
    })
end

local Signal = {}
Signal.__index = Signal

function Signal.new()
    return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn)
    local handler = { Fn = fn, Alive = true }
    table.insert(self._handlers, handler)
    local self_ref = self
    return {
        Connected = true,
        Disconnect = function()
            handler.Alive = false
            for i, h in ipairs(self_ref._handlers) do
                if h == handler then
                    table.remove(self_ref._handlers, i)
                    break
                end
            end
        end,
    }
end

function Signal:Fire(...)
    local snapshot = table.clone(self._handlers)
    for _, handler in ipairs(snapshot) do
        if handler.Alive then
            local ok, err = pcall(handler.Fn, ...)
            if not ok then warn("[Lurk] Signal: " .. tostring(err)) end
        end
    end
end

function Signal:Destroy()
    table.clear(self._handlers)
end

local InputMgr = {}
InputMgr.Sessions = {}

local function InputIsMove(input)
    return input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
end

local function SessionMatches(session, input)
    if input == session.Input then return true end
    if session.Input.UserInputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseMovement then
        return true
    end
    return false
end

local function StopSession(session, position)
    if not session or not session.Alive then return end
    session.Alive = false
    for i = #InputMgr.Sessions, 1, -1 do
        if InputMgr.Sessions[i] == session then
            table.remove(InputMgr.Sessions, i)
            break
        end
    end
    if session.OnEnd then
        local ok, err = pcall(session.OnEnd, position or session.LastPos, session)
        if not ok then warn("[Lurk] DragEnd: " .. tostring(err)) end
    end
end

function InputMgr.Start(input, handlers)
    local session = {
        Input = input,
        OnMove = handlers.OnMove,
        OnEnd = handlers.OnEnd,
        StartPos = input.Position,
        LastPos = input.Position,
        Moved = false,
        Threshold = handlers.Threshold or 0,
        Alive = true,
        Data = handlers.Data,
    }
    table.insert(InputMgr.Sessions, session)
    return session
end

UserInputService.InputChanged:Connect(function(input)
    if #InputMgr.Sessions == 0 then return end
    if not InputIsMove(input) then return end
    for i = #InputMgr.Sessions, 1, -1 do
        local session = InputMgr.Sessions[i]
        if session.Alive and SessionMatches(session, input) then
            session.LastPos = input.Position
            local delta = input.Position - session.StartPos
            if not session.Moved and delta.Magnitude > session.Threshold then
                session.Moved = true
            end
            if session.OnMove then
                local ok, err = pcall(session.OnMove, input.Position, session)
                if not ok then warn("[Lurk] Drag: " .. tostring(err)) end
            end
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if #InputMgr.Sessions == 0 then return end
    for i = #InputMgr.Sessions, 1, -1 do
        local session = InputMgr.Sessions[i]
        if session.Alive then
            local same = (session.Input == input)
            local mouseUp = session.Input.UserInputType == Enum.UserInputType.MouseButton1
                and input.UserInputType == Enum.UserInputType.MouseButton1
            if same or mouseUp then
                StopSession(session, input.Position)
            end
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if #InputMgr.Sessions == 0 then return end
    for i = #InputMgr.Sessions, 1, -1 do
        local session = InputMgr.Sessions[i]
        if session.Alive and session.Input.UserInputState == Enum.UserInputState.End then
            StopSession(session, session.LastPos)
        end
    end
end)

function InputMgr.Bind(gui, handlers)
    return gui.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        if handlers.Enabled and handlers.Enabled() == false then return end
        local session = InputMgr.Start(input, handlers)
        if handlers.OnBegin then
            local ok, err = pcall(handlers.OnBegin, input.Position, session)
            if not ok then warn("[Lurk] DragBegin: " .. tostring(err)) end
        end
    end)
end

local Anim = {}

Anim.Speed = 1

local STYLE = {
    Smooth = { Enum.EasingStyle.Quart, Enum.EasingDirection.Out },
    Fast   = { Enum.EasingStyle.Quad,  Enum.EasingDirection.Out },
    Pop    = { Enum.EasingStyle.Back,  Enum.EasingDirection.Out },
    Snap   = { Enum.EasingStyle.Quint, Enum.EasingDirection.Out },
    In     = { Enum.EasingStyle.Quart, Enum.EasingDirection.In },
    Linear = { Enum.EasingStyle.Linear, Enum.EasingDirection.Out },
}

local function Tween(obj, props, duration, styleName)
    if not obj or not obj.Parent then

        if obj then
            for k, v in pairs(props) do pcall(function() obj[k] = v end) end
        end
        return nil
    end
    local style = STYLE[styleName or "Smooth"] or STYLE.Smooth
    local dur = (duration or 0.18) * Anim.Speed
    if dur <= 0.001 then
        for k, v in pairs(props) do pcall(function() obj[k] = v end) end
        return nil
    end
    local info = TweenInfo.new(dur, style[1], style[2])
    local tween = TweenService:Create(obj, info, props)
    tween:Play()
    return tween
end
Anim.Tween = Tween

local function Ripple(button, x, y, color)
    if not button or not button.Parent then return end
    local abs = button.AbsolutePosition
    local size = button.AbsoluteSize
    local localX = (x or (abs.X + size.X / 2)) - abs.X
    local localY = (y or (abs.Y + size.Y / 2)) - abs.Y
    local maxDist = math.max(
        math.sqrt(localX ^ 2 + localY ^ 2),
        math.sqrt((size.X - localX) ^ 2 + localY ^ 2),
        math.sqrt(localX ^ 2 + (size.Y - localY) ^ 2),
        math.sqrt((size.X - localX) ^ 2 + (size.Y - localY) ^ 2)
    )
    local circle = New("Frame", {
        Name = "Ripple",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(localX, localY),
        Size = UDim2.fromOffset(0, 0),
        BackgroundColor3 = color or Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.75,
        BorderSizePixel = 0,
        ZIndex = button.ZIndex + 1,
        Parent = button,
    })
    Corner(circle, 999)
    local t = Tween(circle, {
        Size = UDim2.fromOffset(maxDist * 2.1, maxDist * 2.1),
        BackgroundTransparency = 1,
    }, 0.45, "Fast")
    if t then
        t.Completed:Connect(function() circle:Destroy() end)
    else
        circle:Destroy()
    end
end
Anim.Ripple = Ripple

local function Hover(obj, onEnter, onLeave)
    local entered = false
    obj.MouseEnter:Connect(function()
        if entered then return end
        entered = true
        if onEnter then onEnter() end
    end)
    obj.MouseLeave:Connect(function()
        if not entered then return end
        entered = false
        if onLeave then onLeave() end
    end)
    obj.AncestryChanged:Connect(function(_, parent)
        if not parent and entered then
            entered = false
            if onLeave then onLeave() end
        end
    end)
end
Anim.Hover = Hover

local PALETTES = {
    Dark = {
        Base     = Color3.fromRGB(12, 12, 12),
        Bevel    = Color3.fromRGB(40, 40, 40),
        Surface  = Color3.fromRGB(20, 20, 20),
        Surface2 = Color3.fromRGB(16, 16, 16),
        Surface3 = Color3.fromRGB(30, 30, 30),
        Border   = Color3.fromRGB(60, 60, 60),
        Text     = Color3.fromRGB(200, 200, 200),
        SubText  = Color3.fromRGB(170, 170, 170),
        Muted    = Color3.fromRGB(120, 120, 120),
        Good     = Color3.fromRGB(90, 200, 110),
        Warn     = Color3.fromRGB(235, 180, 70),
        Bad      = Color3.fromRGB(235, 70, 70),
    },
    Midnight = {
        Bevel    = Color3.fromRGB(38, 44, 68),
        Base     = Color3.fromRGB(9, 11, 20),
        Surface  = Color3.fromRGB(16, 19, 33),
        Surface2 = Color3.fromRGB(23, 27, 45),
        Surface3 = Color3.fromRGB(31, 36, 58),
        Border   = Color3.fromRGB(46, 53, 82),
        Text     = Color3.fromRGB(228, 233, 250),
        SubText  = Color3.fromRGB(140, 150, 180),
        Muted    = Color3.fromRGB(95, 104, 132),
        Good     = Color3.fromRGB(72, 205, 155),
        Warn     = Color3.fromRGB(245, 190, 80),
        Bad      = Color3.fromRGB(240, 90, 110),
    },
    Light = {
        Bevel    = Color3.fromRGB(210, 213, 222),
        Base     = Color3.fromRGB(238, 239, 243),
        Surface  = Color3.fromRGB(248, 249, 252),
        Surface2 = Color3.fromRGB(232, 234, 240),
        Surface3 = Color3.fromRGB(220, 223, 231),
        Border   = Color3.fromRGB(198, 202, 212),
        Text     = Color3.fromRGB(25, 27, 32),
        SubText  = Color3.fromRGB(95, 100, 112),
        Muted    = Color3.fromRGB(140, 145, 158),
        Good     = Color3.fromRGB(38, 160, 90),
        Warn     = Color3.fromRGB(200, 140, 20),
        Bad      = Color3.fromRGB(210, 55, 60),
    },
    Mono = {
        Bevel    = Color3.fromRGB(45, 45, 45),
        Base     = Color3.fromRGB(0, 0, 0),
        Surface  = Color3.fromRGB(14, 14, 14),
        Surface2 = Color3.fromRGB(22, 22, 22),
        Surface3 = Color3.fromRGB(32, 32, 32),
        Border   = Color3.fromRGB(55, 55, 55),
        Text     = Color3.fromRGB(240, 240, 240),
        SubText  = Color3.fromRGB(155, 155, 155),
        Muted    = Color3.fromRGB(100, 100, 100),
        Good     = Color3.fromRGB(190, 190, 190),
        Warn     = Color3.fromRGB(215, 215, 215),
        Bad      = Color3.fromRGB(255, 255, 255),
    },
}

local function CreateTheme(config)
    local T = {}
    T.PaletteName = config.Palette or "Dark"
    T.Colors = table.clone(PALETTES[T.PaletteName] or PALETTES.Dark)
    T.Colors.Accent = config.AccentColor or Color3.fromRGB(255, 30, 30)

    T.Alpha = {
        Fill   = config.Transparency or 0,
        Text   = config.TextTransparency or 0,
        Stroke = config.StrokeTransparency or 0,
        Float  = config.FloatTransparency or 0,
    }

    T.Paints = {}
    T.Fades  = {}
    T.Changed = Signal.new()
    T.AlphaChanged = Signal.new()

    local pendingApply = false
    local lastPrune = 0

    local function EffectiveValue(base, group)
        local alpha = T.Alpha[group] or 0
        return 1 - (1 - base) * (1 - alpha)
    end
    T.Eff = EffectiveValue

    function T.Paint(inst, prop, role)
        local entry = { Object = inst, Prop = prop, Role = role }
        table.insert(T.Paints, entry)
        local color = T.Colors[role]
        if color then
            pcall(function() inst[prop] = color end)
        end
        return entry
    end

    function T.Fade(inst, prop, base, group)
        group = group or "Fill"
        local entry = { Object = inst, Prop = prop, Base = base or 0, Group = group }
        table.insert(T.Fades, entry)
        pcall(function() inst[prop] = EffectiveValue(entry.Base, group) end)

        function entry.Target(overrideBase)
            return EffectiveValue(overrideBase or entry.Base, entry.Group)
        end
        function entry.SetBase(value, animate, duration)
            entry.Base = value
            local target = EffectiveValue(value, entry.Group)
            if animate then
                Tween(inst, { [prop] = target }, duration or 0.14, "Fast")
            else
                pcall(function() inst[prop] = target end)
            end
        end
        function entry.Apply()
            pcall(function() inst[prop] = EffectiveValue(entry.Base, entry.Group) end)
        end
        return entry
    end

    local function Prune()
        local now = os.clock()
        if now - lastPrune < 2 then return end
        lastPrune = now
        for i = #T.Fades, 1, -1 do
            local obj = T.Fades[i].Object
            if not obj or not obj:IsDescendantOf(game) then
                table.remove(T.Fades, i)
            end
        end
        for i = #T.Paints, 1, -1 do
            local obj = T.Paints[i].Object
            if not obj or not obj:IsDescendantOf(game) then
                table.remove(T.Paints, i)
            end
        end
    end

    local function ApplyAlphaNow()
        pendingApply = false
        Prune()
        for _, entry in ipairs(T.Fades) do
            pcall(function()
                entry.Object[entry.Prop] = EffectiveValue(entry.Base, entry.Group)
            end)
        end
        T.AlphaChanged:Fire(T.Alpha)
    end

    local function ScheduleApply()
        if pendingApply then return end
        pendingApply = true
        task.defer(ApplyAlphaNow)
    end

    function T.SetAlpha(group, value)
        T.Alpha[group] = Clamp01(value)
        ScheduleApply()
    end

    function T.GetAlpha(group)
        return T.Alpha[group] or 0
    end

    function T.SetColor(role, color)
        T.Colors[role] = color
        for _, entry in ipairs(T.Paints) do
            if entry.Role == role then
                pcall(function() entry.Object[entry.Prop] = color end)
            end
        end
        T.Changed:Fire(role, color)
    end

    function T.SetAccent(color)
        T.SetColor("Accent", color)
    end

    function T.SetPalette(name)
        local palette = PALETTES[name]
        if not palette then return false end
        T.PaletteName = name
        for role, color in pairs(palette) do
            T.Colors[role] = color
        end
        for _, entry in ipairs(T.Paints) do
            local color = T.Colors[entry.Role]
            if color then
                pcall(function() entry.Object[entry.Prop] = color end)
            end
        end
        T.Changed:Fire("Palette", name)
        return true
    end

    function T.PaletteList()
        local list = {}
        for name in pairs(PALETTES) do table.insert(list, name) end
        table.sort(list)
        return list
    end

    function T.Accent() return T.Colors.Accent end

    function T.Destroy()
        table.clear(T.Paints)
        table.clear(T.Fades)
        T.Changed:Destroy()
        T.AlphaChanged:Destroy()
    end

    return T
end

local OverlayRegistry = {}

local function RegisterOverlay(entry)
    table.insert(OverlayRegistry, entry)
    return entry
end

local function PruneOverlays()
    for i = #OverlayRegistry, 1, -1 do
        local entry = OverlayRegistry[i]
        if not entry.Holder or not entry.Holder:IsDescendantOf(game) then
            table.remove(OverlayRegistry, i)
        end
    end
end

local function CloseAllOverlays(except)
    PruneOverlays()
    for _, entry in ipairs(OverlayRegistry) do
        if entry.Holder ~= except and entry.IsOpen() then
            entry.Close()
        end
    end
end

UserInputService.InputBegan:Connect(function(input, processed)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    PruneOverlays()
    if #OverlayRegistry == 0 then return end
    local pos = input.Position
    for _, entry in ipairs(OverlayRegistry) do
        if entry.IsOpen() then
            local insideHolder = PointInside(entry.Holder, pos.X, pos.Y)
            local insideTrigger = entry.Trigger and PointInside(entry.Trigger, pos.X, pos.Y)
            if not insideHolder and not insideTrigger then
                entry.Close()
            end
        end
    end
end)

local ActiveKeybindCapture = nil

local ELEMENT_NAMES = {
    "Label", "Paragraph", "Section", "Divider", "Spacer",
    "Button", "DoubleButton", "Toggle", "Checkbox", "Switch",
    "Slider", "RangeSlider", "Stepper", "ToggleSlider", "Rating",
    "Dropdown", "MultiDropdown", "SearchableDropdown", "PlayerDropdown",
    "RadioGroup", "Segmented", "Chips", "ColorPicker",
    "Textbox", "Input", "TextArea", "Keybind",
    "ProgressBar", "Spinner", "Image", "Avatar",
    "KeyValue", "Badge", "Stat", "Graph", "Console",
    "ListView", "Table", "Group", "Card",
}

local function CreateFactory(ctx)
    local T = ctx.Theme
    local Factory = {}

    local function Cfg(config, textKey)
        if typeof(config) == "string" or typeof(config) == "number" then
            local t = {}
            t[textKey or "Text"] = tostring(config)
            return t
        end
        return config or {}
    end

    local function Dual(api, name, fn)
        api[name] = function(...)
            local args = table.pack(...)
            if args.n > 0 and args[1] == api then
                return fn(table.unpack(args, 2, args.n))
            end
            return fn(table.unpack(args, 1, args.n))
        end
    end

    local function Root(parent, name, cfg, height)
        local props = {
            Name = name,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, height or 0),
            LayoutOrder = cfg.LayoutOrder or 0,
            Visible = cfg.Visible ~= false,
            Parent = parent,
        }
        if not height then
            props.AutomaticSize = Enum.AutomaticSize.Y
        end
        return New("Frame", props)
    end

    local function Surface(parent, props, colorRole, strokeAlpha)
        local frame = New("Frame", props)
        T.Paint(frame, "BackgroundColor3", colorRole or "Surface2")
        local fade = T.Fade(frame, "BackgroundTransparency", props.BackgroundTransparency or 0, "Fill")
        Corner(frame, props.CornerRadius or 6)
        local stroke = New("UIStroke", {
            Thickness = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Parent = frame,
        })
        T.Paint(stroke, "Color", "Border")
        local strokeFade = T.Fade(stroke, "Transparency", strokeAlpha or 0.25, "Stroke")
        return frame, fade, stroke, strokeFade
    end

    local function Text(parent, props, role, group)
        local label = New("TextLabel", props)
        T.Paint(label, "TextColor3", role or "Text")
        T.Fade(label, "TextTransparency", props.TextTransparency or 0, group or "Text")
        return label
    end

    local function LabelledRow(parent, cfg, name, height, rightWidth)
        height = height or 32
        local root = Root(parent, name, cfg, height)
        local card, cardFade, stroke, strokeFade = Surface(root, {
            Size = UDim2.fromScale(1, 1),
            BorderSizePixel = 0,
            Parent = root,
        }, "Surface2", 0.35)

        Padding(card, 0, 0, 10, 8)

        local title = Text(card, {
            Name = "Title",
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0),
            Size = UDim2.new(1, -(rightWidth or 60), 1, 0),
            Font = Enum.Font.GothamMedium,
            TextSize = cfg.TextSize or 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Text = cfg.Name or cfg.Text or "",
            Parent = card,
        }, "Text")

        Anim.Hover(card, function()
            Tween(card, { BackgroundColor3 = T.Colors.Surface3 }, 0.16, "Fast")
            strokeFade.SetBase(0.05, true)
        end, function()
            Tween(card, { BackgroundColor3 = T.Colors.Surface2 }, 0.2, "Fast")
            strokeFade.SetBase(0.35, true)
        end)

        return root, card, title, cardFade, stroke, strokeFade
    end

    local function Finish(api, root, cfg)
        api.Instance = root
        api.Type = api.Type or "Element"

        Dual(api, "SetVisible", function(value)
            root.Visible = value ~= false
        end)
        Dual(api, "SetLayoutOrder", function(order)
            root.LayoutOrder = order or 0
        end)
        Dual(api, "Destroy", function()
            if api.OnDestroy then pcall(api.OnDestroy) end
            root:Destroy()
        end)
        Dual(api, "GetInstance", function() return root end)

        if cfg.Tooltip and ctx.AttachTooltip then
            ctx.AttachTooltip(root, cfg.Tooltip)
        end
        if cfg.Flag and ctx.RegisterFlag then
            ctx.RegisterFlag(cfg.Flag, api)
        end
        if cfg.Visible == false then
            root.Visible = false
        end
        return api
    end

    local function FireCallback(cfg, api, ...)
        SafeCall(cfg.Callback, ...)
        if cfg.Flag and ctx.SetFlagValue then
            ctx.SetFlagValue(cfg.Flag, ...)
        end
        if api and api.Changed then api.Changed:Fire(...) end
    end

    local function Click(button, cfg, onClick)
        button.MouseButton1Click:Connect(function()
            if button:GetAttribute("Locked") then return end
            if ctx.PlaySound then ctx.PlaySound("Click") end
            onClick()
        end)
        button.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                if button:GetAttribute("Locked") then return end
                if cfg.Ripple ~= false then
                    Ripple(button, input.Position.X, input.Position.Y, T.Colors.Accent)
                end
            end
        end)
    end

    Factory._Helpers = {
        Cfg = Cfg, Dual = Dual, Root = Root, Surface = Surface,
        Text = Text, LabelledRow = LabelledRow, Finish = Finish,
        FireCallback = FireCallback, Click = Click,
    }

    function Factory.Label(parent, config)
        local cfg = Cfg(config, "Text")
        local root = Root(parent, "Label", cfg)
        local label = Text(root, {
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(1, 0, 0, 0),
            Font = cfg.Font or Enum.Font.GothamMedium,
            TextSize = cfg.TextSize or 14,
            TextXAlignment = cfg.Center and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
            TextWrapped = true,
            Text = tostring(cfg.Text or cfg.Name or ""),
            Parent = root,
        }, cfg.Color and nil or (cfg.Muted and "SubText" or "Text"))

        if cfg.Color then
            label.TextColor3 = cfg.Color
        end

        local api = { Type = "Label" }
        Dual(api, "Set", function(value)
            label.Text = tostring(value)
        end)
        Dual(api, "Get", function() return label.Text end)
        Dual(api, "SetColor", function(color) label.TextColor3 = color end)
        return Finish(api, root, cfg)
    end

    function Factory.Paragraph(parent, config)
        local cfg = Cfg(config, "Text")
        local root = Root(parent, "Paragraph", cfg)
        local card, cardFade = Surface(root, {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BorderSizePixel = 0,
            Parent = root,
        }, "Surface2", 0.4)
        Padding(card, 9, 9, 11, 11)
        ListLayout(card, 3)

        local title
        if cfg.Title then
            title = Text(card, {
                BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.Y,
                Size = UDim2.new(1, 0, 0, 0),
                Font = Enum.Font.GothamBold,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
                Text = cfg.Title,
                Parent = card,
            }, "Text")
        end

        local body = Text(card, {
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(1, 0, 0, 0),
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            Text = tostring(cfg.Text or ""),
            Parent = card,
        }, "SubText")

        local api = { Type = "Paragraph" }
        Dual(api, "Set", function(value) body.Text = tostring(value) end)
        Dual(api, "SetText", function(value) body.Text = tostring(value) end)
        Dual(api, "SetTitle", function(value)
            if title then title.Text = tostring(value) end
        end)
        Dual(api, "Get", function() return body.Text end)
        return Finish(api, root, cfg)
    end

    function Factory.Section(parent, config)
        local cfg = Cfg(config, "Text")
        local root = Root(parent, "Section", cfg, 22)

        local label = Text(root, {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = string.upper(tostring(cfg.Text or cfg.Name or "")),
            Parent = root,
        }, "Accent")

        local line = New("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.new(1, 0, 0, 1),
            BorderSizePixel = 0,
            Parent = root,
        })
        T.Paint(line, "BackgroundColor3", "Border")
        T.Fade(line, "BackgroundTransparency", 0.2, "Stroke")

        local function Resize()
            line.Size = UDim2.new(1, -(label.AbsoluteSize.X + 10), 0, 1)
        end
        label:GetPropertyChangedSignal("AbsoluteSize"):Connect(Resize)
        task.defer(Resize)

        local api = { Type = "Section" }
        Dual(api, "Set", function(value)
            label.Text = string.upper(tostring(value))
        end)
        return Finish(api, root, cfg)
    end

    function Factory.Divider(parent, config)
        local cfg = Cfg(config)
        local root = Root(parent, "Divider", cfg, cfg.Height or 9)
        local line = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(1, 0, 0, 1),
            BorderSizePixel = 0,
            Parent = root,
        })
        T.Paint(line, "BackgroundColor3", "Border")
        T.Fade(line, "BackgroundTransparency", 0.15, "Stroke")
        local api = { Type = "Divider" }
        return Finish(api, root, cfg)
    end

    function Factory.Spacer(parent, config)
        local cfg = Cfg(config, "Height")
        local height = tonumber(cfg.Height) or 8
        local root = Root(parent, "Spacer", cfg, height)
        local api = { Type = "Spacer" }
        Dual(api, "Set", function(value)
            root.Size = UDim2.new(1, 0, 0, tonumber(value) or height)
        end)
        return Finish(api, root, cfg)
    end

    local BUTTON_STYLES = {
        Default = { Bg = "Surface3", Text = "Text" },
        Primary = { Bg = "Accent",   Text = nil },
        Danger  = { Bg = "Bad",      Text = nil },
        Good    = { Bg = "Good",     Text = nil },
        Ghost   = { Bg = "Surface2", Text = "SubText" },
    }

    local function BuildButton(parent, cfg, width)
        local styleName = cfg.Style or "Default"
        local style = BUTTON_STYLES[styleName] or BUTTON_STYLES.Default

        local button = New("TextButton", {
            Name = "Button",
            Size = width or UDim2.new(1, 0, 1, 0),
            AutoButtonColor = false,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            Font = Enum.Font.GothamBold,
            TextSize = cfg.TextSize or 14,
            Text = tostring(cfg.Name or cfg.Text or "Button"),
            Parent = parent,
        })
        T.Paint(button, "BackgroundColor3", style.Bg)
        local bgFade = T.Fade(button, "BackgroundTransparency", cfg.Transparency or 0, "Fill")
        T.Fade(button, "TextTransparency", 0, "Text")
        Corner(button, cfg.Radius or 6)

        local stroke = New("UIStroke", {
            Thickness = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Parent = button,
        })
        T.Paint(stroke, "Color", styleName == "Default" and "Border" or style.Bg)
        local strokeFade = T.Fade(stroke, "Transparency", 0.3, "Stroke")

        if style.Text then
            T.Paint(button, "TextColor3", style.Text)
        else
            button.TextColor3 = Color3.fromRGB(255, 255, 255)
        end

        Anim.Hover(button, function()
            bgFade.SetBase(math.max(0, (cfg.Transparency or 0) - 0.12), true)
            Tween(button, { BackgroundColor3 = T.Colors[style.Bg]:Lerp(Color3.new(1, 1, 1), 0.12) }, 0.15, "Fast")
            strokeFade.SetBase(0, true)
        end, function()
            bgFade.SetBase(cfg.Transparency or 0, true)
            Tween(button, { BackgroundColor3 = T.Colors[style.Bg] }, 0.2, "Fast")
            strokeFade.SetBase(0.3, true)
        end)

        return button, bgFade, stroke
    end

    function Factory.Button(parent, config)
        local cfg = Cfg(config, "Name")
        local root = Root(parent, "Button", cfg, cfg.Height or 32)
        local button = BuildButton(root, cfg)

        local confirmState = false
        local originalText = button.Text

        local api = { Type = "Button", Changed = Signal.new() }

        Click(button, cfg, function()
            if cfg.Confirm then
                if not confirmState then
                    confirmState = true
                    button.Text = cfg.ConfirmText or "Sure? Click again"
                    Tween(button, { BackgroundColor3 = T.Colors.Warn }, 0.15, "Fast")
                    task.delay(cfg.ConfirmTime or 3, function()
                        if confirmState then
                            confirmState = false
                            button.Text = originalText
                            Tween(button, { BackgroundColor3 = T.Colors[(BUTTON_STYLES[cfg.Style or "Default"]).Bg] }, 0.2, "Fast")
                        end
                    end)
                    return
                end
                confirmState = false
                button.Text = originalText
                Tween(button, { BackgroundColor3 = T.Colors[(BUTTON_STYLES[cfg.Style or "Default"]).Bg] }, 0.2, "Fast")
            end
            FireCallback(cfg, api)
        end)

        Dual(api, "SetText", function(value)
            originalText = tostring(value)
            button.Text = originalText
        end)
        Dual(api, "Set", function(value)
            originalText = tostring(value)
            button.Text = originalText
        end)
        Dual(api, "Get", function() return button.Text end)
        Dual(api, "SetLocked", function(locked)
            button:SetAttribute("Locked", locked == true)
            Tween(button, { BackgroundTransparency = locked and 0.6 or 0 }, 0.15, "Fast")
            button.AutoButtonColor = false
        end)
        Dual(api, "Fire", function() FireCallback(cfg, api) end)
        return Finish(api, root, cfg)
    end

    function Factory.DoubleButton(parent, config)
        local cfg = Cfg(config)
        local root = Root(parent, "DoubleButton", cfg, cfg.Height or 32)
        local holder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Parent = root,
        })
        ListLayout(holder, 6, Enum.FillDirection.Horizontal)

        local left = cfg.Left or {}
        local right = cfg.Right or {}
        local width = UDim2.new(0.5, -3, 1, 0)

        local b1 = BuildButton(holder, {
            Name = left.Name or "A", Style = left.Style or "Default",
        }, width)
        local b2 = BuildButton(holder, {
            Name = right.Name or "B", Style = right.Style or "Default",
        }, width)
        b1.LayoutOrder = 1
        b2.LayoutOrder = 2

        Click(b1, cfg, function() SafeCall(left.Callback) end)
        Click(b2, cfg, function() SafeCall(right.Callback) end)

        local api = { Type = "DoubleButton" }
        Dual(api, "SetLeftText", function(v) b1.Text = tostring(v) end)
        Dual(api, "SetRightText", function(v) b2.Text = tostring(v) end)
        return Finish(api, root, cfg)
    end

    local BindContainer

    function Factory.Toggle(parent, config)
        local cfg = Cfg(config, "Name")
        local state = cfg.Default == true

        local root = Root(parent, "Toggle", cfg)
        local column = New("Frame", {
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(1, 0, 0, 0),
            Parent = root,
        })
        ListLayout(column, 6)

        local rowHolder = New("Frame", {
            BackgroundTransparency = 1,
            LayoutOrder = 1,
            Size = UDim2.new(1, 0, 0, 32),
            Parent = column,
        })

        local _, card, title, cardFade = LabelledRow(rowHolder, cfg, "ToggleRow", 32, 56)
        card.Size = UDim2.fromScale(1, 1)

        local track = New("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(38, 20),
            BorderSizePixel = 0,
            Parent = card,
        })
        T.Paint(track, "BackgroundColor3", "Surface")
        T.Fade(track, "BackgroundTransparency", 0, "Fill")
        Corner(track, 999)
        local trackStroke = New("UIStroke", { Thickness = 1, Parent = track })
        T.Paint(trackStroke, "Color", "Border")
        local trackStrokeFade = T.Fade(trackStroke, "Transparency", 0.2, "Stroke")

        local knob = New("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 3, 0.5, 0),
            Size = UDim2.fromOffset(14, 14),
            BorderSizePixel = 0,
            Parent = track,
        })
        T.Paint(knob, "BackgroundColor3", "Muted")
        T.Fade(knob, "BackgroundTransparency", 0, "Fill")
        Corner(knob, 999)

        local button = New("TextButton", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Text = "",
            AutoButtonColor = false,
            ZIndex = card.ZIndex + 5,
            Parent = card,
        })

        local subHolder
        local function EnsureSub()
            if not subHolder then
                subHolder = New("Frame", {
                    Name = "SubContent",
                    BackgroundTransparency = 1,
                    LayoutOrder = 2,
                    AutomaticSize = Enum.AutomaticSize.Y,
                    Size = UDim2.new(1, 0, 0, 0),
                    Visible = state,
                    Parent = column,
                })
                Padding(subHolder, 0, 0, 12, 0)
                ListLayout(subHolder, 6)
            end
            return subHolder
        end

        local api = { Type = "Toggle", Changed = Signal.new() }

        local function ApplyVisual(animate)
            local dur = animate and 0.18 or 0
            if state then
                Tween(track, { BackgroundColor3 = T.Colors.Accent }, dur, "Fast")
                Tween(knob, {
                    Position = UDim2.new(1, -17, 0.5, 0),
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    Size = UDim2.fromOffset(14, 14),
                }, dur, "Snap")
                trackStroke.Color = T.Colors.Accent
                trackStrokeFade.SetBase(0, animate)
                Tween(title, { TextColor3 = T.Colors.Text }, dur, "Fast")
            else
                Tween(track, { BackgroundColor3 = T.Colors.Surface }, dur, "Fast")
                Tween(knob, {
                    Position = UDim2.new(0, 3, 0.5, 0),
                    BackgroundColor3 = T.Colors.Muted,
                    Size = UDim2.fromOffset(14, 14),
                }, dur, "Snap")
                trackStroke.Color = T.Colors.Border
                trackStrokeFade.SetBase(0.2, animate)
                Tween(title, { TextColor3 = T.Colors.SubText }, dur, "Fast")
            end
            if subHolder then
                subHolder.Visible = state
            end
        end

        local function SetState(value, silent, animate)
            local newState = value == true
            local changed = newState ~= state
            state = newState
            ApplyVisual(animate ~= false)
            if changed and not silent then
                FireCallback(cfg, api, state)
            end
        end

        Click(button, cfg, function() SetState(not state) end)

        T.Changed:Connect(function() ApplyVisual(false) end)
        ApplyVisual(false)

        Dual(api, "Set", function(value, silent) SetState(value, silent) end)
        Dual(api, "Get", function() return state end)
        Dual(api, "Toggle", function() SetState(not state) end)
        Dual(api, "GetContainer", function() return EnsureSub() end)
        api.OnDestroy = function() api.Changed:Destroy() end

        BindContainer(api, EnsureSub)

        if state and cfg.FireOnStart then
            FireCallback(cfg, api, state)
        end
        return Finish(api, root, cfg)
    end

    function Factory.Checkbox(parent, config)
        local cfg = Cfg(config, "Name")
        local state = cfg.Default == true
        local root, card, title = LabelledRow(parent, cfg, "Checkbox", 32, 40)

        local box = New("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(18, 18),
            BorderSizePixel = 0,
            Parent = card,
        })
        T.Paint(box, "BackgroundColor3", "Surface")
        T.Fade(box, "BackgroundTransparency", 0, "Fill")
        Corner(box, 5)
        local boxStroke = New("UIStroke", { Thickness = 1.4, Parent = box })
        T.Paint(boxStroke, "Color", "Border")
        local boxStrokeFade = T.Fade(boxStroke, "Transparency", 0.1, "Stroke")

        local check = Text(box, {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            Text = "\u{2713}",
            TextTransparency = 1,
            Parent = box,
        }, "Text")
        check.TextColor3 = Color3.fromRGB(255, 255, 255)

        local button = New("TextButton", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Text = "",
            AutoButtonColor = false,
            ZIndex = card.ZIndex + 5,
            Parent = card,
        })

        local api = { Type = "Checkbox", Changed = Signal.new() }

        local function ApplyVisual(animate)
            local dur = animate and 0.16 or 0
            if state then
                Tween(box, { BackgroundColor3 = T.Colors.Accent, Size = UDim2.fromOffset(18, 18) }, dur, "Pop")
                boxStroke.Color = T.Colors.Accent
                boxStrokeFade.SetBase(0, animate)
                Tween(check, { TextTransparency = T.Eff(0, "Text") }, dur, "Fast")
                Tween(title, { TextColor3 = T.Colors.Text }, dur, "Fast")
            else
                Tween(box, { BackgroundColor3 = T.Colors.Surface }, dur, "Fast")
                boxStroke.Color = T.Colors.Border
                boxStrokeFade.SetBase(0.1, animate)
                Tween(check, { TextTransparency = 1 }, dur, "Fast")
                Tween(title, { TextColor3 = T.Colors.SubText }, dur, "Fast")
            end
        end

        local function SetState(value, silent)
            local newState = value == true
            local changed = newState ~= state
            state = newState
            ApplyVisual(true)
            if changed and not silent then FireCallback(cfg, api, state) end
        end

        Click(button, cfg, function() SetState(not state) end)
        T.Changed:Connect(function() ApplyVisual(false) end)
        ApplyVisual(false)

        Dual(api, "Set", function(v, s) SetState(v, s) end)
        Dual(api, "Get", function() return state end)
        Dual(api, "Toggle", function() SetState(not state) end)
        return Finish(api, root, cfg)
    end

    function Factory.Switch(parent, config)
        local cfg = Cfg(config, "Name")
        local state = cfg.Default == true
        local root, card, title = LabelledRow(parent, cfg, "Switch", 34, 66)

        local track = New("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(46, 24),
            BorderSizePixel = 0,
            Parent = card,
        })
        T.Paint(track, "BackgroundColor3", "Surface")
        T.Fade(track, "BackgroundTransparency", 0, "Fill")
        Corner(track, 999)

        local fill = New("Frame", {
            Size = UDim2.fromScale(0, 1),
            BorderSizePixel = 0,
            Parent = track,
        })
        T.Paint(fill, "BackgroundColor3", "Accent")
        T.Fade(fill, "BackgroundTransparency", 0, "Fill")
        Corner(fill, 999)

        local knob = New("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 3, 0.5, 0),
            Size = UDim2.fromOffset(18, 18),
            BorderSizePixel = 0,
            ZIndex = 3,
            Parent = track,
        })
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        T.Fade(knob, "BackgroundTransparency", 0, "Fill")
        Corner(knob, 999)

        local stateLabel = Text(card, {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -52, 0.5, 0),
            Size = UDim2.fromOffset(30, 16),
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Right,
            Text = "OFF",
            Parent = card,
        }, "Muted")

        local button = New("TextButton", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Text = "",
            AutoButtonColor = false,
            ZIndex = card.ZIndex + 5,
            Parent = card,
        })

        local api = { Type = "Switch", Changed = Signal.new() }

        local function ApplyVisual(animate)
            local dur = animate and 0.2 or 0
            if state then
                Tween(fill, { Size = UDim2.fromScale(1, 1) }, dur, "Snap")
                Tween(knob, { Position = UDim2.new(0, 25, 0.5, 0) }, dur, "Snap")
                stateLabel.Text = "ON"
                Tween(stateLabel, { TextColor3 = T.Colors.Accent }, dur, "Fast")
                Tween(title, { TextColor3 = T.Colors.Text }, dur, "Fast")
            else
                Tween(fill, { Size = UDim2.fromScale(0, 1) }, dur, "Snap")
                Tween(knob, { Position = UDim2.new(0, 3, 0.5, 0) }, dur, "Snap")
                stateLabel.Text = "OFF"
                Tween(stateLabel, { TextColor3 = T.Colors.Muted }, dur, "Fast")
                Tween(title, { TextColor3 = T.Colors.SubText }, dur, "Fast")
            end
        end

        local function SetState(value, silent)
            local newState = value == true
            local changed = newState ~= state
            state = newState
            ApplyVisual(true)
            if changed and not silent then FireCallback(cfg, api, state) end
        end

        Click(button, cfg, function() SetState(not state) end)
        T.Changed:Connect(function() ApplyVisual(false) end)
        ApplyVisual(false)

        Dual(api, "Set", function(v, s) SetState(v, s) end)
        Dual(api, "Get", function() return state end)
        Dual(api, "Toggle", function() SetState(not state) end)
        return Finish(api, root, cfg)
    end

    function Factory.ProgressBar(parent, config)
        local cfg = Cfg(config, "Name")
        local value = Clamp01(cfg.Default or 0)
        local root = Root(parent, "ProgressBar", cfg, cfg.Name and 44 or 22)

        local title, percent
        if cfg.Name then
            title = Text(root, {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -50, 0, 18),
                Font = Enum.Font.GothamMedium,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = cfg.Name,
                Parent = root,
            }, "SubText")

            percent = Text(root, {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, 0, 0, 0),
                Size = UDim2.fromOffset(50, 18),
                Font = Enum.Font.GothamBold,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Right,
                Text = "0%",
                Parent = root,
            }, "Accent")
        end

        local track = New("Frame", {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, 0),
            Size = UDim2.new(1, 0, 0, cfg.Thickness or 8),
            BorderSizePixel = 0,
            ClipsDescendants = true,
            Parent = root,
        })
        T.Paint(track, "BackgroundColor3", "Surface")
        T.Fade(track, "BackgroundTransparency", 0, "Fill")
        Corner(track, 999)

        local fill = New("Frame", {
            Size = UDim2.fromScale(0, 1),
            BorderSizePixel = 0,
            Parent = track,
        })
        T.Paint(fill, "BackgroundColor3", cfg.Color and nil or "Accent")
        if cfg.Color then fill.BackgroundColor3 = cfg.Color end
        T.Fade(fill, "BackgroundTransparency", 0, "Fill")
        Corner(fill, 999)

        local api = { Type = "ProgressBar", Changed = Signal.new() }

        local function Apply(v, animate)
            value = Clamp01(v)
            Tween(fill, { Size = UDim2.fromScale(value, 1) }, animate == false and 0 or 0.28, "Snap")
            if percent then
                percent.Text = math.floor(value * 100 + 0.5) .. "%"
            end
        end

        Dual(api, "Set", function(v, animate) Apply(tonumber(v) or 0, animate) end)
        Dual(api, "Get", function() return value end)
        Dual(api, "SetColor", function(color) fill.BackgroundColor3 = color end)
        Dual(api, "SetText", function(text) if title then title.Text = tostring(text) end end)
        Apply(value, false)
        return Finish(api, root, cfg)
    end

    function Factory.Spinner(parent, config)
        local cfg = Cfg(config, "Name")
        local root = Root(parent, "Spinner", cfg, 40)

        local ring = New("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 4, 0.5, 0),
            Size = UDim2.fromOffset(22, 22),
            BackgroundTransparency = 1,
            Parent = root,
        })
        Corner(ring, 999)
        local ringStroke = New("UIStroke", { Thickness = 3, Parent = ring })
        T.Paint(ringStroke, "Color", "Accent")
        New("UIGradient", {
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(0.55, 0.85),
                NumberSequenceKeypoint.new(1, 1),
            }),
            Parent = ringStroke,
        })
        local gradient = ringStroke:FindFirstChildOfClass("UIGradient")

        local label = Text(root, {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 36, 0, 0),
            Size = UDim2.new(1, -36, 1, 0),
            Font = Enum.Font.GothamMedium,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = tostring(cfg.Name or cfg.Text or "Loading..."),
            Parent = root,
        }, "SubText")

        local spinning = true
        local conn
        conn = RunService.RenderStepped:Connect(function(dt)
            if not root:IsDescendantOf(game) then
                conn:Disconnect()
                return
            end
            if spinning and gradient then
                gradient.Rotation = (gradient.Rotation + dt * 320) % 360
            end
        end)

        local api = { Type = "Spinner" }
        Dual(api, "SetText", function(v) label.Text = tostring(v) end)
        Dual(api, "Set", function(v) label.Text = tostring(v) end)
        Dual(api, "Stop", function() spinning = false end)
        Dual(api, "Start", function() spinning = true end)
        api.OnDestroy = function() if conn then conn:Disconnect() end end
        return Finish(api, root, cfg)
    end

    function Factory.KeyValue(parent, config)
        local cfg = Cfg(config, "Name")
        local root, card, title = LabelledRow(parent, cfg, "KeyValue", 30, 120)

        local valueLabel = Text(card, {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.new(0, 160, 1, 0),
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Text = tostring(cfg.Value or ""),
            Parent = card,
        }, "Accent")

        local api = { Type = "KeyValue" }
        Dual(api, "Set", function(v) valueLabel.Text = tostring(v) end)
        Dual(api, "Get", function() return valueLabel.Text end)
        Dual(api, "SetKey", function(v) title.Text = tostring(v) end)
        Dual(api, "SetColor", function(c) valueLabel.TextColor3 = c end)
        return Finish(api, root, cfg)
    end

    function Factory.Badge(parent, config)
        local cfg = Cfg(config, "Text")
        local root, card, title = LabelledRow(parent, cfg, "Badge", 32, 100)

        local badge = New("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(0, 20),
            AutomaticSize = Enum.AutomaticSize.X,
            BorderSizePixel = 0,
            Parent = card,
        })
        badge.BackgroundColor3 = cfg.Color or T.Colors.Accent
        T.Fade(badge, "BackgroundTransparency", 0.82, "Fill")
        Corner(badge, 999)
        Padding(badge, 0, 0, 9, 9)
        local badgeStroke = New("UIStroke", { Thickness = 1, Parent = badge })
        badgeStroke.Color = cfg.Color or T.Colors.Accent
        T.Fade(badgeStroke, "Transparency", 0.4, "Stroke")

        local badgeText = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = cfg.Color or T.Colors.Accent,
            Text = tostring(cfg.Value or cfg.Badge or "NEW"),
            Parent = badge,
        })
        T.Fade(badgeText, "TextTransparency", 0, "Text")

        local api = { Type = "Badge" }
        Dual(api, "Set", function(text, color)
            badgeText.Text = tostring(text)
            if color then
                badgeText.TextColor3 = color
                badge.BackgroundColor3 = color
                badgeStroke.Color = color
            end
        end)
        Dual(api, "Get", function() return badgeText.Text end)
        return Finish(api, root, cfg)
    end

    function Factory.Stat(parent, config)
        local cfg = Cfg(config, "Name")
        local root = Root(parent, "Stat", cfg, 58)
        local card = Surface(root, {
            Size = UDim2.fromScale(1, 1),
            BorderSizePixel = 0,
            Parent = root,
        }, "Surface2", 0.35)
        Padding(card, 8, 8, 12, 12)

        local value = Text(card, {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 24),
            Font = Enum.Font.GothamBlack,
            TextSize = 22,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = tostring(cfg.Value or "0"),
            Parent = card,
        }, "Accent")

        local caption = Text(card, {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 0, 0, 24),
            Size = UDim2.new(1, 0, 0, 16),
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = tostring(cfg.Name or ""),
            Parent = card,
        }, "SubText")

        local api = { Type = "Stat" }
        Dual(api, "Set", function(v) value.Text = tostring(v) end)
        Dual(api, "Get", function() return value.Text end)
        Dual(api, "SetCaption", function(v) caption.Text = tostring(v) end)
        Dual(api, "SetColor", function(c) value.TextColor3 = c end)
        return Finish(api, root, cfg)
    end

    function Factory.Image(parent, config)
        local cfg = Cfg(config, "Image")
        local height = cfg.Height or 120
        local root = Root(parent, "Image", cfg, height)

        local image = New("ImageLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Image = tostring(cfg.Image or cfg.Id or ""),
            ScaleType = cfg.ScaleType or Enum.ScaleType.Fit,
            Parent = root,
        })
        T.Fade(image, "ImageTransparency", cfg.Transparency or 0, "Text")
        if cfg.Radius then Corner(image, cfg.Radius) end
        if cfg.Color then image.ImageColor3 = cfg.Color end

        local api = { Type = "Image" }
        Dual(api, "Set", function(id)
            if typeof(id) == "number" then
                image.Image = "rbxassetid://" .. tostring(id)
            else
                image.Image = tostring(id)
            end
        end)
        Dual(api, "Get", function() return image.Image end)
        Dual(api, "SetSize", function(h)
            root.Size = UDim2.new(1, 0, 0, h)
        end)
        return Finish(api, root, cfg)
    end

    function Factory.Avatar(parent, config)
        local cfg = Cfg(config, "Name")
        local root = Root(parent, "Avatar", cfg, 56)
        local card = Surface(root, {
            Size = UDim2.fromScale(1, 1),
            BorderSizePixel = 0,
            Parent = root,
        }, "Surface2", 0.35)
        Padding(card, 8, 8, 8, 10)

        local holder = New("Frame", {
            Size = UDim2.fromOffset(40, 40),
            BackgroundTransparency = 1,
            Parent = card,
        })
        local image = New("ImageLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Parent = holder,
        })
        T.Paint(image, "BackgroundColor3", "Surface")
        Corner(image, 999)
        T.Fade(image, "ImageTransparency", 0, "Text")

        local nameLabel = Text(card, {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 50, 0, 2),
            Size = UDim2.new(1, -50, 0, 18),
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Text = "",
            Parent = card,
        }, "Text")

        local subLabel = Text(card, {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 50, 0, 20),
            Size = UDim2.new(1, -50, 0, 16),
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Text = "",
            Parent = card,
        }, "SubText")

        local api = { Type = "Avatar" }

        local function LoadPlayer(player)
            if typeof(player) == "string" then
                player = Players:FindFirstChild(player)
            end
            if not player then return end
            nameLabel.Text = player.DisplayName or player.Name
            subLabel.Text = "@" .. player.Name .. "  |  " .. tostring(player.UserId)
            task.spawn(function()
                local ok, content = pcall(function()
                    return Players:GetUserThumbnailAsync(
                        player.UserId,
                        Enum.ThumbnailType.HeadShot,
                        Enum.ThumbnailSize.Size100x100
                    )
                end)
                if ok and content then image.Image = content end
            end)
        end

        Dual(api, "Set", function(player) LoadPlayer(player) end)
        Dual(api, "SetPlayer", function(player) LoadPlayer(player) end)
        Dual(api, "SetSubText", function(v) subLabel.Text = tostring(v) end)
        LoadPlayer(cfg.Player or LocalPlayer)
        return Finish(api, root, cfg)
    end

    local function BuildTrack(parent, props)
        local track = New("Frame", props)
        T.Paint(track, "BackgroundColor3", "Surface")
        T.Fade(track, "BackgroundTransparency", 0, "Fill")
        Corner(track, 999)

        local fill = New("Frame", {
            Size = UDim2.fromScale(0, 1),
            BorderSizePixel = 0,
            Parent = track,
        })
        T.Paint(fill, "BackgroundColor3", "Accent")
        T.Fade(fill, "BackgroundTransparency", 0, "Fill")
        Corner(fill, 999)

        return track, fill
    end

    local function BuildKnob(parent, size)
        local knob = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0, 0.5),
            Size = UDim2.fromOffset(size or 13, size or 13),
            BorderSizePixel = 0,
            ZIndex = 4,
            Parent = parent,
        })
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        T.Fade(knob, "BackgroundTransparency", 0, "Fill")
        Corner(knob, 999)
        local stroke = New("UIStroke", { Thickness = 2, Parent = knob })
        T.Paint(stroke, "Color", "Accent")
        T.Fade(stroke, "Transparency", 0, "Stroke")
        return knob
    end

    local function RelativeX(track, x)
        local size = track.AbsoluteSize.X
        if size <= 0 then return 0 end
        return Clamp01((x - track.AbsolutePosition.X) / size)
    end

    function Factory.Slider(parent, config)
        local cfg = Cfg(config, "Name")
        local min = cfg.Min or 0
        local max = cfg.Max or 100
        if max <= min then max = min + 1 end
        local step = cfg.Step or 1
        local decimals = cfg.Decimals
        local suffix = cfg.Suffix or ""
        local value = math.clamp(cfg.Default or min, min, max)

        local root = Root(parent, "Slider", cfg, 52)
        local card, cardFade, stroke, strokeFade = Surface(root, {
            Size = UDim2.fromScale(1, 1),
            BorderSizePixel = 0,
            Parent = root,
        }, "Surface2", 0.35)
        Padding(card, 7, 7, 10, 8)

        local title = Text(card, {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -70, 0, 18),
            Font = Enum.Font.GothamMedium,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Text = tostring(cfg.Name or ""),
            Parent = card,
        }, "SubText")

        local valueBox = New("TextBox", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, 0),
            Size = UDim2.fromOffset(66, 18),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Right,
            Text = "0",
            ClearTextOnFocus = false,
            TextEditable = cfg.Editable ~= false,
            Parent = card,
        })
        T.Paint(valueBox, "TextColor3", "Accent")
        T.Fade(valueBox, "TextTransparency", 0, "Text")

        local track, fill = BuildTrack(card, {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, -3),
            Size = UDim2.new(1, 0, 0, 6),
            BorderSizePixel = 0,
            Parent = card,
        })
        local knob = BuildKnob(track, 13)

        local hitArea = New("TextButton", {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, 0),
            Size = UDim2.new(1, 0, 0, 20),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 6,
            Parent = card,
        })

        local api = { Type = "Slider", Changed = Signal.new() }
        local dragging = false

        local function Display(v)
            return FormatNumber(v, decimals) .. suffix
        end

        local function ApplyValue(newValue, fromUser, animate)
            local clamped = math.clamp(RoundTo(newValue, step), min, max)
            local changed = clamped ~= value
            value = clamped
            local alpha = (value - min) / (max - min)
            local dur = animate == false and 0 or (dragging and 0.055 or 0.2)
            Tween(fill, { Size = UDim2.fromScale(alpha, 1) }, dur, dragging and "Linear" or "Snap")
            Tween(knob, { Position = UDim2.fromScale(alpha, 0.5) }, dur, dragging and "Linear" or "Snap")
            if not valueBox:IsFocused() then
                valueBox.Text = Display(value)
            end
            if changed and fromUser ~= "silent" then
                FireCallback(cfg, api, value)
            end
        end

        InputMgr.Bind(hitArea, {
            OnBegin = function(pos)
                dragging = true
                Tween(knob, { Size = UDim2.fromOffset(17, 17) }, 0.12, "Pop")
                strokeFade.SetBase(0.05, true)
                ApplyValue(min + RelativeX(track, pos.X) * (max - min), true)
            end,
            OnMove = function(pos)
                ApplyValue(min + RelativeX(track, pos.X) * (max - min), true)
            end,
            OnEnd = function()
                dragging = false
                Tween(knob, { Size = UDim2.fromOffset(13, 13) }, 0.16, "Snap")
                strokeFade.SetBase(0.35, true)
            end,
        })

        valueBox.FocusLost:Connect(function()
            local parsed = tonumber((valueBox.Text:gsub("[^%-%d%.]", "")))
            if parsed then
                ApplyValue(parsed, true)
            else
                valueBox.Text = Display(value)
            end
        end)

        Anim.Hover(card, function()
            Tween(card, { BackgroundColor3 = T.Colors.Surface3 }, 0.16, "Fast")
        end, function()
            Tween(card, { BackgroundColor3 = T.Colors.Surface2 }, 0.2, "Fast")
        end)

        Dual(api, "Set", function(v, silent)
            ApplyValue(tonumber(v) or min, silent and "silent" or false)
        end)
        Dual(api, "Get", function() return value end)
        Dual(api, "SetRange", function(newMin, newMax)
            min = newMin or min
            max = newMax or max
            if max <= min then max = min + 1 end
            ApplyValue(value, "silent")
        end)
        Dual(api, "SetText", function(v) title.Text = tostring(v) end)
        ApplyValue(value, "silent", false)
        return Finish(api, root, cfg)
    end

    function Factory.RangeSlider(parent, config)
        local cfg = Cfg(config, "Name")
        local min = cfg.Min or 0
        local max = cfg.Max or 100
        if max <= min then max = min + 1 end
        local step = cfg.Step or 1
        local low = math.clamp(cfg.DefaultLow or cfg.Low or min, min, max)
        local high = math.clamp(cfg.DefaultHigh or cfg.High or max, min, max)
        if low > high then low, high = high, low end

        local root = Root(parent, "RangeSlider", cfg, 52)
        local card = Surface(root, {
            Size = UDim2.fromScale(1, 1),
            BorderSizePixel = 0,
            Parent = root,
        }, "Surface2", 0.35)
        Padding(card, 7, 7, 10, 8)

        local title = Text(card, {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -100, 0, 18),
            Font = Enum.Font.GothamMedium,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = tostring(cfg.Name or ""),
            Parent = card,
        }, "SubText")

        local valueLabel = Text(card, {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, 0),
            Size = UDim2.fromOffset(100, 18),
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Right,
            Text = "",
            Parent = card,
        }, "Accent")

        local track = New("Frame", {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, -3),
            Size = UDim2.new(1, 0, 0, 6),
            BorderSizePixel = 0,
            Parent = card,
        })
        T.Paint(track, "BackgroundColor3", "Surface")
        T.Fade(track, "BackgroundTransparency", 0, "Fill")
        Corner(track, 999)

        local fill = New("Frame", {
            Size = UDim2.fromScale(0, 1),
            BorderSizePixel = 0,
            Parent = track,
        })
        T.Paint(fill, "BackgroundColor3", "Accent")
        T.Fade(fill, "BackgroundTransparency", 0, "Fill")
        Corner(fill, 999)

        local knobLow = BuildKnob(track, 13)
        local knobHigh = BuildKnob(track, 13)

        local hitArea = New("TextButton", {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, 0),
            Size = UDim2.new(1, 0, 0, 20),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 6,
            Parent = card,
        })

        local api = { Type = "RangeSlider", Changed = Signal.new() }
        local dragging = nil

        local function Apply(silent, animate)
            local aLow = (low - min) / (max - min)
            local aHigh = (high - min) / (max - min)
            local dur = animate == false and 0 or (dragging and 0.055 or 0.2)
            Tween(fill, {
                Position = UDim2.fromScale(aLow, 0),
                Size = UDim2.fromScale(aHigh - aLow, 1),
            }, dur, dragging and "Linear" or "Snap")
            Tween(knobLow, { Position = UDim2.fromScale(aLow, 0.5) }, dur, dragging and "Linear" or "Snap")
            Tween(knobHigh, { Position = UDim2.fromScale(aHigh, 0.5) }, dur, dragging and "Linear" or "Snap")
            valueLabel.Text = FormatNumber(low, cfg.Decimals) .. " - " .. FormatNumber(high, cfg.Decimals)
            if not silent then FireCallback(cfg, api, low, high) end
        end

        local function UpdateFrom(x)
            local ratio = RelativeX(track, x)
            local target = min + ratio * (max - min)
            target = math.clamp(RoundTo(target, step), min, max)
            if dragging == "low" then
                low = math.min(target, high)
            else
                high = math.max(target, low)
            end
            Apply(false)
        end

        InputMgr.Bind(hitArea, {
            OnBegin = function(pos)
                local ratio = RelativeX(track, pos.X)
                local target = min + ratio * (max - min)
                dragging = (math.abs(target - low) <= math.abs(target - high)) and "low" or "high"
                UpdateFrom(pos.X)
            end,
            OnMove = function(pos) UpdateFrom(pos.X) end,
            OnEnd = function() dragging = nil end,
        })

        Dual(api, "Set", function(newLow, newHigh)
            low = math.clamp(newLow or low, min, max)
            high = math.clamp(newHigh or high, min, max)
            if low > high then low, high = high, low end
            Apply(true)
        end)
        Dual(api, "Get", function() return low, high end)
        Apply(true, false)
        return Finish(api, root, cfg)
    end

    function Factory.Stepper(parent, config)
        local cfg = Cfg(config, "Name")
        local min = cfg.Min or 0
        local max = cfg.Max or 100
        local step = cfg.Step or 1
        local value = math.clamp(cfg.Default or min, min, max)

        local root, card, title = LabelledRow(parent, cfg, "Stepper", 34, 110)

        local holder = New("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(104, 24),
            BackgroundTransparency = 1,
            Parent = card,
        })

        local function MiniButton(text, xPos, anchor)
            local btn = New("TextButton", {
                AnchorPoint = Vector2.new(anchor, 0.5),
                Position = UDim2.new(xPos, 0, 0.5, 0),
                Size = UDim2.fromOffset(24, 24),
                AutoButtonColor = false,
                BorderSizePixel = 0,
                ClipsDescendants = true,
                Font = Enum.Font.GothamBold,
                TextSize = 16,
                Text = text,
                ZIndex = 5,
                Parent = holder,
            })
            T.Paint(btn, "BackgroundColor3", "Surface")
            T.Fade(btn, "BackgroundTransparency", 0, "Fill")
            T.Paint(btn, "TextColor3", "Text")
            T.Fade(btn, "TextTransparency", 0, "Text")
            Corner(btn, 6)
            local s = New("UIStroke", { Thickness = 1, Parent = btn })
            T.Paint(s, "Color", "Border")
            T.Fade(s, "Transparency", 0.3, "Stroke")
            Anim.Hover(btn, function()
                Tween(btn, { BackgroundColor3 = T.Colors.Accent }, 0.14, "Fast")
            end, function()
                Tween(btn, { BackgroundColor3 = T.Colors.Surface }, 0.18, "Fast")
            end)
            return btn
        end

        local minus = MiniButton("-", 0, 0)
        local plus = MiniButton("+", 1, 1)

        local valueLabel = Text(holder, {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(52, 24),
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            Text = tostring(value),
            Parent = holder,
        }, "Accent")

        local api = { Type = "Stepper", Changed = Signal.new() }

        local function SetValue(v, silent)
            local clamped = math.clamp(RoundTo(v, step), min, max)
            local changed = clamped ~= value
            value = clamped
            valueLabel.Text = FormatNumber(value, cfg.Decimals) .. (cfg.Suffix or "")
            if changed and not silent then FireCallback(cfg, api, value) end
        end

        Click(minus, cfg, function() SetValue(value - step) end)
        Click(plus, cfg, function() SetValue(value + step) end)

        Dual(api, "Set", function(v, s) SetValue(tonumber(v) or min, s) end)
        Dual(api, "Get", function() return value end)
        SetValue(value, true)
        return Finish(api, root, cfg)
    end

    function Factory.ToggleSlider(parent, config)
        local cfg = Cfg(config, "Name")
        local root = Root(parent, "ToggleSlider", cfg, 52)
        local card = Surface(root, {
            Size = UDim2.fromScale(1, 1),
            BorderSizePixel = 0,
            Parent = root,
        }, "Surface2", 0.35)
        Padding(card, 7, 7, 10, 8)

        local state = cfg.Default == true
        local min = cfg.Min or 0
        local max = cfg.Max or 100
        if max <= min then max = min + 1 end
        local step = cfg.Step or 1
        local value = math.clamp(cfg.DefaultValue or min, min, max)

        local title = Text(card, {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(28, 0),
            Size = UDim2.new(1, -100, 0, 18),
            Font = Enum.Font.GothamMedium,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = tostring(cfg.Name or ""),
            Parent = card,
        }, "SubText")

        local box = New("Frame", {
            AnchorPoint = Vector2.new(0, 0),
            Position = UDim2.fromOffset(0, 1),
            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            Parent = card,
        })
        T.Paint(box, "BackgroundColor3", "Surface")
        T.Fade(box, "BackgroundTransparency", 0, "Fill")
        Corner(box, 4)
        local boxStroke = New("UIStroke", { Thickness = 1.4, Parent = box })
        T.Paint(boxStroke, "Color", "Border")
        T.Fade(boxStroke, "Transparency", 0.1, "Stroke")

        local toggleBtn = New("TextButton", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.new(1, 0, 0, 20),
            Text = "",
            AutoButtonColor = false,
            ZIndex = 8,
            Parent = card,
        })

        local valueLabel = Text(card, {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, 0),
            Size = UDim2.fromOffset(70, 18),
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Right,
            Text = "0",
            Parent = card,
        }, "Accent")

        local track, fill = BuildTrack(card, {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, -3),
            Size = UDim2.new(1, 0, 0, 6),
            BorderSizePixel = 0,
            Parent = card,
        })
        local knob = BuildKnob(track, 13)

        local hitArea = New("TextButton", {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, 0),
            Size = UDim2.new(1, 0, 0, 20),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 6,
            Parent = card,
        })

        local api = { Type = "ToggleSlider", Changed = Signal.new() }
        local dragging = false

        local function ApplyToggle(animate)
            local dur = animate and 0.16 or 0
            if state then
                Tween(box, { BackgroundColor3 = T.Colors.Accent }, dur, "Pop")
                boxStroke.Color = T.Colors.Accent
                Tween(title, { TextColor3 = T.Colors.Text }, dur, "Fast")
                Tween(fill, { BackgroundTransparency = T.Eff(0, "Fill") }, dur, "Fast")
            else
                Tween(box, { BackgroundColor3 = T.Colors.Surface }, dur, "Fast")
                boxStroke.Color = T.Colors.Border
                Tween(title, { TextColor3 = T.Colors.SubText }, dur, "Fast")
                Tween(fill, { BackgroundTransparency = T.Eff(0.65, "Fill") }, dur, "Fast")
            end
        end

        local function ApplyValue(v, silent)
            value = math.clamp(RoundTo(v, step), min, max)
            local alpha = (value - min) / (max - min)
            local dur = dragging and 0.055 or 0.2
            Tween(fill, { Size = UDim2.fromScale(alpha, 1) }, dur, dragging and "Linear" or "Snap")
            Tween(knob, { Position = UDim2.fromScale(alpha, 0.5) }, dur, dragging and "Linear" or "Snap")
            valueLabel.Text = FormatNumber(value, cfg.Decimals) .. (cfg.Suffix or "")
            if not silent then
                SafeCall(cfg.Callback, state, value)
                api.Changed:Fire(state, value)
            end
        end

        Click(toggleBtn, cfg, function()
            state = not state
            ApplyToggle(true)
            SafeCall(cfg.Callback, state, value)
            api.Changed:Fire(state, value)
        end)

        InputMgr.Bind(hitArea, {
            OnBegin = function(pos)
                dragging = true
                Tween(knob, { Size = UDim2.fromOffset(17, 17) }, 0.12, "Pop")
                ApplyValue(min + RelativeX(track, pos.X) * (max - min))
            end,
            OnMove = function(pos)
                ApplyValue(min + RelativeX(track, pos.X) * (max - min))
            end,
            OnEnd = function()
                dragging = false
                Tween(knob, { Size = UDim2.fromOffset(13, 13) }, 0.16, "Snap")
            end,
        })

        Dual(api, "GetToggle", function() return state end)
        Dual(api, "GetSlider", function() return value end)
        Dual(api, "Get", function() return state, value end)
        Dual(api, "SetToggle", function(v) state = v == true ApplyToggle(true) end)
        Dual(api, "SetSlider", function(v) ApplyValue(tonumber(v) or min, true) end)
        Dual(api, "Set", function(s, v)
            state = s == true
            ApplyToggle(false)
            ApplyValue(tonumber(v) or value, true)
        end)
        ApplyToggle(false)
        ApplyValue(value, true)
        return Finish(api, root, cfg)
    end

    function Factory.Rating(parent, config)
        local cfg = Cfg(config, "Name")
        local count = cfg.Count or 5
        local value = math.clamp(cfg.Default or 0, 0, count)
        local root, card, title = LabelledRow(parent, cfg, "Rating", 32, count * 22 + 10)

        local holder = New("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(count * 22, 22),
            BackgroundTransparency = 1,
            Parent = card,
        })
        ListLayout(holder, 2, Enum.FillDirection.Horizontal)

        local api = { Type = "Rating", Changed = Signal.new() }
        local stars = {}

        local function Refresh()
            for i, star in ipairs(stars) do
                local active = i <= value
                Tween(star, {
                    TextColor3 = active and T.Colors.Accent or T.Colors.Muted,
                    TextSize = active and 19 or 17,
                }, 0.15, "Pop")
            end
        end

        for i = 1, count do
            local star = New("TextButton", {
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(20, 22),
                Font = Enum.Font.GothamBold,
                TextSize = 17,
                Text = "\u{2605}",
                AutoButtonColor = false,
                LayoutOrder = i,
                Parent = holder,
            })
            T.Fade(star, "TextTransparency", 0, "Text")
            star.MouseButton1Click:Connect(function()
                value = i
                Refresh()
                FireCallback(cfg, api, value)
            end)
            Anim.Hover(star, function()
                Tween(star, { TextSize = 21 }, 0.12, "Pop")
            end, function()
                Tween(star, { TextSize = (i <= value) and 19 or 17 }, 0.15, "Fast")
            end)
            stars[i] = star
        end

        Dual(api, "Set", function(v) value = math.clamp(tonumber(v) or 0, 0, count) Refresh() end)
        Dual(api, "Get", function() return value end)
        Refresh()
        return Finish(api, root, cfg)
    end

    local function BuildTextBox(parent, cfg, props)
        local frame = New("Frame", props)
        T.Paint(frame, "BackgroundColor3", "Surface")
        T.Fade(frame, "BackgroundTransparency", 0, "Fill")
        Corner(frame, 6)
        local stroke = New("UIStroke", { Thickness = 1, Parent = frame })
        T.Paint(stroke, "Color", "Border")
        local strokeFade = T.Fade(stroke, "Transparency", 0.2, "Stroke")
        Padding(frame, 0, 0, 8, 8)

        local box = New("TextBox", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Font = Enum.Font.Gotham,
            TextSize = cfg.TextSize or 13,
            TextXAlignment = cfg.TextXAlignment or Enum.TextXAlignment.Left,
            PlaceholderText = cfg.Placeholder or "",
            Text = tostring(cfg.Default or ""),
            ClearTextOnFocus = cfg.ClearOnFocus == true,
            ClipsDescendants = true,
            Parent = frame,
        })
        T.Paint(box, "TextColor3", "Text")
        T.Paint(box, "PlaceholderColor3", "Muted")
        T.Fade(box, "TextTransparency", 0, "Text")

        box.Focused:Connect(function()
            stroke.Color = T.Colors.Accent
            strokeFade.SetBase(0, true)
            Tween(frame, { BackgroundColor3 = T.Colors.Surface3 }, 0.15, "Fast")
        end)
        box.FocusLost:Connect(function()
            stroke.Color = T.Colors.Border
            strokeFade.SetBase(0.2, true)
            Tween(frame, { BackgroundColor3 = T.Colors.Surface }, 0.2, "Fast")
        end)

        return frame, box
    end

    function Factory.Textbox(parent, config)
        local cfg = Cfg(config, "Name")
        local root, card, title = LabelledRow(parent, cfg, "Textbox", 34, (cfg.BoxWidth or 130) + 10)

        local frame, box = BuildTextBox(card, cfg, {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(cfg.BoxWidth or 130, 24),
            BorderSizePixel = 0,
            ZIndex = 4,
            Parent = card,
        })

        local api = { Type = "Textbox", Changed = Signal.new() }

        box.FocusLost:Connect(function(enterPressed)
            if cfg.OnlyOnEnter and not enterPressed then return end
            FireCallback(cfg, api, box.Text, enterPressed)
            if cfg.ClearOnEnter and enterPressed then box.Text = "" end
        end)
        if cfg.Live then
            box:GetPropertyChangedSignal("Text"):Connect(function()
                FireCallback(cfg, api, box.Text, false)
            end)
        end

        Dual(api, "Set", function(v) box.Text = tostring(v) end)
        Dual(api, "Get", function() return box.Text end)
        Dual(api, "SetPlaceholder", function(v) box.PlaceholderText = tostring(v) end)
        Dual(api, "Focus", function() box:CaptureFocus() end)
        return Finish(api, root, cfg)
    end

    function Factory.Input(parent, config)
        local cfg = Cfg(config, "Name")
        local hasButton = cfg.Button ~= nil
        local root = Root(parent, "Input", cfg, cfg.Name and 52 or 30)

        if cfg.Name then
            Text(root, {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 18),
                Font = Enum.Font.GothamMedium,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = cfg.Name,
                Parent = root,
            }, "SubText")
        end

        local boxWidth = hasButton and UDim2.new(1, -84, 0, 28) or UDim2.new(1, 0, 0, 28)
        local frame, box = BuildTextBox(root, cfg, {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, 0),
            Size = boxWidth,
            BorderSizePixel = 0,
            Parent = root,
        })

        local api = { Type = "Input", Changed = Signal.new() }

        local function Submit(enterPressed)
            FireCallback(cfg, api, box.Text, enterPressed)
            if cfg.ClearOnEnter then box.Text = "" end
        end

        box.FocusLost:Connect(function(enterPressed)
            if cfg.OnlyOnEnter and not enterPressed then return end
            Submit(enterPressed)
        end)

        if hasButton then
            local btn = BuildButton(root, {
                Name = tostring(cfg.Button),
                Style = cfg.ButtonStyle or "Primary",
            }, UDim2.fromOffset(78, 28))
            btn.AnchorPoint = Vector2.new(1, 1)
            btn.Position = UDim2.new(1, 0, 1, 0)
            Click(btn, cfg, function() Submit(true) end)
        end

        Dual(api, "Set", function(v) box.Text = tostring(v) end)
        Dual(api, "Get", function() return box.Text end)
        Dual(api, "Focus", function() box:CaptureFocus() end)
        return Finish(api, root, cfg)
    end

    function Factory.TextArea(parent, config)
        local cfg = Cfg(config, "Name")
        local height = cfg.Height or 90
        local root = Root(parent, "TextArea", cfg, height + (cfg.Name and 22 or 0))

        if cfg.Name then
            Text(root, {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 18),
                Font = Enum.Font.GothamMedium,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = cfg.Name,
                Parent = root,
            }, "SubText")
        end

        local frame, box = BuildTextBox(root, cfg, {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, 0),
            Size = UDim2.new(1, 0, 0, height),
            BorderSizePixel = 0,
            Parent = root,
        })
        Padding(frame, 6, 6, 8, 8)
        box.MultiLine = true
        box.ClearTextOnFocus = false
        box.TextWrapped = true
        box.TextXAlignment = Enum.TextXAlignment.Left
        box.TextYAlignment = Enum.TextYAlignment.Top

        local api = { Type = "TextArea", Changed = Signal.new() }
        box.FocusLost:Connect(function() FireCallback(cfg, api, box.Text) end)

        Dual(api, "Set", function(v) box.Text = tostring(v) end)
        Dual(api, "Get", function() return box.Text end)
        Dual(api, "Append", function(v) box.Text = box.Text .. tostring(v) end)
        return Finish(api, root, cfg)
    end

    local KeybindList = {}

    UserInputService.InputBegan:Connect(function(input, processed)

        if ActiveKeybindCapture then
            local capture = ActiveKeybindCapture
            if input.UserInputType == Enum.UserInputType.Keyboard then
                ActiveKeybindCapture = nil
                if input.KeyCode == Enum.KeyCode.Escape then
                    capture.Cancel()
                else
                    capture.Apply(input.KeyCode)
                end
                return
            elseif input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.MouseButton2
                or input.UserInputType == Enum.UserInputType.MouseButton3 then
                ActiveKeybindCapture = nil
                capture.Apply(input.UserInputType)
                return
            end
        end
        if processed then return end
        for _, entry in ipairs(KeybindList) do
            if entry.Alive and entry.Matches(input) then
                entry.OnDown()
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        for _, entry in ipairs(KeybindList) do
            if entry.Alive and entry.Matches(input) and entry.OnUp then
                entry.OnUp()
            end
        end
    end)

    function Factory.Keybind(parent, config)
        local cfg = Cfg(config, "Name")
        local current = cfg.Default
        local mode = cfg.Mode or "Toggle"
        local state = false

        local root, card, title = LabelledRow(parent, cfg, "Keybind", 32, 110)

        local btn = New("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(96, 24),
            AutoButtonColor = false,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            Text = KeyName(current),
            ZIndex = 5,
            Parent = card,
        })
        T.Paint(btn, "BackgroundColor3", "Surface")
        T.Fade(btn, "BackgroundTransparency", 0, "Fill")
        T.Paint(btn, "TextColor3", "Text")
        T.Fade(btn, "TextTransparency", 0, "Text")
        Corner(btn, 6)
        local btnStroke = New("UIStroke", { Thickness = 1, Parent = btn })
        T.Paint(btnStroke, "Color", "Border")
        local btnStrokeFade = T.Fade(btnStroke, "Transparency", 0.2, "Stroke")

        local api = { Type = "Keybind", Changed = Signal.new() }
        local listening = false

        local function Refresh()
            btn.Text = listening and "[ listening... ]" or KeyName(current)
            if listening then
                btnStroke.Color = T.Colors.Accent
                btnStrokeFade.SetBase(0, true)
                Tween(btn, { BackgroundColor3 = T.Colors.Surface3 }, 0.15, "Fast")
            else
                btnStroke.Color = T.Colors.Border
                btnStrokeFade.SetBase(0.2, true)
                Tween(btn, { BackgroundColor3 = T.Colors.Surface }, 0.2, "Fast")
            end
        end

        local entry
        entry = {
            Alive = true,
            Matches = function(input)
                if not current then return false end
                if typeof(current) == "EnumItem" and current.EnumType == Enum.KeyCode then
                    return input.UserInputType == Enum.UserInputType.Keyboard
                        and input.KeyCode == current
                end
                return input.UserInputType == current
            end,
            OnDown = function()
                if listening then return end
                if mode == "Hold" then
                    state = true
                    FireCallback(cfg, api, true, current)
                elseif mode == "Toggle" then
                    state = not state
                    FireCallback(cfg, api, state, current)
                else
                    FireCallback(cfg, api, true, current)
                end
                Tween(btn, { BackgroundColor3 = T.Colors.Accent }, 0.08, "Fast")
                task.delay(0.14, function()
                    if not listening then
                        Tween(btn, { BackgroundColor3 = T.Colors.Surface }, 0.2, "Fast")
                    end
                end)
            end,
            OnUp = function()
                if mode == "Hold" and state then
                    state = false
                    FireCallback(cfg, api, false, current)
                end
            end,
        }
        table.insert(KeybindList, entry)

        btn.MouseButton1Click:Connect(function()
            if listening then return end
            listening = true
            Refresh()
            ActiveKeybindCapture = {
                Apply = function(key)
                    current = key
                    listening = false
                    Refresh()
                    SafeCall(cfg.OnBind, key)
                    if ctx.SetFlagValue and cfg.Flag then ctx.SetFlagValue(cfg.Flag, key) end
                end,
                Cancel = function()
                    current = nil
                    listening = false
                    Refresh()
                    SafeCall(cfg.OnBind, nil)
                end,
            }
        end)

        btn.MouseButton2Click:Connect(function()
            current = nil
            listening = false
            ActiveKeybindCapture = nil
            Refresh()
            SafeCall(cfg.OnBind, nil)
        end)

        Dual(api, "Set", function(key) current = key Refresh() end)
        Dual(api, "Get", function() return current end)
        Dual(api, "GetState", function() return state end)
        Dual(api, "SetMode", function(m) mode = m end)
        api.OnDestroy = function()
            entry.Alive = false
            for i, e in ipairs(KeybindList) do
                if e == entry then table.remove(KeybindList, i) break end
            end
        end
        Refresh()
        return Finish(api, root, cfg)
    end

    local function BuildDropdown(parent, cfg, opts)
        opts = opts or {}
        local multi = opts.Multi == true
        local searchable = opts.Search == true
        local isPlayers = opts.Players == true

        local options = {}
        local function NormalizeOptions(list)
            local out = {}
            for _, item in ipairs(list or {}) do
                if typeof(item) == "table" then
                    table.insert(out, tostring(item.Name or item.Text or item[1]))
                else
                    table.insert(out, tostring(item))
                end
            end
            return out
        end

        if isPlayers then
            options = {}
        else
            options = NormalizeOptions(cfg.Options)
        end

        local selected = nil
        local selectedSet = {}
        if multi then
            for _, v in ipairs(cfg.Default or {}) do selectedSet[tostring(v)] = true end
        else
            selected = cfg.Default and tostring(cfg.Default) or nil
        end

        local root, card, title = LabelledRow(parent, cfg, "Dropdown", 34, (cfg.BoxWidth or 150) + 10)

        local box = New("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(cfg.BoxWidth or 150, 26),
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Font = Enum.Font.GothamMedium,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Text = "",
            ZIndex = 5,
            Parent = card,
        })
        T.Paint(box, "BackgroundColor3", "Surface")
        T.Fade(box, "BackgroundTransparency", 0, "Fill")
        T.Paint(box, "TextColor3", "Text")
        T.Fade(box, "TextTransparency", 0, "Text")
        Corner(box, 6)
        Padding(box, 0, 0, 9, 24)
        local boxStroke = New("UIStroke", { Thickness = 1, Parent = box })
        T.Paint(boxStroke, "Color", "Border")
        local boxStrokeFade = T.Fade(boxStroke, "Transparency", 0.2, "Stroke")

        local arrow = Text(box, {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 16, 0.5, 0),
            Size = UDim2.fromOffset(16, 16),
            Font = Enum.Font.GothamBold,
            TextSize = 10,
            Text = "\u{25BC}",
            ZIndex = 6,
            Parent = box,
        }, "Accent")

        local holder = New("Frame", {
            Name = "DropdownOverlay",
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(0, 0),
            Visible = false,
            ClipsDescendants = true,
            ZIndex = 500,
            Parent = ctx.ScreenGui,
        })
        local panel = New("Frame", {
            Size = UDim2.fromScale(1, 1),
            BorderSizePixel = 0,
            ZIndex = 501,
            Parent = holder,
        })
        T.Paint(panel, "BackgroundColor3", "Surface")
        local panelFade = T.Fade(panel, "BackgroundTransparency", 0, "Fill")
        Corner(panel, 6)
        local panelStroke = New("UIStroke", { Thickness = 1, Parent = panel })
        T.Paint(panelStroke, "Color", "Accent")
        local panelStrokeFade = T.Fade(panelStroke, "Transparency", 0.25, "Stroke")

        local searchBox
        local searchHeight = searchable and 28 or 0
        if searchable then
            local sFrame, sBox = BuildTextBox(panel, {
                Placeholder = cfg.SearchPlaceholder or "Search...",
                TextSize = 12,
            }, {
                Position = UDim2.fromOffset(4, 4),
                Size = UDim2.new(1, -8, 0, 22),
                BorderSizePixel = 0,
                ZIndex = 503,
                Parent = panel,
            })
            sBox.ZIndex = 504
            searchBox = sBox
        end

        local scroll = New("ScrollingFrame", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, searchHeight + 4),
            Size = UDim2.new(1, 0, 1, -(searchHeight + 8)),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ScrollBarThickness = 3,
            ScrollBarImageTransparency = 0.4,
            ZIndex = 502,
            Parent = panel,
        })
        T.Paint(scroll, "ScrollBarImageColor3", "Muted")
        ListLayout(scroll, 2)
        Padding(scroll, 4, 4, 4, 4)

        local isOpen = false
        local optionButtons = {}
        local api = { Type = multi and "MultiDropdown" or "Dropdown", Changed = Signal.new() }

        local function DisplayText()
            if multi then
                local list = {}
                for _, opt in ipairs(options) do
                    if selectedSet[opt] then table.insert(list, opt) end
                end
                if #list == 0 then return cfg.Placeholder or "Nothing selected" end
                if #list > 3 then return #list .. " selected" end
                return table.concat(list, ", ")
            end
            return selected or cfg.Placeholder or "None"
        end

        local function RefreshBox()
            box.Text = DisplayText()
        end

        local function HighlightOptions()
            for opt, btn in pairs(optionButtons) do
                local active = multi and selectedSet[opt] or (opt == selected)
                Tween(btn, {
                    BackgroundColor3 = active and T.Colors.Accent or T.Colors.Surface2,
                    BackgroundTransparency = active and T.Eff(0.78, "Fill") or T.Eff(1, "Fill"),
                    TextColor3 = active and T.Colors.Accent or T.Colors.SubText,
                }, 0.12, "Fast")
                local mark = btn:FindFirstChild("Mark")
                if mark then
                    mark.Text = active and "\u{2713}" or ""
                end
            end
        end

        local Close, Open

        local function Choose(opt)
            if multi then
                selectedSet[opt] = not selectedSet[opt] or nil
                RefreshBox()
                HighlightOptions()
                local list = {}
                for _, o in ipairs(options) do
                    if selectedSet[o] then table.insert(list, o) end
                end
                FireCallback(cfg, api, list)
            else
                selected = opt
                RefreshBox()
                HighlightOptions()
                FireCallback(cfg, api, opt)
                Close()
            end
        end

        local function RebuildOptions(filter)
            for _, child in ipairs(scroll:GetChildren()) do
                if child:IsA("TextButton") then child:Destroy() end
            end
            table.clear(optionButtons)

            local shown = 0
            for index, opt in ipairs(options) do
                local visible = true
                if filter and filter ~= "" then
                    visible = string.find(string.lower(opt), string.lower(filter), 1, true) ~= nil
                end
                if visible then
                    shown = shown + 1
                    local btn = New("TextButton", {
                        Size = UDim2.new(1, 0, 0, 26),
                        BackgroundTransparency = 1,
                        AutoButtonColor = false,
                        BorderSizePixel = 0,
                        Font = Enum.Font.GothamMedium,
                        TextSize = 13,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        Text = opt,
                        LayoutOrder = index,
                        ZIndex = 503,
                        Parent = scroll,
                    })
                    T.Paint(btn, "TextColor3", "SubText")
                    T.Fade(btn, "TextTransparency", 0, "Text")
                    Corner(btn, 4)
                    Padding(btn, 0, 0, 8, 22)

                    if multi then
                        local mark = New("TextLabel", {
                            Name = "Mark",
                            BackgroundTransparency = 1,
                            AnchorPoint = Vector2.new(1, 0.5),
                            Position = UDim2.new(1, 18, 0.5, 0),
                            Size = UDim2.fromOffset(16, 16),
                            Font = Enum.Font.GothamBold,
                            TextSize = 13,
                            Text = "",
                            ZIndex = 504,
                            Parent = btn,
                        })
                        T.Paint(mark, "TextColor3", "Accent")
                        T.Fade(mark, "TextTransparency", 0, "Text")
                    end

                    Anim.Hover(btn, function()
                        local active = multi and selectedSet[opt] or (opt == selected)
                        if not active then
                            Tween(btn, {
                                BackgroundTransparency = T.Eff(0.85, "Fill"),
                                BackgroundColor3 = T.Colors.Surface3,
                                TextColor3 = T.Colors.Text,
                            }, 0.12, "Fast")
                        end
                    end, function()
                        HighlightOptions()
                    end)

                    btn.MouseButton1Click:Connect(function()
                        if ctx.PlaySound then ctx.PlaySound("Click") end
                        Choose(opt)
                    end)
                    optionButtons[opt] = btn
                end
            end
            HighlightOptions()
            return shown
        end

        local function TargetHeight(shown)
            local rows = math.clamp(shown or #options, 1, cfg.MaxVisible or 6)
            return rows * 28 + 10 + searchHeight
        end

        Close = function()
            if not isOpen then return end
            isOpen = false
            Tween(arrow, { Rotation = 0 }, 0.18, "Fast")
            boxStroke.Color = T.Colors.Border
            boxStrokeFade.SetBase(0.2, true)
            local tween = Tween(holder, { Size = UDim2.fromOffset(holder.Size.X.Offset, 0) }, 0.16, "In")
            Tween(panel, { BackgroundTransparency = 1 }, 0.16, "Fast")
            Tween(panelStroke, { Transparency = 1 }, 0.16, "Fast")
            if tween then
                tween.Completed:Connect(function()
                    if not isOpen then holder.Visible = false end
                end)
            else
                holder.Visible = false
            end
        end

        Open = function()
            if isOpen then return end
            CloseAllOverlays(holder)
            isOpen = true

            local shown = RebuildOptions(searchBox and searchBox.Text or nil)
            local height = TargetHeight(shown)
            local absPos = box.AbsolutePosition
            local absSize = box.AbsoluteSize
            local viewport = ViewportSize()

            local x = absPos.X
            local y = absPos.Y + absSize.Y + 4
            if y + height > viewport.Y - 8 then
                y = math.max(8, absPos.Y - height - 4)
            end
            x = math.clamp(x, 4, math.max(4, viewport.X - absSize.X - 4))

            holder.Position = UDim2.fromOffset(x, y)
            holder.Size = UDim2.fromOffset(absSize.X, 0)
            holder.Visible = true
            panelFade.Apply()
            panelStrokeFade.Apply()
            panel.BackgroundTransparency = 1
            panelStroke.Transparency = 1

            Tween(holder, { Size = UDim2.fromOffset(absSize.X, height) }, 0.2, "Snap")
            Tween(panel, { BackgroundTransparency = panelFade.Target() }, 0.2, "Fast")
            Tween(panelStroke, { Transparency = panelStrokeFade.Target() }, 0.2, "Fast")
            Tween(arrow, { Rotation = 180 }, 0.2, "Snap")
            boxStroke.Color = T.Colors.Accent
            boxStrokeFade.SetBase(0, true)

            if searchBox then
                searchBox.Text = ""
                task.defer(function() pcall(function() searchBox:CaptureFocus() end) end)
            end
        end

        if searchBox then
            searchBox:GetPropertyChangedSignal("Text"):Connect(function()
                if not isOpen then return end
                local shown = RebuildOptions(searchBox.Text)
                Tween(holder, { Size = UDim2.fromOffset(holder.AbsoluteSize.X, TargetHeight(shown)) }, 0.14, "Fast")
            end)
        end

        box.MouseButton1Click:Connect(function()
            if ctx.PlaySound then ctx.PlaySound("Click") end
            if isOpen then Close() else Open() end
        end)

        RegisterOverlay({
            Holder = holder,
            Trigger = box,
            IsOpen = function() return isOpen end,
            Close = Close,
        })

        local playerConns = {}
        if isPlayers then
            local function RefreshPlayers()
                local list = {}
                if cfg.IncludeSelf ~= false then table.insert(list, LocalPlayer.Name) end
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer then table.insert(list, plr.Name) end
                end
                table.sort(list)
                options = list
                if isOpen then RebuildOptions(searchBox and searchBox.Text or nil) end
                RefreshBox()
            end
            table.insert(playerConns, Players.PlayerAdded:Connect(function()
                task.wait(0.1) RefreshPlayers()
            end))
            table.insert(playerConns, Players.PlayerRemoving:Connect(function()
                task.wait(0.1) RefreshPlayers()
            end))
            RefreshPlayers()
        end

        Dual(api, "Set", function(value, silent)
            if multi then
                table.clear(selectedSet)
                for _, v in ipairs(value or {}) do selectedSet[tostring(v)] = true end
            else
                selected = value and tostring(value) or nil
            end
            RefreshBox()
            HighlightOptions()
            if not silent then
                FireCallback(cfg, api, multi and api.Get() or selected)
            end
        end)
        Dual(api, "Get", function()
            if multi then
                local list = {}
                for _, o in ipairs(options) do
                    if selectedSet[o] then table.insert(list, o) end
                end
                return list
            end
            return selected
        end)
        Dual(api, "SetOptions", function(newOptions, keepSelection)
            options = NormalizeOptions(newOptions)
            if not keepSelection then
                if multi then table.clear(selectedSet) else selected = nil end
            end
            RefreshBox()
            if isOpen then RebuildOptions(searchBox and searchBox.Text or nil) end
        end)
        Dual(api, "GetOptions", function() return table.clone(options) end)
        Dual(api, "AddOption", function(opt)
            table.insert(options, tostring(opt))
            if isOpen then RebuildOptions() end
        end)
        Dual(api, "RemoveOption", function(opt)
            for i, o in ipairs(options) do
                if o == tostring(opt) then table.remove(options, i) break end
            end
            selectedSet[tostring(opt)] = nil
            if selected == tostring(opt) then selected = nil end
            RefreshBox()
            if isOpen then RebuildOptions() end
        end)
        Dual(api, "Open", function() Open() end)
        Dual(api, "Close", function() Close() end)
        Dual(api, "Refresh", function() RebuildOptions() end)

        api.OnDestroy = function()
            holder:Destroy()
            for _, conn in ipairs(playerConns) do
                pcall(function() conn:Disconnect() end)
            end
        end

        RefreshBox()
        RebuildOptions()
        return Finish(api, root, cfg)
    end

    function Factory.Dropdown(parent, config)
        return BuildDropdown(parent, Cfg(config, "Name"), {})
    end
    function Factory.MultiDropdown(parent, config)
        return BuildDropdown(parent, Cfg(config, "Name"), { Multi = true })
    end
    function Factory.SearchableDropdown(parent, config)
        return BuildDropdown(parent, Cfg(config, "Name"), { Search = true })
    end
    function Factory.PlayerDropdown(parent, config)
        local cfg = Cfg(config, "Name")
        cfg.Name = cfg.Name or "Player"
        return BuildDropdown(parent, cfg, { Search = cfg.Search ~= false, Players = true, Multi = cfg.Multi == true })
    end

    function Factory.RadioGroup(parent, config)
        local cfg = Cfg(config, "Name")
        local options = cfg.Options or {}
        local selected = cfg.Default and tostring(cfg.Default) or nil

        local root = Root(parent, "RadioGroup", cfg)
        local column = New("Frame", {
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(1, 0, 0, 0),
            Parent = root,
        })
        ListLayout(column, 4)

        if cfg.Name then
            Text(column, {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 18),
                Font = Enum.Font.GothamMedium,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = cfg.Name,
                LayoutOrder = 0,
                Parent = column,
            }, "SubText")
        end

        local api = { Type = "RadioGroup", Changed = Signal.new() }
        local items = {}

        local function Refresh()
            for value, item in pairs(items) do
                local active = value == selected
                Tween(item.Dot, {
                    Size = active and UDim2.fromOffset(8, 8) or UDim2.fromOffset(0, 0),
                }, 0.16, "Pop")
                item.Ring.Color = active and T.Colors.Accent or T.Colors.Border
                Tween(item.Label, {
                    TextColor3 = active and T.Colors.Text or T.Colors.SubText,
                }, 0.14, "Fast")
            end
        end

        for index, opt in ipairs(options) do
            local value = tostring(opt)
            local row = New("TextButton", {
                Size = UDim2.new(1, 0, 0, 26),
                BackgroundTransparency = 1,
                AutoButtonColor = false,
                Text = "",
                LayoutOrder = index,
                Parent = column,
            })

            local circle = New("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 2, 0.5, 0),
                Size = UDim2.fromOffset(16, 16),
                BackgroundTransparency = 1,
                Parent = row,
            })
            Corner(circle, 999)
            local ring = New("UIStroke", { Thickness = 1.6, Parent = circle })
            T.Fade(ring, "Transparency", 0, "Stroke")

            local dot = New("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromOffset(0, 0),
                BorderSizePixel = 0,
                Parent = circle,
            })
            T.Paint(dot, "BackgroundColor3", "Accent")
            T.Fade(dot, "BackgroundTransparency", 0, "Fill")
            Corner(dot, 999)

            local label = Text(row, {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(26, 0),
                Size = UDim2.new(1, -26, 1, 0),
                Font = Enum.Font.GothamMedium,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = value,
                Parent = row,
            }, "SubText")

            items[value] = { Dot = dot, Ring = ring, Label = label }

            row.MouseButton1Click:Connect(function()
                if ctx.PlaySound then ctx.PlaySound("Click") end
                selected = value
                Refresh()
                FireCallback(cfg, api, value)
            end)
        end

        Dual(api, "Set", function(v, silent)
            selected = v and tostring(v) or nil
            Refresh()
            if not silent then FireCallback(cfg, api, selected) end
        end)
        Dual(api, "Get", function() return selected end)
        Refresh()
        return Finish(api, root, cfg)
    end

    function Factory.Segmented(parent, config)
        local cfg = Cfg(config, "Name")
        local options = cfg.Options or {}
        local selected = cfg.Default and tostring(cfg.Default) or (options[1] and tostring(options[1]))

        local root = Root(parent, "Segmented", cfg, cfg.Name and 54 or 32)

        if cfg.Name then
            Text(root, {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 18),
                Font = Enum.Font.GothamMedium,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = cfg.Name,
                Parent = root,
            }, "SubText")
        end

        local bar = Surface(root, {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, 0),
            Size = UDim2.new(1, 0, 0, 30),
            BorderSizePixel = 0,
            Parent = root,
        }, "Surface", 0.3)
        Padding(bar, 3, 3, 3, 3)

        local highlight = New("Frame", {
            Size = UDim2.fromScale(0, 1),
            BorderSizePixel = 0,
            ZIndex = 2,
            Parent = bar,
        })
        T.Paint(highlight, "BackgroundColor3", "Accent")
        T.Fade(highlight, "BackgroundTransparency", 0, "Fill")
        Corner(highlight, 5)

        local api = { Type = "Segmented", Changed = Signal.new() }
        local buttons = {}
        local count = math.max(#options, 1)

        local function Refresh(animate)
            for index, opt in ipairs(options) do
                local value = tostring(opt)
                local btn = buttons[value]
                if btn then
                    local active = value == selected
                    Tween(btn, {
                        TextColor3 = active and Color3.fromRGB(255, 255, 255) or T.Colors.SubText,
                    }, animate and 0.15 or 0, "Fast")
                    if active then
                        Tween(highlight, {
                            Position = UDim2.fromScale((index - 1) / count, 0),
                            Size = UDim2.fromScale(1 / count, 1),
                        }, animate and 0.22 or 0, "Snap")
                    end
                end
            end
        end

        for index, opt in ipairs(options) do
            local value = tostring(opt)
            local btn = New("TextButton", {
                Position = UDim2.fromScale((index - 1) / count, 0),
                Size = UDim2.fromScale(1 / count, 1),
                BackgroundTransparency = 1,
                AutoButtonColor = false,
                Font = Enum.Font.GothamBold,
                TextSize = 13,
                Text = value,
                ZIndex = 4,
                Parent = bar,
            })
            T.Fade(btn, "TextTransparency", 0, "Text")
            buttons[value] = btn
            btn.MouseButton1Click:Connect(function()
                if ctx.PlaySound then ctx.PlaySound("Click") end
                selected = value
                Refresh(true)
                FireCallback(cfg, api, value)
            end)
        end

        Dual(api, "Set", function(v, silent)
            selected = tostring(v)
            Refresh(true)
            if not silent then FireCallback(cfg, api, selected) end
        end)
        Dual(api, "Get", function() return selected end)
        task.defer(function() Refresh(false) end)
        return Finish(api, root, cfg)
    end

    function Factory.Chips(parent, config)
        local cfg = Cfg(config, "Name")
        local options = cfg.Options or {}
        local selectedSet = {}
        for _, v in ipairs(cfg.Default or {}) do selectedSet[tostring(v)] = true end

        local root = Root(parent, "Chips", cfg)
        local column = New("Frame", {
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(1, 0, 0, 0),
            Parent = root,
        })
        ListLayout(column, 6)

        if cfg.Name then
            Text(column, {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 18),
                Font = Enum.Font.GothamMedium,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = cfg.Name,
                LayoutOrder = 0,
                Parent = column,
            }, "SubText")
        end

        local wrap = New("Frame", {
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(1, 0, 0, 0),
            LayoutOrder = 1,
            Parent = column,
        })
        local wrapLayout = New("UIListLayout", {
            Padding = UDim.new(0, 6),
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = wrap,
        })
        pcall(function() wrapLayout.Wraps = true end)

        local api = { Type = "Chips", Changed = Signal.new() }
        local chips = {}

        local function Selected()
            local list = {}
            for _, opt in ipairs(options) do
                if selectedSet[tostring(opt)] then table.insert(list, tostring(opt)) end
            end
            return list
        end

        local function Refresh()
            for value, chip in pairs(chips) do
                local active = selectedSet[value] == true
                Tween(chip.Frame, {
                    BackgroundColor3 = active and T.Colors.Accent or T.Colors.Surface2,
                    BackgroundTransparency = active and T.Eff(0.75, "Fill") or T.Eff(0, "Fill"),
                }, 0.15, "Fast")
                chip.Stroke.Color = active and T.Colors.Accent or T.Colors.Border
                Tween(chip.Label, {
                    TextColor3 = active and T.Colors.Accent or T.Colors.SubText,
                }, 0.15, "Fast")
            end
        end

        for index, opt in ipairs(options) do
            local value = tostring(opt)
            local chip = New("TextButton", {
                Size = UDim2.fromOffset(0, 26),
                AutomaticSize = Enum.AutomaticSize.X,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Text = "",
                LayoutOrder = index,
                Parent = wrap,
            })
            T.Paint(chip, "BackgroundColor3", "Surface2")
            T.Fade(chip, "BackgroundTransparency", 0, "Fill")
            Corner(chip, 999)
            Padding(chip, 0, 0, 12, 12)
            local chipStroke = New("UIStroke", { Thickness = 1, Parent = chip })
            T.Fade(chipStroke, "Transparency", 0.2, "Stroke")

            local label = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(0, 0, 1, 0),
                AutomaticSize = Enum.AutomaticSize.X,
                Font = Enum.Font.GothamMedium,
                TextSize = 12,
                Text = value,
                Parent = chip,
            })
            T.Fade(label, "TextTransparency", 0, "Text")

            chips[value] = { Frame = chip, Label = label, Stroke = chipStroke }

            chip.MouseButton1Click:Connect(function()
                if ctx.PlaySound then ctx.PlaySound("Click") end
                if cfg.Single then
                    table.clear(selectedSet)
                    selectedSet[value] = true
                else
                    selectedSet[value] = not selectedSet[value] or nil
                end
                Refresh()
                FireCallback(cfg, api, cfg.Single and value or Selected())
            end)
        end

        Dual(api, "Set", function(values, silent)
            table.clear(selectedSet)
            if typeof(values) == "table" then
                for _, v in ipairs(values) do selectedSet[tostring(v)] = true end
            elseif values then
                selectedSet[tostring(values)] = true
            end
            Refresh()
            if not silent then FireCallback(cfg, api, Selected()) end
        end)
        Dual(api, "Get", function() return Selected() end)
        Refresh()
        return Finish(api, root, cfg)
    end

    function Factory.ColorPicker(parent, config)
        local cfg = Cfg(config, "Name")
        local color = cfg.Default or Color3.fromRGB(255, 255, 255)
        local h, s, v = color:ToHSV()
        local alpha = cfg.Alpha or 0
        local useAlpha = cfg.UseAlpha == true

        local root, card, title = LabelledRow(parent, cfg, "ColorPicker", 34, 60)

        local swatch = New("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(48, 24),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            ZIndex = 5,
            Parent = card,
        })
        T.Fade(swatch, "BackgroundTransparency", 0, "Fill")
        Corner(swatch, 6)
        local swatchStroke = New("UIStroke", { Thickness = 1, Parent = swatch })
        T.Paint(swatchStroke, "Color", "Border")
        local swatchStrokeFade = T.Fade(swatchStroke, "Transparency", 0.1, "Stroke")

        local panelWidth = 208
        local panelHeight = 200 + (useAlpha and 26 or 0)

        local holder = New("Frame", {
            Name = "ColorOverlay",
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(panelWidth, 0),
            Visible = false,
            ClipsDescendants = true,
            ZIndex = 500,
            Parent = ctx.ScreenGui,
        })
        local panel = New("Frame", {
            Size = UDim2.fromOffset(panelWidth, panelHeight),
            BorderSizePixel = 0,
            ZIndex = 501,
            Parent = holder,
        })
        T.Paint(panel, "BackgroundColor3", "Surface")
        local panelFade = T.Fade(panel, "BackgroundTransparency", 0, "Fill")
        Corner(panel, 8)
        local panelStroke = New("UIStroke", { Thickness = 1, Parent = panel })
        T.Paint(panelStroke, "Color", "Accent")
        local panelStrokeFade = T.Fade(panelStroke, "Transparency", 0.25, "Stroke")
        Padding(panel, 10, 10, 10, 10)

        local svArea = New("Frame", {
            Size = UDim2.fromOffset(188, 120),
            BackgroundColor3 = Color3.fromHSV(h, 1, 1),
            BorderSizePixel = 0,
            ZIndex = 502,
            Parent = panel,
        })
        Corner(svArea, 6)
        local whiteLayer = New("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BorderSizePixel = 0,
            ZIndex = 503,
            Parent = svArea,
        })
        Corner(whiteLayer, 6)
        New("UIGradient", {
            Color = ColorSequence.new(Color3.new(1, 1, 1)),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(1, 1),
            }),
            Parent = whiteLayer,
        })
        local blackLayer = New("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.new(0, 0, 0),
            BorderSizePixel = 0,
            ZIndex = 504,
            Parent = svArea,
        })
        Corner(blackLayer, 6)
        New("UIGradient", {
            Rotation = 90,
            Color = ColorSequence.new(Color3.new(0, 0, 0)),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(1, 0),
            }),
            Parent = blackLayer,
        })

        local svCursor = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(10, 10),
            BackgroundTransparency = 1,
            ZIndex = 506,
            Parent = svArea,
        })
        Corner(svCursor, 999)
        New("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1), Parent = svCursor })

        local hueBar = New("Frame", {
            Position = UDim2.fromOffset(0, 128),
            Size = UDim2.fromOffset(188, 14),
            BorderSizePixel = 0,
            ZIndex = 502,
            Parent = panel,
        })
        Corner(hueBar, 999)
        New("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
                ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
                ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
                ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
                ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
                ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
            }),
            Parent = hueBar,
        })
        local hueCursor = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0, 0.5),
            Size = UDim2.fromOffset(6, 20),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            ZIndex = 505,
            Parent = hueBar,
        })
        Corner(hueCursor, 999)

        local alphaBar, alphaCursor
        if useAlpha then
            alphaBar = New("Frame", {
                Position = UDim2.fromOffset(0, 148),
                Size = UDim2.fromOffset(188, 14),
                BackgroundColor3 = Color3.new(1, 1, 1),
                BorderSizePixel = 0,
                ZIndex = 502,
                Parent = panel,
            })
            Corner(alphaBar, 999)
            New("UIGradient", {
                Color = ColorSequence.new(color),
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0),
                    NumberSequenceKeypoint.new(1, 1),
                }),
                Parent = alphaBar,
            })
            alphaCursor = New("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0, 0.5),
                Size = UDim2.fromOffset(6, 20),
                BackgroundColor3 = Color3.new(1, 1, 1),
                BorderSizePixel = 0,
                ZIndex = 505,
                Parent = alphaBar,
            })
            Corner(alphaCursor, 999)
        end

        local hexFrame, hexBox = BuildTextBox(panel, { TextSize = 12, Placeholder = "#FFFFFF" }, {
            Position = UDim2.fromOffset(0, useAlpha and 170 or 150),
            Size = UDim2.fromOffset(100, 24),
            BorderSizePixel = 0,
            ZIndex = 503,
            Parent = panel,
        })
        hexBox.ZIndex = 504

        local preview = New("Frame", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, useAlpha and 170 or 150),
            Size = UDim2.fromOffset(80, 24),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            ZIndex = 503,
            Parent = panel,
        })
        Corner(preview, 6)

        local api = { Type = "ColorPicker", Changed = Signal.new() }
        local isOpen = false

        local function ToHex(c)
            return string.format("#%02X%02X%02X",
                math.floor(c.R * 255 + 0.5),
                math.floor(c.G * 255 + 0.5),
                math.floor(c.B * 255 + 0.5))
        end

        local function FromHex(hex)
            hex = tostring(hex):gsub("#", "")
            if #hex ~= 6 then return nil end
            local r = tonumber(hex:sub(1, 2), 16)
            local g = tonumber(hex:sub(3, 4), 16)
            local b = tonumber(hex:sub(5, 6), 16)
            if not r or not g or not b then return nil end
            return Color3.fromRGB(r, g, b)
        end

        local function ApplyColor(fromUser)
            color = Color3.fromHSV(h, s, v)
            swatch.BackgroundColor3 = color
            preview.BackgroundColor3 = color
            svArea.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
            svCursor.Position = UDim2.fromScale(s, 1 - v)
            hueCursor.Position = UDim2.fromScale(h, 0.5)
            if not hexBox:IsFocused() then hexBox.Text = ToHex(color) end
            if alphaBar then
                local grad = alphaBar:FindFirstChildOfClass("UIGradient")
                if grad then grad.Color = ColorSequence.new(color) end
                alphaCursor.Position = UDim2.fromScale(1 - alpha, 0.5)
                preview.BackgroundTransparency = alpha
            end
            if fromUser then
                if useAlpha then
                    FireCallback(cfg, api, color, alpha)
                else
                    FireCallback(cfg, api, color)
                end
            end
        end

        InputMgr.Bind(svArea, {
            OnBegin = function(pos)
                s = Clamp01((pos.X - svArea.AbsolutePosition.X) / svArea.AbsoluteSize.X)
                v = 1 - Clamp01((pos.Y - svArea.AbsolutePosition.Y) / svArea.AbsoluteSize.Y)
                ApplyColor(true)
            end,
            OnMove = function(pos)
                s = Clamp01((pos.X - svArea.AbsolutePosition.X) / svArea.AbsoluteSize.X)
                v = 1 - Clamp01((pos.Y - svArea.AbsolutePosition.Y) / svArea.AbsoluteSize.Y)
                ApplyColor(true)
            end,
        })

        InputMgr.Bind(hueBar, {
            OnBegin = function(pos)
                h = RelativeX(hueBar, pos.X)
                ApplyColor(true)
            end,
            OnMove = function(pos)
                h = RelativeX(hueBar, pos.X)
                ApplyColor(true)
            end,
        })

        if alphaBar then
            InputMgr.Bind(alphaBar, {
                OnBegin = function(pos)
                    alpha = 1 - RelativeX(alphaBar, pos.X)
                    ApplyColor(true)
                end,
                OnMove = function(pos)
                    alpha = 1 - RelativeX(alphaBar, pos.X)
                    ApplyColor(true)
                end,
            })
        end

        hexBox.FocusLost:Connect(function()
            local parsed = FromHex(hexBox.Text)
            if parsed then
                h, s, v = parsed:ToHSV()
                ApplyColor(true)
            else
                hexBox.Text = ToHex(color)
            end
        end)

        local function Close()
            if not isOpen then return end
            isOpen = false
            swatchStroke.Color = T.Colors.Border
            swatchStrokeFade.SetBase(0.1, true)
            local tween = Tween(holder, { Size = UDim2.fromOffset(panelWidth, 0) }, 0.16, "In")
            Tween(panel, { BackgroundTransparency = 1 }, 0.16, "Fast")
            if tween then
                tween.Completed:Connect(function()
                    if not isOpen then holder.Visible = false end
                end)
            end
        end

        local function Open()
            if isOpen then return end
            CloseAllOverlays(holder)
            isOpen = true
            local absPos = swatch.AbsolutePosition
            local absSize = swatch.AbsoluteSize
            local viewport = ViewportSize()
            local x = math.clamp(absPos.X + absSize.X - panelWidth, 6, math.max(6, viewport.X - panelWidth - 6))
            local y = absPos.Y + absSize.Y + 5
            if y + panelHeight > viewport.Y - 8 then
                y = math.max(8, absPos.Y - panelHeight - 5)
            end
            holder.Position = UDim2.fromOffset(x, y)
            holder.Size = UDim2.fromOffset(panelWidth, 0)
            holder.Visible = true
            panel.BackgroundTransparency = 1
            Tween(holder, { Size = UDim2.fromOffset(panelWidth, panelHeight) }, 0.22, "Snap")
            Tween(panel, { BackgroundTransparency = panelFade.Target() }, 0.2, "Fast")
            swatchStroke.Color = T.Colors.Accent
            swatchStrokeFade.SetBase(0, true)
            ApplyColor(false)
        end

        swatch.MouseButton1Click:Connect(function()
            if ctx.PlaySound then ctx.PlaySound("Click") end
            if isOpen then Close() else Open() end
        end)

        RegisterOverlay({
            Holder = holder,
            Trigger = swatch,
            IsOpen = function() return isOpen end,
            Close = Close,
        })

        Dual(api, "Set", function(newColor, silent)
            if typeof(newColor) == "string" then
                newColor = FromHex(newColor) or color
            end
            h, s, v = newColor:ToHSV()
            ApplyColor(not silent)
        end)
        Dual(api, "Get", function() return color end)
        Dual(api, "GetAlpha", function() return alpha end)
        Dual(api, "GetHex", function() return ToHex(color) end)
        Dual(api, "Open", function() Open() end)
        Dual(api, "Close", function() Close() end)
        api.OnDestroy = function() holder:Destroy() end

        ApplyColor(false)
        return Finish(api, root, cfg)
    end

    function Factory.Graph(parent, config)
        local cfg = Cfg(config, "Name")
        local maxPoints = cfg.MaxPoints or 60
        local minValue = cfg.Min or 0
        local maxValue = cfg.Max or 100
        local autoScale = cfg.AutoScale ~= false
        local height = cfg.Height or 90

        local root = Root(parent, "Graph", cfg, height + 22)

        local header = Text(root, {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -60, 0, 18),
            Font = Enum.Font.GothamMedium,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = tostring(cfg.Name or "Graph"),
            Parent = root,
        }, "SubText")

        local lastLabel = Text(root, {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, 0),
            Size = UDim2.fromOffset(60, 18),
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Right,
            Text = "0",
            Parent = root,
        }, "Accent")

        local area = Surface(root, {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, 0),
            Size = UDim2.new(1, 0, 0, height),
            BorderSizePixel = 0,
            ClipsDescendants = true,
            Parent = root,
        }, "Surface", 0.3)

        for i = 1, 3 do
            local line = New("Frame", {
                Position = UDim2.fromScale(0, i / 4),
                Size = UDim2.new(1, 0, 0, 1),
                BorderSizePixel = 0,
                ZIndex = 2,
                Parent = area,
            })
            T.Paint(line, "BackgroundColor3", "Border")
            T.Fade(line, "BackgroundTransparency", 0.6, "Stroke")
        end

        local points = {}
        local segments = {}

        local function Redraw()
            local count = #points
            if count < 2 then return end
            local lo, hi = minValue, maxValue
            if autoScale then
                lo, hi = math.huge, -math.huge
                for _, p in ipairs(points) do
                    lo = math.min(lo, p)
                    hi = math.max(hi, p)
                end
                if hi - lo < 1e-3 then hi = lo + 1 end
                lo = lo - (hi - lo) * 0.1
                hi = hi + (hi - lo) * 0.1
            end

            local width = area.AbsoluteSize.X
            local tall = area.AbsoluteSize.Y
            if width <= 0 or tall <= 0 then return end
            local stepX = width / (maxPoints - 1)

            for index = 1, count - 1 do
                local segment = segments[index]
                if not segment then
                    segment = New("Frame", {
                        AnchorPoint = Vector2.new(0, 0.5),
                        Size = UDim2.fromOffset(0, 2),
                        BorderSizePixel = 0,
                        ZIndex = 5,
                        Parent = area,
                    })
                    T.Paint(segment, "BackgroundColor3", "Accent")
                    T.Fade(segment, "BackgroundTransparency", 0, "Fill")
                    segments[index] = segment
                end
                local offset = maxPoints - count
                local x1 = (index - 1 + offset) * stepX
                local x2 = (index + offset) * stepX
                local y1 = tall - Clamp01((points[index] - lo) / (hi - lo)) * tall
                local y2 = tall - Clamp01((points[index + 1] - lo) / (hi - lo)) * tall
                local dx, dy = x2 - x1, y2 - y1
                local length = math.sqrt(dx * dx + dy * dy)
                segment.Position = UDim2.fromOffset(x1, y1)
                segment.Size = UDim2.fromOffset(length, 2)
                segment.Rotation = math.deg(math.atan2(dy, dx))
                segment.Visible = true
            end
            for index = count, #segments do
                if segments[index] then segments[index].Visible = false end
            end
        end

        local api = { Type = "Graph" }
        Dual(api, "Push", function(value)
            local number = tonumber(value) or 0
            table.insert(points, number)
            while #points > maxPoints do table.remove(points, 1) end
            lastLabel.Text = FormatNumber(number, cfg.Decimals)
            Redraw()
        end)
        Dual(api, "Set", function(list)
            points = {}
            for _, v in ipairs(list or {}) do table.insert(points, tonumber(v) or 0) end
            Redraw()
        end)
        Dual(api, "Clear", function()
            points = {}
            for _, segment in ipairs(segments) do segment.Visible = false end
        end)
        Dual(api, "Get", function() return table.clone(points) end)
        Dual(api, "SetTitle", function(v) header.Text = tostring(v) end)

        area:GetPropertyChangedSignal("AbsoluteSize"):Connect(Redraw)
        return Finish(api, root, cfg)
    end

    function Factory.Console(parent, config)
        local cfg = Cfg(config, "Name")
        local height = cfg.Height or 130
        local maxLines = cfg.MaxLines or 200
        local root = Root(parent, "Console", cfg, height + 22)

        Text(root, {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -60, 0, 18),
            Font = Enum.Font.GothamMedium,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = tostring(cfg.Name or "Console"),
            Parent = root,
        }, "SubText")

        local clearBtn = New("TextButton", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, 0),
            Size = UDim2.fromOffset(56, 18),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            Text = "CLEAR",
            AutoButtonColor = false,
            Parent = root,
        })
        T.Paint(clearBtn, "TextColor3", "Muted")
        T.Fade(clearBtn, "TextTransparency", 0, "Text")

        local area = Surface(root, {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, 0),
            Size = UDim2.new(1, 0, 0, height),
            BorderSizePixel = 0,
            Parent = root,
        }, "Base", 0.3)

        local scroll = New("ScrollingFrame", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ScrollBarThickness = 3,
            ScrollBarImageTransparency = 0.4,
            Parent = area,
        })
        T.Paint(scroll, "ScrollBarImageColor3", "Muted")
        ListLayout(scroll, 1)
        Padding(scroll, 5, 5, 7, 7)

        local LEVEL_COLORS = { Info = "SubText", Good = "Good", Warn = "Warn", Bad = "Bad", Accent = "Accent" }
        local lines = {}
        local api = { Type = "Console" }

        local function Log(text, level)
            local label = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Font = Enum.Font.Code,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                TextWrapped = true,
                LayoutOrder = #lines + 1,
                Text = (cfg.Timestamp ~= false and ("[" .. os.date("%H:%M:%S") .. "] ") or "") .. tostring(text),
                Parent = scroll,
            })
            T.Paint(label, "TextColor3", LEVEL_COLORS[level or "Info"] or "SubText")
            T.Fade(label, "TextTransparency", 0, "Text")
            table.insert(lines, label)
            while #lines > maxLines do
                local old = table.remove(lines, 1)
                if old then old:Destroy() end
            end
            task.defer(function()
                if scroll.Parent then
                    scroll.CanvasPosition = Vector2.new(0, math.max(0, scroll.AbsoluteCanvasSize.Y))
                end
            end)
        end

        clearBtn.MouseButton1Click:Connect(function()
            for _, label in ipairs(lines) do label:Destroy() end
            table.clear(lines)
        end)

        Dual(api, "Log", function(text, level) Log(text, level) end)
        Dual(api, "Info", function(text) Log(text, "Info") end)
        Dual(api, "Success", function(text) Log(text, "Good") end)
        Dual(api, "Warn", function(text) Log(text, "Warn") end)
        Dual(api, "Error", function(text) Log(text, "Bad") end)
        Dual(api, "Clear", function()
            for _, label in ipairs(lines) do label:Destroy() end
            table.clear(lines)
        end)
        Dual(api, "Set", function(text) Log(text, "Info") end)
        return Finish(api, root, cfg)
    end

    function Factory.ListView(parent, config)
        local cfg = Cfg(config, "Name")
        local height = cfg.Height or 120
        local root = Root(parent, "ListView", cfg, height + (cfg.Name and 22 or 0))

        if cfg.Name then
            Text(root, {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 18),
                Font = Enum.Font.GothamMedium,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = cfg.Name,
                Parent = root,
            }, "SubText")
        end

        local area = Surface(root, {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, 0),
            Size = UDim2.new(1, 0, 0, height),
            BorderSizePixel = 0,
            Parent = root,
        }, "Surface", 0.3)

        local scroll = New("ScrollingFrame", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ScrollBarThickness = 3,
            ScrollBarImageTransparency = 0.4,
            Parent = area,
        })
        T.Paint(scroll, "ScrollBarImageColor3", "Muted")
        ListLayout(scroll, 3)
        Padding(scroll, 5, 5, 6, 6)

        local api = { Type = "ListView", Changed = Signal.new() }
        local items = {}

        local function AddItem(text, itemCfg)
            itemCfg = itemCfg or {}
            local row = New("TextButton", {
                Size = UDim2.new(1, 0, 0, 26),
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Text = "",
                LayoutOrder = #items + 1,
                Parent = scroll,
            })
            T.Paint(row, "BackgroundColor3", "Surface2")
            T.Fade(row, "BackgroundTransparency", 0.2, "Fill")
            Corner(row, 5)

            local label = Text(row, {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(8, 0),
                Size = UDim2.new(1, cfg.Removable == false and -16 or -34, 1, 0),
                Font = Enum.Font.GothamMedium,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Text = tostring(text),
                Parent = row,
            }, "Text")

            local entry = { Instance = row, Text = tostring(text), Data = itemCfg.Data }

            if cfg.Removable ~= false then
                local remove = New("TextButton", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -6, 0.5, 0),
                    Size = UDim2.fromOffset(20, 20),
                    BackgroundTransparency = 1,
                    Font = Enum.Font.GothamBold,
                    TextSize = 15,
                    Text = "\u{00D7}",
                    AutoButtonColor = false,
                    Parent = row,
                })
                T.Paint(remove, "TextColor3", "Muted")
                T.Fade(remove, "TextTransparency", 0, "Text")
                Anim.Hover(remove, function()
                    Tween(remove, { TextColor3 = T.Colors.Bad, TextSize = 17 }, 0.12, "Fast")
                end, function()
                    Tween(remove, { TextColor3 = T.Colors.Muted, TextSize = 15 }, 0.15, "Fast")
                end)
                remove.MouseButton1Click:Connect(function()
                    for i, it in ipairs(items) do
                        if it == entry then table.remove(items, i) break end
                    end
                    local tween = Tween(row, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0) }, 0.16, "In")
                    if tween then
                        tween.Completed:Connect(function() row:Destroy() end)
                    else
                        row:Destroy()
                    end
                    SafeCall(cfg.OnRemove, entry.Text, entry.Data)
                end)
            end

            Anim.Hover(row, function()
                Tween(row, { BackgroundColor3 = T.Colors.Surface3 }, 0.12, "Fast")
            end, function()
                Tween(row, { BackgroundColor3 = T.Colors.Surface2 }, 0.15, "Fast")
            end)

            row.MouseButton1Click:Connect(function()
                SafeCall(cfg.OnClick, entry.Text, entry.Data)
                api.Changed:Fire(entry.Text, entry.Data)
            end)

            table.insert(items, entry)
            return entry
        end

        Dual(api, "Add", function(text, itemCfg) return AddItem(text, itemCfg) end)
        Dual(api, "Clear", function()
            for _, item in ipairs(items) do item.Instance:Destroy() end
            table.clear(items)
        end)
        Dual(api, "Get", function()
            local list = {}
            for _, item in ipairs(items) do table.insert(list, item.Text) end
            return list
        end)
        Dual(api, "Set", function(list)
            for _, item in ipairs(items) do item.Instance:Destroy() end
            table.clear(items)
            for _, text in ipairs(list or {}) do AddItem(text) end
        end)
        Dual(api, "Remove", function(text)
            for i, item in ipairs(items) do
                if item.Text == tostring(text) then
                    item.Instance:Destroy()
                    table.remove(items, i)
                    break
                end
            end
        end)
        Dual(api, "Count", function() return #items end)

        for _, text in ipairs(cfg.Items or {}) do AddItem(text) end
        return Finish(api, root, cfg)
    end

    function Factory.Table(parent, config)
        local cfg = Cfg(config, "Name")
        local columns = cfg.Columns or { "A", "B" }
        local height = cfg.Height or 130
        local root = Root(parent, "Table", cfg, height + 22 + (cfg.Name and 22 or 0))

        if cfg.Name then
            Text(root, {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 18),
                Font = Enum.Font.GothamMedium,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = cfg.Name,
                Parent = root,
            }, "SubText")
        end

        local wrapper = New("Frame", {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, 0),
            Size = UDim2.new(1, 0, 0, height + 22),
            BackgroundTransparency = 1,
            Parent = root,
        })

        local header = Surface(wrapper, {
            Size = UDim2.new(1, 0, 0, 22),
            BorderSizePixel = 0,
            Parent = wrapper,
        }, "Surface3", 0.25)

        local columnCount = #columns
        for index, column in ipairs(columns) do
            Text(header, {
                BackgroundTransparency = 1,
                Position = UDim2.fromScale((index - 1) / columnCount, 0),
                Size = UDim2.fromScale(1 / columnCount, 1),
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Text = "  " .. tostring(column),
                Parent = header,
            }, "Text")
        end

        local area = Surface(wrapper, {
            Position = UDim2.fromOffset(0, 24),
            Size = UDim2.new(1, 0, 0, height - 2),
            BorderSizePixel = 0,
            Parent = wrapper,
        }, "Surface", 0.35)

        local scroll = New("ScrollingFrame", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ScrollBarThickness = 3,
            ScrollBarImageTransparency = 0.4,
            Parent = area,
        })
        T.Paint(scroll, "ScrollBarImageColor3", "Muted")
        ListLayout(scroll, 1)
        Padding(scroll, 3, 3, 2, 2)

        local api = { Type = "Table" }
        local rows = {}

        local function AddRow(values)
            local row = New("TextButton", {
                Size = UDim2.new(1, 0, 0, 24),
                BackgroundTransparency = 1,
                AutoButtonColor = false,
                Text = "",
                LayoutOrder = #rows + 1,
                Parent = scroll,
            })
            T.Paint(row, "BackgroundColor3", "Surface2")
            local rowFade = T.Fade(row, "BackgroundTransparency", (#rows % 2 == 0) and 0.5 or 1, "Fill")
            Corner(row, 4)

            for index = 1, columnCount do
                Text(row, {
                    BackgroundTransparency = 1,
                    Position = UDim2.fromScale((index - 1) / columnCount, 0),
                    Size = UDim2.fromScale(1 / columnCount, 1),
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Text = "  " .. tostring(values[index] or ""),
                    Parent = row,
                }, index == 1 and "Text" or "SubText")
            end

            Anim.Hover(row, function()
                rowFade.SetBase(0.15, true)
                Tween(row, { BackgroundColor3 = T.Colors.Surface3 }, 0.12, "Fast")
            end, function()
                rowFade.SetBase((row.LayoutOrder % 2 == 1) and 0.5 or 1, true)
                Tween(row, { BackgroundColor3 = T.Colors.Surface2 }, 0.15, "Fast")
            end)

            row.MouseButton1Click:Connect(function()
                SafeCall(cfg.OnRowClick, values, row.LayoutOrder)
            end)

            table.insert(rows, { Instance = row, Values = values })
            return row
        end

        Dual(api, "AddRow", function(values) return AddRow(values or {}) end)
        Dual(api, "Add", function(values) return AddRow(values or {}) end)
        Dual(api, "Clear", function()
            for _, row in ipairs(rows) do row.Instance:Destroy() end
            table.clear(rows)
        end)
        Dual(api, "Set", function(list)
            for _, row in ipairs(rows) do row.Instance:Destroy() end
            table.clear(rows)
            for _, values in ipairs(list or {}) do AddRow(values) end
        end)
        Dual(api, "Get", function()
            local out = {}
            for _, row in ipairs(rows) do table.insert(out, row.Values) end
            return out
        end)
        Dual(api, "Count", function() return #rows end)

        for _, values in ipairs(cfg.Rows or {}) do AddRow(values) end
        return Finish(api, root, cfg)
    end

    function Factory.Group(parent, config)
        local cfg = Cfg(config, "Name")
        local open = cfg.Open ~= false

        local root = Root(parent, "Group", cfg)
        local card, cardFade, stroke, strokeFade = Surface(root, {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            Parent = root,
        }, "Surface", 0.3)

        local header = New("TextButton", {
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Text = "",
            ZIndex = 3,
            Parent = card,
        })

        local titleLabel = Text(header, {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(28, 0),
            Size = UDim2.new(1, -36, 1, 0),
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = tostring(cfg.Name or cfg.Text or "Group"),
            Parent = header,
        }, "Text")

        local arrow = Text(header, {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 10, 0.5, 0),
            Size = UDim2.fromOffset(12, 12),
            Font = Enum.Font.GothamBold,
            TextSize = 10,
            Text = "\u{25B6}",
            Parent = header,
        }, "Accent")

        local bodyClip = New("Frame", {
            Position = UDim2.fromOffset(0, 32),
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            ClipsDescendants = true,
            Parent = card,
        })

        local body = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Parent = bodyClip,
        })
        Padding(body, 0, 8, 8, 8)
        local bodyLayout = ListLayout(body, 6)

        local api = { Type = "Group" }

        local function Refresh(animate)
            local contentHeight = bodyLayout.AbsoluteContentSize.Y + 8
            local target = open and contentHeight or 0
            Tween(bodyClip, { Size = UDim2.new(1, 0, 0, target) }, animate and 0.24 or 0, "Snap")
            Tween(arrow, { Rotation = open and 90 or 0 }, animate and 0.2 or 0, "Snap")
        end

        bodyLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            if open then Refresh(false) end
        end)

        header.MouseButton1Click:Connect(function()
            if ctx.PlaySound then ctx.PlaySound("Click") end
            open = not open
            Refresh(true)
            SafeCall(cfg.OnToggle, open)
        end)

        Anim.Hover(header, function()
            Tween(card, { BackgroundColor3 = T.Colors.Surface2 }, 0.15, "Fast")
        end, function()
            Tween(card, { BackgroundColor3 = T.Colors.Surface }, 0.2, "Fast")
        end)

        Dual(api, "SetOpen", function(value, animate)
            open = value ~= false
            Refresh(animate ~= false)
        end)
        Dual(api, "Toggle", function() open = not open Refresh(true) end)
        Dual(api, "IsOpen", function() return open end)
        Dual(api, "SetTitle", function(v) titleLabel.Text = tostring(v) end)
        Dual(api, "Clear", function()
            for _, child in ipairs(body:GetChildren()) do
                if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
                    child:Destroy()
                end
            end
        end)
        Dual(api, "GetContainer", function() return body end)

        BindContainer(api, function() return body end)
        task.defer(function() Refresh(false) end)
        return Finish(api, root, cfg)
    end

    function Factory.Card(parent, config)
        local cfg = Cfg(config, "Name")
        local root = Root(parent, "Card", cfg)
        local card = Surface(root, {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BorderSizePixel = 0,
            Parent = root,
        }, "Surface", 0.3)
        Padding(card, 10, 10, 10, 10)
        ListLayout(card, 6)

        if cfg.Name then
            local titleRow = New("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 20),
                LayoutOrder = -1,
                Parent = card,
            })
            Text(titleRow, {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Font = Enum.Font.GothamBold,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = cfg.Name,
                Parent = titleRow,
            }, "Text")
        end

        local api = { Type = "Card" }
        Dual(api, "GetContainer", function() return card end)
        Dual(api, "Clear", function()
            for _, child in ipairs(card:GetChildren()) do
                if not child:IsA("UIListLayout") and not child:IsA("UIPadding")
                    and not child:IsA("UICorner") and not child:IsA("UIStroke") then
                    child:Destroy()
                end
            end
        end)
        BindContainer(api, function() return card end)
        return Finish(api, root, cfg)
    end

    local ALIASES = {
        AddText = "Label", AddTitle = "Section", AddSeparator = "Divider",
        AddColorpicker = "ColorPicker", AddTextBox = "Textbox",
        AddMultiSelect = "MultiDropdown", AddSearchDropdown = "SearchableDropdown",
        AddList = "ListView", AddProgress = "ProgressBar", AddLoading = "Spinner",
        AddPlayerSelect = "PlayerDropdown", AddNumber = "Stepper",
    }

    BindContainer = function(target, getParent)
        for _, name in ipairs(ELEMENT_NAMES) do
            local builder = Factory[name]
            target["Add" .. name] = function(a, b)
                local config = b
                if a ~= target then config = a end
                return builder(getParent(), config)
            end
        end
        for alias, name in pairs(ALIASES) do
            local builder = Factory[name]
            target[alias] = function(a, b)
                local config = b
                if a ~= target then config = a end
                return builder(getParent(), config)
            end
        end
        return target
    end

    Factory.BindContainer = function(target, getParent)
        return BindContainer(target, getParent)
    end

    return Factory
end

local function CreateTab(ctx, tabName, options)
    options = options or {}

    local page = New("ScrollingFrame", {
        Name = "Page_" .. tabName,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromOffset(0, 0),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 4,
        ScrollBarImageTransparency = 0.35,
        ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
        Visible = false,
        Parent = ctx.PageHolder,
    })
    ctx.Theme.Paint(page, "ScrollBarImageColor3", "Accent")
    ListLayout(page, options.Padding or 7)
    Padding(page, 2, 12, 1, 8)

    local Tab = {
        Name = tabName,
        Instance = page,
        Icon = options.Icon,
        Type = "Tab",
    }

    function Tab:GetContainer() return page end

    function Tab:Clear()
        for _, child in ipairs(page:GetChildren()) do
            if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
                child:Destroy()
            end
        end
    end

    function Tab:Refresh()
        page.CanvasPosition = Vector2.new(0, 0)
    end

    function Tab:ScrollToTop()
        Tween(page, { CanvasPosition = Vector2.new(0, 0) }, 0.3, "Snap")
    end

    function Tab:SetVisible(value)
        page.Visible = value ~= false
    end

    function Tab:Select()
        if ctx.SelectTab then ctx.SelectTab(tabName) end
    end

    ctx.Factory.BindContainer(Tab, function() return page end)
    return Tab
end

local function CreateWindow(config)
    config = config or {}

    SHARP = config.Rounded ~= true
    local windowName   = config.Name or "Lurk"
    local subtitle     = config.Subtitle or "v2.0"
    local baseWidth    = 430
    local baseHeight   = 320
    if config.Size then
        baseWidth  = config.Size.X.Offset > 0 and config.Size.X.Offset or baseWidth
        baseHeight = config.Size.Y.Offset > 0 and config.Size.Y.Offset or baseHeight
    end
    baseWidth  = config.Width or baseWidth
    baseHeight = config.Height or baseHeight

    local minWidth  = config.MinWidth or 340
    local minHeight = config.MinHeight or 240
    local maxWidth  = config.MaxWidth or 1100
    local maxHeight = config.MaxHeight or 800

    local sidebarWidth = config.SidebarWidth or 108
    local logoText     = config.LogoText or config.OpenButtonText or string.sub(windowName, 1, 1)
    local toggleKey    = config.ToggleKey or Enum.KeyCode.RightShift

    local existing = GuiParent:FindFirstChild("LurkGui_" .. windowName)
    if existing then existing:Destroy() end

    local ScreenGui = New("ScreenGui", {
        Name = "LurkGui_" .. windowName,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 999999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    ProtectGui(ScreenGui)
    ScreenGui.Parent = GuiParent

    local Theme = CreateTheme(config)

    local ctx = {
        Theme = Theme,
        ScreenGui = ScreenGui,
    }
    local Factory = CreateFactory(ctx)
    ctx.Factory = Factory

    local Window = {}
    Window.Name = windowName
    Window.ScreenGui = ScreenGui
    Window.Theme = Theme
    Window.Flags = {}
    Window.Elements = {}

    local soundEnabled = config.Sound == true
    local soundId = config.SoundId or ""
    local clickSound
    if soundId ~= "" then
        clickSound = New("Sound", { SoundId = soundId, Volume = 0.35, Parent = ScreenGui })
    end
    function ctx.PlaySound()
        if soundEnabled and clickSound then
            pcall(function() clickSound:Play() end)
        end
    end

    function ctx.RegisterFlag(flag, api)
        Window.Elements[flag] = api
        if api.Get then
            Window.Flags[flag] = api.Get()
        end
    end
    function ctx.SetFlagValue(flag, value)
        Window.Flags[flag] = value
    end

    local viewport = ViewportSize()
    local windowClass = "Frame"
    local canvasOk = pcall(function()
        local probe = Instance.new("CanvasGroup")
        probe:Destroy()
    end)
    if canvasOk then windowClass = "CanvasGroup" end

    local mainWindow = New(windowClass, {
        Name = "MainWindow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(viewport.X / 2, viewport.Y / 2),
        Size = UDim2.fromOffset(baseWidth, baseHeight),
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 2,
        Parent = ScreenGui,
    })
    Theme.Paint(mainWindow, "BackgroundColor3", "Base")
    local windowFade = Theme.Fade(mainWindow, "BackgroundTransparency", 0, "Fill")

    local windowScale = New("UIScale", { Scale = config.Scale or 1, Parent = mainWindow })
    local baseScale = config.Scale or 1
    local masterAlpha = config.MasterTransparency or 0

    local function AddLayer(parent, inset, role, zOffset)
        local layer = New("Frame", {
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(inset, inset),
            Size = UDim2.new(1, -inset * 2, 1, -inset * 2),
            ZIndex = parent.ZIndex + (zOffset or 1),
            Parent = parent,
        })
        Theme.Paint(layer, "BackgroundColor3", role)
        Theme.Fade(layer, "BackgroundTransparency", 0, "Fill")
        return layer
    end

    AddLayer(mainWindow, 1, "Border", 1)
    local bg1 = AddLayer(mainWindow, 2, "Bevel", 2)
    AddLayer(bg1, 3, "Border", 1)
    local bg2 = AddLayer(bg1, 4, "Base", 2)

    local titleBar = New("Frame", {
        Name = "TitleBar",
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(6, 6),
        Size = UDim2.new(1, -12, 0, 24),
        ZIndex = bg2.ZIndex + 1,
        Parent = bg2,
    })
    Theme.Paint(titleBar, "BackgroundColor3", "Surface2")
    Theme.Fade(titleBar, "BackgroundTransparency", 0, "Fill")

    local titleText = New("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        Text = windowName,
        ZIndex = titleBar.ZIndex + 1,
        Parent = titleBar,
    })
    Theme.Paint(titleText, "TextColor3", "Accent")
    Theme.Fade(titleText, "TextTransparency", 0, "Text")

    local function TitleButton(text, offsetX, color, callback)
        local btn = New("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, offsetX, 0.5, 0),
            Size = UDim2.fromOffset(18, 18),
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            Text = text,
            ZIndex = titleBar.ZIndex + 2,
            Parent = titleBar,
        })
        Theme.Paint(btn, "TextColor3", "Muted")
        Theme.Fade(btn, "TextTransparency", 0, "Text")
        Anim.Hover(btn, function()
            Tween(btn, {
                TextColor3 = color and Theme.Colors[color] or Theme.Colors.Text,
            }, 0.14, "Fast")
        end, function()
            Tween(btn, { TextColor3 = Theme.Colors.Muted }, 0.18, "Fast")
        end)
        btn.MouseButton1Click:Connect(callback)
        return btn
    end

    local sidebar = New("Frame", {
        Name = "Sidebar",
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(6, 33),
        Size = UDim2.new(0, sidebarWidth - 6, 1, -39),
        ZIndex = bg2.ZIndex + 1,
        Parent = bg2,
    })
    Theme.Paint(sidebar, "BackgroundColor3", "Surface")
    Theme.Fade(sidebar, "BackgroundTransparency", 0, "Fill")

    AddLayer(sidebar, 1, "Bevel", 1)
    local sidebarInner = AddLayer(sidebar, 2, "Base", 2)

    local logoGlow = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 6),
        Size = UDim2.new(1, 0, 0, 48),
        Font = Enum.Font.GothamBlack,
        TextSize = 42,
        Text = logoText,
        ZIndex = sidebarInner.ZIndex + 1,
        Parent = sidebarInner,
    })
    Theme.Paint(logoGlow, "TextColor3", "Accent")
    Theme.Fade(logoGlow, "TextTransparency", 0.7, "Text")

    local logoLabel = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 6),
        Size = UDim2.new(1, 0, 0, 48),
        Font = Enum.Font.GothamBlack,
        TextSize = 36,
        Text = logoText,
        ZIndex = sidebarInner.ZIndex + 2,
        Parent = sidebarInner,
    })
    Theme.Paint(logoLabel, "TextColor3", "Text")
    Theme.Fade(logoLabel, "TextTransparency", 0, "Text")

    local subtitleText = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 54),
        Size = UDim2.new(1, 0, 0, 12),
        Font = Enum.Font.Gotham,
        TextSize = 10,
        Text = subtitle,
        ZIndex = sidebarInner.ZIndex + 2,
        Parent = sidebarInner,
    })
    Theme.Paint(subtitleText, "TextColor3", "Muted")
    Theme.Fade(subtitleText, "TextTransparency", 0, "Text")

    local searchFrame = New("Frame", {
        Position = UDim2.fromOffset(8, 72),
        Size = UDim2.new(1, -16, 0, 18),
        BorderSizePixel = 0,
        ZIndex = sidebarInner.ZIndex + 1,
        Parent = sidebarInner,
    })
    Theme.Paint(searchFrame, "BackgroundColor3", "Surface2")
    Theme.Fade(searchFrame, "BackgroundTransparency", 0, "Fill")
    local searchStroke = New("UIStroke", { Thickness = 1, Parent = searchFrame })
    Theme.Paint(searchStroke, "Color", "Border")
    Theme.Fade(searchStroke, "Transparency", 0, "Stroke")

    local searchBox = New("TextBox", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(6, 0),
        Size = UDim2.new(1, -10, 1, 0),
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        PlaceholderText = "Search...",
        Text = "",
        ClearTextOnFocus = false,
        ZIndex = searchFrame.ZIndex + 1,
        Parent = searchFrame,
    })
    Theme.Paint(searchBox, "TextColor3", "Text")
    Theme.Paint(searchBox, "PlaceholderColor3", "Muted")
    Theme.Fade(searchBox, "TextTransparency", 0, "Text")

    searchBox.Focused:Connect(function()
        Tween(searchStroke, { Color = Theme.Colors.Accent }, 0.16, "Fast")
    end)
    searchBox.FocusLost:Connect(function()
        Tween(searchStroke, { Color = Theme.Colors.Border }, 0.2, "Fast")
    end)

    local tabsHolder = New("ScrollingFrame", {
        Name = "TabsHolder",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(8, 98),
        Size = UDim2.new(1, -16, 1, -106),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 0,
        ZIndex = sidebarInner.ZIndex + 1,
        Parent = sidebarInner,
    })
    ListLayout(tabsHolder, 6)

    local content = New("Frame", {
        Name = "Content",
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(sidebarWidth, 33),
        Size = UDim2.new(1, -sidebarWidth - 9, 1, -39),
        ZIndex = bg2.ZIndex + 1,
        Parent = bg2,
    })
    Theme.Paint(content, "BackgroundColor3", "Base")
    Theme.Fade(content, "BackgroundTransparency", 0, "Fill")

    AddLayer(content, 1, "Bevel", 1)
    local contentInner = AddLayer(content, 2, "Surface3", 2)

    local tabTitle = New("TextLabel", {
        Name = "TabTitle",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(16, 8),
        Size = UDim2.new(1, -32, 0, 24),
        Font = Enum.Font.GothamBold,
        TextSize = 17,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "",
        ZIndex = contentInner.ZIndex + 1,
        Parent = contentInner,
    })
    Theme.Paint(tabTitle, "TextColor3", "Text")
    Theme.Fade(tabTitle, "TextTransparency", 0, "Text")

    local pageHolder = New("Frame", {
        Name = "PageHolder",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 36),
        Size = UDim2.new(1, -24, 1, -42),
        ClipsDescendants = true,
        ZIndex = contentInner.ZIndex + 1,
        Parent = contentInner,
    })

    ctx.PageHolder = pageHolder

    local resizeGrip = New("TextButton", {
        Name = "ResizeGrip",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -3, 1, -3),
        Size = UDim2.fromOffset(16, 16),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 20,
        Parent = mainWindow,
    })
    for i = 1, 3 do
        local dash = New("Frame", {
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -1, 1, -1 - (i - 1) * 4),
            Size = UDim2.fromOffset(3 + (3 - i) * 4, 2),
            BorderSizePixel = 0,
            Rotation = 0,
            ZIndex = 21,
            Parent = resizeGrip,
        })
        Theme.Paint(dash, "BackgroundColor3", "Muted")
        Theme.Fade(dash, "BackgroundTransparency", 0.3, "Stroke")
    end

    local function ApplyWindowSize(width, height, animate)
        baseWidth = math.clamp(width, minWidth, maxWidth)
        baseHeight = math.clamp(height, minHeight, maxHeight)
        Tween(mainWindow, {
            Size = UDim2.fromOffset(baseWidth, baseHeight),
        }, animate and 0.22 or 0, "Snap")
    end

    do
        local startSize, startPos
        InputMgr.Bind(resizeGrip, {
            OnBegin = function()
                startSize = Vector2.new(baseWidth, baseHeight)
                startPos = mainWindow.Position
                CloseAllOverlays()
            end,
            OnMove = function(pos, session)
                local delta = pos - session.StartPos
                local scale = math.max(0.2, windowScale.Scale)
                local newWidth = math.clamp(startSize.X + delta.X / scale, minWidth, maxWidth)
                local newHeight = math.clamp(startSize.Y + delta.Y / scale, minHeight, maxHeight)
                baseWidth, baseHeight = newWidth, newHeight
                mainWindow.Size = UDim2.fromOffset(newWidth, newHeight)

                mainWindow.Position = UDim2.fromOffset(
                    startPos.X.Offset + (newWidth - startSize.X) * scale / 2,
                    startPos.Y.Offset + (newHeight - startSize.Y) * scale / 2
                )
            end,
        })
        Anim.Hover(resizeGrip, function()
            for _, dash in ipairs(resizeGrip:GetChildren()) do
                if dash:IsA("Frame") then
                    Tween(dash, { BackgroundColor3 = Theme.Colors.Accent }, 0.14, "Fast")
                end
            end
        end, function()
            for _, dash in ipairs(resizeGrip:GetChildren()) do
                if dash:IsA("Frame") then
                    Tween(dash, { BackgroundColor3 = Theme.Colors.Muted }, 0.18, "Fast")
                end
            end
        end)
    end

    do
        local startPos
        InputMgr.Bind(titleBar, {
            OnBegin = function()
                startPos = mainWindow.Position
                CloseAllOverlays()
            end,
            OnMove = function(pos, session)
                local delta = pos - session.StartPos
                local vp = ViewportSize()
                local halfW = mainWindow.AbsoluteSize.X / 2
                local halfH = mainWindow.AbsoluteSize.Y / 2
                local x = math.clamp(startPos.X.Offset + delta.X, halfW * 0.2, vp.X - halfW * 0.2)
                local y = math.clamp(startPos.Y.Offset + delta.Y, halfH * 0.3, vp.Y - 20)
                mainWindow.Position = UDim2.fromOffset(x, y)
            end,
        })
    end

    local tabs = {}
    local tabOrder = {}
    local tabButtons = {}
    local selectedTab = nil

    local function SelectTab(name, animate)
        local tab = tabs[name]
        if not tab then return end
        if selectedTab == name then return end
        selectedTab = name
        tabTitle.Text = name

        for tabName, entry in pairs(tabs) do
            local active = tabName == name
            entry.Instance.Visible = active
            if active and animate ~= false then
                entry.Instance.Position = UDim2.fromOffset(0, 10)
                Tween(entry.Instance, { Position = UDim2.fromOffset(0, 0) }, 0.24, "Snap")
            end
        end

        for tabName, button in pairs(tabButtons) do
            local active = tabName == name
            Tween(button.Label, {
                TextColor3 = active and Theme.Colors.Accent or Theme.Colors.Text,
            }, 0.16, "Fast")
            if button.Icon then
                Tween(button.Icon, {
                    TextColor3 = active and Theme.Colors.Accent or Theme.Colors.Muted,
                }, 0.16, "Fast")
            end
        end
        CloseAllOverlays()
    end
    ctx.SelectTab = SelectTab

    function Window:AddTab(name, options)
        if typeof(name) == "table" then
            options = name
            name = options.Name
        end
        options = options or {}
        name = tostring(name or ("Tab " .. (#tabOrder + 1)))
        if tabs[name] then return tabs[name] end

        local tab = CreateTab(ctx, name, options)
        tabs[name] = tab
        table.insert(tabOrder, name)

        local frame = New("Frame", {
            Name = "TabBtn_" .. name,
            Size = UDim2.new(1, 0, 0, 26),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            LayoutOrder = #tabOrder,
            ZIndex = 5,
            Parent = tabsHolder,
        })
        Theme.Paint(frame, "BackgroundColor3", "Surface2")
        Corner(frame, 6)

        local indicator = New("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0),
            Size = UDim2.fromOffset(3, 0),
            BorderSizePixel = 0,
            ZIndex = 7,
            Parent = frame,
        })
        Theme.Paint(indicator, "BackgroundColor3", "Accent")
        Theme.Fade(indicator, "BackgroundTransparency", 0, "Fill")
        Corner(indicator, 999)

        local iconLabel
        local textOffset = 10
        if options.Icon then
            iconLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(9, 0),
                Size = UDim2.fromOffset(18, 30),
                Font = Enum.Font.GothamBold,
                TextSize = 14,
                Text = tostring(options.Icon),
                ZIndex = 7,
                Parent = frame,
            })
            Theme.Paint(iconLabel, "TextColor3", "Muted")
            Theme.Fade(iconLabel, "TextTransparency", 0, "Text")
            textOffset = 30
        end

        local label = New("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(textOffset, 0),
            Size = UDim2.new(1, -textOffset - 6, 1, 0),
            Font = Enum.Font.GothamMedium,
            TextSize = 15,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Text = name,
            ZIndex = 7,
            Parent = frame,
        })
        Theme.Paint(label, "TextColor3", "Text")
        Theme.Fade(label, "TextTransparency", 0, "Text")

        local button = New("TextButton", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Text = "",
            AutoButtonColor = false,
            ZIndex = 8,
            Parent = frame,
        })

        tabButtons[name] = {
            Frame = frame, Label = label, Indicator = indicator, Icon = iconLabel,
        }

        Anim.Hover(button, function()
            if selectedTab ~= name then
                Tween(label, { TextColor3 = Theme.Colors.Accent:Lerp(Theme.Colors.Text, 0.45) }, 0.14, "Fast")
            end
        end, function()
            if selectedTab ~= name then
                Tween(label, { TextColor3 = Theme.Colors.Text }, 0.18, "Fast")
            end
        end)

        button.MouseButton1Click:Connect(function()
            ctx.PlaySound()
            SelectTab(name)
        end)

        tab.Button = frame
        function tab:Remove()
            frame:Destroy()
            tab.Instance:Destroy()
            tabs[name] = nil
            tabButtons[name] = nil
            for i, n in ipairs(tabOrder) do
                if n == name then table.remove(tabOrder, i) break end
            end
            if selectedTab == name then
                selectedTab = nil
                if tabOrder[1] then SelectTab(tabOrder[1]) end
            end
        end

        if #tabOrder == 1 then
            SelectTab(name, false)
        end
        return tab
    end

    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local query = string.lower(Trim(searchBox.Text))
        for name, button in pairs(tabButtons) do
            local match = query == "" or string.find(string.lower(name), query, 1, true) ~= nil
            button.Frame.Visible = match
        end
    end)

    function Window:GetTab(name) return tabs[name] end
    function Window:SelectTab(name) SelectTab(name) end
    function Window:GetTabs() return tabs end

    local hasCanvasGroup = (windowClass == "CanvasGroup")
    local menuOpen = false
    local openToken = 0
    local ApplyBlur

    local function ApplyMasterTransparency()
        if hasCanvasGroup and menuOpen then
            mainWindow.GroupTransparency = masterAlpha
        end
    end

    local function ApplyOpenState(open)
        openToken = openToken + 1
        local token = openToken

        if open then
            mainWindow.Visible = true
            windowScale.Scale = baseScale * 0.93
            if hasCanvasGroup then mainWindow.GroupTransparency = 1 end
            Tween(windowScale, { Scale = baseScale }, 0.3, "Pop")
            if hasCanvasGroup then
                Tween(mainWindow, { GroupTransparency = masterAlpha }, 0.22, "Fast")
            end
        else
            CloseAllOverlays()
            if Window.HideTooltip then Window.HideTooltip() end
            Tween(windowScale, { Scale = baseScale * 0.93 }, 0.18, "In")
            if hasCanvasGroup then
                Tween(mainWindow, { GroupTransparency = 1 }, 0.16, "Fast")
            end
            task.delay(0.2, function()
                if token == openToken and not menuOpen then
                    mainWindow.Visible = false
                end
            end)
        end
        if ApplyBlur then ApplyBlur() end
    end

    function Window:Toggle(open)
        if open == nil then open = not menuOpen end
        if open == menuOpen and mainWindow.Visible == open then return end
        menuOpen = open
        ApplyOpenState(open)
        SafeCall(config.OnToggle, open)
    end
    function Window:Open() Window:Toggle(true) end
    function Window:Close() Window:Toggle(false) end
    function Window:IsOpen() return menuOpen end

    local blurEffect
    local blurEnabled = config.Blur == true
    ApplyBlur = function()
        if not Lighting then return end
        if blurEnabled and menuOpen then
            if not blurEffect then
                pcall(function()
                    blurEffect = Instance.new("BlurEffect")
                    blurEffect.Size = 0
                    blurEffect.Name = "LurkBlur"
                    blurEffect.Parent = Lighting
                end)
            end
            if blurEffect then Tween(blurEffect, { Size = config.BlurSize or 14 }, 0.3, "Fast") end
        elseif blurEffect then
            local tween = Tween(blurEffect, { Size = 0 }, 0.25, "Fast")
            if tween then
                tween.Completed:Connect(function()
                    if blurEffect and (not blurEnabled or not menuOpen) then
                        blurEffect:Destroy()
                        blurEffect = nil
                    end
                end)
            end
        end
    end

    local toggleConn = UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if ActiveKeybindCapture then return end
        if not toggleKey then return end
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == toggleKey then
            Window:Toggle()
        end
    end)

    function Window:SetToggleKey(key) toggleKey = key end
    function Window:GetToggleKey() return toggleKey end

    local tooltip = New("Frame", {
        Name = "Tooltip",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(0, 24),
        AutomaticSize = Enum.AutomaticSize.X,
        Visible = false,
        ZIndex = 900,
        Parent = ScreenGui,
    })
    Theme.Paint(tooltip, "BackgroundColor3", "Surface3")
    local tooltipFade = Theme.Fade(tooltip, "BackgroundTransparency", 0.05, "Fill")
    Corner(tooltip, 5)
    Padding(tooltip, 0, 0, 8, 8)
    local tooltipStroke = New("UIStroke", { Thickness = 1, Parent = tooltip })
    Theme.Paint(tooltipStroke, "Color", "Accent")
    Theme.Fade(tooltipStroke, "Transparency", 0.4, "Stroke")

    local tooltipText = New("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        Text = "",
        ZIndex = 901,
        Parent = tooltip,
    })
    Theme.Paint(tooltipText, "TextColor3", "Text")
    Theme.Fade(tooltipText, "TextTransparency", 0, "Text")

    local tooltipToken = 0
    function Window.HideTooltip()
        tooltipToken = tooltipToken + 1
        tooltip.Visible = false
    end
    function ctx.AttachTooltip(gui, text)
        Anim.Hover(gui, function()
            tooltipToken = tooltipToken + 1
            local token = tooltipToken
            task.delay(0.4, function()
                if token ~= tooltipToken then return end
                tooltipText.Text = tostring(text)
                local mouse = UserInputService:GetMouseLocation()
                tooltip.Position = UDim2.fromOffset(mouse.X + 14, mouse.Y + 16)
                tooltip.Visible = true
                tooltip.BackgroundTransparency = 1
                Tween(tooltip, { BackgroundTransparency = tooltipFade.Target() }, 0.15, "Fast")
            end)
        end, function()
            tooltipToken = tooltipToken + 1
            tooltip.Visible = false
        end)
    end

    local notifyHolder = New("Frame", {
        Name = "NotifyHolder",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -14, 1, -14),
        Size = UDim2.fromOffset(280, 600),
        ZIndex = 800,
        Parent = ScreenGui,
    })
    New("UIListLayout", {
        Padding = UDim.new(0, 8),
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = notifyHolder,
    })

    local NOTIFY_TYPES = {
        Info    = { Color = "Accent", Icon = "i" },
        Success = { Color = "Good",   Icon = "\u{2713}" },
        Warning = { Color = "Warn",   Icon = "!" },
        Error   = { Color = "Bad",    Icon = "\u{00D7}" },
    }

    local notifyOrder = 0

    function Window:Notify(cfg)
        cfg = cfg or {}
        if typeof(cfg) == "string" then cfg = { Content = cfg } end
        local kind = NOTIFY_TYPES[cfg.Type or "Info"] or NOTIFY_TYPES.Info
        local duration = cfg.Duration or 4
        notifyOrder = notifyOrder + 1

        local cardClass = hasCanvasGroup and "CanvasGroup" or "Frame"
        local card = New(cardClass, {
            Name = "Notification",
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BorderSizePixel = 0,
            LayoutOrder = notifyOrder,
            Position = UDim2.fromOffset(300, 0),
            ZIndex = 801,
            Parent = notifyHolder,
        })
        Theme.Paint(card, "BackgroundColor3", "Surface")
        Theme.Fade(card, "BackgroundTransparency", 0.02, "Fill")
        Corner(card, 8)
        Padding(card, 10, 10, 12, 10)
        local cardStroke = New("UIStroke", { Thickness = 1, Parent = card })
        cardStroke.Color = Theme.Colors[kind.Color]
        Theme.Fade(cardStroke, "Transparency", 0.3, "Stroke")
        if hasCanvasGroup then card.GroupTransparency = 1 end

        local accentBar = New("Frame", {
            AnchorPoint = Vector2.new(0, 0),
            Position = UDim2.fromOffset(-8, -6),
            Size = UDim2.new(0, 3, 1, 12),
            BorderSizePixel = 0,
            ZIndex = 803,
            Parent = card,
        })
        accentBar.BackgroundColor3 = Theme.Colors[kind.Color]
        Theme.Fade(accentBar, "BackgroundTransparency", 0, "Fill")
        Corner(accentBar, 999)

        New("UIListLayout", {
            Padding = UDim.new(0, 3),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = card,
        })

        local titleLabel = New("TextLabel", {
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(1, 0, 0, 0),
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            Text = kind.Icon .. "  " .. tostring(cfg.Title or "Notification"),
            LayoutOrder = 1,
            ZIndex = 802,
            Parent = card,
        })
        titleLabel.TextColor3 = Theme.Colors[kind.Color]
        Theme.Fade(titleLabel, "TextTransparency", 0, "Text")

        if cfg.Content and cfg.Content ~= "" then
            local bodyLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.Y,
                Size = UDim2.new(1, 0, 0, 0),
                Font = Enum.Font.Gotham,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
                Text = tostring(cfg.Content),
                LayoutOrder = 2,
                ZIndex = 802,
                Parent = card,
            })
            Theme.Paint(bodyLabel, "TextColor3", "SubText")
            Theme.Fade(bodyLabel, "TextTransparency", 0, "Text")
        end

        local timerTrack = New("Frame", {
            Size = UDim2.new(1, 0, 0, 2),
            BorderSizePixel = 0,
            LayoutOrder = 3,
            ZIndex = 802,
            Parent = card,
        })
        Theme.Paint(timerTrack, "BackgroundColor3", "Surface3")
        Theme.Fade(timerTrack, "BackgroundTransparency", 0.4, "Fill")
        Corner(timerTrack, 999)
        local timerFill = New("Frame", {
            Size = UDim2.fromScale(1, 1),
            BorderSizePixel = 0,
            ZIndex = 803,
            Parent = timerTrack,
        })
        timerFill.BackgroundColor3 = Theme.Colors[kind.Color]
        Theme.Fade(timerFill, "BackgroundTransparency", 0, "Fill")
        Corner(timerFill, 999)

        local closeBtn = New("TextButton", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Text = "",
            AutoButtonColor = false,
            ZIndex = 806,
            Parent = card,
        })

        Tween(card, { Position = UDim2.fromOffset(0, 0) }, 0.32, "Snap")
        if hasCanvasGroup then Tween(card, { GroupTransparency = 0 }, 0.25, "Fast") end
        Tween(timerFill, { Size = UDim2.fromScale(0, 1) }, duration, "Linear")

        local dismissed = false
        local function Dismiss()
            if dismissed then return end
            dismissed = true
            local tween = Tween(card, { Position = UDim2.fromOffset(320, 0) }, 0.22, "In")
            if hasCanvasGroup then Tween(card, { GroupTransparency = 1 }, 0.2, "Fast") end
            if tween then
                tween.Completed:Connect(function() card:Destroy() end)
            else
                card:Destroy()
            end
        end

        closeBtn.MouseButton1Click:Connect(function()
            SafeCall(cfg.Callback)
            Dismiss()
        end)
        task.delay(duration, Dismiss)

        return { Dismiss = Dismiss, Instance = card }
    end

    function Window:Dialog(cfg)
        cfg = cfg or {}
        local backdrop = New("TextButton", {
            Name = "DialogBackdrop",
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            ZIndex = 950,
            Parent = ScreenGui,
        })

        local cardClass = hasCanvasGroup and "CanvasGroup" or "Frame"
        local card = New(cardClass, {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(cfg.Width or 320, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BorderSizePixel = 0,
            ZIndex = 951,
            Parent = backdrop,
        })
        Theme.Paint(card, "BackgroundColor3", "Surface")
        Theme.Fade(card, "BackgroundTransparency", 0, "Fill")
        Corner(card, 10)
        Padding(card, 14, 14, 16, 16)
        local cardStroke = New("UIStroke", { Thickness = 1.4, Parent = card })
        Theme.Paint(cardStroke, "Color", "Accent")
        Theme.Fade(cardStroke, "Transparency", 0.35, "Stroke")
        ListLayout(card, 8)

        local scaleObj = New("UIScale", { Scale = 0.9, Parent = card })

        New("TextLabel", {
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(1, 0, 0, 0),
            Font = Enum.Font.GothamBold,
            TextSize = 16,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            TextColor3 = Theme.Colors.Text,
            Text = tostring(cfg.Title or "Confirm"),
            LayoutOrder = 1,
            ZIndex = 952,
            Parent = card,
        })

        if cfg.Text or cfg.Content then
            New("TextLabel", {
                BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.Y,
                Size = UDim2.new(1, 0, 0, 0),
                Font = Enum.Font.Gotham,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
                TextColor3 = Theme.Colors.SubText,
                Text = tostring(cfg.Text or cfg.Content),
                LayoutOrder = 2,
                ZIndex = 952,
                Parent = card,
            })
        end

        local inputBox
        if cfg.Input then
            local frame = New("Frame", {
                Size = UDim2.new(1, 0, 0, 30),
                BorderSizePixel = 0,
                LayoutOrder = 3,
                ZIndex = 952,
                Parent = card,
            })
            Theme.Paint(frame, "BackgroundColor3", "Surface2")
            Corner(frame, 6)
            Padding(frame, 0, 0, 8, 8)
            inputBox = New("TextBox", {
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                Font = Enum.Font.Gotham,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = Theme.Colors.Text,
                PlaceholderColor3 = Theme.Colors.Muted,
                PlaceholderText = cfg.Placeholder or "",
                Text = cfg.Default or "",
                ClearTextOnFocus = false,
                ZIndex = 953,
                Parent = frame,
            })
        end

        local buttonRow = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 32),
            LayoutOrder = 10,
            ZIndex = 952,
            Parent = card,
        })
        New("UIListLayout", {
            Padding = UDim.new(0, 8),
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = buttonRow,
        })

        local closed = false
        local function CloseDialog()
            if closed then return end
            closed = true
            Tween(scaleObj, { Scale = 0.92 }, 0.15, "In")
            Tween(backdrop, { BackgroundTransparency = 1 }, 0.18, "Fast")
            if hasCanvasGroup then Tween(card, { GroupTransparency = 1 }, 0.15, "Fast") end
            task.delay(0.2, function() backdrop:Destroy() end)
        end

        local buttons = cfg.Buttons or {
            { Text = "Cancel", Style = "Ghost" },
            { Text = "OK", Style = "Primary", Callback = cfg.Callback },
        }

        for index, spec in ipairs(buttons) do
            local btn = New("TextButton", {
                Size = UDim2.fromOffset(spec.Width or 92, 32),
                BorderSizePixel = 0,
                AutoButtonColor = false,
                ClipsDescendants = true,
                Font = Enum.Font.GothamBold,
                TextSize = 13,
                Text = tostring(spec.Text or "OK"),
                LayoutOrder = index,
                ZIndex = 953,
                Parent = buttonRow,
            })
            local isPrimary = (spec.Style or "Primary") == "Primary"
            btn.BackgroundColor3 = isPrimary and Theme.Colors.Accent or Theme.Colors.Surface3
            btn.TextColor3 = isPrimary and Color3.new(1, 1, 1) or Theme.Colors.SubText
            Corner(btn, 6)
            btn.MouseButton1Click:Connect(function()
                ctx.PlaySound()
                Ripple(btn, nil, nil, Color3.new(1, 1, 1))
                local value = inputBox and inputBox.Text or nil
                CloseDialog()
                SafeCall(spec.Callback, value)
            end)
            Anim.Hover(btn, function()
                Tween(btn, { BackgroundColor3 = btn.BackgroundColor3:Lerp(Color3.new(1, 1, 1), 0.15) }, 0.14, "Fast")
            end, function()
                Tween(btn, {
                    BackgroundColor3 = isPrimary and Theme.Colors.Accent or Theme.Colors.Surface3,
                }, 0.18, "Fast")
            end)
        end

        if cfg.CloseOnBackdrop ~= false then
            backdrop.MouseButton1Click:Connect(CloseDialog)
        end

        if hasCanvasGroup then card.GroupTransparency = 1 end
        Tween(backdrop, { BackgroundTransparency = 0.45 }, 0.2, "Fast")
        Tween(scaleObj, { Scale = 1 }, 0.28, "Pop")
        if hasCanvasGroup then Tween(card, { GroupTransparency = 0 }, 0.22, "Fast") end

        return { Close = CloseDialog, Instance = card }
    end

    function Window:Confirm(title, text, onYes, onNo)
        return Window:Dialog({
            Title = title,
            Text = text,
            Buttons = {
                { Text = "No", Style = "Ghost", Callback = onNo },
                { Text = "Yes", Style = "Primary", Callback = onYes },
            },
        })
    end

    function Window:Prompt(title, placeholder, callback)
        return Window:Dialog({
            Title = title,
            Input = true,
            Placeholder = placeholder,
            Buttons = {
                { Text = "Cancel", Style = "Ghost" },
                { Text = "OK", Style = "Primary", Callback = callback },
            },
        })
    end

    function Window:SetAccentColor(color)
        Theme.SetAccent(color)
        return self
    end
    Window.SetAccent = Window.SetAccentColor

    function Window:SetPalette(name)
        Theme.SetPalette(name)
        return self
    end
    Window.SetTheme = Window.SetPalette

    function Window:SetMasterTransparency(value)
        masterAlpha = Clamp01(value)
        ApplyMasterTransparency()
        return self
    end
    function Window:GetMasterTransparency() return masterAlpha end

    function Window:SetTransparency(value)
        Theme.SetAlpha("Fill", value)
        return self
    end
    function Window:GetTransparency() return Theme.GetAlpha("Fill") end

    function Window:SetTextTransparency(value)
        Theme.SetAlpha("Text", value)
        return self
    end
    function Window:SetStrokeTransparency(value)
        Theme.SetAlpha("Stroke", value)
        return self
    end
    function Window:SetFloatTransparency(value)
        Theme.SetAlpha("Float", value)
        return self
    end
    function Window:GetFloatTransparency() return Theme.GetAlpha("Float") end

    function Window:SetSize(width, height, animate)
        if typeof(width) == "UDim2" then
            animate = height
            height = width.Y.Offset
            width = width.X.Offset
        end
        ApplyWindowSize(width or baseWidth, height or baseHeight, animate ~= false)
        return self
    end
    function Window:GetSize() return baseWidth, baseHeight end

    function Window:SetScale(scale, animate)
        baseScale = math.clamp(scale or 1, 0.4, 2.5)
        if menuOpen then
            Tween(windowScale, { Scale = baseScale }, animate == false and 0 or 0.2, "Snap")
        else
            windowScale.Scale = baseScale * 0.93
        end
        return self
    end
    function Window:GetScale() return baseScale end

    function Window:Center()
        local vp = ViewportSize()
        Tween(mainWindow, { Position = UDim2.fromOffset(vp.X / 2, vp.Y / 2) }, 0.28, "Snap")
        return self
    end

    function Window:SetPosition(position)
        mainWindow.Position = position
        return self
    end

    function Window:SetTitle(text)
        titleText.Text = tostring(text)
        return self
    end
    function Window:SetSubtitle(text)
        subtitleText.Text = tostring(text)
        return self
    end

    function Window:SetAnimationSpeed(multiplier)
        Anim.Speed = math.clamp(1 / math.max(0.05, multiplier or 1), 0.05, 5)
        return self
    end

    function Window:SetSound(enabled, id)
        soundEnabled = enabled == true
        if id then
            soundId = id
            if not clickSound then
                clickSound = New("Sound", { Volume = 0.35, Parent = ScreenGui })
            end
            clickSound.SoundId = id
        end
        return self
    end

    function Window:SetBlur(enabled)
        blurEnabled = enabled == true
        ApplyBlur()
        return self
    end

    local floatingGuis = {}
    local floatingButtons = {}

    local function CreateFloatingButton(cfg, forceToggle)
        cfg = cfg or {}
        local isToggle = forceToggle == true or cfg.Toggle == true
        local minSize = cfg.MinSize or 32
        local maxSize = cfg.MaxSize or 220
        local size = math.clamp(cfg.Size or 62, minSize, maxSize)
        local threshold = cfg.DragThreshold or 6
        local state = cfg.Default == true

        local gui = New("ScreenGui", {
            Name = "LurkFloating",
            ResetOnSpawn = false,
            IgnoreGuiInset = true,
            DisplayOrder = 1000000,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        })
        ProtectGui(gui)
        gui.Parent = GuiParent
        table.insert(floatingGuis, gui)

        local defaultPos = cfg.Position or UDim2.new(1, -(size + 18), 0.5, -size / 2)
        local button = New("TextButton", {
            Name = "FloatingButton",
            Position = defaultPos,
            Size = UDim2.fromOffset(size, size),
            BorderSizePixel = 0,
            AutoButtonColor = false,
            ClipsDescendants = true,
            Font = Enum.Font.GothamBold,
            TextSize = math.floor(size * 0.36),
            Text = tostring(cfg.Text or cfg.Name or "M"),
            ZIndex = 50,
            Parent = gui,
        })
        Theme.Paint(button, "BackgroundColor3", "Surface")
        local bgFade = Theme.Fade(button, "BackgroundTransparency", cfg.Transparency or 0, "Float")
        Theme.Fade(button, "TextTransparency", 0, "Float")
        Corner(button, cfg.Circle == false and (cfg.Radius or 10) or 999)

        local stroke = New("UIStroke", { Thickness = 1.5, Parent = button })
        Theme.Paint(stroke, "Color", "Accent")
        local strokeFade = Theme.Fade(stroke, "Transparency", 0.3, "Float")
        Theme.Paint(button, "TextColor3", "Accent")

        local handle = { Instance = button, Gui = gui, Type = "FloatingButton" }

        local function ApplyVisual(animate)
            local dur = animate and 0.18 or 0
            if isToggle and state then
                Tween(button, { BackgroundColor3 = Theme.Colors.Accent, TextColor3 = Color3.new(1, 1, 1) }, dur, "Fast")
                stroke.Color = Theme.Colors.Accent
                strokeFade.SetBase(0, animate)
            else
                Tween(button, { BackgroundColor3 = Theme.Colors.Surface, TextColor3 = Theme.Colors.Accent }, dur, "Fast")
                stroke.Color = Theme.Colors.Accent
                strokeFade.SetBase(0.3, animate)
            end
        end

        local function ClampToScreen()
            local vp = ViewportSize()
            local absPos = button.AbsolutePosition
            local absSize = button.AbsoluteSize
            local x = math.clamp(absPos.X, 2, math.max(2, vp.X - absSize.X - 2))
            local y = math.clamp(absPos.Y, 2, math.max(2, vp.Y - absSize.Y - 2))
            if x ~= absPos.X or y ~= absPos.Y then
                local p = button.Position
                button.Position = UDim2.new(
                    p.X.Scale, p.X.Offset + (x - absPos.X),
                    p.Y.Scale, p.Y.Offset + (y - absPos.Y)
                )
            end
        end

        local function Activate()
            if isToggle then
                state = not state
                ApplyVisual(true)
                SafeCall(cfg.Callback, state)
            else
                SafeCall(cfg.Callback)
            end
            Ripple(button, nil, nil, Theme.Colors.Accent)
            ctx.PlaySound()
        end

        local startPos
        InputMgr.Bind(button, {
            Threshold = threshold,
            OnBegin = function()
                startPos = button.Position
                Tween(button, { Size = UDim2.fromOffset(size * 0.92, size * 0.92) }, 0.1, "Fast")
            end,
            OnMove = function(pos, session)
                if not session.Moved then return end
                local delta = pos - session.StartPos
                button.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
                ClampToScreen()
            end,
            OnEnd = function(pos, session)
                Tween(button, { Size = UDim2.fromOffset(size, size) }, 0.16, "Pop")
                if not session.Moved then
                    Activate()
                elseif cfg.SnapToEdge then
                    local vp = ViewportSize()
                    local absPos = button.AbsolutePosition
                    local targetX = (absPos.X + size / 2 < vp.X / 2) and 8 or (vp.X - size - 8)
                    Tween(button, {
                        Position = UDim2.fromOffset(targetX, absPos.Y),
                    }, 0.25, "Snap")
                end
            end,
        })

        Anim.Hover(button, function()
            Tween(button, { Size = UDim2.fromOffset(size * 1.06, size * 1.06) }, 0.14, "Pop")
        end, function()
            Tween(button, { Size = UDim2.fromOffset(size, size) }, 0.18, "Fast")
        end)

        function handle:SetSize(px)
            size = math.clamp(px or size, minSize, maxSize)
            button.Size = UDim2.fromOffset(size, size)
            button.TextSize = math.floor(size * 0.36)
            task.defer(ClampToScreen)
            return size
        end
        function handle:GetSize() return size end
        function handle:SetText(text) button.Text = tostring(text or "") end
        function handle:SetTransparency(value)
            bgFade.SetBase(Clamp01(value), true)
            return self
        end
        function handle:SetActive(value, silent)
            if not isToggle then return end
            local newState = value == true
            local changed = newState ~= state
            state = newState
            ApplyVisual(true)
            if changed and not silent then SafeCall(cfg.Callback, state) end
        end
        function handle:Toggle() handle:SetActive(not state) end
        function handle:GetState() return state end
        function handle:SetVisible(value) gui.Enabled = value ~= false end
        function handle:SetPosition(position) button.Position = position end
        function handle:Destroy()
            gui:Destroy()
            for i, entry in ipairs(floatingButtons) do
                if entry == handle then table.remove(floatingButtons, i) break end
            end
        end
        function handle:AddSizeSlider(tab, sliderCfg)
            sliderCfg = sliderCfg or {}
            return tab:AddSlider({
                Name = sliderCfg.Name or "Button size",
                Min = sliderCfg.Min or minSize,
                Max = sliderCfg.Max or maxSize,
                Default = size,
                Step = sliderCfg.Step or 2,
                Callback = function(value)
                    handle:SetSize(value)
                    SafeCall(sliderCfg.Callback, value)
                end,
            })
        end

        ApplyVisual(false)
        Theme.Changed:Connect(function() ApplyVisual(false) end)
        table.insert(floatingButtons, handle)
        return handle
    end

    function Window:AddFloatingButton(cfg) return CreateFloatingButton(cfg, false) end
    function Window:AddFloatingToggle(cfg) return CreateFloatingButton(cfg, true) end
    function Window:GetFloatingButtons() return floatingButtons end

    local openButton = CreateFloatingButton({
        Text = logoText,
        Size = config.OpenButtonSize or 62,
        Position = config.OpenButtonPosition or UDim2.new(1, -72, 0.5, -31),
        Transparency = config.OpenButtonTransparency or 0,
        SnapToEdge = config.SnapToEdge == true,
        Callback = function() Window:Toggle() end,
    })
    Window.OpenButton = openButton

    function Window:SetOpenButtonVisible(value) openButton:SetVisible(value) end
    function Window:SetOpenButtonSize(px) openButton:SetSize(px) end

    local watermark, watermarkConn
    function Window:Watermark(cfg)
        cfg = cfg or {}
        if watermark then watermark:Destroy() end

        watermark = New("Frame", {
            Name = "Watermark",
            Position = cfg.Position or UDim2.fromOffset(14, 14),
            Size = UDim2.fromOffset(0, 26),
            AutomaticSize = Enum.AutomaticSize.X,
            BorderSizePixel = 0,
            ZIndex = 700,
            Parent = ScreenGui,
        })
        Theme.Paint(watermark, "BackgroundColor3", "Surface")
        Theme.Fade(watermark, "BackgroundTransparency", 0.15, "Fill")
        Corner(watermark, 6)
        Padding(watermark, 0, 0, 10, 10)
        local wmStroke = New("UIStroke", { Thickness = 1, Parent = watermark })
        Theme.Paint(wmStroke, "Color", "Accent")
        Theme.Fade(wmStroke, "Transparency", 0.35, "Stroke")

        local label = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            Text = "",
            ZIndex = 701,
            Parent = watermark,
        })
        Theme.Paint(label, "TextColor3", "Text")
        Theme.Fade(label, "TextTransparency", 0, "Text")

        do
            local startPos
            InputMgr.Bind(watermark, {
                OnBegin = function() startPos = watermark.Position end,
                OnMove = function(pos, session)
                    local delta = pos - session.StartPos
                    watermark.Position = UDim2.fromOffset(
                        startPos.X.Offset + delta.X,
                        startPos.Y.Offset + delta.Y
                    )
                end,
            })
        end

        local frames, accum, fps = 0, 0, 0
        if watermarkConn then watermarkConn:Disconnect() end
        watermarkConn = RunService.RenderStepped:Connect(function(dt)
            frames = frames + 1
            accum = accum + dt
            if accum >= 0.5 then
                fps = math.floor(frames / accum + 0.5)
                frames, accum = 0, 0
                local ping = 0
                if StatsService then
                    pcall(function()
                        ping = math.floor(StatsService.Network.ServerStatsItem["Data Ping"]:GetValue())
                    end)
                end
                local parts = {}
                table.insert(parts, cfg.Title or windowName)
                if cfg.ShowFPS ~= false then table.insert(parts, fps .. " fps") end
                if cfg.ShowPing ~= false then table.insert(parts, ping .. " ms") end
                if cfg.ShowPlayers then table.insert(parts, #Players:GetPlayers() .. "/" .. Players.MaxPlayers) end
                if cfg.ShowTime ~= false then table.insert(parts, os.date("%H:%M:%S")) end
                if cfg.Extra then table.insert(parts, tostring(cfg.Extra)) end
                label.Text = table.concat(parts, "  |  ")
            end
        end)

        local api = {
            Instance = watermark,
            SetVisible = function(_, value)
                watermark.Visible = value ~= false
            end,
            SetText = function(_, value) cfg.Title = value end,
            Destroy = function()
                if watermarkConn then watermarkConn:Disconnect() watermarkConn = nil end
                watermark:Destroy()
                watermark = nil
            end,
        }
        Window.WatermarkApi = api
        return api
    end

    function Window:SetWatermarkVisible(value)
        if value and not watermark then
            Window:Watermark(config.WatermarkConfig or {})
        elseif watermark then
            watermark.Visible = value ~= false
        end
    end

    local configFolder = config.ConfigFolder or ("LurkUI/" .. windowName)

    local function EnsureFolder()
        if not FS.Enabled then return false end
        local ok = pcall(function()
            if not FS.IsDir("LurkUI") then FS.MakeDir("LurkUI") end
            if not FS.IsDir(configFolder) then FS.MakeDir(configFolder) end
        end)
        return ok
    end

    local function Serialize(value)
        local kind = typeof(value)
        if kind == "Color3" then
            return { __t = "Color3", r = value.R, g = value.G, b = value.B }
        elseif kind == "EnumItem" then
            return { __t = "Enum", name = value.Name, enum = tostring(value.EnumType) }
        elseif kind == "table" then
            local out = {}
            for k, v in pairs(value) do out[k] = Serialize(v) end
            return out
        elseif kind == "number" or kind == "string" or kind == "boolean" then
            return value
        end
        return nil
    end

    local function Deserialize(value)
        if typeof(value) == "table" then
            if value.__t == "Color3" then
                return Color3.new(value.r or 0, value.g or 0, value.b or 0)
            elseif value.__t == "Enum" then
                local ok, item = pcall(function()
                    if string.find(tostring(value.enum), "KeyCode") then
                        return Enum.KeyCode[value.name]
                    end
                    return Enum.UserInputType[value.name]
                end)
                if ok then return item end
                return nil
            end
            local out = {}
            for k, v in pairs(value) do out[k] = Deserialize(v) end
            return out
        end
        return value
    end

    local function CollectState()
        local data = { Flags = {}, UI = {} }
        for flag, element in pairs(Window.Elements) do
            if element.Get then
                local ok, value = pcall(element.Get)
                if ok then data.Flags[flag] = Serialize(value) end
            end
        end
        data.UI = {
            Accent = Serialize(Theme.Colors.Accent),
            Palette = Theme.PaletteName,
            Master = masterAlpha,
            Fill = Theme.GetAlpha("Fill"),
            Text = Theme.GetAlpha("Text"),
            Stroke = Theme.GetAlpha("Stroke"),
            Float = Theme.GetAlpha("Float"),
            Width = baseWidth,
            Height = baseHeight,
            Scale = baseScale,
            Blur = blurEnabled,
            Sound = soundEnabled,
        }
        return data
    end

    local function ApplyState(data)
        if not data then return end
        if data.UI then
            local ui = data.UI
            if ui.Palette then Theme.SetPalette(ui.Palette) end
            if ui.Accent then Theme.SetAccent(Deserialize(ui.Accent)) end
            if ui.Fill then Theme.SetAlpha("Fill", ui.Fill) end
            if ui.Text then Theme.SetAlpha("Text", ui.Text) end
            if ui.Stroke then Theme.SetAlpha("Stroke", ui.Stroke) end
            if ui.Float then Theme.SetAlpha("Float", ui.Float) end
            if ui.Master then Window:SetMasterTransparency(ui.Master) end
            if ui.Width and ui.Height then Window:SetSize(ui.Width, ui.Height, false) end
            if ui.Scale then Window:SetScale(ui.Scale, false) end
            if ui.Blur ~= nil then Window:SetBlur(ui.Blur) end
            if ui.Sound ~= nil then soundEnabled = ui.Sound == true end
        end
        for flag, value in pairs(data.Flags or {}) do
            local element = Window.Elements[flag]
            if element and element.Set then
                pcall(function() element.Set(Deserialize(value)) end)
            end
        end
    end

    function Window:SaveConfig(name)
        name = Trim(name or "default")
        if name == "" then return false, "Empty name" end
        if not FS.Enabled then return false, "Executor does not support writing files" end
        if not EnsureFolder() then return false, "Could not create folder" end
        local ok, err = pcall(function()
            FS.Write(configFolder .. "/" .. name .. ".json", HttpService:JSONEncode(CollectState()))
        end)
        return ok, err
    end

    function Window:LoadConfig(name)
        name = Trim(name or "default")
        if not FS.Enabled then return false, "Executor does not support reading files" end
        local path = configFolder .. "/" .. name .. ".json"
        local ok, result = pcall(function()
            if not FS.IsFile(path) then error("Config not found") end
            return HttpService:JSONDecode(FS.Read(path))
        end)
        if not ok then return false, result end
        ApplyState(result)
        return true
    end

    function Window:DeleteConfig(name)
        if not FS.Enabled then return false end
        local ok = pcall(function()
            FS.Delete(configFolder .. "/" .. Trim(name) .. ".json")
        end)
        return ok
    end

    function Window:ListConfigs()
        local list = {}
        if not FS.Enabled then return list end
        pcall(function()
            for _, path in ipairs(FS.ListDir(configFolder)) do
                local fileName = tostring(path):match("([^/\\]+)%.json$")
                if fileName then table.insert(list, fileName) end
            end
        end)
        table.sort(list)
        return list
    end

    function Window:GetState() return CollectState() end
    function Window:SetState(data) ApplyState(data) end

    function Window:AddSettingsTab(name, options)
        local tab = Window:AddTab(name or "Settings", options or { Icon = "\u{2699}" })

        local look = tab:AddGroup({ Name = "Appearance", Open = true })
        look:AddColorPicker({
            Name = "Accent color",
            Default = Theme.Colors.Accent,
            Tooltip = "Primary color for the whole interface",
            Callback = function(color) Theme.SetAccent(color) end,
        })
        look:AddDropdown({
            Name = "Theme",
            Options = Theme.PaletteList(),
            Default = Theme.PaletteName,
            Callback = function(value) Theme.SetPalette(value) end,
        })

        local alpha = tab:AddGroup({ Name = "Transparency", Open = true })
        alpha:AddSlider({
            Name = "Whole menu",
            Min = 0, Max = 100, Step = 1, Suffix = "%",
            Default = math.floor(masterAlpha * 100),
            Tooltip = "Transparency of the entire window",
            Callback = function(value) Window:SetMasterTransparency(value / 100) end,
        })
        alpha:AddSlider({
            Name = "Background",
            Min = 0, Max = 100, Step = 1, Suffix = "%",
            Default = math.floor(Theme.GetAlpha("Fill") * 100),
            Callback = function(value) Window:SetTransparency(value / 100) end,
        })
        alpha:AddSlider({
            Name = "Text",
            Min = 0, Max = 90, Step = 1, Suffix = "%",
            Default = math.floor(Theme.GetAlpha("Text") * 100),
            Callback = function(value) Window:SetTextTransparency(value / 100) end,
        })
        alpha:AddSlider({
            Name = "Stroke",
            Min = 0, Max = 100, Step = 1, Suffix = "%",
            Default = math.floor(Theme.GetAlpha("Stroke") * 100),
            Callback = function(value) Window:SetStrokeTransparency(value / 100) end,
        })
        alpha:AddSlider({
            Name = "Floating buttons",
            Min = 0, Max = 100, Step = 1, Suffix = "%",
            Default = math.floor(Theme.GetAlpha("Float") * 100),
            Tooltip = "Transparency of the round button and all floating buttons",
            Callback = function(value) Window:SetFloatTransparency(value / 100) end,
        })

        local sizeGroup = tab:AddGroup({ Name = "Size and scale", Open = true })
        sizeGroup:AddSlider({
            Name = "Width",
            Min = minWidth, Max = maxWidth, Step = 5,
            Default = baseWidth,
            Callback = function(value) Window:SetSize(value, baseHeight, false) end,
        })
        sizeGroup:AddSlider({
            Name = "Height",
            Min = minHeight, Max = maxHeight, Step = 5,
            Default = baseHeight,
            Callback = function(value) Window:SetSize(baseWidth, value, false) end,
        })
        sizeGroup:AddSlider({
            Name = "Scale",
            Min = 50, Max = 200, Step = 5, Suffix = "%",
            Default = math.floor(baseScale * 100),
            Tooltip = "Scales the entire menu",
            Callback = function(value) Window:SetScale(value / 100, false) end,
        })
        sizeGroup:AddSlider({
            Name = "Menu button",
            Min = 32, Max = 140, Step = 2,
            Default = openButton:GetSize(),
            Callback = function(value) openButton:SetSize(value) end,
        })
        sizeGroup:AddDoubleButton({
            Left = { Name = "Center", Callback = function() Window:Center() end },
            Right = {
                Name = "Reset",
                Style = "Ghost",
                Callback = function()
                    Window:SetSize(480, 360)
                    Window:SetScale(1)
                    Window:Center()
                end,
            },
        })

        local behavior = tab:AddGroup({ Name = "Behavior", Open = false })
        behavior:AddKeybind({
            Name = "Menu key",
            Default = toggleKey,
            OnBind = function(key) toggleKey = key end,
            Callback = function() end,
        })
        behavior:AddSlider({
            Name = "Animation speed",
            Min = 25, Max = 250, Step = 5, Suffix = "%",
            Default = 100,
            Callback = function(value) Window:SetAnimationSpeed(value / 100) end,
        })
        behavior:AddToggle({
            Name = "Click sound",
            Default = soundEnabled,
            Callback = function(value) soundEnabled = value end,
        })
        behavior:AddToggle({
            Name = "Background blur",
            Default = blurEnabled,
            Tooltip = "Blurs the game while the menu is open",
            Callback = function(value) Window:SetBlur(value) end,
        })
        behavior:AddToggle({
            Name = "Watermark",
            Default = watermark ~= nil,
            Callback = function(value) Window:SetWatermarkVisible(value) end,
        })
        behavior:AddToggle({
            Name = "Open button",
            Default = true,
            Callback = function(value) openButton:SetVisible(value) end,
        })

        local configGroup = tab:AddGroup({ Name = "Configs", Open = false })
        if not FS.Enabled then
            configGroup:AddParagraph({
                Title = "Unavailable",
                Text = "Your executor does not support writefile/readfile, so configs cannot be saved.",
            })
        else
            local nameBox = configGroup:AddInput({
                Name = "Config name",
                Placeholder = "default",
                Button = "Save",
                Callback = function(text)
                    local ok, err = Window:SaveConfig(text ~= "" and text or "default")
                    Window:Notify({
                        Title = ok and "Saved" or "Error",
                        Content = ok and ("Config: " .. (text ~= "" and text or "default")) or tostring(err),
                        Type = ok and "Success" or "Error",
                    })
                end,
            })

            local listDropdown
            listDropdown = configGroup:AddDropdown({
                Name = "Saved configs",
                Options = Window:ListConfigs(),
                Placeholder = "No configs",
                Callback = function() end,
            })

            configGroup:AddDoubleButton({
                Left = {
                    Name = "Load",
                    Callback = function()
                        local selected = listDropdown.Get()
                        if not selected then
                            Window:Notify({ Title = "Select a config", Type = "Warning" })
                            return
                        end
                        local ok, err = Window:LoadConfig(selected)
                        Window:Notify({
                            Title = ok and "Loaded" or "Error",
                            Content = ok and selected or tostring(err),
                            Type = ok and "Success" or "Error",
                        })
                    end,
                },
                Right = {
                    Name = "Delete",
                    Style = "Danger",
                    Callback = function()
                        local selected = listDropdown.Get()
                        if not selected then return end
                        Window:Confirm("Delete config?", selected, function()
                            Window:DeleteConfig(selected)
                            listDropdown.SetOptions(Window:ListConfigs())
                            Window:Notify({ Title = "Deleted", Content = selected, Type = "Info" })
                        end)
                    end,
                },
            })

            configGroup:AddButton({
                Name = "Refresh list",
                Style = "Ghost",
                Callback = function()
                    listDropdown.SetOptions(Window:ListConfigs())
                end,
            })
        end

        return tab
    end

    TitleButton("\u{2013}", -40, "Warn", function()
        Window:Toggle(false)
    end)
    TitleButton("\u{00D7}", -14, "Bad", function()
        if config.CloseDestroys then
            Window:Destroy()
        else
            Window:Toggle(false)
        end
    end)

    function Window:Destroy()
        if toggleConn then toggleConn:Disconnect() end
        if watermarkConn then watermarkConn:Disconnect() end
        if blurEffect then pcall(function() blurEffect:Destroy() end) end
        for _, gui in ipairs(floatingGuis) do
            pcall(function() gui:Destroy() end)
        end
        table.clear(floatingGuis)
        PruneOverlays()
        Theme.Destroy()
        ScreenGui:Destroy()
    end

    Theme.Changed:Connect(function()
        ApplyMasterTransparency()
    end)

    if config.Watermark then
        Window:Watermark(typeof(config.Watermark) == "table" and config.Watermark or {})
    end
    if config.Settings ~= false then

    end
    if masterAlpha > 0 then ApplyMasterTransparency() end

    windowScale.Scale = baseScale * 0.93
    if config.Open == true then
        task.defer(function() Window:Toggle(true) end)
    end

    return Window
end

local Lurk = {}
Lurk.Version = "2.0"
Lurk.Windows = {}

function Lurk:CreateWindow(config)
    local window = CreateWindow(config)
    table.insert(Lurk.Windows, window)
    return window
end

function Lurk.new(config)
    return Lurk:CreateWindow(config)
end

function Lurk:DestroyAll()
    for _, window in ipairs(Lurk.Windows) do
        pcall(function() window:Destroy() end)
    end
    table.clear(Lurk.Windows)
end

function Lurk:GetPalettes()
    local list = {}
    for name in pairs(PALETTES) do table.insert(list, name) end
    table.sort(list)
    return list
end

return Lurk
