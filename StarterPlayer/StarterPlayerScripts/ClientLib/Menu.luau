--!strict
-- Menu design system (Upgrades, Build Index, Worker, Vehicles, Debug...).
-- Direction: flat, sturdy, slightly industrial. Square-ish 4px corners, 2px dark borders,
-- one restrained amber accent, no gradients/glow/bounce. Rarity is always shown with a
-- label + tier pips as well as colour. Everything here is small, reusable and config-free.
--
--   Menu.S            style tokens (colours, type sizes, spacing, timings)
--   Menu.button       flat control (kinds: primary / secondary / danger / ghost)
--   Menu.setButton    update text / kind / enabled state of a Menu.button
--   Menu.label/tag/rarityTag/bar/divider/tabs    building blocks
--   Menu.section / well / iconWell / stat / stateTag / grid   Pass 14C additions: section header, borderless wells, stat cell,
--                     shared LOCKED/OWNED/EQUIPPED/ACTIVE... state language, responsive grid
--   Menu.panel        modal shell (header, close button, scrolling body, responsive size). opts.Wide = 720 instead of 640
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UI = require(script.Parent.UI)
local Site = require(script.Parent.Site)
local Sound = require(script.Parent.Sound)

local Menu = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Menu tokens alias the shared UI.Tokens (PRESENTATION_BIBLE §2) so menus and HUD share one palette.
local K = UI.Tokens
Menu.S = {
	-- surfaces
	Bg = K.Plate,
	Surface = rgb(54, 66, 88),
	Raised = rgb(72, 86, 112),
	Header = K.PlateDeep,
	Border = K.Frame,
	Line = K.Rule,
	Blueprint = rgb(24, 46, 78),
	BlueprintLine = rgb(70, 130, 190),
	-- text
	Text = K.Ink,
	Dim = K.InkDim,
	Faint = K.InkFaint,
	-- accents (restrained)
	Accent = K.Amber,
	AccentText = K.AmberInk,
	Cyan = K.Power,
	Orange = K.Signal,
	Good = K.Good,
	GoodText = rgb(10, 24, 12),
	Bad = K.Bad,
	Disabled = rgb(66, 72, 86),
	-- type
	Font = Enum.Font.BuilderSans,
	FontBold = Enum.Font.BuilderSansBold,
	FontHeavy = Enum.Font.BuilderSansExtraBold,
	-- chunky rounded plates (Pass 21A)
	Radius = 12,
	Pad = 12,
	Gap = 8,
	-- timings
	Fast = 0.1,
	Normal = 0.16,
}
local S = Menu.S

-- Small = 14 design px is the floor (renders >= 10 px at the 0.72 scale floor, PRESENTATION_BIBLE section 4)
local TYPE = { H1 = 28, H2 = 20, Body = 16, Small = 14 }

-- Type sizes grow slightly on touch/compact layouts so nothing important is tiny.
function Menu.size(name: string): number
	local base = (TYPE :: any)[name] or TYPE.Body
	if UI.Mode ~= "desktop" and name == "Small" then
		return base + 1
	end
	return base
end

function Menu.isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled or UI.Mode == "phone"
end

-- Layout units that come out to at least `minPx` real pixels once the ScreenGui UIScale is
-- applied (the phone scale floor shrinks 46-unit buttons to ~33px, which is too small to tap).
function Menu.touchSize(base: number, minPx: number?): number
	local cam = workspace.CurrentCamera
	local scale = if cam then UI.scaleFor(cam.ViewportSize) else 1
	return math.min(math.max(base, math.ceil((minPx or 40) / scale)), 60)
end

-- Comfortable touch target (>= 40 real px, 46 units at least); 36 with a mouse.
function Menu.buttonHeight(): number
	if Menu.isTouch() or UserInputService.GamepadEnabled then
		return Menu.touchSize(46)
	end
	return 40
end

-- Shared gamepad focus ring (one template, cloned by Roblox for every selectable).
local focusRing: Frame
local function getFocusRing(): Frame
	if not focusRing then
		focusRing = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
		UI.new("UIStroke", { Color = rgb(255, 255, 255), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = focusRing })
		UI.new("UICorner", { CornerRadius = UDim.new(0, 5), Parent = focusRing })
	end
	return focusRing
