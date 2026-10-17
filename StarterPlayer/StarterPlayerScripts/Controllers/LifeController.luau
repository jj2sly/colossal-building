--!strict
-- (Pass 21J) MAP LIFE, client-only and visual-only (anchored, no collision, nothing replicated, no physics):
--   * ZONE BEACONS     a soft light beam over every public resource spot in its family colour, with the spot's name floating
--                      above it when you are far away (secret areas get nothing, so nothing is spoiled)
--   * BUILDER NPCS     blocky hard-hat builders who wander the spawn plaza and the training pad, stop to hammer or carry a crate
--   * WILDLIFE         deer and rabbits that graze and hop in the open meadows near the camera (respawned around you as you travel)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local ResourceSpotConfig = require(Shared.Config.ResourceSpotConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)

local LifeController = {}

local V = Vector3.new
local FAMILY_COLOR = {
	Wood = Color3.fromRGB(150, 220, 90),
	Stone = Color3.fromRGB(230, 220, 200),
	Metal = Color3.fromRGB(150, 190, 240),
	Power = Color3.fromRGB(110, 230, 255),
}

local folder: Folder
local function part(parent: Instance, size: Vector3, color: Color3, mat: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.CastShadow = true
	p.Size, p.Color, p.Material = size, color, mat or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include -- terrain only (never land on a tree or roof)
local function groundAt(x: number, z: number): (number?, Enum.Material?)
	local hit = workspace:Raycast(V(x, 400, z), V(0, -700, 0), groundParams)
	if hit then
		return hit.Position.Y, hit.Material
	end
	return nil, nil
end

------------------------------------------------------------------ zone beacons
local function zoneBeacons()
	local beacons = {}
	for _, spot in ResourceSpotConfig.List() do
		if not spot.Secret then
			local res = ResourceConfig.Resources[spot.Resource]
			local color = FAMILY_COLOR[res.FamilyName or res.Family or ""] or Color3.new(1, 1, 1)
			local y = groundAt(spot.Position.X, spot.Position.Z) or 0
			local a0 = Instance.new("Attachment")
			a0.WorldPosition = V(spot.Position.X, y + 18, spot.Position.Z)
			a0.Parent = workspace.Terrain
			local a1 = Instance.new("Attachment")
			a1.WorldPosition = V(spot.Position.X, y + 190, spot.Position.Z)
			a1.Parent = workspace.Terrain
			local beam = Instance.new("Beam")
			beam.Attachment0, beam.Attachment1 = a0, a1
			beam.Width0, beam.Width1 = 7, 2
			beam.FaceCamera = true
			beam.LightEmission = 1
			beam.Color = ColorSequence.new(color)
			beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.7, 0.75), NumberSequenceKeypoint.new(1, 1) })
			beam.Segments = 1
			beam.Parent = a0
			local an = Instance.new("Attachment")
			an.WorldPosition = V(spot.Position.X, y + 70, spot.Position.Z)
			an.Parent = workspace.Terrain
			local bb = Instance.new("BillboardGui")
			bb.Adornee = an
			bb.Size = UDim2.fromOffset(260, 60)
			bb.AlwaysOnTop = true
			bb.LightInfluence = 0
			bb.MaxDistance = 2200
			bb.Parent = an
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Size = UDim2.fromScale(1, 1)
			l.Font = Enum.Font.BuilderSansExtraBold
			l.TextSize = 21
			l.RichText = true
			l.TextColor3 = color
			-- two lines: the zone's name, and in parentheses the resource that is actually gathered there
			l.Text = string.format('%s\n<font size="16" color="rgb(255,255,255)">(%s)</font>', string.upper(spot.DisplayName), res.DisplayName)
			l.Parent = bb
			local s = Instance.new("UIStroke")
			s.Thickness = 2
			s.Color = Color3.fromRGB(10, 12, 18)
			s.Parent = l
			table.insert(beacons, { gui = bb, pos = spot.Position })
		end
	end
	-- names only show from a distance (up close the zone speaks for itself)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local cam = workspace.CurrentCamera
			if cam then
				for _, b in beacons do
					local d = (V(b.pos.X, 0, b.pos.Z) - V(cam.CFrame.Position.X, 0, cam.CFrame.Position.Z)).Magnitude
					b.gui.Enabled = d > 140
				end
			end
		end
	end)
