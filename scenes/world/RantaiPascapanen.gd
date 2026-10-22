extends Node3D
## "Siklus Tanaman Kelapa Sawit" — jalan-jalan 3D berurutan lewat 10 tahap umur
## nyata: Kecambah -> Pre Nursery (1/2/3 bln, bedengan padat) -> Main Nursery
## (12 bln, bedengan segitiga 0,9 m) -> TB-0 -> TBM1 -> TBM2 -> TBM3 -> TM1 ->
## TM Remaja -> Tanaman Tua. Tiga tahap produksi terakhir (TM1/TM Remaja/
## Tanaman Tua) masing-masing ditutup demo panen dgn ALAT & GERAKAN berbeda
## sesuai tinggi pokok:
##  - TM1        : DODOS — ditusukkan lurus (gerak menombak), pokok masih pendek.
##  - TM Remaja  : EGREK bergalah PENDEK — diayun.
##  - Tanaman Tua: EGREK bergalah PANJANG — diayun, pokok sangat tinggi.
## Kamera bergerak otomatis antar-zona, pemain menekan "Lanjut" utk maju.
##
## Tahap lapangan (TB-0..Tanaman Tua) pakai pola tanam SEGITIGA SAMA SISI jarak
## 9 m (baris T-B berjarak 9*sin(60 deg)=7,8 m, selang-seling digeser 4,5 m —
## lihat Gambar "Pola Tanam 9x9" referensi) & ±143 pokok/ha. Tahap bibitan (PN/
## MN) pakai jarak nyata dari data/nursery_stages.json (PN: baris rapat ±15 cm,
## MN: segitiga 0,9 m). Semua model tahap pakai aset dedicated "Asset kelapa
## sawit" (res://assets/models/palm/stages/) via PalmBuilder.build_asset_stage()
## — skala meter asli, tidak di-rescale.
##
## Lingkup saat ini: siklus tanaman (kecambah->tanaman tua) + 3 demo panen.
## Rantai logistik (muat truk / timbang PKS / loading ramp) menyusul di
## iterasi berikutnya.

const GRASS := "res://assets/models/nature/Grass_Common_Tall.gltf"
const GRASS_SHORT := "res://assets/models/nature/Grass_Common_Short.gltf"
const CLOVER := "res://assets/models/nature/Clover_1.gltf"
const ROCKPATH := "res://assets/models/nature/RockPath_Square_Wide.gltf"

const SOIL_DRY_COL := Color(0.42, 0.33, 0.22)
const SOIL_WET_COL := Color(0.26, 0.19, 0.13)
const BAMBOO_COL := Color(0.62, 0.55, 0.30)

const PLANT_SIDE := 9.0        # jarak tanam lapangan (m), segitiga sama sisi
const FIELD_ROWS := 4           # "baris T-B" per zona lapangan (default)
const FIELD_PER_ROW := 3        # pokok per baris (default)
const FIELD_W := 32.0
const FIELD_L := 32.0

const MN_SIDE := 0.9             # jarak tanam segitiga Main Nursery (data/nursery_stages.json)
const MN_COLS := 4               # jumlah baris segitiga (lebar)
const MN_DEPTH := 8              # pokok per baris (kedalaman, menjauh dari kamera)

const PN_ROW_GAP := 0.45         # jarak antar baris polybag (m, ~row_gap_m data)
const PN_SPACING := 0.17         # jarak dalam baris (m, ~spacing_m data)
const PN_LINES := 4              # jumlah baris polybag per bedengan umur
const PN_DEEP := 14              # polybag per baris
const PN_STRIP_GAP := 0.8        # jarak antar bedengan umur (jalan pikul)

const ZONE_GAP := 6.0
const GLOBAL_CX := FIELD_W * 0.5   # pusat X bersama semua zona (lebar zona lapangan)
const DEFAULT_FOV := 75.0

var _zones: Array = []
var _total_len := 0.0
var _max_w := 0.0

var _cam: Camera3D
var _cam_from_pos := Vector3.ZERO
var _cam_to_pos := Vector3.ZERO
var _cam_from_look := Vector3.ZERO
var _cam_to_look := Vector3.ZERO
var _cam_from_fov := DEFAULT_FOV
var _cam_to_fov := DEFAULT_FOV
var _look_cur := Vector3.ZERO
var _cam_busy := false

var _hero_pos := {}   # zone_idx(int) -> Vector3
var _hero_h := {}     # zone_idx(int) -> float (m)

# --- kontrol kamera manual (orbit-drag + scroll zoom), aktif selama tdk _cam_busy.
# Dipusatkan di _look_cur (titik yg sama dipakai _process utk look_at), jadi tiap
# kali tiba di zona baru (_goto_zone) orbit disinkronkan ulang dari framing default.
var _orbit_yaw := 0.0
var _orbit_pitch := 0.0
var _orbit_dist := 5.0
var _dragging := false
var _drag_last := Vector2.ZERO
## D-pad sentuh yang mengubah PANDANGAN (lihat _apply_view_dpad).
var _dpad
const ORBIT_MIN_DIST := 0.12
const ORBIT_MAX_DIST := 90.0
const ORBIT_MIN_PITCH := -1.45
const ORBIT_MAX_PITCH := 0.35

var _stage := 0            # 0..NUM_ZONES-1 = zona siklus, NUM_ZONES = selesai
var _harvest_phase := 0    # 0=caption zona biasa, 1=caption intro-panen, 2=animasi panen
var _title_lbl: Label
var _body_lbl: Label
var _action_btn: Button
var _panel: PanelContainer

