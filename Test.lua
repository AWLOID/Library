--!nocheck
-- EvernessUI
-- Faithful Roblox/Luau reconstruction of the Alice/Everness ImGui menu found
-- in the supplied source tree. The module contains presentation code only.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")

local Library = {}
Library.__index = Library

local Page = {}
Page.__index = Page

local Section = {}
Section.__index = Section

-- RGBA values are copied from themes/themes.cpp. Roblox stores alpha as
-- transparency, so the conversion is transparency = 1 - alpha / 255.
local DEFAULT_THEME = {
	Accent = Color3.fromRGB(120, 255, 100),
	Text = Color3.fromRGB(255, 255, 255),
	TextAlpha = 200 / 255,
	TextHover = Color3.fromRGB(200, 200, 200),
	TextDim = Color3.fromRGB(155, 155, 155),
	TextUnsafe = Color3.fromRGB(255, 199, 56),
	Category = Color3.fromRGB(255, 255, 255),
	CategoryAlpha = .5,

	Border = Color3.fromRGB(24, 24, 24),
	BorderAlpha = 200 / 255,
	Window = Color3.fromRGB(12, 12, 12),
	WindowAlpha = 240 / 255,
	SettingsOverlay = Color3.fromRGB(8, 8, 8),
	SettingsOverlayAlpha = 220 / 255,

	Tab = Color3.fromRGB(255, 255, 255),
	TabAlpha = 0,
	TabHoverAlpha = 4 / 255,
	TabActiveAlpha = 8 / 255,
	TabClickedAlpha = 16 / 255,

	Element = Color3.fromRGB(40, 40, 40),
	ElementAlpha = 40 / 255,
	ElementHoverAlpha = 80 / 255,
	ElementClicked = Color3.fromRGB(42, 42, 42),
	ElementClickedAlpha = 100 / 255,
	ElementOutline = Color3.fromRGB(42, 42, 42),
	ElementOutlineAlpha = 50 / 255,
	ElementOverlay = Color3.fromRGB(255, 255, 255),
	ElementOverlayAlpha = 5 / 255,
	ElementOverlayHoverAlpha = 10 / 255,
	ElementOverlayActiveAlpha = 15 / 255,
	OverlayText = Color3.fromRGB(255, 255, 255),
	OverlayTextAlpha = 96 / 255,

	Popup = Color3.fromRGB(20, 20, 20),
	PopupAlpha = 140 / 255,
	PopupText = Color3.fromRGB(255, 255, 255),
	PopupTextAlpha = 185 / 255,
	PopupOutline = Color3.fromRGB(255, 255, 255),
	PopupOutlineAlpha = 8 / 255,
	PopupOverlay = Color3.fromRGB(255, 255, 255),
	PopupOverlayHoverAlpha = 8 / 255,
	PopupOverlayActiveAlpha = 16 / 255,
	SliderBackground = Color3.fromRGB(0, 0, 0),
	SliderBackgroundAlpha = 100 / 255,
}

local ICONS = {
	Gear = "⚙",
	Back = "‹",
	Down = "⌄",
	Right = "›",
	Save = "▣",
	Warning = "△",
	Check = "✓",
}

local function tr(alpha)
	return 1 - alpha
end

local function create(className, properties)
	local object = Instance.new(className)
	if object:IsA("GuiObject") then object.BorderSizePixel = 0 end
	for key, value in pairs(properties or {}) do
		if key ~= "Parent" then
			object[key] = value
		end
	end
	if properties and properties.Parent then
		object.Parent = properties.Parent
	end
	return object
end

local function addCorner(parent, radius)
	return create("UICorner", {
		CornerRadius = UDim.new(0, radius),
		Parent = parent,
	})
end

local function setCorners(corner, topLeft, topRight, bottomRight, bottomLeft)
	corner.TopLeftRadius = UDim.new(0, topLeft)
	corner.TopRightRadius = UDim.new(0, topRight)
	corner.BottomRightRadius = UDim.new(0, bottomRight)
	corner.BottomLeftRadius = UDim.new(0, bottomLeft)
end

