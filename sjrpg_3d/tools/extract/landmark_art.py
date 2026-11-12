#!/usr/bin/env python3
"""Measured revised hill/garden art; natural tree and waterfall tiles retain their original geometry."""
import json
from pathlib import Path
import numpy as np
from PIL import Image
import chapel

ROOT=Path(__file__).resolve().parents[2]
M=json.loads(Path(__file__).with_name('landmark_art_measure.json').read_text())


def derive(config):
    F,L,R=map(lambda k:np.array(config[k],float),['F','L','R']);B=L+R-F
    t1,t2=config['stair_t'];a=F+(L-F)*t2;b=F+(L-F)*t1;travel=np.array(config['travel']);bottom_a=a+travel;bottom_b=b+travel;down=np.array([0,config['height']])
    foot=F+down;foot_l=L+down
    ia=chapel._intersect(a,travel,foot,foot_l-foot);ib=chapel._intersect(b,travel,foot,foot_l-foot)
    outline=[bottom_a,bottom_b,b,F,R,B,L,a]
    faces=[[F,R,R+down,F+down],[L,a,ia,L+down],[F,b,ib,F+down]]
    scale=768/Image.open(ROOT/config['png']).width
    def packed(points):return [[round(float(z)*scale,3) for z in p] for p in points]
    result = dict(outline=packed(outline),entrance=0,faces=[packed(p) for p in faces],solids=[packed(p) for p in config['solids']],water=[],gvs=config['gvs'],gvk=config['gvk'])
    for key in ['warp','native_size']:
        if key in config:result[key]=config[key]
    return result


def merge(records):
    for index,config in M.items():records[int(index)]=derive(config)
    return records


def pack():
    sources=[M['0']['png'],M['1']['png'],'assets/source/vegetation/concepts/landmark-tree.png','assets/source/environment/landmarks/landmark-waterfall.png'];sheet=Image.new('RGBA',(1536,1536),(0,0,0,0))
    for i,path in enumerate(sources):
        image=Image.open(ROOT/path).convert('RGBA').convert('RGBa').resize((768,768),Image.Resampling.LANCZOS).convert('RGBA');sheet.paste(Image.fromarray(chapel._bleed(np.array(image))),((i%2)*768,(i//2)*768))
    target=ROOT/'assets/sprites/village/landmarks.webp';temporary=target.with_suffix('.tmp')
    sheet.save(temporary,'WEBP',quality=94,alpha_quality=100,method=6,exact=True);temporary.replace(target)


if __name__=='__main__':
    import sys
    if '--data' not in sys.argv:pack()
    path=ROOT/'assets/data/landmarks.json';path.write_text(json.dumps(merge(json.loads(path.read_text())),indent=1)+'\n')
    print('landmark art packed/merged')
