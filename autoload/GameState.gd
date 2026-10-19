extends Node
## GameState (autoload)
## Menyimpan kondisi pemain: saldo, hari, profil, dan blok kebun.
## Save/load ke user:// (lokal, offline).

signal cash_changed(new_cash: int)
signal day_changed(new_day: int)
signal log_message(text: String)
signal blocks_changed()
signal objective_changed(key: String)
signal cosmetics_changed()

const SAVE_PATH := "user://savegame.json"
const SHARE_PATH := "user://kebun_share.json"

var cash: int = 0
var day: int = 1
var profile_id: String = "pekerja_aktif"
var weather: String = "cerah"
var blocks: Array = []  # tiap blok = Dictionary (lihat new_block())

# Misi awal / tutorial (action-based, menggantikan "7 hari pertama").
var objectives: Dictionary = _fresh_objectives()

func _fresh_objectives() -> Dictionary:
	return { "planted": false, "advanced": false, "fertilized": false, "sprayed": false, "harvested": false }

# --- Kosmetik (Fase 6, murni visual) ---
var kebun_name: String = "Kebun Saya"
var cosmetics_owned: Array = []        # id yang dimiliki
var cosmetics_applied: Dictionary = {} # kategori -> id yang dipakai
# --- Kunjungan (multiplayer asinkron) ---
var visiting: Dictionary = {}          # snapshot kebun yang sedang dikunjungi (kosong = main sendiri)
# --- Alur cerita / run-state ---
var story_flags: Dictionary = {}       # jalur, tipe_lahan, lahan_id, dll (lihat decision_tree.md)
var land_acquired: bool = false        # lahan sudah dibeli lewat cerita? (jangan tagih lagi di Main)
var land_class: String = "S1"          # kelas lahan yang dibeli -> production_standard
# --- Kebun 9 plot (Dashboard 3x3). state: kosong|buka|siap|tanam ---
var plots: Array = []
var active_plot: int = 0                # plot yang sedang dimasuki di mode lapangan 3D

func first_planted_index() -> int:
	for i in plots.size():
		if plots[i].get("state") == "tanam":
			return i
	return -1

func active_block() -> Dictionary:
	var idx := active_plot
	if idx < 0 or idx >= plots.size() or plots[idx].get("state") != "tanam":
		idx = first_planted_index()
	if idx < 0:
		# Tak ada tanaman -> tanam cepat di plot 0 agar mode lapangan tetap jalan.
		plant_plot(0, "marihat_ppks")
		plots[0]["planting_day"] = day - 5 * 365
		idx = 0
	active_plot = idx
	return plots[idx]

func _fresh_plots() -> Array:
	var a: Array = []
	for i in 9:
		a.append({ "id": "B%d" % (i + 1), "state": "kosong" })
	return a

## Kebun awal demo (agar hub terlihat hidup): 3 tanam + 1 siap + 1 buka + 4 kosong.
func _seed_start_plots() -> Array:
	var a := _fresh_plots()
	var specs := [
		{ "i": 0, "seed": "marihat_ppks", "age": 8, "weed": 0.2, "pest": null, "golden": 3 },
		{ "i": 1, "seed": "fr", "age": 5, "weed": 0.55, "pest": null, "golden": 1 },
		{ "i": 2, "seed": "damimas", "age": 3, "weed": 0.3,
		  "pest": { "id": "ulat_api", "level": 0.45, "diagnosed": false }, "golden": 0 },
	]
	for s in specs:
		var b := new_block(1.0, s["seed"], land_class)
		b["state"] = "tanam"
		b["id"] = "B%d" % (int(s["i"]) + 1)
		b["planting_day"] = day - int(s["age"]) * 365
		b["last_harvest_day"] = day - 20
		b["last_fertilize_day"] = day - 30
		b["weed_level"] = s["weed"]
		b["pest"] = s["pest"]
		b["golden_count"] = s["golden"]
		b["health"] = 0.9
		a[int(s["i"])] = b
	a[3] = { "id": "B4", "state": "siap" }
	a[4] = { "id": "B5", "state": "buka", "clear": 18, "clear0": 30 }
	return a

const SEEDS_PER_HA := 143

