--!strict
-- BALANCE v0.1 - Transport vehicles. A vehicle is "worn" by the player (welded, massless) so it never
-- fights character physics; it multiplies carry capacity and sets travel speed but the player still
-- gathers and delivers. Roles: Wheelbarrow = cheap early haul, HandCart / UtilityCart = steady
-- upgrades, Pickup = the fast one, Dump Truck = slower but by far the biggest bulk hauler.
--
--   Speed             studs/second while using the vehicle (before the training share below)
--   CargoMultiplier   multiplies Strength-based carry capacity (then the Vehicle Capacity upgrade)
export type Vehicle = {
	Id: string,
	DisplayName: string,
	Description: string,
	Order: number,
	Price: number,
	Speed: number,
	CargoMultiplier: number,
	SpeedShare: number?, -- share of the trained Speed bonus this vehicle inherits (VehicleConfig.SpeedTrainingShare if nil)
	Builder: string, -- visual builder id in VehicleService
	Accel: number, -- studs/s^2 while throttle is held
	Brake: number, -- studs/s^2 when braking / reversing direction
	Turn: number, -- steering rate (radians/second) at speed
	Master: boolean?, -- a Master Builder reward: never purchasable, owned through PlayerData.MasterBuilder.Vehicles (survives prestige)
	MasterRank: number?,
}

local VehicleConfig = {}

-- How much of the trained Speed bonus (above 16) still applies on a vehicle: 0.5 keeps Speed
-- training worth having while leaving vehicles as the answer to heavy logistics.
-- SPEED: vehicle top speed = Speed + SpeedShare x (your trained walk speed - 18). Walking runs 18 -> 37 over Speed 0-100.
--   Wheelbarrow 20 -> 26.7   cargo tool, barely faster than walking early, slower than a trained runner later
--   Hand Cart   24 -> 33.5   a clear early transport upgrade
--   UtilityCart 28 -> 42.3   always faster than running
--   Pickup      34 -> 51.1   the fast all-rounder, comfortably beats a max-level runner (37)
--   Dump Truck  29 -> 43.3   slower than the Pickup, still faster than running; its point is the 6x cargo
-- (Dump Truck cargo 7x -> 6x: at Strength 100 it still hauls ~670 per trip, which is already enormous.)
VehicleConfig.SpeedTrainingShare = 0.35 -- default share for a vehicle without its own SpeedShare

-- Reverse top speed as a fraction of forward MaxSpeed.
VehicleConfig.ReverseFactor = 0.4

VehicleConfig.Vehicles = {
	Wheelbarrow = {
		Id = "Wheelbarrow", DisplayName = "Wheelbarrow", Order = 1,
		Description = "A cheap, trusty wheelbarrow. Carries 1.5x.",
		Price = 75, Speed = 20, SpeedShare = 0.35, CargoMultiplier = 1.5,
		Builder = "Wheelbarrow",
		Accel = 34, Brake = 60, Turn = 1.7,
	},
	HandCart = {
		Id = "HandCart", DisplayName = "Hand Cart", Order = 2,
		Description = "A sturdy two-wheeled cart. Carries 2x and rolls a little faster.",
		Price = 350, Speed = 24, SpeedShare = 0.5, CargoMultiplier = 2,
		Builder = "HandCart",
		Accel = 30, Brake = 55, Turn = 1.5,
	},
	UtilityCart = {
		Id = "UtilityCart", DisplayName = "Utility Cart", Order = 3,
		Description = "A motorized cart. Carries 3x at a good clip.",
		Price = 1500, Speed = 28, SpeedShare = 0.75, CargoMultiplier = 3,
		Builder = "UtilityCart",
		Accel = 26, Brake = 50, Turn = 1.35,
	},
	Pickup = {
		Id = "Pickup", DisplayName = "Pickup", Order = 4,
		Description = "The fast hauler. Carries 4.5x and is the quickest vehicle.",
		Price = 6000, Speed = 34, SpeedShare = 0.9, CargoMultiplier = 4.5,
		Builder = "Pickup",
		Accel = 40, Brake = 70, Turn = 1.4,
	},
	DumpTruck = {
		Id = "DumpTruck", DisplayName = "Dump Truck", Order = 5,
		Description = "Slower than the pickup, but carries a huge 7x load. Built for bulk.",
		Price = 18000, Speed = 29, SpeedShare = 0.75, CargoMultiplier = 6,
		Builder = "DumpTruck",
		Accel = 14, Brake = 40, Turn = 1.0,
	},
	-- MASTER BUILDER VEHICLE 1 (rank 1, permanent, not for sale). Nimble: between the Utility Cart and the Pickup in speed
	-- (31 at Speed 0 -> 46 at Speed 100), 3.5x cargo, quicker to accelerate and tighter to turn than the Pickup.
	BuilderBuggy = {
		Id = "BuilderBuggy", DisplayName = "Builder Buggy", Order = 6,
		Description = "A nimble site buggy with a roll cage. Carries 3.5x and turns on a coin.",
		Price = 0, Speed = 31, SpeedShare = 0.79, CargoMultiplier = 3.5,
		Builder = "BuilderBuggy",
		Accel = 46, Brake = 72, Turn = 1.95,
		Master = true, MasterRank = 1,
	},
} :: { [string]: Vehicle }

return VehicleConfig