local function addStroke(parent, color, alpha, thickness)
	return create("UIStroke", {
		Color = color,
		Transparency = tr(alpha),
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function play(object, duration, properties)
	local info = TweenInfo.new(duration or .10, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	local animation = TweenService:Create(object, info, properties)
	animation:Play()
	return animation
end

local function stripId(text)
	return string.match(tostring(text), "^(.-)##") or tostring(text)
end

local function makeText(parent, text, size, color, properties)
	local object = create("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = stripId(text),
		TextColor3 = color,
		TextTransparency = 0,
		TextSize = size,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = parent,
	})
	for key, value in pairs(properties or {}) do
		object[key] = value
	end
	return object
end

local function makeButton(parent, properties)
	local object = create("TextButton", {
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		ZIndex = 3,
		Parent = parent,
	})
	for key, value in pairs(properties or {}) do
		object[key] = value
	end
	return object
end

local function connectHover(guiObject, entered, left)
	guiObject.MouseEnter:Connect(entered)
	guiObject.MouseLeave:Connect(left)
end

local function makeDraggable(handle, target, connections)
	local dragging = false
	local startInput = Vector3.zero
	local startPosition = target.Position

	local began = handle.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			dragging = true
			startInput = input.Position
			startPosition = target.Position
		end
	end)

	local changed = UserInputService.InputChanged:Connect(function(input)
		local kind = input.UserInputType
		if dragging and (kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.Touch) then
			local delta = input.Position - startInput
			target.Position = UDim2.new(
				startPosition.X.Scale,
				startPosition.X.Offset + delta.X,
				startPosition.Y.Scale,
				startPosition.Y.Offset + delta.Y
			)
		end
	end)

	local ended = UserInputService.InputEnded:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	table.insert(connections, began)
	table.insert(connections, changed)
	table.insert(connections, ended)
end

local function resolveParent(config)
	if config.Parent then
		return config.Parent
	end
	local player = Players.LocalPlayer
	assert(player, "EvernessUI must be created from a LocalScript")
	return player:WaitForChild("PlayerGui")
end

local function dim(color, amount)
	return Color3.new(color.R * amount, color.G * amount, color.B * amount)
end

local function bindAccent(library, callback)
	table.insert(library._accentBindings, callback)
	callback(library.Theme.Accent)
end

function Library.new(config)
	config = config or {}
	local self = setmetatable({}, Library)

	self.Theme = table.clone(DEFAULT_THEME)
	for key, value in pairs(config.Theme or {}) do
		self.Theme[key] = value
	end
	self.ToggleKey = config.ToggleKey or Enum.KeyCode.Insert
	self.Tabs = {}
	self._connections = {}
	self._accentBindings = {}
	self._selectedTab = nil
	self._selectedPage = nil
	self._popup = nil
	self._visible = true
	self._visibilityToken = 0
	self._logoGlow = config.LogoGlow ~= false
	self._mainGlow = config.MainGlow ~= false

	local gui = create("ScreenGui", {
		Name = config.Name or "EvernessUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = config.DisplayOrder or 50,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		Parent = resolveParent(config),
	})
	self.Gui = gui

	local window = create("CanvasGroup", {
		Name = "@alicegang",
		AnchorPoint = Vector2.new(.5, .5),
		Position = config.Position or UDim2.fromScale(.5, .5),
		Size = config.Size or UDim2.fromOffset(680, 460),
		BackgroundColor3 = self.Theme.Window,
		BackgroundTransparency = tr(self.Theme.WindowAlpha),
		BorderSizePixel = 0,
		ClipsDescendants = false,
		GroupTransparency = 0,
		Parent = gui,
	})
	addCorner(window, 12)
	self.Window = window

	local scale = create("UIScale", {
		Scale = config.Scale or 1,
		Parent = window,
	})
	self.Scale = scale

	local shadow = create("ImageLabel", {
		Name = "WindowShadow",
		BackgroundTransparency = 1,
		Image = "rbxassetid://6014261993",
		ImageColor3 = Color3.fromRGB(0, 0, 0),
		ImageTransparency = tr(160 / 255),
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(49, 49, 450, 450),
		Position = UDim2.fromOffset(-64, -64),
		Size = UDim2.new(1, 128, 1, 128),
		ZIndex = -10,
		Parent = window,
	})
	self.Shadow = shadow

	local rightOutline = create("Frame", {
		Name = "OverlayOutline",
		Position = UDim2.fromOffset(180, 0),
		Size = UDim2.new(1, -180, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = window,
	})
	addCorner(rightOutline, 12)
	addStroke(rightOutline, self.Theme.Border, self.Theme.BorderAlpha)

	local mainGlow = create("ImageLabel", {
		Name = "MainGlow",
		BackgroundTransparency = 1,
		Image = "rbxassetid://6014261993",
		ImageColor3 = self.Theme.Accent,
		ImageTransparency = .84,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(49, 49, 450, 450),
		AnchorPoint = Vector2.new(.5, .5),
		Position = UDim2.new(0, 420, 0, 10),
		Size = UDim2.fromOffset(500, 260),
		ZIndex = 0,
		Visible = self._mainGlow,
		Parent = window,
	})
	self.MainGlow = mainGlow
	bindAccent(self, function(accent) mainGlow.ImageColor3 = accent end)

	local sidebar = create("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, 180, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = window,
	})
	self.Sidebar = sidebar

	local logoArea = create("Frame", {
		Name = "LogoArea",
		Size = UDim2.fromOffset(180, 80),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = sidebar,
	})

	local logoGlow = create("ImageLabel", {
		Name = "LogoGlow",
		AnchorPoint = Vector2.new(.5, .5),
		Position = UDim2.fromOffset(90, 40),
		Size = UDim2.fromOffset(150, 150),
		BackgroundTransparency = 1,
		Image = "rbxassetid://6014261993",
		ImageColor3 = self.Theme.Accent,
		ImageTransparency = .52,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(49, 49, 450, 450),
		Visible = self._logoGlow,
		ZIndex = 1,
		Parent = sidebar,
	})
	self.LogoGlow = logoGlow
	bindAccent(self, function(accent) logoGlow.ImageColor3 = accent end)

	local logo
	local logoGradient
	if config.LogoImage then
		logo = create("ImageLabel", {
			Name = "Logo",
			AnchorPoint = Vector2.new(.5, .5),
			Position = UDim2.new(.5, 0, .5, 10),
			Size = UDim2.fromOffset(80, 80),
			BackgroundTransparency = 1,
			Image = config.LogoImage,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 3,
			Parent = logoArea,
		})
		logoGradient = create("UIGradient", {
			Color = ColorSequence.new(Color3.new(1, 1, 1), self.Theme.Accent),
			Rotation = 0,
			Parent = logo,
		})
	else
		logo = makeText(logoArea, config.LogoText or "✿", 48, Color3.new(1, 1, 1), {
			Name = "Logo",
			Position = UDim2.fromOffset(50, 10),
			Size = UDim2.fromOffset(80, 80),
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 3,
		})
		logoGradient = create("UIGradient", {
			Color = ColorSequence.new(Color3.new(1, 1, 1), self.Theme.Accent),
			Rotation = 0,
			Parent = logo,
		})
	end
	self.Logo = logo
	bindAccent(self, function(accent)
		logoGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), accent)
	end)
	logoArea.ClipsDescendants = true

	local navigation = create("ScrollingFrame", {
		Name = "Tabs",
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 1, -80),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Color3.new(1, 1, 1),
		ScrollBarImageTransparency = tr(5 / 255),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 3,
		Parent = sidebar,
	})
	create("UIListLayout", {
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = navigation,
	})
	self.Navigation = navigation

	local topArea = create("Frame", {
		Name = "TopArea",
		Position = UDim2.fromOffset(181, 1),
		Size = UDim2.new(1, -181, 0, 48),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = window,
	})
	self.TopArea = topArea

	local topContent = create("Frame", {
		Name = "TopContent",
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 1, -20),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = topArea,
	})
	self.TopContent = topContent

	local separator = create("Frame", {
		Name = "Separator",
		Position = UDim2.fromOffset(180, 50),
		Size = UDim2.new(1, -180, 0, 1),
		BackgroundColor3 = self.Theme.Border,
		BackgroundTransparency = tr(self.Theme.BorderAlpha),
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = window,
	})

	local pages = create("Frame", {
		Name = "MainArea",
		Position = UDim2.fromOffset(181, 51),
		Size = UDim2.new(1, -181, 1, -51),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 4,
		Parent = window,
	})
	self.Pages = pages

	local gear = makeButton(topContent, {
		Name = "Settings",
		Position = UDim2.new(1, -28, 0, 0),
		Size = UDim2.fromOffset(28, 28),
		ZIndex = 10,
	})
	local gearIcon = makeText(gear, ICONS.Gear, 14, self.Theme.TextDim, {
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 11,
	})
	connectHover(gear, function()
		play(gearIcon, .10, {TextColor3 = self.Theme.Text, TextTransparency = tr(self.Theme.TextAlpha)})
	end, function()
		play(gearIcon, .10, {TextColor3 = self.Theme.TextDim, TextTransparency = 0})
	end)
	gear.MouseButton1Click:Connect(function()
		self:_setSettingsVisible(true)
	end)
	self.Gear = gear

	local popupLayer = create("Frame", {
		Name = "PopupLayer",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 100,
		Parent = window,
	})
	self.PopupLayer = popupLayer

	self:_buildSettings()
	makeDraggable(logoArea, window, self._connections)
	makeDraggable(topArea, window, self._connections)

	table.insert(self._connections, UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == self.ToggleKey then
			self:Toggle()
		end
	end))

	return self
end

