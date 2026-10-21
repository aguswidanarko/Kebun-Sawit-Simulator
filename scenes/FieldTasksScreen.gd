extends Control
## Layar "Tugas Lapangan" — peta blok mini + daftar 7 tugas + bottom-sheet pilih mode.
## Data-driven dari data/field_tasks.json (Database.field_tasks).

const PLAY := "res://scenes/FieldTaskPlay.tscn"

var _tasks: Array = []
var _sheet: CanvasLayer
var _selected_task: Dictionary = {}
var _pin_nodes: Array = []   # [{ task, pin_ctrl }]

func _ready() -> void:
	var raw = Database.field_tasks
	_tasks = raw.get("tasks", []) if raw is Dictionary else []
	_build()
	GameState.blocks_changed.connect(func(): _refresh_pins(); _refresh_list())

# ─────────────────────────────────────────────────────── BUILD ─────

func _build() -> void:
	var content := UIKit.screen_root(self, "")

	# 1. Header foto 168 px
	var hdr := _make_header()
	content.add_child(hdr)

	# 2. Garis aksen 4px
	var accent_line := ColorRect.new()
	accent_line.color = GameState.applied_accent()
	accent_line.custom_minimum_size = Vector2(0, 4)
	content.add_child(accent_line)

	# 3. Strip statistik 3 kolom
	content.add_child(_make_stats_strip())

	# 4. Judul peta
	var map_title_m := UIKit.margin(16, 12, 16, 8)
	var map_title_row := HBoxContainer.new()
	var mt_lbl := UIKit.label("Peta Blok", 17, UIKit.INK, 800)
	mt_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_title_row.add_child(mt_lbl)
	map_title_row.add_child(UIKit.meta("Tap titik untuk mulai"))
	map_title_m.add_child(map_title_row)
	content.add_child(map_title_m)

	# 5. Peta mini
	var map_m := UIKit.margin(16, 0, 16, 0)
	map_m.add_child(_make_map())
	content.add_child(map_m)

	# 6. Daftar tugas
	var list_title_m := UIKit.margin(16, 16, 16, 0)
	list_title_m.add_child(UIKit.label("Daftar Tugas", 17, UIKit.INK, 800))
	content.add_child(list_title_m)

	content.add_child(_make_task_list())

	# Tombol kembali
	var back_m := UIKit.margin(16, 8, 16, 16)
	back_m.add_child(UIKit.btn("← Kembali ke Dashboard",
		func(): get_tree().change_scene_to_file("res://scenes/DashboardScreen.tscn")))
	content.add_child(back_m)

# ─────────────────────────────────────────────────────── HEADER ────

func _make_header() -> Control:
	var hdr := Control.new()
	hdr.custom_minimum_size = Vector2(0, 168)
	var ph := UIKit.photo("res://assets/bg/plantation.jpg", Vector2(0, 0), false)
	ph.set_anchors_preset(Control.PRESET_FULL_RECT)
	hdr.add_child(ph)
	var sc := UIKit.scrim()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	hdr.add_child(sc)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 16)
	m.add_theme_constant_override("margin_right", 16)
	m.add_theme_constant_override("margin_top", 14)
	m.add_theme_constant_override("margin_bottom", 14)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	hdr.add_child(m)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	m.add_child(v)

	# Top: tombol kembali kiri + chip cuaca kanan
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 0)
	var back_btn := _icon_btn("chevron-left", func():
		get_tree().change_scene_to_file("res://scenes/DashboardScreen.tscn"))
	top.add_child(back_btn)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var chip := PanelContainer.new()
	var chip_sb := UIKit.box(Color(0,0,0,0), Color(UIKit.BG.r, UIKit.BG.g, UIKit.BG.b, 0.55), 1, 6)
	chip.add_theme_stylebox_override("panel", chip_sb)
	var chip_lbl := UIKit.label("HARI %d · %s" % [GameState.day, GameState.weather.to_upper()],
		10, UIKit.BG, 600)
	chip.add_child(chip_lbl)
	top.add_child(chip)
	v.add_child(top)

	var spacer := Control.new(); spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)

	# Bottom: kicker + judul
	var b_name := GameState.active_block().get("id", "B1")
	v.add_child(UIKit.kicker("TUGAS LAPANGAN", Color(UIKit.BG.r, UIKit.BG.g, UIKit.BG.b, 0.85)))
	v.add_child(UIKit.label("Blok %s · 1 ha" % b_name, 26, UIKit.BG, 800))
	return hdr

