class_name CloudField
extends Node3D
## Awan 3D dari model .glb (folder "Awan" lampiran Catatan Perbaikan).
##
## Sebelumnya awan HANYA prosedural di sky shader (FBM noise) sehingga terlihat
## rata dan tidak berdimensi. Sekarang awan asli = mesh yang hanyut perlahan di
## atas kebun; shader langit tetap dipakai sebagai lapisan tipis latar belakang
## (SkyKit menurunkan cloud_coverage-nya supaya tidak dobel).
##
## Dipakai lewat SkyKit.build_env(parent) — tidak perlu dipanggil manual.

const MODELS := [
	"res://assets/models/clouds/awan_cumulus_humilis.glb",
	"res://assets/models/clouds/awan_cumulus_mediocris.glb",
	"res://assets/models/clouds/awan_cumulus_congestus.glb",
	"res://assets/models/clouds/awan_stratocumulus.glb",
	"res://assets/models/clouds/awan_awan_mendung.glb",
]

## Model mendung hanya dipakai saat cuaca hujan (indeks terakhir MODELS).
const RAIN_MODEL_IDX := 4

@export var count: int = 9
@export var height: float = 68.0        # tinggi rata-rata awan di atas tanah
@export var drift_speed: float = 1.4    # m/detik, arah +X
@export var target_width: float = 46.0  # lebar satu awan setelah dinormalkan

## Sebaran dipisah per sumbu + punya titik pusat, karena tidak semua dunia
## berpusat di origin: RantaiPascapanen misalnya memanjang di sumbu Z dan
## bergeser di X, sehingga awan yang selalu disebar di sekitar (0,0) tidak
## pernah terlihat kamera.
@export var spread_x: float = 190.0
@export var spread_z: float = 190.0
@export var center: Vector3 = Vector3.ZERO

var _clouds: Array[Node3D] = []
var _min_x: float = 0.0
var _max_x: float = 0.0

## Atur area sebaran dari ukuran dunia. Panggil SEBELUM node masuk tree.
func configure(world_center: Vector3, size_x: float, size_z: float, n := 0) -> void:
	center = Vector3(world_center.x, 0.0, world_center.z)
	# Diberi marjin supaya awan tetap ada di luar tepi dunia (terlihat saat
	# kamera menengok ke horizon).
	spread_x = size_x + 160.0
	spread_z = size_z + 160.0
	if n > 0:
		count = n

func _ready() -> void:
	var half_x := spread_x * 0.5
	var half_z := spread_z * 0.5
	_min_x = center.x - half_x
	_max_x = center.x + half_x
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# Cuaca mendung/hujan -> boleh pakai model awan mendung, cerah -> jangan.
	var allow_rain := _is_overcast()
	var pool: Array = []
	for i in MODELS.size():
		if i == RAIN_MODEL_IDX and not allow_rain:
			continue
		if ResourceLoader.exists(MODELS[i]):
			pool.append(MODELS[i])
	if pool.is_empty():
		return

	# Cache per path: satu PackedScene dipakai berkali-kali (hemat memori).
	var cache := {}
	for i in count:
		var path: String = pool[rng.randi_range(0, pool.size() - 1)]
		if not cache.has(path):
			cache[path] = load(path)
		var ps: PackedScene = cache[path]
		if ps == null:
			continue
		var inst: Node3D = ps.instantiate()
		add_child(inst)
		_normalize(inst, target_width * rng.randf_range(0.7, 1.45))
		inst.position = Vector3(
			rng.randf_range(_min_x, _max_x),
			height + rng.randf_range(-10.0, 14.0),
			center.z + rng.randf_range(-half_z, half_z))
		inst.rotation.y = rng.randf_range(0.0, TAU)
		_no_shadow(inst)
		_clouds.append(inst)

func _process(delta: float) -> void:
	if _clouds.is_empty():
		return
	for c in _clouds:
		c.position.x += drift_speed * delta
		# Begitu keluar batas kanan, lahirkan ulang di batas kiri (wrap) supaya
		# jumlah mesh tetap `count` tapi awan terasa tak pernah habis.
		if c.position.x > _max_x:
			c.position.x = _min_x

## Normalkan lebar model: tiap .glb punya skala ekspor berbeda.
func _normalize(inst: Node3D, want_w: float) -> void:
	var aabb := _local_aabb(inst)
	var w: float = max(aabb.size.x, aabb.size.z)
	if w > 0.001:
		var s: float = want_w / w
		inst.scale = Vector3(s, s, s)

func _no_shadow(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in node.get_children():
		_no_shadow(c)

## params.json weather_types = ["cerah", "mendung", "hujan"]
func _is_overcast() -> bool:
	var w := String(GameState.weather)
	return w == "mendung" or w == "hujan"

# --- util AABB (sama pola dengan Player3D._local_aabb) ---
func _local_aabb(inst: Node) -> AABB:
	var aabb := AABB()
	var first := true
	for m in _meshes(inst):
		var a: AABB = _rel_xform(inst, m) * (m as MeshInstance3D).mesh.get_aabb()
		if first:
			aabb = a
			first = false
		else:
			aabb = aabb.merge(a)
	return aabb

func _rel_xform(root: Node, node: Node3D) -> Transform3D:
	var t := Transform3D()
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t

func _meshes(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append(node)
	for c in node.get_children():
		out.append_array(_meshes(c))
	return out
