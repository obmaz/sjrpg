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

`flutter_game/art/entry-scene.webp`·`class-selection.webp`·`entry-ui.webp`는 로딩·게임 내 초상 등에 쓰는 기존 생성 그림입니다. 인물 없는 차분한 숲 마을과 석재·무광 청동 UI를 사용하며, 넓은 무광 강철 갑옷과 양손 검을 든 남성 전사, 가느다란 체형의 짙은 남색 천 로브·마법서·지팡이를 든 남성 마법사를 구분합니다. 금속 반사와 옷의 장식을 줄이고 마법의 빛은 지팡이 끝에만 작게 남겨 인물과 직업 실루엣이 먼저 보이도록 합니다. 최종 직업 그림의 무기 끝은 각 절반 안에 보존합니다. 전사 HUD와 선택 카드에는 선택된 녹색 망토 전사의 별도 초상을 사용하고, 마법사 초상은 기존 그림을 사용합니다. 실행 그림은 배경 768×1152, 직업·UI 아틀라스 각각 1024×683 WebP입니다. `entry-splash.webp`는 기존 로딩 그림의 원본 비교용으로 보존하며, 첫 로딩에는 작은 `entry-crest.webp`·`entry-loading-bar.webp`를 사용합니다. 문구·선택 상태·진행 표시·버튼 동작은 그림에 굽지 않고 Flutter와 HTML로 구현합니다. [전체 UI 시안](art/entry-ui-reference.webp)의 임시 영문 라벨은 실행 그림에 포함하지 않습니다. 기존 게임의 아트는 바꾸지 않습니다.

`flutter_game/art/combat-fx.png`는 함성·소용돌이·서릿발·번개·유성·격노·빙결 방패·타격을 위해 생성한 4×2 투명 이펙트 아틀라스입니다. 표시만 담당하며 판정과 재사용 시간은 게임 코드에서 처리합니다.

`flutter_game/art/encounter-beacons.webp`는 숲·사막·고대·미래의 재소환 표식을 위해 생성한 투명 그림입니다. 각 지역의 대기·준비 모습을 측정한 영역으로 잘라 같은 끝점에 맞춥니다. 그림에 바닥이나 그림자를 굽지 않고 비고체 투영 아래의 그림자와 적중 표시는 코드로 그립니다.

`flutter_game/art/actors-mage.png`는 기존 모험가 그림을 참조해 생성한 마법사 전용 16방향 × 두 걸음 투명 시트입니다. `mage-bounds.json`은 각 셀의 알파 경계를 측정한 표시 데이터입니다. 원본 생성 PNG를 보존하며 게임에서 방향별로 잘라 표시합니다. `flutter_game/art/gear-icons.png`는 장비 24종을 6×4로 생성한 인벤토리 전용 그림입니다. 스킬 효과는 생성형 아틀라스와 코드 연출을 결합하며, 팝업은 Flutter 위젯으로 구성합니다. 기존 `assets/popup-frame.webp`는 Legacy에서 사용하고 Flutter에서는 디코딩하지 않습니다.

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

새 모험의 광신도(`cultist`)는 기존 생성형 8방향 그림을 사용하며 D&D 계열 이름을 참고한 독자 전투 패턴입니다. 시전 예고·목표 고정·직선 투사체·기절 중단을 적용하고 생명·피해·주기는 모바일 전투에 맞춰 조정했습니다.

`flutter_game/art/dodge-icon.png`는 가죽 장화와 청록 잔상을 생성한 회피 버튼 그림입니다. 투명 원본 `/workspace/generated_images/exec-bfece1ee-3409-4b43-a45e-97d4d647083f.png`를 보존하고 배포용은 256px로 준비합니다. 실제 구르기·방향·무적 판정은 캐릭터 코드가 담당합니다.

장비 목록 초안 `docs/art/equipment-mobile-reference.webp`는 이 게임을 위해 생성한 단일 화면 장비 UI 시안입니다. 원본은 `/workspace/generated_images/exec-91fb037f-1f08-4ab2-b7ad-6c0dd0eaa822.png`이며, 런타임은 기존 생성형 장비 그림을 사용하고 비교·바로 장착·인라인 옵션을 Flutter 위젯으로 구현합니다. 시안의 문구와 수치는 실제 장비 모델을 따르도록 적용합니다.

