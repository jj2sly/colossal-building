--!nonstrict
-- CLASSIC HOUSE show. Activation (~76%): the chimney starts smoking and the windows glow softly.
-- Completion: the front door swings open, the chimney puffs, every window lights up warm.
local Show = {}

local WARM = Color3.fromRGB(255, 204, 140)

local function windows(sess, lib, glow: number, range: number)
	for _, w in lib.group(sess.model, "Window") do
		if not w:GetAttribute("ShowLit") or (w:GetAttribute("ShowLit") :: number) < glow then
			w:SetAttribute("ShowLit", glow)
			lib.tween(w, 1.2, { Color = Color3.fromRGB(122, 156, 178):Lerp(WARM, glow) })
			local l = w:FindFirstChild("ShowLight") or lib.light(w, WARM, range, 0, sess.trash)
			l.Name = "ShowLight"
			l.Range = range
			lib.tween(l, 1.2, { Brightness = glow * 1.4 })
			if glow >= 1 then
				w.Material = Enum.Material.Neon
				w.Transparency = 0.35
			end
		end
	end
end

local function chimney(sess, lib): ParticleEmitter?
	local top = lib.find(sess.model, "ChimneyTop")
	if not top then
		return nil
	end
	local e = top:FindFirstChild("ShowSmoke") :: ParticleEmitter?
	if not e then
		e = lib.emitter(top, lib.SMOKE, Color3.fromRGB(196, 192, 188), 5, 6, 4, sess.trash)
		e.Name = "ShowSmoke"
		e.Acceleration = Vector3.new(1.5, 1.2, 0)
		e.Rate = 3
	end
	return e
end

function Show.Activate(sess, lib)
	-- the roof (and its chimney) may still be appearing: keep looking until the smoke and every window are up
	while sess.alive() do
		chimney(sess, lib)
		windows(sess, lib, 0.45, 18)
		task.wait(1)
	end
end

function Show.Spectacle(ctx, sess, lib)
	local model = ctx.model
	local s = sess or { model = model, trash = ctx.trash }
	-- the door: rotate the Door group about its hinge marker by ~105 degrees, outward
	local hinge = lib.find(model, "DoorHinge")
	local door = lib.group(model, "Door")
	lib.Sound.Play("Chime")
	if hinge then
		local h = hinge.CFrame
		local orig = {}
		for _, p in door do
			orig[p] = h:ToObjectSpace(p.CFrame)
		end
		local t0 = os.clock()
		while os.clock() - t0 < 1.3 and ctx.alive() do
			local k = math.clamp((os.clock() - t0) / 1.3, 0, 1)
			k = 1 - (1 - k) ^ 3
			local rot = h * CFrame.Angles(0, math.rad(105) * k, 0)
			for p, rel in orig do
				p.CFrame = rot * rel
			end
			task.wait()
		end
	end
	-- chimney puff + every window fully lit
	local e = chimney(s, lib)
	if e then
		e.Rate = 6
		e:Emit(30)
	end
	windows(s, lib, 1, 26)
	lib.Sound.Play("Cheer")
	lib.Cine.ring(model:GetPivot().Position + Vector3.new(0, 0.5, 0), WARM, 110, 1.6)
	task.wait(2.5)
end

return Show
