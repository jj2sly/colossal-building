--!strict
-- Worker menu. One Worker per player (not an army). Shows hire state, ON/OFF, the assigned
-- resource, stats derived from WorkerConfig + your Worker Efficiency upgrade, and (while the
-- menu is open) the live task read from the Worker model's replicated attributes.
-- Toggles and assignment update the UI instantly; the server validates and syncs.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local WorkerConfig = require(Shared.Config.WorkerConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local ResourceSpotConfig = require(Shared.Config.ResourceSpotConfig)
local Formulas = require(Shared.Formulas)
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local MasterBuilderConfig = require(Shared.Config.MasterBuilderConfig)
local TweenService = game:GetService("TweenService")
local Format = require(Shared.Util.Format)
local Lib = script.Parent.Parent.ClientLib
local UI = require(Lib.UI)
local Menu = require(Lib.Menu)
local State = require(Lib.State)
local Notify = require(script.Parent.NotifyController)

local WorkerPanel = {}
local S = Menu.S
local player = Players.LocalPlayer

local panel: any
local content: Frame
local liveLabel: TextLabel? = nil
local statusTag: TextLabel? = nil

local TASK_TEXT = {
	Idle = "Waiting at the worker station",
	ToZone = "Walking to the resource zone",
	Gathering = "Gathering",
	ToSite = "Carrying to the build",
	Depositing = "Unloading at the build",
	ToStation = "Heading home",
	Moving = "Heading home",
}

local function workerData(): any
	local d = State.Data
	return d and d.Worker or { Unlocked = false, Enabled = false, Assignment = "Auto", Type = WorkerConfig.DefaultType }
end

local function efficiency(): number
	local d = State.Data
	return UpgradeConfig.Value("WorkerEfficiency", d and d.Upgrades.WorkerEfficiency or 0)
end

-- Workers use each resource's beginner spot, so the estimate averages those distances (from config).
local function zoneDistance(): number
	local sum, n = 0, 0
	for _, resId in ResourceConfig.Families do
		local spot = ResourceSpotConfig.Primary(resId)
		if spot then
			sum += ResourceSpotConfig.DistanceFromRing(spot)
			n += 1
		end
	end
	return if n > 0 then sum / n else 200
end

-- Same formula as the server (WorkerConfig.Scaled): the Worker works at its tier's share of YOUR carry / speed / gather speed.
local function statsFor(def: any, eff: number)
	local d = State.Data
	local tr = d and d.Training or {}
	local rank = d and d.MasterBuilder and d.MasterBuilder.Rank or 0
	local playerCarry = Formulas.BaseCarry(tr.Strength or 0) * (1 + MasterBuilderConfig.Bonus(rank, "CarryEffectiveness"))
	local gatherSpeed = UpgradeConfig.Value("GatherSpeed", d and d.Upgrades.GatherSpeed or 0)
	local carry, speed, gather = WorkerConfig.Scaled(def, workerData().Tier, playerCarry, Formulas.BaseSpeed(tr.Speed or 0), gatherSpeed, eff)
	local cycle = gather + def.DepositTime + 2 * zoneDistance() / speed
	return carry, speed, gather, carry / cycle * 60
end

local function card(order: number): Frame
	local f = Menu.surface(content, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order })
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 14), Parent = f })
	UI.list(f, 8)
	return f
end

