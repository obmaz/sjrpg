"""Split independent generated quest destinations by measured alpha boundaries."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'docs/art/forest-quest-structures/generated-source.png'
im=Image.open(SOURCE).convert('RGBA')
alpha=np.array(im.getchannel('A'))
# Remove generator alpha1-3 noise outside the actual independent silhouettes.
clean=np.array(im);clean[:,:,3][alpha<=3]=0;im=Image.fromarray(clean,'RGBA')
alpha=np.array(im.getchannel('A'))
occupied=(alpha>16).any(axis=0)
spans=[]; start=None
for x,full in enumerate(occupied):
 if full and start is None: start=x
 if not full and start is not None: spans.append((start,x));start=None
if start is not None: spans.append((start,len(occupied)))
assert len(spans)==3, spans
cuts=[0,*[(spans[i][1]+spans[i+1][0])//2 for i in range(2)],im.width]
specs=[
 ('forest-quest-chapel','roots',[330,563],[260,595],[[170,477],[333,543],[498,469],[327,403]]),
 ('forest-quest-cottage','moon',[1026,570],[885,600],[[795,501],[1039,601],[1264,516],[1009,419]]),
 ('forest-quest-cave','sun',[1790,571],[1850,644],[[1470,455],[1807,601],[2090,493],[1771,360]])
]
items=[]
for i,(name,quest,ground,approach,solid) in enumerate(specs):
 sector=im.crop((cuts[i],0,cuts[i+1],im.height))
 b=Image.fromarray((np.array(sector.getchannel('A'))>4).astype('uint8')*255).getbbox(); assert b
 crop=[max(cuts[i],cuts[i]+b[0]-4),max(0,b[1]-4),min(cuts[i+1],cuts[i]+b[2]+4),min(im.height,b[3]+4)]
 result=im.crop(crop)
 path=ROOT/f'flutter_game/art/{name}.webp'
 result.save(path,quality=94,method=6)
 point=lambda p:[p[0]-crop[0],p[1]-crop[1]]
 items.append({'key':name,'quest':quest,'sourceRect':crop,'runtimeSize':list(result.size),'groundAnchor':point(ground),'frontApproach':point(approach),'solidFootprint':list(map(point,solid)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
metadata={'source':'generated-source.png','sourceSize':list(im.size),'sourceSha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'referenceConcept':'docs/art/forest-composition/','lighting':'Upper left, high southeast quarter view; tops/front/right sides visible','assets':items,'packing':'tools/prepare-forest-quest-structures.py; measured alpha>4 components with4px gutter; alpha1-3 generator noise cleared, native pixels, WebP quality94','anchors':'Ground anchor is the center of the illustrated ground-contact plinth. frontApproach marks a free place in front of the door/worksite for a separate NPC. solidFootprint outlines the structure body, excluding the apron and approach.'}
(ROOT/'docs/art/forest-quest-structures/provenance.json').write_text(json.dumps(metadata,indent=4)+'\n')
print(json.dumps(metadata))
