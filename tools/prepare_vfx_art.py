#!/usr/bin/env python3
"""Pack the canonical four-cell generated impact illustration; requires Pillow."""
from pathlib import Path
from PIL import Image
root = Path(__file__).resolve().parents[1]
image = Image.open(root/'assets/source/impact-atlas.png').convert('RGBA')
atlas = Image.new('RGBA', (1024,256))
for index in range(4):
    cell = image.crop((index*image.width//4,0,(index+1)*image.width//4,image.height))
    cell.thumbnail((256,256),Image.Resampling.LANCZOS)
    atlas.paste(cell,(index*256+(256-cell.width)//2,(256-cell.height)//2))
target = root/'assets/art/effects/impact-atlas.webp'
temporary = target.with_suffix('.tmp')
atlas.save(temporary,'WEBP',quality=94,alpha_quality=100,exact=True)
temporary.replace(target)
