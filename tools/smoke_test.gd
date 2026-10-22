extends Node
## Uji perilaku headless untuk perubahan Catatan Perbaikan.
##   Godot --headless --path . res://tools/Smoke.tscn
## Cetak "SMOKE-OK" bila semua lolos, "SMOKE-FAIL" bila ada yang gagal.

var _fail: Array[String] = []
var _n := 0

func _ready() -> void:
	_test_fert_schedule()
	_test_fert_reminders()
	_test_mixing_warning()
	_test_task_gating()
	_test_task_rewards_and_daily_limit()
	_test_field_task_data()
	_test_clouds()
	_test_dpad()
	_test_targets_round_flow()
	_test_catch_flow()
	_test_pascapanen_clouds()

	print("\n=== SMOKE TEST ===")
	print("assertion: %d" % _n)
	if _fail.is_empty():
		print("SMOKE-OK")
	else:
		print("SMOKE-FAIL (%d):" % _fail.size())
		for f in _fail:
			print("  ✗ %s" % f)
	get_tree().quit(0 if _fail.is_empty() else 1)

func _ok(cond: bool, what: String) -> void:
	_n += 1
	if not cond:
		_fail.append(what)

func _eq(a, b, what: String) -> void:
	_n += 1
	if a != b:
		_fail.append("%s  (dapat %s, harap %s)" % [what, str(a), str(b)])

# ------------------------------------------------------------------
func _test_fert_schedule() -> void:
	# Contoh eksplisit dari dokumen: bulan 56 -> UREA 1200 g/pokok (1,2 kg)
	var m56 := Database.fert_schedule_month(56)
	_eq(m56.size(), 1, "bulan 56 hanya satu jenis pupuk")
	_eq(float(m56.get("Urea", 0)), 1200.0, "bulan 56 Urea 1200 g")
	_eq(Agronomy.fmt_kg(1200.0), "1,2 kg", "format 1200 g -> 1,2 kg")
	_eq(Agronomy.fmt_kg(60.0), "60 gr", "format 60 g -> 60 gr")
	_eq(Agronomy.dose_text({"Urea": 1200.0}), "1,2 kg Urea", "teks dosis dokumen")

	# Hari ke-1680 = bulan 56 (sesuai kolom Hari di spreadsheet)
	var found := false
	for e in Database.fertilizer_schedule.get("schedule", []):
		if int(e.get("bulan", -1)) == 56:
			found = int(e.get("hari", -1)) == 1680
	_ok(found, "bulan 56 jatuh pada hari 1680")

	_eq(Agronomy.plant_year_of_month(12), 1, "bulan 12 = tahun 1")
	_eq(Agronomy.plant_year_of_month(13), 2, "bulan 13 = tahun 2")
	_eq(Agronomy.plant_year_of_month(56), 5, "bulan 56 = tahun 5")

	# Rencana per blok: 143 pokok x 1200 g = 171,6 kg
	var blok := { "id": "B1", "area_ha": 1.0, "planting_day": 0, "land_class": "S1" }
	GameState.day = 1680
	var plan := Agronomy.monthly_fert_plan(blok, 56)
	_eq(int(plan.get("palms", 0)), 143, "143 pokok per blok 1 ha")
	var comps: Array = plan.get("components", [])
	_eq(comps.size(), 1, "satu komponen di bulan 56")
	if comps.size() == 1:
		_ok(abs(float(comps[0]["kg_total"]) - 171.6) < 0.05, "total 171,6 kg untuk 143 pokok")
	_ok(int(plan.get("total_cost", 0)) > 0, "biaya pupuk bulan 56 > 0")

