--! @file livesim.lua
-- DEPLS, playable version
-- Copyright © 2038 Dark Energy Processor

local love = love
local tween = require("tween")
local EffectPlayer = require("effect_player")
local List = require("List")
local JSON = require("JSON")
local DEPLS = {
	ElapsedTime = 0,	-- Elapsed time, in milliseconds
	DebugDisplay = false,
	SaveDirectory = "",	-- DEPLS Save Directory
	BeatmapAudioVolume = 0.8,	-- The audio volume
	PlaySpeed = 1.0,	-- Play speed factor. 1 = normal
	PlaySpeedAlterDisabled = false,	-- Disallow alteration of DEPLS play speed factor
	
	BackgroundOpacity = 255,	-- User background opacity set from storyboard
	BackgroundImage = {	-- Index 0 is the main background
		-- {handle, logical x, logical y, x size, y size}
		{nil, -88, 0},
		{nil, 960, 0},
		{nil, 0, -43},
		{nil, 0, 640},
		[0] = {nil, 0, 0}
	},
	LiveOpacity = 255,	-- Live opacity
	AutoPlay = false,	-- Autoplay?
	
	StoryboardFunctions = {},	-- Additional function to be added in sandboxed lua storyboard
	Routines = {			-- Table to store all DEPLS effect routines
		ComboCounter = {CurrentCombo = 0},
		PerfectNode = {},
		ScoreUpdate = {CurrentScore = 0},
		ScoreEclipseF = {},
		NoteIcon = {}
	},
	
	IdolPosition = {	-- Idol position. 9 is leftmost
		{816, 96 }, {785, 249}, {698, 378},
		{569, 465}, {416, 496}, {262, 465},
		{133, 378}, {46 , 249}, {16 , 96 },
	},
	IdolImageData = {	-- [idol positon] = {image handle, opacity}
		{nil, 255}, {nil, 255}, {nil, 255},
		{nil, 255}, {nil, 255}, {nil, 255},
		{nil, 255}, {nil, 255}, {nil, 255}
	},
	NoteAccuracy = {{16, nil}, {40, nil}, {64, nil}, {112, nil}, {128, nil}},	-- Note accuracy
	NoteManager = nil,
	NoteLoader = nil,
	Stamina = 32,
	NotesSpeed = 800,
	NotesSpeedAlterDisabled = false,
	ScoreBase = 500,
	ScoreData = {		-- Contains C score, B score, A score, S score data, in order.
		1,
		2,
		3,
		4
	},
	
	Images = {		-- Lists of loaded images
		Note = {},
		ScoreNode = {}
	},
	Sound = {}
}
----------------------
-- Public functions --
----------------------

--! @brief Get all file contents
--! @param path The file path
--! @returns The file contents as string or `nil` and error message on fail
function file_get_contents(path)
	local f, x = io.open(path)
	
	if not(f) then return nil, x end
	
	local r = f:read("*a")
	
	f:close()
	return r
end

--! Source: https://love2d.org/forums/viewtopic.php?t=2126
function HSL(h, s, l)
	if s == 0 then return l,l,l end
	h, s, l = h/256*6, s/255, l/255
	local c = (1-math.abs(2*l-1))*s
	local x = (1-math.abs(h%2-1))*c
	local m,r,g,b = (l-.5*c), 0,0,0
	if h < 1     then r,g,b = c,x,0
	elseif h < 2 then r,g,b = x,c,0
	elseif h < 3 then r,g,b = 0,c,x
	elseif h < 4 then r,g,b = 0,x,c
	elseif h < 5 then r,g,b = x,0,c
	else              r,g,b = c,0,x
	end
   return math.ceil((r+m)*256),math.ceil((g+m)*256),math.ceil((b+m)*256)
end

-----------------------
-- Private functions --
-----------------------

