--!nonstrict
-- STONE ARCH BRIDGE show. Activation (~65%): the lanterns light up and the banners (once hung) flutter; now and then a little
-- stone dust trickles from under the deck as the masonry settles.
-- Completion: dust falls from under the deck and the arch, the lanterns flare, the banners wave hard, then everything calms.
local Show = {}

local LAMP = Color3.fromRGB(255, 186, 96)
local DUST = Color3.fromRGB(176, 170, 156)

local function lanterns(sess, lib, bright: number)
	for _, l in lib.group(sess.model, "Lantern") do
		if (l:GetAttribute("ShowLit") or 0) < bright then
			l:SetAttribute("ShowLit", bright)
			lib.tween(l, 1, { Color = Color3.fromRGB(110, 72, 34):Lerp(LAMP, bright) })
			local pl = l:FindFirstChild("ShowLight") or lib.light(l, LAMP, 26, 0, sess.trash)
			pl.Name = "ShowLight"
			lib.tween(pl, 1, { Brightness = bright * 1.4 })
		end
	end
end

-- each banner swings out about its top edge (local X axis) with its own phase
local function banners(sess, lib, t: number, amp: number)
	local P = sess.model:GetPivot()
	local xW = P:VectorToWorldSpace(Vector3.xAxis)
	for _, g in sess.model:GetDescendants() do
		if g:IsA("Model") and g.Name == "Banner" then
			local top = g:FindFirstChild("BannerTop")
			local tb = top and sess:base(top)
			if tb then
				local phase = tb.Position.X * 0.37
				local a = math.sin(t * 2.6 + phase) * amp + math.sin(t * 5.1 + phase * 2) * amp * 0.3
				local rot = CFrame.new(tb.Position) * CFrame.fromAxisAngle(xW, a) * CFrame.new(-tb.Position)
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

local function dustAt(sess, lib, trash, amount: number, strong: boolean)
	for _, d in sess.model:GetDescendants() do
		if d.Name == "DustPoint" and d:IsA("BasePart") then
			local a = lib.anchor(d.Position, trash)
			local e = lib.emitter(a, lib.SMOKE, DUST, if strong then 6 else 3.5, if strong then 3 else 2.2, 3, trash)
			e.EmissionDirection = Enum.NormalId.Bottom
			e.SpreadAngle = Vector2.new(35, 35)
			e.Acceleration = Vector3.new(0, -7, 0)
			e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
			e:Emit(amount)
		end
	end
end

function Show.Activate(sess, lib)
	sess:step(function(_, t)
		banners(sess, lib, t, math.rad(5))
	end)
	local nextDust = 3
	local t0 = os.clock()
	while sess.alive() do
		lanterns(sess, lib, 0.8)
		if os.clock() - t0 > nextDust then
			nextDust = os.clock() - t0 + 4 + math.random() * 3
			dustAt(sess, lib, sess.trash, 3, false)
		end
		task.wait(0.5)
	end
end

function Show.Spectacle(ctx, sess, lib)
	local m = ctx.model
	local s = sess or { model = m, trash = ctx.trash }
	lib.Sound.Play("Rumble")
	lib.Cine.shake(0.25, 1.2)
	lanterns(s, lib, 1)
	dustAt(s, lib, ctx.trash, 14, true)
	lib.Cine.burst(m:GetPivot().Position + Vector3.new(0, 4, 0), "Dust", 1.6)
	if sess then
		sess.paused = false -- the banners keep fluttering (harder) during the finale
	end
	local t0 = os.clock()
	local DUR = ctx.duration - 0.6
	local flash = false
	while os.clock() - t0 < DUR and ctx.alive() do
		local t = os.clock() - t0
		if sess then
			banners(sess, lib, os.clock(), math.rad(5 + 17 * math.sin(math.clamp(t / DUR, 0, 1) * math.pi)))
		end
		if not flash and t > 1.4 then
			flash = true
			lib.Sound.Play("Chime")
			dustAt(s, lib, ctx.trash, 8, true)
			lib.Cine.ring(m:GetPivot().Position + Vector3.new(0, 0.5, 0), LAMP, 120, 1.4)
			lib.Sound.Play("Cheer")
		end
		task.wait()
	end
end

return Show
