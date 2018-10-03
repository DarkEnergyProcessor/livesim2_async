-- Language manager
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local i18n = require("libs.i18n")
local JSON = require("libs.JSON")
local log = require("logging")
local language = {list = {}}

function language.init()
	local langList = {}

	for _, file in ipairs(love.filesystem.getDirectoryItems("assets/i18n")) do
		if file:sub(-5) == ".json" then
			local s, data = pcall(JSON.decode, JSON, love.filesystem.read("assets/i18n/"..file))
			if not(s) then
				log.errorf("language", "cannot load language %s: %s", file, data:sub(1, 100))
			else
				data.filename = file
				language.list[#language.list + 1] = data
				langList[data.code] = data.strings
			end
		end
	end

	assert(langList.en, "english localization not found!") -- mandatory
	-- push English to the first one
	for i = 1, #language.list do
		if language.list[i].code == "en" then
			table.insert(language.list, 1, table.remove(language.list, i))
		end
	end
	i18n.load(langList)
end

function language.enum()
	local list = {}
	for i = 1, #language.list do
		local x = language.list[i]
		list[#list + 1] = {
			name = x.name,
			code = x.code
		}
	end
end

function language.set(code)
	return i18n.setLocale(code)
end

function language.getString(name, params)
	local v = i18n(name, params)
	if not(v) then
		v = "missing "..name
	end
	return v
end

setmetatable(language, {
	__call = function(_, name, params)
		return language.getString(name, params)
	end
})

return language
