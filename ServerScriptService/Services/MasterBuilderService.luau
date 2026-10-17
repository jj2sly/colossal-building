--!strict
-- MASTER BUILDER advancement. The client shows a confirmation screen first; this service re-validates everything
-- (requirements, cooldown, not training), runs the pure data reset in MasterBuilderConfig.Advance, grants the rank's
-- rewards, restores permanent unlocks and tells the client what happened so it can play the prestige moment.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local MasterBuilderConfig = require(Shared.Config.MasterBuilderConfig)
local CosmeticConfig = require(Shared.Config.CosmeticConfig)
local MasterProjectConfig = require(Shared.Config.MasterProjectConfig)
local SecretResourceConfig = require(Shared.Config.SecretResourceConfig)

local MasterBuilderService = {}
local S: any

function MasterBuilderService.Init(registry)
	S = registry
end

-- Grants every title / cosmetic of ranks 1..rank (idempotent: Grant ignores things already owned).
local function grantRewards(player: Player, fromRank: number, toRank: number)
	for r = fromRank, toRank do
		local m = MasterBuilderConfig.Milestones[r]
		if m then
			if m.Title then
				S.CosmeticService.Grant(player, "Title", m.Title, "Master Builder")
			end
			for _, c in m.Cosmetics or {} do
				S.CosmeticService.Grant(player, c.Category, c.Item, "Master Builder")
			end
		end
	end
end

-- Re-applies rank-permanent unlocks and rewards (load time, debug rank changes).
function MasterBuilderService.Refresh(player: Player)
	local d = S.PlayerDataService.Get(player)
	if not d then
		return
	end
	local rank = d.MasterBuilder.Rank or 0
	MasterBuilderConfig.ApplyPermanents(d)
	grantRewards(player, 1, rank)
	player:SetAttribute("MasterRank", rank)
	S.PlayerDataService.MarkDirty(player)
	if S.StatsBoardService then
		S.StatsBoardService.Touch(player)
	end
end

local function describeRewards(rank: number): { string }
	local m = MasterBuilderConfig.Milestones[rank]
	local lines = {}
	if m then
		table.insert(lines, m.Text)
	end
	table.insert(lines, string.format("+%d%% carry, +%d%% gather, +%d Luck, +%d%% Worker (total)", math.floor(rank * MasterBuilderConfig.PerRankBonus.CarryEffectiveness * 100 + 0.5), math.floor(rank * MasterBuilderConfig.PerRankBonus.GatherEffectiveness * 100 + 0.5), rank * MasterBuilderConfig.PerRankBonus.PersonalLuck, math.floor(rank * MasterBuilderConfig.PerRankBonus.WorkerEffectiveness * 100 + 0.5)))
	return lines
end

-- Performs the advance. Returns (ok, payload | reason). `force` (debug) skips the cooldown.
function MasterBuilderService.Advance(player: Player, force: boolean?): (boolean, any)
	if not MasterBuilderConfig.Enabled then
		return false, "Master Builder is not available yet"
	end
	local d = S.PlayerDataService.Get(player)
	if not d then
		return false, "Data not loaded"
	end
	if player:GetAttribute("TrainKind") or player:GetAttribute("TrainCarry") then
		return false, "Finish training first"
	end
	local before = d.MasterBuilder.Rank or 0
	local ok, why = MasterBuilderConfig.Advance(d, force)
	if not ok then
		return false, why == "cooldown" and "Master Builder cooldown is still running" or (why == "max rank" and "You are already at the highest rank" or "Requirements not met")
	end
	local after = d.MasterBuilder.Rank
	-- the old vehicle / Worker no longer exist
	player:SetAttribute("Vehicle", nil)
	S.VehicleService.Equip(player, nil)
	S.WorkerService.Despawn(player)
	if d.Worker.Unlocked then
		task.spawn(S.WorkerService.Spawn, player) -- a permanent Worker comes straight back
	end
	grantRewards(player, before + 1, after)
	player:SetAttribute("MasterRank", after)
	S.TrainingService.PublishLevels(player) -- Strength / Speed were halved: republish the levels, speed and carry
	S.UpgradeService.RefreshMovement(player)
	S.ResourceService.RefreshCapacity(player)
	S.PlayerDataService.MarkDirty(player)
	S.PlayerDataService.Sync(player)
	if S.StatsBoardService then
		S.StatsBoardService.Touch(player)
	end
	Net.Event("Notify"):FireAllClients("Success", string.format("%s reached %s!", player.DisplayName, MasterBuilderConfig.Ranks[after].Title), 5)
	return true, {
		Rank = after,
		Title = MasterBuilderConfig.Ranks[after].Title,
		Rewards = describeRewards(after),
	}
end

------------------------------------------------------------------ Master Project + secret hooks (foundation)
-- The live conditions MasterProjectConfig.Eligible checks. No project is enabled yet, so nothing triggers; when a project is
-- enabled (MasterProjectConfig.Projects[i].Enabled + Build) GameLoopService only has to call EligibleMasterProject() when it
-- picks the next build and use the returned project instead of rolling a normal one: it starts AUTOMATICALLY, no vote, and every
-- player can contribute whether or not they are a Master Builder.
function MasterBuilderService.MasterProjectContext(): any
	local combined, masters = 0, 0
	local secrets: { [string]: boolean } = {}
	for _, p in Players:GetPlayers() do
		local d = S.PlayerDataService.Get(p)
		if d then
			local r = d.MasterBuilder.Rank or 0
			combined += r
			if r >= 1 then
				masters += 1
			end
			for id in SecretResourceConfig.Secrets do
				if SecretResourceConfig.CanAccess(id, d) then
					secrets[id] = true
				end
			end
		end
	end
	local built = S.StateService.Get("BuildsCompleted") or 0
	return {
		ServerLuck = S.ServerLuckService.Get(),
		BuildCount = built,
		CombinedRank = combined,
		MasterPlayers = masters,
		Secrets = secrets,
		EventId = S.StateService.Get("EventId"),
		BuildsSinceProject = built - (S.StateService.Get("MasterProjectAt") or 0),
	}
end

function MasterBuilderService.EligibleMasterProject(): any
	return MasterProjectConfig.Eligible(MasterBuilderService.MasterProjectContext())
end

function MasterBuilderService.Start()
	local limiter = Net.RateLimiter(0.5, 2)
	Net.Function("MasterBuilderAdvance").OnServerInvoke = function(player)
		if not limiter(player) then
			return false, "Slow down"
		end
		return MasterBuilderService.Advance(player)
	end
	S.PlayerDataService.Loaded:Connect(function(player)
		MasterBuilderService.Refresh(player)
	end)
	for _, p in Players:GetPlayers() do
		if S.PlayerDataService.IsLoaded(p) then
			MasterBuilderService.Refresh(p)
		end
	end
end

local _ = CosmeticConfig
return MasterBuilderService
