extends Control
## Menu utama — design 2a: 2/3 atas slideshow (1a·1b·1c), 1/3 bawah tombol.
## Slideshow berganti otomatis tiap 5 detik; ketuk garis indikator untuk pindah.

const GAME    := "res://scenes/Main.tscn"
const PROFILE := "res://scenes/ProfileSelect.tscn"
const SLIDE_INTERVAL := 5.0
const SLIDES := 3

var _slide := 0
var _timer := 0.0
var _slides_node: Array = []
var _dots: Array = []

# ── headless shortcuts ────────────────────────────────────────────────────────
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.has("selftest"):
		GameState.start_new_game("anak_pengusaha")
		get_tree().call_deferred("change_scene_to_file", GAME); return
	if a.has("view3d") or a.has("shot3d"):
		GameState.start_new_game("pekerja_aktif")
		get_tree().call_deferred("change_scene_to_file", "res://scenes/Plantation3D.tscn"); return
	if a.has("shotpasca") or a.has("pascatest") or a.has("pascaharvest"):
		GameState.start_new_game("pekerja_aktif")
		get_tree().call_deferred("change_scene_to_file", "res://scenes/world/RantaiPascapanen.tscn"); return
	if a.has("shotshop"):
		GameState.start_new_game("pekerja_aktif")
		get_tree().call_deferred("change_scene_to_file", "res://scenes/CosmeticShop.tscn"); return
	if a.has("shotmain"):
		GameState.start_new_game("anak_pengusaha")
		get_tree().call_deferred("change_scene_to_file", GAME); return
	if a.has("shotprofile"):
		get_tree().call_deferred("change_scene_to_file", PROFILE); return
	if a.has("storytest") or a.has("shotstory") or a.has("shotpreview"):
		GameState.start_new_game("mahasiswa_pertanian")
		get_tree().call_deferred("change_scene_to_file", "res://scenes/Story.tscn"); return
	if a.has("shotdash"):
		GameState.start_new_game("pekerja_aktif"); GameState.seed_demo_kebun()
		get_tree().call_deferred("change_scene_to_file", "res://scenes/DashboardScreen.tscn"); return
	if a.has("shotland"):
		GameState.start_new_game("pekerja_aktif"); GameState.seed_demo_kebun()
		GameState.buy_target_plot = 5
		get_tree().call_deferred("change_scene_to_file", "res://scenes/LandMarket.tscn"); return
	if a.has("shotmerchant"):
		GameState.start_new_game("pekerja_aktif")
		get_tree().call_deferred("change_scene_to_file", "res://scenes/MerchantScreen.tscn"); return
	if a.has("shotharvest"):
		GameState.start_new_game("pekerja_aktif"); GameState.seed_demo_kebun()
		get_tree().call_deferred("change_scene_to_file", "res://scenes/HarvestScreen.tscn"); return
	for shot in [["shotcuaca","res://scenes/CuacaScreen.tscn"],
				 ["shotsosial","res://scenes/SosialScreen.tscn"],
				 ["shothof","res://scenes/HallOfFameScreen.tscn"],
				 ["shotlaporan","res://scenes/LaporanScreen.tscn"]]:
		if a.has(String(shot[0])):
			GameState.start_new_game("anak_pengusaha"); GameState.seed_demo_kebun()
			get_tree().call_deferred("change_scene_to_file", String(shot[1])); return
	if a.has("shotnursery"):
		GameState.start_new_game("pekerja_aktif")
		GameState.order_kecambah("marihat_ppks", 500); TimeManager.advance_day(35)
		get_tree().call_deferred("change_scene_to_file", "res://scenes/world/NurseryWorld3D.tscn"); return
	if a.has("shotworld") or a.has("worldtest") or a.has("shotcustom"):
		GameState.start_new_game("pekerja_aktif")
		if a.has("shotcustom"):
			GameState.cosmetics_applied["kostum"]    = "kos_pekerja"
			GameState.cosmetics_applied["kendaraan"] = "ken_pikap"
		get_tree().call_deferred("change_scene_to_file", "res://scenes/world/FarmWorld3D.tscn"); return

	_build_ui()
	if a.has("shotmenu"):
		call_deferred("_capture")
	elif a.has("shotmenu1"):
		_slide = 1; _refresh_slides(); call_deferred("_capture")
	elif a.has("shotmenu2"):
		_slide = 2; _refresh_slides(); call_deferred("_capture")

func _capture() -> void:
	await get_tree().create_timer(1.3).timeout
	get_viewport().get_texture().get_image().save_png("user://menu.png")
	print("[menu] screenshot saved"); get_tree().quit()

# ── build UI ──────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# ── zona slideshow (2/3 atas) ──────────────────────────────────────────
	var slide_host := Control.new()
	slide_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slide_host.size_flags_stretch_ratio = 2.0
	slide_host.clip_contents = true
	root.add_child(slide_host)

	_slides_node.append(_make_slide_photo(slide_host))
	_slides_node.append(_make_slide_grid(slide_host))
	_slides_node.append(_make_slide_poster(slide_host))

	slide_host.add_child(_make_dot_bar())

	# Pemisah
	var sep := ColorRect.new()
	sep.color = UIKit.INK
	sep.custom_minimum_size = Vector2(0, 2)
	root.add_child(sep)

	# ── zona tombol (1/3 bawah) ────────────────────────────────────────────
	var btn_zone := _make_button_zone()
	btn_zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn_zone.size_flags_stretch_ratio = 1.0
	root.add_child(btn_zone)

	_refresh_slides()

