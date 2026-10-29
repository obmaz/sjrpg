"""Measure newly generated combat sprites; preserve native actor samples."""
import argparse
import hashlib
import json
import math
import shutil
from pathlib import Path
from PIL import Image
import numpy as np
from scipy import ndimage
from scipy.optimize import linear_sum_assignment

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'flutter_game/art'
ARCHIVE = ROOT / 'docs/art/cinematic'

def bounds(image, region):
    crop = image.crop(region)
    box = crop.getchannel('A').point(lambda a: 255 if a > 96 else 0).getbbox()
    if box is None:
        raise ValueError(f'Empty sprite: {region}')
    return (region[0]+box[0], region[1]+box[1], region[0]+box[2], region[1]+box[3])

def save(image, name):
    image.save(ART / f'{name}.webp', lossless=True, exact=True, method=6)

def actor(image, name):
    # Assign complete silhouettes by connected alpha components rather than
    # cutting at grid lines: weapons and tails can extend into the next cell.
    rgba = np.asarray(image.convert('RGBA'))
    alpha = rgba[:, :, 3]
    labels, _ = ndimage.label(alpha > 96)
    areas = np.bincount(labels.ravel())
    if len(areas) < 17:
        raise ValueError(f'{name}: fewer than sixteen separated sprites')
    ids = np.argsort(areas[1:])[-16:][::-1] + 1
    if min(areas[ids]) < 1000:
        raise ValueError(f'{name}: sprites touch or are incomplete')
    centers = np.asarray(ndimage.center_of_mass(alpha > 96, labels, ids))
    expected = np.array([[(r + .5) * image.height / 4, (c + .5) * image.width / 4]
                         for r in range(4) for c in range(4)])
    cost = ((expected[:, None, :] - centers[None, :, :]) ** 2).sum(axis=2)
    rows, cols = linear_sum_assignment(cost)
    if np.sqrt(cost[rows, cols]).max() > min(image.size) / 7:
        raise ValueError(f'{name}: sprite layout cannot be identified reliably')
    ordered_ids = ids[cols[np.argsort(rows)]]
    cores = np.isin(labels, ids)
    nearest = ndimage.distance_transform_edt(~cores, return_distances=False, return_indices=True)
    owners = labels[nearest[0], nearest[1]]
    source_tiles = []
    rects = []
    for ident in ordered_ids:
        mask = (owners == ident) & (alpha > 0)
        opaque = mask & (alpha > 96)
        ys, xs = np.nonzero(opaque)
        box = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
        x0, y0, x1, y1 = box
        pixels = rgba[y0:y1, x0:x1].copy()
        pixels[~mask[y0:y1, x0:x1]] = 0
        source_tiles.append(Image.fromarray(pixels, 'RGBA'))
        rects.append(box)
    # Runtime bearings begin at south. The generated sequence begins at east.
    indices = [((d + 2) % 8) * 2 + p for d in range(8) for p in range(2)]
    tiles = [source_tiles[i] for i in indices]
    heights = sorted(b[3]-b[1] for b in rects)
    reference = (heights[7]+heights[8])/2
    width = 2048 if max(t.width for t in tiles) > 400 else 1024
    placements=[]; x=y=row_height=0
    for tile in tiles:
        if x+tile.width+8 > width:
            y += row_height+8; x=0; row_height=0
        placements.append((x+4,y+4)); x += tile.width+8
        row_height=max(row_height,tile.height)
    height=2**math.ceil(math.log2(y+row_height+8))
    atlas=Image.new('RGBA',(width,height))
    frames=[]; feet=[]
    for tile, (x,y) in zip(tiles,placements):
        atlas.alpha_composite(tile,(x,y))
        alpha=tile.getchannel('A')
        # Ground anchor is measured from the lowest opaque contact pixels.
        contacts=[px for py in range(max(0,tile.height-8),tile.height)
                  for px in range(tile.width) if alpha.getpixel((px,py))>96]
        foot_x=sum(contacts)/len(contacts) if contacts else tile.width/2
        frames.append([x,y,tile.width,tile.height])
        feet.append([x+foot_x,y+tile.height])
    key=f'actors-cinematic-{name}'
    save(atlas,key)
    record={'frames':frames,'feet':feet,'sizes':[[width,reference/1.5]],
            'nativeBodyHeight':reference,'artworkWorldHeightMultiplier':1.5}
    (ART/f'{key}-bounds.json').write_text(json.dumps(record,separators=(',',':'))+'\n')
    return {'sourceRects':rects,'runtime':f'flutter_game/art/{key}.webp',
            'nativeBodyHeight':reference,'decodedRGBABytes':width*height*4,
            'separatedAlphaComponents':True}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest',type=Path,default=ARCHIVE/'sources.json')
    args=parser.parse_args()
    ARCHIVE.mkdir(parents=True,exist_ok=True)
    records={}
    for name,source in json.loads(args.manifest.read_text()).items():
        source=args.manifest.parent/source
        original=ARCHIVE/f'{name}-original.png'
        if Path(source).resolve()!=original.resolve():
            shutil.copyfile(source,original)
        image=Image.open(original).convert('RGBA')
        if image.getchannel('A').getextrema()[0]!=0:
            raise ValueError(f'{name} needs genuine transparency')
        if name=='ui':
            atlas=Image.new('RGBA',(1024,768)); rects=[]
            for r,(top,bottom) in enumerate([(112,444),(444,764),(764,1104)]):
                for c in range(4):
                    box=bounds(image,(c*image.width//4,top,(c+1)*image.width//4,bottom))
                    tile=image.crop(box)
                    tile.thumbnail((244,244),Image.Resampling.LANCZOS)
                    atlas.alpha_composite(tile,(c*256+(256-tile.width)//2,r*256+(256-tile.height)//2))
                    rects.append(box)
            save(atlas,'cinematic-interface'); record={'sourceRects':rects}
        elif name=='vfx':
            atlas=Image.new('RGBA',(1536,1536)); rects=[]
            for r in range(4):
                for c in range(4):
                    region=(c*image.width//4,r*image.height//4,(c+1)*image.width//4,(r+1)*image.height//4)
                    box=bounds(image,region); tile=image.crop(box)
                    tile.thumbnail((352,352),Image.Resampling.LANCZOS)
                    atlas.alpha_composite(tile,(c*384+(384-tile.width)//2,r*384+(384-tile.height)//2))
                    rects.append(box)
            save(atlas,'combat-illustrations'); record={'sourceRects':rects}
        else:
            record=actor(image,name)
        record.update({'source':str(original.relative_to(ROOT)),
                       'sha256':hashlib.sha256(original.read_bytes()).hexdigest()})
        records[name]=record
    (ARCHIVE/'provenance.json').write_text(json.dumps({'generator':'image_gen',
        'packer':'tools/prepare-cinematic-art.py','assets':records},indent=4)+'\n')

if __name__=='__main__':
    main()
