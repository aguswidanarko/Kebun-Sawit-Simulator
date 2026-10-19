extends Node
## Database (autoload)
## Memuat semua norma dari res://data/*.json dan menyediakan fungsi query.
## Workbook Excel adalah SUMBER OTORITATIF; file JSON di sini adalah hasil impor terkurasi.
## Jangan membaca Excel langsung saat game jalan (lihat GDD v0.3 bagian 4).

var params: Dictionary = {}
var seeds: Array = []
var production: Array = []
var fertilizer: Array = []
var control: Array = []
var products: Array = []
var pest_control: Array = []
var pest_catalog: Array = []
var cosmetics: Array = []
var story: Dictionary = {}
var land_offers: Array = []
var field_tasks: Dictionary = {}       # mini-game simulator (design handoff v1)
var merchant_stock: Array = []         # barang beli dari pedagang
var merchant_inventory: Array = []     # gudang awal (jual ke pedagang)
var merchant_categories: Dictionary = {}
var friends: Dictionary = {}           # snapshot kebun teman (demo)
var profiles: Array = []
var land_assessment: Dictionary = {}   # kriteria penilaian kelas lahan (dari app penilaian-kelas-lahan)
var nursery_stages: Array = []         # tahap visual/layout pembibitan PN/MN (lihat params.nursery utk biaya+jadwal)

func _ready() -> void:
	params = _load_dict("res://data/params.json")
	seeds = _load_array("res://data/seed_catalog.json")
	production = _load_array("res://data/production_standard.json")
	fertilizer = _load_array("res://data/fertilizer_standard.json")
	control = _load_array("res://data/control_standard.json")
	products = _load_array("res://data/product_catalog.json")
	pest_control = _load_array("res://data/pest_control.json")
	pest_catalog = _load_array("res://data/pest_catalog.json")
	cosmetics = _load_array("res://data/cosmetic_catalog.json")
	story = _load_dict("res://data/story.json")
	land_offers = _load_array("res://data/land_offers.json")
	field_tasks = _load_dict("res://data/field_tasks.json")
	merchant_stock = _load_array("res://data/merchant_stock.json")
	merchant_inventory = _load_array("res://data/merchant_inventory_start.json")
	merchant_categories = _load_dict("res://data/merchant_categories.json")
	friends = _load_dict("res://data/friends_demo.json")
	profiles = _load_array("res://data/player_profiles.json")
	land_assessment = _load_dict("res://data/land_class_assessment.json")
	nursery_stages = _load_array("res://data/nursery_stages.json")
	print("[Database] %d kecambah, %d produksi, %d pupuk, %d semprot, %d produk, %d hama, %d profil, %d tahap bibitan." % [
		seeds.size(), production.size(), fertilizer.size(), control.size(),
		products.size(), pest_control.size(), profiles.size(), nursery_stages.size()])

func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("File data tidak ditemukan: " + path)
		return null
	var txt := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(txt)
	if data == null:
		push_error("JSON gagal diparse: " + path)
	return data

func _load_dict(path: String) -> Dictionary:
	var d = _load_json(path)
	return d if d is Dictionary else {}

func _load_array(path: String) -> Array:
	var d = _load_json(path)
	return d if d is Array else []

# --- Query kecambah ---
func get_seed(seed_id: String) -> Dictionary:
	for s in seeds:
		if s.get("seed_id") == seed_id:
			return s
	return {}

func list_certified_seeds() -> Array:
	return seeds.filter(func(s): return s.get("certification_status") == "certified")

# --- Query produksi (ton TBS/ha/tahun) ---
func get_production(age_year: int, land_class: String) -> float:
	for row in production:
		if int(row.get("plant_age_year", -1)) == age_year and row.get("land_class") == land_class:
			return float(row.get("tbs_ton_ha_year", 0.0))
	return 0.0

## Baris penuh standar produksi (plant_age_year, land_class, tbs_ton_ha_year,
## bunches_per_palm = jjg/pkk/TAHUN, bunch_weight_kg = BJR kg/tandan). Dipakai
## Agronomy.tbs_batch_kg() utk hitung TBS per rotasi dari jjg x BJR (bukan cuma
## kolom ton/ha/tahun) — lihat Standar Produksi Marihat.xlsx.
func get_production_row(age_year: int, land_class: String) -> Dictionary:
	for row in production:
		if int(row.get("plant_age_year", -1)) == age_year and row.get("land_class") == land_class:
			return row
	return {}