func _test_fert_reminders() -> void:
	GameState.start_new_game("pekerja_aktif")
	GameState.day = 1000
	GameState.plots = [{
		"id": "B1", "state": "tanam", "area_ha": 1.0, "land_class": "S1",
		"seed_id": "marihat_ppks", "planting_day": 1000, "health": 1.0,
	}]
	# Panggilan pertama hanya menandai baseline, TIDAK memuntahkan masa lalu.
	_eq(GameState.collect_fert_reminders().size(), 0, "panggilan pertama tidak memunculkan reminder")

	# Maju 1 bulan -> bulan 1 terjadwal (MOP 300 g)
	GameState.day = 1030
	var r1 := GameState.collect_fert_reminders()
	_eq(r1.size(), 1, "umur 1 bulan memunculkan 1 reminder")
	if r1.size() == 1:
		_ok(String(r1[0]["body"]).contains("300 gr MOP"), "reminder bulan 1 menyebut 300 gr MOP")
		_ok(String(r1[0]["title"]).contains("B1"), "reminder menyebut id blok")
	# Dipanggil lagi di hari yang sama -> tidak dobel
	_eq(GameState.collect_fert_reminders().size(), 0, "reminder tidak terulang di hari sama")

	# Lompat jauh (melewati beberapa jadwal) -> semua terkumpul berurutan
	GameState.day = 1000 + 5 * 30     # bulan 5
	var r2 := GameState.collect_fert_reminders()
	_ok(r2.size() >= 1, "lompat hari mengumpulkan jadwal terlewat")

	# Dua blok ditanam di hari sama -> dua reminder terpisah
	GameState.day = 2000
	GameState.plots = [
		{ "id": "B1", "state": "tanam", "area_ha": 1.0, "land_class": "S1",
		  "seed_id": "marihat_ppks", "planting_day": 2000, "health": 1.0 },
		{ "id": "B2", "state": "tanam", "area_ha": 1.0, "land_class": "S1",
		  "seed_id": "marihat_ppks", "planting_day": 2000, "health": 1.0 },
	]
	GameState.collect_fert_reminders()          # baseline
	GameState.day = 2030
	var r3 := GameState.collect_fert_reminders()
	_eq(r3.size(), 2, "dua blok tanam sehari -> dua reminder")

func _test_mixing_warning() -> void:
	_eq(Agronomy.mixing_warning(["Urea"]), "", "Urea sendiri tidak ada peringatan")
	_eq(Agronomy.mixing_warning(["RPH"]), "", "RPH sendiri tidak ada peringatan")
	_ok(Agronomy.mixing_warning(["Urea", "RPH"]) != "", "Urea + RPH diperingatkan")
	_ok(Agronomy.mixing_warning(["MOP", "Dolomit"]) != "", "MOP + Dolomit diperingatkan")
	_ok(Agronomy.mixing_warning(["Urea", "HGFB"]) != "", "Urea + HGFB diperingatkan")
	_eq(Agronomy.mixing_warning(["Urea", "MOP"]), "", "sesama higroskopis aman")

func _test_task_gating() -> void:
	GameState.start_new_game("pekerja_aktif")
	GameState.day = 100
	GameState.plots = [{ "id": "B1", "state": "kosong" }]
	GameState.nursery = {}

	var tasks: Array = Database.field_tasks.get("tasks", [])
	var by_id := {}
	for t in tasks:
		by_id[String(t.get("id", ""))] = t

	# Tanpa lahan & tanpa pembibitan: semua tugas berhadiah terkunci
	_ok(not GameState.field_task_requirement_met(by_id["semprot"]), "semprot terkunci tanpa lahan/pembibitan")
	_ok(not GameState.field_task_requirement_met(by_id["panen"]), "panen terkunci tanpa TM")
	_ok(not GameState.field_task_requirement_met(by_id["tanam"]), "tanam kecambah terkunci tanpa pembibitan")
	_ok(not GameState.field_task_requirement_met(by_id["transplanting"]), "transplanting terkunci tanpa pembibitan")
	_eq(GameState.field_task_lock_reason(by_id["panen"]),
		"Tidak ada areal TM, tugas tidak bisa dilakukan", "pesan prompt panen sesuai dokumen")
	_eq(GameState.field_task_lock_reason(by_id["tanam"]),
		"Tidak ada areal pembibitan, tugas tidak bisa dilakukan", "pesan prompt tanam sesuai dokumen")

	# Punya pembibitan saja
	GameState.nursery = { "seed_id": "marihat_ppks", "qty": 200, "stage": "pn", "plant_day": 100 }
	_ok(GameState.field_task_requirement_met(by_id["semprot"]), "semprot aktif dengan pembibitan")
	_ok(GameState.field_task_requirement_met(by_id["tanam"]), "tanam aktif dengan pembibitan")
	_ok(not GameState.field_task_requirement_met(by_id["panen"]), "panen tetap terkunci tanpa TM")

	# Lahan TBM (baru tanam) -> panen masih terkunci
	GameState.nursery = {}
	GameState.plots = [{ "id": "B1", "state": "tanam", "seed_id": "marihat_ppks",
		"planting_day": 100, "area_ha": 1.0, "land_class": "S1" }]
	_ok(GameState.has_planted_land(), "punya lahan tertanam")
	_ok(not GameState.has_tm_land(), "umur 0 tahun belum TM")
	_ok(not GameState.field_task_requirement_met(by_id["panen"]), "panen terkunci saat TBM")

	# Lahan TM (umur 5 tahun)
	GameState.day = 100 + 5 * 365
	_ok(GameState.has_tm_land(), "umur 5 tahun sudah TM")
	_ok(GameState.field_task_requirement_met(by_id["panen"]), "panen aktif saat TM")
	_ok(GameState.field_task_requirement_met(by_id["angkut"]), "angkut aktif saat TM")

