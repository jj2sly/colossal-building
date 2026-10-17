--!strict
-- Build Index: a collection book with three tabs, generated entirely from configuration.
--   Builds        every enabled BuildConfig entry (discovered cards show stats; undiscovered
--                 cards show a "?" plus their rarity). New builds appear automatically.
--   Achievements  locked / unlocked / equipped states; equipping a title is instant (the UI
--                 updates before the server round-trip and is reconciled by the next sync).
--   Master Builder  locked explainer with live requirement progress.
-- L1/R1 on a gamepad switch tabs; the grid recomputes its column count from the panel width.
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local BuildConfig = require(Shared.Config.BuildConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local ModifierConfig = require(Shared.Config.ModifierConfig)
local AchievementConfig = require(Shared.Config.AchievementConfig)
local MasterBuilderConfig = require(Shared.Config.MasterBuilderConfig)
local IndexConfig = require(Shared.Config.IndexConfig)
local CosmeticConfig = require(Shared.Config.CosmeticConfig)
local TrainingConfig = require(Shared.Config.TrainingConfig)
local VehicleConfig = require(Shared.Config.VehicleConfig)
local Format = require(Shared.Util.Format)
local Lib = script.Parent.Parent.ClientLib
local UI = require(Lib.UI)
local Menu = require(Lib.Menu)
local BuildPreview = require(Lib.BuildPreview)
local State = require(Lib.State)
local Notify = require(script.Parent.NotifyController)

local IndexPanel = {}
local S = Menu.S
local player = Players.LocalPlayer

local panel: any
local tabs: any
local content: Frame -- holds the active tab's contents (rebuilt on tab switch / data change)
local currentTab = "Builds"
local previewsCleared = false
local lastSig = "" -- data signature of the last redraw from a sync (see IndexPanel.Start)

local effectTweens: { Tween } = {}

local function clear()
	BuildPreview.clear()
	for _, tw in effectTweens do
		tw:Cancel()
	end
	table.clear(effectTweens)
	for _, c in content:GetChildren() do
		c:Destroy()
	end
end

local function rarityOrder(): { [string]: number }
	local o = {}
	for id, r in RarityConfig.Tiers do
		o[id] = r.Order
	end
	return o
end

local function dataOrEmpty(): any
	return State.Data or { BuildIndex = {}, Stats = {}, Upgrades = {}, Achievements = {}, MasterBuilder = { Rank = 0 }, EquippedTitle = "" }
end

------------------------------------------------------------------ builds
local function sheen(thumb: Frame, color: Color3)
	-- one slow light sweep across a discovered Legendary / Mythic plan (same rule as UI.rarityFrame: no pulsing, no rainbow)
	thumb.ClipsDescendants = true
	local bar = UI.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.85, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(-0.3, 0.5), Size = UDim2.new(0.16, 0, 2, 0), Rotation = 18, ZIndex = 5, Parent = thumb })
	local tw = TweenService:Create(bar, TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 2.6), { Position = UDim2.fromScale(1.3, 0.5) })
	tw:Play()
	table.insert(effectTweens, tw)
	local _ = color
end

-- DISCOVERY TREATMENT: a card/record that was not on file when the panel last drew gets a brief "FILED" / "RECORDED" stamp and an edge
-- flash. `seen` is seeded from the first data sync, so existing entries never replay it.
local seen: { [string]: boolean } = {}
local seeded = false
local function fileStamp(card: Frame, key: string, color: Color3, word: string)
	if seen[key] then
		return
	end
	seen[key] = true
	if not seeded then
		return
	end
	local st = card:FindFirstChildOfClass("UIStroke")
	if st then
		st.Color = color
		UI.tween(st, 1, { Color = S.Border })
	end
	local tag = UI.new("TextLabel", { Text = word, Font = S.FontHeavy, TextSize = Menu.size("Small"), TextColor3 = color, TextTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 6), Size = UDim2.fromOffset(90, 16), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 8, Parent = card })
	UI.tween(tag, UI.Anim.Fast, { TextTransparency = 0 })
	task.delay(1.8, function()
		UI.tween(tag, UI.Anim.Slow, { TextTransparency = 1 })
		task.delay(UI.Anim.Slow + 0.05, function()
			tag:Destroy()
		end)
	end)
end

