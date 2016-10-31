-- DEPLS Note Loader function
local List = require("List")
local JSON = require("JSON")

-- Usage: push from right, pop from left
return function(path)
	local notes_data = JSON:decode(file_get_contents(path))
	local notes_list = List.new()
	
	for i = 1, #notes_data do
		notes_list:pushright(notes_data[i])
	end
	
	return notes_list
end