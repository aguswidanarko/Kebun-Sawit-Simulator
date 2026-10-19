extends Node3D
## Dunia kebun 3D yang bisa dijelajahi (Fase 1 track walkable).
## Karakter orang-ketiga berjalan di antara pohon sawit. Kamera follow.
## Sawit = aset dedicated "Asset kelapa sawit" (res://assets/models/palm/stages/)
## sesuai umur pokok blok aktif, via PalmBuilder.build_for_age().
## Karakter & tekstur tanah = CC0. Kode shell = milik proyek (semua aman komersial).

const COLS := 8
const ROWS := 8
const SPACING := 7.0

var _palm_asset := ""
var _palm_h := 8.0
var _player: CharacterBody3D
var _cam: Camera3D
var _joystick
var _block: Dictionary = {}
var _palm_pos: Array = []
var _near := false
var _status: RichTextLabel
var _aksi_btn: Button
var _action_panel: PanelContainer
var _action_list: VBoxContainer
var _toast: Label
var _toast_t := 0.0

# --- Sabuk hutan: batas jelajah sesuai luas lahan blok + loot acak (lihat ForestLoot) ---
var _world_center := Vector3.ZERO
var _boundary_r := 50.0
var _loot_nodes: Dictionary = {}   # slot idx(int) -> MeshInstance3D aktif di dunia
var _loot_tick := 0.0
const LOOT_CHECK_INTERVAL := 2.0
const BOUNDARY_MARGIN := 2.5       # jarak aman dari dinding hutan agar player tak klip ke batang

# --- Simulasi panen SOP (potong -> brondolan -> TPH -> angkut) ---
const RIPE_COUNT := 6          # pohon matang panen per rotasi (representatif)
var _ripe: Array = []          # [{i, pos, cut, brondol, marker}]
var _total_kg := 0.0           # estimasi TBS rotasi ini
var _kg_per_palm := 0.0
var _brondol_per_palm := 0.0   # SOP: brondolan ~10% terhadap janjang
var _carry_kg := 0.0           # buah di piringan yang sedang dibawa
var _hk_charged := false
var _tph_pos := Vector3.ZERO
var _truck_pos := Vector3.ZERO

func _ready() -> void:
	_ensure_block()
	_build_env()
	_build_ground()
	_palm_asset = PalmBuilder.asset_for_age(float(GameState.age_years_of(_block)))
	_palm_h = PalmBuilder.asset_height(_palm_asset)
	_build_plantation()
	_build_pelepah()
	_setup_harvest_sim()
	_spawn_player()
	_build_forest_loot()
	_build_hud()
	var a := OS.get_cmdline_user_args()
	if a.has("shotworld") or a.has("shotcustom"):
		call_deferred("_capture")
	elif a.has("worldtest"):
		call_deferred("_run_worldtest")

func _ensure_block() -> void:
	# Satu sumber kebun = GameState.plots; blok aktif = yang dimasuki dari Dashboard.
	_block = GameState.active_block()

func _run_worldtest() -> void:
	GameState.log_msg("=== WORLDTEST INTERAKSI ===")
	GameState.log_msg("jarak ke pohon terdekat: %.1f m" % _nearest_palm_dist())
	GameState.log_msg("PUPUK: " + Actions.fertilize(_block))
	GameState.log_msg("SEMPROT: " + Actions.spray(_block))
	_block["pest"] = { "id": "ulat_api", "level": 0.5, "diagnosed": false }
	GameState.log_msg("OBATI(blind): " + Actions.treat_pest(_block))
	GameState.log_msg("INSPEKSI: " + Actions.inspect(_block))
	GameState.log_msg("OBATI(diagnosed): " + Actions.treat_pest(_block))
	GameState.log_msg("PANEN: " + Actions.harvest(_block, "pengepul"))
	GameState.log_msg("Saldo akhir: Rp%s" % GameState._fmt(GameState.cash))
	GameState.log_msg("=== WORLDTEST SELESAI ===")
	get_tree().quit()

