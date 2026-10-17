--!nonstrict
-- EDIT-TIME helper (Pass 16B, not used at runtime): zone identity + valley atmosphere. Runs after WorldBuilderSite14D in
-- WorldBuilder.Build() and can also be run on its own:  require(game.ServerStorage.DevTools.WorldBuilderZones16B:Clone())({ world = workspace.World })
-- Idempotent: everything lives in World.ZonePolish (rebuilt each run). Uses its own Random stream and never moves anything.
-- Each family gets a few LARGE forms (no prop spam) placed only where a footprint test finds free, gently sloping ground:
--   WOOD   timber stacks, a chunky timber retaining wall, a corduroy log-road fragment, tree groves (cloned from Scenery)
--   STONE  stacked rock shelves, staged boulders, concrete barrier rows, dusty ground patches
--   METAL  scrap heaps, dark steel gantries, rail fragments, a loading bay, utility poles
--   POWER  concrete utility pads with transformers, thick conduit runs, masts (restrained cyan only where powered)
-- Footprint test: no existing part (roads, nodes, zone markers, other new forms) inside the footprint + margin; terrain-only ground
-- raycast, slope limit, no water. Heights stay low near the central sightline.
return function(ctx)
	local V, M = Vector3.new, Enum.Material
	local world = ctx.world or workspace:FindFirstChild("World")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Spots = require(ReplicatedStorage.Shared.Config.ResourceSpotConfig).Spots

	local old = world:FindFirstChild("ZonePolish")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "ZonePolish"
	root.Parent = world
	local added, placedKits, skipped = 0, 0, {}

	local C = {
		Timber = Color3.fromRGB(122, 86, 54), Log = Color3.fromRGB(148, 108, 70), Bark = Color3.fromRGB(84, 60, 40),
		Rock = Color3.fromRGB(146, 140, 128), RockDark = Color3.fromRGB(100, 98, 96), Sand = Color3.fromRGB(174, 158, 128),
		Concrete = Color3.fromRGB(150, 147, 141), Steel = Color3.fromRGB(54, 58, 66), Rust = Color3.fromRGB(122, 78, 50),
		Amber = Color3.fromRGB(196, 132, 52), Utility = Color3.fromRGB(176, 176, 172), Dark = Color3.fromRGB(64, 66, 72),
		Cyan = Color3.fromRGB(96, 214, 234),
	}

	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { workspace.Terrain }
	local function ground(x: number, z: number): (number?, boolean)
		local hit = workspace:Raycast(V(x, 500, z), V(0, -1000, 0), rp)
		if not hit then
			return nil, false
		end
		return hit.Position.Y, hit.Material ~= Enum.Material.Water
	end
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = { workspace.Terrain }

	-- a kit builds with local coordinates: x/z on the ground plane, y UP from the ground
	local function newKit(frame: CFrame)
		local model = Instance.new("Model")
		model.Name = "Kit"
		local k = {}
		local function fin(p: BasePart, color: Color3, mat: Enum.Material, collide: boolean?)
			added += 1
			p.Anchored, p.Color, p.Material = true, color, mat
			p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			if collide == false then
				p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
			end
			p.Parent = model
			return p
		end
		function k.box(pos: Vector3, size: Vector3, color: Color3, mat: Enum.Material, rot: CFrame?, collide: boolean?)
			local p = Instance.new("Part")
			p.Size, p.CFrame = size, frame * CFrame.new(pos) * (rot or CFrame.identity)
			return fin(p, color, mat, collide)
		end
		function k.wedge(pos: Vector3, size: Vector3, color: Color3, mat: Enum.Material, rot: CFrame?)
			local p = Instance.new("WedgePart")
			p.Size, p.CFrame = size, frame * CFrame.new(pos) * (rot or CFrame.identity)
			return fin(p, color, mat)
		end
		-- cylinder along local X (rot turns it)
		function k.cylX(pos: Vector3, len: number, d: number, color: Color3, mat: Enum.Material, rot: CFrame?, collide: boolean?)
			local p = Instance.new("Part")
			p.Shape = Enum.PartType.Cylinder
			p.Size, p.CFrame = V(len, d, d), frame * CFrame.new(pos) * (rot or CFrame.identity)
			return fin(p, color, mat, collide)
		end
		-- vertical cylinder
		function k.cylY(pos: Vector3, h: number, d: number, color: Color3, mat: Enum.Material)
			return k.cylX(pos, h, d, color, mat, CFrame.Angles(0, 0, math.rad(90)))
		end
		function k.ell(pos: Vector3, size: Vector3, color: Color3, mat: Enum.Material, rot: CFrame?)
			local p = Instance.new("Part")
			p.Size, p.CFrame = size, frame * CFrame.new(pos) * (rot or CFrame.identity)
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
			return fin(p, color, mat)
		end
		function k.bar(a: Vector3, b: Vector3, t: number, color: Color3, mat: Enum.Material)
			local p = Instance.new("Part")
			local wa, wb = frame * a, frame * b
			p.Size, p.CFrame = V(t, t, (wb - wa).Magnitude), CFrame.lookAt((wa + wb) / 2, wb)
			return fin(p, color, mat)
		end
		return k, model
	end

	----------------------------------------------------------------- KITS: { w, d, h, build(k, rng) }
	local Kits = {}
	Kits.TimberStack = { 18, 12, 8, function(k, rng)
		local n = { 4, 3, 2 }
		for layer = 1, 3 do
			for i = 1, n[layer] do
				local z = (i - (n[layer] + 1) / 2) * 3.0
				k.cylX(V(0, 1.5 + (layer - 1) * 2.5, z), 16 + rng:NextInteger(-1, 1), 2.9, if (i + layer) % 2 == 0 then C.Log else C.Timber, M.Wood)
			end
		end
		for _, sx in { -1, 1 } do
			k.box(V(sx * 8.8, 3.5, 0), V(1, 7, 11), C.Bark, M.Wood)
		end
	end }
	Kits.TimberWall = { 26, 8, 10, function(k, rng)
		for i = 1, 9 do
			k.cylY(V((i - 5) * 2.7, 4.6 + rng:NextNumber(0, 0.6), 0), 9.2 + rng:NextNumber(0, 1.2), 2.6, if i % 2 == 0 then C.Log else C.Timber, M.Wood)
		end
		k.box(V(0, 9.4, 0), V(25, 1.3, 1.8), C.Bark, M.Wood)
		k.wedge(V(0, 3, 4.2), V(25, 6, 6), C.Sand, M.Ground, CFrame.Angles(0, math.rad(180), 0))
	end }
	Kits.LogRoad = { 26, 8, 2, function(k)
		for i = 1, 9 do
			k.cylX(V(0, 0.8, (i - 5) * 2.2), 8, 1.7, if i % 2 == 0 then C.Log else C.Timber, M.Wood, CFrame.Angles(0, math.rad(90), 0))
		end
		k.box(V(0, 0.2, 0), V(9, 0.4, 20), C.Sand, M.Ground, nil, false)
	end }
	Kits.RockShelf = { 28, 16, 11, function(k)
		k.box(V(0, 1.6, 0), V(26, 3.2, 14), C.Rock, M.Slate)
		k.box(V(-1, 4.8, -0.5), V(20, 3.2, 11), C.RockDark, M.Slate)
		k.box(V(-3, 8, -1), V(13, 3.2, 8), C.Rock, M.Slate)
		k.wedge(V(1, 2, 9.5), V(22, 4, 5), C.RockDark, M.Slate)
		k.box(V(11, 3, 5), V(5, 6, 5), C.Rock, M.Slate, CFrame.Angles(0, math.rad(20), 0))
	end }
	Kits.BoulderCluster = { 18, 18, 10, function(k, rng)
		k.ell(V(0, 4.2, 0), V(11, 9, 10), C.Rock, M.Slate, CFrame.Angles(0, math.rad(rng:NextInteger(0, 180)), 0))
		k.ell(V(6.5, 3, 4), V(8, 6.5, 7.5), C.RockDark, M.Slate)
		k.ell(V(-5.5, 2.6, 4.5), V(7, 5.6, 7), C.Rock, M.Slate)
		k.ell(V(-3, 1.8, -6), V(5, 3.8, 5), C.RockDark, M.Slate)
	end }
	Kits.BarrierRow = { 26, 5, 4, function(k)
		for i = 1, 4 do
			k.box(V((i - 2.5) * 6.2, 1.7, 0), V(6, 3.4, 2.4), C.Concrete, M.Concrete)
		end
		k.box(V(0, 3.45, 0), V(24, 0.3, 0.5), C.Amber, M.Metal, nil, false)
	end }
	Kits.DustPatch = { 36, 36, 0.4, function(k)
		k.cylY(V(0, 0.18, 0), 0.3, 34, C.Sand, M.Sand):SetAttribute("Flat", true)
	end }
	Kits.ScrapPile = { 20, 16, 8, function(k, rng)
		for i = 1, 7 do
			local a = i / 7 * math.pi * 2
			local r = 2 + (i % 3) * 2.2
			k.box(V(math.cos(a) * r, 1.6 + (i % 4) * 0.9, math.sin(a) * r), V(rng:NextNumber(5, 9), rng:NextNumber(1, 1.6), rng:NextNumber(3, 5.5)), if i % 3 == 0 then C.Rust else C.Steel, M.Metal,
				CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 3.1), rng:NextNumber(-0.4, 0.4)))
		end
	end }
	Kits.SteelGantry = { 22, 9, 15, function(k)
		for _, sx in { -1, 1 } do
			k.box(V(sx * 9, 7, 0), V(2, 14, 2), C.Steel, M.Metal)
		end
		k.box(V(0, 14.5, 0), V(21, 2, 2.4), C.Steel, M.Metal)
		k.bar(V(-9, 1, 0), V(0, 14, 0), 1, C.Dark, M.Metal)
		k.bar(V(9, 1, 0), V(0, 14, 0), 1, C.Dark, M.Metal)
		k.box(V(0, 11.5, 0), V(5, 3, 3), C.Amber, M.Metal)
	end }
	Kits.RailFragment = { 28, 7, 2, function(k)
		for _, sz in { -1.1, 1.1 } do
			k.box(V(0, 0.9, sz), V(26, 0.5, 0.5), C.Steel, M.Metal)
		end
		for i = 1, 6 do
			k.box(V((i - 3.5) * 4.2, 0.35, 0), V(0.9, 0.5, 5), C.Bark, M.Wood)
		end
		k.box(V(13.2, 1.4, 0), V(1.4, 2.4, 4), C.Amber, M.Metal)
	end }
	Kits.LoadingBay = { 20, 14, 9, function(k)
		k.box(V(0, 1.6, 0), V(18, 3.2, 10), C.Dark, M.Concrete)
		k.wedge(V(0, 1.6, 9), V(10, 3.2, 8), C.Concrete, M.Concrete, CFrame.Angles(0, math.rad(180), 0))
		for _, sx in { -1, 1 } do
			k.box(V(sx * 8, 6.4, -4), V(1.4, 6.4, 1.4), C.Steel, M.Metal)
		end
		k.box(V(0, 9.4, -3), V(18, 1, 6), C.Steel, M.Metal)
	end }
	Kits.UtilityPole = { 10, 8, 26, function(k)
		k.cylY(V(0, 12, 0), 24, 1.4, C.Bark, M.Wood)
		k.box(V(0, 22.5, 0), V(9, 0.8, 0.8), C.Bark, M.Wood)
		k.box(V(0, 19.5, 0), V(6, 0.7, 0.7), C.Bark, M.Wood)
		k.box(V(2.2, 17, 0), V(2.4, 3, 2.4), C.Utility, M.Metal)
	end }
	Kits.TransformerPad = { 24, 18, 8, function(k)
		k.box(V(0, 0.4, 0), V(23, 0.8, 17), C.Concrete, M.Concrete)
		for _, sx in { -1, 1 } do
			k.box(V(sx * 5.5, 3.6, -1), V(7, 5.6, 6), C.Utility, M.Metal)
			k.cylY(V(sx * 5.5, 7, -1), 1.6, 4.4, C.Dark, M.Metal)
		end
		k.box(V(-5.5, 3.2, -4.1), V(4.5, 0.35, 0.3), C.Cyan, M.Neon, nil, false) -- the one powered accent
		k.cylX(V(0, 1.5, 6), 22, 1.5, C.Dark, M.Metal)
		k.box(V(0, 1.4, 6), V(2.2, 2.6, 2.6), C.Concrete, M.Concrete)
	end }
	Kits.ConduitRun = { 34, 6, 4, function(k)
		k.cylX(V(0, 1.2, 0), 32, 2, C.Dark, M.Metal)
		for _, x in { -11, 0, 11 } do
			k.box(V(x, 1.2, 0), V(2.2, 3.2, 3.2), C.Concrete, M.Concrete)
		end
		k.box(V(-16.4, 2.5, 0), V(1.6, 5, 4), C.Concrete, M.Concrete)
	end }
	Kits.UtilityMast = { 10, 10, 24, function(k)
		k.cylY(V(0, 11, 0), 22, 1.8, C.Concrete, M.Concrete)
		k.box(V(0, 19, 0), V(8, 0.8, 0.8), C.Dark, M.Metal)
		k.box(V(0, 14, 0), V(5.5, 0.7, 0.7), C.Dark, M.Metal)
		k.box(V(0, 22.4, 0), V(1.2, 1.2, 1.2), C.Cyan, M.Neon, nil, false)
	end }

	----------------------------------------------------------------- placement
	local function try(zoneId: string, kitName: string, centre: Vector3, rng: Random, rMin: number, rMax: number, face: boolean?): boolean
		local def = Kits[kitName]
		local w, d, h = def[1], def[2], def[3]
		for _ = 1, 90 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(rMin, rMax)
			local x, z = centre.X + math.cos(a) * r, centre.Z + math.sin(a) * r
			local yaw = if face then math.atan2(centre.X - x, centre.Z - z) + math.pi / 2 else rng:NextNumber(0, math.pi)
			local gy, dry = ground(x, z)
			if gy and dry then
				local rot = CFrame.Angles(0, yaw, 0)
				local lo, hi = gy, gy
				local ok = true
				for _, c in { V(w / 2, 0, d / 2), V(-w / 2, 0, d / 2), V(w / 2, 0, -d / 2), V(-w / 2, 0, -d / 2) } do
					local wp = (CFrame.new(x, 0, z) * rot) * c
					local cy, cdry = ground(wp.X, wp.Z)
					if not cy or not cdry then
						ok = false
						break
					end
					lo, hi = math.min(lo, cy), math.max(hi, cy)
				end
				if ok and hi - lo <= (if kitName == "DustPatch" or kitName == "RockShelf" or kitName == "BoulderCluster" then 6 else 3.2) then
					local mid = (lo + hi) / 2
					local bot, top = lo - 3, mid + h + 0.5 -- reaches below the footprint so terrain-hugging path pieces on a slope are caught
					local box = CFrame.new(x, (bot + top) / 2, z) * rot
					local blockers = workspace:GetPartBoundsInBox(box, V(w + 5, top - bot, d + 5), op)
					local clear = true
					for _, b in blockers do
						if not (b.Name == "Kit" or b:FindFirstAncestor("ZonePolish") and false) then
							clear = false
							break
						end
					end
					if clear then
						local k, model = newKit(CFrame.new(x, lo - 0.1, z) * rot)
						def[4](k, rng)
						model.Name = kitName .. "_" .. zoneId
						model.Parent = root
						placedKits += 1
						return true
					end
				end
			end
		end
		table.insert(skipped, zoneId .. ":" .. kitName)
		return false
	end

	local PLAN = {
		Forest = { { "TimberStack", 1 }, { "TimberWall", 1 } },
		LumberCamp = { { "TimberStack", 1 }, { "TimberWall", 1 }, { "LogRoad", 1 } },
		Quarry = { { "RockShelf", 1 }, { "BoulderCluster", 1 }, { "BarrierRow", 1 }, { "DustPatch", 1 } },
		DeepQuarry = { { "RockShelf", 1 }, { "BoulderCluster", 2 }, { "BarrierRow", 1 }, { "DustPatch", 1 } },
		Mine = { { "ScrapPile", 1 }, { "SteelGantry", 1 } },
		IndustrialYard = { { "ScrapPile", 1 }, { "SteelGantry", 1 }, { "RailFragment", 1 }, { "UtilityPole", 1 } },
		Energy = { { "TransformerPad", 1 }, { "ConduitRun", 1 } },
		ReactorYard = { { "TransformerPad", 1 }, { "ConduitRun", 1 }, { "UtilityMast", 1 } },
	}
	local LOADING = { IndustrialYard = "LoadingBay" }

	local seed = 1601
	for zoneId, list in PLAN do
		local spot = Spots[zoneId]
		if spot then
			local rng = Random.new(seed)
			seed += 17
			for _, entry in list do
				for _ = 1, entry[2] do
					local rMin, rMax = 30, 100
					if entry[1] == "DustPatch" then
						rMin, rMax = 22, 60
					end
					try(zoneId, entry[1], spot.Position, rng, rMin, rMax, entry[1] == "TimberWall" or entry[1] == "BarrierRow")
				end
			end
			if LOADING[zoneId] then
				try(zoneId, LOADING[zoneId], spot.Position, rng, 40, 80, true)
			end
		end
	end

	----------------------------------------------------------------- tree groves (cloned from Scenery; clusters with open space between)
	local scenery = world:FindFirstChild("Scenery")
	local trees = {}
	if scenery then
		for _, c in scenery:GetChildren() do
			if c.Name == "Tree" and c:IsA("Model") then
				table.insert(trees, c)
			end
		end
	end
	local grovePlaced = 0
	local function grove(centre: Vector3, count: number, rng: Random)
		for _ = 1, count do
			for _ = 1, 8 do
				local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, 14)
				local x, z = centre.X + math.cos(a) * r, centre.Z + math.sin(a) * r
				local gy, dry = ground(x, z)
				if gy and dry and #trees > 0 then
					local blockers = workspace:GetPartBoundsInBox(CFrame.new(x, gy + 4, z), V(10, 14, 10), op)
					if #blockers == 0 then
						local t = trees[rng:NextInteger(1, #trees)]:Clone()
						t:ScaleTo(t:GetScale() * rng:NextNumber(0.85, 1.35))
						t:PivotTo(CFrame.new(x, gy, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
						local bb, bs = t:GetBoundingBox()
						t:PivotTo(t:GetPivot() + V(0, (gy - (bb.Position.Y - bs.Y / 2)) - 0.2, 0))
						for _, d in t:GetDescendants() do
							if d:IsA("BasePart") then
								added += 1
							end
						end
						t.Parent = root
						grovePlaced += 1
						break
					end
				end
			end
		end
	end
	-- groves on the long approaches (spread, not packed): a cluster about 55% of the way from the hub to each Tier 1 and Tier 2 zone,
	-- offset to one side so the road stays open; open ground is kept between clusters
	local gr = Random.new(1633)
	for _, id in { "Forest", "LumberCamp", "Quarry", "DeepQuarry", "Mine", "IndustrialYard", "Energy", "ReactorYard" } do
		local sp = Spots[id]
		if sp then
			local dir = V(sp.Position.X, 0, sp.Position.Z)
			local perp = V(-dir.Z, 0, dir.X).Unit * (if gr:NextInteger(0, 1) == 0 then 38 else -38)
			grove(dir * 0.55 + perp, 3, gr)
		end
	end

	local summary = string.format("ZonePolish: %d kits, %d trees, %d parts; skipped %s", placedKits, grovePlaced, added, table.concat(skipped, ","))
	print("[WorldBuilderZones16B] " .. summary)
	return summary
end