func _ready() -> void:
	_zones = _make_zones()
	_layout_zones()
	_build_world()
	for z in _zones:
		_build_zone(z)
	_build_ui()
	_goto_zone(0, true)
	if OS.get_cmdline_user_args().has("shotpasca"):
		call_deferred("_capture")
	if OS.get_cmdline_user_args().has("pascaharvest"):
		call_deferred("_selftest_harvest")

## Jalur uji headless: lompat ke zona TM1 (hero pertama) & langsung panen, utk cek error runtime.
func _selftest_harvest() -> void:
	var idx := _first_harvest_zone_idx()
	_goto_zone(idx, true)
	_stage = idx
	_harvest_phase = 2
	await _play_harvest(idx, String(_zones[idx]["harvest"]["tool"]))
	print("[pascapanen] selftest harvest selesai, stage=%d" % _stage)
	get_tree().quit()

func _first_harvest_zone_idx() -> int:
	for i in _zones.size():
		if _zones[i].has("harvest"):
			return i
	return 0

## "-- shotpasca <idx>" untuk melompat ke zona tertentu dulu (zona lapangan
## memperlihatkan horizon & awan; zona kecambah terlalu close-up).
func _capture() -> void:
	var a := OS.get_cmdline_user_args()
	var zi := 0
	for i in a.size():
		if String(a[i]) == "shotpasca" and i + 1 < a.size() and String(a[i + 1]).is_valid_int():
			zi = clampi(int(String(a[i + 1])), 0, _zones.size() - 1)
	if zi > 0:
		_goto_zone(zi, true)
		_stage = zi
	# "-- shotpasca wide": arahkan kamera ke langit untuk memeriksa awan.
	# _process() selalu look_at(_look_cur), jadi cara menengadah adalah
	# menaikkan titik pandangnya.
	if a.has("wide"):
		_cam_busy = false
		_cam.position = Vector3(GLOBAL_CX - 40.0, 22.0, _total_len * 0.5 - 150.0)
		_look_cur = Vector3(GLOBAL_CX, 68.0, _total_len * 0.5)
	# "-- shotpasca holdview right": tahan satu arah D-pad lalu potret, untuk
	# memeriksa arah putar/zoom benar-benar terasa sesuai labelnya.
	var hold := ""
	for i in a.size():
		if String(a[i]) == "holdview" and i + 1 < a.size():
			hold = String(a[i + 1])
	await get_tree().create_timer(1.0).timeout
	var suffix := ""
	if hold != "" and _dpad != null:
		get_viewport().get_texture().get_image().save_png("user://pascapanen_before.png")
		_dpad._set_dir(hold, true)
		await get_tree().create_timer(1.0).timeout
		_dpad.release_all()
		suffix = "_" + hold
	get_viewport().get_texture().get_image().save_png("user://pascapanen%s.png" % suffix)
	print("[pascapanen] screenshot saved (zona %d%s)" % [zi, (" hold " + hold) if hold != "" else ""])
	get_tree().quit()

# --- D-pad pengubah PANDANGAN (bukan penggerak player) -----------------
# Scene ini tidak punya karakter yang berjalan; tombol panah di sini memutar
# dan memaju-mundurkan kamera, yaitu hal yang sama dengan drag & pinch tapi
# lewat tombol — penting karena drag/pinch tidak selalu tertangkap di HP
# Android (akar masalah yang sama dengan joystick lama).
const VIEW_YAW_SPEED := 1.25    # radian/detik saat tombol kiri/kanan ditahan
const VIEW_ZOOM_SPEED := 0.85   # laju maju/mundur (perkalian jarak per detik)

func _process(dt: float) -> void:
	_apply_view_dpad(dt)
	if _cam:
		_cam.look_at(_look_cur, Vector3.UP)

func _apply_view_dpad(dt: float) -> void:
	if _dpad == null or _cam == null or _cam_busy:
		return
	var v: Vector2 = _dpad.output
	if v == Vector2.ZERO:
		return
	# Kiri/kanan = putar pandangan mengelilingi titik yang sedang dilihat.
	if absf(v.x) > 0.01:
		_orbit_yaw += v.x * VIEW_YAW_SPEED * dt
	# Atas = maju (mendekat), bawah = mundur (menjauh).
	# output.y bernilai -1 untuk atas, jadi jaraknya mengecil — persis arah
	# yang diharapkan tanpa perlu dibalik.
	if absf(v.y) > 0.01:
		_orbit_dist = clampf(_orbit_dist * (1.0 + v.y * VIEW_ZOOM_SPEED * dt),
			ORBIT_MIN_DIST, ORBIT_MAX_DIST)
	_apply_orbit()

## Orbit-drag (mouse/touch) + scroll/pinch zoom di sekitar `_look_cur` — aktif
## kapan saja kamera TIDAK sedang auto-travel (_cam_busy), jadi pemain bisa bebas
## memutar & maju-mundurkan pandangan di tiap zona (terutama bibitan) sebelum
## menekan "Lanjut". Tombol UI (CanvasLayer, mouse_filter STOP) menyerap klik
## duluan jadi tak bentrok dgn drag di area 3D.
func _unhandled_input(event: InputEvent) -> void:
	if _cam_busy or _cam == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				_dragging = mb.pressed
				_drag_last = mb.position
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					_orbit_dist = clampf(_orbit_dist * 0.88, ORBIT_MIN_DIST, ORBIT_MAX_DIST)
					_apply_orbit()
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_orbit_dist = clampf(_orbit_dist * 1.14, ORBIT_MIN_DIST, ORBIT_MAX_DIST)
					_apply_orbit()
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_orbit_drag(mm.relative)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		_dragging = st.pressed
		_drag_last = st.position
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_orbit_drag(sd.relative)
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		_orbit_dist = clampf(_orbit_dist / maxf(mg.factor, 0.01), ORBIT_MIN_DIST, ORBIT_MAX_DIST)
		_apply_orbit()

