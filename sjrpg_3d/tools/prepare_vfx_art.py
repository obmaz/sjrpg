#!/usr/bin/env python3
"""Pack the canonical reward illustration; animated contacts use prepare_presentation_art.py; requires Pillow."""
from pathlib import Path
from PIL import Image
root = Path(__file__).resolve().parents[1]
for name, count in [('reward-atlas',3)]:
    image = Image.open(root/f'assets/source/{name}.png').convert('RGBA')
    atlas = Image.new('RGBA',(256*count,256))
    for index in range(count):
        cell = image.crop((index*image.width//count,0,(index+1)*image.width//count,image.height))
        cell = cell.convert('RGBa')
        cell.thumbnail((256,256),Image.Resampling.LANCZOS)
        atlas.paste(cell.convert('RGBA'),(index*256+(256-cell.width)//2,(256-cell.height)//2))
    target = root/f'assets/art/effects/{name}.webp'
    temporary = target.with_suffix('.tmp')
    atlas.save(temporary,'WEBP',quality=94,alpha_quality=100,exact=True)
    temporary.replace(target)
