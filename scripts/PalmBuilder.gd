class_name PalmBuilder
extends RefCounted
## Pembangun pohon sawit TUNGGAL dipakai semua scene 3D (dunia, viewer, preview).
## = batang (cylinder) + mahkota fronds Quaternius CC0 + rumpun buah merah prosedural.
## Semua aset CC0/kode sendiri -> aman komersial.

const PALM_SCENE := "res://assets/models/palm/palm_tree.glb"
const SEEDLING_SCENE := "res://assets/models/palm/bibit_sawit.obj"
const TRUNK_COLOR := Color(0.36, 0.27, 0.18)

## Tahap umur tanaman sesuai istilah kebun: TB0 = baru tanam, TBM = belum
## menghasilkan (muda, tanpa buah). TM (menghasilkan/berbuah) dipecah 3 tingkat
## umur produksi (dihitung sejak panen pertama ~umur 4 th):
##  - TM_BARU   (TM1-TM4,  umur ~4-8 th): pokok pendek, sudah berbuah, dipanen DODOS.
##  - TM_REMAJA (TM5-TM10, umur ~8-13 th): tinggi pokok = SEPARUH TM tua, dipanen egrek pendek.
##  - TM_TUA    (>TM10,    umur >13 th): tinggi pokok penuh (formula asli, tak berubah).
enum Stage { TB0, TBM, TM_BARU, TM_REMAJA, TM_TUA }

## Aset dedicated per tahap siklus tanaman ("Asset kelapa sawit"), dipakai
## RantaiPascapanen.gd. Semua model sudah diautori skala meter asli oleh
## pembuat aset (lihat diagnosa AABB) -> TIDAK di-rescale, hanya didudukkan
## ke y=0 lewat AABB (lihat build_asset_stage/_ground).
const ASSET_KECAMBAH := "res://assets/models/palm/stages/kecambah-kelapa-sawit.glb"
const ASSET_PN_1BLN := "res://assets/models/palm/stages/bibit-sawit-1-bulan.glb"
const ASSET_PN_2BLN := "res://assets/models/palm/stages/bibit-sawit-2-bulan.glb"
const ASSET_PN_3BLN := "res://assets/models/palm/stages/bibit-sawit-3-bulan.glb"
const ASSET_MN_12BLN := "res://assets/models/palm/stages/bibit-kelapa-sawit-12-bulan.glb"
const ASSET_TB0 := "res://assets/models/palm/stages/kelapa-sawit-tb0.glb"
const ASSET_TBM1 := "res://assets/models/palm/stages/kelapa-sawit-tbm1.glb"
const ASSET_TBM2 := "res://assets/models/palm/stages/kelapa-sawit-tbm2.glb"
const ASSET_TBM3 := "res://assets/models/palm/stages/kelapa-sawit-tbm3.glb"
const ASSET_TM1 := "res://assets/models/palm/stages/kelapa-sawit-tm1.glb"
const ASSET_TM_REMAJA := "res://assets/models/palm/stages/kelapa-sawit-tm-remaja.glb"
const ASSET_TM_TUA := "res://assets/models/palm/stages/kelapa-sawit-tm-tua.glb"

static var _cached: PackedScene
static var _seedling_cached: Mesh
static var _asset_cache := {}   # path(String) -> PackedScene
static var _asset_height_cache := {}   # path(String) -> float (m)
## Offset dudukan ke y=0 per path. Semua instance dari PackedScene yang sama
## punya geometri identik, jadi AABB-nya juga identik — cukup dihitung SEKALI.
## Tanpa cache ini _local_aabb() menelusuri seluruh pohon node untuk tiap-tiap
## instance; di FarmWorld3D (8x8 = 64 pokok, model TM ~5 MB) itu 64x penelusuran
## penuh dan jadi penyebab loading "Jelajahi Kebun" memakan puluhan detik di HP.
static var _asset_ground_cache := {}   # path(String) -> float (offset y)

## Instance sebuah model tahap dedicated (glb) apa adanya, hanya didudukkan ke
## tanah (y=0) — skalanya sudah benar (meter asli) dari pembuat aset.
static func build_asset_stage(path: String) -> Node3D:
	var root := Node3D.new()
	var ps := _load_asset(path)
	if ps:
		var inst: Node3D = ps.instantiate()
		if not _asset_ground_cache.has(path):
			_asset_ground_cache[path] = _local_aabb(inst).position.y
		inst.position.y -= float(_asset_ground_cache[path])
		root.add_child(inst)
	return root

## Pilih aset dedicated sesuai umur pokok lapangan (tahun) — dipakai scene yang
## merender kebun existing dari umur bebas (bukan siklus eksplisit RantaiPascapanen).
## `start_harvest_age` = umur mulai panen varietas blok ini (seed.start_harvest_age_year,
## 3 atau 4 th tergantung varietas — lihat seed_catalog.json). Tahap TBM1/TBM2/TBM3
## diskalakan PROPORSIONAL thd umur ini (bukan patokan tetap age<4) supaya batas
## "mulai terlihat TM" selalu PAS dgn umur varietas itu benar-benar mulai berbuah —
## kalau tidak, varietas cepat panen (Damimas/FR/Topaz, start_harvest_age_year=3)
## akan masih tampil TBM3 padahal Agronomy.tbs_batch_kg() sudah menghasilkan TBS
## matang di umur 3 th (penanda panen muncul di pokok yg tampilannya belum TM).
static func asset_for_age(age_years: float, start_harvest_age: float = 4.0) -> String:
	var sha := maxf(start_harvest_age, 1.0)
	if age_years < sha * 0.33:
		return ASSET_TBM1
	elif age_years < sha * 0.67:
		return ASSET_TBM2
	elif age_years < sha:
		return ASSET_TBM3
	elif age_years < sha + 4.0:
		return ASSET_TM1
	elif age_years < sha + 9.0:
		return ASSET_TM_REMAJA
	else:
		return ASSET_TM_TUA

