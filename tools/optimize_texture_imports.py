#!/usr/bin/env python3
"""
Optimalkan setelan import tekstur Godot untuk menekan ukuran APK.

Mengubah file *.import (metadata), BUKAN file gambar sumber — sumber tetap
utuh resolusi penuh kalau suatu saat butuh aset cetak/promo.

Dua setelan yang diubah:
  process/size_limit  -> batasi sisi terpanjang (default 1920 px)
       Godot mengecilkan saat import. Layar HP target 390x844 logis
       (~1080x2400 fisik), jadi >1920 px murni pemborosan.
  compress/mode       -> 2 (VRAM Compressed) untuk FOTO
       Lossless (mode 0) men-dekompresi JPEG jadi bitmap penuh:
       plantation4.jpg 4,8 MB -> .ctex 23,1 MB. VRAM Compressed memakai
       ETC2/ASTC (sudah diaktifkan di project.godot) sehingga jauh lebih
       kecil dan lebih cepat dibaca GPU.

Ikon aplikasi (assets/icons/) dan ikon UI SVG TIDAK disentuh: ikon butuh
tepi tajam, dan ukurannya sudah kecil.

Pakai:  python3 tools/optimize_texture_imports.py [--apply]
Tanpa --apply hanya menampilkan rencana (dry-run).
"""

import glob
import os
import re
import sys

MAX_SIDE = 1920

# Folder yang isinya FOTO MURNI -> aman & untung besar pakai VRAM compression.
# assets/portraits/ dan assets/characters/ SENGAJA tidak masuk: kartu karakter
# punya teks tercetak (nama & peran), dan ETC2/ASTC membuat tepi huruf pecah.
# Ukurannya pun kecil (~0,6 MB), jadi tidak sepadan risikonya — cukup size_limit.
PHOTO_DIRS = ("assets/bg/", "assets/pests/")
# Jangan disentuh sama sekali.
SKIP_DIRS = ("assets/icons/", "assets/ui/icons/")


def is_photo(path: str) -> bool:
    return any(d in path for d in PHOTO_DIRS)


def should_skip(path: str) -> bool:
    return any(d in path for d in SKIP_DIRS)


def set_key(text: str, key: str, value: str) -> tuple[str, bool]:
    """Ganti `key=...` di dalam blok [params]. Return (teks_baru, berubah)."""
    pattern = re.compile(rf"^{re.escape(key)}=.*$", re.MULTILINE)
    new_line = f"{key}={value}"
    if pattern.search(text):
        new_text = pattern.sub(new_line, text, count=1)
        return new_text, new_text != text
    # Key belum ada -> tambahkan di akhir blok [params]
    if "[params]" in text:
        return text.rstrip("\n") + f"\n{new_line}\n", True
    return text, False


def collect_textures() -> list:
    out = []
    for imp in sorted(glob.glob("assets/**/*.import", recursive=True)):
        src = imp[: -len(".import")]
        if not src.lower().endswith((".jpg", ".jpeg", ".png")):
            continue
        if should_skip(src) or not os.path.exists(src):
            continue
        with open(imp, "r", encoding="utf-8") as f:
            text = f.read()
        text, c1 = set_key(text, "process/size_limit", str(MAX_SIDE))
        c2 = False
        if is_photo(src):
            text, c2 = set_key(text, "compress/mode", "2")
        if c1 or c2:
            out.append((src, imp, text, "size_limit + VRAM" if c2 else "size_limit"))
    return out


def collect_models() -> list:
    """Matikan create_shadow_meshes pada model 3D.

    Godot membuat SALINAN mesh tersederhana khusus untuk render bayangan.
    Diukur pada sabuk-hutan.glb: 4,96 MB -> 3,33 MB (hemat 33%).

    Konsekuensi: pass bayangan memakai mesh full-detail, jadi sedikit lebih
    berat di GPU. Dapat diterima karena generate_lods tetap aktif (objek jauh
    otomatis pakai versi sederhana), sementara ukuran APK adalah penghalang
    keras rilis Play Store (batas 150 MB).
    """
    out = []
    for imp in sorted(glob.glob("assets/**/*.import", recursive=True)):
        src = imp[: -len(".import")]
        if not src.lower().endswith((".glb", ".gltf", ".obj")):
            continue
        if not os.path.exists(src):
            continue
        with open(imp, "r", encoding="utf-8") as f:
            text = f.read()
        text, changed = set_key(text, "meshes/create_shadow_meshes", "false")
        if changed:
            out.append((src, imp, text, "tanpa shadow_mesh"))
    return out


def main() -> int:
    apply = "--apply" in sys.argv
    textures = collect_textures()
    models = collect_models()
    targets = textures + models

    if not targets:
        print("Tidak ada yang perlu diubah.")
        return 0

    print(f"{'DITERAPKAN' if apply else 'RENCANA (dry-run)'} — {len(targets)} aset\n")
    for src, imp, new, tag in targets:
        print(f"  [{tag}] {src}")
        if apply:
            with open(imp, "w", encoding="utf-8") as f:
                f.write(new)

    n_vram = sum(1 for t in textures if "VRAM" in t[3])
    print(f"\n  {len(textures)} tekstur -> size_limit {MAX_SIDE} px ({n_vram} di antaranya VRAM Compressed)")
    print(f"  {len(models)} model   -> tanpa shadow_mesh")
    if apply:
        print("\n✅ Selesai. Jalankan: godot --headless --import --path .")
    else:
        print("\n(dry-run — tambahkan --apply untuk menerapkan)")
    return 0


if __name__ == "__main__":
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    raise SystemExit(main())
