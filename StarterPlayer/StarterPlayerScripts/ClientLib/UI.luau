--!strict
-- Small UI toolkit: theme, instance builder, chunky buttons, panels, responsive scale.
-- Style: colorful, clean, chunky and tactile. Everything is built in code so layout
-- stays consistent and scales with UIScale for phones.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Sound = require(script.Parent.Sound)

local UI = {}

-- STYLE TOKENS (PRESENTATION_BIBLE.md §2–§7). The ONE source for player-facing colours, type, spacing and frames.
-- UI.Theme and Menu.S are kept as aliases onto these values so older code picks up the same palette.
local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

UI.Tokens = {
	-- surfaces (Pass 21A: brighter slate-blue "simulator" plates instead of near-black dashboard grey)
	Plate = rgb(42, 52, 70), -- main panel surface
	PlateRaised = rgb(60, 73, 96), -- rows, cards inside panels, resting buttons
	PlateDeep = rgb(27, 33, 46), -- headers, wells, bar troughs
	Frame = rgb(13, 16, 24), -- every border
	Rule = rgb(86, 100, 124), -- 1 px dividers
	-- ink
	Ink = rgb(244, 246, 250),
	InkDim = rgb(182, 192, 210),
	InkFaint = rgb(124, 134, 154),
	-- the ONE accent: active tab, primary button, project progress, Most Needed, open-menu edge
	Amber = rgb(255, 194, 38),
	AmberInk = rgb(36, 26, 4),
	Signal = rgb(240, 132, 40), -- warnings, FULL cargo
	Good = rgb(84, 200, 92), -- done / gained / affordable (never decorative)
	Bad = rgb(210, 82, 72), -- damage, errors
	Power = rgb(96, 196, 232), -- Power family + high-tech states only
	Dev = rgb(120, 132, 150), -- developer tools (never a rarity colour)
}
local K = UI.Tokens

-- Typography (design sizes; the UIScale floor is 0.72, so the smallest of these renders at >= 10 px)
UI.Type = {
	Display = 56,
	Title = 22,
	Heading = 17,
	Body = 15,
	Label = 14,
	Heavy = Enum.Font.BuilderSansExtraBold,
	Bold = Enum.Font.BuilderSansBold,
	Regular = Enum.Font.BuilderSans,
}
UI.Space = { Pad = 12, Gap = 8, Group = 16, Margin = 12, Radius = 12 }

-- Resource family colours (UI only; world piles keep their own materials). Grades inside a family get lighter, never
-- a different hue, so Power is cyan everywhere in the UI and Metal Beams no longer borrow the accent amber.
UI.Family = {
	Wood = rgb(168, 112, 64),
	Stone = rgb(150, 146, 138),
	Metal = rgb(140, 150, 162),
	Power = K.Power,
	PowerCell = K.Power,
	Secret = rgb(196, 176, 236),
}

-- Legacy theme keys, now mapped onto the tokens
UI.Theme = {
	Panel = K.Plate,
	PanelLight = K.PlateRaised,
	Stroke = K.Frame,
	Text = K.Ink,
	SubText = K.InkDim,
	Accent = K.Amber,
	Good = K.Good,
	Bad = K.Bad,
	Warn = K.Signal,
	Blue = K.Power,
	Blueprint = rgb(24, 46, 78),
	Title = UI.Type.Heavy,
	Body = UI.Type.Regular,
	Bold = UI.Type.Bold,
}
local T = UI.Theme

-- UI colour for one resource id: its family colour, lightened by grade (1 = base, 3 = lightest)
function UI.resourceColor(id: string): Color3
	local ok, ResourceConfig = pcall(function()
		return require(game:GetService("ReplicatedStorage").Shared.Config.ResourceConfig) :: any
	end)
	local res = ok and ResourceConfig.Resources[id]
	if not res then
		return K.InkDim
	end
	if res.Secret then
		return UI.Family.Secret
	end
	local base = UI.Family[res.FamilyName or ""] or UI.Family[res.Family or ""] or K.InkDim
	return base:Lerp(Color3.new(1, 1, 1), ((res.Grade or 1) - 1) * 0.14)