function Library:_buildSettings()
	local theme = self.Theme
	local overlay = create("CanvasGroup", {
		Name = "SettingsOverlay",
		Position = UDim2.fromOffset(180, 0),
		Size = UDim2.new(1, -180, 1, 0),
		BackgroundColor3 = theme.SettingsOverlay,
		BackgroundTransparency = tr(theme.SettingsOverlayAlpha),
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Visible = false,
		ZIndex = 60,
		Parent = self.Window,
	})
	addCorner(overlay, 12)
	self.SettingsOverlay = overlay

	local blocker = makeButton(overlay, {
		Name = "Blocker",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 60,
	})
	blocker.MouseButton1Click:Connect(function() self:_setSettingsVisible(false) end)

	local panel = create("Frame", {
		Name = "Settings",
		Position = UDim2.fromOffset(180, 0),
		Size = UDim2.new(1, -180, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 61,
		Parent = overlay,
	})

	local back = makeButton(panel, {
		Name = "Back",
		Position = UDim2.new(1, -38, 0, 10),
		Size = UDim2.fromOffset(28, 28),
		ZIndex = 63,
	})
	local backIcon = makeText(back, ICONS.Back, 24, theme.TextDim, {
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 64,
	})
	back.MouseButton1Click:Connect(function() self:_setSettingsVisible(false) end)
	connectHover(back, function()
		play(backIcon, .1, {TextColor3 = theme.Text, TextTransparency = tr(theme.TextAlpha)})
	end, function()
		play(backIcon, .1, {TextColor3 = theme.TextDim, TextTransparency = 0})
	end)

	local area = create("Frame", {
		Name = "SettingsArea",
		Position = UDim2.fromOffset(10, 48),
		Size = UDim2.new(1, -20, 1, -58),
		BackgroundTransparency = 1,
		ZIndex = 62,
		Parent = panel,
	})

	local category = makeText(area, "UI", 10, theme.OverlayText, {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -24, 0, 18),
		Font = Enum.Font.GothamBold,
		TextTransparency = tr(theme.OverlayTextAlpha),
		ZIndex = 63,
	})

	local group = create("Frame", {
		Name = "UIGroup",
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 0, 170),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 63,
		Parent = area,
	})
	addCorner(group, 12)

	local function settingsRow(index, title)
		local row = create("Frame", {
			Name = title,
			Position = UDim2.fromOffset(0, (index - 1) * 34),
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = theme.Element,
			BackgroundTransparency = tr(theme.ElementAlpha),
			BorderSizePixel = 0,
			ZIndex = 63,
			Parent = group,
		})
		local rowCorner = addCorner(row, 0)
		if index == 1 then
			setCorners(rowCorner, 12, 12, 0, 0)
		elseif index == 5 then
			setCorners(rowCorner, 0, 0, 12, 12)
		end
		makeText(row, title, 14, theme.Text, {
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -24, 1, 0),
			TextTransparency = tr(theme.TextAlpha),
			ZIndex = 64,
		})
		if index < 5 then
			create("Frame", {
				Position = UDim2.new(0, 0, 1, -1),
				Size = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = theme.ElementOutline,
				BackgroundTransparency = tr(theme.ElementOutlineAlpha),
				BorderSizePixel = 0,
				ZIndex = 65,
				Parent = row,
			})
		end
		return row
	end

	local themeRow = settingsRow(1, "Theme")
	local themePill = create("Frame", {
		Position = UDim2.new(.5, 0, 0, 5),
		Size = UDim2.new(.5, -12, 0, 24),
		BackgroundColor3 = theme.ElementOverlay,
		BackgroundTransparency = tr(theme.ElementOverlayAlpha),
		ZIndex = 65,
		Parent = themeRow,
	})
	addCorner(themePill, 6)
	addStroke(themePill, theme.ElementOverlay, theme.ElementOverlayHoverAlpha)
	makeText(themePill, "Default", 14, theme.Text, {
		Position = UDim2.fromOffset(6, 0),
		Size = UDim2.new(1, -24, 1, 0),
		TextTransparency = tr(theme.TextAlpha),
		ZIndex = 66,
	})
	makeText(themePill, ICONS.Down, 14, theme.Text, {
		Position = UDim2.new(1, -22, 0, 0),
		Size = UDim2.fromOffset(16, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = tr(theme.TextAlpha),
		ZIndex = 66,
	})

	local function settingsToggle(row, getValue, setValue)
		local track = create("Frame", {
			Position = UDim2.new(1, -40, .5, -8),
			Size = UDim2.fromOffset(28, 16),
			BackgroundColor3 = theme.ElementOverlay,
			BackgroundTransparency = tr(theme.ElementOverlayHoverAlpha),
			ZIndex = 65,
			Parent = row,
		})
		addCorner(track, 999)
		local knob = create("Frame", {
			Size = UDim2.fromOffset(8, 8),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 66,
			Parent = track,
		})
		addCorner(knob, 999)
		local function render()
			local value = getValue()
			track.BackgroundColor3 = value and dim(theme.Accent, .65) or theme.ElementOverlay
			track.BackgroundTransparency = value and 0 or tr(theme.ElementOverlayHoverAlpha)
			knob.Position = value and UDim2.fromOffset(17, 4) or UDim2.fromOffset(3, 4)
			knob.BackgroundTransparency = value and 0 or tr(theme.ElementOverlayActiveAlpha)
		end
		local hit = makeButton(row, {Size = UDim2.fromScale(1, 1), ZIndex = 67})
		hit.MouseButton1Click:Connect(function()
			setValue(not getValue())
			render()
		end)
		bindAccent(self, function() render() end)
		render()
	end

	local mainGlowRow = settingsRow(2, "Main glow")
	settingsToggle(mainGlowRow, function() return self._mainGlow end, function(value)
		self._mainGlow = value
		self.MainGlow.Visible = value
	end)
	local logoGlowRow = settingsRow(3, "Logo glow")
	settingsToggle(logoGlowRow, function() return self._logoGlow end, function(value)
		self._logoGlow = value
		self.LogoGlow.Visible = value
	end)

	local accentRow = settingsRow(4, "Accent color")
	local accentSwatch = create("Frame", {
		Position = UDim2.new(1, -28, .5, -8),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = theme.Accent,
		ZIndex = 65,
		Parent = accentRow,
	})
	addCorner(accentSwatch, 5)
	bindAccent(self, function(accent) accentSwatch.BackgroundColor3 = accent end)
	local accentHit = makeButton(accentRow, {Size = UDim2.fromScale(1, 1), ZIndex = 67})
	accentHit.MouseButton1Click:Connect(function()
		self:_openColorPopup(accentSwatch, self.Theme.Accent, function(color) self:SetAccent(color) end)
	end)

	local widgetsRow = settingsRow(5, "Widgets")
	makeText(widgetsRow, ICONS.Right, 20, theme.Text, {
		Position = UDim2.new(1, -30, 0, 0),
		Size = UDim2.fromOffset(18, 34),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = tr(theme.TextAlpha),
		ZIndex = 66,
	})
	local widgetValues = {Watermark = true, Keybinds = true, ["Hit logs"] = true}
	local widgetsHit = makeButton(widgetsRow, {Size = UDim2.fromScale(1, 1), ZIndex = 67})
	widgetsHit.MouseButton1Click:Connect(function()
		local windowPosition = self.Window.AbsolutePosition
		local rowPosition = widgetsRow.AbsolutePosition
		local x = rowPosition.X - windowPosition.X + widgetsRow.AbsoluteSize.X - 160
		local y = rowPosition.Y - windowPosition.Y - 40
		local popup = self:_popupFrame(150, 100, UDim2.fromOffset(x, y))
		local holder = create("Frame", {
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.new(1, -16, 1, -16),
			BackgroundTransparency = 1,
			ZIndex = 102,
			Parent = popup,
		})
		create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder})
		for _, name in ipairs({"Watermark", "Keybinds", "Hit logs"}) do
			local option = makeButton(holder, {
				Name = name,
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundColor3 = theme.PopupOverlay,
				BackgroundTransparency = 1,
				ZIndex = 103,
			})
			addCorner(option, 16)
			makeText(option, name, 14, theme.PopupText, {
				Position = UDim2.fromOffset(2, 0), Size = UDim2.new(1, -26, 1, 0),
				TextTransparency = tr(theme.PopupTextAlpha), ZIndex = 104,
			})
			local check = makeText(option, widgetValues[name] and ICONS.Check or "", 12, theme.Accent, {
				Position = UDim2.new(1, -20, 0, 0), Size = UDim2.fromOffset(14, 28),
				TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 104,
			})
			option.MouseButton1Click:Connect(function()
				widgetValues[name] = not widgetValues[name]
				check.Text = widgetValues[name] and ICONS.Check or ""
			end)
			connectHover(option, function()
				play(option, .1, {BackgroundTransparency = tr(theme.PopupOverlayHoverAlpha)})
			end, function()
				play(option, .1, {BackgroundTransparency = 1})
			end)
		end
	end)
end

function Library:_setSettingsVisible(visible)
	local overlay = self.SettingsOverlay
	if visible then
		self:ClosePopup()
		overlay.Visible = true
		overlay.GroupTransparency = 1
		play(overlay, .12, {GroupTransparency = 0})
	else
		local animation = play(overlay, .12, {GroupTransparency = 1})
		animation.Completed:Once(function()
			if overlay.GroupTransparency >= .99 then overlay.Visible = false end
		end)
	end
end

