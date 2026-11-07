#!/usr/bin/env python3
"""Compose original generated concept and unedited real Godot browser captures."""
import argparse, hashlib, json, os, shutil
from pathlib import Path
from PIL import Image, ImageOps, ImageDraw, ImageFont

parser = argparse.ArgumentParser()
parser.add_argument("directory", type=Path)
parser.add_argument("--concept", type=Path, default=Path("sjrpg_3d/assets/source/entry-redesign/selection-and-continue-concept.png"))
args = parser.parse_args()
root = args.directory
before, actual = root / "before", root / "actual"
gallery = root / "comparison"
gallery.mkdir(parents=True, exist_ok=True)
concept = Image.open(args.concept).convert("RGB")
assert concept.size == (1330, 1182), "Unexpected original concept dimensions; review exact crop regions."
regions = {"class": (0, 0, 660, 1182), "save": (660, 0, 1330, 1182)}
concept_sha = hashlib.sha256(args.concept.read_bytes()).hexdigest()
font_path = Path("sjrpg_3d/assets/fonts/NanumGothic-Regular.ttf")
font = lambda size: ImageFont.truetype(str(font_path), size) if font_path.exists() else ImageFont.load_default()
title_font, label_font, small_font = font(27), font(21), font(15)
report = {"concept": {"path": str(args.concept), "sha256": concept_sha, "dimensions": list(concept.size), "regions": regions}, "before_provenance": {}, "actual_provenance": {}, "comparisons": [], "missing": []}
for key, folder in [("before_provenance", before), ("actual_provenance", actual)]:
    p = folder / "_provenance.json"
    if p.exists():
        report[key] = json.loads(p.read_text())
    proof = folder / "proof.json"
    report[key]["browser_passed"] = json.loads(proof.read_text()).get("passed") if proof.exists() else None
pairs = []
for suffix, size in [("portrait", "390x844"), ("landscape", "844x390")]:
    for role in ["warrior", "mage"]:
        pairs.append((f"class-{role}-{suffix}", f"entry-class-{role}-{size}", "class", f"{role} / {size}"))
    for scenario in ["mixed", "full"]:
        pairs.append((f"save-{scenario}-{suffix}", f"entry-save-{scenario}-{size}", "save", f"{scenario} saves / {size}"))
html = ['<!doctype html><html lang="en"><meta charset="utf-8"><title>Entry design comparison</title><style>body{background:#101512;color:#e9e2d5;font:16px sans-serif;margin:24px}img{display:block;max-width:100%;height:auto;border:1px solid #554b39}article{margin:32px 0}a{color:#dec493}p{max-width:1000px;line-height:1.6}</style><h1>Generated design and actual Godot UI</h1><p>Left: previous actual game. Middle: original generated concept crop. Right: implemented actual game. Concept text and values are illustrative; screenshots use actual fixture data. Images retain their proportions, including the responsive landscape adaptation.</p>']
for key, name, region, description in pairs:
    paths = [before / (name + ".png"), actual / (name + ".png")]
    if not all(p.exists() for p in paths):
        report["missing"].append({"comparison": key, "paths": [str(p) for p in paths if not p.exists()]})
        continue
    old_image, new_image = [Image.open(p).convert("RGB") for p in paths]
    samples = [old_image, concept.crop(regions[region]), new_image]
    # Letterbox each whole viewport. Never stretch or crop the runtime image.
    cell_w, image_h = (430, 890) if "portrait" in key else (650, 450)
    width, height = cell_w * 3 + 32, image_h + 180
    board = Image.new("RGB", (width, height), "#0e1411")
    draw = ImageDraw.Draw(board)
    draw.text((20, 16), description, font=title_font, fill="#e8ddc8")
    labels = ["BEFORE / ACTUAL GODOT", "GENERATED CONCEPT", "AFTER / ACTUAL GODOT"]
    for index, (sample, label) in enumerate(zip(samples, labels)):
        x, y = 16 + index * cell_w, 72
        draw.text((x + 12, y), label, font=label_font, fill="#cbb58b")
        box = (x + 8, y + 40, x + cell_w - 8, y + 40 + image_h)
        draw.rectangle(box, fill="#19201b", outline="#5e5340", width=1)
        fitted = ImageOps.contain(sample, (cell_w - 28, image_h - 20))
        at = (box[0] + (box[2] - box[0] - fitted.width) // 2, box[1] + (box[3] - box[1] - fitted.height) // 2)
        board.paste(fitted, at)
    draw.text((20, height - 49), "Concept is an art/design reference, not a game screenshot.", font=small_font, fill="#b9ae98")
    draw.text((20, height - 27), "Actual columns are whole exported-browser captures; contain/letterbox preserves original proportions.", font=small_font, fill="#b9ae98")
    output = gallery / (key + ".jpg")
    board.save(output, quality=91, subsampling=0)
    entry = {"name": key, "description": description, "file": output.name, "concept_region": regions[region], "before": {"path": str(paths[0]), "size": list(old_image.size), "sha256": hashlib.sha256(paths[0].read_bytes()).hexdigest()}, "actual": {"path": str(paths[1]), "size": list(new_image.size), "sha256": hashlib.sha256(paths[1].read_bytes()).hexdigest()}}
    report["comparisons"].append(entry)
    html.append(f'<article><h2>{description}</h2><a href="{output.name}"><img src="{output.name}" alt="{description} comparison"></a></article>')
    if "portrait" in key:
        import base64
        data = base64.b64encode(output.read_bytes()).decode()
        print(f"SJ_ENTRY_COMPARISON_IMAGE_BEGIN {key} image/jpeg {len(data)}")
        for i in range(0, len(data), 16384):
            print(f"SJ_ENTRY_COMPARISON_IMAGE_CHUNK {key} {data[i:i+16384]}")
        print(f"SJ_ENTRY_COMPARISON_IMAGE_END {key}")
shutil.copyfile(args.concept, gallery / "original-generated-concept.png")
(gallery / "index.html").write_text("\n".join(html), encoding="utf-8")
(gallery / "comparison-proof.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
print("ENTRY_COMPARISON_RESULT " + json.dumps({"comparisons": len(report["comparisons"]), "missing": report["missing"], "before": report["before_provenance"], "actual": report["actual_provenance"]}))
if len(report["comparisons"]) != 8 or report["missing"]:
    raise SystemExit("Comparison incomplete: missing genuine before/actual files.")
