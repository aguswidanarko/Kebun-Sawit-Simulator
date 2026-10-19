#!/usr/bin/env python3
"""
Automated Download Script for 3D Assets
Downloads assets from Sketchfab and Poly Haven
"""

import os
import urllib.request
import urllib.error
import zipfile
import shutil
from pathlib import Path
import json
import time

BASE_PATH = Path(__file__).parent
ASSETS_PATH = BASE_PATH

# Poly Haven direct download URLs (CC0 - straightforward)
POLYHAVEN_ASSETS = {
    "vegetation/grass_medium_01.glb": "https://cdn.polyhaven.com/asset_files/models/grass_medium_01_2k.glb",
    "vegetation/weed_plant_02.glb": "https://cdn.polyhaven.com/asset_files/models/weed_plant_02_2k.glb",
}

# Sketchfab direct download attempts
SKETCHFAB_MODELS = {
    # Model ID -> (filename, category)
    "213a2e16b77041839e91ceb63dbc2b4b": ("medicinal_plants/ginseng.glb", "Ginseng"),
    "206c458052cc40a29c169733ce887d62": ("medicinal_plants/ginger.glb", "Ginger"),
    "7b7195c2971243e7b19dcc11b8ec26fc": ("medicinal_plants/turmeric.glb", "Turmeric"),
    "c9dba020d1064e0fba2cbfa561e32748": ("mushrooms/mushroom_basic.glb", "Mushroom 2"),
    "a6fcfabf95c94284bc4a675dd12880b0": ("mushrooms/earthstar.glb", "Earthstar"),
    "23027ae584404a2b8dc678aff55da9ed": ("insects/ant.glb", "Ant"),
    "96d626f8a53341e69b31fa0be5bab105": ("insects/bee.glb", "Bee"),
    "74e5a3fb23044eaa94a84a0518ef07a2": ("insects/butterfly.glb", "Butterfly"),
    "1fb35b1aefae4d819dde9de90162602a": ("gemstones/gems_collection.glb", "Gems"),
    "763c12af90f6449b858f0301c6efb0d5": ("animals/keong_mas.glb", "Golden Snail"),
    "19c989a6681145bc999c332699eb852e": ("animals/barn_owl_detailed.glb", "Barn Owl Detailed"),
    "af3cdd38e029430d9c131370ebf1bb33": ("animals/barn_owl_lowpoly.glb", "Barn Owl Low Poly"),
    "30d391929e25432e87f84f5cfe02a0fa": ("eggs/eggs_set.glb", "Eggs"),
}

def download_file(url, filepath, filename):
    """Download a file with progress indication"""
    try:
        print(f"\n⬇️  Downloading: {filename}")
        print(f"   URL: {url}")

        # Create parent directory if needed
        filepath.parent.mkdir(parents=True, exist_ok=True)

        # Download with progress
        def show_progress(block_num, block_size, total_size):
            downloaded = block_num * block_size
            percent = min(100, int((downloaded / total_size) * 100)) if total_size > 0 else 0
            print(f"   Progress: {percent}%", end='\r')

        urllib.request.urlretrieve(url, filepath, show_progress)
        print(f"\n   ✓ Downloaded: {filepath.name} ({filepath.stat().st_size / 1024 / 1024:.1f} MB)")
        return True

    except urllib.error.HTTPError as e:
        print(f"\n   ✗ HTTP Error {e.code}: {filename}")
        return False
    except Exception as e:
        print(f"\n   ✗ Error downloading {filename}: {e}")
        return False

def download_polyhaven_assets():
    """Download from Poly Haven (CC0 - direct links)"""
    print("\n" + "="*60)
    print("DOWNLOADING FROM POLY HAVEN (CC0)")
    print("="*60)

    success = 0
    failed = 0

    for relative_path, url in POLYHAVEN_ASSETS.items():
        filepath = ASSETS_PATH / relative_path

        if filepath.exists():
            print(f"\n✓ Already exists: {relative_path}")
            success += 1
            continue

        if download_file(url, filepath, relative_path):
            success += 1
        else:
            failed += 1

        time.sleep(1)  # Rate limiting

    print(f"\n✓ Poly Haven: {success} downloaded, {failed} failed")
    return success, failed

def get_sketchfab_download_url(model_id):
    """Try to construct Sketchfab direct download URL"""
    # Sketchfab provides glTF exports via a specific pattern
    # This attempts the direct download URL
    return f"https://sketchfab.com/models/{model_id}/download"

