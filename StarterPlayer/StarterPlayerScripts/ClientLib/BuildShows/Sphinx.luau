--!nonstrict
-- SPHINX show. Activation (~55%): a subtle warm glow in the eyes (a slow amber pulse with a faint point light): the "head life" cue.
-- Completion: the eyes brighten to a strong golden glow and a broad gust of sand sweeps across the base of the monument (a wide
-- sand-coloured particle wall rolling along the length of the plinth), with a low rumble and a gold ring.
local Show = {}

local DARK = Color3.fromRGB(120, 90, 54)
local AMBER = Color3.fromRGB(255, 170, 60)
local GOLD = Color3.fromRGB(255, 226, 130)
local SAND = Color3.fromRGB(226, 196, 138)

local function eyes(model: Instance, lib, k: number, neon: boolean)
	for _, e in lib.group(model, "Eye") do
		e.Color = DARK:Lerp(AMBER, math.clamp(k, 0, 1)):Lerp(GOLD, math.clamp(k - 1, 0, 1))
		e.Material = if neon then Enum.Material.Neon else Enum.Material.Sandstone
	end
end

function Show.Activate(sess, lib)
	local light
	sess:step(function(_, t)
		local k = 0.45 + 0.25 * math.sin(t * 1.4)
		eyes(sess.model, lib, k, k > 0.3)
		if not light then
			local ec = lib.find(sess.model, "EyeC")
			if ec then
				light = lib.light(ec, AMBER, 16, 0, sess.trash)
			end
		end
		if light then
			light.Brightness = math.clamp(k, 0, 1) * 1.2
		end
	end)
end

function Show.Spectacle(ctx, sess, lib)
	local m = ctx.model
	local P = m:GetPivot()
	local xW = P:VectorToWorldSpace(Vector3.xAxis)
	local zW = P:VectorToWorldSpace(Vector3.zAxis)
	lib.Sound.Play("Rumble")
	lib.Cine.shake(0.2, 1.4)
	local t0 = os.clock()
	while os.clock() - t0 < 0.9 and ctx.alive() do
		eyes(m, lib, 0.7 + 1.3 * ((os.clock() - t0) / 0.9), true)
		task.wait()
	end
	eyes(m, lib, 2, true)
	lib.Sound.Play("Chime")
	-- the sand gust: emitters in a row across the plinth, travelling along its length (toward the head)
	local base = P.Position + Vector3.new(0, 6, 0)
	for i = -3, 3 do
		local a = lib.anchor(base - xW * 70 + zW * (i * 8), ctx.trash)
		local e = lib.emitter(a, lib.SMOKE, SAND, 9, 3.2, 8, ctx.trash)
		e.SpreadAngle = Vector2.new(18, 10)
		e.Acceleration = Vector3.new(0, 1.5, 0)
		e.Rate = 70
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
		task.delay(2.6, function()
			e.Rate = 0
		end)
		task.spawn(function()
			local s = os.clock()
			while os.clock() - s < 3 and a.Parent do
				a.Position = base - xW * 70 + zW * (i * 8) + xW * ((os.clock() - s) * 42)
				task.wait()
			end
		end)
	end
	lib.Cine.ring(P.Position + Vector3.new(0, 0.5, 0), GOLD, 150, 1.6)
	local left = ctx.duration - 0.9 - 0.2
	if left > 0 then
		task.wait(left)
	end
	lib.Sound.Play("Cheer")
end

return Show
