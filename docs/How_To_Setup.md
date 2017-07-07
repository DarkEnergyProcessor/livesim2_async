How To Start
============

System Requirements
-------------------

Before you proceed, make sure your device comply these requirements

* At least 1GHz dual core. \*

* At least 256MB of free RAM. \*

* Desktop: OpenGL 2.1, unless noted.

* Windows: Windows Vista or above. Graphics card must support at least Direct3D 9 (by using ANGLE backend, and treated as OpenGLES 2), but OpenGL 2.1 is recommended.

* Linux: Can't be determined, but for Ubuntu: At least Ubuntu 14.04

* Mac OS X: Mac OS X v10.7 or above.

* Mobile: OpenGLES 2 capable graphics card.

* Android: Android v4.0 or above (x86 is natively supported). **ARMv5 and ARMv6 CPUs is not supported**

* iOS: Live Simulator: 2 only tested under iOS 9, but older version should be possible, down to iOS 6. **Jailbreak needed**

\* More complex storyboard system requires more CPU, GPU, and RAM

Getting LOVE2D and run Live Simulator: 2
----------------------------------------

If your device comply with requirements above, then proceed.

### Windows

#### Method A

1. Simply download from releases tab above, extract, and run `livesim2.exe`

#### Method B

1. Clone this repository with git or download it as zip. Make sure you extract the zip.

2. Download LOVE2D [here](https://love2d.org/). Zip file is recommended.

3. Extract it somewhere and open command prompt in location where you extracted LOVE2D.

4. Now, type `lovec <livesim2 folder>`. If it works correctly, you'll see Live Simulator: 2 main menu.

> `lovec` is available in LOVE2D v0.10.2 and later. It's not hard to create one for older version if you have VS command prompt. To create `lovec`, run `copy love.exe lovec.exe && editbin /SUBSYSTEM:CONSOLE lovec.exe` in VS command prompt.

### Linux

#### Ubuntu

1. Clone this repository with git or download it as zip. Make sure you extract the zip.

2. Add [this PPA](https://launchpad.net/~bartbes/+archive/love-stable) to your apt repository.

3. Type `sudo apt-get update` and `sudo apt-get install love`.

4. Type `love <livesim2 folder>`. If it works correctly, you'll see Live Simulator: 2 main menu

#### Other distros

**TODO: Use AppImages**

### Mac OS X

*TODO: Add Mac OS X instructions*, but hopefully RayFirefist (@RayFirefist in Twitter) can provide Mac OS X `.dmg` file.

### Android

1. Simply download the APK from releases tab above and install it into your phone/tablet.

### iOS

1. _TODO: Add iOS instruction_. At the moment, you can ask @RayFirefist in Twitter, because he's one who tested Live Simulator: 2 under iOS

Determining R/W directory
-------------------------

You should see the R/W directory in main menu when starting Live Simulator: 2. If you didn't see that folder in your file manager, open a new issue specifying your device because it's **guaranteed** to be created (as long as you run the app at least once). If it doesn't able to create the directory, Live Simulator: 2 will throw error.

Adding beatmaps
---------------

Live Simulator: 2 supports these beatmap formats:

* DEPLS beatmap folder. It's based on CBF format. Beatmap file can be LS2 beatmap, SIF beatmap, CBF, MIDI, or LLP. Additionaly with storyboard support. Can be in ZIP.

* LS2 beatmap file. This is new Live Simulator: 2 binary beatmap file format which allows single LS2 file to contain storyboard, custom unit data, and such. Currently there's no encoder, but the file format structure is available.

* Raw SIF beatmap, with (captured version) or without score information (raw version).

* SIFs, yuyu live simulator beatmap, the one with `.txt` extension (not `.ssp` one). **TODO: support for the new beatmap format**

* Custom Beatmap Festival project folder. Can be in ZIP. **Project data must be in root and not in a directory**

* Specialized MIDI file.

* LLPractice beatmap.

* SIFTrain beatmap. SIFTrain **Extended** beatmap by [MilesElectric168](https://www.reddit.com/r/SchoolIdolFestival/comments/6gqnxk/reintroducting_my_llsif_live_simulator_depls_live/ditlqdg/) is also supported.

As of Live Simulator: 2 v2.0, file extension no longer matters. Live Simulator: 2 will try to scan the file contents instead of checking the file extension.

Live Simulator: 2 supports these audio formats

* Raw PCM in WAV container

* Vorbis in OGG container

* MPEG Audio Layer 3/MP3

Live Simulator: 2 also uses that order to load audio files. So if you have `beatmap.ogg` and `beatmap.wav`, `beatmap.wav` will be loaded instead, because it has higher priority.

Add the beatmap file/folder to `<livesim2 R/W directory>/beatmap` and the optionally the audio in `<livesim2 R/W directory>/audio` (for mobile devices/desktop), or simply drag-and-drop the beatmap file/folder to Live Simulator: 2 window while in "Select Beatmap" menu (for desktop). The audio name must same with the beatmap name.
