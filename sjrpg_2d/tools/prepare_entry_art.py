#!/usr/bin/env python3
"""Split the canonical generated character-selection diptych; preserve the original."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
source = Image.open(ROOT / 'assets/source/hero-selection.png').convert('RGB')
for index, hero in enumerate(['warrior', 'mage']):
    region = source.crop((index * source.width // 2, 0, (index + 1) * source.width // 2, source.height))
    region.thumbnail((768, 1024), Image.Resampling.LANCZOS)
    region.save(ROOT / f'assets/art/ui/hero-{hero}.webp', 'WEBP', quality=92, method=6)
