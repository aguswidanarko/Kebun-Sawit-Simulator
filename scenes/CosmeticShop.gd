extends Control
## Fase 6 — Toko Kosmetik. Semua item MURNI VISUAL (no pay-to-win).
## Dibeli dengan uang dalam game; item premium = penanda paket berbayar di produksi.

## Urutan tampil di toko = urutan dictionary ini (bukan Database.cosmetic_categories(),
## supaya kategori "kostumisasi player" utama tampil duluan drpd skin alat yg
## belum punya hook render 3D).
const CAT_ORDER := ["kostum", "identitas", "emote", "kendaraan", "tema_ui",
	"alat_egrek", "alat_sprayer", "alat_angkong"]
const CAT_LABEL := {
	"tema_ui": "Tema UI", "identitas": "Identitas Kebun",
	"kostum": "Kostum", "kendaraan": "Kendaraan (skin)", "emote": "Emote",
	"alat_egrek": "Skin Egrek", "alat_sprayer": "Skin Sprayer", "alat_angkong": "Skin Angkong"
}
const TIER_LABEL := { "biasa": "Biasa", "premium": "Premium", "eksklusif": "✨ Eksklusif" }

var list: VBoxContainer
var saldo_label: Label
var name_edit: LineEdit

func _ready() -> void:
	_build()
	GameState.cosmetics_changed.connect(_refresh)
	GameState.cash_changed.connect(func(_c): _refresh())
	if OS.get_cmdline_user_args().has("shotshop"):
		call_deferred("_capture")

func _capture() -> void:
	GameState.buy_cosmetic("ui_senja"); GameState.apply_cosmetic("ui_senja")
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png("user://shop.png")
	print("[shop] screenshot saved")
	get_tree().quit()

func _build() -> void:
	var root := VBoxContainer.new()
	root.anchor_right = 1.0; root.anchor_bottom = 1.0
	root.offset_left = 16; root.offset_top = 12; root.offset_right = -16; root.offset_bottom = -12
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var title := UIKit.label("Toko Kosmetik", 22, UIKit.INK, 800)
	root.add_child(title)
	saldo_label = Label.new(); root.add_child(saldo_label)

	var banner := Label.new()
	banner.text = "Semua item hanya mengubah tampilan — TIDAK memberi keunggulan. Profil & progres tetap gratis."
	banner.add_theme_font_size_override("font_size", 12)
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(banner)

	# Nama kebun
	var name_row := HBoxContainer.new()
	var nl := Label.new(); nl.text = "Nama kebun:"; name_row.add_child(nl)
	name_edit = LineEdit.new(); name_edit.text = GameState.kebun_name
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_edit)
	var save_name := Button.new(); save_name.text = "Simpan"
	save_name.pressed.connect(func():
		GameState.kebun_name = name_edit.text.strip_edges()
		GameState.log_msg("Nama kebun: %s" % GameState.display_kebun_name())
		GameState.emit_signal("cosmetics_changed"))
	name_row.add_child(save_name)
	root.add_child(name_row)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	root.add_child(_btn("← Kembali", func(): get_tree().change_scene_to_file("res://scenes/DashboardScreen.tscn")))
	_refresh()

func _refresh() -> void:
	saldo_label.text = "Saldo: Rp%s" % GameState._fmt(GameState.cash)
	for c in list.get_children():
		c.queue_free()
	for cat in CAT_ORDER:
		if Database.cosmetics_by_category(cat).is_empty():
			continue
		var head := Label.new()
		head.text = CAT_LABEL.get(cat, cat)
		head.add_theme_font_size_override("font_size", 16)
		head.add_theme_color_override("font_color", UIKit.ACCENT_700)
		list.add_child(head)
		for item in Database.cosmetics_by_category(cat):
			list.add_child(_item_row(item))

func _item_row(item: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	var id := String(item.get("id"))
	var owned := GameState.is_owned(id)
	var applied: bool = GameState.cosmetics_applied.get(String(item.get("category"))) == id

	var lbl := Label.new()
	var price := int(item.get("price_rp", 0))
	var tag := "GRATIS" if price == 0 else ("Rp%s" % GameState._fmt(price))
	var tier := String(item.get("tier", "standar"))
	if TIER_LABEL.has(tier):
		tag += " ·%s" % TIER_LABEL[tier]
	lbl.text = "%s  (%s)" % [item.get("name"), tag]
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	if applied:
		var ic := UIKit.icon("check", 14, UIKit.N600)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
		var s := Label.new(); s.text = "dipakai"
		s.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		s.add_theme_color_override("font_color", UIKit.N600); row.add_child(s)
	elif owned:
		row.add_child(_btn("Pakai", func(): GameState.apply_cosmetic(id)))
	else:
		row.add_child(_btn("Beli", func(): GameState.buy_cosmetic(id)))
	return row

func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new(); b.text = text; b.pressed.connect(cb)
	return b
