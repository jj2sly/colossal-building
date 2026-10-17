--!strict
-- Upgrades menu. One row per UpgradeConfig entry (built from config, nothing hardcoded):
-- icon, name, level + bar, "current → next (+delta)", and a cost button that becomes MAXED.
-- Values/prices come from UpgradeConfig (same formulas as the server); purchases go through
-- the BuyUpgrade RemoteFunction, which validates everything server-side.
-- A small amber marker on the HUD Upgrades button shows when something is affordable.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local TrainingConfig = require(Shared.Config.TrainingConfig)
local Format = require(Shared.Util.Format)
local Lib = script.Parent.Parent.ClientLib
local UI = require(Lib.UI)
local Menu = require(Lib.Menu)
local State = require(Lib.State)
local Notify = require(script.Parent.NotifyController)
local HUD = require(script.Parent.HUDController)

local UpgradePanel = {}
local S = Menu.S
local STEEL = Color3.fromRGB(176, 184, 198) -- training bars: neutral steel (cyan is reserved for Power)
local player = Players.LocalPlayer

type Row = {
	frame: Frame,
	level: TextLabel,
	next: TextLabel,
	bar: (number, Color3?) -> (),
	buy: TextButton,
}

local panel: any
local rows: { [string]: Row } = {}
type TrainRow = { level: TextLabel, effect: TextLabel, bar: (number, Color3?) -> (), fatigue: TextLabel? }
local trainRows: { [string]: TrainRow } = {}
local busy = false
local ROW_ORDER: { UpgradeConfig.Upgrade } = {}
local ICON_FOR = {
	CarryCapacity = "crate",
	WalkSpeed = "chevrons",
	GatherSpeed = "pickaxe",
	DepositSpeed = "tray",
	Luck = "clover",
	WorkerEfficiency = "hardhat",
	VehicleCapacity = "cart",
}

local function deltaText(id: string, cur: number, nxt: number): string
	local u = UpgradeConfig.Upgrades[id]
	local d = nxt - cur
	if u.Format == "mult" then
		return string.format("+%.2f", d)
	elseif u.Format == "pct" then
		return string.format("+%d%%", math.floor(d + 0.5))
	end
	return "+" .. tostring(math.floor(d * 10 + 0.5) / 10)
end

local function anyAffordable(): boolean
	local data = State.Data
	if not data then
		return false
	end
	local coins = player:GetAttribute("Coins") or 0
	for id, u in UpgradeConfig.Upgrades do
		local price = UpgradeConfig.Price(id, data.Upgrades[id] or 0)
		if price and coins >= price then
			return true
		end
	end
	return false
end

local function hex(c: Color3): string
	return string.format("#%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

-- CURRENT -> NEXT in one line: current in ink, next benefit in the construction accent, the gain in green
local function nextText(id: string, level: number): string
	local cur = UpgradeConfig.Value(id, level)
	local nxt = UpgradeConfig.Value(id, level + 1)
	return string.format(
		'<font color="%s">%s</font>  →  <font color="%s">%s</font>  <font color="%s">%s</font>',
		hex(S.Text), UpgradeConfig.FormatValue(id, cur), hex(S.Accent), UpgradeConfig.FormatValue(id, nxt), hex(S.Good), deltaText(id, cur, nxt)
	)
end

local function refresh()
	local data = State.Data
	local coins = math.floor(player:GetAttribute("Coins") or 0)
	if panel then
		panel.Subtitle.Text = "Coins  " .. Format.Number(coins)
	end
	HUD.SetBadge("Upgrades", anyAffordable())
	if not panel then
		return
	end
	for statId, row in trainRows do
		local def = TrainingConfig.Stats[statId]
		local points = data and data.Training and data.Training[statId] or 0
		local level, into, need = TrainingConfig.Progress(statId, points)
		row.level.Text = string.format("LV %d / %d", level, def.MaxLevel)
		row.bar(if need > 0 then into / need else 1, if need > 0 then STEEL else S.Good)
		local cur = TrainingConfig.Effect(statId, level)
		if need > 0 then
			local nxt = TrainingConfig.Effect(statId, level + 1)
			row.effect.Text = string.format('<font color="%s">%.1f</font>  →  <font color="%s">%.1f</font>   <font color="%s">%d / %d XP</font>', hex(S.Text), cur, hex(S.Accent), nxt, hex(S.Dim), math.floor(into), need)
		else
			row.effect.Text = string.format('<font color="%s">%.1f  ·  MAX</font>', hex(S.Good), cur)
		end
	end
	for id, row in rows do
		local u = UpgradeConfig.Upgrades[id]
		local level = data and data.Upgrades[id] or 0
		local price = UpgradeConfig.Price(id, level)
		row.level.Text = string.format("LV %d / %d", level, u.MaxLevel)
		row.bar(level / u.MaxLevel, if price then S.Accent else S.Good)
		if price then
			row.next.Text = nextText(id, level)
			local can = coins >= price
			-- AVAILABLE = construction yellow (primary); UNAFFORDABLE = muted steel with the price still readable
			Menu.setButton(row.buy, { Text = "BUY  " .. Format.Short(price), Kind = if can then "good" else "secondary", Enabled = can })
			-- affordable rows light up (green frame) so the next purchase is obvious at a glance
			local st = row.frame:FindFirstChildOfClass("UIStroke")
			if st then
				st.Color = if can then S.Good else S.Border
			end
		else
			row.next.Text = string.format('<font color="%s">%s  ·  MAX</font>', hex(S.Good), UpgradeConfig.FormatValue(id, UpgradeConfig.Value(id, level)))
			Menu.setButton(row.buy, { Text = "MAXED", Kind = "secondary", Enabled = false })
			local st = row.frame:FindFirstChildOfClass("UIStroke")
			if st then
				st.Color = S.Border
			end
		end
	end
end

-- shared row skeleton: pictogram well, NAME + LEVEL, thin bar, value line
local function rowShell(name: string, order: number, icon: string, iconColor: Color3, sideW: number, stripe: Color3?)
	local h = if Menu.isTouch() then 92 else 86
	local f = Menu.surface(panel.Body, { Name = name, Size = UDim2.new(1, 0, 0, h), LayoutOrder = order }, stripe)
	local w = Menu.iconWell(f, icon, iconColor, 62)
	w.Position = UDim2.new(0, 12, 0.5, -31)
	local mid = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(88, 0), Size = UDim2.new(1, -(88 + sideW + 24), 1, 0), Parent = f })
	local top = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 9), Size = UDim2.new(1, 0, 0, 26), Parent = mid })
	local title = UI.new("TextLabel", { Font = S.FontHeavy, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, -92, 1, 0), Parent = top })
	-- level as a dark pill on the right of the name
	local level = UI.new("TextLabel", { Font = S.FontHeavy, TextSize = Menu.size("Small"), TextColor3 = S.Text, BackgroundColor3 = S.Header, BackgroundTransparency = 0, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(86, 24), Parent = top })
	UI.corner(level, 12)
	local holder = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 12), Parent = mid })
	local _, setBar = Menu.bar(holder, 12, S.Accent)
	local value = UI.new("TextLabel", { RichText = true, Font = S.FontHeavy, TextSize = Menu.size("Body"), TextColor3 = S.Dim, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(0, 57), Size = UDim2.new(1, 0, 0, 20), Parent = mid })
	return f, title, level, setBar, value