end

local KINDS = {
	primary = { fill = S.Accent, text = S.AccentText },
	good = { fill = S.Good, text = S.GoodText },
	secondary = { fill = S.Raised, text = S.Text },
	danger = { fill = S.Bad, text = rgb(255, 255, 255) },
	ghost = { fill = S.Surface, text = S.Text },
}

local function tint(c: Color3, amount: number): Color3
	return if amount >= 0 then c:Lerp(Color3.new(1, 1, 1), amount) else c:Lerp(Color3.new(0, 0, 0), -amount)
end

-- Applies kind/enabled/text to a Menu.button (also remembers them as attributes).
function Menu.setButton(b: TextButton, props: { Text: string?, Kind: string?, Enabled: boolean? })
	if props.Text then
		b.Text = props.Text
	end
	if props.Kind then
		b:SetAttribute("Kind", props.Kind)
	end
	if props.Enabled ~= nil then
		b:SetAttribute("Enabled", props.Enabled)
	end
	local kind = KINDS[b:GetAttribute("Kind") or "secondary"] or KINDS.secondary
	local enabled = b:GetAttribute("Enabled") ~= false
	b.Active = enabled
	b.AutoButtonColor = false
	b.BackgroundColor3 = if enabled then kind.fill else S.Disabled
	b.TextColor3 = if enabled then kind.text else S.Faint
	b:SetAttribute("BaseColor", b.BackgroundColor3)
	local shine = b:FindFirstChild("Shine")
	if shine then
		(shine :: Frame).Visible = enabled
	end
end

function Menu.button(props: { [string]: any }, onClick: (() -> ())?): TextButton
	local kind = props.Kind or "secondary"
	props.Kind = nil
	local height = props.Height or Menu.buttonHeight()
	props.Height = nil
	local enabled = props.Enabled ~= false
	props.Enabled = nil
	local b = UI.new("TextButton", props)
	b.Font = S.FontBold
	b.TextSize = props.TextSize or Menu.size("Body")
	b.BackgroundTransparency = 0
	b.AutoButtonColor = false
	b.Selectable = true
	b.SelectionImageObject = getFocusRing()
	b.TextTruncate = Enum.TextTruncate.AtEnd
	if not props.Size then
		b.Size = UDim2.fromOffset(120, height)
	end
	UI.new("UICorner", { CornerRadius = UDim.new(0, 10), Parent = b })
	UI.new("UIStroke", { Color = S.Border, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = b })
	b.Font = S.FontHeavy
	UI.shine(b)
	local press = UI.new("UIScale", { Parent = b })
	Menu.setButton(b, { Kind = kind, Enabled = enabled })
	b.MouseEnter:Connect(function()
		if b:GetAttribute("Enabled") ~= false then
			b.BackgroundColor3 = tint(b:GetAttribute("BaseColor") :: Color3, 0.1)
		end
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundColor3 = b:GetAttribute("BaseColor") :: Color3
	end)
	b.MouseButton1Down:Connect(function()
		if b:GetAttribute("Enabled") ~= false then
			b.BackgroundColor3 = tint(b:GetAttribute("BaseColor") :: Color3, -0.14)
			TweenService:Create(press, TweenInfo.new(0.06), { Scale = 0.93 }):Play()
		end
	end)
	b.MouseButton1Up:Connect(function()
		b.BackgroundColor3 = b:GetAttribute("BaseColor") :: Color3
		TweenService:Create(press, TweenInfo.new(0.16, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end)
	if onClick then
		b.Activated:Connect(function()
			if b:GetAttribute("Enabled") == false then
				return
			end
			Sound.Play("Click")
			onClick()
			task.defer(function() -- short confirmation (primary actions): brighten, then settle back to the base colour
				if b.Parent and b:GetAttribute("Enabled") ~= false then
					local c = b:GetAttribute("BaseColor") :: Color3
					b.BackgroundColor3 = tint(c, 0.2)
					TweenService:Create(b, TweenInfo.new(0.18), { BackgroundColor3 = c }):Play()
				end
			end)
		end)
	end
	return b
end

function Menu.label(parent: Instance, text: string, sizeName: string?, color: Color3?, bold: boolean?): TextLabel
	local l = UI.new("TextLabel", {
		Text = text,
		Font = if bold then S.FontBold else S.Font,
		TextSize = Menu.size(sizeName or "Body"),
		TextColor3 = color or S.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, 0, 0, Menu.size(sizeName or "Body") + 4),
		Parent = parent,
	})
	return l
end

-- Flat rectangular tag (state labels such as EQUIPPED, MAXED, LOCKED).
function Menu.tag(parent: Instance, text: string, fill: Color3?, textColor: Color3?, order: number?): TextLabel
	local t = UI.new("TextLabel", {
		Text = text,
		Font = S.FontBold,
		TextSize = Menu.size("Small"),
		TextColor3 = textColor or S.Text,
		BackgroundColor3 = fill or S.Raised,
		BackgroundTransparency = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, Menu.size("Small") + 8),
		LayoutOrder = order or 0,
		Parent = parent,
	})
	UI.new("UICorner", { CornerRadius = UDim.new(0, math.floor((Menu.size("Small") + 8) / 2)), Parent = t })
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9), Parent = t })
	t.Font = S.FontHeavy
	return t
