extends Control
## Laporan keuangan + log (design 1n) — light Modernist, tab "Laporan".

func _ready() -> void:
	_build()
	if OS.get_cmdline_user_args().has("shotlaporan"):
		call_deferred("_capture")

func _capture() -> void:
	await get_tree().create_timer(0.7).timeout
	get_viewport().get_texture().get_image().save_png("user://laporan.png")
	print("[laporan] screenshot saved")
	get_tree().quit()

func _build() -> void:
	var content := UIKit.screen_root(self, "Laporan")
	var m := UIKit.margin(16, 16, 16, 16)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	m.add_child(root)
	content.add_child(m)

	root.add_child(UIKit.kicker("Laporan keuangan"))
	root.add_child(UIKit.label("Rp%s" % GameState._fmt(GameState.cash), 30, UIKit.INK, 800))
	root.add_child(UIKit.meta("Saldo hari %d" % GameState.day, 12))

	# strip masuk/keluar/bersih
	var masuk := 0
	var keluar := 0
	for e in GameState.ledger:
		var a := int(e.get("a", 0))
		if a >= 0:
			masuk += a
		else:
			keluar += -a
	var strip := PanelContainer.new()
	var sb := UIKit.box(UIKit.BG, UIKit.INK, 0, 0)
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	strip.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	strip.add_child(h)
	var cells := [["Masuk", UIKit.rp_short(masuk), UIKit.INK],
		["Keluar", UIKit.rp_short(keluar), UIKit.ACCENT_700],
		["Bersih", UIKit.rp_short(masuk - keluar), UIKit.INK]]
	for i in cells.size():
		if i > 0:
			h.add_child(UIKit.vrule())
		var c = cells[i]
		var mc := UIKit.margin(12, 10, 12, 10)
		mc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 2)
		cv.add_child(UIKit.label(String(c[0]).to_upper(), 10, UIKit.N700, 600))
		cv.add_child(UIKit.label(String(c[1]), 15, c[2], 800))
		mc.add_child(cv)
		h.add_child(mc)
	root.add_child(strip)

	# sub-halaman: penilaian kelas lahan
	var dom := GameState.dominant_land_class()
	var kelas_btn := UIKit.btn(
		"Penilaian Kelas Lahan%s  ›" % (("  ·  kebun: %s" % dom) if dom != "" else ""),
		func(): get_tree().change_scene_to_file("res://scenes/LandClassScreen.tscn"))
	root.add_child(kelas_btn)

	# tabel log
	root.add_child(UIKit.label("Riwayat transaksi", 14, UIKit.INK, 800))
	if GameState.ledger.is_empty():
		root.add_child(UIKit.wrap(UIKit.meta("Belum ada transaksi. Mulai kelola kebunmu — semua pemasukan & pengeluaran tercatat di sini.", 13)))
		return
	var tbl := VBoxContainer.new()
	tbl.add_theme_constant_override("separation", 0)
	var head := HBoxContainer.new()
	for col in [["HARI", 0.6], ["KETERANGAN", 2.2], ["JUMLAH", 1.0]]:
		var l := UIKit.label(String(col[0]), 10, UIKit.N700, 600)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.size_flags_stretch_ratio = float(col[1])
		head.add_child(l)
	tbl.add_child(head)
	tbl.add_child(UIKit.rule())
	var entries := GameState.ledger.duplicate()
	entries.reverse()
	var shown := 0
	for e in entries:
		if shown >= 60:
			tbl.add_child(UIKit.margin(0, 8, 0, 0))
			tbl.add_child(UIKit.meta("… %d transaksi lebih lama tidak ditampilkan" % (entries.size() - shown)))
			break
		shown += 1
		var a := int(e.get("a", 0))
		var row := HBoxContainer.new()
		var d := UIKit.label(str(int(e.get("d", 0))), 12, UIKit.N700)
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		d.size_flags_stretch_ratio = 0.6
		row.add_child(d)
		var t := UIKit.label(String(e.get("t", "")), 12, UIKit.INK)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.size_flags_stretch_ratio = 2.2
		t.clip_text = true
		row.add_child(t)
		var amt := UIKit.label(("+" if a >= 0 else "−") + "Rp" + GameState._fmt(abs(a)), 12,
			UIKit.INK if a >= 0 else UIKit.ACCENT_700, 800)
		amt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		amt.size_flags_stretch_ratio = 1.0
		amt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(amt)
		var rm := UIKit.margin(0, 7, 0, 7)
		rm.add_child(row)
		tbl.add_child(rm)
		tbl.add_child(UIKit.rule(1))
	root.add_child(tbl)