-- worker tier = a STEEL plate with 1-4 rivets (never a build-rarity colour: crew management is not a collection game)
local function tierPlate(parent: Instance, tierId: string, order: number?): Frame
	local tier = WorkerConfig.Tiers[tierId] or WorkerConfig.Tiers.Basic
	local f = UI.new("Frame", { BackgroundColor3 = S.Header, BackgroundTransparency = 0, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 24), LayoutOrder = order or 0, Parent = parent })
	UI.new("UICorner", { CornerRadius = UDim.new(0, 12), Parent = f })
	UI.new("UIStroke", { Color = S.Line, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = f })
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 10), Parent = f })
	local l = UI.list(f, 6, true)
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	local rivets = UI.new("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 24), LayoutOrder = 1, Parent = f })
	local rl = UI.list(rivets, 3, true)
	rl.VerticalAlignment = Enum.VerticalAlignment.Center
	local n = table.find(WorkerConfig.TierOrder, tierId) or 1
	for i = 1, #WorkerConfig.TierOrder do
		UI.new("Frame", { BackgroundColor3 = if i <= n then S.Text else S.Line, BackgroundTransparency = 0, Size = UDim2.fromOffset(5, 5), LayoutOrder = i, Parent = rivets })
	end
	UI.new("TextLabel", { Text = string.upper(tier.DisplayName), Font = S.FontHeavy, TextSize = Menu.size("Small"), TextColor3 = S.Text, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 24), LayoutOrder = 2, Parent = f })
	return f
end

local function updateLive()
	if not liveLabel then
		return
	end
	local m = workspace:FindFirstChild("Workers") and workspace.Workers:FindFirstChild("Worker_" .. player.UserId)
	local wd = workerData()
	if not wd.Unlocked then
		return
	end
	if not wd.Enabled then
		liveLabel.Text = "Stood down"
		if statusTag then
			Menu.setStateTag(statusTag, "OFF")
		end
		return
	end
	if not m then
		liveLabel.Text = "Starting up..."
		return
	end
	local strike = m:GetAttribute("Strike") == true
	local state = tostring(m:GetAttribute("State") or "Idle")
	local res = ResourceConfig.Resources[tostring(m:GetAttribute("CarryRes") or "")]
	local carry = m:GetAttribute("Carry") or 0
	local text = TASK_TEXT[state] or state
	if strike then
		text = "On strike (paused)"
	elseif state == "ToSite" and res then
		text = string.format("Carrying %d %s to the build", carry, res.DisplayName)
	end
	liveLabel.Text = text
	if statusTag then
		if strike then
			Menu.setStateTag(statusTag, "ONBREAK", "ON BREAK")
		else
			Menu.setStateTag(statusTag, "ACTIVE")
		end
	end
end

------------------------------------------------------------------ recruiting (Worker Crates; Coins only, calm presentation)
local lastResult: any = nil -- the last recruit, shown at the top of the Recruitment card until the next one
local recruiting = false

local function recruitPrice(): number
	local wd = workerData()
	if not wd.Unlocked then
		return WorkerConfig.FirstHirePrice
	end
	local c = WorkerConfig.Crate
	return math.min(c.MaxPrice, math.floor(c.Price * c.PriceGrowth ^ math.min(wd.CrateCount or 0, 30)))
end

local function tierName(typeId: string, tierId: string): string
	local t = WorkerConfig.Types[typeId]
	return string.format("%s %s", (WorkerConfig.Tiers[tierId] or WorkerConfig.Tiers.Basic).DisplayName, if t then t.DisplayName else typeId)
end

local draw: () -> ()

local function recruit()
	if recruiting then
		return
	end
	recruiting = true
	local ok, res = Net.Function("WorkerCrate"):InvokeServer("Open")
	recruiting = false
	if ok then
		lastResult = res
		lastResult.At = os.clock()
	else
		Notify.Show("Error", tostring(res))
	end
	draw()
end

local function wrapped(parent: Instance, text: string, order: number, color: Color3?)
	return UI.new("TextLabel", {
		Text = text,
		Font = S.Font,
		TextSize = Menu.size("Small"),
		TextColor3 = color or S.Dim,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = parent,
	})
end