전투 애니메이션 `flutter_game/art/fx-meteor.webp`·`fx-ice-nova.webp`는 이 게임을 위해 생성한 각 16프레임 4×4 효과 시트입니다. 원본은 각각 `/workspace/generated_images/exec-d4379692-c85e-4a0a-b1ee-2286206e6830.png`·`/workspace/generated_images/exec-525696d9-0f57-4f62-8779-1bc33fd12720.png`이며, 투명도를 보존해 1024×1024 WebP로 준비했습니다. 운석의 비행·폭발과 얼음의 성장·파쇄를 서로 다른 실제 그림 프레임으로 재생하고, 충돌·중력 파편·파동·갑옷 결정은 코드로 결합합니다.

`flutter_game/art/fx-whirlwind.webp`는 비어 있는 중앙 주위로 베기·바람·먼지가 모였다가 흩어지는 16프레임 소용돌이 시트입니다. 생성 원본은 `/workspace/generated_images/exec-4e38067a-cf06-457d-a966-05e0d667192d.png`이며 투명도를 보존해 1024×1024 WebP로 준비했습니다. 이 이전 시트와 `SpellClip.whirlwind` 정의는 보존하지만 현재 Flutter 전투에서는 디코딩·재생하지 않습니다. 실제 소용돌이는 `SteelWhirlwind`가 주인공 뒤에 붉은 연속 삼각형 궤적·밝은 끝·짧은 파편을 그립니다. 구형 `fx-steel-whirlwind.webp`도 출처·회귀 비교용으로 보존하지만 단계별 플레이에서 다운로드·디코딩하지 않습니다.

`flutter_game/art/passive-icons.webp`는 전투 집중·전장의 맹세·고양의 울림·온기·냉기 숙련·번개 숙련의 전용 그림 6종을 담은 3×2 아틀라스입니다. 생성 원본은 `/workspace/generated_images/exec-8f84cf7a-27a5-4a77-8a5b-fef1e2ce266a.png`이며 투명도를 보존해 768×512 WebP로 준비했습니다. 트리와 설명 창은 같은 그림을 사용하고 기존 전투 효과와는 별도 텍스처로 읽습니다.

`flutter_game/art/fx-warcry.webp`는 금빛 함성 충격파가 생겨 퍼지고 파편으로 흩어지는 16프레임 시트입니다. 생성 원본은 `/workspace/generated_images/exec-c249e696-e899-4b9d-a011-bf8a32a9ef02.png`입니다. 원본의 4×4 셀을 각각 224px로 준비해 16px 투명 여백과 함께 1024×1024 WebP로 배치하므로 인접 프레임을 샘플링하지 않습니다. 이 시트는 출처·비교용으로 보존하며 단계별 플레이에서는 다운로드·디코딩하지 않습니다. 실제 전사 함성은 `BarbarianUtilityVisual`과 `BarbarianVfx`가 기술별 압력선·파편을 그립니다.

`flutter_game/art/fx-crushing-blow.webp`는 집중 강타의 내려베기·금빛 접촉·돌 파편·먼지 정착을 위해 생성한 16프레임 4×4 시트입니다. 원본 `/workspace/generated_images/exec-88fcbeae-1cd0-43b3-a505-625dc64a37c9.png`의 각 장면을 측정한 접촉점에 맞춰 256px 셀의 `(128, 180)`에 고정했고, 모든 셀에 최소 16px 투명 여백을 둡니다. 정렬·원본 장면 순서·준비 수치는 `fx-crushing-blow-source.json`에 보존합니다. 앞 두 프레임은 실제 준비 동작의 마지막에, 나머지 14프레임은 피해가 발생하는 순간부터 재생합니다. 등급과 실제 충전량에 따라 그림 크기와 코드로 날리는 흙빛 파편을 더하며, 마법진 없이 캐릭터 아래의 지면 효과로 그립니다.

