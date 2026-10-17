--!strict
-- PROJECT CARD (top left, PRESENTATION_BIBLE §10): the strongest permanent HUD element. In under a second it says what the
-- whole server is building, how far along it is and what to bring:
--   rarity plate (pips + NAME) + modifier chips · BUILD NAME · STAGE n / N · stage name + total % · a thick stage-notched
--   progress bar with activation markers · MOST NEEDED.  Expanding (+) adds the per-material checklist and the timer.
-- Rarity changes the FRAME weight only (UI.rarityFrame), never the layout.
-- It also owns the project ribbons (§14): STAGE COMPLETE and SYSTEMS ONLINE slide out of the card's right edge, briefly.
-- Rows are created once and updated in place; redraws are coalesced to ~10/s.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Format = require(Shared.Util.Format)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local ModifierConfig = require(Shared.Config.ModifierConfig)
local BuildConfig = require(Shared.Config.BuildConfig)
local ColossalConfig = require(Shared.Config.ColossalConfig)
local Lib = script.Parent.Parent.ClientLib
local UI = require(Lib.UI)
local Site = require(Lib.Site)
local State = require(Lib.State)
local Sound = require(Lib.Sound)
local HUD = require(script.Parent.HUDController)
local ForgottenIdentity = require(Lib.ForgottenIdentity)
local SecretResourceConfig = require(Shared.Config.SecretResourceConfig)

local TrackerController = {}
local K = UI.Tokens
local TY = UI.Type
local MASTER_COLOR = Color3.fromRGB(120, 215, 255)

type Row = {
	frame: Frame,
	tile: Frame,
	name: TextLabel,
	bar: Frame,
	fill: Frame,
	amount: TextLabel,
	ratio: number,
}

local card: Frame
local tagRow: Frame
local collapseButton: TextButton
local titleLabel: TextLabel
local phaseLabel: TextLabel
local progressRow: Frame
local progressFill: Frame
local stageLabel: TextLabel
local progressPct: TextLabel
local progressBar: Frame
local markerRow: Frame
local tickKey = ""
local rowsFrame: Frame
local rows: { [string]: Row } = {}
local repairFrame: Frame
local repairLabel: TextLabel
local needStrip: Frame
local needTile: Frame
local needName: TextLabel
local needPct: TextLabel
local needTag: TextLabel
local lastTagKey: string? = nil
local collapsed = false
local userToggled = false

TrackerController.MostNeeded = nil :: string?

local function currentDef(): any
	local id = State.Get("BuildId")
	return if type(id) == "string" and id ~= "" then (BuildConfig.Get(id) or ForgottenIdentity.Def(id)) else nil
end

local function makeRow(resId: string, order: number)
	-- one line of the material checklist: family swatch, name, progress bar, count
	local f = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = order, Parent = rowsFrame })
	local tile = UI.new("Frame", { BackgroundColor3 = UI.resourceColor(resId), BackgroundTransparency = 0, Position = UDim2.new(0, 2, 0.5, -6), Size = UDim2.fromOffset(12, 12), Parent = f })
	UI.stroke(tile, K.Frame, 1.5)
	local name = UI.new("TextLabel", {
		Text = ResourceConfig.RequirementLabel(resId),
		Font = TY.Bold,
		TextSize = TY.Body,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(22, 0),
		Size = UDim2.fromOffset(92, 26),
		Parent = f,
	})
	local bar = UI.new("Frame", { BackgroundColor3 = K.PlateDeep, Position = UDim2.new(0, 118, 0.5, -6), Size = UDim2.new(1, -206, 0, 12), Parent = f })
	UI.corner(bar, 6)
	UI.stroke(bar, K.Frame, 1.5)
	local fill = UI.new("Frame", { BackgroundColor3 = UI.resourceColor(resId), Size = UDim2.fromScale(0, 1), Parent = bar })
	UI.corner(fill, 6)
	local amount = UI.new("TextLabel", {
		Font = TY.Bold,
		TextSize = TY.Label,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(84, 26),
		Parent = f,
	})
	rows[resId] = { frame = f, tile = tile, name = name, bar = bar, fill = fill, amount = amount, ratio = -1 }
end

local function setCollapsed(value: boolean)
	collapsed = value
	collapseButton.Text = if value then "+" else "–"
end

