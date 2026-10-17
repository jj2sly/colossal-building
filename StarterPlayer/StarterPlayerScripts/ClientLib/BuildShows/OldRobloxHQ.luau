--!nonstrict
-- OLD ROBLOX HQ show. Activation (~65%): the windows begin to light up (a soft warm glow) and the flag, still furled at
-- the foot of the pole's top, flutters. Completion: the flag deploys to its full size on the mast (unfurls with a wave) and every
-- window fully lights up warm (bright, neon), with a fanfare and a gold ring.
local Show = {}

local WARM = Color3.fromRGB(255, 204, 140)

local function windows(sess, lib, glow: number, range: number)
	for _, w in lib.group(sess.model, "Window") do
		if not w:GetAttribute("ShowLit") or (w:GetAttribute("ShowLit") :: number) < glow then
			w:SetAttribute("ShowLit", glow)
			lib.tween(w, 1.2, { Color = Color3.fromRGB(116, 150, 176):Lerp(WARM, glow) })
			local l = w:FindFirstChild("ShowLight") or lib.light(w, WARM, range, 0, sess.trash)
			l.Name = "ShowLight"
			l.Range = range
			lib.tween(l, 1.2, { Brightness = glow * 1.4 })
			if glow >= 1 then
				w.Material = Enum.Material.Neon
				w.Transparency = 0.3
			end
		end
	end
end

-- the flag is scaled along the mast's +x side about the pole (s = 0.3 furled .. 1 full) and waves about the pole axis
local function flag(sess, lib, s: number, t: number, wave: number)
	local m = sess.model
	local pole = lib.find(m, "FlagPole")
	local pb = pole and sess:base(pole)
	if not pb then
		return
	end
	local P = m:GetPivot()
	local up = P.UpVector
	local xW = P:VectorToWorldSpace(Vector3.xAxis)
	for i, p in lib.group(m, "Flag") do
		local b = sess:base(p)
		if b then
			p:SetAttribute("W0", p:GetAttribute("W0") or p.Size.X)
			local w0 = p:GetAttribute("W0")
			local rel = (b.Position - pb.Position):Dot(xW) -- offset of the part centre along the pole's +x
			local edge = rel - w0 / 2 -- where its pole-side edge starts
			p.Size = Vector3.new(w0 * s, p.Size.Y, p.Size.Z)
			local newCenter = edge * s + w0 * s / 2
			local flat = b - xW * rel + xW * newCenter
			-- a ripple: the free end swings in/out of the plane about the pole (yaw)
			local yaw = math.sin(t * 3.2 + i * 0.3) * math.rad(wave)
			local axisP = CFrame.new(pb.Position) * CFrame.fromAxisAngle(up, yaw) * CFrame.new(-pb.Position)
			p.CFrame = axisP * flat
		end
	end
end

function Show.Activate(sess, lib)
	sess.flagS = 0.3
	sess:step(function(_, t)
		flag(sess, lib, sess.flagS, t, 7)
	end)
	while sess.alive() do
		windows(sess, lib, 0.45, 20)
		task.wait(1)
	end
end

function Show.Spectacle(ctx, sess, lib)
	if not sess then
		return
	end
	local m = ctx.model
	lib.Sound.Play("Chime")
	-- the flag deploys (unfurls over ~1.8 s) while the windows light up fully
	local t0 = os.clock()
	local lit = false
	while os.clock() - t0 < 1.8 and ctx.alive() do
		local k = (os.clock() - t0) / 1.8
		local e = k * k * (3 - 2 * k)
		flag(sess, lib, 0.3 + 0.7 * e, os.clock(), 7 + 14 * (1 - e))
		if not lit and k > 0.35 then
			lit = true
			windows(sess, lib, 1, 30)
			lib.Cine.ring(m:GetPivot().Position + Vector3.new(0, 0.5, 0), WARM, 140, 1.6)
		end
		task.wait()
	end
	sess.flagS = 1
	lib.Sound.Play("Cheer")
	local pole = lib.find(m, "FlagPole")
	if pole then
		local a = lib.anchor(pole.Position + Vector3.new(0, 4, 0), ctx.trash)
		local e = lib.emitter(a, lib.SPARK, Color3.fromRGB(255, 226, 120), 2.6, 2, 26, ctx.trash)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0, -12, 0)
		e:Emit(80)
	end
	lib.Cine.shake(0.12, 0.3)
	sess.paused = false -- the full flag keeps waving
	task.wait(math.max(0.5, ctx.duration - 2.6))
end

return Show
