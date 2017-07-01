-- Beatmap selection
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine = ...
local SelectBeatmap = {}
local BeatmapList = {}
local CurrentPage = 0
local BeatmapSelectedIndex = 0
local MouseState = {X = 0, Y = 0, Pressed = {}}
local NoteLoader

local com_button_14, com_button_14di, com_button_14se
local com_win_02
local s_button_03, s_button_03se
local com_button_12, com_button_12se
local com_button_13, com_button_13se
local log_etc_08
local liveback_1

local BackImage
local BackButton
local BackButtonSe

local MTLmr3m
local FontDesc

local IsRandomForced = AquaShine.GetCommandLineConfig("random")
local IsRandomNotesWasTicked
local HasBeatmapInstalled = false
local CaseInsensitivePath = AquaShine.OperatingSystem == "Windows"
local RandomMountPoint = string.format("temp/%09d", math.random(1, 999999999))

function SelectBeatmap.Start(arg)
	local noteloader = assert(love.filesystem.load("note_loader.lua"))()
	BeatmapList = noteloader.Enumerate()
	
	com_button_14 = AquaShine.LoadImage("assets/image/ui/com_button_14.png")
	com_button_14di = AquaShine.LoadImage("assets/image/ui/com_button_14di.png")
	com_button_14se = AquaShine.LoadImage("assets/image/ui/com_button_14se.png")
	
	com_win_02 = AquaShine.LoadImage("assets/image/ui/com_win_02.png")
	s_button_03 = AquaShine.LoadImage("assets/image/ui/s_button_03.png")
	s_button_03se = AquaShine.LoadImage("assets/image/ui/s_button_03se.png")
	log_etc_08 = AquaShine.LoadImage("assets/image/ui/log_etc_08.png")
	com_button_12 = AquaShine.LoadImage("assets/image/ui/com_button_12.png")
	com_button_12se = AquaShine.LoadImage("assets/image/ui/com_button_12se.png")
	com_button_13 = AquaShine.LoadImage("assets/image/ui/com_button_13.png")
	com_button_13se = AquaShine.LoadImage("assets/image/ui/com_button_13se.png")
	
	liveback_1 = {AquaShine.LoadImage(
		"assets/image/background/liveback_1.png",
		"assets/image/background/b_liveback_001_01.png",
		"assets/image/background/b_liveback_001_02.png",
		"assets/image/background/b_liveback_001_03.png",
		"assets/image/background/b_liveback_001_04.png"
	)}
	
	BackImage = AquaShine.LoadImage("assets/image/ui/com_win_02.png")
	BackButton = AquaShine.LoadImage("assets/image/ui/com_button_01.png")
	BackButtonSe = AquaShine.LoadImage("assets/image/ui/com_button_01se.png")
	
	MTLmr3m = AquaShine.LoadFont("MTLmr3m.ttf", 14)
	FontDesc = AquaShine.LoadFont("MTLmr3m.ttf", 22)
	
	IsRandomNotesWasTicked = arg.Random
	
	if arg[1] then
		for i = 1, #BeatmapList do
			if BeatmapList[i].name == arg[1] then
				BeatmapSelectedIndex = i
				CurrentPage = math.floor((i - 1) / 40)
				
				break
			end
		end
	end
end

function SelectBeatmap.Update()
	if HasBeatmapInstalled then
		local SelBeatmap
		
		if BeatmapSelectedIndex > 0 then
			SelBeatmap = BeatmapList[BeatmapSelectedIndex].name
		end
		
		AquaShine.LoadEntryPoint("select_beatmap.lua", {SelBeatmap})
	end
end

local draw = love.graphics.draw
local drawtext = love.graphics.print
local setFont = love.graphics.setFont
local setColor = love.graphics.setColor

