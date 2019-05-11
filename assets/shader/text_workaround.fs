// Workaround of LOVE Text having unintended "black border" caused by blending
// Part of Live Simulator: 2
// See copyright notice in main.lua

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc)
{
	return color * vec4(1.0, 1.0, 1.0, Texel(tex, tc).a);
}
