Live Simulator: 2
=================

Live Simulator: 2 (`DEPLS2`) is a Love Live! School Idol Festival Live Show Simulator written in Lua.

It is currently LL!SIF live simulator that supports variety of different beatmap formats.

How to run
==========

Please see `docs/How_To_Setup.md`

Components
==========

Live Simulator: 2 uses these special components specially created for this project:

* AquaShine. Please see `docs/AquaShine.md` for more information about this component.

* NoteLoader, internal component responsible of loading beatmaps from variety of different formats. Depends on AquaShine

* LS2, Live Simulator: 2 binary beatmap parser and generator.

Live Simulator: 2 uses these external libraries to run:

* [Yohane Playground Flash Abstraction](https://github.com/MikuAuahDark/Yohane)

* [tween.lua](https://github.com/kikito/tween.lua)

* [JSON.lua](http://regex.info/blog/lua/json)

Live Simulator: 2 uses these external libraries if available:

* [FFmpeg 3.x](http://ffmpeg.org/) (libavcodec 57) (always available in Windows)

Controls
========

* A, S, D, F, Space, J, K, L, Semicolon = Tap notes

* Left Shift = Show debug information (FPS, Elapsed time, ...)

* Left Ctrl = Toggle Autoplay On/Off

* Left Alt = Show note distance

* F5 = Turn the song volume down by 5% (default is 80%)

* F6 = Turn the song volume up by 5%

* PageUp = Increase speed factor by 2x (max 400%)

* PageDown = Decrease speed factor by 2x (min 6.25%)

* Backspace = Restart live simulator

Supported Beatmaps
==================

* SIF beatmap, this is main beatmap format that Live Simulator: 2 uses.

* Sukufesu Simulator beatmap, yuyu live simulator beatmap.

* Custom Beatmap Festival project folder.

* MIDI, specialized MIDI file.

* LLPractice beatmap.

* SIFTrain beatmap, both original one and "extended" one were supported.

Disclaimer
==========

This live simulator also uses many assets from Love Live! School Idol Festival game (background, header, ...)

Special Thanks
==============

* [@yuyu0127_](https://twitter.com/yuyu0127_) - Note circle images.

License
=======

Live Simulator: 2 is licensed under MIT License. See `LICENSE.md` for more details.

Live Simulator: 2 uses Motoya L Maru font. Please see `LICENSE.MTLmr3m` for
Motoya L Maru font license.

Live Simulator: 2 uses Venera-700 font by Joe Prince and licensed under The Lost Type.

Live Simulator: 2 uses image asset from Love Live! School Idol Festival.

Live Simulator: 2 uses FFmpeg when available, and it's licensed under GNU GPLv3 (or GNU LGPL, depending on used binaries). Windows version ships with FFmpeg 3.0 which is licensed under GNU LGPLv3 or later

Please see respective files (or website) for license of those libraries.
