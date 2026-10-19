extends Control
## Sosial & Kunjungan (design 1l) — kartu kebun sendiri + daftar teman (friends_demo.json).

var _sheet: CanvasLayer

func _ready() -> void:
	_build()
	if OS.get_cmdline_user_args().has("shotsosial"):
		call_deferred("_capture")

func _capture() -> void:
	await get_tree().create_timer(0.7).timeout
	get_viewport().get_texture().get_image().save_png("user://sosial.png")
	print("[sosial] screenshot saved")
	get_tree().quit()

func _friends() -> Array:
	var path := "res://data/friends_demo.json"
	if not FileAccess.file_exists(path):
		return []
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary:
		return data.get("friends", [])
	return []

func _own_stats() -> Dictionary:
	var ha := 0
	var hp_sum := 0.0
	var hp_n := 0
	var golden := 0
	for p in GameState.plots:
		if p.get("state") != "kosong":
			ha += 1
		if p.get("state") == "tanam":
			hp_sum += float(p.get("health", 1.0))
			hp_n += 1
			golden += int(p.get("golden_count", 0))
	return { "ha": ha, "sehat": (hp_sum / hp_n * 100.0) if hp_n > 0 else 0.0, "golden": golden }

func _build() -> void:
	var content := UIKit.screen_root(self, "Sosial")
	var m := UIKit.margin(16, 16, 16, 16)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	m.add_child(root)
	content.add_child(m)

	root.add_child(UIKit.kicker("Sosial"))
	root.add_child(UIKit.label("Kunjungi Kebun Teman", 22, UIKit.INK, 800))

	# kartu kebun sendiri
	var own := _own_stats()
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.box(UIKit.INK, UIKit.INK, 0, 14))
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	card.add_child(cv)
	cv.add_child(UIKit.label(GameState.display_kebun_name(), 17, UIKit.BG, 800))
	cv.add_child(UIKit.label("%d ha · sehat %.0f%% · ★%d Golden" % [own.ha, own.sehat, own.golden],
		12, Color(UIKit.BG.r, UIKit.BG.g, UIKit.BG.b, 0.8)))
	var exp := UIKit.btn("Ekspor snapshot kebun", func():
		GameState.export_kebun()
		UIKit.toast(self, "Snapshot kebun diekspor — bagikan agar teman bisa berkunjung."), "primary")
	cv.add_child(exp)
	root.add_child(card)

	root.add_child(UIKit.rule())
	root.add_child(UIKit.label("Teman", 14, UIKit.INK, 800))

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	root.add_child(list)
	for f in _friends():
		list.add_child(_friend_row(f))
		list.add_child(UIKit.rule(1))

func _friend_row(f: Dictionary) -> Control:
	var m := UIKit.margin(0, 10, 0, 10)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	m.add_child(h)
	var phc := Control.new()
	phc.custom_minimum_size = Vector2(64, 64)
	phc.clip_contents = true
	var img_name := String(f.get("img", "")).get_file()
	var ph := UIKit.photo("res://assets/bg/%s" % img_name)
	ph.set_anchors_preset(Control.PRESET_FULL_RECT)
	phc.add_child(ph)
	h.add_child(phc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	v.add_child(UIKit.label(("%s %s" % [f.get("badge", ""), f.get("name", "?")]).strip_edges(), 14, UIKit.INK, 800))
	v.add_child(UIKit.meta("%s · %s" % [f.get("owner", "?"), f.get("prof", "")]))
	var cells: Array = f.get("cells", [])
	var planted := 0
	var hp_sum := 0.0
	for c in cells:
		if c is float or c is int:
			planted += 1
			hp_sum += float(c)
	var sehat := (hp_sum / planted * 100.0) if planted > 0 else 0.0
	v.add_child(UIKit.meta("%d ha · sehat %.0f%% · ★%d" % [cells.size(), sehat, int(f.get("golden", 0))]))
	h.add_child(v)
	h.add_child(UIKit.label("›", 20, UIKit.N500))
	m.mouse_filter = Control.MOUSE_FILTER_STOP
	m.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_open_visit(f))
	return m

func _close_visit() -> void:
	if _sheet:
		_sheet.queue_free()
		_sheet = null

# Kunjungan read-only (sheet berisi grid blok teman).
func _open_visit(f: Dictionary) -> void:
	if _sheet:
		_sheet.queue_free()
	_sheet = CanvasLayer.new()
	add_child(_sheet)
	var backdrop := ColorRect.new()
	backdrop.color = Color(UIKit.INK.r, UIKit.INK.g, UIKit.INK.b, 0.5)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_close_visit())
	_sheet.add_child(backdrop)
	var sheet := PanelContainer.new()
	sheet.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sheet.offset_top = -520
	var sb := UIKit.box(UIKit.BG, UIKit.INK, 0, 16)
	sb.border_width_top = 2
	sheet.add_theme_stylebox_override("panel", sb)
	_sheet.add_child(sheet)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	sheet.add_child(v)
	var hr := HBoxContainer.new()
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UIKit.kicker("Kunjungan · read-only"))
	hv.add_child(UIKit.label(("%s %s" % [f.get("badge", ""), f.get("name", "?")]).strip_edges(), 20, UIKit.INK, 800))
	hr.add_child(hv)
	hr.add_child(UIKit.close_btn(_close_visit))
	v.add_child(hr)
	v.add_child(UIKit.meta("%s · %s" % [f.get("owner", "?"), f.get("prof", "")], 12))

	var gp := PanelContainer.new()
	gp.add_theme_stylebox_override("panel", UIKit.box(UIKit.GRIDLINE, UIKit.GRIDLINE, 0, 2))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	gp.add_child(grid)
	var cells: Array = f.get("cells", [])
	for i in cells.size():
		var c = cells[i]
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(0, 86)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 3)
		cell.add_child(cv)
		cv.add_child(UIKit.label("B%d" % (i + 1), 14, UIKit.INK, 800))
		if c is float or c is int:
			var hp := float(c)
			cell.add_theme_stylebox_override("panel",
				UIKit.box(UIKit.ACCENT_100 if hp < 0.7 else UIKit.SURFACE, Color(0, 0, 0, 0), 0, 8))
			cv.add_child(UIKit.meta("Sehat %.0f%%" % (hp * 100)))
			cv.add_child(UIKit.bar(hp, UIKit.ACCENT if hp < 0.7 else UIKit.INK))
		else:
			cell.add_theme_stylebox_override("panel", UIKit.box(UIKit.BG, Color(0, 0, 0, 0), 0, 8))
			match String(c):
				"b": cv.add_child(UIKit.meta("Pembukaan"))
				"s": cv.add_child(UIKit.meta("Lahan siap"))
				_: cv.add_child(UIKit.meta("Kosong"))
		grid.add_child(cell)
	v.add_child(gp)
	v.add_child(UIKit.meta("★%d Golden Tree di kebun ini" % int(f.get("golden", 0)), 12))
