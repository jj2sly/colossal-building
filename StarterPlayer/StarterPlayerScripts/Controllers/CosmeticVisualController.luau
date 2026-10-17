--!strict
-- Cosmetic visuals that live on players and at the build site (all client side, all cheap):
--   * TRAILS: one Trail instance per player wearing one (attribute CosTrail), only emitting while that player is moving.
--   * DELIVERY (contribution) EFFECTS: a short burst at the build site when a player with CosContrib delivers
--     (the server sends a throttled "Contribution" effect to everyone). At most a handful of bursts exist at once.
-- Vehicle skins are applied server-side at spawn; carry effects are drawn by CarryVisualController.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local CosmeticConfig = require(Shared.Config.CosmeticConfig)
local GameConfig = require(Shared.Config.GameConfig)

local CosmeticVisualController = {}

local trails: { [Player]: Trail } = {}
local MAX_BURSTS = 8
local activeBursts = 0

local function clearTrail(player: Player)
	local t = trails[player]
	if t then
		local a0, a1 = t.Attachment0, t.Attachment1
		t:Destroy()
		if a0 then
			a0:Destroy()
		end
		if a1 then
			a1:Destroy()
		end
		trails[player] = nil
	end
end

local function applyTrail(player: Player)
	clearTrail(player)
	local id = player:GetAttribute("CosTrail")
	local def = if type(id) == "string" then CosmeticConfig.Get("Trail", id) else nil
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not def or not hrp then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "CosTrailA"
	a0.Position = Vector3.new(0, 0.6, 0.6)
	a0.Parent = hrp
	local a1 = Instance.new("Attachment")
	a1.Name = "CosTrailB"
	a1.Position = Vector3.new(0, -1.9, 0.6)
	a1.Parent = hrp
	local t = Instance.new("Trail")
	t.Name = "CosTrail"
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Color = ColorSequence.new(def.Color, def.Color2)
	t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	t.Lifetime = def.Life
	t.LightEmission = def.Glow
	t.WidthScale = NumberSequence.new(def.Width)
	t.MinLength = 0.15
	t.FaceCamera = true
	t.Enabled = false
	t.Parent = hrp
	-- premium trails (Sparkles = true, e.g. Orbital Trail): a few tiny star specks circling the ribbon, toggled with it
	if def.Sparkles then
		local e = Instance.new("ParticleEmitter")
		e.Name = "CosTrailSparkles"
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(def.Color, def.Color2)
		e.LightEmission = 0.6
		e.Rate = 7
		e.Lifetime = NumberRange.new(0.6, 1.1)
		e.Speed = NumberRange.new(0.4, 1.2)
		e.RotSpeed = NumberRange.new(-120, 120)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.32), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		e.Enabled = false
		e.Parent = a1
	end
	trails[player] = t
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("CosTrail"):Connect(function()
		applyTrail(player)
	end)
	player.CharacterAdded:Connect(function()
		task.defer(function()
			task.wait(0.3)
			applyTrail(player)
		end)
	end)
	if player.Character then
		task.defer(applyTrail, player)
	end
end

local function burst(userId: number, id: string)
	local def = CosmeticConfig.Get("ContributionEffect", id)
	if not def or activeBursts >= MAX_BURSTS then
		return
	end
	local p = Players:GetPlayerByUserId(userId)
	local hrp = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local site = GameConfig.Site.Center
	-- the burst rises from the structure, on the side the player is delivering from
	local from = if hrp then Vector3.new(hrp.Position.X, site.Y, hrp.Position.Z) else site
	local dir = from - site
	local at = site + (if dir.Magnitude > 0.1 then dir.Unit * math.min(dir.Magnitude, 24) else Vector3.zero) + Vector3.new(0, 6, 0)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = at
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(def.Color, def.Color2)
	e.LightEmission = 0.8
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	e.Drag = 3
	if def.Style == "Bolts" then
		e.Speed = NumberRange.new(26, 40)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Lifetime = NumberRange.new(0.25, 0.45)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0.1) })
	elseif def.Style == "Firework" then
		e.Speed = NumberRange.new(14, 26)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0, -14, 0)
		e.Lifetime = NumberRange.new(0.7, 1.1)
	else
		e.Speed = NumberRange.new(12, 22)
		e.SpreadAngle = Vector2.new(60, 60)
		e.EmissionDirection = Enum.NormalId.Top
		e.Acceleration = Vector3.new(0, -10, 0)
	end
	e.Parent = anchor
	anchor.Parent = workspace
	e:Emit(def.Count)
	activeBursts += 1
	Debris:AddItem(anchor, 1.5)
	task.delay(1.5, function()
		activeBursts -= 1
	end)
end

function CosmeticVisualController.Start()
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clearTrail)
	-- trails only draw while the wearer is actually moving (also true while riding a vehicle)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.15 then
			return
		end
		acc = 0
		for p, t in trails do
			local hrp = t.Parent :: BasePart?
			t.Enabled = hrp ~= nil and hrp.AssemblyLinearVelocity.Magnitude > 3
			local sp = t.Attachment1 and t.Attachment1:FindFirstChild("CosTrailSparkles") :: ParticleEmitter?
			if sp then
				sp.Enabled = t.Enabled
			end
		end
	end)
	Net.Event("Effect").OnClientEvent:Connect(function(effectId, payload)
		if effectId == "Contribution" and type(payload) == "table" then
			burst(payload.U, payload.Id)
		end
	end)
end

return CosmeticVisualController