end

------------------------------------------------------------------ builder NPCs
-- (Pass 21K) real R15 Roblox characters: clones of ReplicatedStorage.NPCRigs.Builder1..4 (built once in Studio from a HumanoidDescription,
-- hard hat + hi-vis vest welded on). The anchored root is moved here; the limbs are animated by the same R15 pose driver the Workers use
-- (TrainingAnimations: WorkerWalk / WorkerWork / WorkerIdle, + WorkerCarry with a crate overhead).
local TrainingAnimations = require(script.Parent.Parent.ClientLib.TrainingAnimations)
type Gear = { part: BasePart, to: BasePart, off: CFrame, tool: boolean? }
type Npc = { gear: { Gear }, model: Model, root: BasePart, pos: Vector3, target: Vector3, state: string, until_: number, crate: BasePart, area: any, speed: number, track: any?, trackKind: string?, carry: any?, carrying: boolean, hip: number }

-- an NPC's patch: a slab part (plaza / training pad) or a circle round a resource spot (ground from the terrain)
type Area = { part: BasePart?, center: Vector3?, radius: number?, worker: boolean?, tool: string? }
local clearParams = OverlapParams.new()
clearParams.FilterType = Enum.RaycastFilterType.Exclude
local function randomIn(area: Area): Vector3
	local r = Random.new()
	if area.part then
		local p = area.part
		local x = (r:NextNumber() - 0.5) * (p.Size.X - 10)
		local z = (r:NextNumber() - 0.5) * (p.Size.Z - 10)
		local w = p.CFrame:PointToWorldSpace(V(x, 0, z))
		return V(w.X, p.Position.Y + p.Size.Y / 2, w.Z)
	end
	local c = area.center :: Vector3
	for _ = 1, 10 do
		local a = r:NextNumber(0, math.pi * 2)
		local d = r:NextNumber(4, area.radius or 20)
		local x, z = c.X + math.cos(a) * d, c.Z + math.sin(a) * d
		local y = groundAt(x, z)
		if y then
			-- never stand inside a building, rock or node
			local inside = false
			for _, bp in workspace:GetPartBoundsInRadius(V(x, y + 3, z), 1.8, clearParams) do
				if bp.CanCollide and bp.Transparency < 1 then
					inside = true
					break
				end
			end
			if not inside then
				return V(x, y, z)
			end
		end
	end
	return V(c.X, groundAt(c.X, c.Z) or c.Y, c.Z)
end

local function setTrack(n: Npc, kind: string)
	if n.trackKind == kind then
		return
	end
	if n.track then
		n.track:Stop(0.2)
	end
	n.track = TrainingAnimations.Play(n.model, kind, true)
	n.trackKind = kind
end

local function setCarry(n: Npc, on: boolean)
	if on == n.carrying then
		return
	end
	n.carrying = on
	if on then
		n.carry = TrainingAnimations.Play(n.model, "WorkerCarry", true)
	elseif n.carry then
		n.carry:Stop(0.2)
		n.carry = nil
	end
	n.crate.Transparency = if on then 0 else 1
end

