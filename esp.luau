-- ESP STUDIO / Observatory edition
-- Standalone LocalScript: StarterPlayer > StarterPlayerScripts.
-- RightShift or the floating launcher opens the console. Settings are session-only.

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
	UIScale = 1, Theme = "Glacier",
	AimEnabled = false, AimTeamCheck = true, AimVisibilityCheck = true, AimShowRadius = true,
	AimRadius = 140, AimRange = 800, AimSmoothTime = 0.12, AimPart = "Head", AimKey = "RMB",
	EnemyColor = Color3.fromRGB(255, 109, 139),
	FriendlyColor = Color3.fromRGB(100, 218, 255),
}
local settings = table.clone(defaults)
local palette = {
	Background = Color3.fromRGB(12, 15, 21), Sidebar = Color3.fromRGB(9, 12, 17),
	Card = Color3.fromRGB(19, 24, 33), Raised = Color3.fromRGB(26, 33, 45),
	Line = Color3.fromRGB(43, 52, 67), Text = Color3.fromRGB(231, 237, 248),
	Muted = Color3.fromRGB(135, 150, 174), Dim = Color3.fromRGB(85, 101, 126),
	Green = Color3.fromRGB(100, 228, 170),
}
local themes = {
	Glacier = Color3.fromRGB(114, 193, 255), Violet = Color3.fromRGB(177, 150, 255),
	Mint = Color3.fromRGB(103, 230, 186), Ember = Color3.fromRGB(255, 173, 117),
}
local accent = themes[settings.Theme]
local alive = true
local connections, controls, accentBindings, columns, navigation = {}, {}, {}, {}, {}
local activeTweens = setmetatable({}, {__mode = "k"})
local layoutOrders = setmetatable({}, {__mode = "k"})
local refreshAll, updateLayout, updatePreview, selectPage, setOpen

local function make(className, properties, parent)
	local object = Instance.new(className)
	for property, value in properties do object[property] = value end
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
		TweenInfo.new(settings.ReducedMotion and 0 or (duration or 0.18),
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
		task.delay(0.4, function() ripple:Destroy() end)
	end)
	return object
end

-- A second copy replaces only this overlay and lets its old connections clean up.
local previous = playerGui:FindFirstChild("DeveloperESPPanel")
if previous then previous:Destroy() end
local screen = make("ScreenGui", {
	Name = "DeveloperESPPanel", ResetOnSpawn = false, IgnoreGuiInset = true,
	DisplayOrder = 50, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)
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
shadow.BackgroundTransparency = 0.45
local window = round(make("CanvasGroup", {
	Name = "Console", Size = UDim2.fromScale(1, 1), BackgroundColor3 = palette.Background,
	BorderSizePixel = 0, GroupTransparency = 1,
}, host), 12)
stroke(window, palette.Line, 0.05)
local accentBar = bindAccent(frame(window, "Accent", UDim2.new(), UDim2.new(1, 0, 0, 2), accent), "BackgroundColor3")
local accentGradient = make("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(85, 108, 155)),
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(85, 108, 155)),
	}),
}, accentBar)

local titlebar = frame(window, "Titlebar", UDim2.fromOffset(0, 2), UDim2.new(1, 0, 0, 48), palette.Sidebar)
local dragHandle = make("TextButton", {
	Name = "DragHandle", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
	Size = UDim2.new(1, -132, 1, 0),
}, titlebar)
bindAccent(label(dragHandle, "[ / ]", UDim2.fromOffset(18, 0), UDim2.fromOffset(42, 48), 17, accent, Enum.Font.Code), "TextColor3")
label(dragHandle, "ESP STUDIO", UDim2.fromOffset(67, 0), UDim2.fromOffset(145, 48), 14, nil, Enum.Font.GothamBold)
local edition = label(dragHandle, "/ OBSERVATORY", UDim2.fromOffset(213, 0), UDim2.fromOffset(160, 48), 11, palette.Dim, Enum.Font.Code)
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
local navContainer = frame(sidebar, "Sections", UDim2.fromOffset(10, 133), UDim2.new(1, -20, 0, 286))
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
		task.delay(0.22, function()
			if alive and revision == toastRevision then toast.Visible = false end
		end)
	end)
end

