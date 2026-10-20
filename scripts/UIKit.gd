class_name UIKit
## Token & helper UI dari design handoff "Modernist" (design_handoff_kebun_sawit_mobile).
## Light theme: bg #f3f2f2, ink #201e1d, aksen #ec3013, Archivo, radius 0, border 2px.

const BG := Color("f3f2f2")
const SURFACE := Color("eae9e9")
const INK := Color("201e1d")
const ACCENT := Color("ec3013")
const ACCENT_100 := Color("fff2ef")
const ACCENT_300 := Color("ffc4b8")
const ACCENT_600 := Color("dd2b0f")
const ACCENT_700 := Color("ae1800")
const ACCENT_800 := Color("7c1405")
const N300 := Color("d7d3d3")
const N500 := Color("9b9797")
const N600 := Color("7d7979")
const N700 := Color("605d5d")
const DIVIDER := Color(0.1255, 0.1176, 0.1137, 0.4)
# Warna gap grid (divider di atas bg, sudah di-blend agar sel opaque).
const GRIDLINE := Color(0.60, 0.59, 0.585)

## Ikon pakai nama file Lucide di assets/ui/icons/<nama>.svg (lihat UIKit.icon()).
const TABS := [
	["Kebun", "layout-grid", "res://scenes/DashboardScreen.tscn"],
	["Cuaca", "cloud-sun", "res://scenes/CuacaScreen.tscn"],
	["Panen", "truck", "res://scenes/HarvestScreen.tscn"],
	["Pedagang", "store", "res://scenes/MerchantScreen.tscn"],
	["Sosial", "users", "res://scenes/SosialScreen.tscn"],
	["Laporan", "file-text", "res://scenes/LaporanScreen.tscn"],
]

static var _font: Font
static var _bold: FontVariation
static var _semi: FontVariation
static var _gray_shader: Shader

static func font() -> Font:
	if _font == null:
		_font = load("res://assets/ui/Archivo.ttf")
	return _font

static func bold() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = font()
		_bold.variation_embolden = 0.9
	return _bold

static func semi() -> Font:
	if _semi == null:
		_semi = FontVariation.new()
		_semi.base_font = font()
		_semi.variation_embolden = 0.45
	return _semi

# ---------------------------------------------------------------- teks
static func label(text: String, size := 13, col := INK, weight := 400) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if weight >= 800:
		l.add_theme_font_override("font", bold())
	elif weight >= 600:
		l.add_theme_font_override("font", semi())
	return l

static func kicker(text: String, col := ACCENT_700) -> Label:
	return label(text.to_upper(), 10, col, 600)

static func meta(text: String, size := 11) -> Label:
	return label(text, size, N700)

static func wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

