"""Pack approved selection PNGs with cwebp; publish blobs only, never refs.
Python handles checksums, container inspection and metadata; it never edits pixels.
"""
import base64
import hashlib
import json
import os
import re
import shutil
import struct
import subprocess
import urllib.request
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[3]
ROOT = PROJECT.parent
SOURCE = PROJECT / "assets/source/entry-redesign"
OUT = ROOT / "build/selection-art"
EXPECTED = {
    "warrior.png": "6503418f33ed3db1abdcf95dc01a4b05a71801ef",
    "mage.png": "0205987e6a80e8f34a58f11cb8bcef5f59640ad6",
    "forest.png": "56245873cdaf8956cca04b30493bea6a2278a6a3",
    "selection-and-continue-concept.png": "9abecb1e6545f31a743a7062234c6c613c3aa9c5",
}
PROMPT_BLOB = "18a56974b93a4f59d2b10ae4d8855129a3ae16ae"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def git_blob(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def png_size(data):
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise RuntimeError("Expected actual PNG source")
    return list(struct.unpack(">II", data[16:24]))


def webp_size(data):
    if data[:4] != b"RIFF" or data[8:12] != b"WEBP":
        raise RuntimeError("Expected actual WebP output")
    position = 12
    while position + 8 <= len(data):
        kind = data[position:position + 4]
        size = struct.unpack_from("<I", data, position + 4)[0]
        payload = data[position + 8:position + 8 + size]
        if kind == b"VP8X":
            return [int.from_bytes(payload[4:7], "little") + 1, int.from_bytes(payload[7:10], "little") + 1]
        if kind == b"VP8 " and payload[3:6] == b"\x9d\x01\x2a":
            return [struct.unpack_from("<H", payload, 6)[0] & 0x3fff, struct.unpack_from("<H", payload, 8)[0] & 0x3fff]
        position += 8 + size + (size & 1)
    raise RuntimeError("WebP dimensions missing")


def publish(path, file):
    data = file.read_bytes()
    repository = os.environ["GITHUB_REPOSITORY"]
    if repository != "obmaz/sjrpg":
        raise RuntimeError("Unexpected output repository")
    request = urllib.request.Request(
        "https://api.github.com/repos/" + repository + "/git/blobs",
        data=json.dumps({"content": base64.b64encode(data).decode("ascii"), "encoding": "base64"}).encode(),
        headers={"Authorization": "Bearer " + os.environ["SJRPG_ASSET_TOKEN"], "Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=90) as response:
        result = json.load(response)
    record = {"path": path, "sha": result["sha"], "bytes": len(data), "sha256": digest(data)}
    if record["sha"] != git_blob(data):
        raise RuntimeError("Published blob identity mismatch")
    print("SELECTION_ART_BLOB " + json.dumps(record), flush=True)
    return record



def print_review_image(name, file):
    data = file.read_bytes()
    encoded = base64.b64encode(data).decode("ascii")
    chunks = [encoded[index:index + 12000] for index in range(0, len(encoded), 12000)]
    print("SJ_SELECT_IMAGE_BEGIN " + json.dumps({"name": name, "mime": "image/webp", "bytes": len(data), "sha256": digest(data), "chunks": len(chunks)}), flush=True)
    for index, chunk in enumerate(chunks):
        print("SJ_SELECT_IMAGE_CHUNK " + json.dumps({"name": name, "index": index, "data": chunk}), flush=True)
    print("SJ_SELECT_IMAGE_END " + json.dumps({"name": name, "sha256": digest(data)}), flush=True)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sources = {}
    for name, expected in EXPECTED.items():
        data = (SOURCE / name).read_bytes()
        if git_blob(data) != expected:
            raise RuntimeError("Unreviewed source replacement: " + name)
        sources[name] = {"git_blob": expected, "sha256": digest(data), "bytes": len(data), "dimensions": png_size(data)}
    previews = OUT / "previews"
    previews.mkdir(exist_ok=True)
    for label, original in [("concept", "selection-and-continue-concept.png"), ("warrior", "warrior.png"), ("mage", "mage.png")]:
        preview = previews / (label + ".webp")
        subprocess.run(["cwebp", "-q", "80", "-m", "6", "-mt", "-metadata", "none", str(SOURCE / original), "-o", str(preview)], check=True)
        if webp_size(preview.read_bytes()) != sources[original]["dimensions"]:
            raise RuntimeError("Review transport must preserve complete original")
        print_review_image(label, preview)
    prompt_bytes = (SOURCE / "selection-generation.json").read_bytes()
    if git_blob(prompt_bytes) != PROMPT_BLOB:
        raise RuntimeError("Exact generation prompt record changed")
    prompts = json.loads(prompt_bytes)
    mirror = OUT / "godot-import"
    runtime = mirror / "assets/ui/entry"
    runtime.mkdir(parents=True, exist_ok=True)
    (mirror / "project.godot").write_text('[application]\nconfig/name="Selection art packing"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\nrenderer/rendering_method.mobile="gl_compatibility"\n')
    production = {}
    for role in ["warrior", "mage", "forest"]:
        name = "selection-" + role + ".webp"
        destination = runtime / name
        command = ["cwebp", "-q", "88", "-m", "6", "-mt", "-metadata", "none", str(SOURCE / (role + ".png")), "-o", str(destination)]
        subprocess.run(command, check=True)
        data = destination.read_bytes()
        dimensions = webp_size(data)
        if dimensions != sources[role + ".png"]["dimensions"]:
            raise RuntimeError("Packing must preserve full source dimensions")
        production[name] = {"source": role + ".png", "sha256": digest(data), "bytes": len(data), "dimensions": dimensions,
                            "packing": "cwebp -q 88 -m 6 -mt -metadata none; no crop, resize or pixel editing"}
    import_command = [str(PROJECT / "tools/godot.sh"), "--headless", "--editor", "--path", str(mirror), "--import"]
    for pass_number in range(2):
        result = subprocess.run(import_command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        (OUT / ("godot-import-" + str(pass_number + 1) + ".log")).write_text(result.stdout)
        if result.returncode or re.search(r"(^|\n)(ERROR:|SCRIPT ERROR:)", result.stdout):
            raise RuntimeError("Pinned Godot import failed: " + result.stdout[-6000:])
        if pass_number == 0:
            for name in production:
                metadata = runtime / (name + ".import")
                text = metadata.read_text()
                text, count = re.subn(r"(?m)^compress/mode=\d+$", "compress/mode=1", text)
                if count != 1:
                    raise RuntimeError("Missing actual Godot texture import setting")
                metadata.write_text(text)
    for name, details in production.items():
        metadata = runtime / (name + ".import")
        content = metadata.read_text()
        if "compress/mode=1" not in content or 'source_file="res://assets/ui/entry/' + name + '"' not in content:
            raise RuntimeError("Godot import resource path mismatch")
        details["import_metadata_sha256"] = digest(metadata.read_bytes())
    manifest = {
        "source_commit": "12240d247534c003bd2f856bca49dd5206a14dff",
        "worker_commit": os.environ.get("GITHUB_SHA"),
        "engine": (ROOT / ".godot-version").read_text().strip(),
        "cwebp_version": subprocess.check_output(["cwebp", "-version"], text=True).strip(),
        "sources": sources, "production": production,
        "prompt_record": {"path": "selection-generation.json", "git_blob": PROMPT_BLOB, "sha256": digest(prompt_bytes), "bytes": len(prompt_bytes), "record": prompts},
        "scope": "Three new selection-family textures only; concept retained as provenance, never a baked interactive UI",
        "pixel_edits": False, "refs_changed": False,
    }
    manifest_path = OUT / "selection-packing.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    files = [("sjrpg_3d/assets/ui/entry/" + file.name, file) for file in sorted(runtime.iterdir()) if file.is_file()]
    files.append(("sjrpg_3d/assets/source/entry-redesign/selection-packing.json", manifest_path))
    published = [publish(path, file) for path, file in files]
    (OUT / "published-blobs.json").write_text(json.dumps(published, indent=2) + "\n")
    print("SELECTION_ART_READY " + json.dumps({"blobs": len(published), "refs_changed": False}), flush=True)


if __name__ == "__main__":
    main()
