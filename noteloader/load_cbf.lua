-- Custom Beatmap Festival project loader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine, NoteLoader = ...
local love = love
local bit = require("bit")

local CBFLoader = {ProjectLoader = true}
local CBFBeatmap = {}
CBFBeatmap.__index = NoteLoader.NoteLoaderNoteObject._derive(CBFBeatmap)

---------------------------
-- Pre-CBF beatmap setup --
---------------------------

local function image_cache(link)
	return setmetatable({}, {
		__index = function(_, var)
			return AquaShine.LoadImage(link[var])
		end,
	})
end

local position_translation = {L4 = 9, L3 = 8, L2 = 7, L1 = 6, C = 5, R1 = 4, R2 = 3, R3 = 2, R4 = 1}
local cbf_unit_icons = image_cache {
	HONOKA_POOL = "assets/image/cbf/01_pool_unidolized_game_4.png",
	HONOKA_POOL_IDOL = "assets/image/cbf/01_pool_idolized_game_3.png",
	KOTORI_POOL = "assets/image/cbf/01_pool_unidolized_game_3.png",
	KOTORI_POOL_IDOL = "assets/image/cbf/01_pool_idolized_game_2.png",
	MAKI_CIRCUS = "assets/image/cbf/02_circus_unidolized_game.png",
	MAKI_CIRCUS_IDOL = "assets/image/cbf/02_circus_idolized_game.png",
	HANAMARU_SWIMSUIT = "assets/image/cbf/01_Swimsuit_Unidolized_game.png",
	HANAMARU_SWIMSUIT_IDOL = "assets/image/cbf/01_Swimsuit_Idolized_game.png",
	HANAMARU_INITIAL = "assets/image/cbf/01_Initial_Unidolized_game.png",
	HANAMARU_INITIAL_IDOL = "assets/image/cbf/01_Initial_Idolized_game.png",
	ELI_THIEF = "assets/image/cbf/02_thief_unidolized_game.png",
	ELI_THIEF_IDOL = "assets/image/cbf/02_thief_idolized_game.png",
	RIN_ARABIAN = "assets/image/cbf/01_arabianSet_unidolized_game.png",
	RIN_ARABIAN_IDOL = "assets/image/cbf/01_arabianSet_idolized_game.png",
	NOZOMI_IDOLSET = "assets/image/cbf/01_idolCostumeSet_unidolized_game.png",
	NOZOMI_IDOLSET_IDOL = "assets/image/cbf/01_idolCostumeSet_idolized_game.png",
	NICO_DEVIL = "assets/image/cbf/01_devil_unidolized_game.png",
	NICO_DEVIL_IDOL = "assets/image/cbf/01_devil_idolized_game.png",
	UMI_DEVIL = "assets/image/cbf/01_devil_unidolized_game_2.png",
	HANAYO_TAISHOROMAN = "assets/image/cbf/01_taishoRoman_unidolized_game.png",
	HANAYO_TAISHOROMAN_IDOL = "assets/image/cbf/01_taishoRoman_idolized_game.png",
	ELI_POOL = "assets/image/cbf/01_pool_unidolized_game.png",
	KANAN_YUKATA = "assets/image/cbf/01_yukata_unidolized_game.png",
	KANAN_YUKATA_IDOL = "assets/image/cbf/01_yukata_idolized_game.png",
	YOSHIKO_YUKATA = "assets/image/cbf/01_yukata_unidolized_game_2.png",
	YOSHIKO_YUKATA_IDOL = "assets/image/cbf/01_yukata_idolized_game_3.png",
	YOU_YUKATA = "assets/image/cbf/01_yukata_unidolized_game_3.png",
	YOU_YUKATA_IDOL = "assets/image/cbf/01_yukata_idolized_game_2.png",
	MAKI_POOL = "assets/image/cbf/01_pool_unidolized_game_2.png",
	MAKI_POOL_IDOL = "assets/image/cbf/01_pool_idolized_game.png",
	RUBY_GOTHIC = "assets/image/cbf/01_gothic_unidolized_game.png",
	RUBY_GOTHIC_IDOL = "assets/image/cbf/01_gothic_idolized_game.png",
	YOSHIKO_HALLOWEEN = "assets/image/cbf/01_halloween_unidolized_game.png",
	YOSHIKO_HALLOWEEN_IDOL = "assets/image/cbf/01_halloween_idolized_game_2.png",
	MARI_HALLOWEEN_IDOL = "assets/image/cbf/01_halloween_idolized_game.png",
	RIKO_HALLOWEEN_IDOL = "assets/image/cbf/01_halloween_idolized_game_3.png",
	HANAMARU_YUKATA = "assets/image/cbf/02_yukata_unidolized_game.png"
}

