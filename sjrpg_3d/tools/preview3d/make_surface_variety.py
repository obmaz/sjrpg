#!/usr/bin/env python3
"""기존 자연물 표면을 고정 시드로 재현한다. 기존 이미지 편집 없이 수식에서 생성한다."""
import json, hashlib
from pathlib import Path
import numpy as np
from PIL import Image
import make_clean_masonry as m
ROOT = Path(__file__).resolve().parents[2]
ART = ROOT/'assets/art/preview3d'
SOURCE = ROOT/'assets/source/preview3d/surface-variety'
SIZE = 512

def make(kind, seed):
    y,x=np.mgrid[:SIZE,:SIZE].astype(float)/SIZE
    noise=m.periodic_noise(SIZE,8,seed)*.055+m.periodic_noise(SIZE,72,seed+1,3)*.025
    if kind.startswith('rock_'):
        base=m.rubble(SIZE)
        patch=m.periodic_noise(SIZE,4,seed,3)
        if kind=='rock_lichen':
            rgb=np.where((patch>.13)[:,:,None],m.srgb('797d51')*(1+noise[:,:,None]),base*np.array([.88,.96,.94]))
        else:
            vein=np.abs(np.sin((x*3+y*2+m.periodic_noise(SIZE,4,seed)*.35)*np.pi*2))<.10
            rgb=np.where(vein[:,:,None],m.srgb('a46c45'),base*np.array([.93,.83,.77]))
    else:
        patch=m.periodic_noise(SIZE,7,seed,4)
        colors=['3f4524','555332'] if kind=='ground_heather' else ['2d3d25','454831']
        amount=np.clip(patch*.8+.5,0,1)[:,:,None]
        rgb=m.srgb(colors[0])[None,None,:]*(1-amount)+m.srgb(colors[1])[None,None,:]*amount
        # 연속적인 토양색 변화와 작은 풀잎 결. 큰 단색 얼룩을 만들지 않는다.
        blades=np.sin((x*43+y*13)*np.pi*2+patch*5)*np.sin(y*89*np.pi*2)
        grain=m.periodic_noise(SIZE,96,seed+3,2)
        rgb*=np.array([.90,.88,.75])[None,None,:]*(1+grain[:,:,None]*.16+blades[:,:,None]*.07)
    return rgb

def main():
    SOURCE.mkdir(parents=True,exist_ok=True); (SOURCE/'.gdignore').touch()
    kinds=['rock_lichen','rock_iron','ground_heather','ground_moss']
    record={'제작':'원본 수식 기반 절차적 알베도. 자연물 변형. 법선/거칠기 맵은 만들지 않았다.','license':'Original project artwork','generator':str(Path(__file__).relative_to(ROOT)),'materials':{}}
    for i,kind in enumerate(kinds, start=11):
        image=Image.fromarray(np.clip(make(kind,92137+i*31),0,255).astype('uint8'))
        source=SOURCE/(kind+'.png'); image.save(source)
        path=ART/(kind+'.webp'); image.save(path,'WEBP',quality=92,method=6)
        record['materials'][kind]={'path':str(path.relative_to(ROOT)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'source':str(source.relative_to(ROOT)),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'size':[SIZE,SIZE],'tile_m':2.56,'seed':92137+i*31}
    record['generator_sha256']=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    record['geometry']={name:hashlib.sha256((ROOT/'scripts'/name).read_bytes()).hexdigest() for name in ['native_house_3d.gd','native_landmarks_3d.gd','native_scenery_props_3d.gd']}
    (SOURCE/'provenance.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
    print('전용 표면 제작:',len(kinds))
if __name__=='__main__': main()
