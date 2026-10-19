# Kebun Sawit Simulator — Proyek Godot (Scaffold MVP)

Struktur awal proyek Godot 4.7 untuk simulator kebun sawit. **Data-driven**: semua
norma (produksi, pupuk, semprot, kecambah, profil) berada di file JSON di `data/`,
sehingga nilai bisa diubah **tanpa menyentuh kode** (sesuai acceptance criteria GDD).

## Cara membuka

1. Install **Godot Engine 4.7.2** (versi GDScript biasa, arm64 untuk Mac Apple Silicon).
2. Buka Godot → **Import** → pilih file `project.godot` di folder ini.
3. Tekan **▶ (Run / F5)**. Scene `scenes/Main.tscn` akan jalan.

Yang bisa dicoba: pilih kecambah → **Beli & Tanam 1 ha** → **Lanjut Hari** →
**Pupuk** / **Semprot Gulma** → **Panen** → TBS terjual otomatis. Ada **Simpan/Muat** (offline).

**Fase 2 (budidaya) aktif:** kesehatan tanaman turun bila gulma dibiarkan / pupuk telat;
cuaca harian (cerah/mendung/hujan) memengaruhi efektivitas semprot & laju gulma; biaya
pupuk & semprot dihitung dari data workbook asli; hasil panen menskala kesehatan.

**Hama/penyakit:** gejala muncul acak (dipengaruhi umur, cuaca, varietas). Harus
**Inspeksi** dulu untuk diagnosis — mengobati tanpa diagnosis = boros (efektivitas rendah).
**Ganoderma** tidak bisa diberantas satu aplikasi (hanya sanitasi memperlambat; varietas
Topaz GT lebih tahan) — sesuai prinsip edukasi GDD §6.

**Prakiraan cuaca:** profil **Nadia** melihat 5 hari ke depan (buff nyata untuk
menjadwalkan semprot saat cerah); profil lain hanya 1 hari.

**Fase 3:** menu utama + **pemilihan profil** (3 kartu dengan prolog/buff/tantangan) +
**misi awal** (tutorial action-based 5 langkah) + **save/load lengkap** (profil, cuaca,
objektif, semua kondisi blok). **UX budidaya:** semprot kini pilih **lokasi & gulma manual**
(dari norma asli), dengan **indikator prakiraan** (perkiraan efektivitas + saran tunda bila hujan).

**Fase 4 — tenaga kerja & pasar:**
- **HK (hari kerja):** setiap pekerjaan (pupuk/semprot/obati/panen) menambah biaya tenaga
  kerja = HK × upah. **Buff Arman** (kerja +10% cepat) mengurangi HK → biaya lebih murah,
  terasa di skala berapa pun (HK pecahan).
- **Pasar TBS:** jual ke **Pengepul** (harga flat lebih rendah, tanpa transport/sortasi) atau
  **Pabrik** (harga penuh × rendemen × grade kualitas − transport). Indikator membandingkan
  harga kedua pembeli. Rendemen & kesehatan kini benar-benar bermakna saat jual ke pabrik.

**Fase 5 — visual 3D (MVP):** tombol **"Lihat Kebun 3D"** di layar permainan membuka
`Plantation3D` — kebun ber-grid memakai model **sawit berbuah** (oil_palm.glb) di atas
tanah, dengan **pohon latar & rumput** (Stylized Nature CC0). Tampilan mengikuti data blok:
tinggi pohon ∝ umur & kesehatan, kepadatan gulma ∝ `weed_level`, dan **Golden Tree** tampil
berkilau emas. Model beda-skala dinormalisasi otomatis via AABB. ⚠️ Lihat `CREDITS.md` —
model sawit (Sketchfab) **wajib atribusi** sebelum rilis.

**Fase 6 — multiplayer & monetisasi (offline-first, no pay-to-win):**
- **Toko Kosmetik** (`CosmeticShop`): beli & pakai kosmetik dari `data/cosmetic_catalog.json` —
  tema UI (warna aksen), identitas kebun (nama + lencana), kostum, skin kendaraan, emote.
  **Semua murni visual**, tiap kategori punya opsi gratis; dibeli dgn uang dalam game.
- Kosmetik tersimpan di save (v4) & diterapkan langsung (warna tema, nama kebun di header & 3D).
- **Kunjungi Kebun** (multiplayer asinkron, tanpa server wajib): **Ekspor Kebun** menulis
  snapshot `user://kebun_share.json`; **Kunjungi** memuat snapshot (punya sendiri/teman) dan
  membukanya di 3D **read-only** — fantasi "mengunjungi kebun teman" tetap offline-safe.
