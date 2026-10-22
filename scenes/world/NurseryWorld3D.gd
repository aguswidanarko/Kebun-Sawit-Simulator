extends Node3D
## Dunia bibitan 3D yang bisa dijelajahi — merefleksikan GameState.nursery
## (stage/qty/umur bulan) ke layout polybag sesuai data/nursery_stages.json
## (lihat Database.nursery_stage_for_month). model_res tiap tahap memakai aset
## dedicated "Asset kelapa sawit" (res://assets/models/palm/stages/) via
## PalmBuilder.build_asset_stage(). ground_texture_res MASIH PLACEHOLDER (belum
## ada tekstur tanah dedicated) -> tanah di sini fallback warna polos.

const MAX_RENDER := 63   # representatif, bukan render seluruh qty asli (bisa ribuan)

var _player: CharacterBody3D
var _cam: Camera3D
var _dpad
var _status: RichTextLabel
var _stage: Dictionary = {}
var _cols := 7
var _rows := 5
var _sp := 0.9
var _row_gap := 0.9

func _ready() -> void:
	_stage = Database.nursery_stage_for_month(GameState.nursery_age_months())
	_build_env()
	_build_ground()
	_build_layout()
	_build_forest_backdrop()
	_spawn_player()
	_build_hud()
	if OS.get_cmdline_user_args().has("shotnursery"):
		call_deferred("_capture")

func _process(delta: float) -> void:
	if _player == null or _cam == null:
		return
	if _dpad:
		_player.joystick = _dpad.output
	var target := _player.global_position
	var desired := target + Vector3(0, 4.5, 8.5)
	var t: float = 1.0 - exp(-6.0 * delta)
	_cam.global_position = _cam.global_position.lerp(desired, t)
	_cam.look_at(target + Vector3(0, 1.6, -12.0), Vector3.UP)

# ---------------------------------------------------------------- dunia
func _build_env() -> void:
	SkyKit.build_env(self)

func _build_ground() -> void:
	var sb := StaticBody3D.new()
	add_child(sb)
	var col := CollisionShape3D.new()
	col.shape = WorldBoundaryShape3D.new()
	sb.add_child(col)
	var vis := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(160, 160)
	vis.mesh = pm
	var m := StandardMaterial3D.new()
	var tex_path := String(_stage.get("ground_texture_res", ""))
	var diff = load(tex_path) if tex_path != "" and ResourceLoader.exists(tex_path) else null
	if diff != null:
		m.albedo_texture = diff
		m.uv1_scale = Vector3(30, 30, 1)
	else:
		# fallback: tanah PN kering kemerahan vs tanah MN becek gelap
		m.albedo_color = Color(0.45, 0.33, 0.22) if String(_stage.get("layout_type", "")) == "bedengan_rapat" else Color(0.30, 0.27, 0.22)
	vis.material_override = m
	sb.add_child(vis)

## Latar sabuk hutan di sekeliling area bibitan (murni visual, tanpa batas
## jelajah/loot — bibitan bukan "blok lahan milik" seperti FarmWorld3D, jadi
## diskalakan kecil mengikuti luas petak bibit, bukan area_ha blok kebun).
func _build_forest_backdrop() -> void:
	var center := Vector3((_cols - 1) * _sp * 0.5, 0, (_rows - 1) * _row_gap * 0.5)
	var target_radius := 16.0
	var area_ha := pow(target_radius / ForestBeltBuilder.BASE_RADIUS_M, 2.0)
	ForestBeltBuilder.build(self, center, area_ha, true)

