extends Control
## Video pembuka: putar trailer.mp4 portrait, lalu masuk ke MainMenu.
## Klik / tap kapan saja untuk skip.

const NEXT := "res://scenes/MainMenu.tscn"
const VIDEO := "res://assets/video/trailer.mp4"

var _gone := false

func _ready() -> void:
	# Headless (CI / build) → langsung skip ke menu
	if DisplayServer.get_name() == "headless":
		_go(); return

	# Background hitam agar tak ada flash putih
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vp := VideoStreamPlayer.new()
	if ResourceLoader.exists(VIDEO):
		vp.stream = load(VIDEO)
	vp.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.expand = true
	vp.finished.connect(_go)
	add_child(vp)

	if vp.stream:
		vp.play()
	else:
		# Video belum di-import → langsung ke menu
		_go()

	# Hint "tap untuk skip" muncul 2 detik, lalu fade out
	var hint := Label.new()
	hint.text = "Tap untuk skip"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_bottom = -24
	hint.offset_top = -52
	add_child(hint)

	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(hint, "modulate:a", 0.0, 1.0)

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
