# Kredit & Lisensi Aset

Game ini memakai aset pihak ketiga. Patuhi lisensi masing-masing sebelum rilis.
Aset Sketchfab umumnya **CC-BY** → **wajib mencantumkan nama pembuat + link + lisensi**.
Lengkapi nama pembuat dari halaman Sketchfab (kolom "Author") sebelum publikasi.

## Dipakai dalam build saat ini

| Aset | Dipakai sebagai | Sumber | Lisensi |
|------|-----------------|--------|---------|
| **Oil fruit palm** oleh **Aziz.Sisi.Akafomo** | Pohon sawit (`assets/models/palm/oil_palm.glb`) | https://sketchfab.com/3d-models/oil-fruit-palm-6afff2461fba466e8cfb735661ddf93f | **CC-BY** ✅ (dikonfirmasi — wajib cantumkan nama "Aziz.Sisi.Akafomo" di layar kredit) |
| **Stylized Nature MegaKit** (Quaternius) | Rumput/semak (gulma), pohon latar, jalan batu (`assets/models/nature/`) | https://quaternius.com | **CC0** (bebas, tanpa atribusi) |
| **Karakter "Animated Human"** (Quaternius) | Pemain di dunia 3D (`assets/models/character/human.glb`) | https://poly.pizza/m/c3Ibh9I3udk | **CC0** (rigged + animasi Idle/Walk/Run/Working) |
| **Tekstur tanah "aerial_grass_rock"** (Poly Haven) | Ground dunia 3D (`assets/textures/ground_*.jpg`) | https://polyhaven.com/a/aerial_grass_rock | **CC0** |
| **Palm Tree** (Quaternius) | Mahkota/fronds pohon sawit (`assets/models/palm/palm_tree.glb`) | https://poly.pizza/m/P0tgwyXBgr | **CC0** |
| **Animated Human / Worker / Man / Man in Suit** (Quaternius) | Karakter pemain + kostum (`assets/models/character/*.glb`) | poly.pizza/m/c3Ibh9I3udk, Yg2bQZO6Hj, HMnuH5geEG, mQnGoME1ez | **CC0** |
| **Pickup Truck** (Quaternius) | Kendaraan kosmetik (`assets/models/vehicle/pickup.glb`) | https://poly.pizza/m/qn4grQgHm8 | **CC0** |
| Buah sawit (rumpun merah) | Dibuat prosedural di kode (FarmWorld3D) | — | Milik proyek |
| **Foto latar kebun sawit** (`assets/bg/plantation*.jpg`, dipilih acak) | Latar belakang UI (menu/profil/permainan) | Pexels — Andhra Pradesh (30251970); Pok Rie (3246159, 1100636); Mikhail Nilov (6942688) | **Pexels License** (bebas komersial, tanpa atribusi wajib — tetap dicatat di sini) |
| **Kartu karakter** (`assets/portraits/arman.png`, `nadia.png`, `bima.png`) | Kartu hero di layar Pilih Pemain | Dibuat pemilik proyek (AI) | Milik proyek. CATATAN: ada watermark "Paint X Lite" — regenerasi versi bersih (tanpa watermark) sebelum rilis |
| **Foto hama/penyakit — Ulat Api, Kumbang Daun, Belalang, Landak, Monyet, Orangutan** (`assets/pests/{ulat_api,leaf_bettle,belalang,landak,monyet,orangutan}.jpg`, dirujuk dari `data/pest_catalog.json` field `image`) | Kartu identifikasi hama/penyakit (belum ada UI yang menampilkannya — field siap, tab Hama di DashboardScreen belum render foto) | Wikimedia Commons — Bernard DUPONT (ulat_api, belalang); Adam Julian Saputra (leaf_bettle); Rushenb (landak); Detravieso (monyet); Jefri Tarigan (orangutan) | **CC-BY-SA 2.0/4.0** — WAJIB atribusi nama fotografer + link sumber di layar kredit. Lihat catatan ShareAlike di bawah. |
| **Foto hama/penyakit — Ganoderma, Rayap, Tikus, Busuk Pucuk, Hawar Daun** (`assets/pests/{ganoderma,rayap,tikus,busuk_pucuk,hawar_daun}.jpg`, dirujuk dari `data/pest_catalog.json`) | Kartu identifikasi hama/penyakit | Koleksi foto pribadi pemilik proyek (ditambahkan manual ke `Asset/Asset Foto/Foto Baru/Foto Hama Penyakit/`) | Milik proyek — pastikan sumber asli foto (kalau diambil dari internet) tidak melanggar hak cipta pihak lain sebelum rilis komersial |
| **Foto Pasar Lahan** (`assets/bg/land_{h_sungai,h_dataran,h_rawa,b_s1,b_s2,b_eks}.jpg`, dirujuk dari `data/land_offers.json` field `image`) | Kartu lahan di layar Pasar Lahan (`LandMarket.gd`) | Pexels — Harsh Suthar (h_sungai), Tom Fisk (h_dataran), "K" (h_rawa), Bernd Dittrich (b_s1), Fred AUGÉ (b_s2), Daniel Ponomarev (b_eks) | **Pexels License** (bebas komersial, atribusi tidak wajib — tetap dicatat di sini) |
| **Angkong** (`assets/models/tools/angkong.obj` + `angkong.mtl`) | Model alat kerja kategori `alat_angkong` (`ang_std`/`ang_biru`/`ang_kayu`), `data/cosmetic_catalog.json` field `model` | Dibuat/ditambahkan pemilik proyek (`Asset/Asset baru/angkong.obj`) | Milik proyek. CATATAN: file `.mtl` aslinya hilang saat ditambahkan — dibuatkan ulang (`red_paint`/`rubber`/`steel`/`yellow_paint`, warna flat tanpa tekstur) agar bisa diimpor Godot. Belum ada kode yang me-retint model berdasarkan `payload.color` untuk varian biru/kayu — saat ini ketiga varian menampilkan warna `.mtl` yang sama (merah). |
| **Bibit Kelapa Sawit** (`assets/models/palm/bibit_sawit.obj` + `bibit_sawit.mtl`) | Model bibit polybag untuk item `pn`/`mn` (Pre-nursery & Main-nursery) di `data/merchant_inventory_start.json` & `merchant_stock.json`, field `model` | Dibuat/ditambahkan pemilik proyek (`Asset/Asset baru/bibit-kelapa-sawit.obj`) | Milik proyek. Sama seperti Angkong: `.mtl` asli hilang, dibuatkan ulang (`polybag_black`/`soil`/`stem_brown`/`rachis_green`/`leaf_green`, flat color). |
| **Kecambah Kelapa Sawit** (`assets/models/palm/kecambah_sawit.obj` + `.mtl`) | Model untuk item `kec_dam`/`kec_sain` (Kecambah DxP Damimas/SAIN) di `merchant_inventory_start.json` & `merchant_stock.json`, field `model` | Dibuat/ditambahkan pemilik proyek (`Asset/Asset baru/kecambah-kelapa-sawit.obj`) | Milik proyek. `.mtl` asli hilang, dibuatkan ulang (`shell_black`/`moss_green`/`fiber_brown`/`sprout_cream`/`sprout_tip`). Model anatomis germinasi (shell, radicle, plumule) — menutup gap yang sebelumnya dicatat "kecambah masih butuh model sendiri". |
| **Pisau Egrek** (`assets/models/tools/egrek.obj` + `.mtl`) | Model alat kerja kategori `alat_egrek` (`egr_std`/`egr_karbon`/`egr_pita`) di `cosmetic_catalog.json`, dan item `egrek_b`/`egrek_n` (merchant) | Dibuat/ditambahkan pemilik proyek (`Asset/Asset baru/pisau-egrek.obj`) | Milik proyek. `.mtl` asli hilang, dibuatkan ulang (`pole_black`/`rubber_black`/`socket_steel`/`blade_steel`). Model proper (galah + soket + pisau bulan sabit), bukan lagi perlu hack dari model chainsaw-pole generik seperti direncanakan di riset awal. |
| **Traktor Mini** (`assets/models/vehicle/traktor_mini.obj` + `.mtl`) | Model item `traktor` (merchant, kategori `kendaraan`) di `merchant_stock.json`, field `model` | Dibuat/ditambahkan pemilik proyek (`Asset/Asset baru/traktor-mini.obj`) | Milik proyek. `.mtl` asli hilang, dibuatkan ulang (`black_steel`/`lamp_red`/`rim_white`/`rubber`/`yellow_paint`). 104 part bernama (roda 4×, chassis, bak/tray) — menggantikan kandidat Sketchfab CC-BY "Small Tractor" yang direkomendasikan sebelumnya. |
| **Mesin Potong Rumput** (`assets/models/tools/mesin_potong_rumput.obj` + `.mtl`) | Model item `mesin_rumput` (kategori `alat`) di `data/merchant_inventory_start.json`, field `model` | Dibuat/ditambahkan pemilik proyek (`Asset/Asset baru/mesin-potong-rumput.obj`) | Milik proyek. `.mtl` asli hilang, dibuatkan ulang (`aluminium`/`black_plastic`/`blade_blue`/`orange_plastic`/`tank_white`, flat color). Brush cutter bahu lengkap (44 part bernama: tangki, mesin, poros fleksibel, bilah pemotong) — ini menutup gap yang sebelumnya "belum ketemu" di riset lisensi awal. |
| **Pasak Bumi, Jahe Merah, Sambiloto** (`assets/models/3d/medicinal_plants/{pasak_bumi,jahe_merah,sambiloto}.glb`) | Item `pasak`, `jahe` (di 2 file), `sambiloto` — field `model` | Dibuat/ditambahkan pemilik proyek (`Asset/Asset baru/{akar-pasak-bumi,jahe-merah,tanaman-sambiloto}.glb`) | Milik proyek. Format **glTF binary** — material sudah terbungkus di file (bukan `.obj`+`.mtl` terpisah), tidak ada masalah file hilang. `jahe-merah.glb` dipakai juga untuk "Bibit Jahe Merah" (`merchant_stock.json`) karena jahe diperbanyak dari potongan rimpang — bentuknya relevan untuk keduanya. |
| **Jamur Kuping, Jamur Tiram Raja** (`assets/models/3d/mushrooms/{jamur_kuping,jamur_tiram_raja}.glb`) | Item `kuping` (match persis) dan `tiram` (field `model`) | Dibuat/ditambahkan pemilik proyek (`Asset/Asset baru/{jamur-kuping,jamur-tiram-raja}.glb`) | Milik proyek, glTF binary. **CATATAN SPESIES**: `jamur-tiram-raja` (king oyster, *Pleurotus eryngii*) dipakai untuk item "Jamur Tiram" biasa (*Pleurotus ostreatus*) — kerabat dekat & mirip visual, tapi bukan spesies persis sama. Ganti kalau nanti ada model tiram biasa. |
| **Sprayer Punggung** (`assets/models/tools/sprayer.glb`) | Kategori kosmetik `alat_sprayer` (`spr_std`/`spr_kuning`/`spr_loreng`) + item merchant `sprayer_b`/`sprayer_n` | Dibuat/ditambahkan pemilik proyek (`Asset/Asset baru/knapsack-sprayer.glb`) | Milik proyek, glTF binary. Menyelesaikan verifikasi yang sebelumnya pending untuk kandidat Sketchfab "Pump Sprayer" (sekarang tidak relevan lagi). |
| **Lucide icon set** (37 ikon SVG, `assets/ui/icons/*.svg`) | Ikon tab bar (`UIKit.TABS` + `UIKit.icon()`) dan tersedia untuk tombol UI lain (lock, chevron, check, x, search, settings, dll — lihat daftar lengkap di repo) | https://github.com/lucide-icons/lucide (unduh langsung per-file dari `raw.githubusercontent.com/lucide-icons/lucide/main/icons/<nama>.svg`) | **ISC** (+ sebagian MIT dari Feather Icons) — bebas komersial, atribusi tidak wajib di UI. Teks lisensi disalin ke `assets/ui/LUCIDE_LICENSE.txt`. CATATAN: `stroke="currentColor"`/`fill="currentColor"` dinormalisasi ke `#ffffff` di tiap file supaya bisa di-tint lewat `TextureRect.modulate` (pola standar icon-font) — kalau update ke versi Lucide terbaru, ulangi langkah normalisasi ini. |
| **Baglog Jamur Tiram, Jangkrik, Kroto Semut, Madu Hutan** (`assets/models/3d/mushrooms/baglog_jamur.glb`, `3d/insects/{jangkrik,kroto_semut,madu_hutan}.glb`) | Item `baglog`, `jangkrik` (2 file), `kroto`, `madu_hutan` — field `model` | Dibuat/ditambahkan pemilik proyek (`Asset/Asset baru/{baglog-jamur,jangkrik,kroto-semut,madu-hutan}.glb`) | Milik proyek, glTF binary, material terbungkus. |
| **Batu Bacan, Kalimaya Banten, Berlian Banjar** (`assets/models/3d/gems/{batu_bacan,batu_kalimaya_banten,berlian_banjar_mentah}.glb`) | Item `batu_bacan`, `kalimaya`, `berlian_banjar` — field `model` | Dibuat/ditambahkan pemilik proyek (`Asset/Asset baru/{batu-bacan,batu-kalimaya-banten,berlian-banjar-mentah}.glb`) | Milik proyek, glTF binary. |
| **Burung Hantu, Ayam Jantan/Betina, Kambing, Sapi Bali** (`assets/models/3d/animals/{burung_hantu,ayam_jantan,ayam_betina_petelur,kambing,sapi_bali}.glb`) | Item `tyto`, `ayam_jantan`, `ayam_petelur` (`merchant_stock.json`); `kambing`/`sapi`/`jangkrik` juga di-mirror ke `merchant_inventory_start.json` (id sama, model sama) | Dibuat/ditambahkan pemilik proyek (`Asset/Asset baru/{burung-hantu,ayam-jantan,ayam-betina-petelur,kambing,sapi-bali}.glb`) | Milik proyek, glTF binary. |
| **Pickup Muatan Sawit, Mobil Pickup** (`assets/models/vehicle/{pickup_muatan_sawit,mobil_pick_up}.glb`) | `pickup_muatan_sawit.glb` → item `pikap_sawit`; `mobil_pick_up.glb` → item `pikap_b` ("Pikap Bak bekas", `merchant_inventory_start.json`) | Dibuat/ditambahkan pemilik proyek (`Asset/Asset baru/{pick-up-muatan-sawit,mobil-pick-up}.glb`) | Milik proyek, glTF binary. `pickup_muatan_sawit` sangat detail (202 mesh, bak berisi TBS/tandan buah segar built-in). **Keputusan saya**: `mobil-pick-up.glb` tidak ada id eksplisit menunggu di data, jadi saya pasang ke `pikap_b` (satu-satunya item pickup trade yang masih kosong model) — bukan menggantikan `pickup.glb` (Quaternius CC0) yang sudah dipakai `ken_pikap`/`pikap_n`. Koreksi kalau salah sasaran. |
| **Model 3D hama — Belalang, Landak, Monyet, Rayap Prajurit** (`assets/models/3d/pests/{belalang,landak,monyet,rayap_prajurit}.glb`) | Field `model` baru (paralel dengan `image`) di `pest_catalog.json` id `belalang`/`landak`/`monyet`/`rayap` | Dibuat/ditambahkan pemilik proyek (`Asset/Asset baru/{belalang,landak,monyet,rayap-prajurit}.glb`) | Milik proyek, glTF binary. **Field `model` ini baru** — belum ada kode UI yang membacanya untuk pest (beda dari `image` yang juga belum dirender di `_tab_hama()`, lihat poin lain). `rayap-prajurit` representasi kasta prajurit untuk pest id `rayap` (sama seperti alasan jamur-tiram-raja dipakai utk `tiram`). |
| **Kumbang Oryctes** (`assets/models/3d/pests/kumbang_oryctes.glb`) | **Belum di-wire** — tidak ada id pest yang cocok | Dibuat/ditambahkan pemilik proyek (`Asset/Asset baru/kumbang-oryctes.glb`) | Milik proyek, glTF binary. Oryctes rhinoceros (kumbang badak) adalah hama sawit nyata yang **belum ada di `pest_catalog.json` sama sekali** — bukan cuma kurang model, tapi datanya (appear_chance, damage_mult, method, ingredients) juga belum ada. Perlu keputusan desain, bukan sekadar pasang aset. |