## Instance langsung aset dedicated sesuai umur (lihat asset_for_age).
static func build_for_age(age_years: float, start_harvest_age: float = 4.0) -> Node3D:
	return build_asset_stage(asset_for_age(age_years, start_harvest_age))

## Tinggi (m) model dedicated, dipakai utk framing kamera / tinggi pohon hero
## (mis. skala galah egrek saat animasi panen). Di-cache per path.
static func asset_height(path: String) -> float:
	if not _asset_height_cache.has(path):
		var ps := _load_asset(path)
		var h := 0.0
		if ps:
			var inst := ps.instantiate()
			h = _local_aabb(inst).size.y
			inst.free()
		_asset_height_cache[path] = h
	return _asset_height_cache[path]

static func _load_asset(path: String) -> PackedScene:
	if not _asset_cache.has(path):
		_asset_cache[path] = load(path)
	return _asset_cache[path]

static func _ground(inst: Node3D) -> Node3D:
	var aabb := _local_aabb(inst)
	inst.position.y -= aabb.position.y
	return inst

static func _scene() -> PackedScene:
	if _cached == null:
		_cached = load(PALM_SCENE)
	return _cached

## Tinggi pokok TM tua (formula asli, dipakai juga sbg acuan separuh utk TM remaja).
static func _tm_tua_height(age_years: float) -> float:
	return lerp(5.0, 9.0, clampf((age_years - 3.0) / 10.0, 0.0, 1.0))

## Bangun tampilan sawit sesuai tahap umur (dipakai RantaiPascapanen & bisa
## menggantikan pemanggilan build() langsung di tempat lain yang butuh kondisi ini).
static func build_staged(stage: int, age_years: float = 0.0) -> Node3D:
	match stage:
		Stage.TB0:
			return _build_seedling()
		Stage.TBM:
			var h: float = lerp(0.3, 1.125, clampf(age_years / 3.0, 0.0, 1.0))
			return build(h, false)
		Stage.TM_BARU:
			var h: float = lerp(1.6, 2.4, clampf((age_years - 4.0) / 4.0, 0.0, 1.0))
			return build(h, true)
		Stage.TM_REMAJA:
			return build(_tm_tua_height(age_years) * 0.5, true)
		_:
			return build(_tm_tua_height(age_years), true)

## Bibit baru tanam (TB-0): model polybag/kecambah asli, dinormalisasi ~0,5 m.
## .obj diimpor sebagai Mesh polos (bukan scene) -> bungkus manual di MeshInstance3D.
static func _build_seedling() -> Node3D:
	if _seedling_cached == null:
		_seedling_cached = load(SEEDLING_SCENE)
	var root := Node3D.new()
	if _seedling_cached:
		var mi := MeshInstance3D.new()
		mi.mesh = _seedling_cached
		root.add_child(_fit(mi, 0.5))
	return root

## Bangun satu pohon sawit setinggi `height` (m). fruit=false utk pohon muda/tanpa buah.
static func build(height: float, fruit: bool = true) -> Node3D:
	var node := Node3D.new()
	var trunk_h: float = height * 0.62
	var crown_h: float = height * 0.45

	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = height * 0.028
	cyl.bottom_radius = height * 0.043
	cyl.height = trunk_h
	cyl.radial_segments = 8
	trunk.mesh = cyl
	var tm := StandardMaterial3D.new(); tm.albedo_color = TRUNK_COLOR
	trunk.material_override = tm
	trunk.position.y = trunk_h * 0.5
	node.add_child(trunk)

	var ps := _scene()
	if ps:
		var crown := _fit(ps.instantiate(), crown_h)
		crown.position.y += trunk_h - crown_h * 0.15
		crown.rotate_y(randf() * TAU)
		node.add_child(crown)

	if fruit:
		# Titik tempel pas di luar permukaan batang (bukan jauh di tepi mahkota, biar
		# tak "melayang" -- dan bukan di sumbu tengah batang, biar tak "ketanam").
		var attach_r := height * 0.06
		for i in 2:
			var ang := randf() * TAU
			var fb := TBSBuilder.build(height * 0.16, true)
			# TBSBuilder sudah menggantung ke -Y dari origin-nya sendiri; di sini cuma
			# diputar menghadap arah radial lalu dicondongkan menjauhi batang.
			fb.position = Vector3(cos(ang) * attach_r, trunk_h - height * 0.03, sin(ang) * attach_r)
			fb.rotate_y(ang)
			fb.rotate_object_local(Vector3.RIGHT, deg_to_rad(20))
			node.add_child(fb)
	return node

# --- skala via AABB (static) ---
static func _fit(inst: Node3D, target_h: float) -> Node3D:
	var aabb := _local_aabb(inst)
	if target_h > 0.0 and aabb.size.y > 0.0001:
		var s: float = target_h / aabb.size.y
		inst.scale = Vector3(s, s, s)
		inst.position.y = -aabb.position.y * s
	return inst

static func _local_aabb(inst: Node) -> AABB:
	var aabb := AABB(); var first := true
	for m in _meshes(inst):
		var a: AABB = _rel_xform(inst, m) * m.mesh.get_aabb()
		if first: aabb = a; first = false
		else: aabb = aabb.merge(a)
	return aabb

static func _rel_xform(root: Node, node: Node3D) -> Transform3D:
	var t := Transform3D(); var n: Node = node
	while n != null and n != root:
		if n is Node3D: t = (n as Node3D).transform * t
		n = n.get_parent()
	return t

static func _meshes(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append(node)
	for c in node.get_children():
		out.append_array(_meshes(c))
	return out
