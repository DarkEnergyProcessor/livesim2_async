-- SubRip basic parser
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local function sortSub(a, b)
	return a.start < b.start
end

---@param iter fun():(string|nil)
return function(iter)
	---@type Livesim2.SrtParseData[]
	local res = {}

	-- ignore sub number, unnecessary
	local line = iter()
	if line and #line == 0 then line = nil end
	while line do
		-- read timer
		local time = assert(iter(), "eof reached when loading time")
		local a, b, c, d, e, f, g, h = time:match("(%d+):(%d%d):(%d%d),(%d%d%d) %-%-> (%d+):(%d%d):(%d%d),(%d%d%d)")
		if not(a and b and c and d and e and f and g and h) then
			error("invalid time format: "..time.." ("..#time..")")
		end

		-- read text
		local text1 = assert(iter(), "eof reached when reading text")
		-- if it's empty line then skip this subtitle lol
		if #text1 > 0 then
			local text2 = iter()
			local t = {
				start = d / 1000 + c + b * 60 + a * 3600,
				stop = h / 1000 + g + f * 60 + e * 3600,
				text1 = text1
			}
			res[#res + 1] = t

			if text2 and #text2 > 0 then
				t.text2 = text2

				repeat
					local dummy = iter()
				until not(dummy) or #dummy == 0
			end
		end

		line = iter()
		if line and #line == 0 then line = nil end
	end

	-- sort start time
	table.sort(res, sortSub)

	for i = 1, #res - 1 do
		local r1 = res[i]
		r1.stop = math.min(r1.stop, res[i + 1].start)
	end

	return res
end
