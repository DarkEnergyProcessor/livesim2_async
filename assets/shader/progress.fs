extern vec4 backgroundColor;
extern float time;

float smoothstep_reimpl(float edge0, float edge1, float x)
{
	float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
	return t * t * (3.0 - 2.0 * t);
}

vec4 effect(vec4 foregroundColor, Image tex, vec2 tc, vec2 sc)
{
	float saw = fract((tc.x - tc.y) * 4.0 + (1.0 - time));
	float value = smoothstep(0.475, 0.625, abs(2.0 * saw - 1.0));
	return mix(backgroundColor, foregroundColor, value);
}
