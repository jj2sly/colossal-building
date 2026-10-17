--!strict
-- Local construction presentation: pieces "rise into place" when the server reveals
-- them (BuiltAt attribute), stage-complete bursts, damage/repair callouts, completion
-- fireworks. All tweens run on the client only, so 50 players watching costs the
-- server nothing.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local RarityConfig = require(Shared.Config.RarityConfig)
local ColossalConfig = require(Shared.Config.ColossalConfig)
local SITE = ColossalConfig.Site
local Lib = script.Parent.Parent.ClientLib
local UI = require(Lib.UI)
local Sound = require(Lib.Sound)
local ForgottenIdentity = require(Lib.ForgottenIdentity)
local State = require(Lib.State)
local Cine = require(Lib.Cine)
local Notify = require(script.Parent.NotifyController)

local BuildFXController = {}

local function burst(position: Vector3, color: Color3, count: number, speed: number?)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = position
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	e.LightEmission = 0.6
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) })
	e.Speed = NumberRange.new((speed or 30) * 0.5, speed or 30)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Lifetime = NumberRange.new(0.8, 1.6)
	e.Acceleration = Vector3.new(0, -25, 0)
	e.Drag = 1.5
	e.Rate = 0
	e.Shape = Enum.ParticleEmitterShape.Sphere
	e.Parent = p
	p.Parent = workspace
	e:Emit(count)
	Debris:AddItem(p, 3)
end

local function animatePiece(part: BasePart)
	local builtAt = part:GetAttribute("BuiltAt")
	if type(builtAt) ~= "number" or State.ServerNow() - builtAt > 1.5 then
		return -- late joiners just see finished pieces
	end
	local target = part.CFrame
	local transparency = part.Transparency
	part.CFrame = target * CFrame.new(0, -math.max(4, part.Size.Y * 1.5), 0)
	part.Transparency = 1
	UI.tween(part, 0.5, { CFrame = target }, Enum.EasingStyle.Back)
	UI.tween(part, 0.3, { Transparency = transparency })
	Sound.Play("PieceBuilt", 0.15)
end

local function repairMarker(anchor: BasePart)
	local g = Instance.new("BillboardGui")
	g.Size = UDim2.fromOffset(220, 50)
	g.AlwaysOnTop = true
	g.MaxDistance = 400
	g.Adornee = anchor
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundColor3 = Color3.fromRGB(200, 90, 30)
	l.BackgroundTransparency = 0.1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Text = "🔧 DAMAGED! Bring resources"
	l.Parent = g
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = l
	g.Parent = anchor
end

local function watchBuild(model: Instance)
	model.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			if d.Name == "RepairMarker" then
				repairMarker(d)
			elseif d:GetAttribute("BuiltAt") then
				animatePiece(d)
			end
		end
	end)
end

-- STAGE COMPLETE feedback (0.5-1.5 s), scaled by the build's rarity so the audio/visual language is consistent:
--   Common/Uncommon: a construction thud, a dust puff and a gold ground pulse
--   Rare/Epic:       + a chime and a very light shake
--   Legendary/Mythic:+ a low chime, a soft boom, a light sweep over the new structure and a small bloom lift
--   Master Project:  + a heavy rumble, a cyan pulse and the strongest (still modest) shake
local function stageTier(): number
	if State.Get("Rarity") == "Hidden" then
		return 3 -- an undiscovered Forgotten project feels like a high rarity without naming it
	end
	local mp = State.Get("MasterProject")
	if type(mp) == "string" and mp ~= "" then
		return 4
	end
	local ok, r = pcall(RarityConfig.Get, State.Get("Rarity"))
	local order = if ok and r then r.Order else 1
	return if order >= 5 then 3 elseif order >= 3 then 2 else 1
end

local function flashStage(index: number, color: Color3)
	local build = workspace:FindFirstChild("ActiveBuild")
	local stage = build and build:FindFirstChild(string.format("Stage_%02d", index), true)
	if not stage then
		return
	end
	local hl = Instance.new("Highlight")
	hl.Adornee = stage
	hl.FillColor = Color3.new(1, 1, 1) -- a white sheen with a coloured edge (a tinted fill muddies painted parts)
	hl.OutlineColor = color
	hl.FillTransparency = 0.6
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = Cine.folder()
	UI.tween(hl, 1.1, { FillTransparency = 1, OutlineTransparency = 1 })
	Debris:AddItem(hl, 1.2)
end

local function stageFeedback(payload: any)
	local tier = stageTier()
	local pos = payload.Position
	local gold = Color3.fromRGB(255, 214, 90)
	Sound.Cue("Stage", 0.75 + 0.1 * tier) -- one concise layered cue; heavier rarities are a little bigger, not louder piles
	Cine.burst(pos + Vector3.new(0, 4, 0), "Dust", if tier >= 3 then 1.4 else 1)
	-- an impact puff all round the platform edge, readable from the spawn
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2 + math.random()
		Cine.burst(Vector3.new(math.cos(a) * SITE.CollarRadius, 3, math.sin(a) * SITE.CollarRadius), "Dust", 0.45)
	end
	burst(pos, gold, if tier >= 3 then 50 else 28, 34)
	Cine.ring(Vector3.new(0, SITE.DeckTopY + 0.3, 0), if tier == 4 then Color3.fromRGB(120, 215, 255) else gold, ColossalConfig.FrameRadius(1.6 + tier * 0.2), 1.2)
	flashStage(payload.Stage, if tier == 4 then Color3.fromRGB(150, 225, 255) else Color3.fromRGB(255, 236, 170))
	if tier >= 2 then
		Cine.shake(0.15 + (tier - 2) * 0.1, 0.5)
	end
	if tier >= 3 then
		Cine.bloom(0.1, 0.2, 0.3, 0.7)
	end
	if tier == 4 then
		Cine.burst(pos, "Spark", 1.2)
	end
