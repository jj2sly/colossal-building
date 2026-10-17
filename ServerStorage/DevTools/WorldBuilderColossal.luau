--!nonstrict
-- EDIT-TIME helper for WorldBuilder (not used at runtime): the COLOSSAL build site. Replaces the old 78-stud pad with a
-- deck + collar sized from ColossalConfig.Site (one number grows it): a plated deck (the usable build footprint) inside an
-- amber rim, a dark-steel collar players stand on to deposit, a drivable sloped concrete skirt down to the ground, heavy
-- concrete footings with steel pylons between the road entries, and the barrier / stage ring / deposit ring rebuilt at
-- the new radii. Road ends, the spawn walkway and hub props that the bigger site now covers are trimmed or moved; nothing
-- outside the site (spawn, roads beyond the skirt, zones, nodes) moves. Runs last in WorldBuilder.Build().
return function(ctx)
	local V, M = Vector3.new, Enum.Material
	local world, decorF, P, park, flatDist = ctx.world, ctx.decorF, ctx.P, ctx.park, ctx.flatDist
	local terrainEdit, GRASSY = ctx.terrainEdit, ctx.GRASSY
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local CollectionService = game:GetService("CollectionService")
	local ColossalConfig = require(ReplicatedStorage.Shared.Config.ColossalConfig)
	local S = ColossalConfig.Site
	local C = S.Center
	local TOP = S.DeckTopY
	local DECK, BAR, COLLAR = S.DeckRadius, S.BarrierRadius, S.CollarRadius
	local SKIRT_IN, SKIRT_OUT = COLLAR - 4, COLLAR + 2 -- the sloped skirt: deck height at SKIRT_IN, ground at SKIRT_OUT

	local COL = {
		Deck = Color3.fromRGB(116, 120, 130),
		Work = Color3.fromRGB(140, 142, 148),
		DarkSteel = Color3.fromRGB(58, 62, 72),
		Steel = Color3.fromRGB(96, 102, 114),
		Amber = Color3.fromRGB(184, 124, 52),
		Concrete = Color3.fromRGB(126, 122, 116),
		DarkConcrete = Color3.fromRGB(98, 96, 92),
		Rail = Color3.fromRGB(62, 68, 82),
	}
	local added = 0
	local function B(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, collide: boolean?): Part
		added += 1
		return P(parent, { Name = name, Size = size, CFrame = cf, Color = color, Material = mat or M.SmoothPlastic, CanCollide = collide ~= false })
	end
	local function disc(parent: Instance, name: string, d: number, top: number, h: number, color: Color3, mat: Enum.Material): Part
		added += 1
		return P(parent, { Name = name, Shape = Enum.PartType.Cylinder, Size = V(h, d, d), CFrame = CFrame.new(C.X, top - h / 2, C.Z) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = mat })
	end
	local function wedge(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material)
		added += 1
		local w = Instance.new("WedgePart")
		w.Name, w.Anchored, w.Size, w.CFrame, w.Color, w.Material = name, true, size, cf, color, mat
		w.TopSurface, w.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		w.Parent = parent
		return w
	end
	local function ring(n: number, r: number, fn: (number, CFrame, number) -> ())
		for i = 0, n - 1 do
			local a = (i + 0.5) / n * math.pi * 2
			local pos = C + V(math.cos(a) * r, 0, math.sin(a) * r)
			fn(i, CFrame.lookAt(pos, V(C.X, 0, C.Z)), 2 * math.pi * r / n)
		end
	end

	local nodePositions = {}
	for _, n in CollectionService:GetTagged("ResourceNode") do
		if n:IsA("BasePart") and n:IsDescendantOf(world) then
			table.insert(nodePositions, n.Position)
		end
	end
	local function nodeClear(p: Vector3, r: number): boolean
		for _, q in nodePositions do
			if flatDist(p, q) < r then
				return false
			end
		end
		return true
	end

	------------------------------------------------------------------- TIER 1 SHIFT
	-- Each moved Tier 1 zone was generated at its old spot (ResourceSpotConfig GenOffset). Move it out as one block: the zone
	-- model (props, gather point, nodes), the scenery trees that framed it, and its painted ground; flatten the destination
	-- inside the zone (hills there would bury nodes) with a soft slope back up to the surrounding land; return the old ground
	-- to lawn. Roads, water and the Training Yard are never repainted or cut.
	local Terrain = workspace.Terrain
	local CELL = 4
	local shiftRoadPts = {}
	for _, road in ctx.ROADS do
		for _, p in road.Samples do
			table.insert(shiftRoadPts, { p, road.Width / 2 })
		end
	end
	local function protectedGround(p: Vector3): boolean
		for _, e in shiftRoadPts do
			if flatDist(p, e[1]) < e[2] + 4 then
				return true
			end
		end
		for _, pd in ctx.PONDS do
			if flatDist(p, pd.P) < pd.R + 6 then
				return true
			end
		end
		for _, c in ctx.CREEK do
			if flatDist(p, c) < 12 then
				return true
			end
		end
		return p.X > -166 and p.X < -58 and p.Z > 62 and p.Z < 195 -- the Training Yard
	end
	local shifted = {}
	for _, spot in ctx.ResourceSpotConfig.List() do
		local off = spot.GenOffset
		local z = off and world.Zones:FindFirstChild(spot.Id)
		if z then
			local new = V(spot.Position.X, 0, spot.Position.Z)
			local old = new - off
			-- terrain: one region covering both discs, read once, rewritten once
			local R, FLAT, COPY = 56, 40, 46
			local lo = V(math.floor((math.min(old.X, new.X) - R) / CELL) * CELL, -8, math.floor((math.min(old.Z, new.Z) - R) / CELL) * CELL)
			local hi = V(math.ceil((math.max(old.X, new.X) + R) / CELL) * CELL, 40, math.ceil((math.max(old.Z, new.Z) + R) / CELL) * CELL)
			local region = Region3.new(lo, hi)
			local mats, occs = Terrain:ReadVoxels(region, CELL)
			local size = mats.Size
			local nm, no = {}, {}
			for ix = 1, size.X do
				nm[ix], no[ix] = {}, {}
				for iy = 1, size.Y do
					nm[ix][iy], no[ix][iy] = table.clone(mats[ix][iy]), table.clone(occs[ix][iy])
				end
			end
			local dx, dz = off.X / CELL, off.Z / CELL
			for ix = 1, size.X do
				local x = lo.X + (ix - 0.5) * CELL
				for iz = 1, size.Z do
					local zz = lo.Z + (iz - 0.5) * CELL
					local p = V(x, 0, zz)
					local dOld, dNew = flatDist(p, old), flatDist(p, new)
					-- 1. the old ground (never where the new zone lands): back to plain lawn, flat
					if dOld <= R and dNew > R and not protectedGround(p) then
						for iy = 1, size.Y do
							local yb = lo.Y + (iy - 1) * CELL
							if yb >= 0 then
								nm[ix][iy][iz], no[ix][iy][iz] = M.Air, 0
							elseif yb >= -4 then
								nm[ix][iy][iz], no[ix][iy][iz] = M.LeafyGrass, 0.5
							end
						end
					end
					-- 2. the new ground: copy the zone's painted ground in, flatten inside, slope back out
					if dNew <= R and not protectedGround(p) then
						local maxH = if dNew <= FLAT then 0 else (dNew - FLAT) * 0.9
						local sx, sz = ix - dx, iz - dz
						for iy = 1, size.Y do
							local yb = lo.Y + (iy - 1) * CELL
							if dNew <= COPY and sx >= 1 and sx <= size.X and sz >= 1 and sz <= size.Z and yb < 0 then
								nm[ix][iy][iz], no[ix][iy][iz] = mats[sx][iy][sz], occs[sx][iy][sz]
							elseif yb >= maxH then
								nm[ix][iy][iz], no[ix][iy][iz] = M.Air, 0
							elseif yb + CELL > maxH then
								no[ix][iy][iz] = math.min(no[ix][iy][iz], math.clamp((maxH - yb) / CELL, 0, 1))
							end
						end
					end
				end
			end
			Terrain:WriteVoxels(region, CELL, nm, no)
			-- parts: trees already standing where the zone lands are parked; then the zone and the trees that framed it move
			for _, t in decorF:GetChildren() do
				if t:IsA("Model") and t.Name == "Tree" then
					local tp = t:GetPivot().Position
					if flatDist(tp, new) < 46 and flatDist(tp, old) > 46 then
						park(t, "Trees")
					end
				end
			end
			z:PivotTo(z:GetPivot() + off)
			for _, t in decorF:GetChildren() do
				if t:IsA("Model") and t.Name == "Tree" then
					local tp = t:GetPivot().Position
					if flatDist(tp, old) < 50 then
						local dest = tp + off
						if protectedGround(dest) then
							park(t, "Trees")
						else
							t:PivotTo(t:GetPivot() + off + V(0, ctx.groundAt(dest.X, dest.Z) - tp.Y, 0))
						end
					end
				end
			end
			table.insert(shifted, string.format("%s (%d,%d)", spot.Id, off.X, off.Z))
		end
	end
	-- node positions moved with their zones
	table.clear(nodePositions)
	for _, n in CollectionService:GetTagged("ResourceNode") do
		if n:IsA("BasePart") and n:IsDescendantOf(world) then
			table.insert(nodePositions, n.Position)
		end
	end

	------------------------------------------------------------------- clear the old site
	local site = world:FindFirstChild("BuildSite")
	if site then
		site:Destroy()
	end
	site = Instance.new("Folder")
	site.Name = "BuildSite"
	site.Parent = world
	local hub = world:FindFirstChild("Hub")
	local hubFrame = hub and hub:FindFirstChild("HubFrame")
	if hubFrame then
		for _, d in hubFrame:GetChildren() do
			if d.Name == "AxisRamp" or d.Name == "AxisRampEdge" or d.Name == "CollarFooting" then
				d:Destroy()
			end
		end
	end

	------------------------------------------------------------------- deck, rim, stage ring, survey marks
	disc(site, "PlatformSkirt", DECK * 2 + 2, TOP - 0.6, 3.4, Color3.fromRGB(48, 52, 60), M.DiamondPlate)
	disc(site, "Platform", DECK * 2, TOP, 2.4, COL.Deck, M.DiamondPlate)
	disc(site, "WorkDeck", DECK * 2 - 16, TOP + 0.06, 0.2, COL.Work, M.Concrete)
	ring(36, DECK - 0.5, function(_, cf, w)
		B(site, "PlatformTrim", V(w + 0.3, 0.3, 1.6), cf * CFrame.new(0, TOP + 0.1, 0), COL.Amber, M.Metal, false)
	end)
	local stageF = Instance.new("Folder")
	stageF.Name = "StageRing"
	stageF.Parent = site
	for i = 1, 24 do
		local a = (i - 0.5) / 24 * math.pi * 2 - math.pi / 2
		local p = C + V(math.cos(a) * (DECK - 7), TOP + 0.03, math.sin(a) * (DECK - 7))
		local tile = B(stageF, "StageLight", V(2.2, 0.14, 11), CFrame.lookAt(p, p + V(-math.sin(a), 0, math.cos(a))), Color3.fromRGB(64, 70, 84), M.SmoothPlastic, false)
		tile.CanQuery, tile.CanTouch = false, false
		tile:SetAttribute("Index", i)
	end
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		local p = C + V(math.cos(a) * DECK * 0.5, TOP + 0.12, math.sin(a) * DECK * 0.5)
		local cf = CFrame.lookAt(p, V(C.X, TOP + 0.12, C.Z))
		B(site, "SurveyMark", V(7, 0.06, 0.8), cf * CFrame.new(-3, 0, 0), Color3.fromRGB(200, 200, 204), M.SmoothPlastic, false)
		B(site, "SurveyMark", V(0.8, 0.06, 7), cf * CFrame.new(0, 0, 3), Color3.fromRGB(200, 200, 204), M.SmoothPlastic, false)
	end

	------------------------------------------------------------------- collar (deposit standing ring) + sloped skirt
	local collarF = Instance.new("Folder")
	collarF.Name = "Collar"
	collarF.Parent = site
	-- the spawn and the Training Yard sit just outside the deck: there the collar stops and the deck shows its steel face
	local SPAWN = V(0, 0, 104)
	local function openSector(p: Vector3): boolean
		return flatDist(p, SPAWN) < 32 or (p.X > -168 and p.X < -56 and p.Z > 60 and p.Z < 196)
	end
	local cw = SKIRT_IN - DECK
	ring(48, (DECK + SKIRT_IN) / 2, function(_, cf, w)
		if not openSector(cf.Position) then
			B(collarF, "CollarPlate", V(w + 0.6, TOP, cw), cf * CFrame.new(0, TOP / 2, 0), COL.DarkSteel, M.DiamondPlate)
		end
	end)
	-- skirt: a WedgePart is tall at +Z; facing the centre (lookAt) puts +Z outward, so turn it to keep the tall side inward
	local sw = SKIRT_OUT - SKIRT_IN
	ring(56, (SKIRT_IN + SKIRT_OUT) / 2, function(_, cf, w)
		if openSector(cf.Position) or openSector((cf * CFrame.new(0, 0, -sw / 2)).Position) then
			return
		end
		wedge(collarF, "CollarSkirt", V(w + 0.8, TOP, sw), cf * CFrame.new(0, TOP / 2, 0) * CFrame.Angles(0, math.pi, 0), COL.Concrete, M.Concrete)
	end)
	-- deposit ring marker (the deposit edge itself is logic: ColossalConfig.Site.DepositRadius)
	local dep = disc(site, "DepositRing", S.DepositRadius * 2, 0.06, 0.1, Color3.fromRGB(132, 124, 110), M.Concrete)
	dep:SetAttribute("DepositZone", true)
	dep.CanCollide = false

	------------------------------------------------------------------- barrier: dark steel guard rail + invisible wall
	local barrierF = Instance.new("Folder")
	barrierF.Name = "Barrier"
	barrierF.Parent = site
	ring(56, BAR, function(i, cf, w)
		B(barrierF, "Rail", V(w + 0.4, 0.5, 0.5), cf * CFrame.new(0, TOP + 2.4, 0), COL.Rail, M.Metal)
		if i % 2 == 0 then
			B(barrierF, "Post", V(0.8, 2.6, 0.8), cf * CFrame.new(w / 2, TOP + 1.3, 0), COL.Amber, M.Metal)
		end
		local wall = B(barrierF, "Wall", V(w + 0.4, 200, 1), cf * CFrame.new(0, 100, 0), COL.Rail)
		wall.Transparency, wall.CanQuery = 1, false
	end)

	------------------------------------------------------------------- footings + pylons (structure; never on a road, node or the spawn axis)
	local roadPts = {}
	for _, road in ctx.ROADS do
		for _, p in road.Samples do
			table.insert(roadPts, { p, road.Width / 2 })
		end
	end
	local function roadClearAt(p: Vector3, r: number): boolean
		for _, e in roadPts do
			if flatDist(p, e[1]) < e[2] + r then
				return false
			end
		end
		return true
	end
	local pylons = 0
	for k = 0, 15 do
		local a = k / 16 * math.pi * 2 + math.pi / 16
		local d = V(math.cos(a), 0, math.sin(a))
		local p = C + d * (SKIRT_OUT + 4)
		local onAxis = d.Z > 0.85 -- the spawn sits due south (+Z)
		if not onAxis and roadClearAt(p, 6) and nodeClear(p, 9) then
			local cf = CFrame.lookAt(p, V(C.X, 0, C.Z))
			B(site, "Footing", V(9, 3, 7), cf * CFrame.new(0, 1.5, 0), COL.DarkConcrete, M.Concrete)
			if k % 2 == 0 then
				B(site, "PylonColumn", V(3.4, 16, 3.4), cf * CFrame.new(0, 11, 0), COL.DarkSteel, M.Metal)
				B(site, "PylonCap", V(4.2, 1.2, 4.2), cf * CFrame.new(0, 19.6, 0), COL.Amber, M.Metal)
				pylons += 1
			end
		end
	end

	------------------------------------------------------------------- ground: worked earth around the skirt (terrain)
	terrainEdit(C.X - SKIRT_OUT - 14, C.Z - SKIRT_OUT - 14, C.X + SKIRT_OUT + 14, C.Z + SKIRT_OUT + 14, -8, 4, function(x, _y, z, mat)
		if not GRASSY[mat] and mat ~= M.Sandstone then
			return nil
		end
		local d = math.sqrt((x - C.X) ^ 2 + (z - C.Z) ^ 2) + math.noise(x / 20, z / 20, 4.1) * 3
		if d < SKIRT_OUT + 9 then
			return M.Ground
		end
		return nil
	end)

	------------------------------------------------------------------- trim what the bigger site now covers
	-- road ends: segments that start under the skirt are shortened to begin at its foot (no road part under the site)
	local paths = world:FindFirstChild("Paths")
	local trimmed = 0
	if paths then
		for _, d in paths:GetChildren() do
			if d:IsA("BasePart") then
				local p = d.Position
				local r = flatDist(p, C)
				if d.Name == "RoadBody" or d.Name == "RoadShoulder" or d.Name == "Dash" then
					local look = d.CFrame.LookVector
					local L = d.Size.Z
					local a, b = p - look * L / 2, p + look * L / 2
					local ra, rb = flatDist(a, C), flatDist(b, C)
					local limit = SKIRT_OUT - 0.5
					if ra < limit and rb < limit then
						d:Destroy()
						trimmed += 1
					elseif ra < limit or rb < limit then
						local inner, outer = if ra < rb then a else b, if ra < rb then b else a
						-- walk the inner end outward along the segment until it reaches the skirt foot
						local t = 0
						for s = 0, 40 do
							t = s / 40
							if flatDist(inner:Lerp(outer, t), C) >= limit then
								break
							end
						end
						local na = inner:Lerp(outer, t)
						local newL = (outer - na).Magnitude
						if newL < 1 then
							d:Destroy()
						else
							-- same orientation (shoulder wedges keep their tall side), new length and centre along the same axis
							local rot = d.CFrame.Rotation
							local mid = (na + outer) / 2
							d.Size = V(d.Size.X, d.Size.Y, newL)
							d.CFrame = CFrame.new(mid.X, p.Y, mid.Z) * rot
						end
						trimmed += 1
					end
				elseif d.Name == "RoadRamp" and r < SKIRT_OUT + 3 then
					d:Destroy()
					trimmed += 1
				end
			end
		end
	end
	-- spawn walkway and axis strips: start at the skirt foot
	if hub then
		local south = C.Z + SKIRT_OUT
		local function clipZ(d: BasePart)
			local z0, z1 = d.Position.Z - d.Size.Z / 2, d.Position.Z + d.Size.Z / 2
			if z1 <= south then
				d:Destroy()
			elseif z0 < south then
				d.Size = V(d.Size.X, d.Size.Y, z1 - south)
				d.CFrame = CFrame.new(d.Position.X, d.Position.Y, (south + z1) / 2)
			end
		end
		for _, d in hub:GetChildren() do
			if d:IsA("BasePart") and (d.Name == "Walkway" or d.Name == "WalkwayCurb") then
				clipZ(d)
			end
		end
		if hubFrame then
			for _, d in hubFrame:GetChildren() do
				if d:IsA("BasePart") and d.Name == "AxisStrip" then
					clipZ(d)
				end
			end
		end
		-- the tower crane and the silo pair stood where the collar now is: move them out (same design, same roles)
		local moves = { { "Crane", V(100, 0, 58) }, { "Silo", V(88, 0, 96) } }
		if hubFrame then
			for _, mv in moves do
				local parts = {}
				local cx, cz, n = 0, 0, 0
				for _, d in hubFrame:GetChildren() do
					if d:IsA("BasePart") and string.sub(d.Name, 1, #mv[1]) == mv[1] then
						table.insert(parts, d)
						if d.Name == mv[1] .. "Foot" or d.Name == "SiloFrameBase" then
							cx, cz, n = d.Position.X, d.Position.Z, 1
						end
					end
				end
				if n > 0 then
					local delta = V(mv[2].X - cx, 0, mv[2].Z - cz)
					for _, d in parts do
						d.CFrame += delta
					end
				end
			end
		end
	end
	-- scenery trees on or right next to the site are parked
	for _, t in decorF:GetChildren() do
		if t:IsA("Model") and t.Name == "Tree" and flatDist(t:GetPivot().Position, C) < SKIRT_OUT + 8 then
			park(t, "Trees")
		end
	end

	-- the spawn gate pylons stood where the deck edge now is
	if hub then
		for _, d in hub:GetChildren() do
			if d:IsA("BasePart") and (d.Name == "GateColumn" or d.Name == "GateCap" or d.Name == "GateFoot") and flatDist(d.Position, C) < SKIRT_OUT + 2 then
				d:Destroy()
			end
		end
	end

	return string.format("deck %d / collar %d studs, pylons %d, road trims %d, site parts %d, tier 1 shifted: %s", DECK * 2, SKIRT_OUT * 2, pylons, trimmed, added, table.concat(shifted, ", "))
end
