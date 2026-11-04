# 개발 참고

## 한눈에 보는 구조

| 영역 | 파일 | 책임 |
| --- | --- | --- |
| 진입 | `scenes/main.tscn`, `scripts/main.gd` | 화면 전환(타이틀 → 직업 선택 → 모험), 가로/세로 기준 해상도 |
| 상태 | `scripts/game_state.gd` | 영웅 진행·스킬·장비·골드·퀘스트·저장 (자동 로드) |
| 기기 | `scripts/prefs.gd`, `scripts/sound_fx.gd` | 효과음·진동·전체화면 설정(자동 로드), 효과음 합성 |
| 월드 | `scripts/game.gd`, `iso.gd`, `iso_sprite.gd`, `village.gd`, `landmark.gd`, `bridge.gd`, `river.gd`, `wall_piece.gd`, `chest.gd` | 쿼터뷰 투영, 실측 원화 배치, 충돌, 지형 높낮이 |
| 전투 | `player.gd`, `enemy.gd`, `effects.gd`, `skill_defs.gd`, `gear.gd` | 입력·스킬 시전, 몬스터 AI, 투사체·구역, 장비 효과 |
| 진행 | `quests.gd`, `quest_runtime.gd` | 제1장 퀘스트·보스 |
| UI | `hud.gd`, `touch_controls.gd`, `minimap.gd`, `panel_frame.gd` + 패널들 | HUD, 모바일 조작, 가방·스킬·설정·대화·일지 |
| 테스트 | `tests/run_all.gd`, `tests/test_case.gd`, `tests/cases/*.gd` | 헤드리스 케이스 러너 |
| 도구 | `tools/*.sh`, `tools/screenshot.mjs`, `tools/extract/` | 검증·빌드·캡처·데이터 추출 |

## 좌표와 단위

- 지면 좌표(원본 단위)는 `Iso.project()`로 화면 평면의 월드 픽셀이 됩니다. `Iso.S`는 원본 월드를 이 포트의 화면 비율로 바꾸는 배율입니다.
- 건물 원화는 `IsoSprite`가 실측 바닥 접점(`foot`), 지면 보정(`gvs`/`gvk`), 패킹 배율로 그립니다.
- 깊이 정렬은 `world`(y 정렬) 안의 노드 위치 y입니다. 높은 지형 윗면의 캐릭터는 `z_index = 1`로 원화 위에 그립니다.

## Godot판 조정과 개발 순서

원본 추출 데이터는 출처를 보존하고, Godot판 밸런스·규칙은 별도 설정에서 적용합니다.
숲 1장의 저장·재도전, 전투·성장, 의뢰·보스, 탐험, 선택형 동굴, 모바일·웹 마감 순서로 완성합니다.
각 기능은 리뷰·전체 검사·웹 빌드·필요한 브라우저 검증 후 main에 커밋하고 푸시합니다.
배포 워크플로와 공개 페이지를 확인한 뒤 다음 기능으로 진행합니다.

## 데이터 재생성

```sh
python3 tools/extract/extract_data.py /path/to/sjrpg            # skills · gear · village · landmarks
python3 tools/extract/extract_data.py /path/to/sjrpg --only=gear
```

예배당은 원본 원화가 120° 기준을 벗어나 추출 대상이 아닙니다. 새 원화(`assets/source/chapel-new.png`)의 측정값은
`tools/extract/chapel_measure.json`에 있고 `tools/extract/chapel.py`가 `town.webp` 패킹과 `village.json`의 예배당 항목을
만듭니다(`extract_data.py`도 같은 `merge()`로 합침). 패킹은 시트 전체를 다시 인코딩하므로 예배당이 없는 시트에서 한 번만,
측정값만 바꿀 때는 `python3 tools/extract/chapel.py --data`를 씁니다. `assets/source/`는 `.gdignore`로 임포트·번들에서 뺍니다.
성문 두 방향과 성벽 구간 원화(`gate-new-a/b.png`, `wall-seg-a/b.png`)의 측정값은 `tools/extract/gate_measure.json`에 있고
`tools/extract/gate.py`가 `gates.webp`·`walls.webp` 패킹과 `village.json`의 성문·성벽 항목을 도출합니다.

## 디버그 쿼리 (웹)

`index.html?zoom=0.45&at=bridge&panel=bag&gold=300&chests=1`

| 키 | 값 | 효과 |
| --- | --- | --- |
| `zoom` | 숫자 | 카메라 배율(작을수록 넓게) |
| `at` | `field` `bridge` `bank` `gate0`–`gate3` `lm0`–`lm2` `elin` `rowen` `corner0` `corner3` | 시작 위치 |
| `panel` | `bag` `shop` `skills` `settings` `smith` `journal` `mira` `elin` `victory` | 시작 1.5초 뒤 패널 열기 |
| `gold` | 정수 | 시작 골드 |
| `chests` | 아무 값 | 상자를 모두 부숨 |

`tools/screenshot.mjs --scene <이름>`이 위 조합을 이름으로 묶어 둡니다(`--help` 없이 잘못된 이름을 주면 목록 출력).

## 전투 조정

`ForestBalance`에 Godot 숲의 지역 레벨·마을 주변 완화·생성 간격을 둡니다. 추출 데이터는 수정하지 않습니다.
`Gear.melee_profile()`의 월드 사거리·반각·공격 간격을 실제 근접 기본 공격과 가방·스킬 설명이 공유합니다.
무기의 공격속도와 일시적인 연격 강화는 공격 간격에 반영합니다. 대장간은 실패 시 비용만 소비합니다.

