# Native resident family

The merchant is a single imported CC0 pilot from Quaternius's preserved FREE Standard adult family. The other seven identities remain the authored models described below. This pilot does not replace the warrior or the entire village population. Runtime source is `res://assets/art/native_residents/merchant.glb`; source, licence and offline conversion records accompany the generated asset. Actual before/after gallery and gameplay captures remain a separate review gate.

## Shared runtime contract

`NativeResidents3D.create(identity)` is the factory for both the actual village renderer and the review gallery. It returns a `Node3D` root: an imported merchant scene, or an authored `MeshInstance3D` for the other identities. Unknown identities return null. `build("merchant")` returns null, so tests and gallery code cannot accidentally validate an unused procedural substitute. A missing imported scene is visible as a missing owner and fails the pilot test rather than silently claiming conversion.

The merchant has Y-up metre geometry, +Z front, baked root/rig scale and sole Y=0. Its bareheaded adult height target is 1.78m, matching the authoritative 112px resident body height at the existing world-metre scale. The pilot preserves original CC0 UVs and colour textures with roughness 0.95 on its lit PBR materials; the merchant is not yet remapped to the generated shared actor atlas. That shared atlas still belongs to the seven authored residents. The old procedural merchant's 1.84m hat height is not applied to the bareheaded import.

AnimationPlayer uses manual sampling with zero crossfade and no autoplay. `sample_idle(model, source_time)` reads the original `Villager._time` clock, wraps it through the actual imported idle clip, seeks and applies the pose with zero time advance. There is no second timer; pause freezes the original resident clock and the imported skeleton. Repeating the same source time holds the pose. The gallery uses the same factory and sampling API.

Runtime entries retain the source Villager by WeakRef and expose a Node3D root, all descendant body meshes, the actual AnimationPlayer/Skeleton3D and selected clip/time. Source foot position, facing, local visibility and forest/dungeon scope remain authoritative. Injury overlays apply to every imported mesh and clear without changing any shared base material. The import adds no collision body and preserves NPC interaction, name, quest marker and protection-state ownership.

`local_bounds(model)` merges source/rest mesh AABBs through all descendant node transforms in actor-local coordinates, excluding current world placement. These are not evaluated GPU-skinned pose bounds or exact visible silhouette measurements; actual bone transforms and rendered poses are checked separately. `review_snapshot()` distinguishes imported/authored and animated counts; it does not report the remaining seven authored actors as imported.

## Seven authored identities

Seven remaining resident identities use closed, anatomically connected cross-section lofts rather than primitive cylinder bodies. NativeActorShapes is the reproducible geometry source; NativeActorMaterials supplies the shared generated painterly surface atlas. Source Villager identity, actor foot, facing, injury intensity, scope and gameplay remain authoritative.

The anatomy has a shoulder/chest/waist profile, elbow/forearm taper, hand volumes, curved toe/ankle/boot shafts and a jaw/cheek/temple skull profile. Eye whites and pupils sit beyond the face surface, below separate brow volumes. Nose bridge/tip and mouth line are separate features. An open back-and-side hair shell and six tapered locks replace the previous flat hair disk. Elder and smith beard shapes, female braid silhouettes and actual open collars connect the neck and head.

Clothing is constructed by role: smith bare arms and front apron with neck straps; stable keeper open leather vest and saddle pouch; elder low hunched neckline, long folded robe and staff; Mira slender travel coat, short curved cape and shaped backpack; Elin open-face hood shell and ivory tabard; Noah shoulder hood and herb basket; Rowen asymmetric cloak, book and shaped shoulder plate. Front/back cloth shells have finite thickness and folded hems. These differences are actual geometry, not only palette substitutions.

All geometry is batched by cloth/leather/skin/iron surface category, with no more than four shared opaque atlas materials per NPC. Hair shares the skin surface with dark vertex tint; bronze uses the iron surface with bronze tint. Models use Y-up metres, +Z front, sole Y=0 and baked identity scale. Adult variation includes an elder around1.72m and adult bareheaded role heights up to roughly1.78m. Native head/neck/hat bounds and every triangle/surface count are printed by native_residents; the current cap is6500triangles per model. This cap is a mobile creation constraint, not a measured FPS claim.