function Library:_newPage(name)
	local root = create("CanvasGroup", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		ZIndex = 5,
		Parent = self.Pages,
	})
	local scroll = create("ScrollingFrame", {
		Name = "Scroll",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.None,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Color3.new(1, 1, 1),
		ScrollBarImageTransparency = tr(5 / 255),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 6,
		Parent = root,
	})
	local columns = create("Frame", {
		Name = "Columns",
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 0, 0),
		AutomaticSize = Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = scroll,
	})
	local left = create("Frame", {
		Name = "Left",
		Size = UDim2.new(.5, -5, 0, 0),
		AutomaticSize = Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = columns,
	})
	local right = create("Frame", {
		Name = "Right",
		Position = UDim2.new(.5, 5, 0, 0),
		Size = UDim2.new(.5, -5, 0, 0),
		AutomaticSize = Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = columns,
	})
	local leftLayout = create("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = left})
	local rightLayout = create("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = right})

	local page = setmetatable({
		Library = self,
		Name = name,
		Root = root,
		Scroll = scroll,
		Columns = columns,
		Left = left,
		Right = right,
		Sections = {},
	}, Page)
	local function updateCanvas()
		local leftHeight = leftLayout.AbsoluteContentSize.Y
		local rightHeight = right.Visible and rightLayout.AbsoluteContentSize.Y or 0
		left.Size = UDim2.new(left.Size.X.Scale, left.Size.X.Offset, 0, leftHeight)
		right.Size = UDim2.new(right.Size.X.Scale, right.Size.X.Offset, 0, rightHeight)
		local height = math.max(leftHeight, rightHeight)
		columns.Size = UDim2.new(1, -20, 0, height)
		scroll.CanvasSize = UDim2.fromOffset(0, height + 20)
	end
	page._updateCanvas = updateCanvas
	table.insert(self._connections, leftLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas))
	table.insert(self._connections, rightLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas))
	task.defer(updateCanvas)
	return page
end

function Library:_showPage(page)
	if self._selectedPage == page then return end
	self:ClosePopup()
	self._pageTransitionToken = (self._pageTransitionToken or 0) + 1
	local token = self._pageTransitionToken
	local previous = self._selectedPage
	self._selectedPage = page
	local function reveal()
		if token ~= self._pageTransitionToken then return end
		for _, tab in ipairs(self.Tabs) do
			for _, candidate in ipairs(tab.Pages) do candidate.Root.Visible = candidate == page end
		end
		page.Root.Visible = true
		page.Root.GroupTransparency = 1
		page.Root.Position = UDim2.fromOffset(0, 30)
		play(page.Root, .20, {GroupTransparency = 0, Position = UDim2.fromOffset(0, 0)})
	end
	if previous and previous.Root.Visible then
		local animation = play(previous.Root, .20, {GroupTransparency = 1, Position = UDim2.fromOffset(0, 30)})
		animation.Completed:Once(reveal)
	else
		reveal()
	end
end

function Library:_rebuildTopbar(tab)
	for _, child in ipairs(self.TopContent:GetChildren()) do
		if child ~= self.Gear then child:Destroy() end
	end

	local cursor = 0
	if tab.SaveCallback then
		local save = makeButton(self.TopContent, {
			Name = "Save",
			Position = UDim2.fromOffset(cursor, 0),
			Size = UDim2.fromOffset(70, 28),
			BackgroundColor3 = self.Theme.Tab,
			BackgroundTransparency = tr(self.Theme.TabAlpha),
			ZIndex = 7,
		})
		addCorner(save, 6)
		addStroke(save, self.Theme.Border, self.Theme.BorderAlpha)
		local label = makeText(save, ICONS.Save .. "  Save", 14, self.Theme.TextDim, {
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 8,
		})
		connectHover(save, function()
			play(save, .1, {BackgroundTransparency = tr(self.Theme.TabHoverAlpha)})
			play(label, .1, {TextColor3 = self.Theme.Text})
		end, function()
			play(save, .1, {BackgroundTransparency = tr(self.Theme.TabAlpha)})
			play(label, .1, {TextColor3 = self.Theme.TextDim})
		end)
		save.MouseButton1Click:Connect(function() task.spawn(tab.SaveCallback) end)
		cursor += 80
	end

	if #tab.SubTabs > 0 then
		local holder = create("Frame", {
			Name = "SubTabs",
			Position = UDim2.fromOffset(cursor, 0),
			Size = UDim2.fromOffset(0, 28),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = self.Theme.Tab,
			BackgroundTransparency = tr(self.Theme.TabHoverAlpha),
			ClipsDescendants = true,
			ZIndex = 7,
			Parent = self.TopContent,
		})
		addCorner(holder, 6)
		create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder})
		for index, subtab in ipairs(tab.SubTabs) do
			local bounds = TextService:GetTextSize(subtab.Name, 14, Enum.Font.Gotham, Vector2.new(1000, 28))
			local width = math.ceil(bounds.X) + 28
			local button = makeButton(holder, {
				Name = subtab.Name,
				Size = UDim2.fromOffset(width, 28),
				BackgroundColor3 = self.Theme.Tab,
				BackgroundTransparency = tr(subtab.Active and self.Theme.TabActiveAlpha or self.Theme.TabAlpha),
				ZIndex = 8,
			})
			local segmentCorner = addCorner(button, 0)
			if index == 1 then
				setCorners(segmentCorner, 6, 0, 0, 6)
			else
				setCorners(segmentCorner, 0, 6, 6, 0)
			end
			local label = makeText(button, subtab.Name, 14, subtab.Active and self.Theme.Text or self.Theme.TextDim, {
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTransparency = subtab.Active and tr(self.Theme.TextAlpha) or 0,
				ZIndex = 9,
			})
			connectHover(button, function()
				if not subtab.Active then
					play(button, .1, {BackgroundTransparency = tr(self.Theme.TabHoverAlpha)})
					play(label, .1, {TextColor3 = self.Theme.TextHover})
				end
			end, function()
				if not subtab.Active then
					play(button, .1, {BackgroundTransparency = tr(self.Theme.TabAlpha)})
					play(label, .1, {TextColor3 = self.Theme.TextDim})
				end
			end)
			button.MouseButton1Click:Connect(function()
				for _, item in ipairs(tab.SubTabs) do item.Active = false end
				subtab.Active = true
				tab.ActiveSubTab = subtab
				self:_rebuildTopbar(tab)
				self:_showPage(subtab.Page)
			end)
		end
	end
end

function Library:AddCategory(name)
	local slot = create("Frame", {
		Name = string.upper(name),
		Size = UDim2.new(1, 0, 0, 19),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = self.Navigation,
	})
	local label = makeText(slot, string.upper(name), 14, self.Theme.Category, {
		Name = string.upper(name),
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.fromOffset(20, 5),
		TextTransparency = tr(self.Theme.CategoryAlpha),
		ZIndex = 4,
	})
	return label
end

