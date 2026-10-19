extends Control
## Pedagang (design 4a) — pusat jual beli, light Modernist, tab "Pedagang".

var _mode := "beli"
var _cat := "semua"
var _list: VBoxContainer
var _chips: HBoxContainer
var _seg: HBoxContainer
var _info: Label

func _ready() -> void:
	_build()
	GameState.cash_changed.connect(func(_c): _refresh_info())
	if OS.get_cmdline_user_args().has("shotmerchant"):
		call_deferred("_capture")

func _capture() -> void:
	await get_tree().create_timer(0.7).timeout
	get_viewport().get_texture().get_image().save_png("user://merchant.png")
	print("[merchant] screenshot saved")
	get_tree().quit()

func _build() -> void:
	var content := UIKit.screen_root(self, "Pedagang")
	var m := UIKit.margin(16, 16, 16, 16)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	m.add_child(root)
	content.add_child(m)

	# header: potret pedagang placeholder + judul
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 12)
	var por := PanelContainer.new()
	por.custom_minimum_size = Vector2(56, 68)
	por.add_theme_stylebox_override("panel", UIKit.box(UIKit.SURFACE, UIKit.INK, 2, 0))
	var pl := UIKit.icon("user", 26, UIKit.INK)
	pl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	por.add_child(pl)
	hr.add_child(por)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_theme_constant_override("separation", 2)
	hv.add_child(UIKit.kicker("Pedagang · Koh Ahong"))
	hv.add_child(UIKit.label("Pusat Jual Beli", 22, UIKit.INK, 800))
	_info = UIKit.meta("")
	hv.add_child(_info)
	hr.add_child(hv)
	root.add_child(hr)
	root.add_child(UIKit.rule())

	_seg = HBoxContainer.new()
	_seg.add_theme_constant_override("separation", 8)
	root.add_child(_seg)

	var chip_scroll := ScrollContainer.new()
	chip_scroll.custom_minimum_size = Vector2(0, 44)
	chip_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(chip_scroll)
	_chips = HBoxContainer.new()
	_chips.add_theme_constant_override("separation", 6)
	chip_scroll.add_child(_chips)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 0)
	root.add_child(_list)

	_set_mode(_mode)

func _count(cat_id: String, src: Array) -> int:
	var n := 0
	for it in src:
		if it.has("id") and (cat_id == "semua" or it.get("cat") == cat_id):
			n += 1
	return n

func _build_chips() -> void:
	for c in _chips.get_children():
		c.queue_free()
	var src: Array = Database.merchant_stock if _mode == "beli" else GameState.inv
	for cat in Database.merchant_categories.get("categories", []):
		var cid := String(cat.get("id"))
		var n := _count(cid, src)
		var b := UIKit.btn("%s · %d" % [cat.get("label"), n], func():
			_cat = cid
			_build_chips()
			_rebuild(), "fill" if _cat == cid else "secondary", 11, 32)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_chips.add_child(b)

func _set_mode(m: String) -> void:
	_mode = m
	for c in _seg.get_children():
		c.queue_free()
	_seg.add_child(UIKit.seg("Jual ke pedagang", m == "jual", func(): _set_mode("jual")))
	_seg.add_child(UIKit.seg("Beli dari pedagang", m == "beli", func(): _set_mode("beli")))
	_build_chips()
	_refresh_info()
	_rebuild()

func _refresh_info() -> void:
	if _info:
		_info.text = "Saldo %s · nilai gudang %s" % [
			UIKit.rp_short(GameState.cash), UIKit.rp_short(GameState.warehouse_value())]

func _rebuild() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		c.queue_free()
	var src: Array = Database.merchant_stock if _mode == "beli" else GameState.inv
	var any := false
	for it in src:
		if not it.has("id"):
			continue
		if _cat != "semua" and it.get("cat") != _cat:
			continue
		_list.add_child(_row(it))
		_list.add_child(UIKit.rule(1))
		any = true
	if not any:
		var e := UIKit.wrap(UIKit.meta("Tidak ada barang di kategori ini.", 13))
		_list.add_child(e)

func _row(it: Dictionary) -> Control:
	var id := String(it.get("id"))
	var m := UIKit.margin(0, 10, 0, 10)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	m.add_child(h)

	# ilustrasi 52x52 — pratinjau 3D kalau barang punya "model", fallback label kategori
	var ill := PanelContainer.new()
	ill.custom_minimum_size = Vector2(52, 52)
	ill.add_theme_stylebox_override("panel", UIKit.box(UIKit.SURFACE, UIKit.DIVIDER, 1, 0))
	var model_path := String(it.get("model", ""))
	if model_path != "" and ResourceLoader.exists(model_path):
		ill.add_child(UIKit.model_thumb(model_path, Vector2(52, 52)))
	else:
		var il := UIKit.label(String(it.get("cat", "")).left(3).to_upper(), 9, UIKit.N600, 600)
		il.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		il.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ill.add_child(il)
	h.add_child(ill)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	v.add_child(UIKit.label(String(it.get("name", "?")), 14, UIKit.INK, 800))
	if _mode == "jual":
		v.add_child(UIKit.meta("stok %d %s · %s" % [int(it.get("qty", 0)), it.get("unit", ""), it.get("note", "")]))
	else:
		v.add_child(UIKit.wrap(UIKit.meta(String(it.get("note", "")))))
	var act := HBoxContainer.new()
	act.add_theme_constant_override("separation", 6)
	if _mode == "beli":
		act.add_child(UIKit.btn("Beli ×1", func(): _toast(GameState.buy_item(id, 1)), "primary", 11, 30))
		act.add_child(UIKit.btn("×10", func(): _toast(GameState.buy_item(id, 10)), "secondary", 11, 30))
	else:
		act.add_child(UIKit.btn("Jual ×1", func(): _toast(GameState.sell_item(id, 1)), "primary", 11, 30))
		act.add_child(UIKit.btn("×10", func(): _toast(GameState.sell_item(id, 10)), "secondary", 11, 30))
	v.add_child(act)
	h.add_child(v)

	# harga + tren (turun = accent-700)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 2)
	var base := int(it.get("price", 0))
	var unit := GameState.price_today(base, id)
	var tr := GameState.market_trend(id)
	var price_l := UIKit.label("Rp%s" % GameState._fmt(unit), 14, UIKit.INK, 800)
	price_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pv.add_child(price_l)
	var unit_l := UIKit.meta("/%s" % it.get("unit", "unit"))
	unit_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pv.add_child(unit_l)
	var arrow := UIKit.label("%s %.0f%%" % ["▲" if tr >= 0 else "▼", abs(tr) * 100], 11,
		UIKit.INK if tr >= 0 else UIKit.ACCENT_700, 600)
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pv.add_child(arrow)
	h.add_child(pv)
	return m

func _toast(txt: String) -> void:
	GameState.log_msg(txt)
	UIKit.toast(self, txt)
	_refresh_info()
	_rebuild()
