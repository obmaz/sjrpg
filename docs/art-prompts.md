# 원화 생성 공통 프롬프트

반드시 [아트 기준](art-direction.md)을 함께 읽습니다. 아래 영어 블록은 제작용 공통 문구이며, 마지막의 자산별 요구만 바꿉니다. 사용자 기준 화면과 같은 패밀리 이미지를 실제 생성 도구에 참조 이미지로 첨부해야 합니다. 파일 이름만 프롬프트에 적는 것은 이미지 참조가 아닙니다.

## 매번 첨부할 참조

- 분위기 최상위: `assets/source/style/approved-game-reference.jpg`
- 성문·성벽: `assets/source/style/gate-wall-design.png`와 해당 방향의 최근 검수된 성문 원화. 재생성 시 `tools/extract/gate_measure.json`에서 실제 파일을 확인합니다.
- 마을 건물·예배당: 해당 패밀리의 검수된 원본. `town_art_measure.json`·`chapel_measure.json`에 경로가 있습니다.
- 식생: `assets/source/forest-trees.png`, `forest-flora.png` 중 해당 패밀리.
- 배우/선택 원화: `assets/source/hero-selection.png`, 실제 HUD 얼굴 원화. 새 성별·의상으로 바꾸지 않습니다.

통합 컨셉 생성에서는 패밀리 참조가 아직 없을 수 있습니다. 그 경우 사용자 기준 화면과 이미 검수된 인접 건물을 사용하고, 채택한 컨셉의 파일과 실제 생성 프롬프트를 해당 제작 문서에 남깁니다.

## 단일 월드 오브젝트

```text
Create production game artwork for Guardians of Nature. Match the supplied
USER GAME REFERENCE for the restrained realistic forest-fantasy art direction,
and the supplied FAMILY REFERENCE for exact material, construction and scale.
The user reference remains authoritative; do not invent a new art style.

TRUE ORTHOGRAPHIC ISOMETRIC 2.5D, 45-degree azimuth, 35.264-degree elevation.
Ground edges at exactly +30 and -30 degrees on the image; upright edges vertical.
The three projected axes are 120 degrees apart. No perspective convergence,
no foreshortening that changes with distance, no 2:1 dimetric grid, no lens effects.
Top, middle and bottom edges on the same axis must stay parallel on both sides.

Natural restrained detail: warm neutral-gray weathered limestone, legible fine
mortar joints, muted olive foliage, slate-blue roof tiles, aged oak and matte iron
where applicable. Match block dimensions, molding profile, battlement caps,
walkway width and material roughness to the family reference in both directions.
Contemporary realistic hand-finished game art, readable silhouettes and material
texture; no thick outlines, no cartoon, no low-poly or flat painted surfaces,
no excessive ornament, no bright gold decoration, no yellow oversized stonework.

Use consistent soft neutral diffuse light. Self-shading inside joints and
recesses is allowed. No cast shadow on the ground, no black shadow plate,
no sun patches, no unrelated lighting or surroundings baked into the asset.
One isolated complete object, transparent background, no ground platform unless
it is part of the actual structure. Preserve fine alpha edges without a halo.
No words, logos, UI, buttons, border, watermark, mobile navigation bar, or frame.
Do not copy the HUD or the scene's cast shadows from the user reference.

ASSET: [type and exact structural requirements]
VIEW: [the required direction, plus explicit visible front/side]
SCALE: [existing footprint, total height, door/step proportions; do not change]
CONNECTIONS: [required matching wing ends, cornice height, block courses, caps]
OUTPUT: [one complete object / specified separate atlas cells with padding]
```

‘120°’는 생성 요청이며 검증 결과가 아닙니다. 생성 후에는 원화의 여러 실제 직선을 측정합니다.

## 통합 패밀리 컨셉

공통 블록의 투명 오브젝트 지시를 아래 내용으로 바꿉니다. 결과를 게임 아틀라스로 바로 사용하지 않고 구조와 재료의 참조로 삼습니다.

```text
Show ONE coherent architectural family in a unified isometric design sheet:
[gate, wall in both ground-axis directions, and the actual joining corner].
All parts share exactly the same stone size, mortar, roughness, color temperature,
corbel/cornice profile, coping and battlement cap design. Include the rear walkway
and both faces so mismatches cannot hide behind a single front view. No labels.
```

## 지면·식생·효과의 예외

- 지면은 실제 `Iso` 평면에 투영하므로 원화는 정면 위에서 보는 반복 재료 타일입니다. 위 단일 구조물 카메라 문구 대신 `orthographic top-down, seamless evenly lit material tile, no directional shadows`를 사용합니다. 오브젝트 원근을 타일에 굽지 않습니다.
- 식생은 같은 높은 카메라와 색·세부 밀도를 유지하되 자연형 수관을 자로 그은 모서리처럼 만들지 않습니다. `visible upper canopy layers, naturally occluded rear branches, short trunk, rooted ground contact, irregular organic silhouette`을 덧붙입니다.
- 이펙트는 실제 속성에 맞는 작은 청백/불꽃/서리 핵, 가는 궤적과 짧은 섬광입니다. 발광 전용은 [ADD 원화 규격](presentation-design.md)에 따라 순수 검정 바탕으로 제작할 수 있으며 빈 픽셀의 빛 기여가 0인지 검수합니다. UI·일반 오브젝트는 실제 투명 알파를 유지합니다. 투명 알파 또는 발광 전용 검정 바탕과 실제 게임에서 사용할 수명·크기·프레임 구분을 지정하고 바닥·캐릭터·UI를 함께 굽지 않습니다.
