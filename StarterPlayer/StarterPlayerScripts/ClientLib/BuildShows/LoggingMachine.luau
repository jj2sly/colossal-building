--!nonstrict
-- LOGGING MACHINE show. Activation (~65%): the two-part boom rocks gently and the grapple hangs and swings with it.
-- Completion: the grapple opens and lowers over the loose log, closes on it, lifts, the boom slews 35 degrees toward the spawn,
-- the log is lowered onto the pile and released: one huge log stacked, with a thud, dust and a ring.
-- Everything is composed from each part's original CFrame. Kinematics: boom about Pivot (local Z axis), forearm about Elbow,
-- the grapple (cable, hub, tongs, log) hangs from the wrist (never rotates with the boom, only moves with it), slew about the
-- model's up axis through Slew.
local Show = {}

local ARM = { "Boom", "Arm2" }
local HANG = { "Cable", "Claw", "TongL", "TongR", "HeroLog" }

-- s = { a = boom angle, b = elbow angle, d = grapple drop (studs), c = tong close (rad), psi = slew, grab = log carried }
local function pose(sess, lib, s)
	local m = sess.model
	local P = m:GetPivot()
	local up = P.UpVector
	local zW = P:VectorToWorldSpace(Vector3.zAxis)
	local function pos(name: string): Vector3?
		local mk = lib.find(m, name)
		local b = mk and sess:base(mk)
		return b and b.Position
	end
	local P0, E, H0, SL = pos("Pivot"), pos("Elbow"), pos("Hub"), pos("Slew")
	if not (P0 and E and H0 and SL) then
		return
	end
	local function rot(axis: Vector3, ang: number, c: Vector3): CFrame
		return CFrame.new(c) * CFrame.fromAxisAngle(axis, ang) * CFrame.new(-c)
	end
	local TP, TE, TS = rot(zW, s.a, P0), rot(zW, s.b, E), rot(up, s.psi, SL)
	local Wb = H0 + up * 8
	local delta = (TS * TP * TE):PointToWorldSpace(Wb) - Wb
	local Hn = H0 + delta - up * s.d
	local TY = rot(up, s.psi, Hn)
	for _, name in ARM do
		local T = if name == "Boom" then TS * TP else TS * TP * TE
		for _, p in lib.group(m, name) do
			local b = sess:base(p)
			if b then
				p.CFrame = T * b
			end
		end
	end
	for _, name in HANG do
		for _, p in lib.group(m, name) do
			local b = sess:base(p)
			if b then
				if name == "Cable" then
					local L0 = p:GetAttribute("L0") or p.Size.Y
					p:SetAttribute("L0", L0)
					p.Size = Vector3.new(p.Size.X, math.max(0.5, L0 + s.d), p.Size.Z)
					p.CFrame = b + delta - up * (s.d / 2)
				elseif name == "TongL" or name == "TongR" then
					local side = if name == "TongR" then 1 else -1
					p.CFrame = TY * (rot(zW, -side * s.c, H0) * b + delta - up * s.d)
				elseif name == "HeroLog" then
					sess.heroCF = sess.heroCF or {}
					if s.grab then
						sess.heroCF[p] = TY * (b + delta - up * (s.d - 6)) -- the log sits at its own spot while the grapple is at its grab height (d = 6)
					end
					if sess.heroCF[p] then
						p.CFrame = sess.heroCF[p]
					end
				else
					p.CFrame = TY * (b + delta - up * s.d)
				end
			end
		end
	end
end

function Show.Activate(sess, lib)
	sess:step(function(_, t)
		pose(sess, lib, { a = math.rad(1.2) * math.sin(t * 0.5), b = math.rad(2.6) * math.sin(t * 0.8 + 1), d = 0.6 * math.sin(t * 1.1), c = 0, psi = 0, grab = false })
	end)
end

local function ease(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

function Show.Spectacle(ctx, sess, lib)
	if not sess then
		return
	end
	local m = ctx.model
	local function run(seconds: number, fn)
		local t0 = os.clock()
		while os.clock() - t0 < seconds and ctx.alive() do
			fn((os.clock() - t0) / seconds)
			task.wait()
		end
		fn(1)
	end
	local PSI, CLOSE = math.rad(35), 0.5
	local function S(d: number, c: number, psi: number, grab: boolean)
		return { a = 0, b = 0, d = d, c = c, psi = psi, grab = grab }
	end
	lib.Sound.Play("Chime")
	run(0.8, function(k) pose(sess, lib, S(6 * ease(k), -0.15 * ease(k), 0, false)) end) -- open wide and lower over the log
	lib.Sound.Play("Thud")
	run(0.3, function(k) pose(sess, lib, S(6, -0.15 + (CLOSE + 0.15) * ease(k), 0, true)) end) -- close on it
	lib.Sound.Play("Rumble")
	run(0.7, function(k) pose(sess, lib, S(6 - 14 * ease(k), CLOSE, 0, true)) end) -- lift
	run(1.0, function(k) pose(sess, lib, S(-8, CLOSE, PSI * ease(k), true)) end) -- slew toward the pile
	run(0.6, function(k) pose(sess, lib, S(-8 + 6.2 * ease(k), CLOSE, PSI, true)) end) -- lower onto the pile (log centre y 12.4)
	local landing = lib.find(m, "Slew")
	run(0.3, function(k) pose(sess, lib, S(-1.8, CLOSE - (CLOSE + 0.15) * ease(k), PSI, false)) end) -- release
	local P = m:GetPivot()
	local pile = (landing and landing.Position or P.Position) + P:VectorToWorldSpace(Vector3.new(math.cos(PSI), 0, -math.sin(PSI))) * 46
	lib.Sound.Play("Boom")
	lib.Cine.shake(0.3, 0.4)
	lib.Cine.burst(pile, "Dust", 1.3)
	lib.Cine.ring(P.Position + Vector3.new(0, 0.5, 0), Color3.fromRGB(236, 150, 50), 110, 1.3)
	run(0.5, function(k) pose(sess, lib, S(-1.8 - 3 * ease(k), -0.15, PSI, false)) end) -- the grapple lifts clear
	lib.Sound.Play("Cheer")
	task.wait(0.4)
	sess.paused = false
end

return Show
