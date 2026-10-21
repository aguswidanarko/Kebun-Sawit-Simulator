extends Control
## Splash pembuka statis — video dihapus (MP4 tidak reliable di semua perangkat Android).
## Tampilkan logo + nama game 1.5 detik, lalu masuk ke MainMenu.
## Tap / klik kapan saja untuk skip.

const NEXT             := "res://scenes/MainMenu.tscn"
const SPLASH_DURATION  := 1.5

var _gone := false

func _ready() -> void:
	# Headless (CI / build) → langsung skip ke menu
	if DisplayServer.get_name() == "headless":
		call_deferred("_go"); return

	# Background hijau tua (warna brand)
	var bg := ColorRect.new()
	bg.color = Color.html("1a5c30")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Ikon sawit (icon_source_1024x1024.png) di tengah
	var icon_path := "res://assets/icons/icon_source_1024x1024.png"
	if ResourceLoader.exists(icon_path):
		var img := TextureRect.new()
		img.texture = load(icon_path)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.set_anchors_preset(Control.PRESET_FULL_RECT)
		img.offset_left = 60; img.offset_right = -60
		img.offset_top = -80; img.offset_bottom = -120
		add_child(img)

	# Nama game
	var title := Label.new()
	title.text = "Kebun Sawit\nSimulator"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	title.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	title.offset_top = -110; title.offset_bottom = -30
	add_child(title)

	# Hint "tap untuk skip" — fade-out setelah 1 detik
	var hint := Label.new()
	hint.text = "Ketuk layar untuk mulai"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -28; hint.offset_bottom = -8
	add_child(hint)

	# Auto-lanjut setelah SPLASH_DURATION detik
	get_tree().create_timer(SPLASH_DURATION).timeout.connect(_go)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_go()
	elif event is InputEventMouseButton and event.pressed:
		_go()
	elif event is InputEventKey and event.pressed and not event.echo:
		_go()

func _go() -> void:
	if _gone: return
	_gone = true
	get_tree().change_scene_to_file(NEXT)