func _orbit_drag(rel: Vector2) -> void:
	_orbit_yaw -= rel.x * 0.008
	_orbit_pitch = clampf(_orbit_pitch - rel.y * 0.008, ORBIT_MIN_PITCH, ORBIT_MAX_PITCH)
	_apply_orbit()

func _apply_orbit() -> void:
	var dir := Vector3(
		cos(_orbit_pitch) * sin(_orbit_yaw),
		sin(_orbit_pitch),
		cos(_orbit_pitch) * cos(_orbit_yaw))
	_cam.position = _look_cur + dir * _orbit_dist

## Sinkronkan ulang variabel orbit dari posisi kamera saat ini relatif ke
## `_look_cur` — dipanggil tiap kali framing default sebuah zona tercapai
## (instant atau selesai tween), supaya orbit manual selalu mulai dari
## komposisi yg sudah dirancang, bukan residu zona sebelumnya.
func _sync_orbit_from_cam() -> void:
	var off: Vector3 = _cam.position - _look_cur
	var d: float = off.length()
	if d < 0.0001:
		return
	_orbit_dist = d
	var dirn: Vector3 = off / d
	_orbit_pitch = clampf(asin(clampf(dirn.y, -1.0, 1.0)), ORBIT_MIN_PITCH, ORBIT_MAX_PITCH)
	_orbit_yaw = atan2(dirn.x, dirn.z)

# ------------------------------------------------------------ definisi 10 zona siklus
func _make_zones() -> Array:
	return [
		{
			"kind": "kecambah", "w": 10.0, "l": 10.0,
			"label": "Kecambah — Awal Siklus",
			"title": "Kecambah — Awal Siklus",
			"body": "Benih sawit bersertifikat yang sudah berkecambah (radikula & plumula muncul), siap disemai ke polybag kecil Pre Nursery.",
			"btn": "Lanjut ke Pre Nursery →",
		},
		{
			"kind": "pn", "w": 14.0, "l": 10.0,
			"label": "Pre Nursery (PN) — 1–3 Bulan",
			"title": "Pre Nursery (PN) — Umur 1–3 Bulan",
			"body": "Kecambah disemai di polybag kecil 15×23 cm, disusun rapat dalam bedengan berbaris (±15 cm/polybag) di bawah naungan paranet. Umur 1, 2, dan 3 bulan ditampilkan berdampingan.",
			"btn": "Lanjut ke Main Nursery →",
		},
		{
			"kind": "mn", "w": 14.0, "l": 12.0,
			"label": "Main Nursery (MN) — 12 Bulan",
			"title": "Main Nursery (MN) — Umur 12 Bulan",
			"body": "Umur 3 bulan bibit dipindah ke polybag besar 35×40 cm, jarak tanam segitiga 0,9 m, hingga siap tanam lapangan di umur 12 bulan.",
			"btn": "Lanjut ke Tanam Lapangan (TB-0) →",
		},
		{
			"kind": "field", "w": FIELD_W, "l": FIELD_L, "cover": "clover",
			"asset": PalmBuilder.ASSET_TB0,
			"label": "TB-0 — Baru Ditanam",
			"title": "TB-0 — Baru Ditanam di Lapangan",
			"body": "Bibit 12 bulan dipindah ke lapangan dengan pola tanam segitiga sama sisi, jarak 9 m antar pokok (±143 pokok/ha). Tanaman kacangan (LCC) ditanam sebagai penutup tanah.",
			"btn": "Lanjut ke TBM 1 →",
		},
		{
			"kind": "field", "w": FIELD_W, "l": FIELD_L, "cover": "grass",
			"asset": PalmBuilder.ASSET_TBM1,
			"label": "TBM 1 — Belum Menghasilkan",
			"title": "TBM 1 — Belum Menghasilkan (umur ±1 th)",
			"body": "Pokok mulai tegak, pelepah bertambah. Pola tanam segitiga 9 m tetap dipertahankan. Perawatan fokus pupuk & kendali gulma, piringan dijaga bersih.",
			"btn": "Lanjut ke TBM 2 →",
		},
		{
			"kind": "field", "w": FIELD_W, "l": FIELD_L, "cover": "grass",
			"asset": PalmBuilder.ASSET_TBM2,
			"label": "TBM 2 — Belum Menghasilkan",
			"title": "TBM 2 — Belum Menghasilkan (umur ±2 th)",
			"body": "Tajuk makin lebar, batang mulai terbentuk jelas. Perawatan rutin pupuk, kendali gulma, & sanitasi piringan terus berlanjut.",
			"btn": "Lanjut ke TBM 3 →",
		},
		{
			"kind": "field", "w": FIELD_W, "l": FIELD_L, "cover": "grass",
			"asset": PalmBuilder.ASSET_TBM3,
			"label": "TBM 3 — Belum Menghasilkan",
			"title": "TBM 3 — Belum Menghasilkan (umur ±3 th)",
			"body": "Mendekati umur produktif — tajuk antar-pokok mulai bersentuhan, bunga pertama muncul menjelang panen perdana di umur ±4 tahun.",
			"btn": "Lanjut ke TM 1 →",
		},
		{
			"kind": "field", "w": FIELD_W, "l": FIELD_L, "cover": "grass_path", "hero": true,
			"asset": PalmBuilder.ASSET_TM1,
			"label": "TM 1 — Mulai Menghasilkan",
			"title": "TM 1 — Mulai Menghasilkan (umur ≥4 th)",
			"body": "Tandan Buah Segar (TBS) pertama siap dipanen. Pasar pikul & piringan dijaga bersih agar brondolan mudah dikutip.",
			"btn": "▶ Mulai Proses Panen",
			"harvest": {
				"tool": "dodos",
				"intro_title": "Panen TM 1 — Pakai Dodos",
				"intro_body": "Pokok TM 1 masih pendek, dodos (pisau pahat di ujung galah pendek) masih terjangkau. Mata dodos DITUSUKKAN LURUS ke gagang pelepah/TBS seperti menombak — bukan diayun seperti egrek.",
				"intro_btn": "Tusuk & Potong TBS",
			},
		},
		{
			"kind": "field", "w": FIELD_W, "l": FIELD_L, "cover": "grass_path", "hero": true,
			"rows": 2, "per_row": 2,
			"asset": PalmBuilder.ASSET_TM_REMAJA,
			"label": "TM Remaja — Produksi Puncak",
			"title": "TM Remaja — Produksi Puncak (umur ±8–13 th)",
			"body": "Pokok makin tinggi, tajuk lebat, produksi TBS sedang puncak-puncaknya. Dodos tak lagi terjangkau — piringan & pasar pikul tetap dijaga bersih.",
			"btn": "▶ Mulai Proses Panen",
			"harvest": {
				"tool": "egrek_pendek",
				"intro_title": "Panen TM Remaja — Egrek Pendek",
				"intro_body": "Pemanen beralih ke EGREK bergalah pendek (±3–4 m). Pisau arit di ujung galah DIAYUN memotong tangkai TBS yang matang.",
				"intro_btn": "Ayun & Potong TBS",
			},
		},
		{
			"kind": "field", "w": FIELD_W, "l": FIELD_L, "cover": "grass_path", "hero": true,
			"rows": 2, "per_row": 2,
			"asset": PalmBuilder.ASSET_TM_TUA,
			"label": "Tanaman Tua — Umur >13 Tahun",
			"title": "Tanaman Tua — Umur >13 Tahun",
			"body": "Pokok sudah sangat tinggi (>12 m). Perawatan makin berat, tapi tandan tetap besar & produktif hingga masa replanting.",
			"btn": "▶ Mulai Proses Panen",
			"harvest": {
				"tool": "egrek_panjang",
				"intro_title": "Panen Tanaman Tua — Egrek Panjang",
				"intro_body": "Pokok tinggi >12 m butuh EGREK bergalah panjang (hingga 10–12 m). Pemanen mendongak jauh ke atas, membidik tangkai TBS yang matang, lalu DIAYUN memotongnya.",
				"intro_btn": "Ayun & Potong TBS",
			},
		},
	]

