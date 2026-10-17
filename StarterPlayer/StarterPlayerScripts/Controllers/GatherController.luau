--!strict
-- Gathering feel: sets each resource prompt's LOCAL hold time from the player's Gather
-- Speed (and Resource Rush), and plays pickup/deposit feedback. The server still
-- enforces gather timing, so shortening the prompt locally can't cheat.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local ResourceSpotConfig = require(Shared.Config.ResourceSpotConfig)
local SecretResourceConfig = require(Shared.Config.SecretResourceConfig)
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local EventConfig = require(Shared.Config.EventConfig)
local Lib = script.Parent.Parent.ClientLib
local UI = require(Lib.UI)
local Sound = require(Lib.Sound)
local State = require(Lib.State)
local Cine = require(Lib.Cine)
local Notify = require(script.Parent.NotifyController)

local GatherController = {}
local player = Players.LocalPlayer

local function gatherSpeedFor(resId: string): number
	local level = State.Data and State.Data.Upgrades and State.Data.Upgrades.GatherSpeed or 0
	local speed = UpgradeConfig.Value("GatherSpeed", level)
	if State.Get("EventId") == "ResourceRush" and State.Get("EventParam") == resId then
		speed *= EventConfig.Events.ResourceRush.Params.SpeedMultiplier
	end
	return speed
end

local function updatePrompts()
	for _, node in CollectionService:GetTagged("ResourceNode") do
		local prompt = node:FindFirstChild("GatherPrompt") :: ProximityPrompt?
		local res = ResourceConfig.Resources[node:GetAttribute("ResourceId") or ""]
		if prompt and res then
			local spot = ResourceSpotConfig.Get(node:GetAttribute("SpotId"))
			prompt.HoldDuration = res.GatherTime / (gatherSpeedFor(res.Id) * (if spot then spot.GatherSpeedMultiplier else 1))
			-- PERSONAL secret resources: until YOU unlock them the node reads as an unknown material (the server refuses the gather)
			local secret = node:GetAttribute("SecretId")
			if secret then
				local ok = SecretResourceConfig.CanAccess(secret :: string, State.Data)
				prompt.ActionText = if ok then "Gather" else "Unknown material"
				prompt.ObjectText = if ok then res.DisplayName else "???"
			end
		end
	end
end

