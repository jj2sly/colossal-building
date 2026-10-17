--!nonstrict
-- PIRATE SHIP show. Activation (~53%): the stern lanterns light and every sail breathes in the wind (sails added later
-- join in as they appear). Completion: a rolling port broadside, bow to stern: muzzle flash, recoil and a restrained
-- puff of smoke per gun and a light camera kick.
local Show = {}

local LANTERN = Color3.fromRGB(255, 186, 96)

local function lanterns(sess, lib, bright: number)
	for _, l in lib.group(sess.model, "Lantern") do
		if (l:GetAttribute("ShowLit") or 0) < bright then
			l:SetAttribute("ShowLit", bright)
			lib.tween(l, 1, { Color = Color3.fromRGB(110, 72, 34):Lerp(LANTERN, bright) })
			local pl = l:FindFirstChild("ShowLight") or lib.light(l, LANTERN, 18, 0, sess.trash)
			pl.Name = "ShowLight"
			lib.tween(pl, 1, { Brightness = bright * 1.2 })
		end
	end
end

-- each sail swings a little about its top edge (the yard), with its own phase
local function sails(sess, lib, t: number, amp: number)
	for _, p in lib.group(sess.model, "Sail") do
		local b = sess:base(p)
		if b then
			local phase = (b.Position.X + b.Position.Z) * 0.13
			local a = math.sin(t * 1.1 + phase) * amp
			local top = b * CFrame.new(0, p.Size.Y / 2, 0)
			-- swing about the sail's long horizontal edge
			local rot = if p.Size.X > p.Size.Z then CFrame.Angles(a, 0, 0) else CFrame.Angles(0, 0, a)
			p.CFrame = top * rot * top:Inverse() * b
		end
	end
end

function Show.Activate(sess, lib)
	sess:step(function(_, t)
		sails(sess, lib, t, math.rad(2.5))
	end)
	while sess.alive() do
		lanterns(sess, lib, 0.8)
		task.wait(1)
	end
end

function Show.Spectacle(ctx, sess, lib)
	local m = ctx.model
	local s = sess or { model = m, trash = ctx.trash }
	lanterns(s, lib, 1)
	-- the port guns (the side that faces the spawn), bow to stern
	local guns = {}
	for _, g in m:GetDescendants() do
		if g:IsA("Model") and g.Name == "Cannon" and g:GetAttribute("Side") == "Port" then
			table.insert(guns, g)
		end
	end
	table.sort(guns, function(a, b)
		return (a:GetAttribute("Order") or 0) < (b:GetAttribute("Order") or 0)
	end)
	lib.Sound.Play("ChimeLow")
	task.wait(0.4)
	local t0 = os.clock()
	if sess then
		sess.paused = false -- the sails keep breathing during the broadside
	end
	for _, g in guns do
		if not ctx.alive() then
			return
		end
		local muzzle = g:FindFirstChild("Muzzle")
		if muzzle then
			local out = muzzle.CFrame.LookVector
			local pos = muzzle.Position
			-- flash
			local f = Instance.new("Part")
			f.Anchored, f.CanCollide, f.CanQuery, f.CanTouch = true, false, false, false
			f.Shape = Enum.PartType.Ball
			f.Material = Enum.Material.Neon
			f.Color = Color3.fromRGB(255, 196, 110)
			f.Size = Vector3.one * 3
			f.Position = pos + out * 1.5
			f.Parent = workspace
			table.insert(ctx.trash, f)
			lib.tween(f, 0.35, { Size = Vector3.one * 9, Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			-- restrained smoke
			local a = lib.anchor(pos + out * 3, ctx.trash)
			local e = lib.emitter(a, lib.SMOKE, Color3.fromRGB(200, 198, 196), 6, 3.5, 6, ctx.trash)
			e.EmissionDirection = Enum.NormalId.Front
			e.Acceleration = Vector3.new(0, 1.5, 0)
			a.CFrame = CFrame.lookAt(a.Position, a.Position + out)
			e:Emit(10)
			-- recoil: the gun jumps back and rolls out again
			for _, p in g:GetDescendants() do
				if p:IsA("BasePart") and not p:GetAttribute("Marker") then
					local b = p.CFrame
					p.CFrame = b - out * 2.4
					lib.tween(p, 0.7, { CFrame = b }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				end
			end
			lib.Sound.Play("Boom", 0.15)
			lib.Cine.shake(0.15, 0.2)
		end
		task.wait(0.55)
	end
	lib.Sound.Play("Cheer")
	local left = ctx.duration - (os.clock() - t0) - 0.6
	if left > 0 then
		task.wait(left)
	end
end

return Show