end

-- Rarity label: colour swatch + NAME + tier pips (accessible without colour).
local RARITY_ORDER = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6 }
function Menu.rarityTag(parent: Instance, rarityName: string, color: Color3, order: number?): Frame
	local lum = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
	local ink = if lum > 0.55 then S.AccentText else S.Text
	local f = UI.new("Frame", { BackgroundColor3 = color, BackgroundTransparency = 0, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 22), LayoutOrder = order or 0, Parent = parent })
	UI.new("UICorner", { CornerRadius = UDim.new(0, 11), Parent = f })
	UI.new("UIStroke", { Color = S.Border, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = f })
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = f })
	local layout = UI.list(f, 4, true)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	local label = UI.new("TextLabel", {
		Text = string.upper(rarityName),
		Font = S.FontHeavy,
		TextSize = Menu.size("Small"),
		TextColor3 = ink,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 18),
		LayoutOrder = 1,
		Parent = f,
	})
	local _ = label
	local pips = UI.new("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 18), LayoutOrder = 2, Parent = f })
	local pl = UI.list(pips, 2, true)
	pl.VerticalAlignment = Enum.VerticalAlignment.Center
	local tier = RARITY_ORDER[rarityName] or 1
	for i = 1, 6 do
		UI.new("Frame", {
			BackgroundColor3 = ink,
			BackgroundTransparency = if i <= tier then 0 else 0.75,
			Size = UDim2.fromOffset(4, 8),
			LayoutOrder = i,
			Parent = pips,
		})
	end
	return f
end

-- Thin flat progress bar. Returns (track, set(fraction, color?)).
function Menu.bar(parent: Instance, height: number?, fill: Color3?): (Frame, (number, Color3?) -> ())
	local h = math.max(height or 12, 10)
	local track = UI.new("Frame", { BackgroundColor3 = S.Header, BackgroundTransparency = 0, Size = UDim2.new(1, 0, 0, h), Parent = parent })
	UI.new("UICorner", { CornerRadius = UDim.new(0, math.floor(h / 2)), Parent = track })
	UI.new("UIStroke", { Color = S.Border, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = track })
	local bar = UI.new("Frame", { BackgroundColor3 = fill or S.Accent, BackgroundTransparency = 0, Size = UDim2.fromScale(0, 1), Parent = track })
	UI.new("UICorner", { CornerRadius = UDim.new(0, math.floor(h / 2)), Parent = bar })
	return track, function(frac: number, color: Color3?)
		bar.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
		if color then
			bar.BackgroundColor3 = color
		end
	end
end

function Menu.divider(parent: Instance, order: number?): Frame
	return UI.new("Frame", { BackgroundColor3 = S.Line, BackgroundTransparency = 0, Size = UDim2.new(1, 0, 0, 1), LayoutOrder = order or 0, Parent = parent })
end

-- Flat card/row surface with a dark border. `stripe` draws a 4px accent bar on the left.
function Menu.surface(parent: Instance, props: { [string]: any }?, stripe: Color3?): Frame
	local f = UI.new("Frame", props or {})
	f.BackgroundColor3 = S.Surface
	f.BackgroundTransparency = 0
	f.Parent = parent
	UI.new("UICorner", { CornerRadius = UDim.new(0, S.Radius), Parent = f })
	UI.new("UIStroke", { Color = S.Border, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = f })
	if stripe then
		-- a coloured top band instead of a thin side stripe: the card reads its family / rarity at a glance
		local band = UI.new("Frame", { Name = "Stripe", BackgroundColor3 = stripe, BackgroundTransparency = 0, Size = UDim2.new(1, 0, 0, 6), Parent = f })
		UI.new("UICorner", { CornerRadius = UDim.new(0, S.Radius), Parent = band })
	end
	return f
end


-- SECTION HEADER: UPPER label (+ optional right-hand meta) over a 1 px rule. One style for every menu.
function Menu.section(parent: Instance, text: string, order: number?, meta: string?): Frame
	local f = UI.new("Frame", { Name = "Section", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Menu.size("Small") + 10), LayoutOrder = order or 0, Parent = parent })
	UI.new("TextLabel", {
		Text = string.upper(text),
		Font = S.FontHeavy,
		TextSize = Menu.size("Small"),
		TextColor3 = S.Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(if meta then 0.55 else 1, 0, 1, -4),
		Parent = f,
	})
	if meta then
		UI.new("TextLabel", {
			Text = meta,
			Font = S.Font,
			TextSize = Menu.size("Small"),
			TextColor3 = S.Faint,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextTruncate = Enum.TextTruncate.AtEnd,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0.45, 0, 1, -4),
			Parent = f,
		})
	end
	UI.new("Frame", { BackgroundColor3 = S.Line, BackgroundTransparency = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1), Parent = f })
	return f
