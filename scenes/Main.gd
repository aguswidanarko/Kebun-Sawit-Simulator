extends Control
## Layar permainan (Fase 3). UI dibangun lewat kode.
## Tutorial/misi awal, selektor semprot manual, indikator prakiraan cuaca.

const LAND_COST_RP := 15000000      # biaya lahan bersih 1 ha (placeholder gameplay)
const SEEDS_PER_HA := 143           # populasi pokok per ha (placeholder, umum ~130-143)

const OBJ_LABELS := {
	"planted": "Beli & tanam 1 blok",
	"advanced": "Jalankan waktu (Lanjut Hari)",
	"fertilized": "Lakukan pemupukan",
	"sprayed": "Semprot gulma",
	"harvested": "Panen & jual TBS",
}

var title_label: Label
var kebun_label: Label
var profile_label: Label
var saldo_label: Label
var hari_label: Label
var weather_label: Label
var forecast_label: Label
var mission_label: RichTextLabel
var spray_location_opt: OptionButton
var spray_weed_opt: OptionButton
var spray_hint_label: Label
var sell_target_opt: OptionButton
var market_hint_label: Label
var blok_label: RichTextLabel
var log_label: RichTextLabel
var seed_option: OptionButton

func _ready() -> void:
	_build_ui()
	GameState.cash_changed.connect(_on_cash_changed)
	GameState.day_changed.connect(func(_d): _refresh())
	GameState.blocks_changed.connect(_refresh)
	GameState.log_message.connect(_on_log)
	GameState.objective_changed.connect(func(_k): _refresh())
	GameState.cosmetics_changed.connect(_refresh)
	_refresh()
	var prof := Database.get_profile(GameState.profile_id)
	_log("Profil: %s. %s" % [prof.get("name", "?"), prof.get("buff_text", "")])
	_log("Modal awal Rp%s. Selesaikan misi awal di panel atas." % GameState._fmt(GameState.cash))
	if OS.get_cmdline_user_args().has("selftest"):
		call_deferred("_run_selftest")
	if OS.get_cmdline_user_args().has("shotmain"):
		call_deferred("_capture_main")

func _capture_main() -> void:
	for i in Database.seeds.size():
		if Database.seeds[i].get("seed_id") == "fr":
			seed_option.selected = i
	_on_plant()
	TimeManager.advance_day(6 * 365)
	_refresh()
	await get_tree().create_timer(1.3).timeout
	get_viewport().get_texture().get_image().save_png("user://main.png")
	print("[main] screenshot saved")
	get_tree().quit()

