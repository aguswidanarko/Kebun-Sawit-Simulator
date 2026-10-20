extends Node
## PurchaseManager (autoload) — IAP modal kerja tambahan (UANG SUNGGUHAN, beda dari
## kosmetik yg pakai uang dalam game). Proyek ini BELUM pernah di-setup utk
## distribusi Android/iOS (tak ada export preset/akun toko saat kode ini
## ditulis), jadi real billing (Google Play Billing/Apple StoreKit) belum bisa
## tersambung. Arsitektur di sini SUDAH siap pakai begitu plugin billing asli
## dipasang (lihat _has_real_billing()) — sampai saat itu jalan di MODE SANDBOX
## (simulasi beli, instan sukses, TANPA uang sungguhan berpindah) supaya fitur
## bisa didemo/dites sekarang.
##
## CARA MENYAMBUNGKAN KE TOKO SUNGGUHAN (checklist nanti):
##  1. Export project Android (Project > Export > Android) dgn package name
##     yg SAMA dgn yg didaftarkan di Play Console.
##  2. Pasang plugin "Godot Google Play Billing" (godotengine asset library /
##     github.com/godotengine/godot-google-play-billing), aktifkan di preset.
##  3. Buat managed product di Play Console dgn id SAMA PERSIS seperti
##     PRODUCT_ID di bawah, harga Rp10.000.
##  4. _has_real_billing() otomatis mendeteksi plugin terpasang (cek
##     Engine.has_singleton) -> purchase() otomatis pakai jalur asli, mode
##     sandbox tak terpakai lagi. Tak perlu ubah kode layar manapun.

signal purchase_completed(product_id: String, sandbox: bool)
signal purchase_failed(product_id: String, reason: String)

const PRODUCT_ID := "modal_kerja_100jt"
const PRODUCT_PRICE_LABEL := "Rp10.000"   # harga toko (uang sungguhan) — diset di Play Console saat live
const PRODUCT_GRANT_RP := 100000000       # modal kerja yg didapat pemain (uang DALAM GAME)
const PRODUCT_NAME := "Tambahan Modal Kerja"
const PRODUCT_DESC := "Suntikan modal kerja instan Rp100.000.000 ke saldo kebun Anda."

var _billing_singleton_name := "GodotGooglePlayBilling"  # nama singleton plugin resmi, dicek via Engine
var _busy := false

func _has_real_billing() -> bool:
	return Engine.has_singleton(_billing_singleton_name)

func is_sandbox() -> bool:
	return not _has_real_billing()

## Mulai alur beli. UI harus disable tombol selama _busy (lihat purchase_completed/failed).
func purchase(product_id: String = PRODUCT_ID) -> void:
	if _busy:
		return
	_busy = true
	if _has_real_billing():
		_purchase_real(product_id)
	else:
		_purchase_sandbox(product_id)

## Jalur asli (dipanggil hanya kalau plugin billing terpasang — lihat checklist
## di atas). Kerangka panggilan standar godot-google-play-billing; sesuaikan
## nama method persis dgn versi plugin yg dipasang nanti.
func _purchase_real(product_id: String) -> void:
	var billing = Engine.get_singleton(_billing_singleton_name)
	if billing == null or not billing.has_method("purchase"):
		_busy = false
		purchase_failed.emit(product_id, "Plugin billing terpasang tapi API tak sesuai — cek versi plugin.")
		return
	if billing.has_signal("purchases_updated") and not billing.purchases_updated.is_connected(_on_real_purchases_updated):
		billing.purchases_updated.connect(_on_real_purchases_updated)
	billing.purchase(product_id)

func _on_real_purchases_updated(purchases: Array) -> void:
	_busy = false
	for p in purchases:
		var pid := String(p.get("product_id", PRODUCT_ID)) if p is Dictionary else PRODUCT_ID
		_grant(pid, false)

## Mode sandbox: sukses instan, DISIMPAN sbg riwayat lokal (bukan transaksi
## nyata) supaya UI bisa membedakan "sandbox" dari "live" di tampilan nota.
func _purchase_sandbox(product_id: String) -> void:
	await get_tree().create_timer(0.4).timeout   # jeda singkat, kesan "memproses"
	_busy = false
	_grant(product_id, true)

func _grant(product_id: String, sandbox: bool) -> void:
	GameState.earn(PRODUCT_GRANT_RP, "IAP: %s%s" % [PRODUCT_NAME, " (SANDBOX)" if sandbox else ""])
	GameState.record_purchase(product_id, sandbox)
	purchase_completed.emit(product_id, sandbox)