# ---------------------------------------------------------------- stylebox
static func box(bg := BG, border := Color(0, 0, 0, 0), bw := 0, margin := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(0)
	s.set_border_width_all(bw)
	s.border_color = border
	s.set_content_margin_all(margin)
	return s

## Rule horizontal (garis pemisah) 2px divider.
static func rule(h := 2, col := DIVIDER) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.custom_minimum_size = Vector2(0, h)
	return r

static func vrule(w := 2, col := DIVIDER) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.custom_minimum_size = Vector2(w, 0)
	return r

static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

static func margin(l := 16, t := 0, r := 16, b := 0) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	return m

# ---------------------------------------------------------------- tombol
## kind: "primary" (fill aksen) | "secondary" (border divider) | "ghost" | "fill" (fill ink, utk terpilih)
## click_sfx: nama efek SoundManager yg diputar saat ditekan ("" utk bisu — dipakai
## tombol yg sudah punya efek lain sendiri, mis. beli/panen yg bunyi lewat cash_changed).
static func btn(text: String, cb: Callable, kind := "secondary", size := 14, min_h := 44, click_sfx := "click") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_font_override("font", bold())
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	match kind:
		"primary":
			b.add_theme_stylebox_override("normal", box(ACCENT))
			b.add_theme_stylebox_override("hover", box(ACCENT_600))
			b.add_theme_stylebox_override("pressed", box(ACCENT_700))
			b.add_theme_stylebox_override("disabled", box(Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.45)))
			for st in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]:
				b.add_theme_color_override(st, BG)
		"fill":
			b.add_theme_stylebox_override("normal", box(INK))
			b.add_theme_stylebox_override("hover", box(INK))
			b.add_theme_stylebox_override("pressed", box(INK))
			for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				b.add_theme_color_override(st, BG)
		"ghost":
			b.flat = true
			b.add_theme_color_override("font_color", INK)
			b.add_theme_color_override("font_hover_color", ACCENT_700)
		_:
			b.add_theme_stylebox_override("normal", box(BG, DIVIDER, 1))
			b.add_theme_stylebox_override("hover", box(SURFACE, DIVIDER, 1))
			b.add_theme_stylebox_override("pressed", box(N300, DIVIDER, 1))
			b.add_theme_stylebox_override("disabled", box(BG, DIVIDER, 1))
			b.add_theme_color_override("font_color", INK)
			b.add_theme_color_override("font_hover_color", INK)
			b.add_theme_color_override("font_pressed_color", INK)
			b.add_theme_color_override("font_disabled_color", N500)
	b.pressed.connect(func():
		if click_sfx != "":
			SoundManager.play(click_sfx)
		cb.call())
	return b

## Tombol segmented (teks tengah).
static func seg(text: String, selected: bool, cb: Callable) -> Button:
	var b := btn(text, cb, "fill" if selected else "secondary", 13, 44, "toggle")
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b

## Tombol tutup ghost 36×36 dengan ikon "x" (dipakai di header sheet/bottom-sheet).
static func close_btn(cb: Callable) -> Button:
	var b := btn("", cb, "ghost", 14, 36, "close")
	b.custom_minimum_size = Vector2(36, 36)
	var ic := icon("x", 18, INK)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.set_anchors_preset(Control.PRESET_CENTER)
	ic.position = Vector2(-9, -9)
	b.add_child(ic)
	return b

# ---------------------------------------------------------------- komponen kecil
## Tag kecil. kind: "fill" (aksen) | "accent" (outline aksen) | "ink" (outline ink)
static func tag(text: String, kind := "ink") -> Label:
	var l := label(" %s " % text, 10, INK, 800)
	var s: StyleBoxFlat
	match kind:
		"fill":
			s = box(ACCENT, ACCENT, 0, 2)
			l.add_theme_color_override("font_color", BG)
		"accent":
			s = box(Color(0, 0, 0, 0), ACCENT_700, 1, 2)
			l.add_theme_color_override("font_color", ACCENT_700)
		_:
			s = box(Color(0, 0, 0, 0), INK, 1, 2)
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	l.add_theme_stylebox_override("normal", s)
	return l

## Bar progres/kesehatan tipis. Track neutral-300, isi ink (atau aksen bila bermasalah).
static func bar(v: float, col := INK, h := 4) -> Control:
	var bg := ColorRect.new()
	bg.color = N300
	bg.custom_minimum_size = Vector2(0, h)
	var fill := ColorRect.new()
	fill.color = col
	fill.anchor_right = clampf(v, 0.0, 1.0)
	fill.anchor_bottom = 1.0
	bg.add_child(fill)
	return bg

## Foto (object-fit cover). Grayscale by default (design system Modernist); pass grayscale=false untuk foto berwarna penuh.
static func photo(path: String, min_size := Vector2(0, 0), grayscale := true) -> TextureRect:
	var t := TextureRect.new()
	t.custom_minimum_size = min_size
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if path != "" and ResourceLoader.exists(path):
		t.texture = load(path)
	if grayscale:
		if _gray_shader == null:
			_gray_shader = load("res://assets/ui/grayscale.gdshader")
		var m := ShaderMaterial.new()
		m.shader = _gray_shader
		t.material = m
	return t