func _process(delta: float) -> void:
	if _slides_node.is_empty(): return
	_timer += delta
	if _timer >= SLIDE_INTERVAL:
		_timer = 0.0
		_go_slide((_slide + 1) % SLIDES)

# ── slide 0: foto + judul (design 1a) ─────────────────────────────────────────
func _make_slide_photo(host: Control) -> Control:
	var s := Control.new()
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(s)

	var ph := UIKit.photo("res://assets/bg/plantation.jpg", Vector2(0, 0), false)
	ph.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.add_child(ph)

	var sc := UIKit.scrim(0.30, 0.88)
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.add_child(sc)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 24)
	m.add_theme_constant_override("margin_right", 24)
	m.add_theme_constant_override("margin_bottom", 44)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.add_child(m)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.alignment = BoxContainer.ALIGNMENT_END
	m.add_child(v)

	v.add_child(UIKit.kicker("Simulator bisnis kebun",
		Color(UIKit.BG.r, UIKit.BG.g, UIKit.BG.b, 0.85)))
	v.add_child(UIKit.label("Kebun Sawit\nSimulator", 34, UIKit.BG, 800))

	var line := ColorRect.new()
	line.color = UIKit.ACCENT
	line.custom_minimum_size = Vector2(56, 4)
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(line)

	var sub := UIKit.label(
		"Tanam hari ini, panen di tahun ketiga.\nSetiap keputusan menentukan isi truk TBS-mu.",
		14, Color(UIKit.BG.r, UIKit.BG.g, UIKit.BG.b, 0.9))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	return s

# ── slide 1: grid karakter terang (design 1b) ─────────────────────────────────
func _make_slide_grid(host: Control) -> Control:
	var s := Control.new()
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.modulate.a = 0.0
	host.add_child(s)

	# Latar putih
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.add_child(bg)

	# Header bar: nama + tag musim
	var hdr_bg := ColorRect.new()
	hdr_bg.color = UIKit.BG
	hdr_bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hdr_bg.offset_bottom = 52
	s.add_child(hdr_bg)
	var hdr_line := ColorRect.new()
	hdr_line.color = UIKit.INK
	hdr_line.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hdr_line.offset_top = 50; hdr_line.offset_bottom = 52
	s.add_child(hdr_line)
	var hm := MarginContainer.new()
	hm.add_theme_constant_override("margin_left", 20)
	hm.add_theme_constant_override("margin_right", 20)
	hm.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hm.offset_bottom = 50
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 0)
	hm.add_child(hrow)
	var hl := UIKit.label("Kebun Sawit Sim", 15, UIKit.INK, 800)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(hl)
	hrow.add_child(UIKit.tag("Musim 2026", "accent"))
	s.add_child(hm)

	# Sub-header teks
	var sm := MarginContainer.new()
	sm.add_theme_constant_override("margin_left", 20)
	sm.add_theme_constant_override("margin_right", 20)
	sm.add_theme_constant_override("margin_top", 56)
	sm.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sm.offset_bottom = 170
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 5)
	sm.add_child(sv)
	sv.add_child(UIKit.kicker("Selamat datang kembali", UIKit.ACCENT_700))
	var big := UIKit.label("Sawit tidak menunggu.\nKebunmu juga.", 26, UIKit.INK, 800)
	big.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sv.add_child(big)
	var sub := UIKit.label(
		"Modal Rp100 juta, satu hektare, dan siklus panen 6 hari.",
		13, UIKit.N700)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sv.add_child(sub)
	s.add_child(sm)

	# Grid 3 karakter
	var grid_wrap := Control.new()
	grid_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid_wrap.offset_top = 172
	grid_wrap.clip_contents = true
	s.add_child(grid_wrap)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 0)
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.clip_contents = true
	grid_wrap.add_child(grid)

	for path in [
		"res://assets/characters/arman.png",
		"res://assets/characters/nadia.png",
		"res://assets/characters/bima.png"
	]:
		var cell := Control.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		cell.clip_contents = true
		var img := UIKit.photo(path, Vector2(0, 0), false)
		img.set_anchors_preset(Control.PRESET_FULL_RECT)
		cell.add_child(img)
		grid.add_child(cell)

	return s

