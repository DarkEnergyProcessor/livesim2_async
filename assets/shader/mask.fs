extern Image mask;
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc)
{
	vec4 col1 = Texel(tex, tc);
	return color * vec4(col1.rgb, col1.a * Texel(mask, tc).r);
}