## Ikon vektor Lucide (assets/ui/icons/<nama>.svg). Stroke SVG dinormalisasi ke putih saat
## didownload supaya bisa di-tint lewat `col` (TextureRect.modulate), sama seperti pola icon-font.
static func icon(name: String, size := 20, col := INK) -> TextureRect:
	var t := TextureRect.new()
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.modulate = col
	var path := "res://assets/ui/icons/%s.svg" % name
	if ResourceLoader.exists(path):
		t.texture = load(path)
	return t

## Scrim gradient ink di atas foto.
static func scrim(a_top := 0.10, a_bot := 0.86) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(INK.r, INK.g, INK.b, a_top))
	g.set_color(1, Color(INK.r, INK.g, INK.b, a_bot))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var t := TextureRect.new()
	t.texture = gt
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	return t

# ---------------------------------------------------------------- pratinjau 3D (ikon barang)
## Thumbnail 3D dari model (.obj -> Mesh, atau .glb/.gltf -> PackedScene).
## UPDATE_WHEN_VISIBLE: hanya render selagi thumbnail ini kelihatan di layar (hemat saat
## discroll/off-screen). CATATAN: tanpa own_world_3d=true, banyak SubViewport yang dibuat di
## frame yang sama diam-diam BERBAGI World3D default — semua kecuali satu akhirnya menampilkan
## render dari kamera/model TERAKHIR yang dibuat, bukan model masing-masing (ketahuan lewat
## screenshot nyata multi-thumbnail, bukan cuma baca kode). own_world_3d=true mengisolasi tiap
## thumbnail ke dunia 3D privat sehingga tidak saling menimpa.
static func model_thumb(path: String, size := Vector2(52, 52)) -> Control:
	var wrap_ctrl := SubViewportContainer.new()
	wrap_ctrl.custom_minimum_size = size
	wrap_ctrl.stretch = true
	wrap_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.size = Vector2i(size) * 2
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	vp.gui_disable_input = true
	wrap_ctrl.add_child(vp)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.9
	we.environment = env
	vp.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.1
	vp.add_child(sun)

	var holder := Node3D.new()
	vp.add_child(holder)
	if path != "" and ResourceLoader.exists(path):
		var res: Resource = load(path)
		var aabb := AABB()
		if res is Mesh:
			var mi := MeshInstance3D.new()
			mi.mesh = res
			holder.add_child(mi)
			aabb = (res as Mesh).get_aabb()
		elif res is PackedScene:
			var inst: Node3D = (res as PackedScene).instantiate()
			holder.add_child(inst)
			aabb = _thumb_aabb(inst)
		var center := aabb.position + aabb.size * 0.5
		var radius: float = aabb.size.length() * 0.5
		if radius <= 0.0001:
			radius = 1.0
		holder.position = -center
		var cam := Camera3D.new()
		cam.fov = 35.0
		vp.add_child(cam)
		cam.current = true
		var dist: float = radius / sin(deg_to_rad(35.0 * 0.5)) * 1.15
		# Near/far relatif ke skala objek, BUKAN default Godot (near=0.05) — model yang dimodelkan
		# di skala milimeter asli (mis. serangga, radius ~0,006) akan berjarak kamera < 0,05 dan
		# ter-clip habis jadi blanko kalau pakai near plane default. Ketahuan cuma lewat render
		# nyata (headless/baca kode sama-sama bersih) saat satu dari banyak thumbnail kosong.
		cam.near = max(0.001, dist - radius * 2.0)
		cam.far = dist + radius * 2.0
		var cam_pos := Vector3(dist * 0.55, dist * 0.42, dist * 0.78)
		cam.look_at_from_position(cam_pos, Vector3.ZERO, Vector3.UP)
	return wrap_ctrl