local pageDefinitions = {
	{"Overview", "01", "Session overview", "Your session, at a glance.", "home dashboard presets preview"},
	{"Visuals", "02", "Player visuals", "Readable markers. Precise control.", "names health distance boxes highlights overlay"},
	{"Tracers", "03", "Tracer renderer", "A clean line to every visible target.", "lines origin opacity width pulse"},
	{"Aim", "04", "Camera aim assist", "Hold to follow a target near your crosshair.", "aimbot aiming aim assist target camera smoothing fov"},
	{"Filters", "05", "Display filters", "Choose who appears in the overlay.", "range team dead color walls"},
	{"Appearance", "06", "Make it yours", "Tune the palette, scale, and motion.", "theme colors animations reset settings"},
}
local pages, currentPage = {}, "Overview"
for index, definition in pageDefinitions do
	local name = definition[1]
	local nav = button(navContainer, "", UDim2.new(), UDim2.new(1, 0, 0, 42))
	nav.Name = name
	nav.LayoutOrder = index
	nav.BackgroundTransparency = 1
	local navLine = round(frame(nav, "Active", UDim2.fromOffset(0, 10), UDim2.fromOffset(3, 22), accent), 2)
	local number = label(nav, definition[2], UDim2.fromOffset(12, 0), UDim2.fromOffset(27, 42), 10, palette.Dim, Enum.Font.Code)
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
local function setSetting(key, value)
	settings[key] = value
	if key == "AimEnabled" or key == "AimKey" then releaseAim(true) end
	refreshAll()
	if key == "UIScale" then updateLayout() end
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
local function addSlider(parent, title, key, minimum, maximum, step, formatter, y)
	label(parent, title, UDim2.fromOffset(16, y), UDim2.new(1, -120, 0, 24), 12)
	local valueLabel = label(parent, "", UDim2.new(1, -112, 0, y), UDim2.fromOffset(96, 24), 11, accent, Enum.Font.Code)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
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
	local function move(x, left, width)
		local ratio = math.clamp((x - left) / math.max(1, width), 0, 1)
		local value = minimum + math.floor((ratio * (maximum - minimum)) / step + 0.5) * step
		setSetting(key, math.clamp(value, minimum, maximum))
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
	table.insert(controls, function()
		local ratio = (settings[key] - minimum) / (maximum - minimum)
		fill.Size = UDim2.fromScale(ratio, 1)
		knob.Position = UDim2.new(ratio, 0, 0.5, 0)
		valueLabel.Text = formatter(settings[key])
	end)
