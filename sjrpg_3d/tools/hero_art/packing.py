"""Mechanical native-pixel atlas packer adapted from sjrpg pack-runtime.py.

Upstream SHA256: 75f088c7c4247dd007c9377e04541b766d00fd2574ff5e8efea462fadc041ccd
No source images are painted, resized, or installed. Output is assigned by pack_mage_trial.py.
"""
import json
import math
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(os.environ.get("SJRPG_CHARACTER_SOURCE_DIR", "/tmp/sjrpg-character-source"))
OUT = None  # The Godot trial caller must select an explicit temporary output.
FONT = ImageFont.load_default(size=9)
BG = (36, 53, 46, 255)
SOURCE_CELL = int(os.environ.get("SJRPG_RENDER_CELL", "384"))


def power2(x):
    return 1 << (x - 1).bit_length()


def load(className, folder, expected, *, export_scale=0.5, metadata=None):
    m = metadata if metadata is not None else json.loads((ROOT / folder / "render-metadata.json").read_text())
    assert len(m["frames"]) == expected, (className, len(m["frames"]), expected)
    for f in m["frames"]:
        im = Image.open(f["path"]).convert("RGBA")
        assert im.size == (SOURCE_CELL, SOURCE_CELL)
        a = im.getchannel("A")
        box = a.getbbox()
        assert box is not None
        padding = [box[0], box[1], SOURCE_CELL - box[2], SOURCE_CELL - box[3]]
        assert min(padding) >= 8, (f["path"], padding)
        f["sourceAlphaBounds"] = box
        f["sourceEdgePadding"] = padding
        assert math.hypot(*f["bones"]["root"]["world"][:2]) < 1e-5, (
            "root planar motion",
            f["path"],
            f["bones"]["root"]["world"],
        )
        if f["kind"] in ["idle", "run"]:
            v = f["bones"]["projectedGaze"]["worldDirection"]
            actual = math.degrees(math.atan2(-v[1], v[0]))
            expectedHeading = (90 + 22.5 * f["directionIndex"]) % 360
            error = (actual - expectedHeading + 180) % 360 - 180
            assert abs(error) < 10, (f["path"], "gaze", actual, expectedHeading, error)
            f["headingErrorDegrees"] = error
        if f["kind"] == "run":
            yaw = math.radians(f["yawDegrees"])
            fw = (math.sin(yaw), -math.cos(yaw))
            feet = f["bones"]
            f["leftMinusRightForward"] = sum(
                (feet["foot_l"]["world"][i] - feet["foot_r"]["world"][i]) * fw[i]
                for i in range(2)
            )
        # Preserve native samples for high-density exports; filter only an explicit downsample.
        cell = round(SOURCE_CELL * export_scale)
        assert export_scale in (0.5, 1.0)
        f["_image"] = im if cell == SOURCE_CELL else (
            im.convert("RGBa").resize((cell, cell), Image.Resampling.LANCZOS).convert("RGBA")
        )
    for d in range(16):
        fs = sorted(
            [f for f in m["frames"] if f["kind"] == "run" and f["directionIndex"] == d],
            key=lambda f: f["phase"],
        )
        assert len(fs) == 8
        signs = [f["leftMinusRightForward"] > 0 for f in fs]
        assert sum(signs[i] != signs[(i + 1) % 8] for i in range(8)) == 2
    return m


def pack(role, frames, reference, anchor, motion=None, anchored=False, *, export_scale=0.5):
    cell = round(SOURCE_CELL * export_scale)
    density = export_scale / 0.5
    tiles = []
    for i, f in enumerate(frames):
        im = f["_image"]
        b = im.getchannel("A").getbbox()
        C = (b[0] - 6, b[1] - 6)
        crop = (C[0], C[1], b[2] + 6, b[3] + 6)
        assert crop[0] >= 0 and crop[1] >= 0 and crop[2] <= cell and crop[3] <= cell, (
            role,
            i,
            crop,
        )
        tile = im.crop(crop)
        tiles.append({"index": i, "tile": tile, "crop": crop, "frame": f})
    width = round((512 if len(tiles) <= 64 else 1024) * density)
    shelves = []
    placements = {}
    for t in sorted(tiles, key=lambda t: (-t["tile"].height, -t["tile"].width)):
        w, h = t["tile"].size
        shelf = next(
            (s for s in shelves if s["height"] >= h and s["x"] + w <= width), None
        )
        if shelf is None:
            y = sum(s["height"] for s in shelves)
            shelf = {"x": 0, "y": y, "height": h}
            shelves.append(shelf)
        placements[t["index"]] = (shelf["x"], shelf["y"])
        shelf["x"] += w
    height = power2(sum(s["height"] for s in shelves))
    assert width * height * 4 <= 9 * 1024 * 1024 * density ** 2, (role, width, height)
    atlas = Image.new("RGBA", (width, height))
    record = {"frames": [], "feet": [], "sizes": [[cell, reference]]}
    proof = []
    for t in tiles:
        i = t["index"]
        x, y = placements[i]
        tile = t["tile"]
        atlas.alpha_composite(tile, (x, y))
        cx, cy, _, _ = t["crop"]
        foot = [x + anchor[0] - cx, y + anchor[1] - cy]
        record["frames"].append([x, y, tile.width, tile.height])
        record["feet"].append(foot)
        proof.append(
            {
                "slot": i,
                "sheet": role,
                "kind": t["frame"]["kind"],
                "directionIndex": t["frame"]["directionIndex"],
                "phase": t["frame"]["phase"],
                "sourceFile": t["frame"]["path"],
                "sourceAction": t["frame"]["action"],
                "normalizedActionTime": t["frame"]["normalizedActionTime"],
                f"exportCrop{cell}": t["crop"],
                "packedOrigin": [x, y],
                f"originalProjectedOrigin{cell}": anchor,
                "absoluteFeet": foot,
                "derivedAnchor": [foot[0] - x, foot[1] - y],
            }
        )
    if motion:
        record["motion"] = motion
    if anchored:
        record["anchorMode"] = "projected-origin"
    path = OUT / f"actors-{role}.webp"
    atlas.save(path, format="WEBP", lossless=True, method=6, exact=True)
    # PNG copy retained as exportalternative for existing loaderextensioncontracts.
    png = OUT / f"actors-{role}.png"
    atlas.save(png, optimize=True)
    recPath = OUT / f"{role}-bounds.json"
    recPath.write_text(json.dumps(record, separators=(",", ":")) + "\n")
    (OUT / f"{role}-packing.json").write_text(
        json.dumps(
            {
                "role": role,
                "imageSize": [width, height],
                "decodedRGBABytes": width * height * 4,
                "compressedWebPBytes": path.stat().st_size,
                "compressedPNGBytes": png.stat().st_size,
                "transparentPadding": 6,
                "fixedGlobalSourceToRuntimeScale": export_scale,
                "alphaBottomNormalization": False,
                "perFrameScaleAdjustment": False,
                f"fixedProjectedOrigin{cell}": anchor,
                "referenceHeight": reference,
                "slots": proof,
            },
            indent=2,
        )
    )
    return {
        "image": str(path),
        "pngAlternative": str(png),
        "record": record,
        "decodedRGBABytes": width * height * 4,
        "compressedBytes": path.stat().st_size,
    }
