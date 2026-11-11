"""Generate the village's clean wall and roof base-color family.

User direction (2026-11-09): the village wall, chapel and shops looked dated;
make them clean and current like the attached chapel reference. Follow-up the
same day: one wall tile and one roof tile everywhere looked monotonous, so mix
several tiles, include a timber house and give each building its own material
character. Every tile is deterministic (fixed seeds) so the exact pixels can be
rebuilt and reviewed.

Walls (world-space triplanar, square tile = ``tile_m`` metres):
* limestone  2.56m, 8x0.32m courses, sawn ashlar 0.40-0.80m. Fortification and
             the shared trim (plinths, quoins, sills, arches).
* chapel     2.56m, 8 courses, long pale ivory ashlar 0.70-1.20m.
* brick      2.56m, 32 courses x 10 red-brown bricks, light lime mortar.
* rubble     2.56m, irregular fieldstone with recessed mortar (smithy).
* plaster    2.56m, warm lime plaster for the half-timbered shop.
* planks     2.56m, 12 horizontal weatherboards with butt joints (timber house).

Roofs (geometry UV, 2.6m tile, 8 courses x 6 columns): even course bands from
the eave (UV v=0 at the image top) have joints at u=k/6 and odd bands at
(k+0.5)/6, matching NativeHouse3D._roof's real tiles.
* slate      dark blue-grey slate.
* clay       terracotta barrel tiles (rounded profile inside each column).
* shingle    weathered split cedar; each column holds two narrower shingles.

Albedo only: uniform diffuse light, no cast shadow or one-sided highlight.
Edge tone changes are intrinsic (arris wear, tile thickness, board overlap).
No normal or roughness map is produced.

    python3 tools/preview3d/make_clean_masonry.py
"""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "assets/source/preview3d/town-clean-masonry"
ART_DIR = ROOT / "assets/art/preview3d"
MANIFEST = ART_DIR / "materials.json"
SOURCE_SIZE = 1536  # rendered at 2x then downsampled for clean anti-aliased joints
RUNTIME_SIZE = 768
WEBP_QUALITY = 94


