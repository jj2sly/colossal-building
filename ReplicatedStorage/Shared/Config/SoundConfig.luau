--!strict
-- Sound hooks. Placeholders use Roblox's built-in rbxasset sounds; swap SoundId for
-- uploaded audio later without touching gameplay code. Cooldown rate-limits each hook
-- per client so dozens of simultaneous deposits don't become noise.
export type SoundDef = { SoundId: string, Volume: number, Pitch: number, Cooldown: number, Max: number? } -- Max = cut the sound off after this many seconds

local SoundConfig = {}

-- PASS 21B SIMULATOR SOUND SET. The UI / reward / carry cues are bright, short and bouncy ("Daily Sounds" free game sounds, synthesized,
-- licensed for experiences): a cartoon pop, a coin ping, a springy jump and a whoosh, pitched up and down to make a whole family.
-- Heavy construction stays heavy: Thud, Rumble, Boom, DepositHeavy and the Pro Sound Effects gather hits are untouched.
local POP = "rbxassetid://106984966606682"
local COIN = "rbxassetid://130378474223829"
local WHOOSH = "rbxassetid://80984744279155"
local BEEPS = "rbxassetid://80890994815283"
local IMPACT = "rbxassetid://94978851787238"
local SWISH = "rbxassetid://9120715547" -- Pro Sound Effects: fast whoosh by
-- PASS 21E REAL FOLEY: physical things sound like the physical thing (Pro Sound Effects recordings), the way popular simulators do it:
-- a solid wood thump for crates, a ringing I-beam strike for beams, clanking steel for weights, a machine spin-up for treadmills and
-- build power-ups. Only the reward pings (coin) and tiny UI ticks stay clean and bright.
local WOOD = "rbxassetid://9113769181" -- big solid wood drop
local WOOD2 = "rbxassetid://9113769774" -- big solid wood drop (lighter, for pickups)
local IBEAM = "rbxassetid://9125670743" -- sledge hit on an I-beam, metal ring
local STEELRING = "rbxassetid://9125672562" -- sledge hit on an I-beam, shorter (bright construction accent)
local CLANKS = "rbxassetid://9116541944" -- metal clanks, hollow pipe hits
local MOTOR = "rbxassetid://9116921176" -- machine starting up, winding up (cut short with Max)
-- PASS 21L real recordings per task (Pro Sound Effects) + suspense for the reveal (APM Music riser)
local LOGDROP = "rbxassetid://9120864383" -- wood poles dropping on dirt
local ROCKS = "rbxassetid://9113967022" -- crate of rocks tumbling / dropping
local RISER = "rbxassetid://1843490542" -- APM "Critical Mass" riser
local HEART = "rbxassetid://132163421525060" -- heartbeat (cut to one beat with Max)

