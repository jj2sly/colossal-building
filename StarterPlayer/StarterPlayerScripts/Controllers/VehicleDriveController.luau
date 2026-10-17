--!strict
-- Arcade driving for the vehicle you sit in. Roblox fills VehicleSeat.ThrottleFloat / SteerFloat for keyboard (WASD / arrows),
-- gamepad (left stick) and touch (thumbstick) automatically, so this one path covers every input device.
-- The server built the vehicle (VehicleService); the seat's owner simulates it, so this just feeds the two constraints on
-- the Root part: a horizontal LinearVelocity (forward speed; gravity stays free) and an upright AlignOrientation (heading).
-- GROUND FOLLOWING (Pass 20A): each frame four rays under the chassis corners give a ground plane; the AlignOrientation target is the
-- heading tilted onto that plane (smoothed, tilt clamped, side slope blended down), so the hull lies on the slope and the whole model
-- (wheels, seat, driver, cargo are welded to it) pitches and rolls with the terrain instead of staying level and floating. A short
-- forward ray stops the vehicle climbing steep walls / cliffs (anything steeper than MAX_SLOPE). Controls and speeds are unchanged.
-- Jump (Space / A button / mobile jump) steps out. Per-vehicle Accel / Brake / Turn and the reverse factor are seat attributes.
-- One Heartbeat loop polls the humanoid's current seat every frame, so respawns, replaced vehicles and destroyed seats
-- can never leave the controller holding a stale reference.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VehicleDriveController = {}

local player = Players.LocalPlayer

local MAX_TILT = math.rad(32) -- never lean the chassis further than this
local ROLL_BLEND = 0.8 -- side slopes roll the chassis (a little less than the ground, so it never looks tipped)
local MAX_SLOPE = math.rad(48) -- ground that rises faster than this (over 8 studs) stops the vehicle
local MAX_WALL = math.rad(72) -- a face steeper than this straight ahead stops the vehicle
local STEP_MAX = 1.3 -- (Pass 21O) a ledge / curb / bump up to this high is climbed instead of stopping the flat-bottomed hull
local STEP_LIFT = 13 -- vertical velocity given while a step is ahead (the Drive constraint carries no vertical force)
local FOLLOW_RATE = 7 -- how fast the chassis settles onto a new ground plane (1/s)
local MAX_TILT_RATE = math.rad(100) -- the ground plane may swing at most this fast (deg/s): no violent snaps over terrain steps

local currentSeat: VehicleSeat? = nil
local groundN = Vector3.yAxis
local hullHalf = Vector2.new(2.4, 5) -- half width / half length of the hull and its z offset
local hullZ = 0
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local yaw = 0
local speed = 0 -- signed forward speed along the heading

local function currentDrivingSeat(): VehicleSeat?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if seat and seat:IsA("VehicleSeat") and seat:GetAttribute("MBVehicle") and seat.Parent and seat.Occupant == hum then
		return seat
	end
	return nil
end