function Library:AddTab(config)
	if type(config) == "string" then config = {Name = config} end
	config = config or {}
	local tab = {
		Library = self,
		Name = config.Name or "Tab",
		Icon = config.Icon or "•",
		SaveCallback = config.SaveCallback or config.OnSave,
		Active = false,
		SubTabs = {},
		Pages = {},
	}

	local navSlot = create("Frame", {
		Name = tab.Name,
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = self.Navigation,
	})
	local button = makeButton(navSlot, {
		Name = "Button",
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -20, 1, 0),
		BackgroundColor3 = self.Theme.Tab,
		BackgroundTransparency = tr(self.Theme.TabAlpha),
		ZIndex = 4,
	})
	addCorner(button, 6)
	local icon = makeText(button, tab.Icon, 14, self.Theme.TextDim, {
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.fromOffset(20, 32),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 5,
	})
	local label = makeText(button, tab.Name, 14, self.Theme.TextDim, {
		Position = UDim2.fromOffset(44, 0),
		Size = UDim2.new(1, -50, 1, 0),
		ZIndex = 5,
	})
	tab.Button = button
	tab.IconLabel = icon
	tab.Label = label
	tab.RootPage = self:_newPage(tab.Name)
	table.insert(tab.Pages, tab.RootPage)
	if config.SingleColumn then tab.RootPage:SetSingleColumn(true) end

	function tab:_refresh()
		local theme = self.Library.Theme
		play(self.Button, .10, {BackgroundTransparency = tr(self.Active and theme.TabActiveAlpha or theme.TabAlpha)})
		play(self.IconLabel, .10, {TextColor3 = self.Active and theme.Accent or theme.TextDim, TextTransparency = 0})
		play(self.Label, .10, {TextColor3 = self.Active and theme.Text or theme.TextDim})
		self.Label.TextTransparency = self.Active and tr(theme.TextAlpha) or 0
	end

	function tab:Select()
		for _, other in ipairs(self.Library.Tabs) do
			other.Active = false
			other:_refresh()
		end
		self.Active = true
		self.Library._selectedTab = self
		self:_refresh()
		if #self.SubTabs > 0 then
			local selected = self.ActiveSubTab or self.SubTabs[1]
			for _, item in ipairs(self.SubTabs) do item.Active = item == selected end
			self.ActiveSubTab = selected
			self.Library:_showPage(selected.Page)
		else
			self.Library:_showPage(self.RootPage)
		end
		self.Library:_rebuildTopbar(self)
	end

	function tab:AddSubTab(name)
		local subtab = {
			Name = name,
			Active = #self.SubTabs == 0,
			Page = self.Library:_newPage(self.Name .. "_" .. name),
		}
		table.insert(self.SubTabs, subtab)
		table.insert(self.Pages, subtab.Page)
		if subtab.Active then self.ActiveSubTab = subtab end
		if self.Active then
			self.Library:_rebuildTopbar(self)
			self.Library:_showPage(self.ActiveSubTab.Page)
		end
		return subtab.Page
	end

	function tab:AddSection(name, side)
		return self.RootPage:AddSection(name, side)
	end

	connectHover(button, function()
		if not tab.Active then
			play(button, .10, {BackgroundTransparency = tr(self.Theme.TabHoverAlpha)})
			play(icon, .10, {TextColor3 = self.Theme.Text, TextTransparency = tr(self.Theme.TextAlpha)})
			play(label, .10, {TextColor3 = self.Theme.TextHover})
		end
	end, function()
		tab:_refresh()
	end)
	button.MouseButton1Down:Connect(function()
		button.BackgroundTransparency = tr(self.Theme.TabClickedAlpha)
	end)
	button.MouseButton1Click:Connect(function() tab:Select() end)
	bindAccent(self, function() if tab.Active then icon.TextColor3 = self.Theme.Accent end end)

	table.insert(self.Tabs, tab)
	if not self._selectedTab then tab:Select() end
	return tab
end

