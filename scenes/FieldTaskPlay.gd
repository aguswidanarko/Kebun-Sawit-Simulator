extends Control
## Minigame "Tugas Lapangan" — 3 mekanik: hold, timing, targets.
## Data dari GameState.active_field_task (dibaca dari field_tasks.json).

const HUB := "res://scenes/FieldTasksScreen.tscn"

# ── State permainan ───────────────────────────────────────────────
var _task: Dictionary = {}
var _mech: String = ""
var _rounds: int = 5

var _round_idx: int = 0    # ronde saat ini (0-based)
var _hits: int = 0
var _misses: int = 0
var _feedback_timer: float = 0.0
var _feedback_lock: bool = false
var _phase: String = "play"   # "play" | "feedback" | "result"

# hold
var _hold_v: float = 0.0
var _hold_down: bool = false

# timing
var _timing_v: float = 0.0
var _timing_dir: float = 1.0
var _timing_speed: float = 0.024

# targets
var _cells: Array = []   # [{label, sub, valid, tapped}]
var _start_time: float = 0.0
var _elapsed: float = 0.0
var _target_done: bool = false

# ── Node refs ─────────────────────────────────────────────────────
var _area: Control
var _feedback_lbl: Label
var _dots_bar: HBoxContainer
var _action_btn: Button
var _round_lbl: Label
var _val_lbl: Label         # angka besar
var _gauge_fill: Control    # hold: fill gauge
var _track_needle: Control  # timing: jarum
var _target_grid: GridContainer
var _elapsed_lbl: Label
var _tap_count_lbl: Label

func _ready() -> void:
	_task = GameState.active_field_task
	if _task.is_empty():
		get_tree().change_scene_to_file(HUB); return
	_mech = String(_task.get("mech", "timing"))
	_rounds = int(_task.get("rounds", 5))
	_timing_speed = float(_task.get("speed", 0.024))
	_build()
	_start_round()

# ─────────────────────────────────────────── BUILD ───────────────

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# Top bar
	root.add_child(_make_topbar())

	# Help strip
	var help_m := UIKit.margin(16, 8, 16, 8)
	var help_sb := UIKit.box(UIKit.BG, UIKit.DIVIDER, 0, 0)
	help_sb.border_width_bottom = 1
	var help_pc := PanelContainer.new()
	help_pc.add_theme_stylebox_override("panel", help_sb)
	var help_lbl := UIKit.label(String(_task.get("help", "")), 13, UIKit.N700)
	help_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_pc.add_child(help_lbl)
	root.add_child(help_pc)

	# Area permainan
	_area = Control.new()
	_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_area)
	match _mech:
		"hold":    _build_hold()
		"timing":  _build_timing()
		"targets": _build_targets()

	# Umpan balik + dots
	var fb_row := UIKit.margin(16, 8, 16, 4)
	var fh := HBoxContainer.new()
	fh.add_theme_constant_override("separation", 8)
	fb_row.add_child(fh)
	_feedback_lbl = UIKit.label("", 15, UIKit.INK, 800)
	_feedback_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fh.add_child(_feedback_lbl)
	_dots_bar = HBoxContainer.new()
	_dots_bar.add_theme_constant_override("separation", 4)
	fh.add_child(_dots_bar)
	root.add_child(fb_row)
	_rebuild_dots()

	# Tombol aksi
	if _mech != "targets":
		var btn_m := UIKit.margin(16, 8, 16, 24)
		_action_btn = _make_action_btn()
		btn_m.add_child(_action_btn)
		root.add_child(btn_m)

func _make_topbar() -> Control:
	var tb := PanelContainer.new()
	var sb := UIKit.box(UIKit.BG, UIKit.INK, 0, 0)
	sb.border_width_bottom = 2
	tb.add_theme_stylebox_override("panel", sb)
	var m := UIKit.margin(16, 12, 16, 12)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	m.add_child(h)
	tb.add_child(m)

	# Close
	var close_b := UIKit.close_btn(func(): get_tree().change_scene_to_file(HUB))
	h.add_child(close_b)

	# Kicker + nama
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 2)
	var mech_label := {"hold": "TAHAN", "timing": "TIMING", "targets": "TARGET"}
	tv.add_child(UIKit.kicker("%s · %s" % [mech_label.get(_mech, _mech.to_upper()), String(_task.get("verb","")).to_upper()], UIKit.ACCENT_700))
	tv.add_child(UIKit.label(String(_task.get("name", "?")), 17, UIKit.INK, 800))
	h.add_child(tv)

	# Progres kanan
	_round_lbl = UIKit.label("1/%d" % _rounds, 14, UIKit.N700, 600)
	h.add_child(_round_lbl)
	return tb

