Special Command-Line Features
=============================

Live Simulator: 2 contains some special, useful feature which can be used when invoked from command-line (Terminal/Command Prompt). This feature were unavailable under mobile devices.

Command-line of Live Simulator: 2, which is handled entirely by AquaShine, are:

	love <livesim2 folder> <entry point=main_menu> [entry point arguments] [optional command-line options]

Note: `love <livesim2 folder>` can be replaced to `livesim2` for fused executable (Windows only)

Entry Point
-----------

This is actually part of AquaShine feature, which is entry-point based. Here are lists of `<entry point>` defined in Live Simulator: 2

### livesim

This entry point will play the beatmap name specificed in `[entry point arguments]`. Throws error if beatmap not found.

### main_menu

Live Simulator: 2 main menu. This is the default entry point if none specificed in command-line or if the entry point is rejected (not enough arguments, invalid entry point, ...)

### settings

Shows the settings page. Equivalent of clicking "Settings" in main menu.

### beatmap_select

Shows the beatmap selection screen. Equivalent of clicking "Play" in main menu.

### unit_editor

Shows the default unit formation image. Equivalent of clicking "Change Units" in main menu.

### about

Shows the program license, external libraries, and more. It's more like "Credits" screen. Hover your mouse to "License" text to see license for particular component. (Note that **AquaShine** and **NoteLoader** were not listed, because it's a specially written for Live Simulator: 2)

### render

Render the autoplay of the Live Simulator: 2 to image sequence (including audio).

This is one of most useful features in Live Simulator: 2 because it allows you to create video of your custom beatmap without frame drop/stutter. If your PC can't handle recording & autoplaying beatmap at the same time (i.e.: frame drops/stutters), use this feature.

Arguments (in order):

1. Folder destination, where to store the image sequence and the audio file. **The folder must exists**

2. Duration, how long the autoplaying should be recorded (in seconds). **Please take cover art duration into account**

3. Beatmap name, beatmap to autoplay and render.

Please note that this feature is very slow. It will eat all of your CPU cores (100%) and requires minimal of 512MB free RAM. However if video quality is priority, then this feature shouldn't be a problem.

**NEVER MINIMIZE THE WINDOW WHILE STILL RENDERING. IT WILL CAUSE BLACK IMAGE SEQUENCE AND ENCODING ERROR LATER**

After rendering is finished, the folder specificed as first argument will be filled with these files:

* 0000000001.png

* 0000000002.png

* _nnnnnnnnnn_.png

* audio.wav

To create video from the image sequence (encode as H.264 video, AAC audio, MP4 container):

	ffmpeg -framerate 60 -thread_queue_size 512 -i %010d.png -i audio.wav -c:v libx264 -pix_fmt yuv420p -c:a aac -b:a 320k video.mp4

Note: `-framerate 60` is necessary so the resulting video is 60FPS  
Note2: Although you see some debug information while in rendering mode, it won't appear in the final image sequence.
Note3: Render mode always disable minimal effect settings and runs even when the window is out of focus.

Limitation: You only able to create image sequence in fixed, 60 FPS. No other framerates are supported.  
Limitation2: Audio with sample rate higher than 44.1KHz is not supported.

### noteloader

Invokes Live Simulator: 2 note loader, internal component which responsibility to load beatmaps, then dump the SIF-compilant beatmap to `stdout`. This is actually a beatmap converter and might come handy in the future.

Arguments: Beatmap name, beatmap to convert it's notes data to SIF-compilant beatmap.

Command-Line Switches
---------------------

Command-line switches can be placed anywhere after `love livesim` (or `livesim2`).

* `/width=<w>` and `/height=<h>` sets the window width and height to specificed size

* `/fullscreen` runs Live Simulator: 2 in fullscreen

* `/norg` disable volume normalizing

* `/forcerg` forces volume normalizing even if LuaJIT is not used. Volume normalizing is disabled by default when running under Lua 5.1 \*

* `/benchmark` only tests the performance of the render mode (does not write any file)

* `/random` equivalent of always ticking the *Random* options in beatmap selection screen \*

* `/notestyle=<1|2>` overrides note style setting (storyboard, setting). 1 for old note style, 2 for SIF-v5 note style

* `/interpreter` forces LuaJIT to interpret bytecode instead of compiling it to machine code. Decreases frame stutter in some cases. Does nothing when using Lua 5.1

* `/tga` makes the render mode image sequence to output Targa image instead of PNG image

* `/fxaa` enables Fast Approximate Anti-Aliasing (render mode only)

\* - For debugging purpose.
