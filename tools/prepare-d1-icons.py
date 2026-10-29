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

def button_bounds(image, columns, rows):
    # Generated sheets are not grids: locate each opaque circular face first.
    width, height = image.size
    mask = bytearray(image.getchannel('A').point(lambda a: 255 if a > 96 else 0).tobytes())
    regions = []
    for start, value in enumerate(mask):
        if not value:
            continue
        mask[start] = 0
        stack = [start]
        area = 0
        left = right = start % width
        top = bottom = start // width
        while stack:
            pos = stack.pop()
            x, y = pos % width, pos // width
            area += 1
            left, right = min(left, x), max(right, x)
            top, bottom = min(top, y), max(bottom, y)
            for near in (pos - width if y else -1,
                         pos + width if y + 1 < height else -1,
                         pos - 1 if x else -1,
                         pos + 1 if x + 1 < width else -1):
                if near >= 0 and mask[near]:
                    mask[near] = 0
                    stack.append(near)
        if area > 10000:
            regions.append((max(0, left - 1), max(0, top - 1),
                            min(width, right + 2), min(height, bottom + 2)))
    if len(regions) != columns * rows:
        raise ValueError(f'Expected {columns * rows} isolated buttons, found {len(regions)}')
    regions.sort(key=lambda box: (box[1] + box[3]) / 2)
    ordered = []
    for row in range(rows):
        ordered.extend(sorted(regions[row * columns:(row + 1) * columns], key=lambda box: box[0]))
    return ordered


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-directory', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    entries = {}
    for name, (filename, columns, rows) in SHEETS.items():
        source = (args.source_directory / filename if args.source_directory else
                  root / f'docs/art/d1-{name}-original.png')
        image = Image.open(source).convert('RGBA')
        output = Image.new('RGBA', (columns * 192, rows * 192))
        bounds = button_bounds(image, columns, rows)
        for index, box in enumerate(bounds):
            tile = image.crop(box)
            tile = tile.convert('RGBa').resize((176, 176), Image.Resampling.LANCZOS).convert('RGBA')
            output.alpha_composite(tile, (index % columns * 192 + 8, index // columns * 192 + 8))
        runtime = root / f'flutter_game/art/d1-{name}.webp'
        original = root / f'docs/art/d1-{name}-original.png'
        output.save(runtime, format='WEBP', lossless=True, method=6, exact=True)
        if source.resolve() != original.resolve():
            shutil.copyfile(source, original)
        entries[name] = {
            'original': str(original.relative_to(root)),
            'originalSha256': hashlib.sha256(source.read_bytes()).hexdigest(),
            'runtime': str(runtime.relative_to(root)),
            'runtimeSha256': hashlib.sha256(runtime.read_bytes()).hexdigest(),
            'columns': columns, 'rows': rows, 'cell': 192, 'gutter': 8,
            'sourceRects': bounds,
            'decodedRGBABytes': output.width * output.height * 4,
        }
    (root / 'docs/art/d1-icons-provenance.json').write_text(json.dumps({
        'generator': 'image_gen', 'style': 'approved D1',
        'packer': 'tools/prepare-d1-icons.py', 'sheets': entries,
        'method': 'Measured per-button alpha bounds, ordered by row, premultiplied resampling and centered gutters; no repainting.',
    }, indent=4) + '\n')

if __name__ == '__main__':
    main()
