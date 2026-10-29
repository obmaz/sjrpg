"""Pack approved generated D1 circular buttons without repainting their artwork."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path
from PIL import Image

SHEETS = {
    'mage': ('exec-99613ef8-71db-4a71-ac94-1bc72bc94a1d.png', 6, 5),
    'warrior': ('exec-dfd45df4-0e14-483c-9946-3fc68ced9463.png', 6, 5),
    'interface': ('exec-2220b707-042c-4603-af1c-8844b6780067.png', 8, 4),
}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-directory', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    entries = {}
    for name, (filename, columns, rows) in SHEETS.items():
        source = args.source_directory / filename
        image = Image.open(source).convert('RGBA')
        output = Image.new('RGBA', (columns * 192, rows * 192))
        for row in range(rows):
            for column in range(columns):
                tile = image.crop((round(column * image.width / columns),
                    round(row * image.height / rows),
                    round((column + 1) * image.width / columns),
                    round((row + 1) * image.height / rows)))
                # Uniform square cells retain the entire authored round rim.
                tile = tile.convert('RGBa').resize((176, 176), Image.Resampling.LANCZOS).convert('RGBA')
                output.alpha_composite(tile, (column * 192 + 8, row * 192 + 8))
        runtime = root / f'flutter_game/art/d1-{name}.webp'
        original = root / f'docs/art/d1-{name}-original.png'
        output.save(runtime, format='WEBP', lossless=True, method=6, exact=True)
        shutil.copyfile(source, original)
        entries[name] = {
            'original': str(original.relative_to(root)),
            'originalSha256': hashlib.sha256(source.read_bytes()).hexdigest(),
            'runtime': str(runtime.relative_to(root)),
            'runtimeSha256': hashlib.sha256(runtime.read_bytes()).hexdigest(),
            'columns': columns, 'rows': rows, 'cell': 192, 'gutter': 8,
            'decodedRGBABytes': output.width * output.height * 4,
        }
    (root / 'docs/art/d1-icons-provenance.json').write_text(json.dumps({
        'generator': 'image_gen', 'style': 'approved D1',
        'packer': 'tools/prepare-d1-icons.py', 'sheets': entries,
        'method': 'Uniform grid slicing, premultiplied alpha resampling and transparent gutters; no repainting.',
    }, indent=4) + '\n')

if __name__ == '__main__':
    main()