-- a build card: blueprint thumbnail (live preview / silhouette), rarity plate, name, and a few real stats
local function planCard(grid: Instance, def: any, index: number, e: any)
	local discovered = e ~= nil and e.Discovered == true
	local r = RarityConfig.Get(def.Rarity)
	local card = Menu.surface(grid, { Name = "Build_" .. def.Id, LayoutOrder = index }, nil)
	if discovered then
		fileStamp(card, "B_" .. def.Id, r.Color, "FILED")
	end
	-- rarity frames the whole card once filed (the plate below says it in words and pips as well)
	local cst = card:FindFirstChildOfClass("UIStroke")
	if cst and discovered then
		cst.Color = r.Color:Lerp(S.Border, 0.25)
	elseif not discovered then
		card.BackgroundColor3 = S.Surface:Lerp(S.Header, 0.35)
	end
	local thumbH = if discovered then 104 else 142
	local thumb = UI.new("Frame", { BackgroundColor3 = if discovered then S.Blueprint else S.Header, BackgroundTransparency = 0, Position = UDim2.fromOffset(8, 10), Size = UDim2.new(1, -16, 0, thumbH), Parent = card })
	UI.new("UIStroke", { Color = if discovered then S.BlueprintLine else S.Line, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = thumb })
	UI.new("UICorner", { CornerRadius = UDim.new(0, 10), Parent = thumb })
	UI.new("TextLabel", { Text = string.format("PLAN %02d", index), Font = S.FontHeavy, TextSize = Menu.size("Small"), TextColor3 = if discovered then S.BlueprintLine else S.Faint, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(6, 2), Size = UDim2.fromOffset(80, 18), ZIndex = 3, Parent = thumb })
	local vp = BuildPreview.create(thumb, def.Id, not discovered)
	if not vp then
		UI.new("TextLabel", { Text = if discovered then "" else "?", Font = S.FontHeavy, TextSize = 34, TextColor3 = S.Faint, Size = UDim2.fromScale(1, 1), Parent = thumb })
	elseif not discovered then
		UI.new("TextLabel", { Text = "?", Font = S.FontHeavy, TextSize = 26, TextColor3 = S.BlueprintLine, TextTransparency = 0.4, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 1, -2), Size = UDim2.fromOffset(24, 28), ZIndex = 4, Parent = thumb })
	end
	if discovered and r.IndexEffect then
		local stroke = thumb:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = r.Color
			stroke.Thickness = 2
		end
		thumb.BackgroundColor3 = r.Color:Lerp(S.Blueprint, 0.84)
		sheen(thumb, r.Color)
	end
	local info = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, thumbH + 16), Size = UDim2.new(1, -20, 1, -(thumbH + 20)), Parent = card })
	UI.list(info, 3)
	Menu.rarityTag(info, r.DisplayName, r.Color, 1)
	local name = Menu.label(info, if discovered then def.DisplayName else "Unrecorded plan", "H2", if discovered then S.Text else S.Dim, true)
	name.Font = S.FontHeavy
	name.LayoutOrder = 2
	if discovered then
		-- completions read first (big, amber); best share + fastest time are one small line
		local l1 = Menu.label(info, string.format("BUILT x%d", e.TimesCompleted or 0), "Body", S.Accent, true)
		l1.Font = S.FontHeavy
		l1.LayoutOrder = 3
		local l2 = Menu.label(info, string.format("Best %.1f%%   ·   %s", e.BestContributionPct or 0, if e.FastestCompletion then Format.Time(e.FastestCompletion) else "-"), "Small", S.Dim, false)
		l2.LayoutOrder = 4
		-- VARIANTS: Normal + every modifier this build can roll; lit squares are completed
		local variants = { "Normal" }
		for _, id in ModifierConfig.Order do
			if table.find(def.EligibleModifiers, id) then
				table.insert(variants, id)
			end
		end
		local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 5, Parent = info })
		local rl = UI.list(row, 3, true)
		rl.VerticalAlignment = Enum.VerticalAlignment.Center
		local doneCount = 0
		for i, v in variants do
			local have = e.Modifiers and e.Modifiers[v] == true
			if have then
				doneCount += 1
			end
			local sq = UI.new("Frame", { BackgroundColor3 = if have then S.Accent else S.Line, BackgroundTransparency = 0, Size = UDim2.fromOffset(10, 10), LayoutOrder = i, Parent = row })
			UI.new("UICorner", { CornerRadius = UDim.new(0, 5), Parent = sq })
		end
		UI.new("TextLabel", { Text = string.format("  %d/%d variants", doneCount, #variants), Font = S.FontBold, TextSize = Menu.size("Small"), TextColor3 = if doneCount == #variants then S.Good else S.Dim, TextXAlignment = Enum.TextXAlignment.Left, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 18), LayoutOrder = 99, Parent = row })
	end
end

local function drawBuilds()
	local d = dataOrEmpty()
	UI.list(content, 12) -- summary, then the plan grid
	local list = BuildConfig.IndexOrder(rarityOrder())
	local found = 0
	for _, def in list do
		local e = d.BuildIndex[def.Id]
		if e and e.Discovered then
			found += 1
		end
	end

	-- SUMMARY: DISCOVERED x / 40 with a thick bar, then the six rarity collections in a compact grid
	local sum = Menu.surface(content, { Name = "Summary", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 })
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 12), Parent = sum })
	UI.list(sum, 10)
	local head = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 1, Parent = sum })
	local hl = UI.list(head, 10, true)
	hl.VerticalAlignment = Enum.VerticalAlignment.Center
	UI.new("TextLabel", { Text = string.format("%d / %d", found, #list), Font = S.FontHeavy, TextSize = Menu.size("H1") + 4, TextXAlignment = Enum.TextXAlignment.Left, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 30), LayoutOrder = 1, Parent = head })
	UI.new("TextLabel", { Text = "BLUEPRINTS DISCOVERED", Font = S.FontHeavy, TextSize = Menu.size("Small"), TextColor3 = S.Dim, TextXAlignment = Enum.TextXAlignment.Left, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 30), LayoutOrder = 2, Parent = head })
	local holder = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 12), LayoutOrder = 2, Parent = sum })
	local _, set = Menu.bar(holder, 12, S.Accent)
	set(found / math.max(1, #list), S.Accent)

	local builds = {}
	for _, b in BuildConfig.Builds do
		-- the NORMAL collection is the canonical 40-build roster: Master Projects (Orbital Station) live in the Master Archive
		if b.Enabled and b.Season == nil and not b.MasterProject then
			table.insert(builds, { Id = b.Id, Rarity = b.Rarity, EligibleModifiers = b.EligibleModifiers, Name = b.DisplayName })
		end
	end
	local rg = Menu.grid(sum, { Min = 176, Height = 66, Max = 3, Gap = 8, Order = 3 })
	local order = 0
	for _, m in IndexConfig.Milestones do
		if m.Kind == "AllRarity" and m.Rarity then
			order += 1
			local done, have, need = IndexConfig.Progress(m, d, builds)
			local r = RarityConfig.Get(m.Rarity)
			local perk = IndexConfig.RarityBonuses[m.Id]
			local cell = Menu.well(rg, { Name = "Coll_" .. m.Rarity, LayoutOrder = order })
			UI.new("Frame", { BackgroundColor3 = r.Color, BackgroundTransparency = 0, Size = UDim2.new(0, 3, 1, 0), Parent = cell })
			UI.new("TextLabel", { Text = r.DisplayName, Font = S.FontHeavy, TextSize = Menu.size("Small"), TextColor3 = r.Color, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(12, 4), Size = UDim2.new(0.6, -12, 0, 18), Parent = cell })
			UI.new("TextLabel", { Text = string.format("%d/%d", have, need), Font = S.FontHeavy, TextSize = Menu.size("H2"), TextColor3 = if done then S.Good else S.Text, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 2), Size = UDim2.fromOffset(60, 22), Parent = cell })
			local bh = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -20, 0, 6), Parent = cell })
			local _b, setb = Menu.bar(bh, 6, r.Color)
			setb(have / math.max(1, need), r.Color)
			UI.new("TextLabel", {
				Text = if done then "BONUS ACTIVE" else (if perk then perk.Text else ""),
				Font = S.Font,
				TextSize = Menu.size("Small"),
				TextColor3 = if done then S.Good else S.Dim,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(12, 40),
				Size = UDim2.new(1, -18, 0, 20),
				Parent = cell,
			})
		end
	end

	-- BLUEPRINT CARDS
	Menu.section(content, "Blueprints", 2, "complete a build with your crew to file its plan").LayoutOrder = 2
	local grid = Menu.grid(content, { Min = 176, Height = 244, Max = 4, Gap = 12, Order = 3 })
	for i, def in list do
		planCard(grid, def, i, d.BuildIndex[def.Id])
	end
