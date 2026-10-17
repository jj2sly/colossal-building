--!strict
-- MASTER PROJECTS (foundation only, no roster yet). A Master Project is an endgame mega-build that STARTS AUTOMATICALLY
-- the moment the server meets every condition of one of its entries: there is no vote, players who are not Master Builders
-- can contribute like everyone else, and the Project replaces the next normal build selection (GameLoopService asks
-- MasterProjectConfig.Eligible at selection time).
--
-- Conditions (all optional; every present one must hold):
--   MinServerLuck     live Server Luck
--   MinBuildCount     builds completed on this server since it started
--   MinCombinedRank   sum of the Master Builder ranks of the players present
--   MinMasterPlayers  how many present players are Master Builders (rank >= 1)
--   Secret            a SecretResourceConfig id that at least one present player has unlocked (they supply it)
--   EventId           an EventConfig event that must be running
--   Cooldown          builds that must pass after the last Master Project
-- Fill in `Build` (a BuildConfig id) when the build exists and set Enabled = true. Nothing here is on by default.
local MasterProjectConfig = {}

export type Project = {
	Id: string,
	DisplayName: string,
	Build: string?, -- BuildConfig id (nil until the build exists)
	Enabled: boolean,
	MinServerLuck: number?,
	MinBuildCount: number?,
	MinCombinedRank: number?,
	MinMasterPlayers: number?,
	Secret: string?,
	EventId: string?,
	Cooldown: number?,
}

-- PRODUCTION CONDITIONS for the first project: a warmed-up server (Server Luck 60 is about 15 completed builds), at least 12 builds
-- finished on this server, a combined Master Builder rank of 2 among the players present (at least one of them rank >= 1, so Star
-- Metal can be gathered) and 15 builds since the last Master Project. Rare, never accidental.
MasterProjectConfig.Projects = {
	{ Id = "OrbitalStation", DisplayName = "Orbital Station", Build = "OrbitalStation", Enabled = true, MinServerLuck = 60, MinBuildCount = 12, MinCombinedRank = 2, MinMasterPlayers = 1, Secret = "StarMetal", Cooldown = 15 },
} :: { Project }

-- Rewards for finishing a Master Project (GameLoopService / DropService read these).
MasterProjectConfig.ServerLuckBonus = 18 -- on top of the normal per-build gain: meaningful, never an instant cap
MasterProjectConfig.DropRankBonus = 0.1 -- +10% prestige-cosmetic chance per Master Builder rank

-- DEV OVERRIDE: the debug bridge ("ForceMasterProject") sets this so the next selection starts that project regardless of the
-- conditions. Server runtime state only; GameLoopService clears it once used. Never set in production.
MasterProjectConfig.ForceNext = nil :: string?

-- `ctx` = { ServerLuck, BuildCount, CombinedRank, MasterPlayers, Secrets = { [id] = true }, EventId, BuildsSinceProject }
-- Returns the first enabled project whose conditions all hold, or nil.
function MasterProjectConfig.Eligible(ctx: any): Project?
	if MasterProjectConfig.ForceNext then
		for _, p in MasterProjectConfig.Projects do
			if p.Id == MasterProjectConfig.ForceNext and p.Build then
				return p
			end
		end
	end
	for _, p in MasterProjectConfig.Projects do
		if p.Enabled and p.Build then
			local ok = true
			ok = ok and (p.MinServerLuck == nil or ctx.ServerLuck >= p.MinServerLuck)
			ok = ok and (p.MinBuildCount == nil or ctx.BuildCount >= p.MinBuildCount)
			ok = ok and (p.MinCombinedRank == nil or ctx.CombinedRank >= p.MinCombinedRank)
			ok = ok and (p.MinMasterPlayers == nil or ctx.MasterPlayers >= p.MinMasterPlayers)
			ok = ok and (p.Secret == nil or (ctx.Secrets and ctx.Secrets[p.Secret] == true))
			ok = ok and (p.EventId == nil or ctx.EventId == p.EventId)
			ok = ok and (p.Cooldown == nil or (ctx.BuildsSinceProject or 1e9) >= p.Cooldown)
			if ok then
				return p
			end
		end
	end
	return nil
end

return MasterProjectConfig
