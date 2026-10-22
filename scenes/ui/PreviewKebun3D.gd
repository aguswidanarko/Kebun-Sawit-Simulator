extends Node3D
## Preview 3D "kebun jadinya" berdasarkan pilihan cerita (GameState.story_flags).
## Kamera orbit yang bisa dieksplor (dipanggil dari overlay: orbit()/zoom()).
##
## VARIAN LAHAN (ikut lahan_id yang dipilih di pasar lahan cerita):
##  h_sungai  (S2) -> hutan sedang + aliran sungai di satu sisi
##  h_dataran (S1) -> hutan rapat pohon besar (pembukaan berat)
##  h_rawa    (S3) -> pohon jarang + genangan air, tanah basah gelap
##  b_s1           -> lahan bersih prima: rata + ajir/patok tanam rapi
##  b_s2           -> lahan bersih standar: rata + sisa tunggul & batu
##  b_eks          -> eks-kebun: sawit tua tinggi tak seragam + jalan rintis
## Jalur "pembibitan" -> bedengan bibit ditambahkan di sudut depan lahan terpilih.

const TREE := "res://assets/models/nature/CommonTree_1.gltf"
const GRASS := "res://assets/models/nature/Grass_Common_Tall.gltf"

var _cam: Camera3D
var _yaw := 0.7
var _pitch := 0.55
var _distance := 42.0
var _center := Vector3.ZERO
var _auto := true
var _tree: PackedScene

func _ready() -> void:
	_build_env()
	_tree = load(TREE)
	var flags: Dictionary = GameState.story_flags
	var jalur := String(flags.get("jalur", "kebun"))
	var tipe := String(flags.get("tipe_lahan", "bersih"))
	var lahan := String(flags.get("lahan_id", ""))
	match lahan:
		"h_sungai": _build_forest_river()
		"h_dataran": _build_forest_dense()
		"h_rawa": _build_swamp()
		"b_s1": _build_clear_prime()
		"b_s2": _build_clear_standard()
		"b_eks": _build_old_estate()
		_:
			# fallback lama (belum pilih lahan / flags tak lengkap)
			if tipe == "hutan":
				_build_forest_dense()
			else:
				_build_clear_prime()
	if jalur == "pembibitan":
		_add_nursery_beds()
	_cam = Camera3D.new()
	_cam.fov = 60.0
	add_child(_cam)
	_update_cam()

func _process(delta: float) -> void:
	if _auto:
		_yaw += delta * 0.15
		_update_cam()

# ---------------------------------------------------------------- kontrol kamera (dipanggil overlay)
func orbit(dx: float, dy: float) -> void:
	_auto = false
	_yaw -= dx * 0.01
	_pitch = clampf(_pitch - dy * 0.01, 0.12, 1.35)
	_update_cam()

func zoom(factor: float) -> void:
	_distance = clampf(_distance * factor, 10.0, 90.0)
	_update_cam()

func _update_cam() -> void:
	if _cam == null: return
	var c := cos(_pitch)
	_cam.position = _center + Vector3(cos(_yaw) * c, sin(_pitch), sin(_yaw) * c) * _distance
	_cam.look_at(_center + Vector3(0, 2.0, 0), Vector3.UP)

# ---------------------------------------------------------------- dunia
func _build_env() -> void:
	# Tanpa awan mesh: ini widget preview di dalam UI, awan prosedural sudah
	# cukup dan 9 mesh tambahan memberatkan HP kelas bawah.
	SkyKit.build_env(self, Vector3(-46, -40, 0), 0.0015, false)

func _ground(col: Color, size: float = 200.0) -> void:
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(size, size)
	g.mesh = pm
	var m := StandardMaterial3D.new(); m.albedo_color = col
	g.material_override = m
	add_child(g)

## Bidang air datar (sungai/genangan).
func _water(pos: Vector3, size: Vector2) -> void:
	var w := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = size
	w.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.22, 0.38, 0.50, 0.92)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.4; m.roughness = 0.1
	w.material_override = m
	w.position = pos + Vector3(0, 0.05, 0)
	add_child(w)

