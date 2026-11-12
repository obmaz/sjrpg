#!/usr/bin/env python3
"""Pack the canonical defocused forest plate; never paint or replace its pixels."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
image = Image.open(ROOT / 'assets/source/ui/selection-forest.png').convert('RGB')
image.thumbnail((960, 1707), Image.Resampling.LANCZOS)
target = ROOT / 'assets/ui/selection/selection-forest.webp'
temporary = target.with_suffix('.tmp')
image.save(temporary, 'WEBP', quality=88, method=6)
temporary.replace(target)
