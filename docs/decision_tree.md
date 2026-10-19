# Decision Tree — Alur Cerita Awal (data-driven)

Sumber kebenaran mesin = `data/story.json` (node) + `data/land_offers.json` (lahan NPC).
Dokumen ini = versi manusia. Semua cabang **bergabung kembali** agar tidak meledak.

## Tipe node
- **narration** — teks (typewriter) → `next`
- **choice** — teks + beberapa opsi, tiap opsi set flag → `next`
- **land_market** — tampilkan kartu lahan NPC (difilter `hutan`/`bersih`) → pilih set `lahan_id` → `next`
- **preview** — gambaran kebun jadinya (3D eksplor, menyusul) → `next`
- **start_game** — terapkan flag ke GameState → masuk layar kelola (Main)

## Flag yang dikumpulkan sepanjang alur (run-state)
`jalur` = pembibitan | kebun · `tipe_lahan` = hutan | bersih · `lahan_id` · `land_class` · `land_price` · `needs_clearing`

## Pohon

```
[Permainan Baru] → Pilih Profil → STORY

  intro (per profil, 2 narasi)
   ├─ Arman:  intro_arman_1 → intro_arman_2 ─┐
   ├─ Nadia:  intro_nadia_1 → intro_nadia_2 ─┤
   └─ Bima:   intro_bima_1  → intro_bima_2  ─┤
                                             ▼
                                   ◆ invest_choice  "Hari pertama. Arahkan modal ke mana?"
                         ┌───────────────────┴───────────────────┐
              🌱 Buka Pembibitan                        🌴 Buka Kebun Sawit
              set jalur=pembibitan                      set jalur=kebun
                    ▼                                          ▼
              jalur_pembibitan (narasi)                  jalur_kebun (narasi)
                    └───────────────────┬───────────────────────┘
                                        ▼
                             ◆ land_type_choice  "Pilih jenis lahan:"
                         ┌──────────────┴───────────────┐
                  🌳 Areal Hutan                   🟫 Areal Bersih
                  set tipe_lahan=hutan             set tipe_lahan=bersih
                        ▼                                 ▼
              ▣ market_hutan (kartu NPC)          ▣ market_bersih (kartu NPC)
                set lahan_id,land_class,           set lahan_id,land_class,
                land_price,needs_clearing=true     land_price,needs_clearing=false
                        ▼                                 ▼
              preview_note_hutan (narasi)         preview_note_bersih (narasi)
                        └───────────────┬─────────────────┘
                                        ▼
                             ◻ preview3d  (gambaran kebun — 3D eksplor)
                                        ▼
                             ◆ confirm  "Lanjut dengan lahan ini?"
                         ┌──────────────┴───────────────┐
                 ✓ Mulai Kelola                   ↩ Pilih lahan lain
                        ▼                                 │
                   ⚑ start_game                          └──→ kembali ke land_type_choice
          (terapkan flag → Main)
```

## Konsekuensi flag (dipakai gameplay setelah start_game)
- `jalur=pembibitan` → buka subsistem pembibitan (menyemai kecambah → bibit). *Subsistem baru, menyusul.*
- `jalur=kebun` → langsung menanam untuk produksi TBS (loop yang sudah ada).
- `tipe_lahan=hutan` → `needs_clearing=true`: lahan harus dibuka dulu (biaya+waktu, **abstracted**, bukan manual) sebelum tanam. Lebih murah.
- `tipe_lahan=bersih` → siap tanam, lebih mahal.
- `land_class` (S1/S2/S3) dari lahan terpilih → langsung memengaruhi `production_standard`.
- `land_price` → dipotong dari modal saat start_game (lahan tak ditagih lagi di Main).

## Catatan implementasi bertahap
1. **SEKARANG**: engine cerita + typewriter + pilihan + marketplace + start_game (flag diterapkan).
2. Menyusul: preview 3D yang bisa dieksplor (kamera bebas) di node `preview3d`.
3. Menyusul: pembukaan lahan hutan (abstracted) + subsistem pembibitan.
4. Gambar kartu lahan NPC: disediakan pemilik (field `image` di land_offers.json).
