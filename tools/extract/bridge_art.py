#!/usr/bin/env python3
"""Encode the canonical bridge illustration without painting or changing its geometry.
Deck, coping and pier measurements are in scripts/bridge.gd; audit samples are in art_axis_measure.json.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
target = ROOT / 'assets/art/village/bridge.webp'
temporary = target.with_suffix('.tmp')
Image.open(ROOT / 'assets/source/bridge-new.png').save(temporary, 'WEBP', quality=94, alpha_quality=100, method=6, exact=True)
temporary.replace(target)
