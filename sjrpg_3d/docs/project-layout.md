# 폴더와 이름 규칙

운영 자산은 용도별로 찾고, 개별 모델의 변경은 그 모델 폴더에서 끝냅니다. `res://`는 `sjrpg_3d/` 기준입니다.

## 자산

| 경로 | 책임 |
| --- | --- |
| `assets/models/<분류>/<이름>/` | 개별 입체 자산의 `model.glb`, 운영 진입 씬 `visual.tscn`, 전용 이미지·셰이더·규격 |
| `assets/models/<분류>/shared/` | 같은 모델 계열이 공유하는 씬 스크립트·레이아웃 규격 |
| `assets/materials/<계열>/` | 여러 모델·지형이 공유하는 텍스처·셰이더·표면 어댑터 |
| `assets/ui/{entry,selection,hud,skills}/` | 시작 화면·선택 화면·HUD·스킬 아이콘 |
| `assets/effects/` | 효과 전용 이미지·셰이더 |
| `assets/sprites/` | 운영에서 사용하는 평면 원화·호환 표현 자산과 Canvas 셰이더 |
| `assets/data/` | 게임 규칙·배치·제작 명세. 지형 분류/거리장 PNG도 색 그림이 아닌 데이터로 보관 |
| `assets/source/<분류>/` | 원본·생성 입력·라이선스·출처·변환 기록. `.gdignore`로 운영 패키지에서 제외 |

예를 들어 마법사는 `assets/models/heroes/mage/visual.tscn`으로 생성하며 같은 폴더의 `model.glb`와 추출 텍스처를 읽습니다. 분수·워프문·마을 참나무·주민도 같은 계약입니다. 모델이 다른 그림 폴더의 GLB를 불러오는 우회 구조는 사용하지 않습니다. 공용 돌·나무·잔디 재질은 `assets/materials/`에서 공유합니다.

제작 원본·외부 자료의 파일명과 출처 식별자는 추적 가능하도록 보존합니다. GLB에서 추출한 텍스처 파일명은 임베디드 이미지 이름을 반영하므로 `model_cloth-0.png`처럼 외부 이름을 유지할 수 있습니다. 이름 정리만을 위해 원본 GLB·이미지를 재인코딩하지 않습니다. 임포트 설정과 UID도 자산과 함께 이동합니다.

## 코드

| 경로 | 책임 |
| --- | --- |
| `scripts/app/` | 진입 화면·게임 조립·`Adventure3D` |
| `scripts/state/`, `core/`, `input/`, `audio/` | 저장 상태·좌표/공통 계산·입력·소리 |
| `scripts/gameplay/{actors,combat,loot,props,quests,dungeon,travel,expeditions}/` | 플레이 규칙·진행. `props/`는 나무 등 환경 오브젝트의 상태. 렌더러가 규칙을 다시 구현하지 않음 |
| `scripts/world/{geometry,physics,map}/` | 공유 지형 설계·실제 충돌/이동·지도 동기화 |
| `scripts/ui/{screens,panels,hud,widgets,style}/` | 화면·패널·HUD·재사용 컨트롤·스타일 |
| `scripts/rendering/` | `WorldRenderer3D`와 배우·건축·환경·지형·식생·효과·재질·가림 표시 모듈 |
| `scripts/inspection/` | 검수용 배치·관찰 코드. 운영 규칙의 대체 구현을 넣지 않음 |

`WorldRenderer3D`는 실제 운영 표시기입니다. 소유 참조는 `game.world_renderer`, 표시 모듈이 받은 참조는 `renderer`/`_renderer`로 씁니다. `ModelSceneLibrary`와 `ArchitectureSceneLibrary`는 씬 캐시이고, `EnemyRenderer3D` 같은 표시 모듈은 게임 상태를 읽어 모델을 갱신합니다. UI에서 장비 비교를 의미하는 `preview`나 실제 검수 옵션은 그 의미대로 사용합니다.

파일은 `snake_case`, 전역 클래스는 `PascalCase`, 3D 공간 전용 클래스는 필요할 때 `3D` 접미사를 사용합니다. 자산 식별자는 `asset_id`, 씬 경로는 `*_scene_path`, GLB 경로는 `*_model_path`처럼 내용을 구별합니다. 벡터는 화면 좌표/미터 좌표를 구분하고 변환은 공용 좌표 함수를 거칩니다.

