--!nonstrict
-- DEVELOPER ADMIN PANEL (client). Cosmetic only: every button sends (action, args) to the server's "AdminRequest"
-- function, which re-checks authorization (UserId) and validates everything. The panel is built only after the server
-- answers "Open" with ok, so normal players never get a UI (and invoking the remote by hand is rejected server-side).
-- Toggle with F4 or the small ADMIN button.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local UI = require(script.Parent.Parent.ClientLib.UI)

local AdminPanelController = {}
local T = UI.Theme

local TABS = { "Builds", "Server", "Mutations", "Events", "Player", "Teleport", "Profile" }

local catalog, gui, window, content, status, header
local tabPages = {}
local selected = { Build = nil, Variant = "Random", Tier = "Golden", Resource = "Auto", Vehicle = "None", Worker = "Builder", Project = nil, Stat = "Strength" }
local busy = false

local function call(action, args)
	if busy then
		return nil
	end
	busy = true
	local ok, res = pcall(function()
		return Net.Function("AdminRequest"):InvokeServer(action, args or {})
	end)
	busy = false
	if not ok or type(res) ~= "table" then
		return { ok = false, msg = "Request failed" }
	end
	return res
end

local function showSnapshot(s)
	if not s or not header then
		return
	end
	local build = if s.BuildId ~= "" then string.format("%s [%s] stage %d/%d  %d%%", s.BuildTitle ~= "" and s.BuildTitle or s.BuildId, s.Rarity, math.min(s.Stage + 1, math.max(s.StageCount, 1)), s.StageCount, math.floor(s.Progress * 100)) else "no build (" .. tostring(s.Phase) .. ")"
	header.Text = string.format("%s\nLuck %.0f  |  Builds done %d  |  Event: %s  |  Coins %d  |  Str %d  Spd %d  MB %d%s", build, s.Luck, s.BuildsCompleted, s.Event ~= "" and s.Event or "-", s.Coins, s.Strength, s.Speed, s.MasterRank, s.ForcedProject ~= "" and ("  |  forced: " .. s.ForcedProject) or "")
end

local function run(action, args)
	local res = call(action, args)
	if not res then
		return
	end
	status.Text = (if res.ok then "OK: " else "ERROR: ") .. tostring(res.msg)
	status.TextColor3 = if res.ok then T.Good else T.Bad
	if res.data and res.data.Snapshot then
		showSnapshot(res.data.Snapshot)
	end
end

-- ---------------------------------------------------------------- widgets
local function newPage(name)
	local page = UI.new("ScrollingFrame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Visible = false,
		Parent = content,
	})
	UI.list(page, 6)
	UI.padding(page, 4)
	tabPages[name] = page
	return page
end

local function label(page, text)
	local l = UI.new("TextLabel", { Text = text, Font = T.Bold, TextSize = 15, TextColor3 = T.Accent, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -8, 0, 20), Parent = page })
	return l
end

local function row(page)
	local f = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = page })
	UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(126, 30), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = f })
	return f
end

local function btn(parent, text, color, fn)
	local b = UI.button({ Text = text, TextSize = 13, BackgroundColor3 = color or T.PanelLight, Size = UDim2.fromOffset(126, 30) }, fn)
	b.Parent = parent
	return b
end

-- one-of selector: a row of toggle buttons; the chosen one is highlighted
local function selector(page, title, options, key, onPick)
	label(page, title)
	local r = row(page)
	local buttons = {}
	local function paint()
		for opt, b in buttons do
			UI.setButtonColor(b, if selected[key] == opt then T.Blue else T.PanelLight)
		end
	end
	for _, o in options do
		local id = if type(o) == "table" then o.Id else o
		local name = if type(o) == "table" then (o.Name or o.Id) else o
		buttons[id] = btn(r, name, nil, function()
			selected[key] = id
			paint()
			if onPick then
				onPick(id)
			end
		end)
	end
	paint()
	return paint
end

local function numberBox(page, title, default, actionLabel, fn, color)
	local r = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 30), Parent = page })
	UI.list(r, 6, true)
	UI.new("TextLabel", { Text = title, Font = T.Bold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(120, 30), Parent = r })
	local box = UI.new("TextBox", { Text = tostring(default), ClearTextOnFocus = false, Font = T.Body, TextSize = 14, BackgroundTransparency = 0, BackgroundColor3 = T.Blueprint, Size = UDim2.fromOffset(110, 30), Parent = r })
	UI.corner(box, 5)
	local b = UI.button({ Text = actionLabel, TextSize = 13, BackgroundColor3 = color or T.Accent, TextColor3 = T.Stroke, Size = UDim2.fromOffset(110, 30) }, function()
		local n = tonumber(box.Text)
		if n then
			fn(n)
		else
			status.Text = "ERROR: enter a number"
			status.TextColor3 = T.Bad
		end
	end)
	b.Parent = r
	return box
end

