-- Wrapper to start DEPLS in mobile devices

local loader = {
	livesim = {1, "livesim.lua"},
	settings = {0, "setting_view.lua"},
	main_menu = {0, "main_menu.lua"},
	beatmap_select = {0, "select_beatmap.lua"},
	unit_editor = {0, "unit_editor.lua"}
}

function love.load(argv)
	local os_type = love.system.getOS()
	
	print("R/W Directory: "..love.filesystem.getSaveDirectory())
	
	if os_type == "Android" then
		-- Since we can't pass arguments to Android intent, we have to use txt
		local x = love.filesystem.newFile("command_line.txt", "r")
		
		if x then
			for line in x:lines() do
				line = line:gsub("[\r|\n]", "")
				
				table.insert(argv, line)
			end
		end
	elseif os_type == "iOS" then
		error("iOS is not supported!")
	end
	
	if love.filesystem.isFused() == false then
		table.remove(argv, 1)
	end
	
	local progname = argv[1]
	
	if loader[progname] then
		if #argv - 1 >= loader[progname][1] then
			local scriptfile = love.filesystem.load(loader[progname][2])
			scriptfile().Start(argv)
		end
	end
end

function love.update(deltaT)
end

function love.draw()
	love.graphics.print([[

Usage: love livesim <module = main_menu> <module options>
Module options:
 - livesim: <beatmap name>
 - setting: none
 - main_menu: none
 - beatmap_select: <default selected beatmap name>
 - unit_editor: none
]], 10)
end
