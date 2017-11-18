Lua Storyboard
==============

Lua storyboard is simply a Lua script which controls how objects shown behind the simulator,
hence it's named Lua storyboard. Please note that Lua script running as Lua storyboard is
sandboxed, which means most of `love` functions doesn't exist in here or modified to prevent
alteration of the rendering state, and to prevent malicious Lua script from running.

Storyboard Entry Points
=======================

Lua storyboard needs to create this function in global namespace. Although there's way to use
it without this entry points by using coroutines, but it's usage is discouraged and only
provided for legacy DEPLS storyboard Lua script.

*************************************************

### `void Initialize()`

Storyboard initialization. This function is called everytime storyboard is loaded. Load your
images here

*************************************************

### `void Update(number deltaT)`

Storyboard frame update. Draw and calculate everything for the storyboard in here.

Parameters:

* deltaT - The delta-time, in milliseconds

*************************************************

### `void Jump(number elapsed_time)`

Storyboard seek. This function is called when user resumes Live Show!

> This function is not available in current release.

> If this function is not implemented, the beatmap is assumed not to support resumeable live.

Parameters:

* elapsed_time - Last elapsed time when the live show state is saved

*************************************************

### `void Pause(bool pausing)`

Storyboard pause. This function is called when user pressed the pause button.

> This function is not available in current release.

> If this function is not implemented, the storyboard is assumed not to support pause, and all drawing operation will be emulated in 1136x726 canvas

Parameters:

* pausing - `true` if the game is paused, `false` if the game is unpaused.

Storyboard Functions
====================

This function is exported explicitly by DEPLS with `DEPLS.StoryboardFunctions`
table, thus it only exist on storyboard lua script.

*************************************************

### `void SetLiveOpacity ([number opacity = 255])`

Sets the Live Show! image opacity. This includes unit, header, notes, and more.

Parameters:

* `opacity` - The opacity, range from 0-255. 0 for invisible, 255 for opaque (fully visible)

Returns: *none*

*************************************************

### `void SetBackgroundDimOpacity([number opacity = 255])`

Sets background blackness (but not entirely black)

Parameters:

* `opacity` - Background blackness, from 0-255. 0 for full black (approx. 190 blackness), 255 for full bright

Returns: *none*

*************************************************

### `number GetCurrentElapsedTime()`

Get current elapsed time in DEPLS.

Returns: Elapsed time, in milliseconds. Negative value means simulator is not started yet

*************************************************

### `number GetLiveSimulatorDelay()`

Get live simulator delay. Delay before live simulator is shown

Returns: Live simulator delay, in milliseconds

*************************************************

### `void SpawnCircleTapEffect(number pos [, number r = 255 [, number g = 255 [, number b = 255]]])`

Show circletap effect in the specificed idol position and with specificed color

Parameters:

* `pos` - The idol position. 1 is rightmost, 9 is leftmost

* `r` - Red color component of the circletap (defaults to 255)

* `g` - Green color component of the circletap (defaults to 255)

* `b` - Blue color component of the circletap (defaults to 255)

Returns: *none*

*************************************************

### `Video|nil LoadVideo(string path)`

Load video file. Directory is relative to current beatmap folder

Parameters:

* `path` - Video filename

Returns: LOVE `Video` object or `AquaShineVideoObject` or `nil` on failure

> Unlike `love.graphics.newVideo`, this function allows loading of many video formats if system supports it (see `MultiVideoFormatSupported()`)

*************************************************

### `Image|nil LoadImage(string path)`

Load image. Directory is relative to current beatmap folder.

Parameters:

* `path` - Image filename

Returns: LOVE `Image` object or `nil` on failure

> For additional sandboxing and compatibility, this is synonym of `love.graphics.newImage`

*************************************************

### `Font|nil LoadFont([string path [, number size = 14]])`

Load font. Directory is relative to current beatmap folder.

Parameters:

* `path` - Font path or nil to use default, Motoya L Maru font `MTLmr3m.ttf`

* `size` - The font size. Defaults to 14.

Returns: LOVE `Font` object or `nil` on failure

*************************************************

### `string|nil ReadFile(string path)`

Reads the contents of file. Directory is relative to current beatmap folder

Parameters:

* `path` - File to get it's contents

Returns: The contents of the file, or `nil` on failure

*************************************************

### `void SetUnitOpacity(number pos [, number opacity = 255])`

Set unit visibility

Parameters:

* `pos` - The unit position. 9 is leftmost, 1 is rightmost

* `opacity` - The desired opacity. 0 is fully transparent, 255 is fully opaque

Returns: *none*

*************************************************

### `table GetCurrentAudioSample([number size = 1])`

Gets current playing audio sample, with specificed size

Parameters:

* `size` - The sample size

Returns: Stereo audio sample with size `size` (index 1 is L channel, index 2 is R channel)

> This function handles mono/stereo input and this function still works even if no audio is found, where in that case the sample is simply 0

*************************************************

### `Image|nil LoadDEPLS2Image(string path)`