-- confirmation overlay for dangerous actions
local function confirm(text, onYes)
	local shade = UI.new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), ZIndex = 50, Active = true, Parent = window })
	local card = UI.card({ Size = UDim2.fromOffset(340, 130), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 51, Parent = shade })
	UI.new("TextLabel", { Text = text, TextWrapped = true, Font = T.Bold, TextSize = 15, Size = UDim2.new(1, -20, 0, 70), Position = UDim2.fromOffset(10, 8), ZIndex = 52, Parent = card })
	local yes = UI.button({ Text = "CONFIRM", TextSize = 14, BackgroundColor3 = T.Bad, Size = UDim2.fromOffset(140, 32), Position = UDim2.fromOffset(16, 88), ZIndex = 52 }, function()
		shade:Destroy()
		onYes()
	end)
	yes.Parent = card
	local no = UI.button({ Text = "Cancel", TextSize = 14, BackgroundColor3 = T.PanelLight, Size = UDim2.fromOffset(140, 32), Position = UDim2.fromOffset(184, 88), ZIndex = 52 }, function()
		shade:Destroy()
	end)
	no.Parent = card
end

-- ---------------------------------------------------------------- tabs
local function buildTabs()
	-- BUILDS
	local p = newPage("Builds")
	selected.Build = catalog.Builds[1] and catalog.Builds[1].Id
	local opts = {}
	for _, b in catalog.Builds do
		table.insert(opts, { Id = b.Id, Name = b.Name })
	end
	selector(p, "Build", opts, "Build")
	selector(p, "Variant (modifier)", catalog.Variants, "Variant")
	label(p, "Actions")
	local r = row(p)
	btn(r, "Start Build", T.Good, function() run("Builds.Start", { Id = selected.Build, Variant = selected.Variant }) end)
	btn(r, "Force Next Build", T.Blue, function() run("Builds.ForceNext", { Id = selected.Build, Variant = selected.Variant }) end)
	btn(r, "+10% progress", nil, function() run("Builds.Progress", { Percent = 10 }) end)
	btn(r, "+25% progress", nil, function() run("Builds.Progress", { Percent = 25 }) end)
	btn(r, "Complete Build", T.Warn, function()
		confirm("Complete the current build now?", function() run("Builds.Complete") end)
	end)
	btn(r, "Reset Build", T.Bad, function()
		confirm("Reset the current build? Progress is lost.", function() run("Builds.Reset") end)
	end)
	numberBox(p, "Set stage (1-n)", 2, "Set Stage", function(n) run("Builds.SetStage", { Stage = n }) end)

	-- SERVER
	p = newPage("Server")
	numberBox(p, "Server Luck 0-100", 50, "Set Luck", function(n) run("Server.SetLuck", { Value = n }) end)
	local r2 = row(p)
	btn(r2, "Luck +10", nil, function() run("Server.AddLuck", { Delta = 10 }) end)
	btn(r2, "Luck -10", nil, function() run("Server.AddLuck", { Delta = -10 }) end)
	numberBox(p, "Completed builds", 0, "Set Count", function(n) run("Server.SetBuildCount", { Count = n }) end)
	label(p, "Selection")
	local r3 = row(p)
	btn(r3, "Normal Selection", T.Good, function() run("Server.NormalSelection") end)
	selected.Project = catalog.Projects[1]
	btn(r3, "Master Project", T.Warn, function()
		confirm("Force the next build to be the Master Project?", function() run("Server.MasterProject", { Id = selected.Project }) end)
	end)

	-- MUTATIONS
	p = newPage("Mutations")
	selector(p, "Tier", catalog.MutationTiers, "Tier")
	selector(p, "Resource", catalog.MutationResources, "Resource")
	local r4 = row(p)
	btn(r4, "Spawn Mutation", T.Good, function() run("Mutation.Spawn", { Tier = selected.Tier, Resource = selected.Resource }) end)
	btn(r4, "Clear Mutations", T.Bad, function() run("Mutation.Clear") end)
	label(p, "Quick")
	local r5 = row(p)
	for _, t in catalog.MutationTiers do
		btn(r5, "Trigger " .. t, T.Accent, function() run("Mutation.Spawn", { Tier = t, Resource = selected.Resource }) end)
	end
	btn(r5, "Resource Rush", T.Blue, function() run("Event.Trigger", { Id = "ResourceRush" }) end)

	-- EVENTS
	p = newPage("Events")
	local r6 = row(p)
	for _, e in catalog.Events do
		btn(r6, e.Name, Color3.fromRGB(150, 90, 220), function() run("Event.Trigger", { Id = e.Id }) end)
	end
	btn(r6, "End Active Event", T.Bad, function() run("Event.Stop") end)

	-- PLAYER
	p = newPage("Player")
	numberBox(p, "Coins", 1000, "Add Coins", function(n) run("Player.AddCoins", { Amount = n }) end)
	numberBox(p, "Coins", 0, "Set Coins", function(n) run("Player.SetCoins", { Amount = n }) end, T.Blue)
	selector(p, "Stat", catalog.Stats, "Stat")
	numberBox(p, "Level", 10, "Set Level", function(n) run("Player.SetTrainingLevel", { Stat = selected.Stat, Level = n }) end)
	numberBox(p, "XP", 500, "Add XP", function(n) run("Player.AddTrainingXP", { Stat = selected.Stat, Points = n }) end)
	numberBox(p, "Master rank 0-10", 1, "Set Rank", function(n) run("Player.SetMasterRank", { Rank = n }) end)
	selector(p, "Vehicle", catalog.Vehicles, "Vehicle")
	local r7 = row(p)
	btn(r7, "Equip Vehicle", T.Good, function() run("Player.EquipVehicle", { Id = selected.Vehicle }) end)
	btn(r7, "Unlock Vehicles", nil, function() run("Player.GrantVehicles") end)
	selector(p, "Worker type", catalog.WorkerTypes, "Worker")
	local r8 = row(p)
	btn(r8, "Grant Worker", T.Good, function() run("Player.GrantWorker", { Type = selected.Worker }) end)
	btn(r8, "Dismiss Worker", nil, function() run("Player.DismissWorker") end)

	-- TELEPORT
	p = newPage("Teleport")
	local r9 = row(p)
	for _, t in catalog.Teleports do
		btn(r9, t.Label, T.Blue, function() run("Teleport.To", { Id = t.Id }) end)
	end

	-- PROFILE
	p = newPage("Profile")
	label(p, "Own profile only")
	local r10 = row(p)
	btn(r10, "Reset Test Profile", T.Bad, function()
		confirm("RESET your test profile? Coins, upgrades, index, training and rank are wiped.", function()
			run("Profile.Reset", { Confirm = catalog.ResetToken })
		end)
	end)
	btn(r10, "Reset Temp State", T.Warn, function() run("Profile.ResetTemp") end)
	local opts2 = {}
	for _, b in catalog.Builds do
		table.insert(opts2, { Id = b.Id, Name = b.Name })
	end
	selector(p, "Unlock Build Index entry", opts2, "Build")
	local r11 = row(p)
	btn(r11, "Unlock Selected", T.Good, function() run("Profile.UnlockIndex", { Id = selected.Build }) end)