**Belum dipasang — tidak ada item katalog yang cocok** (model sudah didownload ke `assets/models/3d/mushrooms/` tapi belum di-wire ke JSON manapun, supaya tidak salah-pasang): `jamur_kancing.glb` (jamur kancing/button mushroom) dan `jamur_shiitake.glb` (shiitake) — katalog saat ini hanya punya "Jamur Merang", "Jamur Tiram", "Jamur Kuping", "Jamur Lingzhi"; kancing & shiitake bukan salah satu dari itu (shiitake ≠ lingzhi/reishi, bentuknya beda jauh). Kalau item kancing/shiitake memang mau ditambah ke katalog, atau salah satu dimaksudkan sebagai pengganti merang/lingzhi, kasih tahu — supaya tidak saya tebak sendiri.
| **Motor Trail Kebun** (`assets/models/vehicle/motor_trail.obj` + `.mtl`) | Model item `trail` (kategori `kendaraan`) di `data/merchant_inventory_start.json`, field `model` | Dibuat/ditambahkan pemilik proyek (`Asset/Asset baru/motor-trail.obj`) | Milik proyek. `.mtl` asli hilang, dibuatkan ulang (`aluminium`/`black_plastic`/`engine_grey`/`orange_plastic`/`rubber`, flat color). Model motor trail lengkap (85 part: roda, suspensi, rangka, mesin, knalpot, radiator) — menggantikan kandidat Sketchfab CC-BY "KTM Dirt Bike" yang direkomendasikan sebelumnya. |
| **Kenney Interface Sounds** (9 file dipilih dari 100, `assets/audio/sfx/*.wav`) | Efek suara UI/gameplay (`autoload/SoundManager.gd`): klik tombol, dapat/keluar uang, toast, buka/tutup sheet, ganti tab, TBS jatuh, gejala hama | Dikemas ulang utk Godot oleh kontributor Godot (Calinou): https://github.com/Calinou/kenney-interface-sounds — asli dari https://kenney.nl/assets/interface-sounds | **CC0** (lihat `assets/audio/sfx/LICENSE.txt`, atribusi tidak wajib tapi dicatat di sini) |

