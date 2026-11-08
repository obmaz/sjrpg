#!/usr/bin/env python3
"""Inspect actual Web PCK / Android APK contents and GPU texture payloads."""
import argparse
import json
from pathlib import Path
import re
import struct
import zipfile

ROOT = Path(__file__).resolve().parents[1]
# Godot4.7.2 core/io/image.h: format -> (name, bytes per4x4 block).
FORMATS = {
    17: ("DXT1",8), 18: ("DXT3",16), 19: ("DXT5",16),
    20: ("RGTC_R",8), 21: ("RGTC_RG",16), 25: ("ETC",8),
    26: ("ETC2_R11",8), 27: ("ETC2_R11S",8),
    28: ("ETC2_RG11",16), 29: ("ETC2_RG11S",16),
    30: ("ETC2_RGB8",8), 31: ("ETC2_RGBA8",16),
    32: ("ETC2_RGB8A1",8), 33: ("ETC2_RA_AS_RG",16),
    34: ("DXT5_RA_AS_RG",16),
}

def require(condition, message):
    if not condition:
        raise RuntimeError(message)

def normalized(path):
    return path.removeprefix("res://").lstrip("/")

def pck(path):
    rows = {}
    with path.open("rb") as stream:
        def integer(fmt):
            size = struct.calcsize(fmt)
            raw = stream.read(size)
            require(len(raw) == size, "Truncated PCK directory")
            return struct.unpack(fmt, raw)[0]
        require(stream.read(4) == b"GDPC", "Unexpected PCK magic")
        version = integer("<I")
        engine = [integer("<I") for _ in range(3)]
        flags, base = integer("<I"), integer("<Q")
        require(not flags & 1, "Encrypted pack cannot be inspected")
        if version in (3,4):
            stream.seek(integer("<Q"))
        elif version == 2:
            stream.seek(64,1)
        else:
            raise RuntimeError("Unsupported PCK version: " + str(version))
        count = integer("<I")
        require(0 < count < 1000000, "Invalid PCK file count")
        for _ in range(count):
            length = integer("<I")
            require(length < 16384, "Invalid PCK filename")
            name = normalized(stream.read(length).rstrip(b"\0").decode())
            offset, size = integer("<Q"), integer("<Q")
            stream.read(16)
            entry_flags = integer("<I")
            require(base + offset + size <= path.stat().st_size and not entry_flags & 1, "Invalid/encrypted PCK entry")
            require(name not in rows, "Duplicate PCK entry")
            rows[name] = (base + offset, size)
    def read(name):
        offset, size = rows[name]
        with path.open("rb") as stream:
            stream.seek(offset)
            return stream.read(size)
    return rows, read, {"pck_version":version,"engine":engine}