end

-- Pictogram name for a resource family (Site.icon): what to gather reads from the icon before the word
local FAMILY_ICON = { Wood = "log", Stone = "rock", Metal = "ingot", Power = "bolt", PowerCell = "bolt", Secret = "gem" }
function UI.resourceIcon(id: string): string
	local ok, ResourceConfig = pcall(function()
		return require(game:GetService("ReplicatedStorage").Shared.Config.ResourceConfig) :: any
	end)
	local res = ok and ResourceConfig.Resources[id]
	if not res then
		return "crate"
	end
	if res.Secret then
		return "gem"
	end
	return FAMILY_ICON[res.FamilyName or ""] or FAMILY_ICON[res.Family or ""] or "crate"
end

-- RARITY TREATMENT (Bible §3): one layout, frame weight grows with the tier.
--   1 Common: border only · 2 Uncommon: + left accent bar · 3 Rare: + inner accent line · 4 Epic: + corner brackets
--   5 Legendary / 6 Mythic: + full accent frame (Mythic adds one slow light sweep)
local RARITY_LEVEL = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Forgotten = 6, Hidden = 6 }
function UI.rarityLevel(name: string?): number
	return RARITY_LEVEL[name or ""] or 1
end

-- small plate: tier pips + NAME (never colour-only)
function UI.rarityPlate(parent: Instance, name: string, color: Color3, textSize: number?, order: number?): Frame
	local ts = textSize or UI.Type.Label
	local lum = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
	local ink = if lum > 0.55 then K.AmberInk else K.Ink
	local f = UI.new("Frame", {
		Name = "RarityPlate",
		BackgroundColor3 = color,
		BackgroundTransparency = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, ts + 10),
		LayoutOrder = order or 0,
		Parent = parent,
	})
	UI.corner(f, math.floor((ts + 10) / 2))
	UI.new("UIStroke", { Color = K.Frame, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = f })
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 10), Parent = f })
	local l = UI.list(f, 5, true)
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	local pips = UI.new("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, ts), LayoutOrder = 1, Parent = f })
	UI.list(pips, 2, true).VerticalAlignment = Enum.VerticalAlignment.Center
	local tier = UI.rarityLevel(name:sub(1, 1) .. name:sub(2):lower())
	for i = 1, 6 do
		UI.new("Frame", {
			BackgroundColor3 = ink,
			BackgroundTransparency = if i <= tier then 0 else 0.75,
			Size = UDim2.fromOffset(4, math.floor(ts * 0.6)),
			LayoutOrder = i,
			Parent = pips,
		})
	end
	UI.new("TextLabel", {
		Text = string.upper(name),
		Font = UI.Type.Heavy,
		TextSize = ts,
		TextColor3 = ink,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, ts + 4),
		LayoutOrder = 2,
		Parent = f,
	})
	return f
end