✅ Lisensi & nama pembuat "Oil fruit palm" dikonfirmasi: **Aziz.Sisi.Akafomo**, CC-BY — boleh komersial dengan atribusi.

⚠️ Foto hama/penyakit CC-BY-SA punya klausul **ShareAlike**: kalau foto ini dipotong/diedit lalu
didistribusikan ulang sebagai aset game, salinan yang diedit itu harus tetap dilisensikan
CC-BY-SA + atribusi (tidak berarti seluruh game harus open source, hanya aset turunannya).

## Tersedia di folder Asset (belum dipakai / referensi)

| Aset | Sumber | Lisensi | Catatan |
|------|--------|---------|---------|
| Realistic Palm Tree 2 | https://sketchfab.com/3d-models/realistic-palm-tree-2-free-d05c8ffb6ec64a7184c4b673e21f7224 | CC-BY* | model dalam .rar |
| Potted Palm Tree | https://sketchfab.com/3d-models/potted-palm-tree-dadb3ed13e894bbaaff3735d0fc425a0 | CC-BY* | palm hias |
| CC0 props (watering can, jerry can, dll) | CC0Tree pack | CC0 | alat/ikon |
| **Sawit.jl** (model pertumbuhan sawit) | https://github.com/cbsteh/Sawit.jl | **MIT** | rujukan kalibrasi kurva produksi (bukan aset) |
| **OpenAcre** (farming sim Godot 4) | https://github.com/OpenAcre-Project/OpenAcre | **CC BY-SA 4.0** | ⚠️ ShareAlike — aman sbg referensi arsitektur, hati-hati menyalin aset/kode ke produk tertutup |
| Polygonal Mind CC0 models | https://github.com/ToxSam/open-source-3D-assets | CC0 | avatar/props |
| Kenney Prototype Kit | https://kenney.nl/assets/prototype-kit | CC0 | blocking/prototyping |

