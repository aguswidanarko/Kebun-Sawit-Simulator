shader_type canvas_item;
// Foto selalu grayscale + kontras 1.08 (design system Modernist).

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	g = clamp((g - 0.5) * 1.08 + 0.5, 0.0, 1.0);
	COLOR = vec4(vec3(g), c.a);
}
