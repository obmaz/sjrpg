---
name: add-game-content
description: '자연의 수호자 RPG에 무기, 적, 보스, 보조무기, 상자, 아이템, 퀘스트를 추가합니다.'
argument-hint: '[weapon|enemy|boss|aux|chest|item|quest] 설명'
---

# RPG 콘텐츠 추가

## 정의 위치

- 주무기: src/data/weapons.js의 WEAPONS
- 보조무기: src/data/aux-weapons.js의 AUX_WEAPONS
- 적: src/data/enemies.js의 ENEMY_TYPES와 DESERT_ENEMY_TYPES
- 거리별 스폰 규칙: src/data/spawns.js의 SPAWN_RULES
- 대형 보스: src/data/bosses.js의 BOSS_TYPES
- 상자: src/data/chests.js의 CHEST_TYPES
- 소비 아이템: src/data/items.js의 ITEMS
- 탈것: src/data/mounts.js의 MOUNT_TYPES
- 상점 구성: src/data/shops.js의 SHOP_ITEMS
- 퀘스트: src/data/quests.js의 QUESTS

## 추가와 수정

1. 기존 정의의 필드 계약을 확인하고 고유 ID를 사용합니다. 새 파일명은 kebab-case,
   함수·변수는 camelCase, 공유 상수는 UPPER_SNAKE_CASE를 따릅니다.
2. 무기의 dropPool·dropWeapons, 상점의 id·itemId·auxId, 퀘스트 rewardAux가 실제 정의에 연결되는지 확인합니다.
3. 새로운 능력은 src/systems/combat.js 또는 src/systems/auxiliary-weapons.js에서 구현합니다.
4. 적·보스는 spawnEnemy()의 공통 초기화 경로를 사용합니다. minionType은 숲 적 배열의 유효한 인덱스이며 0도 허용합니다.
5. 보조무기는 제한형이면 uses 양수, 영구형이면 uses -1과 cooldown을 설정합니다.
6. 퀘스트 type은 kills, kills_specific, gold, boss, boss_specific 중 하나입니다.
   특정 적·보스에는 enemyName·bossName이 필요합니다.
7. 숲 MAIN_QUESTS 완료는 다음 모험 안내이고, DESERT_QUESTS 완료가 최종 승리입니다.
8. 지역·단계 조건은 isQuestAvailable()에서 처리합니다. 획득 이력은 recordDiscovery()로 보존합니다.
9. 새 소스 파일은 사용하는 모듈에서 import합니다. 게임은 ES Modules로 로드되며 실행에 HTTP(S)가 필요하고 번들링은 필요하지 않습니다.
10. npm run format과 npm run check를 실행하고, 가능하면 브라우저에서 콘텐츠를 직접 확인합니다.
    실제 화면·사운드 확인이 불가능하면 이를 검증 한계로 기록합니다.

콘텐츠 참조와 고유 ID의 기본 검증은 tests/game.test.cjs에 포함됩니다.
새 능력이나 조건을 추가하면 동작 검증도 함께 확장합니다.
