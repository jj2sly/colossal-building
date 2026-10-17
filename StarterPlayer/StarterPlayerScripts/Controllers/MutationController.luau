--!strict
-- MUTATION PRESENTATION (client only). The server publishes one Folder per mutated pile in Workspace.MB_Mutations (Tier, ResId,
-- Spot, Reserve ... and ObjectValues pointing at the pile's nodes). This controller draws everything from that:
--   * on each node: a soft Highlight, a gentle sparkle emitter and a small light in the tier colour (Prismatic shifts hue slowly),
--   * a tall translucent beam over the pile for its first BeamSeconds (and a slim ground ring) so it can be found from afar,
--   * the announcement banner ("DIAMOND METAL!" + place) when the server fires Effect "MutationSpawn" (Golden quiet, Prismatic big),
--   * the level-100 milestone banner (Effect "TrainingMilestone", Big).
-- Cost control: at most a handful of piles ever exist, each node gets one emitter + one light, and one shared 10 Hz loop recolours
-- Prismatic things only while one exists. Nothing is created per frame.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local MutationConfig = require(Shared.Config.MutationConfig)
local Lib = script.Parent.Parent.ClientLib
local UI = require(Lib.UI)
local Sound = require(Lib.Sound)
local Cine = require(Lib.Cine)

local MutationController = {}
local T = UI.Theme
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

type Fx = { pile: Folder, tier: string, instances: { Instance }, prism: { Instance }, beam: Part? }
local active: { [Folder]: Fx } = {}
local prismLoop = false

local function rainbow(offset: number): Color3
	return Color3.fromHSV((os.clock() * 0.2 + offset) % 1, 0.45, 1)
end

local function startPrismLoop()
	if prismLoop then
		return
	end
	prismLoop = true
	task.spawn(function()
		while true do
			local any = false
			for _, fx in active do
				if fx.tier == "Prismatic" then
					any = true
					for i, inst in fx.prism do
						if inst.Parent then
							local c = rainbow(i * 0.13)
							if inst:IsA("Highlight") then
								inst.FillColor = c
								inst.OutlineColor = rainbow(i * 0.13 + 0.35)
							elseif inst:IsA("PointLight") then
								inst.Color = c
							elseif inst:IsA("BasePart") then
								inst.Color = c
							end
						end
					end
				end
			end
			if not any then
				break
			end
			task.wait(0.1)
		end
		prismLoop = false
	end)
end

local function tierSequence(tier: string): ColorSequence
	local def = MutationConfig.Tiers[tier]
	if tier == "Prismatic" then
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 150, 230)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 255, 230)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 240, 150)),
		})
	end
	return ColorSequence.new(def.Color, def.Color2)
end

local function decorateNode(fx: Fx, node: BasePart)
	local def = MutationConfig.Tiers[fx.tier]
	-- highlight the whole prop (the Model the node belongs to) so the pile reads as one glowing object
	local adornee: Instance = node
	local parent = node.Parent
	if parent and parent:IsA("Model") then
		adornee = parent
	end
	local hl = Instance.new("Highlight")
	hl.Adornee = adornee
	hl.FillColor = def.Color
	hl.OutlineColor = def.Color2
	-- Golden: warm, mostly the prop's own shape showing through; Diamond: a cool, brighter crystal coat; Prismatic: strongest
	hl.FillTransparency = if fx.tier == "Golden" then 0.4 elseif fx.tier == "Diamond" then 0.4 else 0.3
	hl.OutlineTransparency = if fx.tier == "Golden" then 0.6 elseif fx.tier == "Diamond" then 0.45 else 0.35
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	-- the glow builds in instead of popping on
	local fill, outline = hl.FillTransparency, hl.OutlineTransparency
	hl.FillTransparency, hl.OutlineTransparency = 1, 1
	UI.tween(hl, 1.2, { FillTransparency = fill, OutlineTransparency = outline })
	hl.Parent = node
	table.insert(fx.instances, hl)
	local anchor = Instance.new("Part")
	anchor.Name = "MB_MutationAnchor"
	anchor.Anchored = true
	anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = node.Position + Vector3.new(0, math.max(2, node.Size.Y / 2), 0)
	anchor.Parent = workspace
	table.insert(fx.instances, anchor)
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLE
	e.Color = tierSequence(fx.tier)
	e.LightEmission = if fx.tier == "Golden" then 0.4 else 0.85
	e.Rate = if fx.tier == "Prismatic" then 16 elseif fx.tier == "Diamond" then 12 else 6
	e.Lifetime = NumberRange.new(1.2, 2)
	e.Speed = NumberRange.new(1.5, 4)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, 1.2, 0)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	e.Shape = Enum.ParticleEmitterShape.Sphere
	e.Parent = anchor
	local light = Instance.new("PointLight")
	light.Color = def.Color
	light.Range = if fx.tier == "Prismatic" then 22 else 16
	light.Brightness = 0
	light.Shadows = false
	light.Parent = anchor
	UI.tween(light, 1.2, { Brightness = 1.1 })
	if fx.tier == "Prismatic" then
		table.insert(fx.prism, hl)
		table.insert(fx.prism, light)
	end
