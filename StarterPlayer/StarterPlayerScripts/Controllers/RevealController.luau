--!strict
-- Build reveal + milestone vote overlays.
--
-- Reveal (≈7 s, timings come from the server payload):
--   SELECTING NEXT BUILD... → rarity roll (slows and lands with a flash) → build name →
--   modifier chips (pop in) → reward multiplier + required-resource chips → fade out.
-- Vote: one card per option (thumbnail, rarity, modifiers, reward, requirements, votes);
--   your choice is outlined and marked; late joiners receive the open ballot from the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local RarityConfig = require(Shared.Config.RarityConfig)
local ColossalConfig = require(Shared.Config.ColossalConfig)
local ModifierConfig = require(Shared.Config.ModifierConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local BuildConfig = require(Shared.Config.BuildConfig)
local Format = require(Shared.Util.Format)
local Lib = script.Parent.Parent.ClientLib
local UI = require(Lib.UI)
local Sound = require(Lib.Sound)
local State = require(Lib.State)
local Site = require(Lib.Site)
local Cine = require(Lib.Cine)

local RevealController = {}
local T = UI.Theme

------------------------------------------------------------------ reveal
local overlay: Frame
local flash: Frame
local header: TextLabel
local rarityLabel: TextLabel
local nameRow: Frame
local thumbLabel: TextLabel
local nameLabel: TextLabel
local modRow: Frame
local infoRow: Frame
local pipRow: Frame
local letterbox: { Frame } = {}
local revealToken = 0

local function clearChips(row: Instance)
	for _, c in row:GetChildren() do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
end

local function popIn(inst: GuiObject, to: number?)
	local s = inst:FindFirstChildOfClass("UIScale") or UI.new("UIScale", { Parent = inst })
	s.Scale = 0.2
	UI.tween(s, UI.Anim.Normal + 0.1, { Scale = to or 1 }, Enum.EasingStyle.Back)
end

local function resourceChips(parent: Instance, requirements: { [string]: number }, size: number)
	for i, id in ResourceConfig.Order do
		local n = requirements[id]
		local res = ResourceConfig.Resources[id]
		if n and res then
			UI.chip(parent, string.format("%s %s", string.upper(ResourceConfig.RequirementLabel(id)), Format.Short(n)), UI.resourceColor(id):Lerp(Color3.new(0, 0, 0), 0.35), size, i + 1)
		end
	end
end

-- REVEAL requirements (Bible §13): at most four FAMILY totals (Wood / Stone / Metal / Power), dark plates with a family
-- swatch, instead of one multicoloured chip per grade
local FAMILY_ORDER = { "Wood", "Stone", "Metal", "Power" }
local function familyPlates(parent: Instance, requirements: { [string]: number }, size: number)
	local totals: { [string]: number } = {}
	for id, n in requirements do
		local res = ResourceConfig.Resources[id]
		if res then
			local fam = if res.Secret then "Secret" else (res.FamilyName or "Other")
			totals[fam] = (totals[fam] or 0) + n
		end
	end
	local order = table.clone(FAMILY_ORDER)
	if totals.Secret then
		table.insert(order, "Secret")
	end
	for i, fam in order do
		local n = totals[fam]
		if n then
			local f = UI.new("TextLabel", {
				Text = string.format("%s  %s", string.upper(fam), Format.Short(n)),
				Font = UI.Type.Heavy,
				TextSize = size,
				TextColor3 = UI.Tokens.Ink,
				BackgroundColor3 = UI.Tokens.PlateDeep,
				BackgroundTransparency = 0.05,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, size + 12),
				LayoutOrder = i + 1,
				Parent = parent,
			})
			UI.corner(f, 2)
			UI.stroke(f, UI.Tokens.Frame, 2)
			UI.new("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 10), Parent = f })
			UI.new("Frame", { BackgroundColor3 = UI.Family[fam] or UI.Tokens.InkDim, BackgroundTransparency = 0, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -11, 0.5, 0), Size = UDim2.fromOffset(6, size), Parent = f })
		end
	end
end

