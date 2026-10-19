extends Control
## Mesin cerita bercabang data-driven (data/story.json) + efek typewriter.
## Node: narration / choice / land_market / preview / start_game.
## Logika terpisah dari UI agar bisa diuji (goto/choose/pick_land dipanggil langsung).

const CHARS_PER_SEC := 45.0
const MAIN := "res://scenes/DashboardScreen.tscn"   # hub resmi = Dashboard

var flags: Dictionary = {}
var current_id: String = ""
var _typing := false
var _full := ""

var text_label: RichTextLabel
var controls: VBoxContainer
var _preview: Node = null

func _ready() -> void:
	add_child(load("res://scenes/ui/KebunBackground.tscn").instantiate())
	_build_ui()
	var start := Database.story_start(GameState.profile_id)
	if start == "":
		start = Database.story_start("pekerja_aktif")
	if OS.get_cmdline_user_args().has("storytest"):
		call_deferred("_run_selftest")
		return
	goto(start)
	if OS.get_cmdline_user_args().has("shotstory"):
		call_deferred("_capture")
	if OS.get_cmdline_user_args().has("shotpreview"):
		call_deferred("_capture_preview")

func _capture_preview() -> void:
	GameState.story_flags = { "jalur": "kebun", "tipe_lahan": "bersih", "land_class": "S1" }
	_open_preview("confirm")
	await get_tree().create_timer(1.6).timeout
	get_viewport().get_texture().get_image().save_png("user://preview.png")
	print("[preview] screenshot saved")
	get_tree().quit()

func _capture() -> void:
	goto("invest_choice")   # tampilkan layar pilihan agar terlihat menarik
	await get_tree().create_timer(1.2).timeout
	get_viewport().get_texture().get_image().save_png("user://story.png")
	print("[story] screenshot saved")
	get_tree().quit()

# ---------------------------------------------------------------- UI
func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(358, 0)   # muat di frame 390 (margin 16 kiri-kanan)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.06, 0.86)
	sb.set_corner_radius_all(16); sb.set_content_margin_all(22)
	sb.set_border_width_all(1); sb.border_color = Color(1, 1, 1, 0.1)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)

	text_label = RichTextLabel.new()
	text_label.bbcode_enabled = true
	text_label.fit_content = true
	text_label.custom_minimum_size = Vector2(0, 120)
	text_label.add_theme_font_size_override("normal_font_size", 18)
	v.add_child(text_label)

	controls = VBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	v.add_child(controls)

func _unhandled_input(ev: InputEvent) -> void:
	# Tap di area kosong menyelesaikan typewriter.
	if not _typing:
		return
	if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
		_on_tap()

func _process(delta: float) -> void:
	if _typing:
		text_label.visible_ratio += (CHARS_PER_SEC / max(1.0, float(_full.length()))) * delta
		if text_label.visible_ratio >= 1.0:
			_typing = false

func _on_tap() -> void:
	if _typing:
		_typing = false
		text_label.visible_ratio = 1.0

func _set_text(txt: String) -> void:
	_full = txt
	text_label.text = txt
	text_label.visible_ratio = 0.0
	_typing = txt.length() > 0

func _clear_controls() -> void:
	for c in controls.get_children():
		c.queue_free()

func _btn(label: String, cb: Callable, icon_name := "") -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 15)
	# Bungkus teks panjang agar tombol tidak memaksa lebar > viewport 390.
	if "autowrap_mode" in b:
		b.set("autowrap_mode", TextServer.AUTOWRAP_WORD_SMART)
	if icon_name != "":
		var path := "res://assets/ui/icons/%s.svg" % icon_name
		if ResourceLoader.exists(path):
			b.icon = load(path)
			b.add_theme_color_override("icon_normal_color", Color(1, 1, 1))
	b.pressed.connect(cb)
	return b