end

------------------------------------------------------------------ achievements
local function drawAchievements()
	local d = dataOrEmpty()
	local unlocked = d.Achievements or {}
	local equipped = d.EquippedTitle or ""
	local ordered = AchievementConfig.Ordered()
	local count = 0
	for _, a in ordered do
		if unlocked[a.Id] then
			count += 1
		end
	end
	UI.list(content, 10)
	-- header strip: UNLOCKED n / N on the left, the equipped title on the right (no explanatory prose)
	local head = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 1, Parent = content })
	local hl = UI.list(head, 10, true)
	hl.VerticalAlignment = Enum.VerticalAlignment.Center
	UI.new("TextLabel", { Text = string.format("%d / %d", count, #ordered), Font = S.FontHeavy, TextSize = Menu.size("H1") + 4, TextXAlignment = Enum.TextXAlignment.Left, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 34), LayoutOrder = 1, Parent = head })
	UI.new("TextLabel", { Text = "ACHIEVEMENTS UNLOCKED", Font = S.FontHeavy, TextSize = Menu.size("Small"), TextColor3 = S.Dim, TextXAlignment = Enum.TextXAlignment.Left, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 34), LayoutOrder = 2, Parent = head })
	local titleChip = Menu.tag(head, if equipped ~= "" then "TITLE  " .. string.upper(equipped) else "NO TITLE", if equipped ~= "" then S.Accent else S.Header, if equipped ~= "" then S.AccentText else S.Faint, 3)
	titleChip.Font = S.FontHeavy
	local list = UI.new("Frame", { Name = "AchList", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = content })
	UI.list(list, 8)
	local rowH = if Menu.isTouch() then 76 else 66
	for i, a in ordered do
		local done = unlocked[a.Id] == true
		local isEquipped = done and equipped == a.Title
		local row = Menu.surface(list, { Name = "Ach_" .. a.Id, Size = UDim2.new(1, 0, 0, rowH), LayoutOrder = i }, if isEquipped then S.Accent else nil)
		Menu.iconWell(row, "trophy", if done then S.Accent else S.Faint, 44).Position = UDim2.new(0, 12, 0.5, -22)
		local btnW = if UI.Mode == "phone" then 104 else 124
		local mid = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(66, 0), Size = UDim2.new(1, -(66 + btnW + 22), 1, 0), Parent = row })
		local top = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 7), Size = UDim2.new(1, 0, 0, 24), Parent = mid })
		local tl = UI.list(top, 8, true)
		tl.VerticalAlignment = Enum.VerticalAlignment.Center
		UI.new("TextLabel", { Text = a.DisplayName, Font = S.FontHeavy, TextSize = Menu.size("Body"), TextColor3 = if done then S.Text else S.Dim, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 24), LayoutOrder = 1, Parent = top })
		if isEquipped then
			Menu.stateTag(top, "EQUIPPED", 2)
		elseif done then
			Menu.stateTag(top, "UNLOCKED", 2)
		end
		UI.new("TextLabel", { Text = a.Description, Font = S.Font, TextSize = Menu.size("Small"), TextColor3 = S.Dim, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(0, 31), Size = UDim2.new(1, 0, 0, 18), Parent = mid })
		if done then
			Menu.button({
				Name = "Equip_" .. a.Id,
				Text = if isEquipped then "UNEQUIP" else "EQUIP",
				Kind = if isEquipped then "secondary" else "primary",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(btnW, Menu.buttonHeight()),
				Parent = row,
			}, function()
				-- instant: change local state and redraw now; the server confirms via the next sync
				local data = State.Data
				if data then
					data.EquippedTitle = if isEquipped then "" else a.Title
				end
				if currentTab == "Achievements" then
					Menu.keepFocus(panel.Frame, function()
						clear()
						drawAchievements()
					end)
				end
				Net.Event("EquipTitle"):FireServer(if isEquipped then "" else a.Title)
			end)
		else
			local progress = math.min(a.Target, AchievementConfig.StatValue(d.Stats or {}, a.Stat))
			local holder = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 53), Size = UDim2.new(1, 0, 0, 6), Parent = mid })
			local _, set = Menu.bar(holder, 6, S.Accent)
			set(progress / math.max(1, a.Target), S.Faint)
			UI.new("TextLabel", { Text = string.format("%s / %s", Format.Short(progress), Format.Short(a.Target)), Font = S.FontHeavy, TextSize = Menu.size("Small"), TextColor3 = S.Dim, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(btnW - 8, 22), TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
		end
	end
end

------------------------------------------------------------------ master builder
local function bonusText(rank: number): string
	local b = MasterBuilderConfig.PerRankBonus
	return string.format("+%d%% carry   +%d%% gather   +%d Luck   +%d%% Worker", math.floor(rank * b.CarryEffectiveness * 100 + 0.5), math.floor(rank * b.GatherEffectiveness * 100 + 0.5), rank * b.PersonalLuck, math.floor(rank * b.WorkerEffectiveness * 100 + 0.5))
end

-- Full-panel overlay used for the confirmation screen and the prestige moment.
local overlay: Frame? = nil
local function closeOverlay()
	if overlay then
		overlay:Destroy()
		overlay = nil
	end
end
local function makeOverlay(): Frame
	closeOverlay()
	local o = UI.new("Frame", { Name = "MBOverlay", BackgroundColor3 = Color3.fromRGB(8, 10, 14), BackgroundTransparency = 0.03, Size = UDim2.fromScale(1, 1), ZIndex = 50, Active = true, Parent = panel.Frame })
	overlay = o
	return o
end

local function listBlock(parent: Instance, order: number, heading: string, lines: { string }, color: Color3)
	local f = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, ZIndex = 51, Parent = parent })
	UI.list(f, 2)
	local h = Menu.label(f, heading, "Small", color, true)
	h.ZIndex = 51
	for i, line in lines do
		local l = Menu.label(f, "  " .. line, "Small", S.Text)
		l.LayoutOrder = i
		l.ZIndex = 51
	end