-- WORLD ACCENT for a reveal, by rarity (players keep full control; nothing is locked):
--   Common/Uncommon: none.  Rare: soft rarity-coloured screen edges.  Epic: + a small bloom lift.
--   Legendary/Mythic: ambience dips, the edges and a light grade take the rarity colour, a pillar of light rises from the platform
--   and a ground pulse rolls out, a low chime + boom and a gentle FOV ease.  Master Project: all of that, bigger and cyan, with a
--   rumble build-up and a crowd cheer when the title lands.
local function pillar(color: Color3, seconds: number, width: number)
	local p = Instance.new("Part")
	p.Name = "MB_RevealPillar"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Shape = Enum.PartType.Cylinder
	p.Material = Enum.Material.Neon
	p.Color = color
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(260, width * 0.3, width * 0.3)
	p.CFrame = CFrame.new(0, 130, 0) * CFrame.Angles(0, 0, math.rad(90))
	p.Parent = Cine.folder()
	UI.tween(p, 0.8, { Transparency = 0.82, Size = Vector3.new(260, width, width) })
	task.delay(seconds, function()
		UI.tween(p, 1.4, { Transparency = 1, Size = Vector3.new(260, width * 1.4, width * 1.4) })
		task.delay(1.5, function()
			p:Destroy()
		end)
	end)
end

local function revealAccent(rarity: any, master: boolean, hold: number)
	local order = if master then 7 else (rarity.Order or 1)
	local color = rarity.Color
	if order >= 3 and order <= 4 then
		Cine.vignette(color, if order == 4 then 0.24 else 0.16, 0.4, hold * 0.6, 1)
		if order == 4 then
			Cine.bloom(0.08, 0.3, 0.6, 0.8)
		end
	elseif order >= 5 then
		local big = order >= 7
		Cine.duck(if big then 0.2 else 0.3, 0.6, hold, 1.6)
		Cine.vignette(color, if big then 0.4 else 0.32, 0.5, hold, 1.4)
		Cine.grade({ TintColor = Color3.new(1, 1, 1):Lerp(color, if big then 0.14 else 0.1), Saturation = 0.06 }, 0.6, hold, 1.6)
		Cine.bloom(if big then 0.22 else 0.14, 0.4, hold * 0.7, 1.4)
		Cine.fov(if big then -6 else -4, 1.2, hold, 1.6)
		pillar(color, hold + 0.6, if big then 30 else 22)
		Cine.ring(Vector3.new(0, 2.4, 0), color, ColossalConfig.FrameRadius(if big then 2.5 else 1.8), if big then 2.6 else 2)
		Sound.Play("ChimeLow")
		Sound.Play("Boom", 0.05)
		if big then
			Cine.shake(0.35, 0.8)
			task.delay(0.9, function()
				Sound.Play("Cheer")
			end)
		end
	end
end

local ShowForgotten

