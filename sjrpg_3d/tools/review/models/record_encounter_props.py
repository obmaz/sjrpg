#!/usr/bin/env python3
"""입체 소품 실측과 현재 공유 재질·생성형 상자 표면 출처를 기록한다."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


def source(path: str) -> dict:
    payload = (ROOT / path).read_bytes()
    return {"path": path, "sha256": hashlib.sha256(payload).hexdigest(), "bytes": len(payload)}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--browser-proof", type=Path)
    args = parser.parse_args()
    destination = ROOT / "assets/data/native_encounter_props.json"
    family = json.loads((ROOT / "assets/materials/shared/materials.json").read_text())
    stone_px = family["materials"]["limestone"]["size"][0]
    stone_tile = family["physical_scale"]["limestone_tile_m"]
    texel_density = f"{stone_px}px limestone:{stone_px / stone_tile:.2f}px/m. 상자는 각 면 원화를 한 번 배치한다. 별도 법선/거칠기 이미지는 없다."
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
        "scope": "숲1장 비석·목재 상자와 선택형 동굴의 쇠·황금 상자. 2D판은 동결한다.",
        "method": "고정 GLB와 개별 씬에서 실제 입체 상자·힌지·내부·철물을 읽고, 생성형 평면 알베도로 목재·쇠·황금 표면을 구분한다.",
        "reference": source("assets/source/style/approved-game-reference.jpg"),
        "source_art": [source(path) for path in ["assets/sprites/village/encounter-stone.webp", "assets/sprites/village/remake-chest.webp", "assets/sprites/village/remake-chest-broken.webp"]],
        "shared_family_provenance": source("assets/materials/shared/materials.json"),
        "shared_textures": [source("assets/materials/shared/" + name + ".webp") for name in ["limestone"]] + [source("assets/materials/chests/albedo.png")],
        "metal_surface_provenance": source("assets/source/materials/chests/provenance.json"),
        "new_texture_bytes": (ROOT / "assets/materials/chests/albedo.png").stat().st_size,
        "new_binary_model_bytes": sum((ROOT / "assets/models/environment" / identity / "model.glb").stat().st_size for identity in ["treasure_chest", "encounter_stone"]),
        "generators": [source(path) for path in ["tools/assets/props/encounter_builder.gd", "scripts/rendering/environment/encounter_prop_renderer_3d.gd", "assets/materials/chests/chest.gdshader"]],
        "materials": {"stone": "Existing shared front-on generated limestone, 2.56m world tile / 8 courses; instance tint observes source flash.", "chest": "목재·쇠·황금의 앞면·옆면·펼친 곡면 뚜껑 전용 원화를 면 전체 UV로 한 번 배치한다. 실제 철물 정점 마스크와 면 영역을 정점색으로 보존한다.", "texel_density": texel_density, "limitations": "Reused generated albedos retain fine authored self-relief, not measured PBR scans."},
        "coordinates": {"units": "metres", "up": "+Y", "ground": "XZ", "forward": "+Z", "baked_scale": [1, 1, 1], "camera_azimuth": 45, "camera_elevation": 35.2643897},
        "geometry": metrics[0],
        "stone_footprint_m": [.8, 32 / 65],
        "stone_height_m": 1.58,
        "chest_scale": "기존 입체 상자 대비 세 축2배. 닫힌1.140×1.058×0.750m; PROP 반경60투영단위(0.777m), 높이1.06m. 표시 배율(1,1,1). ChestPlacement가 기단 경계·건물·나무를 피해 숲 상자를 배치하고 저장 ID는 보존한다.",
        "ownership": {"stone": "Only the art instance IDs of the exact six EncounterStone owners; excludes only those old environment cards.", "chest": "Only current Chest.body_sprite IDs; breaking replaces this sprite identity. Affordances remove the previous fallback and retain fallback when no model is owned.", "regions": "현재 지역의 소스만 표시한다. 동굴에서는 숲 모델을 숨겨 보관하고 새 동굴 상자만 표시하며, 복귀 시 숲의 소모 상태를 복원한다.", "runtime": "표시기는 실제 비석 상태와 Chest.dead/hp/variant만 읽는다. 보상·내구력은 Chest와 Game이 소유하고 공간 충돌은 SpatialWorld3D가 소유한다."},
        "validation": {"headless": "native_encounter_props PASS; actual source strike/open, capsule collider release, hinge-volume check, hidden/cave/return/deletion ownership.", "gpu": gpu, "review_fixture_source": source("scripts/inspection/native_encounter_review.gd"), "review_fixture": "Explicit loot_review=1 in a fresh isolated browser profile only. Official create_slot binds a unique test session before original source state methods. Same source anchors and fixed120 camera; optional native-model rotation checks unseen faces, optional original-art cards provide same-world comparison."},
    }
    destination.write_text(json.dumps(document, ensure_ascii=False, indent=2) + "\n")
    print(destination.relative_to(ROOT))


if __name__ == "__main__":
    main()
