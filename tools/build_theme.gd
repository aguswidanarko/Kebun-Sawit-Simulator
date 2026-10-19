extends SceneTree
## Membangun Theme Godot dari token design handoff (Modernist).
## Hasil:
##   assets/ui/modernist_theme.tres  -> theme LENGKAP (light) utk layar baru bergaya design.
##   assets/ui/base_font_theme.tres  -> HANYA font Archivo (dipakai global; warna tak diubah).
## Jalankan: godot --headless -s tools/build_theme.gd

const INK := Color("201e1d")
const BG := Color("f3f2f2")
const SURFACE := Color("eae9e9")
const ACCENT := Color("ec3013")
const NEUTRAL300 := Color("d7d3d3")
const DIVIDER := Color(0.125, 0.118, 0.114, 0.4)

func _initialize() -> void:
	var font: Font = load("res://assets/ui/Archivo.ttf")
	if font == null:
		print("GAGAL load Archivo.ttf"); quit(); return

	# --- Theme hanya-font (global, aman: tidak mengubah warna) ---
	var base := Theme.new()
	base.default_font = font
	base.default_font_size = 14
	ResourceSaver.save(base, "res://assets/ui/base_font_theme.tres")

	# --- Theme modernist lengkap (untuk layar baru) ---
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 14
	# Button flat radius 0
	t.set_stylebox("normal", "Button", _box(SURFACE, DIVIDER, 1))
	t.set_stylebox("hover", "Button", _box(NEUTRAL300, DIVIDER, 1))
	t.set_stylebox("pressed", "Button", _box(INK, INK, 0))
	t.set_stylebox("focus", "Button", _box(SURFACE, ACCENT, 2))
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", BG)
	t.set_color("font_color", "Label", INK)
	t.set_stylebox("panel", "PanelContainer", _box(SURFACE, DIVIDER, 1))
	t.set_stylebox("panel", "Panel", _box(SURFACE, DIVIDER, 1))
	ResourceSaver.save(t, "res://assets/ui/modernist_theme.tres")

	print("[theme] base_font_theme.tres & modernist_theme.tres tersimpan.")
	quit()

func _box(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(0)   # radius 0 (modernist)
	s.set_border_width_all(bw)
	s.border_color = border
	s.content_margin_left = 12; s.content_margin_right = 12
	s.content_margin_top = 8; s.content_margin_bottom = 8
	return s
