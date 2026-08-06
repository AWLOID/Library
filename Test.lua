--!strict
-- EvernessUI: a Roblox/Luau recreation of the visual language found in the
-- supplied Alice/Everness ImGui source. Uses only standard Roblox APIs.

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Library = {}
Library.__index = Library

local DEFAULT_THEME = {
	Accent = Color3.fromRGB(120, 255, 100),
	Window = Color3.fromRGB(12, 12, 12),
	Panel = Color3.fromRGB(17, 17, 17),
	Element = Color3.fromRGB(24, 24, 24),
	ElementHover = Color3.fromRGB(31, 31, 31),
	Border = Color3.fromRGB(42, 42, 42),
	Text = Color3.fromRGB(235, 235, 235),
	TextDim = Color3.fromRGB(155, 155, 155),
	Danger = Color3.fromRGB(255, 199, 56),
}

local function new(className: string, props: {[string]: any}?): Instance
	local object = Instance.new(className)
	if props then
		for key, value in pairs(props) do
			if key ~= "Parent" then (object :: any)[key] = value end
		end
		if props.Parent then object.Parent = props.Parent end
	end
	return object
end

local function corner(parent: Instance, radius: number)
	new("UICorner", {CornerRadius = UDim.new(0, radius), Parent = parent})
end

local function stroke(parent: Instance, color: Color3, transparency: number?)
	new("UIStroke", {Color = color, Transparency = transparency or 0, Thickness = 1, Parent = parent})
end

local function tween(object: Instance, duration: number, props: {[string]: any})
	TweenService:Create(object, TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props):Play()
end

local function textLabel(parent: Instance, text: string, size: number, color: Color3, props: {[string]: any}?): TextLabel
	local base = {
		BackgroundTransparency = 1, Text = text, TextColor3 = color,
		TextSize = size, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(1, 1), Parent = parent,
	}
	if props then for k, v in pairs(props) do base[k] = v end end
	return new("TextLabel", base) :: TextLabel
end

local function bindHover(button: GuiObject, normal: Color3, hovered: Color3)
	button.MouseEnter:Connect(function() tween(button, .16, {BackgroundColor3 = hovered}) end)
	button.MouseLeave:Connect(function() tween(button, .16, {BackgroundColor3 = normal}) end)
end

local function draggable(handle: GuiObject, target: GuiObject)
	local dragging = false
	local dragStart = Vector3.zero
	local startPosition = target.Position
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, dragStart, startPosition = true, input.Position, target.Position
		end
	end)
	UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
	UIS.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			target.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
		end
	end)
end

local function resolveParent(config: {[string]: any}): Instance
	if config.Parent then return config.Parent end
	local player = Players.LocalPlayer
	assert(player, "EvernessUI must be required by a LocalScript")
	return player:WaitForChild("PlayerGui")
end

