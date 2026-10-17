--!strict
-- One Worker per player (never an army). Workers walk straight lines between their
-- zone's GatherPoint and the build's deposit ring; no pathfinding needed on the
-- hub-and-spoke map. The server runs ONE scheduler loop for all workers and only
-- stores leg endpoints + timestamps as attributes; clients interpolate movement
-- locally (WorkerVisualController), so walking workers cost no CFrame replication.
--
-- Worker deliveries count for the owner at GameConfig.Contribution.WorkerWeight.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local GameConfig = require(Shared.Config.GameConfig)
local WorkerConfig = require(Shared.Config.WorkerConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local ResourceSpotConfig = require(Shared.Config.ResourceSpotConfig)
local Formulas = require(Shared.Formulas)
local MutationConfig = require(Shared.Config.MutationConfig)
local MasterBuilderConfig = require(Shared.Config.MasterBuilderConfig)

type Worker = {
	owner: Player,
	model: Model,
	state: string,
	res: string?,
	carry: number,
	until_: number,
	dest: Vector3?,
	legFrom: Vector3?,
	legStart: number,
	pile: string?, -- live mutated pile this Worker is working (auto-redirect)
	mutTier: string?, -- mutation of the load being carried
	pause: { state: string, remaining: number, moving: boolean }?,
}

local WorkerService = {}
local S: any
local workers: { [Player]: Worker } = {}
local folder: Folder
local paused = false
local MOVING = { ToZone = true, ToSite = true, ToStation = true, Moving = true }

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Workers always use the resource's beginner spot (ResourceSpotConfig.Primary); far spots are for players.
local function zonePoint(resId: string): Vector3?
	local spot = ResourceSpotConfig.Primary(resId)
	if not spot then
		return nil
	end
	local world = workspace:FindFirstChild("World")
	local zones = world and world:FindFirstChild("Zones")
	local zone = zones and zones:FindFirstChild(spot.Id)
	local gp = zone and zone:FindFirstChild("GatherPoint") :: BasePart?
	return if gp then gp.Position else Vector3.new(spot.Position.X, 3, spot.Position.Z)
end

-- Where a Worker goes for its current resource: a live mutated pile (any spot) or the resource's beginner zone.
local function targetPoint(w: Worker): Vector3?
	if w.pile and S.MutationService then
		local pile = S.MutationService.GetPile(w.pile)
		if pile and pile.reserve > 0 then
			local c, n = Vector3.zero, 0
			for _, node in pile.nodes do
				c += node.Position
				n += 1
			end
			if n > 0 then
				return c / n + Vector3.new(0, 3, 0)
			end
		end
		w.pile = nil
	end
	return if w.res then zonePoint(w.res) else nil
end

local function stationPoint(owner: Player): Vector3
	local world = workspace:FindFirstChild("World")
	-- (Pass 21O) the Worker Post building is gone: Workers idle in front of the Builders Shop (the ShopMat that opens the Workers menu)
	local base = Vector3.new(-15, 6, 198)
	for _, m in game:GetService("CollectionService"):GetTagged("ShopMat") do
		if m:IsA("BasePart") and m:GetAttribute("Panel") == "Worker" then
			base = m.Position + Vector3.new(0, 3, -3)
		end
	end
	local angle = (owner.UserId % 12) / 12 * math.pi * 2
	return base + Vector3.new(math.cos(angle) * 6, 0, math.sin(angle) * 6)
end

local function sitePointToward(from: Vector3): Vector3
	local site = GameConfig.Site
	local dir = Vector3.new(from.X - site.Center.X, 0, from.Z - site.Center.Z)
	dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.new(1, 0, 0)
	-- just outside the barrier, inside the deposit edge (works for any site size)
	local p = site.Center + dir * ((site.DepositInnerRadius + site.DepositOuterRadius) / 2)
	return Vector3.new(p.X, from.Y, p.Z)
end

-- WORKERS ARE ROBLOX CHARACTERS: one R15 rig is generated once (Players:CreateHumanoidModelFromDescription) and cloned per
-- Worker. Only the HumanoidRootPart is anchored, so the whole rig follows it while limb animation still plays (the clients
-- play local walk / work animations, see WorkerVisualController). The state machine is off and name/health display hidden.
local template: Model? = nil
local templateBuilding = false

local function newDescription(): HumanoidDescription
	local d = Instance.new("HumanoidDescription")
	d.HeadScale = 1.18
	d.WidthScale = 1.1
	d.DepthScale = 1.1
	return d
end

local function ensureTemplate()
	if template or templateBuilding then
		return
	end
	templateBuilding = true
	task.spawn(function()
		local ok, res = pcall(function()
			return Players:CreateHumanoidModelFromDescription(newDescription(), Enum.HumanoidRigType.R15)
		end)
		if ok and res then
			template = res
		else
			warn("[Worker] could not create the R15 rig:", res)
		end
		templateBuilding = false
	end)
end

local function paint(m: Model, partName: string, color: Color3)
	local p = m:FindFirstChild(partName) :: BasePart?
	if p then
		p.Color = color
	end
end

local function accessory(m: Model, parent: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.CFrame = parent.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = parent
	w.Part1 = p
	w.Parent = p
	p.Parent = m
	return p
end

-- ART PASS: crew characters are stylised simulator NPCs: slightly bigger heads, chunky builds, two-tone sleeves, belts, boots,
-- a hi-vis vest, a role hat and a role TOOL (axe, pickaxe, torch, tablet, backpack, hammer) so each type is recognisable
-- at a glance. Rare outfits get neon trim (and Legendary a sparkle) so they feel collectible.
local RARITY_COLOR = {
	Common = Color3.fromRGB(255, 255, 255),
	Rare = Color3.fromRGB(110, 190, 255),
	Epic = Color3.fromRGB(200, 130, 255),
	Legendary = Color3.fromRGB(255, 205, 70),
	Mythic = Color3.fromRGB(255, 110, 150),
}

local function addTool(m: Model, outfit: any, torso: BasePart, hand: BasePart?)
	local tool = outfit.Tool
	local wood = Color3.fromRGB(150, 100, 55)
	local metal = Color3.fromRGB(190, 196, 208)
	local rope = Color3.fromRGB(196, 170, 110)
	if tool == "Axe" then
		accessory(m, torso, "AxeHandle", Vector3.new(0.35, 3.6, 0.35), CFrame.new(0.5, 0.2, 0.85) * CFrame.Angles(0, 0, math.rad(-28)), wood, Enum.Material.Wood)
		accessory(m, torso, "AxeHead", Vector3.new(0.3, 1.1, 1.3), CFrame.new(1.5, 1.7, 0.85) * CFrame.Angles(0, 0, math.rad(-28)), metal, Enum.Material.Metal)
	elseif tool == "Pickaxe" then
		accessory(m, torso, "PickHandle", Vector3.new(0.35, 3.6, 0.35), CFrame.new(-0.5, 0.2, 0.85) * CFrame.Angles(0, 0, math.rad(28)), wood, Enum.Material.Wood)
		accessory(m, torso, "PickHead", Vector3.new(0.35, 0.4, 2.4), CFrame.new(-1.5, 1.7, 0.85) * CFrame.Angles(0, 0, math.rad(28)), metal, Enum.Material.Metal)
	elseif tool == "Torch" then
		accessory(m, torso, "GasTank", Vector3.new(0.9, 2.4, 0.9), CFrame.new(0.5, 0, 0.95), Color3.fromRGB(70, 130, 200), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		accessory(m, torso, "GasTank", Vector3.new(0.9, 2.2, 0.9), CFrame.new(-0.6, -0.1, 0.95), Color3.fromRGB(220, 70, 60), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		if hand then
			accessory(m, hand, "TorchTip", Vector3.new(0.4, 0.4, 1.1), CFrame.new(0, -0.3, -0.7), Color3.fromRGB(255, 160, 40), Enum.Material.Neon)
		end
	elseif tool == "Tablet" then
		local tab = accessory(m, hand or torso, "Tablet", Vector3.new(0.9, 1.2, 0.15), CFrame.new(0, -0.2, -0.6), Color3.fromRGB(40, 44, 56), Enum.Material.SmoothPlastic)
		accessory(m, tab, "TabletScreen", Vector3.new(0.75, 1, 0.05), CFrame.new(0, 0, -0.1), outfit.HatColor, Enum.Material.Neon)
	elseif tool == "Backpack" then
		accessory(m, torso, "Pack", Vector3.new(2, 2.2, 1.1), CFrame.new(0, 0, 1.0), outfit.Accent, Enum.Material.SmoothPlastic)
		accessory(m, torso, "PackFlap", Vector3.new(2.1, 0.7, 1.2), CFrame.new(0, 0.9, 1.0), outfit.Accent:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.SmoothPlastic)
		accessory(m, torso, "PackRoll", Vector3.new(2.4, 0.7, 0.7), CFrame.new(0, -1.3, 1.1), rope, Enum.Material.Fabric, Enum.PartType.Cylinder)
	else -- Hammer (and default): tucked into the belt
		accessory(m, torso, "HammerHandle", Vector3.new(0.3, 1.5, 0.3), CFrame.new(1.0, -1.05, -0.55), wood, Enum.Material.Wood)
		accessory(m, torso, "HammerHead", Vector3.new(0.9, 0.55, 0.5), CFrame.new(1.0, -0.3, -0.55), metal, Enum.Material.Metal)
	end
end

-- Dresses the rig: colour-blocked shirt, short-sleeve look, belt, boots, role hat, vest and tool.
local function applyOutfit(m: Model, outfit: any)
	for _, n in { "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm" } do
		paint(m, n, outfit.Shirt)
	end
	for _, n in { "LeftLowerArm", "RightLowerArm", "Head", "LeftHand", "RightHand" } do
		paint(m, n, outfit.Skin)
	end
	for _, n in { "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" } do
		paint(m, n, outfit.Pants)
	end
	for _, n in { "LeftFoot", "RightFoot" } do
		paint(m, n, Color3.fromRGB(86, 58, 38))
	end
	local head = m:FindFirstChild("Head") :: BasePart?
	local torso = m:FindFirstChild("UpperTorso") :: BasePart?
	local lower = m:FindFirstChild("LowerTorso") :: BasePart?
	local hand = m:FindFirstChild("RightHand") :: BasePart?
	if head then
		local k = head.Size.X / 1.2
		local hat, hc = outfit.Hat, outfit.HatColor
		if hat == "HardHat" then
			accessory(m, head, "HatDome", Vector3.new(1.45, 0.8, 1.45) * k, CFrame.new(0, 0.62 * k, 0), hc, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			accessory(m, head, "HatBrim", Vector3.new(1.6, 0.14, 1.8) * k, CFrame.new(0, 0.4 * k, -0.12 * k), hc:Lerp(Color3.new(0, 0, 0), 0.12))
			accessory(m, head, "HatRidge", Vector3.new(0.3, 0.14, 1.3) * k, CFrame.new(0, 1.0 * k, 0), hc:Lerp(Color3.new(1, 1, 1), 0.35))
			accessory(m, head, "HatLamp", Vector3.new(0.45, 0.3, 0.2) * k, CFrame.new(0, 0.7 * k, -0.7 * k), Color3.fromRGB(255, 250, 200), Enum.Material.Neon)
		elseif hat == "Cap" then
			accessory(m, head, "CapTop", Vector3.new(1.4, 0.7, 1.4) * k, CFrame.new(0, 0.55 * k, 0), hc, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			accessory(m, head, "CapBrim", Vector3.new(1.2, 0.12, 0.8) * k, CFrame.new(0, 0.38 * k, -0.9 * k), hc:Lerp(Color3.new(0, 0, 0), 0.2))
			accessory(m, head, "CapBadge", Vector3.new(0.4, 0.35, 0.1) * k, CFrame.new(0, 0.72 * k, -0.65 * k), outfit.Accent, Enum.Material.Neon)
		elseif hat == "WeldMask" then
			accessory(m, head, "MaskDome", Vector3.new(1.5, 0.9, 1.5) * k, CFrame.new(0, 0.6 * k, 0), hc, Enum.Material.Metal, Enum.PartType.Ball)
			accessory(m, head, "MaskVisor", Vector3.new(1.25, 0.65, 0.18) * k, CFrame.new(0, 0.18 * k, -0.78 * k) * CFrame.Angles(math.rad(-24), 0, 0), Color3.fromRGB(30, 110, 70), Enum.Material.Glass)
			accessory(m, head, "MaskTrim", Vector3.new(1.4, 0.14, 0.25) * k, CFrame.new(0, 0.55 * k, -0.7 * k), outfit.Accent, Enum.Material.Neon)
		elseif hat == "Headset" then
			accessory(m, head, "HeadsetBand", Vector3.new(1.4, 0.16, 0.5) * k, CFrame.new(0, 0.66 * k, 0), Color3.fromRGB(40, 44, 52), Enum.Material.Metal)
			for _, sx in { -0.7, 0.7 } do
				accessory(m, head, "EarCup", Vector3.new(0.35, 0.7, 0.7) * k, CFrame.new(sx * k, 0.05, 0), Color3.fromRGB(46, 52, 64), Enum.Material.SmoothPlastic)
				accessory(m, head, "EarGlow", Vector3.new(0.12, 0.45, 0.45) * k, CFrame.new(sx * 1.12 * k, 0.05, 0), hc, Enum.Material.Neon)
			end
			accessory(m, head, "Mic", Vector3.new(0.2, 0.2, 0.7) * k, CFrame.new(0.55 * k, -0.2 * k, -0.7 * k), Color3.fromRGB(40, 44, 52), Enum.Material.SmoothPlastic)
			accessory(m, head, "Visor", Vector3.new(1.3, 0.25, 0.12) * k, CFrame.new(0, 0.22 * k, -0.66 * k), hc, Enum.Material.Neon)
		elseif hat == "CrownHat" then
			accessory(m, head, "HatDome", Vector3.new(1.5, 0.8, 1.5) * k, CFrame.new(0, 0.62 * k, 0), Color3.fromRGB(34, 34, 44), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			for i = -1, 1 do
				accessory(m, head, "CrownPoint", Vector3.new(0.3, 0.7, 0.3) * k, CFrame.new(i * 0.5 * k, 1.2 * k, 0), hc, Enum.Material.Neon)
			end
			accessory(m, head, "HatBrim", Vector3.new(1.6, 0.14, 1.7) * k, CFrame.new(0, 0.4 * k, 0), hc, Enum.Material.Metal)
		end
	end
	if torso then
		-- belt with a buckle
		if lower then
			accessory(m, lower, "Belt", Vector3.new(2.15, 0.35, 1.2), CFrame.new(0, 0.25, 0), Color3.fromRGB(60, 40, 28), Enum.Material.Leather)
			accessory(m, lower, "Buckle", Vector3.new(0.5, 0.4, 0.15), CFrame.new(0, 0.25, -0.62), Color3.fromRGB(255, 210, 70), Enum.Material.Metal)
		end
		if outfit.Vest then
			accessory(m, torso, "Vest", Vector3.new(2.25, 1.6, 1.3), CFrame.new(0, -0.1, 0), outfit.Vest, Enum.Material.SmoothPlastic)
			accessory(m, torso, "VestStripe", Vector3.new(2.3, 0.2, 1.35), CFrame.new(0, 0.15, 0), Color3.fromRGB(240, 240, 245), Enum.Material.Neon)
			accessory(m, torso, "VestStripe", Vector3.new(2.3, 0.2, 1.35), CFrame.new(0, -0.55, 0), Color3.fromRGB(240, 240, 245), Enum.Material.Neon)
		end
		-- collectible flair: rare outfits wear neon shoulder trim, Legendary also sparkle
		if outfit.Rarity ~= "Common" then
			local glow = RARITY_COLOR[outfit.Rarity] or Color3.new(1, 1, 1)
			for _, sx in { -1.25, 1.25 } do
				accessory(m, torso, "ShoulderTrim", Vector3.new(0.5, 0.25, 1.2), CFrame.new(sx, 0.85, 0), glow, Enum.Material.Neon)
			end
			if outfit.Rarity == "Legendary" or outfit.Rarity == "Mythic" then
				local s = Instance.new("Sparkles")
				s.SparkleColor = glow
				s.Parent = torso
			end
		end
		addTool(m, outfit, torso, hand)
	end
end

local function buildModel(owner: Player, def: any, outfitId: string): Model?
	if not template then
		return nil
	end
	local m = (template :: Model):Clone()
	m.Name = "Worker_" .. owner.UserId
	local hum = m:FindFirstChildOfClass("Humanoid")
	local hrp = m:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not hrp then
		m:Destroy()
		return nil
	end
	-- BodyColors would repaint the parts after we dress them; the Animate script is not needed (clients play our tracks)
	for _, c in m:GetChildren() do
		if c:IsA("BodyColors") or c.Name == "Animate" then
			c:Destroy()
		end
	end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.EvaluateStateMachine = false
	hum.WalkSpeed = 0
	m.PrimaryPart = hrp
	hrp.Anchored = true
	applyOutfit(m, WorkerConfig.Outfits[outfitId] or WorkerConfig.Outfits.Standard)
	-- the load the Worker carries: shown in front of the torso while it has cargo
	local torso = (m:FindFirstChild("UpperTorso") or hrp) :: BasePart
	local crate = accessory(m, torso, "Crate", Vector3.new(1.6, 1.2, 1.2), CFrame.new(0, -0.1, -1.25), Color3.new(1, 1, 1), Enum.Material.WoodPlanks)
	crate.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(150, 22)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.MaxDistance = 70
	gui.Adornee = hrp
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = RARITY_COLOR[(WorkerConfig.Outfits[outfitId] or WorkerConfig.Outfits.Standard).Rarity] or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = owner.DisplayName .. "'s " .. def.DisplayName
	label.Parent = gui
	gui.Parent = hrp
	m:SetAttribute("Owner", owner.UserId)
	m:SetAttribute("Outfit", outfitId)
	return m
end

local function efficiency(owner: Player): number
	return S.UpgradeService.Value(owner, "WorkerEfficiency")
end

-- Start a straight-line leg; clients animate between LegFrom and LegTo.
local function setLeg(w: Worker, to: Vector3, speed: number, nextState: string)
	local from = w.model:GetPivot().Position
	local flatTo = Vector3.new(to.X, from.Y, to.Z)
	local dist = (flatTo - from).Magnitude
	local duration = math.max(0.1, dist / speed)
	local look = if dist > 0.1 then CFrame.lookAt(from, flatTo) else w.model:GetPivot()
	w.model:PivotTo(look)
	w.model:SetAttribute("LegFrom", from)
	w.model:SetAttribute("LegTo", flatTo)
	w.model:SetAttribute("LegDuration", duration)
	w.model:SetAttribute("LegStart", now())
	w.state = nextState
	w.dest = flatTo
	w.legFrom = from
	w.legStart = now()
	w.until_ = now() + duration
end

local function setCrate(w: Worker)
	local crate = w.model:FindFirstChild("Crate") :: BasePart?
	if not crate then
		return
	end
	local res = w.res and ResourceConfig.Resources[w.res]
	if w.carry > 0 and res then
		crate.Transparency = 0
		local mt = w.mutTier and MutationConfig.Tiers[w.mutTier]
		crate.Color = if mt then mt.Color else res.Color
		crate.Material = if mt then Enum.Material.Neon else res.Material
	else
		crate.Transparency = 1
	end
	w.model:SetAttribute("Carry", w.carry)
	w.model:SetAttribute("CarryRes", w.res or "")
end

local function chooseResource(w: Worker): string?
	local d = S.PlayerDataService.Get(w.owner)
	local needed = S.BuildService.Needed()
	-- AUTO-REDIRECT: a live Golden / Diamond / Prismatic pile of a grade this Worker can haul beats everything else
	-- (Prismatic > Diamond > Golden). It is only checked here, i.e. between trips, so a Worker never abandons a load.
	w.pile = nil
	if S.MutationService then
		local typeDef = WorkerConfig.Types[w.model:GetAttribute("Type") or WorkerConfig.DefaultType] or WorkerConfig.Types.Builder
		local pile = S.MutationService.BestPile(typeDef.MaxGrade)
		if pile then
			w.pile = pile.id
			return pile.resId
		end
	end
	local assignment = d and d.Worker.Assignment or "Auto"
	if assignment ~= "Auto" and (needed[assignment] or 0) > 0 then
		return assignment
	end
	local def = WorkerConfig.Types[w.model:GetAttribute("Type") or WorkerConfig.DefaultType] or WorkerConfig.Types.Builder
	local best, bestN = nil, 0
	for res, n in needed do
		local r = ResourceConfig.Resources[res]
		-- premium grades are too heavy for most Workers: players (and Haulers) deliver those
		if r and not r.Secret and r.Grade <= def.MaxGrade and n > bestN then
			best, bestN = res, n
		end
	end
	return best
end

local function step(w: Worker)
	local def = WorkerConfig.Types[w.model:GetAttribute("Type") or WorkerConfig.DefaultType] or WorkerConfig.Types.Builder
	local eff = efficiency(w.owner)
	-- WORKER STATS SCALE WITH THE OWNER: tier share (Basic 50% .. Master 80%) of your carry, walk speed and gather speed
	local od = S.PlayerDataService.Get(w.owner)
	local playerCarry = Formulas.BaseCarry(od and od.Training.Strength or 0) * (1 + MasterBuilderConfig.Bonus(S.UpgradeService.MasterRank(w.owner), "CarryEffectiveness"))
	local playerSpeed = Formulas.BaseSpeed(od and od.Training.Speed or 0)
	local carryAmount, speed, gatherTime = WorkerConfig.Scaled(def, if od then od.Worker.Tier else nil, playerCarry, playerSpeed, S.UpgradeService.Value(w.owner, "GatherSpeed"), eff)
	-- type specialty: bonus on the material family being worked
	local resDef = w.res and ResourceConfig.Resources[w.res]
	local carryMult, speedMult, gatherMult = WorkerConfig.Modifiers(def, if resDef then resDef.Family else nil)
	carryAmount = math.max(1, math.floor(carryAmount * carryMult + 0.5))
	speed *= speedMult
	gatherTime *= gatherMult
	local building = S.BuildService.IsActive()
	if w.state == "Moving" or w.state == "ToZone" or w.state == "ToSite" or w.state == "ToStation" then
		if now() < w.until_ then
			return
		end
		if w.dest then
			w.model:PivotTo(CFrame.new(w.dest) * w.model:GetPivot().Rotation)
		end
	end
	if not building then
		if w.state ~= "Idle" and w.state ~= "ToStation" then
			setLeg(w, stationPoint(w.owner), speed, "ToStation")
		elseif w.state == "ToStation" then
			w.state = "Idle"
		end
		w.model:SetAttribute("State", w.state)
		return
	end
	if w.state == "Idle" or w.state == "ToStation" or w.state == "Moving" then
		w.res = chooseResource(w)
		local zp = targetPoint(w)
		if zp then
			setLeg(w, zp, speed, "ToZone")
		end
	elseif w.state == "ToZone" then
		w.state = "Gathering"
		w.until_ = now() + gatherTime
	elseif w.state == "Gathering" then
		if now() >= w.until_ then
			w.carry = carryAmount
			w.mutTier = nil
			if w.pile and S.MutationService then
				-- mutated load: taken from the pile's shared reserve (falls back to a plain load if it just ran out)
				local tier, units = S.MutationService.ClaimForWorker(w.pile, carryAmount)
				if tier and units > 0 then
					w.carry, w.mutTier = units, tier
				end
				w.pile = nil
			end
			setCrate(w)
			setLeg(w, sitePointToward(w.model:GetPivot().Position), speed, "ToSite")
		end
	elseif w.state == "ToSite" then
		w.state = "Depositing"
		w.until_ = now() + def.DepositTime
		if w.res and w.carry > 0 then
			local accepted = S.BuildService.Deposit(w.owner, w.res, w.carry, "Worker", w.mutTier)
			if accepted <= 0 and w.mutTier then
				-- the build does not need it: the mutated load still pays its Coins
				S.BuildService.PayUnits(w.owner, w.res, w.carry, MutationConfig.CoinFactor(w.mutTier, S.BuildIndexService.Bonus(w.owner, "MutationValue")))
			end
		end
		w.carry = 0
		w.mutTier = nil
		setCrate(w)
	elseif w.state == "Depositing" then
		if now() >= w.until_ then
			w.res = chooseResource(w)
			local zp = targetPoint(w)
			if zp then
				setLeg(w, zp, speed, "ToZone")
			else
				w.state = "Idle"
			end
		end
	end
	w.model:SetAttribute("State", w.state)
end

function WorkerService.Init(registry)
	S = registry
	ensureTemplate()
	folder = Instance.new("Folder")
	folder.Name = "Workers"
	folder.Parent = workspace
end

function WorkerService.Despawn(player: Player)
	local w = workers[player]
	if w then
		w.model:Destroy()
		workers[player] = nil
	end
end

function WorkerService.Spawn(player: Player)
	local d = S.PlayerDataService.Get(player)
	if not d or not d.Worker.Unlocked or not d.Worker.Enabled or workers[player] then
		return
	end
	ensureTemplate()
	-- the R15 rig is generated asynchronously once; wait for it (a few seconds at most, once per server)
	local waited = 0
	while not template and waited < 15 do
		task.wait(0.25)
		waited += 0.25
	end
	if workers[player] or not player.Parent or not d.Worker.Enabled then
		return
	end
	local def = WorkerConfig.Types[d.Worker.Type] or WorkerConfig.Types.Builder
	local m = buildModel(player, def, d.Worker.Outfit or def.Outfit)
	if not m then
		return
	end
	m:SetAttribute("Type", def.Id)
	m:SetAttribute("Tier", d.Worker.Tier or WorkerConfig.DefaultTier)
	local pos = stationPoint(player)
	m:PivotTo(CFrame.new(pos))
	m.Parent = folder
	S.LaunchTelemetryService.Milestone(player, "FirstWorker")
	workers[player] = { owner = player, model = m, state = "Idle", res = nil, carry = 0, until_ = 0, dest = nil, legFrom = nil, legStart = 0, pile = nil, mutTier = nil, pause = nil }
	m:SetAttribute("State", "Idle")
end

-- Switch to an owned Worker type (free) or buy a new one once (Coins). Still ONE active Worker.
function WorkerService.SetType(player: Player, typeId: string): (boolean, string)
	local d = S.PlayerDataService.Get(player)
	local def = WorkerConfig.Types[typeId]
	if not d or not def or not d.Worker.Unlocked then
		return false, "Hire a Worker first"
	end
	local owned = d.Worker.OwnedTypes
	if not owned[typeId] then
		if d.Coins < def.Price then
			return false, "Not enough Coins"
		end
		S.PlayerDataService.AddCoins(player, -def.Price)
		owned[typeId] = true
		S.CosmeticService.Grant(player, "WorkerOutfit", def.Outfit, "Worker type")
	end
	d.Worker.Type = typeId
	d.Worker.Outfit = def.Outfit
	S.PlayerDataService.MarkDirty(player)
	WorkerService.Despawn(player)
	task.spawn(WorkerService.Spawn, player)
	return true, "ok"
end

------------------------------------------------------------------ Worker Crates (Coins only)
-- Price rises with the number of crates opened this cycle (WorkerConfig.Crate). Each opening rolls one (type, tier) Worker from the
-- tiers the player has unlocked through Master Builder rank. A Worker you already own becomes Worker Tokens. Tokens can Forge the
-- equipped Worker up a tier. A pity counter guarantees a better tier after a streak of Basic rolls. No UI is required: the
-- Net function "WorkerCrate" and the debug bridge both call these.
function WorkerService.CratePrice(player: Player): number
	local d = S.PlayerDataService.Get(player)
	local c = WorkerConfig.Crate
	if d and not d.Worker.Unlocked then
		return WorkerConfig.FirstHirePrice -- the first recruit is cheap and guaranteed (see OpenCrate)
	end
	local n = d and d.Worker.CrateCount or 0
	return math.min(c.MaxPrice, math.floor(c.Price * c.PriceGrowth ^ math.min(n, 30)))
end

local function availableTiers(player: Player): { string }
	local rank = S.UpgradeService.MasterRank(player)
	local out = {}
	for _, id in WorkerConfig.TierOrder do
		if MasterBuilderConfig.WorkerTierUnlocked(rank, id) then
			table.insert(out, id)
		end
	end
	return out
end

function WorkerService.OpenCrate(player: Player, forcedRng: Random?): (boolean, any)
	local d = S.PlayerDataService.Get(player)
	if not d then
		return false, "Data not loaded"
	end
	local price = WorkerService.CratePrice(player)
	if not S.PlayerDataService.TrySpend(player, price) then
		return false, "Not enough Coins"
	end
	if not d.Worker.Unlocked then
		-- FIRST HIRE: a guaranteed Basic General Laborer that starts working immediately (onboarding objective)
		local typeId, tier = WorkerConfig.DefaultType, WorkerConfig.DefaultTier
		d.Worker.Owned = d.Worker.Owned or {}
		d.Worker.Owned[typeId .. ":" .. tier] = true
		d.Worker.Unlocked, d.Worker.Enabled = true, true
		d.Worker.Type, d.Worker.Tier = typeId, tier
		d.Worker.Outfit = WorkerConfig.Types[typeId].Outfit
		S.PlayerDataService.MarkDirty(player)
		S.PlayerDataService.Sync(player)
		task.spawn(WorkerService.Spawn, player)
		return true, { Type = typeId, Tier = tier, New = true, Tokens = 0, Spent = price, First = true }
	end
	local rng = forcedRng or Random.new()
	local tiers = availableTiers(player)
	local pity = WorkerConfig.Crate.Pity
	local guaranteeIdx = table.find(WorkerConfig.TierOrder, pity.GuaranteeTier) or 2
	-- pity: Worker.PityCount = crates since the last tier >= GuaranteeTier
	local pityCount = d.Worker.PityCount or 0
	local tier
	if pityCount >= pity.Threshold and table.find(tiers, pity.GuaranteeTier) then
		-- guaranteed: roll only among tiers at or above the guaranteed one
		local pool = {}
		for _, id in tiers do
			if (table.find(WorkerConfig.TierOrder, id) or 1) >= guaranteeIdx then
				table.insert(pool, id)
			end
		end
		tiers = pool
	end
	local total = 0
	for _, id in tiers do
		total += WorkerConfig.Tiers[id].CrateWeight
	end
	local x = rng:NextNumber() * total
	for _, id in tiers do
		x -= WorkerConfig.Tiers[id].CrateWeight
		if x <= 0 then
			tier = id
			break
		end
	end
	tier = tier or tiers[1]
	if (table.find(WorkerConfig.TierOrder, tier) or 1) >= guaranteeIdx then
		d.Worker.PityCount = 0
	else
		d.Worker.PityCount = pityCount + 1
	end
	local typeId = WorkerConfig.TypeOrder[rng:NextInteger(1, #WorkerConfig.TypeOrder)]
	local key = typeId .. ":" .. tier
	d.Worker.CrateCount = (d.Worker.CrateCount or 0) + 1
	d.Worker.Owned = d.Worker.Owned or {}
	local isNew = not d.Worker.Owned[key]
	local tokens = 0
	if isNew then
		local firstWorker = not d.Worker.Unlocked
		d.Worker.Owned[key] = true
		d.Worker.OwnedTypes[typeId] = true
		d.Worker.Unlocked = true
		local def = WorkerConfig.Types[typeId]
		S.CosmeticService.Grant(player, "WorkerOutfit", def.Outfit, "Worker crate")
		if firstWorker then
			-- the first Worker from a crate is simply hired: equip and send it to work
			d.Worker.Type, d.Worker.Tier, d.Worker.Outfit = typeId, tier, def.Outfit
			task.spawn(WorkerService.Spawn, player)
		end
	else
		tokens = WorkerConfig.Tiers[tier].TokenValue
		d.Worker.Tokens = (d.Worker.Tokens or 0) + tokens
	end
	S.PlayerDataService.MarkDirty(player)
	S.PlayerDataService.Sync(player)
	return true, { Type = typeId, Tier = tier, New = isNew, Tokens = tokens, Spent = price }
end

-- Equip an owned (type, tier) Worker.
function WorkerService.Equip(player: Player, typeId: string, tier: string): (boolean, string)
	local d = S.PlayerDataService.Get(player)
	if not d or not WorkerConfig.Types[typeId] or not WorkerConfig.Tiers[tier] then
		return false, "Unknown Worker"
	end
	local owned = (typeId == WorkerConfig.DefaultType and tier == WorkerConfig.DefaultTier and d.Worker.Unlocked) or (d.Worker.Owned and d.Worker.Owned[typeId .. ":" .. tier])
	if not owned then
		return false, "You don't own that Worker"
	end
	d.Worker.Type, d.Worker.Tier = typeId, tier
	d.Worker.Outfit = WorkerConfig.Types[typeId].Outfit
	S.PlayerDataService.MarkDirty(player)
	WorkerService.Despawn(player)
	task.spawn(WorkerService.Spawn, player)
	return true, "ok"
end

-- Spend Worker Tokens to raise the equipped Worker one tier (if that tier is unlocked by Master Builder rank).
function WorkerService.Forge(player: Player): (boolean, string)
	local d = S.PlayerDataService.Get(player)
	if not d or not d.Worker.Unlocked then
		return false, "Hire a Worker first"
	end
	local idx = table.find(WorkerConfig.TierOrder, d.Worker.Tier or WorkerConfig.DefaultTier) or 1
	local nextId = WorkerConfig.TierOrder[idx + 1]
	if not nextId then
		return false, "Already the top tier"
	end
	if not MasterBuilderConfig.WorkerTierUnlocked(S.UpgradeService.MasterRank(player), nextId) then
		return false, "That tier needs a higher Master Builder rank"
	end
	local cost = WorkerConfig.Tiers[nextId].ForgeCost or math.huge
	if (d.Worker.Tokens or 0) < cost then
		return false, string.format("Needs %d Worker Tokens", cost)
	end
	d.Worker.Tokens -= cost
	d.Worker.Tier = nextId
	d.Worker.Owned = d.Worker.Owned or {}
	d.Worker.Owned[d.Worker.Type .. ":" .. nextId] = true
	S.PlayerDataService.MarkDirty(player)
	WorkerService.Despawn(player)
	task.spawn(WorkerService.Spawn, player)
	return true, "ok"
end

function WorkerService.SetOutfit(player: Player, outfitId: string): (boolean, string)
	local d = S.PlayerDataService.Get(player)
	local outfit = WorkerConfig.Outfits[outfitId]
	if not d or not outfit then
		return false, "Unknown outfit"
	end
	if outfitId ~= WorkerConfig.DefaultOutfit and not (d.Cosmetics.WorkerOutfit and d.Cosmetics.WorkerOutfit[outfitId]) then
		return false, "Outfit not owned"
	end
	d.Worker.Outfit = outfitId
	S.PlayerDataService.MarkDirty(player)
	WorkerService.Despawn(player)
	task.spawn(WorkerService.Spawn, player)
	return true, "ok"
end

function WorkerService.Count(): number
	local n = 0
	for _ in workers do
		n += 1
	end
	return n
end

local function setLabel(w: Worker, text: string)
	local root = w.model.PrimaryPart
	local gui = root and root:FindFirstChildOfClass("BillboardGui")
	local label = gui and gui:FindFirstChildOfClass("TextLabel")
	if label then
		label.Text = text
	end
end

local function pauseWorker(w: Worker)
	local t = now()
	local moving = MOVING[w.state] == true and w.dest ~= nil and t < w.until_
	if moving and w.legFrom and w.dest then
		-- freeze at the current interpolated position
		local total = math.max(0.01, w.until_ - w.legStart)
		local pos = w.legFrom:Lerp(w.dest, math.clamp((t - w.legStart) / total, 0, 1))
		w.model:PivotTo(CFrame.new(pos) * w.model:GetPivot().Rotation)
		w.model:SetAttribute("LegFrom", pos)
		w.model:SetAttribute("LegTo", pos)
		w.model:SetAttribute("LegDuration", 0.05)
		w.model:SetAttribute("LegStart", t)
	end
	w.pause = { state = w.state, remaining = math.max(0, w.until_ - t), moving = moving }
	w.model:SetAttribute("Strike", true)
	setLabel(w, "✋ ON STRIKE")
end

local function resumeWorker(w: Worker)
	local pz = w.pause
	w.pause = nil
	w.model:SetAttribute("Strike", nil)
	setLabel(w, w.owner.DisplayName .. "'s " .. (WorkerConfig.Types[w.model:GetAttribute("Type") or WorkerConfig.DefaultType] or WorkerConfig.Types.Builder).DisplayName)
	if not pz then
		return
	end
	if pz.moving and w.dest then
		local def = WorkerConfig.Types[w.model:GetAttribute("Type") or WorkerConfig.DefaultType] or WorkerConfig.Types.Builder
		local _, resumeSpeed = Formulas.WorkerStats(def, efficiency(w.owner))
		setLeg(w, w.dest, resumeSpeed, pz.state)
	else
		w.state = pz.state
		w.until_ = now() + pz.remaining
	end
end

-- Worker Strike: freeze every worker in place (keeping its load and task) / resume.
function WorkerService.SetPaused(value: boolean)
	if paused == value then
		return
	end
	paused = value
	for _, w in workers do
		if value then
			pauseWorker(w)
		else
			resumeWorker(w)
		end
	end
end

-- Call when the build ends so workers drop their loads and head home.
function WorkerService.ResetAll()
	for _, w in workers do
		w.carry = 0
		w.res = nil
		setCrate(w)
		w.state = "Moving"
		w.until_ = 0
	end
end

local limiter = Net.RateLimiter(2, 4)

function WorkerService.Start()
	S.PlayerDataService.Loaded:Connect(function(player)
		WorkerService.Spawn(player)
	end)
	Players.PlayerRemoving:Connect(WorkerService.Despawn)
	local crateLimiter = Net.RateLimiter(0.5, 2)
	Net.Function("WorkerCrate").OnServerInvoke = function(player, cmd, arg)
		if not crateLimiter(player) then
			return false, "Slow down"
		end
		if cmd == "Open" then
			return WorkerService.OpenCrate(player)
		elseif cmd == "Equip" and type(arg) == "table" and type(arg.Type) == "string" and type(arg.Tier) == "string" then
			return WorkerService.Equip(player, arg.Type, arg.Tier)
		elseif cmd == "Info" then
			local d = S.PlayerDataService.Get(player)
			return true, { Price = WorkerService.CratePrice(player), Tokens = d and d.Worker.Tokens or 0 }
		elseif cmd == "Forge" then
			return WorkerService.Forge(player)
		end
		return false, "Unknown command"
	end
	Net.Event("WorkerCommand").OnServerEvent:Connect(function(player, cmd, arg)
		if not limiter(player) then
			return
		end
		local d = S.PlayerDataService.Get(player)
		if not d or not d.Worker.Unlocked then
			return
		end
		if cmd == "SetEnabled" and type(arg) == "boolean" then
			d.Worker.Enabled = arg
			if arg then
				WorkerService.Spawn(player)
			else
				WorkerService.Despawn(player)
			end
			S.PlayerDataService.MarkDirty(player)
		elseif cmd == "Assign" and type(arg) == "string" and table.find(WorkerConfig.Assignments, arg) then
			d.Worker.Assignment = arg
			S.PlayerDataService.MarkDirty(player)
		elseif cmd == "SetType" and type(arg) == "string" then
			WorkerService.SetType(player, arg)
		elseif cmd == "SetOutfit" and type(arg) == "string" then
			WorkerService.SetOutfit(player, arg)
		elseif cmd == "Forge" then
			WorkerService.Forge(player)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.2)
			for player, w in workers do
				if not player.Parent then
					WorkerService.Despawn(player)
				elseif paused then
					if not w.pause then
						pauseWorker(w) -- spawned during a strike
					end
				else
					local ok, err = pcall(step, w)
					if not ok then
						warn("[Worker] step error", err)
					end
				end
			end
		end
	end)
end

return WorkerService
