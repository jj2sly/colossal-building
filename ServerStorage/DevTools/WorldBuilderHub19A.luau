--!nonstrict
-- PASS 19A: CENTRAL HUB SPACING + CIRCULATION. Runs last in WorldBuilder.Build (and can be run once on an existing built world).
--
--   BUILD PAD (collar, r 90-106)
--   -> PEDESTRIAN APRON: terrain Concrete, r 106-124 (flush, no parts; the site pylon footings sit in its inner 8 studs)
--   -> VEHICLE LANE: asphalt ring, 20 wide, centred r ~134 (r 124-144), bulged outward on the south-east so the Pass 14D crane and silo
--      cluster stay where they are; broad dashed centre line
--   -> SPAWN / Worker Post / Training Yard / loading deck: moved back SHIFT studs (the Yard also west) so they sit outside the lane
--
-- The four resource roads are cut back to the lane and meet it through short ramps. Nothing here moves the pad, resource zones, the crane or silos.
local ServerStorage = game:GetService("ServerStorage")

local V = Vector3.new
local M = Enum.Material

local SHIFT = 60 -- the spawn cluster (spawn, forecourt, loading deck, lamps, Worker Post) moves back this far (+Z)
local YARD_DX = -20 -- the Training Yard moves back and a little west so its corner clears the lane
local LANE_W = 20
local APRON_IN, APRON_OUT = 106, 124 -- the pylon footings take r 105-114, so the clear walking band is r 114-124
local N = 72

local function centerR(th: number): number
	local deg = math.deg(th) % 360
	if deg > 180 then
		deg -= 360
	end
	local d = (deg - 32) / 30
	return 134 + 50 * math.exp(-(d * d))
end

local pts = {}
for i = 1, N do
	local th = 2 * math.pi * (i - 1) / N
	local r = centerR(th)
	pts[i] = V(math.cos(th) * r, 0, math.sin(th) * r)
end

local function laneDist(x: number, z: number): number
	local best = 1e9
	for i = 1, N do
		local a, b = pts[i], pts[i % N + 1]
		local abx, abz = b.X - a.X, b.Z - a.Z
		local t = math.clamp(((x - a.X) * abx + (z - a.Z) * abz) / (abx * abx + abz * abz), 0, 1)
		local dx, dz = x - a.X - abx * t, z - a.Z - abz * t
		best = math.min(best, math.sqrt(dx * dx + dz * dz))
	end
	return best
end

local function radial(x: number, z: number): (number, number)
	return math.sqrt(x * x + z * z), math.atan2(z, x)
end

local function posOf(i: Instance): Vector3?
	if i:IsA("Model") then
		return i:GetPivot().Position
	elseif i:IsA("BasePart") then
		return i.Position
	end
	local first = i:FindFirstChildWhichIsA("BasePart", true)
	return first and first.Position or nil
end

local function shiftInstance(i: Instance, dx: number, dz: number)
	if i:IsA("Model") then
		i:PivotTo(i:GetPivot() + V(dx, 0, dz))
	elseif i:IsA("BasePart") then
		i.CFrame += V(dx, 0, dz)
	elseif i:IsA("Folder") then
		for _, c in i:GetChildren() do
			shiftInstance(c, dx, dz)
		end
	end
end

-- read/modify/write terrain voxels (resolution 4); fn(x, y, z, material, occupancy) -> newMaterial?, newOccupancy?
local function terrainEdit(x0: number, x1: number, z0: number, z1: number, y0: number, y1: number, fn)
	local Terrain = workspace.Terrain
	local region = Region3.new(V(x0, y0, z0), V(x1, y1, z1)):ExpandToGrid(4)
	local mats, occs = Terrain:ReadVoxels(region, 4)
	local size = mats.Size
	local origin = region.CFrame.Position - region.Size / 2
	for ix = 1, size.X do
		local x = origin.X + (ix - 0.5) * 4
		for iy = 1, size.Y do
			local y = origin.Y + (iy - 0.5) * 4
			for iz = 1, size.Z do
				local z = origin.Z + (iz - 0.5) * 4
				local nm, no = fn(x, y, z, mats[ix][iy][iz], occs[ix][iy][iz])
				if nm then
					mats[ix][iy][iz] = nm
				end
				if no then
					occs[ix][iy][iz] = no
				end
			end
		end
	end
	Terrain:WriteVoxels(region, 4, mats, occs)
