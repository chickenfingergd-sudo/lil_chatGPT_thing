-- ESP STUDIO / Aurora edition
-- ESP Studio movement backend: fps-v3
-- ESP Studio settings storage: auto-v1
-- Standalone LocalScript: StarterPlayer > StarterPlayerScripts.
-- RightShift opens the console. Settings auto-save when runtime file storage is available.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local defaults = {
	Enabled = true, ShowNames = true, ShowHealth = true, ShowDistance = true,
	ShowHighlights = true, ShowBoxes = true, ShowTracers = false,
	TeamCheck = false, HideDead = true, UseTeamColors = false, ThroughWalls = true,
	MaxDistance = 1000, MarkerScale = 1, HighlightFillTransparency = 0.8,
	HighlightOutlineTransparency = 0.15, TracerWidth = 1.5, TracerOpacity = 0.7,
	TracerOrigin = "Bottom", PulseTracers = true, ReducedMotion = false,
	UIScale = 1, Theme = "Glacier", CustomAccent = Color3.fromRGB(114, 193, 255),
	PanelStyle = "Midnight", PanelOpacity = 1, UIEffects = true, UIMotionSpeed = 1,
	NavigationStyle = "Adaptive",
	AimEnabled = false, AimTeamCheck = true, AimVisibilityCheck = true, AimShowRadius = true,
	AimRadius = 140, AimRange = 800, AimSmoothTime = 0.12, AimPart = "Head", AimKey = "RMB",
	AimRadiusFullScreen = false,
	MovementEnabled = false, MovementSpeed = true, MovementJump = true, MovementSprint = true,
	MovementWalkSpeed = 16, MovementSprintSpeed = 28, MovementJumpHeight = 7.2,
	MovementSmoothTime = 0.18, MovementSprintMode = "Hold", MovementKeepOnRespawn = true,
	MovementShowHUD = true,
	MovementBackend = "Auto",
	MovementMaintain = true,
	EnemyColor = Color3.fromRGB(255, 109, 139),
	FriendlyColor = Color3.fromRGB(100, 218, 255),
}
local settings: {[string]: any} = table.clone(defaults)
local persistence: {[string]: any} = {
	file = "ESPStudio-settings-v1-" .. tostring(localPlayer.UserId) .. ".json",
	attribute = "ESPStudioSettingsV1", pending = false, closed = false,
	ownerAttribute = "ESPStudioSettingsOwner",
	ranges = {
		MaxDistance = {100, 5000, 50}, MarkerScale = {0.75, 1.4, 0.05},
		HighlightFillTransparency = {0, 1, 0.05}, HighlightOutlineTransparency = {0, 1, 0.05},
		TracerWidth = {1, 4, 0.25}, TracerOpacity = {0.1, 1, 0.05}, UIScale = {0.75, 1.15, 0.05},
		PanelOpacity = {0.55, 1, 0.05}, UIMotionSpeed = {0.5, 2, 0.25},
		AimRadius = {40, math.huge, 5}, AimRange = {100, 2000, 50}, AimSmoothTime = {0, 0.5, 0.01},
		MovementWalkSpeed = {0, 160, 0.5}, MovementSprintSpeed = {0, 240, 0.5},
		MovementJumpHeight = {0, 150, 0.1}, MovementSmoothTime = {0, 1, 0.01},
	},
	choices = {
		Theme = {"Glacier", "Violet", "Mint", "Ember", "Rose", "Gold", "Custom"},
		PanelStyle = {"Midnight", "Graphite", "Dusk", "Deep Sea"}, NavigationStyle = {"Adaptive", "Tabs only"},
		TracerOrigin = {"Bottom", "Center", "Cursor"},
		AimPart = {"Head", "Body"}, AimKey = {"RMB", "Q"}, MovementSprintMode = {"Hold", "Toggle"},
		MovementBackend = {"Auto", "Humanoid", "Controller"},
	},
}
function persistence.Status(text)
	persistence.status = text
	if persistence.label then persistence.label.Text = text end
end
function persistence.Finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end
function persistence.Decode(source)
	if type(source) ~= "string" or #source > 65536 then return nil end
	local ok, data = pcall(function() return HttpService:JSONDecode(source) end)
	if not ok or type(data) ~= "table" or data.version ~= 1 or type(data.settings) ~= "table" then return nil end
	local result = table.clone(defaults)
	for key, default in defaults do
		local value = data.settings[key]
		if key == "EnemyColor" or key == "FriendlyColor" or key == "CustomAccent" then
			if type(value) == "table" and persistence.Finite(value[1]) and persistence.Finite(value[2]) and persistence.Finite(value[3])
				and value[1] >= 0 and value[1] <= 1 and value[2] >= 0 and value[2] <= 1 and value[3] >= 0 and value[3] <= 1 then
				result[key] = Color3.new(value[1], value[2], value[3])
			end
		elseif type(default) == "boolean" and type(value) == "boolean" then result[key] = value
		elseif type(default) == "number" and persistence.Finite(value) then
			local range = persistence.ranges[key]
			if range then result[key] = math.clamp(range[1] + math.floor((value - range[1]) / range[3] + 0.5) * range[3], range[1], range[2]) end
		elseif persistence.choices[key] and table.find(persistence.choices[key], value) then result[key] = value end
	end
	return result
end
function persistence.Encode()
	local values = {}
	for key in defaults do
		local value = settings[key]
		values[key] = (key == "EnemyColor" or key == "FriendlyColor" or key == "CustomAccent") and {value.R, value.G, value.B} or value
	end
	return HttpService:JSONEncode({version = 1, settings = values})
end
function persistence.Changed()
	for key in defaults do if settings[key] ~= persistence.saved[key] then return true end end
	return false
end
function persistence.Flush(force)
	if persistence.token ~= localPlayer:GetAttribute(persistence.ownerAttribute) then return false end
	if not force and not persistence.Changed() then return true end
	local ok, encoded = pcall(persistence.Encode)
	if not ok then persistence.Status("Could not encode settings; use Save now to retry"); return false end
	local cached = pcall(function() localPlayer:SetAttribute(persistence.attribute, encoded) end)
	local written = false
	if persistence.disk then
		local okWrite, result = pcall(persistence.writeFile, persistence.file, encoded)
		written = okWrite and result ~= false
	end
	if written then persistence.Status("Saved on this device / auto-save on")
	elseif cached then persistence.Status(persistence.disk and "Session saved / device save failed; try Save now" or "Session only / device storage unavailable")
	else persistence.Status("Saving unavailable / use Save now to retry") end
	if written or cached then persistence.saved = table.clone(settings) end
	return written or cached
end
function persistence.Schedule()
	if persistence.closed or not persistence.Changed() then return end
	if persistence.token ~= localPlayer:GetAttribute(persistence.ownerAttribute) then return end
	-- Keep reruns current even when Destroying is deferred and the disk write is pending.
	local encoded, source = pcall(persistence.Encode)
	if encoded then pcall(function() localPlayer:SetAttribute(persistence.attribute, source) end) end
	if persistence.pending then return end
	persistence.pending = true
	persistence.Status("Saving settings...")
	task.delay(0.4, function()
		persistence.pending = false
		if not persistence.closed then persistence.Flush() end
	end)
end
function persistence.Load()
	local environment = getfenv()
	persistence.readFile, persistence.writeFile = environment.readfile, environment.writefile
	persistence.disk = type(persistence.readFile) == "function" and type(persistence.writeFile) == "function"
	local cached, source = pcall(function() return localPlayer:GetAttribute(persistence.attribute) end)
	local restored = cached and persistence.Decode(source) or nil
	local fromSession, invalid = restored ~= nil, false
	if not restored and persistence.disk then
		local shouldRead, knownExists = true, false
		if type(environment.isfile) == "function" then
			local checked, exists = pcall(environment.isfile, persistence.file)
			if checked and exists == false then shouldRead = false end
			knownExists = checked and exists == true
		end
		if shouldRead then
			local read, contents = pcall(persistence.readFile, persistence.file)
			if read then restored = persistence.Decode(contents); invalid = restored == nil end
			if not read and knownExists then invalid = true end
		end
	end
	if restored then settings = restored end
	persistence.token = HttpService:GenerateGUID(false)
	localPlayer:SetAttribute(persistence.ownerAttribute, persistence.token)
	persistence.saved = table.clone(settings)
	if invalid then persistence.Status("Unreadable saved profile / defaults loaded")
	elseif restored then persistence.Status(fromSession and "Settings restored / current session" or "Settings loaded from this device")
	else persistence.Status(persistence.disk and "Auto-save ready / this device" or "Session only / device storage unavailable") end
end
-- Flush the old copy before reading its profile, including changes still awaiting auto-save.
do
	local previous = playerGui:FindFirstChild("DeveloperESPPanel")
	if previous then previous:Destroy() end
