extends Node
## LeaderboardManager (autoload) — Hall of Fame (profit tertinggi) ONLINE
## lintas pemain/device, via Firestore REST API (proyek Firebase "project-
## 3e24d919-f9bd-41ca-942"). Tak ada Firebase SDK resmi utk GDScript, jadi di
## sini dipanggil langsung lewat HTTPRequest ke endpoint REST Firestore:
## https://firebase.google.com/docs/firestore/use-rest-api
##
## PENTING — Firestore Security Rules proyek ini HARUS publish rule berikut
## (Firebase Console -> Firestore Database -> Rules) sebelum submit_score()/
## fetch_top() bisa jalan (default "production mode" menolak semua akses):
##
##   rules_version = '2';
##   service cloud.firestore {
##     match /databases/{database}/documents {
##       match /hall_of_fame_profit/{entry} {
##         allow read: if true;
##         allow create: if request.resource.data.keys().hasAll(['kebun_name','profile_id','profit','day'])
##           && request.resource.data.kebun_name is string && request.resource.data.kebun_name.size() <= 40
##           && request.resource.data.profile_id is string
##           && request.resource.data.profit is int
##           && request.resource.data.day is int;
##         allow update, delete: if false;
##       }
##     }
##   }
##
## Kalau request gagal (rules belum di-publish, tidak ada internet, dll),
## fetch_top() otomatis fallback ke rekor lokal (GameState.hall_of_fame_entries())
## supaya layar Hall of Fame tetap menampilkan sesuatu.

const PROJECT_ID := "project-3e24d919-f9bd-41ca-942"
const API_KEY := "AIzaSyAVoy4zFPM_MJJBm3E_8b1XqjudaE-Xfu4"
const COLLECTION := "hall_of_fame_profit"
const BASE_URL := "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % PROJECT_ID

## Kirim skor profit saat ini ke Firestore. Fire-and-forget (no-op kalau gagal
## — rekor pribadi sudah otomatis tercatat lokal lewat
## GameState.maybe_record_hall_of_fame() terlepas dari hasil ini).
func submit_score(profit: int) -> void:
	var entry := {
		"kebun_name": GameState.display_kebun_name(),
		"profile_id": GameState.profile_id,
		"profit": profit,
		"day": GameState.day,
	}
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, _c, _h, _b): http.queue_free())
	var url := "%s/%s?key=%s" % [BASE_URL, COLLECTION, API_KEY]
	var body := JSON.stringify({"fields": _to_firestore_fields(entry)})
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)

## Ambil daftar skor teratas dari Firestore (diurutkan profit tertinggi).
## Fallback ke rekor lokal kalau request gagal.
func fetch_top(limit: int = 20) -> Array:
	var http := HTTPRequest.new()
	add_child(http)
	var url := "%s:runQuery?key=%s" % [BASE_URL, API_KEY]
	var query := {
		"structuredQuery": {
			"from": [{"collectionId": COLLECTION}],
			"orderBy": [{"field": {"fieldPath": "profit"}, "direction": "DESCENDING"}],
			"limit": limit,
		}
	}
	var err := http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(query))
	if err != OK:
		http.queue_free()
		return GameState.hall_of_fame_entries().slice(0, limit)
	var result: Array = await http.request_completed
	http.queue_free()
	var code: int = result[1]
	var body: PackedByteArray = result[3]
	if code != 200:
		return GameState.hall_of_fame_entries().slice(0, limit)
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Array):
		return GameState.hall_of_fame_entries().slice(0, limit)
	var entries: Array = []
	for item in parsed:
		if item is Dictionary and item.has("document"):
			entries.append(_from_firestore_fields(item["document"].get("fields", {})))
	return entries

func _to_firestore_fields(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		var v = d[k]
		if v is int:
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
		elif v.has("stringValue"):
			out[k] = v["stringValue"]
	return out
