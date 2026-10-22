class_name Agronomy
extends RefCounted
## Fase 2 — mesin aturan budidaya.
## Menghitung kebutuhan pupuk & semprot dari data workbook (fertilizer_standard,
## control_standard, product_catalog) lalu menerapkan efek ke health & weed blok.
## Semua fungsi statis; mengakses autoload Database/GameState/TimeManager by name.

# ---------------------------------------------------------------- Pemupukan
static func fertilizer_plan(block: Dictionary) -> Dictionary:
	var age := _clamp_fert_age(GameState.age_years_of(block), block.get("land_class", "S1"))
	var lc := String(block.get("land_class", "S1"))
	var area := float(block.get("area_ha", 1.0))
	var rows := Database.get_fertilizer(age, lc)
	var comps: Array = []
	var total := 0.0
	for r in rows:
		var kg: float = float(r.get("kg_ha_year", 0.0)) * area
		var price := _fert_price(String(r.get("fertilizer_code", "")))
		var cost: float = kg * price
		total += cost
		comps.append({ "code": r.get("fertilizer_code"), "kg": kg, "price_per_kg": price, "cost": cost })
	return { "age_used": age, "components": comps, "total_cost": int(round(total)) }

# ---------------------------------------------------------------- Semprot gulma
static func spray_plan(block: Dictionary, location: String, organism: String) -> Dictionary:
	var age := GameState.age_years_of(block)
	var area := float(block.get("area_ha", 1.0))
	var recs := Database.get_control(age, location, organism)
	if recs.is_empty():
		return { "found": false, "components": [], "total_cost": 0, "water_l": 0.0, "tanks": 0 }
	# Satu rekomendasi bisa punya beberapa komponen (mix_option sama). Ambil grup pertama.
	var mix = recs[0].get("mix_option")
	var group := recs.filter(func(r): return r.get("mix_option") == mix)
	var comps: Array = []
	var total := 0.0
	var vol_ha := 0.0
	for r in group:
		var dose_ha: float = float(r.get("dose_value", 0.0))
		var unit := String(r.get("dose_unit", ""))
		var qty := dose_ha * area                       # ml atau g untuk seluruh luas
		var qty_product_unit := qty / 1000.0 if unit in ["ml", "g"] else qty  # -> Liter/Kg
		var product := Database.cheapest_product(String(r.get("active_ingredient", "")))
		var price: float = float(product.get("price", 0.0)) if not product.is_empty() else 0.0
		var cost: float = qty_product_unit * price
		total += cost
		vol_ha = max(vol_ha, (float(r.get("water_l_ha_min", 0)) + float(r.get("water_l_ha_max", 0))) / 2.0)
		comps.append({
			"active_ingredient": r.get("active_ingredient"),
			"trade_name": product.get("trade_name", "(tak ada harga)"),
			"qty": qty_product_unit, "unit": ("L" if unit == "ml" else ("Kg" if unit == "g" else unit)),
			"price": price, "cost": cost,
			"validation_status": r.get("validation_status", "")
		})
	var water := vol_ha * area
	var tank_cap := float(Database.params.get("tank_capacity_l", 15))
	return {
		"found": true, "location": location, "organism": organism,
		"components": comps, "total_cost": int(round(total)),
		"water_l": water, "tanks": int(ceil(water / tank_cap))
	}

# ---------------------------------------------------------------- Efek ke blok
static func apply_fertilize(block: Dictionary) -> void:
	block["last_fertilize_day"] = GameState.day
	var hist: Array = block.get("fertilize_history", [])
	hist.append(GameState.day)
	block["fertilize_history"] = hist
	var rec := float(Database.params.get("fertilize_health_recovery", 0.10))
	block["health"] = min(1.0, float(block.get("health", 1.0)) + rec)

## Berapa kali blok ini dipupuk dlm 365 hari terakhir (window bergulir, bukan
## tahun kalender tetap — dipakai utk batas bawah produksi TM, lihat tbs_batch_kg).
static func fertilize_count_last_year(block: Dictionary) -> int:
	var hist: Array = block.get("fertilize_history", [])
	var dpy := float(Database.params.get("days_per_year", 365))
	var cutoff := GameState.day - int(dpy)
	var n := 0
	for d in hist:
		if int(d) > cutoff:
			n += 1
	return n

