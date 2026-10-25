# 콘텐츠와 아트 출처

## 규칙 참고

이 게임은 D&D **SRD 5.1**의 무기 이름·피해 주사위와 몬스터의 HP·AC·CR·공격 피해를 참고한 실시간 액션 RPG입니다.
턴제 D&D 규칙을 그대로 실행하지는 않습니다. 명중 굴림·AC에 따른 회피·주문 슬롯·저항·멀티어택은 구현하지 않았습니다.
실제 전투는 기존의 범위 판정, ATK와 재사용 대기시간, 단계별 보정을 사용합니다. 도감의 SRD 참고 수치는 원전 정보입니다.

- [SRD 5.1 원문](https://media.dndbeyond.com/compendium-images/srd/5.1/SRD_CC_v5.1.pdf)
- [공식 SRD 안내](https://www.dndbeyond.com/srd)
- [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)

원전의 단검 1d4·롱소드와 배틀액스 1d8·채찍 1d4·라이트 크로스보우 1d8을 피해 유형과 함께 장비에 표시합니다.
실제 기본 ATK에는 실시간 전투용 능력치 보정을 반영합니다. 단검은 ATK 5·0.24초·3타 콤보,
롱소드는 ATK 8·0.5초·범위 공격으로 서로 다른 역할을 가집니다.
마법 장비의 능력·사용 횟수와 독의 단검·앙크 메이스 등 지역 장비는 이 게임의 자체 변형입니다.
치유의 물약은 원전 2d4+2를 참고하되 HP 100인 실시간 전투에 맞춰 50을 회복합니다.

| 몬스터 참고                | 원전 HP |  AC |  CR | 게임 기본 HP |
| -------------------------- | ------: | --: | --: | -----------: |
| Gray Ooze / 회색 점액괴물  |      22 |   8 | 1/2 |           24 |
| Goblin / 고블린            |       7 |  15 | 1/4 |           14 |
| Wolf / 늑대                |      11 |  13 | 1/4 |           22 |
| Skeleton / 스켈레톤        |      13 |  13 | 1/4 |           26 |
| Troll / 트롤               |      84 |  15 |   5 |          100 |
| Stone Golem / 스톤 골렘    |     178 |  17 |  10 |          200 |
| Giant Scorpion / 거대 전갈 |      52 |  15 |   3 |           60 |
| Mummy / 미라               |      58 |  11 |   3 |           70 |
| Mummy Lord / 파라오        |      97 |  17 |  15 |          350 |

작은 적은 빠른 공격을 주고받는 전투를 위해 HP를 늘리고, 파라오 같은 보스는 보스전 길이를 위해 별도 보정했습니다.
실제 생성 시에는 단계 보정과 보스 보정이 추가됩니다. 모든 몬스터·보스의 원전 참고 값은 데이터의 `reference`에 따로 보관합니다.

## 반복 보상

이미 장착하거나 보관 중인 **무제한 무기와 같은 종류의 드롭**은 가치의 20%에 해당하는 골드로 자동 전환합니다.
단검은 10골드이며, 가방이 가득 차 있어도 전환됩니다. 새 종류의 무기는 보관하고, 가방이 가득 차면 바닥에 남습니다.
사용 횟수가 있는 무기와 플레이어가 직접 버린 무기는 자동 전환하지 않아 남은 횟수와 재습득을 보존합니다.
상점에서 의도적으로 구매한 장비도 자동 전환하지 않습니다.

## Flutter 버전의 직업·장비

Flutter 버전의 전사·마법사는 근접 연타·함성·소용돌이와 화염·냉기·번개의 전투 구성을 참고한 독립 구현입니다. Diablo 게임의 코드·이미지·사운드·데이터는 사용하지 않습니다. 실제 장비 24종·경험치·스킬 계수·몬스터 수치는 `flutter_game/lib/rpg_model.dart`와 `adventure.dart`의 실시간 전투 수치입니다. 아래 SRD 원전 비교표는 기존 JavaScript 버전의 콘텐츠를 설명합니다.

## 아트

`flutter_game/art/combat-fx.png`는 함성·소용돌이·서릿발·번개·유성·격노·빙결 방패·타격을 위해 생성한 4×2 투명 이펙트 아틀라스입니다. 표시만 담당하며 판정과 재사용 시간은 게임 코드에서 처리합니다.

`flutter_game/art/actors-mage.png`는 기존 모험가 그림을 참조해 생성한 마법사 전용 16방향 × 두 걸음 투명 시트입니다. `mage-bounds.json`은 각 셀의 알파 경계를 측정한 표시 데이터입니다. 원본 생성 PNG를 보존하며 게임에서 방향별로 잘라 표시합니다. `flutter_game/art/gear-icons.png`는 장비 24종을 6×4로 생성한 인벤토리 전용 그림입니다. 스킬 효과·스테이지 출구는 코드로 그립니다. 팝업은 기존 `assets/popup-frame.webp`를 공유합니다.

`assets/landscape-materials.webp`는 연속 초원·숲 이끼·사구·자갈 평원·청록 물·흙길을 위해 생성한 3×2 바닥 재질 시트입니다. `assets/landscape-bridge.webp`는 같은 그림체로 생성한 투명 가로 목교입니다. 지형 윤곽·길·수역과 충돌은 코드의 공통 데이터로 구성하며, 생성 그림에 인물·UI·가짜 길을 포함하지 않습니다.

`assets/actors-hero.webp`, `actors-hero-attack.webp`, `actors-creatures-a.webp`~`actors-creatures-d.webp`, `actors-villagers.webp`, `actors-vehicles.webp`는 같은 그림체로 새로 생성한 방향·걷기·검 공격 시트입니다. 주인공은 기존 청록 모험가 그림을 참조해 16방향으로 만들었으며 모든 이동 적·보스·주민·탈것에는 기본 8방향을 연결합니다.

`assets/village-scene.webp`는 사용자가 첨부한 대표 이미지의 구도를 바탕으로 UI·캐릭터·몬스터·상자를 제거하고 새로 생성한 환경 그림입니다. 실제 인물·전투·상호작용은 코드로 실행합니다.

고대 드래곤은 이 게임을 위해 새로 생성한 붉은 비늘·황금 뿔·펼친 날개의 투명 보스 그림을 사용합니다.

`assets/hero.webp`, `assets/atlas.webp`, `assets/terrain.webp`, `assets/world-forest.webp`, `assets/world-desert.webp`, `assets/ui-reference.webp`, `assets/controls.webp`, `assets/popup-frame.webp`, `assets/world-mounts.webp`, `assets/forest.webp`, `assets/ancient-dragon.webp`는 이 게임을 위해 생성한 이미지입니다.
배경은 숲의 유적·사막 왕국으로 통하는 포탈, 기존 아이콘 시트는 장비 8종·몬스터 초상 8종, 바닥은 잔디·흙·모래·돌길입니다.

`docs/art/village-reference.webp`는 대표 플레이 화면의 생성 콘셉트입니다. 이를 그림체 기준으로 투명 배경의 숲·사막 시트를 각각 4×4로 제작했습니다.
모험가 네 방향, 주민·시설·지형·주요 몬스터·탈것과 도감에 사용합니다. UI 시트는 같은 대표 이미지의 초상·황동 프레임·청록 버튼·조이스틱·메뉴 문양을 별도로 생성한 것입니다. 조작 시트는 중심 정렬과 둥근 메뉴를 위해 별도로 생성했습니다. `docs/art/popup-reference.webp`의 팝업 시안을 먼저 생성한 뒤, 같은 스타일의 빈 팝업 테두리를 생성해 코드로 구성한 창에 사용합니다. [월드 아트 기준](art-direction.md)에 셀 배치와 적용 규칙을 기록합니다.
탈것 시트는 말·자전거·오토바이·배의 앞·왼쪽·뒤·오른쪽 모습을 같은 그림체로 생성한 것입니다. 실제 그림 경계를 측정해 잘림 없이 표시합니다.
숲 재질은 같은 대표 이미지에서 수관·그늘·낙엽·이끼 바닥을 별도로 생성했습니다. 밀집 수관에는 기존 나무 그림의 잎 부분을 함께 사용합니다.
WebP 변환은 투명도를 보존하며, 생성 원본 PNG는 보관합니다. 그림 크기는 충돌·HP·탑승 조건을 변경하지 않습니다. 숲의 상점과 첫 퀘스트 주민은 대표 화면 구성을 위해 분수 가까이 배치하며 기존 전체 몸체 검사를 사용합니다.

## SRD 저작자 표시

This work includes material taken from the System Reference Document 5.1 (“SRD 5.1”) by Wizards of the Coast LLC
and available at https://www.dndbeyond.com/srd. The SRD 5.1 is licensed under the Creative Commons Attribution
4.0 International License available at https://creativecommons.org/licenses/by/4.0/legalcode.

이름은 한국어로 옮겼으며 실시간 전투 수치·능력·지역 보상 및 시각 디자인은 이 게임에 맞게 변경했습니다.

Flutter 전용 `actors-roll.png`는 전사·마법사의 웅크리기·구르기·회복 포즈를 생성한 그림이며, `roll-bounds.json`은 원본의 실제 프레임 경계를 기록합니다. 이동은 연속 방향이며 구르기는 8방향·4포즈를 사용합니다. `terrain-materials.png`는 초원·숲 바닥·모래·물가·수면·흙길의 작은 질감으로 생성했습니다. 두 원본은 `/workspace/generated_images/exec-b36bab82-79de-4211-ba99-b6755a0b19f3.png`, `/workspace/generated_images/exec-1bb1282c-1e9d-4f8b-8d26-52143c977a9e.png`입니다.

앱 설치 아이콘 `flutter_game/web/icons/guardian.png`는 청록 방패·금빛 잎 문양으로 생성한 독자 아이콘입니다. 원본은 `/workspace/generated_images/exec-dcade548-2fd8-4ed2-b363-793b12fe23a4.png`입니다.
