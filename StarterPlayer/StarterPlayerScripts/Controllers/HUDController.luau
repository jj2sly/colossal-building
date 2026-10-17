--!strict
-- Main HUD frame (PRESENTATION_BIBLE §8–§12). Three permanent zones on every device:
--   TOP LEFT      StatsColumn (one-line status strip: Coins · Server Luck · rank) and, under it, TopStack (project card +
--                 event strip, docked by TrackerController / EventUIController). The project is the strongest element.
--   RIGHT         the navigation rail (construction control strip): icon buttons, hover label flags, "!" badges.
--   BOTTOM CENTRE contextual cargo: a quiet chip while empty, a named cargo plate with DROP while hauling.
-- RightStack (contribution leaderboard) sits top right, left of the rail. The objective pill sits above the cargo.
-- Contextual UI yields to presentation moments (UI.setMoment: reveal / completion).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Format = require(Shared.Util.Format)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local DailyConfig = require(Shared.Config.DailyConfig)
local Lib = script.Parent.Parent.ClientLib
local UI = require(Lib.UI)
local Menu = require(Lib.Menu)
local Site = require(Lib.Site)
local State = require(Lib.State)
local Sound = require(Lib.Sound)

local HUDController = {}
local player = Players.LocalPlayer
local T = UI.Theme
local K = UI.Tokens
local TY = UI.Type
local MARGIN = UI.Space.Margin

HUDController.TopStack = nil :: Frame?
HUDController.RightStack = nil :: Frame?
HUDController.StatsColumn = nil :: Frame?

local objective: Frame
local objectiveStep: TextLabel
local objectiveText: TextLabel
local lastObjective = ""
local objectiveToken = 0
local menuButtons: Frame
local carryCard: Frame
local menuMeta: { { name: string, button: TextButton, icon: Frame, bar: Frame, flag: TextLabel } } = {}
local refreshCarry: () -> () = function() end

local RAIL_BUTTON = 54
local RAIL_PAD = 0
local PILL_H = 40

-- Status-strip item: one compact plate with a coloured pictogram and a value (no coloured edges, no wells).
-- `icon` is a Site pictogram name (coin / clover / trophy ...).
function HUDController.Pill(parent: Instance, icon: string, color: Color3, order: number, caption: string?): (Frame, TextLabel)
	local f = UI.card({
		BackgroundColor3 = K.Plate,
		BackgroundTransparency = 0.04,
		Size = UDim2.fromOffset(0, PILL_H),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = order,
		Parent = parent,
	})
	f:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, PILL_H / 2)
	-- content lives in its own row so overlay children (e.g. a full-size click button) never join the layout
	local row = UI.new("Frame", { Name = "Row", BackgroundTransparency = 1, Size = UDim2.fromOffset(0, PILL_H), AutomaticSize = Enum.AutomaticSize.X, Parent = f })
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 14), Parent = row })
	local l = UI.list(row, 7, true)
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	-- the pictogram sits in a disc of its own colour (the icon reads before the number)
	local disc = UI.new("Frame", { Name = "Disc", BackgroundColor3 = color, BackgroundTransparency = 0, Size = UDim2.fromOffset(PILL_H - 8, PILL_H - 8), LayoutOrder = 1, Parent = row })
	UI.corner(disc, (PILL_H - 8) / 2)
	UI.stroke(disc, K.Frame, 2)
	local ic = Site.icon(disc, icon, K.Ink, PILL_H - 14, color:Lerp(K.Frame, 0.55))
	ic.AnchorPoint = Vector2.new(0.5, 0.5)
	ic.Position = UDim2.fromScale(0.5, 0.5)
	if caption then
		UI.new("TextLabel", { Name = "Caption", Text = caption, Font = TY.Heavy, TextSize = TY.Label, TextColor3 = color:Lerp(K.Ink, 0.35), AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20), LayoutOrder = 2, Parent = row })
	end
	local label = UI.new("TextLabel", {
		Font = TY.Heavy,
		TextSize = 24,
		TextColor3 = K.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 28),
		LayoutOrder = 3,
		Parent = row,
	})
	UI.textStroke(label, 1.5)
	return f, label