## Kandidat aset baru — hasil riset lisensi (belum didownload)

Hasil pencarian aset foto/3D untuk kelengkapan gap yang teridentifikasi di audit 2026-10-17.
Link di bawah **belum didownload ke project** — isi kolom "File tujuan" & centang setelah file
benar-benar ditaruh di `assets/`/`Asset Foto/` dan dipakai di data JSON terkait.

✅ Hama & Penyakit (8/8), Pasar Lahan (6/6), Angkong, Bibit Kelapa Sawit, Kecambah Kelapa Sawit,
Mesin Potong Rumput, Motor Trail, Pisau Egrek, dan Traktor Mini sudah terpasang — lihat tabel
"Dipakai dalam build saat ini" di atas (semuanya model buatan sendiri, bukan dari Sketchfab/Poly
Pizza — kandidat link lama untuk item-item ini sudah tidak relevan dan dihapus). Sisa kandidat
di bawah masih berupa 1 model dari sumber luar (belum terverifikasi).

⚠️ **Orphan ditemukan**: `Asset/Asset baru/tbs-kelapa-sawit.mtl` ada (material TBS/tandan buah
segar dengan warna asli dari exporter "three-d-stage": fruit_dark_red/fruit_red/fruit_orange/
spine_stalk_tan/stalk_cut_face) tapi **file `.obj`-nya tidak ikut ditambahkan** — kebalikan dari
pola biasanya (biasanya `.obj` ada, `.mtl` hilang). Belum bisa dipasang sampai geometrinya ada.

