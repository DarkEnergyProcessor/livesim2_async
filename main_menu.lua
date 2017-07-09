-- Main Menu using AquaShine composition
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine = ...

local menu_select = {
	-- Name, Func
	{"Play", function() AquaShine.LoadEntryPoint("beatmap_select.lua") end},
	{"Change Units", function() AquaShine.LoadEntryPoint("unit_editor.lua") end},
	{"Settings", function() AquaShine.LoadEntryPoint("setting_view.lua") end}
}

-- We're not allowed to explicitly exit in iOS
if AquaShine.OperatingSystem ~= "iOS" then
	menu_select[4] = {"Exit", love.event.quit}
end

local selection_image, selection_image_se, TitleIcon
local background
local MTLMr3m, TitleFont, ReleaseFont
local versionText = AquaShine.GetCachedData("versionText", function()
	local bld = {}
	bld[#bld + 1] = "Live Simulator: 2 v"
	bld[#bld + 1] = DEPLS_VERSION
	bld[#bld + 1] = " ("
	bld[#bld + 1] = string.format("%08d", DEPLS_VERSION_NUMBER)
	bld[#bld + 1] = ") ("
	bld[#bld + 1] = jit and jit.version or _VERSION
	bld[#bld + 1] = ") "
	
	if AquaShine.FileSelection then
		bld[#bld + 1] = "FileSelection "
	end
	
	if AquaShine.FFmpegExt then
		bld[#bld + 1] = "FFmpegExt"
	end
	
	bld[#bld + 1] = "\nUses AquaShine loader & LOVE2D game framework\nR/W Directory: "
	bld[#bld + 1] = love.filesystem.getSaveDirectory()
	
	return table.concat(bld)
end)

local composition = AquaShine.Composition.Create({
	{
		-- background
		draw = function()
			love.graphics.setColor(255, 255, 255)
			love.graphics.draw(background[1])
			love.graphics.draw(background[2], -88, 0)
			love.graphics.draw(background[3], 960, 0)
			love.graphics.draw(background[4], 0, -43)
			love.graphics.draw(background[5], 0, 640)
		end
	},
	{
		-- Live Simulator: 2 title
		x = 140, y = 46,
		draw = function()
			love.graphics.draw(TitleIcon)
			love.graphics.setFont(TitleFont)
			love.graphics.setColor(0, 0, 0, 127)
			love.graphics.print("Live Simulator: 2", 142, 34)
			love.graphics.print("Live Simulator: 2", 139, 31)
			love.graphics.setColor(255, 255, 255)
			love.graphics.print("Live Simulator: 2", 140, 32)
		end
	},
	{
		-- Version text
		x = 0, y = 589,
		w = 332, h = 35,
		draw = function()
			love.graphics.setFont(ReleaseFont)
			love.graphics.setColor(0, 0, 0)
			love.graphics.print(versionText, 3, 2)
			love.graphics.setColor(255, 255, 255)
			love.graphics.print(versionText, 2, 1)
		end,
		click = function()
			AquaShine.LoadEntryPoint("about_screen.lua")
		end,
	}
})

for i = 1, #menu_select do
	local a = menu_select[i]
	
	composition:Add({
		x = 16, y = 120 + i * 80,
		w = 432, h = 80,
		draw = function()
			love.graphics.setFont(MTLMr3m)
			love.graphics.setColor(255, 255, 255)
			love.graphics.draw(selection_image)
			love.graphics.print(menu_select[i][1], 32, 16)
		end,
		draw_se = function()
			love.graphics.setFont(MTLMr3m)
			love.graphics.setColor(255, 255, 255)
			love.graphics.draw(selection_image_se)
			love.graphics.print(menu_select[i][1], 32, 16)
		end,
		click = menu_select[i][2]
	})
end

return composition:Wrap(function()
	selection_image = AquaShine.LoadImage("assets/image/ui/s_button_03.png")
	selection_image_se = AquaShine.LoadImage("assets/image/ui/s_button_03se.png")
	background = {AquaShine.LoadImage(
		"assets/image/background/liveback_14.png",
		"assets/image/background/b_liveback_014_01.png",
		"assets/image/background/b_liveback_014_02.png",
		"assets/image/background/b_liveback_014_03.png",
		"assets/image/background/b_liveback_014_04.png"
	)}
	TitleIcon = AquaShine.LoadImage("assets/image/icon/icon_128x128.png")

	MTLMr3m = AquaShine.LoadFont("MTLmr3m.ttf", 30)
	TitleFont = AquaShine.LoadFont("MTLmr3m.ttf", 72)
	ReleaseFont = AquaShine.LoadFont("MTLmr3m.ttf", 16)
end, {
	KeyReleased = function(key, scancode)
		if key == "escape" then
			love.event.quit()
		end
	end
})
