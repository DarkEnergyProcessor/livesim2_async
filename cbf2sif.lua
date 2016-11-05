-- Custom Beatmap Festival to SIF Beatmap
-- Command-line: lua cbf2sif.lua <CBF project folder> <output = stdout>
return function(...)
	local arg = {...}
	local target_output = io.stdout

	if arg[1] == nil then
		print("Usage: lua cbf2sif.lua <CBF project folder> <output = stdout>")
		return 1
	end

	if arg[2] then
		target_output = assert(io.open(arg[2], "wb"))
	end

	local project_folder = arg[1]:gsub("[/|\\]$", "")
	local JSON = require("JSON")

	local cbf = {
		beatmap = assert(io.open(project_folder.."/beatmap.txt", "rb")),
		projectConfig = assert(io.open(project_folder.."/projectConfig.txt", "rb"))
	}

	-- Add keys
	for key, value in cbf.projectConfig:read("*a"):gmatch("%[([^%]]+)%];([^;]+);") do
		cbf[key] = value
	end

	local notes_data = {}
	local desired_attribute = 1	-- smile
	local position_translation = {
		L4 = 9,
		L3 = 8,
		L2 = 7,
		L1 = 6,
		C = 5,
		R1 = 4,
		R2 = 3,
		R3 = 2,
		R4 = 1
	}

	cbf.projectConfig:close()

	if cbf.SONG_ATTRIBUTE == "Pure" then
		desired_attribute = 2
	elseif cbf.SONG_ATTRIBUTE == "Cool" then
		desired_attribute = 3
	end

	local readed_notes_data = {}
	local hold_note_queue = {}

	for line in cbf.beatmap:lines() do
		table.insert(readed_notes_data, line)
	end

	cbf.beatmap:close()

	-- sort
	table.sort(readed_notes_data, function(a, b)
		local a1 = a:match("([^/]+)/")
		local b1 = b:match("([^/]+)/")
		
		return tonumber(a1) < tonumber(b1)
	end)

	-- Parse notes
	for _, line in pairs(readed_notes_data) do
		local time, pos, is_hold, is_release, release_time, hold_time, is_star = line:match("([^/]+)/([^/]+)/[^/]+/([^/]+)/([^/]+)/([^/]+)/([^/]+)/([^/]+)/")
		local num_pos = position_translation[pos]
		release_time = tonumber(release_time)
		hold_time = tonumber(hold_time)
		
		if is_release == "True" then
			local last = assert(hold_note_queue[num_pos], "unbalanced release note")
			
			last.effect_value = time - last.timing_sec
			hold_note_queue[num_pos] = nil
		elseif is_hold == "True" then
			local val = {
				timing_sec = time + 0,
				notes_attribute = desired_attribute,
				notes_level = 1,
				effect = 3,
				effect_value = 0,
				position = num_pos
			}
			
			table.insert(notes_data, val)
			assert(hold_note_queue[num_pos] == nil, "overlapped hold note")
			
			hold_note_queue[num_pos] = val
		else
			table.insert(notes_data, {
				timing_sec = time + 0,
				notes_attribute = desired_attribute,
				notes_level = 1,
				effect = is_star == "True" and 4 or 1,
				effect_value = 2,
				position = num_pos
			})
		end
	end

	for i = 1, 9 do
		assert(hold_note_queue[i] == nil, "unbalanced hold note")
	end

	target_output:write(JSON:encode(notes_data))
	
	if target_output ~= io.stdout then
		target_output:close()
	end
end
