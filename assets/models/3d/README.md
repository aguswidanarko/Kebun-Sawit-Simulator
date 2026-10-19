# 3D Assets for GDD Simulator (Kebun Sawit Simulator)

This directory contains organized 3D model assets for the Godot 4.7 GDD Simulator project.

## Current Status

- **Folder Structure:** ✅ Complete (9 categories created)
- **Documentation:** ✅ Complete (ATTRIBUTION.md, ASSET_SOURCES.md)
- **Helper Script:** ✅ Complete (download_helper.py)
- **GLB Files:** ⏳ Awaiting Download (15 models, free & licensed)

## Quick Start

### Step 1: Check Asset Status
Run the helper script to see what's needed:

```bash
cd assets/models/3d
python3 download_helper.py status
```

### Step 2: Download Assets (Two Methods)

#### Method A: Browser Download (Manual, Easiest)

For **Sketchfab models** (CC-BY & CC0):
1. Open the link in your browser
2. Click the **Download** button (bottom-left of 3D viewer)
3. Choose **glTF** format (or Geometry if that's the only option)
4. Save to the correct folder as shown in `ASSET_SOURCES.md`

For **Poly Haven models** (CC0):
1. Go to the asset page
2. Look for download options
3. Choose **glTF** or **FBX** format
4. Save to the correct folder

#### Method B: Python Script (Automated)
A helper script is available to assist with organization and scene creation:

```bash
python3 download_helper.py catalog  # See all available assets
python3 download_helper.py status   # Check download progress
python3 download_helper.py wrap     # Auto-create scene files
```

### Step 3: Organize Downloaded Files

Place each downloaded GLB file in its corresponding category folder:

```
assets/models/3d/
├── medicinal_plants/
│   ├── ginseng.glb
│   ├── ginger.glb
│   └── turmeric.glb
├── mushrooms/
│   ├── mushroom_basic.glb
│   └── earthstar.glb
├── insects/
│   ├── ant.glb
│   ├── bee.glb
│   └── butterfly.glb
├── gemstones/
│   ├── gems_collection.glb
│   └── ...
├── animals/
│   ├── keong_mas.glb
│   ├── barn_owl_detailed.glb
│   └── barn_owl_lowpoly.glb
├── vegetation/
│   ├── grass_medium_01.glb
│   └── weed_plant_02.glb
├── eggs/
│   ├── eggs_set.glb
│   └── ...
└── ATTRIBUTION.md
```

### Step 4: Create Scene Wrappers

After placing GLB files, auto-generate scene files:

```bash
python3 download_helper.py wrap
```

This creates `.tscn` files for each GLB automatically.

### Step 5: Verify in Godot

In the Godot editor:
1. Open `FileSystem` panel
2. Navigate to `res://assets/models/3d/`
3. Verify all folders and GLB files appear
4. Open any `.tscn` file to preview the model

## Asset Categories

### 1. Medicinal Plants (Tanaman Obat)
- Ginseng
- Ginger (Jahe)
- Turmeric (Kunyit)
- *For special missions involving herbal compounds*

### 2. Mushrooms (Jamur)
- Basic Mushroom (with PBR textures)
- Earthstar Mushroom
- *For environment decoration & special missions*

### 3. Insects (Serangga)
- Ant (Semut)
- Bee (Lebah)
- Butterfly (Kupu-kupu)
- *For pest control missions & ecosystem interactions*

### 4. Gemstones (Batu Berharga)
- Gems Collection (21 shapes)
- *For treasure/reward missions*

### 5. Animals (Hewan)
- Keong Mas (Golden Snail) - pest in farms
- Barn Owl (Burung Hantu) - predator/control
- *For specific gameplay mechanics*

### 6. Vegetation (Tumbuhan)
- Grass Medium (Rumput)
- Weed Plant (Gulma)
- *For ground cover & environment variety*

### 7. Eggs (Telur)
- Egg collection models
- *For egg-related missions or breeding mechanics*

## Technical Details

### File Format
- **Format:** GLTF/GLB (native Godot format)
- **Size:** Optimized for game engines
- **Textures:** Embedded in GLTF files
- **Compatibility:** Godot 4.7+

### Scene Structure
Each asset generates a basic scene with this structure:
```
[Model Name]
└── MeshInstance3D
    └── [Imported Mesh]
```

Ready to extend with:
- Physics (CollisionShape3D)
- Animation (AnimationPlayer)
- Logic (Script)

### Import Settings (Automatic)
Godot automatically:
- Imports GLB as mesh resource
- Loads embedded textures
- Creates material overrides as needed

## Licenses

- **CC0 (Public Domain)** - No attribution required
  - Mushroom models
  - Poly Haven assets (Grass, Weeds)

- **CC-BY (Attribution Required)** - Must credit creator
  - Medicinal plant models
  - Insect models
  - Gemstone models
  - Animal models
  - Egg models

**Attribution:** See `ATTRIBUTION.md` for complete credits

## Using Assets in Scenes

### Load from Script
```gdscript
# Load and instance a model
var ant = load("res://assets/models/3d/insects/ant.tscn").instantiate()
add_child(ant)
ant.position = Vector3(10, 0, 5)
```

### Drag & Drop in Editor
1. Open your scene in Godot
2. Go to `FileSystem` panel
3. Find the `.tscn` file in `assets/models/3d/[category]/`
4. Drag and drop into your scene

### Prefab Instantiation
Each `.tscn` file is a ready-to-use prefab:
- Can be duplicated multiple times
- Maintains single source model
- Easy to add variations

## Troubleshooting

### GLB not appearing in FileSystem?
- Make sure file has `.glb` extension (lowercase)
- Place in correct category folder
- Restart Godot editor

### Scene won't load?
- Check that path in `.tscn` file matches actual GLB location
- Ensure GLB file isn't corrupted
- Try regenerating scene wrapper with `python3 download_helper.py wrap`

### Textures look wrong?
- Some Sketchfab models may need material adjustment
- Check if textures are embedded or separate
- May need to apply basic material in scene

## Next Steps

1. **Download Phase** (Manual)
   - Use links in `ASSET_SOURCES.md`
   - Download all 15 models in GLTF format
   - Place in correct folders

2. **Scene Creation** (Automated)
   - Run `python3 download_helper.py wrap`
   - Creates scene files for each model

3. **Godot Integration**
   - Verify in Godot editor
   - Test loading models in scenes
   - Add physics/scripts as needed

4. **Mission Development**
   - Use assets in special missions
   - Instance models programmatically or via editor
   - Customize appearance with materials

## File Reference

- `ASSET_SOURCES.md` - Where to download each model
- `ATTRIBUTION.md` - Complete credits & licenses
- `download_helper.py` - Python utility for management
- `README.md` - This file

## Additional Resources

- **Sketchfab:** https://sketchfab.com - Browse 3D models
- **Poly Haven:** https://polyhaven.com - Free CC0 assets
- **Godot Docs:** https://docs.godotengine.org - Import settings
- **Creative Commons:** https://creativecommons.org - License info

---

**Project:** GDD Simulator (Kebun Sawit Simulator)  
**Last Updated:** 2026-10-17  
**Total Assets:** 15 models  
**Status:** Ready for download & integration
