--!nonstrict
-- ARCADE MACHINE show. Activation (~65%): the screen BOOTS: pixels sweep on row by row in green, a classic invader appears and
-- idles with a two-frame leg wiggle, and the marquee face starts to glow.
-- Completion: the game plays (the invader sidesteps, a laser pixel fires from the bottom row, the invader blows up in white),
-- while the giant joystick tilts left and right and the three giant buttons are pressed in turn; chimes; a ring.
local Show = {}

local OFF = Color3.fromRGB(26, 104, 120) -- lit teal screen background (dim pixels)
local ON = Color3.fromRGB(214, 255, 226) -- bright sprite pixels
local SCREEN = Color3.fromRGB(14, 62, 78) -- the backing plate once the game is on
local CYAN = Color3.fromRGB(90, 220, 255)
local WHITE = Color3.fromRGB(240, 255, 250)
local LASER = Color3.fromRGB(255, 80, 80)

-- the sprite (9 x 6) and its second frame (legs)
local A = {
	"001000100",
	"000101000",
	"011111110",
	"110111011",
	"111111111",
	"101000101",
}
local B = {
	"001000100",
	"100101001",
	"101111101",
	"111111111",
	"011111110",
	"010000010",
}

local function pixels(sess, lib)
	local c = sess.pix
	if not c or os.clock() - c.at > 0.5 then
		local grid = {}
		for _, p in lib.group(sess.model, "Pixel") do
			local r, cc = p:GetAttribute("Row"), p:GetAttribute("Col")
			if r and cc then
				grid[r * 10 + cc] = p
			end
		end
		c = { at = os.clock(), grid = grid }
		sess.pix = c
	end
	return c.grid
end

local function paint(p: BasePart?, color: Color3, on: boolean)
	if p then
		p.Color = color
		p.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
	end
end

-- draws frame `f` (A or B) shifted by `dx` columns; extra = { [r*10+c] = color } overrides on top
local function draw(sess, lib, f, dx: number, color: Color3, extra)
	local g = pixels(sess, lib)
	for r = 1, 6 do
		for c = 1, 9 do
			local on = false
			local sc = c - dx
			if f and sc >= 1 and sc <= 9 and string.sub(f[r], sc, sc) == "1" then
				on = true
			end
			local key = r * 10 + c
			local ex = extra and extra[key]
			if ex then
				paint(g[key], ex, true)
			else
				paint(g[key], if on then color else OFF, on)
			end
		end
	end
end

local function screenOn(sess, lib, on: boolean)
	for _, p in lib.group(sess.model, "Screen") do
		p.Color = if on then SCREEN else Color3.fromRGB(24, 28, 40)
		p.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
	end
end

local function marquee(sess, lib, glow: number)
	for _, p in lib.group(sess.model, "Marquee") do
		if not p:GetAttribute("Marker") then
			p.Color = Color3.fromRGB(110, 40, 90):Lerp(Color3.fromRGB(255, 120, 210), glow)
			p.Material = if glow > 0.5 then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end
end

function Show.Activate(sess, lib)
	sess.boot = os.clock()
	local light
	sess:step(function(_, t)
		screenOn(sess, lib, t > 0.4)
		local bt = t
		if bt < 2.4 then
			-- boot sweep: rows light up from the top with flicker, then settle
			local row = bt / 2.4 * 7
			local g = pixels(sess, lib)
			for r = 1, 6 do
				for c = 1, 9 do
					local on = r <= row and (math.noise(r * 3.1, c * 1.7, bt * 5) > -0.1)
					paint(g[r * 10 + c], if on then CYAN else OFF, on)
				end
			end
			marquee(sess, lib, bt / 2.4 * 0.6)
		else
			local f = if math.floor(t * 1.6) % 2 == 0 then A else B
			draw(sess, lib, f, 0, ON, nil)
			marquee(sess, lib, 0.6 + 0.3 * math.sin(t * 3))
		end
		if not light then
			local mq = lib.find(sess.model, "MarqueeC")
			if mq then
				light = lib.light(mq, Color3.fromRGB(150, 255, 220), 55, 0, sess.trash)
			end
		end
		if light then
			light.Brightness = 1.6 + 0.5 * math.sin(t * 3)
		end
	end)
