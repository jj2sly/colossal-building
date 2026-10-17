--!strict
-- DOUBLE CARRY: everyone's carry capacity is multiplied for the duration. When it ends,
-- capacity returns to normal but nothing already carried is removed; players over
-- capacity simply can't gather more until they unload.
local DoubleCarry = {}

function DoubleCarry.Start(ctx, def, _token)
	ctx.SetCarryMultiplier(def.Params.CapacityMultiplier)
	ctx.SetState("Active", workspace:GetServerTimeNow() + def.Duration, nil)
	return nil
end

return DoubleCarry