local function floatText(worldPos: Vector3, text: string, color: Color3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = worldPos
	local g = Instance.new("BillboardGui")
	g.Size = UDim2.fromOffset(160, 40)
	g.AlwaysOnTop = true
	g.Adornee = anchor
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = color
	l.TextStrokeTransparency = 0
	l.Text = text
	l.Parent = g
	g.Parent = anchor
	anchor.Parent = workspace
	UI.tween(anchor, 0.9, { Position = worldPos + Vector3.new(0, 5, 0) })
	UI.tween(l, 0.9, { TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.95, function()
		anchor:Destroy()
	end)
end

local function flyBlock(from: Vector3, res: any)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end
	local p = Instance.new("Part")
	p.Size = res.StackBlockSize
	p.Color = res.Color
	p.Material = res.Material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CFrame = CFrame.new(from)
	p.Parent = workspace
	UI.tween(p, 0.35, { CFrame = hrp.CFrame * CFrame.new(0, 1, 1), Size = res.StackBlockSize * 0.5 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.36, function()
		p:Destroy()
	end)
end

-- material feedback per pickup: a short burst + one quiet hit, never flashy (secret materials get a richer accent)
local FAMILY_FX = { Wood = { "Wood", "GatherWood" }, Stone = { "Stone", "GatherStone" }, Metal = { "Metal", "GatherMetal" }, PowerCell = { "Power", "GatherPower" } }
local MUT_FX = { Golden = "Gold", Diamond = "Diamond", Prismatic = "Prismatic" }
local function pickupFx(node: BasePart, res: any, mut: string?)
	local top = node.Position + Vector3.new(0, node.Size.Y / 2, 0)
	if res.Id == "StarMetal" then
		Cine.burst(top, "Cosmic", 0.8)
		Sound.Play("GatherCosmic", 0.06)
		Sound.Play("Chime", 0.1)
	elseif res.Id == "AncientTimber" then
		Cine.burst(top, "Ancient", 0.8)
		Sound.Play("GatherWood", 0.06)
		Sound.Play("ChimeLow", 0.1)
	else
		local fx = FAMILY_FX[res.Family] or FAMILY_FX.Wood
		Cine.burst(top, fx[1], 0.7)
		Sound.Play(fx[2], 0.08)
	end
	if mut and MUT_FX[mut] then
		Cine.burst(top, MUT_FX[mut], 0.45)
	end
end

local function nodeBump(node: BasePart)
	-- tiny local "chop" scale pulse on the node
	local original = node.Size
	if node:GetAttribute("_bumping") then
		return
	end
	node:SetAttribute("_bumping", true)
	UI.tween(node, 0.06, { Size = original * 1.06 })
	task.delay(0.07, function()
		UI.tween(node, 0.12, { Size = original })
		task.delay(0.13, function()
			node:SetAttribute("_bumping", nil)
		end)
	end)
end

function GatherController.Start()
	State.DataChanged:Connect(updatePrompts)
	State.Changed("EventId", updatePrompts)
	State.Changed("EventParam", updatePrompts)
	CollectionService:GetInstanceAddedSignal("ResourceNode"):Connect(function()
		task.defer(updatePrompts)
	end)
	task.delay(1, updatePrompts)

	local lastDepositFloat = 0
	Net.Event("Effect").OnClientEvent:Connect(function(id, payload)
		if id == "Gathered" then
			local res = ResourceConfig.Resources[payload.Res]
			local node = payload.Node :: BasePart?
			if res and node then
				Sound.Play("Pickup", 0.1, 0.5)
				if payload.Mut then
					Sound.Play("Chime", 0.05, 0.35, 1.3) -- a subtle premium layer on a mutated resource
				end
				pickupFx(node, res, payload.Mut)
				floatText(node.Position + Vector3.new(0, node.Size.Y / 2 + 2, 0), "+" .. payload.Amount .. " " .. res.DisplayName, res.Color:Lerp(Color3.new(1, 1, 1), 0.4))
				flyBlock(node.Position, res)
				nodeBump(node)
			end
		elseif id == "Full" then
			Sound.Play("Full")
			Sound.Play("Thud", 0.05, 0.9, 0.9)
			Notify.Show("Warn", "🎒 You're full! Carry it to the build site.", 2.5)
		elseif id == "Deposited" then
			-- heavier deliveries sound a little heavier: louder and lower, with a low thud layer for big drops
			local amt = tonumber(payload.Amount) or 1
			-- the material lands on the build: logs, rocks, steel or a power crackle (falls back to a wood thunk)
			local dres = ResourceConfig.Resources[payload.Res]
			local fam = dres and (dres.FamilyName or dres.Family) or ""
			local depName = if fam == "Wood" then "DepositWood" elseif fam == "Stone" then "DepositStone" elseif fam == "Metal" then "DepositMetal" elseif fam == "Power" or fam == "PowerCell" then "DepositPower" else "Deposit"
			Sound.Play(depName, 0.1, math.clamp(0.55 + amt / 70, 0.55, 1.1), math.clamp(1.1 - amt / 250, 0.8, 1.1))
			if amt >= 25 then
				Sound.Play("DepositHeavy", 0.05, math.clamp(amt / 80, 0.5, 1))
			end
			local t = os.clock()
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp and t - lastDepositFloat > 0.3 then
				lastDepositFloat = t
				local res = ResourceConfig.Resources[payload.Res]
				floatText(hrp.Position + Vector3.new(0, 4, 0), "+" .. payload.Amount .. " built!", if res then res.Color:Lerp(Color3.new(1, 1, 1), 0.5) else Color3.new(1, 1, 1))
			end
		elseif id == "UpgradeBought" then
			Sound.Play("Upgrade")
		end
	end)

	-- prompts that open UI panels (shop kiosks)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local panel = prompt:GetAttribute("OpensPanel")
		if type(panel) == "string" then
			UI.openPanel(panel)
		end
	end)
end

return GatherController
