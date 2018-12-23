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
 * \note To load default font, pass "__default" as \p path.
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
const char *readFile(const char *path);

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
 * Gets current audio sample rate.
 * \return Audio sample rate, in Hz.
 **/
size_t getAudioSampleRate();

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
 * both active at same time, Timing Window++ will take priority, which makes
 * Good become Perfect.
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

/**
 * Contains all function related to drawing stuff
 **/
namespace graphics
{

// Object creation
void *newCanvas();
void *newFont(const char *path, int size = 12);
void *newShader(const char *code);
void *newText(void *font, const char *text = nullptr);

// State change
void setBlendMode(const char *blend, const char *blendAlpha);
void setCanvas(void *canvas);
/**
 * Set drawing color.
 * \param r Red color component (0..1).
 * \param g Green color component (0..1).
 * \param b Blue color component (0..1).
 * \param a Alpha color component (0..1).
 */
void setColor(double r, double g, double b, double a = 1.0);
void setFont(void *font);
void setLineWidth(double width);
void setShader(void *shader);

// Drawing
/**
 * Clear screen to black.
 **/
void clear();
/**
 * Draw an object onto the screen.
 * \param drawable A drawable object.
 * \param x The position to draw the object (x-axis).
 * \param y The position to draw the object (y-axis).
 * \param r Orientation (radians).
 * \param sx Scale factor (x-axis).
 * \param sy Scale factor (y-axis).
 * \param ox Origin offset (x-axis).
 * \param oy Origin offset (y-axis).
 * \param kx Shearing factor (x-axis).
 * \param ky Shearing factor (y-axis).
 **/
void drawObject(
	void *drawable,
	double x = 0.0,
	double y = 0.0,
	double r = 0.0,
	double sx = 1.0,
	double sy = 1.0,
	double ox = 0.0,
	double oy = 0.0,
	double kx = 0.0,
	double ky = 0.0
)
void drawText(
	const char *text,
	double x = 0.0,
	double y = 0.0,
	double r = 0.0,
	double sx = 1.0,
	double sy = 1.0,
	double ox = 0.0,
	double oy = 0.0,
	double kx = 0.0,
	double ky = 0.0
);

/**
 * Draws pie arc.
 * \param drawMode How to draw the arc.
 * \param x The position of the center along x-axis.
 * \param y The position of the center along y-axis.
 * \param radius Radius of the arc.
 * \param r1 The angle at which the arc begins.
 * \param r2 The angle at which the arc terminates.
 * \param segm The number of segments used for drawing the arc.
 * \note The arc is drawn counter clockwise if the starting angle is
 * numerically bigger than the final angle. The arc is drawn clockwise if the
 * final angle is numerically bigger than the starting angle. 
 **/
void arc(
	const char *drawMode,
	double x, double y, double radius,
	double r1, double r2,
	int segm = 20
);
void ellipse(const char *drawMode, double x, double y, double rx, double ry, int segm = 20);
void line(double *points);

/**
 * Draws a rectangle.
 * \param drawMode How to draw the rectangle.
 * \param x The position of top-left corner along the x-axis.
 * \param y The position of top-left corner along the y-axis.
 * \param w Width of the rectangle.
 * \param h Height of the rectangle.
 * \param rx The x-axis radius of each round corner. Cannot be greater than
 * half the rectangle's width.
 * \param ry The y-axis radius of each round corner. Cannot be greater than
 * half the rectangle's height.
 * \param segm The number of segments used for drawing the round corners.
 **/
void rectangle(const char *drawMode, double x, double y, double w, double h, double rx = 0.0, double ry = 0.0, int segm = 20);

}

}
