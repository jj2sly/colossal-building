--!strict
-- Developer panel (only for players the server flags IsDebugUser). Buttons just send
-- DebugCommand; DebugService validates and executes. Toggle with the Debug button or F2.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local BuildConfig = require(Shared.Config.BuildConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local EventConfig = require(Shared.Config.EventConfig)
local Lib = script.Parent.Parent.ClientLib
local UI = require(Lib.UI)
local HUD = require(script.Parent.HUDController)

local DebugController = {}
local T = UI.Theme
local player = Players.LocalPlayer

local reportLabel: TextLabel? = nil

local function send(cmd: string, arg: any?)
	Net.Event("DebugCommand"):FireServer(cmd, arg)
end

local function section(parent: Instance, title: string, order: number): Frame
	local l = UI.new("TextLabel", { Text = title, Font = T.Title, TextSize = 18, TextColor3 = T.Accent, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = order, Parent = parent })
	UI.textStroke(l, 1)
	local grid = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order + 1, Parent = parent })
	UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(140, 36), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	return grid
end

local function btn(parent: Instance, text: string, color: Color3?, fn: () -> ())
	UI.button({ Text = text, TextSize = 14, BackgroundColor3 = color or T.PanelLight }, fn).Parent = parent
end

local function build(): Frame
	local f, body = UI.panelShell("Debug", "🛠 DEBUG TOOLS", UDim2.fromOffset(640, 580))
	UI.list(body, 4)
	local g1 = section(body, "Round", 1)
	btn(g1, "Skip phase", T.Blue, function() send("SkipPhase") end)
	btn(g1, "+25% resources", T.Good, function() send("AddResources", 0.25) end)
	btn(g1, "Complete stage", T.Good, function() send("CompleteStage") end)
	btn(g1, "Complete build", T.Good, function() send("CompleteBuild") end)
	btn(g1, "Reset build", T.Bad, function() send("ResetBuild") end)
	btn(g1, "Fast timings", nil, function() send("ToggleFast") end)
	btn(g1, "Vote next", nil, function() send("SetMilestone", 99) end)
	btn(g1, "Fill my carry", nil, function() send("FillCarry") end)
	btn(g1, "Inspect state", T.Blue, function() send("Summary") end)
	local g2 = section(body, "Force build / rarity / modifier", 3)
	for _, def in BuildConfig.Eligible(nil, math.huge) do
		btn(g2, def.DisplayName, T.Blue, function() send("ForceBuild", def.Id) end)
	end
	for _, id in RarityConfig.Order do
		btn(g2, "Rarity: " .. id, RarityConfig.Tiers[id].Color:Lerp(Color3.new(0, 0, 0), 0.3), function() send("ForceRarity", id) end)
	end
	local ModifierConfig = require(Shared.Config.ModifierConfig)
	for _, m in ModifierConfig.Order do
		btn(g2, "Mod: " .. m, ModifierConfig.Modifiers[m].Color:Lerp(Color3.new(0, 0, 0), 0.3), function() send("ForceModifier", m) end)
	end
	btn(g2, "Mod: Golden+Giant", Color3.fromRGB(180, 140, 40), function() send("ForceModifier", "Both") end)
	btn(g2, "Mod: None", nil, function() send("ForceModifier", "None") end)
	local g3 = section(body, "Events & damage", 5)
	for id, def in EventConfig.Events do
		if def.Enabled then
			btn(g3, def.DisplayName, Color3.fromRGB(150, 90, 220), function() send("TriggerEvent", id) end)
		end
	end
	btn(g3, "Stop event", nil, function() send("StopEvent") end)
	btn(g3, "Damage section", T.Bad, function() send("DamageSection") end)
	btn(g3, "Repair all", T.Good, function() send("RepairAll") end)
	local g4 = section(body, "Player & server", 7)
	btn(g4, "+1,000 Coins", T.Accent, function() send("AddCoins", 1000) end)
	btn(g4, "+100k Coins", T.Accent, function() send("AddCoins", 100000) end)
	btn(g4, "Max upgrades", T.Good, function() send("MaxUpgrades") end)
	btn(g4, "Reset upgrades", nil, function() send("ResetUpgrades") end)
	btn(g4, "Luck 0%", nil, function() send("SetServerLuck", 0) end)
	btn(g4, "Luck 50%", nil, function() send("SetServerLuck", 50) end)
	btn(g4, "Luck 100%", nil, function() send("SetServerLuck", 100) end)
	btn(g4, "Friends: 3", nil, function() send("SetFriends", 3) end)
	btn(g4, "Friends: off", nil, function() send("SetFriends", -1) end)
	btn(g4, "Save now", nil, function() send("SaveNow") end)
	btn(g4, "Save+reload data", nil, function() send("ReloadData") end)
	btn(g4, "Reset my data", T.Bad, function() send("ResetData") end)
	-- balance telemetry (dev only): long reports arrive on DebugReport and show below
	local g5 = section(body, "Balance v0.1 telemetry", 9)
	btn(g5, "Session report", T.Blue, function() send("BalanceReport") end)
	btn(g5, "Model tables", T.Blue, function() send("ModelReport") end)
	btn(g5, "Rarity odds", T.Blue, function() send("SimulateRarity") end)
	btn(g5, "Reward table", T.Blue, function() send("RewardTable") end)
	btn(g5, "Spots", T.Blue, function() send("SpotInfo") end)
	btn(g5, "MB rank 1 check", T.Blue, function() send("SimulateMasterBuilder") end)
	btn(g5, "MB reset (forced)", nil, function() send("SimulateMasterBuilder", true) end)
	btn(g5, "Reset telemetry", nil, function() send("TelemetryReset") end)
	btn(g5, "Grant vehicles", nil, function() send("GrantVehicles") end)
	for _, v in { "None", "Wheelbarrow", "HandCart", "UtilityCart", "Pickup", "DumpTruck" } do
		btn(g5, "Equip " .. v, nil, function() send("EquipVehicle", v) end)
	end
	btn(g5, "Str lvl 10", nil, function() send("SetTrainingLevel", { Stat = "Strength", Level = 10 }) end)
	btn(g5, "Str lvl 25", nil, function() send("SetTrainingLevel", { Stat = "Strength", Level = 25 }) end)
	btn(g5, "Spd lvl 10", nil, function() send("SetTrainingLevel", { Stat = "Speed", Level = 10 }) end)
	btn(g5, "Spd lvl 25", nil, function() send("SetTrainingLevel", { Stat = "Speed", Level = 25 }) end)
	btn(g5, "Train 0/0", T.Bad, function()
		send("SetTrainingLevel", { Stat = "Strength", Level = 0 })
		send("SetTrainingLevel", { Stat = "Speed", Level = 0 })
	end)
	reportLabel = UI.new("TextLabel", {
		Name = "Report",
		Text = "(press a balance button)",
		Font = Enum.Font.Code,
		TextSize = 12,
		TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 99,
		Parent = body,
	})
	return f
end

function DebugController.Start()
	Net.Event("DebugReport").OnClientEvent:Connect(function(text)
		if reportLabel then
			reportLabel.Text = tostring(text)
		end
	end)
	local function setup()
		if not player:GetAttribute("IsDebugUser") then
			return
		end
		UI.registerPanel("Debug", build)
		-- DEV TOOL: reachable only for debug users through F2 (and the Admin panel). Never a button in the player rail.
		UserInputService.InputBegan:Connect(function(input, processed)
			if not processed and input.KeyCode == Enum.KeyCode.F2 then
				UI.togglePanel("Debug")
			end
		end)
	end
	if player:GetAttribute("IsDebugUser") then
		setup()
	else
		local conn
		conn = player:GetAttributeChangedSignal("IsDebugUser"):Connect(function()
			if player:GetAttribute("IsDebugUser") then
				conn:Disconnect()
				setup()
			end
		end)
	end
end

return DebugController
