"""Pack an explicit 272-frame mage trial into /tmp without touching runtime assets.

Keep native pixels, the existing ActorAtlas reference height, fixed projected origin,
and phase-major sixteen-direction clips. No --install option exists.
"""
import argparse
import hashlib
import json
import math
import shutil
from pathlib import Path

from PIL import Image, ImageDraw

import packing

PROJECT = Path(__file__).resolve().parents[2]
BASELINE = PROJECT / "assets/source/hero-materials/baseline"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def painted_bounds(image):
    return image.getchannel("A").point(lambda alpha: 255 if alpha > 64 else 0).getbbox()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    output = args.out.resolve()
    if not output.is_relative_to(Path("/tmp")):
        raise ValueError("This unadopted trial may write only under /tmp")
    output.mkdir(parents=True, exist_ok=True)
    metadata_path = args.source / "render-metadata.json"
    metadata = json.loads(metadata_path.read_text())
    if metadata["pilot"]["mode"] != "production" or len(metadata["frames"]) != 272:
        raise ValueError("Expected the completed explicit272-frame production trial")
    if metadata["cellSize"] != [384, 384]:
        raise ValueError("Preserve the current native384-pixel cell contract")
    contract = json.loads((BASELINE / "contract.json").read_text())
    for name, entry in contract["files"].items():
        if sha(BASELINE / name) != entry["sha256"]:
            raise ValueError("Immutable baseline pixels or contract changed: " + name)
    old_motion = json.loads((BASELINE / "mage.json").read_text())
    old_action = json.loads((BASELINE / "mage-cast.json").read_text())
    reference = float(contract["reference_height"])
    if not math.isclose(reference, metadata["actorReferenceHeightRaw256"], abs_tol=1e-9):
        raise ValueError("Reference height changed")
    if old_motion["motion"] != metadata["motion"]:
        raise ValueError("Direction/frame/layout contract changed")
    original = {
        "mage": (old_motion, Image.open(BASELINE / "mage.png").convert("RGBA")),
        "mage-cast": (old_action, Image.open(BASELINE / "mage-cast.webp").convert("RGBA")),
    }
    packing.SOURCE_CELL = 384
    packing.OUT = output / "packing"
    packing.OUT.mkdir(exist_ok=True)
    # Reuse reviewed alpha padding, gaze, root-motion and eight-step cycle guards.
    loaded = packing.load("mage", args.source, 272, export_scale=1.0, metadata=metadata)
    anchor = loaded["worldOriginAnchorPx"]
    if anchor != contract["projected_origin"]:
        raise ValueError("Fixed projected origin changed")
    manifest = {
        "adoptedInRuntime": False,
        "renderHelperSha256": sha(Path(__file__).with_name("render_mage_pilot.py")),
        "packingHelperSha256": sha(Path(__file__).with_name("packing.py")),
        "sourceContractSha256": sha(Path(__file__).with_name("source-provenance.json")),
        "baselineContractSha256": sha(BASELINE / "contract.json"),
        "sourceMetadata": str(metadata_path.resolve()),
        "sourceMetadataSha256": sha(metadata_path),
        "bakeContract": loaded["bakeContract"],
        "generatedMaterial": loaded["pilot"]["source"],
        "generatedMaterialSha256": loaded["pilot"]["sha256"],
        "sourceCell": [384, 384], "sourceToRuntimeScale": 1.0,
        "projectedOrigin": anchor, "referenceHeight": reference,
        "headExtraction": loaded["headExtraction"],
        "comparedWithBaseline": contract["files"],
        "outputs": {}, "frames": [],
    }
    review = output / "review"
    review.mkdir(exist_ok=True)
    all_frames = {}
    for role in ("mage", "mage-cast"):
        frames = [frame for frame in loaded["frames"] if frame["sheet"] == role]
        if len(frames) != (144 if role == "mage" else 128):
            raise ValueError("Missing required motion/action frames")
        result = packing.pack(role, frames, reference, anchor,
                              motion=loaded["motion"] if role == "mage" else None,
                              anchored=True, export_scale=1.0)
        record = result["record"]
        if role == "mage-cast":
            record["action"] = old_action["action"]
        extension = ".png" if role == "mage" else ".webp"
        image_path = output / (role + extension)
        shutil.copyfile(result["pngAlternative"] if role == "mage" else result["image"], image_path)
        bounds_path = output / (role + ".json")
        bounds_path.write_text(json.dumps(record, separators=(",", ":")) + "\n")
        sequence = hashlib.sha256()
        old_record, old_image = original[role]
        proof = json.loads((packing.OUT / (role + "-packing.json")).read_text())
        for index, frame in enumerate(frames):
            all_frames[(frame["kind"], frame["directionIndex"], frame["phase"])] = frame
            sequence.update(Path(frame["path"]).read_bytes())
            prior_roi = old_record["frames"][index]
            prior = old_image.crop((prior_roi[0], prior_roi[1], prior_roi[0] + prior_roi[2], prior_roi[1] + prior_roi[3]))
            before = painted_bounds(prior)
            after = painted_bounds(frame["_image"])
            slot = proof["slots"][index]
            origin = slot["packedOrigin"]
            crop = slot["exportCrop384"]
            feet = record["feet"][index]
            closed = [feet[0] - origin[0] + crop[0], feet[1] - origin[1] + crop[1]]
            error = max(abs(closed[axis] - anchor[axis]) for axis in (0, 1))
            if error > 1e-6:
                raise ValueError("Packed feet no longer reconstruct the projected origin")
            old_source_crop = [anchor[axis] - (old_record["feet"][index][axis] - prior_roi[axis]) for axis in (0, 1)]
            manifest["frames"].append({
                "role": role, "slot": index, "kind": frame["kind"],
                "direction": frame["directionIndex"], "phase": frame["phase"],
                "oldPaintedSize": [before[2] - before[0], before[3] - before[1]],
                "newPaintedSize": [after[2] - after[0], after[3] - after[1]],
                "oldSourceCropOrigin": old_source_crop, "newSourceCropOrigin": crop[:2],
                "newFeetWithinROI": [feet[axis] - origin[axis] for axis in (0, 1)],
                "projectedOriginClosureError": error,
                "sourceAction": frame["action"], "normalizedActionTime": frame["normalizedActionTime"],
                **({"sockets": frame["sockets"]} if "sockets" in frame else {}),
            })
        manifest["outputs"][role] = {
            "image": str(image_path), "imageSha256": sha(image_path),
            "bounds": str(bounds_path), "boundsSha256": sha(bounds_path),
            "frameCount": len(frames), "nativeRenderSequenceSha256": sequence.hexdigest(),
            "decodedRGBABytes": result["decodedRGBABytes"], "compressedBytes": image_path.stat().st_size,
        }

    def sheet(rows, filename):
        width = max(len(row) for row in rows)
        canvas = Image.new("RGB", (384 * width, 412 * len(rows)), (36, 48, 40))
        draw = ImageDraw.Draw(canvas)
        for row_index, row in enumerate(rows):
            for column, key in enumerate(row):
                frame = all_frames[key]
                x, y = column * 384, row_index * 412
                draw.text((x + 10, y + 8), f"{frame['direction']} / {key[0]} {key[2]}", fill=(239, 224, 190))
                canvas.paste(frame["_image"], (x, y + 28), frame["_image"])
        canvas.save(review / filename)

    sheet([[ ("idle", direction, 0) for direction in range(row * 4, (row + 1) * 4)]
           for row in range(4)], "idle-16-directions.png")
    sheet([[ ("cast", direction, phase) for phase in range(8)]
           for direction in (0, 4, 8, 12)], "cast-4-directions-8-frames.png")
    sheet([[ ("run", direction, phase) for phase in range(8)]
           for direction in (0, 4, 8, 12)], "run-4-directions-8-frames.png")
    manifest["maximumProjectedOriginClosureError"] = max(frame["projectedOriginClosureError"] for frame in manifest["frames"])
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps({"adoptedInRuntime": False, "frames": len(manifest["frames"]),
                      "maximumProjectedOriginClosureError": manifest["maximumProjectedOriginClosureError"],
                      "outputs": manifest["outputs"]}, indent=2))


if __name__ == "__main__":
    main()