end
local function addChoices(parent, title, key, options, y)
	label(parent, title, UDim2.fromOffset(16, y), UDim2.new(1, -32, 0, 22), 12)
	for index, option in options do
		local choice = button(parent, option, UDim2.new((index - 1) / #options, 16, 0, y + 30), UDim2.new(1 / #options, -22, 0, 33))
		choice.Activated:Connect(function() setSetting(key, option) end)
		table.insert(controls, function()
			choice.BackgroundColor3 = settings[key] == option and accent:Lerp(palette.Card, 0.8) or palette.Raised
			choice.TextColor3 = settings[key] == option and accent or palette.Muted
		end)
	end
end
local function percent(value) return string.format("%d%%", math.floor(value * 100 + 0.5)) end

-- Overview: real counters, a clearly labeled preview, and useful presets.
local hero = section(pages.Overview, "Everything in focus.", "A live workspace for your player overlay.", 102)
bindAccent(frame(hero, "Edge", UDim2.fromOffset(0, 15), UDim2.fromOffset(3, 72), accent), "BackgroundColor3")
local heroStatus = label(hero, "OVERLAY ONLINE", UDim2.fromOffset(16, 69), UDim2.new(1, -32, 0, 20), 10, palette.Green, Enum.Font.Code)
local metrics = frame(pages.Overview, "Metrics", UDim2.new(), UDim2.new(1, 0, 0, 76))
local metricLabels = {}
for index, text in {"ON SCREEN", "OTHER PLAYERS", "MAX RANGE"} do
	local card = round(frame(metrics, text, UDim2.new((index - 1) / 3, 0, 0, 0), UDim2.new(1 / 3, -10, 1, 0), palette.Card), 8)
	stroke(card, palette.Line, 0.4)
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
addSlider(aimTuning, "Smoothing time", "AimSmoothTime", 0.05, 0.5, 0.01,
	function(value) return string.format("%d ms", math.floor(value * 1000 + 0.5)) end, 149)
addSlider(aimTuning, "Aim radius", "AimRadius", 40, 300, 5,
	function(value) return string.format("%d px", value) end, 226)
addSlider(aimTuning, "Maximum range", "AimRange", 100, 2000, 50,
	function(value) return string.format("%d studs", value) end, 303)
label(aimTuning, "Lower smoothing time follows faster.", UDim2.fromOffset(16, 378), UDim2.new(1, -32, 0, 18), 10, palette.Dim)
local aimDiagnostics = section(pages.Aim, "Last aim status", "The live readout explains why a target is not acquired.", 110)
aimStateLabel = label(aimDiagnostics, lastAimStatus, UDim2.fromOffset(16, 69), UDim2.new(1, -32, 0, 24), 11, palette.Muted, Enum.Font.Code)

local filterCard = section(pages.Filters, "Visibility rules", "Filters apply to markers, highlights, and tracers together.", 265)
addToggle(filterCard, "Team filter", "Hide players who share your non-neutral team", "TeamCheck", 65)
addToggle(filterCard, "Hide eliminated players", "Only show living characters", "HideDead", 121)
addToggle(filterCard, "Use Roblox team colors", "Use each player's team color when available", "UseTeamColors", 177)
local rangeCard = section(pages.Filters, "Render range", "Your character is the origin; the camera is used while respawning.", 150)
addSlider(rangeCard, "Maximum distance", "MaxDistance", 100, 5000, 50, function(value) return string.format("%d studs", value) end, 74)

local themeCard = section(pages.Appearance, "Accent palette", "One accent, carried through the entire workspace.", 140)
addChoices(themeCard, "Color theme", "Theme", {"Glacier", "Violet", "Mint", "Ember"}, 65)
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
local motion = section(pages.Appearance, "Workspace feel", "Scale the console and control animation intensity.", 218)
addToggle(motion, "Reduced motion", "Instant UI transitions and static endpoints", "ReducedMotion", 65)
addSlider(motion, "Interface scale", "UIScale", 0.75, 1.15, 0.05, percent, 136)
local resetCard = section(pages.Appearance, "Fresh start", "Restore all session settings to their defaults.", 118)
local reset = button(resetCard, "Reset settings", UDim2.fromOffset(16, 70), UDim2.new(1, -32, 0, 32))
reset.Activated:Connect(function()
	settings = table.clone(defaults)
	releaseAim(true)
	refreshAll()
	updateLayout()
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
	heroStatus.Text = enabled and "OVERLAY ONLINE  /  CHANGES APPLY LIVE" or "OVERLAY PAUSED  /  CONTROLS STILL AVAILABLE"
	heroStatus.TextColor3 = enabled and palette.Green or palette.Muted
	metricLabels[3].Text = string.format("%d", settings.MaxDistance)
end
refreshAll = function()
	accent = themes[settings.Theme] or themes.Glacier
	for _, binding in accentBindings do binding[1][binding[2]] = accent end
	for _, refresh in controls do refresh() end
	refreshNavigation()
	updatePreview()
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
	sidebar.Visible = not compact
	edition.Visible = not compact
	local offset = compact and 0 or 196
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
	if input == aimHeldInput or ((aimHeldInput or aimMousePolled) and isAimInput(input)) then releaseAim() end
	if activePointer and (input == activePointer.input or (input.UserInputType == Enum.UserInputType.MouseButton1 and activePointer.input.UserInputType == Enum.UserInputType.MouseButton1)) then
		activePointer = nil
	end
end)
connect(UserInputService.WindowFocusReleased, function()
	activePointer = nil
	aimWindowFocused = false
	releaseAim(true)
end)
connect(UserInputService.WindowFocused, function() aimWindowFocused = true end)

local opened, openRevision = true, 0
setOpen = function(value)
	opened = value
	openRevision += 1
	local revision = openRevision
	activePointer = nil
	releaseAim(true)
	aimButton.Visible = settings.AimEnabled and UserInputService.TouchEnabled and not value
	if value then aimCircle.Visible = false; aimStatusPanel.Visible = false end
	if value then
		host.Visible = true
		tween(window, {GroupTransparency = 0, Position = UDim2.new()}, 0.3)
		tween(shadow, {BackgroundTransparency = 0.45}, 0.3)
	else
		tween(window, {GroupTransparency = 1, Position = UDim2.fromOffset(0, 12)}, 0.19)
		tween(shadow, {BackgroundTransparency = 1}, 0.19)
		if search:IsFocused() then search:ReleaseFocus() end
		task.delay(settings.ReducedMotion and 0 or 0.2, function()
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
	local bestPart, bestScore, bestUserId = nil, settings.AimRadius ^ 2, math.huge
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
		if score > settings.AimRadius ^ 2 then continue end
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
	aimCircle.Size = UDim2.fromOffset(settings.AimRadius * 2, settings.AimRadius * 2)
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
	local alpha = 1 - math.exp(-math.max(0, dt) / math.max(0.01, settings.AimSmoothTime))
	camera.CFrame = camera.CFrame:Lerp(goal, alpha)
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
	if opened and not settings.ReducedMotion then
		accentGradient.Offset = Vector2.new(math.sin(clockTime * 0.35) * 0.35, 0)
		sessionDot.BackgroundTransparency = 0.1 + (math.sin(clockTime * 2) + 1) * 0.15
	else
		accentGradient.Offset = Vector2.new()
		sessionDot.BackgroundTransparency = 0
	end
end)

-- Explicit teardown also handles replacing/rerunning this LocalScript.
local function cleanup()
	if not alive then return end
	alive = false
	activePointer = nil
	releaseAim()
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
window.Position = UDim2.fromOffset(0, 12)
setOpen(true)
RunService:BindToRenderStep(aimRenderName, Enum.RenderPriority.Camera.Value + 1, updateAim)
aimBound = true
