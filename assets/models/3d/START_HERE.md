# 🚀 START HERE - 3D Assets Setup Guide

**Status: Ready for Download**  
**Date: 2026-10-17**  
**Project: GDD Simulator (Kebun Sawit Simulator)**

---

## 📊 Current Status

✅ **Completed:**
- Folder structure created (7 categories)
- All documentation written
- Download links compiled and verified
- Helper scripts ready

⏳ **Next Step:**
- Download 15 models (manual process)
- Place in correct folders
- Generate scene wrappers

---

## 🎯 What You Have

This folder now contains:

```
assets/models/3d/
├── medicinal_plants/        ← Empty folder, ready for plants
├── mushrooms/               ← Empty folder, ready for mushrooms
├── insects/                 ← Empty folder, ready for insects
├── gemstones/               ← Empty folder, ready for gems
├── animals/                 ← Empty folder, ready for animals
├── vegetation/              ← Empty folder, ready for grass/weeds
├── eggs/                    ← Empty folder, ready for eggs
├── README.md                ← Detailed usage guide
├── ATTRIBUTION.md           ← Credits for all creators
├── ASSET_SOURCES.md         ← Technical details
├── DOWNLOAD_QUICK_GUIDE.md  ← Visual step-by-step guide
├── MANUAL_DOWNLOAD.sh       ← Display all download links
├── download_helper.py       ← Python utility script
├── auto_download.py         ← Automated download script
└── START_HERE.md            ← This file
```

---

## ⚡ Quick Start (3 Steps)

### Step 1: View Download Links
Run this to see all 15 download links organized by category:

```bash
cd assets/models/3d
bash MANUAL_DOWNLOAD.sh
```

This will display all links in your terminal. Copy each link to your browser.

### Step 2: Download & Organize Files

Open each link in your browser and download:
- Choose **glTF** format when prompted
- Extract ZIP files if needed
- Save each `.glb` file in the correct folder
- Rename according to the guide

**Estimated time: 30-45 minutes**

### Step 3: Generate Scene Wrappers

Once all files are downloaded and organized:

```bash
cd assets/models/3d
python3 download_helper.py wrap
```

This auto-creates `.tscn` scene files for each model.

---

## 📥 Detailed Download Instructions

### For Sketchfab Models (13 models)

1. **Open link in browser**
   - Example: `https://sketchfab.com/3d-models/ginseng-...`

2. **Find the Download button**
   - Located at bottom-left of 3D viewer
   - If not visible, scroll down

3. **Click Download**
   - Pop-up appears with format options

4. **Select "glTF" format**
   - This is the recommended format for Godot
   - Alternative: "glTF Binary (GLB)"

5. **File downloads as ZIP**
   - Browser saves to Downloads folder

6. **Extract the ZIP**
   - Right-click → Extract (macOS/Windows)
   - Unzip (Linux)

7. **Find the .glb file**
   - Navigate into extracted folder
   - Look for file with `.glb` extension
   - This is your model file

8. **Rename if needed**
   - Compare with MANUAL_DOWNLOAD.sh output
   - Rename to suggested name
   - Example: `ginseng.glb`

9. **Move to correct folder**
   - Destination from MANUAL_DOWNLOAD.sh
   - Example: `assets/models/3d/medicinal_plants/`

### For Poly Haven Models (2 models)

1. **Open link in browser**
   - Example: `https://polyhaven.com/a/grass_medium_01`

2. **Scroll to Download section**
   - Look for "Download" button

3. **Select "glTF" format**
   - Dropdown menu has options

4. **Click Download**
   - ZIP file downloads

5. **Extract ZIP**
   - Right-click → Extract

6. **Find .glb file**
   - Usually in root of extracted folder

7. **Rename to suggested name**
   - From MANUAL_DOWNLOAD.sh: `grass_medium_01.glb`

8. **Move to correct folder**
   - `assets/models/3d/vegetation/`

---

## 📋 All 15 Models - Download Checklist

### Medicinal Plants (3 models)
- [ ] Ginseng → `medicinal_plants/ginseng.glb`
- [ ] Ginger → `medicinal_plants/ginger.glb`
- [ ] Turmeric → `medicinal_plants/turmeric.glb`

### Mushrooms (2 models)
- [ ] Mushroom 2 → `mushrooms/mushroom_basic.glb`
- [ ] Earthstar → `mushrooms/earthstar.glb`

### Insects (3 models)
- [ ] Ant → `insects/ant.glb`
- [ ] Bee → `insects/bee.glb`
- [ ] Butterfly → `insects/butterfly.glb`

### Gemstones (1 model)
- [ ] Gems Collection → `gemstones/gems_collection.glb`

