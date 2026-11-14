#!/usr/bin/env python3
"""건물 GLB·씬·재질 슬롯과 자산별 오프라인 제작 기록을 검사한다."""

import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IDS = ("shop", "smith", "stable", "home", "chapel", "fortress", "bridge", "market_shop", "open_smithy")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check_all():
    for identity in IDS:
        folder = ROOT / "assets/models/architecture" / identity
        spec = json.loads((folder / "asset.json").read_text())
        proof = json.loads(
            (
                ROOT / "assets/source/architecture" / identity / "model-provenance.json"
            ).read_text()
        )
        assert spec["id"] == identity and spec["modelSchemaVersion"] == 1
        assert (spec["model"], spec["scene"], spec["layout"]) == (
            "model.glb",
            "visual.tscn",
            "layout.tres",
        )
        for source in proof["inputs"]:
            assert digest(ROOT / source["path"]) == source["sha256"], source["path"]
        for output in proof["outputs"]:
            assert digest(folder / output["path"]) == output["sha256"], output["path"]
        data = (folder / "model.glb").read_bytes()
        magic, version, total = struct.unpack_from("<III", data)
        assert magic == 0x46546C67 and version == 2 and total == len(data)
        length = struct.unpack_from("<I", data, 12)[0]
        gltf = json.loads(data[20 : 20 + length])
        assert not gltf.get("skins") and not gltf.get("animations")
        assert not gltf.get("images") and not gltf.get("extensionsRequired")
        assert len(gltf["materials"]) == len(proof["materialRoles"])
        assert {m["name"].removeprefix("Material_") for m in gltf["materials"]} == set(
            proof["materialRoles"]
        )
        triangles = 0
        for mesh in gltf["meshes"]:
            for primitive in mesh["primitives"]:
                assert {"POSITION", "NORMAL", "TEXCOORD_0"} <= primitive[
                    "attributes"
                ].keys()
                triangles += gltf["accessors"][primitive["indices"]]["count"] // 3
        assert triangles == proof["triangles"]
        assert triangles < (43000 if identity == "fortress" else 30000)
        names = [node["name"] for node in gltf["nodes"]]
        assert len(names) == len(set(names))
        assert all(
            all(abs(s - 1) < 0.00001 for s in n.get("scale", [1, 1, 1]))
            for n in gltf["nodes"]
        )
        scene = (folder / "visual.tscn").read_text()
        assert f"architecture/{identity}/model.glb" in scene
        assert "architecture/shared/visual.gd" in scene
        assert "CollisionShape3D" not in scene and "StaticBody3D" not in scene
        settings = (folder / "model.glb.import").read_text()
        assert "meshes/generate_lods=false" in settings
        assert "meshes/force_disable_compression=true" in settings
        print(
            f"ARCHITECTURE_ASSET_PASS {identity} triangles={triangles} materials={len(gltf['materials'])}"
        )


if __name__ == "__main__":
    check_all()
