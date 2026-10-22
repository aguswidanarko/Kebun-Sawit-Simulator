extends Control
## Dashboard kebun (design handoff layar 1a) — light Modernist.
## Header foto + kartu karakter, strip statistik, kontrol waktu, Peta Blok 3x3,
## tab bar bawah, bottom-sheet blok (Ringkas/Pupuk/Semprot/Hama), toast.

var grid: GridContainer
var kicker_label: Label
var kname_label: Label
var saldo_val: Label
var weather_val: Label
var weather_icon_rect: TextureRect
var tbs_val: Label
var meta_ha: Label
var meta_need: Label
var _sheet: CanvasLayer
var _sheet_tab := "ringkas"
var _sheet_i := -1
var _nursery_holder: MarginContainer
var _ft_holder: MarginContainer
var _order_qty := 200
## Tab Pupuk: ikut mengaplikasikan pemupukan yang terlewat tahun ini?
var _fert_include_missed := false

func _ready() -> void:
	_build()
	GameState.cash_changed.connect(func(_c): _refresh())
	GameState.day_changed.connect(func(_d):
		_refresh()
		_show_fert_reminders())
	GameState.blocks_changed.connect(_refresh)
	GameState.cosmetics_changed.connect(_refresh)
	GameState.break_even_achieved.connect(_on_break_even)
	# Tutorial pertama kali masuk dashboard — hanya muncul jika ada lahan (bukan layar kosong awal).
	# Delay 0.2s agar layout selesai dihitung dulu sebelum overlay ditampilkan.
	if not GameState.tutorial_shown and not GameState.plots.is_empty():
		get_tree().create_timer(0.2).timeout.connect(_show_tutorial)
	# Cek apakah break-even sudah dicapai tapi belum ditampilkan (kalau player ada di scene lain saat break-even)
	call_deferred("_check_pending_breakeven")
	if OS.get_cmdline_user_args().has("shotdash"):
		call_deferred("_capture_dash")

func _capture_dash() -> void:
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png("user://dash.png")
	_open_sheet(2)   # plot dgn hama
	await get_tree().create_timer(0.6).timeout
	get_viewport().get_texture().get_image().save_png("user://sheet.png")
	_sheet_tab = "pupuk"   # tab jadwal pemupukan bulanan
	_render_sheet()
	await get_tree().create_timer(0.6).timeout
	get_viewport().get_texture().get_image().save_png("user://pupuk.png")
	_close_sheet()
	_open_plant_sheet(3)   # plot "siap" -> Tanam sheet
	await get_tree().create_timer(0.6).timeout
	get_viewport().get_texture().get_image().save_png("user://plant.png")
	print("[dash] screenshots saved")
	get_tree().quit()

# ---------------------------------------------------------------- build
func _build() -> void:
	var content := UIKit.screen_root(self, "Kebun")
	content.add_child(_header())

	# garis tema 4px (warna tema kosmetik — satu-satunya tempat warna kosmetik dipakai)
	var line := ColorRect.new()
	line.color = GameState.applied_accent()
	line.custom_minimum_size = Vector2(0, 4)
	content.add_child(line)

	content.add_child(_stats_strip())

	# kontrol waktu
	var tm := UIKit.margin(16, 12, 16, 12)
	var tc := HBoxContainer.new()
	tc.add_theme_constant_override("separation", 8)
	var b1 := UIKit.btn("Lanjut 1 hari  ›", func(): TimeManager.advance_day(1))
	b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tc.add_child(b1)
	var b15 := UIKit.btn("Lanjut 15 hari  »", func(): TimeManager.advance_day(15), "primary")
	b15.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tc.add_child(b15)
	tm.add_child(tc)
	content.add_child(tm)

	# kartu pembibitan (tahapan PN/MN sesuai dokumen; dibangun ulang tiap refresh)
	_nursery_holder = UIKit.margin(16, 0, 16, 4)
	content.add_child(_nursery_holder)

	# Tombol Tugas Lapangan — DI BAWAH pembibitan, DI ATAS peta blok.
	# Merah ("primary") karena hanya ditampilkan saat tugas memang tersedia:
	# syaratnya user sudah punya lahan DAN lahan itu sudah ditanam sawit.
	# Visibilitas diatur ulang tiap _refresh() (lihat _field_tasks_available).
	_ft_holder = UIKit.margin(16, 4, 16, 8)
	var ft_btn := UIKit.btn("Tugas Lapangan  ›",
		func(): get_tree().change_scene_to_file("res://scenes/FieldTasksScreen.tscn"),
		"primary", 14, 44)
	ft_btn.icon = load("res://assets/ui/icons/gamepad-2.svg")
	_ft_holder.add_child(ft_btn)
	content.add_child(_ft_holder)

	# judul peta
	var pm := UIKit.margin(16, 4, 16, 8)
	var ph := HBoxContainer.new()
	var ttl := UIKit.label("Peta Blok", 17, UIKit.INK, 800)
	ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph.add_child(ttl)
	meta_ha = UIKit.meta("")
	ph.add_child(meta_ha)
	meta_need = UIKit.label("", 11, UIKit.ACCENT_700, 600)
	ph.add_child(meta_need)
	pm.add_child(ph)
	content.add_child(pm)

	# grid 3x3 (gap 2px di atas warna divider + border 2px)
	var gm := UIKit.margin(16, 0, 16, 0)
	var gp := PanelContainer.new()
	gp.add_theme_stylebox_override("panel", UIKit.box(UIKit.GRIDLINE, UIKit.GRIDLINE, 0, 2))
	grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	gp.add_child(grid)
	gm.add_child(gp)
	content.add_child(gm)

	# legenda
	var lm := UIKit.margin(16, 8, 16, 8)
	var leg := UIKit.wrap(UIKit.meta("TM menghasilkan · TBM belum menghasilkan · ★ Golden Tree"))
	lm.add_child(leg)
	content.add_child(lm)

	_refresh()

