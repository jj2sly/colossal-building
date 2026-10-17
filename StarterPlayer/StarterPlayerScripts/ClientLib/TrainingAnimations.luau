--!strict
-- Procedural R15 animations for the training stations, the crate / beam carries and the Worker crew (no uploaded assets).
--
-- Each animation is defined as a looping set of joint poses (built below as KeyframeSequence DATA, never registered or played
-- through the Animator: KeyframeSequences that are not uploaded assets only play inside Studio, never in a live server). A tiny
-- driver instead writes Motor6D.Transform on the R15 joints every frame, on EVERY client for that character, with weights, fades,
-- speed scaling and priority layering (a higher-priority overlay such as the carry arms overrides only the joints it poses, so the
-- walk cycle legs keep running underneath). R15 only: R6 rigs are ignored (no animation, no error).
--
-- PLACEHOLDER NOTE: these are hand-posed approximations. To replace one with an authored animation, upload it and set
-- TrainingConfig.Bench.AnimationId / TrainingConfig.Treadmill.AnimationId; TrainingAnimations.Play prefers that id.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TrainingConfig = require(ReplicatedStorage.Shared.Config.TrainingConfig)

local TrainingAnimations = {}

type PoseSet = { [string]: CFrame }

local function rx(deg: number, z: number?): CFrame
	return CFrame.Angles(math.rad(deg), 0, math.rad(z or 0))
end

-- R15 joint tree: each pose is named after the PART it moves; parent poses must match the rig hierarchy.
local TREE = {
	HumanoidRootPart = {
		LowerTorso = {
			UpperTorso = {
				Head = {},
				RightUpperArm = { RightLowerArm = { RightHand = {} } },
				LeftUpperArm = { LeftLowerArm = { LeftHand = {} } },
			},
			RightUpperLeg = { RightLowerLeg = { RightFoot = {} } },
			LeftUpperLeg = { LeftLowerLeg = { LeftFoot = {} } },
		},
	},
}

local function addPose(parent: Instance, name: string, children: any, set: PoseSet)
	local pose = Instance.new("Pose")
	pose.Name = name
	pose.CFrame = set[name] or CFrame.new()
	pose.Weight = if set[name] then 1 else 0
	pose.Parent = parent
	for childName, sub in children do
		addPose(pose, childName, sub, set)
	end
end

local function frame(ks: KeyframeSequence, t: number, set: PoseSet)
	local k = Instance.new("Keyframe")
	k.Time = t
	for rootName, sub in TREE do
		addPose(k, rootName, sub, set)
	end
	k.Parent = ks
end

-- Bench press (the body is already lying on its back, front facing up): arms push up and lower to the chest.
local function bench(): KeyframeSequence
	local ks = Instance.new("KeyframeSequence")
	ks.Name = "MB_BenchPress"
	ks.Loop = true
	ks.Priority = Enum.AnimationPriority.Action4
	local top: PoseSet = { RightUpperArm = rx(96, -10), LeftUpperArm = rx(96, 10), RightLowerArm = rx(4), LeftLowerArm = rx(4), UpperTorso = rx(-4) }
	local low: PoseSet = { RightUpperArm = rx(22, -56), LeftUpperArm = rx(22, 56), RightLowerArm = rx(116), LeftLowerArm = rx(116), UpperTorso = rx(2) }
	local rep = TrainingConfig.Bench.RepSeconds
	frame(ks, 0, top)
	frame(ks, rep * 0.45, low)
	frame(ks, rep * 0.55, low)
	frame(ks, rep, top)
	return ks
end

