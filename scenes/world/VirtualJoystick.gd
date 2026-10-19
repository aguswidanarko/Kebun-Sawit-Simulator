extends Control
## Joystick virtual sentuh. output (-1..1): x=kanan+, y=bawah+ (drag atas = maju/-Z).

signal moved(v: Vector2)
var output: Vector2 = Vector2.ZERO
var radius: float = 80.0
var _active := false
var _center := Vector2(100, 100)
var _knob: Panel

func _ready() -> void:
	custom_minimum_size = Vector2(200, 200)
	size = Vector2(200, 200)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var base := _circle(160, Color(1, 1, 1, 0.12))
	base.position = Vector2(20, 20)
	add_child(base)
	_knob = _circle(70, Color(1, 1, 1, 0.32))
	_knob.position = _center - Vector2(35, 35)
	add_child(_knob)

func _circle(d: int, col: Color) -> Panel:
	var p := Panel.new()
	p.size = Vector2(d, d)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(d / 2))
	p.add_theme_stylebox_override("panel", sb)
	return p

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton or ev is InputEventScreenTouch:
		if ev.pressed:
			_active = true
			_update(ev.position)
		else:
			_active = false
			_reset()
	elif (ev is InputEventMouseMotion or ev is InputEventScreenDrag) and _active:
		_update(ev.position)

func _update(pos: Vector2) -> void:
	var off := (pos - _center).limit_length(radius)
	_knob.position = _center + off - Vector2(35, 35)
	output = off / radius
	emit_signal("moved", output)

func _reset() -> void:
	_knob.position = _center - Vector2(35, 35)
	output = Vector2.ZERO
	emit_signal("moved", output)
