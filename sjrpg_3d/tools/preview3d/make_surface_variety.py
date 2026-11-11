#!/usr/bin/env python3
"""집별 전용 문양과 자연물 표면을 고정 시드로 제작한다. 기존 이미지 편집 없이 수식에서 생성한다."""
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
    if kind in ['beast_fur','grave_bone','scar_skin']:
        patch=m.periodic_noise(SIZE,5,seed,4)
        if kind=='beast_fur':
            grain=m.periodic_noise(SIZE,64,seed,3,cells_y=4)
            return m.srgb('a5a9a0')[None,None,:]*(1+grain[:,:,None]*.30+patch[:,:,None]*.16)
        if kind=='grave_bone':
            pores=m.periodic_noise(SIZE,96,seed,2)<-.33
            return m.srgb('b7b19d')[None,None,:]*(1+patch[:,:,None]*.15)*np.where(pores,.68,1)[:,:,None]
        scars=np.abs(np.sin((x*5+y*2+patch*.6)*np.pi*2))<.045
        return m.srgb('9a9d85')[None,None,:]*(1+noise[:,:,None])*np.where(scars,.64,1)[:,:,None]
    if kind.startswith('door_'):
        palette={'door_shop':'635044','door_smith':'443c35','door_stable':'715b3c','door_home':'4d6060'}
        grain=m.periodic_noise(SIZE,48,seed,3,cells_y=3)*.15
        rgb=m.srgb(palette[kind])[None,None,:]*np.ones((SIZE,SIZE,1))*(1+grain[:,:,None])
        joints=np.minimum((x*6)%1,1-(x*6)%1)<.025
        # 실제 조각처럼 좁은 반복 홈과 중앙 마름모. 조명/철물은 메시가 담당한다.
        carving=np.abs(((x+y)*4)%1-.5)<.025
        carving|=np.abs(((x-y)*4)%1-.5)<.025
        rgb*=np.where(joints,.52,np.where(carving,.76,1))[:,:,None]
        return rgb
    if kind.startswith('roof_'):
        colors={'roof_shop':['7d5637','a2784c','91613c'], 'roof_smith':['333c42','4d5152','3e454c'], 'roof_home':['39585a','456866','587571']}
        return m.roof_tiles(SIZE,seed,[m.srgb(c) for c in colors[kind]],'20282a',lambda u:.91+.09*np.cos(u*np.pi*2),fine=noise,tone=.09)
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
    kinds=['door_shop','door_smith','door_stable','door_home','roof_shop','roof_smith','roof_home','rock_lichen','rock_iron','ground_heather','ground_moss','beast_fur','grave_bone','scar_skin']
    record={'제작':'원본 수식 기반 절차적 알베도. 집별 문양·조각과 자연물 변형. 법선/거칠기 맵은 만들지 않았다.','license':'Original project artwork','generator':str(Path(__file__).relative_to(ROOT)),'materials':{}}
    for i,kind in enumerate(kinds, start=4):
        if kind=='roof_smith':
            continue  # 대장간 지붕은 architecture/smith의 원화 기반 패키지가 소유한다.
        image=Image.fromarray(np.clip(make(kind,92137+i*31),0,255).astype('uint8'))
        source=SOURCE/(kind+'.png'); image.save(source)
        path=ART/(kind+'.webp'); image.save(path,'WEBP',quality=92,method=6)
        record['materials'][kind]={'path':str(path.relative_to(ROOT)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'source':str(source.relative_to(ROOT)),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'size':[SIZE,SIZE],'tile_m':(1.0/0.65 if kind.startswith('door_') else (0.5 if kind=='beast_fur' else (0.3 if kind in ['scar_skin','grave_bone'] else (2.6 if kind.startswith('roof_') else 2.56)))),'seed':92137+i*31}
        if kind=='rock_iron': record['materials'][kind]['actor_golem_tile_m']=0.6
    # 건물 패밀리 기록도 재현 실행 한 번으로 함께 갱신한다.
    m.refresh_dependents(json.loads(m.MANIFEST.read_text()))
    house_path=ROOT/'assets/source/preview3d/houses/provenance.json'
    house=json.loads(house_path.read_text())
    textures=house['materials']['textures']
    for key,entry in record['materials'].items():
        if key.startswith(('wall_','door_','roof_')):
            textures[:]=[v for v in textures if v['path']!=entry['path']]
            textures.append({'path':entry['path'],'sha256':entry['sha256']})
    house_path.write_text(json.dumps(house,ensure_ascii=False,indent=2)+'\n')
    record['generator_sha256']=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    record['geometry']={name:hashlib.sha256((ROOT/'scripts'/name).read_bytes()).hexdigest() for name in ['native_enemy_models.gd','native_house_3d.gd','native_landmarks_3d.gd','native_scenery_props_3d.gd']}
    (SOURCE/'provenance.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
    print('전용 표면 제작:',len(kinds))
if __name__=='__main__': main()