func _make_action_btn() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 88)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_font_override("font", UIKit.bold())
	if ResourceLoader.exists("res://assets/ui/icons/hand.svg"):
		b.icon = load("res://assets/ui/icons/hand.svg")
	b.add_theme_color_override("icon_normal_color", UIKit.BG)
	for st in ["normal", "hover"]:
		b.add_theme_stylebox_override(st, UIKit.box(UIKit.ACCENT, Color(0,0,0,0), 0, 0))
	b.add_theme_stylebox_override("pressed",  UIKit.box(UIKit.ACCENT_700, Color(0,0,0,0), 0, 0))
	b.add_theme_stylebox_override("disabled", UIKit.box(UIKit.N500, Color(0,0,0,0), 0, 0))
	for st in ["font_color","font_hover_color","font_pressed_color"]:
		b.add_theme_color_override(st, UIKit.BG)
	b.text = _action_text(false)
	b.button_down.connect(_on_btn_down)
	b.button_up.connect(_on_btn_up)
	return b

# ─────────────────────────────────────────── HOLD ────────────────

func _build_hold() -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.add_child(h)

	# Gauge vertikal kiri
	var gauge_outer := PanelContainer.new()
	gauge_outer.custom_minimum_size = Vector2(120, 0)
	gauge_outer.add_theme_stylebox_override("panel", UIKit.box(UIKit.SURFACE, UIKit.INK, 2, 0))
	gauge_outer.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var gauge_inner := Control.new()
	gauge_inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	gauge_outer.add_child(gauge_inner)

	_gauge_fill = ColorRect.new()
	_gauge_fill.color = UIKit.INK
	_gauge_fill.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_gauge_fill.anchor_top = 1.0
	gauge_inner.add_child(_gauge_fill)

	# Zona tepat
	var zone: Array = _task.get("zone", [0.5, 0.7])
	var zone_band := Control.new()
	zone_band.set_anchors_preset(Control.PRESET_FULL_RECT)
	zone_band.anchor_top = 1.0 - float(zone[1])
	zone_band.anchor_bottom = 1.0 - float(zone[0])
	zone_band.offset_top = 0; zone_band.offset_bottom = 0
	var zone_bg := ColorRect.new()
	zone_bg.color = Color(UIKit.ACCENT.r, UIKit.ACCENT.g, UIKit.ACCENT.b, 0.14)
	zone_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	zone_band.add_child(zone_bg)
	var zone_top := ColorRect.new()
	zone_top.color = UIKit.ACCENT; zone_top.custom_minimum_size = Vector2(0, 2)
	zone_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	zone_top.offset_bottom = 2
	zone_band.add_child(zone_top)
	var zone_bot := ColorRect.new()
	zone_bot.color = UIKit.ACCENT; zone_bot.custom_minimum_size = Vector2(0, 2)
	zone_bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	zone_bot.offset_top = -2
	zone_band.add_child(zone_bot)
	gauge_inner.add_child(zone_band)
	h.add_child(gauge_outer)

	# Kanan: label atas + angka + label bawah
	var rv := VBoxContainer.new()
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_theme_constant_override("separation", 8)
	var is_buka := (String(_task.get("id","")) == "buka")
	var top_lbl := UIKit.label(
		"MESIN PANAS" if is_buka else "DOSIS BERLEBIH", 11, UIKit.N600, 600)
	rv.add_child(top_lbl)
	var sp1 := Control.new(); sp1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(sp1)
	var zone_kicker := UIKit.kicker("ZONA TEPAT")
	rv.add_child(zone_kicker)
	_val_lbl = UIKit.label("0%", 56, UIKit.INK, 800)
	_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(_val_lbl)
	var unit_lbl := UIKit.meta(
		"% putaran mesin" if is_buka else "% dosis piringan")
	unit_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(unit_lbl)
	var sp2 := Control.new(); sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(sp2)
	var bot_lbl := UIKit.label(
		"BELUM TERTEBAS" if is_buka else "PIRINGAN KERING", 11, UIKit.N600, 600)
	rv.add_child(bot_lbl)
	h.add_child(rv)