var _shot_mode := false

func _process(delta: float) -> void:
	if _shot_mode or _player == null or _cam == null:
		return
	if _joystick:
		_player.joystick = _joystick.output
	_clamp_to_boundary()
	var target := _player.global_position
	var desired := target + Vector3(0, 4.5, 8.5)
	var t: float = 1.0 - exp(-6.0 * delta)
	_cam.global_position = _cam.global_position.lerp(desired, t)
	_cam.look_at(target + Vector3(0, 1.6, -12.0), Vector3.UP)   # pandang mendatar ke depan

	# Proximity ke pohon/TPH/truk/loot -> tampilkan tombol Aksi
	var near := _nearest_palm_dist() < 4.5 or _nearest_ripe() >= 0 or _near_tph() or _near_truck() or _nearest_loot() >= 0
	if near != _near:
		_near = near
		if _aksi_btn: _aksi_btn.visible = _near
		if not _near and _action_panel: _action_panel.visible = false
	# Toast fade + status
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0 and _toast:
			_toast.visible = false
	_loot_tick -= delta
	if _loot_tick <= 0.0:
		_loot_tick = LOOT_CHECK_INTERVAL
		_refresh_forest_loot()
	_update_status()

## Tahan pemain di dalam radius jelajah (dinding hutan) sesuai luas lahan blok.
func _clamp_to_boundary() -> void:
	var p := _player.global_position
	var off := Vector2(p.x - _world_center.x, p.z - _world_center.z)
	var max_r := _boundary_r - BOUNDARY_MARGIN
	if off.length() > max_r:
		off = off.normalized() * max_r
		_player.global_position.x = _world_center.x + off.x
		_player.global_position.z = _world_center.z + off.y

# ---------------------------------------------------------------- dunia
func _build_env() -> void:
	SkyKit.build_env(self)

func _build_ground() -> void:
	var sb := StaticBody3D.new()
	add_child(sb)
	var col := CollisionShape3D.new()
	col.shape = WorldBoundaryShape3D.new()   # lantai tak terbatas di y=0 (fisika jalan kaki)
	sb.add_child(col)
	# Tanah/rumput/jalur visual datang dari sabuk hutan (lihat _build_forest_belt) -
	# tak perlu PlaneMesh terpisah lagi, area 100x100 m (1 ha) sudah tercakup di situ.
	_build_forest_belt()

## Sabuk hutan/semak belukar pembatas area jelajah, besarnya ikut luas lahan
## blok aktif (area_ha). Lihat ForestBeltBuilder & spek: 1 ha -> 100x100 m.
func _build_forest_belt() -> void:
	_world_center = Vector3((COLS - 1) * SPACING * 0.5, 0, (ROWS - 1) * SPACING * 0.5)
	var area_ha := float(_block.get("area_ha", 1.0))
	_boundary_r = ForestBeltBuilder.radius_m(area_ha)
	ForestBeltBuilder.build(self, _world_center, area_ha, true)

func _build_plantation() -> void:
	for r in ROWS:
		for c in COLS:
			var palm := _make_palm()
			palm.position = Vector3(c * SPACING, 0, r * SPACING)
			add_child(palm)
			_palm_pos.append(palm.position)

func _make_palm() -> Node3D:
	return PalmBuilder.build_asset_stage(_palm_asset)

## Susunan pelepah hasil tunasan/panen — BMP Region Riau (areal datar):
## pelepah potong 3 disusun pola U di gawangan mati + patok, pasar pikul bersih.
func _build_pelepah() -> void:
	var root := Node3D.new()
	root.name = "SusunanPelepah"
	add_child(root)
	PelepahBuilder.build(root, PelepahBuilder.layout_flat(COLS, ROWS, SPACING))

