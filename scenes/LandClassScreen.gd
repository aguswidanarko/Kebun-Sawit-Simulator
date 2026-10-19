extends Control
## Sub-halaman Laporan: Penilaian Kelas Lahan (dari app penilaian-kelas-lahan).
## Ringkasan kelas kebun, kriteria S1/S2/S3, rincian per blok + capaian produksi A-E.

func _ready() -> void:
	_build()
	if OS.get_cmdline_user_args().has("shotkelas"):
		call_deferred("_capture")

func _capture() -> void:
	await get_tree().create_timer(0.7).timeout
	get_viewport().get_texture().get_image().save_png("user://kelas.png")
	print("[kelas] screenshot saved")
	get_tree().quit()

func _kelas_col(lc: String) -> Color:
	match lc:
		"S1": return UIKit.INK
		"S2": return UIKit.N600
		_: return UIKit.ACCENT_700

func _build() -> void:
	var content := UIKit.screen_root(self, "")
	var m := UIKit.margin(16, 12, 16, 16)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	m.add_child(root)
	content.add_child(m)

	# header back -> Laporan
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 8)
	hr.add_child(UIKit.btn("‹", func(): get_tree().change_scene_to_file("res://scenes/LaporanScreen.tscn"), "ghost", 20))
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UIKit.kicker("Laporan · kesesuaian lahan"))
	hv.add_child(UIKit.label("Penilaian Kelas Lahan", 22, UIKit.INK, 800))
	hr.add_child(hv)
	root.add_child(hr)

	# ---- Ringkasan kebun yang dimainkan ----
	var dom := GameState.dominant_land_class()
	var owned := 0
	for p in GameState.plots:
		if p.get("state", "kosong") != "kosong":
			owned += 1
	var sumc := PanelContainer.new()
	sumc.add_theme_stylebox_override("panel", UIKit.box(UIKit.BG, UIKit.INK, 2, 14))
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 4)
	sumc.add_child(sv)
	sv.add_child(UIKit.kicker("Kebun Anda", UIKit.N700))
	if dom == "":
		sv.add_child(UIKit.label("Belum ada lahan", 24, UIKit.INK, 800))
		sv.add_child(UIKit.wrap(UIKit.meta("Beli lahan dulu dari Peta Blok — kelas lahannya dinilai saat pembelian.")))
	else:
		var desc := String(Database.land_assessment.get("kelas_desc", {}).get(dom, ""))
		sv.add_child(UIKit.label("Kelas %s" % dom, 28, _kelas_col(dom), 800))
		sv.add_child(UIKit.wrap(UIKit.meta("%s · dominan dari %d blok dimiliki" % [desc, owned], 12)))
	root.add_child(sumc)

	# ---- Kriteria penilaian (persis app penilaian-kelas-lahan) ----
	root.add_child(UIKit.label("Kriteria penilaian", 14, UIKit.INK, 800))
	var la: Dictionary = Database.land_assessment
	var lr: Array = la.get("lereng_pct", [8, 15])
	var gd := float(la.get("gambut_dalam_m", 3))
	var crit := PanelContainer.new()
	crit.add_theme_stylebox_override("panel", UIKit.box(UIKit.SURFACE, UIKit.DIVIDER, 1, 12))
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	crit.add_child(cv)
	for row in [
			["Lereng", "<%d%% S1 · %d–%d%% S2 · >%d%% S3" % [int(lr[0]), int(lr[0]), int(lr[1]), int(lr[1])]],
			["Tanah", "Mineral S1 · gambut <%.0f m S2 · ≥%.0f m S3" % [gd, gd]],
			["Tata air", "Normal S1 · rawa terdrainase / kering S2 · tergenang S3"],
			["Kelas akhir", "Diambil dari faktor yang PALING BERAT"],
			["Pupuk", "Dosis S1 sebagai basis · S2 +5% · S3 +10%"]]:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		var k := UIKit.label(String(row[0]), 12, UIKit.N700, 600)
		k.custom_minimum_size = Vector2(76, 0)
		r.add_child(k)
		var v := UIKit.label(String(row[1]), 12, UIKit.INK)
		v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(v)
		cv.add_child(r)
	root.add_child(crit)

	# ---- Rincian per blok ----
	root.add_child(UIKit.label("Penilaian per blok", 14, UIKit.INK, 800))
	var any := false
	for p in GameState.plots:
		if p.get("state", "kosong") == "kosong":
			continue
		any = true
		root.add_child(_block_card(p))
	if not any:
		root.add_child(UIKit.wrap(UIKit.meta("Belum ada blok dimiliki.", 13)))

	root.add_child(UIKit.wrap(UIKit.meta("Sumber: aplikasi Penilaian Kelas Lahan (standar PPKS) — estimasi untuk bahan evaluasi.", 11)))