클래스 이름은 현재 책임을 나타냅니다. 새 클래스에 3D 전환 이력만을 나타내는 `Native` 접두사를 붙이지 않습니다. 몬스터 씬 캐시는 `EnemyAssets`, 개별 GLB의 표시와 클립 샘플링은 `EnemyVisual`, 게임 상태를 읽는 표시 어댑터는 `EnemyRenderer3D`입니다. 모델 계열의 공용 파일은 해당 폴더의 `shared/catalog.gd`·`shared/visual.gd`로 찾습니다.

이 규칙은 신규 클래스와 책임을 바꾸는 모듈에 적용합니다. 기존 클래스·검사 파일의 접두사를 일괄 변경하는 것을 기능 수정의 완료 조건으로 삼지 않습니다. 테스트 이름·외부 제작 원본·진단 키의 호환성과 참조 비용을 함께 판단합니다.

## 제작·검사 도구

- `tools/assets/<분류>/`: 재현 가능한 모델·재질·이미지 제작/변환 도구.
- `tools/review/models/`: 모델 렌더·비교 캡처·진단 도구. 운영 모델을 보관하지 않습니다.
- `tools/extract/`: 원본 데이터·평면 원화의 추출/측정 규격.
- `tests/cases/`: 실행 회귀 검사. 일회성 캡처·이전/이후 비교·이동 증빙은 무시된 `build/`에 둡니다.

`tools/check_resource_layout.py`는 모델 소유 폴더·진입 씬·정적 리소스 연결을, `tools/check_script_resources.gd`는 운영·검수·테스트 스크립트를 먼저 컴파일하고, 자산별 검사는 GLB 내용·제작 해시·슬롯·예산을 확인합니다. `tools/check.sh`와 루트 `tools/ci.sh`에서 함께 실행합니다. 독립 모델 납품 범위와 물리/규칙 경계는 [에셋 협업](asset-workflow.md)을 따릅니다.

## 공용 계산과 이름

- `WorldSpace3D`가 투영된 Node2D 월드 좌표 ↔ X/Z 미터 좌표 변환과 미터당 배율을 소유합니다. 게임 규칙·물리에서 배율을 얻으려고 렌더러를 참조하지 않습니다. 높이가 이미 반영된 효과 위치는 `elevated_projected_to_world()`로 발치 투영을 제거합니다.
- `ModelTree3D`는 루트 포함 메시, 첫 애니메이터/골격, 중복 없는 씬 경로를 읽습니다. 실제 인스턴스의 자식은 `owner`가 없어도 탐색하며 노드를 변경하지 않습니다.
- `UiMetrics.units_per_display_pixel()`은 논리 뷰포트 단위와 표시 픽셀의 비율입니다. 웹에서는 CSS 픽셀을 사용하고 DPR을 중복 적용하지 않습니다. UI의 기존 배율 메서드는 레이아웃 테스트가 재정의하는 경계로 유지합니다.

불리언은 `_uses_mage_model`처럼 조건을, 서비스 참조는 `_enemy_renderer`·`_resident_renderer`처럼 책임을 나타냅니다. 거리·높이·배율의 이름에는 `*_m`, `*_pixels`, `*_PER_METER`처럼 단위를 드러냅니다. 주석은 현재 책임·단위·제약을 설명하며, 이미 끝난 전환 작업의 지시나 옛 비교 모드를 운영 설명으로 남기지 않습니다. 미사용 여부는 일반 호출뿐 아니라 신호·Callable·문자열 조회·엔진 콜백도 확인한 뒤 판단합니다.

미터 단위 수치 필드·변수는 `height_m`·`death_floor_m`·`distance_m`처럼 `_m`을 사용합니다. 반환 단위를 이름으로 설명하는 GDScript API는 `radius_metres(radius_pixels)`·`pose_lift_metres()`처럼 `_metres()`를 사용합니다. 두 표기는 동일한 미터 단위이므로 JSON 필드를 읽을 때 표기 차이를 이유로 추가 배율을 적용하지 않습니다. 기존 자산 스키마·셰이더 uniform·검수 출력의 키는 해당 생산자와 소비자가 공유하는 계약이므로 새 이름 규칙을 이유로 일괄 교체하지 않습니다.

신규·수정하는 거리·높이 상수는 `MODEL_HEIGHT_M`·`COMBAT_RADIUS_M`처럼 `_M`, 픽셀과 미터 사이의 비율은 `*_PIXELS_PER_METER`처럼 단위 비율을 표시합니다. 공용 API가 실제로 `Dictionary` 또는 `null`을 반환한다면 `-> Variant`로 그 계약을 명시하며, 이름·타입 정리만을 위해 빈 Dictionary로 반환 의미를 바꾸지 않습니다.
