#!/usr/bin/env python3
"""Pack generated entry artwork without changing composition or alpha."""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/source/entry-redesign"
TARGET = ROOT / "assets/art/entry"


def main():
    TARGET.mkdir(parents=True, exist_ok=True)
    report = {}
    for name in ("start-background", "warrior", "mage"):
        source = SOURCE / f"{name}.png"
        target = TARGET / f"{name}.webp"
        image = Image.open(source)
        image.save(target, "WEBP", quality=90, method=6, exact=True)
        report[name] = {
            "source": str(source.relative_to(ROOT)),
            "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
            "runtime": str(target.relative_to(ROOT)),
            "runtime_sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
            "size": list(image.size),
            "mode": image.mode,
            "runtime_bytes": target.stat().st_size,
        }
    # Downloading and ready-to-start use this same image, before Godot loads.
    (ROOT / "web/loading-bg.webp").write_bytes((TARGET / "start-background.webp").read_bytes())
    (SOURCE / "packing.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()