func _block_card(p: Dictionary) -> Control:
	var lc := String(p.get("land_class", "S1"))
	var a: Dictionary = GameState.plot_assessment(p)
	var la: Dictionary = Database.land_assessment
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.box(UIKit.BG, UIKit.DIVIDER, 1, 12))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	card.add_child(v)

	# header blok: id + badge kelas + status
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 8)
	var idl := UIKit.label(String(p.get("id", "?")), 17, UIKit.INK, 800)
	hr.add_child(idl)
	hr.add_child(UIKit.label(lc, 13, _kelas_col(lc), 800))
	var st := UIKit.meta(String(p.get("state", "")).capitalize())
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hr.add_child(st)
	v.add_child(hr)

	# faktor penilaian (lereng/tanah/air) — faktor terberat menentukan kelas
	var lr: Array = la.get("lereng_pct", [8, 15])
	var lereng := float(a.get("lereng", 3.0))
	var lereng_k := "S1" if lereng < float(lr[0]) else ("S2" if lereng <= float(lr[1]) else "S3")
	var tanah_k := "S1"
	var tanah_t := "Tanah mineral"
	if String(a.get("tanah", "mineral")) == "gambut":
		var gm := float(a.get("gambut_m", 0))
		tanah_k = "S3" if gm >= float(la.get("gambut_dalam_m", 3)) else "S2"
		tanah_t = "Gambut %.1f m" % gm
	var air_info: Array = la.get("air_labels", {}).get(String(a.get("air", "normal")), ["Air normal", "S1"])
	for f in [["Lereng %.0f%%" % lereng, lereng_k], [tanah_t, tanah_k], [String(air_info[0]), String(air_info[1])]]:
		var r := HBoxContainer.new()
		var t := UIKit.meta(String(f[0]), 12)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(t)
		r.add_child(UIKit.label(String(f[1]), 12, _kelas_col(String(f[1])), 800))
		v.add_child(r)

	# capaian produksi (blok tanam TM): estimasi vs standar kelas -> klasifikasi A-E
	if p.get("state") == "tanam":
		var age := GameState.age_years_of(p)
		var std := Database.get_production(age, lc)
		if std > 0.0:
			var est := std * float(p.get("health", 1.0))
			var ach := est / std
			var klas := _klasifikasi(ach)
			v.add_child(UIKit.rule(1))
			var pr := HBoxContainer.new()
			var pl := UIKit.meta("Estimasi %.1f vs standar %.1f t/ha/th" % [est, std], 12)
			pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pr.add_child(pl)
			pr.add_child(UIKit.label("%s · %.0f%%" % [String(klas.get("k", "?")), ach * 100.0], 13,
				UIKit.INK if ach >= 0.95 else UIKit.ACCENT_700, 800))
			v.add_child(pr)
			v.add_child(UIKit.wrap(UIKit.meta(String(klas.get("label", "")) + " — " + String(klas.get("desc", "")), 11)))
		else:
			v.add_child(UIKit.wrap(UIKit.meta("Umur %d th — standar produksi mulai umur produktif." % age, 11)))
	return card

func _klasifikasi(ach: float) -> Dictionary:
	for c in Database.land_assessment.get("klasifikasi", []):
		if ach >= float(c.get("lo", 0)):
			return c
	return {}
