extends Node
## LeaderboardManager (autoload) — Hall of Fame (profit tertinggi) ONLINE
## lintas pemain/device, via Firestore REST API. Tak ada Firebase SDK resmi utk
## GDScript, jadi di sini dipanggil langsung lewat HTTPRequest ke endpoint REST:
## https://firebase.google.com/docs/firestore/use-rest-api
##
## KEAMANAN — baca docs/FIREBASE_SECURITY.md sebelum mengubah file ini.
## Ringkasnya:
##   1. PROJECT_ID + API_KEY di bawah BUKAN rahasia. Menurut dokumentasi resmi
##      Firebase, API key hanya mengidentifikasi proyek — bukan otorisasi.
##      Otorisasi 100% ditentukan Firestore Security Rules. Jadi key ini aman
##      ikut terkompilasi ke APK; yang TIDAK aman adalah rules yang longgar.
##      https://firebase.google.com/docs/projects/api-keys
##   2. Rules proyek ini ada di file firestore.rules (root project) dan HARUS
##      sudah di-publish, serta Anonymous Authentication HARUS sudah di-enable
##      di Firebase Console, sebelum submit_score()/fetch_top() bisa jalan.
##   3. Setiap request dikirim dengan ID token hasil anonymous sign-in, sehingga
##      request.auth.uid terisi dan dipakai sebagai ID dokumen: satu entri per
##      pemain, tidak bisa menimpa entri pemain lain.
##   4. Beberapa konstanta di bawah HARUS sinkron dengan firestore.rules
##      (MAX_FETCH_LIMIT, MAX_PROFIT, MAX_DAY, MAX_NAME_LEN).
##
## Kalau request gagal (rules belum di-publish, anonymous auth belum aktif,
## tidak ada internet, dll), fetch_top() otomatis fallback ke rekor lokal
## (GameState.hall_of_fame_entries()) supaya layar Hall of Fame tetap
## menampilkan sesuatu, dan submit_score() diam saja (no-op).

const PROJECT_ID := "project-3e24d919-f9bd-41ca-942"
## Identifier publik, bukan secret — lihat catatan keamanan di atas.
const API_KEY := "AIzaSyAVoy4zFPM_MJJBm3E_8b1XqjudaE-Xfu4"
const COLLECTION := "hall_of_fame_profit"
const BASE_URL := "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % PROJECT_ID
const SIGNUP_URL := "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=%s" % API_KEY
const REFRESH_URL := "https://securetoken.googleapis.com/v1/token?key=%s" % API_KEY

## Identitas anonim disimpan lokal supaya entri leaderboard pemain tetap sama
## setelah game ditutup. Isinya refresh token akun anonim (bukan kredensial
## bernilai — akun ini tidak punya data lain selain 1 baris skor).
const CRED_PATH := "user://leaderboard_cred.json"

## Harus <= batas `request.query.limit` di firestore.rules.
const MAX_FETCH_LIMIT := 50
## Harus sama dengan batas di firestore.rules (validEntry()).
const MAX_PROFIT := 1_000_000_000_000
const MAX_DAY := 100_000
const MAX_NAME_LEN := 40

## Jeda minimum antar-submit ke Firestore. GameState.maybe_record_hall_of_fame()
## dipanggil setiap kali cash berubah, jadi tanpa throttle ini satu sesi bermain
## bisa menghasilkan ratusan write (boros kuota + tagihan). Submit terakhir
## selalu menyusul lewat _flush_timer, jadi tidak ada skor yang hilang.
const SUBMIT_COOLDOWN_SEC := 60.0
## Kalau auth gagal (offline / rules belum siap), jangan hammer endpoint.
const AUTH_RETRY_BACKOFF_SEC := 120.0

signal _auth_finished

var _uid: String = ""
var _id_token: String = ""
var _refresh_token: String = ""
var _token_expiry: float = 0.0
var _auth_busy: bool = false
var _auth_retry_after: float = 0.0

var _best_submitted: int = -1
var _pending_profit: int = -1
var _pending_day: int = 1
var _last_submit_at: float = 0.0
var _flush_timer: Timer

func _ready() -> void:
	_flush_timer = Timer.new()
	_flush_timer.one_shot = true
	_flush_timer.timeout.connect(_flush_pending)
	add_child(_flush_timer)
	_load_credentials()

# --- Submit ---------------------------------------------------------------

