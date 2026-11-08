"""Inspect previously reviewed CC0 Standard archives without importing assets.

This is a source-discovery report, not permission to add a new unreviewed file.
The packaged license must match the already preserved CC0 bytes before any
model metadata is inspected. No full ZIP fallback, latest-pack substitution,
Git mutation, rig conversion or runtime replacement happens here.
"""
import hashlib
import json
import re
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[1] / "build/public-npc-source-discovery"
OUT.mkdir(parents=True, exist_ok=True)
fetch_path = HERE / "fetch_sources.py"
namespace = {"__file__": str(fetch_path), "__name__": "source_discovery_helpers"}
prefix = fetch_path.read_text().split("\noutfit = ", 1)[0]
exec(compile(prefix, str(fetch_path), "exec"), namespace)
RangeZip = namespace["RangeZip"]
reviewed = json.loads((HERE / "source-provenance.json").read_text())["sourceFiles"]
PACKS = [
    {
        "role": "outfits",
        "slug": "modular-character-outfits-fantasy",
        "upload": "16289385",
        "prefix": "Modular Character Outfits - Fantasy[Standard]",
        "license_source": "adult-source/License_Standard.txt",
        "models_folder": "Exports/glTF (Godot-Unreal)/Outfits/",
    },
    {
        "role": "base",
        "slug": "universal-base-characters",
        "upload": "15861669",
        "prefix": "Universal Base Characters[Standard]",
        "license_source": "adult-source/base/License_Standard.txt",
        "models_folder": "Base Characters/Godot - UE/",
    },
]

def fingerprint(data):
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}

reports = []
for pack in PACKS:
    print("CC0_DISCOVERY_PACK_START " + pack["role"], flush=True)
    archive = zipfile.ZipFile(RangeZip(pack["slug"], pack["upload"]))
    license_data = archive.read(pack["prefix"] + "/License_Standard.txt")
    exact = reviewed[pack["license_source"]]
    if fingerprint(license_data) != exact or b"CC0 1.0 Universal" not in license_data:
        raise RuntimeError("Packaged license changed; no candidate acquisition allowed: " + pack["role"])
    (OUT / ("LICENSE-" + pack["role"] + ".txt")).write_bytes(license_data)
    folder = pack["prefix"] + "/" + pack["models_folder"]
    models = []
    for info in sorted(archive.infolist(), key=lambda item: item.filename):
        if not info.filename.startswith(folder) or not info.filename.lower().endswith(".gltf"):
            continue
        if info.file_size > 512 * 1024:
            raise RuntimeError("Unexpected source metadata size")
        data = archive.read(info)
        gltf = json.loads(data)
        primitives = [p for mesh in gltf.get("meshes", []) for p in mesh.get("primitives", [])]
        triangle_count = sum(
            gltf["accessors"][p.get("indices", p["attributes"]["POSITION"])]["count"] // 3
            for p in primitives if p.get("mode", 4) == 4
        )
        files = []
        for item in gltf.get("buffers", []) + gltf.get("images", []):
            uri = item.get("uri", "")
            if not uri or uri.startswith("data:"):
                continue
            if "/" in uri or "\\" in uri or uri in (".", ".."):
                raise RuntimeError("Unexpected relative source URI: " + uri)
            try:
                linked = archive.getinfo(folder + uri)
            except KeyError:
                # Some upstream optional normal-map aliases are dangling. Report
                # them verbatim instead of guessing a replacement source file.
                files.append({"uri": uri, "missing_in_zip": True})
            else:
                files.append({"uri": uri, "zip_bytes": linked.file_size})
        entry = {
            "source": info.filename,
            "name": Path(info.filename).name,
            "fingerprint": fingerprint(data),
            "triangles": triangle_count,
            "primitives": len(primitives),
            "joints": sorted(len(s["joints"]) for s in gltf.get("skins", [])),
            "nodes": [node.get("name", "") for node in gltf.get("nodes", []) if "mesh" in node],
            "materials": [m.get("name", "") for m in gltf.get("materials", [])],
            "dependencies": files,
        }
        models.append(entry)
        print("CC0_DISCOVERY_MODEL " + json.dumps({"pack": pack["role"], **entry}, separators=(",", ":")), flush=True)
    report = {
        "pack": pack,
        "license": {"source": pack["license_source"], **fingerprint(license_data), "verified_exact_prior_CC0": True},
        "models": models,
        "acquisition_scope": "glTF JSON metadata and exact packaged CC0 license only; no binary model dependency imported",
        "refs_changed": False,
    }
    reports.append(report)
    print("CC0_DISCOVERY_PACK_READY " + json.dumps({"pack": pack["role"], "license": report["license"], "models": len(models)}), flush=True)
(OUT / "report.json").write_text(json.dumps(reports, indent=2) + "\n")
print("CC0_DISCOVERY_READY " + json.dumps({"reports": len(reports), "runtime_changed": False, "refs_changed": False}), flush=True)
