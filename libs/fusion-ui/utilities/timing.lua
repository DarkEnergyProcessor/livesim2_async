local path = string.sub(..., 1, string.len(...) - string.len(".utilities.timing"))
local gui = require(path .. ".dummy")

local timing = {
	timers = {
		
	},
	oldTimers = {},
	startTime = 0,
	savePasses = 30,
	oldPasses = {}
}

function timing.startPass()
	if gui.conf.timing then
		timing.startTime = love.timer.getTime()
	end
end

function timing.start(index)
	if gui.conf.timing then
		if timing.timers[index]~=nil then
			timing.timers[index] = love.timer.getTime() - timing.timers[index]
		else
			timing.timers[index] = love.timer.getTime()
		end
	end
end

function timing.stop(index)
	if gui.conf.timing then
		timing.timers[index] = love.timer.getTime() - timing.timers[index]
	end
end

function timing.endPass()
	if gui.conf.timing then
		table.insert(timing.oldTimers,1,timing.timers)
		timing.timers = {}
		if #timing.oldTimers>timing.savePasses then
			table.remove(timing.oldTimers,savePasses)
		end
	end
end

function timing.allTimers()

end

function timing.averageTimers()
	if gui.conf.timing then
		local allAvg = {}

		for i, e in pairs(timing.timers) do
			local total = e
			local totalPast = 1
			for k, p in ipairs(timing.oldTimers) do
				totalPast = totalPast+1
				total = total + p[i]
			end
			allAvg[i] = total/totalPast
		end

		return allAvg
	end
end

return timing