--!strict
-- EARTHQUAKE: short warning, then the ground shakes (client camera shake) and several
-- completed sections crack. Each becomes a normal repair objective, so construction can
-- always be finished. It only damages sections that exist; with fewer finished sections
-- it simply damages fewer.
local Earthquake = {}

function Earthquake.CanStart(ctx, _def): boolean
	return #ctx.Registry().BuildService.DamageableSections() > 0
end

function Earthquake.Start(ctx, def, token)
	local S = ctx.Registry()
	local p = def.Params
	ctx.SetState("Warning", workspace:GetServerTimeNow() + p.WarningTime, nil)
	ctx.Effect("EarthquakeWarning", { Time = p.WarningTime })
	task.wait(p.WarningTime)
	if not ctx.IsCurrent(token) then
		return nil
	end
	local activeFor = def.Duration - p.WarningTime
	ctx.SetState("Active", workspace:GetServerTimeNow() + activeFor, nil)
	ctx.Effect("Earthquake", { Duration = activeFor })
	local rng = Random.new()
	local count = rng:NextInteger(p.SectionsDamaged[1], p.SectionsDamaged[2])
	-- crack sections one after another during the shaking
	for i = 1, count do
		task.delay(0.6 + (i - 1) * 1.1, function()
			if ctx.IsCurrent(token) then
				S.BuildService.DamageSections(1, p.RepairCostFraction, p.MaxRepairUnits)
			end
		end)
	end
	return nil
end

return Earthquake
