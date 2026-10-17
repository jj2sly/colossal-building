--!strict
-- Automatic unloading at the build site. One server loop checks only players who are
-- carrying something (cheap even at 50 players). Inside the deposit ring, resources the
-- build still needs are unloaded at the player's Deposit Speed; the base rate already
-- empties a starter load in about half a second so it never feels like waiting.
-- Unneeded resources stay in the player's stack with a hint.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local GameConfig = require(Shared.Config.GameConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)

local DepositService = {}
local S: any

local BASE_RATE = 45 -- units/sec at Deposit Speed x1
local notNeededNotice: { [Player]: number } = {}

local lastFx: { [Player]: number } = {}

function DepositService.Init(registry)
	S = registry
end

function DepositService.InZone(position: Vector3): boolean
	local site = GameConfig.Site
	local flat = Vector3.new(position.X - site.Center.X, 0, position.Z - site.Center.Z)
	return flat.Magnitude <= site.DepositOuterRadius and position.Y < site.PlatformTopY + 40
end

local function tick(dt: number)
	if not S.BuildService.IsActive() then
		return
	end
	local needed = nil
	for _, player in Players:GetPlayers() do
		if (player:GetAttribute("CarryTotal") or 0) > 0 then
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp and DepositService.InZone(hrp.Position) then
				needed = needed or S.BuildService.Needed()
				-- a huge vehicle load never takes ages to unload: at least a full load every ~3 s, whatever the Deposit Speed level
				local cap = player:GetAttribute("CarryCap") or 0
				local rate = math.max(BASE_RATE * S.UpgradeService.Value(player, "DepositSpeed"), cap / 3) * S.EventService.DepositSpeedMultiplier()
				local budget = math.max(1, math.floor(rate * dt + 0.5))
				local deposited = 0
				local lastRes = nil
				local blocked = false
				local inv = S.ResourceService.GetCarry(player)
				for _, resId in ResourceConfig.Order do
					local have = inv[resId] or 0
					if have > 0 then
						-- a delivered grade can fill its own requirement and every lower grade of its family
						local keys = ResourceConfig.RequirementsFor(resId)
						local need = 0
						for _, k in keys do
							need += needed[k] or 0
						end
						if need > 0 and budget > 0 then
							local q = S.ResourceService.GetQuality(player, resId)
							local amount = math.min(have, budget, math.max(1, math.ceil(need / q)))
							local accepted = S.BuildService.Deposit(player, resId, amount, "Player")
							if accepted > 0 then
								S.ResourceService.Take(player, resId, accepted)
								local counted = accepted * q
								for _, k in keys do
									local t = math.min(needed[k] or 0, counted)
									needed[k] = (needed[k] or 0) - t
									counted -= t
								end
								budget -= accepted
								deposited += accepted
								lastRes = resId
							end
						elseif need <= 0 then
							-- the build doesn't need it, but mutated units still pay their Coins (the rest of the stack stays with you)
							local n, factor = S.ResourceService.TakeMutated(player, resId)
							if n > 0 then
								S.BuildService.PayUnits(player, resId, n, factor)
								deposited += n
								lastRes = resId
							end
							if have - n > 0 then
								blocked = true
							end
						end
					end
				end
				if deposited > 0 then
					if not player:GetAttribute("Driving") then
						S.TrainingService.NaturalDeliver(player, deposited) -- small Strength XP for hauling on foot
					end
					-- one feedback message per tick, however many resource types unloaded
					Net.Event("Effect"):FireClient(player, "Deposited", { Res = lastRes, Amount = deposited })
					-- equipped delivery effect: a short client-side burst everyone can see (throttled per player)
					local fx = player:GetAttribute("CosContrib")
					local now = os.clock()
					if fx and now - (lastFx[player] or 0) > 1.5 then
						lastFx[player] = now
						Net.Event("Effect"):FireAllClients("Contribution", { U = player.UserId, Id = fx })
					end
				end
				if blocked and deposited == 0 then
					local t = os.clock()
					if not notNeededNotice[player] or t - notNeededNotice[player] > 6 then
						notNeededNotice[player] = t
						Net.Event("Notify"):FireClient(player, "Warn", "This build doesn't need what you're carrying. Check the tracker, or drop it.")
					end
				end
			end
		end
	end
end

function DepositService.Start()
	Players.PlayerRemoving:Connect(function(p)
		notNeededNotice[p] = nil
		lastFx[p] = nil
	end)
	task.spawn(function()
		local interval = GameConfig.Site.DepositTickInterval
		local last = os.clock()
		while true do
			task.wait(interval)
			local t = os.clock()
			local ok, err = pcall(tick, math.min(0.5, t - last))
			if not ok then
				warn("[Deposit] tick error:", err) -- never let one bad tick stop deposits for the whole server
			end
			last = t
		end
	end)
end

return DepositService
