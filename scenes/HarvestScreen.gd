extends Control
## Panen & Jual TBS (design 1g) — light Modernist, tab "Panen".

var _buyer := "pengepul"
var _body: VBoxContainer
var _header_box: VBoxContainer

func _ready() -> void:
	_build()
	if OS.get_cmdline_user_args().has("shotharvest"):
		call_deferred("_capture")

func _capture() -> void:
	await get_tree().create_timer(0.7).timeout
	get_viewport().get_texture().get_image().save_png("user://harvest.png")
	print("[harvest] screenshot saved")
	get_tree().quit()

func _ready_plots() -> Array:
	var a: Array = []
	for p in GameState.plots:
		if p.get("state") == "tanam" and TimeManager.harvest_due(p):
			var seed := Database.get_seed(String(p.get("seed_id", "")))
			if GameState.age_years_of(p) >= int(seed.get("start_harvest_age_year", 4)):
				a.append(p)
	return a

func _kg(p: Dictionary) -> float:
	return Agronomy.tbs_batch_kg(p)

func _build() -> void:
	var content := UIKit.screen_root(self, "Panen")
	var m := UIKit.margin(16, 16, 16, 16)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	m.add_child(root)
	content.add_child(m)

	_header_box = VBoxContainer.new()
	_header_box.add_theme_constant_override("separation", 4)
	root.add_child(_header_box)
	root.add_child(UIKit.rule())

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	root.add_child(_body)
	_refresh()

func _refresh() -> void:
	for c in _header_box.get_children():
		c.queue_free()
	for c in _body.get_children():
		c.queue_free()

	var ready := _ready_plots()
	var total_kg := 0.0
	for p in ready:
		total_kg += _kg(p)

	var rot := TimeManager.harvest_rotation_days
	_header_box.add_child(UIKit.kicker("Panen & jual TBS"))
	_header_box.add_child(UIKit.label(("%s kg siap panen" % GameState._fmt(int(total_kg))), 26, UIKit.INK, 800))
	_header_box.add_child(UIKit.wrap(UIKit.meta("Rotasi panen %d hari · harga dasar Rp%s/kg" % [rot, GameState._fmt(int(Database.params.get("tbs_price_rp_per_kg", 2800)))])))

	if ready.is_empty():
		_body.add_child(UIKit.wrap(UIKit.meta("Belum ada blok siap panen — rotasi %d hari belum tercapai atau tanaman belum cukup umur." % rot, 13)))
		_body.add_child(UIKit.btn("Lanjut %d hari  »" % rot, func():
			TimeManager.advance_day(rot)
			_refresh(), "primary"))
		return

	_body.add_child(UIKit.wrap(UIKit.label("⚠ Panen rotasi ini sekarang — TBS matang yang tidak dipanen akan membusuk & tonasenya hilang (tidak terbawa ke rotasi berikutnya).", 12, UIKit.ACCENT_700, 600)))

	# tabel blok
	var table := VBoxContainer.new()
	table.add_theme_constant_override("separation", 0)
	var head := HBoxContainer.new()
	for col in [["BLOK", 1.0], ["VARIETAS", 1.6], ["SEHAT", 0.9], ["TBS", 0.9]]:
		var l := UIKit.label(String(col[0]), 10, UIKit.N700, 600)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.size_flags_stretch_ratio = float(col[1])
		head.add_child(l)
	table.add_child(head)
	table.add_child(UIKit.rule())
	for p in ready:
		var seed := Database.get_seed(String(p.get("seed_id", "")))
		var row := HBoxContainer.new()
		for cell in [[String(p.get("id")), 1.0, 800], [String(seed.get("variety_name", "?")).split(" ")[0], 1.6, 400],
				["%.0f%%" % (float(p.get("health", 1.0)) * 100), 0.9, 400],
				[("%.1f t" % (_kg(p) / 1000.0)).replace(".", ","), 0.9, 800]]:
			var l := UIKit.label(String(cell[0]), 12, UIKit.INK, int(cell[2]))
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.size_flags_stretch_ratio = float(cell[1])
			row.add_child(l)
		var rm := UIKit.margin(0, 8, 0, 8)
		rm.add_child(row)
		table.add_child(rm)
		table.add_child(UIKit.rule(1))
	_body.add_child(table)

	# pilihan pembeli (grid 2 kolom)
	_body.add_child(UIKit.label("Pilihan pembeli", 14, UIKit.INK, 800))
	var seed0 := Database.get_seed(String(ready[0].get("seed_id", "")))
	var hp0 := float(ready[0].get("health", 1.0))
	var p_pengepul := Actions._price(seed0, hp0, "pengepul")
	var p_pabrik := Actions._price(seed0, hp0, "pabrik")
	var bg2 := HBoxContainer.new()
	bg2.add_theme_constant_override("separation", 8)
	bg2.add_child(_buyer_card("Pengepul", "Rp%.0f/kg flat · tanpa grading" % p_pengepul, "pengepul"))
	bg2.add_child(_buyer_card("Pabrik", "Rp%.0f/kg · ikut rendemen & kualitas − transport" % p_pabrik, "pabrik"))
	_body.add_child(bg2)
	var diff := int(abs(p_pabrik - p_pengepul) * total_kg)
	_body.add_child(UIKit.label("Selisih pilihan ±Rp%s untuk panen ini" % GameState._fmt(diff), 11, UIKit.ACCENT_700, 600))

	# rincian
	var gross := 0
	var labor := 0
	for p in ready:
		var seed := Database.get_seed(String(p.get("seed_id", "")))
		gross += int(_kg(p) * Actions._price(seed, float(p.get("health", 1.0)), _buyer))
		labor += Agronomy.labor_cost("panen", float(p.get("area_ha", 1.0)))
	var net := gross - labor
	var rin := VBoxContainer.new()
	rin.add_theme_constant_override("separation", 6)
	for pair in [["Pendapatan kotor", "Rp" + GameState._fmt(gross), 400],
			["Upah panen (HK)", "−Rp" + GameState._fmt(labor), 400],
			["Bersih", "Rp" + GameState._fmt(net), 800]]:
		var row := HBoxContainer.new()
		var k := UIKit.label(String(pair[0]), 13, UIKit.N700 if int(pair[2]) < 800 else UIKit.INK, 400)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(k)
		row.add_child(UIKit.label(String(pair[1]), 14, UIKit.INK, int(pair[2])))
		rin.add_child(row)
	var rp := PanelContainer.new()
	rp.add_theme_stylebox_override("panel", UIKit.box(UIKit.SURFACE, UIKit.DIVIDER, 1, 12))
	rp.add_child(rin)
	_body.add_child(rp)

	_body.add_child(UIKit.btn("Panen & jual — Rp%s" % GameState._fmt(net),
		_harvest_all, "primary", 15, 52))