func _update_hold_visuals() -> void:
	if _val_lbl: _val_lbl.text = "%d%%" % int(_hold_v * 100)
	if _gauge_fill:
		_gauge_fill.anchor_top = 1.0 - _hold_v
		_gauge_fill.color = UIKit.ACCENT if _in_zone(_hold_v) else UIKit.INK
	if _action_btn:
		_action_btn.text = _action_text(_hold_down)

func _in_zone(v: float) -> bool:
	var zone: Array = _task.get("zone", [0.5, 0.7])
	return v >= float(zone[0]) and v <= float(zone[1])

# ─────────────────────────────────────────── TIMING ──────────────

func _build_timing() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.add_child(v)

	# Angka besar
	_val_lbl = UIKit.label("0%", 56, UIKit.INK, 800)
	_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var vsp := Control.new(); vsp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(vsp)
	v.add_child(_val_lbl)

	# Track horizontal
	var track_outer := PanelContainer.new()
	track_outer.custom_minimum_size = Vector2(0, 88)
	var track_sb := UIKit.box(UIKit.SURFACE, UIKit.INK, 2, 0)
	track_outer.add_theme_stylebox_override("panel", track_sb)

	var track_inner := Control.new()
	track_inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	track_outer.add_child(track_inner)

	# Skala tiap 10%
	for i in 9:
		var tl := ColorRect.new()
		tl.color = Color(UIKit.GRIDLINE.r, UIKit.GRIDLINE.g, UIKit.GRIDLINE.b, 0.3)
		tl.custom_minimum_size = Vector2(1, 0)
		tl.set_anchors_preset(Control.PRESET_FULL_RECT)
		tl.anchor_left = (i + 1) * 0.1; tl.anchor_right = (i + 1) * 0.1
		tl.offset_left = 0; tl.offset_right = 1
		track_inner.add_child(tl)

	# Zona tepat
	var zone: Array = _task.get("zone", [0.42, 0.6])
	var zb := Control.new()
	zb.set_anchors_preset(Control.PRESET_FULL_RECT)
	zb.anchor_left = float(zone[0]); zb.anchor_right = float(zone[1])
	var zb_bg := ColorRect.new()
	zb_bg.color = Color(UIKit.ACCENT.r, UIKit.ACCENT.g, UIKit.ACCENT.b, 0.14)
	zb_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	zb.add_child(zb_bg)
	var zb_left := ColorRect.new()
	zb_left.color = UIKit.ACCENT; zb_left.custom_minimum_size = Vector2(2, 0)
	zb_left.set_anchors_preset(Control.PRESET_LEFT_WIDE); zb_left.offset_right = 2
	zb.add_child(zb_left)
	var zb_right := ColorRect.new()
	zb_right.color = UIKit.ACCENT; zb_right.custom_minimum_size = Vector2(2, 0)
	zb_right.set_anchors_preset(Control.PRESET_RIGHT_WIDE); zb_right.offset_left = -2
	zb.add_child(zb_right)
	track_inner.add_child(zb)

	# Jarum
	_track_needle = ColorRect.new()
	_track_needle.color = UIKit.INK
	_track_needle.custom_minimum_size = Vector2(4, 0)
	_track_needle.set_anchors_preset(Control.PRESET_FULL_RECT)
	_track_needle.anchor_left = 0.0; _track_needle.anchor_right = 0.0
	_track_needle.offset_left = -2; _track_needle.offset_right = 2
	_track_needle.offset_top = -10; _track_needle.offset_bottom = 10
	track_inner.add_child(_track_needle)

	var track_m := UIKit.margin(16, 0, 16, 0)
	track_m.add_child(track_outer)
	v.add_child(track_m)

	# Label bawah
	var is_pupuk := (String(_task.get("id","")) == "pupuk")
	var lo_mid_hi: Array
	if is_pupuk:
		lo_mid_hi = ["0 kg", "± 2 kg/pokok", "4 kg"]
	else:
		lo_mid_hi = ["Pelepah", "Tangkai tandan", "Buah"]
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 0)
	var ll := UIKit.meta(lo_mid_hi[0]); ll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lm := UIKit.label(lo_mid_hi[1], 11, UIKit.ACCENT_700)
	lm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var lr := UIKit.meta(lo_mid_hi[2]); lr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lrow.add_child(ll); lrow.add_child(lm); lrow.add_child(lr)
	v.add_child(UIKit.margin(16, 0, 16, 0))
	var lm2 := UIKit.margin(16, 0, 16, 0)
	lm2.add_child(lrow)
	v.add_child(lm2)

	var vsp2 := Control.new(); vsp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(vsp2)