SoundConfig.Sounds = {
	Pickup = { SoundId = "rbxassetid://4612375802", Volume = 0.25, Pitch = 1.1, Cooldown = 0.08, Max = 0.5 }, -- a light knock as it goes in the bag
	Full = { SoundId = "rbxassetid://2865228231", Volume = 0.4, Pitch = 0.9, Cooldown = 0.6 }, -- a heavy, stuffed thunk
	Deposit = { SoundId = WOOD, Volume = 0.55, Pitch = 1, Cooldown = 0.15, Max = 0.9 },
	-- delivered loads sound like the material landing on the build
	DepositWood = { SoundId = LOGDROP, Volume = 0.55, Pitch = 1, Cooldown = 0.15, Max = 0.9 },
	DepositStone = { SoundId = ROCKS, Volume = 0.6, Pitch = 1, Cooldown = 0.15, Max = 1.1 },
	DepositMetal = { SoundId = CLANKS, Volume = 0.5, Pitch = 0.9, Cooldown = 0.15, Max = 0.9 },
	DepositPower = { SoundId = "rbxassetid://9116276051", Volume = 0.3, Pitch = 0.9, Cooldown = 0.15 },
	RevealRiser = { SoundId = RISER, Volume = 0.55, Pitch = 1, Cooldown = 1, Max = 6.5 },
	Heartbeat = { SoundId = HEART, Volume = 0.7, Pitch = 0.85, Cooldown = 0.2, Max = 0.42 },
	StageComplete = { SoundId = "rbxassetid://1837829449", Volume = 0.5, Pitch = 1.2, Cooldown = 0.5, Max = 1.6 },
	PieceBuilt = { SoundId = "rbxassetid://9118588165", Volume = 0.3, Pitch = 1.1, Cooldown = 0.12 }, -- a small thunk as each piece snaps on
	RevealTick = { SoundId = "rbxassetid://4621722813", Volume = 0.55, Pitch = 1, Cooldown = 0.04 }, -- a dry mechanical tick
	RevealFinal = { SoundId = "rbxassetid://74149238738530", Volume = 0.8, Pitch = 1, Cooldown = 0.5 },
	Discovery = { SoundId = "rbxassetid://74216560469867", Volume = 0.6, Pitch = 1.3, Cooldown = 0.5, Max = 2 },
	EventStart = { SoundId = "rbxassetid://644569388", Volume = 0.5, Pitch = 1, Cooldown = 1 },
	Meteor = { SoundId = "rbxassetid://7423520828", Volume = 0.55, Pitch = 1, Cooldown = 0.1, Max = 3 },
	Complete = { SoundId = "rbxassetid://74216560469867", Volume = 0.8, Pitch = 0.95, Cooldown = 1 },
	Upgrade = { SoundId = "rbxassetid://7437419566", Volume = 0.5, Pitch = 1.25, Cooldown = 0.1 },
	Error = { SoundId = "rbxassetid://1388726556", Volume = 0.35, Pitch = 1, Cooldown = 0.3 },
	Click = { SoundId = "rbxassetid://6042053626", Volume = 0.45, Pitch = 1, Cooldown = 0.05 },
	-- reward feel (soft and short; rate-limited so repeated deposits never stack into noise)
	Coins = { SoundId = "rbxassetid://7437419566", Volume = 0.35, Pitch = 1, Cooldown = 0.35 },
	StrengthPickup = { SoundId = WOOD2, Volume = 0.55, Pitch = 1.25, Cooldown = 0.3 },
	StrengthDeliver = { SoundId = COIN, Volume = 0.5, Pitch = 0.9, Cooldown = 0.3 },
	PowerUp = { SoundId = "rbxassetid://9065783664", Volume = 0.5, Pitch = 1.1, Cooldown = 0.5 },
	-- PRESENTATION PASS (Creator Store sound effects from Roblox's licensed Pro Sound Effects library; free to use in experiences)
	-- gathering: one short, quiet material hit per pickup
	GatherWood = { SoundId = "rbxassetid://9120808574", Volume = 0.32, Pitch = 1.1, Cooldown = 0.12 },
	GatherStone = { SoundId = "rbxassetid://9118608146", Volume = 0.3, Pitch = 1.05, Cooldown = 0.12 },
	GatherMetal = { SoundId = "rbxassetid://9125782644", Volume = 0.16, Pitch = 1.35, Cooldown = 0.12 },
	GatherPower = { SoundId = "rbxassetid://9116275998", Volume = 0.12, Pitch = 1.7, Cooldown = 0.12 },
	GatherCosmic = { SoundId = "rbxassetid://9125782020", Volume = 0.26, Pitch = 0.75, Cooldown = 0.15 },
	-- accents
	Chime = { SoundId = "rbxassetid://9116163448", Volume = 0.35, Pitch = 1, Cooldown = 0.2 },
	ChimeLow = { SoundId = "rbxassetid://9116163448", Volume = 0.4, Pitch = 0.62, Cooldown = 0.2 },
	Rumble = { SoundId = "rbxassetid://9113221411", Volume = 0.45, Pitch = 1, Cooldown = 1.5 },
	Thud = { SoundId = "rbxassetid://9118588165", Volume = 0.4, Pitch = 0.8, Cooldown = 0.2 },
	Zap = { SoundId = "rbxassetid://8060079174", Volume = 0.25, Pitch = 1.1, Cooldown = 0.3, Max = 1.2 },
	Cheer = { SoundId = "rbxassetid://9120974507", Volume = 0.22, Pitch = 1, Cooldown = 4 },
	Boom = { SoundId = "rbxassetid://9125401975", Volume = 0.55, Pitch = 0.9, Cooldown = 0.15, Max = 2.5 },
	-- PASS 16A core cues. PLACEHOLDER assets: they reuse the sounds above/built-ins; swap SoundId here later, no gameplay code changes.
	MenuOpen = { SoundId = "rbxassetid://6698736600", Volume = 0.35, Pitch = 1, Cooldown = 0.1, Max = 0.8 },
	MenuClose = { SoundId = "rbxassetid://6698737249", Volume = 0.3, Pitch = 1, Cooldown = 0.1, Max = 0.8 },
	RewardClaim = { SoundId = "rbxassetid://7437419566", Volume = 0.55, Pitch = 1.1, Cooldown = 0.3 },
	Glitch = { SoundId = "rbxassetid://9116276051", Volume = 0.35, Pitch = 0.45, Cooldown = 0.3 }, -- Forgotten "wrong system" interruption
	-- PASS 21D TRAINING CUES: each activity has its own sound (a springy lift, a heavy set-down, a coin cascade for the payoff)
	Ping = { SoundId = "rbxassetid://3807887510", Volume = 0.4, Pitch = 1, Cooldown = 0.05 }, -- uncapped coin ping for cascades
	Whoosh2 = { SoundId = SWISH, Volume = 0.4, Pitch = 1, Cooldown = 0.2 },
	Clank = { SoundId = CLANKS, Volume = 0.45, Pitch = 1.2, Cooldown = 0.12, Max = 1.1 },
	WoodThump = { SoundId = WOOD, Volume = 0.8, Pitch = 1, Cooldown = 0.15, Max = 1.2 },
	BeamStrike = { SoundId = IBEAM, Volume = 0.7, Pitch = 1, Cooldown = 0.2, Max = 1.6 },
	Motor = { SoundId = MOTOR, Volume = 0.5, Pitch = 1.5, Cooldown = 0.3, Max = 1.7 },
	TreadTick = { SoundId = COIN, Volume = 0.26, Pitch = 1, Cooldown = 0.3 }, -- every XP tick on a treadmill (pitch rises with the level)
	BenchRep = { SoundId = CLANKS, Volume = 0.3, Pitch = 1.7, Cooldown = 0.3, Max = 0.7 },
	GateTick = { SoundId = COIN, Volume = 0.22, Pitch = 1.5, Cooldown = 0.1 },
	DepositHeavy = { SoundId = "rbxassetid://9118588165", Volume = 0.45, Pitch = 0.6, Cooldown = 0.4 },
} :: { [string]: SoundDef }

-- LAYERED CUES (PASS 16A): { sound, volume multiplier, pitch multiplier, delay seconds }. Staggered delays keep layers from landing on the
-- same instant. Rarity scaling = the same few layers added level by level (Common 1 .. Mythic 6), Forgotten is its own low/ancient set.
SoundConfig.RarityLevel = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Forgotten = 7, Hidden = 6 }
SoundConfig.Cues = {
	Stage = { { "Thud", 0.9, 0.85, 0 }, { "StageComplete", 0.9, 1, 0.03 }, { "Chime", 0.7, 1.1, 0.2 } },
	Wake = { { "Rumble", 0.7, 1.1, 0 }, { "Zap", 1, 0.8, 0.15 }, { "PowerUp", 0.8, 1, 0.3 } },
	Glitch = { { "Glitch", 1, 1, 0 }, { "Error", 0.7, 0.45, 0.07 }, { "Zap", 0.8, 0.5, 0.15 } },
	TreadStart = { { "Motor", 0.6, 1.5, 0 }, { "Whoosh2", 0.25, 1.4, 0.12 } },
	TreadStop = { { "Motor", 0.35, 0.8, 0 } },
	CrateLift = { { "StrengthPickup", 0.9, 1.0, 0 }, { "Thud", 0.45, 1.2, 0.03 } },
	CrateDrop = { { "WoodThump", 1, 0.85, 0 }, { "Thud", 0.7, 0.9, 0.02 }, { "Ping", 0.9, 1.0, 0.14 }, { "Ping", 0.8, 1.3, 0.22 } },
	BeamLift = { { "Clank", 0.75, 1.3, 0 }, { "Thud", 0.4, 1.3, 0.04 } },
	BeamDrop = { { "BeamStrike", 1, 1.0, 0 }, { "Thud", 0.9, 0.65, 0.03 }, { "Ping", 0.9, 1.0, 0.16 }, { "Ping", 0.8, 1.3, 0.24 } },
	LapDone = { { "Ping", 1, 1.0, 0 }, { "Ping", 1, 1.25, 0.1 }, { "Chime", 0.8, 1.2, 0.2 } },
	ForgottenDiscover = { { "Boom", 0.8, 0.55, 0 }, { "ChimeLow", 1, 0.8, 0.12 }, { "Discovery", 0.6, 0.85, 0.3 } },
}
-- completion layers added per level (cumulative)
SoundConfig.CompleteLayers = {
	{ { "Complete", 0.7, 1.2, 0 } },
	{ { "Chime", 0.6, 1.0, 0.15 } },
	{ { "Cheer", 1, 1, 0.1 }, { "Chime", 0.6, 1.25, 0.3 } },
	{ { "Boom", 0.6, 0.9, 0.05 }, { "Chime", 0.7, 0.9, 0.4 } },
	{ { "Discovery", 0.8, 1, 0.2 }, { "ChimeLow", 0.9, 1, 0.45 } },
	{ { "Boom", 0.8, 0.75, 0 }, { "Rumble", 0.9, 0.9, 0.1 }, { "Cheer", 1, 0.9, 0.6 } },
}
SoundConfig.ForgottenComplete = { { "Boom", 0.7, 0.55, 0 }, { "Rumble", 0.9, 0.7, 0.1 }, { "ChimeLow", 1, 0.62, 0.5 }, { "Discovery", 0.6, 0.8, 0.9 } }

