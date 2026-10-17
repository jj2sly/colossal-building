--!strict
-- Global game tuning + development switches.
--
-- DEV vs PRODUCTION: everything under `Dev` only applies when running inside Roblox
-- Studio AND `Dev.Enabled` is true. Live servers always use production balance, so
-- solo-test shortcuts can never leak into the real game.
local RunService = game:GetService("RunService")
local ColossalConfig = require(script.Parent.ColossalConfig)

local GameConfig = {}

GameConfig.Dev = {
	Enabled = true, -- master switch for every dev shortcut below
	-- Extra multiplier on build requirements while testing solo in Studio.
	-- Production uses PlayerScaling only. 0.35 makes a solo Common take ~2 minutes.
	RequirementMultiplier = 0.35,
	FastPresentation = false, -- shortens reveal/celebration/intermission timings
	EventIntervalMultiplier = 0.4, -- events happen more often while testing
	-- UserIds allowed to use debug tools in live servers (keep empty for production).
	AdminUserIds = {} :: { number },
	FriendCountOverride = nil :: number?, -- force a friend count for every player when testing
}

function GameConfig.IsDev(): boolean
	return GameConfig.Dev.Enabled and RunService:IsStudio()
end

-- Requirement scaling by live player count. Build requirements in BuildConfig are
-- authored for ReferencePlayers active players; servers with fewer players get
-- proportionally smaller builds (never below MinScale), locked when a build starts.
GameConfig.PlayerScaling = {
	ReferencePlayers = 40,
	MinScale = 1 / 40,
	MaxScale = 1.25,
}

-- Round flow timings (seconds). FastPresentation divides these in dev.
GameConfig.Timings = {
	Intermission = 4,
	RevealRoll = 5, -- rarity roll animation (Pass 21L: longer, with a tension beat before the result)
	RevealHold = 4.5, -- build info card
	VoteDuration = 18,
	CompletionAnimation = 2.5,
	CelebrationView = 12, -- time to admire the finished build
	ResetFade = 2,
	LeaderboardBroadcastInterval = 1.5,
}

-- Build site. The geometry (deck, collar, barrier, deposit edge) comes from ColossalConfig.Site so the site can grow
-- from one place; WorldBuilder / WorldBuilderColossal author the matching world.
GameConfig.Site = {
	Center = ColossalConfig.Site.Center,
	PlatformTopY = ColossalConfig.Site.DeckTopY, -- build models are placed with their base on this height
	BuildScale = 1.2, -- every giant build is scaled up by this much (readable from the spawn); Giant modifier multiplies on top
	FacingYaw = 180, -- templates are authored facing -Z; turn them so their front faces the spawn (south of the site)
	DepositInnerRadius = ColossalConfig.Site.BarrierRadius,
	DepositOuterRadius = ColossalConfig.Site.DepositRadius,
	DepositTickInterval = 0.2,
}

GameConfig.Gather = {
	MaxPromptDistance = 12,
	TimingTolerance = 0.75, -- server accepts gathers this fraction faster than nominal (latency)
}

-- Milestone vote: every N completed builds the next build is chosen by vote.
GameConfig.VoteEveryNBuilds = 5
GameConfig.VoteOptionCount = 3

GameConfig.Contribution = {
	WorkerWeight = 0.5, -- worker deliveries count at half weight
	RepairWeight = 1.5, -- repairs are worth more per unit
}

function GameConfig.Timing(name: string): number
	local t = (GameConfig.Timings :: any)[name] :: number
	if GameConfig.IsDev() and GameConfig.Dev.FastPresentation then
		return t * 0.35
	end
	return t
end

return GameConfig