function Library.new(config: {[string]: any}?)
	config = config or {}
	local self = setmetatable({}, Library)
	self.Theme = table.clone(DEFAULT_THEME)
	if config.Theme then for key, value in pairs(config.Theme) do self.Theme[key] = value end end
	self.ToggleKey = config.ToggleKey or Enum.KeyCode.Insert
	self.Tabs = {}
	self.SelectedTab = nil
	self.Connections = {}

	local gui = new("ScreenGui", {
		Name = config.Name or "EvernessUI", ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true,
		Parent = resolveParent(config),
	}) :: ScreenGui
	self.Gui = gui

	local shadow = new("ImageLabel", {
		Name = "Shadow", BackgroundTransparency = 1, Image = "rbxassetid://6014261993",
		ImageColor3 = Color3.new(), ImageTransparency = .28, ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(49, 49, 450, 450), Size = UDim2.new(1, 64, 1, 64),
		Position = UDim2.fromOffset(-32, -32), ZIndex = 0,
	})
	local window = new("Frame", {
		Name = "Window", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5),
		Size = config.Size or UDim2.fromOffset(680, 460), BackgroundColor3 = self.Theme.Window,
		BackgroundTransparency = .06, ClipsDescendants = false, Parent = gui,
	}) :: Frame
	corner(window, 12); stroke(window, self.Theme.Border, .4); shadow.Parent = window
	self.Window = window

	local sidebar = new("Frame", {Name = "Sidebar", Size = UDim2.new(0, 180, 1, 0), BackgroundTransparency = 1, Parent = window})
	local logo = textLabel(sidebar, config.LogoText or "✦", 38, self.Theme.Accent, {
		Size = UDim2.new(1, 0, 0, 80), TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center, Font = Enum.Font.GothamBold,
	})
	self.Logo = logo

	local nav = new("ScrollingFrame", {
		Name = "Navigation", Position = UDim2.fromOffset(0, 80), Size = UDim2.new(1, 0, 1, -90),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
		ScrollBarImageColor3 = self.Theme.Border, AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(), Parent = sidebar,
	})
	new("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = nav})
	self.Navigation = nav

	local content = new("Frame", {
		Name = "Content", Position = UDim2.fromOffset(180, 0), Size = UDim2.new(1, -180, 1, 0),
		BackgroundColor3 = self.Theme.Panel, BackgroundTransparency = .18, Parent = window,
	})
	corner(content, 12); stroke(content, self.Theme.Border, .45)
	local topbar = new("Frame", {Name = "Topbar", Size = UDim2.new(1, 0, 0, 49), BackgroundTransparency = 1, Parent = content})
	new("Frame", {Position = UDim2.new(0, 10, 1, -1), Size = UDim2.new(1, -20, 0, 1), BackgroundColor3 = self.Theme.Border, BackgroundTransparency = .45, BorderSizePixel = 0, Parent = topbar})
	self.TitleLabel = textLabel(topbar, config.Title or "Everness", 14, self.Theme.Text, {Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -70, 1, 0)})
	local close = new("TextButton", {Text = "×", TextSize = 22, Font = Enum.Font.Gotham, TextColor3 = self.Theme.TextDim, BackgroundTransparency = 1, Position = UDim2.new(1, -44, 0, 8), Size = UDim2.fromOffset(34, 32), Parent = topbar}) :: TextButton
	close.MouseButton1Click:Connect(function() self:SetVisible(false) end)
	close.MouseEnter:Connect(function() tween(close, .15, {TextColor3 = self.Theme.Text}) end)
	close.MouseLeave:Connect(function() tween(close, .15, {TextColor3 = self.Theme.TextDim}) end)

	self.Pages = new("Frame", {Name = "Pages", Position = UDim2.fromOffset(0, 49), Size = UDim2.new(1, 0, 1, -49), BackgroundTransparency = 1, ClipsDescendants = true, Parent = content})
	draggable(topbar, window)
	table.insert(self.Connections, UIS.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == self.ToggleKey then self:SetVisible(not gui.Enabled) end
	end))
	return self
end

function Library:SetVisible(visible: boolean)
	self.Gui.Enabled = visible
end

function Library:Toggle() self:SetVisible(not self.Gui.Enabled) end

function Library:SetAccent(color: Color3)
	self.Theme.Accent = color
	self.Logo.TextColor3 = color
	for _, tab in ipairs(self.Tabs) do tab:_refresh() end
end

function Library:AddCategory(name: string)
	local label = textLabel(self.Navigation, string.upper(name), 10, self.Theme.TextDim, {
		Size = UDim2.new(1, 0, 0, 22), TextTransparency = .15, TextXAlignment = Enum.TextXAlignment.Left,
	})
	new("UIPadding", {PaddingLeft = UDim.new(0, 20), Parent = label})
	return label
end

function Library:AddTab(config: any)
	if type(config) == "string" then config = {Name = config} end
	local tab = {Library = self, Name = config.Name or "Tab", Icon = config.Icon or "•", Sections = {}, Active = false}
	local button = new("TextButton", {
		Name = tab.Name, Text = "", AutoButtonColor = false, Size = UDim2.new(1, -20, 0, 32),
		Position = UDim2.fromOffset(10, 0), BackgroundColor3 = self.Theme.Window,
		BackgroundTransparency = 1, Parent = self.Navigation,
	}) :: TextButton
	corner(button, 6)
	local icon = textLabel(button, tab.Icon, 14, self.Theme.TextDim, {Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(22, 32), TextXAlignment = Enum.TextXAlignment.Center})
	local label = textLabel(button, tab.Name, 13, self.Theme.TextDim, {Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -48, 1, 0)})
	local page = new("ScrollingFrame", {
		Name = tab.Name, Visible = false, BackgroundTransparency = 1, BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1), ScrollBarThickness = 2, ScrollBarImageColor3 = self.Theme.Border,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = self.Pages,
	})
	new("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = page})
	new("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page})
	tab.Button, tab.IconLabel, tab.Label, tab.Page = button, icon, label, page
	function tab:_refresh()
		tween(button, .18, {BackgroundTransparency = self.Active and .88 or 1})
		tween(icon, .18, {TextColor3 = self.Active and self.Library.Theme.Accent or self.Library.Theme.TextDim})
		tween(label, .18, {TextColor3 = self.Active and self.Library.Theme.Text or self.Library.Theme.TextDim})
	end
	function tab:Select()
		for _, other in ipairs(self.Library.Tabs) do other.Active = false; other.Page.Visible = false; other:_refresh() end
		self.Active = true; self.Page.Visible = true; self:_refresh(); self.Library.TitleLabel.Text = self.Name
	end
	button.MouseEnter:Connect(function() if not tab.Active then tween(button, .15, {BackgroundTransparency = .94}); tween(label, .15, {TextColor3 = self.Theme.Text}) end end)
	button.MouseLeave:Connect(function() tab:_refresh() end)
	button.MouseButton1Click:Connect(function() tab:Select() end)
	function tab:AddSection(name: string)
		local section = {Tab = self, Library = self.Library, Name = name}
		local holder = new("Frame", {Name = name, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), AutomaticSize = Enum.AutomaticSize.Y, Parent = self.Page})
		local title = textLabel(holder, name, 11, self.Library.Theme.TextDim, {Size = UDim2.new(1, 0, 0, 22)})
		new("UIPadding", {PaddingLeft = UDim.new(0, 12), Parent = title})
		local body = new("Frame", {Name = "Body", Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = holder})
		new("UIListLayout", {Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body})
		section.Body = body
		setmetatable(section, {__index = Library.Section})
		table.insert(self.Sections, section)
		return section
	end
	table.insert(self.Tabs, tab)
	if not self.SelectedTab then self.SelectedTab = tab; tab:Select() end
	return tab
end

Library.Section = {}

function Library.Section:_row(label: string, height: number?): (Frame, TextLabel)
	local row = new("Frame", {Name = label, Size = UDim2.new(1, 0, 0, height or 34), BackgroundColor3 = self.Library.Theme.Element, BackgroundTransparency = .34, Parent = self.Body}) :: Frame
	stroke(row, self.Library.Theme.Border, .72)
	local text = textLabel(row, label, 12, self.Library.Theme.Text, {Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0)})
	return row, text
