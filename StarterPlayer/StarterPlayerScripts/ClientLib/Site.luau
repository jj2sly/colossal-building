--!strict
-- "Construction site" decoration kit shared by the HUD and the menus: pictogram icons drawn
-- from plain rectangles (no emoji, no image assets, so they take the same tint as the UI),
-- a hazard-stripe strip, corner bolts, and the blueprint/steel palette extras.
-- Everything is a handful of Frames; build once, never per frame.
local UI = require(script.Parent.UI)

local Site = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

Site.Color = {
	Steel = rgb(34, 38, 46), -- panels
	SteelDark = rgb(22, 25, 31), -- headers / wells
	SteelLight = rgb(52, 58, 69), -- raised plates
	Seam = rgb(70, 78, 92),
	Blueprint = rgb(24, 46, 78), -- blueprint paper
	BlueprintLine = rgb(70, 130, 190),
	Hazard = rgb(246, 190, 40), -- safety yellow
	HazardDark = rgb(28, 24, 12),
	Orange = rgb(226, 128, 44),
	Cyan = rgb(96, 190, 230),
	Bolt = rgb(96, 104, 118),
}

-- One flat block centred at (cx, cy) on a 32x32 canvas.
local function blk(parent: Instance, cx: number, cy: number, w: number, h: number, rot: number, color: Color3, round: boolean?): Frame
	local f = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(cx, cy),
		Size = UDim2.fromOffset(w, h),
		Rotation = rot,
		BackgroundColor3 = color,
		BackgroundTransparency = 0,
		Parent = parent,
	})
	if round then
		UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = f })
	end
	return f
end

type Drawer = (Frame, Color3, Color3) -> ()
local ICONS: { [string]: Drawer } = {}

ICONS.hammer = function(c, col, dark)
	blk(c, 14, 19, 5, 22, 45, col)
	blk(c, 21, 11, 16, 8, 45, col)
	blk(c, 21, 11, 16, 2, 45, dark)
end
ICONS.pickaxe = function(c, col, dark)
	blk(c, 15, 19, 4, 24, 45, col)
	blk(c, 21, 11, 26, 4, 45, col)
	blk(c, 21, 11, 4, 4, 45, dark)
end
ICONS.plans = function(c, col, dark)
	blk(c, 16, 16, 22, 28, 0, col)
	blk(c, 16, 9, 14, 2, 0, dark)
	blk(c, 16, 15, 14, 2, 0, dark)
	blk(c, 16, 21, 14, 2, 0, dark)
	blk(c, 13, 26, 8, 2, 0, dark)
end
ICONS.hardhat = function(c, col, dark)
	local clip = UI.new("Frame", { BackgroundTransparency = 1, ClipsDescendants = true, Position = UDim2.fromOffset(5, 6), Size = UDim2.fromOffset(22, 12), Parent = c })
	local dome = UI.new("Frame", { BackgroundColor3 = col, BackgroundTransparency = 0, Size = UDim2.fromOffset(22, 22), Parent = clip })
	UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = dome })
	blk(c, 16, 19, 29, 5, 0, col)
	blk(c, 16, 10, 4, 9, 0, dark)
end
ICONS.cart = function(c, col, dark)
	blk(c, 14, 16, 20, 9, 0, col)
	blk(c, 14, 20, 20, 2, 0, dark)
	blk(c, 25, 11, 10, 3, -30, col)
	blk(c, 9, 25, 8, 8, 0, col, true)
	blk(c, 9, 25, 3, 3, 0, dark, true)
	blk(c, 20, 25, 8, 8, 0, col, true)
	blk(c, 20, 25, 3, 3, 0, dark, true)
end
ICONS.gear = function(c, col, dark)
	blk(c, 16, 16, 19, 19, 0, col)
	blk(c, 16, 16, 19, 19, 45, col)
	blk(c, 16, 16, 9, 9, 0, dark, true)
end
ICONS.crate = function(c, col, dark)
	blk(c, 16, 16, 24, 24, 0, col)
	blk(c, 16, 16, 20, 20, 0, dark)
	blk(c, 16, 16, 16, 16, 0, col)
	blk(c, 16, 16, 24, 2, 45, dark)
	blk(c, 16, 16, 24, 2, -45, dark)
