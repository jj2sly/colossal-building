--!strict
-- BUILD SHOWS (client only). Per-build presentation for colossal builds, one module per build in ClientLib/BuildShows:
--   Activate(sess, lib)          the build "comes alive" at its activation point (State BuildActivated)
--   Milestone(sess, lib, n)      later activation steps (State BuildMilestone = n)
--   Spectacle(ctx, sess, lib)    the completion show (registered with SpectacleController under the build's
--                                CompletionSpectacle id; ctx is SpectacleController's context)
-- Everything is driven by replicated state, so late joiners see a build that is already alive. Motion only touches the
-- client's copy of the parts; the session ends (connections + temporary instances cleaned) when the build is reset.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BuildConfig = require(ReplicatedStorage.Shared.Config.BuildConfig)
local Lib = script.Parent.Parent.ClientLib
local State = require(Lib.State)
local Sound = require(Lib.Sound)
local Cine = require(Lib.Cine)
local SpectacleController = require(script.Parent.SpectacleController)

local BuildShowController = {}

------------------------------------------------------------------ lib shared with every show module
local lib = {}
lib.Sound = Sound
lib.Cine = Cine

function lib.tween(inst: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Sine, dir or Enum.EasingDirection.InOut), props)
	tw:Play()
	return tw
end

-- a piece is "settled" once its build-in rise animation is over (or it was never animated)
function lib.settled(p: BasePart): boolean
	local at = p:GetAttribute("BuiltAt")
	return type(at) ~= "number" or State.ServerNow() - at > 1.6
end

-- every BasePart inside every Model called `name` in the build
function lib.group(model: Instance, name: string): { BasePart }
	local out = {}
	for _, g in model:GetDescendants() do
		if g.Name == name and g:IsA("Model") then
			for _, p in g:GetDescendants() do
				if p:IsA("BasePart") then
					table.insert(out, p)
				end
			end
		end
	end
	return out
end

function lib.find(model: Instance, name: string): BasePart?
	local d = model:FindFirstChild(name, true)
	return if d and d:IsA("BasePart") then d else nil
end

function lib.light(parent: Instance, color: Color3, range: number, brightness: number, trash: { Instance }): PointLight
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = color, range, brightness, false
	l.Parent = parent
	table.insert(trash, l)
	return l
end

function lib.emitter(parent: Instance, texture: string, color: Color3, size: number, life: number, speed: number, trash: { Instance }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Color = ColorSequence.new(color)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.5), NumberSequenceKeypoint.new(1, size * 1.6) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(life * 0.7, life)
	e.Speed = NumberRange.new(speed * 0.6, speed)
	e.SpreadAngle = Vector2.new(12, 12)
	e.Rate = 0
	e.Parent = parent
	table.insert(trash, e)
	return e
end

lib.SMOKE = "rbxasset://textures/particles/smoke_main.dds"
lib.SPARK = "rbxasset://textures/particles/sparkles_main.dds"

-- an invisible anchor part at a position (for emitters / lights that must not ride a moving part)
function lib.anchor(pos: Vector3, trash: { Instance }): Part
	local p = Instance.new("Part")
	p.Name = "MB_ShowAnchor"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency = true, false, false, false, 1
	p.Size = Vector3.one
	p.Position = pos
	p.Parent = workspace
	table.insert(trash, p)
	return p
end

-- cached group lookup for per-frame motion (refreshed twice a second, so newly built pieces join in)
function lib.groupOf(sess: any, name: string): { BasePart }
	sess.gcache = sess.gcache or {}
	local e = sess.gcache[name]
	if not e or os.clock() - e.t > 0.5 then
		e = { t = os.clock(), list = lib.group(sess.model, name) }
		sess.gcache[name] = e
	end
	return e.list
end

-- Moves every settled part of group `name` as: pre * (rotation by `angle` about `axis` (template space) through marker `marker`) * base.
-- `pre` is an optional world-space transform (an elevation, a recoil offset). Motions are offsets of the rig, never accumulating.
function lib.spin(sess: any, name: string, marker: string?, axis: Vector3?, angle: number, pre: CFrame?)
	local m = sess.model
	local X = CFrame.identity
	if marker and axis and angle ~= 0 then
		local mk = lib.find(m, marker)
		local mb = mk and sess:base(mk)
		if mb then
			local c = mb.Position
			X = CFrame.new(c) * CFrame.fromAxisAngle(m:GetPivot().Rotation * axis, angle) * CFrame.new(-c)
		end
	end
	if pre then
		X = pre * X
	end
	for _, p in lib.groupOf(sess, name) do
		local b = sess:base(p)
		if b then
			p.CFrame = X * b
		end
	end
