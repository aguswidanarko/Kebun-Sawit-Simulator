class_name PemanenBuilder
extends RefCounted
## Pekerja panen prosedural: rig primitif sederhana (tanpa skeleton) + pivot tangan
## untuk memegang alat (egrek.obj / dodos). Gaya konsisten dengan PalmBuilder —
## semua mesh Godot bawaan, aman lisensi, murah render.

const SHIRT_COL := Color(0.22, 0.38, 0.62)   # kemeja biru spt foto referensi pemanen
const PANTS_COL := Color(0.20, 0.19, 0.17)
const SKIN_COL := Color(0.72, 0.55, 0.40)
const HELM_COL := Color(0.15, 0.45, 0.85)    # helm APD biru

const EGREK_SCENE := "res://assets/models/tools/egrek.obj"

## Bangun satu pekerja setinggi `h` (m). Pivot tangan tersimpan di meta "hand_pivot"
## (putar rotation_degrees.x pivot ini untuk animasi "mengangkat alat"). Badan
## atas (dada/kepala/helm/tangan) dikelompokkan di bawah meta "torso" — sebuah
## Node3D dgn pivot kira-kira di pinggang (y=h*0.40) — supaya posisi badan bisa
## dicondongkan ke depan (mis. "menunduk" saat menombak dgn dodos) tanpa
## mengubah posisi kaki.
static func build(h: float = 1.65) -> Node3D:
	var root := Node3D.new()

	var legs := MeshInstance3D.new()
	var lc := CapsuleMesh.new()
	lc.radius = h * 0.09
	lc.height = h * 0.46
	lc.material = _mat(PANTS_COL)
	legs.mesh = lc
	legs.position.y = h * 0.23
	root.add_child(legs)

	var torso := Node3D.new()
	torso.name = "Torso"
	var hip_y := h * 0.40
	torso.position.y = hip_y
	root.add_child(torso)

	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = h * 0.115
	cap.height = h * 0.58
	cap.material = _mat(SHIRT_COL)
	body.mesh = cap
	body.position.y = h * 0.62 - hip_y
	torso.add_child(body)

	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = h * 0.075
	sph.height = h * 0.15
	sph.material = _mat(SKIN_COL)
	head.mesh = sph
	head.position.y = h * 0.90 - hip_y
	torso.add_child(head)

	var helm := MeshInstance3D.new()
	var hcap := SphereMesh.new()
	hcap.radius = h * 0.088
	hcap.height = h * 0.10
	hcap.is_hemisphere = true
	hcap.material = _mat(HELM_COL)
	helm.mesh = hcap
	helm.position.y = h * 0.955 - hip_y
	torso.add_child(helm)

	# Pivot bahu kanan -> titik pegang alat. Posisi istirahat miring ke bawah.
	var pivot := Node3D.new()
	pivot.name = "HandPivot"
	pivot.position = Vector3(h * 0.14, h * 0.70 - hip_y, h * 0.04)
	pivot.rotation_degrees = Vector3(-25, 0, 0)
	torso.add_child(pivot)
	root.set_meta("hand_pivot", pivot)
	root.set_meta("torso", torso)
	return root

## Pasang egrek.obj ke `pivot`, dinormalisasi sepanjang `pole_len` (m), menjulur
## ke depan-atas dari pegangan. Kembalikan node instance (sudah jadi anak pivot).
## .obj diimpor sebagai Mesh polos (bukan scene) -> bungkus manual di MeshInstance3D.
static var _egrek_cached: Mesh
static func attach_egrek(pivot: Node3D, pole_len: float) -> Node3D:
	if _egrek_cached == null:
		_egrek_cached = load(EGREK_SCENE)
	if _egrek_cached == null:
		return null
	var inst := MeshInstance3D.new()
	inst.mesh = _egrek_cached
	var aabb := _local_aabb(inst)
	var longest: float = max(aabb.size.x, max(aabb.size.y, aabb.size.z))
	if longest > 0.0001:
		var s := pole_len / longest
		inst.scale = Vector3(s, s, s)
	# Pangkal galah di tangan; galah menjulur sepanjang -Z lokal pivot (depan).
	inst.position = Vector3(0, 0, 0)
	inst.rotation_degrees = Vector3(70, 0, 0)
	pivot.add_child(inst)
	return inst

static func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.85
	return m

# --- util AABB (duplikat kecil, sama polanya dgn PalmBuilder) ---
static func _local_aabb(inst: Node) -> AABB:
	var aabb := AABB()
	var first := true
	for m in _meshes(inst):
		var a: AABB = _rel_xform(inst, m) * m.mesh.get_aabb()
		if first: aabb = a; first = false
		else: aabb = aabb.merge(a)
	return aabb

static func _rel_xform(root: Node, node: Node3D) -> Transform3D:
	var t := Transform3D()
	var n: Node = node
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
