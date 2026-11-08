"""Pack only the generated shared limestone color texture, preserving other materials.

Offline format/size packaging only; no painting, relighting or seam blending.
The actual complete source, prompt, dimensions, course measurements and hashes
remain recorded beside the candidate. This tool publishes immutable blobs only.
"""
import base64
import hashlib
import json
import os
from pathlib import Path
import urllib.request
from PIL import Image, ImageStat

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/preview3d/town-limestone/generated.png"
GENERATION = ROOT / "assets/source/preview3d/town-limestone/generation.json"
OUT = ROOT / "assets/art/preview3d/limestone.webp"
MANIFEST = ROOT / "assets/art/preview3d/materials.json"
PROOF = ROOT / "assets/source/preview3d/town-limestone/packaging.json"
SIZE = 768


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def image_metrics(image):
    width, height = image.size
    # These are observations of source pixels, never new painted joints.
    gray = image.convert("L")
    row_mean = [ImageStat.Stat(gray.crop((0, y, width, y + 1))).mean[0] for y in range(height)]
    joints = []
    for index in range(1, 8):
        lo = max(0, round(height * (index / 8.0 - 0.025)))
        hi = min(height, round(height * (index / 8.0 + 0.025)))
        joints.append(min(range(lo, hi), key=lambda y: row_mean[y]))
    rgb = image.convert("RGB")
    def mean_jump(first, second):
        a, b = list(first.getdata()), list(second.getdata())
        return sum(abs(x - y) for p, q in zip(a, b) for x, y in zip(p, q)) / (len(a) * 3.0)
    return {
        "observed_horizontal_joint_rows_px": joints,
        "expected_courses": 8,
        "edge_jump_rgb_mean_0_255": {
            "left_right": mean_jump(rgb.crop((0, 0, 1, height)), rgb.crop((width - 1, 0, width, height))),
            "top_bottom": mean_jump(rgb.crop((0, 0, width, 1)), rgb.crop((0, height - 1, width, height))),
        },
        "review_note": "Quantitative observations only; actual repeated surfaces/corners must be visually reviewed.",
    }


def pack_limestone():
    source = Image.open(SOURCE).convert("RGB")
    if source.width != source.height or source.width < SIZE or source.width > 4096:
        raise RuntimeError("Expected a square source large enough for downsampling")
    expected = json.loads(GENERATION.read_text())
    if expected["source_git_blob"] != "027d06500157f808e375552c9cae40554931df48":
        raise RuntimeError("An unreviewed source requires an explicit generation record update")
    data = SOURCE.read_bytes()
    git_blob = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
    if git_blob != expected["source_git_blob"]:
        raise RuntimeError("Source pixels differ from the selected generated blob")
    packed = source.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    packed.save(OUT, "WEBP", quality=94, method=6)
    return {
        "source": str(SOURCE.relative_to(ROOT)), "source_sha256": sha(SOURCE),
        "generation": str(GENERATION.relative_to(ROOT)),
        "path": str(OUT.relative_to(ROOT)), "sha256": sha(OUT), "size": [SIZE, SIZE],
        "operation": "Full-source downsample to768px and WebP quality94; no painting, source relighting or seam blending.",
        "physical_tile_m": [2.56, 2.56], "courses": 8,
        "source_size": list(source.size), "runtime_bytes": OUT.stat().st_size,
        "source_pixel_measurements": image_metrics(source),
    }


def main():
    original = json.loads(MANIFEST.read_text())
    others = {name: (ROOT / entry["path"]).read_bytes() for name, entry in original["materials"].items() if name != "limestone"}
    entry = pack_limestone()
    original["materials"]["limestone"] = entry
    MANIFEST.write_text(json.dumps(original, indent=2) + "\n")
    proof = {"source": {"path": str(SOURCE.relative_to(ROOT)), "sha256": sha(SOURCE), "bytes": SOURCE.stat().st_size},
        "runtime": entry,
        "unchanged_family_materials": {name: {"sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)} for name, data in others.items()},
        "new_texture_slots": 0, "same_runtime_resource_path": True,
        "rgba8_full_mip_upper_bound_bytes": sum(max(1, SIZE >> level) ** 2 * 4 for level in range(SIZE.bit_length())),
        "limitations": "Byte and image budgets are not measured GPU allocations or FPS. No normal/roughness data was fabricated."}
    for name, data in others.items():
        if data != (ROOT / original["materials"][name]["path"]).read_bytes():
            raise RuntimeError("Unrelated family texture changed: " + name)
    if OUT.stat().st_size > 1024 * 1024:
        raise RuntimeError("Single shared color tile exceeds its compressed byte budget")
    settings = ROOT / "assets/art/preview3d/limestone.webp.import"
    if "compress/mode=1" not in settings.read_text() or "mipmaps/generate=true" not in settings.read_text():
        raise RuntimeError("Existing mipmapped lossy texture import must be preserved")
    PROOF.write_text(json.dumps(proof, indent=2) + "\n")
    artifacts = [OUT, MANIFEST, PROOF]
    published = []
    token = os.environ["SJRPG_ASSET_TOKEN"]
    repository = os.environ["GITHUB_REPOSITORY"]
    if repository != "obmaz/sjrpg":
        raise RuntimeError("Unexpected output repository")
    for target in artifacts:
        data = target.read_bytes()
        req = urllib.request.Request("https://api.github.com/repos/" + repository + "/git/blobs",
            data=json.dumps({"encoding": "base64", "content": base64.b64encode(data).decode("ascii")}).encode(),
            method="POST", headers={"Authorization": "Bearer " + token, "Accept": "application/vnd.github+json", "Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=60) as response:
            blob = json.load(response)
        item = {"path": "sjrpg_3d/" + str(target.relative_to(ROOT)), "sha": blob["sha"], "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
        published.append(item)
        print("VILLAGE_LIMESTONE_BLOB " + json.dumps(item), flush=True)
    print("VILLAGE_LIMESTONE_READY " + json.dumps(proof), flush=True)
    build = ROOT / "build/town-limestone"
    build.mkdir(parents=True, exist_ok=True)
    (build / "published-blobs.json").write_text(json.dumps(published, indent=2) + "\n")
    (build / "packaging.json").write_text(json.dumps(proof, indent=2) + "\n")


if __name__ == "__main__":
    main()
