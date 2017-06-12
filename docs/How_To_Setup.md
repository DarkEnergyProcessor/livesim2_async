How To Start
============

System Requirements
-------------------

Before you proceed, make sure your device comply these requirements

* At least 1GHz dual core. \*

* At least 256MB of free RAM. \*

* Desktop: Direct3D 9 capable graphics card under Windows or OpenGL 2.1 under Linux and OS X. OpenGL 2.1 capable graphics card is recommended anyway.

* Mobile: OpenGLES 2 capable graphics card.

* Windows: Windows Vista or above (sorry Windows XP users)

* Ubuntu: Ubuntu 14.04 - 16.10

* Mac OS X: Mac OS X v10.7 or above.

* Android: Android v4.0 or above. x86 is supported. **ARMv5 and ARMv6 is not supported**

* iOS: iOS 9. Live Simulator: 2 only tested under iOS 9 atm.

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

### Ubuntu

1. Clone this repository with git or download it as zip. Make sure you extract the zip.

2. Add [this PPA](https://launchpad.net/~bartbes/+archive/love-stable) to your apt repository.

3. Type `sudo apt-get update` and `sudo apt-get install love`.

4. Type `love <livesim2 folder>`. If it works correctly, you'll see Live Simulator: 2 main menu

### Mac OS X

*TODO: Add Mac OS X instructions*

### Android

1. Simply download the APK from releases tab above and install it into your phone/tablet.

Determining R/W directory
-------------------------

You should see the R/W directory in main menu when starting Live Simulator: 2. If you didn't see that folder, open a new issue specifying your device because it's **guaranteed** to be created, otherwise error will be thrown.

Adding beatmaps
---------------

Live Simulator: 2 supports these beatmap formats:

* DEPLS beatmap folder. It inherits from CBF format. Beatmap file can be LS2 beatmap, SIF beatmap, CBF, MIDI, or LLP. Additionaly with storyboard support. Can be in ZIP.

* LS2 beatmap file. This is new Live Simulator: 2 binary beatmap file format which allows single LS2 file to contain storyboard, custom unit data, and such. Currently there's no encoder, but the file format structure is available.

* Raw SIF beatmap, with or without score information. This is beatmap format internally used by Live Simulator: 2, without any modification. The extension is `.json`.

* yuyu live simulator beatmap, the one with `.txt` extension (not `.ssp` one). **TODO: support for the new beatmap format**

* Custom Beatmap Festival project folder. Can be in ZIP.

* Specialized MIDI file. The extension is `.mid`

* LLPractice beatmap. The extension is `.llp`. **Make sure to rename the extension to prevent confusion**

Live Simulator: 2 supports these audio formats

* Raw PCM in WAV container

* Vorbis in OGG container

* MPEG Audio Layer 3/MP3

Live Simulator: 2 also uses that order to load audio files. So if you have `beatmap.ogg` and `beatmap.wav`, `beatmap.wav` will be loaded because it has higher priority.

Add the beatmap file/folder to `<livesim2 R/W directory>/beatmap` and the optionally the audio in `<livesim2 R/W directory>/audio` (for mobile devices/desktop), or simply drag-and-drop the beatmap file/folder to Live Simulator: 2 window while in "Select Beatmap" menu (for desktop). The audio name must same with the beatmap name.

**Note for iOS**: It's currently impossible to add beatmaps without jailbreak.

Example Beatmap
---------------

**Example beatmap is now deprecated. It's preferred to download the .ls2 file in `test` folder and add that to Live Simulator: 2 instead**

To run example beatmap, command-line must be used to start Live Simulator: 2. Invoking example beatmap under mobile device is impossible. The beatmap name must be start with two colons then followed by the example beatmap ID. So it will be:

    love <livesim2 folder> livesim ::<id>

Note: `love <livesim2 folder>` can be replaced to `livesim2` for fused executable from releases tab (Windows only)

Here is example beatmap IDs:

1. [Weisser Schnee beatmap by me](https://www.youtube.com/watch?v=szN0faby5HM). Uses swing notes, storyboard (with shader), custom units, and note style enforcing.

2. [Thrilling･One Way by me](https://www.youtube.com/watch?v=xfWGjFo5dy8). Uses storyboard (with shader), FFT, and custom units.
