--!strict
-- Training Yard client. The server decides everything (who is on which machine, XP, deliveries); this only:
--   * shows a small session panel for hands-off training (Treadmill / Bench Press) with a STOP button,
--   * plays the machine animations for EVERY occupied machine (local-only procedural tracks), moves the barbell and
--     scrolls the treadmill belt,
--   * shows the carry banner / delivery feedback for the active tasks (Crate Lift, Beam Carry),
--   * highlights the next race-track gate.
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local TrainingConfig = require(Shared.Config.TrainingConfig)
local Lib = script.Parent.Parent.ClientLib
local UI = require(Lib.UI)
local Site = require(Lib.Site)
local Sound = require(Lib.Sound)
local TrainingAnimations = require(Lib.TrainingAnimations)
local Notify = require(script.Parent.NotifyController)

local TrainingController = {}
local T = UI.Theme
local player = Players.LocalPlayer

local panel: Frame
local titleLabel: TextLabel
local infoLabel: TextLabel
local totalLabel: TextLabel
local staminaFill: Frame
local carryBanner: TextLabel
local active = false

local LABEL = {
	Treadmill = { "TREADMILL", "SPEED  -  hands-off" },
	Bench = { "BENCH PRESS", "STRENGTH  -  hands-off" },
}

local function setStamina(f: number)
	staminaFill.Size = UDim2.fromScale(math.clamp(1 - f, 0, 1), 1)
	staminaFill.BackgroundColor3 = if f > 0.7 then T.Bad elseif f > 0.4 then T.Warn else T.Good
end

local function stopTraining()
	Net.Event("TrainingRequest"):FireServer("Stop")
end

local function bindStopKey()
	ContextActionService:BindActionAtPriority("MB_TrainStop", function(_, state)
		if state == Enum.UserInputState.Begin then
			stopTraining()
		end
		return Enum.ContextActionResult.Sink
	end, false, 2500, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
end

local function build()
	local g = UI.root("Training", 4)
	panel = UI.card({
		Name = "TrainingPanel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.fromOffset(380, 112),
		Visible = false,
		Parent = g,
	})
	panel.ClipsDescendants = true
	Site.hazard(panel, 4)
	titleLabel = UI.new("TextLabel", { Text = "TRAINING", Font = T.Title, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -90, 0, 20), Parent = panel })
	infoLabel = UI.new("TextLabel", { Text = "", Font = T.Bold, TextSize = 12, TextColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(14, 32), Size = UDim2.new(1, -28, 0, 16), Parent = panel })
	UI.button({ Name = "Stop", Text = "STOP", TextSize = 13, BackgroundColor3 = Site.Color.SteelLight, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(60, 24), Parent = panel }, stopTraining)
	totalLabel = UI.new("TextLabel", { Text = "+0 XP", Font = T.Title, TextSize = 22, TextColor3 = T.Accent, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(14, 52), Size = UDim2.fromOffset(150, 26), Parent = panel })
	UI.new("TextLabel", { Text = "STAMINA", Font = T.Bold, TextSize = 11, TextColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(14, 84), Size = UDim2.fromOffset(60, 14), Parent = panel })
	local sta = UI.new("Frame", { BackgroundColor3 = Site.Color.SteelDark, Position = UDim2.fromOffset(76, 86), Size = UDim2.new(1, -180, 0, 10), Parent = panel })
	UI.corner(sta, 2)
	UI.stroke(sta, T.Stroke, 1.5)
	staminaFill = UI.new("Frame", { BackgroundColor3 = T.Good, Size = UDim2.fromScale(1, 1), Parent = sta })
	UI.new("TextLabel", { Name = "GetOffHint", Text = "SPACE to get off", Font = T.Bold, TextSize = 11, TextColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 84), Size = UDim2.fromOffset(90, 14), Parent = panel })
	carryBanner = UI.new("TextLabel", {
		Name = "CarryBanner",
		Text = "",
		Font = T.Title,
		TextSize = 18,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = Color3.fromRGB(40, 36, 30),
		BackgroundTransparency = 0.1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.fromOffset(340, 34),
		Visible = false,
		Parent = g,
	})
	UI.corner(carryBanner, 4)
	UI.stroke(carryBanner, T.Accent, 2)
end

