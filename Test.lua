--!nocheck
-- EvernessUI
-- Responsive Roblox/Luau reconstruction of the Alice/Everness menu with
-- Lucide atlas icons, mobile input, configs and managed notifications.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local Library = {}
Library.__index = Library
Library.Version = "2.1.0"

local Page = {}
Page.__index = Page

local Section = {}
Section.__index = Section

-- The default is Alice/Everness' own "Solid" theme.  It keeps the exact
-- source palette without depending on the native blur pass that Roblox does
-- not have. Roblox stores alpha as transparency (1 - alpha).
local DEFAULT_THEME = {
	Accent = Color3.fromRGB(120, 255, 100),
	Text = Color3.fromRGB(255, 255, 255),
	TextAlpha = 200 / 255,
	TextHover = Color3.fromRGB(200, 200, 200),
	TextDim = Color3.fromRGB(155, 155, 155),
	TextUnsafe = Color3.fromRGB(255, 199, 56),
	Category = Color3.fromRGB(255, 255, 255),
	CategoryAlpha = .5,

	Border = Color3.fromRGB(25, 25, 25),
	BorderAlpha = 1,
	Window = Color3.fromRGB(12, 12, 12),
	WindowAlpha = 1,
	SettingsOverlay = Color3.fromRGB(8, 8, 8),
	SettingsOverlayAlpha = 1,

	Tab = Color3.fromRGB(255, 255, 255),
	TabAlpha = 0,
	TabHoverAlpha = 4 / 255,
	TabActiveAlpha = 8 / 255,
	TabClickedAlpha = 16 / 255,

	Element = Color3.fromRGB(14, 14, 14),
	ElementHover = Color3.fromRGB(16, 16, 16),
	ElementAlpha = 1,
	ElementHoverAlpha = 1,
	ElementClicked = Color3.fromRGB(18, 18, 18),
	ElementClickedAlpha = 1,
	ElementOutline = Color3.fromRGB(20, 20, 20),
	ElementOutlineAlpha = 1,
	ElementOverlay = Color3.fromRGB(255, 255, 255),
	ElementOverlayAlpha = 5 / 255,
	ElementOverlayHoverAlpha = 10 / 255,
	ElementOverlayActiveAlpha = 15 / 255,
	OverlayText = Color3.fromRGB(255, 255, 255),
	OverlayTextAlpha = 96 / 255,

	Popup = Color3.fromRGB(14, 14, 14),
	PopupAlpha = 1,
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

local DEFAULT_ICON_URL = "https://raw.githubusercontent.com/AWLOID/Obscura/refs/heads/main/icons.lua"
local ICON_FALLBACKS = {
	settings = "*",
	["chevron-left"] = "<",
	["chevron-down"] = "v",
	["chevron-right"] = ">",
	save = "+",
	["triangle-alert"] = "!",
	check = "+",
	x = "x",
	menu = "=",
	grip = "+",
	info = "i",
}
local BUILTIN_ICON_FALLBACK = {
	["48px"] = {16898613044, {48, 48}, {820, 257}},
	["256px"] = {16898617944, {256, 256}, {0, 0}},
}

local ICON_ATLAS_CACHE = {}
local MEMORY_CONFIGS = {}
local CONFIG_NIL = {}

local function wrapConfigValue(value)
	return value == nil and CONFIG_NIL or value
end

local function unwrapConfigValue(value)
	if value == CONFIG_NIL then return nil end
	return value
end

local function isFiniteNumber(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function environment()
	local ok, result = pcall(function()
		return getgenv and getgenv() or _G
	end)
	return ok and type(result) == "table" and result or _G
end

local function loadIconAtlas(source)
	if type(source) == "table" then return source end
	local url = type(source) == "string" and source or DEFAULT_ICON_URL
	if ICON_ATLAS_CACHE[url] ~= nil then
		return ICON_ATLAS_CACHE[url] or nil
	end
	local sharedEnvironment = environment()
	sharedEnvironment.__EVERNESS_ICON_ATLASES = sharedEnvironment.__EVERNESS_ICON_ATLASES or {}
	if type(sharedEnvironment.__EVERNESS_ICON_ATLASES[url]) == "table" then
		ICON_ATLAS_CACHE[url] = sharedEnvironment.__EVERNESS_ICON_ATLASES[url]
		return ICON_ATLAS_CACHE[url]
	end
	local ok, atlas = pcall(function()
		local sourceCode = game:HttpGet(url)
		assert(type(sourceCode) == "string" and #sourceCode > 0 and #sourceCode <= 2097152, "Lucide atlas source has an invalid size")
		local chunk = assert(loadstring(sourceCode), "Unable to compile Lucide atlas")
		local setEnvironment = environment().setfenv or setfenv
		if type(setEnvironment) == "function" then
			local sandboxed, sandboxError = pcall(setEnvironment, chunk, {})
			assert(sandboxed, "Unable to sandbox Lucide atlas: " .. tostring(sandboxError))
		end
		return chunk()
	end)
	if not ok or type(atlas) ~= "table" or type(atlas["48px"]) ~= "table" then
		ICON_ATLAS_CACHE[url] = false
		warn("[EvernessUI] Lucide atlas could not be loaded: " .. tostring(atlas))
		return nil
	end
	ICON_ATLAS_CACHE[url] = atlas
	sharedEnvironment.__EVERNESS_ICON_ATLASES[url] = atlas
	return atlas
end

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

local function iconTweenProperties(icon, color, transparency)
	if icon:IsA("ImageLabel") or icon:IsA("ImageButton") then
		return {ImageColor3 = color, ImageTransparency = transparency or 0}
	end
	return {TextColor3 = color, TextTransparency = transparency or 0}
end

local function setIconColor(icon, color, transparency)
	if icon:IsA("ImageLabel") or icon:IsA("ImageButton") then
		icon.ImageColor3 = color
		icon.ImageTransparency = transparency or 0
	else
		icon.TextColor3 = color
		icon.TextTransparency = transparency or 0
	end
end

local makeIcon

function Library:GetIcon(name, sheetName)
	if type(name) ~= "string" then return nil, nil, nil, false end
	name = string.lower(string.match(name, "^%s*(.-)%s*$"))
	name = string.gsub(string.gsub(name, "[_%s]+", "-"), "%-+", "-")
	local requestedSheet = sheetName or self.IconSheet or "48px"
	local sheetKey = (requestedSheet == 256 or requestedSheet == "256px") and "256px" or "48px"
	local cacheKey = sheetKey .. "\0" .. name
	self._iconDescriptorCache = self._iconDescriptorCache or {}
	local cached = self._iconDescriptorCache[cacheKey]
	if cached then return cached.Image, cached.Size, cached.Offset, cached.Exact end
	local sheet = self.Icons and self.Icons[sheetKey]
	local data = sheet and sheet[name]
	local exact = type(data) == "table"
	if type(data) ~= "table" or type(data[1]) ~= "number" then data = BUILTIN_ICON_FALLBACK[sheetKey]; exact = false end
	local size = data[2]
	local offset = data[3]
	if type(size) ~= "table" or type(offset) ~= "table" or type(size[1]) ~= "number" or type(size[2]) ~= "number" or type(offset[1]) ~= "number" or type(offset[2]) ~= "number" then
		data = BUILTIN_ICON_FALLBACK[sheetKey]; size = data[2]; offset = data[3]; exact = false
	end
	local descriptor = {
		Image = "rbxassetid://" .. tostring(data[1]),
		Size = Vector2.new(size[1], size[2]),
		Offset = Vector2.new(offset[1], offset[2]),
		Exact = exact,
	}
	self._iconDescriptorCache[cacheKey] = descriptor
	return descriptor.Image, descriptor.Size, descriptor.Offset, descriptor.Exact
end

function Library:SetIconAtlas(atlas, sheetName)
	if type(atlas) == "string" then self.IconURL = atlas end
	local resolvedAtlas = type(atlas) == "table" and atlas or loadIconAtlas(atlas)
	if not resolvedAtlas then return false end
	self.Icons = resolvedAtlas
	self._iconDescriptorCache = {}
	if sheetName then self.IconSheet = sheetName end
	if self.Icons and self.Gui then
		for _, object in ipairs(self.Gui:GetDescendants()) do
			local lucideName = object:GetAttribute("LucideName")
			if lucideName and (object:IsA("ImageLabel") or object:IsA("ImageButton")) then
				self:ApplyIcon(object, lucideName, object:GetAttribute("LucideSheet"))
			end
		end
	end
	return true
end

function Library:ReloadIcons(source)
	local url = type(source) == "string" and source or self.IconURL or DEFAULT_ICON_URL
	ICON_ATLAS_CACHE[url] = nil
	local sharedEnvironment = environment()
	if type(sharedEnvironment.__EVERNESS_ICON_ATLASES) == "table" then sharedEnvironment.__EVERNESS_ICON_ATLASES[url] = nil end
	self.IconURL = url
	return self:SetIconAtlas(url)
end

function Library:GetIconDescriptor(name, sheetName)
	local image, size, offset, exact = self:GetIcon(name, sheetName)
	if not image then return nil end
	local requestedSheet = sheetName or self.IconSheet or "48px"
	local normalizedSheet = (requestedSheet == 256 or requestedSheet == "256px") and "256px" or "48px"
	return {Image = image, ImageRectSize = size, ImageRectOffset = offset, Name = name, Sheet = normalizedSheet, IsFallback = not exact}
end

function Library:ApplyIcon(imageObject, name, sheetName)
	assert(imageObject and (imageObject:IsA("ImageLabel") or imageObject:IsA("ImageButton")), "ApplyIcon expects ImageLabel or ImageButton")
	local descriptor = self:GetIconDescriptor(name, sheetName)
	if not descriptor then return false end
	imageObject.Image = descriptor.Image
	imageObject.ImageRectSize = descriptor.ImageRectSize
	imageObject.ImageRectOffset = descriptor.ImageRectOffset
	imageObject:SetAttribute("LucideName", descriptor.Name)
	imageObject:SetAttribute("LucideSheet", descriptor.Sheet)
	return true
end

function Library:CreateIcon(parent, name, options)
	options = options or {}
	return makeIcon(self, parent, name, options.Pixels or 18, options.Color or self.Theme.Text, options, options.Fallback)
end

makeIcon = function(library, parent, name, pixels, color, properties, fallback)
	local requestedSheet = properties and (properties.AtlasSize or properties.Sheet) or library.IconSheet
	local image, rectSize, rectOffset = library:GetIcon(name, requestedSheet)
	local normalizedSheet = (requestedSheet == 256 or requestedSheet == "256px") and "256px" or "48px"
	local object
	if image then
		object = create("ImageLabel", {
			Name = "Icon",
			BackgroundTransparency = 1,
			Image = image,
			ImageRectSize = rectSize,
			ImageRectOffset = rectOffset,
			ImageColor3 = color,
			ImageTransparency = 0,
			Size = UDim2.fromOffset(pixels, pixels),
			ZIndex = 2,
			Parent = parent,
		})
		object:SetAttribute("LucideName", name)
		object:SetAttribute("LucideSheet", normalizedSheet)
	else
		object = makeText(parent, fallback or ICON_FALLBACKS[name] or name or "?", pixels, color, {
			Name = "Icon",
			TextXAlignment = Enum.TextXAlignment.Center,
		})
	end
	for key, value in pairs(properties or {}) do
		if key == "AtlasSize" or key == "Sheet" or key == "Pixels" or key == "Color" or key == "Fallback" then continue end
		local mappedKey = key
		if object:IsA("TextLabel") and key == "ImageTransparency" then mappedKey = "TextTransparency" end
		if object:IsA("TextLabel") and key == "ImageColor3" then mappedKey = "TextColor3" end
		if object:IsA("ImageLabel") and key == "TextTransparency" then mappedKey = "ImageTransparency" end
		if object:IsA("ImageLabel") and key == "TextColor3" then mappedKey = "ImageColor3" end
		pcall(function() object[mappedKey] = value end)
	end
	return object
end

local function colorToHex(color, alpha)
	local red = math.clamp(math.floor(color.R * 255 + .5), 0, 255)
	local green = math.clamp(math.floor(color.G * 255 + .5), 0, 255)
	local blue = math.clamp(math.floor(color.B * 255 + .5), 0, 255)
	local result = string.format("#%02X%02X%02X", red, green, blue)
	if alpha ~= nil and alpha < .9995 then
		result ..= string.format("%02X", math.clamp(math.floor(alpha * 255 + .5), 0, 255))
	end
	return result
end

local function colorFromHex(value)
	local cleaned = string.gsub(tostring(value or ""), "[%s#]", "")
	if #cleaned ~= 6 and #cleaned ~= 8 then return nil end
	local number = tonumber(cleaned, 16)
	if not number then return nil end
	local hasAlpha = #cleaned == 8
	local alpha = hasAlpha and bit32.band(number, 0xFF) / 255 or 1
	if hasAlpha then number = bit32.rshift(number, 8) end
	local blue = bit32.band(number, 0xFF)
	local green = bit32.band(bit32.rshift(number, 8), 0xFF)
	local red = bit32.band(bit32.rshift(number, 16), 0xFF)
	return Color3.fromRGB(red, green, blue), alpha, hasAlpha
end

local function normalizeVector2(value, fallback, viewport)
	local kind = typeof(value)
	if kind == "Vector2" then
		if isFiniteNumber(value.X) and isFiniteNumber(value.Y) then return value end
		return fallback
	end
	if kind == "UDim2" then
		viewport = viewport or Vector2.new(640, 430)
		local result = Vector2.new(
			viewport.X * value.X.Scale + value.X.Offset,
			viewport.Y * value.Y.Scale + value.Y.Offset
		)
		return isFiniteNumber(result.X) and isFiniteNumber(result.Y) and result or fallback
	end
	if type(value) == "table" then
		local result = Vector2.new(
			tonumber(value.X or value.Width or value[1]) or fallback.X,
			tonumber(value.Y or value.Height or value[2]) or fallback.Y
		)
		return isFiniteNumber(result.X) and isFiniteNumber(result.Y) and result or fallback
	end
	return fallback
end

local function getViewportSize()
	local camera = Workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(1280, 720)
end

local function prefersTouchInput()
	local ok, result = pcall(function()
		return UserInputService.PreferredInput == Enum.PreferredInput.Touch
	end)
	return ok and result == true
end

local function encodeConfigValue(value, seen, depth)
	depth = (depth or 0) + 1
	if depth > 32 then error("Config value is nested too deeply") end
	if value == CONFIG_NIL then return {['$type'] = "Nil"} end
	local kind = typeof(value)
	if kind == "Color3" then
		return {['$type'] = "Color3", r = math.floor(value.R * 255 + .5), g = math.floor(value.G * 255 + .5), b = math.floor(value.B * 255 + .5)}
	elseif kind == "EnumItem" then
		local enumName = string.match(tostring(value.EnumType), "Enum%.(.+)")
		return {['$type'] = "EnumItem", enum = enumName, name = value.Name}
	elseif kind == "Vector2" then
		if not isFiniteNumber(value.X) or not isFiniteNumber(value.Y) then error("Config contains a non-finite Vector2") end
		return {['$type'] = "Vector2", x = value.X, y = value.Y}
	elseif kind == "number" then
		if not isFiniteNumber(value) then error("Config contains a non-finite number") end
		return value
	elseif kind == "table" then
		seen = seen or {}
		if seen[value] then error("Config contains a cyclic table") end
		seen[value] = true
		local result = {}
		for key, nested in pairs(value) do
			if type(key) ~= "string" and type(key) ~= "number" then error("Unsupported config key type") end
			result[key] = encodeConfigValue(nested, seen, depth)
		end
		seen[value] = nil
		return result
	elseif kind == "nil" then
		return {['$type'] = "Nil"}
	elseif kind == "string" or kind == "boolean" then
		return value
	end
	error("Unsupported config value: " .. kind)
end

local function decodeConfigValue(value, depth)
	depth = (depth or 0) + 1
	if depth > 32 then error("Config value is nested too deeply") end
	if type(value) ~= "table" then return value end
	if value['$type'] == "Nil" then
		return CONFIG_NIL
	elseif value['$type'] == "Color3" then
		return Color3.fromRGB(
			math.clamp(tonumber(value.r) or 0, 0, 255),
			math.clamp(tonumber(value.g) or 0, 0, 255),
			math.clamp(tonumber(value.b) or 0, 0, 255)
		)
	elseif value['$type'] == "EnumItem" then
		local enumType = value.enum and Enum[value.enum]
		local item = enumType and enumType[value.name]
		if not item then error("Unknown enum item in config") end
		return item
	elseif value['$type'] == "Vector2" then
		local x, y = tonumber(value.x), tonumber(value.y)
		if not isFiniteNumber(x) or not isFiniteNumber(y) then error("Config contains an invalid Vector2") end
		return Vector2.new(x, y)
	end
	local result = {}
	for key, nested in pairs(value) do result[key] = decodeConfigValue(nested, depth) end
	return result
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

local function hasInteractiveDescendantAt(root, position)
	for _, object in ipairs(root:GetDescendants()) do
		if object:IsA("GuiButton") and object.Visible then
			local topLeft = object.AbsolutePosition
			local size = object.AbsoluteSize
			if size.X > 0 and size.Y > 0
				and position.X >= topLeft.X and position.X <= topLeft.X + size.X
				and position.Y >= topLeft.Y and position.Y <= topLeft.Y + size.Y then
				return true
			end
		end
	end
	return false
end

local function makeDraggable(handle, target, connections, library)
	local dragging = false
	local capturedInput = nil
	local mouseCapture = false
	local startInput = Vector3.zero
	local startPosition = target.Position

	local began = handle.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			if capturedInput then return end
			if hasInteractiveDescendantAt(handle, input.Position) then return end
			dragging = true
			capturedInput = input
			mouseCapture = kind == Enum.UserInputType.MouseButton1
			startInput = input.Position
			startPosition = target.Position
		end
	end)

	local changed = UserInputService.InputChanged:Connect(function(input)
		local kind = input.UserInputType
		local matches = mouseCapture and kind == Enum.UserInputType.MouseMovement or input == capturedInput
		if dragging and matches then
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
		if input == capturedInput or mouseCapture and kind == Enum.UserInputType.MouseButton1 then
			dragging = false
			capturedInput = nil
			mouseCapture = false
			if library and library._clampWindow then
				task.defer(function() library:_clampToViewport() end)
			end
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
	self.IconSheet = config.IconSheet or "48px"
	self.IconURL = config.IconURL or DEFAULT_ICON_URL
	if config.LoadIcons == false then
		self.Icons = config.Icons
	else
		self.Icons = loadIconAtlas(config.Icons or self.IconURL)
	end
	self.Tabs = {}
	self.Categories = {}
	self._connections = {}
	self._accentBindings = {}
	self._flags = {}
	self._pendingFlags = {}
	self._pendingFlagSilent = {}
	self._configListeners = {}
	self._memoryConfigs = MEMORY_CONFIGS
	self._configOptions = config.Configs or {}
	self._configFolder = self._configOptions.Folder or config.ConfigFolder or "EvernessUI/configs"
	self._configExtension = self._configOptions.Extension or ".json"
	if string.sub(self._configExtension, 1, 1) ~= "." then self._configExtension = "." .. self._configExtension end
	self._autoSave = self._configOptions.AutoSave or config.AutoSave
	self._defaultConfigName = self._configOptions.DefaultName or config.DefaultConfig or "default"
	self._activeConfigName = self._defaultConfigName
	self._autoSaveToken = 0
	self._selectedTab = nil
	self._selectedPage = nil
	self._popup = nil
	self._visible = true
	self._visibilityToken = 0
	self._responsive = type(config.Responsive) == "table" and config.Responsive or {}
	self._responsiveEnabled = config.Responsive ~= false and self._responsive.Enabled ~= false
	self._layoutMode = self._responsive.Mode or "auto"
	self._requestedSize = normalizeVector2(config.Size, Vector2.new(680, 460), getViewportSize())
	self._positionWasConfigured = config.Position ~= nil
	self._minimumSize = normalizeVector2(config.MinSize or self._responsive.MinSize, Vector2.new(360, 320), getViewportSize())
	self._maximumSize = normalizeVector2(config.MaxSize or self._responsive.MaxSize, Vector2.new(1100, 760), getViewportSize())
	self._desktopSidebarWidth = tonumber(config.SidebarWidth) or 180
	self._clampWindow = config.ClampToViewport == true or self._responsive.ClampToViewport == true
	self._compactSidebarWidth = tonumber(self._responsive.CompactSidebarWidth) or 58
	if type(config.MobileToggle) == "table" then
		self._mobileLauncherEnabled = config.MobileToggle.Enabled ~= false
	else
		self._mobileLauncherEnabled = config.MobileToggle ~= false
	end
	self._resizable = config.Resizable ~= false and self._responsive.AllowResize ~= false
	self._mobile = false
	self._touchMode = prefersTouchInput()
	self._lastInputWasTouch = self._touchMode
	self._stacked = false
	self._currentSidebarWidth = self._desktopSidebarWidth
	self._notificationOptions = config.Notifications or {}
	self._notificationQueue = {}
	self._visibleNotifications = {}
	self._notificationsByKey = {}
	self._notificationSequence = 0

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
		Size = UDim2.fromOffset(self._requestedSize.X, self._requestedSize.Y),
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

	local rightOutline = create("Frame", {
		Name = "OverlayOutline",
		Position = UDim2.fromOffset(self._desktopSidebarWidth, 0),
		Size = UDim2.new(1, -self._desktopSidebarWidth, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = window,
	})
	addCorner(rightOutline, 12)
	addStroke(rightOutline, self.Theme.Border, self.Theme.BorderAlpha)
	self.RightOutline = rightOutline

	local sidebar = create("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, self._desktopSidebarWidth, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = window,
	})
	self.Sidebar = sidebar

	local logoArea = create("Frame", {
		Name = "LogoArea",
		Size = UDim2.fromOffset(self._desktopSidebarWidth, 80),
		BackgroundTransparency = 1,
		Active = true,
		ZIndex = 2,
		Parent = sidebar,
	})
	self.LogoArea = logoArea

	local logo
	if config.LogoImage then
		logo = create("ImageLabel", {
			Name = "Logo",
			AnchorPoint = Vector2.new(.5, .5),
			Position = UDim2.new(.5, 0, .5, 10),
			Size = UDim2.fromOffset(80, 80),
			BackgroundTransparency = 1,
			Image = config.LogoImage,
			ImageColor3 = config.LogoColor or self.Theme.Text,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 3,
			Parent = logoArea,
		})
	else
		logo = makeText(logoArea, config.LogoText ~= nil and config.LogoText or config.Name or "", 15, config.LogoColor or self.Theme.Text, {
			Name = "Logo",
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -28, 1, 0),
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 3,
		})
	end
	self.Logo = logo
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
		Position = UDim2.fromOffset(self._desktopSidebarWidth + 1, 1),
		Size = UDim2.new(1, -self._desktopSidebarWidth - 1, 0, 48),
		BackgroundTransparency = 1,
		Active = true,
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
		Position = UDim2.fromOffset(self._desktopSidebarWidth, 50),
		Size = UDim2.new(1, -self._desktopSidebarWidth, 0, 1),
		BackgroundColor3 = self.Theme.Border,
		BackgroundTransparency = tr(self.Theme.BorderAlpha),
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = window,
	})
	self.Separator = separator

	local pages = create("Frame", {
		Name = "MainArea",
		Position = UDim2.fromOffset(self._desktopSidebarWidth + 1, 51),
		Size = UDim2.new(1, -self._desktopSidebarWidth - 1, 1, -51),
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
	local gearIcon = makeIcon(self, gear, "settings", 16, self.Theme.TextDim, {
		AnchorPoint = Vector2.new(.5, .5),
		Position = UDim2.fromScale(.5, .5),
		Size = UDim2.fromOffset(16, 16),
		ZIndex = 11,
	})
	connectHover(gear, function()
		play(gearIcon, .10, iconTweenProperties(gearIcon, self.Theme.Text, tr(self.Theme.TextAlpha)))
	end, function()
		play(gearIcon, .10, iconTweenProperties(gearIcon, self.Theme.TextDim, 0))
	end)
	gear.Activated:Connect(function()
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

	self:_createConfigFacade()
	self:_createNotificationHost()
	self:_createMobileLauncher()
	self:_createResizeHandle()
	self:_buildSettings()
	makeDraggable(logoArea, window, self._connections, self)
	makeDraggable(topArea, window, self._connections, self)

	table.insert(self._connections, UserInputService.InputBegan:Connect(function(input, processed)
		local kind = input.UserInputType
		local inputTouch = kind == Enum.UserInputType.Touch
		local inputMouse = kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.MouseButton2
		if inputTouch or inputMouse then
			local nextTouch = inputTouch
			if nextTouch ~= self._lastInputWasTouch then
				self._lastInputWasTouch = nextTouch
				task.defer(function() self:_applyResponsive() end)
			end
		end
		if not processed and input.KeyCode == self.ToggleKey then
			self:Toggle()
		end
	end))
	local preferredInputOk, preferredInputSignal = pcall(function()
		return UserInputService:GetPropertyChangedSignal("PreferredInput")
	end)
	if preferredInputOk then
		table.insert(self._connections, preferredInputSignal:Connect(function()
			local nextTouch = prefersTouchInput()
			if nextTouch ~= self._lastInputWasTouch then
				self._lastInputWasTouch = nextTouch
				self:_applyResponsive()
			end
		end))
	end
	table.insert(self._connections, RunService.RenderStepped:Connect(function()
		local viewport = getViewportSize()
		if self._lastViewport ~= viewport then
			self._lastViewport = viewport
			self:_applyResponsive()
		end
	end))

	self:_applyResponsive(true)

	return self
end

function Library:_createNotificationHost()
	local host = create("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(.5, .5),
		Position = UDim2.fromScale(.5, .5),
		Size = UDim2.fromOffset(260, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 200,
		Parent = self.Gui,
	})
	local layout = create("UIListLayout", {
		Padding = UDim.new(0, tonumber(self._notificationOptions.Gap) or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = host,
	})
	self.NotificationHost = host
	self.NotificationLayout = layout
	local owner = self
	self.Notifications = {
		Push = function(_, config) return owner:Notify(config) end,
		Clear = function(_, reason) return owner:ClearNotifications(reason) end,
		PauseAll = function() for _, handle in ipairs(owner._visibleNotifications) do handle:Pause() end end,
		ResumeAll = function() for _, handle in ipairs(owner._visibleNotifications) do handle:Resume() end end,
	}
end

function Library:_createMobileLauncher()
	local button = makeButton(self.Gui, {
		Name = "MobileLauncher",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -14),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = self.Theme.Popup,
		BackgroundTransparency = tr(self.Theme.PopupAlpha),
		Visible = false,
		ZIndex = 300,
	})
	addCorner(button, 14)
	addStroke(button, self.Theme.PopupOutline, math.max(self.Theme.PopupOutlineAlpha, .14))
	local icon = makeIcon(self, button, "menu", 20, self.Theme.Text, {
		AnchorPoint = Vector2.new(.5, .5),
		Position = UDim2.fromScale(.5, .5),
		Size = UDim2.fromOffset(20, 20),
		ZIndex = 301,
	})
	button.Activated:Connect(function() self:Toggle() end)
	self.MobileLauncher = button
	self.MobileLauncherIcon = icon
end

function Library:_createResizeHandle()
	local handle = makeButton(self.Window, {
		Name = "ResizeHandle",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(28, 28),
		ZIndex = 90,
	})
	makeIcon(self, handle, "grip", 14, self.Theme.TextDim, {
		AnchorPoint = Vector2.new(.5, .5),
		Position = UDim2.fromScale(.5, .5),
		Size = UDim2.fromOffset(14, 14),
		Rotation = -45,
		ZIndex = 91,
	})
	local capturedInput
	local mouseCapture = false
	local startPosition = Vector3.zero
	local startSize = self._requestedSize
	local startTopLeft = Vector2.zero
	local began = handle.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then return end
		if capturedInput then return end
		capturedInput = input
		mouseCapture = kind == Enum.UserInputType.MouseButton1
		startPosition = input.Position
		startSize = self._requestedSize
		startTopLeft = self.Window.AbsolutePosition
	end)
	local changed = UserInputService.InputChanged:Connect(function(input)
		if not capturedInput then return end
		local matches = mouseCapture and input.UserInputType == Enum.UserInputType.MouseMovement or input == capturedInput
		if not matches then return end
		local delta = input.Position - startPosition
		self:SetSize(startSize + Vector2.new(delta.X, delta.Y) / math.max(self.Scale.Scale, .01))
		local absoluteSize = self.Window.AbsoluteSize
		self.Window.Position = UDim2.fromOffset(
			startTopLeft.X + absoluteSize.X * self.Window.AnchorPoint.X,
			startTopLeft.Y + absoluteSize.Y * self.Window.AnchorPoint.Y
		)
	end)
	local ended = UserInputService.InputEnded:Connect(function(input)
		if input == capturedInput or mouseCapture and input.UserInputType == Enum.UserInputType.MouseButton1 then
			capturedInput = nil
			mouseCapture = false
		end
	end)
	table.insert(self._connections, began)
	table.insert(self._connections, changed)
	table.insert(self._connections, ended)
	self.ResizeHandle = handle
end

function Library:Center()
	local viewport = getViewportSize()
	local topLeft, bottomRight = Vector2.zero, Vector2.zero
	local ok, first, second = pcall(function() return GuiService:GetGuiInset() end)
	if ok then topLeft, bottomRight = first, second end
	self.Window.Position = UDim2.fromOffset(
		topLeft.X + (viewport.X - topLeft.X - bottomRight.X) / 2,
		topLeft.Y + (viewport.Y - topLeft.Y - bottomRight.Y) / 2
	)
	return self
end

function Library:_clampToViewport()
	if not self.Window or not self.Window.Parent then return end
	local viewport = getViewportSize()
	local margin = tonumber(self._responsive.Margin) or 10
	local safeTopLeft, safeBottomRight = Vector2.zero, Vector2.zero
	local ok, first, second = pcall(function() return GuiService:GetGuiInset() end)
	if ok then safeTopLeft, safeBottomRight = first, second end
	local topLeft = self.Window.AbsolutePosition
	local size = self.Window.AbsoluteSize
	local minX, minY = safeTopLeft.X + margin, safeTopLeft.Y + margin
	local x = math.clamp(topLeft.X, minX, math.max(minX, viewport.X - safeBottomRight.X - size.X - margin))
	local y = math.clamp(topLeft.Y, minY, math.max(minY, viewport.Y - safeBottomRight.Y - size.Y - margin))
	if math.abs(x - topLeft.X) > .5 or math.abs(y - topLeft.Y) > .5 then
		self.Window.Position = UDim2.fromOffset(x + size.X * self.Window.AnchorPoint.X, y + size.Y * self.Window.AnchorPoint.Y)
	end
end

function Library:_applyResponsive(initial)
	if not self.Window then return end
	local viewport = getViewportSize()
	local scale = math.max(self.Scale.Scale, .01)
	local margin = tonumber(self._responsive.Margin) or 10
	local safeTopLeft, safeBottomRight = Vector2.zero, Vector2.zero
	local insetOk, first, second = pcall(function() return GuiService:GetGuiInset() end)
	if insetOk then safeTopLeft, safeBottomRight = first, second end
	local available = Vector2.new(
		math.max(240, (viewport.X - safeTopLeft.X - safeBottomRight.X) / scale - margin * 2),
		math.max(240, (viewport.Y - safeTopLeft.Y - safeBottomRight.Y) / scale - margin * 2)
	)
	local minimum = Vector2.new(math.min(self._minimumSize.X, available.X), math.min(self._minimumSize.Y, available.Y))
	local maximum = Vector2.new(
		math.max(minimum.X, math.min(self._maximumSize.X, available.X)),
		math.max(minimum.Y, math.min(self._maximumSize.Y, available.Y))
	)
	local actual
	if self._responsiveEnabled then
		actual = Vector2.new(
			math.clamp(self._requestedSize.X, minimum.X, maximum.X),
			math.clamp(self._requestedSize.Y, minimum.Y, maximum.Y)
		)
	else
		actual = Vector2.new(
			math.clamp(self._requestedSize.X, self._minimumSize.X, self._maximumSize.X),
			math.clamp(self._requestedSize.Y, self._minimumSize.Y, self._maximumSize.Y)
		)
	end
	self._actualSize = actual
	self.Window.Size = UDim2.fromOffset(actual.X, actual.Y)

	local mobileBreakpoint = tonumber(self._responsive.MobileBreakpoint) or 560
	local compactBreakpoint = tonumber(self._responsive.CompactBreakpoint) or 760
	local mode = self._layoutMode
	local touchMode = self._lastInputWasTouch or prefersTouchInput()
	local mobile = mode == "mobile" or mode == "auto" and (
		viewport.X <= mobileBreakpoint or touchMode and viewport.Y <= 500
	)
	local compact = mobile or mode == "compact" or mode == "auto" and (viewport.X <= compactBreakpoint or actual.X < 560)
	if not self._responsiveEnabled and mode == "auto" then mobile, compact = false, false end
	if mode == "desktop" then mobile, compact = false, false end
	touchMode = mobile or self._lastInputWasTouch or prefersTouchInput()
	local sidebarWidth = compact and self._compactSidebarWidth or self._desktopSidebarWidth
	local stacked = mobile or actual.X - sidebarWidth < 430
	local layoutChanged = mobile ~= self._mobile or touchMode ~= self._touchMode or stacked ~= self._stacked or sidebarWidth ~= self._currentSidebarWidth
	self._mobile = mobile
	self._touchMode = touchMode
	self._stacked = stacked
	self._currentSidebarWidth = sidebarWidth
	local topBarHeight = touchMode and 44 or 28
	self.TopContent.Position = UDim2.fromOffset(10, touchMode and 2 or 10)
	self.TopContent.Size = UDim2.new(1, -20, 0, topBarHeight)
	self.Gear.Position = UDim2.new(1, -topBarHeight, 0, 0)
	self.Gear.Size = UDim2.fromOffset(topBarHeight, topBarHeight)
	if self.SettingsBack then
		self.SettingsBack.Position = UDim2.new(1, touchMode and -48 or -38, 0, touchMode and 2 or 10)
		self.SettingsBack.Size = UDim2.fromOffset(touchMode and 44 or 28, touchMode and 44 or 28)
	end

	self.Sidebar.Size = UDim2.new(0, sidebarWidth, 1, 0)
	self.LogoArea.Size = UDim2.fromOffset(sidebarWidth, 80)
	self.LogoArea.Visible = not compact
	self.Navigation.Position = UDim2.fromOffset(0, compact and 10 or 80)
	self.Navigation.Size = UDim2.new(1, 0, 1, compact and -20 or -80)
	self.RightOutline.Position = UDim2.fromOffset(sidebarWidth, 0)
	self.RightOutline.Size = UDim2.new(1, -sidebarWidth, 1, 0)
	self.TopArea.Position = UDim2.fromOffset(sidebarWidth + 1, 1)
	self.TopArea.Size = UDim2.new(1, -sidebarWidth - 1, 0, 48)
	self.Separator.Position = UDim2.fromOffset(sidebarWidth, 50)
	self.Separator.Size = UDim2.new(1, -sidebarWidth, 0, 1)
	self.Pages.Position = UDim2.fromOffset(sidebarWidth + 1, 51)
	self.Pages.Size = UDim2.new(1, -sidebarWidth - 1, 1, -51)
	if self.SettingsOverlay then
		self.SettingsOverlay.Position = UDim2.fromOffset(sidebarWidth, 0)
		self.SettingsOverlay.Size = UDim2.new(1, -sidebarWidth, 1, 0)
	end
	if self.SettingsPanel then
		local settingsInset = compact and 0 or math.min(180, math.max(0, actual.X - sidebarWidth - 280))
		self.SettingsPanel.Position = UDim2.fromOffset(settingsInset, 0)
		self.SettingsPanel.Size = UDim2.new(1, -settingsInset, 1, 0)
	end

	for _, category in ipairs(self.Categories or {}) do
		category.Slot.Visible = not compact
	end
	for _, tab in ipairs(self.Tabs) do
		tab.NavSlot.Size = UDim2.new(1, 0, 0, touchMode and 44 or 32)
		tab.Button.Position = UDim2.fromOffset(compact and 7 or 10, 0)
		tab.Button.Size = compact and UDim2.fromOffset(44, touchMode and 44 or 32) or UDim2.new(1, -20, 1, 0)
		tab.Label.Visible = not compact
		local imageIcon = tab.IconLabel:IsA("ImageLabel") or tab.IconLabel:IsA("ImageButton")
		if compact then
			tab.IconLabel.Position = UDim2.fromScale(.5, .5)
			tab.IconLabel.AnchorPoint = Vector2.new(.5, .5)
			tab.IconLabel.Size = UDim2.fromOffset(18, 18)
		else
			tab.IconLabel.AnchorPoint = Vector2.zero
			tab.IconLabel.Position = imageIcon and UDim2.fromOffset(12, 8) or UDim2.fromOffset(10, 0)
			tab.IconLabel.Size = imageIcon and UDim2.fromOffset(16, 16) or UDim2.fromOffset(20, 32)
		end
	end

	for _, tab in ipairs(self.Tabs) do
		for _, page in ipairs(tab.Pages) do
			for _, section in ipairs(page.Sections) do section:_refreshRows() end
			page:_applyColumns()
		end
	end
	if self._settingsRows then
		local rowHeight = touchMode and 44 or 34
		for index, row in ipairs(self._settingsRows) do
			row.Position = UDim2.fromOffset(0, (index - 1) * rowHeight)
			row.Size = UDim2.new(1, 0, 0, rowHeight)
		end
		local group = self._settingsRows[1] and self._settingsRows[1].Parent
		if group then group.Size = UDim2.new(1, 0, 0, rowHeight * #self._settingsRows) end
	end

	if self.ResizeHandle then
		self.ResizeHandle.Visible = self._resizable
		self.ResizeHandle.Size = UDim2.fromOffset(touchMode and 44 or 28, touchMode and 44 or 28)
	end
	if self.MobileLauncher then
		self.MobileLauncher.Visible = self._mobileLauncherEnabled and touchMode
		self.MobileLauncher.Position = UDim2.new(1, -(safeBottomRight.X + margin), 1, -(safeBottomRight.Y + margin))
		setIconColor(self.MobileLauncherIcon, self.Theme.Text, 0)
	end
	if self.NotificationHost then
		local width = math.min(tonumber(self._notificationOptions.Width) or 260, viewport.X - margin * 2)
		self.NotificationHost.Size = UDim2.fromOffset(math.max(160, width), 0)
		self.NotificationHost.AnchorPoint = Vector2.new(.5, .5)
		self.NotificationHost.Position = UDim2.fromScale(.5, .5)
		self.NotificationLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		self.NotificationLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	end

	if layoutChanged and self._selectedTab then self:_rebuildTopbar(self._selectedTab) end
	if layoutChanged then self:ClosePopup() end
	if self.NotificationHost then self:_syncNotifications() end
	if initial and not self._positionWasConfigured then self:Center() end
	if self._clampWindow then task.defer(function() self:_clampToViewport() end) end
end

function Library:SetSize(value)
	self._requestedSize = normalizeVector2(value, self._requestedSize, getViewportSize())
	self:_applyResponsive()
	return self
end

function Library:GetRequestedSize()
	return self._requestedSize
end

function Library:GetActualSize()
	return self._actualSize or Vector2.new(self.Window.AbsoluteSize.X, self.Window.AbsoluteSize.Y)
end

function Library:GetSize()
	return self:GetActualSize()
end

function Library:SetScale(value)
	self.Scale.Scale = math.clamp(tonumber(value) or 1, .65, 1.5)
	self:_applyResponsive()
	return self
end

function Library:SetClampToViewport(enabled)
	self._clampWindow = enabled == true
	if self._clampWindow then self:_clampToViewport() end
	return self
end

function Library:GetClampToViewport()
	return self._clampWindow
end

function Library:SetLayoutMode(mode)
	mode = string.lower(tostring(mode or "auto"))
	assert(mode == "auto" or mode == "desktop" or mode == "compact" or mode == "mobile", "Unknown layout mode")
	self._layoutMode = mode
	self:_applyResponsive()
	return self
end

function Library:GetLayoutMode()
	return self._mobile and "mobile" or self._currentSidebarWidth == self._compactSidebarWidth and "compact" or "desktop"
end

function Library:_createConfigFacade()
	local owner = self
	self.Configs = {
		GetFlag = function(_, ...) return owner:GetFlag(...) end,
		SetFlag = function(_, ...) return owner:SetFlag(...) end,
		ResetFlag = function(_, ...) return owner:ResetFlag(...) end,
		ResetAll = function(_, ...) return owner:ResetAll(...) end,
		Serialize = function(_, ...) return owner:ExportConfig(...) end,
		Apply = function(_, ...) return owner:ImportConfig(...) end,
		Save = function(_, ...) return owner:SaveConfig(...) end,
		Load = function(_, ...) return owner:LoadConfig(...) end,
		List = function(_, ...) return owner:ListConfigs(...) end,
		Delete = function(_, ...) return owner:DeleteConfig(...) end,
		GetCapabilities = function() return owner:GetConfigCapabilities() end,
		OnChanged = function(_, callback) return owner:OnConfigChanged(callback) end,
	}
end

function Library:_registerFlag(config, handle, kind)
	local flag = config and (config.Flag or config.Id)
	if not flag then return handle end
	flag = tostring(flag)
	assert(flag ~= "", "Flag cannot be empty")
	assert(not self._flags[flag], "Duplicate EvernessUI flag: " .. flag)
	handle.Flag = flag
	handle.Kind = kind
	handle.Default = handle.Export and handle:Export() or handle:Get()
	self._flags[flag] = handle
	if self._pendingFlags[flag] ~= nil then
		local pending = self._pendingFlags[flag]
		local ok, err = pcall(function()
			local value = unwrapConfigValue(pending)
			if handle.Import then handle:Import(value, false, "config") else handle:Set(value, false, "config") end
		end)
		if ok then
			self._pendingFlags[flag] = nil
			local silent = self._pendingFlagSilent[flag]
			self._pendingFlagSilent[flag] = nil
			if not silent then
				if handle.Fire then handle:Fire("config") end
				self:_controlChanged(flag, handle.Export and handle:Export() or handle:Get(), "config")
			end
		else
			warn("[EvernessUI] Pending flag '" .. flag .. "' was rejected: " .. tostring(err))
		end
	end
	return handle
end

function Library:_controlChanged(flag, value, source)
	if not flag then return end
	flag = tostring(flag)
	local handle = self._flags[flag]
	if handle then value = handle.Export and handle:Export() or handle:Get() end
	for _, callback in ipairs(self._configListeners) do
		task.spawn(callback, flag, value, source or "user")
	end
	if self._autoSave and self._activeConfigName and source ~= "config" and source ~= "reset" and source ~= "init" and not self._suspendAutoSave then
		self._autoSaveToken += 1
		local token = self._autoSaveToken
		local delaySeconds = type(self._autoSave) == "number" and math.max(.1, self._autoSave) or .6
		task.delay(delaySeconds, function()
			if token == self._autoSaveToken and not self._destroyed then
				self:SaveConfig(self._activeConfigName or self._defaultConfigName)
			end
		end)
	end
end

function Library:OnConfigChanged(callback)
	assert(type(callback) == "function", "OnConfigChanged expects a function")
	table.insert(self._configListeners, callback)
	local connected = true
	return {
		Disconnect = function()
			if not connected then return end
			connected = false
			local index = table.find(self._configListeners, callback)
			if index then table.remove(self._configListeners, index) end
		end,
	}
end

function Library:GetFlag(flag)
	local handle = self._flags[tostring(flag)]
	if not handle then return nil end
	if handle.Export then return handle:Export() end
	return handle:Get()
end

function Library:SetFlag(flag, value, options)
	local handle = self._flags[tostring(flag)]
	if not handle then return false, "Unknown flag: " .. tostring(flag) end
	options = options or {}
	local fire = options.Silent ~= true
	local source = options.Source or "api"
	local ok, err = pcall(function()
		if handle.Import then handle:Import(value, fire, source) else handle:Set(value, fire, source) end
	end)
	if not ok then return false, tostring(err) end
	if handle.Export then return true, handle:Export() end
	return true, handle:Get()
end

function Library:ResetFlag(flag, fire)
	local handle = self._flags[tostring(flag)]
	if not handle then return false, "Unknown flag: " .. tostring(flag) end
	local value = unwrapConfigValue(decodeConfigValue(encodeConfigValue(handle.Default)))
	if handle.Import then handle:Import(value, fire ~= false, "reset") else handle:Set(value, fire ~= false, "reset") end
	return true
end

function Library:ResetAll(fire)
	for flag in pairs(self._flags) do self:ResetFlag(flag, fire) end
	return true
end

function Library:GetConfigData(options)
	options = options or {}
	local flags = {}
	for flag, handle in pairs(self._flags) do
		local raw = handle.Export and handle:Export() or handle:Get()
		flags[flag] = encodeConfigValue(raw)
	end
	if options.PreserveUnknown ~= false and self._configOptions.PreserveUnknown ~= false then
		for flag, value in pairs(self._pendingFlags) do
			if flags[flag] == nil then flags[flag] = encodeConfigValue(value) end
		end
	end
	local data = {
		schema = "EvernessUI.Config",
		formatVersion = 1,
		configVersion = tonumber(self._configOptions.Version) or 1,
		savedAt = os.time(),
		flags = flags,
	}
	if options.IncludeUIState ~= false and self._configOptions.IncludeUIState ~= false then
		data.ui = {
			accent = encodeConfigValue(self.Theme.Accent),
			size = encodeConfigValue(self._requestedSize),
			scale = self.Scale.Scale,
			layout = self._layoutMode,
			clampToViewport = self._clampWindow,
		}
	end
	return data
end

function Library:ExportConfig(options)
	local ok, result = pcall(function() return HttpService:JSONEncode(self:GetConfigData(options)) end)
	if ok then return result, nil end
	return nil, tostring(result)
end

function Library:ApplyConfig(data, options)
	options = options or {}
	if type(options) == "boolean" then options = {Silent = not options} end
	local decoded = data
	if type(data) == "string" then
		if #data > (tonumber(self._configOptions.MaxImportBytes) or 1048576) then return false, "Config is too large" end
		local ok, result = pcall(function() return HttpService:JSONDecode(data) end)
		if not ok then return false, "Invalid JSON: " .. tostring(result) end
		decoded = result
	end
	if type(decoded) ~= "table" then return false, "Config must be a table or JSON string" end
	if decoded.schema and decoded.schema ~= "EvernessUI.Config" then return false, "Unsupported config schema" end
	if decoded.formatVersion and tonumber(decoded.formatVersion) ~= 1 then return false, "Unsupported config format version" end
	local isEnvelope = decoded.schema ~= nil or decoded.formatVersion ~= nil or decoded.configVersion ~= nil
		or decoded.savedAt ~= nil or decoded.flags ~= nil or decoded.Flags ~= nil or decoded.values ~= nil or decoded.Values ~= nil
	local sourceFlags
	if isEnvelope then
		sourceFlags = decoded.flags or decoded.Flags or decoded.values or decoded.Values
	else
		sourceFlags = decoded
	end
	if type(sourceFlags) ~= "table" then return false, "Config flags are missing" end
	local sourceVersion = decoded.configVersion == nil and 1 or tonumber(decoded.configVersion)
	local targetVersion = tonumber(self._configOptions.Version) or 1
	if not sourceVersion or sourceVersion ~= math.floor(sourceVersion) or sourceVersion < 1 or sourceVersion > 10000 then
		return false, "Invalid config version"
	end
	if targetVersion ~= math.floor(targetVersion) or targetVersion < 1 or targetVersion > 10000 then
		return false, "Invalid target config version"
	end
	if sourceVersion > targetVersion then return false, "Config was created by a newer version" end
	if targetVersion - sourceVersion > 100 then return false, "Config requires too many migration steps" end
	if sourceVersion < targetVersion and type(self._configOptions.Migrations) == "table" then
		local cloneOk, cloned = pcall(function() return HttpService:JSONDecode(HttpService:JSONEncode(sourceFlags)) end)
		if not cloneOk then return false, "Config cannot be cloned for migration" end
		sourceFlags = cloned
		for version = sourceVersion, targetVersion - 1 do
			local migration = self._configOptions.Migrations[version]
			if not migration then return false, "Missing config migration " .. version end
			local ok, migrated = pcall(migration, sourceFlags)
			if not ok then return false, "Config migration " .. version .. " failed: " .. tostring(migrated) end
			if type(migrated) == "table" then sourceFlags = migrated end
		end
	elseif sourceVersion < targetVersion then
		return false, "Config requires migrations"
	end

	local stagedUI
	local shouldApplyUI = decoded.ui ~= nil and options.IncludeUIState ~= false and self._configOptions.IncludeUIState ~= false
	if shouldApplyUI then
		if type(decoded.ui) ~= "table" then return false, "Config UI state must be a table" end
		stagedUI = {}
		if decoded.ui.accent ~= nil then
			local ok, accent = pcall(decodeConfigValue, decoded.ui.accent)
			if not ok or typeof(accent) ~= "Color3" then return false, "Invalid UI accent" end
			stagedUI.Accent = accent
		end
		if decoded.ui.size ~= nil then
			local ok, size = pcall(decodeConfigValue, decoded.ui.size)
			if not ok or typeof(size) ~= "Vector2" or not isFiniteNumber(size.X) or not isFiniteNumber(size.Y) then return false, "Invalid UI size" end
			stagedUI.Size = size
		end
		if decoded.ui.scale ~= nil then
			local scale = tonumber(decoded.ui.scale)
			if not scale or scale ~= scale or scale == math.huge or scale == -math.huge then return false, "Invalid UI scale" end
			stagedUI.Scale = scale
		end
		if decoded.ui.layout ~= nil then
			local layout = string.lower(tostring(decoded.ui.layout))
			if layout ~= "auto" and layout ~= "desktop" and layout ~= "compact" and layout ~= "mobile" then return false, "Invalid UI layout" end
			stagedUI.Layout = layout
		end
		if decoded.ui.clampToViewport ~= nil then
			if type(decoded.ui.clampToViewport) ~= "boolean" then return false, "Invalid viewport clamp setting" end
			stagedUI.ClampToViewport = decoded.ui.clampToViewport
		end
	end

	local changes = {}
	local seenFlags = {}
	local previousPending = self._pendingFlags
	local previousPendingSilent = self._pendingFlagSilent
	local previousUI = {Accent = self.Theme.Accent, Size = self._requestedSize, Scale = self.Scale.Scale, Layout = self._layoutMode, ClampToViewport = self._clampWindow}
	local stagedPending = options.MergePending and table.clone(self._pendingFlags) or {}
	local stagedPendingSilent = options.MergePending and table.clone(self._pendingFlagSilent) or {}
	for flag, encoded in pairs(sourceFlags) do
		seenFlags[tostring(flag)] = true
		local ok, value = pcall(decodeConfigValue, encoded)
		if not ok then return false, "Invalid flag '" .. tostring(flag) .. "': " .. tostring(value) end
		local handle = self._flags[tostring(flag)]
		if handle then
			local previous = handle.Export and handle:Export() or handle:Get()
			table.insert(changes, {Flag = tostring(flag), Handle = handle, Value = value, Previous = wrapConfigValue(previous)})
		elseif options.PreserveUnknown ~= false and self._configOptions.PreserveUnknown ~= false then
			stagedPending[tostring(flag)] = value
			stagedPendingSilent[tostring(flag)] = options.Silent == true
		end
	end
	if options.ResetMissing then
		for flag, handle in pairs(self._flags) do
			if not seenFlags[flag] then
				table.insert(changes, {
					Flag = flag,
					Handle = handle,
					Value = decodeConfigValue(encodeConfigValue(handle.Default)),
					Previous = wrapConfigValue(handle.Export and handle:Export() or handle:Get()),
				})
			end
		end
	end

	local applied = {}
	for _, change in ipairs(changes) do
		local ok, err = pcall(function()
			local value = unwrapConfigValue(change.Value)
			if change.Handle.Import then change.Handle:Import(value, false, "config") else change.Handle:Set(value, false, "config") end
		end)
		if not ok then
			for index = #applied, 1, -1 do
				local rollback = applied[index]
				pcall(function()
					local value = unwrapConfigValue(rollback.Previous)
					if rollback.Handle.Import then rollback.Handle:Import(value, false, "rollback") else rollback.Handle:Set(value, false, "rollback") end
				end)
			end
			return false, "Flag '" .. change.Flag .. "' was rejected: " .. tostring(err)
		end
		table.insert(applied, change)
	end
	self._pendingFlags = stagedPending
	self._pendingFlagSilent = stagedPendingSilent

	if stagedUI then
		local uiOk, uiError = pcall(function()
			if stagedUI.Accent then self:SetAccent(stagedUI.Accent) end
			if stagedUI.Size then self:SetSize(stagedUI.Size) end
			if stagedUI.Scale then self:SetScale(stagedUI.Scale) end
			if stagedUI.Layout then self:SetLayoutMode(stagedUI.Layout) end
			if stagedUI.ClampToViewport ~= nil then self:SetClampToViewport(stagedUI.ClampToViewport) end
		end)
		if not uiOk then
			for index = #applied, 1, -1 do
				local rollback = applied[index]
				pcall(function()
					local value = unwrapConfigValue(rollback.Previous)
					if rollback.Handle.Import then rollback.Handle:Import(value, false, "rollback") else rollback.Handle:Set(value, false, "rollback") end
				end)
			end
			self._pendingFlags = previousPending
			self._pendingFlagSilent = previousPendingSilent
			pcall(function()
				self:SetAccent(previousUI.Accent)
				self:SetSize(previousUI.Size)
				self:SetScale(previousUI.Scale)
				self:SetLayoutMode(previousUI.Layout)
				self:SetClampToViewport(previousUI.ClampToViewport)
			end)
			return false, "UI state was rejected: " .. tostring(uiError)
		end
	end

	if options.Silent ~= true then
		for _, change in ipairs(applied) do
			if change.Handle.Fire then change.Handle:Fire("config") end
			self:_controlChanged(change.Flag, change.Handle.Export and change.Handle:Export() or change.Handle:Get(), "config")
		end
	end
	return true, {Applied = #applied, Pending = table.clone(self._pendingFlags)}
end

Library.ImportConfig = Library.ApplyConfig
Library.SerializeConfig = Library.ExportConfig

local function validConfigName(name)
	name = tostring(name or "")
	if #name < 1 or #name > 64 then return nil, "Config name must contain 1-64 characters" end
	if string.find(name, "%.%.", 1, false) or string.find(name, "[/\\:%c]") then return nil, "Config name contains a forbidden path character" end
	return name
end

function Library:_configPath(name)
	return string.gsub(self._configFolder, "\\", "/") .. "/" .. name .. self._configExtension
end

function Library:GetConfigCapabilities()
	local env = environment()
	return {
		Backend = type(env.writefile) == "function" and type(env.readfile) == "function" and "filesystem" or "memory",
		Persistent = type(env.writefile) == "function" and type(env.readfile) == "function",
		Read = type(env.readfile) == "function",
		Write = type(env.writefile) == "function",
		List = type(env.listfiles) == "function",
		Delete = type(env.delfile) == "function",
		AtomicWrite = false,
		VerifiedWrite = type(env.writefile) == "function" and type(env.readfile) == "function",
	}
end

function Library:_ensureConfigFolder()
	local env = environment()
	if type(env.makefolder) ~= "function" then return false end
	local current = ""
	for part in string.gmatch(string.gsub(self._configFolder, "\\", "/"), "[^/]+") do
		current = current == "" and part or current .. "/" .. part
		local exists = false
		if type(env.isfolder) == "function" then
			local ok, result = pcall(env.isfolder, current)
			exists = ok and result == true
		end
		if not exists then pcall(env.makefolder, current) end
	end
	return true
end

function Library:SaveConfig(name, options)
	local valid, nameError = validConfigName(name)
	if not valid then return nil, nameError end
	local json, encodeError = self:ExportConfig(options)
	if not json then return nil, encodeError end
	local env = environment()
	local capabilities = self:GetConfigCapabilities()
	local folder = self._memoryConfigs[self._configFolder] or {}
	self._memoryConfigs[self._configFolder] = folder
	if capabilities.Persistent then
		self:_ensureConfigFolder()
		local path = self:_configPath(valid)
		local backupPath = path .. ".bak"
		local hadPrevious, previous = pcall(env.readfile, path)
		local ok, err = pcall(env.writefile, path, json)
		if ok then
			local verified, written = pcall(env.readfile, path)
			if not verified or written ~= json then
				ok = false
				err = "Config write verification failed"
				if hadPrevious then pcall(env.writefile, path, previous) end
			end
		end
		if not ok and hadPrevious then pcall(env.writefile, path, previous) end
		if ok then
			local backupWritten = false
			if hadPrevious then backupWritten = pcall(env.writefile, backupPath, previous) end
			folder[string.lower(valid)] = nil
			self._activeConfigName = valid
			return {Name = valid, Backend = "filesystem", Persistent = true, Path = path, BackupPath = backupWritten and backupPath or nil}
		end
		if options and options.RequirePersistent then return nil, tostring(err) end
	end
	folder[string.lower(valid)] = {Name = valid, Json = json, Preferred = capabilities.Persistent}
	self._activeConfigName = valid
	return {Name = valid, Backend = "memory", Persistent = false, Json = json, Fallback = capabilities.Persistent}
end

function Library:LoadConfig(name, options)
	local valid, nameError = validConfigName(name)
	if not valid then return nil, nameError end
	local env = environment()
	local json
	local backupJson
	local usedBackup = false
	local folder = self._memoryConfigs[self._configFolder] or {}
	local memoryItem = folder[string.lower(valid)]
	if memoryItem and memoryItem.Preferred then json = memoryItem.Json end
	if not json and self:GetConfigCapabilities().Persistent then
		local path = self:_configPath(valid)
		local ok, result = pcall(env.readfile, path)
		if ok then json = result end
		local backupOk, backupResult = pcall(env.readfile, path .. ".bak")
		if backupOk then backupJson = backupResult end
		if not json and backupJson then
			json = backupJson
			usedBackup = true
		end
	end
	if not json then
		if not memoryItem then return nil, "Config does not exist: " .. valid end
		json = memoryItem.Json
	end
	local ok, result = self:ApplyConfig(json, options)
	if not ok and backupJson and not usedBackup and backupJson ~= json then
		local backupOk, backupResult = self:ApplyConfig(backupJson, options)
		if backupOk then
			ok, result, usedBackup = true, backupResult, true
		else
			result = tostring(result) .. "; backup was also rejected: " .. tostring(backupResult)
		end
	end
	if ok then
		self._activeConfigName = valid
		if usedBackup and type(result) == "table" then result.RecoveredFromBackup = true end
		return result, nil
	end
	return nil, result
end

function Library:ListConfigs()
	local env = environment()
	local results = {}
	local seen = {}
	if self:GetConfigCapabilities().Persistent and type(env.listfiles) == "function" then
		self:_ensureConfigFolder()
		local ok, files = pcall(env.listfiles, self._configFolder)
		for _, path in ipairs(ok and files or {}) do
			local filename = string.match(path, "([^/\\]+)$")
			if filename and string.sub(filename, -#self._configExtension) == self._configExtension then
				local name = string.sub(filename, 1, #filename - #self._configExtension)
				seen[string.lower(name)] = true
				table.insert(results, name)
			end
		end
	end
	for _, item in pairs(self._memoryConfigs[self._configFolder] or {}) do
		if not seen[string.lower(item.Name)] then table.insert(results, item.Name) end
	end
	table.sort(results, function(a, b) return string.lower(a) < string.lower(b) end)
	return results
end

function Library:DeleteConfig(name)
	local valid, nameError = validConfigName(name)
	if not valid then return nil, nameError end
	local env = environment()
	local removed = false
	if self:GetConfigCapabilities().Persistent then
		if type(env.delfile) == "function" then
			local ok = pcall(env.delfile, self:_configPath(valid))
			removed = ok or removed
			pcall(env.delfile, self:_configPath(valid) .. ".bak")
		end
	end
	local folder = self._memoryConfigs[self._configFolder] or {}
	local existed = folder[string.lower(valid)] ~= nil
	folder[string.lower(valid)] = nil
	if self._activeConfigName and string.lower(self._activeConfigName) == string.lower(valid) then
		self._autoSaveToken += 1
		self._activeConfigName = nil
	end
	return removed or existed
end

function Library:_buildSettings()
	local theme = self.Theme
	local overlay = create("CanvasGroup", {
		Name = "SettingsOverlay",
		Position = UDim2.fromOffset(self._currentSidebarWidth, 0),
		Size = UDim2.new(1, -self._currentSidebarWidth, 1, 0),
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
	blocker.Activated:Connect(function() self:_setSettingsVisible(false) end)

	local panel = create("Frame", {
		Name = "Settings",
		-- Source: settings content starts at global x=360 while the dim layer
		-- starts at x=180. Relative to this overlay that is another 180 px.
		Position = UDim2.fromOffset(180, 0),
		Size = UDim2.new(1, -180, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 61,
		Parent = overlay,
	})
	self.SettingsPanel = panel

	local back = makeButton(panel, {
		Name = "Back",
		Position = UDim2.new(1, -38, 0, 10),
		Size = UDim2.fromOffset(28, 28),
		ZIndex = 63,
	})
	self.SettingsBack = back
	local backIcon = makeIcon(self, back, "chevron-left", 18, theme.TextDim, {
		AnchorPoint = Vector2.new(.5, .5),
		Position = UDim2.fromScale(.5, .5),
		Size = UDim2.fromOffset(18, 18),
		ZIndex = 64,
	})
	back.Activated:Connect(function() self:_setSettingsVisible(false) end)
	connectHover(back, function()
		play(backIcon, .1, iconTweenProperties(backIcon, theme.Text, tr(theme.TextAlpha)))
	end, function()
		play(backIcon, .1, iconTweenProperties(backIcon, theme.TextDim, 0))
	end)

	local area = create("ScrollingFrame", {
		Name = "SettingsArea",
		Position = UDim2.fromOffset(10, 48),
		Size = UDim2.new(1, -20, 1, -58),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = theme.TextDim,
		ScrollBarImageTransparency = .45,
		ZIndex = 62,
		Parent = panel,
	})

	makeText(area, "UI", 10, theme.OverlayText, {
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

	local rowCount = 5
	self._settingsRows = {}
	local function settingsRow(index, title, iconName)
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
		elseif index == rowCount then
			setCorners(rowCorner, 0, 0, 12, 12)
		end
		if iconName then
			makeIcon(self, row, iconName, 16, theme.TextDim, {
				AnchorPoint = Vector2.new(.5, .5),
				Position = UDim2.fromOffset(20, 20),
				Size = UDim2.fromOffset(16, 16),
				ZIndex = 64,
			})
		end
		makeText(row, title, 14, theme.Text, {
			Position = UDim2.fromOffset(iconName and 40 or 12, 0),
			Size = UDim2.new(1, iconName and -52 or -24, 1, 0),
			TextTransparency = tr(theme.TextAlpha),
			ZIndex = 64,
		})
		if index < rowCount then
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
		table.insert(self._settingsRows, row)
		return row
	end

	local function settingsToggle(row, getValue, setValue)
		local track = create("Frame", {
			Position = UDim2.new(1, -44, .5, -10),
			Size = UDim2.fromOffset(32, 20),
			BackgroundColor3 = theme.ElementOverlay,
			BackgroundTransparency = tr(theme.ElementOverlayHoverAlpha),
			ZIndex = 65,
			Parent = row,
		})
		addCorner(track, 999)
		local knob = create("Frame", {
			Size = UDim2.fromOffset(12, 12),
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
		hit.Activated:Connect(function()
			setValue(not getValue())
			render()
		end)
		bindAccent(self, function() render() end)
		render()
	end

	local themeRow = settingsRow(1, "Theme", "paintbrush")
	makeText(themeRow, "Solid", 12, theme.TextDim, {
		Position = UDim2.new(1, -94, 0, 0), Size = UDim2.fromOffset(60, 34),
		TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 66,
	})
	makeIcon(self, themeRow, "chevron-right", 15, theme.TextDim, {
		AnchorPoint = Vector2.new(.5, .5), Position = UDim2.new(1, -19, .5, 0),
		Size = UDim2.fromOffset(15, 15), ZIndex = 66,
	})

	local clampRow = settingsRow(2, "Clamp window", "move")
	settingsToggle(clampRow, function() return self._clampWindow end, function(value)
		self:SetClampToViewport(value)
	end)

	local accentRow = settingsRow(3, "Accent color", "palette")
	local accentSwatch = create("Frame", {
		Position = UDim2.new(1, -34, .5, -10),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = theme.Accent,
		ZIndex = 65,
		Parent = accentRow,
	})
	addCorner(accentSwatch, 5)
	bindAccent(self, function(accent) accentSwatch.BackgroundColor3 = accent end)
	local accentHit = makeButton(accentRow, {Size = UDim2.fromScale(1, 1), ZIndex = 67})
	accentHit.Activated:Connect(function()
		self:_openColorPopup(accentSwatch, self.Theme.Accent, function(color) self:SetAccent(color) end, {
			Title = "Accent color",
			ShowAlpha = false,
			Presets = {Color3.fromRGB(120,255,100), Color3.fromRGB(95,145,255), Color3.fromRGB(205,110,255), Color3.fromRGB(255,120,70)},
		})
	end)

	local scaleRow = settingsRow(4, "Interface scale", "monitor")
	local scaleValue = makeText(scaleRow, string.format("%d%%", math.floor(self.Scale.Scale * 100 + .5)), 12, theme.TextDim, {
		Position = UDim2.new(1, -72, 0, 0), Size = UDim2.fromOffset(58, 34), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 66,
	})
	local scales = {.85, 1, 1.15}
	makeButton(scaleRow, {Size = UDim2.fromScale(1, 1), ZIndex = 67}).Activated:Connect(function()
		local closest = 1
		for index, candidate in ipairs(scales) do
			if math.abs(candidate - self.Scale.Scale) < math.abs(scales[closest] - self.Scale.Scale) then closest = index end
		end
		local nextScale = scales[closest % #scales + 1]
		self:SetScale(nextScale)
		scaleValue.Text = string.format("%d%%", math.floor(nextScale * 100 + .5))
	end)

	local launcherRow = settingsRow(5, "Mobile launcher", "smartphone")
	settingsToggle(launcherRow, function() return self._mobileLauncherEnabled end, function(value)
		self._mobileLauncherEnabled = value
		self:_applyResponsive()
	end)

end

function Library:_setSettingsVisible(visible)
	local overlay = self.SettingsOverlay
	self._settingsToken = (self._settingsToken or 0) + 1
	local token = self._settingsToken
	if visible then
		self:ClosePopup()
		overlay.Visible = true
		overlay.GroupTransparency = 1
		play(overlay, .12, {GroupTransparency = 0})
	else
		local animation = play(overlay, .12, {GroupTransparency = 1})
		animation.Completed:Once(function()
			if token == self._settingsToken and overlay.GroupTransparency >= .99 then overlay.Visible = false end
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
		LeftLayout = leftLayout,
		RightLayout = rightLayout,
		Sections = {},
		SingleColumn = false,
	}, Page)
	local function updateCanvas()
		page:_applyColumns()
	end
	page._updateCanvas = updateCanvas
	table.insert(self._connections, leftLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas))
	table.insert(self._connections, rightLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas))
	task.defer(updateCanvas)
	return page
end

function Page:_applyColumns()
	local leftHeight = self.LeftLayout.AbsoluteContentSize.Y
	local rightHeight = self.RightLayout.AbsoluteContentSize.Y
	local stacked = self.Library._stacked
	self.Right.Visible = not self.SingleColumn
	if stacked then
		self.Left.Position = UDim2.fromOffset(0, 0)
		self.Left.Size = UDim2.new(1, 0, 0, leftHeight)
		self.Right.Position = UDim2.fromOffset(0, leftHeight + 10)
		self.Right.Size = UDim2.new(1, 0, 0, rightHeight)
		local totalHeight = leftHeight + (self.Right.Visible and rightHeight + (rightHeight > 0 and 10 or 0) or 0)
		self.Columns.Size = UDim2.new(1, -20, 0, totalHeight)
		self.Scroll.CanvasSize = UDim2.fromOffset(0, totalHeight + 20)
	else
		self.Left.Position = UDim2.fromOffset(0, 0)
		self.Left.Size = self.SingleColumn and UDim2.new(1, 0, 0, leftHeight) or UDim2.new(.5, -5, 0, leftHeight)
		self.Right.Position = UDim2.new(.5, 5, 0, 0)
		self.Right.Size = UDim2.new(.5, -5, 0, rightHeight)
		local totalHeight = math.max(leftHeight, self.Right.Visible and rightHeight or 0)
		self.Columns.Size = UDim2.new(1, -20, 0, totalHeight)
		self.Scroll.CanvasSize = UDim2.fromOffset(0, totalHeight + 20)
	end
end

function Page:_lockScrolling()
	self._scrollLockCount = (self._scrollLockCount or 0) + 1
	if self._scrollLockCount == 1 then
		self._scrollWasEnabled = self.Scroll.ScrollingEnabled
		self.Scroll.ScrollingEnabled = false
	end
end

function Page:_unlockScrolling()
	self._scrollLockCount = math.max(0, (self._scrollLockCount or 0) - 1)
	if self._scrollLockCount == 0 then
		self.Scroll.ScrollingEnabled = self._scrollWasEnabled ~= false
		self._scrollWasEnabled = nil
	end
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
	local topHeight = self._touchMode and 44 or 28
	if tab.SaveCallback then
		local save = makeButton(self.TopContent, {
			Name = "Save",
			Position = UDim2.fromOffset(cursor, 0),
			Size = UDim2.fromOffset(70, topHeight),
			BackgroundColor3 = self.Theme.Tab,
			BackgroundTransparency = tr(self.Theme.TabAlpha),
			ZIndex = 7,
		})
		addCorner(save, 6)
		addStroke(save, self.Theme.Border, self.Theme.BorderAlpha)
		local saveIcon = makeIcon(self, save, "save", 14, self.Theme.TextDim, {
			AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(14, 14), ZIndex = 8,
		})
		local label = makeText(save, "Save", 14, self.Theme.TextDim, {
			Position = UDim2.fromOffset(26, 0), Size = UDim2.new(1, -30, 1, 0),
			ZIndex = 8,
		})
		connectHover(save, function()
			play(save, .1, {BackgroundTransparency = tr(self.Theme.TabHoverAlpha)})
			play(label, .1, {TextColor3 = self.Theme.Text})
			play(saveIcon, .1, iconTweenProperties(saveIcon, self.Theme.Text, 0))
		end, function()
			play(save, .1, {BackgroundTransparency = tr(self.Theme.TabAlpha)})
			play(label, .1, {TextColor3 = self.Theme.TextDim})
			play(saveIcon, .1, iconTweenProperties(saveIcon, self.Theme.TextDim, 0))
		end)
		save.Activated:Connect(function() task.spawn(tab.SaveCallback) end)
		cursor += 80
	end

	if #tab.SubTabs > 0 then
		local holder = create("ScrollingFrame", {
			Name = "SubTabs",
			Position = UDim2.fromOffset(cursor, 0),
			Size = UDim2.new(1, -cursor - topHeight - 10, 0, topHeight),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			ScrollingDirection = Enum.ScrollingDirection.X,
			ScrollBarThickness = 0,
			BackgroundColor3 = self.Theme.Tab,
			BackgroundTransparency = tr(self.Theme.TabHoverAlpha),
			ClipsDescendants = true,
			ZIndex = 7,
			Parent = self.TopContent,
		})
		addCorner(holder, 6)
		create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder})
		for index, subtab in ipairs(tab.SubTabs) do
			local bounds = TextService:GetTextSize(subtab.Name, 14, Enum.Font.Gotham, Vector2.new(1000, topHeight))
			local width = math.ceil(bounds.X) + 28
			local button = makeButton(holder, {
				Name = subtab.Name,
				Size = UDim2.fromOffset(width, topHeight),
				BackgroundColor3 = self.Theme.Tab,
				BackgroundTransparency = tr(subtab.Active and self.Theme.TabActiveAlpha or self.Theme.TabAlpha),
				ZIndex = 8,
			})
			local segmentCorner = addCorner(button, 0)
			if #tab.SubTabs == 1 then
				setCorners(segmentCorner, 6, 6, 6, 6)
			elseif index == 1 then
				setCorners(segmentCorner, 6, 0, 0, 6)
			elseif index == #tab.SubTabs then
				setCorners(segmentCorner, 0, 6, 6, 0)
			else
				setCorners(segmentCorner, 0, 0, 0, 0)
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
			button.Activated:Connect(function()
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
	table.insert(self.Categories, {Slot = slot, Label = label})
	if self._currentSidebarWidth == self._compactSidebarWidth then slot.Visible = false end
	return label
end

function Library:AddTab(config)
	if type(config) == "string" then config = {Name = config} end
	config = config or {}
	local tab = {
		Library = self,
		Name = config.Name or "Tab",
		Icon = config.Icon or "circle",
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
	local icon = makeIcon(self, button, tab.Icon, 16, self.Theme.TextDim, {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.fromOffset(16, 16),
		ZIndex = 5,
	}, tab.Icon)
	local label = makeText(button, tab.Name, 14, self.Theme.TextDim, {
		Position = UDim2.fromOffset(44, 0),
		Size = UDim2.new(1, -50, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 5,
	})
	tab.Button = button
	tab.NavSlot = navSlot
	tab.IconLabel = icon
	tab.Label = label
	tab.RootPage = self:_newPage(tab.Name)
	table.insert(tab.Pages, tab.RootPage)
	if config.SingleColumn then tab.RootPage:SetSingleColumn(true) end

	function tab:_refresh()
		local theme = self.Library.Theme
		play(self.Button, .10, {BackgroundTransparency = tr(self.Active and theme.TabActiveAlpha or theme.TabAlpha)})
		play(self.IconLabel, .10, iconTweenProperties(self.IconLabel, self.Active and theme.Accent or theme.TextDim, 0))
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
			play(icon, .10, iconTweenProperties(icon, self.Theme.Text, tr(self.Theme.TextAlpha)))
			play(label, .10, {TextColor3 = self.Theme.TextHover})
		end
	end, function()
		tab:_refresh()
	end)
	button.MouseButton1Down:Connect(function()
		button.BackgroundTransparency = tr(self.Theme.TabClickedAlpha)
	end)
	button.Activated:Connect(function() tab:Select() end)
	bindAccent(self, function() if tab.Active then setIconColor(icon, self.Theme.Accent, 0) end end)

	table.insert(self.Tabs, tab)
	if not self._selectedTab then tab:Select() end
	self:_applyResponsive()
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
	self.SingleColumn = enabled ~= false
	task.defer(function() self:_applyColumns() end)
	return self
end

function Section:_refreshRows()
	for index, item in ipairs(self.Rows) do
		local first = index == 1
		local last = index == #self.Rows
		local baseHeight = self.Library._touchMode and math.max(44, item.BaseHeight) or item.BaseHeight
		item.Row.Size = UDim2.new(1, 0, 0, last and baseHeight or baseHeight + 1)
		item.Label.Position = UDim2.fromOffset(item.LabelOffset or 12, last and 0 or -1)
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
	if self.Page and self.Page._updateCanvas then task.defer(self.Page._updateCanvas) end
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
	local entry = {Row = row, Label = labelObject, Hitbox = hit, Corner = rowCorner, BaseHeight = height or 34, LabelOffset = 12}
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
	self:_refreshRows()

	connectHover(hit, function()
		play(row, .10, {BackgroundColor3 = theme.ElementHover or theme.Element, BackgroundTransparency = tr(theme.ElementHoverAlpha)})
	end, function()
		play(row, .10, {BackgroundColor3 = theme.Element, BackgroundTransparency = tr(theme.ElementAlpha)})
	end)
	hit.MouseButton1Down:Connect(function()
		row.BackgroundColor3 = theme.ElementClicked
		row.BackgroundTransparency = tr(theme.ElementClickedAlpha)
	end)
	hit.MouseButton1Up:Connect(function()
		play(row, .10, {BackgroundColor3 = theme.ElementHover or theme.Element, BackgroundTransparency = tr(theme.ElementHoverAlpha)})
	end)
	return entry
end

function Section:AddLabel(text)
	local config = type(text) == "table" and text or {Text = text}
	local labelText = tostring(config.Text or config.Name or "")
	local availableWidth = math.max(120, self.Body.AbsoluteSize.X - 24)
	local bounds = TextService:GetTextSize(labelText, 10, Enum.Font.GothamBold, Vector2.new(availableWidth, 1000))
	local entry = self:_row(labelText, math.max(34, math.ceil(bounds.Y) + 16))
	entry.Label.TextSize = 10
	entry.Label.Font = Enum.Font.GothamBold
	entry.Label.TextColor3 = self.Library.Theme.OverlayText
	entry.Label.TextTransparency = tr(self.Library.Theme.OverlayTextAlpha)
	entry.Label.TextWrapped = true
	entry.Label.TextYAlignment = Enum.TextYAlignment.Center
	entry.Hitbox.Active = false
	return entry.Label
end

function Section:AddButton(config)
	if type(config) == "string" then config = {Name = config} end
	config = config or {}
	local entry = self:_row(config.Name or "Button")
	if config.Icon then
		makeIcon(self.Library, entry.Row, config.Icon, 16, config.Danger and self.Library.Theme.TextUnsafe or self.Library.Theme.TextDim, {
			AnchorPoint = Vector2.new(0,.5), Position = UDim2.new(0,12,.5,0), Size = UDim2.fromOffset(16,16), ZIndex = 10,
		})
		entry.LabelOffset = 40
		entry.Label.Position = UDim2.fromOffset(40,0)
		entry.Label.Size = UDim2.new(1,-52,1,0)
	else
		makeIcon(self.Library, entry.Row, "chevron-right", 16, self.Library.Theme.Text, {
			AnchorPoint = Vector2.new(.5, .5),
			Position = UDim2.new(1, -20, .5, 0),
			Size = UDim2.fromOffset(16, 16),
			ImageTransparency = tr(self.Library.Theme.TextAlpha),
			ZIndex = 10,
		})
		entry.Label.Size = UDim2.new(1,-46,1,0)
	end
	entry.Label.TextTruncate = Enum.TextTruncate.AtEnd
	if config.Danger then entry.Label.TextColor3 = self.Library.Theme.TextUnsafe end
	entry.Hitbox.Activated:Connect(function()
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
	local handle
	for index, color in ipairs(colors) do
		if typeof(color) ~= "Color3" then colors[index] = Color3.new(1, 1, 1) end
	end
	local entry = self:_row(config.Name or "Toggle")
	entry.Label.Size = UDim2.new(1, -(58 + #colors * 22 + ((config.Settings or config.HasSettings) and 22 or 0)), 1, 0)
	entry.Label.TextTruncate = Enum.TextTruncate.AtEnd
	if config.Unsafe then
		entry.Label.Text = stripId(config.Name or "Toggle")
		entry.Label.TextColor3 = self.Library.Theme.TextUnsafe
		local warning = makeIcon(self.Library, entry.Row, "triangle-alert", 14, self.Library.Theme.TextUnsafe, {
			AnchorPoint = Vector2.new(0, .5), Position = UDim2.fromOffset(12, entry.Row.AbsoluteSize.Y / 2), Size = UDim2.fromOffset(14, 14), ZIndex = 10,
		})
		warning.Position = UDim2.new(0, 12, .5, 0)
		entry.LabelOffset = 34
		entry.Label.Position = UDim2.fromOffset(34, 0)
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
	local toggleHit = makeButton(entry.Row, {
		Name = "ToggleHitbox",
		AnchorPoint = Vector2.new(1, .5),
		Position = UDim2.new(1, -2, .5, 0),
		Size = UDim2.new(0, 44, 1, 0),
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
			AnchorPoint = Vector2.new(0, .5),
			Position = UDim2.new(1, -62 - (index - 1) * 22, .5, 0),
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = initialColor,
			BorderSizePixel = 0,
			ZIndex = 13,
			Parent = entry.Row,
		})
		addCorner(swatch, 5)
		addStroke(swatch, self.Library.Theme.ElementOverlay, self.Library.Theme.ElementOverlayHoverAlpha)
		local swatchHit = makeButton(entry.Row, {
			Name = "ColorHitbox" .. index,
			AnchorPoint = Vector2.new(.5, .5),
			Position = UDim2.new(1, -54 - (index - 1) * 22, .5, 0),
			Size = UDim2.new(0, 22, 1, 0),
			ZIndex = 14,
		})
		swatchHit.Activated:Connect(function()
			self.Library:_openColorPopup(swatch, colors[index], function(color)
				colors[index] = color
				swatch.BackgroundColor3 = color
				if config.ColorCallback then task.spawn(config.ColorCallback, index, color) end
				self.Library:_controlChanged(config.Flag or config.Id, handle and handle:Export() or value, "user")
			end, {Title = stripId(config.Name or "Toggle") .. " color " .. index, Presets = config.Presets, ShowAlpha = false})
		end)
		swatches[index] = swatch
	end
	if config.Settings or config.HasSettings then
		local settingsButton = makeButton(entry.Row, {
			Name = "Settings",
			AnchorPoint = Vector2.new(.5, .5),
			Position = UDim2.new(1, -54 - #colors * 22, .5, 0),
			Size = UDim2.new(0, 22, 1, 0),
			ZIndex = 13,
		})
		makeIcon(self.Library, settingsButton, "chevron-right", 14, self.Library.Theme.Text, {
			AnchorPoint = Vector2.new(.5,.5), Position = UDim2.fromScale(.5,.5), Size = UDim2.fromOffset(14,14),
			ImageTransparency = tr(self.Library.Theme.TextAlpha),
			ZIndex = 14,
		})
		settingsButton.Activated:Connect(function()
			if config.Settings then task.spawn(config.Settings) end
		end)
	end

	local function render(fire, source)
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
		if fire and config.Callback then task.spawn(config.Callback, value, {Source = source or "user"}) end
		if fire then self.Library:_controlChanged(config.Flag or config.Id, value, source) end
	end
	toggleHit.MouseButton1Down:Connect(function()
		entry.Row.BackgroundColor3 = self.Library.Theme.ElementClicked
		entry.Row.BackgroundTransparency = tr(self.Library.Theme.ElementClickedAlpha)
	end)
	toggleHit.MouseButton1Up:Connect(function()
		play(entry.Row, .10, {BackgroundColor3 = self.Library.Theme.Element, BackgroundTransparency = tr(self.Library.Theme.ElementHoverAlpha)})
	end)
	local function toggleValue()
		value = not value
		render(true, "user")
	end
	toggleHit.Activated:Connect(toggleValue)
	entry.Hitbox.Activated:Connect(toggleValue)
	bindAccent(self.Library, function() render(false) end)
	render(false)
	handle = {
		Get = function() return value end,
		Set = function(_, newValue, fire, source) value = not not newValue; render(fire ~= false, source or "api") end,
		GetColor = function(_, index) return colors[index or 1] end,
		SetColor = function(_, index, color, fire)
			assert(typeof(color) == "Color3", "Toggle color must be Color3")
			index = index or 1
			colors[index] = color
			if swatches[index] then swatches[index].BackgroundColor3 = color end
			if fire ~= false and config.ColorCallback then task.spawn(config.ColorCallback, index, color) end
			if fire ~= false then self.Library:_controlChanged(config.Flag or config.Id, handle:Export(), "api") end
		end,
		Export = function()
			if #colors == 0 then return value end
			return {Value = value, Colors = table.clone(colors)}
		end,
		Import = function(_, imported, fire, source)
			if type(imported) == "table" and imported.Value ~= nil then
				value = not not imported.Value
				for index, color in ipairs(imported.Colors or {}) do
					if typeof(color) == "Color3" then colors[index] = color; if swatches[index] then swatches[index].BackgroundColor3 = color end end
				end
			else
				value = not not imported
			end
			render(fire ~= false, source or "config")
		end,
		Fire = function(_, source)
			if config.Callback then task.spawn(config.Callback, value, {Source = source or "api"}) end
			if config.ColorCallback then
				for index, color in ipairs(colors) do task.spawn(config.ColorCallback, index, color, {Source = source or "api"}) end
			end
		end,
		Instance = entry.Row,
	}
	return self.Library:_registerFlag(config, handle, "toggle")
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
	blocker.Activated:Connect(function() self:ClosePopup() end)
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
	local scale = math.max(self.Scale.Scale, .01)
	local x = (center.X - windowPosition.X) / scale - width / 2
	local y = (center.Y - windowPosition.Y) / scale - height / 2
	local logicalSize = self._actualSize or Vector2.new(self.Window.AbsoluteSize.X / scale, self.Window.AbsoluteSize.Y / scale)
	x = math.clamp(x, 8, math.max(8, logicalSize.X - width - 8))
	y = math.clamp(y, 8, math.max(8, logicalSize.Y - height - 8))
	return UDim2.fromOffset(x, y)
end

function Section:AddDropdown(config)
	config = config or {}
	local options = table.clone(config.Options or {})
	local value = config.Default
	if value == nil then value = options[1] end
	local entry = self:_row(config.Name or "Dropdown")
	entry.Label.Size = UDim2.new(.5, -12, 1, 0)
	entry.Label.TextTruncate = Enum.TextTruncate.AtEnd
	local preview = create("Frame", {
		Name = "Preview",
		AnchorPoint = Vector2.new(0, .5),
		Position = UDim2.new(.5, 0, .5, 0),
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
	makeIcon(self.Library, preview, "chevron-down", 14, self.Library.Theme.Text, {
		AnchorPoint = Vector2.new(.5,.5), Position = UDim2.new(1, -14, .5, 0),
		Size = UDim2.fromOffset(14, 14),
		ImageTransparency = tr(self.Library.Theme.TextAlpha),
		ZIndex = 11,
	})

	local handle
	local function set(newValue, fire, source)
		if not config.AllowCustom and newValue ~= nil and not table.find(options, newValue) then
			error("Dropdown value is not present in Options")
		end
		value = newValue
		previewLabel.Text = tostring(value or "None")
		if fire and config.Callback then task.spawn(config.Callback, value, {Source = source or "user"}) end
		if fire then self.Library:_controlChanged(config.Flag or config.Id, value, source) end
	end

	local function open()
		local count = math.max(1, #options)
		local itemHeight = self.Library._touchMode and 44 or 32
		local height = math.min(16 + itemHeight * count, math.min(300, self.Library:GetActualSize().Y - 16))
		local width = math.min(math.max(180, math.floor(preview.AbsoluteSize.X / math.max(self.Library.Scale.Scale, .01) * 1.6 + .5)), self.Library:GetActualSize().X - 16)
		local popup = self.Library:_popupFrame(width, height, self.Library:_popupPosition(preview, width, height))
		local holder = create("ScrollingFrame", {
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.new(1, -16, 1, -16),
			BackgroundTransparency = 1,
			CanvasSize = UDim2.fromOffset(0, itemHeight * #options),
			ScrollBarThickness = 2,
			ScrollBarImageColor3 = self.Library.Theme.TextDim,
			ScrollBarImageTransparency = .5,
			ZIndex = 102,
			Parent = popup,
		})
		create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder})
		for _, option in ipairs(options) do
			local choice = makeButton(holder, {
				Name = tostring(option),
				Size = UDim2.new(1, -4, 0, itemHeight),
				BackgroundColor3 = self.Library.Theme.PopupOverlay,
				BackgroundTransparency = 1,
				ZIndex = 103,
			})
			addCorner(choice, 16)
			makeText(choice, tostring(option), 14, self.Library.Theme.PopupText, {
				Position = UDim2.fromOffset(2, 0),
				Size = UDim2.new(1, -26, 1, 0),
				TextTransparency = tr(self.Library.Theme.PopupTextAlpha),
				ZIndex = 104,
			})
			makeIcon(self.Library, choice, "check", 12, self.Library.Theme.Accent, {
				AnchorPoint = Vector2.new(.5,.5), Position = UDim2.new(1, -13, .5, 0),
				Size = UDim2.fromOffset(12, 12),
				Visible = value == option,
				ZIndex = 104,
			})
			connectHover(choice, function()
				play(choice, .1, {BackgroundTransparency = tr(self.Library.Theme.PopupOverlayHoverAlpha)})
			end, function()
				play(choice, .1, {BackgroundTransparency = 1})
			end)
			choice.Activated:Connect(function()
				set(option, true, "user")
				self.Library:ClosePopup()
			end)
		end
	end
	entry.Hitbox.Activated:Connect(open)
	handle = {
		Get = function() return value end,
		Set = function(_, newValue, fire, source) set(newValue, fire ~= false, source or "api") end,
		Refresh = function(_, newOptions, fire)
			options = table.clone(newOptions or {})
			if not table.find(options, value) then set(options[1], fire ~= false, "api") end
		end,
		Export = function() return value end,
		Import = function(_, imported, fire, source) set(imported, fire ~= false, source or "config") end,
		Fire = function(_, source) if config.Callback then task.spawn(config.Callback, value, {Source = source or "api"}) end end,
		Instance = entry.Row,
	}
	return self.Library:_registerFlag(config, handle, "dropdown")
end

function Section:AddSlider(config)
	config = config or {}
	local minimum = tonumber(config.Min) or 0
	local maximum = tonumber(config.Max) or 100
	if minimum > maximum then minimum, maximum = maximum, minimum end
	local step = math.abs(tonumber(config.Step) or 1)
	if step == 0 then step = 1 end
	local value = math.clamp(tonumber(config.Default) or minimum, minimum, maximum)
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
	local sliderHit = makeButton(entry.Row, {
		Position = UDim2.new(.5, 0, 0, 0), Size = UDim2.new(.5, -8, 1, 0), ZIndex = 13,
	})
	bindAccent(self.Library, function(accent) fill.BackgroundColor3 = accent end)

	local capturedInput
	local mouseCapture = false
	local touchCapture = false
	local handle
	local callbackQueued = false
	local function render(fire, source)
		local alpha = maximum == minimum and 0 or (value - minimum) / (maximum - minimum)
		fill.Size = UDim2.fromScale(alpha, 1)
		valueText.Text = config.Format and string.format(config.Format, value) or tostring(value)
		if fire and config.Callback and not callbackQueued then
			callbackQueued = true
			task.defer(function()
				callbackQueued = false
				config.Callback(value, {Source = source or "user"})
			end)
		end
		if fire then self.Library:_controlChanged(config.Flag or config.Id, value, source) end
	end
	local function setFromX(x, source)
		local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
		local raw = minimum + (maximum - minimum) * alpha
		value = math.clamp(minimum + math.floor((raw - minimum) / step + .5) * step, minimum, maximum)
		render(true, source or "user")
	end
	sliderHit.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			if capturedInput then return end
			capturedInput = input
			mouseCapture = kind == Enum.UserInputType.MouseButton1
			touchCapture = kind == Enum.UserInputType.Touch
			if touchCapture and self.Page then self.Page:_lockScrolling() end
			setFromX(input.Position.X, "user")
		end
	end)
	local changedConnection = UserInputService.InputChanged:Connect(function(input)
		local matches = mouseCapture and input.UserInputType == Enum.UserInputType.MouseMovement or input == capturedInput
		if capturedInput and matches then
			setFromX(input.Position.X, "user")
		end
	end)
	local endedConnection = UserInputService.InputEnded:Connect(function(input)
		if input == capturedInput or mouseCapture and input.UserInputType == Enum.UserInputType.MouseButton1 then
			capturedInput = nil
			mouseCapture = false
			if touchCapture and self.Page then self.Page:_unlockScrolling() end
			touchCapture = false
		end
	end)
	table.insert(self.Library._connections, changedConnection)
	table.insert(self.Library._connections, endedConnection)
	render(false)
	handle = {
		Get = function() return value end,
		Set = function(_, newValue, fire, source)
			newValue = assert(tonumber(newValue), "Slider value must be a number")
			assert(newValue == newValue and newValue ~= math.huge and newValue ~= -math.huge, "Slider value must be finite")
			value = math.clamp(minimum + math.floor((newValue - minimum) / step + .5) * step, minimum, maximum)
			render(fire ~= false, source or "api")
		end,
		Export = function() return value end,
		Import = function(_, imported, fire, source) handle:Set(imported, fire, source or "config") end,
		Fire = function(_, source) if config.Callback then task.spawn(config.Callback, value, {Source = source or "api"}) end end,
		Instance = entry.Row,
	}
	return self.Library:_registerFlag(config, handle, "slider")
end

function Library:_openAdvancedColorPopup(anchor, initialColor, callback, options)
	options = options or {}
	if typeof(initialColor) ~= "Color3" then initialColor = Color3.new(1, 1, 1) end
	local originalColor = initialColor
	local showAlpha = options.ShowAlpha ~= false
	local originalAlpha = showAlpha and math.clamp(tonumber(options.Alpha) or 1, 0, 1) or 1
	local alpha = originalAlpha
	local hue, saturation, brightness = initialColor:ToHSV()
	local logicalSize = self:GetActualSize()
	local width = math.min(286, logicalSize.X - 16)
	local barHeight = self._touchMode and 22 or 16
	local alphaY = self._touchMode and 202 or 200
	local previewY = showAlpha and 228 or alphaY
	local channelY = previewY + 36
	local presetY = channelY + 34
	local presetSize = self._touchMode and 44 or 22
	local pickerButtonHeight = self._touchMode and 44 or 28
	local actionY = presetY + presetSize + 7
	local contentHeight = actionY + pickerButtonHeight + 9
	local height = math.min(contentHeight, logicalSize.Y - 16)
	local popup = self:_popupFrame(width, height, self:_popupPosition(anchor, width, height))
	local content = create("ScrollingFrame", {
		Name = "ColorPicker",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.fromOffset(0, contentHeight),
		ScrollBarThickness = height < contentHeight and 2 or 0,
		ScrollBarImageColor3 = self.Theme.TextDim,
		ScrollBarImageTransparency = .45,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 102,
		Parent = popup,
	})

	makeText(content, options.Title or "Color picker", 13, self.Theme.Text, {
		Position = UDim2.fromOffset(12, 5), Size = UDim2.new(1, -54, 0, 28), Font = Enum.Font.GothamBold,
		TextTransparency = tr(self.Theme.TextAlpha), ZIndex = 103,
	})
	local close = makeButton(content, {
		Position = UDim2.new(1, self._touchMode and -46 or -38, 0, self._touchMode and 1 or 3), Size = UDim2.fromOffset(self._touchMode and 44 or 28, self._touchMode and 44 or 28), ZIndex = 110,
	})
	makeIcon(self, close, "x", 15, self.Theme.TextDim, {
		AnchorPoint = Vector2.new(.5,.5), Position = UDim2.fromScale(.5,.5), Size = UDim2.fromOffset(15,15), ZIndex = 111,
	})
	close.Activated:Connect(function() self:ClosePopup() end)

	local sv = create("Frame", {
		Name = "SaturationValue",
		Position = UDim2.fromOffset(12, 38),
		Size = UDim2.new(1, -24, 0, 126),
		BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
		Active = true,
		ClipsDescendants = true,
		ZIndex = 103,
		Parent = content,
	})
	addCorner(sv, 9)
	local white = create("Frame", {Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(1,1,1),ZIndex=104,Parent=sv})
	create("UIGradient", {Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)}),Parent=white})
	local black = create("Frame", {Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),ZIndex=105,Parent=sv})
	create("UIGradient", {Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)}),Parent=black})
	local svCursor = create("Frame", {
		AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(12,12),BackgroundTransparency=1,ZIndex=108,Parent=sv,
	})
	addCorner(svCursor, 99)
	addStroke(svCursor, Color3.new(1,1,1), 1, 2)
	local cursorInner = create("Frame", {AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(4,4),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=.15,ZIndex=109,Parent=svCursor})
	addCorner(cursorInner,99)

	local hueBar = create("Frame", {
		Name="Hue",Position=UDim2.fromOffset(12,174),Size=UDim2.new(1,-24,0,barHeight),BackgroundColor3=Color3.new(1,1,1),Active=true,ClipsDescendants=false,ZIndex=103,Parent=content,
	})
	addCorner(hueBar,99)
	create("UIGradient", {Color=ColorSequence.new({
		ColorSequenceKeypoint.new(0,Color3.fromHSV(0,1,1)),ColorSequenceKeypoint.new(1/6,Color3.fromHSV(1/6,1,1)),
		ColorSequenceKeypoint.new(2/6,Color3.fromHSV(2/6,1,1)),ColorSequenceKeypoint.new(3/6,Color3.fromHSV(3/6,1,1)),
		ColorSequenceKeypoint.new(4/6,Color3.fromHSV(4/6,1,1)),ColorSequenceKeypoint.new(5/6,Color3.fromHSV(5/6,1,1)),
		ColorSequenceKeypoint.new(1,Color3.fromHSV(1,1,1)),
	}),Parent=hueBar})
	local hueCursor = create("Frame", {AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(5,22),BackgroundColor3=Color3.new(1,1,1),ZIndex=108,Parent=hueBar})
	addCorner(hueCursor,99)
	addStroke(hueCursor,Color3.new(0,0,0),.35,1)

	local alphaBar = create("Frame", {
		Name="Alpha",Position=UDim2.fromOffset(12,alphaY),Size=UDim2.new(1,-24,0,barHeight),BackgroundColor3=Color3.fromRGB(45,45,45),Active=true,ClipsDescendants=true,ZIndex=103,Parent=content,
	})
	addCorner(alphaBar,99)
	for index = 0, 17 do
		local square = create("Frame", {
			Position=UDim2.new(index/18,0,0,0),Size=UDim2.new(1/18,1,1,0),BackgroundColor3=index%2==0 and Color3.fromRGB(80,80,80) or Color3.fromRGB(35,35,35),ZIndex=104,Parent=alphaBar,
		})
		if index % 2 == 1 then square.BackgroundTransparency = .15 end
	end
	local alphaOverlay = create("Frame", {Size=UDim2.fromScale(1,1),BackgroundColor3=initialColor,ZIndex=105,Parent=alphaBar})
	create("UIGradient", {Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)}),Parent=alphaOverlay})
	local alphaCursor = create("Frame", {AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(5,22),BackgroundColor3=Color3.new(1,1,1),ZIndex=108,Parent=alphaBar})
	addCorner(alphaCursor,99)
	addStroke(alphaCursor,Color3.new(0,0,0),.35,1)
	alphaBar.Visible = showAlpha

	local originalPreview = create("Frame", {Position=UDim2.fromOffset(12,previewY),Size=UDim2.fromOffset(28,28),BackgroundColor3=originalColor,BackgroundTransparency=1-originalAlpha,ZIndex=103,Parent=content})
	addCorner(originalPreview,7); addStroke(originalPreview,self.Theme.PopupOutline,.18)
	local currentPreview = create("Frame", {Position=UDim2.fromOffset(44,previewY),Size=UDim2.fromOffset(28,28),BackgroundColor3=initialColor,ZIndex=103,Parent=content})
	addCorner(currentPreview,7); addStroke(currentPreview,self.Theme.PopupOutline,.18)

	local hexBox = create("TextBox", {
		Name="Hex",Position=UDim2.fromOffset(78,previewY),Size=UDim2.new(1,-90,0,28),BackgroundColor3=self.Theme.ElementOverlay,
		BackgroundTransparency=tr(self.Theme.ElementOverlayAlpha),Text=colorToHex(initialColor,alpha),PlaceholderText="#RRGGBB",ClearTextOnFocus=false,
		TextColor3=self.Theme.Text,PlaceholderColor3=self.Theme.TextDim,TextSize=12,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,
		ZIndex=104,Parent=content,
	})
	addCorner(hexBox,7); addStroke(hexBox,self.Theme.PopupOutline,.12)
	create("UIPadding", {PaddingLeft=UDim.new(0,9),PaddingRight=UDim.new(0,32),Parent=hexBox})
	local copy = makeButton(hexBox, {Position=UDim2.new(1,-29,0,0),Size=UDim2.fromOffset(29,28),ZIndex=106})
	makeIcon(self,copy,"copy",13,self.Theme.TextDim,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(13,13),ZIndex=107})
	copy.Activated:Connect(function()
		local setter = environment().setclipboard
		if type(setter)=="function" then pcall(setter,hexBox.Text) end
	end)

	local channelBoxes = {}
	local channels = showAlpha and {"R","G","B","A"} or {"R","G","B"}
	local fieldWidth = (width - 24 - (#channels - 1) * 3) / #channels
	for index, channel in ipairs(channels) do
		local box = create("TextBox", {
			Name=channel,Position=UDim2.fromOffset(12+(index-1)*(fieldWidth+3),channelY),Size=UDim2.fromOffset(fieldWidth,27),
			BackgroundColor3=self.Theme.ElementOverlay,BackgroundTransparency=tr(self.Theme.ElementOverlayAlpha),ClearTextOnFocus=false,
			TextColor3=self.Theme.Text,TextSize=11,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=104,Parent=content,
		})
		addCorner(box,7); addStroke(box,self.Theme.PopupOutline,.10)
		channelBoxes[index]=box
	end

	local presetHolder = create("ScrollingFrame", {Position=UDim2.fromOffset(12,presetY),Size=UDim2.new(1,-24,0,presetSize),BackgroundTransparency=1,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.X,ScrollingDirection=Enum.ScrollingDirection.X,ScrollBarThickness=0,ClipsDescendants=true,ZIndex=103,Parent=content})
	create("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder,Parent=presetHolder})
	local presets = options.Presets or {Color3.new(1,1,1),Color3.new(0,0,0),self.Theme.Accent,Color3.fromRGB(95,145,255),Color3.fromRGB(255,100,100),Color3.fromRGB(205,110,255)}

	local focused = nil
	local function currentColor() return Color3.fromHSV(hue,saturation,brightness) end
	local function updateVisuals(updateFields)
		local color = currentColor()
		sv.BackgroundColor3=Color3.fromHSV(hue,1,1)
		svCursor.Position=UDim2.fromScale(saturation,1-brightness)
		hueCursor.Position=UDim2.fromScale(hue,.5)
		alphaCursor.Position=UDim2.fromScale(alpha,.5)
		alphaOverlay.BackgroundColor3=color
		currentPreview.BackgroundColor3=color
		currentPreview.BackgroundTransparency=1-alpha
		if updateFields then
			if focused ~= hexBox then hexBox.Text=colorToHex(color,alpha) end
			local values={math.floor(color.R*255+.5),math.floor(color.G*255+.5),math.floor(color.B*255+.5),math.floor(alpha*255+.5)}
			for index,box in ipairs(channelBoxes) do if focused~=box then box.Text=({"R ","G ","B ","A "})[index]..values[index] end end
		end
		if options.Preview then task.defer(options.Preview,color,alpha) end
	end
	local function setColor(color,newAlpha)
		if typeof(color)~="Color3" then return end
		hue,saturation,brightness=color:ToHSV()
		if newAlpha~=nil then alpha=math.clamp(newAlpha,0,1) end
		updateVisuals(true)
	end

	for _,preset in ipairs(presets) do
		if typeof(preset)=="Color3" then
			local button=makeButton(presetHolder,{Size=UDim2.fromOffset(presetSize,presetSize),BackgroundColor3=preset,BackgroundTransparency=0,ZIndex=104})
			addCorner(button,6);addStroke(button,self.Theme.PopupOutline,.16)
			button.Activated:Connect(function() setColor(preset) end)
		end
	end

	local activeInput, activeSetter, mouseCapture
	local function capture(input,setter)
		local kind=input.UserInputType
		if kind~=Enum.UserInputType.MouseButton1 and kind~=Enum.UserInputType.Touch then return end
		if activeInput then return end
		activeInput=input;activeSetter=setter;mouseCapture=kind==Enum.UserInputType.MouseButton1
		content.ScrollingEnabled=false
		setter(input.Position)
	end
	local function setSV(position)
		saturation=math.clamp((position.X-sv.AbsolutePosition.X)/math.max(1,sv.AbsoluteSize.X),0,1)
		brightness=1-math.clamp((position.Y-sv.AbsolutePosition.Y)/math.max(1,sv.AbsoluteSize.Y),0,1)
		updateVisuals(true)
	end
	local function setHue(position)
		hue=math.clamp((position.X-hueBar.AbsolutePosition.X)/math.max(1,hueBar.AbsoluteSize.X),0,.999999)
		updateVisuals(true)
	end
	local function setAlpha(position)
		alpha=math.clamp((position.X-alphaBar.AbsolutePosition.X)/math.max(1,alphaBar.AbsoluteSize.X),0,1)
		updateVisuals(true)
	end
	sv.InputBegan:Connect(function(input) capture(input,setSV) end)
	hueBar.InputBegan:Connect(function(input) capture(input,setHue) end)
	alphaBar.InputBegan:Connect(function(input) capture(input,setAlpha) end)
	local changed=UserInputService.InputChanged:Connect(function(input)
		local matches=mouseCapture and input.UserInputType==Enum.UserInputType.MouseMovement or input==activeInput
		if activeInput and matches and activeSetter then activeSetter(input.Position) end
	end)
	local ended=UserInputService.InputEnded:Connect(function(input)
		if input==activeInput or mouseCapture and input.UserInputType==Enum.UserInputType.MouseButton1 then activeInput=nil;activeSetter=nil;mouseCapture=false;content.ScrollingEnabled=true end
	end)
	table.insert(self._popup.Connections,changed);table.insert(self._popup.Connections,ended)

	hexBox.Focused:Connect(function() focused=hexBox end)
	hexBox.FocusLost:Connect(function()
		focused=nil
		local color,newAlpha,hasAlpha=colorFromHex(hexBox.Text)
		if color then setColor(color,hasAlpha and newAlpha or alpha) else updateVisuals(true) end
	end)
	for index,box in ipairs(channelBoxes) do
		box.Focused:Connect(function() focused=box;box.Text=string.match(box.Text,"%d+") or "" end)
		box.FocusLost:Connect(function()
			focused=nil
			local number=math.clamp(tonumber(string.match(box.Text,"%-?%d+")) or 0,0,255)
			local color=currentColor()
			local values={math.floor(color.R*255+.5),math.floor(color.G*255+.5),math.floor(color.B*255+.5),math.floor(alpha*255+.5)}
			values[index]=number
			setColor(Color3.fromRGB(values[1],values[2],values[3]),values[4]/255)
		end)
	end

	local cancel=makeButton(content,{Position=UDim2.fromOffset(12,actionY),Size=UDim2.new(.5,-18,0,pickerButtonHeight),BackgroundColor3=self.Theme.ElementOverlay,BackgroundTransparency=tr(self.Theme.ElementAlpha),ZIndex=104})
	addCorner(cancel,8);addStroke(cancel,self.Theme.PopupOutline,.12)
	makeText(cancel,"Cancel",12,self.Theme.TextDim,{TextXAlignment=Enum.TextXAlignment.Center,ZIndex=105})
	cancel.Activated:Connect(function() self:ClosePopup() end)
	local apply=makeButton(content,{Position=UDim2.new(.5,6,0,actionY),Size=UDim2.new(.5,-18,0,pickerButtonHeight),BackgroundColor3=dim(self.Theme.Accent,.55),BackgroundTransparency=.05,ZIndex=104})
	addCorner(apply,8)
	makeText(apply,"Apply",12,self.Theme.Text,{TextXAlignment=Enum.TextXAlignment.Center,Font=Enum.Font.GothamBold,ZIndex=105})
	apply.Activated:Connect(function()
		local color=currentColor()
		self:ClosePopup()
		callback(color,alpha,originalColor,originalAlpha)
	end)
	updateVisuals(true)
	return popup
end

-- Compact Alice/Everness picker. Its geometry follows elem.cpp:
-- CPopup(180), 10 px padding and position {swatch.right + 5, swatch.top - 100}.
function Library:_openColorPopup(anchor, initialColor, callback, options)
	options = options or {}
	if string.lower(tostring(options.Style or "source")) == "advanced" then
		return self:_openAdvancedColorPopup(anchor, initialColor, callback, options)
	end
	if typeof(initialColor) ~= "Color3" then initialColor = Color3.new(1, 1, 1) end
	local showAlpha = options.ShowAlpha ~= false
	local alpha = showAlpha and math.clamp(tonumber(options.Alpha) or 1, 0, 1) or 1
	local hue, saturation, brightness = initialColor:ToHSV()
	local width = 180
	local rowHeight = self._touchMode and 38 or 30
	local controls = showAlpha and 5 or 4
	local contentHeight = 194 + rowHeight * controls
	local logicalSize = self:GetActualSize()
	local height = math.min(contentHeight, math.max(180, logicalSize.Y - 16))
	local scale = math.max(self.Scale.Scale, .01)
	local windowPosition = self.Window.AbsolutePosition
	local x = (anchor.AbsolutePosition.X + anchor.AbsoluteSize.X - windowPosition.X) / scale + 5
	local y = (anchor.AbsolutePosition.Y - windowPosition.Y) / scale - 100
	if self._mobile or x + width > logicalSize.X - 8 then
		x = (anchor.AbsolutePosition.X - windowPosition.X) / scale - width - 5
	end
	if self._mobile then
		x = math.clamp(x, 8, math.max(8, logicalSize.X - width - 8))
		y = math.clamp(y, 8, math.max(8, logicalSize.Y - height - 8))
	end
	local popup = self:_popupFrame(width, height, UDim2.fromOffset(x, y))
	local content = create("ScrollingFrame", {
		Name = "ColorPicker", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		CanvasSize = UDim2.fromOffset(0, contentHeight), ScrollBarThickness = height < contentHeight and 2 or 0,
		ScrollBarImageColor3 = self.Theme.TextDim, ScrollBarImageTransparency = .45,
		ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 102, Parent = popup,
	})

	local sv = create("Frame", {
		Name = "SaturationValue", Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(160, 116),
		BackgroundColor3 = Color3.fromHSV(hue, 1, 1), Active = true, ClipsDescendants = true, ZIndex = 103, Parent = content,
	})
	addCorner(sv, 7)
	local white = create("Frame", {Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(1,1,1),ZIndex=104,Parent=sv})
	create("UIGradient", {Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)}),Parent=white})
	local black = create("Frame", {Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),ZIndex=105,Parent=sv})
	create("UIGradient", {Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)}),Parent=black})
	local svCursor = create("Frame", {AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(11,11),BackgroundTransparency=1,ZIndex=108,Parent=sv})
	addCorner(svCursor, 99); addStroke(svCursor, Color3.new(1,1,1), 1, 2)

	local hueBar = create("Frame", {
		Name="Hue",Position=UDim2.fromOffset(10,136),Size=UDim2.fromOffset(160,8),BackgroundColor3=Color3.new(1,1,1),
		Active=true,ClipsDescendants=false,ZIndex=103,Parent=content,
	})
	addCorner(hueBar, 99)
	create("UIGradient", {Color=ColorSequence.new({
		ColorSequenceKeypoint.new(0,Color3.fromHSV(0,1,1)), ColorSequenceKeypoint.new(1/6,Color3.fromHSV(1/6,1,1)),
		ColorSequenceKeypoint.new(2/6,Color3.fromHSV(2/6,1,1)), ColorSequenceKeypoint.new(3/6,Color3.fromHSV(3/6,1,1)),
		ColorSequenceKeypoint.new(4/6,Color3.fromHSV(4/6,1,1)), ColorSequenceKeypoint.new(5/6,Color3.fromHSV(5/6,1,1)),
		ColorSequenceKeypoint.new(1,Color3.fromHSV(1,1,1)),
	}),Parent=hueBar})
	local hueCursor = create("Frame", {AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(5,14),BackgroundColor3=Color3.new(1,1,1),ZIndex=108,Parent=hueBar})
	addCorner(hueCursor,99); addStroke(hueCursor,Color3.new(0,0,0),.35,1)

	self._colorPalette = self._colorPalette or {}
	local paletteHolder = create("Frame", {Position=UDim2.fromOffset(10,154),Size=UDim2.fromOffset(160,24),BackgroundTransparency=1,ZIndex=103,Parent=content})
	local paletteButtons = {}
	local function currentColor() return Color3.fromHSV(hue, saturation, brightness) end
	local updateVisuals
	local function emit()
		local color = currentColor()
		if options.Preview then task.defer(options.Preview, color, alpha) end
		callback(color, alpha, initialColor, tonumber(options.Alpha) or 1)
	end
	local function setColor(color, newAlpha)
		if typeof(color) ~= "Color3" then return end
		hue, saturation, brightness = color:ToHSV()
		if newAlpha ~= nil and showAlpha then alpha = math.clamp(newAlpha,0,1) end
		updateVisuals()
		emit()
	end
	local function rebuildPalette()
		for _, object in ipairs(paletteButtons) do object:Destroy() end
		table.clear(paletteButtons)
		for index, color in ipairs(self._colorPalette) do
			if index > 6 then break end
			local hit = makeButton(paletteHolder,{Position=UDim2.fromOffset((index-1)*23,0),Size=UDim2.fromOffset(18,18),ZIndex=105})
			local ring=create("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(18,18),BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,ZIndex=104,Parent=hit})
			addCorner(ring,99); addStroke(ring,Color3.new(1,1,1),.65,1)
			local dot=create("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(12,12),BackgroundColor3=color,ZIndex=105,Parent=hit})
			addCorner(dot,99)
			hit.Activated:Connect(function() setColor(color) end)
			table.insert(paletteButtons,hit)
		end
	end
	local addColor = makeButton(paletteHolder,{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,0,0,0),Size=UDim2.fromOffset(18,18),BackgroundColor3=self.Theme.ElementOverlay,BackgroundTransparency=tr(self.Theme.ElementOverlayAlpha),ZIndex=105})
	addCorner(addColor,4)
	makeIcon(self,addColor,"plus",12,self.Theme.PopupText,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(12,12),ZIndex=106})
	addColor.Activated:Connect(function()
		if #self._colorPalette >= 6 then table.remove(self._colorPalette,1) end
		table.insert(self._colorPalette,currentColor()); rebuildPalette()
	end)

	create("Frame", {Position=UDim2.fromOffset(10,184),Size=UDim2.fromOffset(160,1),BackgroundColor3=self.Theme.PopupOutline,BackgroundTransparency=tr(self.Theme.PopupOutlineAlpha),BorderSizePixel=0,ZIndex=103,Parent=content})
	local yCursor = 194
	local function actionRow(name, iconName, action)
		local button=makeButton(content,{Position=UDim2.fromOffset(8,yCursor),Size=UDim2.new(1,-16,0,rowHeight),BackgroundColor3=self.Theme.PopupOverlay,BackgroundTransparency=1,ZIndex=104})
		addCorner(button,12)
		local icon=makeIcon(self,button,iconName,14,self.Theme.PopupText,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(17,rowHeight/2),Size=UDim2.fromOffset(14,14),ZIndex=105})
		makeText(button,name,12,self.Theme.PopupText,{Position=UDim2.fromOffset(34,0),Size=UDim2.new(1,-42,1,0),TextTransparency=tr(self.Theme.PopupTextAlpha),ZIndex=105})
		connectHover(button,function() play(button,.08,{BackgroundTransparency=tr(self.Theme.PopupOverlayHoverAlpha)}) end,function() play(button,.08,{BackgroundTransparency=1}) end)
		button.Activated:Connect(action)
		yCursor += rowHeight
		return button,icon
	end
	local function sliderRow(name,iconName,getValue,setValue)
		local row=actionRow(name,iconName,function() end)
		local track=create("Frame",{AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-9,.5,0),Size=UDim2.fromOffset(76,6),BackgroundColor3=self.Theme.SliderBackground,BackgroundTransparency=tr(self.Theme.SliderBackgroundAlpha),Active=true,ZIndex=107,Parent=row})
		addCorner(track,99)
		local fill=create("Frame",{Size=UDim2.fromScale(getValue(),1),BackgroundColor3=self.Theme.Accent,ZIndex=108,Parent=track});addCorner(fill,99)
		local cursor=create("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(getValue(),.5),Size=UDim2.fromOffset(10,10),BackgroundColor3=Color3.new(1,1,1),ZIndex=109,Parent=track});addCorner(cursor,99)
		local function renderSlider() local value=math.clamp(getValue(),0,1);fill.Size=UDim2.fromScale(value,1);cursor.Position=UDim2.fromScale(value,.5) end
		return track,renderSlider,function(position) setValue(math.clamp((position.X-track.AbsolutePosition.X)/math.max(1,track.AbsoluteSize.X),0,1));renderSlider();updateVisuals();emit() end
	end
	local hdrTrack,hdrRender,setHDR=sliderRow("HDR","sun",function() return brightness end,function(v) brightness=math.max(.1,v) end)
	local alphaTrack,alphaRender,setAlpha
	if showAlpha then alphaTrack,alphaRender,setAlpha=sliderRow("Alpha","paint-roller",function() return alpha end,function(v) alpha=v end) end
	actionRow("Copy","copy",function() self._colorClipboard={Color=currentColor(),Alpha=alpha} end)
	actionRow("Paste","clipboard",function() if self._colorClipboard then setColor(self._colorClipboard.Color,self._colorClipboard.Alpha) end end)
	actionRow("Pick","pipette",function()
		if type(options.Eyedropper)=="function" then
			local ok,color,newAlpha=pcall(options.Eyedropper)
			if ok and typeof(color)=="Color3" then setColor(color,newAlpha) end
		end
	end)

	updateVisuals=function()
		sv.BackgroundColor3=Color3.fromHSV(hue,1,1)
		svCursor.Position=UDim2.fromScale(saturation,1-brightness)
		hueCursor.Position=UDim2.fromScale(hue,.5)
		hdrRender()
		if alphaRender then alphaRender() end
	end
	local activeInput,activeSetter,mouseCapture
	local function capture(input,setter)
		local kind=input.UserInputType
		if activeInput or kind~=Enum.UserInputType.MouseButton1 and kind~=Enum.UserInputType.Touch then return end
		activeInput=input;activeSetter=setter;mouseCapture=kind==Enum.UserInputType.MouseButton1;content.ScrollingEnabled=false;setter(input.Position)
	end
	local function setSV(position)
		saturation=math.clamp((position.X-sv.AbsolutePosition.X)/math.max(1,sv.AbsoluteSize.X),0,1)
		brightness=1-math.clamp((position.Y-sv.AbsolutePosition.Y)/math.max(1,sv.AbsoluteSize.Y),0,1)
		updateVisuals();emit()
	end
	local function setHue(position) hue=math.clamp((position.X-hueBar.AbsolutePosition.X)/math.max(1,hueBar.AbsoluteSize.X),0,.999999);updateVisuals();emit() end
	sv.InputBegan:Connect(function(input) capture(input,setSV) end)
	hueBar.InputBegan:Connect(function(input) capture(input,setHue) end)
	hdrTrack.InputBegan:Connect(function(input) capture(input,setHDR) end)
	if alphaTrack then alphaTrack.InputBegan:Connect(function(input) capture(input,setAlpha) end) end
	local changed=UserInputService.InputChanged:Connect(function(input)
		local matches=mouseCapture and input.UserInputType==Enum.UserInputType.MouseMovement or input==activeInput
		if activeInput and matches and activeSetter then activeSetter(input.Position) end
	end)
	local ended=UserInputService.InputEnded:Connect(function(input)
		if input==activeInput or mouseCapture and input.UserInputType==Enum.UserInputType.MouseButton1 then activeInput=nil;activeSetter=nil;mouseCapture=false;content.ScrollingEnabled=true end
	end)
	table.insert(self._popup.Connections,changed);table.insert(self._popup.Connections,ended)
	rebuildPalette();updateVisuals()
	return popup
end

function Section:AddColorPicker(config)
	config = config or {}
	local value = config.Default or Color3.new(1, 1, 1)
	assert(typeof(value) == "Color3", "ColorPicker Default must be Color3")
	local alpha = config.ShowAlpha == false and 1 or math.clamp(tonumber(config.Alpha) or 1, 0, 1)
	local entry = self:_row(config.Name or "Color")
	entry.Label.Size = UDim2.new(1, -52, 1, 0)
	entry.Label.TextTruncate = Enum.TextTruncate.AtEnd
	local swatch = create("Frame", {
		Name = "Color",
		AnchorPoint = Vector2.new(0, .5),
		Position = UDim2.new(1, -34, .5, 0),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = value,
		BackgroundTransparency = 1 - alpha,
		BorderSizePixel = 0,
		ZIndex = 10,
		Parent = entry.Row,
	})
	addCorner(swatch, 5)
	addStroke(swatch, self.Library.Theme.ElementOverlay, self.Library.Theme.ElementOverlayHoverAlpha)
	local swatchHit = makeButton(entry.Row, {AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-2,.5,0),Size=UDim2.new(0,44,1,0),ZIndex=13})
	local handle
	local function set(color, newAlpha, fire, source)
		assert(typeof(color) == "Color3", "ColorPicker value must be Color3")
		value = color
		if config.ShowAlpha == false then alpha = 1
		elseif newAlpha ~= nil then alpha = math.clamp(tonumber(newAlpha) or alpha, 0, 1) end
		swatch.BackgroundColor3 = color
		swatch.BackgroundTransparency = 1 - alpha
		if fire and config.Callback then task.spawn(config.Callback, color, alpha, {Source = source or "user"}) end
		if fire then self.Library:_controlChanged(config.Flag or config.Id, handle and handle:Export() or color, source) end
	end
	swatchHit.Activated:Connect(function()
		self.Library:_openColorPopup(swatch, value, function(color, newAlpha) set(color, newAlpha, true, "user") end, {
			Title = stripId(config.Name or "Color"), Alpha = alpha, ShowAlpha = config.ShowAlpha ~= false,
			Presets = config.Presets, Style = config.Style, Eyedropper = config.Eyedropper,
		})
	end)
	handle = {
		Get=function() return value end,
		GetAlpha=function() return alpha end,
		Set=function(_,color,newAlpha,fire) set(color,newAlpha,fire~=false,"api") end,
		Export=function() return {Color=value,Alpha=alpha} end,
		Import=function(_,imported,fire,source)
			if typeof(imported)=="Color3" then set(imported,alpha,fire~=false,source or "config")
			elseif type(imported)=="table" then set(imported.Color or imported.Value,imported.Alpha,fire~=false,source or "config")
			else error("Invalid ColorPicker config value") end
		end,
		Fire=function(_,source) if config.Callback then task.spawn(config.Callback,value,alpha,{Source=source or "api"}) end end,
		Instance=entry.Row,
	}
	return self.Library:_registerFlag(config,handle,"color")
