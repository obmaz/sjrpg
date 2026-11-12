"""Read actual exported pack and texture/mesh metadata. Never modify game assets."""
import hashlib
import json
import os
import re
import struct
import urllib.request
from collections import defaultdict
from pathlib import Path
from PIL import Image

PROJECT = Path(__file__).resolve().parents[2]
ROOT = PROJECT.parent
OUT = ROOT / "build/asset-budget"
IMAGE_EXT = {".png", ".webp", ".jpg", ".jpeg"}


def sha256_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def mip_bytes(width, height, mipmaps):
    result = width * height * 4
    if mipmaps:
        while width > 1 or height > 1:
            width, height = max(1, width // 2), max(1, height // 2)
            result += width * height * 4
    return result


def pack_entries(path):
    with path.open("rb") as stream:
        def integer(fmt):
            count = struct.calcsize(fmt)
            data = stream.read(count)
            if len(data) != count:
                raise RuntimeError("Truncated actual pack")
            return struct.unpack(fmt, data)[0]
        if stream.read(4) != b"GDPC":
            raise RuntimeError("Unexpected pack header")
        version = integer("<I")
        engine = [integer("<I") for _ in range(3)]
        flags = integer("<I")
        base = integer("<Q")
        if flags & 1:
            raise RuntimeError("Encrypted pack cannot be audited")
        if version in [3, 4]:
            stream.seek(integer("<Q"))
        elif version == 2:
            stream.seek(64, 1)
        else:
            raise RuntimeError("Unsupported actual pack format: " + str(version))
        count = integer("<I")
        if count > 1000000:
            raise RuntimeError("Invalid directory count")
        rows = []
        for _ in range(count):
            length = integer("<I")
            if length > 16384:
                raise RuntimeError("Invalid pack path length")
            name = stream.read(length).rstrip(b"\0").decode("utf-8")
            offset, size = integer("<Q"), integer("<Q")
            md5 = stream.read(16).hex()
            file_flags = integer("<I")
            if base + offset + size > path.stat().st_size:
                raise RuntimeError("Actual pack entry outside file")
            rows.append({"path": name, "bytes": size, "offset": base + offset, "md5": md5, "flags": file_flags})
        return {"format": version, "engine": engine, "flags": flags, "entries": rows}


def glb_metadata(path):
    with path.open("rb") as stream:
        magic, version, length = struct.unpack("<4sII", stream.read(12))
        chunk_size, chunk_kind = struct.unpack("<II", stream.read(8))
        if magic != b"glTF" or version != 2 or chunk_kind != 0x4e4f534a:
            return {"invalid": True}
        model = json.loads(stream.read(chunk_size))
    counts = []
    triangles = 0
    vertices = 0
    for mesh in model.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            accessors = model["accessors"]
            positions = accessors[primitive["attributes"]["POSITION"]]["count"]
            indices = accessors[primitive["indices"]]["count"] if "indices" in primitive else positions
            vertices += positions
            if primitive.get("mode", 4) == 4:
                triangles += indices // 3
            counts.append({"vertices": positions, "indices": indices, "material": primitive.get("material")})
    return {"vertices_in_primitives": vertices, "triangles": triangles, "mesh_primitives_per_instance": len(counts),
            "primitive_draws_are_not_observed_frame_draw_calls": True,
            "skins": [len(s.get("joints", [])) for s in model.get("skins", [])],
            "animations": [a.get("name", "") for a in model.get("animations", [])],
            "embedded_images": len(model.get("images", [])), "materials": len(model.get("materials", []))}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    packs = list((PROJECT / "build/web").glob("*.pck"))
    if len(packs) != 1:
        raise RuntimeError("Expected exactly one actual production pack: " + str(packs))
    pack = packs[0]
    packed = pack_entries(pack)
    rows = packed["entries"]
    by_name = {r["path"].removeprefix("res://"): r for r in rows}
    text_files = list((PROJECT / "scripts").glob("**/*.gd")) + list((PROJECT / "scenes").glob("**/*.tscn"))
    text_files += list((PROJECT / "assets/models").rglob("*.gd")) + list((PROJECT / "assets/models").rglob("*.tscn"))
    source_references = []
    for file in text_files:
        for line_number, line in enumerate(file.read_text().splitlines(), 1):
            if "res://assets/source/" in line:
                source_references.append({"path": str(file.relative_to(PROJECT)), "line": line_number, "text": line.strip()})
    images = []
    hashes = defaultdict(list)
    for file in sorted((PROJECT / "assets").rglob("*")):
        if not file.is_file() or file.suffix.lower() not in IMAGE_EXT:
            continue
        relative = str(file.relative_to(PROJECT))
        digest = sha256_file(file)
        hashes[digest].append(relative)
        with Image.open(file) as image:
            width, height = image.size
        settings_path = Path(str(file) + ".import")
        settings = settings_path.read_text() if settings_path.exists() else ""
        destinations = sorted(set(re.findall(r'"res://([^"]+\.ctex)"', settings)))
        imported = []
        for destination in destinations:
            actual = PROJECT / destination
            header = actual.read_bytes()[:36] if actual.exists() else b""
            dimensions = list(struct.unpack_from("<II", header, 8)) if header[:4] == b"GST2" else None
            imported.append({"path": destination, "disk_bytes": actual.stat().st_size if actual.exists() else None,
                             "ctex_logical_dimensions": dimensions, "packed_bytes": by_name.get(destination, {}).get("bytes", 0)})
        mips = bool(re.search(r"(?m)^mipmaps/generate=true$", settings))
        limit_match = re.search(r"(?m)^process/size_limit=(\d+)$", settings)
        limit = int(limit_match[1]) if limit_match else 0
        effective_width, effective_height = width, height
        while limit and max(effective_width, effective_height) > limit:
            effective_width, effective_height = max(1, effective_width // 2), max(1, effective_height // 2)
        row = {"path": relative, "encoded_bytes": file.stat().st_size, "sha256": digest, "source_dimensions": [width, height],
               "import_size_limit": limit, "mipmaps": mips, "rgba8_estimated_bytes_if_resident": mip_bytes(effective_width, effective_height, mips),
               "estimate_dimensions": [effective_width, effective_height], "imports": imported,
               "packed_import_bytes": sum(r["packed_bytes"] for r in imported),
               "directly_packed_bytes": by_name.get(relative, {}).get("bytes", 0),
               "ignored_ancestor": any((folder / ".gdignore").exists() for folder in [file.parent, *file.parents] if folder == PROJECT or PROJECT in folder.parents)}
        images.append(row)
    meshes = [{"path": str(file.relative_to(PROJECT)), "encoded_bytes": file.stat().st_size, "sha256": sha256_file(file), **glb_metadata(file)}
              for file in sorted(list((PROJECT / "assets/models").rglob("*.glb")))]
    source_pack = [r for r in rows if "assets/source/" in r["path"]]
    source_images_packed = [r for r in images if r["path"].startswith("assets/source/") and (r["packed_import_bytes"] or r["directly_packed_bytes"])]
    exported_images = [r for r in images if r["packed_import_bytes"] or r["directly_packed_bytes"]]
    report = {
        "commit": os.environ.get("GITHUB_SHA"), "scope": "3D actual release pack plus source metadata; no runtime behavior changed",
        "caveats": ["RGBA8 sums are a conservative if-resident budget, NOT observed simultaneous GPU residency or process memory.",
                    "Lossy WebP/CTEX file size is not decoded GPU size; meshes' primitive count is not observed frame draw calls.",
                    "Source images under .gdignore may be archived only; actual pack mappings below decide inclusion.",
                    "Static references cannot prove dynamic assets unused; no assets are deleted by this audit."],
        "pack": {"name": pack.name, "bytes": pack.stat().st_size, "sha256": sha256_file(pack), "format": packed["format"],
                 "engine": packed["engine"], "entries": len(rows), "entry_payload_bytes": sum(r["bytes"] for r in rows)},
        "summary": {"image_files": len(images), "image_encoded_bytes": sum(r["encoded_bytes"] for r in images),
                    "exported_image_files": len(exported_images), "exported_image_rgba8_if_all_resident": sum(r["rgba8_estimated_bytes_if_resident"] for r in exported_images),
                    "source_pack_entries": len(source_pack), "source_pack_bytes": sum(r["bytes"] for r in source_pack),
                    "source_image_imports_packed": len(source_images_packed),
                    "mesh_files": len(meshes), "mesh_encoded_bytes": sum(r["encoded_bytes"] for r in meshes)},
        "source_runtime_references": source_references,
        "largest_pack_entries": sorted(rows, key=lambda r: r["bytes"], reverse=True)[:80],
        "source_pack_entries": source_pack,
        "images": sorted(images, key=lambda r: r["rgba8_estimated_bytes_if_resident"], reverse=True),
        "identical_image_bytes": [{"sha256": key, "paths": values} for key, values in hashes.items() if len(values) > 1],
        "meshes": sorted(meshes, key=lambda r: r["triangles"], reverse=True),
        "all_pack_entries": rows,
    }
    report_path = OUT / "asset-budget.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print("ASSET_BUDGET_SUMMARY " + json.dumps({"pack": report["pack"], **report["summary"]}), flush=True)
    print("ASSET_BUDGET_LARGEST_PACK " + json.dumps(report["largest_pack_entries"][:15]), flush=True)
    print("ASSET_BUDGET_LARGEST_TEXTURES " + json.dumps([r for r in report["images"] if r["packed_import_bytes"]][:15]), flush=True)
    if os.environ.get("SJRPG_ASSET_TOKEN"):
        request = urllib.request.Request("https://api.github.com/repos/obmaz/sjrpg/git/blobs",
            data=json.dumps({"content": report_path.read_text(), "encoding": "utf-8"}).encode(),
            headers={"Authorization": "Bearer " + os.environ["SJRPG_ASSET_TOKEN"], "Accept": "application/vnd.github+json"},
            method="POST")
        with urllib.request.urlopen(request, timeout=90) as response:
            result = json.load(response)
        print("ASSET_BUDGET_REPORT_BLOB " + result["sha"], flush=True)


if __name__ == "__main__":
    main()