func _test_task_rewards_and_daily_limit() -> void:
	GameState.start_new_game("pekerja_aktif")
	GameState.day = 500
	GameState.cash = 0
	GameState.field_task_played = {}
	GameState.field_task_results = {}

	_eq(GameState.field_task_reward_rp(1), 15000, "hadiah 1 bintang Rp15.000")
	_eq(GameState.field_task_reward_rp(2), 30000, "hadiah 2 bintang Rp30.000")
	_eq(GameState.field_task_reward_rp(3), 50000, "hadiah 3 bintang Rp50.000")

	var p1 := GameState.complete_field_task("semprot", 3, "self")
	_eq(int(p1.get("reward", 0)), 50000, "bayar 50rb untuk 3 bintang")
	_eq(GameState.cash, 50000, "saldo bertambah 50rb")

	# Main lagi di hari yang sama -> tidak dibayar lagi
	var p2 := GameState.complete_field_task("semprot", 3, "self")
	_eq(int(p2.get("reward", 0)), 0, "tidak ada hadiah kedua di hari sama")
	_eq(GameState.cash, 50000, "saldo tidak bertambah lagi")
	_ok(GameState.field_task_played_today("semprot"), "semprot tercatat dimainkan hari ini")

	# Besok boleh lagi
	GameState.day = 501
	_ok(not GameState.field_task_played_today("semprot"), "besok limit harian reset")
	var p3 := GameState.complete_field_task("semprot", 1, "self")
	_eq(int(p3.get("reward", 0)), 15000, "hari berikutnya dibayar lagi")

	# Delegasi ke tim tidak berhadiah
	GameState.day = 502
	var cash_before := GameState.cash
	var p4 := GameState.complete_field_task("pupuk", 2, "team")
	_eq(int(p4.get("reward", 0)), 0, "delegasi tim tidak berhadiah")
	_eq(GameState.cash, cash_before, "saldo tidak berubah karena delegasi")

	# Bonus setelah SEMUA tugas berhadiah selesai di hari yang sama
	GameState.day = 600
	GameState.cash = 0
	GameState.field_task_played = {}
	var ids := GameState.field_task_bonus_ids()
	_eq(ids.size(), 7, "ada 7 tugas berhadiah")
	var last_bonus := 0
	for i in ids.size():
		var pay := GameState.complete_field_task(String(ids[i]), 1, "self")
		last_bonus = int(pay.get("bonus", 0))
		if i < ids.size() - 1:
			_eq(int(pay.get("bonus", 0)), 0, "bonus belum keluar di tugas ke-%d" % (i + 1))
	_eq(last_bonus, 100000, "bonus Rp100.000 saat 7 tugas selesai")
	_eq(GameState.cash, 7 * 15000 + 100000, "total saldo = 7x15rb + bonus 100rb")

