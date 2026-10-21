extends Control
## Hall of Fame — peringkat per level kesulitan, semua level, dan GLOBAL (online).
##
## Tab Normal/Sulit/Krisis/Semua = rekor LOKAL di perangkat ini, diurutkan pakai
## skor gabungan (kecepatan balik modal + profit + luas lahan).
##
## Tab Global = peringkat ONLINE lintas pemain dari Firestore
## (lihat autoload/LeaderboardManager.gd). Entri server hanya menyimpan
## kebun_name/profile_id/profit/day — tidak ada break_even_day atau plots_owned —
## jadi tab ini diurutkan MURNI BERDASARKAN PROFIT (server sudah mengurutkannya),
## bukan skor gabungan. Perbedaan ini ditulis di keterangan tiap tab.

var list: VBoxContainer
var _active_tab: String = "normal"
var _desc_label: Label
## Penanda permintaan. Fetch online butuh await; kalau pemain keburu pindah tab
## sebelum respons datang, hasil yang basi tidak boleh menimpa tampilan baru.
var _fetch_token: int = 0

const TAB_GLOBAL := "global"
const TABS := [
	["normal", "Normal"],
	["sulit",  "Sulit"],
	["krisis", "Krisis"],
	["semua",  "Semua"],
	[TAB_GLOBAL, "🌐 Global"],
]
const DIFF_COLORS := {
	"normal": "16693f", "sulit": "d97706", "krisis": "b91c1c",
	"semua": "374151", TAB_GLOBAL: "1d4ed8",
}
const TAB_DESC := {
	"normal": "Rekor di perangkat ini. Skor = 40% kecepatan balik modal + 40% profit + 20% luas lahan.",
	"sulit":  "Rekor di perangkat ini. Skor = 40% kecepatan balik modal + 40% profit + 20% luas lahan.",
	"krisis": "Rekor di perangkat ini. Skor = 40% kecepatan balik modal + 40% profit + 20% luas lahan.",
	"semua":  "Semua level kesulitan digabung, dari perangkat ini saja.",
	TAB_GLOBAL: "Peringkat online lintas pemain, diurutkan berdasarkan profit tertinggi.",
}

var _tab_btns: Dictionary = {}

func _ready() -> void:
	_active_tab = GameState.difficulty  # mulai di tab sesuai game aktif
	_build()
	_refresh()
	if OS.get_cmdline_user_args().has("shothof"):
		call_deferred("_capture")

## Screenshot tab Global untuk cek visual (pola sama dgn layar lain: shotdash, shotsosial).
func _capture() -> void:
	_active_tab = TAB_GLOBAL
	_rebuild_tabs()
	_refresh()
	await get_tree().create_timer(3.0).timeout   # tunggu request online selesai/gagal
	get_viewport().get_texture().get_image().save_png("user://hof_global.png")
	print("[hof] screenshot saved")
	get_tree().quit()

func _build() -> void:
	var root := VBoxContainer.new()
	root.anchor_right = 1.0; root.anchor_bottom = 1.0
	root.offset_left = 16; root.offset_top = 12; root.offset_right = -16; root.offset_bottom = -12
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	root.add_child(UIKit.label("🏆 Hall of Fame", 22, UIKit.INK, 800))
	_desc_label = UIKit.wrap(UIKit.meta(TAB_DESC.get(_active_tab, ""), 12))
	root.add_child(_desc_label)

	# Tab bar level kesulitan
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 0)
	for entry in TABS:
		var tid: String = entry[0]
		var tlabel: String = entry[1]
		var active: bool = (_active_tab == tid)
		var b := Button.new()
		b.text = tlabel
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 38)
		b.add_theme_font_size_override("font_size", 12)
		b.add_theme_font_override("font", UIKit.bold() if active else UIKit.semi())
		b.add_theme_color_override("font_color", UIKit.INK if active else UIKit.N600)
		var tsb := UIKit.box(Color(0, 0, 0, 0),
			Color.html(DIFF_COLORS.get(tid, "374151")) if active else UIKit.DIVIDER, 0, 8)
		tsb.border_width_bottom = 3 if active else 1
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, tsb)
		b.pressed.connect(func():
			_active_tab = tid
			_rebuild_tabs()
			_refresh())
		tabs.add_child(b)
		_tab_btns[tid] = b
	root.add_child(tabs)

	root.add_child(UIKit.rule())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	root.add_child(UIKit.btn("← Kembali",
		func(): get_tree().change_scene_to_file("res://scenes/DashboardScreen.tscn")))