local TOOL_BY_FAMILY = { Wood = "axe", Stone = "pickaxe", Metal = "hammer", Power = "wrench", PowerCell = "wrench" }
local WOODC, STEELC = Color3.fromRGB(150, 104, 62), Color3.fromRGB(176, 184, 196)
-- tool parts are modelled with the grip at the origin and the working end along +Y
local function buildTool(kind: string): { { part: BasePart, local_: CFrame } }
	local out = {}
	local function add(size: Vector3, off: CFrame, color: Color3, mat: Enum.Material?, shape: Enum.PartType?)
		local p = part(folder, size, color, mat, shape)
		table.insert(out, { part = p, local_ = off })
	end
	if kind == "axe" then
		add(V(0.25, 2.6, 0.25), CFrame.new(0, 1.1, 0), WOODC, Enum.Material.Wood)
		add(V(0.2, 0.9, 1.0), CFrame.new(0, 2.15, -0.45), STEELC, Enum.Material.Metal)
		add(V(0.22, 0.9, 0.3), CFrame.new(0, 2.15, 0.05), Color3.fromRGB(110, 116, 128), Enum.Material.Metal)
	elseif kind == "pickaxe" then
		add(V(0.25, 2.6, 0.25), CFrame.new(0, 1.1, 0), WOODC, Enum.Material.Wood)
		add(V(0.22, 0.28, 2.6), CFrame.new(0, 2.4, 0), STEELC, Enum.Material.Metal)
		add(V(0.22, 0.5, 0.5), CFrame.new(0, 2.4, 0), Color3.fromRGB(110, 116, 128), Enum.Material.Metal)
	elseif kind == "hammer" then
		add(V(0.25, 2.2, 0.25), CFrame.new(0, 0.9, 0), WOODC, Enum.Material.Wood)
		add(V(0.7, 0.7, 1.3), CFrame.new(0, 2.15, 0), STEELC, Enum.Material.Metal)
	elseif kind == "wrench" then
		add(V(0.3, 2.2, 0.18), CFrame.new(0, 0.9, 0), Color3.fromRGB(230, 120, 40), Enum.Material.Metal)
		add(V(0.3, 0.7, 0.9), CFrame.new(0, 2.15, 0), Color3.fromRGB(230, 120, 40), Enum.Material.Metal)
		add(V(0.32, 0.45, 0.4), CFrame.new(0, 2.3, 0), Color3.fromRGB(34, 38, 48))
	else -- dumbbell: bar across the hand, a plate each end
		add(V(1.9, 0.2, 0.2), CFrame.new(0, 0.5, 0), STEELC, Enum.Material.Metal)
		for _, sx in { -0.95, 0.95 } do
			add(V(0.4, 1.0, 1.0), CFrame.new(sx, 0.5, 0), Color3.fromRGB(40, 46, 62), nil, Enum.PartType.Cylinder)
		end
	end
	return out
end

