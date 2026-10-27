import json
import math
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(os.environ.get("SJRPG_CHARACTER_SOURCE_DIR", "/tmp/sjrpg-character-source"))
OUT = ROOT / "runtime"
OUT.mkdir(exist_ok=True)
FONT = ImageFont.load_default(size=9)
BG = (36, 53, 46, 255)


def power2(x):
    return 1 << (x - 1).bit_length()


def load(className, folder, expected):
    m = json.loads((ROOT / folder / "render-metadata.json").read_text())
    assert len(m["frames"]) == expected, (className, len(m["frames"]), expected)
    for f in m["frames"]:
        im = Image.open(f["path"]).convert("RGBA")
        assert im.size == (256, 256)
        a = im.getchannel("A")
        box = a.getbbox()
        assert box is not None
        padding = [box[0], box[1], 256 - box[2], 256 - box[3]]
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
        # Exactly one uniform2x exportdownsample, with premultiplied alpha filtering.
        f["_image"] = (
            im.convert("RGBa")
            .resize((128, 128), Image.Resampling.LANCZOS)
            .convert("RGBA")
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


def pack(role, frames, reference, anchor, motion=None, anchored=False):
    tiles = []
    for i, f in enumerate(frames):
        im = f["_image"]
        b = im.getchannel("A").getbbox()
        C = (b[0] - 6, b[1] - 6)
        crop = (C[0], C[1], b[2] + 6, b[3] + 6)
        assert crop[0] >= 0 and crop[1] >= 0 and crop[2] <= 128 and crop[3] <= 128, (
            role,
            i,
            crop,
        )
        tile = im.crop(crop)
        tiles.append({"index": i, "tile": tile, "crop": crop, "frame": f})
    width = 512 if len(tiles) <= 64 else 1024
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
    assert width * height * 4 <= 9 * 1024 * 1024, (role, width, height)
    atlas = Image.new("RGBA", (width, height))
    record = {"frames": [], "feet": [], "sizes": [[128, reference]]}
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
                "exportCrop128": t["crop"],
                "packedOrigin": [x, y],
                "originalProjectedOrigin128": anchor,
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
                "fixedGlobalSourceToRuntimeScale": 0.5,
                "alphaBottomNormalization": False,
                "perFrameScaleAdjustment": False,
                "fixedProjectedOrigin128": anchor,
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


def review(m, role, folderName=None):
    folder = (
        ROOT
        / (folderName or ("warrior-full" if role == "hero" else "mage-full"))
        / "review"
    )
    folder.mkdir(exist_ok=True)
    scale = 60 / m["actorReferenceHeightRaw256"]
    anchor = m["worldOriginAnchorPx"]
    frames = {}

    def cell(f, label):
        im = Image.open(f["path"]).convert("RGBA")
        sz = (round(256 * scale * 1.20), round(256 * scale * 1.02))
        im = im.convert("RGBa").resize(sz, Image.Resampling.LANCZOS).convert("RGBA")
        c = Image.new("RGBA", (96, 110), BG)
        c.alpha_composite(
            im, (round(48 - anchor[0] * scale * 1.20), round(90 - anchor[1] * scale * 1.02))
        )
        ImageDraw.Draw(c).text((3, 2), label, font=FONT, fill="#e5dfcf")
        return c

    def saveSheet(rows, name):
        out = Image.new("RGBA", (96 * max(map(len, rows)), 110 * len(rows)), BG)
        for r, row in enumerate(rows):
            for c, im in enumerate(row):
                out.alpha_composite(im, (c * 96, r * 110))
        out.save(folder / (name + ".png"))
        out.resize((out.width * 4, out.height * 4), Image.Resampling.NEAREST).save(
            folder / (name + "-4x.png")
        )

    for f in m["frames"]:
        frames[(f["kind"], f["directionIndex"], f["phase"], f["sheet"])] = cell(
            f, f"{f['direction']} {f['kind']}{f['phase']}"
        )
    for d in [0, 4, 8, 12, 14]:
        saveSheet(
            [
                [frames[("idle", d, 0, role)]]
                + [frames[("run", d, p, role)] for p in range(8)]
            ],
            f"{role}-direction{d}-idle-run8-at60px",
        )
    saveSheet(
        [
            [frames[("run", d, 0, role)] for d in range(row * 4, (row + 1) * 4)]
            for row in range(4)
        ],
        role + "-16directions-run0-at60px",
    )
    loopFrames = []
    for p in range(8):
        out = Image.new("RGBA", (96 * 4, 110), BG)
        for c, d in enumerate([0, 4, 8, 12]):
            out.alpha_composite(frames[("run", d, p, role)], (96 * c, 0))
        loopFrames.append(out.convert("RGB"))
    loopFrames[0].save(
        folder / (role + "-cardinals-run8-runtime320ms.gif"),
        save_all=True,
        append_images=loopFrames[1:],
        duration=40,
        loop=0,
    )
    loopFrames[0].save(
        folder / (role + "-cardinals-run8-inspection530ms.gif"),
        save_all=True,
        append_images=loopFrames[1:],
        duration=[70, 60, 70, 70, 60, 70, 70, 60],
        loop=0,
    )
    saveSheet(
        [
            [
                frames[(f["kind"], f["directionIndex"], f["phase"], f["sheet"])]
                for f in m["frames"]
                if f["directionIndex"] == 12 and f["kind"] in ["attack", "cast", "roll"]
            ]
        ],
        role + "-matching-actions-at60px",
    )
    return str(folder)