func _header() -> Control:
	var hdr := Control.new()
	hdr.custom_minimum_size = Vector2(0, 200)
	var ph := UIKit.photo("res://assets/bg/plantation.jpg", Vector2(0, 0), false)
	ph.set_anchors_preset(Control.PRESET_FULL_RECT)
	hdr.add_child(ph)
	var sc := UIKit.scrim()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	hdr.add_child(sc)
	var m := UIKit.margin(16, 14, 16, 14)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	hdr.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	m.add_child(v)

	var prof := Database.get_profile(GameState.profile_id)

	# BARIS 1: tombol ikon, lebar dibagi rata selebar layar — pola yang sama
	# dengan tab bar bawah (UIKit.tabbar) supaya posisinya TIDAK pernah
	# bergeser seberapa pun panjang nama kebun.
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	for spec in [
		["user", func(): get_tree().change_scene_to_file("res://scenes/ProfileScreen.tscn")],
		["shirt", func(): get_tree().change_scene_to_file("res://scenes/CharacterCustomization.tscn")],
		["shopping-bag", func(): get_tree().change_scene_to_file("res://scenes/CosmeticShop.tscn")],
		["star", func(): get_tree().change_scene_to_file("res://scenes/HallOfFameScreen.tscn")],
		["shopping-basket", func(): get_tree().change_scene_to_file("res://scenes/IAPScreen.tscn")],
		["menu", func():
			GameState.save_game()
			get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")],
	]:
		var b := _icon_btn(String(spec[0]), spec[1] as Callable)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_stretch_ratio = 1.0
		btn_row.add_child(b)
	v.add_child(btn_row)

	# BARIS 2: tahun/hari/kesulitan + nama kebun, disusun DI BAWAH tombol.
	# autowrap dipasang supaya nama kebun yang panjang turun baris, bukan
	# melebar ke luar layar.
	var tl := VBoxContainer.new()
	tl.add_theme_constant_override("separation", 2)
	kicker_label = UIKit.kicker("", Color(UIKit.BG.r, UIKit.BG.g, UIKit.BG.b, 0.85))
	kicker_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.add_child(kicker_label)
	kname_label = UIKit.label("", 26, UIKit.BG, 800)
	kname_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.add_child(kname_label)
	v.add_child(tl)

	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)

	# kartu karakter kiri bawah
	var card := HBoxContainer.new()
	card.add_theme_constant_override("separation", 10)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(60, 76)
	frame.add_theme_stylebox_override("panel", UIKit.box(UIKit.INK, UIKit.BG, 2, 0))
	var inner := Control.new()
	inner.custom_minimum_size = Vector2(56, 72)
	inner.clip_contents = true
	var por := UIKit.photo(String(prof.get("portrait", "")), Vector2(0, 0), false)
	por.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.add_child(por)
	var rar := UIKit.tag(String(prof.get("rarity", "SR")), "fill")
	rar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	rar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	inner.add_child(rar)
	frame.add_child(inner)
	card.add_child(frame)
	var ci := VBoxContainer.new()
	ci.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ci.add_theme_constant_override("separation", 1)
	ci.add_child(UIKit.kicker(String(prof.get("role_tag", "")), Color(UIKit.BG.r, UIKit.BG.g, UIKit.BG.b, 0.8)))
	ci.add_child(UIKit.label(String(prof.get("short_name", prof.get("name", "?"))), 17, UIKit.BG, 800))
	var buff := UIKit.label(String(prof.get("buff_text", "")), 11, Color(UIKit.BG.r, UIKit.BG.g, UIKit.BG.b, 0.85))
	buff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ci.add_child(buff)
	card.add_child(ci)
	v.add_child(card)
	return hdr

func _icon_btn(icon_name: String, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(36, 36)
	b.add_theme_stylebox_override("normal", UIKit.box(Color(0, 0, 0, 0), Color(0.953, 0.949, 0.949, 0.55), 1, 4))
	b.add_theme_stylebox_override("hover", UIKit.box(Color(1, 1, 1, 0.12), UIKit.BG, 1, 4))
	b.add_theme_stylebox_override("pressed", UIKit.box(Color(1, 1, 1, 0.2), UIKit.BG, 1, 4))
	var ic := UIKit.icon(icon_name, 18, UIKit.BG)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.set_anchors_preset(Control.PRESET_CENTER)
	ic.position = Vector2(-9, -9)
	b.add_child(ic)
	b.pressed.connect(cb)
	return b

func _stats_strip() -> Control:
	var strip := PanelContainer.new()
	var sb := UIKit.box(UIKit.BG, UIKit.INK, 0, 0)
	sb.border_width_bottom = 2
	strip.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	strip.add_child(h)
	saldo_val = UIKit.label("", 18, UIKit.INK, 800)
	weather_val = UIKit.label("", 15, UIKit.INK, 800)
	tbs_val = UIKit.label("", 18, UIKit.INK, 800)
	weather_icon_rect = UIKit.icon("sun", 15, UIKit.INK)
	var weather_row := HBoxContainer.new()
	weather_row.add_theme_constant_override("separation", 4)
	weather_row.add_child(weather_icon_rect)
	weather_row.add_child(weather_val)
	var cells := [
		["Saldo", saldo_val, 1.3, Callable()],
		["Cuaca", weather_row, 1.0, func(): get_tree().change_scene_to_file("res://scenes/CuacaScreen.tscn")],
		["TBS siap", tbs_val, 1.0, func(): get_tree().change_scene_to_file("res://scenes/HarvestScreen.tscn")],
	]
	for i in cells.size():
		if i > 0:
			h.add_child(UIKit.vrule())
		var c = cells[i]
		var mc := UIKit.margin(16, 12, 16, 12)
		mc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mc.size_flags_stretch_ratio = float(c[2])
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 3)
		var lab := UIKit.label(String(c[0]).to_upper(), 10, UIKit.N700, 600)
		cv.add_child(lab)
		cv.add_child(c[1])
		mc.add_child(cv)
		if c[3] is Callable and not (c[3] as Callable).is_null():
			mc.mouse_filter = Control.MOUSE_FILTER_STOP
			mc.gui_input.connect(func(ev):
				if ev is InputEventMouseButton and ev.pressed:
					(c[3] as Callable).call())
		h.add_child(mc)
	return strip

# ---------------------------------------------------------------- refresh
func _refresh() -> void:
	if grid == null:
		return
	var tbs := 0.0
	var need := 0
	var ha := 0
	for p in GameState.plots:
		if p.get("state") != "kosong":
			ha += 1
		if p.get("state") == "tanam":
			tbs += _tbs_est(p)
			if _problem(p):
				need += 1
	saldo_val.text = UIKit.rp_short(GameState.cash)
	weather_val.text = GameState.weather.capitalize()
	weather_icon_rect.texture = load("res://assets/ui/icons/%s.svg" % UIKit.weather_icon(GameState.weather))
	tbs_val.text = ("%.1f t" % (tbs / 1000.0)).replace(".", ",")
	var diff_suffix := ""
	if GameState.difficulty != "normal":
		var dlabels := {"sulit": " · ⚠ SULIT", "krisis": " · 🔥 KRISIS"}
		diff_suffix = dlabels.get(GameState.difficulty, "")
	kicker_label.text = "TAHUN %d · HARI %d%s" % [1 + (GameState.day - 1) / 365, 1 + (GameState.day - 1) % 365, diff_suffix]
	kname_label.text = GameState.display_kebun_name()
	meta_ha.text = "%d ha" % ha + (" · " if need > 0 else "")
	meta_need.text = ("%d perlu tindakan" % need) if need > 0 else ""
	# Tugas Lapangan hanya tampil kalau sudah ada lahan yang ditanam sawit.
	if _ft_holder != null:
		_ft_holder.visible = GameState.has_planted_land()
	_rebuild_nursery()
	_rebuild_grid()

## Prompt reminder pemupukan, satu per satu (blok pertama dulu; blok kedua
## baru muncul setelah user menekan OK). Dipanggil tiap hari berganti —
## termasuk saat melompat 15 hari, sehingga jadwal yang terlewati tetap
## ditampilkan berurutan.
func _show_fert_reminders() -> void:
	var items := GameState.collect_fert_reminders()
	if items.is_empty():
		return
	UIKit.prompt_queue(self, items)