def download_sketchfab_assets():
    """Download from Sketchfab (CC-BY/CC0)"""
    print("\n" + "="*60)
    print("DOWNLOADING FROM SKETCHFAB (CC-BY/CC0)")
    print("="*60)

    success = 0
    failed = 0

    for model_id, (relative_path, name) in SKETCHFAB_MODELS.items():
        filepath = ASSETS_PATH / relative_path

        if filepath.exists():
            print(f"\n✓ Already exists: {name}")
            success += 1
            continue

        # Try direct download URL pattern
        url = get_sketchfab_download_url(model_id)

        if download_file(url, filepath, name):
            success += 1
        else:
            failed += 1
            print(f"   💡 If download fails, manually download from:")
            print(f"      https://sketchfab.com/models/{model_id}/download")

        time.sleep(1.5)  # Rate limiting (be respectful)

    print(f"\n✓ Sketchfab: {success} downloaded, {failed} failed")
    return success, failed

def extract_glb_from_zips():
    """Extract GLB files from downloaded zips"""
    print("\n" + "="*60)
    print("EXTRACTING GLB FILES FROM ZIPS")
    print("="*60)

    extracted = 0

    for root, dirs, files in os.walk(ASSETS_PATH):
        for file in files:
            if file.endswith('.zip'):
                zip_path = Path(root) / file
                print(f"\n📦 Extracting: {file}")

                try:
                    with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                        # Look for .glb files in zip
                        for item in zip_ref.namelist():
                            if item.endswith('.glb'):
                                # Extract to same directory as zip
                                extracted_path = zip_path.parent / Path(item).name

                                with zip_ref.open(item) as source, open(extracted_path, 'wb') as target:
                                    target.write(source.read())

                                print(f"   ✓ Extracted: {Path(item).name}")
                                extracted += 1

                        # Delete zip after extraction
                        zip_path.unlink()
                        print(f"   ✓ Removed zip")

                except Exception as e:
                    print(f"   ✗ Error extracting {file}: {e}")

    print(f"\n✓ Total extracted: {extracted} files")
    return extracted

def verify_downloads():
    """Verify all downloads"""
    print("\n" + "="*60)
    print("VERIFICATION SUMMARY")
    print("="*60)

    total_files = 0
    total_size = 0

    for category in ["medicinal_plants", "mushrooms", "insects", "gemstones", "animals", "vegetation", "eggs"]:
        category_path = ASSETS_PATH / category
        if not category_path.exists():
            continue

        glb_files = list(category_path.glob("*.glb"))
        if glb_files:
            print(f"\n{category.upper()}:")
            for glb in glb_files:
                size_mb = glb.stat().st_size / 1024 / 1024
                print(f"  ✓ {glb.name} ({size_mb:.1f} MB)")
                total_files += 1
                total_size += size_mb

    print(f"\n{'='*60}")
    print(f"✓ Total files downloaded: {total_files}")
    print(f"✓ Total size: {total_size:.1f} MB")
    print(f"{'='*60}")

    return total_files

def main():
    print("\n╔════════════════════════════════════════════════════════════════╗")
    print("║        AUTOMATED 3D ASSET DOWNLOAD SCRIPT                    ║")
    print("║        GDD Simulator - Kebun Sawit Simulator                 ║")
    print("╚════════════════════════════════════════════════════════════════╝")

    # Download from Poly Haven
    ph_success, ph_failed = download_polyhaven_assets()

    # Download from Sketchfab
    sf_success, sf_failed = download_sketchfab_assets()

    # Extract GLBs from zips
    extracted = extract_glb_from_zips()

    # Verify
    total = verify_downloads()

    # Final status
    print(f"\n{'='*60}")
    print("📊 DOWNLOAD SUMMARY:")
    print(f"  Poly Haven: {ph_success}/{len(POLYHAVEN_ASSETS)} ✓")
    print(f"  Sketchfab: {sf_success}/{len(SKETCHFAB_MODELS)} ✓")
    print(f"  Total Downloaded: {total}/{len(POLYHAVEN_ASSETS) + len(SKETCHFAB_MODELS)}")
    print(f"{'='*60}")

    if total < len(POLYHAVEN_ASSETS) + len(SKETCHFAB_MODELS):
        print("\n⚠️  Some downloads failed. This might be due to:")
        print("  • Network issues")
        print("  • Sketchfab requiring manual download")
        print("  • Rate limiting")
        print("\n💡 NEXT STEPS:")
        print("  1. Run: python3 download_helper.py status")
        print("  2. For missing files, manually download from DOWNLOAD_QUICK_GUIDE.md")
        print("  3. Place GLB files in correct folders")
        print("  4. Run: python3 download_helper.py wrap")
    else:
        print("\n✅ ALL DOWNLOADS COMPLETE!")
        print("\n🚀 NEXT STEP: Create scene wrappers")
        print("   Run: python3 download_helper.py wrap")

    print()

if __name__ == "__main__":
    main()
