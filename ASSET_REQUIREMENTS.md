# 🎮 GDD Simulator - 3D Asset Requirements & Inventory

**Document:** Asset Requirements & Status Report  
**Project:** Kebun Sawit Simulator (Oil Palm Plantation Simulator)  
**Engine:** Godot 4.7.2  
**Date:** 2026-10-17  
**Status:** MVP Phases 1-6 Development

---

## 📊 CURRENT ASSET INVENTORY

### ✅ ASSETS ALREADY IN USE (58 Models)

#### 1. **Palm Oil Models** (2 assets)
| Model | File | License | Usage | Status |
|-------|------|---------|-------|--------|
| Static Oil Palm | oil_palm.glb | CC-BY (Sketchfab) | Fruit visualization in grid | ✅ In use |
| Palm Fronds Tree | palm_tree.glb | CC0 (Quaternius) | Walkable world scenery | ✅ In use |

#### 2. **Character Models** (4 assets)
| Model | File | License | Usage | Status |
|-------|------|---------|-------|--------|
| Human Base | human.glb | CC0 (Quaternius) | Player avatar base | ✅ In use |
| Worker | worker.glb | CC0 (Quaternius) | Cosmetic costume | ✅ In use |
| Business Suit | suit.glb | CC0 (Quaternius) | Cosmetic costume | ✅ In use |
| Man Character | man.glb | CC0 (Quaternius) | NPC/variant | ✅ In use |

#### 3. **Nature/Environment Assets** (50+ models)
Source: **Quaternius (CC0) + Stylized Nature Pack**

| Category | Examples | Count | Usage | License |
|----------|----------|-------|-------|---------|
| Grass | Grass_Common_Short, Grass_Common_Tall, Grass_Dry, etc | 8+ | Ground cover, weed density | CC0 |
| Trees | Tree_Oak, Tree_Birch, Tree_Pine, Conifer variants | 10+ | Forest backdrop | CC0 |
| Bushes | Bush_Dark, Bush_Green, Bush_LowPoly variants | 6+ | Plantation borders | CC0 |
| Flowers | Various flower species | 5+ | Environmental decoration | CC0 |
| Rocks | Rock_Boulder, Rock_Flat, Terrain rocks | 5+ | Environment details | CC0 |
| Paths | Gravel_path, Dirt_road | 3+ | Navigation visuals | CC0 |
| Mushrooms | Various fungi | 3+ | Forest floor | CC0 |

**Total Nature Assets:** 50+ models  
**Usage:** FarmWorld3D decorative landscape

#### 4. **Vehicle Models** (1 asset)
| Model | File | License | Usage | Status |
|-------|------|---------|-------|--------|
| Pickup Truck | pickup.glb | CC0 (Quaternius) | Cosmetic vehicle | ✅ In use |

#### 5. **Vegetation (3D Models)** (1 asset)
| Model | File | License | Status | Usage |
|-------|------|---------|--------|-------|
| Grass Medium 01 | grass_medium_01.glb | CC0 (Poly Haven) | ✅ Downloaded | Vegetation folder |

---

## ⏳ PLANNED ASSETS (15 Models - Ready to Download)

### Location: `assets/models/3d/`

**Status:** Folders created, documentation complete, download links compiled.  
**Action:** Download from Sketchfab & Poly Haven (estimated 30-45 minutes)

#### 1. **Medicinal Plants** (3 models) - For Mission Content
| Model | Creator | License | Link | Purpose |
|-------|---------|---------|------|---------|
| Ginseng | KaMi | CC-BY | Sketchfab | Herbal reward item |
| Ginger (Jahe) | The Whz | CC-BY | Sketchfab | Medicinal farming |
| Turmeric (Kunyit) | anuch | CC-BY | Sketchfab | Spice crop |

**Purpose:** Visual rewards in medicinal farming missions  
**Folder:** `assets/models/3d/medicinal_plants/`

#### 2. **Mushrooms** (2 models) - For Disease Visualization
| Model | Creator | License | Link | Purpose |
|-------|---------|---------|------|---------|
| Mushroom 2 (CC0) | plaggy | CC0 | Sketchfab | Fungal disease indicator |
| Earthstar Mushroom | ffish.asia | CC0 | Sketchfab | Forest fungi variant |

**Purpose:** Visual representation of Ganoderma fungal disease  
**Folder:** `assets/models/3d/mushrooms/`