end

-- Borderless deep well (icon tiles, stat cells): the third nesting level never gets its own border (Bible section 6).
function Menu.well(parent: Instance, props: { [string]: any }?): Frame
	local f = UI.new("Frame", props or {})
	f.BackgroundColor3 = S.Header
	f.BackgroundTransparency = 0
	f.Parent = parent
	UI.new("UICorner", { CornerRadius = UDim.new(0, 8), Parent = f })
	return f
end

-- square well with a Site pictogram centred in it
function Menu.iconWell(parent: Instance, icon: string, color: Color3?, px: number?, order: number?): Frame
	local size = px or 44
	local w = Menu.well(parent, { Name = "IconWell", Size = UDim2.fromOffset(size, size), LayoutOrder = order or 0 })
	local c = color or S.Accent
	w.BackgroundColor3 = c:Lerp(S.Header, 0.72)
	w:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, math.floor(size * 0.3))
	UI.new("UIStroke", { Color = c, Thickness = 2, Transparency = 0.35, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = w })
	local ic = Site.icon(w, icon, c, math.floor(size * 0.66))
	ic.AnchorPoint = Vector2.new(0.5, 0.5)
	ic.Position = UDim2.fromScale(0.5, 0.5)
	return w
end

-- STAT CELL: small label over a bold value (deep well). Used wherever numbers are the point.
function Menu.stat(parent: Instance, label: string, value: string, order: number?, valueColor: Color3?): Frame
	local f = Menu.well(parent, { Name = "Stat_" .. label, LayoutOrder = order or 0 })
	UI.new("TextLabel", { Text = string.upper(label), Font = S.FontHeavy, TextSize = Menu.size("Small"), TextColor3 = S.Dim, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -16, 0, 18), Parent = f })
	UI.new("TextLabel", { Name = "Value", Text = value, Font = S.FontHeavy, TextSize = Menu.size("H2"), TextColor3 = valueColor or S.Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(10, 22), Size = UDim2.new(1, -16, 0, 24), Parent = f })
	return f