end

return function(ctx)
	local world = ctx.world
	local GRASSY = { [M.Grass] = true, [M.LeafyGrass] = true }
	local hub, areas = world:FindFirstChild("Hub"), world:FindFirstChild("Areas")
	local frame = hub and hub:FindFirstChild("HubFrame")
	-- idempotent: re-running with new SHIFT / YARD_DX moves things by the difference and rebuilds the lane
	local folder = world:FindFirstChild("CirculationHub")
	local oldShift, oldYard = 0, 0
	if folder then
		oldShift, oldYard = folder:GetAttribute("Shift") or 0, folder:GetAttribute("YardDx") or 0
		folder:ClearAllChildren()
	else
		folder = Instance.new("Folder")
		folder.Name = "CirculationHub"
		folder.Parent = world
	end
	folder:SetAttribute("Shift", SHIFT)
	folder:SetAttribute("YardDx", YARD_DX)
	local dShift, dYard = SHIFT - oldShift, YARD_DX - oldYard
	local moved, removed, added = 0, 0, 0

	------------------------------------------------------------------- 1. MOVE THE SPAWN CLUSTER BACK
	for _, c in hub:GetChildren() do
		if c ~= frame then
			shiftInstance(c, 0, dShift) -- SpawnLocation, SpawnPad, SpawnRing, lamps, Worker apron
			moved += 1
		end
	end
	for _, p in frame:GetChildren() do
		if p.Name == "WorkPath" or p.Name == "WorkPathEdge" then
			-- the plated path now runs from the forecourt's west edge to the (moved) Yard threshold
			local xEnd = -62 + YARD_DX -- the Yard threshold
			p.Size = V(-30 - xEnd, p.Size.Y, p.Size.Z)
			p.CFrame = CFrame.new((-30 + xEnd) / 2, p.Position.Y, p.Position.Z + dShift)
		elseif p.Name == "YardThreshold" then
			shiftInstance(p, dYard, dShift)
		else
			shiftInstance(p, 0, dShift)
		end
		moved += 1
	end
	-- the spawn plaza discs shrink so the plaza sits outside the lane
	local ring, pad = hub:FindFirstChild("SpawnRing"), hub:FindFirstChild("SpawnPad")
	if ring then
		ring.Size = V(ring.Size.X, 36, 36)
	end
	if pad then
		pad.Size = V(pad.Size.X, 28, 28)
	end
	local worker = world:FindFirstChild("WorkerStation")
	if worker then
		shiftInstance(worker, 0, dShift)
		moved += 1
	end
	local yard = areas and areas:FindFirstChild("TrainingYard")
	if yard then
		shiftInstance(yard, dYard, dShift)
		moved += 1
	end

	------------------------------------------------------------------- 2. CLEAR THE OLD ROADS / DECOR FROM THE NEW CIRCULATION AREA
	local paths = world:FindFirstChild("Paths")
	if paths then
		for _, p in paths:GetChildren() do
			if p:IsA("BasePart") then
				local r, th = radial(p.Position.X, p.Position.Z)
				local margin = r - (centerR(th) + LANE_W / 2)
				if margin < 8 then
					p:Destroy()
					removed += 1
				end
			end
		end
	end
	local function inFootprint(x: number, z: number): boolean
		local r = math.sqrt(x * x + z * z)
		if r < APRON_OUT + 2 and r > 100 then
			return true
		end
		if laneDist(x, z) < LANE_W / 2 + 4 then
			return true
		end
		if x > -78 and x < 92 and z > 140 and z < 262 then
			return true -- the moved spawn cluster
		end
		if x > -194 and x < -70 and z > 114 and z < 270 then
			return true -- the moved Training Yard
		end
		return false
	end
	for _, fname in { "Scenery", "ZonePolish" } do
		local f = world:FindFirstChild(fname)
		if f then
			for _, c in f:GetChildren() do
				local p = posOf(c)
				if p and inFootprint(p.X, p.Z) then
					c:Destroy()
					removed += 1
				end
			end
		end
	end
	-- multi-part props whose centre is outside the lane but whose pieces reach into it
	for _, fname in { "Scenery", "ZonePolish" } do
		local f = world:FindFirstChild(fname)
		if f then
			for _, d in f:GetDescendants() do
				if d:IsA("BasePart") and laneDist(d.Position.X, d.Position.Z) - math.max(d.Size.X, d.Size.Z) / 2 < LANE_W / 2 + 1 then
					d:Destroy()
					removed += 1
				end
			end
		end
	end

	------------------------------------------------------------------- 3. TERRAIN: carve hills out of the lane / yard, repaint the hub ground
	-- (flat ground is a full cell at y -8..-4 plus a HALF-full cell at -4..0 = surface at 0; a hill has that cell full, so clamp it too)
	terrainEdit(-215, 215, -215, 280, -8, 28, function(x, y, z, mat, occ)
		if y < -4 then
			return nil
		end
		local cut = laneDist(x, z) < LANE_W / 2 + 14 or (x > -196 and x < -68 and z > 112 and z < 272) or (x > -80 and x < 94 and z > 138 and z < 262)
		if not cut then
			return nil
		end
		if y > 0 then
			return M.Air, 0
		end
		if occ > 0.5 then
			return nil, 0.5
		end
		return nil
	end)
	-- yard rounded rectangle (same warm sandstone as before, moved with the Yard)
	local ytc = V(-112 + YARD_DX, 0, 128 + SHIFT)
	local yx0, yx1, yz0, yz1, corner = ytc.X - 50, ytc.X + 50, ytc.Z - 63, ytc.Z + 63, 16
	terrainEdit(-215, 215, 40, 280, -8, 4, function(x, _y, z, mat)
		local r = math.sqrt(x * x + z * z)
		-- old cluster / old yard / old work-yard ground back to lawn (outside the deck)
		if r >= 88 and x > -196 and x < 82 and z > 52 and z < 214 and (mat == M.Sandstone or mat == M.Ground) then
			mat = M.Grass
		end
		-- old spoke roads inside the lane back to lawn
		local _, th = radial(x, z)
		if r >= 88 and r < centerR(th) + LANE_W / 2 + 8 and (mat == M.Asphalt or mat == M.Limestone or mat == M.Sandstone or mat == M.Ground) then
			mat = M.Grass
		end
		-- pedestrian apron: flush concrete ring around the pad
		if r >= APRON_IN and r < APRON_OUT then
			mat = M.Concrete
		end
		-- new yard floor + spawn plaza ground + Worker work-yard
		if GRASSY[mat] or mat == M.Grass then
			local cx = math.clamp(x, yx0 + corner, yx1 - corner)
			local cz = math.clamp(z, yz0 + corner, yz1 - corner)
			if (x - cx) ^ 2 + (z - cz) ^ 2 <= corner * corner then
				mat = M.Sandstone
			elseif r >= 146 and (x / 64) ^ 2 + ((z - (112 + SHIFT)) / 42) ^ 2 < 1 then
				mat = M.Sandstone
			end
			if (((x - 54) / 22) ^ 2 + ((z - (130 + SHIFT)) / 26) ^ 2) < 1 then
				mat = M.Ground
			end
		end
		return mat, nil
	end)

	------------------------------------------------------------------- 4. THE VEHICLE LANE (flush: top +0.14, under the 0.2 vehicle lip)
	local ASPH, DASH = Color3.fromRGB(88, 88, 94), Color3.fromRGB(236, 196, 84)
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material)
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame, p.Color, p.Material = name, size, cf, color, mat
		p.Anchored, p.TopSurface, p.BottomSurface = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = folder
		added += 1
		return p
	end
	for i = 1, N do
		local a, b = pts[i], pts[i % N + 1]
		local len = (b - a).Magnitude
		local mid = (a + b) / 2
		part("LaneBody", V(LANE_W, 1, len + 3), CFrame.lookAt(mid + V(0, -0.36, 0), b + V(0, -0.36, 0)), ASPH, M.Asphalt)
		if i % 2 == 0 then
			part("LaneDash", V(0.9, 0.06, math.min(7, len * 0.55)), CFrame.lookAt(mid + V(0, 0.16, 0), b + V(0, 0.16, 0)), DASH, M.SmoothPlastic).CanCollide = false
		end
	end

	------------------------------------------------------------------- 5. RECONNECT THE SPOKE ROADS: one ramp per road, raised road end down onto the lane
	-- the remaining RoadBody nearest the lane (per road) keeps its raised top (+0.42); a wedge runs from its inner end to the lane edge so
	-- no 0.2+ lip stops a vehicle
	local cands = {}
	if paths then
		for _, p in paths:GetChildren() do
			if p:IsA("BasePart") and p.Name == "RoadBody" then
				local look = p.CFrame.LookVector
				look = V(look.X, 0, look.Z).Unit
				if look:Dot(-V(p.Position.X, 0, p.Position.Z)) < 0 then
					look = -look
				end
				local innerEnd = p.Position + look * (p.Size.Z / 2)
				local r, th = radial(innerEnd.X, innerEnd.Z)
				local gap = r - (centerR(th) + LANE_W / 2)
				if gap < 25 and p.Size.Z > 5 then
					table.insert(cands, { part = p, gap = gap, th = th, look = look, innerEnd = innerEnd })
				end
			end
		end
	end
	local best = {}
	for _, c in cands do
		local hit
		for k, b in best do
			local dth = math.abs((c.th - b.th + math.pi) % (2 * math.pi) - math.pi)
			if dth < math.rad(14) then
				hit = k
				break
			end
		end
		if hit then
			if c.gap < best[hit].gap then
				best[hit] = c
			end
		else
			table.insert(best, c)
		end
	end
	for _, c in best do
		local len = math.max(1.5 * math.max(c.gap, 0), 5)
		local from = V(c.innerEnd.X, 0.21, c.innerEnd.Z)
		local cf = CFrame.lookAt(from + c.look * (len / 2), from + c.look * (len / 2 + 1))
		local wedge = Instance.new("WedgePart")
		wedge.Name, wedge.Size, wedge.CFrame, wedge.Color, wedge.Material = "LaneRamp", V(c.part.Size.X, 0.42, len), cf, ASPH, M.Asphalt
		wedge.Anchored, wedge.Parent = true, folder
		added += 1
	end

	------------------------------------------------------------------- 6. PEDESTRIAN BYPASS (19A.1): the apron is blocked by the Pass 14D crane (angles ~24-34) and silos (~44-54)
	-- a flush 10-wide concrete path leaves the apron, runs round the OUTSIDE of both (r ~157, inside the lane's SE bulge) and rejoins it
	local BYP = { { 8, 119 }, { 14, 119 }, { 18, 135 }, { 22, 153 }, { 26, 157 }, { 46, 157 }, { 50, 152 }, { 54, 145 }, { 58, 136 }, { 62, 124 }, { 66, 119 } }
	local bp = {}
	for i = 1, #BYP - 1 do
		local a0, r0, a1, r1 = BYP[i][1], BYP[i][2], BYP[i + 1][1], BYP[i + 1][2]
		local steps = math.max(1, math.floor((a1 - a0) / 2))
		for k = 0, steps - 1 do
			local t = k / steps
			local sm = t * t * (3 - 2 * t)
			local th = math.rad(a0 + (a1 - a0) * t)
			local r = r0 + (r1 - r0) * sm
			table.insert(bp, V(math.cos(th) * r, 0, math.sin(th) * r))
		end
	end
	local th = math.rad(BYP[#BYP][1])
	table.insert(bp, V(math.cos(th) * BYP[#BYP][2], 0, math.sin(th) * BYP[#BYP][2]))
	for i = 1, #bp - 1 do
		local a, b = bp[i], bp[i + 1]
		local len = (b - a).Magnitude
		part("ApronBypass", V(10, 0.3, len + 1.2), CFrame.lookAt((a + b) / 2 + V(0, -0.05, 0), b + V(0, -0.05, 0)), Color3.fromRGB(176, 174, 168), M.Concrete)
	end
	for _, fname in { "Scenery", "ZonePolish" } do
		local f = world:FindFirstChild(fname)
		if f then
			for _, d in f:GetDescendants() do
				if d:IsA("BasePart") then
					for _, q in bp do
						if (V(d.Position.X, 0, d.Position.Z) - q).Magnitude < 8 + math.max(d.Size.X, d.Size.Z) / 2 then
							d:Destroy()
							removed += 1
							break
						end
					end
				end
			end
		end
	end

	return string.format("hub 19A: moved %d, removed %d, added %d parts (lane r124-144 + SE bulge, spawn +%d, ramps %d)", moved, removed, added, SHIFT, #best)
end