local function phaseText(): string
	local phase = State.Get("Phase") or ""
	local endsAt = State.Get("PhaseEndsAt") or 0
	local left = math.max(0, endsAt - State.ServerNow())
	local built = State.Get("BuildsCompleted") or 0
	if phase == "Building" then
		local started = State.Get("BuildStartedAt") or State.ServerNow()
		return "Under construction · " .. Format.Time(State.ServerNow() - started)
	elseif phase == "Intermission" or phase == "Selecting" then
		return "Next project in " .. Format.Time(left)
	elseif phase == "Voting" then
		return "Vote for the next project · " .. Format.Time(left)
	elseif phase == "Reveal" then
		return "New project!"
	elseif phase == "Complete" then
		return string.format("Project complete · %d built on this server", built)
	elseif phase == "Resetting" then
		return "Clearing the site..."
	end
	return ""
end

-- stage notches + activation markers (rebuilt when the build or stage count changes)
local function rebuildTicks(stageCount: number)
	local def = currentDef()
	local key = tostring(State.Get("BuildId")) .. "|" .. stageCount
	if key == tickKey then
		return
	end
	tickKey = key
	for _, c in progressBar:GetChildren() do
		if c.Name == "Tick" then
			c:Destroy()
		end
	end
	for _, c in markerRow:GetChildren() do
		c:Destroy()
	end
	for k = 1, stageCount - 1 do
		UI.new("Frame", { Name = "Tick", BackgroundColor3 = K.Frame, BackgroundTransparency = 0.55, Position = UDim2.new(k / stageCount, -1, 0.2, 0), Size = UDim2.new(0, 2, 0.6, 0), ZIndex = 3, Parent = progressBar })
	end
	-- activation markers: small notches above the bar where the build comes alive
	local points = {}
	local a = def and ColossalConfig.ActivationFraction(def)
	if a then
		table.insert(points, a)
	end
	for _, m in (def and def.Milestones) or {} do
		table.insert(points, m)
	end
	for i, f in points do
		local mk = UI.new("Frame", {
			Name = "Act" .. i,
			BackgroundColor3 = K.InkFaint,
			BackgroundTransparency = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(f, 0, 0.5, 0),
			Size = UDim2.fromOffset(9, 9),
			Parent = markerRow,
		})
		UI.corner(mk, 5)
		UI.stroke(mk, K.Frame, 2)
		mk:SetAttribute("At", f)
	end
end

