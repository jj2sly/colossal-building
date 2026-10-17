--!strict
-- The active Mega Build: requirements, staged physical assembly, damage + repairs,
-- and completion. Knows nothing about specific builds; everything comes from
-- BuildConfig + the template model (see docs/BUILD_AUTHORING.md).
--
-- Assembly: overall progress p = delivered/required (capped per resource). Stage i
-- owns the progress band [(i-1)/N, i/N]; its pieces appear in order as p moves through
-- that band. Hidden pieces wait in ServerStorage (not replicated), and revealed pieces
-- are stamped with BuiltAt so clients play a local build-in animation (no server tweens).
--
-- Damage: completed stages ("sections") can be Damaged by events. A damaged section
-- shows visible damage and gets its own repair requirements. Deposits fill repairs
-- first. A build cannot complete while damaged, but repairs are always achievable, so
-- there is no hard failure.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local GameConfig = require(Shared.Config.GameConfig)
local BuildConfig = require(Shared.Config.BuildConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local MutationConfig = require(Shared.Config.MutationConfig)
local ColossalConfig = require(Shared.Config.ColossalConfig)

type Piece = { part: BasePart, parent: Instance, shown: boolean }
type Repair = { need: { [string]: number }, have: { [string]: number } }
type Stage = {
	index: number,
	name: string,
	model: Instance,
	pieces: { Piece },
	shown: number,
	complete: boolean,
	damaged: boolean,
	repair: Repair?,
	saved: { [BasePart]: { Color: Color3, Material: Enum.Material, CFrame: CFrame } }?,
	fx: { Instance },
}
type Active = {
	def: any,
	modifiers: { string },
	scale: number,
	model: Model,
	stages: { Stage },
	need: { [string]: number },
	have: { [string]: number },
	startedAt: number,
	locked: boolean,
	completedStages: number,
	activateAt: number?, -- partial activation point (progress fraction), nil = none
	activated: boolean,
	milestone: number, -- how many of def.Milestones have been reached
	revealBudget: number,
}

local BuildService = {}
local FALLBACK_FOR: { [string]: string } = {}
BuildService.Completed = Signal.new() -- ()
BuildService.StageCompleted = Signal.new() -- (index)
BuildService.Activated = Signal.new() -- (def) the build came alive before completion (see ColossalConfig.Activation)

local S: any
local active: Active? = nil
local hidden: Folder
local dirty = false
local MAX_REVEALS_PER_FLUSH = 10
local FLUSH_INTERVAL = 0.25

-- Completion touches driven purely by part attributes, so any template can use them:
--   PowerLight -> glowing neon + light,  Lava -> rising smoke.
local function applyCompletionAttributes(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d:GetAttribute("PowerLight") then
				d.Material = Enum.Material.Neon
				d.Color = Color3.fromRGB(90, 230, 255)
				local light = Instance.new("PointLight")
				light.Color = d.Color
				light.Range = 18
				light.Brightness = 2
				light.Parent = d
			elseif d:GetAttribute("Lava") then
				local smoke = Instance.new("Smoke")
				smoke.Color = Color3.fromRGB(90, 70, 60)
				smoke.Opacity = 0.15
				smoke.RiseVelocity = 6
				smoke.Size = 6
				smoke.Parent = d
			end
		end
	end
end

-- Optional per-build hooks keyed by BuildConfig.SpecialMechanic (for behaviour that
-- attributes can't express). Unknown ids are ignored.
local Mechanics: { [string]: { OnComplete: ((Model) -> ())?, OnActivate: ((Model) -> ())? } } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function sortPieces(list: { BasePart }, origin: Vector3)
	table.sort(list, function(a, b)
		local oa, ob = a:GetAttribute("Order"), b:GetAttribute("Order")
		if oa ~= nil or ob ~= nil then
			return (oa or math.huge) < (ob or math.huge)
		end
		local ya = a.Position.Y - a.Size.Y / 2
		local yb = b.Position.Y - b.Size.Y / 2
		if math.abs(ya - yb) > 0.05 then
			return ya < yb
		end
		return (a.Position - origin).Magnitude < (b.Position - origin).Magnitude
	end)
end

local function progressOf(a: Active): number
	local got, req = 0, 0
	for res, n in a.need do
		req += n
		got += math.min(n, a.have[res] or 0)
	end
	return if req > 0 then got / req else 1
end

local function publishRequirements(a: Active)
	for res, n in a.need do
		S.StateService.Set("Need_" .. res, n)
		S.StateService.Set("Have_" .. res, math.floor(math.min(n, a.have[res] or 0)))
	end
	-- aggregate repairs
	local rn, rh = {}, {}
	local damagedCount = 0
	for _, st in a.stages do
		if st.damaged and st.repair then
			damagedCount += 1
			for res, n in st.repair.need do
				rn[res] = (rn[res] or 0) + n
				rh[res] = (rh[res] or 0) + (st.repair.have[res] or 0)
			end
		end
	end
	for id in ResourceConfig.Resources do
		S.StateService.Set("RepairNeed_" .. id, rn[id] or 0)
		S.StateService.Set("RepairHave_" .. id, rh[id] or 0)
	end
	S.StateService.Set("DamagedSections", damagedCount)
	S.StateService.Set("Progress", math.floor(progressOf(a) * 1000) / 1000)
end

local function stageCenter(st: Stage): Vector3
	local sum, n = Vector3.zero, 0
	for _, pc in st.pieces do
		sum += pc.part.Position
		n += 1
	end
	return if n > 0 then sum / n else GameConfig.Site.Center
end

local function revealPiece(pc: Piece)
	pc.shown = true
	pc.part:SetAttribute("BuiltAt", now())
	pc.part.Parent = pc.parent
end

local function flush()
	local a = active
	if not a then
		return
	end
	dirty = false
	publishRequirements(a)
	local p = progressOf(a)
	local n = #a.stages
	local budget = a.revealBudget
	for i, st in a.stages do
		local bandP = if p >= 1 then 1 else math.clamp(p * n - (i - 1) + 1e-9, 0, 1)
		local target = if bandP >= 1 then #st.pieces else math.floor(bandP * #st.pieces)
		while st.shown < target and budget > 0 do
			st.shown += 1
			revealPiece(st.pieces[st.shown])
			budget -= 1
		end
		if st.shown < target then
			dirty = true -- more to reveal next flush (keeps big jumps animated)
		end
		if not st.complete and st.shown >= #st.pieces then
			st.complete = true
			a.completedStages += 1
			S.StateService.Set("Stage", a.completedStages)
			Net.Event("Effect"):FireAllClients("StageComplete", {
				Stage = i,
				Name = if a.def.Forgotten then nil else st.name, -- a Forgotten stage name is client-side identity data only
				Position = stageCenter(st),
				Total = n,
			})
			BuildService.StageCompleted:Fire(i)
		end
	end
	-- PARTIAL ACTIVATION: once per build, when progress first reaches the activation point (lights, motion, a mechanic)
	if not a.activated and a.activateAt and p >= a.activateAt then
		a.activated = true
		S.StateService.Set("BuildActivated", true)
		local mech = a.def.SpecialMechanic and Mechanics[a.def.SpecialMechanic]
		if mech and mech.OnActivate then
			mech.OnActivate(a.model)
		end
		Net.Event("Effect"):FireAllClients("BuildActivated", { BuildId = a.def.Id, Rarity = if a.def.Forgotten then "Mythic" else a.def.Rarity, Progress = p })
		BuildService.Activated:Fire(a.def)
	end
	-- later activation steps (e.g. the duck starts looking around): replicated as one counter clients can read on join
	local ms = a.def.Milestones
	if ms and a.activated then
		while ms[a.milestone + 1] and p >= ms[a.milestone + 1] do
			a.milestone += 1
			S.StateService.Set("BuildMilestone", a.milestone)
		end
	end
	if not a.locked and p >= 1 and a.completedStages >= n then
		local anyDamaged = false
		for _, st in a.stages do
			if st.damaged then
				anyDamaged = true
				break
			end
		end
		if not anyDamaged then
			a.locked = true
			BuildService.Completed:Fire()
		end
	end
end

function BuildService.Init(registry)
	S = registry
	hidden = Instance.new("Folder")
	hidden.Name = "MB_HiddenBuildPieces"
	hidden.Parent = ServerStorage
end

-- Lightweight, replicated copies of every build for the Build Index 3D previews
-- (ReplicatedStorage.BuildPreviews/<BuildId>). Generated from BuildConfig + the templates, so a new
-- build gets a preview automatically. Only static geometry is kept: no scripts, lights, particles,
-- sounds, GUIs or the template's Effects folder.
local STRIP = { "Script", "LocalScript", "ModuleScript", "Sound", "Light", "ParticleEmitter", "Fire", "Smoke", "Sparkles", "Trail", "Beam", "Highlight", "BillboardGui", "SurfaceGui", "ProximityPrompt", "Constraint", "Attachment" }
local function buildPreviews()
	local templates = ServerStorage:FindFirstChild("BuildTemplates")
	if not templates then
		return
	end
	local old = ReplicatedStorage:FindFirstChild("BuildPreviews")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "BuildPreviews"
	for _, def in BuildConfig.Builds do
		local template = def.Enabled and not def.Forgotten and templates:FindFirstChild(def.Template) -- Forgotten previews are never replicated
		if template then
			local clone = (template :: Instance):Clone()
			clone.Name = def.Id
			local effects = clone:FindFirstChild("Effects")
			if effects then
				effects:Destroy()
			end
			for _, d in clone:GetDescendants() do
				local drop = false
				for _, cls in STRIP do
					if d:IsA(cls) then
						drop = true
						break
					end
				end
				if drop then
					d:Destroy()
				elseif d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanTouch = false
					d.CanQuery = false
					d.CastShadow = false
				end
			end
			clone.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
end

function BuildService.Start()
	buildPreviews()
	task.spawn(function()
		while true do
			task.wait(FLUSH_INTERVAL)
			if dirty and active then
				flush()
			end
		end
	end)
end

function BuildService.IsActive(): boolean
	return active ~= nil and not (active :: Active).locked
end

-- Forgotten soft-lock failsafe: HeavySteel stands in for Star Metal, Timber for Ancient Timber (active project only)
FALLBACK_FOR = { HeavySteel = "StarMetal", Timber = "AncientTimber" }
-- the stand-in for a secret resource id (nil when none)
function BuildService.FallbackOf(secretRes: string): string?
	for alt, sec in FALLBACK_FOR do
		if sec == secretRes then
			return alt
		end
	end
	return nil
end
function BuildService.EnableSecretFallback()
	if active then
		(active :: any).secretFallback = true
	end
end

function BuildService.Get(): Active?
	return active
end

function BuildService.ComputeRequirements(def: any, modifiers: { string }, scale: number, secretScales: { [string]: number }?, subs: { [string]: string }?): { [string]: number }
	local reqMult = S.ModifierService.Multipliers(modifiers)
	local need = {}
	for res, base in def.Requirements do
		local alt = subs and subs[res]
		if alt then
			-- start-time substitution (this project's instance only; the authored def is untouched): the secret line is paid in its Tier 3
			-- stand-in at the normal server scaling
			need[alt] = (need[alt] or 0) + math.max(5, math.ceil(base * scale * reqMult))
		else
			need[res] = math.max(5, math.ceil(base * ((secretScales and secretScales[res]) or scale) * reqMult))
		end
	end
	return need
end

-- Begin a build. `scale` = requirement scale (player count, dev multiplier).
function BuildService.Begin(buildId: string, modifiers: { string }, scale: number, secretScales: { [string]: number }?, subs: { [string]: string }?): boolean
	BuildService.Clear()
	local def = BuildConfig.Get(buildId)
	local templates = ServerStorage:FindFirstChild("BuildTemplates")
	local template = def and templates and templates:FindFirstChild(def.Template)
	if not def or not template then
		warn("[Build] missing build or template:", buildId)
		return false
	end
	local model = (template :: Model):Clone()
	model.Name = "ActiveBuild"
	local site = GameConfig.Site
	-- colossal templates are authored at final size (TemplateScale = 1); older ones get the site-wide BuildScale
	model:ScaleTo(model:GetScale() * (def.TemplateScale or site.BuildScale or 1))
	S.ModifierService.ApplyVisuals(model, modifiers)
	-- every build sits on the one shared local origin (deck centre, deck surface, facing the spawn); see ColossalConfig
	model:PivotTo(ColossalConfig.PlacementFor(def))

	local need = BuildService.ComputeRequirements(def, modifiers, scale, secretScales, subs)

	local stages: { Stage } = {}
	local containers = {}
	for _, c in model:GetChildren() do
		local idx = tonumber(string.match(c.Name, "^Stage_(%d+)$"))
		if idx then
			table.insert(containers, { idx = idx, inst = c })
		end
	end
	table.sort(containers, function(x, y)
		return x.idx < y.idx
	end)
	for i, c in containers do
		local parts = {}
		for _, d in c.inst:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			end
		end
		sortPieces(parts, site.Center)
		local pieces = {}
		for _, part in parts do
			part.Anchored = true
			part.CanTouch = false -- nothing listens to Touched on build pieces (decorative)
			table.insert(pieces, { part = part, parent = part.Parent :: Instance, shown = false })
		end
		table.insert(stages, {
			index = i,
			name = def.StageNames[i] or c.inst.Name,
			model = c.inst,
			pieces = pieces,
			shown = 0,
			complete = false,
			damaged = false,
			repair = nil,
			saved = nil,
			fx = {},
		})
	end
	-- hide all pieces until earned
	for _, st in stages do
		for _, pc in st.pieces do
			pc.part.Parent = hidden
		end
	end
	local effects = model:FindFirstChild("Effects")
	if effects then
		effects.Parent = hidden
	end
	model.Parent = workspace

	active = {
		def = def,
		modifiers = modifiers,
		scale = scale,
		model = model,
		stages = stages,
		need = need,
		have = {},
		startedAt = now(),
		locked = false,
		completedStages = 0,
		activateAt = ColossalConfig.ActivationFraction(def),
		activated = false,
		milestone = 0,
		-- colossal builds have many more pieces per stage: reveal at least ~1/40 of the biggest stage per flush so a big
		-- delivery still animates in a few seconds (small builds keep the old 10)
		revealBudget = (function()
			local most = 0
			for _, st in stages do
				most = math.max(most, #st.pieces)
			end
			return math.max(MAX_REVEALS_PER_FLUSH, math.ceil(most / 40))
		end)(),
	}
	S.StateService.Set("BuildActivated", false)
	S.StateService.Set("BuildMilestone", 0)
	S.StateService.ClearPrefixed({ "Need_", "Have_", "RepairNeed_", "RepairHave_" })
	S.StateService.Set("StageCount", #stages)
	S.StateService.Set("Stage", 0)
	S.StateService.Set("BuildStartedAt", now())
	publishRequirements(active :: Active)
	return true
end

-- Remaining units per resource (repairs + construction).
function BuildService.Needed(): { [string]: number }
	local out = {}
	local a = active
	if not a or a.locked then
		return out
	end
	for res, n in a.need do
		local rem = n - (a.have[res] or 0)
		if rem > 0 then
			out[res] = rem
		end
	end
	for _, st in a.stages do
		if st.damaged and st.repair then
			for res, n in st.repair.need do
				local rem = n - (st.repair.have[res] or 0)
				if rem > 0 then
					out[res] = (out[res] or 0) + rem
				end
			end
		end
	end
	return out
end

local function finishRepair(a: Active, st: Stage)
	st.damaged = false
	st.repair = nil
	if st.saved then
		for part, props in st.saved do
			part.Color = props.Color
			part.Material = props.Material
			part.CFrame = props.CFrame
		end
	end
	st.saved = nil
	for _, fx in st.fx do
		fx:Destroy()
	end
	st.fx = {}
	Net.Event("Effect"):FireAllClients("Repaired", { Stage = st.index, Name = st.name, Position = stageCenter(st) })
end

-- Deposit `amount` of `resId` on behalf of `owner`. source: "Player" | "Worker".
-- Returns the units taken from the carrier (repairs first, then construction).
-- Rewards contribution + Coins immediately (Golden Hour / Build Frenzy aware).
--
-- RESOURCE GRADES: a delivered grade fills the requirement on its own id first (a Timber requirement), then on
-- every lower grade of the same family (Logs, then the any-grade "Wood" requirement). Each delivered unit counts
-- `Equivalent` units (a Log counts more than a Stick); all build/repair accounting below is in those counted units
-- and the carrier is only charged the real units used (converted back at the end).
-- Shared Coin multiplier for deposits (friends, events, rarity share, boosts, Index bonuses) so deliveries and mutated-unit
-- cash-outs always pay the same way. `rarityId` is the active build's rarity (nil = none).
function BuildService.CoinMultiplier(owner: Player, rarityId: string?): number
	local friend = S.FriendService.GetBonus(owner)
	local rarityFactor = if rarityId then 1 + EconomyConfig.DepositRarityShare * (RarityConfig.Get(rarityId).RewardMultiplier - 1) else 1
	return (1 + friend) * S.EventService.CoinMultiplier() * rarityFactor * S.BoostService.Mult(owner, "Coins")
		* (1 + S.BuildIndexService.Bonus(owner, "Coins")) * (1 + S.BuildIndexService.Bonus(owner, "ResourceValue"))
end

-- Coins for `units` carried units of `resId` worth `factor` each beyond their grade (mutations). Used when a mutated unit
-- cannot go into the build (the active build does not need that material) or when a Worker's load is unneeded.
function BuildService.PayUnits(owner: Player, resId: string, units: number, factor: number): number
	local res = ResourceConfig.Resources[resId]
	if not res or units <= 0 or not owner.Parent then
		return 0
	end
	local coins = units * res.CoinsPerUnit * MutationConfig.GradeCoin(res.Grade) * factor * BuildService.CoinMultiplier(owner, if active then active.def.Rarity else nil)
	S.PlayerDataService.AddCoins(owner, coins)
	return coins
end

function BuildService.Deposit(owner: Player, resId: string, amount: number, source: string, mutTier: string?): number
	local a = active
	local res = ResourceConfig.Resources[resId]
	if not a or a.locked or not res or amount <= 0 then
		return 0
	end
	local carried = math.floor(amount)
	local mutBonus = S.BuildIndexService.Bonus(owner, "MutationValue")
	local q = if source == "Player" then S.ResourceService.GetQuality(owner, resId) else res.Equivalent * (if mutTier then MutationConfig.BuildFactor(mutTier, mutBonus) else 1)
	local remaining = math.floor(carried * q + 0.5)
	local repaired, built = 0, 0
	local keys = ResourceConfig.RequirementsFor(resId)
	if (a :: any).secretFallback then
		-- soft-lock failsafe for THIS Forgotten project only: Tier 3 stand-ins may fill the remaining secret lines
		local ext = table.clone(keys)
		for _, k in keys do
			local alt = FALLBACK_FOR[k]
			if alt and a.need[alt] then
				table.insert(ext, alt)
			end
		end
		keys = ext
	end
	-- repairs first
	for _, st in a.stages do
		if remaining <= 0 then
			break
		end
		if st.damaged and st.repair then
			for _, key in keys do
				local need = (st.repair.need[key] or 0) - (st.repair.have[key] or 0)
				if need > 0 and remaining > 0 then
					local take = math.min(need, remaining)
					st.repair.have[key] = (st.repair.have[key] or 0) + take
					remaining -= take
					repaired += take
				end
			end
			local done = true
			for r, n in st.repair.need do
				if (st.repair.have[r] or 0) < n then
					done = false
					break
				end
			end
			if done then
				finishRepair(a, st)
			end
		end
	end
	-- then construction. Build Frenzy makes each delivered unit count `cm` units.
	local cm = S.EventService.ConstructionMultiplier()
	local usedForBuild = 0
	for _, key in keys do
		local constructionNeed = (a.need[key] or 0) - (a.have[key] or 0)
		if remaining > 0 and constructionNeed > 0 then
			local used = math.min(remaining, math.ceil(constructionNeed / cm))
			local got = math.min(constructionNeed, math.floor(used * cm + 0.5))
			a.have[key] = (a.have[key] or 0) + got
			remaining -= used
			usedForBuild += used
			built += got
		end
	end
	local accepted = repaired + usedForBuild -- counted units used
	if accepted <= 0 then
		return 0
	end
	if source == "Player" and owner.Parent then
		local td = S.PlayerDataService.Get(owner)
		if td and td.Tutorial and not td.Tutorial.Done then
			td.Tutorial.Done = true -- the basic gather -> carry -> deliver introduction is complete (persisted; never replayed)
			S.PlayerDataService.MarkDirty(owner)
			S.PlayerDataService.Sync(owner)
		end
	end
	if a.def.Forgotten and S.ForgottenService and owner.Parent then
		S.ForgottenService.OnContribution(owner) -- a first legitimate contribution pays a pending first-discovery reward
	end
	local carrierUnits = math.min(carried, math.max(1, math.ceil(accepted / q - 1e-6)))
	dirty = true

	-- contribution + coins
	local cw = GameConfig.Contribution
	local weight = if source == "Worker" then cw.WorkerWeight else 1
	local resValue = 1 + S.BuildIndexService.Bonus(owner, "ResourceValue")
	local gradeBonus = 1 + (MutationConfig.GradeContributionBonus[res.Grade] or 0) -- small extra contribution for premium grades
	local points = (built + repaired * cw.RepairWeight) * res.Value * weight * gradeBonus * resValue
	if owner.Parent then
		S.ContributionService.Add(owner, points)
		-- Coins are paid per CARRIED unit: grade multiplier x mutation multiplier (units of a mutated pile pay their tier)
		local carriedUnits = math.min(carried, (usedForBuild + repaired * EconomyConfig.RepairCoinMultiplier) / q)
		local mutFactor = if source == "Player" then S.ResourceService.GetCoinFactor(owner, resId) else (if mutTier then MutationConfig.CoinFactor(mutTier, mutBonus) else 1)
		local coins = carriedUnits * res.CoinsPerUnit * MutationConfig.GradeCoin(res.Grade) * mutFactor * weight
			* BuildService.CoinMultiplier(owner, a.def.Rarity)
		S.PlayerDataService.AddCoins(owner, coins)
		if S.TelemetryService then
			S.TelemetryService.Record("Deposit", owner, carrierUnits, source, coins, points, resId, accepted)
		end
		local d = S.PlayerDataService.Get(owner)
		if d then
			d.Stats.LifetimeResources += carrierUnits
			d.Stats.LifetimeContribution = (d.Stats.LifetimeContribution or 0) + points
			if source ~= "Worker" and repaired > 0 then
				d.Stats.LifetimeRepairs = (d.Stats.LifetimeRepairs or 0) + repaired
				S.AchievementService.Check(owner)
			end
		end
	end
	return carrierUnits
end

-- Completed, undamaged sections that events may target: { {Index, Center} }.
function BuildService.DamageableSections(): { { Index: number, Center: Vector3 } }
	local out = {}
	local a = active
	if not a or a.locked then
		return out
	end
	for _, st in a.stages do
		if st.complete and not st.damaged then
			table.insert(out, { Index = st.index, Center = stageCenter(st) })
		end
	end
	return out
end

-- Damage up to `count` completed, undamaged sections. Returns damaged stage indices.
function BuildService.DamageSections(count: number, costFraction: number, maxUnits: number): { number }
	local a = active
	local out = {}
	if not a or a.locked then
		return out
	end
	local candidates = {}
	for _, st in a.stages do
		if st.complete and not st.damaged then
			table.insert(candidates, st)
		end
	end
	local rng = Random.new()
	for _ = 1, count do
		if #candidates == 0 then
			break
		end
		local st = table.remove(candidates, rng:NextInteger(1, #candidates)) :: Stage
		BuildService.DamageStage(st.index, costFraction, maxUnits)
		table.insert(out, st.index)
	end
	return out
end

function BuildService.DamageStage(index: number, costFraction: number, maxUnits: number): boolean
	local a = active
	local st = a and a.stages[index]
	if not a or not st or not st.complete or st.damaged then
		return false
	end
	st.damaged = true
	local need = {}
	local stageCount = #a.stages
	for res, n in a.need do
		need[res] = math.max(3, math.min(math.ceil(maxUnits * a.scale), math.ceil(n / stageCount * costFraction)))
	end
	st.repair = { need = need, have = {} }
	-- visuals: darken, knock some pieces askew, add fire/smoke
	local saved = {}
	local rng = Random.new()
	local fxBudget = 3
	for i, pc in st.pieces do
		local part = pc.part
		if not part:GetAttribute("NoDamage") then
			saved[part] = { Color = part.Color, Material = part.Material, CFrame = part.CFrame }
			part.Color = part.Color:Lerp(Color3.fromRGB(30, 22, 18), 0.55)
			if part.Material ~= Enum.Material.Neon then
				part.Material = Enum.Material.Slate
			end
			if i % 3 == 0 then
				part.CFrame = part.CFrame
					* CFrame.new(0, -math.min(0.6, part.Size.Y * 0.2), 0)
					* CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), math.rad(rng:NextNumber(-6, 6)), math.rad(rng:NextNumber(-8, 8)))
			end
			if fxBudget > 0 and i % math.max(1, math.floor(#st.pieces / 3)) == 0 then
				fxBudget -= 1
				local fire = Instance.new("Fire")
				fire.Size = 6
				fire.Heat = 8
				fire.Parent = part
				table.insert(st.fx, fire)
				local smoke = Instance.new("Smoke")
				smoke.Opacity = 0.25
				smoke.Size = 4
				smoke.Parent = part
				table.insert(st.fx, smoke)
			end
		end
	end
	st.saved = saved
	if st.model:IsA("Model") then
		local hl = Instance.new("Highlight")
		hl.FillColor = Color3.fromRGB(255, 120, 40)
		hl.OutlineColor = Color3.fromRGB(255, 160, 60)
		hl.FillTransparency = 0.8
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Adornee = st.model
		hl.Parent = st.model
		table.insert(st.fx, hl)
	end
	local center = stageCenter(st)
	local anchor = Instance.new("Part")
	anchor.Name = "RepairMarker"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = center + Vector3.new(0, 6, 0)
	anchor:SetAttribute("RepairStage", st.index)
	anchor.Parent = a.model
	table.insert(st.fx, anchor)
	dirty = true
	Net.Event("Effect"):FireAllClients("Damaged", { Stage = st.index, Name = st.name, Position = center })
	return true
end

-- Debug/testing helper: fill requirements up to a fraction (0..1) of the target.
function BuildService.FillTo(fraction: number)
	local a = active
	if not a or a.locked then
		return
	end
	for res, n in a.need do
		a.have[res] = math.max(a.have[res] or 0, math.min(n, math.ceil(n * fraction)))
	end
	dirty = true
end

function BuildService.CompleteNextStage()
	local a = active
	if not a then
		return
	end
	BuildService.FillTo(math.min(1, (a.completedStages + 1) / #a.stages))
end

function BuildService.RepairAll()
	local a = active
	if not a then
		return
	end
	for _, st in a.stages do
		if st.damaged then
			finishRepair(a, st)
		end
	end
	dirty = true
end

-- Finishing touches after completion: reveal everything, effects, special mechanic.
function BuildService.FinishPresentation()
	local a = active
	if not a then
		return
	end
	for _, st in a.stages do
		while st.shown < #st.pieces do
			st.shown += 1
			revealPiece(st.pieces[st.shown])
		end
	end
	local effects = hidden:FindFirstChild("Effects")
	if effects then
		effects.Parent = a.model
	end
	applyCompletionAttributes(a.model)
	local mech = a.def.SpecialMechanic and Mechanics[a.def.SpecialMechanic]
	if mech and mech.OnComplete then
		mech.OnComplete(a.model)
	end
	publishRequirements(a)
	S.StateService.Set("Progress", 1)
end

function BuildService.ElapsedSeconds(): number
	local a = active
	return if a then now() - a.startedAt else 0
end

function BuildService.Clear()
	if active then
		active.model:Destroy()
		active = nil
	end
	hidden:ClearAllChildren()
	dirty = false
	S.StateService.ClearPrefixed({ "Need_", "Have_", "RepairNeed_", "RepairHave_" })
	S.StateService.Set("Progress", 0)
	S.StateService.Set("Stage", 0)
	S.StateService.Set("StageCount", 0)
	S.StateService.Set("DamagedSections", 0)
	S.StateService.Set("BuildActivated", false)
	S.StateService.Set("BuildMilestone", 0)
end

-- Active player count used for requirement scaling (data-loaded players).
function BuildService.ActivePlayerCount(): number
	local n = 0
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("DataLoaded") then
			n += 1
		end
	end
	return math.max(1, n)
end

return BuildService