func _test_field_task_data() -> void:
	var tasks: Array = Database.field_tasks.get("tasks", [])
	_eq(tasks.size(), 8, "8 tugas (7 berhadiah + pembukaan lahan)")
	var mechs := {}
	for t in tasks:
		mechs[String(t.get("id", ""))] = String(t.get("mech", ""))
		# Latar belakang tiap tugas harus ada file-nya
		var bg := String(t.get("bg", ""))
		_ok(bg != "" and ResourceLoader.exists(bg),
			"latar belakang ada untuk tugas %s (%s)" % [t.get("id"), bg])
	_eq(mechs.get("angkut"), "hold", "angkut diubah jadi mekanik tahan")
	_eq(mechs.get("inspeksi"), "catch", "inspeksi diubah jadi mekanik tangkap")
	_eq(mechs.get("transplanting"), "hold", "transplanting mekanik tahan")
	_eq(mechs.get("tanam"), "targets", "tanam kecambah tetap targets")

	# Aset gambar hama untuk minigame catch
	var cfg: Dictionary = {}
	for t in tasks:
		if String(t.get("id", "")) == "inspeksi":
			cfg = t.get("catch", {})
	_eq(int(cfg.get("need", 0)), 5, "tangkap 5 hama")
	_eq((cfg.get("pests", []) as Array).size(), 6, "6 jenis hama dari model .glb")
	_eq((cfg.get("avoid", []) as Array).size(), 2, "2 pengecoh (burung hantu/ayam)")
	for grp in [cfg.get("pests", []), cfg.get("avoid", [])]:
		for item in grp:
			var img := String(item.get("img", ""))
			_ok(ResourceLoader.exists(img), "gambar ada: %s" % item.get("label"))
			# Semua ikon wajib PNG transparan hasil render, bukan foto .jpg
			# yang berlatar kotak putih.
			_ok(img.ends_with(".png"), "ikon %s berupa PNG transparan" % item.get("label"))

	# Peta blok
	_ok(ResourceLoader.exists(String(Database.field_tasks.get("map_bg", ""))),
		"latar peta blok ada")
	# Model awan
	_ok(ResourceLoader.exists("res://assets/models/clouds/awan_cumulus_humilis.glb"),
		"model awan ter-impor")

func _test_clouds() -> void:
	GameState.weather = "cerah"
	var cf := CloudField.new()
	cf.count = 6
	add_child(cf)
	_eq(cf.get_child_count(), 6, "CloudField membuat 6 awan")
	# Model "mendung" hanya untuk cuaca mendung/hujan
	var holder := Node3D.new()
	add_child(holder)
	var any_scaled := false
	for c in cf.get_children():
		if (c as Node3D).scale.x > 0.0 and (c as Node3D).scale.x != 1.0:
			any_scaled = true
	_ok(any_scaled, "model awan dinormalkan ukurannya")
	# Hanyut: posisi x berubah setelah _process
	var before: float = (cf.get_child(0) as Node3D).position.x
	cf._process(1.0)
	_ok(abs((cf.get_child(0) as Node3D).position.x - before) > 0.0, "awan hanyut")
	cf.queue_free()
	holder.queue_free()

	# configure(): dunia yang TIDAK berpusat di origin (seperti scene Siklus
	# Tanaman yang memanjang di Z dan bergeser di X). Semua awan wajib jatuh
	# di sekitar pusat dunia itu, bukan di sekitar (0,0).
	var world_center := Vector3(16.0, 0.0, 240.0)   # mirip GLOBAL_CX & _total_len/2
	var cf2 := CloudField.new()
	cf2.configure(world_center, 32.0, 480.0, 10)
	add_child(cf2)
	_eq(cf2.count, 10, "configure() mengatur jumlah awan")
	_eq(cf2.center, Vector3(16.0, 0.0, 240.0), "pusat awan mengikuti pusat dunia")
	_ok(cf2.spread_z > cf2.spread_x, "sebaran Z lebih panjang untuk dunia memanjang")
	var inside := true
	for c in cf2.get_children():
		var pos: Vector3 = (c as Node3D).position
		if abs(pos.x - world_center.x) > cf2.spread_x * 0.5 + 0.01: inside = false
		if abs(pos.z - world_center.z) > cf2.spread_z * 0.5 + 0.01: inside = false
		if pos.y < 40.0: inside = false
	_ok(inside, "semua awan berada di area dunia (bukan di sekitar origin)")
	cf2.queue_free()

func _task_by_id(id: String) -> Dictionary:
	for t in Database.field_tasks.get("tasks", []):
		if String(t.get("id", "")) == id:
			return t
	return {}