`flutter_game/art/quest-sites.webp`는 필수 퀘스트의 뿌리 우물·달빛 샘·태양 제단을 각각 다른 형태로 생성한 3열 아틀라스입니다. 원본 `/workspace/generated_images/exec-06c4015c-de0b-42ba-a057-70a059b3dc37.png`의 각 물체를 투명 여백·일관된 바닥 기준으로 512px 셀에 준비했습니다. 기존 `assets/actors-vehicles.webp` 원본은 보존하며, Flutter 탈것은 종류별 `actors-bicycle.webp`·`actors-motor.png`·`actors-horse.png`·`actors-boat.png`와 측정한 방향/동작 경계를 사용합니다. 이전 공용 시트는 Flutter에서 디코딩하지 않습니다.

Flutter 후속 지도·의뢰는 `stage_content.dart`와 `AdventureWorld`의 지역별 지형에서 관리합니다. 제2장 의뢰는 두 시간축에 네 개씩이며 선행 의뢰·처치 목표·고유 성소·도착 스테이지가 연결됩니다. 새 지역은 `WorldStage`와 체크포인트 검증, 실제 렌더링·충돌·도로 접근 검사도 함께 연결해야 합니다.

Flutter 상점 재고는 `Progress.shopGear`가 정의하며 UI와 실제 구매가 함께 사용합니다. 신규 판매 장비를 추가할 때 직업·레벨·실제 정의·구매 가격·카테고리를 연결해야 합니다. 고유 `sentinel` 부적은 숲 보스의 추가 보상이며, 희귀 무기 보상과 별도로 한 번 지급합니다.

`flutter_game/art/actors-viper.webp`는 독사의 여덟 방향·두 S자 보행 자세를 위해 생성한 투명 아틀라스입니다. 생성 원본은 `/workspace/generated_images/exec-52d1d81e-8ee8-4844-b198-9a81f45c1720.png`이며, 전체 꼬리를 보존해 960×640 무손실 WebP로 준비했습니다. `actors-viper-bounds.json`은 방향별 몸체 그림의 알파 경계와 지면 중심 기준점을 기록합니다.

제4·5장 전용 `actors-bonehound.webp`·`actors-clockwork-spider.webp`·`actors-crystal-beetle.webp`는 각각 뼈 사냥개·태엽 거미·수정 갑충의 여덟 방향×두 보행 자세를 생성한 투명 그림입니다. 원본은 `/workspace/generated_images/exec-4784e935-556e-4828-a06f-e7047cf1e125.png`·`/workspace/generated_images/exec-8ca85511-6e4e-412e-8321-d7d754a9e5be.png`·`/workspace/generated_images/exec-ab86afa6-f48a-414b-8c9a-48a96f066961.png`입니다. 원본에서 분리된 16개 몸체를 꼬리·다리·뿔까지 측정하고 종마다 같은 배율로 768×640 무손실 WebP에 여백을 두어 준비했습니다. 각각의 `-bounds.json`은 실제 그림 경계와 지면 기준점을 기록합니다.

Flutter 대장간의 투명 그림 `flutter_game/art/blacksmith-forge.webp`는 숲 마을의 청록 천막·목재·석조 화로·금속 모루 스타일로 생성한 원본 `exec-592b7727-a1c6-4ad0-904d-4b9a01cb2a44.png`를 512×458 WebP로 준비합니다. 배경을 합성한 타일이 아닌 고체 작업장 물체로 사용하며 열린 바닥과 실제 기구의 충돌 범위를 분리합니다.

`flutter_game/art/fx-level-up.webp`는 금빛 지면 고리와 중앙이 열린 상승 빛의 생성형 16프레임 시트입니다. 원본·해시는 `docs/art/level-up-provenance.json`과 `level-up-original.png`에 보존합니다. `prepare-combat-illustrations.py --preset level-up`이 셀을 분리하고 투명 여백을 넣어 1024² WebP로 준비합니다. 런타임은 프레임을 보간하고 주인공 뒤에 그려 본체를 가리지 않습니다.

