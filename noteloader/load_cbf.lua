-- Custom Beatmap Festival beatmap loader
-- Part of Live Simulator: 2

local AquaShine, NoteLoader = ...
local bit = require("bit")
local CBFBeatmap = {
	Name = "Custom Beatmap Festival",
	Extension = nil,	-- No extension, that means detect function is necessary
}
local position_translation = {L4 = 9, L3 = 8, L2 = 7, L1 = 6, C = 5, R1 = 4, R2 = 3, R3 = 2, R4 = 1}
local UnitLoadingAllowed = AquaShine.LoadConfig("CBF_UNIT_LOAD", 1) == 1

local CompositionCache = {}
local UnitIconCache, IconCache, ComposeUnitImage, LoadUnitStrategy1, LoadUnitStrategy2

if UnitLoadingAllowed then
	UnitIconCache = {
		HONOKA_POOL = AquaShine.LoadImage("assets/image/cbf/01_pool_unidolized_game_4.png"),
		HONOKA_POOL_IDOL = AquaShine.LoadImage("assets/image/cbf/01_pool_idolized_game_3.png"),
		KOTORI_POOL = AquaShine.LoadImage("assets/image/cbf/01_pool_unidolized_game_3.png"),
		KOTORI_POOL_IDOL = AquaShine.LoadImage("assets/image/cbf/01_pool_idolized_game_2.png"),
		MAKI_CIRCUS = AquaShine.LoadImage("assets/image/cbf/02_circus_unidolized_game.png"),
		MAKI_CIRCUS_IDOL = AquaShine.LoadImage("assets/image/cbf/02_circus_idolized_game.png"),
		HANAMARU_SWIMSUIT = AquaShine.LoadImage("assets/image/cbf/01_Swimsuit_Unidolized_game.png"),
		HANAMARU_SWIMSUIT_IDOL = AquaShine.LoadImage("assets/image/cbf/01_Swimsuit_Idolized_game.png"),
		HANAMARU_INITIAL = AquaShine.LoadImage("assets/image/cbf/01_Initial_Unidolized_game.png"),
		HANAMARU_INITIAL_IDOL = AquaShine.LoadImage("assets/image/cbf/01_Initial_Idolized_game.png"),
		ELI_THIEF = AquaShine.LoadImage("assets/image/cbf/02_thief_unidolized_game.png"),
		ELI_THIEF_IDOL = AquaShine.LoadImage("assets/image/cbf/02_thief_idolized_game.png"),
		RIN_ARABIAN = AquaShine.LoadImage("assets/image/cbf/01_arabianSet_unidolized_game.png"),
		RIN_ARABIAN_IDOL = AquaShine.LoadImage("assets/image/cbf/01_arabianSet_idolized_game.png"),
		NOZOMI_IDOLSET = AquaShine.LoadImage("assets/image/cbf/01_idolCostumeSet_unidolized_game.png"),
		NOZOMI_IDOLSET_IDOL = AquaShine.LoadImage("assets/image/cbf/01_idolCostumeSet_idolized_game.png"),
		NICO_DEVIL = AquaShine.LoadImage("assets/image/cbf/01_devil_unidolized_game.png"),
		NICO_DEVIL_IDOL = AquaShine.LoadImage("assets/image/cbf/01_devil_idolized_game.png"),
		UMI_DEVIL = AquaShine.LoadImage("assets/image/cbf/01_devil_unidolized_game_2.png"),
		HANAYO_TAISHOROMAN = AquaShine.LoadImage("assets/image/cbf/01_taishoRoman_unidolized_game.png"),
		HANAYO_TAISHOROMAN_IDOL = AquaShine.LoadImage("assets/image/cbf/01_taishoRoman_idolized_game.png"),
		ELI_POOL = AquaShine.LoadImage("assets/image/cbf/01_pool_unidolized_game.png"),
		KANAN_YUKATA = AquaShine.LoadImage("assets/image/cbf/01_yukata_unidolized_game.png"),
		KANAN_YUKATA_IDOL = AquaShine.LoadImage("assets/image/cbf/01_yukata_idolized_game.png"),
		YOSHIKO_YUKATA = AquaShine.LoadImage("assets/image/cbf/01_yukata_unidolized_game_2.png"),
		YOSHIKO_YUKATA_IDOL = AquaShine.LoadImage("assets/image/cbf/01_yukata_idolized_game_3.png"),
		YOU_YUKATA = AquaShine.LoadImage("assets/image/cbf/01_yukata_unidolized_game_3.png"),
		YOU_YUKATA_IDOL = AquaShine.LoadImage("assets/image/cbf/01_yukata_idolized_game_2.png"),
		MAKI_POOL = AquaShine.LoadImage("assets/image/cbf/01_pool_unidolized_game_2.png"),
		MAKI_POOL_IDOL = AquaShine.LoadImage("assets/image/cbf/01_pool_idolized_game.png"),
		RUBY_GOTHIC = AquaShine.LoadImage("assets/image/cbf/01_gothic_unidolized_game.png"),
		RUBY_GOTHIC_IDOL = AquaShine.LoadImage("assets/image/cbf/01_gothic_idolized_game.png"),
		YOSHIKO_HALLOWEEN = AquaShine.LoadImage("assets/image/cbf/01_halloween_unidolized_game.png"),
		YOSHIKO_HALLOWEEN_IDOL = AquaShine.LoadImage("assets/image/cbf/01_halloween_idolized_game_2.png"),
		MARI_HALLOWEEN_IDOL = AquaShine.LoadImage("assets/image/cbf/01_halloween_idolized_game.png"),
		RIKO_HALLOWEEN_IDOL = AquaShine.LoadImage("assets/image/cbf/01_halloween_idolized_game_3.png"),
		HANAMARU_YUKATA = AquaShine.LoadImage("assets/image/cbf/02_yukata_unidolized_game.png")
	}
	
	IconCache = {
		None = {
			UR = {
				AquaShine.LoadImage("assets/image/cbf/star4circleUREmpty.png"),
				AquaShine.LoadImage("assets/image/cbf/star4foreURSmile_empty.png")
			},
			["UR (Old)"] = {
				AquaShine.LoadImage("assets/image/cbf/star4circleURCustom_Old.png"),
				AquaShine.LoadImage("assets/image/cbf/star4foreURSmile_empty.png")
			},
			SR = {
				AquaShine.LoadImage("assets/image/cbf/star4circleSR_Custom.png"),
				AquaShine.LoadImage("assets/image/cbf/star4circleSR_Custom_fore.png")
			},
			R = {
				AquaShine.LoadImage("assets/image/cbf/star4circleR_Custom.png"),
				AquaShine.LoadImage("assets/image/cbf/star4circleR_Custom_fore.png")
			},
		},
		Smile = {
			UR = {
				AquaShine.LoadImage("assets/image/cbf/star4circleURSmile.png"),
				AquaShine.LoadImage("assets/image/cbf/star4foreURSmile.png")
			},
			["UR (Old)"] = {
				AquaShine.LoadImage("assets/image/cbf/star4circleURSmile_Old.png"),
				AquaShine.LoadImage("assets/image/cbf/star4foreURSmile.png")
			},
			SSR = {
				AquaShine.LoadImage("assets/image/cbf/star4circleSSRSmile.png"),
				AquaShine.LoadImage("assets/image/cbf/star4foreSRSmileIdolized.png")
			},
			SR = {
				AquaShine.LoadImage("assets/image/cbf/star4circleSRSmile.png"),
				AquaShine.LoadImage("assets/image/cbf/star4foreSRSmileIdolized.png")
			},
		},
		Pure = {
			UR = {
				AquaShine.LoadImage("assets/image/cbf/star4circleURPure.png"),
				AquaShine.LoadImage("assets/image/cbf/star4foreURPure.png")
			},
			["UR (Old)"] = {
				AquaShine.LoadImage("assets/image/cbf/star4circleURPure_Old.png"),
				AquaShine.LoadImage("assets/image/cbf/star4foreURPure.png")
			},
			SSR = {
				AquaShine.LoadImage("assets/image/cbf/star4circleSSRPure.png"),
				AquaShine.LoadImage("assets/image/cbf/star4foreSRPureIdolized.png")
			},
			SR = {
				AquaShine.LoadImage("assets/image/cbf/star4circleSRPure.png"),
				AquaShine.LoadImage("assets/image/cbf/star4foreSRPureIdolized.png")
			},
		},
		Cool = {
			UR = {
				AquaShine.LoadImage("assets/image/cbf/star4circleURCool.png"),
				AquaShine.LoadImage("assets/image/cbf/star4foreURCool.png")
			},
			["UR (Old)"] = {
				AquaShine.LoadImage("assets/image/cbf/star4circleURCool_Old.png"),
				AquaShine.LoadImage("assets/image/cbf/star4foreURCool.png")
			},
			SSR = {
				AquaShine.LoadImage("assets/image/cbf/star4circleSSRCool.png"),
				AquaShine.LoadImage("assets/image/cbf/star4foreSRCoolIdolized.png")
			},
			SR = {
				AquaShine.LoadImage("assets/image/cbf/star4circleSRCool.png"),
				AquaShine.LoadImage("assets/image/cbf/star4foreSRCoolIdolized.png")
			},
		},
	}

	function ComposeUnitImage(color_type, rarity, chara_name, r, g, b)
		-- chara_name can be nil
		-- r, g, b are in float
		if chara_name and #chara_name == 0 then chara_name = nil end
		
		local cl = {}
		local da
		local img
		
		if color_type == "Custom" then
			da = IconCache.None
			img = assert(da[rarity], "Invalid rarity")
			
			cl[#cl + 1] = {love.graphics.setColor, r * 255, g * 255, b * 255}
			cl[#cl + 1] = {love.graphics.draw, img[2]}
			
			if chara_name and UnitIconCache[chara_name] then
				cl[#cl + 1] = {love.graphics.setColor, 255, 255, 255}
				cl[#cl + 1] = {love.graphics.draw, UnitIconCache[chara_name]}
				cl[#cl + 1] = {love.graphics.setColor, r * 255, g * 255, b * 255}
			end
			
			cl[#cl + 1] = {love.graphics.draw, img[1]}
		else
			da = assert(IconCache[color_type], "Invalid attribute")
			img = assert(da[rarity], "Invalid rarity")
			
			cl[#cl + 1] = {love.graphics.setColor, 255, 255, 255}
			cl[#cl + 1] = {love.graphics.draw, img[2]}
			
			if chara_name and UnitIconCache[chara_name] then
				cl[#cl + 1] = {love.graphics.draw, UnitIconCache[chara_name]}
			end
			
			cl[#cl + 1] = {love.graphics.draw, img[1]}
		end
		
		return AquaShine.ComposeImage(128, 128, cl)
	end

	-- Look at "Cards" folder for custom cards
	function LoadUnitStrategy1(file)
		if love.filesystem.isDirectory(file[1].."/Cards") then
			setmetatable(UnitIconCache, {
				__index = function(_, var)
					local name = file[1].."/Cards/"..var..".png"
					
					if love.filesystem.isFile(name) then
						local x = love.graphics.newImage(name)
						
						UnitIconCache[var] = x
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
	function LoadUnitStrategy2(file)
		local listname = file[1].."/Custom Cards/list.txt"
		if
			love.filesystem.isDirectory(file[1].."/Custom Cards") and
			love.filesystem.isFile(listname)
		then
			for line in love.filesystem.lines(listname) do
				if #line > 0 then
					local idx = line:match("([^/]+)/[^;]+")
					local _, img = pcall(love.graphics.newImage, file[1].."/Custom Cards/"..idx..".png")
					
					if _ then
						UnitIconCache[idx] = img
					end
				end
			end
			
			return true
		end
		
		return false
	end
end

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
		AquaShine.MountZip(zip, file[1])
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
	local desired_attribute
	
	if cbf.SONG_ATTRIBUTE == "Smile" then
		desired_attribute = 1
	elseif cbf.SONG_ATTRIBUTE == "Pure" then
		desired_attribute = 2
	elseif cbf.SONG_ATTRIBUTE == "Cool" then
		desired_attribute = 3
	else
		desired_attribute = AquaShine.LoadConfig("LLP_SIFT_DEFATTR", 1)
	end
	
	local readed_notes_data = {}
	local hold_note_queue = {}

	for line in cbf.beatmap:lines() do
		if #line > 0 then
			readed_notes_data[#readed_notes_data + 1] = line
		end
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
		
		if time and pos and is_hold and is_release and release_time and hold_time and is_star and r and g and b and is_customcol then
			local num_pos = position_translation[pos]
			local attri = desired_attribute
			release_time = tonumber(release_time)
			hold_time = tonumber(hold_time)
			
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
		else
			io.write("[CBF Beatmap] Ignored", line, "\n")
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
	
	-- Load units
	local units = {}
	local has_custom_units = false
	
	if UnitLoadingAllowed then
		local charposname = file[1].."/characterPositions.txt"
		
		if love.filesystem.isFile(charposname) then
			-- Initialize units image
			if not(LoadUnitStrategy1(file)) then
				LoadUnitStrategy2(file)
			end
			
			-- If loading from "Cards" folder and "Custom Cards" folder fails,
			-- Load in current beatmap directory instead or in unit_icon folder
			local index_name = getmetatable(UnitIconCache)
			if index_name then index_name = index_name.__index end
			
			setmetatable(UnitIconCache, {
				__index = function(_, var)
					if index_name then
						local ret = index_name(_, var)
						
						if ret then
							return ret
						end
					end
					
					local name = file[1].."/"..var..".png"
					local name2 = "unit_icon/"..var..".png"
					local x = nil
					
					if love.filesystem.isFile(name) then
						x = love.graphics.newImage(name)
					elseif love.filesystem.isFile(name2) then
						x = love.graphics.newImage(name2)
					end
					
					UnitIconCache[var] = x
					return x
				end
			})
			
			
			for line in love.filesystem.lines(charposname) do
				if #line > 0 then
					local cache_name = line:sub(line:find("/") + 1)
					local pos, attr, rar, cname, r, g, b = line:match("([^/]+)/([^/]+)/([^/]+)/([^/]*)/(%d+%.?%d*),(%d+%.?%d*),(%d+%.?%d*)/")
					local i = assert(position_translation[pos])
					
					if CompositionCache[cache_name] then
						units[i] = CompositionCache[cache_name]
						has_custom_units = true
					else
						local a = ComposeUnitImage(attr, rar, cname, r, g, b)
						
						units[i] = a
						CompositionCache[cache_name] = a
						has_custom_units = true
					end
				end
			end
		end
	end
	
	-- Result
	local out = {
		notes_list = notes_data,
		song_file = AquaShine.LoadAudio(file[1].."/songFile.wav")
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
			local cover = {image = love.graphics.newImage(fn)}
			
			cover.title = cbf.SONG_NAME
			cover.arrangement = cbf.COVER_COMMENT or ""
			out.cover = cover
			
			break
		end
	end
	
	-- Get live clear SFX
	local live_clear_sound = AquaShine.LoadAudio(file[1].."/liveShowClearSFX.wav")
	
	if live_clear_sound then
		out.live_clear = love.audio.newSource(live_clear_sound)
	end
	
	return out
end

return CBFBeatmap