Loads game image (not relative to beatmap directory)

Parameters:

* `path` - The image path

Returns: Image handle or `nil` on failure

*************************************************

### `number SetPlaySpeed([number speed_factor])`

Get or set play speed. This affects how fast the live simulator are

Parameters:

* `speed_factor` - The speed factor, in decimals. 1 means 100% speed (runs normally)

Returns: Previous play speed factor

> This function throws error if `speed_factor` is zero or less

> This function is disabled in rendering mode. Calls to this function in rendering mode will always result in error

*************************************************

### `void ForceNewNoteStyle(boolean new_style)`

Sets and forces note style.

Parameters:

* `new_style` - Use new-style (SIF v5.0) note (`true`) or use old-style (SIF pre-v5.0) note (`false`)

> This function can only be called inside `Initialize` function.

*************************************************

### `boolean IsRenderingMode()`

Check for current rendering type.

> This function can be useful to determine quality of storyboard

Returns: `true` if currently in rendering mode (offline drawing), `false` if currently in live mode (online drawing).

*************************************************

### `void SkillPopup(unit_pos, name, title[, navi[, rarity[, audio[, force]]]])`

Shows skill cut-in

Parameters:

* `unit_pos` - The unit position which one that triggers the skill

* `name` - The unit position effect color name

* `title` - Cut-in skill name

* `navi` - Transparent image of the cut-in

* `rarity` - Unit rarity. This determines the direction

* `audio` - Unit skill activation audio

* `force` - Always shows even if there's one in progress?

*************************************************

### `void AllowComboCheer()`

Allows star effects (combo cheer) to be drawn in the background. By default, beatmap with storyboard won't have combo cheer
drawn by default.

> This function can only be called inside `Initialize` function.

*************************************************

### `bool IsOpenGLES()`

Check if current renderer is OpenGL ES. This can be used to select shader code to use because Desktop GL shader and GLES shader code  
were bit different each other

Returns: `true` if running under OpenGLES, `false` otherwise

> This function also returns `true` when running LOVE under desktop with [ANGLE](http://angleproject.org) renderer.

*************************************************

### `bool MultiVideoFormatSupported()`

Check if FFmpeg extension is available.

Returns: `true` if FFmpeg extension is available (allow loading video other than Theora .ogg/.ogv), `false` otherwise.

*************************************************

### `table|Image|nil GetCurrentBackgroundImage([number index = 0])`

Get the current beatmap background.

Parameters:

* `idx` - The index to retrieve it's background image or nil for all index

Returns: LOVE `Image` object of specificed index, or nil, or table containing all of background image in LOVE `Image` object (index 0-4)

*************************************************

### `Image GetCurrentUnitImage(number index)`

Get the current unit image.

Parameters:

* `idx` - The unit index to retrieve it's image. 1 is rightmost, 9 is leftmost.

Returns: LOVE `Image` object

*************************************************

### `void UseZeroToOneColorRange()`

Changes the behaviour of `love.graphics.setColor` inside storyboard to use 0-1 range instead of 0-255.
0-255 color range is the default. This function exists for compatibility with older storyboard and doesn't
take LOVE 0.11.x color range changes into account.

> This function can only be called inside, or before `Initialize` function.

Storyboard Callback Functions
=============================

The stoyboard also can accept callbacks for specific event. You have to
declare the callback function as global in your storyboard.

Below is the list of storyboard callback functions:

*************************************************

### `void OnNoteTap(number pos, number accuracy, number distance, number attribute, boolean is_star, boolean is_simul, boolean is_token, any is_slide)`

Triggered everytime note is tapped on screen

Parameters:

* `pos` - Idol unit position. 9 is leftmost

* `accuracy` - The note tap accuracy. 1 for Perfect, 0.88 for Great, 0.8 for Good, 0.4 for Bad, and 0 for **Miss**

* `distance` - The note distance from the idol unit position, in pixels

* `attribute` - Note attribute. 1, 2, 3 are Smile, Pure, and Cool respectively. The others depends on beatmap type.

* `is_star` - Is the note is a star note (dangerous note)?

* `is_simul` - Is the note is a simultaneous note?

* `is_token` - Is the note is a token note?

* `is_slide` - Is the note is a slide note?

*************************************************

### `void OnLongNoteTap(boolean release, number pos, number accuracy, number distance, number attribute, boolean is_simul)`

Triggered everytime long note is tapped (and currently holding) or released

Parameters:

* `release` - Is this a long note release callback?

* `pos` - Idol unit position. 9 is leftmost

* `accuracy` - The note tap accuracy. 1 for Perfect, 0.88 for Great, 0.8 for Good, 0.4 for Bad, and 0 for **Miss** (in this case, release will never be triggered)

* `distance` - The note distance from the idol unit position, in pixels

* `attribute` - Note attribute. 1, 2, 3 are Smile, Pure, and Cool respectively. The others depends on beatmap type.

* `is_simul` - Is the note is a simultaneous note? (start holding only)

* `is_slide` - Is the note is a slide note?
