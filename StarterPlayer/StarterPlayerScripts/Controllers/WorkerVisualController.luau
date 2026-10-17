--!strict
-- Smooth worker movement + crew animation. The server only publishes each leg (LegFrom, LegTo, LegStart,
-- LegDuration) and the Worker's State; every client interpolates the position locally and plays a local walk / work
-- animation on the Worker character (a standard R15 rig dressed in an outfit). One Heartbeat loop handles all
-- workers (max one per player); animation tracks only exist for Workers near the camera.
local RunService = game:GetService("RunService")

local TrainingAnimations = require(script.Parent.Parent.ClientLib.TrainingAnimations)

local WorkerVisualController = {}

type Leg = { from: Vector3, to: Vector3, start: number, duration: number }
local legs: { [Model]: Leg } = {}

local MOVING = { ToZone = true, ToSite = true, ToStation = true, Moving = true }
local WORKING = { Gathering = true, Depositing = true }
-- per Worker: one base animation (Idle / Walk / Work / Place) plus an optional carrying-arms overlay that only exists while it walks with a load
type WorkerTracks = { kind: string, track: AnimationTrack, carry: AnimationTrack? }
local tracks: { [Model]: WorkerTracks } = {}
local WALK_REF_SPEED = 12 -- studs/s at which the walk cycle (0.7 s) looks right; the track speed scales from it
local ANIM_RANGE = 110

local function readLeg(m: Model)
	local from, to = m:GetAttribute("LegFrom"), m:GetAttribute("LegTo")
	local start, dur = m:GetAttribute("LegStart"), m:GetAttribute("LegDuration")
	if typeof(from) == "Vector3" and typeof(to) == "Vector3" and type(start) == "number" and type(dur) == "number" then
		legs[m] = { from = from, to = to, start = start, duration = dur }
	end
end

local function track(m: Instance)
	if not m:IsA("Model") then
		return
	end
	readLeg(m)
	m:GetAttributeChangedSignal("LegStart"):Connect(function()
		readLeg(m)
	end)
	m.Destroying:Connect(function()
		legs[m] = nil
		tracks[m] = nil
	end)
end

local function wantedAnim(m: Model): (string?, boolean)
	local st = m:GetAttribute("State")
	if m:GetAttribute("Strike") then
		return nil, false
	end
	-- "moving" only while a leg is actually running: the feet stop the moment the Worker arrives
	if MOVING[st] and legs[m] then
		return "WorkerWalk", (m:GetAttribute("Carry") or 0) > 0
	elseif st == "Gathering" then
		return "WorkerWork", false
	elseif st == "Depositing" then
		return "WorkerPlace", false
	end
	return "WorkerIdle", false
end

local function stopTracks(cur: WorkerTracks)
	cur.track:Stop(0.2)
	if cur.carry then
		cur.carry:Stop(0.2)
	end
end

local function updateAnimation(m: Model, camPos: Vector3)
	local root = m.PrimaryPart
	local want, carrying = nil, false
	if root and (root.Position - camPos).Magnitude < ANIM_RANGE then
		want, carrying = wantedAnim(m)
	end
	local cur = tracks[m]
	if cur and cur.kind ~= want then
		stopTracks(cur)
		tracks[m] = nil
		cur = nil
	end
	if want and not cur then
		local t = TrainingAnimations.Play(m, want, true)
		if t then
			cur = { kind = want, track = t }
			tracks[m] = cur
		end
	end
	if not cur then
		return
	end
	-- carrying arms over the walk
	if carrying and not cur.carry then
		cur.carry = TrainingAnimations.Play(m, "WorkerCarry", true)
	elseif not carrying and cur.carry then
		cur.carry:Stop(0.2)
		cur.carry = nil
	end
	-- the walk cycle follows the real movement speed
	local leg = legs[m]
	if cur.kind == "WorkerWalk" and leg and leg.duration > 0 then
		local speed = (leg.to - leg.from).Magnitude / leg.duration
		cur.track:AdjustSpeed(math.clamp(speed / WALK_REF_SPEED, 0.5, 2))
	end
end

local function place(m: Model, cf: CFrame)
	-- moving the anchored root carries the whole welded rig (cheaper than PivotTo on every part)
	local root = m.PrimaryPart
	if root then
		root.CFrame = cf
	else
		m:PivotTo(cf)
	end
end

function WorkerVisualController.Start()
	local folder = workspace:WaitForChild("Workers")
	folder.ChildAdded:Connect(track)
	folder.ChildRemoved:Connect(function(m)
		legs[m :: Model] = nil
		tracks[m :: Model] = nil
	end)
	for _, m in folder:GetChildren() do
		track(m)
	end
	-- animation tracks are (re)evaluated a few times per second, not every frame
	task.spawn(function()
		while true do
			task.wait(0.25)
			local cam = workspace.CurrentCamera
			local camPos = if cam then cam.CFrame.Position else Vector3.zero
			for _, m in folder:GetChildren() do
				if m:IsA("Model") then
					updateAnimation(m, camPos)
				end
			end
		end
	end)
	-- Positions come from the leg time, so a skipped frame never drifts; distant or off-screen workers are
	-- simply moved less often.
	local frame = 0
	RunService.Heartbeat:Connect(function()
		if next(legs) == nil then
			return
		end
		frame += 1
		local now = workspace:GetServerTimeNow()
		local cam = workspace.CurrentCamera
		local camPos = if cam then cam.CFrame.Position else Vector3.zero
		local camLook = if cam then cam.CFrame.LookVector else Vector3.zAxis
		for m, leg in legs do
			if m.Parent then
				local alpha = math.clamp((now - leg.start) / leg.duration, 0, 1)
				local pos = leg.from:Lerp(leg.to, alpha)
				local off = pos - camPos
				local dist = off.Magnitude
				local step = if dist < 160 then 1 elseif dist < 400 then 3 else 8
				if step < 6 and dist > 60 and off:Dot(camLook) < 0 then
					step = 6 -- behind the camera
				end
				if alpha >= 1 or frame % step == 0 then
					local dir = leg.to - leg.from
					if alpha < 1 then
						place(m, if dir.Magnitude > 0.1 then CFrame.lookAt(pos, pos + dir) else CFrame.new(pos))
					else
						place(m, if dir.Magnitude > 0.1 then CFrame.lookAt(leg.to, leg.to + dir) else CFrame.new(leg.to))
						legs[m] = nil -- arrived; server pivot is authoritative again
					end
				end
			end
		end
	end)
end

return WorkerVisualController