func _icon_btn(icon_name: String, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(36, 36)
	b.add_theme_stylebox_override("normal", UIKit.box(Color(0,0,0,0), Color(UIKit.BG.r,UIKit.BG.g,UIKit.BG.b,0.55), 1, 4))
	b.add_theme_stylebox_override("hover",  UIKit.box(Color(1,1,1,0.12), UIKit.BG, 1, 4))
	b.add_theme_stylebox_override("pressed",UIKit.box(Color(1,1,1,0.20), UIKit.BG, 1, 4))
	var ic := UIKit.icon(icon_name, 18, UIKit.BG)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.set_anchors_preset(Control.PRESET_CENTER)
	ic.position = Vector2(-9, -9)
	b.add_child(ic)
	b.pressed.connect(cb)
	return b

# ─────────────────────────────────────────────────────── STATS ─────

func _make_stats_strip() -> Control:
	var strip := PanelContainer.new()
	var sb := UIKit.box(UIKit.BG, UIKit.INK, 0, 0)
	sb.border_width_bottom = 2
	strip.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	strip.add_child(h)
	var done := _done_count()
	var stars := _total_stars()
	var hk := _team_hk()
	var cells := [
		["SELESAI", "%d/7" % done],
		["BINTANG", "%d/21" % stars],
		["HK TIM", "%.1f" % hk],
	]
	for i in cells.size():
		if i > 0: h.add_child(UIKit.vrule())
		var mc := UIKit.margin(16, 12, 16, 12)
		mc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 3)
		cv.add_child(UIKit.label(cells[i][0], 10, UIKit.N700, 600))
		cv.add_child(UIKit.label(cells[i][1], 20, UIKit.INK, 800))
		mc.add_child(cv)
		h.add_child(mc)
	return strip

# ─────────────────────────────────────────────────────── PETA ──────

func _make_map() -> Control:
	var outer := PanelContainer.new()
	outer.custom_minimum_size = Vector2(0, 200)
	outer.add_theme_stylebox_override("panel", UIKit.box(UIKit.SURFACE, UIKit.INK, 2, 0))

	var map := Control.new()
	map.set_anchors_preset(Control.PRESET_FULL_RECT)
	map.clip_contents = true
	outer.add_child(map)

	# Grid tipis
	for xi in 5:
		var gl := ColorRect.new()
		gl.color = Color(UIKit.GRIDLINE.r, UIKit.GRIDLINE.g, UIKit.GRIDLINE.b, 0.12)
		gl.custom_minimum_size = Vector2(1, 0)
		gl.set_anchors_preset(Control.PRESET_FULL_RECT)
		gl.anchor_left = (xi + 1) / 5.0; gl.anchor_right = (xi + 1) / 5.0
		gl.offset_left = 0; gl.offset_right = 1
		map.add_child(gl)
	for yi in 4:
		var gl := ColorRect.new()
		gl.color = Color(UIKit.GRIDLINE.r, UIKit.GRIDLINE.g, UIKit.GRIDLINE.b, 0.12)
		gl.custom_minimum_size = Vector2(0, 1)
		gl.set_anchors_preset(Control.PRESET_FULL_RECT)
		gl.anchor_top = (yi + 1) / 4.0; gl.anchor_bottom = (yi + 1) / 4.0
		gl.offset_top = 0; gl.offset_bottom = 1
		map.add_child(gl)

	# Jalan produksi
	var road := ColorRect.new()
	road.color = UIKit.DIVIDER
	road.set_anchors_preset(Control.PRESET_FULL_RECT)
	road.anchor_top = 0.94; road.anchor_bottom = 1.0
	road.offset_top = 0; road.offset_bottom = 0
	map.add_child(road)
	var road_lbl := UIKit.label("JALAN PRODUKSI · TPH", 9, UIKit.N700, 600)
	road_lbl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	road_lbl.offset_bottom = 0; road_lbl.offset_top = -16
	road_lbl.offset_left = 4
	map.add_child(road_lbl)

	# Pin per tugas
	_pin_nodes.clear()
	var offset_map: Dictionary = {}  # posisi yang sudah dipakai
	for i in _tasks.size():
		var task: Dictionary = _tasks[i]
		var at: Array = task.get("at", [0.5, 0.5])
		var key := "%s_%s" % [at[0], at[1]]
		var n_at_same := int(offset_map.get(key, 0))
		offset_map[key] = n_at_same + 1
		var fx: float = float(at[0]) + n_at_same * 0.12
		var fy: float = float(at[1]) + n_at_same * 0.16

		var pin := _make_pin(i + 1, task, fx, fy)
		map.add_child(pin)
		_pin_nodes.append({"task": task, "pin": pin, "fx": fx, "fy": fy})

	_refresh_pins()
	return outer