# ---------------------------------------------------------------- simulasi panen (SOP Panen & Transport)
func _setup_harvest_sim() -> void:
	# TPH di tepi blok (jalan koleksi) + truk angkut di sebelahnya.
	_tph_pos = Vector3(-6.0, 0, (ROWS - 1) * SPACING * 0.5)
	_build_tph()
	_truck_pos = _tph_pos + Vector3(-1.0, 0, 7.5)
	_build_truck()
	# Pohon matang panen (kriteria SOP: 2 brondolan/kg di piringan).
	_total_kg = Actions.estimate_kg(_block)
	if _total_kg <= 0.0:
		return
	var tbs_share := _total_kg * 0.9
	_kg_per_palm = tbs_share / float(RIPE_COUNT)
	_brondol_per_palm = (_total_kg * 0.1) / float(RIPE_COUNT)   # SOP: brondolan ~10%
	var idxs: Array = range(_palm_pos.size())
	idxs.shuffle()
	for k in RIPE_COUNT:
		var i := int(idxs[k])
		var marker := _ripe_marker()
		marker.position = _palm_pos[i] + Vector3(0, _palm_h * 0.72, 0)
		add_child(marker)
		_ripe.append({ "i": i, "pos": _palm_pos[i], "cut": false, "brondol": false, "marker": marker })

## Tanda tandan matang: gugus bola merah menyala di mahkota.
func _ripe_marker() -> Node3D:
	var root := Node3D.new()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.92, 0.19, 0.07)
	m.emission_enabled = true
	m.emission = Color(0.9, 0.25, 0.1)
	m.emission_energy_multiplier = 0.9
	for o in [Vector3.ZERO, Vector3(0.35, -0.15, 0.1), Vector3(-0.3, -0.2, -0.1)]:
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = 0.32; sm.height = 0.58
		s.mesh = sm; s.material_override = m
		s.position = o
		root.add_child(s)
	return root

## TPH: platform + papan nomor (SOP: buah hanya boleh disusun di TPH resmi bernomor).
func _build_tph() -> void:
	var root := Node3D.new()
	root.position = _tph_pos
	add_child(root)
	var plat := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(4.0, 0.18, 3.0)
	plat.mesh = bm
	var pm := StandardMaterial3D.new(); pm.albedo_color = Color(0.52, 0.42, 0.30)
	plat.material_override = pm
	plat.position = Vector3(0, 0.09, 0)
	root.add_child(plat)
	var pole := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.05; cm.bottom_radius = 0.05; cm.height = 1.8
	pole.mesh = cm
	pole.position = Vector3(-1.6, 0.9, -1.2)
	root.add_child(pole)
	var sign := MeshInstance3D.new()
	var sm2 := BoxMesh.new(); sm2.size = Vector3(1.1, 0.5, 0.06)
	sign.mesh = sm2
	var smat := StandardMaterial3D.new(); smat.albedo_color = Color(0.95, 0.95, 0.93)
	sign.material_override = smat
	sign.position = Vector3(-1.6, 1.85, -1.2)
	root.add_child(sign)
	var lbl := Label3D.new()
	lbl.text = "TPH 1"
	lbl.font_size = 64
	lbl.modulate = Color(0.12, 0.12, 0.11)
	lbl.position = Vector3(-1.6, 1.85, -1.16)
	root.add_child(lbl)

## Truk angkut TBS parkir di jalan koleksi.
func _build_truck() -> void:
	var path := "res://assets/models/vehicle/pickup_muatan_sawit.glb"
	if not ResourceLoader.exists(path):
		path = "res://assets/models/vehicle/pickup.glb"
	if ResourceLoader.exists(path):
		var t: Node3D = load(path).instantiate()
		_fit(t, 2.4)
		t.position = _truck_pos
		t.rotation.y = PI * 0.5
		add_child(t)
	else:
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3(2.2, 2.0, 4.5)
		box.mesh = bm
		box.position = _truck_pos + Vector3(0, 1.0, 0)
		add_child(box)

func _nearest_ripe() -> int:
	if _player == null:
		return -1
	var p := _player.global_position
	for k in _ripe.size():
		var r: Dictionary = _ripe[k]
		if bool(r["cut"]) and bool(r["brondol"]):
			continue
		if Vector2(p.x - r["pos"].x, p.z - r["pos"].z).length() < 4.5:
			return k
	return -1

