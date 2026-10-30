"""Measure isolated generated silhouettes and pack four landmarks per stage."""

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
SOURCES = {
    'forest': 'exec-03b7a8f4-ddca-4570-991e-d2424ec14155.png',
    'sands': 'exec-f9db3d69-e1a1-4a3e-879b-f414ed30bd38.png',
    'past': 'exec-8459bf0c-a2ed-4a68-a3aa-0b1b01775f04.png',
    'future': 'exec-82ee4d76-bd04-47a8-83a9-6e1b7f5832f1.png',
    'tombs': 'exec-492e4dcd-6141-41cb-b9c1-48aa730af483.png',
    'foundry': 'exec-f613fbea-bd74-4ed7-8082-e8485dbc7385.png',
    'convergence': 'exec-fa287836-2dcf-40f4-93c3-72ca0975ac56.png',
}
CELL = 768
PADDING = 32


def main():
    stages = {}
    for stage, generation in SOURCES.items():
        source = ROOT / f'docs/art/field-landmarks/{stage}-original.png'
        with Image.open(source) as image:
            rgba = np.array(image.convert('RGBA'))
        alpha = rgba[:, :, 3]
        labels, _ = ndimage.label(alpha > 16)
        areas = np.bincount(labels.ravel())
        areas[0] = 0
        primary = np.argsort(areas)[-4:].tolist()
        if min(areas[primary]) < 20000:
            raise ValueError(f'{stage}: four separated major silhouettes required')
        centers = {i: ndimage.center_of_mass(alpha, labels, i) for i in primary}
        by_row = sorted(primary, key=lambda i: centers[i][0])
        order = sorted(by_row[:2], key=lambda i: centers[i][1]) + sorted(
            by_row[2:], key=lambda i: centers[i][1])
        # Associate disconnected small stones/glow with the nearest measured
        # silhouette. This never assumes quadrant boundaries are crop lines.
        main_mask = np.isin(labels, primary)
        _, nearest = ndimage.distance_transform_edt(~main_mask, return_indices=True)
        owners = labels[tuple(nearest)]
        atlas = Image.new('RGBA', (CELL * 2, CELL * 2))
        frames = []
        for index, label in enumerate(order):
            isolated = rgba.copy()
            isolated[owners != label] = 0
            mask = isolated[:, :, 3] > 2
            yy, xx = np.where(mask)
            bounds = (int(xx.min()), int(yy.min()), int(xx.max()) + 1, int(yy.max()) + 1)
            if bounds[0] == 0 or bounds[1] == 0 or bounds[2] == rgba.shape[1] or bounds[3] == rgba.shape[0]:
                raise ValueError(f'{stage}/{index}: source silhouette touches edge')
            crop = Image.fromarray(isolated).crop(bounds)
            crop.thumbnail((CELL - PADDING * 2, CELL - PADDING * 2), Image.Resampling.LANCZOS)
            position = (index % 2 * CELL + (CELL - crop.width) // 2,
                        index // 2 * CELL + CELL - PADDING - crop.height)
            atlas.alpha_composite(crop, position)
            frames.append({'index': index, 'sourceRect': list(bounds),
                           'packedRect': [*position, crop.width, crop.height]})
        output = ROOT / f'flutter_game/art/landmarks-{stage}.webp'
        atlas.save(output, lossless=True, method=6, exact=True)
        stages[stage] = {'generation': generation, 'source': str(source.relative_to(ROOT)),
                         'sourceSha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                         'runtime': str(output.relative_to(ROOT)),
                         'runtimeSha256': hashlib.sha256(output.read_bytes()).hexdigest(),
                         'frames': frames}
    manifest = {'generator': 'image_gen', 'packer': 'tools/prepare-field-landmarks.py',
                'camera': 'elevated diagonal quarter view; upper-left light',
                'imageSize': [CELL * 2, CELL * 2], 'columns': 2, 'rows': 2,
                'padding': PADDING, 'decodedBytesPerStage': CELL * CELL * 16,
                'stages': stages}
    (ROOT / 'docs/art/field-landmarks/provenance.json').write_text(
        json.dumps(manifest, ensure_ascii=False, indent=4) + '\n')


if __name__ == '__main__':
    main()