function Page:AddSection(name, side)
	name = name or ""
	local target = string.lower(tostring(side or "Left")) == "right" and self.Right or self.Left
	local section = setmetatable({
		Library = self.Library,
		Page = self,
		Name = name,
		Rows = {},
	}, Section)

	local hasTitle = name ~= ""
	local holder = create("Frame", {
		Name = hasTitle and name or "Group",
		Size = UDim2.new(1, 0, 0, hasTitle and 22 or 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = target,
	})
	local title = makeText(holder, name, 10, self.Library.Theme.OverlayText, {
		Name = "Title",
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -24, 0, 18),
		Font = Enum.Font.GothamBold,
		TextTransparency = tr(self.Library.Theme.OverlayTextAlpha),
		ZIndex = 8,
		Visible = hasTitle,
	})
	local body = create("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, hasTitle and 22 or 0),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		ZIndex = 7,
		Parent = holder,
	})
	create("UIListLayout", {
		Padding = UDim.new(0, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = body,
	})
	section.Holder = holder
	section.Title = title
	section.Body = body
	table.insert(self.Sections, section)
	task.defer(self._updateCanvas)
	return section
end

function Page:SetSingleColumn(enabled)
	enabled = enabled ~= false
	self.Right.Visible = not enabled
	self.Left.Size = enabled and UDim2.new(1, 0, 0, self.Left.Size.Y.Offset) or UDim2.new(.5, -5, 0, self.Left.Size.Y.Offset)
	self.Right.Position = UDim2.new(.5, 5, 0, 0)
	self.Right.Size = UDim2.new(.5, -5, 0, self.Right.Size.Y.Offset)
	task.defer(self._updateCanvas)
	return self
end

function Section:_row(label, height)
	local theme = self.Library.Theme
	local row = create("Frame", {
		Name = stripId(label),
		Size = UDim2.new(1, 0, 0, height or 34),
		BackgroundColor3 = theme.Element,
		BackgroundTransparency = tr(theme.ElementAlpha),
		BorderSizePixel = 0,
		ZIndex = 8,
		Parent = self.Body,
	})
	local rowCorner = addCorner(row, 12)
	local labelObject = makeText(row, label, 14, theme.Text, {
		Name = "Label",
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -24, 1, 0),
		TextTransparency = tr(theme.TextAlpha),
		ZIndex = 9,
	})
	local hit = makeButton(row, {
		Name = "Hitbox",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 12,
	})
	local entry = {Row = row, Label = labelObject, Hitbox = hit, Corner = rowCorner, BaseHeight = height or 34}
	local previous = self.Rows[#self.Rows]
	if previous then
		previous.Divider.Visible = true
	end
	local divider = create("Frame", {
		Name = "Divider",
		Position = UDim2.new(0, 0, 1, -1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = theme.ElementOutline,
		BackgroundTransparency = tr(theme.ElementOutlineAlpha),
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 11,
		Parent = row,
	})
	entry.Divider = divider
	table.insert(self.Rows, entry)

	for index, item in ipairs(self.Rows) do
		local first = index == 1
		local last = index == #self.Rows
		item.Row.Size = UDim2.new(1, 0, 0, (last and item.BaseHeight or item.BaseHeight + 1))
		item.Label.Position = UDim2.fromOffset(12, last and 0 or -1)
		item.Divider.Visible = not last
		if first and last then
			setCorners(item.Corner, 12, 12, 12, 12)
		elseif first then
			setCorners(item.Corner, 12, 12, 0, 0)
		elseif last then
			setCorners(item.Corner, 0, 0, 12, 12)
		else
			setCorners(item.Corner, 0, 0, 0, 0)
		end
	end

	connectHover(hit, function()
		play(row, .10, {BackgroundColor3 = theme.Element, BackgroundTransparency = tr(theme.ElementHoverAlpha)})
	end, function()
		play(row, .10, {BackgroundColor3 = theme.Element, BackgroundTransparency = tr(theme.ElementAlpha)})
	end)
	hit.MouseButton1Down:Connect(function()
		row.BackgroundColor3 = theme.ElementClicked
		row.BackgroundTransparency = tr(theme.ElementClickedAlpha)
	end)
	hit.MouseButton1Up:Connect(function()
		play(row, .10, {BackgroundColor3 = theme.Element, BackgroundTransparency = tr(theme.ElementHoverAlpha)})
	end)
	return entry
end

function Section:AddLabel(text)
	local entry = self:_row(text)
	entry.Label.TextSize = 10
	entry.Label.Font = Enum.Font.GothamBold
	entry.Label.TextColor3 = self.Library.Theme.OverlayText
	entry.Label.TextTransparency = tr(self.Library.Theme.OverlayTextAlpha)
	entry.Label.TextWrapped = true
	entry.Hitbox.Active = false
	return entry.Label
end

function Section:AddButton(config)
	if type(config) == "string" then config = {Name = config} end
	config = config or {}
	local entry = self:_row(config.Name or "Button")
	local arrow = makeText(entry.Row, ICONS.Right, 20, self.Library.Theme.Text, {
		Position = UDim2.new(1, -30, 0, 0),
		Size = UDim2.fromOffset(18, 34),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = tr(self.Library.Theme.TextAlpha),
		ZIndex = 10,
	})
	entry.Hitbox.MouseButton1Click:Connect(function()
		if config.Callback then task.spawn(config.Callback) end
	end)
	return {
		SetText = function(_, value) entry.Label.Text = stripId(value) end,
		Instance = entry.Row,
	}
end

function Section:AddToggle(config)
	config = config or {}
	local value = config.Default == true
	local colors = table.clone(config.Colors or {})
	local entry = self:_row(config.Name or "Toggle")
	if config.Unsafe then
		entry.Label.Text = ICONS.Warning .. "  " .. stripId(config.Name or "Toggle")
		entry.Label.TextColor3 = self.Library.Theme.TextUnsafe
	end

	local track = create("Frame", {
		Name = "Track",
		Position = UDim2.new(1, -40, .5, -8),
		Size = UDim2.fromOffset(28, 16),
		BackgroundColor3 = self.Library.Theme.ElementOverlay,
		BackgroundTransparency = tr(self.Library.Theme.ElementOverlayHoverAlpha),
		BorderSizePixel = 0,
		ZIndex = 10,
		Parent = entry.Row,
	})
	addCorner(track, 999)
	local knob = create("Frame", {
		Name = "Knob",
		Position = UDim2.fromOffset(3, 4),
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = self.Library.Theme.ElementOverlay,
		BackgroundTransparency = tr(self.Library.Theme.ElementOverlayActiveAlpha),
		BorderSizePixel = 0,
		ZIndex = 11,
		Parent = track,
	})
	addCorner(knob, 999)
	local toggleHit = makeButton(track, {
		Name = "ToggleHitbox",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 13,
	})
	connectHover(toggleHit, function()
		play(entry.Row, .10, {BackgroundColor3 = self.Library.Theme.Element, BackgroundTransparency = tr(self.Library.Theme.ElementHoverAlpha)})
	end, function()
		play(entry.Row, .10, {BackgroundColor3 = self.Library.Theme.Element, BackgroundTransparency = tr(self.Library.Theme.ElementAlpha)})
	end)

	local swatches = {}
	for index, initialColor in ipairs(colors) do
		local swatch = create("Frame", {
			Name = "Color" .. index,
			Position = UDim2.new(1, -62 - (index - 1) * 22, 0, 9),
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = initialColor,
			BorderSizePixel = 0,
			ZIndex = 13,
			Parent = entry.Row,
		})
		addCorner(swatch, 5)
		addStroke(swatch, self.Library.Theme.ElementOverlay, self.Library.Theme.ElementOverlayHoverAlpha)
		local swatchHit = makeButton(swatch, {Size = UDim2.fromScale(1, 1), ZIndex = 14})
		swatchHit.MouseButton1Click:Connect(function()
			self.Library:_openColorPopup(swatch, colors[index], function(color)
				colors[index] = color
				swatch.BackgroundColor3 = color
				if config.ColorCallback then task.spawn(config.ColorCallback, index, color) end
			end)
		end)
		swatches[index] = swatch
	end
	if config.Settings or config.HasSettings then
		local settingsButton = makeButton(entry.Row, {
			Name = "Settings",
			Position = UDim2.new(1, -62 - #colors * 22, 0, 9),
			Size = UDim2.fromOffset(16, 16),
			ZIndex = 13,
		})
		makeText(settingsButton, ICONS.Right, 18, self.Library.Theme.Text, {
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextTransparency = tr(self.Library.Theme.TextAlpha),
			ZIndex = 14,
		})
		settingsButton.MouseButton1Click:Connect(function()
			if config.Settings then task.spawn(config.Settings) end
		end)
	end

	local function render(fire)
		local accent = self.Library.Theme.Accent
		play(track, .10, {
			BackgroundColor3 = value and dim(accent, .65) or self.Library.Theme.ElementOverlay,
			BackgroundTransparency = value and 0 or tr(self.Library.Theme.ElementOverlayHoverAlpha),
		})
		play(knob, .10, {
			Position = value and UDim2.fromOffset(17, 4) or UDim2.fromOffset(3, 4),
			BackgroundColor3 = value and Color3.new(1, 1, 1) or self.Library.Theme.ElementOverlay,
			BackgroundTransparency = value and 0 or tr(self.Library.Theme.ElementOverlayActiveAlpha),
		})
		if fire and config.Callback then task.spawn(config.Callback, value) end
	end
	toggleHit.MouseButton1Down:Connect(function()
		entry.Row.BackgroundColor3 = self.Library.Theme.ElementClicked
		entry.Row.BackgroundTransparency = tr(self.Library.Theme.ElementClickedAlpha)
	end)
	toggleHit.MouseButton1Up:Connect(function()
		play(entry.Row, .10, {BackgroundColor3 = self.Library.Theme.Element, BackgroundTransparency = tr(self.Library.Theme.ElementHoverAlpha)})
	end)
	toggleHit.MouseButton1Click:Connect(function()
		value = not value
		render(true)
	end)
	bindAccent(self.Library, function() render(false) end)
	render(false)
	return {
		Get = function() return value end,
		Set = function(_, newValue) value = not not newValue; render(true) end,
		GetColor = function(_, index) return colors[index or 1] end,
		SetColor = function(_, index, color)
			index = index or 1
			colors[index] = color
			if swatches[index] then swatches[index].BackgroundColor3 = color end
			if config.ColorCallback then task.spawn(config.ColorCallback, index, color) end
		end,
		Instance = entry.Row,
	}
end

function Library:_popupFrame(width, height, localPosition)
	self:ClosePopup()
	local blocker = makeButton(self.PopupLayer, {
		Name = "PopupBlocker",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 100,
	})
	local popup = create("CanvasGroup", {
		Name = "Popup",
		Position = localPosition,
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = self.Theme.Popup,
		BackgroundTransparency = tr(self.Theme.PopupAlpha),
		BorderSizePixel = 0,
		GroupTransparency = 1,
		ZIndex = 101,
		Parent = self.PopupLayer,
	})
	addCorner(popup, 16)
	addStroke(popup, self.Theme.PopupOutline, self.Theme.PopupOutlineAlpha)
	local popupScale = create("UIScale", {Scale = .96, Parent = popup})
	local shadow = create("ImageLabel", {
		BackgroundTransparency = 1,
		Image = "rbxassetid://6014261993",
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = tr(140 / 255),
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(49, 49, 450, 450),
		Position = UDim2.fromOffset(-30, -30),
		Size = UDim2.new(1, 60, 1, 60),
		ZIndex = 100,
		Parent = popup,
	})
	blocker.MouseButton1Click:Connect(function() self:ClosePopup() end)
	self._popup = {Blocker = blocker, Frame = popup, Connections = {}}
	play(popup, .08, {GroupTransparency = 0})
	play(popupScale, .08, {Scale = 1})
	return popup
end

function Library:ClosePopup()
	local current = self._popup
	if not current then return end
	self._popup = nil
	for _, connection in ipairs(current.Connections or {}) do connection:Disconnect() end
	if current.Frame and current.Frame.Parent then current.Frame:Destroy() end
	if current.Blocker and current.Blocker.Parent then current.Blocker:Destroy() end
end

function Library:_popupPosition(anchor, width, height)
	local windowPosition = self.Window.AbsolutePosition
	local center = anchor.AbsolutePosition + anchor.AbsoluteSize / 2
	local x = center.X - windowPosition.X - width / 2
	local y = center.Y - windowPosition.Y - height / 2
	x = math.clamp(x, 8, math.max(8, self.Window.AbsoluteSize.X - width - 8))
	y = math.clamp(y, 8, math.max(8, self.Window.AbsoluteSize.Y - height - 8))
	return UDim2.fromOffset(x, y)
end

function Section:AddDropdown(config)
	config = config or {}
	local options = table.clone(config.Options or {})
	local value = config.Default
	if value == nil then value = options[1] end
	local entry = self:_row(config.Name or "Dropdown")
	local preview = create("Frame", {
		Name = "Preview",
		Position = UDim2.new(.5, 0, 0, 5),
		Size = UDim2.new(.5, -12, 0, 24),
		BackgroundColor3 = self.Library.Theme.ElementOverlay,
		BackgroundTransparency = tr(self.Library.Theme.ElementOverlayAlpha),
		BorderSizePixel = 0,
		ZIndex = 10,
		Parent = entry.Row,
	})
	addCorner(preview, 6)
	addStroke(preview, self.Library.Theme.ElementOverlay, self.Library.Theme.ElementOverlayHoverAlpha)
	local previewLabel = makeText(preview, tostring(value or "None"), 14, self.Library.Theme.Text, {
		Position = UDim2.fromOffset(6, 0),
		Size = UDim2.new(1, -28, 1, 0),
		TextTransparency = tr(self.Library.Theme.TextAlpha),
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 11,
	})
	makeText(preview, ICONS.Down, 14, self.Library.Theme.Text, {
		Position = UDim2.new(1, -22, 0, 0),
		Size = UDim2.fromOffset(16, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = tr(self.Library.Theme.TextAlpha),
		ZIndex = 11,
	})

	local function set(newValue, fire)
		value = newValue
		previewLabel.Text = tostring(value or "None")
		if fire and config.Callback then task.spawn(config.Callback, value) end
	end

	local function open()
		local count = math.max(1, #options)
		local height = 16 + 28 * count
		local width = math.max(160, math.floor(preview.AbsoluteSize.X * 1.6 + .5))
		local popup = self.Library:_popupFrame(width, height, self.Library:_popupPosition(preview, width, height))
		local holder = create("Frame", {
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.new(1, -16, 1, -16),
			BackgroundTransparency = 1,
			ZIndex = 102,
			Parent = popup,
		})
		create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder})
		for _, option in ipairs(options) do
			local choice = makeButton(holder, {
				Name = tostring(option),
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundColor3 = self.Library.Theme.PopupOverlay,
				BackgroundTransparency = 1,
				ZIndex = 103,
			})
			addCorner(choice, 16)
			local title = makeText(choice, tostring(option), 14, self.Library.Theme.PopupText, {
				Position = UDim2.fromOffset(2, 0),
				Size = UDim2.new(1, -26, 1, 0),
				TextTransparency = tr(self.Library.Theme.PopupTextAlpha),
				ZIndex = 104,
			})
			local check = makeText(choice, value == option and ICONS.Check or "", 12, self.Library.Theme.Accent, {
				Position = UDim2.new(1, -20, 0, 0),
				Size = UDim2.fromOffset(14, 28),
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 104,
			})
			connectHover(choice, function()
				play(choice, .1, {BackgroundTransparency = tr(self.Library.Theme.PopupOverlayHoverAlpha)})
			end, function()
				play(choice, .1, {BackgroundTransparency = 1})
			end)
			choice.MouseButton1Click:Connect(function()
				set(option, true)
				self.Library:ClosePopup()
			end)
		end
	end
	entry.Hitbox.MouseButton1Click:Connect(open)
	return {
		Get = function() return value end,
		Set = function(_, newValue) set(newValue, true) end,
		Refresh = function(_, newOptions)
			options = table.clone(newOptions or {})
			if not table.find(options, value) then set(options[1], true) end
		end,
		Instance = entry.Row,
	}
end

function Section:AddSlider(config)
	config = config or {}
	local minimum = config.Min or 0
	local maximum = config.Max or 100
	local step = math.abs(config.Step or 1)
	if step == 0 then step = 1 end
	local value = math.clamp(config.Default or minimum, minimum, maximum)
	local entry = self:_row(config.Name or "Slider")
	entry.Label.Size = UDim2.new(.5, -12, 1, 0)

	local valueText = makeText(entry.Row, "", 10, self.Library.Theme.TextDim, {
		Position = UDim2.new(1, -62, 0, 0),
		Size = UDim2.fromOffset(50, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 10,
	})
	local track = create("Frame", {
		Name = "Track",
		Position = UDim2.new(.5, 0, 1, -11),
		Size = UDim2.new(.5, -12, 0, 6),
		BackgroundColor3 = self.Library.Theme.SliderBackground,
		BackgroundTransparency = tr(self.Library.Theme.SliderBackgroundAlpha),
		BorderSizePixel = 0,
		ZIndex = 10,
		Parent = entry.Row,
	})
	addCorner(track, 6)
	local fill = create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = self.Library.Theme.Accent,
		BackgroundTransparency = .05,
		BorderSizePixel = 0,
		ZIndex = 11,
		Parent = track,
	})
	addCorner(fill, 6)
	local sliderHit = makeButton(track, {Size = UDim2.fromScale(1, 1), ZIndex = 13})
	bindAccent(self.Library, function(accent) fill.BackgroundColor3 = accent end)

	local dragging = false
	local function render(fire)
		local alpha = maximum == minimum and 0 or (value - minimum) / (maximum - minimum)
		fill.Size = UDim2.fromScale(alpha, 1)
		valueText.Text = config.Format and string.format(config.Format, value) or tostring(value)
		if fire and config.Callback then task.spawn(config.Callback, value) end
	end
	local function setFromX(x)
		local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
		local raw = minimum + (maximum - minimum) * alpha
		value = math.clamp(minimum + math.floor((raw - minimum) / step + .5) * step, minimum, maximum)
		render(true)
	end
	sliderHit.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X)
		end
	end)
	local changedConnection = UserInputService.InputChanged:Connect(function(input)
		local kind = input.UserInputType
		if dragging and (kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end)
	local endedConnection = UserInputService.InputEnded:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then dragging = false end
	end)
	table.insert(self.Library._connections, changedConnection)
	table.insert(self.Library._connections, endedConnection)
	render(false)
	return {
		Get = function() return value end,
		Set = function(_, newValue)
			value = math.clamp(minimum + math.floor((newValue - minimum) / step + .5) * step, minimum, maximum)
			render(true)
		end,
		Instance = entry.Row,
	}
