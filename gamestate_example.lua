-- Gamestate example
local gamestate = require("gamestate")
local async = require("async")
local DEPLS = gamestate.create {
	-- These shit will be loaded in parallel using Lily
	-- or it will be fetched from cache
	fonts = {
		main = {"fonts/MTLmr3m.ttf", 12},
	},
	images = {
		-- cachename:path
		-- only use cache name variant if the second argument is not number nor string
		-- or to share cache for other gamestates
		note = {"noteImage:assets/image/tap_circle/note.png", {mipmaps = true}},
		-- other asset shit here
	}
}

-- If new gamestate is entered, the previous game state will be paused (and calls pause method).
-- If loading screen is specified, the previous game state will just paused directly
-- and moved to loading screen. Otherwise, the game state will still run as usual
-- until the next game state is fully loaded.

-- Function called when state switch is initiated. Load additional assets here (can use async)
function DEPLS:load(arg)
	-- do load some shit with async functions and store it to self.data
	-- self.data must be used for heavy data objects
end

-- Function called when new state is entered
function DEPLS:start(arg)
	-- self.data contains weak table of loaded references (load heavy data here)
	-- self.persist contains persistent data (store game variables here)
	-- self.assets contains loaded assets as specified above
end

-- Function called when current state is exit (game state goes backward or game exit)
function DEPLS:exit()
end

-- Function called when previous state exit and current active state is resumed
function DEPLS:resumed()
end

-- Function called when it's time to go to new state (but not exit)
-- This allows the gamestate to go backward (and it will call resumed in that case)
function DEPLS:paused()
end

-- The order of call is event handlers, then "update" then "draw"
function DEPLS:update(dt)
end

-- The order of call is event handlers, then "update" then "draw"
function DEPLS:draw()
end

DEPLS:registerEvent("keypressed", function(key, scancode)
	-- handle shit
end)

DEPLS:registerEvent("touchpressed", function(id, x, y, dx, dy, pressure)
	-- handle shit
	-- ID is 0 if it comes from mouse keypress
end)

return DEPLS
