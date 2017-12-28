-- Beatmap selection screen, using AquaShineNode as UI elements
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine = ...
local love = love
local NoteLoader = AquaShine.LoadModule("note_loader2")
local BackgroundImage = AquaShine.LoadModule("uielement.background_image")
local TextShadow = AquaShine.LoadModule("uielement.text_with_shadow")
local SimpleButton = AquaShine.LoadModule("uielement.simple_button")
local BeatmapInfo = AquaShine.LoadModule("uielement.beatmap_info")
local BeatmapSelButton = AquaShine.LoadModule("uielement.beatmap_select_button")
local BackNavigation = AquaShine.LoadModule("uielement.backnavigation")
local BeatmapSelect = {SaveDir = love.filesystem.getSaveDirectory().."/"}

local usableChar = {"0123456789", "abcdefghijklmnopqrstuvwxyz"}
usableChar[3] = usableChar[2]:upper()
function BeatmapSelect.CreateRandomString()
	local a = {}
	for i = 1, 16 do
		local b = usableChar[math.random(1, 3)]
		local c = math.random(1, #b)
		a[#a + 1] = b:sub(c, c)
	end
	
	return table.concat(a)
end

function BeatmapSelect.Start(arg)
	local beatmap_list
	local savedir = love.filesystem.getSaveDirectory()
	BeatmapSelect.TempArg = arg
	BeatmapSelect.MainNode = BackgroundImage(1)
	BeatmapSelect.NodeList = {}
	BeatmapSelect.Page = 0
	BeatmapSelect.SwipeData = {nil, nil}	-- Touch handle (or 0 for mouse click), x1
	BeatmapSelect.SwipeThreshold = 128
	
	if AquaShine.LoadConfig("BEATMAP_SELECT_CACHED", 0) == 1 then
		beatmap_list = NoteLoader.EnumerateCached()
		
		-- Sort by name
		table.sort(beatmap_list, function(a, b)
			return a.name < b.name
		end)
	else
		beatmap_list = NoteLoader.Enumerate()
		
		-- Sort by name
		table.sort(beatmap_list, function(a, b)
			return a:GetName() < b:GetName()
		end)
	end
	
	-- Back button
	BeatmapSelect.MainNode:addChild(BackNavigation("Select Beatmap", ":main_menu"))
	
	-- Beatmap info
	BeatmapSelect.Info = BeatmapInfo(arg.RandomWasTicked)
	BeatmapSelect.MainNode:addChild(BeatmapSelect.Info)
	
	-- Each node contain 8 buttons
	for i = 1, math.ceil(#beatmap_list / 8) do
		local node = AquaShine.Node()
		
		for j = 1, 8 do
			local idx = (i - 1) * 8 + j
			if not(beatmap_list[idx]) then break end
			
			node:addChild(BeatmapSelButton(beatmap_list[idx], BeatmapSelect.Info):setPosition(60, j * 60 + 20))
		end
		
		BeatmapSelect.NodeList[i] = node
	end
	
	-- Page text
	BeatmapSelect.PageNumber = TextShadow(AquaShine.LoadFont("MTLmr3m.ttf", 22), "Page 1/"..#BeatmapSelect.NodeList, 64, 560):setShadow(1, 1, true)
	BeatmapSelect.MainNode:addChild(BeatmapSelect.PageNumber)
	
	-- Open beatmap directory
	BeatmapSelect.MainNode:addChild(
		SimpleButton(
			AquaShine.LoadImage("assets/image/ui/s_button_03.png"),
			AquaShine.LoadImage("assets/image/ui/s_button_03se.png"),
			function()
				love.system.openURL(savedir)
			end,
			0.5
		)
		:setPosition(64, 592)
		:initText(AquaShine.LoadFont("MTLmr3m.ttf", 18), "Open Beatmap Directory")
		:setTextPosition(8, 6)
	)
	
	-- Insert beatmap, if FileSelection is available
	if AquaShine.FileSelection then
		BeatmapSelect.MainNode:addChild(
			SimpleButton(
				AquaShine.LoadImage("assets/image/ui/s_button_03.png"),
				AquaShine.LoadImage("assets/image/ui/s_button_03se.png"),
				function()
					local list = AquaShine.FileSelection("Insert Beatmap(s)", nil, nil, true)
					BeatmapSelect.FileDropped(list)
				end,
				0.5
			)
			:setPosition(736, 8)
			:initText(AquaShine.LoadFont("MTLmr3m.ttf", 18), "Insert Beatmap(s)")
			:setTextPosition(8, 6)
		)
	end
	
	-- Download beatmap
	BeatmapSelect.MainNode:addChild(
		SimpleButton(
			AquaShine.LoadImage("assets/image/ui/s_button_03.png"),
			AquaShine.LoadImage("assets/image/ui/s_button_03se.png"),
			function()
				AquaShine.LoadEntryPoint("dl_wrap.lua")
			end,
			0.5
		)
		:setPosition(512, 8)
		:initText(AquaShine.LoadFont("MTLmr3m.ttf", 18), "Download Beatmap(s)")
		:setTextPosition(8, 6)
	)
	
	-- Set brother button
	BeatmapSelect.MainNode.brother = BeatmapSelect.NodeList[1]
end

function BeatmapSelect.FileDropped(list)
	local hasInstalled = false
	for i, v in ipairs(list) do
		local f, h = io.open(v:getFilename(), "rb")
		
		if f then
			local output = "temp/"..BeatmapSelect.CreateRandomString()
			local fh, h = love.filesystem.newFile(output, "w")
			
			if fh then
				
				repeat
					local contents = f:read(8192)
					fh:write(contents)
				until #contents < 8192
				
				fh:close()
				local test = NoteLoader.NoteLoader(output)
				
				if test then
					test:ReleaseBeatmapAudio()
					test:Release()
					assert(os.rename(BeatmapSelect.SaveDir..output, BeatmapSelect.SaveDir.."beatmap/"..AquaShine.Basename(v:getFilename())))
					hasInstalled = true
				end
				
				love.filesystem.remove(output)
			else
				AquaShine.Log("BeatmapSelect", "Cannot open file %s: %s", output, h)
			end
			
			f:close()
		else
			AquaShine.Log("BeatmapSelect", "Cannot open file %s: %s", v, h)
		end
	end
	
	if hasInstalled then
		AquaShine.LoadEntryPoint(":beatmap_select", BeatmapSelect.TempArg)
	end
end

function BeatmapSelect.MovePage(inc)
	BeatmapSelect.Page = BeatmapSelect.Page + inc
	local idx = (BeatmapSelect.Page) % #BeatmapSelect.NodeList
	BeatmapSelect.Page = (idx == idx and idx or 0)
	BeatmapSelect.MainNode.brother = BeatmapSelect.NodeList[BeatmapSelect.Page + 1]
	BeatmapSelect.PageNumber:setText(string.format("Page %d/%d", BeatmapSelect.Page + 1, #BeatmapSelect.NodeList))
end

function BeatmapSelect.Update(deltaT)
end

function BeatmapSelect.Draw()
	return BeatmapSelect.MainNode:draw()
end

function BeatmapSelect.MousePressed(x, y, b, t)
	if not(BeatmapSelect.SwipeData[1]) then
		BeatmapSelect.SwipeData[1] = t or 0
		BeatmapSelect.SwipeData[2] = x
	end
	
	return BeatmapSelect.MainNode:triggerEvent("MousePressed", x, y, b, t)
end

function BeatmapSelect.MouseMoved(x, y, dx, dy, t)
	BeatmapSelect.MainNode:triggerEvent("MouseMoved", x, y, dx, dy, t)
	
	if BeatmapSelect.SwipeData[1] and math.abs(BeatmapSelect.SwipeData[2] - x) >= BeatmapSelect.SwipeThreshold then
		BeatmapSelect.MainNode:triggerEvent("MouseMoved", -200, -200, -1, -1, t)
		BeatmapSelect.MainNode:triggerEvent("MouseReleased", -200, -200, 1, t)
	end
end

function BeatmapSelect.MouseReleased(x, y, b, t)
	if BeatmapSelect.SwipeData[1] then
		if math.abs(BeatmapSelect.SwipeData[2] - x) >= BeatmapSelect.SwipeThreshold then
			-- Switch page
			local is_left = BeatmapSelect.SwipeData[2] - x < 0
			BeatmapSelect.MovePage(BeatmapSelect.SwipeData[2] - x < 0 and -1 or 1)
			BeatmapSelect.SwipeData[2] = nil
		else
			BeatmapSelect.MainNode:triggerEvent("MouseReleased", x, y, b, t)
		end
		
		BeatmapSelect.SwipeData[1] = nil
	end
end

return BeatmapSelect
