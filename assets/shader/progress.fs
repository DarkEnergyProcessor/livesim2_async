extern vec4 backgroundColor;
extern float time;

vec4 effect(vec4 foregroundColor, Image tex, vec2 tc, vec2 sc)
{
	float saw = fract((tc.x - tc.y) * 4.0 + (1.0 - time));
	float value = smoothstep(0.475, 0.625, abs(2.0 * saw - 1.0));
	return mix(backgroundColor, foregroundColor, value);
}
