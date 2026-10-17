--!strict
-- Coin purchases that aren't upgrades: vehicles and the Worker unlock.
-- (No Robux in the vertical slice; future gamepasses/products would add a separate
-- MarketplaceService handler that grants through the same Grant/Unlock functions.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local VehicleConfig = require(Shared.Config.VehicleConfig)
local WorkerConfig = require(Shared.Config.WorkerConfig)

local ShopService = {}
local S: any

function ShopService.Init(registry)
	S = registry
end

local limiter = Net.RateLimiter(3, 6)

local function buy(player: Player, kind: any, id: any): (boolean, string)
	if not limiter(player) then
		return false, "Slow down!"
	end
	local d = S.PlayerDataService.Get(player)
	if not d then
		return false, "Data still loading"
	end
	if kind == "Vehicle" and type(id) == "string" then
		local v = VehicleConfig.Vehicles[id]
		if not v then
			return false, "Unknown vehicle"
		end
		if v.Master then
			-- Master Builder reward: equip if unlocked, never for sale
			if S.VehicleService.Owns(player, id) then
				return S.VehicleService.Equip(player, id)
			end
			return false, "A Master Builder reward"
		end
		if d.Vehicles.Owned[id] then
			return S.VehicleService.Equip(player, id)
		end
		if not S.PlayerDataService.TrySpend(player, v.Price) then
			return false, "Not enough Coins"
		end
		S.VehicleService.Grant(player, id)
		S.VehicleService.Equip(player, id)
		Net.Event("Effect"):FireClient(player, "UpgradeBought", { Id = id })
		return true, v.DisplayName .. " unlocked!"
	elseif kind == "Worker" then
		if d.Worker.Unlocked then
			return false, "You already have a Worker"
		end
		local def = WorkerConfig.Types[WorkerConfig.DefaultType]
		if not S.PlayerDataService.TrySpend(player, def.UnlockPrice) then
			return false, "Not enough Coins"
		end
		d.Worker.Unlocked = true
		d.Worker.Enabled = true
		S.PlayerDataService.MarkDirty(player)
		S.WorkerService.Spawn(player)
		Net.Event("Effect"):FireClient(player, "UpgradeBought", { Id = "Worker" })
		return true, "Worker hired!"
	end
	return false, "Unknown item"
end

function ShopService.Start()
	Net.Function("BuyItem").OnServerInvoke = buy
end

return ShopService