## 바람 동굴

`DungeonLayout`의 투영 다각형을 실제 바닥·이동 충돌·두 지도가 공유합니다. 전투 구역 5개와 두 번의 분기·합류가 있습니다.
`DungeonRuntime`은 숲 루트를 숨기고 처리를 멈춘 뒤 플레이어를 임시 월드로 옮깁니다. 적·상자·시체·지도 상태는
공간별로 분리하고, 퇴장 시 플레이어를 돌려놓은 뒤 동굴 노드를 폐기합니다. 입장 전 미완료 공격도 취소합니다.
적 레벨은 입장 때 고정하며 동굴 처치는 숲 의뢰에 보내지 않습니다. 시체·전리품·경험치는 기존 전투를 재사용합니다.
`location_mode`만 저장하고 동굴 인스턴스는 저장하지 않습니다. 재접속 시 입구로 복귀하며, 보호 의뢰·보스 도전 중 입장은 막습니다.
`DungeonPanel`은 입장·완료·퇴장을 제공하고 설정에서도 중도 퇴장할 수 있습니다.

## 탐험·지도·안식처

`MapGeometry`가 마을 포장·강·다리·벽·건물 바닥·랜드마크 윗면·물 경계에서 두 지도에 쓸 도형을 만듭니다.
`MapPanel`은 전체 지도와 안식처 이동 탭을 제공하며, 의뢰 상태에 따라 목적지 표식을 갱신합니다.
`Exploration`은 직접 방문한 안식처를 해금하고 `last_sanctuary`에 부활·재접속 위치를 기록합니다.
이동은 안식처 근처에서만 가능하며 주변 적·보호 의뢰·보스 도전 중에는 막습니다. 도착점은 실제 충돌로 검사합니다.
폭포는 기존 `landmarks.json`의 네 번째 측정값을 사용하며 상자 ID 8을 추가합니다(기존 기억 상자 5–7 보존).

## 파수꾼 도전

의뢰 3개 완료 시 서쪽 고정 공터에서 `QuestRuntime.start_boss()`로 도전합니다. 별도 처치 수 조건은 없습니다.
사망·1100px 이상 이탈 시 적을 제거하고 재도전을 허용하며, 재접속도 새 도전으로 시작합니다.
보스 예고 타원의 세로 배율과 실제 공격 거리 계산을 일치시킵니다. 고유 보상은 가방이 가득 차면
`boss_heart_pending`으로 저장하고 가방을 비운 뒤 패널을 닫을 때 지급합니다.

## 저장과 재접속

`SaveStore`는 임시 파일에 작성·flush 후 교체하며, 읽을 수 있는 직전 저장만 `.bak`으로 보존합니다.
`GameState.save_game()`은 성공 여부를 반환하고 `save_finished(success, message)`를 알립니다.
HUD는 실패 시 누를 수 있는 재시도 안내를 유지하며 설정의 수동 저장도 실패를 표시합니다.
버전 없는 기존 Godot 저장을 지원하고, 미래 버전과 잘못된 컨테이너는 적용 전에 거부합니다.
중단된 조사관 보호는 습격 노드를 복구하는 대신 수락 상태로 되돌려 재시작합니다.
새 모험 준비·취소는 기존 저장을 지우지 않습니다. 테스트 러너는 별도의 `user://tests/` 경로를 사용합니다.

## 테스트

`tools/check.sh --list` 대신 `tools/godot.sh --headless res://tests/run_all.tscn -- --list`로 케이스를 봅니다.

| 케이스 | 검증 |
| --- | --- |
| `axis` | 지면 접촉 원화(예배당 기단 포함)의 바닥 변이 ±30°(보정 후 2.5° 이내) |
| `chapel` | 예배당 마당: 계단으로 오르면 마당 위(z=1), 건물 자리와 정면 절벽은 막힘 |
| `terrace` | 랜드마크 윗면은 계단(입구)으로만 오를 수 있고 절벽은 막힘 |
| `bridge` | 다리를 건널 수 있고 강은 막힘 |
| `dungeon` | 두 경로 이동·시간 정지·숲 의뢰 분리·최초 완료 보상·재입장·시간 종료·사망·재접속 |
| `exploration` | 안식처 발견·저장·안전한 도착·이동 제한·폭포 물 차단·지도 공유 좌표 |
| `boss` | 명시적 도전·공터 이탈·공격 예고와 판정·가방이 찬 고유 보상 보관·중복 방지 |
| `combat` | 강화 실패 보존·잠금·실제 무기 공격 판정과 간격·무료 초기화 |
| `quests` | 제단·배달·보호 의뢰(실패·재도전 포함), 보상, 파수꾼 처치, 대화·일지 패널 |
| `bag` | 시작 장비, 상자 보상, 장착·잠금·판매, 상점·수련, 저장·불러오기, 설정·스킬 패널 |
| `saving` | 손상 저장·백업·이전 형식·실패 후 재시도·보호 의뢰 복구·보상 중복 방지 |
| `skills` | 두 직업의 모든 스킬을 규칙대로 배우고 시전, 스킬 트리 탭 열기 |

## CI와 배포

`.github/workflows/web.yml`이 모든 푸시에서 `tools/setup_godot.sh` → `tools/check.sh --export`를 실행하고, `main`이면 `build/web`을 Pages에 배포합니다.
