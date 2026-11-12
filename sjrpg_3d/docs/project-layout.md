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
| `scripts/gameplay/{actors,combat,loot,quests,dungeon,travel,expeditions}/` | 플레이 규칙·진행. 렌더러가 이 규칙을 다시 구현하지 않음 |
| `scripts/world/{geometry,physics,map}/` | 공유 지형 설계·실제 충돌/이동·지도 동기화 |
| `scripts/ui/{screens,panels,hud,widgets,style}/` | 화면·패널·HUD·재사용 컨트롤·스타일 |
| `scripts/rendering/` | `WorldRenderer3D`와 배우·건축·환경·지형·식생·효과·재질·가림 표시 모듈 |
| `scripts/inspection/` | 검수용 배치·관찰 코드. 운영 규칙의 대체 구현을 넣지 않음 |

`WorldRenderer3D`는 실제 운영 표시기입니다. 소유 참조는 `game.world_renderer`, 표시 모듈이 받은 참조는 `renderer`/`_renderer`로 씁니다. `ModelSceneLibrary`와 `ArchitectureSceneLibrary`는 씬 캐시이고, `EnemyRenderer3D` 같은 표시 모듈은 게임 상태를 읽어 모델을 갱신합니다. UI에서 장비 비교를 의미하는 `preview`나 실제 검수 옵션은 그 의미대로 사용합니다.

파일은 `snake_case`, 전역 클래스는 `PascalCase`, 3D 공간 전용 클래스는 필요할 때 `3D` 접미사를 사용합니다. 자산 식별자는 `asset_id`, 씬 경로는 `*_scene_path`, GLB 경로는 `*_model_path`처럼 내용을 구별합니다. 벡터는 화면 좌표/미터 좌표를 구분하고 변환은 공용 좌표 함수를 거칩니다.

## 제작·검사 도구

- `tools/assets/<분류>/`: 재현 가능한 모델·재질·이미지 제작/변환 도구.
- `tools/review/models/`: 모델 렌더·비교 캡처·진단 도구. 운영 모델을 보관하지 않습니다.
- `tools/extract/`: 원본 데이터·평면 원화의 추출/측정 규격.
- `tests/cases/`: 실행 회귀 검사. 일회성 캡처·이전/이후 비교·이동 증빙은 무시된 `build/`에 둡니다.

`tools/check_resource_layout.py`는 모델 소유 폴더·진입 씬·정적 리소스 연결을, `tools/check_script_resources.gd`는 운영·검수·테스트 스크립트를 먼저 컴파일하고, 자산별 검사는 GLB 내용·제작 해시·슬롯·예산을 확인합니다. `tools/check.sh`와 루트 `tools/ci.sh`에서 함께 실행합니다. 독립 모델 납품 범위와 물리/규칙 경계는 [에셋 협업](asset-workflow.md)을 따릅니다.
