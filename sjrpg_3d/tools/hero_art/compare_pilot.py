"""Compare non-shipping baseline/candidate renders without repainting either.

Reports actual alpha silhouettes and the original projected origin/bone metadata.
Contact sheets use unchanged native frames on a plain review background.
"""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw


def load(folder):
    data = json.loads((folder / "render-metadata.json").read_text())
    frames = {(f["kind"], f["directionIndex"], f["phase"]): f for f in data["frames"]}
    if len(frames) not in (4, 12):
        raise ValueError("Expected four idle directions, optionally eight run frames")
    return data, frames


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    before, baseline = load(args.baseline)
    after, candidate = load(args.candidate)
    report = {"adoptedInRuntime": False, "frameCount": len(candidate), "cameraUnchanged": True,
              "posesUnchanged": True, "alphaBoundsUnchanged": True, "frames": []}
    for key in ("cameraLocation", "cameraRotation", "target", "orthoScale", "fixedObjectScale", "worldOriginAnchorPx"):
        report["cameraUnchanged"] &= before[key] == after[key]
    for key, updated in candidate.items():
        original = baseline[key]
        same_pose = all(original[k] == updated[k] for k in ("bones", "action", "actionFrame", "normalizedActionTime", "yawDegrees"))
        a = Image.open(original["path"]).convert("RGBA")
        b = Image.open(updated["path"]).convert("RGBA")
        ab = a.getchannel("A").point(lambda value: 255 if value > 64 else 0).getbbox()
        bb = b.getchannel("A").point(lambda value: 255 if value > 64 else 0).getbbox()
        report["posesUnchanged"] &= same_pose
        report["alphaBoundsUnchanged"] &= ab == bb
        report["frames"].append({"kind": key[0], "direction": key[1], "phase": key[2],
                                 "poseUnchanged": same_pose, "baselineAlphaBounds": ab, "candidateAlphaBounds": bb})
    size = before["cellSize"]

    def sheet(keys, name):
        output = Image.new("RGB", (size[0] * len(keys), (size[1] + 28) * 2), (36, 48, 40))
        draw = ImageDraw.Draw(output)
        for row, (label, frames) in enumerate((("Baseline", baseline), ("Candidate", candidate))):
            for col, key in enumerate(keys):
                frame = frames[key]
                image = Image.open(frame["path"]).convert("RGBA")
                x, y = col * size[0], row * (size[1] + 28)
                draw.text((x + 10, y + 8), f"{label} / {frame['direction']} / {key[0]} {key[2]}", fill=(239, 224, 190))
                output.paste(image, (x, y + 28), image)
        output.save(args.out / name)

    sheet([("idle", d, 0) for d in (0, 4, 8, 12)], "comparison-idle.png")
    if all(("run", 0, phase) in candidate for phase in range(8)):
        sheet([("run", 0, phase) for phase in range(8)], "comparison-run.png")
    (args.out / "comparison.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({k: v for k, v in report.items() if k != "frames"}, indent=2))
    if not report["cameraUnchanged"] or not report["posesUnchanged"]:
        raise SystemExit("Pilot changed the camera/pose contract")


if __name__ == "__main__":
    main()