## Harga bibit jadi per batang (beli dari luar): kecambah x faktor pembibitan.
func bibit_price(seed: Dictionary) -> int:
	var f := float(npar().get("bibit_price_factor", 4.0))
	return int(round(float(seed.get("price_per_seed_rp", 0)) * f))

## Tanam blok dengan BELI BIBIT JADI (langsung tanam, lebih mahal).
## Kecambah tidak bisa ditanam langsung ke lapangan — harus lewat pembibitan 12 bulan.
func plant_plot(i: int, seed_id: String) -> bool:
	var seed := Database.get_seed(seed_id)
	var cost := bibit_price(seed) * SEEDS_PER_HA
	if not spend(cost, "Beli bibit jadi %s ×%d" % [seed.get("variety_name", "?"), SEEDS_PER_HA]):
		return false
	return _plant(i, seed_id)

## Tanam blok dari BIBITAN SENDIRI (bibit siap umur 12 bulan).
func plant_from_nursery(i: int) -> bool:
	if String(nursery.get("stage", "")) != "siap":
		log_msg("Bibit belum siap tanam (butuh umur 12 bulan + seleksi final).")
		return false
	if int(nursery.get("qty", 0)) < SEEDS_PER_HA:
		log_msg("Bibit kurang: butuh %d, sisa %d." % [SEEDS_PER_HA, int(nursery.get("qty", 0))])
		return false
	var seed_id := String(nursery.get("seed_id", ""))
	if not _plant(i, seed_id):
		return false
	nursery["qty"] = int(nursery["qty"]) - SEEDS_PER_HA
	log_msg("Tanam %d bibit dari bibitan sendiri ke %s. Sisa bibit: %d." % [
		SEEDS_PER_HA, plots[i].get("id", "?"), int(nursery["qty"])])
	if int(nursery["qty"]) <= 0:
		nursery = {}
		log_msg("Bibitan selesai — semua bibit terpakai. Bisa mulai siklus pembibitan baru.")
	emit_signal("blocks_changed")
	return true

func _plant(i: int, seed_id: String) -> bool:
	if i < 0 or i >= plots.size():
		return false
	var seed := Database.get_seed(seed_id)
	var lc := String(plots[i].get("land_class", land_class))
	var b := new_block(1.0, seed_id, lc)
	b["state"] = "tanam"
	b["id"] = "B%d" % (i + 1)
	# Golden Tree di-roll saat tanam (hanya benih bersertifikat).
	var golden := 0
	if seed.get("golden_eligible", false):
		for j in SEEDS_PER_HA:
			if randf() < float(seed.get("golden_base_probability", 0.0)):
				golden += 1
	b["golden_count"] = golden
	plots[i] = b
	emit_signal("blocks_changed")
	return true

# ---------------------------------------------------------------- TPH (SOP Panen & Transport)
# Buah hasil potong dikumpulkan ke TPH, lalu WAJIB diangkut ke PKS pada hari yang
# sama ("Zero Restan"). Buah restan = dikirim di hari berbeda -> mutu (FFA) turun.
var tph: Dictionary = {}   # {"kg": float, "day": int, "seed_id": String, "health": float}

func tph_kg() -> float:
	return float(tph.get("kg", 0.0))

func tph_restan_days() -> int:
	if tph.is_empty():
		return 0
	return max(0, day - int(tph.get("day", day)))

## Faktor harga akibat restan (SOP transport: FFA naik bila buah menginap).
func tph_restan_factor() -> float:
	return clampf(1.0 - 0.04 * float(tph_restan_days()), 0.75, 1.0)

func tph_deposit(kg: float, seed_id: String, health: float) -> void:
	if tph.is_empty():
		tph = { "kg": 0.0, "day": day, "seed_id": seed_id, "health": health }
	tph["kg"] = float(tph["kg"]) + kg
	emit_signal("blocks_changed")

func tph_clear() -> void:
	tph = {}
	emit_signal("blocks_changed")

## Dipanggil TimeManager tiap hari — peringatan buah restan.
func tick_tph() -> void:
	if tph_kg() > 0.0 and tph_restan_days() > 0:
		log_msg("⚠ Buah RESTAN di TPH %.0f kg (%d hari) — mutu turun %.0f%%. Segera angkut ke PKS!" % [
			tph_kg(), tph_restan_days(), (1.0 - tph_restan_factor()) * 100.0])

