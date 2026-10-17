--!nonstrict
-- PASS 20C: final map visual quality. Runs last in WorldBuilder.Build (after Hub19A) and can be re-run on a built world: it rebuilds
-- its own World.Art20C folder and only repaints terrain materials / adds a few large forms. The layout is LOCKED: nothing here moves the pad,
-- spawn, rings, roads, zones, nodes, crane/silos, ponds/creek or secret areas.
--
--   1. HUB          a clean lawn round the hub (no tall decoration blades flooding the spawn foreground)
--   2. ROADS        every road sits in a packed-earth bed (terrain shoulders under / beside the road body) instead of on grass;
--                   blob hills next to travelled routes get big slate rock shelves on the side facing the route
--   3. APPROACHES   Wood = grove masses + clearing; Stone = rock cut + rock floor; Metal = dark concrete staging + steel gate over the road;
--                   Power = concrete utility pad + one tidy pole line with restrained cyan insulators
--   4. FOLIAGE      lone trees scattered near the hub are removed (clusters stay); a few strong grove masses are added at the approaches
local V = Vector3.new
local M = Enum.Material

local TIER1 = {
	Wood = { zone = "Forest", pos = V(-215, 0, 55) },
	Stone = { zone = "Quarry", pos = V(205, 0, -30) },
	Metal = { zone = "Mine", pos = V(-120, 0, -175) },
	Power = { zone = "Energy", pos = V(135, 0, -160) },
}

local function flat(v: Vector3): Vector3
	return V(v.X, 0, v.Z)
end

