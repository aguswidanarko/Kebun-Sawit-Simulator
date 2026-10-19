class_name ForestLoot
extends RefCounted
## Tabel kemunculan item acak di sabuk semak belukar (lihat ForestBeltBuilder).
## id merujuk entri res://data/merchant_inventory_start.json (lewat
## Database.merchant_inventory) — harga & kategori jual sudah ada di sana,
## pemungutan cukup lewat GameState.collect_item(id). Slot yang sudah dipungut
## refresh random 1 bulan kemudian (lihat MONTH_DAYS) — state disimpan di
## block["forest_slots"], ikut tersimpan oleh save/load umum GameState.

const MONTH_DAYS := 30     # siklus refresh slot setelah dipungut (spek: "1 bulan kemudian")
const MAX_SLOTS := 10      # jumlah titik loot aktif maksimum per blok
const INNER_FRAC := 0.68   # jarak minimal titik loot dari pusat (fraksi radius jelajah) — di luar area tanam inti
const OUTER_MARGIN_M := 4.0 # jarak titik loot dari dinding hutan (radius jelajah - margin)

## rarity -> { weight, ids[] }. id harus ada di data/merchant_inventory_start.json.
const TABLE := [
	{ "rarity": "umum", "weight": 60, "ids": ["tiram", "kuping", "jangkrik"] },
	{ "rarity": "jarang", "weight": 25, "ids": ["jahe", "sambiloto", "pasak", "kroto", "madu_hutan"] },
	{ "rarity": "langka", "weight": 12, "ids": ["ayam", "landak", "burung_hantu", "monyet"] },
	{ "rarity": "epik", "weight": 3, "ids": ["bacan", "kalimaya", "intan"] },
]

## Pilih 1 item_id acak sesuai bobot rarity di TABLE.
static func roll_item_id() -> String:
	var total := 0
	for t in TABLE:
		total += int(t["weight"])
	var r: int = randi() % maxi(total, 1)
	var acc := 0
	for t in TABLE:
		acc += int(t["weight"])
		if r < acc:
			var ids: Array = t["ids"]
			return String(ids[randi() % ids.size()])
	return String(TABLE[0]["ids"][0])

## Posisi DETERMINISTIK titik loot ke-`i` di sabuk belukar blok `seed_key`
## (misal id blok) — sama tiap kali dunia dibangun ulang, tak perlu disimpan.
static func slot_position(seed_key: String, i: int, center: Vector3, radius_m: float) -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_forest_slot_%d" % [seed_key, i])
	var ang := rng.randf_range(0.0, TAU)
	var inner := radius_m * INNER_FRAC
	var outer := maxf(inner + 2.0, radius_m - OUTER_MARGIN_M)
	var rad := rng.randf_range(inner, outer)
	return center + Vector3(cos(ang) * rad, 0.0, sin(ang) * rad)
