--!nonstrict
-- Shared kit for COLOSSAL build templates (edit-time only). One module per build in this folder returns
--   { Id = "<BuildConfig id>", Build = function(kit) -> Model }
-- and TemplateBuilderColossal runs them all into ServerStorage.BuildTemplates.
--
-- Conventions (on top of docs/BUILD_AUTHORING.md):
--   * Author at FINAL WORLD SIZE (BuildConfig TemplateScale = 1). Units are studs.
--   * Local origin = the deck centre on the deck surface (ColossalConfig.OriginCFrame). Y = 0 is the deck; the template
--     FRONT faces -Z (BuildService turns it to face the spawn). Stay inside the 90-stud deck radius at ground level.
--   * Stage_01 .. Stage_NN Models; every stage must change major mass / height / width / mechanism.
--   * Named Models ("groups") inside stages are what the client show modules animate (ClientLib/BuildShows/<Id>).
--     A group may be split across stages: the client collects every Model with that name.
local Kit = {}
local V = Vector3.new
Kit.V = V
Kit.M = Enum.Material
Kit.RGB = Color3.fromRGB

local count = 0
function Kit.ResetCount()
	count = 0
end
function Kit.Count(): number
	return count
end

function Kit.template(name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	return m
end

function Kit.stage(m: Model, i: number): Model
	local s = Instance.new("Model")
	s.Name = string.format("Stage_%02d", i)
	s.Parent = m
	return s
end

-- a named group (Model) inside a stage, animated by the build's client show
function Kit.group(parent: Instance, name: string): Model
	local g = Instance.new("Model")
	g.Name = name
	g.Parent = parent
	return g
end

local function finish(p: BasePart, parent: Instance, color: Color3, mat: Enum.Material?, attrs: { [string]: any }?)
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	for k, v in attrs or {} do
		p:SetAttribute(k, v)
	end
	p.Parent = parent
	count += 1
	return p
end

function Kit.box(parent: Instance, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, attrs: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Size, p.CFrame = size, cf
	return finish(p, parent, color, mat, attrs)
end

-- WedgePart: slope rises toward +Z (tall face at +Z, low edge at -Z)
function Kit.wedge(parent: Instance, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, attrs: { [string]: any }?): WedgePart
	local p = Instance.new("WedgePart")
	p.Size, p.CFrame = size, cf
	return finish(p, parent, color, mat, attrs)
end

-- vertical cylinder centred at cf (height along cf's Y)
function Kit.cyl(parent: Instance, d: number, h: number, cf: CFrame, color: Color3, mat: Enum.Material?, attrs: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Size, p.CFrame = V(h, d, d), cf * CFrame.Angles(0, 0, math.rad(90))
	return finish(p, parent, color, mat, attrs)
end

-- cylinder lying along cf's Z axis
function Kit.cylZ(parent: Instance, d: number, len: number, cf: CFrame, color: Color3, mat: Enum.Material?, attrs: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Size, p.CFrame = V(len, d, d), cf * CFrame.Angles(0, math.rad(90), 0)
	return finish(p, parent, color, mat, attrs)
end

-- ellipsoid (sphere mesh on a box): size = full extents
function Kit.ell(parent: Instance, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, attrs: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Size, p.CFrame = size, cf
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return finish(p, parent, color, mat, attrs)
end

-- square beam between two points
function Kit.bar(parent: Instance, a: Vector3, b: Vector3, t: number, color: Color3, mat: Enum.Material?, attrs: { [string]: any }?): Part
	return Kit.box(parent, V(t, t, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, mat, attrs)
end

-- an empty marker (anchor for client effects: smoke, lights, muzzle points). Invisible, non-colliding, not counted.
function Kit.marker(parent: Instance, name: string, pos: Vector3, look: Vector3?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = V(1, 1, 1)
	p.CFrame = if look then CFrame.lookAt(pos, pos + look) else CFrame.new(pos)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency = true, false, false, false, 1
	p:SetAttribute("Marker", true)
	p.Parent = parent
	return p
end

return Kit
