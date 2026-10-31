"""Pack isolated generated cave components, measured from connected alpha pixels."""
import json
import hashlib
from pathlib import Path
import numpy as np
from scipy import ndimage
from PIL import Image
root=Path(__file__).resolve().parents[1]
source=root/'docs/art/dungeons/cave-entrances-original.png'
im=Image.open(source).convert('RGBA'); pixels=np.asarray(im)
labels,_=ndimage.label(pixels[:,:,3]>24)
parts=[]
for label,sl in enumerate(ndimage.find_objects(labels),1):
 if sl is None:continue
 y,x=sl
 if (y.stop-y.start)*(x.stop-x.start)>40000:
  parts.append((label,(x.start,y.start,x.stop,y.stop)))
parts.sort(key=lambda p:(0 if p[1][1]<100 else 1,p[1][0]))
assert len(parts)==6
atlas=Image.new('RGBA',(1536,1024)); metadata=[]
for i,(label,box) in enumerate(parts):
 x,y,r,b=box
 crop=np.array(im.crop(box)); crop[:,:,3]=np.where(labels[y:b,x:r]==label,crop[:,:,3],0)
 sprite=Image.fromarray(crop);sprite.thumbnail((472,472),Image.Resampling.LANCZOS)
 left=i%3*512+(512-sprite.width)//2;top=i//3*512+492-sprite.height
 atlas.alpha_composite(sprite,(left,top))
 metadata.append({'sourceBounds':list(map(int,box)),'packedBounds':[left,top,sprite.width,sprite.height]})
output=root/'flutter_game/art/cave-entrances.webp';atlas.save(output,lossless=True)
(root/'docs/art/dungeons/provenance.json').write_text(json.dumps({'generator':'OpenAI image_gen','prompt':'Five quarter-view wind, bat, ice, fire and crystal cave mouths plus a return arch; upper-left light, transparent isolated world objects.','sourceSha256':hashlib.sha256(source.read_bytes()).hexdigest(),'atlasSha256':hashlib.sha256(output.read_bytes()).hexdigest(),'components':metadata},indent=2)+'\n')
print(metadata)
rock_source=root/'docs/art/dungeons/cave-rock-original.png'
rock=Image.open(rock_source).convert('RGB')
rock_output=root/'flutter_game/art/cave-rock.webp'
rock.save(rock_output,quality=92,method=6)
(root/'docs/art/dungeons/rock-provenance.json').write_text(json.dumps({
 'generator':'OpenAI image_gen','source':'cave-rock-original.png',
 'sourceSha256':hashlib.sha256(rock_source.read_bytes()).hexdigest(),
 'outputSha256':hashlib.sha256(rock_output.read_bytes()).hexdigest(),
 'size':rock.size,
 'purpose':'Natural irregular upper-left-lit quarter-view cave wall rock; world-aligned repeated material, decoded on first instance preparation.'
},indent=2)+'\n')
