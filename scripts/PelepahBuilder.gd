class_name PelepahBuilder
extends RefCounted
## Susunan pelepah prosedural — BMP Region Riau "Penyusunan Pelepah":
##  - Pelepah dipotong 3 bagian, disusun di gawangan mati membentuk pola U/tangga
##    (areal datar) atau mengikuti kontur dinding teras (areal terasan).
##  - Diberi PATOK penahan di ujung tiap susunan.
##  - Piringan (r 2,5 m), pasar pikul, dan pasar rintis tetap bersih.
## Render memakai MultiMesh (1 draw call per jenis mesh) agar ringan.
## Nanti mesh prosedural tinggal diganti glb artist tanpa mengubah generator.

const STALK_COL := Color(0.55, 0.44, 0.29)   # tangkai pelepah kering
const MOUND_COL := Color(0.40, 0.31, 0.19)   # hamparan anak daun kering
const PATOK_COL := Color(0.47, 0.35, 0.21)

## bars: Array berisi {"from": Vector3, "to": Vector3} — garis susunan pelepah.
## Menambahkan 2 MultiMeshInstance3D (tangkai + gundukan daun) dan patok ke parent.
static func build(parent: Node3D, bars: Array) -> void:
	var stalks: Array = []
	var mounds: Array = []
	for bar in bars:
		var a: Vector3 = bar["from"]
		var b: Vector3 = bar["to"]
		var seg := b - a
		var length := seg.length()
		if length < 0.6:
			continue
		var dir := seg / length
		var yaw := atan2(dir.x, dir.z)

		# Gundukan anak daun kering (alas rumpukan)
		var step_m := 1.4
		for i in int(length / step_m):
			var p := a + dir * (step_m * (float(i) + 0.5))
			var mb := Basis(Vector3.UP, yaw + randf_range(-0.1, 0.1))
			mb = mb.scaled(Vector3(randf_range(0.85, 1.1), 1.0, randf_range(0.85, 1.15)))
			mounds.append(Transform3D(mb, p + Vector3(randf_range(-0.1, 0.1), 0.07, randf_range(-0.1, 0.1))))

		# Tangkai pelepah "potongan 3" (segmen ±1,6 m), 2 lapis tumpukan
		var step := 0.45
		for i in int(length / step):
			var p2 := a + dir * (step * (float(i) + 0.5))
			for layer in 2:
				if layer == 1 and randf() < 0.45:
					continue   # lapis atas lebih jarang
				var basis := Basis(Vector3.UP, yaw + randf_range(-0.22, 0.22)) \
					* Basis(Vector3.RIGHT, PI * 0.5 + randf_range(-0.07, 0.07))
				var off := Vector3(randf_range(-0.18, 0.18), 0.09 + 0.10 * float(layer), randf_range(-0.18, 0.18))
				stalks.append(Transform3D(basis, p2 + off))

		# Patok penahan di kedua ujung susunan (BMP: "di kasih patok")
		parent.add_child(_patok(a))
		parent.add_child(_patok(b))

	parent.add_child(_mmi(_stalk_mesh(), stalks))
	parent.add_child(_mmi(_mound_mesh(), mounds))

## Tata letak AREAL DATAR (diagram BMP): bar utama memanjang di gawangan mati
## (sela kolom berselang-seling, sisi lain = pasar pikul bersih), terputus di
## pasar rintis tiap `rintis_rows` baris, + "anak tangga" U antar pokok dalam barisan.
static func layout_flat(cols: int, rows: int, spacing: float, rintis_rows := 4) -> Array:
	var bars: Array = []
	var z0 := -1.5
	var z1 := (float(rows) - 1.0) * spacing + 1.5
	var c := 0
	while c < cols - 1:
		var x := (float(c) + 0.5) * spacing
		# bar utama (terputus di pasar rintis)
		var z := z0
		var run := float(rintis_rows) * spacing - 2.4
		while z < z1:
			var zend: float = min(z + run, z1)
			bars.append({ "from": Vector3(x, 0, z), "to": Vector3(x, 0, zend) })
			z = zend + 2.4
		# sisi U: bar pendek melintang di tengah antar pokok (menjauhi piringan)
		for r in rows - 1:
			var zm := (float(r) + 0.5) * spacing
			bars.append({ "from": Vector3(x - 1.7, 0, zm), "to": Vector3(x + 1.7, 0, zm) })
		c += 2   # selang-seling: sela berikutnya = pasar pikul (bersih)
	return bars

# ---------------------------------------------------------------- mesh prosedural
static func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 1.0
	return m

static func _stalk_mesh() -> Mesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.025
	m.bottom_radius = 0.055
	m.height = 1.6
	m.radial_segments = 5
	m.rings = 1
	m.material = _mat(STALK_COL)
	return m

static func _mound_mesh() -> Mesh:
	var m := BoxMesh.new()
	m.size = Vector3(0.9, 0.15, 1.6)
	m.material = _mat(MOUND_COL)
	return m

static func _mmi(mesh: Mesh, xforms: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # ringan
	return mi

static func _patok(pos: Vector3) -> MeshInstance3D:
	var p := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.03
	cm.bottom_radius = 0.04
	cm.height = 1.0
	cm.radial_segments = 5
	cm.material = _mat(PATOK_COL)
	p.mesh = cm
	p.position = pos + Vector3(0, 0.5, 0)
	p.rotation = Vector3(randf_range(-0.06, 0.06), 0, randf_range(-0.06, 0.06))
	return p