D1 기술·메뉴·상태 그림은 `docs/art/d1-icons-provenance.json`에 원본·런타임 해시를 보존합니다. 전사 30종·마법사 30종·공용 32종을 `tools/prepare-d1-icons.py`로 원본 알파에서 각 원형 버튼의 실제 경계를 측정한 뒤 중심을 맞춘 셀과 투명 여백에 패킹하며 그림을 다시 그리거나 겹쳐 합성하지 않습니다. 사용 순서는 기존 직업 아이콘 ID와 공용 D1 인덱스를 따릅니다. 원형 초상과 게이지는 코드에서 동일 프레임에 연결하며 이미지의 가로세로 비율을 보존해 크롭합니다.

가로형 직업 선택은 사용자가 제공한 `Guardians_of_Nature_Character_Select_Assets.zip`의 카드·설명 패널·시작/뒤로 버튼·제목 PNG를 사용합니다. `docs/art/guardian-selection-provenance.json`에 ZIP 해시와 개별 자산의 출처·해시를 기록합니다. `select-scene.png`는 첨부 원화의 인물과 지형을 보존하면서 문구·카드·패널을 제거해 생성한 통합 풍경입니다. 흰 외곽선과 발 잘림이 있는 별도 컷아웃 대신 이 풍경 위에 실제 선택 UI를 배치합니다. 제공된 배치 좌표는 `guardian-selection-layout.json`에 보존하며, 현재 존재하는 전사·마법사 두 카드만 표시합니다.

## 마을문·참고 메뉴

`docs/art/village-ui-original.png`는 image_gen으로 제작한 투명 마을문·메뉴 원본입니다. 참고 이미지의 초록 지붕·목재·석조 마을문과 얇은 청동 원형 테두리의 상자·검 문양 책·퀘스트 두루마리·철제 톱니바퀴를 반영합니다. `tools/prepare-village-ui.py`는 개별 알파 경계를 측정해 `village-gateway.webp`와 `reference-menus.webp`로 패킹하며, 원본 해시·자르기 좌표는 `docs/art/village-ui-provenance.json`에 보존합니다. `docs/art/settlement-forest-open-approach-original.png`는 기존 남문 기둥만 제거한 생성형 배경 원본입니다. 숲 마을 남문은 실제 통과 가능한 남쪽 성벽 틈에 열린 문 그림을 맞추며, 배경에 구형 문이 중복으로 남지 않게 합니다.

현재 전투 HUD·일반 버튼은 `cinematic-interface.webp`의 흑철·청동 원형 그림을 사용합니다. 몬스터 21종은 `actors-cinematic-*`의 새 방향별 원본으로 교체하며 이전 몬스터 시트의 배포 복사본은 제거합니다. 공격의 검격·얼음·번개·화염 그림은 아래 공통 이펙트 시트를 사용합니다. 원본과 재현 과정은 [전투 화면 원본](art/cinematic/README.md), 캐릭터의 네이티브 384px 재렌더링은 [캐릭터 동작](art/character-motion.md)을 참고합니다.

공통 전투 이펙트 `combat-illustrations.webp`는 검격·냉기·번개·화염을 각각 생성한 투명 원본 네 장을 사용합니다. 원본·측정 경계·해시는 [생성 이펙트 출처](art/cinematic-combat-vfx-provenance.json)에 기록하며, `tools/prepare-cinematic-combat-vfx.py`가 서로 닿지 않는 실제 알파 경계를 검사해 2×2 시트로 준비합니다. 런타임은 팽창·잔상·페이드와 기존 무기 궤적·입자를 조합합니다.

## 지역별 대형 지형물

일곱 지도에 각 4개, 총 28개의 대형 지형물을 생성형 이미지로 제작합니다. 높은 대각선 쿼터뷰와 왼쪽 위 광원을 사용하며 투명 배경의 원본은 [field-landmarks](art/field-landmarks/)에 보존합니다. 연결된 주요 알파 실루엣과 주변 파편을 측정해 개별 그림을 분리하고 32px 여백의 2×2 런타임 시트에 패킹합니다. 원본·개별 경계·생성 ID·SHA-256은 [provenance.json](art/field-landmarks/provenance.json), 재현 도구는 `tools/prepare-field-landmarks.py`입니다. 실제 월드 배치와 충돌은 `FieldLandmark`, 간결한 지도 윤곽은 `TerrainMapPlan`이 같은 좌표를 공유합니다.
