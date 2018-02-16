-- Main Menu using AquaShine Node
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine = ...
local BackgroundImageUI = AquaShine.LoadModule("uielement/background_image")
local MainMenu = {}

MainMenu.MenuSelect = {
	-- Name, Func
	{"Play", function() AquaShine.LoadEntryPoint(":beatmap_select") end},
	{"Change Units", function() AquaShine.LoadEntryPoint(":unit_editor") end},
	{"Settings", function() AquaShine.LoadEntryPoint(":settings") end},
	{"Exit", function() AquaShine.LoadEntryPoint("iosdummy") end}
}

function MainMenu.ConstructVersionText()
	local bld = {}
	
	bld[#bld + 1] = "Live Simulator: 2 v"
	bld[#bld + 1] = DEPLS_VERSION
	bld[#bld + 1] = " ("
	bld[#bld + 1] = string.format("%08d", DEPLS_VERSION_NUMBER)
	bld[#bld + 1] = ") ("
	bld[#bld + 1] = jit and jit.version or _VERSION
	bld[#bld + 1] = ") "
	
	if os.getenv("LLA_IS_SET") then
		-- From modified Openal-Soft
		bld[#bld + 1] = "LLA:"
		bld[#bld + 1] = os.getenv("LLA_BUFSIZE")
		bld[#bld + 1] = "smp/"
		bld[#bld + 1] = os.getenv("LLA_FREQUENCY")
		bld[#bld + 1] = "Hz "
	end
	
	if AquaShine.FileSelection then
		bld[#bld + 1] = "fselect "
	end
	
	if AquaShine.FFmpegExt then
		bld[#bld + 1] = "FFX "
	end
	
	if AquaShine.Download.HasHTTPS() then
		bld[#bld + 1] = "HTTPS "
	end
	
	bld[#bld + 1] = "\nRenderer: "
	bld[#bld + 1] = AquaShine.RendererInfo[1]
	
	for i = 2, 4 do
		if AquaShine.RendererInfo[i] then
			bld[#bld + 1] = " "
			bld[#bld + 1] = AquaShine.RendererInfo[i]
		end
	end
	
	bld[#bld + 1] = "\nR/W Directory: "
	bld[#bld + 1] = love.filesystem.getSaveDirectory()
	
	return table.concat(bld)
end

function MainMenu.Start(arg)
	local MainMenuButton = AquaShine.LoadModule("uielement.button_main_menu")
	local TextShadow = AquaShine.LoadModule("uielement.text_with_shadow")
	
	-- Remove "Exit" for iOS
	if AquaShine.OperatingSystem ~= "iOS" then MainMenu.MenuSelect[4][2] = love.event.quit end
	
	MainMenu.VersionText = AquaShine.GetCachedData("versionText", MainMenu.ConstructVersionText)
	MainMenu.Background = BackgroundImageUI(14)
	AquaShine.Node.Util.SingleTouchOnly(MainMenu.Background)
	
	-- Version text
	MainMenu.VersionTextNode = TextShadow(AquaShine.LoadFont("MTLmr3m.ttf", 16), MainMenu.VersionText)
	MainMenu.VersionTextNode:setPosition(2, 592)
	MainMenu.VersionTextNode:setShadow(1.25, 1)
	AquaShine.Node.Util.InitializeInArea(MainMenu.VersionTextNode, 480, 48)
	MainMenu.VersionTextNode:setEventHandler("MouseReleased", AquaShine.Node.Util.InAreaFunction(MainMenu.VersionTextNode, function()
		return AquaShine.LoadEntryPoint(":about")
	end))
	MainMenu.Background:addChild(MainMenu.VersionTextNode)
	
	-- Live Simulator: 2 image
	MainMenu.LiveSimulator2Icon = AquaShine.Node.Image(AquaShine.LoadImage("assets/image/icon/icon_128x128.png"))
	MainMenu.LiveSimulator2Icon:setPosition(140, 46)
	MainMenu.Background:addChild(MainMenu.LiveSimulator2Icon)
	
	-- Live Simulator: 2 text
	AquaShine.LoadFont("MTLmr3m.ttf", 72)
	MainMenu.LiveSimulator2Text = TextShadow(AquaShine.LoadFont("MTLmr3m.ttf", 72), "Live Simulator: 2")
	MainMenu.LiveSimulator2Text:setPosition(280, 78)
	MainMenu.LiveSimulator2Text:setShadow(2, 0.5, true)
	MainMenu.Background:addChild(MainMenu.LiveSimulator2Text)
	
	-- Selection
	for i = 1, #MainMenu.MenuSelect do
		local sel = MainMenu.MenuSelect[i]
		local node = MainMenuButton(sel[1], sel[2])
		
		node:setPosition(16, 120 + i * 80)
		MainMenu.Background:addChild(node)
	end
end

function MainMenu.Update(deltaT)
	return MainMenu.Background:update(deltaT)
end

function MainMenu.Draw()
	return MainMenu.Background:draw()
end

function MainMenu.MousePressed(x, y, b, t)
	return MainMenu.Background:triggerEvent("MousePressed", x, y, b, t)
end

function MainMenu.MouseMoved(x, y, dx, dy, t)
	return MainMenu.Background:triggerEvent("MouseMoved", x, y, dx, dy, t)
end

function MainMenu.MouseReleased(x, y, b, t)
	return MainMenu.Background:triggerEvent("MouseReleased", x, y, b, t)
end

MainMenu.Buttons = {"Yes", "No"}
function MainMenu.KeyReleased(key)
	if key == "escape" and love.window.showMessageBox("Quit", "Quit Live Simulator: 2?", MainMenu.Buttons, "warning") == 1 then
		love.event.quit()
	end
end

return MainMenu