end

-- The prestige moment after a successful rank-up (short: tween in, hold, tap or wait to dismiss).
local function playPrestige(payload: any)
	local o = makeOverlay()
	local box = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.9, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 51, Parent = o })
	local lay = UI.list(box, 8)
	lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local function centered(text: string, size: number, color: Color3, order: number, font: Enum.Font): TextLabel
		return UI.new("TextLabel", { Text = text, Font = font, TextSize = size, TextColor3 = color, TextWrapped = true, Size = UDim2.new(1, 0, 0, size + 8), TextTransparency = 1, LayoutOrder = order, ZIndex = 52, Parent = box })
	end
	local t1 = centered("RANK UP", 20, S.Accent, 1, S.FontBold)
	local t2 = centered(string.upper(payload.Title), 34, S.Text, 2, S.FontHeavy)
	local rewardLabels = { t1, t2 }
	for i, line in payload.Rewards do
		table.insert(rewardLabels, centered(line, 16, S.Dim, 2 + i, S.Font))
	end
	table.insert(rewardLabels, centered("Tap to continue", 14, S.Faint, 20, S.Font))
	for i, l in rewardLabels do
		TweenService:Create(l, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
		task.wait(if i <= 2 then 0.35 else 0.15)
	end
	local btn = UI.new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 60, Parent = o })
	btn.Activated:Connect(closeOverlay)
	task.delay(6, function()
		if overlay == o then
			closeOverlay()
		end
	end)
end

