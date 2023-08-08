How To Start
============

Live Simulator: 2 v3.0 requires LOVE 0.10.0 or later. Most of the time this thing is already taken
care by the distributed version, but you need to take this into account if you're under Linux. Some
Linux distros only ship with 0.9.2!

Live Simultor: 2 v4.0 recommends LOVE 11.3 or later. There are some consequences when using older version:

* 11.0 - 11.2: Performance regression on some systems.

* 0.10.2 and earlier: Deprecated, support may removed in the future.

System Requirements
-------------------

Before you proceed, make sure your device comply these requirements

* **v4.0**: a 64-bit CPU and 64-bit OS.

* At least 1.4 GHz dual core. \*

* At least 384 MB of free RAM. \*

* Desktop: OpenGL 2.1-capable graphics card (or iGPU) or later.

* Windows: Windows 7 or later. Note that tests are done in Windows 10 and 11.

* Linux: Oldest-supported Ubuntu distribution.

* Mac OS X: Mac OS X v10.7 or above.

* Mobile: OpenGLES 2 capable graphics card.

* Android: Android 5.0 or later. x86-64 is supported.

* iOS: Live Simulator: 2 only tested under iOS 9, but older version should be possible, down to iOS 6. **Jailbreak needed**

\* More complex storyboard system requires more CPU, GPU, and RAM

Nightly Builds
--------------

GitHub Actions automatically builds new fused binary on each commit for Windows and Linux in here: https://github.com/DarkEnergyProcessor/livesim2_async/actions?query=workflow%3Abuild. Logging in to GitHub is required to download the artifacts.

The nighly builds uses a modified LOVE with [`ls2xlib`](https://github.com/DarkEnergyProcessor/ls2x) and [`lua-https`](https://github.com/love2d/lua-https) built-in. The FFmpeg version denotes the LS2X's needed FFmpeg version.

Getting Live Simulator: 2
-------------------------

### Windows

#### Releases

Simply download from releases tab above, extract, and run `livesim2.exe`

#### Nightly Builds

[See above.](#nightly-builds)

#### From Source

Note: Running from source requires **Windows 10 1809 or later**!

1. Create new directory `livesim2` (or any folder you like).

2. Run `fsutil file setCaseSensitiveInfo livesim2 enable` in elevated **command prompt** (not powershell).

3. Clone this repository with `git clone --recurse-submodules https://github.com/DarkEnergyProcessor/livesim2_async livesim2` or any equivalent link provided above. The `livesim2` denotes the folder in step 1 and 2. Add `--depth 1` if needed.

4. Download LÖVE: https://love2d.org/ or https://github.com/love2d/love/releases. Latest 11.x version and Zip file is recommended. Make sure to pick `win64` version!

5. Extract it somewhere and open command prompt in location where you extracted LÖVE.

6. Now, type `lovec <livesim2 folder>`. If it works correctly, you'll see Live Simulator: 2 main menu.

### Linux

#### Nightly Builds

[See above.](#nightly-builds)

#### From Source

1. Clone this repository with `git clone --recurse-submodules https://github.com/DarkEnergyProcessor/livesim2_async livesim2` or any equivalent link provided above. The `livesim2` denotes the folder destination. Add `--depth 1` if needed.

2. Download LÖVE AppImage: https://love2d.org/ or https://github.com/love2d/love/releases. Latest 11.x version is recommended. You may need to install `libfuse2` and FUSE-capable kernel. Mark the AppImage as executable.

3. Now, type `path/to/love.AppImage <livesim2 folder>`. If it works correctly, you'll see Live Simulator: 2 main menu.

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
