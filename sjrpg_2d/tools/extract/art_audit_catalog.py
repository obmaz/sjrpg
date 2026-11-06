#!/usr/bin/env python3
"""Snapshot reviewed source/render hashes after measuring actual visible structural edges.
This is an explicit authoring step, never run automatically by tests or extraction.
"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main():
    manifest = json.loads(Path(__file__).with_name('art_axis_measure.json').read_text())
    for record in manifest['records']:
        for field in ['source', 'render']:
            record[field + '_sha256'] = hashlib.sha256((ROOT / record[field + '_file']).read_bytes()).hexdigest()
    target = ROOT / 'assets/data/art_axes.json'
    temporary = target.with_suffix('.tmp')
    temporary.write_text(json.dumps(manifest, indent=1) + '\n')
    temporary.replace(target)
    print(len(manifest['records']), 'reviewed rigid art families')


if __name__ == '__main__':
    main()