### Animals (3 models)
- [ ] Golden Snail → `animals/keong_mas.glb`
- [ ] Barn Owl Detailed → `animals/barn_owl_detailed.glb`
- [ ] Barn Owl Low Poly → `animals/barn_owl_lowpoly.glb`

### Vegetation (2 models)
- [ ] Grass Medium → `vegetation/grass_medium_01.glb`
- [ ] Weed Plant → `vegetation/weed_plant_02.glb`

### Eggs (1 model)
- [ ] Eggs Collection → `eggs/eggs_set.glb`

---

## ✅ How to Know You're Done

When you've downloaded all files, run:

```bash
cd assets/models/3d
python3 download_helper.py status
```

You should see output like:

```
============================================================
3D ASSET DOWNLOAD STATUS
============================================================

Total Assets: 15
Downloaded: 15  ✓✓✓
Missing: 0

✓ DOWNLOADED:
  • Ginseng (medicinal_plants/ginseng.glb)
  • Ginger (medicinal_plants/ginger.glb)
  • ... (all 15 listed)
```

When you see **"Downloaded: 15"** → You're ready for next step!

---

## 🎬 After Download: Generate Scenes

Once all 15 GLB files are in place:

```bash
cd assets/models/3d
python3 download_helper.py wrap
```

This command:
- Scans all folders for `.glb` files
- Creates matching `.tscn` scene files
- Makes models ready to use in Godot

Expected output:
```
Created scenes/ginseng.tscn
Created scenes/ginger.tscn
... (15 total)
```

---

## 🔍 Verify in Godot

1. **Open Godot project**
2. **Go to FileSystem panel** (bottom-left)
3. **Navigate to:** `res://assets/models/3d/`
4. **You should see:**
   - All 7 category folders
   - GLB files inside each
   - .tscn files for each model

5. **Double-click a .tscn file to preview**
   - Model will render in viewport
   - Verify it looks correct

---

## 💻 Using Models in Code

After setup, load models in your GDScript:

```gdscript
# Load a single model
var ant = load("res://assets/models/3d/insects/ant.tscn").instantiate()
add_child(ant)
ant.position = Vector3(5, 0, 5)

# Load and position multiple models
var gem = load("res://assets/models/3d/gemstones/gems_collection.tscn").instantiate()
add_child(gem)
gem.position = Vector3(10, 1, 10)

# For missions - load dynamically
var model_name = "ginseng"
var model = load(f"res://assets/models/3d/medicinal_plants/{model_name}.tscn").instantiate()
get_parent().add_child(model)
```

---

## 📚 Reference Documents

If you need more details:

| File | Purpose |
|------|---------|
| `README.md` | Complete usage documentation |
| `DOWNLOAD_QUICK_GUIDE.md` | Visual download walkthrough |
| `ATTRIBUTION.md` | Creator credits & licenses |
| `ASSET_SOURCES.md` | Technical asset details |
| `download_helper.py` | Python tool for management |

---

## 🆘 Troubleshooting

### "Download link doesn't work"
- Check spelling of URL
- Make sure link is for download page, not view page
- Try different browser if one fails

### "Can't find Download button on Sketchfab"
- Scroll down the page
- Button is at bottom-left, below 3D viewer
- May take a moment for page to fully load

### "Downloaded .zip but no .glb inside"
- Extract the zip (don't just double-click view)
- Look inside the extracted folder
- May have subfolders - check all
- Right-click → Extract (not View)

### "Models show in FileSystem but blank in Godot"
- Refresh FileSystem (F5 or button at top)
- Close and re-open Godot
- Check file permissions (should be readable)

### "download_helper.py wrap didn't create scenes"
- Verify .glb files exist in folders
- Run `python3 download_helper.py status` first
- Check file extensions are lowercase `.glb`

---

## 📞 Need Help?

1. **Check the guide:** `DOWNLOAD_QUICK_GUIDE.md`
2. **View all links:** `bash MANUAL_DOWNLOAD.sh`
3. **Check status:** `python3 download_helper.py status`
4. **Test script:** `python3 download_helper.py catalog`

---

## ⏱️ Timeline

**Today (30-45 mins):**
- Download 15 models
- Run scene generator
- Verify in Godot

**Tomorrow:**
- Start using in missions
- Test loading models
- Adjust as needed

---

## 🎉 Summary

You now have:
- ✅ Complete folder structure
- ✅ All documentation
- ✅ Download links ready
- ✅ Helper scripts
- ⏳ 15 free, safe-license models waiting to be downloaded

**Next action:** Open `MANUAL_DOWNLOAD.sh` output and start downloading!

**Total setup time:** ~1 hour (mostly download time)

---

**Ready? Let's build! 🚀**