local function show(payload: any)
	if payload.Forgotten then
		-- hidden tier: nothing identifying is revealed (??? only); the name arrives later as a personal discovery
		-- (the server addresses this reveal to each player after their personal encounter: Name = the real name, Repeat = seen before)
		task.spawn(ShowForgotten, { Hidden = payload.Name == nil, Name = payload.Name, Repeat = payload.Repeat, FakeFrom = payload.FakeFrom, Seconds = (payload.RollTime or 3) + (payload.HoldTime or 4) })
		return
	end
	revealToken += 1
	local my = revealToken
	local master = payload.MasterProject == true
	local rarity = if master then { DisplayName = "MASTER PROJECT", Color = Color3.fromRGB(120, 215, 255), RevealIntensity = 5, Order = 7 } else RarityConfig.Get(payload.Rarity)
	-- low rarities are a quick, light card that never interrupts what you are doing; Epic+ dims the screen; Legendary/Mythic
	-- also clear menus because the whole server is watching
	-- Pass 14E: any open menu is hidden (not destroyed) for the reveal and restored afterwards
	UI.suspendPanel()
	overlay.Visible = true
	UI.setMoment("Reveal", true)
	overlay.BackgroundTransparency = 1
	for _, bar in letterbox do
		bar.Visible = rarity.RevealIntensity >= 3
	end
	for _, c in pipRow:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	UI.tween(overlay, UI.Anim.Normal, { BackgroundTransparency = if rarity.RevealIntensity >= 4 then 0.4 elseif rarity.RevealIntensity >= 3 then 0.65 else 0.85 })
	header.Text = if master then "THE SERVER HAS EARNED IT..." elseif payload.Voted then "THE CREW HAS VOTED" else "ISSUING NEXT CONTRACT..."
	header.TextTransparency = 0
	header.Visible = true
	rarityLabel.Visible = true
	rarityLabel.TextTransparency = 0
	nameRow.Visible = false
	clearChips(modRow)
	clearChips(infoRow)
	infoRow.Visible = false

	-- rarity roll: ticks slow down until landing on the result
	local candidates = payload.Candidates
	if #candidates == 0 then
		candidates = { payload.Rarity }
	end
	-- environment: a cool tint over the whole world for the length of the reveal (client-side Lighting only)
	if master then
		local cc = game:GetService("Lighting"):FindFirstChild("MB_ColorCorrection") :: ColorCorrectionEffect?
		if cc then
			local orig = cc.TintColor
			UI.tween(cc, 1.2, { TintColor = Color3.fromRGB(190, 222, 255) })
			task.delay(payload.RollTime + payload.HoldTime + 0.5, function()
				UI.tween(cc, 1.6, { TintColor = orig })
			end)
		end
		Sound.Play("PowerUp")
		Sound.Play("Rumble")
		Cine.duck(0.3, 1, payload.RollTime + payload.HoldTime, 1.6)
		Cine.vignette(Color3.fromRGB(120, 215, 255), 0.22, 1.2, payload.RollTime, 0.6)
	end
	local rollTime = if payload.Voted or master then 0.4 else payload.RollTime * 0.85
	local suspense = not payload.Voted and not master
	-- (Pass 21L) SUSPENSE: the screen dims and a riser builds under a fast spin; the spin slows, then the last names tick over
	-- one by one with a heartbeat while the label swells; then a held, silent beat ("...") before the result lands.
	local tension = if suspense then math.min(2.1, rollTime * 0.45) else 0
	local spinTime = rollTime - tension - (if suspense then 0.5 else 0)
	if suspense then
		-- the riser is started part-way in so its peak lands exactly on the result
		local def = require(game:GetService("ReplicatedStorage").Shared.Config.SoundConfig).Sounds.RevealRiser
		local riser = Instance.new("Sound")
		riser.SoundId = def.SoundId
		riser.Volume = def.Volume * (0.6 + 0.08 * rarity.RevealIntensity)
		riser.Parent = game:GetService("SoundService")
		task.spawn(function()
			if not riser.IsLoaded then
				riser.Loaded:Wait()
			end
			riser.TimePosition = math.max(0, riser.TimeLength - (rollTime + 0.35))
			riser:Play()
		end)
		task.delay(rollTime + 1.5, function()
			riser:Destroy()
		end)
		UI.tween(overlay, spinTime + tension, { BackgroundTransparency = math.max(0.25, overlay.BackgroundTransparency - 0.35) })
	end
	local elapsed, i, interval = 0, 1, 0.05
	while elapsed < spinTime and suspense do
		local r = RarityConfig.Get(candidates[(i - 1) % #candidates + 1])
		rarityLabel.Text = r.DisplayName
		rarityLabel.TextColor3 = UI.Tokens.InkDim -- the roll stays neutral; only the result takes its colour (no slot machine)
		Sound.Play("RevealTick")
		task.wait(interval)
		if revealToken ~= my then
			return
		end
		elapsed += interval
		i += 1
		interval = math.min(0.3, interval * 1.13)
	end
	if suspense then
		-- the last few names, slowly, each with a heartbeat and a swell
		local steps = 3
		local rs0 = rarityLabel:FindFirstChildOfClass("UIScale") :: UIScale
		for k = 1, steps do
			local r = RarityConfig.Get(candidates[(i - 1) % #candidates + 1])
			i += 1
			rarityLabel.Text = r.DisplayName
			rarityLabel.TextColor3 = UI.Tokens.InkDim:Lerp(Color3.new(1, 1, 1), k / steps * 0.5)
			Sound.Play("RevealTick", nil, 1.3)
			Sound.Play("Heartbeat", nil, 0.7 + 0.15 * k, 0.95 + 0.05 * k)
			if rs0 then
				rs0.Scale = 1 + 0.06 * k
				UI.tween(rs0, tension / steps * 0.9, { Scale = 1 + 0.03 * k })
			end
			task.wait(tension / steps)
			if revealToken ~= my then
				return
			end
		end
		-- held silence
		rarityLabel.Text = "..."
		rarityLabel.TextColor3 = UI.Tokens.InkDim
		task.wait(0.5)
		if revealToken ~= my then
			return
		end
		if rs0 then
			rs0.Scale = 1
		end
	end
	rarityLabel.Text = rarity.DisplayName
	rarityLabel.TextColor3 = rarity.Color
	UI.rarityPlate(pipRow, rarity.DisplayName, rarity.Color, 18, 1)
	-- the pip plate sits between the rarity word and the name: it only fits when the design-space height allows (not on short phone layouts)
	local cam = workspace.CurrentCamera
	pipRow.Visible = cam == nil or cam.ViewportSize.Y / UI.scaleFor(cam.ViewportSize) >= 650
	Sound.RevealImpact(if master then "Mythic" else payload.Rarity)
	flash.BackgroundColor3 = rarity.Color
	flash.BackgroundTransparency = math.max(0.55, 0.78 - rarity.RevealIntensity * 0.045) -- a colour wash, never a white-out
	UI.tween(flash, 0.6, { BackgroundTransparency = 1 })
	revealAccent(rarity, master, math.max(2, payload.HoldTime))
	local rs = rarityLabel:FindFirstChildOfClass("UIScale") :: UIScale
	rs.Scale = 1.5
	UI.tween(rs, UI.Anim.Slow, { Scale = 1 }, Enum.EasingStyle.Back)
	local grand = rarity.RevealIntensity >= 4 -- Legendary / Mythic: a server-wide moment (an overlay only, nobody is frozen)
	if grand then
		header.Text = if master then "MASTER PROJECT" else string.upper(rarity.DisplayName) .. " CONTRACT!"
		task.spawn(function()
			for _ = 1, if rarity.RevealIntensity >= 5 then 4 else 3 do
				if revealToken ~= my then
					return
				end
				flash.BackgroundColor3 = rarity.Color
				flash.BackgroundTransparency = 0.72
				UI.tween(flash, 0.9, { BackgroundTransparency = 1 })
				Sound.Play("Discovery")
				task.wait(1.1)
			end
		end)
	end
	task.wait(payload.RollTime * 0.15 + 0.2)
	if revealToken ~= my then
		return
	end

	-- build name
	local def = BuildConfig.Get(payload.BuildId)
	header.Text = if master then "EVERYONE CAN HELP" elseif grand then string.upper(rarity.DisplayName) .. " CONTRACT AWARDED" else "CONTRACT AWARDED"
	thumbLabel.Text = "" -- pictograms only (Bible §4): no emoji glyph beside the name
	local _ = def
	nameLabel.Text = payload.Title
	nameRow.Visible = true
	popIn(nameRow, if grand then 1.35 else 1) -- the build's big glyph and name dominate the screen on a Legendary / Mythic
	task.wait(0.35)
	if revealToken ~= my then
		return
	end

	-- modifiers pop in one by one
	for k, id in payload.Modifiers do
		local m = ModifierConfig.Modifiers[id]
		if m then
			popIn(UI.chip(modRow, m.DisplayName, m.Color, 22, k))
			Sound.Play("RevealTick")
			task.wait(0.25)
		end
	end
	if revealToken ~= my then
		return
	end

	-- reward + requirements
	infoRow.Visible = true
	local rewardChip = UI.chip(infoRow, string.format("REWARD ×%.2f", payload.RewardMultiplier), UI.Tokens.Amber, 18, 0)
	rewardChip.TextColor3 = UI.Tokens.AmberInk
	popIn(rewardChip)
	familyPlates(infoRow, payload.Requirements, 18)
	task.wait(math.max(0.5, payload.HoldTime - 1.0 - #payload.Modifiers * 0.25))
	if revealToken ~= my then
		return
	end
	UI.tween(overlay, UI.Anim.Slow, { BackgroundTransparency = 1 })
	for _, l in { header, rarityLabel, thumbLabel, nameLabel } do
		UI.tween(l, UI.Anim.Slow, { TextTransparency = 1 })
	end
	task.wait(UI.Anim.Slow + 0.05)
	if revealToken ~= my then
		return
	end
	overlay.Visible = false
	UI.setMoment("Reveal", false)
	UI.resumePanel()
	for _, l in { header, rarityLabel, thumbLabel, nameLabel } do
		l.TextTransparency = 0
	end
	clearChips(modRow)
	clearChips(infoRow)
end

------------------------------------------------------------------ forgotten reveal path
-- ??? -> FORGOTTEN STRUCTURE DISCOVERED -> name. payload = { Name?, FakeFrom?, Hidden?, Seconds? }.
--   Hidden = true  : the server started a Forgotten structure; everyone only ever sees ??? (no name, no preview)
--   Name given     : this player's personal discovery; the name is revealed last
--   FakeFrom       : roll that rarity first (the fake-out): MYTHIC ... then it breaks into ???
local FORGOTTEN_TEXT = Color3.fromRGB(190, 176, 150)
ShowForgotten = function(payload: any)
	revealToken += 1
	local my = revealToken
	UI.suspendPanel()
	overlay.Visible = true
	UI.setMoment("Reveal", true)
	for _, bar in letterbox do
		bar.Visible = true
	end
	for _, c in pipRow:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	pipRow.Visible = false
	clearChips(modRow)
	clearChips(infoRow)
	infoRow.Visible = false
	nameRow.Visible = false
	overlay.BackgroundTransparency = 1
	UI.tween(overlay, UI.Anim.Normal, { BackgroundTransparency = 0.35 })
	header.Visible, header.TextTransparency = true, 0
	rarityLabel.Visible, rarityLabel.TextTransparency = true, 0
	local function stillMine(): boolean
		return revealToken == my
	end
	local function setRarity(text: string, color: Color3)
		rarityLabel.Text, rarityLabel.TextColor3 = text, color
		local rs = rarityLabel:FindFirstChildOfClass("UIScale") :: UIScale
		rs.Scale = 1.35
		UI.tween(rs, UI.Anim.Slow, { Scale = 1 })
	end
	-- optional fake-out: a normal-looking high rarity first
	if payload.FakeFrom then
		local r = RarityConfig.Get(payload.FakeFrom)
		header.Text = "ISSUING NEXT CONTRACT..."
		setRarity(r.DisplayName, r.Color)
		Sound.RevealImpact(payload.FakeFrom)
		task.wait(1.6)
		if not stillMine() then
			return
		end
		-- it breaks
		for _ = 1, 3 do
			rarityLabel.TextTransparency = 0.7
			task.wait(0.08)
			rarityLabel.TextTransparency = 0
			task.wait(0.08)
		end
		Sound.Play("Boom")
		Cine.shake(0.3, 0.6)
	end
	header.Text = "SOMETHING IS WRONG..."
	setRarity("???", UI.Tokens.InkDim)
	Sound.Cue("Glitch")
	Sound.Play("Rumble", nil, 0.7, 0.8)
	task.wait(if payload.Hidden then math.max(2, (payload.Seconds or 4) - (if payload.FakeFrom then 2.2 else 0.5)) else 1.8)
	if not stillMine() then
		return
	end
	if not payload.Hidden then
		header.Text = if payload.Repeat then "FORGOTTEN STRUCTURE" else "FORGOTTEN STRUCTURE DISCOVERED"
		header.TextColor3 = FORGOTTEN_TEXT
		setRarity("FORGOTTEN", FORGOTTEN_TEXT)
		Sound.Cue("ForgottenDiscover")
		Cine.vignette(FORGOTTEN_TEXT, 0.34, 0.5, 3.5, 1.4)
		Cine.bloom(0.1, 0.4, 2.5, 1.2)
		task.wait(1.6)
		if not stillMine() then
			return
		end
		thumbLabel.Text = ""
		nameLabel.Text = string.upper(payload.Name or "???")
		nameRow.Visible = true
		popIn(nameRow, 1.35)
		task.wait(3.6)
		if not stillMine() then
			return
		end
		header.TextColor3 = T.SubText
	end
	UI.tween(overlay, UI.Anim.Slow, { BackgroundTransparency = 1 })
	for _, l in { header, rarityLabel, thumbLabel, nameLabel } do
		UI.tween(l, UI.Anim.Slow, { TextTransparency = 1 })
	end
	task.wait(UI.Anim.Slow + 0.05)
	if not stillMine() then
		return
	end
	overlay.Visible = false
	UI.setMoment("Reveal", false)
	UI.resumePanel()
	for _, l in { header, rarityLabel, thumbLabel, nameLabel } do
		l.TextTransparency = 0
	end
	clearChips(modRow)
	clearChips(infoRow)
end

------------------------------------------------------------------ vote
local voteFrame: Frame
local voteRow: Frame
local voteTimer: TextLabel
local voteBanner: TextLabel
local cards: { { frame: Frame, stroke: UIStroke, button: TextButton, count: TextLabel, fill: Frame, tag: TextLabel } } = {}
local myVote: number? = nil
local voteOpen = false

local function updateSelection()
	for i, c in cards do
		local mine = myVote == i
		c.stroke.Thickness = if mine then 4 else 2
		c.stroke.Color = if mine then T.Accent else T.Stroke
		c.tag.Visible = mine
		c.button.Text = if mine then "VOTED" else "VOTE"
		c.button.BackgroundColor3 = if mine then T.Accent else Site.Color.SteelLight
		c.button.TextColor3 = if mine then Site.Color.HazardDark else T.Text
	end
end

local function buildVote(payload: any)
	for _, c in cards do
		c.frame:Destroy()
	end
	cards = {}
	myVote = nil
	local n = #payload.Options
	for i, opt in payload.Options do
		local def = BuildConfig.Get(opt.BuildId)
		local r = RarityConfig.Get(opt.Rarity)
		local card = UI.card({
			Name = "Card" .. i,
			Size = UDim2.new(1 / n, -14 * (n - 1) / n, 1, 0),
			LayoutOrder = i,
			Parent = voteRow,
		})
		local stroke = card:FindFirstChildOfClass("UIStroke") :: UIStroke
		-- thumbnail panel tinted by rarity
		local thumb = UI.new("Frame", {
			BackgroundColor3 = Site.Color.Blueprint,
			BackgroundTransparency = 0,
			Size = UDim2.new(1, -12, 0, 78),
			Position = UDim2.fromOffset(6, 12),
			Parent = card,
		})
		UI.corner(thumb, 3)
		UI.stroke(thumb, r.Color, 2)
		UI.new("TextLabel", { Text = "PROPOSAL " .. string.char(64 + i), Font = T.Bold, TextSize = 11, TextColor3 = Site.Color.BlueprintLine, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(6, 3), Size = UDim2.fromOffset(90, 14), Parent = thumb })
		UI.new("TextLabel", { Text = def and def.Thumbnail or "?", TextSize = 46, Size = UDim2.fromScale(1, 1), Parent = thumb })
		local rewardChip = UI.chip(thumb, string.format("x%.2f", opt.RewardMultiplier or 1), T.Accent, 15, 0)
		rewardChip.AnchorPoint = Vector2.new(1, 0)
		rewardChip.Position = UDim2.new(1, -5, 0, 5)
		rewardChip.TextColor3 = Site.Color.HazardDark
		-- rarity + modifier chips
		local chipRow = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 96), Size = UDim2.new(1, -12, 0, 20), Parent = card })
		UI.list(chipRow, 4, true, Enum.HorizontalAlignment.Center)
		UI.chip(chipRow, r.DisplayName, r.Color, 12, 1)
		for k, id in opt.Modifiers do
			local m = ModifierConfig.Modifiers[id]
			if m then
				UI.chip(chipRow, m.DisplayName, m.Color, 12, 1 + k)
			end
		end
		local title = UI.new("TextLabel", {
			Text = opt.Title or (def and def.DisplayName) or opt.BuildId,
			Font = T.Title,
			TextScaled = true,
			TextWrapped = true,
			Position = UDim2.fromOffset(6, 118),
			Size = UDim2.new(1, -12, 0, 42),
			Parent = card,
		})
		UI.new("UITextSizeConstraint", { MaxTextSize = 22, MinTextSize = 11, Parent = title })
		-- requirements
		local need = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 162), Size = UDim2.new(1, -12, 0, 44), Parent = card })
		local wrap = UI.list(need, 3, true, Enum.HorizontalAlignment.Center)
		wrap.Wraps = true
		resourceChips(need, opt.Requirements or {}, 12)
		-- votes
		local barBg = UI.new("Frame", { BackgroundColor3 = Site.Color.SteelDark, Position = UDim2.new(0, 8, 1, -82), Size = UDim2.new(1, -16, 0, 10), Parent = card })
		UI.corner(barBg, 2)
		local fill = UI.new("Frame", { BackgroundColor3 = r.Color, Size = UDim2.fromScale(0, 1), Parent = barBg })
		UI.corner(fill, 2)
		local count = UI.new("TextLabel", { Text = "0 votes", Font = T.Bold, TextSize = 13, TextColor3 = T.SubText, Position = UDim2.new(0, 0, 1, -70), Size = UDim2.new(1, 0, 0, 16), Parent = card })
		local button = UI.button({
			Name = "VoteButton",
			Text = "VOTE",
			TextSize = 19,
			BackgroundColor3 = Site.Color.SteelLight,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -16, 0, 36),
			Parent = card,
		}, function()
			if not voteOpen then
				return
			end
			myVote = i
			Net.Event("VoteCast"):FireServer(i)
			updateSelection()
		end)
		local tag = UI.chip(card, "YOUR VOTE", T.Accent, 11, 0)
		tag.TextColor3 = Site.Color.HazardDark
		tag.AnchorPoint = Vector2.new(0.5, 0.5)
		tag.Position = UDim2.new(0.5, 0, 0, 0)
		tag.Visible = false
		tag.ZIndex = 5
		cards[i] = { frame = card, stroke = stroke, button = button, count = count, fill = fill, tag = tag }
	end