end

local function showTab(name)
	for n, page in tabPages do
		page.Visible = n == name
	end
end

local function buildWindow()
	gui = UI.root("Admin", 90)
	window = UI.card({ Name = "AdminWindow", Size = UDim2.fromOffset(600, 470), Position = UDim2.new(0, 16, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Visible = false, Parent = gui })
	UI.new("TextLabel", { Text = "ADMIN PANEL (F4)", Font = T.Title, TextSize = 16, TextColor3 = T.Accent, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 20), Parent = window })
	header = UI.new("TextLabel", { Text = "", Font = Enum.Font.Code, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 32), Parent = window })
	local tabs = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 62), Size = UDim2.new(1, -16, 0, 28), Parent = window })
	UI.list(tabs, 4, true)
	local tabButtons = {}
	for _, name in TABS do
		tabButtons[name] = UI.button({ Text = name, TextSize = 13, BackgroundColor3 = T.PanelLight, Size = UDim2.fromOffset(78, 28) }, function()
			showTab(name)
			for n, b in tabButtons do
				UI.setButtonColor(b, if n == name then T.Accent else T.PanelLight)
			end
		end)
		tabButtons[name].Parent = tabs
	end
	content = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 96), Size = UDim2.new(1, -16, 1, -134), ClipsDescendants = true, Parent = window })
	status = UI.new("TextLabel", { Text = "Ready", Font = T.Bold, TextSize = 13, TextColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Position = UDim2.new(0, 10, 1, -34), Size = UDim2.new(1, -20, 0, 30), Parent = window })
	buildTabs()
	showTab("Builds")
	UI.setButtonColor(tabButtons.Builds, T.Accent)
end

local function toggle()
	if not window then
		return
	end
	window.Visible = not window.Visible
	if window.Visible then
		local res = call("Snapshot")
		if res and res.ok then
			showSnapshot(res.data.Snapshot)
		end
	end
end

function AdminPanelController.Start()
	local res = call("Open")
	if not res or not res.ok then
		return -- not an admin: no UI, no hotkey, nothing to find
	end
	catalog = res.data.Catalog
	buildWindow()
	showSnapshot(res.data.Snapshot)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.F4 then
			toggle()
		end
	end)
	-- developer launcher: neutral dark steel with a thin dev-grey edge (never a rarity colour, Bible §16)
	local open = UI.button({ Text = "ADMIN", TextSize = 14, Font = UI.Type.Bold, BackgroundColor3 = UI.Tokens.PlateDeep, TextColor3 = UI.Tokens.InkFaint, Size = UDim2.fromOffset(64, 22), Position = UDim2.new(0, 8, 1, -28) }, toggle)
	UI.new("Frame", { Name = "DevEdge", BackgroundColor3 = UI.Tokens.Dev, BackgroundTransparency = 0, Size = UDim2.new(0, 3, 1, 0), Parent = open })
	open.Parent = gui
	task.spawn(function()
		while true do
			task.wait(3)
			if window.Visible and not busy then
				local r = call("Snapshot")
				if r and r.ok then
					showSnapshot(r.data.Snapshot)
				end
			end
		end
	end)
end

return AdminPanelController
