-- Game state system
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")
local lily = require("lily")
local Async = require("async")
local Cache = require("cache")
local log = require("logging")
local Setting = require("setting")
local Gamestate = {
	list = {}, -- list of registered gamestate
	internal = {}, -- internal functions
	stack = {}, -- the active one is always gamestate.stack[#gamestate.stack]
	preparedGamestate = nil, -- gamestate which is prepared
	loadingState = nil, -- loading screen gamestate
	loadingStateResumed = false,
}
local weak = {__mode = "kv"}

---------------------
-- Gamestate class --
---------------------
local gamestateConstructorObject = Luaoop.class("Gamestate.Constructor")

---@generic T
---@class Gamestate.Gamestate
---@field public persist table
---@field public assets {images:table<string,love.Image>,fonts:table<string,love.Font>}
local gamestateObject = Luaoop.class("Gamestate.Gamestate")

---@param info Gamestate.ConstructorInfo
function gamestateConstructorObject:__construct(info)
	assert(info.fonts, "missing fonts table")
	assert(info.images, "missing images table")
	self.info = info
	self.events = {}
end

function gamestateConstructorObject:new()
	return gamestateObject(self)
end

function gamestateConstructorObject:registerEvent(name, func)
	self.events[name] = func
end

function gamestateConstructorObject.load() end
function gamestateConstructorObject.start() end
function gamestateConstructorObject.exit() end
function gamestateConstructorObject.paused() end
function gamestateConstructorObject.resumed() end
function gamestateConstructorObject.update() end
function gamestateConstructorObject.draw() end

function gamestateObject:__construct(constructor)
	local internal = Luaoop.class.data(self)
	internal.constructor = constructor
	internal.data = {}
	internal.assets = {fonts = {}, images = {}}
	internal.events = {}
	internal.weak = false
	self.data = setmetatable({}, {
		__mode = "kv",
		__newindex = function(d, var, val)
			rawset(d, var, val)
			if not(internal.weak) then
				rawset(internal.data, var, val)
			end
		end,
		__index = function(d, var)
			local val = rawget(d, var)
			if val == nil then
				val = rawget(internal.data, var)
			end
			return val
		end,
	})
	self.assets = {
		fonts = setmetatable({}, weak),
		images = setmetatable({}, weak)
	}
	self.persist = {}
end

do
	local function makeShortcutMacro(name)
		gamestateObject[name] = function(self, ...)
			return Luaoop.class.data(self).constructor[name](self, ...)
		end
	end
	makeShortcutMacro("load")
	makeShortcutMacro("start")
	makeShortcutMacro("exit")
	makeShortcutMacro("paused")
	makeShortcutMacro("resumed")
	makeShortcutMacro("update")
	makeShortcutMacro("draw")
end

if false then
	---@generic T: Gamestate.Gamestate
	---@param self T
	---@param name string
	---@param callback fun(self:T,...)
	function gamestateObject.registerEvent(self, name, callback)
	end
end

-------------------------------------
-- Internal function is procedural --
-------------------------------------

function Gamestate.internal.makeWeak(game)
	local state = Luaoop.class.data(game)
	-- Expensive. Use sparingly!
	for k in pairs(state.data) do
		state.data[k] = nil
	end
	for k in pairs(state.assets.fonts) do
		state.assets.fonts[k] = nil
	end
	for k in pairs(state.assets.images) do
		state.assets.images[k] = nil
	end
	state.weak = true
end

function Gamestate.internal.makeStrong(game)
	local state = Luaoop.class.data(game)
	-- Expensive. Use sparingly!
	for k, v in pairs(game.data) do
		state.data[k] = v
	end
	for k, v in pairs(game.assets.fonts) do
		state.assets.fonts[k] = v
	end
	for k, v in pairs(game.assets.images) do
		state.assets.images[k] = v
	end
	state.weak = false
end

local function getCacheByValue(v)
	local n = tostring(v[1])
	local s, e = n:find(":", 1, true)
	local assetName
	local cacheName
	if s then
		cacheName = n:sub(1, s-1)
		assetName = n:sub(e+1)
	else
		cacheName = v[1].."_"..tostring(v[2])
		assetName = v[1]
	end

	local object = Cache.get(cacheName)
	if object then
		return true, object
	else
		return false, cacheName, (tonumber(assetName) or assetName)
	end
end

local function gamestateHandleMultiLily(udata, index, value)
	local assetUdata = udata.asset
	local game = udata.game
	local assetType = assetUdata[index][1]
	local internal = Luaoop.class.data(game)

	log.debugf("gamestate", "asset loaded: %s", assetUdata[index][2])
	internal.assets[assetType][assetUdata[index][2]] = value
	game.assets[assetType][assetUdata[index][2]] = value
	Cache.set(assetUdata[index][3], value)
end

-- Called in async.runFunction
function Gamestate.internal.initialize(game, arg)
	Async.wait()
	Gamestate.internal.loadAssets(game)
	game:load(arg)
end

function Gamestate.internal.loadAssets(game)
	local state = Luaoop.class.data(game)
	local loadedAssetList = {}
	local assetUdata = {}
	-- Get fonts
	for k, v in pairs(state.constructor.info.fonts or {}) do
		if not(game.assets.fonts[k]) then
			local s, cname, aname = getCacheByValue(v)
			if s then
				game.assets.fonts[k] = cname
				state.assets.fonts[k] = cname
			else
				loadedAssetList[#loadedAssetList + 1] = {lily.newFont, aname, v[2]}
				assetUdata[#assetUdata + 1] = {"fonts", k, cname}
			end
		end
	end
	-- Get images
	for k, v in pairs(state.constructor.info.images or {}) do
		if not(game.assets.images[k]) then
			local s, cname, aname = getCacheByValue(v)
			if s then
				game.assets.images[k] = cname
				state.assets.images[k] = cname
			else
				loadedAssetList[#loadedAssetList + 1] = {lily.newImage, aname, v[2]}
				assetUdata[#assetUdata + 1] = {"images", k, cname}
			end
		end
	end

	if #loadedAssetList > 0 then
		-- Multilily
		local multi = lily.loadMulti(loadedAssetList)
			:setUserData({asset = assetUdata, game = game})
			:onLoaded(gamestateHandleMultiLily)
		-- Wait
		while multi:isComplete() == false do
			Async.wait()
		end
	end
end

function Gamestate.internal.initPreparation(name, game, arg, mode)
	local t = {
		name = name,
		game = game,
		arg = arg,
		coro = coroutine.create(Gamestate.internal.initialize),
		mode = mode,
	}
	coroutine.resume(t.coro, game, arg)
	return t
end

function Gamestate.internal.loop()
	local prep = Gamestate.preparedGamestate
	local current = nil
	if Gamestate.loadingState and not(Gamestate.loadingStateResumed) then
		Gamestate.loadingStateResumed = true
		Gamestate.loadingState:resumed()
	end
	if Gamestate.preparedGamestate then
		local coro = Gamestate.preparedGamestate.coro
		if coroutine.status(coro) == "dead" then
			-- Assume it's already done, but it may be dead because lua error
			if prep.mode == "replace" then
				current = Gamestate.stack[#Gamestate.stack]
				Gamestate.stack[#Gamestate.stack] = {
					name = Gamestate.preparedGamestate.name,
					game = Gamestate.preparedGamestate.game
				}
			elseif prep.mode == "leave" then
				current = table.remove(Gamestate.stack, #Gamestate.stack)
			elseif prep.mode == "enter" then
				current = Gamestate.stack[#Gamestate.stack]
				Gamestate.stack[#Gamestate.stack + 1] = {
					name = Gamestate.preparedGamestate.name,
					game = Gamestate.preparedGamestate.game
				}
			end

			Gamestate.preparedGamestate = nil
			Gamestate.loadingState = nil

			if current then
				if prep.mode == "enter" then
					current.game:paused()
				elseif prep.mode == "leave" or prep.mode == "replace" then
					current.game:exit()
				end

				if prep.mode == "enter" or prep.mode == "replace" then
					prep.game:start(prep.arg)
				elseif prep.mode == "leave" then
					prep.game:resumed()
				end

				Gamestate.internal.makeWeak(current.game)
			else
				prep.game:start(prep.arg)
			end

			if Gamestate.loadingState and Gamestate.loadingStateResumed then
				Gamestate.loadingStateResumed = false
				Gamestate.loadingState:paused()
				Gamestate.loadingState = nil
			end
		end
	end
end

function Gamestate.internal.handleEvents(name, ...)
	local current = Gamestate.stack[#Gamestate.stack]
	if not(current) then return false end

	local constructor = Luaoop.class.data(current.game).constructor
	if constructor.events[name] then
		constructor.events[name](current.game, select(1, ...))
		return true
	end
	return false
end

function Gamestate.internal.getActive()
	if Gamestate.preparedGamestate and Gamestate.loadingState then
		return Gamestate.loadingState
	end

	local game = Gamestate.stack[#Gamestate.stack]
	if game then
		return game.game
	end

	return nil
end

function Gamestate.internal.quit()
	for i = #Gamestate.stack, 1, -1 do
		local game = Gamestate.stack[i]
		Gamestate.stack[i] = nil
		local s, msg = pcall(game.game.exit, game.game)
		if s == false then
			log.errorf("gamestate", "cleanup stack #%d failed: %s", i, msg)
		end
	end
end

----------------------
-- Public functions --
----------------------

---@param info Gamestate.ConstructorInfo
---@return Gamestate.Gamestate
function Gamestate.create(info)
	return gamestateConstructorObject(info)
end

function Gamestate.newLoadingScreen(info)
	local game = info:new()
	Gamestate.internal.makeStrong(game)
	game:start()
	return game
end

function Gamestate.register(name, obj)
	if Gamestate.list[name] then
		error("gamestate with name '"..name.."' already exist", 2)
	end

	assert(Luaoop.class.is(obj, gamestateConstructorObject), "invalid gamestate object passed")
	Gamestate.list[name] = obj
end

function Gamestate.enter(loading, name, arg)
	if Gamestate.preparedGamestate then
		log.warn("gamestate", "attempt to enter new gamestate but one is in progress")
		return
	end

	local game = assert(Gamestate.list[name], "invalid gamestate name"):new()
	log.infof("gamestate", "entering gamestate: %s", name)
	Gamestate.internal.makeStrong(game)
	Gamestate.preparedGamestate = Gamestate.internal.initPreparation(name, game, arg, "enter")
	Gamestate.loadingState = loading
	Gamestate.loadingStateResumed = false
	Setting.update()
end

function Gamestate.leave(loading)
	-- If it's the last game state, just send love.event.quit
	if #Gamestate.stack == 1 then
		love.event.quit()
		return
	end

	if Gamestate.preparedGamestate then
		log.warn("gamestate", "attempt to enter leave gamestate but one is in progress")
		return
	end

	local game = Gamestate.stack[#Gamestate.stack - 1]
	log.infof("gamestate", "leaving gamestate")
	Gamestate.internal.makeStrong(game.game)
	Gamestate.preparedGamestate = Gamestate.internal.initPreparation(game.name, game.game, nil, "leave")
	Gamestate.loadingState = loading
	Gamestate.loadingStateResumed = false
	Setting.update()
end

function Gamestate.replace(loading, name, arg)
	if Gamestate.preparedGamestate then
		log.warn("gamestate", "attempt to enter new gamestate but one is in progress")
		return
	end

	local game = assert(Gamestate.list[name], "invalid gamestate name"):new()
	log.infof("gamestate", "replace current gamestate: %s", name)
	Gamestate.internal.makeStrong(game)
	Gamestate.preparedGamestate = Gamestate.internal.initPreparation(name, game, arg, "replace")
	Gamestate.loadingState = loading
	Gamestate.loadingStateResumed = false
	Setting.update()
end

return Gamestate