# ---------------------------------------------------------------- pembibitan
func _rebuild_nursery() -> void:
	if _nursery_holder == null:
		return
	for c in _nursery_holder.get_children():
		c.queue_free()
	var nur: Dictionary = GameState.nursery
	var card := PanelContainer.new()
	var urgent := false
	var p: Dictionary = GameState.npar()
	if not nur.is_empty() and String(nur.get("stage", "")) == "pn" \
			and GameState.nursery_age_months() >= int(p.get("mn_prep_due_month", 2)) \
			and not bool(nur.get("mn_prepared", false)):
		urgent = true
	card.add_theme_stylebox_override("panel",
		UIKit.box(UIKit.ACCENT_100 if urgent else UIKit.SURFACE, UIKit.DIVIDER, 1, 12))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var top := HBoxContainer.new()
	var kick := UIKit.kicker("Pembibitan")
	kick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(kick)
	v.add_child(top)

	if nur.is_empty():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var t := UIKit.label("Belum ada bibitan", 13, UIKit.INK, 800)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		v.add_child(row)
		v.add_child(UIKit.wrap(UIKit.meta("Kecambah tidak bisa langsung ditanam ke lapangan — bibitkan 12 bulan dulu, atau beli bibit jadi saat menanam blok.")))
		var start_btn := UIKit.btn("Mulai pembibitan — pesan kecambah", _open_order_sheet, "primary")
		start_btn.icon = load("res://assets/ui/icons/sprout.svg")
		start_btn.add_theme_color_override("icon_normal_color", UIKit.BG)
		v.add_child(start_btn)
		_nursery_holder.add_child(card)
		return

	var seed := Database.get_seed(String(nur.get("seed_id", "")))
	var qty := int(nur.get("qty", 0))
	var m := GameState.nursery_age_months()
	match String(nur.get("stage", "")):
		"pesan":
			var sisa: int = max(0, int(p.get("order_days", 30)) - (GameState.day - int(nur.get("order_day", GameState.day))))
			v.add_child(UIKit.label("Kecambah dalam perjalanan", 13, UIKit.INK, 800))
			v.add_child(UIKit.bar(1.0 - float(sisa) / max(1.0, float(p.get("order_days", 30))), UIKit.INK))
			v.add_child(UIKit.wrap(UIKit.meta("%s ×%d · tiba ±%d hari lagi · areal bibitan sedang disiapkan" % [
				seed.get("variety_name", "?"), qty, sisa])))
		"pn":
			v.add_child(UIKit.wrap(UIKit.label("Pre Nursery — umur %d bln (%s)" % [m, "%d daun" % clampi(m, 0, 3) if m > 0 else "baru tanam"], 13, UIKit.INK, 800)))
			v.add_child(UIKit.bar(float(m) / 3.0, UIKit.INK))
			v.add_child(UIKit.wrap(UIKit.meta("%s · %d bibit · transplanting ke MN umur 3 bln" % [seed.get("variety_name", "?"), qty])))
			if not bool(nur.get("mn_prepared", false)):
				if urgent:
					v.add_child(UIKit.wrap(UIKit.label("⚠ Wajib siapkan Main Nursery sebelum umur 3 bulan!", 12, UIKit.ACCENT_800, 600)))
				v.add_child(UIKit.btn("Siapkan Main Nursery — Rp%s" % GameState._fmt(int(p.get("prep_mn_cost_rp", 2000000))),
					func(): UIKit.toast(self, GameState.prepare_mn()), "primary" if urgent else "secondary"))
			else:
				v.add_child(UIKit.meta("✓ Main Nursery siap — transplanting otomatis umur 3 bln"))
		"mn":
			v.add_child(UIKit.wrap(UIKit.label("Main Nursery — umur %d bln" % m, 13, UIKit.INK, 800)))
			v.add_child(UIKit.bar(float(m) / 12.0, UIKit.INK))
			var next_sel := "final 12 bln"
			for sm in p.get("selection_points_mn", [6, 9]):
				if m < int(sm):
					next_sel = "%d bln" % int(sm)
					break
			v.add_child(UIKit.wrap(UIKit.meta("%s · %d bibit · seleksi berikut: umur %s · siap umur 12 bln" % [
				seed.get("variety_name", "?"), qty, next_sel])))
		"siap":
			v.add_child(UIKit.wrap(UIKit.label("🌱 %d bibit siap tanam" % qty, 14, UIKit.INK, 800)))
			v.add_child(UIKit.wrap(UIKit.meta("%s · lolos seleksi final · tanam ke blok 'Lahan siap' (143/blok) atau jual" % seed.get("variety_name", "?"))))
			var row2 := HBoxContainer.new()
			row2.add_theme_constant_override("separation", 8)
			var bj := UIKit.btn("Jual bibit", _open_sell_sheet, "primary")
			bj.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row2.add_child(bj)
			v.add_child(row2)
	if String(nur.get("stage", "")) != "pesan":
		var explore := UIKit.btn("Jelajahi Bibitan 3D", func():
			get_tree().change_scene_to_file("res://scenes/world/NurseryWorld3D.tscn"), "secondary")
		explore.icon = load("res://assets/ui/icons/gamepad-2.svg")
		v.add_child(explore)
	_nursery_holder.add_child(card)

## Sheet pesan kecambah: pilih jumlah + varietas.
func _open_order_sheet() -> void:
	var sheet := _sheet_base()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	sheet.add_child(v)
	var hr := HBoxContainer.new()
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UIKit.kicker("Pembibitan · tahap 1"))
	hv.add_child(UIKit.label("Pesan Kecambah", 24, UIKit.INK, 800))
	hr.add_child(hv)
	hr.add_child(UIKit.close_btn(_close_sheet))
	v.add_child(hr)
	var prep := int(GameState.npar().get("prep_pn_cost_rp", 1500000))
	v.add_child(UIKit.wrap(UIKit.meta("Tiba ±30 hari. Termasuk persiapan areal Rp%s: pompa & saluran air, media tanah, polybag kecil, naungan. Seleksi ±2%% di tiap tahap." % GameState._fmt(prep), 12)))
	var segr := HBoxContainer.new()
	segr.add_theme_constant_override("separation", 8)
	for q in [200, 500, 1000]:
		var qq := int(q)
		var s := UIKit.seg("%d butir" % qq, _order_qty == qq, func():
			_order_qty = qq
			_open_order_sheet())
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segr.add_child(s)
	v.add_child(segr)
	v.add_child(UIKit.rule())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for seed in Database.seeds:
		if not seed.has("seed_id"):
			continue
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UIKit.box(UIKit.SURFACE, UIKit.DIVIDER, 1, 10))
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 4)
		card.add_child(cv)
		cv.add_child(UIKit.label(String(seed.get("variety_name", "?")), 14, UIKit.INK, 800))
		cv.add_child(UIKit.wrap(UIKit.meta("kecambah Rp%s/butir · plafon %s t · %s" % [
			GameState._fmt(int(seed.get("price_per_seed_rp", 0))),
			str(seed.get("max_tbs_ton_ha_year", 0)), seed.get("certification_status", "")])))
		var total := int(seed.get("price_per_seed_rp", 0)) * _order_qty + prep
		var sid := String(seed.get("seed_id"))
		cv.add_child(UIKit.btn("Pesan %d butir — Rp%s" % [_order_qty, GameState._fmt(total)], func():
			UIKit.toast(self, GameState.order_kecambah(sid, _order_qty))
			_close_sheet(), "primary"))
		list.add_child(card)