func _near_tph() -> bool:
	return _player != null and Vector2(_player.global_position.x - _tph_pos.x,
		_player.global_position.z - _tph_pos.z).length() < 5.0

func _near_truck() -> bool:
	return _player != null and Vector2(_player.global_position.x - _truck_pos.x,
		_player.global_position.z - _truck_pos.z).length() < 5.5

# ---------------------------------------------------------------- loot sabuk hutan
## Pastikan blok aktif punya ForestLoot.MAX_SLOTS titik loot (state tersimpan di
## block["forest_slots"], ikut ke-save oleh GameState.save_game krn _block adalah
## referensi ke Dictionary di GameState.plots/blocks).
func _ensure_forest_slots() -> void:
	if not (_block.get("forest_slots") is Dictionary):
		_block["forest_slots"] = {}
	var slots: Dictionary = _block["forest_slots"]
	for i in ForestLoot.MAX_SLOTS:
		var key := str(i)
		if not slots.has(key):
			slots[key] = { "item_id": ForestLoot.roll_item_id(), "cooldown_until": -1 }

func _build_forest_loot() -> void:
	_ensure_forest_slots()
	_refresh_forest_loot()

## Sinkronkan node loot di dunia dengan state slot (muncul bila tersedia,
## hilang bila baru saja dipungut/masih dalam masa cooldown 1 bulan).
func _refresh_forest_loot() -> void:
	_ensure_forest_slots()
	var slots: Dictionary = _block["forest_slots"]
	for i in ForestLoot.MAX_SLOTS:
		var s: Dictionary = slots[str(i)]
		var available: bool = int(s.get("cooldown_until", -1)) <= GameState.day
		var has_node := _loot_nodes.has(i)
		if available and not has_node:
			_spawn_loot_node(i)
		elif not available and has_node:
			(_loot_nodes[i] as Node3D).queue_free()
			_loot_nodes.erase(i)

func _spawn_loot_node(i: int) -> void:
	var mesh := ForestBeltBuilder.marker_mesh()
	if mesh == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := ForestBeltBuilder.marker_material()
	if mat:
		mi.material_override = mat
	mi.position = ForestLoot.slot_position(String(_block.get("id", "blok")), i, _world_center, _boundary_r)
	add_child(mi)
	_loot_nodes[i] = mi

func _nearest_loot() -> int:
	if _player == null or _loot_nodes.is_empty():
		return -1
	var p := _player.global_position
	for i in _loot_nodes.keys():
		var n: Node3D = _loot_nodes[i]
		if Vector2(p.x - n.position.x, p.z - n.position.z).length() < 3.0:
			return i
	return -1

## Pungut item di slot `i` — masuk gudang via GameState.collect_item, slot
## masuk cooldown 1 bulan lalu random ulang item berikutnya (spek pengguna).
func _do_collect(i: int) -> void:
	var slots: Dictionary = _block.get("forest_slots", {})
	var key := str(i)
	if not slots.has(key):
		return
	var s: Dictionary = slots[key]
	var item_id := String(s.get("item_id", ""))
	if item_id == "":
		return
	var msg := GameState.collect_item(item_id)
	s["cooldown_until"] = GameState.day + ForestLoot.MONTH_DAYS
	s["item_id"] = ForestLoot.roll_item_id()
	slots[key] = s
	if _loot_nodes.has(i):
		(_loot_nodes[i] as Node3D).queue_free()
		_loot_nodes.erase(i)
	_act(msg)

