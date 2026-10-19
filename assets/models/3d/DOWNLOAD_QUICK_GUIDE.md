# Quick Download Guide

Simple step-by-step guide untuk download 3D models dari Sketchfab dan Poly Haven.

## For Sketchfab Models (Sebagian besar assets)

### Steps:

1. **Buka link model** di browser (Chrome, Firefox, Safari, Edge)
   - Example: https://sketchfab.com/3d-models/ginseng-213a2e16b77041839e91ceb63dbc2b4b

2. **Tunggu halaman load** - Anda akan melihat 3D viewer di tengah layar

3. **Cari tombol Download** - di bagian bawah kiri, ada icon download (⬇️)

4. **Klik Download button**

5. **Pilih format:** 
   - Prioritas: `glTF` atau `glTF Binary (GLB)`
   - Alternatif: `FBX` atau `OBJ`
   - **Jangan pilih:** Blend, USDZ, dll

6. **File akan download** - biasanya sebagai `[modelname].zip`

7. **Extract/Unzip** file tersebut
   - Cari file `.glb` atau `.gltf` 
   - Buang file lainnya (textures, docs, dll)

8. **Rename file** ke nama yang benar (lihat tabel di bawah)

9. **Pindahkan ke folder yang benar**
   ```
   assets/models/3d/[category]/[filename].glb
   ```

10. **Repeat** untuk semua models

---

## For Poly Haven Models (Grass, Weeds)

### Steps:

1. **Buka halaman asset** di Poly Haven
   - Example: https://polyhaven.com/a/grass_medium_01

2. **Scroll ke bagian Download**

3. **Pilih format "glTF"** dari dropdown

4. **Klik Download button** - akan download `.zip` file

5. **Extract/Unzip**

6. **Cari file `.glb`** 
   - Struktur biasanya: `[model-name].glb`

7. **Rename ke nama standard** (lihat tabel di bawah)

8. **Pindahkan ke folder:**
   ```
   assets/models/3d/vegetation/[filename].glb
   ```

---

## Download Checklist & File Mapping

### Medicinal Plants (Tanaman Obat)

