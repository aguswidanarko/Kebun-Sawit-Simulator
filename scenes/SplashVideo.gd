extends Control
## Video pembuka: putar trailer.mp4 portrait, lalu masuk ke MainMenu.
## FORMAT: Godot 4 native mendukung .ogv (Theora). Untuk MP4 di Android, Godot
## menggunakan hardware decoder perangkat — pastikan file sudah ter-import di editor.
## Tap / klik kapan saja untuk skip.

const NEXT  := "res://scenes/MainMenu.tscn"
const VIDEO := "res://assets/video/trailer.mp4"

## Fallback: jika video gagal dimuat, tampilkan splash statis selama ini (detik).
const FALLBACK_DURATION := 3.0

var _gone := false
var _vp: VideoStreamPlayer

func _ready() -> void:
	# Headless (CI / build) → langsung skip ke menu
	if DisplayServer.get_name() == "headless":
		call_deferred("_go"); return

	# Background hitam
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Logo sederhana di tengah (ditampilkan selama video dimuat / fallback)
	var logo := Label.new()
	logo.text = "Kebun Sawit\nSimulator"
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	logo.set_anchors_preset(Control.PRESET_FULL_RECT)
	logo.add_theme_font_size_override("font_size", 32)
	logo.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	add_child(logo)

	# Coba muat video
	_vp = VideoStreamPlayer.new()
	_vp.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vp.expand = true
	_vp.autoplay = false
	_vp.finished.connect(_go)
	add_child(_vp)

	# Muat stream satu frame kemudian agar node sudah di scene tree
	call_deferred("_start_video")

	# Hint "tap untuk skip"
	var hint := Label.new()
	hint.text = "Tap untuk skip"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_bottom = -24; hint.offset_top = -52
	add_child(hint)
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(hint, "modulate:a", 0.0, 1.0)

func _start_video() -> void:
	if ResourceLoader.exists(VIDEO):
		var stream = ResourceLoader.load(VIDEO, "", ResourceLoader.CACHE_MODE_IGNORE)
		if stream != null:
			_vp.stream = stream
			_vp.play()
			return
	# Video tidak bisa dimuat → fallback splash statis
	push_warning("SplashVideo: gagal muat %s — fallback splash %ds." % [VIDEO, FALLBACK_DURATION])
	get_tree().create_timer(FALLBACK_DURATION).timeout.connect(_go)

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
	if _vp and _vp.is_playing():
		_vp.stop()
	get_tree().change_scene_to_file(NEXT)