end

local function buildRow(u: UpgradeConfig.Upgrade)
	local buyW = if UI.Mode == "phone" then 118 else 144
	local f, title, level, setBar, nextLabel = rowShell("Row_" .. u.Id, u.Order + 10, ICON_FOR[u.Id] or "tag", S.Accent, buyW, nil)
	title.Text = string.upper(u.DisplayName)
	local buy = Menu.button({
		Name = "Buy",
		Text = "",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(buyW, 54),
		TextSize = 20,
		Parent = f,
	}, function()
		if busy then
			return
		end
		busy = true
		local ok, msg = Net.Function("BuyUpgrade"):InvokeServer(u.Id)
		busy = false
		if ok then
			-- purchase pop: the card flashes amber and bumps once, then refresh() repaints its frame
			local stroke = f:FindFirstChildOfClass("UIStroke") :: UIStroke
			stroke.Color = S.Accent
			local sc = f:FindFirstChildOfClass("UIScale") or UI.new("UIScale", { Parent = f })
			sc.Scale = 1.03
			UI.tween(sc, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
			task.delay(0.35, function()
				refresh()
			end)
		else
			Notify.Show("Error", tostring(msg))
		end
	end)
	rows[u.Id] = { frame = f, level = level, next = nextLabel, bar = setBar, buy = buy }
end

-- Strength / Speed: trained at the yard, so these rows show progress but have no buy button.
local function buildTrainRow(statId: string, order: number)
	local def = TrainingConfig.Stats[statId]
	local tagW = if UI.Mode == "phone" then 92 else 118
	local f, title, level, setBar, effect = rowShell("Train_" .. statId, order, def.Icon, STEEL, tagW, nil)
	title.Text = string.upper(def.DisplayName)
	local tag = Menu.tag(f, "AT TRAINING YARD", S.Header, S.Dim, 0)
	tag.Font = S.FontHeavy
	tag.AnchorPoint = Vector2.new(1, 0.5)
	tag.Position = UDim2.new(1, -12, 0.5, 0)
	tag.AutomaticSize = Enum.AutomaticSize.None
	tag.Size = UDim2.fromOffset(tagW, 44)
	tag.TextWrapped = true
	tag.TextSize = Menu.size("Small") - 1
	trainRows[statId] = { level = level, effect = effect, bar = setBar }
end

local function build(): Frame
	panel = Menu.panel("Upgrades", "Site Equipment", { Icon = "hammer", Wide = true })
	UI.list(panel.Body, 8)
	Menu.section(panel.Body, "Training", 1, "earned at the Training Yard")
	buildTrainRow("Strength", 2)
	buildTrainRow("Speed", 3)
	Menu.section(panel.Body, "Upgrades", 9, "bought with Coins")
	for _, u in ROW_ORDER do
		buildRow(u)
	end
	return panel.Frame
end

function UpgradePanel.Start()
	for _, u in UpgradeConfig.Upgrades do
		table.insert(ROW_ORDER, u)
	end
	table.sort(ROW_ORDER, function(a, b)
		return a.Order < b.Order
	end)
	UI.registerPanel("Upgrades", build, refresh)
	local function onChange()
		if UI.isOpen("Upgrades") or not panel then
			refresh()
		else
			HUD.SetBadge("Upgrades", anyAffordable())
		end
	end
	State.DataChanged:Connect(onChange)
	player:GetAttributeChangedSignal("Coins"):Connect(onChange)
	UI.ModeChanged:Connect(function()
		-- rebuild rows on the next open so touch sizes / widths match the new layout
		if panel then
			if UI.isOpen("Upgrades") then
				UI.closePanel()
			end
			panel.Frame:Destroy()
			panel = nil
			table.clear(rows)
			table.clear(trainRows)
			UI.registerPanel("Upgrades", build, refresh)
		end
	end)
end

return UpgradePanel
