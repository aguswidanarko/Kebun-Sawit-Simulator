#!/usr/bin/env python3
"""
Asset Download Helper Script
Helps manage and organize 3D asset downloads for GDD Simulator

This script provides utilities for:
1. Checking which assets are downloaded
2. Creating scene wrappers for GLB files
3. Organizing assets into correct folders
"""

import os
import json
from pathlib import Path
from dataclasses import dataclass
from typing import List, Dict

# Define asset structure
@dataclass
class Asset:
    name: str
    category: str
    creator: str
    license: str
    sketchfab_url: str = None
    polyhaven_url: str = None
    filename: str = None

# Asset catalog
ASSETS = [
    # Medicinal Plants
    Asset("Ginseng", "medicinal_plants", "KaMi", "CC-BY",
          sketchfab_url="https://sketchfab.com/3d-models/ginseng-213a2e16b77041839e91ceb63dbc2b4b",
          filename="ginseng.glb"),
    Asset("Ginger", "medicinal_plants", "The Whz", "CC-BY",
          sketchfab_url="https://sketchfab.com/3d-models/ginger-root-zingiber-officinale-206c458052cc40a29c169733ce887d62",
          filename="ginger.glb"),
    Asset("Turmeric", "medicinal_plants", "anuch", "CC-BY",
          sketchfab_url="https://sketchfab.com/3d-models/turmeric-7b7195c2971243e7b19dcc11b8ec26fc",
          filename="turmeric.glb"),

    # Mushrooms
    Asset("Mushroom 2", "mushrooms", "plaggy", "CC0",
          sketchfab_url="https://sketchfab.com/3d-models/cc0-mushroom-2-c9dba020d1064e0fba2cbfa561e32748",
          filename="mushroom_basic.glb"),
    Asset("Earthstar Mushroom", "mushrooms", "ffish.asia", "CC0",
          sketchfab_url="https://sketchfab.com/3d-models/cc0-earthstar-mushroom-a-hygrometricus-a6fcfabf95c94284bc4a675dd12880b0",
          filename="earthstar.glb"),

    # Insects
    Asset("Low Poly Ant", "insects", "CGCroissant", "CC-BY",
          sketchfab_url="https://sketchfab.com/3d-models/low-poly-ant-23027ae584404a2b8dc678aff55da9ed",
          filename="ant.glb"),
    Asset("Lowpoly Bee", "insects", "Alex (alemue)", "CC-BY",
          sketchfab_url="https://sketchfab.com/3d-models/lowpoly-bee-96d626f8a53341e69b31fa0be5bab105",
          filename="bee.glb"),
    Asset("Low Poly Butterfly", "insects", "mankindforward", "CC-BY",
          sketchfab_url="https://sketchfab.com/3d-models/low-poly-butterfly-74e5a3fb23044eaa94a84a0518ef07a2",
          filename="butterfly.glb"),

    # Gemstones
    Asset("Gems Collection", "gemstones", "Vivien Deroche", "CC-BY",
          sketchfab_url="https://sketchfab.com/3d-models/gems-21-different-shapes-1fb35b1aefae4d819dde9de90162602a",
          filename="gems_collection.glb"),

    # Animals
    Asset("Keong Mas", "animals", "alfrs", "CC-BY",
          sketchfab_url="https://sketchfab.com/3d-models/keong-mas-763c12af90f6449b858f0301c6efb0d5",
          filename="keong_mas.glb"),
    Asset("Barn Owl (Detailed)", "animals", "Innovation Studio", "CC-BY",
          sketchfab_url="https://sketchfab.com/3d-models/common-barn-owl-19c989a6681145bc999c332699eb852e",
          filename="barn_owl_detailed.glb"),
    Asset("Barn Owl (Low Poly)", "animals", "kristnby", "CC-BY",
          sketchfab_url="https://sketchfab.com/3d-models/barn-owltyto-alba-af3cdd38e029430d9c131370ebf1bb33",
          filename="barn_owl_lowpoly.glb"),

    # Vegetation
    Asset("Grass Medium 01", "vegetation", "Poly Haven", "CC0",
          polyhaven_url="https://polyhaven.com/a/grass_medium_01",
          filename="grass_medium_01.glb"),
    Asset("Weed Plant 02", "vegetation", "Poly Haven", "CC0",
          polyhaven_url="https://polyhaven.com/a/weed_plant_02",
          filename="weed_plant_02.glb"),

    # Eggs
    Asset("Eggs Collection", "eggs", "LanaGre", "CC-BY",
          sketchfab_url="https://sketchfab.com/3d-models/eggs-30d391929e25432e87f84f5cfe02a0fa",
          filename="eggs_set.glb"),
]

