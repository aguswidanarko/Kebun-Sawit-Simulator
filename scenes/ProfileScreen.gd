extends Control
## Profil Pemain — edit Nama User, Nama Kebun, Email, dan foto profil.
## Nama User digunakan di leaderboard/Hall of Fame (beda dari Nama Kebun yang muncul di Dashboard).

var _name_edit: LineEdit
var _kebun_edit: LineEdit
var _email_edit: LineEdit

func _ready() -> void:
	_build()

func _build() -> void:
	var root := VBoxContainer.new()
	root.anchor_right = 1.0; root.anchor_bottom = 1.0
	root.offset_left = 16; root.offset_top = 12; root.offset_right = -16; root.offset_bottom = -12
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	root.add_child(UIKit.label("Profil Pemain", 22, UIKit.INK, 800))
	root.add_child(UIKit.wrap(UIKit.meta("Nama User tampil di Leaderboard. Nama Kebun tampil di Dashboard.")))

	root.add_child(UIKit.rule())

	# ---- Foto profil (placeholder — Play Store rilis nanti) ----
	var photo_row := HBoxContainer.new()
	photo_row.add_theme_constant_override("separation", 16)
	root.add_child(photo_row)

	var ph_frame := PanelContainer.new()
	ph_frame.custom_minimum_size = Vector2(72, 72)
	ph_frame.add_theme_stylebox_override("panel", UIKit.box(UIKit.SURFACE, UIKit.DIVIDER, 2, 0))
	var ph_inner := CenterContainer.new()
	ph_inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	ph_frame.add_child(ph_inner)
	ph_inner.add_child(UIKit.label("👤", 44, UIKit.N500))
	photo_row.add_child(ph_frame)

	var ph_info := VBoxContainer.new()
	ph_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph_info.add_theme_constant_override("separation", 4)
	ph_info.add_child(UIKit.label("Foto Profil", 14, UIKit.INK, 800))
	ph_info.add_child(UIKit.wrap(UIKit.meta("Fitur unggah foto akan tersedia setelah rilis di Play Store.", 12)))
	photo_row.add_child(ph_info)

	root.add_child(UIKit.rule())

	# ---- Form ----
	_name_edit = _field(root, "Nama User", GameState.user_name,
		"Nama Anda (tampil di Leaderboard)")
	_kebun_edit = _field(root, "Nama Kebun", GameState.kebun_name,
		"Nama kebun Anda (tampil di Dashboard)")
	_email_edit = _field(root, "Email", GameState.user_email, "email@contoh.com")
	_email_edit.keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS

	# karakter yang sedang dipakai (read-only, sebagai referensi)
	var char_row := VBoxContainer.new()
	char_row.add_theme_constant_override("separation", 4)
	root.add_child(char_row)
	var prof := Database.get_profile(GameState.profile_id)
	var prof_name := str(prof.get("name", GameState.profile_id)) if not prof.is_empty() else GameState.profile_id
	char_row.add_child(UIKit.label("KARAKTER TERPILIH", 10, UIKit.N700, 600))
	char_row.add_child(UIKit.label(prof_name, 14, UIKit.INK))

	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(sp)

	var save_btn := UIKit.btn("Simpan Profil", _save, "primary", 16, 52)
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(save_btn)
	root.add_child(UIKit.btn("← Kembali ke Kebun",
		func(): get_tree().change_scene_to_file("res://scenes/DashboardScreen.tscn")))

func _field(parent: VBoxContainer, lbl_text: String, value: String, placeholder: String) -> LineEdit:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	parent.add_child(v)
	v.add_child(UIKit.label(lbl_text.to_upper(), 10, UIKit.N700, 600))
	var edit := LineEdit.new()
	edit.text = value
	edit.placeholder_text = placeholder
	edit.custom_minimum_size = Vector2(0, 44)
	edit.add_theme_font_size_override("font_size", 15)
	edit.add_theme_stylebox_override("normal", UIKit.box(UIKit.SURFACE, UIKit.DIVIDER, 1, 10))
	edit.add_theme_stylebox_override("focus",  UIKit.box(UIKit.SURFACE, UIKit.INK,    2, 10))
	edit.add_theme_color_override("font_color", UIKit.INK)
	edit.add_theme_color_override("font_placeholder_color", UIKit.N500)
	v.add_child(edit)
	return edit

func _save() -> void:
	var new_name  := _name_edit.text.strip_edges()
	var new_kebun := _kebun_edit.text.strip_edges()
	var new_email := _email_edit.text.strip_edges()
	if new_kebun == "":
		UIKit.toast(self, "Nama Kebun tidak boleh kosong.")
		return
	GameState.user_name  = new_name
	GameState.kebun_name = new_kebun
	GameState.user_email = new_email
	GameState.save_game()
	UIKit.toast(self, "Profil disimpan.")
