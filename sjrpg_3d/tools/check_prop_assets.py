#!/usr/bin/env python3
"""고정 소품·배우 GLB의 제작 출처, 씬, 슬롯과 임포트 정밀도를 검사한다."""

import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IDS = (
    "heroes/warrior",
    *("residents/" + name for name in ("smith", "stable", "elder", "elin", "noah", "rowen")),
    *("environment/" + name for name in (
        "encounter_stone", "treasure_chest", "waypoint", "cave_entrance", "wall_torch", "trail_sign"
    )),
    *("vegetation/" + name for name in (
        "dark_fir", "black_pine", "spire_cypress", "juniper", "thorn_bramble"
    )),
)
WRAPPERS = (
    "heroes/mage", "residents/merchant", "residents/mira", "environment/fountain",
    "environment/warp_gate", "vegetation/town_oak_0", "vegetation/town_oak_1",
)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check_all():
    for identity in IDS:
        folder = ROOT / "assets/models" / identity
        proof = json.loads((folder / "geometry.json").read_text())
        assert proof["id"] == identity and proof["units"] == "metres"
        for path, expected in proof["inputs"].items():
            assert digest(ROOT / path.removeprefix("res://")) == expected, path
        for key, name in (("model", "model.glb"), ("scene", "visual.tscn"), ("layout", "layout.tres")):
            assert digest(folder / name) == proof[key + "_sha256"], identity + "/" + name
        data = (folder / "model.glb").read_bytes()
        assert struct.unpack_from("<III", data) == (0x46546C67, 2, len(data))
        length = struct.unpack_from("<I", data, 12)[0]
        gltf = json.loads(data[20:20 + length])
        assert not gltf.get("images") and not gltf.get("animations") and not gltf.get("skins")
        triangles = 0
        for mesh in gltf["meshes"]:
            for primitive in mesh["primitives"]:
                assert {"POSITION", "NORMAL"} <= primitive["attributes"].keys()
                triangles += gltf["accessors"][primitive["indices"]]["count"] // 3
        assert triangles == proof["triangles"]
        names = [node["name"] for node in gltf["nodes"]]
        assert len(names) == len(set(names)), identity + " has renamed import nodes"
        assert all(all(abs(s - 1) < 1e-6 for s in n.get("scale", [1, 1, 1])) for n in gltf["nodes"])
        settings = (folder / "model.glb.import").read_text()
        assert "meshes/generate_lods=false" in settings, identity
        assert "meshes/force_disable_compression=true" in settings, identity
        print(f"PROP_ASSET_PASS {identity} triangles={triangles}")
    for identity in WRAPPERS:
        scene = (ROOT / "assets/models" / identity / "visual.tscn").read_text()
        assert 'type="PackedScene"' in scene and '.glb"' in scene, identity
        assert 'instance=ExtResource("model")' in scene, identity
        path = scene.split('path="', 1)[1].split('"', 1)[0]
        assert (ROOT / path.removeprefix("res://")).is_file(), path
        print(f"PROP_SCENE_PASS {identity}")


if __name__ == "__main__":
    check_all()
