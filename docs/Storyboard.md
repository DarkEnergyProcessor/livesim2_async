Lua Storyboard
==============

Lua storyboard is simply a Lua script which controls how objects shown behind the simulator.
Please note that Lua script running as Lua storyboard is sandboxed, which means most of `love`
functions doesn't exist in here or modified to prevent alteration of the rendering state, and
to prevent malicious Lua storyboard script writing anywhere.

Storyboard Entry Points
=======================

Lua storyboard needs to create this function in global namespace. Although there's way to use
it without this entry points by using coroutines, but it's usage is discouraged and only
provided for legacy DEPLS storyboard lua script.

*************************************************

### `void Initialize()`

Storyboard initialization. This function is called everytime storyboard is loaded. Load your
images here

*************************************************

### `void Update(number deltaT)`

Storyboard frame update. Draw and calculate everything for the storyboard in here.

Parameters:

* deltaT - The delta-time, in milliseconds

Storyboard Functions
====================

This function only exist on storyboard lua script.

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

Returns: love2d `Video` object or `nil` on failure

> For additional sandboxing and compatibility, this is synonym of `love.graphics.newVideo`

*************************************************

### `Image|nil LoadImage(string path)`

Load image. Directory is relative to current beatmap folder

Parameters:

* `path` - Image filename

Returns: love2d `Image` object or `nil` on failure

> For additional sandboxing and compatibility, this is synonym of `love.graphics.newImage`

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
