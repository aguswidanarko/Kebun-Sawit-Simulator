class_name Actions
extends RefCounted
## Aksi budidaya inti (dipakai ulang oleh dunia 3D; Main bisa dimigrasi nanti).
## Semua fungsi beroperasi pada satu blok, memakai Agronomy/Database/GameState.
## Mengembalikan ringkasan string untuk ditampilkan; biaya/efek diterapkan langsung.

static func _discount() -> float:
	return float(GameState.profile_mods().get("input_discount", 0.0))

static func fertilize(b: Dictionary) -> String:
	var plan := Agronomy.fertilizer_plan(b)
	if plan.get("components", []).is_empty():
		return "Belum ada rekomendasi pupuk untuk umur ini."
	var area := float(b.get("area_ha", 1.0))
	var mat := int(round(float(plan.get("total_cost", 0)) * (1.0 - _discount())))
	var hk := Agronomy.labor_hk("pupuk", area)
	var lab := Agronomy.labor_cost("pupuk", area)
	if not GameState.spend(mat + lab):
		return "Dana tidak cukup untuk pemupukan."
	Agronomy.apply_fertilize(b)
	GameState.mark_objective("fertilized")
	return "Pupuk %d jenis — Rp%s + %.1f HK. Sehat %.0f%%." % [
		plan.get("components", []).size(), GameState._fmt(mat + lab), hk, float(b.get("health", 1.0)) * 100.0]

static func spray(b: Dictionary, location := "Piringan & pasar pikul", weed := "Rumput + LCC") -> String:
	var plan := Agronomy.spray_plan(b, location, weed)
	if not plan.get("found", false):
		return "Tak ada norma semprot cocok (umur/lokasi/gulma)."
	var area := float(b.get("area_ha", 1.0))
	var mat := int(round(float(plan.get("total_cost", 0)) * (1.0 - _discount())))
	var lab := Agronomy.labor_cost("semprot", area)
	if not GameState.spend(mat + lab):
		return "Dana tidak cukup untuk menyemprot."
	var eff := Agronomy.spray_effectiveness(true)
	var before := float(b.get("weed_level", 0.0))
	Agronomy.apply_spray(b, eff)
	GameState.mark_objective("sprayed")
	return "Semprot %d bahan, cuaca %s, efektif %.0f%% — Rp%s. Gulma %.0f%%→%.0f%%." % [
		plan.get("components", []).size(), GameState.weather, eff * 100.0, GameState._fmt(mat + lab),
		before * 100.0, float(b.get("weed_level", 0)) * 100.0]

static func inspect(b: Dictionary) -> String:
	var pest = b.get("pest")
	if pest == null:
		return "Tidak ada gejala hama/penyakit di sini."
	if bool(pest.get("diagnosed", false)):
		var c := Database.get_pest(String(pest.get("id", "")))
		return "Sudah terdiagnosis: %s." % c.get("name")
	var cost := int(Database.params.get("pest_inspection_cost_rp", 50000))
	if not GameState.spend(cost):
		return "Dana tidak cukup untuk inspeksi."
	pest["diagnosed"] = true
	var cat := Database.get_pest(String(pest.get("id", "")))
	var ingr: Array = cat.get("ingredients", [])
	var it := ", ".join(ingr) if not ingr.is_empty() else "(non-kimia)"
	return "Diagnosis: %s. Metode %s | bahan %s." % [cat.get("name"), cat.get("method"), it]

static func treat_pest(b: Dictionary) -> String:
	var plan := Agronomy.pest_treatment_plan(b)
	if not plan.get("has_pest", false):
		return "Tidak ada hama/penyakit untuk diobati."
	var area := float(b.get("area_ha", 1.0))
	var mat := int(round(float(plan.get("cost", 0)) * (1.0 - _discount())))
	var lab := Agronomy.labor_cost("hama", area)
	if not GameState.spend(mat + lab):
		return "Dana tidak cukup untuk pengobatan."
	var correct := bool(plan.get("diagnosed", false))
	var eff := Agronomy.pest_effectiveness(correct)
	var curable := bool(plan.get("curable", true))
	var cleared := Agronomy.apply_pest_treatment(b, eff, curable)
	var waste := "" if correct else " (tanpa diagnosis — boros!)"
	if not curable:
		return "%s tak bisa diberantas sekali; sanitasi memperlambat. Rp%s." % [plan.get("name"), GameState._fmt(mat + lab)]
	if cleared:
		return "%s teratasi. Rp%s, efektif %.0f%%%s" % [plan.get("name"), GameState._fmt(mat + lab), eff * 100.0, waste]
	return "%s ditekan, belum hilang. Rp%s%s" % [plan.get("name"), GameState._fmt(mat + lab), waste]