return function(ctx)
	local world = ctx.world
	local Terrain = workspace.Terrain
	local old = world:FindFirstChild("Art20C")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Art20C"
	folder.Parent = world
	local added, removed = 0, 0

	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, wedge: boolean?): BasePart
		local p = Instance.new(if wedge then "WedgePart" else "Part")
		p.Name, p.Size, p.CFrame, p.Color, p.Material = name, size, cf, color, mat
		p.Anchored, p.TopSurface, p.BottomSurface = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = folder
		added += 1
		return p
	end

	------------------------------------------------------------------- what must stay clear
	local roads = {}
	local paths = world:FindFirstChild("Paths")
	for _, p in (paths and paths:GetChildren()) or {} do
		if p:IsA("BasePart") and (p.Name == "RoadBody" or p.Name == "JunctionPad") then
			table.insert(roads, p)
		end
	end
	local hubLane = world:FindFirstChild("CirculationHub")
	local lanePts = {}
	for _, p in (hubLane and hubLane:GetChildren()) or {} do
		if p.Name == "LaneBody" then
			table.insert(lanePts, flat(p.Position))
		end
	end
	local nodes = {}
	local zones = world:FindFirstChild("Zones")
	for _, z in (zones and zones:GetChildren()) or {} do
		for _, d in z:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(nodes, flat(d.Position))
			end
		end
	end
	-- distance from a point to the nearest road surface (rectangle test in each road part's frame)
	local function roadDist(p: Vector3): number
		local best = 1e9
		for _, r in roads do
			local lp = r.CFrame:PointToObjectSpace(V(p.X, r.Position.Y, p.Z))
			local dx = math.max(0, math.abs(lp.X) - r.Size.X / 2)
			local dz = math.max(0, math.abs(lp.Z) - r.Size.Z / 2)
			if r.Name == "JunctionPad" then
				dx = math.max(0, math.abs(lp.Y) - r.Size.Y / 2) -- cylinder-ish pads: use the other axes
				dz = math.max(0, math.abs(lp.Z) - r.Size.Z / 2)
			end
			best = math.min(best, math.sqrt(dx * dx + dz * dz))
		end
		return best
	end
	local function laneDist(p: Vector3): number
		local best = 1e9
		for _, q in lanePts do
			best = math.min(best, (flat(p) - q).Magnitude)
		end
		return best - 12
	end
	local function clear(p: Vector3, r: number): boolean
		if roadDist(p) < r + 4 or laneDist(p) < r + 6 then
			return false
		end
		local fp = flat(p)
		for _, n in nodes do
			if (fp - n).Magnitude < r + 10 then
				return false
			end
		end
		return flat(p).Magnitude > 150 -- never inside the hub ring area
	end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { Terrain }
	local function groundY(x: number, z: number): number
		local hit = workspace:Raycast(V(x, 300, z), V(0, -600, 0), rp)
		return if hit then hit.Position.Y else 0
	end

	-- every large form gets its own ground (rock under rock, concrete under steel) so nothing reads as dropped onto grass
	local GRASSY0 = { [M.Grass] = true, [M.LeafyGrass] = true, [M.Ground] = true, [M.Mud] = true }
	local function paintDisc(c: Vector3, radius: number, mat: Enum.Material, alt: Enum.Material)
		local reg = Region3.new(V(c.X - radius, -8, c.Z - radius), V(c.X + radius, 40, c.Z + radius)):ExpandToGrid(4)
		local ms, os_ = Terrain:ReadVoxels(reg, 4)
		local o = reg.CFrame.Position - reg.Size / 2
		for ix = 1, ms.Size.X do
			local x = o.X + (ix - 0.5) * 4
			for iz = 1, ms.Size.Z do
				local z = o.Z + (iz - 0.5) * 4
				local d = (V(x, 0, z) - V(c.X, 0, c.Z)).Magnitude + math.noise(x / 9, z / 9, 7.7) * 4
				if d < radius then
					for iy = 1, ms.Size.Y do
						if os_[ix][iy][iz] > 0 and GRASSY0[ms[ix][iy][iz]] then
							ms[ix][iy][iz] = if math.noise(x / 7, z / 7, 2.1) > 0.15 then alt else mat
						end
					end
				end
			end
		end
		Terrain:WriteVoxels(reg, 4, ms, os_)
	end

	------------------------------------------------------------------- 1 + 2 + 3. TERRAIN MATERIALS (one voxel pass)
	-- road beds: cells under / beside every road body become packed earth
	local bed: { [string]: boolean } = {}
	for _, r in roads do
		local half = V(r.Size.X / 2 + 5, 0, r.Size.Z / 2 + 3)
		for gx = -half.X, half.X, 2 do
			for gz = -half.Z, half.Z, 2 do
				local w = r.CFrame:PointToWorldSpace(V(gx, 0, gz))
				bed[math.floor(w.X / 4) .. "," .. math.floor(w.Z / 4)] = true
			end
		end
	end
	local zoneTint = {
		{ c = TIER1.Stone.pos, r = 46, mat = M.Rock, alt = M.Slate },
		{ c = TIER1.Metal.pos, r = 40, mat = M.Asphalt, alt = M.Concrete },
		{ c = TIER1.Power.pos, r = 40, mat = M.Concrete, alt = M.Pavement },
		{ c = TIER1.Wood.pos, r = 44, mat = M.LeafyGrass, alt = M.Ground },
	}
	local GRASSY = { [M.Grass] = true, [M.LeafyGrass] = true }
	local region = Region3.new(V(-340, -8, -340), V(340, 4, 340)):ExpandToGrid(4)
	local mats, occs = Terrain:ReadVoxels(region, 4)
	local size = mats.Size
	local origin = region.CFrame.Position - region.Size / 2
	for ix = 1, size.X do
		local x = origin.X + (ix - 0.5) * 4
		for iz = 1, size.Z do
			local z = origin.Z + (iz - 0.5) * 4
			local r = math.sqrt(x * x + z * z)
			local key = math.floor(x / 4) .. "," .. math.floor(z / 4)
			for iy = 1, size.Y do
				local mat = mats[ix][iy][iz]
				if occs[ix][iy][iz] > 0 and mat ~= M.Air and mat ~= M.Water then
					local n = math.noise(x / 22, z / 22, 4.2)
					if GRASSY[mat] then
						if bed[key] then
							mats[ix][iy][iz] = if n > 0.25 then M.Mud else M.Ground -- the road sits in a packed-earth bed
						elseif r < 205 and mat == M.Grass then
							mats[ix][iy][iz] = M.LeafyGrass -- a clean lawn round the hub: Grass grows tall decoration blades that flood the spawn view
						else
							for _, t in zoneTint do
								local d = (V(x, 0, z) - t.c).Magnitude
								if d < t.r + n * 8 and d > 12 then
									mats[ix][iy][iz] = if n > 0.1 then t.alt else t.mat
									break
								end
							end
						end
					end
				end
			end
		end
	end
	Terrain:WriteVoxels(region, 4, mats, occs)

	------------------------------------------------------------------- 2. ROCK SHELVES on blob hills beside the routes
	local SLATE, SLATE2 = Color3.fromRGB(112, 108, 102), Color3.fromRGB(92, 90, 88)
	local hills = {}
	for x = -300, 300, 12 do
		for z = -300, 300, 12 do
			local r = math.sqrt(x * x + z * z)
			if r > 160 and r < 320 then
				local h = groundY(x, z)
				if h > 5 then
					local peak = true
					for _, o in { { 12, 0 }, { -12, 0 }, { 0, 12 }, { 0, -12 }, { 12, 12 }, { -12, -12 }, { 12, -12 }, { -12, 12 } } do
						if groundY(x + o[1], z + o[2]) > h then
							peak = false
							break
						end
					end
					local rd = roadDist(V(x, 0, z))
					if peak and rd < 110 and rd > 14 then
						table.insert(hills, { p = V(x, h, z), rd = rd })
					end
				end
			end
		end
	end
	-- biggest blobs first, one entry per hill (peaks of the same dome merge)
	table.sort(hills, function(a, b)
		return a.p.Y > b.p.Y
	end)
	local merged = {}
	for _, h in hills do
		local dup = false
		for _, m in merged do
			if (flat(m.p) - flat(h.p)).Magnitude < 45 then
				dup = true
				break
			end
		end
		if not dup then
			table.insert(merged, h)
		end
	end
	hills = merged
	local shelves = 0
	for i = 1, math.min(6, #hills) do
		local hl = hills[i]
		-- the flank facing the nearest road: march from the peak toward the road until the slope is half way down
		local best, bestD = nil, 1e9
		for _, rd in roads do
			local d = (flat(rd.Position) - flat(hl.p)).Magnitude
			if d < bestD then
				best, bestD = rd, d
			end
		end
		if best then
			local dir = (flat(best.Position) - flat(hl.p)).Unit
			-- the half-way-down point of the flank, but never closer to the road than the shelf needs
			local spot
			for step = 6, 80, 3 do
				local q = flat(hl.p) + dir * step
				if roadDist(q) < 24 then
					break
				end
				local y = groundY(q.X, q.Z)
				spot = V(q.X, y, q.Z)
				if y < hl.p.Y * 0.6 then
					break
				end
			end
			if spot and clear(spot, 14) then
				local side = V(-dir.Z, 0, dir.X)
				for k, off in { -9, 10 } do
					local c = spot + side * off - dir * (k * 2)
					local y = groundY(c.X, c.Z)
					local sz = if k == 1 then V(22, 9, 13) else V(17, 7, 11)
					local cf = CFrame.lookAt(V(c.X, y + sz.Y * 0.22, c.Z), V(c.X, y + sz.Y * 0.22, c.Z) + dir) * CFrame.Angles(math.rad(-10), math.rad(k * 7 - 10), 0)
					part("RockShelf", sz, cf, if k == 1 then SLATE else SLATE2, M.Slate)
				end
				shelves += 1
			end
		end
	end

	------------------------------------------------------------------- 3. TIER 1 APPROACH IDENTITY (large forms only)
	-- the approach point: half way between the hub ring and the zone, nudged sideways off the road
	local function approach(zonePos: Vector3, frac: number, sideOff: number): Vector3
		local p = flat(zonePos) * frac
		local dir = flat(zonePos).Unit
		local side = V(-dir.Z, 0, dir.X)
		return p + side * sideOff
	end
	local function firstClear(zonePos: Vector3, frac: number, offs: { number }, r: number): Vector3?
		for _, f in { frac, frac + 0.05, frac - 0.05, frac + 0.1 } do
			for _, o in offs do
				local p = approach(zonePos, f, o)
				if clear(p, r) then
					return V(p.X, groundY(p.X, p.Z), p.Z)
				end
			end
		end
		return nil
	end

	-- STONE: a rock cut: two big tilted slate walls and a boulder, framing the way into the Rock Field
	for _, side in { 1, -1 } do
		local p = firstClear(TIER1.Stone.pos, 0.82, { side * 24, side * 30, side * 36 }, 10)
		if p then
			local dir = flat(TIER1.Stone.pos).Unit
			local cf = CFrame.lookAt(p, p + dir) * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(side * 14))
			part("RockCut", V(9, 12, 26), cf, SLATE, M.Slate)
			part("RockCutCap", V(11, 4, 18), cf * CFrame.new(-side * 1.5, 6.5, -2) * CFrame.Angles(0, math.rad(8), math.rad(-side * 8)), SLATE2, M.Rock)
		end
	end
	do
		local p = firstClear(TIER1.Stone.pos, 0.9, { 30, -30, 38, -38 }, 8)
		if p then
			part("Boulder", V(10, 8, 9), CFrame.new(p + V(0, 2.5, 0)) * CFrame.Angles(0.3, 0.7, 0.2), SLATE2, M.Rock)
		end
	end

	-- METAL: dark concrete staging pads either side + one steel portal frame spanning the Scrap Yard road
	do
		-- the road piece on the Scrap Yard approach whose gate columns keep well clear of every node and the lane
		local nearest, nd = nil, 1e9
		for _, frac in { 0.8, 0.76, 0.84, 0.72 } do
			local target = flat(TIER1.Metal.pos) * frac
			for _, r in roads do
				if r.Name == "RoadBody" then
					local d = (flat(r.Position) - target).Magnitude
					if d < nd and d < 40 then
						local ok = true
						for _, sx in { -1, 1 } do
							local base = (r.CFrame * CFrame.new(sx * (r.Size.X / 2 + 5.5), 0, 0)).Position
							for _, n in nodes do
								if (flat(base) - n).Magnitude < 16 then
									ok = false
								end
							end
							if laneDist(base) < 8 then
								ok = false
							end
						end
						if ok then
							nearest, nd = r, d
						end
					end
				end
			end
			if nearest then
				break
			end
		end
		if nearest and nd < 40 then
			local cf = nearest.CFrame - V(0, nearest.Position.Y, 0)
			local span = nearest.Size.X / 2 + 5.5 -- outside the road shoulders
			local steel, dark = Color3.fromRGB(66, 70, 78), Color3.fromRGB(46, 48, 54)
			for _, sx in { -1, 1 } do
				local base = (cf * CFrame.new(sx * span, 0, 0)).Position
				local gy = groundY(base.X, base.Z)
				part("GateColumn", V(2.4, 17, 2.4), CFrame.new(base.X, gy + 8.5, base.Z) * cf.Rotation, steel, M.Metal)
				paintDisc(V(base.X, 0, base.Z), 9, M.Concrete, M.Asphalt)
			end
			local mid = cf.Position
			local gy = groundY(mid.X, mid.Z)
			part("GateBeam", V(span * 2 + 3, 2.2, 2.6), CFrame.new(mid.X, gy + 17.5, mid.Z) * cf.Rotation, dark, M.Metal)
			part("GateBand", V(span * 2 + 3.2, 0.5, 2.8), CFrame.new(mid.X, gy + 16.2, mid.Z) * cf.Rotation, Color3.fromRGB(210, 160, 40), M.Metal)
		end
	end

	-- POWER: a tidy line of four utility poles along the Battery Depot approach, restrained cyan insulators
	do
		local zp = flat(TIER1.Power.pos)
		local dir = zp.Unit
		local side = V(-dir.Z, 0, dir.X)
		local placed = 0
		for k = 0, 5 do
			if placed >= 4 then
				break
			end
			local p = zp * (0.74 + k * 0.045)
			for _, o in { 20, -20, 26, -26 } do
				local q = p + side * o
				if clear(q, 4) then
					local gy = groundY(q.X, q.Z)
					local pole = CFrame.lookAt(V(q.X, gy, q.Z), V(q.X, gy, q.Z) + side)
					part("UtilityPole", V(1.3, 22, 1.3), pole * CFrame.new(0, 11, 0), Color3.fromRGB(150, 146, 138), M.Concrete)
					part("CrossArm", V(7, 0.8, 0.9), pole * CFrame.new(0, 20.4, 0), Color3.fromRGB(70, 74, 82), M.Metal)
					for _, ix in { -2.8, 2.8 } do
						local ins = part("Insulator", V(0.6, 0.9, 0.6), pole * CFrame.new(ix, 21.2, 0), Color3.fromRGB(110, 215, 230), M.Glass)
						ins.Transparency = 0.15
					end
					placed += 1
					break
				end
			end
		end
	end

	-- WOOD: grove masses flanking the Stick Grove approach (clones of the map's own biggest trees) and a short log stack
	local scenery = world:FindFirstChild("Scenery")
	-- the map's own tree models: pines (CornerWedge crowns) for the wood approach, round blocky crowns for the hub groves
	local function pickTree(pine: boolean, maxH: number): Model?
		local best, bestH = nil, 0
		for _, t in (scenery and scenery:GetChildren()) or {} do
			if t:IsA("Model") then
				local isPine = t:FindFirstChildWhichIsA("CornerWedgePart", true) ~= nil
				local _, sz = t:GetBoundingBox()
				if isPine == pine and sz.Y > bestH and sz.Y < maxH then
					best, bestH = t, sz.Y
				end
			end
		end
		return best
	end
	local pineTree, roundTree = pickTree(true, 34), pickTree(false, 30)
	local bigTree = pineTree
	local grovesAdded = 0
	local function grove(center: Vector3, count: number, seed: number)
		if not bigTree then
			return
		end
		local rng = Random.new(seed)
		for i = 1, count do
			local a = (i / count) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
			local d = if i == 1 then 0 else rng:NextNumber(6, 12)
			local p = center + V(math.cos(a) * d, 0, math.sin(a) * d)
			if clear(p, 6) then
				local t = bigTree:Clone()
				local sc = rng:NextNumber(0.85, 1.2)
				t:ScaleTo(t:GetScale() * sc)
				local _, s = t:GetBoundingBox()
				t:PivotTo(CFrame.new(p.X, groundY(p.X, p.Z), p.Z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
				-- sit the trunk base on the ground
				local cf2, s2 = t:GetBoundingBox()
				t:PivotTo(t:GetPivot() + V(0, groundY(p.X, p.Z) - (cf2.Position.Y - s2.Y / 2), 0))
				t.Name = "GroveTree"
				t.Parent = folder
				for _, d2 in t:GetDescendants() do
					if d2:IsA("BasePart") then
						added += 1
					end
				end
				grovesAdded += 1
			end
		end
	end
	do
		local wz = flat(TIER1.Wood.pos)
		local dir = wz.Unit
		local side = V(-dir.Z, 0, dir.X)
		grove(wz * 0.8 + side * 30, 4, 11)
		grove(wz * 0.84 - side * 32, 3, 12)
		local p = firstClear(TIER1.Wood.pos, 0.86, { 20, -20, 24 }, 6)
		if p then
			for i = 0, 2 do
				local cf = CFrame.lookAt(p, p + side) * CFrame.new((i - 1) * 1.6, 1 + (if i == 1 then 1.3 else 0), 0) * CFrame.Angles(0, math.rad(90), math.rad(90))
				part("LogStack", V(1.6, 12, 1.6), cf, Color3.fromRGB(120, 84, 52), M.Wood)
			end
		end
	end
	-- one strong grove mass framing each side of the spawn view, outside the ring (replaces the scattered singles removed below)
	bigTree = roundTree or pineTree
	grove(V(-150, 0, 70), 4, 21)
	grove(V(110, 0, 195), 4, 22)

	for _, p in folder:GetChildren() do
		if p:IsA("BasePart") then
			if p.Name == "RockShelf" or p.Name == "RockCut" or p.Name == "Boulder" then
				paintDisc(p.Position, math.max(p.Size.X, p.Size.Z) * 0.75 + 4, M.Rock, M.Slate)
			elseif p.Name == "UtilityPole" then
				paintDisc(p.Position, 6, M.Concrete, M.Pavement)
			elseif p.Name == "LogStack" then
				paintDisc(p.Position, 8, M.Ground, M.Mud)
			end
		end
	end

	------------------------------------------------------------------- 4. LONE TREES: remove isolated singles near the hub
	if scenery then
		local trees = {}
		for _, t in scenery:GetChildren() do
			if t:IsA("Model") then
				table.insert(trees, { m = t, p = flat(t:GetPivot().Position) })
			end
		end
		for _, a in trees do
			local r = a.p.Magnitude
			if r > 140 and r < 300 then
				local friends = 0
				for _, b in trees do
					if b ~= a and (b.p - a.p).Magnitude < 22 then
						friends += 1
					end
				end
				if friends == 0 then
					for _, d in a.m:GetDescendants() do
						if d:IsA("BasePart") then
							removed += 1
						end
					end
					a.m:Destroy()
				end
			end
		end
	end

	return string.format("art 20C: +%d parts (%d grove trees, %d hill shelves), -%d parts (lone trees)", added, grovesAdded, shelves, removed)
end
