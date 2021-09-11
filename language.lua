-- Language manager
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local i18n = require("libs.i18n")
local JSON = require("libs.JSON")

local log = require("logging")
local Setting = require("setting")
local Language = {list = {}}

function Language.init()
	local langList = {}

	for _, file in ipairs(love.filesystem.getDirectoryItems("assets/i18n")) do
		if file:sub(-5) == ".json" then
			local s, data = pcall(JSON.decode, JSON, love.filesystem.read("assets/i18n/"..file))
			if not(s) then
				log.errorf("language", "cannot load language %s: %s", file, data:sub(1, 100))
			else
				data.filename = file
				Language.list[#Language.list + 1] = data
				langList[data.code] = data.strings
			end
		end
	end

	assert(langList.en, "english localization not found!") -- mandatory
	-- push English to the first one
	for i = 1, #Language.list do
		if Language.list[i].code == "en" then
			table.insert(Language.list, 1, table.remove(Language.list, i))
		end
	end
	i18n.load(langList)
end

function Language.enum()
	local list = {}
	for i = 1, #Language.list do
		local x = Language.list[i]
		list[#list + 1] = {
			name = x.name,
			code = x.code
		}
	end

	return list
end

function Language.set(code)
	Setting.set("LANGUAGE", code)
	return i18n.setLocale(code)
end

function Language.get()
	return i18n.getLocale()
end

function Language.getString(name, params)
	local v = i18n(name, params)
	if not(v) then
		v = "missing "..name
	end
	return v
end

setmetatable(Language, {
	__call = function(_, name, params)
		return Language.getString(name, params)
	end
})

return Language