# ---------------------------------------------------------------- Pembibitan
# Tahapan (dok. "Tahapan Proses membuka pembibitan sampai bibit siap tanam"):
#  pesan (1 bln) -> kecambah datang: seleksi 2% -> PN -> siapkan MN (wajib umur 2 bln)
#  -> umur 3 bln (3 daun): transplanting ke MN + seleksi PN 2%
#  -> seleksi MN umur 6 & 9 bln (2%) -> umur 12 bln: seleksi final 2% = bibit siap.
# Perawatan (siram 2x/hari, pupuk, hama) = biaya bulanan otomatis.
var nursery: Dictionary = {}   # kosong = belum ada bibitan

func npar() -> Dictionary:
	return Database.params.get("nursery", {})

## Umur bibit dalam bulan (sejak kecambah ditanam ke PN).
func nursery_age_months() -> int:
	if nursery.is_empty() or int(nursery.get("plant_day", -1)) < 0:
		return 0
	return int((day - int(nursery["plant_day"])) / 30)

func order_kecambah(seed_id: String, qty: int) -> String:
	if not nursery.is_empty():
		return "Bibitan masih berjalan — selesaikan dulu siklus ini."
	var seed := Database.get_seed(seed_id)
	var p := npar()
	var cost_seed := int(seed.get("price_per_seed_rp", 0)) * qty
	var cost_prep := int(p.get("prep_pn_cost_rp", 1500000))
	if not spend(cost_seed + cost_prep, "Pesan %d kecambah + persiapan areal bibitan" % qty):
		return "Dana tidak cukup (butuh Rp%s)." % _fmt(cost_seed + cost_prep)
	nursery = { "seed_id": seed_id, "qty0": qty, "qty": qty, "stage": "pesan",
		"order_day": day, "plant_day": -1, "mn_prepared": false,
		"sel_months": [], "paid_months": 0, "warned_mn": false }
	log_msg("Kecambah %s ×%d dipesan (tiba ±%d hari). Persiapan areal: pompa air, pipa saluran, media tanah, polybag kecil (PN), naungan." % [
		seed.get("variety_name", "?"), qty, int(p.get("order_days", 30))])
	emit_signal("blocks_changed")
	return "Pesanan dibuat — kecambah tiba ±%d hari." % int(p.get("order_days", 30))

## Siapkan media tanah + polybag besar untuk Main Nursery (wajib sebelum umur 3 bln).
func prepare_mn() -> String:
	if nursery.is_empty() or String(nursery.get("stage", "")) != "pn":
		return "Belum di tahap Pre Nursery."
	if bool(nursery.get("mn_prepared", false)):
		return "Main Nursery sudah disiapkan."
	var cost := int(npar().get("prep_mn_cost_rp", 2000000))
	if not spend(cost, "Persiapan Main Nursery (media tanah + polybag besar)"):
		return "Dana tidak cukup (Rp%s)." % _fmt(cost)
	nursery["mn_prepared"] = true
	log_msg("Media tanah & polybag besar Main Nursery disiapkan.")
	emit_signal("blocks_changed")
	return "Main Nursery siap — transplanting otomatis saat bibit umur 3 bulan (3 daun)."

## Jual bibit siap tanam ke pelanggan.
func sell_bibit(qty: int) -> String:
	if String(nursery.get("stage", "")) != "siap":
		return "Belum ada bibit siap jual."
	qty = min(qty, int(nursery.get("qty", 0)))
	if qty <= 0:
		return "Jumlah tidak valid."
	var price := int(npar().get("bibit_sell_price_rp", 35000))
	earn(price * qty, "Jual %d bibit siap tanam" % qty)
	nursery["qty"] = int(nursery["qty"]) - qty
	var msg := "Terjual %d bibit @ Rp%s = Rp%s." % [qty, _fmt(price), _fmt(price * qty)]
	log_msg(msg)
	if int(nursery["qty"]) <= 0:
		nursery = {}
		log_msg("Bibitan selesai — semua bibit terjual. Bisa mulai siklus baru.")
	emit_signal("blocks_changed")
	return msg