-- AMBIENT BEDS: looping, spatial (3D) beds the AmbienceController hangs on the world. Volumes are LOW on purpose; RollOff keeps
-- each landmark local (you hear it as you approach and it is gone a short walk away).
export type AmbientDef = { SoundId: string, Volume: number, Pitch: number, Min: number, Max: number }
SoundConfig.Ambient = {
	-- (Pass 21Q) louder and wider so the world actually has a sound: a steady 2D bed everywhere, busy site sounds at spawn, and a clear bed per zone
	Breeze = { SoundId = "rbxassetid://9116258282", Volume = 0.3, Pitch = 1, Min = 0, Max = 0 }, -- 2D bed everywhere
	HubBirds = { SoundId = "rbxassetid://9112835068", Volume = 0.28, Pitch = 1, Min = 60, Max = 260 },
	Site = { SoundId = "rbxassetid://9112839293", Volume = 0.22, Pitch = 1.15, Min = 50, Max = 240 }, -- distant site machinery around the spawn plaza (only older audio ids load here)
	Forest = { SoundId = "rbxassetid://9116258071", Volume = 0.5, Pitch = 1, Min = 35, Max = 160 },
	Redwood = { SoundId = "rbxassetid://9112806209", Volume = 0.45, Pitch = 0.92, Min = 40, Max = 180 },
	Wind = { SoundId = "rbxassetid://9116258282", Volume = 0.45, Pitch = 0.72, Min = 35, Max = 170 },
	Industrial = { SoundId = "rbxassetid://9112839293", Volume = 0.42, Pitch = 0.9, Min = 30, Max = 150 },
	Hum = { SoundId = "rbxassetid://9112889082", Volume = 0.3, Pitch = 1, Min = 25, Max = 120 },
	Reactor = { SoundId = "rbxassetid://9116386858", Volume = 0.42, Pitch = 0.9, Min = 30, Max = 150 },
	Cosmic = { SoundId = "rbxassetid://9119462099", Volume = 0.38, Pitch = 0.55, Min = 30, Max = 130 },
	Grove = { SoundId = "rbxassetid://9112806209", Volume = 0.45, Pitch = 0.8, Min = 30, Max = 130 },
} :: { [string]: AmbientDef }

return SoundConfig
