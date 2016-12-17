--! @file livesim.lua
-- DEPLS, playable version

local love = love
local tween = require("tween")
local EffectPlayer = require("effect_player")
local List = require("List")
local JSON = require("JSON")
local DEPLS = {
	ElapsedTime = 0,	-- Elapsed time, in milliseconds
	DebugDisplay = true,
	SaveDirectory = "",	-- DEPLS Save Directory
	LogicalScale = {
		ScreenX = 960,
		ScreenY = 640,
		OffX = 0,
		OffY = 0,
		ScaleOverall = 1
	},
	
	BackgroundOpacity = 255,	-- User background opacity set from storyboard
	BackgroundImage = {	-- Index 0 is the main background
		-- {handle, logical x, logical y}
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
	IdolImageData = {},	-- [idol positon] = {image handle, opacity}
	NoteAccuracy = {{16, nil}, {40, nil}, {64, nil}, {112, nil}, {128, nil}},	-- Note accuracy
	NoteManager = nil,
	NoteLoader = nil,
	Stamina = 32,
	NotesSpeed = 800,
	ScoreBase = 500,
	
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
			ComboCounter.Replay = false
		end
		
		-- Don't draw if combo is 0
		if CurrentCombo > 0 then
			-- "combo" pos: 541x267+61+17
			-- number pos: 451x267+24+24; aligh right; subtract by 43 for distance
			combo_tween:update(deltaT)
			
			local combo_str = {string.byte(tostring(CurrentCombo), 1, 2147483647)}
			local img = ComboNumbers[ComboCounter.GetComboColorIndex(CurrentCombo)]
			
			::draw_update_sync2::
			if coroutine.yield() then goto draw_update_sync2 end	-- love.draw part
			
			setColor(255, 255, 255, DEPLS.LiveOpacity)
			
			for i = 1, #combo_str do
				-- Draw numbers
				draw(img[combo_str[i] - 47], 451 - (#combo_str - i) * 43, 267, 0, combo_scale.s, combo_scale.s, 24, 24)
			end
			
			draw(img.combo, 541, 267, 0, combo_scale.s, combo_scale.s, 61, 17)
			
			setColor(255, 255, 255, DEPLS.LiveOpacity)
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

--! @brief Load configuration
--! @param config_name The configuration name
--! @param default_value The default value of the configuration
--! @returns Configuration value or `default_value` (and save it as `default_value`)
function DEPLS.LoadConfig(config_name, default_value)
	local file = love.filesystem.newFile(config_name..".txt", "r")
	
	if file == nil then
		file = io.open(DEPLS.SaveDirectory.."/"..config_name..".txt", "wb")
		file:write(tostring(default_value))
		file:close()
		
		return default_value
	end
	
	local data = file:read()
	
	return tonumber(data) or data
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
		
		if file then
			_, token_image = pcall(love.audio.newSource, path, "static")
			
			if _ then
				return token_image
			end
		end
	end
	
	_, token_image = pcall(love.audio.newSource, path, "static")
	
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

--! @brief Sets foreground live opacity
--! @param opacity Transparency. 1 = opaque, 0 = invisible
function DEPLS.StoryboardFunctions.SetLiveOpacity(opacity)
	opacity = math.max(math.min(opacity or 255, 255), 0)
	
	DEPLS.LiveOpacity = opacity
end

--! @brief Sets background blackness
--! @param opacity Transparency. 1 = full black, 0 = full light
function DEPLS.StoryboardFunctions.SetBackgroundDimOpacity(opacity)
	opacity = math.max(math.min(opacity or 255, 255), 0)
	
	DEPLS.BackgroundOpacity = 255 - opacity
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

--! @brief DEPLS Initialization function
--! @param argv The arguments passed to the game via command-line
function DEPLS.Start(argv)
	DEPLS.Arg = argv
	package.loaded.DEPLS = DEPLS
	_G.DEPLS = DEPLS
	
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
	
	-- Calculate display resolution scale
	DEPLS.SaveDirectory = love.filesystem.getSaveDirectory()
	DEPLS.LogicalScale.ScreenX, DEPLS.LogicalScale.ScreenY = love.graphics.getDimensions()
	DEPLS.LogicalScale.ScaleX = DEPLS.LogicalScale.ScreenX / 960
	DEPLS.LogicalScale.ScaleY = DEPLS.LogicalScale.ScreenY / 640
	DEPLS.LogicalScale.ScaleOverall = math.min(DEPLS.LogicalScale.ScaleX, DEPLS.LogicalScale.ScaleY)
	DEPLS.LogicalScale.OffX = (DEPLS.LogicalScale.ScreenX - DEPLS.LogicalScale.ScaleOverall * 960) / 2
	DEPLS.LogicalScale.OffY = (DEPLS.LogicalScale.ScreenY - DEPLS.LogicalScale.ScaleOverall * 640) / 2
	
	-- Force love2d to make directory
	love.filesystem.createDirectory("audio")
	love.filesystem.createDirectory("beatmap")
	
	-- Load configuration
	local BackgroundID = DEPLS.LoadConfig("BACKGROUND_IMAGE", 11)
	local Keys = DEPLS.LoadConfig("IDOL_KEYS", "a\ts\td\tf\tspace\tj\tk\tl\t;")
	local Auto = DEPLS.LoadConfig("AUTOPLAY", 0)
	DEPLS.LiveDelay = DEPLS.LoadConfig("LIVESIM_DELAY", 1000)
	DEPLS.ElapsedTime = -DEPLS.LiveDelay
	DEPLS.NotesSpeed = DEPLS.LoadConfig("NOTE_SPEED", 800)
	DEPLS.Stamina = DEPLS.LoadConfig("STAMINA_DISPLAY", 32)
	DEPLS.ScoreBase = DEPLS.LoadConfig("SCORE_ADD_NOTE", 1024)
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
	notes_list, DEPLS.StoryboardHandle, DEPLS.Sound.BeatmapAudio = DEPLS.NoteLoader(argv[2])
	
	-- Add to note manager
	for i = 1, #notes_list do
		DEPLS.NoteManager.Add(notes_list[i])
	end
	
	-- Calculate note accuracy
	for i = 1, 5 do
		DEPLS.NoteAccuracy[i][2] = DEPLS.NoteAccuracy[i][1] * 1000 / DEPLS.NotesSpeed
	end
	
	-- Load beatmap audio
	if not(DEPLS.Sound.BeatmapAudio) then
		-- Beatmap audio needs to be safe loaded
		DEPLS.Sound.BeatmapAudio = DEPLS.LoadAudio("audio/"..(argv[3] or argv[2]..".wav"), not(not(argv[3])))
	end
	
	----------------------
	-- Load image start --
	----------------------
	
	-- Load background if no storyboard present
	if not(DEPLS.StoryboardHandle) then
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
	local IdolImagePath = {}
	do
		local idol_img = DEPLS.LoadConfig("IDOL_IMAGE", "a.png,a.png,a.png,a.png,a.png,a.png,a.png,a.png,a.png")
		
		for w in idol_img:gmatch("[^,]+") do
			IdolImagePath[#IdolImagePath + 1] = w
		end
	end
	for i = 1, 9 do
		DEPLS.IdolImageData[i] = {DEPLS.LoadUnitIcon(IdolImagePath[10 - i]), 255}
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

--! @brief DEPLS Update function. It is separated to allow offline rendering
--! @param deltaT Delta-time in milliseconds
function DEPLS.Update(deltaT)
	DEPLS.ElapsedTime = DEPLS.ElapsedTime + deltaT
	
	local ElapsedTime = DEPLS.ElapsedTime
	local Routines = DEPLS.Routines
	
	if ElapsedTime <= 0 then
		persistent_bg_opacity = (ElapsedTime + DEPLS.LiveDelay) / DEPLS.LiveDelay * 191
	end
	
	if ElapsedTime > 0 then
		-- TODO update all
		if DEPLS.Sound.BeatmapAudio and audioplaying == false then
			DEPLS.Sound.BeatmapAudio:setVolume(0.8)
			DEPLS.Sound.BeatmapAudio:seek(ElapsedTime / 1000)
			DEPLS.Sound.BeatmapAudio:play()
			audioplaying = true
		end
		
		-- Update note
		DEPLS.NoteManager.Update(deltaT)
		
		-- Update routines
		Routines.ComboCounter.Draw(deltaT)
		Routines.NoteIcon.Draw(deltaT)
		Routines.ScoreEclipseF.Draw(deltaT)
		Routines.ScoreUpdate.Draw(deltaT)
		Routines.PerfectNode.Draw(deltaT)
	end
end

--! @brief DEPLS Draw function. It is separated to allow offline rendering
--! @param deltaT Delta-time in milliseconds
function DEPLS.Draw(deltaT)
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
		
		for i = 0, 4 do
			draw(BackgroundImage[i][1], BackgroundImage[i][2], BackgroundImage[i][3])
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
		Routines.ScoreEclipseF.Draw()
		Routines.ScoreUpdate.Draw()
		Routines.PerfectNode.Draw()
		
		-- Update effect player
		EffectPlayer.Update(deltaT)
	end
	
	if DEPLS.DebugDisplay then
		local text = string.format([[
%d FPS
SAVE_DIR = %s
NOTE_SPEED = %d ms
ELAPSED_TIME = %d ms
CURRENT_COMBO = %d
RUNNING_EFFECT = %d
LIVE_OPACITY = %.2f
BACKGROUND_BLACKNESS = %.2f
PERFECT = %d GREAT = %d
GOOD = %d BAD = %d MISS = %d
AUTOPLAY = %s
]]			, love.timer.getFPS(), DEPLS.SaveDirectory, DEPLS.NotesSpeed, DEPLS.ElapsedTime
			, DEPLS.Routines.ComboCounter.CurrentCombo, #EffectPlayer.list, DEPLS.LiveOpacity, DEPLS.BackgroundOpacity
			, DEPLS.NoteManager.Perfect, DEPLS.NoteManager.Great, DEPLS.NoteManager.Good
			, DEPLS.NoteManager.Bad, DEPLS.NoteManager.Miss, tostring(DEPLS.AutoPlay))
		setColor(0, 0, 0, 255)
		love.graphics.print(text, 1, 1)
		setColor(255, 255, 255, 255)
		love.graphics.print(text)
	end
end

-- LOVE2D update routines
function love.update(deltaT)
	local Update = DEPLS.Update
	
	-- Skip 1 frame
	function love.update(deltaT)
		deltaT = deltaT * 1000
		Update(deltaT)
	end
end

-- LOVE2D draw routines
function love.draw()
	local Draw = DEPLS.Draw
	local push = love.graphics.push
	local pop = love.graphics.pop
	local translate = love.graphics.translate
	local scale = love.graphics.scale
	local LogicalScale = DEPLS.LogicalScale
	
	-- Skip 1 frame
	function love.draw()
		local deltaT = love.timer.getDelta() * 1000
		
		push()
		translate(LogicalScale.OffX, LogicalScale.OffY)
		scale(LogicalScale.ScaleOverall, LogicalScale.ScaleOverall)
		Draw(deltaT)
		pop()
	end
end

--! @brief Translates physical touch position to logical touch position
--! @param x Physical touch x coordinate
--! @param y Physical touch y coordinate
--! @returns Logical x and y coordinate
local function calculate_touch_position(x, y)
	return
		(x - DEPLS.LogicalScale.OffX) / DEPLS.LogicalScale.ScaleOverall,
		(y - DEPLS.LogicalScale.OffY) / DEPLS.LogicalScale.ScaleOverall
end

-- LOVE2D mouse/touch pressed
function love.mousepressed(x, y, button, touch_id)
	if touch_id == true then return end
	if DEPLS.ElapsedTime <= 0 then return end
	
	touch_id = touch_id or 0
	x, y = calculate_touch_position(x, y)
	
	-- Calculate idol
	for i = 1, 9 do
		local idolpos = DEPLS.IdolPosition[i]
		
		if distance(x - (idolpos[1] + 64), y - (idolpos[2] + 64)) <= 74 then
			DEPLS.NoteManager.SetTouch(i, touch_id)
		end
	end
end

-- LOVE2D mouse/touch released
function love.mousereleased(x, y, button, touch_id)
	if touch_id == true then return end
	if DEPLS.ElapsedTime <= 0 then return end
	
	touch_id = touch_id or 0
	x, y = calculate_touch_position(x, y)
	
	-- Send unset touch message
	DEPLS.NoteManager.SetTouch(nil, touch_id, true)
end

-- LOVE2D key press
function love.keypressed(key, scancode, repeat_bit)
	if repeat_bit == false then
		if key == "backspace" then
			if DEPLS.Sound.BeatmapAudio then
				DEPLS.Sound.BeatmapAudio:stop()
			end
			
			-- Restart
			love.filesystem.load("livesim.lua")().Start(DEPLS.Arg)
		elseif key == "lshift" then
			DEPLS.DebugDisplay = not(DEPLS.DebugDisplay)
		elseif key == "lctrl" then
			DEPLS.AutoPlay = not(DEPLS.AutoPlay)
		elseif key == "lalt" then
			DEPLS.DebugNoteDistance = not(DEPLS.DebugNoteDistance)
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

-- LOVE2D on window resize
function love.resize(w, h)
	DEPLS.LogicalScale.ScreenX, DEPLS.LogicalScale.ScreenY = w, h
	DEPLS.LogicalScale.ScaleX = DEPLS.LogicalScale.ScreenX / 960
	DEPLS.LogicalScale.ScaleY = DEPLS.LogicalScale.ScreenY / 640
	DEPLS.LogicalScale.ScaleOverall = math.min(DEPLS.LogicalScale.ScaleX, DEPLS.LogicalScale.ScaleY)
	DEPLS.LogicalScale.OffX = (DEPLS.LogicalScale.ScreenX - DEPLS.LogicalScale.ScaleOverall * 960) / 2
	DEPLS.LogicalScale.OffY = (DEPLS.LogicalScale.ScreenY - DEPLS.LogicalScale.ScaleOverall * 640) / 2
	
	print("=== Resize ===")
	print("New Dimension", w, h)
	print("Scale", DEPLS.LogicalScale.ScaleX, DEPLS.LogicalScale.ScaleY, DEPLS.LogicalScale.ScaleOverall)
	print("Offset", DEPLS.LogicalScale.OffX, DEPLS.LogicalScale.OffY)
	print("=== Resize ===")
end

require("touch_manager")

DEPLS.Distance = distance
DEPLS.AngleFrom = angle_from

return DEPLS