## Susun polybag sesuai layout_type tahap aktif (bedengan rapat PN vs grid lebar MN).
func _build_layout() -> void:
	if _stage.is_empty():
		_build_empty_sign()
		return
	var layout := String(_stage.get("layout_type", "grid_lebar"))
	_sp = float(_stage.get("spacing_m", 0.9))
	_row_gap = float(_stage.get("row_gap_m", 0.9))
	if layout == "bedengan_rapat":
		_cols = 9; _rows = 7
		_build_bed_frame()
		if bool(_stage.get("shade_net", false)):
			_build_shade_net()
	else:
		_cols = 7; _rows = 5

	var qty := int(GameState.nursery.get("qty", 0))
	var shown := (mini(qty, MAX_RENDER) if qty > 0 else MAX_RENDER)
	var placed := 0
	for r in _rows:
		if placed >= shown:
			break
		for c in _cols:
			if placed >= shown:
				break
			var seedling := _make_seedling()
			seedling.position = Vector3(c * _sp, 0, r * _row_gap)
			add_child(seedling)
			placed += 1
	if qty > MAX_RENDER:
		_label_3d("Mewakili %d dari %d bibit" % [shown, qty], Vector3((_cols - 1) * _sp * 0.5, 2.2, -1.4))

func _build_empty_sign() -> void:
	_label_3d("Belum ada bibitan aktif.\nPesan kecambah dari panel Pembibitan di Dashboard.", Vector3(0, 1.6, -2))

func _label_3d(text: String, pos: Vector3) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 40
	lbl.modulate = Color(1, 1, 0.9)
	lbl.position = pos
	add_child(lbl)

## Bingkai bedengan bambu/kayu di tepi barisan polybag rapat (PN).
func _build_bed_frame() -> void:
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.55, 0.42, 0.25)
	var w := (_cols - 1) * _sp + 0.6
	var h := (_rows - 1) * _row_gap + 0.6
	var rails := [
		{"size": Vector3(w, 0.12, 0.1), "pos": Vector3(w * 0.5 - 0.3, 0.06, -0.3)},
		{"size": Vector3(w, 0.12, 0.1), "pos": Vector3(w * 0.5 - 0.3, 0.06, h - 0.3)},
		{"size": Vector3(0.1, 0.12, h), "pos": Vector3(-0.3, 0.06, h * 0.5 - 0.3)},
		{"size": Vector3(0.1, 0.12, h), "pos": Vector3(w - 0.3, 0.06, h * 0.5 - 0.3)},
	]
	for rail_def in rails:
		var rail := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = rail_def["size"]
		rail.mesh = bm
		rail.material_override = m
		rail.position = rail_def["pos"]
		add_child(rail)

## Tiang + atap paranet sederhana (dipakai hanya di tahap PN awal, shade_net=true).
func _build_shade_net() -> void:
	var w := (_cols - 1) * _sp + 1.0
	var h := (_rows - 1) * _row_gap + 1.0
	var post_m := StandardMaterial3D.new(); post_m.albedo_color = Color(0.5, 0.4, 0.28)
	var net_m := StandardMaterial3D.new()
	net_m.albedo_color = Color(0.08, 0.08, 0.08, 0.55)
	net_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for corner in [Vector3(-0.3, 0, -0.3), Vector3(w, 0, -0.3), Vector3(-0.3, 0, h), Vector3(w, 0, h)]:
		var post := MeshInstance3D.new()
		var cm := CylinderMesh.new(); cm.top_radius = 0.06; cm.bottom_radius = 0.06; cm.height = 2.2
		post.mesh = cm
		post.material_override = post_m
		post.position = corner + Vector3(0, 1.1, 0)
		add_child(post)
	var net := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(w + 0.6, h + 0.6)
	net.mesh = pm
	net.material_override = net_m
	net.position = Vector3(w * 0.5 - 0.3, 2.2, h * 0.5 - 0.3)
	add_child(net)

