"""Pack the measured horizontal quarter-view bridge without changing its physics."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'docs/art/quarter-view-bridge/broad-deck-source.png'
OUTPUT=ROOT/'flutter_game/art/landscape-bridge.webp'
im=Image.open(SOURCE).convert('RGBA')
raw=np.array(im);raw[:,:,3][raw[:,:,3]<=3]=0
im=Image.fromarray(raw,'RGBA')
alpha=im.getchannel('A').getbbox()
# Complete bridge geometry and antialias fringe, not the guide's full canvas.
crop=(0,166,1536,838);padding=4
cut=im.crop(crop)
packed=Image.new('RGBA',(cut.width+padding*2,cut.height+padding*2),(0,0,0,0))
packed.paste(cut,(padding,padding));packed.save(OUTPUT,quality=94,method=6)
# Ground-plane reference band includes low parapet bases and ends immediately
# before the vertical front face. It has exactly the existing 660:176 aspect.
footprint=[104,83,1424,435]
wood=[136,111,1406,368]
metadata={
 'source':'broad-deck-source.png','sourceSize':list(im.size),
 'sourceSha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
 'layoutGuide':'deck-layout-guide.png','alphaNoiseThreshold':3,
 'alphaBounds':list(alpha),'crop':list(crop),'transparentPadding':padding,
 'runtime':'flutter_game/art/landscape-bridge.webp','runtimeSize':list(packed.size),
 'runtimeSha256':hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),
 'deckFootprint':footprint,'deckCenter':[764,259],
 'deckHorizontalSpan':1320,'deckDepth':352,'footprintAspect':3.75,
 'visibleWoodFloor':wood,
 'deckAxis':[[104,259],[1424,259]],
 'placement':'Uniform scale from logical bridge width/1320; measured deck center maps to logical bridge center. The1320x352 ground-plane band matches the unchanged660x176 collision rectangle exactly. Visible inner planks are narrower than the outer ground band because low parapets occupy its edges. Front arches extend beneath the band. No rotation or anisotropic scale.',
 'lighting':'Upper left; high quarter view with horizontal deck axis and visible front stone arches.',
 'legacySourcePreserved':'assets/landscape-bridge.webp',
 'earlierGeneratedReferences':['generated-source.png','horizontal-source.png'],
 'packing':'tools/prepare-quarter-view-bridge.py; alpha1-3 generator noise cleared, measured crop plus4px alpha margin, native pixels, WebP quality94'
}
(ROOT/'docs/art/quarter-view-bridge/provenance.json').write_text(json.dumps(metadata,indent=4)+'\n')
print(json.dumps(metadata))
