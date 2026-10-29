# AI 개발 지침

이 파일은 저장소 전체에 적용됩니다. 먼저 [README.md](README.md)로 제품 범위를 확인하고,
[docs/development.md](docs/development.md)에서 작업에 관련된 구조·동작 계약·검증·배포 내용을 읽습니다.
문서는 탐색을 돕는 자료이며 변경 전에는 실제 코드를 확인합니다.

## 두 버전의 범위

- 기존 JavaScript 게임은 루트 `src/`·`index.html`에서 유지하며 `/sjrpg/legacy/`에 배포합니다.
- 새 게임은 `flutter_game/`의 Flutter·Bonfire 앱이며 `/sjrpg/new/`에 배포합니다. 이 폴더는 Dart의 snake_case 파일명과 `dart format`을 따릅니다.
- `site/index.html`은 두 버전을 고르는 진입 화면입니다. `scripts/build-all.cjs`는 준비된 두 게임을 컴파일 없이 `dist/`에 합칩니다. `npm run prepare:legacy`는 변경 없는 Legacy 배포본/캐시를 검증해 재사용합니다.
- 새 버전 변경 후에는 `flutter analyze`·`flutter test`·`--wasm` Flutter 릴리스 빌드도 실행합니다. 레거시를 보존하고 완전 포팅으로 범위를 확장하지 않습니다.

## Flutter 코드 변경

- Dart는 snake_case 파일명·PascalCase 타입·lowerCamelCase 멤버와 `dart format`을 따릅니다. import 순서는 analyzer로 확인합니다.
- 수치·선행 조건은 모델에서 공유하고 UI에 피해·소모량·DPS 공식을 복제하지 않습니다. 프레임 연출과 실제 타격은 분리합니다.
- 지형·충돌·경로·성역은 공통 월드 모델을 사용합니다. 네이티브 그림·문단·캐시는 소유자와 dispose 경계를 명확히 합니다.
- 헬퍼는 실제 공통 계약이 있을 때 추출하고, 사용하지 않는 대체 코드·배포 자산은 제거합니다. 생성 원본·출처·회귀 시나리오는 보존합니다.
- 주석은 현재 동작의 이유·단위·불변 조건을 설명합니다. 리뷰 완료 내역을 코드나 개발 문서에 누적하지 않습니다.

## Legacy 코드 변경

- 런타임은 브라우저 ES Modules입니다. `src/game.js`가 진입점이며 새 파일은 사용하는 모듈에서 명시적으로 import합니다.
  `window` 전역에 게임 상태나 함수를 노출하지 않습니다. 초기 높이 고정 스크립트만 모듈 진입점보다 먼저 실행합니다.
- 공유 상태는 `src/core/state.js`, 콘텐츠 정의는 `src/data/`, 게임 동작은 `src/systems/`,
  DOM 표시는 `src/ui/`, Canvas 그리기는 `src/render/`에 둡니다.
- 콘텐츠 정의는 템플릿입니다. 획득한 장비·아이템은 복사하고 정의의 사용 횟수를 직접 변경하지 않습니다.
  ID, 드롭 풀, 상점의 `id`·`itemId`·`auxId`, 퀘스트 보상이 실제 정의와 획득 경로로 연결되는지 확인합니다.
- 새로운 월드 상태 배열은 `WORLD_ENTITY_LISTS`에 등록하고 지역 이동 시 `clearWorldEntities()`로 정리합니다.
- 폴더·파일은 kebab-case, 함수·변수는 camelCase, 클래스는 PascalCase, 공유 상수는 UPPER_SNAKE_CASE를 사용합니다.
  기존 Prettier 설정을 따릅니다.

## Legacy에서 유지할 동작

- `canAct()`가 거짓이면 전투·아이템 사용을 실행하지 않습니다. 사망은 같은 프레임의 후속 회복보다 우선합니다.
  처치 보상은 적 하나당 한 번만 지급하고 피격 경직·빙결의 우선순위를 유지합니다.
- 게임 시간은 시뮬레이션 시간이며 프레임 간격은 최대 0.1초입니다. 게임 지연 행동은 `deferGameAction()`을 사용해
  일시정지 때 멈추고 지역 이동 때 취소합니다. 브라우저 타이머는 UI 연출에 사용합니다.
- 스폰·탑승·이동은 전체 몸체를 검사합니다. 스폰 실패의 `null`을 유효하지 않은 후보로 대체하지 않습니다.
  지상 적은 도착 지점에서 해당 크기로 접근 가능한 위치에만 생성합니다. 길찾기 변경 시 좁은 통로와 느린 적도 확인합니다.
  지형을 변경하면 접근성 캐시의 `session.terrainRevision`도 갱신합니다.
- 투사체는 남은 수명 내 이동 구간의 첫 지형·대상을 판정하고 벽 너머에 피해를 주지 않습니다.
- 사막 이동은 편도입니다. 이동 전에 달성한 퀘스트는 보상하고 미완료 숲 전용 퀘스트만 포기합니다.
  지역 공통 퀘스트·완료 기록·보유 장비는 유지합니다. 숲 완료는 다음 모험 안내이고 사막 퀘스트 완료가 최종 승리입니다.
- Legacy의 터치 기기 높이는 페이지 진입 시 한 번 고정합니다. 주소창 변화나 화면 회전으로 높이를 다시 계산하지 않습니다.
  Flutter는 주소창의 높이 변화에는 고정하고 화면 너비가 바뀌면 새 방향의 높이를 기준으로 갱신합니다.
  전체화면 중에는 동적 화면 높이를 사용하고, 나갈 때 현재 방향의 기준 높이를 복원합니다. 데스크톱의 창 크기 대응은 유지합니다.

## 검증과 완료

- Node.js 24 이상에서 의존성이 없으면 `npm ci`, 변경 후 `npm run check`를 실행합니다.
  문서 포맷은 `npx prettier --check README.md AGENTS.md docs/development.md`로 확인합니다.
- Legacy 로직 수정은 `tests/*.test.cjs`, Flutter 로직 수정은 `flutter_game/test/`에 재현·회귀 시나리오를 추가합니다. 문서만 변경할 때 테스트를 새로 만들 필요는 없습니다.
  VM 하네스의 접근자는 테스트 전용이며 실제 브라우저 API로 취급하지 않습니다.
- UI·입력·렌더링을 바꾸면 관련 브라우저 조작도 확인합니다. 모의 Canvas·오디오 테스트를 실제 화면·사운드 검증으로 보고하지 않습니다.
- 푸시·배포를 요청받으면 `main`의 해당 커밋에 대한 **Check and deploy** 성공과 공개 페이지를 확인한 뒤 완료를 보고합니다.
  실행 파일은 상대 경로를 유지해 GitHub Pages의 `/sjrpg/`에서도 로드되게 합니다.
- 기능이 바뀌면 README의 사용자 안내와 개발 참고의 계약을 함께 갱신합니다. 리뷰 수정 내역·일회성 완료 기록은 문서에 누적하지 않습니다.

## Legacy 작업별 참고

- 콘텐츠 필드와 추가 절차: [.github/skills/add-game-content/SKILL.md](.github/skills/add-game-content/SKILL.md)
- 버그 재현과 불변 조건: [.github/skills/debug-game/SKILL.md](.github/skills/debug-game/SKILL.md)
- 구조·공유 상태·업데이트 순서·길찾기·모바일 높이·검사 도구·배포: [docs/legacy-development.md](docs/legacy-development.md)
