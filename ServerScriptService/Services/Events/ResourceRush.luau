--!strict
-- RESOURCE RUSH: one zone (a resource the build still needs) yields more and gathers
-- faster for the event's duration.
local Rush = {}

function Rush.CanStart(ctx, _def): boolean
	return next(ctx.Registry().BuildService.Needed()) ~= nil
end

function Rush.Start(ctx, def, _token)
	local needed = ctx.Registry().BuildService.Needed()
	local options = {}
	for res in needed do
		table.insert(options, res)
	end
	table.sort(options)
	local res = options[Random.new():NextInteger(1, #options)]
	ctx.SetGatherBoost(res, def.Params.YieldMultiplier, def.Params.SpeedMultiplier)
	ctx.SetState("Active", workspace:GetServerTimeNow() + def.Duration, res)
	return nil
end

return Rush
