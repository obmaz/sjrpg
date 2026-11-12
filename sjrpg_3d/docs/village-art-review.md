# 마을 구현·독립 검증

건물 배치·방향과 원본 레퍼런스 분위기를 함께 검토할 때 사용하는 로컬 하네스입니다. 구현자와 검증자는 서로 다른 에이전트로 두고, 검증자는 운영 코드를 수정하지 않습니다. 같은 실행 폴더의 비교는 **최대5회**이며 기존 화면 비교도1회로 셉니다. 회차별 실제 캡처·소스 지문·읽기 전용 공간 상태·검증 판정을 `build/village-art-review/`에 둡니다. 완료 기록을 운영 문서에 누적하지 않습니다.

## 실행

저장소 루트에서:

```sh
node --test sjrpg_3d/tools/review/village/harness.test.mjs
node sjrpg_3d/tools/review/village/harness.mjs baseline
node sjrpg_3d/tools/review/village/harness.mjs accept-review --round 1
node sjrpg_3d/tools/review/village/harness.mjs capture --round 2 --url http://127.0.0.1:8886/
```

첫 baseline 명령은 기존 `build/village-courtyards/`·`build/feel-refinement/`의 검증된 실제 캡처를 복사하므로 해당 산출물이 있을 때만 사용합니다. 이전 산출물이 없는 새 비교는 `baseline` 대신 `capture --round 1 --url …`로 실제 현재 화면부터 촬영합니다. 다음 회차는 구현자가 소스를 동결한 뒤 빌드·캡처합니다. URL은 `sjrpg_3d/build/web/`을 제공하는 로컬 서버여야 합니다. 하네스가 Web export를 먼저 실행하고, 구현 소스가 빌드/촬영 중 바뀌거나 브라우저가 다른 PCK를 읽으면 실패합니다. 임포트 결과와 UID는 엔진 생성물이므로 소스 지문에서 제외합니다. 원본 재료와 생성 프롬프트의 출처 검사는 자산 검증이 별도로 담당합니다.

엔진의 `native_ready`와 진입 로딩 패널 종료는 서로 다른 시점입니다. 촬영 도구는 `EntryLoading`의 `result=ready`·`visible=false`와 실제 DOM 제거까지 기다리고 그 상태를 JSON에 기록합니다. 하네스는 패널 종료가 확인되지 않은 캡처를 거부합니다. 아직 봉인하지 않은 같은 후보의 촬영 오류는 잘못된 사진을 별도로 보존하고 같은 소스/PCK로 재촬영할 수 있습니다. 구현 수정 후 새로 비교하는 회차와 구분하며, 이미 봉인된 비교 사진은 교체하지 않습니다.

후속 캡처는 예배당 기본1×, 배치 전용 넓은 마을 화면, 회전 주택 기본1× 세로·가로, 겹침이 문제였던 북쪽 골목과 성벽 옆 남쪽 골목 기본1×입니다. 기본1× 주택 화면은 건물 고정 시점 대신 정상 플레이의 인물 추적을 사용합니다. `VillageReviewSnapshot`은 명시적 `village_review=1`에서 실제3D 루트·정면의 화면 벡터·모델 간격·문 접근 지점·인물 발 위치와 카메라 방식을 읽습니다. 화면이나 배치를 대신 만들지 않습니다. 모델 간격은 기단·진열대 등 모든 부품을 포함한 실제 회전 XZ AABB의 거리이며 지붕 간격·시선 겹침·전체 보행 가능성을 대신 판정하지 않습니다. 문 접근 지점의 충돌값에는 주민도 포함하므로 벽에 막혔다고 단정하지 않습니다. 인물과 UI의 화면 가독성은 카메라 보간이 안정된 실제 PNG로 판정합니다.

## 독립 비교

검증자는 해당 회차의 `manifest.json`·실제 이미지·사용자 원본 `approved-game-reference.jpg`·관련 이동/지도 검사 결과를 읽고 `round-N/review.json`을 작성합니다. 다음 항목을 확인합니다.

- 일부 집의 정면이 실제로 +X, 화면 우하단을 향하고 다른 집은 +Z 방향을 유지하는가.
- 문 앞 공간·지붕 틈·골목이 읽히며 가림 투명도에 의존한 과밀 배치가 없는가.
- 레퍼런스의 어두운 수관·불규칙한 하층 식생·밝은 건축과 돌길의 관계가 실제 장면에서 개선됐는가.
- 재질·기단·지붕·판석의 크기와 밀도가 어울리고 사각 매트·띠 화단의 반복이 지배하지 않는가.
- 기본1× 가로·세로에서 인물·UI·상호작용을 읽을 수 있는가.

JSON은 `schemaVersion:1`, `round`, `reviewer:"independent_verifier"`, `verdict:"pass"|"revise"`, `comparedImages`(실제로 본 절대경로), `scores`(`layout`, `orientation`, `reference_mood`, `materials`, `vegetation`, `readability`), `blockers`, `nextChanges`, `limits`를 기록합니다. 점수는0..5 정성 척도이며 달성률이나 사진과의 동일성을 보장하는 수치가 아닙니다.

```sh
node sjrpg_3d/tools/review/village/harness.mjs accept-review --round 2
node sjrpg_3d/tools/review/village/harness.mjs gallery
```

필수 이미지를 보지 않았거나 차단 문제가 남으면 합격 기록을 받지 않습니다. 합격은 현재 소스 지문과 실제 표시 루트/공유 포즈 및 문 방향도 일치해야 합니다. 검증한 회차를 덮어쓰거나 여섯 번째 비교를 추가하지 않습니다. 수정 판정은 구현자에게 전달하고 다음 회차로 진행합니다.5회 안에 남은 차이가 있으면 그대로 보고하며 합격으로 바꾸지 않습니다. 이 하네스는 코드·물리 회귀 검사와 실기기 성능 검증을 대체하지 않습니다.