def srgb(hex_color):
    return np.array([int(hex_color[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


def periodic_noise(size, cells, seed, octaves=4, cells_y=None):
    """Tileable value noise in [-1, 1]; ``cells_y`` stretches it for wood grain."""
    rng = np.random.default_rng(seed)
    total = np.zeros((size, size), dtype=np.float32)
    amplitude, weight = 1.0, 0.0
    cells_y = cells if cells_y is None else cells_y
    for octave in range(octaves):
        nx, ny = cells * (2 ** octave), cells_y * (2 ** octave)
        lattice = rng.uniform(-1.0, 1.0, (ny, nx)).astype(np.float32)

        def axis(n):
            coord = np.arange(size, dtype=np.float32) * n / size
            i0 = np.floor(coord).astype(int) % n
            f = coord - np.floor(coord)
            return i0, (i0 + 1) % n, f * f * (3 - 2 * f)
        x0, x1, fx = axis(nx)
        y0, y1, fy = axis(ny)
        top = lattice[y0][:, x0] * (1 - fx)[None, :] + lattice[y0][:, x1] * fx[None, :]
        bottom = lattice[y1][:, x0] * (1 - fx)[None, :] + lattice[y1][:, x1] * fx[None, :]
        total += (top * (1 - fy)[:, None] + bottom * fy[:, None]) * amplitude
        weight += amplitude
        amplitude *= 0.5
    return total / weight


def blend(color, joint_color, amount):
    amount = np.clip(amount, 0.0, 1.0)[..., None]
    return color * (1 - amount) + joint_color * amount


def coursed(size, seed, tile_m, courses, width_range, palette, mortar_m, mortar_hex, grain, rim_m=0.015, tone=0.055):
    """Running-bond blocks (ashlar or brick) on a periodic tile."""
    rng = np.random.default_rng(seed)
    course_px = size / courses
    px_per_m = size / tile_m
    mortar = mortar_m * px_per_m
    stone_id = np.zeros((size, size), dtype=np.int32)
    dist = np.zeros((size, size), dtype=np.float32)
    tones = []
    xs = np.arange(size, dtype=np.float32) + 0.5
    low, high = width_range
    for course in range(courses):
        widths, remaining = [], tile_m
        while remaining > high:
            w = float(rng.uniform(low, high))
            if remaining - w < low:
                w = remaining - low
            widths.append(w)
            remaining -= w
        widths.append(remaining)
        y0, y1 = round(course * course_px), round((course + 1) * course_px)
        local_y = np.arange(y0, y1, dtype=np.float32) - y0 + 0.5
        start = rng.uniform(0, tile_m)
        for w in widths:
            tones.append((rng.normal(0.0, 1.0), rng.integers(len(palette))))
            left = start * px_per_m
            span = w * px_per_m
            lx = (xs - left) % size
            cols = np.nonzero(lx < span)[0]
            x = lx[cols][None, :]
            y = local_y[:, None]
            stone_id[y0:y1, cols] = len(tones) - 1
            dist[y0:y1, cols] = np.minimum(np.minimum(x, span - x), np.minimum(y, (y1 - y0) - y))
            start += w
    tone_value = np.array([t for t, _ in tones], dtype=np.float32)[stone_id]
    base = np.stack(palette)[np.array([p for _, p in tones])[stone_id]]
    color = base * (1.0 + tone * np.clip(tone_value, -2, 2))[..., None]
    color *= (1.0 + grain)[..., None]
    edge = np.clip(1.0 - (dist - mortar * 0.5) / (rim_m * px_per_m), 0.0, 1.0)
    color *= (1.0 - 0.07 * edge ** 2)[..., None]
    mortar_color = srgb(mortar_hex) * (1.0 + periodic_noise(size, 40, seed + 9, 2) * 0.05)[..., None]
    return blend(color, mortar_color, (mortar * 0.5 + 0.75 - dist) / 1.5)


def limestone(size):
    grain = periodic_noise(size, 6, 7) * 0.045 + periodic_noise(size, 48, 8, 3) * 0.03
    palette = [srgb("988e80"), srgb("9e9180"), srgb("928c84"), srgb("a0937f"), srgb("8f8a82")]
    return coursed(size, 20261109, 2.56, 8, (0.40, 0.80), palette, 0.0115, "625d55", grain)


def chapel(size):
    grain = periodic_noise(size, 5, 17) * 0.035 + periodic_noise(size, 64, 18, 3) * 0.02
    palette = [srgb("b4ada0"), srgb("bab2a2"), srgb("aea9a0"), srgb("b8b0a4")]
    return coursed(size, 20261111, 2.56, 8, (0.70, 1.20), palette, 0.008, "7e786f", grain, rim_m=0.012, tone=0.035)


def brick(size):
    grain = periodic_noise(size, 10, 27) * 0.05 + periodic_noise(size, 96, 28, 2) * 0.05
    palette = [srgb("8a4a36"), srgb("9a5540"), srgb("7d4433"), srgb("a0644a"), srgb("74402f"), srgb("925c47")]
    return coursed(size, 20261112, 2.56, 32, (0.23, 0.27), palette, 0.011, "9e9688", grain, rim_m=0.008, tone=0.06)


def rubble(size):
    """Irregular fieldstone: anisotropic Voronoi cells on a torus."""
    rng = np.random.default_rng(20261113)
    cols, rows = 8, 10
    points = []
    for row in range(rows):
        for col in range(cols):
            points.append(((col + rng.uniform(0.15, 0.85)) / cols * size, (row + rng.uniform(0.15, 0.85)) / rows * size))
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float32) + 0.5
    f1 = np.full((size, size), np.inf, dtype=np.float32)
    f2 = np.full((size, size), np.inf, dtype=np.float32)
    ids = np.zeros((size, size), dtype=np.int32)
    for index, (px, py) in enumerate(points):
        dx = (xs - px + size * 0.5) % size - size * 0.5
        dy = ((ys - py + size * 0.5) % size - size * 0.5) * 1.25  # flatter bedded stones
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < f1
        f2 = np.where(closer, f1, np.minimum(f2, d))
        ids = np.where(closer, index, ids)
        f1 = np.where(closer, d, f1)
    border = (f2 - f1) * 0.5
    palette = [srgb("7b766d"), srgb("857a6b"), srgb("6d6b66"), srgb("8a8176"), srgb("736a5e"), srgb("666660")]
    choice = rng.integers(len(palette), size=len(points))
    tones = rng.normal(0, 1, len(points)).astype(np.float32)
    color = np.stack(palette)[choice[ids]] * (1.0 + 0.07 * np.clip(tones[ids], -2, 2))[..., None]
    color *= (1.0 + periodic_noise(size, 8, 31) * 0.06 + periodic_noise(size, 64, 32, 3) * 0.05)[..., None]
    mortar = size * 0.009
    edge = np.clip(1.0 - (border - mortar * 0.5) / (size * 0.012), 0, 1)
    color *= (1.0 - 0.12 * edge ** 2)[..., None]
    mortar_color = srgb("a39b8c") * (1.0 + periodic_noise(size, 40, 33, 2) * 0.06)[..., None]
    return blend(color, mortar_color, (mortar * 0.5 + 0.75 - border) / 1.5)


def plaster(size):
    color = np.broadcast_to(srgb("c9bfac"), (size, size, 3)).astype(np.float32).copy()
    variation = periodic_noise(size, 3, 41) * 0.045 + periodic_noise(size, 18, 42, 3) * 0.025 + periodic_noise(size, 160, 43, 2) * 0.012
    return color * (1.0 + variation)[..., None]


def planks(size):
    rng = np.random.default_rng(20261114)
    boards = 12
    board_px = size / boards
    palette = [srgb("6e5038"), srgb("7a5a3f"), srgb("634732"), srgb("80614a"), srgb("6a4e3a")]
    grain = periodic_noise(size, 3, 51, 4, cells_y=96) * 0.10 + periodic_noise(size, 12, 52, 2, cells_y=160) * 0.05
    color = np.zeros((size, size, 3), dtype=np.float32)
    xs = np.arange(size, dtype=np.float32) + 0.5
    for board in range(boards):
        y0, y1 = round(board * board_px), round((board + 1) * board_px)
        local = np.arange(y0, y1, dtype=np.float32) - y0 + 0.5
        joints = sorted(rng.uniform(0, size, rng.integers(1, 3)))
        segment = np.searchsorted(joints, xs) % len(joints)
        tones = [palette[rng.integers(len(palette))] * (1 + rng.normal(0, 0.04)) for _ in joints]
        base = np.stack(tones)[segment]
        # Weatherboard: the lower lip of each board stands proud of the next.
        lap = 1.0 - 0.14 * np.clip(1.0 - (board_px - local) / (board_px * 0.18), 0, 1) ** 2
        block = base[None, :, :] * lap[:, None, None]
        gap = np.clip((size * 0.0025 + 0.75 - np.minimum(local, board_px - local)) / 1.5, 0, 1)[:, None]
        butt = np.zeros(size, dtype=np.float32)
        for joint in joints:
            d = np.abs((xs - joint + size * 0.5) % size - size * 0.5)
            butt = np.maximum(butt, np.clip((size * 0.0018 + 0.75 - d) / 1.5, 0, 1))
        color[y0:y1] = blend(block, srgb("2a1d14"), np.maximum(gap, butt[None, :]))
    return color * (1.0 + grain)[..., None]


def roof_tiles(size, seed, palette, gap_hex, shade, splits=False, fine=None, tone=0.035):
    rng = np.random.default_rng(seed)
    courses, columns = 8, 6
    course_px = size / courses
    column_px = size / columns
    gap = size * 0.0032
    color = np.zeros((size, size, 3), dtype=np.float32)
    ys = np.arange(size, dtype=np.float32) + 0.5
    xs = np.arange(size, dtype=np.float32) + 0.5
    for course in range(courses):
        y0, y1 = round(course * course_px), round((course + 1) * course_px)
        band = ys[y0:y1] - y0
        stagger = 0.5 if course % 2 else 0.0
        for column in range(columns):
            left = (column + stagger) * column_px
            lx = (xs - left) % size
            cols = np.nonzero(lx < column_px)[0]
            local_x = lx[cols]
            # Joints that follow the real 6-column geometry, plus optional
            # narrower painted shingles inside one real tile.
            cuts = [0.0, column_px]
            if splits:
                cuts.insert(1, column_px * rng.uniform(0.38, 0.62))
            piece = np.searchsorted(cuts, local_x) - 1
            tones = [palette[rng.integers(len(palette))] * (1.0 + rng.normal(0, tone)) for _ in cuts[:-1]]
            tile = np.stack(tones)[np.clip(piece, 0, len(tones) - 1)]
            d = np.min(np.abs(local_x[None, :] - np.array(cuts)[:, None]), axis=0)
            piece_left = np.array(cuts)[np.clip(piece, 0, len(cuts) - 2)]
            piece_width = np.diff(cuts)[np.clip(piece, 0, len(cuts) - 2)]
            across = (local_x - piece_left) / piece_width
            # v=0 (image top of each band) is the exposed eave-side edge; the
            # upper part of the band sits under the next course.
            exposure = 1.0 - 0.10 * (band / (y1 - y0))[:, None]
            pixel = tile[None, :, :] * exposure[..., None] * shade(across)[None, :, None]
            arris = np.clip(1.0 - (np.minimum(d[None, :], band[:, None]) - gap) / (size * 0.004), 0, 1)
            pixel = pixel * (1 + 0.06 * arris[..., None])
            joint = np.clip((gap * 0.5 + 0.75 - d[None, :]) / 1.5, 0, 1)
            lip = np.clip((gap * 0.8 + 0.75 - band[:, None]) / 1.5, 0, 1)
            color[y0:y1, cols] = blend(pixel, srgb(gap_hex), np.maximum(joint, lip))
    if fine is not None:
        color *= (1.0 + fine)[..., None]
    return color


def slate(size):
    fine = periodic_noise(size, 16, 11) * 0.07 + periodic_noise(size, 128, 12, 2) * 0.03
    palette = [srgb("2f3a47"), srgb("36414f"), srgb("2b3540"), srgb("3a434e"), srgb("323c49")]
    return roof_tiles(size, 20261110, palette, "151a20", lambda u: np.ones_like(u), fine=fine)


def clay(size):
    fine = periodic_noise(size, 12, 61) * 0.06 + periodic_noise(size, 96, 62, 2) * 0.04
    palette = [srgb("a2512f"), srgb("b0603a"), srgb("96482b"), srgb("b86b45"), srgb("8c4529"), srgb("a85a3a")]
    # Rounded barrel tile: the tone follows the curved profile symmetrically.
    return roof_tiles(size, 20261115, palette, "3a1e15", lambda u: 0.80 + 0.20 * np.sin(np.pi * np.clip(u, 0, 1)), fine=fine, tone=0.06)


def shingle(size):
    fine = periodic_noise(size, 48, 71, 3, cells_y=3) * 0.10 + periodic_noise(size, 10, 72) * 0.05
    palette = [srgb("6b5442"), srgb("75604b"), srgb("5f4a3a"), srgb("7d6650"), srgb("665648"), srgb("594a3f")]
    return roof_tiles(size, 20261116, palette, "241a14", lambda u: np.ones_like(u), splits=True, fine=fine, tone=0.06)


WALLS = {"limestone": limestone, "chapel_stone": chapel, "brick": brick, "rubble": rubble, "plaster": plaster, "planks": planks}
ROOFS = {"slate": slate, "clay": clay, "shingle": shingle}
DESCRIPTIONS = {
    "limestone": "Fortification ashlar and the shared trim stone of every building.",
    "chapel_stone": "Chapel walls: long pale ivory ashlar with fine joints.",
    "brick": "Dormer house (se): red-brown brick, light lime mortar.",
    "rubble": "Smithy (ne): irregular fieldstone with recessed mortar.",
    "plaster": "Merchant shop (nw): warm lime plaster between the timber frame.",
    "planks": "Stable house (sw): horizontal timber weatherboards.",
    "slate": "Chapel and dormer house roofs (smithy uses a darker tint).",
    "clay": "Merchant shop roof: terracotta barrel tiles.",
    "shingle": "Stable house roof: weathered split cedar shingles.",
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def edge_jump(image):
    rgb = np.asarray(image.convert("RGB"), dtype=np.float32)
    return {"left_right": float(np.abs(rgb[:, 0] - rgb[:, -1]).mean()),
            "top_bottom": float(np.abs(rgb[0] - rgb[-1]).mean())}


def refresh_dependents(manifest):
    """Re-record exact shared-material hashes in the family records that reuse them.

    Only path-keyed hash/byte fields of the shared files change; geometry and
    other inputs in these records stay as they were reviewed.
    """
    shared = {MANIFEST.relative_to(ROOT).as_posix(): MANIFEST}
    for key in list(WALLS) + list(ROOFS):
        shared[manifest["materials"][key]["path"]] = ROOT / manifest["materials"][key]["path"]

    def update(node):
        if isinstance(node, dict):
            path = node.get("path")
            if path in shared and "sha256" in node:
                node["sha256"] = sha(shared[path])
                if "bytes" in node:
                    node["bytes"] = shared[path].stat().st_size
            for value in node.values():
                update(value)
        elif isinstance(node, list):
            for value in node:
                update(value)

    # 마을 건축의 생성형 재료 기록은 각 독립 패키지가 소유한다.
    props = ROOT / "assets/data/native_encounter_props.json"
    record = json.loads(props.read_text())
    update(record)
    record["shared_family_update"]["source"] = Path(__file__).resolve().relative_to(ROOT).as_posix()
    record["materials"]["stone"] = "Shared clean dressed limestone (procedural, make_clean_masonry.py), 2.56m world tile / 8 courses; instance tint observes source flash."
    record["materials"]["limitations"] = "Shared albedos are base colors with intrinsic edge tone only, not measured PBR scans."
    props.write_text(json.dumps(record, indent=2, ensure_ascii=False) + "\n")


def main():
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    manifest = json.loads(MANIFEST.read_text())
    script = Path(__file__).resolve()
    jobs = [(key, make, 2.56) for key, make in WALLS.items()] + [(key, make, 2.6) for key, make in ROOFS.items()]
    for key, make, tile in jobs:
        source = SOURCE_DIR / f"{key}.png"
        pixels = np.clip(make(SOURCE_SIZE), 0, 255).astype(np.uint8)
        Image.fromarray(pixels).save(source, optimize=True)
        runtime = ART_DIR / f"{key}.webp"
        small = Image.open(source).convert("RGB").resize((RUNTIME_SIZE, RUNTIME_SIZE), Image.Resampling.LANCZOS)
        small.save(runtime, "WEBP", quality=WEBP_QUALITY, method=6)
        entry = {
            "role": DESCRIPTIONS[key],
            "source": source.relative_to(ROOT).as_posix(),
            "source_sha256": sha(source),
            "generator": script.relative_to(ROOT).as_posix(),
            "path": runtime.relative_to(ROOT).as_posix(),
            "sha256": sha(runtime),
            "size": [RUNTIME_SIZE, RUNTIME_SIZE],
            "operation": f"Deterministic procedural albedo at {SOURCE_SIZE}px, Lanczos downsample to {RUNTIME_SIZE}px, WebP quality {WEBP_QUALITY}.",
            "physical_tile_m": [tile, tile],
            "source_size": [SOURCE_SIZE, SOURCE_SIZE],
            "runtime_bytes": runtime.stat().st_size,
            "edge_jump_rgb_mean_0_255": edge_jump(small),
        }
        if key in ROOFS:
            entry.update({"courses": 8, "columns": 6, "stagger": "odd courses from the eave (image top) offset by half a column"})
        manifest["materials"][key] = entry
    manifest["generation"] = "tools/preview3d/make_clean_masonry.py (walls and roofs); timber/bark keep their crops"
    manifest["limitations"] = ("Wall and roof tiles are deterministic procedural base colors with intrinsic edge tone only, "
                               "not PBR scans; no normal/roughness maps. No ground or directional scene shadow is baked.")
    MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    refresh_dependents(manifest)
    print(json.dumps({key: manifest["materials"][key]["runtime_bytes"] for key, _, _ in jobs}))


if __name__ == "__main__":
    main()