# ---------------------------------------------------------------- UI
func _build_ui() -> void:
	# Latar 3D kebun hidup di belakang UI.
	add_child(load("res://scenes/ui/KebunBackground.tscn").instantiate())

	# Panel konten semi-transparan (gaya kartu) agar latar tembus pandang.
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 8; panel.offset_top = 8; panel.offset_right = -8; panel.offset_bottom = -8
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.10, 0.08, 0.72)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(12)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.08)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	scroll.add_child(root)

	var top := HBoxContainer.new()
	title_label = Label.new()
	title_label.text = "🌴 Kebun Sawit Simulator"
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title_label)
	top.add_child(_button("≡ Menu", _on_menu))
	root.add_child(top)

	kebun_label = Label.new()
	kebun_label.add_theme_font_size_override("font_size", 15)
	root.add_child(kebun_label)

	profile_label = Label.new()
	profile_label.add_theme_font_size_override("font_size", 12)
	root.add_child(profile_label)

	saldo_label = Label.new()
	saldo_label.add_theme_font_size_override("font_size", 18)
	root.add_child(saldo_label)

	hari_label = Label.new()
	root.add_child(hari_label)
	weather_label = Label.new()
	root.add_child(weather_label)
	forecast_label = Label.new()
	forecast_label.add_theme_font_size_override("font_size", 12)
	root.add_child(forecast_label)

	# Panel misi/tutorial
	var mtitle := Label.new()
	mtitle.text = "📋 Misi Awal"
	mtitle.add_theme_font_size_override("font_size", 14)
	root.add_child(mtitle)
	mission_label = RichTextLabel.new()
	mission_label.bbcode_enabled = true
	mission_label.fit_content = true
	mission_label.custom_minimum_size = Vector2(0, 110)
	root.add_child(mission_label)

	# Kecambah
	var seed_row := HBoxContainer.new()
	var seed_lbl := Label.new(); seed_lbl.text = "Kecambah:"; seed_row.add_child(seed_lbl)
	seed_option = OptionButton.new()
	seed_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in Database.seeds:
		seed_option.add_item("%s — Rp%s | plafon %st | panen umur %d | rendemen %.1f%%" % [
			s.get("variety_name", "?"), GameState._fmt(int(s.get("price_per_seed_rp", 0))),
			str(s.get("max_tbs_ton_ha_year", 0)), int(s.get("start_harvest_age_year", 4)),
			float(s.get("rendemen_pct", 0.0))])
	seed_row.add_child(seed_option)
	root.add_child(seed_row)

	root.add_child(_button("Beli & Tanam 1 ha (lahan Rp%s)" % GameState._fmt(LAND_COST_RP), _on_plant))
	root.add_child(_button("Lanjut 1 Hari", func(): _advance(1)))
	root.add_child(_button("Lanjut 15 Hari (1 rotasi panen)", func(): _advance(TimeManager.harvest_rotation_days)))
	root.add_child(_button("Pupuk Semua Blok", _on_fertilize))

	# Semprot: selektor lokasi + gulma (manual) + indikator prakiraan
	var sep := HSeparator.new(); root.add_child(sep)
	var loc_row := HBoxContainer.new()
	var loc_lbl := Label.new(); loc_lbl.text = "Semprot — lokasi:"; loc_row.add_child(loc_lbl)
	spray_location_opt = OptionButton.new()
	spray_location_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for loc in _distinct_locations():
		spray_location_opt.add_item(loc)
	spray_location_opt.item_selected.connect(func(_i): _populate_spray_weeds(); _refresh())
	loc_row.add_child(spray_location_opt)
	root.add_child(loc_row)

	var weed_row := HBoxContainer.new()
	var weed_lbl := Label.new(); weed_lbl.text = "Gulma dominan:"; weed_row.add_child(weed_lbl)
	spray_weed_opt = OptionButton.new()
	spray_weed_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weed_row.add_child(spray_weed_opt)
	root.add_child(weed_row)
	_populate_spray_weeds()

	spray_hint_label = Label.new()
	spray_hint_label.add_theme_font_size_override("font_size", 12)
	root.add_child(spray_hint_label)
	root.add_child(_button("Semprot Gulma Sekarang", _on_spray))

	var sep2 := HSeparator.new(); root.add_child(sep2)
	root.add_child(_button("Inspeksi Hama (diagnosis)", _on_inspect))
	root.add_child(_button("Obati Hama/Penyakit", _on_treat_pest))

	var sell_row := HBoxContainer.new()
	var sell_lbl := Label.new(); sell_lbl.text = "Jual ke:"; sell_row.add_child(sell_lbl)
	sell_target_opt = OptionButton.new()
	sell_target_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_target_opt.add_item("Pengepul")
	sell_target_opt.add_item("Pabrik")
	sell_target_opt.item_selected.connect(func(_i): _refresh())
	sell_row.add_child(sell_target_opt)
	root.add_child(sell_row)
	market_hint_label = Label.new()
	market_hint_label.add_theme_font_size_override("font_size", 12)
	root.add_child(market_hint_label)
	root.add_child(_button("Panen Semua Blok", _on_harvest))

	root.add_child(_button("🌱 Lihat Kebun 3D", func(): get_tree().change_scene_to_file("res://scenes/Plantation3D.tscn")))

	var social_row := HBoxContainer.new()
	social_row.add_child(_button("🎨 Kosmetik", func(): get_tree().change_scene_to_file("res://scenes/CosmeticShop.tscn")))
	social_row.add_child(_button("📤 Ekspor Kebun", GameState.export_kebun))
	social_row.add_child(_button("👥 Kunjungi", func():
		if GameState.start_visit():
			get_tree().change_scene_to_file("res://scenes/Plantation3D.tscn")))
	root.add_child(social_row)

	var save_row := HBoxContainer.new()
	save_row.add_child(_button("Simpan", GameState.save_game))
	save_row.add_child(_button("Muat", func(): GameState.load_game()))
	root.add_child(save_row)

	var blok_title := Label.new(); blok_title.text = "Blok Kebun:"; root.add_child(blok_title)
	blok_label = RichTextLabel.new()
	blok_label.bbcode_enabled = true
	blok_label.fit_content = true
	blok_label.custom_minimum_size = Vector2(0, 110)
	root.add_child(blok_label)

	var log_title := Label.new(); log_title.text = "Log:"; root.add_child(log_title)
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.custom_minimum_size = Vector2(0, 220)
	root.add_child(log_label)

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new(); b.text = text; b.pressed.connect(cb)
	return b