## Catat skor profit saat ini untuk dikirim ke Firestore. Aman dipanggil sesering
## apa pun: hanya profit yang lebih tinggi dari submit terakhir yang dikirim, dan
## pengiriman di-throttle ke 1x per SUBMIT_COOLDOWN_SEC. Fire-and-forget — rekor
## pribadi sudah tercatat lokal lewat GameState.maybe_record_hall_of_fame()
## terlepas dari hasil request ini.
func submit_score(profit: int) -> void:
	if profit <= 0 or profit > MAX_PROFIT:
		return
	if profit <= _best_submitted or profit <= _pending_profit:
		return
	_pending_profit = profit
	_pending_day = clampi(GameState.day, 1, MAX_DAY)
	var elapsed := Time.get_unix_time_from_system() - _last_submit_at
	if elapsed >= SUBMIT_COOLDOWN_SEC:
		_flush_pending()
	elif _flush_timer.is_stopped():
		_flush_timer.start(SUBMIT_COOLDOWN_SEC - elapsed)

func _flush_pending() -> void:
	if _pending_profit <= _best_submitted:
		_pending_profit = -1
		return
	var profit := _pending_profit
	var day := _pending_day
	_pending_profit = -1
	# Set sebelum await supaya submit yang masuk saat request berjalan tetap
	# kena throttle.
	_last_submit_at = Time.get_unix_time_from_system()
	if not await _ensure_auth():
		return
	var entry := {
		"kebun_name": _clamp_name(GameState.display_player_name()),
		"profile_id": _clamp_name(GameState.profile_id),
		"profit": profit,
		"day": day,
		"last_write": {"timestampValue": Time.get_datetime_string_from_system(true) + "Z"},
	}
	if entry["kebun_name"] == "" or entry["profile_id"] == "":
		return
	# PATCH tanpa updateMask = tulis-ulang seluruh dokumen (dan membuatnya kalau
	# belum ada). ID dokumen = UID, jadi satu pemain hanya punya satu entri.
	var url := "%s/%s/%s?key=%s" % [BASE_URL, COLLECTION, _uid, API_KEY]
	var res := await _request_json(url, HTTPClient.METHOD_PATCH, {"fields": _to_firestore_fields(entry)})
	# 403 di sini normal & diharapkan: rules menolak skor yang tidak lebih tinggi.
	if int(res["code"]) == 200:
		_best_submitted = profit

# --- Fetch ----------------------------------------------------------------

## true kalau fetch_top() terakhir benar-benar mendapat data dari server.
## false = sedang menampilkan rekor lokal (offline / rules belum dipublish /
## anonymous auth belum diaktifkan). Dipakai UI untuk memberi tahu pemain,
## supaya rekor lokal tidak disalahartikan sebagai peringkat global.
var last_fetch_online: bool = false

## Ambil daftar skor teratas dari Firestore (diurutkan profit tertinggi).
## Fallback ke rekor lokal kalau request gagal — cek last_fetch_online.
func fetch_top(limit: int = 20) -> Array:
	var capped := clampi(limit, 1, MAX_FETCH_LIMIT)
	last_fetch_online = false
	if not await _ensure_auth():
		return _local_fallback(capped)
	var query := {
		"structuredQuery": {
			"from": [{"collectionId": COLLECTION}],
			"orderBy": [{"field": {"fieldPath": "profit"}, "direction": "DESCENDING"}],
			"limit": capped,
		}
	}
	var url := "%s:runQuery?key=%s" % [BASE_URL, API_KEY]
	var res := await _request_json(url, HTTPClient.METHOD_POST, query)
	if int(res["code"]) != 200 or not (res["data"] is Array):
		return _local_fallback(capped)
	var entries: Array = []
	for item in res["data"]:
		if item is Dictionary and item.has("document"):
			entries.append(_from_firestore_fields(item["document"].get("fields", {})))
	# Koleksi kosong (belum ada pemain yang submit) tetap dihitung ONLINE —
	# request-nya sukses, datanya saja yang belum ada. Membedakan ini penting:
	# "belum ada rekor global" != "gagal terhubung".
	last_fetch_online = true
	return entries

func _local_fallback(limit: int) -> Array:
	return GameState.hall_of_fame_entries().slice(0, limit)

## Pangkas nama agar <= MAX_NAME_LEN **byte** UTF-8, bukan karakter.
## display_player_name() mengandung emoji badge (kebun_badge()), dan `size()`
## pada string di Firestore Rules menghitung byte — nama 40 karakter beremoji
## bisa jadi >40 byte dan ditolak server tanpa pesan yang jelas.
func _clamp_name(s: String) -> String:
	var out := s.strip_edges()
	while out.length() > 0 and out.to_utf8_buffer().size() > MAX_NAME_LEN:
		out = out.substr(0, out.length() - 1).strip_edges()
	return out

# --- Anonymous auth (REST, tanpa Firebase SDK) ----------------------------