static func apply_spray(block: Dictionary, effectiveness: float) -> void:
	block["weed_level"] = clamp(float(block.get("weed_level", 0.0)) * (1.0 - effectiveness), 0.0, 1.0)
	var rec := float(Database.params.get("spray_health_recovery", 0.12))
	block["health"] = min(1.0, float(block.get("health", 1.0)) + rec * effectiveness)

# Efektivitas = base x cuaca x (diagnosis benar ? (1+bonus_profil) : 0.6).
static func spray_effectiveness(correct_diagnosis: bool) -> float:
	var base := float(Database.params.get("spray_base_effectiveness", 0.80))
	var wfac := float(Database.params.get("weather_spray_factor", {}).get(GameState.weather, 1.0))
	var mods := GameState.profile_mods()
	var bonus := float(mods.get("treatment_effectiveness_bonus", 0.0)) if mods.get("requires_correct_diagnosis", false) else 0.0
	var diag := (1.0 + bonus) if correct_diagnosis else 0.6
	return clamp(base * wfac * diag, 0.0, 1.0)

# ---------------------------------------------------------------- Hama/penyakit
static func tick_pest(block: Dictionary) -> void:
	var age := GameState.age_years_of(block)
	var pest = block.get("pest")
	if pest == null:
		_maybe_spawn(block, age)
		return
	var cat := Database.get_pest(String(pest.get("id", "")))
	pest["level"] = min(1.0, float(pest.get("level", 0.0)) + float(Database.params.get("pest_level_growth_per_day", 0.02)))
	var dmg := float(Database.params.get("pest_damage_per_day", 0.012)) * float(pest.get("level", 0.0)) * float(cat.get("damage_mult", 1.0))
	dmg *= _tolerance_factor(block, cat)
	block["health"] = clamp(float(block.get("health", 1.0)) - dmg, 0.1, 1.0)

static func _maybe_spawn(block: Dictionary, age: int) -> void:
	for cat in Database.eligible_pests(age):
		var chance := float(cat.get("appear_chance_per_day", 0.0))
		chance *= float(cat.get("weather_bias", {}).get(GameState.weather, 1.0))
		chance *= _tolerance_factor(block, cat)
		if randf() < chance:
			block["pest"] = { "id": cat.get("id"), "level": 0.12, "diagnosed": false }
			GameState.log_msg("⚠ %s: gejala muncul — \"%s\" (perlu INSPEKSI utk diagnosis)." % [
				block.get("id"), cat.get("symptom", "?")])
			GameState.emit_signal("pest_appeared", String(block.get("id", "")))
			return

static func pest_treatment_plan(block: Dictionary) -> Dictionary:
	var pest = block.get("pest")
	if pest == null:
		return { "has_pest": false }
	var cat := Database.get_pest(String(pest.get("id", "")))
	var area := float(block.get("area_ha", 1.0))
	var method := String(cat.get("method", "default"))
	var costmap: Dictionary = Database.params.get("pest_treatment_cost_rp_per_ha", {})
	var cost := int(round(float(costmap.get(method, costmap.get("default", 400000))) * area))
	return {
		"has_pest": true, "name": cat.get("name"), "method": method,
		"ingredients": cat.get("ingredients", []), "cost": cost,
		"diagnosed": bool(pest.get("diagnosed", false)), "curable": bool(cat.get("curable", true)),
		"level": float(pest.get("level", 0.0))
	}

# Efektivitas obat = base x (diagnosis benar ? 1+bonus_profil : 0.4). Tanpa diagnosis = boros.
static func pest_effectiveness(correct_diagnosis: bool) -> float:
	var base := float(Database.params.get("pest_base_effectiveness", 0.85))
	var mods := GameState.profile_mods()
	var bonus := float(mods.get("treatment_effectiveness_bonus", 0.0)) if mods.get("requires_correct_diagnosis", false) else 0.0
	var diag := (1.0 + bonus) if correct_diagnosis else 0.4
	return clamp(base * diag, 0.0, 1.0)