#### 3. **Insects** (3 models) - For Pest Visualization
| Model | Creator | License | Link | Purpose |
|-------|---------|---------|------|---------|
| Low Poly Ant | CGCroissant | CC-BY | Sketchfab | General pest indicator |
| Low Poly Bee | Alex (alemue) | CC-BY | Sketchfab | Beneficial insect |
| Low Poly Butterfly | mankindforward | CC-BY | Sketchfab | Environmental wildlife |

**Purpose:** Visual pests for pest management missions  
**Folder:** `assets/models/3d/insects/`

#### 4. **Gemstones** (1 model - 21 variations) - For Cosmetic Rewards
| Model | Creator | License | Link | Count |
|-------|---------|---------|------|-------|
| Gems Collection (21 shapes) | Vivien Deroche | CC-BY | Sketchfab | 21 variations |

**Purpose:** Reward items in cosmetic/achievement system  
**Variants:** Diamond, Ruby, Emerald, Sapphire, Topaz, etc. (21 total shapes)  
**Folder:** `assets/models/3d/gemstones/`

#### 5. **Animals** (3 models) - For Wildlife & Pest Interaction
| Model | Creator | License | Link | Purpose |
|-------|---------|---------|------|---------|
| Golden Snail (Keong Mas) | alfrs | CC-BY | Sketchfab | Crop pest (snail damage) |
| Barn Owl (Detailed) | Innovation Studio | CC-BY | Sketchfab | Predator visual (pest control) |
| Barn Owl (Low Poly) | kristnby | CC-BY | Sketchfab | Performance-optimized variant |

**Purpose:** Pest species & natural predators  
**Folder:** `assets/models/3d/animals/`

#### 6. **Vegetation** (2 models) - For Ground Cover Variety
| Model | Creator | License | Link | Status |
|-------|---------|---------|------|--------|
| Grass Medium 01 | Poly Haven | CC0 | Poly Haven | ✅ **Downloaded** |
| Weed Plant 02 | Poly Haven | CC0 | Poly Haven | ⏳ **Awaiting download** |

**Purpose:** Weed density visualization  
**Folder:** `assets/models/3d/vegetation/`

#### 7. **Eggs** (1 model) - For Breeding System (Future)
| Model | Creator | License | Link | Purpose |
|-------|---------|---------|------|---------|
| Eggs Collection | LanaGre | CC-BY | Sketchfab | Creature egg models |

**Purpose:** Breeding/lifecycle system (planned Phase 6+)  
**Folder:** `assets/models/3d/eggs/`

---

## ❌ CRITICAL ASSET GAPS - NOT YET AVAILABLE

### 1. **Pest/Disease 3D Models** (10 - Currently No 3D Representation)

Game has 10 pests/diseases in system, but **NO 3D MODELS** exist:

| Pest/Disease | Type | Game Logic | 3D Model | Priority |
|--------------|------|-----------|----------|----------|
| **Ulat Api** (Caterpillar) | Pest | ✅ Coded | ❌ Missing | HIGH |
| **Kumbang Daun** (Leaf Beetle) | Pest | ✅ Coded | ❌ Missing | HIGH |
| **Belalang** (Grasshopper) | Pest | ✅ Coded | ❌ Missing | HIGH |
| **Tikus** (Rat) | Pest | ✅ Coded | ❌ Missing | HIGH |
| **Ganoderma** (Root Fungus) | Disease | ✅ Coded | ⏳ Mushroom model available | MEDIUM |
| **Landak** (Porcupine) | Pest | ✅ Coded | ❌ Missing | MEDIUM |
| **Rayap** (Termite) | Pest | ✅ Coded | ❌ Missing | MEDIUM |
| **Busuk Pucuk** (Top Rot) | Disease | ✅ Coded | ❌ Missing | MEDIUM |
| **Hawar Daun** (Leaf Blight) | Disease | ✅ Coded | ❌ Missing | MEDIUM |
| **Monyet** (Monkey) | Pest | ✅ Coded | ❌ Missing | LOW |

**Current State:** Pests display as text/icons only  
**Need:** 10 individual 3D models (or insect/animal variants)

### 2. **NPC Character Models** (Currently Limited)

Game story mentions interactions with:
- Land market sellers (nursery owners)
- Pembibitan (nursery workers)
- Equipment suppliers
- Market buyers (pengepul, pabrik managers)

