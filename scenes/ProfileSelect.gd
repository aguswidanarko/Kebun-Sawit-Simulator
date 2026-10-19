extends Control
## Layar pemilihan pemain bergaya "hero select": kartu portrait, deskripsi,
## efek glow saat hover/terpilih, tombol pilih di bawah. (Gratis, tak terkunci bayar.)

var selected_id: String = ""
var cards: Dictionary = {}          # id -> PanelContainer
var detail_label: RichTextLabel
var pick_button: Button

func _ready() -> void:
	_build_ui()
	if not Database.profiles.is_empty():
		_select(String(Database.profiles[0].get("id")))
	if OS.get_cmdline_user_args().has("shotprofile"):
		call_deferred("_capture")

func _capture() -> void:
	# tampilkan efek hover di kartu kedua utk screenshot
	if cards.has("anak_pengusaha"):
		_style_card(cards["anak_pengusaha"], "hover")
	await get_tree().create_timer(1.2).timeout
	get_viewport().get_texture().get_image().save_png("user://profile.png")
	print("[profile] screenshot saved")
	get_tree().quit()

func _build_ui() -> void:
	add_child(load("res://scenes/ui/KebunBackground.tscn").instantiate())

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 8; panel.offset_top = 8; panel.offset_right = -8; panel.offset_bottom = -8
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.09, 0.07, 0.72)
	sb.set_corner_radius_all(14); sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var title := Label.new()
	title.text = "PILIH PEMAIN"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.95, 0.93))   # panel gelap, tema global bertinta gelap
	root.add_child(title)
	var hint := Label.new()
	hint.text = "Modal awal sama (Rp%s). Yang berbeda: cerita & satu keunggulan kecil." % GameState._fmt(int(Database.params.get("base_capital_rp", 100000000)))
	hint.add_theme_font_size_override("font_size", 11)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_color_override("font_color", Color(0.80, 0.83, 0.80))
	root.add_child(hint)

	# Baris kartu hero
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(row)
	for p in Database.profiles:
		if not p.has("id"):
			continue
		var card := _make_card(p)
		cards[String(p.get("id"))] = card
		row.add_child(card)

	# Panel deskripsi pemain terpilih
	var detail_panel := PanelContainer.new()
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(0, 0, 0, 0.30); dsb.set_corner_radius_all(10); dsb.set_content_margin_all(10)
	detail_panel.add_theme_stylebox_override("panel", dsb)
	root.add_child(detail_panel)
	detail_label = RichTextLabel.new()
	detail_label.bbcode_enabled = true
	detail_label.fit_content = false          # tinggi tetap, scroll di dalam (muat di frame 390x844)
	detail_label.scroll_active = true
	detail_label.custom_minimum_size = Vector2(0, 190)
	detail_panel.add_child(detail_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)

	# Tombol pilih (besar, di bawah)
	pick_button = Button.new()
	pick_button.custom_minimum_size = Vector2(0, 56)
	pick_button.add_theme_font_size_override("font_size", 20)
	pick_button.pressed.connect(func(): if selected_id != "": _choose(selected_id))
	root.add_child(pick_button)

	var back := Button.new()
	back.text = "← Kembali ke Menu"
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	root.add_child(back)

# ---------------------------------------------------------------- Kartu
func _make_card(p: Dictionary) -> PanelContainer:
	var id := String(p.get("id"))
	var accent := Color.html(String(p.get("accent_hex", "4caf50")))
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.set_meta("accent", accent)
	_style_card(card, "normal")

	var portrait_path := String(p.get("portrait", ""))
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		# Kartu = gambar utuh (nama & role sudah tercetak di gambar).
		card.custom_minimum_size = Vector2(0, 300)
		var tex := TextureRect.new()
		tex.texture = load(portrait_path)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tex.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tex.clip_contents = true
		card.add_child(tex)
	else:
		card.custom_minimum_size = Vector2(0, 250)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		card.add_child(v)
		v.add_child(_portrait(p, accent))
		var name := Label.new()
		name.text = String(p.get("short_name", p.get("name", "?")))
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.add_theme_font_size_override("font_size", 17)
		name.add_theme_color_override("font_color", Color(0.95, 0.95, 0.93))
		v.add_child(name)
		var tag := Label.new()
		tag.text = String(p.get("role_tag", ""))
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.autowrap_mode = TextServer.AUTOWRAP_WORD
		tag.add_theme_font_size_override("font_size", 10)
		tag.add_theme_color_override("font_color", accent.lightened(0.2))
		v.add_child(tag)

	card.mouse_entered.connect(func(): if selected_id != id: _style_card(card, "hover"))
	card.mouse_exited.connect(func(): if selected_id != id: _style_card(card, "normal"))
	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_select(id))
	return card