## Hitung posisi tengah (world) tiap zona berurutan di sumbu Z + total panjang/lebar
## dunia (dipakai ground plane). Zona lebih sempit (bibitan) tetap dipusatkan di
## GLOBAL_CX yang sama dgn zona lapangan supaya jalur kamera lurus.
func _layout_zones() -> void:
	var cum := 0.0
	_max_w = 0.0
	for z in _zones:
		var zone: Dictionary = z
		var l: float = zone["l"]
		zone["center"] = Vector3(GLOBAL_CX, 0, cum + l * 0.5)
		cum += l + ZONE_GAP
		_max_w = max(_max_w, float(zone["w"]))
	_total_len = cum - ZONE_GAP

func _build_zone(zone: Dictionary) -> void:
	match String(zone["kind"]):
		"kecambah": _build_zone_kecambah(zone)
		"pn": _build_zone_pn(zone)
		"mn": _build_zone_mn(zone)
		"field": _build_zone_field(zone)

# ------------------------------------------------------------ dunia & kamera
func _build_world() -> void:
	# Awan dipasang manual (bukan lewat build_env) karena dunia ini memanjang
	# di sumbu Z dan bergeser di X — sebaran awan default yang berpusat di
	# origin tidak akan masuk pandangan kamera.
	SkyKit.build_env(self, Vector3(-50, -35, 0), 0.0012, false)
	var clouds := CloudField.new()
	clouds.configure(
		Vector3(GLOBAL_CX, 0, _total_len * 0.5),
		_max_w, _total_len,
		12)   # dunia panjang -> awan lebih banyak agar tidak terlihat jarang
	clouds.height = 72.0
	add_child(clouds)

	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(_max_w + 8.0, _total_len + 8.0)
	ground.mesh = pm
	var gm := SkyKit.ground_material()
	gm.uv1_scale = Vector3(_max_w * 0.35, _total_len * 0.35, 1)
	ground.material_override = gm
	ground.position = Vector3(GLOBAL_CX, -0.02, _total_len * 0.5)
	add_child(ground)

	_cam = Camera3D.new()
	_cam.current = true
	add_child(_cam)