The earlier quick gallery was rejected for prototype silhouettes. This refinement must be judged in fresh actual four-face gallery captures, and same-location mobile gameplay alongside the warrior, environment and HUD. Geometry bounds and test passes do not assert that style is approved. The original NPC card is not registered, while labels/quest/protection bars retain Ortho3DAffordances ownership.

## 실제 배우와 비례 비교

명시적인 `native_style_review=1` 검수에서 `NativeActorProportionAudit`는 현재 게임 인스턴스의 전역 변환이 반영된 메시 rest AABB와 Head/foot/toe 골격 위치를 배우별 한 번 측정합니다. 지팡이·보석·검으로 높이를 부풀리지 않도록 제외한 경로도 기록합니다. 메시의 rest 경계는 현재 스킨 자세나 화면에서 가려지지 않은 픽셀의 정확한 크기가 아니므로 골격 위치와 실제 화면을 함께 봅니다. 이 측정기는 원본 리그·모델 크기·게임 상태를 바꾸거나 GPU bake를 수행하지 않습니다. 같은 직교 카메라에서 자세·가림·바닥 높이를 확인한 뒤 비례를 판단합니다.

## Verification

`native_residents` checks the seven authored meshes and mixed-runtime owner/foot/visibility/flash contracts. `native_merchant` loads the actual imported scene and verifies source/rest volume, baked adult scale, the 18,000-triangle pilot gate, lit materials, real skin and skeleton, manually sampled bone motion, original-clock advance and pause, descendant injury cleanup, scope restoration and source-owner removal. Runtime mesh/surface/triangle/bounds records are measured; passing these checks does not establish visual improvement without the actual paired gallery and town captures.


## CC0 상인 파일럿의 제작·성능 범위

상인 한 명은 Quaternius FREE Standard의 의상·기본 머리·UAL1 원본과 패키지 내 CC0 라이선스를 실제 파일 해시로 검증해 사용합니다. 정확한 원문·원본/런타임 해시·변환 버전은 `assets/source/native-residents/merchant/provenance.json`과 같은 폴더의 세 LICENSE 파일에 있습니다. 상업 게임 이용·수정·재배포 허용은 해당 CC0 원문에 근거합니다. 새 QAL 팩이나 유료 Source 구성은 사용하지 않습니다.

실제 원본 의상과 UAL의 기준 자세는 최대 약 0.084m/회전 행렬 성분 0.192 차이가 있어 동작을 직접 복사하지 않습니다. 소스의 기준 대비 월드 회전 변화만 대상 기준 회전에 적용하고, 대상 부모/자식의 원래 뼈 길이와 간격을 유지하는 FK 방식으로 30fps idle을 다시 구웠습니다. 위치 변화는 단위가 확인된 root/pelvis에만 전달합니다. 모든 프레임의 뼈 길이·스케일과 다섯 대응 시점의 CPU 변형 메시/발 접지·제자리 유지 검사를 별도로 통과해야 합니다.

이 한 명은 18,000삼각형의 명시적 파일럿 상한을 사용합니다. 변환된 모델은 17,612삼각형·8서피스·65관절·2.5초 idle이며 원본 디테일을 유지합니다. 기존 절차형 NPC의 6,500삼각형/4재질 상한은 나머지 일곱 명에 그대로 적용합니다. 이 예외를 전체 주민·몹에 자동 확대하지 않습니다. 텍스처는 원본 UV의 색을 보존하되 최대1024px, roughness0.95, 별도 Godot PNG 임포트는 손실 모드1을 사용합니다. 실제 다운로드/PCK 변화와 모바일 화면을 검수하며 폴리곤 수만으로 FPS 개선을 주장하지 않습니다.