## Sheet jual bibit siap.
func _open_sell_sheet() -> void:
	var sheet := _sheet_base()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	sheet.add_child(v)
	var qty := int(GameState.nursery.get("qty", 0))
	var price := GameState.bibit_sell_price()
	var hr := HBoxContainer.new()
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UIKit.kicker("Pembibitan · bibit siap"))
	hv.add_child(UIKit.label("Jual Bibit", 24, UIKit.INK, 800))
	hr.add_child(hv)
	hr.add_child(UIKit.close_btn(_close_sheet))
	v.add_child(hr)
	v.add_child(UIKit.wrap(UIKit.meta("Sisa %d bibit · harga Rp%s/batang. Seleksi terakhir memastikan hanya bibit berkualitas yang dijual." % [qty, GameState._fmt(price)], 12)))
	v.add_child(UIKit.rule())
	var opts: Array = []
	for q in [50, 100, qty]:
		var qq: int = min(int(q), qty)
		if qq > 0 and not opts.has(qq):
			opts.append(qq)
	for q2 in opts:
		var qq2 := int(q2)
		v.add_child(UIKit.btn("Jual %d bibit — Rp%s" % [qq2, GameState._fmt(qq2 * price)], func():
			UIKit.toast(self, GameState.sell_bibit(qq2))
			_close_sheet(), "primary" if qq2 == qty else "secondary"))

func _rebuild_grid() -> void:
	for c in grid.get_children():
		c.queue_free()
	for i in GameState.plots.size():
		grid.add_child(_cell(i))

func _cell(i: int) -> PanelContainer:
	var p: Dictionary = GameState.plots[i]
	var state := String(p.get("state", "kosong"))
	var problem := state == "tanam" and _problem(p)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 112)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := UIKit.BG
	if problem:
		bg = UIKit.ACCENT_100
	elif state != "kosong":
		bg = UIKit.SURFACE
	card.add_theme_stylebox_override("panel", UIKit.box(bg, Color(0, 0, 0, 0), 0, 8))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_on_cell(i))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	card.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	var id := UIKit.label(String(p.get("id")), 17, UIKit.INK if state != "kosong" else UIKit.N500, 800)
	id.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(id)
	# badge kelas lahan (S1/S2/S3) — hasil penilaian saat lahan dibeli
	if state != "kosong":
		var lc := String(p.get("land_class", "S1"))
		var kcol := UIKit.INK
		if lc == "S2":
			kcol = UIKit.N600
		elif lc == "S3":
			kcol = UIKit.ACCENT_700
		top.add_child(UIKit.label(lc, 10, kcol, 800))
	v.add_child(top)
	match state:
		"tanam":
			var seed := Database.get_seed(String(p.get("seed_id", "")))
			var agef := float(GameState.day - int(p.get("planting_day", GameState.day))) / 365.0
			var fase := "TM" if int(agef) >= int(seed.get("start_harvest_age_year", 4)) else "TBM"
			top.add_child(UIKit.label(fase, 10, UIKit.N700, 600))
			v.add_child(UIKit.meta("%s · %s th" % [_short_variety(seed), ("%.1f" % agef).replace(".", ",")]))
			var hp := float(p.get("health", 1.0))
			var hrow := HBoxContainer.new()
			var hl := UIKit.meta("Sehat")
			hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hrow.add_child(hl)
			hrow.add_child(UIKit.label("%d%%" % int(round(hp * 100)), 12, UIKit.INK, 800))
			v.add_child(hrow)
			v.add_child(UIKit.bar(hp, UIKit.ACCENT if hp < 0.7 else UIKit.INK))
			var tags := HFlowContainer.new()
			tags.add_theme_constant_override("h_separation", 4)
			tags.add_theme_constant_override("v_separation", 4)
			var pest = p.get("pest")
			if pest != null:
				var cat := Database.get_pest(String(pest.get("id", "")))
				var nm := _short_pest_name(String(cat.get("name", "?"))) if bool(pest.get("diagnosed", false)) else "Gejala?"
				tags.add_child(UIKit.tag(nm, "fill"))
			if float(p.get("weed_level", 0)) > 0.5:
				tags.add_child(UIKit.tag("Gulma", "accent"))
			var t := _tbs_est(p)
			if t >= 100.0:
				tags.add_child(UIKit.tag(("%.1f t" % (t / 1000.0)).replace(".", ","), "ink"))
			if int(p.get("golden_count", 0)) > 0:
				tags.add_child(UIKit.label("★%d" % int(p.get("golden_count")), 11, UIKit.ACCENT, 800))
			v.add_child(tags)
		"buka":
			v.add_child(UIKit.meta("Pembukaan lahan", 12))
			var prog: float = 1.0 - float(p.get("clear", 1)) / max(1.0, float(p.get("clear0", 1)))
			v.add_child(UIKit.bar(prog, UIKit.INK))
			v.add_child(UIKit.meta("%d hari lagi" % int(p.get("clear", 0))))
		"siap":
			v.add_child(UIKit.meta("Lahan siap", 12))
			v.add_child(UIKit.label("+ Tanam bibit", 12, UIKit.ACCENT_700, 600))
		_:
			var sp2 := Control.new()
			sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
			v.add_child(sp2)
			v.add_child(UIKit.label("+ Beli lahan", 12, UIKit.N600, 600))
	return card

func _short_variety(seed: Dictionary) -> String:
	var nm := String(seed.get("variety_name", "?"))
	return nm.split(" ")[0] if nm.length() > 12 else nm

## Nama hama katalog kadang berisi keterangan dalam kurung (mis. "Kumbang Daun (Leaf beetle)")
## yang terlalu panjang untuk badge kartu blok — pangkas agar lebar kartu tetap simetris.
func _short_pest_name(nm: String) -> String:
	var paren := nm.find(" (")
	return nm.substr(0, paren) if paren != -1 else nm

# ---------------------------------------------------------------- aksi sel
func _on_cell(i: int) -> void:
	var p: Dictionary = GameState.plots[i]
	match String(p.get("state", "kosong")):
		"tanam": _open_sheet(i)
		"siap": _open_plant_sheet(i)
		"kosong":
			GameState.buy_target_plot = i
			get_tree().change_scene_to_file("res://scenes/LandMarket.tscn")
		"buka": UIKit.toast(self, "Pembukaan lahan: %d hari lagi." % int(p.get("clear", 0)))

func _problem(p: Dictionary) -> bool:
	return p.get("pest") != null or float(p.get("weed_level", 0)) > 0.5 or float(p.get("health", 1)) < 0.7

func _tbs_est(b: Dictionary) -> float:
	return Agronomy.tbs_batch_kg(b)

# ---------------------------------------------------------------- bottom sheet
func _sheet_base() -> PanelContainer:
	SoundManager.open_sheet()
	if _sheet:
		_sheet.queue_free()
	_sheet = CanvasLayer.new()
	add_child(_sheet)
	var backdrop := ColorRect.new()
	backdrop.color = Color(UIKit.INK.r, UIKit.INK.g, UIKit.INK.b, 0.5)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_close_sheet())
	_sheet.add_child(backdrop)
	var sheet := PanelContainer.new()
	sheet.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sheet.offset_top = -620
	var sb := UIKit.box(UIKit.BG, UIKit.INK, 0, 16)
	sb.border_width_top = 2
	sheet.add_theme_stylebox_override("panel", sb)
	_sheet.add_child(sheet)
	return sheet

