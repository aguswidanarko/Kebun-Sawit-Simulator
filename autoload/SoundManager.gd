extends Node
## SoundManager (autoload) — SFX terpusat, MURNI POLISH (tak ada efek gameplay).
## Sumber: Kenney "Interface Sounds" (CC0) — lihat assets/audio/sfx/LICENSE.txt
## & CREDITS.md utk atribusi. Dipasang via sinyal GameState (cash_changed,
## spend_failed, objective_changed, pest_appeared) + dipanggil langsung dari
## UIKit (klik tombol, toast, buka/tutup sheet, segmented tab).
##
## Pool kecil AudioStreamPlayer dipakai berganti-gantian (round-robin) supaya
## 2 suara yg nyaris bersamaan (mis. klik tombol lalu toast) tak saling
## memotong satu sama lain.

const SFX := {
	"click": "res://assets/audio/sfx/click_002.wav",         # klik tombol umum
	"confirm": "res://assets/audio/sfx/confirmation_002.wav", # dapat uang / sukses / misi selesai
	"error": "res://assets/audio/sfx/error_004.wav",          # dana tak cukup / aksi gagal
	"notify": "res://assets/audio/sfx/select_007.wav",        # toast/notifikasi ringan
	"open": "res://assets/audio/sfx/open_001.wav",            # buka sheet/panel
	"close": "res://assets/audio/sfx/close_001.wav",          # tutup sheet/panel
	"toggle": "res://assets/audio/sfx/toggle_002.wav",        # ganti tab segmented / keluar uang (beli)
	"drop": "res://assets/audio/sfx/drop_001.wav",            # TBS/brondolan jatuh
	"alert": "res://assets/audio/sfx/question_002.wav",       # gejala hama baru muncul
}

const POOL_SIZE := 6

var muted := false
var _cache: Dictionary = {}        # path(String) -> AudioStream
var _players: Array = []           # Array[AudioStreamPlayer]
var _pool_i := 0
var _last_cash := -1

func _ready() -> void:
	var bus := "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		add_child(p)
		_players.append(p)
	_last_cash = GameState.cash
	GameState.cash_changed.connect(_on_cash_changed)
	GameState.spend_failed.connect(func(_amount): play("error"))
	GameState.objective_changed.connect(func(_key): play("confirm"))
	GameState.pest_appeared.connect(func(_block_id): play("alert"))

func _on_cash_changed(new_cash: int) -> void:
	if new_cash > _last_cash:
		play("confirm")
	elif new_cash < _last_cash:
		play("toggle")
	_last_cash = new_cash

## Putar efek `key` (lihat SFX). Aman dipanggil dari mana saja — no-op kalau
## muted atau key/file tak ada (tak pernah error/crash krn suara hilang).
func play(key: String) -> void:
	if muted:
		return
	var path: String = SFX.get(key, "")
	if path == "" or not ResourceLoader.exists(path):
		return
	if not _cache.has(path):
		_cache[path] = load(path)
	var p: AudioStreamPlayer = _players[_pool_i]
	_pool_i = (_pool_i + 1) % _players.size()
	p.stream = _cache[path]
	p.play()

func set_muted(m: bool) -> void:
	muted = m

# --- shortcut semantik (enak dibaca di titik panggil) ---
func click() -> void: play("click")
func confirm() -> void: play("confirm")
func error() -> void: play("error")
func notify() -> void: play("notify")
func open_sheet() -> void: play("open")
func close_sheet() -> void: play("close")
func toggle() -> void: play("toggle")
func drop() -> void: play("drop")
func alert() -> void: play("alert")