## Potong tandan — grading SOP: matang (2 brondolan/kg) | terlalu matang | mentah (denda).
func _do_cut(k: int) -> void:
	var r: Dictionary = _ripe[k]
	var roll := randf()
	r["cut"] = true
	if roll < 0.08:
		# Buah MENTAH terlanjur dipotong -> denda (SOP 6.12.3), tidak dihitung.
		r["brondol"] = true
		(r["marker"] as Node3D).visible = false
		GameState.spend(50000, "Denda potong buah mentah (cap M)")
		_act("❌ Grading: MENTAH (<2 brondolan/kg) — kena denda Rp50.000. SOP: periksa brondolan di piringan sebelum memotong!")
		return
	var grade := "MATANG" if roll < 0.85 else "TERLALU MATANG"
	_carry_kg += _kg_per_palm
	(r["marker"] as Node3D).visible = false
	_act("✂ Potong TBS — grading %s. Gagang dipotong rapat 2 cm, buah ke piringan. Jangan lupa KUTIP BRONDOLAN di pokok ini." % grade)

## Kutip brondolan bersih (SOP: 10 lokasi losses brondolan).
func _do_brondol(k: int) -> void:
	var r: Dictionary = _ripe[k]
	r["brondol"] = true
	_carry_kg += _brondol_per_palm
	_act("🫘 Brondolan dikutip bersih (ketiak pelepah, piringan, pasar rintis) → dikarungkan. +%.0f kg." % _brondol_per_palm)

## Susun buah di TPH (5 TBS per baris, gagang ke belakang).
func _do_deposit() -> void:
	if _carry_kg <= 0.0:
		_act("Tidak ada buah yang dibawa. Potong buah dulu.")
		return
	var kg := _carry_kg
	_carry_kg = 0.0
	if not _hk_charged:
		_hk_charged = true
		_act(Actions.deposit_tph(_block, kg))
	else:
		GameState.tph_deposit(kg, String(_block.get("seed_id", "")), float(_block.get("health", 1.0)))
		_act("+%.0f kg disusun di TPH (total %.0f kg)." % [kg, GameState.tph_kg()])
	if _all_harvested():
		_show_toast("✅ Potong buah tuntas! SOP: angkut SEMUA buah ke PKS hari ini juga (Zero Restan). Pergi ke truk.")

func _all_harvested() -> bool:
	for r in _ripe:
		if not bool(r["cut"]):
			return false
	return true

func _do_transport(buyer: String) -> void:
	_act(Actions.transport_sell(buyer))