func _update_timing_visuals() -> void:
	var is_pupuk := (String(_task.get("id","")) == "pupuk")
	if _val_lbl:
		if is_pupuk:
			_val_lbl.text = "%.1f kg" % (_timing_v * 4.0)
		else:
			_val_lbl.text = "%d%%" % int(_timing_v * 100)
	if _track_needle:
		_track_needle.anchor_left = _timing_v
		_track_needle.anchor_right = _timing_v

# ─────────────────────────────────────────── TARGETS ─────────────

func _build_targets() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.add_child(v)

	# Stopwatch + meta
	var info_m := UIKit.margin(16, 8, 16, 4)
	var ih := HBoxContainer.new()
	ih.add_theme_constant_override("separation", 8)
	_elapsed_lbl = UIKit.label("0.0 dtk", 28, UIKit.INK, 800)
	ih.add_child(_elapsed_lbl)
	_tap_count_lbl = UIKit.meta("Salah 0 · target < 25 dtk")
	_tap_count_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tap_count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ih.add_child(_tap_count_lbl)
	info_m.add_child(ih)
	v.add_child(info_m)

	# Grid 3×4
	var grid_m := UIKit.margin(16, 0, 16, 8)
	_target_grid = GridContainer.new()
	_target_grid.columns = 3
	_target_grid.add_theme_constant_override("h_separation", 2)
	_target_grid.add_theme_constant_override("v_separation", 2)
	grid_m.add_child(_target_grid)
	v.add_child(grid_m)
	_populate_targets()

func _populate_targets() -> void:
	_cells.clear()
	for c in _target_grid.get_children():
		c.queue_free()
	var task_id := String(_task.get("id", ""))
	match task_id:
		"angkut":
			for _i in 5: _cells.append({"label": "TBS matang", "sub": "TANDAN", "valid": true, "tapped": false})
			for _i in 3: _cells.append({"label": "Brondolan", "sub": "BUAH LEPAS", "valid": true, "tapped": false})
			for _i in 4: _cells.append({"label": "Tandan mentah", "sub": "JANGAN MUAT", "valid": false, "tapped": false})
		"inspeksi":
			var symptoms: Dictionary = Database.field_tasks.get("inspection_symptoms", {})
			var normal: Array = Database.field_tasks.get("inspection_normal_labels", [])
			var sym_labels: Array = []
			for pest_id in symptoms:
				for s in symptoms[pest_id]: sym_labels.append(s)
			sym_labels.shuffle()
			var chosen_syms: Array = sym_labels.slice(0, 4)
			var normal_pool: Array = normal.duplicate()
			normal_pool.shuffle()
			var chosen_normals: Array = normal_pool.slice(0, 8)
			for i in 12:
				var is_sym := i < 4
				_cells.append({
					"label": "Pokok %02d" % (i + 1),
					"sub": chosen_syms[i] if is_sym else chosen_normals[i - 4],
					"valid": is_sym, "tapped": false
				})
		"tanam":
			for i in 7: _cells.append({"label": "Ajir", "sub": "TITIK TANAM", "valid": true, "tapped": false})
			var obstacles := ["Batu", "Genangan", "Tunggul"]
			for i in 5: _cells.append({"label": obstacles[i % 3], "sub": "RINTANGAN", "valid": false, "tapped": false})

	_cells.shuffle()
	for cell_data in _cells:
		_target_grid.add_child(_make_target_cell(cell_data))