-- Treadmill: an in-place run cycle (opposite arms and legs, bent knees, slight forward lean).
local function treadmill(): KeyframeSequence
	local ks = Instance.new("KeyframeSequence")
	ks.Name = "MB_TreadmillRun"
	ks.Loop = true
	ks.Priority = Enum.AnimationPriority.Action4
	local period = 1 / TrainingConfig.Treadmill.RunCycleHz
	local function pose(phase: number): PoseSet
		local a = math.sin(phase)
		local b = math.sin(phase + math.pi)
		local function knee(v: number): number
			-- knee folds most while the leg swings forward
			return -(25 + 45 * math.max(0, math.cos(v + 0.9)))
		end
		return {
			UpperTorso = rx(-7),
			RightUpperLeg = rx(48 * a),
			LeftUpperLeg = rx(48 * b),
			RightLowerLeg = rx(knee(phase)),
			LeftLowerLeg = rx(knee(phase + math.pi)),
			RightUpperArm = rx(-45 * a),
			LeftUpperArm = rx(-45 * b),
			RightLowerArm = rx(70),
			LeftLowerArm = rx(70),
		}
	end
	for i = 0, 8 do
		frame(ks, period * i / 8, pose(i / 8 * 2 * math.pi))
	end
	return ks
end

-- Worker crew animations (played on the Worker characters by WorkerVisualController).
local function workerWalk(): KeyframeSequence
	local ks = Instance.new("KeyframeSequence")
	ks.Name = "MB_WorkerWalk"
	ks.Loop = true
	ks.Priority = Enum.AnimationPriority.Action
	local period = 0.7
	for i = 0, 4 do
		local ph = i / 4 * 2 * math.pi
		local a, b = math.sin(ph), math.sin(ph + math.pi)
		frame(ks, period * i / 4, {
			UpperTorso = rx(-3),
			RightUpperLeg = rx(32 * a),
			LeftUpperLeg = rx(32 * b),
			RightLowerLeg = rx(-(8 + 26 * math.max(0, math.cos(ph + 0.9)))),
			LeftLowerLeg = rx(-(8 + 26 * math.max(0, math.cos(ph + math.pi + 0.9)))),
			RightUpperArm = rx(-30 * a),
			LeftUpperArm = rx(-30 * b),
			RightLowerArm = rx(18),
			LeftLowerArm = rx(18),
		})
	end
	return ks
end

-- Gather: a short repeated work motion (modest swing; the right arm works, the left braces).
local function workerWork(): KeyframeSequence
	local ks = Instance.new("KeyframeSequence")
	ks.Name = "MB_WorkerWork"
	ks.Loop = true
	ks.Priority = Enum.AnimationPriority.Action
	local up: PoseSet = { UpperTorso = rx(4), RightUpperArm = rx(80, -8), RightLowerArm = rx(40), LeftUpperArm = rx(20, 10), LeftLowerArm = rx(28), Head = rx(-4) }
	local down: PoseSet = { UpperTorso = rx(-14), RightUpperArm = rx(18, -6), RightLowerArm = rx(58), LeftUpperArm = rx(20, 10), LeftLowerArm = rx(28), Head = rx(-8) }
	frame(ks, 0, up)
	frame(ks, 0.3, down)
	frame(ks, 0.42, down)
	frame(ks, 0.8, up)
	return ks
end

-- Idle: a subtle breathing / weight-shift loop so a waiting Worker is never a frozen statue.
local function workerIdle(): KeyframeSequence
	local ks = Instance.new("KeyframeSequence")
	ks.Name = "MB_WorkerIdle"
	ks.Loop = true
	ks.Priority = Enum.AnimationPriority.Action
	local a: PoseSet = { UpperTorso = rx(1.5), Head = rx(2), RightUpperArm = rx(4, -4), LeftUpperArm = rx(4, 4), RightLowerArm = rx(8), LeftLowerArm = rx(8) }
	local b: PoseSet = { UpperTorso = rx(-1.5), Head = rx(-1.5), RightUpperArm = rx(-3, -6), LeftUpperArm = rx(-3, 6), RightLowerArm = rx(12), LeftLowerArm = rx(12), LowerTorso = rx(0, 1) }
	frame(ks, 0, a)
	frame(ks, 1.6, b)
	frame(ks, 3.2, a)
	return ks
