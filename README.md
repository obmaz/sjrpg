# 자연의 수호자 (Godot 4)

Flutter·Bonfire로 만든 [sjrpg](https://github.com/obmaz/sjrpg)를 **Godot 4.5**로 옮기는 프로젝트입니다.
웹(HTML5/WebAssembly)으로 빌드해 GitHub Pages에 배포합니다.

[게임 플레이](https://obmaz.github.io/sjrpg2/)

## 현재 이식된 범위

- 타이틀 → 직업 선택(전사/마법사) → **제1장 숲 마을**과 주변 필드
- **2.5D 쿼터뷰 120°**: 원본 `IsometricGround`와 같은 ±30° 지면 축 (`scripts/iso.gd`)
  - 원본 실측 데이터(`forest_isometric_frames.dart`)를 `assets/data/village.json`으로 옮겨 건물·성문·분수·워프·나무의 원화, 바닥 접점, 지면 보정, 충돌 받침을 그대로 사용 (`scripts/iso_sprite.gd`, `scripts/village.gd`)
  - 성벽과 네 성문, 십자 포장길과 밝은 광장, 상인·대장장이·탈것 상인·촌장·보급원 미라
  - **높낮이**: 예배당은 높은 마당 위에 있으며 계단으로만 오를 수 있고 절벽·난간은 막힘. 마당 위의 캐릭터는 예배당 원화 위에 그려짐
  - 마을은 안전 구역(몬스터 진입·생성 없음), 성문 밖 흙길과 숲에서 몬스터 등장
- 원본 스프라이트 아틀라스(16방향 영웅 달리기·공격, 8방향 몬스터 걷기·공격)와 JSON 경계 데이터를 그대로 사용 (`scripts/actor_atlas.gd`)
- **스킬 트리**: 전사 33종(함성·전투 숙련·전투 기술·기본/특수), 마법사 31종(냉기·번개·화염)
  - 원본 카탈로그의 이름·설명·습득 레벨·소모·재사용·선행 조건·트리 배치·아이콘을 그대로 사용 (`assets/data/skills.json`)
  - 스킬 포인트 2개로 시작, 레벨업마다 1개(5의 배수 레벨은 2개), 원본 계열 기술은 최대 20등급
  - 주 슬롯 1개 + 보조 슬롯 4개 + 구르기, 새로 배운 기술은 빈 보조 슬롯에 자동 장착
  - 초기화 시 투자한 포인트 환급
  - 전투 수치(피해 배율·등급당 성장 등)는 이식판에서 단순화해 조정 (`scripts/skill_defs.gd`)
- 고블린·늑대·멧돼지·해골 전사. 중앙 안식처에서 멀어질수록 강한 몬스터 등장
- 경험치·레벨업·물약 드롭, 사망 후 안식처 부활
- 진행 저장(`user://`, 웹에서는 IndexedDB)
- 키보드(WASD/방향키, J/스페이스 주 슬롯, 1–4 보조 슬롯, Shift/L 구르기, Q 물약, T 스킬 트리, Esc 메뉴)와 모바일 멀티터치(가상 조이스틱 + 버튼)
- 가로/세로 화면 모두 지원

원본의 나머지 여섯 지역, 동문 밖 강과 다리, 장비, 퀘스트, NPC 상호작용(상점 등), 상자 파괴 등은 아직 이식 전입니다. 장비가 없어서 무기 숙련은 가장 높은 한 가지가 기본 무기에 적용됩니다.

## 구조

| 경로 | 내용 |
| --- | --- |
| `scenes/main.tscn`, `scripts/main.gd` | 화면 전환, 가로/세로 기준 해상도 |
| `scripts/game_state.gd` | 자동 로드. 직업 수치, 레벨, 저장 |
| `scripts/game.gd` | 필드, 몬스터 생성, 다각형 충돌, 효과 |
| `scripts/iso.gd`, `scripts/iso_sprite.gd`, `scripts/wall_piece.gd` | 쿼터뷰 투영, 실측 원화 배치, 성벽 |
| `scripts/village.gd`, `assets/data/village.json` | 제1장 숲 마을 배치와 예배당 마당 |
| `scripts/player.gd`, `scripts/enemy.gd` | 영웅 조작과 몬스터 AI |
| `scripts/hud.gd`, `scripts/touch_controls.gd` | HUD, 메뉴, 터치 조작 |
| `scripts/skill_tree_panel.gd`, `scripts/skill_icons.gd` | 스킬 트리 화면, 아이콘 |
| `scripts/skill_defs.gd` | 스킬별 전투 동작과 수치 |
| `tests/skill_smoke.gd` | 모든 스킬을 배우고 시전하는 헤드리스 테스트 (CI에서 실행) |
| `assets/art` | 원본 저장소 `art/`에서 가져온 이미지와 아틀라스 JSON |

## 로컬 실행·빌드

1. [Godot 4.5.1](https://godotengine.org/download)과 같은 버전의 export templates를 설치합니다.
2. 에디터에서 `project.godot`을 열고 F5로 실행합니다.
3. 웹 빌드:

   ```sh
   godot --headless --import
   godot --headless --export-release "Web" build/web/index.html
   cd build/web && python3 -m http.server 8000
   ```

   `index.html?zoom=0.4`로 카메라를 넓게, `&at=chapel`·`&at=field`로 시작 위치를 바꿔 볼 수 있습니다 (디버그용).

   웹 빌드는 스레드를 끈 단일 스레드 템플릿(`variant/thread_support=false`)을 사용합니다.
   GitHub Pages는 COOP/COEP 헤더를 보낼 수 없기 때문입니다.

## 배포

`.github/workflows/web.yml`이 모든 푸시에서 웹 빌드를 만들고, `main` 브랜치에 푸시되면 GitHub Pages에 배포합니다.
처음 한 번은 저장소 **Settings → Pages → Build and deployment → Source**를 **GitHub Actions**로 설정해야 합니다.