static func apply_pest_treatment(block: Dictionary, eff: float, curable: bool) -> bool:
	var pest = block.get("pest")
	if pest == null:
		return false
	if curable:
		pest["level"] = max(0.0, float(pest.get("level", 0.0)) * (1.0 - eff))
		if float(pest.get("level", 0.0)) < float(Database.params.get("pest_clear_threshold", 0.08)):
			block["pest"] = null
			return true
		return false
	# Penyakit tak tersembuhkan (Ganoderma): sanitasi hanya memperlambat.
	pest["level"] = max(0.0, float(pest.get("level", 0.0)) * (1.0 - eff * 0.4))
	return false

static func _tolerance_factor(block: Dictionary, cat: Dictionary) -> float:
	var t := String(cat.get("tolerance_trait", ""))
	if t == "":
		return 1.0
	var seed := Database.get_seed(String(block.get("seed_id", "")))
	var tol := String(seed.get("traits", {}).get(t, ""))
	# Makin toleran, makin kecil peluang & kerusakan.
	match tol:
		"tinggi": return 0.30
		"moderat", "sedang": return 0.45
		_: return 1.0

# ---------------------------------------------------------------- TBS / Panen
## Satu-satunya sumber kebenaran "berapa kg TBS siap potong rotasi ini" — dipakai
## HarvestScreen, DashboardScreen, Actions (estimate_kg/harvest) & Main.gd
## (dulu 4 implementasi terpisah, kini 1). TIDAK mengecek TimeManager.harvest_due()
## di sini — itu tetap tanggung jawab pemanggil (lihat pola lama Actions.estimate_kg),
## supaya DashboardScreen bisa tetap menampilkan ESTIMASI walau belum due.
##
## Formula ikuti Standar Produksi Marihat.xlsx (jjg/pkk & BJR per umur+kelas
## lahan, BUKAN dibaca langsung dari kolom ton/ha/tahun — kolom itu cuma angka
## tahunan kasar, dipakai di tempat lain cuma sbg plafon/pembanding):
##   jjg matang/pkk/BULAN = jjg_per_pkk_TAHUN / 12
##   kg/pkk/BULAN         = jjg matang/pkk/bulan x BJR(kg)
##   kg/pkk/ROTASI        = kg/pkk/bulan x (rotation_days / (days_per_year/12))
##   kg/ha/ROTASI         = kg/pkk/rotasi x pokok/ha x health
## Plafon varietas (seed.max_tbs_ton_ha_year) tetap membatasi pokok NORMAL;
## pokok Golden Tree dapat bonus DI ATAS plafon = count x kg/pkok normal x
## (golden_multiplier - 1) — kebijakan sama dgn Main.gd lama (temuan audit D/E).
## Hasil akhir dijepit ke BATAS BAWAH (floor) sesuai rajin pupuk 365 hari
## terakhir (fertilize_count_last_year) — 12/18/24 t/ha/thn utk 0/1/>=2x pupuk
## — supaya TM tak pernah jatuh ke 0 walau health/gulma/hama terburuk sekalipun.
static func tbs_batch_kg(block: Dictionary) -> float:
	var seed := Database.get_seed(String(block.get("seed_id", "")))
	var age := GameState.age_years_of(block)
	if age < int(seed.get("start_harvest_age_year", 4)):
		return 0.0
	var row := Database.get_production_row(age, String(block.get("land_class", "S1")))
	var bunches_year := float(row.get("bunches_per_palm", 0.0))
	var bjr := float(row.get("bunch_weight_kg", 0.0))
	if bunches_year <= 0.0 or bjr <= 0.0:
		return 0.0

	var dpy := float(Database.params.get("days_per_year", 365))
	var days_per_month := dpy / 12.0
	var rotation_days := float(TimeManager.harvest_rotation_days)
	var kg_per_palm_rotation := (bunches_year / 12.0) * bjr * (rotation_days / days_per_month)

	# Plafon varietas dinyatakan sbg ton/ha/tahun -> turunkan ke kg/pokok/rotasi yg setara.
	var cap_ton_year := float(seed.get("max_tbs_ton_ha_year", 999))
	var cap_kg_per_palm_rotation := (cap_ton_year * 1000.0 / float(GameState.SEEDS_PER_HA)) * (rotation_days / dpy)
	kg_per_palm_rotation = min(kg_per_palm_rotation, cap_kg_per_palm_rotation)

	var area := float(block.get("area_ha", 1.0))
	var health := float(block.get("health", 1.0))
	var palms := float(GameState.SEEDS_PER_HA) * area
	var kg := kg_per_palm_rotation * palms * health

	var golden := float(block.get("golden_count", 0))
	if golden > 0.0 and bool(Database.params.get("golden_bonus_exceeds_variety_cap", true)):
		var mult := float(Database.params.get("golden_multiplier", 5))
		kg += golden * (kg_per_palm_rotation * health) * (mult - 1.0)

	# Batas bawah produksi TM — seburuk apapun kesehatan/gulma/hama, TM tak
	# pernah produksi nol (spek): 1 ton/ha/bulan (12 t/ha/thn) kalau tak dirawat
	# sama sekali, naik ke 1,5 t/ha/bln (18 t/ha/thn) kalau dipupuk 1x dlm 365
	# hari terakhir, 2 t/ha/bln (24 t/ha/thn) kalau dipupuk >=2x. Ini floor, BUKAN
	# tambahan di atas produksi normal — tanaman sehat & terawat lengkap (gulma +
	# hama) hasilnya tetap sesuai standar produksi di atas (floor tak berlaku).
	var fert_n := fertilize_count_last_year(block)
	var floor_ton_ha_year := 12.0
	if fert_n >= 2:
		floor_ton_ha_year = 24.0
	elif fert_n == 1:
		floor_ton_ha_year = 18.0
	var floor_kg := floor_ton_ha_year * 1000.0 * area * (rotation_days / dpy)
	kg = max(kg, floor_kg)
	return kg

