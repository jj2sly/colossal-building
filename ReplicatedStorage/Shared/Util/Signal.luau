--!strict
-- Minimal script signal (no BindableEvent marshalling, preserves table identity).
export type Connection = { Disconnect: (self: Connection) -> () }
export type Signal = {
	Connect: (self: Signal, fn: (...any) -> ()) -> Connection,
	Fire: (self: Signal, ...any) -> (),
	Wait: (self: Signal) -> ...any,
	DisconnectAll: (self: Signal) -> (),
}

local Signal = {}
Signal.__index = Signal

function Signal.new(): Signal
	return (setmetatable({ _handlers = {} }, Signal) :: any) :: Signal
end

function Signal:Connect(fn)
	local handlers = self._handlers
	local entry = { fn = fn }
	table.insert(handlers, entry)
	return {
		Disconnect = function()
			local i = table.find(handlers, entry)
			if i then
				table.remove(handlers, i)
			end
		end,
	}
end

function Signal:Fire(...)
	for _, entry in table.clone(self._handlers) do
		task.spawn(entry.fn, ...)
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:DisconnectAll()
	table.clear(self._handlers)
end

return Signal
