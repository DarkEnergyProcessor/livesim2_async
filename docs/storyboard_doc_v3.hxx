/**
 * This is storyboard function documentation of Live Simulator: 2
 * 
 * Since this documentation is written in C++ header file, there
 * are some consideration that must be taken into account:
 * - `const char*` is `string` datatype in Lua.
 * - `double` is `number` datatype in Lua.
 * - `int` and `size_t` is also `number` datatype in Lua, but doesn't accept
 *   decimals.
 * - `void` means no return value.
 * - `exception` means error will be raised (by `error` function call).
 * - `struct` definition is just actually table with specified fields.
 * - Other types may represented as `void*`.
 * \file storyboard_doc_v3.hxx
 **/

/**
 * This indicates function that applies to Live Simulator: 2 v3.0
 **/
namespace StoryboardVersion3
{

/**
 * Current background.
 **/
void *__background;
/**
 * Unit position 1.
 **/
void *__unit_1;
/**
 * Unit position 2.
 **/
void *__unit_2;
/**
 * Unit position 3.
 **/
void *__unit_3;
/**
 * Unit position 4.
 **/
void *__unit_4;
/**
 * Unit position 5.
 **/
void *__unit_5;
/**
 * Unit position 6.
 **/
void *__unit_6;
/**
 * Unit position 7.
 **/
void *__unit_7;
/**
 * Unit position 8.
 **/
void *__unit_8;
/**
 * Unit position 9.
 **/
void *__unit_9;

/**
 * Note information for "note" callback.
 **/
struct NoteInfo
{
	bool __long;         /*!< is note a long note? (actual name is `long`) */
	bool release;        /*!< is note a release note? (only exist if \p long is `true`) */
	bool isStar;         /*!< is note a star note? */
	bool isSimultaneous; /*!< is note a simultaneous note? */
	bool isToken;        /*!< is note a token note? */
	bool isSwing;        /*!< is note a swing note? */
};

/**
 * Function signature for "init" callback in registerCallback()
 **/
typedef void(*signatureCBInit)();

/**
 * Function signature for "update" callback in registerCallback()
 * \param dt Time since the last update in seconds (pause affected).
 * \param actualdt Time since the last update in seconds.
 * \note If live is paused, \p dt is 0, but \p actualdt won't.
 **/
typedef void(*signatureCBUpdate)(double dt, double actualdt);

/**
 * Function signature for "draw" callback in registerCallback()
 **/
typedef void(*signatureCBDraw)();

/**
 * Function signature for "note" callback in registerCallback()
 * \param pos Idol unit position.
 * \param judgement Judgement, either `perfect`, `great`, `good`, `bad`,
 *  or `miss`.
 * \param distance Note distance from the idol unit position, in pixels.
 * \param info Current note information.
 **/
typedef void(*signatureCBNote)(int pos, const char *judgement, double distance, NoteInfo info);

/**
 * Treat storyboard script as new storyboard code.
 * 
 * Legacy storyboard and new storyboard scripts are not compatible each other
 * due to many internal changes between Live Simulator: 2 v2.0 and v3.0.
 * \param version Storyboard version. At the moment only 0 is allowed and other
 *        value raises error.
 * \exception exception invalid storyboard version passed
 **/
void newStoryboard(int version = 0);

/**
 * \param name Callback name. Available callback names are:
 * - `init` - Storyboard initialization function.
 * - `update` - Storyboard update function.
 * - `draw` - Storyboard draw function.
 * - `note` - Note tap/release.
 * \param func Callback function.
 * \sa signatureCBInit
 * \sa signatureCBUpdate
 * \sa signatureCBDraw
 * \sa signatureCBNote
 **/
void registerCallback(const char *name, void *func);

/**
 * Set live interface opacity.
 * \param opacity interface opacity (0..1).
 * \note \p opacity will be clamped to 0..1 range.
 **/
void setLiveOpacity(double opacity);

/**
 * Load image file from beatmap.
 * \param path Image file path, relative to current beatmap.
 * \return [LOVE Image](https://love2d.org/wiki/Image) object.
 * \exception exception file not found.
 * \exception exception invalid image format.
 **/
void *loadImage(const char *path);

/**
 * Load video file from beatmap.
 * \param path Video file path, relative to current beatmap.
 * \return [LOVE Video](https://love2d.org/wiki/Video) object.
 * \warning This function only loads the video, without the audio!
 * \exception exception file not found.
 * \exception exception invalid video format.
 **/
void *loadVideo(const char *path);

/**
 * Load font from beatmap.
 * \param path Font file path, relative to current beatmap.
 * \param size Font size.
 * \return [LOVE Font](https://love2d.org/wiki/Font) object.
 * \exception exception file not found.
 * \exception exception invalid font format.
 **/
void *loadFont(const char *path, int size = 14);

/**
 * Read file contents from beatmap.
 * \param path File path, relative to current beatmap.
 * \return File contents.
 * \exception exception file not found.
 */
const char *readfile(const char *path);

/**
 * Set unit icon visibility
 * \param position Unit position.
 * \param opacity Unit icon opacity.
 * \note \p opacity will be clamped to 0..1 range.
 * \exception exception unit \p position out of range.
 **/
void setUnitOpacity(int position, double opacity);

/**
 * Gets current audio sample, with specified size.
 * \param size Sample size to retrieve.
 * \return Stereo audio sample formatted, where:
 * - `sample[1]` is left channel and contain left channel audio sample.
 * - `sample[2]` is right channel and contain right channel audio sample.
 **/
double[2] *getCurrentAudioSample(size_t size);

/**
 * Forces note style to specified note style.
 * \param baseFrame Base frame style ID.
 * \param swing Swing note style ID.
 * \param simultaneous Simultaneous mark style ID.
 * \note Currently defined style ID are:
 * 1. Default style
 * 2. Neon style
 * 3. Matte style
 * \exception exception invalid style ID.
 **/
void setNoteStyle(int baseFrame, int swing, int simultaneous);

/**
 * Add score by specified amount.
 * \param amount Amount of score to add.
 * \exception exception \p amount must higher than 0.
 **/
void addScore(int amount);

/**
 * Activates and set Timing Window++ skill duration.
 * 
 * Timing Window++ gives red timing window skill which makes Good or Great
 * become Perfect.
 * \param time Duration in seconds with millisecond resolution.
 * \note This function doesn't accumulate the time. If the current timing
 * duration is higher than \p time, this function has no effect
 **/
void setRedTimingDuration(double time);

/**
 * Activates and set Timing Window+ skill duration.
 * 
 * Timing Window+ gives yellow timing window skill which makes Great become
 * Perfect.
 * \param time Duration in seconds with millisecond resolution.
 * \note This function doesn't accumulate the time. If the current timing
 * duration is higher than \p time, this function has no effect
 * \note Timing Window++ has precedence over Timing Window+, so if you have
 * both active at same time, Timing Window++ will take priority, which makes Good
 * become Perfect.
 **/
void setYellowTimingDuration(double time);

/**
 * Check whenever the notes is randomized.
 * \return `false` if the notes is not randomized, `true` otherwise.
 **/
bool isRandom();

/**
 * Set post-processing shader chain.
 * \param ... New shader(s) to be used as post-processing effect.
 * \return Previous list of shaders used for post-processing effect.
 * \warning Shader must be specified in order they'll be applied.
 **/
void *setPostProcessingShader(...);

}