local function builderNPCs()
	local world = workspace:WaitForChild("World", 30)
	local rigs = ReplicatedStorage:WaitForChild("NPCRigs", 30)
	if not world or not rigs then
		return
	end
	local templates = rigs:GetChildren()
	if #templates == 0 then
		return
	end
	clearParams.FilterDescendantsInstances = { folder }
	-- where the crew works: 5 on the spawn plaza, 4 at the training yard, 2 at every public resource spot (gathering)
	local plan: { Area } = {}
	local plaza = world:FindFirstChild("PlazaSlab", true)
	local pad = world:FindFirstChild("PadSlab", true)
	if plaza and plaza:IsA("BasePart") then
		-- (no builders on the spawn plaza any more)
	end
	if pad and pad:IsA("BasePart") then
		for _ = 1, 4 do
			table.insert(plan, { part = pad, tool = "dumbbell" })
		end
	end
	for _, spot in ResourceSpotConfig.List() do
		if not spot.Secret then
			for _ = 1, 2 do
				local fam = ResourceConfig.Resources[spot.Resource].FamilyName or ResourceConfig.Resources[spot.Resource].Family
				table.insert(plan, { center = spot.Position, radius = 22, worker = true, tool = TOOL_BY_FAMILY[fam or ""] or "hammer" })
			end
		end
	end
	if #plan == 0 then
		return
	end
	local npcs: { Npc } = {}
	for i, area in plan do
		local m = (templates[(i - 1) % #templates + 1] :: Model):Clone()
		local root = m:FindFirstChild("HumanoidRootPart") :: BasePart
		local hum = m:FindFirstChildOfClass("Humanoid")
		root.Anchored = true
		local hip = (if hum then hum.HipHeight else 2) + root.Size.Y / 2
		-- hard hat / vest / belt: unanchored welded accessories drifted away from the bodies (the limbs are physics-driven), so they are
		-- anchored here and re-posed on their body part every frame instead
		local gear: { Gear } = {}
		local ATTACH = { HardHat = "Head", HatBrim = "Head", Vest = "UpperTorso", VestStripe = "UpperTorso", ToolBelt = "LowerTorso", BeltPouch = "LowerTorso" }
		for gname, bodyName in ATTACH do
			local gp = m:FindFirstChild(gname)
			local body = m:FindFirstChild(bodyName)
			if gp and gp:IsA("BasePart") and body and body:IsA("BasePart") then
				for _, w in gp:GetChildren() do
					if w:IsA("WeldConstraint") then
						w:Destroy()
					end
				end
				table.insert(gear, { part = gp, to = body, off = body.CFrame:ToObjectSpace(gp.CFrame) })
				gp.Anchored = true
			end
		end
		-- the crew's tool, held in the right hand (axe for wood, pickaxe for stone, hammer for metal, wrench for power, dumbbell at the yard)
		local rightHand = m:FindFirstChild("RightHand") :: BasePart?
		if rightHand and area.tool then
			local grip = CFrame.new(0, -0.35, 0) * CFrame.Angles(math.rad(-90), 0, 0)
			for _, tp in buildTool(area.tool) do
				table.insert(gear, { part = tp.part, to = rightHand, off = grip * tp.local_, tool = true })
			end
		end
		local crate = part(folder, V(1.8, 1.5, 1.8), Color3.fromRGB(176, 120, 66), Enum.Material.WoodPlanks)
		crate.Transparency = 1
		local start = randomIn(area)
		-- move the WHOLE model (body, hat, vest, belt) to the start: NPCs further than 300 studs are never re-posed, so any part left at the
		-- template's origin would float there for the whole session
		m:PivotTo(CFrame.new(start + V(0, hip, 0)))
		m.Parent = folder
		local n: Npc = { gear = gear, model = m, root = root, pos = start, target = randomIn(area), state = "walk", until_ = 0, crate = crate, area = area, speed = 6 + math.random() * 3, carrying = false, hip = hip }
		table.insert(npcs, n)
		task.defer(setTrack, n, "WorkerWalk")
	end
	local last = os.clock()
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local dt = math.min(0.1, t - last)
		last = t
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		for _, n in npcs do
			if (n.pos - cam.CFrame.Position).Magnitude > 300 then
				continue
			end
			local flat = V(n.target.X - n.pos.X, 0, n.target.Z - n.pos.Z)
			if n.state == "walk" then
				if flat.Magnitude < 1 then
					local roll = math.random()
					if n.area.worker then
						-- spot crews mostly gather, with the odd short stroll
						n.state = if roll < 0.75 then "hammer" elseif roll < 0.9 then "idle" else "walk"
						n.until_ = t + 4 + math.random() * 6
					else
						n.state = if roll < 0.4 then "hammer" elseif roll < 0.7 then "idle" else "walk"
						n.until_ = t + 2 + math.random() * 3
					end
					n.target = randomIn(n.area)
					setCarry(n, math.random() < 0.35)
				else
					n.pos += flat.Unit * math.min(flat.Magnitude, n.speed * dt)
					if not n.area.part then
						local gy = n.target.Y + (n.pos.Y - n.target.Y) * math.clamp(flat.Magnitude / 30, 0, 1)
						n.pos = V(n.pos.X, gy, n.pos.Z)
					end
				end
			elseif t > n.until_ then
				n.state = "walk"
			end
			if n.state ~= "walk" and n.carrying then
				setCarry(n, false)
			end
			setTrack(n, if n.state == "walk" then "WorkerWalk" elseif n.state == "hammer" then "WorkerWork" else "WorkerIdle")
			local dir = if flat.Magnitude > 0.1 then flat.Unit else n.root.CFrame.LookVector
			local at = n.pos + V(0, n.hip, 0)
			n.root.CFrame = CFrame.lookAt(at, at + V(dir.X, 0, dir.Z))
			if n.carrying then
				n.crate.CFrame = n.root.CFrame * CFrame.new(0, 3.6, -0.3)
			end
			for _, g in n.gear do
				g.part.CFrame = g.to.CFrame * g.off
				if g.tool then
					g.part.Transparency = if n.carrying then 1 else 0 -- both hands are on the crate
				end
			end
		end
	end)
end

------------------------------------------------------------------ wildlife
type Animal = { kind: string, parts: { [string]: BasePart }, pos: Vector3, target: Vector3, state: string, until_: number, phase: number, groundY: number, nextRay: number }

local function makeDeer(): { [string]: BasePart }
	local brown, light = Color3.fromRGB(150, 100, 60), Color3.fromRGB(214, 184, 140)
	local p = {}
	p.Body = part(folder, V(1.6, 1.6, 3.4), brown)
	p.Belly = part(folder, V(1.4, 0.3, 3), light)
	p.Neck = part(folder, V(0.8, 1.8, 0.8), brown)
	p.Head = part(folder, V(0.9, 0.9, 1.5), brown)
	p.Tail = part(folder, V(0.4, 0.5, 0.3), light)
	for _, n in { "LegFL", "LegFR", "LegBL", "LegBR" } do
		p[n] = part(folder, V(0.4, 2, 0.4), Color3.fromRGB(110, 74, 46))
	end
	p.AntL = part(folder, V(0.2, 1.2, 0.2), Color3.fromRGB(220, 200, 170))
	p.AntR = part(folder, V(0.2, 1.2, 0.2), Color3.fromRGB(220, 200, 170))
	return p
end

local function makeRabbit(): { [string]: BasePart }
	local c = if math.random() < 0.5 then Color3.fromRGB(190, 176, 160) else Color3.fromRGB(130, 110, 90)
	local p = {}
	p.Body = part(folder, V(0.9, 0.8, 1.2), c)
	p.Head = part(folder, V(0.7, 0.7, 0.7), c)
	p.EarL = part(folder, V(0.18, 0.7, 0.12), c)
	p.EarR = part(folder, V(0.18, 0.7, 0.12), c)
	p.Tail = part(folder, V(0.35, 0.35, 0.35), Color3.fromRGB(245, 245, 240), nil, Enum.PartType.Ball)
	return p
end

local function meadowSpot(around: Vector3): Vector3?
	for _ = 1, 12 do
		local a = math.random() * math.pi * 2
		local r = 90 + math.random() * 170
		local x, z = around.X + math.cos(a) * r, around.Z + math.sin(a) * r
		if math.sqrt(x * x + z * z) > 230 then
			local y, mat = groundAt(x, z)
			if y and (mat == Enum.Material.Grass or mat == Enum.Material.LeafyGrass) then
				-- keep clear of anything built
				local near = workspace:GetPartBoundsInRadius(V(x, y + 3, z), 14)
				local blocked = false
				for _, bp in near do
					if not bp:IsDescendantOf(folder) and bp.Transparency < 1 and not (bp.Parent and bp.Parent.Name == "Tree") then
						blocked = true
						break
					end
				end
				if not blocked then
					return V(x, y, z)
				end
			end
		end
	end
	return nil
end

local function poseAnimal(an: Animal, t: number)
	local p = an.parts
	local flat = V(an.target.X - an.pos.X, 0, an.target.Z - an.pos.Z)
	local dir = if flat.Magnitude > 0.1 then flat.Unit else V(0, 0, 1)
	if an.kind == "deer" then
		local moving = an.state == "walk"
		local swing = if moving then math.sin(t * 6 + an.phase) * 0.5 else 0
		local grazing = an.state == "graze"
		local root = CFrame.lookAt(V(an.pos.X, an.groundY + 2.8, an.pos.Z), V(an.pos.X, an.groundY + 2.8, an.pos.Z) + dir)
		p.Body.CFrame = root
		p.Belly.CFrame = root * CFrame.new(0, -0.8, 0)
		p.Tail.CFrame = root * CFrame.new(0, 0.4, 1.8)
		local neck = if grazing then CFrame.new(0, 0.2, -1.5) * CFrame.Angles(math.rad(-110), 0, 0) else CFrame.new(0, 1.2, -1.6) * CFrame.Angles(math.rad(-20), 0, 0)
		p.Neck.CFrame = root * neck
		p.Head.CFrame = root * neck * CFrame.new(0, 1.1, -0.4)
		p.AntL.CFrame = p.Head.CFrame * CFrame.new(-0.3, 0.9, 0.3) * CFrame.Angles(0, 0, math.rad(20))
		p.AntR.CFrame = p.Head.CFrame * CFrame.new(0.3, 0.9, 0.3) * CFrame.Angles(0, 0, math.rad(-20))
		p.LegFL.CFrame = root * CFrame.new(-0.55, -0.8, -1.2) * CFrame.Angles(swing, 0, 0) * CFrame.new(0, -1, 0)
		p.LegFR.CFrame = root * CFrame.new(0.55, -0.8, -1.2) * CFrame.Angles(-swing, 0, 0) * CFrame.new(0, -1, 0)
		p.LegBL.CFrame = root * CFrame.new(-0.55, -0.8, 1.2) * CFrame.Angles(-swing, 0, 0) * CFrame.new(0, -1, 0)
		p.LegBR.CFrame = root * CFrame.new(0.55, -0.8, 1.2) * CFrame.Angles(swing, 0, 0) * CFrame.new(0, -1, 0)
	else
		local hop = if an.state == "walk" then math.abs(math.sin(t * 8 + an.phase)) * 1.2 else 0
		local root = CFrame.lookAt(V(an.pos.X, an.groundY + 0.45 + hop, an.pos.Z), V(an.pos.X, an.groundY + 0.45 + hop, an.pos.Z) + dir)
		p.Body.CFrame = root
		p.Head.CFrame = root * CFrame.new(0, 0.4, -0.7)
		p.EarL.CFrame = p.Head.CFrame * CFrame.new(-0.15, 0.6, 0.1)
		p.EarR.CFrame = p.Head.CFrame * CFrame.new(0.15, 0.6, 0.1)
		p.Tail.CFrame = root * CFrame.new(0, 0.2, 0.65)
	end
end

local function wildlife()
	local animals: { Animal } = {}
	local function spawn(kind: string, around: Vector3): Animal?
		local at = meadowSpot(around)
		if not at then
			return nil
		end
		local parts = if kind == "deer" then makeDeer() else makeRabbit()
		return { kind = kind, parts = parts, pos = at, target = at, state = "graze", until_ = os.clock() + math.random() * 4, phase = math.random() * 6, groundY = at.Y, nextRay = 0 }
	end
	local function destroy(an: Animal)
		for _, p in an.parts do
			p:Destroy()
		end
	end
	local last = os.clock()
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local dt = math.min(0.1, t - last)
		last = t
		for _, an in animals do
			local flat = V(an.target.X - an.pos.X, 0, an.target.Z - an.pos.Z)
			if an.state == "walk" then
				local speed = if an.kind == "deer" then 4 else 6
				if flat.Magnitude < 0.6 then
					an.state = if math.random() < 0.6 then "graze" else "idle"
					an.until_ = t + 2 + math.random() * 5
				else
					an.pos += flat.Unit * math.min(flat.Magnitude, speed * dt)
				end
				if t > an.nextRay then
					an.nextRay = t + 0.25
					local y = groundAt(an.pos.X, an.pos.Z)
					if y then
						an.groundY = y
					end
				end
			elseif t > an.until_ then
				local a = math.random() * math.pi * 2
				local r = if an.kind == "deer" then 10 + math.random() * 18 else 4 + math.random() * 10
				an.target = an.pos + V(math.cos(a) * r, 0, math.sin(a) * r)
				an.state = "walk"
			end
			poseAnimal(an, t)
		end
	end)
	-- keep a small herd near the camera: respawn the ones left far behind
	task.spawn(function()
		while true do
			local cam = workspace.CurrentCamera
			if cam then
				local cp = cam.CFrame.Position
				for i = #animals, 1, -1 do
					if (animals[i].pos - cp).Magnitude > 380 then
						destroy(animals[i])
						table.remove(animals, i)
					end
				end
				local deer, rabbits = 0, 0
				for _, an in animals do
					if an.kind == "deer" then
						deer += 1
					else
						rabbits += 1
					end
				end
				if deer < 6 then
					local an = spawn("deer", cp)
					if an then
						table.insert(animals, an)
					end
				end
				if rabbits < 8 then
					local an = spawn("rabbit", cp)
					if an then
						table.insert(animals, an)
					end
				end
			end
			task.wait(1.5)
		end
	end)