func _spawn_player() -> void:
	_player = load("res://scenes/world/Player3D.tscn").instantiate()
	_player.position = Vector3((COLS - 1) * SPACING * 0.5 + 0.5, 1.0, (ROWS - 1) * SPACING * 0.5 + 0.5)
	add_child(_player)
	_cam = Camera3D.new()
	_cam.fov = 64.0
	_cam.position = _player.position + Vector3(0, 4.5, 8.5)
	add_child(_cam)
	_cam.current = true
	_cam.look_at(_player.position + Vector3(0, 1.6, -12.0), Vector3.UP)
	# Kendaraan kosmetik (bila dimiliki/dipakai) terparkir di samping pemain
	var vm := GameState.vehicle_model()
	if vm != "" and ResourceLoader.exists(vm):
		var v: Node3D = load(vm).instantiate()
		_fit(v, 2.2)
		v.position = _player.position + Vector3(-3.5, 0, -2.0)
		v.rotation.y = 0.6
		add_child(v)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	# Status kebun (kiri atas)
	var sp := PanelContainer.new()
	sp.position = Vector2(10, 10)
	var ssb := StyleBoxFlat.new(); ssb.bg_color = Color(0, 0, 0, 0.45)
	ssb.set_corner_radius_all(8); ssb.set_content_margin_all(8)
	sp.add_theme_stylebox_override("panel", ssb)
	layer.add_child(sp)
	_status = RichTextLabel.new()
	_status.bbcode_enabled = true; _status.fit_content = true
	_status.custom_minimum_size = Vector2(300, 46)
	sp.add_child(_status)

	# Menu & Lanjut Hari (kanan atas)
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top.position = Vector2(-360, 10); top.add_theme_constant_override("separation", 6)
	layer.add_child(top)
	top.add_child(_mk_btn("😊", func():
		if _player and _player.has_method("do_emote"):
			_player.do_emote(GameState.applied_emote_anim_key(), 2.0)))
	top.add_child(_mk_btn("⏭ +15 Hari", func(): TimeManager.advance_day(15); _show_toast("Maju 15 hari."); _update_status()))
	top.add_child(_mk_btn("← Kebun", func(): get_tree().change_scene_to_file("res://scenes/DashboardScreen.tscn")))

	# Joystick kiri bawah
	_joystick = load("res://scenes/world/VirtualJoystick.gd").new()
	_joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_joystick.position = Vector2(30, -230)
	layer.add_child(_joystick)

	# Tombol Aksi (kanan bawah, muncul saat dekat pohon/TPH/truk)
	var toggle_aksi := func():
		if _action_panel:
			if not _action_panel.visible:
				_rebuild_actions()
			_action_panel.visible = not _action_panel.visible
	_aksi_btn = _mk_btn(" Aksi", toggle_aksi, "settings")
	_aksi_btn.custom_minimum_size = Vector2(120, 60)
	_aksi_btn.add_theme_font_size_override("font_size", 20)
	_aksi_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_aksi_btn.position = Vector2(-140, -90)
	_aksi_btn.visible = false
	layer.add_child(_aksi_btn)

	# Panel aksi (daftar, tersembunyi)
	_action_panel = PanelContainer.new()
	_action_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_action_panel.position = Vector2(-220, -360)
	var apsb := StyleBoxFlat.new(); apsb.bg_color = Color(0.06, 0.09, 0.07, 0.92)
	apsb.set_corner_radius_all(10); apsb.set_content_margin_all(8)
	_action_panel.add_theme_stylebox_override("panel", apsb)
	_action_panel.visible = false
	layer.add_child(_action_panel)
	_action_list = VBoxContainer.new()
	_action_list.add_theme_constant_override("separation", 5)
	_action_panel.add_child(_action_list)
	_rebuild_actions()

	# Toast (tengah bawah)
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.position = Vector2(-220, -250); _toast.custom_minimum_size = Vector2(440, 0)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_color_override("font_color", Color(1, 1, 0.8))
	_toast.add_theme_font_size_override("font_size", 16)
	_toast.visible = false
	layer.add_child(_toast)

	_update_status()

func _mk_btn(text: String, cb: Callable, icon_name := "") -> Button:
	var b := Button.new(); b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	if icon_name != "":
		var path := "res://assets/ui/icons/%s.svg" % icon_name
		if ResourceLoader.exists(path):
			b.icon = load(path)
			b.add_theme_color_override("icon_normal_color", Color(1, 1, 1))
	b.pressed.connect(cb)
	return b

## Isi panel aksi sesuai konteks posisi pemain (pohon matang / TPH / truk / pohon biasa).
func _rebuild_actions() -> void:
	if _action_list == null:
		return
	for c in _action_list.get_children():
		c.queue_free()
	var k := _nearest_ripe()
	if k >= 0:
		var r: Dictionary = _ripe[k]
		if not bool(r["cut"]):
			_action_list.add_child(_mk_btn("✂ Potong TBS (cek matang)", func(): _do_cut(k)))
		elif not bool(r["brondol"]):
			_action_list.add_child(_mk_btn("🫘 Kutip brondolan", func(): _do_brondol(k)))
	if _near_tph() and _carry_kg > 0.0:
		_action_list.add_child(_mk_btn("📦 Susun di TPH (%.0f kg)" % _carry_kg, _do_deposit))
	if _near_truck() and GameState.tph_kg() > 0.0:
		_action_list.add_child(_mk_btn("🚚 Angkut ke PKS (Pabrik)", func(): _do_transport("pabrik")))
		_action_list.add_child(_mk_btn("🚚 Jual ke Pengepul", func(): _do_transport("pengepul")))
	var loot_i := _nearest_loot()
	if loot_i >= 0:
		var slots: Dictionary = _block.get("forest_slots", {})
		var s: Dictionary = slots.get(str(loot_i), {})
		var meta := Database.get_merchant_item(String(s.get("item_id", "")))
		_action_list.add_child(_mk_btn("🌿 Pungut %s" % String(meta.get("name", "item")), func(): _do_collect(loot_i)))
	if _nearest_palm_dist() < 4.5:
		_action_list.add_child(_mk_btn(" Inspeksi Hama", func(): _act(Actions.inspect(_block)), "search"))
		_action_list.add_child(_mk_btn(" Obati Hama", func(): _act(Actions.treat_pest(_block)), "pill"))
		_action_list.add_child(_mk_btn(" Pupuk", func(): _act(Actions.fertilize(_block)), "leaf"))
		_action_list.add_child(_mk_btn(" Semprot Gulma", func(): _act(Actions.spray(_block)), "droplets"))
	if _action_list.get_child_count() == 0:
		var e := Label.new()
		e.text = "Dekati pohon matang (merah),\nTPH, atau truk."
		e.add_theme_font_size_override("font_size", 12)
		_action_list.add_child(e)