func _make_pin(num: int, task: Dictionary, fx: float, fy: float) -> Control:
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var pin := PanelContainer.new()
	pin.custom_minimum_size = Vector2(26, 26)
	pin.set_meta("task_id", task.get("id", ""))
	pin.set_meta("num", num)
	pin.mouse_filter = Control.MOUSE_FILTER_STOP
	pin.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_open_sheet(task))

	# Position via anchors
	pin.anchor_left = fx; pin.anchor_top = fy
	pin.anchor_right = fx; pin.anchor_bottom = fy
	pin.offset_left = -13; pin.offset_top = -13
	pin.offset_right = 13; pin.offset_bottom = 13
	pin.add_theme_stylebox_override("panel", UIKit.box(UIKit.BG, UIKit.INK, 2, 0))

	var num_lbl := UIKit.label("%02d" % num, 11, UIKit.INK, 800)
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	pin.add_child(num_lbl)

	# Verb label di kanan pin
	var verb_lbl := PanelContainer.new()
	verb_lbl.add_theme_stylebox_override("panel", UIKit.box(UIKit.BG, Color(0,0,0,0), 0, 2))
	var vl := UIKit.meta(task.get("verb", ""), 9)
	verb_lbl.add_child(vl)
	verb_lbl.anchor_left = fx; verb_lbl.anchor_top = fy
	verb_lbl.anchor_right = fx; verb_lbl.anchor_bottom = fy
	verb_lbl.offset_left = 15; verb_lbl.offset_top = -8
	verb_lbl.offset_right = 70; verb_lbl.offset_bottom = 8

	host.add_child(pin)
	host.add_child(verb_lbl)
	return host

func _refresh_pins() -> void:
	for entry in _pin_nodes:
		var task: Dictionary = entry["task"]
		var host := entry["pin"] as Control
		var pin := host.get_child(0) as PanelContainer
		if pin == null: continue
		var result: Dictionary = GameState.field_task_results.get(task.get("id", ""), {})
		var stars := int(result.get("stars", 0))
		var num_lbl := pin.get_child(0) as Label
		if stars >= 1:
			pin.add_theme_stylebox_override("panel", UIKit.box(UIKit.INK, UIKit.INK, 2, 0))
			if num_lbl: num_lbl.add_theme_color_override("font_color", UIKit.BG)
		else:
			pin.add_theme_stylebox_override("panel", UIKit.box(UIKit.BG, UIKit.INK, 2, 0))
			if num_lbl: num_lbl.add_theme_color_override("font_color", UIKit.INK)

# ─────────────────────────────────────────────────────── DAFTAR ────

func _make_task_list() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	# border top
	var top_border := ColorRect.new()
	top_border.color = UIKit.INK
	top_border.custom_minimum_size = Vector2(0, 2)
	v.add_child(top_border)
	for i in _tasks.size():
		v.add_child(_task_row(_tasks[i], i + 1))
	return v