# --- Query pupuk (kg/ha/tahun; faktor S2/S3 SUDAH tertanam) ---
func get_fertilizer(age_year: int, land_class: String) -> Array:
	return fertilizer.filter(func(r):
		return int(r.get("plant_age_year", -1)) == age_year and r.get("land_class") == land_class)

# --- Query semprot gulma (umur + lokasi + gulma). mix_option mengelompokkan komponen campuran ---
func get_control(age_year: int, location: String, organism: String) -> Array:
	return control.filter(func(r):
		return int(r.get("plant_age_min", 0)) <= age_year and age_year <= int(r.get("plant_age_max", 999)) \
			and (location == "" or r.get("target_location") == location) \
			and (organism == "" or r.get("target_organism") == organism))

# --- Harga: produk termurah untuk suatu bahan aktif ---
func cheapest_product(active_ingredient: String) -> Dictionary:
	var best := {}
	for p in products:
		if p.get("active_ingredient") == active_ingredient and p.get("price") != null:
			if best.is_empty() or float(p.get("price")) < float(best.get("price")):
				best = p
	return best

# --- Query cerita & lahan ---
func story_node(id: String) -> Dictionary:
	return story.get("nodes", {}).get(id, {})

func story_start(profile_id: String) -> String:
	return String(story.get("start", {}).get(profile_id, ""))

func get_land_offer(id: String) -> Dictionary:
	for l in land_offers:
		if l.get("id") == id:
			return l
	return {}

func land_offers_by_type(t: String) -> Array:
	return land_offers.filter(func(l): return l.get("type") == t)

# --- Query katalog hama ---
func get_pest(pest_id: String) -> Dictionary:
	for p in pest_catalog:
		if p.get("id") == pest_id:
			return p
	return {}

func eligible_pests(age_year: int) -> Array:
	return pest_catalog.filter(func(p):
		return p.has("id") and int(p.get("age_min", 0)) <= age_year and age_year <= int(p.get("age_max", 99)))

# --- Query kosmetik ---
func get_cosmetic(id: String) -> Dictionary:
	for c in cosmetics:
		if c.get("id") == id:
			return c
	return {}

func cosmetics_by_category(cat: String) -> Array:
	return cosmetics.filter(func(c): return c.get("category") == cat)

func cosmetic_categories() -> Array:
	var seen := {}
	for c in cosmetics:
		if c.has("category"):
			seen[String(c["category"])] = true
	return seen.keys()

func free_cosmetic_ids() -> Array:
	return cosmetics.filter(func(c): return c.has("id") and float(c.get("price_rp", 0)) == 0.0) \
		.map(func(c): return c["id"])

# --- Query profil pemain ---
func get_profile(profile_id: String) -> Dictionary:
	for p in profiles:
		if p.get("id") == profile_id:
			return p
	return {}

# --- Query gudang/pedagang (dipakai juga oleh ForestLoot utk metadata item hutan) ---
func get_merchant_item(id: String) -> Dictionary:
	for it in merchant_inventory:
		if it.get("id") == id:
			return it
	return {}

# --- Query tahap pembibitan (layout/model per umur, lihat data/nursery_stages.json) ---
func get_nursery_stage(stage_id: String) -> Dictionary:
	for s in nursery_stages:
		if s.get("stage_id") == stage_id:
			return s
	return {}

# Cocokkan umur (bulan) ke tahap visual. Rentang antar-tahap bisa bertumpuk tepat
# di bulan transisi (mis. bulan 3 = akhir PN & awal MN sekaligus) — pemenangnya
# adalah entri yang LEBIH DULU di array (lihat urutan di nursery_stages.json).
func nursery_stage_for_month(month: int) -> Dictionary:
	for s in nursery_stages:
		if not s.has("stage_id"):
			continue
		var start_month := int(s.get("month_start", 0))
		if month < start_month:
			continue
		var end_month = s.get("month_end")
		if end_month != null and month > int(end_month):
			continue
		return s
	return {}