func _portrait(p: Dictionary, accent: Color) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 150)

	# Gradien gelap -> aksen (nuansa hero). Ganti dgn gambar asli lewat field "portrait".
	var tr := TextureRect.new()
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	var portrait_path := String(p.get("portrait", ""))
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		tr.texture = load(portrait_path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	else:
		var grad := Gradient.new()
		grad.set_color(0, Color(0.08, 0.10, 0.09))
		grad.set_color(1, accent.darkened(0.15))
		var gt := GradientTexture2D.new()
		gt.gradient = grad; gt.width = 128; gt.height = 160
		gt.fill_from = Vector2(0, 0); gt.fill_to = Vector2(0, 1)
		tr.texture = gt
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
	holder.add_child(tr)

	# Ikon besar di tengah (placeholder sampai ada portrait asli)
	if portrait_path == "":
		var cc := CenterContainer.new()
		cc.set_anchors_preset(Control.PRESET_FULL_RECT)
		var emoji := Label.new()
		emoji.text = String(p.get("emoji", "🧑"))
		emoji.add_theme_font_size_override("font_size", 72)
		cc.add_child(emoji)
		holder.add_child(cc)

	# Badge rarity (pojok kiri atas)
	var rar := Label.new()
	rar.text = String(p.get("rarity", "SR"))
	rar.position = Vector2(6, 4)
	rar.add_theme_font_size_override("font_size", 16)
	rar.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	holder.add_child(rar)
	return holder

func _style_card(card: PanelContainer, state: String) -> void:
	var accent: Color = card.get_meta("accent", Color(0.3, 0.7, 0.3))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.11, 0.09, 0.92)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(8)
	match state:
		"selected":
			sb.set_border_width_all(3); sb.border_color = accent.lightened(0.25)
			sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.75); sb.shadow_size = 20
		"hover":
			sb.set_border_width_all(2); sb.border_color = accent
			sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.45); sb.shadow_size = 10
		_:
			sb.set_border_width_all(1); sb.border_color = Color(1, 1, 1, 0.12)
	card.add_theme_stylebox_override("panel", sb)

# ---------------------------------------------------------------- Pilih
func _select(id: String) -> void:
	selected_id = id
	for cid in cards:
		_style_card(cards[cid], "selected" if cid == id else "normal")
	var p := Database.get_profile(id)
	_update_detail(p)
	pick_button.text = "▶  PILIH %s" % String(p.get("short_name", "PEMAIN")).to_upper()
	var accent := Color.html(String(p.get("accent_hex", "4caf50")))
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = accent.darkened(0.1); bsb.set_corner_radius_all(10)
	pick_button.add_theme_stylebox_override("normal", bsb)
	var bsb2 := StyleBoxFlat.new()
	bsb2.bg_color = accent; bsb2.set_corner_radius_all(10)
	pick_button.add_theme_stylebox_override("hover", bsb2)

func _update_detail(p: Dictionary) -> void:
	var accent := Color.html(String(p.get("accent_hex", "4caf50"))).to_html(false)
	detail_label.text = "[b][color=#%s]%s[/color][/b]\n[i]%s[/i]\n\n[color=#8fd98f]✔ Keunggulan:[/color] %s\n[color=#f0c060]△ Tantangan:[/color] %s\n[color=#90c0f0]📘 Tutorial:[/color] %s" % [
		accent, p.get("name", "?"), p.get("prolog", ""),
		p.get("buff_text", ""), p.get("challenge_text", ""), p.get("tutorial", "")]

func _choose(id: String) -> void:
	GameState.start_new_game(id)
	get_tree().change_scene_to_file("res://scenes/Story.tscn")
