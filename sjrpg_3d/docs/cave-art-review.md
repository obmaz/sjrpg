# 동굴 구현·독립 감독 비교

동굴 입구와 내부를 개선할 때 구현자와 별도 감독자가 실제 화면으로 비교하는 로컬 하네스입니다. 운영 코드는 구현자가 수정하고 감독자는 캡처·상태·레퍼런스를 읽어 판정만 작성합니다. 같은 실행 폴더의 실제 감독 비교는 **최대5회**이며 미개선 baseline도1회로 셉니다. `round-N`은 후보 번호이며 기술 실패로 넘긴 미검토 후보는 감독 비교 횟수에 넣지 않습니다. 결과는 루트 `build/cave-art-review/`에 두고 운영 문서에 완료 기록을 쌓지 않습니다.

## 촬영 장면과 조건

모든 회차는 기본1×, 절약화질(`quality=low`), DPR1을 사용합니다. PNG 크기는 세로720×1280, 가로1280×720입니다. 실제3D 제출 해상도는 PNG 크기와 구별해 `manifest.captures[].nativePixels` 및 상태 JSON의 `probe.native_width/native_height`로 기록합니다. 소프트웨어 GPU의 PNG 읽기에는 최대120초를 허용하며, 시작·실제 물리 준비·로딩 패널 종료·함정 단계 검사도 유지합니다.

| 캡처 ID | 실제 장면 | 확인할 내용 |
| --- | --- | --- |
| `entrance-phone` | `town --at cave_exterior` 또는 `cave_descent` · 세로 | 마지막 흙길·하강·암반 발치·전체 입구 |
| `entrance-landscape` | 같은 입구 위치 · 가로 | 구릉/입구 접합과 접근 방향 |
| `entry-phone` | `cave_entry` · 세로 | 동굴 진입·귀환문·벽 부피와 깊이 |
| `room-landscape` | `cave_room` · 가로 | 방 윤곽·재질 반복·인물/전투 가독성 |
| `upper-phone` | `cave_upper` · 세로 | 상하 분기·경사·바닥/벽 접합 |
| `spikes-warning-phone` | `cave_spikes_warn` · 세로 | 실제 가시 예고 단계와 회피 경로 |

`--entrance-at cave_exterior`는 전체 입구와 발치, `cave_descent`는 하강 구간 쪽의 기존 검수 시점입니다. 같은 회차의 입구 두 장은 같은 위치를 사용하며 비교 조건을 바꿨다면 감독의 `limits`에 기록합니다. 화면을 잘라 붙이거나 검수 때만 모델/지형 크기를 바꾸지 않습니다.

## 미개선 baseline 고정

baseline을 촬영하는 동안 구현자가 편집할 수 있도록, 먼저 현재 운영 소스를 동결해 Web export를 마치고 그 산출물을 별도 폴더에 복사합니다. `baseline-build.json`에는 다음 구조를 기록합니다.

```json
{
  "schemaVersion": 1,
  "gitCommit": "실제로 빌드한 40자리 Git SHA",
  "source": {"sha256": "운영 소스 지문", "files": []},
  "pack": {"name": "index-....pck", "sha256": "실제 PCK 전체 SHA-256"}
}
```

`source`는 `harness.mjs`가 내보내는 `sourceSnapshot(project)` 결과이며 미커밋 변경도 포함합니다. 원본 보관 폴더와 엔진이 만든 `.import`/`.uid`는 운영 지문에서 제외하고 별도 자산 출처 검사를 따릅니다. 이미 빌드한 PCK의 소스 지문을 나중의 편집 상태에서 역으로 만들어 쓰지 않습니다. 기존 마을 하네스의 같은 범위 `sourceSnapshot` 출력도 호환됩니다.

고정한 Web 폴더를 로컬 서버로 제공한 뒤 저장소 루트에서 실행합니다.

```sh
node --test sjrpg_3d/tools/review/cave/harness.test.mjs
node sjrpg_3d/tools/review/cave/harness.mjs baseline --round 1 \
  --web-dir build/cave-art-review/baseline-web \
  --build-record build/cave-art-review/baseline-build.json \
  --url http://127.0.0.1:8890/ --entrance-at cave_exterior
```

이 명령은 Godot를 다시 실행하지 않습니다. 빌드 기록의 PCK 전체 해시와 소스 파일 목록 지문, 고정 Web 폴더와 서버의 실제 HTML/PCK 및 WASM·JS 등 부속 파일 바이트, 브라우저가 받은 PCK URL을 함께 확인합니다. 촬영 중 고정한 Web 폴더가 바뀌면 실패합니다. 운영 소스의 후속 편집은 baseline 촬영 실패로 보지 않습니다. baseline 통과 판정은 그 고정 빌드의 판정이며 이후 편집된 후보의 검수를 대신하지 않습니다.