end

function Library:_openColorPopup(anchor, initialColor, callback)
	local width, height = 180, 176
	local popup = self:_popupFrame(width, height, self:_popupPosition(anchor, width, height))
	local hue, saturation, value = initialColor:ToHSV()

	local sv = create("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(160, 112),
		BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 102,
		Parent = popup,
	})
	addCorner(sv, 8)
	local white = create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, ZIndex = 103, Parent = sv})
	addCorner(white, 8)
	create("UIGradient", {
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,1)}),
		Parent = white,
	})
	local black = create("Frame", {Size = UDim2.fromScale(1,1), BackgroundColor3 = Color3.new(0,0,0), BorderSizePixel=0, ZIndex=104, Parent=sv})
	addCorner(black,8)
	create("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(1,0)}),
		Parent = black,
	})
	local cursor = create("Frame", {AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(8,8),BackgroundTransparency=1,ZIndex=106,Parent=sv})
	addCorner(cursor,99); addStroke(cursor,Color3.new(1,1,1),1,1)

	local hueBar = create("Frame", {
		Position = UDim2.fromOffset(10, 132), Size = UDim2.fromOffset(160, 12),
		BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, ZIndex = 102, Parent = popup,
	})
	addCorner(hueBar, 99)
	create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(0,1,1)),
			ColorSequenceKeypoint.new(1/6, Color3.fromHSV(1/6,1,1)),
			ColorSequenceKeypoint.new(2/6, Color3.fromHSV(2/6,1,1)),
			ColorSequenceKeypoint.new(3/6, Color3.fromHSV(3/6,1,1)),
			ColorSequenceKeypoint.new(4/6, Color3.fromHSV(4/6,1,1)),
			ColorSequenceKeypoint.new(5/6, Color3.fromHSV(5/6,1,1)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(1,1,1)),
		}),
		Parent = hueBar,
	})
	local hueCursor = create("Frame", {AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(hue,.5),Size=UDim2.fromOffset(4,16),BackgroundColor3=Color3.new(1,1,1),ZIndex=104,Parent=hueBar})
	addCorner(hueCursor,99)
	local readout = makeText(popup, "", 11, self.Theme.PopupText, {Position=UDim2.fromOffset(10,150),Size=UDim2.fromOffset(160,18),TextXAlignment=Enum.TextXAlignment.Center,ZIndex=103})

	local function update(fire)
		local color = Color3.fromHSV(hue, saturation, value)
		sv.BackgroundColor3 = Color3.fromHSV(hue,1,1)
		cursor.Position = UDim2.fromScale(saturation, 1-value)
		hueCursor.Position = UDim2.fromScale(hue,.5)
		readout.Text = string.format("RGB  %d, %d, %d", math.floor(color.R*255+.5), math.floor(color.G*255+.5), math.floor(color.B*255+.5))
		if fire then callback(color) end
	end
	local svDragging, hueDragging = false, false
	local function setSV(position)
		saturation = math.clamp((position.X-sv.AbsolutePosition.X)/math.max(1,sv.AbsoluteSize.X),0,1)
		value = 1-math.clamp((position.Y-sv.AbsolutePosition.Y)/math.max(1,sv.AbsoluteSize.Y),0,1)
		update(true)
	end
	local function setHue(position)
		hue = math.clamp((position.X-hueBar.AbsolutePosition.X)/math.max(1,hueBar.AbsoluteSize.X),0,.999999)
		update(true)
	end
	sv.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then svDragging=true; setSV(input.Position) end end)
	hueBar.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then hueDragging=true; setHue(input.Position) end end)
	local changed = UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then
			if svDragging then setSV(input.Position) elseif hueDragging then setHue(input.Position) end
		end
	end)
	local ended = UserInputService.InputEnded:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then svDragging=false;hueDragging=false end end)
	if self._popup then
		table.insert(self._popup.Connections, changed)
		table.insert(self._popup.Connections, ended)
	else
		changed:Disconnect()
		ended:Disconnect()
	end
	update(false)
