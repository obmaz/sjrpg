# 자연의 수호자 (Godot 4)

Flutter·Bonfire로 만든 [sjrpg](https://github.com/obmaz/sjrpg)를 **Godot 4.5**로 옮기는 프로젝트입니다.
웹(HTML5/WebAssembly)으로 빌드해 GitHub Pages에 배포합니다.

[게임 플레이](https://obmaz.github.io/sjrpg2/)

## 현재 이식된 범위

- 타이틀 → 직업 선택(전사/마법사) → 필드 모험
- 원본 스프라이트 아틀라스(16방향 영웅 달리기·공격, 8방향 몬스터 걷기·공격)와 JSON 경계 데이터를 그대로 사용 (`scripts/actor_atlas.gd`)
- 전사: 베기 + 회오리 베기(분노), 마법사: 화염탄 + 얼음 폭발(마나·둔화)
- 고블린·늑대·멧돼지·해골 전사. 중앙 안식처에서 멀어질수록 강한 몬스터 등장
- 경험치·레벨업·물약 드롭, 사망 후 안식처 부활
- 진행 저장(`user://`, 웹에서는 IndexedDB)
- 키보드(WASD/방향키, J/스페이스 공격, K 기술, Q 물약, Esc 메뉴)와 모바일 멀티터치(가상 조이스틱 + 버튼)
- 가로/세로 화면 모두 지원

원본의 일곱 지역, 스킬 트리, 장비, 퀘스트, 마을 등은 아직 이식 전입니다.

## 구조

| 경로 | 내용 |
| --- | --- |
| `scenes/main.tscn`, `scripts/main.gd` | 화면 전환, 가로/세로 기준 해상도 |
| `scripts/game_state.gd` | 자동 로드. 직업 수치, 레벨, 저장 |
| `scripts/game.gd` | 필드, 나무 배치, 몬스터 생성, 충돌, 효과 |
| `scripts/player.gd`, `scripts/enemy.gd` | 영웅 조작과 몬스터 AI |
| `scripts/hud.gd`, `scripts/touch_controls.gd` | HUD, 메뉴, 터치 조작 |
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

   웹 빌드는 스레드를 끈 단일 스레드 템플릿(`variant/thread_support=false`)을 사용합니다.
   GitHub Pages는 COOP/COEP 헤더를 보낼 수 없기 때문입니다.

## 배포

`.github/workflows/web.yml`이 모든 푸시에서 웹 빌드를 만들고, `main` 브랜치에 푸시되면 GitHub Pages에 배포합니다.
처음 한 번은 저장소 **Settings → Pages → Build and deployment → Source**를 **GitHub Actions**로 설정해야 합니다.
