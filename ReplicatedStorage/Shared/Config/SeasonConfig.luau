--!strict
-- LIMITED-TIME BUILDS and the LEGACY pool (FOUNDATION ONLY - no scheduling backend).
--
-- A build may name a Season in BuildConfig (`Season = "<id>"`). Season state decides where the build lives:
--   Active    the build is in the NORMAL pool for the event, and event-exclusive cosmetic drops
--             (DropConfig `EventSeason`) can roll.
--   Ended     the build moves to the LEGACY pool: it can still appear, but only through the small
--             post-event activation chance below. Event-exclusive cosmetics NEVER drop again.
--   Scheduled the build is not obtainable yet.
-- A build with no Season is a normal permanent build (always in the normal pool).
--
-- State can be forced by hand (`State`) or derived from StartsAt/EndsAt (os.time() seconds, optional).
-- To run an event: add a season here, give its builds `Season = "<id>"`, set State = "Active" (or dates).
-- To end it: set State = "Ended"; the builds fall into the Legacy pool automatically.
local SeasonConfig = {}

export type Season = {
	Id: string,
	DisplayName: string,
	State: string, -- "Scheduled" | "Active" | "Ended"
	StartsAt: number?,
	EndsAt: number?,
	ExclusiveDrops: { string }, -- DropConfig ids that only drop while Active
}

SeasonConfig.Seasons = {
	-- Example only (no build points at it yet). Delete or edit when a real event exists.
	-- WORKING EXAMPLE: the Lantern Festival. While State = "Active" its build (LanternTower) is in the normal pool and
	-- LanternTrail can drop; set State = "Ended" and the build moves to the Legacy pool (rare activation) while the
	-- trail stops dropping forever. Shipped as Ended so the Legacy path is live; flip it to Active to run the event.
	LanternFestival = { Id = "LanternFestival", DisplayName = "Lantern Festival", State = "Ended", ExclusiveDrops = { "LanternTrail" } },
} :: { [string]: Season }

-- LEGACY ACTIVATION: after a normal build completes there may be a small chance that the NEXT build is drawn
-- from the Legacy pool instead (only if the pool is not empty).
SeasonConfig.Legacy = {
	ActivationChance = 0.05, -- per build selection
	MinServerLuck = 0, -- gate behind Server Luck if wanted
}

function SeasonConfig.StateOf(seasonId: string?, now: number?): string
	if seasonId == nil then
		return "Active"
	end
	local s = SeasonConfig.Seasons[seasonId]
	if not s then
		return "Ended"
	end
	local t = now or os.time()
	if s.StartsAt and t < s.StartsAt then
		return "Scheduled"
	elseif s.EndsAt and t > s.EndsAt then
		return "Ended"
	end
	return s.State
end

-- "Normal" (in the regular pool), "Legacy" (event over), or "Unavailable" (not started).
function SeasonConfig.PoolOf(seasonId: string?, now: number?): string
	local st = SeasonConfig.StateOf(seasonId, now)
	if st == "Active" then
		return "Normal"
	elseif st == "Ended" then
		return "Legacy"
	end
	return "Unavailable"
end

return SeasonConfig