## Seleksi: sisihkan `rate` (dibulatkan ke atas) — abnormal/busuk/mati/double tone.
func _nursery_cull(rate: float, what: String) -> void:
	var n := int(ceil(float(nursery.get("qty", 0)) * rate))
	nursery["qty"] = max(0, int(nursery.get("qty", 0)) - n)
	log_msg("Seleksi %s: %d bibit disisihkan (abnormal/busuk/double tone), sisa %d." % [
		what, n, int(nursery["qty"])])

## Biaya perawatan bulanan: penyiraman 2x/hari + pupuk + pengendalian hama.
func _nursery_maintenance() -> void:
	var p := npar()
	var m := nursery_age_months()
	while int(nursery.get("paid_months", 0)) < m:
		nursery["paid_months"] = int(nursery.get("paid_months", 0)) + 1
		var c := int(ceil(float(nursery.get("qty", 0)) / 100.0)) * int(p.get("maintenance_rp_per_100_per_month", 50000))
		if cash >= c:
			spend(c, "Perawatan bibitan bln %d (siram 2x/hari, pupuk, hama)" % int(nursery["paid_months"]))
		else:
			_nursery_cull(float(p.get("selection_rate", 0.02)), "bibit terlantar (perawatan tak terbayar)")

## Dipanggil TimeManager tiap hari.
func tick_nursery() -> void:
	if nursery.is_empty():
		return
	var p := npar()
	var rate := float(p.get("selection_rate", 0.02))
	match String(nursery.get("stage", "")):
		"pesan":
			if day - int(nursery.get("order_day", day)) >= int(p.get("order_days", 30)):
				nursery["stage"] = "pn"
				nursery["plant_day"] = day
				_nursery_cull(rate, "kecambah saat diterima")
				log_msg("Kecambah datang → dicatat & ditanam ke media polybag kecil (Pre Nursery). Wajib siram pagi & sore.")
				emit_signal("blocks_changed")
		"pn":
			var m := nursery_age_months()
			if m >= int(p.get("mn_prep_due_month", 2)) and not bool(nursery.get("mn_prepared", false)) and not bool(nursery.get("warned_mn", false)):
				nursery["warned_mn"] = true
				log_msg("⚠ Bibit umur %d bulan — WAJIB siapkan media & polybag besar Main Nursery sebelum umur 3 bulan!" % m)
			if m >= int(p.get("pn_to_mn_month", 3)) and bool(nursery.get("mn_prepared", false)):
				nursery["stage"] = "mn"
				_nursery_cull(rate, "transplanting ke Main Nursery (umur 3 bln / 3 daun)")
				log_msg("Transplanting ke polybag besar (Main Nursery) selesai.")
				emit_signal("blocks_changed")
			_nursery_maintenance()
		"mn":
			var m2 := nursery_age_months()
			var done: Array = nursery.get("sel_months", [])
			for sm in p.get("selection_points_mn", [6, 9]):
				if m2 >= int(sm) and not done.has(int(sm)):
					done.append(int(sm))
					nursery["sel_months"] = done
					_nursery_cull(rate, "MN umur %d bulan" % int(sm))
			if m2 >= int(p.get("ready_month", 12)):
				_nursery_cull(rate, "final — hanya bibit berkualitas yang lolos")
				nursery["stage"] = "siap"
				log_msg("🌱 Bibit SIAP umur 12 bulan: %d batang berkualitas — bisa ditanam ke blok atau dijual." % int(nursery["qty"]))
				emit_signal("blocks_changed")
			_nursery_maintenance()

func _ready() -> void:
	cash = int(Database.params.get("base_capital_rp", 100000000))

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func start_new_game(pid: String) -> void:
	profile_id = pid
	cash = int(Database.params.get("base_capital_rp", 100000000))
	day = 1
	weather = "cerah"
	blocks = []
	objectives = _fresh_objectives()
	kebun_name = "Kebun Saya"
	cosmetics_owned = Database.free_cosmetic_ids()
	cosmetics_applied = _default_applied()
	visiting = {}
	story_flags = {}
	land_acquired = false
	land_class = "S1"
	plots = _fresh_plots()           # mulai kosong; lahan awal datang dari Cerita (apply_story)
	inv = _seed_inv()
	ledger = []
	nursery = {}
	tph = {}