# ---------------------------------------------------------------- Logika node (bisa diuji)
func goto(id: String) -> void:
	current_id = id
	var node := Database.story_node(id)
	var type := String(node.get("type", ""))
	if type == "start_game":
		_finish()
		return
	_set_text(String(node.get("text", "")))
	if controls:
		_clear_controls()
	match type:
		"narration":
			_add_continue(String(node.get("next", "")))
		"choice":
			_add_choices(node.get("options", []))
		"land_market":
			_add_land_cards(String(node.get("filter", "")), String(node.get("next", "")))
		"preview":
			_add_preview(String(node.get("next", "")))
		_:
			push_error("Node cerita tak dikenal: " + id)

func set_flags(d: Dictionary) -> void:
	for k in d:
		flags[k] = d[k]

func choose(index: int) -> void:
	var node := Database.story_node(current_id)
	var opts: Array = node.get("options", [])
	if index < 0 or index >= opts.size():
		return
	var opt: Dictionary = opts[index]
	if opt.has("set"):
		set_flags(opt.get("set"))
	goto(String(opt.get("next", "")))

func pick_land(id: String, next_id: String) -> void:
	var lo := Database.get_land_offer(id)
	set_flags({
		"lahan_id": id, "lahan_name": lo.get("name", id),
		"land_class": lo.get("land_class", "S1"),
		"land_price": int(lo.get("price_rp", 0)),
		"needs_clearing": bool(lo.get("needs_clearing", false))
	})
	goto(next_id)

func _finish() -> void:
	GameState.apply_story(flags)
	get_tree().change_scene_to_file(MAIN)

# ---------------------------------------------------------------- UI builders
func _add_continue(next_id: String) -> void:
	if controls == null: return
	controls.add_child(_btn("Lanjut ▶", func(): goto(next_id)))

func _add_choices(opts: Array) -> void:
	if controls == null: return
	for i in opts.size():
		var opt: Dictionary = opts[i]
		var idx := i
		controls.add_child(_btn(String(opt.get("label", "?")), func(): choose(idx)))

func _add_preview(next_id: String) -> void:
	if controls == null: return
	controls.add_child(_btn(" Lihat Preview 3D (eksplor)", func(): _open_preview(next_id), "search"))
	controls.add_child(_btn("Lanjut ▶", func(): goto(next_id)))

func _open_preview(next_id: String) -> void:
	# Teruskan pilihan cerita ke preview SEKARANG (apply_story baru jalan di akhir cerita).
	GameState.story_flags = flags.duplicate()
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(layer)

	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(svc)
	var sv := SubViewport.new()
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.msaa_3d = Viewport.MSAA_2X
	svc.add_child(sv)
	_preview = load("res://scenes/ui/PreviewKebun3D.tscn").instantiate()
	sv.add_child(_preview)

	layer.gui_input.connect(_on_preview_input)

	# Judul kecil + kontrol di bawah
	var head := Label.new()
	head.text = "GAMBARAN KEBUN — seret untuk memutar, zoom dengan tombol"
	head.set_anchors_preset(Control.PRESET_TOP_WIDE)
	head.offset_left = 14; head.offset_top = 12; head.offset_right = -14
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_theme_font_size_override("font_size", 12)
	head.add_theme_color_override("font_color", Color(1, 1, 1))
	layer.add_child(head)

	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -62; bar.offset_left = 12; bar.offset_right = -12; bar.offset_bottom = -12
	bar.add_theme_constant_override("separation", 8)
	layer.add_child(bar)
	bar.add_child(_btn("＋ Zoom", func(): if _preview: _preview.zoom(0.85)))
	bar.add_child(_btn("－ Zoom", func(): if _preview: _preview.zoom(1.18)))
	var spring := Control.new(); spring.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spring)
	bar.add_child(_btn("Tutup & Lanjut ▶", func():
		_preview = null
		layer.queue_free()
		goto(next_id)))

func _on_preview_input(ev: InputEvent) -> void:
	if _preview == null:
		return
	if ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_preview.orbit(ev.relative.x, ev.relative.y)
	elif ev is InputEventScreenDrag:
		_preview.orbit(ev.relative.x, ev.relative.y)
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			_preview.zoom(0.9)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_preview.zoom(1.1)

