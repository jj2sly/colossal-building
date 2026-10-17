--!strict
-- REWARDS menu (one rail button): the Daily reward calendar, the cosmetic Collection (equip trails, vehicle skins, carry
-- and delivery effects) and the persistent Leaderboards. Nothing here is permanently on screen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local DailyConfig = require(Shared.Config.DailyConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local GameConfig = require(Shared.Config.GameConfig)
local CosmeticConfig = require(Shared.Config.CosmeticConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local Format = require(Shared.Util.Format)
local Lib = script.Parent.Parent.ClientLib
local UI = require(Lib.UI)
local Menu = require(Lib.Menu)
local State = require(Lib.State)
local Notify = require(script.Parent.NotifyController)

local RewardsPanel = {}
local S = Menu.S
local player = Players.LocalPlayer

local panel: any
local refresh: () -> ()
local tabs: any
local content: Frame
local currentTab = "Daily"
local boards: { any }? = nil
local boardsAt = 0
local boardsLoading = false

local function clear()
	for _, c in content:GetChildren() do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
end

local function card(order: number): Frame
	local f = Menu.surface(content, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order })
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), Parent = f })
	UI.list(f, 6)
	return f
end

local function dataOrEmpty(): any
	return State.Data or { Daily = { LastClaimDay = 0, Claims = 0 }, Cosmetics = {}, Equipped = {} }
end

------------------------------------------------------------------ daily
local function hex(c: Color3): string
	return string.format("#%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function drawDaily()
	local d = dataOrEmpty()
	local daily = d.Daily or { LastClaimDay = 0, Claims = 0 }
	local today = DailyConfig.DayNumber()
	local canClaim = today > (daily.LastClaimDay or 0)
	local slot = DailyConfig.Slot(daily.Claims or 0)
	local reward = DailyConfig.Cycle[slot]
	-- AVAILABLE NOW (or CLAIMED + the NEXT reward): one strong card, one primary button
	local head = card(1)
	Menu.section(head, if canClaim then "Available now" else "Claimed today", 0, if canClaim then nil else "next reward unlocks 00:00 UTC")
	local big = UI.new("TextLabel", {
		Text = if canClaim then (reward and reward.Text or "") else ("NEXT   " .. (reward and reward.Text or "")),
		Font = S.FontHeavy,
		TextSize = Menu.size("H1"),
		TextColor3 = if canClaim then S.Accent else S.Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = head,
	})
	local _ = big
	Menu.button({ Text = if canClaim then "CLAIM" else "CLAIMED", Kind = if canClaim then "good" else "secondary", Enabled = canClaim, Size = UDim2.new(1, 0, 0, Menu.buttonHeight() + 4), LayoutOrder = 5, Parent = head }, function()
		local ok, res = Net.Function("DailyClaim"):InvokeServer()
		if not ok then
			Notify.Show("Error", tostring(res))
		end
	end).Font = S.FontHeavy
	local list = card(2)
	Menu.section(list, "7-day cycle", 0, "no streak: missing a day costs nothing")
	-- days finished in the current cycle (after a claim today, today's day counts as finished)
	local claims = daily.Claims or 0
	local completed = if canClaim then claims % #DailyConfig.Cycle else (if claims > 0 then (claims - 1) % #DailyConfig.Cycle + 1 else 0)
	for i, r in DailyConfig.Cycle do
		local done = i <= completed
		local current = i == slot and canClaim
		local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 10 + i, Parent = list })
		UI.new("TextLabel", { Text = "DAY " .. i, Font = S.FontHeavy, TextSize = Menu.size("Small"), TextColor3 = if done then S.Faint elseif current then S.Accent else S.Dim, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(58, 28), Parent = row })
		UI.new("TextLabel", {
			Text = r.Text,
			Font = if current then S.FontBold else S.Font,
			TextSize = Menu.size("Body"),
			TextColor3 = if done then S.Faint elseif current then S.Text else S.Dim,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(62, 0),
			Size = UDim2.new(1, -150, 1, 0),
			Parent = row,
		})
		if done or current then
			local t = Menu.stateTag(row, if done then "DONE" else "READY", 0)
			t.AnchorPoint = Vector2.new(1, 0.5)
			t.Position = UDim2.fromScale(1, 0.5)
		end
	end
end

