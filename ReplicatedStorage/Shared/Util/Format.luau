--!strict
-- Display formatting helpers.
local Format = {}

function Format.Number(n: number): string
	n = math.floor(n + 0.5)
	local s = tostring(math.abs(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return (n < 0 and "-" or "") .. out
end

function Format.Short(n: number): string
	if n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("%.1fK", n / 1e3)
	end
	return Format.Number(n)
end

function Format.Time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function Format.Percent(f: number): string
	return string.format("%d%%", math.floor(f * 100 + 0.5))
end

return Format
