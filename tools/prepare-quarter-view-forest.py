"""Pack measured generated forest silhouettes; retain originals and native roots."""
from pathlib import Path
import hashlib
import json
import re
import numpy as np
from scipy import ndimage
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / 'docs/art/quarter-view-crossing'
ART = ROOT / 'flutter_game/art'

def clean(path):
    a = np.array(Image.open(path).convert('RGBA'))
    a[a[:, :, 3] <= 8] = 0
    return a

def silhouettes(path, count):
    a = clean(path)
    labels, _ = ndimage.label(a[:, :, 3] > 32)
    areas = np.bincount(labels.ravel())
    ids = np.argsort(areas[1:])[-count:] + 1
    ids = sorted(ids, key=lambda ident: ndimage.center_of_mass(labels == ident)[1])
    out = []
    for ident in ids:
        own = ndimage.binary_dilation(labels == ident, iterations=3)
        part = a.copy()
        part[~own] = 0
        ys, xs = np.nonzero(part[:, :, 3] > 8)
        box = [max(0, int(xs.min())-4), max(0, int(ys.min())-4),
               min(a.shape[1], int(xs.max())+5), min(a.shape[0], int(ys.max())+5)]
        out.append((Image.fromarray(part).crop(box), box))
    return out

frames = []
atlas = Image.new('RGBA', (1440, 1440))
for row, species in enumerate(['oak', 'fir', 'willow']):
    for col, (cut, box) in enumerate(silhouettes(DOC / f'{species}-original.png', 3)):
        a = np.array(cut)
        r, g, b = [a[:, :, i].astype(float) for i in range(3)]
        bark = (r > g*1.04) & (g > b*1.06) & (r > 55) & (a[:, :, 3] > 180)
        ys, xs = np.nonzero(bark & (np.indices(bark.shape)[0] > cut.height*.8))
        foot_y = int(ys.max())
        foot_x = float(np.median(xs[ys >= foot_y-5]))
        # Keep the root contact and a few pixels of its shadow, not an opaque island.
        cut = cut.crop((0, 0, cut.width, min(cut.height, foot_y+7)))
        factor = min(470/cut.width, 470/cut.height, 1)
        size = (round(cut.width*factor), round(cut.height*factor))
        resized = cut.resize(size, Image.Resampling.LANCZOS)
        x = col*480+(480-size[0])//2
        y = row*480+480-size[1]-5
        atlas.alpha_composite(resized, (x, y))
        foot = [x+foot_x*size[0]/cut.width, y+foot_y*size[1]/cut.height]
        frames.append(dict(species=species, age=col, sourceBox=box,
                           rect=[x, y, *size], foot=foot, height=[200,300,400][col]))
atlas.save(ART / 'forest-trees.webp', lossless=True, method=6, exact=True)
path = ROOT / 'flutter_game/lib/forest_tree_art.dart'
source = path.read_text()
lines = ['  static const frames = <ForestTreeFrame>[']
for f in frames:
    x,y,w,h = f['rect']; fx,fy = f['foot']
    lines.append(f'    ForestTreeFrame(ui.Rect.fromLTWH({x}, {y}, {w}, {h}), ui.Offset({fx:.4f}, {fy:.4f}), {f["height"]}),')
lines.append('  ];')
source = re.sub(r'  static const frames = <ForestTreeFrame>\[.*?\n  \];', '\n'.join(lines), source, flags=re.S)
path.write_text(source)
bridge = Image.fromarray(clean(DOC / 'bridge-original.png'))
bridge.save(ART / 'landscape-bridge.webp', quality=96, method=6, exact=True)
record = {'generator':'image_gen', 'reference':'docs/art/quarter-view-abbey/abbey-original.png',
          'processor':'tools/prepare-quarter-view-forest.py',
          'sources':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in DOC.glob('*-original.png')},
          'treeAtlas':[1440,1440], 'frames':frames, 'bridgeSize':list(bridge.size),
          'alphaNoiseThreshold':8, 'treePacking':'Measured connected silhouettes; independent native age variants, root contacts retained, downsample only.'}
