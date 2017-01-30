#How To Setup

This page will guide you step-by-step how to run DEPLS2 for the first time. The key of getting DEPLS2 run is not hard, but not easy either.

##System Requirements

Before you proceed, make sure your device comply these requirements

* At least 1.3GHz dual core. More complex storyboard system requires more power and RAM

* At least 256MB of free RAM.

* OpenGL 2.1 (or OpenGLES 2 for Android) capable graphics card

* Windows: Windows Vista or above (sorry Windows XP users)

* Ubuntu: Ubuntu 14.04 - 16.10

* Mac OS X: Mac OS X v10.7 or above.

* Android: Android v2.3 or above.

* **iOS: Not supported!**

##Getting LOVE2D and run DEPLS

If your device comply with requirements above, then proceed. DEPLS2 requires LOVE2D v0.10.0 (or later) game framework. Below are steps to get LOVE2D installed.

###Windows

1. Clone this repository with git or download it as zip. Make sure you extract the zip.

2. Download LOVE2D [here](https://love2d.org/). Zip file is recommended.

3. Extract it somewhere and open command prompt in location where you extracted LOVE2D.

4. Now, type `lovec <DEPLS2 folder>`. If it works correctly, you'll see DEPLS2 main menu.

> `lovec` is available in LOVE2D v0.10.2 and later. It's not hard to create one for older version if you have VS command prompt. To create `lovec`, run `copy love.exe lovec.exe && editbin /SUBSYSTEM:CONSOLE lovec.exe` in VS command prompt.

###Ubuntu

1. Clone this repository with git or download it as zip. Make sure you extract the zip.

2. Add [this PPA](https://launchpad.net/~bartbes/+archive/love-stable) to your apt repository.

3. Type `sudo apt-get update` and `sudo apt-get install love`.

4. Type `love <DEPLS2 folder>`. If it works correctly, you'll see DEPLS2 main menu

###Mac OS X

*TODO: Add Mac OS X instructions*

###Android

1. Clone this repository or download zip. Push all files to somewhere in your phone in `DEPLS-DEPLS2` folder if you download it as ZIP, or simply push all files to your phone except `.git` folder (might be hidden).

2. Download LOVE2D APK from [LOVE2D](https://love2d.org/) website, or from Play Store.

3. Find DEPLS2 `main.lua` in your phone, and open it with LOVE2D

4. If it works, you'll see DEPLS2 main menu, but to play beatmaps, you have to specify it **in command-line**. Well, you can't pass the beatmap name in command-line because there is no such thing in Android, so special steps is required for Android. See below

##Determining DEPLS R/W directory

It's necessary so that you can add beatmaps. If you're under Windows, Ubuntu, or Mac OS X, look at the terminal output (in Windows, use `lovec` instead of `love`). It will write `R/W Directory: <DEPLS2 R/W directory>`. Example in Windows: `R/W Directory: C:/Users/User/AppData/Roaming/LOVE/DEPLS`.

If you're under Android, most of the time it's in `/sdcard/Android/data/org.love2d.android/files/save/DEPLS`. If you didn't see that folder, open a new issue specifying your device. It is because if you run it for the first time, DEPLS will create it's own R/W directory, and **guaranteed** to be created.

##Adding beatmaps

DEPLS2 supports these beatmap formats:

* DEPLS beatmap folder. It combines CBF format and raw SIF format. Additionaly with storyboard support.

* LS2 beatmap file. This is new DEPLS2 binary beatmap file format which allows single LS2 file to contain storyboard, custom unit data, and such. Currently there's no encoder, but the file structure is available.

* Raw SIF beatmap, without score information. Stripped from SIF response data. This is beatmap format internally used by DEPLS, without any modification. The extension is `.json` (captured ones is also supported, with score information)

* yuyu live simulator beatmap, the one with `.txt` extension (not `.ssp` one). TODO: support for the new beatmap format

* Custom Beatmap Festival project folder.

* Specialized MIDI file. The extension is `.mid`

* LLPractice beatmap. The extension is `.llp` (make sure to rename it to prevent confusion)

* SIFTrain beatmap. The extension is `.rs`. **Currently disabled due to processing bug**. There's problem in SIFTrain beatmap which causes JSON parse error. This is SIFTrain fault, since DEPLS2 uses JSON library which comply with JSON standards. To fix it, open the beatmap with text editor and add double quote to the value in the `music_file`.

DEPLS supports these audio formats

* Raw PCM in WAV container

* Vorbis in OGG container

* MPEG Audio Layer 3/MP3

DEPLS also uses that order to load audio files. So if you have `beatmap.ogg` and `beatmap.wav`, `beatmap.wav` will be loaded because it has higher priority.

Add the beatmap file/folder in `<DEPLS2 R/W directory>/beatmap` and the optionally the audio in `<DEPLS2 R/W directory>/audio`. The audio name must same with the beatmap name, or explictly specify the used audio in the command-line (discussed later).

##Starting beatmap

Note: Beatmap name and audio file is relative to `<DEPLS2 R/W dir>/beatmap/` and `<DEPLS2 R/W dir>/audio/` folder respectively. Specifying audio file argument is optional, and DEPLS will try to load audio in beatmap folder (if it's DEPLS/CBF beatmap folder) or in audio folder with the audio filename same as the beatmap name (and will try to load WAV or OGG audio).

###Android

In Android, write file named `command_line.txt` in DEPLS2 R/W directory with this contents

	livesim
    <beatmap name without extension>
    <used audio with extension (optional)>

Then start DEPLS like the way described above.

###Desktop (Windows, Ubuntu, Mac OS X)

Start LOVE2D with this command-line arguments

    love <DEPLS2 folder> livesim <beatmap name without extension> [audio filename with extension]

Note: in windows, use `lovec` instead of `love` to keep the terminal waits for love to exits.

##Example Beatmap

To run example beatmap, the beatmap name must be start with two colons then followed by the example beatmap ID. So it will be

    love <DEPLS2 folder> livesim ::<id>

Here is example beatmap IDs:

1. [Daydream Warrior beatmap](https://www.youtube.com/watch?v=PpZqNjv0HUw)

2. [MOMENT RING beatmap](https://www.youtube.com/watch?v=u76q9x7lOzA)

As times goes on, I might add more example beatmaps.