end

-- ARRIVAL: the world reacts where the pile appears (only for piles that spawn while you are playing, not on join)
local function arrival(tier: string, center: Vector3)
	local def = MutationConfig.Tiers[tier]
	local ground = center - Vector3.new(0, 1.5, 0)
	if tier == "Golden" then
		Cine.ring(ground, def.Color, 34, 1.4)
		Cine.burst(center, "Gold", 0.8)
		Sound.PlayAt("Chime", center, 160)
	elseif tier == "Diamond" then
		Cine.ring(ground, def.Color, 56, 1.6)
		Cine.burst(center, "Diamond", 1.2)
		Sound.PlayAt("Chime", center, 220)
		Sound.PlayAt("Zap", center, 140)
	else
		-- Prismatic: the jackpot. A brighter pulse, a short world-wide colour shift and a bloom lift, still never a white-out
		Cine.ring(ground, Color3.fromRGB(255, 170, 235), 90, 2)
		task.delay(0.35, function()
			Cine.ring(ground, Color3.fromRGB(150, 255, 230), 70, 1.8)
		end)
		Cine.burst(center, "Prismatic", 1.4)
		Cine.grade({ TintColor = Color3.fromRGB(246, 236, 255), Saturation = 0.12 }, 0.5, 1.6, 1.5)
		Cine.bloom(0.18, 0.4, 1.2, 1.4)
		Cine.vignette(Color3.fromRGB(230, 150, 255), 0.22, 0.5, 1.6, 1.4)
		Cine.fov(-3, 0.5, 1, 1.4)
		Sound.PlayAt("Chime", center, 300)
	end
end

local function build(pile: Folder, fresh: boolean?)
	local tier = pile:GetAttribute("Tier")
	if type(tier) ~= "string" or not MutationConfig.Tiers[tier] or active[pile] then
		return
	end
	local fx: Fx = { pile = pile, tier = tier, instances = {}, prism = {}, beam = nil }
	active[pile] = fx
	local center, n = Vector3.zero, 0
	for _, ov in pile:GetChildren() do
		if ov:IsA("ObjectValue") and ov.Value and ov.Value:IsA("BasePart") then
			decorateNode(fx, ov.Value)
			center += ov.Value.Position
			n += 1
		end
	end
	if n == 0 then
		return
	end
	center /= n
	local def = MutationConfig.Tiers[tier]
	if fresh then
		arrival(tier, center)
	end
	if def.Beam then
		-- the temporary marker: a tall, soft pillar of light (visible across the valley) plus a ground ring; both fade away
		local beam = Instance.new("Part")
		beam.Name = "MB_MutationBeam"
		beam.Anchored = true
		beam.CanCollide, beam.CanQuery, beam.CanTouch = false, false, false
		beam.Shape = Enum.PartType.Cylinder
		beam.Size = Vector3.new(320, 5, 5)
		beam.CFrame = CFrame.new(center + Vector3.new(0, 160, 0)) * CFrame.Angles(0, 0, math.rad(90))
		beam.Material = Enum.Material.Neon
		beam.Color = def.Color
		beam.Transparency = 1
		beam.CastShadow = false
		beam.Parent = workspace
		fx.beam = beam
		table.insert(fx.instances, beam)
		UI.tween(beam, 1.2, { Transparency = if tier == "Golden" then 0.82 else 0.74 })
		local ring = Instance.new("Part")
		ring.Name = "MB_MutationRing"
		ring.Anchored = true
		ring.CanCollide, ring.CanQuery, ring.CanTouch = false, false, false
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.3, 26, 26)
		ring.CFrame = CFrame.new(center.X, center.Y + 0.4, center.Z) * CFrame.Angles(0, 0, math.rad(90))
		ring.Material = Enum.Material.ForceField
		ring.Color = def.Color
		ring.Transparency = 0.35
		ring.Parent = workspace
		table.insert(fx.instances, ring)
		if tier == "Prismatic" then
			table.insert(fx.prism, beam)
			table.insert(fx.prism, ring)
		end
		task.delay(MutationConfig.BeamSeconds, function()
			if beam.Parent then
				UI.tween(beam, 2, { Transparency = 1 })
				task.delay(2.1, function()
					beam:Destroy()
				end)
			end
			if ring.Parent then
				UI.tween(ring, 2, { Transparency = 1 })
				task.delay(2.1, function()
					ring:Destroy()
				end)
			end
		end)
	end
	if tier == "Prismatic" then
		startPrismLoop()
	end
end

local function clear(pile: Folder)
	local fx = active[pile]
	if not fx then
		return
	end
	active[pile] = nil
	for _, inst in fx.instances do
		if inst.Parent then
			if inst:IsA("BasePart") and inst.Name == "MB_MutationAnchor" then
				local e = inst:FindFirstChildOfClass("ParticleEmitter")
				if e then
					e.Rate = 0
					e:Emit(10) -- a last small puff as the pile ends
				end
				Debris:AddItem(inst, 1.6)
			else
				inst:Destroy()
			end
		end
	end
