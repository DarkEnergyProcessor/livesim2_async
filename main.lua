-- DEP LS (Pronounced Deep Less), Live Simulator.
local pairs = pairs
local math = math
local coroutine = coroutine
local string = string
local table = table
local love = love
local List
local JSON
local tween
local graphics	-- love.graphics
local effect_player
local backgound_image	-- background image handle
local background_dim = {tween = nil, opacity = 0}	-- for tween
local live_header = {}	-- Live header image handle lists
local tap_sound	-- tap sound handle (SE_306.ogg)
local idol_image_handle = {}	-- idol image handle
local idol_image_pos = {	-- idol image position
	{16 , 96 },
	{46 , 249},
	{133, 378},
	{262, 465},
	{416, 496},
	{569, 465},
	{698, 378},
	{785, 249},
	{816, 96 }
}
-- local notes_moving_angle = {90, 112.46575563415, 134.89859164657, 157.34706707977, 180, -157.4794343971, -135, -112.5205656029, -90}
local livesim_delay = LIVESIM_DELAY or 1000
local notes_list			-- SIF format notes list
local BEATMAP_AUDIO			-- beatmap audio handle
local BEATMAP_NAME = nil	-- name of the beatmap to be loaded
local tap_circle_image		-- Tap circle image handle.
local start_livesim = livesim_delay	-- used internally (delay)
local __arg					-- Used to reset state
local elapsed_time = -livesim_delay
local DEBUG_SWITCH = false
local NOTES_QUEUE = {}
local DEBUG_FONT
local DEBUG_FONT_OUTLINE_SHADER
local audio_playing = false
local NOTE_LOADER			-- Note loader function
local stamina_number_image = {}	-- Stamina number image
local stamina_bar_image		-- Stamina bar image
local current_score = 0	-- Score tracking
local current_combo = 0		-- Combo tracking
local NOTE_SPEED = NOTE_SPEED
local combo_system = {replay_animation = false, img = {}}
local score_eclipsef = {replay_animation = false}
local score_node = {img = {}}
local perfect_node = {replay_animation = false}
local noteicon_anim = {}
local SAVE_DIR

function path_save_dir(path)
	return love.filesystem.getSaveDirectory().."/"..path
end

function file_get_contents(path)
	local f = io.open(path)
	
	if not(f) then return nil end
	
	local r = f:read("*a")
	
	f:close()
	return r
end

local function load_token_note(path)
	local _, token_image = pcall(love.graphics.newImage, path)
	
	if _ == false then return nil
	else return token_image end
end

