--!strict
-- Build catalogue. Adding a build = one entry here + one template model in
-- ServerStorage.BuildTemplates (see docs/BUILD_AUTHORING.md for the model convention).
-- No gameplay code references specific build ids.
--
-- Requirements are authored for GameConfig.PlayerScaling.ReferencePlayers (40) active
-- players and scaled down for smaller servers when the build starts.
-- A requirement key is a RESOURCE ID from ResourceConfig and accepts that grade OR BETTER of the same family:
-- `Wood` accepts Sticks/Logs/Timber, `Logs` accepts Logs/Timber, `Timber` accepts only Timber. Delivered units
-- count their grade's `Equivalent` toward the number. Common builds stay on basic ids; Rare+ add refined grades;
-- Legendary/Mythic add premium grades (Timber, Boulders, Heavy Steel, Energy Cores).
export type Build = {
	Id: string,
	DisplayName: string,
	Rarity: string,
	Description: string,
	Requirements: { [string]: number },
	RewardMultiplier: number, -- on top of the rarity multiplier
	Template: string, -- model name in ServerStorage.BuildTemplates
	StageNames: { string }, -- display names; count must match the template's Stage_XX children
	Thumbnail: string, -- placeholder glyph / future image id
	SpecialMechanic: string?, -- optional id handled by BuildService hooks
	EligibleModifiers: { string },
	MinimumServerLuck: number,
	Tags: { string },
	EstimatedDifficulty: number, -- 1..10, informational
	Enabled: boolean,
	CompletionSpectacle: string?, -- SpectacleConfig id played on completion (client-side show)
	Forgotten: boolean?, -- true = a Forgotten structure: never in normal selection, voting, Legacy or any Index list (ForgottenService starts it)
	MasterProject: boolean?, -- true = a Master Project: never in normal selection, voting or the normal Index (MasterProjectConfig starts it)
	Season: string?, -- SeasonConfig id for limited-time builds (nil = permanent); ended seasons are the Legacy pool
	-- COLOSSAL builds (see ColossalConfig + DevTools/ColossalBuilds + ClientLib/BuildShows):
	TemplateScale: number?, -- 1 = authored at final world size (default: GameConfig.Site.BuildScale for older templates)
	Yaw: number?, -- extra turn on the platform (degrees) so the hero silhouette reads from the spawn
	Offset: Vector3?, -- local shift from the build origin
	Footprint: { Width: number, Depth: number, Height: number }?, -- authored envelope (studs), informational
	ActivateAt: number?, -- partial activation point (progress fraction); default = middle of the rarity's range
	Milestones: { number }?, -- later activation steps (progress fractions), replicated as State "BuildMilestone"
	SpectacleSeconds: number?, -- override of the rarity's completion-show window (seconds) for a longer showpiece
	Legacy: boolean?, -- true = a retired pre-roster entry: kept (definition + data compatibility) but Enabled = false, so it never rolls, votes or shows in lists
	Show: string?, -- client show module in ClientLib/BuildShows (activation motion, milestones, spectacle); default = Id
}

local SeasonConfig = require(script.Parent.SeasonConfig)

local BuildConfig = {}

-- Builds whose footprint is too wide for the x1.25 Giant scale use NO_GIANT.
local ALL_MODIFIERS = { "Golden", "Giant", "Ancient", "Corrupted" }
local NO_GIANT = { "Golden", "Ancient", "Corrupted" }

