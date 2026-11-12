#!/usr/bin/env python3
"""새 바늘잎 묶음을 원본 수식·고정 시드에서 그린다. 기존 그림을 편집하지 않는다."""
from pathlib import Path
from PIL import Image, ImageDraw
import random, hashlib, json
ROOT=Path(__file__).resolve().parents[3]
source=ROOT/'assets/source/vegetation/wild_flora';source.mkdir(parents=True,exist_ok=True);(source/'.gdignore').touch()
rng=random.Random(76451)
image=Image.new('RGBA',(512,512));draw=ImageDraw.Draw(image)
draw.line([(256,477),(251,36)],fill=(56,49,30,255),width=7)
for side in [-1,1]:
 for i in range(35):
  y=70+i*11; t=(y-36)/441; reach=(.15+.85*t)*190*rng.uniform(.82,1.08)
  end=(256+side*reach,y-46-rng.uniform(3,30))
  draw.line([(255,y),end],fill=(35,54,34,255),width=3)
  for j in range(6):
   q=(j+1)/7; x=255+(end[0]-255)*q; yy=y+(end[1]-y)*q
   ink=rng.choice([(23,49,35,255),(34,62,41,255),(48,77,47,255),(57,86,53,255)])
   for direction in [-1,1]:
    tip=(x+side*rng.uniform(13,24),yy+direction*rng.uniform(16,29)-8)
    draw.polygon([(x-2,yy+2),(x+2,yy-2),tip],fill=ink)
png=source/'needles.png';image.save(png)
art=ROOT/'assets/materials/shared/needle_sprays.webp';image.save(art,'WEBP',quality=94,method=6)
record={'제작':'고정된 3D 곡면 가지에 쓰는 바늘잎. 카메라 빌보드가 아니다. 원본 수식에서 생성한 프로젝트 소유 알베도이며 법선/거칠기 맵이 아니다.','reference':'assets/source/style/approved-game-reference.jpg','reference_sha256':hashlib.sha256((ROOT/'assets/source/style/approved-game-reference.jpg').read_bytes()).hexdigest(),'seed':76451,'generator':str(Path(__file__).relative_to(ROOT)),'generator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'source':str(png.relative_to(ROOT)),'source_sha256':hashlib.sha256(png.read_bytes()).hexdigest(),'runtime':str(art.relative_to(ROOT)),'sha256':hashlib.sha256(art.read_bytes()).hexdigest(),'size':[512,512]}
(source/'needles.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
print('바늘잎 제작 완료',art.stat().st_size)
