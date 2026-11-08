# 3D 개발 구조

현재 개발 대상은 `sjrpg_3d/`입니다. 2D판은 동결하며, 루트는 버전 선택·공통 빌드만 담당합니다. [전체 구조](../../docs/development.md)와 [3D 제작 기준](../../docs/3d-asset-guide.md)이 기준입니다.

## 실행과 상태

- `NativeAdventure`가 모험 진입점입니다. `SpatialWorld3D`의 실제 몸체·높이·충돌이 공간 기준입니다.
- 기존 `Game`, `Player`, `Enemy`는 진행·AI·UI 호환 어댑터입니다. 화면 좌표를 실제 X/Z 지면과 Y 높이로 변환합니다.
- `SpatialCombat3D`가 높이·벽·몸체를 기준으로 근접 공격과 투사체를 제한합니다. 피해·재사용 시간·저장은 기존 규칙을 공유합니다.
- `Ortho3DPreview`는 이름에 Preview가 남은 실제 공간 표시기입니다. 마을·숲·기존 동굴에서 사용하므로 미사용 프리뷰 코드로 삭제하지 않습니다.
- 카메라는 방위45°·고도35.2643897° 직교 투영입니다. HUD와 미니맵은2D UI이며, 지면·물·효과·알파 잎의 평면은 입체 물리와 함께 사용합니다.

## 저장과 입력

진행은 `GameState`, 설정은 `Prefs`가 담당합니다. 저장은 `data.get(키, 기본값)`으로 하위 호환을 유지합니다. 3D 저장 위치는 네이티브 `sjrpg_3d`, 웹 `/userfs/sjrpg_3d`입니다. [저장 슬롯](save-slots.md)을 따릅니다.

키보드·마우스·터치·Xbox 조작은 [프로젝트 안내](../README.md)를 따릅니다. 입력과 HUD는 실제 게임 상태를 읽으며 검수 observer가 게임 상태를 대신 만들지 않습니다.

## 제작과 유지보수

[문서 목록](README.md)에서 현재 영역별 제작 문서를 찾습니다. 공통2D 원화 제작 기록은 `../../sjrpg_2d/docs/`에 한 벌만 보존합니다. 이 기록을3D 기하·광원·충돌 규격으로 사용하지 않습니다.

`assets/source/`는 승인 스타일, 생성 원본, 라이선스·출처·재생성 기록입니다. 게임 패키지에는 넣지 않지만 재현에 필요한 입력이므로 유지합니다. `assets/art/`와 `assets/data/`는 실제 런타임 리소스입니다. 경로 이름만으로 미사용 여부를 판단하지 않습니다.

데이터 추출물은 `tools/extract/`에서 재생성합니다. 수치 단위는 원본 단위이며 HUD 체력·피해는100배, 자원은10배로 표시합니다. 조정은 추출 JSON을 수동 변경하는 대신 별도 설정으로 적용합니다.

## 검사와 내보내기

저장소 루트에서 실행합니다.

```sh
tools/check.sh --project=3d
tools/check.sh --export
tools/serve.sh
```

테스트는 `tests/run_all.tscn`에서 `tests/cases/`를 탐색합니다. 정적 호출이 없다는 이유로 테스트 파일을 삭제하지 않습니다. 제작 도구의 Python import와 명령행 진입점도 참조에 포함합니다.

[Web·Android 내보내기](platform-exports.md), [Android 설치·서명](android.md), [웹 성능](web-performance.md)을 따릅니다. UI·입력·렌더 변경은 실제 가로·세로 브라우저 검사를 추가하고, 배포는 전체 검사와 공개 페이지 실행을 확인합니다.

검수 캡처·일회성 진단 출력은 `build/`와 Actions 아티팩트에 둡니다. 저장소에 완료 스크린샷을 계속 쌓지 않습니다. 원본 출처와 현재 재현 방법은 관련 제작 문서에 유지합니다.

프레임 비용은 `frame-pacing-review.yml`의 동일 worker 전후 비교로 검사합니다. `tools/perf/frame_pacing_observer.gd`는 임시 CI 빌드에만 연결하며 실제 렌더 제출 간격과 읽기 전용 엔진 모니터를 수집합니다. 정상 운영 장면에 관찰기를 연결하거나 입력·게임 상태를 바꾸지 않습니다. 측정 범위와 한계는 [웹 성능](web-performance.md)을 참고하세요.

## 적 표시와 공격 피드백

`NativeEnemyModels`는 기존 입체 몬스터를 표시합니다. `visual_variant=cave_crawler`인 동굴 비석 무리는 `NativeEnemySprites3D`가 실제 `actor_foot()` 위에 생성형 원화를 표시하며, 시체도 같은 변형 정보를 전달해 기존3D 시체와 중복되지 않게 합니다. 소스 몬스터의 방향·보행 주기·접촉 정지·피격·사망·시체 수명을 읽고 별도 전투 시계를 만들지 않습니다. 알파에서 측정한 프레임별 발 위치와 실제 크기는 `assets/data/cave_crawler_sprite.json`에 둡니다.

`NativeEnemyFeedback3D`는 실제HP·최근 피해·보스 준비 타이머를 체력바와 지면 예고로 표시합니다. `NativeZoneFx3D`는 기존 `Effect`의 위치·높이·범위·나이·지연을 읽어 지속 마법을 표시합니다. 소스의 피해 판정이나 효과 수명을 바꾸지 않습니다. `NativeCaveLanterns3D`는 이전 source역할 이름을 유지하는 횃불 표시기이며, `Ortho3DEnvironment._clock`을 공유합니다.

`EncounterRuntime.CAVE_SITE`는 직접 공격으로만20마리를 소환합니다. 일반 몬스터 예산30은 유지하고 이 특수 무리에만20개를 추가 예약합니다. 전체20개 배치 가능 위치를 먼저 검사해 부분 소환을 막습니다. 저장 검증은 일반 기록 합계30·특수 기록20·전체50을 각각 제한하며, 기존 저장 버전과 다른 비석의 충전 규칙은 유지합니다.

메뉴 이동은 `Game._leave_to_menu()`의 저장 성공 후에만 장면을 해제합니다. 보상 적용과 동굴 위치 메타데이터를 저장에 포함하되, 실패하면 현재 팝업·일시정지·동굴 상태를 유지합니다. `close_panel(false)`, `dungeon.leave(...,false)`, `claim_boss_heart(false)`는 이 경로에서 중복 쓰기를 피하기 위한 내부 호출이며 기본 인자는 기존 일반 동작을 유지합니다.