end

function Show.Spectacle(ctx, sess, lib)
	if not sess then
		return
	end
	local m = ctx.model
	screenOn(sess, lib, true)
	local sb = lib.find(m, "StickBase")
	local base = sb and sess:base(sb)
	local P = m:GetPivot()
	local zW = P:VectorToWorldSpace(Vector3.zAxis)
	local xW = P:VectorToWorldSpace(Vector3.xAxis)
	local upW = P.UpVector
	local function joystick(angle: number)
		if not base then
			return
		end
		local rot = CFrame.new(base.Position) * CFrame.fromAxisAngle(zW, angle) * CFrame.new(-base.Position)
		for _, p in lib.group(m, "Stick") do
			local b = sess:base(p)
			if b then
				p.CFrame = rot * b
			end
		end
	end
	local btns = lib.group(m, "Button")
	local function press(i: number, depth: number)
		local p = btns[i]
		local b = p and sess:base(p)
		if b then
			p.CFrame = b - upW * depth
		end
	end
	lib.Sound.Play("Chime")
	local t0 = os.clock()
	local DUR = math.max(3, ctx.duration - 0.6)
	local shot, boom = false, false
	while os.clock() - t0 < DUR and ctx.alive() do
		local t = os.clock() - t0
		-- joystick sweeps left and right
		joystick(math.sin(t * 5) * math.rad(18))
		-- the three buttons pressed in turn (a press every 0.35 s)
		local step = math.floor(t / 0.35)
		for i = 1, 3 do
			press(i, if step % 3 == i - 1 and (t % 0.35) < 0.18 then 2.4 else 0)
		end
		-- the game: the invader sidesteps (dx -1 .. 1), a laser fires at t 1.6, boom at 2.5
		local dx = math.floor(math.sin(t * 2.2) * 1.99)
		local f = if math.floor(t * 4) % 2 == 0 then A else B
		local extra = nil
		local flash = false
		if t >= 1.6 and t < 2.5 then
			extra = {}
			local row = 6 - math.floor((t - 1.6) / 0.9 * 6)
			if row >= 1 then
				extra[row * 10 + 5] = LASER
			end
			if not shot then
				shot = true
				lib.Sound.Play("Zap")
			end
		end
		if t >= 2.5 then
			if not boom then
				boom = true
				lib.Sound.Play("Boom")
				lib.Sound.Play("Cheer")
				lib.Cine.shake(0.2, 0.3)
				lib.Cine.ring(P.Position + Vector3.new(0, 0.5, 0), Color3.fromRGB(255, 130, 210), 120, 1.4)
			end
			flash = true
		end
		if flash then
			local k = (t - 2.5) / 0.6
			if k < 1 then
				-- an exploding burst: the whole grid flashes white then fades to the boot colour
				local g = pixels(sess, lib)
				for r = 1, 6 do
					for c = 1, 9 do
						local on = math.noise(r * 1.3, c * 2.1, t * 12) > -0.25 + k * 0.6
						paint(g[r * 10 + c], if on then WHITE:Lerp(CYAN, k) else OFF, on)
					end
				end
			else
				draw(sess, lib, A, 0, ON, nil)
			end
		else
			draw(sess, lib, f, dx, ON, extra)
		end
		marquee(sess, lib, 0.5 + 0.5 * math.abs(math.sin(t * 6)))
		task.wait()
	end
	joystick(0)
	for i = 1, 3 do
		press(i, 0)
	end
	draw(sess, lib, A, 0, ON, nil)
	marquee(sess, lib, 0.8)
	sess.paused = false
end

return Show