func _distinct_locations() -> Array:
	var seen := {}
	for r in Database.control:
		var loc = r.get("target_location")
		if loc != null:
			seen[String(loc)] = true
	var arr := seen.keys(); arr.sort()
	return arr

func _populate_spray_weeds() -> void:
	if spray_weed_opt == null:
		return
	spray_weed_opt.clear()
	var loc := spray_location_opt.get_item_text(spray_location_opt.selected) if spray_location_opt.selected >= 0 else ""
	var seen := {}
	for r in Database.control:
		if String(r.get("target_location", "")) == loc:
			var w = r.get("target_organism")
			if w != null:
				seen[String(w)] = true
	var arr := seen.keys(); arr.sort()
	for w in arr:
		spray_weed_opt.add_item(w)

# ---------------------------------------------------------------- Aksi
func _advance(n: int) -> void:
	TimeManager.advance_day(n)
	GameState.mark_objective("advanced")

func _on_plant() -> void:
	var idx := seed_option.selected
	if idx < 0 or idx >= Database.seeds.size():
		return
	var seed: Dictionary = Database.seeds[idx]
	# Lahan dibeli lewat cerita -> tak ditagih lagi; kelas lahan mengikuti pilihan cerita.
	var land_cost := 0 if GameState.land_acquired else LAND_COST_RP
	var total := land_cost + int(seed.get("price_per_seed_rp", 0)) * SEEDS_PER_HA
	if not GameState.spend(total):
		return
	var block := GameState.new_block(1.0, seed.get("seed_id"), GameState.land_class)
	block["golden_count"] = _roll_golden(seed, SEEDS_PER_HA)
	GameState.add_block(block)
	GameState.mark_objective("planted")
	GameState.log_msg("Tanam 1 ha %s. Biaya lahan+benih Rp%s. Golden Tree: %d pokok." % [
		seed.get("variety_name"), GameState._fmt(total), block["golden_count"]])

func _roll_golden(seed: Dictionary, count: int) -> int:
	if not seed.get("golden_eligible", false):
		return 0
	var p := float(seed.get("golden_base_probability", 0.0))
	var golden := 0
	for i in count:
		if randf() < p:
			golden += 1
	return golden

