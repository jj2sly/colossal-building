--!strict
-- Event banner + client-side event visuals (meteors, rush zone highlight).
-- Meteors are fully simulated locally from a single server message; impacts that
-- matter (section damage) are decided by the server.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local EventConfig = require(Shared.Config.EventConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local ResourceSpotConfig = require(Shared.Config.ResourceSpotConfig)
local Format = require(Shared.Util.Format)
local Lib = script.Parent.Parent.ClientLib
local UI = require(Lib.UI)
local Sound = require(Lib.Sound)
local Cine = require(Lib.Cine)
local State = require(Lib.State)
local Site = require(Lib.Site)
local HUD = require(script.Parent.HUDController)
local Notify = require(script.Parent.NotifyController)

local EventUIController = {}
local T = UI.Theme
-- incident bulletin colours: muted, readable, no candy
local KIND_COLORS = {
	Help = Color3.fromRGB(44, 112, 70),
	Hinder = Color3.fromRGB(150, 88, 32),
	Damage = Color3.fromRGB(156, 46, 40),
}
local EVENT_ICONS = {
	BuildFrenzy = "hammer",
	DoubleCarry = "crate",
	GoldenHour = "coin",
	ResourceRush = "pickaxe",
	MeteorShower = "alert",
	Earthquake = "alert",
	WorkerStrike = "hardhat",
}
local iconTile: TextLabel
local iconArt: Frame? = nil
local kindEdge: Frame
local eventStrip: Frame
local function setEventIcon(id: string)
	if iconArt then
		iconArt:Destroy()
	end
	iconArt = Site.icon(iconTile, EVENT_ICONS[id] or "alert", Color3.new(1, 1, 1), 28, Color3.fromRGB(20, 20, 24))
	local a = iconArt :: Frame
	a.AnchorPoint = Vector2.new(0.5, 0.5)
	a.Position = UDim2.fromScale(0.5, 0.5)
end

local banner: Frame
local titleL: TextLabel
local descL: TextLabel
local timerL: TextLabel
local timerBar: Frame
local timerFill: Frame
local rushHighlight: Instance? = nil
local shownEvent = "" -- event id the banner currently represents
local expandedUntil = 0 -- banner shows the full description until this time

-- Banner has two states: a short "expanded" entrance (icon, title, description, timer) and a
-- slim "compact" active state (icon, title, timer + draining bar) so it never dominates.
local function applySize(expanded: boolean, animate: boolean)
	-- the event strip docks under the project card at the SAME width (Bible §9); only its height changes
	local width = if UI.Mode == "phone" and UI.Portrait then 296 else 330
	local size = if expanded then UDim2.fromOffset(width, 60) else UDim2.fromOffset(width, 46)
	descL.Visible = expanded
	iconTile.Size = if expanded then UDim2.fromOffset(44, 44) else UDim2.fromOffset(34, 34)
	iconTile:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
	titleL.Position = UDim2.fromOffset(if expanded then 62 else 52, if expanded then 5 else 2)
	titleL.Size = UDim2.new(1, if expanded then -140 else -128, 0, if expanded then 28 else 40)
	titleL.TextSize = if expanded then 24 else 18
	if animate then
		UI.tween(banner, UI.Anim.Normal, { Size = size }, Enum.EasingStyle.Quad)
	else
		banner.Size = size
	end
end

local function refresh()
	local id = State.Get("EventId") or ""
	local def = EventConfig.Events[id]
	if not def then
		if banner.Visible then
			-- short exit: shrink and fade, then hide
			local sc = banner:FindFirstChildOfClass("UIScale") or UI.new("UIScale", { Parent = banner })
			UI.tween(sc, UI.Anim.Fast, { Scale = 0.85 })
			task.delay(UI.Anim.Fast, function()
				if (State.Get("EventId") or "") == "" then
					banner.Visible = false
					sc.Scale = 1
				end
			end)
		end
		shownEvent = ""
		return
	end
	local newEvent = shownEvent ~= id
	banner.Visible = true
	-- steel bulletin plate; the kind colour lives on the edge, icon tile and gauge only
	local kindColor = KIND_COLORS[def.Kind] or T.Blue
	kindEdge.BackgroundColor3 = kindColor
	iconTile.BackgroundColor3 = kindColor
	-- the event colour fills the strip (darkened) so it reads bright but compact, not as a grey notice box
	banner.BackgroundColor3 = kindColor:Lerp(UI.Tokens.PlateDeep, 0.62)
	local bst = banner:FindFirstChildOfClass("UIStroke")
	if bst then
		bst.Color = kindColor
	end
	timerFill.BackgroundColor3 = kindColor:Lerp(Color3.new(1, 1, 1), 0.35)
	eventStrip.Visible = def.Kind ~= "Help" -- hazard stripes only on warnings
	if shownEvent ~= id then
		setEventIcon(id)
	end
	local phase = State.Get("EventPhase") or ""
	local param = State.Get("EventParam") or ""
	local res = ResourceConfig.Resources[param]
	if phase == "Warning" then
		titleL.Text = def.DisplayName .. "!"
	elseif res and id == "ResourceRush" then
		titleL.Text = def.DisplayName .. ": " .. string.upper(res.DisplayName) .. "!"
	else
		titleL.Text = def.DisplayName .. "!"
	end
	descL.Text = if res and id == "ResourceRush"
		then string.format("Go to the %s: x2 yield + speed", string.upper((ResourceSpotConfig.Get(res.Zone) or { DisplayName = res.Zone }).DisplayName))
		else def.Description
	if newEvent then
		shownEvent = id
		expandedUntil = os.clock() + 4
		applySize(true, false)
		-- entrance: pop in from small
		local sc = banner:FindFirstChildOfClass("UIScale") or UI.new("UIScale", { Parent = banner })
		sc.Scale = 0.6
		UI.tween(sc, UI.Anim.Slow, { Scale = 1 }, Enum.EasingStyle.Back)
		timerBar.Visible = true
	end
	-- warnings stay expanded until the event goes active
	if phase == "Warning" then
		expandedUntil = math.max(expandedUntil, os.clock() + 1)
	end
end

local function clearRush()
	if rushHighlight then
		rushHighlight:Destroy()
		rushHighlight = nil
	end
end

local rushKey = ""
local function updateRushZone()
	-- this runs for every event-state change; only rebuild when the zone actually changes
	local key = if State.Get("EventId") == "ResourceRush" then tostring(State.Get("EventParam")) else ""
	if key == rushKey and (key == "" or rushHighlight) then
		return
	end
	rushKey = key
	clearRush()
	if key == "" then
		return
	end
	local res = ResourceConfig.Resources[State.Get("EventParam") or ""]
	local world = workspace:FindFirstChild("World")
	local zones = world and world:FindFirstChild("Zones")
	local zone = res and zones and zones:FindFirstChild(res.Zone)
	if not zone then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "RushFX"
	local hl = Instance.new("Highlight")
	hl.Adornee = zone
	hl.FillColor = res.Color
	hl.FillTransparency = 0.82
	hl.OutlineColor = res.Color:Lerp(Color3.new(1, 1, 1), 0.35) -- a soft tinted rim, never a hard white debug outline
	hl.OutlineTransparency = 0.55
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = folder
	local gp = zone:FindFirstChild("GatherPoint") :: BasePart?
	if gp then
		local pillar = Instance.new("Part")
		pillar.Anchored = true
		pillar.CanCollide = false
		pillar.CanQuery = false
		pillar.CanTouch = false
		pillar.Material = Enum.Material.Neon
		pillar.Color = res.Color
		pillar.Transparency = 0.55
		pillar.Size = Vector3.new(6, 220, 6)
		pillar.Position = gp.Position + Vector3.new(0, 110, 0)
		pillar.Parent = folder
	end
	folder.Parent = workspace
	rushHighlight = folder
end

local function spawnMeteor(impact: any, fallTime: number)
	task.wait(impact.Delay)
	local target: Vector3 = impact.Position
	local start = target + Vector3.new(math.random(-60, 60), 160, math.random(-60, 60))
	local size = if impact.Big then 9 else 5
	local rock = Instance.new("Part")
	rock.Shape = Enum.PartType.Ball
	rock.Size = Vector3.one * size
	rock.Material = Enum.Material.Neon
	rock.Color = Color3.fromRGB(255, 120, 40)
	rock.Anchored = true
	rock.CanCollide = false
	rock.CanQuery = false
	rock.CanTouch = false
	rock.CFrame = CFrame.new(start)
	local fire = Instance.new("Fire")
	fire.Size = size * 1.6
	fire.Heat = 20
	fire.Parent = rock
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, size / 3, 0)
	a0.Parent = rock
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -size / 3, 0)
	a1.Parent = rock
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.5
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(120, 60, 40))
	trail.LightEmission = 1
	trail.Parent = rock
	rock.Parent = workspace
	UI.tween(rock, fallTime, { CFrame = CFrame.new(target) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.wait(fallTime)
	rock:Destroy()
	local boom = Instance.new("Explosion")
	boom.Position = target
	boom.BlastPressure = 0
	boom.BlastRadius = 0
	boom.DestroyJointRadiusPercent = 0
	boom.ExplosionType = Enum.ExplosionType.NoCraters
	boom.Parent = workspace
	local char = Players.LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp and (hrp.Position - target).Magnitude < 120 then
		Sound.Play("Meteor", 0.15)
	end
	-- smoldering crater rocks
	for _ = 1, if impact.Big then 5 else 3 do
		local d = Instance.new("Part")
		d.Size = Vector3.new(math.random(10, 22) / 10, math.random(8, 16) / 10, math.random(10, 22) / 10)
		d.Color = Color3.fromRGB(60, 45, 40)
		d.Material = Enum.Material.Basalt
		d.Anchored = true
		d.CanCollide = false
		d.CanQuery = false
		d.CFrame = CFrame.new(target + Vector3.new(math.random(-4, 4), 0.5, math.random(-4, 4))) * CFrame.Angles(math.random(), math.random(), math.random())
		d.Parent = workspace
		Debris:AddItem(d, 8)
	end
end

-- Golden Hour: warm color grade while the event runs (local Lighting effect).
local tint: ColorCorrectionEffect? = nil
local function setGoldenTint(on: boolean)
	if on and not tint then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "MB_GoldenHourTint"
		cc.Parent = game:GetService("Lighting")
		tint = cc
		UI.tween(cc, 1.5, { TintColor = Color3.fromRGB(255, 214, 140), Saturation = 0.2 })
	elseif not on and tint then
		local cc = tint
		tint = nil
		UI.tween(cc, 1.2, { TintColor = Color3.new(1, 1, 1), Saturation = 0 })
		task.delay(1.3, function()
			cc:Destroy()
		end)
	end
end

function EventUIController.Start()
	while not HUD.TopStack do
		task.wait()
	end
	banner = UI.card({
		Name = "EventBanner",
		Size = UDim2.fromOffset(400, 54),
		LayoutOrder = 2,
		Visible = false,
		ClipsDescendants = false,
		Parent = HUD.TopStack,
	})
	iconTile = UI.new("TextLabel", {
		Text = "",
		TextSize = 22,
		BackgroundColor3 = T.Blue,
		BackgroundTransparency = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(40, 40),
		Parent = banner,
	})
	UI.corner(iconTile, 22)
	UI.stroke(iconTile, UI.Tokens.Frame, 2)
	banner.BackgroundColor3 = T.Panel
	kindEdge = UI.new("Frame", { Name = "KindEdge", BackgroundColor3 = T.Blue, BackgroundTransparency = 0, Size = UDim2.new(0, 4, 1, 0), Visible = false, Parent = banner })
	UI.corner(kindEdge, 2)
	-- caution strip along the top edge: an incident bulletin, not a toast
	local strip = Site.hazard(banner, 4)
	eventStrip = strip
	strip.Position = UDim2.fromOffset(6, -2)
	strip.Size = UDim2.new(1, -12, 0, 4)
	titleL = UI.new("TextLabel", { Font = T.Title, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = banner })
	descL = UI.new("TextLabel", { Text = "", Font = T.Bold, TextSize = 14, Position = UDim2.fromOffset(62, 33), Size = UDim2.new(1, -146, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = banner })
		timerL = UI.new("TextLabel", { Text = "", Font = T.Title, TextSize = 22, BackgroundColor3 = UI.Tokens.Frame, BackgroundTransparency = 0.35, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, -2), Size = UDim2.fromOffset(66, 32), Parent = banner })
	UI.corner(timerL, 16)
		timerBar = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0.6, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, -24, 0, 6), Parent = banner })
	UI.corner(timerBar, 3)
	timerFill = UI.new("Frame", { BackgroundColor3 = T.Text, Size = UDim2.fromScale(1, 1), Parent = timerBar })
	UI.corner(timerFill, 3)
	applySize(true, false)
	UI.ModeChanged:Connect(function()
		applySize(os.clock() < expandedUntil, false)
	end)

	for _, key in { "EventId", "EventPhase", "EventParam" } do
		State.Changed(key, function()
			refresh()
			updateRushZone()
			setGoldenTint(State.Get("EventId") == "GoldenHour")
		end)
	end
	setGoldenTint(State.Get("EventId") == "GoldenHour")
	refresh()
	task.spawn(function()
		local blink = false
		local compact = false
		while true do
			task.wait(0.25)
			if banner.Visible and shownEvent ~= "" then
				local def = EventConfig.Events[shownEvent]
				local endsAt = State.Get("EventEndsAt") or 0
				local left = math.max(0, endsAt - State.ServerNow())
				timerL.Text = Format.Time(left)
				local total = if def then def.Duration else 1
				timerFill.Size = UDim2.fromScale(math.clamp(left / math.max(1, total), 0, 1), 1) -- 4 Hz steps are sub-pixel; no Tween object per tick
				if State.Get("EventPhase") == "Warning" then
					blink = not blink
					titleL.TextColor3 = if blink then Color3.fromRGB(255, 230, 90) else T.Text
				else
					titleL.TextColor3 = T.Text
				end
				local wantExpanded = os.clock() < expandedUntil
				if wantExpanded == compact then
					compact = not wantExpanded
					applySize(wantExpanded, true)
				end
			else
				compact = false
			end
		end
	end)

	Net.Event("Effect").OnClientEvent:Connect(function(id, payload)
		if id == "EventStarted" then
			Sound.Play("EventStart")
		elseif id == "EventEnded" then
			if payload.Id == "DoubleCarry" then
				Notify.Show("Info", "Double Carry ended. You keep everything you're carrying!")
			elseif payload.Id == "WorkerStrike" then
				Notify.Show("Info", "👷 The strike is over. Workers are back on the job!")
			end
			clearRush()
		elseif id == "Meteors" then
			for _, impact in payload.Impacts do
				task.spawn(spawnMeteor, impact, payload.FallTime)
			end
		elseif id == "EarthquakeWarning" then
			-- the banner already says WARNING; just a faint rumble
			Cine.shake(0.15, payload.Time * 0.6)
			Sound.Play("Rumble")
		elseif id == "Earthquake" then
			Sound.Play("Meteor")
			Sound.Play("Rumble")
			Cine.shake(0.4, payload.Duration)
			-- dust shaken loose around the build site
			for k = 0, 5 do
				local a = k / 6 * math.pi * 2
				Cine.burst(Vector3.new(math.cos(a) * 46, 2, math.sin(a) * 46), "Dust", 0.8)
			end

		end
	end)
end

return EventUIController
