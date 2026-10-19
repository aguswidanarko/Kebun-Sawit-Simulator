extends Node3D
## Fase 5 — penampil kebun 3D sederhana.
## Menampilkan 1 blok sebagai grid pohon sawit — aset dedicated "Asset kelapa
## sawit" (res://assets/models/palm/stages/) dipilih sesuai umur blok lewat
## PalmBuilder.build_for_age(), dengan sedikit skala seragam dari kesehatan
## sbg isyarat visual. Gulma (rumput Stylized Nature) sesuai weed_level.

const GRASS := "res://assets/models/nature/Grass_Common_Tall.gltf"
const BUSH := "res://assets/models/nature/Bush_Common.gltf"

const ROWS := 5
const COLS := 4
const SPACING := 4.6

var info_label: Label

func _ready() -> void:
	_build_world()
	var block := _current_block()
	_build_block(block)
	_build_ui(block)
	if OS.get_cmdline_user_args().has("view3d"):
		call_deferred("_selftest_quit", block)
	if OS.get_cmdline_user_args().has("shot3d"):
		call_deferred("_capture")

func _capture() -> void:
	await get_tree().create_timer(1.0).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://kebun3d.png")
	print("[3D] screenshot: user://kebun3d.png")
	get_tree().quit()

func _current_block() -> Dictionary:
	if not GameState.visiting.is_empty():
		var vb = GameState.visiting.get("blocks", [])
		if vb is Array and not vb.is_empty():
			return vb[0]
	var idx := GameState.first_planted_index()
	if idx >= 0:
		return GameState.plots[idx]
	# Blok demo agar tetap bisa dilihat tanpa bermain.
	return { "id": "demo", "seed_id": "fr", "area_ha": 1.0, "health": 0.8,
			 "weed_level": 0.35, "golden_count": 3, "planting_day": 1 }

# ---------------------------------------------------------------- Dunia
func _build_world() -> void:
	SkyKit.build_env(self)

	# Tanah
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	var gm := SkyKit.ground_material()
	gm.uv1_scale = Vector3(8, 8, 1)
	ground.material_override = gm
	add_child(ground)

	# Kamera melihat grid dari sudut atas
	var cam := Camera3D.new()
	var center := Vector3(COLS * SPACING * 0.5, 0, ROWS * SPACING * 0.5)
	cam.position = center + Vector3(0, 16, 24)
	cam.current = true
	add_child(cam)
	cam.look_at(center + Vector3(0, 1.5, 0), Vector3.UP)  # setelah masuk tree

	# Sabuk hutan latar — asset tunggal (lihat ForestBeltBuilder), ganti pohon
	# bg + jalan batu lama. Viewer ini statis (tanpa player) jadi cukup visual,
	# tanpa batas jelajah/loot (lihat FarmWorld3D utk versi walkable penuh).
	var block := _current_block()
	var area_ha := float(block.get("area_ha", 1.0))
	ForestBeltBuilder.build(self, center, area_ha, true)

# ---------------------------------------------------------------- Blok
func _build_block(block: Dictionary) -> void:
	var age := GameState.age_years_of(block) if block.get("id") != "demo" else 6
	var health := float(block.get("health", 1.0))
	var golden := int(block.get("golden_count", 0))
	var scale_s: float = lerp(0.82, 1.0, health)   # isyarat visual kesehatan buruk = lebih kecil

	var idx := 0
	for r in ROWS:
		for c in COLS:
			var palm := PalmBuilder.build_for_age(float(age))
			palm.position = Vector3(c * SPACING, 0, r * SPACING)
			palm.scale = Vector3(scale_s, scale_s, scale_s)
			palm.rotate_y(randf() * TAU)
			if idx < golden:
				_tint_gold(palm)
			add_child(palm)
			idx += 1

	# Gulma: kepadatan ∝ weed_level
	var weed := float(block.get("weed_level", 0.0))
	var n_weeds := int(weed * 80.0)
	var grass_scene := load(GRASS)
	var bush_scene := load(BUSH)
	for i in n_weeds:
		var src = grass_scene if (i % 3 != 0) else bush_scene
		if src == null:
			continue
		var g := _fit(src.instantiate(), 0.5)
		g.position = Vector3(randf() * COLS * SPACING, 0, randf() * ROWS * SPACING)
		g.rotate_y(randf() * TAU)
		add_child(g)

func _build_ui(block: Dictionary) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	layer.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var visiting := not GameState.visiting.is_empty()
	if visiting:
		var vlbl := Label.new()
		vlbl.text = "👥 Mengunjungi: %s" % str(GameState.visiting.get("kebun_name", "Kebun teman"))
		vlbl.add_theme_color_override("font_color", Color(0.6, 0.85, 1))
		v.add_child(vlbl)
	info_label = Label.new()
	var seed := Database.get_seed(String(block.get("seed_id", "")))
	info_label.text = "Blok %s — %s\nUmur %d th | sehat %.0f%% | gulma %.0f%% | golden %d" % [
		block.get("id"), seed.get("variety_name", "?"),
		(GameState.age_years_of(block) if block.get("id") != "demo" else 6),
		float(block.get("health", 1.0)) * 100.0, float(block.get("weed_level", 0)) * 100.0,
		int(block.get("golden_count", 0))]
	v.add_child(info_label)
	var back := Button.new()
	back.text = "← Kembali"
	back.pressed.connect(func():
		GameState.end_visit()
		get_tree().change_scene_to_file("res://scenes/Main.tscn"))
	v.add_child(back)

# ---------------------------------------------------------------- Util skala
# Normalisasi tinggi model ke target_h (m). target_h<=0 => pakai skala asli.
func _fit(inst: Node3D, target_h: float) -> Node3D:
	var aabb := _local_aabb(inst)
	if target_h > 0.0 and aabb.size.y > 0.0001:
		var s := target_h / aabb.size.y
		inst.scale = Vector3(s, s, s)
		inst.position.y = -aabb.position.y * s
	else:
		inst.position.y = -aabb.position.y
	return inst

func _local_aabb(inst: Node) -> AABB:
	var aabb := AABB()
	var first := true
	for m in _meshes(inst):
		var a: AABB = _rel_xform(inst, m) * m.mesh.get_aabb()
		if first: aabb = a; first = false
		else: aabb = aabb.merge(a)
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

func _tint_gold(inst: Node) -> void:
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.82, 0.2)
	gold.emission_enabled = true
	gold.emission = Color(0.8, 0.6, 0.05)
	gold.emission_energy_multiplier = 0.4
	for m in _meshes(inst):
		(m as MeshInstance3D).material_override = gold

func _selftest_quit(block: Dictionary) -> void:
	var palms := 0
	for c in get_children():
		if c is Node3D and c.get_child_count() > 0:
			palms += 1
	print("[3D] Scene terbangun. Node anak: %d. Model sawit dimuat: %s" % [
		get_child_count(), str(ResourceLoader.exists(PalmBuilder.ASSET_TM1))])
	get_tree().quit()
