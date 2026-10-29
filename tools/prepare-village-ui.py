"""Pack measured alpha silhouettes from the generated gateway/menu sheet."""
import hashlib
import json
import shutil
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'docs/art/village-ui-original.png'
GROUND_SOURCE = ROOT / 'docs/art/settlement-forest-open-approach-original.png'

def measured(image, region):
    tile = image.crop(region)
    box = tile.getchannel('A').point(lambda a: 255 if a > 96 else 0).getbbox()
    return (region[0] + box[0], region[1] + box[1],
            region[0] + box[2], region[1] + box[3])

def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path)
    parser.add_argument('--ground-source', type=Path)
    args = parser.parse_args()
    if args.source:
        shutil.copyfile(args.source, SOURCE)
    if args.ground_source:
        shutil.copyfile(args.ground_source, GROUND_SOURCE)
    ground = {}
    if GROUND_SOURCE.exists():
        runtime = ROOT / 'flutter_game/art/settlement-forest.webp'
        Image.open(GROUND_SOURCE).save(runtime, lossless=True, exact=True)
        ground = {
            'original': str(GROUND_SOURCE.relative_to(ROOT)),
            'sha256': hashlib.sha256(GROUND_SOURCE.read_bytes()).hexdigest(),
            'runtime': str(runtime.relative_to(ROOT)),
            'runtimeSha256': hashlib.sha256(runtime.read_bytes()).hexdigest(),
            'edit': 'Remove the old painted south gate beneath the separate generated open gateway; preserve the other village landmarks and wall opening.',
        }
    image = Image.open(SOURCE).convert('RGBA')
    gate = measured(image, (0, 0, 1536, 675))
    image.crop(gate).save(ROOT / 'flutter_game/art/village-gateway.webp',
                         lossless=True, exact=True)
    rects = [measured(image, (left, 676, right, 990))
             for left, right in [(35, 365), (420, 745), (790, 1110), (1170, 1500)]]
    atlas = Image.new('RGBA', (4 * 192, 192))
    for i, box in enumerate(rects):
        tile = image.crop(box)
        tile.thumbnail((188, 188), Image.Resampling.LANCZOS)
        atlas.alpha_composite(tile, (i * 192 + (192 - tile.width) // 2,
                                     (192 - tile.height) // 2))
    atlas.save(ROOT / 'flutter_game/art/reference-menus.webp', lossless=True, exact=True)
    (ROOT / 'docs/art/village-ui-provenance.json').write_text(json.dumps({
        'generator': 'image_gen',
        'original': str(SOURCE.relative_to(ROOT)),
        'sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        'packer': 'tools/prepare-village-ui.py',
        'gateSourceRect': gate, 'menuSourceRects': rects,
        'menuCell': 192, 'menuFaceMaximum': 188,
        'forestGround': ground,
        'style': 'Reference: thin bronze circular rims, chest, sword book, quest scroll, iron cog; mossy green-roofed open village gateway.',
    }, indent=4) + '\n')

if __name__ == '__main__':
    main()