end
ICONS.chevrons = function(c, col)
	for _, x in { 10, 20 } do
		blk(c, x, 11.5, 11, 4, 45, col)
		blk(c, x, 20.5, 11, 4, -45, col)
	end
end
ICONS.tray = function(c, col)
	blk(c, 16, 8, 5, 8, 0, col)
	blk(c, 12.5, 15.5, 10, 4, 45, col)
	blk(c, 19.5, 15.5, 10, 4, -45, col)
	blk(c, 16, 26, 24, 4, 0, col)
	blk(c, 5, 22, 4, 10, 0, col)
	blk(c, 27, 22, 4, 10, 0, col)
end
ICONS.clover = function(c, col, dark)
	blk(c, 12, 12, 10, 10, 0, col, true)
	blk(c, 20, 12, 10, 10, 0, col, true)
	blk(c, 12, 20, 10, 10, 0, col, true)
	blk(c, 20, 20, 10, 10, 0, col, true)
	blk(c, 16, 16, 2, 22, 0, dark)
	blk(c, 16, 16, 22, 2, 0, dark)
	blk(c, 19, 27, 3, 9, 25, col)
end
ICONS.coin = function(c, col, dark)
	blk(c, 16, 16, 24, 24, 0, col, true)
	blk(c, 16, 16, 16, 16, 0, dark, true)
	blk(c, 16, 16, 12, 12, 0, col, true)
	blk(c, 16, 16, 4, 12, 0, dark)
end
ICONS.trophy = function(c, col, dark)
	blk(c, 16, 12, 16, 14, 0, col)
	blk(c, 7, 11, 5, 8, 0, col)
	blk(c, 25, 11, 5, 8, 0, col)
	blk(c, 16, 22, 4, 6, 0, col)
	blk(c, 16, 27, 14, 4, 0, col)
	blk(c, 16, 10, 4, 6, 0, dark)
end
ICONS.alert = function(c, col, dark)
	blk(c, 16, 16, 22, 22, 45, col)
	blk(c, 16, 13, 4, 10, 0, dark)
	blk(c, 16, 22, 4, 4, 0, dark)
end
ICONS.dumbbell = function(c, col, dark)
	blk(c, 16, 16, 20, 4, 0, col)
	blk(c, 6, 16, 5, 16, 0, col)
	blk(c, 26, 16, 5, 16, 0, col)
	blk(c, 10, 16, 4, 11, 0, col)
	blk(c, 22, 16, 4, 11, 0, col)
	blk(c, 16, 16, 6, 2, 0, dark)
end
ICONS.tag = function(c, col, dark)
	blk(c, 16, 16, 24, 16, 0, col)
	blk(c, 9, 16, 4, 4, 0, dark, true)
end

-- (Pass 21A) resource family + state pictograms
ICONS.log = function(c, col, dark)
	blk(c, 16, 11, 26, 8, -12, col, true)
	blk(c, 16, 21, 26, 8, -12, col, true)
	blk(c, 27, 8.7, 5, 5, 0, dark, true)
	blk(c, 27, 18.7, 5, 5, 0, dark, true)
end
ICONS.rock = function(c, col, dark)
	blk(c, 16, 19, 24, 16, 0, col, true)
	blk(c, 12, 13, 14, 12, 20, col, true)
	blk(c, 21, 14, 12, 10, -15, col, true)
	blk(c, 13, 20, 6, 2, 20, dark)
end
ICONS.ingot = function(c, col, dark)
	blk(c, 16, 21, 26, 10, 0, col)
	blk(c, 16, 13, 18, 8, 0, col)
	blk(c, 16, 16.5, 26, 2, 0, dark)
end
ICONS.bolt = function(c, col, dark)
	blk(c, 18, 9, 7, 14, 25, col)
	blk(c, 16, 16, 16, 5, 0, col)
	blk(c, 14, 23, 7, 14, 25, col)
	local _ = dark