BuildConfig.Builds = {
	ClassicHouse = {
		Id = "ClassicHouse",
		DisplayName = "Classic House",
		Rarity = "Common",
		Description = "A chunky, nostalgic blocky home with a big red roof and a smoking chimney. Everyone's first build.",
		Requirements = { Timber = 8000, StoneBlocks = 6000 },
		RewardMultiplier = 1,
		Template = "ClassicHouse", CompletionSpectacle = "HouseWelcome",
		StageNames = { "Foundation", "Walls", "Roof & Chimney", "Porch & Final Form" },
		Thumbnail = "🏠",
		SpecialMechanic = nil,
		EligibleModifiers = ALL_MODIFIERS,
		MinimumServerLuck = 0,
		Tags = { "Classic", "Architecture" },
		EstimatedDifficulty = 2,
		Enabled = true,
		TemplateScale = 1, Footprint = { Width = 80, Depth = 72, Height = 72 }, ActivateAt = 0.76,
	},
	ConstructionCrane = {
		Id = "ConstructionCrane", DisplayName = "Construction Crane", Rarity = "Common",
		Description = "A chunky yellow tower crane with a huge jib. Finish it and it sets its first beam.",
		Requirements = { MetalBeams = 7000, Stone = 7000 },
		RewardMultiplier = 1, Template = "ConstructionCrane", CompletionSpectacle = "CraneLift",
		StageNames = { "Base", "Tower Mast", "Main Jib", "Cab, Counterweight & Hook" },
		Thumbnail = "🏗", SpecialMechanic = nil, EligibleModifiers = ALL_MODIFIERS,
		MinimumServerLuck = 0, Tags = { "Mechanical", "Construction" }, EstimatedDifficulty = 2, Enabled = true,
		TemplateScale = 1, Footprint = { Width = 97, Depth = 34, Height = 79 }, ActivateAt = 0.76,
	},
	NoobStatue = {
		Id = "NoobStatue", DisplayName = "Noob Statue", Rarity = "Common",
		Description = "A giant classic noob with a block torso, thick arms and a big yellow head. It waves when it is done.",
		Requirements = { Stone = 7000, Timber = 5000 },
		RewardMultiplier = 1, Template = "NoobStatue", CompletionSpectacle = "NoobWave",
		StageNames = { "Pedestal & Feet", "Legs & Torso", "Arms", "Head" },
		Thumbnail = "🧍", SpecialMechanic = nil, EligibleModifiers = ALL_MODIFIERS,
		MinimumServerLuck = 0, Tags = { "Classic", "Humorous", "Monument" }, EstimatedDifficulty = 2, Enabled = true,
		TemplateScale = 1, Footprint = { Width = 48, Depth = 38, Height = 67 }, ActivateAt = 0.76,
	},
	WaterTower = {
		Id = "WaterTower", DisplayName = "Water Tower", Rarity = "Common",
		Description = "A huge round tank on a braced timber frame. Finish it and it lets off a burst of water.",
		Requirements = { MetalBeams = 6000, Logs = 5000 },
		RewardMultiplier = 1, Template = "WaterTower", CompletionSpectacle = "WaterRelease",
		StageNames = { "Footings", "Support Frame", "Tank", "Cap & Pipes" },
		Thumbnail = "🛢", SpecialMechanic = nil, EligibleModifiers = ALL_MODIFIERS,
		MinimumServerLuck = 0, Tags = { "Mechanical", "Industrial" }, EstimatedDifficulty = 2, Enabled = true,
		TemplateScale = 1, Footprint = { Width = 52, Depth = 70, Height = 76 }, ActivateAt = 0.76,
	},
	GiantToolbox = {
		Id = "GiantToolbox", DisplayName = "Giant Toolbox", Rarity = "Common",
		Description = "A wide red toolbox with its lid flipped open and a hammer, wrench and saw standing out of it.",
		Requirements = { Metal = 8000, Timber = 4000 },
		RewardMultiplier = 1, Template = "GiantToolbox", CompletionSpectacle = "ToolboxPop",
		StageNames = { "Box Body", "Open Lid", "Giant Tools" },
		Thumbnail = "🧰", SpecialMechanic = nil, EligibleModifiers = ALL_MODIFIERS,
		MinimumServerLuck = 0, Tags = { "Classic", "Construction" }, EstimatedDifficulty = 2, Enabled = true,
		TemplateScale = 1, Footprint = { Width = 66, Depth = 38, Height = 66 }, ActivateAt = 0.75,
	},
	BrickWatchtower = {
		Id = "BrickWatchtower", DisplayName = "Brick Watchtower", Rarity = "Common",
		Description = "A thick brick tower under a wide open lookout deck, with a flag that is raised when it is finished.",
		Requirements = { StoneBlocks = 8000, Timber = 4000 },
		RewardMultiplier = 1, Template = "BrickWatchtower", CompletionSpectacle = "FlagRaise",
		StageNames = { "Base", "Brick Shaft", "Observation Deck", "Roof & Flag" },
		Thumbnail = "🏰", SpecialMechanic = nil, EligibleModifiers = ALL_MODIFIERS,
		MinimumServerLuck = 0, Tags = { "Architecture", "Historical" }, EstimatedDifficulty = 2, Enabled = true,
		TemplateScale = 1, Footprint = { Width = 54, Depth = 54, Height = 73 }, ActivateAt = 0.76,
	},
	GiantSpawnPad = {
		Id = "GiantSpawnPad", DisplayName = "Giant Spawn Pad", Rarity = "Common",
		Description = "An enormous classic studded spawn plate that stands tilted on its corner while it is built, then rolls over and slams flat.",
		Requirements = { Stone = 8000, Metal = 5000 },
		RewardMultiplier = 1, Template = "GiantSpawnPad", CompletionSpectacle = "SpawnShimmer",
		StageNames = { "Studded Base", "Pylons & Frame", "Spawn Core" },
		Thumbnail = "🟦", SpecialMechanic = nil, EligibleModifiers = ALL_MODIFIERS,
		MinimumServerLuck = 0, Tags = { "Classic", "Monument" }, EstimatedDifficulty = 2, Enabled = true,
		TemplateScale = 1, Offset = Vector3.new(0, 0, 45), Footprint = { Width = 72, Depth = 72, Height = 30 }, ActivateAt = 0.75,
		SpectacleSeconds = 6.5, -- braces, lift, heavy corner roll, slam, flash and burst in ~6 s
	},
	-- COMMON ------------------------------------------------------------
	BuilderBuddyStatue = {
		Id = "BuilderBuddyStatue", DisplayName = "Builder Buddy Statue", Rarity = "Common",
		Description = "The game's mascot: a chunky builder in a big hard hat with huge boots and a giant hammer. It taps its hammer while you build, then hoists it high and gives a thumbs-up.",
		Requirements = { Stone = 5000, Wood = 3500, Metal = 2500, Logs = 1000 },
		RewardMultiplier = 1, Template = "BuilderBuddyStatue", CompletionSpectacle = "BuddyThumbsUp",
		StageNames = { "Pedestal & Boots", "Legs & Torso", "Arms & Giant Hammer", "Head & Hard Hat" },
		Thumbnail = "👷", SpecialMechanic = nil, EligibleModifiers = ALL_MODIFIERS,
		MinimumServerLuck = 0, Tags = { "Classic", "Humorous", "Monument" }, EstimatedDifficulty = 2, Enabled = true,
		TemplateScale = 1, Footprint = { Width = 90, Depth = 50, Height = 74 }, ActivateAt = 0.75,
	},
	-- LEGACY (Pass 11B): superseded by BuilderBuddyStatue; not on the canonical roster
	BlockBuddyStatue = {
		Id = "BlockBuddyStatue", DisplayName = "Block Buddy Statue", Rarity = "Common",
		Description = "A giant waving blocky builder in a hard hat. Classic charm, huge scale.",
		Requirements = { Stone = 8000, Wood = 5500 },
		RewardMultiplier = 1, Template = "BlockBuddyStatue",
		StageNames = { "Pedestal", "Legs", "Torso", "Arms", "Head & Hard Hat" },
		Thumbnail = "🗿", SpecialMechanic = nil, EligibleModifiers = ALL_MODIFIERS,
		MinimumServerLuck = 0, Tags = { "Classic", "Humorous", "Monument" }, EstimatedDifficulty = 2, Enabled = false, Legacy = true,
	},
	-- LEGACY (Pass 11B): superseded by BrickWatchtower; not on the canonical roster
	Watchtower = {
		Id = "Watchtower", DisplayName = "Wooden Watchtower", Rarity = "Common",
		Description = "A tall timber lookout with a ladder, lantern and red roof.",
		Requirements = { Wood = 10000, Stone = 4000 },
		RewardMultiplier = 1, Template = "Watchtower",
		StageNames = { "Footings", "Stilts", "Platform", "Railing & Ladder", "Roof & Flag" },
		Thumbnail = "🗼", SpecialMechanic = nil, EligibleModifiers = ALL_MODIFIERS,
		MinimumServerLuck = 0, Tags = { "Architecture", "Historical" }, EstimatedDifficulty = 2, Enabled = false, Legacy = true,
	},
	-- LIMITED EVENT (Lantern Festival; see SeasonConfig). Reuses the Watchtower model until it gets its own template.
	-- LEGACY (Pass 11B): the roster has no event builds; disabled (also keeps it out of the Legacy-season pool)
	LanternTower = {
		Id = "LanternTower", DisplayName = "Festival Lantern Tower", Rarity = "Rare",
		Description = "A timber watchtower hung with paper lanterns, built for the Lantern Festival.",
		Requirements = { Wood = 6000, Logs = 3000, Stone = 5000 },
		RewardMultiplier = 1.1, Template = "Watchtower",
		StageNames = { "Footings", "Stilts", "Platform", "Railing & Ladder", "Roof & Flag" },
		Thumbnail = "🏮", SpecialMechanic = nil, EligibleModifiers = ALL_MODIFIERS,
		MinimumServerLuck = 0, Tags = { "Event", "Architecture" }, EstimatedDifficulty = 3, Enabled = false, Legacy = true, Season = "LanternFestival",
	},
	-- UNCOMMON ----------------------------------------------------------
	ArcadeMachine = {
		Id = "ArcadeMachine", DisplayName = "Giant Arcade Machine", Rarity = "Uncommon",
		Description = "A ridiculously oversized arcade cabinet with a deep screen, a big marquee and a giant joystick. Finish it and the game boots up.",
		Requirements = { Wood = 6000, Metal = 5500, MetalBeams = 2500, PowerCell = 3500 },
		RewardMultiplier = 1, Template = "ArcadeMachine", CompletionSpectacle = "ArcadeBoot",
		StageNames = { "Cabinet Base", "Screen Housing", "Marquee", "Control Deck", "Screen & Final Form" },
		Thumbnail = "👾", SpecialMechanic = nil, EligibleModifiers = ALL_MODIFIERS,
		MinimumServerLuck = 0, Tags = { "Humorous", "Mechanical" }, EstimatedDifficulty = 4, Enabled = true,
		TemplateScale = 1, Footprint = { Width = 60, Depth = 70, Height = 96 }, ActivateAt = 0.65,
	},
	SiegeTower = {
		Id = "SiegeTower", DisplayName = "Medieval Siege Tower", Rarity = "Uncommon",
		Description = "A broad timber siege tower on four huge wheels with a raised drawbridge. Finish it and it rolls up and drops the bridge.",
		Requirements = { Timber = 9000, Stone = 4500, Metal = 2500 },
		RewardMultiplier = 1, Template = "SiegeTower", CompletionSpectacle = "SiegeDrop",
		StageNames = { "Wheels & Base", "Tower Frame", "Enclosed Body", "Upper Platform", "Drawbridge" },
		Thumbnail = "🏰", SpecialMechanic = nil, EligibleModifiers = ALL_MODIFIERS,
		MinimumServerLuck = 0, Tags = { "Medieval", "Mechanical" }, EstimatedDifficulty = 4, Enabled = true,
		TemplateScale = 1, Yaw = 20, Offset = Vector3.new(0, 0, 19), Footprint = { Width = 76, Depth = 90, Height = 105 }, ActivateAt = 0.65,
	},
	RocketMonument = {
		Id = "RocketMonument", DisplayName = "Rocket Launcher Monument", Rarity = "Uncommon",
		Description = "A heavy pedestal under a very long launcher tube with a big rocket loaded. It elevates and fires one sky rocket.",
		Requirements = { Metal = 7500, Stone = 6000 },
		RewardMultiplier = 1, Template = "RocketMonument", CompletionSpectacle = "RocketLaunch",
		StageNames = { "Pedestal", "Support Frame", "Launcher Tube", "Rocket" },
		Thumbnail = "🚀", SpecialMechanic = nil, EligibleModifiers = ALL_MODIFIERS,
		MinimumServerLuck = 0, Tags = { "Monument", "Mechanical" }, EstimatedDifficulty = 4, Enabled = true,
		TemplateScale = 1, Footprint = { Width = 110, Depth = 46, Height = 100 }, ActivateAt = 0.65,
	},
	GiantToilet = {
		Id = "GiantToilet", DisplayName = "Giant Toilet", Rarity = "Rare",
		Description = "A colossal friendly porcelain toilet with a raised lid and a tall tank. Finish it and it flushes with a giant vortex.",
		Requirements = { StoneBlocks = 12000, Metal = 9000 },
		RewardMultiplier = 1, Template = "GiantToilet", CompletionSpectacle = "FlushVortex",
		StageNames = { "Pedestal", "Bowl", "Tank", "Seat & Lid", "Flush Assembly" },
		Thumbnail = "🚽", SpecialMechanic = nil, EligibleModifiers = ALL_MODIFIERS,
		MinimumServerLuck = 0, Tags = { "Humorous", "Monument" }, EstimatedDifficulty = 5, Enabled = true,
		TemplateScale = 1, Yaw = 28, Footprint = { Width = 80, Depth = 112, Height = 110 }, ActivateAt = 0.55,
	},
	ColossalExcavator = {
		Id = "ColossalExcavator", DisplayName = "Colossal Excavator", Rarity = "Rare",
		Description = "A huge tracked excavator with an absurd bucket. Finish it and it digs one scoop and dumps it.",
		Requirements = { Metal = 11000, MetalBeams = 8500 },
		RewardMultiplier = 1, Template = "ColossalExcavator", CompletionSpectacle = "DigCycle",
		StageNames = { "Tracks", "Chassis & Counterweight", "Cab", "Boom", "Stick & Bucket", "Hydraulics & Masses" },
		Thumbnail = "🚜", SpecialMechanic = nil, EligibleModifiers = ALL_MODIFIERS,
		MinimumServerLuck = 0, Tags = { "Mechanical", "Industrial" }, EstimatedDifficulty = 5, Enabled = true,
		TemplateScale = 1, Footprint = { Width = 150, Depth = 60, Height = 84 }, ActivateAt = 0.55,
	},
	LoggingMachine = {
		Id = "LoggingMachine", DisplayName = "Logging Machine", Rarity = "Uncommon",
		Description = "A tracked forestry machine with a huge boom and grapple. Finish it and it stacks a big log.",
		Requirements = { Logs = 9000, Metal = 6000 },
		RewardMultiplier = 1, Template = "LoggingMachine", CompletionSpectacle = "LogStack",
		StageNames = { "Tracks", "Cab", "Boom", "Grapple", "Log Load" },
		Thumbnail = "🪵", SpecialMechanic = nil, EligibleModifiers = ALL_MODIFIERS,
		MinimumServerLuck = 0, Tags = { "Mechanical", "Industrial" }, EstimatedDifficulty = 4, Enabled = true,
		TemplateScale = 1, Footprint = { Width = 104, Depth = 40, Height = 80 }, ActivateAt = 0.65,
	},
	StoneArchBridge = {
		Id = "StoneArchBridge", DisplayName = "Stone Arch Bridge", Rarity = "Uncommon",
		Description = "A massive stone arch with thick piers, a heavy deck and end towers hung with lanterns and banners.",
		Requirements = { StoneBlocks = 10000, Timber = 4500 },
		RewardMultiplier = 1, Template = "StoneArchBridge", CompletionSpectacle = "BridgeSettle",
		StageNames = { "Piers", "Arch", "Deck", "Towers & Parapets", "Final Structure" },
		Thumbnail = "🌉", SpecialMechanic = nil, EligibleModifiers = ALL_MODIFIERS,
		MinimumServerLuck = 0, Tags = { "Architecture", "Historical" }, EstimatedDifficulty = 4, Enabled = true,
		TemplateScale = 1, Footprint = { Width = 104, Depth = 40, Height = 95 }, ActivateAt = 0.65,
	},
	GiantHammer = {
		Id = "GiantHammer", DisplayName = "Giant Hammer", Rarity = "Uncommon",
		Description = "An absurd sledge hammer on a pedestal. When it is done it slams the slab in front of it.",
		Requirements = { Metal = 8000, Stone = 7000 },
		RewardMultiplier = 1, Template = "GiantHammer", CompletionSpectacle = "HammerSlam",
		StageNames = { "Pedestal", "Handle", "Hammer Head", "Impact Base" },
		Thumbnail = "🔨", SpecialMechanic = nil, EligibleModifiers = ALL_MODIFIERS,
		MinimumServerLuck = 0, Tags = { "Humorous", "Construction" }, EstimatedDifficulty = 4, Enabled = true,
		TemplateScale = 1, Yaw = 8, Footprint = { Width = 95, Depth = 46, Height = 94 }, ActivateAt = 0.65,
	},
	OldRobloxHQ = {
		Id = "OldRobloxHQ", DisplayName = "Old Roblox HQ", Rarity = "Uncommon",
		Description = "A chunky stepped brick headquarters with a big entrance tower. The flag deploys and every window lights up.",
		Requirements = { StoneBlocks = 7000, MetalBeams = 5500 },
		RewardMultiplier = 1, Template = "OldRobloxHQ", CompletionSpectacle = "HQFlag",
		StageNames = { "Foundation", "Lower HQ", "Upper HQ", "Entrance Tower", "Roof & Flag" },
		Thumbnail = "🏢", SpecialMechanic = nil, EligibleModifiers = ALL_MODIFIERS,
		MinimumServerLuck = 0, Tags = { "Classic", "Architecture" }, EstimatedDifficulty = 4, Enabled = true,
		TemplateScale = 1, Footprint = { Width = 104, Depth = 68, Height = 98 }, ActivateAt = 0.65,
	},
	Windmill = {
		Id = "Windmill", DisplayName = "Windmill", Rarity = "Uncommon",
		Description = "A tapered mill tower with a giant four-blade rotor. When it is done the blades spin up and settle.",
		Requirements = { Timber = 9000, StoneBlocks = 5000 },
		RewardMultiplier = 1, Template = "Windmill", CompletionSpectacle = "MillSpin",
		StageNames = { "Base", "Tower", "Roof Housing", "Giant Blades", "Support & Balcony" },
		Thumbnail = "🌬", SpecialMechanic = nil, EligibleModifiers = ALL_MODIFIERS,
		MinimumServerLuck = 0, Tags = { "Architecture", "Mechanical" }, EstimatedDifficulty = 4, Enabled = true,
		TemplateScale = 1, Footprint = { Width = 76, Depth = 76, Height = 96 }, ActivateAt = 0.65,
	},
	LeaningTowerOfPisa = {
		Id = "LeaningTowerOfPisa", DisplayName = "Leaning Tower of Pisa", Rarity = "Rare",
		Description = "A tall marble arcade tower with an unmistakable lean. Finish it and the bells ring while a flock circles the crown.",
		Requirements = { StoneBlocks = 12000, Timber = 5000 },
		RewardMultiplier = 1, Template = "LeaningTowerOfPisa", CompletionSpectacle = "PisaBells",
		StageNames = { "Foundation", "Lower Arcade", "Mid Tower I", "Mid Tower II", "Upper Arcade", "Bell Chamber", "Crown" },
		Thumbnail = "🗼", SpecialMechanic = nil, EligibleModifiers = ALL_MODIFIERS,
		MinimumServerLuck = 0, Tags = { "Architecture", "Historical", "Monument" }, EstimatedDifficulty = 5, Enabled = true,
		TemplateScale = 1, Footprint = { Width = 70, Depth = 70, Height = 130 }, ActivateAt = 0.55,
	},
	Sphinx = {
		Id = "Sphinx", DisplayName = "Sphinx", Rarity = "Rare",
		Description = "A long reclining sandstone sphinx with huge paws and a striped headdress. Its eyes glow and the sand gusts across the base.",
		Requirements = { Boulders = 9000, StoneBlocks = 9000 },
		RewardMultiplier = 1, Template = "Sphinx", CompletionSpectacle = "SphinxGlow",
		StageNames = { "Plinth & Paws", "Lion Body", "Chest & Shoulders", "Neck & Head", "Headdress", "Face & Final Monument" },
		Thumbnail = "🦁", SpecialMechanic = nil, EligibleModifiers = ALL_MODIFIERS,
		MinimumServerLuck = 0, Tags = { "Historical", "Monument" }, EstimatedDifficulty = 5, Enabled = true,
		TemplateScale = 0.95, Yaw = 30, Footprint = { Width = 168, Depth = 70, Height = 82 }, ActivateAt = 0.55,
	},
	GiantLinkedSword = {
		Id = "GiantLinkedSword", DisplayName = "Giant Linked Sword", Rarity = "Rare",
		Description = "The classic blocky sword, enormous, stuck in a stone. Finish it and it rises and makes one huge slash.",
		Requirements = { MetalBeams = 8000, Stone = 8000 },
		RewardMultiplier = 1, Template = "GiantLinkedSword", CompletionSpectacle = "SwordSlash",
		StageNames = { "Stone Pedestal", "Lower Blade", "Full Blade", "Guard & Handle", "Pommel & Final Assembly" },
		Thumbnail = "🗡", SpecialMechanic = nil, EligibleModifiers = ALL_MODIFIERS,
		MinimumServerLuck = 0, Tags = { "Classic", "Monument" }, EstimatedDifficulty = 5, Enabled = true,
		TemplateScale = 1, Yaw = 14, Footprint = { Width = 90, Depth = 58, Height = 144 }, ActivateAt = 0.55,
	},
	SteamLocomotive = {
		Id = "SteamLocomotive", DisplayName = "Steam Locomotive", Rarity = "Rare",
		Description = "A huge steam engine with an oversized stack and a long tender. Finish it and it blows its whistle and cycles its wheels.",
		Requirements = { Metal = 10000, MetalBeams = 6000, Logs = 3000 },
		RewardMultiplier = 1, Template = "SteamLocomotive", CompletionSpectacle = "TrainSteam",
		StageNames = { "Wheels & Frame", "Boiler", "Cab", "Smokestack", "Cowcatcher & Front", "Tender", "Rods & Steam Hardware" },
		Thumbnail = "🚂", SpecialMechanic = nil, EligibleModifiers = ALL_MODIFIERS,
		MinimumServerLuck = 0, Tags = { "Mechanical", "Industrial" }, EstimatedDifficulty = 5, Enabled = true,
		TemplateScale = 1, Yaw = 18, Footprint = { Width = 180, Depth = 41, Height = 86 }, ActivateAt = 0.55,
	},
	-- RARE --------------------------------------------------------------
	PirateShip = {
		Id = "PirateShip", DisplayName = "Pirate Ship", Rarity = "Rare",
		Description = "A sweeping three-masted galleon in dry dock: huge sails, a full broadside and the jolly roger.",
		Requirements = { Timber = 13000, Metal = 10000 },
		RewardMultiplier = 1, Template = "PirateShip", CompletionSpectacle = "ShipBroadside",
		StageNames = { "Keel", "Lower Hull", "Upper Deck, Bow & Stern", "Masts", "Main Sails", "Cannons", "Figurehead & Flags" },
		Thumbnail = "⛵", SpecialMechanic = nil, EligibleModifiers = NO_GIANT,
		MinimumServerLuck = 0, Tags = { "Historical", "Fantasy" }, EstimatedDifficulty = 5, Enabled = true,
		TemplateScale = 1, Yaw = 10, Footprint = { Width = 168, Depth = 50, Height = 113 }, ActivateAt = 0.53,
	},
	GiantDuck = {
		Id = "GiantDuck", DisplayName = "Giant Duck", Rarity = "Rare",
		Description = "A monumental rubber duck in its own pond. It bobs, it looks around, it QUACKS.",
		Requirements = { Timber = 12000, Stone = 11000 },
		RewardMultiplier = 1, Template = "GiantDuck", CompletionSpectacle = "DuckQuack",
		StageNames = { "Feet & Pond", "Body", "Wings", "Neck & Head", "Beak & Face", "Tail & Final Form" },
		Thumbnail = "🦆", SpecialMechanic = nil, EligibleModifiers = NO_GIANT,
		MinimumServerLuck = 0, Tags = { "Humorous", "Monument" }, EstimatedDifficulty = 5, Enabled = true,
		TemplateScale = 1, Yaw = 55, Footprint = { Width = 128, Depth = 169, Height = 114 }, ActivateAt = 0.55, Milestones = { 0.85 },
	},
	-- LEGACY (Pass 11B): not on the canonical roster
	CastleGate = {
		Id = "CastleGate", DisplayName = "Massive Castle Gate", Rarity = "Rare",
		Description = "Twin towers, a great arch and an iron portcullis.",
		Requirements = { Stone = 10000, StoneBlocks = 7000, Wood = 2500, Logs = 1500, Metal = 2500, MetalBeams = 1500 },
		RewardMultiplier = 1, Template = "CastleGate",
		StageNames = { "Foundations", "Towers", "Great Arch", "Battlements", "Portcullis", "Banners" },
		Thumbnail = "🏰", SpecialMechanic = nil, EligibleModifiers = NO_GIANT,
		MinimumServerLuck = 0, Tags = { "Historical", "Architecture" }, EstimatedDifficulty = 5, Enabled = false, Legacy = true,
	},
	-- EPIC --------------------------------------------------------------
	VolcanoTemple = {
		Id = "VolcanoTemple", DisplayName = "Volcano Temple", Rarity = "Epic",
		Description = "A broad smouldering volcano with a temple carved into its slope. Lava wakes early, runs down the flanks, and on completion the crater erupts.",
		Requirements = { Stone = 6000, StoneBlocks = 9000, Boulders = 6000, PowerCell = 5000, Cells = 6000 },
		RewardMultiplier = 1, Template = "VolcanoTemple", CompletionSpectacle = "VolcanoEruption",
		StageNames = { "Temple Terrace", "Lower Slopes", "Upper Cone", "Temple Facade", "Lava Channels", "Crater", "Summit", "Temple Crown" },
		Thumbnail = "🌋", SpecialMechanic = nil, EligibleModifiers = NO_GIANT,
		MinimumServerLuck = 0, Tags = { "Fantasy", "Monument", "Ancient" }, EstimatedDifficulty = 7, Enabled = true,
		TemplateScale = 1, Footprint = { Width = 185, Depth = 181, Height = 116 }, ActivateAt = 0.45, Milestones = { 0.75 },
	},
	UFO = {
		Id = "UFO", DisplayName = "UFO", Rarity = "Epic",
		Description = "A huge landed saucer on four legs with a glass dome and a halo ring. Its rim wakes early; finish it and it lifts off and hovers.",
		Requirements = { Metal = 6000, MetalBeams = 9000, HeavySteel = 5000, PowerCell = 5000, Cells = 5000, Stone = 2000 },
		RewardMultiplier = 1, Template = "UFO", CompletionSpectacle = "UfoHover",
		StageNames = { "Landing Base", "Lower Hull", "Main Disc", "Upper Hull", "Dome & Core", "Underside Emitter", "Halo Ring" },
		Thumbnail = "🛸", SpecialMechanic = nil, EligibleModifiers = NO_GIANT,
		MinimumServerLuck = 0, Tags = { "SciFi", "Mechanical" }, EstimatedDifficulty = 7, Enabled = true,
		TemplateScale = 1, Footprint = { Width = 172, Depth = 172, Height = 104 }, ActivateAt = 0.45, Milestones = { 0.75 },
	},
	GiantRobot = {
		Id = "GiantRobot", DisplayName = "Giant Robot", Rarity = "Epic",
		Description = "A towering heavy mech with huge shoulders and a glowing chest core. It powers up while you build, then scans the server and salutes.",
		Requirements = { Metal = 6000, MetalBeams = 8000, HeavySteel = 6000, PowerCell = 4000, Cells = 5000, StoneBlocks = 3000 },
		RewardMultiplier = 1, Template = "GiantRobot", CompletionSpectacle = "RobotPowerUp",
		StageNames = { "Feet & Base", "Legs", "Torso", "Shoulders", "Arms", "Head", "Armor & Core Housing", "Back Reactor" },
		Thumbnail = "🤖", SpecialMechanic = nil, EligibleModifiers = ALL_MODIFIERS,
		MinimumServerLuck = 0, Tags = { "SciFi", "Mechanical", "Monument" }, EstimatedDifficulty = 7, Enabled = true,
		TemplateScale = 0.86, Footprint = { Width = 121, Depth = 86, Height = 165 }, ActivateAt = 0.45, Milestones = { 0.72 },
	},
	Colosseum = {
		Id = "Colosseum", DisplayName = "Colosseum Arena", Rarity = "Epic",
		Description = "A vast stone amphitheatre with two tiers of arches and a monumental gate. Torches light early; finish it and a wave of light and banners sweeps the ring.",
		Requirements = { Stone = 8000, StoneBlocks = 11000, Boulders = 5000, Metal = 3000, HeavySteel = 3000, Logs = 2000 },
		RewardMultiplier = 1, Template = "Colosseum", CompletionSpectacle = "ArenaWave",
		StageNames = { "Arena Floor", "Lower Wall", "Lower Arcade", "Upper Ring", "Upper Arcade", "Seating Bowl", "Grand Entrance", "Crown & Banners" },
		Thumbnail = "🏟", SpecialMechanic = nil, EligibleModifiers = NO_GIANT,
		MinimumServerLuck = 0, Tags = { "Historical", "Monument" }, EstimatedDifficulty = 7, Enabled = true,
		TemplateScale = 1, Yaw = 28, Footprint = { Width = 184, Depth = 160, Height = 96 }, ActivateAt = 0.45, Milestones = { 0.75 },
	},
	DragonCitadel = {
		Id = "DragonCitadel", DisplayName = "Dragon Citadel", Rarity = "Epic",
		Description = "A giant dragon perched on and gripping a stone citadel, wings spread wider than the walls. It breathes while you build, and on completion it rears, beats its wings and breathes fire.",
		Requirements = { Stone = 5500, StoneBlocks = 8000, Boulders = 3000, Logs = 5500, Timber = 2500, Metal = 4000, HeavySteel = 3500 },
		RewardMultiplier = 1, Template = "DragonCitadel", CompletionSpectacle = "DragonRoar",
		StageNames = { "Fortress Foundation", "Fortress Walls", "Dragon Torso", "Neck", "Head", "Wings", "Tail & Claws", "Citadel Crown" },
		Thumbnail = "🐉", SpecialMechanic = nil, EligibleModifiers = NO_GIANT,
		MinimumServerLuck = 0, Tags = { "Fantasy", "Monument" }, EstimatedDifficulty = 7, Enabled = true,
		TemplateScale = 1, Yaw = 30, Footprint = { Width = 220, Depth = 192, Height = 160 }, ActivateAt = 0.45, Milestones = { 0.75 },
	},
	SkyGalleon = {
		Id = "SkyGalleon", DisplayName = "Sky Galleon", Rarity = "Epic",
		Description = "A long fantasy airship slung under three huge lift envelopes. Its lift wakes early, the engines start late, and on completion it rises off the dock and hovers.",
		Requirements = { Wood = 4000, Logs = 6000, Timber = 3500, Metal = 4500, MetalBeams = 5000, HeavySteel = 2000, PowerCell = 3000, Cells = 4000 },
		RewardMultiplier = 1, Template = "SkyGalleon", CompletionSpectacle = "GalleonLift",
		StageNames = { "Keel & Lower Hull", "Upper Hull", "Mast & Support Frame", "Lift Envelopes", "Sails & Fins", "Propulsion", "Command Deck" },
		Thumbnail = "🎈", SpecialMechanic = nil, EligibleModifiers = NO_GIANT,
		MinimumServerLuck = 0, Tags = { "Fantasy", "Vehicle" }, EstimatedDifficulty = 7, Enabled = true,
		TemplateScale = 1, Yaw = 12, Footprint = { Width = 200, Depth = 86, Height = 133 }, ActivateAt = 0.45, Milestones = { 0.75 },
	},
	ClockworkTitan = {
		Id = "ClockworkTitan", DisplayName = "Clockwork Titan", Rarity = "Epic",
		Description = "A towering bronze clockwork giant carrying two enormous open gears and a great pendulum. Its gears start turning early; finish it and it winds up, strikes and chimes.",
		Requirements = { Metal = 6500, MetalBeams = 8000, HeavySteel = 6000, PowerCell = 4000, Cells = 4500, Logs = 3000 },
		RewardMultiplier = 1, Template = "ClockworkTitan", CompletionSpectacle = "TitanChime",
		StageNames = { "Feet & Platform", "Legs", "Pelvis & Great Gear", "Torso", "Arms", "Head", "Gear System", "Core & Mainspring" },
		Thumbnail = "⚙", SpecialMechanic = nil, EligibleModifiers = ALL_MODIFIERS,
		MinimumServerLuck = 0, Tags = { "Mechanical", "Fantasy", "Monument" }, EstimatedDifficulty = 7, Enabled = true,
		TemplateScale = 0.8, Footprint = { Width = 171, Depth = 85, Height = 163 }, ActivateAt = 0.45, Milestones = { 0.72 },
	},
	-- LEGENDARY ---------------------------------------------------------
	MegaFortress = {
		Id = "MegaFortress", DisplayName = "Mega Fortress Wall", Rarity = "Legendary",
		Description = "A colossal defensive wall across the whole site, with two great towers and a gatehouse you can see straight through. Its torches and gate machinery wake as it rises; finish it and the great gates open.",
		Requirements = { Stone = 6000, StoneBlocks = 9000, Boulders = 8000, Metal = 3000, MetalBeams = 4000, HeavySteel = 5000, Logs = 3000 },
		RewardMultiplier = 1, Template = "MegaFortress", CompletionSpectacle = "FortressBanners",
		StageNames = { "Foundation", "Main Wall Span", "West Tower", "East Tower", "Gatehouse", "Battlements & Banners", "Inner Towers", "Gate Mechanism", "Crown & Beacons" },
		Thumbnail = "🧱", SpecialMechanic = nil, EligibleModifiers = NO_GIANT,
		MinimumServerLuck = 0, Tags = { "Historical", "Monument" }, EstimatedDifficulty = 8, Enabled = true,
		TemplateScale = 1, Footprint = { Width = 193, Depth = 84, Height = 127 }, ActivateAt = 0.40, Milestones = { 0.65, 0.82 },
	},
	LeviathanDreadnought = {
		Id = "LeviathanDreadnought", DisplayName = "Leviathan Dreadnought", Rarity = "Legendary",
		Description = "A capital warship longer than the site, with a gigantic engine block. Its engines warm, its power systems wake and it lifts off its cradle as it nears completion; finish it and it ignites.",
		Requirements = { Metal = 4000, MetalBeams = 7000, HeavySteel = 9000, PowerCell = 3000, Cells = 5000, EnergyCore = 6000, StoneBlocks = 4000 },
		RewardMultiplier = 1, Template = "LeviathanDreadnought", CompletionSpectacle = "DreadnoughtIgnition",
		StageNames = { "Keel & Cradle", "Lower Hull", "Upper Hull", "Rear Engine Block", "Command Tower", "Side Fins", "Dorsal Cannon", "Power Systems", "Final Armor" },
		Thumbnail = "🚀", SpecialMechanic = nil, EligibleModifiers = NO_GIANT,
		MinimumServerLuck = 0, Tags = { "SciFi", "Vehicle", "Mechanical" }, EstimatedDifficulty = 8, Enabled = true,
		TemplateScale = 1, Yaw = -165, Footprint = { Width = 247, Depth = 144, Height = 107 }, ActivateAt = 0.40, Milestones = { 0.65, 0.82 },
	},
	WorldTree = {
		Id = "WorldTree", DisplayName = "World Tree", Rarity = "Legendary",
		Description = "A monumental ancient tree with roots across the whole site and a vast crown of separate canopies. It stirs, its heartwood wakes and its crown breathes as it grows; finish it and a golden pulse blooms through it.",
		Requirements = { Wood = 5000, Logs = 8000, Timber = 10000, Stone = 3000, Boulders = 4000, Cells = 4000, EnergyCore = 4000 },
		RewardMultiplier = 1, Template = "WorldTree", CompletionSpectacle = "WorldTreeBloom",
		StageNames = { "Root Platform", "Lower Trunk", "Upper Trunk", "First Great Branches", "Remaining Branches", "Lower Crown", "Upper Crown", "Vines & Shrine", "Final Crown" },
		Thumbnail = "🌳", SpecialMechanic = nil, EligibleModifiers = NO_GIANT,
		MinimumServerLuck = 0, Tags = { "Fantasy", "Nature", "Monument" }, EstimatedDifficulty = 8, Enabled = true,
		TemplateScale = 1, Footprint = { Width = 244, Depth = 212, Height = 230 }, ActivateAt = 0.40, Milestones = { 0.65, 0.82 },
	},
	LunarLaunchComplex = {
		Id = "LunarLaunchComplex", DisplayName = "Lunar Launch Complex", Rarity = "Legendary",
		Description = "An enormous moon rocket on a flame trench beside a heavy launch gantry. It vents, swings its service arms and readies for launch as it nears completion; finish it for countdown, ignition and liftoff.",
		Requirements = { Metal = 5000, MetalBeams = 8000, HeavySteel = 9000, PowerCell = 3000, Cells = 4000, EnergyCore = 5000, StoneBlocks = 4000 },
		RewardMultiplier = 1, Template = "LunarLaunchComplex", CompletionSpectacle = "LunarLiftoff",
		StageNames = { "Launch Base & Flame Trench", "Lower Rocket", "Middle Rocket", "Upper Rocket", "Capsule & Nose", "Gantry Tower", "Service Arms", "Fuel & Support", "Launch Systems" },
		Thumbnail = "🚀", SpecialMechanic = nil, EligibleModifiers = ALL_MODIFIERS,
		MinimumServerLuck = 0, Tags = { "SciFi", "Industrial", "Monument" }, EstimatedDifficulty = 8, Enabled = true,
		TemplateScale = 1, Footprint = { Width = 168, Depth = 100, Height = 218 }, ActivateAt = 0.40, Milestones = { 0.68, 0.84 },
	},
	AncientColossus = {
		Id = "AncientColossus", DisplayName = "Ancient Colossus", Rarity = "Legendary",
		Description = "A weathered stone giant with a tower shield and a colossal sword, built like a monument. Its cracks, eyes and core wake as it rises; finish it and it hauls its sword skyward and strikes the stone.",
		Requirements = { Stone = 6000, StoneBlocks = 9000, Boulders = 11000, Metal = 3000, HeavySteel = 5000, Cells = 2000, EnergyCore = 2000 },
		RewardMultiplier = 1, Template = "AncientColossus", CompletionSpectacle = "ColossusAwakening",
		StageNames = { "Pedestal & Feet", "Legs", "Pelvis", "Torso", "Shield Arm", "Sword Arm", "Helmet", "Shoulders & Back", "Ancient Core" },
		Thumbnail = "🗿", SpecialMechanic = nil, EligibleModifiers = NO_GIANT,
		MinimumServerLuck = 0, Tags = { "Ancient", "Monument", "Fantasy" }, EstimatedDifficulty = 8, Enabled = true,
		TemplateScale = 0.85, Footprint = { Width = 208, Depth = 91, Height = 224 }, ActivateAt = 0.40, Milestones = { 0.65, 0.82 },
	},
	SkyCity = {
		Id = "SkyCity", DisplayName = "Sky City", Rarity = "Mythic",
		Description = "A floating city in pieces: a central spire city and three separate sky districts joined by huge bridges, with open sky between them. Its lift systems wake as it rises; finish it and the whole city ascends.",
		Requirements = { Metal = 4000, MetalBeams = 5000, HeavySteel = 10000, PowerCell = 3000, Cells = 4000, EnergyCore = 9000, StoneBlocks = 4000, Boulders = 4000, Logs = 3000 },
		RewardMultiplier = 1, Template = "SkyCity", CompletionSpectacle = "SkyCityAscension",
		StageNames = { "Central Foundation", "Lower District", "Upper District", "Sky District A", "Sky District B", "Sky District C", "Grand Bridges", "Central Spire", "Lift Rings", "Secondary Skyline", "City Crown" },
		Thumbnail = "🏙", SpecialMechanic = nil, EligibleModifiers = NO_GIANT,
		MinimumServerLuck = 0, Tags = { "Fantasy", "SciFi", "Monument" }, EstimatedDifficulty = 10, Enabled = true,
		TemplateScale = 1.15, Footprint = { Width = 303, Depth = 204, Height = 237 }, ActivateAt = 0.35, Milestones = { 0.60, 0.82 },
	},
	OrbitalRingGateway = {
		Id = "OrbitalRingGateway", DisplayName = "Orbital Ring Gateway", Rarity = "Mythic",
		Description = "An enormous upright gateway ring with an open centre, a turning inner ring and a suspended core. It wakes in stages as it rises; finish it and a gateway field opens inside the ring.",
		Requirements = { Metal = 5000, MetalBeams = 6000, HeavySteel = 11000, PowerCell = 3000, Cells = 4000, EnergyCore = 10000, StoneBlocks = 3000, Boulders = 2000, Logs = 2000 },
		RewardMultiplier = 1, Template = "OrbitalRingGateway", CompletionSpectacle = "GatewayOpen",
		StageNames = { "Foundation", "West Support", "East Support", "Lower Ring", "Upper Ring", "Ring Braces", "Inner Ring", "Suspended Core", "Power Modules", "Gateway Crown" },
		Thumbnail = "⭕", SpecialMechanic = nil, EligibleModifiers = NO_GIANT,
		MinimumServerLuck = 0, Tags = { "SciFi", "Monument" }, EstimatedDifficulty = 10, Enabled = true,
		TemplateScale = 1, Footprint = { Width = 250, Depth = 131, Height = 247 }, ActivateAt = 0.35, Milestones = { 0.70, 0.82 },
	},
	CyberDragonFortress = {
		Id = "CyberDragonFortress", DisplayName = "Cyber Dragon Fortress", Rarity = "Mythic",
		Description = "A colossal mechanical dragon whose armoured body is the fortress, standing on bastion legs with segmented wings and a reactor core. It powers up in stages as it rises; finish it and it ignites its core and fires one beam.",
		Requirements = { Metal = 5000, MetalBeams = 6000, HeavySteel = 10000, PowerCell = 3000, Cells = 4000, EnergyCore = 8000, StoneBlocks = 4000, Boulders = 4000, Logs = 2000 },
		RewardMultiplier = 1, Template = "CyberDragonFortress", CompletionSpectacle = "CyberDragonIgnition",
		StageNames = { "Fortress Bastions", "Lower Body", "Chest & Core", "Neck", "Head & Jaw", "Near Wing", "Far Wing", "Tail", "Energy Spine", "Upper Fortress & Armor" },
		Thumbnail = "🐲", SpecialMechanic = nil, EligibleModifiers = NO_GIANT,
		MinimumServerLuck = 0, Tags = { "SciFi", "Fantasy", "Mechanical", "Monument" }, EstimatedDifficulty = 10, Enabled = true,
		TemplateScale = 1, Yaw = 15, Footprint = { Width = 326, Depth = 140, Height = 239 }, ActivateAt = 0.35, Milestones = { 0.60, 0.82 },
	},
	TitanMechFoundry = {
		Id = "TitanMechFoundry", DisplayName = "Titan Mech Foundry", Rarity = "Mythic",
		Description = "A titan mech being assembled inside a colossal open factory frame, with a gantry crane, assembly arms and a suspended arm. The machinery wakes as it rises; finish it and the mech is completed, released and powered up.",
		Requirements = { Metal = 5000, MetalBeams = 7000, HeavySteel = 10000, PowerCell = 3000, Cells = 3000, EnergyCore = 7000, StoneBlocks = 4000, Boulders = 5000, Logs = 2000 },
		RewardMultiplier = 1, Template = "TitanMechFoundry", CompletionSpectacle = "FoundryBirth",
		StageNames = { "Foundry Floor", "Side Towers", "Overhead Frame", "Legs", "Torso & Reactor", "Head", "Right Arm", "Suspended Left Arm", "Assembly Arms", "Gantry Crane", "Power & Final Lock" },
		Thumbnail = "🏗", SpecialMechanic = nil, EligibleModifiers = NO_GIANT,
		MinimumServerLuck = 0, Tags = { "SciFi", "Mechanical", "Monument" }, EstimatedDifficulty = 10, Enabled = true,
		TemplateScale = 1, Footprint = { Width = 297, Depth = 97, Height = 272 }, ActivateAt = 0.35, Milestones = { 0.60, 0.82 },
	},
	-- MYTHIC ------------------------------------------------------------
	-- MASTER PROJECT (starts automatically, see MasterProjectConfig). Roughly 14% of the units are secret resources, so a server of
	-- non-Master players with premium materials can still finish most of it; Master Builders bring the Star Metal / Ancient Timber.
	OrbitalStation = {
		Id = "OrbitalStation", DisplayName = "Orbital Station", Rarity = "Mythic",
		Description = "The server's first true megaproject: a ringed orbital station with solar wings, docking arms and a command dome.",
		Requirements = { HeavySteel = 9000, EnergyCore = 6000, MetalBeams = 6000, Cells = 5000, Metal = 3000, StarMetal = 3500, AncientTimber = 1200 },
		RewardMultiplier = 3.5, Template = "OrbitalStation", CompletionSpectacle = "OrbitalActivation",
		StageNames = { "Launch Base", "Central Core", "Lower Ring", "Upper Ring", "Docking Arms", "Power Modules", "Solar Arrays", "Command Module", "Antenna & Dish", "Activation" },
		Thumbnail = "🛰", SpecialMechanic = nil, EligibleModifiers = {},
		MinimumServerLuck = 0, Tags = { "SciFi", "MasterProject" }, EstimatedDifficulty = 10, Enabled = true, MasterProject = true,
	},
} :: { [string]: Build }