func _on_harvest() -> void:
	if GameState.blocks.is_empty():
		GameState.log_msg("Belum ada blok untuk dipanen.")
		return
	var total_rev := 0
	for b in GameState.blocks:
		if not TimeManager.harvest_due(b):
			continue
		var seed: Dictionary = Database.get_seed(b.get("seed_id"))
		var age := GameState.age_years_of(b)
		var start_age := int(seed.get("start_harvest_age_year", 4))
		if age < start_age:
			GameState.log_msg("%s: umur %d th, mulai panen di umur %d th." % [b.get("id"), age, start_age])
			continue
		var area := float(b.get("area_ha", 1.0))
		var health := float(b.get("health", 1.0))
		var kg := Agronomy.tbs_batch_kg(b)
		if kg <= 0.0:
			GameState.log_msg("%s: umur %d th belum produktif (tabel)." % [b.get("id"), age])
			continue
		var price := _sell_price(seed, health)
		var gross := int(kg * price)
		var hk := Agronomy.labor_hk("panen", area)
		var lab := Agronomy.labor_cost("panen", area)
		var net := gross - lab
		total_rev += net
		b["last_harvest_day"] = GameState.day
		GameState.log_msg("%s: panen %.0f kg (sehat %.0f%%) ke %s @ Rp%.0f/kg = Rp%s − %.1f HK panen (Rp%s) = Rp%s" % [
			b.get("id"), kg, health * 100.0, _buyer(), price, GameState._fmt(gross), hk, GameState._fmt(lab),
			GameState._fmt(net)])
	if total_rev > 0:
		GameState.earn(total_rev)
		GameState.mark_objective("harvested")
		GameState.log_msg("Total pendapatan panen (bersih): Rp%s" % GameState._fmt(total_rev))
	else:
		GameState.log_msg("Tidak ada blok siap panen (rotasi %d hari belum tercapai / belum cukup umur)." % TimeManager.harvest_rotation_days)

func _on_fertilize() -> void:
	if GameState.blocks.is_empty():
		GameState.log_msg("Belum ada blok.")
		return
	var discount := float(GameState.profile_mods().get("input_discount", 0.0))
	for b in GameState.blocks:
		var plan := Agronomy.fertilizer_plan(b)
		if plan.get("components", []).is_empty():
			GameState.log_msg("%s: tak ada rekomendasi pupuk utk umur ini." % b.get("id"))
			continue
		var area := float(b.get("area_ha", 1.0))
		var mat := int(round(float(plan.get("total_cost", 0)) * (1.0 - discount)))
		var hk := Agronomy.labor_hk("pupuk", area)
		var lab := Agronomy.labor_cost("pupuk", area)
		if not GameState.spend(mat + lab):
			continue
		Agronomy.apply_fertilize(b)
		GameState.mark_objective("fertilized")
		GameState.log_msg("%s: pupuk %d jenis — bahan Rp%s + %.1f HK (Rp%s) = Rp%s. Sehat %.0f%%" % [
			b.get("id"), plan.get("components", []).size(), GameState._fmt(mat), hk,
			GameState._fmt(lab), GameState._fmt(mat + lab), float(b.get("health", 1.0)) * 100.0])
	_refresh()

func _on_spray() -> void:
	if GameState.blocks.is_empty():
		GameState.log_msg("Belum ada blok.")
		return
	var loc := spray_location_opt.get_item_text(spray_location_opt.selected) if spray_location_opt.selected >= 0 else ""
	var weed := spray_weed_opt.get_item_text(spray_weed_opt.selected) if spray_weed_opt.selected >= 0 else ""
	var discount := float(GameState.profile_mods().get("input_discount", 0.0))
	for b in GameState.blocks:
		var plan := Agronomy.spray_plan(b, loc, weed)
		if not plan.get("found", false):
			GameState.log_msg("%s: tak ada norma semprot cocok (umur %d / %s / %s)." % [
				b.get("id"), GameState.age_years_of(b), loc, weed])
			continue
		var area := float(b.get("area_ha", 1.0))
		var mat := int(round(float(plan.get("total_cost", 0)) * (1.0 - discount)))
		var hk := Agronomy.labor_hk("semprot", area)
		var lab := Agronomy.labor_cost("semprot", area)
		if not GameState.spend(mat + lab):
			continue
		var eff := Agronomy.spray_effectiveness(true)
		var before := float(b.get("weed_level", 0.0))
		Agronomy.apply_spray(b, eff)
		GameState.mark_objective("sprayed")
		GameState.log_msg("%s: semprot %s/%s, %d bahan, %.0f L (%d tangki), cuaca %s, efektif %.0f%% — bahan Rp%s + %.1f HK (Rp%s). Gulma %.0f%%->%.0f%%" % [
			b.get("id"), loc, weed, plan.get("components", []).size(), float(plan.get("water_l", 0)),
			int(plan.get("tanks", 0)), GameState.weather, eff * 100.0, GameState._fmt(mat), hk, GameState._fmt(lab),
			before * 100.0, float(b.get("weed_level", 0)) * 100.0])
	_refresh()

