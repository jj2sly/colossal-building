--!strict
-- GOLDEN HOUR: deliveries and repairs pay extra Coins for the duration. The multiplier is
-- read by BuildService when paying out, and EventService resets it when the event ends.
local GoldenHour = {}

function GoldenHour.Start(ctx, def, _token)
	ctx.SetCoinMultiplier(def.Params.CoinMultiplier)
	ctx.SetState("Active", workspace:GetServerTimeNow() + def.Duration, nil)
	return nil
end

return GoldenHour