## Tunggul pohon (sisa tebangan).
func _stump(pos: Vector3) -> void:
	var s := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.28; cm.bottom_radius = 0.38; cm.height = 0.7
	s.mesh = cm
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.38, 0.28, 0.18)
	s.material_override = m
	s.position = pos + Vector3(0, 0.35, 0)
	add_child(s)

## Batu kecil.
func _rock(pos: Vector3) -> void:
	var r := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.45; sm.height = 0.5
	r.mesh = sm
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.52, 0.51, 0.48)
	r.material_override = m
	r.position = pos + Vector3(0, 0.18, 0)
	r.rotate_y(randf() * TAU)
	add_child(r)

## Ajir / patok tanam (lahan prima siap tanam).
func _stake(pos: Vector3) -> void:
	var s := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.035; cm.bottom_radius = 0.035; cm.height = 1.1
	s.mesh = cm
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.85, 0.75, 0.45)
	s.material_override = m
	s.position = pos + Vector3(0, 0.55, 0)
	add_child(s)

func _forest_tree(pos: Vector3, h: float) -> void:
	if _tree == null: return
	var t := _fit(_tree.instantiate(), h)
	t.position = pos
	t.rotate_y(randf() * TAU)
	add_child(t)

func _set_focus(cols: int, rows: int, sp: float, dist: float, pitch: float) -> void:
	_center = Vector3((cols - 1) * sp * 0.5, 0, (rows - 1) * sp * 0.5)
	_distance = dist; _pitch = pitch

# ---------------------------------------------------------------- VARIAN LAHAN
## h_sungai (S2): hutan sedang, sungai mengalir di sisi timur.
func _build_forest_river() -> void:
	_ground(Color(0.26, 0.36, 0.19))
	var cols := 7; var rows := 8; var sp := 4.8
	_set_focus(cols, rows, sp, 48.0, 0.45)
	for r in rows:
		for c in cols:
			_forest_tree(Vector3(c * sp + randf_range(-1, 1), 0, r * sp + randf_range(-1, 1)), randf_range(5.5, 7.5))
	# sungai: jalur air memanjang di sisi timur grid
	_water(Vector3(cols * sp + 4.0, 0, (rows - 1) * sp * 0.5), Vector2(7.0, rows * sp + 20.0))

## h_dataran (S1): hutan rapat pohon besar — pembukaan berat.
func _build_forest_dense() -> void:
	_ground(Color(0.28, 0.38, 0.20))
	var cols := 9; var rows := 9; var sp := 3.8
	_set_focus(cols, rows, sp, 50.0, 0.45)
	for r in rows:
		for c in cols:
			_forest_tree(Vector3(c * sp + randf_range(-1.2, 1.2), 0, r * sp + randf_range(-1.2, 1.2)), randf_range(7.0, 9.5))

## h_rawa (S3): pohon jarang + genangan, tanah basah gelap.
func _build_swamp() -> void:
	_ground(Color(0.20, 0.26, 0.16))
	var cols := 7; var rows := 7; var sp := 5.4
	_set_focus(cols, rows, sp, 48.0, 0.45)
	for r in rows:
		for c in cols:
			if randf() < 0.45:   # jarang
				_forest_tree(Vector3(c * sp + randf_range(-1.5, 1.5), 0, r * sp + randf_range(-1.5, 1.5)), randf_range(4.5, 6.5))
	# genangan air tersebar
	for i in 7:
		_water(Vector3(randf_range(0, cols * sp), 0, randf_range(0, rows * sp)),
			Vector2(randf_range(4.0, 9.0), randf_range(3.0, 6.0)))

