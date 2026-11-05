#!/usr/bin/env python3
"""Pack the existing generated selection artwork for the pre-engine loader.

Run with Pillow installed: python3 web/prepare_art.py
No art is redrawn, and the original remains in assets/art/ui.
"""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
image = Image.open(root / "assets/art/ui/select-scene.png").convert("RGB")
image.thumbnail((1440, 900), Image.Resampling.LANCZOS)
image.save(root / "web/loading-bg.webp", "WEBP", quality=83, method=6)
