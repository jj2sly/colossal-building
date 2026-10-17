--!strict
-- COMPLETION SPECTACLES: short (5-15 s) client-side shows a finished build can play during the celebration,
-- before the next round. A build opts in with `CompletionSpectacle = "<id>"` in BuildConfig.
--
-- The server only says WHICH spectacle and WHEN (one Net "Spectacle" event); the handlers live in
-- StarterPlayerScripts/Controllers/SpectacleController and run entirely on each client (tweens, lights, particles),
-- so they cost the server nothing and never delay the round (the celebration view lasts 12 s anyway).
-- New spectacle = an entry here + a handler of the same id in SpectacleController.
local SpectacleConfig = {}

export type Spectacle = { Id: string, DisplayName: string, Duration: number }

SpectacleConfig.Spectacles = {
	RobotPowerUp = { Id = "RobotPowerUp", DisplayName = "Power Up", Duration = 9 },
	UfoHover = { Id = "UfoHover", DisplayName = "Hover", Duration = 9.5 },
	ArenaWave = { Id = "ArenaWave", DisplayName = "Arena Wave", Duration = 9 },
	VolcanoEruption = { Id = "VolcanoEruption", DisplayName = "Eruption", Duration = 10 },
	DragonRoar = { Id = "DragonRoar", DisplayName = "Dragon Roar", Duration = 9 },
	GalleonLift = { Id = "GalleonLift", DisplayName = "Lift Off", Duration = 9.5 },
	TitanChime = { Id = "TitanChime", DisplayName = "The Great Chime", Duration = 9 },
	ShipCannons = { Id = "ShipCannons", DisplayName = "Cannon Salute", Duration = 8 },
	OrbitalActivation = { Id = "OrbitalActivation", DisplayName = "Orbital Activation", Duration = 13.5 },
	ArcadeLightShow = { Id = "ArcadeLightShow", DisplayName = "Arcade Light Show", Duration = 8 },
	FortressBanners = { Id = "FortressBanners", DisplayName = "The Gates Open", Duration = 12 },
	DreadnoughtIgnition = { Id = "DreadnoughtIgnition", DisplayName = "Ignition", Duration = 11.5 },
	WorldTreeBloom = { Id = "WorldTreeBloom", DisplayName = "The Bloom", Duration = 12 },
	SkyCityAscension = { Id = "SkyCityAscension", DisplayName = "Ascension", Duration = 14.5 },
	GatewayOpen = { Id = "GatewayOpen", DisplayName = "The Gateway Opens", Duration = 14 },
	CyberDragonIgnition = { Id = "CyberDragonIgnition", DisplayName = "Core Ignition", Duration = 15.6 },
	FoundryBirth = { Id = "FoundryBirth", DisplayName = "Foundry Birth", Duration = 15.5 },
	Fg7aShow = { Id = "Fg7aShow", DisplayName = "Discharge", Duration = 16 },
	Fg3cShow = { Id = "Fg3cShow", DisplayName = "Pulse", Duration = 17 },
	Fg9eShow = { Id = "Fg9eShow", DisplayName = "Wake", Duration = 16.5 },
	Fg4bShow = { Id = "Fg4bShow", DisplayName = "Rise", Duration = 17 },
	Fg6dShow = { Id = "Fg6dShow", DisplayName = "Stir", Duration = 17 },
	Fg8mShow = { Id = "Fg8mShow", DisplayName = "Drift", Duration = 18 },
	LunarLiftoff = { Id = "LunarLiftoff", DisplayName = "Liftoff", Duration = 12.5 },
	ColossusAwakening = { Id = "ColossusAwakening", DisplayName = "The Awakening", Duration = 12 },
	-- colossal batch 1 (handlers live in ClientLib/BuildShows/<build>, registered by BuildShowController)
	HouseWelcome = { Id = "HouseWelcome", DisplayName = "Welcome Home", Duration = 4.5 },
	CraneLift = { Id = "CraneLift", DisplayName = "First Beam", Duration = 5 },
	DuckQuack = { Id = "DuckQuack", DisplayName = "The Quack", Duration = 6.5 },
	ShipBroadside = { Id = "ShipBroadside", DisplayName = "Broadside", Duration = 7 },
	-- colossal batch 2
	BuddyThumbsUp = { Id = "BuddyThumbsUp", DisplayName = "Thumbs Up", Duration = 4.5 },
		NoobWave = { Id = "NoobWave", DisplayName = "Victory Wave", Duration = 5.5 },
	WaterRelease = { Id = "WaterRelease", DisplayName = "Pressure Release", Duration = 5 },
	ToolboxPop = { Id = "ToolboxPop", DisplayName = "Lid Pop", Duration = 4.5 },
	FlagRaise = { Id = "FlagRaise", DisplayName = "Flag Raised", Duration = 5 },
	-- colossal batch 5
	PisaBells = { Id = "PisaBells", DisplayName = "The Bells", Duration = 6 },
	SphinxGlow = { Id = "SphinxGlow", DisplayName = "Eyes of Gold", Duration = 6 },
	SwordSlash = { Id = "SwordSlash", DisplayName = "The Slash", Duration = 5.5 },
	TrainSteam = { Id = "TrainSteam", DisplayName = "Full Steam", Duration = 6.5 },
	-- colossal batch 4
	SiegeDrop = { Id = "SiegeDrop", DisplayName = "The Bridge Falls", Duration = 5 },
	ArcadeBoot = { Id = "ArcadeBoot", DisplayName = "Game On", Duration = 5 },
	RocketLaunch = { Id = "RocketLaunch", DisplayName = "Lift Off", Duration = 5.5 },
	FlushVortex = { Id = "FlushVortex", DisplayName = "The Flush", Duration = 6 },
	DigCycle = { Id = "DigCycle", DisplayName = "One Big Scoop", Duration = 6 },
	-- colossal batch 3
	LogStack = { Id = "LogStack", DisplayName = "Log Stack", Duration = 5.5 },
	BridgeSettle = { Id = "BridgeSettle", DisplayName = "Bridge Settles", Duration = 4.5 },
	HammerSlam = { Id = "HammerSlam", DisplayName = "The Slam", Duration = 5 },
	HQFlag = { Id = "HQFlag", DisplayName = "Flag Deploys", Duration = 5 },
	MillSpin = { Id = "MillSpin", DisplayName = "Spin Up", Duration = 5 },
	SpawnShimmer = { Id = "SpawnShimmer", DisplayName = "Spawn Shimmer", Duration = 6.5 },
} :: { [string]: Spectacle }

return SpectacleConfig