class AssetManager:
    def __init__(self, base_path: str = "."):
        self.base_path = Path(base_path)
        self.assets_path = self.base_path / "assets" / "models" / "3d"

    def check_downloaded_assets(self) -> Dict[str, List[str]]:
        """Check which assets are already downloaded"""
        status = {
            "downloaded": [],
            "missing": [],
            "total": len(ASSETS)
        }

        for asset in ASSETS:
            asset_path = self.assets_path / asset.category / asset.filename
            if asset_path.exists():
                status["downloaded"].append(f"{asset.name} ({asset.category}/{asset.filename})")
            else:
                status["missing"].append(f"{asset.name} - Download from {asset.sketchfab_url or asset.polyhaven_url}")

        return status

    def print_download_status(self):
        """Print current download status"""
        status = self.check_downloaded_assets()

        print("\n" + "="*60)
        print("3D ASSET DOWNLOAD STATUS")
        print("="*60)
        print(f"\nTotal Assets: {status['total']}")
        print(f"Downloaded: {len(status['downloaded'])}")
        print(f"Missing: {len(status['missing'])}")

        if status['downloaded']:
            print("\n✓ DOWNLOADED:")
            for item in status['downloaded']:
                print(f"  • {item}")

        if status['missing']:
            print("\n✗ MISSING (Action Required):")
            for item in status['missing']:
                print(f"  • {item}")

        print("\n" + "="*60)

    def create_scene_wrappers(self):
        """Create .tscn scene files for each downloaded GLB"""
        print("\nChecking for GLB files to wrap in scenes...")

        created_count = 0
        for category_dir in self.assets_path.iterdir():
            if not category_dir.is_dir() or category_dir.name.startswith("_"):
                continue

            for glb_file in category_dir.glob("*.glb"):
                scene_file = glb_file.with_suffix(".tscn")

                if not scene_file.exists():
                    # Create scene wrapper
                    scene_content = self._create_scene_template(glb_file)
                    scene_file.write_text(scene_content)
                    print(f"  ✓ Created {scene_file.name}")
                    created_count += 1

        print(f"\nTotal scenes created: {created_count}")

    def _create_scene_template(self, glb_path: Path) -> str:
        """Generate scene content for a GLB file"""
        # Get relative path from project root
        relative_path = glb_path.relative_to(self.base_path)

        scene_content = f"""[gd_scene load_steps=2 format=3 uid="uid:generated__{glb_path.stem}"]

[ext_resource type="Mesh" path="res://{relative_path.as_posix()}" id="1_mesh"]

[node name="{glb_path.stem}" type="Node3D"]

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
mesh = SubResource("1_mesh")
"""
        return scene_content

    def print_asset_catalog(self):
        """Print all available assets"""
        print("\n" + "="*60)
        print("AVAILABLE 3D ASSETS")
        print("="*60)

        current_category = None
        for asset in ASSETS:
            if asset.category != current_category:
                current_category = asset.category
                print(f"\n[{current_category.upper()}]")

            source = "Sketchfab" if asset.sketchfab_url else "Poly Haven"
            print(f"  • {asset.name} (by {asset.creator})")
            print(f"    License: {asset.license}")
            print(f"    File: {asset.filename}")
            print(f"    Source: {source}\n")

def main():
    """Main script entry point"""
    import sys

    # Get script directory
    script_dir = Path(__file__).parent

    # Initialize manager
    manager = AssetManager(base_path=str(script_dir.parent.parent))

    if len(sys.argv) > 1:
        command = sys.argv[1]

        if command == "status":
            manager.print_download_status()
        elif command == "wrap":
            manager.create_scene_wrappers()
        elif command == "catalog":
            manager.print_asset_catalog()
        else:
            print(f"Unknown command: {command}")
            print("\nUsage: python3 download_helper.py [status|wrap|catalog]")
            print("  status  - Check which assets are downloaded")
            print("  wrap    - Create scene wrappers for downloaded GLBs")
            print("  catalog - Print all available assets")
    else:
        manager.print_download_status()

if __name__ == "__main__":
    main()