end

-- The platform's STAGE RING (World.BuildSite.StageRing): tiles fill amber with overall progress; tiles inside
-- finished stages turn a brighter gold, so the platform itself reads "how far along is this build".
local RING_OFF = Color3.fromRGB(64, 70, 84)
local RING_PROGRESS = Color3.fromRGB(196, 150, 70)
local RING_DONE = Color3.fromRGB(255, 196, 70)

local function refreshStageRing()
	local world = workspace:FindFirstChild("World")
	local site = world and world:FindFirstChild("BuildSite")
	local ring = site and site:FindFirstChild("StageRing")
	if not ring then
		return
	end
	local tiles = ring:GetChildren()
	local n = #tiles
	local count = tonumber(State.Get("StageCount")) or 0
	local stage = tonumber(State.Get("Stage")) or 0
	local progress = tonumber(State.Get("Progress")) or 0
	local done = if count > 0 then math.floor(n * stage / count + 0.5) else 0
	local lit = if count > 0 then math.max(done, math.floor(n * progress + 0.5)) else 0
	for _, t in tiles do
		local i = t:GetAttribute("Index")
		if t:IsA("BasePart") and type(i) == "number" then
			local color = if i <= done then RING_DONE elseif i <= lit then RING_PROGRESS else RING_OFF
			if t.Color ~= color then
				UI.tween(t, 0.4, { Color = color })
			end
		end
	end
end

function BuildFXController.Start()
	for _, key in { "Stage", "StageCount", "Progress" } do
		State.Changed(key, refreshStageRing)
	end
	task.defer(refreshStageRing)
	workspace.ChildAdded:Connect(function(c)
		if c.Name == "ActiveBuild" then
			watchBuild(c)
		end
	end)
	local existing = workspace:FindFirstChild("ActiveBuild")
	if existing then
		watchBuild(existing)
	end

	Net.Event("Effect").OnClientEvent:Connect(function(id, payload)
		if id == "StageComplete" then
			stageFeedback(payload) -- world FX + sound; the STAGE COMPLETE ribbon belongs to the project card (TrackerController)
		elseif id == "Damaged" then
			burst(payload.Position, Color3.fromRGB(255, 110, 40), 80, 50)
			Notify.Show("Error", "💥 " .. payload.Name .. " was damaged! Bring resources to repair it.")
		elseif id == "Repaired" then
			Sound.Play("StageComplete")
			burst(payload.Position, Color3.fromRGB(120, 255, 140), 60, 35)
			Notify.Show("Success", "🔧 " .. payload.Name .. " repaired!")
		elseif id == "BuildComplete" then
			local r = RarityConfig.Get(payload.Rarity)
			-- the one moment that earns a camera accent for everyone: a small FOV punch, a soft grade and the ambience dipping
			Cine.fov(-5, 0.35, 1.2, 1.5)
			Cine.duck(0.35, 0.4, 6, 2)
			Cine.bloom(0.05, 0.3, 1.5, 1.5)
			Cine.shake(0.3, 0.6)
			local rar = payload.Rarity
			if ForgottenIdentity.Def(State.Get("BuildId")) then
				rar = "Forgotten" -- the public tier is masked as Mythic; a discoverer hears the real one
			end
			Sound.Complete(rar)
			for i = 1, 4 + r.RevealIntensity * 2 do
				task.delay(i * 0.35, function()
					-- spread over the whole deck and up the height of a colossal build
					local spread = SITE.DeckRadius
					local pos = payload.Position + Vector3.new(math.random(-spread, spread), math.random(30, 30 + 30 * (r.Order or 1)), math.random(-spread, spread))
					local colors = { r.Color, Color3.fromRGB(255, 220, 90), Color3.fromRGB(90, 200, 255), Color3.fromRGB(255, 120, 200) }
					burst(pos, colors[i % #colors + 1], 90, 55)
					Sound.Play("Meteor", 0.3, 0.45)
				end)
			end
		elseif id == "BuildActivated" then
			-- partial activation: the build comes alive before it is finished (a short ring + note; builds add their own)
			local r = RarityConfig.Get(payload.Rarity)
			Cine.ring(Vector3.new(0, SITE.DeckTopY + 0.3, 0), r.Color, ColossalConfig.FrameRadius(2), 1.6)
			Sound.Milestone(0, 0) -- the SYSTEMS ONLINE ribbon on the project card carries the message
		elseif id == "BuildReset" then
			burst(Vector3.new(0, 8, 0), Color3.fromRGB(200, 190, 170), 120, 45)
		end
	end)
end

return BuildFXController