end

-- Carrying overlay: both arms hold a load in front of the chest. Higher priority than walking, and it only poses the torso and
-- arms, so the walk cycle's legs keep running underneath.
local function workerCarry(): KeyframeSequence
	local ks = Instance.new("KeyframeSequence")
	ks.Name = "MB_WorkerCarry"
	ks.Loop = true
	ks.Priority = Enum.AnimationPriority.Action2
	local a: PoseSet = { UpperTorso = rx(6), RightUpperArm = rx(62, -19), LeftUpperArm = rx(62, 19), RightLowerArm = rx(18), LeftLowerArm = rx(18) }
	local b: PoseSet = { UpperTorso = rx(4), RightUpperArm = rx(58, -19), LeftUpperArm = rx(58, 19), RightLowerArm = rx(14), LeftLowerArm = rx(14) }
	frame(ks, 0, a)
	frame(ks, 0.35, b)
	frame(ks, 0.7, a)
	return ks
end

-- Deposit: lean forward and set the load down, then straighten up (loops while the Worker is at the project).
local function workerPlace(): KeyframeSequence
	local ks = Instance.new("KeyframeSequence")
	ks.Name = "MB_WorkerPlace"
	ks.Loop = true
	ks.Priority = Enum.AnimationPriority.Action
	local hold: PoseSet = { UpperTorso = rx(2), RightUpperArm = rx(62, -19), LeftUpperArm = rx(62, 19), RightLowerArm = rx(18), LeftLowerArm = rx(18) }
	local set: PoseSet = { UpperTorso = rx(-22), RightUpperArm = rx(38, -12), LeftUpperArm = rx(38, 12), RightLowerArm = rx(6), LeftLowerArm = rx(6), Head = rx(6) }
	frame(ks, 0, hold)
	frame(ks, 0.45, set)
	frame(ks, 0.7, set)
	frame(ks, 1.15, hold)
	return ks
end

-- Player training carries (played on the carrier by every client; the server welds the prop, these poses make it read as held).
-- Crate: arms forward at hip height, a gentle lift/lower rhythm. Beam: arms overhead, slower and heavier, with a slow sway.
local function carryCrate(): KeyframeSequence
	local ks = Instance.new("KeyframeSequence")
	ks.Name = "MB_CarryCrate"
	ks.Loop = true
	ks.Priority = Enum.AnimationPriority.Action2
	local a: PoseSet = { UpperTorso = rx(7), RightUpperArm = rx(58, -14), LeftUpperArm = rx(58, 14), RightLowerArm = rx(14), LeftLowerArm = rx(14) }
	local b: PoseSet = { UpperTorso = rx(5), RightUpperArm = rx(66, -14), LeftUpperArm = rx(66, 14), RightLowerArm = rx(18), LeftLowerArm = rx(18) }
	frame(ks, 0, a)
	frame(ks, 0.45, b)
	frame(ks, 0.9, a)
	return ks
end

local function carryBeam(): KeyframeSequence
	local ks = Instance.new("KeyframeSequence")
	ks.Name = "MB_CarryBeam"
	ks.Loop = true
	ks.Priority = Enum.AnimationPriority.Action2
	local a: PoseSet = { UpperTorso = rx(9, 2), Head = rx(4), RightUpperArm = rx(168, -8), LeftUpperArm = rx(168, 8), RightLowerArm = rx(6), LeftLowerArm = rx(6) }
	local b: PoseSet = { UpperTorso = rx(6, -2), Head = rx(2), RightUpperArm = rx(160, -10), LeftUpperArm = rx(160, 10), RightLowerArm = rx(12), LeftLowerArm = rx(12) }
	frame(ks, 0, a)
	frame(ks, 0.8, b)
	frame(ks, 1.6, a)
	return ks
end

