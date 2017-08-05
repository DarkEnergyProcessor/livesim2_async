-- Common data for beatmap selection screen
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine = ...
local love = love
local BSCommon = {
	BeatmapTypeFont = AquaShine.LoadFont("MTLmr3m.ttf", 11),
	SongNameFont = AquaShine.LoadFont("MTLmr3m.ttf", 22),
	Page = 1,
	SwipeData = {nil, nil},	-- Touch handle (or 0 for mouse click), x1
	SwipeThreshold = 75,
	CompositionList = {}
}

BSCommon.PageCompositionTable = {
	x = 64, y = 560, text = "Page 1",
	font = BSCommon.SongNameFont,
	draw = function(this)
		love.graphics.setFont(this.font)
		love.graphics.setColor(0, 0, 0)
		love.graphics.print(this.text, 1, 1)
		love.graphics.print(this.text, -1, -1)
		love.graphics.setColor(255, 255, 255)
		love.graphics.print(this.text)
	end
}

BSCommon.AutoplayTick = {
	x = 440, y = 520,
	w = 24, h = 24,
	tick = AquaShine.LoadImage("assets/image/ui/com_etc_293.png"),
	default = AquaShine.LoadImage("assets/image/ui/com_etc_292.png"),
	is_ticked = AquaShine.LoadConfig("AUTOPLAY", 0) == 1,
	draw = function(this)
		love.graphics.setColor(255, 255, 255)
		love.graphics.draw(this.default)
		
		if this.is_ticked then
			love.graphics.draw(this.tick, -2, 0)
		end
		
		love.graphics.setColor(0, 0, 0)
		love.graphics.setFont(BSCommon.SongNameFont)
		love.graphics.print("Autoplay", 33, 2)
	end,
	click = function(this)
		this.is_ticked = not(this.is_ticked)
		AquaShine.SaveConfig("AUTOPLAY", this.is_ticked and "1" or "0")
	end
}

BSCommon.RandomTick = {
	x = 440, y = 556,
	w = 24, h = 24,
	tick = AquaShine.LoadImage("assets/image/ui/com_etc_293.png"),
	default = AquaShine.LoadImage("assets/image/ui/com_etc_292.png"),
	is_ticked = false,
	draw = function(this)
		love.graphics.setColor(255, 255, 255)
		love.graphics.draw(this.default)
		
		if this.is_ticked then
			love.graphics.draw(this.tick, -2, 0)
		end
		
		love.graphics.setColor(0, 0, 0)
		love.graphics.setFont(BSCommon.SongNameFont)
		love.graphics.print("Random", 33, 2)
	end,
	click = function(this)
		this.is_ticked = not(this.is_ticked)
	end
}

function BSCommon.Update(deltaT)
end

function BSCommon.Draw()
	BSCommon.MainUIComposition:Draw()
	
	if #BSCommon.CompositionList > 0 then
		BSCommon.CompositionList[BSCommon.Page]:Draw()
	end
end

function BSCommon.MousePressed(x, y, k, tid)
	if not(BSCommon.SwipeData[1]) then
		BSCommon.SwipeData[1] = tid or 0
		BSCommon.SwipeData[2] = x
	end
	
	BSCommon.MainUIComposition:MousePressed(x, y)
	BSCommon.CompositionList[BSCommon.Page]:MousePressed(x, y)
end

function BSCommon.MouseMoved(x, y)
	BSCommon.MainUIComposition:MouseMoved(x, y)
	
	if BSCommon.SwipeData[1] and math.abs(BSCommon.SwipeData[2] - x) >= BSCommon.SwipeThreshold then
		BSCommon.CompositionList[BSCommon.Page]:MouseMoved(-100, -100)	-- Guaranteed to abort it
	end
end

function BSCommon.MouseReleased(x, y, k, tid)
	BSCommon.MainUIComposition:MouseReleased(x, y)
	BSCommon.CompositionList[BSCommon.Page]:MouseReleased(x, y)
	
	if BSCommon.SwipeData[1] then
		if math.abs(BSCommon.SwipeData[2] - x) >= BSCommon.SwipeThreshold then
			-- Switch page
			local is_left = BSCommon.SwipeData[2] - x < 0
			
			BSCommon.Page = ((BSCommon.Page + (is_left and -2 or 0)) % #BSCommon.CompositionList) + 1
			BSCommon.SwipeData[2] = nil
			BSCommon.PageCompositionTable.text = "Page "..BSCommon.Page.."/"..#BSCommon.CompositionList
		end
		
		BSCommon.SwipeData[1] = nil
	end
end

function BSCommon.KeyReleased(key)
	if key == "escape" then
		AquaShine.LoadEntryPoint(":main_menu")
	end
end

function BSCommon._Button50ScaleTemplate(x, y, text, action)
	local select = AquaShine.LoadImage("assets/image/ui/s_button_03.png")
	local select_se = AquaShine.LoadImage("assets/image/ui/s_button_03se.png")
	local font = AquaShine.LoadFont("MTLmr3m.ttf", 18)
	return {
		x = x, y = y, w = 216, h = 40,
		_drawtext = function(this)
			love.graphics.setFont(font)
			love.graphics.print(text, 8, 6)
		end,
		draw = function(this)
			love.graphics.setColor(255, 255, 255)
			love.graphics.draw(select, 0, 0, 0, 0.5)
			return this:_drawtext()
		end,
		draw_se = function(this)
			love.graphics.setColor(255, 255, 255)
			love.graphics.draw(select_se, 0, 0, 0, 0.5)
			return this:_drawtext()
		end,
		click = action
	}
end

return BSCommon