end

function Library.Section:AddLabel(text: string)
	local label = textLabel(self.Body, text, 11, self.Library.Theme.TextDim, {Size = UDim2.new(1, 0, 0, 28), TextWrapped = true})
	new("UIPadding", {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = label})
	return label
end

function Library.Section:AddButton(config: any)
	if type(config) == "string" then config = {Name = config} end
	local row, label = self:_row(config.Name or "Button")
	local button = new("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = row}) :: TextButton
	textLabel(row, "›", 20, self.Library.Theme.Text, {Position = UDim2.new(1, -30, 0, 0), Size = UDim2.fromOffset(18, 34), TextXAlignment = Enum.TextXAlignment.Center})
	bindHover(row :: any, self.Library.Theme.Element, self.Library.Theme.ElementHover)
	button.MouseButton1Click:Connect(function() if config.Callback then task.spawn(config.Callback) end end)
	return {SetText = function(_, value) label.Text = value end}
end

function Library.Section:AddToggle(config: any)
	local value = config.Default == true
	local row = self:_row(config.Name or "Toggle")
	local hit = new("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = row}) :: TextButton
	local track = new("Frame", {Position = UDim2.new(1, -40, .5, -8), Size = UDim2.fromOffset(28, 16), BackgroundColor3 = self.Library.Theme.ElementHover, Parent = row}) :: Frame
	corner(track, 99)
	local knob = new("Frame", {Position = UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = Color3.fromRGB(180, 180, 180), Parent = track}) :: Frame
	corner(knob, 99)
	local function render(fire: boolean)
		tween(track, .18, {BackgroundColor3 = value and self.Library.Theme.Accent:Lerp(Color3.new(), .35) or self.Library.Theme.ElementHover})
		tween(knob, .18, {Position = value and UDim2.fromOffset(15, 3) or UDim2.fromOffset(3, 3), BackgroundColor3 = value and Color3.new(1,1,1) or Color3.fromRGB(180,180,180)})
		if fire and config.Callback then task.spawn(config.Callback, value) end
	end
	hit.MouseButton1Click:Connect(function() value = not value; render(true) end)
	render(false)
	return {Get = function() return value end, Set = function(_, v) value = not not v; render(true) end}
end

function Library.Section:AddSlider(config: any)
	local min, max = config.Min or 0, config.Max or 100
	local value = math.clamp(config.Default or min, min, max)
	local row, label = self:_row(config.Name or "Slider", 46)
	local valueLabel = textLabel(row, tostring(value), 11, self.Library.Theme.TextDim, {Position = UDim2.new(1, -62, 0, 0), Size = UDim2.fromOffset(50, 30), TextXAlignment = Enum.TextXAlignment.Right})
	local track = new("Frame", {Position = UDim2.new(0, 12, 1, -10), Size = UDim2.new(1, -24, 0, 4), BackgroundColor3 = self.Library.Theme.ElementHover, BorderSizePixel = 0, Parent = row}) :: Frame
	corner(track, 99)
	local fill = new("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = self.Library.Theme.Accent, BorderSizePixel = 0, Parent = track}) :: Frame
	corner(fill, 99)
	local dragging = false
	local function set(v: number, fire: boolean)
		local step = config.Step or 1; value = math.clamp(math.floor(v / step + .5) * step, min, max)
		local alpha = (value - min) / (max - min); tween(fill, .08, {Size = UDim2.fromScale(alpha, 1)})
		valueLabel.Text = (config.Format and string.format(config.Format, value)) or tostring(value)
		if fire and config.Callback then task.spawn(config.Callback, value) end
	end
	local function fromX(x: number) set(min + math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1) * (max - min), true) end
	track.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true; fromX(i.Position.X) end end)
	UIS.InputChanged:Connect(function(i) if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then fromX(i.Position.X) end end)
	UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
	set(value, false)
	return {Get = function() return value end, Set = function(_, v) set(v, true) end, Label = label}
end

function Library.Section:AddDropdown(config: any)
	local options = config.Options or {}; local value = config.Default or options[1]; local open = false
	local row = self:_row(config.Name or "Dropdown", 40)
	local button = new("TextButton", {Text = tostring(value or "None"), TextSize = 11, Font = Enum.Font.GothamMedium, TextColor3 = self.Library.Theme.Text, AutoButtonColor = false, BackgroundColor3 = self.Library.Theme.ElementHover, Position = UDim2.new(1, -172, 0, 6), Size = UDim2.fromOffset(160, 28), Parent = row}) :: TextButton
	corner(button, 6)
	local popup = new("Frame", {Visible = false, Position = UDim2.new(1, -172, 1, 5), Size = UDim2.fromOffset(160, 8), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Color3.fromRGB(20,20,20), ZIndex = 20, Parent = row})
	corner(popup, 8); stroke(popup, self.Library.Theme.Border, .2)
	new("UIPadding", {PaddingTop = UDim.new(0,4), PaddingBottom = UDim.new(0,4), PaddingLeft = UDim.new(0,4), PaddingRight = UDim.new(0,4), Parent = popup})
	new("UIListLayout", {Padding = UDim.new(0,2), Parent = popup})
	local function set(v, fire) value = v; button.Text = tostring(v); open = false; popup.Visible = false; if fire and config.Callback then task.spawn(config.Callback, v) end end
	local function rebuild(list)
		options = list
		for _, child in ipairs(popup:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
		for _, option in ipairs(options) do
			local choice = new("TextButton", {Text = tostring(option), TextSize = 11, Font = Enum.Font.GothamMedium, TextColor3 = self.Library.Theme.TextDim, BackgroundColor3 = self.Library.Theme.Element, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,26), ZIndex = 21, Parent = popup}) :: TextButton
			corner(choice, 5); choice.MouseButton1Click:Connect(function() set(option, true) end)
			choice.MouseEnter:Connect(function() tween(choice,.12,{BackgroundTransparency=.3,TextColor3=self.Library.Theme.Text}) end)
			choice.MouseLeave:Connect(function() tween(choice,.12,{BackgroundTransparency=1,TextColor3=self.Library.Theme.TextDim}) end)
		end
	end
	button.MouseButton1Click:Connect(function() open = not open; popup.Visible = open end)
	rebuild(options)
	return {Get=function() return value end, Set=function(_,v) set(v,true) end, Refresh=function(_,list) rebuild(list) end}
end

function Library:Notify(config: any)
	if type(config) == "string" then config = {Text = config} end
	local toast = new("Frame", {AnchorPoint = Vector2.new(1,1), Position = UDim2.new(1,-20,1,-20), Size = UDim2.fromOffset(260,68), BackgroundColor3 = Color3.fromRGB(20,20,20), Parent = self.Gui}) :: Frame
	corner(toast, 10); stroke(toast, self.Theme.Border, .2)
	textLabel(toast, config.Title or "Notification", 12, self.Theme.Text, {Position=UDim2.fromOffset(14,8),Size=UDim2.new(1,-28,0,20)})
	textLabel(toast, config.Text or "", 11, self.Theme.TextDim, {Position=UDim2.fromOffset(14,28),Size=UDim2.new(1,-28,0,28),TextWrapped=true})
	toast.Position = UDim2.new(1, 280, 1, -20); tween(toast,.25,{Position=UDim2.new(1,-20,1,-20)})
	task.delay(config.Duration or 3, function() if toast.Parent then tween(toast,.2,{Position=UDim2.new(1,280,1,-20)}); task.wait(.22); toast:Destroy() end end)
end

function Library:Destroy()
	for _, connection in ipairs(self.Connections) do connection:Disconnect() end
	self.Gui:Destroy()
end

return Library