func _make_target_cell(cell_data: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 72)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel",
		UIKit.box(UIKit.BG, Color(UIKit.GRIDLINE.r, UIKit.GRIDLINE.g, UIKit.GRIDLINE.b, 0.5), 1, 0))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_on_target_tap(cell_data, card))
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 2)
	card.add_child(cv)
	var sub_lbl := UIKit.label(cell_data.get("sub", ""), 9, UIKit.N700, 600)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(sub_lbl)
	var main_lbl := UIKit.label(cell_data.get("label", "?"), 12, UIKit.INK, 800)
	main_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(main_lbl)
	cell_data["_card"] = card
	cell_data["_main_lbl"] = main_lbl
	return card

func _on_target_tap(cell_data: Dictionary, card: PanelContainer) -> void:
	if cell_data.get("tapped", false) or _phase != "play" or _feedback_lock: return
	cell_data["tapped"] = true
	var valid: bool = cell_data.get("valid", false)
	var main_lbl := cell_data.get("_main_lbl") as Label
	if valid:
		_hits += 1
		card.add_theme_stylebox_override("panel", UIKit.box(UIKit.INK, UIKit.INK, 1, 0))
		if main_lbl: main_lbl.add_theme_color_override("font_color", UIKit.BG)
		_feedback_lbl.text = "Benar"
		_feedback_lbl.add_theme_color_override("font_color", UIKit.INK)
	else:
		_misses += 1
		card.add_theme_stylebox_override("panel", UIKit.box(UIKit.ACCENT, UIKit.ACCENT, 1, 0))
		if main_lbl: main_lbl.add_theme_color_override("font_color", UIKit.BG)
		_feedback_lbl.text = "Salah pilih"
		_feedback_lbl.add_theme_color_override("font_color", UIKit.ACCENT_700)
	_update_tap_info()
	var valid_count := _valid_cell_count()
	if _hits >= valid_count:
		_feedback_lock = true
		_feedback_timer = 0.5
		# akan lanjut ke hasil di _process

func _valid_cell_count() -> int:
	var n := 0
	for c in _cells:
		if c.get("valid", false): n += 1
	return n

func _update_tap_info() -> void:
	if _tap_count_lbl:
		_tap_count_lbl.text = "Salah %d · target < 25 dtk" % _misses

# ──────────────────────────────────────── LOOP ───────────────────

func _process(delta: float) -> void:
	if _phase == "feedback":
		_feedback_timer -= delta
		if _feedback_timer <= 0.0:
			_feedback_lock = false
			if _mech == "targets" and _hits >= _valid_cell_count():
				_show_result()
				return
			_round_idx += 1
			if _round_idx >= _rounds:
				_show_result()
			else:
				_start_round()
		return

	if _phase == "result": return

	if _mech == "hold":
		if _hold_down:
			_hold_v = minf(_hold_v + 0.011, 1.0)
			if _hold_v >= 1.0 and _action_btn and not _action_btn.disabled:
				_action_btn.disabled = true
				_trigger_hold_release(true)
		_update_hold_visuals()

	elif _mech == "timing":
		_timing_v += _timing_dir * _timing_speed * 60.0 * delta
		if _timing_v >= 1.0: _timing_v = 1.0; _timing_dir = -1.0
		elif _timing_v <= 0.0: _timing_v = 0.0; _timing_dir = 1.0
		_update_timing_visuals()

	elif _mech == "targets":
		_elapsed += delta
		if _elapsed_lbl: _elapsed_lbl.text = "%.1f dtk" % _elapsed

# ──────────────────────────────────────── INPUT ──────────────────

func _on_btn_down() -> void:
	if _feedback_lock or _phase != "play": return
	if _mech == "hold":
		_hold_down = true
		_hold_v = 0.0
		if _action_btn: _action_btn.text = "%s…  lepas di zona" % _task.get("verb","")
	elif _mech == "timing":
		_tap_timing()

func _on_btn_up() -> void:
	if _mech == "hold":
		_trigger_hold_release(false)

func _trigger_hold_release(overrun: bool) -> void:
	_hold_down = false
	if _feedback_lock: return
	_feedback_lock = true
	var zone: Array = _task.get("zone", [0.5, 0.7])
	var is_buka := (String(_task.get("id","")) == "buka")
	if overrun:
		_show_feedback("Lewat zona — %s" % ("Mesin overheat" if is_buka else "Kebanyakan — gulma mati, boros herbisida"), false)
	elif _hold_v < float(zone[0]):
		_show_feedback("Kurang — lepas terlalu cepat", false)
	else:
		_show_feedback("Tepat", true)
	if _action_btn: _action_btn.disabled = false