| Model Name | Filename | Sketchfab Link | Extract From |
|------------|----------|---|---|
| Ginseng | `ginseng.glb` | [Link](https://sketchfab.com/3d-models/ginseng-213a2e16b77041839e91ceb63dbc2b4b) | `*.glb` di zip |
| Ginger | `ginger.glb` | [Link](https://sketchfab.com/3d-models/ginger-root-zingiber-officinale-206c458052cc40a29c169733ce887d62) | `*.glb` di zip |
| Turmeric | `turmeric.glb` | [Link](https://sketchfab.com/3d-models/turmeric-7b7195c2971243e7b19dcc11b8ec26fc) | `*.glb` di zip |

**Destination:** `assets/models/3d/medicinal_plants/`

---

### Mushrooms (Jamur)

| Model Name | Filename | Link | Format |
|------------|----------|------|--------|
| Mushroom 2 | `mushroom_basic.glb` | [Link](https://sketchfab.com/3d-models/cc0-mushroom-2-c9dba020d1064e0fba2cbfa561e32748) | glTF |
| Earthstar | `earthstar.glb` | [Link](https://sketchfab.com/3d-models/cc0-earthstar-mushroom-a-hygrometricus-a6fcfabf95c94284bc4a675dd12880b0) | glTF |

**Destination:** `assets/models/3d/mushrooms/`

---

### Insects (Serangga)

| Model Name | Filename | Link | Format |
|------------|----------|------|--------|
| Ant | `ant.glb` | [Link](https://sketchfab.com/3d-models/low-poly-ant-23027ae584404a2b8dc678aff55da9ed) | glTF |
| Bee | `bee.glb` | [Link](https://sketchfab.com/3d-models/lowpoly-bee-96d626f8a53341e69b31fa0be5bab105) | glTF |
| Butterfly | `butterfly.glb` | [Link](https://sketchfab.com/3d-models/low-poly-butterfly-74e5a3fb23044eaa94a84a0518ef07a2) | glTF |

**Destination:** `assets/models/3d/insects/`

---

### Gemstones (Batu Berharga)

| Model Name | Filename | Link | Notes |
|------------|----------|------|-------|
| Gems Collection | `gems_collection.glb` | [Link](https://sketchfab.com/3d-models/gems-21-different-shapes-1fb35b1aefae4d819dde9de90162602a) | 21 variations included |

**Destination:** `assets/models/3d/gemstones/`

---

### Animals (Hewan)

| Model Name | Filename | Link | Priority |
|------------|----------|------|----------|
| Golden Snail | `keong_mas.glb` | [Link](https://sketchfab.com/3d-models/keong-mas-763c12af90f6449b858f0301c6efb0d5) | High |
| Barn Owl (Detailed) | `barn_owl_detailed.glb` | [Link](https://sketchfab.com/3d-models/common-barn-owl-19c989a6681145bc999c332699eb852e) | Medium |
| Barn Owl (Low Poly) | `barn_owl_lowpoly.glb` | [Link](https://sketchfab.com/3d-models/barn-owltyto-alba-af3cdd38e029430d9c131370ebf1bb33) | Low |

**Destination:** `assets/models/3d/animals/`

---

### Vegetation (Tumbuhan)

| Model Name | Filename | Source | Link |
|------------|----------|--------|------|
| Grass Medium | `grass_medium_01.glb` | Poly Haven | [Link](https://polyhaven.com/a/grass_medium_01) |
| Weed Plant | `weed_plant_02.glb` | Poly Haven | [Link](https://polyhaven.com/a/weed_plant_02) |

**Destination:** `assets/models/3d/vegetation/`

---

### Eggs (Telur)

| Model Name | Filename | Link |
|------------|----------|------|
| Eggs Collection | `eggs_set.glb` | [Link](https://sketchfab.com/3d-models/eggs-30d391929e25432e87f84f5cfe02a0fa) |

**Destination:** `assets/models/3d/eggs/`

---

## Common Issues & Solutions

### "Can't find Download button"
- Scroll down pada halaman Sketchfab/Poly Haven
- Button ada di bawah 3D viewer
- Pastikan sudah wait sampai page fully loaded

### "Zip file berisi banyak folder"
- Kamu mengextract zip dengan struktur folder
- Cari file `.glb` di dalam folder
- Gunakan Finder/Explorer untuk navigate
- Copy `.glb` file ke destination folder

### "Multiple .glb files in zip"
- Beberapa models memiliki multiple meshes
- Biasanya ada file utama (terbesar size)
- Gunakan file terbesar
- Jika ragu, gunakan semua dan test di Godot

### "File sudah ada tapi tetap di 'missing' list"
- Check spelling dan extension (harus `.glb` lowercase)
- Check folder - file harus di category folder yang tepat
- Run `python3 download_helper.py status` lagi

### "Model tidak muncul di Godot setelah download"
- Refresh Godot FileSystem (klik refresh icon)
- Close dan re-open Godot project
- Check file permissions (harus readable)

---

## After Downloading All Files

### Step 1: Verify dengan Python Script
```bash
cd assets/models/3d
python3 download_helper.py status
```

Semua harus muncul di "DOWNLOADED" section.

### Step 2: Create Scene Wrappers
```bash
python3 download_helper.py wrap
```

Ini akan auto-create `.tscn` files untuk setiap GLB.

### Step 3: Open in Godot
1. Open Godot project
2. Go ke FileSystem panel
3. Navigate ke `assets/models/3d/`
4. Double-click salah satu `.tscn` file
5. Model akan preview di Godot editor

### Step 4: Use in Your Missions
```gdscript
# Dalam mission script Anda:
var ant = load("res://assets/models/3d/insects/ant.tscn").instantiate()
get_parent().add_child(ant)
ant.position = Vector3(10, 0, 5)
```

---

## Download Priority (Jika Ingin Mulai Cepat)

**Tinggi (Harus Ada):**
- Ginseng, Ginger, Turmeric (medicinal plants - core mission assets)
- Mushroom 2, Earthstar (environment)
- Ant, Bee, Butterfly (pests/interactions)
- Gems Collection (rewards)
- Keong Mas, Barn Owl (special mechanics)

**Sedang (Recommended):**
- Grass Medium, Weed Plant (environment)
- Eggs Collection (breeding mechanics)

**Rendah (Optional):**
- Barn Owl Low Poly (jika sudah ada detailed version)

---

## Estimated Time

- Per model: 2-3 menit (download + extract + copy)
- Total untuk 15 models: ~30-45 menit
- Scene generation: < 1 menit (automatic)
- Total time: ~1 jam untuk full setup

---

**Tips:**
- Download semua files sekaligus browser tabs terbuka
- Jangan close tabs sampai semua download selesai
- Test di Godot sambil download yang lain berjalan

Semua link valid per 2026-10-17 ✓
