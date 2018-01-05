-- Beatmap converter: To LLPractice
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine = ...
local JSON = require("JSON")
local NoteLoader = AquaShine.LoadModule("note_loader2")
local ToLLP = {}
local epsilon = 0.001

function ToLLP.CheckSimulNote(lane, timing)
	for i = 1, 9 do
		if lane[i] then
			local n = lane[i]
			
			for j = 1, #n do
				if math.abs(n[j].starttime - timing) <= epsilon then
					return true
				end
			end
		end
	end
	
	return false
end

function ToLLP.Start(arg)
	local noteloader_data = NoteLoader.NoteLoader(assert("beatmap/"..arg[1]))
	local llpdata = {}
	--llpdata.speed = tonumber(arg[2]) or 160
	--llpdata.audiofile = arg[1]
	llpdata.lane = {}
	
	for i, v in ipairs(noteloader_data:GetNotesList()) do
		local laneidx = 10 - v.position
		local lane = llpdata.lane[laneidx]
		
		if not(lane) then
			lane = {}
			llpdata.lane[laneidx] = lane
		end
		
		local note = table.new(0, 6)
		local long = v.effect % 10 == 3
		-- time units is in ms for LLP
		note.starttime = v.timing_sec * 1000
		note.endtime = note.starttime + (long and v.effect_value or 0) * 1000
		note.longnote = long
		note.parallel = ToLLP.CheckSimulNote(llpdata.lane, note.starttime)
		note.lane = laneidx - 1
		note.hold = false
		
		lane[#lane + 1] = note
	end
	
	io.write(JSON:encode(llpdata), "\n")
	love.event.quit()
end

return ToLLP