## Pindah ke zona `idx` (0..NUM_ZONES-1). instant=true utk lompat langsung.
## Zona "hero" (TM1/TM Remaja/Tanaman Tua) dapat framing khusus diskalakan dari
## tinggi pokok hero; kecambah/PN/MN dapat framing jarak-dekat (objeknya jauh
## lebih kecil dari zona lapangan) + FOV sempit utk kecambah (efek zoom lensa).
func _goto_zone(idx: int, instant: bool = false) -> void:
	var zi := clampi(idx, 0, _zones.size() - 1)
	var zone: Dictionary = _zones[zi]
	var center: Vector3 = zone["center"]
	var target_pos: Vector3
	var target_look: Vector3
	var target_fov := DEFAULT_FOV
	if bool(zone.get("hero", false)) and _hero_pos.has(zi):
		var hp: Vector3 = _hero_pos[zi]
		var hh: float = _hero_h[zi]
		var dist: float = 6.0 + hh * 1.1
		target_pos = hp + Vector3(-dist * 0.55, 1.5 + hh * 0.55, dist * 0.75)
		target_look = hp + Vector3(0, hh * 0.4, 0)
	else:
		match String(zone["kind"]):
			"kecambah":
				target_pos = center + Vector3(0, 0.08, 0.55)
				target_look = center + Vector3(0, 0.018, 0)
				target_fov = 16.0
			"pn":
				target_pos = center + Vector3(0, 2.4, 7.2)
				target_look = center + Vector3(0, 0.5, 1.0)
			"mn":
				target_pos = center + Vector3(0, 7.0, 6.0)
				target_look = center + Vector3(0, 0.2, 0)
			_:
				var h: float = float(zone["l"]) * 0.5
				var back: float = float(zone["l"]) * 0.75
				target_pos = center + Vector3(0, h, back)
				target_look = center + Vector3(0, 1.4, 0)
	if instant:
		_cam.position = target_pos
		_cam.fov = target_fov
		_look_cur = target_look
		_sync_orbit_from_cam()
	else:
		_cam_from_pos = _cam.position
		_cam_to_pos = target_pos
		_cam_from_look = _look_cur
		_cam_to_look = target_look
		_cam_from_fov = _cam.fov
		_cam_to_fov = target_fov
		_cam_busy = true
		var tw := create_tween()
		tw.tween_method(_cam_step, 0.0, 1.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.finished.connect(func():
			_cam_busy = false
			_sync_orbit_from_cam())

func _cam_step(t: float) -> void:
	_cam.position = _cam_from_pos.lerp(_cam_to_pos, t)
	_look_cur = _cam_from_look.lerp(_cam_to_look, t)
	_cam.fov = lerpf(_cam_from_fov, _cam_to_fov, t)

# ------------------------------------------------------------ pola tanam
## Segitiga sama sisi ("mata lima") sisi `side` meter: antar baris T-B berjarak
## side*sin(60 deg), dalam baris berjarak `side`, baris ganjil digeser side/2 —
## persis Gambar "Pola Tanam 9x9" referensi. Dipakai lapangan (9 m) & MN (0,9 m).
func _triangular_positions(rows: int, per_row: int, side: float) -> Array:
	var row_gap := side * 0.8660254   # sqrt(3)/2
	var offset := side * 0.5
	var pts: Array = []
	for r in rows:
		for i in per_row:
			var x: float = r * row_gap
			var z: float = i * side + (offset if r % 2 == 1 else 0.0)
			pts.append(Vector3(x, 0, z))
	return pts

## Baris lurus rapat (bukan segitiga) — persis layout "bedengan_rapat" Pre
## Nursery: `cols` baris polybag berjarak `col_gap`, tiap baris berisi `rows`
## polybag rapat berjarak `row_gap`.
func _rect_positions(cols: int, rows: int, col_gap: float, row_gap: float) -> Array:
	var pts: Array = []
	for c in cols:
		for r in rows:
			pts.append(Vector3(c * col_gap, 0, r * row_gap))
	return pts

## Geser kumpulan titik lokal supaya titik tengah bounding box-nya jatuh persis
## di `center` dunia.
func _center_positions(pts: Array, center: Vector3) -> Array:
	var minx := INF; var maxx := -INF; var minz := INF; var maxz := -INF
	for p in pts:
		var v: Vector3 = p
		minx = min(minx, v.x); maxx = max(maxx, v.x)
		minz = min(minz, v.z); maxz = max(maxz, v.z)
	var cx := (minx + maxx) * 0.5
	var cz := (minz + maxz) * 0.5
	var out: Array = []
	for p in pts:
		var v2: Vector3 = p
		out.append(Vector3(center.x + (v2.x - cx), 0, center.z + (v2.z - cz)))
	return out

# ------------------------------------------------------------ Zona Kecambah
func _build_zone_kecambah(zone: Dictionary) -> void:
	var center: Vector3 = zone["center"]
	_soil_patch(center, 1.6, 1.3, SOIL_DRY_COL)
	# Satu baris 3 kecambah MELEBAR (sumbu X, tegak lurus arah kamera) — bukan
	# ditumpuk ke dalam (Z) spy tak saling tumpang-tindih di layar saat di-zoom.
	var pts := _center_positions(_rect_positions(3, 1, 0.04, 0.0), center)
	for p in pts:
		var k := PalmBuilder.build_asset_stage(PalmBuilder.ASSET_KECAMBAH)
		k.position = p
		k.rotate_y(randf() * TAU)
		add_child(k)
	_add_sign(center + Vector3(0, 0, -float(zone["l"]) * 0.5 + 1.5), String(zone["label"]), 1.2, 0.35)

# ------------------------------------------------------------ Zona Pre Nursery
func _build_zone_pn(zone: Dictionary) -> void:
	var center: Vector3 = zone["center"]
	var strips := [
		[PalmBuilder.ASSET_PN_1BLN, "1 Bulan"],
		[PalmBuilder.ASSET_PN_2BLN, "2 Bulan"],
		[PalmBuilder.ASSET_PN_3BLN, "3 Bulan"],
	]
	var strip_w: float = (PN_LINES - 1) * PN_ROW_GAP
	var strip_l: float = (PN_DEEP - 1) * PN_SPACING
	var total_w: float = strips.size() * strip_w + (strips.size() - 1) * PN_STRIP_GAP
	var start_x: float = center.x - total_w * 0.5 + strip_w * 0.5
	var near_z: float = center.z - strip_l * 0.5 - 0.7   # label/hero sedikit di depan bedengan
	_soil_patch(center, total_w + 1.5, strip_l + 2.0, SOIL_DRY_COL)
	for s in strips.size():
		var asset_path := String(strips[s][0])
		var strip_center := Vector3(start_x + s * (strip_w + PN_STRIP_GAP), 0, center.z)
		var pts := _center_positions(_rect_positions(PN_LINES, PN_DEEP, PN_ROW_GAP, PN_SPACING), strip_center)
		for p in pts:
			var seedling := PalmBuilder.build_asset_stage(asset_path)
			seedling.position = p
			seedling.rotate_y(randf() * TAU)
			add_child(seedling)
		_bamboo_stakes(strip_center, strip_w + 0.3, strip_l + 0.3)
		# Satu pokok hero berlabel umur, berdiri sedikit di depan bedengannya.
		var hero := PalmBuilder.build_asset_stage(asset_path)
		hero.position = Vector3(strip_center.x, 0, near_z)
		add_child(hero)
		_label3d(Vector3(strip_center.x, 0.05, near_z + 0.9), String(strips[s][1]))
	_add_sign(center + Vector3(0, 0, -float(zone["l"]) * 0.5 + 1.2), String(zone["label"]), 1.6, 0.45)

# ------------------------------------------------------------ Zona Main Nursery
func _build_zone_mn(zone: Dictionary) -> void:
	var center: Vector3 = zone["center"]
	var pts := _center_positions(_triangular_positions(MN_COLS, MN_DEPTH, MN_SIDE), center)
	_soil_patch(center, (MN_COLS - 1) * MN_SIDE * 0.866 + 2.0, (MN_DEPTH - 1) * MN_SIDE + 2.0, SOIL_WET_COL)
	for p in pts:
		var s := PalmBuilder.build_asset_stage(PalmBuilder.ASSET_MN_12BLN)
		s.position = p
		s.rotate_y(randf() * TAU)
		add_child(s)
	_add_sign(center + Vector3(0, 0, -float(zone["l"]) * 0.5 + 1.5), String(zone["label"]), 2.0, 0.45)

# ------------------------------------------------------------ Zona lapangan (TB-0..Tanaman Tua)
func _build_zone_field(zone: Dictionary) -> void:
	var center: Vector3 = zone["center"]
	var w: float = zone["w"]
	var l: float = zone["l"]
	var origin := center - Vector3(w * 0.5, 0, l * 0.5)
	match String(zone.get("cover", "grass")):
		"clover":
			var cs := load(CLOVER)
			if cs:
				for i in 90:
					var c := _fit(cs.instantiate(), 0.22)
					c.position = origin + Vector3(randf() * w, 0, randf() * l)
					c.rotate_y(randf() * TAU)
					add_child(c)
		"grass":
			var gs := load(GRASS)
			if gs:
				for i in 80:
					var g := _fit(gs.instantiate(), 0.4)
					g.position = origin + Vector3(randf() * w, 0, randf() * l)
					g.rotate_y(randf() * TAU)
					add_child(g)
		"grass_path":
			var gs2 := load(GRASS_SHORT)
			if gs2:
				for i in 34:
					var g2 := _fit(gs2.instantiate(), 0.25)
					g2.position = origin + Vector3(randf() * w, 0, randf() * l)
					g2.rotate_y(randf() * TAU)
					add_child(g2)
			var ps := load(ROCKPATH)
			if ps:
				for i in 6:
					var pth := _fit(ps.instantiate(), 0.0)
					pth.position = Vector3(center.x, 0, origin.z + 2.0 + i * (l - 4.0) / 5.0)
					add_child(pth)

	var rows: int = int(zone.get("rows", FIELD_ROWS))
	var per_row: int = int(zone.get("per_row", FIELD_PER_ROW))
	var pts := _center_positions(_triangular_positions(rows, per_row, PLANT_SIDE), center)
	var asset_path := String(zone["asset"])
	var is_hero_zone: bool = bool(zone.get("hero", false))
	var hero_idx: int = pts.size() / 2
	for i in pts.size():
		var tree := PalmBuilder.build_asset_stage(asset_path)
		tree.position = pts[i]
		tree.rotate_y(randf() * TAU)
		add_child(tree)
		if is_hero_zone and i == hero_idx:
			var zi: int = _zones.find(zone)
			_hero_pos[zi] = pts[i]
			_hero_h[zi] = PalmBuilder.asset_height(asset_path)
	_add_sign(center + Vector3(0, 0, -l * 0.5 + 2.5), String(zone["label"]))

func _soil_patch(center: Vector3, w: float, l: float, col: Color) -> void:
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(w, l)
	m.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 1.0
	m.material_override = mat
	m.position = Vector3(center.x, -0.01, center.z)
	add_child(m)

## 4 tiang bambu di sudut bedengan (penanda bingkai bedengan spt foto referensi).
func _bamboo_stakes(center: Vector3, w: float, l: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BAMBOO_COL
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var stake := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.015
			cyl.bottom_radius = 0.02
			cyl.height = 0.5
			stake.mesh = cyl
			stake.material_override = mat
			stake.position = center + Vector3(sx * w * 0.5, 0.25, sz * l * 0.5)
			add_child(stake)

## `height_off`/`size_mult` dikecilkan utk zona bibitan (kamera jauh lebih dekat
## drpd zona lapangan) spy teks papan nama tak kebesaran/terpotong di layar.
func _add_sign(pos: Vector3, text: String, height_off: float = 2.4, size_mult: float = 1.0) -> void:
	var l3 := Label3D.new()
	l3.text = text
	l3.font_size = 48
	l3.pixel_size = 0.012 * size_mult
	l3.position = pos + Vector3(0, height_off, 0)
	l3.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l3.modulate = Color(1, 1, 1)
	l3.outline_size = 10
	add_child(l3)

## Label kecil mengambang (dipakai utk keterangan umur bibit PN 1/2/3 bulan).
func _label3d(pos: Vector3, text: String) -> void:
	var l3 := Label3D.new()
	l3.text = text
	l3.font_size = 28
	l3.pixel_size = 0.01
	l3.position = pos
	l3.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l3.modulate = Color(1, 1, 1)
	l3.outline_size = 8
	add_child(l3)

# ------------------------------------------------------------ UI (caption + tombol)
# Kolom teks + tombol DITUMPUK VERTIKAL (bukan sebaris) supaya tombol tidak pernah
# terpotong di layar sempit/potret — lebar penuh panel selalu cukup.
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var back := Button.new()
	back.text = "← Kembali ke Menu"
	back.position = Vector2(12, 12)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	layer.add_child(back)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.position.y = -220
	_panel.custom_minimum_size = Vector2(0, 220)
	layer.add_child(_panel)

	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 16)
	_panel.add_child(m)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	m.add_child(col)

	_title_lbl = Label.new()
	_title_lbl.add_theme_font_size_override("font_size", 20)
	_title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_title_lbl)

	_body_lbl = Label.new()
	_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_lbl.add_theme_font_size_override("font_size", 14)
	col.add_child(_body_lbl)

	_action_btn = Button.new()
	_action_btn.custom_minimum_size = Vector2(0, 44)
	_action_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_btn.pressed.connect(_on_action)
	col.add_child(_action_btn)

	_build_view_dpad(layer)
	_refresh_panel()