## Bug yang dilaporkan user: "Ketika selesai klik ajir, waktu tidak berhenti".
## Penyebabnya _on_target_tap mengisi _feedback_timer tapi tidak mengubah
## _phase, jadi ronde menggantung. Uji ini mengunci perbaikannya.
func _test_targets_round_flow() -> void:
	GameState.start_new_game("pekerja_aktif")
	GameState.day = 700
	GameState.field_task_played = {}
	GameState.active_field_task = _task_by_id("tanam")

	var play = load("res://scenes/FieldTaskPlay.gd").new()
	add_child(play)      # _ready() -> _build() + _start_round()

	_eq(play._rounds, 5, "tanam kecambah berjalan 5 ronde")
	_eq(play._round_idx, 0, "mulai dari ronde 1")
	_eq(play._phase, "play", "fase awal = play")

	# Waktu berjalan selama fase play
	play._process(1.0)
	_ok(play._elapsed > 0.0, "stopwatch berjalan saat bermain")

	# Ketuk SEMUA ajir (sel valid)
	for cell in play._cells.duplicate():
		if bool(cell.get("valid", false)):
			play._on_target_tap(cell, cell.get("_card"))

	_eq(play._phase, "round_done", "ronde selesai -> fase round_done")
	var frozen: float = play._elapsed
	play._process(5.0)
	_eq(play._elapsed, frozen, "WAKTU BERHENTI setelah semua ajir diklik")
	_ok(play._round_done_layer != null, "panel 'Tugas selesai' muncul")

	# Klik lanjut -> ronde 2 dari 5
	play._next_targets_round()
	_eq(play._round_idx, 1, "lanjut ke ronde ke-2")
	_eq(play._phase, "play", "ronde baru kembali ke fase play")
	_eq(play._elapsed, 0.0, "stopwatch ronde baru dimulai dari 0")
	_ok(play._round_done_layer == null, "panel ditutup saat lanjut")

	# Selesaikan sisa ronde -> hasil akhir
	for r in range(1, 5):
		for cell in play._cells.duplicate():
			if bool(cell.get("valid", false)):
				play._on_target_tap(cell, cell.get("_card"))
		if play._phase == "round_done":
			play._next_targets_round()
	_eq(play._phase, "result", "setelah 5 ronde tampil hasil")
	_ok(play._total_valid > 0, "akurasi dihitung dari akumulasi 5 ronde")
	_ok(GameState.field_task_played_today("tanam"), "tanam tercatat dimainkan hari ini")
	play.queue_free()

## Minigame tangkap: menangkap hama menambah skor, menangkap burung hantu/ayam
## dihitung salah.
func _test_catch_flow() -> void:
	GameState.start_new_game("pekerja_aktif")
	GameState.day = 800
	GameState.field_task_played = {}
	GameState.active_field_task = _task_by_id("inspeksi")

	var play = load("res://scenes/FieldTaskPlay.gd").new()
	add_child(play)
	_eq(play._mech, "catch", "inspeksi memakai mekanik catch")
	_eq(play._catch_need, 5, "perlu menangkap 5 hama")

	# Paksa ukuran layer lalu jalankan satu frame agar hama ter-spawn
	play._catch_layer.size = Vector2(360, 420)
	play._process(0.016)
	_eq(play._catch_items.size(), 7, "5 hama + 2 pengecoh di layar")

	# Array.filter() mengembalikan Array tanpa tipe -> wajib anotasi eksplisit,
	# ":=" akan gagal infer.
	var pests: Array = play._catch_items.filter(func(i): return String(i["kind"]) == "pest")
	var avoids: Array = play._catch_items.filter(func(i): return String(i["kind"]) == "avoid")
	_eq(pests.size(), 5, "5 hama bisa ditangkap")
	_eq(avoids.size(), 2, "2 pengecoh (burung hantu + ayam)")

	# Salah tangkap predator
	play._on_catch_tap(avoids[0])
	_eq(play._catch_wrong, 1, "menangkap predator dihitung salah")
	_eq(play._catch_caught, 0, "predator tidak menambah tangkapan")

	# Tangkap 4 hama -> belum selesai
	for i in 4:
		play._on_catch_tap(pests[i])
	_eq(play._catch_caught, 4, "4 hama tertangkap")
	_eq(play._phase, "play", "belum selesai sebelum 5 hama")

	# Hama ke-5 -> selesai, dan karena ada 1 salah bintangnya bukan 3
	play._on_catch_tap(pests[4])
	_eq(play._phase, "result", "selesai setelah 5 hama tertangkap")
	_eq(play._calc_stars(), 2, "1 kali salah -> 2 bintang, bukan 3")
	play.queue_free()