end

-- SHARED STATE LANGUAGE for LOCKED / OWNED / EQUIPPED / ACTIVE / OFF / MAXED / READY / DONE (colour + word, never colour alone)
local STATES = {
	EQUIPPED = { fill = S.Accent, text = S.AccentText },
	READY = { fill = S.Accent, text = S.AccentText },
	ACTIVE = { fill = S.Good, text = S.GoodText },
	OWNED = { fill = S.Raised, text = S.Good },
	UNLOCKED = { fill = S.Raised, text = S.Good },
	MAXED = { fill = S.Raised, text = S.Good },
	DONE = { fill = S.Raised, text = S.Good },
	LOCKED = { fill = S.Header, text = S.Faint },
	OFF = { fill = S.Raised, text = S.Dim },
	ONBREAK = { fill = S.Raised, text = S.Orange },
}
local function stateDef(state: string): { fill: Color3, text: Color3 }
	return STATES[string.upper(string.gsub(state, "%s", ""))] or STATES.OFF
end
function Menu.stateTag(parent: Instance, state: string, order: number?, text: string?): TextLabel
	local def = stateDef(state)
	local t = Menu.tag(parent, text or state, def.fill, def.text, order)
	t.Name = "State"
	t.Font = S.FontHeavy
	return t
end
function Menu.setStateTag(t: TextLabel, state: string, text: string?)
	local def = stateDef(state)
	t.Text = text or state
	t.BackgroundColor3 = def.fill
	t.TextColor3 = def.text
end

-- RESPONSIVE GRID: cells are at least `Min` design px wide, columns follow the real width (1..Max), cell height is fixed.
-- Returns (grid, layout). Works inside a UIScale'd ScreenGui and in a ScrollingFrame (only the width drives the columns).
function Menu.grid(parent: Instance, opts: { Min: number, Height: number, Max: number?, Gap: number?, Order: number? }): (Frame, UIGridLayout)
	local gap = opts.Gap or 10
	-- height is computed from the column count (AutomaticSize does not reliably shrink when UIGridLayout re-flows)
	local grid = UI.new("Frame", { Name = "Grid", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, opts.Height), LayoutOrder = opts.Order or 0, Parent = parent })
	local layout = UI.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(opts.Min, opts.Height),
		CellPadding = UDim2.fromOffset(gap, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Parent = grid,
	})
	local function fit()
		local gui = grid:FindFirstAncestorWhichIsA("ScreenGui")
		local us = gui and gui:FindFirstChildWhichIsA("UIScale")
		local avail = grid.AbsoluteSize.X / (if us then us.Scale else 1) - 1
		if avail < 60 then
			return
		end
		local cols = math.clamp(math.floor((avail + gap) / (opts.Min + gap)), 1, opts.Max or 6)
		layout.CellSize = UDim2.fromOffset(math.floor((avail - gap * (cols - 1)) / cols), opts.Height)
		local n = 0
		for _, c in grid:GetChildren() do
			if c:IsA("GuiObject") then
				n += 1
			end
		end
		local rows = math.max(1, math.ceil(n / cols))
		grid.Size = UDim2.new(1, 0, 0, rows * opts.Height + (rows - 1) * gap)
	end
	grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	grid.ChildAdded:Connect(function()
		task.defer(fit)
	end)
	task.defer(fit)
	return grid, layout
end