function BuildConfig.Get(id: string): Build?
	return BuildConfig.Builds[id]
end

-- Builds in the NORMAL pool: enabled, Server Luck allows, and (for limited-time builds) the event is Active.
-- Legacy builds (ended events) are not here; see BuildConfig.Legacy.
function BuildConfig.Eligible(rarity: string?, serverLuck: number): { Build }
	local list = {}
	for _, b in BuildConfig.Builds do
		if b.Enabled and not b.MasterProject and not b.Forgotten and serverLuck >= b.MinimumServerLuck and (rarity == nil or b.Rarity == rarity) and SeasonConfig.PoolOf(b.Season) == "Normal" then
			table.insert(list, b)
		end
	end
	table.sort(list, function(a, b)
		return a.Id < b.Id
	end)
	return list
end

-- Builds from ended events (the Legacy pool): obtainable only through the small activation chance (SeasonConfig.Legacy).
function BuildConfig.Legacy(): { Build }
	local list = {}
	for _, b in BuildConfig.Builds do
		if b.Enabled and not b.MasterProject and not b.Forgotten and b.Season ~= nil and SeasonConfig.PoolOf(b.Season) == "Legacy" then
			table.insert(list, b)
		end
	end
	table.sort(list, function(a, b)
		return a.Id < b.Id
	end)
	return list
