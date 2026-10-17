--!nonstrict
-- GIANT TOOLBOX show. Activation (~75%): the lid creaks a few degrees on its hinge and the three tools bob a little.
-- Completion: the lid pops open further and rings back like a spring, and the hammer, wrench and saw each hop up and land.
local Show = {}

local TOOLS = { "Hammer", "Wrench", "Saw" }

-- lid swing (rad, + = opens further) and each tool's lift (studs) along the model's up axis
local function pose(sess, lib, lid: number, lift: { [string]: number })
	local m = sess.model
	local P = m:GetPivot()
	local hinge = lib.find(m, "LidHinge")
	local hb = hinge and sess:base(hinge)
	if hb then
		local h = CFrame.new(hb.Position) * P.Rotation
		for _, p in lib.group(m, "Lid") do
			local b = sess:base(p)
			if b then
				p.CFrame = h * CFrame.Angles(lid, 0, 0) * h:Inverse() * b
			end
		end
	end
	for _, name in TOOLS do
		local dy = lift[name] or 0
		for _, p in lib.group(m, name) do
			local b = sess:base(p)
			if b then
				p.CFrame = b + P.UpVector * dy
			end
		end
	end
end

function Show.Activate(sess, lib)
	sess:step(function(_, t)
		pose(sess, lib, math.sin(t * 0.9) * math.rad(3.5), {
			Hammer = math.sin(t * 1.3) * 0.5,
			Wrench = math.sin(t * 1.3 + 2) * 0.5,
			Saw = math.sin(t * 1.3 + 4) * 0.5,
		})
	end)
end

function Show.Spectacle(ctx, sess, lib)
	if not sess then
		return
	end
	local m = ctx.model
	local hinge = lib.find(m, "LidHinge")
	lib.Sound.Play("Thud")
	lib.Cine.shake(0.35, 0.5)
	local t0 = os.clock()
	local SPAN = 2.8
	while os.clock() - t0 < SPAN and ctx.alive() do
		local t = os.clock() - t0
		-- the lid: a fast snap open, then a damped spring back to rest
		local lid = if t < 0.18 then math.rad(34) * (1 - (1 - t / 0.18) ^ 2) else math.rad(34) * math.exp(-2.6 * (t - 0.18)) * math.cos(9 * (t - 0.18))
		-- the tools: each hops (staggered) and lands with a decaying bounce
		local lift = {}
		for i, name in TOOLS do
			local tt = t - 0.1 - (i - 1) * 0.14
			lift[name] = if tt > 0 then 10 * math.abs(math.sin(tt * 5.2)) * math.exp(-1.4 * tt) else 0
		end
		pose(sess, lib, lid, lift)
		task.wait()
	end
	pose(sess, lib, 0, {})
	if hinge then
		lib.Cine.burst(hinge.Position - Vector3.new(0, 20, 0), "Dust", 1.2)
	end
	lib.Cine.ring(m:GetPivot().Position + Vector3.new(0, 0.5, 0), Color3.fromRGB(240, 120, 60), 120, 1.4)
	lib.Sound.Play("Cheer")
	task.wait(0.5)
	sess.paused = false
end

return Show
