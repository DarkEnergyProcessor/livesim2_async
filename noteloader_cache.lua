-- Caching functions for NoteLoader2
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine, NoteLoader = ...
local love = love
local NCache = {}

function NCache.CreateCache(note, filename)
	local ncache = {}
	
	ncache.filename = assert(filename)
	ncache.name = note:GetName()
	ncache.type = note:GetBeatmapTypename()
	ncache.score_data = note:GetScoreInformation()
	ncache.combo_data = note:GetComboInformation()
	ncache.cover_art = note:GetCoverArt()
	ncache.has_storyboard = note:HasStoryboard()
	
	do
		local s = note:GetStarDifficultyInfo()
		local rs = note:GetStarDifficultyInfo(true)
		
		if s > 0 then
			if rs ~= s then
				ncache.difficulty = string.format("%d\226\152\134 (Random %d\226\152\134)", s, rs)
			else
				ncache.difficulty = string.format("%d\226\152\134", s)
			end
		end
	end
	
	-- Resize cover art and add PNG string representation
	if ncache.cover_art then
		local drawcall = {}
		local w, h = ncache.cover_art.image:getDimensions()
		drawcall[#drawcall + 1] = {love.graphics.draw, ncache.cover_art.image, 0, 0, 0, 160 / w, 160 / h}
		
		local imagedata = AquaShine.ComposeImage(160, 160, drawcall, true)
		local png = imagedata:encode("png"):getString()
		
		ncache.cover_art.image = love.graphics.newImage(imagedata)
		ncache.cover_art._image = png
	end
	
	if not(ncache.score_data) or not(ncache.combo_data) then
		-- Default: calculate from notes data
		local notes_list = note:GetNotesList()
		
		if not(ncache.score_data) then
			-- Use MASTER score preset
			-- Swing notes is half of it.
			local s_score = 0
			for i = 1, #notes_list do
				s_score = s_score + (notes_list[i].effect > 10 and 370 or 739)
			end
			
			local score = {}
			
			score[1] = math.floor(s_score * 0.285521 + 0.5)
			score[2] = math.floor(s_score * 0.71448 + 0.5)
			score[3] = math.floor(s_score * 0.856563 + 0.5)
			score[4] = s_score
			ncache.score_data = score
		end
		
		if not(ncache.combo_data) then
			-- Calculate using 0.3, 0.5, 0.7, 1.0 preset
			local s_combo = #notes_list
			local combo = {}
			
			combo[1] = math.ceil(s_combo * 0.3)
			combo[2] = math.ceil(s_combo * 0.5)
			combo[3] = math.ceil(s_combo * 0.7)
			combo[4] = s_combo
			ncache.combo_data = combo
		end
	end
	
	return ncache
end

function NCache.LoadCache(beatmap_path)
	local cname = string.format("%s/noteloader_%s_cache.ncache", AquaShine.GetTempDir(), (beatmap_path:gsub("[/|\\]", "_")))
	local f = io.open(cname, "rb")
	local cache = nil
	
	if not(f) then
		-- Cache doesn't exists
		local note = NoteLoader.NoteLoader(beatmap_path)
		
		if not(note) then
			-- Note is not valid
			return nil
		end
		
		cache = NCache.CreateCache(note, beatmap_path)
		NCache._SaveCache(cname, beatmap_path, cache)
		note:Release()
	else
		local beatmap_mtime = assert(love.filesystem.getLastModified(beatmap_path))
		local status
		status, cache = pcall(NCache.ParseCache, f)
		f:close()
		
		if not(status) or cache._mtime ~= beatmap_mtime then
			-- Beatmap is modified. Recreate cache.
			local note = NoteLoader.NoteLoader(beatmap_path)
			
			if not(note) then
				-- Note is not valid. Delete cache
				os.remove(cname)
				return nil
			end
			
			cache = NCache.CreateCache(note, beatmap_path)
			NCache._SaveCache(cname, beatmap_path, cache)
			note:Release()
		end
	end
	
	return cache
end

function NCache._ReadBinary(file)
	local lengthstr = {}
	
	while true do
		local b = file:read(1)
		local c = b:byte()
		
		if c == 58 then break end
		
		assert(c >= 48 and c < 58, "Invalid number")
		lengthstr[#lengthstr + 1] = b
	end
	
	return file:read(tonumber(table.concat(lengthstr)))
end

function NCache._Explode(str, delim)
	local a = {}
	
	for w in str:gmatch("[^"..delim.."]+") do
		a[#a + 1] = tonumber(w) or w
	end
	
	return a
end

function NCache.ParseCache(file)
	local ncache = {}
	
	file:seek("set")
	ncache.version = assert(tonumber(file:read("*l")))
	ncache._mtime = assert(tonumber(file:read("*l")))
	ncache.name = assert(file:read("*l"))
	ncache.type = assert(file:read("*l"))
	ncache.filename = assert(file:read("*l"))
	ncache.score_data = NCache._Explode(assert(file:read("*l")), ":")
	ncache.combo_data = NCache._Explode(assert(file:read("*l")), ":")
	
	if ncache.version >= 2 then
		local diff = assert(file:read("*l"))
		if #diff > 0 then
			ncache.difficulty = diff
		end
	end
	
	local storycover = NCache._Explode(assert(file:read("*l")), ":")
	
	if storycover[2] >= 1 then
		-- Has cover
		local title = assert(file:read("*l"))
		local arr = assert(file:read("*l"))
		
		ncache.cover_art = {}
		
		if #title > 0 then
			ncache.cover_art.title = title
		end
		
		if #arr > 0 then
			ncache.cover_art.arrangement = arr
		end
		
		ncache.cover_art._image = NCache._ReadBinary(file)
		ncache.cover_art.image = love.graphics.newImage(love.filesystem.newFileData(ncache.cover_art._image, "_.png"))
	end
	
	ncache.has_storyboard = storycover[1] >= 1
	
	
	return ncache
end

function NCache.SaveCache(beatmap_path, cache)
	return NCache._SaveCache(
		("%s/noteloader_%s_cache.ncache"):format(AquaShine.GetTempDir(), (beatmap_path:gsub("[/|\\]", "_"))),
		beatmap_path,
		cache
	)
end

function NCache._SaveCache(desired_name, beatmap_path, cache)
	local f = assert(io.open(desired_name, "wb"))
	
	cache._mtime = assert(love.filesystem.getLastModified(beatmap_path))
	
	f:write(
		"2\n",
		cache._mtime, "\n",
		cache.name, "\n",
		cache.type, "\n",
		cache.filename, "\n",
		table.concat(cache.score_data, ":"), "\n",
		table.concat(cache.combo_data, ":"), "\n",
		cache.difficulty or "", "\n",
		cache.has_storyboard and 1 or 0, ":", cache.cover_art and 1 or 0, "\n"
	)
	
	if cache.cover_art then
		f:write(
			cache.cover_art.title or "", "\n",
			cache.cover_art.arrangement or "", "\n",
			#cache.cover_art._image, ":", cache.cover_art._image
		)
	end
	
	f:close()
end

return NCache