- Real-time LAN/online = fondasi masa depan (opsional, tak mewajibkan koneksi — sesuai GDD).

**Review agronomi v2 terintegrasi:** +2 varietas (DxP SAIN, DxP FR), +6 hama/penyakit
(Landak, Rayap, Busuk Pucuk, Hawar Daun, Monyet, Orangutan — primata via "Pengusiran",
non-letal), harga TBS → Rp2.800/kg, status data di-*bump* ke `reviewed_v2`.

Uji otomatis headless: `Godot --headless --path . -- selftest`

## Struktur folder

```
KebunSawitSim/
├── project.godot          # konfigurasi engine + daftar autoload
├── icon.svg
├── autoload/              # singleton (selalu aktif)
│   ├── Database.gd        # memuat semua JSON + fungsi query (produksi/pupuk/semprot/harga)
│   ├── GameState.gd       # saldo, hari, cuaca, blok, save/load
│   └── TimeManager.gd     # model waktu + cuaca harian + penurunan kesehatan/gulma
├── scripts/
│   └── Agronomy.gd        # Fase 2: hitung kebutuhan pupuk/semprot + efek ke kesehatan
├── data/                  # DATABASE NORMA (hasil impor terkurasi dari workbook)
│   ├── params.json              # parameter global & ekonomi
│   ├── seed_catalog.json        # katalog kecambah + Golden Tree
│   ├── production_standard.json # ton TBS/ha/tahun per umur & kelas lahan
│   ├── fertilizer_standard.json # kg/ha/tahun
│   ├── control_standard.json    # norma semprot/hama
│   └── player_profiles.json     # 3 profil pemain
├── scenes/ui/            # latar 3D hidup di balik UI (menu/profil/permainan)
│   ├── AmbientKebun3D.*   # grove sawit + kamera mengorbit
│   └── KebunBackground.*  # SubViewport pembungkus (taruh sbg anak pertama Control)
├── assets/models/        # aset 3D (lihat CREDITS.md untuk lisensi!)
│   ├── palm/oil_palm.glb  # pohon sawit (Sketchfab, CC-BY — wajib atribusi)
│   └── nature/*.gltf      # Stylized Nature MegaKit / Quaternius (CC0)
└── scenes/
    ├── MainMenu.tscn/.gd      # menu: Lanjutkan / Permainan Baru
    ├── ProfileSelect.tscn/.gd # pilih 1 dari 3 profil pemain
    ├── Main.tscn/.gd          # layar permainan + tutorial/misi + budidaya
    ├── Plantation3D.tscn/.gd  # Fase 5: penampil kebun 3D (+ mode kunjungan)
    └── CosmeticShop.tscn/.gd  # Fase 6: toko kosmetik
```

Alur scene: **MainMenu → (Baru) ProfileSelect → Main**, atau **(Lanjutkan) → Main**.
Scene utama = `MainMenu.tscn`.

## Pemetaan ke GDD + perbaikan temuan audit

| Hal | Di proyek ini |
|-----|---------------|
| Model data (GDD §4) | file-file di `data/` + `Database.gd` |
| Pisah bahan aktif / nama dagang | field di `control_standard.json` |
| Satuan dosis per ha/pokok/liter | field `per_basis` di `control_standard.json` |
| **Temuan C — model waktu** | dikunci: 1 tick = 1 hari; rotasi di `params.json` |
| **Temuan D — plafon Golden Tree** | `golden_bonus_exceeds_variety_cap=false`; panen di-clamp ke plafon varietas |
| **Temuan E — timing roll Golden** | roll sekali saat tanam (`golden_roll_phase`) |
| **Temuan F — diferensiasi varietas** | `traits` di `seed_catalog.json` (masih perlu angka) |
| Data belum tervalidasi ditandai | `"validation_status": "needs_validation"` |

## ⚠️ Penting: angka masih PLACEHOLDER

File `production_standard.json`, `fertilizer_standard.json`, dan `control_standard.json`
berisi angka contoh yang **ditandai `needs_validation`**. Ganti dengan data asli dari
`Std_Produksi_Pupuk_Herbisida_v3.xlsx` (workbook ini belum ada di folder GDD — mohon
dilampirkan agar bisa diimpor dengan benar, sesuai temuan J audit).

## Langkah berikutnya (saran)

1. Lampirkan workbook `.xlsx` → impor ke `data/*.json` lewat pipeline terkontrol.
2. Tambah layar pemilihan profil (pakai `player_profiles.json`).
3. Tambah mekanik gulma/hama/pupuk yang mengubah `health` & hasil panen.
4. Baru setelah loop ekonomi solid: beralih ke visual 3D.