end

------------------------------------------------------------------ sky: airplanes and hot-air balloons
local function airplanes()
	local function buildPlane(): (Model, BasePart, { { part: BasePart, rel: CFrame } })
		local m = Instance.new("Model")
		m.Name = "Airplane"
		local rels = {}
		local function p(size, cf, color, mat, shape)
			local x = part(m, size, color, mat, shape)
			x.CastShadow = false
			x.CFrame = cf
			table.insert(rels, { part = x, rel = cf })
			return x
		end
		local white, red = Color3.fromRGB(240, 242, 246), Color3.fromRGB(220, 60, 50)
		local body = p(V(26, 4.2, 4.2), CFrame.new(), white, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		p(V(4, 4.4, 4.4), CFrame.new(-13, 0, 0), red, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		p(V(5, 0.5, 34), CFrame.new(-1, -0.4, 0), white) -- wing
		p(V(5.2, 0.55, 8), CFrame.new(-1, -0.4, 13), red)
		p(V(5.2, 0.55, 8), CFrame.new(-1, -0.4, -13), red)
		p(V(4, 0.4, 12), CFrame.new(10.5, 0.3, 0), white) -- tailplane
		p(V(4.5, 5, 0.4), CFrame.new(10.8, 2.6, 0) * CFrame.Angles(0, 0, math.rad(-18)), red) -- fin
		p(V(0.4, 4.2, 0.5), CFrame.new(-14.6, 0, 0), Color3.fromRGB(40, 44, 52)) -- prop
		m.PrimaryPart = body
		-- contrail: two trails from the wing tips
		for _, z in { -16, 16 } do
			local a0 = Instance.new("Attachment")
			a0.Position = V(2, -0.4, z)
			a0.Parent = body
			local a1 = Instance.new("Attachment")
			a1.Position = V(2, -0.4, z + 0.4)
			a1.Parent = body
			local tr = Instance.new("Trail")
			tr.Attachment0, tr.Attachment1 = a0, a1
			tr.Lifetime = 5
			tr.MinLength = 0.1
			tr.LightEmission = 0.4
			tr.Color = ColorSequence.new(Color3.new(1, 1, 1))
			tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
			tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3) })
			tr.Parent = body
		end
		return m, body, rels
	end
	task.spawn(function()
		task.wait(8)
		while true do
			local m, body, rels = buildPlane()
			local a = math.random() * math.pi * 2
			local dir = V(math.cos(a), 0, math.sin(a))
			local side = V(-dir.Z, 0, dir.X) * math.random(-500, 500)
			local alt = 340 + math.random() * 120
			local start = side - dir * 1300 + V(0, alt, 0)
			local speed = 85 + math.random() * 30
			local t0 = os.clock()
			m.Parent = folder
			local conn
			conn = RunService.RenderStepped:Connect(function()
				local t = os.clock() - t0
				local pos = start + dir * speed * t + V(0, math.sin(t * 0.4) * 6, 0)
				-- the model's long axis is X pointing at the nose (-X): face the travel direction
				body.CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(math.sin(t * 0.7) * 0.06, 0, 0)
				for _, r in rels do
					r.part.CFrame = body.CFrame * r.rel
				end
			end)
			task.delay(2600 / speed, function()
				conn:Disconnect()
				m:Destroy()
			end)
			task.wait(45 + math.random() * 70)
		end
	end)