end

local function updateTallies(payload: any)
	local total = 0
	for _, v in payload.Tallies do
		total += v
	end
	for i, c in cards do
		local n = payload.Tallies[i] or 0
		c.count.Text = n .. (if n == 1 then " vote" else " votes")
		UI.tween(c.fill, UI.Anim.Normal, { Size = UDim2.fromScale(if total > 0 then n / total else 0, 1) })
	end
end

local function onVote(payload: any)
	if payload.State == "Open" then
		-- also handles late joiners: the server sends the current ballot on join
		voteOpen = true
		UI.closePanel()
		buildVote(payload)
		updateTallies(payload)
		voteBanner.Visible = false
		voteFrame.Visible = true
		Sound.Play("EventStart")
	elseif payload.State == "Update" then
		updateTallies(payload)
	elseif payload.State == "Closed" then
		voteOpen = false
		updateTallies(payload)
		local winner = cards[payload.Winner]
		for i, c in cards do
			if i == payload.Winner then
				c.stroke.Color = T.Good
				c.stroke.Thickness = 6
			else
				c.frame.BackgroundTransparency = 0.6
			end
			c.button.Visible = false
		end
		local opt = payload.Options[payload.Winner]
		voteBanner.Text = "CONTRACT AWARDED: " .. tostring(opt and (opt.Title or opt.BuildId) or "")
		voteBanner.Visible = true
		local _ = winner
		task.delay(2.4, function()
			if not voteOpen then
				voteFrame.Visible = false
			end
		end)
	end