func _on_inspect() -> void:
	var cost := int(Database.params.get("pest_inspection_cost_rp", 50000))
	var any := false
	for b in GameState.blocks:
		var pest = b.get("pest")
		if pest == null:
			continue
		any = true
		if bool(pest.get("diagnosed", false)):
			continue
		if not GameState.spend(cost):
			return
		pest["diagnosed"] = true
		var cat := Database.get_pest(String(pest.get("id", "")))
		var ingr: Array = cat.get("ingredients", [])
		var ingr_txt := ", ".join(ingr) if not ingr.is_empty() else "(non-kimia / sanitasi)"
		GameState.log_msg("%s: diagnosis = %s (%s). Metode: %s | bahan: %s." % [
			b.get("id"), cat.get("name"), cat.get("type"), cat.get("method"), ingr_txt])
	if not any:
		GameState.log_msg("Tidak ada gejala hama/penyakit.")
	_refresh()

func _on_treat_pest() -> void:
	var discount := float(GameState.profile_mods().get("input_discount", 0.0))
	var any := false
	for b in GameState.blocks:
		var plan := Agronomy.pest_treatment_plan(b)
		if not plan.get("has_pest", false):
			continue
		any = true
		var area := float(b.get("area_ha", 1.0))
		var mat := int(round(float(plan.get("cost", 0)) * (1.0 - discount)))
		var hk := Agronomy.labor_hk("hama", area)
		var lab := Agronomy.labor_cost("hama", area)
		var cost := mat + lab
		if not GameState.spend(cost):
			continue
		var correct := bool(plan.get("diagnosed", false))
		var eff := Agronomy.pest_effectiveness(correct)
		var curable := bool(plan.get("curable", true))
		var cleared := Agronomy.apply_pest_treatment(b, eff, curable)
		var waste := "" if correct else " — tanpa diagnosis, boros!"
		var cost_txt := "bahan Rp%s + %.1f HK (Rp%s)" % [GameState._fmt(mat), hk, GameState._fmt(lab)]
		if not curable:
			GameState.log_msg("%s: %s TIDAK bisa diberantas sekali aplikasi; sanitasi (%s) memperlambat. %s, efektif %.0f%%." % [
				b.get("id"), plan.get("name"), plan.get("method"), cost_txt, eff * 100.0])
		elif cleared:
			GameState.log_msg("%s: %s teratasi (%s). %s, efektif %.0f%%%s" % [
				b.get("id"), plan.get("name"), plan.get("method"), cost_txt, eff * 100.0, waste])
		else:
			GameState.log_msg("%s: %s ditekan tapi belum hilang. %s, efektif %.0f%%%s" % [
				b.get("id"), plan.get("name"), cost_txt, eff * 100.0, waste])
	if not any:
		GameState.log_msg("Tidak ada hama/penyakit untuk diobati.")
	_refresh()

func _on_menu() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _buyer() -> String:
	if sell_target_opt and sell_target_opt.selected >= 0:
		return sell_target_opt.get_item_text(sell_target_opt.selected).to_lower()
	return "pengepul"

func _sell_price(seed: Dictionary, health: float) -> float:
	return _price_for(_buyer(), seed, health)

# Harga jual TBS per pembeli (Fase 4):
#  - Pengepul: harga flat lebih rendah, abaikan rendemen & kualitas, tanpa transport.
#  - Pabrik: harga dasar penuh x rendemen x grade(kualitas) − transport/kg.
func _price_for(buyer: String, seed: Dictionary, health: float) -> float:
	var base := float(Database.params.get("tbs_price_rp_per_kg", 2800))
	if buyer == "pengepul":
		return base * float(Database.params.get("pengepul_price_factor", 0.85))
	var baseline := float(Database.params.get("rendemen_baseline_pct", 22.0))
	var sens := float(Database.params.get("rendemen_price_sensitivity", 1.5))
	var rendemen := float(seed.get("rendemen_pct", baseline))
	var rendemen_factor := 1.0 + (rendemen - baseline) * 0.01 * sens
	var gbase := float(Database.params.get("pabrik_grade_base", 0.90))
	var grade: float = gbase + (1.0 - gbase) * clamp(health, 0.0, 1.0)
	var transport := float(Database.params.get("transport_cost_rp_per_kg", 150))
	return max(base * rendemen_factor * grade - transport, 0.0)