local function substitute_extension(file, ext_without_dot)
	return file:sub(1,((file:find("%.[^%.]*$")) or #file+1)-1).."."..ext_without_dot
end

local function load_audio_safe(path, noorder)
	local _, token_image
	
	if not(noorder) then
		local a = load_audio_safe(substitute_extension(path, "wav"), true)
		
		if a == nil then
			return load_audio_safe(substitute_extension(path, "ogg"), true)
		end
	end
	
	-- Try save dir
	do
		local file = love.filesystem.newFile(path)
		
		if file then
			_, token_image = pcall(love.audio.newSource, path, "static")
			
			if _ then
				return token_image
			end
		end
	end
	
	_, token_image = pcall(love.audio.newSource, path, "static")
	
	if _ == false then return nil
	else return token_image end
end

local function cubicbezier(x1, y1, x2, y2)
	local curve = love.math.newBezierCurve(0, 0, x1, y1, x2, y2, 1, 1)
	return function (t, b, c, d) return c * curve:evaluate(t/d) + b end
end

local load_unit_icon
do
	local dummy_image
	local list = {}
	
	load_unit_icon = function(path)
		if list[path] then
			return list[path]
		end
		
		if dummy_image == nil then
			dummy_image = love.graphics.newImage("image/dummy.png")
		end
		
		if path == nil then return dummy_image end
		
		local filedata = love.filesystem.newFileData("unit_icon/"..path)
		
		if not(filedata) then
			return dummy_image
		end
		
		local _, img = pcall(love.graphics.newImage, filedata)
		
		if _ == false then
			return dummy_image
		end
		
		list[path] = img
		return img
	end
end

score_eclipsef.routine = coroutine.wrap(function()
	local deltaT
	local eclipse_data = {scale = 1, opacity = 255}
	local eclipse_tween = tween.new(500, eclipse_data, {scale = 1.6, opacity = 0}, "outSine")
	local bar_data = {opacity = 255}
	
	bar_data.tween = tween.new(300, bar_data, {opacity = 0})
	
	-- Seek to end
	eclipse_tween:update(500)
	bar_data.tween:update(300)
	
	while true do
		deltaT = coroutine.yield()		-- love.update part
		
		if score_eclipsef.replay_animation then
			eclipse_tween:reset()
			bar_data.tween:reset()
			score_eclipsef.replay_animation = false
		end
		
		coroutine.yield()	-- love.draw part
		
		if eclipse_tween:update(deltaT) == false then
			graphics.setColor(255, 255, 255, eclipse_data.opacity)
			graphics.draw(score_eclipsef.img, 484, 72, 0, eclipse_data.scale, eclipse_data.scale, 159, 34)
		end
		
		if bar_data.tween:update(deltaT) == false then
			graphics.setColor(255, 255, 255, bar_data.opacity)
			graphics.draw(score_eclipsef.img2, 5, 8)
		end
		
		graphics.setColor(255, 255, 255, 255)
	end
end)

perfect_node.routine = coroutine.wrap(function()
	local deltaT
	local et = 500
	local perfect_data = {opacity = 0, scale = 0}
	local perfect_tween = tween.new(50, perfect_data, {opacity = 255, scale = 2}, "outSine")
	local perfect_tween_fadeout = tween.new(200, perfect_data, {opacity = 0})
	perfect_tween:update(50)
	perfect_tween_fadeout:update(200)
	
	while true do
		deltaT = coroutine.yield()
		et = et + deltaT
		-- love.update
		
		if perfect_node.replay_animation then
			et = deltaT
			perfect_tween:reset()
			perfect_tween_fadeout:reset()
			perfect_node.replay_animation = false
		end
		
		perfect_tween:update(deltaT)
		
		if et > 200 then
			perfect_tween_fadeout:update(deltaT)
		end
		
		-- To prevet overflow
		if et > 5000 then
			et = et - 4000
		end
		
		coroutine.yield()
		-- love.draw
		
		if et < 500 then
			graphics.setColor(255, 255, 255, perfect_data.opacity)
			graphics.draw(perfect_node.img, 480, 320, 0, perfect_data.scale, perfect_data.scale, 99, 19)
			graphics.setColor(255, 255, 255, 255)
		end
	end
end)

noteicon_anim.circleroutine = function()
	local deltaT
	local circ_data = {scale = 0.6, opacity = 255}
	local circ_tween = tween.new(1600, circ_data, {scale = 2.5, opacity = 0})
	
	while true do
		deltaT = coroutine.yield()
		
		if circ_tween:update(deltaT) == true then
			break
		end
		
		graphics.setColor(255, 255, 255, circ_data.opacity)
		graphics.draw(noteicon_anim.img2, 480, 160, 0, circ_data.scale, circ_data.scale, 34, 34)
		graphics.setColor(255, 255, 255, 255)
	end
	
	while true do coroutine.yield(true) end
end

noteicon_anim.routine = coroutine.wrap(function()
	local deltaT
	local et = 0
	local noteicon_data = {scale = 1}
	local noteicon_tween = tween.new(800, noteicon_data, {scale = 0.8})
	local noteicon_tween2 = tween.new(1200, noteicon_data, {scale = 1}, "outSine")
	local active_tween = noteicon_tween
	local circledraw_time = {0, 300, 600}
	
	while true do
		deltaT = coroutine.yield()
		
		if deltaT then
			et = et + deltaT
			
			if et >= 2000 then
				et = et - 2000
				noteicon_tween:reset()
				noteicon_tween2:reset()
				active_tween = noteicon_tween
				circledraw_time[1] = 0
				circledraw_time[2] = 300
				circledraw_time[3] = 600
			end
			
			if active_tween:update(deltaT) == true then
				active_tween = noteicon_tween2
			end
			
			-- Draw circle
			for i = 1, 3 do
				circledraw_time[i] = circledraw_time[i] - deltaT
				
				if circledraw_time[i] <= 0 then
					local cr = coroutine.wrap(noteicon_anim.circleroutine)
					effect_player.spawn(cr)
					cr()
					circledraw_time[i] = 1234567
				end
			end
			
			-- love.draw
			coroutine.yield()
			graphics.draw(noteicon_anim.img, 480, 160, 0, noteicon_data.scale, noteicon_data.scale, 54, 52)
		end
	end
end)

-- Score updater routine
local score_update_coroutine = coroutine.wrap(function(deltaT)
	local score_str = {string.byte(tostring(current_score), 1, 2147483647)}
	local score_images = {}
	local score_digit_len = 0
	local xpos
	
	for i = 0, 9 do
		score_images[i] = love.graphics.newImage("image/score_num/l_num_0"..i..".png")
	end
	
	while true do
		deltaT = coroutine.yield()
		
		score_str = {string.byte(tostring(current_score), 1, 2147483647)}
		score_digit_len = #score_str
		xpos = 448 - 16 * score_digit_len
		
		coroutine.yield()
		
		for i = 1, score_digit_len do
			graphics.draw(score_images[score_str[i] - 48], xpos + 32 * i, 53)
		end
	end
end)

local function sine_tween_func(t, b, c, d)
	return c * (math.floor(math.sin(t/d * math.pi) * 1000000) / 1000000) + b
end

-- Added score update routine
score_node.routine = function(score)
	local score_canvas = graphics.newCanvas(500, 32)
	local score_info = {opacity = 0, scale = 0.85, x = 518}
	local opacity_tw = tween.new(100, score_info, {opacity = 255})
	local scale_tw = tween.new(200, score_info, {scale = 1}, "inOutSine")
	local xpos_tw = tween.new(250, score_info, {x = 580}, "inOutSine")
	local deltaT
	local elapsed_time = 0
	
	-- Draw all in canvas
	graphics.setCanvas(score_canvas)
	graphics.setBlendMode("alpha", "premultiplied")
	graphics.draw(score_node.img.plus)
	
	do
		local i = 1
		for w in tostring(score):gmatch("%d") do
			graphics.draw(score_node.img[tonumber(w)], i * 24, 0)
			i = i + 1
		end
	end
	graphics.setBlendMode("alpha")
	graphics.setCanvas()
	
	deltaT = coroutine.yield()
	elapsed_time = elapsed_time + deltaT
	
	while elapsed_time < 500 do
		xpos_tw:update(deltaT)
		opacity_tw:update(elapsed_time > 350 and -deltaT or deltaT)
		scale_tw:update(elapsed_time > 200 and -deltaT or deltaT)
		
		graphics.setColor(255, 255, 255, score_info.opacity)
		graphics.draw(score_canvas, score_info.x, 72, 0, score_info.scale, score_info.scale, 0, 16)
		graphics.setColor(255, 255, 255, 255)
		
		deltaT = coroutine.yield()
		elapsed_time = elapsed_time + deltaT
	end
	
	while true do coroutine.yield(true) end	-- Stop
end

local function add_score(score_val)
	-- Combo calculation starts here
	local added_score = score_val
	
	if current_combo < 50 then
		added_score = added_score
	elseif current_combo < 100 then
		added_score = added_score * 1.1
	elseif current_combo < 200 then
		added_score = added_score * 1.15
	elseif current_combo < 400 then
		added_score = added_score * 1.2
	elseif current_combo < 600 then
		added_score = added_score * 1.25
	elseif current_combo < 800 then
		added_score = added_score * 1.3
	else
		added_score = added_score * 1.35
	end
	
	added_score = math.floor(added_score + 0.5)
	
	current_score = current_score + added_score
	score_eclipsef.replay_animation = true
	perfect_node.replay_animation = true
	
	local score_routine_eff = coroutine.wrap(score_node.routine)
	score_routine_eff(added_score)
	effect_player.spawn(score_routine_eff)
end

local function get_combo_color_index(combo)
	if combo < 50 then
		-- 0-49
		return 1
	elseif combo < 100 then
		-- 50-99
		return 2
	elseif combo < 200 then
		-- 100-199
		return 3
	elseif combo < 300 then
		-- 200-299
		return 4
	elseif combo < 400 then
		-- 300-399
		return 5
	elseif combo < 500 then
		-- 400-499
		return 6
	elseif combo < 600 then
		-- 500-599
		return 7
	elseif combo < 1000 then
		-- 600-999
		return 8
	else
		-- >= 1000
		return 9
	end
end

combo_system.draw_routine = coroutine.wrap(function()
	local deltaT
	local combo_scale = {s = 0.85}
	local combo_tween = tween.new(100, combo_scale, {s = 1}, function(t, b, c, d) return c * (1 - math.cos(t / d * math.pi) * 0.5 - 0.5) + b end)
	
	while true do
		deltaT = coroutine.yield()	-- love.update part
		
		if combo_system.replay_animation then
			combo_tween:reset()
			combo_system.replay_animation = false
		end
		
		-- Don't draw if combo is 0
		if current_combo > 0 then
			-- "combo" pos: 541x267+61+17
			-- number pos: 451x267+24+24; aligh right; subtract by 43 for distance
			combo_tween:update(deltaT)
			
			local combo_str = {string.byte(tostring(current_combo), 1, 2147483647)}
			local img = combo_system.img[get_combo_color_index(current_combo)]
			
			coroutine.yield()	-- love.draw part
			
			for i = 1, #combo_str do
				-- Draw numbers
				graphics.draw(img[combo_str[i] - 47], 451 - (#combo_str - i) * 43, 267, 0, combo_scale.s, combo_scale.s, 24, 24)
			end
			
			graphics.draw(img.combo, 541, 267, 0, combo_scale.s, combo_scale.s, 61, 17)
		else
			coroutine.yield()	-- draw nothing
		end
	end
end)

local function circletap_effect_routine(position)
	local deltaT
	local el_t = 0
	local circle = tap_circle_image.ef_316_001
	local stareff = tap_circle_image.ef_316_000
	local circle1_data = {scale = 2, opacity = 255}
	local circle2_data = {scale = 2, opacity = 255}
	local stareff_data = {opacity = 255}
	local circle1_tween = tween.new(125, circle1_data, {scale = 3.5, opacity = 0})
	local circle2_tween = tween.new(200, circle2_data, {scale = 3.5, opacity = 0})
	local stareff_tween = tween.new(200, stareff_data, {opacity = 0}, "inQuad")
	local pos = {idol_image_pos[position][1] + 64, idol_image_pos[position][2] + 64}
	
	while true do
		local still_has_render = false
		deltaT = coroutine.yield()
		el_t = el_t + deltaT
		
		if circle1_tween and circle1_tween:update(deltaT) == false then
			-- graphics.draw(drawn_circle, x, y, 0, s, s, 64, 64)
			still_has_render = true
			graphics.setColor(255, 255, 255, circle1_data.opacity)
			graphics.draw(circle, pos[1], pos[2], 0, circle1_data.scale, circle1_data.scale, 37.5, 37.5)
			graphics.setColor(255, 255, 255, 255)
		else
			circle1_tween = nil
		end
		
		if circle2_tween and circle2_tween:update(deltaT) == false then
			still_has_render = true
			graphics.setColor(255, 255, 255, circle2_data.opacity)
			graphics.draw(circle, pos[1], pos[2], 0, circle2_data.scale, circle2_data.scale, 37.5, 37.5)
			graphics.setColor(255, 255, 255, 255)
		else
			circle2_tween = nil
		end
		
		if el_t >= 75 and stareff_tween:update(deltaT) == false then
			still_has_render = true
			graphics.setColor(255, 255, 255, stareff_data.opacity)
			graphics.draw(stareff, pos[1], pos[2], 0, 1.5, 1.5, 50, 50)
			graphics.setColor(255, 255, 255, 255)
		end
		
		if still_has_render == false then
			break
		end
	end
	
	while true do
		coroutine.yield(true)	-- Tell effect player to remove this
	end
end

local function distance(a, b)
	return math.sqrt(a ^ 2 + b ^ 2)
end

local function angle_from(x1, y1, x2, y2)
	return math.atan2(y2 - y1, x2 - x1) - math.pi / 2
end

-- Note drawing coroutine
local function circletap_drawing_coroutine(note_data, simul_note_bit)
	local pos = 10 - note_data.position
	local note_draw = {scale = 0, x = 480, y = 160}
	local note_tween = tween.new(NOTE_SPEED, note_draw, {
		scale = 1, x = idol_image_pos[pos][1] + 64, y = idol_image_pos[pos][2] + 64
	})
	local time_elapsed = 0
	local circle_sound = tap_sound:clone()
	local star_note_bit = note_data.effect == 4
	local long_note_bit = note_data.effect == 3
	local token_note_bit = note_data.effect == 2
	local drawn_circle
	local longnote_data = {}
	local off_time = NOTE_SPEED
	local score = long_note_bit and (SCORE_ADD_NOTE * 1.25) or SCORE_ADD_NOTE
	local drawing_order = {}
	local first_note_done_rendering = false
	
	if RANDOM_NOTE_IMAGE then
		drawn_circle = tap_circle_image[math.random(1, 10)]
	else
		drawn_circle = tap_circle_image[note_data.notes_attribute]
	end
	
	if long_note_bit then
		longnote_data.direction = angle_from(480, 160, idol_image_pos[pos][1] + 64, idol_image_pos[pos][2] + 64)
		longnote_data.last_circle = {scale = 0, x = 480, y = 160}
		longnote_data.last_circle_tween = tween.new(NOTE_SPEED, longnote_data.last_circle, {
			scale = 1, x = idol_image_pos[pos][1] + 64, y = idol_image_pos[pos][2] + 64
		})
		longnote_data.duration = note_data.effect_value * 1000
		longnote_data.sound = tap_sound:clone()
		longnote_data.first_sound_play = false
		
		off_time = off_time + longnote_data.duration
	end
	
	local deltaT = coroutine.yield(score)	-- Should be in ms
	time_elapsed = time_elapsed + deltaT
	
	while time_elapsed < off_time do
		if first_note_done_rendering == false then
			first_note_done_rendering = note_tween:update(deltaT)
		elseif not(longnote_data.first_sound_play) then
			circle_sound:play()
			longnote_data.first_sound_play = true
		end
		
		local x = math.floor(note_draw.x + 0.5)
		local y = math.floor(note_draw.y + 0.5)
		local s = note_draw.scale
		local spawn_ln_end = time_elapsed >= off_time - NOTE_SPEED
		
		if long_note_bit then
			-- Draw long note indicator first
			local popn_scale_y = distance(longnote_data.last_circle.x - note_draw.x, longnote_data.last_circle.y - note_draw.y) / 256
			
			if spawn_ln_end then
				-- Start tweening
				longnote_data.last_circle_tween:update(deltaT)
			end
			
			local s2 = longnote_data.last_circle.scale
			
			local vert = {
				-- First position
				math.floor((note_draw.x + (s * 60) * math.cos(longnote_data.direction)) + 0.5),	-- x
				math.floor((note_draw.y + (s * 60) * math.sin(longnote_data.direction)) + 0.5),	-- y
				-- Second position
				math.floor((note_draw.x + (s * 60) * math.cos(longnote_data.direction - math.pi)) + 0.5),	-- x
				math.floor((note_draw.y + (s * 60) * math.sin(longnote_data.direction - math.pi)) + 0.5),	-- y
				-- Third position
				math.floor((longnote_data.last_circle.x + (s2 * 60) * math.cos(longnote_data.direction - math.pi)) + 0.5),	-- x
				math.floor((longnote_data.last_circle.y + (s2 * 60) * math.sin(longnote_data.direction - math.pi)) + 0.5),	-- y
				-- Fourth position
				math.floor((longnote_data.last_circle.x + (s2 * 60) * math.cos(longnote_data.direction)) + 0.5),	-- x
				math.floor((longnote_data.last_circle.y + (s2 * 60) * math.sin(longnote_data.direction)) + 0.5),	-- y
			}
			
			drawing_order[#drawing_order + 1] = {graphics.setColor, 255, 255, 255, 127}
			drawing_order[#drawing_order + 1] = {graphics.polygon, "fill", vert[1], vert[2], vert[3], vert[4], vert[5], vert[6]}
			drawing_order[#drawing_order + 1] = {graphics.polygon, "fill", vert[5], vert[6], vert[7], vert[8], vert[1], vert[2]}
			drawing_order[#drawing_order + 1] = {graphics.setColor, 255, 255, 255, 255}
			
			drawing_order[#drawing_order + 1] = {graphics.draw, drawn_circle, x, y, 0, s, s, 64, 64} -- Draw tap circle BEFORE end long note indicator
			
			if spawn_ln_end then
				drawing_order[#drawing_order + 1] = {graphics.draw, tap_circle_image.endlongnote, longnote_data.last_circle.x, longnote_data.last_circle.y, 0, s2, s2, 64, 64}
			end
		
		else
			drawing_order[#drawing_order + 1] = {graphics.draw, drawn_circle, x, y, 0, s, s, 64, 64}		-- Draw tap circle
		end
		
		if token_note_bit and tap_circle_image.tokennote then
			drawing_order[#drawing_order + 1] = {graphics.draw, tap_circle_image.tokennote, x, y, 0, s, s, 64, 64}	-- Layer token note
		end
		
		if simul_note_bit then
			drawing_order[#drawing_order + 1] = {graphics.draw, tap_circle_image.simulnote, x, y, 0, s, s, 64, 64}	-- Layer simul note
		end
		
		if star_note_bit then
			drawing_order[#drawing_order + 1] = {graphics.draw, tap_circle_image.starnote, x, y, 0, s, s, 64, 64}		-- Layer star note
		end
		
		coroutine.yield(score)
		
		-- Draw
		for i = 1, #drawing_order do
			local x = drawing_order[i]
			local f = table.remove(x, 1)
			f(unpack(x))
		end
		drawing_order = {}
		
		deltaT = coroutine.yield(score)
		time_elapsed = time_elapsed + deltaT
	end
	
	current_combo = current_combo + 1
	combo_system.replay_animation = true
	
	if long_note_bit then
		longnote_data.sound:play()
	else
		circle_sound:play()
	end
	
	local aftertap = coroutine.wrap(circletap_effect_routine)
	aftertap(pos)	-- Initialize circletap effect
	effect_player.spawn(aftertap)	-- Then add to effect list
	
	while true do coroutine.yield(score) end
end

-- Initialization function
function love.load(argv)
	math.randomseed(os.time())
	
	SAVE_DIR = love.filesystem.getSaveDirectory()
	love.filesystem.createDirectory("audio")
	love.filesystem.createDirectory("beatmap")
	print("R/W Directory: "..SAVE_DIR)
	
	-- Initialize libraries
	__arg = argv
	ROOT_DIR = love.filesystem.getRealDirectory("main.lua")
	JSON = require("JSON")
	tween = require("tween")
	List = require("List")
	effect_player = require("effect_player")
	graphics = love.graphics
	BEATMAP_NAME = argv[2]
	NOTE_SPEED = (tonumber(argv[4] or "") or NOTE_SPEED) * 1000
	NOTE_LOADER = require("note_loader")
	
	if BEATMAP_NAME then
		-- Load beatmap
		notes_list = NOTE_LOADER(path_save_dir("beatmap/"..BEATMAP_NAME..".json"))
		--NOTES_QUEUE = List.new()
		
		-- Load beatmap audio
		BEATMAP_AUDIO = load_audio_safe("audio/"..(argv[3] or BEATMAP_NAME), not(not(argv[3])))
		
		-- Load perfect sound
		tap_sound = love.audio.newSource("sound/SE_306.ogg", "static")
		
		-- Load background
		background_image = love.graphics.newImage(BACKGROUND_IMAGE)
		background_dim.tween = tween.new(livesim_delay, background_dim, {opacity = 170})
		
		-- Load live header
		live_header.header = love.graphics.newImage("image/live_header.png")
		live_header.score_gauge = love.graphics.newImage("image/live_gauge_03_02.png")
		
		-- Load idol images
		for i = 1, 9 do
			idol_image_handle[i] = load_unit_icon(IDOL_IMAGE[i])
		end
		
		-- Load tap circle data
		tap_circle_image = {
			love.graphics.newImage("image/tap_circle/tap_circle-0.png"),
			love.graphics.newImage("image/tap_circle/tap_circle-4.png"),
			love.graphics.newImage("image/tap_circle/tap_circle-8.png"),
			love.graphics.newImage("image/tap_circle/tap_circle-12.png"),
			love.graphics.newImage("image/tap_circle/tap_circle-16.png"),
			love.graphics.newImage("image/tap_circle/tap_circle-20.png"),
			love.graphics.newImage("image/tap_circle/tap_circle-24.png"),
			love.graphics.newImage("image/tap_circle/tap_circle-28.png"),
			love.graphics.newImage("image/tap_circle/tap_circle-32.png"),
			love.graphics.newImage("image/tap_circle/tap_circle-36.png"),
			love.graphics.newImage("image/tap_circle/tap_circle-40.png"),
			
			-- Tap circle layering
			display = love.graphics.newImage("image/popn.png"),
			simulnote = love.graphics.newImage("image/tap_circle/ef_315_timing_1.png"),
			starnote = love.graphics.newImage("image/tap_circle/ef_315_effect_0004.png"),
			endlongnote = love.graphics.newImage("image/tap_circle/tap_circle-44.png"),
			tokennote = load_token_note(argv[4] or TOKEN_IMAGE),
			
			-- Tap circle effect
			ef_316_000 = love.graphics.newImage("image/ef_316_000.png"),
			ef_316_001 = love.graphics.newImage("image/ef_316_001.png")
		}
		
		-- Load stamina bar
		stamina_bar_image = love.graphics.newImage("image/live_gauge_02_02.png")
		
		-- Load stamina number images
		do
			local stamina_display_str = tostring(STAMINA_DISPLAY)
			local matcher = stamina_display_str:gmatch("%d")
			local temp
			local temp_num
			
			stamina_number_image.draw_target = {}
			
			for i = 1, #stamina_display_str do
				temp = matcher()
				temp_num = tonumber(temp)
				
				if stamina_number_image[temp_num] == nil then
					stamina_number_image[temp_num] = love.graphics.newImage("image/hp_num/live_num_"..temp..".png")
				end
				
				stamina_number_image.draw_target[i] = stamina_number_image[temp_num]
			end
		end
		
		-- Load combo number images
		combo_system.img = require("combo_num")
		
		-- Load score eclipse
		score_eclipsef.img = love.graphics.newImage("image/l_etc_46.png")
		score_eclipsef.img2 = love.graphics.newImage("image/l_gauge_17.png")
		
		-- Load score node number
		for i = 21, 30 do
			score_node.img[i - 21] = love.graphics.newImage("image/score_num/l_num_"..i..".png")
		end
		score_node.img.plus = love.graphics.newImage("image/score_num/l_num_31.png")
		
		-- PERFECT text
		perfect_node.img = love.graphics.newImage("image/ef_313_004.png")
		perfect_node.routine()
		
		-- Note spawning position
		noteicon_anim.img = love.graphics.newImage("image/ef_308_000.png")
		noteicon_anim.img2 = love.graphics.newImage("image/ef_308_001.png")
		noteicon_anim.routine()
		
		-- Load font
		DEBUG_FONT = love.graphics.newFont("MTLmr3m.ttf", 24)
		DEBUG_FONT_OUTLINE_SHADER = love.graphics.newShader("outline_shader.glsl")
	end
end

function love.draw()
	local deltaT = love.timer.getDelta() * 1000
	
	if BEATMAP_NAME then
		local livesim_started = start_livesim <= 0
		-- Draw background
		graphics.draw(background_image)	-- TODO: replace with background handler
		
		graphics.setColor(0, 0, 0, background_dim.opacity)
		graphics.rectangle("fill", 0, 0, 960, 640)
		graphics.setColor(255, 255, 255, 255)
		
		if livesim_started then
			-- Draw header
			graphics.draw(live_header.header)
			graphics.draw(live_header.score_gauge, 5, 8, 0, 0.99545454, 0.86842105)
			
			-- Draw idols
			for i = 1, 9 do
				graphics.draw(idol_image_handle[i], unpack(idol_image_pos[i]))
			end
			
			-- Draw stamina
			graphics.draw(stamina_bar_image, 14, 60)
			for i = 1, #stamina_number_image.draw_target do
				graphics.draw(stamina_number_image.draw_target[i], 290 + 16 * i, 66)
			end
			
			-- Draw score
			score_update_coroutine()
			
			-- Draw combo
			combo_system.draw_routine()
		end
		
		-- Draw notes
		for n, v in pairs(NOTES_QUEUE) do
			v.draw()
		end
		
		-- Draw PERFECT text
		perfect_node.routine()
		
		-- remove notes from queue
		local accumulative_score = 0
		
		while NOTES_QUEUE[1] do
			if elapsed_time > NOTES_QUEUE[1].endtime then
				accumulative_score = accumulative_score + table.remove(NOTES_QUEUE, 1).draw()
			else
				break
			end
		end
		
		if accumulative_score > 0 then
			add_score(accumulative_score)
		end
		
		-- Update effect player
		effect_player.update(deltaT)
		
		if livesim_started then
			score_eclipsef.routine()
			noteicon_anim.routine()
		end
		
		-- Print debug info if exist
		if DEBUG_SWITCH then
			local str = string.format([[
%d FPS
NOTE_SPEED = %d ms
AVAILABLE_NOTES = %d
QUEUED_NOTES = %d
CURRENT_COMBO = %d
RUNNING_EFFECT = %d
SAVE_DIR = %s
]], love.timer.getFPS(), NOTE_SPEED, notes_list.len, #NOTES_QUEUE, current_combo, #effect_player.list, SAVE_DIR)
			local oldfont = graphics.getFont()
			
			graphics.setFont(DEBUG_FONT)
			graphics.setColor(0, 0, 0, 255)
			graphics.print(str, 1, 1)
			graphics.setColor(255, 255, 255, 255)
			graphics.print(str)
			graphics.setFont(oldfont)
		end
	else
		graphics.print([[


Please specify beatmap in command-line when starting love2d
Usage: love livesim <beatmap>.json <sound=beatmap.wav> <notes speed = 0.8> <token note image = image/tap_circle/e_icon_08.png>
		]])
	end
end

function love.update(deltaT)
	deltaT = deltaT * 1000	-- In ms
	elapsed_time = elapsed_time + deltaT
	
	if BEATMAP_NAME then
		if start_livesim > 0 then
			start_livesim = start_livesim - deltaT
			background_dim.tween:update(deltaT)
		else
			if BEATMAP_AUDIO and audio_playing == false then
				BEATMAP_AUDIO:setVolume(0.9)
				BEATMAP_AUDIO:setLooping(false)
				BEATMAP_AUDIO:seek(math.max(elapsed_time / livesim_delay - 1, 0))
				BEATMAP_AUDIO:play()
				audio_playing = true
			end
			
			combo_system.draw_routine(deltaT)
			
			if notes_list:isempty() == false then
				-- Spawn notes
				local temp_note
				local added_notes = {}
				
				while notes_list:isempty() == false do
					temp_note = notes_list:popleft()
					if elapsed_time >= temp_note.timing_sec * 1000 - NOTE_SPEED then
						table.insert(added_notes, temp_note)
					else
						notes_list:pushleft(temp_note)
						break
					end
				end
				
				local simul_note = #added_notes > 1
				
				for n, v in pairs(added_notes) do
					local draw_func = coroutine.wrap(circletap_drawing_coroutine)
					local et = v.timing_sec * 1000
					
					if v.effect == 3 then
						et = et + v.effect_value * 1000
					end
					
					draw_func(v, simul_note)
					
					table.insert(NOTES_QUEUE, {
						draw = draw_func,
						endtime = et
					})
				end
			end
			
			local accumulative_score = 0
			
			-- Update notes (remove if necessary)
			for i = #NOTES_QUEUE, 1, -1 do
				local x = NOTES_QUEUE[i]
				x.draw(deltaT)
				
				if elapsed_time > x.endtime then
					accumulative_score = accumulative_score + table.remove(NOTES_QUEUE, i).draw()
				end
			end
			
			if accumulative_score > 0 then
				add_score(accumulative_score)
			end
			
			score_update_coroutine(deltaT)
			score_eclipsef.routine(deltaT)
			noteicon_anim.routine(deltaT)
		end
		
		perfect_node.routine(deltaT)
	end
end

function love.keypressed(key, scancode, repeat_bit)
	if repeat_bit == false then
		if key == "lshift" then
			DEBUG_SWITCH = not(DEBUG_SWITCH)
		elseif key == "backspace" then
			if BEATMAP_AUDIO then
				BEATMAP_AUDIO:stop()
			end
			
			-- Reset state
			dofile(ROOT_DIR.."/conf.lua")
			dofile(ROOT_DIR.."/main.lua")
			love.load(__arg)
		end
	end
end