**Current:** Only base human variants (worker, suit, man)  
**Need:** Specialized NPC models (older farmer, female worker, merchant, etc.)

### 3. **Equipment/Tools Models** (Cosmetic Gaps)

Game references but has no models for:
- Spray equipment (knapsack sprayer, boom sprayer)
- Fertilizer spreaders
- Harvest baskets/crates
- Watering cans
- Tool shed items

### 4. **Plantation Infrastructure** (Optional Visuals)

Could enhance gameplay visualization:
- Irrigation system (pipes, sprinklers)
- Storage shed
- Worker shelter/rest area
- Farm gate/entrance
- Sign posts

---

## 🎯 ASSET PRIORITY MATRIX

### **TIER 1 - CRITICAL (Required for MVP)**
**Status:** 2 of 2 complete ✅

- ✅ Palm oil models (existing)
- ✅ Character models (existing)
- ✅ Environment (existing)

### **TIER 2 - HIGH PRIORITY (Immediate Download)**
**Status:** 1 of 15 downloaded, 14 remaining ⏳

**Should download first:**
1. **Mushroom models (2)** - For Ganoderma disease visualization
2. **Insect models (3)** - For pest system visuals (ant, bee, butterfly can represent insects)
3. **Snail model (1)** - For pest interaction

**Timeline:** Download now (part of 15-model batch)  
**Effort:** 30-45 minutes

### **TIER 3 - MEDIUM PRIORITY (For Polish & Polish)**
**Status:** 0 of 7, can acquire later

**Could enhance but not critical:**
- Medicinal plant models (3) - for farming variety
- Gemstone models (1) - cosmetic rewards
- Animal models (2 owl variants) - wildlife atmosphere

**Timeline:** Download next update cycle  
**Effort:** Additional 20-30 minutes

### **TIER 4 - LOW PRIORITY (Future Phases)**
**Status:** 0 of 10 pest models

**Major gap but not blocking current phases:**
- 10 pest-specific 3D models
- NPC character variants
- Equipment/tool models
- Breeding system visuals

**Timeline:** Phase 5+ development  
**Effort:** Custom 3D asset acquisition or creation

---

## 📋 COMPLETE ASSET CHECKLIST

### Currently in Use (58 models)
```
✅ Palm Oil Models.................... 2/2
✅ Character Models................... 4/4
✅ Nature/Environment Models......... 50+/50+
✅ Vehicle Models..................... 1/1
✅ Vegetation (existing).............. 1/2
───────────────────────────────────────────
✅ TOTAL IN USE........................ 58+/58+
```

### Planned Downloads (15 models)
```
⏳ Medicinal Plants................... 0/3
⏳ Mushrooms.......................... 0/2
⏳ Insects............................ 0/3
⏳ Gemstones.......................... 0/1
⏳ Animals............................ 0/3
⏳ Vegetation (remaining)............. 1/2
⏳ Eggs............................... 0/1
───────────────────────────────────────────
⏳ READY TO DOWNLOAD.................. 1/15
❌ STILL NEEDED...................... 14/15
```

### Critical Gaps (Not Available Anywhere)
```
❌ Pest-specific models (Caterpillar, Beetle, Grasshopper, Rat, etc)... 10 models
❌ NPC character variants................................................ 5+ models
❌ Equipment/Tools (sprayers, baskets, spreaders)......................... 8+ models
❌ Plantation infrastructure (irrigation, sheds, gates)................... 6+ models
───────────────────────────────────────────
❌ TOTAL CRITICAL GAPS.................................................. 29+ models
```

---

## 💾 FILE ORGANIZATION STATUS

### Currently Downloaded & Integrated
```
assets/models/
├── palm/                    ✅ 2 assets in use
├── character/               ✅ 4 assets in use
├── nature/                  ✅ 50+ assets in use
├── vehicle/                 ✅ 1 asset in use
└── (No other folders)

TOTAL: 57+ assets already integrated
```

### Planned Folder Structure (Created, Awaiting Downloads)
```
assets/models/3d/
├── medicinal_plants/        ⏳ Empty (3 models to download)
├── mushrooms/               ⏳ Empty (2 models to download)
├── insects/                 ⏳ Empty (3 models to download)
├── gemstones/               ⏳ Empty (1 model to download)
├── animals/                 ⏳ Empty (3 models to download)
├── vegetation/              ✅ 1 asset (1 to download)
└── eggs/                    ⏳ Empty (1 model to download)

READY: 7 folders | POPULATED: 1 folder (grass_medium_01.glb)
AWAITING: 14 models
```

