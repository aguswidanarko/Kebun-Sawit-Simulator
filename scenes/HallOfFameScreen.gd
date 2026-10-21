extends Control
## Hall of Fame — peringkat per level kesulitan & semua level.
## Tab: Normal · Sulit · Krisis · Semua. Setiap tab tersortir by skor gabungan.

var list: VBoxContainer
var _active_tab: String = "normal"

const TABS := [
	["normal", "Normal"],
	["sulit",  "Sulit"],
	["krisis", "Krisis"],
	["semua",  "Semua"],
]
const DIFF_COLORS := {
	"normal": "16693f", "sulit": "d97706", "krisis": "b91c1c", "semua": "374151"
}

var _tab_btns: Dictionary = {}

func _ready() -> void:
	_active_tab = GameState.difficulty  # mulai di tab sesuai game aktif
	_build()
	_refresh()

func _build() -> void:
	var root := VBoxContainer.new()
	root.anchor_right = 1.0; root.anchor_bottom = 1.0
	root.offset_left = 16; root.offset_top = 12; root.offset_right = -16; root.offset_bottom = -12
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	root.add_child(UIKit.label("🏆 Hall of Fame", 22, UIKit.INK, 800))
	root.add_child(UIKit.wrap(UIKit.meta(
		"Skor = 40% kecepatan balik modal + 40% profit + 20% luas lahan. Dipisahkan per level kesulitan.", 12)))

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
	for c in list.get_children():
		c.queue_free()

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
		list.add_child(_row(i + 1, entries[i]))

func _row(rank: int, e: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var is_top3 := rank <= 3
	card.add_theme_stylebox_override("panel", UIKit.box(
		UIKit.ACCENT_100 if is_top3 else UIKit.SURFACE, UIKit.DIVIDER, 1, 10))
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
	v.add_child(UIKit.label(String(e.get("kebun_name", "?")), 13, UIKit.INK, 800))
	# Sub-info: hari, minggu, level
	var diff_str := String(e.get("difficulty", "normal"))
	var diff_labels := {"normal": "Normal", "sulit": "⚠ Sulit", "krisis": "🔥 Krisis"}
	var week := int(e.get("week", 0))
	var sub := "Hari ke-%d · Minggu %d · %s" % [int(e.get("day", 0)), week, diff_labels.get(diff_str, diff_str)]
	v.add_child(UIKit.meta(sub, 10))
	h.add_child(v)
	var profit := int(e.get("profit", 0))
	var diff_col_map := {"sulit": UIKit.ACCENT_700, "krisis": UIKit.ACCENT_700}
	var pcol: Color = diff_col_map.get(diff_str, UIKit.ACCENT_700) if profit >= 0 else UIKit.N600
	h.add_child(UIKit.label("Rp%s" % GameState._fmt(profit), 13, pcol, 800))
	return card