------------------------------------------------------------------ collection
local function drawCollection()
	local d = dataOrEmpty()
	local order = 0
	for _, info in CosmeticConfig.Equippable do
		order += 1
		local c = card(order)
		Menu.section(c, info.Label, 0)
		local equipped = player:GetAttribute(info.Attribute)
		local ownedSet = (d.Cosmetics or {})[info.Category] or {}
		local function row(id: string?, name: string, desc: string, rarity: string?, owned: boolean, order2: number)
			local r = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Menu.buttonHeight() + 8), LayoutOrder = order2, Parent = c })
			UI.new("TextLabel", {
				Text = name,
				Font = S.FontBold,
				TextSize = Menu.size("Body"),
				TextColor3 = if owned then S.Text else S.Faint,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Size = UDim2.new(1, -120, 0, Menu.size("Body") + 4),
				Parent = r,
			})
			UI.new("TextLabel", {
				RichText = true, Text = (if rarity then string.format("<font color=\"%s\">%s</font>   ", hex(RarityConfig.Get(rarity).Color), string.upper(rarity)) else "") .. desc,
				Font = S.Font,
				TextSize = Menu.size("Small"),
				TextColor3 = S.Dim,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(0, Menu.size("Body") + 4),
				Size = UDim2.new(1, -120, 0, Menu.size("Small") + 4),
				Parent = r,
			})
			local on = (id == nil and equipped == nil) or (id ~= nil and equipped == id)
			local b = Menu.button({
				Text = if not owned then "LOCKED" elseif on then "EQUIPPED" else "EQUIP",
				Kind = if on then "good" else "secondary",
				Enabled = owned and not on,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.fromOffset(110, Menu.buttonHeight()),
				Parent = r,
			}, function()
				Net.Event("EquipCosmetic"):FireServer(info.Category, id or "")
			end)
			local _ = b
		end
		row(nil, "None", "No effect", nil, true, 0)
		local ids = {}
		for id in (CosmeticConfig.Catalog :: any)[info.Category] do
			table.insert(ids, id)
		end
		table.sort(ids, function(a, b)
			local ra = RarityConfig.Get(CosmeticConfig.Rarity(info.Category, a)).Order
			local rb = RarityConfig.Get(CosmeticConfig.Rarity(info.Category, b)).Order
			if ra ~= rb then
				return ra < rb
			end
			return a < b
		end)
		for i, id in ids do
			local e = CosmeticConfig.Get(info.Category, id) :: any
			row(id, e.Name, e.Description, e.Rarity, ownedSet[id] == true, i)
		end
	end
	local note = Menu.label(content, "Titles are equipped in the Build Index (Achievements). Worker outfits are chosen in the Worker menu.", "Small", S.Dim)
	note.LayoutOrder = 99
	note.TextWrapped = true
	note.TextTruncate = Enum.TextTruncate.None
	note.AutomaticSize = Enum.AutomaticSize.Y
end

------------------------------------------------------------------ boards
local drawBoards
local function loadBoards()
	if boardsLoading or (boards and os.clock() - boardsAt < 45) then
		return
	end
	boardsLoading = true
	task.spawn(function()
		local ok, res = pcall(function()
			return Net.Function("GetBoards"):InvokeServer()
		end)
		boardsLoading = false
		if ok and type(res) == "table" then
			boards = res
			boardsAt = os.clock()
		end
		if panel and UI.isOpen("Rewards") and currentTab == "Boards" then
			clear()
			drawBoards()
		end
	end)
end

function drawBoards()
	loadBoards()
	if not boards or #boards == 0 then
		local c = card(1)
		Menu.label(c, "Loading leaderboards...", "Body", S.Dim)
		return
	end
	for i, b in boards do
		local c = card(i)
		Menu.section(c, b.Title, 0)
		if not b.Global then
			Menu.label(c, "This server only (global boards need live servers)", "Small", S.Dim)
		end
		if #b.Entries == 0 then
			Menu.label(c, "No entries yet", "Small", S.Faint)
		end
		for rank, e in b.Entries do
			local mine = e.u == player.UserId
			local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Menu.size("Body") + 6), LayoutOrder = 10 + rank, Parent = c })
			UI.new("TextLabel", {
				Text = string.format("#%d   %s", rank, if mine then "You" else e.name),
				Font = if mine then S.FontBold else S.Font,
				TextSize = Menu.size("Body"),
				TextColor3 = if mine then S.Accent else S.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Size = UDim2.new(1, -90, 1, 0),
				Parent = row,
			})
			UI.new("TextLabel", {
				Text = Format.Short(e.v),
				Font = S.FontBold,
				TextSize = Menu.size("Body"),
				TextColor3 = S.Text,
				TextXAlignment = Enum.TextXAlignment.Right,
				Size = UDim2.new(1, 0, 1, 0),
				Parent = row,
			})
		end
	end
