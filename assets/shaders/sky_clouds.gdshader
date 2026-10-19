shader_type sky;
// Langit biru gradasi + awan prosedural (fbm noise) — dipakai semua scene 3D
// lewat SkyKit.gd, menggantikan ProceduralSkyMaterial default yang terlihat
// abu-abu datar dan tidak punya awan sama sekali.

uniform vec3 sky_top_color : source_color = vec3(0.22, 0.50, 0.85);
uniform vec3 sky_horizon_color : source_color = vec3(0.72, 0.84, 0.93);
uniform vec3 ground_color : source_color = vec3(0.30, 0.28, 0.24);
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.45;
uniform float cloud_softness : hint_range(0.02, 0.5) = 0.18;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		v += amp * noise(p);
		p *= 2.02;
		amp *= 0.5;
	}
	return v;
}

void sky() {
	float up = EYEDIR.y;
	vec3 base = mix(sky_horizon_color, sky_top_color, smoothstep(0.0, 0.55, up));
	base = mix(base, ground_color, smoothstep(0.0, -0.4, up));

	// Proyeksi arah pandang ke bidang awan datar jauh di atas -> awan stabil, tak berputar aneh.
	vec2 cloud_uv = EYEDIR.xz / max(0.1, up + 0.18) * 0.12;
	float n = fbm(cloud_uv);
	float cloud = smoothstep(1.0 - cloud_coverage - cloud_softness, 1.0 - cloud_coverage + cloud_softness, n);
	cloud *= smoothstep(0.02, 0.3, up);   // pudar mendekati horizon & tak muncul di bawah cakrawala

	COLOR = mix(base, cloud_color, cloud * 0.85);
}