end

function RevealController.Start()
	local g = UI.root("Reveal", 6)
	overlay = UI.new("Frame", { Name = "RevealOverlay", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 80), Position = UDim2.fromOffset(0, -60), Visible = false, Parent = g })
	flash = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = overlay })
	-- letterbox (Rare+): plate-coloured bars with a thin hazard edge on the inner side only (Bible §13)
	local topBar = UI.new("Frame", { Name = "LetterTop", BackgroundColor3 = UI.Tokens.Plate, BackgroundTransparency = 0.05, Size = UDim2.new(1, 0, 0.01, 36), Parent = overlay })
	local th = Site.hazard(topBar, 4)
	th.AnchorPoint = Vector2.new(0, 1)
	th.Position = UDim2.fromScale(0, 1)
	local botBar = UI.new("Frame", { Name = "LetterBottom", BackgroundColor3 = UI.Tokens.Plate, BackgroundTransparency = 0.05, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0.01, 12), Parent = overlay })
	Site.hazard(botBar, 4).Position = UDim2.fromScale(0, 0)
	letterbox = { topBar, botBar }
	header = UI.new("TextLabel", { Font = T.Title, TextSize = 24, TextColor3 = T.SubText, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.26), Size = UDim2.fromOffset(800, 40), Parent = overlay })
	UI.textStroke(header, 2)
	rarityLabel = UI.new("TextLabel", { Font = T.Title, TextSize = 88, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.38), Size = UDim2.fromOffset(900, 100), Parent = overlay })
	UI.new("UIStroke", { Color = T.Stroke, Thickness = 3, Transparency = 0.1, Parent = rarityLabel })
	UI.new("UIScale", { Parent = rarityLabel })
	pipRow = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.38, 60), Size = UDim2.fromOffset(400, 30), Parent = overlay })
	UI.list(pipRow, 0, true, Enum.HorizontalAlignment.Center).VerticalAlignment = Enum.VerticalAlignment.Center
	nameRow = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.new(0.9, 0, 0, 64), Visible = false, Parent = overlay })
	local nrSize = Instance.new("UISizeConstraint")
	nrSize.MaxSize = Vector2.new(1100, 64)
	nrSize.Parent = nameRow
	thumbLabel = UI.new("TextLabel", { TextSize = 52, Size = UDim2.new(0, 70, 1, 0), Parent = nameRow })
	-- the name is centred under the rarity; the build glyph sits just left of the text (placed from TextBounds)
	nameLabel = UI.new("TextLabel", { Font = T.Title, TextScaled = true, Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Center, Parent = nameRow })
	nameLabel:GetPropertyChangedSignal("TextBounds"):Connect(function()
		thumbLabel.AnchorPoint = Vector2.new(1, 0)
		thumbLabel.Position = UDim2.new(0.5, -nameLabel.TextBounds.X / 2 - 6, 0, 0)
	end)
	UI.new("UITextSizeConstraint", { MaxTextSize = 56, MinTextSize = 18, Parent = nameLabel })
	UI.new("UIStroke", { Color = T.Stroke, Thickness = 2.5, Transparency = 0.1, Parent = nameLabel })
	modRow = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.61), Size = UDim2.new(0.9, 0, 0, 36), Parent = overlay })
	UI.list(modRow, 8, true, Enum.HorizontalAlignment.Center)
	infoRow = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.70), Size = UDim2.new(0.9, 0, 0, 64), Visible = false, Parent = overlay })
	UI.list(infoRow, 6, true, Enum.HorizontalAlignment.Center).Wraps = true

	-- vote overlay
	voteFrame = UI.new("Frame", { Name = "VoteOverlay", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.new(1, 0, 1, 80), Position = UDim2.fromOffset(0, -60), Visible = false, Parent = g })
	local title = UI.new("TextLabel", { Text = "MILESTONE VOTE  -  CHOOSE THE NEXT CONTRACT", Font = T.Title, TextSize = 34, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.12), Size = UDim2.fromOffset(700, 44), Parent = voteFrame })
	Site.hazard(voteFrame, 8).Position = UDim2.fromOffset(0, 60)
	voteRow = UI.new("Frame", { Name = "VoteRow", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.92, 0, 0, 310), Parent = voteFrame })
	local rowLimit = Instance.new("UISizeConstraint")
	rowLimit.MaxSize = Vector2.new(860, 310)
	rowLimit.Parent = voteRow
	UI.list(voteRow, 14, true, Enum.HorizontalAlignment.Center)
	voteTimer = UI.new("TextLabel", { Font = T.Title, TextSize = 24, TextColor3 = T.Accent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.86), Size = UDim2.fromOffset(500, 32), Parent = voteFrame })
	UI.textStroke(voteTimer, 2)
	voteBanner = UI.new("TextLabel", { Font = T.Title, TextSize = 36, TextColor3 = T.Good, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.86), Size = UDim2.fromOffset(800, 44), Visible = false, Parent = voteFrame })
	UI.textStroke(voteBanner, 2.5)
	task.spawn(function()
		while true do
			task.wait(0.25)
			if voteFrame.Visible and voteOpen then
				voteTimer.Text = "Voting ends in " .. Format.Time((State.Get("PhaseEndsAt") or 0) - State.ServerNow())
			end
			voteTimer.Visible = voteOpen
		end
	end)

	Net.Event("Reveal").OnClientEvent:Connect(function(payload)
		task.spawn(show, payload)
	end)
	Net.Event("VoteState").OnClientEvent:Connect(onVote)
	-- personal Forgotten discovery (sent only to the player who just discovered it)
	Net.Event("Effect").OnClientEvent:Connect(function(id, payload)
		if id == "ForgottenDiscovered" and type(payload) == "table" and payload.Play then -- dev/framework replay only
			task.spawn(ShowForgotten, { Name = payload.Name, FakeFrom = payload.FakeFrom })
		end
	end)
	-- safety: if the phase moves on while a ballot is on screen (server skipped/aborted), clear it
	State.Changed("Phase", function(phase)
		if phase ~= "Voting" and voteOpen then
			voteOpen = false
			voteFrame.Visible = false
		end
	end)
end

return RevealController
