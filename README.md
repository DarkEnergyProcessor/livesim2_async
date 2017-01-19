#This one has been superseded by [DEPLS2](https://github.com/MikuAuahDark/DEPLS/tree/master). This one is only provided for learning purpose and should not be used/migrate to DEPLS2.

**********************************

Dark Enegy Processor Live Simulator
===================================

DEPLS (pronounced **Deep Less**) is a Love Live! School Idol Festival Live Show Simulator written in Lua meant to be run under LOVE2D framework.

You need LOVE2D v0.10.1 or above to run this live simulator.

How to run
==========

Start love2d with this command-line

    love <current directory> <beatmap_name>.json <beatmap_audio = <beatmap>.wav> <notes_speed = 0.8>

Example:

	love DEPLS test_beatmap.json m_006.ogg

It will play `test_beatmap.json` with `m_006.ogg` as the audio.

Don't worry, I've put some testing beatmap in there, `test_beatmap` and `love_marginal`. Also I put 1 song (Mermaid Festa vol.1, named `m_006.ogg`)

To add your own, place the music in `audio` folder and place the beatmap in `beatmap` folder. It expects `notes_list` from real SIF beatmap data.

Support for another beatmap format (like SifSimu, CBF, and SIFTrain beatmap) is planned.

Status
======

Currently this is still incomplete, but it's now possible to play beatmap, although still less fancy (no tap flash animation, no combo counter, etc.)