## Bibit sesuai tahap aktif: aset dedicated bila ada (lihat model_res di
## nursery_stages.json), kalau tidak fallback prosedural (polybag + daun).
func _make_seedling() -> Node3D:
	var model_path := String(_stage.get("model_res", ""))
	if model_path != "" and ResourceLoader.exists(model_path):
		return PalmBuilder.build_asset_stage(model_path)
	var root := Node3D.new()
	var bag := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	var big := String(_stage.get("polybag_size_cm", "")).begins_with("35")
	cm.top_radius = 0.20 if big else 0.10
	cm.bottom_radius = 0.18 if big else 0.09
	cm.height = 0.30 if big else 0.20
	bag.mesh = cm
	var bag_m := StandardMaterial3D.new(); bag_m.albedo_color = Color(0.05, 0.05, 0.05)
	bag.material_override = bag_m
	bag.position.y = cm.height * 0.5
	root.add_child(bag)
	var leaf_h := _leaf_height()
	if leaf_h > 0.0:
		var leaf_m := StandardMaterial3D.new(); leaf_m.albedo_color = Color(0.30, 0.55, 0.18)
		for i in 3:
			var leaf := MeshInstance3D.new()
			var bm := BoxMesh.new(); bm.size = Vector3(0.05, leaf_h, 0.02)
			leaf.mesh = bm
			leaf.material_override = leaf_m
			leaf.position = Vector3(0, cm.height + leaf_h * 0.5, 0)
			leaf.rotate_y(i * TAU / 3.0)
			leaf.rotate_z(deg_to_rad(18))
			root.add_child(leaf)
	return root

func _leaf_height() -> float:
	match String(_stage.get("stage_id", "")):
		"pn_baru_tanam": return 0.0
		"pn_tunas_tunggal": return 0.22
		"pn_siap_transplant": return 0.35
		"pn_menjelang_mn": return 0.45
		"mn_baru_transplant": return 0.65
		"mn_seleksi_6bln": return 0.95
		"mn_seleksi_9bln": return 1.25
		"siap_tanam": return 1.5
		_: return 0.3

func _spawn_player() -> void:
	_player = load("res://scenes/world/Player3D.tscn").instantiate()
	_player.position = Vector3((_cols - 1) * _sp * 0.5, 1.0, -3.0)
	add_child(_player)
	_cam = Camera3D.new()
	_cam.fov = 64.0
	_cam.position = _player.position + Vector3(0, 4.5, 8.5)
	add_child(_cam)
	_cam.current = true
	_cam.look_at(_player.position + Vector3(0, 1.6, -12.0), Vector3.UP)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var sp := PanelContainer.new()
	sp.position = Vector2(10, 10)
	var ssb := StyleBoxFlat.new(); ssb.bg_color = Color(0, 0, 0, 0.45)
	ssb.set_corner_radius_all(8); ssb.set_content_margin_all(8)
	sp.add_theme_stylebox_override("panel", ssb)
	layer.add_child(sp)
	_status = RichTextLabel.new()
	_status.bbcode_enabled = true; _status.fit_content = true
	_status.custom_minimum_size = Vector2(340, 60)
	sp.add_child(_status)
	_update_status()

	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top.position = Vector2(-150, 10)
	layer.add_child(top)
	top.add_child(_mk_btn("← Kebun", func(): get_tree().change_scene_to_file("res://scenes/DashboardScreen.tscn")))

	# D-pad sentuh kiri bawah (pengganti VirtualJoystick — lihat TouchDPad.gd)
	_dpad = load("res://scenes/world/TouchDPad.gd").new()
	layer.add_child(_dpad)
	_dpad.anchor_bottom_left(18, 24)

func _mk_btn(text: String, cb: Callable) -> Button:
	var b := Button.new(); b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(cb)
	return b

func _update_status() -> void:
	if _status == null:
		return
	if GameState.nursery.is_empty():
		_status.text = "[b]Bibitan[/b]\nBelum ada bibitan aktif."
		return
	var seed := Database.get_seed(String(GameState.nursery.get("seed_id", "")))
	var m := GameState.nursery_age_months()
	_status.text = "[b]%s[/b]\n%s · umur %d bln · %d bibit" % [
		String(_stage.get("label", "?")), seed.get("variety_name", "?"), m, int(GameState.nursery.get("qty", 0))]

func _capture() -> void:
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png("user://nursery.png")
	print("[nursery] screenshot saved")
	get_tree().quit()
