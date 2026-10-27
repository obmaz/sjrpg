"""Fetch only reviewed free CC0 source entries; refuse full ZIP fallback."""

import hashlib
import io
import json
import os
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(os.environ.get("SJRPG_CHARACTER_SOURCE_DIR", "/tmp/sjrpg-character-source"))
PROVENANCE = (
    Path(__file__).resolve().parents[2] / "docs/art/character-motion-provenance.json"
)
EXPECTED = json.loads(PROVENANCE.read_text())["sourceFiles"]


class RangeZip(io.RawIOBase):
    def __init__(self, slug, upload):
        endpoint = (
            f"https://quaternius.itch.io/{slug}/file/{upload}?source=game_download"
        )
        response = urllib.request.urlopen(endpoint, data=b"", timeout=30)
        self.url = json.load(response)["url"]
        self.position = 0
        response = self.request(0, 1)
        self.size = int(response.headers["Content-Range"].split("/")[-1])
        response.read()

    def request(self, start, length):
        request = urllib.request.Request(
            self.url, headers={"Range": f"bytes={start}-{start + length - 1}"}
        )
        response = urllib.request.urlopen(request, timeout=45)
        if response.status != 206:
            response.close()
            raise RuntimeError("Range unsupported; refused full source ZIP download")
        return response

    def seekable(self):
        return True

    def readable(self):
        return True

    def seek(self, offset, whence=0):
        self.position = (
            offset
            if whence == 0
            else self.position + offset
            if whence == 1
            else self.size + offset
        )
        return self.position

    def tell(self):
        return self.position

    def read(self, length=-1):
        if length < 0:
            length = self.size - self.position
        if not length:
            return b""
        if length > 16 * 1024 * 1024:
            raise ValueError("Source entry exceeds reviewed range budget")
        data = self.request(self.position, length).read()
        self.position += len(data)
        return data


def extract(slug, upload, prefix, entries):
    missing = []
    for source, target in entries:
        path = ROOT / target
        expected = EXPECTED[target]["sha256"]
        if (
            not path.exists()
            or hashlib.sha256(path.read_bytes()).hexdigest() != expected
        ):
            missing.append((source, target))
    if not missing:
        return
    archive = zipfile.ZipFile(RangeZip(slug, upload))
    for source, target in missing:
        info = archive.getinfo(prefix + "/" + source)
        if info.file_size > 32 * 1024 * 1024:
            raise ValueError("Source entry exceeds reviewed decoded budget")
        data = archive.read(info)
        if hashlib.sha256(data).hexdigest() != EXPECTED[target]["sha256"]:
            raise ValueError(
                "Official source changed; review provenance before updating hashes"
            )
        path = ROOT / target
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        print("Verified", target, len(data))


outfit = "Modular Character Outfits - Fantasy[Standard]"
folder = "Exports/glTF (Godot-Unreal)/Outfits/"
entries = [
    (folder + name, "adult-source/" + name)
    for name in [
        "Male_Ranger.gltf",
        "Male_Ranger.bin",
        "T_Ranger_BaseColor.png",
        "T_Regular_Male_Dark_BaseColor.png",
    ]
]
entries += [
    (folder + name, "adult-source/mage/" + name)
    for name in [
        "Male_Peasant.gltf",
        "Male_Peasant.bin",
        "T_Peasant_BaseColor.png",
        "T_Regular_Male_Dark_BaseColor.png",
    ]
]
entries += [
    ("License_Standard.txt", "adult-source/License_Standard.txt"),
    ("Readme.txt", "adult-source/Readme.txt"),
]
extract("modular-character-outfits-fantasy", "16289385", outfit, entries)
base = "Universal Base Characters[Standard]"
base_id = next(
    pack["itchUploadID"]
    for pack in json.loads(PROVENANCE.read_text())["sources"]
    if pack["pack"] == "Universal Base Characters Standard"
)
entries = [
    ("Base Characters/Godot - UE/" + name, "adult-source/base/" + name)
    for name in [
        "Superhero_Male_FullBody.gltf",
        "Superhero_Male_FullBody.bin",
        "T_Hair_1_BaseColor.png",
        "T_Eye_Brown.png",
        "T_Superhero_Male_Dark.png",
    ]
]
extract(
    "universal-base-characters",
    base_id,
    base,
    entries + [("License_Standard.txt", "adult-source/base/License_Standard.txt")],
)
extract(
    "universal-animation-library",
    "17958403",
    "Universal Animation Library[Standard]",
    [
        ("Unreal-Godot/UAL1_Standard.glb", "adult-source/UAL1_Standard.glb"),
        ("License.txt", "adult-source/Animation-License.txt"),
        ("README.txt", "adult-source/Animation-README.txt"),
    ],
)
extract(
    "universal-animation-library-2",
    "17958478",
    "Universal Animation Library 2[Standard]",
    [
        ("Unreal-Godot/UAL2_Standard.glb", "adult-source/UAL2_Standard.glb"),
        ("License.txt", "adult-source/UAL2-License.txt"),
    ],
)
for original, derived in [
    ("adult-source/Male_Ranger.gltf", "adult-source/Male_Ranger-matte.gltf"),
    (
        "adult-source/mage/Male_Peasant.gltf",
        "adult-source/mage/Male_Peasant-matte.gltf",
    ),
    (
        "adult-source/base/Superhero_Male_FullBody.gltf",
        "adult-source/base/Superhero_Male-matte.gltf",
    ),
]:
    data = json.loads((ROOT / original).read_text())
    for material in data["materials"]:
        material.pop("normalTexture", None)
        material.pop("occlusionTexture", None)
        pbr = material.setdefault("pbrMetallicRoughness", {})
        pbr.pop("metallicRoughnessTexture", None)
        pbr["roughnessFactor"] = 0.95
        pbr["metallicFactor"] = 0
    (ROOT / derived).write_text(json.dumps(data))
print("Verified source cache ready:", ROOT)
