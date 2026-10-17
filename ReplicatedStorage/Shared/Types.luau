--!strict
-- Shared type definitions and the replicated GameState attribute contract.
--
-- ReplicatedStorage.GameState (Configuration) attributes, written ONLY by the server:
--   Phase            "Intermission" | "Selecting" | "Voting" | "Reveal" | "Building" | "Complete" | "Resetting"
--   PhaseEndsAt      workspace:GetServerTimeNow() timestamp (0 = open-ended)
--   BuildId, Rarity, Modifiers (comma list), BuildTitle
--   BuildStartedAt   server time the current build began
--   Progress         0..1 construction progress (requirements only)
--   Stage, StageCount
--   Need_<Res>, Have_<Res>          construction requirement per resource (absent = not required)
--   RepairNeed_<Res>, RepairHave_<Res>  outstanding repairs (0 when none)
--   DamagedSections  number of damaged sections
--   ServerLuck       0..100
--   BuildsCompleted, MilestoneCount, VoteEvery
--   EventId, EventEndsAt, EventParam, EventPhase ("Warning" | "Active" | "")
--
-- Player attributes (server-written, replicated to everyone):
--   Coins, Contribution, CarryTotal, CarryCap, Carry_<Res>, FriendsInServer,
--   Vehicle, DataLoaded, IsDebugUser
export type PlayerData = {
	Version: number,
	Coins: number,
	Upgrades: { [string]: number },
	Worker: { Unlocked: boolean, Type: string, Assignment: string, Enabled: boolean, Level: number },
	Vehicles: { Owned: { [string]: boolean }, Equipped: string? },
	BuildIndex: { [string]: IndexEntry },
	Stats: { BuildsCompleted: number, LifetimeResources: number, LifetimeContribution: number, CoinsEarned: number },
	MasterBuilder: { Rank: number, LastAdvancedAt: number },
	Unlocks: { [string]: boolean },
	Badges: { [string]: boolean },
	Titles: { [string]: boolean },
	Cosmetics: { [string]: boolean },
	Achievements: { [string]: boolean },
	Tutorial: { Done: boolean },
}

export type IndexEntry = {
	Discovered: boolean,
	TimesCompleted: number,
	BestContributionPct: number,
	FastestCompletion: number?,
	Modifiers: { [string]: boolean },
	HighestReward: number,
	FirstCompletedAt: number?,
}

export type LeaderEntry = { u: number, p: number } -- userId, points

return {}
