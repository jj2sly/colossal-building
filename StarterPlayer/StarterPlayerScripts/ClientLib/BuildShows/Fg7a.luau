--!nonstrict
-- FORGOTTEN F1 show (module name = the opaque build key; nothing here names the structure). A colossal angled orbital cannon.
-- Activation (~25%, rotator stage built): the rotator drum turns slowly.
-- Milestone 1 (~60%, Ring I built): the first barrel ring starts to turn.
-- Milestone 2 (~69%, Ring II built): the second ring counter-rotates and the chamber core wakes.
-- Milestone 3 (~84%, power banks + spine built): banks glow and a slow charge breathes in the chamber.
-- Milestone 4 (~93%, conduits built): charge pulses run up the barrel conduits; the cannon is partially alive.
-- Completion (~16 s): the chamber wakes, the rings accelerate and the cannon elevates a little; energy travels up the barrel;
-- one harmless discharge into the sky; heavy recoil and settle; a restrained residual glow remains.
local Show = {}
Show.SpectacleId = "Fg7aShow"

local GLOW0 = Color3.fromRGB(52, 78, 96)
local CYAN = Color3.fromRGB(120, 215, 255)
local WHITE = Color3.fromRGB(230, 248, 255)
local D = Vector3.new(-0.766, 0.643, 0).Unit -- barrel direction (template space)
local Y, Z = Vector3.yAxis, Vector3.zAxis
local ELEV = { "BarrelLow", "BarrelUp", "Ring1", "Ring2", "Spine", "Conduit", "Crown", "Chamber", "Core" }

local function glow(p: BasePart, k: number)
	p.Color = GLOW0:Lerp(CYAN, math.clamp(k, 0, 1)):Lerp(WHITE, math.clamp(k - 1, 0, 1))
	p.Material = if k > 0.3 then Enum.Material.Neon else Enum.Material.SmoothPlastic
end

-- sess.rot, sess.s1, sess.s2 = angles; sess.lv1/lv2 = ring speed levels; sess.charge 0..1; sess.elev (rad); sess.recoil (studs)
local function pose(sess, lib)
	local m = sess.model
	local R = m:GetPivot().Rotation
	local pv = lib.find(m, "PivC")
	local pb = pv and sess:base(pv)
	local pre = CFrame.identity
	if pb and (sess.elev or 0) ~= 0 then
		pre = CFrame.new(pb.Position) * CFrame.fromAxisAngle(R * Z, -sess.elev) * CFrame.new(-pb.Position)
	end
	lib.spin(sess, "Rotator", "RotC", Y, sess.rot or 0)
	local recoil = CFrame.new(R * D * -(sess.recoil or 0))
	for _, g in ELEV do
		if g == "Ring1" then
			lib.spin(sess, g, "Ring1C", D, sess.s1 or 0, recoil * pre)
		elseif g == "Ring2" then
			lib.spin(sess, g, "Ring2C", D, sess.s2 or 0, recoil * pre)
		elseif g == "BarrelUp" or g == "Crown" or g == "Spine" or g == "Conduit" then
			lib.spin(sess, g, nil, nil, 0, recoil * pre)
		else
			lib.spin(sess, g, nil, nil, 0, pre)
		end
	end
end

local function charge(sess, lib, t: number, level: number, pulse: number)
	for _, p in lib.groupOf(sess, "Conduit") do
		local o = p:GetAttribute("Order") or 1
		local wave = 0.5 + 0.5 * math.sin(t * 5 - o * 0.9)
		glow(p, level * 0.35 + pulse * wave * 1.1)
	end
	for _, p in lib.groupOf(sess, "Core") do
		glow(p, 0.35 + level * 0.5 + pulse * 0.4 + 0.12 * math.sin(t * 2))
	end
	for _, p in lib.groupOf(sess, "BankGlow") do
		glow(p, 0.25 + level * 0.6 + 0.15 * math.sin(t * 1.7))
	end
end

function Show.Activate(sess, lib)
	sess.rot, sess.s1, sess.s2 = 0, 0, 0
	sess.lv1, sess.lv2, sess.level, sess.pulse = 0, 0, 0, 0
	sess.elev, sess.recoil = 0, 0
	lib.Sound.Play("Rumble")
	sess:step(function(dt, t)
		sess.rot += dt * 0.12
		sess.s1 += dt * 0.45 * sess.lv1
		sess.s2 -= dt * 0.62 * sess.lv2
		pose(sess, lib)
		if sess.lv2 > 0 or sess.level > 0 then
			charge(sess, lib, t, sess.level, sess.pulse)
		end
	end)
end

local function ramp(sess, key: string, to: number, secs: number)
	local from = sess[key] or 0
	local t0 = os.clock()
	while sess.alive() and os.clock() - t0 < secs do
		sess[key] = from + (to - from) * ((os.clock() - t0) / secs)
		task.wait()
	end
	sess[key] = to
end

function Show.Milestone(sess, lib, n)
	if n == 1 then
		lib.Sound.Play("Rumble")
		ramp(sess, "lv1", 1, 3)
	elseif n == 2 then
		lib.Sound.Play("PowerUp")
		ramp(sess, "lv2", 1, 3)
		ramp(sess, "level", 0.3, 2)
	elseif n == 3 then
		lib.Sound.Play("PowerUp")
		ramp(sess, "level", 0.7, 3)
		ramp(sess, "lv1", 1.4, 3)
	else
		lib.Sound.Play("Zap")
		ramp(sess, "pulse", 0.6, 2.5)
	end
end