var buy_target_plot: int = 0         # slot yang sedang dibeli di Pasar Lahan
# --- Pedagang: gudang (inv) + harga harian ---
var inv: Array = []

func _seed_inv() -> Array:
	var a: Array = []
	for it in Database.merchant_inventory:
		if it.has("id"):
			a.append(it.duplicate(true))
	return a

## Tren harga harian ±6%, deterministik per item per hari.
func market_trend(id: String) -> float:
	var h: int = (id + "#" + str(day)).hash()
	return (float(abs(h) % 1000) / 1000.0 - 0.5) * 0.12

func price_today(base: int, id: String) -> int:
	return int(round(float(base) * (1.0 + market_trend(id))))

func buy_item(item_id: String, qty: int) -> String:
	var st := {}
	for s in Database.merchant_stock:
		if s.get("id") == item_id: st = s; break
	if st.is_empty():
		return "Barang tak tersedia."
	var unit := price_today(int(st.get("price", 0)), item_id)
	if not spend(unit * qty, "Beli %s ×%d" % [st.get("name", "?"), qty]):
		return "Dana tidak cukup (Rp%s)." % _fmt(unit * qty)
	var sell_base := int(round(float(st.get("price", 0)) * 0.85))
	var found := false
	for it in inv:
		if it.get("id") == item_id:
			it["qty"] = int(it.get("qty", 0)) + qty; found = true; break
	if not found:
		inv.append({ "id": item_id, "name": st.get("name"), "cat": st.get("cat"),
			"note": st.get("note", ""), "unit": st.get("unit", "unit"), "price": sell_base, "qty": qty })
	emit_signal("cosmetics_changed")
	return "Beli %d %s %s — Rp%s." % [qty, st.get("unit", ""), st.get("name"), _fmt(unit * qty)]

func sell_item(item_id: String, qty: int) -> String:
	var it := {}
	for x in inv:
		if x.get("id") == item_id: it = x; break
	if it.is_empty() or int(it.get("qty", 0)) < qty:
		return "Stok gudang tidak cukup."
	var unit := price_today(int(it.get("price", 0)), item_id)
	it["qty"] = int(it.get("qty", 0)) - qty
	if int(it["qty"]) <= 0:
		inv.erase(it)
	earn(unit * qty, "Jual %s ×%d" % [it.get("name", "?"), qty])
	emit_signal("cosmetics_changed")
	return "Jual %d %s %s — Rp%s." % [qty, it.get("unit", ""), it.get("name"), _fmt(unit * qty)]

## Masuk ke gudang TANPA dibayar (hasil pungut di sabuk hutan, beda dgn
## buy_item yang membayar pedagang). Metadata (nama/kategori/harga jual dasar)
## diambil dari katalog Database.merchant_inventory via id.
func collect_item(item_id: String, qty: int = 1) -> String:
	var meta := Database.get_merchant_item(item_id)
	if meta.is_empty():
		return ""
	var found := false
	for it in inv:
		if it.get("id") == item_id:
			it["qty"] = int(it.get("qty", 0)) + qty
			found = true
			break
	if not found:
		inv.append({ "id": item_id, "name": meta.get("name"), "cat": meta.get("cat"),
			"note": meta.get("note", ""), "unit": meta.get("unit", "unit"),
			"price": int(meta.get("price", 0)), "qty": qty })
	emit_signal("cosmetics_changed")
	return "🌿 Dapat %d %s %s — masuk gudang, bisa dijual ke Pedagang." % [qty, meta.get("unit", ""), meta.get("name", "?")]

func warehouse_value() -> int:
	var v := 0
	for it in inv:
		v += price_today(int(it.get("price", 0)), String(it.get("id", ""))) * int(it.get("qty", 0))
	return v

## Isi kebun demo (untuk masuk Dashboard tanpa alur cerita / testing).
func seed_demo_kebun() -> void:
	plots = _seed_start_plots()
	emit_signal("blocks_changed")

