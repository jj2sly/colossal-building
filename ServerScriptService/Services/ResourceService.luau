--!strict
-- Gathering + carried inventory (server-authoritative).
--
-- Every node in the world tagged "ResourceNode" (attribute ResourceId) gets a
-- ProximityPrompt. One code path handles every resource type. The client only says
-- "I triggered this prompt"; the server checks distance, gather timing (Gather Speed
-- upgrade + events), capacity, then decides the amount. The client can shorten its
-- local prompt hold time for responsiveness, but the server still enforces the rate.
--
-- Carried amounts replicate as player attributes (Carry_<Res>, CarryTotal, CarryCap)
-- which clients use to draw the carried stack locally (no replicated stack parts).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local GameConfig = require(Shared.Config.GameConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local Formulas = require(Shared.Formulas)
local MasterBuilderConfig = require(Shared.Config.MasterBuilderConfig)
local MutationConfig = require(Shared.Config.MutationConfig)
local SecretResourceConfig = require(Shared.Config.SecretResourceConfig)
local ResourceSpotConfig = require(Shared.Config.ResourceSpotConfig)

local ResourceService = {}
local S: any

local carry: { [Player]: { [string]: number } } = {}
local lastGather: { [Player]: number } = {}
local lastFullNotice: { [Player]: number } = {}
local quality: { [Player]: { [string]: number } } = {} -- average richness of each carried stack
-- mutated units inside each carried stack: mut[player][resId] = { Golden = n, Diamond = n, Prismatic = n } (a subset of carry)
local mut: { [Player]: { [string]: { [string]: number } } } = {}

local function total(inv: { [string]: number }): number
	local t = 0
	for _, n in inv do
		t += n
	end
	return t
end

local function publish(player: Player)
	local inv = carry[player]
	if not inv then
		return
	end
	for id in ResourceConfig.Resources do
		local n = inv[id] or 0
		player:SetAttribute("Carry_" .. id, if n > 0 then n else nil)
	end
	player:SetAttribute("CarryTotal", total(inv))
	-- compact "Res=g,d,p;Res=g,d,p" so every client can draw mutated blocks in the carried stack
	local parts = {}
	local m = mut[player]
	if m then
		for _, id in ResourceConfig.Order do
			local c = m[id]
			if c and (c.Golden or 0) + (c.Diamond or 0) + (c.Prismatic or 0) > 0 then
				table.insert(parts, string.format("%s=%d,%d,%d", id, c.Golden or 0, c.Diamond or 0, c.Prismatic or 0))
			end
		end
	end
	local str = table.concat(parts, ";")
	player:SetAttribute("CarryMut", if str ~= "" then str else nil)
end

function ResourceService.Init(registry)
	S = registry
end

function ResourceService.GetCapacity(player: Player): number
	local d = S.PlayerDataService.Get(player)
	if not d then
		return 0
	end
	local eventMult = S.EventService and S.EventService.CarryMultiplier() or 1
	local base = Formulas.BaseCarry(d.Training.Strength or 0) * (1 + MasterBuilderConfig.Bonus(S.UpgradeService.MasterRank(player), "CarryEffectiveness")) * (1 + S.BoostService.CargoBonus(player))
	return Formulas.CarryCapacity(base, player:GetAttribute("Driving"), d.Upgrades.VehicleCapacity or 0, eventMult)
end

function ResourceService.RefreshCapacity(player: Player)
	player:SetAttribute("CarryCap", ResourceService.GetCapacity(player))
end

function ResourceService.RefreshAllCapacities()
	for _, p in Players:GetPlayers() do
		ResourceService.RefreshCapacity(p)
	end
end

function ResourceService.GetCarry(player: Player): { [string]: number }
	return carry[player] or {}
end

function ResourceService.GetTotal(player: Player): number
	return total(carry[player] or {})
end

-- Adds up to `amount`, clamped to free capacity. Returns the amount actually added.
-- Average richness (>= 1) of what the player carries of a resource; Workers/debug gives are 1.
function ResourceService.GetQuality(player: Player, resId: string): number
	local q = quality[player]
	local r = ResourceConfig.Resources[resId]
	return q and q[resId] or (if r then r.Equivalent else 1)
end

function ResourceService.Give(player: Player, resId: string, amount: number, richness: number?, mutation: string?): number
	local inv = carry[player]
	if not inv or not ResourceConfig.Resources[resId] then
		return 0
	end
	local free = math.max(0, ResourceService.GetCapacity(player) - total(inv))
	local add = math.min(free, math.floor(amount))
	if add > 0 then
		local before = inv[resId] or 0
		local q = quality[player]
		if not q then
			q = {}
			quality[player] = q
		end
		local eq = (ResourceConfig.Resources[resId] :: any).Equivalent
		q[resId] = (before * (q[resId] or eq) + add * (richness or eq)) / (before + add)
		inv[resId] = before + add
		if mutation and mutation ~= "Normal" and MutationConfig.Tiers[mutation] then
			mut[player] = mut[player] or {}
			local m = mut[player][resId] or {}
			mut[player][resId] = m
			m[mutation] = (m[mutation] or 0) + add
		end
		publish(player)
	end
	return add
end

-- Number of mutated units of a resource currently carried, per tier.
function ResourceService.GetMutations(player: Player, resId: string): { [string]: number }
	return (mut[player] and mut[player][resId]) or {}
end

local function mutatedCount(player: Player, resId: string): number
	local m = mut[player] and mut[player][resId]
	if not m then
		return 0
	end
	local n = 0
	for _, v in m do
		n += v
	end
	return n
end

ResourceService.MutatedCount = mutatedCount

-- Average Coin factor per carried unit of a resource: normal units x1, mutated units x their (bonus-adjusted) Coin multiplier.
function ResourceService.GetCoinFactor(player: Player, resId: string): number
	local have = (carry[player] and carry[player][resId]) or 0
	local m = mut[player] and mut[player][resId]
	if have <= 0 or not m then
		return 1
	end
	local bonus = S.BuildIndexService.Bonus(player, "MutationValue")
	local sum, mutated = 0, 0
	for tier, n in m do
		sum += n * MutationConfig.CoinFactor(tier, bonus)
		mutated += n
	end
	return (sum + math.max(0, have - mutated)) / have
end

-- Removes up to `amount`; returns removed amount.
function ResourceService.Take(player: Player, resId: string, amount: number): number
	local inv = carry[player]
	if not inv then
		return 0
	end
	local have = inv[resId] or 0
	local take = math.min(have, math.floor(amount))
	if take > 0 then
		local m = mut[player] and mut[player][resId]
		if m then
			-- remove mutated units in proportion so the stack's averages stay consistent
			local left = take
			for tier, n in m do
				local r = math.min(n, math.floor(n * take / have + 0.5), left)
				m[tier] = n - r
				left -= r
			end
			if have - take <= 0 then
				mut[player][resId] = nil
			end
		end
		inv[resId] = have - take
		if inv[resId] <= 0 then
			inv[resId] = nil
			if quality[player] then
				quality[player][resId] = nil
			end
		end
		publish(player)
	end
	return take
end

-- Removes ONLY the mutated units of a resource (used when the active build does not need it: they still pay their Coins).
-- Returns (units, coinFactorOfThoseUnits, tiers) or nil.
function ResourceService.TakeMutated(player: Player, resId: string): (number, number)
	local m = mut[player] and mut[player][resId]
	local inv = carry[player]
	local have = inv and inv[resId] or 0
	local n = mutatedCount(player, resId)
	if not m or n <= 0 or have <= 0 then
		return 0, 1
	end
	local bonus = S.BuildIndexService.Bonus(player, "MutationValue")
	local factorSum, buildSum = 0, 0
	local eq = (ResourceConfig.Resources[resId] :: any).Equivalent
	for tier, cnt in m do
		factorSum += cnt * MutationConfig.CoinFactor(tier, bonus)
		buildSum += cnt * eq * MutationConfig.BuildFactor(tier, bonus)
	end
	-- the rest of the stack keeps its own average richness
	local q = quality[player]
	if q and q[resId] then
		local rest = have - n
		q[resId] = if rest > 0 then math.max(eq, (q[resId] * have - buildSum) / rest) else nil
	end
	mut[player][resId] = nil
	inv[resId] = have - n
	if inv[resId] <= 0 then
		inv[resId] = nil
	end
	publish(player)
	return n, factorSum / n
end

function ResourceService.Clear(player: Player)
	if carry[player] then
		carry[player] = {}
		quality[player] = nil
		mut[player] = nil
		publish(player)
	end
end

local function onGather(player: Player, node: BasePart, resId: string)
	local res = ResourceConfig.Resources[resId]
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not res or not hrp or not hum or hum.Health <= 0 or not carry[player] then
		return
	end
	-- distance check (node size allowance for big rocks/trees)
	local reach = GameConfig.Gather.MaxPromptDistance + node.Size.Magnitude / 2
	if (hrp.Position - node.Position).Magnitude > reach then
		return
	end
	-- personal secret resources: only players who unlocked them can gather, whoever is standing nearby
	local secret = node:GetAttribute("SecretId")
	if secret and not SecretResourceConfig.CanAccess(secret :: string, S.PlayerDataService.Get(player)) then
		local sdef = SecretResourceConfig.Secrets[secret :: string]
		Net.Event("Notify"):FireClient(player, "Warn", if sdef and sdef.MinMasterRank then string.format("Unknown material. Reach Master Builder rank %d to unlock it.", sdef.MinMasterRank) else "Unknown material.", 3)
		return
	end
	-- timing check: nominal time at this player's gather speed
	local spot = ResourceSpotConfig.Get(node:GetAttribute("SpotId"))
	local spotRichness = spot and spot.YieldMultiplier or 1
	local spotSpeed = spot and spot.GatherSpeedMultiplier or 1
	local speed = S.UpgradeService.Value(player, "GatherSpeed") * S.EventService.GatherSpeedMultiplier(resId) * spotSpeed
	local minInterval = res.GatherTime / speed * GameConfig.Gather.TimingTolerance
	local now = os.clock()
	if lastGather[player] and now - lastGather[player] < minInterval then
		return
	end
	lastGather[player] = now

	local cap = ResourceService.GetCapacity(player)
	if total(carry[player]) >= cap then
		if not lastFullNotice[player] or now - lastFullNotice[player] > 2 then
			lastFullNotice[player] = now
			Net.Event("Effect"):FireClient(player, "Full", {})
		end
		return
	end
	local amount = math.floor(res.YieldPerGather * S.EventService.GatherYieldMultiplier(resId) + 0.5)
	-- a mutated pile: shared reserve + personal full-yield allowance, units keep their mutation tier
	local mutTier: string? = nil
	if S.MutationService and node:GetAttribute("MutationPile") then
		local free = math.max(0, cap - total(carry[player]))
		mutTier, amount = S.MutationService.Claim(player, node, amount, free)
		if amount <= 0 then
			return
		end
	end
	local richness = spotRichness * (if mutTier then MutationConfig.BuildFactor(mutTier, S.BuildIndexService.Bonus(player, "MutationValue")) else 1)
	local added = ResourceService.Give(player, resId, amount, richness, mutTier)
	if S.TelemetryService then
		S.TelemetryService.Record("Gather", player, added, spot and spot.Id or resId)
	end
	if added > 0 then
		Net.Event("Effect"):FireClient(player, "Gathered", { Res = resId, Amount = added, Node = node, Mut = mutTier })
		if total(carry[player]) >= cap then
			Net.Event("Effect"):FireClient(player, "Full", {})
		end
	end
end

-- Exposed for automated playtests (DebugService bridge); same validation path.
ResourceService.HandleGather = function(player: Player, node: BasePart)
	onGather(player, node, node:GetAttribute("ResourceId"))
end

local function setupNode(node: Instance)
	if not node:IsA("BasePart") then
		return
	end
	local resId = node:GetAttribute("ResourceId")
	local res = resId and ResourceConfig.Resources[resId]
	if not res then
		warn("[Resource] node without valid ResourceId:", node:GetFullName())
		return
	end
	local prompt = node:FindFirstChild("GatherPrompt") :: ProximityPrompt?
	if not prompt then
		local p = Instance.new("ProximityPrompt")
		p.Name = "GatherPrompt"
		p.Parent = node
		prompt = p
	end
	local pr = prompt :: ProximityPrompt
	pr.ActionText = "Gather"
	pr.ObjectText = res.DisplayName
	local nodeSpot = ResourceSpotConfig.Get(node:GetAttribute("SpotId"))
	pr.HoldDuration = res.GatherTime / (nodeSpot and nodeSpot.GatherSpeedMultiplier or 1)
	pr.MaxActivationDistance = GameConfig.Gather.MaxPromptDistance
	pr.RequiresLineOfSight = false
	pr.KeyboardKeyCode = Enum.KeyCode.E
	pr.Style = Enum.ProximityPromptStyle.Default
	pr:SetAttribute("ResourceId", resId)
	pr.Triggered:Connect(function(player)
		onGather(player, node :: BasePart, resId)
	end)
end

function ResourceService.Start()
	for _, node in CollectionService:GetTagged("ResourceNode") do
		setupNode(node)
	end
	CollectionService:GetInstanceAddedSignal("ResourceNode"):Connect(setupNode)

	local function onAdded(player: Player)
		carry[player] = {}
		publish(player)
	end
	Players.PlayerAdded:Connect(onAdded)
	for _, p in Players:GetPlayers() do
		onAdded(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		carry[p] = nil
		lastGather[p] = nil
		lastFullNotice[p] = nil
		quality[p] = nil
		mut[p] = nil
	end)
	S.PlayerDataService.Loaded:Connect(function(player)
		ResourceService.RefreshCapacity(player)
	end)

	local dropLimiter = Net.RateLimiter(1, 2)
	Net.Event("DropCarry").OnServerEvent:Connect(function(player, resId)
		if not dropLimiter(player) then
			return
		end
		if resId == nil then
			ResourceService.Clear(player)
		elseif type(resId) == "string" and ResourceConfig.Resources[resId] then
			ResourceService.Take(player, resId, math.huge)
		end
	end)
end

return ResourceService
