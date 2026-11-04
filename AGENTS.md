# AI 개발 지침

이 파일은 저장소 전체에 적용됩니다. 작업 전에 [README.md](README.md)로 현재 이식 범위를,
[docs/development.md](docs/development.md)로 구조·데이터 출처·검증 방법을 확인합니다.
문서는 탐색용이므로 변경 전에는 실제 코드를 읽습니다.

## 프로젝트

- Godot 4.5 프로젝트(GL Compatibility)이며 GitHub Pages(`/sjrpg2/`)에 웹(WASM, 단일 스레드)으로 배포합니다.
  Flutter·Bonfire 원본 [obmaz/sjrpg](https://github.com/obmaz/sjrpg)는 **참고 자료**입니다. 세계관·전사와 마법사·쿼터뷰는 유지하되
  Godot판의 조작감·가독성·진행을 우선해 규칙·밸런스를 개선합니다. 원본과 다른 규칙은 README와 관련 코드에 이유를 남깁니다.
  현재 목표는 숲 1장 완성(탐험 보강·선택형 동굴 포함)이며, 후속 지역과 탈것은 이후에 작업합니다.
- 스크립트는 `scripts/`, 데이터는 `assets/data/`, 원화는 `assets/art/`, 테스트는 `tests/`, 도구는 `tools/`입니다.
  장면(`scenes/`)은 `main.tscn` 하나이며 화면은 코드로 구성합니다.

## 그림 규칙 (가장 중요)

- **2.5D 쿼터뷰 120°**: 지면 두 축은 ±30°, 수직은 90°입니다(`scripts/iso.gd`).
  바닥 접점이나 구성한 충돌 사각형만으로 원화가 맞다고 판단하지 않습니다. 모든 직선 구조물은 실제 원화의 상·중·하단,
  두 방향·마주보는 모서리를 측정합니다. 렌더링 후 각도 오차와 같은 축의 평행선 간 차이 모두 2.5° 이내여야 합니다.
  `tools/extract/art_axis_measure.json`에 실제 픽셀 선분을 기록하고, 원화·아틀라스 해시를 명시적으로 갱신합니다
  (`art_audit_catalog.py`). `art_projection`은 실제 그리기 투영·선분 내부·메시 뒤집힘·해시를 검사합니다.
  `axis`는 배치·충돌 모델 검사이며 원화 검증을 대신하지 않습니다. 지붕 경사·계단 진행 방향·자연 실루엣은 수평축과 구별합니다.
  새 원화는 [측정·재생성 방법](docs/chapel-regeneration.md)을 따릅니다.
- 코드로 그림을 대신 그리지 않습니다. 코드는 원화의 배치·투영·충돌·깊이 정렬에만 씁니다(HUD 도형과 효과는 예외).
- 이미지를 새로 가져오면 `.import`의 `compress/mode`를 손실(1)로 두어 웹 번들 크기를 유지합니다(`tools/check.sh`는 크기를 점검하지 않으므로 export 결과 `pck`를 확인).
- 그림·UI를 바꾸면 실제 브라우저 화면(`tools/screenshot.mjs`)으로 가로·세로를 함께 확인합니다. 헤드리스 테스트 통과로 시각 검증을 대신하지 않습니다.

## 데이터 출처

- `assets/data/{skills,gear,village,landmarks}.json`은 원본 Dart에서 `tools/extract/extract_data.py`로 뽑습니다. 손으로 고치지 말고
  추출 스크립트를 고쳐 다시 만듭니다(재현 가능해야 함). 추출 후 `git diff`로 의도한 변화만 있는지 확인합니다.
- 전투 수치(피해·체력·소모·가격)는 원본 단위를 따릅니다: 정수 내부 단위, 화면 표시는 체력·피해 ×100, 자원 ×10(`HudArt.stat/res`).
  Godot판 조정값은 추출 JSON을 직접 바꾸지 않고 별도 설정으로 적용합니다. 변경한 규칙과 이유를 주석과 README에 적습니다.

## GDScript 규칙

- 탭 들여쓰기, 가능한 곳에는 타입을 적습니다. `Dictionary`/`Variant`에서 꺼낸 값은 `var x: float = d["x"]`처럼 타입을 명시합니다
  (`:=`로 추론하면 "Variant로 추론" 경고가 오류로 처리됩니다). 한 줄 람다 안에서 `match`를 쓰지 말고 함수로 뺍니다.
- 폰 화면: 세로 720×1280, 가로 1280×720 기준 해상도입니다(`main.gd`). 패널은 `PanelFrame`을 쓰고(안전 영역, 64px+ 터치, 큰 글자),
  일반 화면의 `UiKit` 글자 크기는 `PanelFrame`이 `UiKit.boost`로 키웁니다.
- 게임플레이 상태는 `GameState`(자동 로드)에 두고 `save_game()`/`load_game()`에 항목을 추가합니다. 저장은 하위 호환(`data.get(키, 기본값)`)을 지킵니다.
- 효과음(`SoundFx`)·진동(`Prefs.pulse`)은 설정에서 꺼질 수 있으므로 항상 해당 호출을 거칩니다.
- 사용하지 않는 코드·자산은 지웁니다. 주석은 현재 동작의 이유·단위·불변 조건을 설명합니다.

## 검증과 완료

변경 후 반드시 실행합니다.

```sh
tools/check.sh                 # 임포트(스크립트 오류) + 전체 테스트
tools/check.sh --only=quests   # 일부 케이스
tools/check.sh --export        # 웹 빌드까지
```

- 새 기능은 `tests/cases/`에 케이스를 추가합니다(`extends TestCase`, `run()` 구현). 실패는 `check()`/`failures += 1`로 남깁니다.
  게임 장면은 `await make_game()`으로 만들고, 걷기·프레임 대기는 `_walk`/`_frames`를 씁니다.
- UI·입력·렌더링을 바꾸면 `tools/export_web.sh` → `tools/serve.sh` → `node tools/screenshot.mjs --scene … --device phone|desktop`으로 화면을 확인합니다.
- **푸시·배포를 요청받으면** `main`의 해당 커밋에 대한 워크플로 "Build web and deploy to GitHub Pages" 성공과 공개 페이지
  <https://obmaz.github.io/sjrpg2/> 로드까지 확인한 뒤 완료를 보고합니다. 배포 설정(Pages 소스 = GitHub Actions)은 저장소 설정에서 한 번만 바꿉니다.
- 브랜치는 만들지 않고 `main`에 직접 커밋합니다(사용자 지시). 커밋 메시지는 변경의 이유를 적습니다.
- 기능이 바뀌면 README의 사용자 안내와 `docs/development.md`의 구조를 함께 갱신합니다. 일회성 완료 기록은 문서에 쌓지 않습니다.
