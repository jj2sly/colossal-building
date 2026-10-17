--!strict
-- COLOSSAL SCALE: the single source of truth for how big builds sit on the central site.
--
--   * BUILD ORIGIN. Every build definition places its model relative to ONE local origin: the centre of the deck, on the
--     deck surface, facing the spawn. Authors model a build with its base at Y = 0 and its front toward -Z (as before);
--     BuildService pivots the template to ColossalConfig.OriginCFrame() (plus an optional per-build `Offset` / `Yaw`).
--   * PLATFORM. The deck and collar radii live here; WorldBuilderColossal reads them, the deposit ring, the barrier and
--     every client effect radius are derived from them, so growing the site is one number.
--   * ENVELOPES. Flexible per-rarity footprint/height targets (studs, at final in-world scale) for authoring and checks.
--   * PARTIAL ACTIVATION. A build may "come alive" before it is complete (lights, motion, a mechanic). The activation
--     point is a progress fraction picked per rarity (or `def.ActivateAt`); BuildService fires it once per build.
--   * SPECTACLE WINDOW. How long a completion show may run per rarity; the round waits for it before resetting.
--
-- Rarities that do not exist yet (Forgotten) are listed so future builds can use them without touching this file.
local ColossalConfig = {}

ColossalConfig.Site = {
	Center = Vector3.new(0, 0, 0),
	DeckTopY = 2, -- build bases sit on this height (matches GameConfig.Site.PlatformTopY)
	FacingYaw = 180, -- templates face -Z; turn them so their front faces the spawn (south)
	-- usable build footprint (players are kept outside it) and the structural collar around it
	DeckRadius = 90,
	CollarRadius = 104, -- the sloped skirt reaches the ground at CollarRadius + 2 (a 212-stud structure overall)
	-- the invisible barrier stands at the deck rim; players and vehicles stop on the collar outside it
	BarrierRadius = 90.5,
	-- deposits count inside this radius. It must reach a Dump Truck driver whose bumper touches the barrier (~11 studs
	-- back). Tier 1 zones were moved out by ~45 (DepositRadius - 58, the original edge) so their walks are unchanged.
	DepositRadius = 103,
}

-- Flexible size envelopes per rarity: { footprint min, footprint max, height min, height max } in studs.
-- Horizontal builds may be longer and lower; the footprint may overhang the deck at height.
ColossalConfig.Envelopes = {
	Common = { 55, 85, 45, 75 },
	Uncommon = { 70, 105, 60, 95 },
	Rare = { 90, 130, 80, 125 },
	Epic = { 110, 150, 105, 165 },
	Legendary = { 130, 175, 135, 210 },
	Mythic = { 150, 200, 170, 260 },
	Forgotten = { 170, 230, 200, 320 },
}

-- Partial activation: progress fraction range per rarity; a build uses the middle unless it sets `ActivateAt`.
ColossalConfig.Activation = {
	Common = { 0.70, 0.80 },
	Uncommon = { 0.60, 0.70 },
	Rare = { 0.50, 0.60 },
	Epic = { 0.40, 0.50 },
	Legendary = { 0.35, 0.45 },
	Mythic = { 0.30, 0.40 },
	Forgotten = { 0.20, 0.30 },
}

-- Completion spectacle window per rarity (seconds): { min, max }.
ColossalConfig.Spectacle = {
	Common = { 3, 5 },
	Uncommon = { 4, 6 },
	Rare = { 5, 7 },
	Epic = { 7, 10 },
	Legendary = { 10, 13 },
	Mythic = { 12, 16 },
	Forgotten = { 15, 20 },
}

-- Seconds the site takes to clear a finished build (fade on clients); bigger builds clear a little slower.
ColossalConfig.ResetFade = {
	Common = 2,
	Uncommon = 2,
	Rare = 2.5,
	Epic = 3,
	Legendary = 3.5,
	Mythic = 4,
	Forgotten = 5,
}

-- The local build origin: the deck centre on the deck surface, facing the spawn.
function ColossalConfig.OriginCFrame(): CFrame
	local s = ColossalConfig.Site
	return CFrame.new(s.Center.X, s.DeckTopY, s.Center.Z) * CFrame.Angles(0, math.rad(s.FacingYaw), 0)
end

-- Where a given build definition is placed: the origin plus its optional local Offset (Vector3, origin space) and Yaw
-- (degrees, extra turn) so long horizontal builds can be aimed or shifted without touching the template.
function ColossalConfig.PlacementFor(def: any): CFrame
	local cf = ColossalConfig.OriginCFrame()
	if def and def.Offset then
		cf *= CFrame.new(def.Offset)
	end
	if def and def.Yaw then
		cf *= CFrame.Angles(0, math.rad(def.Yaw), 0)
	end
	return cf
end

function ColossalConfig.ActivationFraction(def: any): number?
	if not def then
		return nil
	end
	if def.ActivateAt == false then
		return nil
	end
	if type(def.ActivateAt) == "number" then
		return math.clamp(def.ActivateAt, 0.05, 1)
	end
	local r = ColossalConfig.Activation[def.Rarity or "Common"] or ColossalConfig.Activation.Common
	return (r[1] + r[2]) / 2
end

-- How long the completion show for this build may run: its own spectacle duration clamped to the rarity window,
-- or the window's minimum when it has none (a short settle beat).
function ColossalConfig.SpectacleSeconds(def: any, spectacleDuration: number?): number
	if def and def.SpectacleSeconds then
		return def.SpectacleSeconds -- a build-specific override (a longer showpiece than its rarity window)
	end
	local w = ColossalConfig.Spectacle[(def and def.Rarity) or "Common"] or ColossalConfig.Spectacle.Common
	if spectacleDuration then
		return math.clamp(spectacleDuration, w[1], w[2])
	end
	return w[1]
end

function ColossalConfig.ResetSeconds(def: any): number
	return ColossalConfig.ResetFade[(def and def.Rarity) or "Common"] or 2
end

-- Radius for site-wide effects (reveal rings, completion bursts, stage dust) so they always reach past the build.
function ColossalConfig.FrameRadius(scale: number?): number
	return ColossalConfig.Site.CollarRadius * (scale or 1.4)
end

return ColossalConfig