---

## 🚀 IMMEDIATE ACTION ITEMS

### **What to do NOW (Next 1 hour):**

1. **Download 15 planned models**
   ```bash
   cd KebunSawitSim/assets/models/3d/
   bash MANUAL_DOWNLOAD.sh          # View all links
   ```
   
2. **Manual Download Process:**
   - Click each link
   - Choose GLTF format
   - Extract ZIP files
   - Save .glb to correct folder
   - Time: 30-45 minutes

3. **Auto-Generate Scenes:**
   ```bash
   python3 download_helper.py wrap  # Creates .tscn files
   ```

4. **Verify in Godot:**
   - FileSystem → assets/models/3d/
   - Check all folders populated

### **What to do LATER (Next update cycle):**

1. **Research & Source 10 Pest Models**
   - Caterpillar, Beetle, Grasshopper, Rat, Fungus, Porcupine, Termite, etc.
   - Can use existing ant/bee models as placeholder representations

2. **Consider NPC Character Variants**
   - Optional female worker variant
   - Elderly farmer character
   - Merchant/buyer character

3. **Plan Equipment Models**
   - Spray equipment (if needed for visual feedback)
   - Harvest baskets (reward visualization)
   - Optional for gameplay

---

## 📊 ASSET STATISTICS

| Metric | Count | Status |
|--------|-------|--------|
| **Assets in Current Use** | 58 | ✅ Complete |
| **Assets Planned & Ready to Download** | 15 | ⏳ 1 downloaded, 14 pending |
| **Critical Gaps Identified** | 29+ | ❌ Need sourcing |
| **Total Assets (current + planned)** | 73 | ⏳ 59 available, 14 pending |
| **Total Assets (with critical gaps)** | 102+ | ⏳ 59 available, 43 missing |

---

## ✅ REQUIREMENTS BY FEATURE

### **Plant/Crop System**
- Palm models: ✅ Complete (2 models)
- Medicinal plants: ⏳ Ready to download (3 models)
- Status: 5 of 5 models ready/available

### **Pest & Disease System**
- Fungal disease (Ganoderma): ⏳ Mushroom model available
- Insect pests (6 types): ❌ Only 3 models planned, 10 total needed
- Rodent pests (rats, porcupines): ❌ No models
- Status: 4 of 16+ models available

### **Character & NPC System**
- Player avatars: ✅ Complete (4 models)
- NPC variants: ❌ Missing specialized roles
- Status: 4 of 12+ models available

### **Environment & Decoration**
- Vegetation: ⏳ 1/2 downloaded (grass)
- Nature elements: ✅ 50+ assets available
- Status: 51 of 52+ models available

### **Cosmetic/Reward System**
- Gemstones: ⏳ Ready to download (21 variations)
- Vehicles: ✅ Complete (pickup truck)
- Equipment: ❌ Missing
- Status: 22 of 25+ models available

---

## 📝 RECOMMENDATIONS

### **Short-term (This Week)**
1. ✅ Download the 15 prepared models (1 hour)
2. ✅ Integrate into Godot project
3. ⏳ Use mushroom model for Ganoderma visualization
4. ⏳ Use insect models for pest representation

### **Medium-term (This Month)**
1. Research and source 10 pest-specific models (or use existing variants)
2. Create simple placeholder equipment models (if needed)
3. Test pest visualization with available assets

### **Long-term (Future Phases)**
1. Commission custom NPC character models
2. Add specialized equipment models if gameplay requires visual feedback
3. Consider plantation infrastructure models for immersion

---

## 🎯 SUMMARY

### Current Status:
- **Assets in Use:** 58 models ✅
- **Assets Ready to Download:** 15 models ⏳
- **Critical Gaps:** 29+ models ❌

### Next Steps:
1. Download 15 planned models (30-45 min)
2. Complete Tier 2 integration
3. Plan Tier 4 pest model acquisition

### Long-term Goal:
- Target: 100+ quality 3D assets for full visual immersion
- Current: 58 in use + 15 ready = 73 available
- Gap: 27+ models needed for complete pest/NPC/equipment system

---

**Document Updated:** 2026-10-17  
**Prepared by:** Claude Code  
**For:** GDD Simulator (Kebun Sawit Simulator)  
**Project Status:** MVP Development - Phases 1-6 Active
