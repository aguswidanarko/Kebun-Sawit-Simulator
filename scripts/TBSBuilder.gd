class_name TBSBuilder
extends RefCounted
## Tandan Buah Segar (TBS) prosedural: tangkai (rachis) + spikelet buah radial
## membentuk ovoid, dipakai di mahkota pohon (PalmBuilder), TBS jatuh saat panen,
## dan tumpukan di TPH/truk (RantaiPascapanen). Semua primitif Godot -> aman lisensi.

const RIPE_COL := Color(0.62, 0.14, 0.05)
const UNRIPE_COL := Color(0.35, 0.42, 0.14)
const STALK_COL := Color(0.30, 0.22, 0.12)

## Satu TBS setinggi `size` (m). ripe=false -> hijau (belum matang, dipajang saja).
## Origin (0,0,0) node = TITIK TEMPEL di pangkal pelepah/batang; tangkai & rumpun
## buah SAMA-SAMA menjulur ke -Y dari situ (nyambung, bukan dua potongan terpisah).
static func build(size: float, ripe: bool = true) -> Node3D:
	var b := Node3D.new()

	var stalk_h := size * 0.35
	var stalk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = size * 0.07
	cyl.bottom_radius = size * 0.10
	cyl.height = stalk_h
	cyl.radial_segments = 6
	cyl.material = _mat(STALK_COL, 1.0)
	stalk.mesh = cyl
	stalk.position.y = -stalk_h * 0.5   # menggantung dari titik tempel ke bawah
	b.add_child(stalk)

	var fruit_mat := _mat(RIPE_COL if ripe else UNRIPE_COL, 0.55)
	var fruit_mesh := SphereMesh.new()
	fruit_mesh.radius = size * 0.09
	fruit_mesh.height = size * 0.2
	fruit_mesh.material = fruit_mat

	var cluster_len := size * 0.8
	var n := 40
	for i in n:
		var t := float(i) / float(n)
		var along: float = -stalk_h - t * cluster_len   # lanjutan tangkai, terus ke bawah
		var ang := t * TAU * 6.0
		var rad: float = size * 0.22 * sin(t * PI)  # profil ovoid: tipis ujung, lebar tengah
		var f := MeshInstance3D.new()
		f.mesh = fruit_mesh
		f.position = Vector3(cos(ang) * rad, along, sin(ang) * rad)
		f.scale = Vector3.ONE * randf_range(0.82, 1.18)
		b.add_child(f)
	return b

## Ledakan brondolan (butiran lepas) di titik jatuh TBS -> MultiMesh, ringan.
static func brondolan_burst(parent: Node3D, origin: Vector3, count: int = 14) -> MultiMeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = 0.045
	sm.height = 0.09
	sm.material = _mat(RIPE_COL, 0.5)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sm
	mm.instance_count = count
	for i in count:
		var ang := randf() * TAU
		var r := randf_range(0.12, 0.6)
		var p := origin + Vector3(cos(ang) * r, 0.03, sin(ang) * r)
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, randf() * TAU), p))

	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

## Tumpukan TBS prosedural (TPH / bak truk) — n buah disusun random di area persegi.
static func pile(parent: Node3D, center: Vector3, count: int, spread: float, size: float) -> void:
	for i in count:
		var tbs := build(size * randf_range(0.85, 1.1), true)
		var off := Vector3(randf_range(-spread, spread), 0.0, randf_range(-spread, spread))
		tbs.position = center + off
		tbs.position.y = size * 0.18 + randf_range(0.0, size * 0.15)
		tbs.rotation = Vector3(randf_range(-0.3, 0.3), randf() * TAU, randf_range(-0.3, 0.3))
		parent.add_child(tbs)

static func _mat(col: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	return m
