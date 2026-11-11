#!/usr/bin/env python3
"""독립 몬스터 씬의 원본·라이선스·GLB 구조와 모바일 예산을 검사한다."""

import argparse
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check(kind):
    folder = ROOT / "assets/models/enemies" / kind
    spec = json.loads((folder / "asset.json").read_text())
    assert spec["kind"] == kind and spec["schema_version"] == 1
    source = ROOT / "assets/source/enemies" / kind
    proof = json.loads((source / "provenance.json").read_text())
    assert digest(source / proof["original"]) == proof["original_sha256"]
    assert digest(source / "LICENSE.txt") == proof["license_sha256"]
    assert proof["author"] == spec["author"] and proof["license"] == spec["license"]
    assert (
        spec["source_url"] == proof["source_url"]
        and spec["license_url"] == proof["license_url"]
    )
    assert (source / "source-page.html").is_file() and (
        source / "conversion.json"
    ).is_file()
    conversion = json.loads((source / "conversion.json").read_text())
    assert (
        conversion["rest_error"] < 0.0001
        and conversion["max_discarded_skin_weight"] < 0.02
    )
    assert digest(folder / "model.glb") == proof["runtime_sha256"]
    assert digest(ROOT / proof["converter"]) == proof["converter_sha256"]
    scene = (folder / "visual.tscn").read_text()
    assert "enemies/shared/visual.gd" in scene and f"enemies/{kind}/model.glb" in scene
    assert "CollisionShape3D" not in scene and "CharacterBody3D" not in scene
    data = (folder / "model.glb").read_bytes()
    magic, version, total = struct.unpack_from("<III", data)
    assert magic == 0x46546C67 and version == 2 and total == len(data)
    count = struct.unpack_from("<I", data, 12)[0]
    gltf = json.loads(data[20 : 20 + count])
    binary = data[28 + count :]
    assert gltf["asset"]["version"] == "2.0" and not gltf.get("extensionsRequired")
    assert (
        len(gltf["meshes"]) == 1
        and len(gltf["skins"]) == 1
        and 30 <= len(gltf["skins"][0]["joints"]) <= 64
    )
    assert len(gltf["materials"]) <= 4 and all(
        all(abs(v - 1) < 0.0001 for v in n.get("scale", [1, 1, 1]))
        for n in gltf["nodes"]
    )
    triangles = 0
    for mesh in gltf["meshes"]:
        for primitive in mesh["primitives"]:
            attributes = primitive["attributes"]
            assert {
                "POSITION",
                "NORMAL",
                "TEXCOORD_0",
                "JOINTS_0",
                "WEIGHTS_0",
            } <= attributes.keys()
            assert "COLOR_0" not in attributes
            triangles += gltf["accessors"][primitive["indices"]]["count"] // 3
    assert 0 < triangles < 6000
    animations = {a["name"]: a for a in gltf["animations"]}
    assert set(spec["clips"]) <= animations.keys()
    for role, clip in spec["clips"].items():
        assert clip["name"] in animations and clip["length"] > 0
    assert (
        0 < spec["clips"]["attack"]["contact_time"] < spec["clips"]["attack"]["length"]
    )
    for image in gltf["images"]:
        assert image["mimeType"] == "image/png" and "uri" not in image
        view = gltf["bufferViews"][image["bufferView"]]
        offset = view.get("byteOffset", 0)
        payload = binary[offset : offset + view["byteLength"]]
        assert payload[:8] == b"\x89PNG\r\n\x1a\n"
        width, height = struct.unpack_from(">II", payload, 16)
        assert 0 < width <= 1024 and 0 < height <= 1024
    print(
        f'ENEMY_ASSET_PASS {kind} triangles={triangles} surfaces={len(gltf["materials"])} joints={len(gltf["skins"][0]["joints"])} clips={len(animations)}'
    )


def check_all():
    for folder in sorted((ROOT / "assets/models/enemies").iterdir()):
        if (folder / "asset.json").is_file():
            check(folder.name)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--kind")
    args = parser.parse_args()
    check(args.kind) if args.kind else check_all()
