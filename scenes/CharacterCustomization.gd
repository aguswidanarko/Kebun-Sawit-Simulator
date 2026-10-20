extends Control
## Kustomisasi Karakter — pilih kostum, emote, dan aksesori visual.

var selected_category: String = "kostum"
var list: VBoxContainer
var detail_panel: PanelContainer

func _ready() -> void:
	_rebuild()
	GameState.cosmetics_changed.connect(func(): _refresh())
	GameState.cash_changed.connect(func(_c): _refresh())

## Hapus seluruh tree dan bangun ulang (dipakai juga saat ganti tab kategori).
func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	detail_panel = null
	list = null

	# Background + scroll via screen_root
	var content := UIKit.screen_root(self, "")

	# Header
	var hm := UIKit.margin(16, 12, 16, 0)
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 12)
	var title := UIKit.label("Kustomisasi Karakter", 22, UIKit.INK, 800)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(title)
	hrow.add_child(UIKit.close_btn(func():
		get_tree().change_scene_to_file("res://scenes/DashboardScreen.tscn")))
	hm.add_child(hrow)
	content.add_child(hm)

	var sm := UIKit.margin(16, 2, 16, 8)
	sm.add_child(UIKit.wrap(UIKit.meta(
		"Ubah penampilan pemain Anda — kostum & emote. Murni visual, tidak memengaruhi gameplay.", 12)))
	content.add_child(sm)

	content.add_child(UIKit.rule())

	# Tab kategori dengan style underline aktif
	var tabm := UIKit.margin(16, 8, 16, 0)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 0)
	for entry in [["kostum", "Kostum"], ["emote", "Emote"]]:
		var cid: String = entry[0]
		var clabel: String = entry[1]
		var active := (selected_category == cid)
		var b := Button.new()
		b.text = clabel
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_font_override("font", UIKit.bold() if active else UIKit.semi())
		b.add_theme_color_override("font_color", UIKit.INK if active else UIKit.N600)
		b.add_theme_color_override("font_hover_color", UIKit.INK)
		var tsb := UIKit.box(Color(0, 0, 0, 0), UIKit.ACCENT if active else UIKit.DIVIDER, 0, 8)
		tsb.border_width_bottom = 3 if active else 1
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, tsb)
		b.pressed.connect(func():
			selected_category = cid
			_rebuild())
		tabs.add_child(b)
	tabm.add_child(tabs)
	content.add_child(tabm)

	# Panel "dipakai sekarang"
	detail_panel = PanelContainer.new()
	detail_panel.add_theme_stylebox_override("panel", UIKit.box(UIKit.SURFACE, UIKit.DIVIDER, 1, 10))
	var dm := UIKit.margin(16, 10, 16, 0)
	dm.add_child(detail_panel)
	content.add_child(dm)

	# List item kosmetik
	var lm := UIKit.margin(16, 8, 16, 16)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	lm.add_child(list)
	content.add_child(lm)

	_refresh()

func _refresh() -> void:
	if detail_panel == null or list == null:
		return
	for c in detail_panel.get_children():
		c.queue_free()
	for c in list.get_children():
		c.queue_free()

	# Panel detail
	var current_id: String = GameState.cosmetics_applied.get(selected_category, "")
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 4)
	detail_panel.add_child(dv)
	dv.add_child(UIKit.kicker("Dipakai Sekarang"))
	if current_id != "":
		var ci := Database.get_cosmetic(current_id)
		dv.add_child(UIKit.label(String(ci.get("name", "?")), 14, UIKit.INK, 800))
	else:
		dv.add_child(UIKit.meta("(bawaan)", 11))

	# List item
	var items := Database.cosmetics_by_category(selected_category)
	if items.is_empty():
		list.add_child(UIKit.meta("Belum ada item untuk kategori ini."))
		return
	for item in items:
		list.add_child(_item_card(item))

func _item_card(item: Dictionary) -> PanelContainer:
	var id := String(item.get("id"))
	var iname := String(item.get("name", "?"))
	var price := int(item.get("price_rp", 0))
	var tier := String(item.get("tier", "biasa"))
	var owned := GameState.is_owned(id)
	var applied: bool = (GameState.cosmetics_applied.get(selected_category, "") == id)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel",
		UIKit.box(UIKit.ACCENT_100 if applied else UIKit.BG, UIKit.DIVIDER, 1, 10))

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	v.add_child(UIKit.label(iname, 14, UIKit.INK, 800))

	var tier_labels: Dictionary = {"biasa": "Biasa", "premium": "Premium", "eksklusif": "✨ Eksklusif"}
	var tier_txt: String = tier_labels.get(tier, tier)
	var price_txt := "GRATIS" if price == 0 else ("Rp%s" % GameState._fmt(price))
	v.add_child(UIKit.meta("%s · %s" % [tier_txt, price_txt], 11))

	if applied:
		h.add_child(UIKit.label("✓ Dipakai", 12, UIKit.N700, 600))
	elif owned:
		h.add_child(UIKit.btn("Pakai", func(): GameState.apply_cosmetic(id)))
	else:
		h.add_child(UIKit.btn("Beli", func():
			if not GameState.buy_cosmetic(id):
				UIKit.toast(self, "Dana tidak cukup.")))

	return card