--! Function used to replace extension on file
local function substitute_extension(file, ext_without_dot)
	return file:sub(1, ((file:find("%.[^%.]*$")) or #file+1)-1).."."..ext_without_dot
end

--! @brief Function to calculate distance of 2 position.
--! @code distance(x2 - x1, y2 - y1)
--! @endcode
local function distance(a, b)
	return math.sqrt(a ^ 2 + b ^ 2)
end

--! Function to calculate angle of 2 position
local function angle_from(x1, y1, x2, y2)
	return math.atan2(y2 - y1, x2 - x1) - math.pi / 2
end

------------------------
-- Animation routines --
------------------------

--! @brief Circletap aftertap effect routine. Meant to be run via coroutine
--! @param x The x position relative to center of the image
--! @param y The y position relative to center of the image
--! @param r The RGB red value. Defaults to 255
--! @param g The RGB green value. Defaults to 255
--! @param b The RGB blue value. Defaults to 255
function DEPLS.Routines.CircleTapEffect(x, y, r, g, b)
	r = r or 255
	g = g or 255
	b = b or 255
	
	-- Initialize tons of locals
	local deltaT
	local setColor = love.graphics.setColor
	local draw = love.graphics.draw
	local el_t = 0
	local circle = DEPLS.Images.ef_316_001
	local stareff = DEPLS.Images.ef_316_000
	local circle1_data = {scale = 2, opacity = 255}
	local circle2_data = {scale = 2, opacity = 255}
	local circle3_data = {scale = 2, opacity = 255}
	local stareff_data = {opacity = 255}
	local circle1_tween = tween.new(125, circle1_data, {scale = 3.5})
	local circle2_tween = tween.new(200, circle2_data, {scale = 3.5})
	local circle3_tween = tween.new(250, circle3_data, {scale = 3.5})
	local circle1_tween_op = tween.new(125, circle1_data, {opacity = 0}, "inQuad")
	local circle2_tween_op = tween.new(200, circle2_data, {opacity = 0}, "inQuad")
	local circle3_tween_op = tween.new(250, circle3_data, {opacity = 0}, "inQuad")
	local stareff_tween = tween.new(250, stareff_data, {opacity = 0}, "inQuad")
	local pos = {x, y}
	
	while true do
		local still_has_render = false
		deltaT = coroutine.yield()
		el_t = el_t + deltaT
		
		if circle1_tween and circle1_tween:update(deltaT) == false then
			still_has_render = true
			
			circle1_tween_op:update(deltaT)
			setColor(r, g, b, circle1_data.opacity)
			draw(circle, pos[1], pos[2], 0, circle1_data.scale, circle1_data.scale, 37.5, 37.5)
			setColor(255, 255, 255, 255)
		else
			circle1_tween = nil
		end
		
		if circle2_tween and circle2_tween:update(deltaT) == false then
			still_has_render = true
			
			circle2_tween_op:update(deltaT)
			setColor(r, g, b, circle2_data.opacity)
			draw(circle, pos[1], pos[2], 0, circle2_data.scale, circle2_data.scale, 37.5, 37.5)
			setColor(255, 255, 255, 255)
		else
			circle2_tween = nil
		end
		
		if circle3_tween and circle3_tween:update(deltaT) == false then
			still_has_render = true
			
			circle3_tween_op:update(deltaT)
			setColor(r, g, b, circle3_data.opacity)
			draw(circle, pos[1], pos[2], 0, circle3_data.scale, circle3_data.scale, 37.5, 37.5)
			setColor(255, 255, 255, 255)
		else
			circle3_tween = nil
		end
		
		if el_t >= 75 and stareff_tween:update(deltaT) == false then
			still_has_render = true
			setColor(r, g, b, stareff_data.opacity)
			draw(stareff, pos[1], pos[2], 0, 1.5, 1.5, 50, 50)
			setColor(255, 255, 255, 255)
		end
		
		if still_has_render == false then
			break
		end
	end
	
	while true do
		coroutine.yield(true)	-- Tell effect player to remove this
	end
end

function DEPLS.Routines.ComboCounter.GetComboColorIndex(combo)
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

--! Combo counter animation routine
DEPLS.Routines.ComboCounter.Draw = coroutine.wrap(function()
	local deltaT
	local combo_scale = {s = 1.15}
	local combo_tween = tween.new(150, combo_scale, {s = 1}, "inOutSine")
	local combo_boom = {s = 1.25, op = 127}
	local combo_boom_tween = tween.new(330, combo_boom, {s = 1.65, op = 0})
	local ComboCounter = DEPLS.Routines.ComboCounter
	local ComboNumbers = DEPLS.Images.ComboNumbers
	local CurrentCombo
	local draw = love.graphics.draw
	local setColor = love.graphics.setColor
	
	while true do
		::draw_update_sync1::
		deltaT = coroutine.yield()	-- love.update part
		if not(deltaT) then goto draw_update_sync1 end
		
		CurrentCombo = ComboCounter.CurrentCombo
		
		if ComboCounter.Replay then
			combo_tween:reset()
			combo_boom_tween:reset()
			ComboCounter.Replay = false
		end
		
		-- Don't draw if combo is 0
		if CurrentCombo > 0 then
			-- "combo" pos: 541x267+61+17
			-- number pos: 451x267+24+24; aligh right; subtract by 43 for distance
			combo_tween:update(deltaT)
			combo_boom_tween:update(deltaT)
			
			local combo_str = {string.byte(tostring(CurrentCombo), 1, 2147483647)}
			local img = ComboNumbers[ComboCounter.GetComboColorIndex(CurrentCombo)]
			
			::draw_update_sync2::
			if coroutine.yield() then goto draw_update_sync2 end	-- love.draw part
			
			setColor(255, 255, 255, DEPLS.LiveOpacity)
			
			for i = 1, #combo_str do
				-- Draw numbers
				draw(img[combo_str[i] - 47], 451 - (#combo_str - i) * 43, 267, 0, combo_scale.s, combo_scale.s, 24, 24)
			end
			
			setColor(255, 255, 255, combo_boom.op * DEPLS.LiveOpacity / 255)
			draw(img.combo, 541, 266, 0, combo_boom.s, combo_boom.s, 61, 18)
			setColor(255, 255, 255, DEPLS.LiveOpacity)
			draw(img.combo, 541, 267, 0, combo_scale.s, combo_scale.s, 61, 17)
			setColor(255, 255, 255, 255)
		else
			::draw_update_sync3::
			if coroutine.yield() then goto draw_update_sync3 end	-- draw nothing
		end
	end
end)

--! Tap accuracy display routine
DEPLS.Routines.PerfectNode.Draw = coroutine.wrap(function()
	local deltaT
	local setColor = love.graphics.setColor
	local draw = love.graphics.draw
	local et = 500
	local perfect_data = {opacity = 0, scale = 0}
	local perfect_tween = tween.new(50, perfect_data, {opacity = 255, scale = 2}, "outSine")
	local perfect_tween_fadeout = tween.new(200, perfect_data, {opacity = 0})
	local PerfectNode = DEPLS.Routines.PerfectNode
	
	perfect_tween:update(50)
	perfect_tween_fadeout:update(200)
	
	while true do
		::draw_update_sync1::
		deltaT = coroutine.yield()	-- love.update part
		if not(deltaT) then goto draw_update_sync1 end
		
		et = et + deltaT
		
		if PerfectNode.Replay then
			et = deltaT
			perfect_tween:reset()
			perfect_tween_fadeout:reset()
			PerfectNode.Replay = false
		end
		
		perfect_tween:update(deltaT)
		
		if et > 200 then
			perfect_tween_fadeout:update(deltaT)
		end
		
		-- To prevnet overflow
		if et > 5000 then
			et = et - 4000
		end
		
		::draw_update_sync2::
		if coroutine.yield() then goto draw_update_sync2 end	-- love.draw part
		
		if et < 500 then
			setColor(255, 255, 255, perfect_data.opacity * DEPLS.LiveOpacity / 255)
			draw(PerfectNode.Image, 480, 320, 0, perfect_data.scale, perfect_data.scale,
				PerfectNode.Center[PerfectNode.Image][1], PerfectNode.Center[PerfectNode.Image][2])
			setColor(255, 255, 255, 255)
		end
	end
end)

--! Score flash animation routine
DEPLS.Routines.ScoreEclipseF.Draw = coroutine.wrap(function()
	local setColor = love.graphics.setColor
	local draw = love.graphics.draw
	local deltaT
	local eclipse_data = {scale = 1, opacity = 255}
	local eclipse_tween = tween.new(500, eclipse_data, {scale = 1.6, opacity = 0}, "outSine")
	local bar_data = {opacity = 255}
	local ScoreEclipseF = DEPLS.Routines.ScoreEclipseF
	
	bar_data.tween = tween.new(300, bar_data, {opacity = 0})
	
	-- Seek to end
	eclipse_tween:update(500)
	bar_data.tween:update(300)
	
	while true do
		::draw_update_sync1::
		deltaT = coroutine.yield()	-- love.update part
		if not(deltaT) then goto draw_update_sync1 end
		
		if ScoreEclipseF.Replay then
			eclipse_tween:reset()
			bar_data.tween:reset()
			ScoreEclipseF.Replay = false
		end
		
		::draw_update_sync2::
		if coroutine.yield() then goto draw_update_sync2 end	-- love.draw part
		
		if eclipse_tween:update(deltaT) == false then
			setColor(255, 255, 255, eclipse_data.opacity * DEPLS.LiveOpacity / 255)
			draw(ScoreEclipseF.Img, 484, 72, 0, eclipse_data.scale, eclipse_data.scale, 159, 34)
		end
		
		if bar_data.tween:update(deltaT) == false then
			setColor(255, 255, 255, bar_data.opacity * DEPLS.LiveOpacity / 255)
			draw(ScoreEclipseF.Img2, 5, 8)
		end
		
		setColor(255, 255, 255, 255)
	end
end)

-- Circle effect function in the note icon
DEPLS.Routines.NoteIcon.CircleEffect = function()
	local deltaT
	local setColor = love.graphics.setColor
	local draw = love.graphics.draw
	local circ_data = {scale = 0.6, opacity = 255}
	local circ_tween = tween.new(1600, circ_data, {scale = 2.5, opacity = 0})
	local NoteIconCircle = DEPLS.Images.NoteIconCircle
	local draw = love.graphics.draw
	local NoteIcon = DEPLS.Images.NoteIcon
	
	while true do
		deltaT = coroutine.yield()
		
		if circ_tween:update(deltaT) == true then
			break
		end
		
		setColor(255, 255, 255, circ_data.opacity * DEPLS.LiveOpacity / 255)
		draw(NoteIconCircle, 480, 160, 0, circ_data.scale, circ_data.scale, 34, 34)
		setColor(255, 255, 255, 255)
	end
	
	while true do coroutine.yield(true) end
end

-- Note icon draw function
DEPLS.Routines.NoteIcon.Draw = coroutine.wrap(function()
	local deltaT
	local et = 0
	local noteicon_data = {scale = 1}
	local noteicon_tween = tween.new(800, noteicon_data, {scale = 0.8})
	local noteicon_tween2 = tween.new(1200, noteicon_data, {scale = 1}, "outSine")
	local active_tween = noteicon_tween
	local circledraw_time = {0, 300, 600}
	local setColor = love.graphics.setColor
	local draw = love.graphics.draw
	local NoteIcon = DEPLS.Images.NoteIcon
	
	while true do
		repeat
			deltaT = coroutine.yield()
		until deltaT
		
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
					local cr = coroutine.wrap(DEPLS.Routines.NoteIcon.CircleEffect)
					cr()
					EffectPlayer.Spawn(cr)
					
					circledraw_time[i] = 1234567
				end
			end
			
			-- love.draw
			while coroutine.yield() do end
			
			setColor(255, 255, 255, DEPLS.LiveOpacity)
			draw(NoteIcon, 480, 160, 0, noteicon_data.scale, noteicon_data.scale, 54, 52)
			setColor(255, 255, 255, 255)
		end
	end
end)

-- Score bar routine
DEPLS.Routines.ScoreBar = coroutine.wrap(function(deltaT)
	local ScoreUpdate = DEPLS.Routines.ScoreUpdate
	local ScoreData = DEPLS.ScoreData
	local LogicalScale = LogicalScale
	local newImage = love.graphics.newImage
	local setScissor = love.graphics.setScissor
	local setColor = love.graphics.setColor
	local draw = love.graphics.draw
	local no_score = newImage("image/live_gauge_03_03.png")
	local c_score = newImage("image/live_gauge_03_04.png")
	local b_score = newImage("image/live_gauge_03_05.png")
	local a_score = newImage("image/live_gauge_03_06.png")
	local s_score = newImage("image/live_gauge_03_07.png")
	local draw_area = 960
	local used_score = nil
	
	while true do
		repeat
			deltaT = coroutine.yield()
		until deltaT
		
		if ScoreUpdate.CurrentScore >= ScoreData[4] then
			-- S score
			used_score = s_score
			draw_area = 960
		elseif ScoreUpdate.CurrentScore >= ScoreData[3] then
			-- A score
			used_score = a_score
			draw_area = 791 + math.floor((ScoreData[3] - ScoreUpdate.CurrentScore) / (ScoreData[3] - ScoreData[4]) * 84 + 0.5)
		elseif ScoreUpdate.CurrentScore >= ScoreData[2] then
			-- B score
			used_score = b_score
			draw_area = 667 + math.floor((ScoreData[2] - ScoreUpdate.CurrentScore) / (ScoreData[2] - ScoreData[3]) * 125 + 0.5)
		elseif ScoreUpdate.CurrentScore >= ScoreData[1] then
			-- C score
			used_score = c_score
			draw_area = 504 + math.floor((ScoreData[1] - ScoreUpdate.CurrentScore) / (ScoreData[1] - ScoreData[2]) * 164 + 0.5)
		else
			-- No score
			used_score = no_score
			draw_area = 48 + math.floor(ScoreUpdate.CurrentScore / ScoreData[1] * 456 + 0.5)
		end
		
		while coroutine.yield() do end
		
		setScissor(LogicalScale.OffX, LogicalScale.OffY, draw_area * LogicalScale.ScaleOverall, 640)
		setColor(255, 255, 255, DEPLS.LiveOpacity)
		draw(used_score, 5, 8, 0, 0.99545454, 0.86842105)
		setColor(255, 255, 255, 255)
		setScissor()
	end
end)

-- Score display routine
DEPLS.Routines.ScoreUpdate.Draw = coroutine.wrap(function(deltaT)
	local ScoreUpdate = DEPLS.Routines.ScoreUpdate
	local newImage = love.graphics.newImage
	local draw = love.graphics.draw
	local setColor = love.graphics.setColor
	local score_str = {string.byte(tostring(ScoreUpdate.CurrentScore), 1, 2147483647)}
	local score_images = {}
	local score_digit_len = 0
	local xpos
	
	for i = 0, 9 do
		score_images[i] = newImage("image/score_num/l_num_0"..i..".png")
	end
	
	while true do
		repeat
			deltaT = coroutine.yield()
		until deltaT
		
		score_str = {string.byte(tostring(ScoreUpdate.CurrentScore), 1, 2147483647)}
		score_digit_len = #score_str
		xpos = 448 - 16 * score_digit_len
		
		while coroutine.yield() do end
		
		setColor(255, 255, 255, DEPLS.LiveOpacity)
		
		for i = 1, score_digit_len do
			draw(score_images[score_str[i] - 48], xpos + 32 * i, 53)
		end
		
		setColor(255, 255, 255, 255)
	end
end)

-- Added score, update routine
DEPLS.Routines.ScoreNode = function(score)
	local Images = DEPLS.Images
	local graphics = love.graphics
	local score_canvas = graphics.newCanvas(500, 32)
	local score_info = {opacity = 0, scale = 0.9, x = 530}
	local opacity_tw = tween.new(100, score_info, {opacity = 255})
	local scale_tw = tween.new(200, score_info, {scale = 1}, "inOutSine")
	local xpos_tw = tween.new(250, score_info, {x = 570}, "outSine")
	local deltaT
	local elapsed_time = 0
	
	-- Draw all in canvas
	graphics.setCanvas(score_canvas)
	graphics.setBlendMode("alpha", "premultiplied")
	graphics.setColor(255, 255, 255, DEPLS.LiveOpacity)
	graphics.draw(Images.ScoreNode.Plus)
	
	do
		local i = 1
		for w in tostring(score):gmatch("%d") do
			graphics.draw(Images.ScoreNode[tonumber(w)], i * 24, 0)
			i = i + 1
		end
	end
	graphics.setColor(255, 255, 255, 255)
	graphics.setBlendMode("alpha")
	graphics.setCanvas()
	
	deltaT = coroutine.yield()
	elapsed_time = elapsed_time + deltaT
	
	while elapsed_time < 500 do
		xpos_tw:update(deltaT)
		opacity_tw:update(elapsed_time > 350 and -deltaT or deltaT)
		scale_tw:update(elapsed_time > 200 and -deltaT or deltaT)
		
		graphics.setColor(255, 255, 255, score_info.opacity * DEPLS.LiveOpacity / 255)
		graphics.draw(score_canvas, score_info.x, 72, 0, score_info.scale, score_info.scale, 0, 16)
		graphics.setColor(255, 255, 255, 255)
		
		deltaT = coroutine.yield()
		elapsed_time = elapsed_time + deltaT
	end
	
	while true do coroutine.yield(true) end	-- Stop
end

--------------------------------
-- Another public functions   --
-- Some is part of storyboard --
--------------------------------

--! @brief Add score
--! @param score The score value
function DEPLS.AddScore(score)
	local ComboCounter = DEPLS.Routines.ComboCounter
	local added_score = score
	
	if ComboCounter.CurrentCombo < 50 then
		-- noop
	elseif ComboCounter.CurrentCombo < 100 then
		added_score = added_score * 1.1
	elseif ComboCounter.CurrentCombo < 200 then
		added_score = added_score * 1.15
	elseif ComboCounter.CurrentCombo < 400 then
		added_score = added_score * 1.2
	elseif ComboCounter.CurrentCombo < 600 then
		added_score = added_score * 1.25
	elseif ComboCounter.CurrentCombo < 800 then
		added_score = added_score * 1.3
	else
		added_score = added_score * 1.35
	end
	
	added_score = math.floor(added_score)
	
	DEPLS.Routines.ScoreUpdate.CurrentScore = DEPLS.Routines.ScoreUpdate.CurrentScore + added_score
	DEPLS.Routines.ScoreEclipseF.Replay = true
	
	local sc = coroutine.wrap(DEPLS.Routines.ScoreNode)
	sc(added_score)
	EffectPlayer.Spawn(sc)
end

--! @brief Load image
--! @param path The image path
--! @returns Image handle or `nil` and error message on fail
function DEPLS.LoadImageSafe(path)
	local _, token_image = pcall(love.graphics.newImage, path)
	
	if _ == false then return nil, token_image
	else return token_image end
end

--! @brief Load audio
--! @param path The audio path
--! @param noorder Force existing extension?
--! @returns Audio handle or `nil` plus error message on failure
function DEPLS.LoadAudio(path, noorder)
	local _, token_image
	
	if not(noorder) then
		local a = DEPLS.LoadAudio(substitute_extension(path, "wav"), true)
		
		if a == nil then
			a = DEPLS.LoadAudio(substitute_extension(path, "ogg"), true)
			
			if a == nil then
				return DEPLS.LoadAudio(substitute_extension(path, "mp3"), true)
			end
		end
		
		return a
	end
	
	-- Try save dir
	do
		local file = love.filesystem.newFile(path)
		
		if file:open("r") then
			_, token_image = pcall(love.sound.newSoundData, file)
			
			if _ then
				return token_image
			end
		end
	end
	
	_, token_image = pcall(love.sound.newSoundData, path)
	
	if _ == false then return nil, token_image
	else return token_image end
end

do
	local dummy_image
	local list = {}
	
	--! @brief Loads image, specialized for unit icon
	--! @param path The unit image path, relative to save_dir/unit_icon folder
	--! @returns Requested unit icon or placeholder unit icon (dummy.png)
	DEPLS.LoadUnitIcon = function(path)
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

--------------------------------------
-- Functions exported to storyboard --
--------------------------------------

--! @brief Sets foreground live opacity
--! @param opacity Transparency. 255 = opaque, 0 = invisible
function DEPLS.StoryboardFunctions.SetLiveOpacity(opacity)
	opacity = math.max(math.min(opacity or 255, 255), 0)
	
	DEPLS.LiveOpacity = opacity
end

--! @brief Sets background blackness
--! @param opacity Transparency. 0 = full black, 255 = full light
function DEPLS.StoryboardFunctions.SetBackgroundDimOpacity(opacity)
	opacity = math.max(math.min(opacity or 255, 255), 0)
	
	DEPLS.BackgroundOpacity = 255 - opacity
end

--! @brief Gets current elapsed time
--! @returns Elapsed time, in milliseconds. Negative value means simulator is not started yet
function DEPLS.StoryboardFunctions.GetCurrentElapsedTime()
	return DEPLS.ElapsedTime
end

--! @brief Gets live simulator delay. Delay before live simulator is shown
--! @returns Live simulator delay, in milliseconds
function DEPLS.StoryboardFunctions.GetLiveSimulatorDelay()
	return DEPLS.LiveDelay
end

--! @brief Spawn spotlight effect in the specificed idol position and with specificed color
--! @param pos The idol position. 9 is the leftmost
--! @param r The RGB red value
--! @param g The RGB green value
--! @param b The RGB blue value
function DEPLS.StoryboardFunctions.SpawnSpotEffect(pos, r, g, b)
	r = r or 255
	g = g or 255
	b = b or 255
	
	local graphics = love.graphics
	local idolpos = DEPLS.IdolPosition[pos]
	local idx = idolpos[1] + 64
	local idy = idolpos[2] + 64
	local spotlight = DEPLS.Images.Spotlight
	local func = coroutine.wrap(function()
		local deltaT
		local dist = distance(idolpos[1] - 416, idolpos[2] - 96) / 256
		local direction = angle_from(480, 160, idx, idy)
		local popn_data = {scale = 1.3333, opacity = 255}
		local keep_render = false
		popn_data.tween = tween.new(500, popn_data, {scale = 0, opacity = 0})
		
		while keep_render == false do
			deltaT = coroutine.yield()
			keep_render = popn_data.tween:update(deltaT)
			
			graphics.setBlendMode("add")
			graphics.setColor(r, g, b, popn_data.opacity)
			graphics.draw(spotlight, idx, idy, direction, popn_data.scale, dist, 48, 256)
			graphics.setColor(255, 255, 255, 255)
			graphics.setBlendMode("alpha")
		end
		
		while true do coroutine.yield(true) end
	end)
	
	func()
	EffectPlayer.Spawn(func)
end

--! @brief Spawn circletap effect in the specificed idol position and with specificed color
--! @param pos The idol position. 9 is the leftmost
--! @param r The RGB red value
--! @param g The RGB green value
--! @param b The RGB blue value
function DEPLS.StoryboardFunctions.SpawnCircleTapEffect(pos, r, g, b)
	local effect = coroutine.wrap(DEPLS.Routines.CircleTapEffect)
	local x, y = DEPLS.IdolPosition[pos][1] + 64, DEPLS.IdolPosition[pos][2] + 64
	effect(x, y, r, g, b)
	EffectPlayer.Spawn(effect)
end

--! @brief Set unit visibility
--! @param pos The unit position (9 is leftmost)
--! @param opacity The desired opacity. 0 is fully transparent, 255 is fully opaque (255 default)
function DEPLS.StoryboardFunctions.SetUnitOpacity(pos, opacity)
	local data = DEPLS.IdolImageData[pos]
	
	if data == nil then
		error("Invalid pos specificed")
	end
	
	data[2] = math.min(math.max(opacity or 255, 0), 255)
end

do
	local channels
	
	local function getsample_safe(sound_data, pos)
		local _, sample = pcall(sound_data.getSample, sound_data, pos)
		
		if _ == false then
			return 0
		end
		
		return sample
	end
	
	--! @brief Gets current playing audio sample with specificed size
	--! @param size The sample size (1 default = 1 sample)
	--! @returns table containing the samples with size `size`
	--! @note This function handles mono/stereo input and this function still works even
	--!       if no audio is found, where in that case the sample is simply 0
	function DEPLS.StoryboardFunctions.GetCurrentAudioSample(size)
		size = size or 1
		
		local audio = DEPLS.Sound.BeatmapAudio
		local sample_list = {}
		
		if not(audio) then
			for i = 1, size do
				sample_list[#sample_list + 1] = {0, 0}
			end
			
			return sample_list
		end
		
		if not(channels) then
			channels = audio:getChannels()
		end
		
		local pos = DEPLS.Sound.LiveAudio:tell("samples")
		
		if channels == 1 then
			for i = pos, pos + size - 1 do
				-- Mono
				local sample = getsample_safe(audio, i)
				
				sample_list[#sample_list + 1] = {sample, sample}
			end
		elseif channels == 2 then
			for i = pos, pos + size - 1 do
				-- Stereo
				sample_list[#sample_list + 1] = {
					getsample_safe(audio, i * 2),
					getsample_safe(audio, i * 2 + 1),
				}
			end
		end
		
		return sample_list
	end
end

--! @brief Loads DEPLS2 image file
--! @param path The image path
--! @returns Image handle or nil on failure
function DEPLS.StoryboardFunctions.LoadDEPLS2Image(path)
	local _, a = pcall(love.graphics.newImage, path)
	
	if _ then
		return a
	end
	
	return nil
end

--! @brief Disable play speed alteration and set play speed to 1
--! @note This function should be called on storyboard initialization, as calling it
--!       multiple times is a waste of CPU
function DEPLS.StoryboardFunctions.DisablePlaySpeedAlteration()
	DEPLS.PlaySpeedAlterDisabled = true
	
	if DEPLS.Sound.LiveAudio then
		DEPLS.Sound.LiveAudio:setPitch(1)
	end
end

--! @brief Get or set notes speed
--! @param notes_speed Note speed, in milliseconds. 0.8 notes speed in SIF is equal to 800 in here
--! @returns Previous notes speed
--! @warning This function throws error if notes_speed is less than 400ms
function DEPLS.StoryboardFunctions.SetNotesSpeed(notes_speed)
	if notes_speed then
		assert(notes_speed >= 400, "notes_speed can't be less than 400ms")
	end
	
	local prev = DEPLS.NotesSpeed
	DEPLS.NotesSpeed = notes_speed or prev
	
	-- Recalculate accuracy
	for i = 1, 5 do
		DEPLS.NoteAccuracy[i][2] = DEPLS.NoteAccuracy[i][1] * 1000 / notes_speed
	end
	
	return prev
end

--! @brief Get or set play speed. This affects how fast the live simulator are
--! @param speed_factor The speed factor, in decimals. 1 means 100% speed (runs normally)
--! @returns Previous play speed factor
--! @warning This function throws error if speed_factor is zero
function DEPLS.StoryboardFunctions.SetPlaySpeed(speed_factor)
	if speed_factor then
		assert(speed_factor > 0, "speed_factor can't be zero")
	end
	
	local factorrest = speed_factor or DEPLS.PlaySpeed
	
	DEPLS.PlaySpeed = factorrest
	
	if DEPLS.Sound.LiveAudio then
		DEPLS.Sound.LiveAudio:setPitch(factorrest)
	end
end

-----------------------------
-- The Live simuator logic --
-----------------------------

--! @brief Call storyboard callback
--! @param name Callback name
--! @param ... Additional arguments passed to callback function
function DEPLS.StoryboardCallback(name, ...)
	if DEPLS.StoryboardHandle then
		DEPLS.StoryboardHandle.On(name, ...)
	end
end

--! @brief DEPLS Initialization function
--! @param argv The arguments passed to the game via command-line
function DEPLS.Start(argv)
	DEPLS.Arg = argv
	_G.DEPLS = DEPLS
	EffectPlayer.Clear()
	
	-- Load tap sound. High priority
	DEPLS.Sound.PerfectTap = love.audio.newSource("sound/SE_306.ogg", "static")
	DEPLS.Sound.GreatTap = love.audio.newSource("sound/SE_307.ogg", "static")
	DEPLS.Sound.GoodTap = love.audio.newSource("sound/SE_308.ogg", "static")
	DEPLS.Sound.BadTap = love.audio.newSource("sound/SE_309.ogg", "static")
	DEPLS.Sound.StarExplode = love.audio.newSource("sound/SE_326.ogg", "static")
	
	-- Load notes image. High Priority
	DEPLS.Images.Note = {
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
		
		NoteEnd = love.graphics.newImage("image/tap_circle/tap_circle-44.png"),
		Star = love.graphics.newImage("image/tap_circle/ef_315_effect_0004.png"),
		Simultaneous = love.graphics.newImage("image/tap_circle/ef_315_timing_1.png"),
		Token = love.graphics.newImage("image/tap_circle/e_icon_01.png"),
	}
	DEPLS.Images.Spotlight = love.graphics.newImage("image/popn.png")
	DEPLS.SaveDirectory = love.filesystem.getSaveDirectory()
	
	-- Force love2d to make directory
	love.filesystem.createDirectory("audio")
	love.filesystem.createDirectory("beatmap")
	
	-- Load configuration
	local BackgroundID = LoadConfig("BACKGROUND_IMAGE", 11)
	local Keys = LoadConfig("IDOL_KEYS", "a\ts\td\tf\tspace\tj\tk\tl\t;")
	local Auto = LoadConfig("AUTOPLAY", 0)
	DEPLS.LiveDelay = LoadConfig("LIVESIM_DELAY", 1000)
	DEPLS.ElapsedTime = -DEPLS.LiveDelay
	DEPLS.NotesSpeed = LoadConfig("NOTE_SPEED", 800)
	DEPLS.Stamina = LoadConfig("STAMINA_DISPLAY", 32)
	DEPLS.ScoreBase = LoadConfig("SCORE_ADD_NOTE", 1024)
	DEPLS.Keys = {}
	do
		local i = 9
		for w in Keys:gmatch("[^\t]+") do
			DEPLS.Keys[i] = w
			
			i = i - 1
		end
	end
	if Auto == 0 then
		DEPLS.AutoPlay = false
	else
		DEPLS.AutoPlay = true
	end
	
	-- Load modules
	DEPLS.NoteManager = love.filesystem.load("note.lua")()
	DEPLS.NoteLoader = love.filesystem.load("note_loader.lua")()
	
	-- Load beatmap
	local notes_list
	local noteloader_data = DEPLS.NoteLoader.NoteLoader(argv[1])
	local custom_background = false
	notes_list = noteloader_data.notes_list
	DEPLS.StoryboardHandle = noteloader_data.storyboard
	DEPLS.Sound.BeatmapAudio = noteloader_data.song_file
	
	if type(noteloader_data.background) == "number" then
		BackgroundID = noteloader_data.background
	elseif type(noteloader_data.background) == "table" then
		DEPLS.BackgroundImage[0][1] = noteloader_data.background[0]
		DEPLS.BackgroundImage[0][4] = 960 / noteloader_data.background[0]:getWidth()
		DEPLS.BackgroundImage[0][5] = 640 / noteloader_data.background[0]:getHeight()
		DEPLS.BackgroundImage[1][1] = noteloader_data.background[1]
		DEPLS.BackgroundImage[2][1] = noteloader_data.background[2]
		DEPLS.BackgroundImage[3][1] = noteloader_data.background[3]
		DEPLS.BackgroundImage[4][1] = noteloader_data.background[4]
		print(DEPLS.BackgroundImage[0][4], DEPLS.BackgroundImage[0][5])
		
		custom_background = true
	end
	
	-- Add to note manager
	do
		local a = os.clock()
		for i = 1, #notes_list do
			DEPLS.NoteManager.Add(notes_list[i])
		end
		print("Note added in "..((os.clock() - a) * 1000).." ms")
	end
	
	-- Calculate note accuracy
	for i = 1, 5 do
		DEPLS.NoteAccuracy[i][2] = DEPLS.NoteAccuracy[i][1] * 1000 / DEPLS.NotesSpeed
	end
	
	-- Calculate score bar
	if noteloader_data.score then
		for i = 1, 4 do
			-- Use info from beatmap
			DEPLS.ScoreData[i] = noteloader_data.score[i]
		end
	else
		-- Calculate using master difficulty preset
		local s_score = #notes_list * 739
		
		DEPLS.ScoreData[1] = math.floor(s_score * 0.285521 + 0.5)
		DEPLS.ScoreData[2] = math.floor(s_score * 0.71448 + 0.5)
		DEPLS.ScoreData[3] = math.floor(s_score * 0.856563 + 0.5)
		DEPLS.ScoreData[4] = s_score
	end
	
	-- Load beatmap audio
	if not(DEPLS.Sound.BeatmapAudio) then
		-- Beatmap audio needs to be safe loaded
		DEPLS.Sound.BeatmapAudio = DEPLS.LoadAudio("audio/"..(argv[2] or argv[1]..".wav"), not(not(argv[2])))
	end
	
	-- BeatmapAudio is actually SoundData, LiveAudio is the real Source
	if DEPLS.Sound.BeatmapAudio then
		DEPLS.Sound.LiveAudio = love.audio.newSource(DEPLS.Sound.BeatmapAudio)
	end
	
	----------------------
	-- Load image start --
	----------------------
	
	-- Load background if no storyboard present
	if not(DEPLS.StoryboardHandle) and not(custom_background) then
		DEPLS.BackgroundImage[0][1] = love.graphics.newImage("image/liveback_"..BackgroundID..".png")
		
		for i = 1, 4 do
			DEPLS.BackgroundImage[i][1] = love.graphics.newImage(string.format("image/background/b_liveback_%03d_%02d.png", BackgroundID, i))
		end
	end
	
	-- Tap circle effect
	DEPLS.Images.ef_316_000 = love.graphics.newImage("image/ef_316_000.png")
	DEPLS.Images.ef_316_001 = love.graphics.newImage("image/ef_316_001.png")
	
	-- Load live header images
	DEPLS.Images.Header = love.graphics.newImage("image/live_header.png")
	DEPLS.Images.ScoreGauge = love.graphics.newImage("image/live_gauge_03_02.png")
	
	-- Load unit icons
	noteloader_data.units = noteloader_data.units or {}
	local IdolImagePath = {}
	do
		local idol_img = LoadConfig("IDOL_IMAGE", "a.png,a.png,a.png,a.png,a.png,a.png,a.png,a.png,a.png")
		
		for w in idol_img:gmatch("[^,]+") do
			IdolImagePath[#IdolImagePath + 1] = w
		end
	end
	for i = 1, 9 do
		DEPLS.IdolImageData[i][1] = noteloader_data.units[i] or DEPLS.LoadUnitIcon(IdolImagePath[10 - i])
	end
	
	-- Load stamina image (bar and number)
	DEPLS.Images.StaminaRelated = {
		Bar = love.graphics.newImage("image/live_gauge_02_02.png")
	}
	do
		local stamina_display_str = tostring(DEPLS.Stamina)
		local matcher = stamina_display_str:gmatch("%d")
		local temp
		local temp_num
		local stamina_number_image = {}
		
		for i = 1, #stamina_display_str do
			temp = matcher()
			temp_num = tonumber(temp)
			
			if DEPLS.Images.StaminaRelated[temp_num] == nil then
				DEPLS.Images.StaminaRelated[temp_num] = love.graphics.newImage("image/hp_num/live_num_"..temp..".png")
			end
			
			stamina_number_image[i] = DEPLS.Images.StaminaRelated[temp_num]
		end
		
		DEPLS.Images.StaminaRelated.DrawTarget = stamina_number_image
	end
	
	-- Load combo numbers
	DEPLS.Images.ComboNumbers = require("combo_num")
	-- Start combo counter routine
	DEPLS.Routines.ComboCounter.Draw()
	
	-- Load score eclipse related image
	DEPLS.Routines.ScoreEclipseF.Img = love.graphics.newImage("image/l_etc_46.png")
	DEPLS.Routines.ScoreEclipseF.Img2 = love.graphics.newImage("image/l_gauge_17.png")
	-- Initialize score flash
	DEPLS.Routines.ScoreEclipseF.Draw()
	
	-- Init score bar
	DEPLS.Routines.ScoreBar()
	
	-- Load score node number
	for i = 21, 30 do
		DEPLS.Images.ScoreNode[i - 21] = love.graphics.newImage("image/score_num/l_num_"..i..".png")
	end
	DEPLS.Images.ScoreNode.Plus = love.graphics.newImage("image/score_num/l_num_31.png")
	
	-- Tap accuracy image
	DEPLS.Images.Perfect = love.graphics.newImage("image/ef_313_004.png")
	DEPLS.Images.Great = love.graphics.newImage("image/ef_313_003.png")
	DEPLS.Images.Good = love.graphics.newImage("image/ef_313_002.png")
	DEPLS.Images.Bad = love.graphics.newImage("image/ef_313_001.png")
	DEPLS.Images.Miss = love.graphics.newImage("image/ef_313_000.png")
		DEPLS.Routines.PerfectNode.Center = {
		[DEPLS.Images.Perfect] = {99, 19},
		[DEPLS.Images.Great] = {73, 17},
		[DEPLS.Images.Good] = {63, 17},
		[DEPLS.Images.Bad] = {43, 16},
		[DEPLS.Images.Miss] = {46, 15}
	}
	DEPLS.Routines.PerfectNode.Image = DEPLS.Images.Perfect
	-- Initialize tap accuracy routine
	DEPLS.Routines.PerfectNode.Draw()
	
	-- Load NoteIcon image
	DEPLS.Images.NoteIcon = love.graphics.newImage("image/ef_308_000.png")
	DEPLS.Images.NoteIconCircle = love.graphics.newImage("image/ef_308_001.png")
	
	-- Load Font
	DEPLS.MTLmr3m = love.graphics.newFont("MTLmr3m.ttf", 24)
	love.graphics.setFont(DEPLS.MTLmr3m)
end

-- Used internally
local persistent_bg_opacity = 0
local audioplaying = false
local audiodeltaT = 0
local audiolasttime = 0

--! @brief DEPLS Update function. It is separated to allow offline rendering
--! @param deltaT Delta-time in milliseconds
function DEPLS.Update(deltaT)
	deltaT = deltaT * DEPLS.PlaySpeed
	DEPLS.ElapsedTime = DEPLS.ElapsedTime + deltaT
	
	local ElapsedTime = DEPLS.ElapsedTime
	local Routines = DEPLS.Routines
	
	if ElapsedTime <= 0 then
		persistent_bg_opacity = (ElapsedTime + DEPLS.LiveDelay) / DEPLS.LiveDelay * 191
	end
	
	if ElapsedTime > 0 then
		if DEPLS.Sound.LiveAudio and audioplaying == false then
			DEPLS.Sound.LiveAudio:setVolume(DEPLS.BeatmapAudioVolume)
			DEPLS.Sound.LiveAudio:play()
			DEPLS.Sound.LiveAudio:seek(ElapsedTime / 1000)
			audioplaying = true
		end
		
		-- Update note
		DEPLS.NoteManager.Update(deltaT)
		
		-- Update routines
		Routines.ComboCounter.Draw(deltaT)
		Routines.NoteIcon.Draw(deltaT)
		Routines.ScoreEclipseF.Draw(deltaT)
		Routines.ScoreUpdate.Draw(deltaT)
		Routines.ScoreBar(deltaT)
		Routines.PerfectNode.Draw(deltaT)
	end
end

--! @brief DEPLS Draw function. It is separated to allow offline rendering
--! @param deltaT Delta-time in milliseconds
function DEPLS.Draw(deltaT)
	deltaT = deltaT * DEPLS.PlaySpeed
	-- Localize love functions
	local graphics = love.graphics
	local rectangle = graphics.rectangle
	local draw = graphics.draw
	local setColor = graphics.setColor
	local Images = DEPLS.Images
	
	local Routines = DEPLS.Routines
	local ElapsedTime = DEPLS.ElapsedTime
	local AllowedDraw = DEPLS.ElapsedTime > 0 
	
	-- If there's storyboard, draw the storyboard instead.
	if DEPLS.StoryboardHandle then
		DEPLS.StoryboardHandle.Draw(deltaT)
	else
		-- No storyboard. Draw background
		local BackgroundImage = DEPLS.BackgroundImage
		
		draw(
			BackgroundImage[0][1],
			BackgroundImage[0][2],
			BackgroundImage[0][3],
			0,
			BackgroundImage[0][4] or 1,
			BackgroundImage[0][5] or 1
		)
		
		for i = 1, 4 do
			if BackgroundImage[i][1] then
				draw(BackgroundImage[i][1], BackgroundImage[i][2], BackgroundImage[i][3])
			end
		end
	end
	
	-- Draw background blackness
	setColor(0, 0, 0, DEPLS.BackgroundOpacity * persistent_bg_opacity / 255)
	rectangle("fill", -88, -43, 1136, 726)
	setColor(255, 255, 255, 255)
		
	if AllowedDraw then
		-- Draw header
		setColor(255, 255, 255, DEPLS.LiveOpacity)
		draw(Images.Header, 0, 0)
		draw(Images.ScoreGauge, 5, 8, 0, 0.99545454, 0.86842105)
		
		draw(Images.StaminaRelated.Bar, 14, 60)
		for i = 1, #Images.StaminaRelated.DrawTarget do
			love.graphics.draw(Images.StaminaRelated.DrawTarget[i], 290 + 16 * i, 66)
		end
		
		-- Draw idol unit
		do
			local IdolData = DEPLS.IdolImageData
			local IdolPos = DEPLS.IdolPosition
			
			for i = 1, 9 do
				setColor(255, 255, 255, DEPLS.LiveOpacity * IdolData[i][2] / 255)
				draw(IdolData[i][1], unpack(IdolPos[i]))
			end
		end
		
		-- Update note
		DEPLS.NoteManager.Draw()
		
		-- Draw routines
		Routines.ComboCounter.Draw()
		Routines.NoteIcon.Draw()
		Routines.ScoreBar()
		Routines.ScoreEclipseF.Draw()
		Routines.ScoreUpdate.Draw()
		Routines.PerfectNode.Draw()
		
		-- Update effect player
		EffectPlayer.Update(deltaT)
	end
	
	if DEPLS.DebugDisplay then
		local sample = DEPLS.StoryboardFunctions.GetCurrentAudioSample()[1]
		local text = string.format([[
%d FPS
SAVE_DIR = %s
NOTE_SPEED = %d ms
ELAPSED_TIME = %d ms
SPEED_FACTOR = %.2f%%
CURRENT_COMBO = %d
PLAYING_EFFECT = %d
LIVE_OPACITY = %.2f
BACKGROUND_BLACKNESS = %.2f
AUDIO_VOLUME = %.2f
AUDIO_SAMPLE = %5.2f, %5.2f
PERFECT = %d GREAT = %d
GOOD = %d BAD = %d MISS = %d
AUTOPLAY = %s
]]			, love.timer.getFPS(), DEPLS.SaveDirectory, DEPLS.NotesSpeed, DEPLS.ElapsedTime, DEPLS.PlaySpeed * 100
			, DEPLS.Routines.ComboCounter.CurrentCombo, #EffectPlayer.list, DEPLS.LiveOpacity, DEPLS.BackgroundOpacity
			, DEPLS.BeatmapAudioVolume, sample[1], sample[2], DEPLS.NoteManager.Perfect, DEPLS.NoteManager.Great
			, DEPLS.NoteManager.Good, DEPLS.NoteManager.Bad, DEPLS.NoteManager.Miss, tostring(DEPLS.AutoPlay))
		setColor(0, 0, 0, 255)
		love.graphics.print(text, 1, 1)
		setColor(255, 255, 255, 255)
		love.graphics.print(text)
	end
end

-- LOVE2D mouse/touch pressed
function love.mousepressed(x, y, button, touch_id)
	if touch_id == true then return end
	if DEPLS.ElapsedTime <= 0 then return end
	
	touch_id = touch_id or 0
	x, y = CalculateTouchPosition(x, y)
	
	-- Calculate idol
	for i = 1, 9 do
		local idolpos = DEPLS.IdolPosition[i]
		
		if distance(x - (idolpos[1] + 64), y - (idolpos[2] + 64)) <= 77 then
			DEPLS.NoteManager.SetTouch(i, touch_id)
		end
	end
end

-- LOVE2D mouse/touch released
function love.mousereleased(x, y, button, touch_id)
	if touch_id == true then return end
	if DEPLS.ElapsedTime <= 0 then return end
	
	touch_id = touch_id or 0
	x, y = CalculateTouchPosition(x, y)
	
	-- Send unset touch message
	DEPLS.NoteManager.SetTouch(nil, touch_id, true)
end

local function update_audio_volume()
	if DEPLS.Sound.LiveAudio then
		DEPLS.Sound.LiveAudio:setVolume(DEPLS.BeatmapAudioVolume)
	end
end

-- LOVE2D key press
function love.keypressed(key, scancode, repeat_bit)
	if key == "f6" then
		DEPLS.BeatmapAudioVolume = math.min(DEPLS.BeatmapAudioVolume + 0.05, 1)
		update_audio_volume()
	elseif scancode == "f5" then
		DEPLS.BeatmapAudioVolume = math.max(DEPLS.BeatmapAudioVolume - 0.05, 0)
		update_audio_volume()
	elseif repeat_bit == false then
		if key == "escape" then
			if DEPLS.Sound.LiveAudio then
				DEPLS.Sound.LiveAudio:stop()
			end
			
			-- Back
			MountZip()	-- Unmount
			LoadEntryPoint("main_menu.lua")
		elseif key == "backspace" then
			if DEPLS.Sound.LiveAudio then
				DEPLS.Sound.LiveAudio:stop()
			end
			
			-- Restart
			LoadEntryPoint("livesim.lua", DEPLS.Arg)
		elseif key == "lshift" then
			DEPLS.DebugDisplay = not(DEPLS.DebugDisplay)
		elseif key == "lctrl" then
			DEPLS.AutoPlay = not(DEPLS.AutoPlay)
		elseif key == "lalt" then
			DEPLS.DebugNoteDistance = not(DEPLS.DebugNoteDistance)
		elseif key == "pageup" and not(DEPLS.PlaySpeedAlterDisabled) and DEPLS.PlaySpeed < 4 then
			-- Increase play speed
			DEPLS.StoryboardFunctions.SetPlaySpeed(DEPLS.PlaySpeed * 2)
		elseif key == "pagedown" and not(DEPLS.PlaySpeedAlterDisabled) and DEPLS.PlaySpeed > 0.0625 then
			-- Decrease play speed
			DEPLS.StoryboardFunctions.SetPlaySpeed(DEPLS.PlaySpeed * 0.5)
		elseif key == "up" then
			DEPLS.StoryboardFunctions.SetNotesSpeed(DEPLS.NotesSpeed + 100)
		elseif key == "down" and DEPLS.NotesSpeed > 400 then
			DEPLS.StoryboardFunctions.SetNotesSpeed(DEPLS.NotesSpeed - 100)
		elseif DEPLS.ElapsedTime >= 0 then
			for i = 1, 9 do
				if key == DEPLS.Keys[i] then
					DEPLS.NoteManager.SetTouch(i, key)
					break
				end
			end
		end
	end
end

-- LOVE2D key release
function love.keyreleased(key)
	if DEPLS.ElapsedTime <= 0 then return end
	
	for i = 1, 9 do
		if key == DEPLS.Keys[i] then
			DEPLS.NoteManager.SetTouch(nil, key, true)
			break
		end
	end
end

require("touch_manager")

DEPLS.Distance = distance
DEPLS.AngleFrom = angle_from

return DEPLS