def ctex(data, variant):
    require(len(data) >= 52 and data[:4] == b"GST2", "Missing actual compressed texture header")
    version, logical_w, logical_h, flags = struct.unpack_from("<4I",data,4)
    kind = struct.unpack_from("<I",data,36)[0]
    width, height, mipmaps, image_format = struct.unpack_from("<HHII",data,40)
    require(version == 1 and kind == 0, "Expected raw GPU block data in CTEX")
    require(image_format in FORMATS, "Unexpected GPU compression format " + str(image_format))
    name, block_bytes = FORMATS[image_format]
    require((variant == "s3tc" and image_format in (17,18,19,20,21,34)) or
            (variant == "etc2" and 25 <= image_format <= 33), "Variant and actual image format disagree")
    require(logical_w > 0 and logical_h > 0 and width > 0 and height > 0 and mipmaps > 0 and flags & (1 << 23), "Missing dimensions/mipmaps")
    # Encoders may align the storage edge to a4px block. Logical dimensions stay original.
    require(logical_w <= width <= (logical_w + 3) // 4 * 4 and logical_h <= height <= (logical_h + 3) // 4 * 4, "Texture was unexpectedly resized")
    expected = sum(((max(1,width >> level)+3)//4)*((max(1,height >> level)+3)//4)*block_bytes for level in range(mipmaps+1))
    require(len(data)-52 == expected, "Compressed payload size disagrees with its actual dimensions/format")
    rgba8 = sum(max(1,logical_w >> level)*max(1,logical_h >> level)*4 for level in range(mipmaps+1))
    return {"logical_size":[logical_w,logical_h],"storage_size":[width,height],"mipmaps":mipmaps,
            "format":name,"gpu_block_bytes":expected,"rgba8_same_mips_estimate":rgba8}

def inspect(rows, read, platform):
    require(not any(name.startswith(("assets/source/","tests/","tools/")) for name in rows), "Build contains excluded source/test/tool assets")
    policy = json.loads((ROOT / "assets/data/texture_policy.json").read_text())
    selected = []
    for entry in policy["gpu_compressed_textures"]:
        source = entry["path"]
        metadata = (ROOT / (source + ".import")).read_text()
        variants = dict(re.findall(r'^path\.(s3tc|etc2)="res://([^"]+)"$',metadata,re.M))
        require(set(variants) == {"s3tc","etc2"}, "Godot did not generate both variants: " + source)
        expected = {"s3tc","etc2"} if platform == "web" else {"etc2"}
        record = {"path":source,"variants":{}}
        for variant, path in variants.items():
            if variant in expected:
                require(path in rows, "Export is missing its required " + variant + " texture: " + source)
                record["variants"][variant] = ctex(read(path),variant)
            else:
                require(path not in rows, "Android contains an unnecessary desktop texture variant")
        selected.append(record)
    totals = {}
    for variant in ("s3tc","etc2"):
        textures = [r["variants"][variant] for r in selected if variant in r["variants"]]
        if textures:
            totals[variant] = {"textures":len(textures),"gpu_block_bytes":sum(t["gpu_block_bytes"] for t in textures),
                               "rgba8_same_mips_estimate":sum(t["rgba8_same_mips_estimate"] for t in textures)}
    return {"platform":platform,"files":len(rows),"selected_textures":selected,"controlled_texture_budget":totals}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--web",type=Path)
    mode.add_argument("--android",type=Path)
    parser.add_argument("--package-info",type=Path)
    parser.add_argument("--out",type=Path,required=True)
    args = parser.parse_args()
    if args.web:
        rows, read, extra = pck(args.web)
        report = inspect(rows,read,"web")
        report.update(extra)
        report["download_bytes"] = args.web.stat().st_size
    else:
        require(args.package_info is not None, "Android requires actual aapt2 package metadata")
        badging = args.package_info.read_text()
        require("name='com.obmaz.sjrpg3d'" in badging, "Android package identity changed")
        minimum = re.search(r"(?m)^(?:minSdkVersion|sdkVersion):'(\d+)'",badging)
        target = re.search(r"(?m)^targetSdkVersion:'(\d+)'",badging)
        sdk_lines = [line for line in badging.splitlines() if "sdk" in line.lower()]
        require(minimum is not None and target is not None and minimum[1] == "24" and target[1] == "36",
                "Android SDK defaults disagree with Godot4.7.2: " + json.dumps(sdk_lines))
        with zipfile.ZipFile(args.android) as archive:
            names = archive.namelist()
            require("lib/arm64-v8a/libgodot_android.so" in names, "Missing actual native arm64 engine")
            require(not any(name.startswith(("lib/x86/","lib/x86_64/","lib/armeabi-v7a/")) for name in names), "Unexpected Android ABI payload")
            rows = {name.removeprefix("assets/"):None for name in names if name.startswith("assets/") and not name.endswith("/")}
            report = inspect(rows,lambda name:archive.read("assets/"+name),"android")
        report["apk_bytes"] = args.android.stat().st_size
        report["package"] = "com.obmaz.sjrpg3d"
        report["min_sdk"],report["target_sdk"],report["abi"] = 24,36,"arm64-v8a"
        report["signature"] = "apksigner verify is required by export_android.sh before this check"
    report["passed"] = True
    args.out.parent.mkdir(parents=True,exist_ok=True)
    args.out.write_text(json.dumps(report,indent=2)+"\n")
    print("PLATFORM_EXPORT_PASS "+json.dumps({k:v for k,v in report.items() if k != "selected_textures"}))

if __name__ == "__main__":
    main()