## Beli lahan dari Pasar Lahan untuk slot `idx`.
func buy_land(offer_id: String, idx: int) -> String:
	if idx < 0 or idx >= plots.size():
		return "Slot tidak valid."
	var lo := Database.get_land_offer(offer_id)
	if lo.is_empty():
		return "Lahan tak ditemukan."
	var price := int(lo.get("price_rp", 0))
	var clearing := int(Database.params.get("clearing_cost_rp", 0)) if bool(lo.get("needs_clearing", false)) else 0
	if not spend(price + clearing, "Beli lahan %s" % lo.get("name", "?")):
		return "Dana tidak cukup (butuh Rp%s)." % _fmt(price + clearing)
	_fill_plot_from_land(idx, lo)
	emit_signal("blocks_changed")
	return "%s dibeli untuk %s." % [lo.get("name", "Lahan"), plots[idx].get("id")]

func _fill_plot_from_land(idx: int, lo: Dictionary) -> void:
	var lc := String(lo.get("land_class", "S1"))
	var id := "B%d" % (idx + 1)
	if bool(lo.get("needs_clearing", false)):
		var d := int(Database.params.get("clearing_days", 30))
		plots[idx] = { "id": id, "state": "buka", "land_class": lc, "clear": d, "clear0": d }
	else:
		plots[idx] = { "id": id, "state": "siap", "land_class": lc }
	# Atribut penilaian kelas lahan (lereng/tanah/air) ikut tersimpan di plot.
	if lo.has("assess"):
		plots[idx]["assess"] = (lo.get("assess") as Dictionary).duplicate()

## Atribut penilaian sebuah plot; fallback profil tipikal per kelas bila tidak ada.
func plot_assessment(p: Dictionary) -> Dictionary:
	if p.has("assess"):
		return p.get("assess")
	var dflt: Dictionary = Database.land_assessment.get("default_assess", {})
	return dflt.get(String(p.get("land_class", "S1")), { "lereng": 3.0, "tanah": "mineral", "gambut_m": 0.0, "air": "normal" })

## Kelas lahan dominan kebun (modus blok dimiliki; seri -> kelas terberat).
func dominant_land_class() -> String:
	var count := { "S1": 0, "S2": 0, "S3": 0 }
	for p in plots:
		if p.get("state", "kosong") != "kosong":
			var lc := String(p.get("land_class", "S1"))
			count[lc] = int(count.get(lc, 0)) + 1
	var best := ""
	var best_n := 0
	for lc in ["S3", "S2", "S1"]:   # urutan terberat dulu -> seri dimenangkan kelas terberat
		if int(count[lc]) > best_n:
			best = lc
			best_n = int(count[lc])
	return best

## Terapkan hasil pilihan cerita ke run-state (dipanggil di akhir alur cerita).
func apply_story(flags: Dictionary) -> void:
	story_flags = flags.duplicate()
	land_acquired = true
	land_class = String(flags.get("land_class", "S1"))
	var price := int(flags.get("land_price", 0))
	if price > 0:
		cash = max(0, cash - price)
		emit_signal("cash_changed", cash)
	# Lahan dari cerita menjadi blok pertama (B1): hutan -> buka, bersih -> siap.
	var lo := Database.get_land_offer(String(flags.get("lahan_id", "")))
	if lo.is_empty():
		lo = { "land_class": land_class, "needs_clearing": bool(flags.get("needs_clearing", false)) }
	if not plots.is_empty():
		_fill_plot_from_land(0, lo)
	emit_signal("blocks_changed")
	log_msg("Lahan: %s (kelas %s)%s. Sisa modal Rp%s." % [
		flags.get("lahan_name", "-"), land_class,
		"  — perlu dibuka dulu" if flags.get("needs_clearing", false) else "",
		_fmt(cash)])
	match String(flags.get("bibit", "")):
		"sendiri":
			log_msg("Rencana bibit: BIBITKAN SENDIRI — pesan kecambah lewat panel Pembibitan di Dashboard (siap ±13 bulan).")
		"beli":
			log_msg("Rencana bibit: BELI BIBIT JADI — tanam langsung dari blok berstatus 'Lahan siap'.")

