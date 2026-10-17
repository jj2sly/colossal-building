--!nonstrict
-- EDIT-TIME helper for WorldBuilder (not used at runtime): ART RESET PASS 3, environment style unification + landmark rebuild.
-- The faceted, textured rock masses are the anchor; everything else is raised to their weight: authored trees (tapered trunks,
-- multi-mass textured canopies, faceted pyramid-tier pines that echo the rock facets), an engineered build platform and hub,
-- an industrial Training Yard, heavier roads with rock cuts and junction pads, and four rebuilt landmarks (Foundry, Steel Mine,
-- Power Plant, Reactor) made of a few LARGE forms. Gameplay is untouched: every resource node, gather point, prompt, tagged
-- training part and the build platform footprint keep their exact positions. Deterministic (no shared rng).
-- WorldBuilder.Build() calls it with its shared helpers (ctx).
return function(ctx)
	local V, M, Terrain = Vector3.new, Enum.Material, workspace.Terrain
	local world, decorF, ROADS, ROAD_TOP = ctx.world, ctx.decorF, ctx.ROADS, ctx.ROAD_TOP
	local ResourceSpotConfig, flatDist, groundAt, roadClear = ctx.ResourceSpotConfig, ctx.flatDist, ctx.groundAt, ctx.roadClear
	local P, tint, smoke, soft, gableRoof, rockMass = ctx.P, ctx.tint, ctx.smoke, ctx.soft, ctx.gableRoof, ctx.rockMass
	local CollectionService = game:GetService("CollectionService")
	local Lighting = game:GetService("Lighting")

	-- one structural palette (muted, dark metals, warm earth, restrained accents)
	local COL = {
		DarkSteel = Color3.fromRGB(58, 62, 72),
		Steel = Color3.fromRGB(96, 102, 114),
		PaleMetal = Color3.fromRGB(126, 130, 140),
		Amber = Color3.fromRGB(184, 124, 52),
		Concrete = Color3.fromRGB(150, 146, 138),
		DarkConcrete = Color3.fromRGB(104, 102, 98),
		Brick = Color3.fromRGB(122, 62, 46),
		DarkStone = Color3.fromRGB(86, 76, 68),
		Rust = Color3.fromRGB(122, 74, 52),
		Heat = Color3.fromRGB(255, 136, 40),
		Power = Color3.fromRGB(70, 190, 220),
		Bark = Color3.fromRGB(76, 56, 42),
		BarkDark = Color3.fromRGB(70, 52, 40),
		RedwoodBark = Color3.fromRGB(108, 52, 36),
		Leaf = Color3.fromRGB(78, 138, 68),
		LeafDark = Color3.fromRGB(58, 112, 58),
		Pine = Color3.fromRGB(58, 112, 62),
		DeepLeaf = Color3.fromRGB(52, 102, 56),
	}

	local partsAdded = 0
	local function B(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, collide: boolean?): Part
		partsAdded += 1
		return P(parent, { Name = name, Size = size, CFrame = cf, Color = color, Material = mat or M.SmoothPlastic, CanCollide = collide ~= false })
	end
	-- a vertical cylinder centred at cf
	local function cyl(parent: Instance, name: string, d: number, h: number, cf: CFrame, color: Color3, mat: Enum.Material?, collide: boolean?): Part
		partsAdded += 1
		return P(parent, { Name = name, Shape = Enum.PartType.Cylinder, Size = V(h, d, d), CFrame = cf * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = mat or M.SmoothPlastic, CanCollide = collide ~= false })
	end
	-- an ellipsoid (non-colliding canopy / flare mass)
	local function ell(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, collide: boolean?): Part
		partsAdded += 1
		local p = P(parent, { Name = name, Size = size, CFrame = cf, Color = color, Material = mat or M.SmoothPlastic, CanCollide = collide == true, CanQuery = collide == true })
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = p
		return p
	end
	local function wedgeP(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, collide: boolean?): WedgePart
		partsAdded += 1
		local w = Instance.new("WedgePart")
		w.Name, w.Anchored, w.Size, w.CFrame, w.Color = name, true, size, cf, color
		w.Material = mat or M.SmoothPlastic
		w.CanCollide = collide ~= false
		w.TopSurface, w.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		w.Parent = parent
		return w
	end
	-- a square pyramid of four corner wedges (the faceted pine tier; matches the rock facets)
	local function pyramid(parent: Instance, name: string, base: Vector3, w: number, h: number, yaw: number, color: Color3, mat: Enum.Material)
		local a = w / 2
		for k = 0, 3 do
			partsAdded += 1
			local p = Instance.new("CornerWedgePart")
			p.Name, p.Anchored, p.CanCollide, p.CanQuery = name, true, false, false
			p.Size = V(a, h, a)
			p.CFrame = CFrame.new(base) * CFrame.Angles(0, yaw + k * math.pi / 2, 0) * CFrame.new(-a / 2, h / 2, a / 2)
			p.Color, p.Material = color, mat
			p.Parent = parent
		end
	end
	local function hashRandom(p: Vector3): Random
		return Random.new(math.floor(p.X * 7.3 + p.Z * 13.1 + 1e5))
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

	------------------------------------------------------------------- TREES
	-- broadleaf: a flared foot, a two-stage tapered trunk with a slight lean, and 3 asymmetric canopy masses (textured Grass)
	local function broadleaf(m: Model, base: Vector3, s: number, leaf: Color3, far: boolean)
		local r = hashRandom(base)
		local yaw = r:NextNumber(0, math.pi * 2)
		local lean = r:NextNumber(2, 6)
		if not far and s >= 1.4 then
			ell(m, "TrunkFlare", V(2.5 * s, 2.4 * s, 2.5 * s), CFrame.new(base + V(0, -0.2 * s, 0)), COL.BarkDark, M.Wood)
		end
		local tcf = CFrame.new(base) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(lean), 0, 0)
		local lowH = if far then 7.4 * s else 3.6 * s
		cyl(m, "Trunk", 1.85 * s, lowH, tcf * CFrame.new(0, lowH / 2, 0), COL.Bark, M.Wood)
		local up = tcf * CFrame.new(0, 3.2 * s, 0) * CFrame.Angles(math.rad(lean * 0.5), 0, 0)
		if far then
			up = tcf * CFrame.new(0, 3.2 * s, 0)
		else
			cyl(m, "Trunk", 1.55 * s, 4.0 * s, up * CFrame.new(0, 1.9 * s, 0), tint(COL.Bark, 0.03), M.Wood)
		end
		local top = (up * CFrame.new(0, 3.6 * s, 0)).Position
		local c = CFrame.new(top) * CFrame.Angles(0, yaw, 0)
		local k = r:NextNumber(0.9, 1.1)
		ell(m, "Leaves", V(9.6 * s * k, 6.6 * s, 8.8 * s), c * CFrame.new(0, 2.6 * s, 0) * CFrame.Angles(0, 0.3, r:NextNumber(-0.08, 0.08)), leaf, M.Grass)
		ell(m, "Leaves", V(6.8 * s, 5.0 * s, 6.2 * s), c * CFrame.new(3.7 * s, 0.7 * s, 1.5 * s), tint(leaf, -0.12), M.Grass)
		if not far then
			ell(m, "Leaves", V(5.8 * s, 4.6 * s, 5.8 * s), c * CFrame.new(-3.3 * s, 2.3 * s * k, -1.9 * s), tint(leaf, 0.05), M.Grass)
		end
	end

	-- pine: a visible lower trunk and 3 faceted tiers (2 for distant crest pines), each turned and slightly off-axis
	local function pine(m: Model, base: Vector3, s: number, leaf: Color3, far: boolean)
		local r = hashRandom(base)
		local yaw = r:NextNumber(0, math.pi)
		cyl(m, "Trunk", 1.35 * s, 5.4 * s, CFrame.new(base + V(0, 2.7 * s, 0)), COL.Bark, M.Wood)
		local tiers = if far then { { 10.6, 8.2, 3.4 }, { 6.4, 7.4, 8.6 } } else { { 10.6, 7.2, 3.2 }, { 7.8, 6.6, 7.2 }, { 4.8, 6.4, 11.0 } }
		for i, t in tiers do
			local off = V(r:NextNumber(-0.3, 0.3), 0, r:NextNumber(-0.3, 0.3)) * s
			pyramid(m, "Tier", base + V(0, t[3] * s, 0) + off, t[1] * s * r:NextNumber(0.94, 1.06), t[2] * s, yaw + (i - 1) * 0.42, tint(leaf, (i - 1) * 0.05), M.Grass)
		end
	end

	local function rebuildTree(m: Model, far: boolean)
		local trunk = m:FindFirstChild("Trunk") :: BasePart?
		if not trunk or not trunk:IsA("Part") then
			return
		end
		local isPine = m:FindFirstChild("Tier") ~= nil
		local leafPart = m:FindFirstChild(if isPine then "Tier" else "Leaves") :: BasePart?
		local leaf = if leafPart then leafPart.Color else COL.Leaf
		-- deeper, calmer greens than Pass 1 (keeps each tree's own variation)
		leaf = leaf:Lerp(if isPine then COL.Pine else COL.Leaf, 0.5):Lerp(Color3.new(0, 0, 0), 0.06)
		local h, d = trunk.Size.X, trunk.Size.Y
		local base = trunk.Position - V(0, h / 2, 0)
		local s = d / (if isPine then 1.5 else 1.7)
		for _, c in m:GetChildren() do
			c:Destroy()
		end
		if isPine then
			pine(m, base, s, leaf, far)
		else
			broadleaf(m, base, s, leaf, far)
		end
		m.WorldPivot = CFrame.new(base)
	end

	-- redwoods: a massive four-stage tapered trunk, a broad root flare and a few broad, flattened canopy masses
	local function rebuildRedwood(m: Model)
		local lower = m:FindFirstChild("Trunk") :: BasePart?
		local upper = m:FindFirstChild("UpperTrunk") :: BasePart?
		if not lower or not upper then
			return
		end
		local base = lower.Position - V(0, lower.Size.X / 2, 0)
		local H = (upper.Position.Y + upper.Size.X / 2) - base.Y
		local r = hashRandom(base)
		for _, c in m:GetChildren() do
			if c.Name ~= "Root" then
				c:Destroy()
			else
				c.Color, c.Material = tint(COL.RedwoodBark, -0.1), M.Wood
			end
		end
		ell(m, "TrunkFlare", V(25, 8, 25), CFrame.new(base + V(0, 0.6, 0)), tint(COL.RedwoodBark, -0.12), M.Wood)
		local y = 0
		local drift = V(r:NextNumber(-1, 1), 0, r:NextNumber(-1, 1)).Unit
		for i, st in { { 15.5, 0.24 }, { 12.5, 0.28 }, { 9.8, 0.27 }, { 7.2, 0.24 } } do
			local hh = H * st[2]
			cyl(m, if i == 1 then "Trunk" else "UpperTrunk", st[1], hh + 0.6, CFrame.new(base + V(0, y + hh / 2, 0) + drift * (i - 1) * 0.7), tint(COL.RedwoodBark, (i - 1) * 0.03), M.Wood)
			y += hh
		end
		local top = base + V(0, H, 0) + drift * 2.1
		local g = COL.DeepLeaf
		ell(m, "Crown", V(42, 15, 38), CFrame.new(top + V(0, 4, 0)) * CFrame.Angles(0, r:NextNumber(0, 3), 0), g, M.Grass)
		ell(m, "Crown", V(30, 11, 27), CFrame.new(top + V(9, -9, 6)), tint(g, 0.05), M.Grass)
		ell(m, "Crown", V(24, 9, 22), CFrame.new(base + V(-8, H * 0.74, -6)), tint(g, -0.06), M.Grass)
	end

	-- ancient grove: each giant trunk becomes three tapered, leaning stages over a broad flare; canopies become textured masses
	local function groveTrees()
		local z = world.Zones:FindFirstChild("AncientGrove")
		if not z then
			return
		end
		local center = nil
		for _, spot in ResourceSpotConfig.List() do
			if spot.Id == "AncientGrove" then
				center = spot.Position
			end
		end
		for _, t in z:GetChildren() do
			if t.Name == "AncientTrunk" and t:IsA("Part") then
				local L, D = t.Size.X, t.Size.Y
				local p = t.Position
				local bottom, topY = p.Y - L / 2, p.Y + L / 2
				local r = hashRandom(p)
				-- lean outward, away from the grove centre (the giants crowd the open middle)
				local out = if center then V(p.X - center.X, 0, p.Z - center.Z) else V(1, 0, 0)
				out = if out.Magnitude > 0.1 then out.Unit else V(1, 0, 0)
				local elder = D > 15
				local stages = { { 1.06, 0.34 }, { 0.9, 0.33 }, { 0.76, 0.36 } }
				local y = bottom
				for i, st in stages do
					local hh = L * st[2]
					local off = out * (i - 1) * D * 0.09 + V(r:NextNumber(-0.4, 0.4), 0, r:NextNumber(-0.4, 0.4))
					cyl(z, "AncientTrunk", D * st[1], hh + 0.8, CFrame.new(p.X + off.X, y + hh / 2, p.Z + off.Z), tint(Color3.fromRGB(118, 86, 58), -(i - 1) * 0.04), M.Wood)
					y += hh
				end
				-- a knotted shoulder mass where the trunk splits into the crown
				ell(z, "AncientTrunk", V(D * 1.25, D * 0.55, D * 1.05), CFrame.new(p.X + out.X * D * 0.2, topY - D * 0.2, p.Z + out.Z * D * 0.2) * CFrame.Angles(0, r:NextNumber(0, 3), 0), Color3.fromRGB(104, 76, 52), M.Wood, true)
				if elder then
					-- the elder tree: one more broad crown mass, lowest and widest
					ell(z, "Canopy", V(D * 3.4, D * 1.2, D * 3.0), CFrame.new(p.X - out.X * 6, topY - D * 0.5, p.Z - out.Z * 6), Color3.fromRGB(58, 106, 58), M.Grass)
				end
				t:Destroy()
				partsAdded -= 1
			elseif t.Name == "TrunkFlare" and t:IsA("Part") then
				local L, D = t.Size.X, t.Size.Y
				local p = t.Position
				local g = groundAt(p.X, p.Z)
				ell(z, "TrunkFlare", V(D * 1.4, D * 0.95, D * 1.3), CFrame.new(p.X, g - D * 0.12, p.Z) * CFrame.Angles(0, p.X, 0), Color3.fromRGB(96, 70, 48), M.Wood, true)
				t:Destroy()
				partsAdded -= 1
			elseif t.Name == "Canopy" and t:IsA("Part") and t.Shape == Enum.PartType.Ball then
				local d = t.Size.X
				local cf = t.CFrame
				ell(z, "Canopy", V(d * 1.15, d * 0.66, d * 1.02), CFrame.new(cf.Position) * CFrame.Angles(0, cf.Position.Z, 0), t.Color:Lerp(COL.DeepLeaf, 0.3), M.Grass)
				t:Destroy()
				partsAdded -= 1
			end
		end
	end

	-- grove roots: any buttress root whose underside still hangs above the ground along its length is parked
	local function groveRoots(): number
		local z = world.Zones:FindFirstChild("AncientGrove")
		local n = 0
		if not z then
			return 0
		end
		for _, r in z:GetChildren() do
			if r.Name == "Root" and r:IsA("BasePart") then
				local look = r.CFrame.LookVector
				for _, t in { -0.25, 0.1, 0.4 } do
					local q = r.Position + look * r.Size.Z * t
					if q.Y - r.Size.Y * 0.5 > groundAt(q.X, q.Z) + 0.6 then
						ctx.park(r, "Misc")
						n += 1
						break
					end
				end
			end
		end
		return n
	end

	local function treeUpgrade(): number
		local n = 0
		local function far(m: Model): boolean
			local p = m:GetPivot().Position
			return flatDist(p, V(0, 0, -150)) > 360
		end
		for _, m in decorF:GetChildren() do
			if m:IsA("Model") and m.Name == "Tree" then
				rebuildTree(m, far(m))
				n += 1
			end
		end
		for _, z in world.Zones:GetChildren() do
			for _, m in z:GetDescendants() do
				if m:IsA("Model") and (m.Name == "Tree" or m.Name == "YoungTree") and not isNode(m) then
					rebuildTree(m, false)
					n += 1
				elseif m:IsA("Model") and m.Name == "Redwood" then
					rebuildRedwood(m)
					n += 1
				end
			end
		end
		groveTrees()
		groveRoots()
		return n
	end

	------------------------------------------------------------------- BUILD PLATFORM + HUB
	-- the platform reads as a major construction site: a heavy dark-steel collar outside the barrier with an amber cap, braced by
	-- sloped steel buttresses that carry it into the plaza (drivable slopes, no lip), and a steel gateway framing the build from
	-- the spawn walkway. The barrier, deck, stage ring and deposit ring are untouched.
	local function platform()
		local site = world:FindFirstChild("BuildSite")
		if not site then
			return
		end
		local f = Instance.new("Folder")
		f.Name = "PlatformFrame"
		f.Parent = site
		local R, segs = 43.4, 16
		for i = 0, segs - 1 do
			local a = (i + 0.5) / segs * math.pi * 2
			local pos = V(math.cos(a) * R, 0, math.sin(a) * R)
			local cf = CFrame.lookAt(pos, V(0, 0, 0))
			local w = 2 * math.pi * R / segs + 0.6
			B(f, "Collar", V(w, 1.9, 2.4), cf * CFrame.new(0, 0.95, 0), COL.DarkSteel, M.Metal)
			B(f, "CollarCap", V(w, 0.35, 2.6), cf * CFrame.new(0, 2.05, 0), COL.Amber, M.SmoothPlastic, false)
			if i % 2 == 0 then
				-- a buttress sloping from the collar top down to the plaza (WedgePart is tall at +Z: tall end against the collar)
				wedgeP(f, "Buttress", V(5, 1.9, 5), cf * CFrame.new(0, 0.95, 3.7) * CFrame.Angles(0, math.pi, 0), COL.Steel, M.DiamondPlate)
			end
		end
		-- the barrier rail becomes a dark steel guard rail with amber posts (same parts, same positions)
		local barrier = site:FindFirstChild("Barrier")
		if barrier then
			for _, d in barrier:GetChildren() do
				if d.Name == "Rail" then
					d.Color, d.Material = COL.DarkSteel, M.Metal
				elseif d.Name == "Post" then
					d.Color = COL.Amber
				end
			end
		end
		-- the platform skirt reads as layered steel, the trim as a darker amber band
		local skirt = site:FindFirstChild("PlatformSkirt") :: BasePart?
		if skirt then
			skirt.Color, skirt.Material = Color3.fromRGB(48, 52, 60), M.DiamondPlate
		end
		local trim = site:FindFirstChild("PlatformTrim") :: BasePart?
		if trim then
			trim.Color = Color3.fromRGB(186, 128, 50)
		end
		local rim = site:FindFirstChild("PlazaRim") :: BasePart?
		if rim then
			rim.Color, rim.Material = Color3.fromRGB(120, 112, 100), M.Concrete
		end
		-- walkway entry: two heavy steel pylons with amber caps flank the walkway at the spawn pad (no girder: the build stays
		-- the uninterrupted focal point from spawn)
		local hub = world:FindFirstChild("Hub")
		if hub then
			for _, sx in { -1, 1 } do
				B(hub, "GateColumn", V(3.2, 8, 3.2), CFrame.new(sx * 17.4, 4.6, 92), COL.DarkSteel, M.Metal)
				B(hub, "GateCap", V(3.6, 1, 3.6), CFrame.new(sx * 17.4, 9.1, 92), COL.Amber, M.Metal)
				B(hub, "GateFoot", V(5, 1.2, 5), CFrame.new(sx * 17.4, 0.6, 92), COL.DarkConcrete, M.Concrete)
			end
			-- the walkway gets a concrete threshold where it meets the spawn pad and the plaza (ground transition, no lip)
			for _, d in hub:GetChildren() do
				if d.Name == "Walkway" then
					d.Color = Color3.fromRGB(128, 130, 136)
				end
			end
		end
	end

	------------------------------------------------------------------- TRAINING YARD
	-- a construction-training corner: concrete work slabs under each station, steel portal frames over the bench and treadmill
	-- stations, a gantry over the carry lane, dark steel race-gate posts. Tagged training parts are never moved or resized.
	local function trainingYard()
		local yard = world:FindFirstChild("Areas") and world.Areas:FindFirstChild("TrainingYard")
		if not yard then
			return
		end
		local c = ctx.TRAIN_CENTER
		local f = Instance.new("Folder")
		f.Name = "YardFrame"
		f.Parent = yard
		for _, slab in { { V(-36, 0, 3), V(24, 0.2, 46) }, { V(10, 0, 44), V(56, 0.2, 26) }, { V(-6, 0, -47), V(92, 0.2, 30) } } do
			B(f, "WorkSlab", slab[2], CFrame.new(c + slab[1] + V(0, 0.05, 0)), Color3.fromRGB(138, 132, 122), M.Concrete, false)
		end
		local function portal(center: Vector3, hx: number, hz: number, h: number)
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					B(f, "FrameColumn", V(1.8, h, 1.8), CFrame.new(center + V(sx * hx, h / 2, sz * hz)), COL.DarkSteel, M.Metal)
				end
				B(f, "FrameBeam", V(1.8, 1.8, hz * 2 + 1.8), CFrame.new(center + V(sx * hx, h + 0.9, 0)), COL.Amber, M.Metal)
			end
			for _, sz in { -1, 1 } do
				B(f, "FrameBeam", V(hx * 2 + 1.8, 1.4, 1.4), CFrame.new(center + V(0, h + 0.7, sz * hz)), COL.DarkSteel, M.Metal)
			end
		end
		portal(c + V(-36, 0, 3), 10.5, 21.5, 12)
		portal(c + V(10, 0, 44), 26.5, 10, 11)
		-- carry lane gantry: two legs and an I-beam span over the crate and beam lanes
		for _, x in { -52, 40 } do
			B(f, "GantryLeg", V(2.4, 15, 2.4), CFrame.new(c + V(x, 7.5, -47)), COL.Amber, M.Metal)
			B(f, "GantryFoot", V(4.5, 0.8, 4.5), CFrame.new(c + V(x, 0.4, -47)), COL.DarkSteel, M.Metal)
		end
		B(f, "GantryBeam", V(94.4, 2.4, 2), CFrame.new(c + V(-6, 16.2, -47)), COL.DarkSteel, M.Metal)
		for _, d in yard:GetDescendants() do
			if d:IsA("BasePart") then
				if d.Name == "Post" then
					d.Color, d.Material = COL.DarkSteel, M.Metal
				elseif d.Name == "PostBase" then
					d.Color = COL.Amber
				elseif (d.Name == "Side" or d.Name == "Console" or d.Name == "Cap" or d.Name == "Foot") and d.Parent and d.Parent.Name == "Treadmill" and d.Color.B > d.Color.R + 0.2 then
					d.Color, d.Material = Color3.fromRGB(70, 104, 140), M.Metal -- speed blue, muted and metallic
				end
			end
		end
	end

	------------------------------------------------------------------- ROADS
	-- surface variation and edge wear (colour only), junction pads where the Back Road meets the Steel and Power roads, and rock
	-- cuts: where the Stone road runs through rock country it reads as carved, with large faceted retaining masses at its sides
	local function roads(): number
		local paths = world:FindFirstChild("Paths")
		if not paths then
			return 0
		end
		local k = 0
		for _, d in paths:GetChildren() do
			if d:IsA("BasePart") then
				k += 1
				local n = math.noise(d.Position.X / 60, d.Position.Z / 60, 3.3)
				if d.Name == "RoadBody" or d.Name == "RoadRamp" then
					d.Color = Color3.fromRGB(88, 88, 94):Lerp(if n > 0 then Color3.fromRGB(98, 96, 98) else Color3.fromRGB(76, 78, 86), math.abs(n) * 0.9)
				elseif d.Name == "RoadShoulder" then
					d.Color = Color3.fromRGB(156, 150, 140):Lerp(Color3.fromRGB(128, 120, 108), math.clamp(n + 0.4, 0, 1))
				end
			end
		end
		-- junction pads: a broad asphalt disc at road height with a sloped concrete apron (no lip, no visible seam)
		local pads = 0
		local nodes = CollectionService:GetTagged("ResourceNode")
		for _, j in { V(-235, 0, -320), V(240, 0, -300) } do
			local R = 15
			for _, nd in nodes do
				if nd:IsA("BasePart") and nd:IsDescendantOf(workspace) then
					R = math.min(R, flatDist(nd.Position, j) - 7)
				end
			end
			-- and clear of the rebuilt landmark structures
			for _, zn in { "IndustrialYard", "ReactorYard" } do
				local zz = world.Zones:FindFirstChild(zn)
				for _, d in (zz and zz:GetChildren() or {}) do
					if d:IsA("BasePart") and d.CanCollide and d.Size.Magnitude > 6 then
						-- distance from the junction to the part's footprint box
						local rel = d.CFrame:PointToObjectSpace(V(j.X, d.Position.Y, j.Z))
						local dx = math.max(0, math.abs(rel.X) - d.Size.X / 2)
						local dz = math.max(0, math.abs(rel.Z) - d.Size.Z / 2)
						R = math.min(R, math.sqrt(dx * dx + dz * dz) - 4.5)
					end
				end
			end
			if R >= 9 then
				P(paths, { Name = "JunctionPad", Shape = Enum.PartType.Cylinder, Size = V(1, R * 2, R * 2), CFrame = CFrame.new(j.X, ROAD_TOP - 0.5, j.Z) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(86, 86, 92), Material = M.Asphalt, CastShadow = false })
				local n = 16
				for i = 0, n - 1 do
					local a = (i + 0.5) / n * math.pi * 2
					local dir = V(math.cos(a), 0, math.sin(a))
					local pos = j + dir * (R + 1.5)
					-- tall end at +Z faces the pad
					wedgeP(paths, "JunctionApron", V(2 * math.pi * (R + 1.5) / n + 0.5, ROAD_TOP + 0.05, 3), CFrame.lookAt(pos + V(0, (ROAD_TOP + 0.05) / 2 - 0.05, 0), pos + V(0, (ROAD_TOP + 0.05) / 2 - 0.05, 0) + dir), Color3.fromRGB(146, 140, 130), M.Concrete).CastShadow = false
				end
				partsAdded += 1
				pads += 1
			end
		end
		-- rock cuts along the Stone road (terrain only): alternate sides every ~44 studs between the destinations
		for _, road in ROADS do
			if road.Name == "StoneRoad" then
				local s = road.Samples
				local acc, side = 0, 1
				for i = 2, #s - 1 do
					acc += (s[i] - s[i - 1]).Magnitude
					if acc > 44 and flatDist(s[i], V(0, 0, 40)) > 150 then
						acc = 0
						side = -side
						local dir = (s[i + 1] - s[i - 1]) * V(1, 0, 1)
						dir = if dir.Magnitude > 0 then dir.Unit else V(0, 0, 1)
						local nrm = V(-dir.Z, 0, dir.X) * side
						local q = s[i] + nrm * (road.Width / 2 + 11)
						local h = 9 + math.noise(q.X / 40, q.Z / 40, 1.7) * 6
						if roadClear(q, 7, 0) and ctx.clearOf(q, 8, 0) then
							rockMass(CFrame.lookAt(q + V(0, h * 0.35, 0), q + V(0, h * 0.35, 0) + dir) * CFrame.Angles(0, 0, side * 0.12), V(13, h, 30), M.Rock)
						end
					end
				end
			end
		end
		return pads
	end

	------------------------------------------------------------------- LANDMARKS
	local KEEP = { Nodes = true, GatherPoint = true }
	local function clearLandmark(z: Instance, keep: ((Instance) -> boolean)?)
		for _, c in z:GetChildren() do
			if not KEEP[c.Name] and not (keep and keep(c)) and not isNode(c) then
				c:Destroy()
			end
		end
	end

	-- FOUNDRY: one massive brick furnace hall on a dark stone plinth, a heavy steel frame, a projecting heat chamber with a glowing
	-- mouth and pour channel, a clerestory heat strip and two substantial chimneys
	local function foundry()
		local z = world.Zones:FindFirstChild("IndustrialYard")
		local hall = z and z:FindFirstChild("Hall") :: BasePart?
		if not hall then
			return
		end
		local cf0 = hall.CFrame * CFrame.new(0, -7, -3)
		local cf = CFrame.new(cf0.X, 0, cf0.Z) * cf0.Rotation
		clearLandmark(z)
		local brick, stone = COL.Brick, COL.DarkStone
		B(z, "Plinth", V(46, 2.4, 30), cf * CFrame.new(0, 1.2, 11), stone, M.Slate)
		B(z, "Hall", V(40, 24, 26), cf * CFrame.new(0, 14.4, 11), brick, M.Brick)
		gableRoof(z, cf * CFrame.new(0, 26.4, 11), 43, 29, 27, Color3.fromRGB(64, 60, 60), tint(brick, -0.1))
		-- steel frame: front columns rising above the eave, an eave girder, back corner columns
		for _, x in { -20.6, -6.8, 6.8, 20.6 } do
			B(z, "FrameColumn", V(2.8, 29, 2.8), cf * CFrame.new(x, 14.5, -2.3), COL.DarkSteel, M.Metal)
		end
		B(z, "EaveGirder", V(44, 2.8, 3.2), cf * CFrame.new(0, 26.2, -2.4), COL.DarkSteel, M.Metal)
		for _, x in { -20.6, 20.6 } do
			B(z, "FrameColumn", V(2.8, 27, 2.8), cf * CFrame.new(x, 13.5, 24.3), COL.DarkSteel, M.Metal)
		end
		-- heat chamber: a heavy corroded block projecting from the hall, its mouth glowing, a sloped hood tying it to the wall
		B(z, "HeatChamber", V(16, 15, 9), cf * CFrame.new(-4, 7.5, -6.5), Color3.fromRGB(62, 54, 50), M.Metal)
		wedgeP(z, "ChamberHood", V(16, 4.5, 9), cf * CFrame.new(-4, 17.25, -6.5), COL.DarkSteel, M.Metal)
		local mouth = B(z, "FurnaceMouth", V(9, 7.5, 0.5), cf * CFrame.new(-4, 5.2, -11.1), Color3.fromRGB(196, 82, 26), M.Neon, false)
		soft(mouth, Color3.fromRGB(255, 150, 60), 26, 1.6)
		B(z, "MouthFrame", V(11.4, 1.6, 1), cf * CFrame.new(-4, 9.7, -11.2), COL.DarkSteel, M.Metal)
		B(z, "PourChannel", V(3.4, 0.9, 7), cf * CFrame.new(-4, 0.45, -14.6), COL.DarkSteel, M.Metal, false)
		local melt = B(z, "Molten", V(1.8, 0.2, 6.6), cf * CFrame.new(-4, 0.95, -14.6), Color3.fromRGB(196, 86, 30), M.Neon, false)
		melt.Transparency = 0.15
		B(z, "HotWindow", V(30, 2.2, 0.5), cf * CFrame.new(2, 21.4, -2.1), Color3.fromRGB(188, 86, 34), M.Neon, false)
		B(z, "Door", V(9, 13, 0.6), cf * CFrame.new(13, 8.9, -2.1), COL.DarkSteel, M.Metal)
		-- chimneys: substantial, on stone feet, with one dark steel band each
		for i, ch in { { -12, 30, 64 }, { 10, 32, 72 } } do
			local base = cf * CFrame.new(ch[1], 0, ch[2])
			B(z, "StackFoot", V(12, 6, 12), base * CFrame.new(0, 3, 0), stone, M.Slate)
			cyl(z, "Smokestack", 8.4 - i * 0.4, ch[3], base * CFrame.new(0, 6 + ch[3] / 2, 0), tint(brick, -0.08), M.Brick)
			cyl(z, "StackBand", 9.2, 2.4, base * CFrame.new(0, 6 + ch[3] - 5, 0), COL.DarkSteel, M.Metal)
			smoke(z, (base * CFrame.new(0, 6 + ch[3] + 1, 0)).Position, Color3.fromRGB(150, 148, 150), 3, 6)
		end
	end

	-- STEEL MINE: the portal is carved into the cliff: a real tunnel cut into the rock with steel ribs and warm work lights,
	-- two huge concrete abutments with rock shoulders, one massive box girder with an amber band, and a heavy yard gantry
	local function steelMine()
		local z = world.Zones:FindFirstChild("SteelWorks")
		local td = z and z:FindFirstChild("TunnelDark") :: BasePart?
		local gb = z and z:FindFirstChild("GantryBeam") :: BasePart?
		if not td or not gb then
			return
		end
		local pcf = td.CFrame * CFrame.new(0, -16, -1.5)
		pcf = CFrame.new(pcf.X, 0, pcf.Z) * pcf.Rotation
		local gcf = gb.CFrame * CFrame.new(0, -27.5, 0)
		gcf = CFrame.new(gcf.X, 0, gcf.Z) * gcf.Rotation
		clearLandmark(z)
		-- carve the tunnel (local +Z runs into the cliff)
		Terrain:FillBlock(pcf * CFrame.new(0, 13.5, 19), V(28, 27, 38), M.Air)
		-- rock shoulders that wrap the abutments into the cliff
		for _, sx in { -1, 1 } do
			rockMass(pcf * CFrame.new(sx * 30, 17, 3) * CFrame.Angles(0, sx * 0.25, sx * 0.08), V(16, 36, 18), M.Basalt)
		end
		B(z, "TunnelFloor", V(26, 0.4, 40), pcf * CFrame.new(0, 0.2, 18), Color3.fromRGB(84, 80, 76), M.Concrete)
		B(z, "TunnelBack", V(28, 27, 1.5), pcf * CFrame.new(0, 13.5, 37.5), Color3.fromRGB(72, 54, 42), M.Slate)
		B(z, "TunnelBackInner", V(12, 10, 0.4), pcf * CFrame.new(0, 5, 36.6), Color3.fromRGB(176, 124, 70), M.SmoothPlastic, false)
		for _, d in { 6, 17, 28 } do
			for _, sx in { -1, 1 } do
				B(z, "Rib", V(2.2, 23, 2.2), pcf * CFrame.new(sx * 11.6, 11.5, d), COL.DarkSteel, M.Metal)
			end
			B(z, "Rib", V(25.4, 2.2, 2.2), pcf * CFrame.new(0, 23.6, d), COL.DarkSteel, M.Metal)
		end
		for _, d in { 11, 26 } do
			local g = B(z, "TunnelGlow", V(3, 1, 3), pcf * CFrame.new(0, 22, d), Color3.fromRGB(255, 196, 120), M.Neon, false)
			soft(g, Color3.fromRGB(255, 170, 90), 30, 1.3)
		end
		-- portal: abutments, sloped buttresses, header girder and band
		for _, sx in { -1, 1 } do
			B(z, "Abutment", V(9, 40, 9), pcf * CFrame.new(sx * 18.5, 20, -1), COL.DarkConcrete, M.Concrete)
			wedgeP(z, "AbutmentButtress", V(9, 15, 8), pcf * CFrame.new(sx * 18.5, 7.5, -9.5), COL.DarkConcrete, M.Concrete)
		end
		B(z, "PortalGirder", V(50, 9, 10), pcf * CFrame.new(0, 40, -1), COL.DarkSteel, M.Metal)
		B(z, "PortalBand", V(50.4, 2.4, 0.5), pcf * CFrame.new(0, 37.6, -6.2), COL.Amber, M.SmoothPlastic, false)
		for _, sx in { -9, 9 } do
			local l = B(z, "PortalLamp", V(2.4, 1.4, 2.4), pcf * CFrame.new(sx, 34.8, -4.5), Color3.fromRGB(255, 206, 140), M.Neon, false)
			soft(l, Color3.fromRGB(255, 180, 100), 22, 1)
		end
		for _, sx in { -1.4, 1.4 } do
			B(z, "Rail", V(0.6, 0.4, 66), pcf * CFrame.new(sx, 0.6, 4), Color3.fromRGB(128, 132, 142), M.Metal)
		end
		-- yard gantry: heavier legs, same feet positions (the ingot piles were placed around them)
		for _, sz in { -22, 22 } do
			for _, sx in { -3.6, 3.6 } do
				B(z, "GantryLeg", V(3.4, 30, 3.4), gcf * CFrame.new(sx, 15, sz), COL.Amber, M.Metal)
			end
			B(z, "GantryFoot", V(11, 1, 4.4), gcf * CFrame.new(0, 0.5, sz), COL.DarkSteel, M.Metal, false)
		end
		B(z, "GantryBeam", V(10, 5, 52), gcf * CFrame.new(0, 32.5, 0), COL.Amber, M.Metal)
		B(z, "Trolley", V(7.5, 4.5, 7.5), gcf * CFrame.new(0, 27.75, 6), COL.DarkSteel, M.Metal)
		B(z, "HoistCable", V(0.4, 12, 0.4), gcf * CFrame.new(0, 19.5, 6), Color3.fromRGB(36, 36, 42), M.SmoothPlastic, false)
		B(z, "HangingIngot", V(4.4, 2.2, 7.4), gcf * CFrame.new(0, 12.4, 6), Color3.fromRGB(104, 128, 168), M.Metal)
	end

	-- POWER PLANT: two substantial hyperbolic cooling towers (pale warm grey shells on dark footings, muted rust lips), a heavy
	-- turbine hall with a raised roof monitor, and a substation (three big transformers under a bus gantry)
	local function powerPlant()
		local z = world.Zones:FindFirstChild("ReactorYard")
		local hall = z and z:FindFirstChild("TurbineHall") :: BasePart?
		if not hall then
			return
		end
		local cf0 = hall.CFrame * CFrame.new(-2, -4.5, 10)
		local cf = CFrame.new(cf0.X, 0, cf0.Z) * cf0.Rotation
		local lm = cf.Position
		clearLandmark(z, function(c)
			-- keep the transmission line along the road (pylons, arms and their long lines)
			if string.find(c.Name, "^PowerLine") then
				return true
			end
			return c.Name == "Line" and c:IsA("BasePart") and flatDist(c.Position, lm) > 34
		end)
		local shell, shell2, foot, lip = Color3.fromRGB(156, 152, 146), Color3.fromRGB(142, 138, 132), Color3.fromRGB(88, 90, 96), Color3.fromRGB(126, 86, 70)
		local function tower(base: CFrame, s: number)
			cyl(z, "TowerFooting", 29 * s, 3 * s, base * CFrame.new(0, 1.5 * s, 0), foot, M.Concrete)
			cyl(z, "Tower", 26 * s, 12 * s, base * CFrame.new(0, 9 * s, 0), shell, M.Concrete)
			cyl(z, "Tower", 21.5 * s, 10 * s, base * CFrame.new(0, 20 * s, 0), shell2, M.Concrete)
			cyl(z, "Tower", 23 * s, 9 * s, base * CFrame.new(0, 29.5 * s, 0), shell, M.Concrete)
			cyl(z, "TowerBand", 23.6 * s, 2 * s, base * CFrame.new(0, 34.6 * s, 0), lip, M.Concrete)
			smoke(z, (base * CFrame.new(0, 37 * s, 0)).Position, Color3.fromRGB(236, 236, 240), 4, 8 * s)
		end
		tower(cf * CFrame.new(-12, 0, 18), 1.3)
		tower(cf * CFrame.new(18, 0, 22), 1.05)
		-- turbine hall: a heavy concrete block with a dark steel roof, a raised roof monitor and a tall exhaust stack
		B(z, "TurbineHall", V(32, 17, 16), cf * CFrame.new(3, 8.5, -5.5), Color3.fromRGB(122, 120, 116), M.Concrete)
		B(z, "HallPlinth", V(34, 1.6, 18), cf * CFrame.new(3, 0.8, -5.5), COL.DarkConcrete, M.Concrete)
		B(z, "HallRoof", V(34, 1.8, 18), cf * CFrame.new(3, 17.9, -5.5), COL.DarkSteel, M.Metal)
		B(z, "HallMonitor", V(22, 3.6, 7), cf * CFrame.new(3, 20.6, -5.5), COL.Steel, M.Metal)
		B(z, "HallStripe", V(32.2, 0.8, 16.2), cf * CFrame.new(3, 13.6, -5.5), Color3.fromRGB(46, 112, 132), M.Metal, false)
		B(z, "HallDoor", V(10, 11, 0.5), cf * CFrame.new(8, 6.1, -13.7), COL.DarkSteel, M.Metal)
		cyl(z, "ExhaustStack", 5, 58, cf * CFrame.new(24, 29, 2), Color3.fromRGB(132, 130, 126), M.Concrete)
		cyl(z, "StackBand", 5.6, 3, cf * CFrame.new(24, 52, 2), lip, M.Concrete)
		cyl(z, "StackFoot", 9, 4, cf * CFrame.new(24, 2, 2), foot, M.Concrete)
		-- substation
		for k = 0, 2 do
			local tcf = cf * CFrame.new(-28 + k * 7.5, 0, -12)
			B(z, "TransformerBank", V(6, 7, 5), tcf * CFrame.new(0, 3.5, 0), COL.Steel, M.Metal)
			B(z, "TransformerFins", V(6.4, 4.6, 0.8), tcf * CFrame.new(0, 3.5, -2.9), COL.DarkSteel, M.Metal, false)
		end
		for _, x in { -32, -13 } do
			B(z, "BusPost", V(1.4, 14, 1.4), cf * CFrame.new(x, 7, -7), COL.DarkSteel, M.Metal)
		end
		B(z, "BusBeam", V(20.4, 1.2, 1.2), cf * CFrame.new(-22.5, 14.4, -7), COL.DarkSteel, M.Metal)
		for _, ox in { -1.2, 1.2 } do
			local a, b = (cf * CFrame.new(-13, 13.6, -7 + ox)).Position, (cf * CFrame.new(-11.9, 12, -10 + ox)).Position
			B(z, "Line", V(0.25, 0.25, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), Color3.fromRGB(40, 42, 50), M.SmoothPlastic, false)
		end
	end

	-- REACTOR: a three-tier elevated base, four thick tapered pylons tied by a heavy octagonal crown ring, a contained energy core
	-- (two slow steel containment rings) and restrained cyan accents; dark steel and pale metal carry it with the lights off
	local function reactor()
		local z = world.Zones:FindFirstChild("CoreVault")
		local baseP = z and z:FindFirstChild("ReactorBase") :: BasePart?
		if not baseP then
			return
		end
		local c = V(baseP.Position.X, 0, baseP.Position.Z)
		clearLandmark(z)
		local function disc(name: string, d: number, top: number, h: number, color: Color3, mat: Enum.Material)
			cyl(z, name, d, h, CFrame.new(c + V(0, top - h / 2, 0)), color, mat)
		end
		disc("ReactorBase", 42, 1.4, 1.6, COL.DarkSteel, M.DiamondPlate)
		disc("ReactorTier", 33, 2.7, 1.3, COL.Steel, M.Metal)
		disc("ReactorDais", 22, 3.7, 1, Color3.fromRGB(128, 132, 140), M.Metal)
		disc("ReactorInlay", 23, 3.75, 0.2, Color3.fromRGB(28, 84, 104), M.Neon)
		local R = 15.5
		local tops = {}
		for k = 0, 3 do
			local a = k / 4 * math.pi * 2 + math.pi / 4
			local d = V(math.cos(a), 0, math.sin(a))
			local p = c + d * R
			local face = CFrame.lookAt(p, V(c.X, 0, c.Z))
			B(z, "PylonFoot", V(7.6, 4, 7.6), face * CFrame.new(0, 4.7, 0), COL.DarkSteel, M.Metal)
			B(z, "Pillar", V(5.4, 30, 5.4), face * CFrame.new(0, 21.7, 0), COL.PaleMetal, M.Metal)
			B(z, "PylonCap", V(7.2, 3.6, 7.2), face * CFrame.new(0, 38.5, 0), COL.DarkSteel, M.Metal)
			B(z, "PylonStrip", V(1.4, 20, 0.4), face * CFrame.new(0, 21.7, -2.8), Color3.fromRGB(36, 116, 142), M.Neon, false)
			table.insert(tops, p + V(0, 38.5, 0))
		end
		-- crown ring: an octagon of heavy beams over the pylon caps
		local n = 8
		for i = 0, n - 1 do
			local a0 = i / n * math.pi * 2 + math.pi / 4
			local a1 = (i + 1) / n * math.pi * 2 + math.pi / 4
			local p0 = c + V(math.cos(a0) * R, 39, math.sin(a0) * R)
			local p1 = c + V(math.cos(a1) * R, 39, math.sin(a1) * R)
			B(z, "CrownRing", V(3.2, 3, (p1 - p0).Magnitude + 3), CFrame.lookAt((p0 + p1) / 2, p1), COL.DarkSteel, M.Metal)
		end
		local core = P(z, { Name = "Core", Shape = Enum.PartType.Ball, Size = V(11, 11, 11), Position = c + V(0, 21, 0), Color = Color3.fromRGB(56, 168, 200), Material = M.Neon, CanCollide = false })
		partsAdded += 1
		soft(core, COL.Power, 22, 1.2)
		for _, ring in { { 13, 9.6 }, { 29, 9.2 } } do
			local segs = 12
			for k = 0, segs - 1 do
				local a = k / segs * math.pi * 2
				local p = c + V(math.cos(a) * ring[2], ring[1], math.sin(a) * ring[2])
				B(z, "Halo", V(1.6, 1.4, 2 * math.pi * ring[2] / segs + 0.3), CFrame.lookAt(p, p + V(-math.sin(a), 0, math.cos(a))), Color3.fromRGB(150, 158, 172), M.Metal, false)
			end
		end
		for _, t in tops do
			local from, to = t - V(0, 11, 0), c + V(0, 21, 0)
			B(z, "Conduit", V(0.7, 0.7, (to - from).Magnitude), CFrame.lookAt((from + to) / 2, to), COL.DarkSteel, M.Metal, false)
		end
	end

	------------------------------------------------------------------- ATMOSPHERE
	-- the distant mountains sit further back: a touch more aerial haze and a cooler, lower-value horizon (style unchanged)
	local function atmosphere()
		local atm = Lighting:FindFirstChildOfClass("Atmosphere")
		if atm then
			atm.Density = 0.3
			atm.Offset = 0.22
			atm.Haze = 1.25
			atm.Color = Color3.fromRGB(198, 210, 226)
			atm.Decay = Color3.fromRGB(150, 168, 198)
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
		local trees = treeUpgrade()
		platform()
		trainingYard()
		foundry()
		steelMine()
		powerPlant()
		reactor()
		local pads = roads()
		return string.format("trees %d, junctions %d, parts %d -> %d", trees, pads, before, countParts())
	end

	return { finish = finish, atmosphere = atmosphere }
end
