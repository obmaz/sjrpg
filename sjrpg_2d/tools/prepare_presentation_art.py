#!/usr/bin/env python3
"""Pack generated UI metal and registered four-phase VFX without painting new artwork."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CELL = 256


def record(path):
    path = Path(path)
    return dict(path=str(path.relative_to(ROOT)), sha256=hashlib.sha256(path.read_bytes()).hexdigest())


def save(image, path):
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_suffix('.tmp')
    image.save(temporary, 'WEBP', quality=94, alpha_quality=100, exact=True, method=6)
    temporary.replace(target)
    return dict(**record(target), size=list(image.size))


def main():
    ui_path = ROOT / 'assets/source/hud-trim.png'
    effects_path = ROOT / 'assets/source/combat-frames.png'
    map_path = ROOT / 'assets/source/map-rim.png'
    ui_source = Image.open(ui_path).convert('RGBA')
    sheet = Image.new('RGBA', (CELL * 2, CELL * 2))
    frames = {}
    for index, key in enumerate(['active', 'empty', 'map', 'corner']):
        x, y = index % 2, index // 2
        region = ui_source.crop((x * ui_source.width // 2, y * ui_source.height // 2,
                                 (x + 1) * ui_source.width // 2, (y + 1) * ui_source.height // 2))
        source_offset = (x * ui_source.width // 2, y * ui_source.height // 2)
        if key == 'map':
            region = Image.open(map_path).convert('RGBA')
            source_offset = (0, 0)
        bounds = region.getchannel('A').point(lambda a: 255 if a > 24 else 0).getbbox()
        if not bounds:
            raise ValueError('Missing generated trim: ' + key)
        width, height = bounds[2] - bounds[0], bounds[3] - bounds[1]
        side = max(width, height) + 8
        left = round((bounds[0] + bounds[2] - side) / 2)
        top = round((bounds[1] + bounds[3] - side) / 2)
        region = region.crop((left, top, left + side, top + side))
        region = region.convert('RGBa').resize((248, 248), Image.Resampling.LANCZOS).convert('RGBA')
        tile = Image.new('RGBA', (CELL, CELL))
        tile.paste(region, (4, 4))
        actual = tile.getchannel('A').point(lambda a: 255 if a > 8 else 0).getbbox()
        half = max(CELL / 2 - actual[0], CELL / 2 - actual[1], actual[2] - CELL / 2, actual[3] - CELL / 2)
        sheet.paste(tile, (x * CELL, y * CELL))
        frames[key] = dict(source=[x * CELL, y * CELL, CELL, CELL], paint_half=half,
                           source_roi=[left + source_offset[0], top + source_offset[1], side, side],
                           source_path=str((map_path if key == "map" else ui_path).relative_to(ROOT)))
    ui = dict(**save(sheet, 'assets/art/hud/generated-trim.webp'), frames=frames)
    effects_source = Image.open(effects_path).convert('RGB')
    effects = Image.new('RGB', (CELL * 4, CELL * 4))
    for row in range(4):
        for col in range(4):
            # Uniform cells retain registration and relative growth across the animation.
            region = effects_source.crop((col * effects_source.width // 4, row * effects_source.height // 4,
                                          (col + 1) * effects_source.width // 4, (row + 1) * effects_source.height // 4))
            region = region.resize((240, 240), Image.Resampling.LANCZOS)
            effects.paste(region, (col * CELL + 8, row * CELL + 8))
    impact = dict(**save(effects, 'assets/art/effects/combat-frames.webp'), cell=CELL, rows=4, columns=4,
                  elements=['physical', 'fire', 'lightning', 'frost'], blend='add', phases=['contact', 'peak', 'fragments', 'tail'])
    data = dict(sources=[record(ui_path), record(map_path), record(effects_path)],
                reference=record(ROOT / 'assets/source/style/approved-game-reference.jpg'),
                generation=record(ROOT / 'tools/extract/presentation_generation.json'), ui=ui, impact=impact)
    (ROOT / 'assets/data/presentation_art.json').write_text(json.dumps(data, indent=1) + '\n')
    print('Generated presentation art: 4 UI trims, 16 registered FX frames')


if __name__ == '__main__':
    main()