end

------------------------------------------------------------------ store
-- Everything here is optional. The server decides ownership; this only shows state and asks the server to start a purchase.
local storeCategory = "Passes"

local function fmtTime(seconds: number): string
	local m = math.ceil(seconds / 60)
	return if m >= 60 then string.format("%dh %02dm", m // 60, m % 60) else string.format("%d min", m)
end

local function buyButton(parent: Instance, order: number, kind: string, key: string, id: number, owned: boolean, label: string?)
	local dev = GameConfig.IsDev() and MonetizationConfig.DevSimulation
	local text, enabled, style
	if owned then
		text, enabled, style = "OWNED", false, "good"
	elseif id <= 0 and not dev then
		text, enabled, style = "COMING SOON", false, "secondary"
	elseif id <= 0 then
		text, enabled, style = "GET (DEV SIMULATION)", true, "secondary"
	else
		text, enabled, style = label or "GET", true, "primary"
	end
	Menu.button({ Text = text, Kind = style, Enabled = enabled, Size = UDim2.new(1, 0, 0, Menu.buttonHeight()), LayoutOrder = order, Parent = parent }, function()
		local ok, msg = Net.Function("StorePurchase"):InvokeServer(kind, key)
		if not ok then
			Notify.Show("Error", tostring(msg))
		elseif msg ~= "Opening checkout..." then
			Notify.Show("Info", tostring(msg))
		end
	end)
end

local function itemCard(order: number, name: string, desc: string, bullets: { string }?, status: string?): Frame
	local c = card(order)
	local head = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Menu.size("H2") + 4), LayoutOrder = 1, Parent = c })
	UI.new("TextLabel", { Text = string.upper(name), Font = S.FontBold, TextSize = Menu.size("H2"), TextColor3 = S.Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, -110, 1, 0), Parent = head })
	if status then
		UI.new("TextLabel", { Text = status, Font = S.FontBold, TextSize = Menu.size("Small"), TextColor3 = S.Good, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(1, 0, 1, 0), Parent = head })
	end
	local d = Menu.label(c, desc, "Small", S.Dim)
	d.LayoutOrder = 2
	d.TextWrapped = true
	d.TextTruncate = Enum.TextTruncate.None
	d.AutomaticSize = Enum.AutomaticSize.Y
	for i, b in bullets or {} do
		local l = Menu.label(c, "  " .. b, "Small", S.Text)
		l.LayoutOrder = 2 + i
	end
	return c
end