end

function Section:AddKeybind(config)
	config = config or {}
	local value = config.Default or Enum.KeyCode.Unknown
	if typeof(value) == "string" then value = Enum.KeyCode[value] or Enum.KeyCode.Unknown end
	assert(typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode, "Keybind Default must be Enum.KeyCode")
	local listening = false
	local entry = self:_row(config.Name or "Keybind")
	entry.Label.Size = UDim2.new(.5, -12, 1, 0)
	entry.Label.TextTruncate = Enum.TextTruncate.AtEnd
	local key = makeText(entry.Row, value.Name, 11, self.Library.Theme.TextDim, {
		AnchorPoint = Vector2.new(0, .5),
		Position = UDim2.new(.5, 0, .5, 0),
		Size = UDim2.new(.5, -12, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 10,
	})
	local handle
	local function set(newValue, fire, source)
		if type(newValue) == "string" then newValue = Enum.KeyCode[newValue] end
		assert(typeof(newValue) == "EnumItem" and newValue.EnumType == Enum.KeyCode, "Keybind value must be Enum.KeyCode")
		value = newValue
		key.Text = value.Name
		if fire and config.Callback then task.spawn(config.Callback, value, {Source = source or "user"}) end
		if fire then self.Library:_controlChanged(config.Flag or config.Id, value, source) end
	end
	local function cancelListening()
		listening = false
		if self.Library._listeningKeybind == handle then self.Library._listeningKeybind = nil end
		key.Text = value.Name
	end
	entry.Hitbox.Activated:Connect(function()
		if self.Library._listeningKeybind and self.Library._listeningKeybind ~= handle then
			self.Library._listeningKeybind:Cancel()
		end
		listening = true
		self.Library._listeningKeybind = handle
		key.Text = "..."
	end)
	local connection = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if listening and input.KeyCode ~= Enum.KeyCode.Unknown then
			if input.KeyCode == Enum.KeyCode.Escape then cancelListening(); return end
			local newValue = input.KeyCode == Enum.KeyCode.Backspace and Enum.KeyCode.Unknown or input.KeyCode
			cancelListening()
			set(newValue, true, "user")
		end
	end)
	table.insert(self.Library._connections, connection)
	handle = {
		Get=function() return value end,
		Set=function(_,newValue,fire,source) set(newValue,fire~=false,source or "api") end,
		Cancel=cancelListening,
		Export=function() return value end,
		Import=function(_,imported,fire,source) set(imported,fire~=false,source or "config") end,
		Fire=function(_,source) if config.Callback then task.spawn(config.Callback,value,{Source=source or "api"}) end end,
		Instance=entry.Row,
	}
	return self.Library:_registerFlag(config,handle,"keybind")