-- STRENGTH CARRY ZONES (client only). Every crate/beam pickup stack and drop pallet gets a soft glowing pad: a
-- shimmering ForceField floor, a slowly pulsing rim and a few rising sparkles. Pickups glow gently while you are free;
-- while you carry something, the pallets that accept it glow brighter and pulse, so it reads as "carry this here".
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local PICK_COLOR = Color3.fromRGB(110, 220, 255)
local DROP_COLOR = Color3.fromRGB(255, 196, 70)
type Zone = { part: BasePart, kind: string, pickup: boolean, lane: number, floor: BasePart, rim: BasePart, light: PointLight, sparkles: ParticleEmitter, hl: Highlight }
local zones: { Zone } = {}
local carrying: string? = nil
local carryLane = 1

local function makeZone(part: BasePart, kind: string, pickup: boolean)
	local color = if pickup then PICK_COLOR else DROP_COLOR
	local folder = workspace:FindFirstChild("MB_TrainingZones") or Instance.new("Folder")
	folder.Name = "MB_TrainingZones"
	folder.Parent = workspace
	local footprint = Vector2.new(math.max(part.Size.X, 4) + 3, math.max(part.Size.Z, 4) + 3)
	local groundY = part.Position.Y - part.Size.Y / 2
	local base = CFrame.new(part.Position.X, groundY, part.Position.Z) * part.CFrame.Rotation
	local floor = Instance.new("Part")
	floor.Name = "ZoneFloor"
	floor.Anchored, floor.CanCollide, floor.CanQuery, floor.CanTouch = true, false, false, false
	floor.Size = Vector3.new(footprint.X, 0.12, footprint.Y)
	floor.CFrame = base * CFrame.new(0, 0.1, 0)
	floor.Material = Enum.Material.ForceField
	floor.Color = color
	floor.Transparency = 0.2
	floor.Parent = folder
	local rim = Instance.new("Part")
	rim.Name = "ZoneRim"
	rim.Anchored, rim.CanCollide, rim.CanQuery, rim.CanTouch = true, false, false, false
	rim.Size = Vector3.new(footprint.X + 1, 1.6, footprint.Y + 1)
	rim.CFrame = base * CFrame.new(0, 0.8, 0)
	rim.Material = Enum.Material.ForceField
	rim.Color = color
	rim.Transparency = 0.6
	rim.Parent = folder
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 12
	light.Brightness = 0.3
	light.Shadows = false
	light.Parent = floor
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLE
	e.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	e.LightEmission = 0.5
	e.Rate = 2
	e.Lifetime = NumberRange.new(1.4, 2.2)
	e.Speed = NumberRange.new(1.5, 3)
	e.SpreadAngle = Vector2.new(10, 10)
	e.EmissionDirection = Enum.NormalId.Top
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Parent = floor
	-- a soft fill on the drop pallet itself while it is your target (off otherwise)
	local hl = Instance.new("Highlight")
	hl.Adornee = part
	hl.FillColor = color
	hl.OutlineColor = color
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Enabled = false
	hl.Parent = floor
	table.insert(zones, { part = part, kind = kind, pickup = pickup, lane = (part:GetAttribute("Lane") :: number?) or 1, floor = floor, rim = rim, light = light, sparkles = e, hl = hl })
end

-- how strongly each zone should call for attention right now (0 quiet .. 1 "bring it here")
local function zoneWeight(z: Zone): number
	if carrying then
		if not z.pickup and z.kind == carrying and z.lane == carryLane then
			return 1
		end
		return 0
	end
	return if z.pickup then 0.45 else 0.15
end

local function updateZones()
	local t = os.clock()
	for _, z in zones do
		local w = zoneWeight(z)
		local pulse = 0.5 + 0.5 * math.sin(t * (if w >= 1 then 4 else 1.6))
		z.floor.Transparency = 0.55 - 0.5 * w - 0.08 * pulse * w
		z.rim.Transparency = 0.9 - (0.45 + 0.25 * pulse) * w
		z.light.Brightness = (0.4 + 0.8 * pulse) * w
		z.sparkles.Rate = if w >= 1 then 14 elseif w > 0.3 then 3 else 0
		z.hl.Enabled = w >= 1
		if w >= 1 then
			z.hl.FillTransparency = 0.45 + 0.3 * pulse
			z.hl.OutlineTransparency = 0.15 + 0.3 * pulse
		end
	end
end

