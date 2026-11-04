#!/usr/bin/env python3
"""Pack canonical generated impact/reward illustrations; requires Pillow."""
from pathlib import Path
from PIL import Image
root = Path(__file__).resolve().parents[1]
for name, count in [('impact-atlas',4),('reward-atlas',3)]:
    image = Image.open(root/f'assets/source/{name}.png').convert('RGBA')
    atlas = Image.new('RGBA',(256*count,256))
    for index in range(count):
        cell = image.crop((index*image.width//count,0,(index+1)*image.width//count,image.height))
        if name == 'reward-atlas':
            cell = cell.convert('RGBa')
        cell.thumbnail((256,256),Image.Resampling.LANCZOS)
        atlas.paste(cell.convert('RGBA'),(index*256+(256-cell.width)//2,(256-cell.height)//2))
    target = root/f'assets/art/effects/{name}.webp'
    temporary = target.with_suffix('.tmp')
    atlas.save(temporary,'WEBP',quality=94,alpha_quality=100,exact=True)
    temporary.replace(target)