func _open_sheet(i: int) -> void:
	_sheet_i = i
	_sheet_tab = "ringkas"
	_fert_include_missed = false
	_render_sheet()

func _close_sheet() -> void:
	SoundManager.close_sheet()
	if _sheet:
		_sheet.queue_free()
		_sheet = null
	_sheet_i = -1
	_refresh()

# --- Tanam (design 1j) ---
func _open_plant_sheet(i: int) -> void:
	var sheet := _sheet_base()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	sheet.add_child(v)
	var hr := HBoxContainer.new()
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UIKit.kicker("Tanam bibit"))
	hv.add_child(UIKit.label(String(GameState.plots[i].get("id", "B?")), 26, UIKit.INK, 800))
	hr.add_child(hv)
	hr.add_child(UIKit.close_btn(_close_sheet))
	v.add_child(hr)
	v.add_child(UIKit.wrap(UIKit.meta("Yang ditanam ke lapangan adalah BIBIT umur 12 bln (bukan kecambah) · 143 pokok/ha · kelas lahan %s" % GameState.plots[i].get("land_class", "S1"), 12)))
	v.add_child(UIKit.rule())
	# Opsi 1: bibit dari bibitan sendiri (bila siap & cukup)
	var nur: Dictionary = GameState.nursery
	if String(nur.get("stage", "")) == "siap":
		var nqty := int(nur.get("qty", 0))
		var nseed := Database.get_seed(String(nur.get("seed_id", "")))
		var own := PanelContainer.new()
		own.add_theme_stylebox_override("panel", UIKit.box(UIKit.BG, UIKit.INK, 2, 10))
		var ov := VBoxContainer.new()
		ov.add_theme_constant_override("separation", 4)
		own.add_child(ov)
		ov.add_child(UIKit.kicker("Dari bibitan sendiri", UIKit.N700))
		ov.add_child(UIKit.label("%s — sisa %d bibit" % [nseed.get("variety_name", "?"), nqty], 14, UIKit.INK, 800))
		if nqty >= 143:
			ov.add_child(UIKit.btn("Tanam 143 bibit sendiri — gratis", func():
				if GameState.plant_from_nursery(i):
					UIKit.toast(self, "Ditanam dari bibitan sendiri di B%d." % (i + 1))
					_close_sheet(), "primary"))
		else:
			ov.add_child(UIKit.wrap(UIKit.meta("Kurang dari 143 — jual sisanya atau beli bibit jadi di bawah.")))
		v.add_child(own)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 340)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for seed in Database.seeds:
		if not seed.has("seed_id"):
			continue
		list.add_child(_seed_card(i, seed))

func _seed_card(i: int, seed: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.box(UIKit.SURFACE, UIKit.DIVIDER, 1, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	v.add_child(UIKit.label(String(seed.get("variety_name", "?")), 14, UIKit.INK, 800))
	v.add_child(UIKit.wrap(UIKit.meta("plafon %s t · rendemen %.1f%% · panen umur %d th · %s" % [
		str(seed.get("max_tbs_ton_ha_year", 0)), float(seed.get("rendemen_pct", 0)),
		int(seed.get("start_harvest_age_year", 4)), seed.get("certification_status", "")])))
	var cost := GameState.bibit_price(seed) * 143
	var sid := String(seed.get("seed_id"))
	var b := UIKit.btn("Beli bibit jadi & tanam — Rp%s" % GameState._fmt(cost), func():
		if GameState.plant_plot(i, sid):
			UIKit.toast(self, "Ditanam %s di B%d." % [seed.get("variety_name"), i + 1])
			_close_sheet()
		else:
			UIKit.toast(self, "Dana tidak cukup (Rp%s)." % GameState._fmt(cost)), "primary")
	v.add_child(b)
	return card

# --- Panel blok (design 1b-1f) ---
func _render_sheet() -> void:
	if _sheet_i < 0:
		return
	var p: Dictionary = GameState.plots[_sheet_i]
	var seed := Database.get_seed(String(p.get("seed_id", "")))
	var sheet := _sheet_base()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	sheet.add_child(v)

	# header
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 12)
	hr.add_child(UIKit.label(String(p.get("id")), 36, UIKit.INK, 800))
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_theme_constant_override("separation", 1)
	hv.add_child(UIKit.label(String(seed.get("variety_name", "?")), 15, UIKit.INK, 800))
	var agef := float(GameState.day - int(p.get("planting_day", GameState.day))) / 365.0
	var fase := "TM" if int(agef) >= int(seed.get("start_harvest_age_year", 4)) else "TBM"
	hv.add_child(UIKit.meta("%s · %s th · sehat %.0f%%" % [fase, ("%.1f" % agef).replace(".", ","), float(p.get("health", 1)) * 100]))
	hr.add_child(hv)
	hr.add_child(UIKit.close_btn(_close_sheet))
	v.add_child(hr)

	# tab 4 kolom underline
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 0)
	var pest_dot := " •" if p.get("pest") != null else ""
	for t in [["ringkas", "Ringkas"], ["pupuk", "Pupuk"], ["semprot", "Semprot"], ["hama", "Hama" + pest_dot]]:
		var tid := String(t[0])
		var active := _sheet_tab == tid
		var b := Button.new()
		b.text = String(t[1])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_font_override("font", UIKit.bold() if active else UIKit.semi())
		b.add_theme_color_override("font_color", UIKit.INK if active else UIKit.N600)
		b.add_theme_color_override("font_hover_color", UIKit.INK)
		var tsb := UIKit.box(Color(0, 0, 0, 0), UIKit.ACCENT if active else UIKit.DIVIDER, 0, 8)
		tsb.border_width_bottom = 3 if active else 1
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, tsb)
		b.pressed.connect(func():
			_sheet_tab = tid
			_render_sheet())
		tabs.add_child(b)
	v.add_child(tabs)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)

	match _sheet_tab:
		"ringkas": _tab_ringkas(body, p, seed)
		"pupuk": _tab_pupuk(body, p)
		"semprot": _tab_semprot(body, p)
		"hama": _tab_hama(body, p)

func _metric(label_txt: String, val: String, problem := false) -> Control:
	var c := VBoxContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_theme_constant_override("separation", 2)
	c.add_child(UIKit.label(label_txt.to_upper(), 10, UIKit.N700, 600))
	c.add_child(UIKit.label(val, 16, UIKit.ACCENT_700 if problem else UIKit.INK, 800))
	return c