# ---------------------------------------------------------------- Refresh / log
func _refresh() -> void:
	saldo_label.text = "Saldo: Rp%s" % GameState._fmt(GameState.cash)
	hari_label.text = "Hari ke-%d" % GameState.day
	if title_label:
		title_label.add_theme_color_override("font_color", GameState.applied_accent())
	if kebun_label:
		kebun_label.text = "🏡 " + GameState.display_kebun_name()
	var prof := Database.get_profile(GameState.profile_id)
	if profile_label:
		profile_label.text = "Profil: %s" % prof.get("name", "?")
	if weather_label:
		weather_label.text = "Cuaca hari ini: %s" % GameState.weather.capitalize()
	if forecast_label:
		var fc := TimeManager.forecast(GameState.forecast_days())
		forecast_label.text = ("Prakiraan %d hr: %s" % [fc.size(), ", ".join(fc)]) if not fc.is_empty() else ""
	_update_spray_hint()
	_update_market_hint()
	_update_mission()
	_update_blocks()

func _update_market_hint() -> void:
	if market_hint_label == null:
		return
	var seed: Dictionary
	var health := 1.0
	if not GameState.blocks.is_empty():
		seed = Database.get_seed(String(GameState.blocks[0].get("seed_id", "")))
		health = float(GameState.blocks[0].get("health", 1.0))
	else:
		seed = Database.get_seed("marihat_ppks")
	var pengepul := _price_for("pengepul", seed, health)
	var pabrik := _price_for("pabrik", seed, health)
	market_hint_label.text = "Harga/kg — Pengepul Rp%.0f | Pabrik Rp%.0f  (rendemen %s%%, kualitas %.0f%%)" % [
		pengepul, pabrik, str(seed.get("rendemen_pct", "?")), health * 100.0]

func _update_spray_hint() -> void:
	if spray_hint_label == null:
		return
	var eff := Agronomy.spray_effectiveness(true) * 100.0
	var txt := "Semprot hari ini (cuaca %s): perkiraan efektif ~%.0f%%." % [GameState.weather, eff]
	var fc := TimeManager.forecast(GameState.forecast_days())
	if GameState.weather == "hujan" and fc.has("cerah"):
		txt += "  ⚠ Hujan — tunda ke hari cerah dalam prakiraan."
	spray_hint_label.text = txt

func _update_mission() -> void:
	if mission_label == null:
		return
	var prof := Database.get_profile(GameState.profile_id)
	var txt := "[i]%s[/i]\n" % prof.get("tutorial", "")
	var done := 0
	for key in OBJ_LABELS:
		var ok := bool(GameState.objectives.get(key, false))
		if ok: done += 1
		txt += "%s %s\n" % ["[color=lime]✔[/color]" if ok else "▢", OBJ_LABELS[key]]
	if done == OBJ_LABELS.size():
		txt += "[color=lime][b]Misi awal selesai! Lanjutkan membangun kebunmu.[/b][/color]"
	mission_label.text = txt

func _update_blocks() -> void:
	var txt := ""
	if GameState.blocks.is_empty():
		txt = "[i]Belum ada blok. Beli & tanam dulu.[/i]"
	else:
		for b in GameState.blocks:
			var seed: Dictionary = Database.get_seed(b.get("seed_id"))
			var pest = b.get("pest")
			var pest_note := ""
			if pest != null:
				var cat := Database.get_pest(String(pest.get("id", "")))
				var nm: String = cat.get("name") if bool(pest.get("diagnosed", false)) else "? gejala (inspeksi!)"
				pest_note = " | [color=red]%s %.0f%%[/color]" % [nm, float(pest.get("level", 0)) * 100.0]
			txt += "[b]%s[/b] — %s | umur %d th | sehat %.0f%% | gulma %.0f%% | golden %d%s\n" % [
				b.get("id"), seed.get("variety_name", "?"),
				GameState.age_years_of(b), float(b.get("health", 1.0)) * 100.0,
				float(b.get("weed_level", 0)) * 100.0, int(b.get("golden_count", 0)), pest_note]
	blok_label.text = txt

