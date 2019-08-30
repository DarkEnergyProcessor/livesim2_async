extern vec2 resolution;
extern vec2 dir;

// https://github.com/Jam3/glsl-fast-gaussian-blur
vec4 effect(vec4 c, Image image, vec2 uv, vec2 sc)
{
	vec4 color = vec4(0.0);
	vec2 off1 = vec2(1.3846153846) * dir;
	vec2 off2 = vec2(3.2307692308) * dir;
	color += Texel(image, uv) * 0.2270270270;
	color += Texel(image, uv + (off1 / resolution)) * 0.3162162162;
	color += Texel(image, uv - (off1 / resolution)) * 0.3162162162;
	color += Texel(image, uv + (off2 / resolution)) * 0.0702702703;
	color += Texel(image, uv - (off2 / resolution)) * 0.0702702703;
	return color * c;
}