✅ Sprayer Punggung, Pasak Bumi, Jahe Merah, Sambiloto, Jamur Kuping, dan Jamur Tiram (pakai
tiram-raja) juga sudah terpasang — lihat tabel di atas. Kandidat Sketchfab/Poly Pizza untuk
item-item ini sudah tidak relevan dan dihapus dari daftar di bawah.

### Barang dagang Pedagang — masih kandidat (`data/merchant_inventory_start.json`, `merchant_stock.json`)
| Item | Sumber | Lisensi | Catatan |
|---|---|---|---|
| Kunyit | https://polyhaven.com/a/food_ginger_01 | **CC0** | model rimpang generik (reuse dari referensi jahe), recolor kuning |
| Jamur Merang / Jamur Lingzhi | https://poly.pizza/search/mushroom (Quaternius) | **CC0** | belum ada model buatan sendiri utk 2 item ini (kancing & shiitake yang masuk bukan match) |
| Akik Kecubung / Batu Bacan / Intan | https://poly.pizza/bundle/Pirate-kit-0q5ulmIYqQ (mesh "Gem") | **CC0** | 3 varian warna dari 1 bundle |
| Sapi Bali | https://poly.pizza/m/5XSc2Fka3F | **CC0** | — |
| Ayam Kampung | https://poly.pizza/m/1YE8U35HXsI | CC-BY | — |
| Kambing | https://poly.pizza/search/goat (pilih varian "Poly by Google") | CC-BY | cek kreator saat download, hindari varian tak berlisensi jelas |
| Madu Kelulut (stup) | https://sketchfab.com/3d-models/bee-hive-5ac5d5a85d0d41d396565718c0ba7ac3 | CC-BY | alternatif: peti kayu CC0 Kenney sbg placeholder |
| Kroto (telur rangrang) | https://poly.pizza/m/2YvCk4p0xdH ("Ant") | CC-BY | pengganti sementara, bukan telur semut |
| Jangkrik | poly.pizza/search/insect (grasshopper, "Poly by Google") | CC-BY | pengganti sementara, bukan jangkrik asli |