end
ICONS.gem = function(c, col, dark)
	blk(c, 16, 16, 18, 18, 45, col)
	blk(c, 16, 16, 7, 7, 45, dark)
end
ICONS.star = function(c, col, dark)
	blk(c, 16, 16, 18, 18, 0, col)
	blk(c, 16, 16, 18, 18, 45, col)
	blk(c, 16, 16, 6, 6, 45, dark)
end
ICONS.lock = function(c, col, dark)
	blk(c, 16, 21, 20, 14, 0, col)
	blk(c, 10.5, 11, 4, 10, 0, col)
	blk(c, 21.5, 11, 4, 10, 0, col)
	blk(c, 16, 7, 15, 4, 0, col)
	blk(c, 16, 21, 4, 6, 0, dark)
end

-- (Pass 21P) steering wheel (Vehicles) and open book (Build Index): ring of blocks, three spokes and a hub / two angled pages on a spine
ICONS.wheel = function(c, col, dark)
	-- simple wheel: ring, one cross-bar and a down spoke, hub
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		blk(c, 16 + math.cos(a) * 11.5, 16 + math.sin(a) * 11.5, 6.4, 6.4, math.deg(a) + 45, col, true)
	end
	blk(c, 16, 16, 22, 4, 0, col)
	blk(c, 16, 23, 4, 12, 0, col)
	blk(c, 16, 16, 8, 8, 0, col, true)
end
ICONS.book = function(c, col, dark)
	blk(c, 9.6, 17, 13, 21, -7, col)
	blk(c, 22.4, 17, 13, 21, 7, col)
	blk(c, 16, 18.2, 2.2, 22, 0, dark)
	for k = 0, 2 do
		blk(c, 9.2, 11 + k * 5, 8, 1.6, -7, dark)
		blk(c, 22.8, 11 + k * 5, 8, 1.6, 7, dark)
	end
	blk(c, 9.6, 28.4, 13, 2, -7, col)
	blk(c, 22.4, 28.4, 13, 2, 7, col)
end

-- Pictogram in a square of `px` pixels. Unknown names fall back to a plain block.
function Site.icon(parent: Instance, name: string, color: Color3, px: number, dark: Color3?): Frame
	local holder = UI.new("Frame", { Name = "Icon_" .. name, BackgroundTransparency = 1, Size = UDim2.fromOffset(px, px), Parent = parent })
	local art = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(32, 32), Parent = holder })
	UI.new("UIScale", { Scale = px / 32, Parent = art })
	local draw = ICONS[name]
	if draw then
		draw(art, color, dark or Site.Color.SteelDark)
	else
		blk(art, 16, 16, 18, 18, 0, color)
	end
	return holder
end

-- Caution-stripe strip (diagonal bars on a dark ground). Purely decorative.
function Site.hazard(parent: Instance, height: number, order: number?, count: number?): Frame
	local f = UI.new("Frame", {
		Name = "Hazard",
		BackgroundColor3 = Site.Color.HazardDark,
		BackgroundTransparency = 0,
		ClipsDescendants = true,
		Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = order or 0,
		Parent = parent,
	})
	local n = count or 28
	for i = 0, n do
		UI.new("Frame", {
			BackgroundColor3 = Site.Color.Hazard,
			BackgroundTransparency = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(i / n, 0, 0.5, 0),
			Size = UDim2.new(0.5 / n, 0, 0, height * 3),
			Rotation = 35,
			Parent = f,
		})
	end
	return f
end

-- Four small corner bolts inside a panel.
function Site.bolts(parent: Instance, inset: number?)
	local i = inset or 5
	for _, a in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		UI.new("Frame", {
			Name = "Bolt",
			BackgroundColor3 = Site.Color.Bolt,
			BackgroundTransparency = 0,
			AnchorPoint = a,
			Position = UDim2.new(a.X, if a.X == 0 then i else -i, a.Y, if a.Y == 0 then i else -i),
			Size = UDim2.fromOffset(4, 4),
			ZIndex = 5,
			Parent = parent,
		})
	end
end

return Site