func _task_row(task: Dictionary, num: int) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UIKit.box(UIKit.BG, UIKit.DIVIDER, 0, 0))
	var sb2 := UIKit.box(UIKit.BG, UIKit.DIVIDER, 0, 0)
	sb2.border_width_bottom = 1
	row.add_theme_stylebox_override("panel", sb2)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_open_sheet(task))

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 16)
	m.add_theme_constant_override("margin_right", 16)
	m.add_theme_constant_override("margin_top", 12)
	m.add_theme_constant_override("margin_bottom", 12)
	row.add_child(m)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	m.add_child(h)

	# Nomor
	var num_lbl := UIKit.label("%02d" % num, 14, UIKit.N600, 600)
	num_lbl.custom_minimum_size = Vector2(28, 0)
	h.add_child(num_lbl)

	# Nama + meta
	var vl := VBoxContainer.new()
	vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vl.add_theme_constant_override("separation", 2)
	var mech_label := {"hold": "Tahan", "timing": "Timing", "targets": "Target"}
	vl.add_child(UIKit.label(task.get("name", "?"), 14, UIKit.INK, 800))
	vl.add_child(UIKit.meta("%s · %s" % [
		mech_label.get(String(task.get("mech", "")), "?"), task.get("worker", "?")], 11))
	h.add_child(vl)

	# Bintang
	var stars_box := HBoxContainer.new()
	stars_box.add_theme_constant_override("separation", 2)
	var result: Dictionary = GameState.field_task_results.get(task.get("id", ""), {})
	var stars := int(result.get("stars", 0))
	for s in 3:
		var sq := PanelContainer.new()
		sq.custom_minimum_size = Vector2(9, 9)
		sq.add_theme_stylebox_override("panel",
			UIKit.box(UIKit.ACCENT if s < stars else UIKit.N300, Color(0,0,0,0), 0, 0))
		stars_box.add_child(sq)
	h.add_child(stars_box)

	# Status
	var mode := String(result.get("mode", ""))
	var status_txt := "BELUM" if mode == "" else ("SENDIRI" if mode == "self" else "TIM")
	var status_col := UIKit.N600 if mode == "" else UIKit.INK
	var status_lbl := UIKit.label(status_txt, 10, status_col, 600)
	status_lbl.custom_minimum_size = Vector2(44, 0)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(status_lbl)

	# Chevron
	h.add_child(UIKit.icon("chevron-right", 16, UIKit.N500))
	return row

func _refresh_list() -> void:
	pass  # scroll container auto-updates saat tree berubah karena blocks_changed

# ──────────────────────────────────────────── BOTTOM SHEET ─────────

func _open_sheet(task: Dictionary) -> void:
	_selected_task = task
	if _sheet: _sheet.queue_free()
	_sheet = CanvasLayer.new()
	add_child(_sheet)

	var backdrop := ColorRect.new()
	backdrop.color = Color(UIKit.INK.r, UIKit.INK.g, UIKit.INK.b, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed: _close_sheet())
	_sheet.add_child(backdrop)

	var sheet := PanelContainer.new()
	sheet.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sheet.offset_top = -480
	var sb := UIKit.box(UIKit.BG, UIKit.INK, 0, 0)
	sb.border_width_top = 2
	sheet.add_theme_stylebox_override("panel", sb)
	_sheet.add_child(sheet)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 16)
	m.add_theme_constant_override("margin_right", 16)
	m.add_theme_constant_override("margin_top", 14)
	m.add_theme_constant_override("margin_bottom", 20)
	sheet.add_child(m)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	m.add_child(v)

	# Header
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 12)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_theme_constant_override("separation", 2)
	var mech_label := {"hold": "Tahan", "timing": "Timing", "targets": "Target"}
	var num_idx := _tasks.find(task) + 1
	hv.add_child(UIKit.kicker("%02d · %s · %s" % [num_idx, mech_label.get(String(task.get("mech","")), "?"), task.get("verb","")], UIKit.ACCENT_700))
	hv.add_child(UIKit.label(task.get("name", "?"), 22, UIKit.INK, 800))
	hr.add_child(hv)
	hr.add_child(UIKit.close_btn(_close_sheet))
	v.add_child(hr)

	v.add_child(UIKit.wrap(UIKit.label(task.get("help", ""), 14, UIKit.N700)))

	v.add_child(UIKit.rule())

	# Grid 2 kolom: sendiri | tim
	var grid := PanelContainer.new()
	var gsb := UIKit.box(UIKit.BG, UIKit.INK, 0, 0)
	gsb.border_width_top = 2; gsb.border_width_bottom = 2
	grid.add_theme_stylebox_override("panel", gsb)
	var gh := HBoxContainer.new()
	gh.add_theme_constant_override("separation", 0)
	grid.add_child(gh)

	# Kerjakan sendiri
	var self_col := _sheet_col(
		"KERJAKAN SENDIRI",
		_self_sub(task),
		"1–3 bintang · hemat %s HK" % _fmt_hk(task.get("hk_delegate", 0.5)))
	gh.add_child(self_col)
	gh.add_child(UIKit.vrule())

	# Tugaskan tim
	var team_col := _sheet_col(
		"TUGASKAN TIM",
		task.get("worker", "?"),
		"Selalu 2 bintang · %s HK" % _fmt_hk(task.get("hk_delegate", 0.5)))
	gh.add_child(team_col)
	v.add_child(grid)

	# Tombol primary: mainkan sendiri
	var play_btn := UIKit.btn("", func(): _start_play(task), "primary", 20, 52)
	play_btn.text = "%s sendiri  ›" % task.get("verb", "Main")
	play_btn.icon = load("res://assets/ui/icons/gamepad-2.svg")
	play_btn.add_theme_color_override("icon_normal_color", UIKit.BG)
	v.add_child(play_btn)

	# Tombol secondary: delegasi tim
	var delegate_btn := UIKit.btn("", func(): _do_delegate(task), "secondary", 14, 44)
	delegate_btn.text = "Tugaskan ke tim"
	delegate_btn.icon = load("res://assets/ui/icons/users.svg")
	v.add_child(delegate_btn)