func _tap_timing() -> void:
	if _feedback_lock or _phase != "play": return
	_feedback_lock = true
	var zone: Array = _task.get("zone", [0.42, 0.6])
	if _timing_v >= float(zone[0]) and _timing_v <= float(zone[1]):
		_show_feedback("Tepat", true)
	elif _timing_v < float(zone[0]):
		_show_feedback("Terlalu awal", false)
	else:
		_show_feedback("Terlambat", false)

func _show_feedback(txt: String, hit: bool) -> void:
	if hit: _hits += 1
	_feedback_lbl.text = txt
	_feedback_lbl.add_theme_color_override("font_color",
		UIKit.INK if hit else UIKit.ACCENT_700)
	_rebuild_dots()
	_hold_v = 0.0
	_timing_v = 0.0
	_timing_dir = 1.0
	_feedback_timer = 0.7
	_phase = "feedback"

func _start_round() -> void:
	_phase = "play"
	_feedback_lock = false
	_hold_v = 0.0
	_hold_down = false
	_timing_v = 0.0
	_timing_dir = 1.0
	_feedback_lbl.text = ""
	if _round_lbl: _round_lbl.text = "%d/%d" % [_round_idx + 1, _rounds]
	if _action_btn:
		_action_btn.text = _action_text(false)
		_action_btn.disabled = false
	_rebuild_dots()
	if _mech == "targets":
		_hits = 0; _misses = 0; _elapsed = 0.0; _target_done = false
		_populate_targets()

func _action_text(holding: bool) -> String:
	if _mech == "hold":
		return ("%s…  lepas di zona" if holding else "Tahan · %s") % String(_task.get("verb","Tahan"))
	return "Tap · %s" % String(_task.get("verb","Tap"))

func _rebuild_dots() -> void:
	if _dots_bar == null or _mech == "targets": return
	for c in _dots_bar.get_children(): c.queue_free()
	for i in _rounds:
		var dot := PanelContainer.new()
		dot.custom_minimum_size = Vector2(18, 18)
		var is_active := (i == _round_idx and _phase == "play")
		var sb: StyleBoxFlat
		if i < _round_idx:
			# sudah selesai — hit atau miss
			sb = UIKit.box(UIKit.INK, UIKit.INK, 2, 0)  # akan diupdate saat feedback
		elif is_active:
			sb = UIKit.box(UIKit.N300, UIKit.INK, 2, 0)
		else:
			sb = UIKit.box(Color(0,0,0,0), UIKit.INK, 2, 0)
		dot.add_theme_stylebox_override("panel", sb)
		_dots_bar.add_child(dot)

# ──────────────────────────────────────── HASIL ──────────────────

func _show_result() -> void:
	_phase = "result"
	var stars := _calc_stars()
	GameState.complete_field_task(String(_task.get("id","")), stars, "self")
	_build_result_screen(stars)

func _calc_stars() -> int:
	if _mech == "targets":
		var valid_n := float(_valid_cell_count())
		if valid_n <= 0: return 1
		var acc := float(_hits - _misses) / valid_n
		if acc >= 0.99 and _elapsed < 25.0: return 3
		if acc >= 0.6: return 2
		return 1
	else:
		var r := float(_hits) / float(maxi(_rounds, 1))
		if r >= 0.8: return 3
		if r >= 0.5: return 2
		return 1

