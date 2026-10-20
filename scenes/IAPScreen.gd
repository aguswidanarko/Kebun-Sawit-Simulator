extends Control
## Layar "Tambahan Modal Kerja" — IAP (UANG SUNGGUHAN, beda dari Toko Kosmetik
## yg pakai uang dalam game). Lihat autoload/PurchaseManager.gd utk arsitektur
## sandbox-vs-live & checklist penyambungan ke Google Play Billing sungguhan.

var saldo_label: Label
var banner: PanelContainer
var buy_btn: Button
var history_list: VBoxContainer

func _ready() -> void:
	_build()
	GameState.cash_changed.connect(func(_c): _refresh())
	PurchaseManager.purchase_completed.connect(_on_purchase_completed)
	PurchaseManager.purchase_failed.connect(_on_purchase_failed)

func _build() -> void:
	var root := VBoxContainer.new()
	root.anchor_right = 1.0; root.anchor_bottom = 1.0
	root.offset_left = 16; root.offset_top = 12; root.offset_right = -16; root.offset_bottom = -12
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var title := UIKit.label("Tambahan Modal Kerja", 22, UIKit.INK, 800)
	root.add_child(title)
	saldo_label = Label.new()
	root.add_child(saldo_label)

	banner = PanelContainer.new()
	root.add_child(banner)
	_refresh_banner()

	root.add_child(UIKit.rule())

	# Kartu produk
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.box(UIKit.SURFACE, UIKit.DIVIDER, 1, 14))
	root.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	card.add_child(cv)
	cv.add_child(UIKit.label(PurchaseManager.PRODUCT_NAME, 16, UIKit.INK, 800))
	var desc := UIKit.label(PurchaseManager.PRODUCT_DESC, 12, UIKit.N700)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(desc)
	cv.add_child(UIKit.label("Modal masuk: Rp%s" % GameState._fmt(PurchaseManager.PRODUCT_GRANT_RP), 13, UIKit.ACCENT_700, 600))
	buy_btn = UIKit.btn("Beli — %s" % PurchaseManager.PRODUCT_PRICE_LABEL, _on_buy_pressed, "primary", 15, 48)
	cv.add_child(buy_btn)

	root.add_child(UIKit.wrap(UIKit.meta("Harga toko (uang sungguhan) ditentukan Google Play/App Store saat aplikasi sudah terbit — label di atas adalah harga yang direncanakan.", 11)))

	root.add_child(UIKit.rule())
	root.add_child(UIKit.label("Riwayat Pembelian", 14, UIKit.INK, 800))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	history_list = VBoxContainer.new()
	history_list.add_theme_constant_override("separation", 4)
	scroll.add_child(history_list)

	root.add_child(UIKit.btn("← Kembali", func(): get_tree().change_scene_to_file("res://scenes/DashboardScreen.tscn")))
	_refresh()

func _refresh_banner() -> void:
	for c in banner.get_children():
		c.queue_free()
	var sandbox := PurchaseManager.is_sandbox()
	banner.add_theme_stylebox_override("panel", UIKit.box(
		UIKit.ACCENT_100 if sandbox else UIKit.SURFACE,
		UIKit.ACCENT_700 if sandbox else UIKit.DIVIDER, 1, 10))
	var txt := Label.new()
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.add_theme_font_size_override("font_size", 12)
	if sandbox:
		txt.text = "🧪 MODE SANDBOX — belum terhubung ke Google Play Billing (aplikasi belum di-export/terbit). Pembelian di bawah ini SIMULASI, tidak ada uang sungguhan yang berpindah, tapi modal kerja tetap benar-benar masuk ke saldo untuk keperluan uji coba."
		txt.add_theme_color_override("font_color", UIKit.ACCENT_800)
	else:
		txt.text = "✅ Terhubung ke toko aplikasi — pembelian akan memproses uang sungguhan."
		txt.add_theme_color_override("font_color", UIKit.INK)
	banner.add_child(txt)

func _refresh() -> void:
	saldo_label.text = "Saldo: Rp%s" % GameState._fmt(GameState.cash)
	for c in history_list.get_children():
		c.queue_free()
	if GameState.purchase_history.is_empty():
		history_list.add_child(UIKit.meta("Belum ada pembelian."))
		return
	for h in GameState.purchase_history:
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "Hari %d — +Rp%s%s" % [
			int(h.get("day", 0)), GameState._fmt(int(h.get("grant_rp", 0))),
			" (sandbox)" if bool(h.get("sandbox", true)) else ""]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		history_list.add_child(row)

func _on_buy_pressed() -> void:
	buy_btn.disabled = true
	buy_btn.text = "Memproses..."
	PurchaseManager.purchase()

func _on_purchase_completed(_product_id: String, sandbox: bool) -> void:
	buy_btn.disabled = false
	buy_btn.text = "Beli — %s" % PurchaseManager.PRODUCT_PRICE_LABEL
	UIKit.toast(self, "Modal kerja +Rp%s masuk%s!" % [
		GameState._fmt(PurchaseManager.PRODUCT_GRANT_RP), " (sandbox)" if sandbox else ""])
	_refresh()

func _on_purchase_failed(_product_id: String, reason: String) -> void:
	buy_btn.disabled = false
	buy_btn.text = "Beli — %s" % PurchaseManager.PRODUCT_PRICE_LABEL
	SoundManager.error()
	UIKit.toast(self, "Pembelian gagal: %s" % reason)
