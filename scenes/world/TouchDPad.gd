extends Control
## D-pad sentuh 4 arah (atas/bawah/kiri/kanan) — pengganti VirtualJoystick.
##
## Kenapa bukan joystick: VirtualJoystick mengandalkan _gui_input + area
## floating 80% tengah layar, dan di sebagian HP Android sentuhannya tidak
## pernah sampai (lihat Catatan Perbaikan). Button punya penanganan sentuh
## bawaan Godot yang jauh lebih andal, jadi tiap panah di sini adalah Button
## sungguhan dengan sinyal button_down/button_up.
##
## Interface-nya sengaja dibuat sama seperti VirtualJoystick (`output: Vector2`
## + signal `moved`) supaya pemanggil lama tidak perlu berubah banyak:
##   x = kanan+, y = bawah+ (atas = maju/-Z)

signal moved(v: Vector2)

const BTN := 64        # sisi satu tombol panah (px)
const GAP := 6         # jarak antar tombol
const GLYPH := 26      # ukuran font glyph panah

var output: Vector2 = Vector2.ZERO

var _held := {"up": false, "down": false, "left": false, "right": false}
var _btns: Dictionary = {}

func _ready() -> void:
	# Ukuran cross: 3 kolom tombol + 2 gap
	var side := BTN * 3 + GAP * 2
	custom_minimum_size = Vector2(side, side)
	size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # hanya tombolnya yang menangkap sentuhan

	# Posisi cross: baris/kolom dalam grid 3x3
	_add_arrow("up",    "▲", 1, 0, side)
	_add_arrow("left",  "◀", 0, 1, side)
	_add_arrow("right", "▶", 2, 1, side)
	_add_arrow("down",  "▼", 1, 2, side)

func _add_arrow(dir: String, glyph: String, col: int, row: int, _side: int) -> void:
	var b := Button.new()
	b.text = glyph
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.custom_minimum_size = Vector2(BTN, BTN)
	b.size = Vector2(BTN, BTN)
	b.position = Vector2(col * (BTN + GAP), row * (BTN + GAP))
	b.add_theme_font_size_override("font_size", GLYPH)
	b.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	b.add_theme_stylebox_override("normal", _style(Color(0.06, 0.09, 0.07, 0.72)))
	b.add_theme_stylebox_override("hover", _style(Color(0.06, 0.09, 0.07, 0.72)))
	b.add_theme_stylebox_override("pressed", _style(Color(0.16, 0.42, 0.22, 0.95)))
	b.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0)))

	# button_down/up lebih tepat daripada `pressed` (yang hanya memicu saat
	# lepas) karena gerak harus berjalan selama tombol DITAHAN.
	b.button_down.connect(func(): _set_dir(dir, true))
	b.button_up.connect(func(): _set_dir(dir, false))

	_btns[dir] = b
	add_child(b)

func _style(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(12)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(1, 1, 1, 0.22)
	return sb

func _set_dir(dir: String, down: bool) -> void:
	_held[dir] = down
	_recalc()

func _recalc() -> void:
	var v := Vector2.ZERO
	if _held["left"]:  v.x -= 1.0
	if _held["right"]: v.x += 1.0
	if _held["up"]:    v.y -= 1.0
	if _held["down"]:  v.y += 1.0
	# Diagonal jangan lebih cepat dari lurus
	output = v.limit_length(1.0)
	emit_signal("moved", output)

## Tempelkan D-pad ke sudut kiri-bawah layar dengan margin tertentu.
## WAJIB dipanggil SETELAH add_child(): _ready() menetapkan size dulu, jadi
## anchor yang diset sebelum add_child akan ditimpa.
func anchor_bottom_left(margin_x: int = 18, margin_y: int = 24) -> void:
	var side := BTN * 3 + GAP * 2
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = margin_x
	offset_right = margin_x + side
	offset_top = -(side + margin_y)
	offset_bottom = -margin_y

## Lepaskan semua arah — dipakai saat layar kehilangan fokus / D-pad
## disembunyikan, supaya pemain tidak "nyangkut" jalan terus.
func release_all() -> void:
	for d in _held.keys():
		_held[d] = false
		if _btns.has(d):
			(_btns[d] as Button).button_pressed = false
	_recalc()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		release_all()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		release_all()
