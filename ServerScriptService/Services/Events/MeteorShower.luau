--!strict
-- METEOR SHOWER: warning, then meteors rain down. Meteors aimed at completed sections
-- damage them on impact (players then repair). Other meteors are cosmetic and land
-- around the map. Meteor visuals are simulated on clients from one Effect message.
local Meteor = {}

function Meteor.CanStart(ctx, _def): boolean
	return #ctx.Registry().BuildService.DamageableSections() > 0
end

function Meteor.Start(ctx, def, token)
	local S = ctx.Registry()
	local p = def.Params
	local now = workspace:GetServerTimeNow()
	ctx.SetState("Warning", now + p.WarningTime, nil)
	ctx.Effect("MeteorWarning", { Time = p.WarningTime })
	task.wait(p.WarningTime)
	if not ctx.IsCurrent(token) then
		return nil
	end
	local activeFor = def.Duration - p.WarningTime
	ctx.SetState("Active", workspace:GetServerTimeNow() + activeFor, nil)

	local rng = Random.new()
	local sections = S.BuildService.DamageableSections()
	local hits = math.min(#sections, rng:NextInteger(p.SectionsDamaged[1], p.SectionsDamaged[2]))
	local impacts = {}
	local targeted = {}
	for i = 1, hits do
		local s = table.remove(sections, rng:NextInteger(1, #sections))
		local delay = 0.8 + i * 1.6
		table.insert(impacts, { Position = s.Center, Delay = delay, Big = true })
		table.insert(targeted, { Index = s.Index, Delay = delay })
	end
	for _ = 1, p.MeteorCount - hits do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(30, 190)
		table.insert(impacts, {
			Position = Vector3.new(math.cos(angle) * radius, 1, math.sin(angle) * radius),
			Delay = rng:NextNumber(0, activeFor - 3),
			Big = false,
		})
	end
	local fallTime = 1.4
	ctx.Effect("Meteors", { Impacts = impacts, FallTime = fallTime })
	for _, t in targeted do
		task.delay(t.Delay + fallTime, function()
			if ctx.IsCurrent(token) then
				S.BuildService.DamageStage(t.Index, p.RepairCostFraction, p.MaxRepairUnits)
			end
		end)
	end
	return nil
end

return Meteor
