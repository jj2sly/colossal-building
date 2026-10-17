--!strict
-- RESOURCE MUTATIONS (server-authoritative). Every 45-75 s (random, MutationConfig.Roll) the server may turn a PILE of some
-- resource grade Golden / Diamond / Prismatic. A pile is 1-3 of that resource's world nodes that share one finite RESERVE;
-- each player gathers a personal ALLOWANCE at full yield, then a reduced yield while the reserve lasts. The pile ends when
-- the reserve is empty or its lifetime runs out.
--
-- Replication (cheap by design): nodes get attributes Mutation / MutationPile; one Folder per pile in Workspace.MB_Mutations
-- carries Tier / ResId / Spot / Reserve (updated at most once a second) plus ObjectValues pointing at its nodes. Clients draw
-- every visual (aura, sparkle, light, beam, announcement) from that folder, so the server runs no per-frame work: one timer for
-- rolls and one 1 s tick that only runs while a pile exists.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local MutationConfig = require(Shared.Config.MutationConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local ResourceSpotConfig = require(Shared.Config.ResourceSpotConfig)

local MutationService = {}
local S: any

type Pile = {
	id: string,
	tier: string,
	resId: string,
	spotId: string,
	nodes: { BasePart },
	reserve: number,
	reserveMax: number,
	endsAt: number,
	gathered: { [Player]: number },
	obj: Folder,
	dirty: boolean,
}

local piles: { [string]: Pile } = {}
local pileCount = 0
local nextId = 0
local rng = Random.new()
local folder: Folder
local ticking = false

function MutationService.Init(registry)
	S = registry
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function nodesOf(resId: string): { BasePart }
	local out = {}
	for _, n in CollectionService:GetTagged("ResourceNode") do
		if n:IsA("BasePart") and n:GetAttribute("ResourceId") == resId and n:GetAttribute("MutationPile") == nil and (n:GetAttribute("SecretId") == nil) then
			table.insert(out, n)
		end
	end
	return out
end

local function endPile(p: Pile, why: string)
	if not piles[p.id] then
		return
	end
	piles[p.id] = nil
	pileCount -= 1
	for _, n in p.nodes do
		if n.Parent then
			n:SetAttribute("Mutation", nil)
			n:SetAttribute("MutationPile", nil)
		end
	end
	p.obj:SetAttribute("Ending", why)
	task.delay(0.2, function()
		p.obj:Destroy()
	end)
end

-- Reserve size for a tier at the current player count.
local function reserveFor(tier: string): number
	local r = MutationConfig.Reserve[tier]
	return math.floor(r.Base + r.PerPlayer * math.max(1, #Players:GetPlayers()))
end

-- Creates a pile. Returns the pile or nil (no nodes / too many piles). Used by the roll timer and the debug bridge.
function MutationService.Spawn(resId: string, tier: string): Pile?
	local res = ResourceConfig.Resources[resId]
	if not res or not MutationConfig.Tiers[tier] or tier == "Normal" then
		return nil
	end
	local candidates = nodesOf(resId)
	if #candidates == 0 then
		return nil
	end
	local want = rng:NextInteger(MutationConfig.Roll.NodesPerPile[1], MutationConfig.Roll.NodesPerPile[2])
	local nodes = {}
	-- the nodes of one pile sit together: start from a random node and take its nearest neighbours
	local first = table.remove(candidates, rng:NextInteger(1, #candidates)) :: BasePart
	table.insert(nodes, first)
	table.sort(candidates, function(a, b)
		return (a.Position - first.Position).Magnitude < (b.Position - first.Position).Magnitude
	end)
	for i = 1, math.min(want - 1, #candidates) do
		table.insert(nodes, candidates[i])
	end
	nextId += 1
	local id = "P" .. nextId
	local spot = ResourceSpotConfig.Get(first:GetAttribute("SpotId"))
	local obj = Instance.new("Folder")
	obj.Name = id
	local reserve = reserveFor(tier)
	obj:SetAttribute("Tier", tier)
	obj:SetAttribute("ResId", resId)
	obj:SetAttribute("Spot", spot and spot.DisplayName or res.DisplayName)
	obj:SetAttribute("Family", res.FamilyName)
	obj:SetAttribute("ItemName", res.DisplayName)
	obj:SetAttribute("Reserve", reserve)
	obj:SetAttribute("ReserveMax", reserve)
	obj:SetAttribute("StartedAt", now())
	local endsAt = now() + MutationConfig.Roll.Lifetime
	obj:SetAttribute("EndsAt", endsAt)
	for i, n in nodes do
		local ov = Instance.new("ObjectValue")
		ov.Name = "Node" .. i
		ov.Value = n
		ov.Parent = obj
		n:SetAttribute("Mutation", tier)
		n:SetAttribute("MutationPile", id)
	end
	local p: Pile = { id = id, tier = tier, resId = resId, spotId = (spot and spot.Id) or "", nodes = nodes, reserve = reserve, reserveMax = reserve, endsAt = endsAt, gathered = {}, obj = obj, dirty = false }
	piles[id] = p
	pileCount += 1
	obj.Parent = folder
	-- announcement (client draws banner + beacon): short text only
	local center = Vector3.zero
	for _, n in nodes do
		center += n.Position
	end
	Net.Event("Effect"):FireAllClients("MutationSpawn", { Id = id, Tier = tier, Family = string.upper(res.FamilyName), Place = spot and spot.DisplayName or res.DisplayName, Pos = center / #nodes })
	if S.TelemetryService then
		S.TelemetryService.Record("Mutation", nil, tier, resId)
	end
	if not ticking then
		ticking = true
		task.spawn(function()
			while pileCount > 0 do
				task.wait(1)
				local t = now()
				for _, pile in piles do
					if t >= pile.endsAt or pile.reserve <= 0 then
						endPile(pile, if pile.reserve <= 0 then "Depleted" else "Expired")
					elseif pile.dirty then
						pile.dirty = false
						pile.obj:SetAttribute("Reserve", pile.reserve)
					end
				end
			end
			ticking = false
		end)
	end
	return p
end

-- One roll: does a mutation happen, and which? Server Luck raises the chance and the tier quality.
local function roll()
	if not MutationConfig.Enabled or pileCount >= MutationConfig.Roll.MaxActive then
		return
	end
	if S.StateService.Get("Phase") ~= "Building" then
		return
	end
	local luck = S.ServerLuckService.Get()
	if rng:NextNumber() > MutationConfig.ChanceAt(luck) then
		return
	end
	-- tier
	local odds = MutationConfig.TierOdds(luck)
	local x, tier = rng:NextNumber(), "Golden"
	for _, e in odds do
		x -= e.p
		if x <= 0 then
			tier = e.id
			break
		end
	end
	-- grade, then a family at random
	local gw = MutationConfig.Roll.GradeWeights
	local total = 0
	for _, w in gw do
		total += w
	end
	local g, y = 1, rng:NextNumber() * total
	for grade = 1, 3 do
		y -= gw[grade]
		if y <= 0 then
			g = grade
			break
		end
	end
	local choices = {}
	for _, id in ResourceConfig.Order do
		local r = ResourceConfig.Resources[id]
		if r.Grade == g then
			table.insert(choices, id)
		end
	end
	MutationService.Spawn(choices[rng:NextInteger(1, #choices)], tier)
end

------------------------------------------------------------------ gathering
-- Player gather from a mutated node. `free` = free carry capacity. Returns (tier, units): the mutation tier of the units and
-- how many to give (already reduced past the personal allowance and clamped to the reserve and `free`). (nil, amount) when the
-- node is not part of a live pile.
function MutationService.Claim(player: Player, node: BasePart, amount: number, free: number): (string?, number)
	local id = node:GetAttribute("MutationPile")
	local p = id and piles[id :: string]
	if not p or p.reserve <= 0 then
		return nil, amount
	end
	local allowance = MutationConfig.PersonalAllowance[p.tier]
	local got = p.gathered[player] or 0
	local units = amount
	if got >= allowance then
		units = math.max(1, math.floor(amount * MutationConfig.ReducedYield + 0.5))
	elseif got + amount > allowance then
		-- the gather that crosses the allowance is split: the part inside it at full yield, the rest reduced
		local inside = allowance - got
		units = inside + math.floor((amount - inside) * MutationConfig.ReducedYield + 0.5)
	end
	units = math.min(units, math.floor(p.reserve), math.floor(free))
	if units <= 0 then
		return p.tier, 0
	end
	p.reserve -= units
	p.gathered[player] = got + units
	p.dirty = true
	return p.tier, units
end

-- Give back reserve that was claimed but could not be carried.
function MutationService.Refund(node: BasePart, units: number)
	local id = node:GetAttribute("MutationPile")
	local p = id and piles[id :: string]
	if p and units > 0 then
		p.reserve += units
		p.dirty = true
	end
end

-- Remaining reserve percentage for a node's pile (0..1) or nil.
function MutationService.ReserveOf(node: BasePart): number?
	local id = node:GetAttribute("MutationPile")
	local p = id and piles[id :: string]
	return p and p.reserve / p.reserveMax or nil
end

------------------------------------------------------------------ workers
-- The best live pile a Worker able to haul `maxGrade` may redirect to (Prismatic > Diamond > Golden), or nil.
function MutationService.BestPile(maxGrade: number): Pile?
	local best, bestScore = nil, 0
	for _, p in piles do
		local r = ResourceConfig.Resources[p.resId]
		if p.reserve > 0 and r and r.Grade <= maxGrade then
			local score = MutationConfig.WorkerPriority[p.tier] or 0
			if score > bestScore then
				best, bestScore = p, score
			end
		end
	end
	return best
end

function MutationService.GetPile(id: string?): Pile?
	return id and piles[id] or nil
end

-- A Worker's load from a pile. Takes from the shared reserve (no personal allowance: Workers never starve players, they just
-- share the reserve). Returns (tier, units).
function MutationService.ClaimForWorker(id: string, amount: number): (string?, number)
	local p = piles[id]
	if not p or p.reserve <= 0 then
		return nil, amount
	end
	local units = math.min(amount, math.floor(p.reserve))
	p.reserve -= units
	p.dirty = true
	return p.tier, units
end

-- Debug / test: end every live pile.
function MutationService.Clear()
	for _, p in piles do
		endPile(p, "Cleared")
	end
end

function MutationService.Active(): { Pile }
	local out = {}
	for _, p in piles do
		table.insert(out, p)
	end
	return out
end

function MutationService.Start()
	local old = workspace:FindFirstChild("MB_Mutations")
	if old then
		old:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "MB_Mutations"
	folder.Parent = workspace
	task.spawn(function()
		while true do
			local r = MutationConfig.Roll
			task.wait(rng:NextNumber(r.MinInterval, r.MaxInterval))
			roll()
		end
	end)
	Players.PlayerRemoving:Connect(function(pl)
		for _, p in piles do
			p.gathered[pl] = nil
		end
	end)
end

-- Debug: roll immediately (ignores the phase and active-pile limits only for `force`).
function MutationService.RollNow()
	roll()
end

return MutationService