end

-- Stable ordering for the Build Index: by rarity, then name.
function BuildConfig.IndexOrder(rarityOrder: { [string]: number }): { Build }
	local list = {}
	for _, b in BuildConfig.Builds do
		if b.Enabled and not b.MasterProject and not b.Forgotten then
			table.insert(list, b)
		end
	end
	table.sort(list, function(a, b)
		local ra, rb = rarityOrder[a.Rarity] or 0, rarityOrder[b.Rarity] or 0
		if ra ~= rb then
			return ra < rb
		end
		return a.DisplayName < b.DisplayName
	end)
	return list
end

-- SAFETY NET: every build that has a finished template + show must stay in BuildConfig. Add an id here when a new build ships;
-- BuildConfig.Validate() (run at server start) warns loudly if one is missing, disabled, or has no stages / spectacle id.
BuildConfig.RequiredIds = {
	"ClassicHouse", "ConstructionCrane", "GiantDuck", "PirateShip",
	"NoobStatue", "WaterTower", "GiantToolbox", "BrickWatchtower", "GiantSpawnPad",
	"LoggingMachine", "StoneArchBridge", "GiantHammer", "OldRobloxHQ", "Windmill",
	"SiegeTower", "ArcadeMachine", "RocketMonument", "GiantToilet", "ColossalExcavator",
	"LeaningTowerOfPisa", "Sphinx", "GiantLinkedSword", "SteamLocomotive",
	"VolcanoTemple", "UFO", "GiantRobot", "Colosseum",
	"DragonCitadel", "SkyGalleon", "ClockworkTitan",
	"MegaFortress", "LeviathanDreadnought", "WorldTree",
	"LunarLaunchComplex", "AncientColossus",
	"BuilderBuddyStatue",
	"SkyCity", "OrbitalRingGateway", "CyberDragonFortress", "TitanMechFoundry",
} :: { string }