func _on_cash_changed(_c: int) -> void:
	_refresh()

func _on_log(text: String) -> void:
	_log(text)

func _log(text: String) -> void:
	if log_label:
		log_label.append_text(text + "\n")

# ---------------------------------------------------------------- Self-test headless
func _run_selftest() -> void:
	GameState.log_msg("=== SELFTEST FASE 3 ===")
	GameState.log_msg("Profil: %s | prakiraan %d hari: %s" % [
		Database.get_profile(GameState.profile_id).get("name", "?"),
		GameState.forecast_days(), ", ".join(TimeManager.forecast(GameState.forecast_days()))])
	for i in Database.seeds.size():
		if Database.seeds[i].get("seed_id") == "marihat_ppks":
			seed_option.selected = i
	_on_plant()
	_advance(5 * 365)
	GameState.log_msg("Setelah 5 th: sehat %.0f%%, gulma %.0f%%" % [
		float(GameState.blocks[0].get("health", 1)) * 100.0, float(GameState.blocks[0].get("weed_level", 0)) * 100.0])
	_on_fertilize()
	# Pilih lokasi & gulma valid untuk umur ini (uji selektor manual)
	for i in spray_location_opt.item_count:
		if spray_location_opt.get_item_text(i) == "Piringan & pasar pikul":
			spray_location_opt.selected = i
	_populate_spray_weeds()
	for i in spray_weed_opt.item_count:
		if spray_weed_opt.get_item_text(i) == "Rumput + LCC":
			spray_weed_opt.selected = i
	_on_spray()
	GameState.blocks[0]["pest"] = { "id": "ulat_api", "level": 0.5, "diagnosed": false }
	_on_treat_pest()   # tanpa diagnosis
	_on_inspect()
	_on_treat_pest()   # dengan diagnosis
	# Fase 4: HK + jual ke Pabrik (grading)
	GameState.log_msg("HK panen (profil ini): %.2f = Rp%s" % [
		Agronomy.labor_hk("panen", 1.0), GameState._fmt(Agronomy.labor_cost("panen", 1.0))])
	for i in sell_target_opt.item_count:
		if sell_target_opt.get_item_text(i) == "Pabrik":
			sell_target_opt.selected = i
	_on_harvest()
	# Fase 6: kosmetik + kunjungan
	GameState.log_msg("Kosmetik gratis dimiliki: %d" % GameState.cosmetics_owned.size())
	GameState.buy_cosmetic("ui_senja"); GameState.apply_cosmetic("ui_senja")
	GameState.kebun_name = "Kebun Nadia"
	GameState.buy_cosmetic("id_emas"); GameState.apply_cosmetic("id_emas")
	GameState.log_msg("Tema accent=%s | nama tampil: %s" % [
		GameState.applied_accent().to_html(false), GameState.display_kebun_name()])
	GameState.export_kebun()
	var visited := GameState.start_visit()
	var vblocks: Array = GameState.visiting.get("blocks", [])
	GameState.log_msg("Kunjungi: %s | kebun=%s | blok=%d" % [
		str(visited), str(GameState.visiting.get("kebun_name")), vblocks.size()])
	GameState.end_visit()
	GameState.log_msg("Objektif selesai: %d/%d" % [
		GameState.objectives.values().count(true), GameState.objectives.size()])
	GameState.save_game()
	GameState.log_msg("has_save setelah simpan: %s" % str(GameState.has_save()))
	GameState.log_msg("Saldo akhir: Rp%s" % GameState._fmt(GameState.cash))
	GameState.log_msg("=== SELFTEST SELESAI ===")
	get_tree().quit()
