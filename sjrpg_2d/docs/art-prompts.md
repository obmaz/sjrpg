# 원화 생성 공통 프롬프트

반드시 [레퍼런스 분위기 제작 가이드](reference-look-guide.md)와 [아트 기준](art-direction.md)을 함께 읽습니다. 아래 영어 블록은 제작용 공통 문구이며, 마지막의 자산별 요구만 바꿉니다. 사용자 기준 화면과 같은 패밀리 이미지를 실제 생성 도구에 참조 이미지로 첨부해야 합니다. 파일 이름만 프롬프트에 적는 것은 이미지 참조가 아닙니다.

## 매번 첨부할 참조

- 분위기 최상위: `assets/source/style/approved-game-reference.jpg`
- 새 패밀리의 분리 원화: 위 사용자 원본과 함께 실제 사용할 작은 장면 컨셉. 현재 마을은 `assets/source/remake/town-master-scene.png`의 비교 수정 후보3을 사용하며 승인된 새 기준으로 간주하지 않습니다.
- 성문·성벽: 위 두 참조와 현재 `assets/source/remake/gate-a.png`·`gate-b-v2.png` 및 실제 추출 벽을 사용합니다. `gate_measure.json`·`remake_gate_*_measure.json`에서 현재 채택 파일을 확인합니다. 이전 `gate-wall-design.png`는 제작 이력입니다.
- 마을 건물·예배당: 해당 패밀리의 현재 채택 원본. `town_art_measure.json`·`chapel_measure.json`에 경로가 있습니다. 이전 구조 원화를 첨부할 때는 geometry guide임을 명시하고 재질·색·구도 기준으로 삼지 않습니다.
- 식생: `assets/source/remake/trees-v2.png`·`flora.png` 중 해당 패밀리. 위에서 본 지면은 `remake/ground.png`, 강 재료는 `remake/river-materials.png`를 참조합니다.
- 배우/선택 원화: `assets/source/hero-selection.png`, 실제 HUD 얼굴 원화. 새 성별·의상으로 바꾸지 않습니다.

통합 컨셉 생성에서는 패밀리 참조가 아직 없을 수 있습니다. 그 경우 사용자 기준 화면과 이미 검수된 인접 건물을 사용하고, 채택한 컨셉의 파일과 실제 생성 프롬프트를 해당 제작 문서에 남깁니다.
마을의 실제 생성 문구·참조 파일 순서·거절/대체 이력은 `tools/extract/town_remake_generation.json`에 있습니다. 아래 공통 문구는 실제 실행 기록을 대신하지 않습니다.

## 작은 완성 장면 컨셉

새 패밀리는 이 단계부터 시작합니다. 아래 컨셉은 재료·빛·구도를 맞추는 제작 참조이며, 한 장을 배경으로 붙여 게임을 구현하지 않습니다.
문·계단·앞뒤 가림과 120° 실측을 통과한 분리 원화로 옮깁니다. 사용자 원본을 실제 참조 이미지로 첨부합니다.

```text
Create a cohesive close gameplay scene for Guardians of Nature, matching the
supplied USER GAME REFERENCE: a restrained realistic forest chapel, an intimate
stone path, layered woodland planting and one male mage in a dark navy coat.
Keep the character's identity, proportions and materials consistent with the
supplied CHARACTER REFERENCE when provided.

TRUE ORTHOGRAPHIC ISOMETRIC 2.5D: azimuth 45 degrees, elevation 35.264 degrees.
Ground-axis edges must be at +30 / -30 degrees, vertical edges exactly upright,
with the three projected axes 120 degrees apart. Keep parallel edges parallel
at the top, middle and base of both visible faces. No perspective convergence,
wide-angle lens or 2:1 dimetric projection. Roof pitches are not ground edges.

Use a close playable composition, not an aerial map or a miniature village.
The standing character's visible height is roughly 22–26% of the short image
dimension. One nearby chapel dominates the background; allow its outer extent
to continue outside the frame. Leave the character and attack direction clear.
Layer near-edge leaves, the readable character and stone path, and a deeper forest.

Warm restrained daylight from the upper left, cool dark woodland ambient shade,
warm neutral-gray limestone relief, slate-blue shingles, muted olive vegetation,
small cream-white and restrained warm wildflowers. Keep material texture legible
at mobile viewing size. Preserve shadow detail and the navy coat silhouette.
Add a small blue-white hand-cast light with separated delicate particles;
never obscure the body with a white bloom blob. No excessive gilding or ornament.

No HUD, text, buttons, phone frame, navigation bar, logo or watermark.
This is a SCENE CONCEPT: lighting and cast shadows describe the final mood.
Do not reuse scene shadow patches in tiles or isolated production objects.
OUTPUT: [portrait or landscape dimensions and the intended playable crop].
```

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

Use consistent soft neutral diffuse light for the reusable material layer.
Preserve readable form shading, surface relief and self-shading inside joints
and recesses; do not flatten the object into an evenly colored cutout. No cast shadow on the ground, no black shadow plate,
no sun patches, no unrelated lighting or surroundings baked into the asset.
One isolated complete object, transparent background, no ground platform unless
it is part of the actual structure. Preserve fine alpha edges without a halo.
No words, logos, UI, buttons, border, watermark, mobile navigation bar, or frame.
Do not copy the HUD or the scene's cast shadows from the user reference.

ASSET: [type and exact structural requirements]
VIEW: [the required direction, plus explicit visible front/side]
SCALE: [measured world footprint, total height, door/step proportions relative to
the84-world-unit hero; preserve access, but allow recorded layout corrections
when an old footprint would make the door smaller than the hero]
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
