AquaShine
=========
AquaShine is the base layer which powers DEPLS2. It contains useful utilities
functions meant to be used for DEPLS2. Because AquaShine is written for DEPLS2,
is not distributed as standalone Lua script.

However, you can simply take the `AquaShine.lua` and use it in your another
game. I don't mind about it. Please note that AquaShine itself depends on
Shelsha library. Well, you can edit the AquaShine code to not load Playground
texture banks, thus removing dependency to Shelsha library.

Features
========

* Letterboxing. This means that screen size doesn't matter. Just make your code
think the resolution is constant (like 800x600, 1366x768, etc.)

* Image & texture bank caching. Load images faster, with cost of memory needed.

* Scissor, which takes letterboxing into account

Architecture
============
AquaShine allows a separate update, draw, and input callbacks in a separate lua
script. Instead of overwriting `love.update`, `love.draw`, and the others when
switching sections, AquaShine simply stores the current section and call it's
update, draw, and it's other callback functions. Let's call it entry point.

A typical entry point Lua script as follows

```lua
local AquaShine = AquaShine
local MySection = {}

function MySection.Start(arg)
	-- Initialization code
end

function MySection.Update(deltaT)
	-- Update code
end

function MySection.Draw(deltaT)
	-- Drawing code
end

return MySection
```

To specify lists of entry points to AquaShine, please see `main.lua`
