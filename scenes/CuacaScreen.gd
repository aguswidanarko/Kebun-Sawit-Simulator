extends Control
## Cuaca & Prakiraan (design 1h) — light Modernist, tab "Cuaca".

func _ready() -> void:
	_build()
	if OS.get_cmdline_user_args().has("shotcuaca"):
		call_deferred("_capture")

func _capture() -> void:
	await get_tree().create_timer(0.7).timeout
	get_viewport().get_texture().get_image().save_png("user://cuaca.png")
	print("[cuaca] screenshot saved")
	get_tree().quit()

func _spray_eff(w: String) -> float:
	return float(Database.params.get("weather_spray_factor", {}).get(w, 1.0))

func _weed_fac(w: String) -> float:
	return float(Database.params.get("weather_weed_factor", {}).get(w, 1.0))

func _build() -> void:
	var content := UIKit.screen_root(self, "Cuaca")
	var m := UIKit.margin(16, 16, 16, 16)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	m.add_child(root)
	content.add_child(m)

	root.add_child(UIKit.kicker("Cuaca & prakiraan"))

	# kartu hari ini
	var today := GameState.weather
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.box(UIKit.SURFACE, UIKit.DIVIDER, 1, 14))
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 14)
	card.add_child(ch)
	var ic := PanelContainer.new()
	ic.custom_minimum_size = Vector2(72, 72)
	ic.add_theme_stylebox_override("panel", UIKit.box(UIKit.INK, UIKit.INK, 0, 0))
	var il := UIKit.icon(UIKit.weather_icon(today), 32, UIKit.BG)
	il.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	il.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.add_child(il)
	ch.add_child(ic)
	var cv := VBoxContainer.new()
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cv.add_theme_constant_override("separation", 2)
	cv.add_child(UIKit.label(today.capitalize(), 32, UIKit.INK, 800))
	cv.add_child(UIKit.wrap(UIKit.meta("Efektivitas semprot %d%% · laju gulma ×%s" % [
		int(round(_spray_eff(today) * 100)), ("%.1f" % _weed_fac(today)).replace(".", ",")], 12)))
	ch.add_child(cv)
	root.add_child(card)

	# grid 5 hari
	var horizon := GameState.forecast_days()
	var fc := TimeManager.forecast(4)
	var grid := PanelContainer.new()
	grid.add_theme_stylebox_override("panel", UIKit.box(UIKit.GRIDLINE, UIKit.GRIDLINE, 0, 1))
	var gh := HBoxContainer.new()
	gh.add_theme_constant_override("separation", 1)
	grid.add_child(gh)
	for i in 5:
		var cell := PanelContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_stylebox_override("panel", UIKit.box(UIKit.BG, Color(0, 0, 0, 0), 0, 8))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		cell.add_child(v)
		var dl := UIKit.label("H ini" if i == 0 else "H+%d" % i, 10, UIKit.N700, 600)
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(dl)
		var known := i == 0 or i <= horizon - 1
		var w := today if i == 0 else (String(fc[i - 1]) if i - 1 < fc.size() else "")
		var icon := UIKit.icon(UIKit.weather_icon(w) if known else "lock", 20, UIKit.INK if known else UIKit.N500)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(icon)
		var el := UIKit.label("%d%%" % int(round(_spray_eff(w) * 100)) if known else "—", 11,
			UIKit.INK if known else UIKit.N500, 600)
		el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(el)
		gh.add_child(cell)
	root.add_child(grid)
	if horizon < 5:
		root.add_child(UIKit.wrap(UIKit.meta("Prakiraan H+%d ke atas terkunci — hanya profil Analis (Nadia) yang melihat 5 hari." % horizon)))

	# saran jadwal semprot
	var tip := "Cuaca %s — semprot efektif hari ini." % today
	if _spray_eff(today) < 0.8:
		tip = "Cuaca %s — efektivitas semprot rendah." % today
		for i in fc.size():
			if i < horizon - 1 and String(fc[i]) == "cerah":
				tip += " Jadwalkan semprot H+%d (cerah)." % (i + 1)
				break
	var tipbox := PanelContainer.new()
	tipbox.add_theme_stylebox_override("panel", UIKit.box(UIKit.ACCENT_100, UIKit.DIVIDER, 1, 12))
	tipbox.add_child(UIKit.wrap(UIKit.label(tip, 12, UIKit.ACCENT_800)))
	root.add_child(tipbox)

	# tabel dampak cuaca
	root.add_child(UIKit.label("Dampak cuaca", 14, UIKit.INK, 800))
	var tbl := VBoxContainer.new()
	tbl.add_theme_constant_override("separation", 0)
	var head := HBoxContainer.new()
	for col in ["CUACA", "EFEK SEMPROT", "LAJU GULMA"]:
		var l := UIKit.label(col, 10, UIKit.N700, 600)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(l)
	tbl.add_child(head)
	tbl.add_child(UIKit.rule())
	for w in ["cerah", "mendung", "hujan"]:
		var row := HBoxContainer.new()
		var wcell := HBoxContainer.new()
		wcell.add_theme_constant_override("separation", 6)
		wcell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wcell.add_child(UIKit.icon(UIKit.weather_icon(w), 16, UIKit.INK))
		wcell.add_child(UIKit.label(w.capitalize(), 12, UIKit.INK, 400))
		row.add_child(wcell)
		for cell in [["%d%%" % int(round(_spray_eff(w) * 100)), 800],
				[("×%.1f" % _weed_fac(w)).replace(".", ","), 800]]:
			var l := UIKit.label(String(cell[0]), 12, UIKit.INK, int(cell[1]))
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
		var rm := UIKit.margin(0, 8, 0, 8)
		rm.add_child(row)
		tbl.add_child(rm)
		tbl.add_child(UIKit.rule(1))
	root.add_child(tbl)
