--!strict
-- PROJECT COMPLETE — construction certificate (PRESENTATION_BIBLE §15). One plate docked in the LOWER THIRD so the finished
-- build and its spectacle stay visible above it:
--   PROJECT COMPLETE · rarity plate · BUILD NAME · crew line (builders, time, materials)   ← the server first
--   YOUR CONTRIBUTION (points, rank, share) · YOUR REWARD · Index status · Server Luck · MVP / Top 3 line   ← you second
-- Rarity changes only the frame weight (UI.rarityFrame), the entrance timing and the sound; never the layout.
-- After a few seconds it collapses to a slim strip (tap to re-expand) and it clears when the next phase starts.
-- While it is up, contextual HUD (cargo, objective) yields (UI.setMoment "Complete").
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local RarityConfig = require(Shared.Config.RarityConfig)
local ModifierConfig = require(Shared.Config.ModifierConfig)
local AchievementConfig = require(Shared.Config.AchievementConfig)
local Format = require(Shared.Util.Format)
local Lib = script.Parent.Parent.ClientLib
local UI = require(Lib.UI)
local Sound = require(Lib.Sound)
local State = require(Lib.State)
local Site = require(Lib.Site)
local Notify = require(script.Parent.NotifyController)

local CelebrationController = {}
local K = UI.Tokens
local TY = UI.Type
local MASTER_COLOR = Color3.fromRGB(120, 215, 255)

-- entrance delay after the completion signal: big projects let their spectacle open first
local ENTER_DELAY = { Common = 0.3, Uncommon = 0.4, Rare = 0.8, Epic = 1.4, Legendary = 2.6, Mythic = 3.2 }
-- how long the full certificate stays before collapsing to the slim strip
local HOLD = { Common = 7, Uncommon = 7, Rare = 8, Epic = 8, Legendary = 9, Mythic = 10 }

local root: Frame
local plate: Frame
local slim: TextButton
local headTag: TextLabel
local rarityHolder: Frame
local nameLabel: TextLabel
local crewLine: TextLabel
local yourValue: TextLabel
local yourSub: TextLabel
local rewardValue: TextLabel
local rewardIcon: Frame
local notesLine: TextLabel
local extraLine: TextLabel
local showToken = 0
local shown = false -- the certificate is part of the completion moment (visible unless a menu is open: never two windows)

local function applyVisible()
	if root then
		root.Visible = shown and UI.openName() == nil
	end
end
local pendingAchievements: { { id: string, t: number } } = {}

local function setCollapsed(collapsed: boolean)
	plate.Visible = not collapsed
	slim.Visible = collapsed
end

