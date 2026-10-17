--!strict
-- Contribution UI.
--  * Top-right card: compact Top 5 (pooled rows updated in place, no rebuild) + your own
--    row pinned underneath when you're outside the Top 5. "All standings" expands to a
--    scrolling list of everyone (rebuilt only while expanded and when data changes).
--  * Top-left pill: your points and rank.
--  * Only shown while a build is under construction; phones start with the card collapsed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Format = require(Shared.Util.Format)
local Lib = script.Parent.Parent.ClientLib
local UI = require(Lib.UI)
local State = require(Lib.State)
local HUD = require(script.Parent.HUDController)

local LeaderboardController = {}
local T = UI.Theme
local player = Players.LocalPlayer

type Entry = { u: number, p: number }
type RowUI = { frame: Frame, name: TextLabel, value: TextLabel }

local list: { Entry } = {}
local total = 0
local expanded = false
local collapsedPhone = false
local userToggled = false

local card: Frame
local topRows: { RowUI } = {}
local fullRows: { RowUI } = {}
local selfRow: RowUI
local fullFrame: ScrollingFrame
local toggle: TextButton
local toggleBtn: TextButton
local header: TextLabel
local pillLabel: TextLabel
local pill: Frame
local body: Frame
local MEDALS = { "🥇", "🥈", "🥉" }

local function nameFor(userId: number): string
	local p = Players:GetPlayerByUserId(userId)
	return p and p.DisplayName or "Builder"
end

local function makeRow(parent: Instance, order: number): RowUI
	local f = UI.new("Frame", { BackgroundColor3 = T.PanelLight, BackgroundTransparency = 0.4, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = order, Parent = parent })
	UI.corner(f, 6)
	local name = UI.new("TextLabel", {
		Font = T.Title,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(6, 0),
		Size = UDim2.new(1, -70, 1, 0),
		Parent = f,
	})
	UI.textStroke(name, 1)
	local value = UI.new("TextLabel", {
		Font = T.Bold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -66, 0, 0),
		Size = UDim2.fromOffset(60, 22),
		Parent = f,
	})
	UI.textStroke(value, 1)
	return { frame = f, name = name, value = value }
end

local function setRow(r: RowUI, rank: number, entry: Entry?)
	if not entry then
		r.frame.Visible = false
		return
	end
	local mine = entry.u == player.UserId
	r.frame.Visible = true
	r.frame.BackgroundColor3 = if mine then Color3.fromRGB(30, 62, 92) else T.PanelLight
	r.frame.BackgroundTransparency = if mine then 0.1 else 0.4
	r.name.Text = (MEDALS[rank] or ("#" .. rank)) .. " " .. (if mine then "You" else nameFor(entry.u))
	r.value.Text = Format.Short(entry.p)
end

local function redraw()
	local myRank, myEntry = nil, nil
	for i, e in list do
		if e.u == player.UserId then
			myRank, myEntry = i, e
		end
	end
	-- personal pill
	pillLabel.Text = if myRank then "#" .. myRank else "-"

	if expanded then
		for _, r in topRows do
			r.frame.Visible = false
		end
		selfRow.frame.Visible = false
		-- rows are pooled: the broadcast arrives every ~1.5 s and recreating up to 50 rows each time
		-- was the biggest UI instance churn
		local shown = {}
		local n = 0
		for i, e in list do
			n += 1
			local row = fullRows[n] or makeRow(fullFrame, n)
			fullRows[n] = row
			setRow(row, i, e)
			shown[e.u] = true
		end
		for _, p in Players:GetPlayers() do
			if not shown[p.UserId] then
				n += 1
				local row = fullRows[n] or makeRow(fullFrame, n)
				fullRows[n] = row
				setRow(row, n, { u = p.UserId, p = 0 })
			end
		end
		for i = n + 1, #fullRows do
			fullRows[i].frame.Visible = false
		end
	else
		for i, r in topRows do
			setRow(r, i, list[i])
		end
		if myRank and myRank > 5 then
			setRow(selfRow, myRank, myEntry)
		else
			selfRow.frame.Visible = false
		end
	end
	fullFrame.Visible = expanded
	toggle.Text = if expanded then "Show Top 5" else "All standings (" .. #Players:GetPlayers() .. ")"
	header.Text = "TOP BUILDERS"
end

local function updateVisibility()
	local phase = State.Get("Phase")
	local building = phase == "Building"
	-- SIMPLICITY: only a compact rank chip by default; click it to open Top Builders
	card.Visible = building and not collapsedPhone
	pill.Visible = building
	body.Visible = not collapsedPhone
end

function LeaderboardController.GetList(): ({ Entry }, number)
	return list, total
end

function LeaderboardController.Start()
	while not HUD.RightStack or not HUD.StatsColumn do
		task.wait()
	end
	pill, pillLabel = HUD.Pill(HUD.StatsColumn :: Frame, "trophy", Color3.fromRGB(96, 190, 230), 3)
	pillLabel.TextSize = 16

	card = UI.card({
		Name = "Leaderboard",
		Size = UDim2.fromOffset(222, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = HUD.RightStack,
	})
	UI.padding(card, 7)
	UI.list(card, 4)
	local headRow = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 1, Parent = card })
	header = UI.new("TextLabel", {
		Font = T.Title,
		TextSize = 16,
		TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -30, 1, 0),
		Parent = headRow,
	})
	UI.textStroke(header, 1.4)
	toggleBtn = UI.button({
		Text = "–",
		TextSize = 14,
		BackgroundColor3 = T.PanelLight,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(26, 22),
		Parent = headRow,
	}, function()
		userToggled = true
		collapsedPhone = true
		updateVisibility()
	end)
	body = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = card })
	UI.list(body, 3)
	local top = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = body })
	UI.list(top, 3)
	for i = 1, 5 do
		topRows[i] = makeRow(top, i)
		topRows[i].frame.Visible = false
	end
	selfRow = makeRow(body, 2)
	selfRow.frame.Visible = false
	fullFrame = UI.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 220),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		LayoutOrder = 3,
		Visible = false,
		Parent = body,
	})
	UI.list(fullFrame, 3)
	toggle = UI.button({
		Text = "All standings",
		TextSize = 13,
		BackgroundColor3 = T.PanelLight,
		Size = UDim2.new(1, 0, 0, 24),
		LayoutOrder = 4,
		Parent = body,
	}, function()
		expanded = not expanded
		redraw()
	end)

	local function applyMode()
		card.Size = UDim2.fromOffset(if UI.Mode == "phone" then 180 else 222, 0)
		if not userToggled then
			collapsedPhone = true
		end
		updateVisibility()
	end
	UI.ModeChanged:Connect(applyMode)
	collapsedPhone = true
	local rankButton = UI.new("TextButton", { Name = "RankButton", Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 10, Parent = pill })
	rankButton.Activated:Connect(function()
		userToggled = true
		collapsedPhone = not collapsedPhone
		updateVisibility()
	end)
	card.Size = UDim2.fromOffset(if UI.Mode == "phone" then 180 else 222, 0)

	Net.Event("Leaderboard").OnClientEvent:Connect(function(newList, newTotal)
		list = newList
		total = newTotal
		redraw()
	end)
	State.Changed("Phase", function(phase)
		if phase == "Reveal" or phase == "Intermission" then
			-- new round: standings reset (server sends an empty list on the next change)
			list = {}
			total = 0
			expanded = false
			redraw()
		end
		updateVisibility()
	end)
	redraw()
	updateVisibility()
end

return LeaderboardController