func _default_applied() -> Dictionary:
	var d := {}
	for id in Database.free_cosmetic_ids():
		var c := Database.get_cosmetic(String(id))
		d[String(c.get("category"))] = id
	return d

# ---- Kosmetik (semua murni visual; tidak ada efek gameplay) ----
func is_owned(id: String) -> bool:
	return cosmetics_owned.has(id)

func buy_cosmetic(id: String) -> bool:
	var c := Database.get_cosmetic(id)
	if c.is_empty() or is_owned(id):
		return false
	if not spend(int(c.get("price_rp", 0)), "Kosmetik %s" % c.get("name", "?")):
		return false
	cosmetics_owned.append(id)
	emit_signal("cosmetics_changed")
	log_msg("Beli kosmetik: %s (visual saja — tak memengaruhi gameplay)." % c.get("name"))
	return true

func apply_cosmetic(id: String) -> void:
	var c := Database.get_cosmetic(id)
	if c.is_empty() or not is_owned(id):
		return
	cosmetics_applied[String(c.get("category"))] = id
	emit_signal("cosmetics_changed")

func character_model() -> String:
	var c := Database.get_cosmetic(String(cosmetics_applied.get("kostum", "")))
	var m := String(c.get("model", ""))
	return m if m != "" else "res://assets/models/character/human.glb"

func vehicle_model() -> String:
	var c := Database.get_cosmetic(String(cosmetics_applied.get("kendaraan", "")))
	return String(c.get("model", ""))

func applied_accent() -> Color:
	var c := Database.get_cosmetic(String(cosmetics_applied.get("tema_ui", "")))
	return Color.html(String(c.get("payload", {}).get("accent", "2e7d32")))

func kebun_badge() -> String:
	var c := Database.get_cosmetic(String(cosmetics_applied.get("identitas", "")))
	return String(c.get("payload", {}).get("badge", ""))

## Nama klip animasi utk emote yg sedang dipakai (lihat Player3D.do_emote()).
## Dicocokkan via substring thd klip model kostum yg aktif -> kalau kostum yg
## dipakai tak punya klip serupa, otomatis diam (aman, lihat catatan di katalog).
func applied_emote_anim_key() -> String:
	var c := Database.get_cosmetic(String(cosmetics_applied.get("emote", "")))
	var k := String(c.get("payload", {}).get("anim_key", ""))
	return k if k != "" else "Working"

func display_kebun_name() -> String:
	return ("%s %s" % [kebun_badge(), kebun_name]).strip_edges()

# ---- Kunjungan kebun (multiplayer asinkron via snapshot) ----
func export_kebun() -> void:
	var snap := { "kebun_name": kebun_name, "blocks": blocks,
		"cosmetics_applied": cosmetics_applied, "profile_id": profile_id }
	var f := FileAccess.open(SHARE_PATH, FileAccess.WRITE)
	if f == null:
		log_msg("Gagal ekspor kebun.")
		return
	f.store_string(JSON.stringify(snap, "\t"))
	f.close()
	log_msg("Kebun diekspor ke %s — bagikan file ini agar teman bisa berkunjung." % SHARE_PATH)

func start_visit(path: String = "") -> bool:
	var p := path if path != "" else SHARE_PATH
	if not FileAccess.file_exists(p):
		log_msg("Snapshot kunjungan tak ditemukan. Ekspor dulu.")
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(p))
	if not (data is Dictionary):
		log_msg("Snapshot kunjungan rusak.")
		return false
	visiting = data
	return true

func end_visit() -> void:
	visiting = {}

func mark_objective(key: String) -> void:
	if objectives.get(key, true) == false:
		objectives[key] = true
		emit_signal("objective_changed", key)

func profile_mods() -> Dictionary:
	return Database.get_profile(profile_id).get("modifiers", {})

## Horison prakiraan cuaca (hari) sesuai profil — buff Nadia memperpanjang ini.
func forecast_days() -> int:
	return int(profile_mods().get("weather_forecast_days",
		Database.params.get("weather_forecast_days_default", 1)))

func log_msg(text: String) -> void:
	emit_signal("log_message", text)
	print("[Game] " + text)

