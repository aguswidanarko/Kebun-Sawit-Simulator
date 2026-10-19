extends Control
## Latar foto kebun sawit (statis, ringan) di BELAKANG UI. Dipilih acak tiap buka
## dari beberapa foto. Semua foto: Pexels (bebas komersial, tanpa atribusi wajib) —
## lihat CREDITS.md. Pakai: tambahkan instance ini sebagai anak PERTAMA sebuah Control.

const BGS := [
	"res://assets/bg/plantation.jpg",
	"res://assets/bg/plantation2.jpg",
	"res://assets/bg/plantation3.jpg",
	"res://assets/bg/plantation4.jpg",
]

func _ready() -> void:
	randomize()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var avail := BGS.filter(func(p): return ResourceLoader.exists(p))
	var path: String = avail[randi() % avail.size()] if not avail.is_empty() else BGS[0]

	var tr := TextureRect.new()
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists(path):
		tr.texture = load(path)
	add_child(tr)

	# Lapisan gelap agar teks UI tetap terbaca di atas foto.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
