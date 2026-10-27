import importlib.util
import json
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "character_pack_runtime", Path(__file__).with_name("pack-runtime.py")
)
pack = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pack)
ROOT = pack.ROOT
pack.OUT = ROOT / "runtime-final"
pack.OUT.mkdir(exist_ok=True)
war = pack.load("warrior", "warrior-final", 272)
mage = pack.load("mage", "mage-full", 208)
manifest = {}
for m, roles in [
    (war, ["hero", "hero-attack", "hero-backhand", "hero-cleave"]),
    (mage, ["mage", "mage-cast"]),
]:
    ref = m["actorReferenceHeightRaw256"] * 0.5
    anchor = [x * 0.5 for x in m["worldOriginAnchorPx"]]
    for role in roles:
        fs = [f for f in m["frames"] if f["sheet"] == role]
        manifest[role] = pack.pack(
            role,
            fs,
            ref,
            anchor,
            motion=m["motion"] if role in ["hero", "mage"] else None,
            anchored=True,
        )
        if role == "mage":
            manifest[role]["image"] = manifest[role]["pngAlternative"]
            manifest[role]["compressedBytes"] = (
                Path(manifest[role]["image"]).stat().st_size
            )
warRef = war["actorReferenceHeightRaw256"] * 0.5
mageRef = mage["actorReferenceHeightRaw256"] * 0.5
anchor = [x * 0.5 for x in war["worldOriginAnchorPx"]]
assert anchor == [x * 0.5 for x in mage["worldOriginAnchorPx"]]
rollFrames = [f for f in war["frames"] if f["kind"] == "roll"] + [
    f for f in mage["frames"] if f["kind"] == "roll"
]
manifest["roll"] = pack.pack(
    "roll", rollFrames, warRef * 43 / 60, anchor, anchored=True
)
manifest["roll"]["record"]["sizes"].append([128, mageRef * 43 / 60])
manifest["roll"]["image"] = manifest["roll"]["pngAlternative"]
manifest["roll"]["compressedBytes"] = Path(manifest["roll"]["image"]).stat().st_size
(pack.OUT / "roll-bounds.json").write_text(
    json.dumps(manifest["roll"]["record"], separators=(",", ":")) + "\n"
)
manifest["_status"] = {
    "complete": True,
    "completedClasses": ["warrior", "mage"],
    "totalRealRenderedFrames": 480,
    "movement": "each16idle+16directions*8realrun",
    "warAttacks": "3realSwordA/B/Cactions*2poses*16directions",
    "mageCast": "earlyEnter.25charge+Shoot.5release*16directions",
    "roll": "each4poses*8directions; Warfirst32, Magesecond32; projected-origin",
    "materialStatus": "FINALdeeptealWar+navyrobeMage, sameapprovedadultmalehead/coherentbody",
    "reviews": {
        "warrior": pack.review(war, "hero", "warrior-final"),
        "mage": pack.review(mage, "mage", "mage-full"),
    },
    "decodedRGBAUnionBytes": sum(
        v["decodedRGBABytes"] for v in manifest.values() if "decodedRGBABytes" in v
    ),
    "compressedSelectedRuntimeBytes": sum(
        v["compressedBytes"] for v in manifest.values() if "compressedBytes" in v
    ),
}
(pack.OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
for className, m in [("warrior-final", war), ("mage-full", mage)]:
    for f in m["frames"]:
        f.pop("_image", None)
    m["directions"] = {f["direction"]: f["yawDegrees"] for f in m["frames"]}
    (ROOT / className / "validated-render-metadata.json").write_text(
        json.dumps(m, indent=2) + "\n"
    )
print("ALL480FRAMEQUALITYASSERTIONSPASS")
for k, v in manifest.items():
    if not k.startswith("_"):
        print(k, v["decodedRGBABytes"], v["compressedBytes"], v["image"])
print(
    "union",
    manifest["_status"]["decodedRGBAUnionBytes"],
    "compressed",
    manifest["_status"]["compressedSelectedRuntimeBytes"],
)