end

local function balloons()
	local colors = { Color3.fromRGB(235, 90, 70), Color3.fromRGB(70, 150, 230), Color3.fromRGB(250, 200, 60) }
	for i = 1, 3 do
		local m = Instance.new("Model")
		m.Name = "Balloon"
		local rels = {}
		local function p(size, cf, color, mat, shape)
			local x = part(m, size, color, mat, shape)
			x.CastShadow = false
			table.insert(rels, { part = x, rel = cf })
			return x
		end
		local c = colors[i]
		local env = p(V(22, 26, 22), CFrame.new(0, 24, 0), c, Enum.Material.Fabric, Enum.PartType.Ball)
		p(V(22.2, 3, 22.2), CFrame.new(0, 24, 0), Color3.fromRGB(245, 245, 240), Enum.Material.Fabric, Enum.PartType.Ball)
		p(V(6, 3.5, 6), CFrame.new(0, 7, 0), Color3.fromRGB(150, 104, 62), Enum.Material.WoodPlanks)
		for _, cx in { -2.5, 2.5 } do
			for _, cz in { -2.5, 2.5 } do
				p(V(0.2, 11, 0.2), CFrame.new(cx * 1.6, 13.5, cz * 1.6) * CFrame.Angles(cz * 0.03, 0, -cx * 0.03), Color3.fromRGB(90, 70, 50))
			end
		end
		m.PrimaryPart = env
		m.Parent = folder
		local radius = 520 + i * 90
		local phase = i * 2.1
		local alt = 170 + i * 30
		RunService.RenderStepped:Connect(function()
			local t = os.clock() * 0.012 + phase
			local pos = V(math.cos(t) * radius, alt + math.sin(os.clock() * 0.3 + i) * 8, math.sin(t) * radius)
			local cf = CFrame.new(pos) * CFrame.Angles(math.sin(os.clock() * 0.5 + i) * 0.04, os.clock() * 0.03, 0)
			for _, r in rels do
				r.part.CFrame = cf * r.rel
			end
		end)
	end