-- Apply (or re-apply) the rarity frame treatment to a plate. Decorations live in a "RarityFrame" folder-frame so they can be
-- rebuilt when the rarity changes. Returns the decoration frame.
function UI.rarityFrame(plate: GuiObject, rarityName: string?, color: Color3?)
	local old = plate:FindFirstChild("RarityFrame")
	if old then
		old:Destroy()
	end
	local level = UI.rarityLevel(rarityName)
	local c = color or K.InkDim
	local deco = UI.new("Frame", { Name = "RarityFrame", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = plate })
	if level >= 2 then
		UI.new("Frame", { Name = "Bar", BackgroundColor3 = c, BackgroundTransparency = 0, Size = UDim2.new(0, 3, 1, 0), ZIndex = 6, Parent = deco })
	end
	if level >= 3 then
		local inner = UI.new("Frame", { Name = "Inner", BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 3), Size = UDim2.new(1, -7, 1, -6), ZIndex = 6, Parent = deco })
		UI.corner(inner, 2)
		UI.new("UIStroke", { Color = c, Thickness = 1, Transparency = if level >= 5 then 0.2 else 0.55, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = inner })
	end
	if level >= 4 then
		-- corner brackets: four small L-plates
		for _, corner in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do
			for _, horizontal in { true, false } do
				UI.new("Frame", {
					BackgroundColor3 = c,
					BackgroundTransparency = 0,
					AnchorPoint = Vector2.new(corner[1], corner[2]),
					Position = UDim2.fromScale(corner[1], corner[2]),
					Size = if horizontal then UDim2.fromOffset(12, 2) else UDim2.fromOffset(2, 12),
					ZIndex = 7,
					Parent = deco,
				})
			end
		end
	end
	local stroke = plate:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = if level >= 5 then c:Lerp(K.Frame, 0.25) else K.Frame
		stroke.Thickness = if level >= 5 then 3 else 2
	end
	if level >= 6 then
		-- one slow light sweep across the frame every few seconds (no pulsing, no rainbow)
		local sweep = UI.new("Frame", { Name = "Sweep", BackgroundColor3 = c, BackgroundTransparency = 0.82, Position = UDim2.fromScale(-0.2, 0), Size = UDim2.new(0, 26, 1, 0), ZIndex = 5, Parent = deco })
		UI.new("UIGradient", {
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }),
			Parent = sweep,
		})
		deco.ClipsDescendants = true
		task.spawn(function()
			while deco.Parent do
				sweep.Position = UDim2.fromScale(-0.2, 0)
				TweenService:Create(sweep, TweenInfo.new(1.6, Enum.EasingStyle.Sine), { Position = UDim2.fromScale(1.1, 0) }):Play()
				task.wait(4)
			end
		end)
	end
	return deco
end

-- A plate that carries rarity decoration (scale-sized overlay children) must NOT use AutomaticSize, or the overlay keeps
-- it from ever shrinking. fitHeight sizes `plate` to its auto-sized `content` (+ extra design px) instead.
function UI.fitHeight(plate: GuiObject, content: GuiObject, extra: number?)
	plate.AutomaticSize = Enum.AutomaticSize.None
	local function fit()
		-- total UIScale above the plate: the ScreenGui's plus any compact-layout scale on a docking frame (Pass 21B)
		local scale = 1
		local node: Instance? = plate.Parent
		while node do
			local sc = node:FindFirstChildOfClass("UIScale")
			if sc then
				scale *= sc.Scale
			end
			node = node.Parent
		end
		plate.Size = UDim2.new(plate.Size.X.Scale, plate.Size.X.Offset, 0, math.ceil(content.AbsoluteSize.Y / scale + (extra or 0)))
	end
	content:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	task.defer(fit)
end

-- PRESENTATION MOMENTS: reveal / completion take the stage; contextual HUD (cargo, objective, toasts) yields to them.
UI.Moments = {} :: { [string]: boolean }
function UI.setMoment(name: string, on: boolean)
	if (UI.Moments[name] == true) == on then
		return
	end
	UI.Moments[name] = if on then true else nil
	if UI.MomentChanged then
		UI.MomentChanged:Fire(name, on)
	end
end
function UI.inMoment(): boolean
	return next(UI.Moments) ~= nil
end