func _rebuild_tabs() -> void:
	for tid in _tab_btns:
		var b: Button = _tab_btns[tid]
		var active: bool = (_active_tab == tid)
		b.add_theme_font_override("font", UIKit.bold() if active else UIKit.semi())
		b.add_theme_color_override("font_color", UIKit.INK if active else UIKit.N600)
		var tsb := UIKit.box(Color(0, 0, 0, 0),
			Color.html(DIFF_COLORS.get(tid, "374151")) if active else UIKit.DIVIDER, 0, 8)
		tsb.border_width_bottom = 3 if active else 1
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, tsb)

func _refresh() -> void:
	_fetch_token += 1
	var token := _fetch_token
	_clear_list()
	if _desc_label:
		_desc_label.text = TAB_DESC.get(_active_tab, "")

	if _active_tab == TAB_GLOBAL:
		await _refresh_global(token)
		return

	var entries: Array = []
	if _active_tab == "semua":
		entries = GameState.hall_of_fame_entries_all()
	else:
		entries = GameState.hall_of_fame_entries(_active_tab)

	if entries.is_empty():
		list.add_child(UIKit.meta("Belum ada rekor di level ini."))
		return

	entries.sort_custom(func(a, b):
		return GameState.calculate_hof_score(a) > GameState.calculate_hof_score(b))

	for i in entries.size():
		list.add_child(_row(i + 1, entries[i], false))

## Ambil peringkat online. Dipisah karena perlu await (request jaringan).
func _refresh_global(token: int) -> void:
	list.add_child(UIKit.meta("Memuat peringkat global…"))
	var entries: Array = await LeaderboardManager.fetch_top(50)
	# Pemain sudah pindah tab / keluar layar selagi menunggu respons -> buang hasil.
	if token != _fetch_token or not is_instance_valid(list):
		return
	_clear_list()

	var online: bool = LeaderboardManager.last_fetch_online
	if not online:
		list.add_child(_notice(
			"Tidak bisa terhubung ke server. Yang tampil di bawah adalah rekor di perangkat ini.\n"
			+ "Periksa koneksi internet, atau Firebase memang belum disiapkan."))
	if entries.is_empty():
		list.add_child(UIKit.meta(
			"Belum ada rekor global. Jadilah yang pertama — mainkan sampai balik modal!"
			if online else "Belum ada rekor."))
		return
	for i in entries.size():
		list.add_child(_row(i + 1, entries[i], online))

func _clear_list() -> void:
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()

## Kotak pemberitahuan (dipakai saat gagal terhubung).
func _notice(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.box(UIKit.ACCENT_100, UIKit.ACCENT_300, 1, 10))
	var l := UIKit.label(text, 11, UIKit.ACCENT_800)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(l)
	return p

## `online` = entri berasal dari Firestore. Entri server TIDAK punya field
## difficulty/week (hanya kebun_name/profile_id/profit/day), jadi baris
## sub-info dirender berbeda — bukan ditampilkan sebagai "Normal" palsu.
func _row(rank: int, e: Dictionary, online: bool) -> PanelContainer:
	var name_str := String(e.get("kebun_name", "?"))
	var is_me := online and name_str == GameState.display_player_name()
	var card := PanelContainer.new()
	var is_top3 := rank <= 3
	var bg: Color = UIKit.ACCENT_100 if (is_top3 or is_me) else UIKit.SURFACE
	card.add_theme_stylebox_override("panel", UIKit.box(
		bg, UIKit.ACCENT_700 if is_me else UIKit.DIVIDER, 2 if is_me else 1, 10))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)
	var medals := ["🥇", "🥈", "🥉"]
	var rank_lbl := UIKit.label(
		medals[rank - 1] if is_top3 else "#%d" % rank, 16, UIKit.INK, 800)
	rank_lbl.custom_minimum_size = Vector2(36, 0)
	h.add_child(rank_lbl)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 1)
	v.add_child(UIKit.label(name_str + ("  (kamu)" if is_me else ""), 13, UIKit.INK, 800))

	var sub := ""
	if online:
		# profile_id -> nama karakter yang terbaca pemain.
		var prof := Database.get_profile(String(e.get("profile_id", "")))
		var prof_name := String(prof.get("short_name", prof.get("name", "")))
		sub = "Hari ke-%d" % int(e.get("day", 0))
		if prof_name != "":
			sub += " · %s" % prof_name
	else:
		var diff_str := String(e.get("difficulty", "normal"))
		var diff_labels := {"normal": "Normal", "sulit": "⚠ Sulit", "krisis": "🔥 Krisis"}
		sub = "Hari ke-%d · Minggu %d · %s" % [
			int(e.get("day", 0)), int(e.get("week", 0)), diff_labels.get(diff_str, diff_str)]
	v.add_child(UIKit.meta(sub, 10))
	h.add_child(v)

	var profit := int(e.get("profit", 0))
	var pcol: Color = UIKit.ACCENT_700 if profit >= 0 else UIKit.N600
	h.add_child(UIKit.label("Rp%s" % GameState._fmt(profit), 13, pcol, 800))
	return card
