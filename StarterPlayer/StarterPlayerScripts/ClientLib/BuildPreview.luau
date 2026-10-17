--!strict
-- 3D build previews for the Build Index. Each preview is one ViewportFrame holding a clone of
-- ReplicatedStorage.BuildPreviews/<BuildId> (made by the server from the real templates).
--   * discovered  -> lit model, slowly orbiting camera (rotating the camera is far cheaper than
--                    moving model parts)
--   * undiscovered -> the same model as a dark silhouette, no animation
-- A single shared RenderStepped connection drives every orbiting preview and exists only while
-- previews exist and the Index is active. `BuildPreview.clear()` destroys everything (the Index
-- calls it whenever it redraws or closes), so nothing accumulates across opens.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UI = require(script.Parent.UI)

local BuildPreview = {}

type Entry = { vp: ViewportFrame, camera: Camera, center: Vector3, dist: number, phase: number, spin: boolean }
local entries: { Entry } = {}
local conn: RBXScriptConnection? = nil
local active = true
local clipFrame: GuiObject? = nil -- the scroll frame previews live in; off-screen previews are hidden (not rendered)
local SPIN_SPEED = 0.45 -- radians per second
local ELEVATION = math.rad(18)

local function place(e: Entry, angle: number)
	local dir = Vector3.new(math.sin(angle) * math.cos(ELEVATION), math.sin(ELEVATION), math.cos(angle) * math.cos(ELEVATION))
	e.camera.CFrame = CFrame.lookAt(e.center + dir * e.dist, e.center)
end

local function ensureLoop()
	if conn or not active then
		return
	end
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local i = 1
		while i <= #entries do
			local e = entries[i]
			if not e.vp.Parent then
				table.remove(entries, i) -- destroyed by a redraw
			else
				local clip = clipFrame
				if clip then
					local ap, as = e.vp.AbsolutePosition, e.vp.AbsoluteSize
					local cp, cs = clip.AbsolutePosition, clip.AbsoluteSize
					local on = ap.Y + as.Y > cp.Y and ap.Y < cp.Y + cs.Y
					if e.vp.Visible ~= on then
						e.vp.Visible = on
					end
				end
				if e.spin and e.vp.Visible then
					place(e, e.phase + t * SPIN_SPEED)
				end
				i += 1
			end
		end
		if #entries == 0 and conn then
			conn:Disconnect()
			conn = nil
		end
	end)
end

-- Previews outside this frame's bounds are switched off so scrolling a long Index stays cheap.
function BuildPreview.setClip(frame: GuiObject?)
	clipFrame = frame
end

function BuildPreview.clear()
	for i = #entries, 1, -1 do
		entries[i].vp:Destroy()
	end
	table.clear(entries)
	if conn then
		conn:Disconnect()
		conn = nil
	end
end

-- Pause/resume the orbit (the Index calls this when it is hidden).
function BuildPreview.setActive(on: boolean)
	active = on
	if on then
		ensureLoop()
	elseif conn then
		conn:Disconnect()
		conn = nil
	end
end

-- Returns the ViewportFrame, or nil when no preview model exists for the build.
function BuildPreview.create(parent: Instance, buildId: string, silhouette: boolean, order: number?): ViewportFrame?
	local previews = ReplicatedStorage:FindFirstChild("BuildPreviews")
	local source = previews and previews:FindFirstChild(buildId)
	if not source then
		return nil
	end
	local vp = UI.new("ViewportFrame", {
		Name = "Preview",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		LayoutOrder = order or 0,
		Parent = parent,
	})
	if silhouette then
		vp.Ambient = Color3.fromRGB(20, 26, 40)
		vp.LightColor = Color3.fromRGB(60, 100, 170)
	else
		vp.Ambient = Color3.fromRGB(150, 150, 160)
		vp.LightColor = Color3.fromRGB(255, 244, 228)
	end
	vp.LightDirection = Vector3.new(-1, -1.4, -0.6)
	local model = source:Clone()
	if silhouette then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Color = Color3.fromRGB(12, 16, 26)
				d.Material = Enum.Material.SmoothPlastic
				d.Reflectance = 0
				d.Transparency = if d.Transparency > 0.9 then 1 else 0
			elseif d:IsA("Decal") or d:IsA("Texture") or d:IsA("SurfaceAppearance") then
				d:Destroy()
			end
		end
	end
	model.Parent = vp
	local cf, size = (model :: Model):GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 34
	camera.Parent = vp
	vp.CurrentCamera = camera
	-- fit by height and by the horizontal diagonal (the model orbits), for a roughly 1.5:1 frame
	local halfTan = math.tan(math.rad(camera.FieldOfView / 2))
	local fitH = (size.Y / 2) / halfTan
	local fitW = (math.sqrt(size.X * size.X + size.Z * size.Z) / 2) / (halfTan * 1.5)
	local fit = math.max(fitH, fitW) * 1.22 + math.sqrt(size.X * size.X + size.Z * size.Z) * 0.25
	local entry: Entry = {
		vp = vp,
		camera = camera,
		center = cf.Position,
		dist = fit,
		phase = (#entries * 1.3) % (math.pi * 2), -- stagger so cards don't turn in lockstep
		spin = not silhouette,
	}
	place(entry, if silhouette then math.rad(35) else entry.phase)
	table.insert(entries, entry)
	ensureLoop()
	return vp
end

return BuildPreview