-- UI.new("Frame", {props}, {children})
function UI.new(class: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(class)
	if inst:IsA("GuiObject") then
		(inst :: any).BorderSizePixel = 0
	end
	if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
		local t = inst :: any
		t.Font = T.Body
		t.TextColor3 = T.Text
		t.BackgroundTransparency = 1
		t.TextScaled = false
		t.TextSize = 16
	end
	local parent = nil
	for k, v in props or {} do
		if k == "Parent" then
			parent = v
		else
			(inst :: any)[k] = v
		end
	end
	for _, c in children or {} do
		c.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UI.corner(parent: Instance, radius: number?): UICorner
	return UI.new("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = parent })
end

function UI.stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	return UI.new("UIStroke", {
		Color = color or T.Stroke,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function UI.textStroke(label: Instance, thickness: number?)
	-- a light edge for legibility over the 3D world, not a cartoon outline
	UI.new("UIStroke", { Color = T.Stroke, Thickness = (thickness or 1.5) * 0.55, Transparency = 0.35, Parent = label })
end

function UI.padding(parent: Instance, px: number)
	UI.new("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		Parent = parent,
	})
end

function UI.list(parent: Instance, padding: number?, horizontal: boolean?, align: Enum.HorizontalAlignment?): UIListLayout
	return UI.new("UIListLayout", {
		Padding = UDim.new(0, padding or 6),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

-- Chunky panel frame.
function UI.card(props: { [string]: any }): Frame
	local f = UI.new("Frame", props)
	if props.BackgroundColor3 == nil then
		f.BackgroundColor3 = T.Panel
	end
	if props.BackgroundTransparency == nil then
		f.BackgroundTransparency = 0.04
	end
	UI.corner(f, UI.Space.Radius)
	UI.stroke(f, T.Stroke, 3)
	return f
end

-- Glossy top highlight inside a chunky button (reads as a raised, pressable block; no gradients on the text)
function UI.shine(b: GuiObject, radius: number?)
	if b:FindFirstChild("Shine") then
		return
	end
	local s = UI.new("Frame", {
		Name = "Shine",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.84,
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 0.38, -2),
		ZIndex = b.ZIndex,
		Parent = b,
	})
	UI.corner(s, radius or 8)
end

-- Tactile button: press squish + click sound.
function UI.button(props: { [string]: any }, onClick: (() -> ())?): TextButton
	local color = props.BackgroundColor3 or T.Accent
	local _ = color
	local b = UI.new("TextButton", props)
	b.BackgroundColor3 = color
	b.BackgroundTransparency = 0
	b.AutoButtonColor = false
	b.Font = props.Font or T.Title
	if props.TextColor3 == nil then
		b.TextColor3 = T.Text
	end
	UI.corner(b, 10)
	UI.stroke(b, T.Stroke, 3)
	UI.shine(b)
	local scale = UI.new("UIScale", { Parent = b })
	-- hover tint remembers whatever color the button has *now*, so code that recolors
	-- buttons (selected tabs, affordable prices) isn't undone by hovering
	local base: Color3? = nil
	b.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1.05 }):Play()
		base = b.BackgroundColor3
		b.BackgroundColor3 = b.BackgroundColor3:Lerp(Color3.new(1, 1, 1), 0.12)
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
		if base then
			b.BackgroundColor3 = base
			base = nil
		end
	end)
	b.Activated:Connect(function()
		base = nil -- click handlers may recolor; don't restore a stale color on leave
	end)
	b.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.92 }):Play()
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end)
	if onClick then
		b.Activated:Connect(function()
			Sound.Play("Click")
			onClick()
			-- short confirmation: a quick brighten that settles to whatever colour the handler left (buy / equip / claim)
			task.defer(function()
				if b.Parent then
					local c = b.BackgroundColor3
					b.BackgroundColor3 = c:Lerp(Color3.new(1, 1, 1), 0.28)
					TweenService:Create(b, TweenInfo.new(0.18), { BackgroundColor3 = c }):Play()
				end
			end)
		end)
	end
	return b
end

function UI.setButtonColor(b: TextButton, color: Color3)
	b.BackgroundColor3 = color
end

-- Progress bar: returns (frame, setFn(fraction, color?))
function UI.bar(props: { [string]: any }, fillColor: Color3): (Frame, (number, Color3?) -> ())
	local f = UI.new("Frame", props)
	f.BackgroundColor3 = props.BackgroundColor3 or K.PlateDeep
	UI.corner(f, 6)
	local fill = UI.new("Frame", { Name = "Fill", BackgroundColor3 = fillColor, Size = UDim2.fromScale(0, 1), Parent = f })
	UI.corner(fill, 6)
	return f, function(frac: number, color: Color3?)
		frac = math.clamp(frac, 0, 1)
		TweenService:Create(fill, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(frac, 1) }):Play()
		if color then
			fill.BackgroundColor3 = color
		end
	end
end

