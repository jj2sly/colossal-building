--!strict
-- Random server events. Each entry maps to a module in
-- ServerScriptService.Services.Events.<Module>. Set Enabled=false to switch an event
-- off without deleting it. Frequency = Interval (+ Weight between events).
export type EventDef = {
	Id: string,
	DisplayName: string,
	Description: string,
	Module: string,
	Weight: number,
	Duration: number, -- seconds the banner/effect lasts
	Kind: string, -- "Help" | "Hinder" | "Damage" (UI color)
	Icon: string, -- banner glyph
	Enabled: boolean,
	Params: { [string]: any },
}

local EventConfig = {}

-- Time between events while a build is under construction (seconds, random range).
EventConfig.Interval = { 80, 135 } -- seconds between events (random in range)
EventConfig.FirstEventDelay = 45 -- grace period after a build starts

EventConfig.Events = {
	MeteorShower = {
		Id = "MeteorShower", Icon = "☄", DisplayName = "METEOR SHOWER", Kind = "Damage",
		Description = "Repair any damaged sections!",
		Module = "MeteorShower", Weight = 30, Duration = 14, Enabled = true,
		Params = {
			WarningTime = 5,
			MeteorCount = 14,
			SectionsDamaged = { 1, 2 },
			RepairCostFraction = 0.12, -- of the build's per-stage cost, per damaged section
			MaxRepairUnits = 2500, -- before player scaling
		},
	},
	ResourceRush = {
		Id = "ResourceRush", Icon = "⚡", DisplayName = "RESOURCE RUSH", Kind = "Help",
		Description = "One zone: x2 yield and faster!",
		Module = "ResourceRush", Weight = 40, Duration = 45, Enabled = true,
		Params = { YieldMultiplier = 2, SpeedMultiplier = 1.5 },
	},
	DoubleCarry = {
		Id = "DoubleCarry", Icon = "🎒", DisplayName = "DOUBLE CARRY", Kind = "Help",
		Description = "Everyone carries twice as much!",
		Module = "DoubleCarry", Weight = 30, Duration = 50, Enabled = true,
		Params = { CapacityMultiplier = 2 },
	},
	Earthquake = {
		Id = "Earthquake", Icon = "🌋", DisplayName = "EARTHQUAKE", Kind = "Damage",
		Description = "Sections are cracking. Repair them!",
		Module = "Earthquake", Weight = 14, Duration = 10, Enabled = true,
		Params = {
			WarningTime = 4,
			SectionsDamaged = { 2, 3 },
			RepairCostFraction = 0.08, -- cheaper per section than meteors (it hits more)
			MaxRepairUnits = 1800,
		},
	},
	GoldenHour = {
		Id = "GoldenHour", Icon = "🌟", DisplayName = "GOLDEN HOUR", Kind = "Help",
		Description = "Deliveries pay double Coins!",
		Module = "GoldenHour", Weight = 18, Duration = 45, Enabled = true,
		Params = { CoinMultiplier = 2 },
	},
	WorkerStrike = {
		Id = "WorkerStrike", Icon = "✋", DisplayName = "WORKER STRIKE", Kind = "Hinder",
		Description = "Workers on break. Haul it yourself!",
		Module = "WorkerStrike", Weight = 12, Duration = 30, Enabled = true,
		Params = {},
	},
	BuildFrenzy = {
		Id = "BuildFrenzy", Icon = "🔥", DisplayName = "BUILD FRENZY", Kind = "Help",
		Description = "Deliveries count +50% to the build!",
		Module = "BuildFrenzy", Weight = 18, Duration = 35, Enabled = true,
		Params = { ConstructionMultiplier = 1.5, DepositSpeedMultiplier = 1.5 },
	},
} :: { [string]: EventDef }

return EventConfig
