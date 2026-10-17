--!strict
-- WORKER STRIKE: every Worker stops where it is (holding its load and task) and shows a
-- strike sign. When the event ends they resume exactly where they left off.
local WorkerStrike = {}

function WorkerStrike.CanStart(ctx, _def): boolean
	return ctx.Registry().WorkerService.Count() > 0
end

function WorkerStrike.Start(ctx, def, _token)
	local workers = ctx.Registry().WorkerService
	workers.SetPaused(true)
	ctx.SetState("Active", workspace:GetServerTimeNow() + def.Duration, nil)
	return function()
		workers.SetPaused(false)
	end
end

return WorkerStrike
