AquaShine
=========
AquaShine is the base layer which powers Live Simulator: 2. It contains useful
utilities functions meant to be used for Live Simulator: 2. Because AquaShine
is specially written for Live Simulator: 2, is not distributed as standalone
LOVE2D library.

However, you can simply take the `AquaShine.lua` and use it in your another
game. I don't mind about it. Please note that AquaShine itself depends on
Shelsha library. Well, of course you can edit the AquaShine code to not load
Playground texture banks, thus removing dependency to Shelsha library.

Origin of the Name
==================
So, where AquaShine name came from? Well, the name came from cosplay group in
Bali, Indonesia. **Opinion Starts** I think the name itself has a deep meaning,
like keep going and don't give up, or something like that **Opinion Ends**.

[We've got permission from AquaShine cosplay group to use it's name for this library name](https://www.facebook.com/AquaShineBali/posts/1049366371860966)

Features
========

* Letterboxing. This means that screen size doesn't matter. Just make your code
think the resolution is constant (like 800x600, 1366x768, etc.)

* Image & texture bank caching. Load images faster, with cost of memory needed.

* Scissor, which takes letterboxing into account

* Page switching, ZIP mounting management

* Configuration management (and command-line switches)

Architecture
============
AquaShine allows a separate update, draw, and input callbacks in a separate Lua
script which is called entry point. Instead of overwriting `love.update`,
`love.draw`, and the others when switching entry pouint, AquaShine simply
stores the current entry point and call it's appropriate functions.

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

function MySection.Exit()
	-- Cleanup here
end

return MySection, "Window title name"
```

Please see `conf.lua` for example how to initialize AquaShine.
