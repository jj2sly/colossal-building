--!nonstrict
-- LEANING TOWER OF PISA show. Activation (~55%, once the bell chamber is up): the three bells begin a subtle sway about their yokes.
-- Completion: the bells swing hard and ring (chimes, a soft ring over the tower), and a small flock of white birds spirals up and
-- circles the crown for the rest of the show, then fades off.
local Show = {}

local function sway(sess, lib, t: number, amp: number)
	local P = sess.model:GetPivot()
	local zW = P:VectorToWorldSpace(Vector3.zAxis)
	for _, g in sess.model:GetDescendants() do
		if g:IsA("Model") and g.Name == "Bell" then
			local top = g:FindFirstChild("BellTop")
			local tb = top and sess:base(top)
			if tb then
				local phase = tb.Position.X * 0.31
				local a = math.sin(t * 1.5 + phase) * amp
				local rot = CFrame.new(tb.Position) * CFrame.fromAxisAngle(zW, a) * CFrame.new(-tb.Position)
				for _, p in g:GetDescendants() do
					if p:IsA("BasePart") then
						local b = sess:base(p)
						if b then
							p.CFrame = rot * b
						end
					end
				end
			end
		end
	end
end

function Show.Activate(sess, lib)
	sess:step(function(_, t)
		sway(sess, lib, t, math.rad(3.5))
	end)
end

function Show.Spectacle(ctx, sess, lib)
	if not sess then
		return
	end
	local m = ctx.model
	local crown = lib.find(m, "CrownTop")
	local center = if crown then crown.Position else m:GetPivot().Position + Vector3.new(0, 100, 0)
	local birds = {}
	for i = 1, 14 do
		local b = Instance.new("Part")
		b.Name = "MB_Bird"
		b.Anchored, b.CanCollide, b.CanQuery, b.CanTouch = true, false, false, false
		b.Material = Enum.Material.SmoothPlastic
		b.Color = Color3.fromRGB(246, 246, 250)
		b.Size = Vector3.new(4.4, 0.6, 1.6)
		b.Transparency = 1
		b.Parent = workspace
		table.insert(ctx.trash, b)
		birds[i] = { part = b, phase = i / 14 * math.pi * 2, lift = (i % 5) * 2.2, speed = 0.9 + (i % 4) * 0.08 }
	end
	lib.Sound.Play("ChimeLow")
	lib.Cine.shake(0.15, 0.5)
	sess.paused = false
	local DUR = math.max(3, ctx.duration - 0.2)
	local t0 = os.clock()
	local rang = 0
	while os.clock() - t0 < DUR and ctx.alive() do
		local t = os.clock() - t0
		local amp = math.rad(3.5 + 15 * math.sin(math.clamp(t / 2.4, 0, 1) * math.pi * 0.5))
		if t > 3.4 then
			amp *= math.max(0.25, 1 - (t - 3.4) / 2)
		end
		sway(sess, lib, os.clock(), amp)
		if t > rang * 0.8 and rang < 5 then
			rang += 1
			lib.Sound.Play("Chime")
		end
		for _, bd in birds do
			local k = math.clamp((t - 0.4) / 1.2, 0, 1)
			local ang = bd.phase + t * bd.speed * 2.2
			local r = 14 + 24 * math.clamp(t / DUR, 0, 1) + (bd.lift % 3)
			local pos = center + Vector3.new(math.cos(ang) * r, 4 + bd.lift + t * 3.2 + math.sin(t * 2 + bd.phase) * 1.4, math.sin(ang) * r)
			local tang = Vector3.new(-math.sin(ang), 0.15, math.cos(ang))
			local flap = math.sin(t * 14 + bd.phase * 3) * math.rad(28)
			bd.part.CFrame = CFrame.lookAt(pos, pos + tang) * CFrame.Angles(0, 0, flap) * CFrame.Angles(0, math.rad(90), 0)
			bd.part.Transparency = math.clamp(1 - k + math.clamp((t - (DUR - 1)) / 1, 0, 1), 0, 1)
		end
		task.wait()
	end
	lib.Cine.ring(m:GetPivot().Position + Vector3.new(0, 0.5, 0), Color3.fromRGB(240, 226, 170), 120, 1.4)
	lib.Sound.Play("Cheer")
end

return Show