(DOC / 'provenance.json').write_text(json.dumps(record,indent=4)+'\n')
print(json.dumps({'treeFrames':frames,'bridge':bridge.size}))

# The original four-prop sheet joins the broken chest and cactus. Use only its
# two independent left silhouettes, and independent re-generated right props.
parts = silhouettes(DOC / 'props-original.png', 3)
closed = min(parts, key=lambda p: abs(p[1][0]-35)+abs(p[1][1]-80))
rock = min(parts, key=lambda p: abs(p[1][0]-35)+abs(p[1][1]-720))
parts = [closed, silhouettes(DOC/'broken-chest-original.png',1)[0], rock,
         silhouettes(DOC/'cactus-original.png',1)[0], silhouettes(DOC/'palm-original.png',1)[0]]
props = Image.new('RGBA',(640,960)); prop_frames=[]
for i,(cut,box) in enumerate(parts):
    factor=min(296/cut.width,296/cut.height)
    size=(round(cut.width*factor),round(cut.height*factor))
    cut=cut.resize(size,Image.Resampling.LANCZOS)
    x=i%2*320+(320-size[0])//2; y=i//2*320+(320-size[1])//2
    props.alpha_composite(cut,(x,y))
    pixels=np.array(props.crop((i%2*320,i//2*320,i%2*320+320,i//2*320+320)))
    yy,xx=np.nonzero(pixels[:,:,3]>32)
    bottom=int(yy.max())+1; top=int(yy.min()); tip=float(np.mean(xx[yy>=bottom-(bottom-top)*.2]))
    prop_frames.append(dict(name=['chest','broken-chest','rock','cactus','palm'][i], sourceBox=box,
                            rect=[i%2*320,i//2*320,320,320],
                            foot=[i%2*320+tip,i//2*320+bottom],bodyHeight=bottom-top))
props.save(ART/'quarter-props.webp',quality=96,method=6,exact=True)
lines=["// Generated by tools/prepare-quarter-view-forest.py; measured opaque roots.","import 'dart:ui';",'', 'const naturalObjectFrames = [']
for f in prop_frames:
    x,y,w,h=f['rect'];fx,fy=f['foot']
    lines.append(f'  (source: Rect.fromLTWH({x},{y},{w},{h}), foot: Offset({fx:.8f},{fy}), height: {f["bodyHeight"]}.0),')
lines.append('];\n')
(ROOT/'flutter_game/lib/natural_object_frames.dart').write_text('\n'.join(lines))
# Paired milestones keep matching physical height between charged/dormant states.
beacon_parts=sorted(silhouettes(DOC/'beacons-original.png',8),key=lambda p:p[1][1])
beacon_parts=[p for i in range(0,8,2) for p in sorted(beacon_parts[i:i+2],key=lambda p:p[1][0])]
beacons=Image.new('RGBA',(512,1024)); beacon_frames=[]
for i,(cut,box) in enumerate(beacon_parts):
    factor=min(232/cut.width,232/cut.height)
    size=(round(cut.width*factor),round(cut.height*factor));cut=cut.resize(size,Image.Resampling.LANCZOS)
    x=i%2*256+(256-size[0])//2;y=i//2*256+(256-size[1])//2
    beacons.alpha_composite(cut,(x,y))
    a=np.array(beacons.crop((i%2*256,i//2*256,i%2*256+256,i//2*256+256)))
    yy,xx=np.nonzero(a[:,:,3]>32);bottom=int(yy.max())+1; top=int(yy.min())
    tip=float(np.mean(xx[yy>=bottom-4]))
    beacon_frames.append(dict(rect=[i%2*256,i//2*256,256,256],tip=[tip,bottom],height=bottom-top,sourceBox=box))
# Quantization must not move the measured alpha contact used by runtime/tests.
beacons.save(ART/'encounter-beacons.webp',lossless=True,method=6,exact=True)
path=ROOT/'flutter_game/lib/encounter_beacon_art.dart';source=path.read_text()
lines=['  static final _frames = <EncounterBeaconFrame>[']
for i,f in enumerate(beacon_frames):
    x,y,w,h=f['rect'];fx,fy=f['tip'];pair=beacon_frames[i//2*2:i//2*2+2]
    height=sum(p['height'] for p in pair)/2
    lines.append(f'    EncounterBeaconFrame(const ui.Rect.fromLTWH({x},{y},{w},{h}), const ui.Offset({fx:.8f},{fy}), {height}),')
lines.append('  ];')
source=re.sub(r'  static final _frames = <EncounterBeaconFrame>\[.*?\n  \];','\n'.join(lines),source,flags=re.S)
source=source.replace('-6 - tip.dy * 56 / bodyHeight','-tip.dy * 56 / bodyHeight')
source=source.replace("ready ? .85 : .55",'1')
source=source.replace('with the pointed body tip as the anchor','with the grounded plinth contact as the anchor')
source=source.replace('every non-solid encounter mark','every solid encounter milestone')
path.write_text(source)
gate=Image.fromarray(clean(DOC/'gateway-original.png'))
padded=Image.new('RGBA',(gate.width+8,gate.height+8));padded.alpha_composite(gate,(4,4))
padded.save(ART/'village-gateway.webp',quality=96,method=6,exact=True)
record.update(naturalObjects=prop_frames,beacons=beacon_frames,gatewaySize=list(padded.size),
              sources={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in DOC.glob('*-original.png')})
(DOC/'provenance.json').write_text(json.dumps(record,indent=4)+'\n')

# The arches are open at their lower edge. Trace that actual silhouette rather
# than treating the whole bridge face (including dry land under an arch) as solid.
import cv2
bridge_pixels=clean(DOC/'bridge-original.png')
yy,xx=np.indices(bridge_pixels.shape[:2])
front_y=722+(xx-445)*(-450/950)
structural=((bridge_pixels[:,:,3]>128)&np.where(xx<=445,yy>=710,yy>=front_y)).astype('uint8')*255
structural=cv2.morphologyEx(structural,cv2.MORPH_CLOSE,np.ones((3,3),np.uint8))
contours,_=cv2.findContours(structural,cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_SIMPLE)
polygons=[]
for contour in contours:
    if cv2.contourArea(contour)<800:continue
    polygon=cv2.approxPolyDP(contour,4,True)[:,0,:].tolist()
    polygons.append(polygon)
# Depth follows the foundations' ground line through each arch, not the elevated
# deck. For the solid near abutment use the measured lower silhouette itself.
strip_width=48
front_depth=[]
for x in range(0,1536,strip_width):
    ys=np.nonzero(structural[:,x:x+strip_width])[0]
    measured=float(ys.max()) if len(ys) else 0
    plane=980+(x-590)*(-450/880) if x+strip_width>445 else 0
    front_depth.append(min(1024,max(measured,plane)))
lines=["// Generated from the bridge's opaque structural silhouette, not its image box.","import 'dart:ui';",'', 'const bridgeFrontPolygons = <List<Offset>>[']
for polygon in polygons:
    lines.append('  ['+', '.join(f'Offset({x},{y})' for x,y in polygon)+'],')
lines+= ['];','', 'const bridgeFrontDepths = <double>[', ', '.join(f'{y:.4f}' for y in front_depth),'];','']
(ROOT/'flutter_game/lib/bridge_collision_frames.dart').write_text('\n'.join(lines))
record['bridgeStructure']={'alphaThreshold':128,'contourSimplificationPixels':4,'polygons':polygons,'stripWidth':strip_width,'frontDepth':front_depth}
(DOC/'provenance.json').write_text(json.dumps(record,indent=4)+'\n')
print(json.dumps({'bridgeContours':[len(p) for p in polygons]}))
