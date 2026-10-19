class_name ForestBeltBuilder
extends RefCounted
## Sabuk hutan/semak belukar pembatas area jelajah — satu aset artis tunggal
## (res://assets/models/environment/sabuk-hutan.glb, dari "Asset kelapa sawit")
## dipakai di semua scene kebun 3D (FarmWorld3D, Plantation3D) agar konsisten.
## Struktur node dalam model: tanah_blok/jalur (lantai+jalan setapak),
## kebun_sawit (placeholder sawit bawaan model — disembunyikan bila scene sudah
## render sawitnya sendiri lewat PalmBuilder), sabuk_belukar (semak/pakis/jamur/
## batu tempat item hasil hutan muncul), dinding_hutan (pagar pohon rapat =
## batas jelajah), marker_item (mesh penanda, dipakai ulang utk loot spawn).

const SCENE_PATH := "res://assets/models/environment/sabuk-hutan.glb"
const PLACEHOLDER_SAWIT := "kebun_sawit"
const MARKER_NODE := "marker_item_marker_item"

## Model diautori utk blok 1 ha (radius jelajah 50 m). Blok lain -> diskalakan.
const BASE_RADIUS_M := 50.0

static var _cached_scene: PackedScene
static var _marker_mesh: Mesh
static var _marker_mat: Material
static var _marker_ready := false

## Radius (m) area jelajah utk luas blok `area_ha` (1 ha = 100x100 m persegi,
## lihat spek: "1 blok/1 ha -> area jelajah 100x100 m").
static func radius_m(area_ha: float) -> float:
	return BASE_RADIUS_M * sqrt(max(area_ha, 0.01))

## Pasang sabuk hutan berpusat di `center` (posisi dunia), diskalakan sesuai
## `area_ha`. `hide_kebun_sawit`: true utk scene yang sudah render sawitnya
## sendiri lewat PalmBuilder (FarmWorld3D/Plantation3D) agar tak dobel.
static func build(parent: Node3D, center: Vector3, area_ha: float, hide_kebun_sawit := true) -> Node3D:
	var ps := _scene()
	if ps == null:
		return null
	var inst: Node3D = ps.instantiate()
	parent.add_child(inst)
	inst.position = center
	var s := sqrt(max(area_ha, 0.01))
	inst.scale = Vector3(s, s, s)
	if hide_kebun_sawit:
		var ph := _find_by_name(inst, PLACEHOLDER_SAWIT)
		if ph is Node3D:
			(ph as Node3D).visible = false
	return inst

## Mesh bawaan model utk penanda item hasil hutan (dipakai FarmWorld3D saat
## memunculkan loot di sabuk_belukar). Diambil sekali & di-cache.
static func marker_mesh() -> Mesh:
	_ensure_marker()
	return _marker_mesh

static func marker_material() -> Material:
	_ensure_marker()
	return _marker_mat

static func _ensure_marker() -> void:
	if _marker_ready:
		return
	_marker_ready = true
	var ps := _scene()
	if ps == null:
		return
	var inst := ps.instantiate()
	var n := _find_by_name(inst, MARKER_NODE)
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		_marker_mesh = mi.mesh
		if mi.mesh and mi.mesh.get_surface_count() > 0:
			_marker_mat = mi.get_active_material(0)
	inst.free()

static func _scene() -> PackedScene:
	if _cached_scene == null and ResourceLoader.exists(SCENE_PATH):
		_cached_scene = load(SCENE_PATH)
	return _cached_scene

static func _find_by_name(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	for c in node.get_children():
		var r := _find_by_name(c, name)
		if r:
			return r
	return null