local cbf_icons = {
	None = {
		UR = image_cache {
			"assets/image/cbf/star4circleUREmpty.png",
			"assets/image/cbf/star4foreURSmile_empty.png"
		},
		["UR (Old)"] = image_cache {
			"assets/image/cbf/star4circleURCustom_Old.png",
			"assets/image/cbf/star4foreURSmile_empty.png"
		},
		SR = image_cache {
			"assets/image/cbf/star4circleSR_Custom.png",
			"assets/image/cbf/star4circleSR_Custom_fore.png"
		},
		R = image_cache {
			"assets/image/cbf/star4circleR_Custom.png",
			"assets/image/cbf/star4circleR_Custom_fore.png"
		},
	},
	Smile = {
		UR = image_cache {
			"assets/image/cbf/star4circleURSmile.png",
			"assets/image/cbf/star4foreURSmile.png"
		},
		["UR (Old)"] = image_cache {
			"assets/image/cbf/star4circleURSmile_Old.png",
			"assets/image/cbf/star4foreURSmile.png"
		},
		SSR = image_cache {
			"assets/image/cbf/star4circleSSRSmile.png",
			"assets/image/cbf/star4foreSRSmileIdolized.png"
		},
		SR = image_cache {
			"assets/image/cbf/star4circleSRSmile.png",
			"assets/image/cbf/star4foreSRSmileIdolized.png"
		},
	},
	Pure = {
		UR = image_cache {
			"assets/image/cbf/star4circleURPure.png",
			"assets/image/cbf/star4foreURPure.png"
		},
		["UR (Old)"] = image_cache {
			"assets/image/cbf/star4circleURPure_Old.png",
			"assets/image/cbf/star4foreURPure.png"
		},
		SSR = image_cache {
			"assets/image/cbf/star4circleSSRPure.png",
			"assets/image/cbf/star4foreSRPureIdolized.png"
		},
		SR = image_cache {
			"assets/image/cbf/star4circleSRPure.png",
			"assets/image/cbf/star4foreSRPureIdolized.png"
		},
	},
	Cool = {
		UR = image_cache {
			"assets/image/cbf/star4circleURCool.png",
			"assets/image/cbf/star4foreURCool.png"
		},
		["UR (Old)"] = image_cache {
			"assets/image/cbf/star4circleURCool_Old.png",
			"assets/image/cbf/star4foreURCool.png"
		},
		SSR = image_cache {
			"assets/image/cbf/star4circleSSRCool.png",
			"assets/image/cbf/star4foreSRCoolIdolized.png"
		},
		SR = image_cache {
			"assets/image/cbf/star4circleSRCool.png",
			"assets/image/cbf/star4foreSRCoolIdolized.png"
		},
	},
}

local function LoadUnitStrategy0(table)
	return setmetatable(table or {}, {__index = function(self, var)
		local x = cbf_unit_icons[var]
		self[var] = x
		
		return x
	end})
end

-- Look at "Cards" folder for custom cards
local function LoadUnitStrategy1(table, file)
	if love.filesystem.isDirectory(file.."/Cards") then
		setmetatable(table, {
			__index = function(_, var)
				local name = file.."/Cards/"..var..".png"
				
				if love.filesystem.isFile(name) then
					local x = love.graphics.newImage(name)
					
					table[var] = x
					return x
				end
				
				return nil
			end
		})
		
		return true
	end
	
	return false
end

-- Look at "Custom Cards" folder and read list.txt
local function LoadUnitStrategy2(table, file)
	local listname = file.."/Custom Cards/list.txt"
	if
		love.filesystem.isDirectory(file.."/Custom Cards") and
		love.filesystem.isFile(listname)
	then
		local f = assert(love.filesystem.newFile(listname, "r"))
		for line in f:lines() do
			if #line > 0 then
				local idx = line:match("([^/]+)/[^;]+")
				local _, img = pcall(love.graphics.newImage, file.."/Custom Cards/"..idx..".png")
				
				if _ then
					table[idx] = img
				end
			end
		end
		
		f:close()
		return true
	end
	
	return false
