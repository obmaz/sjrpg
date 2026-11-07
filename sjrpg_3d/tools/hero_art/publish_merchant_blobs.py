"""Verify exact CC0 inputs and publish candidate blobs only; never move refs."""
import base64
import hashlib
import json
import os
import re
import shutil
import struct
import subprocess
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[2]
OUT = Path(os.environ.get("SJRPG_CC0_MERCHANT_OUT", str(PROJECT / "build/cc0-merchant"))).resolve()
CACHE = Path(os.environ.get("SJRPG_CHARACTER_SOURCE_DIR", "/tmp/sjrpg-cc0-merchant-source"))
EXPECTED = json.loads(Path(__file__).with_name("source-provenance.json").read_text())["sourceFiles"]
LICENSES = {
    "LICENSE-Outfits.txt": "adult-source/License_Standard.txt",
    "LICENSE-Base.txt": "adult-source/base/License_Standard.txt",
    "LICENSE-Animations.txt": "adult-source/Animation-License.txt",
}

def sha256(data):
    return hashlib.sha256(data).hexdigest()

def main():
    verified = {}
    for relative, expected in EXPECTED.items():
        data = (CACHE / relative).read_bytes()
        if len(data) != expected["bytes"] or sha256(data) != expected["sha256"]:
            raise RuntimeError("Reviewed source bytes changed: " + relative)
        verified[relative] = {"bytes": len(data), "sha256": sha256(data)}
    for output, source in LICENSES.items():
        data = (OUT / output).read_bytes()
        if data != (CACHE / source).read_bytes() or b"CC0 1.0 Universal" not in data:
            raise RuntimeError("Missing exact CC0 license: " + output)

    binary = (OUT / "merchant.glb").read_bytes()
    magic, version, length = struct.unpack_from("<4sII", binary)
    if magic != b"glTF" or version != 2 or length != len(binary) or len(binary) > 12 * 1024 * 1024:
        raise RuntimeError("Invalid or oversized merchant GLB")
    json_length, json_type = struct.unpack_from("<II", binary, 12)
    if json_type != 0x4E4F534A:
        raise RuntimeError("GLB JSON chunk missing")
    gltf = json.loads(binary[20:20 + json_length])
    if not gltf.get("skins") or not any(a.get("name") == "idle" for a in gltf.get("animations", [])):
        raise RuntimeError("Merchant must retain its skin and idle animation")
    if "KHR_draco_mesh_compression" in gltf.get("extensionsRequired", []):
        raise RuntimeError("Plain accessor geometry is required; Draco is not a runtime dependency")
    if gltf.get("cameras") or any("uri" in b for b in gltf.get("buffers", [])) or any("uri" in i for i in gltf.get("images", [])):
        raise RuntimeError("Candidate must be self-contained and contain no cameras")
    triangles = 0
    for mesh in gltf["meshes"]:
        for primitive in mesh["primitives"]:
            if primitive.get("mode", 4) != 4:
                raise RuntimeError("Expected triangle geometry")
            accessor = primitive.get("indices", primitive["attributes"]["POSITION"])
            triangles += gltf["accessors"][accessor]["count"] // 3
    if not 0 < triangles <= 18000:
        raise RuntimeError("Merchant triangle budget exceeded: " + str(triangles))
    if max(len(s["joints"]) for s in gltf["skins"]) > 80:
        raise RuntimeError("Merchant joint budget exceeded")

    # Same res:// path as production; this minimal project has no gameplay scripts.
    mirror = OUT / "godot-import"
    runtime = mirror / "assets/art/native_residents"
    runtime.mkdir(parents=True, exist_ok=True)
    shutil.copy2(OUT / "merchant.glb", runtime / "merchant.glb")
    (mirror / "project.godot").write_text('[application]\nconfig/name="CC0 merchant import"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\nrenderer/rendering_method.mobile="gl_compatibility"\n')
    command = [str(PROJECT / "tools/godot.sh"), "--headless", "--editor", "--path", str(mirror), "--import"]
    subprocess.run(command, check=True)
    textures = sorted(runtime.glob("*.png"))
    for texture in textures:
        settings = texture.with_name(texture.name + ".import")
        content = settings.read_text()
        content, count = re.subn(r"(?m)^compress/mode=\d+$", "compress/mode=1", content)
        if count != 1:
            raise RuntimeError("Texture compression setting missing: " + texture.name)
        settings.write_text(content)
    if textures:
        subprocess.run(command, check=True)

    proof = json.loads((OUT / "provenance.json").read_text())
    proof["acquisition_verification"] = {
        "verified_at_utc": datetime.now(timezone.utc).isoformat(),
        "source_manifest": "sjrpg_3d/tools/hero_art/source-provenance.json",
        "verified_files": verified,
        "exact_license_files": {name: verified[source] for name, source in LICENSES.items()},
        "runtime_glb_sha256": sha256(binary),
        "runtime_glb_bytes": len(binary),
        "actual_gltf_triangles": triangles,
        "commercial_use_and_modification": "CC0 1.0 Universal; exact packaged license files verified",
        "import": "Godot pinned version, same resource paths; extracted PNG imports use lossy mode 1",
    }
    (OUT / "provenance.json").write_text(json.dumps(proof, indent=2) + "\n")
    artifacts = {}
    for file in sorted(runtime.iterdir()):
        if not file.is_file() or not (file.name == "merchant.glb" or file.name == "merchant.glb.import" or file.name.endswith((".png", ".png.import"))):
            continue
        artifacts["sjrpg_3d/assets/art/native_residents/" + file.name] = file
    if "sjrpg_3d/assets/art/native_residents/merchant.glb.import" not in artifacts:
        raise RuntimeError("Actual Godot import metadata missing")
    for name in ["provenance.json", *LICENSES]:
        artifacts["sjrpg_3d/assets/source/native-residents/merchant/" + name] = OUT / name

    repository = os.environ.get("GITHUB_REPOSITORY", "")
    if repository != "obmaz/sjrpg":
        raise RuntimeError("Unexpected output repository")
    token = os.environ["SJRPG_ASSET_TOKEN"]
    published = []
    for path, file in artifacts.items():
        data = file.read_bytes()
        request = urllib.request.Request(
            "https://api.github.com/repos/" + repository + "/git/blobs",
            data=json.dumps({"content": base64.b64encode(data).decode("ascii"), "encoding": "base64"}).encode(),
            headers={"Authorization": "Bearer " + token, "Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"},
            method="POST",
        )
        with urllib.request.urlopen(request, timeout=60) as response:
            result = json.load(response)
        sha = result["sha"]
        if not re.fullmatch("[0-9a-f]{40}", sha):
            raise RuntimeError("Invalid blob response")
        record = {"path": path, "sha": sha, "bytes": len(data), "sha256": sha256(data)}
        published.append(record)
        print("CC0_MERCHANT_BLOB " + json.dumps(record), flush=True)
    (OUT / "published-blobs.json").write_text(json.dumps(published, indent=2) + "\n")
    print("CC0_MERCHANT_SOURCE_VERIFIED " + json.dumps(proof["acquisition_verification"]), flush=True)
    print("CC0_MERCHANT_CANDIDATE_READY " + json.dumps({"blobs": len(published), "triangles": triangles, "refs_changed": False}), flush=True)

if __name__ == "__main__":
    main()