local function show(summary: any, mine: any)
	showToken += 1
	local my = showToken
	local rarityName = summary.Rarity or "Common"
	local r = RarityConfig.Get(rarityName)
	local master = summary.MasterProject == true
	local accent = if master then MASTER_COLOR else r.Color

	-- server first: rarity, name, crew line
	for _, c in rarityHolder:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	UI.rarityPlate(rarityHolder, if master then "MASTER PROJECT" else r.DisplayName, accent, TY.Label, 1)
	for i, id in summary.Modifiers or {} do
		local m = ModifierConfig.Modifiers[id]
		if m and i <= 2 then
			UI.chip(rarityHolder, m.DisplayName, m.Color, TY.Label, 1 + i)
		end
	end
	UI.rarityFrame(plate, if master then "Legendary" else rarityName, accent)
	nameLabel.Text = string.upper(summary.Title or "")
	crewLine.Text = string.format(
		"Built by %d builder%s in %s  ·  %s materials delivered",
		summary.Participants or 0,
		if (summary.Participants or 0) == 1 then "" else "s",
		Format.Time(summary.Seconds or 0),
		Format.Number(summary.TotalContribution or 0)
	)

	-- you second
	if mine.Eligible then
		yourValue.Text = string.format("%s pts  ·  #%d", Format.Number(mine.Points or 0), mine.Rank or 0)
		local bits = { string.format("%.0f%% of the project", (mine.Share or 0) * 100) }
		if mine.FriendBonus and mine.FriendBonus > 0 then
			table.insert(bits, string.format("crew bonus +%d%%", math.floor(mine.FriendBonus * 100 + 0.5)))
		end
		if mine.Lucky then
			table.insert(bits, "lucky bonus")
		end
		yourSub.Text = table.concat(bits, "  ·  ")
		rewardValue.Text = "+" .. Format.Number(mine.Coins or 0)
		rewardValue.TextColor3 = K.Amber
		rewardIcon.Visible = true
	else
		yourValue.Text = "You joined the crew"
		yourSub.Text = "Deliver materials next project to earn a share."
		rewardValue.Text = "—"
		rewardValue.TextColor3 = K.InkFaint
		rewardIcon.Visible = false
	end
	local notes = {}
	if mine.NewDiscovery then
		table.insert(notes, "NEW IN INDEX")
	end
	table.insert(notes, string.format("SERVER LUCK +%.0f%% → %d%%", summary.LuckGain or 0, math.floor(summary.ServerLuck or 0)))
	local top = summary.Top or {}
	if top[1] then
		local pod = { "MVP " .. tostring(top[1].n) }
		if top[2] then
			table.insert(pod, "2ND " .. tostring(top[2].n))
		end
		if top[3] then
			table.insert(pod, "3RD " .. tostring(top[3].n))
		end
		table.insert(notes, table.concat(pod, "  "))
	end
	notesLine.Text = table.concat(notes, "   ·   ")
	notesLine.TextColor3 = if mine.NewDiscovery then K.Power else K.InkDim
	-- achievements earned in this completion (folded in, never a separate popup)
	local extra = {}
	local now = os.clock()
	for _, a in pendingAchievements do
		if now - a.t < 8 then
			local def = AchievementConfig.Achievements[a.id]
			if def then
				table.insert(extra, string.format("CERTIFIED: %s", string.upper(def.DisplayName)))
			end
		end
	end
	extraLine.Text = table.concat(extra, "   ·   ")
	extraLine.Visible = #extra > 0

	slim.Text = string.format("%s COMPLETE  ·  %s", string.upper(summary.Title or ""), if mine.Eligible then "+" .. Format.Number(mine.Coins or 0) .. " coins" else "thanks, crew")

	-- entrance: wait for the spectacle to open (scaled by rarity), then rise in from below; Epic+ snap the frame
	local delayFor = if master then 3.2 else (ENTER_DELAY[rarityName] or 0.5)
	task.delay(delayFor, function()
		if showToken ~= my or State.Get("Phase") ~= "Complete" then
			return
		end
		Sound.Play("RewardClaim")
		-- the result arrives in a short sequence: crew line, your result, the reward (counting up), then notes
		local steps = { { crewLine }, { yourValue, yourSub }, { rewardValue }, { notesLine, extraLine } }
		for i, grp in steps do
			for _, l in grp do
				l.TextTransparency = 1
			end
			task.delay((i - 1) * 0.2, function()
				if showToken ~= my then
					return
				end
				for _, l in grp do
					UI.tween(l, UI.Anim.Normal, { TextTransparency = 0 })
				end
			end)
		end
		local target = tonumber(mine.Coins) or 0
		if mine.Eligible and target > 1 then
			task.spawn(function()
				task.wait(0.4)
				local t0 = os.clock()
				while os.clock() - t0 < 0.4 and showToken == my do
					local k = (os.clock() - t0) / 0.4
					rewardValue.Text = "+" .. Format.Number(math.floor(target * (1 - (1 - k) ^ 2)))
					task.wait()
				end
				if showToken == my then
					rewardValue.Text = "+" .. Format.Number(target)
				end
			end)
		end
		shown = true
		applyVisible()
		setCollapsed(false)
		root.Position = UDim2.new(0.5, 0, 1, -UI.Space.Margin + 24)
		plate.BackgroundTransparency = 1
		UI.tween(root, UI.Anim.Slow, { Position = UDim2.new(0.5, 0, 1, -UI.Space.Margin) })
		UI.tween(plate, UI.Anim.Slow, { BackgroundTransparency = 0.04 })
		local level = UI.rarityLevel(rarityName)
		local deco = plate:FindFirstChild("RarityFrame")
		if deco and level >= 4 then
			local sc = UI.new("UIScale", { Scale = 1.04, Parent = deco })
			UI.tween(sc, UI.Anim.Normal, { Scale = 1 })
		end
		task.delay(if master then 10 else (HOLD[rarityName] or 8), function()
			if showToken == my and shown then
				setCollapsed(true)
			end
		end)
	end)
end