local lastProgress = -1
local function redraw()
	local phase = State.Get("Phase") or ""
	local buildId = State.Get("BuildId") or ""
	-- during Reveal the overlay announces the build; the card stays generic so it can't spoil the roll
	local active = buildId ~= "" and (phase == "Building" or phase == "Complete")

	-- rarity plate + modifiers (rebuilt only when rarity/modifiers change); the frame weight follows the rarity
	local masterProject = State.Get("MasterProject")
	local isMaster = type(masterProject) == "string" and masterProject ~= ""
	local rarityName = State.Get("Rarity") or "Common"
	local ident = ForgottenIdentity.Def(buildId) -- a Forgotten structure this player has discovered: real tier + name
	if ident then
		rarityName = "Forgotten"
	end
	local tagKey = string.format("%s|%s|%s|%s", tostring(active), tostring(rarityName), tostring(State.Get("Modifiers")), tostring(isMaster))
	if tagKey ~= lastTagKey then
		lastTagKey = tagKey
		for _, c in tagRow:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		if active and isMaster then
			UI.rarityPlate(tagRow, "MASTER PROJECT", MASTER_COLOR, TY.Body, 1)
			UI.rarityFrame(card, "Legendary", MASTER_COLOR)
		elseif active then
			local r = RarityConfig.Get(rarityName)
			UI.rarityPlate(tagRow, r.DisplayName, r.Color, TY.Body, 1)
			local mods = string.split(State.Get("Modifiers") or "", ",")
			local shown = 0
			for i, id in mods do
				local m = ModifierConfig.Modifiers[id]
				if m then
					shown += 1
					if shown <= 2 then
						UI.chip(tagRow, m.DisplayName, m.Color, TY.Label, 1 + i)
					end
				end
			end
			if shown > 2 then
				UI.chip(tagRow, string.format("+%d", shown - 2), K.PlateRaised, TY.Label, 9)
			end
			UI.rarityFrame(card, rarityName, r.Color)
		else
			UI.rarityPlate(tagRow, "NEXT PROJECT", K.InkDim, TY.Body, 1)
			UI.rarityFrame(card, "Common", K.InkDim)
		end
	end
	if active then
		titleLabel.Text = if ident then string.upper(ident.DisplayName) else string.upper(State.Get("BuildTitle") or "")
	else
		titleLabel.Text = if phase == "Voting" then "SERVER VOTE" else "GET READY"
	end

	-- stage line + progress
	local progress = State.Get("Progress") or 0
	local stage, stageCount = State.Get("Stage") or 0, State.Get("StageCount") or 0
	local showProgress = stageCount > 0 and phase == "Building"
	progressRow.Visible = showProgress
	-- the timer line is secondary: only outside construction, or in the expanded card
	phaseLabel.Visible = not showProgress or not collapsed
	if showProgress then
		local def = currentDef()
		local current = math.min(stage + 1, stageCount)
		local stageName = def and def.StageNames and def.StageNames[current]
		stageLabel.Text = (if stageName then string.upper(stageName) .. "  " else "") .. string.format("· STAGE %d/%d", current, stageCount)
		progressPct.Text = Format.Percent(progress)
		rebuildTicks(stageCount)
		if progress ~= lastProgress then
			local grew = lastProgress >= 0 and progress > lastProgress
			lastProgress = progress
			UI.tween(progressFill, UI.Anim.Normal, { Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1) })
			if grew then
				-- the changed percentage briefly lights up amber and settles back (short, subtle)
				progressPct.TextColor3 = K.Amber
				UI.tween(progressPct, 0.45, { TextColor3 = K.Ink })
				local ps = progressPct:FindFirstChildOfClass("UIScale")
				if ps then
					ps.Scale = 1.18
					UI.tween(ps, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
				end
			end
		end
		progressFill.BackgroundColor3 = if progress >= 1 then K.Good else K.Amber
		local accent = if isMaster then MASTER_COLOR else RarityConfig.Get(rarityName).Color
		for _, mk in markerRow:GetChildren() do
			if mk:IsA("Frame") then
				local reached = progress >= ((mk:GetAttribute("At") :: number?) or 2)
				mk.BackgroundColor3 = if reached then accent else K.InkFaint
			end
		end
	end

	-- resource rows: find the most-behind unfinished resource
	local worstRes, worstRatio, secondRatio, unfinished = nil, 2, 2, 0
	for _, id in ResourceConfig.Order do
		local need = State.Get("Need_" .. id)
		local row = rows[id]
		if need and need > 0 and phase == "Building" then
			local have = State.Get("Have_" .. id) or 0
			local ratio = math.clamp(have / need, 0, 1)
			row.frame.Visible = true
			if row.ratio ~= ratio then
				row.ratio = ratio
				UI.tween(row.fill, UI.Anim.Normal, { Size = UDim2.fromScale(ratio, 1) })
			end
			local done = ratio >= 1
			row.fill.BackgroundColor3 = if done then K.Good else UI.resourceColor(id)
			row.amount.Text = if done then "DONE" else Format.Short(have) .. " / " .. Format.Short(need)
			row.amount.TextColor3 = if done then K.Good else K.Ink
			row.name.TextTransparency = if done then 0.45 else 0
			row.tile.BackgroundTransparency = if done then 0.6 else 0
			local res = ResourceConfig.Resources[id]
			local locked = res.Secret ~= nil and not SecretResourceConfig.CanAccess(res.Secret, State.Data)
			if not done and not locked then -- a secret you cannot gather is never "most needed" for you
				unfinished += 1
				if ratio < worstRatio then
					secondRatio = worstRatio
					worstRes, worstRatio = id, ratio
				elseif ratio < secondRatio then
					secondRatio = ratio
				end
			end
		else
			row.frame.Visible = false
			row.ratio = -1
		end
	end
	for id, row in rows do
		local highlight = id == worstRes and unfinished > 1 and (secondRatio - worstRatio) >= 0.03
		row.name.TextColor3 = if highlight then K.Amber else K.Ink
	end
	TrackerController.MostNeeded = worstRes

	-- repairs replace MOST NEEDED until they are done (one row, never an extra one)
	local parts = {}
	for _, id in ResourceConfig.Order do
		local need = State.Get("RepairNeed_" .. id) or 0
		local have = State.Get("RepairHave_" .. id) or 0
		if need > have then
			table.insert(parts, ResourceConfig.RequirementLabel(id) .. " " .. (need - have))
		end
	end
	local repairing = #parts > 0 and phase == "Building"
	repairFrame.Visible = repairing
	if repairing then
		local damaged = State.Get("DamagedSections") or 0
		repairLabel.Text = string.format("REPAIR %s  ·  %s", if damaged > 0 then tostring(damaged) .. " SECTION" .. (if damaged == 1 then "" else "S") else "DAMAGE", table.concat(parts, "  ·  "))
	end

	rowsFrame.Visible = phase == "Building" and not collapsed
	needStrip.Visible = phase == "Building" and not repairing
	if needStrip.Visible then
		if worstRes then
			needTag.Visible = true
			needTile.Visible = true
			local rc = UI.resourceColor(worstRes)
			needTile.BackgroundColor3 = rc
			needStrip.BackgroundColor3 = rc:Lerp(K.PlateDeep, 0.55)
			local nst = needStrip:FindFirstChildOfClass("UIStroke")
			if nst then
				nst.Color = rc
			end
			local ic = UI.resourceIcon(worstRes)
			if needTile:GetAttribute("Icon") ~= ic then
				needTile:SetAttribute("Icon", ic)
				for _, c in needTile:GetChildren() do
					if c:IsA("Frame") then
						c:Destroy()
					end
				end
				local pic = Site.icon(needTile, ic, K.Ink, 24)
				pic.AnchorPoint = Vector2.new(0.5, 0.5)
				pic.Position = UDim2.fromScale(0.5, 0.5)
			end
			local nm = string.upper(ResourceConfig.RequirementLabel(worstRes))
			if needName.Text ~= nm and needName.Text ~= "" and lastTagKey ~= nil then
				needName.TextTransparency = 0.8 -- a clean cross-fade when the most-needed material changes
				needTile.BackgroundTransparency = 0.7
				UI.tween(needName, UI.Anim.Normal, { TextTransparency = 0 })
				UI.tween(needTile, UI.Anim.Normal, { BackgroundTransparency = 0 })
			end
			needName.Text = nm
			needName.TextColor3 = K.Ink
			needPct.Text = Format.Percent(worstRatio)
		else
			needTag.Visible = false
			needTile.Visible = false
			needStrip.BackgroundColor3 = K.Good:Lerp(K.PlateDeep, 0.6)
			needName.Text = "ALL MATERIALS DELIVERED"
			needName.TextColor3 = K.Good
			needPct.Text = ""
		end
	end
	collapseButton.Visible = phase == "Building"
	-- the reveal and vote overlays are the focus while they run
	card.Visible = phase ~= "Reveal" and phase ~= "Voting" and not UI.Moments.Reveal
end

------------------------------------------------------------------ project ribbons (stage complete / activation)
type Ribbon = { kind: string, title: string, line: string, sub: string?, color: Color3? }
local ribbonGui: ScreenGui
local queue: { Ribbon } = {}
local showing = false

local function ribbonFrame(r: Ribbon): Frame
	local stage = r.kind == "stage"
	local f = UI.new("Frame", {
		Name = "ProjectRibbon",
		BackgroundColor3 = if stage then K.Amber else K.PlateDeep,
		BackgroundTransparency = 0,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		ZIndex = 10,
		Parent = ribbonGui,
	})
	UI.corner(f, 12)
	UI.stroke(f, K.Frame, 3)
	if not stage then
		-- activation: the rarity colour fills the plate (darkened), so it reads as build energy, not a notice
		f.BackgroundColor3 = (r.color or K.Power):Lerp(K.PlateDeep, 0.6)
		local st = f:FindFirstChildOfClass("UIStroke")
		if st then
			st.Color = r.color or K.Power
		end
	end
	-- text lives in its own auto-sized column; the accent edge is a sibling sized from it (no scale children here,
	-- which would feed back into AutomaticSize)
	local col = UI.new("Frame", { Name = "Content", BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0), ZIndex = 11, Parent = f })
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 16), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 9), Parent = col })
	UI.list(col, 1)
	local ink = if stage then K.AmberInk else (r.color or K.Power):Lerp(K.Ink, 0.45)
	UI.new("TextLabel", { Text = r.title, Font = TY.Heavy, TextSize = 24, TextColor3 = ink, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 26), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, ZIndex = 11, Parent = col })
	UI.new("TextLabel", { Text = r.line, Font = TY.Heavy, TextSize = TY.Heading, TextColor3 = if stage then K.AmberInk else K.Ink, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2, ZIndex = 11, Parent = col })
	if r.sub then
		UI.new("TextLabel", { Text = r.sub, Font = TY.Bold, TextSize = TY.Label, TextColor3 = if stage then Color3.fromRGB(92, 70, 16) else K.InkDim, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 16), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 3, ZIndex = 11, Parent = col })
	end
	UI.shine(f, 10)
	return f
