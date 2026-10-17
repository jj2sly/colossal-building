--!strict
-- Permanent upgrades: purchase validation and applying effects. All numbers come from
-- UpgradeConfig; other services ask UpgradeService.Value(player, id).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local VehicleConfig = require(Shared.Config.VehicleConfig)
local Formulas = require(Shared.Formulas)
local MasterBuilderConfig = require(Shared.Config.MasterBuilderConfig)

local UpgradeService = {}
local S: any

function UpgradeService.Init(registry)
	S = registry
end

function UpgradeService.Level(player: Player, id: string): number
	local d = S.PlayerDataService.Get(player)
	return d and d.Upgrades[id] or 0
end

function UpgradeService.MasterRank(player: Player): number
	local d = S.PlayerDataService.Get(player)
	return d and d.MasterBuilder and d.MasterBuilder.Rank or 0
end

-- Temporary buffs from daily / return rewards: attributes Buff<Key> (amount) and Buff<Key>Until (os.time seconds).
function UpgradeService.Buff(player: Player, key: string): number
	local untilT = player:GetAttribute("Buff" .. key .. "Until")
	if type(untilT) == "number" and os.time() < untilT then
		return player:GetAttribute("Buff" .. key) or 0
	end
	return 0
end

-- Upgrade value including the small permanent Master Builder rank bonuses (gather, Luck, Worker) and temporary buffs.
function UpgradeService.Value(player: Player, id: string): number
	local v = UpgradeConfig.Value(id, UpgradeService.Level(player, id))
	local rank = UpgradeService.MasterRank(player)
	if rank > 0 then
		if id == "GatherSpeed" then
			v *= 1 + MasterBuilderConfig.Bonus(rank, "GatherEffectiveness")
		elseif id == "Luck" then
			v += MasterBuilderConfig.Bonus(rank, "PersonalLuck")
		elseif id == "WorkerEfficiency" then
			v *= 1 + MasterBuilderConfig.Bonus(rank, "WorkerEffectiveness")
		end
	end
	-- permanent Index rarity-completion bonuses (IndexConfig.RarityBonuses)
	if S.BuildIndexService then
		if id == "Luck" then
			v += S.BuildIndexService.Bonus(player, "Luck")
		elseif id == "WorkerEfficiency" then
			v *= 1 + S.BuildIndexService.Bonus(player, "WorkerEfficiency")
		end
	end
	if id == "GatherSpeed" then
		v *= 1 + UpgradeService.Buff(player, "Gather")
		if S.BoostService then
			v *= S.BoostService.PaidGatherMult(player) -- Builder's Toolkit + Builder Rush, capped
		end
	elseif id == "Luck" then
		v += UpgradeService.Buff(player, "Luck")
	elseif id == "DepositSpeed" and S.BoostService then
		v *= S.BoostService.PaidDepositMult(player)
	end
	return v
end

-- Personal Luck points (upgrade + Master Builder bonus).
function UpgradeService.PersonalLuck(player: Player): number
	return UpgradeService.Value(player, "Luck")
end

-- Walk speed = trained Speed * vehicle speed multiplier.
function UpgradeService.RefreshMovement(player: Player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local d = S.PlayerDataService.Get(player)
	local speed = Formulas.BaseSpeed(d and d.Training.Speed or 0)
	-- the character always walks at its trained speed; a vehicle is a separate moving object whose MaxSpeed is published here
	hum.WalkSpeed = speed
	if S.VehicleService then
		S.VehicleService.RefreshStats(player, speed)
	end
end

-- Applies a level directly (used by purchases and debug tools).
function UpgradeService.SetLevel(player: Player, id: string, level: number)
	local d = S.PlayerDataService.Get(player)
	local u = UpgradeConfig.Upgrades[id]
	if not d or not u then
		return
	end
	d.Upgrades[id] = math.clamp(math.floor(level), 0, u.MaxLevel)
	S.PlayerDataService.MarkDirty(player)
	UpgradeService.RefreshMovement(player)
	S.ResourceService.RefreshCapacity(player)
end

local limiter = Net.RateLimiter(4, 8)

local function onBuy(player: Player, id: any): (boolean, string)
	if not limiter(player) then
		return false, "Slow down!"
	end
	if type(id) ~= "string" or not UpgradeConfig.Upgrades[id] then
		return false, "Unknown upgrade"
	end
	local level = UpgradeService.Level(player, id)
	local price = UpgradeConfig.Price(id, level)
	if not price then
		return false, "Max level"
	end
	if not S.PlayerDataService.TrySpend(player, price) then
		return false, "Not enough Coins"
	end
	UpgradeService.SetLevel(player, id, level + 1)
	Net.Event("Effect"):FireClient(player, "UpgradeBought", { Id = id, Level = level + 1 })
	return true, "Upgraded!"
end

function UpgradeService.Start()
	Net.Function("BuyUpgrade").OnServerInvoke = onBuy
	local function hookCharacter(player: Player)
		player.CharacterAdded:Connect(function(char)
			char:WaitForChild("Humanoid")
			UpgradeService.RefreshMovement(player)
		end)
		if player.Character then
			UpgradeService.RefreshMovement(player)
		end
	end
	Players.PlayerAdded:Connect(hookCharacter)
	for _, p in Players:GetPlayers() do
		hookCharacter(p)
	end
	S.PlayerDataService.Loaded:Connect(function(player)
		UpgradeService.RefreshMovement(player)
	end)
end

return UpgradeService