# ---------------------------------------------------------------- Tenaga kerja (HK)
# HK (hari kerja) = luas / norma(ha/HK) / kecepatan. Pecahan agar buff Arman
# (work_speed_multiplier) terasa di skala berapa pun (kerja lebih cepat & murah).
static func labor_hk(activity: String, area: float) -> float:
	var norma_map: Dictionary = Database.params.get("ha_per_hk", {})
	var norma: float = max(float(norma_map.get(activity, norma_map.get("default", 2.0))), 0.01)
	var speed := float(GameState.profile_mods().get("work_speed_multiplier", 1.0))
	return area / norma / speed

static func labor_cost(activity: String, area: float) -> int:
	return int(round(labor_hk(activity, area) * float(Database.params.get("daily_wage_rp", 120000))))

# ======================================================================
# Jadwal pemupukan BULANAN (data/fertilizer_schedule.json)
# ----------------------------------------------------------------------
# Berbeda dari fertilizer_plan() yang memakai norma per-TAHUN: jadwal ini
# menentukan bulan ke berapa memupuk dan jenis apa, sesuai dokumen
# "rekomendasi pemupukan.xlsx". Dosis = GRAM PER POKOK per aplikasi.
# ======================================================================

## Pupuk higroskopis (bersifat asam) — tidak boleh dicampur dengan golongan
## fosfat/basa di bawah. Lihat catatan agronomi di Catatan Perbaikan.
const HYGROSCOPIC := ["Urea", "MOP"]
const PHOSPHATE_ALKALINE := ["RPH", "Dolomit", "HGFB"]

## Umur blok dalam bulan (1 bulan = 30 hari, konsisten dgn kolom Hari sheet).
static func block_age_months(block: Dictionary) -> int:
	return int(floor(float(GameState.day - int(block.get("planting_day", GameState.day))) / 30.0))

## Tahun tanam ke berapa untuk bulan tertentu (bulan 1-12 = tahun 1, dst).
static func plant_year_of_month(bulan: int) -> int:
	return maxi(1, int(ceil(float(bulan) / 12.0)))

## Jumlah pokok di satu blok.
static func palms_of(block: Dictionary) -> int:
	var per_ha := int(Database.fertilizer_schedule.get("palms_per_ha", 143))
	return int(round(per_ha * float(block.get("area_ha", 1.0))))

