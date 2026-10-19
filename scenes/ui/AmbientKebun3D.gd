extends Node3D
## Latar belakang 3D: HAMPARAN kebun sawit luas berbaris — aset dedicated sawit
## tua "Asset kelapa sawit" (PalmBuilder.ASSET_TM_TUA) dipakai apa adanya lewat
## PalmBuilder.build_asset_stage(). Kamera sudut sedang mengorbit pelan (membentang ke horizon).

const GRASS := "res://assets/models/nature/Grass_Common_Tall.gltf"

const COLS := 9
const ROWS := 12
const SPACING := 6.0

var _cam: Camera3D
var _t := 0.0
var _center := Vector3((COLS - 1) * SPACING * 0.5, 0, (ROWS - 1) * SPACING * 0.5)

func _ready() -> void:
	# Lingkungan + langit dengan horizon & kabut tipis
	SkyKit.build_env(self, Vector3(-45, -42, 0), 0.0016)

	# Tanah luas
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(400, 400)
	ground.mesh = pm
	var gm := SkyKit.ground_material()
	gm.uv1_scale = Vector3(40, 40, 1)
	ground.material_override = gm
	add_child(ground)

	# Jalan tanah di tepi kebun
	var road := MeshInstance3D.new()
	var rm := PlaneMesh.new(); rm.size = Vector2(4.5, ROWS * SPACING + 16)
	road.mesh = rm
	road.position = Vector3(-SPACING, 0.02, _center.z)
	var rmat := StandardMaterial3D.new(); rmat.albedo_color = Color(0.55, 0.44, 0.31)
	road.material_override = rmat
	add_child(road)

	# Hamparan sawit berbaris
	for r in ROWS:
		for c in COLS:
			var palm := _make_palm()
			palm.position = Vector3(c * SPACING, 0, r * SPACING)
			add_child(palm)

	# Rumput undergrowth di sela barisan
	var grass := load(GRASS)
	if grass:
		for i in 70:
			var g := _fit(grass.instantiate(), 0.5)
			g.position = Vector3(randf_range(0, (COLS - 1) * SPACING), 0, randf_range(0, (ROWS - 1) * SPACING))
			g.rotate_y(randf() * TAU)
			add_child(g)

	_cam = Camera3D.new()
	_cam.fov = 62.0
	add_child(_cam)
	_update_cam()

func _make_palm() -> Node3D:
	var node := PalmBuilder.build_asset_stage(PalmBuilder.ASSET_TM_TUA)
	node.rotate_y(randf() * TAU)
	return node

func _process(delta: float) -> void:
	_t += delta * 0.04
	_update_cam()

func _update_cam() -> void:
	if _cam == null: return
	# Sudut sedang, jauh -> barisan sawit membentang ke horizon + langit di atas.
	var radius := 62.0
	_cam.position = _center + Vector3(cos(_t) * radius, 22.0, sin(_t) * radius)
	_cam.look_at(_center + Vector3(0, 4.0, 0), Vector3.UP)

# --- Normalisasi skala via AABB (model beda sumber) ---
func _fit(inst: Node3D, target_h: float) -> Node3D:
	var aabb := _local_aabb(inst)
	if target_h > 0.0 and aabb.size.y > 0.0001:
		var s := target_h / aabb.size.y
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