✅ Lucide icon set (37 ikon) sudah terpasang — lihat tabel "Dipakai dalam build saat ini" di atas.

## Kewajiban sebelum rilis
1. Lengkapi **nama pembuat** aset CC-BY (Sketchfab) di tabel ini + di layar kredit game.
2. Jangan menyalin aset/kode **OpenAcre** (CC BY-SA) ke produk komersial tertutup.
3. Simpan salinan teks lisensi untuk tiap aset yang dipakai.
4. Setelah aset 3D di bagian "Kandidat" benar-benar didownload: pindahkan ke tabel
   "Dipakai dalam build saat ini", isi path file tujuan, dan tambahkan baris atribusi kreator
   di layar kredit in-game untuk item berlisensi CC-BY/CC-BY-SA.
5. Tambahkan layar/menu "Kredit" in-game yang menampilkan atribusi fotografer Wikimedia
   (6 foto hama CC-BY-SA) — saat ini baru tercatat di file ini, belum tampil di UI game.
6. Tab "Hama" di `DashboardScreen.gd` belum merender field `image` dari `pest_catalog.json` —
   field datanya sudah siap, tinggal tambah `TextureRect` di `_tab_hama()` kalau mau ditampilkan.
7. Model buatan sendiri (Angkong, Bibit & Kecambah Kelapa Sawit, Mesin Potong Rumput, Motor Trail,
   Pisau Egrek, Traktor Mini) semua dikirim tanpa file `.mtl` — sudah dibuatkan ulang dengan warna
   flat berdasarkan nama material di `.obj`. Kalau ada file `.mtl`/tekstur asli menyusul, timpa
   yang dibuat ulang ini.