static func _thumb_aabb(root: Node) -> AABB:
	var aabb := AABB()
	var first := true
	for m in _thumb_meshes(root):
		var a: AABB = _thumb_xform(root, m) * (m as MeshInstance3D).mesh.get_aabb()
		if first:
			aabb = a; first = false
		else:
			aabb = aabb.merge(a)
	return aabb

static func _thumb_meshes(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append(node)
	for c in node.get_children():
		out.append_array(_thumb_meshes(c))
	return out

static func _thumb_xform(root: Node, node: Node3D) -> Transform3D:
	var t := Transform3D()
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t

# ---------------------------------------------------------------- tab bar
## Tab bar bawah 6 kolom (border-top 2px ink, aktif = aksen + bar 3px atas).
static func tabbar(active: String) -> Control:
	var wrap_panel := PanelContainer.new()
	var s := box(BG, INK, 0, 0)
	s.border_width_top = 2
	s.content_margin_bottom = 10
	wrap_panel.add_theme_stylebox_override("panel", s)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	wrap_panel.add_child(h)
	for t in TABS:
		var name_s := String(t[0])
		var route := String(t[2])
		var is_active := name_s == active
		var col := ACCENT if is_active else N600
		var item := VBoxContainer.new()
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.add_theme_constant_override("separation", 2)
		item.mouse_filter = Control.MOUSE_FILTER_STOP
		var topbar := ColorRect.new()
		topbar.color = ACCENT if is_active else Color(0, 0, 0, 0)
		topbar.custom_minimum_size = Vector2(0, 3)
		item.add_child(topbar)
		var ic := icon(String(t[1]), 18, col)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		item.add_child(ic)
		var nm := label(name_s, 10, col, 600)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.add_child(nm)
		if not is_active:
			item.gui_input.connect(func(ev):
				if ev is InputEventMouseButton and ev.pressed and ResourceLoader.exists(route):
					item.get_tree().change_scene_to_file(route))
		h.add_child(item)
	return wrap_panel

# ---------------------------------------------------------------- toast
static func toast(host: Node, txt: String) -> void:
	SoundManager.notify()
	var layer := CanvasLayer.new()
	layer.layer = 90
	host.add_child(layer)
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	p.offset_top = -140
	p.offset_left = 16
	p.offset_right = -16
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var s := box(INK, ACCENT, 0, 12)
	s.border_width_left = 4
	p.add_theme_stylebox_override("panel", s)
	var l := label(txt, 13, BG)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(l)
	layer.add_child(p)
	host.get_tree().create_timer(2.6).timeout.connect(func(): layer.queue_free())

# ---------------------------------------------------------------- format
## Rp ringkas gaya design: 84.300.000 -> "Rp84,3 jt"; 1.200.000.000 -> "Rp1,2 M".
static func rp_short(n: int) -> String:
	var neg := "-" if n < 0 else ""
	var a: float = abs(n)
	if a >= 1e9:
		return "%sRp%s M" % [neg, _dec(a / 1e9)]
	if a >= 1e6:
		return "%sRp%s jt" % [neg, _dec(a / 1e6)]
	if a >= 1e3:
		return "%sRp%d rb" % [neg, int(round(a / 1e3))]
	return "%sRp%d" % [neg, int(a)]

static func _dec(v: float) -> String:
	return ("%.1f" % v).replace(".", ",")

## Nama ikon Lucide (assets/ui/icons/<nama>.svg) untuk kondisi cuaca.
static func weather_icon(w: String) -> String:
	match w:
		"hujan": return "cloud-rain"
		"mendung": return "cloud"
		_: return "sun"

## Layar standar: bg terang + kolom [scroll konten, tab bar]. Return VBox konten.
static func screen_root(host: Control, tab: String) -> VBoxContainer:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(bg)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	host.add_child(col)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 0)
	scroll.add_child(content)
	if tab != "":
		col.add_child(tabbar(tab))
	return content