func _tab_ringkas(v: VBoxContainer, p: Dictionary, _seed: Dictionary) -> void:
	var enter := UIKit.btn("Masuk blok · mode lapangan", func():
		GameState.active_plot = _sheet_i
		get_tree().change_scene_to_file("res://scenes/world/FarmWorld3D.tscn"), "primary", 15, 52)
	enter.icon = load("res://assets/ui/icons/gamepad-2.svg")
	enter.add_theme_color_override("icon_normal_color", UIKit.BG)
	v.add_child(enter)
	var hp := float(p.get("health", 1))
	var weed := float(p.get("weed_level", 0))
	var fert_days := GameState.day - int(p.get("last_fertilize_day", GameState.day))
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 10)
	g.add_child(_metric("Sehat", "%.0f%%" % (hp * 100), hp < 0.7))
	g.add_child(_metric("Gulma", "%.0f%%" % (weed * 100), weed > 0.5))
	g.add_child(_metric("Hama", "Ada" if p.get("pest") != null else "—", p.get("pest") != null))
	g.add_child(_metric("Pupuk", "%d hr" % fert_days, fert_days > 120))
	g.add_child(_metric("Golden", "★%d" % int(p.get("golden_count", 0))))
	g.add_child(_metric("TBS", ("%.1f t" % (_tbs_est(p) / 1000.0)).replace(".", ",")))
	v.add_child(g)
	v.add_child(UIKit.wrap(UIKit.meta("Estimasi produksi rotasi ini ~%.0f kg (ikut kesehatan & umur)." % _tbs_est(p), 12)))
	if TimeManager.harvest_due(p) and _tbs_est(p) > 0.0:
		v.add_child(UIKit.wrap(UIKit.label("⚠ TBS matang — segera panen, kalau tidak akan membusuk & tonasenya hilang.", 11, UIKit.ACCENT_700, 600)))
		var kg := _tbs_est(p)
		var net := int(kg * Actions._price(_seed, hp, "pengepul")) - Agronomy.labor_cost("panen", float(p.get("area_ha", 1.0)))
		v.add_child(UIKit.btn("🌾 Panen Otomatis — Rp%s" % GameState._fmt(max(0, net)), func():
			_do(Actions.harvest(p)), "primary"))
		v.add_child(UIKit.wrap(UIKit.meta("Atau masuk blok & panen manual sendiri — hasilnya 10% lebih tinggi drpd panen otomatis.", 11)))
	elif bool(p.get("harvest_bonus_available", false)):
		v.add_child(UIKit.wrap(UIKit.label("Panen otomatis blok ini sudah diambil. Masuk blok untuk ambil sisa 10% secara manual.", 11, UIKit.ACCENT_700, 600)))
	for t in [["Pupuk blok ini  ›", "pupuk"], ["Semprot gulma  ›", "semprot"], ["Periksa hama  ›", "hama"]]:
		var tid := String(t[1])
		v.add_child(UIKit.btn(String(t[0]), func():
			_sheet_tab = tid
			_render_sheet()))
	v.add_child(UIKit.rule())
	var sale := GameState.land_sale_price(_sheet_i)
	var golden_n := int(p.get("golden_count", 0))
	var sale_note := ("naik jadi %d%% modal krn %d Golden Tree (+1%%/pokok)" % [100 + golden_n, golden_n]) if golden_n > 0 else "80% dari modal (lahan sawit biasa)"
	v.add_child(UIKit.wrap(UIKit.meta("Pedagang membeli lahan ini %s." % sale_note, 11)))
	v.add_child(UIKit.btn("💰 Jual lahan ke pedagang — Rp%s" % GameState._fmt(sale), func():
		var msg := GameState.sell_land(_sheet_i)
		UIKit.toast(self, msg)
		_close_sheet(), "secondary"))

func _tab_pupuk(v: VBoxContainer, p: Dictionary) -> void:
	var fert_days := GameState.day - int(p.get("last_fertilize_day", GameState.day))
	var late := fert_days > 120
	var note := PanelContainer.new()
	note.add_theme_stylebox_override("panel", UIKit.box(UIKit.ACCENT_100 if late else UIKit.SURFACE, UIKit.DIVIDER, 1, 10))
	var nl := UIKit.label("Terakhir dipupuk %d hari lalu%s" % [fert_days, " — sudah lewat rotasi 120 hari!" if late else " · rotasi 120 hari"],
		12, UIKit.ACCENT_800 if late else UIKit.INK)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_child(nl)
	v.add_child(note)
	# Rekomendasi kini mengikuti JADWAL BULANAN, bukan norma per tahun.
	var now_m := Agronomy.block_age_months(p)
	v.add_child(UIKit.wrap(UIKit.meta("Umur blok %d bulan · tahun tanam ke-%d" % [
		now_m, Agronomy.plant_year_of_month(maxi(now_m, 1))], 12)))

	var due: Array = Agronomy.missed_fert_months(p)
	if due.is_empty():
		v.add_child(UIKit.wrap(UIKit.meta(
			"Tidak ada jadwal pemupukan yang jatuh tempo untuk blok ini. Prompt akan muncul saat bulan berikutnya tiba.", 12)))
		return

	# Jadwal terbaru = yang jatuh tempo sekarang; sisanya = terlewat tahun ini.
	var target: int = int(due[-1])
	var earlier: Array = due.slice(0, due.size() - 1)
	var plan := Agronomy.monthly_fert_plan(p, target)

	v.add_child(UIKit.rule())
	v.add_child(UIKit.label("Jadwal bulan ke-%d" % target, 13, UIKit.INK, 800))
	_fert_rows(v, plan)

	var warn := String(plan.get("warning", ""))
	if warn != "":
		var wbox := PanelContainer.new()
		wbox.add_theme_stylebox_override("panel", UIKit.box(UIKit.ACCENT_100, UIKit.ACCENT, 1, 10))
		wbox.add_child(UIKit.wrap(UIKit.label("⚠ " + warn, 12, UIKit.ACCENT_800)))
		v.add_child(wbox)

	# Pupuk yang terlewat pada TAHUN TANAM YANG SAMA — opsional diaplikasikan.
	var months: Array = [target]
	if not earlier.is_empty():
		var extra_cost := 0
		for m in earlier:
			extra_cost += int((Agronomy.monthly_fert_plan(p, int(m)) as Dictionary).get("total_cost", 0))
		# Teks CheckBox TIDAK bisa wrap, jadi labelnya dibuat pendek dan
		# rinciannya ditaruh di baris meta terpisah yang bisa turun baris.
		var cb := CheckBox.new()
		cb.text = "Ikut pupuk %d bulan yang terlewat" % earlier.size()
		cb.add_theme_font_size_override("font_size", 12)
		cb.button_pressed = _fert_include_missed
		cb.toggled.connect(func(on):
			_fert_include_missed = on
			_render_sheet())
		v.add_child(cb)
		v.add_child(UIKit.wrap(UIKit.meta(
			"Bulan %s pada tahun tanam ini belum dipupuk — tambah Rp%s." % [
				", ".join(earlier.map(func(x): return str(x))), GameState._fmt(extra_cost)])))
		if _fert_include_missed:
			months = earlier.duplicate()
			months.append(target)

	var disc := 1.0 - float(GameState.profile_mods().get("input_discount", 0.0))
	var mat := 0
	for m in months:
		mat += int(round(float((Agronomy.monthly_fert_plan(p, int(m)) as Dictionary).get("total_cost", 0)) * disc))
	var lab := Agronomy.labor_cost("pupuk", float(p.get("area_ha", 1.0))) * months.size()
	v.add_child(UIKit.wrap(UIKit.meta("Bahan Rp%s + upah HK Rp%s" % [
		GameState._fmt(mat), GameState._fmt(lab)], 12)))
	v.add_child(UIKit.btn("Pupuk %s — Rp%s" % [p.get("id"), GameState._fmt(mat + lab)], func():
		_fert_include_missed = false
		_do(Actions.fertilize_schedule(p, months)), "primary"))