end

-- a short number bounce on a HUD value that just went up (simulator "it grew" feedback, ~0.2 s)
local function bounce(label: GuiObject)
	local sc = label:FindFirstChildOfClass("UIScale") or UI.new("UIScale", { Parent = label })
	sc.Scale = 1.22
	UI.tween(sc, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
end
HUDController.Bounce = bounce

-- strip emoji / pictographs from UI copy (Bible §4: pictograms come from Site.icon, never emoji)
local function plainText(s: string): string
	local out = {}
	for _, cp in utf8.codes(s) do
		if cp < 0x2000 then
			table.insert(out, utf8.char(cp))
		end
	end
	return (string.gsub(table.concat(out), "%s%s+", " "))
end

local function objectiveAllowed(): boolean
	return not UI.inMoment()
end

-- Objective line: a short instruction, optionally prefixed by a "STEP n/m" chip.
function HUDController.SetObjective(text: string, color: Color3?, step: string?, persist: boolean?)
	if not objective then
		return
	end
	-- SIMPLICITY: an objective is a short, temporary nudge. It shows when the task CHANGES, fades after a few
	-- seconds and is not repeated while the same task continues.
	if text == "" then
		objective.Visible = false
		lastObjective = ""
		return
	end
	if text == lastObjective then
		if persist and not objective.Visible then
			objective.Visible = objectiveAllowed() -- a persistent intro step comes back after a menu / moment closes
		end
		return
	end
	lastObjective = text
	objectiveToken += 1
	local token = objectiveToken
	objective.Visible = objectiveAllowed()
	objectiveText.Text = plainText(text)
	objectiveText.TextColor3 = if color then color:Lerp(K.Ink, 0.4) else K.Ink
	objectiveStep.Visible = step ~= nil
	objectiveStep.Text = if step then "  " .. step .. "  " else ""
	if persist then
		return -- first-session steps stay until the task changes
	end
	task.delay(8, function()
		if objectiveToken == token and objective then
			objective.Visible = false
		end
	end)
end

-- Notification badge on a rail button: a small amber plate with "!" (one short pulse when it appears, then still).
local badges: { [string]: TextLabel } = {}
function HUDController.SetBadge(name: string, on: boolean)
	local b = menuButtons and menuButtons:FindFirstChild(name)
	if not b then
		return
	end
	local badge = badges[name]
	if on and not badge then
		local l = UI.new("TextLabel", {
			Name = "Badge",
			Text = "!",
			Font = TY.Heavy,
			TextSize = 16,
			TextColor3 = K.Ink,
			BackgroundColor3 = K.Bad,
			BackgroundTransparency = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(22, 22),
			ZIndex = 8,
			Parent = b,
		})
		UI.corner(l, 11)
		UI.stroke(l, K.Frame, 2)
		local sc = UI.new("UIScale", { Scale = 1.5, Parent = l })
		UI.tween(sc, 0.3, { Scale = 1 })
		badges[name] = l
	elseif not on and badge then
		badges[name] = nil
		badge:Destroy()
	end
end

-- Docks that follow their neighbours' real height (portrait phones stack the leaderboard under the project card).
local function placeStacks()
	local top, right, stats = HUDController.TopStack, HUDController.RightStack, HUDController.StatsColumn
	if not (top and right and stats) then
		return
	end
	local cam = workspace.CurrentCamera
	local scale = if cam then UI.scaleFor(cam.ViewportSize) else 1
	top.Position = UDim2.fromOffset(MARGIN, 8 + stats.AbsoluteSize.Y / scale + 6)
	if UI.Mode == "phone" and UI.Portrait then
		right.AnchorPoint = Vector2.zero
		right.Position = UDim2.fromOffset(MARGIN, 8 + stats.AbsoluteSize.Y / scale + 6 + top.AbsoluteSize.Y / scale + 6)
	else
		right.AnchorPoint = Vector2.new(1, 0)
		right.Position = UDim2.new(1, -(MARGIN + RAIL_BUTTON + 14), 0, 8)
	end
end

-- (Pass 21B) compact phones / tablets: the whole top-left block (strip + project card + event) and the cargo plate scale down so
-- they leave the world visible; essential text stays >= ~11 px at the UIScale floor.
local function compactScale(): number
	if UI.Mode == "phone" then
		return if UI.Portrait then 0.9 else 0.8
	elseif UI.Mode == "tablet" then
		return 0.88
	end
	return 1
end
local function setScaleOn(inst: GuiObject?, scale: number)
	if not inst then
		return
	end
	local sc = inst:FindFirstChild("CompactScale") :: UIScale?
	if not sc then
		sc = UI.new("UIScale", { Name = "CompactScale", Parent = inst }) :: UIScale
	end
	(sc :: UIScale).Scale = scale
end

local function applyMode()
	local phone = UI.Mode == "phone"
	local portrait = phone and UI.Portrait
	local cs = compactScale()
	setScaleOn(HUDController.TopStack, cs)
	setScaleOn(HUDController.StatsColumn, cs)
	if carryCard then
		setScaleOn(carryCard, math.min(1, cs + 0.08))
	end
	local size = if phone then math.max(RAIL_BUTTON, Menu.touchSize(44)) else RAIL_BUTTON
	if menuButtons then
		menuButtons.AnchorPoint = Vector2.new(1, 0.5)
		menuButtons.Position = UDim2.new(1, -MARGIN, 0.5, if portrait then 40 else 0)
	end
	for _, m in menuMeta do
		m.button.Size = UDim2.fromOffset(size, size)
	end
	local top, right = HUDController.TopStack, HUDController.RightStack
	if top and right then
		top.AnchorPoint = Vector2.zero
		top.Size = UDim2.fromOffset(if portrait then 296 else 330, 0)
		right.Size = UDim2.fromOffset(if portrait then 200 else 230, 0)
		local rl = right:FindFirstChildOfClass("UIListLayout")
		if rl then
			rl.HorizontalAlignment = if portrait then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Right
		end
	end
	refreshCarry()
	placeStacks()
end

-- Rail button states: rest (Plate), hover (raised + label flag), open (raised + amber edge + amber pictogram).
local function paintMenuButtons(openName: string?)
	for _, m in menuMeta do
		local on = m.name == openName
		m.bar.Visible = on
		local cap = m.button:FindFirstChild("Caption") :: TextLabel?
		if cap then
			cap.TextColor3 = if on then K.AmberInk else K.InkDim
		end
		m.button.BackgroundColor3 = if on then K.Amber else K.PlateRaised
		local st = m.button:FindFirstChildOfClass("UIStroke")
		if st then
			st.Color = if on then K.AmberInk else K.Frame
		end
		for _, d in m.icon:GetDescendants() do
			if d:IsA("Frame") and d.BackgroundTransparency == 0 and d.Name ~= "Dark" then
				-- pictogram blocks follow the tab state; detail blocks (tagged once) flip to amber so they stay readable
				if d:GetAttribute("Detail") == nil then
					d:SetAttribute("Detail", d.BackgroundColor3 == Site.Color.SteelDark)
				end
				if d:GetAttribute("Detail") then
					d.BackgroundColor3 = if on then K.Amber else Site.Color.SteelDark
				else
					d.BackgroundColor3 = if on then K.AmberInk else K.Ink
				end
			end
		end
	end
end

local CAPTIONS = { Upgrades = "UPGRADE", Index = "INDEX", Worker = "CREW", Vehicles = "FLEET", Rewards = "REWARDS" }
local FLAG_NAMES = { Upgrades = "UPGRADES", Index = "BUILD INDEX", Worker = "WORKERS", Vehicles = "VEHICLES", Rewards = "REWARDS", Debug = "DEBUG" }

function HUDController.AddMenuButton(name: string, icon: string, _color: Color3, order: number, onClick: () -> ()): TextButton
	local b = UI.button({
		Name = name,
		Text = "",
		BackgroundColor3 = K.PlateRaised,
		Size = UDim2.fromOffset(RAIL_BUTTON, RAIL_BUTTON),
		LayoutOrder = order,
		Parent = menuButtons,
	}, onClick)
	b:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 14)
	local bar = UI.new("Frame", { Name = "OpenEdge", BackgroundTransparency = 1, Size = UDim2.fromScale(0, 0), Visible = false, Parent = b })
	local ic = Site.icon(b, icon, K.Ink, 30)
	ic.AnchorPoint = Vector2.new(0.5, 0.5)
	ic.Position = UDim2.new(0.5, 0, 0.5, -5)
	-- (Pass 21P) a short caption under every pictogram: what the button opens, readable without hovering
	local caption = UI.new("TextLabel", {
		Name = "Caption",
		Text = CAPTIONS[name] or string.upper(name),
		Font = TY.Heavy,
		TextSize = 11,
		TextColor3 = K.InkDim,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -3),
		Size = UDim2.new(1, -4, 0, 13),
		Parent = b,
	})
	UI.textStroke(caption, 1)
	-- hover label flag: slides out to the left of the rail (mouse only; never a permanent label)
	local flag = UI.new("TextLabel", {
		Name = "Flag",
		Text = FLAG_NAMES[name] or string.upper(name),
		Font = TY.Heavy,
		TextSize = TY.Body,
		TextColor3 = K.Ink,
		BackgroundColor3 = K.PlateDeep,
		BackgroundTransparency = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(0, -10, 0.5, 0),
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		Visible = false,
		ZIndex = 9,
		Parent = b,
	})
	UI.corner(flag, 15)
	UI.stroke(flag, K.Frame, 2)
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = flag })
	b.MouseEnter:Connect(function()
		if UserInputService.MouseEnabled and not UserInputService.TouchEnabled or UserInputService.MouseEnabled and UI.Mode ~= "phone" then
			flag.Visible = true
			flag.TextTransparency = 1
			flag.BackgroundTransparency = 1
			UI.tween(flag, UI.Anim.Fast, { TextTransparency = 0, BackgroundTransparency = 0 })
		end
		if not bar.Visible then
			b.BackgroundColor3 = K.PlateRaised:Lerp(K.Ink, 0.12)
		end
	end)
	b.MouseLeave:Connect(function()
		flag.Visible = false
		if not bar.Visible then
			b.BackgroundColor3 = K.PlateRaised
		end
	end)
	table.insert(menuMeta, { name = name, button = b, icon = ic, bar = bar, flag = flag })
	applyMode()
	return b