func _act(result: String) -> void:
	if _player and _player.has_method("do_work"):
		_player.do_work(1.2)
	_show_toast(result)
	_update_status()
	if _action_panel: _action_panel.visible = false

func _show_toast(txt: String) -> void:
	if _toast:
		_toast.text = txt
		_toast.visible = true
		_toast_t = 3.5

func _update_status() -> void:
	if _status == null or _block.is_empty():
		return
	var age := GameState.age_years_of(_block)
	var pest = _block.get("pest")
	var pest_txt := ""
	if pest != null:
		var c := Database.get_pest(String(pest.get("id", "")))
		var nm: String = c.get("name") if bool(pest.get("diagnosed", false)) else "? gejala (inspeksi)"
		pest_txt = "  [color=#ff8080]⚠ %s[/color]" % nm
	var panen_txt := ""
	if not _ripe.is_empty():
		var sisa := 0
		for r in _ripe:
			if not bool(r["cut"]):
				sisa += 1
		panen_txt = "\n[color=#ffd080]Panen: %d pohon matang tersisa · bawa %.0f kg · TPH %.0f kg%s[/color]" % [
			sisa, _carry_kg, GameState.tph_kg(),
			("  ⚠ RESTAN %d hr" % GameState.tph_restan_days()) if GameState.tph_restan_days() > 0 else ""]
	elif GameState.tph_kg() > 0.0:
		panen_txt = "\n[color=#ff9080]TPH %.0f kg — angkut ke PKS! (restan %d hr)[/color]" % [
			GameState.tph_kg(), GameState.tph_restan_days()]
	_status.text = "[b]Rp%s[/b] · Hari %d · %s\nKebun: umur %d th · sehat %.0f%% · gulma %.0f%%%s%s" % [
		GameState._fmt(GameState.cash), GameState.day, GameState.weather.capitalize(),
		age, float(_block.get("health", 1.0)) * 100.0, float(_block.get("weed_level", 0)) * 100.0, pest_txt, panen_txt]

func _nearest_palm_dist() -> float:
	if _player == null: return 9999.0
	var p := _player.global_position
	var best := 9999.0
	for pos in _palm_pos:
		var d: float = Vector2(p.x - pos.x, p.z - pos.z).length()
		if d < best: best = d
	return best

# ---------------------------------------------------------------- util
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

func _capture() -> void:
	_shot_mode = true
	if _aksi_btn: _aksi_btn.visible = true
	if _action_panel: _action_panel.visible = true
	_show_toast("Dekati pohon lalu tekan ⚙ Aksi")
	var p := _player.global_position
	_cam.global_position = p + Vector3(0, 4.5, 8.5)
	_cam.look_at(p + Vector3(0, 1.6, -12.0), Vector3.UP)
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png("user://world.png")
	print("[world] screenshot saved")
	get_tree().quit()