## Pastikan ada ID token valid. true kalau siap dipakai.
func _ensure_auth() -> bool:
	if _is_token_valid():
		return true
	if _auth_busy:
		await _auth_finished
		return _is_token_valid()
	if Time.get_unix_time_from_system() < _auth_retry_after:
		return false
	_auth_busy = true
	var ok := await _authenticate()
	_auth_busy = false
	if not ok:
		_auth_retry_after = Time.get_unix_time_from_system() + AUTH_RETRY_BACKOFF_SEC
	_auth_finished.emit()
	return ok

func _is_token_valid() -> bool:
	return _id_token != "" and _uid != "" and Time.get_unix_time_from_system() < _token_expiry

func _authenticate() -> bool:
	if _refresh_token != "" and await _refresh_session():
		return true
	# Refresh token tidak valid lagi (akun anonim dihapus / auto-cleanup 30 hari).
	_refresh_token = ""
	_uid = ""
	return await _sign_up_anonymous()

func _sign_up_anonymous() -> bool:
	var res := await _request_json(SIGNUP_URL, HTTPClient.METHOD_POST, {"returnSecureToken": true}, false)
	var data = res["data"]
	if int(res["code"]) != 200 or not (data is Dictionary):
		return false
	_apply_session(str(data.get("idToken", "")), str(data.get("refreshToken", "")),
		str(data.get("localId", "")), int(data.get("expiresIn", 3600)))
	if _is_token_valid():
		_save_credentials()
		return true
	return false

func _refresh_session() -> bool:
	var http := HTTPRequest.new()
	add_child(http)
	var body := "grant_type=refresh_token&refresh_token=%s" % _refresh_token.uri_encode()
	var err := http.request(REFRESH_URL, ["Content-Type: application/x-www-form-urlencoded"],
		HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		return false
	var result: Array = await http.request_completed
	http.queue_free()
	if int(result[1]) != 200:
		return false
	var raw: PackedByteArray = result[3]
	var data = JSON.parse_string(raw.get_string_from_utf8())
	if not (data is Dictionary):
		return false
	_apply_session(str(data.get("id_token", "")), str(data.get("refresh_token", _refresh_token)),
		str(data.get("user_id", _uid)), int(str(data.get("expires_in", "3600"))))
	if _is_token_valid():
		_save_credentials()
		return true
	return false

func _apply_session(id_token: String, refresh_token: String, uid: String, expires_in: int) -> void:
	_id_token = id_token
	if refresh_token != "":
		_refresh_token = refresh_token
	if uid != "":
		_uid = uid
	# Pangkas 5 menit supaya token tidak kedaluwarsa di tengah request.
	_token_expiry = Time.get_unix_time_from_system() + maxf(60.0, float(expires_in) - 300.0)

func _load_credentials() -> void:
	if not FileAccess.file_exists(CRED_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(CRED_PATH))
	if data is Dictionary:
		_refresh_token = str(data.get("refresh_token", ""))
		_uid = str(data.get("uid", ""))

func _save_credentials() -> void:
	var f := FileAccess.open(CRED_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"refresh_token": _refresh_token, "uid": _uid}))
	f.close()

# --- HTTP / Firestore helpers --------------------------------------------

## with_auth=false dipakai untuk endpoint sign-in (belum punya token).
func _request_json(url: String, method: int, body_dict, with_auth: bool = true) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	var headers := ["Content-Type: application/json"]
	if with_auth and _id_token != "":
		headers.append("Authorization: Bearer %s" % _id_token)
	var body := JSON.stringify(body_dict) if body_dict != null else ""
	var err := http.request(url, headers, method, body)
	if err != OK:
		http.queue_free()
		return {"code": 0, "data": null}
	var result: Array = await http.request_completed
	http.queue_free()
	var raw: PackedByteArray = result[3]
	return {"code": int(result[1]), "data": JSON.parse_string(raw.get_string_from_utf8())}

func _to_firestore_fields(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		var v = d[k]
		if v is Dictionary:
			out[k] = v  # sudah dalam bentuk Firestore Value (mis. timestampValue)
		elif v is int:
			out[k] = {"integerValue": str(v)}
		elif v is float:
			out[k] = {"doubleValue": v}
		else:
			out[k] = {"stringValue": str(v)}
	return out

func _from_firestore_fields(fields: Dictionary) -> Dictionary:
	var out := {}
	for k in fields:
		var v: Dictionary = fields[k]
		if v.has("integerValue"):
			out[k] = int(v["integerValue"])
		elif v.has("doubleValue"):
			out[k] = v["doubleValue"]
		elif v.has("timestampValue"):
			out[k] = str(v["timestampValue"])
		elif v.has("stringValue"):
			out[k] = v["stringValue"]
	return out
