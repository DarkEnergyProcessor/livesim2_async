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
local notes_list			-- SIF format notes list
local BEATMAP_AUDIO			-- beatmap audio handle
local BEATMAP_NAME = nil	-- name of the beatmap to be loaded
local tap_circle_image		-- Tap circle image handle.
local start_livesim = 1000	-- used internally (delay)
local __arg					-- Used to reset state
local elapsed_time = -1000
local DEBUG_SWITCH = true
local __LSHIFT_REPEAT = false
local NOTES_QUEUE = {}
local DEBUG_FONT
local DEBUG_FONT_OUTLINE_SHADER
local audio_playing = false
local NOTE_LOADER			-- Note loader function
local stamina_number_image = {}	-- Stamina number image
local stamina_bar_image		-- Stamina bar image
local current_score = SCORE_DISPLAY_DEBUG or 0	-- Score tracking
local current_combo = 0		-- Combo tracking
local NOTE_SPEED = NOTE_SPEED
local combo_system = {replay_animation = false, img = {}}

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

local function load_audio_safe(path)
	local _, token_image = pcall(love.audio.newSource, path, "static")
	
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
	
	load_unit_icon = function(path)
		if dummy_image == nil then
			dummy_image = love.graphics.newImage("image/dummy.png")
		end
		
		if path == nil then return dummy_image end
		
		local _, img = pcall(love.graphics.newImage, path)
		
		if _ == false then
			return dummy_image
		end
		
		return img
	end
end

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
		score_str = {string.byte(tostring(current_score), 1, 2147483647)}
		score_digit_len = #score_str
		xpos = 448 - 18 * score_digit_len

		for i = 1, score_digit_len do
			graphics.draw(score_images[score_str[i] - 48], xpos + 36 * i, 53)
		end
		
		-- Get deltaT
		deltaT = coroutine.yield()
	end