-- RECRUITMENT: one card. Price + RECRUIT first, then what a hire can be, progress toward a better hire, tokens and your crew.
local function drawRecruit(order: number)
	local wd = workerData()
	local d = State.Data
	local rank = d and d.MasterBuilder and d.MasterBuilder.Rank or 0
	local coins = player:GetAttribute("Coins") or 0
	local c = card(order)
	Menu.section(c, "Recruitment", 0, "hire crew members")
	local price = recruitPrice()
	local rb = Menu.button({
		Name = "Recruit",
		Text = if wd.Unlocked then string.format("RECRUIT   %s", Format.Number(price)) else string.format("HIRE YOUR FIRST WORKER   %s", Format.Number(price)),
		Kind = if coins >= price then "good" else "secondary",
		Enabled = coins >= price and not recruiting,
		TextSize = 20,
		Size = UDim2.new(1, 0, 0, 54),
		LayoutOrder = 1,
		Parent = c,
	}, recruit)
	rb.Font = S.FontHeavy
	-- result of the last recruit: a quiet strip (no spinning, no flashing)
	if lastResult then
		local res = Menu.well(c, { Size = UDim2.new(1, 0, 0, 52), LayoutOrder = 2 })
		UI.new("UIStroke", { Color = S.Accent, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = res })
		local title = UI.new("TextLabel", { Text = "HIRED   " .. string.upper(tierName(lastResult.Type, lastResult.Tier)), Font = S.FontHeavy, TextSize = Menu.size("Body"), TextColor3 = S.Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(14, 5), Size = UDim2.new(1, -20, 0, 22), Parent = res })
		local sub = UI.new("TextLabel", {
			Text = if lastResult.New then (if lastResult.First then "Your first crew member is on the way to work!" else "New crew member. Equip them below.") else string.format("Already in your crew: +%d Worker Tokens", lastResult.Tokens or 0),
			Font = S.Font, TextSize = Menu.size("Small"), TextColor3 = S.Dim, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(14, 27), Size = UDim2.new(1, -20, 0, 20), Parent = res,
		})
		if os.clock() - (lastResult.At or 0) < 1 then
			title.TextTransparency, sub.TextTransparency = 1, 1
			TweenService:Create(title, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
			TweenService:Create(sub, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
		end
	end
	-- tiers: share of your stats and your chance (or the Master Builder rank that unlocks it)
	local total = 0
	for _, id in WorkerConfig.TierOrder do
		if MasterBuilderConfig.WorkerTierUnlocked(rank, id) then
			total += WorkerConfig.Tiers[id].CrateWeight
		end
	end
	local tiers = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = c })
	UI.list(tiers, 4)
	for i, id in WorkerConfig.TierOrder do
		local tier = WorkerConfig.Tiers[id]
		local unlocked = MasterBuilderConfig.WorkerTierUnlocked(rank, id)
		local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = i, Parent = tiers })
		local plate = tierPlate(row, id)
		plate.Position = UDim2.fromOffset(0, 1)
		UI.new("TextLabel", { Text = string.format("works at %d%% of your stats", math.floor(tier.Share * 100 + 0.5)), Font = S.Font, TextSize = Menu.size("Small"), TextColor3 = if unlocked then S.Text else S.Faint, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(112, 0), Size = UDim2.new(1, -240, 1, 0), Parent = row })
		UI.new("TextLabel", {
			Text = if not wd.Unlocked then (if id == WorkerConfig.DefaultTier then "first hire" else "-") elseif unlocked then string.format("%d%%", math.floor(tier.CrateWeight / math.max(1, total) * 100 + 0.5)) else string.format("Master Builder %d", WorkerConfig.CrateTierMinRank[id] or 0),
			Font = S.FontBold, TextSize = Menu.size("Small"), TextColor3 = if unlocked then S.Text else S.Faint,
			TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(126, 26), Parent = row,
		})
	end
	if wd.Unlocked then
		-- recruitment progress (the guaranteed-better-hire counter), shown as a calm bar
		local pity = WorkerConfig.Crate.Pity
		local left = math.max(1, pity.Threshold - (wd.PityCount or 0))
		local prow = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 4, Parent = c })
		UI.new("TextLabel", { Text = string.format("RECRUITMENT PROGRESS   %s or better within %d hire%s", WorkerConfig.Tiers[pity.GuaranteeTier].DisplayName, left, if left == 1 then "" else "s"), Font = S.FontBold, TextSize = Menu.size("Small"), TextColor3 = S.Dim, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, 0, 0, 18), Parent = prow })
		local holder = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 12), Parent = prow })
		local _, set = Menu.bar(holder, 12, S.Accent)
		set(math.clamp((wd.PityCount or 0) / pity.Threshold, 0, 1), S.Accent)
		-- tokens + training
		local trow = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Menu.buttonHeight()), LayoutOrder = 5, Parent = c })
		UI.new("TextLabel", { Text = string.format("WORKER TOKENS   %d", wd.Tokens or 0), Font = S.FontHeavy, TextSize = Menu.size("Body"), TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.4, 0, 1, 0), Parent = trow })
		local idx = table.find(WorkerConfig.TierOrder, wd.Tier or WorkerConfig.DefaultTier) or 1
		local nextId = WorkerConfig.TierOrder[idx + 1]
		if nextId then
			local cost = WorkerConfig.Tiers[nextId].ForgeCost or 0
			local can = (wd.Tokens or 0) >= cost and MasterBuilderConfig.WorkerTierUnlocked(rank, nextId)
			Menu.button({
				Name = "Forge",
				Text = string.format("TRAIN TO %s   %d tokens", string.upper(WorkerConfig.Tiers[nextId].DisplayName), cost),
				Kind = "secondary",
				Enabled = can,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0.6, 0, 1, 0),
				Parent = trow,
			}, function()
				local ok, msg = Net.Function("WorkerCrate"):InvokeServer("Forge")
				if not ok then
					Notify.Show("Error", tostring(msg))
				end
			end)
		end
	end
	-- your crew: every (specialty, tier) you have recruited; tap to put them to work
	local owned = {}
	for key in wd.Owned or {} do
		table.insert(owned, key)
	end
	if #owned > 1 then
		table.sort(owned)
		Menu.section(c, "Your crew", 6)
		local crow = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 7, Parent = c })
		UI.list(crow, 6, true).Wraps = true
		for i, key in owned do
			local typeId, tierId = string.match(key, "^(%w+):(%w+)$")
			if typeId and tierId then
				local current = wd.Type == typeId and (wd.Tier or WorkerConfig.DefaultTier) == tierId
				Menu.button({
					Name = "Crew_" .. key,
					Text = tierName(typeId, tierId),
					Kind = if current then "primary" else "secondary",
					Size = UDim2.fromOffset(210, Menu.buttonHeight()),
					LayoutOrder = i,
					Parent = crow,
				}, function()
					local ok, msg = Net.Function("WorkerCrate"):InvokeServer("Equip", { Type = typeId, Tier = tierId })
					if not ok then
						Notify.Show("Error", tostring(msg))
					end
				end)
			end
		end
	end