function Show.Spectacle(ctx, sess, lib)
	if not sess then
		return
	end
	local m = ctx.model
	local R = m:GetPivot().Rotation
	local last = os.clock()
	local T = 0
	local function run(seconds: number, fn)
		local t0 = os.clock()
		while os.clock() - t0 < seconds and ctx.alive() do
			local now = os.clock()
			local dt = math.min(now - last, 0.05)
			T += dt
			fn((now - t0) / seconds, dt)
			pose(sess, lib)
			last = now
			task.wait()
		end
		fn(1, 0)
		pose(sess, lib)
	end
	local function ease(k: number): number
		return k * k * (3 - 2 * k)
	end
	local lv1, lv2 = sess.lv1 or 1, sess.lv2 or 1
	local function spin(dt: number, mul: number)
		sess.rot += dt * 0.12
		sess.s1 += dt * 0.45 * lv1 * mul
		sess.s2 -= dt * 0.62 * lv2 * mul
	end
	-- 1. the chamber wakes (2.5 s)
	lib.Sound.Play("PowerUp")
	lib.Sound.Play("Rumble")
	run(2.5, function(k, dt)
		spin(dt, 1 + 2 * k)
		charge(sess, lib, T, 0.7 + 0.3 * k, 0.5 * k)
	end)
	-- 2. rings accelerate and the cannon elevates a little (2.5 s)
	lib.Cine.shake(0.15, 1)
	run(2.5, function(k, dt)
		spin(dt, 3 + 3 * k)
		sess.elev = math.rad(5) * ease(k)
		charge(sess, lib, T, 1, 0.7 + 0.3 * k)
	end)
	-- 3. energy travels up the barrel (3 s): a bright head runs the conduit Order
	lib.Sound.Play("Zap")
	run(3, function(k, dt)
		spin(dt, 6)
		for _, p in lib.groupOf(sess, "Conduit") do
			local o = p:GetAttribute("Order") or 1
			local d = math.abs(o - 1 - k * 9)
			glow(p, 0.4 + 1.4 * math.exp(-(d / 1.3) ^ 2))
		end
		for _, p in lib.groupOf(sess, "Core") do
			glow(p, 1.1 + 0.4 * k)
		end
		for _, p in lib.groupOf(sess, "Spine") do
			p.Color = p.Color:Lerp(CYAN, 0.02)
		end
	end)
	-- 4. one harmless sky discharge (1.2 s) from the muzzle along the barrel
	local mz = lib.find(m, "MuzzleC")
	local mb = mz and sess:base(mz)
	local pre = CFrame.identity
	local pv = lib.find(m, "PivC")
	local pb = pv and sess:base(pv)
	if pb then
		pre = CFrame.new(pb.Position) * CFrame.fromAxisAngle(R * Z, -(sess.elev or 0)) * CFrame.new(-pb.Position)
	end
	local origin = if mb then (pre * mb).Position else m:GetPivot().Position + Vector3.new(0, 150, 0)
	local dir = pre:VectorToWorldSpace(R * D)
	lib.Sound.Play("Boom")
	lib.Sound.Play("Meteor")
	lib.Cine.shake(0.55, 1.2)
	lib.Cine.bloom(0.5, 0.2, 2.5, 1.5)
	lib.Cine.ring(origin, WHITE, 120, 1.2)
	local len = 700
	local beam = Instance.new("Part")
	beam.Name = "MB_Discharge"
	beam.Anchored, beam.CanCollide, beam.CanQuery, beam.CanTouch, beam.CastShadow = true, false, false, false, false
	beam.Shape = Enum.PartType.Cylinder
	beam.Material = Enum.Material.Neon
	beam.Color = WHITE
	beam.Size = Vector3.new(len, 4, 4)
	beam.CFrame = CFrame.lookAt(origin + dir * len / 2, origin + dir * len) * CFrame.Angles(0, math.rad(90), 0)
	beam.Parent = workspace
	table.insert(ctx.trash, beam)
	local la = lib.anchor(origin, ctx.trash)
	local fl = lib.light(la, CYAN, 120, 0, ctx.trash)
	run(1.2, function(k, dt)
		spin(dt, 6)
		local w = 4 + 16 * math.sin(math.min(k * 3, 1) * math.pi / 2) * (1 - k)
		beam.Size = Vector3.new(len, w, w)
		beam.Transparency = k * k
		fl.Brightness = 10 * (1 - k)
		for _, p in lib.groupOf(sess, "Conduit") do
			glow(p, 1.6 * (1 - k) + 0.5)
		end
	end)
	beam:Destroy()
	-- 5. heavy recoil and settle (3 s): the barrel slides back, the cannon drops, rings spin down
	lib.Sound.Play("Thud")
	lib.Cine.shake(0.3, 0.8)
	local e0 = sess.elev
	run(3, function(k, dt)
		local kick = if k < 0.12 then k / 0.12 else math.exp(-(k - 0.12) * 4)
		sess.recoil = 9 * kick
		sess.elev = e0 * (1 - ease(math.clamp(k * 1.3, 0, 1)))
		spin(dt, 6 * (1 - ease(k)) + 1)
		charge(sess, lib, T, 1 - 0.5 * k, 0.3 * (1 - k))
	end)
	sess.recoil, sess.elev = 0, 0
	-- 6. restrained residual glow (3.8 s): charge fades to a quiet hum
	lib.Sound.Play("Cheer")
	run(3.8, function(k, dt)
		spin(dt, 1)
		charge(sess, lib, T, 0.5 - 0.15 * k, 0)
	end)
	sess.level, sess.pulse = 0.35, 0.3
	sess.paused = false
end

return Show
