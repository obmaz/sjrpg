#!/usr/bin/env python3
"""Give an exported Godot pack an immutable URL without duplicating its payload."""

import argparse
import hashlib
import json
from pathlib import Path
import re


PACK_NAME = re.compile(r"index-[0-9a-f]{20}\.pck\Z")
CONFIG_START = re.compile(r"\bconst\s+GODOT_CONFIG\s*=\s*")
BUILD_MARKER = re.compile(r'\n[ \t]*window\.__sjrpgBuild = "[0-9a-f]{64}"; // web-pack-stamp\n?')


def read_config(html):
    """Decode the actual JSON object, including nested or multiline fileSizes."""
    match = CONFIG_START.search(html)
    if match is None:
        raise ValueError("export has no GODOT_CONFIG JSON assignment")
    config, length = json.JSONDecoder().raw_decode(html[match.end():])
    end = match.end() + length
    if not isinstance(config, dict) or not html[end:].lstrip().startswith(";"):
        raise ValueError("GODOT_CONFIG must be a JSON object followed by a semicolon")
    return config, match.end(), end


def digest(path):
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(chunk)
    return result.hexdigest()


def stamp(directory):
    directory = Path(directory)
    index = directory / "index.html"
    html = BUILD_MARKER.sub("\n", index.read_text(encoding="utf-8"))
    config, start, end = read_config(html)
    if config.get("executable") != "index":
        raise ValueError("expected the index executable produced by export_web.sh")
    old_pack = config.get("mainPack") or "index.pck"
    if old_pack != "index.pck" and PACK_NAME.fullmatch(old_pack) is None:
        raise ValueError("refusing an unexpected mainPack path")
    # A fresh engine export produces index.pck; a rerun uses the stamped pack.
    source = directory / "index.pck"
    if not source.is_file():
        source = directory / old_pack
    if not source.is_file() or source.stat().st_size == 0:
        raise ValueError("exported game pack is missing or empty")
    sha256 = digest(source)
    name = "index-" + sha256[:20] + ".pck"
    target = directory / name
    if target.is_file() and target != source and digest(target) != sha256:
        raise ValueError("content-hash filename collision")
    sizes = config.get("fileSizes")
    if not isinstance(sizes, dict):
        raise ValueError("export has no Godot fileSizes metadata")
    sizes = {key: value for key, value in sizes.items()
             if key != "index.pck" and PACK_NAME.fullmatch(key) is None}
    sizes[name] = source.stat().st_size
    config["mainPack"] = name
    config["fileSizes"] = sizes
    encoded = json.dumps(config, separators=(",", ":"), ensure_ascii=False)
    html = html[:start] + encoded + html[end:]
    # Keep the marker adjacent to configuration, before Engine construction.
    _, _, end = read_config(html)
    semicolon = html.index(";", end)
    html = html[:semicolon + 1] + '\n    window.__sjrpgBuild = "' + sha256 + '"; // web-pack-stamp\n' + html[semicolon + 1:].lstrip("\n")
    temporary = directory / ".index-stamped.html"
    temporary.write_text(html, encoding="utf-8")
    if source != target:
        source.replace(target)
    temporary.replace(index)
    # The independent2D build has no alternate3D entry document.
    for obsolete in ("3d.html", ".3d-stamped.html"):
        (directory / obsolete).unlink(missing_ok=True)
    # Delete only this helper's obsolete generated pack names, never other packs.
    for candidate in directory.iterdir():
        if candidate.is_file() and PACK_NAME.fullmatch(candidate.name) and candidate.name != name:
            candidate.unlink()
    return {"main_pack": name, "sha256": sha256, "bytes": sizes[name]}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    options = parser.parse_args()
    print(stamp(options.directory)["main_pack"])