end

local function drawInner()
	for _, c in content:GetChildren() do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
	liveLabel, statusTag = nil, nil
	local d = State.Data
	local wd = workerData()
	local def = WorkerConfig.Types[wd.Type] or WorkerConfig.Types[WorkerConfig.DefaultType]
	local eff = efficiency()
	local carry, speed, gather, perMin = statsFor(def, eff)
	local coins = player:GetAttribute("Coins") or 0
	local tier = WorkerConfig.Tiers[wd.Tier or WorkerConfig.DefaultTier] or WorkerConfig.Tiers.Basic
	if panel then
		panel.Subtitle.Text = if wd.Unlocked then (if wd.Enabled then "Worker active" else "Worker off") else "Not hired"
	end

	-- 1 ACTIVE WORKER: name, tier plate, state, deploy toggle, current task, key stats
	local head = card(1)
	Menu.section(head, "Active worker", 0)
	if wd.Unlocked then
		local top = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 76), LayoutOrder = 1, Parent = head })
		local badge = Menu.iconWell(top, "hardhat", if wd.Enabled then S.Accent else S.Faint, 72)
		badge.Position = UDim2.fromOffset(0, 2)
		local left = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(86, 4), Size = UDim2.new(1, -236, 1, -8), Parent = top })
		UI.list(left, 6)
		UI.new("TextLabel", { Text = string.upper(def.DisplayName), Font = S.FontHeavy, TextSize = Menu.size("H1"), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, 0, 0, 32), LayoutOrder = 1, Parent = left })
		local chips = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 2, Parent = left })
		UI.list(chips, 8, true).VerticalAlignment = Enum.VerticalAlignment.Center
		tierPlate(chips, wd.Tier or WorkerConfig.DefaultTier, 1)
		statusTag = Menu.stateTag(chips, if wd.Enabled then "ACTIVE" else "OFF", 2)
		Menu.button({
			Name = "Toggle",
			Text = if wd.Enabled then "SEND HOME" else "DEPLOY",
			Kind = if wd.Enabled then "secondary" else "good",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(140, 52),
			TextSize = 18,
			Parent = top,
		}, function()
			local newValue = not wd.Enabled
			if d then
				d.Worker.Enabled = newValue
			end
			draw()
			Net.Event("WorkerCommand"):FireServer("SetEnabled", newValue)
		end)
		-- current task, as a status strip
		local taskWell = Menu.well(head, { Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 2 })
		liveLabel = UI.new("TextLabel", { Text = "", Font = S.FontHeavy, TextSize = Menu.size("Body"), TextColor3 = S.Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), Parent = taskWell })
		local assignRes = ResourceConfig.Resources[wd.Assignment or ""]
		local sg = Menu.grid(head, { Min = 150, Height = 54, Max = 3, Gap = 8, Order = 3 })
		Menu.stat(sg, "Output", string.format("~%d/min", math.floor(perMin + 0.5)), 1, S.Accent)
		Menu.stat(sg, "Assignment", if assignRes then assignRes.FamilyName else "Auto", 2, if assignRes then UI.resourceColor(wd.Assignment):Lerp(S.Text, 0.3) else S.Text)
		Menu.stat(sg, "Carry / trip", tostring(carry), 3)
		-- secondary numbers stay small, on one line
		UI.new("TextLabel", {
			Text = string.format("Speed %.1f/s   ·   Gather %.1fs   ·   Efficiency x%.2f   ·   Tier share %d%%", speed, gather, eff, math.floor(tier.Share * 100 + 0.5)),
			Font = S.FontBold, TextSize = Menu.size("Small"), TextColor3 = S.Dim, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 4, Parent = head,
		})
	else
		UI.new("TextLabel", { Text = "NO WORKER HIRED", Font = S.FontHeavy, TextSize = Menu.size("H1"), TextColor3 = S.Dim, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 1, Parent = head })
		wrapped(head, "A worker gathers, hauls and unloads for you at a share of your own strength and speed. One active worker per player.", 2)
		if coins < WorkerConfig.FirstHirePrice then
			wrapped(head, string.format("First hire: %s coins (need %s more).", Format.Number(WorkerConfig.FirstHirePrice), Format.Number(WorkerConfig.FirstHirePrice - math.floor(coins))), 3, S.Faint)
		end
	end

	-- RECRUITMENT comes right after the card until you have a first hire; afterwards it moves below the management cards
	local recruitOrder = if wd.Unlocked then 5 else 2
	drawRecruit(recruitOrder)

	-- 2 ASSIGNMENT
	local assign = card(3)
	Menu.section(assign, "Assignment", 0, "Auto = whatever the build needs most")
	local row = UI.new("Frame", { Name = "AssignRow", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = assign })
	local wl = UI.list(row, 6, true)
	wl.Wraps = true
	for i, a in WorkerConfig.Assignments do
		local res = ResourceConfig.Resources[a]
		local selected = wd.Assignment == a
		Menu.button({
			Name = "Assign_" .. a,
			Text = if res then res.FamilyName else "Auto",
			Kind = if selected then "primary" else "secondary",
			Size = UDim2.fromOffset(if res then 104 else 96, Menu.buttonHeight()),
			LayoutOrder = i,
			Parent = row,
		}, function()
			if d then
				d.Worker.Assignment = a
			end
			draw()
			Net.Event("WorkerCommand"):FireServer("Assign", a)
		end)
	end

	-- 3 CREW specialty + outfit (cosmetic outfits come from builds, Index milestones and later Master Builder rewards)
	if wd.Unlocked then
		local crew = card(4)
		Menu.section(crew, "Crew specialty", 0)
		local trow = UI.new("Frame", { Name = "TypeRow", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = crew })
		UI.list(trow, 6, true).Wraps = true
		for i, id in WorkerConfig.TypeOrder do
			local t = WorkerConfig.Types[id]
			local owned = wd.OwnedTypes and wd.OwnedTypes[id]
			Menu.button({
				Name = "Type_" .. id,
				Text = if owned or t.Price == 0 then t.DisplayName else string.format("%s  %s", t.DisplayName, Format.Number(t.Price)),
				Kind = if wd.Type == id then "primary" else "secondary",
				Enabled = owned or coins >= t.Price,
				Size = UDim2.fromOffset(190, Menu.buttonHeight()),
				LayoutOrder = i,
				Parent = trow,
			}, function()
				Net.Event("WorkerCommand"):FireServer("SetType", id)
			end)
		end
		wrapped(crew, def.Description .. " Premium grades (Timber, Boulders, Heavy Steel, Energy Cores) need a Hauler or you.", 2)
		Menu.section(crew, "Outfit", 3)
		local orow = UI.new("Frame", { Name = "OutfitRow", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4, Parent = crew })
		UI.list(orow, 6, true).Wraps = true
		local owned = d and d.Cosmetics and d.Cosmetics.WorkerOutfit or {}
		local locked, order = 0, 0
		for id, o in WorkerConfig.Outfits do
			if id == WorkerConfig.DefaultOutfit or owned[id] then
				order += 1
				Menu.button({
					Name = "Outfit_" .. id,
					Text = o.DisplayName,
					Kind = if (wd.Outfit or WorkerConfig.DefaultOutfit) == id then "primary" else "secondary",
					Size = UDim2.fromOffset(160, Menu.buttonHeight()),
					LayoutOrder = order,
					Parent = orow,
				}, function()
					Net.Event("WorkerCommand"):FireServer("SetOutfit", id)
				end)
			else
				locked += 1
			end
		end
		if locked > 0 then
			wrapped(crew, string.format("%d more outfits to discover from rare build drops and Index milestones.", locked), 5, S.Faint)
		end
	end
	updateLive()
end

draw = function()
	if panel then
		Menu.keepFocus(panel.Frame, drawInner)
	end
end

local function build(): Frame
	panel = Menu.panel("Worker", "Crew Management", { Icon = "hardhat" })
	content = UI.new("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.new(1, -(2 * S.Pad + 6), 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = panel.Body })
	UI.list(content, 10)
	return panel.Frame
end

function WorkerPanel.Start()
	UI.registerPanel("Worker", build, draw)
	State.DataChanged:Connect(function()
		if UI.isOpen("Worker") then
			draw()
		end
	end)
	-- live task text: only polls while the menu is open
	task.spawn(function()
		while true do
			task.wait(0.5)
			if UI.isOpen("Worker") then
				updateLive()
			end
		end
	end)
	UI.ModeChanged:Connect(function()
		if panel then
			if UI.isOpen("Worker") then
				UI.closePanel()
			end
			panel.Frame:Destroy()
			panel = nil
			UI.registerPanel("Worker", build, draw)
		end
	end)
end

return WorkerPanel