## Rencana pemupukan untuk SATU bulan terjadwal di satu blok.
## Mengembalikan {} kalau bulan itu tidak ada jadwalnya.
static func monthly_fert_plan(block: Dictionary, bulan: int) -> Dictionary:
	var dose: Dictionary = Database.fert_schedule_month(bulan)
	if dose.is_empty():
		return {}
	var palms := palms_of(block)
	var comps: Array = []
	var total := 0.0
	for code in dose:
		var g_per_palm := float(dose[code])
		var kg_total := g_per_palm / 1000.0 * float(palms)
		var price := _fert_price(String(code))
		var cost := kg_total * price
		total += cost
		comps.append({
			"code": code, "g_per_palm": g_per_palm,
			"kg_total": kg_total, "price_per_kg": price, "cost": cost })
	comps.sort_custom(func(a, b): return String(a["code"]) < String(b["code"]))
	return {
		"bulan": bulan, "palms": palms, "components": comps,
		"total_cost": int(round(total)),
		"warning": mixing_warning(dose.keys()) }

## Bulan-bulan berjadwal yang SUDAH LEWAT tapi belum dipupuk, dalam tahun
## tanam yang sama dengan bulan sekarang.
static func missed_fert_months(block: Dictionary) -> Array:
	var now_m := block_age_months(block)
	var this_year := plant_year_of_month(now_m)
	var done: Array = block.get("fert_months_done", [])
	var out: Array = []
	for e in Database.fertilizer_schedule.get("schedule", []):
		var b := int(e.get("bulan", -1))
		if b <= 0 or b > now_m:
			continue
		if plant_year_of_month(b) != this_year:
			continue
		if not done.has(b):
			out.append(b)
	out.sort()
	return out

## Catat bahwa blok sudah dipupuk untuk bulan tertentu.
static func mark_fert_month(block: Dictionary, bulan: int) -> void:
	var done: Array = block.get("fert_months_done", [])
	if not done.has(bulan):
		done.append(bulan)
	block["fert_months_done"] = done

## Peringatan campur pupuk. "" kalau aman.
static func mixing_warning(codes: Array) -> String:
	var hyg: Array = []
	var pho: Array = []
	for c in codes:
		var s := String(c)
		if HYGROSCOPIC.has(s): hyg.append(s)
		if PHOSPHATE_ALKALINE.has(s): pho.append(s)
	if hyg.is_empty() or pho.is_empty():
		return ""
	return "Jangan dicampur: %s bersifat higroskopis/asam, sedangkan %s golongan fosfat/basa. Aplikasikan terpisah dengan jeda, bukan sekali tabur." % [
		", ".join(hyg), ", ".join(pho)]

## Teks dosis untuk prompt reminder, mis. "1,2 kg Urea per pokok".
static func dose_text(dose: Dictionary) -> String:
	var parts: Array = []
	var keys: Array = dose.keys()
	keys.sort()
	for code in keys:
		parts.append("%s %s" % [fmt_kg(float(dose[code])), code])
	return ", ".join(parts)

## Gram -> teks kg gaya Indonesia (koma desimal). 1200 -> "1,2 kg"; 60 -> "60 gr".
static func fmt_kg(gram: float) -> String:
	if gram < 1000.0:
		return ("%d gr" % int(round(gram)))
	var kg := gram / 1000.0
	var s := "%.1f" % kg
	if s.ends_with(".0"):
		s = s.substr(0, s.length() - 2)
	return s.replace(".", ",") + " kg"

# ---------------------------------------------------------------- Util
static func _fert_price(code: String) -> float:
	var m: Dictionary = Database.params.get("fertilizer_price_rp_per_kg", {})
	var base := float(m.get(code, m.get("default", 7000)))
	# Terapkan faktor harga input sesuai level kesulitan
	return base * GameState.input_price_factor()

static func _clamp_fert_age(age: int, lc: String) -> int:
	# T_Pupuk: umur di luar rentang -> pakai baris terdekat (lihat catatan sheet).
	var ages: Array = []
	for r in Database.fertilizer:
		if r.get("land_class") == lc and r.has("plant_age_year"):
			ages.append(int(r["plant_age_year"]))
	if ages.is_empty():
		return age
	ages.sort()
	if age < ages[0]:
		return ages[0]
	if age > ages[-1]:
		return ages[-1]
	return age