local function confirmAdvance(nextRankIndex: number)
	local rank = MasterBuilderConfig.Ranks[nextRankIndex]
	local o = makeOverlay()
	local card = Menu.surface(o, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.9, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	card.ZIndex = 51
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), Parent = card })
	UI.list(card, 8)
	local h = Menu.label(card, "ADVANCE TO " .. string.upper(rank.Title) .. "?", "H2", S.Text, true)
	h.LayoutOrder = 1
	h.ZIndex = 51
	local m = MasterBuilderConfig.Milestones[nextRankIndex]
	-- concrete numbers from YOUR data, so nobody prestiges without seeing exactly what changes
	local d = dataOrEmpty()
	local upgradeLevels = 0
	for _, lv in d.Upgrades or {} do
		upgradeLevels += lv
	end
	local permanent = MasterBuilderConfig.Permanents(nextRankIndex)
	local lostVehicles, keptVehicles = {}, {}
	for id in (d.Vehicles and d.Vehicles.Owned) or {} do
		local name = (VehicleConfig.Vehicles[id] and VehicleConfig.Vehicles[id].DisplayName) or id
		table.insert(if table.find(permanent, id) then keptVehicles else lostVehicles, name)
	end
	local tr = d.Training or {}
	local sNow, vNow = TrainingConfig.Level("Strength", tr.Strength or 0), TrainingConfig.Level("Speed", tr.Speed or 0)
	local keep = MasterBuilderConfig.TrainingRetention
	listBlock(card, 2, "YOU LOSE", {
		string.format("All %s Coins", Format.Short(math.floor(d.Coins or 0))),
		string.format("All Coin upgrades (%d levels)", upgradeLevels),
		if #lostVehicles > 0 then "Vehicles: " .. table.concat(lostVehicles, ", ") else "Normal vehicles (you own none right now)",
		"Your Worker crew and tier (Worker Tokens are kept)",
		string.format("Half your training: Strength %d -> %d, Speed %d -> %d", sNow, math.floor(sNow * keep), vNow, math.floor(vNow * keep)),
	}, S.Bad)
	local keepLines = { "Build Index, variants and collection bonuses", "Achievements, titles and cosmetics", "Master Builder rank, permanent unlocks and Worker tier access", "Worker Tokens" }
	local mbNames = {}
	for _, id in permanent do
		local mv = MasterBuilderConfig.MasterVehicles[id]
		table.insert(mbNames, if mv then mv.DisplayName else id)
	end
	if #keptVehicles > 0 then
		table.insert(mbNames, table.concat(keptVehicles, ", "))
	end
	if #mbNames > 0 then
		table.insert(keepLines, "Permanent vehicles: " .. table.concat(mbNames, ", "))
	end
	table.insert(keepLines, "Master Project history, Forgotten Archive and secret-resource access")
	listBlock(card, 3, "YOU KEEP", keepLines, S.Good)
	listBlock(card, 4, "YOU EARN", { if m then m.Text else "Permanent bonus", bonusText(nextRankIndex), string.format("+%d%% Strength/Speed training XP (permanent)", math.floor(MasterBuilderConfig.TrainingXPBonus(nextRankIndex) * 100 + 0.5)) }, S.Accent)
	local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Menu.buttonHeight()), LayoutOrder = 5, ZIndex = 51, Parent = card })
	UI.list(row, 8, true)
	local cancel = Menu.button({ Text = "CANCEL", Kind = "secondary", Size = UDim2.new(0.4, -4, 1, 0), LayoutOrder = 1, ZIndex = 52, Parent = row }, closeOverlay)
	local busy = false
	local armed = false
	local confirm: TextButton
	confirm = Menu.button({ Text = "RANK UP AND RESET", Kind = "danger", Size = UDim2.new(0.6, -4, 1, 0), LayoutOrder = 2, ZIndex = 52, Parent = row }, function()
		if busy then
			return
		end
		-- two taps: the first one arms the button for a few seconds so a stray click can never prestige
		if not armed then
			armed = true
			Menu.setButton(confirm, { Text = "TAP AGAIN TO CONFIRM" })
			task.delay(4, function()
				if armed and not busy and confirm.Parent then
					armed = false
					Menu.setButton(confirm, { Text = "RANK UP AND RESET" })
				end
			end)
			return
		end
		busy = true
		local ok, res = Net.Function("MasterBuilderAdvance"):InvokeServer()
		if ok then
			task.spawn(playPrestige, res)
		else
			closeOverlay()
			Notify.Show("Error", tostring(res))
		end
	end)
	local _ = { cancel, confirm }
end