function SelectBeatmap.Draw()
	-- Grid: 4x10 beatmap list. Starts at 48x100px
	setColor(255, 255, 255)
	draw(liveback_1[1])
	draw(liveback_1[2], -88, 0)
	draw(liveback_1[3], 960, 0)
	draw(liveback_1[4], 0, -43)
	draw(liveback_1[5], 0, 640)
	setFont(FontDesc)
	draw(BackImage, -98, 0)
	setColor(0, 0, 0)
	drawtext("Select Beatmap", 95, 13)
	drawtext(string.format("Page %d", CurrentPage + 1), 52, 500)
	setColor(255, 255, 255)
	setFont(MTLmr3m)
	
	if MouseState.Pressed[1] then
		if
			MouseState.X >= 0 and MouseState.X <= 86 and
			MouseState.Y >= 0 and MouseState.Y <= 58
		then
			draw(BackButtonSe)
		else
			draw(BackButton)
		end
		
		if
			MouseState.X >= 0 and MouseState.X < 48 and
			MouseState.Y >= 272 and MouseState.Y < 328
		then
			draw(com_button_12se, 0, 272)
		else
			draw(com_button_12, 0, 272)
		end
		
		if
			MouseState.X >= 912 and MouseState.X < 960 and
			MouseState.Y >= 272 and MouseState.Y < 328
		then
			draw(com_button_13se, 912, 272)
		else
			draw(com_button_13, 912, 272)
		end
	else
		draw(BackButton)
		draw(com_button_12, 0, 272)
		draw(com_button_13, 912, 272)
	end
	
	-- Install beatmaps button
	if AquaShine.FileSelection then
		draw(s_button_03, 480, 18, 0, 0.5, 0.5)
		drawtext("Add Beatmap(s)", 488, 26)
	end
	
	-- Open beatmap directory
	draw(s_button_03, 696, 18, 0, 0.5, 0.5)
	drawtext("Open Beatmap Folder", 704, 26)
	
	for i = CurrentPage * 40 + 1, (CurrentPage + 1) * 40 do
		local beatmap_info = BeatmapList[i]
		
		if beatmap_info then
			local xpos = 48 + ((i - 1 - CurrentPage * 40) % 4) * 216
			local ypos = 100 + math.floor((i - 1 - CurrentPage * 40) * 0.25) * 40
			
			if BeatmapSelectedIndex == i then
				draw(s_button_03, xpos, ypos, 0, 0.5, 0.5)
				setColor(255, 255, 255, 127)
				draw(s_button_03se, xpos, ypos, 0, 0.5, 0.5)
				setColor(255, 255, 255, 255)
				setFont(FontDesc)
				drawtext("Type: ", 52, 536)
				drawtext(beatmap_info.type, 108, 536)
				setFont(MTLmr3m)
			elseif
				MouseState.X >= xpos and MouseState.X < xpos + 216 and
				MouseState.Y >= ypos and MouseState.Y < ypos + 40
			then
				draw(s_button_03se, xpos, ypos, 0, 0.5, 0.5)
			else
				draw(s_button_03, xpos, ypos, 0, 0.5, 0.5)
			end
			
			drawtext(beatmap_info.name, xpos + 8, ypos + 8)
		end
	end
	
	if BeatmapSelectedIndex > 0 then
		if MouseState.X >= 760 and MouseState.X <= 904 and
		   MouseState.Y >= 530 and MouseState.Y <= 588 and
		   MouseState.Pressed[1]
		then
			draw(com_button_14se, 760, 530)
		else
			draw(com_button_14, 760, 530)
		end
	else
		draw(com_button_14di, 760, 530)
	end
	
	-- Render mode/Random notes check
	setFont(FontDesc)
	love.graphics.rectangle("fill", 476, 528, 32, 32)
	drawtext("Random (experimental)", 526, 533)
	
	if IsRandomNotesWasTicked then
		draw(log_etc_08, 477, 528, 0, 0.842105)
	elseif IsRandomForced then
		setColor(0, 0, 0, 127)
		draw(log_etc_08, 477, 528, 0, 0.842105)
	end
end

function SelectBeatmap.MousePressed(x, y, button)
	MouseState.X, MouseState.Y = x, y
	MouseState.Pressed[button] = true
end

function SelectBeatmap.MouseMoved(x, y)
	MouseState.X, MouseState.Y = x, y
end