-- CANONICAL POOLS: how many ENABLED normal-pool builds each rarity must have (no legacy, Master Projects or seasonal builds).
-- Keep in step with BUILD_ROSTER.md (raise a count when a build of that rarity ships). Forgotten is a separate archive.
BuildConfig.ExpectedPools = { Common = 8, Uncommon = 8, Rare = 8, Epic = 7, Legendary = 5, Mythic = 4 } :: { [string]: number }
local POOL_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

-- the live normal-pool size per rarity (what selection and votes can actually draw from)
function BuildConfig.PoolCounts(): { [string]: number }
	local out = {}
	for _, r in { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" } do
		out[r] = #BuildConfig.Eligible(r, math.huge)
	end
	return out
end

-- "C8 U8 R8 E7 L5 M2"
function BuildConfig.PoolSummary(): string
	local c = BuildConfig.PoolCounts()
	local parts = {}
	for _, r in POOL_ORDER do
		table.insert(parts, string.sub(r, 1, 1) .. tostring(c[r]))
	end
	return table.concat(parts, " ")
end

-- returns the list of problems (empty = healthy)
function BuildConfig.Validate(): { string }
	local problems = {}
	for _, id in BuildConfig.RequiredIds do
		local b = (BuildConfig.Builds :: any)[id]
		if not b then
			table.insert(problems, "MISSING build entry: " .. id)
		elseif not b.Enabled then
			table.insert(problems, "build disabled: " .. id)
		elseif not b.StageNames or #b.StageNames == 0 then
			table.insert(problems, "no StageNames: " .. id)
		end
	end
	-- the eligible pools must be exactly the canonical roster
	local counts = BuildConfig.PoolCounts()
	for r, want in BuildConfig.ExpectedPools do
		if counts[r] ~= want then
			table.insert(problems, string.format("%s pool has %d eligible builds, expected %d (a legacy/extra entry is enabled, or a canonical one is missing)", r, counts[r] or 0, want))
		end
	end
	local required = {}
	for _, id in BuildConfig.RequiredIds do
		required[id] = true
	end
	for _, r in POOL_ORDER do
		for _, b in BuildConfig.Eligible(r, math.huge) do
			if not required[b.Id] then
				table.insert(problems, "eligible build is not in RequiredIds (the canonical list): " .. b.Id)
			end
		end
	end
	return problems
end

return BuildConfig
