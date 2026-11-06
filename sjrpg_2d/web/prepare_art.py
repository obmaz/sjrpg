#!/usr/bin/env python3
"""Pack the existing generated selection artwork for the pre-engine loader.

Run with Pillow installed: python3 web/prepare_art.py
No art is redrawn, and the original remains in assets/art/ui.
"""
from pathlib import Path
import json
from PIL import Image

root = Path(__file__).resolve().parents[1]
image = Image.open(root / "assets/art/ui/select-scene.png").convert("RGB")
image.thumbnail((1440, 900), Image.Resampling.LANCZOS)
image.save(root / "web/loading-bg.webp", "WEBP", quality=83, method=6)
# The ready action uses the same generated metal as the guardian selection screen.
selection = json.loads((root / "assets/data/selection_ui.json").read_text())
source = Image.open(root / selection["source"]).convert("RGBA")
source.crop(selection["source_rects"]["primary"]).save(root / "web/entry-button.webp", "WEBP", quality=94, method=6)
# Reuse the game's existing hero portrait; installation icons introduce no new source art.
portrait = Image.open(root / "assets/art/hud/portrait-warrior.webp").convert("RGB")
for size in (180, 192, 512):
    portrait.resize((size, size), Image.Resampling.LANCZOS).save(root / f"web/install-{size}.png", optimize=True)
