--!nonstrict
-- EDIT-TIME helper for WorldBuilder (not used at runtime): ART RESET PASS 2, the core environment rebuild.
-- Terrain silhouette, roads, hub composition, intentional tree clusters and the weak surfaces Pass 1 exposed. Each area is ONE
-- composition: the terrain makes the space, the road follows it, tree groups frame it. Own random streams only (the locked
-- layout, resource nodes and routes never move); nothing here is scatter. Lives in its own module because WorldBuilder is at
-- the script-size and local-register limits. WorldBuilder.Build() calls it with its shared helpers (ctx).
return function(ctx)
	local V, M, Terrain = Vector3.new, Enum.Material, workspace.Terrain
	local world, decorF, ROADS, ROAD_TOP, ZONE_R = ctx.world, ctx.decorF, ctx.ROADS, ctx.ROAD_TOP, ctx.ZONE_R
	local SPAWN, TRAIN_CENTER, ResourceSpotConfig, GRASSY = ctx.SPAWN, ctx.TRAIN_CENTER, ctx.ResourceSpotConfig, ctx.GRASSY
	local landform, clearOf, roadClear, flatDist, groundAt = ctx.landform, ctx.clearOf, ctx.roadClear, ctx.flatDist, ctx.groundAt
	local terrainEdit, plantLater, folder, P, park, tint = ctx.terrainEdit, ctx.plantLater, ctx.folder, ctx.P, ctx.park, ctx.tint
	local artReset2Terrain, plantClusters, artReset2Finish


	-- broad, low landforms that give the hub and the north Wood stretch a shape (fewer, larger terrain decisions)
	local HUB_FORMS = {
		{ V(124, 0, 170), 42, 10 }, -- east: a broad rise behind the Worker post
		{ V(-58, 0, 248), 44, 9 }, -- south-west, past the Training Yard
		{ V(36, 0, 238), 54, 12 }, -- south: the backdrop rise behind the spawn
		{ V(-128, 0, -94), 34, 13 }, -- north Wood: one shoulder between the Timber and Steel roads (the framed beat of the route)
	}
	-- Tier 1 work zones: one low berm on the outer side of each, so the zone reads as a small natural work pocket
	local WORK_BERMS = { Quarry = M.Rock, Mine = M.LeafyGrass, Energy = M.LeafyGrass, Forest = M.LeafyGrass }

	-- the hub ground: compacted warm earth around the spawn reaching west into the Training Yard floor, a ring of worked ground
	-- where the plaza meets the lawn, grass at the edges (no giant slab, no checkerboard)
	local function hubGround()
		-- one clean material per surface: worked earth (Ground) ringing the construction plaza; the spawn stands on the same warm
		-- sandstone as the Training Yard floor, joined to it by one band (one hub floor); tidy edges (low noise), lawn beyond
		local function segDist(x: number, z: number, a: Vector3, b: Vector3): number
			local ab = V(b.X - a.X, 0, b.Z - a.Z)
			local t = math.clamp(((x - a.X) * ab.X + (z - a.Z) * ab.Z) / ab:Dot(ab), 0, 1)
			return math.sqrt((x - a.X - ab.X * t) ^ 2 + (z - a.Z - ab.Z * t) ^ 2)
		end
		terrainEdit(-120, -84, 90, 170, -8, 4, function(x, _y, z, mat)
			if not GRASSY[mat] then
				return nil
			end
			local n = math.noise(x / 24, z / 24, 3.3)
			if math.sqrt(x * x + z * z) + n * 2.5 < 70 then
				return M.Ground
			end
			if ((x + 2) / 64) ^ 2 + ((z - 114) / 46) ^ 2 + n * 0.06 < 1 then
				return M.Sandstone
			end
			if segDist(x, z, V(-36, 0, 112), V(-64, 0, 118)) + n * 2 < 15 then
				return M.Sandstone
			end
			return nil
		end)
	end

	artReset2Terrain = function()
		for _, f in HUB_FORMS do
			if clearOf(f[1], f[2], 4) then
				landform(f[1], f[2], f[3], f[4])
			end
		end
		for _, spot in ResourceSpotConfig.List() do
			local mat = WORK_BERMS[spot.Id]
			if mat then
				local out = V(spot.Position.X, 0, spot.Position.Z).Unit
				for _, da in { 0, 0.5, -0.5, 1, -1 } do
					local dir = CFrame.Angles(0, da, 0):VectorToWorldSpace(out)
					-- (colossal site) a moved Tier 1 zone is generated at its old spot and shifted out later: place the berm
					-- where it will sit relative to the zone after the shift
					local p = spot.Position + dir * (ZONE_R[1] + 30) + (spot.GenOffset or Vector3.zero)
					if clearOf(p, 18, 3) then
						landform(p, 18, 8, mat)
						break
					end
				end
			end
		end
		hubGround()
	end

	-- TREE CLUSTERS: authored groups (one lead tree, a few smaller ones leaning off it), same tree family, three sizes only
	-- (small 1.0, medium 1.35, hero 2.3). Placed on the new landforms and at route beats; never on a road, a zone or the hub.
	local CLUSTERS = {
		{ V(128, 0, 174), "round", 5, 2.3 }, -- hub east rise
		{ V(-58, 0, 252), "mixed", 5, 1.35 }, -- hub south-west rise
		{ V(44, 0, 244), "round", 4, 1.35 }, -- hub south backdrop
		{ V(-134, 0, -100), "mixed", 5, 2.3 }, -- north Wood shoulder (hero)
		{ V(-152, 0, -64), "pine", 4, 1.35 }, -- north Wood, by the creek bend
	}
	plantClusters = function()
		local cr = Random.new(2468)
		local existing = {}
		for _, t in decorF:GetChildren() do
			if t:IsA("Model") and t.Name == "Tree" then
				table.insert(existing, t:GetPivot().Position)
			end
		end
		local function ok(p: Vector3, r: number): boolean
			if not roadClear(p, r, 3) or flatDist(p, V(0, 0, 0)) < 74 or flatDist(p, SPAWN) < 58 or flatDist(p, TRAIN_CENTER) < 78 then
				return false
			end
			for _, spot in ResourceSpotConfig.List() do
				if flatDist(p, spot.Position) < ZONE_R[spot.Tier] + r + 2 then
					return false
				end
			end
			for _, q in existing do
				if flatDist(p, q) < 7 then
					return false
				end
			end
			return true
		end
		for _, g in CLUSTERS do
			local c, kind, n, lead = g[1], g[2], g[3], g[4]
			local placed = 0
			if ok(c, 12) then
				plantLater(c, if kind == "mixed" then "round" else kind, lead)
				table.insert(existing, c)
			end
			for _ = 1, 30 do
				if placed >= n - 1 then
					break
				end
				local a = cr:NextNumber(0, math.pi * 2)
				local r = cr:NextNumber(8, 15)
				local p = c + V(math.cos(a) * r, 0, math.sin(a) * r)
				local s = if cr:NextNumber() < 0.6 then 1 else 1.35
				if ok(p, 7) then
					plantLater(p, if kind == "mixed" then (if placed % 2 == 0 then "pine" else "round") else kind, s)
					table.insert(existing, p)
					placed += 1
				end
			end
		end
	end

	-- ROADS: one raised road body for every paved road: a dark asphalt body with a sloped warm-concrete shoulder on each side
	-- and a ramp at every road end (no vertical lip anywhere: vehicle hulls slide straight on and off). Built from as few
	-- straight segments as the curve allows (a new segment only where the heading turns > 5 degrees or after 44 studs), so
	-- curves read as one flowing route. Same centre line and width as before; the terrain road stays underneath.
	local ROAD_BODY = Color3.fromRGB(88, 88, 94)
	local ROAD_EDGE = Color3.fromRGB(162, 156, 146)
	local SHOULDER_W = 2.6
	local function roadBodies(): number
		local paths = world:FindFirstChild("Paths") or folder(world, "Paths")
		local bridge = V(-170, 0, -40)
		local count = 0
		local function ramp(at: Vector3, out: Vector3, width: number, top: number)
			local h = top + 0.05
			local c = at + out * 1.6
			local cf = CFrame.lookAt(V(c.X, -0.05 + h / 2, c.Z), V(c.X, -0.05 + h / 2, c.Z) + out)
			local w = Instance.new("WedgePart")
			w.Name = "RoadRamp"
			w.Anchored = true
			w.Size = V(width, h, 3.2)
			w.CFrame = cf
			w.Color = ROAD_BODY
			w.Material = M.Asphalt
			w.CastShadow = false
			w.Parent = paths
			count += 1
		end
		for ri, road in ROADS do
			if not road.Dirt then
				-- the back road meets two main roads: a hair lower so the overlaps never z-fight (no step a hull can feel)
				local top = ROAD_TOP - (if road.Name == "BackRoad" then 0.015 else 0)
				local runs, cur = {}, {}
				for _, p in road.Samples do
					local inside = p.Magnitude < 57 or (ri == 1 and flatDist(p, bridge) < 10)
					if inside then
						if #cur > 1 then
							table.insert(runs, cur)
						end
						cur = {}
					else
						table.insert(cur, p)
					end
				end
				if #cur > 1 then
					table.insert(runs, cur)
				end
				for _, pts in runs do
					local i0 = 1
					while i0 < #pts do
						local d0 = (pts[i0 + 1] - pts[i0]).Unit
						local j = i0 + 1
						while j < #pts do
							local dj = (pts[j + 1] - pts[j]).Unit
							if d0:Dot(dj) < math.cos(math.rad(5)) or (pts[j + 1] - pts[i0]).Magnitude > 44 then
								break
							end
							j += 1
						end
						local a, b = pts[i0], pts[j]
						-- runs that stop at the bridge reach the deck end, so there is no gap between road and deck
						local atBridgeB = ri == 1 and flatDist(b, bridge) < 14 and j == #pts
						local atBridgeA = ri == 1 and flatDist(a, bridge) < 14 and i0 == 1
						if atBridgeB then
							b += (b - a).Unit * math.max(0, flatDist(b, bridge) - 9)
						end
						if atBridgeA then
							a += (a - b).Unit * math.max(0, flatDist(a, bridge) - 9)
						end
						local len = (b - a).Magnitude + 2.4
						local mid = (a + b) / 2
						local cf = CFrame.lookAt(V(mid.X, 0, mid.Z), V(b.X, 0, b.Z))
						P(paths, { Name = "RoadBody", Size = V(road.Width, 1, len), CFrame = cf * CFrame.new(0, top - 0.5, 0), Color = ROAD_BODY, Material = M.Asphalt, CastShadow = false })
						count += 1
						-- sloped shoulders: high against the body, low at the verge
						for _, sx in { -1, 1 } do
							local c = (cf * CFrame.new(sx * (road.Width / 2 + SHOULDER_W / 2), 0, 0)).Position
							local out = cf.RightVector * sx
							local h = top - 0.03 + 0.05
							local w = Instance.new("WedgePart")
							w.Name = "RoadShoulder"
							w.Anchored = true
							w.Size = V(len, h, SHOULDER_W)
							w.CFrame = CFrame.lookAt(V(c.X, -0.05 + h / 2, c.Z), V(c.X, -0.05 + h / 2, c.Z) + out)
							w.Color = ROAD_EDGE
							w.Material = M.Concrete
							w.CastShadow = false
							w.Parent = paths
							count += 1
						end
						-- road ends (plaza, destinations): a ramp down to the ground instead of an edge
						local dir = (b - a).Unit
						if i0 == 1 and not atBridgeA then
							ramp(a - dir * 1.2, -dir, road.Width + SHOULDER_W * 2, top)
						end
						if j == #pts and not atBridgeB then
							ramp(b + dir * 1.2, dir, road.Width + SHOULDER_W * 2, top)
						end
						i0 = j
					end
				end
			end
		end
		-- the bridge deck rises with the road body (rails, posts, piers and abutments move with it)
		for _, d in paths:GetChildren() do
			if d:IsA("BasePart") and (string.find(d.Name, "^Bridge") or d.Name == "Abutment" or d.Name == "WingWall") then
				d.CFrame += V(0, ROAD_TOP, 0)
			end
		end
		return count
	end

	-- GROVE: every ancient tree is grounded. The trunk and flare reach down to the lowest ground under them, a low mound of grove
	-- floor wraps the base, and each buttress root dives into the ground at its outer end (no floating flares or root tips)
	local function groveGround()
		local z = world.Zones:FindFirstChild("AncientGrove")
		if not z then
			return
		end
		local trunks = {}
		for _, d in z:GetChildren() do
			if d.Name == "AncientTrunk" then
				table.insert(trunks, d)
			end
		end
		for _, trunk in trunks do
			local p = trunk.Position
			local flare
			for _, d in z:GetChildren() do
				if d.Name == "TrunkFlare" and flatDist(d.Position, p) < 1 then
					flare = d
				end
			end
			local R = (if flare then flare.Size.Y else trunk.Size.Y) / 2
			local gc = groundAt(p.X, p.Z)
			local gmin, gmax = gc, gc
			for k = 0, 11 do
				local a = k / 12 * math.pi * 2
				local g = groundAt(p.X + math.cos(a) * R * 1.1, p.Z + math.sin(a) * R * 1.1)
				gmin, gmax = math.min(gmin, g), math.max(gmax, g)
			end
			-- a low mound of grove floor around the base (raises the downhill side to meet the flare)
			local mr = R * 1.6
			Terrain:FillBall(V(p.X, (gmin + gc) / 2 - mr * 0.72, p.Z), mr, M.LeafyGrass)
			local top = p.Y + trunk.Size.X / 2
			local bottom = gmin - 2
			trunk.Size = V(top - bottom, trunk.Size.Y, trunk.Size.Z)
			trunk.CFrame = CFrame.new(p.X, (top + bottom) / 2, p.Z) * CFrame.Angles(0, 0, math.rad(90))
			if flare then
				local ftop = gc + 5
				flare.Size = V(ftop - bottom, flare.Size.Y, flare.Size.Z)
				flare.CFrame = CFrame.new(p.X, (ftop + bottom) / 2, p.Z) * CFrame.Angles(0, 0, math.rad(90))
			end
			for _, r in z:GetChildren() do
				if r.Name == "Root" and r:IsA("BasePart") and flatDist(r.Position, p) < 30 then
					local look = r.CFrame.LookVector
					local L = r.Size.Z
					local r0, r1 = r.Position - look * L / 2, r.Position + look * L / 2
					r1 = V(r1.X, groundAt(r1.X, r1.Z) - 1.2, r1.Z)
					r.Size = V(r.Size.X, r.Size.Y, (r1 - r0).Magnitude)
					r.CFrame = CFrame.lookAt((r0 + r1) / 2, r1)
					-- a root that would still hang over the slope anywhere along its length is removed (parked)
					for _, t in { 0.5, 0.8 } do
						local q = r0:Lerp(r1, t)
						if q.Y - r.Size.Y * 0.5 > groundAt(q.X, q.Z) + 1 then
							park(r, "Misc")
							break
						end
					end
				end
			end
		end
	end

	-- weak surfaces exposed by Pass 1: cooling towers, quarry blocks, crater crystals, training mats, trees inside industry
	local function weakSpots(): string
		local zones = world:FindFirstChild("Zones")
		local notes = {}
		-- POWER PLANT cooling towers: pale warm-grey shell, a darker structural base ring, a muted rust band (silhouette unchanged)
		local plant = zones and zones:FindFirstChild("ReactorYard")
		if plant then
			local towers = {}
			for _, d in plant:GetChildren() do
				if d.Name == "Tower" then
					table.insert(towers, d)
				end
			end
			local n = 0
			for _, t in towers do
				local lowest = true
				for _, o in towers do
					if o ~= t and flatDist(o.Position, t.Position) < 2 and o.Position.Y < t.Position.Y then
						lowest = false
					end
				end
				t.Material = M.Concrete
				t.Color = if lowest then Color3.fromRGB(118, 122, 130) else Color3.fromRGB(190, 188, 182)
				n += 1
			end
			for _, d in plant:GetChildren() do
				if d.Name == "TowerBand" then
					d.Color = Color3.fromRGB(150, 98, 80)
					d.Material = M.Concrete
				elseif d.Name == "TurbineHall" then
					d.Color = Color3.fromRGB(176, 178, 182)
				end
			end
			table.insert(notes, "towers " .. n)
		end
		-- QUARRY blocks: warm neutral processed stone (no near-white), the cut face behind them darker so the stacks read against it
		local quarry = zones and zones:FindFirstChild("DeepQuarry")
		if quarry then
			local k = 0
			for _, d in quarry:GetDescendants() do
				if d:IsA("BasePart") then
					local par = d.Parent and d.Parent.Name
					if par == "BlockStack" or d.Name == "HangingBlock" or (d.Name == "Cap" or d.Name == "Foot") and quarry:FindFirstChild("HangingBlock") and flatDist(d.Position, quarry.HangingBlock.Position) < 4 then
						k += 1
						local base = ({ Color3.fromRGB(166, 150, 126), Color3.fromRGB(156, 140, 116), Color3.fromRGB(174, 158, 134) })[k % 3 + 1]
						d.Color = if d.Name == "Cap" then tint(base, 0.06) elseif d.Name == "Foot" then tint(base, -0.25) else base
						d.Material = if d.Name == "Cap" or d.Name == "Foot" then M.SmoothPlastic else M.Concrete
					elseif d.Name == "CutFace" then
						d.Color = Color3.fromRGB(128, 108, 86)
					elseif d.Name == "CutLine" then
						d.Color = Color3.fromRGB(100, 84, 66)
					end
				end
			end
			table.insert(notes, "quarry parts " .. k)
		end
		-- STAR CRATER: the heart crystals get a subtle emissive body (dark-ish neon, so they glow without blooming) and the heart
		-- keeps ONE low-range light; walls and floor stay unlit
		local crater = zones and zones:FindFirstChild("StarCrater")
		if crater then
			for _, d in crater:GetChildren() do
				if d.Name == "HeartCrystal" then
					d.Material = M.Neon
					d.Color = Color3.fromRGB(30, 92, 140):Lerp(Color3.fromRGB(44, 112, 164), (d.Size.Y - 7) / 8)
					d.Transparency = 0.12
				elseif d.Name == "HeartGlow" then
					d.Color = Color3.fromRGB(90, 170, 220)
					d.Transparency = 0.55
					local l = d:FindFirstChildOfClass("PointLight")
					if l then
						l.Range = 16
						l.Brightness = 1.1
					end
				end
			end
		end
		-- TRAINING YARD: the coloured mats and the race strip calm down toward the hub ground (a construction-training corner, not a
		-- glowing gym); the gate banners keep their colour for readability
		local yard = world:FindFirstChild("Areas") and world.Areas:FindFirstChild("TrainingYard")
		if yard then
			local dirt = Color3.fromRGB(176, 150, 116)
			for _, d in yard:GetDescendants() do
				if d:IsA("BasePart") then
					if d.Name == "ZoneMat" then
						d.Color = d.Color:Lerp(dirt, 0.55)
					elseif d.Name == "TrackStrip" then
						d.Color = Color3.fromRGB(176, 118, 96)
					elseif d.Name == "Side" or d.Name == "Console" or d.Name == "Pad" then
						-- equipment keeps its colour code (blue = speed, orange = strength), one step calmer
						d.Color = d.Color:Lerp(Color3.fromRGB(70, 76, 90), 0.3)
					end
				end
			end
		end
		-- METAL: no natural trees inside the industrial footprints
		local parkedTrees = 0
		for _, id in { "Mine", "IndustrialYard", "SteelWorks" } do
			for _, spot in ResourceSpotConfig.List() do
				if spot.Id == id then
					for _, t in decorF:GetChildren() do
						if t:IsA("Model") and t.Name == "Tree" and flatDist(t:GetPivot().Position, spot.Position) < ZONE_R[spot.Tier] + 12 then
							park(t, "Trees")
							parkedTrees += 1
						end
					end
				end
			end
		end
		table.insert(notes, "industry trees parked " .. parkedTrees)
		-- Pass 1 parked some chunk() bodies (moss rocks, extra meteors); their thin cap and foot plates were left floating
		local orphans = 0
		for _, d in world:GetDescendants() do
			if d:IsA("BasePart") and (d.Name == "Cap" or d.Name == "Foot") and d.Parent then
				local body = false
				for _, o in d.Parent:GetChildren() do
					if o ~= d and o:IsA("BasePart") and o.Name ~= "Cap" and o.Name ~= "Foot" then
						local rel = o.CFrame:PointToObjectSpace(d.Position)
						if math.abs(rel.X) < 0.5 and math.abs(rel.Z) < 0.5 and math.abs(rel.Y) < o.Size.Y / 2 + 0.3 then
							body = true
							break
						end
					end
				end
				if not body then
					park(d, "Scatter")
					orphans += 1
				end
			end
		end
		table.insert(notes, "orphan plates parked " .. orphans)
		return table.concat(notes, ", ")
	end

	-- POWER stays clean and maintained (the contrast to rough Stone and Metal): no dirt blotches on the power grounds or along
	-- the power road; earth inside a power zone becomes paving, outside it becomes short lawn
	local function powerTidy()
		local areas = {}
		for _, spot in ResourceSpotConfig.List() do
			if spot.Id == "Energy" or spot.Id == "ReactorYard" or spot.Id == "CoreVault" then
				table.insert(areas, { spot.Position, ZONE_R[spot.Tier] })
			end
		end
		for _, road in ROADS do
			if road.Name == "PowerRoad" then
				for i = 1, #road.Samples, 3 do
					local p = road.Samples[i]
					if p.Magnitude > 90 then
						table.insert(areas, { p, 0 })
					end
				end
			end
		end
		for _, a in areas do
			local c, zr = a[1], a[2]
			local R = zr + 22
			terrainEdit(c.X - R, c.Z - R, c.X + R, c.Z + R, -8, 6, function(x, _y, z, mat)
				if mat ~= M.Ground and mat ~= M.Mud and mat ~= M.Cobblestone then
					return nil
				end
				local d = math.sqrt((x - c.X) ^ 2 + (z - c.Z) ^ 2)
				if d > R then
					return nil
				end
				return if d < zr then M.Pavement else M.LeafyGrass
			end)
		end
	end

	artReset2Finish = function(): string
		local roadParts = roadBodies()
		groveGround()
		powerTidy()
		return "road parts " .. roadParts .. ", " .. weakSpots()
	end

	return { terrain = artReset2Terrain, plantClusters = plantClusters, finish = artReset2Finish }
end