func _add_land_cards(filter: String, next_id: String) -> void:
	if controls == null: return
	for lo in Database.land_offers_by_type(filter):
		if not lo.has("id"): continue
		controls.add_child(_land_card(lo, next_id))

func _land_card(lo: Dictionary, next_id: String) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.13, 0.10, 0.95)
	sb.set_corner_radius_all(10); sb.set_content_margin_all(10)
	sb.set_border_width_all(1); sb.border_color = Color(1, 1, 1, 0.12)
	card.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	# Gambar (bila ada) atau ikon
	var img_path := String(lo.get("image", ""))
	if img_path != "" and ResourceLoader.exists(img_path):
		var tr := TextureRect.new()
		tr.texture = load(img_path)
		tr.custom_minimum_size = Vector2(90, 70)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		row.add_child(tr)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var title := Label.new()
	title.text = "%s — %s" % [lo.get("name", "?"), lo.get("land_class", "?")]
	title.add_theme_font_size_override("font_size", 14)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Panel cerita gelap — tema global memakai teks tinta gelap, wajib override terang.
	title.add_theme_color_override("font_color", Color(0.95, 0.95, 0.93))
	info.add_child(title)
	var desc := Label.new()
	desc.text = "%s\nRp%s · %.0f ha%s" % [lo.get("desc", ""), GameState._fmt(int(lo.get("price_rp", 0))),
		float(lo.get("size_ha", 1.0)), "  · perlu dibuka" if lo.get("needs_clearing", false) else ""]
	desc.add_theme_font_size_override("font_size", 11)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", Color(0.80, 0.83, 0.80))
	info.add_child(desc)

	var id := String(lo.get("id"))
	row.add_child(_btn("Pilih", func(): pick_land(id, next_id)))
	return card

# ---------------------------------------------------------------- Self-test (headless)
func _run_selftest() -> void:
	GameState.log_msg("=== SELFTEST CERITA ===")
	var start := Database.story_start(GameState.profile_id)
	goto(start)
	GameState.log_msg("start=%s" % start)
	# maju 2 narasi intro
	goto(Database.story_node(current_id).get("next", ""))
	goto(Database.story_node(current_id).get("next", ""))
	GameState.log_msg("di node: %s (harusnya invest_choice)" % current_id)
	choose(0)   # Pembibitan
	goto(Database.story_node(current_id).get("next", ""))  # jalur_pembibitan -> pembibitan_note
	goto(Database.story_node(current_id).get("next", ""))  # pembibitan_note -> land_type_choice
	GameState.log_msg("jalur=%s, node=%s" % [flags.get("jalur"), current_id])
	choose(0)   # Areal Hutan
	GameState.log_msg("tipe_lahan=%s, node=%s" % [flags.get("tipe_lahan"), current_id])
	pick_land("h_rawa", Database.story_node(current_id).get("next", ""))
	GameState.log_msg("lahan=%s class=%s price=%s node=%s" % [
		flags.get("lahan_id"), flags.get("land_class"), flags.get("land_price"), current_id])
	goto(Database.story_node(current_id).get("next", ""))  # preview_note -> preview3d
	goto(Database.story_node(current_id).get("next", ""))  # preview3d -> confirm
	GameState.log_msg("di node: %s (harusnya confirm)" % current_id)
	GameState.apply_story(flags)
	GameState.log_msg("APPLY -> land_acquired=%s land_class=%s sisa_modal=Rp%s jalur=%s" % [
		GameState.land_acquired, GameState.land_class, GameState._fmt(GameState.cash), GameState.story_flags.get("jalur")])
	GameState.log_msg("plot B1 setelah cerita: state=%s class=%s (hutan->buka, bersih->siap)" % [
		GameState.plots[0].get("state"), GameState.plots[0].get("land_class")])
	GameState.log_msg("=== SELFTEST CERITA SELESAI ===")
	get_tree().quit()