function CelebrationController.Start()
	local g = UI.root("Celebration", 7)
	root = UI.new("Frame", {
		Name = "Certificate",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -UI.Space.Margin),
		Size = UDim2.new(0.94, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = g,
	})
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(640, 400)
	limit.Parent = root
	UI.list(root, 0, false, Enum.HorizontalAlignment.Center)

	-- collapsed state: one slim strip
	slim = UI.button({
		Text = "",
		TextSize = TY.Body,
		BackgroundColor3 = K.Plate,
		Size = UDim2.new(1, 0, 0, 40),
		Visible = false,
		LayoutOrder = 1,
		Parent = root,
	}, function()
		setCollapsed(false)
		local my = showToken
		task.delay(7, function()
			if showToken == my and shown then
				setCollapsed(true)
			end
		end)
	end)
	slim.TextColor3 = K.Ink
	slim.Font = TY.Heavy

	-- the certificate plate
	plate = UI.card({ Name = "Plate", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = root })
	plate.ClipsDescendants = true
	Site.hazard(plate, 5)
	local body = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 5), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = plate })
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 12), Parent = body })
	UI.list(body, 3)
	UI.fitHeight(plate, body, 5)

	-- row 1: PROJECT COMPLETE + rarity plate (right)
	local row1 = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 1, Parent = body })
	headTag = UI.new("TextLabel", { Text = "PROJECT COMPLETE", Font = TY.Heavy, TextSize = TY.Label + 1, TextColor3 = K.Amber, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.5, 0, 1, 0), Parent = row1 })
	rarityHolder = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.5, 0, 1, 0), Parent = row1 })
	local rl = UI.list(rarityHolder, 5, true, Enum.HorizontalAlignment.Right)
	rl.VerticalAlignment = Enum.VerticalAlignment.Center
	-- row 2: BUILD NAME
	nameLabel = UI.new("TextLabel", { Font = TY.Heavy, TextScaled = true, TextColor3 = K.Ink, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 2, Parent = body })
	UI.new("UITextSizeConstraint", { MaxTextSize = 32, MinTextSize = 20, Parent = nameLabel })
	-- row 3: crew line (the server result)
	crewLine = UI.new("TextLabel", { Font = TY.Bold, TextSize = TY.Body, TextColor3 = K.InkDim, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = body })
	UI.new("Frame", { BackgroundColor3 = K.Rule, BackgroundTransparency = 0, Size = UDim2.new(1, 0, 0, 1), LayoutOrder = 4, Parent = body })

	-- row 4: YOUR CONTRIBUTION (left) | YOUR REWARD (right)
	local row4 = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 60), LayoutOrder = 5, Parent = body })
	UI.new("TextLabel", { Text = "YOUR CONTRIBUTION", Font = TY.Heavy, TextSize = TY.Label, TextColor3 = K.InkDim, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(0.62, 0, 0, 16), Parent = row4 })
	yourValue = UI.new("TextLabel", { Font = TY.Heavy, TextSize = TY.Title - 2, TextColor3 = K.Ink, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(0, 20), Size = UDim2.new(0.62, 0, 0, 22), Parent = row4 })
	yourSub = UI.new("TextLabel", { Font = TY.Bold, TextSize = TY.Label, TextColor3 = K.InkDim, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(0.62, 0, 0, 14), Parent = row4 })
	local rewardBox = UI.new("Frame", { BackgroundColor3 = K.PlateDeep, BackgroundTransparency = 0, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.36, 0, 0, 58), Parent = row4 })
	UI.corner(rewardBox, 12)
	UI.stroke(rewardBox, K.Amber, 2)
	UI.new("TextLabel", { Text = "YOUR REWARD", Font = TY.Heavy, TextSize = TY.Label, TextColor3 = K.InkDim, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(10, 3), Size = UDim2.new(1, -14, 0, 16), Parent = rewardBox })
	rewardIcon = Site.icon(rewardBox, "coin", K.Amber, 26)
	rewardIcon.Position = UDim2.fromOffset(10, 23)
	rewardValue = UI.new("TextLabel", { Font = TY.Heavy, TextSize = 30, TextColor3 = K.Amber, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(42, 20), Size = UDim2.new(1, -46, 0, 32), Parent = rewardBox })
	UI.textStroke(rewardValue, 2)

	-- row 5: Index status · Server Luck · MVP / Top 3 (one line), achievements under it
	notesLine = UI.new("TextLabel", { Font = TY.Heavy, TextSize = TY.Label, TextColor3 = K.InkDim, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 6, Parent = body })
	extraLine = UI.new("TextLabel", { Font = TY.Heavy, TextSize = TY.Label, TextColor3 = K.Good, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 7, Visible = false, Parent = body })
	local _ = headTag

	Net.Event("Celebration").OnClientEvent:Connect(function(summary, mine)
		show(summary, mine or {})
	end)
	-- Discovery arrives right before Celebration; the certificate shows it, here we only play the sound
	Net.Event("Discovery").OnClientEvent:Connect(function()
		Sound.Play("Discovery")
	end)
	-- achievements are folded into the certificate during a completion, toasted otherwise
	Net.Event("Effect").OnClientEvent:Connect(function(id, payload)
		if id ~= "Achievement" then
			return
		end
		local a = AchievementConfig.Achievements[payload.Id]
		if not a then
			return
		end
		Sound.Play("Discovery")
		if State.Get("Phase") == "Complete" then
			table.insert(pendingAchievements, { id = payload.Id, t = os.clock() })
		else
			Notify.Show("Success", string.format("Achievement: %s! Title \"%s\" unlocked", a.DisplayName, a.Title), 4)
		end
	end)
	State.Changed("Phase", function(phase)
		UI.setMoment("Complete", phase == "Complete")
		if phase ~= "Complete" then
			shown = false
			applyVisible()
			showToken += 1
			table.clear(pendingAchievements)
		end
	end)
	UI.PanelChanged:Connect(applyVisible)
	UI.setMoment("Complete", State.Get("Phase") == "Complete")
end

return CelebrationController