end
persistence.Load()
local palette = {
	Background = Color3.fromRGB(12, 15, 21), Sidebar = Color3.fromRGB(9, 12, 17),
	Card = Color3.fromRGB(19, 24, 33), Raised = Color3.fromRGB(26, 33, 45),
	Line = Color3.fromRGB(43, 52, 67), Text = Color3.fromRGB(231, 237, 248),
	Muted = Color3.fromRGB(157, 174, 201), Dim = Color3.fromRGB(119, 139, 171),
	Green = Color3.fromRGB(100, 228, 170),
}
local themes = {
	Glacier = Color3.fromRGB(114, 193, 255), Violet = Color3.fromRGB(177, 150, 255),
	Mint = Color3.fromRGB(103, 230, 186), Ember = Color3.fromRGB(255, 173, 117),
	Rose = Color3.fromRGB(255, 133, 189), Gold = Color3.fromRGB(255, 211, 105),
}
local skin = {
	roles = {"Background", "Sidebar", "Card", "Raised", "Line"},
	palettes = {
		Midnight = {"0B1020", "0E1628", "162137", "202E47", "344764"},
		Graphite = {"101114", "17181D", "202228", "2C2F37", "454954"},
		Dusk = {"160F23", "1B142D", "261C3B", "35284D", "513C70"},
		["Deep Sea"] = {"0A1B21", "10262D", "16343C", "20434B", "355E68"},
	} :: {[string]: {string}},
	bindings = setmetatable({} :: {[any]: {property: string, role: string}}, {__mode = "k"}),
	animationTime = 0,
}
function skin.ParseHex(text)
	local hex = string.match(text, "^%s*#?(%x%x%x%x%x%x)%s*$")
	if not hex then return nil end
	return Color3.fromRGB(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
end
function skin.FormatHex(color)
	return string.format("#%02X%02X%02X", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end
function skin.Accent(theme)
	if theme == "Custom" then return settings.CustomAccent end
	return themes[theme] or themes.Glacier
end
do
	local appliedPanelStyle: string? = nil
	function skin.ApplyPalette()
		local name = settings.PanelStyle
		if appliedPanelStyle == name then return end
		appliedPanelStyle = name
		local colors = skin.palettes[name] or skin.palettes.Midnight
		for index, role in skin.roles do palette[role] = skin.ParseHex(colors[index]) end
		for object, binding in pairs(skin.bindings) do
			if object.Parent then object[binding.property] = palette[binding.role] end
		end
	end
end
function skin.Duration(seconds)
	if settings.ReducedMotion then return 0 end
	return seconds / settings.UIMotionSpeed
end
skin.ApplyPalette()
local accent = skin.Accent(settings.Theme)
local alive = true
local connections, controls, accentBindings, columns, navigation = {}, {}, {}, {}, {}
local activeTweens = setmetatable({}, {__mode = "k"})
local layoutOrders = setmetatable({}, {__mode = "k"})
local refreshAll, updateLayout, updatePreview, selectPage, setOpen
local movement: {[string]: any} = {
	humanoid = nil, owned = {}, ui = {}, time = 0, sprintHeld = false, sprintToggled = false,
	speedDirty = true, jumpDirty = true, ramping = false,
	rewriteCounts = {}, afterPhysics = {}, history = {},
	limits = {
		MovementWalkSpeed = {0, 160, 0.5}, MovementSprintSpeed = {0, 240, 0.5},
		MovementJumpHeight = {0, 150, 0.1}, MovementSmoothTime = {0, 1, 0.01},
	},
}

local function make(className, properties, parent)
	local object = Instance.new(className)
	for property, value in properties do
		object[property] = value
		if property == "BackgroundColor3" or (className == "UIStroke" and property == "Color") then
			for _, role in skin.roles do
				if value == palette[role] then
					skin.bindings[object] = {property = property, role = role}
					break
				end
			end
		end
	end
	if parent and object:IsA("GuiObject") and properties.LayoutOrder == nil then
		layoutOrders[parent] = (layoutOrders[parent] or 0) + 1
		object.LayoutOrder = layoutOrders[parent]
	end
	object.Parent = parent
	return object
end
local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end
local function round(object, radius)
	make("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, object)
	return object
end
local function stroke(object, color, transparency, thickness)
	return make("UIStroke", {
		Color = color or palette.Line, Transparency = transparency or 0,
		Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, object)
end
local function frame(parent, name, position, size, color)
	return make("Frame", {
		Name = name, Position = position, Size = size, BackgroundColor3 = color or palette.Card,
		BackgroundTransparency = color and 0 or 1, BorderSizePixel = 0,
	}, parent)
end
local function label(parent, text, position, size, fontSize, color, font)
	return make("TextLabel", {
		Name = "Label", Text = text, Position = position, Size = size,
		BackgroundTransparency = 1, Font = font or Enum.Font.Gotham,
		TextSize = fontSize or 13, TextColor3 = color or palette.Text,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
end
local function tween(object, properties, duration, style)
	if activeTweens[object] then activeTweens[object]:Cancel() end
	local animation = TweenService:Create(object,
		TweenInfo.new(skin.Duration(duration or 0.18),
			style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out), properties)
	activeTweens[object] = animation
	animation:Play()
	return animation
end
local function bindAccent(object, property)
	table.insert(accentBindings, {object, property})
	object[property] = accent
	return object
end
local function button(parent, text, position, size)
	local object = round(make("TextButton", {
		Name = text, Text = text, Position = position, Size = size,
		BackgroundColor3 = palette.Raised, BorderSizePixel = 0, AutoButtonColor = false,
		ClipsDescendants = true,
		TextColor3 = palette.Text, TextSize = 12, Font = Enum.Font.GothamMedium,
	}, parent), 7)
	local border = stroke(object, palette.Line, 0.25)
	object.MouseEnter:Connect(function() tween(border, {Color = accent, Transparency = 0.1}) end)
	object.MouseLeave:Connect(function() tween(border, {Color = palette.Line, Transparency = 0.25}) end)
	object.Activated:Connect(function(inputObject)
		if settings.ReducedMotion then return end
		local position = UDim2.fromScale(0.5, 0.5)
		if inputObject and (inputObject.UserInputType == Enum.UserInputType.MouseButton1 or inputObject.UserInputType == Enum.UserInputType.Touch) then
			position = UDim2.fromScale(
				(inputObject.Position.X - object.AbsolutePosition.X) / math.max(1, object.AbsoluteSize.X),
				(inputObject.Position.Y - object.AbsolutePosition.Y) / math.max(1, object.AbsoluteSize.Y))
		end
		local ripple = frame(object, "ClickRipple", position, UDim2.fromScale(0, 0), accent)
		ripple.AnchorPoint = Vector2.new(0.5, 0.5)
		ripple.BackgroundTransparency = 0.85
		make("UICorner", {CornerRadius = UDim.new(1, 0)}, ripple)
		make("UIAspectRatioConstraint", {AspectRatio = 1}, ripple)
		tween(ripple, {Size = UDim2.fromScale(2.5, 2.5), BackgroundTransparency = 1}, 0.38)
		task.delay(skin.Duration(0.4), function() ripple:Destroy() end)
	end)
	return object
end

-- The previous overlay has already flushed settings and disconnected its events.
local screen = make("ScreenGui", {
	Name = "DeveloperESPPanel", ResetOnSpawn = false, IgnoreGuiInset = true,
	DisplayOrder = 50, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)
screen:SetAttribute("ESPStudioBuild", "KINETIC 3 / FPS audit")
local world = make("Folder", {Name = "DeveloperESPWorld"}, workspace)
local tracerLayer = frame(screen, "Tracers", UDim2.new(), UDim2.fromScale(1, 1))
local markerLayer = frame(screen, "Markers", UDim2.new(), UDim2.fromScale(1, 1))
tracerLayer.ZIndex = 1
markerLayer.ZIndex = 2

local aimCircle = frame(screen, "AimRadius", UDim2.new(), UDim2.fromOffset(280, 280))
aimCircle.AnchorPoint = Vector2.new(0.5, 0.5)
aimCircle.ZIndex = 2
aimCircle.Visible = false
make("UICorner", {CornerRadius = UDim.new(1, 0)}, aimCircle)
local aimCircleStroke = bindAccent(stroke(aimCircle, accent, 0.4), "Color")
local aimDot = round(frame(screen, "AimTarget", UDim2.new(), UDim2.fromOffset(6, 6), palette.Green), 3)
aimDot.AnchorPoint = Vector2.new(0.5, 0.5)
aimDot.ZIndex = 3
aimDot.Visible = false
local aimButton = button(screen, "HOLD AIM", UDim2.new(1, -112, 1, -106), UDim2.fromOffset(92, 48))
aimButton.ZIndex = 20
aimButton.Visible = false
local aimStatusPanel = round(frame(screen, "AimStatus", UDim2.new(0.5, 0, 0, 60), UDim2.fromOffset(360, 32), palette.Background), 7)
aimStatusPanel.AnchorPoint = Vector2.new(0.5, 0)
aimStatusPanel.ZIndex = 20
aimStatusPanel.Visible = false
stroke(aimStatusPanel, palette.Line, 0.15)
local aimStatusText = label(aimStatusPanel, "", UDim2.fromOffset(10, 0), UDim2.new(1, -20, 1, 0), 11, palette.Muted, Enum.Font.Code)
aimStatusText.TextXAlignment = Enum.TextXAlignment.Center
local aimStateLabel
local lastAimStatus = "Enable Aim, minimize the console, then hold RMB."
local aimHeld, aimHeldInput, aimMousePolled = false, nil, false
local aimWindowFocused, aimNeedsFreshMouse = true, false
local function showAimStatus(text, tracking)
	aimStatusText.Text = text
	aimStatusText.TextColor3 = tracking and palette.Green or palette.Muted
	lastAimStatus = text
	if aimStateLabel then aimStateLabel.Text = text end
end
local function releaseAim(requireFreshMouse)
	aimHeld, aimHeldInput = false, nil
	aimMousePolled = false
	if requireFreshMouse then aimNeedsFreshMouse = true end
	aimDot.Visible = false
	aimButton.Text = "HOLD AIM"
end
local function isAimInput(input)
	return (settings.AimKey == "RMB" and input.UserInputType == Enum.UserInputType.MouseButton2)
		or (settings.AimKey == "Q" and input.KeyCode == Enum.KeyCode.Q)
		or input.KeyCode == Enum.KeyCode.ButtonL2
end

-- Fixed-size canvas: opening fades/slides it, instead of collapsing its children.
local host = frame(screen, "ConsoleHost", UDim2.fromOffset(70, 70), UDim2.fromOffset(960, 650))
host.ZIndex = 10
host.Visible = false
local hostScale = make("UIScale", {Scale = 1}, host)
local shadow = round(frame(host, "Shadow", UDim2.fromOffset(0, 10), UDim2.fromScale(1, 1), Color3.new()), 14)
shadow.BackgroundTransparency = 0.68
local window = round(make("CanvasGroup", {
	Name = "Console", Size = UDim2.fromScale(1, 1), BackgroundColor3 = palette.Background,
	BorderSizePixel = 0, GroupTransparency = 1,
}, host), 14)
skin.windowBorder = stroke(window, palette.Line, 0.05)
local accentBar = bindAccent(frame(window, "Accent", UDim2.new(), UDim2.new(1, 0, 0, 2), accent), "BackgroundColor3")
local accentGradient = make("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(115, 115, 115)),
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(115, 115, 115)),
	}),
}, accentBar)

local titlebar = frame(window, "Titlebar", UDim2.fromOffset(0, 2), UDim2.new(1, 0, 0, 48), palette.Sidebar)
local dragHandle = make("TextButton", {
	Name = "DragHandle", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
	Size = UDim2.new(1, -132, 1, 0),
}, titlebar)
do
	local tile = bindAccent(round(frame(dragHandle, "BrandTile", UDim2.fromOffset(14, 8), UDim2.fromOffset(36, 32), accent), 9), "BackgroundColor3")
	tile.BackgroundTransparency = 0.86
	bindAccent(stroke(tile, accent, 0.53), "Color")
	local mark = bindAccent(label(tile, "[ / ]", UDim2.new(), UDim2.fromScale(1, 1), 11, accent, Enum.Font.Code), "TextColor3")
	mark.TextXAlignment = Enum.TextXAlignment.Center
end
label(dragHandle, "ESP STUDIO", UDim2.fromOffset(62, 6), UDim2.fromOffset(125, 21), 15, nil, Enum.Font.GothamBold)
label(dragHandle, "CONTROL DECK", UDim2.fromOffset(63, 25), UDim2.fromOffset(125, 15), 9, palette.Dim, Enum.Font.Code)
local edition = bindAccent(round(frame(dragHandle, "EditionBadge", UDim2.fromOffset(191, 13), UDim2.fromOffset(76, 22), accent), 6), "BackgroundColor3")
edition.BackgroundTransparency = 0.89
do
	local name = bindAccent(label(edition, "AURORA", UDim2.new(), UDim2.fromScale(1, 1), 10, accent, Enum.Font.Code), "TextColor3")
	name.TextXAlignment = Enum.TextXAlignment.Center
end
local centerButton = button(titlebar, "+", UDim2.new(1, -88, 0, 10), UDim2.fromOffset(30, 28))
local minimizeButton = button(titlebar, "-", UDim2.new(1, -48, 0, 10), UDim2.fromOffset(30, 28))

local sidebar = frame(window, "Explorer", UDim2.fromOffset(0, 50), UDim2.new(0, 196, 1, -78), palette.Sidebar)
frame(sidebar, "Divider", UDim2.new(1, -1, 0, 0), UDim2.new(0, 1, 1, 0), palette.Line)
label(sidebar, "EXPLORER", UDim2.fromOffset(18, 12), UDim2.fromOffset(155, 28), 10, palette.Muted, Enum.Font.Code)
local search = round(make("TextBox", {
	Name = "Search", Text = "", PlaceholderText = "Find a section...", ClearTextOnFocus = false,
	Position = UDim2.fromOffset(14, 48), Size = UDim2.fromOffset(166, 34),
	BackgroundColor3 = palette.Background, BorderSizePixel = 0, Font = Enum.Font.Gotham,
	TextSize = 11, TextColor3 = palette.Text, PlaceholderColor3 = palette.Dim,
	TextXAlignment = Enum.TextXAlignment.Left,
}, sidebar), 6)
stroke(search)
make("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 8)}, search)
label(sidebar, "SESSION TOOLS", UDim2.fromOffset(18, 99), UDim2.fromOffset(155, 24), 10, palette.Dim, Enum.Font.Code)
local navContainer = frame(sidebar, "Sections", UDim2.fromOffset(10, 133), UDim2.new(1, -20, 0, 310))
make("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, navContainer)
local noResults = label(sidebar, "No sections found", UDim2.fromOffset(18, 141), UDim2.fromOffset(160, 40), 11, palette.Muted)
noResults.Visible = false
local sessionCard = round(frame(sidebar, "Session", UDim2.new(0, 14, 1, -124), UDim2.fromOffset(166, 105), palette.Card), 8)
stroke(sessionCard, palette.Line, 0.4)
local sessionDot = round(frame(sessionCard, "Status", UDim2.fromOffset(12, 15), UDim2.fromOffset(6, 6), palette.Green), 3)
label(sessionCard, "LOCAL SESSION", UDim2.fromOffset(26, 6), UDim2.fromOffset(130, 24), 10, palette.Muted, Enum.Font.Code)
label(sessionCard, localPlayer.DisplayName, UDim2.fromOffset(12, 33), UDim2.fromOffset(142, 22), 12, nil, Enum.Font.GothamMedium)
label(sessionCard, "RightShift to minimize\nDrag the title bar to move", UDim2.fromOffset(12, 61), UDim2.fromOffset(145, 32), 10, palette.Dim)

local tabbar = frame(window, "Tabs", UDim2.fromOffset(196, 50), UDim2.new(1, -196, 0, 43), palette.Sidebar)
frame(tabbar, "Divider", UDim2.new(0, 0, 1, -1), UDim2.new(1, 0, 0, 1), palette.Line)
local body = frame(window, "Workspace", UDim2.fromOffset(196, 93), UDim2.new(1, -196, 1, -121))
local statusbar = frame(window, "Statusbar", UDim2.new(0, 0, 1, -28), UDim2.new(1, 0, 0, 28), palette.Sidebar)
skin.chrome = {window, titlebar, sidebar, tabbar, statusbar}
frame(statusbar, "Divider", UDim2.new(), UDim2.new(1, 0, 0, 1), palette.Line)
local statusText = label(statusbar, "READY", UDim2.fromOffset(14, 0), UDim2.new(0.65, 0, 1, 0), 10, palette.Muted, Enum.Font.Code)
local fpsText = label(statusbar, "-- FPS", UDim2.new(1, -140, 0, 0), UDim2.fromOffset(124, 28), 10, palette.Dim, Enum.Font.Code)
fpsText.TextXAlignment = Enum.TextXAlignment.Right

local launcher = button(screen, "[ / ]   ESP STUDIO", UDim2.new(0, 18, 1, -54), UDim2.fromOffset(172, 36))
launcher.ZIndex = 20
bindAccent(launcher:FindFirstChildOfClass("UIStroke"), "Color")
local toast = round(make("CanvasGroup", {
	Name = "Notification", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -22),
	Size = UDim2.fromOffset(310, 42), BackgroundColor3 = palette.Raised,
	BorderSizePixel = 0, GroupTransparency = 1, Visible = false, ZIndex = 30,
}, screen), 9)
bindAccent(stroke(toast, accent, 0.45), "Color")
local toastText = label(toast, "", UDim2.fromOffset(14, 0), UDim2.new(1, -28, 1, 0), 12)
toastText.TextXAlignment = Enum.TextXAlignment.Center
local toastRevision = 0
local function notify(message)
	toastRevision += 1
	local revision = toastRevision
	local _, bottomInset = GuiService:GetGuiInset()
	local bottom = bottomInset.Y + 28
	toastText.Text = message
	toast.Visible = true
	tween(toast, {GroupTransparency = 0, Position = UDim2.new(0.5, 0, 1, -bottom)}, 0.22)
	task.delay(2.2, function()
		if not alive or revision ~= toastRevision then return end
		tween(toast, {GroupTransparency = 1, Position = UDim2.new(0.5, 0, 1, -bottom + 10)}, 0.2)
		task.delay(skin.Duration(0.22), function()
			if alive and revision == toastRevision then toast.Visible = false end
		end)
	end)
end

local pageDefinitions = {
	{"Overview", "01", "Session overview", "Your session, at a glance.", "home dashboard presets preview"},
	{"Visuals", "02", "Player visuals", "Readable markers. Precise control.", "names health distance boxes highlights overlay"},
	{"Tracers", "03", "Tracer renderer", "A clean line to every visible target.", "lines origin opacity width pulse"},
	{"Aim", "04", "Camera aim assist", "Hold to follow a target near your crosshair.", "aimbot aiming aim assist target camera smoothing fov"},
	{"Movement", "05", "Kinetic movement lab", "Dial in your pace. Shape your next jump.", "movement walk speed sprint jump height power acceleration mobility"},
	{"Filters", "06", "Display filters", "Choose who appears in the overlay.", "range team dead color walls"},
	{"Appearance", "07", "Appearance studio", "Mix your own accent and tune how the deck feels.", "theme colors custom hex opacity layout motion animations reset settings"},
}
local pages, currentPage = {}, "Overview"
for index, definition in pageDefinitions do
	local name = definition[1]
	local nav = button(navContainer, "", UDim2.new(), UDim2.new(1, 0, 0, 38))
	nav.Name = name
	nav.LayoutOrder = index
	nav.BackgroundTransparency = 1
	local navLine = round(frame(nav, "Active", UDim2.fromOffset(0, 8), UDim2.fromOffset(3, 22), accent), 2)
	local number = label(nav, definition[2], UDim2.fromOffset(12, 0), UDim2.fromOffset(27, 38), 10, palette.Dim, Enum.Font.Code)
	local caption = label(nav, name, UDim2.fromOffset(44, 0), UDim2.new(1, -54, 1, 0), 12, palette.Muted)
	local tab = make("TextButton", {
		Name = name, Text = name, Position = UDim2.new((index - 1) / #pageDefinitions, 0, 0, 0),
		Size = UDim2.new(1 / #pageDefinitions, 0, 1, -1), BackgroundColor3 = palette.Background,
		BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false,
		Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = palette.Muted,
	}, tabbar)
	local underline = frame(tab, "Active", UDim2.new(0, 12, 1, -2), UDim2.new(1, -24, 0, 2), accent)
	navigation[name] = {button = nav, line = navLine, number = number, caption = caption, tab = tab, underline = underline, keywords = definition[5]}
	nav.Activated:Connect(function() selectPage(name) end)
	tab.Activated:Connect(function() selectPage(name) end)
	local page = make("ScrollingFrame", {
		Name = name, Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -40, 1, 0),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
		ScrollBarImageColor3 = palette.Dim, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, Visible = false,
	}, body)
	make("UIPadding", {PaddingTop = UDim.new(0, 24), PaddingBottom = UDim.new(0, 22), PaddingRight = UDim.new(0, 4)}, page)
	make("UIListLayout", {Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder}, page)
	local heading = frame(page, "Heading", UDim2.new(), UDim2.new(1, 0, 0, 72))
	heading.LayoutOrder = -10
	bindAccent(label(heading, "WORKSPACE / " .. string.upper(name), UDim2.new(), UDim2.new(1, 0, 0, 17), 10, accent, Enum.Font.Code), "TextColor3")
	label(heading, definition[3], UDim2.fromOffset(0, 22), UDim2.new(1, 0, 0, 27), 23, nil, Enum.Font.GothamBold)
	label(heading, definition[4], UDim2.fromOffset(0, 52), UDim2.new(1, 0, 0, 19), 12, palette.Muted)
	pages[name] = page
end

local function section(parent, title, subtitle, height)
	local object = round(frame(parent, title, UDim2.new(), UDim2.new(1, 0, 0, height), palette.Card), 10)
	stroke(object, palette.Line, 0.3)
	local mark = bindAccent(round(frame(object, "CardMark", UDim2.fromOffset(7, 16), UDim2.fromOffset(2, 12), accent), 1), "BackgroundColor3")
	mark.BackgroundTransparency = 0.35
	label(object, title, UDim2.fromOffset(16, 12), UDim2.new(1, -32, 0, 22), 13, nil, Enum.Font.GothamBold)
	label(object, subtitle, UDim2.fromOffset(16, 36), UDim2.new(1, -32, 0, 20), 10, palette.Muted)
	return object
end
local function twoColumns(parent, leftHeight, rightHeight)
	local container = frame(parent, "Columns", UDim2.new(), UDim2.new(1, 0, 0, math.max(leftHeight, rightHeight)))
	local left = frame(container, "Left", UDim2.new(), UDim2.new(0.5, -7, 0, leftHeight))
	local right = frame(container, "Right", UDim2.new(0.5, 7, 0, 0), UDim2.new(0.5, -7, 0, rightHeight))
	table.insert(columns, {container = container, left = left, right = right, leftHeight = leftHeight, rightHeight = rightHeight})
	return left, right
end
local function aimRadiusCap()
	local camera = workspace.CurrentCamera
	if not camera then return 300 end
	-- Round the center-to-corner distance up to a slider step.
	return math.max(45, math.ceil(camera.ViewportSize.Magnitude / 10) * 5)
end
local function setSetting(key, value)
	local limit = movement.limits[key]
	if limit then
		if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return end
		value = math.clamp(limit[1] + math.floor((value - limit[1]) / limit[3] + 0.5) * limit[3], limit[1], limit[2])
	end
	if key == "AimRadius" then settings.AimRadiusFullScreen = value >= aimRadiusCap() end
	settings[key] = value
	if key == "AimEnabled" or key == "AimKey" then releaseAim(true) end
	if string.sub(key, 1, 8) == "Movement" and movement.MarkDirty then
		movement.MarkDirty(key)
		movement.Update(0)
	end
	refreshAll()
	if key == "UIScale" or key == "NavigationStyle" then updateLayout() end
end
local function addToggle(parent, title, description, key, y)
	local row = make("TextButton", {
		Name = key, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(10, y),
		Size = UDim2.new(1, -20, 0, 55), BackgroundColor3 = palette.Raised,
		BackgroundTransparency = 1, BorderSizePixel = 0,
	}, parent)
	round(row, 6)
	label(row, title, UDim2.fromOffset(6, 5), UDim2.new(1, -70, 0, 20), 12)
	label(row, description, UDim2.fromOffset(6, 28), UDim2.new(1, -70, 0, 17), 10, palette.Muted)
	local track = round(frame(row, "Switch", UDim2.new(1, -48, 0, 15), UDim2.fromOffset(40, 22), palette.Raised), 11)
	local knob = round(frame(track, "Knob", UDim2.fromOffset(3, 3), UDim2.fromOffset(16, 16), palette.Muted), 8)
	row.MouseEnter:Connect(function() tween(row, {BackgroundTransparency = 0.25}, 0.15) end)
	row.MouseLeave:Connect(function() tween(row, {BackgroundTransparency = 1}, 0.2) end)
	row.Activated:Connect(function() setSetting(key, not settings[key]) end)
	table.insert(controls, function()
		local enabled = settings[key]
		tween(track, {BackgroundColor3 = enabled and accent:Lerp(palette.Card, 0.55) or palette.Raised})
		tween(knob, {Position = UDim2.fromOffset(enabled and 21 or 3, 3), BackgroundColor3 = enabled and accent or palette.Muted}, 0.22)
	end)
end

local activePointer
local function addSlider(parent, title, key, minimum, maximum, step, formatter, y, editable)
	local function maximumValue()
		if type(maximum) == "function" then return maximum() end
		return maximum
	end
	label(parent, title, UDim2.fromOffset(16, y), UDim2.new(1, -120, 0, 24), 12)
	local valueLabel = make(editable and "TextBox" or "TextLabel", {
		Name = key .. "Value", Text = "", Position = UDim2.new(1, -112, 0, y), Size = UDim2.fromOffset(96, 24),
		Font = Enum.Font.Code, TextSize = 11, TextColor3 = accent, TextXAlignment = Enum.TextXAlignment.Right,
		BackgroundColor3 = palette.Raised, BackgroundTransparency = editable and 0 or 1, BorderSizePixel = 0,
	}, parent)
	if editable then
		round(valueLabel, 5)
		valueLabel.ClearTextOnFocus = false
		make("UIPadding", {PaddingRight = UDim.new(0, 6), PaddingLeft = UDim.new(0, 4)}, valueLabel)
		valueLabel.Focused:Connect(function()
			valueLabel.Text = tostring(settings[key])
			tween(valueLabel, {BackgroundColor3 = accent:Lerp(palette.Card, 0.8)}, 0.15)
		end)
		valueLabel.FocusLost:Connect(function()
			local value = tonumber(valueLabel.Text)
			local limit = maximumValue()
			if value and value == value and math.abs(value) < math.huge then
				setSetting(key, math.clamp(minimum + math.floor((value - minimum) / step + 0.5) * step, minimum, limit))
			else notify("Enter a finite number, without units.") end
			valueLabel.Text = formatter(settings[key], limit)
			tween(valueLabel, {BackgroundColor3 = palette.Raised}, 0.18)
		end)
	end
	bindAccent(valueLabel, "TextColor3")
	local hitbox = make("TextButton", {
		Name = key, Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
		Position = UDim2.fromOffset(19, y + 26), Size = UDim2.new(1, -38, 0, 26),
	}, parent)
	local rail = round(frame(hitbox, "Rail", UDim2.fromOffset(0, 10), UDim2.new(1, 0, 0, 5), palette.Raised), 3)
	local fill = bindAccent(round(frame(rail, "Fill", UDim2.new(), UDim2.fromScale(0.5, 1), accent), 3), "BackgroundColor3")
	local knob = bindAccent(round(frame(rail, "Knob", UDim2.new(0.5, 0, 0.5, 0), UDim2.fromOffset(13, 13), accent), 7), "BackgroundColor3")
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	stroke(knob, palette.Background, 0, 2)
	hitbox.MouseEnter:Connect(function() tween(knob, {Size = UDim2.fromOffset(16, 16)}, 0.15) end)
	hitbox.MouseLeave:Connect(function() tween(knob, {Size = UDim2.fromOffset(13, 13)}, 0.18) end)
	local function move(x, left, width)
		local ratio = math.clamp((x - left) / math.max(1, width), 0, 1)
		local limit = maximumValue()
		local value = minimum + math.floor((ratio * (limit - minimum)) / step + 0.5) * step
		setSetting(key, math.clamp(value, minimum, limit))
	end
	hitbox.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			-- Freeze the rail while dragging the UI-scale slider so resizing cannot move its range.
			local left, width = rail.AbsolutePosition.X, rail.AbsoluteSize.X
			local function drag(x) move(x, left, width) end
			activePointer = {kind = "slider", input = input, move = drag}
			drag(input.Position.X)
		end
	end)
	local function refresh()
		local limit = maximumValue()
		local value = math.clamp(settings[key], minimum, limit)
		if key == "AimRadius" and settings.AimRadiusFullScreen then value = limit end
		local ratio = (value - minimum) / (limit - minimum)
		fill.Size = UDim2.fromScale(ratio, 1)
		knob.Position = UDim2.new(ratio, 0, 0.5, 0)
		if not editable or not valueLabel:IsFocused() then valueLabel.Text = formatter(value, limit) end
	end
	table.insert(controls, refresh)
	return refresh
end
local function addChoices(parent, title, key, options, y, perRow)
	label(parent, title, UDim2.fromOffset(16, y), UDim2.new(1, -32, 0, 22), 12)
	local count = perRow or #options
	for index, option in options do
		local column = (index - 1) % count
		local row = math.floor((index - 1) / count)
		local choice = button(parent, option, UDim2.new(column / count, 16, 0, y + 30 + row * 39), UDim2.new(1 / count, -22, 0, 33))
		local swatch
		if key == "Theme" then
			swatch = round(frame(choice, "AccentSwatch", UDim2.new(0, 8, 1, -3), UDim2.new(1, -16, 0, 2), skin.Accent(option)), 1)
		end
		choice.Activated:Connect(function() setSetting(key, option) end)
		table.insert(controls, function()
			choice.BackgroundColor3 = settings[key] == option and accent:Lerp(palette.Card, 0.8) or palette.Raised
			choice.TextColor3 = settings[key] == option and accent or palette.Muted
			if swatch then swatch.BackgroundColor3 = skin.Accent(option) end
		end)
	end
end
local function percent(value) return string.format("%d%%", math.floor(value * 100 + 0.5)) end

-- Overview: real counters, a clearly labeled preview, and useful presets.
local hero = round(frame(pages.Overview, "AuroraOverview", UDim2.new(), UDim2.new(1, 0, 0, 145), palette.Card), 13)
hero.ClipsDescendants = true
stroke(hero, palette.Line, 0.14)
do
	skin.wash = bindAccent(frame(hero, "AuroraWash", UDim2.new(), UDim2.fromScale(1, 1), accent), "BackgroundColor3")
	make("UIGradient", {
		Rotation = 12,
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.52, 0.97), NumberSequenceKeypoint.new(1, 0.76)}),
	}, skin.wash)
	skin.radar = frame(hero, "Radar", UDim2.new(1, -104, 0.5, 0), UDim2.fromOffset(160, 160))
	skin.radar.AnchorPoint = Vector2.new(0.5, 0.5)
	for _, diameter in {56, 104, 154} do
		local ring = round(frame(skin.radar, "Ring", UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(diameter, diameter)), diameter / 2)
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		bindAccent(stroke(ring, accent, 0.75), "Color")
	end
	local horizontal = bindAccent(frame(skin.radar, "Horizontal", UDim2.new(0, 4, 0.5, 0), UDim2.new(1, -8, 0, 1), accent), "BackgroundColor3")
	local vertical = bindAccent(frame(skin.radar, "Vertical", UDim2.new(0.5, 0, 0, 4), UDim2.new(0, 1, 1, -8), accent), "BackgroundColor3")
	horizontal.BackgroundTransparency, vertical.BackgroundTransparency = 0.83, 0.83
	local center = bindAccent(round(frame(skin.radar, "Center", UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(5, 5), accent), 3), "BackgroundColor3")
	center.AnchorPoint = Vector2.new(0.5, 0.5)
	skin.radarDot = bindAccent(round(frame(skin.radar, "Signal", UDim2.new(0.5, 52, 0.5, 0), UDim2.fromOffset(8, 8), accent), 4), "BackgroundColor3")
	skin.radarDot.AnchorPoint = Vector2.new(0.5, 0.5)
	bindAccent(stroke(skin.radarDot, accent, 0.64, 3), "Color")
	bindAccent(label(hero, "AURORA / SESSION", UDim2.fromOffset(19, 13), UDim2.new(1, -190, 0, 18), 10, accent, Enum.Font.Code), "TextColor3")
	label(hero, "Control deck", UDim2.fromOffset(18, 34), UDim2.new(1, -165, 0, 37), 28, nil, Enum.Font.GothamBold)
	label(hero, "Visuals, aim, and movement in one workspace.", UDim2.fromOffset(19, 73), UDim2.new(1, -172, 0, 20), 11, palette.Muted)
end
skin.heroBadge = round(frame(hero, "OverlayStatus", UDim2.fromOffset(18, 107), UDim2.fromOffset(145, 23), palette.Raised), 6)
skin.heroDot = round(frame(skin.heroBadge, "Signal", UDim2.fromOffset(9, 9), UDim2.fromOffset(5, 5), palette.Green), 3)
local heroStatus = label(skin.heroBadge, "OVERLAY ONLINE", UDim2.fromOffset(20, 0), UDim2.new(1, -25, 1, 0), 10, palette.Green, Enum.Font.Code)
local metrics = frame(pages.Overview, "Metrics", UDim2.new(), UDim2.new(1, 0, 0, 82))
local metricLabels = {}
for index, text in {"ON SCREEN", "OTHER PLAYERS", "MAX RANGE"} do
	local card = round(frame(metrics, text, UDim2.new((index - 1) / 3, 0, 0, 0), UDim2.new(1 / 3, -10, 1, 0), palette.Card), 8)
	stroke(card, palette.Line, 0.4)
	local line = bindAccent(round(frame(card, "MetricLine", UDim2.new(0, 12, 1, -10), UDim2.fromOffset(22, 2), accent), 1), "BackgroundColor3")
	line.BackgroundTransparency = 0.38
	label(card, text, UDim2.fromOffset(12, 10), UDim2.new(1, -24, 0, 17), 9, palette.Dim, Enum.Font.Code)
	metricLabels[index] = label(card, "00", UDim2.fromOffset(12, 30), UDim2.new(1, -24, 0, 32), 24, nil, Enum.Font.GothamBold)
end
local overviewLeft, overviewRight = twoColumns(pages.Overview, 292, 292)
local preview = section(overviewLeft, "Live style preview", "Sample player / follows your settings", 292)
local previewStage = round(frame(preview, "PreviewStage", UDim2.fromOffset(12, 66), UDim2.new(1, -24, 1, -78), palette.Background), 7)
previewStage.ClipsDescendants = true
for index = 1, 8 do
	local line = frame(previewStage, "Grid", UDim2.fromScale(index / 9, 0), UDim2.new(0, 1, 1, 0), palette.Line)
	line.BackgroundTransparency = 0.7
end
for index = 1, 5 do
	local line = frame(previewStage, "Grid", UDim2.fromScale(0, index / 6), UDim2.new(1, 0, 0, 1), palette.Line)
	line.BackgroundTransparency = 0.7
end
local previewRig = frame(previewStage, "SampleRig", UDim2.new(0.5, -28, 0.5, -36), UDim2.fromOffset(56, 100))
local previewParts = {}
for _, geometry in {
	{19, 0, 18, 18}, {12, 22, 32, 38}, {0, 22, 9, 40},
	{47, 22, 9, 40}, {12, 64, 14, 36}, {30, 64, 14, 36},
} do
	local part = round(frame(previewRig, "Body", UDim2.fromOffset(geometry[1], geometry[2]), UDim2.fromOffset(geometry[3], geometry[4]), accent), 3)
	part.BackgroundTransparency = 0.65
	table.insert(previewParts, part)
end
local previewBox = frame(previewStage, "SampleBox", UDim2.new(0.5, -44, 0.5, -44), UDim2.fromOffset(88, 118))
local previewBoxStroke = stroke(previewBox, settings.EnemyColor, 0.12)
local previewName = label(previewStage, "Preview player", UDim2.new(0, 0, 0.5, -92), UDim2.new(1, 0, 0, 20), 12, palette.Text, Enum.Font.GothamBold)
previewName.TextXAlignment = Enum.TextXAlignment.Center
local previewMeta = label(previewStage, "86 HP  /  24 studs", UDim2.new(0, 0, 0.5, -72), UDim2.new(1, 0, 0, 17), 10, palette.Muted, Enum.Font.Code)
previewMeta.TextXAlignment = Enum.TextXAlignment.Center
local previewHealth = round(frame(previewStage, "SampleHealth", UDim2.new(0.5, -40, 0.5, 80), UDim2.fromOffset(80, 3), palette.Raised), 2)
round(frame(previewHealth, "Fill", UDim2.new(), UDim2.fromScale(0.86, 1), palette.Green), 2)
local previewTracer = frame(previewStage, "SampleTracer", UDim2.new(0.5, 0, 0.5, 85), UDim2.new(0, 1, 0.5, -85), settings.EnemyColor)
label(previewStage, "PREVIEW", UDim2.fromOffset(8, 5), UDim2.fromOffset(80, 17), 8, palette.Dim, Enum.Font.Code)
local quick = section(overviewRight, "Quick controls", "The essentials, one click away.", 292)
addToggle(quick, "Overlay enabled", "Master switch for all markers", "Enabled", 65)
addToggle(quick, "Tracers", "Connect targets to your screen", "ShowTracers", 121)
addToggle(quick, "Team filter", "Exclude players on your team", "TeamCheck", 177)
local openVisuals = button(quick, "Customize visuals  >", UDim2.fromOffset(16, 244), UDim2.new(1, -32, 0, 31))
openVisuals.Activated:Connect(function() selectPage("Visuals") end)
local presets = section(pages.Overview, "Instant setup", "Switch the entire visual style in one click.", 122)
for index, name in {"Minimal", "Tactical", "Spotlight"} do
	local preset = button(presets, name, UDim2.new((index - 1) / 3, 16, 0, 72), UDim2.new(1 / 3, -22, 0, 33))
	preset.Activated:Connect(function()
		settings.Enabled = true
		settings.ShowNames = true
		settings.ShowDistance = name ~= "Spotlight"
		settings.ShowHealth = name ~= "Minimal"
		settings.ShowBoxes = name == "Tactical"
		settings.ShowTracers = name == "Tactical"
		settings.ShowHighlights = name ~= "Minimal"
		settings.HighlightFillTransparency = name == "Spotlight" and 0.55 or 0.8
		refreshAll()
		notify(name .. " preset applied")
	end)
end

local visualsLeft, visualsRight = twoColumns(pages.Visuals, 411, 411)
local markers = section(visualsLeft, "Player markers", "Build your ideal information plate.", 411)
addToggle(markers, "Overlay enabled", "Show or hide every ESP element", "Enabled", 65)
addToggle(markers, "Player names", "Display names above each player", "ShowNames", 121)
addToggle(markers, "Health bars", "Smooth bars with health colors", "ShowHealth", 177)
addToggle(markers, "Distance labels", "Distance from your character", "ShowDistance", 233)
addToggle(markers, "Corner boxes", "Minimal brackets around the rig", "ShowBoxes", 289)
addSlider(markers, "Marker scale", "MarkerScale", 0.75, 1.4, 0.05, percent, 347)
local outlines = section(visualsRight, "Character highlights", "Silhouettes with adjustable intensity.", 411)
addToggle(outlines, "Highlights", "Tint and outline character models", "ShowHighlights", 65)
addToggle(outlines, "Through walls", "Allow highlights behind geometry", "ThroughWalls", 121)
addSlider(outlines, "Fill transparency", "HighlightFillTransparency", 0, 1, 0.05, percent, 192)
addSlider(outlines, "Outline transparency", "HighlightOutlineTransparency", 0, 1, 0.05, percent, 270)
label(outlines, "Screen markers and tracers are\ndrawn above the world.", UDim2.fromOffset(16, 350), UDim2.new(1, -32, 0, 38), 10, palette.Dim)

local tracerLeft, tracerRight = twoColumns(pages.Tracers, 361, 361)
local tracerSettings = section(tracerLeft, "Screen tracers", "Crisp lines that follow the camera.", 361)
addToggle(tracerSettings, "Enable tracers", "Respect master, team, and range filters", "ShowTracers", 65)
addToggle(tracerSettings, "Animated endpoints", "A subtle pulse on each target", "PulseTracers", 121)
addChoices(tracerSettings, "Start position", "TracerOrigin", {"Bottom", "Center", "Cursor"}, 194)
label(tracerSettings, "Tracers appear when a target's\nroot is inside the camera view.", UDim2.fromOffset(16, 292), UDim2.new(1, -32, 0, 38), 10, palette.Dim)
local tracerStyle = section(tracerRight, "Line style", "Low noise. High readability.", 361)
addSlider(tracerStyle, "Line width", "TracerWidth", 1, 4, 0.25, function(value) return string.format("%.2f px", value) end, 75)
addSlider(tracerStyle, "Opacity", "TracerOpacity", 0.1, 1, 0.05, percent, 163)
label(tracerStyle, "Target colors are shared with the\noverlay. Adjust them in Appearance.", UDim2.fromOffset(16, 267), UDim2.new(1, -32, 0, 40), 10, palette.Muted)

local aimLeft, aimRight = twoColumns(pages.Aim, 411, 411)
local aimControls = section(aimLeft, "Hold to aim", "Enable, minimize the console, then hold.", 411)
addToggle(aimControls, "Enable aim assist", "Gently turn the camera toward a player", "AimEnabled", 65)
addToggle(aimControls, "Team check", "Ignore players on your team", "AimTeamCheck", 121)
addToggle(aimControls, "Visibility check", "Require a clear camera-to-target ray", "AimVisibilityCheck", 177)
addToggle(aimControls, "Show aim radius", "Show the acquisition circle", "AimShowRadius", 233)
addChoices(aimControls, "Hold control", "AimKey", {"RMB", "Q"}, 300)
label(aimControls, "Gamepad: hold L2. Touch: hold AIM.", UDim2.fromOffset(16, 378), UDim2.new(1, -32, 0, 18), 10, palette.Dim)
local aimTuning = section(aimRight, "Targeting", "Choose the closest player to screen center.", 411)
addChoices(aimTuning, "Aim point", "AimPart", {"Head", "Body"}, 65)
addSlider(aimTuning, "Smoothing time", "AimSmoothTime", 0, 0.5, 0.01,
	function(value)
		if value == 0 then return "Instant" end
		return string.format("%d ms", math.floor(value * 1000 + 0.5))
	end, 149)
local refreshAimRadius = addSlider(aimTuning, "Aim radius", "AimRadius", 40, aimRadiusCap, 5,
	function(value, limit)
		if value >= limit then return "Full screen" end
		return string.format("%d px", value)
	end, 226)
addSlider(aimTuning, "Maximum range", "AimRange", 100, 2000, 50,
	function(value) return string.format("%d studs", value) end, 303)
label(aimTuning, "Slide all the way left for Instant.", UDim2.fromOffset(16, 378), UDim2.new(1, -32, 0, 18), 10, palette.Dim)
local aimDiagnostics = section(pages.Aim, "Last aim status", "The live readout explains why a target is not acquired.", 110)
aimStateLabel = label(aimDiagnostics, lastAimStatus, UDim2.fromOffset(16, 69), UDim2.new(1, -32, 0, 24), 11, palette.Muted, Enum.Font.Code)

-- Kinetic workspace: animated, explicitly simulated trajectory + real character telemetry.
do
	local ui = movement.ui
	local left, right = twoColumns(pages.Movement, 320, 320)
	local trajectoryCard = section(left, "KINETIC / TRAJECTORY", "Simulated arc for the selected jump profile.", 320)
	local edge = bindAccent(frame(trajectoryCard, "Accent", UDim2.fromOffset(16, 0), UDim2.new(1, -32, 0, 2), accent), "BackgroundColor3")
	make("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1)})}, edge)
	ui.graph = round(frame(trajectoryCard, "Trajectory", UDim2.fromOffset(12, 66), UDim2.new(1, -24, 1, -78), palette.Background), 8)
	ui.graph.ClipsDescendants = true
	for index = 1, 7 do
		local line = frame(ui.graph, "Grid", UDim2.fromScale(index / 8, 0), UDim2.new(0, 1, 1, 0), palette.Line)
		line.BackgroundTransparency = 0.65
	end
	for index = 1, 4 do
		local line = frame(ui.graph, "Grid", UDim2.fromScale(0, index / 5), UDim2.new(1, 0, 0, 1), palette.Line)
		line.BackgroundTransparency = 0.65
	end
	ui.arcLines = {}
	for index = 1, 24 do
		local line = bindAccent(round(frame(ui.graph, "Arc" .. index, UDim2.new(), UDim2.fromOffset(12, 2), accent), 1), "BackgroundColor3")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		table.insert(ui.arcLines, line)
	end
	ui.arcBall = bindAccent(round(frame(ui.graph, "Probe", UDim2.new(), UDim2.fromOffset(9, 9), accent), 5), "BackgroundColor3")
	ui.arcBall.AnchorPoint = Vector2.new(0.5, 0.5)
	stroke(ui.arcBall, palette.Text, 0.2)
	ui.apex = bindAccent(label(ui.graph, "APEX / 7.2 u", UDim2.fromOffset(10, 7), UDim2.new(1, -20, 0, 20), 11, accent, Enum.Font.Code), "TextColor3")
	ui.flight = label(ui.graph, "", UDim2.new(0, 10, 1, -25), UDim2.new(1, -20, 0, 18), 9, palette.Muted, Enum.Font.Code)
	local movementQuick = section(right, "Movement control", "An independent, reversible character profile.", 320)
	addToggle(movementQuick, "Enable movement profile", "Apply speed and jump overrides", "MovementEnabled", 65)
	addToggle(movementQuick, "Sprint controls", "LeftShift / L3 / touch button", "MovementSprint", 121)
	addToggle(movementQuick, "Compact movement HUD", "Live values when this console is hidden", "MovementShowHUD", 177)
	local restore = button(movementQuick, "Restore captured values", UDim2.fromOffset(16, 247), UDim2.new(0.5, -20, 0, 34))
	restore.Text = "Restore values"
	restore.Activated:Connect(function()
		setSetting("MovementEnabled", false)
		notify("Movement overrides released")
	end)
	local reapply = button(movementQuick, "Reapply profile", UDim2.new(0.5, 4, 0, 247), UDim2.new(0.5, -20, 0, 34))
	reapply.Activated:Connect(function()
		movement.nextDetection = 0
		movement.MarkDirty()
		movement.Update(0)
		notify(movement.ui.status.Text)
	end)
	ui.status = label(movementQuick, "PROFILE OFF", UDim2.fromOffset(16, 288), UDim2.new(1, -32, 0, 19), 10, palette.Muted, Enum.Font.Code)
	local movementMetrics = frame(pages.Movement, "MovementTelemetry", UDim2.new(), UDim2.new(1, 0, 0, 76))
	ui.metrics = {}
	for index, title in {"WALK LIMIT", "JUMP HEIGHT", "GROUND SPEED"} do
		local card = round(frame(movementMetrics, title, UDim2.new((index - 1) / 3, 0, 0, 0), UDim2.new(1 / 3, -8, 1, 0), palette.Card), 8)
		stroke(card, palette.Line, 0.3)
		label(card, title, UDim2.fromOffset(12, 9), UDim2.new(1, -24, 0, 17), 9, palette.Dim, Enum.Font.Code)
		ui.metrics[index] = label(card, "--", UDim2.fromOffset(12, 31), UDim2.new(1, -24, 0, 32), 24, nil, Enum.Font.GothamBold)
	end
	local profiles = section(pages.Movement, "Pick your momentum", "One click applies and enables a complete movement profile.", 132)
	for index, profile in {
		{name = "Balanced", walk = 16, sprint = 28, jump = 7.2},
		{name = "Athlete", walk = 24, sprint = 38, jump = 14},
		{name = "Velocity", walk = 48, sprint = 72, jump = 10},
		{name = "Lunar", walk = 20, sprint = 32, jump = 45},
	} do
		local choice = button(profiles, profile.name .. "\n" .. profile.walk .. " u/s  /  " .. profile.jump .. " u",
			UDim2.new((index - 1) / 4, 16, 0, 72), UDim2.new(1 / 4, -22, 0, 43))
		choice.Name = "MovementPreset" .. profile.name
		choice.TextSize = 10
		choice.Activated:Connect(function()
			settings.MovementEnabled, settings.MovementSpeed, settings.MovementJump, settings.MovementSprint = true, true, true, true
			settings.MovementWalkSpeed, settings.MovementSprintSpeed, settings.MovementJumpHeight = profile.walk, profile.sprint, profile.jump
			movement.StopSprint()
			movement.MarkDirty()
			movement.Update(0)
			refreshAll()
			notify(profile.name .. " movement profile applied")
		end)
		table.insert(controls, function()
			local selected = settings.MovementEnabled and settings.MovementWalkSpeed == profile.walk and settings.MovementSprintSpeed == profile.sprint and math.abs(settings.MovementJumpHeight - profile.jump) < 0.001
			tween(choice, {BackgroundColor3 = selected and accent:Lerp(palette.Card, 0.78) or palette.Raised})
			choice.TextColor3 = selected and accent or palette.Text
		end)
	end
	local speedSide, jumpSide = twoColumns(pages.Movement, 365, 365)
	local speed = section(speedSide, "Pace & sprint", "Drag a slider or click its number to type.", 365)
	addToggle(speed, "Override walk speed", "Your configured walking speed cap", "MovementSpeed", 65)
	addToggle(speed, "Enable sprint", "A separate speed while sprinting", "MovementSprint", 121)
	addSlider(speed, "Walk speed", "MovementWalkSpeed", 0, 160, 0.5, function(value) return string.format("%.1f u/s", value) end, 190, true)
	addSlider(speed, "Sprint speed", "MovementSprintSpeed", 0, 240, 0.5, function(value) return string.format("%.1f u/s", value) end, 267, true)
	label(speed, "Sprint never lowers the selected walk speed.", UDim2.fromOffset(16, 340), UDim2.new(1, -32, 0, 17), 10, palette.Dim)
	local jump = section(jumpSide, "Lift & response", "Uses the character's active jump mode.", 365)
	addToggle(jump, "Override jump height", "Height in studs; power mode is converted", "MovementJump", 65)
	addSlider(jump, "Jump height", "MovementJumpHeight", 0, 150, 0.1, function(value) return string.format("%.1f studs", value) end, 137, true)
	addSlider(jump, "Speed blend time", "MovementSmoothTime", 0, 1, 0.01, function(value) return string.format("%d ms", math.floor(value * 1000 + 0.5)) end, 210, true)
	addChoices(jump, "Sprint behavior", "MovementSprintMode", {"Hold", "Toggle"}, 285)
	local recovery = section(pages.Movement, "Controller & session", "Maintain applies before physics; custom systems still need integration.", 390)
	addToggle(recovery, "Keep profile after respawn", "Apply to the new character when enabled", "MovementKeepOnRespawn", 65)
	addToggle(recovery, "Maintain selected profile", "Reapply selected values before each physics step", "MovementMaintain", 121)
	addChoices(recovery, "Movement backend", "MovementBackend", {"Auto", "Humanoid", "Controller"}, 182)
	ui.controllerInfo = label(recovery, "Detecting movement...", UDim2.fromOffset(16, 258), UDim2.new(1, -32, 0, 64), 10, palette.Muted, Enum.Font.Code)
	ui.controllerInfo.TextWrapped = true
	ui.physics = label(recovery, "", UDim2.fromOffset(16, 329), UDim2.new(1, -32, 0, 17), 10, palette.Dim, Enum.Font.Code)
	local report = button(recovery, "Print full movement audit", UDim2.fromOffset(16, 352), UDim2.new(0.5, -20, 0, 26))
	report.Activated:Connect(function() movement.PrintAudit() end)
	local sample = button(recovery, "Sample for 1 second", UDim2.new(0.5, 4, 0, 352), UDim2.new(0.5, -20, 0, 26))
	sample.Activated:Connect(function()
		movement.capture = {deadline = os.clock() + 1, samples = {}, nextSample = 0}
		notify("Move and jump now; the audit prints in one second")
	end)
	ui.hud = round(frame(screen, "KineticHUD", UDim2.new(1, -18, 0, 104), UDim2.fromOffset(236, 62), palette.Background), 9)
	ui.hud.AnchorPoint = Vector2.new(1, 0)
	ui.hud.ZIndex = 20
	ui.hud.Visible = false
	bindAccent(stroke(ui.hud, accent, 0.45), "Color")
	ui.hudTitle = bindAccent(label(ui.hud, "KINETIC / WALK", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 18), 10, accent, Enum.Font.Code), "TextColor3")
	ui.hudValues = label(ui.hud, "", UDim2.fromOffset(12, 26), UDim2.new(1, -24, 0, 20), 11, nil, Enum.Font.Code)
	local track = round(frame(ui.hud, "Track", UDim2.fromOffset(12, 51), UDim2.new(1, -24, 0, 3), palette.Raised), 2)
	ui.hudFill = bindAccent(round(frame(track, "Fill", UDim2.new(), UDim2.fromScale(0, 1), accent), 2), "BackgroundColor3")
	ui.sprintButton = button(screen, "SPRINT", UDim2.new(1, -112, 1, -166), UDim2.fromOffset(92, 48))
	ui.sprintButton.ZIndex = 20
	ui.sprintButton.Visible = false
	ui.sprintButton.Activated:Connect(function() movement.ToggleTouch() end)
end

local filterCard = section(pages.Filters, "Visibility rules", "Filters apply to markers, highlights, and tracers together.", 265)
addToggle(filterCard, "Team filter", "Hide players who share your non-neutral team", "TeamCheck", 65)
addToggle(filterCard, "Hide eliminated players", "Only show living characters", "HideDead", 121)
addToggle(filterCard, "Use Roblox team colors", "Use each player's team color when available", "UseTeamColors", 177)
local rangeCard = section(pages.Filters, "Render range", "Your character is the origin; the camera is used while respawning.", 150)
addSlider(rangeCard, "Maximum distance", "MaxDistance", 100, 5000, 50, function(value) return string.format("%d studs", value) end, 74)

do
	local themeCard = section(pages.Appearance, "Accent palette", "Choose a preset or mix your own accent.", 245)
	addChoices(themeCard, "Accent preset", "Theme", persistence.choices.Theme, 60, 4)
	label(themeCard, "CUSTOM HEX", UDim2.fromOffset(16, 175), UDim2.fromOffset(112, 19), 9, palette.Dim, Enum.Font.Code)
	local swatch = round(frame(themeCard, "CustomAccentPreview", UDim2.fromOffset(16, 199), UDim2.fromOffset(34, 29), settings.CustomAccent), 6)
	skin.accentInput = round(make("TextBox", {
		Name = "CustomAccentHex", Text = skin.FormatHex(settings.CustomAccent), ClearTextOnFocus = false,
		PlaceholderText = "#72C1FF", Position = UDim2.fromOffset(58, 199), Size = UDim2.fromOffset(112, 29),
		Font = Enum.Font.Code, TextColor3 = palette.Text, PlaceholderColor3 = palette.Dim, TextSize = 12,
		BackgroundColor3 = palette.Background, BorderSizePixel = 0,
	}, themeCard), 6)
	stroke(skin.accentInput, palette.Line, 0.2)
	local apply = button(themeCard, "Apply hex", UDim2.fromOffset(178, 199), UDim2.fromOffset(92, 29))
	local function applyHex()
		local color = skin.ParseHex(skin.accentInput.Text)
		if not color then
			skin.accentInput.Text = skin.FormatHex(settings.CustomAccent)
			notify("Enter a six-digit hex color, such as #FF85BD")
			return
		end
		settings.CustomAccent = color
		setSetting("Theme", "Custom")
	end
	apply.Activated:Connect(applyHex)
	skin.accentInput.FocusLost:Connect(function(enterPressed)
		if enterPressed then applyHex() end
	end)
	table.insert(controls, function()
		swatch.BackgroundColor3 = settings.CustomAccent
		if not skin.accentInput:IsFocused() then skin.accentInput.Text = skin.FormatHex(settings.CustomAccent) end
	end)
end
do
	local left, right = twoColumns(pages.Appearance, 326, 326)
	local shell = section(left, "Window style", "Set the panel tint and make room for content.", 326)
	addChoices(shell, "Panel tint", "PanelStyle", persistence.choices.PanelStyle, 61, 2)
	addSlider(shell, "Panel opacity", "PanelOpacity", 0.55, 1, 0.05, percent, 173)
	addChoices(shell, "Navigation", "NavigationStyle", persistence.choices.NavigationStyle, 244)
	local motion = section(right, "Motion & scale", "Fine-tune the feel of the workspace.", 326)
	addToggle(motion, "Ambient effects", "Radar motion and accent glow", "UIEffects", 60)
	addToggle(motion, "Reduced motion", "Instant UI transitions and static endpoints", "ReducedMotion", 116)
	addSlider(motion, "Animation speed", "UIMotionSpeed", 0.5, 2, 0.25, function(value) return string.format("%gx", value) end, 179)
	addSlider(motion, "Interface scale", "UIScale", 0.75, 1.15, 0.05, percent, 252)
end
local colorLeft, colorRight = twoColumns(pages.Appearance, 145, 145)
local swatchColors = {
	Color3.fromRGB(255, 109, 139), Color3.fromRGB(100, 218, 255), Color3.fromRGB(177, 150, 255),
	Color3.fromRGB(103, 230, 186), Color3.fromRGB(255, 191, 105), Color3.fromRGB(235, 240, 255),
}
local function addSwatches(parent, title, key)
	local card = section(parent, title, "Used when team colors are disabled.", 145)
	for index, color in swatchColors do
		local choice = round(make("TextButton", {
			Name = "Color" .. index, Text = "", AutoButtonColor = false, BackgroundColor3 = color,
			BorderSizePixel = 0, Position = UDim2.new((index - 1) / #swatchColors, 16, 0, 80),
			Size = UDim2.new(1 / #swatchColors, -21, 0, 32),
		}, card), 5)
		local border = stroke(choice, palette.Text, 1, 2)
		choice.Activated:Connect(function() setSetting(key, color) end)
		table.insert(controls, function() border.Transparency = settings[key] == color and 0 or 1 end)
	end
end
addSwatches(colorLeft, "Other players", "EnemyColor")
addSwatches(colorRight, "Friendly players", "FriendlyColor")
table.insert(controls, function()
	for _, surface in skin.chrome do surface.BackgroundTransparency = 1 - settings.PanelOpacity end
	skin.windowBorder.Color = settings.UIEffects and accent:Lerp(palette.Line, 0.6) or palette.Line
	skin.windowBorder.Transparency = settings.UIEffects and 0.15 or 0.05
	accentGradient.Enabled = settings.UIEffects
	skin.wash.Visible = settings.UIEffects
	skin.radar.Visible = settings.UIEffects
end)
local savedCard = section(pages.Appearance, "Saved settings", "Your choices reload automatically the next time you run.", 155)
persistence.label = label(savedCard, persistence.status, UDim2.fromOffset(16, 65), UDim2.new(1, -32, 0, 32), 11, palette.Muted, Enum.Font.Code)
persistence.label.Name = "SettingsSaveStatus"
persistence.label.TextWrapped = true
local saveNow = button(savedCard, "Save now", UDim2.fromOffset(16, 109), UDim2.new(1, -32, 0, 31))
saveNow.Activated:Connect(function()
	if persistence.Flush(true) then notify(persistence.status) else notify("Settings could not be saved; see save status") end
end)
local resetCard = section(pages.Appearance, "Fresh start", "Restore defaults and save them for next time.", 118)
local reset = button(resetCard, "Reset settings", UDim2.fromOffset(16, 70), UDim2.new(1, -32, 0, 32))
reset.Activated:Connect(function()
	settings = table.clone(defaults)
	releaseAim(true)
	movement.StopSprint()
	movement.MarkDirty()
	movement.Update(0)
	refreshAll()
	updateLayout()
	persistence.Flush(true)
	notify("Default settings restored")
end)

local function refreshNavigation()
	for name, data in navigation do
		local selected = name == currentPage
		data.button.BackgroundColor3 = accent:Lerp(palette.Card, 0.85)
		tween(data.button, {BackgroundTransparency = selected and 0 or 1})
		data.caption.TextColor3 = selected and palette.Text or palette.Muted
		data.number.TextColor3 = selected and accent or palette.Dim
		data.line.BackgroundColor3 = accent
		data.line.Visible = selected
		data.tab.TextColor3 = selected and palette.Text or palette.Muted
		data.tab.BackgroundTransparency = selected and 0 or 1
		data.underline.BackgroundColor3 = accent
		data.underline.Visible = selected
		if selected and not data.wasSelected then
			data.underline.Size = UDim2.fromOffset(0, 2)
			tween(data.underline, {Size = UDim2.new(1, -24, 0, 2)}, 0.24)
		end
		data.wasSelected = selected
	end
end
selectPage = function(name)
	if currentPage == name and pages[name].Visible then return end
	currentPage = name
	for pageName, page in pages do page.Visible = pageName == name end
	local page = pages[name]
	page.Position = UDim2.fromOffset(settings.ReducedMotion and 22 or 34, 0)
	tween(page, {Position = UDim2.fromOffset(22, 0)}, 0.26)
	refreshNavigation()
end
updatePreview = function()
	local enabled = settings.Enabled
	previewRig.Visible = enabled
	previewBox.Visible = enabled and settings.ShowBoxes
	previewBoxStroke.Color = settings.EnemyColor
	previewName.Visible = enabled and settings.ShowNames
	local parts = {}
	if settings.ShowHealth then table.insert(parts, "86 HP") end
	if settings.ShowDistance then table.insert(parts, "24 studs") end
	previewMeta.Text = table.concat(parts, "  /  ")
	previewMeta.Visible = enabled
	previewHealth.Visible = enabled and settings.ShowHealth
	previewTracer.Visible = enabled and settings.ShowTracers
	previewTracer.BackgroundColor3 = settings.EnemyColor
	previewTracer.BackgroundTransparency = 1 - settings.TracerOpacity
	previewTracer.Size = UDim2.new(0, settings.TracerWidth, 0.5, -85)
	for _, part in previewParts do
		part.BackgroundColor3 = settings.ShowHighlights and settings.EnemyColor or palette.Dim
		part.BackgroundTransparency = settings.ShowHighlights and settings.HighlightFillTransparency or 0.25
	end
	heroStatus.Text = enabled and "OVERLAY ONLINE" or "OVERLAY PAUSED"
	heroStatus.TextColor3 = enabled and palette.Green or palette.Muted
	skin.heroDot.BackgroundColor3 = enabled and palette.Green or palette.Dim
	metricLabels[3].Text = string.format("%d", settings.MaxDistance)
end
refreshAll = function()
	skin.ApplyPalette()
	accent = skin.Accent(settings.Theme)
	for _, binding in accentBindings do binding[1][binding[2]] = accent end
	for _, refresh in controls do refresh() end
	refreshNavigation()
	updatePreview()
	persistence.Schedule()
end
search:GetPropertyChangedSignal("Text"):Connect(function()
	local query = string.lower(search.Text)
	local count = 0
	for name, data in navigation do
		local matches = string.find(string.lower(name .. " " .. data.keywords), query, 1, true) ~= nil
		data.button.Visible = matches
		if matches then count += 1 end
	end
	noResults.Visible = count == 0
end)

-- Safe-area positioning, compact navigation, continuous mouse/touch dragging.
local layoutWidth, layoutHeight, layoutScale = 960, 650, 1
local safeMin, safeMax = Vector2.new(12, 12), Vector2.new(1200, 800)
-- Input may arrive before CurrentCamera exists and the first layout pass runs.
local hostPosition = Vector2.new(host.Position.X.Offset, host.Position.Y.Offset)
local needsInitialCenter = true
local function clampPosition(position)
	local maximum = safeMax - Vector2.new(layoutWidth * layoutScale, layoutHeight * layoutScale)
	return Vector2.new(
		math.clamp(position.X, safeMin.X, math.max(safeMin.X, maximum.X)),
		math.clamp(position.Y, safeMin.Y, math.max(safeMin.Y, maximum.Y)))
end
local function positionHost(position)
	hostPosition = clampPosition(position)
	host.Position = UDim2.fromOffset(hostPosition.X, hostPosition.Y)
end
updateLayout = function(recenter)
	local camera = workspace.CurrentCamera
	if not camera then return end
	refreshAimRadius()
	local viewport = camera.ViewportSize
	local topLeft, bottomRight = GuiService:GetGuiInset()
	safeMin = topLeft + Vector2.new(12, 12)
	safeMax = viewport - bottomRight - Vector2.new(12, 12)
	local available = safeMax - safeMin
	local compact = available.X < 760
	layoutScale = math.max(0.1, math.min(settings.UIScale, available.Y / 650, available.X / (compact and 520 or 960)))
	layoutWidth = compact and math.min(760, available.X / layoutScale) or 960
	layoutHeight = 650
	host.Size = UDim2.fromOffset(layoutWidth, layoutHeight)
	hostScale.Scale = layoutScale
	local showSidebar = not compact and settings.NavigationStyle == "Adaptive"
	sidebar.Visible = showSidebar
	if not showSidebar and search:IsFocused() then search:ReleaseFocus() end
	edition.Visible = not compact
	local offset = showSidebar and 196 or 0
	tabbar.Position = UDim2.fromOffset(offset, 50)
	tabbar.Size = UDim2.new(1, -offset, 0, 43)
	body.Position = UDim2.fromOffset(offset, 93)
	body.Size = UDim2.new(1, -offset, 1, -121)
	local stacked = layoutWidth - offset - 44 < 570
	for _, column in columns do
		column.left.Size = UDim2.new(stacked and 1 or 0.5, stacked and 0 or -7, 0, column.leftHeight)
		column.right.Size = UDim2.new(stacked and 1 or 0.5, stacked and 0 or -7, 0, column.rightHeight)
		column.right.Position = stacked and UDim2.fromOffset(0, column.leftHeight + 14) or UDim2.new(0.5, 7, 0, 0)
		column.container.Size = UDim2.new(1, 0, 0, stacked and (column.leftHeight + column.rightHeight + 14) or math.max(column.leftHeight, column.rightHeight))
	end
	if recenter or needsInitialCenter then
		positionHost(safeMin + (available - Vector2.new(layoutWidth * layoutScale, layoutHeight * layoutScale)) / 2)
	else positionHost(hostPosition) end
	needsInitialCenter = false
	launcher.Position = UDim2.fromOffset(safeMin.X + 4, viewport.Y - bottomRight.Y - 50)
	aimButton.Position = UDim2.fromOffset(viewport.X - bottomRight.X - 112, viewport.Y - bottomRight.Y - 106)
	aimStatusPanel.Position = UDim2.new(0.5, 0, 0, safeMin.Y + 8)
	aimStatusPanel.Size = UDim2.fromOffset(math.max(120, math.min(360, viewport.X - 24)), 32)
	movement.ui.hud.Position = UDim2.fromOffset(viewport.X - bottomRight.X - 18, safeMin.Y + 54)
	movement.ui.sprintButton.Position = UDim2.fromOffset(viewport.X - bottomRight.X - 112, viewport.Y - bottomRight.Y - 166)
	toast.Position = UDim2.new(0.5, 0, 1, -bottomRight.Y - 28)
end
dragHandle.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if needsInitialCenter then updateLayout() end
		activePointer = {kind = "drag", input = input, start = input.Position, position = hostPosition}
		-- A late camera must not recenter the console over an in-progress drag.
		needsInitialCenter = false
	end
end)
connect(UserInputService.InputChanged, function(input)
	if not activePointer then return end
	local isMouse = activePointer.input.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement
	if not isMouse and input ~= activePointer.input then return end
	if activePointer.kind == "slider" then activePointer.move(input.Position.X)
	else
		local delta = input.Position - activePointer.start
		positionHost(activePointer.position + Vector2.new(delta.X, delta.Y))
	end
end)
connect(UserInputService.InputEnded, function(input)
	movement.EndInput(input)
	if input == aimHeldInput or ((aimHeldInput or aimMousePolled) and isAimInput(input)) then releaseAim() end
	if activePointer and (input == activePointer.input or (input.UserInputType == Enum.UserInputType.MouseButton1 and activePointer.input.UserInputType == Enum.UserInputType.MouseButton1)) then
		activePointer = nil
	end
end)
connect(UserInputService.WindowFocusReleased, function()
	activePointer = nil
	aimWindowFocused = false
	releaseAim(true)
	movement.StopSprint()
end)
connect(UserInputService.WindowFocused, function() aimWindowFocused = true end)

local opened, openRevision = true, 0
setOpen = function(value)
	opened = value
	openRevision += 1
	local revision = openRevision
	activePointer = nil
	releaseAim(true)
	movement.StopSprint()
	aimButton.Visible = settings.AimEnabled and UserInputService.TouchEnabled and not value
	if value then aimCircle.Visible = false; aimStatusPanel.Visible = false end
	if value then
		host.Visible = true
		tween(window, {GroupTransparency = 0, Position = UDim2.new()}, 0.3)
		tween(shadow, {BackgroundTransparency = 0.68}, 0.3)
	else
		tween(window, {GroupTransparency = 1, Position = UDim2.fromOffset(0, 12)}, 0.19)
		tween(shadow, {BackgroundTransparency = 1}, 0.19)
		if search:IsFocused() then search:ReleaseFocus() end
		if skin.accentInput:IsFocused() then skin.accentInput:ReleaseFocus() end
		task.delay(skin.Duration(0.2), function()
			if alive and revision == openRevision and not opened then host.Visible = false end
		end)
	end
	launcher.Text = value and "[ / ]   MINIMIZE" or "[ / ]   ESP STUDIO"
end
launcher.Activated:Connect(function() setOpen(not opened) end)
minimizeButton.Activated:Connect(function() setOpen(false) end)
centerButton.Activated:Connect(function() updateLayout(true); notify("Workspace centered") end)
local function beginAim(input)
	if UserInputService:GetFocusedTextBox() or GuiService.MenuIsOpen or not aimWindowFocused then
		releaseAim(true)
		return
	end
	if settings.AimEnabled and not opened then
		aimNeedsFreshMouse = false
		aimMousePolled = false
		aimHeld, aimHeldInput = true, input
		aimButton.Text = "AIMING"
	end
end
aimButton.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then beginAim(input) end
end)
connect(UserInputService.InputBegan, function(input, processed)
	movement.HandleInput(input, processed)
	if not processed and not UserInputService:GetFocusedTextBox() and input.KeyCode == Enum.KeyCode.RightShift then setOpen(not opened) end
	-- Another input handler may process RMB. The explicitly enabled mouse hold still applies;
	-- text input, the console, the Roblox menu, and window focus are checked separately.
	if isAimInput(input) and (not processed or input.UserInputType == Enum.UserInputType.MouseButton2) then beginAim(input) end
end)

-- Overlay renderer: native GUI lines stay aligned in first/third person and after respawn.
local records = {}
local cornerDefinitions = {
	{0, 0, false}, {0, 0, true}, {1, 0, false}, {1, 0, true},
	{0, 1, false}, {0, 1, true}, {1, 1, false}, {1, 1, true},
}
local boundsCorners = {
	Vector3.new(-1, -1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, 1, 1),
	Vector3.new(1, -1, -1), Vector3.new(1, -1, 1), Vector3.new(1, 1, -1), Vector3.new(1, 1, 1),
}
local function makeLine(parent, name, thickness, color)
	local line = round(frame(parent, name, UDim2.new(), UDim2.fromOffset(1, thickness), color), 2)
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	return line
end
local function placeLine(line, origin, target, width)
	local delta = target - origin
	line.Position = UDim2.fromOffset((origin.X + target.X) / 2, (origin.Y + target.Y) / 2)
	line.Size = UDim2.fromOffset(delta.Magnitude, width)
	line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
end
local function hideRecord(data)
	data.marker.Visible = false
	data.tracer.Visible = false
	if data.highlight then data.highlight.Enabled = false end
end
local function unbindCharacter(data)
	if data.highlight then data.highlight:Destroy(); data.highlight = nil end
	data.character, data.rootPart, data.humanoid, data.boundsOffset = nil, nil, nil, nil
	hideRecord(data)
end
local function removePlayer(player)
	local data = records[player]
	if not data then return end
	for _, connection in data.connections do connection:Disconnect() end
	unbindCharacter(data)
	data.marker:Destroy()
	data.tracer:Destroy()
	records[player] = nil
end
local function hookPlayer(player)
	if player == localPlayer or records[player] then return end
	local marker = frame(markerLayer, player.Name, UDim2.new(), UDim2.fromOffset(100, 150))
	marker.Visible = false
	local box = frame(marker, "CornerBox", UDim2.new(), UDim2.fromScale(1, 1))
	local corners = {}
	for _, definition in cornerDefinitions do
		local corner = frame(box, "Corner", UDim2.fromScale(definition[1], definition[2]), UDim2.fromOffset(12, 2), settings.EnemyColor)
		corner.AnchorPoint = Vector2.new(definition[1], definition[2])
		stroke(corner, Color3.new(), 0.5)
		table.insert(corners, corner)
	end
	local tag = round(frame(marker, "Nameplate", UDim2.new(0.5, 0, 0, -9), UDim2.fromOffset(174, 48), palette.Background), 6)
	tag.AnchorPoint = Vector2.new(0.5, 1)
	tag.BackgroundTransparency = 0.12
	stroke(tag, palette.Line, 0.1)
	local tagScale = make("UIScale", {Scale = 1}, tag)
	local tagAccent = frame(tag, "Accent", UDim2.fromOffset(0, 10), UDim2.fromOffset(2, 24), settings.EnemyColor)
	local name = label(tag, player.DisplayName, UDim2.fromOffset(10, 3), UDim2.new(1, -20, 0, 20), 12, nil, Enum.Font.GothamBold)
	local meta = label(tag, "", UDim2.fromOffset(10, 24), UDim2.new(1, -20, 0, 16), 10, palette.Muted, Enum.Font.Code)
	local healthTrack = round(frame(tag, "Health", UDim2.new(0, 10, 1, -5), UDim2.new(1, -20, 0, 2), palette.Raised), 1)
	local healthFill = round(frame(healthTrack, "Fill", UDim2.new(), UDim2.fromScale(1, 1), palette.Green), 1)
	local tracer = frame(tracerLayer, player.Name, UDim2.new(), UDim2.fromScale(1, 1))
	tracer.Visible = false
	local glow = makeLine(tracer, "Glow", 5, settings.EnemyColor)
	glow.BackgroundTransparency = 0.93
	local line = makeLine(tracer, "Line", 1.5, settings.EnemyColor)
	stroke(line, palette.Background, 0.55)
	local endpoint = round(frame(tracer, "Endpoint", UDim2.new(), UDim2.fromOffset(5, 5), settings.EnemyColor), 5)
	endpoint.AnchorPoint = Vector2.new(0.5, 0.5)
	local data = {
		marker = marker, box = box, corners = corners, tag = tag, tagScale = tagScale,
		tagAccent = tagAccent, name = name, meta = meta, healthTrack = healthTrack, healthFill = healthFill,
		tracer = tracer, line = line, glow = glow, endpoint = endpoint,
		connections = {}, healthRatio = 1, nextBounds = 0,
	}
	records[player] = data
	local function bindCharacter(character)
		unbindCharacter(data)
		data.character = character
	end
	table.insert(data.connections, player.CharacterAdded:Connect(bindCharacter))
	table.insert(data.connections, player.CharacterRemoving:Connect(function(character)
		if data.character == character then unbindCharacter(data) end
	end))
	if player.Character then bindCharacter(player.Character) end
end
local function friendly(player)
	return player.Team ~= nil and localPlayer.Team ~= nil and not player.Neutral and not localPlayer.Neutral and player.Team == localPlayer.Team
end
local function targetColor(player)
	if settings.UseTeamColors and player.Team and not player.Neutral then return player.TeamColor.Color end
	return friendly(player) and settings.FriendlyColor or settings.EnemyColor
end

-- Camera-only assistance; selection and visibility use the same viewport space as the ring.
local aimRaycastParams = RaycastParams.new()
aimRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
aimRaycastParams.IgnoreWater = true
local function chooseAimTarget(camera, localCharacter, localRoot)
	local center = camera.ViewportSize / 2
	local radiusSquared = settings.AimRadiusFullScreen and math.huge or settings.AimRadius ^ 2
	local bestPart, bestScore, bestUserId = nil, radiusSquared, math.huge
	local bestPlayer
	local counts = {players = 0, living = 0, teams = 0, range = 0, view = 0, radius = 0}
	aimRaycastParams.FilterDescendantsInstances = {localCharacter, camera}
	for player, data in records do
		counts.players += 1
		local character = data.character
		if not character or not character:IsDescendantOf(workspace) then continue end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not humanoid or humanoid.Health <= 0 or not rootPart then continue end
		counts.living += 1
		if settings.AimTeamCheck and friendly(player) then continue end
		counts.teams += 1
		local part = settings.AimPart == "Head" and character:FindFirstChild("Head") or rootPart
		if not part or not part:IsA("BasePart") then part = rootPart end
		if not part:IsA("BasePart") then continue end
		if (part.Position - localRoot.Position).Magnitude > settings.AimRange then continue end
		counts.range += 1
		local projected, onScreen = camera:WorldToViewportPoint(part.Position)
		if not onScreen or projected.Z <= 0 then continue end
		counts.view += 1
		local offset = Vector2.new(projected.X, projected.Y) - center
		local score = offset.X ^ 2 + offset.Y ^ 2
		if score > radiusSquared then continue end
		counts.radius += 1
		if score > bestScore or (score == bestScore and player.UserId >= bestUserId) then continue end
		local direction = part.Position - camera.CFrame.Position
		if direction.Magnitude < 0.001 then continue end
		if settings.AimVisibilityCheck then
			local hit = workspace:Raycast(camera.CFrame.Position, direction, aimRaycastParams)
			if hit and not hit.Instance:IsDescendantOf(character) then continue end
		end
		bestPart, bestScore, bestUserId = part, score, player.UserId
		bestPlayer = player
	end
	if bestPart then return bestPart, bestPlayer, nil end
	local reason = "Target blocked by world geometry"
	if counts.players == 0 then reason = "No other players in the session"
	elseif counts.living == 0 then reason = "Waiting for a living player character"
	elseif counts.teams == 0 then reason = "Team check excludes all players"
	elseif counts.range == 0 then reason = "Players are beyond maximum aim range"
	elseif counts.view == 0 then reason = "No eligible player is on screen"
	elseif counts.radius == 0 then reason = "Move a player's aim point inside the circle" end
	return nil, nil, reason
end
local function updateAim(dt)
	local camera = workspace.CurrentCamera
	local active = settings.AimEnabled and not opened and camera ~= nil
	aimButton.Visible = active and UserInputService.TouchEnabled
	aimCircle.Visible = active and settings.AimShowRadius
	aimStatusPanel.Visible = settings.AimEnabled and not opened
	aimDot.Visible = false
	aimCircleStroke.Color = accent
	if not active then
		releaseAim(true)
		if not settings.AimEnabled then showAimStatus("Aim assist is disabled")
		elseif not opened then showAimStatus("Waiting for a camera") end
		return
	end
	aimCircle.Position = UDim2.fromOffset(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
	local cap = aimRadiusCap()
	local radius = settings.AimRadiusFullScreen and cap or math.min(settings.AimRadius, cap)
	aimCircle.Size = UDim2.fromOffset(radius * 2, radius * 2)
	if not aimWindowFocused then releaseAim(true); showAimStatus("Click the game window to aim"); return end
	if GuiService.MenuIsOpen then releaseAim(true); showAimStatus("Close the Roblox menu to aim"); return end
	if UserInputService:GetFocusedTextBox() then releaseAim(true); showAimStatus("Finish typing before aiming"); return end
	if camera.CameraType == Enum.CameraType.Scriptable then
		releaseAim(true)
		showAimStatus("Custom camera active: aim assist paused")
		return
	end
	local character = localPlayer.Character
	local localRoot = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not localRoot or not humanoid or humanoid.Health <= 0 then
		releaseAim(true); showAimStatus("Waiting for your living character"); return
	end
	-- Poll RMB as well as listening to events, so a consumed/missed InputBegan cannot
	-- leave the circle idle. Interruptions still require release followed by a fresh hold.
	local waitingForRelease = false
	if settings.AimKey == "RMB" then
		local mouseDown = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
		local mouseSource = aimMousePolled or (aimHeldInput and aimHeldInput.UserInputType == Enum.UserInputType.MouseButton2)
		if not mouseDown then
			aimNeedsFreshMouse = false
			if mouseSource then releaseAim() end
		elseif not aimNeedsFreshMouse and not aimHeld then
			aimHeld, aimMousePolled = true, true
			aimButton.Text = "AIMING"
		elseif aimNeedsFreshMouse then
			waitingForRelease = true
		end
	end
	if not aimHeld then
		showAimStatus(waitingForRelease and "Release RMB, then hold it again" or ("Hold " .. settings.AimKey .. " / L2 / AIM to acquire a target"))
		return
	end
	local part, player, reason = chooseAimTarget(camera, character, localRoot)
	if not part then showAimStatus(reason); return end
	local goal = CFrame.lookAt(camera.CFrame.Position, part.Position)
	local smoothTime = settings.AimSmoothTime
	if smoothTime == 0 then
		camera.CFrame = goal
	else
		local alpha = 1 - math.exp(-math.max(0, dt) / math.max(0.01, smoothTime))
		camera.CFrame = camera.CFrame:Lerp(goal, alpha)
	end
	local point = camera:WorldToViewportPoint(part.Position)
	aimDot.Position = UDim2.fromOffset(point.X, point.Y)
	aimDot.Visible = true
	aimCircleStroke.Color = palette.Green
	showAimStatus("Aiming: " .. player.DisplayName, true)
end
local aimRenderName = "ESPStudioAim_" .. HttpService:GenerateGUID(false)
local aimBound = false
local function screenBounds(camera, data, now)
	local rootPart = data.rootPart
	if not data.boundsOffset or now >= data.nextBounds then
		local boundingCFrame, size = data.character:GetBoundingBox()
		data.boundsOffset = rootPart.CFrame:ToObjectSpace(boundingCFrame)
		-- Clamp extreme accessories so one oversized hat cannot fill the viewport.
		data.boundsSize = Vector3.new(math.clamp(size.X, 3, 12), math.clamp(size.Y, 5, 16), math.clamp(size.Z, 2, 10))
		data.nextBounds = now + 0.2
	end
	local cframe = rootPart.CFrame * data.boundsOffset
	local half = data.boundsSize / 2
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	for _, corner in boundsCorners do
		local point = camera:WorldToViewportPoint(cframe:PointToWorldSpace(corner * half))
		if point.Z <= 0.1 then return nil end
		minX, minY = math.min(minX, point.X), math.min(minY, point.Y)
		maxX, maxY = math.max(maxX, point.X), math.max(maxY, point.Y)
	end
	return Vector2.new(minX, minY), Vector2.new(maxX - minX, maxY - minY)
end

-- Maintained profiles run before physics. Observe mode remains available.
function movement.Finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end
function movement.Read(owner, property, attribute)
	if not owner then return nil end
	if attribute then return owner:GetAttribute(property) end
	return owner[property]
end
function movement.Write(property, value, owner, attribute)
	owner = owner or movement.humanoid
	local existing = movement.owned[property]
	if existing and (existing.owner ~= owner or existing.attribute ~= attribute) then movement.Release(property) end
	if not movement.owned[property] then
		local before = movement.Read(owner, property, attribute)
		movement.owned[property] = {owner = owner, attribute = attribute, before = movement.Finite(before) and before or nil}
	end
	if attribute then owner:SetAttribute(property, value) else owner[property] = value end
	movement.owned[property].last = movement.Read(owner, property, attribute)
	movement.owned[property].lastObserved = nil
end
function movement.RecordRewrite(property, entry, value)
	if entry.lastObserved == value then return end
	entry.lastObserved = value
	movement.rewriteCounts[property] = (movement.rewriteCounts[property] or 0) + 1
	movement.lastRewrite = {property = property, value = tostring(value), time = os.clock()}
	if settings.MovementMaintain and movement.Finite(value) then entry.before = value end
end
function movement.Release(property)
	local entry = movement.owned[property]
	local owner = entry and entry.owner
	local current = entry and movement.Read(owner, property, entry.attribute)
	if entry and owner and movement.Finite(entry.before) and movement.Finite(current) and math.abs(current - entry.last) < 0.001 then
		if entry.attribute then owner:SetAttribute(property, entry.before) else owner[property] = entry.before end
	end
	movement.owned[property] = nil
end
function movement.Restore()
	movement.Release("WalkSpeed")
	movement.Release("BaseMoveSpeed")
	movement.Release("JumpHeight")
	movement.Release("JumpPower")
	movement.ramping, movement.targetSpeed, movement.blendValue = false, nil, nil
	movement.speedExternal, movement.jumpExternal = false, false
	movement.speedDirty, movement.jumpDirty = true, true
end
function movement.Attach(humanoid, manager, jumping)
	if movement.humanoid == humanoid and movement.manager == manager and movement.jumping == jumping then return end
	movement.Restore()
	movement.humanoid, movement.manager, movement.jumping = humanoid, manager, jumping
	movement.lastMode, movement.lastGravity = nil, nil
	movement.speedDirty, movement.jumpDirty = true, true
end
function movement.StopSprint()
	movement.sprintHeld, movement.sprintToggled, movement.sprintInput = false, false, nil
	movement.speedDirty = true
end
function movement.MarkDirty(key)
	if key == "MovementBackend" then movement.nextDetection = 0; movement.StopSprint() end
	if key == "MovementMaintain" then movement.blendValue = nil end
	if key == nil or key == "MovementMaintain" or key == "MovementBackend" or key == "MovementEnabled" or key == "MovementSpeed" or key == "MovementSprint"
		or key == "MovementSprintMode" or key == "MovementWalkSpeed" or key == "MovementSprintSpeed" or key == "MovementSmoothTime" then
		movement.speedDirty = true
	end
	if key == nil or key == "MovementMaintain" or key == "MovementBackend" or key == "MovementEnabled" or key == "MovementJump" or key == "MovementJumpHeight" then movement.jumpDirty = true end
	if key == "MovementSprintMode" or not settings.MovementEnabled or not settings.MovementSprint then movement.StopSprint() end
end
function movement.IsSprinting()
	return settings.MovementEnabled and settings.MovementSpeed and settings.MovementSprint
		and not opened and aimWindowFocused and not GuiService.MenuIsOpen and not UserInputService:GetFocusedTextBox()
		and (movement.sprintHeld or movement.sprintToggled)
end
function movement.HandleInput(input, processed)
	if (processed and not settings.MovementMaintain) or opened or not aimWindowFocused or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() then return end
	if not settings.MovementEnabled or not settings.MovementSpeed or not settings.MovementSprint then return end
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL3 then
		if settings.MovementSprintMode == "Toggle" then movement.sprintToggled = not movement.sprintToggled
		else movement.sprintHeld, movement.sprintInput = true, input end
		movement.speedDirty = true
		movement.Update(0)
	end
end
function movement.EndInput(input)
	if movement.sprintHeld and movement.sprintInput and (input == movement.sprintInput or input.KeyCode == movement.sprintInput.KeyCode) then
		movement.sprintHeld, movement.sprintInput = false, nil
		movement.speedDirty = true
		movement.Update(0)
	end
end
function movement.ToggleTouch()
	if opened or not aimWindowFocused or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() then return end
	if not settings.MovementEnabled or not settings.MovementSpeed or not settings.MovementSprint then return end
	movement.sprintToggled = not movement.sprintToggled
	movement.speedDirty = true
	movement.Update(0)
end
function movement.Detect(character, humanoid)
	if not character then movement.detection = nil; return {} end
	local now = os.clock()
	local cached = movement.detection
	if cached and movement.detectedCharacter == character and movement.detectedHumanoid == humanoid
		and now < (movement.nextDetection or 0) and (not cached.manager or cached.manager.Parent)
		and (not cached.jumping or cached.jumping.Parent) and (not cached.dead or cached.dead.Parent) then return cached end
	local canonicalRoot = character:FindFirstChild("HumanoidRootPart") or (humanoid and humanoid.RootPart) or character.PrimaryPart
	local manager, bestScore, tied, count = nil, -1, false, 0
	for _, object in character:GetDescendants() do
		if object:IsA("ControllerManager") then
			count += 1
			local root = object.RootPart
			local score = (canonicalRoot and root == canonicalRoot and 8 or 0)
				+ (object.ActiveController and 4 or 0) + (root and root:IsDescendantOf(character) and 2 or 0)
			if score > bestScore then manager, bestScore, tied = object, score, false
			elseif score == bestScore then tied = true end
		end
	end
	if tied then manager = nil end
	local actor = character:FindFirstChild("AbilityManagerActor")
	local abilities = (actor and actor:FindFirstChild("Abilities")) or character:FindFirstChild("Abilities")
	local jumping = abilities and abilities:FindFirstChild("Jumping")
	if jumping and not jumping:IsA("Configuration") then jumping = nil end
	local dead = abilities and abilities:FindFirstChild("Dead")
	if dead and not dead:IsA("Configuration") then dead = nil end
	cached = {manager = manager, jumping = jumping, dead = dead, root = canonicalRoot, managerCount = count, ambiguous = tied}
	movement.detection, movement.detectedCharacter, movement.detectedHumanoid = cached, character, humanoid
	movement.nextDetection = now + 0.25
	return cached
end
function movement.SpeedBinding(humanoid)
	if movement.manager then return movement.manager, "BaseMoveSpeed" end
	if settings.MovementBackend ~= "Humanoid" and movement.detection and movement.detection.ambiguous then return nil, nil end
	if settings.MovementBackend == "Controller" then return nil, nil end
	if humanoid and humanoid.EvaluateStateMachine ~= false then return humanoid, "WalkSpeed" end
	return nil, nil
end
function movement.JumpBinding(humanoid)
	if settings.MovementBackend ~= "Humanoid" and movement.detection and movement.detection.ambiguous then return nil, nil, nil end
	if settings.MovementBackend == "Controller" and not movement.manager then return nil, nil, nil end
	local jumping = movement.jumping
	if jumping then
		local power = jumping:GetAttribute("UseJumpPower")
		local value = jumping:GetAttribute(power and "JumpPower" or "JumpHeight")
		if type(power) == "boolean" and type(value) == "number" and value == value and math.abs(value) < math.huge then return jumping, true, power end
	end
	if humanoid and humanoid.EvaluateStateMachine ~= false then return humanoid, nil, humanoid.UseJumpPower end
	return nil, nil, nil
end
function movement.Living(humanoid, root)
	local dead = movement.detection and movement.detection.dead
	local health = dead and dead:GetAttribute("Health")
	if movement.manager and type(health) == "number" and health <= 0 then return false end
	if humanoid then return humanoid.Health > 0 end
	return movement.manager ~= nil and root ~= nil
end
function movement.Diagnostics()
	local humanoid, manager = movement.humanoid, movement.manager
	local speedOwner, speedProperty = movement.SpeedBinding(humanoid)
	local jumpOwner, attribute, power = movement.JumpBinding(humanoid)
	local root = movement.root
	local state = humanoid and tostring(humanoid:GetState()):gsub("^Enum%.HumanoidStateType%.", "") or "no Humanoid"
	local active = manager and manager.ActiveController
	local direction = manager and manager.MovingDirection or (humanoid and humanoid.MoveDirection)
	return string.format("KINETIC 3 | %s | Backend=%s | Speed=%s:%s | Jump=%s | RootAnchored=%s | State=%s | Active=%s | Input=%.2f | Requested=%.1f/%.1f",
		settings.MovementMaintain and "MAINTAIN / PRE-PHYSICS" or "OBSERVE REWRITES",
		manager and "ControllerManager" or (speedOwner and "Humanoid" or "Unsupported/custom"),
		speedOwner and speedOwner.ClassName or "none", speedProperty or "none",
		jumpOwner and ((attribute and "CCL.Jumping." or "Humanoid.") .. (power and "JumpPower" or "JumpHeight")) or "adapter required",
		tostring(root and root.Anchored or false), state, active and active.ClassName or "none", direction and direction.Magnitude or 0,
		settings.MovementWalkSpeed, settings.MovementJumpHeight)
end
function movement.Height(humanoid, gravity)
	local owner, attribute, power = movement.JumpBinding(humanoid)
	if not owner then return nil end
	if power then
		if gravity <= 0 then return nil end
		return (movement.Read(owner, "JumpPower", attribute) or 0) ^ 2 / (2 * gravity)
	end
	return movement.Read(owner, "JumpHeight", attribute) or 0
end
function movement.Visuals(dt, humanoid, root, gravity, status)
	local ui = movement.ui
	local living = movement.Living(humanoid, root)
	ui.hud.Visible = settings.MovementEnabled and settings.MovementShowHUD and not opened and living
	ui.sprintButton.Visible = settings.MovementEnabled and settings.MovementSpeed and settings.MovementSprint and not opened and UserInputService.TouchEnabled and living
	ui.sprintButton.Text = movement.IsSprinting() and "SPRINTING" or "SPRINT"
	if opened and currentPage == "Movement" and not settings.ReducedMotion then movement.time += math.max(0, dt) end
	local height = settings.MovementJumpHeight
	local axis = math.max(20, math.ceil(height / 10) * 10)
	local amplitude = 0.62 * height / axis
	local function arc(t) return Vector2.new(0.10 + t * 0.80, 0.84 - amplitude * 4 * t * (1 - t)) end
	local size, scale = ui.graph.AbsoluteSize, math.max(0.01, hostScale.Scale)
	local plotKey = string.format("%.2f:%.2f:%.1f:%.3f", size.X, size.Y, height, scale)
	if plotKey ~= movement.plotKey then
		movement.plotKey = plotKey
		for index, line in ui.arcLines do
			local a, b = arc((index - 1) / 24), arc(index / 24)
			local delta = Vector2.new((b.X - a.X) * size.X, (b.Y - a.Y) * size.Y)
			line.Position = UDim2.fromScale((a.X + b.X) / 2, (a.Y + b.Y) / 2)
			line.Size = UDim2.fromOffset(delta.Magnitude / scale, 2)
			line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
		end
	end
	local flight = gravity > 0 and 2 * math.sqrt(2 * height / gravity) or 0
	local phase = settings.ReducedMotion and 0.5 or math.min(1, (movement.time % math.max(0.9, flight + 0.4)) / math.max(0.01, flight))
	if height == 0 or gravity <= 0 then phase = 0 end
	local point = arc(phase)
	ui.arcBall.Position = UDim2.fromScale(point.X, point.Y)
	movement.uiTime = (movement.uiTime or 0) + math.max(0, dt)
	if movement.uiTime < 0.1 and dt ~= 0 then return end
	movement.uiTime = 0
	local actualHeight = movement.Height(humanoid, gravity)
	local speedOwner, speedProperty = movement.SpeedBinding(humanoid)
	local walk = speedOwner and speedOwner[speedProperty] or 0
	local velocity = root and root.AssemblyLinearVelocity
	local ground = velocity and math.sqrt(velocity.X ^ 2 + velocity.Z ^ 2) or 0
	ui.metrics[1].Text = living and speedOwner and string.format("%.1f", walk) or "--"
	ui.metrics[2].Text = actualHeight and string.format("%.1f", actualHeight) or "--"
	ui.metrics[3].Text = living and string.format("%.1f", ground) or "--"
	ui.apex.Text = string.format("APEX / %.1f u   AXIS / %d u", height, axis)
	ui.flight.Text = gravity > 0 and string.format("EST. AIR %.2fs / DIST %.1fu", flight, settings.MovementWalkSpeed * flight) or "ZERO GRAVITY / NO BALLISTIC ESTIMATE"
	ui.status.Text = status
	ui.status.TextColor3 = (status == "CUSTOM MOVEMENT ONLINE" or status == "SPRINT ACTIVE") and palette.Green or palette.Muted
	local jumpOwner, _, power = movement.JumpBinding(humanoid)
	ui.physics.Text = string.format("%s / GRAVITY %.1f / SPRINT: LEFTSHIFT OR L3", jumpOwner and (power and "POWER MODE: HEIGHT IS ESTIMATED" or "HEIGHT MODE") or "CUSTOM JUMP: ADAPTER REQUIRED", gravity)
	ui.controllerInfo.Text = movement.Diagnostics()
	ui.hudTitle.Text = movement.IsSprinting() and "KINETIC 3 / SPRINT" or (movement.manager and "KINETIC 3 / CONTROLLER" or "KINETIC 3 / WALK")
	ui.hudValues.Text = not speedOwner and not jumpOwner and "Controller adapter required" or string.format("%.1f u/s  /  %s u jump", walk, actualHeight and string.format("%.1f", actualHeight) or "--")
	tween(ui.hudFill, {Size = UDim2.fromScale(math.clamp(walk / math.max(1, settings.MovementWalkSpeed, settings.MovementSprintSpeed), 0, 1), 1)}, 0.12)
end
function movement.Apply(dt)
	if not alive then return end
	local character = localPlayer.Character
	if character == movement.removingCharacter then character = nil end
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local detected = movement.Detect(character, humanoid)
	local manager = detected.manager
	local legacy = humanoid and humanoid.EvaluateStateMachine ~= false
	if settings.MovementBackend == "Humanoid" then manager = nil
	elseif settings.MovementBackend == "Auto" and manager and not manager.ActiveController and legacy then manager = nil end
	local jumping = manager and detected.jumping or nil
	movement.Attach(humanoid, manager, jumping)
	local root = (manager and manager.RootPart) or (humanoid and humanoid.RootPart) or (character and character:FindFirstChild("HumanoidRootPart")) or (character and character.PrimaryPart)
	if root and not root:IsA("BasePart") then root = nil end
	movement.root = root
	local gravity = math.max(0, workspace.Gravity)
	local status = "PROFILE OFF / CAPTURED VALUES RELEASED"
	if not settings.MovementEnabled or not movement.Living(humanoid, root) then
		movement.Restore()
		movement.StopSprint()
		if settings.MovementEnabled then status = "WAITING FOR YOUR LIVING CHARACTER / CONTROLLER" end
		movement.Visuals(dt, humanoid, root, gravity, status)
		return
	end
	if manager and (not manager.RootPart or not manager.ActiveController) then
		movement.Restore()
		movement.StopSprint()
		movement.Visuals(dt, humanoid, root, gravity, "WAITING FOR CONTROLLER ROOT / ACTIVE CONTROLLER")
		return
	end
	if (opened or not aimWindowFocused or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox()) and (movement.sprintHeld or movement.sprintToggled) then movement.StopSprint() end
	local speedOwner, speedProperty = movement.SpeedBinding(humanoid)
	-- Explicit Controller mode must not silently fall back to Humanoid properties.
	if settings.MovementBackend == "Controller" and not manager then speedOwner, speedProperty = nil, nil end
	if settings.MovementSpeed and speedOwner then
		local otherSpeed = speedProperty == "WalkSpeed" and "BaseMoveSpeed" or "WalkSpeed"
		movement.Release(otherSpeed)
		local current = speedOwner[speedProperty]
		local entry = movement.owned[speedProperty]
		local rewritten = entry and math.abs(current - entry.last) >= 0.001
		if rewritten then movement.RecordRewrite(speedProperty, entry, current) end
		if movement.speedDirty then
			if rewritten and not settings.MovementMaintain then movement.owned[speedProperty] = nil end
			movement.targetSpeed = movement.IsSprinting() and math.max(settings.MovementWalkSpeed, settings.MovementSprintSpeed) or settings.MovementWalkSpeed
			movement.blendValue = movement.blendValue or current
			movement.Write(speedProperty, current, speedOwner)
			movement.speedDirty, movement.speedExternal, movement.ramping = false, false, true
		elseif rewritten and not settings.MovementMaintain then
			movement.speedExternal, movement.ramping = true, false
		end
		if movement.ramping then
			local alpha = settings.MovementSmoothTime <= 0 and 1 or (1 - math.exp(-math.max(0, dt) / settings.MovementSmoothTime))
			local previous = settings.MovementMaintain and movement.blendValue or current
			local value = previous + (movement.targetSpeed - previous) * alpha
			if math.abs(value - movement.targetSpeed) < 0.01 then value = movement.targetSpeed; movement.ramping = false end
			movement.blendValue = value
			movement.Write(speedProperty, value, speedOwner)
		elseif settings.MovementMaintain and math.abs(current - movement.targetSpeed) >= 0.001 then
			movement.Write(speedProperty, movement.targetSpeed, speedOwner)
		end
	else
		movement.Release("WalkSpeed"); movement.Release("BaseMoveSpeed")
		movement.ramping, movement.speedExternal, movement.blendValue = false, false, nil
	end
	local jumpOwner, attribute, power = movement.JumpBinding(humanoid)
	if power ~= movement.lastMode or gravity ~= movement.lastGravity then movement.jumpDirty = true end
	movement.lastMode, movement.lastGravity = power, gravity
	if settings.MovementJump and jumpOwner then
		local property = power and "JumpPower" or "JumpHeight"
		movement.Release(power and "JumpHeight" or "JumpPower")
		local current = movement.Read(jumpOwner, property, attribute)
		local entry = movement.owned[property]
		if entry and (entry.owner ~= jumpOwner or entry.attribute ~= attribute) then
			movement.Release(property)
			entry, movement.jumpDirty = nil, true
		end
		local rewritten = entry and math.abs(current - entry.last) >= 0.001
		if rewritten then movement.RecordRewrite(property, entry, current) end
		if movement.jumpDirty or (settings.MovementMaintain and rewritten) then
			if rewritten and not settings.MovementMaintain then movement.owned[property] = nil end
			if power and gravity <= 0 then movement.Release(property)
			else movement.Write(property, power and math.min(1000, math.sqrt(2 * gravity * settings.MovementJumpHeight)) or settings.MovementJumpHeight, jumpOwner, attribute) end
			movement.jumpDirty, movement.jumpExternal = false, false
		elseif rewritten then movement.jumpExternal = true end
	else
		movement.Release("JumpHeight"); movement.Release("JumpPower")
		movement.jumpExternal = false
	end
	status = movement.IsSprinting() and "SPRINT ACTIVE" or "CUSTOM MOVEMENT ONLINE"
	if not settings.MovementSpeed and not settings.MovementJump then status = "NO MOVEMENT OVERRIDES ENABLED"
	elseif settings.MovementSpeed and not speedOwner then status = "CUSTOM SPEED CONTROLLER: ADAPTER REQUIRED"
	elseif settings.MovementJump and not jumpOwner then status = "SPEED ACTIVE / CUSTOM JUMP ADAPTER REQUIRED"
	elseif gravity <= 0 and power and settings.MovementJump then status = "ZERO GRAVITY / JUMP HEIGHT UNAVAILABLE"
	elseif movement.speedExternal or movement.jumpExternal then status = "ANOTHER CONTROLLER CHANGED MOVEMENT" end
	if detected.ambiguous and settings.MovementBackend ~= "Humanoid" then status = "MULTIPLE CONTROLLERS: SELECT THE GAME'S MOVEMENT OWNER"
	elseif root and (root.Anchored or (root.AssemblyRootPart and root.AssemblyRootPart.Anchored)) then status = "ROOT ASSEMBLY IS ANCHORED: CHARACTER CANNOT MOVE"
	elseif humanoid and humanoid.Sit then status = "SEATED: VEHICLE HAS ITS OWN MOVEMENT"
	elseif not manager and humanoid and humanoid.PlatformStand then status = "PLATFORM STAND: CHARACTER CONTROLS PAUSED"
	elseif jumpOwner and not attribute and humanoid and settings.MovementJump and not humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping) then status = "JUMP STATE DISABLED BY CONTROLLER"
	elseif manager and manager.ActiveController.MoveSpeedFactor == 0 then status = "ACTIVE CONTROLLER HAS ZERO SPEED FACTOR" end
	movement.Visuals(dt, humanoid, root, gravity, status)
end
function movement.Update(dt, phase)
	if not alive then return end
	movement.lastPhase = phase or "Immediate UI change"
	local ok, problem = pcall(movement.Apply, dt)
	if not ok then
		movement.lastError = tostring(problem)
		movement.errorCount = (movement.errorCount or 0) + 1
		movement.ui.status.Text = "MOVEMENT ERROR / PRINT FULL MOVEMENT AUDIT"
		if os.clock() >= (movement.nextErrorLog or 0) then
			warn("[ESP Studio movement] " .. movement.lastError)
			movement.nextErrorLog = os.clock() + 5
		end
	end
end
function movement.Path(object)
	if not object then return "none" end
	local ok, path = pcall(function() return object:GetFullName() end)
	return ok and path or (object.ClassName .. ":" .. object.Name)
end
function movement.Snapshot()
	local humanoid, root, manager = movement.humanoid, movement.root, movement.manager
	local character = localPlayer.Character
	local speedOwner, speedProperty = movement.SpeedBinding(humanoid)
	local jumpOwner, attribute, power = movement.JumpBinding(humanoid)
	local jumpProperty = power and "JumpPower" or "JumpHeight"
	local direction = manager and manager.MovingDirection or (humanoid and humanoid.MoveDirection)
	local velocity = root and root.AssemblyLinearVelocity
	local assembly = root and root.AssemblyRootPart
	local active = manager and manager.ActiveController
	local detection = movement.detection or {}
	local issues, actuators = {}, {}
	local function issue(condition, description) if condition then table.insert(issues, description) end end
	issue(not settings.MovementEnabled, "Movement master switch is OFF")
	issue(not settings.MovementSpeed, "Speed override is OFF")
	issue(not settings.MovementJump, "Jump override is OFF")
	issue(not character or not character:IsDescendantOf(workspace), "Character absent or outside Workspace")
	issue(not root, "No supported root part found")
	issue(root and not root:IsDescendantOf(workspace), "Selected root is outside Workspace")
	issue(root and (root.Anchored or (assembly and assembly.Anchored)), "Root assembly is anchored; profile cannot cause motion")
	issue(not movement.Living(humanoid, root), "Character is dead or no live controller found")
	issue(detection.ambiguous and settings.MovementBackend ~= "Humanoid", "Multiple equally ranked ControllerManagers; automatic binding withheld")
	issue(settings.MovementSpeed and not speedOwner, "No supported speed binding; integrate the custom movement owner")
	issue(settings.MovementJump and not jumpOwner, "No supported jump binding; integrate the custom jump ability")
	issue(humanoid and humanoid.EvaluateStateMachine == false, "Humanoid state machine disabled; its movement properties may be inactive")
	issue(humanoid and humanoid.Sit, "Seated; vehicle/controller owns seated movement")
	issue(humanoid and humanoid.PlatformStand, "PlatformStand enabled")
	issue(humanoid and not humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping), "Humanoid Jumping state disabled")
	issue(manager and (not manager.RootPart or not active), "ControllerManager root or ActiveController missing")
	issue(active and active.MoveSpeedFactor == 0, "Active controller MoveSpeedFactor is zero")
	issue(settings.MovementEnabled and (not direction or direction.Magnitude < 0.001), "No movement intent at this instant; move with WASD/joystick while sampling")
	issue(workspace.Gravity <= 0, "Zero/negative gravity: standard ballistic jump conversion unavailable")
	issue(movement.speedExternal or movement.jumpExternal, "Observe mode yielded to a movement rewrite; enable Maintain or reapply")
	issue(opened, "Console open: sprint activation is paused; walk/jump profile still applies")
	issue(not aimWindowFocused, "Window unfocused: sprint paused")
	issue(GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() ~= nil, "Menu or text input active: sprint paused")
	if character then
		local actuatorClasses = {LinearVelocity = true, VectorForce = true, AlignPosition = true, BodyVelocity = true, BodyPosition = true, BodyForce = true}
		for _, object in character:GetDescendants() do
			if actuatorClasses[object.ClassName] and #actuators < 16 then table.insert(actuators, movement.Path(object)) end
		end
	end
	issue(#actuators > 0, "Force/position actuators present; presence alone does not prove a conflict")
	local post = {}
	for property, sample in movement.afterPhysics do
		post[property] = {applied = sample.applied, readback = sample.readback, matches = sample.matches}
		issue(not sample.matches, property .. " changed after profile application; a later script or replication may own it")
	end
	local owned = {}
	for property, entry in movement.owned do
		owned[property] = {owner = movement.Path(entry.owner), attribute = entry.attribute == true,
			applied = entry.last, current = movement.Read(entry.owner, property, entry.attribute), restore = entry.before}
	end
	return {
		build = "KINETIC 3 / fps-v3", applicationPhase = movement.lastPhase or "not run", status = movement.ui.status.Text,
		source = movement.Path(typeof(script) == "Instance" and script or nil), character = movement.Path(character), root = movement.Path(root),
		settings = {enabled = settings.MovementEnabled, maintain = settings.MovementMaintain, speed = settings.MovementSpeed,
			jump = settings.MovementJump, sprint = settings.MovementSprint, backend = settings.MovementBackend,
			walk = settings.MovementWalkSpeed, sprintSpeed = settings.MovementSprintSpeed, jumpHeight = settings.MovementJumpHeight,
			blendSeconds = settings.MovementSmoothTime, sprintActive = movement.IsSprinting(), targetSpeed = movement.targetSpeed},
		binding = {speedOwner = movement.Path(speedOwner), speedProperty = speedProperty or "unsupported",
			speedNow = speedOwner and speedOwner[speedProperty] or "unavailable", jumpOwner = movement.Path(jumpOwner),
			jumpProperty = jumpOwner and jumpProperty or "unsupported", jumpIsAttribute = attribute == true,
			jumpNow = jumpOwner and movement.Read(jumpOwner, jumpProperty, attribute) or "unavailable",
			managersFound = detection.managerCount or 0, ambiguousManagers = detection.ambiguous == true,
			activeController = movement.Path(active), speedFactor = active and active.MoveSpeedFactor or "unavailable",
			upDirection = manager and tostring(manager.UpDirection) or "Humanoid/world gravity"},
		physical = {gravity = workspace.Gravity, rootAnchored = root and root.Anchored == true or false,
			assemblyRoot = movement.Path(assembly), assemblyAnchored = assembly and assembly.Anchored == true or false,
			state = humanoid and tostring(humanoid:GetState()) or "no Humanoid", seat = movement.Path(humanoid and humanoid.SeatPart),
			inputMagnitude = direction and direction.Magnitude or 0, horizontalSpeed = velocity and math.sqrt(velocity.X ^ 2 + velocity.Z ^ 2) or 0,
			verticalSpeed = velocity and velocity.Y or 0, windowFocused = aimWindowFocused, consoleOpen = opened,
			position = root and tostring(root.Position) or "no root", rig = humanoid and tostring(humanoid.RigType) or "no Humanoid",
			evaluateStateMachine = humanoid and humanoid.EvaluateStateMachine ~= false or false,
			jumpIntent = humanoid and humanoid.Jump == true or false,
			networkAuthority = "Unknown on client; inspect ownership/validation in the game's server controller"},
		ownedProperties = owned, afterPhysics = post, rewriteCounts = table.clone(movement.rewriteCounts),
		lastRewrite = movement.lastRewrite or "none", lastError = movement.lastError or "none", errorCount = movement.errorCount or 0,
		observedIssues = issues, actuatorCandidates = actuators,
		limits = "Matching properties do not prove locomotion. Custom CFrame/velocity controllers, collisions, custom gravity, and server authority require target-place inspection.",
	}
end
function movement.PrintAudit(samples)
	local ok, report = pcall(movement.Snapshot)
	if not ok then warn("[ESP Studio audit failed] " .. tostring(report)); return end
	if samples then report.oneSecondSamples = samples end
	local lines = {"[ESP Studio movement audit / KINETIC 3]"}
	local function flatten(value, path)
		if type(value) ~= "table" then table.insert(lines, path .. " = " .. tostring(value)); return end
		local keys = {}
		for key in value do table.insert(keys, key) end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		for _, key in keys do flatten(value[key], path == "" and tostring(key) or (path .. "." .. tostring(key))) end
	end
	flatten(report, "")
	print(table.concat(lines, "\n"))
end
function movement.Observe()
	if not alive then return end
	local readbacks = {}
	for property, entry in movement.owned do
		local value = movement.Read(entry.owner, property, entry.attribute)
		local matches = movement.Finite(value) and math.abs(value - entry.last) < 0.001
		readbacks[property] = {applied = entry.last, readback = value == nil and "nil" or value, matches = matches}
		if not matches then movement.RecordRewrite(property, entry, value) end
	end
	movement.afterPhysics = readbacks
	local capture, now = movement.capture, os.clock()
	if not capture then return end
	if now >= capture.nextSample and #capture.samples < 16 then
		local humanoid, root, manager = movement.humanoid, movement.root, movement.manager
		local direction = manager and manager.MovingDirection or (humanoid and humanoid.MoveDirection)
		local velocity = root and root.AssemblyLinearVelocity
		table.insert(capture.samples, {time = now, input = direction and direction.Magnitude or 0,
			velocity = velocity and tostring(velocity) or "no root", position = root and tostring(root.Position) or "no root",
			state = humanoid and tostring(humanoid:GetState()) or "no Humanoid", properties = readbacks})
		capture.nextSample = now + 0.1
	end
	if now >= capture.deadline then
		movement.capture = nil
		movement.PrintAudit(capture.samples)
		notify("Movement audit printed; copy the full KINETIC 3 report")
	end
end
connect(localPlayer.CharacterRemoving, function(character)
	movement.removingCharacter = character
	movement.Attach(nil)
	movement.StopSprint()
end)
connect(localPlayer.CharacterAdded, function()
	movement.removingCharacter = nil
	movement.Attach(nil)
	movement.StopSprint()
	if not settings.MovementKeepOnRespawn then settings.MovementEnabled = false; refreshAll() end
	movement.MarkDirty()
end)
connect(RunService.PreSimulation, function(dt) movement.Update(dt, "PreSimulation") end)
connect(RunService.Heartbeat, function() movement.Observe() end)

local cameraConnection
local function watchCamera()
	if cameraConnection then cameraConnection:Disconnect(); cameraConnection = nil end
	if workspace.CurrentCamera then
		cameraConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function() updateLayout() end)
		updateLayout()
	end