-- Responsive layout --------------------------------------------------------------------
-- One UIScale per ScreenGui keeps proportions across devices. Layout MODE ("desktop",
-- "tablet", "phone") is derived from the viewport and controllers adapt to it (compact
-- leaderboard, smaller menu buttons...). Controllers listen to UI.ModeChanged.
local Signal = require(game:GetService("ReplicatedStorage").Shared.Util.Signal)
UI.ModeChanged = Signal.new() -- (mode)
UI.MomentChanged = Signal.new() -- (name, on)
UI.Mode = "desktop"
UI.Anim = { Fast = 0.12, Normal = 0.22, Slow = 0.4 } -- shared animation timings (seconds)

local function viewport(): Vector2
	local cam = workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(1920, 1080)
end

UI.Portrait = false

local function isPortrait(vp: Vector2): boolean
	return vp.Y > vp.X * 1.1
end

local function computeMode(vp: Vector2): string
	if isPortrait(vp) then
		return if vp.X < 700 then "phone" elseif vp.X < 1000 then "tablet" else "desktop"
	end
	-- short laptop windows (430-700 tall) are tablets, not phones (Bible §19)
	if vp.Y < 430 or vp.X < 760 then
		return "phone"
	elseif vp.X < 1100 or vp.Y < 700 then
		return "tablet"
	end
	return "desktop"
end

function UI.isCompact(): boolean
	return UI.Mode ~= "desktop"
end

function UI.scaleFor(vp: Vector2): number
	if isPortrait(vp) then
		-- portrait: lay out for ~640 virtual studs of width
		return math.clamp(vp.X / 640, 0.72, 1.1)
	end
	-- one floor everywhere (Bible §4): at 0.72 the smallest design size (14) still renders at 10 px; layouts compact instead
	return math.clamp(math.min(vp.X / 1300, vp.Y / 760), 0.72, 1.15)
end

local roots: { [string]: ScreenGui } = {}
local scales: { [string]: UIScale } = {}
local function refreshLayout()
	local vp = viewport()
	for _, sc in scales do
		sc.Scale = UI.scaleFor(vp)
	end
	local mode = computeMode(vp)
	local portrait = isPortrait(vp)
	if mode ~= UI.Mode or portrait ~= UI.Portrait then
		UI.Mode = mode
		UI.Portrait = portrait
		UI.ModeChanged:Fire(mode) -- also fires on orientation flips; read UI.Portrait
	end
end

-- Root ScreenGui shared by controllers (one per display order layer).
function UI.root(name: string, displayOrder: number?): ScreenGui
	if roots[name] then
		return roots[name]
	end
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local g = UI.new("ScreenGui", {
		Name = "MB_" .. name,
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder or 0,
		Parent = pg,
	})
	scales[name] = UI.new("UIScale", { Parent = g })
	if next(roots) == nil and workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshLayout)
	end
	roots[name] = g
	refreshLayout()
	return g
end

-- Small rounded label chip (rarity / modifier / resource tags).
function UI.chip(parent: Instance, text: string, color: Color3, textSize: number?, order: number?): TextLabel
	local t = UI.new("TextLabel", {
		Text = " " .. text .. " ",
		Font = T.Title,
		TextSize = textSize or 15,
		BackgroundColor3 = color,
		BackgroundTransparency = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, (textSize or 15) + 8),
		LayoutOrder = order or 0,
		Parent = parent,
	})
	UI.corner(t, math.floor(((textSize or 15) + 8) / 2))
	UI.stroke(t, T.Stroke, 2)
	-- flat label plate: dark ink on light fills, light ink on dark fills
	local lum = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
	t.TextColor3 = if lum > 0.52 then Color3.fromRGB(24, 20, 10) else T.Text
	return t
end

-- Panels: only one open at a time. Register a builder returning the panel Frame.
-- opts.OnBumper(dir) lets a panel use L1/R1 itself (tab switching); otherwise L1/R1 cycles menus.
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local panels: { [string]: { frame: Frame?, build: () -> Frame, refresh: (() -> ())?, opts: any } } = {}
local openName: string? = nil
UI.PanelChanged = Signal.new() -- (openName: string?)
UI.MenuOrder = { "Upgrades", "Index", "Worker", "Vehicles" }

function UI.registerPanel(name: string, build: () -> Frame, refresh: (() -> ())?, opts: any?)
	panels[name] = { frame = nil, build = build, refresh = refresh, opts = opts or {} }
