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

## 테스트

`tools/check.sh --list` 대신 `tools/godot.sh --headless res://tests/run_all.tscn -- --list`로 케이스를 봅니다.

| 케이스 | 검증 |
| --- | --- |
| `axis` | 지면 접촉 원화(예배당 기단 포함)의 바닥 변이 ±30°(보정 후 2.5° 이내) |
| `chapel` | 예배당 마당: 계단으로 오르면 마당 위(z=1), 건물 자리와 정면 절벽은 막힘 |
| `terrace` | 랜드마크 윗면은 계단(입구)으로만 오를 수 있고 절벽은 막힘 |
| `bridge` | 다리를 건널 수 있고 강은 막힘 |
| `quests` | 제단·배달·보호 의뢰(실패·재도전 포함), 보상, 파수꾼 처치, 대화·일지 패널 |
| `bag` | 시작 장비, 상자 보상, 장착·잠금·판매, 상점·수련, 저장·불러오기, 설정·스킬 패널 |
| `skills` | 두 직업의 모든 스킬을 규칙대로 배우고 시전, 스킬 트리 탭 열기 |

## CI와 배포

`.github/workflows/web.yml`이 모든 푸시에서 `tools/setup_godot.sh` → `tools/check.sh --export`를 실행하고, `main`이면 `build/web`을 Pages에 배포합니다.
