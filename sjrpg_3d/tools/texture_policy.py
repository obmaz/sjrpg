#!/usr/bin/env python3
"""Enforce the 3D texture import policy without opening source image files.

Only [params] values in assets/art/ and assets/models/ import metadata can be written. Godot owns
the generated [remap]/[deps] compressed artifacts after the next import.
"""
import argparse
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
POLICY = ROOT / "assets/data/texture_policy.json"
EXPECTED_GPU = {
    "compress/mode": "2",
    "compress/high_quality": "false",
    "mipmaps/generate": "true",
    "process/size_limit": "0",
    "detect_3d/compress_to": "0",
}
EXPECTED_PROTECTED = {"compress/mode": "1", "detect_3d/compress_to": "0"}
SECTION = re.compile(r"(?m)^\[([^]\r\n]+)\][ \t]*$")
SETTING = re.compile(r"(?m)^([^;#\s][^=\r\n]*)=([^\r\n]*)$")


def sections(text, label):
    matches = list(SECTION.finditer(text))
    result = {}
    for index, match in enumerate(matches):
        name = match.group(1)
        if name in result:
            raise ValueError(f"{label}: duplicate section {name}")
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        result[name] = (match.end(), end)
    return result


def values(text, span, label):
    result = {}
    for match in SETTING.finditer(text, *span):
        key = match.group(1).strip()
        if key in result:
            raise ValueError(f"{label}: duplicate setting {key}")
        result[key] = match.group(2).strip()
    return result


def resource_path(relative):
    path = Path(relative)
    roots = ("assets/art/", "assets/models/")
    if path.is_absolute() or ".." in path.parts or not relative.startswith(roots):
        raise ValueError("Policy path is outside 3D art/model assets: " + relative)
    allowed = any((ROOT / path).resolve().is_relative_to((ROOT / part).resolve()) for part in roots)
    if not allowed:
        raise ValueError("Policy path escapes 3D assets: " + relative)
    return path


def load_policy():
    policy = json.loads(POLICY.read_text())
    if policy.get("version") != 1:
        raise ValueError("Unsupported texture policy version")
    if policy.get("gpu_compressed_settings") != EXPECTED_GPU or policy.get("protected_settings") != EXPECTED_PROTECTED:
        raise ValueError("Texture settings must use the reviewed GPU/protected contract")
    selected = {}
    for entry in policy["gpu_compressed_textures"]:
        relative = entry["path"]
        resource_path(relative)
        if relative in selected:
            raise ValueError("Duplicate texture policy path: " + relative)
        selected[relative] = entry["usage"]
    if len(selected) != 24:
        raise ValueError("The reviewed native opaque allowlist must contain exactly 24 textures")
    return selected


def update_params(text, desired, label):
    parsed = sections(text, label)
    if "params" not in parsed:
        raise ValueError(label + ": missing [params]")
    start, end = parsed["params"]
    before = values(text, (start, end), label)
    block = text[start:end]
    for key, value in desired.items():
        pattern = re.compile(r"(?m)^" + re.escape(key) + r"=[^\r\n]*$")
        replacement = key + "=" + value
        if key in before:
            block, count = pattern.subn(lambda _: replacement, block)
            if count != 1:
                raise ValueError(label + ": ambiguous setting " + key)
        else:
            block = block.rstrip("\n") + "\n" + replacement + "\n"
    updated = text[:start] + block + text[end:]
    updated_sections = sections(updated, label)
    after = values(updated, updated_sections["params"], label)
    if {k: v for k, v in before.items() if k not in desired} != {k: v for k, v in after.items() if k not in desired}:
        raise ValueError(label + ": unrelated import settings changed")
    for section, span in parsed.items():
        if section != "params" and text[slice(*span)] != updated[slice(*updated_sections[section])]:
            raise ValueError(label + ": generated import remap/deps must remain untouched")
    return updated, before


def run(apply=False):
    selected = load_policy()
    seen = set()
    chosen = []
    protected_mips = {}
    updates = []
    protected_count = 0
    imports = list((ROOT / "assets/art").rglob("*.import")) + list((ROOT / "assets/models").rglob("*.import"))
    for path in sorted(imports):
        relative = path.relative_to(ROOT).as_posix()
        resource_path(relative)
        original = path.read_text()
        parsed = sections(original, relative)
        if "remap" not in parsed:
            raise ValueError(relative + ": missing [remap]")
        remap = values(original, parsed["remap"], relative)
        if remap.get("importer") != '"texture"':
            continue  # GLB scene metadata is outside this policy.
        source = relative.removesuffix(".import")
        if "deps" not in parsed:
            raise ValueError(relative + ": missing [deps]")
        deps = values(original, parsed["deps"], relative)
        if deps.get("source_file") != json.dumps("res://" + source):
            raise ValueError(relative + ": texture source identity mismatch")
        gpu = source in selected
        desired = EXPECTED_GPU if gpu else EXPECTED_PROTECTED
        updated, before = update_params(original, desired, relative)
        if gpu:
            seen.add(source)
            chosen.append({"path": source, "settings": {key: before.get(key, "<missing>") for key in desired}})
        else:
            protected_count += 1
            mip = before.get("mipmaps/generate", "<default>")
            protected_mips[mip] = protected_mips.get(mip, 0) + 1
        if updated != original:
            updates.append((path, updated))
    missing = sorted(set(selected) - seen)
    if missing:
        raise ValueError("Allowlisted native texture imports missing: " + ", ".join(missing))
    # Validate the whole inventory before writing any metadata. Never open images.
    if apply:
        for path, updated in updates:
            path.write_text(updated)
    report = {
        "policy": POLICY.relative_to(ROOT).as_posix(),
        "operation": "apply" if apply else "check",
        "ok": apply or not updates,
        "gpu_textures": len(chosen),
        "protected_textures": protected_count,
        "gpu_required_settings": EXPECTED_GPU,
        "protected_required_settings": EXPECTED_PROTECTED,
        "gpu_settings_before": chosen,
        "protected_mipmap_counts": protected_mips,
        "metadata_changes": len(updates),
        "changed_import_examples": [path.relative_to(ROOT).as_posix() for path, _ in updates[:12]],
        "source_images_opened": 0,
    }
    print("TEXTURE_POLICY " + json.dumps(report, sort_keys=True))
    return 0 if report["ok"] else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--apply", action="store_true", help="update reviewed metadata settings only")
    mode.add_argument("--check", action="store_true", help="fail if an import deviates from policy")
    args = parser.parse_args()
    try:
        return run(apply=args.apply)
    except (ValueError, OSError, KeyError, TypeError) as error:
        print("TEXTURE_POLICY_ERROR " + str(error), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
