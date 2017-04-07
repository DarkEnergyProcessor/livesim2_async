-- Custom Beatmap Festival beatmap loader
-- Part of DEPLS2

local bit = require("bit")
local DEPLS = _G.DEPLS
local NoteLoader = _G.NoteLoader
local CBFBeatmap = {
	Extension = nil,	-- No extension, that means detect function is necessary
}
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

--! @brief Check if specificed beatmap is CBF beatmap
--! @param file Table contains:
--!        - path relative to DEPLS save dir
--!        - absolute path
--!        - forward slashed and not contain trailing slash
--! @returns true if it's CBF beatmap, false otherwise
function CBFBeatmap.Detect(file)
	-- File param is table:
	-- 1. path relative to DEPLS save dir
	-- 2. absolute path
	-- dir separator is forward slash
	-- does not contain trailing slash
	local zip = file[1]..".zip"
	
	if love.filesystem.isFile(zip) then
		MountZip(zip, file[1])
	end
	
	return
		love.filesystem.isFile(file[1].."/beatmap.txt") and
		love.filesystem.isFile(file[1].."/projectConfig.txt")
end

--! @brief Loads CBF beatmap
--! @param file Table contains:
--!        - path relative to DEPLS save dir
--!        - absolute path
--!        - forward slashed and not contain trailing slash
--! @returns table with these data
--!          - notes_list is the SIF-compilant notes data
--!          - song_file is the song file handle (Source object) or nil
--!          - background is beatmap-specific background handle list (for extended backgrounds) (jpg supported) or nil
--!          - units is custom units image list or nil
function CBFBeatmap.Load(file)
	local cbf = {
		beatmap = assert(love.filesystem.newFile(file[1].."/beatmap.txt", "r")),
		projectConfig = assert(love.filesystem.newFile(file[1].."/projectConfig.txt", "r"))
	}
	
	-- Add keys
	for key, value in cbf.projectConfig:read():gmatch("%[([^%]]+)%];([^;]+);") do
		cbf[key] = value
	end
	
	local notes_data = {}
	local desired_attribute = LoadConfig("LLP_SIFT_DEFATTR", 1)
	
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
		local time, pos, is_hold, is_release, release_time, hold_time, is_star, r, g, b, is_customcol = line:match("([^/]+)/([^/]+)/[^/]+/([^/]+)/([^/]+)/([^/]+)/([^/]+)/([^/]+)/([^,]+),([^,]+),([^,]+),([^;]+);")
		local num_pos = position_translation[pos]
		local attri = desired_attribute
		release_time = tonumber(release_time)
		hold_time = tonumber(hold_time)
		
		if is_customcol == "True" then
			attri = bit.bor(bit.bor(bit.lshift(tonumber(r) * 255, 23), bit.lshift(tonumber(g) * 255, 14)), bit.bor(bit.lshift(tonumber(b) * 255, 5), 31))
		end
		
		if is_release == "True" then
			local last = assert(hold_note_queue[num_pos], "unbalanced release note")
			
			last.effect_value = time - last.timing_sec
			hold_note_queue[num_pos] = nil
		elseif is_hold == "True" then
			local val = {
				timing_sec = time + 0,
				notes_attribute = attri,
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
				notes_attribute = attri,
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
	
	table.sort(notes_data, function(a, b) return a.timing_sec < b.timing_sec end)
	
	-- Get background
	local background = {}
	local exts = {"png", "jpg", "bmp"}
	
	for a, b in pairs(exts) do
		if love.filesystem.isFile(file[1].."/background."..b) then
			background[0] = NoteLoader.LoadImageRelative(file[1], "background."..b)
		end
	end
	
	-- Left, Right, Top, Bottom
	if background[0] then
		for i = 1, 4 do
			for j = 1, 3 do
				local b = exts[j]
				
				if love.filesystem.isFile(file[1].."/background-"..i.."."..b) then
					background[i] = NoteLoader.LoadImageRelative(file[1], "background-"..i.."."..b)
					break
				end
			end
		end
	end
	
	-- Get units
	local units_ext = {"png", "txt"}
	local units = {}
	local has_custom_units = false
	
	for i = 1, 9 do
		for j = 1, 2 do
			local fn = file[1].."/unit_pos_"..i.."."..units_ext[j]
			
			if love.filesystem.isFile(fn) then
				units[i] = NoteLoader.UnitLoader(fn)
				has_custom_units = true
				break
			end
		end
	end
	
	-- Result
	local out = {
		notes_list = notes_data,
		song_file = DEPLS.LoadAudio(file[1].."/songFile.wav")
	}
	
	if background[0] then
		out.background = background
	end
	
	if has_custom_units then
		out.units = units
	end
	
	-- Get cover
	local cover_ext = {"jpg", "png"}
	
	for i = 1, 2 do
		local fn = file[1].."/cover."..cover_ext[i]
		
		if love.filesystem.isFile(file[1].."/cover."..cover_ext[i]) then
			-- Has cover image
			local cover = {image = love.graphics.newImage(love.filesystem.newFileData(fn))}
			cover.title = cbf.SONG_NAME
			
			out.cover = cover
			break
		end
	end
	
	return out
end

return CBFBeatmap
