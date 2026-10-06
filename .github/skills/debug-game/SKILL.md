---
name: debug-game
description: '자연의 수호자 RPG의 전투, 충돌, 스폰, 화면 및 상태 관리 버그를 재현하고 수정합니다.'
argument-hint: '[버그 설명]'
---

# RPG 게임 디버깅

## 코드 위치

- 공통 설정과 상태: `src/core/constants.js`, `src/core/state.js`
- 충돌과 스폰 검색: `src/core/collision.js`, `src/core/helpers.js`
- 시작과 프레임 루프: `src/game.js`
- 게임 업데이트 순서: `src/systems/simulation.js`
- 플레이어 이동: `src/systems/player.js`
- 공격과 처치: `src/systems/combat.js`
- 적 상태 머신: `src/systems/enemy-ai.js`
- 맵 생성과 스폰: `src/systems/world.js`, `src/systems/spawning.js`
- 보조무기: `src/systems/auxiliary-weapons.js`
- 소비 아이템·탈것: `src/systems/consumables.js`, `src/systems/mounts.js`
- 퀘스트 진행과 이동: `src/systems/quests.js`, `src/systems/travel.js`
- 패널과 HUD: `src/ui/`
- Canvas 렌더링: `src/render/`

## 수정 절차

1. 발생 조건과 기대 동작을 정리하고 해당 시스템의 실제 코드를 읽습니다.
2. `tests/game.test.cjs`에 실패하는 동작 테스트를 추가합니다.
3. 공통 헬퍼와 데이터 정의를 확인한 뒤 수정합니다.
4. `npm run check`로 변수·참조·포맷·전체 회귀 테스트를 검증합니다.
5. 가능하면 브라우저에서 직접 확인합니다. 브라우저 확인이 차단되면 그 한계를 명시합니다.

## 지켜야 하는 동작

- `canAct()`가 거짓이면 전투와 아이템 사용을 실행하지 않습니다.
- 피격 경직과 빙결은 상태 전환보다 우선합니다.
- 처치 보상은 적 하나당 한 번만 지급합니다.
- `findSpawnTile()`의 null은 스폰 실패이며 임의의 마지막 후보로 대체하지 않습니다.
- 일반 적의 전체 몸체가 지형과 다른 엔티티에 겹치지 않아야 합니다.
- 숲 퀘스트 완료 후 사막 진행을 유지하고 사막 퀘스트 그룹 완료를 최종 승리로 판정합니다.
- 보스 퀘스트는 수락 이전의 처치 기록도 반영합니다.
- 편도 지역 이동 전에 달성한 퀘스트를 완료하고 미완료 이전 지역 전용 퀘스트는 포기합니다. 지역 공통 퀘스트와 완료 기록은 유지합니다.
- 탑승·이동·스폰은 탈것의 전체 몸체를 검증합니다. 배는 물에만 머물며 육지에서 탑승할 수 있어야 합니다.
- 투사체는 남은 수명 내 이동 경로에서 가장 먼저 닿는 지형이나 몸체를 판정합니다. 벽을 통과해 피해를 주지 않습니다.
- 부메랑 같은 게임 지연 동작은 `deferGameAction()`을 사용합니다. 일시정지 시 시간이 멈추고 지역 이동 시 취소됩니다.
- 월드 초기화는 `clearWorldEntities()`를 사용합니다. 배열을 추가하면 `WORLD_ENTITY_LISTS`에도 등록합니다.
- UI 애니메이션과 메시지 제거만 실제 브라우저 타이머를 사용합니다.
- 임시 로그는 최종 코드에서 제거합니다. 정상 게임 피드백은 `addMessage()`, `spawnFloatingText()`, `spawnParticles()`를 사용합니다.

## 검증의 범위

테스트 하네스는 HTML의 모듈 진입점에서 실제 import 그래프를 링크·실행하고 DOM·Canvas·브라우저 타이머를 대체합니다.
실제 화면의 배치·색상·사운드는 자동 테스트만으로 검증했다고 보고하지 않습니다.
