# 자연의 수호자 (Godot 4)

Flutter·Bonfire로 만든 [sjrpg](https://github.com/obmaz/sjrpg)를 **Godot 4.5**로 옮기는 프로젝트입니다.
웹(HTML5/WebAssembly)으로 빌드해 GitHub Pages에 배포합니다.

[게임 플레이](https://obmaz.github.io/sjrpg2/)

## 현재 이식된 범위

- 타이틀 → 직업 선택(전사/마법사) → **제1장 숲 마을**과 주변 필드
- **2.5D 쿼터뷰 120°**: 원본 `IsometricGround`와 같은 ±30° 지면 축 (`scripts/iso.gd`)
  - 원본 실측 데이터(`forest_isometric_frames.dart`)를 `assets/data/village.json`으로 옮겨 건물·성문·분수·워프·나무의 원화, 바닥 접점, 지면 보정, 충돌 받침을 그대로 사용 (`scripts/iso_sprite.gd`, `scripts/village.gd`)
  - 성벽과 네 성문, 십자 포장길과 밝은 광장, 상인·대장장이·탈것 상인·촌장·보급원 미라
  - **120° 기준 점검**: 바닥 접점이 ±30°에서 2° 이내인 원화만 사용. 예배당 원화는 측정 결과 어긋나(-30/+39/-19/+27°) 게임에서 뺐고, 이에 따라 높은 마당(높낮이)도 새 원화가 나올 때까지 없음 (`docs/chapel-regeneration.md`)
  - 마을은 안전 구역(몬스터 진입·생성 없음), 성문 밖 흙길과 숲에서 몬스터 등장
  - **동문 밖 강과 돌다리**: 원본 실측(`QuarterViewBridgeArt`)대로 동문 앞마당에서 북쪽으로 다리를 건너 길이 이어짐. 물은 흐르는 텍스처 두 겹과 바위 둑으로 그리고, 다리 상판만 걸을 수 있으며 난간 앞면과 모서리 기둥은 캐릭터 위에 그려짐
  - 성벽 끝은 성문의 실측 기둥 위치에 맞물리고 성문이 항상 성벽 끝을 덮음
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
- **가방(장비)**: 원본 장비 34종(`assets/data/gear.json`), 부위 3(무기·방어구·부적) · 등급 4 · 옵션 · 무기 레벨, 보관함 24칸, 탭(전체·신규·무기·방어구·부적·잠금), 장착·잠금·판매, 현재 장비와 비교. 시작 장비는 원본과 같음(전사: 수호자의 검, 마법사: 불씨 완드, 둘 다 여행자의 옷). 공격력·생명·자원은 장비를 합산해 계산(`GameState.attack_power`)
- **상자**: 마을 상자 5개를 공격 기술로 부수면 원본 규칙대로 장비 7 · 보급 1 · 골드 1 · 매복 1 비율로 보상
- **상점**: 상인(왼쪽 위 집) 곁에서 "상점" 버튼 → 무기·방어구·부적·물약 구매 (원본 가격·레벨 해금)
- **설정**: 전체화면, 타격 진동, 전투 효과음(원본 SoundProfile 합성), 지금 저장, 타이틀, 새 모험(확인 후 저장 삭제). 설정은 기기에 저장
- **모바일 레이아웃**: 가방·스킬·설정이 한 틀(`PanelFrame`)을 공유. 화면 전체를 쓰고 안전 영역을 피하며, 글자 약 20px+·터치 영역 64px+, 탭은 가로 스크롤, 본문은 세로 스크롤
- **레퍼런스 스타일 HUD**: 원본 초상화(전사 hero-helmeted-portrait, 마법사 class-selection 얼굴)와 기울어진 체력·마나·경험치 막대, 원형 미니맵과 지역명, 청색(전사는 호박색) 빛 고리의 주 슬롯과 보조 슬롯 4개, 체력·마나 물약, 구르기, 마법진 조이스틱, 하단 가방·스킬·퀘스트·설정 아이콘 바, 가장자리 비네트
- 바닥은 원본 자갈 포장 원화를 지면에 깔고 숲 그늘(나뭇잎 그림자) 층을 곱해 레퍼런스의 햇살·그늘 분위기를 냄

원본의 나머지 여섯 지역, 폭포·강 상류, 퀘스트, 대장장이·탈것·촌장 상호작용, 상점의 축복(수련), 무기 능력(희귀·고유 장비의 선물), 장비별 사거리·공격 간격은 아직 이식 전입니다. 장비가 없어서 무기 숙련은 가장 높은 한 가지가 기본 무기에 적용됩니다.

## 구조

| 경로 | 내용 |
| --- | --- |
| `scenes/main.tscn`, `scripts/main.gd` | 화면 전환, 가로/세로 기준 해상도 |
| `scripts/game_state.gd` | 자동 로드. 직업 수치, 레벨, 저장 |
| `scripts/game.gd` | 필드, 몬스터 생성, 다각형 충돌, 효과 |
| `scripts/iso.gd`, `scripts/iso_sprite.gd`, `scripts/wall_piece.gd` | 쿼터뷰 투영, 실측 원화 배치, 성벽 |
| `scripts/village.gd`, `assets/data/village.json` | 제1장 숲 마을 배치와 예배당 마당 |
| `scripts/river.gd`, `scripts/bridge.gd` | 동문 밖 강과 돌다리 |
| `scripts/gear.gd`, `scripts/gear_art.gd`, `scripts/chest.gd` | 장비 모델·아이콘, 마을 상자 |
| `scripts/panel_frame.gd`, `scripts/bag_panel.gd`, `scripts/settings_panel.gd` | 모바일 패널 틀, 가방·상점, 설정 |
| `scripts/prefs.gd`, `scripts/sound_fx.gd` | 기기 설정(진동·효과음), 효과음 합성 |
| `docs/chapel-regeneration.md` | 예배당 원화가 ±30° 기준에서 벗어난 측정 결과와 재생성 규격 |
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

   `index.html?zoom=0.4`로 카메라를 넓게, `&at=field`·`&at=bridge`·`&at=gate0..3`로 시작 위치를 바꿔 볼 수 있습니다 (디버그용).

   웹 빌드는 스레드를 끈 단일 스레드 템플릿(`variant/thread_support=false`)을 사용합니다.
   GitHub Pages는 COOP/COEP 헤더를 보낼 수 없기 때문입니다.

## 배포

`.github/workflows/web.yml`이 모든 푸시에서 웹 빌드를 만들고, `main` 브랜치에 푸시되면 GitHub Pages에 배포합니다.
처음 한 번은 저장소 **Settings → Pages → Build and deployment → Source**를 **GitHub Actions**로 설정해야 합니다.