func _sheet_col(title: String, sub: String, note: String) -> Control:
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_right", 12)
	m.add_theme_constant_override("margin_top", 12)
	m.add_theme_constant_override("margin_bottom", 12)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	m.add_child(v)
	v.add_child(UIKit.kicker(title, UIKit.N700))
	var sub_lbl := UIKit.label(sub, 13, UIKit.INK, 600)
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub_lbl)
	var note_lbl := UIKit.meta(note)
	note_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note_lbl)
	return m

func _self_sub(task: Dictionary) -> String:
	var mech := String(task.get("mech", ""))
	var rounds := int(task.get("rounds", 5))
	if mech == "hold":
		return "%d putaran tahan" % rounds
	elif mech == "timing":
		return "%d putaran timing" % rounds
	else:
		return "Ketuk target, lawan waktu"

func _fmt_hk(hk) -> String:
	var v := float(hk)
	if v == int(v):
		return "%d" % int(v)
	return "%.1f" % v

func _close_sheet() -> void:
	if _sheet: _sheet.queue_free(); _sheet = null

func _start_play(task: Dictionary) -> void:
	_close_sheet()
	GameState.active_field_task = task
	get_tree().change_scene_to_file(PLAY)

func _do_delegate(task: Dictionary) -> void:
	var hk := float(task.get("hk_delegate", 0.5))
	var cost := GameState.field_task_delegate_cost(hk)
	if not GameState.spend(cost, "Delegasi tugas %s ke %s" % [task.get("name","?"), task.get("worker","tim")]):
		UIKit.toast(self, "Dana tidak cukup (Rp%s)." % GameState._fmt(cost))
		return
	GameState.complete_field_task(task.get("id", ""), 2, "team")
	_close_sheet()
	UIKit.toast(self, "%s ditugaskan ke %s · %s HK" % [
		task.get("name", "?"), task.get("worker", "tim"), _fmt_hk(hk)])

# ─────────────────────────────────────────────────────── UTIL ──────

func _done_count() -> int:
	var n := 0
	for t in _tasks:
		if GameState.field_task_results.has(t.get("id", "")): n += 1
	return n

func _total_stars() -> int:
	var s := 0
	for t in _tasks:
		s += int(GameState.field_task_results.get(t.get("id", ""), {}).get("stars", 0))
	return s

func _team_hk() -> float:
	var hk := 0.0
	for t in _tasks:
		var r: Dictionary = GameState.field_task_results.get(t.get("id", ""), {})
		if String(r.get("mode", "")) == "team":
			hk += float(t.get("hk_delegate", 0.5))
	return hk