8. ✅ **Selesai**: `MerchantScreen.gd` sekarang merender field `model` barang dagang via
   `UIKit.model_thumb()` (SubViewport 3D, `UPDATE_WHEN_VISIBLE`), fallback ke label kategori kalau
   item tidak punya `model`. Diverifikasi lewat screenshot render nyata (bukan cuma headless) untuk
   ketujuh model di atas — semua tampil benar & berbeda satu sama lain di layar Pedagang.
9. **Bug yang ketemu & diperbaiki saat verifikasi**: `SubViewport` untuk thumbnail wajib set
   `own_world_3d = true`. Tanpa itu, banyak `SubViewport` yang dibuat di frame yang sama
   diam-diam berbagi `World3D` default — hasilnya semua thumbnail KECUALI satu menampilkan
   render dari model/kamera TERAKHIR yang dibuat (bukan model masing-masing). Ini baru ketahuan
   dari screenshot nyata multi-item, bukan dari headless check atau baca kode saja — kalau nanti
   menambah helper render 3D serupa di tempat lain, ingat pola ini.
10. **Format `.glb` (glTF binary) lebih aman dari `.obj`+`.mtl`**: 8 aset belakangan (Pasak Bumi,
    Jahe Merah, Sambiloto, 4 jamur, Sprayer) dikirim sebagai `.glb` — material sudah terbungkus di
    satu file, jadi tidak ada risiko "file `.mtl` ketinggalan" seperti 7 aset `.obj` sebelumnya.
    Kalau menambah aset baru ke depan, minta format `.glb` kalau memungkinkan.
11. `jamur_kancing.glb` dan `jamur_shiitake.glb` sudah ada di `assets/models/3d/mushrooms/` tapi
    **belum di-wire ke JSON manapun** — tidak ada item katalog yang cocok (katalog hanya punya
    Merang/Tiram/Kuping/Lingzhi). Tunggu keputusan: tambah item baru, atau salah satu jadi
    pengganti model Merang/Lingzhi yang belum ada.
