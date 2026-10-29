"""Pack native character renders without resampling.

384px sources increase visible body size by 1.5 while preserving collision
geometry, authored poses and the projected ground origin.
"""

import argparse
import hashlib
import importlib.util
import json
import shutil
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--warrior", type=Path, required=True)
    parser.add_argument("--mage", type=Path, required=True)
    parser.add_argument("--mage-casts", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--install", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    spec = importlib.util.spec_from_file_location(
        "character_pack_runtime", Path(__file__).with_name("pack-runtime.py")
    )
    pack = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(pack)
    pack.OUT = args.output
    pack.OUT.mkdir(parents=True, exist_ok=True)

    def source(folder):
        return json.loads((folder / "render-metadata.json").read_text())

    mage_metadata = source(args.mage)
    if args.mage_casts:
        mage_metadata["frames"] = [
            f for f in mage_metadata["frames"] if f["kind"] != "cast"
        ] + source(args.mage_casts)["frames"]
    warrior = pack.load(
        "warrior", args.warrior, 560, export_scale=1.0
    )
    mage = pack.load(
        "mage", args.mage, 304, export_scale=1.0, metadata=mage_metadata
    )
    manifest = {"version": 1, "sourceCell": pack.SOURCE_CELL, "runtimeCell": pack.SOURCE_CELL,
                "worldSizeIncrease": pack.SOURCE_CELL / 256,
                "pixelDensityIncrease": pack.SOURCE_CELL / 128, "runtimeRoles": {}}
    roles = manifest["runtimeRoles"]

    def output(role, frames, metadata, *, motion=None, roll=False):
        reference = metadata["actorReferenceHeightRaw256"] * (43 / 60 if roll else 1)
        result = pack.pack(
            role, frames, reference, metadata["worldOriginAnchorPx"],
            motion=motion, anchored=True, export_scale=1.0,
        )
        if role not in ("hero", "mage", "roll"):
            result["record"]["action"] = {
                "directions": 16, "frames": 8, "layout": "phase-major"
            }
        if roll:
            result["record"]["sizes"].append(
                [256, mage["actorReferenceHeightRaw256"] * 43 / 60]
            )
        target = {
            "hero": "hero-helmeted", "hero-attack": "hero-helmeted-attack",
            "hero-backhand": "hero-helmeted-backhand",
            "hero-cleave": "hero-helmeted-cleave", "mage": "actors-mage",
            "mage-cast": "actors-mage-cast", "roll": "hero-helmeted-roll",
        }[role]
        extension = "png" if role in ("mage", "roll") else "webp"
        image = Path(result["pngAlternative"] if extension == "png" else result["image"])
        bounds_name = "mage-bounds.json" if role == "mage" else f"{target}-bounds.json"
        record = args.output / f"{role}-bounds.json"
        record.write_text(json.dumps(result["record"], separators=(",", ":")) + "\n")
        if args.install:
            shutil.copyfile(image, root / "flutter_game/art" / f"{target}.{extension}")
            shutil.copyfile(record, root / "flutter_game/art" / bounds_name)
        # Hash each native source to make the density increase independently auditable.
        source_hash = hashlib.sha256()
        for f in frames:
            source_hash.update(Path(f["path"]).read_bytes())
        roles[role] = {
            "image": f"flutter_game/art/{target}.{extension}",
            "metadata": f"flutter_game/art/{bounds_name}",
            "frameCount": len(frames), "sha256": hashlib.sha256(image.read_bytes()).hexdigest(),
            "nativeRenderSequenceSha256": source_hash.hexdigest(),
            "decodedRGBABytes": result["decodedRGBABytes"],
            "compressedBytes": image.stat().st_size,
            "referenceHeight": reference, "projectedOrigin": metadata["worldOriginAnchorPx"],
        }
        print(role, len(frames), result["decodedRGBABytes"], image.stat().st_size, flush=True)

    for metadata, names in [
        (warrior, ["hero", "hero-attack", "hero-backhand", "hero-cleave"]),
        (mage, ["mage", "mage-cast"]),
    ]:
        for role in names:
            frames = [f for f in metadata["frames"] if f["sheet"] == role]
            output(role, frames, metadata, motion=metadata["motion"] if role in ("hero", "mage") else None)
    rolls = [f for f in warrior["frames"] if f["kind"] == "roll"] + [
        f for f in mage["frames"] if f["kind"] == "roll"
    ]
    assert len(rolls) == 64
    assert warrior["worldOriginAnchorPx"] == mage["worldOriginAnchorPx"]
    output("roll", rolls, warrior, roll=True)
    assert sum(v["frameCount"] for v in roles.values()) == 864
    manifest["decodedRGBAUnionBytes"] = sum(v["decodedRGBABytes"] for v in roles.values())
    manifest["compressedBytes"] = sum(v["compressedBytes"] for v in roles.values())
    (args.output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    if args.install:
        (root / "docs/art/character-high-resolution-provenance.json").write_text(
            json.dumps(manifest, indent=2) + "\n"
        )


if __name__ == "__main__":
    main()
