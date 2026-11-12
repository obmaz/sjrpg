# 3D 개발 구조

현재 개발 대상은 `sjrpg_3d/`입니다. 2D판은 동결하며, 루트는 버전 선택·공통 빌드만 담당합니다. [전체 구조](../../docs/development.md)와 [3D 제작 기준](../../docs/3d-asset-guide.md)이 기준입니다.

공용 좌표 변환은 `WorldSpace3D`, 모델 트리 조회는 `ModelTree3D`, UI 표시 배율은 `UiMetrics`에서 관리합니다. 사용 단위와 호출 경계는 [폴더와 이름 규칙](project-layout.md#공용-계산과-이름)을 따릅니다.

## 실행과 상태

- `Adventure3D`가 모험 진입점입니다. `SpatialWorld3D`의 실제 몸체·높이·충돌이 공간 기준입니다.
- 기존 `Game`, `Player`, `Enemy`는 진행·AI·UI 호환 어댑터입니다. 화면 좌표를 실제 X/Z 지면과 Y 높이로 변환합니다.
- `SpatialCombat3D`가 높이·벽·몸체를 기준으로 근접 공격과 투사체를 제한합니다. 피해·재사용 시간·저장은 기존 규칙을 공유합니다.
- `WorldRenderer3D`는 마을·숲·기존 동굴의 운영 공간 표시기입니다. 소유 참조는 `game.world_renderer`, 모듈의 표시기 참조는 `renderer`로 통일합니다.
- 카메라는 방위45°·고도35.2643897° 직교 투영입니다. HUD와 미니맵은2D UI이며, 지면·물·효과·알파 잎의 평면은 입체 물리와 함께 사용합니다.

이동은 네이티브 캡슐 스윕과 미끄러짐을 보존하고, 바닥에 맞춰 높이를 보정할 때 추가 충돌을 확인합니다. 모든 이동 뒤에 겹침 여부만으로 되돌리면 정상적인 교대 모서리 접촉도 막힙니다. `native_bridge_sweep`는 30가지 이동 간격·진입 위치를 검사하며, `native_threshold_support`는 실제 접촉 깊이를 측정하고, 벽 안으로 3cm 이동한 검사 캡슐은 관통으로 검출되는지도 확인합니다.

가림 처리 모듈은 `scripts/rendering/occlusion/`에 모았습니다. [전체 오브젝트 전환](../scripts/rendering/occlusion/player_occlusion.gd), [공간 색인](../scripts/rendering/occlusion/spatial_index.gd), [로딩 중 재질 준비](../scripts/rendering/occlusion/warmup.gd)를 나눕니다. 공간 색인은 재질이나 게임 상태를 변경하지 않으며 표시기는 실제 삼각형 검사와 전체 모델 투명도만 담당합니다.

`NativePlayerOcclusion`은 실제 카메라 방향으로 발·몸통·머리의 가림을100ms 간격으로 검사합니다. 바운딩 박스 검사 뒤 공유 메시별 TriangleMesh BVH로 실제 삼각형을 확인하므로 성벽의 빈 안뜰이나 모델의 빈 틈은 가림으로 판단하지 않습니다. `mark_object(root)`로 지정한 정적 모델의 어느 부품이 가리면 전체 부품을 하나의 전환 상태로 묶어 약20% 불투명도까지 함께 조절하고 함께 복원합니다. StandardMaterial·ShaderMaterial 모두 같은 알파 승수를 적용하며 부분 마스크나 디더링은 사용하지 않습니다. `StaticMeshBatch3D`는 재질별 배칭 후에도 원래 오브젝트 소속과 CPU 변환을 보존합니다. 나무·수풀은 `occlusion_static_instances`로 지정한 MultiMesh에서 개별 인스턴스 전체를 처리합니다. 몬스터·배우·NPC는 정적 모델로 등록하지 않으며, `occlusion_dynamic` 하위와 실제 CharacterBody3D·Skeleton3D 하위도 제외합니다. 연속된 지면·물·길은 등록하지 않습니다. `warm_up()`이 플레이 준비 완료 전에 공유 BVH·재질 원형을 만들고 `NativeOcclusionWarmup`의64×64 별도 뷰포트에서 한 번 실제로 그립니다. 이는 [Compatibility의 첫 셰이더 컴파일 지연](https://docs.godotengine.org/en/stable/tutorials/rendering/jitter_stutter.html#stutter)을 로딩 단계에서 처리하기 위한 것입니다. 정적 월드 변환·AABB·역변환을 재사용하며8m 공간 셀로 시선 구역에 있는 후보만 검사합니다. 배칭 노드별로 변환을 한 번 확인하므로 재배치와 삭제도 색인에 반영합니다.  같은 오브젝트의 같은 재질은 공유합니다. 최근16개 오브젝트는 분리한 표시 노드와 재질을 보관하며 원본 슬롯/재질을 복원한 뒤 숨깁니다. 활성 전환은 캐시 퇴출에서 보호하고, 퇴출 재질은 렌더 서버 참조가 끝나도록3프레임 유지합니다. 물리·진행 상태는 수정하지 않으며 일시정지 중 전환도 멈춥니다. 브라우저 검수의 `at=occlusion`·`at=tree_occlusion`과 `probe=1&occlusion=off`로 비교할 수 있습니다.

`Player.MOVE_SPEED_MULTIPLIER=1.2`는 기존 직업별 속도·이동 패시브·질주 보너스·게임 템포에 곱하는 주인공 전용 이동 배율입니다. 공격·투사체·적의 속도와 구르기 거리/시간은 이 배율을 읽지 않습니다. 달리기 동작은 실제 이동 거리로 샘플링해 빨라진 발걸음과 맞춥니다.

`Player.contact_serial`은 실제 근접 공격의 첫 명중만 알리며, 네이티브 전사와 GLB 모션은 접촉 자세를 적용한 뒤 정지합니다. `Enemy.hit_reaction_age`는 로컬 히트스톱 뒤에 흐르고 `EnemyRenderer3D`의 흉곽·머리·무기 반응을 구동합니다. `HitFeedback3D`는 실제 명중 효과의 접촉점/단계를 관찰해 재사용하는 파편과3D 장면 전용 초점 셰이더를 표시합니다. 숫자는 원본 `Effect`의 크기·팝·표시 대기(40ms 간격/상한200ms)를 그대로 읽고 소리는 재질 악센트와 강한 명중의 우선순위를 적용합니다. 피해·공격 간격은 이 연출에서 계산하지 않습니다. 현재 수치·예산·동작 줄이기와 검증 방법은 [타격감](juice.md)을 따릅니다.

배우 연결 문자는 실제 발을 읽고, 자유 배치 문자는 `Effect.anchor_text_ground()`의 생성 지면과 화면 여백을 분리합니다. 상자·시체·보상에 별도 물리 배우를 만들거나 피해 숫자의 표시 대기에 넣지 않습니다.

## 원정 진행과 기술 확장

`GameState.expedition`은 현재 원정, `expedition_meta`는 명성과 챕터 완료 기록입니다. 기존 저장 슬롯 안에 보관하며 필드가 없는 예전 저장은 기존 진행을 유지합니다. `scripts/gameplay/expeditions/`에 상태 검증, 저장용 캐릭터 스냅샷, 선택/룬, 월드 어댑터, UI를 분리했습니다. `ExpeditionSaveRules`는 원본 캐릭터의 장비·의뢰·웨이포인트 자료와 현재 기술 슬롯/보상 단계의 관계를 적용 전에 검사해 부분 복구를 막습니다. `SaveStore.write()`도 새 문서를 검증한 뒤 기록해 잘못된 상태로 주 파일/백업이 교체되지 않게 합니다. 선택과 결산 저장에 실패하면 기존 상태로 되돌리고 월드를 교체하지 않습니다.

챕터/계약과 룬은 `assets/data/expeditions/`, 새 기술은 `assets/abilities/<id>/ability.json`이 소유합니다. `SkillDefs.base_def()`가 기본 행동을, `RunBuild.definition()`이 원정 룬을 적용한 행동을 반환합니다. 투사체의 관통과 갈래는 실제 `Effect`에 전달하며, 흡수는 시전 식별자로 한 시전당 한 번만 지급합니다. 월드 재생성은 메뉴 재시작과 구별되는 `reload_requested`로 기존 로딩 화면을 거칩니다.

후속 챕터의 데이터/월드 어댑터 경계, 영속 수명, 검수 방법은 [원정 구조](expeditions.md)를 따릅니다.

## 지도

`MapWorldState`는 실제 건축 루트·성문 변환과 공유 지형 설계를 프레임당 한 번 확인하고 변경 시에만 두 지도용 도형과 메시를 갱신합니다. `MapGeometry`는 살아 있는 시설·진입 노드와 활성 동굴의 미개봉 상자에서 표식을 만들고, 동굴 귀환문은 완료 판정과 같은 `DungeonRuntime.return_portal()`을 읽습니다. `WorldMapCanvas`와 `MapPlaceRow`는 같은 번호/좌표를 표시합니다. 행은 터치 입력을 부모 스크롤에 전달하는 리스트 컨트롤이며, `GamepadNavigation`은 `gamepad_target`과 `pressed` 신호를 가진 비버튼 컨트롤도 탐색합니다. 상세 계약과 검사는 [지도 구조](world-map.md)를 따릅니다.

`PanelFrame`은 스크롤 안에 추가되는 버튼과 입력 경로를 `ScrollTouchSupport`로 준비합니다. 버튼의 드래그/휠을 부모 스크롤에 전달하고, 스크롤 시작 시 Godot의 버튼 취소 알림으로 클릭을 취소합니다. 슬라이더·스크롤바와 패널 밖 버튼은 입력을 계속 소유합니다. 가방 셀은 누를 때가 아니라 드래그 없는 릴리스에서만 선택합니다. `panel_scroll`은 동적 버튼·푸터·슬라이더·셀 탭/스와이프를, `tools/check_panel_scroll.mjs <URL> <출력폴더>`는 실제 모바일 설정과 가로 가방의 버튼 위 스크롤 및 탭 동작을 확인합니다.

## 저장과 입력

진행은 `GameState`, 설정은 `Prefs`가 담당합니다. 저장은 `data.get(키, 기본값)`으로 하위 호환을 유지합니다. 3D 저장 위치는 네이티브 `sjrpg_3d`, 웹 `/userfs/sjrpg_3d`입니다. [저장 슬롯](save-slots.md)을 따릅니다.

키보드·마우스·터치·Xbox 조작은 [프로젝트 안내](../README.md)를 따릅니다. 입력과 HUD는 실제 게임 상태를 읽으며 검수 observer가 게임 상태를 대신 만들지 않습니다. `PlayerActionBuffer`는100ms 단발 입력 하나만 보관하고 `TouchControls.release_all()`과 행동 취소가 이를 비웁니다. `DirectionalAim`의 전방±45°/각도 우선 규칙과 `Player.aim_direction()`의 최신 입력 방향을 `Player.aim_target()`·`aim_range()` 및 실제 시전·`AimTargetRenderer3D`가 공유합니다. 작은 자동 보정은 다음 공격의 입력 방향으로 누적하지 않으며, 돌진/직접 대상 재선택·상자/소환석도 뒤쪽을 선택하지 않습니다. `PlayerFootsteps`는 실제 보행 거리를 읽고 `SoundFx`는 CC0 PCM과 합성 악센트를8음성의 중요도 풀로 재생합니다. `RewardHudTrail`은 확정 지급 이후의 HUD 표시만 담당합니다. 현재 시간·접지·오디오 출처·표시 예산은 [타격감](juice.md)을 따릅니다. `directional_targeting`은 네 방향·새 입력·보정 누적·근접 뒤쪽 예외·대상 상실 후 재선택을 검사합니다. 실제 브라우저 터치 검수는 `tools/screenshot.mjs --scene directional_aim --device phone`으로 네 방향 적 중 조이스틱 방향의 실제 시전/발치 링을 확인합니다(`aim_preview=1` 전용 검수 장면).

`TouchControls.mobile_layout`은 세로 화면·터치 장치·네이티브 모바일을 인식합니다. 모바일 헤더/미니맵은 안전 영역 아래6단위 여백과 좌우가 같은 실제 테두리 여백을 사용하고, 세로 주 공격/조이스틱 중심은 각각 사용 가능한 높이의79%/78%입니다. 조이스틱의 기본 중심은 안전 영역 왼쪽에서 세로128단위·가로 터치136단위로, 이전보다24단위 오른쪽입니다. 가로 터치 화면은 바닥에서144단위, 데스크톱 가로는 기존178단위를 사용합니다. 실제 입력과 그림이 `_layout()`의 같은 버튼 좌표를 읽으며, 상호작용 패널도 옮긴 조이스틱·부채꼴을 피합니다. `hud_header`·`hud_layout`이 노치 여백·회전·메뉴 간격·터치 소유권을 확인합니다.

`BagPanel._gear_row()`는 가방·상점의 접힌 장비 행에도 현재 착용 장비와의 비교를 표시합니다. 비교 문구는 행의 터치·패드 선택을 가로막지 않으며, 펼친 상세에는 중복 표시하지 않습니다.

`TownPlazaPlan3D`가 분수 광장과 기존 주택 중심·전용 상점/대장간의 배치·NPC 접근·실제 충돌을 공유합니다. 기존 주택 자산을 보존하고 두 시설은 독립 GLB/씬으로 추가합니다. 길 거리장은 `capture_road_geometry.tscn`으로 실제 도로를 뽑아 `bake_ground_field.py`로 재생성하며 지도와 별개인 포장 좌표를 만들지 않습니다. 제작과 네 방향 검수는 [건물 계약](native-architecture-models.md#전용-시설과-광장)을 따릅니다.

## 제작과 유지보수

[문서 목록](README.md)에서 현재 영역별 제작 문서를 찾습니다. 공통2D 원화 제작 기록은 `../../sjrpg_2d/docs/`에 한 벌만 보존합니다. 이 기록을3D 기하·광원·충돌 규격으로 사용하지 않습니다.

`assets/source/`는 승인 스타일, 생성 원본, 라이선스·출처·재생성 기록입니다. 게임 패키지에는 넣지 않지만 재현에 필요한 입력이므로 유지합니다. 운영 자산은 `assets/models/`·`materials/`·`ui/`·`effects/`·`sprites/`와 `assets/data/`로 나눕니다. [폴더와 이름 규칙](project-layout.md)에 소유권과 재사용 경계를 정리했습니다.

주택의 `BuildingSurfaceMaterials`는 `fullFacade`의 벽 한 면 전체를 처마/박공 높이에 맞춰 한 번 배치합니다. `infillOnly` 원화에 문·창·기둥 그림을 넣지 않고 실제3D 구멍과 골조가 경계를 만듭니다. `NativeVillageSurfaces`는 전용 생성형 목재·석재·기와 조각을 공유하며 기단/계단/덮개와 광장 포장을 구별합니다. 원본·참조 해시·협업 경계는 [에셋 협업](asset-workflow.md)을 따릅니다.

예배당은 사용자가 재확인한 실제 게임 화면을 기준으로 전체 면 원화를 입힌 입체 구조를 사용합니다. 돌출 입구·두 박공·열린 종탑과 L자 몸체/왼쪽 계단은 [예배당](native-chapel-refinement.md)의 공유 설계를 따릅니다.

데이터 추출물은 `tools/extract/`에서 재생성합니다. 수치 단위는 원본 단위이며 HUD 체력·피해는100배, 자원은10배로 표시합니다. 조정은 추출 JSON을 수동 변경하는 대신 별도 설정으로 적용합니다.

## 검사와 내보내기

매 작업은 [완료 검수 기준](../AGENTS.md)의 관련 주변 범위까지 확인합니다. 건축 네 방향·재질/기하 경계·실제 충돌, 모바일 가로/세로 여백·입력, 동시/연속 전투·지역 전환과 자원 예산을 먼저 점검하고 명확한 결함을 함께 수정합니다. 실제 비교는 `build/`에 두며 `hud_header`·`combat_text_timing`·`village_structures`가 여백·숫자 표시·구조 충돌의 재발을 검사합니다.

저장소 루트에서 실행합니다.

```sh
tools/check.sh --project=3d
tools/check.sh --export
tools/serve.sh
```

테스트는 `tests/run_all.tscn`에서 `tests/cases/`를 탐색합니다. 정적 호출이 없다는 이유로 테스트 파일을 삭제하지 않습니다. 제작 도구의 Python import와 명령행 진입점도 참조에 포함합니다.

헤드리스 테스트 러너는 마지막 짧은 효과음의 자연 종료를 확인한 뒤 오디오 믹스와 메인 루프의 재생기 정리 경계를 기다립니다. 설정·효과음 재생기·캐시는 변경하지 않으며, 종료 대기가2초를 넘으면 검사를 실패 처리합니다.

`tools/import_project.sh`는 새 캐시에서 프로젝트 폰트를 먼저 요청한 첫 임포트가 리소스 생성을 마친 뒤 종료 코드134로 중단된 경우 한 번 재검사합니다. 스크립트 오류·미완료 임포트·두 번째 실패는 통과시키지 않습니다. 이 경계는 `python3 sjrpg_3d/tools/test_import_project.py`로 검증합니다.

[Web·Android 내보내기](platform-exports.md), [Android 설치·서명](android.md), [웹 성능](web-performance.md)을 따릅니다. UI·입력·렌더 변경은 실제 가로·세로 브라우저 검사를 추가하고, 배포는 전체 검사와 요청한 대상의 전달 결과를 확인합니다. 공개 페이지 실행은 웹 배포를 명시적으로 요청한 경우에만 확인합니다.

검수 캡처·일회성 진단 출력은 `build/`와 Actions 아티팩트에 둡니다. 저장소에 완료 스크린샷을 계속 쌓지 않습니다. 원본 출처와 현재 재현 방법은 관련 제작 문서에 유지합니다.

프레임 비용 전후 비교용 `tools/check_frame_pacing.mjs`와 `tools/perf/frame_pacing_observer.gd`는 남아 있지만 이를 실행하던 GitHub 워크플로는 제거했습니다. 관찰기는 임시 빌드에만 연결하며 실제 렌더 제출 간격과 읽기 전용 엔진 모니터를 수집합니다. 정상 운영 장면에 관찰기를 연결하거나 입력·게임 상태를 바꾸지 않습니다. 측정 범위와 한계는 [웹 성능](web-performance.md)을 참고하세요.

## 적 표시와 공격 피드백

`EnemyRenderer3D`는 모든 몬스터와 `visual_variant=cave_crawler`인 동굴 잠복자를 실제 입체 메시로 표시합니다. 메시·클립을 캐시하며, 골격·피격 재질은 인스턴스마다 분리합니다. 실제 `actor_foot()`·방향·모델별 실측 보폭으로 나눈 자력 이동 XZ 거리·공격 준비/타격/복귀·피격·시체 수명을 읽습니다. 화면 픽셀의 보행 주기는3D 클립에 사용하지 않으며 밀침·순간이동은 보폭을 진행시키지 않습니다. 검의 팔 관절, 짐승의 머리와 턱, 도약 포즈는 기존 피해 시점(공격 위상0.60)에 맞춥니다. 별도 공격 시계나 피해 판정을 만들지 않습니다. 2D 몬스터 렌더러와 이동/시체 아틀라스는 제거했습니다.

`EnemyHitFeedback3D`는 실제HP·최근 피해·보스 준비 타이머를 체력바와 지면 예고로 표시합니다. `AreaEffects3D`는 기존 `Effect`의 위치·높이·범위·나이·지연을 읽어 지속 마법을 표시합니다. 소스의 피해 판정이나 효과 수명을 바꾸지 않습니다. `CaveLanternRenderer3D`는 이전 source역할 이름을 유지하며 실제 `CaveWallGeometry3D`의 안쪽 삼각형에 레이를 쏘아 벽 부착 위치·법선을 구합니다. 낮은 앞쪽 절단면은 제외하고 지상1.55m의 벽에 고정판·받침대와1.7배 크기의 횃불을 네 공유 배치로 표시합니다. 원래 바닥 source좌표는 소유권 참조로만 보존하며, 불꽃과 기존 열 개 광원은 같은 부착 변환을 사용합니다. 벽 메시를 먼저 만든 뒤 횃불을 배치하며, `EnvironmentRenderer3D._clock`·일시정지·동작 줄이기를 공유하고 추가 광원·파티클·바닥 장애물을 만들지 않습니다.

`EncounterRuntime.CAVE_SITE`는 직접 공격으로만20마리를 소환합니다. 일반 몬스터 예산30은 유지하고 이 특수 무리에만20개를 추가 예약합니다. 전체20개 배치 가능 위치를 먼저 검사해 부분 소환을 막습니다. 저장 검증은 일반 기록 합계30·특수 기록20·전체50을 각각 제한하며, 기존 저장 버전과 다른 비석의 충전 규칙은 유지합니다.

메뉴 이동은 `Game._leave_to_menu()`의 저장 성공 후에만 장면을 해제합니다. 보상 적용과 동굴 위치 메타데이터를 저장에 포함하되, 실패하면 현재 팝업·일시정지·동굴 상태를 유지합니다. `close_panel(false)`, `dungeon.leave(...,false)`, `claim_boss_heart(false)`는 이 경로에서 중복 쓰기를 피하기 위한 내부 호출이며 기본 인자는 기존 일반 동작을 유지합니다.

### 잔디 패턴 혼합

[야외 표면](native-outdoor-surfaces.md)은 생성형 잔디10종과 강물10종을 월드 좌표로 혼합합니다. `NativeTerrainSurfaces`가 가져온 압축 데이터를 종류별 `Texture2DArray`로 한 번 묶어 공유합니다. 낮은 들판과 높은 지형은 같은2.56m 배율을 사용하며 길 거리장·충돌은 유지합니다. 원본·프롬프트·실제 참조·해시는 `assets/source/materials/{grass,water}/provenance.json`을 따릅니다.

`ChapelPlan3D`은 확대된 예배당의 3단 계단과 실제 FLOOR를 공유합니다. `TerrainForms3D`의 지층·흙 사면은 동일 정점을 표시와 SOLID에 사용합니다. 생성형 건물 표면과 동굴의 원본/프롬프트는 `assets/source/architecture/`, 웨이포인트·강둑·하강 동굴 원화는 `assets/source/environment/`에 보존합니다. 성벽·기존 지형의 채택 원본은 `assets/source/environment/world_refinement/`에 유지합니다. 길의 합집합·막다른 끝·강안 거리 데이터는 `capture_road_geometry` → `bake_ground_field.py`로 재현하며, 끝 포장은 흙으로, 강안은 젖은 돌→흙→풀로 연결됩니다.

성곽은 2D 기준 원화의 열린 원형 망루·목재 상부 바닥·양쪽 흉벽·외측 아치 음각을 따릅니다. 몸체 반경1.30m·전망 바닥4.25m·성가퀴 정상5.15m이며, `FortressPlan3D.crown_parts()`가 열린 난간/흉벽의 제작과 SOLID를 공유합니다. `wall_walk()`는 여덟 벽 구간 안쪽의 폭1.12m 발판·돌 난간·받침·목재 보를 정의하고 표시와 합친 삼각형 SOLID가 공유합니다. 지상 머리 위2.02m 이상을 비우며, 상부 구조를 지상 FLOOR로 등록하지 않아 아래 배우를 위층으로 끌어올리지 않습니다. 보초 AI·플레이어 승강은 별도입니다. 성문/문짝까지 실제36,928삼각형·정적4서피스이며 검사 상한은38,000/4입니다. 안쪽 통로 뒤의 아치 장식은 생성하지 않습니다. 성곽 목재는 원본의 낡은 중성 참나무색으로 분리하고 텍스처는 공유합니다. 여덟 이동 문짝은 정적 배칭에서 제외합니다. `ortho_3d_fortification`과 `village_structures`가 목재 전망 바닥 12곳·실제 난간·화살창·열린 성문·머리 여유·충돌을 확인합니다.

## 에셋별 독립 작업

[에셋 협업](asset-workflow.md)의 폴더 계약을 사용합니다. 건물 다섯 종류는 `assets/models/architecture/<id>/asset.json`의 생성형 네 면 표면을 사용하며 다리는 같은 계열의 석재/덮개/포장을 적용합니다. `BuildingSurfaceMaterials`는 전역 목록 없이 폴더를 읽습니다. 동굴 입구는 `assets/models/environment/cave_entrance/`에서 밀도장으로 조형하고 구운 GLB를 `visual.tscn`으로 읽어 표시와 실제 삼각형 SOLID에 함께 사용합니다. 공통 윤곽·좌표계·하강로는 `plan.gd`가 담당합니다. 생성 원본·프롬프트·해시는 `assets/source/architecture/`에 보존합니다. 일회성 비교 리뷰와 후보 원화는 현재 제작 규격에 섞지 않습니다.

## 낮은 강과 야외 웨이포인트

`GroundRelief3D`는 낮은 강바닥·완만한 강둑·다리 양 끝의 흙 교대·동굴 하강로를 하나의 정점 집합으로 만듭니다. `GroundRenderer3D` 표시 메시와 `SpatialWorld3D`의 FLOOR가 그 정점을 공유합니다. 강 수면은-1.2m, 깊은 바닥은-1.85m이고, 다리의 기존0m 보행면은 유지합니다. 육지의 대부분은3m, 강둑·동굴 주변만0.5m로 나누며 공유 모서리의 높이는 한 번만 계산하며 같은 필드 규격의 정점 집합을 재사용합니다.

포장6종의 원본·프롬프트·실제 첨부 참조와 해시는 `assets/source/materials/paving/`에 있습니다. `assets/materials/paving/surface.gdshaderinc`가 고정된 월드 좌표에서 호환되는 재질을 구역별로 혼합합니다. `GroundRenderer3D`는6개 밉맵/VRAM 압축 텍스처를 같은 지면 재질에 연결하며, 길 거리장·보행 충돌·강둑 고저차를 보존합니다. `native_ground.gdshader`의 미세 요철은 광원용 법선이며 개별 돌을 이동 장애물로 만들지 않습니다. `natural_ground`가6종 실파일·해시·바인딩·거리장을 검사하고 실제 브라우저에서 혼합 경계를 확인합니다.

야외 tree/cave 지점은 `assets/models/environment/waypoint/`의10cm 돌 기단과 문양입니다. `SpatialWorld3D.terrain_surfaces()`가 기단의 실제 FLOOR를 공유하고 표시기의 원점은 주변 지면 높이에 고정합니다. `Village._waypoint_clearing()`이 강·건물·높은 지형·동굴에서 떨어진 빈 위치를 선택하고, 표식은 SOLID를 만들지 않습니다. `Exploration.on_waypoint()`가 실제 발 위치로 첫 활성화를 검사하고 기존 `discovered_sanctuaries`에 저장합니다. 단순 근접이나 미활성 상태의 안식처 접근은 첫 발견을 대신하지 않습니다. 공용 표시기는 저장 상태를 읽어 어두운 회색→차분한 석재색과 네 대각 모퉁이의 작은 불/비그림자 광원을 함께 전환합니다. 큰 중앙 광원이나 청록색 발광 고리는 사용하지 않습니다. 첫 발견은 `RewardFx.discover_waypoint()`로 기존 금빛 원화와 실제 링 메시를1.6초 표시하고 `LevelUpBanner`에 장소 이름과 활성화 안내를2.6초 보여 줍니다. `waypoint_position`이 실제 기단의 고정 원점이며 움직이는 영웅을 따라가지 않습니다. 재방문·저장 재개는 재생하지 않고, 준비 완료 전에는 자동 발견을 진행하지 않습니다. 일시정지는 효과와 알림의 시계를 함께 멈춥니다. 동시 레벨업은 우선 표시한 뒤 발견 알림을 이어서 보여 줍니다. 실제 첫 활성화 검수는 `at=waypoint_cave_active&waypoint_preview=1&probe=1`로 고정할 수 있습니다. 마을의 수직 워프문과 동굴 귀환문은 유지합니다.

## 확장한 숲과 암반 골짜기

`ForestRegion`의 실제 지면 범위는(-3600,-3600)에서(10800,10800)입니다. 마을·북서 경계를 유지한 채 가로·세로가 각각2배이며 `Game.FIELD`, 물리 외곽, 지도, 생성 지형이 같은 범위를 사용합니다. 나무·수풀·돌의 필드 배치 수는 면적에 맞춰 늘리고 모델·재질·공간 묶음은 공유합니다.

동굴은 지면 좌표(7600,7600)의 독립 암반 지대에 있습니다. `NativeCavePlan.approach_height()`와 `GroundRelief3D`가 약20m의 하강로,3.2m의 바깥 고저차와1.2m의 안쪽 하강을 함께 만듭니다. 암반 측면·바닥은 생성형 돌/자갈 원화를 사용하며, 포장길이나 웨이포인트를 암반 지대에 겹쳐 배치하지 않습니다. `frame()`의 실제 원점은 주변 땅보다3.2m 낮습니다. 동굴 웨이포인트는 과거 의뢰 위치 대신 하강로 전방 약40m의 열린 곳을 기준으로 선택합니다. `CaveTrailPlan3D`의 남쪽 필드 길 분기점부터 웨이포인트를 거치는 미터 단위10개 경유점을 지면 셰이더·식생 제외·실제 통행 테스트가 공유합니다. 생성형 흙/자갈 표면은 기존 지면 메시 위에 폭이 불규칙한 흙길로 혼합하며 새 평면이나 포장길을 겹치지 않습니다. `CaveTrailMarkers3D`의 세 목재 표지는 같은 계획에서 위치·진행 방향을 읽고 `SpatialWorld3D`가 유한한 기둥 충돌을 만듭니다. `cave_trail`은 필드부터 입구까지 실제 캡슐 이동을 검사합니다.

동굴 상자·내구력·금속 표면·지역별 표시 수명은 [입체 소품](native-encounter-props.md), 크기·배치·보상 계약은 [상자 규격](native-chest-scale.md)에 정리합니다. `CaveWallGeometry3D`은 연결된 원래 벽 구간별로 안/바깥 재질을 한 가림 오브젝트로 묶습니다. 떨어진 벽을 X좌표만으로 합치지 않으며 `cave_treasure`가 실제 가림 시선·복원·몬스터 제외를 검사합니다. 바닥/벽 각각6종의 생성 원본·공유 재질·표면 검수는 [동굴 재질](native-cave-surfaces.md)에 정리합니다.

강은 마을 밖 필드의 서·동 경계를 가로지르고 다리의 교대는 지면(5200,5200)에 있습니다. 퀘스트·랜드마크·소환 위치·구역 이름은 [확장 필드 배치](field-layout.md)를 공유합니다. 도로/강 거리장은 `capture_road_geometry.tscn`과 `bake_ground_field.py`로 함께 재생성합니다. `native_river.gdshader`는 시간에 따라 두 물결 표면을 이동시키고 이동 포말·수면 법선을 갱신합니다. 정적 메시를 매 프레임 다시 만들지 않으며 일시정지에는 같은 phase를 유지합니다.

푸시로 실행되는 GitHub Actions는 없고 검사는 푸시 전 로컬 `tools/ci.sh`로 합니다. Pages 공개 배포는 사용자가 별도로 요청한 뒤 `deploy-pages.yml`을 `workflow_dispatch`로 실행할 때만 허용합니다. 기본 “배포”는 [APK 전달 스킬](../../.agents/skills/dropbox-apk/SKILL.md)의 Dropbox 전달입니다.

동굴 소환 비석은 골짜기 바닥의 완만한 지점에 둡니다. 저장된 소환 무리는 비석 기준점을 기록하고, 이전 위치의 저장은 무리 구성을 보존한 채 새 암반 지대로 옮긴 후 실제 지형에 재배치합니다. 시험용 전투장은 `native_combat_fixture.remote_at()`으로 필드 범위 밖에 두어 실제 지형 확장과 겹치지 않게 합니다.

분수의 전용 표면은 `assets/models/environment/fountain/`에서 교체합니다. `asset.json`이 기둥·수조·덮개·기초의2×2 표면과 기존2D 물 원화의 UV 영역을 지정합니다. 물은 기존 `remake-pool.webp`의90×60px 물 부분을 재사용하며 원본 그림이나 모델 전체를 카메라 방향 판으로 붙이지 않습니다. 기존 `PlazaWater.phase`로 표면과 낙수점 파문을 움직이고 메뉴·동작 줄이기 설정을 따릅니다. 석재 원본·실제 참조·생성 문구는 `assets/source/environment/{fountain,fortress}/`와 `assets/source/architecture/smith/`에 보존합니다. 대장간의 양쪽 작업 홈은 기존 여섯 재질의 실제 기하이며 기존 전체 건물 충돌 안에 있습니다. 활엽수는377개 잎 묶음·4,886삼각형으로 수관을 채우되 같은 두 공유 메시와 기존 발치·충돌을 유지합니다.

대장간을 포함한 주택·예배당은 패키지의 `roofCell`로 생성형 기와 한 조각 재질을 선택합니다. 기하의8단·6열·엇갈림 UV와 같은 좌표로 붙여 그림 속 줄눈이 어긋나지 않습니다. 분수 낙수는 높이로 수면과 구분하며 장식구의 실제 정점 법선만 부드럽게 만들고 주변 석재의 각은 유지합니다.

새 렌더링 헬퍼는 탭 들여쓰기·명시적 자료형과100자 줄 길이를 사용합니다. `Dictionary`에서 꺼낸 값은 자료형을 지정하고, 주석은 실제 단위·수명·소유권과 선택 이유를 설명합니다. 정적 모델·표면 패키지와 게임 상태를 분리하며 화면 알림의 공통 생성은 HUD의 한 헬퍼를 재사용합니다.

## 몬스터의 독립 씬

`EnemyRenderer3D`는 게임 상태를 관찰하는 표시 어댑터입니다. 몬스터 여섯 종은 `assets/models/enemies/<kind>/`의 GLB·`visual.tscn`·`asset.json`을 읽고, `shared/visual.gd`가 실제 클립과 타격 시각을 연결합니다. 각 인스턴스의 골격·재질은 분리하고 원본 메시·클립은 공유합니다. 절차형 몬스터 생성기는 제거했으며 원본/클립 변환은 오프라인 도구가 담당합니다. 제작·접지·캐시·검수·출처는 [몬스터 안내](native-enemy-models.md)를 따릅니다.

## 건물 씬과 제작 도구

마을의 주택 네 채·예배당·성곽/성문·다리는 `ArchitectureSceneLibrary`가 개별 GLB 씬을 인스턴스화합니다. 메시·UV·문짝 피벗은 GLB, 엔진 전용 표면은 씬의 공유 재질, 측정/노드 경로는 자산별 `layout.tres`에 있습니다. `HouseRenderer3D`·`ChapelRenderer3D`·`BridgeRenderer3D`는 배치 어댑터이며 `FortificationRenderer3D`은 기존 성문 상태만 연결합니다. 실제 이동/충돌은 기존 Plan과 `SpatialWorld3D`가 유지합니다. 모델링 코드는 `tools/assets/architecture/`로 옮겼으며 APK/Web에서 제외합니다. 자산별 재현·외부 제작·검수는 [건물 GLB 계약](native-architecture-models.md)을 따릅니다.

몬스터 보행의 `locomotion.distance_curve`는 오프라인120Hz 지지발 측정으로 만든 거리→GLB 시각 표입니다. 실시간 실제 이동 거리를 역보간하며, 접지 시각마다 평균 속도에서 어긋나던 앞뒤 발 움직임을 보정합니다. [모델·재측정 계약](native-enemy-models.md)을 따릅니다.

`WarpTravel`은 수락·잠금·전환 시계를, `Exploration._complete_warp`는 실제 도착 재검증·공간 이동·회복·저장을 소유합니다. 워프 연출의 프레임 간격만 최대1/15초로 제한하고 전환 프레임은 완전 숨김으로 고정합니다. 플레이어 쿨다운·버프·회복은 실제 delta를 사용하며 워프 중 능동/주기 공격과 물약 사용은 실행하지 않습니다. `WarpEffects3D`는 그 시계만 읽어 재사용하는 빛을 표시하고, [ActorWarpFade](../scripts/rendering/actors/actor_warp_fade.gd)가 배우 전체 표시/재질 복원을 담당합니다. 매 출발에 현재 표면을 다시 읽고 Standard/ORM 등 `BaseMaterial3D`의 얕은 사본을 표면 간 공유하며 종료/취소에 재질·오버레이·그림자·표시 상태를 복원합니다. 텍스처는 복제하지 않습니다. 임의 ShaderMaterial·다중 패스·기본 재질은 알파 계약을 추측하지 않고 배우 전체를 동시에 숨김/표시하며 원본 표면을 바꾸지 않습니다. 이 경우 빛은 유지하지만 부드러운 배우 페이드는 적용하지 않습니다.

`MapPlaceRow`는 드래그 임계값을 넘긴 상태를 손을 뗄 때까지 유지합니다. 방향 반전·터치 취소·다른 손가락이 탭을 만들지 않으며 부모 목록의 스크롤을 막지 않습니다. `map_place_row_input`과 실제 터치 도구 `tools/check_map_touch.mjs`가 이를 검증합니다.

`Game._tick_corpse_list`는 활성 영역과 동굴 방문 중 숨겨진 필드의 시체 수명을 같은 모험 시계로 처리합니다. 기본15초/끝3초 페이드이며 삭제 시 스킬 대상·원본 기록·3D 표시를 함께 정리합니다. `warp_transition`·`actor_warp_fade`·`corpse_expiry`가 실제 공간/재질 복원과 정상 프레임 만료를 검증합니다.

동굴의 실제 바닥·경사·경계는 `DungeonRelief`가 공유하고, `DungeonHazards`가 장치의 시계·피해를 소유합니다. `DungeonHazardRenderer3D`와 HUD·지도는 같은 상태를 읽습니다. 모델 교체 경계·수명·검사는 [동굴 구조](native-cave.md)를 따릅니다.

동굴의 방별 처치 진행은 `DungeonRooms`가 생성 시 등록한 적 ID를 추적합니다. HUD와 지도는 같은 상태를 읽으며 `DungeonRuntime`이 사망·재입장 수명을 연결합니다. 함정 주기는 전체 동굴에서 흐르며, `DungeonHazards`의20m 전투 반경이 먼 방의 피해/대상 검색만 제한합니다.

HUD는 Viewport 크기 변경 신호에서도 표시를 갱신합니다. `TouchControls.refresh_layout()`과 `Minimap.refresh_layout()`은 조작·피드백·알림 시계를 진행시키지 않고 그림/터치 범위를 재배치합니다. `hud_pause_resize`는 실제 일시정지 중 가로·세로 왕복 신호와 시간 정지를 검사합니다.

일반 적의 공격 준비 게이지는 `EnemyHitFeedback3D`가 실제 AI 타이머에서 표시합니다. 명시적 검수 쿼리의 준비 장면은 `scripts/inspection/native_enemy_review.gd`에 분리하며 운영 전투 시계를 만들지 않습니다.

`Chest`는 실제 피해·보상과 함께 짧은 피격/개봉 표시 시간도 소유합니다. 반응 중에만 `_process`를 활성화하고, `EncounterPropRenderer3D`는 같은 힌지 범위의 `lid_fraction()`만 읽습니다. [타격감 구조](juice.md)를 참고하세요.

실제 구르기 피격 방지는 `Player.confirm_roll_avoid()`에서 한 번만 표시합니다. 대상 연결 문자는 `Effect`의 약한 참조/마지막 접점과 실제3D 발에서 배치하며 [타격감 구조](juice.md)를 따릅니다.

고정 소품·전사·주민·식생은 [소품 GLB·씬 계약](native-prop-models.md)을 따릅니다. `ModelSceneLibrary`는 씬과 메시를 공유하며, 나무/수풀/횃불은 기존 MultiMesh 배칭을 유지합니다. 형상 제작기는 `tools/assets/props/`에 두고 게임은 원래 이동·공격·상호작용 시계를 계속 소유합니다.
