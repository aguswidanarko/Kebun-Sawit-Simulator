extends Control
## Pasar Lahan (design 1i) — layar push, light Modernist.
## Hutan -> plot "buka" (perlu pembukaan), Bersih -> plot "siap".

const PHOTOS := ["res://assets/bg/plantation2.jpg", "res://assets/bg/plantation3.jpg", "res://assets/bg/plantation4.jpg"]

var _type := "hutan"
var _list: VBoxContainer
var _seg: HBoxContainer

func _ready() -> void:
	_build()
	if OS.get_cmdline_user_args().has("shotland"):
		call_deferred("_capture")

func _capture() -> void:
	await get_tree().create_timer(0.7).timeout
	get_viewport().get_texture().get_image().save_png("user://land.png")
	print("[land] screenshot saved")
	get_tree().quit()

func _build() -> void:
	var content := UIKit.screen_root(self, "")
	var m := UIKit.margin(16, 12, 16, 16)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	m.add_child(root)
	content.add_child(m)

	# header back
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 8)
	hr.add_child(UIKit.btn("‹", func(): get_tree().change_scene_to_file("res://scenes/DashboardScreen.tscn"), "ghost", 20))
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UIKit.kicker("Pasar lahan"))
	hv.add_child(UIKit.label("Beli Lahan", 22, UIKit.INK, 800))
	hr.add_child(hv)
	root.add_child(hr)
	root.add_child(UIKit.meta("Saldo %s · untuk slot %s" % [
		UIKit.rp_short(GameState.cash), GameState.plots[GameState.buy_target_plot].get("id", "B?")], 12))
	root.add_child(UIKit.rule())

	_seg = HBoxContainer.new()
	_seg.add_theme_constant_override("separation", 8)
	root.add_child(_seg)
	var note := UIKit.wrap(UIKit.meta("Hutan: lebih murah, perlu pembukaan (biaya + waktu). Bersih: siap tanam, lebih mahal."))
	root.add_child(note)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 12)
	root.add_child(_list)
	_set_type(_type)

func _set_type(t: String) -> void:
	_type = t
	for c in _seg.get_children():
		c.queue_free()
	_seg.add_child(UIKit.seg("Areal Hutan", t == "hutan", func(): _set_type("hutan")))
	_seg.add_child(UIKit.seg("Areal Bersih", t == "bersih", func(): _set_type("bersih")))
	for c in _list.get_children():
		c.queue_free()
	var i := 0
	for lo in Database.land_offers_by_type(t):
		if lo.has("id"):
			_list.add_child(_card(lo, i))
			i += 1

func _card(lo: Dictionary, idx: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.box(UIKit.BG, UIKit.DIVIDER, 1, 0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	card.add_child(v)

	# foto 150px + tag kelas
	var ph := Control.new()
	ph.custom_minimum_size = Vector2(0, 150)
	ph.clip_contents = true
	var img_path := String(lo.get("image", ""))
	if img_path == "" or not ResourceLoader.exists(img_path):
		img_path = PHOTOS[idx % PHOTOS.size()]
	var img := UIKit.photo(img_path)
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	ph.add_child(img)
	var cls := UIKit.tag("Kelas %s" % lo.get("land_class", "?"), "fill")
	cls.position = Vector2(10, 10)
	ph.add_child(cls)
	v.add_child(ph)

	var body := UIKit.margin(12, 10, 12, 12)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 6)
	body.add_child(bv)
	v.add_child(body)
	bv.add_child(UIKit.label(String(lo.get("name", "?")), 18, UIKit.INK, 800))
	bv.add_child(UIKit.wrap(UIKit.meta(String(lo.get("desc", "")))))
	var price := int(lo.get("price_rp", 0))
	var clearing := int(Database.params.get("clearing_cost_rp", 0)) if bool(lo.get("needs_clearing", false)) else 0
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 8)
	pr.add_child(UIKit.label("Rp%s" % GameState._fmt(price), 20, UIKit.INK, 800))
	if clearing > 0:
		pr.add_child(UIKit.meta("+ pembukaan Rp%s · %d hari" % [
			GameState._fmt(clearing), int(Database.params.get("clearing_days", 30))]))
	bv.add_child(pr)
	var total := price + clearing
	var afford := GameState.cash >= total
	var b := UIKit.btn("Beli lahan ini" if afford else "Saldo tidak cukup",
		func(): _buy(String(lo.get("id"))), "primary" if afford else "secondary")
	b.disabled = not afford
	bv.add_child(b)
	return card

func _buy(offer_id: String) -> void:
	var msg := GameState.buy_land(offer_id, GameState.buy_target_plot)
	GameState.log_msg(msg)
	get_tree().change_scene_to_file("res://scenes/DashboardScreen.tscn")
