extends Node
## TimeManager (autoload)
## Mengunci model waktu (menambal temuan C audit): 1 tick = 1 hari.
## Rotasi panen/pupuk/semprot dibaca dari params.json agar bisa dikonfigurasi.

signal day_advanced(day: int)

var harvest_rotation_days: int = 6
var fertilizer_rotation_days: int = 120
var spray_rotation_days: int = 90

var _weather_queue: Array = []   # cuaca hari-hari mendatang (untuk prakiraan)

func _ready() -> void:
	harvest_rotation_days = int(Database.params.get("harvest_rotation_days", 6))
	fertilizer_rotation_days = int(Database.params.get("fertilizer_rotation_days", 120))
	spray_rotation_days = int(Database.params.get("spray_rotation_days", 90))
	_ensure_forecast(7)

func advance_day(n: int = 1) -> void:
	for _i in n:
		GameState.day += 1
		_roll_weather()
		_tick_blocks()
		GameState.tick_nursery()
		GameState.tick_tph()
	emit_signal("day_advanced", GameState.day)
	GameState.emit_signal("day_changed", GameState.day)

func _ensure_forecast(min_len: int) -> void:
	var types: Array = Database.params.get("weather_types", ["cerah"])
	while _weather_queue.size() < min_len:
		_weather_queue.append(String(types[randi() % types.size()]))

func _roll_weather() -> void:
	_ensure_forecast(1)
	GameState.weather = String(_weather_queue.pop_front())
	_ensure_forecast(7)

## Prakiraan cuaca n hari ke depan (hari esok dst). Horison per profil (buff Nadia).
func forecast(n: int) -> Array:
	_ensure_forecast(n)
	return _weather_queue.slice(0, n)

func _tick_blocks() -> void:
	var wgrow := float(Database.params.get("weed_growth_per_day", 0.012))
	var wfac := float(Database.params.get("weather_weed_factor", {}).get(GameState.weather, 1.0))
	var h_weed := float(Database.params.get("health_decay_weed_factor", 0.25))   # per bulan pada gulma penuh
	var h_fert := float(Database.params.get("health_decay_fertilizer_per_day", 0.0015))
	for b in GameState.blocks:
		_tick_plant(b, wgrow, wfac, h_weed, h_fert)
	# Kebun 9 plot (Dashboard): tanam ditick, buka berkurang progresnya.
	for p in GameState.plots:
		match p.get("state", "kosong"):
			"tanam":
				_tick_plant(p, wgrow, wfac, h_weed, h_fert)
			"buka":
				p["clear"] = max(0, int(p.get("clear", 0)) - 1)
				if int(p["clear"]) <= 0:
					p["state"] = "siap"

func _tick_plant(b: Dictionary, wgrow: float, wfac: float, h_weed: float, h_fert: float) -> void:
	b["weed_level"] = min(1.0, float(b.get("weed_level", 0.0)) + wgrow * wfac)
	var h := float(b.get("health", 1.0))
	h -= float(b.get("weed_level", 0.0)) * h_weed / 30.0
	if GameState.day - int(b.get("last_fertilize_day", GameState.day)) > fertilizer_rotation_days:
		h -= h_fert
	b["health"] = clamp(h, 0.1, 1.0)
	Agronomy.tick_pest(b)   # Fase 2: hama/penyakit muncul & merusak

func harvest_due(block: Dictionary) -> bool:
	return (GameState.day - int(block.get("last_harvest_day", 0))) >= harvest_rotation_days
