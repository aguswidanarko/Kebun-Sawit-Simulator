extends Control
## Joystick virtual sentuh — FLOATING, area aktif 80% tengah layar.
## Joystick muncul di posisi pertama kali user tap (bukan posisi tetap).
## output (-1..1): x=kanan+, y=bawah+ (drag atas = maju/-Z).

signal moved(v: Vector2)
var output: Vector2 = Vector2.ZERO
var radius: float = 80.0

var _active := false
var _touch_index := -1   # finger ID yang mengontrol joystick ini
var _origin := Vector2.ZERO  # posisi tap awal (pusat joystick sementara)
var _base: Panel
var _knob: Panel

func _ready() -> void:
	# Isi seluruh layar — tapi hanya area 80% tengah yang ditangkap
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Lingkaran base (awalnya tersembunyi)
	_base = _circle(int(radius * 2), Color(1, 1, 1, 0.15))
	_base.pivot_offset = Vector2(radius, radius)
	_base.visible = false
	add_child(_base)

	# Knob
	_knob = _circle(64, Color(1, 1, 1, 0.38))
	_knob.pivot_offset = Vector2(32, 32)
	_knob.visible = false
	add_child(_knob)

func _circle(d: int, col: Color) -> Panel:
	var p := Panel.new()
	p.size = Vector2(d, d)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(d / 2))
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

## Hanya area 80% tengah layar yang aktif — 10% kiri/kanan/atas/bawah bebas
## untuk tombol lain (panen, semprot, dll).
func _in_active_zone(pos: Vector2) -> bool:
	var vp := get_viewport().get_visible_rect().size
	var margin_x := vp.x * 0.10
	var margin_y := vp.y * 0.10
	return (pos.x > margin_x and pos.x < vp.x - margin_x
		and pos.y > margin_y and pos.y < vp.y - margin_y)

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if ev.pressed and not _active and _in_active_zone(ev.position):
			_active = true
			_touch_index = ev.index
			_origin = ev.position
			_show_at(_origin)
			_update(ev.position)
		elif not ev.pressed and ev.index == _touch_index:
			_active = false
			_touch_index = -1
			_hide()
			_reset()
	elif ev is InputEventScreenDrag and _active and ev.index == _touch_index:
		_update(ev.position)
	# Editor: mouse fallback
	elif ev is InputEventMouseButton:
		if ev.pressed and not _active and _in_active_zone(ev.position):
			_active = true
			_origin = ev.position
			_show_at(_origin)
			_update(ev.position)
		elif not ev.pressed and _active:
			_active = false
			_hide()
			_reset()
	elif ev is InputEventMouseMotion and _active:
		_update(ev.position)

func _show_at(pos: Vector2) -> void:
	_base.position = pos - Vector2(radius, radius)
	_base.visible = true
	_knob.visible = true

func _hide() -> void:
	_base.visible = false
	_knob.visible = false

func _update(pos: Vector2) -> void:
	var off := (pos - _origin).limit_length(radius)
	_knob.position = _origin + off - Vector2(32, 32)
	output = off / radius
	emit_signal("moved", output)

func _reset() -> void:
	_origin = Vector2.ZERO
	output = Vector2.ZERO
	emit_signal("moved", output)