## Satu komponen = dua baris. Sebelumnya semua detail dipadatkan di satu baris
## sehingga terdorong ke luar layar di HP sempit.
func _fert_rows(v: VBoxContainer, plan: Dictionary) -> void:
	for c in plan.get("components", []):
		var row := HBoxContainer.new()
		var nm := UIKit.label(String(c.get("code", "?")).to_upper(), 13, UIKit.INK, 600)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		row.add_child(UIKit.label("%s/pokok" % Agronomy.fmt_kg(float(c.get("g_per_palm", 0))),
			13, UIKit.INK, 800))
		v.add_child(row)
		# Format dulu, BARU ganti titik jadi koma — kalau format string-nya yang
		# di-replace, "%.1f" ikut berubah jadi "%,1f" dan rusak.
		var kg_s := ("%.1f" % float(c.get("kg_total", 0))).replace(".", ",")
		v.add_child(UIKit.wrap(UIKit.meta("%s kg untuk %d pokok · Rp%s" % [
			kg_s, int(plan.get("palms", 0)), GameState._fmt(int(c.get("cost", 0)))])))
		v.add_child(UIKit.rule(1))

func _tab_semprot(v: VBoxContainer, p: Dictionary) -> void:
	var eff := Agronomy.spray_effectiveness(true)
	var ibox := PanelContainer.new()
	ibox.add_theme_stylebox_override("panel", UIKit.box(UIKit.BG, UIKit.INK, 2, 12))
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 6)
	ibox.add_child(bv)
	bv.add_child(UIKit.kicker("Indikator prakiraan", UIKit.N700))
	bv.add_child(UIKit.label("Efektivitas %d%%" % int(round(eff * 100)), 28, UIKit.ACCENT_700 if eff < 0.5 else UIKit.INK, 800))
	bv.add_child(UIKit.bar(eff, UIKit.ACCENT if eff < 0.5 else UIKit.INK, 6))
	var advice := "Cuaca %s — lanjutkan semprot." % GameState.weather
	if eff < 0.5:
		var fc := TimeManager.forecast(GameState.forecast_days())
		advice = "Cuaca %s — efektivitas rendah." % GameState.weather
		for i in fc.size():
			if String(fc[i]) == "cerah":
				advice += " Saran: tunda ke H+%d (cerah)." % (i + 1)
				break
	bv.add_child(UIKit.wrap(UIKit.meta(advice, 12)))
	v.add_child(ibox)
	v.add_child(UIKit.wrap(UIKit.meta("Semprot menurunkan gulma & menaikkan kesehatan (ikut cuaca).", 12)))
	v.add_child(UIKit.btn("Semprot gulma sekarang", func(): _do(Actions.spray(p)), "primary"))

	# Pengendalian manual (TB-0: tidak ada semprot kimia, wajib manual)
	v.add_child(UIKit.rule())
	var manual_box := PanelContainer.new()
	manual_box.add_theme_stylebox_override("panel", UIKit.box(UIKit.SURFACE, UIKit.DIVIDER, 1, 10))
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 6)
	manual_box.add_child(mv)
	mv.add_child(UIKit.kicker("Pengendalian Manual", UIKit.N700))
	var weed_pct := int(float(p.get("weed_level", 0)) * 100)
	var spray_lab := Agronomy.labor_cost("semprot", float(p.get("area_ha", 1.0)))
	var manual_cost := int(spray_lab * 3.0)
	mv.add_child(UIKit.wrap(UIKit.meta(
		"Cocok untuk TB-0 atau saat cuaca buruk. Biaya 3× semprot kimia karena padat karya. Efektivitas 100%%, tidak terpengaruh cuaca.", 12)))
	mv.add_child(UIKit.meta("Gulma saat ini: %d%%  ·  Perkiraan biaya: Rp%s" % [weed_pct, GameState._fmt(manual_cost)], 12))
	mv.add_child(UIKit.btn("Manual Gulma — Rp%s" % GameState._fmt(manual_cost),
		func(): _do(Actions.manual_gulma(p)), "secondary"))
	v.add_child(manual_box)

func _tab_hama(v: VBoxContainer, p: Dictionary) -> void:
	var pest = p.get("pest")
	if pest == null:
		v.add_child(UIKit.wrap(UIKit.meta("Tidak ada gejala hama/penyakit di blok ini.", 13)))
		return
	var lv := float(pest.get("level", 0))
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.box(UIKit.SURFACE, UIKit.DIVIDER, 1, 12))
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	card.add_child(cv)
	cv.add_child(UIKit.label("Tingkat serangan %.0f%%" % (lv * 100), 13, UIKit.INK, 800))
	cv.add_child(UIKit.bar(lv, UIKit.ACCENT))
	v.add_child(card)
	if not bool(pest.get("diagnosed", false)):
		v.add_child(UIKit.wrap(UIKit.meta("Ada gejala — diagnosis dulu agar perlakuan efektif (85% vs 30%).", 12)))
		v.add_child(UIKit.btn("Inspeksi & diagnosis — Rp50.000", func(): _do(Actions.inspect(p)), "primary"))
		v.add_child(UIKit.btn("Obati tanpa diagnosis (efektivitas 30%)", func(): _do(Actions.treat_pest(p))))
	else:
		var cat := Database.get_pest(String(pest.get("id", "")))
		var dg := PanelContainer.new()
		var dsb := UIKit.box(UIKit.BG, UIKit.INK, 2, 0)
		dg.add_theme_stylebox_override("panel", dsb)
		var dv := VBoxContainer.new()
		dg.add_child(dv)
		var head := PanelContainer.new()
		head.add_theme_stylebox_override("panel", UIKit.box(UIKit.INK, UIKit.INK, 0, 10))
		head.add_child(UIKit.label(String(cat.get("name", "?")), 14, UIKit.BG, 800))
		dv.add_child(head)
		var rows := UIKit.margin(10, 8, 10, 8)
		var rv := VBoxContainer.new()
		rv.add_theme_constant_override("separation", 4)
		rows.add_child(rv)
		var ingr: Array = cat.get("ingredients", [])
		for pair in [["Metode", String(cat.get("method", "-"))],
				["Bahan aktif", ", ".join(ingr) if not ingr.is_empty() else "non-kimia"],
				["Efektivitas", "85%"]]:
			var row := HBoxContainer.new()
			var k := UIKit.meta(String(pair[0]), 12)
			k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(k)
			row.add_child(UIKit.label(String(pair[1]), 12, UIKit.INK, 600))
			rv.add_child(row)
		dv.add_child(rows)
		v.add_child(dg)
		if not bool(cat.get("curable", true)):
			var warn := PanelContainer.new()
			warn.add_theme_stylebox_override("panel", UIKit.box(UIKit.ACCENT_100, UIKit.DIVIDER, 1, 10))
			warn.add_child(UIKit.wrap(UIKit.label("Tidak bisa diberantas tuntas — sanitasi hanya memperlambat.", 12, UIKit.ACCENT_800)))
			v.add_child(warn)
		v.add_child(UIKit.btn("Lakukan %s" % String(cat.get("method", "perlakuan")), func(): _do(Actions.treat_pest(p)), "primary"))