end
connect(workspace:GetPropertyChangedSignal("CurrentCamera"), watchCamera)
connect(GuiService:GetPropertyChangedSignal("TopbarInset"), function() updateLayout() end)
connect(Players.PlayerAdded, hookPlayer)
connect(Players.PlayerRemoving, removePlayer)
for _, player in Players:GetPlayers() do hookPlayer(player) end

local lastText, lastStats, frameTime, clockTime = 0, 0, 1 / 60, 0
connect(RunService.RenderStepped, function(dt)
	local camera = workspace.CurrentCamera
	if not camera then
		for _, data in records do hideRecord(data) end
		return
	end
	local now = os.clock()
	clockTime += dt
	frameTime += (math.min(dt, 0.25) - frameTime) * math.min(1, dt * 5)
	local updateText = now - lastText >= 0.1
	if updateText then lastText = now end
	local localRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
	local originPosition = localRoot and localRoot.Position or camera.CFrame.Position
	local viewport = camera.ViewportSize
	local _, bottomInset = GuiService:GetGuiInset()
	local tracerOrigin = Vector2.new(viewport.X / 2, viewport.Y - bottomInset.Y - 18)
	if settings.TracerOrigin == "Center" then tracerOrigin = viewport / 2
	elseif settings.TracerOrigin == "Cursor" then tracerOrigin = UserInputService:GetMouseLocation() end
	local onScreenCount, playerCount = 0, 0
	for player, data in records do
		playerCount += 1
		local character = data.character
		if not character or not character:IsDescendantOf(workspace) then hideRecord(data); continue end
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not rootPart or not humanoid then hideRecord(data); continue end
		if data.rootPart ~= rootPart then data.rootPart = rootPart; data.boundsOffset = nil end
		data.humanoid = humanoid
		local distance = (rootPart.Position - originPosition).Magnitude
		local visible = settings.Enabled and distance <= settings.MaxDistance and not (settings.TeamCheck and friendly(player)) and not (settings.HideDead and humanoid.Health <= 0)
		if not visible then hideRecord(data); continue end
		local color = targetColor(player)
		if settings.ShowHighlights then
			if not data.highlight then data.highlight = make("Highlight", {Name = player.Name, Adornee = character}, world) end
			data.highlight.Enabled = true
			data.highlight.FillColor, data.highlight.OutlineColor = color, color
			data.highlight.FillTransparency = settings.HighlightFillTransparency
			data.highlight.OutlineTransparency = settings.HighlightOutlineTransparency
			data.highlight.DepthMode = settings.ThroughWalls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
		elseif data.highlight then data.highlight.Enabled = false end
		local projected, onScreen = camera:WorldToViewportPoint(rootPart.Position)
		if not onScreen or projected.Z <= 0 then
			data.marker.Visible, data.tracer.Visible = false, false
			continue
		end
		onScreenCount += 1
		local topLeft, size = screenBounds(camera, data, now)
		data.marker.Visible = topLeft ~= nil and (settings.ShowBoxes or settings.ShowNames or settings.ShowHealth or settings.ShowDistance)
		if topLeft then
			data.marker.Position = UDim2.fromOffset(topLeft.X, topLeft.Y)
			data.marker.Size = UDim2.fromOffset(size.X, size.Y)
			data.box.Visible = settings.ShowBoxes
			local length = math.clamp(size.X * 0.2, 6, 19)
			for index, corner in data.corners do
				local vertical = cornerDefinitions[index][3]
				corner.Size = UDim2.fromOffset(vertical and 2 or length, vertical and length or 2)
				corner.BackgroundColor3 = color
			end
			data.tag.Visible = settings.ShowNames or settings.ShowHealth or settings.ShowDistance
			data.tagScale.Scale = settings.MarkerScale
			-- Keep plates inside the horizontal and top edges of the viewport.
			local tagX = math.clamp(topLeft.X + size.X / 2, 87 * settings.MarkerScale + 6, math.max(87 * settings.MarkerScale + 6, viewport.X - 87 * settings.MarkerScale - 6))
			data.tag.Position = UDim2.fromOffset(tagX - topLeft.X, math.max(-9, 54 * settings.MarkerScale - topLeft.Y))
			data.tagAccent.BackgroundColor3 = color
			data.name.Visible = settings.ShowNames
			data.meta.Position = UDim2.fromOffset(10, settings.ShowNames and 24 or 8)
			local plateHeight = settings.ShowNames and (settings.ShowHealth or settings.ShowDistance) and 48 or 32
			data.tag.Size = UDim2.fromOffset(174, plateHeight)
			local ratio = math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1)
			data.healthRatio += (ratio - data.healthRatio) * (settings.ReducedMotion and 1 or (1 - math.exp(-12 * dt)))
			data.healthTrack.Visible = settings.ShowHealth
			data.healthFill.Size = UDim2.fromScale(data.healthRatio, 1)
			data.healthFill.BackgroundColor3 = Color3.fromRGB(255, 99, 123):Lerp(palette.Green, ratio)
			if updateText then
				data.name.Text = player.DisplayName
				local parts = {}
				if settings.ShowHealth then table.insert(parts, string.format("%d HP", math.max(0, math.floor(humanoid.Health)))) end
				if settings.ShowDistance then table.insert(parts, string.format("%d studs", math.floor(distance))) end
				data.meta.Text = table.concat(parts, " / ")
			end
		end
		data.tracer.Visible = settings.ShowTracers
		if settings.ShowTracers then
			local target = Vector2.new(projected.X, projected.Y)
			placeLine(data.line, tracerOrigin, target, settings.TracerWidth)
			placeLine(data.glow, tracerOrigin, target, settings.TracerWidth + 4)
			data.line.BackgroundColor3, data.glow.BackgroundColor3, data.endpoint.BackgroundColor3 = color, color, color
			data.line.BackgroundTransparency = 1 - settings.TracerOpacity
			data.glow.BackgroundTransparency = 1 - settings.TracerOpacity * 0.09
			data.endpoint.BackgroundTransparency = 1 - settings.TracerOpacity
			data.endpoint.Position = UDim2.fromOffset(target.X, target.Y)
			local pulse = settings.PulseTracers and not settings.ReducedMotion and math.sin(clockTime * 3.2 + player.UserId % 7) or 0
			data.endpoint.Size = UDim2.fromOffset(5 + pulse, 5 + pulse)
		end
	end
	if now - lastStats >= 0.4 then
		lastStats = now
		metricLabels[1].Text = string.format("%02d", onScreenCount)
		metricLabels[2].Text = string.format("%02d", playerCount)
		fpsText.Text = string.format("%d FPS / LOCAL", math.floor(1 / math.max(frameTime, 0.001) + 0.5))
		statusText.Text = string.format("%s  /  %d ON SCREEN  /  %d PLAYERS", settings.Enabled and "ONLINE" or "PAUSED", onScreenCount, playerCount)
	end
	if opened and settings.UIEffects and not settings.ReducedMotion then
		skin.animationTime += dt * settings.UIMotionSpeed
		local phase = skin.animationTime
		accentGradient.Offset = Vector2.new(math.sin(phase * 0.35) * 0.35, 0)
		sessionDot.BackgroundTransparency = 0.1 + (math.sin(phase * 2) + 1) * 0.15
		if currentPage == "Overview" then
			skin.radarDot.Position = UDim2.new(0.5, math.cos(phase * 1.4) * 52, 0.5, math.sin(phase * 1.4) * 52)
		end
	else
		accentGradient.Offset = Vector2.new()
		sessionDot.BackgroundTransparency = 0
		skin.radarDot.Position = UDim2.new(0.5, 52, 0.5, 0)
	end
