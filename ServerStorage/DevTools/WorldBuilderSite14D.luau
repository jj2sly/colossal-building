--!nonstrict
-- EDIT-TIME helper (Pass 14D, not used at runtime): build-site presentation polish. Runs LAST in WorldBuilder.Build() (after
-- WorldBuilderColossal) and can also be run on its own:  require(game.ServerStorage.DevTools.WorldBuilderSite14D:Clone())({ world = workspace.World })
-- Idempotent: everything it adds lives in World.SitePolish (rebuilt every run); the old Art4 crane / silo parts are replaced.
-- Nothing functional moves: deck, collar, deposit ring, barrier, spawn, roads and zones keep their geometry and radii.
--   * deck composition: a darker core disc, four diagonal construction seams, four inset anchor plates (flush, non-colliding)
--   * rim beats: heavy concrete bastions straddling the skirt at the existing footing angles (never on a road or a sector gap)
--   * site crane: a heavy tower crane (lattice-read mast, ballast base, cab, counter-jib, load) at the same foot, its jib swung
--     out along the site edge so it frames the projects without ever entering their space
--   * silo cluster: two heavier silos on one shared base and frame, a transfer housing and one feed chute toward the site
--   * site pylons: the four existing pylons become heavier, taller masts (same spots)
return function(ctx)
	local V, M = Vector3.new, Enum.Material
	local world = ctx.world or workspace:FindFirstChild("World")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ColossalConfig = require(ReplicatedStorage.Shared.Config.ColossalConfig)
	local S = ColossalConfig.Site
	local C = S.Center
	local TOP = S.DeckTopY
	local DECK, COLLAR = S.DeckRadius, S.CollarRadius
	local SKIRT_OUT = COLLAR + 2

	local COL = {
		DarkSteel = Color3.fromRGB(58, 62, 72),
		Steel = Color3.fromRGB(96, 102, 114),
		Amber = Color3.fromRGB(196, 132, 52),
		Concrete = Color3.fromRGB(128, 124, 118),
		DarkConcrete = Color3.fromRGB(98, 96, 92),
		Seam = Color3.fromRGB(92, 96, 104),
		Core = Color3.fromRGB(126, 128, 134),
		Plate = Color3.fromRGB(78, 82, 92),
		Silo = Color3.fromRGB(196, 190, 176),
		Glass = Color3.fromRGB(40, 52, 64),
	}

	local old = world:FindFirstChild("SitePolish")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "SitePolish"
	root.Parent = world
	local added = 0
	local function folder(name: string): Folder
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = root
		return f
	end
	local function B(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, collide: boolean?): Part
		added += 1
		local p = Instance.new("Part")
		p.Name, p.Anchored, p.Size, p.CFrame, p.Color, p.Material = name, true, size, cf, color, mat or M.SmoothPlastic
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.CanCollide = collide ~= false
		if collide == false then
			p.CanQuery, p.CanTouch = false, false
		end
		p.Parent = parent
		return p
	end
	local function W(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material)
		added += 1
		local w = Instance.new("WedgePart")
		w.Name, w.Anchored, w.Size, w.CFrame, w.Color, w.Material = name, true, size, cf, color, mat
		w.TopSurface, w.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		w.Parent = parent
		return w
	end
	local function cyl(parent: Instance, name: string, d: number, h: number, cf: CFrame, color: Color3, mat: Enum.Material, collide: boolean?)
		local p = B(parent, name, V(h, d, d), cf * CFrame.Angles(0, 0, math.rad(90)), color, mat, collide)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	local function bar(parent: Instance, name: string, a: Vector3, b: Vector3, t: number, color: Color3, mat: Enum.Material?, collide: boolean?)
		return B(parent, name, V(t, t, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, mat or M.Metal, collide)
	end
	local function flat(p: Vector3): Vector3
		return V(p.X, 0, p.Z)
	end

	------------------------------------------------------------------- remove the old (Art4) crane and silo pair
	local hubFrame = world:FindFirstChild("Hub") and world.Hub:FindFirstChild("HubFrame")
	local removed = 0
	local craneFoot, siloBase = V(100, 0, 58), V(88, 0, 96)
	if hubFrame then
		for _, d in hubFrame:GetChildren() do
			if d:IsA("BasePart") and (string.sub(d.Name, 1, 5) == "Crane" or string.sub(d.Name, 1, 4) == "Silo") then
				if d.Name == "CraneFoot" then
					craneFoot = flat(d.Position)
				elseif d.Name == "SiloFrameBase" then
					siloBase = flat(d.Position)
				end
				d:Destroy()
				removed += 1
			end
		end
	end

	------------------------------------------------------------------- DECK COMPOSITION (flush, non-colliding, large forms only)
	local deckF = folder("Deck")
	local Y = TOP + 0.19 -- just above the work deck (top TOP + 0.16)
	cyl(deckF, "DeckCore", 62, 0.06, CFrame.new(C.X, Y, C.Z), COL.Core, M.Concrete, false)
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		local dir = V(math.cos(a), 0, math.sin(a))
		local p0, p1 = C + dir * 31, C + dir * (DECK - 12)
		B(deckF, "DeckSeam", V(1.8, 0.06, (p1 - p0).Magnitude), CFrame.lookAt((p0 + p1) / 2 + V(0, Y + 0.005, 0), p1 + V(0, Y + 0.005, 0)), COL.Seam, M.Slate, false)
	end
	for k = 0, 3 do
		local a = k * math.pi / 2
		local dir = V(math.cos(a), 0, math.sin(a))
		local p = C + dir * (DECK - 26)
		B(deckF, "AnchorPlate", V(16, 0.06, 16), CFrame.lookAt(p + V(0, Y + 0.004, 0), C + V(0, Y + 0.004, 0)), COL.Plate, M.DiamondPlate, false)
	end

	------------------------------------------------------------------- RIM BEATS: bastions at the existing footing angles
	local rimF = folder("Rim")
	local roads = {}
	local paths = world:FindFirstChild("Paths")
	if paths then
		for _, d in paths:GetChildren() do
			if d:IsA("BasePart") and (d.Name == "RoadBody" or d.Name == "RoadShoulder" or d.Name == "RoadRamp") then
				table.insert(roads, d)
			end
		end
	end
	local function nearRoad(p: Vector3, r: number): boolean
		for _, d in roads do
			local lp = d.CFrame:PointToObjectSpace(V(p.X, d.Position.Y, p.Z))
			if math.abs(lp.X) < d.Size.X / 2 + r and math.abs(lp.Z) < d.Size.Z / 2 + r then
				return true
			end
		end
		return false
	end
	local SPAWN = V(0, 0, 104)
	local function openSector(p: Vector3): boolean
		return (flat(p) - SPAWN).Magnitude < 40 or (p.X > -170 and p.X < -54 and p.Z > 58 and p.Z < 198)
	end
	local footings = {}
	local site = world:FindFirstChild("BuildSite")
	if site then
		for _, d in site:GetChildren() do
			if d:IsA("BasePart") and d.Name == "Footing" then
				table.insert(footings, flat(d.Position))
			end
		end
	end
	local bastions = 0
	for _, fp in footings do
		local dir = (fp - flat(C)).Unit
		local mid = flat(C) + dir * (SKIRT_OUT - 0.5)
		if not openSector(mid) and not nearRoad(mid, 6) then
			local cf = CFrame.lookAt(mid, flat(C)) -- -Z points at the centre
			-- low and heavy: body straddling the skirt foot, a sloped outer buttress onto the footing, a steel cap plate. Kept
			-- under 5.2 studs so builds with wide base slabs (Colosseum) cover it instead of being pierced by it.
			local g = Instance.new("Model")
			g.Name = "Bastion"
			g.Parent = rimF
			B(g, "BastionBody", V(9, 4.4, 8), cf * CFrame.new(0, 2.2, 0), COL.DarkConcrete, M.Concrete)
			W(g, "BastionButtress", V(9, 4.4, 6), cf * CFrame.new(0, 2.2, 7) * CFrame.Angles(0, math.pi, 0), COL.Concrete, M.Concrete) -- wedges are tall at +Z: turn so the tall side meets the bastion
			B(g, "BastionCap", V(9.6, 0.8, 8.6), cf * CFrame.new(0, 4.8, 0), COL.DarkSteel, M.DiamondPlate)
			-- never on a road, a pylon or the Training Yard slabs (checked against the real parts)
			local params = OverlapParams.new()
			params.FilterDescendantsInstances = { root, workspace.Terrain }
			params.FilterType = Enum.RaycastFilterType.Exclude
			local blocked = false
			for _, p in g:GetChildren() do
				for _, h in workspace:GetPartsInPart(p, params) do
					if h.Name == "RoadBody" or h.Name == "RoadShoulder" or h.Name == "RoadRamp" or h.Name == "PylonColumn" or h.Name == "WorkSlab" or h.Name == "Dash" then
						blocked = true
					end
				end
			end
			if blocked then
				added -= 3
				g:Destroy()
			else
				bastions += 1
			end
		end
	end

	-- the four existing site pylons (on footings at the skirt foot) become heavier masts: same spots, absolute sizes (idempotent)
	if site then
		for _, d in site:GetChildren() do
			if d:IsA("BasePart") and d.Name == "PylonColumn" then
				local base = flat(d.Position)
				d.Size = V(5, 24, 5)
				d.CFrame = CFrame.new(base + V(0, 15, 0)) * d.CFrame.Rotation
			elseif d:IsA("BasePart") and d.Name == "PylonCap" then
				local base = flat(d.Position)
				d.Size = V(6.4, 1.6, 6.4)
				d.CFrame = CFrame.new(base + V(0, 27.8, 0)) * d.CFrame.Rotation
			end
		end
	end

	------------------------------------------------------------------- SITE CRANE (same foot, heavier, jib swung out along the edge)
	local craneF = folder("Crane")
	local cb = craneFoot
	local toC = (flat(C) - cb).Unit
	-- jib runs along the site edge (tangent), turned slightly outward: it frames the projects, never enters their space
	local tangent = V(-toC.Z, 0, toC.X)
	if tangent:Dot(V(0, 0, 1)) > 0 then
		tangent = -tangent -- swing it away from the spawn side so the jib reads side-on from spawn
	end
	local jibDir = (tangent * 0.9 - toC * 0.44).Unit
	local MAST_TOP = 72
	B(craneF, "CraneBase", V(16, 3, 16), CFrame.new(cb + V(0, 1.5, 0)), COL.DarkConcrete, M.Concrete)
	B(craneF, "CraneBallast", V(10, 3, 10), CFrame.new(cb + V(0, 4.5, 0)), COL.DarkSteel, M.Metal)
	-- mast: dark core + four amber corner chords + three collars (reads as a heavy lattice tower with very few parts)
	local mh = MAST_TOP - 6
	B(craneF, "CraneMastCore", V(4.4, mh, 4.4), CFrame.new(cb + V(0, 6 + mh / 2, 0)), COL.DarkSteel, M.Metal)
	for _, o in { V(2.6, 0, 2.6), V(-2.6, 0, 2.6), V(2.6, 0, -2.6), V(-2.6, 0, -2.6) } do
		B(craneF, "CraneChord", V(1.4, mh, 1.4), CFrame.new(cb + o + V(0, 6 + mh / 2, 0)), COL.Amber, M.Metal)
	end
	for _, y in { 24, 44, 64 } do
		B(craneF, "CraneCollar", V(7, 1.2, 7), CFrame.new(cb + V(0, y, 0)), COL.Amber, M.Metal)
	end
	local top = cb + V(0, MAST_TOP, 0)
	B(craneF, "CraneSlew", V(8, 3, 8), CFrame.lookAt(top + V(0, 1.5, 0), top + V(0, 1.5, 0) + jibDir), COL.DarkSteel, M.Metal)
	local cabC = top + V(0, 1.2, 0) + jibDir * 5 + V(-jibDir.Z, 0, jibDir.X) * 4.6
	B(craneF, "CraneCab", V(4.4, 4.6, 6), CFrame.lookAt(cabC, cabC + jibDir), COL.Amber, M.Metal)
	B(craneF, "CraneCabGlass", V(4.6, 1.8, 0.4), CFrame.lookAt(cabC + jibDir * 3.05 + V(0, 0.8, 0), cabC + jibDir * 4 + V(0, 0.8, 0)), COL.Glass, M.Glass)
	local jy = MAST_TOP + 4.4
	local jibA, jibB = top + V(0, 4.4, 0) - jibDir * 20, top + V(0, 4.4, 0) + jibDir * 56
	bar(craneF, "CraneJib", top + V(0, 4.4, 0), jibB, 3.4, COL.Amber)
	bar(craneF, "CraneJibChord", top + V(0, 1.6, 0) + jibDir * 4, top + V(0, 3.4, 0) + jibDir * 44, 1.6, COL.Amber)
	bar(craneF, "CraneCounterJib", jibA, top + V(0, 4.4, 0), 3.4, COL.Amber)
	B(craneF, "CraneCounterweight", V(9, 7, 6), CFrame.lookAt(jibA + jibDir * 4 + V(0, -3, 0), jibA + jibDir * 5 + V(0, -3, 0)), COL.DarkConcrete, M.Concrete)
	local apex = top + V(0, 18, 0)
	B(craneF, "CraneApex", V(3, 14, 3), CFrame.new(top + V(0, 11, 0)), COL.Amber, M.Metal)
	bar(craneF, "CranePendant", apex, jibB + V(0, 1.6, 0), 0.5, COL.DarkSteel, M.Metal, false)
	bar(craneF, "CranePendant", apex, jibA + V(0, 1.6, 0), 0.5, COL.DarkSteel, M.Metal, false)
	local hook = top + V(0, 4.4, 0) + jibDir * 40
	B(craneF, "CraneTrolley", V(4, 2, 4), CFrame.lookAt(hook + V(0, -2.6, 0), hook + V(0, -2.6, 0) + jibDir), COL.DarkSteel, M.Metal, false)
	bar(craneF, "CraneCable", hook + V(0, -3.6, 0), hook + V(0, -40, 0), 0.4, Color3.fromRGB(36, 36, 42), M.Metal, false)
	B(craneF, "CraneHook", V(2.6, 3.2, 2.6), CFrame.new(hook + V(0, -41.6, 0)), COL.Amber, M.Metal, false)
	B(craneF, "CraneLoad", V(18, 2.4, 3.2), CFrame.new(hook + V(0, -45, 0)) * CFrame.Angles(0, math.atan2(jibDir.X, jibDir.Z) + 0.5, 0), COL.Steel, M.Metal, false)

	------------------------------------------------------------------- SILO CLUSTER (one base, one frame, one transfer housing)
	local siloF = folder("Silos")
	local sb = siloBase
	B(siloF, "SiloBase", V(32, 2, 18), CFrame.new(sb + V(0, 1, 0)), COL.DarkConcrete, M.Concrete)
	for _, sx in { -8, 8 } do
		for _, sz in { -5.5, 5.5 } do
			B(siloF, "SiloLeg", V(2, 13, 2), CFrame.new(sb + V(sx + (if sx > 0 then 4.6 else -4.6), 8.5, sz)), COL.DarkSteel, M.Metal)
		end
		cyl(siloF, "Silo", 12, 24, CFrame.new(sb + V(sx, 27, 0)), COL.Silo, M.Concrete)
		local cone = Instance.new("Part")
		cone.Name, cone.Anchored, cone.Shape = "SiloCone", true, Enum.PartType.Ball
		cone.Size, cone.CFrame, cone.Color, cone.Material = V(12, 12, 12), CFrame.new(sb + V(sx, 15, 0)), Color3.fromRGB(170, 164, 150), M.Concrete
		cone.Parent = siloF
		added += 1
		cyl(siloF, "SiloBand", 12.5, 1.6, CFrame.new(sb + V(sx, 33, 0)), COL.Amber, M.Metal)
		cyl(siloF, "SiloCap", 9, 2, CFrame.new(sb + V(sx, 40, 0)), COL.DarkSteel, M.Metal)
	end
	-- one steel frame girder across both silo skirts and one transfer housing across the tops
	B(siloF, "SiloGirder", V(30, 2.2, 2.2), CFrame.new(sb + V(0, 15, -5.5)), COL.DarkSteel, M.Metal)
	B(siloF, "SiloGirder", V(30, 2.2, 2.2), CFrame.new(sb + V(0, 15, 5.5)), COL.DarkSteel, M.Metal)
	B(siloF, "SiloHousing", V(10, 6, 7), CFrame.new(sb + V(0, 40, 0)), COL.DarkSteel, M.Metal)
	B(siloF, "SiloHousingRoof", V(11, 1, 8), CFrame.new(sb + V(0, 43.5, 0)), COL.Amber, M.Metal)
	-- one feed chute from the housing down toward the site skirt
	local toSite = (flat(C) - sb).Unit
	local chuteA, chuteB = sb + V(0, 39, 0) + toSite * 4, sb + V(0, 8, 0) + toSite * 26
	bar(siloF, "SiloChute", chuteA, chuteB, 2.6, COL.Steel, M.Metal)
	B(siloF, "SiloChuteFoot", V(5, 6, 5), CFrame.new(chuteB + V(0, -3, 0)), COL.DarkSteel, M.Metal)

	-- (no entrance piers: every candidate spot at the spawn walk-in sits under the Colosseum's base slab, which overhangs the
	-- collar there. The walk-in keeps its clean gap.)

	return string.format("site polish: %d parts added, %d old crane/silo parts replaced, %d bastions", added, removed, bastions)
end