local function drawMasterBuilder()
	local d = dataOrEmpty()
	local mb = d.MasterBuilder or { Rank = 0 }
	local rankNow = mb.Rank or 0
	UI.list(content, 12)
	local B = MasterBuilderConfig.PerRankBonus

	-- CURRENT RANK + permanent bonuses as four stat cells
	local head = Menu.surface(content, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 })
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 12), Parent = head })
	UI.list(head, 10)
	local hrow = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 1, Parent = head })
	local hl = UI.list(hrow, 10, true)
	hl.VerticalAlignment = Enum.VerticalAlignment.Center
	UI.new("TextLabel", { Text = if rankNow > 0 then string.upper(MasterBuilderConfig.Ranks[rankNow].Title) else "NOT RANKED YET", Font = S.FontHeavy, TextSize = Menu.size("H1") + 2, TextColor3 = if rankNow > 0 then S.Accent else S.Dim, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 30), LayoutOrder = 1, Parent = hrow })
	UI.new("TextLabel", { Text = "MASTER BUILDER RANK", Font = S.FontHeavy, TextSize = Menu.size("Small"), TextColor3 = S.Dim, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 30), LayoutOrder = 2, Parent = hrow })
	local bg = Menu.grid(head, { Min = 124, Height = 50, Max = 4, Gap = 8, Order = 2 })
	Menu.stat(bg, "Carry", string.format("+%d%%", math.floor(rankNow * B.CarryEffectiveness * 100 + 0.5)), 1)
	Menu.stat(bg, "Gather", string.format("+%d%%", math.floor(rankNow * B.GatherEffectiveness * 100 + 0.5)), 2)
	Menu.stat(bg, "Luck", string.format("+%d", rankNow * B.PersonalLuck), 3)
	Menu.stat(bg, "Worker", string.format("+%d%%", math.floor(rankNow * B.WorkerEffectiveness * 100 + 0.5)), 4)

	-- NEXT RANK
	local nextIndex = rankNow + 1
	local rank = MasterBuilderConfig.Ranks[nextIndex]
	if not rank then
		local c = Menu.surface(content, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 })
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), Parent = c })
		Menu.label(c, "Highest Master Builder rank reached.", "Body", S.Good, true)
	else
		local card = Menu.surface(content, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 })
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 12), Parent = card })
		UI.list(card, 8)
		Menu.section(card, "Next rank  -  " .. rank.Title, 0)
		local function req(order: number, label: string, have: number, need: number)
			local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = order, Parent = card })
			UI.new("TextLabel", { Text = label, Font = S.Font, TextSize = Menu.size("Small"), TextColor3 = if have >= need then S.Good else S.Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(0.62, 0, 0, 18), Parent = row })
			UI.new("TextLabel", { Text = string.format("%s / %s%s", Format.Short(have), Format.Short(need), if have >= need then "  DONE" else ""), Font = S.FontHeavy, TextSize = Menu.size("Small"), TextColor3 = if have >= need then S.Good else S.Text, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(1, 0, 0, 18), Parent = row })
			local holder = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 8), Parent = row })
			local _, set = Menu.bar(holder, 8, S.Accent)
			set(have / math.max(1, need), if have >= need then S.Good else S.Accent)
		end
		local allDone = true
		for k, row in MasterBuilderConfig.Requirements(rank, d) do
			req(k, row.Label, row.Have, row.Need)
			allDone = allDone and row.Done
		end
		local cooldown = MasterBuilderConfig.CooldownLeft(d)
		local m = MasterBuilderConfig.Milestones[nextIndex]
		local rw = Menu.label(card, "REWARD  " .. (if m then m.Text else "permanent bonus"), "Small", S.Accent, true)
		rw.LayoutOrder = 50
		rw.TextWrapped = true
		rw.TextTruncate = Enum.TextTruncate.None
		rw.AutomaticSize = Enum.AutomaticSize.Y
		local can = allDone and cooldown <= 0 and MasterBuilderConfig.Enabled
		local label = if can then "RANK UP" elseif not allDone then "REQUIREMENTS NOT MET" elseif cooldown > 0 then string.format("READY IN %dh", math.ceil(cooldown / 3600)) else "UNAVAILABLE"
		Menu.button({ Text = label, Kind = if can then "primary" else "secondary", Enabled = can, Size = UDim2.new(1, 0, 0, Menu.buttonHeight()), LayoutOrder = 51, Parent = card }, function()
			confirmAdvance(nextIndex)
		end)
	end

	-- EVERY RANK: one compact line each (number plate + what it permanently gives)
	local all = Menu.surface(content, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3 })
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), Parent = all })
	UI.list(all, 6)
	Menu.section(all, "All ranks", 0)
	for i, r in MasterBuilderConfig.Ranks do
		local m = MasterBuilderConfig.Milestones[i]
		local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = i, Parent = all })
		local rl2 = UI.list(row, 10, true)
		rl2.VerticalAlignment = Enum.VerticalAlignment.Top
		local tag = Menu.tag(row, tostring(i), if i <= rankNow then S.Good else S.Header, if i <= rankNow then S.GoodText else S.Dim, 1)
		tag.Font = S.FontHeavy
		tag.AutomaticSize = Enum.AutomaticSize.None
		tag.Size = UDim2.fromOffset(28, 24)
		tag.TextXAlignment = Enum.TextXAlignment.Center
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 0), PaddingRight = UDim.new(0, 0), Parent = tag })
		local t = UI.new("TextLabel", {
			Text = if m then m.Text else r.Title,
			Font = if i == rankNow + 1 then S.FontBold else S.Font,
			TextSize = Menu.size("Small"),
			TextColor3 = if i <= rankNow then S.Good elseif i == rankNow + 1 then S.Text else S.Dim,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			Size = UDim2.new(1, -40, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Parent = row,
		})
		local _ = t
	end
end

-- MASTER ARCHIVE: Master Projects live apart from the 40 normal builds and are NOT a seventh rarity. One project file per Master
-- Project: unrecorded silhouette until discovered, concise activation conditions, a rare-reward line and a state badge.
local MASTER_COLOR = Color3.fromRGB(120, 215, 255)
local function drawMasterArchive()
	local d = dataOrEmpty()
	UI.list(content, 12)
	local archive = d.MasterArchive or {}
	local order = 0
	for _, def in BuildConfig.Builds do
		if def.Enabled and def.MasterProject then
			order += 1
			local rec = archive[def.Id]
			local found = rec ~= nil and rec.Discovered == true
			local card = Menu.surface(content, { Name = "Project_" .. def.Id, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order }, MASTER_COLOR)
			-- the surface's own stripe must not take part in the list layout, so the content lives in an inner frame
			local inner = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = card })
			UI.new("UIPadding", { PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 14), Parent = inner })
			UI.list(inner, 10)
			-- identity line: MASTER PROJECT (never a rarity) + state badge
			local top = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 1, Parent = inner })
			UI.new("TextLabel", { Text = "MASTER PROJECT", Font = S.FontHeavy, TextSize = Menu.size("Small"), TextColor3 = MASTER_COLOR, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.6, 0, 1, 0), Parent = top })
			local tag = Menu.stateTag(top, if found then "DONE" else "LOCKED", nil, if found then "RECORDED" else "UNRECORDED")
			tag.AnchorPoint = Vector2.new(1, 0.5)
			tag.Position = UDim2.fromScale(1, 0.5)
			UI.new("TextLabel", { Text = string.upper(if found then def.DisplayName else "Unrecorded project"), Font = S.FontHeavy, TextSize = Menu.size("H1") + 2, TextColor3 = if found then S.Text else S.Dim, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 2, Parent = inner })
			-- large blueprint silhouette
			local thumb = UI.new("Frame", { BackgroundColor3 = S.Blueprint, Size = UDim2.new(1, 0, 0, 160), LayoutOrder = 3, Parent = inner })
			UI.new("UICorner", { CornerRadius = UDim.new(0, 2), Parent = thumb })
			UI.new("UIStroke", { Color = S.BlueprintLine, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = thumb })
			UI.new("TextLabel", { Text = "MASTER FILE", Font = S.FontHeavy, TextSize = Menu.size("Small"), TextColor3 = S.BlueprintLine, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(8, 4), Size = UDim2.fromOffset(120, 18), ZIndex = 3, Parent = thumb })
			local vp = BuildPreview.create(thumb, def.Id, not found)
			if not vp then
				UI.new("TextLabel", { Text = "?", Font = S.FontHeavy, TextSize = 44, TextColor3 = S.Faint, Size = UDim2.fromScale(1, 1), Parent = thumb })
			end
			if found then
				-- recorded: real stats from your archive
				local sg = Menu.grid(inner, { Min = 140, Height = 50, Max = 3, Gap = 8, Order = 4 })
				local secs = rec.FastestCompletion
				Menu.stat(sg, "Completed", tostring(rec.TimesCompleted or 0), 1)
				Menu.stat(sg, "Best share", string.format("%.1f%%", rec.BestContributionPct or 0), 2)
				Menu.stat(sg, "Fastest", if secs then Format.Time(secs) else "-", 3)
			else
				-- unrecorded: what it takes (concise, no hard numbers)
				Menu.section(inner, "Starts when the server is ready", 4)
				local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 5, Parent = inner })
				UI.list(row, 6, true).Wraps = true
				for i, text in { "HIGH SERVER LUCK", "MANY BUILDS FINISHED", "MASTER BUILDERS PRESENT" } do
					local c = Menu.tag(row, text, S.Header, S.Text, i)
					c.Font = S.FontHeavy
				end
			end
			-- rare reward line
			local owns = d.Cosmetics and d.Cosmetics.Trail and d.Cosmetics.Trail.OrbitalTrail
			local rrow = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 6, Parent = inner })
			UI.new("TextLabel", { Text = "RARE REWARD   " .. CosmeticConfig.Name("Trail", "OrbitalTrail"), Font = S.FontBold, TextSize = Menu.size("Body"), TextColor3 = S.Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(0.7, 0, 1, 0), Parent = rrow })
			local rt = Menu.stateTag(rrow, if owns then "OWNED" else "LOCKED", nil, if owns then "FOUND" else "NOT FOUND")
			rt.AnchorPoint = Vector2.new(1, 0.5)
			rt.Position = UDim2.fromScale(1, 0.5)
		end
	end
	if order == 0 then
		Menu.label(content, "No Master Projects yet.", "Body", S.Dim)
	end
