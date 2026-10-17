--!strict
-- BUILD FRENZY: each delivered unit counts extra toward construction and unloading is
-- faster. Players still have to gather and deliver; EventService resets it afterwards.
local BuildFrenzy = {}

function BuildFrenzy.CanStart(ctx, _def): boolean
	return next(ctx.Registry().BuildService.Needed()) ~= nil
end

function BuildFrenzy.Start(ctx, def, _token)
	ctx.SetConstructionMultiplier(def.Params.ConstructionMultiplier, def.Params.DepositSpeedMultiplier)
	ctx.SetState("Active", workspace:GetServerTimeNow() + def.Duration, nil)
	return nil
end

return BuildFrenzy
