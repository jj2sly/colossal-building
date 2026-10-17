--!strict
-- Vehicle menu, generated from VehicleConfig. For each vehicle: state (LOCKED / OWNED /
-- EQUIPPED), what it gives you (carry capacity and speed, computed with the shared
-- formulas against your current upgrades) and a Buy / Equip / Park button.
-- Vehicles are worn by the player and still need driving: they raise transport, not automation.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local VehicleConfig = require(Shared.Config.VehicleConfig)
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local Formulas = require(Shared.Formulas)
local TrainingConfig = require(Shared.Config.TrainingConfig)
local Format = require(Shared.Util.Format)
local Lib = script.Parent.Parent.ClientLib
local UI = require(Lib.UI)
local Menu = require(Lib.Menu)
local State = require(Lib.State)
local Notify = require(script.Parent.NotifyController)

local VehiclePanel = {}
local S = Menu.S
local player = Players.LocalPlayer

local panel: any
local content: Frame

-- SITE FLEET: an equipped-vehicle summary on top, then one compact card per vehicle (name first, two numbers, one action).
local function draw()
	if not panel then
		return
	end
	for _, c in content:GetChildren() do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
	local d = State.Data
	local owned = d and d.Vehicles.Owned or {}
	local mbVehicles = d and d.MasterBuilder and d.MasterBuilder.Vehicles or {}
	local equipped = player:GetAttribute("Vehicle")
	local coins = math.floor(player:GetAttribute("Coins") or 0)
	local baseCarry = Formulas.BaseCarry(d and d.Training and d.Training.Strength or 0)
	local vcapLevel = d and d.Upgrades.VehicleCapacity or 0
	local walk = Formulas.BaseSpeed(d and d.Training and d.Training.Speed or 0)
	local baseCap = Formulas.CarryCapacity(baseCarry, nil, vcapLevel, 1)
	local eqDef = equipped and VehicleConfig.Vehicles[equipped]
	panel.Subtitle.Text = if eqDef then "Equipped: " .. eqDef.DisplayName else "On foot"

	-- SELECTED / EQUIPPED
	local sum = Menu.surface(content, { Name = "Selected", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 0 }, if eqDef then S.Accent else nil)
	local inner = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = sum })
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 12), Parent = inner })
	UI.list(inner, 8)
	local top = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Menu.buttonHeight()), LayoutOrder = 1, Parent = inner })
	local left = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -118, 1, 0), Parent = top })
	local ll = UI.list(left, 10, true)
	ll.VerticalAlignment = Enum.VerticalAlignment.Center
	UI.new("TextLabel", { Text = if eqDef then string.upper(eqDef.DisplayName) else "ON FOOT", Font = S.FontHeavy, TextSize = Menu.size("H1"), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 30), LayoutOrder = 1, Parent = left })
	Menu.stateTag(left, if eqDef then "EQUIPPED" else "OFF", 2, if eqDef then nil else "NO VEHICLE")
	if eqDef then
		Menu.button({ Name = "Park", Text = "PARK", Kind = "secondary", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(108, Menu.buttonHeight()), Parent = top }, function()
			Net.Event("VehicleCommand"):FireServer("Unequip")
		end)
	end
	local sg = Menu.grid(inner, { Min = 140, Height = 50, Max = 3, Gap = 8, Order = 2 })
	local nowCap = if eqDef then Formulas.CarryCapacity(baseCarry, equipped, vcapLevel, 1) else baseCap
	local nowSpeed = if eqDef then Formulas.VehicleSpeed(equipped, walk) else walk
	Menu.stat(sg, "Carry", tostring(nowCap), 1)
	Menu.stat(sg, "Speed", string.format("%.1f", nowSpeed), 2)
	Menu.stat(sg, "Capacity upgrade", string.format("x%.2f", UpgradeConfig.Value("VehicleCapacity", vcapLevel)), 3)

	-- THE FLEET
	Menu.section(content, "Fleet", 1, "buy once, equip any time")
	local list = {}
	for _, v in VehicleConfig.Vehicles do
		-- a Master Builder vehicle appears only once it is unlocked (never shown as purchasable)
		if not v.Master or mbVehicles[v.Id] == true then
			table.insert(list, v)
		end
	end
	table.sort(list, function(a, b)
		return a.Order < b.Order
	end)
	local grid = Menu.grid(content, { Min = 270, Height = 232, Max = 2, Gap = 12, Order = 2 })
	local MASTER_GOLD = Color3.fromRGB(255, 206, 84)
	for _, v in list do
		local isOwned = owned[v.Id] == true or (v.Master == true and mbVehicles[v.Id] == true)
		local isEquipped = equipped == v.Id
		local card = Menu.surface(grid, { Name = "Vehicle_" .. v.Id, LayoutOrder = v.Order }, if v.Master then MASTER_GOLD elseif isEquipped then S.Accent else nil)
		local cst = card:FindFirstChildOfClass("UIStroke")
		if v.Master then
			-- Master Builder reward: warm gold frame + a soft gold wash, nothing animated
			card.BackgroundColor3 = S.Surface:Lerp(MASTER_GOLD, 0.12)
			if cst then
				cst.Color = MASTER_GOLD
			end
		elseif isEquipped and cst then
			cst.Color = S.Accent
		elseif not isOwned then
			card.BackgroundColor3 = S.Surface:Lerp(S.Header, 0.35) -- locked cards sit back
		end
		-- big vehicle badge: the cart pictogram in a coloured tile (a lock sits on it while locked)
		local affordable = not isOwned and coins >= (v.Price or math.huge)
		local wellColor = if v.Master then MASTER_GOLD elseif isOwned then S.Accent elseif affordable then S.Good else S.Faint
		local well = Menu.iconWell(card, "cart", wellColor, 70)
		well.Position = UDim2.fromOffset(14, 16)
		if affordable then
			card.BackgroundColor3 = S.Surface
		elseif not isOwned then
			local lockBadge = Menu.iconWell(well, "lock", S.Dim, 28)
			lockBadge.AnchorPoint = Vector2.new(1, 1)
			lockBadge.Position = UDim2.new(1, 6, 1, 6)
		elseif v.Master then
			local star = Menu.iconWell(well, "star", MASTER_GOLD, 28)
			star.AnchorPoint = Vector2.new(1, 1)
			star.Position = UDim2.new(1, 6, 1, 6)
		end
		UI.new("TextLabel", { Text = string.upper(v.DisplayName), Font = S.FontHeavy, TextSize = 22, TextColor3 = if v.Master then MASTER_GOLD:Lerp(S.Text, 0.3) elseif isOwned then S.Text else S.Dim, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(96, 16), Size = UDim2.new(1, -104, 0, 26), Parent = card })
		local tagHolder = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(96, 46), Size = UDim2.new(1, -104, 0, 22), Parent = card })
		local stTag = Menu.stateTag(tagHolder, if isEquipped then "EQUIPPED" elseif isOwned then "OWNED" else "LOCKED", 1, if v.Master then "MASTER BUILDER" else nil)
		if v.Master then
			stTag.BackgroundColor3 = MASTER_GOLD
			stTag.TextColor3 = S.AccentText
		end
		UI.new("TextLabel", { Text = if v.Master then "Permanent reward" else v.Description, Font = S.FontBold, TextSize = Menu.size("Small"), TextColor3 = S.Dim, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(96, 70), Size = UDim2.new(1, -104, 0, 18), Parent = card })
		local withVehicle = Formulas.CarryCapacity(baseCarry, v.Id, vcapLevel, 1)
		local vSpeed = Formulas.VehicleSpeed(v.Id, walk)
		local c1 = Menu.stat(card, "Carry", string.format("%d → %d", baseCap, withVehicle), 0, S.Good)
		c1.Position = UDim2.fromOffset(12, 98)
		c1.Size = UDim2.new(0.5, -16, 0, 50)
		local c2 = Menu.stat(card, "Speed", string.format("%.0f → %.0f", walk, vSpeed), 0, if vSpeed > walk then S.Good else S.Text)
		c2.Position = UDim2.new(0.5, 4, 0, 98)
		c2.Size = UDim2.new(0.5, -16, 0, 50)

		local text, kind, enabled
		if isEquipped then
			text, kind, enabled = "PARK", "secondary", true
		elseif isOwned then
			text, kind, enabled = "EQUIP", "primary", true
		else
			text, kind, enabled = string.format("BUY  %s", Format.Number(v.Price)), if coins >= v.Price then "good" else "secondary", coins >= v.Price
		end
		local b = Menu.button({
			Name = "Action_" .. v.Id,
			Text = text,
			Kind = kind,
			Enabled = enabled,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 12, 1, -12),
			Size = UDim2.new(1, -24, 0, 50),
			TextSize = 20,
			Parent = card,
		}, function()
			if isEquipped then
				Net.Event("VehicleCommand"):FireServer("Unequip")
			elseif isOwned then
				Net.Event("VehicleCommand"):FireServer("Equip", v.Id)
			else
				local ok, msg = Net.Function("BuyItem"):InvokeServer("Vehicle", v.Id)
				if not ok then
					Notify.Show("Error", tostring(msg))
				end
			end
		end)
		local _ = b
	end
