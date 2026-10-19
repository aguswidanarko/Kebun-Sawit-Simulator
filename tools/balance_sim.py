#!/usr/bin/env python3
"""
Balance sim — menambal temuan I audit ("uji keseimbangan profil").

Mensimulasikan ekonomi 1 ha selama N tahun untuk ketiga profil dengan lahan,
modal, cuaca, dan keputusan yang SAMA, lalu membandingkan laba kumulatif.

CATATAN: ini meniru rumus di scenes/Main.gd + asumsi biaya pemeliharaan tahunan
(belum ada di MVP). Angka biaya = placeholder gameplay. Tujuannya menguji apakah
buff profil seimbang — BUKAN memvalidasi angka agronomis.

Jalankan:  python3 tools/balance_sim.py
"""
import json, os

DATA = os.path.join(os.path.dirname(__file__), "..", "data")

def load(name):
    with open(os.path.join(DATA, name), encoding="utf-8") as f:
        return json.load(f)

params = load("params.json")
seeds = {s["seed_id"]: s for s in load("seed_catalog.json")}
prod_rows = load("production_standard.json")

# Asumsi biaya (placeholder gameplay — ganti dari workbook/desain):
MAINTENANCE_PER_HA_YEAR = 8_000_000   # pupuk + HK + semprot per ha/tahun
BASE_HEALTH = 0.90                      # kualitas panen dasar tanpa buff
YEARS = 10
SEED_ID = "marihat_ppks"               # varietas pembanding
LAND_COST = 15_000_000
SEEDS_PER_HA = 143

def production(age, land_class="S1"):
    for r in prod_rows:
        if r.get("plant_age_year") == age and r.get("land_class") == land_class:
            return float(r.get("tbs_ton_ha_year", 0))
    return 0.0

def tbs_price(seed, health):
    base = params["tbs_price_rp_per_kg"]
    if not params.get("enable_grading", True):
        return base
    baseline = params["rendemen_baseline_pct"]
    sens = params["rendemen_price_sensitivity"]
    factor = 1 + (seed["rendemen_pct"] - baseline) * 0.01 * sens
    return base * factor * max(0.0, min(1.0, health))

def simulate(profile):
    """profile = dict modifiers. Mengembalikan laba kumulatif 10 tahun."""
    seed = seeds[SEED_ID]
    mods = profile["modifiers"]
    # Hook buff:
    maint_mult = 1.0 - (0.10 if mods.get("work_speed_multiplier") else 0.0)  # kerja cepat -> HK lebih murah
    maint_mult -= float(mods.get("input_discount") or 0.0)                   # diskon input (Nadia 5%)
    health = BASE_HEALTH + (0.10 if mods.get("treatment_effectiveness_bonus") else 0.0)
    health = min(health, 1.0)

    cash = -(LAND_COST + seed["price_per_seed_rp"] * SEEDS_PER_HA)  # investasi awal
    yearly = []
    start_age = seed["start_harvest_age_year"]
    cap = seed["max_tbs_ton_ha_year"]
    for age in range(0, YEARS + 1):
        rev = 0.0
        if age >= start_age:
            ton = min(production(age), cap)
            yield_kg = ton * 1000
            # Golden Tree expected value (5% x (5-1) = +20% of normal) di atas plafon:
            if seed.get("golden_eligible") and params.get("golden_bonus_exceeds_variety_cap", True):
                p = params["golden_base_probability"]
                mult = params["golden_multiplier"]
                yield_kg += yield_kg * p * (mult - 1)
            rev = yield_kg * tbs_price(seed, health)
        cost = MAINTENANCE_PER_HA_YEAR * maint_mult if age >= 1 else 0
        cash += rev - cost
        yearly.append(cash)
    return yearly

profiles = {p["id"]: p for p in load("player_profiles.json")}

print("=" * 72)
print("UJI KESEIMBANGAN PROFIL — laba kumulatif Rp (1 ha, %s, %d tahun)" % (SEED_ID, YEARS))
print("=" * 72)
rows = list(profiles.values())
results = {}
for p in rows:
    res = simulate(p)
    results[p["name"]] = res[-1]
    print("\n%-38s  BEP thn | laba thn-%d" % (p["name"], YEARS))
    bep = next((i for i, v in enumerate(res) if v >= 0), None)
    print("  %-36s  %-7s | Rp%s" % (p["buff_text"][:36] if "buff_text" in p else "(varian uji)",
          str(bep) if bep is not None else ">%d" % YEARS, f"{int(res[-1]):,}".replace(",", ".")))

print("\n" + "-" * 72)
best = max(results.values()); worst = min(results.values())
spread = (best - worst) / abs(best) * 100 if best else 0
print("Selisih profil terbaik vs terburuk: %.1f%%" % spread)
print("Target sehat: < 15%. Jika lebih, buff tidak seimbang (temuan I).")
print("-" * 72)