end

local function compose_unit_icon(unit_cache, color_type, rarity, chara_name, r, g, b)
	-- chara_name can be nil
	-- r, g, b are in float (0..1)
	if chara_name and #chara_name == 0 then chara_name = nil end
	
	local cl = {}
	local da
	local img
	
	if color_type == "Custom" then
		da = cbf_icons.None
		img = assert(da[rarity], "Invalid rarity")
		
		cl[#cl + 1] = {love.graphics.setColor, r * 255, g * 255, b * 255}
		cl[#cl + 1] = {love.graphics.draw, img[2]}
		
		if chara_name and unit_cache[chara_name] then
			cl[#cl + 1] = {love.graphics.setColor, 255, 255, 255}
			cl[#cl + 1] = {love.graphics.draw, unit_cache[chara_name]}
			cl[#cl + 1] = {love.graphics.setColor, r * 255, g * 255, b * 255}
		end
		
		cl[#cl + 1] = {love.graphics.draw, img[1]}
	else
		da = assert(cbf_icons[color_type], "Invalid attribute")
		img = assert(da[rarity], "Invalid rarity")
		
		cl[#cl + 1] = {love.graphics.setColor, 255, 255, 255}
		cl[#cl + 1] = {love.graphics.draw, img[2]}
		
		if chara_name and unit_cache[chara_name] then
			cl[#cl + 1] = {love.graphics.draw, unit_cache[chara_name]}
		end
		
		cl[#cl + 1] = {love.graphics.draw, img[1]}
	end
	
	return AquaShine.ComposeImage(128, 128, cl)
end

------------------------
-- CBF Beatmap Loader --
------------------------

function CBFLoader.GetLoaderName()
	return "Custom Beatmap Festival"
end

function CBFLoader.LoadNoteFromFilename(file)
	local this = setmetatable({}, CBFBeatmap)
	local project_config = file.."/projectConfig.txt"
	this.beatmap_filename = file.."/beatmap.txt"
	this.project_folder = file
	
	assert(
		love.filesystem.isFile(this.beatmap_filename) and
		love.filesystem.isFile(project_config),
		"Not a valid Custom Beatmap Festival project"
	)
	
	this.cbf_conf = {}
	project_config = assert(love.filesystem.newFile(project_config, "r"))
	
	-- Add keys
	for key, value in project_config:read():gmatch("%[([^%]]+)%];([^;]+);") do
		this.cbf_conf[key] = tonumber(value) or value
	end
	
	project_config:close()
	return this
end

------------------------
-- CBF Beatmap Object --
------------------------

function CBFBeatmap.GetNotesList(this)
	if not(this.notes_data) then
		local f = assert(love.filesystem.newFile(this.beatmap_filename, "r"))
		local notes_data = {}
		local readed_notes_data = {}
		local hold_note_queue = {}
		local desired_attribute
		
		if this.cbf_conf.SONG_ATTRIBUTE == "Smile" then
			desired_attribute = 1
		elseif this.cbf_conf.SONG_ATTRIBUTE == "Pure" then
			desired_attribute = 2
		elseif this.cbf_conf.SONG_ATTRIBUTE == "Cool" then
			desired_attribute = 3
		else
			desired_attribute = AquaShine.LoadConfig("LLP_SIFT_DEFATTR", 10)
		end

		-- Load it line by line
		for line in f:lines() do
			if #line > 0 then
				readed_notes_data[#readed_notes_data + 1] = line
			end
		end
		f:close()
		
		-- First phase sort
		table.sort(readed_notes_data, function(a, b)
			local a1 = a:match("([^/]+)/")
			local b1 = b:match("([^/]+)/")
			
			return tonumber(a1) < tonumber(b1)
		end)
		
		-- Parse
		for _, line in ipairs(readed_notes_data) do
			local time, pos, is_hold, is_release, release_time, hold_time, is_star, r, g, b, is_customcol = line:match("([^/]+)/([^/]+)/[^/]+/([^/]+)/([^/]+)/([^/]+)/([^/]+)/([^/]+)/([^,]+),([^,]+),([^,]+),([^;]+);")
			
			if time and pos and is_hold and is_release and release_time and hold_time and is_star and r and g and b and is_customcol then
				local num_pos = position_translation[pos]
				local attri = desired_attribute
				release_time = tonumber(release_time)
				hold_time = tonumber(hold_time)
				time = tonumber(time)
				
				if is_customcol == "True" then
					attri = bit.bor(
						bit.bor(bit.lshift(math.floor(tonumber(r) * 255), 23), bit.lshift(math.floor(tonumber(g) * 255), 14)),
						bit.bor(bit.lshift(math.floor(tonumber(b) * 255), 5), 31)
					)
				end
				
				if is_release == "True" then
					local last = assert(hold_note_queue[num_pos], "unbalanced release note")
					
					last.effect_value = time - last.timing_sec
					hold_note_queue[num_pos] = nil
				elseif is_hold == "True" then
					local val = {
						timing_sec = time,
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
						timing_sec = time,
						notes_attribute = attri,
						notes_level = 1,
						effect = is_star == "True" and 4 or 1,
						effect_value = 2,
						position = num_pos
					})
				end
			else
				AquaShine.Log("NoteLoader2/load_cbf", "Ignored: %s", line)
			end
		end
		
		table.sort(notes_data, function(a, b) return a.timing_sec < b.timing_sec end)
		this.notes_data = notes_data
	end
	
	return this.notes_data
end

function CBFBeatmap.GetName(this)
	return this.cbf_conf.SONG_NAME
end

function CBFBeatmap.GetBeatmapTypename()
	return "Custom Beatmap Festival"
end

local supported_image_fmts = {".png", ".bmp", ".jpg"}
function CBFBeatmap.GetCoverArt(this)
	if not(this.cover_art_loaded) then
		for _, v in ipairs(supported_image_fmts) do
			local name = this.project_folder.."/cover"..v
			
			if love.filesystem.isFile(name) then
				local cover = {}
				
				cover.title = this.cbf_conf.SONG_NAME
				cover.arrangement = this.cbf_conf.COVER_COMMENT
				cover.image = love.graphics.newImage(name)
				
				this.cover_art = cover
				break
			end
		end
		
		this.cover_art_loaded = true
	end
	
	return this.cover_art
end

function CBFBeatmap.GetCustomUnitInformation(this)
	if not(this.unit_loaded) then
		local charpos = this.project_folder.."/characterPositions.txt"
		local units = {}
		this.custom_unit = units
		
		if love.filesystem.isFile(charpos) then
			local composition_cache = {}
			local cunitloc = LoadUnitStrategy0()
			local f = assert(love.filesystem.newFile(charpos, "r"))
			
			-- Initialize units image
			if not(LoadUnitStrategy1(cunitloc, this.project_folder)) then
				LoadUnitStrategy2(cunitloc, this.project_folder)
			end
			
			-- If loading from "Cards" folder and "Custom Cards" folder fails,
			-- Load in current beatmap directory instead or in unit_icon folder
			local index_name = getmetatable(cunitloc)
			if index_name then index_name = index_name.__index end
			
			setmetatable(cunitloc, {
				__index = function(_, var)
					if index_name then
						local ret = index_name(_, var)
						
						if ret then
							return ret
						end
					end
					
					local name = this.project_folder.."/"..var..".png"
					local name2 = "unit_icon/"..var..".png"
					local x = nil
					
					if love.filesystem.isFile(name) then
						x = love.graphics.newImage(name)
					elseif love.filesystem.isFile(name2) then
						x = love.graphics.newImage(name2)
					end
					
					cunitloc[var] = x
					return x
				end
			})
			
			for line in f:lines() do
				if #line > 0 then
					local cache_name = line:sub(line:find("/") + 1)
					local pos, attr, rar, cname, r, g, b = line:match("([^/]+)/([^/]+)/([^/]+)/([^/]*)/(%d+%.?%d*),(%d+%.?%d*),(%d+%.?%d*)/")
					local i = assert(position_translation[pos])
					
					if composition_cache[cache_name] then
						units[i] = composition_cache[cache_name]
					else
						local a = compose_unit_icon(cunitloc, attr, rar, cname, r, g, b)
						
						units[i] = a
						composition_cache[cache_name] = a
					end
				end
			end
			
			f:close()
		end
		
		this.unit_loaded = true
	end
	
	return this.custom_unit
end

function CBFBeatmap.GetBackgroundID(this)
	return this:GetCustomBackground() and -1 or 0
end

function CBFBeatmap.GetCustomBackground(this)
	if not(this.bg_loaded) then
		for _, v in ipairs(supported_image_fmts) do
			local name = this.project_folder.."/background"..v
			
			if love.filesystem.isFile(name) then
				local bg = {}
				local img = love.graphics.newImage(name)
				local w, h = img:getDimensions()
				local ratio = w / h
				
				if ratio >= 1.770 then
					-- We can make the background to be 16:9
					local canvas = love.graphics.newCanvas(1136, 640)
					local scale = 640 / h
					
					love.graphics.push("all")
					love.graphics.setCanvas(canvas)
					love.graphics.setColor(255, 255, 255)
					love.graphics.clear(0, 0, 0)
					love.graphics.draw(img, 568, 320, 0, scale, scale, w * 0.5, h * 0.5)
					love.graphics.pop()
					
					bg[0] = love.graphics.newImage(canvas:newImageData(88, 0, 960, 640))
					bg[1] = love.graphics.newImage(canvas:newImageData(0, 0, 88, 640))
					bg[2] = love.graphics.newImage(canvas:newImageData(1048, 0, 88, 640))
				elseif ratio >= 1.5 then
					-- 2:3 ratio. Put it as-is
					bg[0] = img
				elseif ratio >= 4/3 then
					-- We can make the background to be 4:3
					local canvas = love.graphics.newCanvas(960, 720)
					local scale = 960 / w
					
					love.graphics.push("all")
					love.graphics.setCanvas(canvas)
					love.graphics.setColor(255, 255, 255)
					love.graphics.clear(0, 0, 0)
					love.graphics.draw(img, 480, 360, 0, scale, scale, w * 0.5, h * 0.5)
					love.graphics.pop()
					
					bg[0] = love.graphics.newImage(canvas:newImageData(0, 40, 960, 640))
					bg[4] = love.graphics.newImage(canvas:newImageData(0, 0, 960, 40))
					bg[5] = love.graphics.newImage(canvas:newImageData(0, 640, 960, 40))
				else
					-- We don't know the ratio. Put it as-is
					bg[0] = img
				end
				
				this.background = bg
				break
			end
		end
		
		this.bg_loaded = true
	end
	
	return this.background
end

-- This is non-standard (and not supported in CBF 0.7 atm).
local supported_video_fmts = {".ogg", ".ogv"}
if AquaShine.FFmpegExt then
	-- Wooo, FFmpegExt power!
	supported_video_fmts[#supported_video_fmts + 1] = ".mp4"
	supported_video_fmts[#supported_video_fmts + 1] = ".mkv"
	supported_video_fmts[#supported_video_fmts + 1] = ".avi"
	supported_video_fmts[#supported_video_fmts + 1] = ".flv"
end
function CBFBeatmap.GetVideoBackground(this)
	if not(this.video_loaded) then
		for _, v in ipairs(supported_video_fmts) do
			local name = this.project_folder.."/video_background"..v
			
			if love.filesystem.isFile(name) then
				local message
				this.video, message = AquaShine.LoadVideo(name)
				
				if not(this.video) then
					AquaShine.Log("NoteLoader2/load_cbf", "Failed to load video: %s", message)
				end
				
				break
			end
		end
		
		this.video_loaded = true
	end
	
	return this.video
end

-- In CBF, only  WAV and OGG were supported
local supported_audio_fmts = {".wav", ".ogg"}
function CBFBeatmap.GetBeatmapAudio(this)
	if not(this.audio_loaded) then
		for _, v in ipairs(supported_audio_fmts) do
			local name = this.project_folder.."/songFile"..v
			
			if love.filesystem.isFile(name) then
				this.audio = love.sound.newSoundData(name)
				break
			end
		end
		
		this.audio_loaded = true
	end
	
	return this.audio
end

function CBFBeatmap.ReleaseBeatmapAudio(this)
	this.audio_loaded, this.audio = false, nil
end

return CBFLoader
