-- Game state system
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local Luaoop = require("libs.Luaoop")
local lily = require("libs.lily")
local async = require("async")
local cache = require("cache")
local gamestate = {
	list = {}, -- list of registered gamestate
	cachedInstance = setmetatable({}, {__mode = "kv"}),
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
local gamestateConstructorObject = Luaoop.class("gamestate.Constructor")
local gamestateObject = Luaoop.class("gamestate.Gamestate")

function gamestateConstructorObject:__construct(info)
	assert(info.fonts, "missing fonts table")
	assert(info.images, "missing images table")
	assert(info.audios, "missing audios table")
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
	local internal = gamestateObject^self
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
			return (gamestateObject^self).constructor[name](self, ...)
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

-------------------------------------
-- Internal function is procedural --
-------------------------------------

function gamestate.internal.makeWeak(game)
	local state = gamestateObject^game
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

function gamestate.internal.makeStrong(game)
	local state = gamestateObject^game
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

	local object = cache.get(cacheName)
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
	local internal = gamestateObject^game

	game.assets[assetType][assetUdata[index][2]] = value
	internal.assets[assetType][assetUdata[index][2]] = value
	cache.set(assetUdata[index][3], value)
end

-- Called in async.runFunction
function gamestate.internal.initialize(game, arg)
	async.wait()
	gamestate.internal.loadAssets(game)
	game:load(arg)
end

function gamestate.internal.loadAssets(game)
	local state = gamestateObject^game
	local loadedAssetList = {}
	local assetUdata = {}
	-- Get fonts
	for k, v in pairs(state.constructor.info.fonts or {}) do
		if not(game.assets.fonts[k]) then
			local s, cname, aname = getCacheByValue(v)
			if s then
				game.assets.fonts[k] = cname
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
			else
				loadedAssetList[#loadedAssetList + 1] = {lily.newImage, aname, v[2]}
				assetUdata[#assetUdata + 1] = {"images", k, cname}
			end
		end
	end
	-- Get audios
	for k, v in pairs(state.constructor.info.audios or {}) do
		if not(game.assets.images[k]) then
			local s, cname, aname = getCacheByValue(v)
			if s then
				game.assets.images[k] = cname
			else
				loadedAssetList[#loadedAssetList + 1] = {lily.newSource, aname, v[2]}
				assetUdata[#assetUdata + 1] = {"audios", k, cname}
			end
		end
	end

	-- Multilily
	local multi = lily.loadMulti(loadedAssetList)
		:setUserData({asset = assetUdata, game = game})
		:onLoaded(gamestateHandleMultiLily)
	-- Wait
	while multi:isComplete() == false do
		async.wait()
	end
end

function gamestate.internal.initPreparation(name, game, arg, mode)
	local t = {
		name = name,
		game = game,
		arg = arg,
		coro = coroutine.create(gamestate.internal.initialize),
		mode = mode,
	}
	coroutine.resume(t.coro, game, arg)
	return t
end

function gamestate.internal.loop()
	local prep = gamestate.preparedGamestate
	local current = nil
	if gamestate.loadingState and not(gamestate.loadingStateResumed) then
		gamestate.loadingStateResumed = true
		gamestate.loadingState:resumed()
	end
	if gamestate.preparedGamestate then
		local coro = gamestate.preparedGamestate.coro
		if coroutine.status(coro) == "dead" then
			-- Assume it's already done, but it may be dead because lua error
			if prep.mode == "replace" then
				current = gamestate.stack[#gamestate.stack]
				gamestate.stack[#gamestate.stack] = {
					name = gamestate.preparedGamestate.name,
					game = gamestate.preparedGamestate.game
				}
			elseif prep.mode == "leave" then
				current = table.remove(gamestate.stack, #gamestate.stack)
			elseif prep.mode == "enter" then
				current = gamestate.stack[#gamestate.stack]
				gamestate.stack[#gamestate.stack + 1] = {
					name = gamestate.preparedGamestate.name,
					game = gamestate.preparedGamestate.game
				}
			end

			gamestate.preparedGamestate = nil
			gamestate.loadingState = nil

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

				gamestate.internal.makeWeak(current.game)
			else
				prep.game:start(prep.arg)
			end

			if gamestate.loadingState and gamestate.loadingStateResumed then
				gamestate.loadingStateResumed = false
				gamestate.loadingState:paused()
				gamestate.loadingState = nil
			end
		end
	end
end

function gamestate.internal.handleEvents(name, ...)
	local current = gamestate.stack[#gamestate.stack]
	if not(current) then return false end

	local constructor = (gamestateObject^current.game).constructor
	if constructor.events[name] then
		constructor.events[name](current.game, select(1, ...))
		return true
	end
	return false
end

function gamestate.internal.getActive()
	if gamestate.preparedGamestate and gamestate.loadingState then
		return gamestate.loadingState
	end

	local game = gamestate.stack[#gamestate.stack]
	if game then
		return game.game
	end

	return nil
end

function gamestate.internal.quit()
	for i = #gamestate.stack, 1, -1 do
		local game = gamestate.stack[i]
		gamestate.stack[i] = nil
		game.game:exit()
	end
end

----------------------
-- Public functions --
----------------------

function gamestate.create(info)
	return gamestateConstructorObject(info)
end

function gamestate.newLoadingScreen(info)
	local game = info:new()
	gamestate.internal.makeStrong(game)
	game:start()
	return game
end

function gamestate.register(name, obj)
	if gamestate.list[name] then
		error("gamestate with name '"..name.."' already exist", 2)
	end
	gamestate.list[name] = obj
end

function gamestate.enter(loading, name, arg)
	local game = assert(gamestate.list[name], "invalid gamestate name"):new()
	gamestate.internal.makeStrong(game)
	gamestate.preparedGamestate = gamestate.internal.initPreparation(name, game, arg, "enter")
	gamestate.loadingState = loading
	gamestate.loadingStateResumed = false
end

function gamestate.leave(loading)
	-- If it's the last game state, just send love.event.quit
	if #gamestate.stack == 1 then
		love.event.quit()
		return
	end

	local game = gamestate.stack[#gamestate.stack - 1]
	gamestate.internal.makeStrong(game.game)
	gamestate.preparedGamestate = gamestate.internal.initPreparation(game.name, game.game, nil, "leave")
	gamestate.loadingState = loading
	gamestate.loadingStateResumed = false
end

function gamestate.replace(loading, name, arg)
	local game = assert(gamestate.list[name], "invalid gamestate name"):new()
	gamestate.internal.makeStrong(game)
	gamestate.preparedGamestate = gamestate.internal.initPreparation(name, game, arg, "replace")
	gamestate.loadingState = loading
	gamestate.loadingStateResumed = false
end

return gamestate
