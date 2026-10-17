--!nonstrict
-- EDIT-TIME helper for WorldBuilder (not used at runtime): ART RESET PASS 4, hub + remaining hero landmarks + optimization.
-- Reference quality = the Steel Mine, the Energy Reactor, the big rock language and the redwoods (all left untouched here).
-- This pass: the hub becomes the construction heart (zoned ground, a ceremonial spawn->build axis, an anchored platform apron,
-- three framing forms), Training and the Worker Post join its material language, the Foundry gets a dominant blast-furnace
-- tower + charging bridge, the Power Plant one hero composition (hyperbolic towers + a landmark power gantry), the Quarry and
-- the Mountain Excavation become real excavations with one hero machine each, and the tree family gets a smooth taper and an
-- authored LOD hierarchy (hero / normal / distant) that costs fewer parts. Runs after Pass 3; deterministic; never moves a
-- resource node, gather point, prompt, tagged training part, spawn, platform or road.
return function(ctx)
	local V, M, Terrain = Vector3.new, Enum.Material, workspace.Terrain
	local world, decorF, ROADS = ctx.world, ctx.decorF, ctx.ROADS
	local ResourceSpotConfig, flatDist, groundAt, roadClear = ctx.ResourceSpotConfig, ctx.flatDist, ctx.groundAt, ctx.roadClear
	local P, tint, smoke, soft, rockMass, park = ctx.P, ctx.tint, ctx.smoke, ctx.soft, ctx.rockMass, ctx.park
	local terrainEdit, GRASSY = ctx.terrainEdit, ctx.GRASSY
	local CollectionService = game:GetService("CollectionService")

	local COL = {
		DarkSteel = Color3.fromRGB(58, 62, 72),
		Steel = Color3.fromRGB(96, 102, 114),
		Amber = Color3.fromRGB(184, 124, 52),
		Concrete = Color3.fromRGB(138, 134, 126),
		DarkConcrete = Color3.fromRGB(104, 102, 98),
		WarmNeutral = Color3.fromRGB(150, 142, 128),
		Brick = Color3.fromRGB(122, 62, 46),
		DarkStone = Color3.fromRGB(86, 76, 68),
		Bark = Color3.fromRGB(76, 56, 42),
		BarkDark = Color3.fromRGB(66, 50, 38),
		Leaf = Color3.fromRGB(78, 138, 68),
		Pine = Color3.fromRGB(58, 112, 62),
	}

	------------------------------------------------------------------- part helpers
	local function B(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, collide: boolean?): Part
		return P(parent, { Name = name, Size = size, CFrame = cf, Color = color, Material = mat or M.SmoothPlastic, CanCollide = collide ~= false })
	end
	local function cyl(parent: Instance, name: string, d: number, h: number, cf: CFrame, color: Color3, mat: Enum.Material?, collide: boolean?): Part
		return P(parent, { Name = name, Shape = Enum.PartType.Cylinder, Size = V(h, d, d), CFrame = cf * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = mat or M.SmoothPlastic, CanCollide = collide ~= false })
	end
	local function ell(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, collide: boolean?): Part
		local p = P(parent, { Name = name, Size = size, CFrame = cf, Color = color, Material = mat or M.SmoothPlastic, CanCollide = collide == true, CanQuery = collide == true })
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = p
		return p
	end
	local function wedgeP(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, collide: boolean?): WedgePart
		local w = Instance.new("WedgePart")
		w.Name, w.Anchored, w.Size, w.CFrame, w.Color = name, true, size, cf, color
		w.Material = mat or M.SmoothPlastic
		w.CanCollide = collide ~= false
		w.TopSurface, w.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		w.Parent = parent
		return w
	end
	local function pyramid(parent: Instance, name: string, base: Vector3, w: number, h: number, yaw: number, color: Color3, mat: Enum.Material)
		local a = w / 2
		for k = 0, 3 do
			local p = Instance.new("CornerWedgePart")
			p.Name, p.Anchored, p.CanCollide, p.CanQuery = name, true, false, false
			p.Size = V(a, h, a)
			p.CFrame = CFrame.new(base) * CFrame.Angles(0, yaw + k * math.pi / 2, 0) * CFrame.new(-a / 2, h / 2, a / 2)
			p.Color, p.Material = color, mat
			p.Parent = parent
		end
	end
	-- a beam between two points (square section)
	local function beam(parent: Instance, name: string, a: Vector3, b: Vector3, t: number, color: Color3, mat: Enum.Material?, collide: boolean?): Part
		return B(parent, name, V(t, t, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, mat or M.Metal, collide)
	end
	local function hashRandom(p: Vector3): Random
		return Random.new(math.floor(p.X * 7.3 + p.Z * 13.1 + 2e5))
	end
	local function isNode(inst: Instance): boolean
		if CollectionService:HasTag(inst, "ResourceNode") then
			return true
		end
		for _, d in inst:GetDescendants() do
			if CollectionService:HasTag(d, "ResourceNode") then
				return true
			end
		end
		return false
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
	local function spotPos(id: string): Vector3?
		for _, s in ResourceSpotConfig.List() do
			if s.Id == id then
				return s.Position
			end
		end
		return nil
	end
	-- park scenery trees whose trunk base sits inside a footprint box (landmark structures must never grow trees through them)
	local function clearTreesIn(cf: CFrame, size: Vector3)
		for _, t in decorF:GetChildren() do
			if t:IsA("Model") and t.Name == "Tree" then
				local rel = cf:PointToObjectSpace(t:GetPivot().Position)
				if math.abs(rel.X) < size.X / 2 and math.abs(rel.Z) < size.Z / 2 then
					park(t, "Trees")
				end
			end
		end
	end
	-- park trees buried by new terrain (trunk base well below the new ground)
	local function clearBuriedTrees(c: Vector3, r: number)
		for _, t in decorF:GetChildren() do
			if t:IsA("Model") and t.Name == "Tree" then
				local p = t:GetPivot().Position
				if flatDist(p, c) < r and groundAt(p.X, p.Z) > p.Y + 2.5 then
					park(t, "Trees")
				end
			end
		end
	end

	------------------------------------------------------------------- HUB
	local function hub(): number
		local hubF = world:FindFirstChild("Hub")
		local site = world:FindFirstChild("BuildSite")
		if not hubF or not site then
			return 0
		end
		local f = Instance.new("Folder")
		f.Name = "HubFrame"
		f.Parent = hubF
		local n0 = #f:GetDescendants()

		-- GROUND ZONES (terrain, broad shapes): the west half of the yard stays the Training sandstone, the east half becomes a
		-- compacted dark work yard around the Worker Post, the grass edge is pulled in to a cleaner line
		terrainEdit(18, 64, 76, 166, -8, 4, function(x, _y, z, mat)
			if mat == M.Sandstone or GRASSY[mat] then
				if x > 22 and ((x - 46) / 30) ^ 2 + ((z - 116) / 50) ^ 2 + math.noise(x / 30, z / 30, 9.1) * 0.08 < 1 then
					return M.Ground
				end
			end
			return nil
		end)

		-- SPAWN FORECOURT: one broad plated slab around the spawn pad (nearly flush: vehicles and players roll straight over),
		-- edged with dark-steel strips; the walkway runs straight out of it toward the build
		local fc = V(0, 0, 108)
		B(f, "Forecourt", V(60, 0.2, 34), CFrame.new(fc + V(0, 0, 0)), COL.DarkConcrete, M.Concrete, false)
		for _, sz in { -1, 1 } do
			B(f, "ForecourtEdge", V(61, 0.24, 1.4), CFrame.new(fc + V(0, 0.04, sz * 17.4)), COL.DarkSteel, M.Metal, false)
		end
		for _, sx in { -1, 1 } do
			B(f, "ForecourtEdge", V(1.4, 0.24, 36.2), CFrame.new(fc + V(sx * 30.4, 0.04, 0)), COL.DarkSteel, M.Metal, false)
		end
		-- ELEVATION: an engineered loading deck behind the spawn (2.4 studs, crisp concrete, amber edge, steps on the axis and
		-- ramps at both ends); the spawn now reads as standing at the foot of the yard, looking down the axis to the build
		B(f, "LoadingDeck", V(60, 2.4, 22), CFrame.new(0, 1.2, 147), COL.DarkConcrete, M.Concrete)
		B(f, "DeckEdge", V(60.4, 0.5, 1.4), CFrame.new(0, 2.45, 136.2), COL.Amber, M.Metal, false)
		B(f, "DeckStep", V(16, 0.8, 2.4), CFrame.new(0, 0.4, 134.8), COL.Concrete, M.Concrete)
		B(f, "DeckStep", V(16, 1.6, 1.4), CFrame.new(0, 0.8, 135.6), COL.Concrete, M.Concrete)
		for _, sx in { -1, 1 } do
			wedgeP(f, "DeckRamp", V(22, 2.4, 9), CFrame.new(sx * 34.5, 1.2, 147) * CFrame.Angles(0, -sx * math.pi / 2, 0), COL.Steel, M.DiamondPlate)
		end
		-- on the deck: one bundle of long steel beams and one stack of formwork panels (construction stock, two big forms only)
		for k = 0, 2 do
			B(f, "BeamBundle", V(2.4, 2, 20), CFrame.new(-14 + k * 2.6, 3.4 + (if k == 1 then 2 else 0), 148) * CFrame.Angles(0, 0.08, 0), COL.Steel, M.Metal)
		end
		B(f, "Formwork", V(10, 3.2, 7), CFrame.new(15, 4, 150) * CFrame.Angles(0, -0.12, 0), Color3.fromRGB(132, 104, 72), M.WoodPlanks)
		-- the two hub lamps step out past the deck ramps
		for _, m in hubF:GetChildren() do
			if m:IsA("Model") and m.Name == "Lamp" then
				local pv = m:GetPivot()
				m:PivotTo(pv.Rotation + V(math.sign(pv.X) * 44, pv.Y, 146))
			end
		end
		-- PLATED WORK PATH: one broad plated path from the forecourt to the Training Yard floor (replaces the dirt path visually)
		B(f, "WorkPath", V(34, 0.2, 14), CFrame.new(-46.4, 0, 113), Color3.fromRGB(96, 98, 104), M.DiamondPlate, false)
		for _, sz in { -1, 1 } do
			B(f, "WorkPathEdge", V(34, 0.24, 1), CFrame.new(-46.4, 0.04, 113 + sz * 7.4), COL.DarkSteel, M.Metal, false)
		end
		-- SPAWN -> BUILD AXIS: heavier walkway edge beams and two embedded amber strips running the full axis
		for _, d in hubF:GetChildren() do
			if d.Name == "WalkwayCurb" then
				d.Size = V(2.6, d.Size.Y, d.Size.Z)
				d.Color = COL.DarkSteel
			elseif d.Name == "SpawnPad" then
				d.Color = Color3.fromRGB(184, 176, 160)
			elseif d.Name == "Walkway" then
				d.Color, d.Material = Color3.fromRGB(116, 118, 124), M.DiamondPlate
			end
		end
		for _, sx in { -1, 1 } do
			B(f, "AxisStrip", V(0.8, 0.14, 39), CFrame.new(sx * 6, 0.1, 71.5), COL.Amber, M.Metal, false)
		end
		-- the approach ramp: one wide plated slope from the plaza onto the collar, exactly on the axis (aligned with the walkway)
		wedgeP(f, "AxisRamp", V(28, 1.9, 6.5), CFrame.new(0, 0.95, 48.1) * CFrame.Angles(0, math.pi, 0), COL.Steel, M.DiamondPlate)
		for _, sx in { -1, 1 } do
			B(f, "AxisRampEdge", V(1.6, 2.2, 7), CFrame.lookAt(V(sx * 14.6, 1.1, 48.1), V(sx * 14.6, 1.1, 0)), COL.DarkSteel, M.Metal)
		end

		-- PLATFORM ANCHOR: the plaza discs become radial work zones (dark worked inner ring, warm concrete deposit ring, a
		-- dark steel outer band), and eight concrete footings bed the collar into the ground between the buttresses
		for _, d in site:GetChildren() do
			if d.Name == "PlazaInner" then
				d.Color, d.Material = Color3.fromRGB(104, 100, 94), M.Concrete
			elseif d.Name == "DepositRing" then
				d.Color = Color3.fromRGB(150, 140, 122)
			elseif d.Name == "PlazaRim" then
				d.Color, d.Material = COL.DarkSteel, M.Metal
			end
		end
		for i = 0, 7 do
			local a = (i + 0.5) / 8 * math.pi * 2 + (1 / 16) * math.pi * 2 -- between the Pass 3 buttresses
			local dir = V(math.cos(a), 0, math.sin(a))
			if math.abs(dir.Z - 1) > 0.15 then -- not on the spawn axis (the ramp is there)
				local p = dir * 46.6
				B(f, "CollarFooting", V(6, 1.2, 4), CFrame.lookAt(p + V(0, 0.6, 0), V(0, 0.6, 0)), COL.DarkConcrete, M.Concrete)
			end
		end

		-- VERTICAL FORMS (3, all framing, none over the walkway): a tower crane west of the plaza with its jib over the build,
		-- a cement silo pair on a steel frame east of the forecourt, and two tall gate pylons that replace the short Pass 3 ones
		-- tower crane
		local cb = V(-54, 0, 58)
		B(f, "CraneFoot", V(10, 2, 10), CFrame.new(cb + V(0, 1, 0)), COL.DarkConcrete, M.Concrete)
		B(f, "CraneMast", V(3.6, 62, 3.6), CFrame.new(cb + V(0, 33, 0)), COL.Amber, M.Metal)
		local jibDir = (V(0, 0, 0) - cb).Unit
		local top = cb + V(0, 64, 0)
		B(f, "CraneSlew", V(6, 3, 6), CFrame.lookAt(top, top + jibDir), COL.DarkSteel, M.Metal)
		B(f, "CraneCab", V(3.6, 3.6, 4), CFrame.lookAt(top + V(0, -3, 0) + jibDir * 3, top + V(0, -3, 0) + jibDir * 4), COL.DarkSteel, M.Metal)
		local jibA, jibB = top + V(0, 2.4, 0) - jibDir * 14, top + V(0, 2.4, 0) + jibDir * 50
		beam(f, "CraneJib", jibA, jibB, 2.6, COL.Amber)
		B(f, "CraneCounterweight", V(6, 4, 6), CFrame.lookAt(jibA + V(0, -2.6, 2.6 * 0) + jibDir * 3, jibA + jibDir * 4), COL.DarkConcrete, M.Concrete)
		local apex = top + V(0, 11, 0)
		B(f, "CraneApex", V(2, 9, 2), CFrame.new(top + V(0, 6.5, 0)), COL.Amber, M.Metal)
		beam(f, "CranePendant", apex, jibB + V(0, 1, 0), 0.5, COL.DarkSteel, M.Metal, false)
		beam(f, "CranePendant", apex, jibA + V(0, 1, 0), 0.5, COL.DarkSteel, M.Metal, false)
		local hook = top + V(0, 2.4, 0) + jibDir * 30
		B(f, "CraneTrolley", V(3, 1.6, 3), CFrame.new(hook + V(0, -2, 0)), COL.DarkSteel, M.Metal, false)
		B(f, "CraneCable", V(0.3, 26, 0.3), CFrame.new(hook + V(0, -15.8, 0)), Color3.fromRGB(36, 36, 42), M.SmoothPlastic, false)
		B(f, "CraneLoad", V(10, 1.6, 2), CFrame.new(hook + V(0, -29.6, 0)) * CFrame.Angles(0, 0.4, 0), COL.Steel, M.Metal, false)
		-- silo pair
		local sb = V(48, 0, 74)
		B(f, "SiloFrameBase", V(22, 1.6, 12), CFrame.new(sb + V(0, 0.8, 0)), COL.DarkConcrete, M.Concrete)
		for _, sx in { -5.5, 5.5 } do
			for _, sz in { -4, 4 } do
				B(f, "SiloLeg", V(1.6, 12, 1.6), CFrame.new(sb + V(sx + (if sx > 0 then 3.4 else -3.4), 7.6, sz)), COL.DarkSteel, M.Metal)
			end
			cyl(f, "Silo", 9, 20, CFrame.new(sb + V(sx, 23.6, 0)), COL.WarmNeutral, M.Concrete)
			ell(f, "SiloCone", V(9, 6, 9), CFrame.new(sb + V(sx, 13.6, 0)), tint(COL.WarmNeutral, -0.15), M.Concrete)
			cyl(f, "SiloBand", 9.4, 1.4, CFrame.new(sb + V(sx, 30, 0)), COL.Amber, M.Metal)
			cyl(f, "SiloCap", 7, 1.6, CFrame.new(sb + V(sx, 34.4, 0)), COL.DarkSteel, M.Metal)
		end
		B(f, "SiloBridge", V(14, 2, 3), CFrame.new(sb + V(0, 33.6, 0)), COL.DarkSteel, M.Metal)
		-- gate pylons: taller, heavier, still clear of the axis view (the Pass 3 pylons are replaced, same positions)
		for _, d in hubF:GetChildren() do
			if d.Name == "GateColumn" then
				d.Size = V(3.6, 15, 3.6)
				d.CFrame = CFrame.new(d.Position.X, 8.1, d.Position.Z)
			elseif d.Name == "GateCap" then
				d.Size = V(4.2, 1.4, 4.2)
				d.CFrame = CFrame.new(d.Position.X, 16.3, d.Position.Z)
			end
		end
		clearTreesIn(CFrame.new(cb), V(14, 1, 14))
		clearTreesIn(CFrame.new(sb), V(30, 1, 18))

		-- WORKER POST: same building, hub language (warm neutral walls, dark steel roof/frame, one construction accent)
		local ws = world:FindFirstChild("WorkerStation")
		if ws then
			for _, d in ws:GetChildren() do
				if d:IsA("BasePart") then
					local nm = d.Name
					if nm == "WallBack" or nm == "WallSide" then
						d.Color, d.Material = COL.WarmNeutral, M.Concrete
					elseif nm == "FrontPier" or nm == "Lintel" or nm == "Plinth" or nm == "Base" then
						d.Color, d.Material = COL.DarkSteel, M.Metal
					elseif nm == "Roof" or nm == "RoofTrim" then
						d.Color, d.Material = COL.DarkSteel, M.Metal
					elseif nm == "WallCap" then
						d.Color = COL.Amber
					elseif nm == "Counter" then
						d.Color = COL.Steel
					elseif nm == "CounterTop" or nm == "WindowFrame" then
						d.Color = Color3.fromRGB(190, 184, 172)
					elseif nm == "HatBand" or nm == "HatBrim" or nm == "HatDome" then
						d.Color = Color3.fromRGB(214, 160, 48)
					elseif nm == "Floor" then
						d.Color = COL.Concrete
					elseif nm == "Sign" then
						d.Color = COL.DarkSteel
					end
				end
			end
		end
		for _, d in hubF:GetChildren() do
			if d.Name == "Apron" then
				d.Color = COL.DarkConcrete
			end
		end

		-- TRAINING: its slabs take the forecourt concrete, its frames already share the steel + amber
		local yard = world:FindFirstChild("Areas") and world.Areas:FindFirstChild("TrainingYard")
		local frame = yard and yard:FindFirstChild("YardFrame")
		if frame then
			for _, d in frame:GetChildren() do
				if d.Name == "WorkSlab" then
					d.Color = COL.DarkConcrete
				end
			end
		end
		-- a dark steel threshold where the Training floor meets the forecourt yard path (one strip, ground-flush)
		B(f, "YardThreshold", V(1.4, 0.24, 30), CFrame.new(-62, 0.04, 116), COL.DarkSteel, M.Metal, false)
		return #f:GetDescendants() - n0
	end

	------------------------------------------------------------------- FOUNDRY: blast-furnace tower + charging bridge, restrained heat
	local function foundry()
		local z = world.Zones:FindFirstChild("IndustrialYard")
		local hall = z and z:FindFirstChild("Hall") :: BasePart?
		if not hall then
			return
		end
		local cf = hall.CFrame * CFrame.new(0, -14.4, -11)
		cf = CFrame.new(cf.X, 0, cf.Z) * cf.Rotation
		local FX = 34
		-- HIGH: the furnace tower (the asymmetric hero) on a stone base beside the hall, tapering in three stages
		local tb = cf * CFrame.new(FX, 0, 16)
		B(z, "FurnaceBase", V(20, 9, 20), tb * CFrame.new(0, 4.5, 0), COL.DarkStone, M.Slate)
		cyl(z, "FurnaceShaft", 18, 21, tb * CFrame.new(0, 19.5, 0), Color3.fromRGB(98, 80, 68), M.Metal)
		cyl(z, "FurnaceShaft", 15, 19, tb * CFrame.new(0, 39.5, 0), Color3.fromRGB(108, 88, 74), M.Metal)
		cyl(z, "FurnaceShaft", 11.5, 15, tb * CFrame.new(0, 56.5, 0), Color3.fromRGB(118, 96, 80), M.Metal)
		cyl(z, "FurnaceBand", 18.8, 2.4, tb * CFrame.new(0, 30, 0), COL.DarkSteel, M.Metal)
		cyl(z, "FurnaceBand", 15.8, 2.4, tb * CFrame.new(0, 49, 0), COL.DarkSteel, M.Metal)
		B(z, "FurnaceTop", V(16, 4.5, 16), tb * CFrame.new(0, 66, 0), COL.DarkSteel, M.Metal)
		cyl(z, "FurnaceStack", 4.6, 16, tb * CFrame.new(0, 76, 0), Color3.fromRGB(70, 60, 56), M.Metal)
		smoke(z, (tb * CFrame.new(0, 85, 0)).Position, Color3.fromRGB(150, 146, 146), 2, 5)
		-- the tapping hole at the furnace foot: deep orange, small, with one warm light
		local tap = B(z, "TapHole", V(3.4, 2.2, 0.6), tb * CFrame.new(0, 2.4, -10.1), Color3.fromRGB(124, 86, 34), M.Neon, false)
		soft(tap, Color3.fromRGB(255, 140, 60), 12, 0.8)
		-- the charging bridge: one heavy inclined steel box girder from a ground pier up to the furnace top, on two trestles
		local foot = (cf * CFrame.new(FX, 3, 60)).Position
		local head = (tb * CFrame.new(0, 64, 8)).Position
		beam(z, "ChargingBridge", foot, head, 4.4, COL.DarkSteel, M.Metal)
		beam(z, "BridgeRail", foot + V(0, 2.8, 0), head + V(0, 2.8, 0), 0.9, COL.Amber, M.Metal, false)
		B(z, "BridgePier", V(7, 6, 7), CFrame.new(foot + V(0, 0, 0)) * cf.Rotation, COL.DarkStone, M.Slate)
		for _, t in { 0.35, 0.68 } do
			local q = foot:Lerp(head, t)
			B(z, "BridgeTrestle", V(3, q.Y, 3), CFrame.new(q.X, q.Y / 2 - 1.4, q.Z) * cf.Rotation, COL.Steel, M.Metal)
		end
		clearTreesIn(tb, V(30, 1, 30))
		clearTreesIn(CFrame.new((foot + head) / 2) * cf.Rotation, V(14, 1, 50))
		-- HEAT RESTRAINT: deep orange / amber, small and local (no neon-sign rectangles)
		for _, d in z:GetChildren() do
			if d.Name == "FurnaceMouth" then
				-- the mouth becomes a dark recess; only a small low opening glows (hot, not a neon sign)
				d.Color, d.Material = Color3.fromRGB(44, 34, 30), M.Metal
				B(z, "FurnaceGlow", V(d.Size.X * 0.55, d.Size.Y * 0.4, 0.3), d.CFrame * CFrame.new(0, -d.Size.Y * 0.26, -0.3), Color3.fromRGB(124, 86, 34), M.Neon, false)
				local l = d:FindFirstChildOfClass("PointLight")
				if l then
					l.Range, l.Brightness = 16, 0.9
				end
			elseif d.Name == "Molten" then
				d.Color = Color3.fromRGB(128, 88, 36)
			elseif d.Name == "HotWindow" then
				-- the long heat strip becomes three short, dim clerestory slots
				local cf0, len = d.CFrame, d.Size.X
				d:Destroy()
				for k = -1, 1 do
					B(z, "HotWindow", V(len / 5, 1.6, 0.5), cf0 * CFrame.new(k * len / 3, 0, 0), Color3.fromRGB(112, 76, 30), M.Neon, false)
				end
			end
		end
	end

	------------------------------------------------------------------- POWER PLANT: hyperbolic towers + one landmark power gantry
	local function powerPlant()
		local z = world.Zones:FindFirstChild("ReactorYard")
		local hall = z and z:FindFirstChild("TurbineHall") :: BasePart?
		if not hall then
			return
		end
		local cf = hall.CFrame * CFrame.new(-3, -8.5, 5.5)
		cf = CFrame.new(cf.X, 0, cf.Z) * cf.Rotation
		for _, d in z:GetChildren() do
			if d.Name == "Tower" or d.Name == "TowerFooting" or d.Name == "TowerBand" or (d.Name == "SmokeEmitter" and d.Position.Y > 30) then
				d:Destroy()
			end
		end
		local shell, shellD, foot, lip = Color3.fromRGB(156, 152, 146), Color3.fromRGB(144, 140, 134), Color3.fromRGB(84, 86, 92), Color3.fromRGB(126, 86, 70)
		-- wide base, clear inward neck, flared lip: seven stacked rings read as one hyperbolic shell
		local profile = { { 28, 5 }, { 25.5, 6 }, { 23, 6 }, { 21, 6 }, { 20, 5 }, { 21, 4 }, { 23, 3 } }
		local function tower(base: CFrame, s: number)
			cyl(z, "TowerFooting", 31 * s, 3.2 * s, base * CFrame.new(0, 1.6 * s, 0), foot, M.Concrete)
			local y = 3.2 * s
			for i, pr in profile do
				local h = pr[2] * s
				cyl(z, "Tower", pr[1] * s, h + 0.2, base * CFrame.new(0, y + h / 2, 0), if i % 2 == 0 then shellD else shell, M.Concrete)
				y += h
			end
			cyl(z, "TowerBand", 23.8 * s, 1.6 * s, base * CFrame.new(0, y - 0.4 * s, 0), lip, M.Concrete)
			smoke(z, (base * CFrame.new(0, y + 2, 0)).Position, Color3.fromRGB(236, 236, 240), 4, 9 * s)
			return y
		end
		local t1 = cf * CFrame.new(-12, 0, 18)
		local t2 = cf * CFrame.new(18, 0, 22)
		tower(t1, 1.3)
		tower(t2, 1.05)
		-- THE POWER GANTRY: two heavy A-frame portals carrying one deep box girder across the whole plant (tower to tower over
		-- the hall), with big insulator strings and drop lines into the hall and the substation
		local legs = { cf * CFrame.new(-42, 0, -4), cf * CFrame.new(38, 0, -4) }
		local H = 34
		for _, lcf in legs do
			for _, sz in { -1, 1 } do
				local a = (lcf * CFrame.new(0, 0, sz * 6)).Position
				local b = (lcf * CFrame.new(0, H, sz * 1.6)).Position
				beam(z, "GantryLeg", a, b, 3.4, COL.DarkSteel, M.Metal)
			end
			B(z, "GantryFootPad", V(6, 1.4, 16), lcf * CFrame.new(0, 0.7, 0), COL.DarkConcrete, M.Concrete)
			B(z, "GantryBrace", V(2.2, 2.2, 9), lcf * CFrame.new(0, H * 0.45, 0), COL.Steel, M.Metal)
		end
		local ga, gb = (legs[1] * CFrame.new(-2, H + 2.4, 0)).Position, (legs[2] * CFrame.new(2, H + 2.4, 0)).Position
		B(z, "GantryGirder", V(5, 5, (gb - ga).Magnitude), CFrame.lookAt((ga + gb) / 2, gb), COL.DarkSteel, M.Metal)
		B(z, "GantryChord", V(5.4, 1.2, (gb - ga).Magnitude), CFrame.lookAt((ga + gb) / 2 + V(0, 3.1, 0), gb + V(0, 3.1, 0)), Color3.fromRGB(46, 112, 132), M.Metal, false)
		for _, x in { -26, -8, 10, 28 } do
			local p = (cf * CFrame.new(x, H - 2.6, -4)).Position
			cyl(z, "InsulatorString", 1.6, 4.4, CFrame.new(p), Color3.fromRGB(150, 146, 140), M.Concrete, false)
		end
		for _, pair in { { -26, (cf * CFrame.new(-22.5, 15, -12)).Position }, { 10, (cf * CFrame.new(10, 21.6, -5.5)).Position } } do
			local a = (cf * CFrame.new(pair[1], H - 4.8, -4)).Position
			beam(z, "Line", a, pair[2], 0.3, Color3.fromRGB(40, 42, 50), M.SmoothPlastic, false)
		end
		-- the old bus beam is superseded by the gantry
		for _, d in z:GetChildren() do
			if d.Name == "BusBeam" or d.Name == "BusPost" then
				d:Destroy()
			end
		end
		clearTreesIn(cf * CFrame.new(0, 0, 4), V(100, 1, 60))
	end

	------------------------------------------------------------------- QUARRY: terraced cut faces, big block stacks, one hero derrick
	local function quarry()
		local z = world.Zones:FindFirstChild("DeepQuarry")
		local c = spotPos("DeepQuarry")
		local mast = z and z:FindFirstChild("Mast") :: BasePart?
		if not z or not c or not mast then
			return
		end
		local lm = V(mast.Position.X, 0, mast.Position.Z)
		local hang = z:FindFirstChild("HangingBlock")
		for _, d in z:GetChildren() do
			if d:IsA("BasePart") and not isNode(d) then
				local nm = d.Name
				local hangPiece = hang and (nm == "Cap" or nm == "Foot") and flatDist(d.Position, hang.Position) < 4
				if nm == "DerrickBase" or nm == "Mast" or nm == "Boom" or nm == "GuyRope" or nm == "Rope" or nm == "HangingBlock" or nm == "CutFace" or nm == "CutLine" or hangPiece then
					d:Destroy()
				end
			end
		end
		-- terraced cut faces: three benches stepping up and away from the bowl on both sides of the road (terrain = it reads as
		-- rock removed), lowest bench a darker inner cut
		local placed = 0
		for k = 0, 23 do
			local a = k / 24 * math.pi * 2
			local d = V(math.cos(a), 0, math.sin(a))
			for i, bench in { { 44, 7, M.Slate }, { 51, 14, M.Sandstone }, { 58, 21, M.Rock } } do
				local p = c + d * bench[1]
				if roadClear(p, 8, 3) and nodeClear(p, 10) then
					Terrain:FillBlock(CFrame.lookAt(V(p.X, bench[2] / 2 - 2, p.Z), V(c.X, bench[2] / 2 - 2, c.Z)), V(bench[1] * 0.3, bench[2] + 2, 8), bench[3])
					placed += 1
				end
			end
		end
		clearBuriedTrees(c, 70)
		-- HERO DERRICK: a heavy steel mast and boom on a concrete plinth with back stays, lifting a big cut block
		local cf = CFrame.lookAt(lm, V(c.X, 0, c.Z))
		B(z, "DerrickBase", V(11, 2.2, 11), cf * CFrame.new(0, 1.1, 0), COL.DarkConcrete, M.Concrete)
		B(z, "Mast", V(2.8, 46, 2.8), cf * CFrame.new(0, 25, 0), COL.Amber, M.Metal)
		local mastTop = (cf * CFrame.new(0, 48, 0)).Position
		for _, sx in { -1, 1 } do
			beam(z, "BackStay", (cf * CFrame.new(sx * 9, 1, 12)).Position, mastTop, 1.6, COL.DarkSteel, M.Metal)
			B(z, "StayFoot", V(4, 2, 4), cf * CFrame.new(sx * 9, 1, 12), COL.DarkConcrete, M.Concrete)
		end
		local boomRoot = cf * CFrame.new(0, 6, 0) * CFrame.Angles(math.rad(58), 0, 0)
		B(z, "Boom", V(2.2, 2.2, 38), boomRoot * CFrame.new(0, 0, -19), COL.Amber, M.Metal)
		local tip = (boomRoot * CFrame.new(0, 0, -38)).Position
		beam(z, "GuyRope", mastTop, tip, 0.35, Color3.fromRGB(40, 38, 36), M.SmoothPlastic, false)
		local blockPos = V(tip.X, math.max(9, tip.Y - 18), tip.Z)
		B(z, "Rope", V(0.35, tip.Y - blockPos.Y - 4, 0.35), CFrame.new((tip + blockPos + V(0, 4, 0)) / 2), Color3.fromRGB(40, 38, 36), M.SmoothPlastic, false)
		B(z, "HangingBlock", V(9, 7, 9), CFrame.new(blockPos), Color3.fromRGB(170, 154, 130), M.Concrete, false)
		-- the freshly cut face: three long stepped stone tiers facing the bowl (crisp parts standing proud of the rock rim), each
		-- with a darker inner cut line at its foot, so the excavation reads as benches of removed rock. Tried on the far side of
		-- the bowl first, then either flank; the first side clear of the road and every node wins.
		local away = (V(c.X, 0, c.Z) - lm).Unit
		for _, base in { away, CFrame.Angles(0, 0.9, 0):VectorToWorldSpace(away), CFrame.Angles(0, -0.9, 0):VectorToWorldSpace(away) } do
			local tiers = {}
			local ok = true
			for i, t in { { 36, 7, 34 }, { 42, 14, 32 }, { 48, 21, 30 } } do
				local p = V(c.X, 0, c.Z) + base * t[1]
				local tcf = CFrame.lookAt(V(p.X, t[2] / 2 - 0.5, p.Z), V(c.X, t[2] / 2 - 0.5, c.Z))
				for _, sx in { -0.5, 0, 0.5 } do
					local q = (tcf * CFrame.new(sx * t[3], 0, 0)).Position
					ok = ok and roadClear(q, 4, 1) and nodeClear(q, 7)
				end
				table.insert(tiers, { tcf, t })
			end
			if ok then
				for i, e in tiers do
					local tcf, t = e[1], e[2]
					B(z, "CutFace", V(t[3], t[2], 6), tcf, if i % 2 == 1 then Color3.fromRGB(176, 154, 120) else Color3.fromRGB(160, 138, 106), M.Sandstone)
					B(z, "CutLine", V(t[3] + 0.2, 1.2, 6.2), tcf * CFrame.new(0, -t[2] / 2 + 1.1, -0.1), Color3.fromRGB(104, 88, 70), M.Slate, false)
				end
				clearTreesIn(tiers[2][1], V(40, 1, 24))
				break
			end
		end
		-- processed stone: two big stacks of square-cut blocks beside the derrick (scenery; nodes are the small stacks)
		local stacks = 0
		for _, off in { V(-14, 0, 6), V(14, 0, 8) } do
			local p = (cf * CFrame.new(off)).Position
			if roadClear(p, 8, 2) and nodeClear(p, 9) then
				stacks += 1
				local scf = CFrame.new(p) * cf.Rotation * CFrame.Angles(0, off.X * 0.02, 0)
				B(z, "CutStone", V(7, 5, 7), scf * CFrame.new(-3.6, 2.5, 0), Color3.fromRGB(164, 148, 124), M.Concrete)
				B(z, "CutStone", V(7, 5, 7), scf * CFrame.new(3.6, 2.5, 0), Color3.fromRGB(156, 140, 116), M.Concrete)
				B(z, "CutStone", V(7, 5, 7), scf * CFrame.new(0, 7.5, 0) * CFrame.Angles(0, 0.2, 0), Color3.fromRGB(172, 156, 132), M.Concrete)
			end
		end
		return placed, stacks
	end

	------------------------------------------------------------------- MOUNTAIN EXCAVATION: strata, carved terraces, bucket-wheel machine
	local function mountain()
		local z = world.Zones:FindFirstChild("BoulderField")
		local c = spotPos("BoulderField")
		local body = z and z:FindFirstChild("Body") :: BasePart?
		if not z or not c or not body then
			return
		end
		local ecf = body.CFrame * CFrame.new(0, -7.8, -2)
		local lm = V(ecf.X, 0, ecf.Z)
		for _, nm in { "Track", "Turntable", "Body", "Counterweight", "Cab", "CabGlass", "Boom", "Stick", "Bucket" } do
			for _, d in z:GetChildren() do
				if d.Name == nm and d:IsA("BasePart") and not isNode(d) then
					d:Destroy()
				end
			end
		end
		-- CARVED TERRACES: excavation benches cut into both canyon walls (air steps above y 8, so the floor and nodes are untouched)
		local zc = c
		local dir = (V(364, 0, -194) - zc).Unit
		local side = V(-dir.Z, 0, dir.X)
		for _, sd in { -1, 1 } do
			for k = 1, 3 do
				local lat = 60 + (k - 0.5) * 11
				local h0 = 9 * k
				local p = zc + side * sd * lat
				Terrain:FillBlock(CFrame.lookAt(V(p.X, h0 + 50, p.Z), V(p.X, h0 + 50, p.Z) + dir), V(11, 100, 120), M.Air)
			end
		end
		-- STRATA: the exposed mountain rock is repainted in thick horizontal layers (reads as a cut, from far away)
		local mc = V(452, 0, -326)
		local layers = { M.Rock, M.Sandstone, M.Rock, M.Slate }
		terrainEdit(mc.X - 170, mc.Z - 170, mc.X + 170, mc.Z + 170, 4, 160, function(x, y, zz, mat)
			if mat ~= M.Rock and mat ~= M.Slate and mat ~= M.Sandstone and mat ~= M.Sand and mat ~= M.Ground then
				return nil
			end
			if (x - mc.X) ^ 2 + (zz - mc.Z) ^ 2 > 170 * 170 then
				return nil
			end
			local band = math.floor((y + math.noise(x / 40, zz / 40, 2.2) * 3) / 9)
			return layers[band % #layers + 1]
		end)
		-- HERO: a chunky bucket-wheel excavator biting into the cut (tracks, body, house, long boom, big wheel, counter-boom)
		-- side-on to the road approach: the boom reaches across into the canyon wall on the mountain side
		local side2 = V(-dir.Z, 0, dir.X)
		local toMtn = if side2:Dot(V(mc.X, 0, mc.Z) - lm) > 0 then side2 else -side2
		local mz = z
		z = Instance.new("Model")
		z.Name = "BucketWheelExcavator"
		z.Parent = mz
		local cf = CFrame.lookAt(lm, lm + toMtn)
		local Y, D = Color3.fromRGB(206, 150, 46), Color3.fromRGB(52, 54, 62)
		for _, sx in { -7, 7 } do
			B(z, "Track", V(5, 5, 30), cf * CFrame.new(sx, 2.5, 4), D, M.Metal)
		end
		B(z, "Chassis", V(18, 3, 24), cf * CFrame.new(0, 6.5, 4), D, M.Metal)
		cyl(z, "Turntable", 16, 2, cf * CFrame.new(0, 9, 2), D, M.Metal)
		B(z, "Body", V(16, 11, 18), cf * CFrame.new(0, 15.5, 4), Y, M.Metal)
		B(z, "House", V(10, 7, 9), cf * CFrame.new(-2, 24.5, 7), Y, M.Metal)
		B(z, "Cab", V(5, 5, 5), cf * CFrame.new(5, 19, -6), D, M.Metal)
		B(z, "CabGlass", V(4.4, 2.6, 0.3), cf * CFrame.new(5, 19.6, -8.6), Color3.fromRGB(120, 170, 200), M.Glass, false).Transparency = 0.25
		B(z, "Mast", V(3, 16, 3), cf * CFrame.new(0, 29, 0), D, M.Metal)
		-- main boom down to the wheel, counter-boom back to the counterweight, a stay from the mast to both
		local root = (cf * CFrame.new(0, 14, -5)).Position
		local hub = (cf * CFrame.new(0, 14, -46)).Position
		beam(z, "Boom", root, hub, 4, Y)
		local cw = (cf * CFrame.new(0, 20, 30)).Position
		beam(z, "CounterBoom", (cf * CFrame.new(0, 18, 10)).Position, cw, 3, Y)
		B(z, "Counterweight", V(10, 7, 6), CFrame.new(cw) * cf.Rotation, D, M.Metal)
		local mt = (cf * CFrame.new(0, 37, 0)).Position
		beam(z, "Stay", mt, hub + V(0, 3, 0), 0.8, D, M.Metal, false)
		beam(z, "Stay", mt, cw + V(0, 3, 0), 0.8, D, M.Metal, false)
		-- the wheel (axle across the boom) with eight chunky buckets on its rim; the lowest one keeps the "Bucket" name
		local wcf = CFrame.new(hub) * cf.Rotation
		P(z, { Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = V(3.6, 24, 24), CFrame = wcf, Color = Y, Material = M.Metal })
		cyl(z, "WheelHub", 6, 4.4, wcf * CFrame.Angles(0, 0, math.rad(90)), D, M.Metal)
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			local bp = wcf * CFrame.new(0, math.cos(a) * 12.4, math.sin(a) * 12.4)
			B(z, if k == 4 then "Bucket" else "WheelBucket", V(5, 4.2, 4.2), CFrame.new(bp.Position) * cf.Rotation * CFrame.Angles(-a, 0, 0), D, M.Metal, false)
		end
		z.WorldPivot = CFrame.new(lm)
		z:ScaleTo(1.35)
		z = mz
		clearTreesIn(cf * CFrame.new(0, 0, -14), V(40, 1, 110))
	end

	------------------------------------------------------------------- TREES: smooth taper + authored LOD (hero / normal / distant)
	-- broadleaf: a tall flare ellipsoid that narrows into ONE leaning trunk (no stacked steps), canopy masses by tier
	local function broadleaf(m: Model, base: Vector3, s: number, leaf: Color3, tier: string)
		local r = hashRandom(base)
		local yaw = r:NextNumber(0, math.pi * 2)
		local lean = r:NextNumber(2, 6)
		local d = 1.55 * s
		local h = 7.2 * s
		local tcf = CFrame.new(base) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(lean), 0, 0)
		if tier ~= "far" then
			-- a tall, narrow flare (same bark) whose widest part is underground: it meets the trunk ~1.9 s up, steeply, so the
			-- trunk reads as one taper instead of a step or a bulb
			ell(m, "TrunkFlare", V(2.3 * s, 5 * s, 2.3 * s), CFrame.new(base), COL.Bark, M.Wood)
		end
		cyl(m, "Trunk", d, h, tcf * CFrame.new(0, h / 2, 0), COL.Bark, M.Wood)
		local top = (tcf * CFrame.new(0, h - 0.6 * s, 0)).Position
		local c = CFrame.new(top) * CFrame.Angles(0, yaw, 0)
		local k = r:NextNumber(0.9, 1.1)
		if tier == "hero" then
			-- a forked limb into the second mass (silhouette break under the canopy)
			local a, b = (tcf * CFrame.new(0, h * 0.62, 0)).Position, (c * CFrame.new(3.4 * s, 0.6 * s, 1.3 * s)).Position
			cyl(m, "Trunk", d * 0.55, (b - a).Magnitude, CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(math.rad(90), 0, 0), COL.Bark, M.Wood)
		end
		if tier == "far" then
			ell(m, "Leaves", V(10.6 * s * k, 7.4 * s, 9.8 * s), c * CFrame.new(0.6 * s, 2.2 * s, 0) * CFrame.Angles(0, 0.3, 0), leaf, M.Grass)
			ell(m, "Leaves", V(6.4 * s, 4.8 * s, 6 * s), c * CFrame.new(-3.4 * s, 1.4 * s, -1.4 * s), tint(leaf, -0.1), M.Grass)
			return
		end
		ell(m, "Leaves", V(9.6 * s * k, 6.6 * s, 8.8 * s), c * CFrame.new(0, 2.6 * s, 0) * CFrame.Angles(0, 0.3, r:NextNumber(-0.08, 0.08)), leaf, M.Grass)
		ell(m, "Leaves", V(6.8 * s, 5.0 * s, 6.2 * s), c * CFrame.new(3.7 * s, 0.7 * s, 1.5 * s), tint(leaf, -0.12), M.Grass)
		if tier == "hero" or s >= 1.25 then
			ell(m, "Leaves", V(5.8 * s, 4.6 * s, 5.8 * s), c * CFrame.new(-3.3 * s, 2.3 * s * k, -1.9 * s), tint(leaf, 0.05), M.Grass)
		end
	end

	-- pine: hero = 3 faceted tiers, normal = 2 taller tiers, distant = 1 tall faceted spire (trunk always visible)
	local function pine(m: Model, base: Vector3, s: number, leaf: Color3, tier: string)
		local r = hashRandom(base)
		local yaw = r:NextNumber(0, math.pi)
		cyl(m, "Trunk", 1.35 * s, 5.4 * s, CFrame.new(base + V(0, 2.7 * s, 0)), COL.Bark, M.Wood)
		local tiers
		if tier == "hero" then
			tiers = { { 10.6, 7.2, 3.2 }, { 7.8, 6.6, 7.2 }, { 4.8, 6.4, 11.0 } }
		elseif tier == "normal" then
			tiers = { { 10.8, 8.6, 3.2 }, { 6.6, 9.2, 8.4 } }
		else
			tiers = { { 10.4, 14.6, 3.4 } }
		end
		for i, t in tiers do
			local off = V(r:NextNumber(-0.3, 0.3), 0, r:NextNumber(-0.3, 0.3)) * s
			pyramid(m, "Tier", base + V(0, t[3] * s, 0) + off, t[1] * s * r:NextNumber(0.94, 1.06), t[2] * s, yaw + (i - 1) * 0.42, tint(leaf, (i - 1) * 0.05), M.Grass)
		end
	end

	local function treeTier(base: Vector3, s: number, isPine: boolean): string
		if flatDist(base, V(0, 0, -150)) > 360 then
			return "far"
		end
		if s >= (if isPine then 1.75 else 1.65) then
			return "hero"
		end
		return "normal"
	end

	local function treeOptimize(): (number, number)
		local before, after = 0, 0
		local function rebuild(m: Model)
			local tierPart = m:FindFirstChild("Tier") :: BasePart?
			local isPine = tierPart ~= nil
			local trunk
			for _, c in m:GetChildren() do
				if c.Name == "Trunk" and c:IsA("Part") and (trunk == nil or c.Position.Y < trunk.Position.Y) then
					trunk = c
				end
			end
			if not trunk then
				return
			end
			local leafPart = tierPart or m:FindFirstChild("Leaves") :: BasePart?
			local leaf = if leafPart then leafPart.Color else COL.Leaf
			local base = m.WorldPivot.Position
			-- Pass 3 sizes: broadleaf lower trunk = 1.85 s, pine trunk = 1.35 s
			local s = trunk.Size.Y / (if isPine then 1.35 else 1.85)
			for _, c in m:GetChildren() do
				if c:IsA("BasePart") then
					before += 1
				end
				c:Destroy()
			end
			local tier = treeTier(base, s, isPine)
			if isPine then
				pine(m, base, s, leaf, tier)
			else
				broadleaf(m, base, s, leaf, tier)
			end
			for _, c in m:GetChildren() do
				if c:IsA("BasePart") then
					after += 1
				end
			end
			m.WorldPivot = CFrame.new(base)
		end
		for _, m in decorF:GetChildren() do
			if m:IsA("Model") and m.Name == "Tree" then
				rebuild(m)
			end
		end
		for _, zn in world.Zones:GetChildren() do
			for _, m in zn:GetDescendants() do
				if m:IsA("Model") and (m.Name == "Tree" or m.Name == "YoungTree") and not isNode(m) then
					rebuild(m)
				end
			end
		end
		return before, after
	end

	------------------------------------------------------------------- ANCIENT GROVE: smooth trunks, varied roots, a dominant elder
	local function grove(): number
		local z = world.Zones:FindFirstChild("AncientGrove")
		local c = spotPos("AncientGrove")
		if not z or not c then
			return 0
		end
		local fixed = 0
		local flares = {}
		for _, d in z:GetChildren() do
			if d.Name == "TrunkFlare" and d:IsA("Part") then
				table.insert(flares, d)
			end
		end
		for _, fl in flares do
			local p = fl.Position
			local parts, bottom, top, D = {}, math.huge, -math.huge, 0
			for _, d in z:GetChildren() do
				if d.Name == "AncientTrunk" and d:IsA("Part") and flatDist(d.Position, p) < fl.Size.X then
					table.insert(parts, d)
					local isCyl = d.Shape == Enum.PartType.Cylinder
					local half = if isCyl then d.Size.X / 2 else d.Size.Y / 2
					bottom = math.min(bottom, d.Position.Y - half)
					top = math.max(top, d.Position.Y + half)
					if isCyl then
						D = math.max(D, d.Size.Y / 1.06)
					end
				end
			end
			if #parts > 0 and D > 0 then
				local r = hashRandom(p)
				local elder = flatDist(p, c) < 20
				local out = V(p.X - c.X, 0, p.Z - c.Z)
				out = if out.Magnitude > 0.1 then out.Unit else V(1, 0, 0)
				for _, d in parts do
					d:Destroy()
				end
				local g = groundAt(p.X, p.Z)
				local dk = D * r:NextNumber(0.9, 1.1) * (if elder then 1.12 else 1)
				local lean = math.rad(r:NextNumber(3, 7) * (if elder then 1.4 else 1))
				local axis = V(-out.Z, 0, out.X)
				local L = top - g
				-- one long leaning trunk (diameter = the old middle stage) rising out of a tall flare: a smooth taper
				local tcf = CFrame.new(p.X, g, p.Z) * CFrame.fromAxisAngle(axis, -lean)
				cyl(z, "AncientTrunk", dk * 0.86, L, tcf * CFrame.new(0, L / 2, 0), Color3.fromRGB(112, 82, 56):Lerp(Color3.fromRGB(96, 70, 50), r:NextNumber()), M.Wood)
				fl.Size = V(dk * (if elder then 1.7 else 1.38), dk * (if elder then 2.3 else 1.9), dk * (if elder then 1.55 else 1.3))
				fl.CFrame = CFrame.new(p.X, g - dk * 0.35, p.Z) * CFrame.Angles(0, r:NextNumber(0, 3), 0)
				local crown = (tcf * CFrame.new(0, L - dk * 0.15, 0)).Position
				ell(z, "AncientTrunk", V(dk * 1.25, dk * 0.6, dk * 1.05), CFrame.new(crown) * CFrame.Angles(0, r:NextNumber(0, 3), 0), Color3.fromRGB(104, 76, 52), M.Wood, true)
				if elder then
					-- the elder: a second, broader crown tier that spreads lower and wider than any other tree
					ell(z, "Canopy", V(dk * 4.2, dk * 1.3, dk * 3.6), CFrame.new(crown + V(0, -dk * 0.4, 0) - out * 4) * CFrame.Angles(0, 0.6, 0), Color3.fromRGB(56, 102, 56), M.Grass)
				end
				fixed += 1
			end
		end
		-- roots: varied width / length / yaw so no two trees repeat; every root end dives into the ground; one in four dropped
		local idx = 0
		for _, rt in z:GetChildren() do
			if rt.Name == "Root" and rt:IsA("BasePart") then
				idx += 1
				local r = hashRandom(rt.Position + V(idx, 0, 0))
				if r:NextNumber() < 0.25 then
					park(rt, "Misc")
				else
					local look = rt.CFrame.LookVector
					local L = rt.Size.Z * r:NextNumber(0.75, 1.2)
					local r0 = rt.Position - look * rt.Size.Z / 2
					local flat = CFrame.fromAxisAngle(Vector3.yAxis, r:NextNumber(-0.22, 0.22)):VectorToWorldSpace(V(look.X, 0, look.Z).Unit)
					local r1 = r0 + flat * L
					r1 = V(r1.X, groundAt(r1.X, r1.Z) - 1.4, r1.Z)
					rt.Size = V(rt.Size.X * r:NextNumber(0.75, 1.25), rt.Size.Y * r:NextNumber(0.85, 1.15), (r1 - r0).Magnitude)
					rt.CFrame = CFrame.lookAt((r0 + r1) / 2, r1)
				end
			end
		end
		return fixed
	end

	------------------------------------------------------------------- ROADS: targeted (no rebuild)
	local function roads()
		local paths = world:FindFirstChild("Paths")
		if not paths then
			return
		end
		-- the per-segment tone variation showed hard seams between segments: keep it, but far subtler
		for _, d in paths:GetChildren() do
			if d:IsA("BasePart") then
				if d.Name == "RoadBody" or d.Name == "RoadRamp" or d.Name == "JunctionPad" then
					d.Color = Color3.fromRGB(88, 88, 94):Lerp(d.Color, 0.25)
				elseif d.Name == "RoadShoulder" or d.Name == "JunctionApron" then
					d.Color = Color3.fromRGB(150, 144, 134):Lerp(d.Color, 0.3)
				end
			end
		end
		-- plaza entries: the end ramps meet the deposit ring in the plaza's own dark steel instead of pale concrete
		for _, d in paths:GetChildren() do
			if d.Name == "RoadRamp" and d.Position.Magnitude < 64 then
				d.Color, d.Material = Color3.fromRGB(80, 82, 90), M.Asphalt
			end
		end
	end

	local function countParts(): number
		local n = 0
		for _, d in world:GetDescendants() do
			if d:IsA("BasePart") then
				n += 1
			end
		end
		return n
	end

	local function finish(): string
		local before = countParts()
		local tb, ta = treeOptimize()
		local g = grove()
		local h = hub()
		foundry()
		powerPlant()
		local benches, stacks = quarry()
		mountain()
		roads()
		return string.format("trees %d -> %d parts, grove trunks %d, hub +%d, quarry benches %s stacks %s, parts %d -> %d", tb, ta, g, h, tostring(benches), tostring(stacks), before, countParts())
	end

	return { finish = finish }
end
