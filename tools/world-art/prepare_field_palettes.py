"""Extract low-frequency *ground* colors from generated chapter master art.

No geometry is inferred: blue water, bright markers and dark architecture are
excluded. Runtime roads/water/solids remain the authored gameplay geometry.
Images stay untouched; output is a compact 16x12 table of color data.
"""
import colorsys
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
COLS, ROWS = 16, 12
FALLBACKS = {
    'forest': (120, 133, 75), 'sands': (177, 147, 94),
    'past': (145, 139, 109), 'future': (100, 113, 113),
    'tombs': (130, 122, 104), 'foundry': (116, 112, 104),
    'convergence': (122, 137, 106),
}


def ground_color(pixel):
    r, g, b = [v / 255 for v in pixel[:3]]
    h, saturation, value = colorsys.rgb_to_hsv(r, g, b)
    # Only color data reaches the game. Reject water's distinctive blue/cyan
    # and bright emissive accents so an art lake never stains walkable land.
    return (value > .21 and value < .91
            and not (saturation > .24 and .46 < h < .70)
            and not (saturation > .68 and value > .72))


def extract(path, fallback):
    image = Image.open(path).convert('RGB')
    colors = []
    for row in range(ROWS):
        for col in range(COLS):
            box = (int(col * image.width / COLS), int(row * image.height / ROWS),
                   int((col + 1) * image.width / COLS), int((row + 1) * image.height / ROWS))
            pixels = list(image.crop(box).getdata())
            land = [pixel for pixel in pixels if ground_color(pixel)]
            average = tuple(round(sum(p[i] for p in land) / len(land)) for i in range(3)) if land else fallback
            # A restrained master palette preserves readable characters; high
            # frequency detail is provided by native-size generated surfaces.
            colors.append(tuple(round(average[i] * .78 + fallback[i] * .22) for i in range(3)))
    return colors


def main():
    manifest = json.loads((ROOT / 'docs/art/field-designs.json').read_text())
    lines = ["// Generated from chapter master art by tools/world-art/prepare_field_palettes.py.",
             "// Ground color only; never a source of collision or water geometry.",
             "import 'dart:ui';", "", "const fieldPaletteColumns = 16;",
             "const fieldPaletteRows = 12;", "", "const fieldPalettes = <String, List<Color>>{"]
    for stage, fallback in FALLBACKS.items():
        colors = extract(ROOT / manifest['chapters'][stage]['source'], fallback)
        lines.append(f"  '{stage}': [")
        for start in range(0, len(colors), 8):
            lines.append('    ' + ', '.join(f'Color(0xff{r:02x}{g:02x}{b:02x})' for r, g, b in colors[start:start + 8]) + ',')
        lines.append('  ],')
    lines.append('};')
    (ROOT / 'flutter_game/lib/field_palettes.dart').write_text('\n'.join(lines) + '\n')

if __name__ == '__main__':
    main()