-- Segmented tab bar. defs = { {Id=, Text=} }. Returns controller { Frame, Select(id), Next(dir), Current }.
-- Phone layouts keep every tab at a readable width and scroll the bar sideways instead of squeezing the text.
function Menu.tabs(parent: Instance, defs: { { Id: string, Text: string } }, onSelect: (string) -> ()): any
	local compact = UI.Mode == "phone" and #defs > 2
	local frame: any
	if compact then
		frame = UI.new("ScrollingFrame", {
			BackgroundColor3 = S.Header,
			BackgroundTransparency = 0,
			Size = UDim2.new(1, 0, 0, Menu.buttonHeight() + 6),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			ScrollingDirection = Enum.ScrollingDirection.X,
			ScrollBarThickness = 0,
			ElasticBehavior = Enum.ElasticBehavior.Never,
			Parent = parent,
		})
	else
		frame = UI.new("Frame", { BackgroundColor3 = S.Header, BackgroundTransparency = 0, Size = UDim2.new(1, 0, 0, Menu.buttonHeight() + 6), Parent = parent })
	end
	UI.list(frame, 4, true)
	UI.new("UICorner", { CornerRadius = UDim.new(0, 12), Parent = frame })
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = frame })
	local buttons: { [string]: TextButton } = {}
	local ctl: any = { Frame = frame, Current = defs[1].Id }
	local function paint()
		for id, b in buttons do
			local on = id == ctl.Current
			b.TextColor3 = if on then S.AccentText else S.Dim
			b.BackgroundColor3 = if on then S.Accent else S.Header
			local bar = b:FindFirstChild("Underline") :: Frame?
			if bar then
				bar.Visible = on
			end
			b.Font = if on then S.FontHeavy else S.FontBold
		end
	end
	function ctl.Select(id: string)
		if buttons[id] then
			ctl.Current = id
			paint()
			onSelect(id)
		end
	end
	function ctl.Next(dir: number)
		for i, d in defs do
			if d.Id == ctl.Current then
				local n = defs[(i - 1 + dir) % #defs + 1]
				ctl.Select(n.Id)
				return
			end
		end
	end
	for i, d in defs do
		local b = UI.new("TextButton", {
			Name = "Tab_" .. d.Id,
			Text = d.Text,
			Font = S.FontBold,
			TextSize = Menu.size("Body"),
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Selectable = true,
			SelectionImageObject = getFocusRing(),
			Size = if compact then UDim2.new(0, math.max(120, #d.Text * 11 + 36), 1, 0) else UDim2.new(1 / #defs, -4, 1, 0),
			LayoutOrder = i,
			Parent = frame,
		})
		UI.new("UICorner", { CornerRadius = UDim.new(0, 10), Parent = b })
		b.Activated:Connect(function()
			Sound.Play("Click")
			ctl.Select(d.Id)
		end)
		buttons[d.Id] = b
	end
	paint()
	return ctl
end

-- Modal panel shell. Returns { Frame, Body (ScrollingFrame), Header, Subtitle, Close }.
-- Size is responsive: 92% x 88% of the screen, capped at MaxWidth x MaxHeight.
function Menu.panel(name: string, title: string, opts: { MaxWidth: number?, MaxHeight: number?, Icon: string?, Wide: boolean? }?): any
	local o = opts or {}
	local g = UI.root("Panels", 5)
	local frame = UI.new("Frame", {
		Name = name,
		BackgroundColor3 = S.Bg,
		BackgroundTransparency = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		-- desktop: 92% x 88%; tighter margins on smaller windows (Bible section 19)
		Size = if UI.Mode == "desktop" then UDim2.fromScale(0.92, 0.88) else UDim2.fromScale(0.97, 0.95),
		Visible = false,
		Parent = g,
	})
	frame.Selectable = false
	frame.SelectionGroup = true
	for _, dir in { "Up", "Down", "Left", "Right" } do
		(frame :: any)["SelectionBehavior" .. dir] = Enum.SelectionBehavior.Stop
	end
	UI.new("UISizeConstraint", { MaxSize = Vector2.new(o.MaxWidth or (if o.Wide then 720 else 640), o.MaxHeight or 580), MinSize = Vector2.new(280, 200), Parent = frame })
	UI.new("UICorner", { CornerRadius = UDim.new(0, 16), Parent = frame })
	UI.new("UIStroke", { Color = S.Border, Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = frame })

	-- construction-yellow header band: the menu title is the loudest thing in the panel
	local headerH = Menu.buttonHeight() + 16
	local header = UI.new("Frame", { Name = "Header", BackgroundColor3 = S.Accent, BackgroundTransparency = 0, Size = UDim2.new(1, 0, 0, headerH), Parent = frame })
	UI.new("UICorner", { CornerRadius = UDim.new(0, 16), Parent = header })
	-- square off the header's bottom corners
	UI.new("Frame", { BackgroundColor3 = S.Accent, BackgroundTransparency = 0, Position = UDim2.new(0, 0, 1, -10), Size = UDim2.new(1, 0, 0, 10), Parent = header })
	-- caution-stripe seam between the header plate and the body
	local seam = Site.hazard(header, 4)
	seam.AnchorPoint = Vector2.new(0, 1)
	seam.Position = UDim2.fromScale(0, 1)
	local titleX = 16
	if o.Icon then
		-- the menu pictogram sits in a dark disc on the yellow band
		local disc = UI.new("Frame", { BackgroundColor3 = S.AccentText, BackgroundTransparency = 0, Position = UDim2.new(0, 12, 0.5, -20), Size = UDim2.fromOffset(36, 36), Parent = header })
		UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = disc })
		local ic = Site.icon(disc, o.Icon, S.Accent, 24)
		ic.AnchorPoint = Vector2.new(0.5, 0.5)
		ic.Position = UDim2.fromScale(0.5, 0.5)
		titleX = 58
	end
	local titleLabel = UI.new("TextLabel", {
		Text = string.upper(title),
		Font = S.FontHeavy,
		TextSize = Menu.size("H1"),
		TextColor3 = S.AccentText,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(titleX, 0),
		Size = UDim2.new(0.5, -titleX, 1, -4),
		Parent = header,
	})
	local subtitle = UI.new("TextLabel", {
		Text = "",
		Font = S.Font,
		TextSize = Menu.size("Small"),
		TextColor3 = rgb(92, 66, 10),
		Font = S.FontBold,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -(headerH + 8), 0, 0),
		Size = UDim2.new(0.5, -(headerH + 8), 1, -2),
		Parent = header,
	})
	local close = Menu.button({
		Name = "Close",
		Text = "X",
		Kind = "danger",
		TextSize = Menu.size("H2"),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, -3),
		Size = UDim2.fromOffset(headerH - 20, headerH - 20),
		Parent = header,
	}, function()
		UI.closePanel()
	end)

	local body = UI.new("ScrollingFrame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, headerH),
		Size = UDim2.new(1, 0, 1, -headerH),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = if Menu.isTouch() then 10 else 8,
		ScrollBarImageColor3 = S.Line,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		Parent = frame,
	})
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, S.Pad), PaddingRight = UDim.new(0, S.Pad + 6), PaddingTop = UDim.new(0, S.Pad), PaddingBottom = UDim.new(0, S.Pad), Parent = body })
	return { Frame = frame, Body = body, Header = header, HeaderH = headerH, Title = titleLabel, Subtitle = subtitle, Close = close }
end

-- Redraws a menu section without losing gamepad focus: remembers the focused button's name
-- and re-selects the same-named button after `redraw` rebuilt the content.
function Menu.keepFocus(frame: GuiObject, redraw: () -> ())
	local sel = GuiService.SelectedObject
	local name = if sel and sel:IsDescendantOf(frame) then sel.Name else nil
	redraw()
	if name then
		local n = frame:FindFirstChild(name, true)
		if n and n:IsA("GuiObject") and n.Visible then
			GuiService.SelectedObject = n
		end
	end
end

-- Gamepad: focus the first usable button inside a panel (called when a panel opens).
function Menu.focusFirst(frame: GuiObject)
	local best: GuiObject? = nil
	local bestY = math.huge
	for _, d in frame:GetDescendants() do
		if d:IsA("TextButton") and d.Visible and d.Selectable and d.Active and d.Name ~= "Close" then
			local y = d.AbsolutePosition.Y
			if y < bestY and d.AbsoluteSize.X > 0 then
				best, bestY = d, y
			end
		end
	end
	GuiService.SelectedObject = best or (frame:FindFirstChild("Close", true) :: GuiObject?)
end

return Menu
