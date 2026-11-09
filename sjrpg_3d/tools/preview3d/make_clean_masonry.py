"""Generate the clean dressed-limestone and blue-slate village base colors.

The user asked for a cleaner, current look for the village wall, chapel and
shops (2026-11-09) and supplied the chapel gameplay reference again. The old
generated tiles had rough rock-faced blocks and low-contrast joints that read
as muddy at mobile zoom. These tiles are deterministic (fixed seeds) so the
exact pixels can be rebuilt and reviewed:

* limestone: 2.56m tile, 8 courses of 0.32m, smooth sawn ashlar 0.40-0.80m
  wide in running bond, fine recessed mortar, quiet per-stone tone changes.
* slate: 2.6m tile, 8 courses x 6 columns. Even course bands (from the eave,
  UV v=0 at the image top) have joints at u=k/6 and odd bands at (k+0.5)/6,
  matching NativeHouse3D._roof's real tile geometry.

Albedo only: uniform diffuse light, no cast shadow or directional highlight.
Small edge tone changes are intrinsic material (arris wear, slate thickness).
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


def periodic_noise(size, cells, seed, octaves=4):
    """Tileable value noise in [-1, 1] (bilinear lattice on a torus)."""
    rng = np.random.default_rng(seed)
    total = np.zeros((size, size), dtype=np.float32)
    amplitude, weight = 1.0, 0.0
    for octave in range(octaves):
        n = cells * (2 ** octave)
        lattice = rng.uniform(-1.0, 1.0, (n, n)).astype(np.float32)
        coord = np.arange(size, dtype=np.float32) * n / size
        i0 = np.floor(coord).astype(int) % n
        i1 = (i0 + 1) % n
        f = coord - np.floor(coord)
        f = f * f * (3 - 2 * f)
        rows = lattice[i0][:, i0] * (1 - f)[None, :] + lattice[i0][:, i1] * f[None, :]
        rows2 = lattice[i1][:, i0] * (1 - f)[None, :] + lattice[i1][:, i1] * f[None, :]
        layer = rows * (1 - f)[:, None] + rows2 * f[:, None]
        total += layer * amplitude
        weight += amplitude
        amplitude *= 0.5
    return total / weight


def edge_distance(local_x, local_y, width, height):
    return np.minimum(np.minimum(local_x, width - local_x), np.minimum(local_y, height - local_y))


def limestone(size):
    rng = np.random.default_rng(20261109)
    courses = 8
    course_px = size / courses
    px_per_m = size / 2.56
    mortar = size * 0.0045  # about 11.5mm joint
    stone_id = np.full((size, size), -1, dtype=np.int32)
    dist = np.zeros((size, size), dtype=np.float32)
    tones = []
    xs = np.arange(size, dtype=np.float32)
    for course in range(courses):
        # Partition the full periodic course into 0.40-0.80m stones.
        widths = []
        remaining = 2.56
        while remaining > 0.8:
            w = float(rng.uniform(0.42, 0.78))
            if remaining - w < 0.40:
                w = remaining - 0.40 if remaining - 0.40 >= 0.40 else remaining
            widths.append(w)
            remaining -= w
        if remaining > 1e-6:
            widths.append(remaining)
        offset = rng.uniform(0, 2.56)
        y0 = round(course * course_px)
        y1 = round((course + 1) * course_px)
        local_y = np.arange(y0, y1, dtype=np.float32) - y0 + 0.5
        start = offset
        for w in widths:
            tone = rng.normal(0.0, 1.0)
            tones.append((tone, rng.uniform(0.2, 0.8)))
            index = len(tones) - 1
            left = start * px_per_m
            right = (start + w) * px_per_m
            for shift in (-size, 0, size):
                lx = xs + 0.5 - (left + shift)
                inside = (lx >= 0) & (lx < right - left)
                if not inside.any():
                    continue
                cols = np.nonzero(inside)[0]
                d = edge_distance(lx[cols][None, :], local_y[:, None], right - left, y1 - y0)
                stone_id[y0:y1, cols] = index
                dist[y0:y1, cols] = d
            start += w
    base = srgb("988e80")
    warm = srgb("a3947e")
    cool = srgb("8c8880")
    color = np.zeros((size, size, 3), dtype=np.float32)
    tone_value = np.array([t for t, _ in tones], dtype=np.float32)[stone_id]
    hue_mix = np.array([h for _, h in tones], dtype=np.float32)[stone_id]
    tint = np.where(hue_mix[..., None] < 0.5,
                    base + (cool - base) * (1 - hue_mix[..., None] * 2),
                    base + (warm - base) * (hue_mix[..., None] * 2 - 1))
    color[:] = tint * (1.0 + 0.055 * np.clip(tone_value, -2, 2))[..., None]
    # Fine sawn-stone grain: very low amplitude so faces stay smooth and clean.
    grain = periodic_noise(size, 6, 7) * 0.045 + periodic_noise(size, 48, 8, 3) * 0.03
    color *= (1.0 + grain)[..., None]
    # Slightly worn arris: a 1.5cm lighter-then-darker rim reads as a dressed edge
    # from every light direction (no one-sided highlight).
    rim = size * 0.006
    edge = np.clip(1.0 - (dist - mortar * 0.5) / rim, 0.0, 1.0)
    color *= (1.0 - 0.07 * edge ** 2)[..., None]
    mortar_color = srgb("625d55") * (1.0 + periodic_noise(size, 40, 9, 2) * 0.05)[..., None]
    m = np.clip((mortar * 0.5 + 0.75 - dist) / 1.5, 0.0, 1.0)[..., None]
    color = color * (1 - m) + mortar_color * m
    return np.clip(color, 0, 255).astype(np.uint8)


def slate(size):
    rng = np.random.default_rng(20261110)
    courses, columns = 8, 6
    course_px = size / courses
    column_px = size / columns
    gap = size * 0.0032
    color = np.zeros((size, size, 3), dtype=np.float32)
    ys = np.arange(size, dtype=np.float32) + 0.5
    xs = np.arange(size, dtype=np.float32) + 0.5
    palette = [srgb("2f3a47"), srgb("36414f"), srgb("2b3540"), srgb("3a434e"), srgb("323c49")]
    fine = periodic_noise(size, 16, 11) * 0.07 + periodic_noise(size, 128, 12, 2) * 0.03
    for course in range(courses):
        y0, y1 = round(course * course_px), round((course + 1) * course_px)
        band = ys[y0:y1] - y0
        stagger = 0.5 if course % 2 else 0.0
        for column in range(columns):
            left = (column + stagger) * column_px
            tile = palette[rng.integers(len(palette))] * (1.0 + rng.normal(0, 0.035))
            lx = (xs - left) % size
            inside = lx < column_px
            cols = np.nonzero(inside)[0]
            local_x = lx[cols]
            # v=0 (image top of each band) is the exposed eave-side edge; the
            # upper part of the band sits under the next course.
            exposure = 1.0 - 0.10 * (band / (y1 - y0))[:, None]
            d = np.minimum(local_x[None, :], column_px - local_x[None, :])
            joint = np.clip((gap * 0.5 + 0.75 - d) / 1.5, 0, 1)
            lip = np.clip((gap * 0.8 + 0.75 - band[:, None]) / 1.5, 0, 1)
            shade = np.maximum(joint, lip)
            pixel = tile[None, None, :] * exposure[..., None]
            # Thin cut edge of each slate, slightly lighter, all around.
            arris = np.clip(1.0 - (np.minimum(d, band[:, None]) - gap) / (size * 0.004), 0, 1)
            pixel = pixel * (1 + 0.06 * arris[..., None])
            pixel = pixel * (1 - shade[..., None]) + srgb("151a20")[None, None, :] * shade[..., None]
            color[y0:y1, cols] = pixel
    color *= (1.0 + fine)[..., None]
    return np.clip(color, 0, 255).astype(np.uint8)


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
    for key in ("limestone", "slate"):
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

    houses = ROOT / "assets/source/preview3d/houses/provenance.json"
    record = json.loads(houses.read_text())
    update(record)
    record["materials"]["actual_material_record"] = manifest
    record["materials"]["provenance_sha256"] = sha(MANIFEST)
    houses.write_text(json.dumps(record, indent=2, ensure_ascii=False) + "\n")
    chapel = ROOT / "assets/source/preview3d/chapel/refinement.json"
    record = json.loads(chapel.read_text())
    update(record)
    chapel.write_text(json.dumps(record, indent=2, ensure_ascii=False) + "\n")
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
    for key, make, tile in (("limestone", limestone, 2.56), ("slate", slate, 2.6)):
        source = SOURCE_DIR / f"{key}.png"
        Image.fromarray(make(SOURCE_SIZE)).save(source, optimize=True)
        runtime = ART_DIR / f"{key}.webp"
        small = Image.open(source).convert("RGB").resize((RUNTIME_SIZE, RUNTIME_SIZE), Image.Resampling.LANCZOS)
        small.save(runtime, "WEBP", quality=WEBP_QUALITY, method=6)
        entry = {
            "source": source.relative_to(ROOT).as_posix(),
            "source_sha256": sha(source),
            "generator": script.relative_to(ROOT).as_posix(),
            "generator_sha256": sha(script),
            "path": runtime.relative_to(ROOT).as_posix(),
            "sha256": sha(runtime),
            "size": [RUNTIME_SIZE, RUNTIME_SIZE],
            "operation": f"Deterministic procedural albedo at {SOURCE_SIZE}px, Lanczos downsample to {RUNTIME_SIZE}px, WebP quality {WEBP_QUALITY}.",
            "physical_tile_m": [tile, tile],
            "courses": 8,
            "source_size": [SOURCE_SIZE, SOURCE_SIZE],
            "runtime_bytes": runtime.stat().st_size,
            "edge_jump_rgb_mean_0_255": edge_jump(small),
        }
        if key == "slate":
            entry["columns"] = 6
            entry["stagger"] = "odd courses from the eave (image top) offset by half a column"
        manifest["materials"][key] = entry
    manifest["generation"] = "tools/preview3d/make_clean_masonry.py (limestone, slate); timber/bark keep their crops"
    manifest["limitations"] = ("Limestone and slate are deterministic procedural base colors with intrinsic edge tone only, "
                               "not PBR scans; no normal/roughness maps. No ground or directional scene shadow is baked.")
    MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    refresh_dependents(manifest)
    print(json.dumps({k: manifest["materials"][k]["sha256"] for k in ("limestone", "slate")}))


if __name__ == "__main__":
    main()
