"""Measure isolated generated walking poses and quarter-view ground corpses."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import math
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.optimize import linear_sum_assignment

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = ROOT / 'docs/art/monster-motion'
ART = ROOT / 'flutter_game/art'
KINDS = ['goblin','wolf','skeleton','cultist','troll','golem','scorpion','mummy',
         'boar','basilisk','wraith','drone','viper','bonehound','clockwork-spider',
         'crystal-beetle','cyber','gunner','sand-warden','ancient-king','cyber-core']
CORPSES = {'forest':['goblin','wolf','skeleton','cultist','troll','boar'],
           'wilds':['scorpion','mummy','basilisk','wraith','viper','bonehound'],
           'machines':['drone','clockwork-spider','crystal-beetle','cyber','gunner']}


def separate(image, rows, columns, count):
    rgba=np.asarray(image.convert('RGBA')); alpha=rgba[:,:,3]
    if alpha.min()!=0: raise ValueError('Expected genuine transparency')
    labels,_=ndimage.label(alpha>96)
    areas=np.bincount(labels.ravel())
    ids=np.argsort(areas[1:])[-count:][::-1]+1
    if len(ids)!=count or min(areas[ids])<900:
        raise ValueError(f'Incomplete or touching silhouettes: {sorted(areas[1:],reverse=True)[:count+1]}')
    centers=np.asarray(ndimage.center_of_mass(alpha>96,labels,ids))
    expected=np.array([[(r+.5)*image.height/rows,(c+.5)*image.width/columns]
                       for r in range(rows) for c in range(columns)][:count])
    cost=((expected[:,None,:]-centers[None,:,:])**2).sum(axis=2)
    r,c=linear_sum_assignment(cost); ordered=ids[c[np.argsort(r)]]
    if np.sqrt(cost[r,c]).max()>max(image.width/columns,image.height/rows)*.6:
        raise ValueError('Cannot identify source arrangement reliably')
    nearest=ndimage.distance_transform_edt(~np.isin(labels,ids),return_distances=False,return_indices=True)
    owners=labels[nearest[0],nearest[1]]
    tiles=[]; rects=[]
    for ident in ordered:
        mask=(owners==ident)&(alpha>0); ys,xs=np.nonzero(mask&(alpha>96))
        box=(int(xs.min()),int(ys.min()),int(xs.max())+1,int(ys.max())+1)
        x0,y0,x1,y1=box; pixels=rgba[y0:y1,x0:x1].copy()
        pixels[~mask[y0:y1,x0:x1]]=0
        tiles.append(Image.fromarray(pixels)); rects.append(box)
    return tiles,rects


def pack(tiles, width=1024):
    places=[]; x=y=row=0
    for tile in tiles:
        if x+tile.width+8>width: y+=row+8;x=0;row=0
        places.append((x+4,y+4));x+=tile.width+8;row=max(row,tile.height)
    height=2**math.ceil(math.log2(y+row+8))
    atlas=Image.new('RGBA',(width,height));frames=[];feet=[]
    for tile,(x,y) in zip(tiles,places):
        atlas.alpha_composite(tile,(x,y)); a=np.asarray(tile)[:,:,3]
        ys,xs=np.nonzero(a[max(0,tile.height-8):,:]>96)
        # Use silhouette center rather than the leading foot. Alternating feet
        # must not move the whole body sideways between contact poses.
        feet.append([x+tile.width/2,y+tile.height])
        frames.append([x,y,tile.width,tile.height])
    return atlas,frames,feet


def main():
    sources=json.loads((ARCHIVE/'sources.json').read_text());records={}
    corpse_tiles=[];corpse_kinds=[]
    def process(item):
        key,relative=item
        source=ARCHIVE/relative;image=Image.open(source).convert('RGBA')
        record={'source':str(source.relative_to(ROOT)), 'sha256':hashlib.sha256(source.read_bytes()).hexdigest()}
        if key.startswith('walk-'):
            kind=key[5:];tiles,rects=separate(image,4,8,32)
            # Some generated sheets swapped the forward/backward axial views;
            # identify these from the original and record the explicit mapping.
            directions=list(range(8))
            if kind in ['cyber']: directions[2],directions[6]=6,2
            indices=[p*8+directions[(d+2)%8] for d in range(8) for p in range(4)]
            tiles=[tiles[i] for i in indices]
            atlas,frames,feet=pack(tiles)
            reference=float(np.median([t.height for t in tiles]))
            name=f'actors-walk-{kind}'
            atlas.save(ART/f'{name}.webp',quality=94,method=4,exact=True)
            meta={'frames':frames,'feet':feet,'sizes':[[atlas.width,reference/1.5]],
                  'nativeBodyHeight':reference,'artworkWorldHeightMultiplier':1.5,'walk':{'directions':8,'frames':4,'layout':'direction-major'}}
            (ART/f'{name}-bounds.json').write_text(json.dumps(meta,separators=(',',':'))+'\n')
            record.update(sourceRects=rects,sourceDirectionColumns=directions,runtime=f'flutter_game/art/{name}.webp',
                          decodedRGBABytes=atlas.width*atlas.height*4,frameCount=32,nativeSamples=True)
        else:
            family=key[7:]; kinds=CORPSES[family]; tiles,rects=separate(image,2,3,len(kinds))
            for tile in tiles:
                tile.thumbnail((288,176),Image.Resampling.LANCZOS)
                corpse_tiles.append(tile)
            corpse_kinds.extend(kinds);record.update(sourceRects=rects,kinds=kinds)
        records[key]=record
        print(key, 'measured',flush=True)
    for item in sources.items():
        if item[0].startswith('corpse-'): process(item)
    with ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(process, [item for item in sources.items() if item[0].startswith('walk-')]))
    records={key:records[key] for key in sources}
    atlas,frames,_=pack(corpse_tiles)
    atlas.save(ART/'monster-corpses.webp',quality=94,method=4,exact=True)
    # Center each lying body at its own ground footprint, preserving its aspect.
    metadata={'kinds':corpse_kinds,'frames':frames,'atlasSize':list(atlas.size)}
    (ART/'monster-corpses-bounds.json').write_text(json.dumps(metadata,separators=(',',':'))+'\n')
    (ARCHIVE/'provenance.json').write_text(json.dumps({'generator':'image_gen','camera':'upper diagonal quarter-view, upper-left light',
       'packer':'tools/prepare-monster-motion.py','walkDirections':8,'posesPerDirection':4,
       'corpseAtlas':{'kinds':corpse_kinds,'decodedRGBABytes':atlas.width*atlas.height*4},'assets':records},indent=2)+'\n')

if __name__=='__main__':main()