## D-pad pengubah pandangan, ditaruh DI ATAS panel penjelasan (panel memakai
## 220 px paling bawah, kalau tidak digeser tombolnya tertimbun).
func _build_view_dpad(layer: CanvasLayer) -> void:
	const PANEL_H := 220
	_dpad = load("res://scenes/world/TouchDPad.gd").new()
	layer.add_child(_dpad)
	_dpad.anchor_bottom_left(14, PANEL_H + 42)

	# Keterangan: di scene lain panah menggerakkan pemain, di sini mengubah
	# kamera — tanpa label pemain akan mengira ini kontrol jalan.
	var cap := Label.new()
	cap.text = "PANDANGAN  ▲▼ maju-mundur  ◀▶ putar"
	cap.add_theme_font_size_override("font_size", 10)
	cap.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	var cap_bg := StyleBoxFlat.new()
	cap_bg.bg_color = Color(0.06, 0.09, 0.07, 0.72)
	cap_bg.set_corner_radius_all(6)
	cap_bg.set_content_margin_all(6)
	var cap_panel := PanelContainer.new()
	cap_panel.add_theme_stylebox_override("panel", cap_bg)
	cap_panel.add_child(cap)
	cap_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(cap_panel)
	cap_panel.anchor_left = 0.0
	cap_panel.anchor_right = 0.0
	cap_panel.anchor_top = 1.0
	cap_panel.anchor_bottom = 1.0
	cap_panel.offset_left = 14
	cap_panel.offset_top = -(PANEL_H + 42 + 204 + 26)
	cap_panel.offset_bottom = -(PANEL_H + 42 + 204 + 2)