# ── slide 2: poster merah (design 1c) ─────────────────────────────────────────
func _make_slide_poster(host: Control) -> Control:
	var s := Control.new()
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.modulate.a = 0.0
	host.add_child(s)

	# Background merah penuh
	var red := ColorRect.new()
	red.color = UIKit.ACCENT
	red.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.add_child(red)

	# Strip foto di bagian bawah
	var ph := UIKit.photo("res://assets/bg/plantation2.jpg", Vector2(0, 0), false)
	ph.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	ph.offset_top = -130
	s.add_child(ph)
	var ph_border := ColorRect.new()
	ph_border.color = UIKit.INK
	ph_border.custom_minimum_size = Vector2(0, 2)
	ph_border.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	ph_border.offset_top = -132; ph_border.offset_bottom = -130
	s.add_child(ph_border)

	# Teks
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 24)
	m.add_theme_constant_override("margin_right", 24)
	m.add_theme_constant_override("margin_top", 22)
	m.set_anchors_preset(Control.PRESET_TOP_WIDE)
	m.offset_bottom = 430
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	m.add_child(v)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	var k1 := UIKit.kicker("Kebun Sawit Simulator",
		Color(UIKit.BG.r, UIKit.BG.g, UIKit.BG.b, 0.85))
	k1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(k1)
	row.add_child(UIKit.kicker("v0.1", Color(UIKit.BG.r, UIKit.BG.g, UIKit.BG.b, 0.85)))
	v.add_child(row)

	var tagline := UIKit.label("Tanam.\nRawat.\nPanen.\nUlangi.", 52, UIKit.BG, 800)
	v.add_child(tagline)

	var divider := ColorRect.new()
	divider.color = UIKit.BG
	divider.custom_minimum_size = Vector2(0, 2)
	v.add_child(divider)

	var quote := UIKit.label(
		"Ganoderma tak bisa ditawar, hujan tak bisa dipesan.\nYang bisa kamu atur: keputusanmu.",
		14, Color(UIKit.BG.r, UIKit.BG.g, UIKit.BG.b, 0.9))
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(quote)
	s.add_child(m)
	return s

# ── dots indikator ─────────────────────────────────────────────────────────────
func _make_dot_bar() -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 24)
	m.add_theme_constant_override("margin_right", 24)
	m.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	m.offset_top = -34; m.offset_bottom = -14

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	m.add_child(hb)

	for i in SLIDES:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 20)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for st in ["normal", "hover", "pressed", "focus"]:
			btn.add_theme_stylebox_override(st, UIKit.box(Color(0,0,0,0), Color(0,0,0,0), 0, 0))

		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(0, 4)
		dot.set_anchors_preset(Control.PRESET_FULL_RECT)
		dot.offset_top = 8; dot.offset_bottom = -8
		dot.color = UIKit.ACCENT if i == 0 else Color(UIKit.BG.r, UIKit.BG.g, UIKit.BG.b, 0.55)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(dot)

		var idx := i
		btn.pressed.connect(func(): _go_slide(idx))
		hb.add_child(btn)
		_dots.append(dot)

	return m

# ── zona tombol (bawah) ────────────────────────────────────────────────────────
func _make_button_zone() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 24)
	m.add_theme_constant_override("margin_right", 24)
	m.add_theme_constant_override("margin_top", 14)
	m.add_theme_constant_override("margin_bottom", 20)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)
	scroll.add_child(m)

	if GameState.has_save():
		v.add_child(UIKit.btn("Lanjutkan  ›", _on_continue, "primary", 15, 52))
		v.add_child(UIKit.btn("Permainan baru", _on_new, "secondary", 14, 48))
	else:
		v.add_child(UIKit.btn("Permainan baru  ›", _on_new, "primary", 15, 52))

	v.add_child(UIKit.btn("Dashboard kebun (demo)", func():
		GameState.start_new_game("pekerja_aktif"); GameState.seed_demo_kebun()
		get_tree().change_scene_to_file("res://scenes/DashboardScreen.tscn"),
		"secondary", 14, 48))

	v.add_child(UIKit.btn("Jelajahi kebun 3D", func():
		GameState.start_new_game("pekerja_aktif"); GameState.seed_demo_kebun()
		get_tree().change_scene_to_file("res://scenes/world/FarmWorld3D.tscn"),
		"secondary", 14, 48))

	v.add_child(UIKit.btn("🌴 Siklus Tanaman Kelapa Sawit", func():
		GameState.start_new_game("pekerja_aktif")
		get_tree().change_scene_to_file("res://scenes/world/RantaiPascapanen.tscn"),
		"secondary", 14, 48))

	v.add_child(UIKit.btn("Keluar", func(): get_tree().quit(), "secondary", 14, 44))
	return scroll

# ── animasi slide ─────────────────────────────────────────────────────────────
func _go_slide(idx: int) -> void:
	if idx == _slide: return
	_slide = idx
	_timer = 0.0
	_refresh_slides()

func _refresh_slides() -> void:
	for i in _slides_node.size():
		var target := 1.0 if i == _slide else 0.0
		var tw := (_slides_node[i] as Control).create_tween()
		tw.tween_property(_slides_node[i], "modulate:a", target, 0.6)

	for i in _dots.size():
		var d := _dots[i] as ColorRect
		if d == null: continue
		d.color = UIKit.ACCENT if i == _slide else Color(UIKit.BG.r, UIKit.BG.g, UIKit.BG.b, 0.55)

func _on_new() -> void:
	get_tree().change_scene_to_file(PROFILE)

func _on_continue() -> void:
	if GameState.load_game():
		get_tree().change_scene_to_file("res://scenes/DashboardScreen.tscn")