end)

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
	-- TODO: Call update score coroutine for animation
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
		deltaT = coroutine.yield()
		
		if combo_system.replay_animation then
			combo_tween:update(-100)	-- Reset
			combo_system.replay_animation = false
		end
		
		-- Don't draw if combo is 0
		if current_combo > 0 then
			-- "combo" pos: 541x267+61+17
			-- number pos: 451x267+24+24; aligh right; subtract by 43 for distance
			combo_tween:update(deltaT)
			
			local combo_str = {string.byte(tostring(current_combo), 1, 2147483647)}
			local img = combo_system.img[get_combo_color_index(current_combo)]
			
			for i = 1, #combo_str do
				local n = 
				-- Draw numbers
				graphics.draw(img[combo_str[i] - 47], 451 - (#combo_str - i) * 43, 267, 0, combo_scale.s, combo_scale.s, 24, 24)
			end
			
			graphics.draw(img.combo, 541, 267, 0, combo_scale.s, combo_scale.s, 61, 17)
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
	local note_draw = {scale = 0, x = 480, y = 160}
	local note_tween = tween.new(NOTE_SPEED, note_draw, {
		scale = 1, x = idol_image_pos[note_data.position][1] + 64, y = idol_image_pos[note_data.position][2] + 64
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
	
	if RANDOM_NOTE_IMAGE then
		drawn_circle = tap_circle_image[math.random(1, 10)]
	else
		drawn_circle = tap_circle_image[note_data.notes_attribute]
	end
	
	if long_note_bit then
		longnote_data.direction = angle_from(480, 160, idol_image_pos[note_data.position][1] + 64, idol_image_pos[note_data.position][2] + 64)
		longnote_data.last_circle = {scale = 0, x = 480, y = 160}
		longnote_data.last_circle_tween = tween.new(NOTE_SPEED, longnote_data.last_circle, {
			scale = 1, x = idol_image_pos[note_data.position][1] + 64, y = idol_image_pos[note_data.position][2] + 64
		})
		longnote_data.duration = note_data.effect_value * 1000
		longnote_data.sound = tap_sound:clone()
		longnote_data.first_sound_play = false
		
		off_time = off_time + longnote_data.duration
	end
	
	local deltaT = coroutine.yield(score)	-- Should be in ms
	
	while time_elapsed < off_time do
		if time_elapsed < NOTE_SPEED then
			note_tween:update(deltaT)
		elseif not(longnote_data.first_sound_play) then
			circle_sound:play()
			longnote_data.first_sound_play = true
		end
		
		time_elapsed = time_elapsed + deltaT
		
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
				math.floor((note_draw.x + (s * 64) * math.cos(longnote_data.direction)) + 0.5),	-- x
				math.floor((note_draw.y + (s * 64) * math.sin(longnote_data.direction)) + 0.5),	-- y
				-- Second position
				math.floor((note_draw.x + (s * 64) * math.cos(longnote_data.direction - math.pi)) + 0.5),	-- x
				math.floor((note_draw.y + (s * 64) * math.sin(longnote_data.direction - math.pi)) + 0.5),	-- y
				-- Third position
				math.floor((longnote_data.last_circle.x + (s2 * 64) * math.cos(longnote_data.direction - math.pi)) + 0.5),	-- x
				math.floor((longnote_data.last_circle.y + (s2 * 64) * math.sin(longnote_data.direction - math.pi)) + 0.5),	-- y
				-- Fourth position
				math.floor((longnote_data.last_circle.x + (s2 * 64) * math.cos(longnote_data.direction)) + 0.5),	-- x
				math.floor((longnote_data.last_circle.y + (s2 * 64) * math.sin(longnote_data.direction)) + 0.5),	-- y
			}
			
			graphics.setColor(255, 255, 255, 127)
			graphics.polygon("fill", vert[1], vert[2], vert[3], vert[4], vert[5], vert[6])
			graphics.polygon("fill", vert[5], vert[6], vert[7], vert[8], vert[1], vert[2])
			graphics.setColor(255, 255, 255, 255)
			
			graphics.draw(drawn_circle, x, y, 0, s, s, 64, 64) -- Draw tap circle BEFORE end long note indicator
			
			if spawn_ln_end then
				graphics.draw(tap_circle_image.endlongnote, longnote_data.last_circle.x, longnote_data.last_circle.y, 0, s2, s2, 64, 64)
			end
		
		else
			graphics.draw(drawn_circle, x, y, 0, s, s, 64, 64)		-- Draw tap circle
		end
		
		if token_note_bit and tap_circle_image.tokennote then
			graphics.draw(tap_circle_image.tokennote, x, y, 0, s, s, 64, 64)	-- Layer token note
		end
		
		if simul_note_bit then
			graphics.draw(tap_circle_image.simulnote, x, y, 0, s, s, 64, 64)	-- Layer simul note
		end
		
		if star_note_bit then
			graphics.draw(tap_circle_image.starnote, x, y, 0, s, s, 64, 64)		-- Layer star note
		end
		
		deltaT = coroutine.yield(score)
	end
	
	current_combo = current_combo + 1
	combo_system.replay_animation = true
	
	if long_note_bit then
		longnote_data.sound:play()
	else
		circle_sound:play()
	end
	
	local aftertap = coroutine.wrap(circletap_effect_routine)
	aftertap(note_data.position)	-- Initialize circletap effect
	effect_player.spawn(aftertap)	-- Then add to effect list
	
	coroutine.yield(score)
	
	
	while true do coroutine.yield(score) end
end

-- Initialization function
function love.load(argv)
	math.randomseed(os.time())
	
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
		notes_list = NOTE_LOADER(ROOT_DIR.."/beatmap/"..BEATMAP_NAME..".json")
		--NOTES_QUEUE = List.new()
		
		-- Load beatmap audio
		BEATMAP_AUDIO = load_audio_safe("audio/"..(argv[3] or BEATMAP_NAME..".wav"))
		
		-- Load perfect sound
		tap_sound = love.audio.newSource("sound/SE_306.ogg", "static")
		
		-- Load background
		background_image = love.graphics.newImage(BACKGROUND_IMAGE)
		background_dim.tween = tween.new(1000, background_dim, {opacity = 127})
		
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
		combo_system.draw_routine()	-- Call it once
		
		-- Load font
		DEBUG_FONT = love.graphics.newFont("MTLmr3m.ttf", 24)
		DEBUG_FONT_OUTLINE_SHADER = love.graphics.newShader("outline_shader.glsl")
	end
end

function love.draw()
	local deltaT = love.timer.getDelta() * 1000
	
	if BEATMAP_NAME then
		-- Draw background
		graphics.draw(background_image)	-- TODO: replace with background handler
		
		graphics.setColor(0, 0, 0, background_dim.opacity)
		graphics.rectangle("fill", 0, 0, 960, 640)
		graphics.setColor(255, 255, 255, 255)
		
		if start_livesim <= 0 then
			-- Draw header
			graphics.draw(live_header.header)
			graphics.draw(live_header.score_gauge, 5, 8, 0, 876 / 880, 33 / 38)
			
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
			score_update_coroutine(deltaT)
		end
		
		-- Draw combo
		combo_system.draw_routine(deltaT)
		
		-- Draw notes
		for n, v in pairs(NOTES_QUEUE) do
			v.draw(deltaT)
		end
		
		-- remove notes from queue
		local accumulative_score = 0
		
		while NOTES_QUEUE[1] do
			if elapsed_time > NOTES_QUEUE[1].endtime then
				accumulative_score = accumulative_score + table.remove(NOTES_QUEUE, 1).draw(deltaT)
			else
				break
			end
		end
		
		add_score(accumulative_score)
		
		-- Update effect player
		effect_player.update(deltaT)
		
		-- Print debug info if exist
		if DEBUG_SWITCH then
			local str = string.format([[
%d FPS
NOTE_SPEED = %d ms
AVAILABLE_NOTES = %d
QUEUED_NOTES = %d
CURRENT_COMBO = %d
RUNNING_EFFECT = %d
]], love.timer.getFPS(), NOTE_SPEED, notes_list.len, #NOTES_QUEUE, current_combo, #effect_player.list)
			local oldfont = graphics.getFont()
			
			graphics.setFont(DEBUG_FONT)
			graphics.setColor(255, 0, 0, 255)
			graphics.print(str)
			graphics.setFont(oldfont)
			graphics.setColor(255, 255, 255, 255)
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
				BEATMAP_AUDIO:play()
				audio_playing = true
			end
			
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
		end
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