## b_s1: lahan bersih prima — rata, bersih, ajir tanam rapi.
func _build_clear_prime() -> void:
	_ground(Color(0.45, 0.38, 0.26))
	var cols := 7; var rows := 7; var sp := 5.2
	_set_focus(cols, rows, sp, 42.0, 0.5)
	for r in rows:
		for c in cols:
			_stake(Vector3(c * sp, 0, r * sp))

## b_s2: lahan bersih standar — rata dengan sisa tunggul & batu.
func _build_clear_standard() -> void:
	_ground(Color(0.42, 0.36, 0.25))
	var cols := 7; var rows := 7; var sp := 5.2
	_set_focus(cols, rows, sp, 42.0, 0.5)
	for i in 10:
		_stump(Vector3(randf_range(0, cols * sp), 0, randf_range(0, rows * sp)))
	for i in 8:
		_rock(Vector3(randf_range(0, cols * sp), 0, randf_range(0, rows * sp)))

## b_eks: eks-kebun — sawit tua tinggi tak seragam + jalan rintis tanah.
func _build_old_estate() -> void:
	_ground(Color(0.34, 0.43, 0.22))
	var cols := 7; var rows := 7; var sp := 5.2
	_set_focus(cols, rows, sp, 46.0, 0.5)
	for r in rows:
		for c in cols:
			if randf() < 0.9:   # ada beberapa titik kosong (pohon mati)
				var p := PalmBuilder.build_asset_stage(PalmBuilder.ASSET_TM_TUA)
				var s := randf_range(0.82, 1.15)   # "tinggi tak seragam"
				p.scale = Vector3(s, s, s)
				p.position = Vector3(c * sp + randf_range(-0.6, 0.6), 0, r * sp + randf_range(-0.6, 0.6))
				add_child(p)
	# jalan rintis membelah kebun
	var road := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(3.0, rows * sp + 14.0)
	road.mesh = pm
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.48, 0.40, 0.30)
	road.material_override = m
	road.position = Vector3((cols - 1) * sp * 0.5, 0.03, (rows - 1) * sp * 0.5)
	add_child(road)

## Jalur pembibitan: bedengan bibit polibag di sudut depan lahan terpilih.
func _add_nursery_beds() -> void:
	var ox := -16.0; var oz := -4.0   # sudut depan, di luar grid lahan
	# bedengan tanah
	var bed := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(14.0, 0.3, 9.0)
	bed.mesh = bm
	var mm := StandardMaterial3D.new(); mm.albedo_color = Color(0.40, 0.31, 0.21)
	bed.material_override = mm
	bed.position = Vector3(ox + 6.0, 0.15, oz + 4.0)
	add_child(bed)
	for r in 4:
		for c in 7:
			var seedling := PalmBuilder.build_asset_stage(PalmBuilder.ASSET_PN_2BLN)
			seedling.position = Vector3(ox + 1.0 + c * 2.0, 0.3, oz + 1.0 + r * 2.0)
			seedling.rotate_y(randf() * TAU)
			add_child(seedling)

# ---------------------------------------------------------------- util skala (AABB)
func _fit(inst: Node3D, target_h: float) -> Node3D:
	var aabb := _local_aabb(inst)
	if target_h > 0.0 and aabb.size.y > 0.0001:
		var s: float = target_h / aabb.size.y
		inst.scale = Vector3(s, s, s)
		inst.position.y = -aabb.position.y * s
	return inst

func _local_aabb(inst: Node) -> AABB:
	var aabb := AABB(); var first := true
	for m in _meshes(inst):
		var a: AABB = _rel_xform(inst, m) * m.mesh.get_aabb()
		if first: aabb = a; first = false
		else: aabb = aabb.merge(a)
	return aabb

func _rel_xform(root: Node, node: Node3D) -> Transform3D:
	var t := Transform3D(); var n: Node = node
	while n != null and n != root:
		if n is Node3D: t = (n as Node3D).transform * t
		n = n.get_parent()
	return t

func _meshes(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append(node)
	for c in node.get_children():
		out.append_array(_meshes(c))
	return out