end

-- FORGOTTEN ARCHIVE: only YOUR OWN discoveries are ever here (the server sends nothing else). The tab itself does not exist until the
-- player holds a first record: no tab, count, sealed slot, silhouette or "???" placeholder. Entries are generic records (no per-build code).
local FORGOTTEN_COLOR = RarityConfig.Get("Forgotten").Color
local function drawForgotten()
	local d = dataOrEmpty()
	UI.list(content, 12)
	local records = {}
	for _, rec in d.ForgottenArchive or {} do
		if rec.Discovered then
			table.insert(records, rec)
		end
	end
	table.sort(records, function(a, b)
		return tostring(a.Tier) < tostring(b.Tier)
	end)
	for i, rec in records do
		local card = Menu.surface(content, { Name = "Forgotten_" .. tostring(rec.Id), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = i }, FORGOTTEN_COLOR)
		fileStamp(card, "F_" .. tostring(rec.Id), FORGOTTEN_COLOR, "RECORDED")
		local inner = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = card })
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 14), Parent = inner })
		UI.list(inner, 10)
		local top = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 1, Parent = inner })
		UI.new("TextLabel", { Text = "FORGOTTEN  ·  " .. tostring(rec.Tier or ""), Font = S.FontHeavy, TextSize = Menu.size("Small"), TextColor3 = FORGOTTEN_COLOR, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.6, 0, 1, 0), Parent = top })
		local tag = Menu.stateTag(top, "DONE", nil, "RECORDED")
		tag.AnchorPoint = Vector2.new(1, 0.5)
		tag.Position = UDim2.fromScale(1, 0.5)
		UI.new("TextLabel", { Text = string.upper(tostring(rec.Name or "???")), Font = S.FontHeavy, TextSize = Menu.size("H1") + 2, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 2, Parent = inner })
		local sg = Menu.grid(inner, { Min = 140, Height = 50, Max = 3, Gap = 8, Order = 3 })
		local secs = rec.FastestCompletion
		Menu.stat(sg, "Completed", tostring(rec.TimesCompleted or 0), 1)
		Menu.stat(sg, "Best share", string.format("%.1f%%", rec.BestContributionPct or 0), 2)
		Menu.stat(sg, "Fastest", if secs then Format.Time(secs) else "-", 3)
	end
