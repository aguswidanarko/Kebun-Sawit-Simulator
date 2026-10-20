extends Control
## Hall of Fame — peringkat profit tertinggi, lintas pemain/device via
## Firestore (lihat autoload/LeaderboardManager.gd). Fallback otomatis ke
## rekor lokal (GameState.hall_of_fame_entries()) kalau request gagal.

var list: VBoxContainer
var banner: PanelContainer

func _ready() -> void:
	_build()
	_refresh()

func _build() -> void:
	var root := VBoxContainer.new()
	root.anchor_right = 1.0; root.anchor_bottom = 1.0
	root.offset_left = 16; root.offset_top = 12; root.offset_right = -16; root.offset_bottom = -12
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	root.add_child(UIKit.label("🏆 Hall of Fame", 22, UIKit.INK, 800))
	root.add_child(UIKit.wrap(UIKit.meta("Peringkat profit bersih (saldo sekarang dikurangi modal awal Rp100 juta) tertinggi.", 12)))

	banner = PanelContainer.new()
	root.add_child(banner)

	root.add_child(UIKit.rule())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	root.add_child(UIKit.btn("← Kembali", func(): get_tree().change_scene_to_file("res://scenes/DashboardScreen.tscn")))

func _refresh_banner() -> void:
	for c in banner.get_children():
		c.queue_free()
	banner.add_theme_stylebox_override("panel", UIKit.box(UIKit.SURFACE, UIKit.DIVIDER, 1, 10))
	var txt := Label.new()
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.add_theme_font_size_override("font_size", 12)
	txt.text = "🌐 Terhubung ke leaderboard online — peringkat di bawah ini lintas pemain."
	banner.add_child(txt)

func _refresh() -> void:
	_refresh_banner()
	for c in list.get_children():
		c.queue_free()
	var entries: Array = await LeaderboardManager.fetch_top(20)
	if entries.is_empty():
		list.add_child(UIKit.meta("Belum ada rekor — profit pertama Anda akan muncul di sini."))
		return
	# Sort by ranking formula (sama seperti di GameState)
	entries.sort_custom(func(a, b):
		var score_a := GameState.calculate_hof_score(a)
		var score_b := GameState.calculate_hof_score(b)
		return score_a > score_b)
	for i in entries.size():
		var e: Dictionary = entries[i]
		list.add_child(_row(i + 1, e))

func _row(rank: int, e: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var is_top3 := rank <= 3
	card.add_theme_stylebox_override("panel", UIKit.box(
		UIKit.ACCENT_100 if is_top3 else UIKit.SURFACE, UIKit.DIVIDER, 1, 10))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)
	var medal := ["🥇", "🥈", "🥉"]
	var rank_lbl := UIKit.label(medal[rank - 1] if is_top3 else "#%d" % rank, 16, UIKit.INK, 800)
	rank_lbl.custom_minimum_size = Vector2(36, 0)
	h.add_child(rank_lbl)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 1)
	v.add_child(UIKit.label(String(e.get("kebun_name", "?")), 13, UIKit.INK, 800))
	v.add_child(UIKit.meta("Hari ke-%d" % int(e.get("day", 0)), 10))
	h.add_child(v)
	var profit := int(e.get("profit", 0))
	h.add_child(UIKit.label("Rp%s" % GameState._fmt(profit), 13, UIKit.ACCENT_700 if profit >= 0 else UIKit.N600, 800))
	return card
