extends Node
## Render model .glb jadi sprite PNG transparan (sekali jalan, hasil di-commit).
##   Godot --headless --path . res://tools/RenderSprites.tscn
##
## Dipakai untuk minigame Inspeksi Hama: burung hantu & ayam hanya tersedia
## sebagai model 3D, sedangkan hama lain sudah punya foto 2D di assets/pests/.

const OUT_DIR := "res://assets/pests"
const SIZE := 256

# [path glb, nama file keluaran, rotasi-y derajat]
# Semua ikon minigame "tangkap" dirender dari model 3D ke PNG transparan.
# Sebelumnya hama memakai foto .jpg yang berlatar kotak putih — di layar
# terlihat seperti kartu persegi, bukan ikon hama.
const JOBS := [
	["res://assets/models/3d/animals/burung_hantu.glb", "burung_hantu.png", 20.0],
	["res://assets/models/3d/animals/ayam_jantan.glb", "ayam.png", 35.0],
	["res://assets/models/3d/pests/ulat_api.glb", "ikon_ulat_api.png", 25.0],
	["res://assets/models/3d/pests/rayap_prajurit.glb", "ikon_rayap.png", 30.0],
	["res://assets/models/3d/pests/kumbang_oryctes.glb", "ikon_kumbang.png", 30.0],
	["res://assets/models/3d/pests/monyet.glb", "ikon_monyet.png", 25.0],
	["res://assets/models/3d/pests/belalang.glb", "ikon_belalang.png", 30.0],
	["res://assets/models/3d/pests/landak.glb", "ikon_landak.png", 25.0],
]

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for job in JOBS:
		await _render(String(job[0]), String(job[1]), float(job[2]))
	print("RENDER-DONE")
	get_tree().quit()

func _render(glb: String, out_name: String, yaw: float) -> void:
	if not ResourceLoader.exists(glb):
		print("LEWAT (tak ada): ", glb)
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var holder := Node3D.new()
	vp.add_child(holder)

	var inst: Node3D = (load(glb) as PackedScene).instantiate()
	holder.add_child(inst)
	inst.rotation_degrees.y = yaw

	# Pusatkan & skala agar model mengisi frame
	var aabb := _aabb(inst)
	var longest: float = max(aabb.size.x, max(aabb.size.y, aabb.size.z))
	if longest > 0.0001:
		var s := 1.0 / longest
		inst.scale = Vector3(s, s, s)
	inst.position = -aabb.get_center() * inst.scale.x

	var cam := Camera3D.new()
	cam.fov = 45.0
	# look_at WAJIB setelah add_child: butuh global_transform yang hanya ada
	# ketika node sudah masuk tree.
	vp.add_child(cam)
	cam.position = Vector3(0.9, 0.55, 1.5)
	cam.look_at(Vector3.ZERO, Vector3.UP)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -40, 0)
	key.light_energy = 1.6
	vp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, 140, 0)
	fill.light_energy = 0.7
	vp.add_child(fill)

	# Tunggu 2 frame agar viewport benar-benar ter-render
	await get_tree().process_frame
	await get_tree().process_frame

	var img := vp.get_texture().get_image()
	var abs_path := ProjectSettings.globalize_path(OUT_DIR.path_join(out_name))
	var err := img.save_png(abs_path)
	print("%s -> %s (err %d)" % [glb.get_file(), out_name, err])
	vp.queue_free()

func _aabb(inst: Node) -> AABB:
	var out := AABB()
	var first := true
	for m in _meshes(inst):
		var a: AABB = (m as MeshInstance3D).global_transform * (m as MeshInstance3D).mesh.get_aabb()
		if first:
			out = a
			first = false
		else:
			out = out.merge(a)
	return out

func _meshes(node: Node) -> Array:
	var r: Array = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		r.append(node)
	for c in node.get_children():
		r.append_array(_meshes(c))
	return r
