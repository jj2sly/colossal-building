--!nonstrict
-- PASS 21H: map presence, terrain first. The valley was a flat grass disc with everything bunched in the middle; this adds
--   1. a continuous MOUNTAIN RING (r ~ 840-1060) so the valley is enclosed on every side (the west / south-west was open),
--   2. ROLLING HILLS in the empty meadows (never on roads, zones, pads or the hub: an occupancy grid of every built part keeps them clear),
--   3. FOREST CLUSTERS cloned from the existing scenery trees into the empty meadows (same rule),
--   4. a little rock dressing on the bigger hills.
-- Deterministic (seeded) so a rebuild gives the same valley. Terrain is additive; trees go in World.Scenery21H (rebuilt each run).
local V = Vector3.new
local M = Enum.Material

local CELL = 16

return function(ctx)
	local world = ctx.world
	local T = workspace.Terrain
	local rng = Random.new(2116)

	-- occupancy grid of everything built (with a margin), so terrain never swallows a road, zone or pad
	local occ = {}
	local function key(cx: number, cz: number)
		return cx * 100000 + cz
	end
	local function mark(x0, x1, z0, z1, margin)
		for cx = math.floor((x0 - margin) / CELL), math.floor((x1 + margin) / CELL) do
			for cz = math.floor((z0 - margin) / CELL), math.floor((z1 + margin) / CELL) do
				occ[key(cx, cz)] = true
			end
		end
	end
	local old = world:FindFirstChild("Scenery21H")
	if old then
		old:Destroy()
	end
	for _, d in world:GetDescendants() do
		if d:IsA("BasePart") and d.Position.Y > -500 and d.Position.Y < 200 then
			local h = d.Size.Magnitude / 2
			if h < 300 then
				-- existing scenery trees do not block (forests may grow next to them)
				local sc = world:FindFirstChild("Scenery")
				if not (sc and d:IsDescendantOf(sc)) then
					local margin = if d.Parent and d.Parent.Name == "Paths" then 34 else 26
					mark(d.Position.X - h, d.Position.X + h, d.Position.Z - h, d.Position.Z + h, margin)
				end
			end
		end
	end
	local function free(x: number, z: number, r: number): boolean
		for cx = math.floor((x - r) / CELL), math.floor((x + r) / CELL) do
			for cz = math.floor((z - r) / CELL), math.floor((z + r) / CELL) do
				if occ[key(cx, cz)] then
					return false
				end
			end
		end
		return true
	end

	-- 1. mountain ring
	local balls = 0
	for i = 0, if ctx.skipTerrain then -1 else 179 do
		local a = i / 180 * math.pi * 2 + rng:NextNumber(-0.01, 0.01)
		local r = rng:NextNumber(880, 1000)
		local x, z = math.cos(a) * r, math.sin(a) * r
		local rad = rng:NextNumber(70, 120)
		local y = rng:NextNumber(10, 70)
		T:FillBall(V(x, y, z), rad, M.Rock)
		T:FillBall(V(x * 1.06, y + rad * 0.55, z * 1.06), rad * 0.6, M.Slate)
		if rng:NextNumber() < 0.45 then
			T:FillBall(V(x * 1.08, y + rad * 0.95, z * 1.08), rad * 0.3, M.Snow)
		end
		-- grassy skirt facing the valley
		T:FillBall(V(math.cos(a) * (r - rad * 0.8), -rad * 0.35, math.sin(a) * (r - rad * 0.8)), rad * 0.75, M.Grass)
		balls += 4
		if i % 12 == 0 then
			task.wait()
		end
	end

	-- 2. rolling hills in the empty meadows (between the busy middle and the mountains)
	local hills = 0
	for _ = 1, if ctx.skipTerrain then 0 else 900 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(330, 800)
		local x, z = math.cos(a) * r, math.sin(a) * r
		local rad = rng:NextNumber(26, 60)
		if free(x, z, rad * 1.15) then
			T:FillBall(V(x, -rad * 0.55, z), rad, M.Grass)
			T:FillBall(V(x + rng:NextNumber(-rad, rad) * 0.5, -rad * 0.45, z + rng:NextNumber(-rad, rad) * 0.5), rad * 0.7, M.LeafyGrass)
			if rad > 48 and rng:NextNumber() < 0.5 then
				T:FillBall(V(x + rad * 0.3, rad * 0.25, z - rad * 0.2), rad * 0.22, M.Rock)
			end
			mark(x - rad, x + rad, z - rad, z + rad, 10)
			hills += 1
			if hills % 10 == 0 then
				task.wait()
			end
			if hills >= 70 then
				break
			end
		end
	end

	-- 3. forest clusters (clones of the existing scenery trees)
	local scenery = world:FindFirstChild("Scenery")
	local templates = {}
	if scenery then
		for _, m in scenery:GetChildren() do
			if m:IsA("Model") and m.Name == "Tree" then
				table.insert(templates, m)
			end
		end
	end
	local f = Instance.new("Folder")
	f.Name = "Scenery21H"
	f.Parent = world
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { T }
	local trees = 0
	if #templates > 0 then
		for _ = 1, 140 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(280, 820)
			local cx, cz = math.cos(a) * r, math.sin(a) * r
			if free(cx, cz, 30) then
				for _ = 1, rng:NextInteger(5, 11) do
					local x, z = cx + rng:NextNumber(-34, 34), cz + rng:NextNumber(-34, 34)
					if free(x, z, 6) then
						local hit = workspace:Raycast(V(x, 400, z), V(0, -600, 0), rp)
						if hit and hit.Material ~= M.Rock and hit.Material ~= M.Slate and hit.Material ~= M.Water then
							local t = templates[rng:NextInteger(1, #templates)]:Clone()
							local s = rng:NextNumber(0.8, 1.35)
							t:ScaleTo(t:GetScale() * s)
							local _, size = t:GetBoundingBox()
							local pivot = t:GetPivot()
							local bottom = select(1, t:GetBoundingBox()).Position.Y - size.Y / 2
							t:PivotTo(CFrame.new(x, hit.Position.Y + (pivot.Position.Y - bottom) - 0.4, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
							t.Parent = f
							trees += 1
						end
					end
				end
				mark(cx - 40, cx + 40, cz - 40, cz + 40, 0)
				task.wait()
			end
		end
	end
	return string.format("terrain21H: mountain ring (%d fills), %d hills, %d trees", balls, hills, trees)
end
