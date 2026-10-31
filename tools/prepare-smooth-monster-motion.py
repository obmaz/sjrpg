"""Bake eight-bearing walk in-betweens and articulated attack clips offline.

Requires numpy, scipy, Pillow and opencv-python-headless. Uses the archived
transparent image_gen key poses; never blends images or computes flow in game.
"""
import hashlib
import importlib.util
import json
import math
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'flutter_game/art'
ARCHIVE = ROOT / 'docs/art/monster-motion'
spec = importlib.util.spec_from_file_location('native_motion', Path(__file__).with_name('prepare-monster-motion.py'))
native = importlib.util.module_from_spec(spec)
spec.loader.exec_module(native)
cv2.setNumThreads(1)
LOW = {'wolf', 'boar', 'basilisk', 'viper', 'bonehound', 'scorpion',
       'clockwork-spider', 'crystal-beetle'}
CASTERS = {'cultist', 'wraith', 'drone', 'cyber', 'gunner', 'cyber-core'}


def premultiply(tile, size, anchor):
    canvas = Image.new('RGBA', size)
    canvas.alpha_composite(tile, (anchor[0] - tile.width // 2, anchor[1] - tile.height))
    a = np.asarray(canvas).astype(np.float32) / 255
    a[:, :, :3] *= a[:, :, 3:4]
    return a


def flow_pair(a, b):
    # Silhouette and material both contribute, including dark creatures.
    def grey(im):
        rgb = (im[:, :, :3] * 255).astype(np.uint8)
        return cv2.addWeighted(cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY), .65,
                              (im[:, :, 3] * 255).astype(np.uint8), .35, 0)
    solver = cv2.DISOpticalFlow_create(cv2.DISOPTICAL_FLOW_PRESET_MEDIUM)
    return solver.calc(grey(a), grey(b), None), solver.calc(grey(b), grey(a), None)


def between(a, b, flows, t):
    if t <= 0: return a.copy()
    if t >= 1: return b.copy()
    yy, xx = np.mgrid[:a.shape[0], :a.shape[1]].astype(np.float32)
    f, back = flows
    first = cv2.remap(a, xx - f[:, :, 0] * t, yy - f[:, :, 1] * t,
                      cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT)
    last = cv2.remap(b, xx - back[:, :, 0] * (1-t), yy - back[:, :, 1] * (1-t),
                     cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT)
    return first * (1-t) + last * t


def attack_pose(im, kind, direction, t, anchor, height):
    # Keep the feet fixed. Localized head/torso/outer-limb motion gives distinct
    # anticipation, extension and recovery rather than scaling the whole body.
    bend = np.interp(t, [0, .28, .48, .65, 1], [0, -.45, 1, .6, 0])
    crouch = np.interp(t, [0, .28, .48, .65, 1], [0, .5, -.25, .1, 0])
    yy, xx = np.mgrid[:im.shape[0], :im.shape[1]].astype(np.float32)
    x = (xx-anchor[0])/height
    y = (anchor[1]-yy)/height
    upper = np.clip((y-.18)/.6, 0, 1)
    limb = np.exp(-((y-.47)/.24)**2) * np.clip(np.abs(x)*3, 0, 1)
    head = np.exp(-((y-.8)/.2)**2)
    angle = direction*math.pi/4 + math.pi/2
    dx, dy = math.cos(angle), math.sin(angle)*.55
    if kind in LOW:
        reach = head*.1 + limb*.045 + upper*.025
        drop = head*.035
    elif kind in CASTERS:
        reach = limb*.12 + upper*.025
        drop = -head*.025
    else:
        reach = limb*.16 + upper*.04 + head*.015
        drop = head*.015
    mx = xx - height*(dx*reach*bend + x*upper*crouch*.035)
    my = yy - height*(dy*reach*bend + drop*bend + upper*crouch*.035)
    return cv2.remap(im, mx.astype(np.float32), my.astype(np.float32),
                     cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT)


def tile_and_anchor(im, anchor):
    alpha = im[:, :, 3]
    ys, xs = np.nonzero(alpha > 1/255)
    x0, y0, x1, y1 = xs.min(), ys.min(), xs.max()+1, ys.max()+1
    crop = im[y0:y1, x0:x1].copy()
    crop[:, :, :3] /= np.maximum(crop[:, :, 3:4], 1/255)
    crop = np.clip(np.rint(crop*255), 0, 255).astype(np.uint8)
    crop[crop[:, :, 3] == 0] = 0
    return Image.fromarray(crop), (int(anchor[0]-x0), int(anchor[1]-y0))


def pack(tiles, anchors):
    width = 2048
    positions=[]; x=y=row=0
    for tile in tiles:
        if x+tile.width+8 > width: y+=row+8; x=0; row=0
        positions.append((x+4,y+4)); x+=tile.width+8; row=max(row,tile.height)
    atlas=Image.new('RGBA',(width,y+row+8)); frames=[]; feet=[]
    for tile,(x,y),(ax,ay) in zip(tiles,positions,anchors):
        atlas.alpha_composite(tile,(x,y));frames.append([x,y,tile.width,tile.height]);feet.append([x+ax,y+ay])
    return atlas,frames,feet


def process(item):
    key, relative = item
    kind = key[5:]
    source = ARCHIVE/relative
    image = Image.open(source).convert('RGBA')
    tiles, rects = native.separate(image,4,8,32)
    columns=list(range(8))
    if kind == 'cyber': columns[2],columns[6]=6,2
    reference=float(np.median([t.height for t in tiles]))
    ratio=min(1,(160 if kind == 'basilisk' else 176)/reference)
    for i,tile in enumerate(tiles):
        tiles[i]=tile.resize((round(tile.width*ratio),round(tile.height*ratio)),Image.Resampling.LANCZOS)
    reference*=ratio
    size=(max(t.width for t in tiles)+80,max(t.height for t in tiles)+64)
    anchor=(size[0]//2,size[1]-24)
    walks=[]; attacks=[]
    for d in range(8):
        poses=[premultiply(tiles[p*8+columns[(d+2)%8]],size,anchor) for p in range(4)]
        for p in range(4):
            walks.extend([poses[p],between(poses[p],poses[(p+1)%4],flow_pair(poses[p],poses[(p+1)%4]),.5)])
        # Use the same neutral image at either end, with a second genuine stance
        # driving the thrust. This avoids a different character on attack.
        flows=flow_pair(poses[0],poses[2])
        for p in range(8):
            t=p/7
            stance=np.interp(t,[0,.28,.48,.65,1],[0,.25,1,.65,0])
            posed=between(poses[0],poses[2],flows,float(stance))
            attacks.append(attack_pose(posed,kind,d,t,anchor,reference))
    cropped=[tile_and_anchor(im,anchor) for im in walks+attacks]
    atlas,frames,feet=pack([x[0] for x in cropped],[x[1] for x in cropped])
    name=f'actors-walk-{kind}'
    atlas.save(ART/f'{name}.webp',quality=93,method=5,exact=True)
    metadata={'frames':frames,'feet':feet,'sizes':[[atlas.width,reference/1.5]],
              'nativeBodyHeight':reference,'artworkWorldHeightMultiplier':1.5,
              'walk':{'directions':8,'frames':8,'layout':'direction-major'},
              'enemyAttack':{'directions':8,'frames':8,'offset':64,'layout':'direction-major'}}
    (ART/f'{name}-bounds.json').write_text(json.dumps(metadata,separators=(',',':'))+'\n')
    print(kind,atlas.size,flush=True)
    return kind,{'source':str(source.relative_to(ROOT)),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
                 'sourceRects':rects,'directionColumns':columns,'runtime':f'flutter_game/art/{name}.webp',
                 'walkFrames':64,'attackFrames':64,'nativeWalkKeys':32,'decodedRGBABytes':atlas.width*atlas.height*4,
                 'referenceHeight':reference,'profile':'low' if kind in LOW else 'caster' if kind in CASTERS else 'melee'}


def main():
    sources=json.loads((ARCHIVE/'sources.json').read_text())
    baseline_path=ARCHIVE/'provenance.json'
    baseline=json.loads(baseline_path.read_text())
    baseline['scope']='Original generated native key poses; the final expanded runtime is described by smooth-provenance.json'
    baseline_path.write_text(json.dumps(baseline,indent=4)+'\n')
    with ThreadPoolExecutor(max_workers=3) as pool:
        records=dict(pool.map(process,[(k,v) for k,v in sources.items() if k.startswith('walk-')]))
    (ARCHIVE/'smooth-provenance.json').write_text(json.dumps({
        'sourceGenerator':'image_gen','processor':'tools/prepare-smooth-monster-motion.py',
        'method':'offline bidirectional DIS optical-flow in-betweens; grounded species-profile articulated attack warps',
        'camera':'original eight upper-diagonal quarter-view bearings; no mirroring',
        'walkFramesPerDirection':8,'attackFramesPerDirection':8,'assets':records},indent=2)+'\n')

if __name__ == '__main__': main()