func _refresh_panel() -> void:
	_action_btn.disabled = false
	if _stage < _zones.size():
		var zone: Dictionary = _zones[_stage]
		if _harvest_phase == 1 and zone.has("harvest"):
			var hv: Dictionary = zone["harvest"]
			_title_lbl.text = String(hv["intro_title"])
			_body_lbl.text = String(hv["intro_body"])
			_action_btn.text = String(hv["intro_btn"])
		else:
			_title_lbl.text = String(zone["title"])
			_body_lbl.text = String(zone["body"])
			_action_btn.text = String(zone["btn"])
		return
	# _stage == _zones.size() -> selesai
	_title_lbl.text = "Selesai — Siklus Tanaman Kelapa Sawit"
	_body_lbl.text = "Kecambah → PN → MN → TB-0 → TBM1 → TBM2 → TBM3 → TM1 → TM Remaja → Tanaman Tua sudah dilalui, lengkap dgn 3 demo panen (dodos, egrek pendek, egrek panjang). Rantai logistik pascapanen (muat truk, timbang PKS & loading ramp) menyusul di update berikutnya."
	_action_btn.text = "🔁 Ulangi"

func _on_action() -> void:
	if _cam_busy:
		return
	if _stage < _zones.size():
		var zone: Dictionary = _zones[_stage]
		if zone.has("harvest"):
			if _harvest_phase == 0:
				_harvest_phase = 1
				_refresh_panel()
				return
			elif _harvest_phase == 1:
				_harvest_phase = 2
				_action_btn.disabled = true
				_play_harvest(_stage, String(zone["harvest"]["tool"]))
				return
		# zona biasa (atau hero yg sudah selesai dipanen) -> lanjut
		if _stage < _zones.size() - 1:
			_stage += 1
			_harvest_phase = 0
			_goto_zone(_stage)
			_refresh_panel()
		else:
			_stage = _zones.size()
			_refresh_panel()
	else:
		get_tree().reload_current_scene()