end

local function runQueue()
	if showing then
		return
	end
	showing = true
	task.spawn(function()
		while #queue > 0 do
			local r = table.remove(queue, 1) :: Ribbon
			if card.Visible then
				local cam = workspace.CurrentCamera
				local scale = if cam then UI.scaleFor(cam.ViewportSize) else 1
				local f = ribbonFrame(r)
				-- slides out of the card's right edge, level with the stage line
				local x = (card.AbsolutePosition.X + card.AbsoluteSize.X) / scale
				local y = (card.AbsolutePosition.Y + 34 * scale) / scale
				if UI.Mode == "phone" and UI.Portrait then
					-- no room beside the card: drop it just under the card instead
					x = card.AbsolutePosition.X / scale + 8
					y = (card.AbsolutePosition.Y + card.AbsoluteSize.Y) / scale + 6
				end
				f.Position = UDim2.fromOffset(x - 10, y)
				local rs = UI.new("UIScale", { Scale = 0.7, Parent = f }) -- one punchy pop-in (short back ease), then still
				UI.tween(rs, 0.24, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
				for _, d in f:GetDescendants() do
					if d:IsA("TextLabel") then
						d.TextTransparency = 1
					end
				end
				f.BackgroundTransparency = 1
				local fs = f:FindFirstChildOfClass("UIStroke")
				if fs then
					fs.Transparency = 1 -- the frame outline fades with the plate (no empty outlined box while it slides)
					UI.tween(fs, UI.Anim.Normal, { Transparency = 0 })
				end
				UI.tween(f, UI.Anim.Normal, { Position = UDim2.fromOffset(x + 6, y), BackgroundTransparency = 0 })
				for _, d in f:GetDescendants() do
					if d:IsA("TextLabel") then
						UI.tween(d, UI.Anim.Normal, { TextTransparency = 0 })
					end
				end
				-- hold; a newer stage ribbon cuts an older one short so the ribbon never lags behind the card
				local hold, t0 = if r.kind == "stage" then 1.9 else 2.6, os.clock()
				while os.clock() - t0 < hold do
					task.wait(0.1)
					if r.kind == "stage" and queue[1] and queue[1].kind == "stage" and os.clock() - t0 > 0.6 then
						break
					end
				end
				UI.tween(f, UI.Anim.Normal, { Position = UDim2.fromOffset(x - 10, y), BackgroundTransparency = 1 })
				if fs then
					UI.tween(fs, UI.Anim.Normal, { Transparency = 1 })
				end
				for _, d in f:GetDescendants() do
					if d:IsA("TextLabel") then
						UI.tween(d, UI.Anim.Normal, { TextTransparency = 1 })
					elseif d:IsA("Frame") then
						UI.tween(d, UI.Anim.Normal, { BackgroundTransparency = 1 })
					end
				end
				task.wait(UI.Anim.Normal + 0.05)
				f:Destroy()
				task.wait(0.25)
			end
		end
		showing = false
	end)
end

local function push(r: Ribbon)
	-- spam guard: a newer stage ribbon replaces a stage ribbon that is still waiting
	if r.kind == "stage" then
		for i = #queue, 1, -1 do
			if queue[i].kind == "stage" then
				table.remove(queue, i)
			end
		end
	end
	table.insert(queue, r)
	runQueue()
end

local ACT_WORDS = {
	[1] = { "SYSTEMS ONLINE" },
	[2] = { "SYSTEMS ONLINE", "FULL POWER" },
	[3] = { "SYSTEMS ONLINE", "POWER RISING", "FULL POWER" },
}
local function activationRibbon(n: number)
	local def = currentDef()
	local total = 1 + #((def and def.Milestones) or {})
	local words = ACT_WORDS[math.clamp(total, 1, 3)]
	local r = RarityConfig.Get(State.Get("Rarity") or "Common")
	local ident = ForgottenIdentity.Def(State.Get("BuildId"))
	local title = if ident then string.upper(ident.DisplayName) else string.upper(State.Get("BuildTitle") or "")
	if ident then
		r = RarityConfig.Get("Forgotten")
	end
	-- a restrained pulse through the card edge and progress area (no screen flash; the spectacle stays the focus)
	local st = card and card:FindFirstChildOfClass("UIStroke")
	if st then
		local was = st.Color
		st.Color = r.Color
		UI.tween(st, 0.7, { Color = was })
	end
	if progressFill then
		local fc = progressFill.BackgroundColor3
		progressFill.BackgroundColor3 = fc:Lerp(Color3.new(1, 1, 1), 0.45)
		UI.tween(progressFill, 0.6, { BackgroundColor3 = fc })
	end
	push({
		kind = "activation",
		title = words[math.clamp(n, 1, #words)],
		line = if n == 1 then title .. " is coming alive" else title,
		sub = if total > 1 then string.format("ACTIVATION %d OF %d", n, total) else nil,
		color = r.Color,
	})
end

function TrackerController.Start()
	while not HUD.TopStack do
		task.wait()
	end
	card = UI.card({
		Name = "BuildCard",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = HUD.TopStack,
	})
	card.ClipsDescendants = true
	ribbonGui = (HUD.TopStack :: Frame):FindFirstAncestorOfClass("ScreenGui") :: ScreenGui
	local body = UI.new("Frame", { Name = "Body", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = card })
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 12), Parent = body })
	UI.list(body, 5, false, Enum.HorizontalAlignment.Left)
	UI.fitHeight(card, body)

	-- 1 rarity line
	local header = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 1, Parent = body })
	tagRow = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -32, 1, 0), Parent = header })
	UI.list(tagRow, 5, true).VerticalAlignment = Enum.VerticalAlignment.Center
	collapseButton = UI.button({
		Text = "+",
		TextSize = TY.Heading,
		BackgroundColor3 = K.PlateRaised,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(30, 28),
		Parent = header,
	}, function()
		userToggled = true
		setCollapsed(not collapsed)
		redraw()
	end)

	-- 2 BUILD NAME (largest text on the HUD; shrinks to 17 before it truncates)
	titleLabel = UI.new("TextLabel", {
		Font = TY.Heavy,
		TextScaled = true,
		TextColor3 = K.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = 2,
		Parent = body,
	})
	UI.new("UITextSizeConstraint", { MaxTextSize = 32, MinTextSize = 18, Parent = titleLabel })
	UI.textStroke(titleLabel, 2)
	phaseLabel = UI.new("TextLabel", { Font = TY.Bold, TextSize = TY.Label, TextColor3 = K.InkDim, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 3, Parent = body })

	-- 3 stage line + 4 progress (stage notches; activation markers above)
	progressRow = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 54), LayoutOrder = 4, Parent = body })
	stageLabel = UI.new("TextLabel", { Font = TY.Heavy, TextSize = TY.Body, TextColor3 = K.Amber:Lerp(K.Ink, 0.35), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, -78, 0, 22), Parent = progressRow })
	progressPct = UI.new("TextLabel", { Font = TY.Heavy, TextSize = 28, TextColor3 = K.Ink, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, -4), Size = UDim2.fromOffset(78, 28), Parent = progressRow })
	UI.textStroke(progressPct, 2)
	UI.new("UIScale", { Parent = progressPct })
	-- thick rounded progress bar; stage notches inside, activation dots ride on it
	progressBar = UI.new("Frame", { BackgroundColor3 = K.PlateDeep, Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 22), Parent = progressRow })
	UI.corner(progressBar, 11)
	UI.stroke(progressBar, K.Frame, 3)
	progressFill = UI.new("Frame", { BackgroundColor3 = K.Amber, Size = UDim2.fromScale(0, 1), Parent = progressBar })
	UI.corner(progressFill, 11)
	UI.shine(progressFill, 6)
	markerRow = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 22), ZIndex = 4, Parent = progressRow })

	-- 5 MOST NEEDED: one row, amber edge, family swatch, name, %
	-- MOST NEEDED capsule: [resource icon] NAME ........ % on a resource-coloured plate (reads in under a second)
	needStrip = UI.new("Frame", { BackgroundColor3 = K.PlateDeep, BackgroundTransparency = 0, Size = UDim2.new(1, 0, 0, 48), Visible = false, LayoutOrder = 5, Parent = body })
	UI.corner(needStrip, 12)
	UI.stroke(needStrip, K.InkDim, 2)
	needTile = UI.new("Frame", { BackgroundColor3 = K.InkDim, BackgroundTransparency = 0, Position = UDim2.new(0, 6, 0.5, -18), Size = UDim2.fromOffset(36, 36), Parent = needStrip })
	UI.corner(needTile, 18)
	UI.stroke(needTile, K.Frame, 2)
	needTag = UI.new("TextLabel", { Text = "MOST NEEDED", Font = TY.Heavy, TextSize = TY.Label, TextColor3 = K.Amber, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(50, 4), Size = UDim2.new(1, -120, 0, 16), Parent = needStrip })
	needName = UI.new("TextLabel", { Font = TY.Heavy, TextSize = 20, TextColor3 = K.Ink, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(50, 20), Size = UDim2.new(1, -120, 0, 24), Parent = needStrip })
	UI.textStroke(needName, 1.5)
	needPct = UI.new("TextLabel", { Font = TY.Heavy, TextSize = 24, TextColor3 = K.Ink, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(64, 30), Parent = needStrip })
	UI.textStroke(needPct, 1.5)

	-- repairs (replace MOST NEEDED while damage is outstanding)
	repairFrame = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(110, 40, 34), BackgroundTransparency = 0, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 5, Visible = false, Parent = body })
	UI.corner(repairFrame, 12)
	UI.stroke(repairFrame, K.Bad, 2)
	UI.new("Frame", { BackgroundColor3 = K.Bad, BackgroundTransparency = 0, Size = UDim2.new(0, 3, 1, 0), Parent = repairFrame })
	repairLabel = UI.new("TextLabel", { Font = TY.Heavy, TextSize = TY.Body, TextColor3 = Color3.fromRGB(255, 200, 186), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -14, 1, 0), Parent = repairFrame })

	-- expanded: the material checklist
	rowsFrame = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 6, Parent = body })
	UI.list(rowsFrame, 1)
	UI.new("TextLabel", { Text = "MATERIALS", Font = TY.Heavy, TextSize = TY.Label, TextColor3 = K.InkDim, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 0, Parent = rowsFrame })
	for i, id in ResourceConfig.Order do
		makeRow(id, i)
	end

	local function applyMode()
		if not userToggled then
			setCollapsed(true)
		end
		redraw()
	end
	UI.ModeChanged:Connect(applyMode)
	setCollapsed(true) -- the card starts as name + stage + progress + most needed; expand for the breakdown

	-- reveal hand-off: the card stays hidden while the reveal overlay is up, then "receives" the project with a short flash
	UI.MomentChanged:Connect(function(name, on)
		if name ~= "Reveal" then
			return
		end
		redraw()
		if not on then
			local st = card:FindFirstChildOfClass("UIStroke")
			if st then
				local was = st.Color
				st.Color = K.Amber
				task.delay(0.3, function()
					UI.tween(st, 0.3, { Color = was })
				end)
			end
		end
	end)

	-- project ribbons
	Net.Event("Effect").OnClientEvent:Connect(function(id, payload)
		if id == "StageComplete" and type(payload) == "table" then
			if (payload.Stage or 0) < (payload.Total or 0) then
				local def = currentDef()
				local nextName = def and def.StageNames and def.StageNames[(payload.Stage or 0) + 1]
				push({
					kind = "stage",
					title = string.format("STAGE %d COMPLETE", payload.Stage or 0),
					line = string.upper(tostring(payload.Name or (def and def.StageNames and def.StageNames[payload.Stage or 0]) or "")),
					sub = if nextName then "NEXT: " .. string.upper(nextName) else nil,
				})
			end
		elseif id == "BuildActivated" then
			activationRibbon(1)
		end
	end)
	local lastMilestone = tonumber(State.Get("BuildMilestone")) or 0
	State.Changed("BuildMilestone", function(v)
		local n = tonumber(v) or 0
		if n > lastMilestone and State.Get("Phase") == "Building" then
			activationRibbon(n + 1)
			local d = currentDef()
			Sound.Milestone(n, #((d and d.Milestones) or { 1 }))
		end
		lastMilestone = n
	end)

	local queued = false
	State.AnyChanged:Connect(function()
		if not queued then
			queued = true
			task.delay(0.1, function()
				queued = false
				redraw()
			end)
		end
	end)
	redraw()
	task.spawn(function()
		while true do
			task.wait(0.5)
			phaseLabel.Text = phaseText()
		end
	end)
end

return TrackerController