end

-- (Pass 21Q) a floating title over the Training Yard: visible from across the map, hidden once you are inside the pad
local function trainingSign()
	local world = workspace:WaitForChild("World", 30)
	local areas = world and world:WaitForChild("Areas", 30)
	local yard = areas and areas:WaitForChild("TrainingYard", 30)
	if not yard then
		return
	end
	task.wait(2)
	local cf, size = yard:GetBoundingBox()
	local y = groundAt(cf.Position.X, cf.Position.Z) or 0
	local an = Instance.new("Attachment")
	an.WorldPosition = V(cf.Position.X, y + 42, cf.Position.Z)
	an.Parent = workspace.Terrain
	local bb = Instance.new("BillboardGui")
	bb.Adornee = an
	bb.Size = UDim2.fromOffset(340, 78)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 2200
	bb.Parent = an
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.BuilderSansExtraBold
	l.TextSize = 30
	l.RichText = true
	l.TextColor3 = Color3.fromRGB(255, 200, 40)
	l.Text = "TRAINING YARD\n<font size=\"17\" color=\"rgb(255,255,255)\">RUN  -  LIFT  -  LEVEL UP</font>"
	l.Parent = bb
	local st = Instance.new("UIStroke")
	st.Thickness = 2.5
	st.Color = Color3.fromRGB(10, 12, 18)
	st.Parent = l
	task.spawn(function()
		while true do
			task.wait(0.5)
			local cam = workspace.CurrentCamera
			if cam then
				local d = (V(cf.Position.X, 0, cf.Position.Z) - V(cam.CFrame.Position.X, 0, cam.CFrame.Position.Z)).Magnitude
				bb.Enabled = d > math.max(size.X, size.Z) * 0.55
			end
		end
	end)
end

function LifeController.Start()
	folder = Instance.new("Folder")
	folder.Name = "MB_Life"
	folder.Parent = workspace
	groundParams.FilterDescendantsInstances = { workspace.Terrain }
	task.spawn(zoneBeacons)
	task.spawn(trainingSign)
	task.spawn(builderNPCs)
	task.spawn(wildlife)
	task.spawn(airplanes)
	task.spawn(balloons)
end

return LifeController