end

function HUDController.Start()
	-- Our standings replace the default player list (50 names would cover the screen)
	pcall(function()
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
	local g = UI.root("HUD", 1)

	-- top left: status strip (Coins, Server Luck, + rank chip added by LeaderboardController)
	local stats = UI.new("Frame", {
		Name = "StatsColumn",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(MARGIN, 8),
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = g,
	})
	UI.list(stats, 6, true).VerticalAlignment = Enum.VerticalAlignment.Center
	HUDController.StatsColumn = stats

	-- top left, under the strip: the project card + event strip dock here
	local top = UI.new("Frame", {
		Name = "TopStack",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(MARGIN, 44),
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = g,
	})
	UI.list(top, 6, false, Enum.HorizontalAlignment.Left)
	HUDController.TopStack = top

	-- top right, left of the rail: contribution leaderboard
	local right = UI.new("Frame", {
		Name = "RightStack",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -80, 0, 8),
		Size = UDim2.fromOffset(230, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = g,
	})
	UI.list(right, 6, false, Enum.HorizontalAlignment.Right)
	HUDController.RightStack = right

	local _, coinsLabel = HUDController.Pill(stats, "coin", Color3.fromRGB(255, 196, 46), 1)
	local _, luckLabel = HUDController.Pill(stats, "clover", K.Good, 2, "LUCK")

	-- COIN POPUP: "+24 Coins" a little below the centre of the screen. Gains that arrive close together are added into
	-- one popup (no spam from rapid deposit ticks); a new popup pushes older ones up so they stack instead of overlapping.
	local popups: { TextLabel } = {}
	local pending = 0
	local function showCoinPopup(amount: number)
		for _, old in popups do
			UI.tween(old, 0.18, { Position = old.Position - UDim2.fromOffset(0, 30) })
		end
		local l = UI.new("TextLabel", {
			Name = "CoinPopup",
			Text = "+" .. Format.Number(amount) .. " Coins",
			Font = TY.Heavy,
			TextSize = 32,
			TextColor3 = K.Amber,
			TextTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 104),
			Size = UDim2.fromOffset(260, 32),
			ZIndex = 6,
			Parent = g,
		})
		UI.textStroke(l, 2)
		local stroke = l:FindFirstChildOfClass("UIStroke")
		table.insert(popups, 1, l)
		if #popups > 3 then
			local last = table.remove(popups)
			if last then
				last:Destroy()
			end
		end
		UI.tween(l, 0.2, { TextTransparency = 0, Position = UDim2.new(0.5, 0, 0.5, 92) })
		Sound.Play("Coins", 0.06)
		task.delay(1.1, function()
			if not l.Parent then
				return
			end
			UI.tween(l, 0.5, { TextTransparency = 1, Position = l.Position - UDim2.fromOffset(0, 22) })
			if stroke then
				UI.tween(stroke, 0.5, { Transparency = 1 })
			end
			task.delay(0.5, function()
				local i = table.find(popups, l)
				if i then
					table.remove(popups, i)
				end
				l:Destroy()
			end)
		end)
	end
	local function queueCoins(amount: number)
		if pending == 0 then
			task.delay(0.35, function()
				local n = pending
				pending = 0
				if n > 0 then
					showCoinPopup(n)
				end
			end)
		end
		pending += amount
	end

	local shownCoins = 0
	local coinTween = 0
	local coinsLoaded = false
	local function setCoins()
		local c = player:GetAttribute("Coins") or 0
		if coinsLoaded and c > shownCoins then
			queueCoins(c - shownCoins)
		end
		if coinsLoaded and c > shownCoins then
			bounce(coinsLabel)
		end
		local wasLoaded = coinsLoaded
		coinsLoaded = coinsLoaded or player:GetAttribute("Coins") ~= nil
		local from = shownCoins
		shownCoins = c
		-- count toward the new value in ~0.3 s whatever the size of the reward (never slow for big payouts)
		coinTween += 1
		local my = coinTween
		if not wasLoaded or c <= from or c - from < 2 then
			coinsLabel.Text = Format.Number(c)
		else
			task.spawn(function()
				local t0 = os.clock()
				while os.clock() - t0 < 0.3 and coinTween == my do
					local k = (os.clock() - t0) / 0.3
					coinsLabel.Text = Format.Number(math.floor(from + (c - from) * (1 - (1 - k) ^ 2)))
					task.wait()
				end
				if coinTween == my then
					coinsLabel.Text = Format.Number(c)
				end
			end)
		end
	end
	player:GetAttributeChangedSignal("Coins"):Connect(setCoins)
	setCoins()

	local function setLuck()
		local v = math.floor(State.Get("ServerLuck") or 0)
		if luckLabel.Text ~= "" and luckLabel.Text ~= string.format("%d%%", v) then
			bounce(luckLabel)
		end
		luckLabel.Text = string.format("%d%%", v)
	end
	State.Changed("ServerLuck", setLuck)
	setLuck()

	-- RIGHT: navigation rail (one dark housing, flat cells, 2 px gaps read as separators)
	menuButtons = UI.new("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -MARGIN, 0.5, 0),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		Parent = g,
	})
	UI.padding(menuButtons, 4) -- room for the hover/press scale and badges
	UI.list(menuButtons, 8)
	HUDController.AddMenuButton("Upgrades", "hammer", T.Blue, 1, function()
		UI.togglePanel("Upgrades")
	end)
	HUDController.AddMenuButton("Index", "book", T.Blue, 2, function()
		UI.togglePanel("Index")
	end)
	HUDController.AddMenuButton("Worker", "hardhat", T.Blue, 3, function()
		UI.togglePanel("Worker")
	end)
	HUDController.AddMenuButton("Vehicles", "wheel", T.Blue, 4, function()
		UI.togglePanel("Vehicles")
	end)
	HUDController.AddMenuButton("Rewards", "trophy", T.Blue, 5, function()
		UI.togglePanel("Rewards")
	end)
	-- daily reward ready -> badge on Rewards (checked lazily; claiming clears it)
	task.spawn(function()
		while true do
			local d = State.Data
			local daily = d and d.Daily
			if daily then
				HUDController.SetBadge("Rewards", DailyConfig.DayNumber() > (daily.LastClaimDay or 0))
			end
			task.wait(4)
		end
	end)

	-- BOTTOM CENTRE: contextual cargo. Empty = a quiet chip; carrying = named plate + bar + DROP; full = + hazard edge.
	carryCard = UI.card({
		Name = "Carry",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -MARGIN),
		Size = UDim2.fromOffset(150, 40),
		ClipsDescendants = true,
		Parent = g,
	})
	local fullStrip = Site.hazard(carryCard, 5)
	fullStrip.Visible = false
	-- resource disc: the cargo's family colour behind its pictogram
	local iconHolder = UI.new("Frame", { BackgroundColor3 = K.PlateDeep, BackgroundTransparency = 0, Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(32, 32), Parent = carryCard })
	UI.corner(iconHolder, 16)
	UI.stroke(iconHolder, K.Frame, 2)
	local carryIcon = Site.icon(iconHolder, "crate", K.InkDim, 22)
	carryIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	carryIcon.Position = UDim2.fromScale(0.5, 0.5)
	local currentIcon = "crate"
	local resLabel = UI.new("TextLabel", {
		Font = TY.Heavy,
		TextSize = 20,
		TextColor3 = K.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(72, 8),
		Size = UDim2.new(1, -270, 0, 24),
		Parent = carryCard,
	})
	UI.textStroke(resLabel, 1.5)
	local carryText = UI.new("TextLabel", {
		Font = TY.Heavy,
		TextSize = 24,
		TextColor3 = K.Ink,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -118, 0, 7),
		Size = UDim2.fromOffset(100, 26),
		Parent = carryCard,
	})
	UI.textStroke(carryText, 1.5)
	local fullTag = UI.new("TextLabel", {
		Text = "FULL!",
		Font = TY.Heavy,
		TextSize = TY.Body,
		TextColor3 = K.AmberInk,
		BackgroundColor3 = K.Signal,
		BackgroundTransparency = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -118, 0, 38),
		Size = UDim2.fromOffset(56, 22),
		Visible = false,
		ZIndex = 4,
		Parent = carryCard,
	})
	UI.corner(fullTag, 11)
	UI.stroke(fullTag, K.Frame, 2)
	local barBg = UI.new("Frame", {
		BackgroundColor3 = K.PlateDeep,
		Position = UDim2.fromOffset(72, 40),
		Size = UDim2.new(1, -196, 0, 18),
		ClipsDescendants = true,
		Parent = carryCard,
	})
	UI.corner(barBg, 9)
	UI.stroke(barBg, K.Frame, 2)
	local segs = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = barBg })
	UI.list(segs, 0, true)
	for q = 1, 3 do
		UI.new("Frame", { BackgroundColor3 = K.PlateDeep, BackgroundTransparency = 0.3, Position = UDim2.fromScale(q / 4, 0), Size = UDim2.new(0, 2, 1, 0), ZIndex = 3, Parent = barBg })
	end
	local drop = Menu.button({ Text = "DROP", Kind = "primary", TextSize = TY.Heading, Parent = carryCard }, function()
		Net.Event("DropCarry"):FireServer(nil)
	end)
	drop.Font = TY.Heavy
	drop.TextSize = 22
	drop.AnchorPoint = Vector2.new(1, 0.5)
	drop.Position = UDim2.new(1, -10, 0.5, 0)
	drop.Size = UDim2.fromOffset(98, 50)

	local carrying = false
	local lastTotal = 0
	local function updateCarry()
		local total = player:GetAttribute("CarryTotal") or 0
		local cap = math.max(1, player:GetAttribute("CarryCap") or 1)
		carryText.Text = string.format("%s / %s", Format.Number(total), Format.Number(cap))
		for _, c in segs:GetChildren() do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		local mainId, mainN, kinds = nil, 0, 0
		for i, id in ResourceConfig.Order do
			local n = player:GetAttribute("Carry_" .. id) or 0
			if n > 0 then
				kinds += 1
				if n > mainN then
					mainId, mainN = id, n
				end
				UI.new("Frame", {
					BackgroundColor3 = UI.resourceColor(id),
					Size = UDim2.fromScale(math.min(1, n / cap), 1),
					LayoutOrder = i,
					Parent = segs,
				})
			end
		end
		local full = total >= cap
		local was = carrying
		carrying = total > 0
		local phone = UI.Mode == "phone"
		local menuOpen = UI.openName() ~= nil
		-- contextual: yields to reveal / completion and to open menus (never sits under a panel); phones hide it while empty
		carryCard.Visible = not UI.inMoment() and not menuOpen and not (phone and not carrying)
		fullTag.Visible = full
		fullStrip.Visible = full
		barBg.Size = UDim2.new(1, if full then -256 else -196, 0, 18) -- the FULL plate sits at the end of the bar row
		resLabel.Visible = carrying
		barBg.Visible = carrying
		drop.Visible = carrying
		if carrying and mainId then
			resLabel.Text = string.upper(ResourceConfig.RequirementLabel(mainId)) .. (if kinds > 1 then string.format("  +%d", kinds - 1) else "")
			resLabel.TextColor3 = UI.resourceColor(mainId):Lerp(K.Ink, 0.35)
		end
		-- empty: quiet chip (icon + count, faint); carrying: the full cargo plate (bigger disc, big count, thick bar, DROP)
		local w = if carrying then (if phone then 340 else 400) else 150
		local h = if carrying then 70 else 40
		local disc = if carrying then 54 else 32
		iconHolder.Size = UDim2.fromOffset(disc, disc)
		iconHolder.Position = if carrying then UDim2.fromOffset(8, 8) else UDim2.fromOffset(4, 4)
		iconHolder:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, disc / 2)
		local wantIcon = if carrying and mainId then UI.resourceIcon(mainId) else "crate"
		local tint = if carrying and mainId then UI.resourceColor(mainId) else K.InkDim
		if wantIcon ~= currentIcon or (carryIcon:GetAttribute("Px") or 22) ~= (if carrying then 38 else 22) then
			carryIcon:Destroy()
			carryIcon = Site.icon(iconHolder, wantIcon, K.Ink, if carrying then 38 else 22)
			carryIcon:SetAttribute("Px", if carrying then 38 else 22)
			carryIcon.AnchorPoint = Vector2.new(0.5, 0.5)
			carryIcon.Position = UDim2.fromScale(0.5, 0.5)
			currentIcon = wantIcon
		end
		iconHolder.BackgroundColor3 = if carrying then tint else K.PlateDeep
		for _, d in carryIcon:GetDescendants() do
			if d:IsA("Frame") and d.BackgroundTransparency == 0 and d.BackgroundColor3 ~= Site.Color.SteelDark then
				d.BackgroundColor3 = if carrying then K.Ink else K.InkDim
			end
		end
		carryText.AnchorPoint = if carrying then Vector2.new(1, 0) else Vector2.new(0, 0)
		carryText.Position = if carrying then UDim2.new(1, -118, 0, 7) else UDim2.fromOffset(42, 7)
		carryText.TextSize = if carrying then 24 else 20
		carryText.TextXAlignment = if carrying then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
		carryText.TextColor3 = if carrying then K.Ink else K.InkDim
		carryCard.BackgroundTransparency = if carrying then 0.02 else 0.3
		local cst = carryCard:FindFirstChildOfClass("UIStroke")
		if cst then
			cst.Color = if full then K.Signal elseif carrying then tint:Lerp(K.Frame, 0.5) else K.Frame
		end
		if was ~= carrying then
			UI.tween(carryCard, 0.18, { Size = UDim2.fromOffset(w, h) }, Enum.EasingStyle.Back)
		else
			carryCard.Size = UDim2.fromOffset(w, h)
		end
		if carrying and total > lastTotal then
			bounce(carryText)
		end
		lastTotal = total
	end
	refreshCarry = updateCarry
	for _, attr in { "CarryTotal", "CarryCap" } do
		player:GetAttributeChangedSignal(attr):Connect(updateCarry)
	end
	updateCarry()
	UI.PanelChanged:Connect(function()
		updateCarry()
	end)

	-- objective pill above the cargo
	objective = UI.card({
		Name = "Objective",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -94),
		Size = UDim2.fromOffset(0, 38),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0.12,
		Visible = false,
		Parent = g,
	})
	UI.padding(objective, 5)
	UI.list(objective, 8, true).VerticalAlignment = Enum.VerticalAlignment.Center
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(640, 44)
	sizeLimit.Parent = objective
	objectiveStep = UI.chip(objective, "", K.Amber, TY.Label, 1)
	objectiveStep.TextColor3 = K.AmberInk
	objectiveStep.Visible = false
	objectiveText = UI.new("TextLabel", {
		Font = TY.Bold,
		TextSize = TY.Body + 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 24),
		LayoutOrder = 2,
		Parent = objective,
	})

	-- presentation moments: cargo and the objective step aside for the reveal and the completion certificate
	UI.MomentChanged:Connect(function()
		updateCarry()
		if UI.inMoment() then
			objective.Visible = false
		end
	end)

	UI.ModeChanged:Connect(applyMode)
	applyMode()
	top:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeStacks)
	stats:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeStacks)
	game:GetService("GuiService"):GetPropertyChangedSignal("TopbarInset"):Connect(applyMode)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyMode)
	end
	UI.PanelChanged:Connect(paintMenuButtons)
	paintMenuButtons(UI.openName())
	UI.bindHotkeys()

	-- (Pass 21G) the spawn shops: walking onto a ShopMat opens its menu (attribute Panel: "Worker" = Builders Shop, "Vehicles" = Vehicle Shop).
	-- It opens once per visit: step off the mat before it can open again.
	task.spawn(function()
		local inside: { [BasePart]: boolean } = {}
		while true do
			task.wait(0.15)
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			for _, m in CollectionService:GetTagged("ShopMat") do
				if m:IsA("BasePart") then
					local on = false
					if hrp then
						local rel = m.CFrame:PointToObjectSpace(hrp.Position)
						on = math.abs(rel.X) <= m.Size.X / 2 + 0.5 and math.abs(rel.Z) <= m.Size.Z / 2 + 0.5 and math.abs(rel.Y) < 8
					end
					if on and not inside[m] then
						inside[m] = true
						local panel = m:GetAttribute("Panel")
						local cur = UI.openName()
						-- opens from nothing, or swaps from the other shop's menu (never replaces a menu the player opened themselves)
						if type(panel) == "string" and (cur == nil or ((cur == "Worker" or cur == "Vehicles") and cur ~= panel)) and not UI.inMoment() then
							UI.openPanel(panel)
						end
					elseif not on then
						inside[m] = nil
					end
				end
			end
		end
	end)
end

return HUDController