# ------------------------------------------------------------ Animasi panen
## tool: "dodos" (ditusuk lurus spt menombak) | "egrek_pendek" | "egrek_panjang" (diayun).
func _play_harvest(zone_idx: int, tool: String) -> void:
	var hero_pos: Vector3 = _hero_pos[zone_idx]
	var hero_h: float = _hero_h[zone_idx]

	var worker_off: Vector3
	var pole_len: float
	match tool:
		"dodos":
			worker_off = Vector3(1.1, 0, 0.6)
			pole_len = clampf(hero_h * 0.55, 1.2, 2.4)
		"egrek_pendek":
			worker_off = Vector3(2.2, 0, 0.9)
			pole_len = hero_h * 0.65
		_:   # egrek_panjang
			worker_off = Vector3(2.8, 0, 1.1)
			pole_len = hero_h * 0.82

	var worker := PemanenBuilder.build(1.65)
	worker.position = hero_pos + worker_off
	add_child(worker)
	worker.look_at(hero_pos + Vector3(0, 1.0, 0), Vector3.UP)

	var pivot: Node3D = worker.get_meta("hand_pivot")
	PemanenBuilder.attach_egrek(pivot, pole_len)

	if tool == "dodos":
		# Dodos: badan condong/menunduk ke depan (dekat pokok pendek), lengan
		# menusuk lurus dari posisi itu — beda dgn egrek yg berdiri tegak mendongak.
		var torso: Node3D = worker.get_meta("torso")
		if torso:
			torso.rotation_degrees.x = -28.0
		pivot.rotation_degrees.x = -15.0
		_body_lbl.text = "Menusukkan dodos lurus ke gagang TBS, seperti menombak..."
		var jab_tw := create_tween()
		jab_tw.tween_property(pivot, "rotation_degrees:x", -72.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await jab_tw.finished
		await get_tree().create_timer(0.18).timeout
	else:
		var raise_tw := create_tween()
		raise_tw.tween_property(pivot, "rotation_degrees:x", -80.0, 1.1).set_trans(Tween.TRANS_SINE)
		await raise_tw.finished
		_body_lbl.text = "Membidik & mengayun egrek menebas tangkai TBS matang..."
		await get_tree().create_timer(0.5).timeout

	var tbs := TBSBuilder.build(hero_h * 0.16, true)
	tbs.position = hero_pos + Vector3(0.3, hero_h * 0.82, 0.2)
	add_child(tbs)
	var land_pos := hero_pos + Vector3(randf_range(-0.5, 0.9), 0.06, randf_range(-0.5, 0.5))

	var fall_tw := create_tween()
	fall_tw.tween_property(tbs, "position", land_pos, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall_tw.parallel().tween_property(tbs, "rotation_degrees", Vector3(randf_range(-70, 70), randf() * 360, randf_range(-70, 70)), 0.7)
	await fall_tw.finished
	SoundManager.drop()

	TBSBuilder.brondolan_burst(self, land_pos, 16)

	var lower_tw := create_tween()
	lower_tw.tween_property(pivot, "rotation_degrees:x", -20.0 if tool == "dodos" else -25.0, 0.5)

	_title_lbl.text = "TBS Jatuh ke Piringan"
	_body_lbl.text = "Brondolan yang lepas wajib dikutip bersih sesuai SOP Panen, lalu TBS dikumpulkan ke TPH."
	await get_tree().create_timer(1.4).timeout

	if zone_idx < _zones.size() - 1:
		_stage = zone_idx + 1
		_harvest_phase = 0
		_goto_zone(_stage)
	else:
		_stage = _zones.size()
	_refresh_panel()

# ------------------------------------------------------------ util skala (AABB)
func _fit(inst: Node3D, target_h: float) -> Node3D:
	var aabb := _local_aabb(inst)
	if target_h > 0.0 and aabb.size.y > 0.0001:
		var s: float = target_h / aabb.size.y
		inst.scale = Vector3(s, s, s)
		inst.position.y = -aabb.position.y * s
	else:
		inst.position.y = -aabb.position.y
	return inst

func _local_aabb(inst: Node) -> AABB:
	var aabb := AABB(); var first := true
	for m in _meshes(inst):
		var a: AABB = _rel_xform(inst, m) * m.mesh.get_aabb()
		if first: aabb = a; first = false
		else: aabb = aabb.merge(a)
	return aabb

func _rel_xform(root: Node, node: Node3D) -> Transform3D:
	var t := Transform3D(); var n: Node = node
	while n != null and n != root:
		if n is Node3D: t = (n as Node3D).transform * t
		n = n.get_parent()
	return t

func _meshes(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append(node)
	for c in node.get_children():
		out.append_array(_meshes(c))
	return out