func _build_result_screen(stars: int) -> void:
	# Hapus semua child lama
	for c in get_children(): c.queue_free()

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# Poster ACCENT
	var poster := PanelContainer.new()
	poster.add_theme_stylebox_override("panel", UIKit.box(UIKit.ACCENT, Color(0,0,0,0), 0, 0))
	var pm := MarginContainer.new()
	pm.add_theme_constant_override("margin_left", 16)
	pm.add_theme_constant_override("margin_right", 16)
	pm.add_theme_constant_override("margin_top", 56)
	pm.add_theme_constant_override("margin_bottom", 24)
	poster.add_child(pm)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 16)
	pm.add_child(pv)

	var mech_label := {"hold": "TAHAN", "timing": "TIMING", "targets": "TARGET"}
	pv.add_child(UIKit.kicker("%s · %s · SELESAI" % [
		mech_label.get(_mech, _mech.to_upper()), String(_task.get("verb","")).to_upper()],
		Color(UIKit.BG.r, UIKit.BG.g, UIKit.BG.b, 0.85)))

	var headlines := {3: "Sempurna.", 2: "Cukup baik.", 1: "Perlu latihan."}
	pv.add_child(UIKit.label(headlines.get(stars, "Selesai."), 44, UIKit.BG, 800))

	# Bintang 3 kotak 56×56
	var stars_row := HBoxContainer.new()
	stars_row.add_theme_constant_override("separation", 8)
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	for s in 3:
		var sq := PanelContainer.new()
		sq.custom_minimum_size = Vector2(56, 56)
		sq.add_theme_stylebox_override("panel",
			UIKit.box(UIKit.INK if s < stars else Color(0,0,0,0),
				UIKit.BG, 2, 0))
		if ResourceLoader.exists("res://assets/ui/icons/star.svg"):
			var ic := UIKit.icon("star", 24, UIKit.BG if s < stars else Color(UIKit.BG.r,UIKit.BG.g,UIKit.BG.b,0.45))
			ic.set_anchors_preset(Control.PRESET_CENTER)
			ic.position = Vector2(-12, -12)
			sq.add_child(ic)
		stars_row.add_child(sq)
	pv.add_child(stars_row)
	root.add_child(poster)

	# Strip statistik
	root.add_child(_make_result_stats(stars))

	# Catatan
	var note_m := UIKit.margin(16, 12, 16, 4)
	var hk_save := float(_task.get("hk_delegate", 0.5))
	var note_txt: String
	if stars == 3:
		note_txt = "Hasil terbaik tersimpan. Tugas ini tidak menambah biaya upah karena dikerjakan sendiri."
	else:
		if _mech == "targets":
			note_txt = "Syarat 3 bintang: tanpa salah pilih dan selesai di bawah 25 detik. Menugaskan tim selalu memberi 2 bintang."
		else:
			note_txt = "Syarat 3 bintang: minimal 80%% putaran tepat di zona. Menugaskan tim selalu memberi 2 bintang."
	var note_lbl := UIKit.label(note_txt, 13, UIKit.N700)
	note_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_m.add_child(note_lbl)
	root.add_child(note_m)

	var sp := Control.new(); sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(sp)

	# Tombol
	var btn_m := UIKit.margin(16, 8, 16, 24)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 10)
	btn_m.add_child(bv)
	bv.add_child(UIKit.btn("Kembali ke peta  ›",
		func(): get_tree().change_scene_to_file(HUB), "primary", 15, 52))
	var retry_btn := UIKit.btn("Ulangi tugas", func():
		_round_idx = 0; _hits = 0; _misses = 0
		_elapsed = 0.0; _feedback_lock = false; _phase = "play"
		_build(); _start_round(), "secondary", 14, 44)
	if ResourceLoader.exists("res://assets/ui/icons/rotate-ccw.svg"):
		retry_btn.icon = load("res://assets/ui/icons/rotate-ccw.svg")
	bv.add_child(retry_btn)
	root.add_child(btn_m)

func _make_result_stats(stars: int) -> Control:
	var strip := PanelContainer.new()
	var sb := UIKit.box(UIKit.BG, UIKit.INK, 0, 0)
	sb.border_width_top = 2; sb.border_width_bottom = 2
	strip.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	strip.add_child(h)
	var hk := float(_task.get("hk_delegate", 0.5))
	var cells: Array
	if _mech == "targets":
		var valid_n := float(maxi(_valid_cell_count(), 1))
		var acc := clampf(float(_hits - _misses) / valid_n * 100.0, 0.0, 100.0)
		cells = [
			["AKURASI", "%d%%" % int(acc)],
			["WAKTU", "%.1f dtk" % _elapsed],
			["UPAH HEMAT", "%s HK" % _fmt_hk(hk)],
		]
	else:
		cells = [
			["TEPAT", "%d/%d" % [_hits, _rounds]],
			["MELESET", "%d" % (_rounds - _hits)],
			["UPAH HEMAT", "%s HK" % _fmt_hk(hk)],
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

func _fmt_hk(hk) -> String:
	var v := float(hk)
	return ("%.1f" % v) if v != int(v) else ("%d" % int(v))