end

local DRAW = { Builds = drawBuilds, Achievements = drawAchievements, MasterBuilder = drawMasterBuilder, MasterArchive = drawMasterArchive, Forgotten = drawForgotten }

local syncTabs

local function refresh()
	if not panel then
		return
	end
	syncTabs()
	clear()
	DRAW[currentTab]()
	local d = dataOrEmpty()
	local found = 0
	for _, e in d.BuildIndex or {} do
		if e.Discovered then
			found += 1
		end
	end
	panel.Subtitle.Text = string.format("%d / %d builds discovered", found, #BuildConfig.IndexOrder(rarityOrder()))
end

local tabsHaveForgotten: boolean? = nil
local suppressSelect = false
local function hasForgotten(): boolean
	for _, rec in dataOrEmpty().ForgottenArchive or {} do
		if rec.Discovered then
			return true
		end
	end
	return false
end

-- (re)creates the tab strip; the Forgotten tab exists only while the player holds at least one Forgotten record
syncTabs = function(force: boolean?)
	local want = hasForgotten()
	if not panel or (not force and want == tabsHaveForgotten) then
		return
	end
	tabsHaveForgotten = want
	if tabs then
		tabs.Frame:Destroy()
	end
	local defs = {
		{ Id = "Builds", Text = "Builds" },
		{ Id = "Achievements", Text = "Achievements" },
		{ Id = "MasterBuilder", Text = "Master Builder" },
		{ Id = "MasterArchive", Text = "Master Archive" },
	}
	if want then
		table.insert(defs, { Id = "Forgotten", Text = "Forgotten" })
	elseif currentTab == "Forgotten" then
		currentTab = "Builds"
	end
	tabs = Menu.tabs(panel.Frame, defs, function(id)
		currentTab = id
		if not suppressSelect then
			refresh()
			panel.Body.CanvasPosition = Vector2.zero
		end
	end)
	tabs.Frame.Position = UDim2.fromOffset(0, panel.HeaderH)
	if not force then
		suppressSelect = true
		tabs.Select(currentTab) -- repaint only; the caller (refresh) redraws the content
		suppressSelect = false
	end
end

local function build(): Frame
	panel = Menu.panel("Index", "Blueprint Archive", { Icon = "book", Wide = true })
	tabs = nil
	tabsHaveForgotten = nil
	syncTabs(true)
	local tabH = tabs.Frame.Size.Y.Offset
	panel.Body.Position = UDim2.fromOffset(0, panel.HeaderH + tabH)
	panel.Body.Size = UDim2.new(1, 0, 1, -(panel.HeaderH + tabH))
	content = UI.new("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.new(1, -(2 * S.Pad + 6), 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = panel.Body })
	UI.list(content, 10)
	BuildPreview.setClip(panel.Body)
	tabs.Select(currentTab)
	return panel.Frame
end

function IndexPanel.Start()
	UI.registerPanel("Index", build, function()
		lastSig = ""
		previewsCleared = false
		refresh()
	end, {
		OnBumper = function(dir: number)
			if tabs then
				tabs.Next(dir)
			end
		end,
	})
	-- PlayerSync arrives every few seconds while depositing (coins/stats move); rebuilding ~370
	-- instances for identical Index data was the biggest menu redraw, so skip unchanged data.
	State.DataChanged:Connect(function(data)
		if not seeded and data.BuildIndex then
			for id, e in data.BuildIndex do
				if e.Discovered then
					seen["B_" .. id] = true
				end
			end
			for id, rec in data.ForgottenArchive or {} do
				if rec.Discovered then
					seen["F_" .. tostring(id)] = true
				end
			end
			seeded = true
		end
		if not UI.isOpen("Index") then
			return
		end
		local slice = if currentTab == "Builds" then { data.BuildIndex }
			elseif currentTab == "Achievements" then { data.Achievements, data.Titles, data.EquippedTitle, data.Stats }
			elseif currentTab == "Forgotten" then { data.ForgottenArchive }
			else { data.MasterBuilder, data.Stats, data.Upgrades, data.Training, data.BuildIndex, math.floor(data.Coins or 0) }
		local sig = currentTab .. HttpService:JSONEncode(slice) .. tostring(hasForgotten())
		if sig ~= lastSig then
			lastSig = sig
			refresh()
		end
	end)
	UI.PanelChanged:Connect(function(open)
		if open == "Index" then
			BuildPreview.setActive(true)
			if previewsCleared and panel then
				-- the menu came back after a suspend (reveal): previews and any data that changed meanwhile are redrawn, scroll kept
				previewsCleared = false
				local y = panel.Body.CanvasPosition
				lastSig = ""
				refresh()
				task.defer(function()
					panel.Body.CanvasPosition = y
				end)
			end
		else
			BuildPreview.clear() -- closed (or another menu): free every ViewportFrame and model clone
			BuildPreview.setActive(false)
			previewsCleared = true
		end
	end)
	UI.ModeChanged:Connect(function()
		if panel then
			if UI.isOpen("Index") then
				UI.closePanel()
			end
			panel.Frame:Destroy()
			panel, tabs = nil, nil
			UI.registerPanel("Index", build, function()
		lastSig = ""
		refresh()
	end, {
				OnBumper = function(dir: number)
					if tabs then
						tabs.Next(dir)
					end
				end,
			})
		end
	end)
	local _ = player
end

return IndexPanel
