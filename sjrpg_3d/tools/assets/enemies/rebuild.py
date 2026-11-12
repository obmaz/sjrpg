"""보존한 원본과 잠금 해시로 몬스터 GLB를 다시 만든다. 네트워크를 사용하지 않는다."""

import argparse
import hashlib
import json
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument(
    "--kind",
    choices=["goblin", "wolf", "boar", "skeleton", "golem", "cave_crawler"],
    required=True,
)
args = parser.parse_args()
if args.kind not in ["goblin", "wolf"]:
    command = [
        "blender",
        "-b",
        "--python-exit-code",
        "1",
        "--python",
        str(Path(__file__).with_name("export_remaining.py")),
        "--",
        "--kind",
        args.kind,
    ]
    if args.kind == "skeleton":
        import os

        converter = os.environ.get("SJRPG_FBX2GLTF")
        if not converter:
            parser.error(
                "스켈레톤 원본 ASCII FBX 변환용 SJRPG_FBX2GLTF 경로가 필요합니다. 몬스터 문서의 고정 버전/해시를 확인하세요."
            )
        command += ["--fbx2gltf", converter]
    subprocess.run(command, check=True)
    raise SystemExit(0)
source = ROOT / "assets/source/enemies" / args.kind
proof = json.loads((source / "provenance.json").read_text())
original = source / proof["original"]
assert hashlib.sha256(original.read_bytes()).hexdigest() == proof["original_sha256"]
payload = original
if args.kind == "wolf":
    cache = ROOT / "build/enemy-source/wolf"
    cache.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(original) as archive:
        for name in ["source/loup.fbx", "textures/wolf_Tex.png"]:
            path = cache / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(archive.read(name))
    payload = cache / "source/loup.fbx"
assert hashlib.sha256(payload.read_bytes()).hexdigest() == proof["payload_sha256"]
subprocess.run(
    [
        "blender",
        "-b",
        "--python-exit-code",
        "1",
        "--python",
        str(Path(__file__).with_name("export_enemy.py")),
        "--",
        "--kind",
        args.kind,
        "--source",
        str(payload),
        "--output",
        str(ROOT / "assets/models/enemies" / args.kind / "model.glb"),
    ],
    check=True,
)
print(
    "검수 후 conversion.json과 런타임 해시를 갱신하세요. 원본 잠금은 변경하지 않습니다."
)
