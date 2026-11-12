# 일반 투사체의 네이티브 표시

`Player._projectiles()`는 기본 `firebolt`와 `fireball`을 `kind="proj", visual=""`로 만듭니다. 숨긴 원본 Canvas 대신 동작하는 `WorldRenderer3D._sync_cards()`는 이 값을 원화 화이트리스트 밖으로 취급해 실제 탄환이 보이지 않았습니다.

`CombatEffects3D`는 현재 `game.world`의 살아 있는 일반 비투척 투사체만 관찰합니다. `Effect.native_position()`의 실제 높이와 궤적, 소스의 `age/life`, 연속 관찰된 실제 이동 방향을 사용합니다. 생성형 `PresentationArt`의 기존 `combat-frames.webp` 원소 행과 peak열을 재사용하며, 새 이미지·충돌·피해·자원 소비·효과용 타이머를 추가하지 않습니다. 본체는 원본44px 크기와 작은 source-age 흔들림을 유지하고, 꼬리는0.32m 이하입니다. 공간 깊이 검사를 사용하며 새 Canvas/SubViewport/점광원은 만들지 않습니다.

최대32개의 투사체에 본체/꼬리2카드씩, 합계64카드·128삼각형을 사용합니다. 상한은 표시만 제한하고 게임 투사체를 삭제하지 않습니다. 정지 중에는 소스가 그대로 멈추며 동작 줄이기는 꼬리와 깜박임을 억제합니다. 지역이 바뀌거나 소스가 만료/삭제되면 해당 그림을 제거합니다. 기존 bolt/slash/spin/slam/frost/meteor/impact/cast/release 그림은 기존 경로로 유지합니다.

`native_projectile_fx`는 실제 장착 슬롯의 기본 firebolt/fireball 발사 콜백, 올라간 바닥의 비행, 원소 UV와 공간 깊이, 꼬리 상한, 정지/동작 줄이기, 소스 만료, 기존 iceBolt 중복 방지, 표시 예산과 지역 소유권을 검사합니다. `spatial_combat`과 `render_budget`도 함께 검사합니다. `generic_projectiles` 브라우저 프로브는 실제 소스 나이/위치와 native body 오차를 읽기만 합니다.

## 이번 변경에 포함하지 않는 기존 누락 경로

| 소스 kind | 실제 호출 경로 |
| --- | --- |
| 투척 proj | doubleThrow의 throw=true |
| orb | frozenOrb 본체(방출하는 일반 투사체는 이번 공통 경로에 해당) |
| beam / chain / strike | lightning / chainLightning / thunderStorm |
| nova | nova / staticField / 일부 전사 함성·보조 접촉 원 |
| zone | blizzard / firewall / blaze / meteor의 경고·지속 영역(별도 meteor 충격 원화는 유지) |
| cone / trail | inferno / 이동 기술의 연결 흔적 |
| hydra / ward | hydra 본체 / grimWard(방출하는 일반 투사체는 공통 경로에 해당) |
| dodge_echo | 원본 배우 잔상 |

이 목록은 기존 매핑 공백의 기록이며 이번 마감 범위를 확대하지 않습니다.
