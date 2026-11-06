"""Replace the mixed frontal/shadow-baked tree families with reviewed organic art.

Unlike rigid architecture, a tree has no straight ground-axis edges to warp into
place. Its crown, root footprint and elevated camera are authored in the image.
Original IDs, world heights, placement and collisions remain unchanged.
"""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def merge(data):
    art = json.loads((ROOT / 'assets/data/tree_art.json').read_text())
    for key, family in art['variants'].items():
        height = data['sprites'][key]['world_height']
        frame = copy.deepcopy(art['frames'][family])
        data['sprites'][key] = dict(sheet='forest-isometric-trees', **frame,
                                    world_height=height, body=None, gvs=1, gvk=0)
    return data