local function drawStore()
	local d = dataOrEmpty()
	local passes = d.Passes or {}
	local boosts = d.Boosts or {}
	-- category switcher
	local bar = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Menu.buttonHeight()), LayoutOrder = 0, Parent = content })
	UI.list(bar, 8, true)
	for i, cat in { "Passes", "Boosts", "Cosmetics" } do
		Menu.button({ Text = cat, Kind = if cat == storeCategory then "primary" else "secondary", Size = UDim2.new(1 / 3, -6, 1, 0), LayoutOrder = i, Parent = bar }, function()
			storeCategory = cat
			refresh()
		end)
	end
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	if GameConfig.IsDev() and MonetizationConfig.DevSimulation then
		local n = Menu.label(content, "DEV SIMULATION: products without a real Roblox id are simulated in Studio only.", "Small", S.Orange)
		n.LayoutOrder = nextOrder()
		n.TextWrapped = true
		n.TextTruncate = Enum.TextTruncate.None
		n.AutomaticSize = Enum.AutomaticSize.Y
	end
	if storeCategory == "Passes" or storeCategory == "Cosmetics" then
		for _, key in MonetizationConfig.PassOrder do
			local p = MonetizationConfig.Passes[key]
			if p.Category == storeCategory then
				local owned = passes[key] == true
				local c = itemCard(nextOrder(), p.Name, p.Description, p.Benefits, if owned then "OWNED" else nil)
				buyButton(c, 20, "Pass", key, p.PassId, owned)
			end
		end
	else
		local h = Menu.label(content, "PERSONAL BOOSTS (temporary, they never stack with themselves)", "Small", S.Dim, true)
		h.LayoutOrder = nextOrder()
		for _, key in MonetizationConfig.BoostOrder do
			local b = MonetizationConfig.Boosts[key]
			local rec = boosts[b.Kind]
			local left = if rec and rec.Until and rec.Until > os.time() then rec.Until - os.time() else 0
			local c = itemCard(nextOrder(), b.Name, string.format("%s %d min per purchase, up to %d min.", b.Description, b.Minutes, b.MaxMinutes), nil, if left > 0 then "ACTIVE " .. fmtTime(left) else nil)
			buyButton(c, 20, "Boost", key, b.ProductId, false, "GET")
		end
		local h2 = Menu.label(content, "SERVER-WIDE BOOSTS (everyone in the server benefits)", "Small", S.Dim, true)
		h2.LayoutOrder = nextOrder()
		for _, key in MonetizationConfig.ServerBoostOrder do
			local b = MonetizationConfig.ServerBoosts[key]
			local untilT = State.Get("SB_" .. key) or 0
			local left = if type(untilT) == "number" and untilT > os.time() then untilT - os.time() else 0
			local c = itemCard(nextOrder(), b.Name, string.format("%s %d min per purchase, up to %d min.", b.Description, b.Minutes, b.MaxMinutes), nil, if left > 0 then "ACTIVE " .. fmtTime(left) else nil)
			buyButton(c, 20, "ServerBoost", key, b.ProductId, false, "GET")
		end
	end
	local note = Menu.label(content, "Everything in Mega Build can be earned for free. Paid items are optional conveniences and cosmetics.", "Small", S.Faint)
	note.LayoutOrder = 99
	note.TextWrapped = true
	note.TextTruncate = Enum.TextTruncate.None
	note.AutomaticSize = Enum.AutomaticSize.Y
end

local DRAW = { Daily = drawDaily, Collection = drawCollection, Boards = drawBoards, Store = drawStore }

function refresh()
	if not panel then
		return
	end
	clear()
	DRAW[currentTab]()
end

local function build(): Frame
	panel = Menu.panel("Rewards", "Rewards", { Icon = "trophy" })
	tabs = Menu.tabs(panel.Frame, {
		{ Id = "Daily", Text = "Daily" },
		{ Id = "Collection", Text = "Collection" },
		{ Id = "Boards", Text = "Leaderboards" },
		{ Id = "Store", Text = "Store" },
	}, function(id)
		currentTab = id
		refresh()
		panel.Body.CanvasPosition = Vector2.zero
	end)
	tabs.Frame.Position = UDim2.fromOffset(0, panel.HeaderH)
	local tabH = tabs.Frame.Size.Y.Offset
	panel.Body.Position = UDim2.fromOffset(0, panel.HeaderH + tabH)
	panel.Body.Size = UDim2.new(1, 0, 1, -(panel.HeaderH + tabH))
	content = UI.new("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.new(1, -(2 * S.Pad + 6), 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = panel.Body })
	UI.list(content, 10)
	tabs.Select(currentTab)
	return panel.Frame
end

function RewardsPanel.Start()
	UI.registerPanel("Rewards", build, refresh, {
		OnBumper = function(dir: number)
			if tabs then
				tabs.Next(dir)
			end
		end,
	})
	State.DataChanged:Connect(function()
		if UI.isOpen("Rewards") and currentTab ~= "Boards" then
			refresh()
		end
	end)
	for _, info in CosmeticConfig.Equippable do
		player:GetAttributeChangedSignal(info.Attribute):Connect(function()
			if UI.isOpen("Rewards") and currentTab == "Collection" then
				refresh()
			end
		end)
	end
	task.spawn(function()
		while true do
			task.wait(15)
			if UI.isOpen("Rewards") and currentTab == "Store" then
				refresh()
			end
		end
	end)
	UI.PanelChanged:Connect(function(open)
		if open == "Rewards" then
			boards = nil
		end
	end)
	UI.ModeChanged:Connect(function()
		if panel then
			if UI.isOpen("Rewards") then
				UI.closePanel()
			end
			panel.Frame:Destroy()
			panel, tabs = nil, nil
			UI.registerPanel("Rewards", build, refresh)
		end
	end)
end

return RewardsPanel