end

function Section:AddColorPicker(config)
	config = config or {}
	local value = config.Default or Color3.new(1, 1, 1)
	local entry = self:_row(config.Name or "Color")
	local swatch = create("Frame", {
		Name = "Color",
		Position = UDim2.new(1, -28, 0, 9),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = value,
		BorderSizePixel = 0,
		ZIndex = 10,
		Parent = entry.Row,
	})
	addCorner(swatch, 5)
	addStroke(swatch, self.Library.Theme.ElementOverlay, self.Library.Theme.ElementOverlayHoverAlpha)
	local swatchHit = makeButton(swatch, {Size = UDim2.fromScale(1, 1), ZIndex = 13})
	local function set(color, fire)
		value = color
		swatch.BackgroundColor3 = color
		if fire and config.Callback then task.spawn(config.Callback, color) end
	end
	swatchHit.MouseButton1Click:Connect(function()
		self.Library:_openColorPopup(swatch, value, function(color) set(color, true) end)
	end)
	return {Get=function() return value end, Set=function(_,color) set(color,true) end, Instance=entry.Row}
end

function Section:AddKeybind(config)
	config = config or {}
	local value = config.Default or Enum.KeyCode.Unknown
	local listening = false
	local entry = self:_row(config.Name or "Keybind")
	local key = makeText(entry.Row, value.Name, 11, self.Library.Theme.TextDim, {
		Position = UDim2.new(.5, 0, 0, 5),
		Size = UDim2.new(.5, -12, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 10,
	})
	local function set(newValue, fire)
		value = newValue
		key.Text = value.Name
		if fire and config.Callback then task.spawn(config.Callback, value) end
	end
	entry.Hitbox.MouseButton1Click:Connect(function()
		listening = true
		key.Text = "..."
	end)
	local connection = UserInputService.InputBegan:Connect(function(input)
		if listening and input.KeyCode ~= Enum.KeyCode.Unknown then
			listening = false
			set(input.KeyCode, true)
		end
	end)
	table.insert(self.Library._connections, connection)
	return {Get=function() return value end, Set=function(_,newValue) set(newValue,true) end, Instance=entry.Row}
end

Section.Toggle = Section.AddToggle
Section.Button = Section.AddButton
Section.Dropdown = Section.AddDropdown
Section.Slider = Section.AddSlider
Section.ColorPicker = Section.AddColorPicker
Section.Keybind = Section.AddKeybind
Section.Label = Section.AddLabel

function Library:SetAccent(color)
	self.Theme.Accent = color
	for _, callback in ipairs(self._accentBindings) do callback(color) end
	for _, tab in ipairs(self.Tabs) do tab:_refresh() end
end

function Library:SetVisible(visible)
	self:ClosePopup()
	visible = not not visible
	self._visible = visible
	self._visibilityToken += 1
	local token = self._visibilityToken
	if visible then
		self.Gui.Enabled = true
		self.Window.GroupTransparency = 1
		play(self.Window, .20, {GroupTransparency = 0})
	else
		local animation = play(self.Window, .20, {GroupTransparency = 1})
		animation.Completed:Once(function()
			if token == self._visibilityToken and not self._visible then self.Gui.Enabled = false end
		end)
	end
end

function Library:Toggle()
	self:SetVisible(not self._visible)
end

function Library:Notify(config)
	if type(config) == "string" then config = {Text = config} end
	config = config or {}
	local toast = create("CanvasGroup", {
		Name = "Notification",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 280, 1, -20),
		Size = UDim2.fromOffset(260, 74),
		BackgroundColor3 = self.Theme.Popup,
		BackgroundTransparency = tr(self.Theme.PopupAlpha),
		BorderSizePixel = 0,
		GroupTransparency = 0,
		ZIndex = 200,
		Parent = self.Gui,
	})
	addCorner(toast, 16)
	addStroke(toast, self.Theme.PopupOutline, self.Theme.PopupOutlineAlpha)
	makeText(toast, config.Title or "Notification", 14, self.Theme.Text, {
		Position = UDim2.fromOffset(12, 7), Size = UDim2.new(1, -24, 0, 22), Font = Enum.Font.GothamBold,
		TextTransparency = tr(self.Theme.TextAlpha), ZIndex = 201,
	})
	makeText(toast, config.Text or "", 12, self.Theme.TextDim, {
		Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -24, 0, 36), TextWrapped = true, ZIndex = 201,
	})
	play(toast, .14, {Position = UDim2.new(1, -20, 1, -20)})
	task.delay(config.Duration or 3, function()
		if not toast.Parent then return end
		local animation = play(toast, .14, {Position = UDim2.new(1, 280, 1, -20), GroupTransparency = 1})
		animation.Completed:Once(function() if toast.Parent then toast:Destroy() end end)
	end)
end

function Library:Destroy()
	self:ClosePopup()
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
	self.Gui:Destroy()
end

function Library.CreateWindow(first, second)
	return Library.new(first == Library and second or first)
end
Library.Theme = DEFAULT_THEME

return Library