func _buyer_card(title: String, desc: String, id: String) -> Control:
	var sel := _buyer == id
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 92)
	card.add_theme_stylebox_override("panel",
		UIKit.box(UIKit.INK if sel else UIKit.BG, UIKit.INK if sel else UIKit.DIVIDER, 2 if sel else 1, 12))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	v.add_child(UIKit.label(title, 15, UIKit.BG if sel else UIKit.INK, 800))
	var d := UIKit.label(desc, 11, Color(UIKit.BG.r, UIKit.BG.g, UIKit.BG.b, 0.8) if sel else UIKit.N700)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_buyer = id
			_refresh())
	return card

func _harvest_all() -> void:
	var ready := _ready_plots()
	var total := 0
	for p in ready:
		var seed := Database.get_seed(String(p.get("seed_id", "")))
		var kg := _kg(p)
		var price := Actions._price(seed, float(p.get("health", 1.0)), _buyer)
		var net := int(kg * price) - Agronomy.labor_cost("panen", float(p.get("area_ha", 1.0)))
		p["last_harvest_day"] = GameState.day
		total += max(0, net)
	if total > 0:
		GameState.earn(total, "Panen TBS → %s" % _buyer.capitalize())
		GameState.mark_objective("harvested")
	GameState.log_msg("Panen %d blok ke %s: Rp%s" % [ready.size(), _buyer, GameState._fmt(total)])
	UIKit.toast(self, "Panen %d blok — bersih Rp%s." % [ready.size(), GameState._fmt(total)])
	_refresh()