end

function Section:AddInput(config)
	config = config or {}
	local value = config.Default ~= nil and tostring(config.Default) or ""
	if config.Numeric and value ~= "" then
		local initialNumber = tonumber(value)
		assert(initialNumber and initialNumber == initialNumber and initialNumber ~= math.huge and initialNumber ~= -math.huge, "Input Default must be a finite number")
		value = tostring(initialNumber)
	end
	local entry = self:_row(config.Name or "Input")
	entry.Label.Size = UDim2.new(.46, -12, 1, 0)
	local field = create("TextBox", {
		Name = "Input",
		AnchorPoint = Vector2.new(0, .5),
		Position = UDim2.new(.46, 0, .5, 0),
		Size = UDim2.new(.54, -12, 0, 26),
		BackgroundColor3 = self.Library.Theme.ElementOverlay,
		BackgroundTransparency = tr(self.Library.Theme.ElementOverlayAlpha),
		ClearTextOnFocus = config.ClearOnFocus == true,
		PlaceholderText = config.Placeholder or "",
		PlaceholderColor3 = self.Library.Theme.TextDim,
		Text = value,
		TextColor3 = self.Library.Theme.Text,
		TextSize = 12,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 13,
		Parent = entry.Row,
	})
	addCorner(field, 7)
	addStroke(field, self.Library.Theme.ElementOverlay, self.Library.Theme.ElementOverlayHoverAlpha)
	create("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = field})
	local handle
	local function set(newValue, fire, source)
		newValue = tostring(newValue or "")
		if config.MaxLength then newValue = string.sub(newValue, 1, math.max(0, tonumber(config.MaxLength) or 0)) end
		if config.Numeric and newValue ~= "" then
			local number = tonumber(newValue)
			assert(number and number == number and number ~= math.huge and number ~= -math.huge, "Input value must be a finite number")
			newValue = tostring(number)
		end
		if config.Validate then
			local accepted, replacement = config.Validate(newValue)
			assert(accepted ~= false, replacement or "Input value was rejected")
			if replacement ~= nil then newValue = tostring(replacement) end
		end
		if config.Numeric and newValue ~= "" then
			local number = tonumber(newValue)
			assert(isFiniteNumber(number), "Validated input value must be a finite number")
			newValue = tostring(number)
		end
		value = newValue
		field.Text = value
		if fire and config.Callback then task.spawn(config.Callback, config.Numeric and tonumber(value) or value, {Source = source or "user"}) end
		if fire then self.Library:_controlChanged(config.Flag or config.Id, value, source) end
	end
	field.FocusLost:Connect(function()
		local ok = pcall(set, field.Text, true, "user")
		if not ok then field.Text = value end
	end)
	handle = {
		Get = function() return config.Numeric and tonumber(value) or value end,
		Set = function(_, newValue, fire, source) set(newValue, fire ~= false, source or "api") end,
		Focus = function() field:CaptureFocus() end,
		Export = function() return config.Numeric and tonumber(value) or value end,
		Import = function(_, imported, fire, source) set(imported, fire ~= false, source or "config") end,
		Fire = function(_, source) if config.Callback then task.spawn(config.Callback, config.Numeric and tonumber(value) or value, {Source = source or "api"}) end end,
		Instance = entry.Row,
	}
	return self.Library:_registerFlag(config, handle, "input")
end

Section.Toggle = Section.AddToggle
Section.Button = Section.AddButton
Section.Dropdown = Section.AddDropdown
Section.Slider = Section.AddSlider
Section.ColorPicker = Section.AddColorPicker
Section.Keybind = Section.AddKeybind
Section.Label = Section.AddLabel
Section.Input = Section.AddInput

function Library:SetAccent(color)
	assert(typeof(color) == "Color3", "Accent must be Color3")
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
		self.Window.Visible = true
		self.Window.GroupTransparency = 1
		play(self.Window, .20, {GroupTransparency = 0})
	else
		local animation = play(self.Window, .20, {GroupTransparency = 1})
		animation.Completed:Once(function()
			if token == self._visibilityToken and not self._visible then self.Window.Visible = false end
		end)
	end
end

function Library:Toggle()
	self:SetVisible(not self._visible)
end

function Library:_notificationStyle(kind)
	kind = string.lower(tostring(kind or "info"))
	if kind == "success" then return Color3.fromRGB(105, 225, 135), "check" end
	if kind == "warning" then return Color3.fromRGB(255, 190, 75), "triangle-alert" end
	if kind == "error" or kind == "danger" then return Color3.fromRGB(255, 95, 105), "circle-x" end
	return self.Theme.Accent, "info"
end

function Library:_renderLegacyNotification(handle)
	local view = handle.View
	if not view or not view.Card.Parent then return end
	if view.Content then view.Content:Destroy() end
	local config = handle.Config
	local card = view.Card
	local width = math.max(160, self.NotificationHost.Size.X.Offset)
	local contentWidth = width - 54
	local bodyText = tostring(config.Text or config.Description or "")
	local bodyBounds = TextService:GetTextSize(bodyText, 12, Enum.Font.Gotham, Vector2.new(contentWidth, 1000))
	local bodyHeight = bodyText == "" and 0 or math.clamp(math.ceil(bodyBounds.Y), 16, config.Expanded and 160 or 58)
	local actions = type(config.Actions) == "table" and config.Actions or {}
	local actionHeight = #actions > 0 and (self._touchMode and 44 or 34) or 0
	local contentBottom = 34 + (bodyHeight > 0 and bodyHeight + 6 or 0)
	local height = math.max(66, contentBottom + actionHeight + (#actions > 0 and 12 or 8))
	view.Height = height
	view.Wrapper.Size = UDim2.new(1, 0, 0, height)
	card.Size = UDim2.fromScale(1, 1)
	local content = create("Frame", {Name="Content",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=202,Parent=card})
	view.Content = content
	local accent, iconName = self:_notificationStyle(config.Type)
	makeIcon(self, content, config.Icon or iconName, 18, accent, {
		Position=UDim2.fromOffset(13,12),Size=UDim2.fromOffset(18,18),ZIndex=204,
	})
	local countText = handle.Count > 1 and ("  ×" .. handle.Count) or ""
	makeText(content, tostring(config.Title or "Notification") .. countText, 13, self.Theme.Text, {
		Position=UDim2.fromOffset(40,7),Size=UDim2.new(1,-78,0,26),Font=Enum.Font.GothamBold,
		TextTransparency=tr(self.Theme.TextAlpha),TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=204,
	})
	if config.Closable ~= false then
		local close = makeButton(content,{Position=UDim2.new(1,-36,0,5),Size=UDim2.fromOffset(30,30),ZIndex=207})
		makeIcon(self,close,"x",14,self.Theme.TextDim,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(14,14),ZIndex=208})
		close.Activated:Connect(function() handle:Close("dismissed") end)
	end
	if bodyHeight > 0 then
		makeText(content,bodyText,12,self.Theme.TextDim,{
			Position=UDim2.fromOffset(40,33),Size=UDim2.new(1,-54,0,bodyHeight),TextWrapped=true,
			TextYAlignment=Enum.TextYAlignment.Top,TextTruncate=config.Expanded and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd,ZIndex=204,
		})
	end
	if #actions > 0 then
		local holder=create("Frame",{Position=UDim2.fromOffset(40,height-actionHeight-8),Size=UDim2.new(1,-52,0,actionHeight),BackgroundTransparency=1,ZIndex=204,Parent=content})
		create("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,HorizontalAlignment=Enum.HorizontalAlignment.Right,Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder,Parent=holder})
		local visibleActionCount=math.min(2,#actions)
		local maximumActionWidth=(width-52-6*(visibleActionCount-1))/visibleActionCount
		for index,action in ipairs(actions) do
			if index > 2 then break end
			local actionWidth=math.max(48,math.min(maximumActionWidth,140,TextService:GetTextSize(tostring(action.Text or "Action"),12,Enum.Font.Gotham,Vector2.new(200,30)).X+(action.Icon and 42 or 24)))
			local button=makeButton(holder,{Size=UDim2.fromOffset(actionWidth,actionHeight),BackgroundColor3=action.Style=="danger" and Color3.fromRGB(120,35,40) or dim(accent,.45),BackgroundTransparency=action.Style=="ghost" and .75 or .15,ZIndex=205})
			addCorner(button,8);addStroke(button,self.Theme.PopupOutline,.12)
			if action.Icon then
				makeIcon(self,button,action.Icon,13,self.Theme.Text,{AnchorPoint=Vector2.new(0,.5),Position=UDim2.new(0,10,.5,0),Size=UDim2.fromOffset(13,13),ZIndex=206})
				makeText(button,tostring(action.Text or "Action"),12,self.Theme.Text,{Position=UDim2.fromOffset(29,0),Size=UDim2.new(1,-35,1,0),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=206})
			else
				makeText(button,tostring(action.Text or "Action"),12,self.Theme.Text,{TextXAlignment=Enum.TextXAlignment.Center,ZIndex=206})
			end
			local busy=false
			button.Activated:Connect(function()
				if busy then return end
				busy=true
				local revision=handle.Revision
				task.spawn(function()
					local ok,result=pcall(function() return action.Callback and action.Callback(handle) end)
					if not ok then warn("[EvernessUI] Notification action failed: "..tostring(result)) end
					busy=false
					if ok and result~=false and action.Close~=false and handle.Revision==revision then handle:Close("action") end
				end)
			end)
		end
	end
	local progress=create("Frame",{Name="Progress",AnchorPoint=Vector2.new(0,1),Position=UDim2.fromScale(0,1),Size=UDim2.new(1,0,0,3),BackgroundColor3=accent,BackgroundTransparency=.08,ZIndex=205,Parent=content})
	view.Progress=progress
	self:_updateNotificationProgress(handle)
end

-- Source-style alerts from alerts/alerts.cpp. Queue/dedupe/progress handling is
-- intentionally kept separate, so changing the presentation cannot break it.
function Library:_renderNotification(handle)
	local view=handle.View
	if not view or not view.Card.Parent then return end
	if view.Content then view.Content:Destroy() end
	local config=handle.Config
	local card=view.Card
	local width=math.max(160,self.NotificationHost.Size.X.Offset)
	local bodyText=tostring(config.Text or config.Description or "")
	local actions=type(config.Actions)=="table" and config.Actions or {}
	local contentWidth=width-30
	local bodyBounds=TextService:GetTextSize(bodyText,12,Enum.Font.Gotham,Vector2.new(contentWidth,1000))
	local bodyHeight=bodyText=="" and 0 or math.clamp(math.ceil(bodyBounds.Y),16,120)
	local buttonHeight=self._touchMode and 48 or 44
	local visibleActions=math.min(2,#actions)
	local actionsHeight=visibleActions*(buttonHeight+4)
	local height=math.max(116,58+bodyHeight+(bodyHeight>0 and 12 or 0)+actionsHeight+10)
	view.Height=height
	view.Wrapper.Size=UDim2.new(1,0,0,height)
	card.Size=UDim2.fromScale(1,1)
	local content=create("Frame",{Name="AlertContent",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=202,Parent=card})
	view.Content=content
	local countText=handle.Count>1 and ("  ×"..handle.Count) or ""
	makeText(content,tostring(config.Title or "Notification")..countText,16,self.Theme.Text,{
		Position=UDim2.fromOffset(15,12),Size=UDim2.new(1,-30,0,34),Font=Enum.Font.GothamBold,
		TextTransparency=tr(self.Theme.TextAlpha),TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=204,
	})
	if bodyHeight>0 then
		makeText(content,bodyText,12,self.Theme.TextDim,{
			Position=UDim2.fromOffset(15,52),Size=UDim2.new(1,-30,0,bodyHeight),TextWrapped=true,
			TextYAlignment=Enum.TextYAlignment.Top,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=204,
		})
	end
	if config.Closable==true then
		local close=makeButton(content,{Position=UDim2.new(1,-38,0,9),Size=UDim2.fromOffset(28,28),ZIndex=207})
		makeIcon(self,close,"x",13,self.Theme.TextDim,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(13,13),ZIndex=208})
		close.Activated:Connect(function() handle:Close("dismissed") end)
	end
	local startY=height-10-actionsHeight
	for index=1,visibleActions do
		local action=actions[index]
		local primary=index==1 and action.Style~="ghost"
		local button=makeButton(content,{
			Position=UDim2.fromOffset(10,startY+(index-1)*(buttonHeight+4)),Size=UDim2.new(1,-20,0,buttonHeight),
			BackgroundColor3=primary and dim(self.Theme.Accent,.6) or self.Theme.Element,
			BackgroundTransparency=primary and 0 or tr(self.Theme.ElementAlpha),ZIndex=205,
		})
		addCorner(button,64);addStroke(button,primary and dim(self.Theme.Accent,.8) or self.Theme.ElementOutline,1)
		makeText(button,tostring(action.Text or "OK"),12,self.Theme.Text,{TextXAlignment=Enum.TextXAlignment.Center,Font=Enum.Font.GothamMedium,ZIndex=206})
		local busy=false
		button.Activated:Connect(function()
			if busy then return end
			busy=true
			task.spawn(function()
				local ok,result=pcall(function() return action.Callback and action.Callback(handle) end)
				if not ok then warn("[EvernessUI] Notification action failed: "..tostring(result)) end
				busy=false
				if ok and result~=false and action.Close~=false then handle:Close("action") end
			end)
		end)
	end
	local accent=self:_notificationStyle(config.Type)
	local progress=create("Frame",{Name="Progress",AnchorPoint=Vector2.new(0,1),Position=UDim2.fromScale(0,1),Size=UDim2.new(1,0,0,2),BackgroundColor3=accent,BackgroundTransparency=.08,ZIndex=205,Visible=false,Parent=content})
	view.Progress=progress
	self:_updateNotificationProgress(handle)
end

function Library:_updateNotificationProgress(handle)
	local view=handle.View
	if not view or not view.Progress then return end
	local progress=handle.Config.Progress
	local alpha
	if type(progress)=="number" then alpha=math.clamp(progress,0,1)
	elseif handle.Duration>0 then alpha=math.clamp(handle.Remaining/handle.Duration,0,1)
	else alpha=1 end
	view.Progress.Visible = type(progress)=="number" or (handle.Config.ShowTimer==true and handle.Config.Persistent~=true and handle.Duration>0)
	view.Progress.Size=UDim2.new(alpha,0,0,3)
end

function Library:_mountNotification(handle)
	handle.State="visible"
	if handle.Remaining<=0 then handle.Remaining=handle.Duration end
	table.insert(self._visibleNotifications,handle)
	local wrapper=create("Frame",{Name="NotificationSlot",Size=UDim2.new(1,0,0,0),BackgroundTransparency=1,ClipsDescendants=false,LayoutOrder=-handle.Priority*100000+handle.Sequence,ZIndex=200,Parent=self.NotificationHost})
	local card=create("CanvasGroup",{Name="Alert",Position=UDim2.fromOffset(0,12),Size=UDim2.fromScale(1,1),BackgroundColor3=self.Theme.Window,BackgroundTransparency=tr(self.Theme.WindowAlpha),GroupTransparency=1,Active=true,ZIndex=201,Parent=wrapper})
	addCorner(card,16);addStroke(card,self.Theme.Border,self.Theme.BorderAlpha)
	handle.View={Wrapper=wrapper,Card=card}
	self:_renderNotification(handle)
	card.Position=UDim2.fromOffset(0,12)
	play(card,.18,{Position=UDim2.fromOffset(0,0),GroupTransparency=0})
	card.MouseEnter:Connect(function() if self._notificationOptions.PauseOnHover~=false then handle:Pause() end end)
	card.MouseLeave:Connect(function() if self._notificationOptions.PauseOnHover~=false then handle:Resume() end end)
	local swipeInput,swipeStart
	table.insert(handle.Connections,card.InputBegan:Connect(function(input)
		if input.UserInputType~=Enum.UserInputType.Touch or swipeInput then return end
		if hasInteractiveDescendantAt(card,input.Position) then return end
		swipeInput=input;swipeStart=input.Position
	end))
	table.insert(handle.Connections,UserInputService.InputChanged:Connect(function(input)
		if input~=swipeInput or not swipeStart or not handle.View then return end
		local delta=input.Position.X-swipeStart.X
		if math.abs(delta)<8 then return end
		card.Position=UDim2.fromOffset(delta,0)
		card.GroupTransparency=math.clamp(math.abs(delta)/math.max(1,card.AbsoluteSize.X),0,.75)
	end))
	table.insert(handle.Connections,UserInputService.InputEnded:Connect(function(input)
		if input~=swipeInput then return end
		local delta=input.Position.X-swipeStart.X
		swipeInput=nil;swipeStart=nil
		if math.abs(delta)>=math.max(56,card.AbsoluteSize.X*.25) then handle:Close("swipe") else play(card,.12,{Position=UDim2.fromOffset(0,0),GroupTransparency=0}) end
	end))
end

function Library:_notificationLimit()
	local configured = self._mobile and self._notificationOptions.MobileMaxVisible or self._notificationOptions.MaxVisible
	return math.clamp(math.floor(tonumber(configured) or 1), 1, 12)
end

function Library:_notificationStackTooTall()
	if #self._visibleNotifications <= 1 then return false end
	local viewport = getViewportSize()
	local safeTopLeft, safeBottomRight = Vector2.zero, Vector2.zero
	local insetOk, first, second = pcall(function() return GuiService:GetGuiInset() end)
	if insetOk then safeTopLeft, safeBottomRight = first, second end
	local margin = tonumber(self._responsive.Margin) or 10
	local budget = math.max(120, viewport.Y - safeTopLeft.Y - safeBottomRight.Y - margin * 2)
	local gap = tonumber(self._notificationOptions.Gap) or 8
	local total = math.max(0, #self._visibleNotifications - 1) * gap
	for _, handle in ipairs(self._visibleNotifications) do
		total += handle.View and handle.View.Height or 0
	end
	return total > budget
end

function Library:_demoteNotification(handle)
	if not handle or handle.State ~= "visible" then return false end
	local visibleIndex = table.find(self._visibleNotifications, handle)
	if visibleIndex then table.remove(self._visibleNotifications, visibleIndex) end
	for _, connection in ipairs(handle.Connections) do connection:Disconnect() end
	table.clear(handle.Connections)
	if handle.View and handle.View.Wrapper.Parent then handle.View.Wrapper:Destroy() end
	handle.View = nil
	handle.State = "queued"
	if not table.find(self._notificationQueue, handle) then table.insert(self._notificationQueue, handle) end
	return true
end

function Library:_syncNotifications()
	if #self._visibleNotifications==0 and #self._notificationQueue==0 then return end
	local maximum=self:_notificationLimit()
	table.sort(self._visibleNotifications,function(a,b) return a.Priority==b.Priority and a.Sequence<b.Sequence or a.Priority>b.Priority end)
	while #self._visibleNotifications>maximum do
		self:_demoteNotification(self._visibleNotifications[#self._visibleNotifications])
	end
	for _,handle in ipairs(self._visibleNotifications) do self:_renderNotification(handle) end
	while self:_notificationStackTooTall() do
		table.sort(self._visibleNotifications,function(a,b) return a.Priority==b.Priority and a.Sequence<b.Sequence or a.Priority>b.Priority end)
		self:_demoteNotification(self._visibleNotifications[#self._visibleNotifications])
	end
	self:_pumpNotifications()
end

function Library:_pumpNotifications()
	local maxVisible=self:_notificationLimit()
	table.sort(self._notificationQueue,function(a,b) return a.Priority==b.Priority and a.Sequence<b.Sequence or a.Priority>b.Priority end)
	while #self._visibleNotifications>=maxVisible and #self._notificationQueue>0 do
		local worst
		for _,candidate in ipairs(self._visibleNotifications) do
			if not worst or candidate.Priority<worst.Priority or candidate.Priority==worst.Priority and candidate.Sequence>worst.Sequence then worst=candidate end
		end
		if not worst or self._notificationQueue[1].Priority<=worst.Priority then break end
		self:_demoteNotification(worst)
		table.sort(self._notificationQueue,function(a,b) return a.Priority==b.Priority and a.Sequence<b.Sequence or a.Priority>b.Priority end)
	end
	while #self._visibleNotifications<maxVisible and #self._notificationQueue>0 do
		local handle=table.remove(self._notificationQueue,1)
		if handle.State=="queued" then
			self:_mountNotification(handle)
			if self:_notificationStackTooTall() then
				table.sort(self._visibleNotifications,function(a,b) return a.Priority==b.Priority and a.Sequence<b.Sequence or a.Priority>b.Priority end)
				self:_demoteNotification(self._visibleNotifications[#self._visibleNotifications])
				break
			end
		end
	end
	if not self._notificationHeartbeat then
		self._notificationHeartbeat=RunService.Heartbeat:Connect(function(delta)
			for index=#self._visibleNotifications,1,-1 do
				local handle=self._visibleNotifications[index]
				if handle.State=="visible" and not handle.Paused and handle.Duration>0 and handle.Config.Persistent~=true then
					handle.Remaining-=delta
					self:_updateNotificationProgress(handle)
					if handle.Remaining<=0 then handle:Close("timeout") end
				end
			end
		end)
		table.insert(self._connections,self._notificationHeartbeat)
	end
end

function Library:_closeNotification(handle, reason, immediate)
	if handle.State=="closed" then return end
	handle.State="closed"
	handle.CloseReason=reason
	if handle.Key and self._notificationsByKey[handle.Key]==handle then self._notificationsByKey[handle.Key]=nil end
	local queueIndex=table.find(self._notificationQueue,handle)
	if queueIndex then table.remove(self._notificationQueue,queueIndex) end
	local visibleIndex=table.find(self._visibleNotifications,handle)
	if visibleIndex then table.remove(self._visibleNotifications,visibleIndex) end
	for _,connection in ipairs(handle.Connections) do connection:Disconnect() end
	table.clear(handle.Connections)
	local view=handle.View
	if view and view.Wrapper.Parent then
		if immediate then view.Wrapper:Destroy()
		else
			local animation=play(view.Card,.14,{Position=UDim2.fromOffset(0,12),GroupTransparency=1})
			animation.Completed:Once(function()
				if view.Wrapper.Parent then
					local collapse=play(view.Wrapper,.12,{Size=UDim2.new(1,0,0,0)})
					collapse.Completed:Once(function() if view.Wrapper.Parent then view.Wrapper:Destroy() end end)
				end
			end)
		end
	end
	handle.View=nil
	self:_pumpNotifications()
end

function Library:Notify(config)
	if type(config)=="string" then config={Text=config} end
	config=table.clone(config or {})
	local key=config.Id or config.DedupeKey
	if key then key=tostring(key) end
	local existing=key and self._notificationsByKey[key]
	if existing and existing.State~="closed" then
		local mode=string.lower(tostring(config.DedupeMode or "replace"))
		if mode=="ignore" then return existing end
		if mode=="count" then existing.Count+=1;existing:Update(config) else existing:Replace(config) end
		return existing
	end
	self._notificationSequence+=1
	local handle={
		Library=self,Config=config,Key=key,Sequence=self._notificationSequence,Priority=tonumber(config.Priority) or 0,
		Duration=math.max(0,tonumber(config.Duration) or tonumber(self._notificationOptions.DefaultDuration) or 4.5),
		Remaining=0,Paused=false,Count=1,Revision=0,State="queued",Connections={},
	}
	function handle:Update(changes)
		if self.State=="closed" then return self end
		self.Revision+=1
		for name,value in pairs(changes or {}) do self.Config[name]=value end
		for _,name in ipairs(changes and changes.Clear or {}) do self.Config[name]=nil end
		self.Config.Clear=nil
		if changes and changes.Duration~=nil then self:SetDuration(changes.Duration) else self.Remaining=self.Duration end
		if changes and changes.Priority~=nil then self.Priority=tonumber(changes.Priority) or self.Priority end
		if self.View then self.View.Wrapper.LayoutOrder=-self.Priority*100000+self.Sequence end
		self.Library:_syncNotifications()
		return self
	end
	function handle:Replace(replacement)
		if self.State=="closed" then return self end
		self.Revision+=1
		self.Config=table.clone(replacement or {})
		self.Count=1
		self.Priority=tonumber(self.Config.Priority) or 0
		self.Duration=math.max(0,tonumber(self.Config.Duration) or tonumber(self.Library._notificationOptions.DefaultDuration) or 4.5)
		self.Remaining=self.Duration
		if self.View then self.View.Wrapper.LayoutOrder=-self.Priority*100000+self.Sequence end
		self.Library:_syncNotifications()
		return self
	end
	function handle:SetProgress(value) self.Config.Progress=value;self.Library:_updateNotificationProgress(self);return self end
	function handle:SetDuration(value) self.Duration=math.max(0,tonumber(value) or 0);self.Remaining=self.Duration;self.Library:_updateNotificationProgress(self);return self end
	function handle:Pause() self.Paused=true;return self end
	function handle:Resume() self.Paused=false;return self end
	function handle:Close(reason) self.Library:_closeNotification(self,reason or "closed");return self end
	function handle:IsOpen() return self.State~="closed" end
	if key then self._notificationsByKey[key]=handle end
	table.insert(self._notificationQueue,handle)
	local maxQueued=tonumber(self._notificationOptions.MaxQueued) or 30
	if #self._notificationQueue>maxQueued then
		table.sort(self._notificationQueue,function(a,b) return a.Priority==b.Priority and a.Sequence<b.Sequence or a.Priority>b.Priority end)
		self:_closeNotification(table.remove(self._notificationQueue),"queue-overflow",true)
	end
	self:_pumpNotifications()
	return handle
end

function Library:ClearNotifications(reason)
	local all={}
	for _,handle in ipairs(self._notificationQueue) do table.insert(all,handle) end
	for _,handle in ipairs(self._visibleNotifications) do table.insert(all,handle) end
	for _,handle in ipairs(all) do self:_closeNotification(handle,reason or "cleared",true) end
end

function Library:Destroy()
	if self._destroyed then return end
	self._destroyed = true
	self:ClosePopup()
	self:ClearNotifications("destroyed")
	if self._listeningKeybind then self._listeningKeybind:Cancel() end
	for _, connection in ipairs(self._connections) do
		pcall(function() connection:Disconnect() end)
	end
	table.clear(self._connections)
	table.clear(self._accentBindings)
	table.clear(self._configListeners)
	table.clear(self._flags)
	if self.Gui then self.Gui:Destroy() end
end

function Library.CreateWindow(first, second)
	return Library.new(first == Library and second or first)
end
Library.Theme = DEFAULT_THEME

return Library