func _do(result: String) -> void:
	UIKit.toast(self, result)
	_render_sheet()

func _check_pending_breakeven() -> void:
	if GameState.break_even_day > 0 and not GameState._break_even_shown:
		var entries := GameState.hall_of_fame_entries()
		var rank := 1
		for i in entries.size():
			if entries[i].get("kebun_name") == GameState.display_kebun_name():
				rank = i + 1
				break
		_on_break_even(GameState.break_even_day, rank)

func _on_break_even(days_taken: int, rank: int) -> void:
	if GameState._break_even_shown:
		return
	GameState._break_even_shown = true
	var sheet := _sheet_base()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	sheet.add_child(v)
	v.add_child(UIKit.label("🎉 Selamat!", 28, UIKit.INK, 800))
	v.add_child(UIKit.wrap(UIKit.label(
		"Anda berhasil balik modal dalam %d hari!" % days_taken,
		16, UIKit.INK, 600)))
	v.add_child(UIKit.rule())
	v.add_child(UIKit.label("🏆 Hall of Fame", 20, UIKit.INK, 800))
	v.add_child(UIKit.wrap(UIKit.label(
		"Anda masuk dalam hall of fame, peringkat ke-%d" % rank,
		16, UIKit.ACCENT_700 if rank <= 3 else UIKit.INK, 600)))
	v.add_child(UIKit.rule())
	v.add_child(UIKit.btn("Lihat Hall of Fame", func():
		_close_sheet()
		get_tree().change_scene_to_file("res://scenes/HallOfFameScreen.tscn"), "primary"))
	v.add_child(UIKit.btn("Lanjutkan", _close_sheet))

# ── Tutorial dashboard pertama kali ────────────────────────────────────────
const _TUTORIAL_STEPS := [
	{
		"title": "Dashboard Kebun",
		"body": "Ini pusat kendali kebun Anda. Di sini Anda bisa memantau saldo, cuaca, TBS siap panen, dan kondisi setiap blok lahan.",
		"icon": "layout-grid"
	},
	{
		"title": "Strip Statistik",
		"body": "Saldo kebun, kondisi cuaca hari ini, dan estimasi TBS yang siap dipanen. Tap area Cuaca untuk melihat prakiraan, tap TBS untuk langsung ke layar Panen.",
		"icon": "file-text"
	},
	{
		"title": "Maju Hari",
		"body": "Tap 'Lanjut 1 hari' untuk maju satu hari, atau 'Lanjut 15 hari' untuk loncat. Waktu memengaruhi pertumbuhan gulma, hama, dan kematangan TBS.",
		"icon": "fast-forward"
	},
	{
		"title": "Panel Pembibitan",
		"body": "Kelola siklus pembibitan 12 bulan — dari pesan kecambah, Pre Nursery, hingga bibit siap tanam. Bibit sendiri jauh lebih murah dari beli jadi.",
		"icon": "sprout"
	},
	{
		"title": "Peta Blok 3×3",
		"body": "Tap blok untuk melihat detail dan mengambil tindakan: pupuk, semprot gulma, tangani hama, atau panen. Blok merah = ada masalah yang perlu ditangani.",
		"icon": "flag"
	},
	{
		"title": "Tugas Lapangan",
		"body": "Tombol 'Tugas Lapangan' di bawah peta membuka 7 minigame aktivitas lapangan. Mainkan sendiri untuk bonus 80–120%, atau tugaskan ke tim (selalu 2 bintang, bayar HK).",
		"icon": "gamepad-2"
	},
	{
		"title": "Icon Atas",
		"body": "👤 Profil · 👕 Kostum karakter · 🛍 Toko kosmetik · ⭐ Hall of Fame · 🛒 Top-up modal · ☰ Menu utama. Semuanya bisa diakses kapan saja dari header.",
		"icon": "settings"
	},
]

var _tutorial_idx: int = 0
var _tutorial_overlay: CanvasLayer

func _show_tutorial() -> void:
	GameState.tutorial_shown = true
	# Jangan save_game() di sini — demo mode tidak boleh menimpa save asli.
	# Save akan dilakukan otomatis saat user maju hari atau keluar ke menu.
	_tutorial_idx = 0
	_build_tutorial_step()

func _build_tutorial_step() -> void:
	if _tutorial_overlay:
		_tutorial_overlay.queue_free()
	if _tutorial_idx >= _TUTORIAL_STEPS.size():
		return

	_tutorial_overlay = CanvasLayer.new()
	add_child(_tutorial_overlay)

	var backdrop := ColorRect.new()
	backdrop.color = Color(UIKit.INK.r, UIKit.INK.g, UIKit.INK.b, 0.72)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tutorial_overlay.add_child(backdrop)

	var card_host := Control.new()
	card_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tutorial_overlay.add_child(card_host)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.box(UIKit.BG, UIKit.INK, 2, 0))
	card.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
	card.offset_left = 24; card.offset_right = -24
	card.offset_top = -160; card.offset_bottom = 160
	card_host.add_child(card)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 20)
	m.add_theme_constant_override("margin_right", 20)
	m.add_theme_constant_override("margin_top", 18)
	m.add_theme_constant_override("margin_bottom", 18)
	card.add_child(m)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	m.add_child(v)

	var step: Dictionary = _TUTORIAL_STEPS[_tutorial_idx]

	# Header: ikon + kicker + judul
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 10)
	var icon_name: String = step.get("icon", "info")
	if ResourceLoader.exists("res://assets/ui/icons/%s.svg" % icon_name):
		hrow.add_child(UIKit.icon(icon_name, 22, UIKit.ACCENT))
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_theme_constant_override("separation", 2)
	hv.add_child(UIKit.kicker("TUTORIAL %d/%d" % [_tutorial_idx + 1, _TUTORIAL_STEPS.size()]))
	hv.add_child(UIKit.label(step.get("title", ""), 18, UIKit.INK, 800))
	hrow.add_child(hv)
	v.add_child(hrow)

	v.add_child(UIKit.rule())

	var body_lbl := UIKit.label(step.get("body", ""), 14, UIKit.N700)
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(body_lbl)

	var sp := Control.new(); sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)

	# Navigasi
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 10)
	v.add_child(nav)

	if _tutorial_idx > 0:
		var back := UIKit.btn("← Sebelumnya", func():
			_tutorial_idx -= 1
			_build_tutorial_step())
		back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nav.add_child(back)

	var is_last := (_tutorial_idx == _TUTORIAL_STEPS.size() - 1)
	var next := UIKit.btn(
		"Mulai bermain ✓" if is_last else "Lanjut →",
		func():
			if is_last:
				if _tutorial_overlay: _tutorial_overlay.queue_free(); _tutorial_overlay = null
			else:
				_tutorial_idx += 1
				_build_tutorial_step(),
		"primary" if is_last else "secondary", 14, 44)
	next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(next)

	if not is_last:
		var skip := UIKit.btn("Lewati", func():
			if _tutorial_overlay: _tutorial_overlay.queue_free(); _tutorial_overlay = null)
		skip.add_theme_color_override("font_color", UIKit.N600)
		v.add_child(skip)
