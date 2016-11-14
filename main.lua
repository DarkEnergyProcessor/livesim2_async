-- Wrapper to start DEPLS in mobile devices

function love.load(argv)
	local os_type = love.system.getOS()
	
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
	
	love.filesystem.load("livesim.lua")()
	love.load(argv)
end
