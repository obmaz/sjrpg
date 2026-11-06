"""Use the reviewed cave-kit entrance while preserving its original world height.

The field entrance keeps its world anchor, interaction approach and collision.
Only its illustration and measured ground contact come from the new cave kit.
"""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def merge(data):
    art = json.loads((ROOT / 'assets/data/cave_art.json').read_text())
    height = data['sprites']['cave']['world_height']
    data['sprites']['cave'] = copy.deepcopy(art['frames']['entrance'])
    data['sprites']['cave']['world_height'] = height
    return data