end

local function refresh()
	Menu.keepFocus(panel.Frame, draw)
end

local function build(): Frame
	panel = Menu.panel("Vehicles", "Site Fleet", { Icon = "wheel" })
	content = UI.new("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.new(1, -(2 * S.Pad + 6), 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = panel.Body })
	UI.list(content, 10)
	return panel.Frame
end

function VehiclePanel.Start()
	UI.registerPanel("Vehicles", build, refresh)
	State.DataChanged:Connect(function()
		if UI.isOpen("Vehicles") then
			refresh()
		end
	end)
	player:GetAttributeChangedSignal("Vehicle"):Connect(function()
		if UI.isOpen("Vehicles") then
			refresh()
		end
	end)
	-- Coins move every ~0.3 s while depositing; the cards redraw from scratch, so batch to 2 Hz
	local coinRefreshQueued = false
	player:GetAttributeChangedSignal("Coins"):Connect(function()
		if UI.isOpen("Vehicles") and not coinRefreshQueued then
			coinRefreshQueued = true
			task.delay(0.5, function()
				coinRefreshQueued = false
				if UI.isOpen("Vehicles") then
					refresh()
				end
			end)
		end
	end)
	UI.ModeChanged:Connect(function()
		if panel then
			if UI.isOpen("Vehicles") then
				UI.closePanel()
			end
			panel.Frame:Destroy()
			panel = nil
			UI.registerPanel("Vehicles", build, refresh)
		end
	end)
end

return VehiclePanel