end

------------------------------------------------------------------ sessions
export type Session = {
	model: Model,
	buildId: string,
	paused: boolean,
	milestone: number,
	trash: { Instance },
	conns: { RBXScriptConnection },
	alive: () -> boolean,
	-- per-frame callback while the session lives (skipped while a spectacle owns the build)
	step: (self: Session, fn: (dt: number, t: number) -> ()) -> (),
	-- motion rig: remembers each settled part's original CFrame so motions are offsets, never accumulating
	rig: { [BasePart]: CFrame },
	base: (self: Session, p: BasePart) -> CFrame?,
}

local current: Session? = nil

local function newSession(model: Model, buildId: string): Session
	local t0 = os.clock()
	local sess: any = {
		model = model,
		buildId = buildId,
		paused = false,
		milestone = 0,
		trash = {},
		conns = {},
		rig = {},
	}
	sess.alive = function()
		return model.Parent ~= nil and current == sess
	end
	sess.step = function(self, fn)
		table.insert(self.conns, RunService.RenderStepped:Connect(function(dt)
			if not self.paused then
				fn(dt, os.clock() - t0)
			end
		end))
	end
	sess.base = function(self, p: BasePart): CFrame?
		local cf = self.rig[p]
		if cf then
			return cf
		end
		if p.Parent and lib.settled(p) then
			self.rig[p] = p.CFrame
			return p.CFrame
		end
		return nil
	end
	return sess
end

local function endSession()
	local s = current
	current = nil
	if not s then
		return
	end
	for _, c in s.conns do
		c:Disconnect()
	end
	for _, inst in s.trash do
		if inst.Parent then
			inst:Destroy()
		end
	end
end

local function showFor(buildId: string): any
	local def = BuildConfig.Get(buildId)
	local folder = Lib:FindFirstChild("BuildShows")
	-- a Forgotten build is not in the client's BuildConfig at all: its show module is found by the opaque key
	local mod = folder and folder:FindFirstChild(if def then ((def :: any).Show or buildId) else buildId)
	if not mod then
		return nil
	end
	local ok, show = pcall(require, mod)
	return if ok then show else nil
end

local function sync()
	local model = workspace:FindFirstChild("ActiveBuild")
	local buildId = State.Get("BuildId")
	local activated = State.Get("BuildActivated") == true
	if current and (not model or current.model ~= model or current.buildId ~= buildId or not activated) then
		endSession()
	end
	if not model or not model:IsA("Model") or type(buildId) ~= "string" or buildId == "" or not activated then
		return
	end
	local show = showFor(buildId)
	if not show then
		return
	end
	if not current then
		current = newSession(model, buildId)
		if show.Activate then
			task.spawn(show.Activate, current, lib)
		end
	end
	local sess = current :: Session
	local ms = tonumber(State.Get("BuildMilestone")) or 0
	while sess.milestone < ms do
		sess.milestone += 1
		if show.Milestone then
			task.spawn(show.Milestone, sess, lib, sess.milestone)
		end
	end
end

function BuildShowController.Start()
	-- every build with a show module and a completion spectacle gets its handler registered
	for id, def in BuildConfig.Builds do
		local d = def :: any
		local show = showFor(id)
		if show and show.Spectacle and d.CompletionSpectacle then
			SpectacleController.Register(d.CompletionSpectacle, function(ctx)
				sync()
				local sess = current
				if sess then
					sess.paused = true
				end
				show.Spectacle(ctx, sess, lib)
			end)
		end
	end
	-- Forgotten shows export their own SpectacleId (their builds are not in BuildConfig on the client)
	local folder = Lib:FindFirstChild("BuildShows")
	for _, mod in if folder then folder:GetChildren() else {} do
		local okS, show = pcall(require, mod)
		if okS and type(show) == "table" and show.SpectacleId and show.Spectacle then
			SpectacleController.Register(show.SpectacleId, function(ctx)
				sync()
				local sess = current
				if sess then
					sess.paused = true
				end
				show.Spectacle(ctx, sess, lib)
			end)
		end
	end
	for _, key in { "BuildActivated", "BuildMilestone", "BuildId" } do
		State.Changed(key, function()
			task.defer(sync)
		end)
	end
	task.spawn(function()
		while true do
			task.wait(0.5)
			pcall(sync)
		end
	end)
end

BuildShowController.lib = lib
return BuildShowController