## 후보 촬영과 감독 판정

구현자가 수정 소스를 동결한 뒤, 현재 `sjrpg_3d/build/web/`를 제공하는 로컬 서버에서 촬영합니다.

```sh
node sjrpg_3d/tools/review/cave/harness.mjs capture --round 2 \
  --url http://127.0.0.1:8891/ --entrance-at cave_exterior
```

후보 명령은 Web export부터 실행하고 빌드·촬영 전후 운영 소스 지문을 비교합니다. Godot 임포트/내보내기와 충돌하지 않게 한 번에 하나의 하네스만 실행합니다. 고정 baseline 폴더 서버를 후보 서버로 잘못 지정하면 HTML/PCK 검사에서 거부합니다. `ready`인 회차만 감독이 실제 PNG와 상태 JSON을 검토합니다.

감독자는 `round-N/review.json`을 작성합니다. 형식은 `schemaVersion:1`, `round`, `reviewer:"independent_supervisor"`, `verdict:"pass"|"revise"`, `comparedImages`(실제로 본 PNG 및 사용자 원본의 절대 경로), `scores`, `blockers`, `nextChanges`, `limits`입니다. `scores`는 `entrance_shape`, `ground_connection`, `interior_form`, `materials`, `readability`, `hazards` 각각0..5의 정성 척도이며 달성률이 아닙니다.

- 입구가 자연 암반의 개구부로 읽히고, 흙길/하강 지형과 발치가 부드럽게 연결되는가.
- 내부가 직선 울타리나 얇은 칸막이처럼 보이지 않고 암반의 부피·깊이·방별 형태가 읽히는가.
- 바닥과 벽의 재료 크기·반복·이음과 높이 전환이 어울리는가.
- 기본 시야에서 인물·진행 방향·귀환문·상자·적을 찾을 수 있는가.
- 가시 예고와 회피 가능한 바닥을 장식/조명과 구별할 수 있는가.
- [사용자 스타일 원본](../assets/source/style/approved-game-reference.jpg) 및 현재 [3D 제작 기준](../../docs/3d-asset-guide.md)과 재질·빛·실루엣 관계가 어울리는가. 어둡게 덮는 방식으로 구조 결함을 숨기지 않는가.

```sh
node sjrpg_3d/tools/review/cave/harness.mjs accept-review --round 2
node sjrpg_3d/tools/review/cave/harness.mjs gallery
```

필수 이미지를 보지 않았거나 차단 문제가 남으면 합격을 받지 않습니다. 이미지 또는 실제 상태 JSON이 바뀌어도 거부합니다. 후보 합격은 촬영한 소스 지문과 현재 운영 소스도 일치해야 합니다. 봉인한 판정은 `review.accepted.json`과 세션 해시로 보존합니다.

## 실패와 회차 보존

각 촬영 시도의 원본 PNG·상태·로그는 `round-N/attempt-M/`에 보존합니다. 기술 실패인 `failed` 시도만 새 `attempt` 폴더로 재시도하며 이전 이미지를 덮어쓰지 않습니다. PCK까지 만들어진 실패는 같은 소스·PCK·Web 파일 목록일 때만 기술 재시도로 취급하고, 후보는 기존 빌드를 재사용합니다. 수정에 다른 소스나 PCK가 필요하면 실패 원본을 보존한 채 다음 후보 번호로 이동합니다. 아직 감독이 보지 않은 실패에 인위적인 판정을 요구하지 않으며 실제 봉인한 감독 판정 수만 최대5회로 제한합니다. 프로세스가 강제 종료돼 `building/capturing` 상태가 남았다면 살아 있는 캡처/엔진 작업부터 확인하고 종료 원인을 기록해 복구합니다. 진행 중 작업 위에 중복 실행하지 않습니다.

완료한 `ready` 회차를 재촬영하거나 이미 감독이 본 판정을 덮어써 합격으로 바꾸지 않습니다. 감독의 수정 판정은 다음 회차에서 처리합니다.5회 안에 남은 문제가 있으면 그대로 보고하고 여섯 번째 감독 비교를 추가하지 않습니다. 기술 실패 때문에 후보 번호가6 이상이 된 경우에도 실제 감독 비교는5회를 넘지 않습니다. 이 하네스는 실제 이동·충돌·함정/전투 회귀 검사나 Android 실기기 성능 검수를 대체하지 않습니다.
