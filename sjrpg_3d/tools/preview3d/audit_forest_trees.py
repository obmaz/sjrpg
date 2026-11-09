#!/usr/bin/env python3
"""CPU-only source audit; does not stand in for native rendered/device validation."""
import hashlib
import json
import math
from pathlib import Path
import struct

from PIL import Image

PROJECT = Path(__file__).resolve().parents[2]


def glb(path):
    raw = path.read_bytes()
    assert raw[:4] == b"glTF"
    size, kind = struct.unpack_from("<II", raw, 12)
    assert kind == 0x4E4F534A
    data = json.loads(raw[20:20 + size])
    offset = 20 + size
    binary_size, binary_kind = struct.unpack_from("<II", raw, offset)
    assert binary_kind == 0x004E4942
    binary = raw[offset + 8:offset + 8 + binary_size]
    vertices = []
    triangles = 0
    for primitive in data["meshes"][0]["primitives"]:
        accessor = data["accessors"][primitive["attributes"]["POSITION"]]
        view = data["bufferViews"][accessor["bufferView"]]
        assert accessor["componentType"] == 5126 and accessor["type"] == "VEC3"
        start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        stride = view.get("byteStride", 12)
        vertices += [struct.unpack_from("<3f", binary, start + i * stride)
                     for i in range(accessor["count"])]
        triangles += data["accessors"][primitive["indices"]]["count"] // 3
    assert all(not any(k in node for k in ("matrix", "rotation", "translation", "scale"))
               for node in data["nodes"]), "audit assumes identity authored mesh transforms"
    return vertices, triangles


def fit_error(vertices, width, top, yaw):
    # Same Y-up yaw/camera basis as Ortho3DTrees, including every crown vertex.
    s, c = math.sin(yaw), math.cos(yaw)
    turned = [(c*x + s*z, y, -s*x + c*z) for x, y, z in vertices]
    horizontal = [(x-z) / math.sqrt(2) for x, _, z in turned]
    radial = width / (max(horizontal) - min(horizontal))
    vertical = min((top + radial*(x+z)/math.sqrt(6)) / (y*math.sqrt(2/3))
                   for x, y, z in turned if y > 0.0001)
    assert radial > 0 and vertical > 0
    projected = [y*vertical*math.sqrt(2/3) - radial*(x+z)/math.sqrt(6)
                 for x, y, z in turned]
    return max(abs((max(horizontal)-min(horizontal))*radial-width),
               abs(max(projected)-top))


def main():
    recipe = json.loads((PROJECT / "assets/data/native_forest_trees.json").read_text())
    record = json.loads((PROJECT / recipe["mesh_provenance"]).read_text())
    sprites = json.loads((PROJECT / "assets/data/village.json").read_text())["sprites"]
    sources = [d for d in sprites.values() if d.get("sheet") == "forest-isometric-trees"]
    factor = 65 * math.sqrt(3/2) * .97
    maximum = 0.0
    variants = []
    for variant in record["variants"]:
        path = PROJECT / variant["path"]
        assert hashlib.sha256(path.read_bytes()).hexdigest() == variant["sha256"]
        vertices, triangles = glb(path)
        assert triangles == recipe["budget"]["triangles_per_tree"] < 5000
        for source in sources:
            k = source["world_height"] / source["height"] * .97
            width = source["source"][2] * k / factor
            top = (source["foot"][1]-source["source"][1]) * k / factor
            for step in range(16):
                maximum = max(maximum, fit_error(vertices, width, top, step*math.tau/16))
        variants.append({"mesh": variant["path"], "triangles": triangles,
                         "all_surface_vertices": len(vertices)})
    additional = json.loads((PROJECT / recipe["additional_mesh_provenance"]).read_text())
    assert hashlib.sha256((PROJECT / additional["generator"]).read_bytes()).hexdigest() == additional["generator_sha256"]
    for variant in additional["variants"]:
        assert hashlib.sha256((PROJECT / variant["path"]).read_bytes()).hexdigest() == variant["sha256"]
        assert variant["surfaces"] == 2 and 0 < variant["triangles"] < 5000
        assert not variant["authoring"]["billboard"]
    material = json.loads((PROJECT / recipe["additional_material_provenance"]).read_text())
    for path_key, hash_key in [("generator", "generator_sha256"), ("source", "source_sha256"), ("runtime", "sha256"), ("reference", "reference_sha256")]:
        assert hashlib.sha256((PROJECT / material[path_key]).read_bytes()).hexdigest() == material[hash_key]
    needles = Image.open(PROJECT / material["runtime"])
    assert needles.size == tuple(material["size"]) and needles.mode == "RGBA"
    image = Image.open(PROJECT / "assets/art/preview3d/tree-leaves.webp")
    histogram = image.getchannel("A").histogram()
    threshold = recipe["budget"]["alpha_scissor_threshold"]
    coverage = sum(histogram[math.ceil(threshold*255):]) / (image.width*image.height)
    assert coverage == recipe["budget"]["leaf_texture_alpha_coverage_at_threshold"]
    assert maximum < 1e-9
    print(json.dumps({"audit": "CPU source geometry/provenance only", "variants": variants,
                      "additional_res_hashes_verified": len(additional["variants"]),
                      "additional_res_geometry_validation": "Godot wild_vegetation_bridge and ortho_3d_trees cases",
                      "source_ids": len(sources), "yaw_samples_per_source": 16,
                      "maximum_fit_error_metres": maximum, "leaf_alpha_coverage": coverage,
                      "native_render_and_device_performance": "pending"}, indent=2))


if __name__ == "__main__":
    main()
