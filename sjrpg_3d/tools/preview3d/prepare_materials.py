"""Pack generated front-on village materials, using exact crops and WebP only."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/art/preview3d"
SOURCE = ROOT / "assets/source/preview3d/village-materials.png"
PATCHES = {"limestone": (0, 0), "slate": (1, 0), "timber": (0, 1), "bark": (1, 1)}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    image = Image.open(SOURCE).convert("RGB")
    assert image.width == image.height and image.width % 2 == 0
    tile = image.width // 2
    records = {}
    previous = json.loads((OUT / "materials.json").read_text())
    OUT.mkdir(parents=True, exist_ok=True)
    for key, (x, y) in PATCHES.items():
        box = (x * tile, y * tile, (x + 1) * tile, (y + 1) * tile)
        target = OUT / (key + ".webp")
        if key in ("limestone", "slate"):
            # Owned by make_clean_masonry.py; keep its reviewed record unchanged.
            records[key] = previous["materials"][key]
            continue
        image.crop(box).save(target, "WEBP", quality=94, method=6)
        records[key] = {"source": str(SOURCE.relative_to(ROOT)), "source_sha256": sha(SOURCE),
                        "crop": list(box), "path": str(target.relative_to(ROOT)),
                        "sha256": sha(target), "size": [tile, tile],
                        "operation": "Exact quadrant crop and WebP encoding; no upscaling, painting or source relighting."}
        imported = target.with_suffix(".webp.import")
        if imported.exists():
            continue
        path = "res://" + str(target.relative_to(ROOT))
        cache = "res://.godot/imported/" + target.name + "-" + hashlib.md5(path.encode()).hexdigest() + ".ctex"
        imported.write_text(f'''[remap]
importer="texture"
type="CompressedTexture2D"
path="{cache}"
metadata={{"vram_texture": false}}

[deps]
source_file="{path}"
dest_files=PackedStringArray("{cache}")

[params]
compress/mode=1
compress/lossy_quality=0.9
mipmaps/generate=true
process/fix_alpha_border=true
''')
    record = {"purpose": "Shared front-on native3D village albedos; 2D sprite art is unchanged.",
              "generation": previous["generation"],
              "authoritative_reference": {"path": "assets/source/style/approved-game-reference.jpg",
                                          "sha256": sha(ROOT / "assets/source/style/approved-game-reference.jpg")},
              "materials": records,
              "physical_scale": {"limestone_tile_m": 2.56, "limestone_courses": 8, "slate_tile_m": 2.6},
              "limitations": previous["limitations"]}
    (OUT / "materials.json").write_text(json.dumps(record, indent=2, ensure_ascii=False) + "\n")
    # Normalize any newly created import metadata without touching packed image bytes.
    subprocess.run([sys.executable, str(ROOT / "tools/texture_policy.py"), "--apply"], check=True)
    print("Packed", len(records), "material tiles at", tile, "px")


if __name__ == "__main__":
    main()