end

------------------------------------------------------------------ banners
local gui: ScreenGui
local flash: Frame
local bannerToken = 0
local currentBanner: Frame? = nil

local function ensureGui()
	if gui then
		return
	end
	gui = UI.root("Mutation", 6)
	flash = UI.new("Frame", { Name = "Flash", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = gui })
end

-- A big centred headline with a small second line. `tone` = Soft | Loud | Epic (Epic is longer, larger and colour-shifting).
local function banner(title: string, sub: string, color: Color3, tone: string, seconds: number)
	ensureGui()
	bannerToken += 1
	local token = bannerToken
	local size = if tone == "Epic" then 64 elseif tone == "Loud" then 46 else 28
	-- one banner at a time: a newer announcement replaces the old one instead of stacking on top of it
	if currentBanner and currentBanner.Parent then
		currentBanner:Destroy()
	end
	local holder = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.2), Size = UDim2.fromOffset(760, size + 40), ZIndex = 5, Parent = gui })
	currentBanner = holder
	local scale = UI.new("UIScale", { Scale = 0.6, Parent = holder })
	local t = UI.new("TextLabel", { Text = title, Font = T.Title, TextSize = size, TextColor3 = color, TextTransparency = 1, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, size + 6), ZIndex = 6, Parent = holder })
	UI.textStroke(t, 2.4)
	local st = UI.new("TextLabel", { Text = sub, Font = T.Bold, TextSize = if tone == "Epic" then 26 else 20, TextColor3 = Color3.new(1, 1, 1), TextTransparency = 1, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, size + 8), Size = UDim2.new(1, 0, 0, 30), ZIndex = 6, Parent = holder })
	UI.textStroke(st, 1.8)
	UI.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	UI.tween(t, 0.25, { TextTransparency = 0 })
	UI.tween(st, 0.25, { TextTransparency = 0 })
	if tone == "Epic" then
		-- a brief soft colour wash over the whole screen, never blinding
		flash.BackgroundColor3 = color
		flash.BackgroundTransparency = 0.78
		UI.tween(flash, 1.6, { BackgroundTransparency = 1 })
		task.spawn(function()
			local t0 = os.clock()
			while holder.Parent and os.clock() - t0 < seconds do
				t.TextColor3 = rainbow(0)
				task.wait(0.08)
			end
		end)
	end
	task.delay(seconds, function()
		if holder.Parent then
			UI.tween(t, 0.5, { TextTransparency = 1 })
			UI.tween(st, 0.5, { TextTransparency = 1 })
			task.delay(0.6, function()
				holder:Destroy()
			end)
		end
	end)
	local _ = token
end

local function onEffect(id: string, payload: any)
	if id == "MutationSpawn" and type(payload) == "table" then
		local def = MutationConfig.Tiers[payload.Tier]
		local text = MutationConfig.Announce[payload.Tier]
		if not def or not text then
			return
		end
		banner(string.format(text.Title, payload.Family or ""), tostring(payload.Place or ""), def.Color, def.Announce, text.Seconds)
		if payload.Tier == "Prismatic" then
			Sound.Play("RevealFinal")
			Sound.Play("ChimeLow")
			task.delay(0.3, function()
				Sound.Play("Chime")
			end)
			task.delay(0.8, function()
				Sound.Play("Cheer")
			end)
		elseif payload.Tier == "Diamond" then
			Sound.Play("Discovery")
			Sound.Play("Chime")
		else
			Sound.Play("Chime")
		end
	elseif id == "SecretCache" and type(payload) == "table" then
		banner(tostring(payload.Name) .. " CACHE", "A secret cache appeared", Color3.fromRGB(150, 205, 255), "Loud", 4)
		Sound.Play("Discovery")
	elseif id == "TrainingMilestone" and type(payload) == "table" and payload.Big then
		local color = Color3.fromRGB(255, 214, 92)
		banner(string.format("%s LEVEL %d!", string.upper(tostring(payload.Stat)), payload.Level or 100), "Maximum reached", color, "Epic", 6)
		Sound.Play("RevealFinal")
	end
end

function MutationController.Start()
	local folder = workspace:WaitForChild("MB_Mutations", 30)
	if folder then
		for _, c in folder:GetChildren() do
			if c:IsA("Folder") then
				build(c)
			end
		end
		folder.ChildAdded:Connect(function(c)
			if c:IsA("Folder") then
				task.defer(build, c, true) -- let the server finish adding the node references
			end
		end)
		folder.ChildRemoved:Connect(function(c)
			if c:IsA("Folder") then
				clear(c)
			end
		end)
	end
	Net.Event("Effect").OnClientEvent:Connect(onEffect)
end

local _ = RunService
return MutationController