# --- Ekonomi ---
# Buku kas untuk layar Laporan: {d: hari, t: keterangan, a: jumlah (keluar = negatif)}.
var ledger: Array = []

func spend(amount: int, note := "") -> bool:
	if amount > cash:
		log_msg("Dana tidak cukup. Butuh Rp%s, saldo Rp%s." % [_fmt(amount), _fmt(cash)])
		return false
	cash -= amount
	if amount != 0:
		ledger.append({ "d": day, "t": note if note != "" else "Pengeluaran", "a": -amount })
	emit_signal("cash_changed", cash)
	return true

func earn(amount: int, note := "Pemasukan") -> void:
	cash += amount
	if amount != 0:
		ledger.append({ "d": day, "t": note, "a": amount })
	emit_signal("cash_changed", cash)

# --- Blok kebun ---
func new_block(area_ha: float, seed_id: String, land_class: String) -> Dictionary:
	return {
		"id": "blok_%d" % (blocks.size() + 1),
		"area_ha": area_ha,
		"seed_id": seed_id,
		"land_class": land_class,
		"planting_day": day,
		"last_harvest_day": day,
		"last_fertilize_day": day,
		"weed_level": 0.0,
		"pest": null,
		"health": 1.0
	}

func add_block(block: Dictionary) -> void:
	blocks.append(block)
	emit_signal("blocks_changed")

func age_years_of(block: Dictionary) -> int:
	var dpy := int(Database.params.get("days_per_year", 365))
	return int((day - int(block.get("planting_day", day))) / dpy)

# --- Save / Load ---
func save_game() -> void:
	var data := {
		"version": 6, "cash": cash, "day": day, "profile_id": profile_id,
		"weather": weather, "blocks": blocks, "objectives": objectives,
		"kebun_name": kebun_name, "cosmetics_owned": cosmetics_owned,
		"cosmetics_applied": cosmetics_applied,
		"story_flags": story_flags, "land_acquired": land_acquired, "land_class": land_class,
		"plots": plots, "inv": inv, "ledger": ledger, "nursery": nursery, "tph": tph
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		log_msg("Gagal menyimpan.")
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	log_msg("Game disimpan.")

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		log_msg("Belum ada save.")
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data == null:
		log_msg("Save rusak.")
		return false
	cash = int(data.get("cash", cash))
	day = int(data.get("day", day))
	profile_id = str(data.get("profile_id", profile_id))
	weather = str(data.get("weather", weather))
	blocks = data.get("blocks", [])
	var obj = data.get("objectives", _fresh_objectives())
	objectives = obj if obj is Dictionary else _fresh_objectives()
	kebun_name = str(data.get("kebun_name", "Kebun Saya"))
	var owned = data.get("cosmetics_owned", Database.free_cosmetic_ids())
	cosmetics_owned = owned if owned is Array else Database.free_cosmetic_ids()
	var appl = data.get("cosmetics_applied", _default_applied())
	cosmetics_applied = appl if appl is Dictionary else _default_applied()
	var sf = data.get("story_flags", {})
	story_flags = sf if sf is Dictionary else {}
	land_acquired = bool(data.get("land_acquired", false))
	land_class = str(data.get("land_class", "S1"))
	var pl = data.get("plots", _fresh_plots())
	plots = pl if (pl is Array and pl.size() == 9) else _seed_start_plots()
	var iv2 = data.get("inv", _seed_inv())
	inv = iv2 if iv2 is Array else _seed_inv()
	var lg = data.get("ledger", [])
	ledger = lg if lg is Array else []
	var nr = data.get("nursery", {})
	nursery = nr if nr is Dictionary else {}
	var tp = data.get("tph", {})
	tph = tp if tp is Dictionary else {}
	visiting = {}
	emit_signal("cosmetics_changed")
	emit_signal("cash_changed", cash)
	emit_signal("day_changed", day)
	emit_signal("blocks_changed")
	log_msg("Game dimuat.")
	return true

func _fmt(n: int) -> String:
	# Format ribuan sederhana: 1000000 -> 1.000.000
	var s := str(abs(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i != 0:
			out = "." + out
	return ("-" if n < 0 else "") + out