local function step(dt: number)
	local seat = currentDrivingSeat()
	if seat ~= currentSeat then
		currentSeat = seat
		speed = 0
		groundN = Vector3.yAxis
		if seat and seat.Parent and (seat.Parent :: Model).PrimaryPart then
			local _, y = ((seat.Parent :: Model).PrimaryPart :: BasePart).CFrame:ToOrientation()
			yaw = y
			local hull = (seat.Parent :: Model):FindFirstChild("Hull") :: BasePart?
			if hull then
				hullHalf = Vector2.new(hull.Size.X / 2, hull.Size.Z / 2)
				hullZ = (seat.Parent :: Model).PrimaryPart.CFrame:PointToObjectSpace(hull.Position).Z
			end
			rayParams.FilterDescendantsInstances = { seat.Parent :: Instance, player.Character :: Instance }
		end
	end
	if not seat then
		return
	end
	local root = (seat.Parent :: Model).PrimaryPart
	local driveV = root and root:FindFirstChild("Drive") :: LinearVelocity?
	local upright = root and root:FindFirstChild("Upright") :: AlignOrientation?
	if not root or not driveV or not upright then
		return
	end
	local maxSpeed: number = seat:GetAttribute("MaxSpeed") or 20
	local accel: number = seat:GetAttribute("Accel") or 30
	local brake: number = seat:GetAttribute("Brake") or 55
	local turn: number = seat:GetAttribute("Turn") or 2.5
	local revFactor: number = seat:GetAttribute("Reverse") or 0.4
	local throttle = seat.ThrottleFloat
	local steer = seat.SteerFloat
	if math.abs(throttle) > 0.05 then
		local target = if throttle > 0 then maxSpeed * throttle else maxSpeed * revFactor * throttle
		local rate = if (throttle > 0) == (speed >= 0) or math.abs(speed) < 0.5 then accel else brake
		speed = if speed < target then math.min(target, speed + rate * dt) else math.max(target, speed - rate * dt)
	else
		-- coast to a stop
		local rate = brake * 0.5 * dt
		speed = if math.abs(speed) <= rate then 0 else speed - math.sign(speed) * rate
	end
	-- steering scales up with speed but still works at a crawl; reversing mirrors like a real car
	local grip = math.clamp(math.abs(speed) / (maxSpeed * 0.35), 0.3, 1)
	yaw -= steer * turn * grip * math.sign(if speed == 0 then 1 else speed) * dt
	local heading = CFrame.Angles(0, yaw, 0)
	local fwd, rgt = -heading.ZVector, heading.XVector
	local pos = root.Position
	-- ground plane from four corner rays (a missing hit leaves the plane flat)
	local hits, n = {}, 0
	local groundLow = math.huge
	-- corners: 1 front-left, 2 front-right, 3 back-left, 4 back-right (x: right = +1, y: back = +1)
	for i, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local origin = pos + rgt * (c[1] * hullHalf.X * 0.9) + fwd * (-hullZ - c[2] * hullHalf.Y * 0.85) + Vector3.new(0, 8, 0) -- start well above the ground so a corner on rising terrain never starts inside it
		local hit = workspace:Raycast(origin, Vector3.new(0, -20, 0), rayParams)
		-- a hit far above the chassis is a cliff top / overhang, far below is a drop: neither is "the ground under the hull"
		if hit and hit.Position.Y < pos.Y + 5.5 and hit.Position.Y > pos.Y - 9 then
			hits[i] = hit.Position
			n += 1
			groundLow = math.min(groundLow, hit.Position.Y)
		end
	end
	local target = Vector3.yAxis
	if n >= 3 then
		local nrm
		if n == 4 then
			nrm = (hits[2] - hits[3]):Cross(hits[1] - hits[4])
		else
			local p: { Vector3 } = {}
			for i = 1, 4 do
				if hits[i] then
					table.insert(p, hits[i])
				end
			end
			nrm = (p[2] - p[1]):Cross(p[3] - p[1])
		end
		if nrm.Magnitude > 1e-3 then
			target = nrm.Unit
			if target.Y < 0 then
				target = -target
			end
		end
	end
	-- blend the lateral lean down (modest roll), clamp the tilt, then ease onto the new plane
	local a, b, c = target:Dot(fwd), target:Dot(rgt), target.Y
	target = (fwd * a + rgt * b * ROLL_BLEND + Vector3.yAxis * c).Unit
	local tilt = math.acos(math.clamp(target.Y, -1, 1))
	if tilt > MAX_TILT then
		target = Vector3.yAxis:Lerp(target, MAX_TILT / tilt).Unit
	end
	local want = groundN:Lerp(target, math.min(1, dt * FOLLOW_RATE)).Unit
	local swing = math.acos(math.clamp(groundN:Dot(want), -1, 1))
	if swing > MAX_TILT_RATE * dt then
		want = groundN:Lerp(want, MAX_TILT_RATE * dt / swing).Unit
	end
	groundN = want
	local look = (fwd - groundN * fwd:Dot(groundN)).Unit
	upright.CFrame = CFrame.fromMatrix(Vector3.zero, look:Cross(groundN), groundN, -look)
	-- no wall-climbing: a (near-)vertical face straight ahead, or ground that rises faster than MAX_SLOPE over the next few studs, stops the
	-- vehicle; ordinary hills (including the stepped voxel terrain) are fine
	if math.abs(speed) > 0.5 then
		local dir = fwd * math.sign(speed)
		local center = pos - fwd * hullZ
		local wall = workspace:Raycast(center + Vector3.new(0, 1.6, 0), dir * (hullHalf.Y + 7), rayParams)
		local blocked = wall ~= nil and wall.Instance.CanCollide and math.acos(math.clamp(wall.Normal.Y, -1, 1)) > MAX_WALL
		if not blocked then
			local front = center + dir * hullHalf.Y
			local h0 = workspace:Raycast(front + Vector3.new(0, 10, 0), Vector3.new(0, -30, 0), rayParams)
			local h1 = workspace:Raycast(front + dir * 8 + Vector3.new(0, 10, 0), Vector3.new(0, -30, 0), rayParams)
			if h0 and h1 and h1.Position.Y - h0.Position.Y > 8 * math.tan(MAX_SLOPE) then
				blocked = true
			end
		end
		if blocked then
			speed = 0
		end
	end
	-- STEP ASSIST: the invisible hull is a flat-bottomed box, so a curb, road shoulder, tile edge or small rock lip stopped it dead. A low
	-- forward ray finds a short vertical face; a probe from above measures its height; if it is climbable the hull gets a brief upward
	-- velocity so it rides up and over (anything taller still blocks, as before).
	if math.abs(speed) > 0.5 and groundLow < math.huge then
		local dir = fwd * math.sign(speed)
		local center = pos - fwd * hullZ
		-- (Pass 21T) three low rays across the nose (centre and both sides), starting only 0.06 above the lowest ground under the hull: the hull
		-- bottom sits ~0.05 off the ground, so a road-edge lip of 0.1 - 0.2 studs (lane edges, dashes, apron bypass, tile seams) used to pass
		-- UNDER the old 0.2 ray and still stop the hull dead. An off-centre lip is caught by the side rays.
		local stepH = 0
		for _, off in { 0, -hullHalf.X * 0.8, hullHalf.X * 0.8 } do
			local lowOrigin = Vector3.new(center.X, groundLow + 0.06, center.Z) + dir * (hullHalf.Y - 0.8) + rgt * off
			local low = workspace:Raycast(lowOrigin, dir * 2.6, rayParams)
			if low and low.Instance.CanCollide and low.Normal.Y < 0.5 then
				local probe = workspace:Raycast(low.Position + dir * 0.08 + Vector3.new(0, STEP_MAX + 1.5, 0), Vector3.new(0, -(STEP_MAX + 1.5), 0), rayParams)
				-- (probed just inside the face so even a 0.4-stud-thin curb still has its top under the probe)
				-- no top within reach (> STEP_MAX) = a real wall, left to the wall rule
				if probe then
					local h = probe.Position.Y - groundLow
					if h > 0.02 and h <= STEP_MAX then
						stepH = math.max(stepH, h)
					end
				end
			end
		end
		if stepH > 0 then
			-- just enough upward speed to clear this lip (+ a little margin), never the full hop for a tiny edge
			local lift = math.clamp(math.sqrt(2 * workspace.Gravity * (stepH + 0.15)), 4, STEP_LIFT)
			local v = root.AssemblyLinearVelocity
			if v.Y < lift then
				root.AssemblyLinearVelocity = Vector3.new(v.X, lift, v.Z)
			end
		end
	end
	driveV.VectorVelocity = -heading.ZVector * speed
end

function VehicleDriveController.Start()
	RunService.Heartbeat:Connect(step)
end

return VehicleDriveController
