#!/usr/bin/env python3
"""Package the generated entry illustration, without painting text or controls."""
from pathlib import Path
import shutil
from PIL import Image
root=Path(__file__).resolve().parents[1]
source=root/'assets/art/entry'
shutil.copy2(source/'start-background.webp',root/'web/loading-bg.webp')
# Installation uses the newly generated warrior artwork, not the old photo portrait.
hero=Image.open(source/'warrior.webp').convert('RGB')
side=min(hero.size)
portrait=hero.crop(((hero.width-side)//2,0,(hero.width+side)//2,side))
for size in (180,192,512):
    portrait.resize((size,size),Image.Resampling.LANCZOS).save(root/f'web/install-{size}.png',optimize=True)