## Scene "Siklus Tanaman Kelapa Sawit" (RantaiPascapanen) memanjang di sumbu Z
## dan bergeser di X, jadi awannya harus dikonfigurasi mengikuti bentuk dunia.
func _test_pascapanen_clouds() -> void:
	GameState.start_new_game("pekerja_aktif")
	var scn = load("res://scenes/world/RantaiPascapanen.tscn")
	if scn == null:
		_fail.append("scene RantaiPascapanen tidak bisa dimuat")
		_n += 1
		return
	var node = scn.instantiate()
	add_child(node)
	var cf: CloudField = null
	for c in node.get_children():
		if c is CloudField:
			cf = c
	_ok(cf != null, "scene Siklus Tanaman memasang CloudField")
	if cf != null:
		_ok(cf.get_child_count() > 0, "awan ter-spawn di scene Siklus Tanaman")
		_ok(cf.center.z > 1.0, "pusat awan digeser ke tengah dunia memanjang (bukan origin)")
		_ok(cf.spread_z > cf.spread_x, "sebaran awan mengikuti dunia yang memanjang di Z")

	# D-pad pengubah PANDANGAN (bukan penggerak player)
	_ok(node._dpad != null, "scene Siklus Tanaman punya D-pad pandangan")
	if node._dpad != null:
		node._cam_busy = false

		# Kiri/kanan memutar pandangan
		var yaw0: float = node._orbit_yaw
		node._dpad._set_dir("right", true)
		node._apply_view_dpad(0.2)
		_ok(node._orbit_yaw > yaw0, "tombol kanan memutar pandangan ke kanan")
		node._dpad.release_all()

		var yaw1: float = node._orbit_yaw
		node._dpad._set_dir("left", true)
		node._apply_view_dpad(0.2)
		_ok(node._orbit_yaw < yaw1, "tombol kiri memutar ke arah sebaliknya")
		node._dpad.release_all()

		# Atas = maju (mendekat), bawah = mundur (menjauh)
		node._orbit_dist = 10.0
		node._dpad._set_dir("up", true)
		node._apply_view_dpad(0.2)
		_ok(node._orbit_dist < 10.0, "tombol atas = maju (jarak mengecil)")
		node._dpad.release_all()

		node._orbit_dist = 10.0
		node._dpad._set_dir("down", true)
		node._apply_view_dpad(0.2)
		_ok(node._orbit_dist > 10.0, "tombol bawah = mundur (jarak membesar)")
		node._dpad.release_all()

		# Jarak tidak boleh menembus batas orbit
		node._orbit_dist = 0.12
		node._dpad._set_dir("up", true)
		for i in 50:
			node._apply_view_dpad(0.2)
		_ok(node._orbit_dist >= 0.12 - 0.0001, "jarak minimum orbit dihormati")
		node._dpad.release_all()

		# Saat kamera sedang auto-travel antar zona, D-pad diabaikan
		node._cam_busy = true
		node._orbit_dist = 10.0
		node._dpad._set_dir("down", true)
		node._apply_view_dpad(0.2)
		_eq(node._orbit_dist, 10.0, "D-pad diabaikan saat kamera berpindah zona")
		node._dpad.release_all()
	node.queue_free()

func _test_dpad() -> void:
	var dp = load("res://scenes/world/TouchDPad.gd").new()
	add_child(dp)
	_eq(dp.get_child_count(), 4, "D-pad punya 4 tombol panah")
	_eq(dp.output, Vector2.ZERO, "awalnya diam")
	dp._set_dir("up", true)
	_eq(dp.output, Vector2(0, -1), "atas = -Y (maju)")
	dp._set_dir("up", false)
	dp._set_dir("right", true)
	_eq(dp.output, Vector2(1, 0), "kanan = +X")
	# Diagonal tidak boleh lebih cepat dari lurus
	dp._set_dir("down", true)
	_ok(abs(dp.output.length() - 1.0) < 0.001, "diagonal dinormalkan ke panjang 1")
	dp.release_all()
	_eq(dp.output, Vector2.ZERO, "release_all menghentikan gerak")
	dp.queue_free()