local builders: { [string]: () -> KeyframeSequence } = {
	Bench = bench, Treadmill = treadmill, WorkerWalk = workerWalk, WorkerWork = workerWork, WorkerIdle = workerIdle, WorkerCarry = workerCarry,
	WorkerPlace = workerPlace, CarryCrate = carryCrate, CarryBeam = carryBeam,
}

------------------------------------------------------------------ pose driver
type Compiled = { length: number, keys: { { t: number, pose: { [string]: CFrame } } }, priority: number }
local compiled: { [string]: Compiled } = {}
local PRIORITY = { Idle = 1, Movement = 2, Action = 3, Action2 = 4, Action3 = 5, Action4 = 6 }

local function compile(kind: string): Compiled?
	local have = compiled[kind]
	if have then
		return have
	end
	local build = builders[kind]
	if not build then
		return nil
	end
	local ks = build()
	local keys = {}
	for _, k in ks:GetChildren() do
		if k:IsA("Keyframe") then
			local pose: { [string]: CFrame } = {}
			for _, p in k:GetDescendants() do
				if p:IsA("Pose") and p.Weight > 0 then
					pose[p.Name] = p.CFrame
				end
			end
			table.insert(keys, { t = k.Time, pose = pose })
		end
	end
	table.sort(keys, function(a, b)
		return a.t < b.t
	end)
	local out: Compiled = { length = math.max(keys[#keys].t, 0.05), keys = keys, priority = PRIORITY[ks.Priority.Name] or 3 }
	ks:Destroy()
	compiled[kind] = out
	return out
end

local IDENTITY = CFrame.new()
local function evaluate(c: Compiled, time: number, into: { [string]: CFrame })
	local tt = time % c.length
	local keys = c.keys
	local i = 1
	while i < #keys and keys[i + 1].t <= tt do
		i += 1
	end
	local a, b = keys[i], keys[math.min(i + 1, #keys)]
	local span = b.t - a.t
	local alpha = if span > 1e-4 then math.clamp((tt - a.t) / span, 0, 1) else 0
	for name, cf in a.pose do
		into[name] = cf:Lerp(b.pose[name] or IDENTITY, alpha)
	end
	for name, cf in b.pose do
		if not a.pose[name] then
			into[name] = IDENTITY:Lerp(cf, alpha)
		end
	end
end

-- AnimationTrack look-alike: callers only use Stop / AdjustSpeed / Speed / WeightCurrent / Animation.Name.
local Track = {}
Track.__index = Track
function Track:Stop(fade: number?)
	self.stopping = true
	self.fadeOut = math.max(fade or 0.1, 0.01)
end
function Track:AdjustSpeed(speed: number)
	self.Speed = speed
end

-- R15 characters use either classic Motor6D joints or the newer AnimationConstraint joints; both expose Transform. The Animator rewrites
-- Transform of the joints it animates once per frame BEFORE PreSimulation, so a write at PreSimulation (RunService.Stepped) lands after it
-- and wins for that frame; that is where this driver runs. (Writes at PreRender / PreAnimation / PostSimulation are overwritten.)
type CharState = { tracks: { any }, joints: { [string]: Instance? }, driven: { [string]: boolean }, last: { [string]: CFrame } }
local chars: { [Model]: CharState } = {}
local connection: RBXScriptConnection? = nil

local function jointFor(char: Model, st: CharState, partName: string): Instance?
	local cached = st.joints[partName]
	if cached and cached.Parent then
		return cached
	end
	local part = char:FindFirstChild(partName)
	if part then
		for _, j in part:GetChildren() do
			if (j:IsA("Motor6D") and j.Part1 == part) or (j:IsA("AnimationConstraint") and j.Attachment1 and j.Attachment1.Parent == part) then
				st.joints[partName] = j
				return j
			end
		end
	end
	return nil
end

local function step(dt: number)
	for char, st in chars do
		if not char.Parent then
			chars[char] = nil
			continue
		end
		for i = #st.tracks, 1, -1 do
			local tr = st.tracks[i]
			tr.time += dt * tr.Speed
			if tr.stopping then
				tr.WeightCurrent -= dt / tr.fadeOut
				if tr.WeightCurrent <= 0 then
					tr.WeightCurrent = 0
					tr.IsPlaying = false
					table.remove(st.tracks, i)
				end
			else
				tr.WeightCurrent = math.min(1, tr.WeightCurrent + dt / tr.fadeIn)
			end
		end
		-- layer the tracks lowest priority first; a higher layer replaces only the joints it poses
		table.sort(st.tracks, function(a, b)
			if a.data.priority ~= b.data.priority then
				return a.data.priority < b.data.priority
			end
			return a.order < b.order
		end)
		-- Joints are driven through Motor6D.C0, NOT Transform: the Animator (the default walk / idle of a player) rewrites Transform every
		-- frame and would overwrite us. Rendered joint = C0 * Transform, so C0 = baseC0 * wanted * Transform^-1 cancels whatever the
		-- Animator is doing and lands exactly on the pose; with no track left C0 goes back to its original value.
		local posed: { { [string]: CFrame } } = {}
		local names: { [string]: boolean } = {}
		for _, tr in st.tracks do
			local pose: { [string]: CFrame } = {}
			evaluate(tr.data, tr.time, pose)
			table.insert(posed, pose)
			for name in pose do
				names[name] = true
			end
		end
		for name in names do
			local j = jointFor(char, st, name) :: any
			if j then
				-- what the Animator wants for this joint (identity when nothing animates it, e.g. a Worker, or when the value is still the one we wrote)
				local now = j.Transform
				local mine = st.last[name]
				local natural = if mine and now == mine then IDENTITY else now
				local cur = natural
				for i, tr in st.tracks do
					local cf = posed[i][name]
					if cf then
						cur = cur:Lerp(cf, tr.WeightCurrent)
					end
				end
				j.Transform = cur
				st.last[name] = cur
				st.driven[name] = true
			end
		end
		for name in st.driven do
			if not names[name] then
				local j = jointFor(char, st, name) :: any
				if j then
					j.Transform = IDENTITY -- released: an animated joint goes back to the Animator next frame, an idle one to its rest pose
				end
				st.last[name] = nil
				st.driven[name] = nil
			end
		end
		if #st.tracks == 0 and next(st.driven) == nil then
			chars[char] = nil
		end
	end
	if next(chars) == nil and connection then
		connection:Disconnect()
		connection = nil
	end
end

local counter = 0
local warnedRig = false

-- Starts the looping animation on an R15 character. Returns a track (call :Stop(fade) to end it) or nil. `keepPriority` keeps the
-- animation's own priority (Worker / carry layers); without it the animation is top priority (training machines replace everything).
function TrainingAnimations.Play(character: Model, kind: string, keepPriority: boolean?): any?
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.RigType ~= Enum.HumanoidRigType.R15 then
		if hum and not warnedRig then
			warnedRig = true
			warn("[TrainingAnimations] R15 only: skipping animation on a non-R15 rig")
		end
		return nil
	end
	local data = compile(kind)
	if not data then
		return nil
	end
	counter += 1
	local tr = setmetatable({
		data = { length = data.length, keys = data.keys, priority = if keepPriority then data.priority else PRIORITY.Action4 },
		time = 0,
		Speed = 1,
		WeightCurrent = 0,
		fadeIn = 0.2,
		fadeOut = 0.2,
		stopping = false,
		IsPlaying = true,
		order = counter,
		Animation = { Name = "MB_" .. kind },
	}, Track)
	local st = chars[character]
	if not st then
		st = { tracks = {}, joints = {}, driven = {}, last = {} }
		chars[character] = st
	end
	table.insert(st.tracks, tr)
	if not connection then
		connection = RunService.PreSimulation:Connect(step)
	end
	return tr
end

return TrainingAnimations
