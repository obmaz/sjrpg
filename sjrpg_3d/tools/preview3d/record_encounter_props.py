#!/usr/bin/env python3
"""Record code-built volume and reused family sources; never generate/paint art."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def source(path: str) -> dict:
    payload = (ROOT / path).read_bytes()
    return {"path": path, "sha256": hashlib.sha256(payload).hexdigest(), "bytes": len(payload)}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--browser-proof", type=Path)
    args = parser.parse_args()
    destination = ROOT / "assets/data/native_encounter_props.json"
    previous = json.loads(destination.read_text()) if destination.is_file() else {}
    family = json.loads((ROOT / "assets/art/preview3d/materials.json").read_text())
    stone_px = family["materials"]["limestone"]["size"][0]
    stone_tile = family["physical_scale"]["limestone_tile_m"]
    timber_px = family["materials"]["timber"]["size"][0]
    texel_density = f"{stone_px}px limestone:{stone_px / stone_tile:.2f}px/m; timber:{timber_px * .65:.2f}px/m. No normal/roughness image maps invented."
    lines = args.log.read_text().splitlines()
    metrics = [json.loads(line.removeprefix("NATIVE_ENCOUNTER_METRICS ")) for line in lines if line.startswith("NATIVE_ENCOUNTER_METRICS ")]
    if len(metrics) != 1 or not any(line.startswith("PASS native_encounter_props") for line in lines):
        raise SystemExit("Need one successful actual native_encounter_props metric record")
    gpu = "Pending coordinated actual browser captures; CPU metadata is not visual acceptance."
    if args.browser_proof:
        payload = args.browser_proof.read_bytes()
        proof = json.loads(payload)
        captures = proof.get("evidence", [])
        if proof.get("errors") != [] or not captures:
            raise SystemExit("Need completed browser evidence without unexpected errors")
        gpu = {
            "evidence_sha256": hashlib.sha256(payload).hexdigest(),
            "captures": len(captures), "unexpected_errors": 0,
            "quality_modes": sorted({capture["quality"] for capture in captures}),
            "viewports": sorted({"{width}x{height}".format(**capture["viewport"]) for capture in captures}),
            "observed_cases": [capture["name"] for capture in captures],
            "interpretation": "Actual coordinated captures were inspected separately; recording evidence is not automatic style approval.",
        }
    document = {
        "scope": "Existing Stage1 forest encounter stones and all existing chests only; source2D project unchanged.",
        "method": "Reproducible native full-volume mesh construction. No new image/model generation, image painting, relighting or baked shadows.",
        "reference": source("assets/source/style/approved-game-reference.jpg"),
        "source_art": [source(path) for path in ["assets/art/village/encounter-stone.webp", "assets/art/village/remake-chest.webp", "assets/art/village/remake-chest-broken.webp"]],
        "shared_family_provenance": source("assets/art/preview3d/materials.json"),
        "shared_textures": [source("assets/art/preview3d/" + name + ".webp") for name in ["limestone", "timber"]],
        "new_texture_bytes": 0,
        "new_binary_model_bytes": 0,
        "generators": [source("scripts/" + name) for name in ["native_encounter_mesh_3d.gd", "native_encounter_props_3d.gd", "native_chest_material.gdshader"]],
        "materials": {"stone": "Existing shared front-on generated limestone, 2.56m world tile / 8 courses; instance tint observes source flash.", "chest": "Existing shared front-on generated timber, .65 UV scale (1.538m tile), and shared iron colour/roughness/metallic response selected by geometry vertex mask. No painted iron overlay.", "texel_density": texel_density, "limitations": "Reused generated albedos retain fine authored self-relief, not measured PBR scans."},
        "coordinates": {"units": "metres", "up": "+Y", "ground": "XZ", "forward": "+Z", "baked_scale": [1, 1, 1], "camera_azimuth": 45, "camera_elevation": 35.2643897},
        "geometry": metrics[0],
        "stone_footprint_m": [.8, 32 / 65],
        "stone_height_m": 1.58,
        "chest_proportion_change": "The old ~111.7-world-unit target sprite was replaced by a below-knee-height physical chest bounded by its existing 24px-radius cylinder; the old source card was much wider/taller than that inset physical collider. The original centre/ground source point, collider and consumed lifetime remain unchanged.",
        "ownership": {"stone": "Only the art instance IDs of the exact six EncounterStone owners; excludes only those old environment cards.", "chest": "Only current Chest.body_sprite IDs; breaking replaces this sprite identity. Affordances remove the previous fallback and retain fallback when no model is owned.", "regions": "Explicit forest scope plus source-local visibility; hidden adapter ancestors are ignored. Native roots hidden in cave and cleaned when owners leave the source world.", "runtime": "Read-only EncounterRuntime states/charges/recharge/living/can_summon, EncounterStone source tint/flash and Chest.dead. No visual timer, altered collision or extra rewards."},
        "validation": {"headless": "native_encounter_props PASS; actual source strike/open, capsule collider release, hinge-volume check, hidden/cave/return/deletion ownership.", "gpu": gpu, "review_fixture_source": source("scripts/native_encounter_review.gd"), "review_fixture": "Explicit loot_review=1 in a fresh isolated browser profile only. Official create_slot binds a unique test session before original source state methods. Same source anchors and fixed120 camera; optional native-model rotation checks unseen faces, optional original-art cards provide same-world comparison."},
    }
    # Refresh measured sources without discarding the adopted enlargement,
    # authoritative placement correction or previously qualified GPU evidence.
    for key in ("chest_proportion_change", "placement_correction", "shared_family_update"):
        if key in previous:
            document[key] = previous[key]
    if "runtime" in previous.get("ownership", {}):
        document["ownership"]["runtime"] = previous["ownership"]["runtime"]
    validation = dict(previous.get("validation", {}))
    validation.update({key: value for key, value in document["validation"].items() if key != "gpu"})
    if args.browser_proof or "gpu" not in validation:
        validation["gpu"] = gpu
    document["validation"] = validation
    destination.write_text(json.dumps(document, ensure_ascii=False, indent=2) + "\n")
    print(destination.relative_to(ROOT))


if __name__ == "__main__":
    main()
