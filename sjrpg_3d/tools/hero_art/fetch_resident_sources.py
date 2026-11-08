"""Acquire one exact-license CC0 NPC candidate; preserve its reviewed source lock.

Only BaseColor images and binary glTF buffers are acquired. Upstream optional
normal/ORM aliases are not guessed or downloaded. The original glTF is retained
for hashing; an explicitly matte derivative is the only file Blender imports.
A committed resident-source-provenance.json pins all bytes on later runs.
"""
import hashlib
import json
import os
import shutil
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
CACHE = Path(os.environ.get("SJRPG_CHARACTER_SOURCE_DIR", "/tmp/sjrpg-cc0-merchant-source"))
OUT = Path(os.environ.get("SJRPG_CC0_RESIDENT_OUT", str(HERE.parents[1] / "build/cc0-resident")))
OUT.mkdir(parents=True, exist_ok=True)
plan = json.loads((HERE / "resident-source-plan.json").read_text())
original = json.loads((HERE / "source-provenance.json").read_text())
lock_path = HERE / "resident-source-provenance.json"
previous = json.loads(lock_path.read_text()) if lock_path.exists() else None
fetch_path = HERE / "fetch_sources.py"
helpers = {"__file__": str(fetch_path), "__name__": "resident_source_helpers"}
exec(compile(fetch_path.read_text().split("\noutfit = ", 1)[0], str(fetch_path), "exec"), helpers)
RangeZip = helpers["RangeZip"]
verified = {}
for path, expected in original["sourceFiles"].items():
    data = (CACHE / path).read_bytes()
    if hashlib.sha256(data).hexdigest() != expected["sha256"] or len(data) != expected["bytes"]:
        raise RuntimeError("Existing reviewed source cache changed: " + path)
    verified[path] = expected

def record(data):
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}

def safe_uri(uri):
    if not uri or uri.startswith("data:") or "/" in uri or "\\" in uri or uri in (".", ".."):
        raise RuntimeError("Unreviewed source URI: " + uri)
    return uri

for pack in plan["packs"]:
    archive = zipfile.ZipFile(RangeZip(pack["slug"], pack["upload"]))
    license_data = archive.read(pack["prefix"] + "/License_Standard.txt")
    expected_license = original["sourceFiles"][pack["license_source"]]
    if record(license_data) != expected_license or b"CC0 1.0 Universal" not in license_data:
        raise RuntimeError("Actual packaged CC0 license changed: " + pack["slug"])
    for model in pack["models"]:
        original_path = model["folder"] + model["name"]
        data = archive.read(pack["prefix"] + "/" + original_path)
        if record(data) != model["fingerprint"]:
            raise RuntimeError("Reviewed source JSON changed: " + model["name"])
        target = CACHE / model["target"]
        target.mkdir(parents=True, exist_ok=True)
        source_json = json.loads(data)
        paths = {safe_uri(buffer["uri"]) for buffer in source_json.get("buffers", [])}
        # Only colour images referenced by actual PBR materials are required.
        for material in source_json.get("materials", []):
            texture = material.get("pbrMetallicRoughness", {}).get("baseColorTexture")
            if texture is not None:
                image_index = source_json["textures"][texture["index"]]["source"]
                paths.add(safe_uri(source_json["images"][image_index]["uri"]))
        for name, binary in [(model["name"], data)]:
            key = model["target"] + "/" + name
            verified[key] = record(binary)
            (target / name).write_bytes(binary)
        for uri in sorted(paths):
            entry = archive.getinfo(pack["prefix"] + "/" + model["folder"] + uri)
            if entry.file_size > 32 * 1024 * 1024:
                raise RuntimeError("Source entry exceeds decoded budget: " + uri)
            key = model["target"] + "/" + uri
            existing = target / uri
            locked = previous["sourceFiles"].get(key) if previous else None
            if locked and existing.exists() and record(existing.read_bytes()) == locked:
                binary = existing.read_bytes()
            else:
                binary = archive.read(entry)
            actual = record(binary)
            if locked and actual != locked:
                raise RuntimeError("Pinned resident source bytes changed: " + key)
            verified[key] = actual
            existing.write_bytes(binary)
            print("CC0_RESIDENT_SOURCE " + json.dumps({"path": key, **actual}), flush=True)
        matte = json.loads(data)
        for material in matte.get("materials", []):
            material.pop("normalTexture", None)
            material.pop("occlusionTexture", None)
            pbr = material.setdefault("pbrMetallicRoughness", {})
            pbr.pop("metallicRoughnessTexture", None)
            pbr["roughnessFactor"] = 0.95
            pbr["metallicFactor"] = 0.0
        (target / (Path(model["name"]).stem + "-matte.gltf")).write_text(json.dumps(matte))
if previous and previous["sourceFiles"] != verified:
    raise RuntimeError("Resident source lock differs; explicit provenance review required")
proof = {"version": 1, "creator": "Quaternius", "sourceLicense": "CC0 1.0 Universal",
    "sources": original["sources"], "plan": plan, "sourceFiles": verified,
    "scope": "Only one selected female Ranger and matching adult female base/head; existing merchant/mage sources unchanged."}
(OUT / "resident-source-provenance.json").write_text(json.dumps(proof, indent=2) + "\n")
print("CC0_RESIDENT_SOURCE_READY " + json.dumps({"files": len(verified), "refs_changed": False,
    "new_files": {name: entry for name, entry in verified.items() if name not in original["sourceFiles"]}}), flush=True)
