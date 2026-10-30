#!/usr/bin/env python3
"""Pack nine independently generated trees from measured transparent boundaries.

No drawing is resized. Source ROIs follow measured gaps in this exact generated
sheet; only the target atlas uses equal cells. Feet use lower brown root pixels.
"""
from pathlib import Path
import hashlib
import json
import math
import subprocess
from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'docs/art/forest-composition'
SOURCE = ART / 'tree-sheet.png'
OUTPUT = ROOT / 'flutter_game/art/forest-trees.webp'
ROWS = [(0, 441, [0, 358, 737, 1254]),
        (441, 863, [0, 369, 777, 1254]),
        (863, 1254, [0, 358, 762, 1254])]
SPECIES = ['oak', 'fir', 'willow']
AGES = ['sapling', 'mid', 'mature']
HEIGHTS = [140, 210, 280]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def build():
    source = Image.open(SOURCE).convert('RGBA')
    rgba = np.array(source)
    # Generated matte remnants (including invisible saturated fringe RGB) have
    # alpha1..8. Exclude those from both measured bounds and deployment pixels.
    rgba[rgba[:, :, 3] <= 8] = 0
    clean = Image.fromarray(rgba)
    frames = []
    crops = []
    for row, (top, bottom, columns) in enumerate(ROWS):
        for col in range(3):
            roi = (columns[col], top, columns[col + 1], bottom)
            alpha = clean.crop(roi).getchannel('A')
            bounds = alpha.getbbox()
            assert bounds, (row, col)
            bounds = (roi[0]+bounds[0], roi[1]+bounds[1],
                      roi[0]+bounds[2], roi[1]+bounds[3])
            src = (max(roi[0], bounds[0]-3), max(roi[1], bounds[1]-3),
                   min(roi[2], bounds[2]+3), min(roi[3], bounds[3]+3))
            crop = clean.crop(src)
            pixels = np.array(crop)
            # Root bark is brown, unlike the canopy and soft contact shadow.
            brown = ((pixels[:, :, 0].astype(float) > pixels[:, :, 1]*1.07)
                     & (pixels[:, :, 0].astype(float) > pixels[:, :, 2]*1.2)
                     & (pixels[:, :, 3] > 128))
            ys, xs = np.where(brown)
            assert len(xs)
            root_y = int(ys.max())
            root_x = int(np.median(xs[ys >= root_y-12]))
            crops.append(crop)
            frames.append({'id': row*3+col,
                           'species': SPECIES[row], 'age': AGES[col],
                           'worldHeight': HEIGHTS[col],
                           'sourceRoi': list(roi), 'sourceAlphaBounds': list(bounds),
                           'sourceRect': list(src),
                           'sourceFoot': [src[0]+root_x, src[1]+root_y]})
    cell = math.ceil(max(max(c.size) for c in crops)/16)*16+16
    atlas = Image.new('RGBA', (cell*3, cell*3))
    for frame, crop in zip(frames, crops):
        row, col = divmod(frame['id'], 3)
        x = col*cell+(cell-crop.width)//2
        y = row*cell+cell-crop.height-8
        atlas.paste(crop, (x, y))
        frame['rect'] = [x, y, crop.width, crop.height]
        foot_x, foot_y = frame['sourceFoot']
        frame['foot'] = [x+foot_x-frame['sourceRect'][0],
                         y+foot_y-frame['sourceRect'][1]]
        assert min(crop.width, crop.height) > 120
    OUTPUT.parent.mkdir(exist_ok=True)
    atlas.save(OUTPUT, lossless=True, method=6)
    metadata = {
        'source': str(SOURCE.relative_to(ROOT)),
        'output': str(OUTPUT.relative_to(ROOT)),
        'sourceSha256': sha(SOURCE), 'outputSha256': sha(OUTPUT),
        'atlasSize': list(atlas.size), 'cellSize': cell,
        'sourceSize': list(source.size),
        'alphaThreshold': 8,
        'packing': 'Native pixels, measured alpha bounds plus3px padding; no resize. Per-frame brown-root foot anchors.',
        'frames': frames,
        'composition': {
            'reference': 'docs/art/forest-composition/world-layout-reference.png',
            'overview': 'docs/art/forest-composition/stage-concept.png',
            'overviewSha256': sha(ART / 'stage-concept.png'),
            'initialOverview': 'docs/art/forest-composition/stage-concept-initial.png',
            'initialOverviewSha256': sha(ART / 'stage-concept-initial.png'),
            'worldLayoutSha256': sha(ART / 'world-layout-reference.png'),
            'rejectedUnpaddedSource': 'docs/art/forest-composition/tree-sheet-unpadded.png',
            'rejectedSourceSha256': sha(ART / 'tree-sheet-unpadded.png'),
            'rejectedReason': 'Mature oak touched the right canvas edge; padded re-generation is deployed.',
            'zones': {'oak': 'central mature groves',
                      'fir': 'remote northeast and southeast deep woods',
                      'willow': 'river and lake banks'},
            'heights': 'saplings on village/road edges, mid trees in grove transitions, mature trees in deep cores',
            'constraints': ['preserve actual water and road topology',
                            'keep quest clearing and combat approaches open',
                            'retain original trunk collision bodies']}}
    (ART/'tree-provenance.json').write_text(json.dumps(metadata, indent=2)+'\n')
    subprocess.run(['npx', 'prettier', '--write', str(ART/'tree-provenance.json')],
                   cwd=ROOT, check=True, stdout=subprocess.DEVNULL)
    # A compact review image of the deployed pixels, still with clear alpha.
    atlas.save(ART/'packed-preview.webp', quality=90)
    print(json.dumps({'size': atlas.size, 'bytes': OUTPUT.stat().st_size,
                      'frames': frames}, indent=2))

if __name__ == '__main__':
    build()
