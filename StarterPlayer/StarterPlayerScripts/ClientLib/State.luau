--!strict
-- Client view of replicated state:
--   State.Get(key) / State.Changed(key, fn)  -> ReplicatedStorage.GameState attributes
--   State.Data / State.DataChanged           -> private PlayerSync payload (upgrades, index...)
--   State.ServerNow()                        -> synchronized server clock
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local State = {}
local folder = ReplicatedStorage:WaitForChild("GameState") :: Configuration

State.Folder = folder
State.AnyChanged = Signal.new() -- (key)
State.Data = nil :: any
State.DataChanged = Signal.new() -- (data)

function State.Get(key: string): any
	return folder:GetAttribute(key)
end

function State.Changed(key: string, fn: (any) -> ())
	return folder:GetAttributeChangedSignal(key):Connect(function()
		fn(folder:GetAttribute(key))
	end)
end

function State.ServerNow(): number
	return workspace:GetServerTimeNow()
end

folder.AttributeChanged:Connect(function(key)
	State.AnyChanged:Fire(key)
end)

Net.Event("PlayerSync").OnClientEvent:Connect(function(data)
	State.Data = data
	State.DataChanged:Fire(data)
end)

return State
