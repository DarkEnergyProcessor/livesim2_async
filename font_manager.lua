-- DEPLS2 Font manager

local FontManager = {}
local FontList = {}

function FontManager.GetFont(name, size)
	if not(FontList[name]) then
		FontList[name] = {}
	end
	
	if not(FontList[name][size]) then
		local _, a = pcall(love.graphics.newFont, name, size)
		
		if _ then
			FontList[name][size] = a
		else
			return nil, a
		end
	end
	
	return FontList[name][size]
end

return FontManager