static func harvest(b: Dictionary, buyer := "pengepul") -> String:
	if not TimeManager.harvest_due(b):
		var d := TimeManager.harvest_rotation_days - (GameState.day - int(b.get("last_harvest_day", 0)))
		return "Belum waktunya panen (%d hari lagi)." % max(0, d)
	var seed := Database.get_seed(String(b.get("seed_id", "")))
	var age := GameState.age_years_of(b)
	if age < int(seed.get("start_harvest_age_year", 4)):
		return "Umur %d th, mulai panen di umur %d th." % [age, int(seed.get("start_harvest_age_year", 4))]
	var kg := Agronomy.tbs_batch_kg(b)
	if kg <= 0.0:
		return "Belum produktif pada umur ini."
	var health := float(b.get("health", 1.0))
	var price := _price(seed, health, buyer)
	var gross := int(kg * price)
	var lab := Agronomy.labor_cost("panen", float(b.get("area_ha", 1.0)))
	var net := gross - lab
	b["last_harvest_day"] = GameState.day
	b["harvest_bonus_available"] = true   # sisa 10% bisa diambil manual di mode lapangan
	if net > 0:
		GameState.earn(net)
		GameState.mark_objective("harvested")
	return "Panen %.0f kg (sehat %.0f%%) ke %s @ Rp%.0f/kg − HK = Rp%s." % [
		kg, health * 100.0, buyer, price, GameState._fmt(net)]

# ---------------------------------------------------------------- Panen SOP (simulasi lapangan)
## Estimasi kg TBS siap potong rotasi ini (0 bila belum due/belum produktif).
static func estimate_kg(b: Dictionary) -> float:
	if not TimeManager.harvest_due(b):
		return 0.0
	return Agronomy.tbs_batch_kg(b)

## Setor hasil potong ke TPH (SOP: susun 5 TBS/baris + karung brondolan).
## Menandai rotasi blok selesai & menagih upah HK panen.
static func deposit_tph(b: Dictionary, kg: float) -> String:
	var lab := Agronomy.labor_cost("panen", float(b.get("area_ha", 1.0)))
	GameState.spend(lab, "Upah HK panen %s" % b.get("id", "?"))
	b["last_harvest_day"] = GameState.day
	GameState.tph_deposit(kg, String(b.get("seed_id", "")), float(b.get("health", 1.0)))
	GameState.mark_objective("harvested")
	return "%.0f kg tersusun di TPH (5 TBS/baris, brondolan dikarungkan). Angkut ke PKS HARI INI juga!" % kg

## Angkut seluruh isi TPH ke pembeli. Restan menurunkan harga (FFA naik).
static func transport_sell(buyer := "pabrik") -> String:
	var kg := GameState.tph_kg()
	if kg <= 0.0:
		return "TPH kosong — potong buah dulu."
	var seed := Database.get_seed(String(GameState.tph.get("seed_id", "")))
	var health := float(GameState.tph.get("health", 1.0))
	var restan := GameState.tph_restan_days()
	var factor := GameState.tph_restan_factor()
	var price := _price(seed, health, buyer) * factor
	var gross := int(kg * price)
	GameState.earn(gross, "Jual TBS %d kg ke %s%s" % [int(kg), buyer, (" (restan %d hr)" % restan) if restan > 0 else ""])
	GameState.tph_clear()
	var note := "" if restan == 0 else "  ⚠ Restan %d hari — harga turun %.0f%%." % [restan, (1.0 - factor) * 100.0]
	return "Angkut %.0f kg → %s @ Rp%.0f/kg = Rp%s.%s" % [kg, buyer, price, GameState._fmt(gross), note]

static func _price(seed: Dictionary, health: float, buyer: String) -> float:
	var base := float(Database.params.get("tbs_price_rp_per_kg", 2800))
	if buyer == "pengepul":
		return base * float(Database.params.get("pengepul_price_factor", 0.85))
	var baseline := float(Database.params.get("rendemen_baseline_pct", 22.0))
	var sens := float(Database.params.get("rendemen_price_sensitivity", 1.5))
	var rf := 1.0 + (float(seed.get("rendemen_pct", baseline)) - baseline) * 0.01 * sens
	var gbase := float(Database.params.get("pabrik_grade_base", 0.90))
	var grade: float = gbase + (1.0 - gbase) * clamp(health, 0.0, 1.0)
	return max(base * rf * grade - float(Database.params.get("transport_cost_rp_per_kg", 150)), 0.0)
