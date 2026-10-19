extends Control
## Menu utama: Lanjutkan (jika ada save) / Permainan Baru.

const GAME := "res://scenes/Main.tscn"
const PROFILE := "res://scenes/ProfileSelect.tscn"

func _ready() -> void:
	# Jalur uji otomatis headless: langsung mulai game & selftest.
	if OS.get_cmdline_user_args().has("selftest"):
		GameState.start_new_game("anak_pengusaha")
		get_tree().call_deferred("change_scene_to_file", GAME)
		return
	if OS.get_cmdline_user_args().has("view3d") or OS.get_cmdline_user_args().has("shot3d"):
		GameState.start_new_game("pekerja_aktif")
		get_tree().call_deferred("change_scene_to_file", "res://scenes/Plantation3D.tscn")
		return
	if OS.get_cmdline_user_args().has("shotpasca") or OS.get_cmdline_user_args().has("pascatest") or OS.get_cmdline_user_args().has("pascaharvest"):
		GameState.start_new_game("pekerja_aktif")
		get_tree().call_deferred("change_scene_to_file", "res://scenes/world/RantaiPascapanen.tscn")
		return
	if OS.get_cmdline_user_args().has("shotshop"):
		GameState.start_new_game("pekerja_aktif")
		get_tree().call_deferred("change_scene_to_file", "res://scenes/CosmeticShop.tscn")
		return
	if OS.get_cmdline_user_args().has("shotmain"):
		GameState.start_new_game("anak_pengusaha")
		get_tree().call_deferred("change_scene_to_file", GAME)
		return
	if OS.get_cmdline_user_args().has("shotprofile"):
		get_tree().call_deferred("change_scene_to_file", PROFILE)
		return
	var a := OS.get_cmdline_user_args()
	if a.has("storytest") or a.has("shotstory") or a.has("shotpreview"):
		GameState.start_new_game("mahasiswa_pertanian")
		get_tree().call_deferred("change_scene_to_file", "res://scenes/Story.tscn")
		return
	if a.has("shotdash"):
		GameState.start_new_game("pekerja_aktif")
		GameState.seed_demo_kebun()
		get_tree().call_deferred("change_scene_to_file", "res://scenes/DashboardScreen.tscn")
		return
	if a.has("shotland"):
		GameState.start_new_game("pekerja_aktif")
		GameState.seed_demo_kebun()
		GameState.buy_target_plot = 5
		get_tree().call_deferred("change_scene_to_file", "res://scenes/LandMarket.tscn")
		return
	if a.has("shotmerchant"):
		GameState.start_new_game("pekerja_aktif")
		get_tree().call_deferred("change_scene_to_file", "res://scenes/MerchantScreen.tscn")
		return
	if a.has("shotharvest"):
		GameState.start_new_game("pekerja_aktif")
		GameState.seed_demo_kebun()
		get_tree().call_deferred("change_scene_to_file", "res://scenes/HarvestScreen.tscn")
		return
	for shot in [["shotcuaca", "res://scenes/CuacaScreen.tscn"], ["shotsosial", "res://scenes/SosialScreen.tscn"], ["shotlaporan", "res://scenes/LaporanScreen.tscn"]]:
		if a.has(String(shot[0])):
			GameState.start_new_game("anak_pengusaha")
			GameState.seed_demo_kebun()
			get_tree().call_deferred("change_scene_to_file", String(shot[1]))
			return
	if a.has("shotnursery"):
		GameState.start_new_game("pekerja_aktif")
		GameState.order_kecambah("marihat_ppks", 500)
		TimeManager.advance_day(35)
		get_tree().call_deferred("change_scene_to_file", "res://scenes/world/NurseryWorld3D.tscn")
		return
	if a.has("shotworld") or a.has("worldtest") or a.has("shotcustom"):
		GameState.start_new_game("pekerja_aktif")
		if a.has("shotcustom"):
			GameState.cosmetics_applied["kostum"] = "kos_pekerja"
			GameState.cosmetics_applied["kendaraan"] = "ken_pikap"
		get_tree().call_deferred("change_scene_to_file", "res://scenes/world/FarmWorld3D.tscn")
		return
	_build_ui()
	if OS.get_cmdline_user_args().has("shotmenu"):
		call_deferred("_capture")

func _capture() -> void:
	await get_tree().create_timer(1.3).timeout
	get_viewport().get_texture().get_image().save_png("user://menu.png")
	print("[menu] screenshot saved")
	get_tree().quit()

func _build_ui() -> void:
	# Latar foto grayscale + scrim (design system Modernist).
	var ph := UIKit.photo("res://assets/bg/plantation.jpg")
	ph.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ph)
	var sc := UIKit.scrim(0.35, 0.9)
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sc)

	var m := UIKit.margin(24, 0, 24, 48)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(m)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.alignment = BoxContainer.ALIGNMENT_END
	m.add_child(box)

	box.add_child(UIKit.kicker("Simulator bisnis kebun", Color(UIKit.BG.r, UIKit.BG.g, UIKit.BG.b, 0.85)))
	var title := UIKit.label("Kebun Sawit\nSimulator", 34, UIKit.BG, 800)
	box.add_child(title)
	var line := ColorRect.new()
	line.color = UIKit.ACCENT
	line.custom_minimum_size = Vector2(56, 4)
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(line)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 18)
	box.add_child(sp)

	if GameState.has_save():
		box.add_child(UIKit.btn("Lanjutkan  ›", _on_continue, "primary", 15, 52))
		box.add_child(_light_btn("Permainan baru", _on_new))
	else:
		box.add_child(UIKit.btn("Permainan baru  ›", _on_new, "primary", 15, 52))
	box.add_child(_light_btn("Dashboard kebun (demo)", func():
		GameState.start_new_game("pekerja_aktif")
		GameState.seed_demo_kebun()
		get_tree().change_scene_to_file("res://scenes/DashboardScreen.tscn")))
	box.add_child(_light_btn("Jelajahi kebun 3D", func(): get_tree().change_scene_to_file("res://scenes/world/FarmWorld3D.tscn")))
	box.add_child(_light_btn("🌴 Siklus Tanaman Kelapa Sawit", func():
		GameState.start_new_game("pekerja_aktif")
		get_tree().change_scene_to_file("res://scenes/world/RantaiPascapanen.tscn")))
	box.add_child(_light_btn("Keluar", func(): get_tree().quit()))

## Tombol secondary varian di atas foto gelap (border & teks terang).
func _light_btn(text: String, cb: Callable) -> Button:
	var b := UIKit.btn(text, cb, "secondary", 14, 48)
	b.add_theme_stylebox_override("normal", UIKit.box(Color(0, 0, 0, 0), Color(0.953, 0.949, 0.949, 0.55), 1))
	b.add_theme_stylebox_override("hover", UIKit.box(Color(1, 1, 1, 0.12), UIKit.BG, 1))
	b.add_theme_stylebox_override("pressed", UIKit.box(Color(1, 1, 1, 0.2), UIKit.BG, 1))
	for st in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(st, UIKit.BG)
	return b

func _on_new() -> void:
	get_tree().change_scene_to_file(PROFILE)

func _on_continue() -> void:
	if GameState.load_game():
		get_tree().change_scene_to_file("res://scenes/DashboardScreen.tscn")