function SelectBeatmap.MouseReleased(x, y, button)
	MouseState.X, MouseState.Y = x, y
	MouseState.Pressed[button] = false
	
	if x >= 0 and x <= 86 and y >= 0 and y <= 58 then
		AquaShine.LoadEntryPoint("main_menu.lua")
		return
	elseif AquaShine.FileSelection and x >= 696 and y >= 18 and x < 912 and y < 58 then
		-- Open beatmap folder
		love.system.openURL("file://"..love.filesystem.getSaveDirectory().."/beatmap")
	elseif x >= 480 and y >= 18 and x < 696 and y < 58 then
		-- File selection
		local randomdest = string.format("temp/temp_store_%08X", math.random(0, 4294967295))
		local files = AquaShine.FileSelection("Select Beatmaps to Add", nil, "*.zip *.json *.ls2 *.llp *.rs *.mid *.txt *.wav *.ogg *.mp3", true)
		
		if #files > 0 then
			assert(love.filesystem.createDirectory(randomdest))
			
			for i = 1, #files do
				local filename = files[i]
				local newpath = randomdest.."/"..AquaShine.Basename(filename)
				local f = assert(io.open(filename, "rb"))
				
				love.filesystem.write(newpath, f:read("*a"))
				f:close()
				
				f = love.filesystem.newFile(newpath)
				
				SelectBeatmap.FileDropped(f)
				f:close()
				
				love.filesystem.remove(newpath)
			end
			
			love.filesystem.remove(randomdest)
		end
	end
	
	do
		-- Check if Ok button is pressed
		if BeatmapSelectedIndex > 0 and
		   x >= 760 and x <= 904 and
		   y >= 530 and y <= 588
		then
			-- Start livesim
			AquaShine.LoadEntryPoint("livesim.lua", {BeatmapList[BeatmapSelectedIndex].name, Random = IsRandomNotesWasTicked})
			
			return
		elseif not(IsRandomForced) and
			x >= 476 and x < 508 and
			y >= 528 and y < 560
		then
			-- Random note check
			IsRandomNotesWasTicked = not(IsRandomNotesWasTicked)
			return
		elseif x >= 0 and x < 48 and y >= 272 and y < 328 then
			-- Prev
			CurrentPage = math.max(CurrentPage - 1, 0)
		elseif x >= 912 and x < 960 and y >= 272 and y < 328 then
			-- Next
			CurrentPage = math.min(math.floor(math.max(#BeatmapList - 1, 0) / 40), CurrentPage + 1)
		end
	end
	
	do
		-- Get beatmap index from x and y
		local bm_idx
		local bm_idx_y
		local bm_idx_x = math.floor((x - 48) / 216)
		
		if bm_idx_x < 0 or bm_idx_x > 3 then
			BeatmapSelectedIndex = 0
			return
		end
		
		bm_idx_y = math.floor((y - 100) / 40)
		
		if bm_idx_y < 0 or bm_idx_y > 9 then
			BeatmapSelectedIndex = 0
			return
		end
		
		local bm_idx = CurrentPage * 40 + 1 + bm_idx_y * 4 + bm_idx_x
		
		if BeatmapList[bm_idx] then
			BeatmapSelectedIndex = bm_idx
		else
			BeatmapSelectedIndex = 0
		end
	end
end

function SelectBeatmap.KeyReleased(key, scancode)
	if key == "escape" then
		AquaShine.LoadEntryPoint("main_menu.lua")
	end
end

-- Beatmap insertion function
local function RemoveExtension(file)
	local _ = file:reverse()
	return _:sub((_:find("%.") or 0) + 1):reverse()
end

local function BeatmapExists(path)
	local _ = path:reverse()
	local beatmap_name = _:sub((_:find("%.") or 0) + 1, (_:find("/") or _:find("\\") or #_ + 1) - 1):reverse()
	
	if CaseInsensitivePath then
		beatmap_name = beatmap_name:lower()
	end
	
	for i = 1, #BeatmapList do
		local name = BeatmapList[i].name
		
		if CaseInsensitivePath then
			name = name:lower()
		end
		
		if beatmap_name == name then
			io.write("Beatmap with name \"", name, "\" already exist\n")
			
			return true
		end
	end
	
	return false
end

-- Both source and dest should not have trailing slash
local function CopyDirRecursive(source, dest)
	local list = love.filesystem.getDirectoryItems(source)
	
	for i = 1, #list do
		local filename = source.."/"..list[i]
		
		if love.filesystem.isFile(filename) then
			love.filesystem.write(dest.."/"..list[i], love.filesystem.read(filename))
		elseif love.filesystem.isDirectory(filename) then
			-- Create directory
			local dest_filename = dest.."/"..list[i]
			
			assert(love.filesystem.createDirectory(dest_filename), "Failed to create directory")
			CopyDirRecursive(filename, dest_filename)
		end
	end
end

function SelectBeatmap.FileDropped(file)
	local filename = file:getFilename()
	local ext = filename:sub(-4)
	
	if ext == ".wav" or ext == ".ogg" or ext == ".mp3" then
		assert(file:open("r"))
		love.filesystem.write("audio/"..AquaShine.Basename(filename), file:read())
		file:close()
		
		return
	end
	
	if not(NoteLoader) then
		NoteLoader = assert(love.filesystem.load("note_loader.lua"))()
	end
	
	if not(BeatmapExists(filename)) then
		local beatmap_filename = AquaShine.Basename(filename)
		local dest_file = "temp/"..beatmap_filename
		assert(file:open("r"))
		
		-- Copy to temp folder
		love.filesystem.write(dest_file, file:read())
		
		if NoteLoader.DetectSpecific("temp/"..RemoveExtension(beatmap_filename)) then
			-- Move it
			love.filesystem.write("beatmap/"..beatmap_filename, love.filesystem.read(dest_file))
			
			HasBeatmapInstalled = true
		else
			io.write(beatmap_filename, " is not a valid beatmap\n")
		end
		
		love.filesystem.remove(dest_file)
	end
end

function SelectBeatmap.DirectoryDropped(dir)
	if not(NoteLoader) then
		NoteLoader = assert(love.filesystem.load("note_loader.lua"))()
	end
	
	if not(BeatmapExists(dir)) then
		assert(love.filesystem.mount(dir, RandomMountPoint), "Cannot mount directory")
		
		if NoteLoader.DetectSpecific(RandomMountPoint) then
			-- Copy recursive
			local beatmap_dest = "beatmap/"..AquaShine.Basename(dir)
			
			love.filesystem.createDirectory(beatmap_dest)
			CopyDirRecursive(RandomMountPoint, beatmap_dest)
			
			HasBeatmapInstalled = true
		else
			io.write(beatmap_filename, " is not a valid beatmap\n")
		end
		
		love.filesystem.unmount(dir)
	end
end

return SelectBeatmap, "Beatmap Selection"