end)

-- Explicit teardown also handles replacing/rerunning this LocalScript.
local function cleanup()
	if not alive then return end
	persistence.Flush()
	persistence.closed = true
	alive = false
	activePointer = nil
	releaseAim()
	movement.StopSprint()
	movement.Restore()
	if aimBound then RunService:UnbindFromRenderStep(aimRenderName); aimBound = false end
	for _, connection in connections do connection:Disconnect() end
	if cameraConnection then cameraConnection:Disconnect() end
	for _, animation in activeTweens do animation:Cancel() end
	local players = {}
	for player in records do table.insert(players, player) end
	for _, player in players do removePlayer(player) end
	world:Destroy()
end
screen.Destroying:Connect(cleanup)
-- The ScreenGui owns cleanup. A real script Instance can also trigger teardown;
-- an absent/non-Instance script context must not interrupt UI initialization.
if typeof(script) == "Instance" then
	connect(script.Destroying, function()
		cleanup()
		if screen.Parent then screen:Destroy() end
	end)
end

refreshAll()
selectPage("Overview")
watchCamera()
movement.Update(0)
window.Position = UDim2.fromOffset(0, 12)
setOpen(true)
RunService:BindToRenderStep(aimRenderName, Enum.RenderPriority.Camera.Value + 1, updateAim)
aimBound = true
