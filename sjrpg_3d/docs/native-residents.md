# Authored native resident family

Eight resident identities use closed, anatomically connected cross-section lofts rather than primitive cylinder bodies. NativeActorShapes is the reproducible geometry source; NativeActorMaterials supplies the shared generated painterly surface atlas. Source Villager identity, actor foot, facing, injury intensity, scope and gameplay remain authoritative.

The anatomy has a shoulder/chest/waist profile, elbow/forearm taper, hand volumes, curved toe/ankle/boot shafts and a jaw/cheek/temple skull profile. Eye whites and pupils sit beyond the face surface, below separate brow volumes. Nose bridge/tip and mouth line are separate features. An open back-and-side hair shell and six tapered locks replace the previous flat hair disk. Elder and smith beard shapes, female braid silhouettes and actual open collars connect the neck and head.

Clothing is constructed by role: merchant short frock and soft cap; smith bare arms and front apron with neck straps; stable keeper open leather vest and saddle pouch; elder low hunched neckline, long folded robe and staff; Mira slender travel coat, short curved cape and shaped backpack; Elin open-face hood shell and ivory tabard; Noah shoulder hood and herb basket; Rowen asymmetric cloak, book and shaped shoulder plate. Front/back cloth shells have finite thickness and folded hems. These differences are actual geometry, not only palette substitutions.

All geometry is batched by cloth/leather/skin/iron surface category, with no more than four shared opaque atlas materials per NPC. Hair shares the skin surface with dark vertex tint; bronze uses the iron surface with bronze tint. Models use Y-up metres, +Z front, sole Y=0 and baked identity scale. Adult variation includes an elder around1.72m and the merchant cap reaching1.84m. Native head/neck/hat bounds and every triangle/surface count are printed by native_residents; the current cap is6500triangles per model. This cap is a mobile creation constraint, not a measured FPS claim.

The earlier quick gallery was rejected for prototype silhouettes. This refinement must be judged in fresh actual four-face gallery captures, and same-location mobile gameplay alongside the warrior, environment and HUD. Geometry bounds and test passes do not assert that style is approved. The original NPC card is not registered, while labels/quest/protection bars retain Ortho3DAffordances ownership.

## 실제 배우와 비례 비교

명시적인 `native_style_review=1` 검수에서 `NativeActorProportionAudit`는 현재 게임 인스턴스의 전역 변환이 반영된 메시 rest AABB와 Head/foot/toe 골격 위치를 배우별 한 번 측정합니다. 지팡이·보석·검으로 높이를 부풀리지 않도록 제외한 경로도 기록합니다. 메시의 rest 경계는 현재 스킨 자세나 화면에서 가려지지 않은 픽셀의 정확한 크기가 아니므로 골격 위치와 실제 화면을 함께 봅니다. 이 측정기는 원본 리그·모델 크기·게임 상태를 바꾸거나 GPU bake를 수행하지 않습니다. 같은 직교 카메라에서 자세·가림·바닥 높이를 확인한 뒤 비례를 판단합니다.