12. ✅ **Emoji→ikon Lucide diganti di semua slot ikon dedicated** (tombol, glyph berdiri sendiri)
    di layar-layar live: `UIKit.tabbar()` (6), `UIKit.weather_icon()` + `CuacaScreen.gd` (icon
    cuaca besar, 5 sel prakiraan + lock, baris tabel dampak cuaca), `DashboardScreen.gd` (strip
    cuaca, 3 tombol header shirt/shopping-bag/menu, 4 tombol tutup "✕" via `UIKit.close_btn()`
    baru, tombol "Masuk blok" + "Mulai pembibitan" pakai `Button.icon` native +
    `icon_normal_color` theme override), `MerchantScreen.gd` (potret pedagang), `CosmeticShop.gd`
    (status "dipakai"), `FarmWorld3D.gd` (tombol Aksi + 5 tombol panel aksi lapangan), `Story.gd`
    (tombol preview 3D), `SosialScreen.gd` (tombol tutup kunjungan). Semua diverifikasi lewat
    screenshot render nyata, bukan cuma headless check.
13. **Kebijakan yang dipakai**: emoji yang MENYATU di dalam teks dinamis/log (mis. `log_msg("⚠ ...")`
    di `GameState.gd`/`Agronomy.gd`, status "✓ Main Nursery siap" di dalam `UIKit.meta()`, badge
    "★N Golden" di kartu Sosial) **sengaja tidak diganti** — itu teks naratif/status, bukan slot
    ikon dedicated, dan mengganti perlu merombak jadi RichText `[img]` atau container campuran
    yang berisiko lebih tinggi untuk nilai visual yang kecil. `Main.gd` (UI lama/dev-only, bukan
    alur default pemain) & `ProfileSelect.gd` emoji fallback (tak pernah ketrigger — ketiga profil
    sudah punya portrait asli) juga dilewati.
14. **Bug ketemu & diperbaiki saat verifikasi**: `CosmeticShop.gd` sempat rusak total (teks
    "dipakai" merender vertikal satu-huruf-per-baris) gara-gara ikon ditaruh di dalam
    `HBoxContainer` bersarang tanpa `size_flags_horizontal = SIZE_SHRINK_CENTER` di sebelah Label
    ber-autowrap — ketahuan HANYA karena dibandingkan dengan screenshot sebelum/sesudah perubahan,
    bukan dari baca kode atau headless check (keduanya bersih tanpa error). Pola amannya: taruh
    ikon+label sebagai **sibling langsung** (bukan dibungkus container baru) dan selalu set
    `size_flags_horizontal/vertical = SIZE_SHRINK_CENTER` di ikon saat ada sibling ber-autowrap.
15. 31 ikon Lucide lain sudah terdownload ke `assets/ui/icons/` siap pakai (`star`, `flag`,
    `triangle-alert`, `book-open`, `clipboard-list`, `palette`, `upload`, `house`,
    `chevron-left`, `chevron-right`, `fast-forward`, `rotate-ccw`, `rotate-cw`, `hand`, dll) tapi
    belum ada slot pemakaian live untuknya (★/⚠/📘 dkk di atas sengaja dibiarkan teks per poin 13).
16. **Bug kedua ketemu & diperbaiki (lebih serius)**: `UIKit.model_thumb()` memakai `Camera3D`
    dengan `near`/`far` DEFAULT Godot (`near=0.05`). Model yang dimodelkan di skala asli
    milimeter/sentimeter (mis. `rayap_prajurit.glb`, radius AABB ≈ 0,006 unit — ~175× lebih kecil
    dari model lain yang rata-rata ~1 unit) menghasilkan jarak kamera (~0,025) LEBIH DEKAT dari
    near plane default → seluruh model ter-clip habis, thumbnail blanko total, **tanpa error
    apa pun** (bukan crash, bukan warning — render sukses tapi isinya kosong). Baru ketahuan
    karena render 19 model sekaligus dalam satu grid dan membandingkan satu per satu; kalau cuma
    dites satu model dalam isolasi tanpa pembanding, blanko ini mudah terlewat dianggap "sudah
    beres". Fix: `cam.near`/`cam.far` sekarang dihitung relatif ke `dist`/`radius` objek, bukan
    nilai tetap — aman untuk model skala berapa pun (milimeter sampai meter).
17. Model dari batch ini (19 file: hewan ternak, serangga, batu permata, kendaraan, 4 model hama)
    semua format glTF binary, material terbungkus, tidak ada file hilang. Semua diverifikasi
    render per-model via grid thumbnail + layar Pedagang sungguhan setelah fix di atas.
