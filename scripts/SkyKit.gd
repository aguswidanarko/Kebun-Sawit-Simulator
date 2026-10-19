class_name SkyKit
extends RefCounted
## Langit (shader biru + awan prosedural) & tanah kecoklatan dipakai SEMUA scene 3D,
## biar konsisten & tidak perlu copy-paste ProceduralSkyMaterial polos (yang defaultnya
## terlihat abu-abu datar dan tidak punya awan).

const SKY_SHADER := "res://assets/shaders/sky_clouds.gdshader"
const GROUND_TEX := "res://assets/textures/ground_diff.jpg"
const GROUND_NOR := "res://assets/textures/ground_nor.jpg"
# Tint hangat utk menggeser ground_diff.jpg (tekstur lumut kuning-hijau) jadi kecoklatan.
const GROUND_TINT := Color(0.66, 0.50, 0.37)
const GROUND_FLAT_COLOR := Color(0.44, 0.36, 0.24)   # warna polos pengganti hijau-zaitun lama

static var _shader_cached: Shader

## Pasang WorldEnvironment (langit biru+awan, kabut, filmic) + DirectionalLight3D.
## Panggil sekali per scene. Kembalikan DirectionalLight3D kalau perlu diatur lagi.
static func build_env(parent: Node3D, sun_deg := Vector3(-48, -38, 0), fog_density := 0.0012) -> DirectionalLight3D:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	if _shader_cached == null:
		_shader_cached = load(SKY_SHADER)
	var sm := ShaderMaterial.new()
	sm.shader = _shader_cached
	sky.sky_material = sm
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.85
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	if fog_density > 0.0:
		e.fog_enabled = true
		e.fog_light_color = Color(0.80, 0.86, 0.92)
		e.fog_density = fog_density
	we.environment = e
	parent.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = sun_deg
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	parent.add_child(sun)
	return sun

## Material tanah kecoklatan bertekstur (ganti ground_diff.jpg mentah yg kuning-hijau).
static func ground_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var diff = load(GROUND_TEX)
	if diff != null:
		m.albedo_texture = diff
		m.albedo_color = GROUND_TINT
	else:
		m.albedo_color = GROUND_FLAT_COLOR
	var nor = load(GROUND_NOR)
	if nor != null:
		m.normal_enabled = true
		m.normal_texture = nor
	return m