end

local function usingGamepad(): boolean
	return string.find(UserInputService:GetLastInputType().Name, "Gamepad") ~= nil
end

local bindPanelActions: (any) -> ()

function UI.closePanel()
	if openName then
		Sound.Play("MenuClose")
		local p = panels[openName]
		if p and p.frame then
			p.frame.Visible = false
		end
		openName = nil
		UI.PanelChanged:Fire(nil)
		ContextActionService:UnbindAction("MB_PanelBack")
		ContextActionService:UnbindAction("MB_PanelBumper")
		if usingGamepad() then
			GuiService.SelectedObject = nil
		end
	end
end

function UI.togglePanel(name: string)
	if openName == name then
		UI.closePanel()
		return
	end
	UI.openPanel(name)
end

local function cycleMenus(dir: number)
	local idx = table.find(UI.MenuOrder, openName or "") or 0
	local nextName = UI.MenuOrder[(idx - 1 + dir) % #UI.MenuOrder + 1]
	UI.openPanel(nextName)
end

function UI.openPanel(name: string)
	UI.closePanel()
	local p = panels[name]
	if not p then
		return
	end
	Sound.Play("MenuOpen")
	if not p.frame then
		p.frame = p.build()
	end
	if p.refresh then
		p.refresh()
	end
	local f = p.frame :: Frame
	f.Visible = true
	-- short, flat slide-in (no bounce)
	f.Position = UDim2.new(0.5, 0, 0.5, 14)
	UI.tween(f, UI.Anim.Fast + 0.04, { Position = UDim2.fromScale(0.5, 0.5) })
	openName = name
	UI.PanelChanged:Fire(name)
	bindPanelActions(p)
	if usingGamepad() then
		task.defer(function()
			require(script.Parent.Menu).focusFirst(f)
		end)
	end
end

bindPanelActions = function(p: any)
	ContextActionService:BindActionAtPriority("MB_PanelBack", function(_, state)
		if state == Enum.UserInputState.Begin then
			UI.closePanel()
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.ButtonB)
	ContextActionService:BindActionAtPriority("MB_PanelBumper", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			local dir = if input.KeyCode == Enum.KeyCode.ButtonR1 then 1 else -1
			if p.opts.OnBumper then
				p.opts.OnBumper(dir)
			else
				cycleMenus(dir)
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1)
end

-- SUSPEND / RESUME (Pass 14E): a reveal hides the open menu without destroying it, then puts the SAME menu back (tab, scroll
-- position and content untouched). If the player opened a different menu in the meantime, nothing is restored.
local suspended: string? = nil
function UI.suspendPanel()
	if openName and not suspended then
		suspended = openName
		UI.closePanel()
	end
end
function UI.resumePanel()
	local name = suspended
	suspended = nil
	if name and openName == nil then
		local p = panels[name]
		if p and p.frame then
			p.frame.Visible = true
			openName = name
			UI.PanelChanged:Fire(name)
			bindPanelActions(p)
		end
	end
end

function UI.isOpen(name: string): boolean
	return openName == name
end

function UI.openName(): string?
	return openName
end

-- Keyboard / gamepad shortcuts for the main menus (U, B, J, V; Y opens Upgrades).
local hotkeysBound = false
function UI.bindHotkeys()
	if hotkeysBound then
		return
	end
	hotkeysBound = true
	local keys = { [Enum.KeyCode.U] = "Upgrades", [Enum.KeyCode.B] = "Index", [Enum.KeyCode.J] = "Worker", [Enum.KeyCode.V] = "Vehicles", [Enum.KeyCode.ButtonY] = "Upgrades" }
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local name = keys[input.KeyCode]
		if name and panels[name] then
			UI.togglePanel(name)
		end
	end)
end

-- Compatibility shim (Debug panel): old signature, new flat shell.
function UI.panelShell(name: string, title: string, _size: UDim2): (Frame, Frame)
	local p = require(script.Parent.Menu).panel(name, title)
	return p.Frame, p.Body
end

function UI.tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

return UI