local function nearestZone(pickup: boolean): Zone?
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return nil
	end
	local best, bd = nil, math.huge
	for _, z in zones do
		if z.pickup == pickup then
			local d = (z.part.Position - hrp.Position).Magnitude
			if d < bd then
				best, bd = z, d
			end
		end
	end
	return best
end

-- a short soft burst of sparkles at a point
local function myMachine(tagName: string): BasePart?
	for _, inst in CollectionService:GetTagged(tagName) do
		if inst:IsA("BasePart") and inst:GetAttribute("Occupant") == player.UserId then
			return inst
		end
	end
	return nil
end

local function softBurst(pos: Vector3, color: Color3, count: number)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = pos
	p.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLE
	e.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	e.LightEmission = 0.6
	e.Rate = 0
	e.Lifetime = NumberRange.new(0.6, 1)
	e.Speed = NumberRange.new(6, 12)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 3
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = p
	e:Emit(count)
	task.delay(1.5, function()
		p:Destroy()
	end)
end

-- floating "+7.5 Strength XP" over a point in the world
local function xpPop(pos: Vector3, text: string, color: Color3?)
	local a = Instance.new("Part")
	a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch = true, false, false, false
	a.Transparency = 1
	a.Size = Vector3.one
	a.Position = pos
	a.Parent = workspace
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 40)
	bb.StudsOffset = Vector3.new(0, 2, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = a
	local l = UI.new("TextLabel", {
		Text = text,
		Font = T.Title,
		TextSize = 26,
		-- same motion language as the coin popup (pop, float, fade); Speed XP reads cool, Strength XP warm
		TextColor3 = color or (if string.find(text, "Speed") then Color3.fromRGB(140, 220, 255) else Color3.fromRGB(255, 196, 92)),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = bb,
	})
	UI.textStroke(l, 2)
	local pop = UI.new("UIScale", { Scale = 0.6, Parent = l })
	UI.tween(pop, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	UI.tween(bb, 1.2, { StudsOffset = Vector3.new(0, 6, 0) }, Enum.EasingStyle.Quad)
	task.delay(0.6, function()
		UI.tween(l, 0.6, { TextTransparency = 1 })
		local s = l:FindFirstChildOfClass("UIStroke")
		if s then
			UI.tween(s, 0.6, { Transparency = 1 })
		end
	end)
	task.delay(1.3, function()
		a:Destroy()
	end)
end

local function setupZones()
	for _, spec in { { "CrateStack", "Crate", true }, { "CratePallet", "Crate", false }, { "BeamStack", "Beam", true }, { "BeamPallet", "Beam", false } } do
		for _, p in CollectionService:GetTagged(spec[1]) do
			if p:IsA("BasePart") then
				makeZone(p, spec[2], spec[3])
			end
		end
	end
	RunService.RenderStepped:Connect(updateZones)
end

local function onUpdate(msg: any)
	if type(msg) ~= "table" then
		return
	end
	if msg.Type == "Start" then
		active = true
		local l = LABEL[msg.Kind] or { "TRAINING", "" }
		titleLabel.Text = l[1]
		infoLabel.Text = l[2]
		totalLabel.Text = "+0 XP"
		setStamina(msg.Fatigue or 0)
		panel.Visible = true
		if msg.Kind == "Treadmill" then
			Sound.Cue("TreadStart")
		else
			Sound.Play("Click")
		end
		bindStopKey()
	elseif msg.Type == "Tick" and active then
		totalLabel.Text = string.format("+%.0f %s XP", msg.Total or 0, msg.Stat or "")
		setStamina(msg.Fatigue or 0)
		-- a tick sound whose pitch climbs with the machine's level, plus a floating "+N XP" and a spark burst in the tier colour
		local isTread = msg.Kind == "Treadmill"
		local m = myMachine(if isTread then "TrainingTreadmill" else "TrainingBench")
		local tiers = (if isTread then TrainingConfig.Treadmill else TrainingConfig.Bench).Tiers
		local lvl = if m then math.clamp(math.floor((m:GetAttribute("Level") :: number?) or 1), 1, #tiers) else 1
		Sound.Play(if isTread then "TreadTick" else "BenchRep", 0.02, nil, 1 + 0.1 * (lvl - 1))
		if m then
			xpPop(m.Position + Vector3.new(0, 4, 0), string.format("+%.1f %s XP", msg.XP or 0, msg.Stat or ""), tiers[lvl].Color)
			softBurst(m.Position + Vector3.new(0, 3, 0), tiers[lvl].Color, 10)
		end
	elseif msg.Type == "Carry" then
		if msg.Kind then
			carrying = msg.Kind
			local z = nearestZone(true)
			carryLane = if z then z.lane else 1
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				softBurst(hrp.Position, PICK_COLOR, 14)
			end
			Sound.Cue(if msg.Kind == "Beam" then "BeamLift" else "CrateLift")
			carryBanner.Visible = true
			carryBanner.Text = if msg.Kind == "Beam" then "BEAM  -  walk onto the far pad" else "CRATE  -  walk onto the pad"
			bindStopKey()
		else
			carrying = nil
			carryBanner.Visible = false
			if not active then
				ContextActionService:UnbindAction("MB_TrainStop")
			end
		end
	elseif msg.Type == "Deliver" then
		setStamina(msg.Fatigue or 0)
		carrying = nil
		local z = nearestZone(false)
		local at = if z then z.part.Position + Vector3.new(0, z.part.Size.Y / 2, 0) else nil
		if at then
			softBurst(at, DROP_COLOR, 22)
			xpPop(at, string.format("+%.1f %s XP", msg.XP or 0, msg.Stat or "Strength"))
		end
		Sound.Cue(if msg.Kind == "Beam" then "BeamDrop" else "CrateDrop")
	elseif msg.Type == "Lap" then
		Notify.Show("Info", string.format("Lap complete  +%.0f Speed XP", msg.XP), 2)
		Sound.Cue("LapDone")
	elseif msg.Type == "End" then
		if active then
			Sound.Cue("TreadStop")
		end
		active = false
		panel.Visible = false
		ContextActionService:UnbindAction("MB_TrainStop")
		if type(msg.Reason) == "string" and msg.Reason ~= "" then
			Notify.Show("Info", msg.Reason, 3)
		end
	end
end

-- Highlight the gate the runner must reach next (set locally from the TrainGate attribute).
local highlight: Highlight? = nil
local lastGateWant = 0
local function updateGate()
	local want = player:GetAttribute("TrainGate") or 0
	if want > 0 and want ~= lastGateWant then
		Sound.Play("GateTick", 0.02, nil, 1 + 0.08 * (want - 1)) -- each gate a little higher: a rising run
	end
	lastGateWant = want
	if highlight then
		highlight:Destroy()
		highlight = nil
	end
	if want <= 0 then
		return
	end
	for _, g in CollectionService:GetTagged("TrainingGate") do
		if g:GetAttribute("GateIndex") == want and g.Parent then
			local h = Instance.new("Highlight")
			h.FillColor = T.Accent
			h.OutlineColor = Color3.new(1, 1, 1)
			h.FillTransparency = 0.5
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.Adornee = if g.Parent:IsA("Model") then g.Parent else g
			h.Parent = g
			highlight = h
			return
		end
	end
end

------------------------------------------------------------------ machine visuals (all occupied machines, all clients)
type Playing = { userId: number, track: AnimationTrack?, character: Model? }
local playing: { [BasePart]: Playing } = {}
local barBase: { [Model]: CFrame } = {}
local ridgeBase: { [BasePart]: CFrame } = {}

local function playerByUserId(id: number): Player?
	return Players:GetPlayerByUserId(id)
end

local function stopMachine(part: BasePart)
	local p = playing[part]
	if p and p.track then
		p.track:Stop(0.2)
	end
	playing[part] = nil
	-- the barbell goes back to its rack position when the lifter leaves
	local bar = part.Parent and part.Parent:FindFirstChild("Barbell")
	if bar and bar:IsA("Model") and barBase[bar] then
		bar:PivotTo(barBase[bar])
	end
end

-- (Pass 21D) flashy running treadmills: neon trim pulses, speed sparks + streaks fire and the tier light brightens while somebody runs
local fxOn: { [BasePart]: boolean } = {}
local function setTreadFX(part: BasePart, on: boolean, now: number)
	local model = part.Parent
	if not model or (not on and not fxOn[part]) then
		return
	end
	fxOn[part] = if on then true else nil
	local phase = 0
	for _, d in model:GetChildren() do
		if d.Name == "Glow" and d:IsA("BasePart") then
			phase += 0.7
			d.Transparency = if on then 0.05 + 0.4 * (0.5 + 0.5 * math.sin(now * 11 - phase)) else 0
		end
	end
	for _, d in part:GetChildren() do
		if d:IsA("ParticleEmitter") then
			d.Enabled = on
		elseif d:IsA("PointLight") then
			d.Brightness = if on then 1.4 + 0.5 * math.sin(now * 9) else 0.5
		end
	end
end

local function updateMachines(now: number)
	for kind, tagName in { Treadmill = "TrainingTreadmill", Bench = "TrainingBench" } do
		for _, inst in CollectionService:GetTagged(tagName) do
			local part = inst :: BasePart
			local occ = part:GetAttribute("Occupant")
			local cur = playing[part]
			if cur and (occ ~= cur.userId or not cur.character or not cur.character.Parent) then
				stopMachine(part)
				cur = nil
			end
			if type(occ) == "number" and not cur then
				local plr = playerByUserId(occ)
				local char = plr and plr.Character
				if char and char:FindFirstChildOfClass("Humanoid") then
					playing[part] = { userId = occ, track = TrainingAnimations.Play(char, kind), character = char }
				end
			end
			setTreadFX(part, playing[part] ~= nil, now)
			if playing[part] then
				if kind == "Treadmill" then
					-- belt ridges scroll toward the back so it reads as a moving belt under the runner
					local model = part.Parent
					if model then
						for _, ridge in model:GetChildren() do
							if ridge.Name == "Ridge" and ridge:IsA("BasePart") then
								local base = ridgeBase[ridge]
								if not base then
									base = ridge.CFrame
									ridgeBase[ridge] = base
								end
								local rel = part.CFrame:ToObjectSpace(base).Position.Z
								local shifted = ((rel + 5 + now * 7) % 12) - 5.5
								ridge.CFrame = part.CFrame * CFrame.new(0, part.Size.Y / 2 + 0.05, shifted)
							end
						end
					end
				else
					-- the barbell follows the press: low at the chest, high at lock-out
					local bar = part.Parent and part.Parent:FindFirstChild("Barbell")
					if bar and bar:IsA("Model") then
						barBase[bar] = barBase[bar] or bar:GetPivot()
						local base = barBase[bar]
						local char = playing[part].character
						local rh, lh = char and char:FindFirstChild("RightHand"), char and char:FindFirstChild("LeftHand")
						if rh and lh and rh:IsA("BasePart") and lh:IsA("BasePart") then
							-- the bar rides the lifter's actual hands, so bar and arms always move together
							local handY = (rh.Position.Y + lh.Position.Y) / 2
							bar:PivotTo(CFrame.new(base.Position.X, handY + 0.3, base.Position.Z) * base.Rotation)
						end
					end
				end
			end
		end
	end
end

-- crate / beam carries: the server welds the prop and publishes Player attribute TrainCarry ("Crate" | "Beam"); every client plays the
-- matching carrying-arms pose on that player's character (it only poses the torso and arms, so the normal run / walk cycle keeps
-- playing underneath) and stops it the moment the carry ends, the character respawns or the player leaves
local carryTracks: { [Player]: { kind: string, track: AnimationTrack, character: Model } } = {}
local function updateCarries()
	for _, plr in Players:GetPlayers() do
		local kind = plr:GetAttribute("TrainCarry")
		local char = plr.Character
		local cur = carryTracks[plr]
		if cur and (cur.kind ~= kind or cur.character ~= char or not char or not char.Parent) then
			cur.track:Stop(0.2)
			carryTracks[plr] = nil
			cur = nil
		end
		if (kind == "Crate" or kind == "Beam") and char and char.Parent and not cur then
			local t = TrainingAnimations.Play(char, "Carry" .. kind, true)
			if t then
				carryTracks[plr] = { kind = kind, track = t, character = char }
			end
		end
	end
	for plr, cur in carryTracks do
		if not plr.Parent then
			cur.track:Stop(0)
			carryTracks[plr] = nil
		end
	end
end

-- (Pass 21B) the training panel and the carry banner shrink on phones / tablets and sit lower so the world stays visible
local function applyCompact()
	local phone = UI.Mode == "phone"
	local scale = if phone then (if UI.Portrait then 0.85 else 0.72) elseif UI.Mode == "tablet" then 0.84 else 1
	local bottom = if phone then -96 elseif UI.Mode == "tablet" then -120 else -150
	for _, gui in { panel, carryBanner } do
		local sc = gui:FindFirstChild("CompactScale") :: UIScale?
		if not sc then
			sc = UI.new("UIScale", { Name = "CompactScale", Parent = gui }) :: UIScale
		end
		(sc :: UIScale).Scale = scale
		gui.Position = UDim2.new(0.5, 0, 1, bottom)
	end
	local hint = panel:FindFirstChild("GetOffHint")
	if hint then
		(hint :: TextLabel).Text = if phone then "Tap jump to get off" else "SPACE to get off"
		(hint :: TextLabel).Size = UDim2.fromOffset(if phone then 120 else 90, 14)
	end
end

-- (Pass 21C) a small sign over every treadmill: its level and the Master Builder rank it needs (green = you can use it, red = locked)
local function setupTreadmillSigns()
	local State = require(Lib.State)
	local signs: { { gui: BillboardGui, label: TextLabel, part: BasePart, kind: string } } = {}
	local function rankNow(): number
		local d = State.Data
		return (d and d.MasterBuilder and d.MasterBuilder.Rank) or 0
	end
	local function paint()
		local rank = rankNow()
		for _, s in signs do
			local tiers = (if s.kind == "Bench" then TrainingConfig.Bench else TrainingConfig.Treadmill).Tiers
			local tier = tiers[math.clamp(math.floor((s.part:GetAttribute("Level") :: number?) or 1), 1, #tiers)]
			local ok = rank >= tier.Rank
			s.label.Text = if ok then string.format("%s\n%s", tier.Label, if s.kind == "Bench" then "TAP TO LIFT" else "WALK ON TO RUN") else string.format("LOCKED\nMASTER BUILDER %d", tier.Rank)
			s.label.TextColor3 = if ok then Color3.fromRGB(150, 235, 150) else Color3.fromRGB(255, 150, 130)
		end
	end
	local function add(inst: Instance, kind: string)
		if not inst:IsA("BasePart") or inst:FindFirstChild("TreadmillSign") then
			return
		end
		local gui = Instance.new("BillboardGui")
		gui.Name = "TreadmillSign"
		gui.Adornee = inst
		gui.Size = UDim2.fromOffset(170, 48)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 4.2, 5)
		gui.AlwaysOnTop = false
		gui.MaxDistance = 80
		gui.LightInfluence = 0
		gui.Parent = inst
		local label = Instance.new("TextLabel")
		label.BackgroundColor3 = Color3.fromRGB(20, 26, 38)
		label.BackgroundTransparency = 0.15
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.BuilderSansExtraBold
		label.TextSize = 17
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Parent = gui
		UI.corner(label, 12)
		UI.stroke(label, Color3.fromRGB(13, 16, 24), 3)
		table.insert(signs, { gui = gui, label = label, part = inst, kind = kind })
		-- the status sign steps aside while somebody is running on it
		local function occupied()
			gui.Enabled = inst:GetAttribute("Occupant") == nil
		end
		inst:GetAttributeChangedSignal("Occupant"):Connect(occupied)
		occupied()
		paint()
	end
	for tagName, kind in { TrainingTreadmill = "Treadmill", TrainingBench = "Bench" } do
		for _, inst in CollectionService:GetTagged(tagName) do
			add(inst, kind)
		end
		CollectionService:GetInstanceAddedSignal(tagName):Connect(function(inst)
			add(inst, kind)
		end)
	end
	State.DataChanged:Connect(paint)
end

function TrainingController.Start()
	build()
	applyCompact()
	setupTreadmillSigns()
	UI.ModeChanged:Connect(applyCompact)
	setupZones()
	Net.Event("TrainingUpdate").OnClientEvent:Connect(onUpdate)
	player:GetAttributeChangedSignal("TrainGate"):Connect(updateGate)
	updateGate()
	local carryAccum = 0
	RunService.Heartbeat:Connect(function(dt)
		updateMachines(workspace:GetServerTimeNow())
		carryAccum += dt
		if carryAccum >= 0.2 then
			carryAccum = 0
			updateCarries()
		end
	end)
	-- dying or respawning ends the session server-side; close the panel locally too
	player.CharacterAdded:Connect(function()
		if active then
			active = false
			panel.Visible = false
		end
		carrying = nil
		carryBanner.Visible = false
		ContextActionService:UnbindAction("MB_TrainStop")
	end)
end

return TrainingController
